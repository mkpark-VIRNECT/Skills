---
name: issue-family-goal
description: "같은 GitHub 저장소의 parent issue와 native direct sub-issue를 장기 goal로 등록하고, dependency 순서의 단일 stacked PR chain으로 구현·검증·독립 리뷰까지 순차 완료할 때 사용한다. 단일 이슈, Project Todo 전체 선별, cross-repo hub 실행에는 사용하지 않는다."
---

# Issue Family Goal

같은 저장소의 parent issue가 가진 native direct sub-issue를 한 번에 하나씩 처리한다. 각 구현은 `$gh-issue-pr-review-loop`에 맡기고, 이 Skill은 goal 수명주기, 고정된 child 범위, 실행 순서, stacked branch ancestry와 최종 감사를 조율한다.

## 범위와 권한

- 입력은 GitHub issue URL, `owner/repo#number`, 또는 현재 저장소의 issue 번호다.
- parent와 모든 direct sub-issue가 같은 repository에 있을 때만 실행한다. cross-repo child가 있으면 `$multi-repo-issue-orchestration`으로 넘긴다.
- nested child를 재귀 확장하지 않는다. direct child가 다시 parent라면 범위를 자동 확대하지 말고 보고한다.
- merge, issue close, parent 직접 구현은 수행하지 않는다.
- goal은 자동 선택만으로 생성하지 않는다. 아래 snapshot을 보여준 뒤 사용자가 명시적으로 승인해야 한다.

## Goal 등록 전 확인

1. `get_goal`로 현재 task의 goal을 먼저 확인한다.
   - 같은 repository/parent의 진행 중 goal이면 새로 만들지 않고 재개한다.
   - 다른 unfinished goal이면 덮어쓰지 말고 현재 goal을 보고한다.
2. parent와 기본 branch를 조회하고 native direct sub-issue를 REST endpoint `repos/{owner}/{repo}/issues/{parent}/sub_issues`로 끝까지 paginate한다. GraphQL `first: 20` 결과만으로 범위를 확정하지 않는다.
3. 각 child의 `dependencies/blocked_by`, Project 상태, linked branch, open PR과 PR base/head를 조회한다. 기존 `$issue-management` preflight는 child 착수 검증에 재사용한다.
4. child가 모두 같은 repo인지, dependency cycle이 없는지 확인한다. 내부 dependency는 topological order로 정렬하고, 동시에 가능한 child는 parent의 native sub-issue 순서를 따른다.
5. 사용자에게 다음 snapshot을 보여주고 goal 등록 여부를 확인한다.
   - repository, parent, 기본 branch
   - 고정할 direct child 번호와 순서
   - 내부 dependency와 외부 open blocker
   - 기존 branch/PR 및 충돌
   - 완료 기준과 merge 제외
6. 승인 후에만 `create_goal`을 호출한다. objective에는 repository, parent, 고정 child 번호, 순차 stacked PR, review-clear 최종 감사와 merge 제외를 포함한다. 사용자가 요청하지 않은 `token_budget`은 설정하지 않는다.

질문 카드가 있으면 등록 확인에 사용한다. 없으면 snapshot과 짧은 승인 질문을 남기고 goal을 만들지 않은 채 턴을 끝낸다.

## 순차 실행

1. 매 goal turn 시작 시 live child/dependency/PR 상태와 고정 snapshot을 대조한다.
   - child 추가·제거·교체 또는 dependency 변경은 자동 편입하지 않는다. 변경 내용과 영향을 보여주고 사용자 승인을 받는다.
   - 기존 branch/PR은 아래 stack과 호환될 때만 재사용한다. base나 ancestry가 다르면 임의 retarget, rebase, force-push하지 않는다.
   - 이미 닫힌 child는 이를 closing한 merged PR과 merge commit의 stack 포함 여부가 확인될 때만 완료로 인정한다. 근거가 없으면 자동으로 건너뛰지 않는다.
2. 아직 완료되지 않은 child 중 내부 predecessor가 goal-local review-clear이고 외부 open blocker가 없는 첫 후보를 고른다.
   - 첫 child base는 repository 기본 branch다.
   - 이후 child base는 직전 review-clear PR의 최신 head branch다. dependency가 없는 sibling도 같은 단일 stack을 이어간다.
3. `$gh-issue-pr-review-loop`에 parent, 고정 child 목록, 현재 source child, stack base/head, goal-local blocker와 reviewed head SHA를 전달한다.
4. 다음 조건을 모두 다시 조회한 뒤에만 child를 review-clear로 기록하고 다음 child로 이동한다.
   - source issue에 연결된 PR과 branch가 있다.
   - PR base가 계획한 stack base이고 최신 predecessor head가 ancestry에 포함된다.
   - 검증 결과와 독립 리뷰가 최신 PR head를 대상으로 한다.
   - unresolved review thread와 blocking review가 0건이다.
   - PR metadata postcondition이 통과했고 Ready 판단이 끝났다.

goal-local open blocker는 해당 blocker PR이 위 조건으로 review-clear이고 후보 stack base가 그 최신 head를 포함할 때만 충족된 것으로 본다. snapshot 밖의 open blocker, partial preflight, 확인되지 않은 ancestry는 항상 hard stop이다.

## 중단과 완료

- 한 child가 막혀도 다른 실행 가능 child가 있으면 계속 진행한다.
- 실행 가능한 child가 없으면 live blocker와 필요한 다음 조치를 보고하고 goal을 active로 둔다.
- 같은 blocking condition이 원래 turn을 포함해 3회 연속 반복되고 의미 있는 다른 작업이 없을 때만 `update_goal(status="blocked")`를 호출한다.
- 완료 전 고정 child 전부에 대해 merged-complete 또는 최신 head review-clear 여부, unresolved thread 0건, blocking review 0건, PR postcondition, 연속 stack ancestry를 다시 감사한다.
- 전부 통과하면 `update_goal(status="complete")`를 호출한다. budgeted goal이면 tool 결과의 최종 token usage도 보고한다.
- 최종 보고에는 parent, child별 branch/PR/latest SHA/검증/리뷰, stack merge 순서, 미실시 merge를 포함한다.

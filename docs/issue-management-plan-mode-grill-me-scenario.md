# issue-management Plan Mode + Grill-Me 재현 시나리오

저장소 루트에서 실행한다. 두 시나리오 모두 Plan Mode 전용이며 issue, Project field, relationship, branch와 PR을 변경하지 않는다.

## 공통 관찰 기준

시작 전과 최종 계획 출력 후 다음 상태를 비교한다.

```powershell
$Repo = "mkpark-VIRNECT/Skills"
$beforeIssues = gh issue list --repo $Repo --state all --limit 100 --json number,state,title,updatedAt
$beforeProject = gh project item-list 4 --owner mkpark-VIRNECT --format json --limit 100
$beforeChildren = gh api "repos/$Repo/issues/2/sub_issues?per_page=100"

# Plan Mode 대화를 실행한다.

$afterIssues = gh issue list --repo $Repo --state all --limit 100 --json number,state,title,updatedAt
$afterProject = gh project item-list 4 --owner mkpark-VIRNECT --format json --limit 100
$afterChildren = gh api "repos/$Repo/issues/2/sub_issues?per_page=100"

@(
    $beforeIssues -ceq $afterIssues
    $beforeProject -ceq $afterProject
    $beforeChildren -ceq $afterChildren
) -notcontains $false
```

기대 결과는 `True`다. 대화 transcript에도 `gh issue create/edit`, Project item mutation, `addSubIssue`, `addBlockedBy`가 없어야 한다.

## 1. 모호한 요구

Plan Mode에서 다음 요청을 사용한다.

```text
[issue-management](plugins/virnect-skills/skills/issue-management/) virnect-skills 검증 실패 알림을 이슈로 구성해. 알림 채널과 CI 포함 여부는 아직 정하지 않았어.
```

기대 흐름:

1. `issue-management`가 `grill-me`를 자동 적용한다.
2. repository, 기존 validator/wrapper, open issue/PR과 Project field를 먼저 읽는다.
3. 코드와 기존 이슈로 확정할 수 없는 가장 중요한 제품 결정 하나만 `request_user_input`으로 묻는다.
4. 답변이 다른 scope, 완료 기준 또는 metadata 결정을 열면 다음 턴에 질문 카드 하나만 추가한다.
5. 모든 질문이 해소되기 전에는 `<proposed_plan>`을 확정하거나 GitHub를 변경하지 않는다.

첫 질문 카드의 예시는 다음과 같다.

```text
질문: 검증 실패를 어디에 노출할까요?
1. 로컬 종료 코드만 (Recommended) — 현재 wrapper 계약을 유지하고 CI/외부 연동을 추가하지 않습니다.
2. GitHub Actions — workflow와 check 결과까지 작업 범위가 넓어집니다.
3. 로컬과 GitHub Actions — 두 실행 경로와 중복 메시지 기준이 필요합니다.
```

질문 카드를 사용할 수 없는 환경에서는 일반 채팅 질문으로 바꾸지 않고 진행 불가 사유만 보고한다.

## 2. 명확한 요구

Plan Mode에서 다음 요청을 사용한다.

```text
[issue-management](plugins/virnect-skills/skills/issue-management/) 기존 #6을 기준으로 온보딩 문서에 Test-VirnectSkills.ps1 실행법과 #4/#5 시나리오 문서 링크를 연결하는 계획을 작성해. docs/virnect-skills-workflow-onboarding.md만 수정하고 script, skill 본문, CI는 범위에서 제외해. 완료 기준은 상대 경로 링크, 전체 검증 명령, final review/ancestry checklist야. Project #4 Todo, P2, XS, Estimate 2h, assignee mkpark-VIRNECT, parent #2와 기존 blocked-by #4/#5를 유지해. GitHub는 변경하지 마.
```

기대 흐름:

1. 요구와 기존 #6의 목적, scope/non-scope, 관계, metadata가 일치하는지 읽기 전용으로 확인한다.
2. 코드나 issue에서 이미 확정된 내용을 다시 묻지 않는다.
3. 질문 카드 없이 바로 결정 완료 계획을 출력한다.
4. issue/Project/relationship mutation은 0건이다.

## 3. 최종 출력 계약

두 흐름 모두 결정이 끝나면 다음 항목을 하나의 `<proposed_plan>`에 포함한다.

```text
<proposed_plan>
- 목적과 성공 기준
- scope / non-scope
- 구현 계획과 검증 계획
- statusPlan
  - group, title, reason
  - remainingQuestions=[]
  - expectedStatus와 statusReason
  - relationshipPlan
- metadataPlan
  - assignees, project, status, size, estimateHours
  - splitRequired, metadataQuestions=[]
- rootCauseOwnershipPlan
  - symptomRepo, candidateRootCauseRepos, searchedSignals
  - activePrOrIssueCandidates, ownershipDecision, decisionReason
- expectedNativeRelations
- GitHub mutation 0건 확인 기준
</proposed_plan>
```

`remainingQuestions` 또는 `metadataQuestions`가 남아 있거나 필수 계약이 불명확하면 결정 완료 계획으로 표시하지 않는다.

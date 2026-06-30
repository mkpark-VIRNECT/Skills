---
name: multi-repo-issue-orchestration
description: "issue-management와 gh-issue-pr-review-loop가 내부 helper로 사용하는 multi-repo product hub orchestration 스킬. 일반 사용자는 이 스킬을 직접 고르지 않고 issue-management로 이슈 등록을 요청한다. product 요구사항을 여러 requirement group, product hub issue, repo별 child issue로 나누거나, hub issue 실행 시 child issue와 product local package override를 조율해야 할 때 보조 지침과 profile/schema를 제공한다."
---

# Multi Repo Issue Orchestration

Product 요구사항 하나가 여러 repository나 module package 변경으로 나뉘는 경우를 조율한다.
단일 repo 구현 세부 절차는 기존 `issue-management`, `gh-issue-pr-review-loop`, `todo-issue-automation`에 맡기고, 이 Skill은 hub/sub issue 구조와 product-local test setup만 결정한다.
일반 사용자는 `$issue-management ... 이슈 등록`으로 요청한다. 이 Skill은 issue registration/execution 과정에서 필요한 경우에만 helper로 사용한다.

## Reference 로드 기준

- profile을 추가하거나 해석할 때는 `references/profile-schema.md`를 읽는다.
- 자동화 prompt를 생성하거나 profile required field를 확인할 때는 `scripts/render-hub-prompt.ps1`를 사용한다.
- repo별 issue 생성/갱신은 `issue-management`를 사용한다.
- repo별 PR 구현/검증/review loop는 `gh-issue-pr-review-loop`를 사용한다.
- repo별 Todo 후보 자동 선별이 필요하면 해당 repo의 `todoProfile`로 `todo-issue-automation`을 사용한다.

## 기본 원칙

- 사람이 확인하는 issue, PR, comment, review, 보고는 한국어로 작성한다.
- 이슈 등록의 public front door는 `issue-management`다. 사용자가 single-repo/multi-repo를 먼저 고르게 하지 않는다.
- 이슈 등록과 작업 실행은 분리한다. registration 단계에서는 issue/Project/relationship만 만들고 branch/worktree/PR/package override를 실행하지 않는다.
- 기존 단일 repo Skill 본문을 재해석하지 않는다. 이 Skill은 product hub 조율만 한다.
- repo, Project, branch, ownership, validation, package override 값은 profile을 단일 진실원천으로 사용한다.
- package manager별 설정 방법은 추측하지 말고 profile의 `packageOverrides` command만 실행한다.
- merge는 수행하지 않는다.
- product local test override는 product issue 범위가 아니면 commit하지 않는다.
- active PR, 열린 `blocked-by`, ownership overlap, partial preflight는 착수 차단 또는 보류 사유로 보고한다.

## Profile 사용

profile 위치 기본값:

- product repo: `.codex/multi-repo-issue-orchestration/profiles/<profile-id>.json`
- 로컬 Codex 환경: `$CODEX_HOME/automation-profiles/multi-repo-issue-orchestration/<profile-id>.json`
- 명시 경로: renderer의 `-Profile`에 JSON 파일 경로를 직접 전달

renderer:

```powershell
.\scripts\render-hub-prompt.ps1 -Profile <profile-id-or-json-path> -ProductRepoRoot <product-repo-root>
```

`-ProductRepoRoot`를 생략하면 현재 작업 디렉터리에서 product repo-local profile을 찾는다.

## Workflow

1. mode를 확인한다.
   - `Register`: 요구사항 group, hub issue, child issue, relationship만 구성한다.
   - `Execute`: 이미 등록된 issue 번호나 URL을 기준으로 child issue 실행과 product local package override만 조율한다.
   - 사용자가 단순히 이슈 등록을 요청했다면 `Register`로 처리하고 실행하지 않는다.
2. profile과 기존 Skill을 확인한다.
   - `profile-schema.md`와 profile required field를 검증한다.
   - product repo instruction과 module repo instruction을 읽는다.
   - profile 필드가 빠지면 GitHub 변경을 시작하지 말고 누락 필드를 보고한다.
3. 요구사항을 group으로 나누고 hub/single issue로 분류한다.
   - 서로 다른 목적, 완료 기준, 검증 경로, repository 영향은 별도 group으로 둔다.
   - 한 번의 사용자 입력에서 product 단일 issue, 같은 repo parent/sub issue, multi-repo hub issue가 여러 개 섞일 수 있다.
   - product-only, 독립 완료 기준 1개, package/API/DB/DTO/protocol 변경 없음, estimate가 `singleIssueMaxEstimateHours` 이하이면 product 단일 issue로 둔다.
   - module/package 변경, 공통 계약 변경, 둘 이상의 repo 검증 단위, 또는 estimate 초과면 product hub issue와 repo별 sub issue로 나눈다.
4. `Register` mode에서는 issue를 생성/갱신한다.
   - `issue-management`로 중복, canonical, metadata, relationship gate를 통과한다.
   - hub issue에는 전체 목적, repo별 작업 목록, 관계, product 통합 테스트 기준을 적는다.
   - sub issue에는 해당 repo에서 바로 구현 가능한 범위와 검증 계획만 적는다.
   - cross-repo sub issue는 GitHub native relationship을 먼저 시도하고, 실패하면 hub issue 본문에 child issue URL 목록으로 fallback한다.
   - branch/worktree/PR/package override 실행은 하지 않는다.
5. `Execute` mode에서는 작업 후보를 선별한다.
   - hub issue와 child issue의 `blocked-by`, Project status, active PR changed files를 확인한다.
   - child issue별 repo ownership rule을 적용한다.
   - 동시에 진행 가능한 child만 위임하고, overlap이 있으면 보류한다.
6. repo별 PR을 진행한다.
   - child issue는 각 repo worktree에서 `gh-issue-pr-review-loop`로 Draft PR까지 진행한다.
   - repo별 Todo 큐에서 추가 후보를 뽑아야 하면 해당 repo의 `todoProfile`로 `todo-issue-automation`을 실행한다.
7. product local test setup을 준비한다.
   - 필요한 module branch/PR이 준비된 뒤 `packageOverrides.setupCommands`만 실행한다.
   - `verifyCommands`로 product repo가 module branch를 바라보는지 확인한다.
   - command가 비어 있으면 package override setup은 blocked로 보고하고 임의 설정을 만들지 않는다.
   - `restoreCommands`와 변경된 local config path를 최종 보고에 포함한다.
8. 결과를 보고한다.
   - hub issue, child issue, 관계, 보류 사유, repo별 branch/PR, 검증 결과를 보고한다.
   - product local test 환경의 module branch 세팅 상태와 restore 방법을 보고한다.
   - merge하지 않았음을 명시한다.

## 완료 전 자체 체크

- product-only 단일 issue로 충분한 작업을 hub/sub issue로 과분해하지 않았는가?
- 여러 요구사항 입력에서 hub issue가 여러 개 나올 수 있음을 고려했는가?
- multi-repo/package/계약 변경 작업을 product issue 하나로 뭉개지 않았는가?
- Register mode에서 작업 실행을 하지 않았는가?
- 모든 child issue가 repo별 독립 완료 기준과 검증 계획을 가지는가?
- 열린 `blocked-by`, active PR overlap, partial preflight를 충돌 없음으로 해석하지 않았는가?
- product local override는 profile command만 사용했는가?
- product local override 변경이 의도치 않게 commit 대상에 들어가지 않았는가?

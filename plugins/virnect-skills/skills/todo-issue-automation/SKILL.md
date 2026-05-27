---
name: todo-issue-automation
description: "ProjectV2 Todo 이슈 자동화를 외부 profile로 실행하는 공통 워크플로우. 사용자가 저장소별 Todo 이슈를 충돌 없이 선별하고, worker에게 issue-to-PR/review loop를 위임하며, 저장된 Codex automation prompt를 공통 Skill+profile wrapper로 관리하라고 할 때 사용한다."
---

# Todo Issue Automation

ProjectV2의 `Todo` 이슈를 외부 profile 기준으로 수집하고, active 작업과 충돌하지 않는 후보만 worker에게 위임하는 자동화 지침이다.
이 Skill에는 공통 절차와 profile 계약만 둔다. 실제 저장소 profile은 대상 저장소나 로컬 Codex 환경에 둔다.

## 기본 원칙

- 사람이 확인하는 보고, GitHub issue/PR/comment/review 문구는 한국어로 작성한다.
- 저장소별 값은 profile JSON을 우선한다. repo, Project, base branch, worktree prefix, ownership, validation rule을 프롬프트 본문에 다시 하드코딩하지 않는다.
- 이슈 구현과 PR/review loop는 sibling Skill인 `gh-issue-pr-review-loop`를 사용한다.
- 이슈 본문 정리, 모호성 처리, relationship/preflight 판단은 sibling Skill인 `issue-management`를 사용한다.
- merge는 수행하지 않는다.
- 불확실한 작업 범위는 충돌 가능으로 분류하고 worker 위임 대상에서 제외한다.
- baseline 실패와 이번 변경 회귀를 분리해 보고한다.

## Profile 사용

profile을 추가하거나 수정할 때는 `references/profile-schema.md`를 먼저 읽고 required field를 유지한다.
이 Skill 폴더에는 실제 저장소 profile을 저장하지 않는다.

profile 위치 기본값:

- 대상 저장소: `.codex/todo-issue-automation/profiles/<profile-id>.json`
- 로컬 Codex 환경: `$CODEX_HOME/automation-profiles/todo-issue-automation/<profile-id>.json`
- 명시 경로: renderer의 `-Profile`에 JSON 파일 경로를 직접 전달

자동화 prompt를 생성하거나 검증할 때는 renderer를 사용한다.

```powershell
.\scripts\render-automation-prompt.ps1 -Profile <profile-id-or-json-path>
.\scripts\render-automation-prompt.ps1 -Profile <profile-id> -RepoRoot <target-repo-root>
```

`-RepoRoot`를 생략하면 현재 작업 디렉터리의 `.codex/todo-issue-automation/...`를 repo-local profile 탐색 기준으로 사용한다.
renderer 출력은 저장된 automation의 `prompt`에 넣는 얇은 wrapper다.
기존 automation을 갱신할 때는 schedule, status, model, reasoning effort, cwd, local environment config를 보존한다.

## 실행 절차

1. profile과 sibling Skill을 확인한다.
   - profile required field가 누락되면 자동화를 진행하지 말고 누락 field를 보고한다.
   - common Skill과 sibling Skill은 Skill 이름으로 참조하고, 설치 cache path를 프롬프트에 고정하지 않는다.
2. 자동화 전용 worktree를 만든다.
   - `sourceRoot`가 git 저장소이면 그 경로를 기준으로 사용한다.
   - 없거나 git 저장소가 아니면 현재 checkout의 `git rev-parse --show-toplevel` 결과를 fallback으로 사용한다.
   - `origin/<baseBranch>`를 fetch한 뒤 `worktreePrefix-<yyyyMMdd-HHmmss>`와 `branchPrefix-<yyyyMMdd-HHmmss>`로 bootstrap worktree/branch를 만든다.
3. 실행 전 진단을 수행한다.
   - `gh auth status`
   - `gh repo view <repoFullName>`
   - `git status --short --branch`
   - 인증, 접근 권한, fetch/worktree 생성, Project 조회가 막히면 이후 단계를 중단하고 실패 명령과 조치를 보고한다.
4. ProjectV2 상태를 수집한다.
   - profile의 `projectNumber`, `projectOwner`, `todoStatusName`, `inProgressStatusName`을 사용한다.
   - Project 상태와 실제 open PR/branch가 어긋나면 active 작업으로 간주한다.
5. active 수정 범위를 파악한다.
   - In Progress 이슈, 상태 불일치 active PR, 연결 branch의 diff를 확인한다.
   - profile의 `ownershipRules`를 적용해 파일뿐 아니라 같은 화면, DTO/model, API, DB, fixture, config, service ownership 충돌을 함께 판단한다.
6. Todo 후보 수정 범위를 추정한다.
   - 이슈 제목, 본문, 최신 코멘트, parent/sub issue, 코드 검색 결과, profile ownership rule을 사용한다.
   - 추정 신뢰도는 `확정`, `높은 가능성`, `불명확`으로 기록한다.
   - `불명확`은 worker 위임 대상에서 제외하고 필요한 정보를 보고한다.
7. 충돌 없는 후보를 선별한다.
   - active 수정 범위와 겹치는 Todo를 제외한다.
   - 남은 Todo끼리 ownership이 겹치면 그룹별 대표 선행 이슈 1개만 고른다.
   - 최대 worker 수는 profile의 `maxWorkers`를 넘기지 않는다.
8. worker에게 위임한다.
   - worker prompt에는 이슈 번호, 예상 수정 범위, 충돌 금지 ownership, 검증 기대치, profile 기반 preflight 인자를 포함한다.
   - worker에게 `gh-issue-pr-review-loop`와 `issue-management`를 사용하도록 지시한다.
   - worker는 각자 이슈별 branch/worktree를 사용하고 다른 작업자의 변경을 되돌리지 않는다.
9. 결과를 수집해 보고한다.
   - bootstrap worktree/branch
   - In Progress와 active PR 수정 범위
   - Todo 후보와 제외 사유
   - 선택한 이슈와 선택 이유
   - worker별 branch, PR URL, 커밋, 검증, GitHub review/comment URL, Ready 여부
   - 실패/차단 명령과 다음 조치

## Worker Prompt 필수 내용

worker prompt에는 아래 정보를 빠뜨리지 않는다.

- 저장소: profile `repoFullName`
- 기준 이슈 번호
- 기준 worktree와 base branch
- 예상 수정 범위와 충돌 금지 ownership
- preflight helper 인자: profile `preflightArgs`
- 사용할 Skill: `gh-issue-pr-review-loop`, 필요 시 `issue-management`
- 검증 기대치: profile `validationRules`
- GitHub-visible 문구는 한국어
- merge 금지

## 자동화 Prompt Migration

기존 stored automation을 wrapper prompt로 줄일 때는 renderer 출력만 `prompt`에 반영한다.
자동화 메모리 파일은 이동하거나 재작성하지 않는다.

Codex automation tool을 사용할 수 있으면 기존 automation을 view한 뒤 전체 필드를 보존하여 update한다.
worktree automation에서 `localEnvironmentConfigPath`를 유지해야 하는 경우에는 앱이 요구하는 방식에 맞춰 suggested update를 사용한다.

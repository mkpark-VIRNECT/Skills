---
name: gh-issue-pr-review-loop
description: "GitHub 이슈를 브랜치, 구현, 검증, 커밋, 푸시, PR, 독립 코드리뷰, 수정 반영까지 끝내는 실행 워크플로우. 사용자가 특정 GitHub 이슈를 처리하라고 하거나, 이슈 기반 PR을 만들고 review comments를 반영해 재검증·재리뷰해야 하거나, 착수 전 blocked-by 관계와 active PR 파일 충돌을 확인해야 할 때 사용한다. 저장소별 Project, milestone, assignee, 테스트 명령, base branch 관례를 현재 repo에서 확인해 적용한다."
---

# GitHub Issue PR Review Loop

명확한 GitHub 이슈를 실제 작업 브랜치와 PR로 연결하고, 독립 리뷰와 수정 반영 루프까지 닫는 절차다.
이슈가 바로 구현 가능한 수준이 아니면 먼저 `$issue-management`로 이슈 본문, 질문, 상태, 관계를 정리한다.

## 완료 조건

작업은 아래 조건을 모두 만족할 때 완료로 본다.

- 이슈 기준 브랜치가 생성되고 원격에 푸시되어 있다.
- 저장소가 Project/상태를 사용한다면 착수 상태가 `In Progress` 또는 저장소의 동등한 상태로 변경되어 있다.
- 구현, 문서, 테스트가 이슈 범위와 일치한다.
- PR 제목과 본문은 저장소 지침과 사용자의 언어에 맞게 작성되어 있고 이슈 번호가 연결되어 있다.
- 독립 리뷰가 GitHub PR에 남아 있고, 수정 요청이 있으면 반영 또는 반박 근거가 남아 있다.
- 수정 후 필요한 검증이 다시 실행되었고, 남은 blocking 요청이 없다.
- Draft PR로 시작했다면 마지막에 Ready for review 전환 여부가 판단되어 있다.

## 1. 저장소와 이슈 확인

1. GitHub 인증과 저장소를 확인한다.
   - `gh auth status`
   - `gh repo view --json nameWithOwner,defaultBranchRef`
2. 저장소 지침을 읽는다.
   - `AGENTS.md`, `.github/pull_request_template*`, `README*`, 기존 PR 본문을 우선 확인한다.
   - 사용자에게 보이는 이슈/PR/리뷰/보고 언어는 저장소 지침과 현재 대화 언어를 따른다.
3. 이슈 본문, 코멘트, 상태, assignee, labels, milestone, Project, 기존 브랜치, 기존 PR을 확인한다.
   - GitHub 앱 도구를 우선 사용하고, 필요한 정보가 빠지면 `gh` CLI로 전환한다.
   - `gh issue view <issue-number> --comments`
   - `gh pr list --state all --search "<issue-number>"`
   - `gh pr list --state all --head <branch-name>`
4. 이슈가 작업 가능한지 판단한다.
   - 목적, 완료 기준, 작업 계획, 검증 계획이 불명확하면 구현하지 말고 `$issue-management`로 질문과 상태를 정리한다.
   - 이미 PR이 있으면 새 PR을 만들지 말고 현재 PR 상태와 `origin/<base>` 대비 diff를 확인해 이어서 작업한다.
   - 브랜치만 있고 PR이 없으면 브랜치 최신성, 이슈 상태, 실제 diff를 함께 확인한다.

## 2. 관계와 충돌 Preflight

가능하면 `$issue-management`의 helper를 사용한다. 전역 설치와 repo 로컬 설치를 모두 확인한다.

```powershell
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$preflight = Join-Path $codexHome "skills\issue-management\scripts\gh-issue-preflight.ps1"
if (-not (Test-Path -LiteralPath $preflight)) {
    $preflight = ".agents\skills\issue-management\scripts\gh-issue-preflight.ps1"
}
```

사용 시점별 mode:

- 착수 후보 확인: `& $preflight -Issue <issue-number> -Mode Startup -Json`
- 상태 변경 직전: `& $preflight -Issue <issue-number> -Mode StatusTransition -Json`
- PR 발행 직전 또는 변경 범위 확대 후: `& $preflight -Issue <issue-number> -Mode PrConflict -Json`
- 보고, PR 본문, 리뷰 위임용 완전 컨텍스트: `& $preflight -Issue <issue-number> -Mode Full -Json`

해석 규칙:

- 열린 `blockedBy`가 있으면 새 브랜치를 만들거나 `In Progress`로 바꾸지 말고 선행 조건을 보고한다.
- 같은 화면, 모델, DTO, service, repository, protocol, generated file, E2E fixture를 active PR이 수정 중이면 병렬 착수를 보류하거나 PR 본문에 충돌 위험을 명시한다.
- `partial=true` 또는 `skippedLookups`가 있으면 조회 생략 결과다. `softConflicts=[]`나 `overlappingPrs=[]`를 충돌 없음으로 해석하지 않는다.
- helper를 사용할 수 없으면 target issue의 `parent`, `subIssues`, `blockedBy`, `blocking`, Project status, 연결 active PR 파일군을 직접 최소 조회한다.

## 3. 브랜치와 상태 설정

1. 작업트리를 보호한다.
   - `git status --short --branch`
   - 사용자 또는 다른 작업자의 변경으로 보이는 파일은 되돌리지 않는다.
   - 현재 checkout이 더러우면 새 worktree를 우선 검토한다.
2. 브랜치를 만든다.
   - 기본 형식: `codex/issue-<issue-number>-<short-slug>`
   - 저장소에 명시된 branch naming 규칙이 있으면 그 규칙을 우선한다.
   - 이미 적절한 브랜치가 있으면 새로 만들지 말고 기존 브랜치와 PR을 확인한다.
3. 이슈의 작업 상태를 갱신한다.
   - 저장소가 ProjectV2를 쓰면 `In Progress` 또는 동등한 상태로 변경한다.
   - Project/상태 필드가 없거나 권한이 없으면 이슈 코멘트에 브랜치 링크와 작업 시작 사실을 남긴다.
   - PR 본문에는 `Closes #<issue-number>`, `Fixes #<issue-number>`, 또는 저장소 관례에 맞는 연결 문구를 포함한다.

## 4. 구현

1. 이슈 범위에 맞는 repo-specific 스킬이나 지침을 먼저 사용한다.
   - 프론트엔드, 백엔드, 문서, 테스트, 배포 등 도메인별 스킬이 있으면 해당 스킬을 읽는다.
   - 명시된 스킬이 없으면 기존 코드 패턴, AGENTS.md, README, package scripts, CI 설정을 기준으로 한다.
2. 최신 요구사항 기준으로 구현한다.
   - 이슈 본문보다 최신 코멘트가 더 구체적이면 코멘트를 우선한다.
   - API, DB schema, protocol, DTO 같은 계약 변경은 구현, 테스트, 문서 갱신을 함께 처리한다.
   - 범위 밖 리팩터링은 하지 않는다.
3. 새 불확실성이 발견되면 구현을 멈춘다.
   - 이슈 본문 또는 코멘트에 질문을 추가한다.
   - Project 상태가 있다면 `Issue Review` 또는 저장소의 동등한 상태로 되돌린다.
   - 사용자에게 어떤 판단이 필요한지 보고한다.

## 5. 검증과 커밋

1. 변경 범위에 맞는 최소 검증부터 실행한다.
   - 저장소 문서, package scripts, CI workflow, 기존 PR의 검증 기록에서 명령을 찾는다.
   - 예: `dotnet test`, `npm test`, `pnpm test`, `pytest`, `flutter test`, lint/analyze, 문서 검증 스크립트.
2. 실패를 분류한다.
   - 이번 변경의 회귀와 base branch의 기존 실패를 분리해 기록한다.
   - 환경 문제로 막히면 재현 명령, 실패 원인, 남은 리스크를 PR 본문 또는 코멘트에 남긴다.
3. 커밋한다.
   - `git status --short`로 내 변경만 확인한다.
   - 관련 파일만 stage한다.
   - 커밋 메시지는 저장소 관례와 사용자 언어에 맞춰 간결하게 작성한다.

## 6. PR 발행

PR 생성 직전에는 `PrConflict` preflight로 `origin/<base>...HEAD` 실제 변경 파일과 active PR 파일 목록을 다시 비교한다.
`localDiffStatus`가 `ok-empty` 또는 `ok-changed`가 아니면 파일 충돌 판단을 ready로 보지 말고 원인을 확인한다.

1. 브랜치를 푸시한다.
   - 일반 push를 우선한다.
   - rebase 후 필요한 경우에만 `--force-with-lease`를 사용하고 이유를 기록한다.
2. PR은 기본적으로 draft로 만든다.
   - 사용자가 ready PR을 명시하거나 저장소 관례가 다르면 그 지시를 우선한다.
   - 본문 초반에 요약 작업 목록을 둔다.
   - 중요한 로직 변화, 검증 결과, 미검증/차단 항목을 구분한다.
   - 이슈 연결 문구와 preflight 요약을 포함한다.
3. 이슈에 PR 링크를 남긴다.
   - GitHub Development 필드에 자동 반영되지 않으면 이슈 코멘트로 브랜치와 PR을 연결한다.

## 7. 독립 리뷰 위임

리뷰는 PR이 생성되고 로컬 검증 결과가 정리된 뒤 위임한다.
가능하면 서브에이전트나 독립 리뷰 도구를 사용하고, 없으면 별도 pass로 PR diff를 리뷰해 GitHub-visible 코멘트를 남긴다.

리뷰 프롬프트 형식:

```text
PR <PR 번호>를 코드리뷰해 주세요.

- 저장소: <owner/repo>
- 기준 이슈: #<issue-number>
- PR URL: <url>
- Relationship/충돌 preflight: <blocked-by, parent/sub-issue, overlapping PR, 충돌 위험 파일 요약>
- 리뷰 코멘트는 GitHub PR에 <저장소/사용자 언어>로 남겨 주세요.
- 버그, 회귀, 계약 불일치, 누락된 테스트를 우선 검토해 주세요.
- 선행 이슈나 active PR과의 작업 순서, stale relationship, 파일군 충돌 가능성도 같이 검토해 주세요.
- 수정 요청이 있으면 파일/라인/재현 조건을 구체적으로 적어 주세요.
- 작성자 본인 PR이라 REQUEST_CHANGES가 거부되면 COMMENT review 또는 PR 코멘트로 남겨 주세요.
- 코드 수정은 하지 말고 리뷰 결과와 남긴 코멘트 URL만 보고해 주세요.
```

리뷰 후 다음을 확인한다.

- 리뷰어의 최종 보고
- PR review thread와 top-level PR comment
- GitHub에 실제 코멘트가 남았는지

## 8. 수정 요청 반영 루프

리뷰에서 수정 요청이 있으면 아래 루프를 반복한다.

1. 수정 요청을 severity와 파일 단위로 정리한다.
2. 실제 결함 또는 요구사항 불일치면 코드, 테스트, 문서를 수정한다.
3. 타당하지 않은 지적이면 근거를 PR 코멘트로 설명한다.
4. 검증을 다시 실행한다.
5. 변경 파일군이 넓어졌으면 `PrConflict` 또는 `Full` preflight를 다시 실행한다.
6. 새 커밋을 만들고 push한다.
7. 관련 review thread에는 반영 내용 또는 반영하지 않은 이유를 답글로 남긴다.
8. 같은 PR에 재리뷰를 다시 위임한다.

루프 종료 조건:

- 남은 blocking 수정 요청이 없다.
- 반복되는 의견이 요구사항 판단 문제라면 이슈를 `Issue Review` 또는 동등한 상태로 되돌리고 사용자 확인 질문을 남긴다.
- GitHub 코멘트 작성이 실패하면 로컬 요약만으로 완료 처리하지 말고 실패 사유와 재시도 방법을 보고한다.

## 9. Ready 전환과 마무리

1. Draft PR이면 수정 요청이 없어진 뒤 Ready for review 전환 여부를 판단한다.
   - `gh pr ready <pr-number>`
2. PR 본문이 오래되었으면 최종 검증 결과와 남은 리스크를 갱신한다.
3. 이슈에는 현재 브랜치, PR, 리뷰 완료 상태를 코멘트로 남긴다.
4. 최종 보고에는 이슈 번호, 브랜치, PR URL, 커밋 요약, 검증 결과, 리뷰 결과, 재작업 여부, Ready 전환 여부를 포함한다.

## 주의 사항

- self-authored PR에 `APPROVE` 또는 `REQUEST_CHANGES`가 거부될 수 있다. 이 경우 `COMMENT` review로 전환한다.
- GitHub connector가 실패하면 `gh` CLI로 우회한다.
- 사용자가 GitHub-visible 산출물을 요구한 경우 리뷰 코멘트와 진행 코멘트는 실제 GitHub에 남긴다.
- long-running 테스트는 중간 로그와 산출물 경로를 남긴다.
- merge는 사용자가 명시하지 않으면 수행하지 않는다.
- unrelated 파일, 사용자 변경, 생성된 임시 파일은 stage하지 않는다.

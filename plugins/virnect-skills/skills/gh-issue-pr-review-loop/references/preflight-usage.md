# Preflight 사용법

관계와 active PR 충돌을 확인해야 할 때 읽는다.
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

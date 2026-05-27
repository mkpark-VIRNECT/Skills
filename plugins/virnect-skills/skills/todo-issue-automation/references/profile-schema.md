# Profile Schema

`todo-issue-automation` profile은 저장소별 자동화 차이를 담는 JSON 파일이다.
공통 workflow는 `SKILL.md`에 두고, repo/project/path/ownership/validation 차이만 profile에 둔다.

## Required Fields

- `id`: 짧은 profile id. 예: `project-a`, `project-b`
- `displayName`: 보고용 이름
- `repoFullName`: GitHub `owner/repo`
- `repoUrl`: GitHub URL
- `sourceRoot`: 우선 사용할 로컬 저장소 root
- `projectOwner`: GitHub Project owner
- `projectNumber`: GitHub ProjectV2 번호
- `projectTitle`: 보고용 Project 이름
- `baseBranch`: 기준 branch
- `todoStatusName`: Todo 상태명
- `inProgressStatusName`: In Progress 상태명
- `maxWorkers`: 한 실행에서 동시에 위임할 최대 worker 수
- `worktreePrefix`: bootstrap worktree folder prefix
- `branchPrefix`: bootstrap branch prefix
- `repoInstructionPaths`: 저장소 지침 후보 경로 배열
- `preflightArgs`: `gh-issue-preflight.ps1`에 넘길 기본 인자 object
- `ownershipRules`: 충돌 판정에 사용할 ownership rule 배열
- `validationRules`: worker 검증 기대치 배열
- `reportingRules`: 최종 보고에 포함할 항목 배열

## Rules

- JSON은 comments 없이 UTF-8로 저장한다.
- `preflightArgs`에는 최소 `Repo`, `ProjectOwner`, `ProjectNumber`, `Base`를 둔다.
- status 이름은 Project에 실제로 표시되는 문자열과 맞춘다.
- path 값은 Windows 경로를 JSON escape 규칙에 맞게 `\\`로 쓴다.
- profile은 설치 cache path나 공통 Skill 경로를 포함하지 않는다. Skill은 automation prompt에서 이름으로 참조한다.
- 실제 profile은 이 Skill 저장소에 넣지 않는다. 대상 저장소의 `.codex/todo-issue-automation/profiles/` 또는 로컬 `$CODEX_HOME/automation-profiles/todo-issue-automation/` 아래에 둔다.
- repo-local profile 탐색은 renderer의 `-RepoRoot` 값, 또는 `-RepoRoot`가 없으면 현재 작업 디렉터리를 기준으로 한다.
- repo-specific ownership은 구체적으로 쓴다. 파일 경로만 쓰지 말고 UI 화면, DTO/model, API/DB/service, fixture/config 같은 logical ownership도 포함한다.

## Example Shape

```json
{
  "id": "example",
  "displayName": "Example Todo Automation",
  "repoFullName": "owner/repo",
  "repoUrl": "https://github.com/owner/repo",
  "sourceRoot": "D:\\Git\\Projects\\Repo",
  "projectOwner": "owner",
  "projectNumber": 1,
  "projectTitle": "Project",
  "baseBranch": "master",
  "todoStatusName": "Todo",
  "inProgressStatusName": "In Progress",
  "maxWorkers": 3,
  "worktreePrefix": "repo-todo",
  "branchPrefix": "codex/automation/repo-todo",
  "repoInstructionPaths": ["AGENTS.md", ".github/copilot-instructions.md"],
  "preflightArgs": {
    "Repo": "owner/repo",
    "ProjectOwner": "owner",
    "ProjectNumber": 1,
    "Base": "master"
  },
  "ownershipRules": ["same API contract", "same DB entity/table"],
  "validationRules": ["Run changed-area tests first, then broader validation when risk is high."],
  "reportingRules": ["Report selected issues, exclusion reasons, PR URLs, verification, and blockers."]
}
```

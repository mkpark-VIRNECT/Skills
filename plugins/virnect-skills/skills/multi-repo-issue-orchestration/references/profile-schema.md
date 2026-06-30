# Profile Schema

`multi-repo-issue-orchestration` profile은 product hub issue와 여러 repo/module 작업을 연결하는 JSON 파일이다.
공통 workflow는 `SKILL.md`에 두고, repo/project/path/ownership/validation/package override 차이만 profile에 둔다.
일반 사용자의 이슈 등록 진입점은 `issue-management`이며, 이 profile은 multi-repo 판단이 필요할 때 helper로 사용한다.

## Required Fields

- `id`: 짧은 profile id.
- `displayName`: 보고용 이름.
- `hub`: product hub issue를 만들 product repository와 ProjectV2 설정.
- `repos`: product/module repository 목록.
- `issueSplitRules`: 단일 issue 허용 기준. `singleIssueMaxEstimateHours`는 없으면 8로 해석한다.
- `packageOverrides`: product local test 환경에서 module branch를 연결/검증/복원하는 command 묶음.
- `reportingRules`: 최종 보고에 포함할 항목 배열.

## `hub`

Required:

- `repoFullName`: GitHub `owner/repo`.
- `repoUrl`: GitHub URL.
- `sourceRoot`: product repo local root.
- `projectOwner`: GitHub Project owner.
- `projectNumber`: GitHub ProjectV2 번호.
- `projectTitle`: 보고용 Project 이름.
- `baseBranch`: 기준 branch.
- `todoStatusName`: Todo 상태명.
- `inProgressStatusName`: In Progress 상태명.
- `issueReviewStatusName`: review 대기 상태명.
- `repoInstructionPaths`: product repo 지침 후보 경로 배열.

## `repos`

각 항목 required:

- `id`: repo 식별자.
- `role`: `product` 또는 `module`.
- `displayName`: 보고용 이름.
- `repoFullName`: GitHub `owner/repo`.
- `repoUrl`: GitHub URL.
- `sourceRoot`: local repo root.
- `baseBranch`: 기준 branch.
- `todoProfile`: 해당 repo의 `todo-issue-automation` profile id 또는 JSON 경로.
- `repoInstructionPaths`: repo 지침 후보 경로 배열.
- `ownershipRules`: 충돌 판정에 사용할 ownership rule 배열.
- `validationRules`: child issue/PR 검증 기대치 배열.

## `issueSplitRules`

- `singleIssueMaxEstimateHours`: product-only 단일 issue 허용 최대 estimate. 없으면 8.

단일 issue 조건:

- product repo 변경만 있다.
- 독립 완료 기준이 1개다.
- module package, API, DB, DTO, protocol 변경이 없다.
- estimate가 `singleIssueMaxEstimateHours` 이하이다.

그 외에는 product hub issue와 repo별 child issue로 나눈다.
한 번의 사용자 입력에 여러 독립 requirement group이 있으면 hub issue도 여러 개 생길 수 있다.

## `packageOverrides`

Required fields:

- `setupCommands`: product repo에서 module branch/package override를 설정하는 command 배열.
- `verifyCommands`: product repo가 기대 branch/package를 바라보는지 확인하는 command 배열.
- `restoreCommands`: 사용 후 local override를 되돌리는 command 배열.

Optional fields:

- `expectedChangedPaths`: local override가 바꿀 수 있는 product repo path 배열.
- `notes`: 보고에 포함할 주의사항 배열.

command 배열이 비어 있으면 Codex는 임의 package manager 설정을 만들지 말고 local test setup을 blocked로 보고한다.
registration 단계에서는 이 command들을 실행하지 않는다. 기존 issue 번호/URL을 받은 execution 단계에서만 실행한다.

## Example Shape

```json
{
  "id": "product-suite",
  "displayName": "Product Suite Multi Repo",
  "hub": {
    "repoFullName": "owner/product",
    "repoUrl": "https://github.com/owner/product",
    "sourceRoot": "D:\\Git\\Products\\Product",
    "projectOwner": "owner",
    "projectNumber": 1,
    "projectTitle": "Product",
    "baseBranch": "master",
    "todoStatusName": "Todo",
    "inProgressStatusName": "In Progress",
    "issueReviewStatusName": "Issue Review",
    "repoInstructionPaths": ["AGENTS.md", ".github/copilot-instructions.md"]
  },
  "repos": [
    {
      "id": "product",
      "role": "product",
      "displayName": "Product",
      "repoFullName": "owner/product",
      "repoUrl": "https://github.com/owner/product",
      "sourceRoot": "D:\\Git\\Products\\Product",
      "baseBranch": "master",
      "todoProfile": "product",
      "repoInstructionPaths": ["AGENTS.md"],
      "ownershipRules": ["same product integration flow", "same package lock/config"],
      "validationRules": ["Run product integration checks after module branches are linked."]
    },
    {
      "id": "module-a",
      "role": "module",
      "displayName": "Module A",
      "repoFullName": "owner/module-a",
      "repoUrl": "https://github.com/owner/module-a",
      "sourceRoot": "D:\\Git\\Packages\\ModuleA",
      "baseBranch": "master",
      "todoProfile": "module-a",
      "repoInstructionPaths": ["AGENTS.md"],
      "ownershipRules": ["same public package API", "same generated artifacts"],
      "validationRules": ["Run changed-area package tests before opening PR."]
    }
  ],
  "issueSplitRules": {
    "singleIssueMaxEstimateHours": 8
  },
  "packageOverrides": {
    "setupCommands": [
      "pwsh -File .\\.codex\\package-overrides\\use-module-branches.ps1"
    ],
    "verifyCommands": [
      "pwsh -File .\\.codex\\package-overrides\\verify-module-branches.ps1"
    ],
    "restoreCommands": [
      "pwsh -File .\\.codex\\package-overrides\\restore.ps1"
    ],
    "expectedChangedPaths": [
      "package-lock.json",
      "Packages/manifest.json"
    ],
    "notes": [
      "Do not commit local package override files unless the product issue explicitly includes them."
    ]
  },
  "reportingRules": [
    "Report hub issue, child issues, relationships, PR URLs, validation, blocked work, package override status, and restore commands."
  ]
}
```

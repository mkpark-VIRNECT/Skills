[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Profile,

    [string]$SkillRoot = "",

    [string]$RepoRoot = "",

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-SkillRoot {
    param([string]$InputPath)

    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        return (Resolve-Path -LiteralPath $InputPath).Path
    }

    return (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
}

function Resolve-ProfilePath {
    param(
        [string]$ProfileValue,
        [string]$ResolvedSkillRoot,
        [string]$RepositoryRoot
    )

    if (Test-Path -LiteralPath $ProfileValue) {
        return (Resolve-Path -LiteralPath $ProfileValue).Path
    }

    $candidates = @()
    $repoRootPath = if (-not [string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        (Resolve-Path -LiteralPath $RepositoryRoot).Path
    } else {
        (Get-Location).Path
    }
    $candidates += (Join-Path $repoRootPath ".codex\todo-issue-automation\profiles\$ProfileValue.json")
    $candidates += (Join-Path $repoRootPath ".codex\todo-issue-automation\$ProfileValue.json")

    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
    $candidates += (Join-Path $codexHome "automation-profiles\todo-issue-automation\$ProfileValue.json")
    $candidates += (Join-Path $codexHome "todo-issue-automation\profiles\$ProfileValue.json")

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Profile '$ProfileValue' was not found. Pass a JSON path, pass -RepoRoot for a repo-local profile, or create one under CODEX_HOME\automation-profiles\todo-issue-automation."
}

function Assert-RequiredField {
    param(
        [pscustomobject]$Object,
        [string[]]$Fields
    )

    $names = @($Object.PSObject.Properties.Name)
    $missing = @()
    foreach ($field in $Fields) {
        if ($names -notcontains $field) {
            $missing += $field
            continue
        }

        $value = $Object.$field
        if ($null -eq $value) {
            $missing += $field
            continue
        }

        if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
            $missing += $field
        }
    }

    if ($missing.Count -gt 0) {
        throw "Profile is missing required field(s): $($missing -join ', ')"
    }
}

function Get-PropertyValue {
    param(
        [pscustomobject]$Object,
        [string]$Field
    )

    $property = $Object.PSObject.Properties[$Field]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Format-BulletList {
    param([object]$Items)

    $lines = @()
    foreach ($item in @($Items)) {
        $lines += "- $item"
    }
    return ($lines -join [Environment]::NewLine)
}

function Format-InstructionPaths {
    param([object]$Items)

    $lines = @()
    foreach ($item in @($Items)) {
        $lines += "- ``$item``"
    }
    return ($lines -join [Environment]::NewLine)
}

function Format-PreflightArgs {
    param([pscustomobject]$ArgsObject)

    $parts = @()
    foreach ($property in @($ArgsObject.PSObject.Properties)) {
        $name = $property.Name
        $value = $property.Value
        $parts += "-$name $value"
    }
    return ($parts -join " ")
}

$resolvedSkillRoot = Resolve-SkillRoot -InputPath $SkillRoot
$profilePath = Resolve-ProfilePath -ProfileValue $Profile -ResolvedSkillRoot $resolvedSkillRoot -RepositoryRoot $RepoRoot
$profileObject = Get-Content -Raw -Encoding UTF8 -LiteralPath $profilePath | ConvertFrom-Json

$requiredFields = @(
    "id",
    "displayName",
    "repoFullName",
    "repoUrl",
    "sourceRoot",
    "projectOwner",
    "projectNumber",
    "projectTitle",
    "baseBranch",
    "todoStatusName",
    "inProgressStatusName",
    "maxWorkers",
    "worktreePrefix",
    "branchPrefix",
    "repoInstructionPaths",
    "preflightArgs",
    "ownershipRules",
    "validationRules",
    "reportingRules"
)
Assert-RequiredField -Object $profileObject -Fields $requiredFields
Assert-RequiredField -Object $profileObject.preflightArgs -Fields @("Repo", "ProjectOwner", "ProjectNumber", "Base")

if ([int]$profileObject.maxWorkers -lt 1) {
    throw "Profile maxWorkers must be greater than zero."
}

$candidateSplitPolicy = Get-PropertyValue -Object $profileObject -Field "candidateSplitPolicy"
$splitEnabled = $true
$splitRequireParentInTodoQueue = $true
$splitMaxChildIssuesPerRun = 1
if ($null -ne $candidateSplitPolicy) {
    $enabled = Get-PropertyValue -Object $candidateSplitPolicy -Field "enabled"
    if ($null -ne $enabled) {
        $splitEnabled = [bool]$enabled
    }

    $requireParentInTodoQueue = Get-PropertyValue -Object $candidateSplitPolicy -Field "requireParentInTodoQueue"
    if ($null -ne $requireParentInTodoQueue) {
        $splitRequireParentInTodoQueue = [bool]$requireParentInTodoQueue
    }

    $maxChildIssuesPerRun = Get-PropertyValue -Object $candidateSplitPolicy -Field "maxChildIssuesPerRun"
    if ($null -ne $maxChildIssuesPerRun) {
        $splitMaxChildIssuesPerRun = [int]$maxChildIssuesPerRun
    }
}

if ($splitMaxChildIssuesPerRun -lt 1) {
    throw "Profile candidateSplitPolicy.maxChildIssuesPerRun must be greater than zero."
}

$splitModeText = if ($splitEnabled) { "enabled" } else { "disabled" }
$splitActionText = if ($splitEnabled) {
    "split-required broad parent는 조건을 모두 만족할 때 issue-management Register mode로 child issue만 등록한다."
} else {
    "split-required broad parent는 child issue를 등록하지 않고 사유만 보고한다."
}

$prompt = @"
ProjectV2 Todo 이슈 자동화를 실행한다.

## 공통 Skill과 profile
- 공통 자동화 Skill: todo-issue-automation
- 저장소 profile: $profilePath
- profile schema: todo-issue-automation/references/profile-schema.md
- 이슈 관리 Skill: issue-management
- PR/review loop Skill: gh-issue-pr-review-loop

## 기본 원칙
- 위 파일들을 먼저 읽고, profile 값을 저장소별 단일 원천으로 사용한다.
- 저장소명, Project 번호, 상태명, source root, worktree/branch prefix, ownership/validation/reporting rule은 profile에서만 가져온다.
- 공통 절차는 공통 자동화 Skill을 따른다.
- 사람이 확인하는 보고와 GitHub issue/PR/comment/review 문구는 한국어로 작성한다.
- merge는 수행하지 않는다.
- 불확실한 작업 범위는 충돌 가능으로 분류하고 바로 구현하지 않는다.
- broad parent 이슈는 직접 구현하지 않는다.

## Candidate split policy
- mode: $splitModeText
- requireParentInTodoQueue: $splitRequireParentInTodoQueue
- maxChildIssuesPerRun: $splitMaxChildIssuesPerRun
- $splitActionText

## 실행 절차
1. profile schema와 profile required field를 검증한다.
2. profile에 정의된 저장소와 ProjectV2에서 Todo/In Progress issue 및 active PR/branch를 수집한다.
3. Todo 후보를 direct, split-required, defer로 분류하고 existing open child가 있으면 parent를 재분해하지 말고 child만 평가한다.
4. split-required는 parent가 Todo 큐에 있고, native child/본문 child URL 중복이 없고, child별 scope/non-scope/완료 기준/검증 계획/Assignee/Project Status/Size/Estimate가 확정된 경우에만 Register mode로 child issue를 만든다.
5. child 등록 뒤 Project/relationship을 재조회하고 실행 대상은 child issue만 삼는다. child PR close keyword는 child에만 쓰고 parent는 Refs 또는 Part of로만 참조한다.
6. profile ownership rule로 충돌 없는 Todo 후보를 선별한다.
7. 선별된 이슈를 profile maxWorkers 범위에서 worker에게 위임한다.
8. worker prompt에는 profile 기반 preflight 인자, 예상 수정 범위, 충돌 금지 ownership, 검증 기대치, 사용할 Skill 경로와 아래 PR 메타데이터 계약을 포함한다.
   - ``gh api user --jq .login`` 실행 계정을 확인하고 ``gh pr create --assignee '@me'`` 또는 ``gh pr edit --add-assignee '@me'``로 PR assignee를 지정한다.
   - 새 branch는 첫 push 전에 ``gh issue develop <issue> --base <base> --name <branch>``로 구현 source issue에 연결한다.
   - source issue 제목/본문에 ``\b[A-Z][A-Z0-9]+-\d+\b`` Jira key가 있으면 ``jiraKeyStatus=required``, 없으면 GitHub-only인 ``jiraKeyStatus=not-applicable``로 기록한다. ``not-applicable``은 key 없이 성공할 수 있다.
   - 구현 source issue(분해한 경우 child)만 PR 본문의 ``Closes``/``Fixes``로 연결하고 parent/hub issue는 ``Refs``/``Part of``로만 참조한다.
9. PR 생성 직후와 Ready/완료 판정 직전에 실행 계정 assignee, 구현 source issue의 ``closingIssuesReferences``, ``gh issue develop --list <issue>``의 linked branch를 검증한다. ``jiraKeyStatus=required``일 때만 PR 제목/head branch의 모든 Jira key와 각 Jira issue Development의 branch/PR 동기화를 30초 간격으로 최대 3회 검증하고, ``not-applicable``이면 Jira 조회를 생략한다.
10. postcondition 하나라도 실패한 worker는 완료 또는 Ready로 집계하지 않고 Draft/blocked 상태와 실패 항목을 보고한다.
11. worker 결과에 branch, PR URL, 커밋, 검증, review/comment URL, ``jiraKeyStatus``, Ready 여부를 포함해 profile reporting rule에 맞춰 최종 보고한다.
12. 작업 대상이 없으면 split-required 조건부 child 등록 예외를 제외하고 새 이슈를 만들지 말고, 어떤 기준으로 대상이 없다고 판단했는지만 보고한다.
"@

if ($Json) {
    [pscustomobject]@{
        profile = $profileObject.id
        profilePath = $profilePath
        candidateSplitPolicy = [pscustomobject]@{
            enabled = $splitEnabled
            requireParentInTodoQueue = $splitRequireParentInTodoQueue
            maxChildIssuesPerRun = $splitMaxChildIssuesPerRun
        }
        prompt = $prompt
    } | ConvertTo-Json -Depth 8
} else {
    $prompt
}

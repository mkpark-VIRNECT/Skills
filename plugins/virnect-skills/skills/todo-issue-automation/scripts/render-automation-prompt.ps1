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

## 실행 절차
1. profile schema와 profile required field를 검증한다.
2. profile에 정의된 저장소와 ProjectV2에서 Todo/In Progress issue 및 active PR/branch를 수집한다.
3. profile ownership rule로 충돌 없는 Todo 후보를 선별한다.
4. 선별된 이슈를 profile maxWorkers 범위에서 worker에게 위임한다.
5. worker prompt에는 profile 기반 preflight 인자, 예상 수정 범위, 충돌 금지 ownership, 검증 기대치, 사용할 Skill 경로를 포함한다.
6. worker 결과를 모아 profile reporting rule에 맞춰 최종 보고한다.
7. 작업 대상이 없으면 새 이슈를 만들지 말고, 어떤 기준으로 대상이 없다고 판단했는지만 보고한다.
"@

if ($Json) {
    [pscustomobject]@{
        profile = $profileObject.id
        profilePath = $profilePath
        prompt = $prompt
    } | ConvertTo-Json -Depth 8
} else {
    $prompt
}

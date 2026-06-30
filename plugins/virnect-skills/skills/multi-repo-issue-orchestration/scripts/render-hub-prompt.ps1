[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Profile,

    [string]$SkillRoot = "",

    [string]$ProductRepoRoot = "",

    [ValidateSet("Register", "Execute")]
    [string]$Action = "Register",

    [string[]]$Issues = @(),

    [string]$HubIssue = "",

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
        [string]$RepositoryRoot
    )

    if (Test-Path -LiteralPath $ProfileValue) {
        return (Resolve-Path -LiteralPath $ProfileValue).Path
    }

    $repoRootPath = if (-not [string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        (Resolve-Path -LiteralPath $RepositoryRoot).Path
    } else {
        (Get-Location).Path
    }

    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
    $candidates = @(
        (Join-Path $repoRootPath ".codex\multi-repo-issue-orchestration\profiles\$ProfileValue.json"),
        (Join-Path $repoRootPath ".codex\multi-repo-issue-orchestration\$ProfileValue.json"),
        (Join-Path $codexHome "automation-profiles\multi-repo-issue-orchestration\$ProfileValue.json"),
        (Join-Path $codexHome "multi-repo-issue-orchestration\profiles\$ProfileValue.json")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Profile '$ProfileValue' was not found. Pass a JSON path, pass -ProductRepoRoot for a repo-local profile, or create one under CODEX_HOME\automation-profiles\multi-repo-issue-orchestration."
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

function Assert-RequiredField {
    param(
        [pscustomobject]$Object,
        [string[]]$Fields,
        [string]$Path
    )

    if ($null -eq $Object) {
        throw "$Path is missing."
    }

    $missing = @()
    foreach ($field in $Fields) {
        $value = Get-PropertyValue -Object $Object -Field $field
        if ($null -eq $value) {
            $missing += "$Path.$field"
            continue
        }

        if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
            $missing += "$Path.$field"
        }
    }

    if ($missing.Count -gt 0) {
        throw "Profile is missing required field(s): $($missing -join ', ')"
    }
}

function Assert-ArrayField {
    param(
        [pscustomobject]$Object,
        [string]$Field,
        [string]$Path,
        [switch]$AllowEmpty
    )

    $property = $Object.PSObject.Properties[$Field]
    if ($null -eq $property) {
        throw "Profile is missing required field(s): $Path.$Field"
    }

    $value = $property.Value
    if ($null -eq $value) {
        if ($AllowEmpty) {
            return
        }
        throw "Profile field must not be empty: $Path.$Field"
    }

    $items = @($value)
    if (-not $AllowEmpty -and $items.Count -eq 0) {
        throw "Profile field must not be empty: $Path.$Field"
    }
}

function Format-BulletList {
    param(
        [object]$Items,
        [string]$EmptyText = "(none configured)"
    )

    $itemsArray = @($Items)
    if ($itemsArray.Count -eq 0) {
        return "- $EmptyText"
    }

    $lines = @()
    foreach ($item in $itemsArray) {
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

function Format-RepoSummary {
    param([object]$Repos)

    $lines = @()
    foreach ($repo in @($Repos)) {
        $lines += "- $($repo.id) [$($repo.role)]: $($repo.repoFullName), sourceRoot=$($repo.sourceRoot), base=$($repo.baseBranch), todoProfile=$($repo.todoProfile)"
    }
    return ($lines -join [Environment]::NewLine)
}

$resolvedSkillRoot = Resolve-SkillRoot -InputPath $SkillRoot
$profilePath = Resolve-ProfilePath -ProfileValue $Profile -RepositoryRoot $ProductRepoRoot
$profileObject = Get-Content -Raw -Encoding UTF8 -LiteralPath $profilePath | ConvertFrom-Json

Assert-RequiredField -Object $profileObject -Path "profile" -Fields @(
    "id",
    "displayName",
    "hub",
    "repos",
    "issueSplitRules",
    "packageOverrides",
    "reportingRules"
)

Assert-RequiredField -Object $profileObject.hub -Path "profile.hub" -Fields @(
    "repoFullName",
    "repoUrl",
    "sourceRoot",
    "projectOwner",
    "projectNumber",
    "projectTitle",
    "baseBranch",
    "todoStatusName",
    "inProgressStatusName",
    "issueReviewStatusName",
    "repoInstructionPaths"
)
Assert-ArrayField -Object $profileObject.hub -Path "profile.hub" -Field "repoInstructionPaths"
Assert-ArrayField -Object $profileObject -Path "profile" -Field "repos"
Assert-ArrayField -Object $profileObject -Path "profile" -Field "reportingRules"

$repoIndex = 0
foreach ($repo in @($profileObject.repos)) {
    Assert-RequiredField -Object $repo -Path "profile.repos[$repoIndex]" -Fields @(
        "id",
        "role",
        "displayName",
        "repoFullName",
        "repoUrl",
        "sourceRoot",
        "baseBranch",
        "todoProfile",
        "repoInstructionPaths",
        "ownershipRules",
        "validationRules"
    )
    if (@("product", "module") -notcontains $repo.role) {
        throw "Profile field profile.repos[$repoIndex].role must be 'product' or 'module'."
    }
    Assert-ArrayField -Object $repo -Path "profile.repos[$repoIndex]" -Field "repoInstructionPaths"
    Assert-ArrayField -Object $repo -Path "profile.repos[$repoIndex]" -Field "ownershipRules"
    Assert-ArrayField -Object $repo -Path "profile.repos[$repoIndex]" -Field "validationRules"
    $repoIndex += 1
}

Assert-ArrayField -Object $profileObject.packageOverrides -Path "profile.packageOverrides" -Field "setupCommands" -AllowEmpty
Assert-ArrayField -Object $profileObject.packageOverrides -Path "profile.packageOverrides" -Field "verifyCommands" -AllowEmpty
Assert-ArrayField -Object $profileObject.packageOverrides -Path "profile.packageOverrides" -Field "restoreCommands" -AllowEmpty

$singleEstimate = Get-PropertyValue -Object $profileObject.issueSplitRules -Field "singleIssueMaxEstimateHours"
if ($null -eq $singleEstimate) {
    $singleEstimate = 8
}
if ([int]$singleEstimate -lt 1) {
    throw "Profile field profile.issueSplitRules.singleIssueMaxEstimateHours must be greater than zero."
}

if ($Action -eq "Execute" -and [string]::IsNullOrWhiteSpace($HubIssue) -and @($Issues).Count -eq 0) {
    throw "Execute action requires -HubIssue or -Issues."
}

$hubInstructionPaths = Format-InstructionPaths -Items $profileObject.hub.repoInstructionPaths
$repoSummary = Format-RepoSummary -Repos $profileObject.repos
$setupCommands = Format-BulletList -Items $profileObject.packageOverrides.setupCommands -EmptyText "setupCommands is empty; report product local package override setup as blocked."
$verifyCommands = Format-BulletList -Items $profileObject.packageOverrides.verifyCommands -EmptyText "verifyCommands is empty; report product local package override verification as blocked."
$restoreCommands = Format-BulletList -Items $profileObject.packageOverrides.restoreCommands -EmptyText "restoreCommands is empty; report that no restore command is configured."
$expectedChangedPaths = Format-BulletList -Items (Get-PropertyValue -Object $profileObject.packageOverrides -Field "expectedChangedPaths") -EmptyText "expectedChangedPaths is not configured; inspect product repo git status after setup."
$reportingRules = Format-BulletList -Items $profileObject.reportingRules

$issueTargets = @()
if (-not [string]::IsNullOrWhiteSpace($HubIssue)) {
    $issueTargets += "HubIssue=$HubIssue"
}
foreach ($issue in @($Issues)) {
    if (-not [string]::IsNullOrWhiteSpace($issue)) {
        $issueTargets += "Issue=$issue"
    }
}
$issueTargetsText = Format-BulletList -Items $issueTargets -EmptyText "No issue target supplied."

$actionSteps = if ($Action -eq "Register") {
@"
1. profile required field와 product/module repo instruction을 검증한다.
2. 사용자가 입력한 요구사항을 목적, 완료 기준, 검증 경로, repository 영향 기준으로 requirement group으로 나눈다.
3. 각 group을 product-only single issue, same-repo parent/sub issue, multi-repo product hub + repo별 child issue 중 하나로 분류한다.
4. issue-management 방식으로 중복, canonical, split, metadata gate를 통과한다.
5. GitHub issue, Project field, native relationship만 생성/갱신하고 검증한다.
6. branch/worktree/PR/package override command는 실행하지 않는다.
7. 생성/갱신 issue와 group별 판단, 관계, Project 검증, 작업 실행 미수행 사실을 보고한다.
"@
} else {
@"
1. 지정된 issue target을 조회해 단일 구현 issue인지 hub/umbrella issue인지 판정한다.
2. hub/umbrella issue이면 child issue와 blocked-by, Project status, active PR changed files를 조회한다.
3. 열린 blocker, partial preflight, ownership overlap이 있는 child issue는 실행하지 않는다.
4. 실행 가능한 child issue만 각 repo worktree에서 gh-issue-pr-review-loop로 진행한다.
5. 필요한 module branch/PR이 준비된 뒤 packageOverrides.setupCommands만 실행한다.
6. packageOverrides.verifyCommands로 product local test 환경을 확인한다.
7. product local override 변경 파일과 restoreCommands를 보고한다.
"@
}

$prompt = @"
Product multi-repo issue orchestration을 실행한다.

## 공통 Skill과 profile
- 공통 조율 Skill: multi-repo-issue-orchestration
- 저장소 profile: $profilePath
- profile schema: multi-repo-issue-orchestration/references/profile-schema.md
- 이슈 관리 Skill: issue-management
- PR/review loop Skill: gh-issue-pr-review-loop
- Todo 자동화 Skill: todo-issue-automation
- Action: $Action

## Issue targets
$issueTargetsText

## Product hub
- repo: $($profileObject.hub.repoFullName)
- sourceRoot: $($profileObject.hub.sourceRoot)
- Project: $($profileObject.hub.projectOwner) #$($profileObject.hub.projectNumber) ($($profileObject.hub.projectTitle))
- baseBranch: $($profileObject.hub.baseBranch)
- statuses: Todo=$($profileObject.hub.todoStatusName), InProgress=$($profileObject.hub.inProgressStatusName), IssueReview=$($profileObject.hub.issueReviewStatusName)
- product-only single issue max estimate: $singleEstimate hours

## Product instructions
$hubInstructionPaths

## Participating repositories
$repoSummary

## 기본 원칙
- 위 Skill과 profile schema를 먼저 읽고, profile 값을 product/module repo 조율의 단일 원천으로 사용한다.
- 사용자는 single-repo/multi-repo를 고르지 않는다. 이슈 등록의 기본 진입점은 issue-management다.
- Register action에서는 이슈 등록과 관계 검증만 하고 branch/worktree/PR/package override command를 실행하지 않는다.
- Execute action은 기존 issue 번호나 URL을 기준으로만 실행한다.
- product-only, 독립 완료 기준 1개, package/API/DB/DTO/protocol 변경 없음, estimate <= $singleEstimate 이면 product 단일 issue로 구성한다.
- multi-repo, module package 변경, 공통 계약 변경, 독립 검증 단위가 있으면 product hub issue와 repo별 child issue로 구성한다.
- relation은 GitHub native sub issue/blocked-by mutation을 먼저 시도하고, 실패하면 hub issue 본문에 child issue URL과 fallback 사유를 남긴다.
- 동시에 진행 가능한 child issue만 위임하고, ownership overlap이나 partial preflight가 있으면 보류한다.
- merge는 수행하지 않는다.
- 사람이 확인하는 GitHub issue/PR/comment/review/report 문구는 한국어로 작성한다.

## Package override commands (Execute action only)
setupCommands:
$setupCommands

verifyCommands:
$verifyCommands

restoreCommands:
$restoreCommands

expectedChangedPaths:
$expectedChangedPaths

## 실행 절차
$actionSteps

## Reporting rules
$reportingRules
"@

if ($Json) {
    [pscustomobject]@{
        profile = $profileObject.id
        profilePath = $profilePath
        skillRoot = $resolvedSkillRoot
        action = $Action
        issueTargets = $issueTargets
        singleIssueMaxEstimateHours = [int]$singleEstimate
        prompt = $prompt
    } | ConvertTo-Json -Depth 12
} else {
    $prompt
}

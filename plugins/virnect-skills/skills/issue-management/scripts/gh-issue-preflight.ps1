[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$Issue,

    [string]$Repo = "",
    [string]$ProjectOwner = "",
    [int]$ProjectNumber = 0,
    [string]$Base = "",
    [switch]$Json,
    [ValidateSet("Full", "Startup", "StatusTransition", "PrConflict")]
    [string]$Mode = "Full",
    [switch]$IncludePrsWhenBlocked,
    [switch]$StopOnOpenBlocker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-GhJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = & gh @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
    if ([string]::IsNullOrWhiteSpace($output)) {
        return $null
    }
    return $output | ConvertFrom-Json
}

function Get-RepoInfo {
    param(
        [string]$Repository,
        [bool]$NeedsDefaultBranch
    )

    if (-not [string]::IsNullOrWhiteSpace($Repository) -and
        -not $NeedsDefaultBranch -and
        $Repository -match '^[^/\s]+/[^/\s]+$') {
        $parts = $Repository -split "/", 2
        return [pscustomobject]@{
            Owner = $parts[0]
            Name = $parts[1]
            FullName = $Repository
            DefaultBranch = $null
            Lookup = "direct-owner-name"
        }
    }

    $args = @("repo", "view", "--json", "nameWithOwner,defaultBranchRef")
    if (-not [string]::IsNullOrWhiteSpace($Repository)) {
        $args = @("repo", "view", $Repository, "--json", "nameWithOwner,defaultBranchRef")
    }
    $info = Invoke-GhJson -Arguments $args
    $parts = $info.nameWithOwner -split "/", 2
    return [pscustomobject]@{
        Owner = $parts[0]
        Name = $parts[1]
        FullName = $info.nameWithOwner
        DefaultBranch = $info.defaultBranchRef.name
        Lookup = "gh-repo-view"
    }
}

function Get-LocalDiffFiles {
    param([string]$BaseRef)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $insideWorkTree = (& git rev-parse --is-inside-work-tree 2>$null)
        if ($LASTEXITCODE -ne 0 -or $insideWorkTree -ne "true") {
            return [pscustomobject]@{
                files = @()
                status = "not-git-worktree"
                reason = "Current directory is not inside a git worktree."
                baseRef = "origin/$BaseRef"
            }
        }

        $baseExists = (& git rev-parse --verify "origin/$BaseRef" 2>$null)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($baseExists)) {
            return [pscustomobject]@{
                files = @()
                status = "missing-origin-base"
                reason = "Base ref origin/$BaseRef was not found."
                baseRef = "origin/$BaseRef"
            }
        }

        $mergeBase = (& git merge-base "origin/$BaseRef" HEAD 2>$null)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($mergeBase)) {
            return [pscustomobject]@{
                files = @()
                status = "merge-base-failed"
                reason = "Could not calculate merge-base between origin/$BaseRef and HEAD."
                baseRef = "origin/$BaseRef"
            }
        }

        $committedFiles = (& git diff --name-only "$mergeBase...HEAD" 2>$null)
        if ($LASTEXITCODE -ne 0) {
            $committedFiles = @()
        }

        $unstagedFiles = (& git diff --name-only 2>$null)
        if ($LASTEXITCODE -ne 0) {
            $unstagedFiles = @()
        }

        $stagedFiles = (& git diff --name-only --cached 2>$null)
        if ($LASTEXITCODE -ne 0) {
            $stagedFiles = @()
        }

        $untrackedFiles = (& git ls-files --others --exclude-standard 2>$null)
        if ($LASTEXITCODE -ne 0) {
            $untrackedFiles = @()
        }
    } finally {
        $ErrorActionPreference = $previousPreference
    }

    $files = @(
        @(
            $committedFiles
            $unstagedFiles
            $stagedFiles
            $untrackedFiles
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
    )

    $status = "ok-empty"
    $reason = "No local diff files were found."
    if ($files.Count -gt 0) {
        $status = "ok-changed"
        $reason = "Local diff files were found."
    }

    return [pscustomobject]@{
        files = @($files)
        status = $status
        reason = $reason
        baseRef = "origin/$BaseRef"
    }
}

function Get-IssueGraph {
    param(
        [string]$Owner,
        [string]$Name,
        [int]$Number
    )

    $query = @'
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      id
      number
      title
      state
      url
      parent { id number title state url }
      subIssues(first: 20) { nodes { id number title state url } }
      blockedBy(first: 20) { nodes { id number title state url } }
      blocking(first: 20) { nodes { id number title state url } }
      projectItems(first: 20) {
        nodes {
          id
          project { title number }
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field { ... on ProjectV2FieldCommon { name } }
                name
                optionId
              }
            }
          }
        }
      }
    }
  }
  rateLimit { cost remaining resetAt }
}
'@

    $args = @(
        "api", "graphql",
        "-f", "query=$query",
        "-F", "owner=$Owner",
        "-F", "name=$Name",
        "-F", "number=$Number"
    )
    return Invoke-GhJson -Arguments $args
}

function Get-ProjectStatus {
    param($IssueNode)

    foreach ($item in @($IssueNode.projectItems.nodes)) {
        if ($ProjectNumber -gt 0 -and $item.project.number -ne $ProjectNumber) {
            continue
        }
        foreach ($value in @($item.fieldValues.nodes)) {
            $fieldProperty = $value.PSObject.Properties["field"]
            if ($null -ne $fieldProperty -and $null -ne $fieldProperty.Value -and $fieldProperty.Value.name -eq "Status") {
                return [pscustomobject]@{
                    Project = $item.project.title
                    ProjectNumber = $item.project.number
                    Status = $value.name
                    OptionId = $value.optionId
                }
            }
        }
    }
    return $null
}

function Get-RelatedIssueNumbers {
    param($IssueNode)

    $numbers = New-Object System.Collections.Generic.HashSet[int]
    [void]$numbers.Add([int]$IssueNode.number)
    if ($null -ne $IssueNode.parent) {
        [void]$numbers.Add([int]$IssueNode.parent.number)
    }
    foreach ($node in @($IssueNode.subIssues.nodes) + @($IssueNode.blockedBy.nodes) + @($IssueNode.blocking.nodes)) {
        if ($null -ne $node) {
            [void]$numbers.Add([int]$node.number)
        }
    }
    return @($numbers | Sort-Object)
}

function Get-OpenPrsForIssues {
    param(
        [string]$Repository,
        [int[]]$IssueNumbers,
        [switch]$IncludeFiles
    )

    $linkedPrs = New-Object 'System.Collections.Generic.Dictionary[int,object]'
    $issueSet = New-Object System.Collections.Generic.HashSet[int]
    foreach ($issueNumber in @($IssueNumbers)) {
        [void]$issueSet.Add([int]$issueNumber)
    }

    $prs = @()
    foreach ($number in $IssueNumbers) {
        $args = @(
            "pr", "list",
            "--repo", $Repository,
            "--state", "open",
            "--search", $number.ToString(),
            "--json", "number,title,url,headRefName,baseRefName,isDraft,state,closingIssuesReferences,updatedAt"
        )
        $result = Invoke-GhJson -Arguments $args
        foreach ($pr in @($result)) {
            if ($null -eq $pr) {
                continue
            }

            $linkedByClosingReference = $false
            foreach ($reference in @($pr.closingIssuesReferences)) {
                if ($null -ne $reference -and $issueSet.Contains([int]$reference.number)) {
                    $linkedByClosingReference = $true
                    break
                }
            }

            $linkedByBranchName = $false
            foreach ($issueNumber in @($IssueNumbers)) {
                if ($pr.headRefName -match "(^|[-_/])issue[-_/]?$issueNumber($|[-_/])") {
                    $linkedByBranchName = $true
                    break
                }
            }

            if (-not $linkedByClosingReference -and -not $linkedByBranchName) {
                continue
            }

            $prNumber = [int]$pr.number
            if (-not $linkedPrs.ContainsKey($prNumber)) {
                $linkedPrs.Add($prNumber, $pr)
            }
        }
    }

    $prs = @()
    foreach ($prNumber in @($linkedPrs.Keys | Sort-Object)) {
        $pr = $linkedPrs[$prNumber]
        $files = @()
        $filesLookup = "skipped"
        if ($IncludeFiles) {
            $filesResult = Invoke-GhJson -Arguments @(
                "pr", "view", $pr.number.ToString(),
                "--repo", $Repository,
                "--json", "files"
            )
            $files = @($filesResult.files)
            $filesLookup = "fetched"
        }

        $prs += [pscustomobject]@{
            number = $pr.number
            title = $pr.title
            url = $pr.url
            headRefName = $pr.headRefName
            baseRefName = $pr.baseRefName
            isDraft = $pr.isDraft
            state = $pr.state
            updatedAt = $pr.updatedAt
            files = @($files)
            filesLookup = $filesLookup
            closingIssuesReferences = @($pr.closingIssuesReferences)
        }
    }
    return $prs
}

function New-SkippedLookup {
    param(
        [string]$Name,
        [string]$Reason
    )

    return [pscustomobject]@{
        name = $Name
        reason = $Reason
    }
}

$repoInfo = Get-RepoInfo -Repository $Repo -NeedsDefaultBranch ([string]::IsNullOrWhiteSpace($Base))
if ([string]::IsNullOrWhiteSpace($Base)) {
    $Base = $repoInfo.DefaultBranch
}

$graph = Get-IssueGraph -Owner $repoInfo.Owner -Name $repoInfo.Name -Number $Issue
$issueNode = $graph.data.repository.issue
if ($null -eq $issueNode) {
    throw "Issue #$Issue was not found in $($repoInfo.FullName)."
}

$status = Get-ProjectStatus -IssueNode $issueNode
$openBlockers = @($issueNode.blockedBy.nodes | Where-Object { $_.state -eq "OPEN" })
$relatedNumbers = @(Get-RelatedIssueNumbers -IssueNode $issueNode)
$localDiff = Get-LocalDiffFiles -BaseRef $Base
$localDiffFiles = @($localDiff.files)

$skippedLookups = @()
$partial = $false
$prIssueNumbers = @($relatedNumbers)
$prSearchScope = "related-issues"
$stopOnOpenBlockerEffective = $false
if ($Mode -eq "Startup" -and $openBlockers.Count -gt 0 -and -not $IncludePrsWhenBlocked) {
    $stopOnOpenBlockerEffective = $true
    $partial = $true
    $prIssueNumbers = @([int]$Issue)
    $prSearchScope = "target-issue-only"
    $skippedLookups += New-SkippedLookup `
        -Name "related-pr-search" `
        -Reason "Startup mode found open blocked-by issues; only target issue PRs were checked."
}

$includePrFiles = $false
if ($Mode -eq "Full") {
    $includePrFiles = $true
} elseif ($Mode -eq "PrConflict" -and $localDiff.status -eq "ok-changed") {
    $includePrFiles = $true
} elseif ($Mode -eq "Startup" -and $IncludePrsWhenBlocked -and $localDiff.status -eq "ok-changed") {
    $includePrFiles = $true
}

if (-not $includePrFiles) {
    $partial = $true
    $skippedLookups += New-SkippedLookup `
        -Name "pr-files" `
        -Reason "Mode $Mode does not require PR changed files for this lookup, or local diff status is $($localDiff.status)."
}

$openPrs = @(Get-OpenPrsForIssues -Repository $repoInfo.FullName -IssueNumbers $prIssueNumbers -IncludeFiles:($includePrFiles))

$overlappingPrs = @()
foreach ($pr in @($openPrs)) {
    $prFiles = @($pr.files | ForEach-Object { $_.path })
    $overlap = @($localDiffFiles | Where-Object { $prFiles -contains $_ })
    if ($overlap.Count -gt 0) {
        $overlappingPrs += [pscustomobject]@{
            number = $pr.number
            title = $pr.title
            url = $pr.url
            overlappingFiles = $overlap
        }
    }
}

$decision = "ready"
$confidence = "medium"
$notes = @()

$issueIsOpen = ($issueNode.state -eq "OPEN")
if (-not $issueIsOpen) {
    $decision = "needs-review"
    $confidence = "high"
    $notes += "Issue is not open; verify whether to reopen, replace, or skip."
} elseif ($openBlockers.Count -gt 0) {
    $decision = "blocked"
    $confidence = "high"
    $notes += "Open blocked-by issues exist; hold In Progress transition."
} elseif ($overlappingPrs.Count -gt 0) {
    $decision = "conflict-risk"
    $confidence = "high"
    $notes += "Local diff files overlap with active PR files."
} elseif ($openPrs.Count -gt 0) {
    $decision = "conflict-risk"
    $confidence = "medium"
    $notes += "Active PRs are linked to related issues; verify work order."
} elseif ($Mode -eq "PrConflict" -and $localDiff.status -ne "ok-empty" -and $localDiff.status -ne "ok-changed") {
    $decision = "needs-review"
    $confidence = "low"
    $notes += "Local diff status is $($localDiff.status); file conflict readiness cannot be confirmed."
} elseif ($localDiffFiles.Count -eq 0) {
    $confidence = "low"
    $notes += "No local diff files; file conflict confidence is limited."
}

if ($partial) {
    $notes += "Some lookups were skipped; do not treat this result as full conflict evidence."
}

$recommendedOrder = "ready"
if (-not $issueIsOpen) {
    $recommendedOrder = "verify closed issue handling"
} elseif ($openBlockers.Count -gt 0) {
    $recommendedOrder = "wait for blocked-by issues"
} elseif ($overlappingPrs.Count -gt 0) {
    $recommendedOrder = "wait for overlapping PR merge or rebase"
}

$result = [pscustomobject]@{
    queriedAt = (Get-Date).ToString("o")
    mode = $Mode
    partial = $partial
    repo = $repoInfo.FullName
    issue = [pscustomobject]@{
        number = $issueNode.number
        title = $issueNode.title
        state = $issueNode.state
        url = $issueNode.url
        projectStatus = $status
    }
    decision = $decision
    confidence = $confidence
    hardBlockers = @($openBlockers | Select-Object number, title, state, url)
    softConflicts = @($openPrs | Select-Object number, title, url, headRefName, baseRefName, isDraft, updatedAt)
    overlappingPrs = $overlappingPrs
    relationship = [pscustomobject]@{
        parent = $issueNode.parent
        subIssues = @($issueNode.subIssues.nodes | Select-Object number, title, state, url)
        blockedBy = @($issueNode.blockedBy.nodes | Select-Object number, title, state, url)
        blocking = @($issueNode.blocking.nodes | Select-Object number, title, state, url)
    }
    localDiffFiles = $localDiffFiles
    localDiffStatus = [pscustomobject]@{
        status = $localDiff.status
        reason = $localDiff.reason
        baseRef = $localDiff.baseRef
    }
    relatedIssueNumbers = @($relatedNumbers)
    lookupStatus = [pscustomobject]@{
        repoInfo = $repoInfo.Lookup
        relationship = "live"
        projectStatus = "live"
        prSearchScope = $prSearchScope
        prSearchIssueNumbers = @($prIssueNumbers)
        prFiles = $(if ($includePrFiles) { "fetched" } else { "skipped" })
        stopOnOpenBlockerRequested = [bool]$StopOnOpenBlocker
        stopOnOpenBlocker = $stopOnOpenBlockerEffective
    }
    skippedLookups = @($skippedLookups)
    cacheHits = @()
    recommendedOrder = $recommendedOrder
    rateLimit = $graph.data.rateLimit
    notes = $notes
}

if ($Json) {
    $result | ConvertTo-Json -Depth 100
} else {
    "Issue #$($result.issue.number): $($result.issue.title)"
    "Decision: $($result.decision) ($($result.confidence))"
    "Recommended order: $($result.recommendedOrder)"
    "Mode: $($result.mode) partial=$($result.partial)"
    if ($result.hardBlockers.Count -gt 0) {
        "Hard blockers:"
        $result.hardBlockers | ForEach-Object { "- #$($_.number) $($_.title) [$($_.state)]" }
    }
    if ($result.overlappingPrs.Count -gt 0) {
        "Overlapping PRs:"
        $result.overlappingPrs | ForEach-Object { "- #$($_.number) $($_.title): $($_.overlappingFiles -join ', ')" }
    }
    if ($result.notes.Count -gt 0) {
        "Notes:"
        $result.notes | ForEach-Object { "- $_" }
    }
}

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Profile,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProductRepoRoot,

    [string]$DisplayName = "",
    [string]$ProductRepoFullName = "",
    [string]$ProductRepoUrl = "",
    [string]$ProductBaseBranch = "",
    [string]$ProductTodoProfile = "",

    [string]$ProjectOwner = "",
    [int]$ProjectNumber = 0,
    [string]$ProjectTitle = "",

    [string[]]$ProductOwnershipRules = @(),
    [string[]]$ProductValidationRules = @(),
    [string]$ConfirmedModulesJson = "",

    [string[]]$PackageSetupCommands = @(),
    [string[]]$PackageVerifyCommands = @(),
    [string[]]$PackageRestoreCommands = @(),
    [string[]]$PackageExpectedChangedPaths = @(),
    [string[]]$PackageNotes = @(),

    [int]$SingleIssueMaxEstimateHours = 8,

    [ValidateSet("RepoLocal", "CodexHome")]
    [string]$OutputScope = "RepoLocal",

    [string]$OutputPath = "",

    [switch]$Force,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ObjectField {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Test-Blank {
    param([object]$Value)

    if ($null -eq $Value) {
        return $true
    }

    if ($Value -is [string]) {
        return [string]::IsNullOrWhiteSpace($Value)
    }

    return $false
}

function ConvertTo-Array {
    param([object]$Value)

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [System.Array]) {
        return @($Value)
    }

    return @($Value)
}

function ConvertTo-RelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    $rootUri = New-Object System.Uri(($rootFull + [System.IO.Path]::DirectorySeparatorChar))
    $pathUri = New-Object System.Uri($pathFull)
    return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Invoke-Git {
    param(
        [string]$RepoRoot,
        [string[]]$Arguments
    )

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $git) {
        return $null
    }

    $output = & git -C $RepoRoot @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    return (($output | Out-String).Trim())
}

function ConvertFrom-GitHubUrl {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [pscustomobject]@{ repoFullName = ""; repoUrl = "" }
    }

    $text = $Value.Trim()
    $repoFullName = ""

    if ($text -match "github\.com[:/](?<owner>[^/\s:]+)/(?<repo>[^/\s#?]+)") {
        $repo = $Matches["repo"] -replace "\.git$", ""
        $repoFullName = "$($Matches["owner"])/$repo"
    }

    $repoUrl = ""
    if (-not [string]::IsNullOrWhiteSpace($repoFullName)) {
        $repoUrl = "https://github.com/$repoFullName"
    }

    return [pscustomobject]@{
        repoFullName = $repoFullName
        repoUrl = $repoUrl
    }
}

function ConvertTo-ProfileId {
    param([string]$Value)

    $text = if ([string]::IsNullOrWhiteSpace($Value)) { "repo" } else { $Value }
    $text = $text.Trim().ToLowerInvariant()
    $text = $text -replace "[^a-z0-9]+", "-"
    $text = $text.Trim("-")
    if ([string]::IsNullOrWhiteSpace($text)) {
        return "repo"
    }

    return $text
}

function Resolve-LocalReference {
    param(
        [string]$Root,
        [string]$Reference
    )

    if ([string]::IsNullOrWhiteSpace($Reference)) {
        return ""
    }

    $raw = $Reference.Trim()
    if ($raw.StartsWith("file:")) {
        $raw = $raw.Substring(5)
    }

    $raw = $raw.Trim('"', "'")
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($raw)) {
        return [System.IO.Path]::GetFullPath($raw)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $Root $raw))
}

function Add-Candidate {
    param(
        [System.Collections.IList]$Candidates,
        [string]$Source,
        [string]$Name = "",
        [string]$RepoFullName = "",
        [string]$RepoUrl = "",
        [string]$SourceRoot = "",
        [string]$Reference = "",
        [string]$Confidence = "candidate"
    )

    if ([string]::IsNullOrWhiteSpace($RepoFullName) -and [string]::IsNullOrWhiteSpace($SourceRoot) -and [string]::IsNullOrWhiteSpace($Name)) {
        return
    }

    $displayName = $Name
    if ([string]::IsNullOrWhiteSpace($displayName) -and -not [string]::IsNullOrWhiteSpace($RepoFullName)) {
        $displayName = ($RepoFullName -split "/")[-1]
    }
    if ([string]::IsNullOrWhiteSpace($displayName) -and -not [string]::IsNullOrWhiteSpace($SourceRoot)) {
        $displayName = Split-Path -Leaf $SourceRoot
    }

    $idSource = if (-not [string]::IsNullOrWhiteSpace($RepoFullName)) { ($RepoFullName -split "/")[-1] } else { $displayName }
    $id = ConvertTo-ProfileId -Value $idSource
    $key = if (-not [string]::IsNullOrWhiteSpace($RepoFullName)) {
        "repo:$RepoFullName"
    } elseif (-not [string]::IsNullOrWhiteSpace($SourceRoot)) {
        "path:$([System.IO.Path]::GetFullPath($SourceRoot).ToLowerInvariant())"
    } else {
        "name:$id"
    }

    foreach ($candidate in @($Candidates)) {
        if ($candidate.matchKey -eq $key) {
            return
        }
    }

    [void]$Candidates.Add([pscustomobject]@{
        id = $id
        displayName = $displayName
        repoFullName = $RepoFullName
        repoUrl = $RepoUrl
        sourceRoot = $SourceRoot
        source = $Source
        reference = $Reference
        confidence = $Confidence
        matchKey = $key
    })
}

function Get-InstructionPaths {
    param([string]$RepoRoot)

    if ([string]::IsNullOrWhiteSpace($RepoRoot) -or -not (Test-Path -LiteralPath $RepoRoot)) {
        return @()
    }

    $candidates = @(
        "AGENTS.md",
        "CLAUDE.md",
        ".github\copilot-instructions.md",
        ".github\PULL_REQUEST_TEMPLATE.md"
    )

    $paths = @()
    foreach ($candidate in $candidates) {
        $fullPath = Join-Path $RepoRoot $candidate
        if (Test-Path -LiteralPath $fullPath) {
            $paths += $candidate.Replace('\', '/')
        }
    }

    $issueTemplateRoot = Join-Path $RepoRoot ".github\ISSUE_TEMPLATE"
    if (Test-Path -LiteralPath $issueTemplateRoot) {
        $paths += ".github/ISSUE_TEMPLATE"
    }

    return @($paths)
}

function Get-GhRepoInfo {
    param([string]$RepoRoot)

    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -eq $gh) {
        return $null
    }

    Push-Location $RepoRoot
    try {
        $raw = & gh repo view --json nameWithOwner,url,defaultBranchRef 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) {
            return $null
        }

        return ($raw | ConvertFrom-Json)
    } catch {
        return $null
    } finally {
        Pop-Location
    }
}

function Get-ProjectCandidates {
    param([string]$Owner)

    if ([string]::IsNullOrWhiteSpace($Owner)) {
        return @()
    }

    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -eq $gh) {
        return @()
    }

    try {
        $raw = & gh project list --owner $Owner --format json --limit 20 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) {
            return @()
        }

        $parsed = $raw | ConvertFrom-Json
        $projects = Get-ObjectField -Object $parsed -Name "projects"
        if ($null -eq $projects) {
            return @()
        }

        $items = @()
        foreach ($project in @($projects)) {
            $items += [pscustomobject]@{
                owner = $Owner
                number = Get-ObjectField -Object $project -Name "number"
                title = Get-ObjectField -Object $project -Name "title"
                url = Get-ObjectField -Object $project -Name "url"
            }
        }

        return @($items)
    } catch {
        return @()
    }
}

function Find-ModuleCandidates {
    param([string]$Root)

    $candidates = New-Object System.Collections.ArrayList

    $packageJsonPath = Join-Path $Root "package.json"
    if (Test-Path -LiteralPath $packageJsonPath) {
        try {
            $packageJson = Get-Content -Raw -Encoding UTF8 -LiteralPath $packageJsonPath | ConvertFrom-Json
            foreach ($field in @("dependencies", "devDependencies", "peerDependencies", "optionalDependencies")) {
                $deps = Get-ObjectField -Object $packageJson -Name $field
                if ($null -eq $deps) {
                    continue
                }

                foreach ($dependency in @($deps.PSObject.Properties)) {
                    $value = [string]$dependency.Value
                    if ($value -match "^(file:|\.\.?[\\/])") {
                        Add-Candidate -Candidates $candidates -Source "package.json" -Name $dependency.Name -SourceRoot (Resolve-LocalReference -Root $Root -Reference $value) -Reference "$field.$($dependency.Name)=$value"
                    } elseif ($value -match "github\.com[:/]") {
                        $identity = ConvertFrom-GitHubUrl -Value $value
                        Add-Candidate -Candidates $candidates -Source "package.json" -Name $dependency.Name -RepoFullName $identity.repoFullName -RepoUrl $identity.repoUrl -Reference "$field.$($dependency.Name)=$value"
                    } elseif ($value -match "^workspace:") {
                        Add-Candidate -Candidates $candidates -Source "package.json" -Name $dependency.Name -Reference "$field.$($dependency.Name)=$value" -Confidence "workspace-package"
                    }
                }
            }

            $workspaces = Get-ObjectField -Object $packageJson -Name "workspaces"
            if ($null -ne $workspaces) {
                $patterns = @()
                if ($workspaces -is [System.Array]) {
                    $patterns = @($workspaces)
                } else {
                    $packages = Get-ObjectField -Object $workspaces -Name "packages"
                    $patterns = @($packages)
                }

                foreach ($pattern in @($patterns)) {
                    if ([string]::IsNullOrWhiteSpace([string]$pattern)) {
                        continue
                    }

                    $patternText = ([string]$pattern).Trim('"', "'")
                    $parent = $patternText
                    if ($parent.Contains("*")) {
                        $parent = $parent.Substring(0, $parent.IndexOf("*")).TrimEnd('\', '/')
                    }

                    $workspaceRoot = Resolve-LocalReference -Root $Root -Reference $parent
                    if (Test-Path -LiteralPath $workspaceRoot) {
                        Add-Candidate -Candidates $candidates -Source "package.json workspaces" -Name $patternText -SourceRoot $workspaceRoot -Reference $patternText -Confidence "workspace-root"
                    }
                }
            }
        } catch {
            Add-Candidate -Candidates $candidates -Source "package.json" -Name "package-json-parse-failed" -Reference $_.Exception.Message -Confidence "parse-warning"
        }
    }

    $pnpmWorkspacePath = Join-Path $Root "pnpm-workspace.yaml"
    if (Test-Path -LiteralPath $pnpmWorkspacePath) {
        foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $pnpmWorkspacePath) {
            if ($line -match "^\s*-\s*['""]?(?<path>[^'""]+)['""]?\s*$") {
                $patternText = $Matches["path"].Trim()
                $parent = $patternText
                if ($parent.Contains("*")) {
                    $parent = $parent.Substring(0, $parent.IndexOf("*")).TrimEnd('\', '/')
                }
                Add-Candidate -Candidates $candidates -Source "pnpm-workspace.yaml" -Name $patternText -SourceRoot (Resolve-LocalReference -Root $Root -Reference $parent) -Reference $patternText -Confidence "workspace-root"
            }
        }
    }

    $gitmodulesPath = Join-Path $Root ".gitmodules"
    if (Test-Path -LiteralPath $gitmodulesPath) {
        $modulePath = ""
        $moduleUrl = ""
        $flushModule = {
            if (-not [string]::IsNullOrWhiteSpace($modulePath) -or -not [string]::IsNullOrWhiteSpace($moduleUrl)) {
                $identity = ConvertFrom-GitHubUrl -Value $moduleUrl
                Add-Candidate -Candidates $candidates -Source ".gitmodules" -Name (Split-Path -Leaf $modulePath) -RepoFullName $identity.repoFullName -RepoUrl $identity.repoUrl -SourceRoot (Resolve-LocalReference -Root $Root -Reference $modulePath) -Reference $moduleUrl -Confidence "submodule"
            }
        }

        foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $gitmodulesPath) {
            if ($line -match "^\s*\[submodule\s+") {
                & $flushModule
                $modulePath = ""
                $moduleUrl = ""
            } elseif ($line -match "^\s*path\s*=\s*(?<path>.+?)\s*$") {
                $modulePath = $Matches["path"]
            } elseif ($line -match "^\s*url\s*=\s*(?<url>.+?)\s*$") {
                $moduleUrl = $Matches["url"]
            }
        }
        & $flushModule
    }

    $manifestPath = Join-Path $Root "Packages\manifest.json"
    if (Test-Path -LiteralPath $manifestPath) {
        try {
            $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
            $deps = Get-ObjectField -Object $manifest -Name "dependencies"
            if ($null -ne $deps) {
                foreach ($dependency in @($deps.PSObject.Properties)) {
                    $value = [string]$dependency.Value
                    if ($value -match "^(file:|\.\.?[\\/])") {
                        Add-Candidate -Candidates $candidates -Source "Packages/manifest.json" -Name $dependency.Name -SourceRoot (Resolve-LocalReference -Root $Root -Reference $value) -Reference "$($dependency.Name)=$value"
                    } elseif ($value -match "github\.com[:/]") {
                        $identity = ConvertFrom-GitHubUrl -Value $value
                        Add-Candidate -Candidates $candidates -Source "Packages/manifest.json" -Name $dependency.Name -RepoFullName $identity.repoFullName -RepoUrl $identity.repoUrl -Reference "$($dependency.Name)=$value"
                    }
                }
            }
        } catch {
            Add-Candidate -Candidates $candidates -Source "Packages/manifest.json" -Name "unity-manifest-parse-failed" -Reference $_.Exception.Message -Confidence "parse-warning"
        }
    }

    $projectFiles = Get-ChildItem -LiteralPath $Root -Recurse -File -Include *.sln,*.csproj -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "\\\.git\\" } |
        Select-Object -First 200

    foreach ($file in @($projectFiles)) {
        $lines = Get-Content -Encoding UTF8 -LiteralPath $file.FullName -ErrorAction SilentlyContinue
        foreach ($line in @($lines)) {
            if ($file.Extension -ieq ".csproj" -and $line -match "ProjectReference\s+Include\s*=\s*['""](?<path>[^'""]+)['""]") {
                $candidateRoot = Resolve-LocalReference -Root (Split-Path -Parent $file.FullName) -Reference $Matches["path"]
                Add-Candidate -Candidates $candidates -Source "ProjectReference" -Name ([System.IO.Path]::GetFileNameWithoutExtension($candidateRoot)) -SourceRoot (Split-Path -Parent $candidateRoot) -Reference (ConvertTo-RelativePath -Root $Root -Path $candidateRoot)
            } elseif ($file.Extension -ieq ".sln" -and $line -match "Project\(.+\)\s*=\s*['""](?<name>[^'""]+)['""],\s*['""](?<path>[^'""]+\.(csproj|vbproj|fsproj))['""]") {
                $candidateFile = Resolve-LocalReference -Root (Split-Path -Parent $file.FullName) -Reference $Matches["path"]
                Add-Candidate -Candidates $candidates -Source "solution reference" -Name $Matches["name"] -SourceRoot (Split-Path -Parent $candidateFile) -Reference (ConvertTo-RelativePath -Root $Root -Path $candidateFile)
            }
        }
    }

    $docFiles = @()
    $readme = Join-Path $Root "README.md"
    if (Test-Path -LiteralPath $readme) {
        $docFiles += Get-Item -LiteralPath $readme
    }
    $docsRoot = Join-Path $Root "docs"
    if (Test-Path -LiteralPath $docsRoot) {
        $docFiles += Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter *.md -ErrorAction SilentlyContinue | Select-Object -First 100
    }

    foreach ($doc in @($docFiles)) {
        $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $doc.FullName -ErrorAction SilentlyContinue
        foreach ($match in [regex]::Matches($content, "https://github\.com/[^/\s\)]+/[^/\s\)#]+")) {
            $identity = ConvertFrom-GitHubUrl -Value $match.Value
            Add-Candidate -Candidates $candidates -Source "docs" -RepoFullName $identity.repoFullName -RepoUrl $identity.repoUrl -Reference (ConvertTo-RelativePath -Root $Root -Path $doc.FullName)
        }
    }

    return @($candidates)
}

function Read-ConfirmedModules {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    $raw = ""
    if (Test-Path -LiteralPath $Value) {
        $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $Value
    } else {
        $raw = $Value
    }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    $parsed = $raw | ConvertFrom-Json
    return @($parsed)
}

function Get-ModuleBaseBranch {
    param([string]$SourceRoot)

    if ([string]::IsNullOrWhiteSpace($SourceRoot) -or -not (Test-Path -LiteralPath $SourceRoot)) {
        return ""
    }

    $originHead = Invoke-Git -RepoRoot $SourceRoot -Arguments @("rev-parse", "--abbrev-ref", "origin/HEAD")
    if (-not [string]::IsNullOrWhiteSpace($originHead) -and $originHead -match "^origin/(?<branch>.+)$") {
        return $Matches["branch"]
    }

    $currentBranch = Invoke-Git -RepoRoot $SourceRoot -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    if (-not [string]::IsNullOrWhiteSpace($currentBranch) -and $currentBranch -ne "HEAD") {
        return $currentBranch
    }

    return ""
}

function New-ModuleRepo {
    param([object]$Module)

    $repoFullName = [string](Get-ObjectField -Object $Module -Name "repoFullName")
    $repoUrl = [string](Get-ObjectField -Object $Module -Name "repoUrl")
    if ([string]::IsNullOrWhiteSpace($repoUrl) -and -not [string]::IsNullOrWhiteSpace($repoFullName)) {
        $repoUrl = "https://github.com/$repoFullName"
    }

    $sourceRoot = [string](Get-ObjectField -Object $Module -Name "sourceRoot")
    $baseBranch = [string](Get-ObjectField -Object $Module -Name "baseBranch")
    if ([string]::IsNullOrWhiteSpace($baseBranch)) {
        $baseBranch = Get-ModuleBaseBranch -SourceRoot $sourceRoot
    }

    $displayName = [string](Get-ObjectField -Object $Module -Name "displayName")
    if ([string]::IsNullOrWhiteSpace($displayName) -and -not [string]::IsNullOrWhiteSpace($repoFullName)) {
        $displayName = ($repoFullName -split "/")[-1]
    }

    $id = [string](Get-ObjectField -Object $Module -Name "id")
    if ([string]::IsNullOrWhiteSpace($id)) {
        $id = ConvertTo-ProfileId -Value $displayName
    }

    $instructionPaths = @(ConvertTo-Array -Value (Get-ObjectField -Object $Module -Name "repoInstructionPaths"))
    if (@($instructionPaths).Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($sourceRoot) -and (Test-Path -LiteralPath $sourceRoot)) {
        $instructionPaths = @(Get-InstructionPaths -RepoRoot $sourceRoot)
    }

    return [pscustomobject]@{
        id = $id
        role = "module"
        displayName = $displayName
        repoFullName = $repoFullName
        repoUrl = $repoUrl
        sourceRoot = $sourceRoot
        baseBranch = $baseBranch
        todoProfile = [string](Get-ObjectField -Object $Module -Name "todoProfile")
        repoInstructionPaths = @($instructionPaths)
        ownershipRules = @(ConvertTo-Array -Value (Get-ObjectField -Object $Module -Name "ownershipRules"))
        validationRules = @(ConvertTo-Array -Value (Get-ObjectField -Object $Module -Name "validationRules"))
    }
}

function Add-MissingIfBlank {
    param(
        [System.Collections.IList]$Missing,
        [object]$Value,
        [string]$Message
    )

    if (Test-Blank -Value $Value) {
        [void]$Missing.Add($Message)
    }
}

function Add-MissingIfEmptyArray {
    param(
        [System.Collections.IList]$Missing,
        [object[]]$Value,
        [string]$Message
    )

    if (@($Value).Count -eq 0) {
        [void]$Missing.Add($Message)
    }
}

function Format-HumanResult {
    param([object]$Result)

    $lines = New-Object System.Collections.ArrayList
    if ($Result.created) {
        [void]$lines.Add("multi-repo profile을 생성했습니다.")
        [void]$lines.Add("")
        [void]$lines.Add("- profile: $($Result.profilePath)")
        [void]$lines.Add("- id: $($Result.profileId)")
        [void]$lines.Add("- module repos: $(@($Result.profile.repos | Where-Object { $_.role -eq 'module' }).Count)")
        [void]$lines.Add("")
        [void]$lines.Add("검증:")
        [void]$lines.Add(".\scripts\render-hub-prompt.ps1 -Profile `"$($Result.profilePath)`" -Action Register")
    } else {
        [void]$lines.Add("확인되지 않은 필수 값이 있어 profile 파일을 만들지 않았습니다.")
        [void]$lines.Add("")
        [void]$lines.Add("생성 예정 경로:")
        [void]$lines.Add("- $($Result.profilePath)")
        [void]$lines.Add("")
        [void]$lines.Add("필요한 확인:")
        foreach ($missing in @($Result.missingDecisions)) {
            [void]$lines.Add("- $missing")
        }
        [void]$lines.Add("")
        [void]$lines.Add("질문:")
        foreach ($question in @($Result.questions)) {
            [void]$lines.Add("- $question")
        }
        [void]$lines.Add("")
        [void]$lines.Add("자동 탐색 module 후보:")
        if (@($Result.candidateModules).Count -eq 0) {
            [void]$lines.Add("- 후보를 찾지 못했습니다. 수정 가능한 module repo와 local sourceRoot를 직접 알려주세요.")
        } else {
            foreach ($candidate in @($Result.candidateModules)) {
                $repoText = if ([string]::IsNullOrWhiteSpace($candidate.repoFullName)) { "(repo unknown)" } else { $candidate.repoFullName }
                $pathText = if ([string]::IsNullOrWhiteSpace($candidate.sourceRoot)) { "(path unknown)" } else { $candidate.sourceRoot }
                [void]$lines.Add("- $($candidate.displayName): $repoText, sourceRoot=$pathText, source=$($candidate.source)")
            }
        }
        if (@($Result.projectCandidates).Count -gt 0) {
            [void]$lines.Add("")
            [void]$lines.Add("ProjectV2 후보:")
            foreach ($project in @($Result.projectCandidates)) {
                [void]$lines.Add("- $($project.owner) #$($project.number) $($project.title)")
            }
        }
    }

    return ($lines -join [Environment]::NewLine)
}

$productRoot = (Resolve-Path -LiteralPath $ProductRepoRoot).Path
$candidateModules = Find-ModuleCandidates -Root $productRoot
$instructionPaths = Get-InstructionPaths -RepoRoot $productRoot

$ghRepo = Get-GhRepoInfo -RepoRoot $productRoot
if ([string]::IsNullOrWhiteSpace($ProductRepoFullName) -and $null -ne $ghRepo) {
    $ProductRepoFullName = [string]$ghRepo.nameWithOwner
}
if ([string]::IsNullOrWhiteSpace($ProductRepoUrl) -and $null -ne $ghRepo) {
    $ProductRepoUrl = [string]$ghRepo.url
}
if ([string]::IsNullOrWhiteSpace($ProductBaseBranch) -and $null -ne $ghRepo) {
    $defaultBranchRef = Get-ObjectField -Object $ghRepo -Name "defaultBranchRef"
    $ProductBaseBranch = [string](Get-ObjectField -Object $defaultBranchRef -Name "name")
}

if ([string]::IsNullOrWhiteSpace($ProductRepoFullName)) {
    $remoteUrl = Invoke-Git -RepoRoot $productRoot -Arguments @("remote", "get-url", "origin")
    $identity = ConvertFrom-GitHubUrl -Value $remoteUrl
    $ProductRepoFullName = $identity.repoFullName
    if ([string]::IsNullOrWhiteSpace($ProductRepoUrl)) {
        $ProductRepoUrl = $identity.repoUrl
    }
}

if ([string]::IsNullOrWhiteSpace($ProductRepoUrl) -and -not [string]::IsNullOrWhiteSpace($ProductRepoFullName)) {
    $ProductRepoUrl = "https://github.com/$ProductRepoFullName"
}

if ([string]::IsNullOrWhiteSpace($ProductBaseBranch)) {
    $originHead = Invoke-Git -RepoRoot $productRoot -Arguments @("rev-parse", "--abbrev-ref", "origin/HEAD")
    if (-not [string]::IsNullOrWhiteSpace($originHead) -and $originHead -match "^origin/(?<branch>.+)$") {
        $ProductBaseBranch = $Matches["branch"]
    }
}
if ([string]::IsNullOrWhiteSpace($ProductBaseBranch)) {
    $ProductBaseBranch = Invoke-Git -RepoRoot $productRoot -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
}

if ([string]::IsNullOrWhiteSpace($ProductTodoProfile)) {
    $ProductTodoProfile = $Profile
}
if ([string]::IsNullOrWhiteSpace($DisplayName)) {
    $DisplayName = "$Profile multi-repo"
}

$repoOwnerFromName = ""
if (-not [string]::IsNullOrWhiteSpace($ProductRepoFullName) -and $ProductRepoFullName.Contains("/")) {
    $repoOwnerFromName = ($ProductRepoFullName -split "/")[0]
}
if ([string]::IsNullOrWhiteSpace($ProjectOwner)) {
    $ProjectOwner = $repoOwnerFromName
}

$projectCandidates = @(Get-ProjectCandidates -Owner $ProjectOwner)
if ($ProjectNumber -le 0 -and [string]::IsNullOrWhiteSpace($ProjectTitle) -and @($projectCandidates).Count -eq 1) {
    $ProjectNumber = [int]$projectCandidates[0].number
    $ProjectTitle = [string]$projectCandidates[0].title
}

$targetPath = ""
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $targetPath = [System.IO.Path]::GetFullPath($OutputPath)
} elseif ($OutputScope -eq "RepoLocal") {
    $targetPath = Join-Path $productRoot ".codex\multi-repo-issue-orchestration\profiles\$Profile.json"
} else {
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
    $targetPath = Join-Path $codexHome "automation-profiles\multi-repo-issue-orchestration\$Profile.json"
}

$confirmedModules = Read-ConfirmedModules -Value $ConfirmedModulesJson
$moduleRepos = @()
foreach ($module in @($confirmedModules)) {
    $moduleRepos += New-ModuleRepo -Module $module
}

$missing = New-Object System.Collections.ArrayList
Add-MissingIfBlank -Missing $missing -Value $ProductRepoFullName -Message "product repoFullName을 확인해야 합니다."
Add-MissingIfBlank -Missing $missing -Value $ProductRepoUrl -Message "product repoUrl을 확인해야 합니다."
Add-MissingIfBlank -Missing $missing -Value $ProductBaseBranch -Message "product baseBranch를 확인해야 합니다."
Add-MissingIfEmptyArray -Missing $missing -Value $instructionPaths -Message "product repoInstructionPaths 후보를 찾지 못했습니다. product repo 지침 경로를 확인해야 합니다."
Add-MissingIfBlank -Missing $missing -Value $ProjectOwner -Message "GitHub Project owner를 확인해야 합니다."
if ($ProjectNumber -le 0) {
    [void]$missing.Add("GitHub ProjectV2 number를 확인해야 합니다.")
}
Add-MissingIfBlank -Missing $missing -Value $ProjectTitle -Message "GitHub ProjectV2 title을 확인해야 합니다."
Add-MissingIfEmptyArray -Missing $missing -Value $ProductOwnershipRules -Message "product ownershipRules를 확인해야 합니다."
Add-MissingIfEmptyArray -Missing $missing -Value $ProductValidationRules -Message "product validationRules를 확인해야 합니다."
if (@($moduleRepos).Count -eq 0) {
    [void]$missing.Add("수정 가능한 module repo 목록을 확인해야 합니다.")
}
Add-MissingIfEmptyArray -Missing $missing -Value $PackageSetupCommands -Message "product local test용 package override setupCommands를 확인해야 합니다."
Add-MissingIfEmptyArray -Missing $missing -Value $PackageVerifyCommands -Message "product local test용 package override verifyCommands를 확인해야 합니다."
Add-MissingIfEmptyArray -Missing $missing -Value $PackageRestoreCommands -Message "product local test용 package override restoreCommands를 확인해야 합니다."

$moduleIndex = 0
foreach ($repo in @($moduleRepos)) {
    Add-MissingIfBlank -Missing $missing -Value $repo.id -Message "module[$moduleIndex].id를 확인해야 합니다."
    Add-MissingIfBlank -Missing $missing -Value $repo.displayName -Message "module[$moduleIndex].displayName을 확인해야 합니다."
    Add-MissingIfBlank -Missing $missing -Value $repo.repoFullName -Message "module[$moduleIndex].repoFullName을 확인해야 합니다."
    Add-MissingIfBlank -Missing $missing -Value $repo.repoUrl -Message "module[$moduleIndex].repoUrl을 확인해야 합니다."
    Add-MissingIfBlank -Missing $missing -Value $repo.sourceRoot -Message "module[$moduleIndex].sourceRoot를 확인해야 합니다."
    Add-MissingIfBlank -Missing $missing -Value $repo.baseBranch -Message "module[$moduleIndex].baseBranch를 확인해야 합니다."
    Add-MissingIfBlank -Missing $missing -Value $repo.todoProfile -Message "module[$moduleIndex].todoProfile을 확인해야 합니다."
    Add-MissingIfEmptyArray -Missing $missing -Value $repo.repoInstructionPaths -Message "module[$moduleIndex].repoInstructionPaths를 확인해야 합니다."
    Add-MissingIfEmptyArray -Missing $missing -Value $repo.ownershipRules -Message "module[$moduleIndex].ownershipRules를 확인해야 합니다."
    Add-MissingIfEmptyArray -Missing $missing -Value $repo.validationRules -Message "module[$moduleIndex].validationRules를 확인해야 합니다."
    $moduleIndex += 1
}

$questions = @(
    "자동 탐색 후보 중 실제로 사용자가 수정 가능한 module repo는 무엇인가요?",
    "각 module repo의 local sourceRoot, baseBranch, todoProfile은 무엇인가요?",
    "product와 module별 ownershipRules, validationRules는 무엇인가요?",
    "product local test에서 module branch를 연결, 검증, 복원하는 setup/verify/restore command는 무엇인가요?",
    "profile을 product repo-local에 둘까요, 개인 CODEX_HOME에 둘까요? 개인 PC 절대 경로나 개인용 override command가 있으면 repo commit 대상이 아닙니다."
)

if ($missing.Count -gt 0) {
    $result = [pscustomobject]@{
        created = $false
        profileId = $Profile
        profilePath = $targetPath
        product = [pscustomobject]@{
            repoFullName = $ProductRepoFullName
            repoUrl = $ProductRepoUrl
            sourceRoot = $productRoot
            baseBranch = $ProductBaseBranch
            projectOwner = $ProjectOwner
            projectNumber = $ProjectNumber
            projectTitle = $ProjectTitle
            repoInstructionPaths = @($instructionPaths)
        }
        candidateModules = @($candidateModules)
        confirmedModules = @($moduleRepos)
        projectCandidates = @($projectCandidates)
        missingDecisions = @($missing)
        questions = @($questions)
    }

    if ($Json) {
        $result | ConvertTo-Json -Depth 20
    } else {
        Format-HumanResult -Result $result
    }
    exit 0
}

if ((Test-Path -LiteralPath $targetPath) -and -not $Force) {
    throw "Profile already exists: $targetPath. Use -Force to overwrite it."
}

$productRepo = [pscustomobject]@{
    id = "product"
    role = "product"
    displayName = $DisplayName
    repoFullName = $ProductRepoFullName
    repoUrl = $ProductRepoUrl
    sourceRoot = $productRoot
    baseBranch = $ProductBaseBranch
    todoProfile = $ProductTodoProfile
    repoInstructionPaths = @($instructionPaths)
    ownershipRules = @($ProductOwnershipRules)
    validationRules = @($ProductValidationRules)
}

$profileObject = [ordered]@{
    id = $Profile
    displayName = $DisplayName
    hub = [ordered]@{
        repoFullName = $ProductRepoFullName
        repoUrl = $ProductRepoUrl
        sourceRoot = $productRoot
        projectOwner = $ProjectOwner
        projectNumber = $ProjectNumber
        projectTitle = $ProjectTitle
        baseBranch = $ProductBaseBranch
        todoStatusName = "Todo"
        inProgressStatusName = "In Progress"
        issueReviewStatusName = "Issue Review"
        repoInstructionPaths = @($instructionPaths)
    }
    repos = @($productRepo) + @($moduleRepos)
    issueSplitRules = [ordered]@{
        singleIssueMaxEstimateHours = $SingleIssueMaxEstimateHours
    }
    packageOverrides = [ordered]@{
        setupCommands = @($PackageSetupCommands)
        verifyCommands = @($PackageVerifyCommands)
        restoreCommands = @($PackageRestoreCommands)
        expectedChangedPaths = @($PackageExpectedChangedPaths)
        notes = @($PackageNotes)
    }
    reportingRules = @(
        "Report hub issue, child issues, relationships, PR URLs, validation, blocked work, package override status, and restore commands."
    )
}

$targetDirectory = Split-Path -Parent $targetPath
if (-not (Test-Path -LiteralPath $targetDirectory)) {
    [void](New-Item -ItemType Directory -Path $targetDirectory)
}

$profileObject | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 -LiteralPath $targetPath

$createdResult = [pscustomobject]@{
    created = $true
    profileId = $Profile
    profilePath = $targetPath
    profile = $profileObject
    candidateModules = @($candidateModules)
}

if ($Json) {
    $createdResult | ConvertTo-Json -Depth 20
} else {
    Format-HumanResult -Result $createdResult
}

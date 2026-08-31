[CmdletBinding()]
param(
    [string]$ValidatorPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JSON file was not found: $Path"
    }

    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

$pluginRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $pluginRoot)
$plugin = Read-JsonFile -Path (Join-Path $pluginRoot ".codex-plugin\plugin.json")
$null = Read-JsonFile -Path (Join-Path $repoRoot ".agents\plugins\marketplace.json")

if ([string]::IsNullOrWhiteSpace($ValidatorPath)) {
    $codexRoot = if ($env:CODEX_HOME) {
        $env:CODEX_HOME
    } else {
        Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex"
    }
    $ValidatorPath = Join-Path $codexRoot "skills\.system\skill-creator\scripts\quick_validate.py"
}

if (-not (Test-Path -LiteralPath $ValidatorPath -PathType Leaf)) {
    throw "Skill validator was not found: $ValidatorPath"
}

$skillRoot = (Resolve-Path -LiteralPath (Join-Path $pluginRoot $plugin.skills)).Path
$skillDirectories = @(Get-ChildItem -LiteralPath $skillRoot -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md") -PathType Leaf
} | Sort-Object Name)

if ($skillDirectories.Count -eq 0) {
    throw "No skills were found under: $skillRoot"
}

$python = Get-Command python -CommandType Application -ErrorAction Stop
foreach ($skill in $skillDirectories) {
    & $python.Source $ValidatorPath $skill.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "Skill validation failed: $($skill.Name)"
    }
}

Write-Output "Validated $($skillDirectories.Count) skills and 2 JSON manifests."

param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceClaudeDir = Join-Path $repoRoot ".claude"
$userClaudeDir = Join-Path $HOME ".claude"

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Warning "claude CLI was not found on PATH. The hook will fail until Claude Code is installed and 'claude' is reachable."
}

New-Item -ItemType Directory -Force -Path $userClaudeDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $userClaudeDir "agents") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $userClaudeDir "hooks") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $userClaudeDir "hooks\lib") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $userClaudeDir "reference") | Out-Null

Copy-Item -LiteralPath (Join-Path $sourceClaudeDir "agents\markdown-guardian.md") `
    -Destination (Join-Path $userClaudeDir "agents\markdown-guardian.md") -Force
Copy-Item -LiteralPath (Join-Path $sourceClaudeDir "hooks\auto-fix-markdown.ps1") `
    -Destination (Join-Path $userClaudeDir "hooks\auto-fix-markdown.ps1") -Force
Copy-Item -LiteralPath (Join-Path $sourceClaudeDir "hooks\lib\extract-markdown-paths.ps1") `
    -Destination (Join-Path $userClaudeDir "hooks\lib\extract-markdown-paths.ps1") -Force
Copy-Item -LiteralPath (Join-Path $sourceClaudeDir "reference\markdown-rules-summary.md") `
    -Destination (Join-Path $userClaudeDir "reference\markdown-rules-summary.md") -Force

$settingsPath = Join-Path $userClaudeDir "settings.json"
$hookCommand = 'Set-ExecutionPolicy -Scope Process Bypass -Force; & "$HOME\.claude\hooks\auto-fix-markdown.ps1"'
$hookCommandMarker = "auto-fix-markdown.ps1"

function Test-HasProperty {
    param([object]$Node, [string]$Name)
    if ($null -eq $Node) { return $false }
    foreach ($p in $Node.PSObject.Properties) {
        if ($p.Name -eq $Name) { return $true }
    }
    return $false
}

if (Test-Path -LiteralPath $settingsPath) {
    Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak" -Force
    $rawSettings = Get-Content -Raw -LiteralPath $settingsPath
    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $settings = $rawSettings | ConvertFrom-Json -Depth 100
        } else {
            $settings = $rawSettings | ConvertFrom-Json
        }
    } catch {
        Write-Error ("$settingsPath is not valid JSON: $($_.Exception.Message)`n" +
            "Original file is unchanged; backup at $settingsPath.bak`n" +
            "Fix the JSON and re-run the installer.")
        exit 1
    }
    if ($null -eq $settings) { $settings = [pscustomobject]@{} }
} else {
    $settings = [pscustomobject]@{}
}

if (-not (Test-HasProperty $settings "hooks")) {
    $settings | Add-Member -MemberType NoteProperty -Name hooks -Value ([pscustomobject]@{})
}

if (-not (Test-HasProperty $settings.hooks "PostToolUse")) {
    $settings.hooks | Add-Member -MemberType NoteProperty -Name PostToolUse -Value @()
}

$filteredGroups = @()
foreach ($group in @($settings.hooks.PostToolUse)) {
    $kept = @($group.hooks | Where-Object { $_.command -notlike "*$hookCommandMarker*" })
    if ($kept.Count -gt 0) {
        $group.hooks = $kept
        $filteredGroups += $group
    }
}
$settings.hooks.PostToolUse = $filteredGroups

$newGroup = [pscustomobject]@{
    matcher = "Write|Edit|MultiEdit"
    hooks = @(
        [pscustomobject]@{
            type = "command"
            shell = "powershell"
            command = $hookCommand
            timeout = 300
            statusMessage = "markdown-guardian: checking Markdown files"
        }
    )
}

$settings.hooks.PostToolUse = @($settings.hooks.PostToolUse) + $newGroup

$settings | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $settingsPath -Encoding UTF8

Write-Host "Installed markdown-guardian to $userClaudeDir"
Write-Host "Agent: $HOME\.claude\agents\markdown-guardian.md"
Write-Host "Hook : $HOME\.claude\hooks\auto-fix-markdown.ps1"
Write-Host "Settings updated: $settingsPath (backup at $settingsPath.bak if it already existed)"
Write-Host "Verify: edit any .md file in a Claude Code session; status line should show 'markdown-guardian: checking Markdown files'."

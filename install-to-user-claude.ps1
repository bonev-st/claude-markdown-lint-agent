param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceClaudeDir = Join-Path $repoRoot ".claude"
$userClaudeDir = Join-Path $HOME ".claude"

New-Item -ItemType Directory -Force -Path $userClaudeDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $userClaudeDir "agents") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $userClaudeDir "hooks") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $userClaudeDir "reference") | Out-Null

Copy-Item -LiteralPath (Join-Path $sourceClaudeDir "agents\markdown-guardian.md") `
    -Destination (Join-Path $userClaudeDir "agents\markdown-guardian.md") -Force
Copy-Item -LiteralPath (Join-Path $sourceClaudeDir "hooks\auto-fix-markdown.ps1") `
    -Destination (Join-Path $userClaudeDir "hooks\auto-fix-markdown.ps1") -Force
Copy-Item -LiteralPath (Join-Path $sourceClaudeDir "reference\markdown-rules-summary.md") `
    -Destination (Join-Path $userClaudeDir "reference\markdown-rules-summary.md") -Force

$settingsPath = Join-Path $userClaudeDir "settings.json"
$hookCommand = "& `"$HOME\.claude\hooks\auto-fix-markdown.ps1`""

if (Test-Path -LiteralPath $settingsPath) {
    $settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json -Depth 100
} else {
    $settings = [pscustomobject]@{}
}

if (-not ($settings.PSObject.Properties.Name -contains "hooks")) {
    $settings | Add-Member -MemberType NoteProperty -Name hooks -Value ([pscustomobject]@{})
}

if (-not ($settings.hooks.PSObject.Properties.Name -contains "PostToolUse")) {
    $settings.hooks | Add-Member -MemberType NoteProperty -Name PostToolUse -Value @()
}

$alreadyExists = $false
foreach ($group in @($settings.hooks.PostToolUse)) {
    foreach ($hook in @($group.hooks)) {
        if ($hook.command -eq $hookCommand) {
            $alreadyExists = $true
        }
    }
}

if (-not $alreadyExists) {
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
}

$settings | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $settingsPath -Encoding UTF8

Write-Host "Installed markdown-guardian to $userClaudeDir"
Write-Host "Agent: $HOME\.claude\agents\markdown-guardian.md"
Write-Host "Hook : $HOME\.claude\hooks\auto-fix-markdown.ps1"
Write-Host "Settings updated: $settingsPath"

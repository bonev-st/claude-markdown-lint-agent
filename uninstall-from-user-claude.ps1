param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$userClaudeDir = Join-Path $HOME ".claude"
$settingsPath = Join-Path $userClaudeDir "settings.json"
$hookCommand = '& "$HOME\.claude\hooks\auto-fix-markdown.ps1"'

Remove-Item -LiteralPath (Join-Path $userClaudeDir "agents\markdown-guardian.md") -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $userClaudeDir "hooks\auto-fix-markdown.ps1") -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $userClaudeDir "hooks\lib\extract-markdown-paths.ps1") -Force -ErrorAction SilentlyContinue
$libDir = Join-Path $userClaudeDir "hooks\lib"
if ((Test-Path -LiteralPath $libDir) -and -not (Get-ChildItem -LiteralPath $libDir -Force)) {
    Remove-Item -LiteralPath $libDir -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath (Join-Path $userClaudeDir "reference\markdown-rules-summary.md") -Force -ErrorAction SilentlyContinue
Write-Host "Removed markdown-guardian agent, hook, extractor, and reference from $userClaudeDir."

if (-not (Test-Path -LiteralPath $settingsPath)) {
    Write-Host "No $settingsPath; nothing further to do."
    exit 0
}

function Test-HasProperty {
    param([object]$Node, [string]$Name)
    if ($null -eq $Node) { return $false }
    foreach ($p in $Node.PSObject.Properties) {
        if ($p.Name -eq $Name) { return $true }
    }
    return $false
}

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
        "Fix the JSON and re-run the uninstaller.")
    exit 1
}

if ((Test-HasProperty $settings "hooks") -and (Test-HasProperty $settings.hooks "PostToolUse")) {

    $newGroups = @()
    foreach ($group in @($settings.hooks.PostToolUse)) {
        $kept = @($group.hooks | Where-Object { $_.command -ne $hookCommand })
        if ($kept.Count -gt 0) {
            $group.hooks = $kept
            $newGroups += $group
        }
    }

    if ($newGroups.Count -gt 0) {
        $settings.hooks.PostToolUse = $newGroups
    } else {
        $settings.hooks.PSObject.Properties.Remove("PostToolUse")
    }

    $hooksPropCount = 0
    foreach ($p in $settings.hooks.PSObject.Properties) { $hooksPropCount++ }
    if ($hooksPropCount -eq 0) {
        $settings.PSObject.Properties.Remove("hooks")
    }
}

$settings | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
Write-Host "Updated $settingsPath (backup at $settingsPath.bak)."

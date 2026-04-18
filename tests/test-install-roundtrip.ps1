param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$installer = Join-Path $repoRoot "install-to-user-claude.ps1"
$uninstaller = Join-Path $repoRoot "uninstall-from-user-claude.ps1"
$hookCommand = "& `"`$HOME\.claude\hooks\auto-fix-markdown.ps1`""

$script:pass = 0
$script:fail = 0

function Check {
    param([string]$Message, [scriptblock]$Assertion)
    try {
        if (& $Assertion) {
            Write-Host "    PASS $Message"
            $script:pass++
        } else {
            Write-Host "    FAIL $Message"
            $script:fail++
        }
    } catch {
        Write-Host "    FAIL $Message ($_)"
        $script:fail++
    }
}

function New-TempHome {
    $t = Join-Path ([System.IO.Path]::GetTempPath()) ("md-guardian-roundtrip-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $t | Out-Null
    return $t
}

function Invoke-InChildHome {
    param([string]$TmpHome, [string]$ScriptPath, [switch]$ExpectFail)

    $oldHD = $env:HOMEDRIVE
    $oldHP = $env:HOMEPATH
    $oldUP = $env:USERPROFILE
    $prevEAP = $ErrorActionPreference
    try {
        $env:HOMEDRIVE = ($TmpHome -split ":", 2)[0] + ":"
        $env:HOMEPATH = ($TmpHome -split ":", 2)[1]
        $env:USERPROFILE = $TmpHome
        $ErrorActionPreference = "Continue"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath *> $null
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEAP
        $env:HOMEDRIVE = $oldHD
        $env:HOMEPATH = $oldHP
        $env:USERPROFILE = $oldUP
    }
    if ($ExpectFail) {
        return ($code -ne 0)
    }
    return ($code -eq 0)
}

function Test-HasProperty {
    param([object]$Node, [string]$Name)
    if ($null -eq $Node) { return $false }
    foreach ($p in $Node.PSObject.Properties) {
        if ($p.Name -eq $Name) { return $true }
    }
    return $false
}

function Get-HookEntryCount {
    param([string]$SettingsPath)
    if (-not (Test-Path -LiteralPath $SettingsPath)) { return 0 }
    $raw = Get-Content -Raw -LiteralPath $SettingsPath
    if ([string]::IsNullOrWhiteSpace($raw)) { return 0 }
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $s = $raw | ConvertFrom-Json -Depth 100
    } else {
        $s = $raw | ConvertFrom-Json
    }
    $count = 0
    if (Test-HasProperty $s "hooks") {
        $h = $s.hooks
        if (Test-HasProperty $h "PostToolUse") {
            foreach ($g in @($h.PostToolUse)) {
                foreach ($hk in @($g.hooks)) {
                    if ($hk.command -eq $hookCommand) { $count++ }
                }
            }
        }
    }
    return $count
}

function Has-PreexistingHook {
    param([string]$SettingsPath)
    $raw = Get-Content -Raw -LiteralPath $SettingsPath
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $s = $raw | ConvertFrom-Json -Depth 100
    } else {
        $s = $raw | ConvertFrom-Json
    }
    foreach ($g in @($s.hooks.PostToolUse)) {
        foreach ($hk in @($g.hooks)) {
            if ($hk.command -eq "echo preexisting") { return $true }
        }
    }
    return $false
}

Write-Host "Scenario: fresh install -> re-install -> uninstall"
$tmp = New-TempHome
[void](Invoke-InChildHome -TmpHome $tmp -ScriptPath $installer)
$settings = Join-Path $tmp ".claude\settings.json"
Check "agent file installed" { Test-Path (Join-Path $tmp ".claude\agents\markdown-guardian.md") }
Check "hook file installed" { Test-Path (Join-Path $tmp ".claude\hooks\auto-fix-markdown.ps1") }
Check "extractor installed" { Test-Path (Join-Path $tmp ".claude\hooks\lib\extract-markdown-paths.ps1") }
Check "reference installed" { Test-Path (Join-Path $tmp ".claude\reference\markdown-rules-summary.md") }
Check "settings.json created" { Test-Path $settings }
Check "one hook entry" { (Get-HookEntryCount $settings) -eq 1 }

[void](Invoke-InChildHome -TmpHome $tmp -ScriptPath $installer)
Check "re-install stays idempotent (still 1 entry)" { (Get-HookEntryCount $settings) -eq 1 }

[void](Invoke-InChildHome -TmpHome $tmp -ScriptPath $uninstaller)
Check "agent removed" { -not (Test-Path (Join-Path $tmp ".claude\agents\markdown-guardian.md")) }
Check "hook removed" { -not (Test-Path (Join-Path $tmp ".claude\hooks\auto-fix-markdown.ps1")) }
Check "extractor removed" { -not (Test-Path (Join-Path $tmp ".claude\hooks\lib\extract-markdown-paths.ps1")) }
Check "reference removed" { -not (Test-Path (Join-Path $tmp ".claude\reference\markdown-rules-summary.md")) }
Check "zero hook entries after uninstall" { (Get-HookEntryCount $settings) -eq 0 }
Remove-Item -Recurse -Force $tmp

Write-Host "Scenario: install preserves unrelated settings"
$tmp = New-TempHome
New-Item -ItemType Directory -Path (Join-Path $tmp ".claude") | Out-Null
$settings = Join-Path $tmp ".claude\settings.json"
@'
{
  "permissions": {
    "allow": ["Bash(ls:*)"]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "shell": "powershell", "command": "echo preexisting"}
        ]
      }
    ]
  }
}
'@ | Set-Content -LiteralPath $settings -Encoding UTF8

[void](Invoke-InChildHome -TmpHome $tmp -ScriptPath $installer)
Check "preexisting permissions survive" {
    $raw = Get-Content -Raw -LiteralPath $settings
    $s = if ($PSVersionTable.PSVersion.Major -ge 6) { $raw | ConvertFrom-Json -Depth 100 } else { $raw | ConvertFrom-Json }
    $s.permissions.allow -contains "Bash(ls:*)"
}
Check "our entry added (now 1)" { (Get-HookEntryCount $settings) -eq 1 }
Check "preexisting hook entry still present" { Has-PreexistingHook $settings }

[void](Invoke-InChildHome -TmpHome $tmp -ScriptPath $uninstaller)
Check "our entry removed after uninstall" { (Get-HookEntryCount $settings) -eq 0 }
Check "preexisting permissions still survive" {
    $raw = Get-Content -Raw -LiteralPath $settings
    $s = if ($PSVersionTable.PSVersion.Major -ge 6) { $raw | ConvertFrom-Json -Depth 100 } else { $raw | ConvertFrom-Json }
    $s.permissions.allow -contains "Bash(ls:*)"
}
Check "preexisting hook entry still present after uninstall" { Has-PreexistingHook $settings }
Remove-Item -Recurse -Force $tmp

Write-Host "Scenario: malformed settings.json is not overwritten"
$tmp = New-TempHome
New-Item -ItemType Directory -Path (Join-Path $tmp ".claude") | Out-Null
$settings = Join-Path $tmp ".claude\settings.json"
'{ this is not valid json' | Set-Content -LiteralPath $settings -Encoding UTF8 -NoNewline
$origBytes = [System.IO.File]::ReadAllBytes($settings)
$origHash = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash($origBytes))

Check "installer exits non-zero on bad JSON" {
    Invoke-InChildHome -TmpHome $tmp -ScriptPath $installer -ExpectFail
}
$afterBytes = [System.IO.File]::ReadAllBytes($settings)
$afterHash = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash($afterBytes))
Check "settings.json is byte-for-byte unchanged" { $afterHash -eq $origHash }
Check "backup was created" { Test-Path (Join-Path $tmp ".claude\settings.json.bak") }
Remove-Item -Recurse -Force $tmp

Write-Host ""
Write-Host "$pass passed, $fail failed"
if ($fail -gt 0) { exit 1 }

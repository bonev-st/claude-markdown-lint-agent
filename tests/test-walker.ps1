param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$extractor = Join-Path $repoRoot ".claude\hooks\lib\extract-markdown-paths.ps1"
$payloadsDir = Join-Path $scriptDir "hook-payloads"

if (-not (Test-Path -LiteralPath $extractor)) {
    Write-Error "missing extractor at $extractor"
    exit 1
}

function Normalize {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $lines = ($Text -split "`r?`n") | Where-Object { $_ -and $_.Trim() }
    return (($lines | Sort-Object) -join "`n")
}

$pass = 0
$fail = 0

Get-ChildItem -Path $payloadsDir -Filter *.json | ForEach-Object {
    $name = $_.BaseName
    $expectedFile = Join-Path $payloadsDir "$name.expected"
    if (-not (Test-Path -LiteralPath $expectedFile)) {
        Write-Host "  SKIP $name (no .expected)"
        return
    }

    $expectedRaw = Get-Content -Raw -LiteralPath $expectedFile
    $actualRaw = (& $extractor -PayloadPath $_.FullName | Out-String)

    $expectedN = Normalize $expectedRaw
    $actualN = Normalize $actualRaw

    if ($expectedN -eq $actualN) {
        Write-Host "  PASS $name"
        $script:pass++
    } else {
        Write-Host "  FAIL $name"
        Write-Host "    expected:"
        ($expectedN -split "`n") | ForEach-Object { Write-Host "      $_" }
        Write-Host "    actual:"
        ($actualN -split "`n") | ForEach-Object { Write-Host "      $_" }
        $script:fail++
    }
}

Write-Host "$pass passed, $fail failed"
if ($fail -gt 0) {
    exit 1
}

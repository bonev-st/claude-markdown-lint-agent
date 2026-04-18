param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($env:MARKDOWN_GUARDIAN_ACTIVE -eq "1") {
    exit 0
}

$rawInput = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($rawInput)) {
    exit 0
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$extractor = Join-Path $scriptDir "lib\extract-markdown-paths.ps1"

if (-not (Test-Path -LiteralPath $extractor)) {
    Write-Error "markdown-guardian: extractor missing at $extractor"
    exit 0
}

$tempPayload = [System.IO.Path]::GetTempFileName()
try {
    Set-Content -LiteralPath $tempPayload -Value $rawInput -Encoding UTF8 -NoNewline
    $extracted = & $extractor -PayloadPath $tempPayload
} finally {
    Remove-Item -LiteralPath $tempPayload -ErrorAction SilentlyContinue
}

$paths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($extracted) {
    foreach ($line in @($extracted)) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            [void]$paths.Add($line.Trim())
        }
    }
}

if ($paths.Count -eq 0) {
    exit 0
}

$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$userReferencePath = Join-Path $HOME ".claude\reference\markdown-rules-summary.md"
$projectReferencePath = Join-Path $projectDir ".claude\reference\markdown-rules-summary.md"
$referencePath = if (Test-Path -LiteralPath $userReferencePath -PathType Leaf) {
    $userReferencePath
} else {
    $projectReferencePath
}

foreach ($path in $paths) {
    $fullPath = if ([System.IO.Path]::IsPathRooted($path)) {
        $path
    } else {
        Join-Path $projectDir $path
    }

    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        continue
    }

    $resolved = (Resolve-Path -LiteralPath $fullPath).Path

    if ($resolved -like "*\.claude\*") {
        continue
    }

    $prompt = @"
Review and correct the Markdown file at "$resolved".

Read the rule summary at "$referencePath" and apply only the safe,
formatting-only fixes it lists. Preserve meaning, code samples, links, and
the original language. If the file is already acceptable, leave it unchanged.
Return only a short summary that names the rule-summary version you applied.
"@

    $env:MARKDOWN_GUARDIAN_ACTIVE = "1"
    try {
        $output = & claude `
            -p $prompt `
            --agent markdown-guardian `
            --permission-mode acceptEdits 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning ("markdown-guardian failed for {0}: {1}" -f $resolved, ($output | Out-String).Trim())
        }
    } finally {
        Remove-Item Env:MARKDOWN_GUARDIAN_ACTIVE -ErrorAction SilentlyContinue
    }
}

exit 0

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

try {
    $payload = $rawInput | ConvertFrom-Json -Depth 100
} catch {
    Write-Error "markdown-guardian: invalid hook JSON input"
    exit 0
}

function Add-MarkdownPath {
    param(
        [System.Collections.Generic.HashSet[string]]$Set,
        [string]$Candidate
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return
    }

    $trimmed = $Candidate.Trim()
    $extension = [System.IO.Path]::GetExtension($trimmed)
    if ($extension -in @(".md", ".markdown")) {
        [void]$Set.Add($trimmed)
    }
}

function Collect-MarkdownPaths {
    param(
        [object]$Node,
        [System.Collections.Generic.HashSet[string]]$Set
    )

    if ($null -eq $Node) {
        return
    }

    if ($Node -is [string]) {
        Add-MarkdownPath -Set $Set -Candidate $Node
        return
    }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in $Node) {
            Collect-MarkdownPaths -Node $item -Set $Set
        }
        return
    }

    foreach ($property in $Node.PSObject.Properties) {
        $name = $property.Name
        $value = $property.Value

        if ($name -match "file_path|path|paths|file_paths") {
            Collect-MarkdownPaths -Node $value -Set $Set
            continue
        }

        if ($value -isnot [string] -and $value -isnot [ValueType]) {
            Collect-MarkdownPaths -Node $value -Set $Set
        }
    }
}

$paths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
Collect-MarkdownPaths -Node $payload.tool_input -Set $paths

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

First read the rule summary at "$referencePath".

Apply only safe Markdown fixes:
- heading hierarchy and blank lines
- list indentation and list marker consistency
- trailing whitespace, tabs, and excessive blank lines
- fenced code block spacing when safe
- table formatting and surrounding blank lines
- link syntax and descriptive link text when obvious

Do not add new content. Preserve meaning, code samples, links, and the original language.
If the file is already acceptable, leave it unchanged.
Return only a short summary.
"@

    $env:MARKDOWN_GUARDIAN_ACTIVE = "1"
    try {
        $output = & claude `
            -p $prompt `
            --agent markdown-guardian `
            --permission-mode acceptEdits `
            --allowedTools "Read,Edit,MultiEdit,Write,Glob,Grep" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning ("markdown-guardian failed for {0}: {1}" -f $resolved, ($output | Out-String).Trim())
        }
    } finally {
        Remove-Item Env:MARKDOWN_GUARDIAN_ACTIVE -ErrorAction SilentlyContinue
    }
}

exit 0

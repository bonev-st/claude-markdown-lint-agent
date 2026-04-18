# Extract .md / .markdown file paths from a Claude Code hook JSON payload.
#
# Reads JSON from stdin (or from a file path given as the first argument)
# and writes one candidate path per line to stdout. Silent on malformed
# input.
#
# Used by auto-fix-markdown.ps1 and by the tests under tests/.

param([string]$PayloadPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($PSBoundParameters.ContainsKey("PayloadPath") -and $PayloadPath) {
    $raw = Get-Content -Raw -LiteralPath $PayloadPath
} else {
    $raw = [Console]::In.ReadToEnd()
}

if ([string]::IsNullOrWhiteSpace($raw)) {
    exit 0
}

try {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $payload = $raw | ConvertFrom-Json -Depth 100
    } else {
        $payload = $raw | ConvertFrom-Json
    }
} catch {
    exit 0
}

$pathKeys = @("file_path", "path", "paths", "file_paths")
$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

function Add-Candidate {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $trimmed = $Value.Trim()
    $ext = [System.IO.Path]::GetExtension($trimmed)
    if ($ext -in @(".md", ".markdown")) {
        if ($seen.Add($trimmed)) {
            Write-Output $trimmed
        }
    }
}

function Walk-Node {
    param([object]$Node)

    if ($null -eq $Node) { return }

    if ($Node -is [string]) {
        Add-Candidate -Value $Node
        return
    }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in $Node) { Walk-Node -Node $item }
        return
    }

    foreach ($property in $Node.PSObject.Properties) {
        $name = $property.Name
        $value = $property.Value

        if ($pathKeys -contains $name) {
            Walk-Node -Node $value
        } elseif ($value -isnot [string] -and $value -isnot [ValueType]) {
            Walk-Node -Node $value
        }
    }
}

function Get-Property {
    param([object]$Node, [string]$Name)
    if ($null -eq $Node) { return $null }
    foreach ($p in $Node.PSObject.Properties) {
        if ($p.Name -eq $Name) { return $p.Value }
    }
    return $null
}

$toolInput = Get-Property -Node $payload -Name "tool_input"
if ($null -ne $toolInput) {
    Walk-Node -Node $toolInput
}

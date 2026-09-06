<#
.SYNOPSIS
    Builds the ROM filesystem allocation table from a manifest of BASIC programs.
.DESCRIPTION
    Reads a "NAME = path/to/file.bas" manifest (see Programs.txt), normalizes each
    referenced BASIC source file (BOM stripped, CRLF line endings, trailing blank
    lines removed, single trailing CRLF added, ASCII only), and emits a vasm
    source file defining FS_TABLE: the allocation table the ROM filesystem code
    in Basic.s searches for LOAD / FILES / the AUTO boot program. Programs are
    embedded via "incbin" from normalized copies written next to the generated
    source, so the assembler always sees exactly what shipped.

    An "AUTO" entry in the manifest may either name an already-declared program
    (the ROM filesystem entry is then a zero-cost alias, same data pointer) or
    a direct path to its own file.
.PARAMETER Manifest
    Path to the manifest file (NAME = path pairs; '#' comments and blank lines
    are ignored).
.PARAMETER Output
    Path to the generated .s file (overwritten). Normalized program data is
    written as .bin files in a "fs" folder next to it, referenced by "incbin"
    with a path relative to Output (vasm resolves incbin relative to the
    including source file, not the current directory).
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Manifest,

    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Manifest -PathType Leaf)) {
    throw "Manifest file not found: $Manifest"
}

# Strips a UTF-8 BOM, normalizes line endings to CRLF, drops trailing blank
# lines, guarantees a single trailing CRLF, and rejects any non-ASCII byte
# (the fix layer can only display ASCII).
function Get-NormalizedBasicBytes {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Program file not found: $Path"
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length - 1)]
    }

    for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -gt 0x7F) {
            throw "Non-ASCII byte 0x$($bytes[$i].ToString('X2')) at offset $i in '$Path' - the fix layer can only display ASCII."
        }
    }

    $text = [System.Text.Encoding]::ASCII.GetString($bytes)
    $lines = [System.Collections.Generic.List[string]]($text -split "`r`n|`n|`r")
    while ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -eq '') {
        $lines.RemoveAt($lines.Count - 1)
    }

    if ($lines.Count -eq 0) {
        return [byte[]]@()
    }

    $normalized = ($lines -join "`r`n") + "`r`n"
    return [System.Text.Encoding]::ASCII.GetBytes($normalized)
}

# --- parse the manifest ---------------------------------------------------

$namePattern = '^[A-Za-z0-9_]{1,15}$'

$order = New-Object System.Collections.Generic.List[string]
$paths = @{}
$autoTarget = $null

foreach ($rawLine in (Get-Content -LiteralPath $Manifest -Encoding UTF8)) {
    $line = $rawLine.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { continue }

    $eq = $line.IndexOf('=')
    if ($eq -lt 0) {
        throw "Malformed manifest line (expected NAME = path): '$rawLine'"
    }

    $key = $line.Substring(0, $eq).Trim()
    $value = $line.Substring($eq + 1).Trim()

    if ($key -eq 'AUTO') {
        if ($null -ne $autoTarget) {
            throw "AUTO is declared more than once in the manifest."
        }
        $autoTarget = $value
        continue
    }

    if ($key -notmatch $namePattern) {
        throw "Invalid program name '$key': must be 1-15 letters, digits or underscore."
    }

    $upperKey = $key.ToUpperInvariant()
    if ($paths.ContainsKey($upperKey)) {
        throw "Duplicate program name (names are case-insensitive at LOAD time): '$key'"
    }

    $paths[$upperKey] = @{ Name = $key; Path = $value }
    $order.Add($upperKey)
}

# --- resolve AUTO: alias of a declared program, or its own file ----------

$autoIsAlias = $false
$autoOwnPath = $null
if ($null -ne $autoTarget) {
    $autoKeyUpper = $autoTarget.ToUpperInvariant()
    if ($paths.ContainsKey($autoKeyUpper)) {
        $autoIsAlias = $true
    }
    else {
        $autoOwnPath = $autoTarget
    }
}

# --- normalize every referenced file once, keyed by manifest name --------

$blobs = [ordered]@{}

foreach ($upperKey in $order) {
    $bytes = Get-NormalizedBasicBytes -Path $paths[$upperKey].Path
    $blobs[$upperKey] = @{ Label = "FS_DATA_$upperKey"; Bytes = $bytes; File = "$upperKey.bin" }
}

$autoBlobKey = $null
if ($null -ne $autoTarget) {
    if ($autoIsAlias) {
        $autoBlobKey = $autoKeyUpper
    }
    else {
        $blobs['AUTO'] = @{ Label = 'FS_DATA_AUTO'; Bytes = (Get-NormalizedBasicBytes -Path $autoOwnPath); File = 'AUTO.bin' }
        $autoBlobKey = 'AUTO'
    }
}

# --- assemble the (name, blob) entry list, AUTO last if present ----------

$entries = New-Object System.Collections.Generic.List[object]
foreach ($upperKey in $order) {
    $entries.Add(@{ Name = $paths[$upperKey].Name; BlobKey = $upperKey })
}
if ($null -ne $autoTarget) {
    $entries.Add(@{ Name = 'AUTO'; BlobKey = $autoBlobKey })
}

# --- write the normalized program data next to the generated source ------

$outputDir = Split-Path -Parent $Output
if ($outputDir -eq '') { $outputDir = '.' }
$blobDir = Join-Path $outputDir 'fs'
New-Item -ItemType Directory -Force -Path $blobDir | Out-Null

foreach ($key in $blobs.Keys) {
    $blob = $blobs[$key]
    [System.IO.File]::WriteAllBytes((Join-Path $blobDir $blob.File), $blob.Bytes)
}

# --- emit the vasm source --------------------------------------------------

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("; Generated by MakeFileSystem.ps1 from '$Manifest' - do not edit by hand.")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('	global FS_TABLE')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('	section text')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('	even')
[void]$sb.AppendLine('FS_TABLE:')
[void]$sb.AppendLine("	dc.b 'NBFS'")
[void]$sb.AppendLine('	dc.w 1')
[void]$sb.AppendLine("	dc.w $($entries.Count)")

foreach ($entry in $entries) {
    $name = $entry.Name
    $padding = ',0' * (16 - $name.Length)
    $blob = $blobs[$entry.BlobKey]
    [void]$sb.AppendLine("	dc.b '$name'$padding")
    [void]$sb.AppendLine("	dc.l $($blob.Label)")
    [void]$sb.AppendLine("	dc.l $($blob.Label)_END-$($blob.Label)")
}

[void]$sb.AppendLine('')

$totalBytes = 0
foreach ($key in $blobs.Keys) {
    $blob = $blobs[$key]
    [void]$sb.AppendLine('	even')
    [void]$sb.AppendLine("$($blob.Label):")
    [void]$sb.AppendLine("	incbin ""fs/$($blob.File)""")
    [void]$sb.AppendLine("$($blob.Label)_END:")
    $totalBytes += $blob.Bytes.Length
}
[void]$sb.AppendLine('	even')

Set-Content -LiteralPath $Output -Value $sb.ToString() -Encoding ASCII -NoNewline

Write-Host "Built '$Output': $($entries.Count) program(s), $($blobs.Count) blob(s), $totalBytes bytes total."

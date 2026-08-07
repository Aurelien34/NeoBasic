<#
.SYNOPSIS
    Converts a "labels" format BASIC source file into a numbered "basic" format file.
.DESCRIPTION
    The source file uses @label declarations ("@name:") instead of line numbers, and
    jump targets are written as "@name" after GOTO / GOSUB / THEN / ELSE. This script
    assigns line numbers starting at 10, incrementing by 10, strips label declarations,
    and rewrites jump targets to the resolved line numbers.
.PARAMETER Source
    Path to the input "labels" format file.
.PARAMETER Destination
    Path to the output "basic" format file (overwritten if it already exists).
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Source,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Destination
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
    throw "Source file not found: $Source"
}

$sourceLines = Get-Content -LiteralPath $Source -Encoding UTF8

$labelDeclPattern = '^\s*@(?<name>[A-Za-z_]\w*):(?<rest>.*)$'

# First pass: strip label declarations, record what emitted line index each label resolves to.
$emittedLines = New-Object System.Collections.Generic.List[string]
$labelTarget = @{}
$labelDeclLine = @{}

for ($i = 0; $i -lt $sourceLines.Count; $i++) {
    $line = $sourceLines[$i]
    $sourceLineNumber = $i + 1
    $match = [regex]::Match($line, $labelDeclPattern)

    if ($match.Success) {
        $name = $match.Groups['name'].Value
        $rest = $match.Groups['rest'].Value

        if ($labelDeclLine.ContainsKey($name)) {
            throw "Label '@$name' declared more than once (source lines $($labelDeclLine[$name]) and $sourceLineNumber)."
        }
        $labelDeclLine[$name] = $sourceLineNumber

        if ($rest.Trim() -eq '') {
            # Bare label declaration: the whole line is dropped, label points to the next emitted line.
            $labelTarget[$name] = $emittedLines.Count
        }
        else {
            # Label followed by code on the same line: only the "@name:" prefix is dropped.
            $labelTarget[$name] = $emittedLines.Count
            $emittedLines.Add($rest)
        }
    }
    elseif ($line.Trim() -ne '') {
        $emittedLines.Add($line)
    }
}

foreach ($name in $labelTarget.Keys) {
    if ($labelTarget[$name] -ge $emittedLines.Count) {
        throw "Label '@$name' (declared at source line $($labelDeclLine[$name])) has no following line."
    }
}

# Assign line numbers: 10, 20, 30, ...
$lineNumbers = for ($i = 0; $i -lt $emittedLines.Count; $i++) { 10 + $i * 10 }

# Second pass: resolve @label references that follow GOTO / GOSUB / THEN / ELSE.
$labelRefPattern = '(?i)\b(GOTO|GOSUB|THEN|ELSE)\b((?:\s*,?\s*@[A-Za-z_]\w*)+)'
$atTokenPattern = '@(?<name>[A-Za-z_]\w*)'

$resultLines = New-Object System.Collections.Generic.List[string]

for ($i = 0; $i -lt $emittedLines.Count; $i++) {
    $content = $emittedLines[$i]
    $currentLineNumber = $lineNumbers[$i]

    $refEvaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)

        $keyword = $m.Groups[1].Value
        $targets = $m.Groups[2].Value

        $tokenEvaluator = [System.Text.RegularExpressions.MatchEvaluator]{
            param($m2)

            $name = $m2.Groups['name'].Value
            if (-not $labelTarget.ContainsKey($name)) {
                throw "Undefined label '@$name' referenced at output line $currentLineNumber (source: '$content')."
            }
            return [string]$lineNumbers[$labelTarget[$name]]
        }

        $resolvedTargets = [regex]::Replace($targets, $atTokenPattern, $tokenEvaluator)
        return "$keyword$resolvedTargets"
    }

    try {
        $resolved = [regex]::Replace($content, $labelRefPattern, $refEvaluator)
    }
    catch {
        $inner = $_.Exception
        while ($inner.InnerException) { $inner = $inner.InnerException }
        throw $inner.Message
    }

    if ($resolved -match '(?i)^\s*REM\b') {
        # Normalize a leading REM so removing a label prefix doesn't leave extra spacing.
        $resolved = $resolved.TrimStart()
    }

    if ($resolved -eq '') {
        $resultLines.Add("$currentLineNumber")
    }
    else {
        $resultLines.Add("$currentLineNumber $resolved")
    }
}

$outputText = ($resultLines -join "`r`n") + "`r`n"
Set-Content -LiteralPath $Destination -Value $outputText -Encoding ASCII -NoNewline

Write-Host "Converted '$Source' -> '$Destination' ($($resultLines.Count) lines)."

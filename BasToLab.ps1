<#
.SYNOPSIS
    Converts a numbered "basic" format BASIC source file into a "labels" format file.
.DESCRIPTION
    Reverse of LabToBas.ps1. Every line number that is a jump target (referenced after
    GOTO / GOSUB / THEN / ELSE) gets a generated "@L<number>:" label declaration on its
    own line just before it. Jump targets are rewritten from numbers to "@L<number>"
    references, and all line numbers are then dropped.
.PARAMETER Source
    Path to the input "basic" format file.
.PARAMETER Destination
    Path to the output "labels" format file (overwritten if it already exists).
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

$linePattern = '^(?<num>\d+)(?: (?<rest>.*))?$'
$numbers = New-Object System.Collections.Generic.List[int]
$contents = New-Object System.Collections.Generic.List[string]
$lineIndex = @{}
$entries = New-Object System.Collections.Generic.List[psobject]

for ($i = 0; $i -lt $sourceLines.Count; $i++) {
    $line = $sourceLines[$i]
    if ($line.Trim() -eq '') {
        $entries.Add([pscustomobject]@{ Type = 'Blank' })
        continue
    }

    $match = [regex]::Match($line, $linePattern)
    if (-not $match.Success) {
        throw "Line $($i + 1) does not start with a line number: '$line'."
    }

    $num = [int]$match.Groups['num'].Value
    if ($lineIndex.ContainsKey($num)) {
        throw "Line number $num appears more than once in the source file."
    }

    $lineIndex[$num] = $numbers.Count
    $numbers.Add($num)
    $contents.Add($match.Groups['rest'].Value)
    $entries.Add([pscustomobject]@{ Type = 'Line'; Index = $numbers.Count - 1 })
}

# First pass: find every line number referenced after GOTO / GOSUB / THEN / ELSE / RESTORE.
$jumpRefPattern = '(?i)\b(GOTO|GOSUB|THEN|ELSE|RESTORE)\b((?:\s*,?\s*\d+)+)'
$numTokenPattern = '\d+'

$targets = New-Object System.Collections.Generic.HashSet[int]

foreach ($content in $contents) {
    foreach ($m in [regex]::Matches($content, $jumpRefPattern)) {
        foreach ($m2 in [regex]::Matches($m.Groups[2].Value, $numTokenPattern)) {
            $targets.Add([int]$m2.Value) | Out-Null
        }
    }
}

foreach ($target in $targets) {
    if (-not $lineIndex.ContainsKey($target)) {
        throw "Line number $target is referenced as a jump target but does not exist in the source file."
    }
}

$labelName = @{}
foreach ($target in $targets) {
    $labelName[$target] = "L$target"
}

# Second pass: rewrite jump targets to label references and drop line numbers.
$resultLines = New-Object System.Collections.Generic.List[string]

foreach ($entry in $entries) {
    if ($entry.Type -eq 'Blank') {
        $resultLines.Add('REM')
        continue
    }

    $num = $numbers[$entry.Index]
    $content = $contents[$entry.Index]

    $refEvaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)

        $keyword = $m.Groups[1].Value
        $targetList = $m.Groups[2].Value

        $tokenEvaluator = [System.Text.RegularExpressions.MatchEvaluator]{
            param($m2)
            return "@$($labelName[[int]$m2.Value])"
        }

        $resolvedTargets = [regex]::Replace($targetList, $numTokenPattern, $tokenEvaluator)
        return "$keyword$resolvedTargets"
    }

    $resolved = [regex]::Replace($content, $jumpRefPattern, $refEvaluator)

    if ($labelName.ContainsKey($num)) {
        $resultLines.Add("@$($labelName[$num]):")
    }
    $resultLines.Add($resolved)
}

$outputText = ($resultLines -join "`r`n") + "`r`n"
Set-Content -LiteralPath $Destination -Value $outputText -Encoding ASCII -NoNewline

Write-Host "Converted '$Source' -> '$Destination' ($($resultLines.Count) lines)."

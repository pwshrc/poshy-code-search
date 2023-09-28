#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


<#
.SYNOPSIS
    Searches for function definitions in PowerShell files.
.PARAMETER Path
    The path to search in. Defaults to the current directory.
.PARAMETER Name
    The name that any returned functions must match exactly.
.PARAMETER NameLike
    The name that any returned functions must match using wildcard matching.
.PARAMETER NameMatch
    The name that any returned functions must match using regular expression matching.
.PARAMETER First
    The number of functions to return from the beginning of the list.
.PARAMETER Last
    The number of functions to return from the end of the list.
.PARAMETER Skip
    The number of functions to skip from the beginning of the list.
.PARAMETER SkipLast
    The number of functions to skip from the end of the list.
.EXAMPLE
    Get-PwshFunctionDefinition -Path ~/ -Name prompt
#>
function Get-PwshFunctionDefinition {
    [CmdletBinding(DefaultParameterSetName = "ByName")]
    param(
        [Parameter(Mandatory=$false)]
        [string[]] $Path = @($pwd),

        [Parameter(Mandatory=$false, ParameterSetName = "ByName")]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory=$true, ParameterSetName = "ByNameLike")]
        [ValidateNotNullOrEmpty()]
        [string] $NameLike,

        [Parameter(Mandatory=$true, ParameterSetName = "ByNameMatch")]
        [ValidateNotNullOrEmpty()]
        [string] $NameMatch,

        [Parameter(Mandatory=$false)]
        [ValidateRange(1, [int]::MaxValue)]
        [Nullable[int]] $First,

        [Parameter(Mandatory=$false)]
        [ValidateRange(1, [int]::MaxValue)]
        [Nullable[int]] $Last,

        [Parameter(Mandatory=$false)]
        [ValidateRange(0, [int]::MaxValue)]
        [Nullable[int]] $Skip,

        [Parameter(Mandatory=$false)]
        [ValidateRange(0, [int]::MaxValue)]
        [Nullable[int]] $SkipLast
    )
    # Outputs: Name, FilePath, & LineNumber.
    # Functions may be defined redudantly in multiple files, possibly with conflicting definitions, so we need to check all of them.

    # At the end, we use Select-Object to filter our output.
    # So we go ahead and prepare the parameters for that.
    [hashtable] $selectObjectPagingParameters = @{}
    if ($First) {
        $selectObjectPagingParameters["First"] = $First.Value
    }
    if ($Last) {
        $selectObjectPagingParameters["Last"] = $Last.Value
    }
    if ($Skip) {
        $selectObjectPagingParameters["Skip"] = $Skip.Value
    }
    if ($SkipLast) {
        $selectObjectPagingParameters["SkipLast"] = $SkipLast.Value
    }

    [System.IO.FileInfo[]] $files = Get-ChildItem -Path $Path -Filter *.ps* -Recurse -File
    [hashtable] $resolvedPaths = @{}

    return (
        $files `
        | Select-String -AllMatches -Pattern "(^\s*)function\s+(?<Name>[^\s({]+)" `
        | ForEach-Object {
            [PSCustomObject]@{
                "Name"       = $_.Matches.Groups[2].Value;
                "FilePath"   = $_.Path;
                "LineNumber" = $_.LineNumber;
                "DeclarationContext" = $_.ToEmphasizedString($PWD);
            }
        } `
        | ForEach-Object {
            # Make the paths relative, so that the output is more readable.
            if (-not $resolvedPaths.ContainsKey($_.FilePath)) {
                $resolvedPaths[$_.FilePath] = Resolve-Path -Path $_.FilePath -Relative
            }
            $_.FilePath = $resolvedPaths[$_.FilePath]
            $_
        } `
        | Where-Object {
            if ($Name) {
                $_.Name -eq $Name
            } elseif ($NameLike) {
                $_.Name -like $NameLike
            } elseif ($NameMatch) {
                $_.Name -match $NameMatch
            } else {
                $true
            }
        } `
        | Select-Object @selectObjectPagingParameters
    )
}

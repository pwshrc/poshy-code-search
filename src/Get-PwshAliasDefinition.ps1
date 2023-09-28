#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

<#
.SYNOPSIS
    Searches for alias definitions in PowerShell files.
.PARAMETER Path
    The path to search in. Defaults to the current directory.
.PARAMETER Name
    The name that any returned aliases must match exactly.
.PARAMETER NameLike
    The name that any returned aliases must match using wildcard matching.
.PARAMETER NameMatch
    The name that any returned aliases must match using regular expression matching.
.PARAMETER First
    The number of aliases to return from the beginning of the list.
.PARAMETER Last
    The number of aliases to return from the end of the list.
.PARAMETER Skip
    The number of aliases to skip from the beginning of the list.
.PARAMETER SkipLast
    The number of aliases to skip from the end of the list.
.EXAMPLE
    Get-PwshAliasDefinition -Path ~/ -Name z
#>
function Get-PwshAliasDefinition {
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
    # Outputs: Name, Value, FilePath, LineNumber, & Active.
    # ("Active" is a boolean indicating whether Get-Alias for that name returns the same value or not.)
    # Aliases may be defined redudantly in multiple files, possibly with conflicting values, so we need to check all of them.

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
        | Select-String -AllMatches -Pattern "^\s*Set-Alias\s+(.+?)(#.*$|$|;.*$)"
        | ForEach-Object {
            # The match is the whole parameter set, not even split up yet.
            # Now, we need to split up and try to "parse" it.
            # We can't assume that all the parameters are present, so we need to be careful.

            [string[]] $aliasCommandParameters = ($_.Matches[0].Groups[1].Value.Trim()) -split "\s+"
            [string] $aliasName = $null
            [string] $aliasValue = $null
            for ($i = 0; $i -lt $aliasCommandParameters.Length; $i++) {
                [string] $parameter = $aliasCommandParameters[$i]
                if ($parameter -eq "-Name") {
                    $aliasName = $aliasCommandParameters[$i + 1]
                    $i++
                } elseif ($parameter -eq "-Value") {
                    $aliasValue = $aliasCommandParameters[$i + 1]
                    $i++
                } elseif ($parameter -in @("-Option", "-Description")) {
                    # We don't care about these values.
                    $i++
                } elseif ($parameter -in @("-Force", "-PassThru")) {
                    # We don't care about these switches either.
                } elseif (-not $parameter.StartsWith("-")) {
                    if (-not $aliasName) {
                        $aliasName = $parameter
                    } elseif (-not $aliasValue) {
                        $aliasValue = $parameter
                    } else {
                        throw "Unexpected parameter '$parameter' in alias definition at line $($_.LineNumber) of $($_.Path)."
                    }
                } else {
                    throw "Unexpected parameter '$parameter' in alias definition at line $($_.LineNumber) of $($_.Path)."
                }
                if ($aliasName -and $aliasValue)
                {
                    break
                }
            }

            [PSCustomObject]@{
                "Name"       = $aliasName;
                "Value"      = $aliasValue;
                "FilePath"   = $_.Path;
                "LineNumber" = $_.LineNumber;
                "DeclarationContext" = $_.ToEmphasizedString($PWD);
            }
        } `
        | ForEach-Object {
            # Remove quotes from the Name and the Value.
            $_.Name = $_.Name.Trim("`"")
            $_.Value = $_.Value.Trim("`"")

            # Make the paths relative, so that the output is more readable.
            if (-not $resolvedPaths.ContainsKey($_.FilePath)) {
                $resolvedPaths[$_.FilePath] = Resolve-Path -Path $_.FilePath -Relative
            }
            $_.FilePath = $resolvedPaths[$_.FilePath]

            $nameMatchedExtantAlias = Get-Alias -Name $_.Name -ErrorAction SilentlyContinue

            [bool] $isActive = ($nameMatchedExtantAlias -and $nameMatchedExtantAlias.Definition -eq $_.Value)
            [bool] $nameIsDynamic = ($_.Name -like "*`$*")
            [bool] $valueIsDynamic = ($_.Value -like "*`$*")

            # Add the properties to the pipeline object.
            $_ `
            | Add-Member -MemberType NoteProperty -Name IsActive -Value $isActive -PassThru `
            | Add-Member -MemberType NoteProperty -Name NameIsDynamic -Value $nameIsDynamic -PassThru `
            | Add-Member -MemberType NoteProperty -Name ValueIsDynamic -Value $valueIsDynamic -PassThru
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

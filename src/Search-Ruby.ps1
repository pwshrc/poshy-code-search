#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


<#
.SYNOPSIS
    Searches for Ruby code in Ruby files.
.PARAMETER Path
    The path to search in. Defaults to the current directory.
.PARAMETER Pattern
    The pattern to search for.
#>
function Search-Ruby {
    param(
        [Parameter(Mandatory=$false)]
        [string[]] $Path = @($pwd),

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Pattern
    )
    Get-ChildItem -Path $Path -Filter *.rb -Recurse -File | ForEach-Object {
        Get-Content $_.FullName | Select-String -Pattern $Pattern | ForEach-Object {
            [PSCustomObject]@{
                File = $_.Path
                Line = $_.LineNumber
                Text = $_.Line
            }
        }
    }
}

#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


# Find ruby file
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

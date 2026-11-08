<#
.SYNOPSIS
    The second of the two scripts for the Windows install guide at
    https://archive.rottenth.cafe/system/windows/: the developer environment, once the computer
    is online.

.DESCRIPTION
    Runs with your own rights: open a normal terminal, there is no need for Run as
    administrator. Lists every change in online\, asks once, then applies them. It needs the
    internet.

.PARAMETER Yes
    Apply without asking.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\2-Online.ps1
#>
#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Yes)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib\Helpers.ps1')

$failed = Invoke-SetupScript -Title 'Windows setup: after going online (needs the internet)' -Folder (Join-Path $PSScriptRoot 'online') -Yes:$Yes
if ($failed -lt 0) { exit 0 }

Write-Host 'Open a new terminal to use the tools.'
exit $failed

<#
.SYNOPSIS
    The first of the two scripts for the Windows install guide at
    https://archive.rottenth.cafe/system/windows/: the settings and WinUtil tweaks, before the
    computer goes online.

.DESCRIPTION
    Needs administrator rights, and stops without changing anything when it doesn't have them.
    Lists every change in offline\, asks once, then applies them. Turning off UAC comes first;
    it and some other changes take effect after a restart.

    Nothing is backed up and there is no undo.

.PARAMETER Yes
    Apply without asking.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\1-Offline.ps1
#>
#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Yes)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib\Helpers.ps1')

if (-not (Test-IsAdmin)) {
    Write-Host '1-Offline.ps1 needs administrator rights. Open Terminal (Admin) from the Win+X menu, go to this folder and run it again.' -ForegroundColor Yellow
    exit 1
}

$failed = Invoke-SetupScript -Title 'Windows setup: before going online' -Folder (Join-Path $PSScriptRoot 'offline') -Yes:$Yes
if ($failed -lt 0) { exit 0 }

Write-Host 'Restart Windows now: turning off UAC and some other changes take effect after a restart.'
exit $failed

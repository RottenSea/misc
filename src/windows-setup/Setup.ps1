<#
.SYNOPSIS
    Applies the Windows 11 settings from the Windows install guide at
    https://archive.rottenth.cafe/system/windows/.

.DESCRIPTION
    Lists every change it is about to make, asks once, then applies them. The changes are
    grouped; the files in items\ define each group and its changes. Changes that need
    administrator rights run in one elevated PowerShell window, the rest run as you.

    Nothing is backed up and there is no undo.

.PARAMETER Dev
    Also set up the developer environment, without asking.

.PARAMETER Yes
    Apply without asking. The developer environment is left out unless -Dev is given.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Setup.ps1
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Dev,
    [switch]$Yes,
    # Used when the script starts itself elevated: the ids of the changes to apply.
    [string[]]$Only,
    [switch]$Elevated
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib\Helpers.ps1')
Get-ChildItem (Join-Path $PSScriptRoot 'items') -Filter '*.ps1' |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }

if ($Elevated) {
    # -File passes "a,b,c" as one string.
    $ids = $Only -split ','
    $failed = Invoke-SetupItems ($script:SetupItems | Where-Object { $ids -contains $_.Id })
    if ($failed) { Read-Host 'Some changes failed. Press Enter to close this window' | Out-Null }
    exit $failed
}

$groups = @($script:SetupGroups | Where-Object { $_.Default -or ($Dev -and $_.Id -eq 'dev') })

Write-Host ''
Write-Host 'Windows setup' -ForegroundColor Cyan
Write-Host ''
foreach ($group in $script:SetupGroups) {
    $chosen = $groups -contains $group
    $mark = if ($chosen) { '[x]' } else { '[ ]' }
    Write-Host ("{0} {1}" -f $mark, $group.Title) -ForegroundColor $(if ($chosen) { 'White' } else { 'DarkGray' })
    foreach ($item in $script:SetupItems | Where-Object Group -eq $group.Id) {
        $admin = if ($item.Admin) { ' (admin)' } else { '' }
        Write-Host ("      {0}{1}" -f $item.Title, $admin) -ForegroundColor $(if ($chosen) { 'Gray' } else { 'DarkGray' })
    }
    Write-Host ''
}

if (-not $Yes) {
    foreach ($group in $script:SetupGroups | Where-Object { $groups -notcontains $_ }) {
        $answer = Read-Host ("Also apply '{0}'? [y/N]" -f $group.Title)
        if ($answer -match '^(y|yes)$') { $groups += $group }
    }
    $count = @($script:SetupItems | Where-Object { $groups.Id -contains $_.Group }).Count
    $answer = Read-Host ("Apply these {0} changes? [Y/n]" -f $count)
    if ($answer -match '^(n|no)$') {
        Write-Host 'Nothing changed.'
        exit 0
    }
}

$selected = @($script:SetupItems | Where-Object { $groups.Id -contains $_.Group })
$adminItems = @($selected | Where-Object Admin)
$userItems = @($selected | Where-Object { -not $_.Admin })
$failed = 0

if ($adminItems.Count -gt 0) {
    if (Test-IsAdmin) {
        $failed += Invoke-SetupItems $adminItems
    } else {
        Write-Host 'Starting an administrator window for the changes that need it...' -ForegroundColor Cyan
        $arguments = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $PSCommandPath),
            '-Elevated', '-Only', ($adminItems.Id -join ',')
        )
        try {
            $process = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList $arguments
            $failed += $process.ExitCode
        } catch {
            Write-Warning 'The administrator window was cancelled, so those changes were skipped.'
            $failed += $adminItems.Count
        }
    }
}

$failed += Invoke-SetupItems $userItems

if ($selected | Where-Object RestartExplorer) {
    Restart-Explorer
}

Write-Host ''
if ($failed) {
    Write-Host ("Done, with {0} failed change(s). See the messages above." -f $failed) -ForegroundColor Yellow
} else {
    Write-Host 'Done.' -ForegroundColor Green
}
Write-Host 'Sign out or restart for every change to take effect.'

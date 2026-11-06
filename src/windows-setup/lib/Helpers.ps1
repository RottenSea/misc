# Shared by Setup.ps1 and the files in items\.

$script:SetupGroups = @()
$script:SetupItems = @()

# A group of changes. The groups marked -Default are applied unless you say no; Setup.ps1 asks
# about the others. Keep each call on one line: the misc site reads the title and description
# from it.
function Register-SetupGroup {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Description,
        [switch]$Default
    )
    $script:SetupGroups += [pscustomobject]@{
        Id = $Id; Title = $Title; Description = $Description; Default = [bool]$Default
    }
}

# One change. -Admin runs it in the elevated window; -RestartExplorer restarts Explorer once
# everything is done, so the taskbar and File Explorer pick it up. Keep everything before
# -Action on one line, as with Register-SetupGroup.
function Register-SetupItem {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Group,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Description,
        [switch]$Admin,
        [switch]$RestartExplorer,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    $script:SetupItems += [pscustomobject]@{
        Id = $Id; Group = $Group; Title = $Title; Description = $Description
        Admin = [bool]$Admin; RestartExplorer = [bool]$RestartExplorer; Action = $Action
    }
}

# Runs the changes in order and returns how many failed. A failed change doesn't stop the rest.
function Invoke-SetupItems {
    param([object[]]$Items)
    $failed = 0
    foreach ($item in $Items) {
        Write-Host ("- {0}" -f $item.Title)
        try {
            & $item.Action
        } catch {
            $failed++
            Write-Warning ("  Failed: {0}" -f $_.Exception.Message)
        }
    }
    return $failed
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Creates the key when it's missing.
function Set-RegistryValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()]$Value,
        [ValidateSet('DWord', 'QWord', 'String', 'ExpandString')][string]$Type = 'DWord'
    )
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Remove-RegistryValue {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    if (Test-Path $Path) {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    }
}

# Skips services this edition of Windows doesn't have.
function Set-ServiceStartup {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Automatic', 'Manual', 'Disabled')][string]$StartupType
    )
    if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
        Set-Service -Name $Name -StartupType $StartupType
    }
}

# Removes an app package for every user, and stops it being installed for new users.
function Remove-SetupAppPackage {
    param([Parameter(Mandatory)][string]$Name)
    Get-AppxPackage -AllUsers -Name $Name | Remove-AppxPackage -AllUsers -ErrorAction Continue
    Get-AppxProvisionedPackage -Online |
        Where-Object DisplayName -like $Name |
        Remove-AppxProvisionedPackage -Online -ErrorAction Continue | Out-Null
}

function Restart-Explorer {
    Write-Host 'Restarting Explorer...'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

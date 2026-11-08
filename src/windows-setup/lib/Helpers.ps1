# Shared by 1-Offline.ps1, 2-Online.ps1 and the files in offline\ and online\.

$script:SetupItems = @()

# One change. -RestartExplorer restarts Explorer once everything is done, so the taskbar and File
# Explorer pick it up. Keep everything before -Action on one line: the misc site reads the title
# and description from it.
function Register-SetupItem {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Description,
        [switch]$RestartExplorer,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    $script:SetupItems += [pscustomobject]@{
        Id = $Id; Title = $Title; Description = $Description
        RestartExplorer = [bool]$RestartExplorer; Action = $Action
    }
}

# Loads the changes in $Folder, lists them, asks once unless -Yes, then applies them in order. A
# failed change doesn't stop the rest. Returns how many failed, or -1 when you said no.
function Invoke-SetupScript {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Folder,
        [switch]$Yes
    )
    Get-ChildItem $Folder -Filter '*.ps1' |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }

    Write-Host ''
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ''
    foreach ($item in $script:SetupItems) { Write-Host ("  {0}" -f $item.Title) }
    Write-Host ''

    if (-not $Yes) {
        $answer = Read-Host ("Apply these {0} changes? [Y/n]" -f $script:SetupItems.Count)
        if ($answer -match '^(n|no)$') {
            Write-Host 'Nothing changed.'
            return -1
        }
    }

    $failed = 0
    foreach ($item in $script:SetupItems) {
        Write-Host ("- {0}" -f $item.Title)
        try {
            # To the screen, so the only thing this function returns is the count.
            & $item.Action | Out-Host
        } catch {
            $failed++
            Write-Warning ("  Failed: {0}" -f $_.Exception.Message)
        }
    }
    if ($script:SetupItems | Where-Object RestartExplorer) { Restart-Explorer }

    Write-Host ''
    if ($failed) {
        Write-Host ("Done, with {0} failed change(s). See the messages above." -f $failed) -ForegroundColor Yellow
    } else {
        Write-Host 'Done.' -ForegroundColor Green
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

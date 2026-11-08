# The tweaks the guide picks from Chris Titus Tech's Windows Utility (WinUtil), written out here
# so that WinUtil itself never runs. Each change follows WinUtil's own implementation in
# config/tweaks.json at https://github.com/ChrisTitusTech/winutil (MIT license, see
# THIRD-PARTY-NOTICES.txt).

Register-SetupGroup -Id 'optimizations' -Title 'System optimizations' -Description 'The WinUtil tweaks the guide recommends: less telemetry, fewer ads and suggestions, fewer background services.' -Default

Register-SetupItem -Id 'consumer-features' -Group 'optimizations' -Title 'Turn off consumer features' -Description 'Windows stops installing promoted apps and suggesting Store content.' -Admin -Action {
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
}

Register-SetupItem -Id 'telemetry' -Group 'optimizations' -Title 'Turn off telemetry' -Description 'Turns off diagnostic data, the advertising ID, tailored experiences, inking and typing personalisation, activity publishing and feedback prompts; disables the Connected User Experiences and Windows Error Reporting services; stops Defender sending samples automatically and PowerShell 7 sending usage data.' -Admin -Action {
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
    Set-RegistryValue 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 0
    Set-RegistryValue 'HKCU:\Software\Microsoft\Input\TIPC' 'Enabled' 0
    Set-RegistryValue 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 1
    Set-RegistryValue 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1
    Set-RegistryValue 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 0
    Set-RegistryValue 'HKCU:\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackProgs' 0
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
    Set-RegistryValue 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
    Remove-RegistryValue 'HKCU:\Software\Microsoft\Siuf\Rules' 'PeriodInNanoSeconds'
    Set-ServiceStartup 'DiagTrack' 'Disabled'
    Set-ServiceStartup 'WerSvc' 'Disabled'
    try {
        Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction Stop
    } catch {
        Write-Warning '  Defender sample submission was left as it is: Defender may be off or replaced by another antivirus.'
    }
    [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')
}

Register-SetupItem -Id 'services' -Group 'optimizations' -Title 'Set some services to manual or disabled' -Description 'Offline Files, Connected User Experiences and Internet Connection Sharing are disabled; Downloaded Maps Manager and Storage Service start only when needed.' -Admin -Action {
    Set-ServiceStartup 'CscService' 'Disabled'
    Set-ServiceStartup 'DiagTrack' 'Disabled'
    Set-ServiceStartup 'MapsBroker' 'Manual'
    Set-ServiceStartup 'StorSvc' 'Manual'
    Set-ServiceStartup 'SharedAccess' 'Disabled'
}

Register-SetupItem -Id 'widgets' -Group 'optimizations' -Title 'Remove Widgets' -Description 'Uninstalls the Widgets board (Win+W) and its runtime for every user.' -Admin -RestartExplorer -Action {
    # Removal can fail while the widgets are running.
    Get-Process -Name '*Widget*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Remove-SetupAppPackage 'Microsoft.WidgetsPlatformRuntime'
    Remove-SetupAppPackage 'MicrosoftWindows.Client.WebExperience'
}

Register-SetupItem -Id 'windows-ai' -Group 'optimizations' -Title 'Turn off Windows AI features' -Description 'Removes Copilot and the Microsoft 365 app, turns off Recall and the AI features in Notepad, and hides the AI components page in Settings.' -Admin -Action {
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'SettingsPageVisibility' 'hide:aicomponents' 'String'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\WindowsNotepad' 'DisableAIFeatures' 1
    Remove-SetupAppPackage '*Copilot*'
    Remove-SetupAppPackage 'Microsoft.MicrosoftOfficeHub'

    # CoreAI is a system package: marking it end-of-life for this user lets it be removed.
    $coreAi = (Get-AppxPackage -Name 'MicrosoftWindows.Client.CoreAI').PackageFullName
    if ($coreAi) {
        $sid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
        New-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\EndOfLife\$sid\$coreAi" -Force | Out-Null
        Remove-AppxPackage $coreAi -ErrorAction Continue
    }

    Set-ServiceStartup 'WSAIFabricSvc' 'Disabled'
    if (Get-WindowsOptionalFeature -Online -FeatureName 'Recall' -ErrorAction SilentlyContinue) {
        Disable-WindowsOptionalFeature -Online -FeatureName 'Recall' -NoRestart | Out-Null
    }
}

Register-SetupItem -Id 'edge-policies' -Group 'optimizations' -Title 'Quiet Microsoft Edge' -Description 'Edge policies that turn off its first-run screens, recommendations, shopping, rewards and wallet prompts, collections, feedback and diagnostic data, and stop it adding a desktop shortcut on updates. Edge stays installed.' -Admin -Action {
    $edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' 'CreateDesktopShortcutDefault' 0
    Set-RegistryValue "$edge\ExtensionInstallBlocklist" '1' 'ofefcgjbeghpigppfmkologfjadafddi' 'String'
    $policies = [ordered]@{
        PersonalizationReportingEnabled = 0; ShowRecommendationsEnabled = 0; HideFirstRunExperience = 1
        UserFeedbackAllowed = 0; ConfigureDoNotTrack = 1; AlternateErrorPagesEnabled = 0
        EdgeCollectionsEnabled = 0; EdgeShoppingAssistantEnabled = 0; MicrosoftEdgeInsiderPromotionEnabled = 0
        ShowMicrosoftRewards = 0; WebWidgetAllowed = 0; DiagnosticData = 0
        EdgeAssetDeliveryServiceEnabled = 0; WalletDonationEnabled = 0; DefaultBrowserSettingsCampaignEnabled = 0
    }
    foreach ($name in $policies.Keys) { Set-RegistryValue $edge $name $policies[$name] }
}

Register-SetupItem -Id 'store-search' -Group 'optimizations' -Title 'No Store suggestions in Start search' -Description 'Searching for an app in Start no longer suggests apps from the Microsoft Store.' -Action {
    $database = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
    if (-not (Test-Path $database)) {
        Write-Host '  The Store has not made its database yet. Open the Store once, then run this again.'
        return
    }
    icacls $database /deny '*S-1-1-0:F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'icacls could not change the permissions of store.db.' }
}

Register-SetupItem -Id 'folder-discovery' -Group 'optimizations' -Title 'Stop File Explorer guessing folder types' -Description 'Every folder opens with the general view instead of one guessed from its contents, which is slow on large folders. Clears the views you saved for folders, and turns off grouping in them.' -RestartExplorer -Action {
    $shell = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell'
    Remove-Item "$shell\Bags" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$shell\BagMRU" -Recurse -Force -ErrorAction SilentlyContinue
    Set-RegistryValue "$shell\Bags\AllFolders\Shell" 'FolderType' 'NotSpecified' 'String'
}

Register-SetupItem -Id 'classic-context-menu' -Group 'optimizations' -Title 'Use the full right-click menu' -Description 'File Explorer shows the Windows 10 style right-click menu with every entry, without Show more options.' -RestartExplorer -Action {
    $server = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
    if (-not (Test-Path $server)) { New-Item -Path $server -Force | Out-Null }
    Set-Item -Path $server -Value ''
}

Register-SetupItem -Id 'teredo' -Group 'optimizations' -Title 'Turn off Teredo' -Description 'Turns off the Teredo IPv6 tunnel, which can add latency. Some online games use it.' -Admin -Action {
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents' 1
    netsh interface teredo set state disabled | Out-Null
}

Register-SetupItem -Id 'start-recommended' -Group 'optimizations' -Title 'Hide the Recommended section in Start' -Description 'Removes the whole Recommended section from Start. Windows only allows this in education editions, so it also tells Windows it is in an education environment, which turns off Spotlight on the lock screen too.' -Admin -RestartExplorer -Action {
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start' 'HideRecommendedSection' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Education' 'IsEducationEnvironment' 1
    Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'HideRecommendedSection' 1
}

Register-SetupItem -Id 'bing-search' -Group 'optimizations' -Title 'No Bing results in Search' -Description 'Windows Search only searches this computer.' -Action {
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
}

Register-SetupItem -Id 'file-extensions' -Group 'optimizations' -Title 'Show file extensions' -Description 'File Explorer shows extensions such as .txt and .exe.' -RestartExplorer -Action {
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0
}

Register-SetupItem -Id 'hidden-files' -Group 'optimizations' -Title 'Show hidden files' -Description 'File Explorer shows hidden files and folders.' -RestartExplorer -Action {
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden' 1
}

Register-SetupItem -Id 'settings-home' -Group 'optimizations' -Title 'Hide the Settings home page' -Description 'Settings opens on System instead of the Home page with its suggestions.' -Action {
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'SettingsPageVisibility' 'hide:home' 'String'
}

Register-SetupItem -Id 'verbose-status' -Group 'optimizations' -Title 'Show detailed sign-in and shutdown messages' -Description 'The screens shown while signing in, signing out and shutting down say what Windows is doing.' -Admin -Action {
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'VerboseStatus' 1
}

Register-SetupItem -Id 'classic-outlook' -Group 'optimizations' -Title 'Keep classic Outlook' -Description 'Classic Outlook stays, without the switch to the new Outlook or the automatic move to it.' -Action {
    Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Preferences' 'UseNewOutlook' 0
    Set-RegistryValue 'HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General' 'HideNewOutlookToggle' 1
    Set-RegistryValue 'HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Options\General' 'DoNewOutlookAutoMigration' 0
    Remove-RegistryValue 'HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Preferences' 'NewOutlookMigrationUserSetting'
}

Register-SetupItem -Id 'standby-network' -Group 'optimizations' -Title 'Stay connected in Modern Standby' -Description 'On laptops with Modern Standby (S0 sleep), the network stays connected during sleep while plugged in.' -Action {
    Set-RegistryValue 'HKCU:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9' 'ACSettingIndex' 1
}

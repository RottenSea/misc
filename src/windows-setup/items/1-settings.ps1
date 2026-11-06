# The settings the guide changes in the Settings app, done through the registry instead.

Register-SetupGroup -Id 'settings' -Title 'Settings from the guide' -Description 'What the guide sets by hand in the Settings app, wherever a registry value or a command does the same.' -Default

Register-SetupItem -Id 'mouse-acceleration' -Group 'settings' -Title 'Turn off mouse acceleration' -Description 'The pointer moves as far as the mouse does, however fast you move it (Enhance pointer precision off). Applies after you sign in again.' -Action {
    $mouse = 'HKCU:\Control Panel\Mouse'
    Set-RegistryValue $mouse 'MouseSpeed' '0' 'String'
    Set-RegistryValue $mouse 'MouseThreshold1' '0' 'String'
    Set-RegistryValue $mouse 'MouseThreshold2' '0' 'String'
}

Register-SetupItem -Id 'account-search' -Group 'settings' -Title 'Keep Search off your online accounts' -Description 'Windows Search stops showing results from your Microsoft account and work or school account.' -Action {
    $search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'
    Set-RegistryValue $search 'IsMSACloudSearchEnabled' 0
    Set-RegistryValue $search 'IsAADCloudSearchEnabled' 0
}

Register-SetupItem -Id 'lock-screen' -Group 'settings' -Title 'No Spotlight or tips on the lock screen' -Description 'Turns off Windows Spotlight and the fun facts and tips on the lock screen, which then shows a picture.' -Action {
    $content = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    Set-RegistryValue $content 'RotatingLockScreenEnabled' 0
    Set-RegistryValue $content 'RotatingLockScreenOverlayEnabled' 0
    Set-RegistryValue $content 'SubscribedContent-338387Enabled' 0
}

Register-SetupItem -Id 'start-suggestions' -Group 'settings' -Title 'No recommendations in Start' -Description 'Start stops showing recommended files, tips and new apps, and notifications about your account.' -RestartExplorer -Action {
    $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-RegistryValue $advanced 'Start_TrackDocs' 0
    Set-RegistryValue $advanced 'Start_IrisRecommendations' 0
    Set-RegistryValue $advanced 'Start_AccountNotifications' 0
}

Register-SetupItem -Id 'taskbar-buttons' -Group 'settings' -Title 'Search icon only, no Task View button' -Description 'Search on the taskbar becomes an icon instead of a box, and the Task View button goes.' -RestartExplorer -Action {
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowTaskViewButton' 0
}

Register-SetupItem -Id 'dynamic-lighting' -Group 'settings' -Title 'Turn off Dynamic Lighting' -Description 'Windows stops controlling RGB lighting on your devices, and apps in the foreground no longer take it over.' -Action {
    $lighting = 'HKCU:\Software\Microsoft\Lighting'
    Set-RegistryValue $lighting 'AmbientLightingEnabled' 0
    Set-RegistryValue $lighting 'ControlledByForegroundApp' 0
}

Register-SetupItem -Id 'end-task' -Group 'settings' -Title 'End task from the taskbar' -Description 'Right-clicking an app on the taskbar offers End task, without opening Task Manager.' -RestartExplorer -Action {
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' 1
}

Register-SetupItem -Id 'long-paths' -Group 'settings' -Title 'Allow long paths' -Description 'Lifts the 260-character limit on file paths for apps that support longer ones.' -Admin -Action {
    Set-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1
}

Register-SetupItem -Id 'script-policy' -Group 'settings' -Title 'Let local PowerShell scripts run' -Description 'Sets the execution policy to RemoteSigned: scripts written on this computer run without a signature, downloaded ones still need one.' -Admin -Action {
    # Inside a Bypass session, Set-ExecutionPolicy saves the policy but reports that the session
    # overrides it, so check what was saved instead of trusting the error.
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction SilentlyContinue
    if ((Get-ExecutionPolicy -Scope LocalMachine) -ne 'RemoteSigned') {
        throw 'The execution policy could not be set.'
    }
}

Register-SetupItem -Id 'developer-mode' -Group 'settings' -Title 'Turn on Developer Mode' -Description 'Apps can be installed from any source, including loose files.' -Admin -Action {
    Set-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' 'AllowDevelopmentWithoutDevLicense' 1
}

Register-SetupItem -Id 'game-mode' -Group 'settings' -Title 'Turn off Game Mode' -Description 'Windows stops giving games priority over everything else that is running.' -Action {
    $gameBar = 'HKCU:\Software\Microsoft\GameBar'
    Set-RegistryValue $gameBar 'AutoGameModeEnabled' 0
    Set-RegistryValue $gameBar 'AllowAutoGameMode' 0
}

Register-SetupItem -Id 'accessibility-shortcuts' -Group 'settings' -Title 'Turn off accessibility shortcuts that are easy to hit' -Description 'The keyboard shortcuts for Sticky Keys (Shift five times), Filter Keys, contrast themes and Narrator stop working. The features themselves stay available in Settings.' -Action {
    $accessibility = 'HKCU:\Control Panel\Accessibility'
    Set-RegistryValue "$accessibility\StickyKeys" 'Flags' '506' 'String'
    Set-RegistryValue "$accessibility\Keyboard Response" 'Flags' '122' 'String'
    Set-RegistryValue "$accessibility\HighContrast" 'Flags' '122' 'String'
    Set-RegistryValue 'HKCU:\Software\Microsoft\Narrator\NoRoam' 'WinEnterLaunchEnabled' 0
}

Register-SetupItem -Id 'transparency' -Group 'settings' -Title 'Turn off transparency effects' -Description 'Windows, the taskbar and Start become opaque.' -Action {
    Set-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
}

Register-SetupItem -Id 'scrollbars' -Group 'settings' -Title 'Always show scroll bars' -Description 'Scroll bars stay visible instead of hiding when you are not scrolling.' -Action {
    Set-RegistryValue 'HKCU:\Control Panel\Accessibility' 'DynamicScrollbars' 0
}

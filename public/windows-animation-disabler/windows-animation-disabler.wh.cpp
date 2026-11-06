// ==WindhawkMod==
// @id              windows-animation-disabler
// @name            Windows Animation Disabler
// @description     Disable selected Windows, taskbar and shell animations without touching the system-wide animation switch
// @version         1.0
// @author          RottenSea
// @github          https://github.com/RottenSea
// @include         explorer.exe
// @include         StartMenuExperienceHost.exe
// @include         ShellExperienceHost.exe
// @include         ShellHost.exe
// @include         SearchHost.exe
// @architecture    x86-64
// @compilerOptions -luser32
// @license         MIT
// ==/WindhawkMod==

// ==WindhawkModReadme==
/*
# Windows Animation Disabler

Turns off individual Windows animations and delays without touching the
system-wide animation switch, so ordinary programs such as Chrome, Edge or
Notepad are unaffected.

Every program asks Windows whether it should play animations. This mod only
changes the answer for explorer and a few shell components; everything else
still gets the real one.

## What it can turn off

- Taskbar and Task View animations: opening Task View from the taskbar icon,
  and the taskbar sliding in and out when it auto-hides.
- The popup animation of the window preview shown when hovering a taskbar
  icon.
- The delays: before that preview appears, before the auto-hidden taskbar
  appears and hides, and the hover time in general.
- The transition played when switching virtual desktops with
  Win+Ctrl+Left/Right.
- The popup animations of the Start menu, Search, Quick Settings and
  Notification Center, each on its own.

## Notes

- Everything is on by default, so the mod works as soon as it is enabled.
- Hover delays are removed everywhere as well, which also makes the hover
  preview close as soon as the pointer leaves the taskbar icon. Turn that
  setting off if you want to click the thumbnails inside the preview.
- Changing the Start menu and the other shell flyout switches restarts those
  components, which flickers the screen once.
- Windows 11 only.

## Sources

The techniques here were learned from these Windhawk mods, all MIT licensed:

- [Shell Animation Disabler](https://windhawk.net/mods/shell-animation-disabler)
  by [Lockframe](https://github.com/Lockframe)
- [Disable Virtual Desktop Transition Animation](https://windhawk.net/mods/disable-virtual-desktop-transition)
  by [Isabella Lulamoon (kawapure)](https://github.com/kawapure)
- [Instant Taskbar Thumbnail Previews](https://windhawk.net/mods/instant-taskbar-thumbnail-previews)
  by [Alchemy](https://github.com/alchemyyy)
- [Taskbar Auto-Hide Instant Show](https://windhawk.net/mods/taskbar-autohide-instant-show)
  by [Bo0ii](https://github.com/Bo0ii)
- Windhawk itself and several taskbar mods by [m417z](https://github.com/m417z)
*/
// ==/WindhawkModReadme==

// ==WindhawkModSettings==
/*
- taskbar:
  - disableAnimations: true
    $name: Disable taskbar and Task View animations
    $description: >-
      Turns off the taskbar's own animations: opening Task View from the
      taskbar icon, and the taskbar sliding in and out when it auto-hides.
      Only the explorer process that owns the taskbar is affected.
  - autoHideShowDelayMs: 1
    $name: Auto-hide show delay in milliseconds
    $description: >-
      How long after the pointer reaches the screen edge the auto-hidden
      taskbar starts to appear. Windows uses about 50 ms. 0 leaves it alone.
  - autoHideHideDelayMs: 1
    $name: Auto-hide hide delay in milliseconds
    $description: >-
      How long after the pointer leaves the taskbar it starts to hide.
      Windows uses about 500 ms. 0 leaves it alone.
  $name: Taskbar
  $description: Animations and delays of the taskbar itself.

- hoverPreview:
  - disableAnimation: true
    $name: Disable the hover preview popup animation
    $description: >-
      Whether the window preview of a taskbar icon fades and slides in, or
      simply appears. On means it appears at once.
  - delayMs: 1
    $name: Hover preview delay in milliseconds
    $description: >-
      How long the pointer must rest on a taskbar icon before the preview
      appears. Windows uses about 400 ms; 1 is effectively immediate.
      0 leaves it alone.
  $name: Hover preview
  $description: >-
    The window preview shown when hovering a taskbar icon.

- hoverDelays:
  - disableAll: true
    $name: Remove hover delays everywhere
    $description: >-
      Squeezes the explorer hover time to its minimum. That removes the wait
      before tooltips appear, the wait before the hover preview closes after
      the pointer leaves it, and the wait before the task view switches to a
      hovered desktop. Turning this on also makes the hover preview close the
      instant the pointer leaves the taskbar icon, which makes the thumbnails
      inside it hard to click.
  $name: Hover delays
  $description: >-
    Hover timing in explorer, which several different behaviours share.

- virtualDesktopSwitch:
  - disableAnimation: true
    $name: Disable the virtual desktop switch animation
    $description: >-
      The transition played when switching desktops with
      Win+Ctrl+Left/Right. Only the keyboard shortcut is affected. Clicking a
      desktop thumbnail in Task View keeps Windows' own code path, because
      redirecting that path stops desktops that are not loaded yet from being
      switched to.
  $name: Virtual desktop switching

- shellFlyouts:
  - start: true
    $name: Start menu animation
  - search: true
    $name: Search animation
  - quickSettings: true
    $name: Quick settings animation
  - notificationCenter: true
    $name: Notification center animation
  $name: Shell flyout animations
  $description: >-
    The popup animations of the Start menu, Search, Quick Settings and
    Notification Center, each on its own.

- advanced:
  - restartShellProcesses: true
    $name: Restart the shell components after a change
    $description: >-
      Restarting the Start menu and the other shell components is what makes a
      change to the shell flyout switches take effect. The screen flickers
      once while that happens. Settings outside that group take effect without
      a restart.
  $name: Advanced
*/
// ==/WindhawkModSettings==

#include <windows.h>
#include <windhawk_utils.h>
#include <tlhelp32.h>

#include <atomic>

namespace {

// ===========================================================================
// Settings
// ===========================================================================

struct {
    bool taskbarDisableAnimations;
    int taskbarAutoHideShowDelayMs;
    int taskbarAutoHideHideDelayMs;
    bool hoverPreviewDisableAnimation;
    int hoverPreviewDelayMs;
    bool hoverDelaysDisableAll;
    bool virtualDesktopDisableSwitchAnimation;
    bool shellFlyoutStart;
    bool shellFlyoutSearch;
    bool shellFlyoutQuickSettings;
    bool shellFlyoutNotificationCenter;
    bool restartShellProcesses;
} settings;

// Reads a delay setting. Zero means "leave it to Windows"; anything above zero
// is an override.
int GetDelaySetting(PCWSTR name) {
    int value = Wh_GetIntSetting(name);
    return value > 0 ? value : 0;
}

void LoadSettings() {
    settings.taskbarDisableAnimations =
        Wh_GetIntSetting(L"taskbar.disableAnimations") != 0;
    settings.taskbarAutoHideShowDelayMs =
        GetDelaySetting(L"taskbar.autoHideShowDelayMs");
    settings.taskbarAutoHideHideDelayMs =
        GetDelaySetting(L"taskbar.autoHideHideDelayMs");

    settings.hoverPreviewDisableAnimation =
        Wh_GetIntSetting(L"hoverPreview.disableAnimation") != 0;
    settings.hoverPreviewDelayMs = GetDelaySetting(L"hoverPreview.delayMs");

    settings.hoverDelaysDisableAll =
        Wh_GetIntSetting(L"hoverDelays.disableAll") != 0;

    settings.virtualDesktopDisableSwitchAnimation =
        Wh_GetIntSetting(L"virtualDesktopSwitch.disableAnimation") != 0;

    settings.shellFlyoutStart =
        Wh_GetIntSetting(L"shellFlyouts.start") != 0;
    settings.shellFlyoutSearch =
        Wh_GetIntSetting(L"shellFlyouts.search") != 0;
    settings.shellFlyoutQuickSettings =
        Wh_GetIntSetting(L"shellFlyouts.quickSettings") != 0;
    settings.shellFlyoutNotificationCenter =
        Wh_GetIntSetting(L"shellFlyouts.notificationCenter") != 0;

    settings.restartShellProcesses =
        Wh_GetIntSetting(L"advanced.restartShellProcesses") != 0;
}

// ===========================================================================
// Which process are we in?
// ===========================================================================

enum class ProcKind {
    unknown,
    explorer,
    startMenu,
    searchHost,
    shellHost,
    shellExperience,
};

ProcKind g_procKind = ProcKind::unknown;

bool IsWindows11() {
    static std::atomic<int> cached{-1};

    int value = cached.load(std::memory_order_relaxed);
    if (value < 0) {
        value = 0;

        HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
        if (ntdll) {
            using RtlGetVersion_t = LONG(WINAPI*)(OSVERSIONINFOEXW*);
            auto rtlGetVersion = reinterpret_cast<RtlGetVersion_t>(
                GetProcAddress(ntdll, "RtlGetVersion"));
            if (rtlGetVersion) {
                OSVERSIONINFOEXW version{};
                version.dwOSVersionInfoSize = sizeof(version);
                if (rtlGetVersion(&version) == 0 &&
                    (version.dwMajorVersion > 10 ||
                     (version.dwMajorVersion == 10 &&
                      version.dwBuildNumber >= 22000))) {
                    value = 1;
                }
            }
        }

        cached.store(value, std::memory_order_relaxed);
    }

    return value != 0;
}

ProcKind DetectProcKind() {
    static const struct {
        PCWSTR fileName;
        ProcKind kind;
    } kNames[] = {
        {L"explorer.exe", ProcKind::explorer},
        {L"StartMenuExperienceHost.exe", ProcKind::startMenu},
        {L"SearchHost.exe", ProcKind::searchHost},
        {L"ShellHost.exe", ProcKind::shellHost},
        {L"ShellExperienceHost.exe", ProcKind::shellExperience},
    };

    WCHAR path[MAX_PATH];
    if (!GetModuleFileNameW(nullptr, path, MAX_PATH)) {
        return ProcKind::unknown;
    }

    PCWSTR fileName = wcsrchr(path, L'\\');
    fileName = fileName ? fileName + 1 : path;

    for (const auto& entry : kNames) {
        if (_wcsicmp(fileName, entry.fileName) == 0) {
            return entry.kind;
        }
    }

    return ProcKind::unknown;
}

// Several explorer.exe processes exist; only the one that owns the desktop and
// the taskbar is of interest, so that folder windows keep their animations.
//
// The answer is not available during early startup, so it is cached lazily and
// stays unknown until it can be told for sure.
bool IsShellProcess() {
    static std::atomic<int> cached{-1};

    int value = cached.load(std::memory_order_relaxed);
    if (value >= 0) {
        return value != 0;
    }

    DWORD ownPid = GetCurrentProcessId();
    bool resolved = false;
    bool result = false;

    HWND desktop = GetShellWindow();
    if (desktop) {
        DWORD pid = 0;
        GetWindowThreadProcessId(desktop, &pid);
        result = (pid == ownPid);
        resolved = true;
    }

    HWND taskbar = FindWindowW(L"Shell_TrayWnd", nullptr);
    if (taskbar) {
        DWORD pid = 0;
        GetWindowThreadProcessId(taskbar, &pid);
        if (pid == ownPid) {
            result = true;
        }
        resolved = true;
    }

    if (resolved) {
        cached.store(result ? 1 : 0, std::memory_order_relaxed);
    }

    return result;
}

// ===========================================================================
// Desktop switching
//
// The switch itself is never redirected. Windows carries a desktop switch out
// through more than one route and they are not equivalent: a switch started
// from Task View goes through the foreground policy, which is what brings a
// not-yet-loaded desktop up, while the plain non-animated switch skips that
// step and the shell then falls back to the current desktop. Redirecting was
// tried and it broke switching from Task View.
//
// So the hotkey handler's own call is marked, and the animation switch is
// answered differently only inside it.
// ===========================================================================

// Non-zero while a hotkey-initiated switch is in progress. Global rather than
// per-thread, because the switch consults the animation switch from other
// threads as well.
std::atomic<int> g_hotkeyCycleDepth{0};

using CycleInDirection_t = long(WINAPI*)(void*, int);
CycleInDirection_t CycleInDirection_Original;

long WINAPI CycleInDirection_Hook(void* self, int direction) {
    g_hotkeyCycleDepth.fetch_add(1, std::memory_order_relaxed);
    long result = CycleInDirection_Original(self, direction);
    g_hotkeyCycleDepth.fetch_sub(1, std::memory_order_relaxed);
    return result;
}

// ===========================================================================
// Reporting animations as switched off
//
// Every process asks Windows whether it should play animations. The answer is
// changed only for the processes that were asked to be silenced; everything
// else still gets the real one.
// ===========================================================================

using SystemParametersInfoW_t = decltype(&SystemParametersInfoW);
SystemParametersInfoW_t SystemParametersInfoW_Original;

// "Effectively now", used wherever a delay is removed.
constexpr UINT kMinimumHoverTimeMs = 1;

// The queries which report whether animations are switched on.
bool IsAnimationQuery(UINT action) {
    return action == SPI_GETANIMATION || action == SPI_GETCLIENTAREAANIMATION;
}

bool ShouldReportAnimationsDisabled() {
    switch (g_procKind) {
        case ProcKind::explorer:
            if (!IsShellProcess()) {
                return false;
            }

            // A switch started from the hotkey is silenced on its own, so that
            // it can be switched off independently of the taskbar.
            return settings.taskbarDisableAnimations ||
                   (settings.virtualDesktopDisableSwitchAnimation &&
                    g_hotkeyCycleDepth.load(std::memory_order_relaxed) > 0);

        case ProcKind::startMenu:
            return settings.shellFlyoutStart;

        case ProcKind::searchHost:
            return settings.shellFlyoutSearch;

        case ProcKind::shellHost:
            return settings.shellFlyoutQuickSettings;

        case ProcKind::shellExperience:
            return settings.shellFlyoutNotificationCenter;

        default:
            return false;
    }
}

BOOL WINAPI SystemParametersInfoW_Hook(UINT action,
                                       UINT param,
                                       PVOID value,
                                       UINT flags) {
    BOOL result = SystemParametersInfoW_Original(action, param, value, flags);

    if (!result || !value) {
        return result;
    }

    // How long the pointer must rest before the shell acts on it. It governs
    // the tooltip popup, how long the taskbar preview stays up after the
    // pointer leaves it, and how long the task view waits before switching to
    // a hovered desktop.
    if (action == SPI_GETMOUSEHOVERTIME) {
        if (settings.hoverDelaysDisableAll &&
            g_procKind == ProcKind::explorer && IsShellProcess()) {
            *static_cast<UINT*>(value) = kMinimumHoverTimeMs;
        }
        return result;
    }

    if (!IsAnimationQuery(action) || !ShouldReportAnimationsDisabled()) {
        return result;
    }

    if (action == SPI_GETANIMATION) {
        auto* info = static_cast<ANIMATIONINFO*>(value);
        if (info->cbSize >= sizeof(ANIMATIONINFO)) {
            info->iMinAnimate = 0;
        }
    } else {
        *static_cast<BOOL*>(value) = FALSE;
    }

    return result;
}

// ===========================================================================
// The hover preview flyout
//
// SharedAnimations owns every animation the taskbar plays. These two start the
// flyout's appearance and disappearance; they only run the animation, while the
// flyout's position, size and visibility are handled by the surrounding code.
// Skipping them therefore makes the flyout appear and disappear at once,
// without changing where it ends up.
// ===========================================================================

// 100-nanosecond ticks.
constexpr LONGLONG kTicksPerMillisecond = 10000LL;

using TransitionToFlyoutVisiblePendingState_t = void(WINAPI*)(void*,
                                                             void*,
                                                             LONGLONG);
TransitionToFlyoutVisiblePendingState_t
    TransitionToFlyoutVisiblePendingState_Original;

void WINAPI TransitionToFlyoutVisiblePendingState_Hook(void* self,
                                                       void* targetItem,
                                                       LONGLONG delayTicks) {
    LONGLONG applied = delayTicks;
    if (delayTicks > 0 && settings.hoverPreviewDelayMs > 0) {
        applied = static_cast<LONGLONG>(settings.hoverPreviewDelayMs) *
                  kTicksPerMillisecond;
    }

    TransitionToFlyoutVisiblePendingState_Original(self, targetItem, applied);
}

using StartFlyoutAnimation_t = void(WINAPI*)(void*, void*);
StartFlyoutAnimation_t StartFlyoutEntranceAnimation_Original;
StartFlyoutAnimation_t StartFlyoutExitAnimation_Original;

void WINAPI StartFlyoutEntranceAnimation_Hook(void* self, void* element) {
    if (settings.hoverPreviewDisableAnimation) {
        return;
    }

    StartFlyoutEntranceAnimation_Original(self, element);
}

void WINAPI StartFlyoutExitAnimation_Hook(void* self, void* element) {
    if (settings.hoverPreviewDisableAnimation) {
        return;
    }

    StartFlyoutExitAnimation_Original(self, element);
}

// The task view is a XAML surface, so it may ask for the hover time through
// this getter rather than through the plain API above. Both paths are covered
// so that either one is enough.
using MouseHoverTime_t = UINT(WINAPI*)(void*);
MouseHoverTime_t MouseHoverTime_Original;

UINT WINAPI MouseHoverTime_Hook(void* self) {
    if (settings.hoverDelaysDisableAll && IsShellProcess()) {
        return kMinimumHoverTimeMs;
    }

    return MouseHoverTime_Original(self);
}

// ===========================================================================
// Taskbar auto-hide delays
//
// The taskbar arms two timers on Shell_TrayWnd: id 2 for hiding, id 3 for
// showing. Replacing the timeout is enough to change both delays.
// ===========================================================================

using SetTimer_t = decltype(&SetTimer);
SetTimer_t SetTimer_Original;

UINT_PTR WINAPI SetTimer_Hook(HWND hWnd,
                              UINT_PTR eventId,
                              UINT elapse,
                              TIMERPROC timerFunc) {
    if (hWnd && (eventId == 2 || eventId == 3) && IsShellProcess()) {
        int configured = (eventId == 3) ? settings.taskbarAutoHideShowDelayMs
                                        : settings.taskbarAutoHideHideDelayMs;

        WCHAR className[64];
        if (configured > 0 &&
            GetClassNameW(hWnd, className, ARRAYSIZE(className)) &&
            (_wcsicmp(className, L"Shell_TrayWnd") == 0 ||
             _wcsicmp(className, L"Shell_SecondaryTrayWnd") == 0)) {
            elapse = static_cast<UINT>(configured);
        }
    }

    return SetTimer_Original(hWnd, eventId, elapse, timerFunc);
}

// ===========================================================================
// Modules which load after the mod does
// ===========================================================================

std::atomic<bool> g_taskbarViewHooked{false};
std::atomic<bool> g_twinuiPcshellHooked{false};

bool HookTaskbarViewSymbols(HMODULE module) {
    // Taskbar.View.dll
    //
    // Several spellings of the same symbol are listed because debug symbol
    // names differ slightly between Windows builds; the first one that matches
    // is used.
    WindhawkUtils::SYMBOL_HOOK hooks[] = {
        {
            {
                LR"(private: void __cdecl winrt::Taskbar::implementation::HoverFlyoutModel::TransitionToFlyoutVisiblePendingState(struct winrt::hstring,class std::chrono::duration<__int64,struct std::ratio<1,10000000> >))",
                LR"(private: void __cdecl winrt::Taskbar::implementation::HoverFlyoutModel::TransitionToFlyoutVisiblePendingState(struct winrt::hstring,class std::chrono::duration<long long,struct std::ratio<1,10000000> >))",
            },
            &TransitionToFlyoutVisiblePendingState_Original,
            TransitionToFlyoutVisiblePendingState_Hook,
            true,
        },
        {
            {
                LR"(public: void __cdecl winrt::Taskbar::implementation::SharedAnimations::StartFlyoutEntranceAnimation(struct winrt::Windows::UI::Xaml::UIElement const &)const )",
                LR"(public: void __cdecl winrt::Taskbar::implementation::SharedAnimations::StartFlyoutEntranceAnimation(struct winrt::Windows::UI::Xaml::UIElement const &)const)",
            },
            &StartFlyoutEntranceAnimation_Original,
            StartFlyoutEntranceAnimation_Hook,
            true,
        },
        {
            {
                LR"(public: void __cdecl winrt::Taskbar::implementation::SharedAnimations::StartFlyoutExitAnimation(struct winrt::Windows::UI::Xaml::UIElement const &)const )",
                LR"(public: void __cdecl winrt::Taskbar::implementation::SharedAnimations::StartFlyoutExitAnimation(struct winrt::Windows::UI::Xaml::UIElement const &)const)",
            },
            &StartFlyoutExitAnimation_Original,
            StartFlyoutExitAnimation_Hook,
            true,
        },
        {
            {
                LR"(public: __cdecl winrt::impl::consume_Windows_UI_ViewManagement_IUISettings<struct winrt::Windows::UI::ViewManagement::IUISettings>::MouseHoverTime(void)const )",
                LR"(public: unsigned int __cdecl winrt::impl::consume_Windows_UI_ViewManagement_IUISettings<struct winrt::Windows::UI::ViewManagement::IUISettings>::MouseHoverTime(void)const )",
            },
            &MouseHoverTime_Original,
            MouseHoverTime_Hook,
            true,
        },
    };

    if (!WindhawkUtils::HookSymbols(module, hooks, ARRAYSIZE(hooks))) {
        Wh_Log(L"Taskbar.View.dll: failed to install symbol hooks");
        return false;
    }

    if (!StartFlyoutEntranceAnimation_Original &&
        !TransitionToFlyoutVisiblePendingState_Original &&
        !MouseHoverTime_Original) {
        Wh_Log(L"Taskbar.View.dll: none of the expected symbols were found");
        return false;
    }

    Wh_Log(L"Taskbar.View.dll: entrance %s, exit %s, preview delay %s, "
           L"hover time %s",
           StartFlyoutEntranceAnimation_Original ? L"ok" : L"missing",
           StartFlyoutExitAnimation_Original ? L"ok" : L"missing",
           TransitionToFlyoutVisiblePendingState_Original ? L"ok" : L"missing",
           MouseHoverTime_Original ? L"ok" : L"missing");

    return true;
}

bool HookTwinuiPcshellSymbols(HMODULE module) {
    // twinui.pcshell.dll
    WindhawkUtils::SYMBOL_HOOK hooks[] = {
        {
            {
                LR"(private: long __cdecl CVirtualDesktopHotkeyHandler::_CycleInDirection(enum VirtualDesktopSwitchDirection))",
            },
            &CycleInDirection_Original,
            CycleInDirection_Hook,
            true,
        },
    };

    if (!WindhawkUtils::HookSymbols(module, hooks, ARRAYSIZE(hooks))) {
        Wh_Log(L"twinui.pcshell.dll: failed to install symbol hooks");
        return false;
    }

    if (!CycleInDirection_Original) {
        Wh_Log(L"twinui.pcshell.dll: hotkey handler symbol not found");
        return false;
    }

    Wh_Log(L"twinui.pcshell.dll: hotkey scope installed");
    return true;
}

// Recent Windows ships two Taskbar.View.dll files. Resolving the module by name
// gives the copy that is actually loaded in this process, which is the one
// whose symbols need hooking.
void TryHookTaskbarView() {
    if (g_taskbarViewHooked.load()) {
        return;
    }

    HMODULE module = GetModuleHandleW(L"Taskbar.View.dll");
    if (!module) {
        module = GetModuleHandleW(L"ExplorerExtensions.dll");
    }

    if (!module || g_taskbarViewHooked.exchange(true)) {
        return;
    }

    Wh_Log(L"Taskbar.View.dll found, hooking");
    if (HookTaskbarViewSymbols(module)) {
        Wh_ApplyHookOperations();
    }
}

void TryHookTwinuiPcshell() {
    HMODULE module = GetModuleHandleW(L"twinui.pcshell.dll");

    if (!module || g_twinuiPcshellHooked.exchange(true)) {
        return;
    }

    Wh_Log(L"twinui.pcshell.dll found, hooking");
    if (HookTwinuiPcshellSymbols(module)) {
        Wh_ApplyHookOperations();
    }
}

// Called when a library is loaded, and again once the mod is ready, so that a
// module which was already present is not missed.
void HookLateLoadedModules() {
    TryHookTaskbarView();
    TryHookTwinuiPcshell();
}

using LoadLibraryExW_t = decltype(&LoadLibraryExW);
LoadLibraryExW_t LoadLibraryExW_Original;

// Loads with these flags only inspect a file; nothing is actually loaded, so
// they must not be mistaken for a module being brought in.
constexpr DWORD kNonExecutableLoadFlags =
    LOAD_LIBRARY_AS_DATAFILE | LOAD_LIBRARY_AS_DATAFILE_EXCLUSIVE |
    LOAD_LIBRARY_AS_IMAGE_RESOURCE;

HMODULE WINAPI LoadLibraryExW_Hook(LPCWSTR fileName,
                                   HANDLE file,
                                   DWORD flags) {
    HMODULE module = LoadLibraryExW_Original(fileName, file, flags);

    if (module && !(flags & kNonExecutableLoadFlags) && IsShellProcess()) {
        HookLateLoadedModules();
    }

    return module;
}

// ===========================================================================
// Restarting the shell components
// ===========================================================================

void RestartShellProcesses() {
    static const WCHAR* const kTargets[] = {
        L"StartMenuExperienceHost.exe",
        L"SearchHost.exe",
        L"ShellHost.exe",
        L"ShellExperienceHost.exe",
    };

    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) {
        return;
    }

    PROCESSENTRY32W entry{};
    entry.dwSize = sizeof(entry);

    if (Process32FirstW(snapshot, &entry)) {
        do {
            for (const WCHAR* target : kTargets) {
                if (_wcsicmp(entry.szExeFile, target) == 0) {
                    HANDLE process =
                        OpenProcess(PROCESS_TERMINATE, FALSE,
                                    entry.th32ProcessID);
                    if (process) {
                        TerminateProcess(process, 0);
                        CloseHandle(process);
                    }
                    break;
                }
            }
        } while (Process32NextW(snapshot, &entry));
    }

    CloseHandle(snapshot);
}

// Restarting is disruptive, so it only happens for a change that needs it.
bool ShellFlyoutSettingsChanged(bool start,
                                bool search,
                                bool quickSettings,
                                bool notificationCenter) {
    return start != settings.shellFlyoutStart ||
           search != settings.shellFlyoutSearch ||
           quickSettings != settings.shellFlyoutQuickSettings ||
           notificationCenter != settings.shellFlyoutNotificationCenter;
}

// ===========================================================================
// Entry points
// ===========================================================================

void RestartShellProcessesForExplorer() {
    if (g_procKind == ProcKind::explorer && settings.restartShellProcesses &&
        IsShellProcess()) {
        RestartShellProcesses();
    }
}

}  // namespace

BOOL Wh_ModInit() {
    g_procKind = DetectProcKind();

    if (g_procKind == ProcKind::unknown) {
        Wh_Log(L"Unsupported process, doing nothing");
        return FALSE;
    }

    if (!IsWindows11()) {
        Wh_Log(L"This mod only supports Windows 11");
        return FALSE;
    }

    LoadSettings();

    Wh_Log(L"Init, process kind = %d", static_cast<int>(g_procKind));

    // The animation switch is answered differently in every targeted process.
    WindhawkUtils::SetFunctionHook(SystemParametersInfoW,
                                   SystemParametersInfoW_Hook,
                                   &SystemParametersInfoW_Original);

    if (g_procKind == ProcKind::explorer) {
        HMODULE user32 = GetModuleHandleW(L"user32.dll");
        if (user32) {
            auto setTimer = reinterpret_cast<SetTimer_t>(
                GetProcAddress(user32, "SetTimer"));
            if (setTimer) {
                WindhawkUtils::SetFunctionHook(setTimer, SetTimer_Hook,
                                               &SetTimer_Original);
            }
        }

        // Taskbar.View.dll and twinui.pcshell.dll load later, so watch for
        // them.
        HMODULE kernelBase = GetModuleHandleW(L"kernelbase.dll");
        if (kernelBase) {
            auto loadLibraryExW = reinterpret_cast<LoadLibraryExW_t>(
                GetProcAddress(kernelBase, "LoadLibraryExW"));
            if (loadLibraryExW) {
                WindhawkUtils::SetFunctionHook(loadLibraryExW,
                                               LoadLibraryExW_Hook,
                                               &LoadLibraryExW_Original);
            }
        }
    }

    RestartShellProcessesForExplorer();
    return TRUE;
}

void Wh_ModAfterInit() {
    if (g_procKind == ProcKind::explorer && IsShellProcess()) {
        HookLateLoadedModules();
    }
}

void Wh_ModUninit() {
    RestartShellProcessesForExplorer();
}

void Wh_ModSettingsChanged() {
    bool previousStart = settings.shellFlyoutStart;
    bool previousSearch = settings.shellFlyoutSearch;
    bool previousQuickSettings = settings.shellFlyoutQuickSettings;
    bool previousNotificationCenter = settings.shellFlyoutNotificationCenter;

    LoadSettings();

    if (ShellFlyoutSettingsChanged(previousStart, previousSearch,
                                   previousQuickSettings,
                                   previousNotificationCenter)) {
        RestartShellProcessesForExplorer();
    }
}

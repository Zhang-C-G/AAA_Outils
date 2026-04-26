; State and app bootstrap

; ---------------------------------
; Global config / state
; ---------------------------------
gDataFile := A_ScriptDir "\\config.ini"
gSnapshotFile := A_ScriptDir "\\config.snapshot.ini"
gLogFile := A_ScriptDir "\\action.log"
gUsageFile := A_ScriptDir "\\usage.ini"
gAssistantRateFile := A_ScriptDir "\\assistant_rate.ini"
gNotesDir := A_ScriptDir "\\notes"
gNotesDisplayDir := A_ScriptDir "\\notes_display"
gCaptureDir := A_ScriptDir "\\captures"
gCaptureBridgeScript := A_Temp "\\raccourci_capture_bridge.ps1"
gCaptureBridgePidFile := A_Temp "\\raccourci_capture_bridge.pid"
gCaptureBridgeStatusFile := A_Temp "\\raccourci_capture_bridge_status.ini"
gWebConfigPort := 8798
gWebConfigServerFile := A_ScriptDir "\\webui\\config\\server.ps1"
gWebConfigPidFile := A_Temp "\\raccourci_web_config_server.pid"
gWebConfigActionFile := A_Temp "\\raccourci_web_config_action.json"
gWebConfigDesiredFile := A_Temp "\\raccourci_web_config_desired.flag"
gResumeProfileFile := A_ScriptDir "\\resume_profile.json"
gAppName := "靠北！Raccourci Control"

gPanelGui := ""
gConfigGui := ""
gSearchEdit := ""
gMatchList := ""
gStatusText := ""
gHintText := ""

gLastTargetHwnd := 0
gPanelVisible := false
gMatches := []

gData := Map("fields", [], "prompts", [])
gCategories := []
gUsage := Map("fields", Map(), "prompts", Map())
gTheme := Map()
gBehavior := Map()
gAppSettings := Map()
gCaptureSettings := Map()
gAssistantSettings := Map()
gResumeSettings := Map()
gActiveMode := "shortcuts"
gCurrentQuery := ""
gUsesSinceAutoRefresh := 0
gCaptureLastPath := ""
gCaptureLatestFile := ""
gAssistantLastResult := ""
gConfigDiskStamp := ""

gHotkeys := Map()
gHotkeyDefs := []
gRegisteredHotkeys := []

gPanelW := 428
gPanelH := 410

gDevAutoReloadEnabled := true
gDevReloadSignature := ""

Init() {
    global gData, gUsage, gHotkeys, gBehavior, gCategories, gAppSettings, gActiveMode, gCaptureSettings, gAssistantSettings, gResumeSettings, gCaptureDir
    global gConfigDiskStamp
    InitTheme()
    InitHotkeyDefs()
    EnsureDataFile()
    EnsureUsageFile()
    EnsureAssistantRateFile()
    EnsureNotesStore()
    EnsureNotesDisplayStore()
    gAppSettings := LoadAppSettings()
    if (gAppSettings.Has("capture_dir") && Trim(gAppSettings["capture_dir"]) != "") {
        gCaptureDir := gAppSettings["capture_dir"]
    }
    EnsureCaptureStore()
    gCategories := LoadCategories()
    gData := LoadDataByCategories(gCategories)
    gUsage := LoadUsageCounts()
    gHotkeys := LoadHotkeys()
    gBehavior := LoadBehavior()
    gCaptureSettings := LoadCaptureSettings()
    gAssistantSettings := LoadAssistantSettings()
    gResumeSettings := LoadResumeSettings()
    gActiveMode := gAppSettings["active_mode"]
    UpdateConfigDiskStamp()

    BuildPanelGui()
    BuildConfigGui()
    RegisterHotkeys()
    RestartAutoRefreshTimer()
    OnExit(OnAppExit)
    RestoreWebConfigServerIfNeeded()
    StartDevAutoReloadWatcher()

    WriteLog("startup", "script initialized")
}

StartDevAutoReloadWatcher() {
    global gDevAutoReloadEnabled, gDevReloadSignature
    if !gDevAutoReloadEnabled {
        return
    }
    gDevReloadSignature := BuildDevReloadSignature()
    SetTimer(CheckDevAutoReload, 1200)
}

CheckDevAutoReload(*) {
    global gDevAutoReloadEnabled, gDevReloadSignature
    if !gDevAutoReloadEnabled {
        return
    }

    nextSig := BuildDevReloadSignature()
    if (nextSig = gDevReloadSignature) {
        return
    }

    gDevReloadSignature := nextSig
    WriteLog("dev_auto_reload", "source_changed -> reload")
    SetTimer(DoDevAutoReload, -80)
}

DoDevAutoReload(*) {
    Reload()
}

BuildDevReloadSignature() {
    mainTime := ""
    try mainTime := FileGetTime(A_ScriptFullPath, "M")

    parts := [A_ScriptFullPath "=" mainTime]
    ahkCount := 0
    loop files, A_ScriptDir "\\src\\*.ahk", "R" {
        ahkCount += 1
        t := ""
        try t := FileGetTime(A_LoopFileFullPath, "M")
        parts.Push(A_LoopFileFullPath "=" t)
    }

    return "count=" ahkCount "|" StrJoin(parts, "|")
}

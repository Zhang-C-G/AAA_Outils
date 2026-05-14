; Web config UI bridge (AHK + local HTTP server)

gWebConfigTimerEnabled := false

GetConfigDiskStamp() {
    global gDataFile
    if !FileExist(gDataFile) {
        return ""
    }
    try return FileGetTime(gDataFile, "M")
    catch
        return ""
}

UpdateConfigDiskStamp() {
    global gConfigDiskStamp
    gConfigDiskStamp := GetConfigDiskStamp()
    return gConfigDiskStamp
}

SyncConfigStateFromDiskIfNewer(reason := "") {
    global gConfigDiskStamp

    currentStamp := GetConfigDiskStamp()
    if (currentStamp = "") {
        return false
    }
    if (gConfigDiskStamp = currentStamp) {
        return false
    }

    ReloadAppStateFromDisk()
    WriteLog("config_disk_sync", "reason=" reason " stamp=" currentStamp)
    return true
}

ShowWebConfigWindow() {
    global gWebConfigPort, gWebConfigDesiredFile
    try FileAppend("", gWebConfigDesiredFile, "UTF-8")
    ok := StartWebConfigServer(gWebConfigPort)
    if !ok {
        MsgBox("Web UI start failed, fallback to legacy window.")
        return false
    }

    url := "http://127.0.0.1:" gWebConfigPort "/"
    Run(url)
    WriteLog("config_open", "web url=" url)
    return true
}

RestoreWebConfigServerIfNeeded() {
    global gWebConfigDesiredFile, gWebConfigPort
    if !FileExist(gWebConfigDesiredFile) {
        return
    }
    try StartWebConfigServer(gWebConfigPort)
}

StartWebConfigServer(port := 8798) {
    global gWebConfigPort, gWebConfigPidFile, gWebConfigServerFile
    global gDataFile, gUsageFile, gSnapshotFile, gWebConfigActionFile, gNotesDir, gNotesDisplayDir, gCaptureDir, gLogFile
    global gCaptureBridgeScript, gCaptureBridgePidFile, gCaptureBridgeStatusFile, gResumeProfileFile

    gWebConfigPort := port
    if IsWebConfigServerAlive() {
        if WebConfigServerNeedsRestart() {
            StopWebConfigServer()
        } else {
            EnsureWebConfigActionWatcher()
            return true
        }
    }

    if IsWebConfigServerAlive() {
        EnsureWebConfigActionWatcher()
        return true
    }

    if !FileExist(gWebConfigServerFile) {
        WriteLog("web_config_start_failed", "missing server file")
        return false
    }

    if FileExist(gWebConfigPidFile) {
        try FileDelete(gWebConfigPidFile)
    }

    cmd := 'powershell -NoProfile -ExecutionPolicy Bypass -File "' gWebConfigServerFile '"'
        . ' -Port ' gWebConfigPort
        . ' -Root "' A_ScriptDir '\\webui\\config"'
        . ' -DataFile "' gDataFile '"'
        . ' -UsageFile "' gUsageFile '"'
        . ' -SnapshotFile "' gSnapshotFile '"'
        . ' -ActionFile "' gWebConfigActionFile '"'
        . ' -PidFile "' gWebConfigPidFile '"'
        . ' -NotesDir "' gNotesDir '"'
        . ' -NotesDisplayDir "' gNotesDisplayDir '"'
        . ' -CaptureDir "' gCaptureDir '"'
        . ' -BridgeScript "' gCaptureBridgeScript '"'
        . ' -BridgePidFile "' gCaptureBridgePidFile '"'
        . ' -BridgeStatusFile "' gCaptureBridgeStatusFile '"'
        . ' -ResumeProfileFile "' gResumeProfileFile '"'
        . ' -LogFile "' gLogFile '"'

    try {
        Run(cmd, , "Hide")
    } catch {
        WriteLog("web_config_start_failed", "run exception")
        return false
    }

    alive := false
    Loop 16 {
        Sleep(250)
        if IsWebConfigServerAlive() {
            alive := true
            break
        }
    }

    if alive {
        EnsureWebConfigActionWatcher()
        WriteLog("web_config_start", "port=" gWebConfigPort)
    } else {
        WriteLog("web_config_start_failed", "pid not alive")
    }
    return alive
}

WebConfigServerNeedsRestart() {
    global gWebConfigPidFile
    if !FileExist(gWebConfigPidFile) {
        return false
    }

    try pidInfo := FileGetTime(gWebConfigPidFile, "M")
    catch
        return false

    latest := GetWebConfigSourceLatestWriteTime()
    if (latest = "") {
        return false
    }
    return latest > pidInfo
}

GetWebConfigSourceLatestWriteTime() {
    root := A_ScriptDir "\\webui\\config"
    latest := ""

    Loop Files, root "\\*.html", "F" {
        if (latest = "" || A_LoopFileTimeModified > latest) {
            latest := A_LoopFileTimeModified
        }
    }
    Loop Files, root "\\*.css", "F" {
        if (latest = "" || A_LoopFileTimeModified > latest) {
            latest := A_LoopFileTimeModified
        }
    }
    Loop Files, root "\\*.js", "F" {
        if (latest = "" || A_LoopFileTimeModified > latest) {
            latest := A_LoopFileTimeModified
        }
    }
    Loop Files, root "\\server*.ps1", "F" {
        if (latest = "" || A_LoopFileTimeModified > latest) {
            latest := A_LoopFileTimeModified
        }
    }
    Loop Files, root "\\server_state\\*.ps1", "F" {
        if (latest = "" || A_LoopFileTimeModified > latest) {
            latest := A_LoopFileTimeModified
        }
    }
    return latest
}

EnsureWebConfigActionWatcher() {
    global gWebConfigTimerEnabled
    if gWebConfigTimerEnabled {
        return
    }
    SetTimer(ProcessWebConfigActionFile, 120)
    gWebConfigTimerEnabled := true
}

ProcessWebConfigActionFile(*) {
    global gWebConfigActionFile, gAssistantOverlayVisible
    if !FileExist(gWebConfigActionFile) {
        return
    }

    raw := ""
    try raw := FileRead(gWebConfigActionFile, "UTF-8")
    try FileDelete(gWebConfigActionFile)

    raw := Trim(raw)

    if (raw = "reload") {
        ReloadAppStateFromDisk()
        WriteLog("web_config_reload", "applied from web ui")
    }
    if (raw = "assistant_overlay_open_only") {
        if !gAssistantOverlayVisible {
            SetTimer(WebConfigOpenAssistantOverlayOnlyAction, -1)
        }
    } else if (raw = "assistant_overlay_open") {
        SetTimer(WebConfigToggleAssistantOverlayAction, -1)
    } else if (raw = "assistant_capture_now") {
        SetTimer(WebConfigAssistantCaptureNowAction, -1)
        WriteLog("assistant_capture_triggered", "source=web_action")
    } else if (raw = "assistant_voice_input_down") {
        SetTimer(WebConfigAssistantVoiceInputDownAction, -1)
    } else if (raw = "assistant_voice_input_up") {
        SetTimer(WebConfigAssistantVoiceInputUpAction, -1)
    }
}

WebConfigToggleAssistantOverlayAction(*) {
    ToggleAssistantOverlay(false, "web_action")
}

WebConfigOpenAssistantOverlayOnlyAction(*) {
    StartAssistantOverlayOnly(false)
}

WebConfigAssistantCaptureNowAction(*) {
    StartAssistantCaptureFlow(false)
}

WebConfigAssistantVoiceInputDownAction(*) {
    StartAssistantVoiceInputHold(false)
}

WebConfigAssistantVoiceInputUpAction(*) {
    StopAssistantVoiceInputHold(false)
}

ReloadAppStateFromDisk() {
    global gData, gUsage, gHotkeys, gBehavior, gCategories, gAppSettings, gActiveMode, gCaptureSettings, gAssistantSettings, gCaptureDir

    gCategories := LoadCategories()
    gData := LoadDataByCategories(gCategories)
    gUsage := LoadUsageCounts()
    gHotkeys := LoadHotkeys()
    gBehavior := LoadBehavior()
    gAppSettings := LoadAppSettings()
    if (gAppSettings.Has("capture_dir") && Trim(gAppSettings["capture_dir"]) != "") {
        gCaptureDir := gAppSettings["capture_dir"]
    }
    gCaptureSettings := LoadCaptureSettings()
    gAssistantSettings := LoadAssistantSettings()
    gActiveMode := gAppSettings["active_mode"]
    UpdateConfigDiskStamp()

    RegisterHotkeys()
    RestartAutoRefreshTimer()
    EnsureWebConfigActionWatcher()
    try SyncAssistantOverlayAfterSettingsChange()
    try RebuildConfigWindow()
}

StopWebConfigServer() {
    global gWebConfigPidFile
    pid := ReadWebConfigPid()
    if (pid > 0) {
        try RunWait('powershell -NoProfile -Command "Stop-Process -Id ' pid ' -Force"', , "Hide")
        WriteLog("web_config_stop", "pid=" pid)
    }
    if FileExist(gWebConfigPidFile) {
        try FileDelete(gWebConfigPidFile)
    }
}

ReadWebConfigPid() {
    global gWebConfigPidFile
    if !FileExist(gWebConfigPidFile) {
        return 0
    }
    raw := Trim(FileRead(gWebConfigPidFile, "UTF-8"))
    if !RegExMatch(raw, "^\d+$") {
        return 0
    }
    return Integer(raw)
}

IsWebConfigServerAlive() {
    pid := ReadWebConfigPid()
    if (pid <= 0) {
        return false
    }
    return ProcessExist(pid) != 0
}

OnAppExit(reason, code) {
    global gWebConfigDesiredFile
    if (reason != "Reload") {
        try FileDelete(gWebConfigDesiredFile)
    }
    StopWebConfigServer()
}

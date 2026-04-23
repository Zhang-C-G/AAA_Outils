; Config tabs submodule: snapshot save/restore

OnSaveVersionClicked(*) {
    if SaveSnapshotVersion() {
        WriteLog("version_save", "snapshot saved")
        MsgBox("Version saved.")
    } else {
        MsgBox("Save version failed.")
    }
}

OnRestoreVersionClicked(*) {
    global gCategories, gData, gUsage, gHotkeys, gBehavior, gAppSettings, gActiveMode, gCaptureSettings, gAssistantSettings

    if !RestoreSnapshotVersion() {
        MsgBox("No restorable version found.")
        return
    }

    gCategories := LoadCategories()
    gData := LoadDataByCategories(gCategories)
    gUsage := LoadUsageCounts()
    gHotkeys := LoadHotkeys()
    gBehavior := LoadBehavior()
    gAppSettings := LoadAppSettings()
    gCaptureSettings := LoadCaptureSettings()
    gAssistantSettings := LoadAssistantSettings()
    gActiveMode := gAppSettings["active_mode"]

    RegisterHotkeys()
    RestartAutoRefreshTimer()
    WriteLog("version_restore", "snapshot restored")
    RebuildConfigWindow()
    MsgBox("Restored to latest saved version.")
}

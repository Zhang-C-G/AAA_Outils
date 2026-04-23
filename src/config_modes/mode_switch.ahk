GetModeIdFromChoose(index) {
    if (index = 2) {
        return "notes"
    }
    if (index = 3) {
        return "capture"
    }
    if (index = 4) {
        return "assistant"
    }
    if (index = 5) {
        return "resume"
    }
    return "shortcuts"
}

OnConfigModeChanged(ctrl, *) {
    global gActiveMode
    nextMode := GetModeIdFromChoose(ctrl.Value)
    if (nextMode = gActiveMode) {
        return
    }
    if (gActiveMode = "notes" && nextMode != "notes") {
        SaveCurrentNoteIfAny()
    }
    if (gActiveMode = "capture" && nextMode != "capture") {
        SaveCaptureSettingsFromGui()
        SetTimer(UpdateCaptureBridgeStatusUi, 0)
    }
    if (gActiveMode = "assistant" && nextMode != "assistant") {
        SaveAssistantSettingsFromGui()
    }
    if (gActiveMode = "resume" && nextMode != "resume") {
        SaveResumeSettingsFromGui()
    }
    gActiveMode := nextMode
    SaveData()
    WriteLog("mode_switch", "active_mode=" gActiveMode)
    RebuildConfigWindow()
}

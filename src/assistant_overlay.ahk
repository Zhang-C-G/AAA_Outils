; Screenshot assistant runtime overlay

gAssistantOverlayGui := ""
gAssistantOverlayText := ""
gAssistantOverlayTextHint := ""
gAssistantOverlayStatusText := ""
gAssistantOverlayCaptureBtn := ""
gAssistantOverlayCaptureBusy := false
gAssistantOverlayVisible := false
gAssistantOverlayTempHidden := false
gAssistantOverlayTempRestoreText := ""
gAssistantOverlayProtectionGapHidden := false
gAssistantOverlayProtectionGapRestoreText := ""
gAssistantOverlayProtectionGapRestoreStatus := "状态：悬浮窗已恢复"
gAssistantOverlayRiskHidden := false
gAssistantOverlayRiskRestoreText := ""
gAssistantOverlayRiskRestoreStatus := "状态：悬浮窗已恢复"
gAssistantOverlaySensitiveHidden := false
gAssistantOverlaySensitiveRestoreText := ""
gAssistantOverlaySensitiveRestoreStatus := "状态：处理中..."
gAssistantOverlayLastStatus := "状态：待命"
gAssistantOverlayCaptureGuardEnabled := true
gAssistantOverlayCaptureGuardRunning := false
gAssistantOverlayInSensitivePhase := false
gAssistantThinkingActive := false
gAssistantThinkingStartTick := 0
gAssistantOverlayPlaced := false
; Core-first baseline: keep generic capture exclusion enabled whenever the
; assistant overlay is visible. Secondary effects such as custom opacity must
; yield to the primary goal: local-visible while absent from recordings.
gAssistantOverlayAffinityEnabled := true
gAssistantOverlayAffinityActive := false
; Keep WDA on for recorder exclusion, but only auto-hide on real screenshot actions.
gAssistantOverlaySecurityFirst := true
gAssistantOverlayTempRestoreStatus := "状态：悬浮窗已恢复"
gAssistantOverlayLastProtectionRearmTick := 0
gAssistantOverlayLastProtectionEnsureTick := 0
gAssistantOverlayProtectionRearmPending := false
gAssistantOverlayProtectionRearmReason := ""
gAssistantOverlayFullText := ""
gAssistantOverlayRenderedLines := []
gAssistantOverlayScrollOffset := 1
gAssistantOverlayLastAppliedOpacity := -1
gAssistantOverlayRecordingProtectionActive := false
gAssistantOverlayOpenGraceUntilTick := 0
gAssistantOverlayAffinityRepairFailures := 0
gAssistantOverlayAffinityRepairCooldownUntilTick := 0
gAssistantOverlayCaptureRiskLastSeenTick := 0
gAssistantOverlayEnhancedProtectGapSinceTick := 0

ResetAssistantOverlayProtectionStability() {
    global gAssistantOverlayAffinityRepairFailures, gAssistantOverlayAffinityRepairCooldownUntilTick
    gAssistantOverlayAffinityRepairFailures := 0
    gAssistantOverlayAffinityRepairCooldownUntilTick := 0
}

BeginAssistantOverlayOpenGrace(durationMs := 1200) {
    global gAssistantOverlayOpenGraceUntilTick
    duration := Max(0, Abs(Integer(durationMs)))
    if (GetAssistantCaptureMode() = "enhanced") {
        duration := Max(duration, 1800)
    }
    gAssistantOverlayOpenGraceUntilTick := A_TickCount + duration
}

IsAssistantOverlayInOpenGrace() {
    global gAssistantOverlayOpenGraceUntilTick
    return (A_TickCount < gAssistantOverlayOpenGraceUntilTick)
}

GetAssistantOverlayRearmDelayMs(baseDelay := 220) {
    global gAssistantOverlayOpenGraceUntilTick
    delay := Max(60, Abs(Integer(baseDelay)))
    if IsAssistantOverlayInOpenGrace() {
        delay := Max(delay, (gAssistantOverlayOpenGraceUntilTick - A_TickCount) + 80)
    }
    return delay
}

CanAssistantOverlayAttemptProtectionRepair() {
    global gAssistantOverlayAffinityRepairCooldownUntilTick
    if (GetAssistantCaptureMode() != "enhanced" && IsAssistantOverlayInOpenGrace()) {
        return false
    }
    if (GetAssistantCaptureMode() = "enhanced") {
        return true
    }
    if (A_TickCount < gAssistantOverlayAffinityRepairCooldownUntilTick) {
        return false
    }
    return true
}

NoteAssistantOverlayProtectionRepairResult(success, reason := "") {
    global gAssistantOverlayAffinityRepairFailures, gAssistantOverlayAffinityRepairCooldownUntilTick
    global gAssistantOverlayEnhancedProtectGapSinceTick
    if success {
        if (gAssistantOverlayAffinityRepairFailures > 0 || gAssistantOverlayAffinityRepairCooldownUntilTick > 0) {
            WriteLog("assistant_overlay_protect_repair_recovered", "reason=" reason)
        }
        gAssistantOverlayAffinityRepairFailures := 0
        gAssistantOverlayAffinityRepairCooldownUntilTick := 0
        gAssistantOverlayEnhancedProtectGapSinceTick := 0
        return
    }

    gAssistantOverlayAffinityRepairFailures += 1
    if (GetAssistantCaptureMode() = "enhanced") {
        if (gAssistantOverlayAffinityRepairFailures >= 3) {
            WriteLog(
                "assistant_overlay_protect_repair_retrying",
                "mode=enhanced reason=" reason " failures=" gAssistantOverlayAffinityRepairFailures
            )
            gAssistantOverlayAffinityRepairFailures := 0
        }
        return
    }
    if (gAssistantOverlayAffinityRepairFailures < 3) {
        return
    }

    gAssistantOverlayAffinityRepairCooldownUntilTick := A_TickCount + 5000
    WriteLog(
        "assistant_overlay_protect_repair_paused",
        "reason=" reason " failures=" gAssistantOverlayAffinityRepairFailures " cooldown_ms=5000"
    )
    gAssistantOverlayAffinityRepairFailures := 0
}

IsAssistantOverlayProtectionMode() {
    global gAssistantOverlayAffinityEnabled, gAssistantOverlayRecordingProtectionActive
    return gAssistantOverlayAffinityEnabled || gAssistantOverlayRecordingProtectionActive
}

GetAssistantOverlayTargetOpacity() {
    global gAssistantSettings
    opacity := 100
    try opacity := ClampAssistantOpacity(gAssistantSettings["overlay_opacity"])
    return opacity
}

GetAssistantOverlayEffectiveOpacity() {
    if IsAssistantOverlayProtectionMode() {
        return 100
    }
    return GetAssistantOverlayTargetOpacity()
}

ShouldAssistantOverlayProtectionBeActive() {
    if IsAssistantOverlayProtectionMode() {
        return true
    }
    return ShouldAssistantOverlayRearmProtection()
}

ShouldAssistantOverlayRearmProtection() {
    return GetAssistantOverlayTargetOpacity() >= 100
}

SyncAssistantOverlayAfterSettingsChange() {
    global gAssistantOverlayVisible, gAssistantOverlayRecordingProtectionActive, gAssistantOverlayAffinityEnabled
    if !gAssistantOverlayVisible {
        return
    }

    opacity := GetAssistantOverlayTargetOpacity()
    if (!gAssistantOverlayAffinityEnabled && !gAssistantOverlayRecordingProtectionActive && opacity < 100) {
        DisableAssistantOverlayCaptureProtection("semi_transparent_settings")
    }
    SetAssistantOverlayOpacity(GetAssistantOverlayEffectiveOpacity())
    if (ShouldAssistantOverlayProtectionBeActive()) {
        QueueAssistantOverlayProtectionRearm("settings_reload")
    }
}

DisableAssistantOverlayCaptureProtection(reason := "") {
    global gAssistantOverlayGui, gAssistantOverlayAffinityActive, gAssistantOverlayProtectionRearmPending
    global gAssistantOverlayRecordingProtectionActive, gAssistantOverlayLastAppliedOpacity
    wasRecordingProtected := gAssistantOverlayRecordingProtectionActive
    gAssistantOverlayRecordingProtectionActive := false
    if !IsObject(gAssistantOverlayGui) {
        gAssistantOverlayAffinityActive := false
        gAssistantOverlayProtectionRearmPending := false
        return
    }

    gAssistantOverlayProtectionRearmPending := false
    try DllCall("user32\SetWindowDisplayAffinity", "Ptr", gAssistantOverlayGui.Hwnd, "UInt", 0, "Int")
    gAssistantOverlayAffinityActive := false
    try WinSetTransparent("Off", "ahk_id " gAssistantOverlayGui.Hwnd)
    gAssistantOverlayLastAppliedOpacity := 100
    SetAssistantOverlayOpacity(GetAssistantOverlayTargetOpacity())
    if (reason != "") {
        WriteLog("assistant_overlay_protect_disabled", "reason=" reason)
    }
    if (wasRecordingProtected) {
        WriteLog("assistant_overlay_recording_protect_off", "reason=" reason)
    }
}

EnableAssistantOverlayRecordingProtection(reason := "") {
    global gAssistantOverlayGui, gAssistantOverlayVisible, gAssistantOverlayAffinityActive
    global gAssistantOverlayRecordingProtectionActive, gAssistantOverlayLastAppliedOpacity
    if !gAssistantOverlayVisible || !IsObject(gAssistantOverlayGui) {
        return false
    }
    if gAssistantOverlayRecordingProtectionActive {
        return gAssistantOverlayAffinityActive
    }

    hwnd := gAssistantOverlayGui.Hwnd
    gAssistantOverlayRecordingProtectionActive := true
    gAssistantOverlayLastAppliedOpacity := -1
    try WinSetTransparent("Off", "ahk_id " hwnd)
    ok := DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0x11, "Int")
    gAssistantOverlayAffinityActive := (ok != 0)
    SetAssistantOverlayOpacity(100)
    if gAssistantOverlayAffinityActive {
        WriteLog("assistant_overlay_recording_protect_on", "reason=" reason)
    } else {
        WriteLog("assistant_overlay_recording_protect_failed", "reason=" reason " last_error=" A_LastError)
    }
    return gAssistantOverlayAffinityActive
}

GetAssistantCurrentModelLabel() {
    global gAssistantSettings
    model := ""
    try model := Trim(gAssistantSettings["model"])
    if (model = "") {
        model := "doubao-seed-2-0-lite-260215"
    }
    return model
}

IsAssistantOverlayCopyBlocked() {
    global gAssistantSettings
    if !IsObject(gAssistantSettings) {
        return true
    }
    if !gAssistantSettings.Has("disable_copy") {
        return true
    }
    return gAssistantSettings["disable_copy"] ? true : false
}

IsAssistantEnhancedCaptureModeEnabled() {
    global gAssistantSettings
    if !IsObject(gAssistantSettings) || !gAssistantSettings.Has("enhanced_capture_mode") {
        return false
    }
    return gAssistantSettings["enhanced_capture_mode"] ? true : false
}

GetAssistantCaptureMode() {
    if IsAssistantEnhancedCaptureModeEnabled() {
        return "enhanced"
    }
    return "standard"
}

IsAssistantEnhancedCaptureModeReady() {
    global gAssistantOverlayAffinityActive
    if (GetAssistantCaptureMode() != "enhanced") {
        return false
    }
    if !gAssistantOverlayAffinityActive {
        return false
    }
    return GetAssistantOverlayCurrentDisplayAffinity() = 0x11
}

CanAssistantKeepVisibleDuringCapture() {
    ; Only the internal F1 capture flow is allowed to attempt "locally visible,
    ; capture result hidden". External screenshot hotkeys must still temp-hide.
    return IsAssistantEnhancedCaptureModeEnabled()
}

EnsureAssistantOverlayReadonlyMousePolicy() {
    ; 回答区永久禁止鼠标选中与 I-beam 光标，保持纯展示区域体验。
    OnMessage(0x21, AssistantOverlayOnMouseActivate)     ; WM_MOUSEACTIVATE
    OnMessage(0x20, AssistantOverlayOnSetCursor)         ; WM_SETCURSOR
    OnMessage(0x201, AssistantOverlayOnMouseDown)        ; WM_LBUTTONDOWN
    OnMessage(0x202, AssistantOverlayOnMouseDown)        ; WM_LBUTTONUP
    OnMessage(0x203, AssistantOverlayOnMouseDown)        ; WM_LBUTTONDBLCLK
    OnMessage(0x204, AssistantOverlayOnMouseDown)        ; WM_RBUTTONDOWN
    OnMessage(0x205, AssistantOverlayOnMouseDown)        ; WM_RBUTTONUP
}

EnsureAssistantOverlayProtectionMessageHooks() {
    ; Re-arm protection after display / composition / app activation transitions.
    OnMessage(0x007E, AssistantOverlayOnDisplayChange)   ; WM_DISPLAYCHANGE
    OnMessage(0x031E, AssistantOverlayOnDisplayChange)   ; WM_DWMCOMPOSITIONCHANGED
    OnMessage(0x001C, AssistantOverlayOnDisplayChange)   ; WM_ACTIVATEAPP
}

NormalizeAssistantOverlayWindowStyles() {
    global gAssistantOverlayGui
    if !IsObject(gAssistantOverlayGui) {
        return
    }

    hwnd := gAssistantOverlayGui.Hwnd
    GWL_EXSTYLE := -20
    WS_EX_APPWINDOW := 0x00040000
    WS_EX_TOOLWINDOW := 0x00000080
    WS_EX_NOACTIVATE := 0x08000000
    exStyle := DllCall("user32\GetWindowLongPtr", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr")
    if (exStyle = 0) {
        return
    }
    nextStyle := ((exStyle | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE) & ~WS_EX_APPWINDOW)
    if (nextStyle != exStyle) {
        DllCall("user32\SetWindowLongPtr", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr", nextStyle, "Ptr")
        SWP_NOSIZE := 0x0001
        SWP_NOMOVE := 0x0002
        SWP_NOZORDER := 0x0004
        SWP_NOACTIVATE := 0x0010
        SWP_FRAMECHANGED := 0x0020
        DllCall(
            "user32\SetWindowPos",
            "Ptr", hwnd,
            "Ptr", 0,
            "Int", 0,
            "Int", 0,
            "Int", 0,
            "Int", 0,
            "UInt", SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED,
            "Int"
        )
    }
}

RefreshAssistantOverlayWindow(redrawFrame := true) {
    global gAssistantOverlayGui
    if !IsObject(gAssistantOverlayGui) {
        return
    }

    hwnd := gAssistantOverlayGui.Hwnd
    flags := 0x0001 | 0x0004 | 0x0080 | 0x0400
    if redrawFrame {
        flags |= 0x0400
    }
    try DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", flags, "Int")
    try DllCall("user32\UpdateWindow", "Ptr", hwnd, "Int")
    try DllCall("dwmapi\DwmFlush")
}

WaitAssistantOverlayHidden(timeoutMs := 260) {
    global gAssistantOverlayGui
    if !IsObject(gAssistantOverlayGui) {
        return true
    }

    hwnd := gAssistantOverlayGui.Hwnd
    deadline := A_TickCount + Max(40, Abs(Integer(timeoutMs)))
    loop {
        visible := DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
        if (visible = 0) {
            break
        }
        if (A_TickCount >= deadline) {
            break
        }
        Sleep(15)
    }
    try DllCall("dwmapi\DwmFlush")
    Sleep(45)
    return DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int") = 0
}

StartAssistantOverlayOnly(showNotice := true) {
    global gAssistantSettings, gAssistantLastResult

    if (!gAssistantSettings.Has("enabled") || gAssistantSettings["enabled"] = 0) {
        msg := "助手功能当前已禁用，请在 Assistant 模块中启用。"
        if showNotice {
            MsgBox(msg)
        }
        return Map("ok", 0, "text", "", "error", msg, "path", "")
    }

    text := Trim(gAssistantLastResult)
    if (text = "") {
        text := "截图问答悬浮窗已启动。`n按 F1 进行截图并问答。"
    }

    ShowAssistantOverlay(text)
    WriteLog("assistant_overlay_open", "source=manual")
    return Map("ok", 1, "text", text, "error", "", "path", "")
}

StartAssistantCaptureFlow(showNotice := true) {
    global gAssistantSettings, gAssistantLastResult, gCaptureLastPath, gAssistantOverlayVisible

    if (!gAssistantSettings.Has("enabled") || gAssistantSettings["enabled"] = 0) {
        msg := "助手功能当前已禁用，请在 Assistant 模块中启用。"
        if showNotice {
            MsgBox(msg)
        }
        return Map("ok", 0, "text", "", "error", msg, "path", "")
    }

    EnsureAssistantOverlayGui()
    modelLabel := GetAssistantCurrentModelLabel()
    wasOverlayVisible := gAssistantOverlayVisible
    restoreText := ""
    restoreStatus := ""
    if wasOverlayVisible {
        restoreText := GetAssistantOverlayCurrentText()
        restoreStatus := gAssistantOverlayLastStatus
        if (restoreText = "") {
            restoreText := "截图问答悬浮窗已启动。`n按 F1 进行截图并问答。"
        }
        SetAssistantOverlayText("准备开始截图问答...`n当前模型：" modelLabel)
        UpdateAssistantOverlayStatus("状态：准备截图 | 模型：" modelLabel)
    }

    rateRes := ConsumeAssistantRateLimit(gAssistantSettings)
    if !rateRes["ok"] {
        WriteLog("assistant_rate_limited", "limit=" rateRes["limit"] " used=" rateRes["used"])
        if wasOverlayVisible {
            UpdateAssistantOverlayStatus("状态：限流触发 | 模型：" modelLabel)
        }
        if showNotice {
            MsgBox(rateRes["error"])
        }
        return Map("ok", 0, "text", "", "error", rateRes["error"], "path", "")
    }

    if wasOverlayVisible {
        UpdateAssistantOverlayStatus("状态：正在截图 | 模型：" modelLabel)
    }
    path := GenerateCapturePath()
    ok := CaptureAssistantScreenSafely(path, wasOverlayVisible)
    if !ok {
        WriteLog("assistant_capture_failed", "capture path=" path)
        if wasOverlayVisible {
            ShowAssistantOverlay(restoreText)
        }
        if wasOverlayVisible {
            UpdateAssistantOverlayStatus("状态：截图失败 | 模型：" modelLabel)
        }
        if showNotice {
            MsgBox("截图失败，请重试。")
        }
        return Map("ok", 0, "text", "", "error", "capture failed", "path", path)
    }

    gCaptureLastPath := path
    try PublishLatestCapture(path)
    WriteLog("assistant_capture", "path=" path)
    if wasOverlayVisible {
        UpdateAssistantOverlayStatus("状态：截图完毕 | 模型：" modelLabel)
    }
    EnterAssistantSensitivePhase("状态：正在分析（0秒） | 模型：" modelLabel)
    StartAssistantThinkingTicker()

    progressCb := ""
    try progressCb := Func("OnAssistantThinkingProgress")

    try {
        res := RequestAssistantAnswerFromImage(path, gAssistantSettings, progressCb)
    } catch as err {
        res := Map("ok", 0, "text", "", "error", err.Message)
    }

    if !IsObject(res) {
        res := Map("ok", 0, "text", "", "error", "assistant response invalid")
    }
    StopAssistantThinkingTicker()
    res["path"] := path
    if !res["ok"] {
        ExitAssistantSensitivePhase(true)
        WriteLog("assistant_answer_failed", "err=" res["error"])
        if gAssistantOverlayVisible {
            SetAssistantOverlayText("模型调用失败：" res["error"])
        } else {
            ShowAssistantOverlay("模型调用失败：" res["error"])
        }
        UpdateAssistantOverlayStatus("状态：调用失败 | 模型：" modelLabel)
        if showNotice {
            MsgBox("模型调用失败：" res["error"])
        }
        return res
    }

    ExitAssistantSensitivePhase(true)
    gAssistantLastResult := res["text"]
    if gAssistantOverlayVisible {
        SetAssistantOverlayText(res["text"])
    } else {
        ShowAssistantOverlay(res["text"])
    }
    UpdateAssistantOverlayStatus("状态：回答完成 | 模型：" modelLabel)
    WriteLog("assistant_answer_show", "chars=" StrLen(res["text"]))
    return res
}

CaptureAssistantScreenSafely(path, restoreAfterCapture := false) {
    global gAssistantOverlayVisible, gAssistantOverlayGui, gAssistantOverlayText, gAssistantOverlayLastStatus
    if !(gAssistantOverlayVisible && IsObject(gAssistantOverlayGui)) {
        return CaptureFullScreen(path)
    }

    mode := GetAssistantCaptureMode()
    if (mode = "enhanced" && CanAssistantKeepVisibleDuringCapture()) {
        visibleReady := ApplyAssistantOverlayCaptureProtection(true, "internal_capture_visible")
        if visibleReady {
            WriteLog("assistant_overlay_capture_mode", "source=internal_capture mode=enhanced_visible")
            return CaptureFullScreen(path)
        }
        WriteLog("assistant_overlay_capture_mode", "source=internal_capture mode=enhanced_visible_failed_rearm")
    }
    if (mode = "enhanced") {
        WriteLog("assistant_overlay_capture_mode", "source=internal_capture mode=enhanced_fallback_hide")
    } else {
        WriteLog("assistant_overlay_capture_mode", "source=internal_capture mode=standard_hide")
    }

    restoreText := ""
    restoreText := GetAssistantOverlayCurrentText()
    if (restoreText = "") {
        restoreText := "截图完成，正在请求回答..."
    }
    restoreStatus := gAssistantOverlayLastStatus

    try gAssistantOverlayGui.Hide()
    gAssistantOverlayVisible := false
    hiddenReady := WaitAssistantOverlayHidden(280)
    if !hiddenReady {
        WriteLog("assistant_overlay_capture_hide_timeout", "source=internal_capture")
    }
    ok := CaptureFullScreen(path)
    Sleep(60)

    if restoreAfterCapture {
        ShowAssistantOverlay(restoreText)
        UpdateAssistantOverlayStatus(restoreStatus)
    }
    return ok
}

EnsureAssistantOverlayGui() {
    global gAssistantOverlayGui, gAssistantOverlayText, gAssistantOverlayTextHint, gAssistantOverlayStatusText
    global gAssistantOverlayCaptureBtn
    global gAppName, gTheme, gAssistantSettings

    if IsObject(gAssistantOverlayGui) {
        return
    }

    ; Keep the overlay non-activating and out of taskbar / Alt-Tab surfaces.
    gAssistantOverlayGui := Gui("+AlwaysOnTop +ToolWindow", gAppName " - Assistant")
    gAssistantOverlayGui.BackColor := gTheme["bg_app"]
    gAssistantOverlayGui.SetFont("s10", "Microsoft YaHei UI")

    title := gAssistantOverlayGui.AddText("x16 y12 w300 h24 c" gTheme["text_primary"], "截图问答助手")
    title.SetFont("s12 w700", "Segoe UI")

    gAssistantOverlayCaptureBtn := gAssistantOverlayGui.AddButton("x332 y18 w170 h28", "截图问答")
    gAssistantOverlayCaptureBtn.OnEvent("Click", OnAssistantOverlayCaptureButton)

    gAssistantOverlayStatusText := gAssistantOverlayGui.AddText("x16 y46 w486 h20 c" gTheme["text_hint"], "状态：待命")

    gAssistantOverlayTextHint := gAssistantOverlayGui.AddText("x330 y88 w172 h14 Right c" gTheme["text_hint"], "Alt+Up / Alt+Down 滚动")
    gAssistantOverlayText := gAssistantOverlayGui.AddText("x16 y104 w486 h342 Border c" gTheme["text_on_light"] " Background" gTheme["bg_header"], "")
    gAssistantOverlayText.SetFont("s10", "Consolas")

    gAssistantOverlayGui.OnEvent("Close", OnAssistantOverlayClose)
    EnsureAssistantOverlayReadonlyMousePolicy()
    EnsureAssistantOverlayProtectionMessageHooks()
    OnMessage(0x0301, AssistantOverlayOnCopyMessage)
    NormalizeAssistantOverlayWindowStyles()
}

ShowAssistantOverlay(answerText) {
    global gAssistantOverlayGui, gAssistantOverlayText
    global gAssistantOverlayVisible, gAssistantSettings, gAssistantOverlayRiskHidden, gAssistantOverlayPlaced, gAssistantOverlayRecordingProtectionActive, gAssistantOverlayAffinityEnabled

    EnsureAssistantOverlayGui()
    ResetAssistantOverlayProtectionStability()
    BeginAssistantOverlayOpenGrace()

    opacity := GetAssistantOverlayEffectiveOpacity()
    SetAssistantOverlayText(answerText)
    needsProtection := ShouldAssistantOverlayProtectionBeActive()
    showOpts := "NA w520 h462"
    if !gAssistantOverlayPlaced {
        x := Max(0, A_ScreenWidth - 540)
        y := 60
        showOpts := "NA x" x " y" y " w520 h462"
    }

    ; Core-first: when recorder exclusion is required, prepare the native window
    ; and apply capture protection before the overlay becomes visible on screen.
    if (!gAssistantOverlayVisible && needsProtection) {
        gAssistantOverlayGui.Show("Hide " showOpts)
        NormalizeAssistantOverlayWindowStyles()
        ApplyAssistantOverlayCaptureProtection(true, "pre_show")
    }

    if gAssistantOverlayVisible {
        gAssistantOverlayGui.Show("NA w520 h462")
    } else if !gAssistantOverlayPlaced {
        gAssistantOverlayGui.Show(showOpts)
        gAssistantOverlayPlaced := true
    } else {
        gAssistantOverlayGui.Show("NA w520 h462")
    }
    gAssistantOverlayVisible := true
    gAssistantOverlayRiskHidden := false
    NormalizeAssistantOverlayWindowStyles()
    RefreshAssistantOverlayWindow()
    if (!gAssistantOverlayAffinityEnabled && !gAssistantOverlayRecordingProtectionActive && opacity < 100) {
        DisableAssistantOverlayCaptureProtection("semi_transparent_show")
    }
    SetAssistantOverlayOpacity(opacity)
    if (needsProtection && !gAssistantOverlayAffinityActive) {
        ApplyAssistantOverlayCaptureProtection(true, "show")
    }
    if (needsProtection) {
        QueueAssistantOverlayProtectionRearm("show")
    }
    StartAssistantOverlayCaptureGuard()
}

SetAssistantOverlayText(answerText) {
    global gAssistantOverlayText, gAssistantOverlayFullText, gAssistantOverlayRenderedLines, gAssistantOverlayScrollOffset
    if !IsObject(gAssistantOverlayText) {
        return
    }
    gAssistantOverlayFullText := FormatAssistantOverlayText(answerText)
    gAssistantOverlayRenderedLines := WrapAssistantOverlayText(gAssistantOverlayFullText)
    gAssistantOverlayScrollOffset := 1
    RenderAssistantOverlayText()
}

UpdateAssistantOverlayStatus(text) {
    global gAssistantOverlayStatusText, gAssistantOverlayLastStatus
    gAssistantOverlayLastStatus := text
    if IsObject(gAssistantOverlayStatusText) {
        gAssistantOverlayStatusText.Text := text
    }
}

OnAssistantThinkingProgress(stage, elapsedSec := 0) {
    global gAssistantThinkingActive, gAssistantThinkingStartTick
    modelLabel := GetAssistantCurrentModelLabel()
    if (stage = "thinking") {
        if (gAssistantThinkingActive && gAssistantThinkingStartTick > 0) {
            elapsedSec := Floor((A_TickCount - gAssistantThinkingStartTick) / 1000)
            elapsedSec := Max(0, elapsedSec)
        }
        UpdateAssistantOverlayStatus("状态：正在分析（" elapsedSec "秒） | 模型：" modelLabel)
    } else if (stage = "request_done") {
        UpdateAssistantOverlayStatus("状态：思考完成，正在整理答案... | 模型：" modelLabel)
    }
}

FormatAssistantOverlayText(answerText) {
    text := answerText
    if (Type(text) != "String") {
        text := "" text
    }

    text := StrReplace(text, "`r`n", "`n")
    text := StrReplace(text, "`r", "`n")

    if (!InStr(text, "`n") && (InStr(text, "\r\n") || InStr(text, "\n"))) {
        text := StrReplace(text, "\r\n", "`n")
        text := StrReplace(text, "\n", "`n")
    }

    text := StrReplace(text, "\t", "    ")
    text := RegExReplace(text, "[ \t]+\n", "`n")
    text := RegExReplace(text, "\n{3,}", "`n`n")
    fence := Chr(96) Chr(96) Chr(96)
    text := RegExReplace(text, fence . "([^\r\n]+)[ \t]+", fence . "$1`n")
    text := RegExReplace(text, "([^\r\n])" . fence, "$1`n" . fence)
    text := RegExReplace(text, "([。；：！？])([^\r\n])", "$1`n$2")
    text := RegExReplace(text, "([)]|\]|】)([-*•\d])", "$1`n$2")
    return text
}

SetAssistantOverlayOpacity(opacity) {
    global gAssistantOverlayGui, gAssistantOverlayLastAppliedOpacity, gAssistantOverlayVisible
    if !IsObject(gAssistantOverlayGui) {
        return
    }

    val := ClampAssistantOpacity(opacity)
    if IsAssistantOverlayProtectionMode() {
        if (gAssistantOverlayLastAppliedOpacity != 100) {
            try WinSetTransparent("Off", "ahk_id " gAssistantOverlayGui.Hwnd)
            gAssistantOverlayLastAppliedOpacity := 100
        }
        return
    }
    if (val = gAssistantOverlayLastAppliedOpacity) {
        return
    }
    if (val >= 100) {
        try WinSetTransparent("Off", "ahk_id " gAssistantOverlayGui.Hwnd)
        gAssistantOverlayLastAppliedOpacity := val
        if gAssistantOverlayVisible {
            RefreshAssistantOverlayWindow(false)
        }
        return
    }

    alpha := Round(val * 255 / 100)
    alpha := Min(255, Max(1, alpha))
    try WinSetTransparent(alpha, "ahk_id " gAssistantOverlayGui.Hwnd)
    gAssistantOverlayLastAppliedOpacity := val
    if gAssistantOverlayVisible {
        SetTimer(AssistantOverlayRefreshAfterOpacityChange, -20)
    }
}

AssistantOverlayRefreshAfterOpacityChange(*) {
    RefreshAssistantOverlayWindow(false)
}

GetAssistantOverlayCurrentDisplayAffinity() {
    global gAssistantOverlayGui
    if !IsObject(gAssistantOverlayGui) {
        return -1
    }
    affinity := 0
    ok := DllCall("user32\GetWindowDisplayAffinity", "Ptr", gAssistantOverlayGui.Hwnd, "UInt*", affinity, "Int")
    if (ok = 0) {
        return -1
    }
    return affinity
}

ApplyAssistantOverlayCaptureProtection(forceReset := false, reason := "") {
    global gAssistantOverlayGui, gAssistantOverlayAffinityEnabled, gAssistantOverlayAffinityActive, gAssistantSettings, gAssistantOverlayLastAppliedOpacity
    global gAssistantOverlayLastProtectionEnsureTick, gAssistantOverlayLastProtectionRearmTick
    if !IsObject(gAssistantOverlayGui) {
        gAssistantOverlayAffinityActive := false
        return false
    }

    hwnd := gAssistantOverlayGui.Hwnd
    if !gAssistantOverlayAffinityEnabled {
        try DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0, "Int")
        gAssistantOverlayAffinityActive := false
        SetAssistantOverlayOpacity(ClampAssistantOpacity(gAssistantSettings["overlay_opacity"]))
        return true
    }

    actualAffinity := GetAssistantOverlayCurrentDisplayAffinity()
    if (!forceReset && actualAffinity = 0x11) {
        gAssistantOverlayAffinityActive := true
        gAssistantOverlayLastProtectionEnsureTick := A_TickCount
        SetAssistantOverlayOpacity(GetAssistantOverlayEffectiveOpacity())
        return true
    }

    ; Protection mode always uses a plain, non-layered window. Avoid repeated
    ; transparency toggles and frame redraws here because they are the main
    ; source of flicker on some Windows setups.
    gAssistantOverlayLastAppliedOpacity := -1
    try WinSetTransparent("Off", "ahk_id " hwnd)
    if forceReset {
        try DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0, "Int")
    }

    wasActive := gAssistantOverlayAffinityActive
    ok := DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0x11, "Int")
    if (ok != 0) {
        gAssistantOverlayAffinityActive := true
        gAssistantOverlayLastProtectionEnsureTick := A_TickCount
        NoteAssistantOverlayProtectionRepairResult(true, reason)
        if forceReset {
            gAssistantOverlayLastProtectionRearmTick := A_TickCount
            WriteLog("assistant_overlay_protect_rearm", "mode=WDA_EXCLUDEFROMCAPTURE reason=" reason)
        }
        if !wasActive {
            WriteLog("assistant_overlay_protect_enabled", "mode=WDA_EXCLUDEFROMCAPTURE")
        }
        SetAssistantOverlayOpacity(100)
        return true
    }

    try DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0, "Int")
    gAssistantOverlayAffinityActive := false
    NoteAssistantOverlayProtectionRepairResult(false, reason != "" ? reason : "apply_failed")
    if forceReset {
        gAssistantOverlayLastProtectionRearmTick := A_TickCount
    }
    if (wasActive || forceReset) {
        WriteLog("assistant_overlay_protect_failed", "mode=WDA_EXCLUDEFROMCAPTURE last_error=" A_LastError)
    }
    SetAssistantOverlayOpacity(GetAssistantOverlayEffectiveOpacity())
    return false
}

OnAssistantOverlayCaptureButton(*) {
    global gAssistantOverlayCaptureBusy
    if gAssistantOverlayCaptureBusy {
        return
    }

    gAssistantOverlayCaptureBusy := true
    WriteLog("assistant_capture_btn_click", "source=overlay_button")
    try {
        ; Use same secure capture pipeline as F1, but no modal popups.
        StartAssistantCaptureFlow(false)
    } finally {
        gAssistantOverlayCaptureBusy := false
    }
}

AssistantOverlayOnCopyMessage(wParam, lParam, msg, hwnd) {
    global gAssistantOverlayText, gAssistantOverlayGui, gAssistantOverlayVisible
    if !IsAssistantOverlayCopyBlocked() {
        return
    }
    if !gAssistantOverlayVisible || !IsObject(gAssistantOverlayGui) || !IsObject(gAssistantOverlayText) {
        return
    }
    if (hwnd = gAssistantOverlayText.Hwnd) {
        WriteLog("assistant_overlay_copy_blocked", "source=wm_copy")
        return 0
    }
}

IsAssistantOverlayMessageTarget(hwnd) {
    global gAssistantOverlayGui
    if !IsObject(gAssistantOverlayGui) || !hwnd {
        return false
    }
    root := DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") ; GA_ROOT
    if !root {
        root := hwnd
    }
    return (root = gAssistantOverlayGui.Hwnd)
}

AssistantOverlayOnMouseActivate(wParam, lParam, msg, hwnd) {
    ; Keep the underlying app focused even when the user clicks overlay controls.
    ; This avoids triggering blur/focus-loss handlers in the target window.
    if !IsAssistantOverlayMessageTarget(hwnd) {
        return
    }
    return 3 ; MA_NOACTIVATE
}

AssistantOverlayOnSetCursor(wParam, lParam, msg, hwnd) {
    global gAssistantOverlayText, gAssistantOverlayVisible
    if !gAssistantOverlayVisible || !IsObject(gAssistantOverlayText) {
        return
    }
    if (wParam = gAssistantOverlayText.Hwnd) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32512, "Ptr"), "Ptr")
        return 1
    }
}

AssistantOverlayOnMouseDown(wParam, lParam, msg, hwnd) {
    global gAssistantOverlayText, gAssistantOverlayVisible
    if !gAssistantOverlayVisible || !IsObject(gAssistantOverlayText) {
        return
    }
    if (hwnd = gAssistantOverlayText.Hwnd) {
        ; 吞掉鼠标点击，阻止文本聚焦与选区。
        return 0
    }
}

OnAssistantOverlayClose(*) {
    global gAssistantOverlayGui, gAssistantOverlayVisible, gAssistantOverlayRiskHidden, gAssistantOverlayInSensitivePhase
    global gAssistantOverlayProtectionRearmPending, gAssistantOverlayProtectionRearmReason, gAssistantOverlayRecordingProtectionActive
    global gAssistantOverlayOpenGraceUntilTick, gAssistantOverlayProtectionGapHidden, gAssistantOverlayEnhancedProtectGapSinceTick
    if IsObject(gAssistantOverlayGui) {
        gAssistantOverlayGui.Hide()
    }
    gAssistantOverlayVisible := false
    gAssistantOverlayRiskHidden := false
    gAssistantOverlayInSensitivePhase := false
    gAssistantOverlayRecordingProtectionActive := false
    gAssistantOverlayProtectionGapHidden := false
    gAssistantOverlayEnhancedProtectGapSinceTick := 0
    gAssistantOverlayProtectionRearmPending := false
    gAssistantOverlayProtectionRearmReason := ""
    gAssistantOverlayOpenGraceUntilTick := 0
    ResetAssistantOverlayProtectionStability()
    StopAssistantOverlayCaptureGuard()
    StopAssistantThinkingTicker()
    try SaveData()
}

AssistantOverlayOnDisplayChange(wParam := 0, lParam := 0, msg := 0, hwnd := 0) {
    QueueAssistantOverlayProtectionRearm("msg_" msg)
}

QueueAssistantOverlayProtectionRearm(reason := "manual") {
    global gAssistantOverlayVisible, gAssistantOverlayAffinityEnabled, gAssistantOverlayRecordingProtectionActive
    global gAssistantOverlayProtectionRearmPending, gAssistantOverlayProtectionRearmReason
    if !gAssistantOverlayVisible || !(gAssistantOverlayAffinityEnabled || gAssistantOverlayRecordingProtectionActive) || !ShouldAssistantOverlayProtectionBeActive() {
        return
    }
    gAssistantOverlayProtectionRearmPending := true
    gAssistantOverlayProtectionRearmReason := reason
    SetTimer(AssistantOverlayPerformProtectionRearm, -GetAssistantOverlayRearmDelayMs(220))
}

AssistantOverlayPerformProtectionRearm(*) {
    global gAssistantOverlayVisible, gAssistantOverlayAffinityEnabled, gAssistantOverlayRecordingProtectionActive
    global gAssistantOverlayProtectionRearmPending, gAssistantOverlayProtectionRearmReason
    if !gAssistantOverlayProtectionRearmPending {
        return
    }
    gAssistantOverlayProtectionRearmPending := false
    if !gAssistantOverlayVisible || !(gAssistantOverlayAffinityEnabled || gAssistantOverlayRecordingProtectionActive) || !ShouldAssistantOverlayProtectionBeActive() {
        return
    }
    if !CanAssistantOverlayAttemptProtectionRepair() {
        gAssistantOverlayProtectionRearmPending := true
        SetTimer(AssistantOverlayPerformProtectionRearm, -GetAssistantOverlayRearmDelayMs(320))
        return
    }
    ApplyAssistantOverlayCaptureProtection(true, gAssistantOverlayProtectionRearmReason)
}

ScrollAssistantOverlay(lines) {
    global gAssistantOverlayVisible, gAssistantOverlayRenderedLines, gAssistantOverlayScrollOffset
    if !gAssistantOverlayVisible || !IsObject(gAssistantOverlayText) {
        return
    }
    visibleLines := GetAssistantOverlayVisibleLineCount()
    maxOffset := Max(1, gAssistantOverlayRenderedLines.Length - visibleLines + 1)
    nextOffset := gAssistantOverlayScrollOffset + Integer(lines)
    gAssistantOverlayScrollOffset := Min(maxOffset, Max(1, nextOffset))
    RenderAssistantOverlayText()
}

AssistantOverlayScrollUp(*) {
    ScrollAssistantOverlay(-4)
}

AssistantOverlayScrollDown(*) {
    ScrollAssistantOverlay(4)
}

TemporarilyHideAssistantOverlay(durationMs := 1200) {
    global gAssistantOverlayGui, gAssistantOverlayVisible, gAssistantOverlayTempHidden, gAssistantOverlayTempRestoreText
    global gAssistantLastResult, gAssistantOverlayLastStatus, gAssistantOverlayRiskRestoreStatus, gAssistantOverlayText, gAssistantOverlayTempRestoreStatus
    global gAssistantOverlayAffinityActive, gAssistantOverlaySecurityFirst
    if (gAssistantOverlayAffinityActive && !gAssistantOverlaySecurityFirst) {
        return
    }
    if !gAssistantOverlayVisible || !IsObject(gAssistantOverlayGui) {
        return
    }

    gAssistantOverlayTempRestoreText := ""
    gAssistantOverlayTempRestoreText := GetAssistantOverlayCurrentText()
    if (Trim(gAssistantOverlayTempRestoreText) = "") {
        gAssistantOverlayTempRestoreText := Trim(gAssistantLastResult)
    }
    if (gAssistantOverlayTempRestoreText = "") {
        gAssistantOverlayTempRestoreText := "问答助手已恢复。"
    }

    try gAssistantOverlayGui.Hide()
    gAssistantOverlayVisible := false
    gAssistantOverlayTempHidden := true
    gAssistantOverlayRiskRestoreStatus := gAssistantOverlayLastStatus
    gAssistantOverlayTempRestoreStatus := gAssistantOverlayLastStatus
    WriteLog("assistant_overlay_temp_hide", "reason=screenshot_guard")
    SetTimer(AssistantOverlayRestoreAfterTempHide, -Abs(Integer(durationMs)))
}

AssistantOverlayRestoreAfterTempHide(*) {
    global gAssistantOverlayTempHidden, gAssistantOverlayTempRestoreText, gAssistantOverlayRiskHidden, gAssistantOverlayRiskRestoreStatus, gAssistantOverlayTempRestoreStatus, gAssistantOverlayAffinityActive
    if !gAssistantOverlayTempHidden {
        return
    }
    if (gAssistantOverlayRiskHidden || (!gAssistantOverlayAffinityActive && IsAssistantCaptureRiskActive())) {
        SetTimer(AssistantOverlayRestoreAfterTempHide, -350)
        return
    }
    gAssistantOverlayTempHidden := false
    ShowAssistantOverlay(gAssistantOverlayTempRestoreText)
    UpdateAssistantOverlayStatus(gAssistantOverlayTempRestoreStatus)
    WriteLog("assistant_overlay_temp_restore", "ok=1")
}

EnterAssistantSensitivePhase(statusText := "") {
    global gAssistantOverlayInSensitivePhase, gAssistantOverlaySensitiveHidden
    global gAssistantOverlayAffinityActive
    gAssistantOverlayInSensitivePhase := true
    if (statusText != "") {
        UpdateAssistantOverlayStatus(statusText)
    }

    ; Keep the overlay locally visible during analysis regardless of affinity state.
    ; Screenshot actions are handled separately by the screenshot guard, while recording
    ; exclusion relies on WDA best effort and must not force local auto-hide.
    gAssistantOverlaySensitiveHidden := false
    if !gAssistantOverlayAffinityActive {
        WriteLog("assistant_overlay_sensitive_visible", "phase=thinking affinity_active=0")
    }
}

ExitAssistantSensitivePhase(restore := true) {
    global gAssistantOverlayInSensitivePhase, gAssistantOverlaySensitiveHidden
    global gAssistantOverlaySensitiveRestoreText, gAssistantOverlaySensitiveRestoreStatus
    global gAssistantOverlayRiskHidden, gAssistantOverlayTempHidden
    gAssistantOverlayInSensitivePhase := false
    if (restore && gAssistantOverlaySensitiveHidden && !gAssistantOverlayRiskHidden && !gAssistantOverlayTempHidden) {
        ShowAssistantOverlay(gAssistantOverlaySensitiveRestoreText)
        UpdateAssistantOverlayStatus(gAssistantOverlaySensitiveRestoreStatus)
        WriteLog("assistant_overlay_sensitive_restore", "phase=thinking_done")
    }
    gAssistantOverlaySensitiveHidden := false
}

StartAssistantOverlayCaptureGuard() {
    global gAssistantOverlayCaptureGuardEnabled, gAssistantOverlayCaptureGuardRunning
    if !gAssistantOverlayCaptureGuardEnabled || gAssistantOverlayCaptureGuardRunning {
        return
    }
    gAssistantOverlayCaptureGuardRunning := true
    SetTimer(CheckAssistantCaptureRisk, 60)
}

StopAssistantOverlayCaptureGuard() {
    global gAssistantOverlayCaptureGuardRunning
    if !gAssistantOverlayCaptureGuardRunning {
        return
    }
    SetTimer(CheckAssistantCaptureRisk, 0)
    gAssistantOverlayCaptureGuardRunning := false
}

StartAssistantThinkingTicker() {
    global gAssistantThinkingActive, gAssistantThinkingStartTick
    gAssistantThinkingStartTick := A_TickCount
    gAssistantThinkingActive := true
    SetTimer(AssistantThinkingTick, 1000)
    AssistantThinkingTick()
}

StopAssistantThinkingTicker() {
    global gAssistantThinkingActive
    if !gAssistantThinkingActive {
        return
    }
    SetTimer(AssistantThinkingTick, 0)
    gAssistantThinkingActive := false
}

AssistantThinkingTick(*) {
    global gAssistantThinkingActive, gAssistantThinkingStartTick, gAssistantOverlayInSensitivePhase
    if !gAssistantThinkingActive || !gAssistantOverlayInSensitivePhase {
        return
    }
    elapsed := Floor((A_TickCount - gAssistantThinkingStartTick) / 1000)
    elapsed := Max(0, elapsed)
    modelLabel := GetAssistantCurrentModelLabel()
    UpdateAssistantOverlayStatus("状态：正在分析（" elapsed "秒） | 模型：" modelLabel)
}

CheckAssistantCaptureRisk(*) {
    global gAssistantOverlayVisible, gAssistantOverlayGui, gAssistantOverlayRiskHidden, gAssistantOverlayRiskRestoreText, gAssistantOverlayRiskRestoreStatus
    global gAssistantOverlayText, gAssistantOverlayLastStatus, gAssistantOverlayInSensitivePhase, gAssistantOverlayTempHidden, gAssistantOverlayAffinityActive, gAssistantOverlayAffinityEnabled
    global gAssistantOverlayRecordingProtectionActive
    global gAssistantOverlayLastProtectionEnsureTick, gAssistantOverlayLastProtectionRearmTick, gAssistantSettings
    global gAssistantOverlayCaptureRiskLastSeenTick
    global gAssistantOverlayProtectionGapHidden, gAssistantOverlayProtectionGapRestoreText, gAssistantOverlayProtectionGapRestoreStatus
    global gAssistantOverlayEnhancedProtectGapSinceTick

    ; Recorder protection is the top priority: when active, keep re-checking WDA
    ; and repair it immediately if Windows drops the capture exclusion.
    if (gAssistantOverlayVisible && (gAssistantOverlayAffinityEnabled || gAssistantOverlayRecordingProtectionActive) && CanAssistantOverlayAttemptProtectionRepair()) {
        actualAffinity := GetAssistantOverlayCurrentDisplayAffinity()
        drifted := (actualAffinity != 0x11)
        needsRepair := drifted || !gAssistantOverlayAffinityActive
        if needsRepair {
            reason := drifted ? "capture_affinity_drift_" actualAffinity : "capture_affinity_inactive"
            if (GetAssistantCaptureMode() = "enhanced" && IsObject(gAssistantOverlayGui)) {
                captureRiskActive := IsAssistantCaptureRiskActive()
                if captureRiskActive {
                    if (gAssistantOverlayEnhancedProtectGapSinceTick <= 0) {
                        gAssistantOverlayEnhancedProtectGapSinceTick := A_TickCount
                    }
                    gAssistantOverlayProtectionGapRestoreText := GetAssistantOverlayCurrentText()
                    gAssistantOverlayProtectionGapRestoreStatus := gAssistantOverlayLastStatus
                    gapElapsed := A_TickCount - gAssistantOverlayEnhancedProtectGapSinceTick
                    shouldGapHide := (!IsAssistantOverlayInOpenGrace() && gapElapsed >= 450)
                    if (shouldGapHide && gAssistantOverlayVisible) {
                        try gAssistantOverlayGui.Hide()
                        gAssistantOverlayVisible := false
                        gAssistantOverlayProtectionGapHidden := true
                        WriteLog("assistant_overlay_protect_gap_hide", "reason=" reason " risk=1")
                    }
                } else {
                    gAssistantOverlayEnhancedProtectGapSinceTick := 0
                    if (gAssistantOverlayProtectionGapHidden && !gAssistantOverlayTempHidden && !gAssistantOverlayRiskHidden) {
                        gAssistantOverlayProtectionGapHidden := false
                        ShowAssistantOverlay(gAssistantOverlayProtectionGapRestoreText)
                        UpdateAssistantOverlayStatus(gAssistantOverlayProtectionGapRestoreStatus)
                        WriteLog("assistant_overlay_protect_gap_restore", "mode=enhanced risk=0")
                    }
                }
            }
            QueueAssistantOverlayProtectionRearm(reason)
        } else if (GetAssistantCaptureMode() = "enhanced" && gAssistantOverlayProtectionGapHidden && !gAssistantOverlayTempHidden && !gAssistantOverlayRiskHidden) {
            gAssistantOverlayEnhancedProtectGapSinceTick := 0
            gAssistantOverlayProtectionGapHidden := false
            ShowAssistantOverlay(gAssistantOverlayProtectionGapRestoreText)
            UpdateAssistantOverlayStatus(gAssistantOverlayProtectionGapRestoreStatus)
            WriteLog("assistant_overlay_protect_gap_restore", "mode=enhanced")
        } else if (GetAssistantCaptureMode() = "enhanced") {
            gAssistantOverlayEnhancedProtectGapSinceTick := 0
        }
    }

    if IsAssistantOverlayInOpenGrace() {
        return
    }

    risk := IsAssistantCaptureRiskActive()
    if (risk && gAssistantOverlayVisible && IsObject(gAssistantOverlayGui)) {
        gAssistantOverlayCaptureRiskLastSeenTick := A_TickCount
        gAssistantOverlayRiskRestoreText := GetAssistantOverlayCurrentText()
        gAssistantOverlayRiskRestoreStatus := gAssistantOverlayLastStatus
        try gAssistantOverlayGui.Hide()
        gAssistantOverlayVisible := false
        gAssistantOverlayRiskHidden := true
        WriteLog("assistant_overlay_risk_hide", "risk=1 mode=" (gAssistantOverlayAffinityActive ? "affinity_active" : "temp_hide"))
        return
    }

    if risk {
        gAssistantOverlayCaptureRiskLastSeenTick := A_TickCount
        return
    }

    if (gAssistantOverlayCaptureRiskLastSeenTick > 0 && (A_TickCount - gAssistantOverlayCaptureRiskLastSeenTick) < 450) {
        return
    }

    if (!risk && gAssistantOverlayRiskHidden && !gAssistantOverlayTempHidden) {
        gAssistantOverlayRiskHidden := false
        ShowAssistantOverlay(gAssistantOverlayRiskRestoreText)
        UpdateAssistantOverlayStatus(gAssistantOverlayRiskRestoreStatus)
        WriteLog("assistant_overlay_risk_restore", "risk=0 mode=" (gAssistantOverlayAffinityActive ? "affinity_restore" : "temp_hide"))
    }
}

IsAssistantCaptureRiskActive() {
    winPressed := GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
    prtPressed := GetKeyState("PrintScreen", "P")
    snipPressed := winPressed && GetKeyState("Shift", "P") && GetKeyState("s", "P")
    qqPressed := GetKeyState("Ctrl", "P") && GetKeyState("Alt", "P") && GetKeyState("a", "P")
    if (prtPressed || snipPressed || qqPressed) {
        return true
    }

    ; Only detect active screenshot actions/windows, avoid persistent false positives.
    if WinActive("ahk_class ScreenClippingHost") || WinActive("ahk_exe SnippingTool.exe") {
        return true
    }
    if WinExist("ahk_class ScreenClippingHost") || WinExist("ahk_exe SnippingTool.exe") {
        return true
    }
    if WinExist("截图和草图") || WinExist("Snipping Tool") {
        return true
    }
    return false
}

GetAssistantOverlayCurrentText() {
    global gAssistantOverlayFullText
    return gAssistantOverlayFullText
}

GetAssistantOverlayVisibleLineCount() {
    ; 486x342 answer area with 10pt Consolas yields about 18-19 comfortable rows.
    return 19
}

RenderAssistantOverlayText() {
    global gAssistantOverlayText, gAssistantOverlayTextHint, gAssistantOverlayRenderedLines, gAssistantOverlayScrollOffset
    if !IsObject(gAssistantOverlayText) {
        return
    }

    if !IsObject(gAssistantOverlayRenderedLines) || (gAssistantOverlayRenderedLines.Length = 0) {
        gAssistantOverlayRenderedLines := [""]
    }

    visibleLines := GetAssistantOverlayVisibleLineCount()
    maxOffset := Max(1, gAssistantOverlayRenderedLines.Length - visibleLines + 1)
    gAssistantOverlayScrollOffset := Min(maxOffset, Max(1, gAssistantOverlayScrollOffset))

    startLine := gAssistantOverlayScrollOffset
    endLine := Min(gAssistantOverlayRenderedLines.Length, startLine + visibleLines - 1)
    lines := []
    Loop endLine - startLine + 1 {
        idx := startLine + A_Index - 1
        lines.Push(gAssistantOverlayRenderedLines[idx])
    }
    gAssistantOverlayText.Text := StrJoin(lines, "`r`n")

    if IsObject(gAssistantOverlayTextHint) {
        if (gAssistantOverlayRenderedLines.Length <= visibleLines) {
            gAssistantOverlayTextHint.Text := ""
        } else {
            gAssistantOverlayTextHint.Text := "第 " startLine "-" endLine " / " gAssistantOverlayRenderedLines.Length " 行"
        }
    }
}

WrapAssistantOverlayText(text) {
    maxUnits := 60
    wrapped := []
    normalized := StrReplace(text, "`r`n", "`n")
    normalized := StrReplace(normalized, "`r", "`n")
    sourceLines := StrSplit(normalized, "`n")
    for rawLine in sourceLines {
        if (rawLine = "") {
            wrapped.Push("")
            continue
        }

        remaining := rawLine
        while (remaining != "") {
            segment := TakeAssistantOverlayLineSegment(remaining, maxUnits)
            if (segment = "") {
                break
            }
            wrapped.Push(segment)
            remaining := SubStr(remaining, StrLen(segment) + 1)
        }
    }

    if (wrapped.Length = 0) {
        wrapped.Push("")
    }
    return wrapped
}

TakeAssistantOverlayLineSegment(text, maxUnits) {
    units := 0
    lastSoftBreak := 0
    Loop Parse, text {
        ch := A_LoopField
        nextUnits := units + GetAssistantOverlayCharUnits(ch)
        if (nextUnits > maxUnits) {
            breakAt := lastSoftBreak > 0 ? lastSoftBreak : A_Index - 1
            if (breakAt < 1) {
                breakAt := 1
            }
            return SubStr(text, 1, breakAt)
        }
        units := nextUnits
        if InStr(" -_/\,.;:!?，。；：、）】])}", ch) {
            lastSoftBreak := A_Index
        }
    }
    return text
}

GetAssistantOverlayCharUnits(ch) {
    code := Ord(ch)
    if (code <= 0x7F) {
        return 1
    }
    return 2
}

ShouldAssistantTempHideForCapture() {
    ; Screenshot rule is unconditional: once a screenshot action starts,
    ; the overlay must hide before pixels are captured.
    return true
}

IsAssistantRecordingRiskActive() {
    ; Best-effort recorder detection helper kept for diagnostics/future use.
    ; Recorder presence alone must NOT hide the overlay: the user should keep seeing it locally,
    ; while WDA_EXCLUDEFROMCAPTURE attempts to keep it out of the recording stream.
    static recorderProcesses := [
        "obs64.exe", "obs32.exe",
        "bdcam.exe", "Bandicam.exe",
        "CamtasiaRecorder.exe", "CamtasiaStudio.exe",
        "SnagitCapture.exe", "SnagitEditor.exe",
        "ScreenRecorder.exe", "ScreenRec.exe",
        "sharex.exe", "ffmpeg.exe",
        "NVIDIA Share.exe", "Action_x64.exe", "XSplit.Core.exe",
        "XboxGameBar.exe", "GameBar.exe", "GameBarFTServer.exe",
        "Captura.exe", "Loom.exe",
        "Zoom.exe", "ms-teams.exe", "Teams.exe", "TencentMeeting.exe", "WeMeetApp.exe",
        "Lark.exe", "DingTalk.exe"
    ]

    for procName in recorderProcesses {
        if ProcessExist(procName) {
            return true
        }
    }

    ; Window title based fallback for recorder apps.
    for key in [
        "OBS", "Bandicam", "Snagit", "Camtasia",
        "Game Bar", "Xbox Game Bar",
        "正在录制", "录制中", "正在共享", "共享屏幕",
        "Screen sharing", "You are sharing"
    ] {
        if WinExist(key) {
            return true
        }
    }

    return false
}

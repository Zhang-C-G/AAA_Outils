; Screenshot assistant runtime overlay

gAssistantOverlayGui := ""
gAssistantOverlayText := ""
gAssistantOverlayOpacitySlider := ""
gAssistantOverlayOpacityLabel := ""
gAssistantOverlayStatusText := ""
gAssistantOverlayVisible := false
gAssistantOverlayTempHidden := false
gAssistantOverlayTempRestoreText := ""
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
; Default ON: prioritize anti-capture / anti-recording.
gAssistantOverlayAffinityEnabled := true
gAssistantOverlayAffinityActive := false
; Security-first fallback: even if WDA is active, still hide on detected capture/record risk.
gAssistantOverlaySecurityFirst := true
gAssistantOverlayTempRestoreStatus := "状态：悬浮窗已恢复"

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

EnsureAssistantOverlayReadonlyMousePolicy() {
    ; 回答区永久禁止鼠标选中与 I-beam 光标，保持纯展示区域体验。
    OnMessage(0x20, AssistantOverlayOnSetCursor)         ; WM_SETCURSOR
    OnMessage(0x201, AssistantOverlayOnMouseDown)        ; WM_LBUTTONDOWN
    OnMessage(0x202, AssistantOverlayOnMouseDown)        ; WM_LBUTTONUP
    OnMessage(0x203, AssistantOverlayOnMouseDown)        ; WM_LBUTTONDBLCLK
    OnMessage(0x204, AssistantOverlayOnMouseDown)        ; WM_RBUTTONDOWN
    OnMessage(0x205, AssistantOverlayOnMouseDown)        ; WM_RBUTTONUP
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
    if gAssistantOverlayVisible {
        SetAssistantOverlayText("准备开始截图问答...`n当前模型：" modelLabel)
    } else {
        ShowAssistantOverlay("准备开始截图问答...`n当前模型：" modelLabel)
    }
    UpdateAssistantOverlayStatus("状态：准备截图 | 模型：" modelLabel)

    rateRes := ConsumeAssistantRateLimit(gAssistantSettings)
    if !rateRes["ok"] {
        WriteLog("assistant_rate_limited", "limit=" rateRes["limit"] " used=" rateRes["used"])
        UpdateAssistantOverlayStatus("状态：限流触发 | 模型：" modelLabel)
        if showNotice {
            MsgBox(rateRes["error"])
        }
        return Map("ok", 0, "text", "", "error", rateRes["error"], "path", "")
    }

    UpdateAssistantOverlayStatus("状态：正在截图 | 模型：" modelLabel)
    path := GenerateCapturePath()
    ok := CaptureAssistantScreenSafely(path)
    if !ok {
        WriteLog("assistant_capture_failed", "capture path=" path)
        UpdateAssistantOverlayStatus("状态：截图失败 | 模型：" modelLabel)
        if showNotice {
            MsgBox("截图失败，请重试。")
        }
        return Map("ok", 0, "text", "", "error", "capture failed", "path", path)
    }

    gCaptureLastPath := path
    try PublishLatestCapture(path)
    WriteLog("assistant_capture", "path=" path)
    UpdateAssistantOverlayStatus("状态：截图完毕 | 模型：" modelLabel)
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

CaptureAssistantScreenSafely(path) {
    global gAssistantOverlayVisible, gAssistantOverlayGui, gAssistantOverlayText, gAssistantOverlayLastStatus, gAssistantOverlayAffinityActive
    if gAssistantOverlayAffinityActive {
        return CaptureFullScreen(path)
    }

    if !(gAssistantOverlayVisible && IsObject(gAssistantOverlayGui)) {
        return CaptureFullScreen(path)
    }

    restoreText := ""
    if IsObject(gAssistantOverlayText) {
        restoreText := gAssistantOverlayText.Value
    }
    if (restoreText = "") {
        restoreText := "截图完成，正在请求回答..."
    }
    restoreStatus := gAssistantOverlayLastStatus

    try gAssistantOverlayGui.Hide()
    gAssistantOverlayVisible := false
    Sleep(70)
    ok := CaptureFullScreen(path)
    Sleep(40)

    ShowAssistantOverlay(restoreText)
    UpdateAssistantOverlayStatus(restoreStatus)
    return ok
}

EnsureAssistantOverlayGui() {
    global gAssistantOverlayGui, gAssistantOverlayText, gAssistantOverlayOpacitySlider, gAssistantOverlayOpacityLabel, gAssistantOverlayStatusText
    global gAppName, gTheme, gAssistantSettings

    if IsObject(gAssistantOverlayGui) {
        return
    }

    ; E0x08000000 = WS_EX_NOACTIVATE, avoid stealing focus / being treated as app switch.
    gAssistantOverlayGui := Gui("+AlwaysOnTop +ToolWindow +E0x08000000", gAppName " - Assistant")
    gAssistantOverlayGui.BackColor := gTheme["bg_app"]
    gAssistantOverlayGui.SetFont("s10", "Microsoft YaHei UI")

    title := gAssistantOverlayGui.AddText("x16 y12 w300 h24 c" gTheme["text_primary"], "截图问答助手")
    title.SetFont("s12 w700", "Segoe UI")

    gAssistantOverlayOpacityLabel := gAssistantOverlayGui.AddText("x330 y16 w160 h20 c" gTheme["text_hint"], "透明度")
    ; Remove slider tooltip bubble to avoid showing numeric popup on hover/drag.
    gAssistantOverlayOpacitySlider := gAssistantOverlayGui.AddSlider("x330 y38 w170 h24 Range35-100", ClampAssistantOpacity(gAssistantSettings["overlay_opacity"]))
    gAssistantOverlayOpacitySlider.OnEvent("Change", OnAssistantOverlayOpacityChanged)

    gAssistantOverlayStatusText := gAssistantOverlayGui.AddText("x16 y46 w486 h20 c" gTheme["text_hint"], "状态：待命")

    gAssistantOverlayText := gAssistantOverlayGui.AddEdit("x16 y76 w486 h370 +Multi ReadOnly +Wrap c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    gAssistantOverlayText.SetFont("s10", "Consolas")

    gAssistantOverlayGui.OnEvent("Close", OnAssistantOverlayClose)
    EnsureAssistantOverlayReadonlyMousePolicy()
    OnMessage(0x0301, AssistantOverlayOnCopyMessage)
}

ShowAssistantOverlay(answerText) {
    global gAssistantOverlayGui, gAssistantOverlayText, gAssistantOverlayOpacitySlider, gAssistantOverlayOpacityLabel
    global gAssistantOverlayVisible, gAssistantSettings, gAssistantOverlayRiskHidden, gAssistantOverlayPlaced

    EnsureAssistantOverlayGui()

    opacity := ClampAssistantOpacity(gAssistantSettings["overlay_opacity"])
    SetAssistantOverlayText(answerText)
    gAssistantOverlayOpacitySlider.Value := opacity
    gAssistantOverlayOpacityLabel.Text := "透明度 " opacity "%"

    if gAssistantOverlayVisible {
        gAssistantOverlayGui.Show("NA w520 h462")
    } else if !gAssistantOverlayPlaced {
        x := Max(0, A_ScreenWidth - 540)
        y := 60
        gAssistantOverlayGui.Show("NA x" x " y" y " w520 h462")
        gAssistantOverlayPlaced := true
    } else {
        gAssistantOverlayGui.Show("NA w520 h462")
    }
    gAssistantOverlayVisible := true
    gAssistantOverlayRiskHidden := false
    SetAssistantOverlayOpacity(opacity)
    ApplyAssistantOverlayCaptureProtection()
    StartAssistantOverlayCaptureGuard()
}

SetAssistantOverlayText(answerText) {
    global gAssistantOverlayText
    if !IsObject(gAssistantOverlayText) {
        return
    }
    gAssistantOverlayText.Value := FormatAssistantOverlayText(answerText)
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
    fence := Chr(96) Chr(96) Chr(96)
    text := RegExReplace(text, fence . "([^\r\n]+)[ \t]+", fence . "$1`n")
    text := RegExReplace(text, "([^\r\n])" . fence, "$1`n" . fence)
    return text
}

SetAssistantOverlayOpacity(opacity) {
    global gAssistantOverlayGui
    if !IsObject(gAssistantOverlayGui) {
        return
    }
    val := ClampAssistantOpacity(opacity)
    if (val >= 100) {
        try WinSetTransparent("Off", "ahk_id " gAssistantOverlayGui.Hwnd)
        return
    }

    alpha := Round(val * 255 / 100)
    alpha := Min(255, Max(1, alpha))
    try WinSetTransparent(alpha, "ahk_id " gAssistantOverlayGui.Hwnd)
}

ApplyAssistantOverlayCaptureProtection() {
    global gAssistantOverlayGui, gAssistantOverlayAffinityEnabled, gAssistantOverlayAffinityActive
    if !IsObject(gAssistantOverlayGui) {
        gAssistantOverlayAffinityActive := false
        return false
    }

    hwnd := gAssistantOverlayGui.Hwnd
    if !gAssistantOverlayAffinityEnabled {
        ; Default OFF to avoid black rectangle artifacts.
        try DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0, "Int")
        gAssistantOverlayAffinityActive := false
        return true
    }

    ; WDA_EXCLUDEFROMCAPTURE (0x11): Windows 10 2004+ best effort.
    ok := DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0x11, "Int")
    if (ok != 0) {
        gAssistantOverlayAffinityActive := true
        WriteLog("assistant_overlay_protect_enabled", "mode=WDA_EXCLUDEFROMCAPTURE")
        return true
    }

    ; Do NOT fallback to WDA_MONITOR to avoid visible black block in captures.
    try DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0, "Int")
    gAssistantOverlayAffinityActive := false
    WriteLog("assistant_overlay_protect_failed", "mode=WDA_EXCLUDEFROMCAPTURE last_error=" A_LastError)
    return false
}

OnAssistantOverlayOpacityChanged(ctrl, *) {
    global gAssistantSettings, gAssistantOverlayOpacityLabel
    val := ClampAssistantOpacity(ctrl.Value)
    gAssistantSettings["overlay_opacity"] := val
    gAssistantOverlayOpacityLabel.Text := "透明度 " val "%"
    SetAssistantOverlayOpacity(val)
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
    if IsObject(gAssistantOverlayGui) {
        gAssistantOverlayGui.Hide()
    }
    gAssistantOverlayVisible := false
    gAssistantOverlayRiskHidden := false
    gAssistantOverlayInSensitivePhase := false
    StopAssistantOverlayCaptureGuard()
    StopAssistantThinkingTicker()
    try SaveData()
}

ScrollAssistantOverlay(lines) {
    global gAssistantOverlayVisible, gAssistantOverlayText
    if !gAssistantOverlayVisible || !IsObject(gAssistantOverlayText) {
        return
    }
    try DllCall("SendMessage", "Ptr", gAssistantOverlayText.Hwnd, "UInt", 0x00B6, "Ptr", 0, "Ptr", Integer(lines), "Ptr")
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
    if IsObject(gAssistantOverlayText) {
        gAssistantOverlayTempRestoreText := gAssistantOverlayText.Value
    }
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
    global gAssistantOverlayGui, gAssistantOverlayVisible, gAssistantOverlayText
    global gAssistantOverlaySensitiveRestoreText, gAssistantOverlaySensitiveRestoreStatus, gAssistantOverlayLastStatus
    gAssistantOverlayInSensitivePhase := true
    if (statusText != "") {
        UpdateAssistantOverlayStatus(statusText)
    }

    gAssistantOverlaySensitiveHidden := false
    if (gAssistantOverlayVisible && IsObject(gAssistantOverlayGui)) {
        gAssistantOverlaySensitiveRestoreText := ""
        if IsObject(gAssistantOverlayText) {
            gAssistantOverlaySensitiveRestoreText := gAssistantOverlayText.Value
        }
        gAssistantOverlaySensitiveRestoreStatus := gAssistantOverlayLastStatus
        try gAssistantOverlayGui.Hide()
        gAssistantOverlayVisible := false
        gAssistantOverlaySensitiveHidden := true
        WriteLog("assistant_overlay_sensitive_hide", "phase=thinking")
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
    SetTimer(CheckAssistantCaptureRisk, 120)
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

    ; Keep re-applying WDA while visible to reduce edge cases where protection gets dropped.
    if (gAssistantOverlayVisible && gAssistantOverlayAffinityEnabled) {
        ApplyAssistantOverlayCaptureProtection()
    }

    risk := IsAssistantCaptureRiskActive()
    if (risk && gAssistantOverlayVisible && IsObject(gAssistantOverlayGui)) {
        gAssistantOverlayRiskRestoreText := ""
        if IsObject(gAssistantOverlayText) {
            gAssistantOverlayRiskRestoreText := gAssistantOverlayText.Value
        }
        gAssistantOverlayRiskRestoreStatus := gAssistantOverlayLastStatus
        try gAssistantOverlayGui.Hide()
        gAssistantOverlayVisible := false
        gAssistantOverlayRiskHidden := true
        WriteLog("assistant_overlay_risk_hide", "risk=1")
        return
    }

    if (!risk && gAssistantOverlayRiskHidden && !gAssistantOverlayTempHidden) {
        gAssistantOverlayRiskHidden := false
        ShowAssistantOverlay(gAssistantOverlayRiskRestoreText)
        UpdateAssistantOverlayStatus(gAssistantOverlayRiskRestoreStatus)
        WriteLog("assistant_overlay_risk_restore", "risk=0 mode=" (gAssistantOverlayAffinityActive ? "affinity" : "temp_hide"))
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

    if IsAssistantRecordingRiskActive() {
        return true
    }

    ; Only detect active clipping windows, avoid persistent false positives.
    if WinActive("ahk_class ScreenClippingHost") || WinActive("ahk_exe SnippingTool.exe") {
        return true
    }
    if WinExist("截图和草图") || WinExist("Snipping Tool") {
        return true
    }
    return false
}

ShouldAssistantTempHideForCapture() {
    global gAssistantOverlayAffinityActive, gAssistantOverlaySecurityFirst
    if gAssistantOverlaySecurityFirst {
        return true
    }
    return !gAssistantOverlayAffinityActive
}

IsAssistantRecordingRiskActive() {
    ; Best-effort recorder detection. If any known recorder is active, hide overlay.
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
        "Zoom.exe", "ms-teams.exe", "Teams.exe", "TencentMeeting.exe", "WeMeetApp.exe", "Lark.exe", "DingTalk.exe"
    ]

    for procName in recorderProcesses {
        if ProcessExist(procName) {
            return true
        }
    }

    ; Window title based fallback for recorder apps.
    for key in ["OBS", "Bandicam", "Snagit", "Camtasia", "Game Bar", "Xbox Game Bar", "正在录制", "录制中", "正在共享", "共享屏幕", "Screen sharing", "You are sharing"] {
        if WinExist(key) {
            return true
        }
    }

    return false
}

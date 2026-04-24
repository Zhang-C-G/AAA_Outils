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
; Default ON: prioritize screenshot protection and keep recorder exclusion enabled.
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
    exStyle := DllCall("user32\GetWindowLongPtr", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr")
    if (exStyle = 0) {
        return
    }
    nextStyle := (exStyle | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW
    if (nextStyle != exStyle) {
        DllCall("user32\SetWindowLongPtr", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr", nextStyle, "Ptr")
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
    restoreText := GetAssistantOverlayCurrentText()
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
    global gAssistantOverlayVisible, gAssistantSettings, gAssistantOverlayRiskHidden, gAssistantOverlayPlaced

    EnsureAssistantOverlayGui()

    opacity := ClampAssistantOpacity(gAssistantSettings["overlay_opacity"])
    SetAssistantOverlayText(answerText)

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
    NormalizeAssistantOverlayWindowStyles()
    RefreshAssistantOverlayWindow()
    SetAssistantOverlayOpacity(opacity)
    QueueAssistantOverlayProtectionRearm("show")
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
        SetAssistantOverlayOpacity(ClampAssistantOpacity(gAssistantSettings["overlay_opacity"]))
        return true
    }

    ; Reset layered transparency before applying WDA. This keeps the overlay locally visible
    ; while avoiding a fragile layered-window + affinity combination.
    gAssistantOverlayLastAppliedOpacity := -1
    try WinSetTransparent("Off", "ahk_id " hwnd)
    if forceReset {
        try DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0, "Int")
        Sleep(20)
    }

    ; WDA_EXCLUDEFROMCAPTURE (0x11): Windows 10 2004+ best effort.
    wasActive := gAssistantOverlayAffinityActive
    ok := DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0x11, "Int")
    if (ok != 0) {
        gAssistantOverlayAffinityActive := true
        gAssistantOverlayLastProtectionEnsureTick := A_TickCount
        if forceReset {
            gAssistantOverlayLastProtectionRearmTick := A_TickCount
            WriteLog("assistant_overlay_protect_rearm", "mode=WDA_EXCLUDEFROMCAPTURE reason=" reason)
        }
        if !wasActive {
            WriteLog("assistant_overlay_protect_enabled", "mode=WDA_EXCLUDEFROMCAPTURE")
        }
        SetAssistantOverlayOpacity(ClampAssistantOpacity(gAssistantSettings["overlay_opacity"]))
        RefreshAssistantOverlayWindow(false)
        return true
    }

    ; Do NOT fallback to WDA_MONITOR to avoid visible black block in captures.
    try DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0, "Int")
    gAssistantOverlayAffinityActive := false
    if forceReset {
        gAssistantOverlayLastProtectionRearmTick := A_TickCount
    }
    if (wasActive || forceReset) {
        WriteLog("assistant_overlay_protect_failed", "mode=WDA_EXCLUDEFROMCAPTURE last_error=" A_LastError)
    }
    SetAssistantOverlayOpacity(ClampAssistantOpacity(gAssistantSettings["overlay_opacity"]))
    RefreshAssistantOverlayWindow(false)
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
    global gAssistantOverlayProtectionRearmPending, gAssistantOverlayProtectionRearmReason
    if IsObject(gAssistantOverlayGui) {
        gAssistantOverlayGui.Hide()
    }
    gAssistantOverlayVisible := false
    gAssistantOverlayRiskHidden := false
    gAssistantOverlayInSensitivePhase := false
    gAssistantOverlayProtectionRearmPending := false
    gAssistantOverlayProtectionRearmReason := ""
    StopAssistantOverlayCaptureGuard()
    StopAssistantThinkingTicker()
    try SaveData()
}

AssistantOverlayOnDisplayChange(wParam := 0, lParam := 0, msg := 0, hwnd := 0) {
    QueueAssistantOverlayProtectionRearm("msg_" msg)
}

QueueAssistantOverlayProtectionRearm(reason := "manual") {
    global gAssistantOverlayVisible, gAssistantOverlayAffinityEnabled
    global gAssistantOverlayProtectionRearmPending, gAssistantOverlayProtectionRearmReason
    if !gAssistantOverlayVisible || !gAssistantOverlayAffinityEnabled {
        return
    }
    gAssistantOverlayProtectionRearmPending := true
    gAssistantOverlayProtectionRearmReason := reason
    SetTimer(AssistantOverlayPerformProtectionRearm, -120)
}

AssistantOverlayPerformProtectionRearm(*) {
    global gAssistantOverlayVisible, gAssistantOverlayAffinityEnabled
    global gAssistantOverlayProtectionRearmPending, gAssistantOverlayProtectionRearmReason
    if !gAssistantOverlayProtectionRearmPending {
        return
    }
    gAssistantOverlayProtectionRearmPending := false
    if !gAssistantOverlayVisible || !gAssistantOverlayAffinityEnabled {
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
    global gAssistantOverlayLastProtectionEnsureTick, gAssistantOverlayLastProtectionRearmTick, gAssistantSettings

    ; Probe actual affinity state instead of blindly spamming SetWindowDisplayAffinity.
    if (gAssistantOverlayVisible && gAssistantOverlayAffinityEnabled) {
        currentOpacity := 100
        try currentOpacity := ClampAssistantOpacity(gAssistantSettings["overlay_opacity"])

        ; Layered transparency + WDA is unstable on some Windows setups.
        ; When using semi-transparent overlay, keep the current protection state and
        ; stop aggressive re-arm loops, otherwise the window may keep flashing.
        if (currentOpacity >= 100) {
            actualAffinity := GetAssistantOverlayCurrentDisplayAffinity()
            drifted := (actualAffinity != 0x11)
            needsRearm := drifted || (A_TickCount - gAssistantOverlayLastProtectionRearmTick) >= 2500
            needsEnsure := drifted || !gAssistantOverlayAffinityActive || (A_TickCount - gAssistantOverlayLastProtectionEnsureTick) >= 900
            if needsRearm {
                reason := drifted ? "affinity_drift_" actualAffinity : "periodic_rearm"
                ApplyAssistantOverlayCaptureProtection(true, reason)
            } else if needsEnsure {
                ApplyAssistantOverlayCaptureProtection(false, "")
            }
        }
    }

    risk := IsAssistantCaptureRiskActive()
    if (risk && gAssistantOverlayVisible && IsObject(gAssistantOverlayGui)) {
        gAssistantOverlayRiskRestoreText := GetAssistantOverlayCurrentText()
        gAssistantOverlayRiskRestoreStatus := gAssistantOverlayLastStatus
        try gAssistantOverlayGui.Hide()
        gAssistantOverlayVisible := false
        gAssistantOverlayRiskHidden := true
        WriteLog("assistant_overlay_risk_hide", "risk=1 mode=" (gAssistantOverlayAffinityActive ? "affinity_active" : "temp_hide"))
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
    global gAssistantOverlayAffinityActive, gAssistantOverlaySecurityFirst
    if gAssistantOverlaySecurityFirst {
        return true
    }
    return !gAssistantOverlayAffinityActive
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

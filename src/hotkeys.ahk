; Hotkey definition and dynamic registration

InitHotkeyDefs() {
    global gHotkeyDefs
    gHotkeyDefs := [
        Map("id", "toggle_panel", "label", "呼出悬浮窗", "default", "!q", "scope", "global"),
        Map("id", "open_config", "label", "打开主界面", "default", "!+q", "scope", "global"),
        Map("id", "assistant_capture", "label", "启动问答悬浮窗", "default", "!+a", "scope", "global"),
        Map("id", "assistant_capture_now", "label", "截图并问答", "default", "F1", "scope", "global"),
        Map("id", "assistant_voice_input", "label", "按住语音输入", "default", "F3", "scope", "global"),
        Map("id", "notes_display_overlay", "label", "启动笔记显示悬浮窗", "default", "F4", "scope", "global"),
        Map("id", "notes_overlay_up", "label", "笔记目录上移", "default", "Up", "scope", "notes_overlay"),
        Map("id", "notes_overlay_down", "label", "笔记目录下移", "default", "Down", "scope", "notes_overlay"),
        Map("id", "assistant_overlay_up", "label", "助手悬浮窗上移", "default", "!Up", "scope", "assistant_overlay"),
        Map("id", "assistant_overlay_down", "label", "助手悬浮窗下移", "default", "!Down", "scope", "assistant_overlay"),
        Map("id", "close_panel", "label", "关闭悬浮窗", "default", "Esc", "scope", "panel"),
        Map("id", "confirm_selection", "label", "确认插入", "default", "Enter", "scope", "panel"),
        Map("id", "move_up", "label", "上移候选", "default", "Up", "scope", "panel"),
        Map("id", "move_down", "label", "下移候选", "default", "Down", "scope", "panel")
    ]
}

PanelHotkeyCondition(*) {
    global gPanelVisible
    return gPanelVisible
}

AssistantOverlayHotkeyCondition(*) {
    global gAssistantOverlayVisible
    return gAssistantOverlayVisible
}

NotesOverlayHotkeyCondition(*) {
    global gNotesOverlayVisible
    return gNotesOverlayVisible
}

ProtectedOverlayHotkeyCondition(*) {
    global gAssistantOverlayVisible, gNotesOverlayVisible
    return gAssistantOverlayVisible || gNotesOverlayVisible
}

RegisterHotkeys() {
    global gHotkeys, gHotkeyDefs, gRegisteredHotkeys
    UnregisterHotkeys()

    for def in gHotkeyDefs {
        id := def["id"]
        key := gHotkeys[id]
        if (key = "") {
            continue
        }

        handler := GetHotkeyHandler(id)
        if !handler {
            continue
        }

        scope := def["scope"]
        if (scope = "panel") {
            HotIf(PanelHotkeyCondition)
        } else if (scope = "assistant_overlay") {
            HotIf(AssistantOverlayHotkeyCondition)
        } else if (scope = "notes_overlay") {
            HotIf(NotesOverlayHotkeyCondition)
        } else {
            HotIf()
        }

        try {
            Hotkey(key, handler, "On")
            gRegisteredHotkeys.Push(Map("key", key, "handler", handler, "scope", def["scope"]))
            if (id = "assistant_voice_input") {
                upKey := key " Up"
                Hotkey(upKey, HotkeyAssistantVoiceInputUp, "On")
                gRegisteredHotkeys.Push(Map("key", upKey, "handler", HotkeyAssistantVoiceInputUp, "scope", def["scope"]))
            }
        } catch as err {
            WriteLog("hotkey_register_failed", "id=" id " key=" key " err=" err.Message)
        }
    }

    RegisterProtectedOverlayCaptureGuardHotkeys()
    HotIf()
}

UnregisterHotkeys() {
    global gRegisteredHotkeys
    for item in gRegisteredHotkeys {
        if (item["scope"] = "panel") {
            HotIf(PanelHotkeyCondition)
        } else if (item["scope"] = "assistant_overlay") {
            HotIf(AssistantOverlayHotkeyCondition)
        } else if (item["scope"] = "notes_overlay") {
            HotIf(NotesOverlayHotkeyCondition)
        } else if (item["scope"] = "protected_overlay") {
            HotIf(ProtectedOverlayHotkeyCondition)
        } else {
            HotIf()
        }
        try Hotkey(item["key"], item["handler"], "Off")
    }
    HotIf()
    gRegisteredHotkeys := []
}

RegisterProtectedOverlayCaptureGuardHotkeys() {
    global gRegisteredHotkeys
    HotIf(ProtectedOverlayHotkeyCondition)
    for keyName in ["PrintScreen", "#+s", "^!a"] {
        try {
            Hotkey(keyName, HotkeyAssistantExternalCaptureGuard, "On")
            gRegisteredHotkeys.Push(Map("key", keyName, "handler", HotkeyAssistantExternalCaptureGuard, "scope", "protected_overlay"))
        }
    }
    HotIf()
}

GetHotkeyHandler(id) {
    switch id {
        case "toggle_panel":
            return HotkeyTogglePanel
        case "open_config":
            return HotkeyShowConfig
        case "assistant_capture":
            return HotkeyAssistantCapture
        case "assistant_capture_now":
            return HotkeyAssistantCaptureNow
        case "assistant_voice_input":
            return HotkeyAssistantVoiceInputDown
        case "notes_display_overlay":
            return HotkeyNotesDisplayOverlay
        case "notes_overlay_up":
            return HotkeyNotesOverlayUp
        case "notes_overlay_down":
            return HotkeyNotesOverlayDown
        case "assistant_overlay_up":
            return HotkeyAssistantOverlayUp
        case "assistant_overlay_down":
            return HotkeyAssistantOverlayDown
        case "close_panel":
            return HotkeyHidePanel
        case "confirm_selection":
            return HotkeyConfirmSelection
        case "move_up":
            return PanelMoveUp
        case "move_down":
            return PanelMoveDown
    }
    return ""
}

HotkeyTogglePanel(*) {
    TogglePanel()
}

HotkeyShowConfig(*) {
    ShowConfigWindow()
}

HotkeyAssistantCapture(*) {
    StartAssistantOverlayOnly()
}

HotkeyAssistantCaptureNow(*) {
    StartAssistantCaptureFlow()
}

HotkeyAssistantVoiceInputDown(*) {
    StartAssistantVoiceInputHold(false)
}

HotkeyAssistantVoiceInputUp(*) {
    StopAssistantVoiceInputHold(false)
}

HotkeyNotesDisplayOverlay(*) {
    ToggleNotesDisplayOverlay(false)
}

HotkeyNotesOverlayUp(*) {
    NotesOverlayMoveSelection(-1)
}

HotkeyNotesOverlayDown(*) {
    NotesOverlayMoveSelection(1)
}

HotkeyAssistantOverlayUp(*) {
    AssistantOverlayScrollUp()
}

HotkeyAssistantOverlayDown(*) {
    AssistantOverlayScrollDown()
}

HotkeyAssistantExternalCaptureGuard(*) {
    hk := A_ThisHotkey
    useTempHide := true
    try useTempHide := ShouldAssistantTempHideForCapture()
    if useTempHide {
        try {
            if IsNotesOverlayVisible() {
                TemporarilyHideNotesOverlay(1800)
            }
        }
        try {
            if gAssistantOverlayVisible {
                TemporarilyHideAssistantOverlay(1800)
            }
        }
        Sleep(90)
    }

    if (hk = "PrintScreen") {
        Send("{PrintScreen}")
    } else if (hk = "#+s") {
        Send("#+s")
    } else if (hk = "^!a") {
        Send("^!a")
    } else {
        Send("{PrintScreen}")
    }
    WriteLog("assistant_overlay_guard_forward", "hotkey=" hk " mode=" (useTempHide ? "temp_hide" : "affinity_visible"))
}

HotkeyHidePanel(*) {
    HidePanel()
}

HotkeyConfirmSelection(*) {
    UseCurrentSelection()
}

PanelMoveUp(*) {
    MoveListSelection(-1)
}

PanelMoveDown(*) {
    MoveListSelection(1)
}

; Notes display overlay

gNotesOverlayGui := ""
gNotesOverlayVisible := false
gNotesOverlayPlaced := false
gNotesOverlayTocList := ""
gNotesOverlayContentEdit := ""
gNotesOverlayCurrentNoteId := ""
gNotesOverlayCurrentTitle := ""
gNotesOverlayCurrentContent := ""
gNotesOverlayCurrentToc := []
gNotesOverlayTocLineMap := []
gNotesOverlayAffinityActive := false
gNotesOverlayLastAppliedAffinity := 0
gNotesOverlayTempHidden := false
gNotesOverlayTempRestoreMs := 0
gNotesOverlayTempRestoreToken := 0
gNotesOverlayProtectionGuardRunning := false
gNotesOverlayManualCloseLock := false
gNotesOverlayAutoRestoreEnabled := false

WriteNotesOverlayStateLog(action, details := "") {
    global gNotesOverlayVisible, gNotesOverlayTempHidden, gNotesOverlayTempRestoreMs
    global gNotesOverlayTempRestoreToken, gNotesOverlayProtectionGuardRunning
    global gNotesOverlayManualCloseLock, gNotesOverlayAutoRestoreEnabled
    global gNotesOverlayAffinityActive, gNotesOverlayCurrentNoteId

    snapshot := "visible=" (gNotesOverlayVisible ? 1 : 0)
        . " temp_hidden=" (gNotesOverlayTempHidden ? 1 : 0)
        . " restore_ms=" Integer(gNotesOverlayTempRestoreMs)
        . " restore_token=" Integer(gNotesOverlayTempRestoreToken)
        . " guard=" (gNotesOverlayProtectionGuardRunning ? 1 : 0)
        . " manual_lock=" (gNotesOverlayManualCloseLock ? 1 : 0)
        . " auto_restore=" (gNotesOverlayAutoRestoreEnabled ? 1 : 0)
        . " affinity=" (gNotesOverlayAffinityActive ? 1 : 0)
        . " note_id=" Trim(gNotesOverlayCurrentNoteId)
    if (details != "") {
        snapshot .= " " details
    }
    WriteLog(action, snapshot)
}

ToggleNotesDisplayOverlay(showNotice := true) {
    global gNotesOverlayVisible, gNotesOverlayManualCloseLock
    if gNotesOverlayVisible {
        gNotesOverlayManualCloseLock := true
        HideNotesDisplayOverlay()
        return Map("ok", 1, "hidden", 1)
    }
    gNotesOverlayManualCloseLock := false
    return StartNotesDisplayOverlay(showNotice)
}

StartNotesDisplayOverlay(showNotice := true) {
    global gNotesOverlayManualCloseLock
    gNotesOverlayManualCloseLock := false
    EnsureNotesOverlayGui()
    note := LoadLatestNoteForOverlay()
    if !IsObject(note) || Trim(note["id"]) = "" {
        msg := "No note is available to display."
        if showNotice {
            MsgBox(msg)
        }
        return Map("ok", 0, "error", msg)
    }

    ShowNotesDisplayOverlay(note)
    WriteNotesOverlayStateLog("notes_overlay_open", "id=" note["id"])
    return Map("ok", 1, "id", note["id"], "title", note["title"])
}

DisposeNotesOverlayGui() {
    global gNotesOverlayGui, gNotesOverlayTocList, gNotesOverlayContentEdit
    if IsObject(gNotesOverlayGui) {
        try gNotesOverlayGui.Destroy()
    }
    gNotesOverlayGui := ""
    gNotesOverlayTocList := ""
    gNotesOverlayContentEdit := ""
}

HideNotesDisplayOverlay() {
    global gNotesOverlayGui, gNotesOverlayVisible, gNotesOverlayTempHidden
    CancelNotesOverlayTempRestore()
    SaveNotesOverlayWindowPlacement()
    if IsObject(gNotesOverlayGui) {
        try gNotesOverlayGui.Hide()
    }
    gNotesOverlayVisible := false
    gNotesOverlayTempHidden := false
    StopNotesOverlayProtectionGuard()
    DisableNotesOverlayCaptureProtection("hide")
    DisposeNotesOverlayGui()
    WriteNotesOverlayStateLog("notes_overlay_hide", "")
}

LoadLatestNoteForOverlay() {
    notes := LoadNotesDisplayMeta()
    if (notes.Length = 0) {
        return Map("id", "", "title", "Untitled", "content", "")
    }
    latest := notes[1]
    return LoadNotesDisplayNote(latest["id"])
}

ShowNotesDisplayOverlay(note) {
    global gNotesOverlayVisible, gNotesOverlayPlaced, gNotesOverlayManualCloseLock
    global gNotesOverlayCurrentNoteId, gNotesOverlayCurrentTitle, gNotesOverlayCurrentContent

    gNotesOverlayManualCloseLock := false
    EnsureNotesOverlayGui()
    parsed := BuildNotesOverlayDocument(note)
    gNotesOverlayCurrentNoteId := note["id"]
    gNotesOverlayCurrentTitle := parsed["title"]
    gNotesOverlayCurrentContent := parsed["display_text"]

    SetNotesOverlayDocument(parsed)
    showOpts := GetNotesOverlayShowOptions()

    NormalizeNotesOverlayWindowStyles()
    EnableNotesOverlayCaptureProtection("pre_show")

    if gNotesOverlayVisible {
        gNotesOverlayGui.Show("NA w700 h500")
    } else {
        gNotesOverlayGui.Show(showOpts)
        gNotesOverlayPlaced := true
    }

    gNotesOverlayVisible := true
    NormalizeNotesOverlayWindowStyles()
    EnableNotesOverlayCaptureProtection("show")
    StartNotesOverlayProtectionGuard()
    WriteNotesOverlayStateLog("notes_overlay_show", "placed=" (gNotesOverlayPlaced ? 1 : 0))
}

EnsureNotesOverlayGui() {
    global gNotesOverlayGui
    global gNotesOverlayTocList, gNotesOverlayContentEdit, gAppName, gTheme

    if IsObject(gNotesOverlayGui) {
        return
    }

    gNotesOverlayGui := Gui("+AlwaysOnTop +ToolWindow", gAppName " - Notes Overlay")
    gNotesOverlayGui.BackColor := gTheme["bg_app"]
    gNotesOverlayGui.SetFont("s10", "Microsoft YaHei UI")

    gNotesOverlayTocList := gNotesOverlayGui.AddListBox("x16 y16 w180 h454 AltSubmit")
    gNotesOverlayTocList.OnEvent("Change", NotesOverlayOnTocChange)

    gNotesOverlayContentEdit := gNotesOverlayGui.AddEdit("x208 y16 w476 h454 +Multi ReadOnly -VScroll c" gTheme["text_on_light"] " Background" gTheme["bg_header"], "")
    gNotesOverlayContentEdit.SetFont("s10", "Consolas")

    gNotesOverlayGui.OnEvent("Close", OnNotesOverlayClose)
}

GetNotesOverlayShowOptions() {
    global gAppSettings, gNotesOverlayPlaced

    width := 700
    height := 500
    hasSavedX := gAppSettings.Has("notes_overlay_x") && gAppSettings["notes_overlay_x"] != ""
    hasSavedY := gAppSettings.Has("notes_overlay_y") && gAppSettings["notes_overlay_y"] != ""

    if (hasSavedX && hasSavedY) {
        x := Integer(gAppSettings["notes_overlay_x"])
        y := Integer(gAppSettings["notes_overlay_y"])
        x := Max(0, Min(x, Max(0, A_ScreenWidth - width)))
        y := Max(0, Min(y, Max(0, A_ScreenHeight - height)))
        gNotesOverlayPlaced := true
        return "NA x" x " y" y " w" width " h" height
    }

    x := Max(0, A_ScreenWidth - 730)
    y := 80
    return "NA x" x " y" y " w" width " h" height
}

SaveNotesOverlayWindowPlacement(forceSave := false) {
    global gNotesOverlayGui, gAppSettings, gNotesOverlayPlaced
    if !IsObject(gNotesOverlayGui) {
        return false
    }

    try WinGetPos(&x, &y, &w, &h, "ahk_id " gNotesOverlayGui.Hwnd)
    catch {
        return false
    }

    if (w <= 0 || h <= 0) {
        return false
    }

    nextX := Integer(x)
    nextY := Integer(y)
    prevX := gAppSettings.Has("notes_overlay_x") ? gAppSettings["notes_overlay_x"] : ""
    prevY := gAppSettings.Has("notes_overlay_y") ? gAppSettings["notes_overlay_y"] : ""

    gAppSettings["notes_overlay_x"] := nextX
    gAppSettings["notes_overlay_y"] := nextY
    gNotesOverlayPlaced := true

    if forceSave || (prevX != nextX || prevY != nextY) {
        SaveData()
        WriteNotesOverlayStateLog("notes_overlay_position_saved", "x=" nextX " y=" nextY)
    }
    return true
}

BuildNotesOverlayDocument(note) {
    title := Trim(note["title"])
    content := note["content"]
    lines := StrSplit(StrReplace(StrReplace(content, "`r`n", "`n"), "`r", "`n"), "`n")
    displayLines := []
    toc := []
    inFence := false
    h1Found := false

    for rawLine in lines {
        line := rawLine
        trimmed := Trim(line)

        if (SubStr(trimmed, 1, 3) = Chr(96) Chr(96) Chr(96)) {
            inFence := !inFence
            displayLines.Push(Chr(96) Chr(96) Chr(96))
            continue
        }

        if !inFence && RegExMatch(trimmed, "^(#{1,6})\s+(.+)$", &m) {
            level := StrLen(m[1])
            headingText := Trim(m[2])
            if (!h1Found && level = 1 && headingText != "") {
                title := headingText
                h1Found := true
            }
            if (displayLines.Length > 0 && Trim(displayLines[displayLines.Length]) != "") {
                displayLines.Push("")
            }
            lineNo := displayLines.Length + 1
            displayLines.Push(headingText)
            displayLines.Push(FormatNotesOverlayUnderline(headingText, level))
            displayLines.Push("")
            toc.Push(Map("label", FormatNotesOverlayTocLabel(headingText, level), "line", lineNo))
            continue
        }

        displayLines.Push(FormatNotesOverlayLine(line, inFence))
    }

    displayText := StrJoin(displayLines, "`r`n")
    if (Trim(title) = "") {
        title := "Untitled"
    }
    return Map(
        "title", title,
        "display_text", displayText,
        "toc", toc
    )
}

FormatNotesOverlayUnderline(text, level) {
    width := Max(8, Min(48, StrLen(text) + 2))
    ch := (level = 1) ? "=" : "-"
    out := ""
    loop width {
        out .= ch
    }
    return out
}

FormatNotesOverlayTocLabel(text, level) {
    indent := ""
    loop Max(0, level - 1) {
        indent .= "  "
    }
    return indent text
}

FormatNotesOverlayLine(line, inFence := false) {
    if inFence {
        return line
    }
    out := StrReplace(line, "**", "")
    out := StrReplace(out, "__", "")
    out := StrReplace(out, "`t", "    ")
    return out
}

SetNotesOverlayDocument(parsed) {
    global gNotesOverlayContentEdit, gNotesOverlayTocList
    global gNotesOverlayCurrentToc, gNotesOverlayTocLineMap

    if IsObject(gNotesOverlayContentEdit) {
        gNotesOverlayContentEdit.Value := parsed["display_text"]
    }

    gNotesOverlayCurrentToc := parsed["toc"]
    gNotesOverlayTocLineMap := []

    if IsObject(gNotesOverlayTocList) {
        gNotesOverlayTocList.Delete()
        if (parsed["toc"].Length = 0) {
            gNotesOverlayTocList.Add(["(No outline)"])
            gNotesOverlayTocLineMap.Push(1)
            gNotesOverlayTocList.Choose(1)
            return
        }

        labels := []
        for item in parsed["toc"] {
            labels.Push(item["label"])
            gNotesOverlayTocLineMap.Push(item["line"])
        }
        gNotesOverlayTocList.Add(labels)
        gNotesOverlayTocList.Choose(1)
    }
}

NotesOverlayOnTocChange(ctrl, *) {
    global gNotesOverlayTocLineMap, gNotesOverlayContentEdit
    if !IsObject(gNotesOverlayContentEdit) {
        return
    }
    index := ctrl.Value
    if !(index >= 1 && index <= gNotesOverlayTocLineMap.Length) {
        return
    }
    targetLine := Max(1, Integer(gNotesOverlayTocLineMap[index]))
    ScrollNotesOverlayContentToLine(targetLine)
}

NotesOverlayMoveSelection(delta) {
    global gNotesOverlayTocList, gNotesOverlayTocLineMap
    if !IsObject(gNotesOverlayTocList) {
        return
    }

    count := gNotesOverlayTocLineMap.Length
    if (count <= 0) {
        return
    }

    currentIndex := Integer(gNotesOverlayTocList.Value)
    if !(currentIndex >= 1 && currentIndex <= count) {
        currentIndex := 1
    }

    nextIndex := currentIndex + Integer(delta)
    if (nextIndex < 1) {
        nextIndex := 1
    } else if (nextIndex > count) {
        nextIndex := count
    }

    NotesOverlaySelectTocIndex(nextIndex)
}

NotesOverlaySelectTocIndex(index) {
    global gNotesOverlayTocList, gNotesOverlayTocLineMap
    if !IsObject(gNotesOverlayTocList) {
        return
    }
    if !(index >= 1 && index <= gNotesOverlayTocLineMap.Length) {
        return
    }

    gNotesOverlayTocList.Choose(index)
    targetLine := Max(1, Integer(gNotesOverlayTocLineMap[index]))
    ScrollNotesOverlayContentToLine(targetLine)
}

ScrollNotesOverlayContentToLine(targetLine) {
    global gNotesOverlayContentEdit
    if !IsObject(gNotesOverlayContentEdit) {
        return
    }
    firstVisible := SendMessage(0x00CE, 0, 0, , "ahk_id " gNotesOverlayContentEdit.Hwnd)
    delta := (targetLine - 1) - firstVisible
    SendMessage(0x00B6, 0, delta, , "ahk_id " gNotesOverlayContentEdit.Hwnd)
}

NormalizeNotesOverlayWindowStyles() {
    global gNotesOverlayGui
    if !IsObject(gNotesOverlayGui) {
        return
    }

    hwnd := gNotesOverlayGui.Hwnd
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
        DllCall(
            "user32\SetWindowPos",
            "Ptr", hwnd,
            "Ptr", 0,
            "Int", 0,
            "Int", 0,
            "Int", 0,
            "Int", 0,
            "UInt", 0x0001 | 0x0002 | 0x0004 | 0x0010 | 0x0020,
            "Int"
        )
    }
}

EnableNotesOverlayCaptureProtection(reason := "") {
    global gNotesOverlayGui, gNotesOverlayAffinityActive, gNotesOverlayLastAppliedAffinity
    if !IsObject(gNotesOverlayGui) {
        return false
    }
    hwnd := gNotesOverlayGui.Hwnd
    ok := DllCall("user32\SetWindowDisplayAffinity", "Ptr", hwnd, "UInt", 0x11, "Int")
    gNotesOverlayAffinityActive := (ok != 0)
    gNotesOverlayLastAppliedAffinity := gNotesOverlayAffinityActive ? 0x11 : 0
    if gNotesOverlayAffinityActive {
        WriteNotesOverlayStateLog("notes_overlay_protect_on", "reason=" reason)
    } else {
        WriteNotesOverlayStateLog("notes_overlay_protect_failed", "reason=" reason " last_error=" A_LastError)
    }
    return gNotesOverlayAffinityActive
}

GetNotesOverlayCurrentDisplayAffinity() {
    global gNotesOverlayGui
    if !IsObject(gNotesOverlayGui) {
        return 0
    }
    affinity := 0
    ok := DllCall("user32\GetWindowDisplayAffinity", "Ptr", gNotesOverlayGui.Hwnd, "UInt*", &affinity, "Int")
    if (ok = 0) {
        return 0
    }
    return affinity
}

DisableNotesOverlayCaptureProtection(reason := "") {
    global gNotesOverlayGui, gNotesOverlayAffinityActive, gNotesOverlayLastAppliedAffinity
    if !IsObject(gNotesOverlayGui) {
        gNotesOverlayAffinityActive := false
        gNotesOverlayLastAppliedAffinity := 0
        return
    }
    try DllCall("user32\SetWindowDisplayAffinity", "Ptr", gNotesOverlayGui.Hwnd, "UInt", 0, "Int")
    gNotesOverlayAffinityActive := false
    gNotesOverlayLastAppliedAffinity := 0
    if (reason != "") {
        WriteNotesOverlayStateLog("notes_overlay_protect_off", "reason=" reason)
    }
}

IsNotesOverlayVisible() {
    global gNotesOverlayVisible
    return gNotesOverlayVisible
}

TemporarilyHideNotesOverlay(durationMs := 1800) {
    global gNotesOverlayGui, gNotesOverlayVisible, gNotesOverlayTempHidden, gNotesOverlayTempRestoreMs, gNotesOverlayTempRestoreToken
    global gNotesOverlayAutoRestoreEnabled
    if !gNotesOverlayVisible || !IsObject(gNotesOverlayGui) {
        return false
    }
    try gNotesOverlayGui.Hide()
    gNotesOverlayVisible := false
    gNotesOverlayTempHidden := true
    gNotesOverlayTempRestoreMs := Max(300, Abs(Integer(durationMs)))
    gNotesOverlayTempRestoreToken := 0
    gNotesOverlayAutoRestoreEnabled := false
    WriteNotesOverlayStateLog("notes_overlay_temp_hide", "duration_ms=" gNotesOverlayTempRestoreMs " auto_restore=off")
    return true
}

NotesOverlayRestoreAfterTempHide(*) {
    global gNotesOverlayTempHidden, gNotesOverlayTempRestoreToken, gNotesOverlayManualCloseLock, gNotesOverlayAutoRestoreEnabled
    currentToken := gNotesOverlayTempRestoreToken
    if !gNotesOverlayTempHidden {
        return
    }
    if !gNotesOverlayAutoRestoreEnabled {
        CancelNotesOverlayTempRestore()
        WriteNotesOverlayStateLog("notes_overlay_temp_restore_blocked", "source=timer reason=auto_restore_disabled")
        return
    }
    if (currentToken <= 0) {
        return
    }
    if gNotesOverlayManualCloseLock {
        CancelNotesOverlayTempRestore()
        WriteNotesOverlayStateLog("notes_overlay_temp_restore_blocked", "source=timer reason=manual_close_lock")
        return
    }
    gNotesOverlayTempHidden := false
    gNotesOverlayTempRestoreToken := 0
    ShowNotesOverlayFromCache()
    WriteNotesOverlayStateLog("notes_overlay_temp_restore", "source=timer")
}

HideNotesOverlayForCapture() {
    global gNotesOverlayGui, gNotesOverlayVisible, gNotesOverlayTempHidden
    if !gNotesOverlayVisible || !IsObject(gNotesOverlayGui) {
        return false
    }
    SaveNotesOverlayWindowPlacement()
    try gNotesOverlayGui.Hide()
    gNotesOverlayVisible := false
    gNotesOverlayTempHidden := false
    DisposeNotesOverlayGui()
    return true
}

RestoreNotesOverlayAfterCapture(wasHidden) {
    global gNotesOverlayManualCloseLock, gNotesOverlayAutoRestoreEnabled
    if !wasHidden {
        return
    }
    if !gNotesOverlayAutoRestoreEnabled {
        WriteNotesOverlayStateLog("notes_overlay_capture_restore_blocked", "reason=auto_restore_disabled")
        return
    }
    if gNotesOverlayManualCloseLock {
        WriteNotesOverlayStateLog("notes_overlay_capture_restore_blocked", "reason=manual_close_lock")
        return
    }
    ShowNotesOverlayFromCache()
}

CancelNotesOverlayTempRestore() {
    global gNotesOverlayTempHidden, gNotesOverlayTempRestoreMs, gNotesOverlayTempRestoreToken, gNotesOverlayAutoRestoreEnabled
    gNotesOverlayTempHidden := false
    gNotesOverlayTempRestoreMs := 0
    gNotesOverlayTempRestoreToken := 0
    gNotesOverlayAutoRestoreEnabled := false
    SetTimer(NotesOverlayRestoreAfterTempHide, 0)
}

ShowNotesOverlayFromCache() {
    global gNotesOverlayCurrentNoteId, gNotesOverlayManualCloseLock
    if gNotesOverlayManualCloseLock {
        WriteNotesOverlayStateLog("notes_overlay_restore_blocked", "reason=manual_close_lock")
        return
    }
    if (Trim(gNotesOverlayCurrentNoteId) = "") {
        note := LoadLatestNoteForOverlay()
    } else {
        note := LoadNotesDisplayNote(gNotesOverlayCurrentNoteId)
    }
    if IsObject(note) {
        ShowNotesDisplayOverlay(note)
    }
}

OnNotesOverlayClose(*) {
    global gNotesOverlayManualCloseLock
    gNotesOverlayManualCloseLock := true
    HideNotesDisplayOverlay()
    WriteNotesOverlayStateLog("notes_overlay_close", "source=close_event")
}

StartNotesOverlayProtectionGuard() {
    global gNotesOverlayProtectionGuardRunning
    if gNotesOverlayProtectionGuardRunning {
        return
    }
    gNotesOverlayProtectionGuardRunning := true
    SetTimer(NotesOverlayProtectionGuardTick, 1200)
}

StopNotesOverlayProtectionGuard() {
    global gNotesOverlayProtectionGuardRunning
    if !gNotesOverlayProtectionGuardRunning {
        return
    }
    gNotesOverlayProtectionGuardRunning := false
    SetTimer(NotesOverlayProtectionGuardTick, 0)
}

NotesOverlayProtectionGuardTick(*) {
    global gNotesOverlayProtectionGuardRunning, gNotesOverlayVisible
    if !gNotesOverlayProtectionGuardRunning || !gNotesOverlayVisible {
        return
    }
    if (GetNotesOverlayCurrentDisplayAffinity() != 0x11) {
        EnableNotesOverlayCaptureProtection("guard_rearm")
    }
}

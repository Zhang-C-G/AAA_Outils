; Config submodule: hotkey + behavior editors and handlers

BuildHotkeyEditor(guiObj, x, y) {
    global gHotkeyDefs, gTheme

    guiObj.AddText("x" x " y" (y - 24) " h20 c" gTheme["text_primary"], "自定义快捷键（保存后立即生效）")
    guiObj.AddText("x" x " y" (y + 4) " h20 c" gTheme["text_hint"], "格式示例：Alt+Q, Alt+Shift+Q, Ctrl+J, Win+K")

    rowY := y + 40
    for def in gHotkeyDefs {
        id := def["id"]
        label := def["label"]
        guiObj.AddText("x" x " y" rowY " w220 h22 c" gTheme["text_primary"], label)
        guiObj.AddEdit("x" (x + 220) " y" (rowY - 4) " w180 h28 vHK_" id " c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
        guiObj.AddText("x" (x + 420) " y" rowY " w260 h22 c" gTheme["text_hint"], "默认：" HotkeyToFriendly(def["default"]))
        rowY += 44
    }

    resetBtn := guiObj.AddButton("x" x " y" (rowY + 8) " w220 h34 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "一键恢复默认快捷键")
    resetBtn.SetFont("s10 w700", "Segoe UI")
    resetBtn.OnEvent("Click", OnResetDefaultHotkeys)
}

BuildBehaviorEditor(guiObj, x, y) {
    global gTheme

    guiObj.AddText("x" x " y" (y - 24) " h20 c" gTheme["text_primary"], "默认展示自动更新策略")
    guiObj.AddText("x" x " y" (y + 4) " h20 c" gTheme["text_hint"], "支持按使用次数触发刷新，或按分钟定时刷新。")

    guiObj.AddCheckBox("x" x " y" (y + 40) " vBH_AutoEnabled c" gTheme["text_primary"], "启用自动刷新默认展示")
    guiObj.AddText("x" x " y" (y + 86) " w220 h22 c" gTheme["text_primary"], "每使用多少次后刷新")
    guiObj.AddEdit("x" (x + 220) " y" (y + 82) " w120 h28 vBH_Uses c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    guiObj.AddText("x" (x + 350) " y" (y + 86) " w80 h22 c" gTheme["text_hint"], "次")

    guiObj.AddText("x" x " y" (y + 132) " w220 h22 c" gTheme["text_primary"], "每隔多少分钟刷新")
    guiObj.AddEdit("x" (x + 220) " y" (y + 128) " w120 h28 vBH_Minutes c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    guiObj.AddText("x" (x + 350) " y" (y + 132) " w80 h22 c" gTheme["text_hint"], "分钟")

    resetBtn := guiObj.AddButton("x" x " y" (y + 188) " w240 h34 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "恢复默认策略")
    resetBtn.SetFont("s10 w700", "Segoe UI")
    resetBtn.OnEvent("Click", OnResetDefaultBehavior)
}

ReloadHotkeyInputs() {
    global gConfigGui, gHotkeys, gHotkeyDefs
    for def in gHotkeyDefs {
        id := def["id"]
        ctrl := gConfigGui["HK_" id]
        ctrl.Value := HotkeyToFriendly(gHotkeys[id])
    }
}

ReadHotkeysFromGui() {
    global gConfigGui, gHotkeys, gHotkeyDefs
    seen := Map()

    for def in gHotkeyDefs {
        id := def["id"]
        key := HotkeyFromFriendly(gConfigGui["HK_" id].Value)
        if (key = "") {
            MsgBox("快捷键不能为空：" def["label"])
            return false
        }
        if seen.Has(key) {
            MsgBox("快捷键重复冲突：" key)
            return false
        }
        seen[key] := true
        gHotkeys[id] := key
    }

    return true
}

ReloadBehaviorInputs() {
    global gConfigGui, gBehavior
    gConfigGui["BH_AutoEnabled"].Value := gBehavior["auto_refresh_enabled"]
    gConfigGui["BH_Uses"].Value := gBehavior["refresh_every_uses"]
    gConfigGui["BH_Minutes"].Value := gBehavior["refresh_every_minutes"]
}

ReadBehaviorFromGui() {
    global gConfigGui, gBehavior
    enabled := gConfigGui["BH_AutoEnabled"].Value ? 1 : 0
    usesRaw := Trim(gConfigGui["BH_Uses"].Value)
    minsRaw := Trim(gConfigGui["BH_Minutes"].Value)

    if !RegExMatch(usesRaw, "^\d+$") || Integer(usesRaw) < 1 {
        MsgBox("策略配置错误：使用次数必须是大于等于 1 的整数。")
        return false
    }
    if !RegExMatch(minsRaw, "^\d+$") || Integer(minsRaw) < 1 {
        MsgBox("策略配置错误：分钟数必须是大于等于 1 的整数。")
        return false
    }

    gBehavior["auto_refresh_enabled"] := enabled
    gBehavior["refresh_every_uses"] := Integer(usesRaw)
    gBehavior["refresh_every_minutes"] := Integer(minsRaw)
    return true
}

OnResetDefaultHotkeys(*) {
    global gHotkeys, gHotkeyDefs
    for def in gHotkeyDefs {
        gHotkeys[def["id"]] := def["default"]
    }
    ReloadHotkeyInputs()
    SaveData()
    RegisterHotkeys()
    WriteLog("hotkey_reset_default", "restored and applied")
    MsgBox("已恢复默认快捷键并立即生效。")
}

OnResetDefaultBehavior(*) {
    global gBehavior
    gBehavior := GetBehaviorDefaults()
    ReloadBehaviorInputs()
    SaveData()
    RestartAutoRefreshTimer()
    WriteLog("behavior_reset_default", "restored and applied")
    MsgBox("已恢复默认自动刷新策略并立即生效。")
}

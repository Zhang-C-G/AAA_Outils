; Config window UI shell (layout + wiring)

gConfigTabsCtrl := ""
gConfigDeleteCategoryBtn := ""
gConfigRenameEdit := ""
gConfigRenameTargetId := ""
gConfigDeleteConfirmMode := false
gConfigTabMeta := []
gTabDragHooked := false
gTabDragActive := false
gTabDragFrom := 0
gConfigModeDDL := ""

BuildConfigGui() {
    global gConfigGui, gAppName, gTheme, gActiveMode
    global gConfigModeDDL, gConfigDeleteCategoryBtn, gConfigTabsCtrl, gConfigRenameEdit

    gConfigTabsCtrl := ""
    gConfigDeleteCategoryBtn := ""
    gConfigRenameEdit := ""
    gConfigModeDDL := ""

    gConfigGui := Gui("+Resize", gAppName " - Config")
    gConfigGui.SetFont("s10", "Microsoft YaHei UI")
    gConfigGui.BackColor := gTheme["bg_app"]

    gConfigGui.AddText("x0 y0 w980 h92 0x10 Background" gTheme["bg_surface"])

    title := gConfigGui.AddText("x28 y20 w420 h28 c" gTheme["text_primary"], gAppName " Config Center")
    title.SetFont("s18 w700", "Segoe UI")

    sub := gConfigGui.AddText("x28 y52 w560 h20 c" gTheme["text_hint"], "Mono style, editable tabs, version restore, mode switch")
    sub.SetFont("s9", "Microsoft YaHei UI")

    gConfigGui.AddText("x600 y30 w56 h22 c" gTheme["text_primary"], "Mode")
    gConfigModeDDL := gConfigGui.AddDropDownList("x650 y26 w180 Choose" GetModeChooseIndex(gActiveMode) " c" gTheme["text_on_light"] " Background" gTheme["bg_header"], ["Hotkeys", "Notes", "Capture", "Assistant"])
    gConfigModeDDL.OnEvent("Change", OnConfigModeChanged)

    restoreBtn := gConfigGui.AddButton("x820 y18 w64 h30 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Restore")
    restoreBtn.SetFont("s9 w700", "Segoe UI")
    restoreBtn.OnEvent("Click", OnRestoreVersionClicked)

    saveVersionBtn := gConfigGui.AddButton("x890 y18 w64 h30 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "Save")
    saveVersionBtn.SetFont("s9 w700", "Segoe UI")
    saveVersionBtn.OnEvent("Click", OnSaveVersionClicked)

    gConfigGui.AddText("x20 y92 w940 h1 0x10 Background" gTheme["line"])

    switch gActiveMode {
        case "notes":
            BuildNotesModeBody()
        case "capture":
            BuildCaptureModeBody()
        case "assistant":
            BuildAssistantModeBody()
        default:
            BuildShortcutsModeBody()
    }

    gConfigGui.OnEvent("Close", OnConfigGuiClose)
}

BuildShortcutsModeBody() {
    global gConfigGui, gTheme, gCategories
    global gConfigTabsCtrl, gConfigRenameEdit, gConfigTabMeta, gConfigDeleteCategoryBtn

    tabNames := []
    gConfigTabMeta := []
    for cat in gCategories {
        tabNames.Push(cat["name"])
        gConfigTabMeta.Push(Map("type", "category", "id", cat["id"]))
    }
    tabNames.Push("Hotkeys")
    gConfigTabMeta.Push(Map("type", "fixed", "id", "hotkeys"))
    tabNames.Push("Strategy")
    gConfigTabMeta.Push(Map("type", "fixed", "id", "behavior"))

    gConfigTabsCtrl := gConfigGui.AddTab3("x20 y106 w900 h570 c" gTheme["text_primary"] " Background" gTheme["bg_surface"], tabNames)
    gConfigTabsCtrl.OnEvent("Change", OnConfigTabChanged)
    try gConfigTabsCtrl.OnEvent("DoubleClick", OnConfigTabDoubleClick)
    RegisterConfigTabDragHooks()

    tabIndex := 1
    for cat in gCategories {
        gConfigTabsCtrl.UseTab(tabIndex)
        BuildCategoryEditor(gConfigGui, cat["id"], 40, 158)
        tabIndex += 1
    }

    gConfigTabsCtrl.UseTab(tabIndex)
    BuildHotkeyEditor(gConfigGui, 40, 158)
    tabIndex += 1

    gConfigTabsCtrl.UseTab(tabIndex)
    BuildBehaviorEditor(gConfigGui, 40, 158)

    gConfigTabsCtrl.UseTab()
    addCategoryBtn := gConfigGui.AddButton("x925 y106 w35 h28 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "+")
    addCategoryBtn.SetFont("s14 w700", "Segoe UI")
    addCategoryBtn.OnEvent("Click", OnAddCategoryClicked)

    gConfigRenameEdit := gConfigGui.AddEdit("x20 y106 w160 h28 vTabRenameEdit Hidden c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    gConfigRenameEdit.SetFont("s10", "Microsoft YaHei UI")
    gConfigRenameEdit.OnEvent("LoseFocus", OnRenameTabCommit)

    gConfigGui.AddText("x20 y692 w940 h1 0x10 Background" gTheme["line"])

    saveBtn := gConfigGui.AddButton("x350 y712 w220 h42 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "Save Config")
    saveBtn.SetFont("s11 w700", "Segoe UI")
    saveBtn.OnEvent("Click", OnSaveConfig)

    gConfigDeleteCategoryBtn := gConfigGui.AddButton("x760 y712 w200 h42 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Delete Current Tab")
    gConfigDeleteCategoryBtn.SetFont("s10 w700", "Segoe UI")
    gConfigDeleteCategoryBtn.OnEvent("Click", OnDeleteCategoryClicked)

    UpdateDeleteCategoryButtonState()
}

BuildCategoryEditor(guiObj, categoryId, x, y) {
    global gTheme
    prefix := GetCategoryCtrlPrefix(categoryId)
    contentW := 860
    listH := 310
    formY := y + listH + 22

    lv := guiObj.AddListView("x" x " y" y " w" contentW " h" listH " v" prefix "LV Background" gTheme["bg_surface"] " c" gTheme["text_primary"], ["Trigger", "Value", "Usage"])
    lv.OnEvent("ItemSelect", CategoryItemSelect.Bind(categoryId))
    lv.ModifyCol(1, 180)
    lv.ModifyCol(2, 575)
    lv.ModifyCol(3, 92)

    guiObj.AddText("x" x " y" formY " h24 c" gTheme["text_primary"], "Trigger")
    guiObj.AddEdit("x" (x + 58) " y" (formY - 2) " w190 h28 v" prefix "Key c" gTheme["text_on_light"] " Background" gTheme["bg_header"])

    guiObj.AddText("x" (x + 270) " y" formY " h24 c" gTheme["text_primary"], "Value")
    guiObj.AddEdit("x" (x + 310) " y" (formY - 2) " w390 h28 v" prefix "Val c" gTheme["text_on_light"] " Background" gTheme["bg_header"])

    addBtn := guiObj.AddButton("x" (x + 720) " y" (formY - 2) " w76 h28 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "Add")
    updBtn := guiObj.AddButton("x" (x + 804) " y" (formY - 2) " w76 h28 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "Update")
    delBtn := guiObj.AddButton("x" (x + 720) " y" (formY + 34) " w76 h28 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Delete")
    upBtn := guiObj.AddButton("x" (x + 804) " y" (formY + 34) " w76 h28 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Up")
    downBtn := guiObj.AddButton("x" (x + 804) " y" (formY + 68) " w76 h28 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Down")

    addBtn.OnEvent("Click", CategoryAdd.Bind(categoryId))
    updBtn.OnEvent("Click", CategoryUpdate.Bind(categoryId))
    delBtn.OnEvent("Click", CategoryDelete.Bind(categoryId))
    upBtn.OnEvent("Click", CategoryMove.Bind(categoryId, -1))
    downBtn.OnEvent("Click", CategoryMove.Bind(categoryId, 1))
}

ShowConfigWindow() {
    global gConfigGui, gConfigDeleteConfirmMode, gActiveMode
    if ShowWebConfigWindow() {
        return
    }

    gConfigDeleteConfirmMode := false

    if (gActiveMode = "shortcuts") {
        ReloadConfigListViews()
        ReloadHotkeyInputs()
        ReloadBehaviorInputs()
    } else if (gActiveMode = "notes") {
        ReloadNotesEditor()
    } else if (gActiveMode = "capture") {
        ReloadCapturePanel()
    } else if (gActiveMode = "assistant") {
        ReloadAssistantPanel()
    }

    gConfigGui.Show("w980 h770")
    if (gActiveMode = "shortcuts") {
        UpdateDeleteCategoryButtonState()
    }
    WriteLog("config_open", "shown mode=" gActiveMode)
}

ReloadConfigListViews() {
    global gConfigGui, gData, gCategories

    for cat in gCategories {
        id := cat["id"]
        prefix := GetCategoryCtrlPrefix(id)
        lv := gConfigGui[prefix "LV"]
        lv.Delete()
        if gData.Has(id) {
            for row in gData[id] {
                lv.Add(, row["key"], row["value"], GetUsageCountByCategory(id, row["key"]))
            }
        }
        ClearCategoryInputs(id)
    }
}

OnSaveConfig(*) {
    if !ReadHotkeysFromGui() {
        WriteLog("config_save_failed", "invalid hotkey settings")
        return
    }
    if !ReadBehaviorFromGui() {
        WriteLog("config_save_failed", "invalid behavior settings")
        return
    }

    SaveData()
    RegisterHotkeys()
    RestartAutoRefreshTimer()
    WriteLog("config_save", "saved to config.ini")
    MsgBox("Config saved")
}

GetModeChooseIndex(modeId) {
    if (modeId = "notes") {
        return 2
    }
    if (modeId = "capture") {
        return 3
    }
    if (modeId = "assistant") {
        return 4
    }
    return 1
}

OnConfigGuiClose(*) {
    global gConfigGui, gActiveMode
    if (gActiveMode = "notes") {
        SaveCurrentNoteIfAny()
    } else if (gActiveMode = "capture") {
        SaveCaptureSettingsFromGui()
        SaveData()
        SetTimer(UpdateCaptureBridgeStatusUi, 0)
    } else if (gActiveMode = "assistant") {
        SaveAssistantSettingsFromGui()
        SaveData()
    }
    gConfigGui.Hide()
}

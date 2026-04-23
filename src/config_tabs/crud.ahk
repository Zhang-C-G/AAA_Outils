; Config tabs submodule: category CRUD, rename, selection, delete

OnAddCategoryClicked(*) {
    global gCategories, gData, gUsage

    id := "cat_" FormatTime(A_Now, "yyyyMMddHHmmss")
    idx := 1
    while HasCategory(gCategories, id) {
        idx += 1
        id := "cat_" FormatTime(A_Now, "yyyyMMddHHmmss") "_" idx
    }

    gCategories.Push(Map("id", id, "name", "New Tab", "builtin", 0))
    gData[id] := []
    gUsage[id] := Map()
    SaveData()
    SaveUsageCounts()
    WriteLog("category_add", "id=" id)
    RebuildConfigWindow(id)
}

RebuildConfigWindow(focusCategoryId := "") {
    global gConfigGui

    wasVisible := false
    if IsObject(gConfigGui) {
        try {
            if WinExist("ahk_id " gConfigGui.Hwnd) {
                wasVisible := true
            }
        }
        try gConfigGui.Destroy()
    }

    BuildConfigGui()
    if wasVisible {
        ShowConfigWindow()
        if (focusCategoryId != "") {
            FocusCategoryTabById(focusCategoryId)
        }
    }
}

FocusCategoryTabById(categoryId) {
    global gConfigTabsCtrl, gConfigTabMeta
    idx := 0
    for meta in gConfigTabMeta {
        idx += 1
        if (meta["type"] = "category" && meta["id"] = categoryId) {
            gConfigTabsCtrl.Value := idx
            UpdateDeleteCategoryButtonState()
            return
        }
    }
}

OnConfigTabChanged(*) {
    global gConfigDeleteConfirmMode
    gConfigDeleteConfirmMode := false
    UpdateDeleteCategoryButtonState()
}

OnConfigTabDoubleClick(*) {
    StartInlineRenameCurrentCategory()
}

StartInlineRenameCurrentCategory() {
    global gConfigTabsCtrl, gConfigTabMeta, gConfigRenameEdit, gConfigRenameTargetId

    idx := gConfigTabsCtrl.Value
    if (idx < 1 || idx > gConfigTabMeta.Length) {
        return
    }

    meta := gConfigTabMeta[idx]
    if (meta["type"] != "category") {
        return
    }

    gConfigRenameTargetId := meta["id"]
    gConfigRenameEdit.Value := GetCategoryNameById(gConfigRenameTargetId)
    gConfigRenameEdit.Opt("-Hidden")
    gConfigRenameEdit.Focus()
}

OnRenameTabCommit(*) {
    global gConfigRenameEdit, gConfigRenameTargetId, gCategories

    if (gConfigRenameTargetId = "") {
        gConfigRenameEdit.Opt("+Hidden")
        return
    }

    newName := Trim(gConfigRenameEdit.Value)
    if (newName = "") {
        gConfigRenameEdit.Opt("+Hidden")
        gConfigRenameTargetId := ""
        return
    }

    for cat in gCategories {
        if (cat["id"] = gConfigRenameTargetId) {
            cat["name"] := newName
            break
        }
    }

    SaveData()
    WriteLog("category_rename", "id=" gConfigRenameTargetId " name=" newName)
    gConfigRenameTargetId := ""
    gConfigRenameEdit.Opt("+Hidden")
    RebuildConfigWindow()
}

UpdateDeleteCategoryButtonState() {
    global gConfigDeleteCategoryBtn, gConfigTabsCtrl, gConfigTabMeta, gConfigDeleteConfirmMode

    idx := gConfigTabsCtrl.Value
    canDelete := false

    if (idx >= 1 && idx <= gConfigTabMeta.Length) {
        meta := gConfigTabMeta[idx]
        if (meta["type"] = "category" && !IsBuiltinCategory(meta["id"])) {
            canDelete := true
        }
    }

    gConfigDeleteCategoryBtn.Enabled := canDelete
    if !canDelete {
        gConfigDeleteCategoryBtn.Text := "Delete Current Tab"
        gConfigDeleteConfirmMode := false
    } else {
        gConfigDeleteCategoryBtn.Text := gConfigDeleteConfirmMode ? "Click Again To Confirm" : "Delete Current Tab"
    }
}

IsBuiltinCategory(categoryId) {
    return (categoryId = "fields" || categoryId = "prompts" || categoryId = "quick_fields")
}

OnDeleteCategoryClicked(*) {
    global gConfigTabsCtrl, gConfigTabMeta, gConfigDeleteConfirmMode, gCategories, gData, gUsage

    idx := gConfigTabsCtrl.Value
    if (idx < 1 || idx > gConfigTabMeta.Length) {
        return
    }

    meta := gConfigTabMeta[idx]
    if (meta["type"] != "category" || IsBuiltinCategory(meta["id"])) {
        return
    }

    if !gConfigDeleteConfirmMode {
        gConfigDeleteConfirmMode := true
        UpdateDeleteCategoryButtonState()
        return
    }

    targetId := meta["id"]
    targetName := GetCategoryNameById(targetId)
    nextCats := []
    for cat in gCategories {
        if (cat["id"] != targetId) {
            nextCats.Push(cat)
        }
    }
    gCategories := nextCats

    if gData.Has(targetId) {
        gData.Delete(targetId)
    }
    if gUsage.Has(targetId) {
        gUsage.Delete(targetId)
    }

    SaveData()
    SaveUsageCounts()
    WriteLog("category_delete", "id=" targetId " name=" targetName)
    gConfigDeleteConfirmMode := false
    RebuildConfigWindow()
}

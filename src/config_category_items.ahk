; Config submodule: category item CRUD and helpers

CategoryItemSelect(categoryId, lv, rowNumber, *) {
    global gConfigGui, gData
    if !rowNumber {
        return
    }

    prefix := GetCategoryCtrlPrefix(categoryId)
    gConfigGui[prefix "Key"].Value := gData[categoryId][rowNumber]["key"]
    gConfigGui[prefix "Val"].Value := gData[categoryId][rowNumber]["value"]
}

CategoryAdd(categoryId, *) {
    global gData, gConfigGui, gUsage

    prefix := GetCategoryCtrlPrefix(categoryId)
    key := Trim(gConfigGui[prefix "Key"].Value)
    val := Trim(gConfigGui[prefix "Val"].Value)

    if (key = "" || val = "") {
        WriteLog("config_add_failed", "category=" categoryId " empty key/value")
        MsgBox("Trigger and value cannot be empty.")
        return
    }

    if !gData.Has(categoryId) {
        gData[categoryId] := []
    }
    gData[categoryId].Push(Map("key", key, "value", val))

    EnsureUsageCategory(categoryId)
    if !gUsage[categoryId].Has(key) {
        gUsage[categoryId][key] := 0
        SaveUsageCounts()
    }

    ReloadConfigListViews()
    WriteLog("config_add", "category=" categoryId " key=" key)
}

CategoryUpdate(categoryId, *) {
    global gData, gConfigGui, gUsage

    prefix := GetCategoryCtrlPrefix(categoryId)
    lv := gConfigGui[prefix "LV"]
    row := lv.GetNext()
    if !row {
        WriteLog("config_update_failed", "category=" categoryId " no selection")
        MsgBox("Please select a row first.")
        return
    }

    key := Trim(gConfigGui[prefix "Key"].Value)
    val := Trim(gConfigGui[prefix "Val"].Value)

    if (key = "" || val = "") {
        WriteLog("config_update_failed", "category=" categoryId " empty key/value")
        MsgBox("Trigger and value cannot be empty.")
        return
    }

    EnsureUsageCategory(categoryId)
    oldKey := gData[categoryId][row]["key"]
    gData[categoryId][row] := Map("key", key, "value", val)

    if (oldKey != key) {
        oldCount := gUsage[categoryId].Has(oldKey) ? gUsage[categoryId][oldKey] : 0
        if gUsage[categoryId].Has(oldKey) {
            gUsage[categoryId].Delete(oldKey)
        }
        gUsage[categoryId][key] := oldCount
        SaveUsageCounts()
    }

    ReloadConfigListViews()
    lv.Modify(row, "Select Focus")
    WriteLog("config_update", "category=" categoryId " row=" row " key=" key)
}

CategoryDelete(categoryId, *) {
    global gData, gConfigGui, gUsage

    prefix := GetCategoryCtrlPrefix(categoryId)
    lv := gConfigGui[prefix "LV"]
    row := lv.GetNext()
    if !row {
        WriteLog("config_delete_failed", "category=" categoryId " no selection")
        MsgBox("Please select a row first.")
        return
    }

    removedKey := gData[categoryId][row]["key"]
    gData[categoryId].RemoveAt(row)

    EnsureUsageCategory(categoryId)
    if gUsage[categoryId].Has(removedKey) {
        gUsage[categoryId].Delete(removedKey)
        SaveUsageCounts()
    }

    ReloadConfigListViews()
    WriteLog("config_delete", "category=" categoryId " row=" row " key=" removedKey)
}

CategoryMove(categoryId, direction, *) {
    global gData, gConfigGui

    prefix := GetCategoryCtrlPrefix(categoryId)
    lv := gConfigGui[prefix "LV"]
    row := lv.GetNext()
    if !row {
        WriteLog("config_move_failed", "category=" categoryId " no selection")
        MsgBox("Please select a row first.")
        return
    }

    target := row + direction
    if (target < 1 || target > gData[categoryId].Length) {
        WriteLog("config_move_ignored", "category=" categoryId " row=" row " direction=" direction)
        return
    }

    tmp := gData[categoryId][row]
    gData[categoryId][row] := gData[categoryId][target]
    gData[categoryId][target] := tmp

    ReloadConfigListViews()
    lv.Modify(target, "Select Focus")
    WriteLog("config_move", "category=" categoryId " from=" row " to=" target)
}

ClearCategoryInputs(categoryId) {
    global gConfigGui
    prefix := GetCategoryCtrlPrefix(categoryId)
    gConfigGui[prefix "Key"].Value := ""
    gConfigGui[prefix "Val"].Value := ""
}

GetCategoryCtrlPrefix(categoryId) {
    safe := RegExReplace(categoryId, "[^0-9A-Za-z_]", "_")
    return "CAT_" safe "_"
}

GetCategoryNameById(categoryId) {
    global gCategories
    for cat in gCategories {
        if (cat["id"] = categoryId) {
            return cat["name"]
        }
    }
    return categoryId
}

EnsureUsageCategory(categoryId) {
    global gUsage
    if !gUsage.Has(categoryId) {
        gUsage[categoryId] := Map()
    }
}

GetUsageCountByCategory(categoryId, key) {
    global gUsage
    if !gUsage.Has(categoryId) {
        return 0
    }
    return gUsage[categoryId].Has(key) ? gUsage[categoryId][key] : 0
}

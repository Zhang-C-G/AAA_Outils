; Data and usage persistence

EnsureDataFile() {
    global gDataFile
    if FileExist(gDataFile) {
        return
    }

    defaultIni := "[Categories]`n"
        . "fields=字段`n"
        . "prompts=提示词`n"
        . "quick_fields=快捷字段`n"
        . "`n[Fields]`n"
        . "297=2970654645@qq.com`n"
        . "A75=A757850510A`n"
        . "QCM=将题目做成互动性测试格式`n"
        . "@zcg=@zcgZCG757850510`n"
        . "`n[Prompts]`n"
        . "fy=翻译`n"
        . "yhwa=优化文案`n"
        . "`n[QuickFields]`n"
        . "更新=更新动作记录文档并同步各模块文档；若文件过大则自动拆分为子文件，防止文件臃肿并保持结构清晰。`n"
        . "`n[Hotkeys]`n"
        . "toggle_panel=!q`n"
        . "open_config=!+q`n"
        . "assistant_capture=!+a`n"
        . "assistant_capture_now=F1`n"
        . "assistant_overlay_up=!Up`n"
        . "assistant_overlay_down=!Down`n"
        . "close_panel=Esc`n"
        . "confirm_selection=Enter`n"
        . "move_up=Up`n"
        . "move_down=Down`n"
        . "`n[App]`n"
        . "active_mode=shortcuts`n"
        . "`n[Capture]`n"
        . "upload_endpoint=https://0x0.st`n"
        . "open_qr_after_upload=1`n"
        . "bridge_port=8787`n"
        . "`n[Assistant]`n"
        . "enabled=1`n"
        . "api_endpoint=https://ark.cn-beijing.volces.com/api/v3/responses`n"
        . "api_key=`n"
        . "api_key_protected=`n"
        . "model=doubao-seed-2-0-lite-260215`n"
        . "active_template=default_template`n"
        . "prompt=编程题：直接给完整可运行代码，并在代码框中输出；随后对核心思路做简短说明。选择题：先写15字以内题目总结，再直接给答案。`n"
        . "overlay_opacity=100`n"
        . "rate_limit_enabled=1`n"
        . "rate_limit_per_hour=100`n"
        . "`n[AssistantTemplates]`n"
        . "default_template=编程题：直接给完整可运行代码，并在代码框中输出；随后对核心思路做简短说明。选择题：先写15字以内题目总结，再直接给答案。`n"
        . "`n[Behavior]`n"
        . "auto_refresh_enabled=1`n"
        . "refresh_every_uses=3`n"
        . "refresh_every_minutes=5`n"

    FileAppend(defaultIni, gDataFile, "UTF-8")
}

EnsureUsageFile() {
    global gUsageFile
    if FileExist(gUsageFile) {
        return
    }
    FileAppend("[Usage_fields]`n`n[Usage_prompts]`n`n[Usage_quick_fields]`n", gUsageFile, "UTF-8")
}

LoadData() {
    global gCategories
    return LoadDataByCategories(gCategories)
}

LoadCategories() {
    global gDataFile
    categories := []
    raw := LoadSection(gDataFile, "Categories")
    if (raw.Length = 0) {
        categories.Push(Map("id", "fields", "name", "字段", "builtin", 1))
        categories.Push(Map("id", "prompts", "name", "提示词", "builtin", 1))
        categories.Push(Map("id", "quick_fields", "name", "快捷字段", "builtin", 1))
        return categories
    }

    for row in raw {
        id := Trim(row["key"])
        if (id = "") {
            continue
        }
        name := Trim(row["value"])
        if (name = "") {
            name := id
        }
        builtin := (id = "fields" || id = "prompts" || id = "quick_fields") ? 1 : 0
        categories.Push(Map("id", id, "name", name, "builtin", builtin))
    }

    if !HasCategory(categories, "fields") {
        categories.InsertAt(1, Map("id", "fields", "name", "字段", "builtin", 1))
    }
    if !HasCategory(categories, "prompts") {
        categories.InsertAt(2, Map("id", "prompts", "name", "提示词", "builtin", 1))
    }
    if !HasCategory(categories, "quick_fields") {
        categories.InsertAt(3, Map("id", "quick_fields", "name", "快捷字段", "builtin", 1))
    }
    return categories
}

HasCategory(categories, id) {
    for cat in categories {
        if (cat["id"] = id) {
            return true
        }
    }
    return false
}

LoadDataByCategories(categories) {
    global gDataFile
    data := Map()
    for cat in categories {
        id := cat["id"]
        sectionName := GetCategorySectionName(id)
        data[id] := LoadSection(gDataFile, sectionName)
        if (id = "quick_fields") {
            EnsureQuickFieldDefaults(data[id])
        }
    }
    return data
}

EnsureQuickFieldDefaults(rows) {
    existsUpdate := false
    for row in rows {
        if (Trim(row["key"]) = "更新") {
            existsUpdate := true
            break
        }
    }
    if !existsUpdate {
        rows.Push(Map(
            "key", "更新",
            "value", "更新动作记录文档并同步各模块文档；若文件过大则自动拆分为子文件，防止文件臃肿并保持结构清晰。"
        ))
    }
}

GetCategorySectionName(catId) {
    if (catId = "fields") {
        return "Fields"
    }
    if (catId = "prompts") {
        return "Prompts"
    }
    if (catId = "quick_fields") {
        return "QuickFields"
    }
    return "Category_" catId
}

LoadHotkeys() {
    global gDataFile, gHotkeyDefs
    raw := LoadSection(gDataFile, "Hotkeys")
    hk := Map()

    for row in raw {
        val := HotkeyFromFriendly(Trim(row["value"]))
        hk[row["key"]] := val
    }

    for def in gHotkeyDefs {
        if !hk.Has(def["id"]) || hk[def["id"]] = "" {
            hk[def["id"]] := def["default"]
        }
    }
    return hk
}

LoadBehavior() {
    global gDataFile
    behavior := GetBehaviorDefaults()
    raw := LoadSection(gDataFile, "Behavior")

    for row in raw {
        key := row["key"]
        value := row["value"]
        switch key {
            case "auto_refresh_enabled":
                behavior["auto_refresh_enabled"] := (value = "1" || StrLower(value) = "true") ? 1 : 0
            case "refresh_every_uses":
                behavior["refresh_every_uses"] := RegExMatch(value, "^\d+$") ? Integer(value) : behavior["refresh_every_uses"]
            case "refresh_every_minutes":
                behavior["refresh_every_minutes"] := RegExMatch(value, "^\d+$") ? Integer(value) : behavior["refresh_every_minutes"]
        }
    }

    NormalizeBehavior(behavior)
    return behavior
}

LoadAppSettings() {
    global gDataFile
    settings := Map("active_mode", "shortcuts")
    raw := LoadSection(gDataFile, "App")
    for row in raw {
        if (row["key"] = "active_mode") {
            settings["active_mode"] := NormalizeModeId(row["value"])
        }
    }
    return settings
}

NormalizeModeId(mode) {
    m := StrLower(Trim(mode))
    if (m = "notes") {
        return "notes"
    }
    if (m = "capture") {
        return "capture"
    }
    if (m = "assistant") {
        return "assistant"
    }
    if (m = "resume") {
        return "resume"
    }
    return "shortcuts"
}

LoadCaptureSettings() {
    global gDataFile
    settings := Map(
        "upload_endpoint", "https://0x0.st",
        "open_qr_after_upload", 1,
        "bridge_port", 8787
    )

    raw := LoadSection(gDataFile, "Capture")
    for row in raw {
        key := row["key"]
        value := Trim(row["value"])
        switch key {
            case "upload_endpoint":
                if (value != "") {
                    settings["upload_endpoint"] := value
                }
            case "open_qr_after_upload":
                settings["open_qr_after_upload"] := (value = "1" || StrLower(value) = "true") ? 1 : 0
            case "bridge_port":
                if RegExMatch(value, "^\d+$") {
                    p := Integer(value)
                    if (p >= 1024 && p <= 65535) {
                        settings["bridge_port"] := p
                    }
                }
        }
    }
    return settings
}

LoadResumeSettings() {
    global gDataFile
    settings := Map(
        "name", "",
        "phone", "",
        "email", "",
        "education", "",
        "experience", "",
        "skills", ""
    )

    raw := LoadSection(gDataFile, "Resume")
    for row in raw {
        key := row["key"]
        value := Trim(row["value"])
        if settings.Has(key) {
            settings[key] := value
        }
    }
    return settings
}

LoadSection(path, section) {
    rows := []
    inSection := false

    for line in StrSplit(FileRead(path, "UTF-8"), "`n", "`r") {
        trimLine := Trim(line)
        if (trimLine = "") {
            continue
        }

        if RegExMatch(trimLine, "^\[(.+)\]$", &m) {
            inSection := (m[1] = section)
            continue
        }

        if !inSection {
            continue
        }

        if InStr(trimLine, "=") {
            key := Trim(SubStr(trimLine, 1, InStr(trimLine, "=") - 1))
            value := Trim(SubStr(trimLine, InStr(trimLine, "=") + 1))
            if (key != "") {
                rows.Push(Map("key", key, "value", value))
            }
        }
    }

    return rows
}

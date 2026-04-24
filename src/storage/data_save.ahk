SaveData() {
    global gDataFile, gData, gHotkeys, gHotkeyDefs, gBehavior, gCategories, gActiveMode, gCaptureSettings, gAssistantSettings, gResumeSettings, gCaptureDir
    try ProcessWebConfigActionFile()

    EnsureAssistantTemplates(gAssistantSettings)
    gAssistantSettings["overlay_opacity"] := ClampAssistantOpacity(gAssistantSettings["overlay_opacity"])
    gAssistantSettings["rate_limit_per_hour"] := ClampAssistantRatePerHour(gAssistantSettings["rate_limit_per_hour"])

    currentPlainKey := Trim(gAssistantSettings["api_key"])
    protectedKey := Trim(gAssistantSettings["api_key_protected"])
    if (currentPlainKey != "") {
        newProtected := ProtectAssistantSecret(currentPlainKey)
        if (newProtected != "") {
            protectedKey := newProtected
        }
    }
    gAssistantSettings["api_key_protected"] := protectedKey
    gAssistantSettings["has_api_key"] := (currentPlainKey != "" || protectedKey != "") ? 1 : 0

    lines := []
    lines.Push("[Categories]")
    for cat in gCategories {
        lines.Push(cat["id"] "=" cat["name"])
    }

    for cat in gCategories {
        lines.Push("")
        lines.Push("[" GetCategorySectionName(cat["id"]) "]")
        if gData.Has(cat["id"]) {
            for row in gData[cat["id"]] {
                lines.Push(row["key"] "=" row["value"])
            }
        }
    }

    lines.Push("")
    lines.Push("[Hotkeys]")
    for def in gHotkeyDefs {
        id := def["id"]
        lines.Push(id "=" gHotkeys[id])
    }

    lines.Push("")
    lines.Push("[App]")
    lines.Push("active_mode=" NormalizeModeId(gActiveMode))
    lines.Push("capture_dir=" gCaptureDir)

    lines.Push("")
    lines.Push("[Capture]")
    lines.Push("upload_endpoint=" gCaptureSettings["upload_endpoint"])
    lines.Push("open_qr_after_upload=" gCaptureSettings["open_qr_after_upload"])
    lines.Push("bridge_port=" gCaptureSettings["bridge_port"])

    lines.Push("")
    lines.Push("[Assistant]")
    lines.Push("enabled=" gAssistantSettings["enabled"])
    lines.Push("api_endpoint=" gAssistantSettings["api_endpoint"])
    lines.Push("api_key=")
    lines.Push("api_key_protected=" gAssistantSettings["api_key_protected"])
    lines.Push("model=" gAssistantSettings["model"])
    lines.Push("active_template=" gAssistantSettings["active_template"])
    lines.Push("prompt=" StrReplace(StrReplace(GetAssistantPromptByTemplate(gAssistantSettings), "`r", " "), "`n", " "))
    lines.Push("overlay_opacity=" gAssistantSettings["overlay_opacity"])
    lines.Push("disable_copy=" (gAssistantSettings.Has("disable_copy") ? gAssistantSettings["disable_copy"] : 1))
    lines.Push("rate_limit_enabled=" gAssistantSettings["rate_limit_enabled"])
    lines.Push("rate_limit_per_hour=" gAssistantSettings["rate_limit_per_hour"])

    lines.Push("")
    lines.Push("[Resume]")
    lines.Push("name=" gResumeSettings["name"])
    lines.Push("phone=" gResumeSettings["phone"])
    lines.Push("email=" gResumeSettings["email"])
    lines.Push("education=" gResumeSettings["education"])
    lines.Push("experience=" gResumeSettings["experience"])
    lines.Push("skills=" gResumeSettings["skills"])

    lines.Push("")
    lines.Push("[AssistantTemplates]")
    for t in gAssistantSettings["templates"] {
        tName := Trim(t["name"])
        tPrompt := StrReplace(StrReplace(Trim(t["prompt"]), "`r", " "), "`n", " ")
        if (tName = "") {
            continue
        }
        if (tPrompt = "") {
            tPrompt := GetAssistantDefaultPrompt()
        }
        lines.Push(tName "=" tPrompt)
    }

    lines.Push("")
    lines.Push("[Behavior]")
    lines.Push("auto_refresh_enabled=" gBehavior["auto_refresh_enabled"])
    lines.Push("refresh_every_uses=" gBehavior["refresh_every_uses"])
    lines.Push("refresh_every_minutes=" gBehavior["refresh_every_minutes"])

    FileDelete(gDataFile)
    FileAppend(StrJoin(lines, "`n"), gDataFile, "UTF-8")
}

SaveSnapshotVersion() {
    global gDataFile, gSnapshotFile
    if !FileExist(gDataFile) {
        return false
    }
    FileCopy(gDataFile, gSnapshotFile, 1)
    return true
}

RestoreSnapshotVersion() {
    global gDataFile, gSnapshotFile
    if !FileExist(gSnapshotFile) {
        return false
    }
    FileCopy(gSnapshotFile, gDataFile, 1)
    return true
}

; Floating panel UI and insertion workflow

BuildPanelGui() {
    global gPanelGui, gSearchEdit, gMatchList, gStatusText, gHintText, gAppName, gTheme

    gPanelGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", gAppName " - 热键悬浮面板")
    gPanelGui.BackColor := gTheme["bg_app"]
    gPanelGui.MarginX := 14
    gPanelGui.MarginY := 14

    panelInnerW := 392

    title := gPanelGui.AddText("xm ym w" panelInnerW " h28 c" gTheme["text_primary"], gAppName)
    title.SetFont("s15 w700", "Segoe UI")

    subTitle := gPanelGui.AddText("xm y+2 w" panelInnerW " h20 c" gTheme["text_muted"], "Alt+Q 呼出 · Enter 插入 · Esc 关闭")
    subTitle.SetFont("s9", "Microsoft YaHei UI")

    gPanelGui.AddText("xm y+8 w" panelInnerW " h1 0x10 Background" gTheme["line"])

    gSearchEdit := gPanelGui.AddEdit("vSearchInput xm y+10 w" panelInnerW " h36 c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    gSearchEdit.SetFont("s11", "Segoe UI")
    gSearchEdit.OnEvent("Change", OnSearchChanged)

    gStatusText := gPanelGui.AddText("xm y+8 w" panelInnerW " h20 c" gTheme["text_primary"], "")
    gStatusText.SetFont("s9", "Microsoft YaHei UI")

    gMatchList := gPanelGui.AddListView("vMatchList xm y+6 w" panelInnerW " h220 -Multi -Hdr Background" gTheme["bg_surface"] " c" gTheme["text_primary"], ["键", "内容", "热度"])
    gMatchList.SetFont("s10", "Segoe UI")
    gMatchList.OnEvent("DoubleClick", OnMatchDoubleClick)
    gMatchList.ModifyCol(1, 90)
    gMatchList.ModifyCol(2, 236)
    gMatchList.ModifyCol(3, 52)

    gHintText := gPanelGui.AddText("xm y+8 w" panelInnerW " h20 c" gTheme["text_hint"], "Tip: 空搜索默认展示提示词 Top 5，↑/↓ 切换候选，Enter 插入")
    gHintText.SetFont("s8", "Microsoft YaHei UI")

    gPanelGui.OnEvent("Close", (*) => HidePanel())
}

TogglePanel() {
    global gPanelVisible
    if gPanelVisible {
        HidePanel()
    } else {
        ShowPanel()
    }
}

ShowPanel() {
    global gPanelGui, gSearchEdit, gPanelVisible, gLastTargetHwnd, gPanelW, gPanelH, gCurrentQuery

    gLastTargetHwnd := WinGetID("A")

    MouseGetPos(&mx, &my)
    px := mx + 12
    py := my + 12
    maxX := A_ScreenWidth - gPanelW - 8
    maxY := A_ScreenHeight - gPanelH - 8
    px := Max(8, Min(px, maxX))
    py := Max(8, Min(py, maxY))

    gCurrentQuery := ""
    RefreshMatches("")
    gPanelGui.Show("x" px " y" py " w" gPanelW " h" gPanelH)
    gPanelGui.Opt("+OwnDialogs")

    gSearchEdit.Value := ""
    gSearchEdit.Focus()
    SwitchToEnglishLayout(gPanelGui.Hwnd)
    PanelFadeIn()
    gPanelVisible := true
    WriteLog("panel_open", "target_hwnd=" gLastTargetHwnd)
}

HidePanel() {
    global gPanelGui, gPanelVisible
    PanelFadeOut()
    gPanelGui.Hide()
    gPanelVisible := false
    WriteLog("panel_close", "hidden")
}

OnSearchChanged(ctrl, *) {
    global gCurrentQuery
    gCurrentQuery := ctrl.Value
    RefreshMatches(ctrl.Value)
}

RefreshMatches(query) {
    global gData, gUsage, gCategories, gMatchList, gStatusText, gMatches

    q := Trim(StrLower(query))
    matches := []
    fieldCount := 0
    promptCount := 0

    if (q = "") {
        ranked := []
        idx := 0

        if !gData.Has("prompts") {
            gData["prompts"] := []
        }
        for row in gData["prompts"] {
            idx += 1
            key := row["key"]
            count := (gUsage.Has("prompts") && gUsage["prompts"].Has(key)) ? gUsage["prompts"][key] : 0
            ranked.Push(Map("index", idx, "count", count, "row", row))
        }

        loop ranked.Length - 1 {
            i := A_Index
            loop ranked.Length - i {
                j := A_Index
                left := ranked[j]
                right := ranked[j + 1]
                if (right["count"] > left["count"]) || (right["count"] = left["count"] && right["index"] < left["index"]) {
                    ranked[j] := right
                    ranked[j + 1] := left
                }
            }
        }

        maxN := Min(5, ranked.Length)
        loop maxN {
            row := ranked[A_Index]["row"]
            matches.Push(Map("type", "提示词", "cat_id", "prompts", "key", row["key"], "value", row["value"]))
        }
        promptCount := matches.Length
    } else {
        for cat in gCategories {
            catId := cat["id"]
            catName := cat["name"]
            if !gData.Has(catId) {
                continue
            }
            for row in gData[catId] {
                if IsMatch(q, row["key"], row["value"]) {
                    matches.Push(Map("type", catName, "cat_id", catId, "key", row["key"], "value", row["value"]))
                    if (catId = "fields") {
                        fieldCount += 1
                    } else if (catId = "prompts") {
                        promptCount += 1
                    }
                }
            }
        }
    }

    gMatches := matches
    gMatchList.Delete()

    for idx, row in matches {
        preview := row["value"]
        if (StrLen(preview) > 30) {
            preview := SubStr(preview, 1, 30) "..."
        }
        keyLabel := row["key"]
        heat := GetUsageCountByCategory(row["cat_id"], row["key"])
        gMatchList.Add(, keyLabel, preview, heat)
    }

    if (matches.Length > 0) {
        gMatchList.Modify(1, "Select Focus")
    }

    if (q = "") {
        gStatusText.Value := "默认展示：提示词 Top " matches.Length "（按使用频率）"
    } else {
        gStatusText.Value := "找到 " matches.Length " 个匹配项  ·  字段 " fieldCount "  ·  提示词 " promptCount
    }
}

IncreaseUsage(catId, key) {
    global gUsage, gBehavior, gUsesSinceAutoRefresh
    if !gUsage.Has(catId) {
        gUsage[catId] := Map()
    }
    cur := gUsage[catId].Has(key) ? gUsage[catId][key] : 0
    gUsage[catId][key] := cur + 1
    SaveUsageCounts()

    gUsesSinceAutoRefresh += 1
    if gBehavior["auto_refresh_enabled"] && (gUsesSinceAutoRefresh >= gBehavior["refresh_every_uses"]) {
        gUsesSinceAutoRefresh := 0
        MaybeRefreshDefaultMatches("usage")
    }
}

OnMatchDoubleClick(*) {
    UseCurrentSelection()
}

MoveListSelection(step) {
    global gMatchList, gMatches

    if (gMatches.Length = 0) {
        return
    }

    cur := gMatchList.GetNext(0, "Focused")
    if !cur {
        cur := gMatchList.GetNext()
    }
    if !cur {
        cur := 1
    }

    next := cur + step
    if (next < 1) {
        next := gMatches.Length
    } else if (next > gMatches.Length) {
        next := 1
    }

    gMatchList.Modify(0, "-Select")
    gMatchList.Modify(next, "Select Focus")
    gMatchList.Modify(next, "Vis")
}

UseCurrentSelection() {
    global gMatchList, gMatches

    row := gMatchList.GetNext(0, "Focused")
    if !row {
        row := gMatchList.GetNext()
    }
    if !row {
        SoundBeep(1000)
        return
    }

    UseMatchedRow(gMatches[row])
}

UseMatchedRow(selected) {
    IncreaseUsage(selected["cat_id"], selected["key"])
    currentUsage := GetUsageCountByCategory(selected["cat_id"], selected["key"])
    WriteLog("selection_confirm", "key=" selected["key"] " type=" selected["type"])
    WriteLog("usage_update", "key=" selected["key"] " type=" selected["type"] " count=" currentUsage)
    InsertValueToTarget(selected["value"])
}

InsertValueToTarget(text) {
    global gLastTargetHwnd

    HidePanel()

    if !WinExist("ahk_id " gLastTargetHwnd) {
        WriteLog("insert_failed", "target window missing")
        MsgBox("未找到目标输入窗口，无法回填。")
        return
    }

    oldClip := ClipboardAll()
    A_Clipboard := ""
    A_Clipboard := text
    if !ClipWait(0.4) {
        WriteLog("insert_failed", "clipboard write failed")
        MsgBox("写入剪贴板失败。")
        return
    }

    WinActivate("ahk_id " gLastTargetHwnd)
    WinWaitActive("ahk_id " gLastTargetHwnd, , 0.6)
    Send("^v")
    Sleep(80)

    A_Clipboard := oldClip
    WriteLog("insert_success", "chars=" StrLen(text))
}

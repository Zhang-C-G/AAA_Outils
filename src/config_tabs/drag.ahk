; Config tabs submodule: drag reorder

RegisterConfigTabDragHooks() {
    global gTabDragHooked
    if gTabDragHooked {
        return
    }
    OnMessage(0x201, OnConfigLButtonDown) ; WM_LBUTTONDOWN
    OnMessage(0x202, OnConfigLButtonUp)   ; WM_LBUTTONUP
    gTabDragHooked := true
}

OnConfigLButtonDown(wParam, lParam, msg, hwnd) {
    global gConfigGui, gConfigTabsCtrl, gTabDragActive, gTabDragFrom, gCategories

    if !IsObject(gConfigGui) || !IsObject(gConfigTabsCtrl) {
        return
    }
    if (hwnd != gConfigGui.Hwnd) {
        return
    }

    MouseGetPos(, , &winHwnd, &ctrlHwnd, 2)
    if (winHwnd != gConfigGui.Hwnd || ctrlHwnd != gConfigTabsCtrl.Hwnd) {
        return
    }

    fromIndex := GetTabIndexUnderMouse(gConfigTabsCtrl.Hwnd)
    if (fromIndex < 1 || fromIndex > gCategories.Length) {
        return
    }

    gTabDragActive := true
    gTabDragFrom := fromIndex
}

OnConfigLButtonUp(wParam, lParam, msg, hwnd) {
    global gConfigGui, gConfigTabsCtrl, gTabDragActive, gTabDragFrom, gCategories

    if !gTabDragActive {
        return
    }
    gTabDragActive := false

    if !IsObject(gConfigGui) || !IsObject(gConfigTabsCtrl) {
        gTabDragFrom := 0
        return
    }
    if (hwnd != gConfigGui.Hwnd) {
        gTabDragFrom := 0
        return
    }

    MouseGetPos(, , &winHwnd, &ctrlHwnd, 2)
    if (winHwnd != gConfigGui.Hwnd || ctrlHwnd != gConfigTabsCtrl.Hwnd) {
        gTabDragFrom := 0
        return
    }

    toIndex := GetTabIndexUnderMouse(gConfigTabsCtrl.Hwnd)
    fromIndex := gTabDragFrom
    gTabDragFrom := 0

    if (toIndex < 1 || toIndex > gCategories.Length || toIndex = fromIndex) {
        return
    }

    MoveCategoryTab(fromIndex, toIndex)
}

GetTabIndexUnderMouse(tabHwnd) {
    MouseGetPos(&sx, &sy)

    pt := Buffer(8, 0)
    NumPut("Int", sx, pt, 0)
    NumPut("Int", sy, pt, 4)
    DllCall("ScreenToClient", "Ptr", tabHwnd, "Ptr", pt.Ptr)

    hti := Buffer(16, 0)
    NumPut("Int", NumGet(pt, 0, "Int"), hti, 0)
    NumPut("Int", NumGet(pt, 4, "Int"), hti, 4)

    idx0 := SendMessage(0x130D, 0, hti.Ptr, , "ahk_id " tabHwnd) ; TCM_HITTEST
    return (idx0 = -1 || idx0 = 0xFFFFFFFF) ? 0 : (idx0 + 1)
}

MoveCategoryTab(fromIndex, toIndex) {
    global gCategories

    if (fromIndex < 1 || fromIndex > gCategories.Length || toIndex < 1 || toIndex > gCategories.Length) {
        return
    }

    moving := gCategories.RemoveAt(fromIndex)
    gCategories.InsertAt(toIndex, moving)

    SaveData()
    WriteLog("category_reorder", "from=" fromIndex " to=" toIndex " id=" moving["id"])
    RebuildConfigWindow(moving["id"])
}

; Effects and input language helpers

SwitchToEnglishLayout(hwnd) {
    ; 0x50 = WM_INPUTLANGCHANGEREQUEST, 0x0409 = English (US)
    PostMessage(0x50, 0, 0x04090409, , "ahk_id " hwnd)
}

PanelFadeIn() {
    global gPanelGui
    hwndTitle := "ahk_id " gPanelGui.Hwnd
    WinSetTransparent(1, hwndTitle)
    Loop 10 {
        alpha := A_Index * 23
        WinSetTransparent(alpha, hwndTitle)
        Sleep(10)
    }
    WinSetTransparent(235, hwndTitle)
}

PanelFadeOut() {
    global gPanelGui
    if !gPanelGui.Hwnd {
        return
    }

    hwndTitle := "ahk_id " gPanelGui.Hwnd
    Loop 6 {
        alpha := 235 - (A_Index * 35)
        if (alpha < 30) {
            alpha := 30
        }
        WinSetTransparent(alpha, hwndTitle)
        Sleep(8)
    }
    WinSetTransparent(255, hwndTitle)
}

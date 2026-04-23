ReloadCapturePanel() {
    global gCaptureSettings, gCaptureEndpointEdit, gCaptureQrCheckbox, gCapturePathText, gCaptureLinkEdit, gCaptureLastPath, gCaptureBridgePortEdit
    if !IsObject(gCaptureEndpointEdit) {
        return
    }
    gCaptureBridgePortEdit.Value := gCaptureSettings["bridge_port"]
    gCaptureEndpointEdit.Value := gCaptureSettings["upload_endpoint"]
    gCaptureQrCheckbox.Value := gCaptureSettings["open_qr_after_upload"]
    gCapturePathText.Value := gCaptureLastPath
    UpdateCaptureBridgeStatusUi()
    SetTimer(UpdateCaptureBridgeStatusUi, 1500)
    if IsObject(gCaptureLinkEdit) {
        gCaptureLinkEdit.Value := ""
    }
}

SaveCaptureSettingsFromGui() {
    global gCaptureSettings, gCaptureEndpointEdit, gCaptureQrCheckbox, gCaptureBridgePortEdit
    if !IsObject(gCaptureEndpointEdit) {
        return
    }
    if IsObject(gCaptureBridgePortEdit) {
        pRaw := Trim(gCaptureBridgePortEdit.Value)
        if RegExMatch(pRaw, "^\d+$") {
            p := Integer(pRaw)
            if (p >= 1024 && p <= 65535) {
                gCaptureSettings["bridge_port"] := p
            }
        }
    }
    endpoint := Trim(gCaptureEndpointEdit.Value)
    if (endpoint = "") {
        endpoint := "https://0x0.st"
    }
    gCaptureSettings["upload_endpoint"] := endpoint
    gCaptureSettings["open_qr_after_upload"] := gCaptureQrCheckbox.Value ? 1 : 0
}

OnSaveCaptureSettings(*) {
    global gCaptureSettings
    SaveCaptureSettingsFromGui()
    SaveData()
    WriteLog("capture_settings_save", "endpoint=" gCaptureSettings["upload_endpoint"])
    MsgBox("Capture settings saved")
}

OnCaptureScreen(*) {
    global gCaptureLastPath, gCapturePathText
    path := GenerateCapturePath()
    ok := CaptureFullScreen(path)
    if !ok {
        WriteLog("capture_create_failed", "path=" path)
        MsgBox("Capture failed")
        return
    }
    gCaptureLastPath := path
    try {
        PublishLatestCapture(path)
    }
    if IsObject(gCapturePathText) {
        gCapturePathText.Value := path
    }
    WriteLog("capture_create", "path=" path)
}

OnUploadCaptureToPhone(*) {
    global gCaptureLastPath, gCaptureSettings, gCaptureLinkEdit
    if (gCaptureLastPath = "" || !FileExist(gCaptureLastPath)) {
        MsgBox("Please capture screen first")
        return
    }

    SaveCaptureSettingsFromGui()
    endpoint := gCaptureSettings["upload_endpoint"]
    url := UploadCaptureFile(gCaptureLastPath, endpoint)
    if (url = "" || !InStr(url, "http")) {
        WriteLog("capture_upload_failed", "path=" gCaptureLastPath " endpoint=" endpoint)
        MsgBox("Upload failed. Check endpoint/network.")
        return
    }

    if IsObject(gCaptureLinkEdit) {
        gCaptureLinkEdit.Value := url
    }
    A_Clipboard := url
    WriteLog("capture_upload_success", "url=" url)

    if gCaptureSettings["open_qr_after_upload"] {
        qrUrl := "https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=" UriEncode(url)
        Run(qrUrl)
        WriteLog("capture_qr_open", "url=" qrUrl)
    }

    MsgBox("Uploaded and URL copied to clipboard")
}

OnCopyCaptureUrl(*) {
    global gCaptureLinkEdit
    if !IsObject(gCaptureLinkEdit) {
        return
    }
    txt := Trim(gCaptureLinkEdit.Value)
    if (txt = "") {
        return
    }
    A_Clipboard := txt
    WriteLog("capture_url_copy", "url=" txt)
}

OnOpenCaptureFolder(*) {
    global gCaptureDir
    EnsureCaptureStore()
    Run(gCaptureDir)
}

OnStartCaptureBridge(*) {
    global gCaptureSettings, gCaptureBridgeUrlEdit
    SaveCaptureSettingsFromGui()
    ok := StartCaptureBridge(gCaptureSettings["bridge_port"])
    if !ok {
        MsgBox("Start link failed. Try another port.")
        return
    }
    url := GetCaptureBridgeUrl(gCaptureSettings["bridge_port"])
    if IsObject(gCaptureBridgeUrlEdit) {
        gCaptureBridgeUrlEdit.Value := url
    }
    WriteLog("capture_bridge_start", "url=" url)
    UpdateCaptureBridgeStatusUi()
}

OnStopCaptureBridge(*) {
    StopCaptureBridge()
    WriteLog("capture_bridge_stop", "manual")
    UpdateCaptureBridgeStatusUi()
}

OnOpenPhonePage(*) {
    global gCaptureSettings, gCaptureBridgePidFile
    SaveCaptureSettingsFromGui()
    if !FileExist(gCaptureBridgePidFile) {
        StartCaptureBridge(gCaptureSettings["bridge_port"])
    }
    url := GetCaptureBridgeUrl(gCaptureSettings["bridge_port"])
    Run(url)
    WriteLog("capture_phone_open", "url=" url)
    UpdateCaptureBridgeStatusUi()
}

UpdateCaptureBridgeStatusUi(*) {
    global gCaptureSettings, gCapturePcStatusText, gCapturePhoneStatusText, gCaptureBridgeUrlEdit
    if !IsObject(gCapturePcStatusText) {
        return
    }

    status := ReadBridgeStatus()
    url := GetCaptureBridgeUrl(gCaptureSettings["bridge_port"])
    if IsObject(gCaptureBridgeUrlEdit) {
        gCaptureBridgeUrlEdit.Value := url
    }

    pcAlive := IsBridgeProcessAlive()
    phoneConnected := false
    if (status["state"] = "connected" && status["last_seen"] != "0") {
        diff := 999
        try diff := DateDiff(A_Now, status["last_seen"], "Seconds")
        phoneConnected := (Abs(diff) <= 8)
    }

    if pcAlive {
        gCapturePcStatusText.Text := "PC: CONNECTED"
        gCapturePcStatusText.Opt("c22AA44")
    } else {
        gCapturePcStatusText.Text := "PC: DISCONNECTED"
        gCapturePcStatusText.Opt("cCC3333")
    }

    if phoneConnected {
        gCapturePhoneStatusText.Text := "PHONE: CONNECTED"
        gCapturePhoneStatusText.Opt("c22AA44")
    } else if (status["state"] = "waiting" || status["state"] = "starting") {
        gCapturePhoneStatusText.Text := "PHONE: WAITING"
        gCapturePhoneStatusText.Opt("cC99922")
    } else {
        gCapturePhoneStatusText.Text := "PHONE: DISCONNECTED"
        gCapturePhoneStatusText.Opt("cCC3333")
    }
}

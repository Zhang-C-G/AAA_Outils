BuildCaptureModeBody() {
    global gConfigGui, gTheme, gCaptureEndpointEdit, gCaptureQrCheckbox, gCapturePathText, gCaptureLinkEdit
    global gCaptureBridgePortEdit, gCapturePcStatusText, gCapturePhoneStatusText, gCaptureBridgeUrlEdit

    gConfigGui.AddText("x40 y130 w860 h24 c" gTheme["text_primary"], "Capture To Phone")
    gConfigGui.AddText("x40 y156 w860 h20 c" gTheme["text_hint"], "Capture screen, upload, then open QR for phone scan")

    gConfigGui.AddText("x40 y190 w120 h22 c" gTheme["text_primary"], "Bridge Port")
    gCaptureBridgePortEdit := gConfigGui.AddEdit("x160 y186 w120 h28 vCaptureBridgePort c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    gConfigGui.AddText("x300 y190 w100 h22 c" gTheme["text_primary"], "Upload URL")
    gCaptureEndpointEdit := gConfigGui.AddEdit("x160 y186 w560 h28 vCaptureEndpoint c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    gCaptureEndpointEdit.Move(410, 186, 310, 28)
    gCaptureQrCheckbox := gConfigGui.AddCheckBox("x740 y190 w200 h22 c" gTheme["text_primary"], "Open QR after upload")

    gCapturePcStatusText := gConfigGui.AddText("x40 y226 w240 h22 c" gTheme["text_hint"], "PC: DISCONNECTED")
    gCapturePhoneStatusText := gConfigGui.AddText("x40 y248 w240 h22 c" gTheme["text_hint"], "PHONE: DISCONNECTED")
    gCaptureBridgeUrlEdit := gConfigGui.AddEdit("x290 y222 w430 h28 ReadOnly c" gTheme["text_on_light"] " Background" gTheme["bg_header"])

    startBridgeBtn := gConfigGui.AddButton("x730 y222 w100 h28 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "Start Link")
    startBridgeBtn.SetFont("s9 w700", "Segoe UI")
    startBridgeBtn.OnEvent("Click", OnStartCaptureBridge)
    stopBridgeBtn := gConfigGui.AddButton("x840 y222 w100 h28 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Stop Link")
    stopBridgeBtn.SetFont("s9 w700", "Segoe UI")
    stopBridgeBtn.OnEvent("Click", OnStopCaptureBridge)

    captureBtn := gConfigGui.AddButton("x290 y254 w180 h38 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "Capture Screen")
    captureBtn.SetFont("s10 w700", "Segoe UI")
    captureBtn.OnEvent("Click", OnCaptureScreen)

    uploadBtn := gConfigGui.AddButton("x480 y254 w180 h38 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "Upload To Phone")
    uploadBtn.SetFont("s10 w700", "Segoe UI")
    uploadBtn.OnEvent("Click", OnUploadCaptureToPhone)

    openPhoneBtn := gConfigGui.AddButton("x670 y254 w130 h38 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Open Phone")
    openPhoneBtn.SetFont("s10 w700", "Segoe UI")
    openPhoneBtn.OnEvent("Click", OnOpenPhonePage)

    saveCfgBtn := gConfigGui.AddButton("x810 y254 w130 h38 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Save Capture")
    saveCfgBtn.SetFont("s10 w700", "Segoe UI")
    saveCfgBtn.OnEvent("Click", OnSaveCaptureSettings)

    folderBtn := gConfigGui.AddButton("x810 y296 w130 h34 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Open Folder")
    folderBtn.SetFont("s10 w700", "Segoe UI")
    folderBtn.OnEvent("Click", OnOpenCaptureFolder)

    gConfigGui.AddText("x40 y340 w860 h20 c" gTheme["text_hint"], "Latest capture")
    gCapturePathText := gConfigGui.AddEdit("x40 y364 w900 h28 ReadOnly c" gTheme["text_on_light"] " Background" gTheme["bg_header"])

    gConfigGui.AddText("x40 y404 w860 h20 c" gTheme["text_hint"], "Phone URL")
    gCaptureLinkEdit := gConfigGui.AddEdit("x40 y428 w900 h28 ReadOnly c" gTheme["text_on_light"] " Background" gTheme["bg_header"])

    copyBtn := gConfigGui.AddButton("x40 y468 w180 h34 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Copy URL")
    copyBtn.SetFont("s9 w700", "Segoe UI")
    copyBtn.OnEvent("Click", OnCopyCaptureUrl)
}


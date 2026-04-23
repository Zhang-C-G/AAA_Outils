BuildAssistantModeBody() {
    global gConfigGui, gTheme
    global gAssistantEnabledCheckbox, gAssistantApiEndpointEdit, gAssistantApiKeyEdit, gAssistantModelEdit
    global gAssistantPromptEdit, gAssistantOpacitySlider, gAssistantOpacityLabel, gAssistantResultEdit

    gConfigGui.AddText("x40 y130 w860 h24 c" gTheme["text_primary"], "Screenshot Assistant")
    gConfigGui.AddText("x40 y156 w860 h20 c" gTheme["text_hint"], "Capture by hotkey, send to model API, show answer in floating window.")
    gConfigGui.AddText("x40 y176 w860 h20 c" gTheme["text_hint"], "本地测试可使用 endpoint=mock://local 或 model=mock-local（不调用外部 API）。")

    gAssistantEnabledCheckbox := gConfigGui.AddCheckBox("x40 y198 w220 h22 c" gTheme["text_primary"], "启用截图问答助手")

    gConfigGui.AddText("x40 y230 w120 h22 c" gTheme["text_primary"], "API Endpoint")
    gAssistantApiEndpointEdit := gConfigGui.AddEdit("x160 y226 w780 h28 c" gTheme["text_on_light"] " Background" gTheme["bg_header"])

    gConfigGui.AddText("x40 y266 w120 h22 c" gTheme["text_primary"], "API Key")
    gAssistantApiKeyEdit := gConfigGui.AddEdit("x160 y262 w780 h28 Password c" gTheme["text_on_light"] " Background" gTheme["bg_header"])

    gConfigGui.AddText("x40 y302 w120 h22 c" gTheme["text_primary"], "Model")
    gAssistantModelEdit := gConfigGui.AddEdit("x160 y298 w380 h28 c" gTheme["text_on_light"] " Background" gTheme["bg_header"])

    gAssistantOpacityLabel := gConfigGui.AddText("x560 y302 w160 h22 c" gTheme["text_primary"], "透明度")
    gAssistantOpacitySlider := gConfigGui.AddSlider("x640 y298 w300 h28 Range35-100 ToolTip", 92)
    gAssistantOpacitySlider.OnEvent("Change", OnAssistantOpacitySliderChanged)

    gConfigGui.AddText("x40 y338 w120 h22 c" gTheme["text_primary"], "Prompt")
    gAssistantPromptEdit := gConfigGui.AddEdit("x160 y334 w780 h108 +Multi c" gTheme["text_on_light"] " Background" gTheme["bg_header"])

    runBtn := gConfigGui.AddButton("x160 y454 w220 h36 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "Run Capture + Ask")
    runBtn.SetFont("s10 w700", "Segoe UI")
    runBtn.OnEvent("Click", OnAssistantRunNow)

    mockBtn := gConfigGui.AddButton("x392 y454 w220 h36 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Run Local Mock")
    mockBtn.SetFont("s10 w700", "Segoe UI")
    mockBtn.OnEvent("Click", OnAssistantRunMock)

    saveBtn := gConfigGui.AddButton("x624 y454 w220 h36 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "Save Assistant")
    saveBtn.SetFont("s10 w700", "Segoe UI")
    saveBtn.OnEvent("Click", OnSaveAssistantSettings)

    gConfigGui.AddText("x40 y504 w900 h20 c" gTheme["text_hint"], "Last answer")
    gAssistantResultEdit := gConfigGui.AddEdit("x40 y528 w900 h220 +Multi ReadOnly c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
}

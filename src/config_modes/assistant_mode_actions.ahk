ReloadAssistantPanel() {
    global gAssistantSettings, gAssistantEnabledCheckbox, gAssistantApiEndpointEdit, gAssistantApiKeyEdit
    global gAssistantModelEdit, gAssistantPromptEdit, gAssistantOpacitySlider, gAssistantOpacityLabel, gAssistantResultEdit, gAssistantLastResult

    if !IsObject(gAssistantApiEndpointEdit) {
        return
    }

    gAssistantEnabledCheckbox.Value := gAssistantSettings["enabled"]
    gAssistantApiEndpointEdit.Value := gAssistantSettings["api_endpoint"]
    gAssistantApiKeyEdit.Value := gAssistantSettings["api_key"]
    gAssistantModelEdit.Value := gAssistantSettings["model"]
    gAssistantPromptEdit.Value := gAssistantSettings["prompt"]

    opacity := ClampAssistantOpacity(gAssistantSettings["overlay_opacity"])
    gAssistantOpacitySlider.Value := opacity
    gAssistantOpacityLabel.Text := "透明度 " opacity "%"

    if IsObject(gAssistantResultEdit) {
        gAssistantResultEdit.Value := gAssistantLastResult
    }
}

SaveAssistantSettingsFromGui() {
    global gAssistantSettings, gAssistantEnabledCheckbox, gAssistantApiEndpointEdit, gAssistantApiKeyEdit
    global gAssistantModelEdit, gAssistantPromptEdit, gAssistantOpacitySlider

    if !IsObject(gAssistantApiEndpointEdit) {
        return
    }

    endpoint := Trim(gAssistantApiEndpointEdit.Value)
    if (endpoint = "") {
        endpoint := "https://ark.cn-beijing.volces.com/api/v3/responses"
    }

    model := Trim(gAssistantModelEdit.Value)
    if (model = "") {
        model := "doubao-seed-2-0-lite-260215"
    }

    prompt := Trim(gAssistantPromptEdit.Value)
    if (prompt = "") {
        prompt := "编程题：直接给完整可运行代码，并在代码框中输出；随后对核心思路做简短说明。选择题：先写15字以内题目总结，再直接给答案。"
    }

    gAssistantSettings["enabled"] := gAssistantEnabledCheckbox.Value ? 1 : 0
    gAssistantSettings["api_endpoint"] := endpoint
    gAssistantSettings["api_key"] := Trim(gAssistantApiKeyEdit.Value)
    gAssistantSettings["model"] := model
    gAssistantSettings["prompt"] := prompt
    gAssistantSettings["overlay_opacity"] := ClampAssistantOpacity(gAssistantOpacitySlider.Value)
    SetAssistantActiveTemplatePrompt(gAssistantSettings, prompt)
}

OnAssistantOpacitySliderChanged(ctrl, *) {
    global gAssistantOpacityLabel
    val := ClampAssistantOpacity(ctrl.Value)
    gAssistantOpacityLabel.Text := "透明度 " val "%"
}

OnSaveAssistantSettings(*) {
    global gAssistantSettings
    SaveAssistantSettingsFromGui()
    SaveData()
    WriteLog("assistant_settings_save", "endpoint=" gAssistantSettings["api_endpoint"] " model=" gAssistantSettings["model"])
    MsgBox("Assistant settings saved")
}

OnAssistantRunNow(*) {
    global gAssistantResultEdit
    SaveAssistantSettingsFromGui()

    result := StartAssistantCaptureFlow(false)
    if !result["ok"] {
        MsgBox("助手执行失败：" result["error"])
        return
    }

    if IsObject(gAssistantResultEdit) {
        gAssistantResultEdit.Value := result["text"]
    }
}

OnAssistantRunMock(*) {
    global gAssistantSettings, gAssistantApiEndpointEdit, gAssistantModelEdit, gAssistantResultEdit

    if IsObject(gAssistantApiEndpointEdit) {
        gAssistantApiEndpointEdit.Value := "mock://local"
    }
    if IsObject(gAssistantModelEdit) {
        gAssistantModelEdit.Value := "mock-local"
    }

    SaveAssistantSettingsFromGui()
    gAssistantSettings["api_endpoint"] := "mock://local"
    gAssistantSettings["model"] := "mock-local"

    result := StartAssistantCaptureFlow(false)
    if !result["ok"] {
        MsgBox("本地模拟测试失败：" result["error"])
        return
    }

    if IsObject(gAssistantResultEdit) {
        gAssistantResultEdit.Value := result["text"]
    }
    MsgBox("本地模拟测试完成。")
}

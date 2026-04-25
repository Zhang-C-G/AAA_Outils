; Assistant settings + screenshot QA request

GetAssistantDefaultPrompt() {
    return "编程题：直接给编程完整答案，代码写在代码框中，并对核心部分做简短解释。选择题：先写15字以内题目总结，再直接给答案。"
}

GetAssistantDefaultTemplates() {
    return [Map("name", "default_template", "prompt", GetAssistantDefaultPrompt())]
}
IsAssistantPromptBroken(text) {
    t := Trim(text)
    if (t = "") {
        return true
    }
    if RegExMatch(t, "^[\?\？]+$") {
        return true
    }
    if (InStr(t, "???") || InStr(t, "？？？")) {
        return true
    }
    return false
}

ClampAssistantOpacity(opacity) {
    allowed := [20, 50, 75, 100]
    value := 100
    try value := Integer(opacity)
    best := allowed[1]
    bestDiff := Abs(value - best)
    for candidate in allowed {
        diff := Abs(value - candidate)
        if (diff < bestDiff || (diff = bestDiff && candidate > best)) {
            best := candidate
            bestDiff := diff
        }
    }
    return best
}

ClampAssistantRatePerHour(limitValue) {
    v := 100
    try v := Integer(limitValue)
    return Min(10000, Max(1, v))
}

EnsureAssistantTemplates(settings) {
    templates := []
    seen := Map()

    if settings.Has("templates") {
        for t in settings["templates"] {
            name := Trim(t["name"])
            prompt := Trim(t["prompt"])
            if (name = "") {
                continue
            }
            if (prompt = "") {
                prompt := GetAssistantDefaultPrompt()
            }
            low := StrLower(name)
            if seen.Has(low) {
                continue
            }
            seen[low] := true
            if IsAssistantPromptBroken(prompt) {
                prompt := GetAssistantDefaultPrompt()
            }
            templates.Push(Map("name", name, "prompt", prompt))
        }
    }

    if (templates.Length = 0) {
        templates := GetAssistantDefaultTemplates()
    }

    active := settings.Has("active_template") ? Trim(settings["active_template"]) : ""
    if (active = "") {
        active := templates[1]["name"]
    }

    found := false
    for t in templates {
        if (t["name"] = active) {
            found := true
            break
        }
    }
    if !found {
        active := templates[1]["name"]
    }

    settings["templates"] := templates
    settings["active_template"] := active
    settings["prompt"] := GetAssistantPromptByTemplate(settings)
}

GetAssistantPromptByTemplate(settings) {
    if settings.Has("templates") {
        active := settings.Has("active_template") ? settings["active_template"] : ""
        for t in settings["templates"] {
            if (t["name"] = active) {
                return t["prompt"]
            }
        }
        if (settings["templates"].Length > 0) {
            return settings["templates"][1]["prompt"]
        }
    }
    if settings.Has("prompt") && Trim(settings["prompt"]) != "" {
        return settings["prompt"]
    }
    return GetAssistantDefaultPrompt()
}

SetAssistantActiveTemplatePrompt(settings, promptText) {
    EnsureAssistantTemplates(settings)
    active := settings["active_template"]
    prompt := Trim(promptText)
    if (prompt = "") {
        prompt := GetAssistantDefaultPrompt()
    }

    for t in settings["templates"] {
        if (t["name"] = active) {
            t["prompt"] := prompt
            settings["prompt"] := prompt
            return
        }
    }

    settings["templates"].Push(Map("name", active, "prompt", prompt))
    settings["prompt"] := prompt
}

GetAssistantDefaultSettings() {
    return Map(
        "enabled", 1,
        "api_endpoint", "https://ark.cn-beijing.volces.com/api/v3/responses",
        "api_key", "",
        "api_key_protected", "",
        "has_api_key", 0,
        "model", "doubao-seed-2-0-lite-260215",
        "prompt", GetAssistantDefaultPrompt(),
        "active_template", "default_template",
        "templates", GetAssistantDefaultTemplates(),
        "overlay_opacity", 75,
        "enhanced_capture_mode", 0,
        "disable_copy", 1,
        "voice_input_enabled", 0,
        "rate_limit_enabled", 1,
        "rate_limit_per_hour", 100,
        "voice_input_provider", "local_windows",
        "voice_input_endpoint", "",
        "voice_input_model", ""
    )
}

GetAssistantVoiceInputProvider(settings) {
    provider := ""
    try provider := Trim(settings["voice_input_provider"])
    if (provider = "") {
        provider := "local_windows"
    }
    return provider
}

GetAssistantVoiceProviderLabel(settings) {
    provider := StrLower(GetAssistantVoiceInputProvider(settings))
    switch provider {
        case "local_windows":
            return "本地语音识别"
        case "mock_local":
            return "本地模拟语音识别"
        default:
            return provider
    }
}

BuildAssistantMockTextAnswer(queryText, settings) {
    template := settings.Has("active_template") ? settings["active_template"] : "default_template"
    ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    text := "[本地模拟文本问答，不调用外部 API]"
        . "`n模板: " template
        . "`n时间: " ts
        . "`n`n输入内容:"
        . "`n" Trim(queryText)
        . "`n`n模拟回答:"
        . "`n文本链路正常: 热键 -> 语音识别 -> 文本问答 -> 悬浮窗展示。"
    return text
}

IsAssistantMockMode(settings) {
    endpoint := StrLower(Trim(settings["api_endpoint"]))
    model := StrLower(Trim(settings["model"]))
    return (endpoint = "mock://local" || model = "mock-local")
}

BuildAssistantMockAnswer(imagePath, settings) {
    template := settings.Has("active_template") ? settings["active_template"] : "default_template"
    ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    text := "[本地模拟模式，不调用外部 API]"
        . "`n模板: " template
        . "`n截图: " imagePath
        . "`n时间: " ts
        . "`n`n模拟回答:"
        . "`n链路正常: 快捷键 -> 截图 -> 模板选择 -> 悬浮窗展示。"
        . "`n可继续使用 Alt+Up / Alt+Down 测试悬浮窗滚动。"
    return text
}

LoadAssistantSettings() {
    global gDataFile
    settings := GetAssistantDefaultSettings()
    raw := LoadSection(gDataFile, "Assistant")
    legacyApiKey := ""

    for row in raw {
        key := row["key"]
        value := Trim(row["value"])
        switch key {
            case "enabled":
                settings["enabled"] := 1
            case "api_endpoint":
                if (value != "") {
                    settings["api_endpoint"] := value
                }
            case "api_key":
                legacyApiKey := value
            case "api_key_protected":
                settings["api_key_protected"] := value
            case "model":
                if (value != "") {
                    settings["model"] := value
                }
            case "prompt":
                if (value != "" && !IsAssistantPromptBroken(value)) {
                    settings["prompt"] := value
                }
            case "active_template":
                settings["active_template"] := value
            case "overlay_opacity":
                if RegExMatch(value, "^\d+$") {
                    settings["overlay_opacity"] := ClampAssistantOpacity(Integer(value))
                }
            case "enhanced_capture_mode":
                settings["enhanced_capture_mode"] := (value = "1" || StrLower(value) = "true") ? 1 : 0
            case "disable_copy":
                settings["disable_copy"] := (value = "1" || StrLower(value) = "true") ? 1 : 0
            case "voice_input_enabled":
                settings["voice_input_enabled"] := (value = "1" || StrLower(value) = "true") ? 1 : 0
            case "rate_limit_enabled":
                settings["rate_limit_enabled"] := (value = "1" || StrLower(value) = "true") ? 1 : 0
            case "rate_limit_per_hour":
                if RegExMatch(value, "^\d+$") {
                    settings["rate_limit_per_hour"] := ClampAssistantRatePerHour(Integer(value))
                }
            case "voice_input_provider":
                if (value != "") {
                    settings["voice_input_provider"] := value
                }
            case "voice_input_endpoint":
                settings["voice_input_endpoint"] := value
            case "voice_input_model":
                settings["voice_input_model"] := value
        }
    }

    protected := Trim(settings["api_key_protected"])
    if (protected != "") {
        plain := UnprotectAssistantSecret(protected)
        if (plain != "") {
            settings["api_key"] := plain
        }
    } else if (legacyApiKey != "") {
        settings["api_key"] := legacyApiKey
        settings["api_key_protected"] := ProtectAssistantSecret(legacyApiKey)
    }

    settings["has_api_key"] := (Trim(settings["api_key"]) != "" || Trim(settings["api_key_protected"]) != "") ? 1 : 0

    tmplRows := LoadSection(gDataFile, "AssistantTemplates")
    if (tmplRows.Length > 0) {
        templates := []
        for row in tmplRows {
            name := Trim(row["key"])
            prompt := Trim(row["value"])
            if (name = "") {
                continue
            }
            if IsAssistantPromptBroken(prompt) {
                prompt := GetAssistantDefaultPrompt()
            }
            templates.Push(Map("name", name, "prompt", prompt))
        }
        settings["templates"] := templates
    }

    settings["overlay_opacity"] := ClampAssistantOpacity(settings["overlay_opacity"])
    settings["enabled"] := 1
    settings["enhanced_capture_mode"] := settings.Has("enhanced_capture_mode") ? (settings["enhanced_capture_mode"] ? 1 : 0) : 0
    settings["disable_copy"] := settings.Has("disable_copy") ? (settings["disable_copy"] ? 1 : 0) : 1
    settings["voice_input_enabled"] := settings.Has("voice_input_enabled") ? (settings["voice_input_enabled"] ? 1 : 0) : 0
    settings["rate_limit_per_hour"] := ClampAssistantRatePerHour(settings["rate_limit_per_hour"])
    EnsureAssistantTemplates(settings)
    return settings
}

RequestAssistantAnswerFromImage(imagePath, settings, onProgress := "") {
    if IsAssistantMockMode(settings) {
        return Map("ok", 1, "text", BuildAssistantMockAnswer(imagePath, settings), "reasoning", "", "streamed", 0, "error", "")
    }

    streamRes := RequestAssistantAnswerFromImageStream(imagePath, settings, onProgress)
    if streamRes["ok"] {
        return streamRes
    }

    WriteLog("assistant_stream_fallback", "reason=" streamRes["error"])
    return RequestAssistantAnswerFromImageLegacy(imagePath, settings, onProgress)
}

RequestAssistantAnswerFromText(queryText, settings, onProgress := "") {
    if IsAssistantMockMode(settings) {
        return Map("ok", 1, "text", BuildAssistantMockTextAnswer(queryText, settings), "reasoning", "", "streamed", 0, "error", "")
    }

    streamRes := RequestAssistantAnswerFromTextStream(queryText, settings, onProgress)
    if streamRes["ok"] {
        return streamRes
    }

    WriteLog("assistant_text_stream_fallback", "reason=" streamRes["error"])
    return RequestAssistantAnswerFromTextLegacy(queryText, settings, onProgress)
}

RequestAssistantAnswerFromImageLegacy(imagePath, settings, onProgress := "") {
    outPath := A_Temp "\\raccourci_assistant_out.txt"
    errPath := A_Temp "\\raccourci_assistant_err.txt"
    psPath := A_Temp "\\raccourci_assistant_request.ps1"

    endpoint := Trim(settings["api_endpoint"])
    apiKey := Trim(settings["api_key"])
    model := Trim(settings["model"])
    prompt := Trim(GetAssistantPromptByTemplate(settings))

    if (endpoint = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant endpoint is empty")
    }
    if (model = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant model is empty")
    }
    if (prompt = "") {
        prompt := GetAssistantDefaultPrompt()
    }

    prompt := StrReplace(StrReplace(prompt, "`r", " "), "`n", " ")

    script := "$ErrorActionPreference='Stop'`n"
        . "`$ep='" PsSingleQuote(endpoint) "'`n"
        . "`$k='" PsSingleQuote(apiKey) "'`n"
        . "`$model='" PsSingleQuote(model) "'`n"
        . "`$prompt='" PsSingleQuote(prompt) "'`n"
        . "`$img='" PsSingleQuote(imagePath) "'`n"
        . "`$out='" PsSingleQuote(outPath) "'`n"
        . "`$err='" PsSingleQuote(errPath) "'`n"
        . "try {`n"
        . "  `$bytes=[System.IO.File]::ReadAllBytes(`$img)`n"
        . "  `$b64=[System.Convert]::ToBase64String(`$bytes)`n"
        . "  `$imgUrl='data:image/png;base64,' + `$b64`n"
        . "  `$headers=@{}; if(`$k -ne ''){`$headers['Authorization']='Bearer ' + `$k}`n"
        . "  `$isResponses = `$ep.ToLower().Contains('/responses')`n"
        . "  if(`$isResponses){`n"
        . "    `$body=[ordered]@{`n"
        . "      model=`$model;`n"
        . "      input=@([ordered]@{role='user';content=@([ordered]@{type='input_image';image_url=`$imgUrl},[ordered]@{type='input_text';text=`$prompt})})`n"
        . "    }`n"
        . "  } else {`n"
        . "    `$body=[ordered]@{`n"
        . "      model=`$model;`n"
        . "      messages=@([ordered]@{role='user';content=@([ordered]@{type='text';text=`$prompt},[ordered]@{type='image_url';image_url=[ordered]@{url=`$imgUrl}})});`n"
        . "      temperature=0.2;`n"
        . "      max_tokens=700`n"
        . "    }`n"
        . "  }`n"
        . "  `$json=`$body | ConvertTo-Json -Depth 30`n"
        . "  `$res=Invoke-RestMethod -Method Post -Uri `$ep -Headers `$headers -ContentType 'application/json' -Body `$json`n"
        . "  `$text=''`n"
        . "  if(`$isResponses){`n"
        . "    if(-not [string]::IsNullOrWhiteSpace([string]`$res.output_text)){ `$text=[string]`$res.output_text }`n"
        . "    if([string]::IsNullOrWhiteSpace(`$text) -and `$null -ne `$res.output){`n"
        . "      foreach(`$o in `$res.output){`n"
        . "        if(`$null -ne `$o.content){`n"
        . "          foreach(`$c in `$o.content){`n"
        . "            if(`$c.type -eq 'output_text' -and `$c.text){ `$text += [string]`$c.text + [Environment]::NewLine }`n"
        . "          }`n"
        . "        }`n"
        . "      }`n"
        . "    }`n"
        . "  } else {`n"
        . "    if(`$null -ne `$res.choices -and `$res.choices.Count -gt 0){`n"
        . "      `$content=`$res.choices[0].message.content`n"
        . "      if(`$content -is [System.Array]){ foreach(`$it in `$content){ if(`$it.text){ `$text += [string]`$it.text + [Environment]::NewLine } } } else { `$text=[string]`$content }`n"
        . "    }`n"
        . "  }`n"
        . "  if([string]::IsNullOrWhiteSpace(`$text) -and `$null -ne `$res.output_text){ `$text=[string]`$res.output_text }`n"
        . "  if([string]::IsNullOrWhiteSpace(`$text)){ `$text = (`$res | ConvertTo-Json -Depth 20) }`n"
        . "  Set-Content -LiteralPath `$out -Value `$text -Encoding UTF8`n"
        . "} catch {`n"
        . "  Set-Content -LiteralPath `$err -Value `$_.Exception.Message -Encoding UTF8`n"
        . "}`n"

    if FileExist(outPath) {
        FileDelete(outPath)
    }
    if FileExist(errPath) {
        FileDelete(errPath)
    }
    if FileExist(psPath) {
        FileDelete(psPath)
    }
    FileAppend(script, psPath, "UTF-8")

    pid := 0
    try {
        Run('powershell -NoProfile -ExecutionPolicy Bypass -File "' psPath '"', , "Hide", &pid)
    } catch {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant request command failed")
    }

    startTick := A_TickCount
    if (pid > 0) {
        loop {
            if !ProcessExist(pid) {
                break
            }
            if IsObject(onProgress) {
                elapsed := Floor((A_TickCount - startTick) / 1000)
                onProgress.Call("thinking", elapsed)
            }
            Sleep(200)
        }
    } else {
        Sleep(200)
    }

    if IsObject(onProgress) {
        onProgress.Call("request_done", Floor((A_TickCount - startTick) / 1000))
    }

    if FileExist(errPath) {
        err := Trim(FileRead(errPath, "UTF-8"))
        if (err != "") {
            return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", err)
        }
    }

    if !FileExist(outPath) {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant no output")
    }

    txt := Trim(FileRead(outPath, "UTF-8"))
    if (txt = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant returned empty text")
    }
    return Map("ok", 1, "text", txt, "reasoning", "", "streamed", 0, "error", "")
}

RequestAssistantAnswerFromImageStream(imagePath, settings, onProgress := "") {
    outPath := A_Temp "\\raccourci_assistant_stream_out.txt"
    reasonPath := A_Temp "\\raccourci_assistant_stream_reasoning.txt"
    errPath := A_Temp "\\raccourci_assistant_stream_err.txt"
    progressPath := A_Temp "\\raccourci_assistant_stream_progress.txt"
    psPath := A_Temp "\\raccourci_assistant_stream_request.ps1"

    endpoint := Trim(settings["api_endpoint"])
    apiKey := Trim(settings["api_key"])
    model := Trim(settings["model"])
    prompt := Trim(GetAssistantPromptByTemplate(settings))

    if (endpoint = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant endpoint is empty")
    }
    if (model = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant model is empty")
    }
    if (prompt = "") {
        prompt := GetAssistantDefaultPrompt()
    }
    if !InStr(StrLower(endpoint), "/responses") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "stream requires responses endpoint")
    }

    prompt := StrReplace(StrReplace(prompt, "`r", " "), "`n", " ")

    script := "$ErrorActionPreference='Stop'`n"
        . "`$ep='" PsSingleQuote(endpoint) "'`n"
        . "`$k='" PsSingleQuote(apiKey) "'`n"
        . "`$model='" PsSingleQuote(model) "'`n"
        . "`$prompt='" PsSingleQuote(prompt) "'`n"
        . "`$img='" PsSingleQuote(imagePath) "'`n"
        . "`$out='" PsSingleQuote(outPath) "'`n"
        . "`$reason='" PsSingleQuote(reasonPath) "'`n"
        . "`$err='" PsSingleQuote(errPath) "'`n"
        . "`$progress='" PsSingleQuote(progressPath) "'`n"
        . "function Write-State([string]`$status,[string]`$reasoning,[string]`$answer,[string]`$mode='stream',[int]`$reasoningVisible=0){`n"
        . "  `$enc=[Text.Encoding]::UTF8`n"
        . "  `$reasonB64=[Convert]::ToBase64String(`$enc.GetBytes([string]`$reasoning))`n"
        . "  `$answerB64=[Convert]::ToBase64String(`$enc.GetBytes([string]`$answer))`n"
        . "  `$lines=@(`n"
        . "    'status=' + `$status,`n"
        . "    'mode=' + `$mode,`n"
        . "    'reasoning_visible=' + `$reasoningVisible,`n"
        . "    'reasoning_b64=' + `$reasonB64,`n"
        . "    'answer_b64=' + `$answerB64`n"
        . "  )`n"
        . "  [IO.File]::WriteAllLines(`$progress, `$lines, `$enc)`n"
        . "}`n"
        . "function Get-DeltaText(`$evt){`n"
        . "  `$text=''`n"
        . "  if(`$null -ne `$evt.delta){`n"
        . "    if(`$evt.delta -is [string]){ `$text=[string]`$evt.delta }`n"
        . "    elseif(`$null -ne `$evt.delta.text){ `$text=[string]`$evt.delta.text }`n"
        . "  }`n"
        . "  if([string]::IsNullOrWhiteSpace(`$text) -and `$null -ne `$evt.part){`n"
        . "    if(`$null -ne `$evt.part.text){ `$text=[string]`$evt.part.text }`n"
        . "  }`n"
        . "  if([string]::IsNullOrWhiteSpace(`$text) -and `$null -ne `$evt.text){ `$text=[string]`$evt.text }`n"
        . "  return `$text`n"
        . "}`n"
        . "function Get-EventKind(`$evt){`n"
        . "  `$type=''`n"
        . "  if(`$null -ne `$evt.type){ `$type=[string]`$evt.type }`n"
        . "  if([string]::IsNullOrWhiteSpace(`$type) -or (`$type -notmatch 'delta')){ return '' }`n"
        . "  if(`$type -match 'reasoning'){ return 'reasoning' }`n"
        . "  if(`$type -match 'output_text'){ return 'answer' }`n"
        . "  if(`$null -ne `$evt.part -and `$null -ne `$evt.part.type){`n"
        . "    `$partType=[string]`$evt.part.type`n"
        . "    if(`$partType -match 'reasoning'){ return 'reasoning' }`n"
        . "    if(`$partType -match 'output_text'){ return 'answer' }`n"
        . "  }`n"
        . "  return ''`n"
        . "}`n"
        . "try {`n"
        . "  `$bytes=[IO.File]::ReadAllBytes(`$img)`n"
        . "  `$b64=[Convert]::ToBase64String(`$bytes)`n"
        . "  `$imgUrl='data:image/png;base64,' + `$b64`n"
        . "  `$payload=[ordered]@{`n"
        . "    model=`$model;`n"
        . "    stream=`$true;`n"
        . "    input=@([ordered]@{role='user';content=@([ordered]@{type='input_image';image_url=`$imgUrl},[ordered]@{type='input_text';text=`$prompt})})`n"
        . "  }`n"
        . "  `$json=`$payload | ConvertTo-Json -Depth 30`n"
        . "  `$req=[System.Net.HttpWebRequest]::Create(`$ep)`n"
        . "  `$req.Method='POST'`n"
        . "  `$req.Accept='text/event-stream'`n"
        . "  `$req.ContentType='application/json'`n"
        . "  `$req.Timeout=180000`n"
        . "  `$req.ReadWriteTimeout=180000`n"
        . "  if(`$k -ne ''){ `$req.Headers['Authorization']='Bearer ' + `$k }`n"
        . "  `$bodyBytes=[Text.Encoding]::UTF8.GetBytes(`$json)`n"
        . "  `$req.ContentLength=`$bodyBytes.Length`n"
        . "  `$reqStream=`$req.GetRequestStream()`n"
        . "  `$reqStream.Write(`$bodyBytes, 0, `$bodyBytes.Length)`n"
        . "  `$reqStream.Close()`n"
        . "  `$resp=`$req.GetResponse()`n"
        . "  `$reader=New-Object IO.StreamReader(`$resp.GetResponseStream(), [Text.Encoding]::UTF8)`n"
        . "  `$reasoningSb=New-Object System.Text.StringBuilder`n"
        . "  `$answerSb=New-Object System.Text.StringBuilder`n"
        . "  `$eventLines=New-Object System.Collections.Generic.List[string]`n"
        . "  `$reasoningVisible=0`n"
        . "  Write-State 'streaming' '' '' 'stream' 0`n"
        . "  while((`$line=`$reader.ReadLine()) -ne `$null){`n"
        . "    if([string]::IsNullOrWhiteSpace(`$line)){`n"
        . "      if(`$eventLines.Count -gt 0){`n"
        . "        `$payloadText=[string]::Join([Environment]::NewLine, `$eventLines)`n"
        . "        `$eventLines.Clear()`n"
        . "        if(`$payloadText -eq '[DONE]'){ break }`n"
        . "        try { `$evt=`$payloadText | ConvertFrom-Json } catch { continue }`n"
        . "        `$kind=Get-EventKind `$evt`n"
        . "        `$delta=Get-DeltaText `$evt`n"
        . "        if(`$kind -eq 'reasoning' -and `$delta -ne ''){ [void]`$reasoningSb.Append(`$delta); `$reasoningVisible=1 }`n"
        . "        elseif(`$kind -eq 'answer' -and `$delta -ne ''){ [void]`$answerSb.Append(`$delta) }`n"
        . "        if(`$kind -ne '' -and `$delta -ne ''){ Write-State 'streaming' `$reasoningSb.ToString() `$answerSb.ToString() 'stream' `$reasoningVisible }`n"
        . "      }`n"
        . "      continue`n"
        . "    }`n"
        . "    if(`$line.StartsWith('data:')){ `$eventLines.Add(`$line.Substring(5).TrimStart()) }`n"
        . "  }`n"
        . "  `$reader.Close()`n"
        . "  `$resp.Close()`n"
        . "  `$answerText=`$answerSb.ToString()`n"
        . "  `$reasoningText=`$reasoningSb.ToString()`n"
        . "  [IO.File]::WriteAllText(`$out, `$answerText, [Text.Encoding]::UTF8)`n"
        . "  [IO.File]::WriteAllText(`$reason, `$reasoningText, [Text.Encoding]::UTF8)`n"
        . "  Write-State 'done' `$reasoningText `$answerText 'stream' `$reasoningVisible`n"
        . "} catch {`n"
        . "  [IO.File]::WriteAllText(`$err, `$_.Exception.Message, [Text.Encoding]::UTF8)`n"
        . "}`n"

    for path in [outPath, reasonPath, errPath, progressPath, psPath] {
        if FileExist(path) {
            FileDelete(path)
        }
    }
    FileAppend(script, psPath, "UTF-8")

    pid := 0
    try {
        Run('powershell -NoProfile -ExecutionPolicy Bypass -File "' psPath '"', , "Hide", &pid)
    } catch {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant stream command failed")
    }

    startTick := A_TickCount
    lastProgressRaw := ""
    lastAnswer := ""
    lastReasoning := ""
    streamSeen := false
    if (pid > 0) {
        loop {
            if FileExist(progressPath) {
                try progressRaw := FileRead(progressPath, "UTF-8")
                catch {
                    progressRaw := ""
                }
                if (progressRaw != "" && progressRaw != lastProgressRaw) {
                    lastProgressRaw := progressRaw
                    snapshot := ParseAssistantStreamSnapshot(progressRaw)
                    lastAnswer := snapshot["answer"]
                    lastReasoning := snapshot["reasoning"]
                    if (lastAnswer != "" || lastReasoning != "") {
                        streamSeen := true
                    }
                    if IsObject(onProgress) {
                        onProgress.Call("stream_snapshot", snapshot)
                    }
                }
            }
            if !ProcessExist(pid) {
                break
            }
            if IsObject(onProgress) {
                elapsed := Floor((A_TickCount - startTick) / 1000)
                onProgress.Call("thinking", elapsed)
            }
            Sleep(120)
        }
    } else {
        Sleep(200)
    }

    if FileExist(progressPath) {
        try progressRaw := FileRead(progressPath, "UTF-8")
        catch {
            progressRaw := ""
        }
        if (progressRaw != "" && progressRaw != lastProgressRaw) {
            snapshot := ParseAssistantStreamSnapshot(progressRaw)
            lastAnswer := snapshot["answer"]
            lastReasoning := snapshot["reasoning"]
            if (lastAnswer != "" || lastReasoning != "") {
                streamSeen := true
            }
            if IsObject(onProgress) {
                onProgress.Call("stream_snapshot", snapshot)
            }
        }
    }

    if IsObject(onProgress) {
        onProgress.Call("request_done", Floor((A_TickCount - startTick) / 1000))
    }

    if FileExist(errPath) {
        err := Trim(FileRead(errPath, "UTF-8"))
        if (err != "") {
            return Map("ok", 0, "text", "", "reasoning", "", "streamed", streamSeen ? 1 : 0, "error", err)
        }
    }

    txt := FileExist(outPath) ? Trim(FileRead(outPath, "UTF-8")) : Trim(lastAnswer)
    reasoning := FileExist(reasonPath) ? Trim(FileRead(reasonPath, "UTF-8")) : Trim(lastReasoning)
    if (txt = "") {
        return Map("ok", 0, "text", "", "reasoning", reasoning, "streamed", streamSeen ? 1 : 0, "error", "assistant stream empty output")
    }
    return Map("ok", 1, "text", txt, "reasoning", reasoning, "streamed", 1, "error", "")
}

RequestAssistantAnswerFromTextLegacy(queryText, settings, onProgress := "") {
    outPath := A_Temp "\\raccourci_assistant_text_out.txt"
    errPath := A_Temp "\\raccourci_assistant_text_err.txt"
    psPath := A_Temp "\\raccourci_assistant_text_request.ps1"

    endpoint := Trim(settings["api_endpoint"])
    apiKey := Trim(settings["api_key"])
    model := Trim(settings["model"])
    prompt := Trim(GetAssistantPromptByTemplate(settings))
    query := Trim(queryText)

    if (endpoint = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant endpoint is empty")
    }
    if (model = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant model is empty")
    }
    if (prompt = "") {
        prompt := GetAssistantDefaultPrompt()
    }
    if (query = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant text query is empty")
    }

    prompt := StrReplace(StrReplace(prompt, "`r", " "), "`n", " ")
    query := StrReplace(StrReplace(query, "`r", " "), "`n", " ")

    script := "$ErrorActionPreference='Stop'`n"
        . "`$ep='" PsSingleQuote(endpoint) "'`n"
        . "`$k='" PsSingleQuote(apiKey) "'`n"
        . "`$model='" PsSingleQuote(model) "'`n"
        . "`$prompt='" PsSingleQuote(prompt) "'`n"
        . "`$query='" PsSingleQuote(query) "'`n"
        . "`$out='" PsSingleQuote(outPath) "'`n"
        . "`$err='" PsSingleQuote(errPath) "'`n"
        . "try {`n"
        . "  `$headers=@{}`n"
        . "  if(`$k -ne ''){ `$headers['Authorization']='Bearer ' + `$k }`n"
        . "  `$isResponses=(`$ep.ToLower().Contains('/responses'))`n"
        . "  if(`$isResponses){`n"
        . "    `$payload=[ordered]@{ model=`$model; input=@([ordered]@{role='user';content=@([ordered]@{type='input_text';text=`$prompt + '`n`n' + `$query})}) }`n"
        . "  } else {`n"
        . "    `$payload=[ordered]@{ model=`$model; messages=@([ordered]@{role='user';content=@([ordered]@{type='text';text=`$prompt + '`n`n' + `$query})}); temperature=0.2; max_tokens=700 }`n"
        . "  }`n"
        . "  `$json=`$payload | ConvertTo-Json -Depth 30`n"
        . "  `$res=Invoke-RestMethod -Method Post -Uri `$ep -Headers `$headers -ContentType 'application/json' -Body `$json`n"
        . "  `$text=''`n"
        . "  if(`$isResponses){`n"
        . "    if(-not [string]::IsNullOrWhiteSpace([string]`$res.output_text)){ `$text=[string]`$res.output_text }`n"
        . "    if([string]::IsNullOrWhiteSpace(`$text) -and `$null -ne `$res.output){`n"
        . "      foreach(`$o in `$res.output){`n"
        . "        if(`$null -eq `$o.content){ continue }`n"
        . "        foreach(`$c in `$o.content){ if(`$c.type -eq 'output_text' -and `$c.text){ `$text += [string]`$c.text + [Environment]::NewLine } }`n"
        . "      }`n"
        . "      `$text=`$text.Trim()`n"
        . "    }`n"
        . "  } else {`n"
        . "    if(`$null -ne `$res.choices -and `$res.choices.Count -gt 0){`n"
        . "      `$msg=`$res.choices[0].message`n"
        . "      if(`$null -ne `$msg.content){`n"
        . "        if(`$msg.content -is [string]){ `$text=[string]`$msg.content }`n"
        . "        elseif(`$msg.content -is [System.Array]){ foreach(`$part in `$msg.content){ if(`$part.type -eq 'text' -and `$part.text){ `$text += [string]`$part.text + [Environment]::NewLine } }; `$text=`$text.Trim() }`n"
        . "      }`n"
        . "    }`n"
        . "  }`n"
        . "  if([string]::IsNullOrWhiteSpace(`$text)){ `$text = (`$res | ConvertTo-Json -Depth 20) }`n"
        . "  Set-Content -LiteralPath `$out -Value `$text -Encoding UTF8`n"
        . "} catch {`n"
        . "  Set-Content -LiteralPath `$err -Value `$_.Exception.Message -Encoding UTF8`n"
        . "}`n"

    if FileExist(outPath) {
        FileDelete(outPath)
    }
    if FileExist(errPath) {
        FileDelete(errPath)
    }
    if FileExist(psPath) {
        FileDelete(psPath)
    }
    FileAppend(script, psPath, "UTF-8")

    pid := 0
    try {
        Run('powershell -NoProfile -ExecutionPolicy Bypass -File "' psPath '"', , "Hide", &pid)
    } catch {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant text request command failed")
    }

    startTick := A_TickCount
    if (pid > 0) {
        loop {
            if !ProcessExist(pid) {
                break
            }
            if IsObject(onProgress) {
                elapsed := Floor((A_TickCount - startTick) / 1000)
                onProgress.Call("thinking", elapsed)
            }
            Sleep(200)
        }
    } else {
        Sleep(200)
    }

    if IsObject(onProgress) {
        onProgress.Call("request_done", Floor((A_TickCount - startTick) / 1000))
    }

    if FileExist(errPath) {
        err := Trim(FileRead(errPath, "UTF-8"))
        if (err != "") {
            return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", err)
        }
    }

    if !FileExist(outPath) {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant text no output")
    }

    txt := Trim(FileRead(outPath, "UTF-8"))
    if (txt = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant text returned empty text")
    }
    return Map("ok", 1, "text", txt, "reasoning", "", "streamed", 0, "error", "")
}

RequestAssistantAnswerFromTextStream(queryText, settings, onProgress := "") {
    outPath := A_Temp "\\raccourci_assistant_text_stream_out.txt"
    reasonPath := A_Temp "\\raccourci_assistant_text_stream_reasoning.txt"
    errPath := A_Temp "\\raccourci_assistant_text_stream_err.txt"
    progressPath := A_Temp "\\raccourci_assistant_text_stream_progress.txt"
    psPath := A_Temp "\\raccourci_assistant_text_stream_request.ps1"

    endpoint := Trim(settings["api_endpoint"])
    apiKey := Trim(settings["api_key"])
    model := Trim(settings["model"])
    prompt := Trim(GetAssistantPromptByTemplate(settings))
    query := Trim(queryText)

    if (endpoint = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant endpoint is empty")
    }
    if (model = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant model is empty")
    }
    if (prompt = "") {
        prompt := GetAssistantDefaultPrompt()
    }
    if (query = "") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant text query is empty")
    }
    if !InStr(StrLower(endpoint), "/responses") {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "stream requires responses endpoint")
    }

    prompt := StrReplace(StrReplace(prompt, "`r", " "), "`n", " ")
    query := StrReplace(StrReplace(query, "`r", " "), "`n", " ")

    script := "$ErrorActionPreference='Stop'`n"
        . "`$ep='" PsSingleQuote(endpoint) "'`n"
        . "`$k='" PsSingleQuote(apiKey) "'`n"
        . "`$model='" PsSingleQuote(model) "'`n"
        . "`$prompt='" PsSingleQuote(prompt) "'`n"
        . "`$query='" PsSingleQuote(query) "'`n"
        . "`$out='" PsSingleQuote(outPath) "'`n"
        . "`$reason='" PsSingleQuote(reasonPath) "'`n"
        . "`$err='" PsSingleQuote(errPath) "'`n"
        . "`$progress='" PsSingleQuote(progressPath) "'`n"
        . "function Write-State([string]`$status,[string]`$reasoning,[string]`$answer,[string]`$mode='stream',[int]`$reasoningVisible=0){`n"
        . "  `$enc=[Text.Encoding]::UTF8`n"
        . "  `$reasonB64=[Convert]::ToBase64String(`$enc.GetBytes([string]`$reasoning))`n"
        . "  `$answerB64=[Convert]::ToBase64String(`$enc.GetBytes([string]`$answer))`n"
        . "  `$lines=@(`n"
        . "    'status=' + `$status,`n"
        . "    'mode=' + `$mode,`n"
        . "    'reasoning_visible=' + `$reasoningVisible,`n"
        . "    'reasoning_b64=' + `$reasonB64,`n"
        . "    'answer_b64=' + `$answerB64`n"
        . "  )`n"
        . "  [IO.File]::WriteAllLines(`$progress, `$lines, `$enc)`n"
        . "}`n"
        . "function Get-DeltaText(`$evt){`n"
        . "  `$text=''`n"
        . "  if(`$null -ne `$evt.delta){`n"
        . "    if(`$evt.delta -is [string]){ `$text=[string]`$evt.delta }`n"
        . "    elseif(`$null -ne `$evt.delta.text){ `$text=[string]`$evt.delta.text }`n"
        . "  }`n"
        . "  if([string]::IsNullOrWhiteSpace(`$text) -and `$null -ne `$evt.part){`n"
        . "    if(`$null -ne `$evt.part.text){ `$text=[string]`$evt.part.text }`n"
        . "  }`n"
        . "  if([string]::IsNullOrWhiteSpace(`$text) -and `$null -ne `$evt.text){ `$text=[string]`$evt.text }`n"
        . "  return `$text`n"
        . "}`n"
        . "function Get-EventKind(`$evt){`n"
        . "  `$type=''`n"
        . "  if(`$null -ne `$evt.type){ `$type=[string]`$evt.type }`n"
        . "  if([string]::IsNullOrWhiteSpace(`$type) -or (`$type -notmatch 'delta')){ return '' }`n"
        . "  if(`$type -match 'reasoning'){ return 'reasoning' }`n"
        . "  if(`$type -match 'output_text'){ return 'answer' }`n"
        . "  if(`$null -ne `$evt.part -and `$null -ne `$evt.part.type){`n"
        . "    `$partType=[string]`$evt.part.type`n"
        . "    if(`$partType -match 'reasoning'){ return 'reasoning' }`n"
        . "    if(`$partType -match 'output_text'){ return 'answer' }`n"
        . "  }`n"
        . "  return ''`n"
        . "}`n"
        . "try {`n"
        . "  `$payload=[ordered]@{`n"
        . "    model=`$model;`n"
        . "    stream=`$true;`n"
        . "    input=@([ordered]@{role='user';content=@([ordered]@{type='input_text';text=`$prompt + '`n`n' + `$query})})`n"
        . "  }`n"
        . "  `$json=`$payload | ConvertTo-Json -Depth 30`n"
        . "  `$req=[System.Net.HttpWebRequest]::Create(`$ep)`n"
        . "  `$req.Method='POST'`n"
        . "  `$req.Accept='text/event-stream'`n"
        . "  `$req.ContentType='application/json'`n"
        . "  `$req.Timeout=180000`n"
        . "  `$req.ReadWriteTimeout=180000`n"
        . "  if(`$k -ne ''){ `$req.Headers['Authorization']='Bearer ' + `$k }`n"
        . "  `$bodyBytes=[Text.Encoding]::UTF8.GetBytes(`$json)`n"
        . "  `$req.ContentLength=`$bodyBytes.Length`n"
        . "  `$reqStream=`$req.GetRequestStream()`n"
        . "  `$reqStream.Write(`$bodyBytes, 0, `$bodyBytes.Length)`n"
        . "  `$reqStream.Close()`n"
        . "  `$resp=`$req.GetResponse()`n"
        . "  `$reader=New-Object IO.StreamReader(`$resp.GetResponseStream(), [Text.Encoding]::UTF8)`n"
        . "  `$reasoningSb=New-Object System.Text.StringBuilder`n"
        . "  `$answerSb=New-Object System.Text.StringBuilder`n"
        . "  `$eventLines=New-Object System.Collections.Generic.List[string]`n"
        . "  `$reasoningVisible=0`n"
        . "  Write-State 'streaming' '' '' 'stream' 0`n"
        . "  while((`$line=`$reader.ReadLine()) -ne `$null){`n"
        . "    if([string]::IsNullOrWhiteSpace(`$line)){`n"
        . "      if(`$eventLines.Count -gt 0){`n"
        . "        `$payloadText=[string]::Join([Environment]::NewLine, `$eventLines)`n"
        . "        `$eventLines.Clear()`n"
        . "        if(`$payloadText -eq '[DONE]'){ break }`n"
        . "        try { `$evt=`$payloadText | ConvertFrom-Json } catch { continue }`n"
        . "        `$kind=Get-EventKind `$evt`n"
        . "        `$delta=Get-DeltaText `$evt`n"
        . "        if(`$kind -eq 'reasoning' -and `$delta -ne ''){ [void]`$reasoningSb.Append(`$delta); `$reasoningVisible=1 }`n"
        . "        elseif(`$kind -eq 'answer' -and `$delta -ne ''){ [void]`$answerSb.Append(`$delta) }`n"
        . "        if(`$kind -ne '' -and `$delta -ne ''){ Write-State 'streaming' `$reasoningSb.ToString() `$answerSb.ToString() 'stream' `$reasoningVisible }`n"
        . "      }`n"
        . "      continue`n"
        . "    }`n"
        . "    if(`$line.StartsWith('data:')){ `$eventLines.Add(`$line.Substring(5).TrimStart()) }`n"
        . "  }`n"
        . "  `$reader.Close()`n"
        . "  `$resp.Close()`n"
        . "  `$answerText=`$answerSb.ToString()`n"
        . "  `$reasoningText=`$reasoningSb.ToString()`n"
        . "  [IO.File]::WriteAllText(`$out, `$answerText, [Text.Encoding]::UTF8)`n"
        . "  [IO.File]::WriteAllText(`$reason, `$reasoningText, [Text.Encoding]::UTF8)`n"
        . "  Write-State 'done' `$reasoningText `$answerText 'stream' `$reasoningVisible`n"
        . "} catch {`n"
        . "  [IO.File]::WriteAllText(`$err, `$_.Exception.Message, [Text.Encoding]::UTF8)`n"
        . "}`n"

    for path in [outPath, reasonPath, errPath, progressPath, psPath] {
        if FileExist(path) {
            FileDelete(path)
        }
    }
    FileAppend(script, psPath, "UTF-8")

    pid := 0
    try {
        Run('powershell -NoProfile -ExecutionPolicy Bypass -File "' psPath '"', , "Hide", &pid)
    } catch {
        return Map("ok", 0, "text", "", "reasoning", "", "streamed", 0, "error", "assistant text stream command failed")
    }

    startTick := A_TickCount
    lastProgressRaw := ""
    lastAnswer := ""
    lastReasoning := ""
    streamSeen := false
    if (pid > 0) {
        loop {
            if FileExist(progressPath) {
                try progressRaw := FileRead(progressPath, "UTF-8")
                catch {
                    progressRaw := ""
                }
                if (progressRaw != "" && progressRaw != lastProgressRaw) {
                    lastProgressRaw := progressRaw
                    snapshot := ParseAssistantStreamSnapshot(progressRaw)
                    lastAnswer := snapshot["answer"]
                    lastReasoning := snapshot["reasoning"]
                    if (lastAnswer != "" || lastReasoning != "") {
                        streamSeen := true
                    }
                    if IsObject(onProgress) {
                        onProgress.Call("stream_snapshot", snapshot)
                    }
                }
            }
            if !ProcessExist(pid) {
                break
            }
            if IsObject(onProgress) {
                elapsed := Floor((A_TickCount - startTick) / 1000)
                onProgress.Call("thinking", elapsed)
            }
            Sleep(120)
        }
    } else {
        Sleep(200)
    }

    if FileExist(progressPath) {
        try progressRaw := FileRead(progressPath, "UTF-8")
        catch {
            progressRaw := ""
        }
        if (progressRaw != "" && progressRaw != lastProgressRaw) {
            snapshot := ParseAssistantStreamSnapshot(progressRaw)
            lastAnswer := snapshot["answer"]
            lastReasoning := snapshot["reasoning"]
            if (lastAnswer != "" || lastReasoning != "") {
                streamSeen := true
            }
            if IsObject(onProgress) {
                onProgress.Call("stream_snapshot", snapshot)
            }
        }
    }

    if IsObject(onProgress) {
        onProgress.Call("request_done", Floor((A_TickCount - startTick) / 1000))
    }

    if FileExist(errPath) {
        err := Trim(FileRead(errPath, "UTF-8"))
        if (err != "") {
            return Map("ok", 0, "text", "", "reasoning", "", "streamed", streamSeen ? 1 : 0, "error", err)
        }
    }

    txt := FileExist(outPath) ? Trim(FileRead(outPath, "UTF-8")) : Trim(lastAnswer)
    reasoning := FileExist(reasonPath) ? Trim(FileRead(reasonPath, "UTF-8")) : Trim(lastReasoning)
    if (txt = "") {
        return Map("ok", 0, "text", "", "reasoning", reasoning, "streamed", streamSeen ? 1 : 0, "error", "assistant text stream empty output")
    }
    return Map("ok", 1, "text", txt, "reasoning", reasoning, "streamed", 1, "error", "")
}

ParseAssistantStreamSnapshot(rawText) {
    snapshot := Map("status", "", "mode", "", "answer", "", "reasoning", "", "reasoning_visible", 0)
    text := StrReplace(rawText, "`r`n", "`n")
    text := StrReplace(text, "`r", "`n")
    for line in StrSplit(text, "`n") {
        row := Trim(line)
        if (row = "") {
            continue
        }
        pos := InStr(row, "=")
        if (pos <= 0) {
            continue
        }
        key := Trim(SubStr(row, 1, pos - 1))
        value := SubStr(row, pos + 1)
        switch key {
            case "status":
                snapshot["status"] := value
            case "mode":
                snapshot["mode"] := value
            case "reasoning_visible":
                snapshot["reasoning_visible"] := (Trim(value) = "1") ? 1 : 0
            case "answer_b64":
                snapshot["answer"] := Base64DecodeUtf8(value)
            case "reasoning_b64":
                snapshot["reasoning"] := Base64DecodeUtf8(value)
        }
    }
    return snapshot
}

StartAssistantVoiceRecognitionSession(settings) {
    provider := StrLower(GetAssistantVoiceInputProvider(settings))
    if (provider = "mock_local") {
        return Map("ok", 1, "provider", provider, "pid", 0, "transcript_path", "", "stop_path", "", "error_path", "")
    }
    if (provider != "local_windows") {
        return Map("ok", 0, "provider", provider, "error", "voice provider not implemented: " provider)
    }

    transcriptPath := A_Temp "\\raccourci_voice_input_transcript.txt"
    stopPath := A_Temp "\\raccourci_voice_input_stop.flag"
    errPath := A_Temp "\\raccourci_voice_input_err.txt"
    psPath := A_Temp "\\raccourci_voice_input_listen.ps1"

    script := "$ErrorActionPreference='Stop'`n"
        . "$out='" PsSingleQuote(transcriptPath) "'`n"
        . "$stop='" PsSingleQuote(stopPath) "'`n"
        . "$err='" PsSingleQuote(errPath) "'`n"
        . "try {`n"
        . "  Add-Type -AssemblyName System.Speech`n"
        . "  try { $engine = New-Object System.Speech.Recognition.SpeechRecognitionEngine([System.Globalization.CultureInfo]::InstalledUICulture) } catch { $engine = New-Object System.Speech.Recognition.SpeechRecognitionEngine }`n"
        . "  $grammar = New-Object System.Speech.Recognition.DictationGrammar`n"
        . "  $engine.LoadGrammar($grammar)`n"
        . "  $engine.SetInputToDefaultAudioDevice()`n"
        . "  $parts = New-Object 'System.Collections.Generic.List[string]'`n"
        . "  while(-not (Test-Path -LiteralPath $stop)){`n"
        . "    $result = $null`n"
        . "    try { $result = $engine.Recognize([TimeSpan]::FromMilliseconds(700)) } catch { Start-Sleep -Milliseconds 120; continue }`n"
        . "    if($null -eq $result){ continue }`n"
        . "    $text = ([string]$result.Text).Trim()`n"
        . "    if([string]::IsNullOrWhiteSpace($text)){ continue }`n"
        . "    if($result.Confidence -lt 0.35){ continue }`n"
        . "    if($parts.Count -gt 0 -and $parts[$parts.Count - 1] -eq $text){ continue }`n"
        . "    [void]$parts.Add($text)`n"
        . "    [IO.File]::WriteAllText($out, [string]::Join([Environment]::NewLine, $parts), [Text.Encoding]::UTF8)`n"
        . "  }`n"
        . "  if(-not (Test-Path -LiteralPath $out)){ [IO.File]::WriteAllText($out, '', [Text.Encoding]::UTF8) }`n"
        . "} catch {`n"
        . "  [IO.File]::WriteAllText($err, $_.Exception.Message, [Text.Encoding]::UTF8)`n"
        . "} finally {`n"
        . "  try { if($null -ne $engine){ $engine.Dispose() } } catch {}`n"
        . "}`n"

    for path in [transcriptPath, stopPath, errPath, psPath] {
        if FileExist(path) {
            FileDelete(path)
        }
    }
    FileAppend(script, psPath, "UTF-8")

    pid := 0
    try {
        Run('powershell -NoProfile -ExecutionPolicy Bypass -File "' psPath '"', , "Hide", &pid)
    } catch {
        return Map("ok", 0, "provider", provider, "error", "voice recognition command failed")
    }
    return Map(
        "ok", 1,
        "provider", provider,
        "pid", pid,
        "transcript_path", transcriptPath,
        "stop_path", stopPath,
        "error_path", errPath,
        "script_path", psPath
    )
}

StopAssistantVoiceRecognitionSession(session, timeoutMs := 2600) {
    if !IsObject(session) {
        return Map("ok", 0, "text", "", "error", "voice session missing")
    }

    provider := session.Has("provider") ? session["provider"] : ""
    if (provider = "mock_local") {
        return Map("ok", 1, "text", "这是一次本地模拟语音输入。", "error", "")
    }

    stopPath := session.Has("stop_path") ? session["stop_path"] : ""
    transcriptPath := session.Has("transcript_path") ? session["transcript_path"] : ""
    errPath := session.Has("error_path") ? session["error_path"] : ""
    pid := session.Has("pid") ? session["pid"] : 0

    try FileAppend("stop", stopPath, "UTF-8")

    deadline := A_TickCount + Max(400, Abs(Integer(timeoutMs)))
    loop {
        if !(pid > 0 && ProcessExist(pid)) {
            break
        }
        if (A_TickCount >= deadline) {
            break
        }
        Sleep(120)
    }
    if (pid > 0 && ProcessExist(pid)) {
        try ProcessClose(pid)
    }

    if (errPath != "" && FileExist(errPath)) {
        err := Trim(FileRead(errPath, "UTF-8"))
        if (err != "") {
            return Map("ok", 0, "text", "", "error", err)
        }
    }

    text := ""
    if (transcriptPath != "" && FileExist(transcriptPath)) {
        text := Trim(FileRead(transcriptPath, "UTF-8"))
    }
    return Map("ok", 1, "text", text, "error", "")
}

EnsureAssistantRateFile() {
    global gAssistantRateFile
    if FileExist(gAssistantRateFile) {
        return
    }
    IniWrite("", gAssistantRateFile, "Rate", "window")
    IniWrite("0", gAssistantRateFile, "Rate", "count")
}

ConsumeAssistantRateLimit(settings) {
    global gAssistantRateFile
    EnsureAssistantRateFile()

    enabled := settings.Has("rate_limit_enabled") ? settings["rate_limit_enabled"] : 1
    if (enabled = 0) {
        return Map("ok", 1, "used", 0, "limit", 0, "remaining", 0)
    }

    limit := settings.Has("rate_limit_per_hour") ? ClampAssistantRatePerHour(settings["rate_limit_per_hour"]) : 100
    window := FormatTime(A_Now, "yyyyMMddHH")
    storedWindow := IniRead(gAssistantRateFile, "Rate", "window", "")
    countText := IniRead(gAssistantRateFile, "Rate", "count", "0")
    count := RegExMatch(countText, "^\d+$") ? Integer(countText) : 0

    if (storedWindow != window) {
        count := 0
    }

    if (count >= limit) {
        return Map(
            "ok", 0,
            "used", count,
            "limit", limit,
            "remaining", 0,
            "error", "已达到每小时调用上限（" limit " 次）。"
        )
    }

    count += 1
    IniWrite(window, gAssistantRateFile, "Rate", "window")
    IniWrite(count, gAssistantRateFile, "Rate", "count")
    WriteLog("assistant_rate_consume", "window=" window " used=" count "/" limit)
    return Map("ok", 1, "used", count, "limit", limit, "remaining", Max(0, limit - count))
}

ProtectAssistantSecret(plainText) {
    txt := Trim(plainText)
    if (txt = "") {
        return ""
    }

    outPath := A_Temp "\\raccourci_assistant_secret_protected.txt"
    psPath := A_Temp "\\raccourci_assistant_secret_protect.ps1"
    script := "$ErrorActionPreference='Stop'`n"
        . "$raw='" PsSingleQuote(txt) "'`n"
        . "$secure=ConvertTo-SecureString -String $raw -AsPlainText -Force`n"
        . "$enc=$secure | ConvertFrom-SecureString`n"
        . "Set-Content -LiteralPath '" PsSingleQuote(outPath) "' -Value $enc -Encoding UTF8`n"

    try {
        if FileExist(outPath) {
            FileDelete(outPath)
        }
        if FileExist(psPath) {
            FileDelete(psPath)
        }
        FileAppend(script, psPath, "UTF-8")
        RunWait('powershell -NoProfile -ExecutionPolicy Bypass -File "' psPath '"', , "Hide")
        if !FileExist(outPath) {
            return ""
        }
        return Trim(FileRead(outPath, "UTF-8"))
    } catch {
        WriteLog("assistant_secret_protect_failed", "error=" A_LastError)
        return ""
    }
}

UnprotectAssistantSecret(protectedText) {
    encoded := Trim(protectedText)
    if (encoded = "") {
        return ""
    }

    outPath := A_Temp "\\raccourci_assistant_secret_plain.txt"
    psPath := A_Temp "\\raccourci_assistant_secret_unprotect.ps1"
    script := "$ErrorActionPreference='Stop'`n"
        . "$enc='" PsSingleQuote(encoded) "'`n"
        . "$secure=ConvertTo-SecureString -String $enc`n"
        . "$txt=([pscredential]::new('u',$secure)).GetNetworkCredential().Password`n"
        . "Set-Content -LiteralPath '" PsSingleQuote(outPath) "' -Value $txt -Encoding UTF8`n"

    try {
        if FileExist(outPath) {
            FileDelete(outPath)
        }
        if FileExist(psPath) {
            FileDelete(psPath)
        }
        FileAppend(script, psPath, "UTF-8")
        RunWait('powershell -NoProfile -ExecutionPolicy Bypass -File "' psPath '"', , "Hide")
        if !FileExist(outPath) {
            return ""
        }
        return Trim(FileRead(outPath, "UTF-8"))
    } catch {
        WriteLog("assistant_secret_unprotect_failed", "error=" A_LastError)
        return ""
    }
}


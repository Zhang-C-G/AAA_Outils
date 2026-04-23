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
    return Min(100, Max(35, Integer(opacity)))
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
        "overlay_opacity", 92,
        "disable_copy", 1,
        "rate_limit_enabled", 1,
        "rate_limit_per_hour", 100
    )
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
                settings["enabled"] := (value = "1" || StrLower(value) = "true") ? 1 : 0
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
            case "disable_copy":
                settings["disable_copy"] := (value = "1" || StrLower(value) = "true") ? 1 : 0
            case "rate_limit_enabled":
                settings["rate_limit_enabled"] := (value = "1" || StrLower(value) = "true") ? 1 : 0
            case "rate_limit_per_hour":
                if RegExMatch(value, "^\d+$") {
                    settings["rate_limit_per_hour"] := ClampAssistantRatePerHour(Integer(value))
                }
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
    settings["disable_copy"] := settings.Has("disable_copy") ? (settings["disable_copy"] ? 1 : 0) : 1
    settings["rate_limit_per_hour"] := ClampAssistantRatePerHour(settings["rate_limit_per_hour"])
    EnsureAssistantTemplates(settings)
    return settings
}

RequestAssistantAnswerFromImage(imagePath, settings, onProgress := "") {
    outPath := A_Temp "\\raccourci_assistant_out.txt"
    errPath := A_Temp "\\raccourci_assistant_err.txt"
    psPath := A_Temp "\\raccourci_assistant_request.ps1"

    endpoint := Trim(settings["api_endpoint"])
    apiKey := Trim(settings["api_key"])
    model := Trim(settings["model"])
    prompt := Trim(GetAssistantPromptByTemplate(settings))

    if IsAssistantMockMode(settings) {
        return Map("ok", 1, "text", BuildAssistantMockAnswer(imagePath, settings), "error", "")
    }

    if (endpoint = "") {
        return Map("ok", 0, "text", "", "error", "assistant endpoint is empty")
    }
    if (model = "") {
        return Map("ok", 0, "text", "", "error", "assistant model is empty")
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
        return Map("ok", 0, "text", "", "error", "assistant request command failed")
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
            return Map("ok", 0, "text", "", "error", err)
        }
    }

    if !FileExist(outPath) {
        return Map("ok", 0, "text", "", "error", "assistant no output")
    }

    txt := Trim(FileRead(outPath, "UTF-8"))
    if (txt = "") {
        return Map("ok", 0, "text", "", "error", "assistant returned empty text")
    }
    return Map("ok", 1, "text", txt, "error", "")
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


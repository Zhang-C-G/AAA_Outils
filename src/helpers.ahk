; Generic helpers and logging

StrJoin(arr, sep := "") {
    out := ""
    for idx, item in arr {
        out .= (idx = 1 ? "" : sep) item
    }
    return out
}

WriteLog(action, details := "") {
    global gLogFile
    ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    clean := StrReplace(StrReplace(details, "`r", " "), "`n", " ")
    line := ts " | " action
    if (clean != "") {
        line .= " | " clean
    }
    line .= "`n"
    FileAppend(line, gLogFile, "UTF-8")
}

IsMatch(q, key, value) {
    if (q = "") {
        return true
    }

    keyL := StrLower(key)
    valL := StrLower(value)
    return InStr(keyL, q) || InStr(valL, q)
}

HotkeyToFriendly(hk) {
    if (hk = "") {
        return ""
    }
    ; Already readable format
    if InStr(hk, "+") && (InStr(StrLower(hk), "alt") || InStr(StrLower(hk), "ctrl") || InStr(StrLower(hk), "shift") || InStr(StrLower(hk), "win")) {
        return hk
    }

    mods := []
    key := hk

    if InStr(key, "^") {
        mods.Push("Ctrl")
        key := StrReplace(key, "^")
    }
    if InStr(key, "!") {
        mods.Push("Alt")
        key := StrReplace(key, "!")
    }
    if InStr(key, "+") {
        mods.Push("Shift")
        key := StrReplace(key, "+")
    }
    if InStr(key, "#") {
        mods.Push("Win")
        key := StrReplace(key, "#")
    }

    key := Trim(key)
    if (key = "") {
        return hk
    }

    if (mods.Length = 0) {
        return key
    }
    return StrJoin(mods, "+") "+" StrUpper(key)
}

HotkeyFromFriendly(raw) {
    txt := Trim(raw)
    if (txt = "") {
        return ""
    }

    compact := StrReplace(txt, " ", "")
    lowerCompact := StrLower(compact)

    ; Friendly keyword format should be converted, e.g. Alt+Q / Ctrl+J.
    hasFriendlyWord := InStr(lowerCompact, "alt") || InStr(lowerCompact, "ctrl") || InStr(lowerCompact, "control") || InStr(lowerCompact, "shift") || InStr(lowerCompact, "win") || InStr(lowerCompact, "windows")
    if !hasFriendlyWord {
        ; Keep native AHK modifier format, e.g. !q / ^j / +k / #m
        if RegExMatch(compact, "[\!\^\#]") || RegExMatch(compact, "^\+[^+]+$") {
            return compact
        }
    }

    parts := StrSplit(compact, "+")
    key := ""
    modMap := Map("ctrl", "^", "control", "^", "alt", "!", "shift", "+", "win", "#", "windows", "#")
    modPrefix := ""

    for p in parts {
        low := StrLower(p)
        if modMap.Has(low) {
            sym := modMap[low]
            if !InStr(modPrefix, sym) {
                modPrefix .= sym
            }
        } else if (p != "") {
            key := p
        }
    }

    if (key = "") {
        return compact
    }
    return modPrefix StrLower(key)
}

UriEncode(str) {
    out := ""
    Loop Parse, str {
        ch := A_LoopField
        code := Ord(ch)
        isSafe := (code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A) || ch = "-" || ch = "_" || ch = "." || ch = "~"
        if isSafe {
            out .= ch
        } else {
            out .= "%" Format("{:02X}", code)
        }
    }
    return out
}

Base64DecodeUtf8(text) {
    encoded := Trim(text)
    if (encoded = "") {
        return ""
    }

    charsNeeded := 0
    if !DllCall(
        "Crypt32\CryptStringToBinaryW",
        "Str", encoded,
        "UInt", 0,
        "UInt", 0x1,
        "Ptr", 0,
        "UInt*", charsNeeded,
        "Ptr", 0,
        "Ptr", 0,
        "Int"
    ) {
        return ""
    }

    buf := Buffer(charsNeeded, 0)
    if !DllCall(
        "Crypt32\CryptStringToBinaryW",
        "Str", encoded,
        "UInt", 0,
        "UInt", 0x1,
        "Ptr", buf,
        "UInt*", charsNeeded,
        "Ptr", 0,
        "Ptr", 0,
        "Int"
    ) {
        return ""
    }

    return StrGet(buf, charsNeeded, "UTF-8")
}

LoadUsageCounts() {
    global gUsageFile, gCategories
    usage := Map()
    for cat in gCategories {
        id := cat["id"]
        usage[id] := LoadUsageSection(gUsageFile, GetUsageSectionName(id))
    }
    return usage
}

GetUsageSectionName(catId) {
    return "Usage_" catId
}

LoadUsageSection(path, section) {
    counts := Map()
    inSection := false

    for line in StrSplit(FileRead(path, "UTF-8"), "`n", "`r") {
        trimLine := Trim(line)
        if (trimLine = "") {
            continue
        }

        if RegExMatch(trimLine, "^\[(.+)\]$", &m) {
            inSection := (m[1] = section)
            continue
        }

        if !inSection {
            continue
        }

        if InStr(trimLine, "=") {
            key := Trim(SubStr(trimLine, 1, InStr(trimLine, "=") - 1))
            raw := Trim(SubStr(trimLine, InStr(trimLine, "=") + 1))
            value := RegExMatch(raw, "^\d+$") ? Integer(raw) : 0
            if (key != "") {
                counts[key] := Max(0, value)
            }
        }
    }

    return counts
}

SaveUsageCounts() {
    global gUsageFile, gUsage, gCategories
    lines := []
    for cat in gCategories {
        id := cat["id"]
        lines.Push("[" GetUsageSectionName(id) "]")
        if gUsage.Has(id) {
            for key, count in gUsage[id] {
                lines.Push(key "=" count)
            }
        }
        lines.Push("")
    }

    FileDelete(gUsageFile)
    FileAppend(StrJoin(lines, "`n"), gUsageFile, "UTF-8")
}

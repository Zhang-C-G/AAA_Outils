EnsureNotesStore() {
    global gNotesDir
    if !DirExist(gNotesDir) {
        DirCreate(gNotesDir)
    }
    if (LoadNotesMeta().Length = 0) {
        defaultId := CreateNote("Welcome")
        SaveNoteContent(defaultId, "Welcome", "This is your first note.")
    }
}


GetNotePath(noteId) {
    global gNotesDir
    return gNotesDir "\\" noteId ".md"
}

CreateNote(title := "New Note") {
    id := FormatTime(A_Now, "yyyyMMddHHmmss")
    seq := 1
    while FileExist(GetNotePath(id)) {
        seq += 1
        id := FormatTime(A_Now, "yyyyMMddHHmmss") "_" seq
    }
    SaveNoteContent(id, title, "")
    return id
}

DeleteNote(noteId) {
    path := GetNotePath(noteId)
    if FileExist(path) {
        FileDelete(path)
    }
}

LoadNotesMeta() {
    global gNotesDir
    notes := []
    if !DirExist(gNotesDir) {
        return notes
    }

    Loop Files, gNotesDir "\\*.md", "F" {
        id := RegExReplace(A_LoopFileName, "\.md$")
        parsed := ParseNoteFile(A_LoopFileFullPath)
        notes.Push(Map(
            "id", id,
            "title", parsed["title"],
            "updated", A_LoopFileTimeModified
        ))
    }

    if (notes.Length > 1) {
        loop notes.Length - 1 {
            i := A_Index
            loop notes.Length - i {
                j := A_Index
                left := notes[j]
                right := notes[j + 1]
                if (right["updated"] > left["updated"]) {
                    notes[j] := right
                    notes[j + 1] := left
                }
            }
        }
    }

    return notes
}

LoadNote(noteId) {
    path := GetNotePath(noteId)
    if !FileExist(path) {
        return Map("id", noteId, "title", "Untitled", "content", "")
    }
    parsed := ParseNoteFile(path)
    parsed["id"] := noteId
    return parsed
}

SaveNoteContent(noteId, title, content) {
    global gNotesDir
    title := Trim(title)
    if (title = "") {
        title := "Untitled"
    }
    text := "Title: " title "`n"
        . "Updated: " FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") "`n`n"
        . content
    if !DirExist(gNotesDir) {
        DirCreate(gNotesDir)
    }
    path := GetNotePath(noteId)
    if FileExist(path) {
        FileDelete(path)
    }
    FileAppend(text, path, "UTF-8")
}

ParseNoteFile(path) {
    text := FileRead(path, "UTF-8")
    lines := StrSplit(text, "`n", "`r")
    title := "Untitled"
    start := 1
    if (lines.Length >= 1 && InStr(lines[1], "Title: ") = 1) {
        title := Trim(SubStr(lines[1], 8))
        start := 4
    }
    contentLines := []
    idx := start
    while (idx <= lines.Length) {
        contentLines.Push(lines[idx])
        idx += 1
    }
    return Map("title", title, "content", StrJoin(contentLines, "`n"))
}

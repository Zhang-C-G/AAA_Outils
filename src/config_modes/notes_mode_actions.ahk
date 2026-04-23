ReloadNotesEditor() {
    global gNotesListView, gCurrentNoteId, gNotesDeleteConfirm, gNotesMetaCache

    gNotesDeleteConfirm := false
    notes := LoadNotesMeta()
    gNotesMetaCache := notes
    gNotesListView.Delete()

    selectedIndex := 0
    idx := 0
    for note in notes {
        idx += 1
        gNotesListView.Add(, note["title"])
        if (note["id"] = gCurrentNoteId) {
            selectedIndex := idx
        }
    }

    if (selectedIndex = 0 && notes.Length > 0) {
        selectedIndex := 1
        gCurrentNoteId := notes[1]["id"]
    }

    if (selectedIndex > 0) {
        gNotesListView.Modify(selectedIndex, "Select Focus")
        LoadCurrentNoteToEditor(gCurrentNoteId)
    } else {
        gCurrentNoteId := ""
        ClearNoteEditor()
    }
}

LoadCurrentNoteToEditor(noteId) {
    global gNotesTitleEdit, gNotesEdit
    note := LoadNote(noteId)
    gNotesTitleEdit.Value := note["title"]
    gNotesEdit.Value := note["content"]
}

ClearNoteEditor() {
    global gNotesTitleEdit, gNotesEdit
    gNotesTitleEdit.Value := ""
    gNotesEdit.Value := ""
}

OnNotesListSelect(lv, rowNumber, *) {
    global gCurrentNoteId, gNotesMetaCache
    if !rowNumber {
        return
    }

    SaveCurrentNoteIfAny()
    if (rowNumber > gNotesMetaCache.Length) {
        return
    }
    gCurrentNoteId := gNotesMetaCache[rowNumber]["id"]
    LoadCurrentNoteToEditor(gCurrentNoteId)
    WriteLog("notes_select", "id=" gCurrentNoteId)
}

OnCreateNote(*) {
    global gCurrentNoteId
    SaveCurrentNoteIfAny()
    gCurrentNoteId := CreateNote("New Note")
    WriteLog("notes_new", "id=" gCurrentNoteId)
    ReloadNotesEditor()
}

OnDeleteNote(btn, *) {
    global gCurrentNoteId, gNotesDeleteConfirm
    if (gCurrentNoteId = "") {
        return
    }

    if !gNotesDeleteConfirm {
        gNotesDeleteConfirm := true
        btn.Text := "Confirm Delete"
        return
    }

    DeleteNote(gCurrentNoteId)
    WriteLog("notes_delete", "id=" gCurrentNoteId)
    gCurrentNoteId := ""
    gNotesDeleteConfirm := false
    btn.Text := "Delete"
    ReloadNotesEditor()
}

OnNotesChanged(*) {
    global gNotesDeleteConfirm
    gNotesDeleteConfirm := false
}

SaveCurrentNoteIfAny() {
    global gCurrentNoteId
    if (gCurrentNoteId = "") {
        return
    }
    SaveCurrentNote()
    WriteLog("notes_autosave", "id=" gCurrentNoteId)
}

SaveCurrentNote() {
    global gCurrentNoteId, gNotesTitleEdit, gNotesEdit
    if (gCurrentNoteId = "") {
        return
    }
    SaveNoteContent(gCurrentNoteId, gNotesTitleEdit.Value, gNotesEdit.Value)
}

OnSaveNotes(*) {
    global gCurrentNoteId
    if (gCurrentNoteId = "") {
        gCurrentNoteId := CreateNote("New Note")
    }
    SaveCurrentNote()
    WriteLog("notes_save", "id=" gCurrentNoteId)
    ReloadNotesEditor()
    MsgBox("Notes saved")
}


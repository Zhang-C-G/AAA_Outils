BuildNotesModeBody() {
    global gConfigGui, gTheme, gNotesListView, gNotesTitleEdit, gNotesEdit

    gConfigGui.AddText("x40 y130 w200 h24 c" gTheme["text_primary"], "Notes")
    gConfigGui.AddText("x40 y156 w300 h20 c" gTheme["text_hint"], "Create, edit, and keep multiple notes")

    gNotesListView := gConfigGui.AddListView("x40 y186 w270 h500 -Multi -Hdr vNotesListView Background" gTheme["bg_surface"] " c" gTheme["text_primary"], ["Title"])
    gNotesListView.OnEvent("ItemSelect", OnNotesListSelect)
    gNotesListView.ModifyCol(1, 248)

    gConfigGui.AddText("x330 y186 w610 h20 c" gTheme["text_hint"], "Title")
    gNotesTitleEdit := gConfigGui.AddEdit("x330 y210 w610 h28 vNotesTitleInput c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    gNotesTitleEdit.OnEvent("Change", OnNotesChanged)

    gConfigGui.AddText("x330 y246 w610 h20 c" gTheme["text_hint"], "Content")
    gNotesEdit := gConfigGui.AddEdit("x330 y270 w610 h416 +Multi -Wrap vNotesEditor c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    gNotesEdit.SetFont("s10", "Consolas")
    gNotesEdit.OnEvent("Change", OnNotesChanged)

    newBtn := gConfigGui.AddButton("x40 y708 w100 h42 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "New")
    newBtn.SetFont("s10 w700", "Segoe UI")
    newBtn.OnEvent("Click", OnCreateNote)

    saveBtn := gConfigGui.AddButton("x150 y708 w100 h42 Background" gTheme["bg_header"] " c" gTheme["text_on_light"], "Save")
    saveBtn.SetFont("s10 w700", "Segoe UI")
    saveBtn.OnEvent("Click", OnSaveNotes)

    deleteBtn := gConfigGui.AddButton("x260 y708 w100 h42 Background" gTheme["bg_surface_alt"] " c" gTheme["text_primary"], "Delete")
    deleteBtn.SetFont("s10 w700", "Segoe UI")
    deleteBtn.OnEvent("Click", OnDeleteNote)
}


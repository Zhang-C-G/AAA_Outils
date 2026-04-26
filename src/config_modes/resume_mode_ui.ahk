BuildResumeModeBody() {
    global gConfigGui, gTheme
    
    gConfigGui.AddText("x20 y106 w940 h24 c" gTheme["text_primary"], "Resume Auto-fill Configuration")
    
    gConfigGui.AddText("x20 y140 w100 h24 c" gTheme["text_primary"], "Name")
    gConfigGui.AddEdit("x130 y136 w300 h28 vResumeNameEdit c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    
    gConfigGui.AddText("x20 y180 w100 h24 c" gTheme["text_primary"], "Phone")
    gConfigGui.AddEdit("x130 y176 w300 h28 vResumePhoneEdit c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    
    gConfigGui.AddText("x20 y220 w100 h24 c" gTheme["text_primary"], "Email")
    gConfigGui.AddEdit("x130 y216 w300 h28 vResumeEmailEdit c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    
    gConfigGui.AddText("x20 y260 w100 h24 c" gTheme["text_primary"], "Education")
    gConfigGui.AddEdit("x130 y256 w800 h80 vResumeEducationEdit c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    
    gConfigGui.AddText("x20 y350 w100 h24 c" gTheme["text_primary"], "Experience")
    gConfigGui.AddEdit("x130 y346 w800 h80 vResumeExperienceEdit c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    
    gConfigGui.AddText("x20 y440 w100 h24 c" gTheme["text_primary"], "Skills")
    gConfigGui.AddEdit("x130 y436 w800 h80 vResumeSkillsEdit c" gTheme["text_on_light"] " Background" gTheme["bg_header"])
    
    gConfigGui.AddText("x20 y692 w940 h1 0x10 Background" gTheme["line"])

    for ctrlName in ["ResumeNameEdit", "ResumePhoneEdit", "ResumeEmailEdit", "ResumeEducationEdit", "ResumeExperienceEdit", "ResumeSkillsEdit"] {
        gConfigGui[ctrlName].OnEvent("Change", OnResumeFieldChanged)
    }
}

ReloadResumePanel() {
    global gConfigGui, gResumeSettings
    
    gConfigGui["ResumeNameEdit"].Value := gResumeSettings["name"]
    gConfigGui["ResumePhoneEdit"].Value := gResumeSettings["phone"]
    gConfigGui["ResumeEmailEdit"].Value := gResumeSettings["email"]
    gConfigGui["ResumeEducationEdit"].Value := gResumeSettings["education"]
    gConfigGui["ResumeExperienceEdit"].Value := gResumeSettings["experience"]
    gConfigGui["ResumeSkillsEdit"].Value := gResumeSettings["skills"]
}

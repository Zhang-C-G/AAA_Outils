gResumeAutoSavePending := false

SaveResumeSettingsFromGui() {
    global gConfigGui, gResumeSettings
    
    gResumeSettings["name"] := gConfigGui["ResumeNameEdit"].Value
    gResumeSettings["phone"] := gConfigGui["ResumePhoneEdit"].Value
    gResumeSettings["email"] := gConfigGui["ResumeEmailEdit"].Value
    gResumeSettings["education"] := gConfigGui["ResumeEducationEdit"].Value
    gResumeSettings["experience"] := gConfigGui["ResumeExperienceEdit"].Value
    gResumeSettings["skills"] := gConfigGui["ResumeSkillsEdit"].Value
}

ScheduleResumeSettingsAutoSave() {
    global gResumeAutoSavePending
    gResumeAutoSavePending := true
    SetTimer(FlushResumeSettingsAutoSave, -500)
}

FlushResumeSettingsAutoSave(*) {
    global gResumeAutoSavePending
    if !gResumeAutoSavePending {
        return
    }
    gResumeAutoSavePending := false
    SaveResumeSettingsFromGui()
    SaveData()
    WriteLog("resume_auto_save", "config saved")
}

OnResumeFieldChanged(*) {
    ScheduleResumeSettingsAutoSave()
}

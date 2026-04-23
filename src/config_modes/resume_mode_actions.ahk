SaveResumeSettingsFromGui() {
    global gConfigGui, gResumeSettings
    
    gResumeSettings["name"] := gConfigGui["ResumeNameEdit"].Value
    gResumeSettings["phone"] := gConfigGui["ResumePhoneEdit"].Value
    gResumeSettings["email"] := gConfigGui["ResumeEmailEdit"].Value
    gResumeSettings["education"] := gConfigGui["ResumeEducationEdit"].Value
    gResumeSettings["experience"] := gConfigGui["ResumeExperienceEdit"].Value
    gResumeSettings["skills"] := gConfigGui["ResumeSkillsEdit"].Value
}

OnSaveResumeConfigClicked(*) {
    SaveResumeSettingsFromGui()
    SaveData()
    WriteLog("resume", "config saved")
    MsgBox("Resume config saved")
}

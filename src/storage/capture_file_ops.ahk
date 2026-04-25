EnsureCaptureStore() {
    global gCaptureDir
    if !DirExist(gCaptureDir) {
        DirCreate(gCaptureDir)
    }
}

GenerateCapturePath() {
    global gCaptureDir
    stamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    base := gCaptureDir "\\cap_" stamp
    path := base ".png"
    idx := 1
    while FileExist(path) {
        idx += 1
        path := base "_" idx ".png"
    }
    return path
}

GetCaptureLatestPath() {
    global gCaptureDir
    return gCaptureDir "\\latest.png"
}

PublishLatestCapture(sourcePath) {
    target := GetCaptureLatestPath()
    if FileExist(target) {
        FileDelete(target)
    }
    FileCopy(sourcePath, target, 1)
    return target
}

CaptureFullScreen(path) {
    notesHiddenForCapture := false
    try {
        if IsNotesOverlayVisible() {
            notesHiddenForCapture := HideNotesOverlayForCapture()
        }
    }

    psPath := A_Temp "\\raccourci_capture.ps1"
    script := "$ErrorActionPreference='Stop'`n"
        . "Add-Type -AssemblyName System.Drawing`n"
        . "Add-Type -AssemblyName System.Windows.Forms`n"
        . "$b=[System.Windows.Forms.SystemInformation]::VirtualScreen`n"
        . "$bmp=New-Object System.Drawing.Bitmap($b.Width,$b.Height)`n"
        . "$g=[System.Drawing.Graphics]::FromImage($bmp)`n"
        . "$g.CopyFromScreen($b.X,$b.Y,0,0,$bmp.Size)`n"
        . "$bmp.Save('" PsSingleQuote(path) "', [System.Drawing.Imaging.ImageFormat]::Png)`n"
        . "$g.Dispose()`n"
        . "$bmp.Dispose()`n"

    if FileExist(psPath) {
        FileDelete(psPath)
    }
    FileAppend(script, psPath, "UTF-8")
    try {
        RunWait('powershell -NoProfile -ExecutionPolicy Bypass -File "' psPath '"', , "Hide")
    } catch {
        try RestoreNotesOverlayAfterCapture(notesHiddenForCapture)
        return false
    }
    try RestoreNotesOverlayAfterCapture(notesHiddenForCapture)
    return FileExist(path)
}

UploadCaptureFile(filePath, endpoint) {
    outPath := A_Temp "\\raccourci_upload_out.txt"
    psPath := A_Temp "\\raccourci_upload.ps1"

    script := "$ErrorActionPreference='Stop'`n"
        . "Add-Type -AssemblyName System.Net.Http`n"
        . "$ep='" PsSingleQuote(endpoint) "'`n"
        . "$fp='" PsSingleQuote(filePath) "'`n"
        . "$bytes=[System.IO.File]::ReadAllBytes($fp)`n"
        . "$client=New-Object System.Net.Http.HttpClient`n"
        . "$mp=New-Object System.Net.Http.MultipartFormDataContent`n"
        . "$fc=New-Object System.Net.Http.ByteArrayContent($bytes)`n"
        . "$mp.Add($fc,'file',[System.IO.Path]::GetFileName($fp))`n"
        . "$resp=$client.PostAsync($ep,$mp).Result`n"
        . "$txt=$resp.Content.ReadAsStringAsync().Result`n"
        . "Set-Content -LiteralPath '" PsSingleQuote(outPath) "' -Value $txt -Encoding UTF8`n"

    if FileExist(outPath) {
        FileDelete(outPath)
    }
    if FileExist(psPath) {
        FileDelete(psPath)
    }
    FileAppend(script, psPath, "UTF-8")

    try {
        RunWait('powershell -NoProfile -ExecutionPolicy Bypass -File "' psPath '"', , "Hide")
    } catch {
        return ""
    }

    if !FileExist(outPath) {
        return ""
    }
    return Trim(FileRead(outPath, "UTF-8"))
}

PsSingleQuote(txt) {
    return StrReplace(txt, "'", "''")
}

GetPrimaryLocalIp() {
    outPath := A_Temp "\\raccourci_local_ip.txt"
    psPath := A_Temp "\\raccourci_local_ip.ps1"

    script := "$ErrorActionPreference='Stop'`n"
        . "$ips=Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -ExpandProperty IPAddress`n"
        . "$ip=$ips | Select-Object -First 1`n"
        . "if(-not $ip){$ip='127.0.0.1'}`n"
        . "Set-Content -LiteralPath '" PsSingleQuote(outPath) "' -Value $ip -Encoding UTF8`n"

    if FileExist(outPath) {
        FileDelete(outPath)
    }
    if FileExist(psPath) {
        FileDelete(psPath)
    }
    FileAppend(script, psPath, "UTF-8")

    try {
        RunWait('powershell -NoProfile -ExecutionPolicy Bypass -File "' psPath '"', , "Hide")
    } catch {
        return "127.0.0.1"
    }

    if !FileExist(outPath) {
        return "127.0.0.1"
    }
    ip := Trim(FileRead(outPath, "UTF-8"))
    if (ip = "" || !InStr(ip, ".")) {
        return "127.0.0.1"
    }
    return ip
}

GetCaptureBridgeUrl(port) {
    return "http://" GetPrimaryLocalIp() ":" port "/"
}

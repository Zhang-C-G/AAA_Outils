WriteBridgeStatus(state := "idle", lastSeen := "") {
    global gCaptureBridgeStatusFile
    if (lastSeen = "") {
        lastSeen := "0"
    }
    content := "state=" state "`nlast_seen=" lastSeen "`n"
    if FileExist(gCaptureBridgeStatusFile) {
        FileDelete(gCaptureBridgeStatusFile)
    }
    FileAppend(content, gCaptureBridgeStatusFile, "UTF-8")
}

ReadBridgeStatus() {
    global gCaptureBridgeStatusFile
    out := Map("state", "stopped", "last_seen", "0")
    if !FileExist(gCaptureBridgeStatusFile) {
        return out
    }
    raw := StrSplit(FileRead(gCaptureBridgeStatusFile, "UTF-8"), "`n", "`r")
    for line in raw {
        t := Trim(line)
        if (t = "" || !InStr(t, "=")) {
            continue
        }
        k := Trim(SubStr(t, 1, InStr(t, "=") - 1))
        v := Trim(SubStr(t, InStr(t, "=") + 1))
        if (k = "state" || k = "last_seen") {
            out[k] := v
        }
    }
    return out
}

ReadBridgePid() {
    global gCaptureBridgePidFile
    if !FileExist(gCaptureBridgePidFile) {
        return 0
    }
    raw := Trim(FileRead(gCaptureBridgePidFile, "UTF-8"))
    if !RegExMatch(raw, "^\d+$") {
        return 0
    }
    return Integer(raw)
}

IsBridgeProcessAlive() {
    pid := ReadBridgePid()
    if (pid <= 0) {
        return false
    }
    return ProcessExist(pid) != 0
}

StartCaptureBridge(port) {
    global gCaptureBridgeScript, gCaptureBridgePidFile, gCaptureBridgeStatusFile, gCaptureDir

    StopCaptureBridge()
    EnsureCaptureStore()
    WriteBridgeStatus("starting", "0")

    psLines := []
    psLines.Push("$ErrorActionPreference='Stop'")
    psLines.Push("param([int]$Port,[string]$CaptureDir,[string]$StatusFile,[string]$PidFile)")
    psLines.Push("$listener=New-Object System.Net.HttpListener")
    psLines.Push("$listener.Prefixes.Add('http://+:'+$Port+'/')")
    psLines.Push("$pid=$PID")
    psLines.Push("Set-Content -LiteralPath $PidFile -Value $pid -Encoding UTF8")
    psLines.Push("Set-Content -LiteralPath $StatusFile -Value 'state=waiting`nlast_seen=0`n' -Encoding UTF8")
    psLines.Push("$listener.Start()")
    psLines.Push("$html=@'")
    psLines.Push("<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'><style>body{font-family:Arial;background:#111;color:#fff;margin:0;padding:16px}.badge{padding:6px 10px;border-radius:999px;background:#444;display:inline-block;margin-right:8px}.on{background:#2f9e44}.off{background:#c92a2a}img{width:100%;margin-top:12px;border-radius:8px;border:1px solid #333}</style></head><body><h3>Raccourci Phone Link</h3><div><span id='pc' class='badge off'>PC: DISCONNECTED</span><span id='ph' class='badge off'>PHONE: CONNECTED</span></div><img id='img' src='/latest.png'><script>async function ping(){document.getElementById('ph').className='badge on';document.getElementById('ph').textContent='PHONE: CONNECTED';try{await fetch('/heartbeat?t='+Date.now());document.getElementById('pc').className='badge on';document.getElementById('pc').textContent='PC: CONNECTED';}catch(e){document.getElementById('pc').className='badge off';document.getElementById('pc').textContent='PC: DISCONNECTED';}document.getElementById('img').src='/latest.png?t='+Date.now();}setInterval(ping,1200);ping();</script></body></html>")
    psLines.Push("'@")
    psLines.Push("while($true){")
    psLines.Push("  $ctx=$listener.GetContext();$req=$ctx.Request;$res=$ctx.Response;$path=$req.Url.AbsolutePath.ToLowerInvariant()")
    psLines.Push("  try{")
    psLines.Push("    if($path -eq '/' -or $path -eq '/index.html'){$buf=[Text.Encoding]::UTF8.GetBytes($html);$res.ContentType='text/html; charset=utf-8';$res.ContentLength64=$buf.Length;$res.OutputStream.Write($buf,0,$buf.Length)}")
    psLines.Push("    elseif($path -eq '/heartbeat'){$now=Get-Date -Format 'yyyyMMddHHmmss';Set-Content -LiteralPath $StatusFile -Value ('state=connected`nlast_seen='+$now+'`n') -Encoding UTF8;$buf=[Text.Encoding]::UTF8.GetBytes('ok');$res.ContentType='text/plain';$res.ContentLength64=$buf.Length;$res.OutputStream.Write($buf,0,$buf.Length)}")
    psLines.Push("    elseif($path -eq '/latest.png'){$p=Join-Path $CaptureDir 'latest.png';if(Test-Path $p){$bytes=[IO.File]::ReadAllBytes($p);$res.ContentType='image/png';$res.ContentLength64=$bytes.Length;$res.OutputStream.Write($bytes,0,$bytes.Length)}else{$res.StatusCode=404}}")
    psLines.Push("    else{$res.StatusCode=404}")
    psLines.Push("  }catch{$res.StatusCode=500}finally{$res.OutputStream.Close()}")
    psLines.Push("}")
    script := StrJoin(psLines, "`n") "`n"

    if FileExist(gCaptureBridgeScript) {
        FileDelete(gCaptureBridgeScript)
    }
    FileAppend(script, gCaptureBridgeScript, "UTF-8")
    cmd := 'powershell -NoProfile -ExecutionPolicy Bypass -File "' gCaptureBridgeScript '" -Port ' port ' -CaptureDir "' gCaptureDir '" -StatusFile "' gCaptureBridgeStatusFile '" -PidFile "' gCaptureBridgePidFile '"'
    try {
        Run(cmd, , "Hide")
    } catch {
        WriteBridgeStatus("failed", "0")
        return false
    }
    Sleep(500)
    return FileExist(gCaptureBridgePidFile)
}

StopCaptureBridge() {
    global gCaptureBridgePidFile, gCaptureBridgeStatusFile
    if FileExist(gCaptureBridgePidFile) {
        pid := Trim(FileRead(gCaptureBridgePidFile, "UTF-8"))
        if RegExMatch(pid, "^\d+$") {
            try RunWait('powershell -NoProfile -Command "Stop-Process -Id ' pid ' -Force" ', , "Hide")
        }
        FileDelete(gCaptureBridgePidFile)
    }
    WriteBridgeStatus("stopped", "0")
}

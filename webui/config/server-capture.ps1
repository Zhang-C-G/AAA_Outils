function Ensure-CaptureStore { Ensure-Dir $CaptureDir }

function Generate-CapturePath {
  Ensure-CaptureStore
  $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
  $base = Join-Path $CaptureDir ('cap_' + $stamp)
  $path = $base + '.png'; $idx = 1
  while (Test-Path $path) { $idx += 1; $path = $base + '_' + $idx + '.png' }
  return $path
}

function Get-CaptureLatestPath { Join-Path $CaptureDir 'latest.png' }

function Publish-LatestCapture {
  param([string]$SourcePath)
  Ensure-CaptureStore
  $target = Get-CaptureLatestPath
  if (Test-Path $target) { Remove-Item -LiteralPath $target -Force }
  Copy-Item -LiteralPath $SourcePath -Destination $target -Force
}

function Capture-FullScreen {
  param([string]$Path)
  try {
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.X, $b.Y, 0, 0, $bmp.Size)
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); return $true
  } catch { return $false }
}

function Upload-CaptureFile {
  param([string]$FilePath, [string]$Endpoint)
  try {
    Add-Type -AssemblyName System.Net.Http
    $bytes = [IO.File]::ReadAllBytes($FilePath)
    $client = New-Object System.Net.Http.HttpClient
    $mp = New-Object System.Net.Http.MultipartFormDataContent
    $fc = New-Object System.Net.Http.ByteArrayContent($bytes)
    $mp.Add($fc, 'file', [IO.Path]::GetFileName($FilePath))
    $resp = $client.PostAsync($Endpoint, $mp).Result
    return $resp.Content.ReadAsStringAsync().Result.Trim()
  } catch { return '' }
}

function Get-PrimaryLocalIp {
  try {
    $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
      Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } |
      Select-Object -ExpandProperty IPAddress
    $ip = $ips | Select-Object -First 1
    if ($ip) { return $ip }
  } catch {}
  return '127.0.0.1'
}

function Get-BridgeUrl { param([int]$Port) ('http://' + (Get-PrimaryLocalIp) + ':' + $Port + '/') }

function Write-BridgeStatus {
  param([string]$State = 'idle', [string]$LastSeen = '0')
  [IO.File]::WriteAllText($BridgeStatusFile, "state=$State`nlast_seen=$LastSeen`n", [Text.Encoding]::UTF8)
}

function Read-BridgeStatus {
  if (!(Test-Path $BridgeStatusFile)) { return [ordered]@{ state='stopped'; last_seen='0' } }
  $out = [ordered]@{ state='stopped'; last_seen='0' }
  foreach ($line in [IO.File]::ReadAllLines($BridgeStatusFile, [Text.Encoding]::UTF8)) {
    $t = $line.Trim(); if ($t -eq '' -or !$t.Contains('=')) { continue }
    $idx = $t.IndexOf('='); $k = $t.Substring(0, $idx).Trim(); $v = $t.Substring($idx + 1).Trim()
    if ($k -eq 'state' -or $k -eq 'last_seen') { $out[$k] = $v }
  }
  return $out
}

function Read-BridgePid {
  if (!(Test-Path $BridgePidFile)) { return 0 }
  $raw = [IO.File]::ReadAllText($BridgePidFile, [Text.Encoding]::UTF8).Trim(); $bridgePid = 0
  if ([int]::TryParse($raw, [ref]$bridgePid)) { return $bridgePid }
  return 0
}

function Is-BridgeAlive {
  $bridgePid = Read-BridgePid
  if ($bridgePid -le 0) { return $false }
  return ($null -ne (Get-Process -Id $bridgePid -ErrorAction SilentlyContinue))
}

function Stop-CaptureBridge {
  $bridgePid = Read-BridgePid
  if ($bridgePid -gt 0) { try { Stop-Process -Id $bridgePid -Force } catch {} }
  if (Test-Path $BridgePidFile) { Remove-Item -LiteralPath $BridgePidFile -Force }
  Write-BridgeStatus -State 'stopped' -LastSeen '0'
}

function Start-CaptureBridge {
  param([int]$Port)
  Stop-CaptureBridge
  Ensure-CaptureStore
  Write-BridgeStatus -State 'starting' -LastSeen '0'

  $lines = @(
    "param([int]`$Port,[string]`$CaptureDir,[string]`$StatusFile,[string]`$PidFile)",
    "`$ErrorActionPreference='Stop'",
    "`$listener=New-Object System.Net.HttpListener",
    "`$started=`$false",
    "try{`$listener.Prefixes.Add('http://+:' + `$Port + '/');`$listener.Start();`$started=`$true}catch{}",
    "if(-not `$started){`$listener=New-Object System.Net.HttpListener;`$listener.Prefixes.Add('http://127.0.0.1:' + `$Port + '/');`$listener.Start()}",
    "`$bridgePid=`$PID",
    "Set-Content -LiteralPath `$PidFile -Value `$bridgePid -Encoding UTF8",
    "Set-Content -LiteralPath `$StatusFile -Value 'state=waiting`nlast_seen=0`n' -Encoding UTF8",
    "`$html='<!doctype html><html><head><meta name=''viewport'' content=''width=device-width,initial-scale=1''><style>body{font-family:Arial;background:#111;color:#fff;margin:0;padding:16px}.badge{padding:6px 10px;border-radius:999px;background:#444;display:inline-block;margin-right:8px}.on{background:#2f9e44}.off{background:#c92a2a}img{width:100%;margin-top:12px;border-radius:8px;border:1px solid #333}</style></head><body><h3>Raccourci Phone Link</h3><div><span id=''pc'' class=''badge off''>PC: DISCONNECTED</span><span id=''ph'' class=''badge off''>PHONE: WAITING</span></div><img id=''img'' src=''/latest.png''><script>async function ping(){document.getElementById(''ph'').className=''badge on'';document.getElementById(''ph'').textContent=''PHONE: CONNECTED'';try{await fetch(''/heartbeat?t=''+Date.now());document.getElementById(''pc'').className=''badge on'';document.getElementById(''pc'').textContent=''PC: CONNECTED'';}catch(e){document.getElementById(''pc'').className=''badge off'';document.getElementById(''pc'').textContent=''PC: DISCONNECTED'';}document.getElementById(''img'').src=''/latest.png?t=''+Date.now();}setInterval(ping,1200);ping();</script></body></html>'",
    "while(`$true){",
    "  `$ctx=`$listener.GetContext();`$req=`$ctx.Request;`$res=`$ctx.Response;`$path=`$req.Url.AbsolutePath.ToLowerInvariant()",
    "  try{",
    "    if(`$path -eq '/' -or `$path -eq '/index.html'){`$buf=[Text.Encoding]::UTF8.GetBytes(`$html);`$res.ContentType='text/html; charset=utf-8';`$res.ContentLength64=`$buf.Length;`$res.OutputStream.Write(`$buf,0,`$buf.Length)}",
    "    elseif(`$path -eq '/heartbeat'){`$now=Get-Date -Format 'yyyyMMddHHmmss';Set-Content -LiteralPath `$StatusFile -Value ('state=connected`nlast_seen=' + `$now + '`n') -Encoding UTF8;`$buf=[Text.Encoding]::UTF8.GetBytes('ok');`$res.ContentType='text/plain';`$res.ContentLength64=`$buf.Length;`$res.OutputStream.Write(`$buf,0,`$buf.Length)}",
    "    elseif(`$path -eq '/latest.png'){`$p=Join-Path `$CaptureDir 'latest.png';if(Test-Path `$p){`$bytes=[IO.File]::ReadAllBytes(`$p);`$res.ContentType='image/png';`$res.ContentLength64=`$bytes.Length;`$res.OutputStream.Write(`$bytes,0,`$bytes.Length)}else{`$res.StatusCode=404}}",
    "    else{`$res.StatusCode=404}",
    "  }catch{`$res.StatusCode=500}finally{`$res.OutputStream.Close()}",
    "}"
  )

  [IO.File]::WriteAllText($BridgeScript, ([string]::Join("`n", $lines) + "`n"), [Text.Encoding]::UTF8)
  try {
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File', $BridgeScript, '-Port', "$Port", '-CaptureDir', $CaptureDir, '-StatusFile', $BridgeStatusFile, '-PidFile', $BridgePidFile)
    Start-Process -FilePath powershell -ArgumentList $args -WindowStyle Hidden | Out-Null
  } catch {
    Write-BridgeStatus -State 'failed' -LastSeen '0'
    return $false
  }

  for ($i = 0; $i -lt 8; $i++) {
    Start-Sleep -Milliseconds 250
    if (Is-BridgeAlive) { return $true }
  }
  return $false
}

function Get-CaptureState {
  $settings = Get-CaptureSettings
  $status = Read-BridgeStatus
  $pcAlive = Is-BridgeAlive
  $phone = 'DISCONNECTED'
  if ($status.state -eq 'connected' -and $status.last_seen -ne '0') {
    try {
      $seen = [datetime]::ParseExact($status.last_seen, 'yyyyMMddHHmmss', $null)
      $diff = [Math]::Abs((New-TimeSpan -Start (Get-Date) -End $seen).TotalSeconds)
      $phone = if ($diff -le 8) { 'CONNECTED' } else { 'WAITING' }
    } catch { $phone = 'WAITING' }
  } elseif ($status.state -in @('waiting','starting')) {
    $phone = 'WAITING'
  }

  $latest = Get-CaptureLatestPath
  if (!(Test-Path $latest)) { $latest = '' }

  return [ordered]@{
    settings=$settings
    bridge_url=(Get-BridgeUrl -Port ([int]$settings.bridge_port))
    pc_connected=$pcAlive
    phone_state=$phone
    latest_capture=$latest
  }
}

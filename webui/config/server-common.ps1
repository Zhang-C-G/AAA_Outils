function Write-AppLog {
  param([string]$Action, [string]$Detail = "")
  try {
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $clean = ($Detail -replace "`r", ' ' -replace "`n", ' ').Trim()
    $line = if ($clean) { "$ts | $Action | $clean" } else { "$ts | $Action" }
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
  } catch {}
}

function Send-Json {
  param($Res, $Obj)
  $json = $Obj | ConvertTo-Json -Depth 20
  $buf = [Text.Encoding]::UTF8.GetBytes($json)
  $Res.ContentType = 'application/json; charset=utf-8'
  $Res.ContentLength64 = $buf.Length
  $Res.OutputStream.Write($buf, 0, $buf.Length)
}

function Send-Text {
  param($Res, [string]$Text, [string]$Type = 'text/plain; charset=utf-8')
  $buf = [Text.Encoding]::UTF8.GetBytes($Text)
  $Res.ContentType = $Type
  $Res.ContentLength64 = $buf.Length
  $Res.OutputStream.Write($buf, 0, $buf.Length)
}

function Read-BodyJson {
  param($Req)
  $ms = New-Object IO.MemoryStream
  $Req.InputStream.CopyTo($ms)
  $bytes = $ms.ToArray()
  if ($bytes.Length -eq 0) {
    return [pscustomobject]@{}
  }

  $body = [Text.Encoding]::UTF8.GetString($bytes)
  if ($body.Length -gt 0 -and [int][char]$body[0] -eq 0xFEFF) {
    $body = $body.Substring(1)
  }

  if ([string]::IsNullOrWhiteSpace($body)) {
    return [pscustomobject]@{}
  }

  $parseError = ''
  try {
    return $body | ConvertFrom-Json
  } catch {
    $parseError = $_.Exception.Message
  }

  try {
    $fallbackEncoding = if ($null -ne $Req.ContentEncoding) { $Req.ContentEncoding } else { [Text.Encoding]::Default }
    $bodyAlt = $fallbackEncoding.GetString($bytes)
    if ($bodyAlt.Length -gt 0 -and [int][char]$bodyAlt[0] -eq 0xFEFF) {
      $bodyAlt = $bodyAlt.Substring(1)
    }
    return $bodyAlt | ConvertFrom-Json
  } catch {
    $parseError = $parseError + ' | fallback decode: ' + $_.Exception.Message
  }

  throw ('invalid json body: ' + $parseError)
}

function Count-TopLevelRows {
  param($PayloadData, [string]$CategoryId)
  if ($null -eq $PayloadData) { return 0 }
  $rows = Get-Prop $PayloadData $CategoryId @()
  return @($rows).Count
}

function To-JsonNoBom {
  param($Obj, [int]$Depth = 20)
  $json = $Obj | ConvertTo-Json -Depth $Depth
  if ($null -eq $json) { return '' }
  return [string]$json
}

function Get-Prop {
  param($Obj, [string]$Name, $Default = $null)
  if ($null -eq $Obj) { return $Default }
  if ($Obj -is [System.Collections.IDictionary]) {
    if ($Obj.Contains($Name)) { return $Obj[$Name] }
    foreach ($k in $Obj.Keys) {
      if ([string]::Equals([string]$k, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Obj[$k]
      }
    }
    return $Default
  }
  $p = $Obj.PSObject.Properties[$Name]
  if ($null -eq $p) { return $Default }
  return $p.Value
}

function Ensure-Dir {
  param([string]$Path)
  if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function Read-Ini {
  param([string]$Path)
  $out = [ordered]@{}
  if (!(Test-Path $Path)) { return $out }

  $section = ''
  foreach ($raw in [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)) {
    $line = $raw.Trim()
    if ($line -eq '' -or $line.StartsWith(';')) { continue }
    if ($line.StartsWith('[') -and $line.EndsWith(']')) {
      $section = $line.Trim('[', ']')
      if (!$out.Contains($section)) { $out[$section] = [ordered]@{} }
      continue
    }
    if ($section -eq '') { continue }
    $idx = $line.IndexOf('=')
    if ($idx -lt 1) { continue }
    $k = $line.Substring(0, $idx).Trim()
    $v = $line.Substring($idx + 1).Trim()
    if ($k -ne '') { $out[$section][$k] = $v }
  }
  return $out
}

function Write-Ini {
  param($Ini)
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($sec in $Ini.Keys) {
    $lines.Add("[$sec]")
    foreach ($k in $Ini[$sec].Keys) {
      $lines.Add("$k=$($Ini[$sec][$k])")
    }
    $lines.Add('')
  }
  [IO.File]::WriteAllText($DataFile, [string]::Join([Environment]::NewLine, $lines), [Text.Encoding]::UTF8)
}

function Get-CategorySection {
  param([string]$Id)
  if ($Id -eq 'fields') { return 'Fields' }
  if ($Id -eq 'prompts') { return 'Prompts' }
  if ($Id -eq 'quick_fields') { return 'QuickFields' }
  return 'Category_' + $Id
}

function Normalize-Mode {
  param([string]$Mode)
  $m = ($Mode + '').Trim().ToLowerInvariant()
  if ($m -in @('shortcuts', 'notes', 'capture', 'assistant', 'hotkeys', 'testing')) { return $m }
  return 'shortcuts'
}

function Get-HotkeyDefs {
  return @(
    [ordered]@{ id='toggle_panel'; label='呼出悬浮窗'; default='!q'; group='shared'; group_label='公共快捷键'; scope='global' },
    [ordered]@{ id='open_config'; label='打开主界面'; default='!+q'; group='shared'; group_label='公共快捷键'; scope='global' },
    [ordered]@{ id='close_panel'; label='关闭悬浮窗'; default='Esc'; group='shared'; group_label='公共快捷键'; scope='global' },
    [ordered]@{ id='confirm_selection'; label='确认插入'; default='Enter'; group='shared'; group_label='公共快捷键'; scope='panel' },
    [ordered]@{ id='move_up'; label='上移候选'; default='Up'; group='shared'; group_label='公共快捷键'; scope='panel' },
    [ordered]@{ id='move_down'; label='下移候选'; default='Down'; group='shared'; group_label='公共快捷键'; scope='panel' },
    [ordered]@{ id='assistant_capture'; label='启动问答悬浮窗'; default='!+a'; group='assistant'; group_label='截图问答特有'; scope='assistant' },
    [ordered]@{ id='assistant_capture_now'; label='截图并问答'; default='F1'; group='assistant'; group_label='截图问答特有'; scope='assistant' },
    [ordered]@{ id='assistant_overlay_up'; label='问答悬浮上移'; default='!Up'; group='assistant'; group_label='截图问答特有'; scope='assistant' },
    [ordered]@{ id='assistant_overlay_down'; label='问答悬浮下移'; default='!Down'; group='assistant'; group_label='截图问答特有'; scope='assistant' }
  )
}

function Serve-Static {
  param($Req, $Res)
  $path = $Req.Url.AbsolutePath
  if ($path -eq '/') { $path = '/index.html' }

  $name = $path.TrimStart('/')
  if ($name -eq '' -or $name -match '\.\.' -or $name -notmatch '^[a-zA-Z0-9._/-]+$') {
    $Res.StatusCode = 404
    Send-Text $Res 'not found'
    return
  }

  $file = Join-Path $Root $name
  if (!(Test-Path $file)) {
    $Res.StatusCode = 404
    Send-Text $Res 'not found'
    return
  }

  $ext = [IO.Path]::GetExtension($file).ToLowerInvariant()
  $ct = switch ($ext) {
    '.html' { 'text/html; charset=utf-8' }
    '.css' { 'text/css; charset=utf-8' }
    '.js' { 'application/javascript; charset=utf-8' }
    '.svg' { 'image/svg+xml' }
    '.png' { 'image/png' }
    default { 'application/octet-stream' }
  }

  $bytes = [IO.File]::ReadAllBytes($file)
  $Res.Headers['Cache-Control'] = 'no-store, no-cache, must-revalidate'
  $Res.Headers['Pragma'] = 'no-cache'
  $Res.Headers['Expires'] = '0'
  $Res.ContentType = $ct
  $Res.ContentLength64 = $bytes.Length
  $Res.OutputStream.Write($bytes, 0, $bytes.Length)
}

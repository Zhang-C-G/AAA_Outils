param(
  [int]$Port,
  [string]$Root,
  [string]$DataFile,
  [string]$UsageFile,
  [string]$SnapshotFile,
  [string]$ActionFile,
  [string]$PidFile,
  [string]$NotesDir,
  [string]$CaptureDir,
  [string]$BridgeScript,
  [string]$BridgePidFile,
  [string]$BridgeStatusFile,
  [string]$ResumeProfileFile,
  [string]$LogFile
)

$ErrorActionPreference = 'Stop'
[System.IO.File]::WriteAllText($PidFile, "$PID", [System.Text.Encoding]::UTF8)

$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $moduleRoot 'server-common.ps1')
. (Join-Path $moduleRoot 'server-state.ps1')
. (Join-Path $moduleRoot 'server-notes.ps1')
. (Join-Path $moduleRoot 'server-capture.ps1')
. (Join-Path $moduleRoot 'server-assistant.ps1')
. (Join-Path $moduleRoot 'server-resume.ps1')
. (Join-Path $moduleRoot 'server-testing.ps1')

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-AppLog 'web_config_start' ('port=' + $Port)

while ($true) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request
  $res = $ctx.Response
  $path = $req.Url.AbsolutePath
  $method = $req.HttpMethod.ToUpperInvariant()

  try {
    if ($method -eq 'OPTIONS') {
      $res.StatusCode = 204
      Send-Text $res ''
    }
    elseif ($path -eq '/api/ping' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/state' -and $method -eq 'GET') {
      Send-Json $res (Get-ConfigState)
    }
    elseif ($path -eq '/api/save' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $catCount = @((Get-Prop $payload 'categories' @())).Count
      $dataObj = Get-Prop $payload 'data' $null
      $hotObj = Get-Prop $payload 'hotkeys' $null
      $hasData = $null -ne $dataObj
      $hasHotkeys = $null -ne $hotObj
      if ($catCount -le 0 -or -not $hasData -or -not $hasHotkeys) {
        throw "invalid save payload: categories/data/hotkeys required"
      }
      $qfCount = @((Get-Prop $dataObj 'quick_fields' @())).Count
      $fieldsCount = @((Get-Prop $dataObj 'fields' @())).Count
      $promptsCount = @((Get-Prop $dataObj 'prompts' @())).Count
      Write-AppLog 'config_save_payload' ("categories=$catCount hasData=$hasData hasHotkeys=$hasHotkeys rows(fields=$fieldsCount,prompts=$promptsCount,quick_fields=$qfCount)")
      Write-ConfigState $payload
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/version/save' -and $method -eq 'POST') {
      Copy-Item -LiteralPath $DataFile -Destination $SnapshotFile -Force
      Write-AppLog 'version_save' 'snapshot saved (web)'
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/version/restore' -and $method -eq 'POST') {
      if (Test-Path $SnapshotFile) {
        Copy-Item -LiteralPath $SnapshotFile -Destination $DataFile -Force
        [IO.File]::WriteAllText($ActionFile, 'reload', [Text.Encoding]::UTF8)
        Write-AppLog 'version_restore' 'snapshot restored (web)'
      }
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/app/mode' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      Set-AppMode -Mode ([string](Get-Prop $payload 'active_mode' 'shortcuts'))
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/notes/list' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{ ok=$true; notes=(Get-NotesMeta) })
    }
    elseif ($path -eq '/api/notes/get' -and $method -eq 'GET') {
      $id = [string]$req.QueryString['id']
      if ([string]::IsNullOrWhiteSpace($id)) {
        Send-Json $res ([ordered]@{ ok=$false; error='missing id' })
      } else {
        Write-AppLog 'notes_select' ('id=' + $id)
        Send-Json $res ([ordered]@{ ok=$true; note=(Load-Note -Id $id) })
      }
    }
    elseif ($path -eq '/api/notes/create' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $id = Create-Note -Title ([string](Get-Prop $payload 'title' 'New Note'))
      Send-Json $res ([ordered]@{ ok=$true; id=$id })
    }
    elseif ($path -eq '/api/notes/save' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $id = [string](Get-Prop $payload 'id' '')
      if ([string]::IsNullOrWhiteSpace($id)) {
        Send-Json $res ([ordered]@{ ok=$false; error='missing id' })
      } else {
        Save-NoteContent -Id $id -Title ([string](Get-Prop $payload 'title' 'Untitled')) -Content ([string](Get-Prop $payload 'content' ''))
        Write-AppLog 'notes_save' ('id=' + $id)
        Send-Json $res ([ordered]@{ ok=$true })
      }
    }
    elseif ($path -eq '/api/notes/delete' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $id = [string](Get-Prop $payload 'id' '')
      if ([string]::IsNullOrWhiteSpace($id)) {
        Send-Json $res ([ordered]@{ ok=$false; error='missing id' })
      } else {
        Delete-Note -Id $id
        Send-Json $res ([ordered]@{ ok=$true })
      }
    }
    elseif ($path -eq '/api/capture/state' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{ ok=$true; state=(Get-CaptureState) })
    }
    elseif ($path -eq '/api/capture/save-settings' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $settings = Save-CaptureSettings $payload
      Send-Json $res ([ordered]@{ ok=$true; settings=$settings })
    }
    elseif ($path -eq '/api/capture/start-link' -and $method -eq 'POST') {
      $settings = Get-CaptureSettings
      $ok = Start-CaptureBridge -Port ([int]$settings.bridge_port)
      if ($ok) { Write-AppLog 'capture_bridge_start' ('url=' + (Get-BridgeUrl -Port ([int]$settings.bridge_port))) }
      Send-Json $res ([ordered]@{ ok=$ok; state=(Get-CaptureState) })
    }
    elseif ($path -eq '/api/capture/stop-link' -and $method -eq 'POST') {
      Stop-CaptureBridge
      Write-AppLog 'capture_bridge_stop' 'manual (web)'
      Send-Json $res ([ordered]@{ ok=$true; state=(Get-CaptureState) })
    }
    elseif ($path -eq '/api/capture/capture-screen' -and $method -eq 'POST') {
      $pathOut = Generate-CapturePath
      $ok = Capture-FullScreen -Path $pathOut
      if ($ok) {
        Publish-LatestCapture -SourcePath $pathOut
        Write-AppLog 'capture_create' ('path=' + $pathOut)
        Send-Json $res ([ordered]@{ ok=$true; path=$pathOut; state=(Get-CaptureState) })
      } else {
        Write-AppLog 'capture_create_failed' ('path=' + $pathOut)
        Send-Json $res ([ordered]@{ ok=$false; error='capture failed' })
      }
    }
    elseif ($path -eq '/api/capture/upload' -and $method -eq 'POST') {
      $settings = Get-CaptureSettings
      $latest = Get-CaptureLatestPath
      if (!(Test-Path $latest)) {
        Send-Json $res ([ordered]@{ ok=$false; error='no capture found' })
      } else {
        $url = Upload-CaptureFile -FilePath $latest -Endpoint ([string]$settings.upload_endpoint)
        if ([string]::IsNullOrWhiteSpace($url) -or $url -notmatch '^https?://') {
          Write-AppLog 'capture_upload_failed' ('path=' + $latest + ' endpoint=' + $settings.upload_endpoint)
          Send-Json $res ([ordered]@{ ok=$false; error='upload failed' })
        } else {
          Write-AppLog 'capture_upload_success' ('url=' + $url)
          if ([int]$settings.open_qr_after_upload -eq 1) {
            $qr = 'https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=' + [Uri]::EscapeDataString($url)
            Start-Process $qr | Out-Null
            Write-AppLog 'capture_qr_open' ('url=' + $qr)
          }
          Send-Json $res ([ordered]@{ ok=$true; url=$url })
        }
      }
    }
    elseif ($path -eq '/api/capture/open-phone' -and $method -eq 'POST') {
      $settings = Get-CaptureSettings
      if (!(Is-BridgeAlive)) { [void](Start-CaptureBridge -Port ([int]$settings.bridge_port)) }
      $url = Get-BridgeUrl -Port ([int]$settings.bridge_port)
      Start-Process $url | Out-Null
      Write-AppLog 'capture_phone_open' ('url=' + $url)
      Send-Json $res ([ordered]@{ ok=$true; url=$url; state=(Get-CaptureState) })
    }
    elseif ($path -eq '/api/capture/open-folder' -and $method -eq 'POST') {
      Ensure-CaptureStore
      Start-Process $CaptureDir | Out-Null
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/assistant/state' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{ ok=$true; state=(Get-AssistantState) })
    }
    elseif ($path -eq '/api/assistant/save-settings' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $settings = Save-AssistantSettings $payload
      Send-Json $res ([ordered]@{ ok=$true; settings=$settings })
    }
    elseif ($path -eq '/api/assistant/capture-ask' -and $method -eq 'POST') {
      $result = Run-AssistantCaptureAsk
      Send-Json $res $result
    }
    elseif ($path -eq '/api/assistant/show-overlay' -and $method -eq 'POST') {
      $result = Request-AssistantOverlayShow
      Send-Json $res $result
    }
    elseif ($path -eq '/api/assistant/trigger-capture' -and $method -eq 'POST') {
      $result = Request-AssistantCaptureRun
      Send-Json $res $result
    }
    elseif ($path -eq '/api/resume/state' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{ ok=$true; state=(Get-ResumeState) })
    }
    elseif ($path -eq '/api/resume/save' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $stateOut = Save-ResumeProfile -Payload $payload
      Send-Json $res ([ordered]@{ ok=$true; state=$stateOut })
    }
    elseif ($path -eq '/api/resume/profile' -and $method -eq 'GET') {
      $profile = Get-ResumeProfile
      Send-Json $res ([ordered]@{
        ok = $true
        profile = $profile
        flat_map = (Get-ResumeFlatMap -Profile $profile)
      })
    }
    elseif ($path -eq '/api/testing/open-hotkey-probe' -and $method -eq 'POST') {
      $result = Open-TestingHotkeyProbe
      Send-Json $res $result
    }
    elseif ($path -eq '/api/testing/run-overlay-record-capture' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $result = Run-TestingOverlayRecordCapture -DurationSec ([int](Get-Prop $payload 'duration_sec' 6)) -Fps ([int](Get-Prop $payload 'fps' 10))
      Send-Json $res $result
    }
    else {
      Serve-Static -Req $req -Res $res
    }
  }
  catch {
    $res.StatusCode = 500
    Send-Json $res ([ordered]@{ ok=$false; error=$_.Exception.Message })
  }
  finally {
    try { $res.OutputStream.Close() } catch {}
  }
}

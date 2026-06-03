param(
  [int]$Port,
  [string]$Root,
  [string]$DataFile,
  [string]$UsageFile,
  [string]$SnapshotFile,
  [string]$ActionFile,
  [string]$PidFile,
  [string]$NotesDir,
  [string]$NotesDisplayDir,
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
. (Join-Path $moduleRoot 'server-shortcuts.ps1')

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
    elseif ($path -eq '/api/app/state' -and $method -eq 'GET') {
      Send-Json $res (Get-AppShellState)
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
      try {
        Save-ShortcutsFieldsBackup -Reason 'auto_save' -Categories (Get-Prop $payload 'categories' @()) -Data (Get-Prop $payload 'data' $null) | Out-Null
      } catch {
        Write-AppLog 'shortcuts_fields_backup_auto_failed' $_.Exception.Message
      }
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/shortcuts/backup' -and $method -eq 'POST') {
      $result = Save-ShortcutsFieldsBackup -Reason 'manual'
      Send-Json $res $result
    }
    elseif ($path -eq '/api/shortcuts/backups' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{
        ok = $true
        dir = (Get-ShortcutsBackupDir)
        items = (Get-ShortcutsFieldsBackupList)
      })
    }
    elseif ($path -eq '/api/shortcuts/export' -and $method -eq 'GET') {
      $format = ([string]$req.QueryString['format']).Trim().ToLowerInvariant()
      if ($format -eq '') { $format = 'json' }
      $export = Get-ShortcutsFieldsExportObject -Source 'export'
      $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
      if ($format -eq 'ini') {
        $text = ConvertTo-ShortcutsFieldsIniText -ExportObject $export
        $bytes = [Text.Encoding]::UTF8.GetBytes($text)
        Send-Bytes $res $bytes 'text/plain; charset=utf-8' ("shortcuts_fields_$stamp.ini")
      }
      elseif ($format -eq 'csv') {
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add('category_id,category_name,key,value,desc,usage')
        foreach ($cat in @($export.categories)) {
          $catId = [string](Get-Prop $cat 'id' '')
          $catName = [string](Get-Prop $cat 'name' $catId)
          $lookup = Try-GetDataRows -PayloadData $export.data -CategoryId $catId
          if (-not $lookup.found) { continue }
          foreach ($row in @($lookup.rows)) {
            $key = ([string](Get-Prop $row 'key' '')).Trim()
            if ($key -eq '') { continue }
            $value = ([string](Get-Prop $row 'value' ''))
            $desc = ([string](Get-Prop $row 'desc' ''))
            $usage = [string](Get-Prop $row 'usage' 0)
            $escapedValue = '"' + ($value -replace '"', '""') + '"'
            $escapedDesc = '"' + ($desc -replace '"', '""') + '"'
            $escapedName = '"' + ($catName -replace '"', '""') + '"'
            $escapedKey = '"' + ($key -replace '"', '""') + '"'
            $lines.Add("$catId,$escapedName,$escapedKey,$escapedValue,$escapedDesc,$usage")
          }
        }
        $text = [string]::Join([Environment]::NewLine, $lines)
        $bytes = [Text.Encoding]::UTF8.GetBytes($text)
        Send-Bytes $res $bytes 'text/csv; charset=utf-8' ("shortcuts_fields_$stamp.csv")
      }
      else {
        $json = $export | ConvertTo-Json -Depth 30
        $bytes = [Text.Encoding]::UTF8.GetBytes($json)
        Send-Bytes $res $bytes 'application/json; charset=utf-8' ("shortcuts_fields_$stamp.json")
      }
    }
    elseif ($path -eq '/api/shortcuts/restore' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $fileName = [string](Get-Prop $payload 'file' 'latest.json')
      $result = Restore-ShortcutsFieldsBackup -FileName $fileName
      Send-Json $res $result
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
    elseif ($path -eq '/api/app/mode-order' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      Set-AppModeOrder -ModeOrder (Get-Prop $payload 'mode_order' @())
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/app/notes-sidebar' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      Set-AppNotesSidebarCompact -Compact (Get-Prop $payload 'notes_sidebar_compact' 0)
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/app/notes-display-sidebar' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      Set-AppNotesDisplaySidebarCompact -Compact (Get-Prop $payload 'notes_display_sidebar_compact' 0)
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/app/notes-display-workspace' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      Set-AppNotesDisplayWorkspaceState -CurrentId ([string](Get-Prop $payload 'notes_display_current_id' '')) -ContentView ([string](Get-Prop $payload 'notes_display_content_view' 'rendered'))
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/app/testing-subview' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      Set-AppTestingSubview -Subview ([string](Get-Prop $payload 'testing_subview' 'assistant_benchmark'))
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/app/notes-extract-collapsed' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      Set-AppNotesExtractCollapsed -Collapsed (Get-Prop $payload 'notes_extract_collapsed' 0)
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/app/theme' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      Set-AppTheme -Theme $payload
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/app/language' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      Set-AppLanguage -Language ([string](Get-Prop $payload 'app_language' 'fr'))
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/app/shortcuts-category' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      Set-AppShortcutsSelectedCategory -CategoryId ([string](Get-Prop $payload 'shortcuts_selected_category' ''))
      Send-Json $res ([ordered]@{ ok=$true })
    }
    elseif ($path -eq '/api/notes/list' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{ ok=$true; notes=(Get-NotesMeta) })
    }
    elseif ($path -eq '/api/notes/reorder' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $notes = Reorder-Notes -Order (Get-Prop $payload 'order' @())
      Send-Json $res ([ordered]@{ ok=$true; notes=$notes })
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
        $saveIntent = ([string](Get-Prop $payload 'save_intent' '')).Trim().ToLowerInvariant()
        if ($saveIntent -eq '') { $saveIntent = 'autosave' }
        $saved = Save-NoteContent -Id $id -Title ([string](Get-Prop $payload 'title' 'Untitled')) -Content ([string](Get-Prop $payload 'content' ''))
        Write-AppLog 'notes_save' ('id=' + $id + ' intent=' + $saveIntent)
        Send-Json $res ([ordered]@{
          ok=$true
          content=$saved.content
        })
      }
    }
    elseif ($path -eq '/api/notes/export-pdf' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $title = [string](Get-Prop $payload 'title' 'Untitled')
      $html = [string](Get-Prop $payload 'html' '')
      if ([string]::IsNullOrWhiteSpace($html)) {
        Send-Json $res ([ordered]@{ ok=$false; error='missing html' })
      } else {
        $safeTitle = ($title -replace '[\\/:*?"<>|]+', '-').Trim()
        if ([string]::IsNullOrWhiteSpace($safeTitle)) { $safeTitle = 'Untitled' }
        $bytes = Convert-NoteHtmlToPdfBytes -Html $html -Title $safeTitle
        Send-Bytes $res $bytes 'application/pdf' ($safeTitle + '.pdf')
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
    elseif ($path -eq '/api/notes-display/list' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{ ok=$true; notes=(Get-NotesDisplayMeta) })
    }
    elseif ($path -eq '/api/notes-display/reorder' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $notes = Reorder-NotesDisplay -Order (Get-Prop $payload 'order' @())
      Send-Json $res ([ordered]@{ ok=$true; notes=$notes })
    }
    elseif ($path -eq '/api/notes-display/get' -and $method -eq 'GET') {
      $id = [string]$req.QueryString['id']
      if ([string]::IsNullOrWhiteSpace($id)) {
        Send-Json $res ([ordered]@{ ok=$false; error='missing id' })
      } else {
        Write-AppLog 'notes_display_select' ('id=' + $id)
        Send-Json $res ([ordered]@{ ok=$true; note=(Load-NotesDisplayNote -Id $id) })
      }
    }
    elseif ($path -eq '/api/notes-display/create' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $id = Create-NotesDisplayNote -Title ([string](Get-Prop $payload 'title' 'New Note'))
      Send-Json $res ([ordered]@{ ok=$true; id=$id })
    }
    elseif ($path -eq '/api/notes-display/save' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $id = [string](Get-Prop $payload 'id' '')
      if ([string]::IsNullOrWhiteSpace($id)) {
        Send-Json $res ([ordered]@{ ok=$false; error='missing id' })
      } else {
        Save-NotesDisplayContent -Id $id -Title ([string](Get-Prop $payload 'title' 'Untitled')) -Content ([string](Get-Prop $payload 'content' ''))
        Write-AppLog 'notes_display_save' ('id=' + $id)
        Send-Json $res ([ordered]@{ ok=$true })
      }
    }
    elseif ($path -eq '/api/notes-display/delete' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $id = [string](Get-Prop $payload 'id' '')
      if ([string]::IsNullOrWhiteSpace($id)) {
        Send-Json $res ([ordered]@{ ok=$false; error='missing id' })
      } else {
        Delete-NotesDisplayNote -Id $id
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
    elseif ($path -eq '/api/assistant/audio-input-devices' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{ ok=$true; devices=@(Get-AssistantAudioInputDevices) })
    }
    elseif ($path -eq '/api/assistant/benchmark-state' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{ ok=$true; benchmark=(Get-AssistantBenchmarkState) })
    }
    elseif ($path -eq '/api/assistant/benchmark-image' -and $method -eq 'GET') {
      Send-File -Res $res -Path (Ensure-AssistantBenchmarkImage) -Type 'image/png'
    }
    elseif ($path -eq '/api/assistant/benchmark-run' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $result = Invoke-AssistantBenchmarkRun $payload
      Send-Json $res $result
    }
    elseif ($path -eq '/api/assistant/benchmark-stream-start' -and $method -eq 'POST') {
      $payload = Read-BodyJson $req
      $result = Start-AssistantBenchmarkStreamRun $payload
      Send-Json $res $result
    }
    elseif ($path -eq '/api/assistant/benchmark-stream-state' -and $method -eq 'GET') {
      $result = Get-AssistantBenchmarkStreamState -RunId ([string]$req.QueryString['run_id'])
      Send-Json $res $result
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
    elseif ($path -eq '/api/assistant/open-folder' -and $method -eq 'POST') {
      $result = Open-AssistantCaptureFolder
      Send-Json $res $result
    }
    elseif ($path -eq '/api/assistant/pick-folder' -and $method -eq 'POST') {
      $result = Select-AssistantCaptureFolder
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
    elseif ($path -eq '/api/resume/extension-install' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{
        ok = $true
        state = (Get-ResumeExtensionInstallState)
      })
    }
    elseif ($path -eq '/api/resume/open-extension-folder' -and $method -eq 'POST') {
      $result = Open-ResumeExtensionFolder
      Send-Json $res $result
    }
    elseif ($path -eq '/api/resume/open-extension-page' -and $method -eq 'POST') {
      $result = Open-ResumeExtensionPage
      Send-Json $res $result
    }
    elseif ($path -eq '/api/testing/open-hotkey-probe' -and $method -eq 'POST') {
      $result = Open-TestingHotkeyProbe
      Send-Json $res $result
    }
    elseif ($path -eq '/api/testing/voice-latency-state' -and $method -eq 'GET') {
      Send-Json $res ([ordered]@{ ok=$true; state=(Get-TestingVoiceLatencyState) })
    }
    elseif ($path -eq '/api/testing/run-voice-latency-benchmark' -and $method -eq 'POST') {
      $result = Run-TestingVoiceLatencyBenchmark
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

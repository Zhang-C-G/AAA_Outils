function Get-TestingScriptsRoot {
  return (Join-Path $PSScriptRoot '..\..\scripts')
}

function Get-TestingVoiceLatencyScriptPath {
  return (Join-Path (Get-TestingScriptsRoot) 'test_xunfei_voice_latency.ps1')
}

function Get-TestingVoiceLatencySampleText {
  $textCodePoints = @(
    20320,22909,65292,29616,22312,24320,22987,27979,35797,35821,38899,35782,21035,24310,36831,12290,
    25105,20204,38656,35201,30830,35748,39318,26465,35782,21035,32467,26524,36820,22238,30340,36895,
    24230,26159,21542,36275,22815,24555,12290
  )
  return (-join ($textCodePoints | ForEach-Object { [char]$_ }))
}

function Get-TestingVoiceLatencyState {
  return [ordered]@{
    engine_id = 'xunfei_websocket_asr'
    engine_label = 'Xunfei WebSocket ASR'
    sample_text = (Get-TestingVoiceLatencySampleText)
    note = 'Fixed Chinese sample for measuring the F3 voice recognition service path only.'
  }
}

function Open-TestingHotkeyProbe {
  $probePath = Join-Path (Get-TestingScriptsRoot) 'hotkey_focus_probe.html'
  if (-not (Test-Path $probePath)) {
    return [ordered]@{ ok = $false; error = 'probe html not found'; path = $probePath }
  }

  Start-Process $probePath | Out-Null
  Write-AppLog 'testing_open_probe' ('path=' + $probePath)
  return [ordered]@{ ok = $true; path = $probePath }
}

function Run-TestingOverlayRecordCapture {
  param(
    [int]$DurationSec = 6,
    [int]$Fps = 10
  )

  $scriptPath = Join-Path (Get-TestingScriptsRoot) 'test_overlay_record_capture.ps1'
  if (-not (Test-Path $scriptPath)) {
    return [ordered]@{ ok = $false; error = 'record test script not found'; path = $scriptPath }
  }

  if ($DurationSec -lt 4) { $DurationSec = 4 }
  if ($DurationSec -gt 30) { $DurationSec = 30 }
  if ($Fps -lt 5) { $Fps = 5 }
  if ($Fps -gt 30) { $Fps = 30 }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'powershell.exe'
  $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -DurationSec {1} -Fps {2}' -f $scriptPath, $DurationSec, $Fps)
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  [void]$proc.Start()
  $stdout = $proc.StandardOutput.ReadToEnd()
  $stderr = $proc.StandardError.ReadToEnd()
  $proc.WaitForExit()

  $output = (($stdout + [Environment]::NewLine + $stderr).Trim())
  $summary = 'overlay record test finished: exit=' + $proc.ExitCode
  if ($output -match '(?im)^RESULT:\s*([A-Z]+)') {
    $summary = 'overlay record result: ' + $Matches[1]
  }

  Write-AppLog 'testing_run_overlay_record_capture' ('exit=' + $proc.ExitCode + ' duration=' + $DurationSec + ' fps=' + $Fps)
  return [ordered]@{
    ok = ($proc.ExitCode -eq 0)
    exit_code = $proc.ExitCode
    summary = $summary
    output = $output
  }
}

function Run-TestingVoiceLatencyBenchmark {
  $scriptPath = Get-TestingVoiceLatencyScriptPath
  if (-not (Test-Path -LiteralPath $scriptPath)) {
    return [ordered]@{ ok = $false; error = 'voice latency test script not found'; path = $scriptPath }
  }
  $dataFilePath = $DataFile
  if (-not [IO.Path]::IsPathRooted([string]$dataFilePath)) {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $dataFilePath = Join-Path $repoRoot $dataFilePath
  }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'powershell.exe'
  $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -DataFile "{1}"' -f $scriptPath, $dataFilePath)
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.WorkingDirectory = Split-Path -Parent $scriptPath

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  [void]$proc.Start()
  $stdout = $proc.StandardOutput.ReadToEnd()
  $stderr = $proc.StandardError.ReadToEnd()
  $proc.WaitForExit()

  $raw = ([string]$stdout).Trim()
  if ([string]::IsNullOrWhiteSpace($raw) -and -not [string]::IsNullOrWhiteSpace([string]$stderr)) {
    $raw = ([string]$stderr).Trim()
  }

  $parsed = $null
  try {
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      $parsed = $raw | ConvertFrom-Json
    }
  } catch {
    $message = 'voice latency benchmark json parse failed: ' + $_.Exception.Message
    Write-AppLog 'testing_voice_latency_parse_failed' $message
    return [ordered]@{
      ok = $false
      error = $message
      exit_code = $proc.ExitCode
      stdout = $stdout
      stderr = $stderr
      state = (Get-TestingVoiceLatencyState)
    }
  }

  if ($null -eq $parsed) {
    return [ordered]@{
      ok = $false
      error = 'voice latency benchmark returned empty payload'
      exit_code = $proc.ExitCode
      stdout = $stdout
      stderr = $stderr
      state = (Get-TestingVoiceLatencyState)
    }
  }

  $errorText = ([string](Get-Prop $parsed 'error' '')).Trim()
  $elapsedMs = [int](Get-Prop $parsed 'elapsed_ms' 0)
  $transcript = [string](Get-Prop $parsed 'transcript' '')
  $metrics = Get-Prop $parsed 'metrics' @{}
  $stage = [string](Get-Prop $parsed 'status_stage' '')
  $detail = [string](Get-Prop $parsed 'status_detail' '')
  $ok = ($proc.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($errorText))

  Write-AppLog 'testing_voice_latency_benchmark' ('ok=' + $ok + ' elapsed_ms=' + $elapsedMs + ' exit=' + $proc.ExitCode)
  return [ordered]@{
    ok = $ok
    state = (Get-TestingVoiceLatencyState)
    started_at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    elapsed_ms = $elapsedMs
    exit_code = [int](Get-Prop $parsed 'exit_code' $proc.ExitCode)
    transcript = $transcript
    transcript_chars = [int](Get-Prop $parsed 'transcript_chars' 0)
    text = [string](Get-Prop $parsed 'text' '')
    error = $errorText
    metrics = $metrics
    status_stage = $stage
    status_detail = $detail
  }
}

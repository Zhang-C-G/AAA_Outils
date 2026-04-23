function Get-TestingScriptsRoot {
  return (Join-Path $PSScriptRoot '..\..\scripts')
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
  $summary = '录屏捕获检测完成: exit=' + $proc.ExitCode
  if ($output -match '(?im)^RESULT:\s*([A-Z]+)') {
    $summary = '录屏捕获检测结果: ' + $Matches[1]
  }

  Write-AppLog 'testing_run_overlay_record_capture' ('exit=' + $proc.ExitCode + ' duration=' + $DurationSec + ' fps=' + $Fps)
  return [ordered]@{
    ok = ($proc.ExitCode -eq 0)
    exit_code = $proc.ExitCode
    summary = $summary
    output = $output
  }
}

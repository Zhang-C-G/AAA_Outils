param()

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$mainScript = Join-Path $projectRoot 'main.ahk'
$candidates = @(
  (Join-Path $projectRoot 'LOGICIEL_Autohotkey\v2\AutoHotkey64.exe'),
  (Join-Path $projectRoot 'LOGICIEL_Autohotkey\UX\AutoHotkeyUX.exe')
)

function Get-MainAhkProcesses {
  param([string]$ScriptPath)

  Get-CimInstance Win32_Process |
    Where-Object {
      $_.Name -like 'AutoHotkey*.exe' -and
      $_.CommandLine -and
      $_.CommandLine.Contains($ScriptPath)
    }
}

$existing = @(Get-MainAhkProcesses -ScriptPath $mainScript)
foreach ($proc in $existing) {
  Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Milliseconds 800

$ahkExe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ahkExe) {
  throw "AutoHotkey executable not found for $mainScript"
}

Start-Process -FilePath $ahkExe -ArgumentList @($mainScript)
Start-Sleep -Seconds 2

$running = @(Get-MainAhkProcesses -ScriptPath $mainScript)
if ($running.Count -lt 1) {
  throw "Failed to start $mainScript"
}

$running |
  Select-Object ProcessId, Name, ExecutablePath, CommandLine

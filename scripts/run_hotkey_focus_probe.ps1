param()

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$probePath = Join-Path $scriptDir "hotkey_focus_probe.html"

if (!(Test-Path $probePath)) {
  throw "Probe file not found: $probePath"
}

Write-Host "Opening probe page..."
Start-Process $probePath | Out-Null
Write-Host "Opened: $probePath"
Write-Host "Use this page to observe: focus/blur, visibilitychange, keydown/keyup."


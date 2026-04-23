param(
  [int]$Port = 19021
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$dataTest = Join-Path $env:TEMP 'raccourci_test_config.ini'
$usageTest = Join-Path $env:TEMP 'raccourci_test_usage.ini'
$snapshotTest = Join-Path $env:TEMP 'raccourci_test_snapshot.ini'
$pidFile = Join-Path $env:TEMP 'raccourci_test_web.pid'
$actionFile = Join-Path $env:TEMP 'raccourci_test_action.json'
$bridgeScript = Join-Path $env:TEMP 'raccourci_test_bridge.ps1'
$bridgePid = Join-Path $env:TEMP 'raccourci_test_bridge.pid'
$bridgeStatus = Join-Path $env:TEMP 'raccourci_test_bridge_status.ini'
$logFile = Join-Path $env:TEMP 'raccourci_test_action.log'

Copy-Item (Join-Path $root 'config.ini') $dataTest -Force
Copy-Item (Join-Path $root 'usage.ini') $usageTest -Force

$args = @(
  '-NoProfile', '-ExecutionPolicy', 'Bypass',
  '-File', (Join-Path $root 'webui\config\server.ps1'),
  '-Port', $Port,
  '-Root', (Join-Path $root 'webui\config'),
  '-DataFile', $dataTest,
  '-UsageFile', $usageTest,
  '-SnapshotFile', $snapshotTest,
  '-ActionFile', $actionFile,
  '-PidFile', $pidFile,
  '-NotesDir', (Join-Path $root 'notes'),
  '-CaptureDir', (Join-Path $root 'captures'),
  '-BridgeScript', $bridgeScript,
  '-BridgePidFile', $bridgePid,
  '-BridgeStatusFile', $bridgeStatus,
  '-LogFile', $logFile
)

$p = Start-Process powershell -ArgumentList $args -PassThru -WindowStyle Hidden
try {
  $ok = $false
  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 200
    try {
      if ((Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/ping" -Method Get -TimeoutSec 2).ok) {
        $ok = $true
        break
      }
    } catch {}
  }
  if (-not $ok) { throw 'web config server start failed' }

  $saveBody = [ordered]@{
    enabled = 1
    api_endpoint = 'mock://local'
    api_key = ''
    model = 'mock-local'
    overlay_opacity = 92
    active_template = 'test_template'
    templates = @(
      [ordered]@{
        name = 'test_template'
        prompt = 'Please answer in test template style.'
      }
    )
  }

  $saveResp = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/assistant/save-settings" -Method Post -ContentType 'application/json' -Body ($saveBody | ConvertTo-Json -Depth 10) -TimeoutSec 10
  if (-not $saveResp.ok) { throw 'save assistant settings failed' }

  $runResp = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/assistant/capture-ask" -Method Post -ContentType 'application/json' -Body '{}' -TimeoutSec 30
  if (-not $runResp.ok) { throw ("capture ask failed: " + [string]$runResp.error) }

  if ([string]::IsNullOrWhiteSpace([string]$runResp.text)) {
    throw 'assistant text empty'
  }

  Write-Output 'PASS: assistant mock flow success'
  Write-Output ('Capture: ' + [string]$runResp.path)
  Write-Output 'Answer Preview:'
  Write-Output ([string]$runResp.text)
}
finally {
  if ($p -and -not $p.HasExited) {
    Stop-Process -Id $p.Id -Force
  }
  foreach ($f in @($dataTest, $usageTest, $snapshotTest, $pidFile, $actionFile, $bridgeScript, $bridgePid, $bridgeStatus, $logFile)) {
    if (Test-Path $f) {
      Remove-Item $f -Force -ErrorAction SilentlyContinue
    }
  }
}

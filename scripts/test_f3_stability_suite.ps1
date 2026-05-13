param(
  [string]$RepoRoot = '',
  [switch]$OpenOverlayFirst,
  [int]$LatencyIterations = 4,
  [int]$LatencyHoldMs = 2600,
  [int]$LatencyWaitAfterReleaseMs = 4500,
  [int]$RestartIterations = 3,
  [int]$PrewarmWaitMs = 2600,
  [int]$WaitAfterSecondReleaseMs = 7000,
  [int]$BenchmarkElapsedWarn = 4000,
  [int]$BenchmarkFirstTextWarn = 1200
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}

function Invoke-JsonScript {
  param(
    [string]$ScriptPath,
    [string[]]$Arguments
  )

  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "script failed: $ScriptPath"
  }
  return ($output | ConvertFrom-Json)
}

$latencyScript = Join-Path $PSScriptRoot 'test_f3_latency_report.ps1'
$restartScript = Join-Path $PSScriptRoot 'test_f3_restart_flow.ps1'
$benchmarkScript = Join-Path $PSScriptRoot 'test_xunfei_voice_latency.ps1'

$latencyArgs = @(
  '-RepoRoot', $RepoRoot,
  '-Iterations', [string]$LatencyIterations,
  '-HoldMs', [string]$LatencyHoldMs,
  '-WaitAfterReleaseMs', [string]$LatencyWaitAfterReleaseMs
)
if ($OpenOverlayFirst) {
  $latencyArgs += '-OpenOverlayFirst'
}

$latency = Invoke-JsonScript -ScriptPath $latencyScript -Arguments $latencyArgs
$benchmark = Invoke-JsonScript -ScriptPath $benchmarkScript -Arguments @('-DataFile', (Join-Path $RepoRoot 'config.ini'))

$restartRuns = @()
for ($i = 1; $i -le $RestartIterations; $i++) {
  $restartArgs = @(
    '-RepoRoot', $RepoRoot,
    '-PrewarmWaitMs', [string]$PrewarmWaitMs,
    '-WaitAfterSecondReleaseMs', [string]$WaitAfterSecondReleaseMs
  )
  if ($OpenOverlayFirst) {
    $restartArgs += '-OpenOverlayFirst'
  }
  $restartResult = Invoke-JsonScript -ScriptPath $restartScript -Arguments $restartArgs
  $restartRuns += [pscustomobject][ordered]@{
    iteration = $i
    ok = [bool]$restartResult.ok
    prewarm_ready = [bool]$restartResult.prewarm_ready
    first_start_ready = [bool]$restartResult.first_start_ready
    restart_requested = [int]$restartResult.restart_requested
    restart_completed = [int]$restartResult.restart_completed
    start_events = [int]$restartResult.start_events
    stop_failed_events = [int]$restartResult.stop_failed_events
    latest_final_outcome = [string]$restartResult.latest_final_outcome
  }
}

$restartFailures = @($restartRuns | Where-Object { -not $_.ok }).Count
$restartStopFailures = ($restartRuns | Measure-Object -Property stop_failed_events -Sum).Sum
$restartRequestedTotal = ($restartRuns | Measure-Object -Property restart_requested -Sum).Sum
$restartCompletedTotal = ($restartRuns | Measure-Object -Property restart_completed -Sum).Sum

$ok = [bool]$latency.ok
if ($restartFailures -gt 0) {
  $ok = $false
}
if ($restartStopFailures -gt 0) {
  $ok = $false
}
if ($restartRequestedTotal -lt $RestartIterations) {
  $ok = $false
}
if ($restartCompletedTotal -lt $RestartIterations) {
  $ok = $false
}
if ([int]$benchmark.elapsed_ms -gt $BenchmarkElapsedWarn) {
  $ok = $false
}
$benchmarkFirstText = 0
if ($null -ne $benchmark.metrics -and $benchmark.metrics.PSObject.Properties.Name -contains 'first_nonempty_text_received_ms') {
  $benchmarkFirstText = [int]$benchmark.metrics.first_nonempty_text_received_ms
}
if ($benchmarkFirstText -gt $BenchmarkFirstTextWarn) {
  $ok = $false
}

[ordered]@{
  ok = $ok
  started_at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  latency = $latency
  benchmark = [ordered]@{
    elapsed_ms = [int]$benchmark.elapsed_ms
    transcript_chars = [int]$benchmark.transcript_chars
    status_stage = [string]$benchmark.status_stage
    status_detail = [string]$benchmark.status_detail
    first_nonempty_text_received_ms = $benchmarkFirstText
    first_result_received_ms = if ($null -ne $benchmark.metrics -and $benchmark.metrics.PSObject.Properties.Name -contains 'first_result_received_ms') { [int]$benchmark.metrics.first_result_received_ms } else { 0 }
    websocket_connected_ms = if ($null -ne $benchmark.metrics -and $benchmark.metrics.PSObject.Properties.Name -contains 'websocket_connected_ms') { [int]$benchmark.metrics.websocket_connected_ms } else { 0 }
    warn_thresholds = [ordered]@{
      elapsed_ms = $BenchmarkElapsedWarn
      first_nonempty_text_received_ms = $BenchmarkFirstTextWarn
    }
  }
  restart_iterations = $RestartIterations
  restart_failures = $restartFailures
  restart_stop_failed_events = $restartStopFailures
  restart_requested_total = [int]$restartRequestedTotal
  restart_completed_total = [int]$restartCompletedTotal
  restart_runs = $restartRuns
} | ConvertTo-Json -Depth 6

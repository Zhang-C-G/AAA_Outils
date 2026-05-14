param(
  [string]$RepoRoot = '',
  [switch]$OpenOverlayFirst,
  [int]$PrewarmWaitMs = 3200,
  [int]$PrewarmReadyTimeoutMs = 25000,
  [int]$VoiceStartTimeoutMs = 8000,
  [int]$FirstHoldMs = 900,
  [int]$GapAfterFirstReleaseMs = 140,
  [int]$SecondHoldMs = 900,
  [int]$WaitAfterSecondReleaseMs = 7000
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}

$logPath = Join-Path $RepoRoot 'action.log'
$sessionPath = Join-Path $RepoRoot 'assistant_voice_sessions.jsonl'
$actionPath = Join-Path $env:TEMP 'raccourci_web_config_action.json'

if (-not (Test-Path -LiteralPath $logPath)) {
  throw "action log not found: $logPath"
}
if (-not (Test-Path -LiteralPath $sessionPath)) {
  [IO.File]::WriteAllText($sessionPath, '', [Text.UTF8Encoding]::new($false))
}

$initialLogLineCount = @([IO.File]::ReadAllLines($logPath, [Text.Encoding]::UTF8)).Count
$initialSessionLineCount = @([IO.File]::ReadAllLines($sessionPath, [Text.Encoding]::UTF8)).Count
$testStartedAt = Get-Date

function Send-AhkAction {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Action,
    [int]$WaitMs = 220
  )
  [IO.File]::WriteAllText($actionPath, $Action, [Text.UTF8Encoding]::new($false))
  Start-Sleep -Milliseconds $WaitMs
}

function Wait-ActionLogPattern {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Pattern,
    [int]$TimeoutMs = 10000
  )

  $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
  while ([DateTime]::UtcNow -lt $deadline) {
    $lines = [IO.File]::ReadAllLines($logPath, [Text.Encoding]::UTF8)
    if ($lines.Count -gt $initialLogLineCount) {
      $slice = $lines[$initialLogLineCount..($lines.Count - 1)]
      foreach ($line in $slice) {
        if ($line -match $Pattern) {
          return $true
        }
      }
    }
    Start-Sleep -Milliseconds 180
  }
  return $false
}

try {
  $prewarmReady = $false
  $firstStartReady = $false
  if ($OpenOverlayFirst) {
    Send-AhkAction -Action 'assistant_overlay_open_only'
    Start-Sleep -Milliseconds $PrewarmWaitMs
    $prewarmReady = Wait-ActionLogPattern -Pattern '\| assistant_voice_service_ready \|' -TimeoutMs $PrewarmReadyTimeoutMs
  }
  Send-AhkAction -Action 'assistant_voice_input_down'
  $firstStartReady = Wait-ActionLogPattern -Pattern '\| assistant_voice_input_start \|' -TimeoutMs $VoiceStartTimeoutMs
  Start-Sleep -Milliseconds $FirstHoldMs
  Send-AhkAction -Action 'assistant_voice_input_up'
  Start-Sleep -Milliseconds $GapAfterFirstReleaseMs
  Send-AhkAction -Action 'assistant_voice_input_down'
  Start-Sleep -Milliseconds $SecondHoldMs
  Send-AhkAction -Action 'assistant_voice_input_up'
  Start-Sleep -Milliseconds $WaitAfterSecondReleaseMs
} finally {
  Remove-Item -LiteralPath $actionPath -Force -ErrorAction SilentlyContinue
}

$allLogLines = [IO.File]::ReadAllLines($logPath, [Text.Encoding]::UTF8)
$newLogLines = if ($initialLogLineCount -lt $allLogLines.Count) {
  $allLogLines[$initialLogLineCount..($allLogLines.Count - 1)]
} else {
  @()
}

$allSessionLines = [IO.File]::ReadAllLines($sessionPath, [Text.Encoding]::UTF8)
$newSessionLines = if ($initialSessionLineCount -lt $allSessionLines.Count) {
  $allSessionLines[$initialSessionLineCount..($allSessionLines.Count - 1)] | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
} else {
  @()
}

$sessions = @()
foreach ($line in $newSessionLines) {
  try {
    $sessions += ($line | ConvertFrom-Json)
  } catch {
  }
}

$restartRequested = @($newLogLines | Where-Object { $_ -match '\| assistant_voice_input_restart_requested \|' }).Count
$restartCompleted = @($newLogLines | Where-Object { $_ -match '\| assistant_voice_input_restarted \|' }).Count
$starts = @($newLogLines | Where-Object { $_ -match '\| assistant_voice_input_start \|' }).Count
$texts = @($newLogLines | Where-Object { $_ -match '\| assistant_voice_input_text \|' }).Count
$empty = @($newLogLines | Where-Object { $_ -match '\| assistant_voice_input_empty \|' }).Count
$stopFailed = @($newLogLines | Where-Object { $_ -match '\| assistant_voice_input_stop_failed \|' }).Count

$cancelledForRestart = @($sessions | Where-Object { $_.outcome -eq 'cancelled_for_restart' }).Count
$finalOutcomes = @($sessions | Where-Object { $_.outcome -ne 'cancelled_for_restart' })
$latestFinal = if ($finalOutcomes.Count -gt 0) { $finalOutcomes[-1] } else { $null }

$pass = ($restartRequested -ge 1 -and $starts -ge 2 -and $cancelledForRestart -ge 1 -and $stopFailed -eq 0)

[ordered]@{
  ok = $pass
  started_at = $testStartedAt.ToString('yyyy-MM-dd HH:mm:ss')
  first_hold_ms = $FirstHoldMs
  prewarm_wait_ms = $PrewarmWaitMs
  prewarm_ready = [bool]$prewarmReady
  prewarm_ready_timeout_ms = $PrewarmReadyTimeoutMs
  voice_start_timeout_ms = $VoiceStartTimeoutMs
  first_start_ready = [bool]$firstStartReady
  open_overlay_first = [bool]$OpenOverlayFirst
  second_hold_ms = $SecondHoldMs
  gap_after_first_release_ms = $GapAfterFirstReleaseMs
  wait_after_second_release_ms = $WaitAfterSecondReleaseMs
  restart_requested = $restartRequested
  restart_completed = $restartCompleted
  start_events = $starts
  text_events = $texts
  empty_events = $empty
  stop_failed_events = $stopFailed
  cancelled_for_restart = $cancelledForRestart
  session_count = $sessions.Count
  latest_final_outcome = if ($null -ne $latestFinal) { [string]$latestFinal.outcome } else { '' }
  latest_final_total_ms = if ($null -ne $latestFinal) { [int]$latestFinal.total_ms } else { 0 }
  latest_final_finalize_ms = if ($null -ne $latestFinal) { [int]$latestFinal.finalize_ms } else { 0 }
  latest_final_chars = if ($null -ne $latestFinal) { [int]$latestFinal.transcript_chars } else { 0 }
  sessions = $sessions
} | ConvertTo-Json -Depth 6

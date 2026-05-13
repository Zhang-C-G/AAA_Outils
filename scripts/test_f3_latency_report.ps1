param(
  [string]$RepoRoot = '',
  [switch]$OpenOverlayFirst,
  [int]$Iterations = 3,
  [int]$PrewarmWaitMs = 2200,
  [int]$PrewarmReadyTimeoutMs = 12000,
  [int]$VoiceStartTimeoutMs = 8000,
  [int]$HoldMs = 2400,
  [int]$WaitAfterReleaseMs = 4500,
  [int]$LaunchMsWarn = 180,
  [int]$ConnectedMsWarn = 1500,
  [int]$FirstAudioSentMsWarn = 1800,
  [int]$FinalizeMsWarn = 2600
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

function Send-AhkAction {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Action,
    [int]$WaitMs = 220
  )
  [IO.File]::WriteAllText($actionPath, $Action, [Text.UTF8Encoding]::new($false))
  Start-Sleep -Milliseconds $WaitMs
}

function Get-NewLinesSince {
  param(
    [string]$Path,
    [int]$LineCount
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return @()
  }
  $allLines = [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)
  if ($LineCount -ge $allLines.Count) {
    return @()
  }
  return $allLines[$LineCount..($allLines.Count - 1)]
}

function Wait-Pattern {
  param(
    [string]$Path,
    [int]$BaseLineCount,
    [string]$Pattern,
    [int]$TimeoutMs
  )

  $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
  while ([DateTime]::UtcNow -lt $deadline) {
    $lines = Get-NewLinesSince -Path $Path -LineCount $BaseLineCount
    foreach ($line in $lines) {
      if ($line -match $Pattern) {
        return $line
      }
    }
    Start-Sleep -Milliseconds 100
  }
  return $null
}

function Get-JsonSessionsSince {
  param([int]$BaseLineCount)
  $newLines = Get-NewLinesSince -Path $sessionPath -LineCount $BaseLineCount
  $items = @()
  foreach ($line in $newLines) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }
    try {
      $items += ($line | ConvertFrom-Json)
    } catch {
    }
  }
  return $items
}

function Get-StatSummary {
  param([object[]]$Values)

  $nums = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ })
  if ($nums.Count -eq 0) {
    return [ordered]@{
      count = 0
      min = 0
      avg = 0
      max = 0
      p95 = 0
    }
  }

  $sorted = @($nums | Sort-Object)
  $avg = ($nums | Measure-Object -Average).Average
  $p95Index = [Math]::Ceiling($sorted.Count * 0.95) - 1
  if ($p95Index -lt 0) { $p95Index = 0 }
  if ($p95Index -ge $sorted.Count) { $p95Index = $sorted.Count - 1 }

  return [ordered]@{
    count = $sorted.Count
    min = [int][Math]::Round($sorted[0])
    avg = [int][Math]::Round($avg)
    max = [int][Math]::Round($sorted[-1])
    p95 = [int][Math]::Round($sorted[$p95Index])
  }
}

function Get-MetricValue {
  param($Session, [string]$Name)
  if ($null -eq $Session) {
    return $null
  }
  if ($null -ne $Session.metrics -and $Session.metrics.PSObject.Properties.Name -contains $Name) {
    return [int]$Session.metrics.$Name
  }
  return $null
}

$initialLogLineCount = @([IO.File]::ReadAllLines($logPath, [Text.Encoding]::UTF8)).Count
$initialSessionLineCount = @([IO.File]::ReadAllLines($sessionPath, [Text.Encoding]::UTF8)).Count
$testStartedAt = Get-Date
$iterationResults = @()
$prewarmReadyLine = $null

try {
  if ($OpenOverlayFirst) {
    Send-AhkAction -Action 'assistant_overlay_open_only'
    Start-Sleep -Milliseconds $PrewarmWaitMs
    $prewarmReadyLine = Wait-Pattern -Path $logPath -BaseLineCount $initialLogLineCount -Pattern '\| assistant_voice_service_ready \|' -TimeoutMs $PrewarmReadyTimeoutMs
  }

  for ($i = 1; $i -le $Iterations; $i++) {
    $runLogBase = @([IO.File]::ReadAllLines($logPath, [Text.Encoding]::UTF8)).Count
    $runSessionBase = @([IO.File]::ReadAllLines($sessionPath, [Text.Encoding]::UTF8)).Count

    Send-AhkAction -Action 'assistant_voice_input_down'
    $startLine = Wait-Pattern -Path $logPath -BaseLineCount $runLogBase -Pattern '\| assistant_voice_input_start \|' -TimeoutMs $VoiceStartTimeoutMs
    Start-Sleep -Milliseconds $HoldMs
    Send-AhkAction -Action 'assistant_voice_input_up'
    Start-Sleep -Milliseconds $WaitAfterReleaseMs

    $runLogLines = Get-NewLinesSince -Path $logPath -LineCount $runLogBase
    $sessions = @(Get-JsonSessionsSince -BaseLineCount $runSessionBase)
    $latestSession = if ($sessions.Count -gt 0) { $sessions[-1] } else { $null }

    $launchMs = $null
    if ($null -ne $startLine -and $startLine -match 'launch_ms=(\d+)') {
      $launchMs = [int]$matches[1]
    }

    $firstTextLine = $runLogLines | Where-Object { $_ -match '\| assistant_voice_first_text \|' } | Select-Object -First 1
    $firstTextLogMs = $null
    if ($null -ne $firstTextLine -and $firstTextLine -match 'elapsed_ms=(\d+)') {
      $firstTextLogMs = [int]$matches[1]
    }

    $iterationResults += [pscustomobject][ordered]@{
      iteration = $i
      start_logged = [bool]($null -ne $startLine)
      launch_ms = $launchMs
      outcome = if ($null -ne $latestSession) { [string]$latestSession.outcome } else { '' }
      transcript_chars = if ($null -ne $latestSession) { [int]$latestSession.transcript_chars } else { 0 }
      total_ms = if ($null -ne $latestSession) { [int]$latestSession.total_ms } else { 0 }
      hold_ms = if ($null -ne $latestSession) { [int]$latestSession.hold_ms } else { 0 }
      finalize_ms = if ($null -ne $latestSession) { [int]$latestSession.finalize_ms } else { 0 }
      websocket_connected_ms = Get-MetricValue -Session $latestSession -Name 'websocket_connected_ms'
      audio_stream_ready_ms = Get-MetricValue -Session $latestSession -Name 'audio_stream_ready_ms'
      first_audio_sent_ms = Get-MetricValue -Session $latestSession -Name 'first_audio_sent_ms'
      first_result_received_ms = Get-MetricValue -Session $latestSession -Name 'first_result_received_ms'
      first_nonempty_text_received_ms = Get-MetricValue -Session $latestSession -Name 'first_nonempty_text_received_ms'
      first_text_log_ms = $firstTextLogMs
    }
  }
} finally {
  Remove-Item -LiteralPath $actionPath -Force -ErrorAction SilentlyContinue
}

$textSessions = @($iterationResults | Where-Object { $_.outcome -eq 'text' })
$failedStarts = @($iterationResults | Where-Object { -not $_.start_logged }).Count
$failedSessions = @($iterationResults | Where-Object { $_.outcome -eq 'failed' }).Count

$launchStats = Get-StatSummary ($iterationResults.launch_ms)
$connectedStats = Get-StatSummary ($iterationResults.websocket_connected_ms)
$firstAudioSentStats = Get-StatSummary ($iterationResults.first_audio_sent_ms)
$finalizeStats = Get-StatSummary ($iterationResults.finalize_ms)
$firstNonemptyStats = Get-StatSummary ($textSessions.first_nonempty_text_received_ms)
$firstTextLogStats = Get-StatSummary ($textSessions.first_text_log_ms)

$ok = $true
if ($failedStarts -gt 0 -or $failedSessions -gt 0) {
  $ok = $false
}
if ($launchStats.count -gt 0 -and $launchStats.p95 -gt $LaunchMsWarn) {
  $ok = $false
}
if ($connectedStats.count -gt 0 -and $connectedStats.p95 -gt $ConnectedMsWarn) {
  $ok = $false
}
if ($firstAudioSentStats.count -gt 0 -and $firstAudioSentStats.p95 -gt $FirstAudioSentMsWarn) {
  $ok = $false
}
if ($finalizeStats.count -gt 0 -and $finalizeStats.p95 -gt $FinalizeMsWarn) {
  $ok = $false
}

[ordered]@{
  ok = $ok
  started_at = $testStartedAt.ToString('yyyy-MM-dd HH:mm:ss')
  iterations = $Iterations
  open_overlay_first = [bool]$OpenOverlayFirst
  prewarm_ready = [bool]($null -ne $prewarmReadyLine)
  failed_starts = $failedStarts
  failed_sessions = $failedSessions
  text_session_count = $textSessions.Count
  empty_session_count = @($iterationResults | Where-Object { $_.outcome -eq 'empty' }).Count
  cancelled_session_count = @($iterationResults | Where-Object { $_.outcome -eq 'cancelled_for_restart' }).Count
  launch_ms = $launchStats
  websocket_connected_ms = $connectedStats
  first_audio_sent_ms = $firstAudioSentStats
  finalize_ms = $finalizeStats
  first_nonempty_text_received_ms = $firstNonemptyStats
  first_text_log_ms = $firstTextLogStats
  warn_thresholds = [ordered]@{
    launch_ms_p95 = $LaunchMsWarn
    websocket_connected_ms_p95 = $ConnectedMsWarn
    first_audio_sent_ms_p95 = $FirstAudioSentMsWarn
    finalize_ms_p95 = $FinalizeMsWarn
  }
  runs = $iterationResults
} | ConvertTo-Json -Depth 6

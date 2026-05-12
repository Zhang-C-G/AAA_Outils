param(
  [string]$Text = '',
  [string]$DataFile = 'config.ini'
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$PSNativeCommandUseErrorActionPreference = $false

function Unprotect-AssistantSecret {
  param([string]$Encoded)
  $raw = ([string]$Encoded).Trim()
  if ($raw -eq '') { return '' }
  try {
    $secure = ConvertTo-SecureString -String $raw
    return ([pscredential]::new('u', $secure)).GetNetworkCredential().Password
  } catch {
    return ''
  }
}

function Read-IniSection {
  param(
    [string]$Path,
    [string]$SectionName
  )

  $map = [ordered]@{}
  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
    return $map
  }

  $currentSection = ''
  foreach ($line in [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)) {
    $trimmed = ([string]$line).Trim()
    if ($trimmed -eq '') { continue }
    if ($trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) { continue }
    if ($trimmed -match '^\[(.+)\]$') {
      $currentSection = $matches[1].Trim()
      continue
    }
    if ($currentSection -ne $SectionName) { continue }
    $pair = $trimmed.Split('=', 2)
    if ($pair.Length -ne 2) { continue }
    $map[$pair[0].Trim()] = $pair[1]
  }
  return $map
}

function Get-XunfeiConfig {
  param([string]$IniPath)

  $sec = Read-IniSection -Path $IniPath -SectionName 'Assistant'
  $appId = if ($sec.Contains('xunfei_app_id')) { ([string]$sec['xunfei_app_id']).Trim() } else { '' }
  $apiKey = if ($sec.Contains('xunfei_api_key')) { ([string]$sec['xunfei_api_key']).Trim() } else { '' }
  $apiSecret = if ($sec.Contains('xunfei_api_secret')) { ([string]$sec['xunfei_api_secret']).Trim() } else { '' }

  if ($apiKey -eq '' -and $sec.Contains('xunfei_api_key_protected')) {
    $apiKey = Unprotect-AssistantSecret ([string]$sec['xunfei_api_key_protected'])
  }
  if ($apiSecret -eq '' -and $sec.Contains('xunfei_api_secret_protected')) {
    $apiSecret = Unprotect-AssistantSecret ([string]$sec['xunfei_api_secret_protected'])
  }

  return [ordered]@{
    app_id = $appId
    api_key = $apiKey
    api_secret = $apiSecret
  }
}

$cfg = Get-XunfeiConfig -IniPath $DataFile
if ([string]::IsNullOrWhiteSpace([string]$cfg.app_id) -or [string]::IsNullOrWhiteSpace([string]$cfg.api_key) -or [string]::IsNullOrWhiteSpace([string]$cfg.api_secret)) {
  throw 'xunfei websocket credentials missing in config.ini'
}

if ([string]::IsNullOrWhiteSpace($Text)) {
  $textCodePoints = @(
    20320,22909,65292,29616,22312,24320,22987,27979,35797,35821,38899,35782,21035,24310,36831,12290,
    25105,20204,38656,35201,30830,35748,39318,26465,35782,21035,32467,26524,36820,22238,30340,36895,
    24230,26159,21542,36275,22815,24555,12290
  )
  $Text = -join ($textCodePoints | ForEach-Object { [char]$_ })
}

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($null -eq $ffmpeg) {
  throw 'ffmpeg not found'
}
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $pythonCmd) {
  throw 'python not found'
}

$wavPath = Join-Path $env:TEMP 'xunfei_latency_benchmark.wav'
$pcmPath = Join-Path $env:TEMP 'xunfei_latency_benchmark.pcm'
$outPath = Join-Path $env:TEMP 'xunfei_latency_benchmark_out.txt'
$errPath = Join-Path $env:TEMP 'xunfei_latency_benchmark_err.txt'
$statusPath = Join-Path $env:TEMP 'xunfei_latency_benchmark_status.txt'

function Read-StatusMetrics {
  param([string]$Path)

  $stage = ''
  $detail = ''
  $metrics = [ordered]@{}
  if (-not (Test-Path -LiteralPath $Path)) {
    return [ordered]@{
      stage = $stage
      detail = $detail
      metrics = $metrics
    }
  }

  foreach ($line in [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)) {
    $trimmed = ([string]$line).Trim()
    if ($trimmed -eq '') { continue }
    $pair = $trimmed.Split('=', 2)
    if ($pair.Length -ne 2) { continue }
    $key = $pair[0].Trim()
    $value = $pair[1].Trim()
    if ($key -eq 'stage') {
      $stage = $value
      continue
    }
    if ($key -eq 'detail') {
      $detail = $value
      continue
    }
    if ($key.StartsWith('metric_')) {
      $metricName = $key.Substring(7)
      $metricValue = 0
      if ([int]::TryParse($value, [ref]$metricValue)) {
        $metrics[$metricName] = $metricValue
      }
    }
  }

  return [ordered]@{
    stage = $stage
    detail = $detail
    metrics = $metrics
  }
}

function Invoke-NativeProcess {
  param(
    [string]$FilePath,
    [string[]]$ArgumentList
  )

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $FilePath
  $escapedArgs = @()
  foreach ($arg in $ArgumentList) {
    $escaped = [string]$arg
    if ($escaped -match '\s|"') {
      $escaped = '"' + ($escaped -replace '"', '\"') + '"'
    }
    $escapedArgs += $escaped
  }
  $psi.Arguments = [string]::Join(' ', $escapedArgs)
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

  return [ordered]@{
    exit_code = $proc.ExitCode
    stdout = $stdout
    stderr = $stderr
  }
}

foreach($path in @($wavPath, $pcmPath, $outPath, $errPath, $statusPath)) {
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
  }
}

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
  $synth.SetOutputToWaveFile($wavPath)
  $synth.Speak($Text)
} finally {
  $synth.Dispose()
}

$ffmpegRun = Invoke-NativeProcess -FilePath $ffmpeg.Source -ArgumentList @('-y', '-i', $wavPath, '-ac', '1', '-ar', '16000', '-f', 's16le', $pcmPath)
if ([int]$ffmpegRun.exit_code -ne 0) {
  throw ('ffmpeg convert failed: ' + ([string]$ffmpegRun.stderr).Trim())
}

$env:XUNFEI_APP_ID = ([string]$cfg.app_id).Trim()
$env:XUNFEI_API_KEY = ([string]$cfg.api_key).Trim()
$env:XUNFEI_API_SECRET = ([string]$cfg.api_secret).Trim()

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$pythonRun = Invoke-NativeProcess -FilePath $pythonCmd.Source -ArgumentList @((Join-Path $PSScriptRoot 'xunfei_asr.py'), '--audio', $pcmPath, '--status-path', $statusPath, '--output', $outPath, '--error-output', $errPath)
$exitCode = [int]$pythonRun.exit_code
$sw.Stop()

$transcript = ''
$errText = ''
$statusData = Read-StatusMetrics -Path $statusPath
if (Test-Path -LiteralPath $outPath) {
  $transcript = [IO.File]::ReadAllText($outPath, [Text.Encoding]::UTF8).Trim()
}
if (Test-Path -LiteralPath $errPath) {
  $errText = [IO.File]::ReadAllText($errPath, [Text.Encoding]::UTF8).Trim()
}

$result = [ordered]@{
  text = $Text
  elapsed_ms = [int]$sw.ElapsedMilliseconds
  exit_code = [int]$exitCode
  transcript = $transcript
  transcript_chars = $transcript.Length
  error = $errText
  status_stage = [string]$statusData.stage
  status_detail = [string]$statusData.detail
  metrics = $statusData.metrics
  wav_path = $wavPath
  pcm_path = $pcmPath
}

$result | ConvertTo-Json -Depth 4

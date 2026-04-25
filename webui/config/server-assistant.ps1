function Test-AssistantMockMode {
  param($Settings)
  $endpoint = ([string](Get-Prop $Settings 'api_endpoint' '')).Trim().ToLowerInvariant()
  $model = ([string](Get-Prop $Settings 'model' '')).Trim().ToLowerInvariant()
  return ($endpoint -eq 'mock://local' -or $model -eq 'mock-local')
}

function Get-AssistantMockAnswer {
  param([string]$ImagePath, $Settings)
  $template = ([string](Get-Prop $Settings 'active_template' 'default_template')).Trim()
  if ($template -eq '') { $template = 'default_template' }
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  return @"
[Local mock mode, no external API call]
Template: $template
Image: $ImagePath
Time: $ts

Mock answer:
Flow is OK: hotkey -> capture -> template -> overlay display.
You can keep using Alt+Up / Alt+Down to test overlay scrolling.
"@
}

function Get-AssistantRateFilePath {
  $dir = Split-Path -Parent $DataFile
  return (Join-Path $dir 'assistant_rate.ini')
}

function Ensure-AssistantRateStore {
  $rateFile = Get-AssistantRateFilePath
  if (Test-Path $rateFile) { return }
  [IO.File]::WriteAllText($rateFile, "[Rate]`r`nwindow=`r`ncount=0`r`n", [Text.Encoding]::UTF8)
}

function Save-AssistantRateState {
  param([string]$Window, [int]$Count)
  $rateFile = Get-AssistantRateFilePath
  $lines = @('[Rate]', ('window=' + $Window), ('count=' + $Count), '')
  [IO.File]::WriteAllText($rateFile, [string]::Join([Environment]::NewLine, $lines), [Text.Encoding]::UTF8)
}

function Consume-AssistantRateLimit {
  param($Settings)
  Ensure-AssistantRateStore

  $enabled = if ([string](Get-Prop $Settings 'rate_limit_enabled' '1') -eq '0') { 0 } else { 1 }
  if ($enabled -eq 0) {
    return [ordered]@{ ok=$true; used=0; limit=0; remaining=0 }
  }

  $limit = Clamp-AssistantRatePerHour (Get-Prop $Settings 'rate_limit_per_hour' 100)
  $window = Get-Date -Format 'yyyyMMddHH'
  $rateFile = Get-AssistantRateFilePath
  $ini = Read-Ini $rateFile

  $storedWindow = ''
  $count = 0
  if ($ini.Contains('Rate')) {
    $sec = $ini['Rate']
    if ($sec.Contains('window')) { $storedWindow = [string]$sec['window'] }
    if ($sec.Contains('count')) { [int]::TryParse([string]$sec['count'], [ref]$count) | Out-Null }
  }

  if ($storedWindow -ne $window) {
    $count = 0
  }

  if ($count -ge $limit) {
    return [ordered]@{
      ok = $false
      used = $count
      limit = $limit
      remaining = 0
      error = ('Hourly limit reached (' + $limit + ' requests).')
    }
  }

  $count += 1
  Save-AssistantRateState -Window $window -Count $count
  Write-AppLog 'assistant_rate_consume' ('window=' + $window + ' used=' + $count + '/' + $limit)

  return [ordered]@{
    ok = $true
    used = $count
    limit = $limit
    remaining = [Math]::Max(0, $limit - $count)
  }
}

function Extract-AssistantText {
  param($Response, [bool]$IsResponses)

  $text = ''
  if ($IsResponses) {
    if ($null -ne $Response.output_text -and ![string]::IsNullOrWhiteSpace([string]$Response.output_text)) {
      $text = [string]$Response.output_text
    }
    if ([string]::IsNullOrWhiteSpace($text) -and $null -ne $Response.output) {
      foreach ($o in $Response.output) {
        if ($null -eq $o.content) { continue }
        foreach ($c in $o.content) {
          if ($c.type -eq 'output_text' -and $c.text) {
            $text += [string]$c.text + "`n"
          }
        }
      }
    }
  } else {
    if ($null -ne $Response.choices -and $Response.choices.Count -gt 0) {
      $content = $Response.choices[0].message.content
      if ($content -is [System.Array]) {
        foreach ($it in $content) {
          if ($it.text) { $text += [string]$it.text + "`n" }
        }
      } else {
        $text = [string]$content
      }
    }
  }

  if ([string]::IsNullOrWhiteSpace($text) -and $null -ne $Response.output_text) {
    $text = [string]$Response.output_text
  }
  if ([string]::IsNullOrWhiteSpace($text)) {
    $text = ($Response | ConvertTo-Json -Depth 20)
  }
  return $text
}

function Extract-AssistantReasoning {
  param($Response, [bool]$IsResponses)

  $reasoning = ''
  if ($IsResponses) {
    if ($null -ne $Response.reasoning_content -and ![string]::IsNullOrWhiteSpace([string]$Response.reasoning_content)) {
      $reasoning = [string]$Response.reasoning_content
    }
    if ([string]::IsNullOrWhiteSpace($reasoning) -and $null -ne $Response.output) {
      foreach ($o in $Response.output) {
        if ($null -eq $o.content) { continue }
        foreach ($c in $o.content) {
          $ctype = [string](Get-Prop $c 'type' '')
          if ($ctype -match 'reasoning') {
            $text = [string](Get-Prop $c 'text' '')
            if ([string]::IsNullOrWhiteSpace($text)) {
              $text = [string](Get-Prop $c 'summary' '')
            }
            if ([string]::IsNullOrWhiteSpace($text) -and $null -ne (Get-Prop $c 'summary' $null)) {
              $summary = Get-Prop $c 'summary' $null
              if ($summary -is [System.Array]) {
                foreach ($item in $summary) {
                  $piece = [string](Get-Prop $item 'text' '')
                  if ($piece) { $reasoning += $piece + "`n" }
                }
              }
            } elseif ($text) {
              $reasoning += $text + "`n"
            }
          }
        }
      }
    }
  } else {
    if ($null -ne $Response.choices -and $Response.choices.Count -gt 0) {
      $msg = $Response.choices[0].message
      $reasoning = [string](Get-Prop $msg 'reasoning_content' '')
    }
  }

  return $reasoning.Trim()
}

function Invoke-AssistantByImage {
  param([string]$ImagePath, $Settings)
  try {
    if (!(Test-Path $ImagePath)) {
      return [ordered]@{ ok=$false; error='image not found'; text='' }
    }

    $endpoint = ([string](Get-Prop $Settings 'api_endpoint' 'https://ark.cn-beijing.volces.com/api/v3/responses')).Trim()
    if ($endpoint -eq '') { $endpoint = 'https://ark.cn-beijing.volces.com/api/v3/responses' }
    $apiKey = Resolve-AssistantApiKey -Settings $Settings
    $model = Resolve-AssistantModel -Requested ([string](Get-Prop $Settings 'model' 'doubao-seed-2-0-lite-260215')) -Fallback 'doubao-seed-2-0-lite-260215'
    $prompt = ([string](Get-AssistantPromptByTemplate -Settings $Settings)).Trim()
    if ($prompt -eq '') { $prompt = Get-AssistantDefaultPrompt }

    if (Test-AssistantMockMode -Settings $Settings) {
      return [ordered]@{ ok=$true; text=(Get-AssistantMockAnswer -ImagePath $ImagePath -Settings $Settings); error='' }
    }

    $bytes = [IO.File]::ReadAllBytes($ImagePath)
    $b64 = [Convert]::ToBase64String($bytes)
    $imgUrl = 'data:image/png;base64,' + $b64

    $headers = @{}
    if ($apiKey -ne '') {
      $headers['Authorization'] = 'Bearer ' + $apiKey
    }

    $isResponses = $endpoint.ToLowerInvariant().Contains('/responses')
    if ($isResponses) {
      $payload = [ordered]@{
        model = $model
        input = @(
          [ordered]@{
            role = 'user'
            content = @(
              [ordered]@{ type='input_image'; image_url=$imgUrl },
              [ordered]@{ type='input_text'; text=$prompt }
            )
          }
        )
      }
    } else {
      $payload = [ordered]@{
        model = $model
        messages = @(
          [ordered]@{
            role = 'user'
            content = @(
              [ordered]@{ type='text'; text=$prompt },
              [ordered]@{ type='image_url'; image_url=[ordered]@{ url=$imgUrl } }
            )
          }
        )
        temperature = 0.2
        max_tokens = 700
      }
    }

    $json = $payload | ConvertTo-Json -Depth 30
    $res = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -ContentType 'application/json' -Body $json
    $text = Extract-AssistantText -Response $res -IsResponses $isResponses
    $reasoning = Extract-AssistantReasoning -Response $res -IsResponses $isResponses

    return [ordered]@{ ok=$true; text=$text; reasoning=$reasoning; streamed=$false; error='' }
  } catch {
    return [ordered]@{ ok=$false; text=''; reasoning=''; streamed=$false; error=$_.Exception.Message }
  }
}

function Get-AssistantState {
  $settings = Get-AssistantSettings
  return [ordered]@{
    settings = (Get-AssistantPublicSettings -Settings $settings)
    latest_capture = (Get-CaptureLatestPath)
    benchmark = (Get-AssistantBenchmarkState)
  }
}

function Get-AssistantBenchmarkImagePath {
  return (Join-Path $CaptureDir 'assistant_api_benchmark_baseline.png')
}

function Ensure-AssistantBenchmarkImage {
  $path = Get-AssistantBenchmarkImagePath
  if (Test-Path -LiteralPath $path) {
    return $path
  }

  try {
    Ensure-CaptureStore
    Add-Type -AssemblyName System.Drawing | Out-Null

    $w = 1200
    $h = 760
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $font = New-Object System.Drawing.Font('Segoe UI', 18)
    $brush = [System.Drawing.Brushes]::Black
    try {
      $g.Clear([System.Drawing.Color]::White)
      $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
      $lines = @(
        '1. Alibaba prefers depth and breadth, practical application, learning ability, communication, and ownership.',
        '',
        '2. Baidu values deep framework understanding, delivery skills, Github experience, initiative, resilience, and communication.',
        '',
        '3. Tencent expects language foundations, extensions, language features, data structures, algorithms, and problem solving.',
        '',
        '4. ByteDance emphasizes Java basics, algorithms, data structures, code design, curiosity about new tech, and product awareness.',
        '',
        '5. Meituan values broad and deep technical ability, advanced bytecode topics, open-source participation, logic, and execution.'
      )
      $text = [string]::Join([Environment]::NewLine, $lines)
      $rect = New-Object System.Drawing.RectangleF(20, 20, [single]($w - 40), [single]($h - 40))
      $g.DrawString($text, $font, $brush, $rect)
      $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $g.Dispose()
      $font.Dispose()
      $bmp.Dispose()
    }
  } catch {
    Write-AppLog 'assistant_benchmark_image_failed' $_.Exception.Message
  }

  return $path
}

function Get-AssistantBenchmarkState {
  $path = Ensure-AssistantBenchmarkImage
  $exists = Test-Path -LiteralPath $path
  $sizeKb = 0
  $stamp = ''
  if ($exists) {
    $item = Get-Item -LiteralPath $path
    $sizeKb = [Math]::Round($item.Length / 1KB, 2)
    $stamp = [string]$item.LastWriteTimeUtc.Ticks
  }

  return [ordered]@{
    image_name = [IO.Path]::GetFileName($path)
    image_path = $path
    image_kb = $sizeKb
    image_url = if ($exists) { '/api/assistant/benchmark-image?ts=' + $stamp } else { '' }
    note = 'Fixed baseline image for measuring image-to-answer API latency only.'
  }
}

function Get-AssistantBenchmarkRunRoot {
  $dir = Join-Path ([IO.Path]::GetTempPath()) 'raccourci_assistant_benchmark_runs'
  Ensure-Dir $dir
  return $dir
}

function New-AssistantBenchmarkRunId {
  return ([guid]::NewGuid().ToString('N'))
}

function Get-AssistantBenchmarkRunStatePath {
  param([string]$RunId)
  return (Join-Path (Get-AssistantBenchmarkRunRoot) ($RunId + '.json'))
}

function Get-AssistantBenchmarkRunScriptPath {
  param([string]$RunId)
  return (Join-Path (Get-AssistantBenchmarkRunRoot) ($RunId + '.ps1'))
}

function Get-AssistantBenchmarkStatePreview {
  param([string]$Text)
  $preview = [string]$Text
  if ($preview.Length -gt 220) {
    $preview = $preview.Substring(0, 220) + '...'
  }
  return $preview
}

function Start-AssistantBenchmarkStreamRun {
  param($Payload = $null)

  $settings = Get-AssistantSettings
  $requestedModel = ([string](Get-Prop $Payload 'model' '')).Trim()
  if ($requestedModel -ne '') {
    $settings.model = Resolve-AssistantModel -Requested $requestedModel -Fallback ([string]$settings.model)
  }

  $imagePath = Ensure-AssistantBenchmarkImage
  $runId = New-AssistantBenchmarkRunId
  $statePath = Get-AssistantBenchmarkRunStatePath -RunId $runId
  $scriptPath = Get-AssistantBenchmarkRunScriptPath -RunId $runId
  $startedAt = Get-Date

  $endpoint = ([string](Get-Prop $settings 'api_endpoint' 'https://ark.cn-beijing.volces.com/api/v3/responses')).Trim()
  if ($endpoint -eq '') { $endpoint = 'https://ark.cn-beijing.volces.com/api/v3/responses' }
  $apiKey = Resolve-AssistantApiKey -Settings $settings
  $model = Resolve-AssistantModel -Requested ([string](Get-Prop $settings 'model' 'doubao-seed-2-0-lite-260215')) -Fallback 'doubao-seed-2-0-lite-260215'
  $prompt = ([string](Get-AssistantPromptByTemplate -Settings $settings)).Trim()
  if ($prompt -eq '') { $prompt = Get-AssistantDefaultPrompt }

  $initial = [ordered]@{
    ok = $true
    run_id = $runId
    status = 'running'
    benchmark = (Get-AssistantBenchmarkState)
    model = $model
    started_at = $startedAt.ToString('yyyy-MM-dd HH:mm:ss')
    prompt_preview = $prompt
    answer = ''
    answer_preview = ''
    reasoning = ''
    streamed = $true
    perf = [ordered]@{
      read_ms = 0
      base64_ms = 0
      json_ms = 0
      request_ms = 0
      parse_ms = 0
      total_ms = 0
      image_kb = 0
      payload_kb = 0
    }
  }
  [IO.File]::WriteAllText($statePath, (To-JsonNoBom $initial 20), [Text.Encoding]::UTF8)

  $script = @"
`$ErrorActionPreference = 'Stop'
`$statePath = '$([string]($statePath -replace "'", "''"))'
`$imagePath = '$([string]($imagePath -replace "'", "''"))'
`$endpoint = '$([string]($endpoint -replace "'", "''"))'
`$apiKey = '$([string]($apiKey -replace "'", "''"))'
`$model = '$([string]($model -replace "'", "''"))'
`$prompt = '$([string]($prompt -replace "'", "''"))'
`$startedAt = '$($startedAt.ToString('yyyy-MM-dd HH:mm:ss'))'

function Write-State {
  param(
    [string]`$Status,
    [string]`$Answer,
    [string]`$Reasoning,
    [bool]`$Streamed,
    [hashtable]`$Perf,
    [string]`$ErrorMessage = ''
  )

  `$preview = [string]`$Answer
  if (`$preview.Length -gt 220) {
    `$preview = `$preview.Substring(0, 220) + '...'
  }

  `$obj = [ordered]@{
    ok = ([string]::IsNullOrWhiteSpace(`$ErrorMessage))
    run_id = '$runId'
    status = `$Status
    benchmark = [ordered]@{
      image_name = '$( [IO.Path]::GetFileName($imagePath) )'
      image_path = '$([string]($imagePath -replace "'", "''"))'
      image_kb = [math]::Round(([IO.FileInfo]::new(`$imagePath)).Length / 1KB, 2)
      image_url = '/api/assistant/benchmark-image'
      note = 'Fixed baseline image for measuring image-to-answer API latency only.'
    }
    model = `$model
    started_at = `$startedAt
    prompt_preview = `$prompt
    answer = [string]`$Answer
    answer_preview = `$preview
    reasoning = [string]`$Reasoning
    streamed = `$Streamed
    perf = `$Perf
    error = `$ErrorMessage
  }
  [IO.File]::WriteAllText(`$statePath, (`$obj | ConvertTo-Json -Depth 20), [Text.Encoding]::UTF8)
}

function Get-DeltaText(`$evt) {
  `$text = ''
  if (`$null -ne `$evt.delta) {
    if (`$evt.delta -is [string]) { `$text = [string]`$evt.delta }
    elseif (`$null -ne `$evt.delta.text) { `$text = [string]`$evt.delta.text }
  }
  if ([string]::IsNullOrWhiteSpace(`$text) -and `$null -ne `$evt.part) {
    if (`$null -ne `$evt.part.text) { `$text = [string]`$evt.part.text }
    elseif (`$null -ne `$evt.part.summary) {
      if (`$evt.part.summary -is [System.Array]) {
        foreach (`$piece in `$evt.part.summary) {
          `$p = [string]`$piece.text
          if (`$p) { `$text += `$p + [Environment]::NewLine }
        }
      } else {
        `$text = [string]`$evt.part.summary
      }
    }
  }
  if ([string]::IsNullOrWhiteSpace(`$text) -and `$null -ne `$evt.text) { `$text = [string]`$evt.text }
  return `$text
}

function Get-EventKind(`$evt) {
  `$type = [string]`$evt.type
  if ([string]::IsNullOrWhiteSpace(`$type) -or (`$type -notmatch 'delta')) { return '' }
  if (`$type -match 'reasoning') { return 'reasoning' }
  if (`$type -match 'output_text') { return 'answer' }
  if (`$null -ne `$evt.part) {
    `$partType = [string]`$evt.part.type
    if (`$partType -match 'reasoning') { return 'reasoning' }
    if (`$partType -match 'output_text') { return 'answer' }
  }
  return ''
}

try {
  `$swTotal = [System.Diagnostics.Stopwatch]::StartNew()

  `$sw = [System.Diagnostics.Stopwatch]::StartNew()
  `$bytes = [IO.File]::ReadAllBytes(`$imagePath)
  `$sw.Stop()
  `$readMs = `$sw.ElapsedMilliseconds

  `$sw.Restart()
  `$b64 = [Convert]::ToBase64String(`$bytes)
  `$imgUrl = 'data:image/png;base64,' + `$b64
  `$sw.Stop()
  `$base64Ms = `$sw.ElapsedMilliseconds

  `$sw.Restart()
  `$payload = [ordered]@{
    model = `$model
    stream = `$true
    input = @(
      [ordered]@{
        role = 'user'
        content = @(
          [ordered]@{ type='input_image'; image_url=`$imgUrl },
          [ordered]@{ type='input_text'; text=`$prompt }
        )
      }
    )
  }
  `$json = `$payload | ConvertTo-Json -Depth 30
  `$sw.Stop()
  `$jsonMs = `$sw.ElapsedMilliseconds

  `$perf = [ordered]@{
    read_ms = `$readMs
    base64_ms = `$base64Ms
    json_ms = `$jsonMs
    request_ms = 0
    parse_ms = 0
    total_ms = 0
    image_kb = [math]::Round(`$bytes.Length / 1KB, 2)
    payload_kb = [math]::Round(`$json.Length / 1KB, 2)
  }

  Write-State -Status 'running' -Answer '' -Reasoning '' -Streamed `$true -Perf `$perf

  `$headers = @{ Accept = 'text/event-stream' }
  if (`$apiKey -ne '') { `$headers['Authorization'] = 'Bearer ' + `$apiKey }

  `$requestSw = [System.Diagnostics.Stopwatch]::StartNew()
  `$request = [System.Net.HttpWebRequest]::Create(`$endpoint)
  `$request.Method = 'POST'
  `$request.Accept = 'text/event-stream'
  `$request.ContentType = 'application/json'
  `$request.Timeout = 180000
  `$request.ReadWriteTimeout = 180000
  foreach (`$key in `$headers.Keys) {
    if (`$key -eq 'Accept') { continue }
    `$request.Headers[`$key] = `$headers[`$key]
  }
  `$bodyBytes = [Text.Encoding]::UTF8.GetBytes(`$json)
  `$request.ContentLength = `$bodyBytes.Length
  `$requestStream = `$request.GetRequestStream()
  `$requestStream.Write(`$bodyBytes, 0, `$bodyBytes.Length)
  `$requestStream.Close()

  `$response = `$request.GetResponse()
  `$reader = New-Object IO.StreamReader(`$response.GetResponseStream(), [Text.Encoding]::UTF8)
  `$eventLines = New-Object 'System.Collections.Generic.List[string]'
  `$answerSb = New-Object System.Text.StringBuilder
  `$reasoningSb = New-Object System.Text.StringBuilder

  while ((`$line = `$reader.ReadLine()) -ne `$null) {
    if ([string]::IsNullOrWhiteSpace(`$line)) {
      if (`$eventLines.Count -gt 0) {
        `$payloadText = [string]::Join([Environment]::NewLine, `$eventLines)
        `$eventLines.Clear()
        if (`$payloadText -eq '[DONE]') { break }
        try { `$evt = `$payloadText | ConvertFrom-Json } catch { continue }
        `$kind = Get-EventKind `$evt
        `$delta = Get-DeltaText `$evt
        if (`$kind -eq 'reasoning' -and `$delta) {
          [void]`$reasoningSb.Append(`$delta)
        } elseif (`$kind -eq 'answer' -and `$delta) {
          [void]`$answerSb.Append(`$delta)
        }
        `$perf.request_ms = `$requestSw.ElapsedMilliseconds
        `$perf.total_ms = `$swTotal.ElapsedMilliseconds
        Write-State -Status 'running' -Answer `$answerSb.ToString() -Reasoning `$reasoningSb.ToString() -Streamed `$true -Perf `$perf
      }
      continue
    }
    if (`$line.StartsWith('data:')) {
      `$eventLines.Add(`$line.Substring(5).TrimStart())
    }
  }

  `$reader.Close()
  `$response.Close()
  `$requestSw.Stop()

  `$parseSw = [System.Diagnostics.Stopwatch]::StartNew()
  `$answerText = `$answerSb.ToString()
  `$reasoningText = `$reasoningSb.ToString()
  `$parseSw.Stop()

  `$perf.request_ms = `$requestSw.ElapsedMilliseconds
  `$perf.parse_ms = `$parseSw.ElapsedMilliseconds
  `$perf.total_ms = `$swTotal.ElapsedMilliseconds
  Write-State -Status 'done' -Answer `$answerText -Reasoning `$reasoningText -Streamed `$true -Perf `$perf
} catch {
  `$perf = [ordered]@{
    read_ms = 0
    base64_ms = 0
    json_ms = 0
    request_ms = 0
    parse_ms = 0
    total_ms = 0
    image_kb = 0
    payload_kb = 0
  }
  Write-State -Status 'error' -Answer '' -Reasoning '' -Streamed `$true -Perf `$perf -ErrorMessage `$_.Exception.Message
}
"@

  [IO.File]::WriteAllText($scriptPath, $script, [Text.Encoding]::UTF8)
  Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) | Out-Null
  Write-AppLog 'assistant_benchmark_stream_start' ('run_id=' + $runId + ' model=' + $model)

  return [ordered]@{
    ok = $true
    run_id = $runId
    state = $initial
  }
}

function Get-AssistantBenchmarkStreamState {
  param([string]$RunId)

  $run = ([string]$RunId).Trim()
  if ([string]::IsNullOrWhiteSpace($run)) {
    return [ordered]@{ ok = $false; error = 'missing run_id' }
  }

  $statePath = Get-AssistantBenchmarkRunStatePath -RunId $run
  if (!(Test-Path -LiteralPath $statePath)) {
    return [ordered]@{ ok = $false; error = 'run not found'; run_id = $run }
  }

  try {
    $raw = [IO.File]::ReadAllText($statePath, [Text.Encoding]::UTF8)
    $obj = if ([string]::IsNullOrWhiteSpace($raw)) { $null } else { $raw | ConvertFrom-Json }
    if ($null -eq $obj) {
      return [ordered]@{ ok = $false; error = 'empty run state'; run_id = $run }
    }
    return $obj
  } catch {
    return [ordered]@{ ok = $false; error = $_.Exception.Message; run_id = $run }
  }
}

function Invoke-AssistantByImageWithPerf {
  param([string]$ImagePath, $Settings)
  try {
    if (!(Test-Path -LiteralPath $ImagePath)) {
      return [ordered]@{ ok = $false; error = 'image not found'; text = '' }
    }

    $endpoint = ([string](Get-Prop $Settings 'api_endpoint' 'https://ark.cn-beijing.volces.com/api/v3/responses')).Trim()
    if ($endpoint -eq '') { $endpoint = 'https://ark.cn-beijing.volces.com/api/v3/responses' }
    $apiKey = Resolve-AssistantApiKey -Settings $Settings
    $model = Resolve-AssistantModel -Requested ([string](Get-Prop $Settings 'model' 'doubao-seed-2-0-lite-260215')) -Fallback 'doubao-seed-2-0-lite-260215'
    $prompt = ([string](Get-AssistantPromptByTemplate -Settings $Settings)).Trim()
    if ($prompt -eq '') { $prompt = Get-AssistantDefaultPrompt }

    if (Test-AssistantMockMode -Settings $Settings) {
      $text = Get-AssistantMockAnswer -ImagePath $ImagePath -Settings $Settings
      return [ordered]@{
        ok = $true
        text = $text
        reasoning = ''
        streamed = $false
        error = ''
        perf = [ordered]@{
          read_ms = 0
          base64_ms = 0
          json_ms = 0
          request_ms = 0
          parse_ms = 0
          total_ms = 0
          image_kb = 0
          payload_kb = 0
        }
      }
    }

    $swTotal = [System.Diagnostics.Stopwatch]::StartNew()

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $bytes = [IO.File]::ReadAllBytes($ImagePath)
    $sw.Stop()
    $readMs = $sw.ElapsedMilliseconds

    $sw.Restart()
    $b64 = [Convert]::ToBase64String($bytes)
    $imgUrl = 'data:image/png;base64,' + $b64
    $sw.Stop()
    $base64Ms = $sw.ElapsedMilliseconds

    $headers = @{}
    if ($apiKey -ne '') {
      $headers['Authorization'] = 'Bearer ' + $apiKey
    }

    $isResponses = $endpoint.ToLowerInvariant().Contains('/responses')
    $sw.Restart()
    if ($isResponses) {
      $payload = [ordered]@{
        model = $model
        input = @(
          [ordered]@{
            role = 'user'
            content = @(
              [ordered]@{ type='input_image'; image_url=$imgUrl },
              [ordered]@{ type='input_text'; text=$prompt }
            )
          }
        )
      }
    } else {
      $payload = [ordered]@{
        model = $model
        messages = @(
          [ordered]@{
            role = 'user'
            content = @(
              [ordered]@{ type='text'; text=$prompt },
              [ordered]@{ type='image_url'; image_url=[ordered]@{ url=$imgUrl } }
            )
          }
        )
        temperature = 0.2
        max_tokens = 700
      }
    }
    $json = $payload | ConvertTo-Json -Depth 30
    $sw.Stop()
    $jsonMs = $sw.ElapsedMilliseconds

    $sw.Restart()
    $res = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -ContentType 'application/json' -Body $json
    $sw.Stop()
    $requestMs = $sw.ElapsedMilliseconds

    $sw.Restart()
    $text = Extract-AssistantText -Response $res -IsResponses $isResponses
    $reasoning = Extract-AssistantReasoning -Response $res -IsResponses $isResponses
    $sw.Stop()
    $parseMs = $sw.ElapsedMilliseconds

    $swTotal.Stop()
    return [ordered]@{
      ok = $true
      text = $text
      reasoning = $reasoning
      streamed = $false
      error = ''
      perf = [ordered]@{
        read_ms = $readMs
        base64_ms = $base64Ms
        json_ms = $jsonMs
        request_ms = $requestMs
        parse_ms = $parseMs
        total_ms = $swTotal.ElapsedMilliseconds
        image_kb = [Math]::Round($bytes.Length / 1KB, 2)
        payload_kb = [Math]::Round($json.Length / 1KB, 2)
      }
    }
  } catch {
    return [ordered]@{ ok=$false; text=''; reasoning=''; streamed=$false; error=$_.Exception.Message }
  }
}

function Invoke-AssistantBenchmarkRun {
  param($Payload = $null)

  $settings = Get-AssistantSettings
  $requestedModel = ([string](Get-Prop $Payload 'model' '')).Trim()
  if ($requestedModel -ne '') {
    $settings.model = Resolve-AssistantModel -Requested $requestedModel -Fallback ([string]$settings.model)
  }
  $imagePath = Ensure-AssistantBenchmarkImage
  $startedAt = Get-Date
  $result = Invoke-AssistantByImageWithPerf -ImagePath $imagePath -Settings $settings
  if (-not $result.ok) {
    Write-AppLog 'assistant_benchmark_failed' ('error=' + $result.error)
    return [ordered]@{
      ok = $false
      error = $result.error
      benchmark = (Get-AssistantBenchmarkState)
    }
  }

  $preview = [string]$result.text
  if ($preview.Length -gt 220) {
    $preview = $preview.Substring(0, 220) + '...'
  }

  $perf = $result.perf
  Write-AppLog 'assistant_benchmark_run' ('model=' + $settings.model + ' total_ms=' + $perf.total_ms + ' request_ms=' + $perf.request_ms)
  return [ordered]@{
    ok = $true
    benchmark = (Get-AssistantBenchmarkState)
    model = [string]$settings.model
    started_at = $startedAt.ToString('yyyy-MM-dd HH:mm:ss')
    prompt_preview = ([string](Get-AssistantPromptByTemplate -Settings $settings))
    perf = $perf
    answer = [string]$result.text
    reasoning = [string]$result.reasoning
    streamed = [bool](Get-Prop $result 'streamed' $false)
    answer_preview = $preview
  }
}

function Request-AssistantOverlayShow {
  try {
    [IO.File]::WriteAllText($ActionFile, 'assistant_overlay_open', [Text.Encoding]::UTF8)
    Write-AppLog 'assistant_overlay_open_req' 'source=web'
    return [ordered]@{ ok=$true }
  } catch {
    Write-AppLog 'assistant_overlay_open_failed' $_.Exception.Message
    return [ordered]@{ ok=$false; error=$_.Exception.Message }
  }
}

function Request-AssistantCaptureRun {
  try {
    [IO.File]::WriteAllText($ActionFile, 'assistant_capture_now', [Text.Encoding]::UTF8)
    Write-AppLog 'assistant_capture_req' 'source=web'
    return [ordered]@{ ok=$true }
  } catch {
    Write-AppLog 'assistant_capture_req_failed' $_.Exception.Message
    return [ordered]@{ ok=$false; error=$_.Exception.Message }
  }
}

function Open-AssistantCaptureFolder {
  try {
    Ensure-CaptureStore
    Start-Process $CaptureDir | Out-Null
    return [ordered]@{ ok = $true; path = $CaptureDir }
  } catch {
    return [ordered]@{ ok = $false; error = $_.Exception.Message }
  }
}

function Set-AssistantCaptureFolder {
  param([string]$SelectedPath)

  $target = ([string]$SelectedPath).Trim()
  if ($target -eq '') {
    return [ordered]@{ ok = $false; error = 'empty folder path' }
  }

  try {
    Ensure-Dir $target
    $ini = Read-Ini $DataFile
    if (!$ini.Contains('App')) { $ini['App'] = [ordered]@{} }
    $ini['App']['capture_dir'] = $target
    Write-Ini $ini
    $script:CaptureDir = $target
    Ensure-CaptureStore
    [IO.File]::WriteAllText($ActionFile, 'reload', [Text.Encoding]::UTF8)
    Write-AppLog 'assistant_capture_dir_change' ('path=' + $target)
    return [ordered]@{
      ok = $true
      path = $target
      settings = (Get-AssistantPublicSettings -Settings (Get-AssistantSettings))
    }
  } catch {
    Write-AppLog 'assistant_capture_dir_change_failed' $_.Exception.Message
    return [ordered]@{ ok = $false; error = $_.Exception.Message }
  }
}

function Select-AssistantCaptureFolder {
  try {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = '选择截图保存目录'
    $dialog.ShowNewFolderButton = $true
    if (![string]::IsNullOrWhiteSpace([string]$CaptureDir) -and (Test-Path $CaptureDir)) {
      $dialog.SelectedPath = [string]$CaptureDir
    }

    $result = $dialog.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
      return [ordered]@{ ok = $false; cancelled = $true; path = [string]$CaptureDir }
    }

    return Set-AssistantCaptureFolder -SelectedPath ([string]$dialog.SelectedPath)
  } catch {
    Write-AppLog 'assistant_capture_dir_pick_failed' $_.Exception.Message
    return [ordered]@{ ok = $false; error = $_.Exception.Message }
  }
}

function Run-AssistantCaptureAsk {
  $settings = Get-AssistantSettings
  if ([string](Get-Prop $settings 'enabled' '1') -eq '0') {
    return [ordered]@{ ok=$false; error='assistant disabled'; text=''; path='' }
  }

  $quota = Consume-AssistantRateLimit -Settings $settings
  if (-not $quota.ok) {
    Write-AppLog 'assistant_rate_limited' ('limit=' + $quota.limit + ' used=' + $quota.used)
    return [ordered]@{ ok=$false; error=$quota.error; text=''; path=''; quota=$quota }
  }

  $pathOut = Generate-CapturePath
  $ok = Capture-FullScreen -Path $pathOut
  if (!$ok) {
    Write-AppLog 'assistant_capture_failed' ('path=' + $pathOut)
    return [ordered]@{ ok=$false; error='capture failed'; text=''; path=$pathOut }
  }

  Publish-LatestCapture -SourcePath $pathOut
  Write-AppLog 'assistant_capture' ('path=' + $pathOut)

  $ans = Invoke-AssistantByImage -ImagePath $pathOut -Settings $settings
  if (-not $ans.ok) {
    Write-AppLog 'assistant_answer_failed' ('error=' + $ans.error)
    return [ordered]@{ ok=$false; error=$ans.error; text=''; path=$pathOut }
  }

  Write-AppLog 'assistant_answer_show' ('chars=' + $ans.text.Length)
  return [ordered]@{ ok=$true; text=$ans.text; error=''; path=$pathOut; quota=$quota }
}

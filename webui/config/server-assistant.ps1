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

  $limit = Clamp-AssistantRatePerHour (Get-Prop $Settings 'rate_limit_per_hour' 30)
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

    return [ordered]@{ ok=$true; text=$text; error='' }
  } catch {
    return [ordered]@{ ok=$false; text=''; error=$_.Exception.Message }
  }
}

function Get-AssistantState {
  $settings = Get-AssistantSettings
  return [ordered]@{
    settings = (Get-AssistantPublicSettings -Settings $settings)
    latest_capture = (Get-CaptureLatestPath)
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

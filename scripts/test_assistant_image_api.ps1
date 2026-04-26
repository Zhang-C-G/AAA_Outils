param(
  [Parameter(Mandatory = $true)]
  [string]$ImagePath,

  [int]$RepeatCount = 1,
  [int]$PauseMs = 0,
  [string]$ConfigPath = ".\\config.ini",
  [string]$PromptOverride = "",
  [string]$ModelOverride = ""
)

$ErrorActionPreference = "Stop"

function Read-IniSection {
  param(
    [string]$Path,
    [string]$SectionName
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Config not found: $Path"
  }

  $data = @{}
  $current = ""
  foreach ($raw in Get-Content -LiteralPath $Path -Encoding UTF8) {
    $line = [string]$raw
    if ($line -match '^\s*[;#]') { continue }
    if ($line -match '^\s*\[(.+)\]\s*$') {
      $current = $Matches[1].Trim()
      continue
    }
    if ($current -ne $SectionName) { continue }
    if ($line -match '^\s*([^=]+?)\s*=\s*(.*)\s*$') {
      $data[$Matches[1].Trim()] = $Matches[2]
    }
  }
  return $data
}

function Get-AssistantPrompt {
  param(
    [hashtable]$AssistantSection,
    [hashtable]$TemplateSection,
    [string]$PromptOverrideText
  )

  $override = ([string]$PromptOverrideText).Trim()
  if ($override -ne "") {
    return $override
  }

  $active = ([string]($AssistantSection["active_template"])).Trim()
  if ($active -ne "" -and $TemplateSection.ContainsKey($active)) {
    $candidate = ([string]$TemplateSection[$active]).Trim()
    if ($candidate -ne "") {
      return $candidate
    }
  }

  $direct = ([string]($AssistantSection["prompt"])).Trim()
  if ($direct -ne "") {
    return $direct
  }

  if ($TemplateSection.ContainsKey("default_template")) {
    $fallback = ([string]$TemplateSection["default_template"]).Trim()
    if ($fallback -ne "") {
      return $fallback
    }
  }

  return "Answer coding questions with complete runnable code and a brief explanation. Answer choice questions with a short summary and direct answer."
}

function Expand-AssistantText {
  param($Response)

  $text = ""
  if (-not [string]::IsNullOrWhiteSpace([string]$Response.output_text)) {
    $text = [string]$Response.output_text
  }

  if ([string]::IsNullOrWhiteSpace($text) -and $null -ne $Response.output) {
    foreach ($o in $Response.output) {
      if ($null -eq $o.content) { continue }
      foreach ($c in $o.content) {
        if ($c.type -eq "output_text" -and $c.text) {
          $text += [string]$c.text + [Environment]::NewLine
        }
      }
    }
  }

  return $text.Trim()
}

function Invoke-AssistantImageRun {
  param(
    [string]$Endpoint,
    [string]$ApiKey,
    [string]$Model,
    [string]$Prompt,
    [string]$Path
  )

  $headers = @{}
  if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
    $headers["Authorization"] = "Bearer $ApiKey"
  }

  $swTotal = [System.Diagnostics.Stopwatch]::StartNew()

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $sw.Stop()
  $readMs = $sw.ElapsedMilliseconds

  $sw.Restart()
  $b64 = [System.Convert]::ToBase64String($bytes)
  $imgUrl = "data:image/png;base64,$b64"
  $sw.Stop()
  $base64Ms = $sw.ElapsedMilliseconds

  $isResponses = $Endpoint.ToLower().Contains("/responses")

  $sw.Restart()
  if ($isResponses) {
    $body = [ordered]@{
      model = $Model
      input = @(
        [ordered]@{
          role = "user"
          content = @(
            [ordered]@{ type = "input_image"; image_url = $imgUrl },
            [ordered]@{ type = "input_text"; text = $Prompt }
          )
        }
      )
    }
  } else {
    $body = [ordered]@{
      model = $Model
      messages = @(
        [ordered]@{
          role = "user"
          content = @(
            [ordered]@{ type = "text"; text = $Prompt },
            [ordered]@{ type = "image_url"; image_url = [ordered]@{ url = $imgUrl } }
          )
        }
      )
      temperature = 0.2
      max_tokens = 700
    }
  }
  $json = $body | ConvertTo-Json -Depth 30
  $sw.Stop()
  $jsonMs = $sw.ElapsedMilliseconds

  $sw.Restart()
  $res = Invoke-RestMethod -Method Post -Uri $Endpoint -Headers $headers -ContentType "application/json" -Body $json
  $sw.Stop()
  $requestMs = $sw.ElapsedMilliseconds

  $sw.Restart()
  $answer = Expand-AssistantText -Response $res
  $sw.Stop()
  $parseMs = $sw.ElapsedMilliseconds

  $swTotal.Stop()

  return [pscustomobject]@{
    answer = $answer
    read_ms = $readMs
    base64_ms = $base64Ms
    json_ms = $jsonMs
    request_ms = $requestMs
    parse_ms = $parseMs
    total_ms = $swTotal.ElapsedMilliseconds
    image_bytes = $bytes.Length
    payload_chars = $json.Length
  }
}

$resolvedConfig = (Resolve-Path -LiteralPath $ConfigPath).Path
$resolvedImage = (Resolve-Path -LiteralPath $ImagePath).Path

$assistant = Read-IniSection -Path $resolvedConfig -SectionName "Assistant"
$templates = Read-IniSection -Path $resolvedConfig -SectionName "AssistantTemplates"

$endpoint = ([string]($assistant["api_endpoint"])).Trim()
$model = ([string]$ModelOverride).Trim()
if ($model -eq "") {
  $model = ([string]($assistant["model"])).Trim()
}

$protected = ([string]($assistant["api_key_protected"])).Trim()
if ([string]::IsNullOrWhiteSpace($endpoint)) {
  throw "Assistant endpoint missing in config."
}
if ([string]::IsNullOrWhiteSpace($model)) {
  throw "Assistant model missing in config."
}
if ([string]::IsNullOrWhiteSpace($protected)) {
  throw "Assistant api_key_protected missing in config."
}

$secure = ConvertTo-SecureString -String $protected
$apiKey = ([pscredential]::new("u", $secure)).GetNetworkCredential().Password
$prompt = Get-AssistantPrompt -AssistantSection $assistant -TemplateSection $templates -PromptOverrideText $PromptOverride

$runs = @()
for ($i = 1; $i -le [Math]::Max(1, $RepeatCount); $i++) {
  $result = Invoke-AssistantImageRun -Endpoint $endpoint -ApiKey $apiKey -Model $model -Prompt $prompt -Path $resolvedImage
  $preview = $result.answer
  if ($preview.Length -gt 120) {
    $preview = $preview.Substring(0, 120) + "..."
  }

  $runs += [pscustomobject]@{
    run = $i
    read_ms = $result.read_ms
    base64_ms = $result.base64_ms
    json_ms = $result.json_ms
    request_ms = $result.request_ms
    parse_ms = $result.parse_ms
    total_ms = $result.total_ms
    image_kb = [Math]::Round($result.image_bytes / 1KB, 2)
    payload_kb = [Math]::Round($result.payload_chars / 1KB, 2)
    answer_len = $result.answer.Length
    answer_preview = $preview
  }

  if ($i -lt $RepeatCount -and $PauseMs -gt 0) {
    Start-Sleep -Milliseconds $PauseMs
  }
}

$summary = [pscustomobject]@{
  endpoint = $endpoint
  model = $model
  image = $resolvedImage
  repeat_count = $runs.Count
  prompt_length = $prompt.Length
  avg_read_ms = [Math]::Round((($runs | Measure-Object -Property read_ms -Average).Average), 2)
  avg_base64_ms = [Math]::Round((($runs | Measure-Object -Property base64_ms -Average).Average), 2)
  avg_json_ms = [Math]::Round((($runs | Measure-Object -Property json_ms -Average).Average), 2)
  avg_request_ms = [Math]::Round((($runs | Measure-Object -Property request_ms -Average).Average), 2)
  avg_parse_ms = [Math]::Round((($runs | Measure-Object -Property parse_ms -Average).Average), 2)
  avg_total_ms = [Math]::Round((($runs | Measure-Object -Property total_ms -Average).Average), 2)
}

[pscustomobject]@{
  summary = $summary
  runs = $runs
} | ConvertTo-Json -Depth 6

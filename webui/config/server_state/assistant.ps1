function Get-AssistantDefaultPrompt {
  return '编程题：直接给编程完整答案，代码写在代码框中，并对核心部分做简短解释。选择题：先写15字以内题目总结，再直接给答案。'
}

function Get-AssistantModelCatalog {
  return @(
    [ordered]@{
      id = 'doubao-seed-2-0-lite-260215'
      name = 'Doubao Seed 2.0 Lite (Vision)'
      provider = 'volcengine-ark'
      vision = 1
      enabled = 1
    },
    [ordered]@{
      id = 'doubao-seed-2-0-pro-260215'
      name = 'Doubao Seed 2.0 Pro (Vision)'
      provider = 'volcengine-ark'
      vision = 1
      enabled = 1
    },
    [ordered]@{
      id = 'doubao-seed-2-0-mini-260215'
      name = 'Doubao Seed 2.0 Mini (ASR Fast)'
      note = '语音识别专用，速度特别快'
      provider = 'volcengine-ark'
      vision = 1
      enabled = 1
    }
  )
}
function Resolve-AssistantModel {
  param(
    [string]$Requested,
    [string]$Fallback = 'doubao-seed-2-0-lite-260215'
  )
  $catalog = Get-AssistantModelCatalog
  $candidate = ([string]$Requested).Trim()
  $fallback = ([string]$Fallback).Trim()
  if ($candidate -ne '') {
    foreach ($m in $catalog) {
      if ([string](Get-Prop $m 'id' '') -eq $candidate) {
        return $candidate
      }
    }
  }
  if ($fallback -ne '') {
    foreach ($m in $catalog) {
      if ([string](Get-Prop $m 'id' '') -eq $fallback) {
        return $fallback
      }
    }
  }
  return [string](Get-Prop $catalog[0] 'id' 'doubao-seed-2-0-lite-260215')
}

function Test-AssistantPromptBroken {
  param([string]$Text)
  $t = ([string]$Text).Trim()
  if ($t -eq '') { return $true }
  if ($t -match '^[\?]+$') { return $true }
  if ($t.Contains('???')) { return $true }
  return $false
}

function Get-AssistantDefaults {
  $prompt = Get-AssistantDefaultPrompt
  return [ordered]@{
    enabled = 1
    api_endpoint = 'https://ark.cn-beijing.volces.com/api/v3/responses'
    api_key = ''
    api_key_protected = ''
    has_api_key = 0
    model = (Resolve-AssistantModel -Requested 'doubao-seed-2-0-lite-260215')
    prompt = $prompt
    active_template = 'default_template'
    templates = @([ordered]@{ name = 'default_template'; prompt = $prompt })
    overlay_opacity = 75
    enhanced_capture_mode = 0
    disable_copy = 1
    voice_input_enabled = 0
    rate_limit_enabled = 1
    rate_limit_per_hour = 100
  }
}

function Clamp-AssistantOpacity {
  param($Opacity)
  $v = 100
  [int]::TryParse([string]$Opacity, [ref]$v) | Out-Null
  $allowed = @(20, 50, 75, 100)
  $best = $allowed[0]
  $bestDiff = [Math]::Abs($v - $best)
  foreach ($candidate in $allowed) {
    $diff = [Math]::Abs($v - $candidate)
    if ($diff -lt $bestDiff -or ($diff -eq $bestDiff -and $candidate -gt $best)) {
      $best = $candidate
      $bestDiff = $diff
    }
  }
  return $best
}

function Clamp-AssistantRatePerHour {
  param($Limit)
  $v = 100
  [int]::TryParse([string]$Limit, [ref]$v) | Out-Null
  return [Math]::Min(10000, [Math]::Max(1, $v))
}

function Protect-AssistantSecret {
  param([string]$Secret)
  $txt = ([string]$Secret).Trim()
  if ($txt -eq '') { return '' }
  try {
    $secure = ConvertTo-SecureString -String $txt -AsPlainText -Force
    return ($secure | ConvertFrom-SecureString)
  } catch {
    Write-AppLog 'assistant_secret_protect_failed' $_.Exception.Message
    return ''
  }
}

function Unprotect-AssistantSecret {
  param([string]$Encoded)
  $raw = ([string]$Encoded).Trim()
  if ($raw -eq '') { return '' }
  try {
    $secure = ConvertTo-SecureString -String $raw
    return ([pscredential]::new('u', $secure)).GetNetworkCredential().Password
  } catch {
    Write-AppLog 'assistant_secret_unprotect_failed' $_.Exception.Message
    return ''
  }
}

function Get-AssistantPromptByTemplate {
  param($Settings)
  $active = [string](Get-Prop $Settings 'active_template' '')
  $templates = Get-Prop $Settings 'templates' @()

  foreach ($t in $templates) {
    if ([string](Get-Prop $t 'name' '') -eq $active) {
      $prompt = ([string](Get-Prop $t 'prompt' '')).Trim()
      if ($prompt) { return $prompt }
    }
  }

  if ($templates.Count -gt 0) {
    $prompt = ([string](Get-Prop $templates[0] 'prompt' '')).Trim()
    if ($prompt) { return $prompt }
  }

  $fallback = ([string](Get-Prop $Settings 'prompt' '')).Trim()
  if ($fallback) { return $fallback }
  return Get-AssistantDefaultPrompt
}

function Ensure-AssistantTemplates {
  param($Settings)

  $templates = @()
  $seen = @{}

  foreach ($t in (Get-Prop $Settings 'templates' @())) {
    $name = ([string](Get-Prop $t 'name' '')).Trim()
    $prompt = ([string](Get-Prop $t 'prompt' '')).Trim()
    if ($name -eq '') { continue }
    if ($prompt -eq '' -or (Test-AssistantPromptBroken $prompt)) {
      $prompt = Get-AssistantDefaultPrompt
    }

    $k = $name.ToLowerInvariant()
    if ($seen.ContainsKey($k)) { continue }
    $seen[$k] = $true
    $templates += [ordered]@{ name = $name; prompt = $prompt }
  }

  if ($templates.Count -eq 0) {
    $templates += [ordered]@{ name = 'default_template'; prompt = (Get-AssistantDefaultPrompt) }
  }

  $active = ([string](Get-Prop $Settings 'active_template' '')).Trim()
  if ($active -eq '') { $active = [string]$templates[0].name }
  if (-not @($templates | Where-Object { [string]$_.name -eq $active }).Count) {
    $active = [string]$templates[0].name
  }

  $Settings['templates'] = $templates
  $Settings['active_template'] = $active
  $Settings['prompt'] = Get-AssistantPromptByTemplate -Settings $Settings
}

function Resolve-AssistantProtectedKey {
  param($PayloadAssistant, $Fallback)

  $fallbackProtected = [string](Get-Prop $Fallback 'api_key_protected' '')
  $incoming = Get-Prop $PayloadAssistant 'api_key' $null
  $keep = [string](Get-Prop $PayloadAssistant 'keep_api_key' '0') -eq '1'
  $clear = [string](Get-Prop $PayloadAssistant 'clear_api_key' '0') -eq '1'

  if ($clear) { return '' }

  if ($null -ne $incoming) {
    $keyText = ([string]$incoming).Trim()
    if ($keyText -ne '') {
      $protected = Protect-AssistantSecret -Secret $keyText
      if ($protected -ne '') { return $protected }
    }
    if ($keep -or $fallbackProtected -ne '') { return $fallbackProtected }
    return ''
  }

  if ($keep -or $fallbackProtected -ne '') { return $fallbackProtected }
  return ''
}

function Convert-ToAssistantSettings {
  param($PayloadAssistant, $Fallback)

  if ($null -eq $Fallback) { $Fallback = Get-AssistantDefaults }

  $settings = [ordered]@{}
  $settings.enabled = 1

  $endpoint = ([string](Get-Prop $PayloadAssistant 'api_endpoint' (Get-Prop $Fallback 'api_endpoint' 'https://ark.cn-beijing.volces.com/api/v3/responses'))).Trim()
  if ($endpoint -eq '') { $endpoint = 'https://ark.cn-beijing.volces.com/api/v3/responses' }
  $settings.api_endpoint = $endpoint

  $settings.api_key = ''
  $settings.api_key_protected = Resolve-AssistantProtectedKey -PayloadAssistant $PayloadAssistant -Fallback $Fallback
  $settings.has_api_key = if ($settings.api_key_protected -ne '') { 1 } else { 0 }

  $requestedModel = [string](Get-Prop $PayloadAssistant 'model' (Get-Prop $Fallback 'model' 'doubao-seed-2-0-lite-260215'))
  $settings.model = Resolve-AssistantModel -Requested $requestedModel -Fallback ([string](Get-Prop $Fallback 'model' 'doubao-seed-2-0-lite-260215'))

  $settings.active_template = ([string](Get-Prop $PayloadAssistant 'active_template' (Get-Prop $Fallback 'active_template' 'default_template'))).Trim()
  if ($settings.active_template -eq '') { $settings.active_template = 'default_template' }

  $settings.overlay_opacity = Clamp-AssistantOpacity (Get-Prop $PayloadAssistant 'overlay_opacity' (Get-Prop $Fallback 'overlay_opacity' 100))
  $settings.enhanced_capture_mode = if ([string](Get-Prop $PayloadAssistant 'enhanced_capture_mode' (Get-Prop $Fallback 'enhanced_capture_mode' 0)) -eq '0') { 0 } else { 1 }
  $settings.disable_copy = if ([string](Get-Prop $PayloadAssistant 'disable_copy' (Get-Prop $Fallback 'disable_copy' 1)) -eq '0') { 0 } else { 1 }
  $settings.voice_input_enabled = if ([string](Get-Prop $PayloadAssistant 'voice_input_enabled' (Get-Prop $Fallback 'voice_input_enabled' 0)) -eq '0') { 0 } else { 1 }
  $settings.rate_limit_enabled = if ([string](Get-Prop $PayloadAssistant 'rate_limit_enabled' (Get-Prop $Fallback 'rate_limit_enabled' 1)) -eq '0') { 0 } else { 1 }
  $settings.rate_limit_per_hour = Clamp-AssistantRatePerHour (Get-Prop $PayloadAssistant 'rate_limit_per_hour' (Get-Prop $Fallback 'rate_limit_per_hour' 100))

  $payloadTemplates = Get-Prop $PayloadAssistant 'templates' $null
  if ($null -eq $payloadTemplates) {
    $settings.templates = Get-Prop $Fallback 'templates' @()
  } else {
    $settings.templates = @()
    foreach ($t in $payloadTemplates) {
      $settings.templates += [ordered]@{
        name = [string](Get-Prop $t 'name' '')
        prompt = [string](Get-Prop $t 'prompt' '')
      }
    }
  }

  $settings.prompt = ([string](Get-Prop $PayloadAssistant 'prompt' (Get-Prop $Fallback 'prompt' (Get-AssistantDefaultPrompt)))).Trim()
  Ensure-AssistantTemplates $settings
  return $settings
}

function Resolve-AssistantApiKey {
  param($Settings)

  $protected = ([string](Get-Prop $Settings 'api_key_protected' '')).Trim()
  if ($protected -ne '') {
    $plain = Unprotect-AssistantSecret -Encoded $protected
    if ($plain -ne '') { return $plain }
  }

  $ini = Read-Ini $DataFile
  if ($ini.Contains('Assistant') -and $ini['Assistant'].Contains('api_key')) {
    return ([string]$ini['Assistant']['api_key']).Trim()
  }
  return ''
}

function Get-AssistantSettings {
  $ini = Read-Ini $DataFile
  $settings = Get-AssistantDefaults

  if ($ini.Contains('Assistant')) {
    $sec = $ini['Assistant']
    if ($sec.Contains('enabled')) { $settings.enabled = 1 }
    if ($sec.Contains('api_endpoint')) {
      $tmp = ([string]$sec['api_endpoint']).Trim()
      if ($tmp) { $settings.api_endpoint = $tmp }
    }
    if ($sec.Contains('api_key_protected')) {
      $settings.api_key_protected = ([string]$sec['api_key_protected']).Trim()
    }
    if ($sec.Contains('model')) {
      $tmp = ([string]$sec['model']).Trim()
      if ($tmp) { $settings.model = (Resolve-AssistantModel -Requested $tmp -Fallback ([string]$settings.model)) }
    }
    if ($sec.Contains('prompt')) {
      $tmp = ([string]$sec['prompt']).Trim()
      if ($tmp -and -not (Test-AssistantPromptBroken $tmp)) { $settings.prompt = $tmp }
    }
    if ($sec.Contains('active_template')) {
      $tmp = ([string]$sec['active_template']).Trim()
      if ($tmp) { $settings.active_template = $tmp }
    }
    if ($sec.Contains('overlay_opacity')) {
      $settings.overlay_opacity = Clamp-AssistantOpacity $sec['overlay_opacity']
    }
    if ($sec.Contains('enhanced_capture_mode')) {
      $settings.enhanced_capture_mode = if ([string]$sec['enhanced_capture_mode'] -eq '0') { 0 } else { 1 }
    }
    if ($sec.Contains('disable_copy')) {
      $settings.disable_copy = if ([string]$sec['disable_copy'] -eq '0') { 0 } else { 1 }
    }
    if ($sec.Contains('voice_input_enabled')) {
      $settings.voice_input_enabled = if ([string]$sec['voice_input_enabled'] -eq '0') { 0 } else { 1 }
    }
    if ($sec.Contains('rate_limit_enabled')) {
      $settings.rate_limit_enabled = if ([string]$sec['rate_limit_enabled'] -eq '0') { 0 } else { 1 }
    }
    if ($sec.Contains('rate_limit_per_hour')) {
      $settings.rate_limit_per_hour = Clamp-AssistantRatePerHour $sec['rate_limit_per_hour']
    }

    if (($settings.api_key_protected -eq '') -and $sec.Contains('api_key')) {
      $legacy = ([string]$sec['api_key']).Trim()
      if ($legacy -ne '') {
        $settings.api_key_protected = Protect-AssistantSecret -Secret $legacy
      }
    }
  }

  if ($ini.Contains('AssistantTemplates')) {
    $settings.templates = @()
    foreach ($k in $ini['AssistantTemplates'].Keys) {
      $name = ([string]$k).Trim()
      if ($name -eq '') { continue }
      $prompt = ([string]$ini['AssistantTemplates'][$k]).Trim()
      if (Test-AssistantPromptBroken $prompt) { $prompt = Get-AssistantDefaultPrompt }
      $settings.templates += [ordered]@{ name = $name; prompt = $prompt }
    }
  } elseif ([string]$settings.prompt -ne '') {
    $settings.templates = @([ordered]@{ name = $settings.active_template; prompt = $settings.prompt })
  }

  Ensure-AssistantTemplates $settings
  $settings.api_key = ''
  $settings.has_api_key = if ([string]$settings.api_key_protected -ne '') { 1 } else { 0 }
  $settings.model = Resolve-AssistantModel -Requested ([string](Get-Prop $settings 'model' '')) -Fallback 'doubao-seed-2-0-lite-260215'
  $settings.enhanced_capture_mode = if ([string](Get-Prop $settings 'enhanced_capture_mode' 0) -eq '0') { 0 } else { 1 }
  $settings.disable_copy = if ([string](Get-Prop $settings 'disable_copy' 1) -eq '0') { 0 } else { 1 }
  $settings.voice_input_enabled = if ([string](Get-Prop $settings 'voice_input_enabled' 0) -eq '0') { 0 } else { 1 }
  $settings.rate_limit_per_hour = Clamp-AssistantRatePerHour $settings.rate_limit_per_hour
  return $settings
}

function Get-AssistantPublicSettings {
  param($Settings = $null)
  if ($null -eq $Settings) { $Settings = Get-AssistantSettings }

  $public = [ordered]@{}
  foreach ($k in $Settings.Keys) {
    if ($k -eq 'api_key_protected') { continue }
    if ($k -eq 'api_key') {
      $public[$k] = ''
      continue
    }
    $public[$k] = $Settings[$k]
  }

  $public['api_key'] = ''
  $public['has_api_key'] = if ([string](Get-Prop $Settings 'api_key_protected' '') -ne '') { 1 } else { 0 }
  $public['model_options'] = Get-AssistantModelCatalog
  $public['capture_dir'] = [string]$CaptureDir
  $public['latest_capture'] = (Get-CaptureLatestPath)
  return $public
}

function Save-AssistantSettings {
  param($Payload)

  $ini = Read-Ini $DataFile
  if (!$ini.Contains('Assistant')) { $ini['Assistant'] = [ordered]@{} }
  if (!$ini.Contains('AssistantTemplates')) { $ini['AssistantTemplates'] = [ordered]@{} }

  $settings = Convert-ToAssistantSettings -PayloadAssistant $Payload -Fallback (Get-AssistantSettings)

  $ini['Assistant']['enabled'] = [string]$settings.enabled
  $ini['Assistant']['api_endpoint'] = [string]$settings.api_endpoint
  $ini['Assistant']['api_key'] = ''
  $ini['Assistant']['api_key_protected'] = [string]$settings.api_key_protected
  $ini['Assistant']['model'] = [string]$settings.model
  $ini['Assistant']['active_template'] = [string]$settings.active_template
  $ini['Assistant']['prompt'] = ([string](Get-AssistantPromptByTemplate -Settings $settings) -replace '[\r\n]+', ' ')
  $ini['Assistant']['overlay_opacity'] = [string]$settings.overlay_opacity
  $ini['Assistant']['enhanced_capture_mode'] = [string]$settings.enhanced_capture_mode
  $ini['Assistant']['disable_copy'] = [string]$settings.disable_copy
  $ini['Assistant']['voice_input_enabled'] = [string]$settings.voice_input_enabled
  $ini['Assistant']['rate_limit_enabled'] = [string]$settings.rate_limit_enabled
  $ini['Assistant']['rate_limit_per_hour'] = [string]$settings.rate_limit_per_hour

  $ini['AssistantTemplates'] = [ordered]@{}
  foreach ($t in $settings.templates) {
    $name = ([string](Get-Prop $t 'name' '')).Trim()
    if ($name -eq '') { continue }
    $prompt = ([string](Get-Prop $t 'prompt' '')).Trim()
    if ($prompt -eq '' -or (Test-AssistantPromptBroken $prompt)) { $prompt = Get-AssistantDefaultPrompt }
    $ini['AssistantTemplates'][$name] = ($prompt -replace '[\r\n]+', ' ')
  }

  Write-Ini $ini
  [IO.File]::WriteAllText($ActionFile, 'reload', [Text.Encoding]::UTF8)
  Write-AppLog 'assistant_settings_save' ('model=' + $settings.model + ' template=' + $settings.active_template)

  return (Get-AssistantPublicSettings -Settings $settings)
}


function Get-BuiltinCategoryDefaults {
  return [ordered]@{
    fields = 'Fields'
    prompts = 'Prompts'
    quick_fields = 'Quick Fields'
  }
}

function Normalize-BuiltinCategoryName {
  param([string]$Id, [string]$Name)

  $defaults = Get-BuiltinCategoryDefaults
  $id = ([string]$Id).Trim().ToLowerInvariant()
  $name = ([string]$Name).Trim()

  if ($id -in @('fields', 'prompts', 'quick_fields')) {
    if ($name -eq '' -or $name -match '^\?+$' -or $name -ieq $id) {
      return [string]$defaults[$id]
    }
  }

  if ($name -eq '' -or $name -match '^\?+$') {
    if ($id -in @('fields', 'prompts', 'quick_fields')) {
      return [string]$defaults[$id]
    }
    return $Id
  }

  return $name
}

function Ensure-BuiltinCategories {
  param($Cats)

  if ($null -eq $Cats) { $Cats = @() }
  $defaults = Get-BuiltinCategoryDefaults

  $byId = [ordered]@{}
  foreach ($cat in $Cats) {
    $id = ([string](Get-Prop $cat 'id' '')).Trim()
    if ([string]::IsNullOrWhiteSpace($id)) { continue }
    if ($byId.Contains($id)) { continue }

    $name = Normalize-BuiltinCategoryName -Id $id -Name ([string](Get-Prop $cat 'name' $id))
    $builtin = if ($id -in @('fields', 'prompts', 'quick_fields')) { 1 } else { 0 }
    $byId[$id] = [ordered]@{ id = $id; name = $name; builtin = $builtin }
  }

  foreach ($id in @('fields', 'prompts', 'quick_fields')) {
    if (-not $byId.Contains($id)) {
      $byId[$id] = [ordered]@{ id = $id; name = [string]$defaults[$id]; builtin = 1 }
    }
  }

  $ordered = @()
  foreach ($id in @('fields', 'prompts', 'quick_fields')) {
    $ordered += [ordered]@{
      id = $id
      name = Normalize-BuiltinCategoryName -Id $id -Name ([string](Get-Prop $byId[$id] 'name' [string]$defaults[$id]))
      builtin = 1
    }
  }

  foreach ($id in $byId.Keys) {
    if ($id -in @('fields', 'prompts', 'quick_fields')) { continue }
    $ordered += [ordered]@{
      id = $id
      name = [string](Get-Prop $byId[$id] 'name' $id)
      builtin = 0
    }
  }

  return $ordered
}

function Get-CategoriesFromIni {
  param($Ini)

  $cats = @()
  if ($null -eq $Ini) { return $cats }
  if (-not $Ini.Contains('Categories')) { return $cats }

  foreach ($id in $Ini['Categories'].Keys) {
    $idText = ([string]$id).Trim()
    if ([string]::IsNullOrWhiteSpace($idText)) { continue }

    $name = Normalize-BuiltinCategoryName -Id $idText -Name ([string]$Ini['Categories'][$id])
    $builtin = if ($idText -in @('fields', 'prompts', 'quick_fields')) { 1 } else { 0 }
    $cats += [ordered]@{ id = $idText; name = $name; builtin = $builtin }
  }
  return $cats
}

function Try-GetDataRows {
  param($PayloadData, [string]$CategoryId)

  if ($null -eq $PayloadData) {
    return [ordered]@{ found = $false; rows = @() }
  }

  if ($PayloadData -is [System.Collections.IDictionary]) {
    if ($PayloadData.Contains($CategoryId)) {
      return [ordered]@{ found = $true; rows = $PayloadData[$CategoryId] }
    }
    foreach ($k in $PayloadData.Keys) {
      if ([string]::Equals([string]$k, $CategoryId, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [ordered]@{ found = $true; rows = $PayloadData[$k] }
      }
    }
    return [ordered]@{ found = $false; rows = @() }
  }

  $p = $PayloadData.PSObject.Properties[$CategoryId]
  if ($null -ne $p) {
    return [ordered]@{ found = $true; rows = $p.Value }
  }

  foreach ($prop in $PayloadData.PSObject.Properties) {
    if ([string]::Equals([string]$prop.Name, $CategoryId, [System.StringComparison]::OrdinalIgnoreCase)) {
      return [ordered]@{ found = $true; rows = $prop.Value }
    }
  }
  return [ordered]@{ found = $false; rows = @() }
}

function Get-ConfigAutoBackupPath {
  if ([string]::IsNullOrWhiteSpace([string]$DataFile)) {
    return 'config.autobak.ini'
  }
  return ($DataFile + '.autobak')
}

function Test-ConfigIntegrity {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
    return $false
  }

  $ini = Read-Ini $Path
  if (-not $ini.Contains('Categories')) { return $false }
  if (-not $ini.Contains('Hotkeys')) { return $false }

  $requiredCats = @('fields', 'prompts', 'quick_fields')
  foreach ($id in $requiredCats) {
    if (-not $ini['Categories'].Contains($id)) { return $false }
  }

  foreach ($def in (Get-HotkeyDefs)) {
    $id = [string](Get-Prop $def 'id' '')
    if ($id -eq '') { continue }
    if (-not $ini['Hotkeys'].Contains($id)) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$ini['Hotkeys'][$id])) { return $false }
  }

  return $true
}

function Get-ConfigState {
  $ini = Read-Ini $DataFile

  $cats = @()
  if ($ini.Contains('Categories')) {
    foreach ($id in $ini['Categories'].Keys) {
      $idText = ([string]$id).Trim()
      if ([string]::IsNullOrWhiteSpace($idText)) { continue }

      $name = Normalize-BuiltinCategoryName -Id $idText -Name ([string]$ini['Categories'][$id])
      $builtin = if ($idText -in @('fields', 'prompts', 'quick_fields')) { 1 } else { 0 }
      $cats += [ordered]@{ id = $idText; name = $name; builtin = $builtin }
    }
  }
  $cats = Ensure-BuiltinCategories -Cats $cats

  $usageIni = Read-Ini $UsageFile
  $data = [ordered]@{}
  foreach ($cat in $cats) {
    $id = [string](Get-Prop $cat 'id' '')
    if ($id -eq '') { continue }

    $section = Get-CategorySection $id
    $usageSection = 'Usage_' + $id
    $usage = if ($usageIni.Contains($usageSection)) { $usageIni[$usageSection] } else { [ordered]@{} }

    $rows = @()
    if ($ini.Contains($section)) {
      foreach ($k in $ini[$section].Keys) {
        $u = 0
        if ($usage.Contains($k)) { [int]::TryParse([string]$usage[$k], [ref]$u) | Out-Null }
        $rows += [ordered]@{
          key = [string]$k
          value = [string]$ini[$section][$k]
          usage = $u
        }
      }
    }

    $data[$id] = $rows
  }

  $hotkeys = [ordered]@{}
  if ($ini.Contains('Hotkeys')) {
    foreach ($k in $ini['Hotkeys'].Keys) {
      $hotkeys[[string]$k] = [string]$ini['Hotkeys'][$k]
    }
  }
  foreach ($def in (Get-HotkeyDefs)) {
    $defId = [string](Get-Prop $def 'id' '')
    $defVal = [string](Get-Prop $def 'default' '')
    if ($defId -eq '') { continue }
    if (-not $hotkeys.Contains($defId) -or [string]::IsNullOrWhiteSpace([string]$hotkeys[$defId])) {
      $hotkeys[$defId] = $defVal
    }
  }

  $behavior = [ordered]@{
    auto_refresh_enabled = 1
    refresh_every_uses = 3
    refresh_every_minutes = 5
  }
  if ($ini.Contains('Behavior')) {
    foreach ($k in $ini['Behavior'].Keys) {
      $behavior[[string]$k] = [string]$ini['Behavior'][$k]
    }
  }
  $uses = 3
  $mins = 5
  [int]::TryParse([string]$behavior['refresh_every_uses'], [ref]$uses) | Out-Null
  [int]::TryParse([string]$behavior['refresh_every_minutes'], [ref]$mins) | Out-Null
  $behavior['auto_refresh_enabled'] = if ([string]$behavior['auto_refresh_enabled'] -eq '0') { 0 } else { 1 }
  $behavior['refresh_every_uses'] = [Math]::Max(1, $uses)
  $behavior['refresh_every_minutes'] = [Math]::Max(1, $mins)

  $app = [ordered]@{
    active_mode = 'shortcuts'
    mode_order = (Get-DefaultModeOrder)
    shortcuts_selected_category = 'fields'
  }
  if ($ini.Contains('App') -and $ini['App'].Contains('active_mode')) {
    $app['active_mode'] = Normalize-Mode([string]$ini['App']['active_mode'])
  }
  if ($ini.Contains('App') -and $ini['App'].Contains('mode_order')) {
    $app['mode_order'] = Normalize-ModeOrder([string]$ini['App']['mode_order'])
  }
  if ($ini.Contains('App') -and $ini['App'].Contains('shortcuts_selected_category')) {
    $selectedCategory = ([string]$ini['App']['shortcuts_selected_category']).Trim()
    if (-not [string]::IsNullOrWhiteSpace($selectedCategory)) {
      $app['shortcuts_selected_category'] = $selectedCategory
    }
  }

  return [ordered]@{
    categories = $cats
    data = $data
    hotkeys = $hotkeys
    hotkey_defs = (Get-HotkeyDefs)
    behavior = $behavior
    app = $app
    assistant = (Get-AssistantPublicSettings -Settings (Get-AssistantSettings))
  }
}

function Get-AppShellState {
  $ini = Read-Ini $DataFile

  $hotkeys = [ordered]@{}
  if ($ini.Contains('Hotkeys')) {
    foreach ($k in $ini['Hotkeys'].Keys) {
      $hotkeys[[string]$k] = [string]$ini['Hotkeys'][$k]
    }
  }
  foreach ($def in (Get-HotkeyDefs)) {
    $defId = [string](Get-Prop $def 'id' '')
    $defVal = [string](Get-Prop $def 'default' '')
    if ($defId -eq '') { continue }
    if (-not $hotkeys.Contains($defId) -or [string]::IsNullOrWhiteSpace([string]$hotkeys[$defId])) {
      $hotkeys[$defId] = $defVal
    }
  }

  $app = [ordered]@{
    active_mode = 'shortcuts'
    mode_order = (Get-DefaultModeOrder)
    shortcuts_selected_category = 'fields'
  }
  if ($ini.Contains('App') -and $ini['App'].Contains('active_mode')) {
    $app['active_mode'] = Normalize-Mode([string]$ini['App']['active_mode'])
  }
  if ($ini.Contains('App') -and $ini['App'].Contains('mode_order')) {
    $app['mode_order'] = Normalize-ModeOrder([string]$ini['App']['mode_order'])
  }
  if ($ini.Contains('App') -and $ini['App'].Contains('shortcuts_selected_category')) {
    $selectedCategory = ([string]$ini['App']['shortcuts_selected_category']).Trim()
    if (-not [string]::IsNullOrWhiteSpace($selectedCategory)) {
      $app['shortcuts_selected_category'] = $selectedCategory
    }
  }

  $result = [ordered]@{
    hotkeys = $hotkeys
    hotkey_defs = (Get-HotkeyDefs)
    app = $app
  }

  if ($app['active_mode'] -in @('shortcuts', 'hotkeys')) {
    $result['shortcuts_prefetch'] = Get-ConfigState
  }

  return $result
}

function Write-ConfigState {
  param($Payload)

  $currentIni = Read-Ini $DataFile
  $lines = New-Object System.Collections.Generic.List[string]

  $lines.Add('[Categories]')
  $catsIncoming = @()
  foreach ($cat in (Get-Prop $Payload 'categories' @())) {
    $id = ([string](Get-Prop $cat 'id' '')).Trim()
    if ($id -eq '') { continue }

    $name = ([string](Get-Prop $cat 'name' $id)).Trim()
    if ($name -eq '') { $name = $id }
    $catsIncoming += [ordered]@{ id = $id; name = $name }
  }

  $catsCurrent = Ensure-BuiltinCategories -Cats (Get-CategoriesFromIni -Ini $currentIni)
  $cats = if ($catsIncoming.Count -gt 0) {
    Ensure-BuiltinCategories -Cats $catsIncoming
  } else {
    $catsCurrent
  }
  foreach ($cat in $cats) {
    $lines.Add("$($cat.id)=$($cat.name)")
  }

  $payloadData = Get-Prop $Payload 'data' $null
  foreach ($cat in $cats) {
    $id = [string]$cat.id
    $section = Get-CategorySection $id
    $lines.Add('')
    $lines.Add("[$section]")

    $lookup = Try-GetDataRows -PayloadData $payloadData -CategoryId $id
    if ($lookup.found) {
      $incomingLines = New-Object System.Collections.Generic.List[string]
      foreach ($row in $lookup.rows) {
        $key = ([string](Get-Prop $row 'key' '')).Trim()
        if ($key -eq '') { continue }

        $value = ([string](Get-Prop $row 'value' '')) -replace '[\r\n]+', ' '
        $incomingLines.Add("$key=$value")
      }

      foreach ($line in $incomingLines) {
        $lines.Add($line)
      }
    } elseif ($currentIni.Contains($section)) {
      foreach ($k in $currentIni[$section].Keys) {
        $lines.Add(([string]$k + '=' + [string]$currentIni[$section][$k]))
      }
    }
  }

  $lines.Add('')
  $lines.Add('[Hotkeys]')
  $currentHotkeys = [ordered]@{}
  if ($currentIni.Contains('Hotkeys')) {
    foreach ($k in $currentIni['Hotkeys'].Keys) {
      $currentHotkeys[[string]$k] = [string]$currentIni['Hotkeys'][$k]
    }
  }

  $hotkeys = [ordered]@{}
  $payloadHotkeys = Get-Prop $Payload 'hotkeys' $null
  if ($null -ne $payloadHotkeys) {
    foreach ($p in $payloadHotkeys.PSObject.Properties) {
      $k = [string]$p.Name
      $v = ([string]$p.Value).Trim()
      if ($k -and $v) { $hotkeys[$k] = $v }
    }
  } else {
    foreach ($k in $currentHotkeys.Keys) {
      $hotkeys[$k] = $currentHotkeys[$k]
    }
  }
  foreach ($def in (Get-HotkeyDefs)) {
    $id = [string](Get-Prop $def 'id' '')
    $default = [string](Get-Prop $def 'default' '')
    if ($id -eq '') { continue }
    if (-not $hotkeys.Contains($id) -or [string]::IsNullOrWhiteSpace([string]$hotkeys[$id])) {
      if ($currentHotkeys.Contains($id) -and -not [string]::IsNullOrWhiteSpace([string]$currentHotkeys[$id])) {
        $hotkeys[$id] = [string]$currentHotkeys[$id]
      } else {
        $hotkeys[$id] = $default
      }
    }
    $lines.Add($id + '=' + $hotkeys[$id])
  }

  $lines.Add('')
  $lines.Add('[App]')
  $currentMode = 'shortcuts'
  $currentOrder = Get-DefaultModeOrder
  $currentSelectedCategory = 'fields'
  if ($currentIni.Contains('App') -and $currentIni['App'].Contains('active_mode')) {
    $currentMode = Normalize-Mode([string]$currentIni['App']['active_mode'])
  }
  if ($currentIni.Contains('App') -and $currentIni['App'].Contains('mode_order')) {
    $currentOrder = Normalize-ModeOrder([string]$currentIni['App']['mode_order'])
  }
  if ($currentIni.Contains('App') -and $currentIni['App'].Contains('shortcuts_selected_category')) {
    $selectedCategory = ([string]$currentIni['App']['shortcuts_selected_category']).Trim()
    if (-not [string]::IsNullOrWhiteSpace($selectedCategory)) {
      $currentSelectedCategory = $selectedCategory
    }
  }
  $appPayload = Get-Prop $Payload 'app' $null
  $mode = Normalize-Mode([string](Get-Prop $appPayload 'active_mode' $currentMode))
  $modeOrder = Normalize-ModeOrder((Get-Prop $appPayload 'mode_order' $currentOrder))
  $selectedCategory = ([string](Get-Prop $appPayload 'shortcuts_selected_category' $currentSelectedCategory)).Trim()
  if ([string]::IsNullOrWhiteSpace($selectedCategory)) {
    $selectedCategory = $currentSelectedCategory
  }
  $lines.Add('active_mode=' + $mode)
  $lines.Add('mode_order=' + [string]::Join(',', $modeOrder))
  $lines.Add('shortcuts_selected_category=' + $selectedCategory)

  $capture = Get-CaptureSettings
  $lines.Add('')
  $lines.Add('[Capture]')
  $lines.Add('upload_endpoint=' + $capture.upload_endpoint)
  $lines.Add('open_qr_after_upload=' + $capture.open_qr_after_upload)
  $lines.Add('bridge_port=' + $capture.bridge_port)

  $assistantPayload = Get-Prop $Payload 'assistant' $null
  $assistantFallback = Get-AssistantSettings
  $assistant = if ($null -eq $assistantPayload) {
    $assistantFallback
  } else {
    Convert-ToAssistantSettings -PayloadAssistant $assistantPayload -Fallback $assistantFallback
  }
  $assistantEnabled = if ([string]$assistant.enabled -eq '0') { '0' } else { '1' }

  $lines.Add('')
  $lines.Add('[Assistant]')
  $lines.Add('enabled=' + $assistantEnabled)
  $lines.Add('api_endpoint=' + $assistant.api_endpoint)
  $lines.Add('api_key=')
  $lines.Add('api_key_protected=' + $assistant.api_key_protected)
  $lines.Add('model=' + $assistant.model)
  $lines.Add('active_template=' + $assistant.active_template)
  $lines.Add('prompt=' + ((Get-AssistantPromptByTemplate -Settings $assistant) -replace '[\r\n]+', ' '))
  $lines.Add('overlay_opacity=' + $assistant.overlay_opacity)
  $lines.Add('enhanced_capture_mode=' + $assistant.enhanced_capture_mode)
  $lines.Add('disable_copy=' + $assistant.disable_copy)
  $lines.Add('rate_limit_enabled=' + $assistant.rate_limit_enabled)
  $lines.Add('rate_limit_per_hour=' + $assistant.rate_limit_per_hour)

  $lines.Add('')
  $lines.Add('[AssistantTemplates]')
  foreach ($t in $assistant.templates) {
    $name = ([string](Get-Prop $t 'name' '')).Trim()
    if ($name -eq '') { continue }
    $prompt = ([string](Get-Prop $t 'prompt' '')).Trim()
    if ($prompt -eq '') { $prompt = Get-AssistantDefaultPrompt }
    $lines.Add($name + '=' + ($prompt -replace '[\r\n]+', ' '))
  }

  $currentBehavior = [ordered]@{
    auto_refresh_enabled = '1'
    refresh_every_uses = '3'
    refresh_every_minutes = '5'
  }
  if ($currentIni.Contains('Behavior')) {
    foreach ($k in $currentIni['Behavior'].Keys) {
      $currentBehavior[[string]$k] = [string]$currentIni['Behavior'][$k]
    }
  }

  $behavior = Get-Prop $Payload 'behavior' $null
  $enabled = if ([string](Get-Prop $behavior 'auto_refresh_enabled' $currentBehavior['auto_refresh_enabled']) -eq '0') { '0' } else { '1' }
  $uses = 3
  $mins = 5
  [int]::TryParse([string](Get-Prop $behavior 'refresh_every_uses' $currentBehavior['refresh_every_uses']), [ref]$uses) | Out-Null
  [int]::TryParse([string](Get-Prop $behavior 'refresh_every_minutes' $currentBehavior['refresh_every_minutes']), [ref]$mins) | Out-Null
  $uses = [Math]::Max(1, $uses)
  $mins = [Math]::Max(1, $mins)

  $lines.Add('')
  $lines.Add('[Behavior]')
  $lines.Add('auto_refresh_enabled=' + $enabled)
  $lines.Add('refresh_every_uses=' + $uses)
  $lines.Add('refresh_every_minutes=' + $mins)

  $content = [string]::Join([Environment]::NewLine, $lines)
  $tmpFile = $DataFile + '.tmp'
  $backupFile = Get-ConfigAutoBackupPath

  try {
    if (Test-Path $DataFile) {
      Copy-Item -LiteralPath $DataFile -Destination $backupFile -Force
    }

    [IO.File]::WriteAllText($tmpFile, $content, [Text.Encoding]::UTF8)
    if (-not (Test-ConfigIntegrity -Path $tmpFile)) {
      throw 'saved config failed integrity check'
    }

    Move-Item -LiteralPath $tmpFile -Destination $DataFile -Force
    $postIni = Read-Ini $DataFile
    $summary = New-Object System.Collections.Generic.List[string]
    foreach ($cat in $cats) {
      $cid = [string](Get-Prop $cat 'id' '')
      if ($cid -eq '') { continue }
      $sec = Get-CategorySection $cid
      $count = 0
      if ($postIni.Contains($sec)) { $count = @($postIni[$sec].Keys).Count }
      $summary.Add(($cid + '=' + $count))
    }
    Write-AppLog 'config_save_result' ('rows(' + [string]::Join(',', $summary) + ')')
    [IO.File]::WriteAllText($ActionFile, 'reload', [Text.Encoding]::UTF8)
    Write-AppLog 'config_save' 'source=web'
  }
  catch {
    try {
      if (Test-Path $tmpFile) { Remove-Item -LiteralPath $tmpFile -Force }
    } catch {}

    try {
      if (Test-Path $backupFile) {
        Copy-Item -LiteralPath $backupFile -Destination $DataFile -Force
        Write-AppLog 'config_save_rollback' 'restored_from_autobak'
      }
    } catch {}

    throw
  }
}

function Set-AppMode {
  param([string]$Mode)

  $ini = Read-Ini $DataFile
  if (-not $ini.Contains('App')) {
    $ini['App'] = [ordered]@{}
  }
  $ini['App']['active_mode'] = Normalize-Mode $Mode
  if (-not $ini['App'].Contains('mode_order')) {
    $ini['App']['mode_order'] = [string]::Join(',', (Get-DefaultModeOrder))
  } else {
    $ini['App']['mode_order'] = [string]::Join(',', (Normalize-ModeOrder([string]$ini['App']['mode_order'])))
  }
  Write-Ini $ini

  [IO.File]::WriteAllText($ActionFile, 'reload', [Text.Encoding]::UTF8)
  Write-AppLog 'mode_switch' ('active_mode=' + $ini['App']['active_mode'])
}

function Set-AppModeOrder {
  param($ModeOrder)

  $ini = Read-Ini $DataFile
  if (-not $ini.Contains('App')) {
    $ini['App'] = [ordered]@{}
  }
  if (-not $ini['App'].Contains('active_mode')) {
    $ini['App']['active_mode'] = 'shortcuts'
  }
  $normalized = Normalize-ModeOrder $ModeOrder
  $ini['App']['active_mode'] = Normalize-Mode ([string]$ini['App']['active_mode'])
  $ini['App']['mode_order'] = [string]::Join(',', $normalized)
  Write-Ini $ini

  [IO.File]::WriteAllText($ActionFile, 'reload', [Text.Encoding]::UTF8)
  Write-AppLog 'mode_order_save' ('mode_order=' + $ini['App']['mode_order'])
}

function Set-AppShortcutsSelectedCategory {
  param([string]$CategoryId)

  $selectedCategory = ([string]$CategoryId).Trim()
  if ([string]::IsNullOrWhiteSpace($selectedCategory)) {
    $selectedCategory = 'fields'
  }

  $ini = Read-Ini $DataFile
  if (-not $ini.Contains('App')) {
    $ini['App'] = [ordered]@{}
  }
  if (-not $ini['App'].Contains('active_mode')) {
    $ini['App']['active_mode'] = 'shortcuts'
  } else {
    $ini['App']['active_mode'] = Normalize-Mode ([string]$ini['App']['active_mode'])
  }
  if (-not $ini['App'].Contains('mode_order')) {
    $ini['App']['mode_order'] = [string]::Join(',', (Get-DefaultModeOrder))
  } else {
    $ini['App']['mode_order'] = [string]::Join(',', (Normalize-ModeOrder([string]$ini['App']['mode_order'])))
  }
  $ini['App']['shortcuts_selected_category'] = $selectedCategory
  Write-Ini $ini

  Write-AppLog 'shortcuts_category_save' ('shortcuts_selected_category=' + $selectedCategory)
}



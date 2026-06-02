function Get-ShortcutsBackupDir {
  if ([string]::IsNullOrWhiteSpace([string]$DataFile)) {
    return (Join-Path (Get-Location) 'backups\shortcuts')
  }
  return (Join-Path (Split-Path -Parent $DataFile) 'backups\shortcuts')
}

function New-ShortcutsFieldsExportObject {
  param(
    $Categories,
    $Data,
    [string]$Source = 'disk'
  )

  $exportCategories = @()
  foreach ($cat in @($Categories)) {
    $id = ([string](Get-Prop $cat 'id' '')).Trim()
    if ($id -eq '') { continue }
    $exportCategories += [ordered]@{
      id = $id
      name = ([string](Get-Prop $cat 'name' $id)).Trim()
      builtin = if ([string](Get-Prop $cat 'builtin' 0) -eq '1') { 1 } else { 0 }
    }
  }

  $exportData = [ordered]@{}
  foreach ($cat in $exportCategories) {
    $id = [string]$cat.id
    $rows = @()
    $lookup = Try-GetDataRows -PayloadData $Data -CategoryId $id
    if ($lookup.found) {
      foreach ($row in @($lookup.rows)) {
        $key = ([string](Get-Prop $row 'key' '')).Trim()
        if ($key -eq '') { continue }
        $usage = 0
        [int]::TryParse([string](Get-Prop $row 'usage' 0), [ref]$usage) | Out-Null
        $rows += [ordered]@{
          key = $key
          value = [string](Get-Prop $row 'value' '')
          usage = [Math]::Max(0, $usage)
        }
      }
    }
    $exportData[$id] = $rows
  }

  return [ordered]@{
    format = 'raccourci-shortcuts-fields-v1'
    exported_at = (Get-Date).ToString('o')
    source = $Source
    categories = $exportCategories
    data = $exportData
  }
}

function Get-ShortcutsFieldsExportObject {
  param(
    $Categories = $null,
    $Data = $null,
    [string]$Source = 'disk'
  )

  if ($null -eq $Categories -or $null -eq $Data) {
    $state = Get-ConfigState
    $Categories = $state.categories
    $Data = $state.data
  }

  return New-ShortcutsFieldsExportObject -Categories $Categories -Data $Data -Source $Source
}

function ConvertTo-ShortcutsFieldsSavePayload {
  param($ExportObject)

  $current = Get-ConfigState
  $categories = @()
  foreach ($cat in @(Get-Prop $ExportObject 'categories' @())) {
    $id = ([string](Get-Prop $cat 'id' '')).Trim()
    if ($id -eq '') { continue }
    $categories += [ordered]@{
      id = $id
      name = ([string](Get-Prop $cat 'name' $id)).Trim()
      builtin = if ([string](Get-Prop $cat 'builtin' 0) -eq '1') { 1 } else { 0 }
    }
  }
  if ($categories.Count -le 0) {
    throw 'backup has no categories'
  }

  $categories = Ensure-BuiltinCategories -Cats $categories
  $data = [ordered]@{}
  $exportData = Get-Prop $ExportObject 'data' $null
  foreach ($cat in $categories) {
    $id = [string]$cat.id
    $lookup = Try-GetDataRows -PayloadData $exportData -CategoryId $id
    $data[$id] = if ($lookup.found) { @($lookup.rows) } else { @() }
  }

  return [ordered]@{
    categories = $categories
    data = $data
    hotkeys = $current.hotkeys
    behavior = $current.behavior
    app = $current.app
    assistant = (Get-AssistantSettings)
  }
}

function Save-ShortcutsFieldsBackup {
  param(
    [string]$Reason = 'manual',
    $Categories = $null,
    $Data = $null
  )

  $dir = Get-ShortcutsBackupDir
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }

  $export = Get-ShortcutsFieldsExportObject -Categories $Categories -Data $Data -Source $Reason
  $json = $export | ConvertTo-Json -Depth 30
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $fileName = "shortcuts_fields_$stamp.json"
  $path = Join-Path $dir $fileName
  [IO.File]::WriteAllText($path, $json, [Text.Encoding]::UTF8)
  [IO.File]::WriteAllText((Join-Path $dir 'latest.json'), $json, [Text.Encoding]::UTF8)

  $maxKeep = 40
  $files = @(Get-ChildItem -LiteralPath $dir -Filter 'shortcuts_fields_*.json' | Sort-Object LastWriteTime -Descending)
  if ($files.Count -gt $maxKeep) {
    foreach ($old in $files[$maxKeep..($files.Count - 1)]) {
      try { Remove-Item -LiteralPath $old.FullName -Force } catch {}
    }
  }

  Write-AppLog 'shortcuts_fields_backup' ("reason=$Reason file=$fileName")
  return [ordered]@{
    ok = $true
    file = $fileName
    path = $path
    exported_at = $export.exported_at
  }
}

function Get-ShortcutsFieldsBackupList {
  $dir = Get-ShortcutsBackupDir
  if (-not (Test-Path $dir)) {
    return @()
  }

  $items = @()
  foreach ($file in @(Get-ChildItem -LiteralPath $dir -Filter 'shortcuts_fields_*.json' | Sort-Object LastWriteTime -Descending)) {
    $items += [ordered]@{
      file = $file.Name
      size = $file.Length
      updated_at = $file.LastWriteTime.ToString('o')
    }
  }
  return $items
}

function Restore-ShortcutsFieldsBackup {
  param([string]$FileName = 'latest.json')

  $dir = Get-ShortcutsBackupDir
  $safeName = [IO.Path]::GetFileName(([string]$FileName).Trim())
  if ([string]::IsNullOrWhiteSpace($safeName)) {
    $safeName = 'latest.json'
  }
  $path = Join-Path $dir $safeName
  if (-not (Test-Path -LiteralPath $path)) {
    throw "backup not found: $safeName"
  }

  $backup = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
  $payload = ConvertTo-ShortcutsFieldsSavePayload -ExportObject $backup
  Write-ConfigState $payload
  Write-AppLog 'shortcuts_fields_restore' ("file=$safeName")
  return [ordered]@{ ok = $true; file = $safeName }
}

function ConvertTo-ShortcutsFieldsIniText {
  param($ExportObject)

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('[Categories]')
  foreach ($cat in @(Get-Prop $ExportObject 'categories' @())) {
    $id = ([string](Get-Prop $cat 'id' '')).Trim()
    if ($id -eq '') { continue }
    $name = ([string](Get-Prop $cat 'name' $id)).Trim()
    if ($name -eq '') { $name = $id }
    $lines.Add("$id=$name")
  }

  $exportData = Get-Prop $ExportObject 'data' $null
  foreach ($cat in @(Get-Prop $ExportObject 'categories' @())) {
    $id = ([string](Get-Prop $cat 'id' '')).Trim()
    if ($id -eq '') { continue }
    $section = Get-CategorySection $id
    $lines.Add('')
    $lines.Add("[$section]")
    $lookup = Try-GetDataRows -PayloadData $exportData -CategoryId $id
    if ($lookup.found) {
      foreach ($row in @($lookup.rows)) {
        $key = ([string](Get-Prop $row 'key' '')).Trim()
        if ($key -eq '') { continue }
        $value = ([string](Get-Prop $row 'value' '')) -replace '[\r\n]+', ' '
        $lines.Add("$key=$value")
      }
    }
  }

  return [string]::Join([Environment]::NewLine, $lines)
}

function Get-NotePath {
  param([string]$Id)
  return (Join-Path $NotesDir ($Id + '.md'))
}

function Get-NotesOrderPath {
  return (Join-Path $NotesDir '_order.json')
}

function Get-NotesDisplayPath {
  param([string]$Id)
  return (Join-Path $NotesDisplayDir ($Id + '.md'))
}

function Parse-NoteFile {
  param([string]$Path)
  $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
  $lines = $text -split "`r?`n"
  $title = 'Untitled'; $start = 0
  if ($lines.Length -gt 0 -and $lines[0].StartsWith('Title: ')) {
    $title = $lines[0].Substring(7).Trim(); $start = 3
  }
  if ($title -eq '') { $title = 'Untitled' }
  if ($start -ge $lines.Length) { return [ordered]@{ title=$title; content='' } }
  $content = [string]::Join("`n", $lines[$start..($lines.Length - 1)])
  return [ordered]@{ title=$title; content=$content }
}

function Get-NotesMeta {
  Ensure-Dir $NotesDir
  $list = @()
  foreach ($f in Get-ChildItem -Path $NotesDir -Filter *.md -File -ErrorAction SilentlyContinue) {
    $id = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    $parsed = Parse-NoteFile $f.FullName
    $list += [ordered]@{ id=$id; title=$parsed.title; updated=$f.LastWriteTime.ToString('yyyyMMddHHmmss') }
  }
  return (Apply-NotesOrder -Notes @($list | Sort-Object updated -Descending))
}

function Read-NotesOrder {
  Ensure-Dir $NotesDir
  $path = Get-NotesOrderPath
  if (!(Test-Path -LiteralPath $path)) { return @() }
  try {
    $raw = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $parsed = $raw | ConvertFrom-Json
    if ($parsed -is [System.Array]) {
      return @($parsed | ForEach-Object { [string]$_ })
    }
    return @()
  } catch {
    return @()
  }
}

function Save-NotesOrder {
  param($Order)
  Ensure-Dir $NotesDir
  $normalized = @()
  foreach ($id in @($Order)) {
    $text = ([string]$id).Trim()
    if ($text -eq '') { continue }
    if ($normalized -contains $text) { continue }
    $normalized += $text
  }
  $json = To-JsonNoBom $normalized
  [IO.File]::WriteAllText((Get-NotesOrderPath), $json, [Text.Encoding]::UTF8)
}

function Apply-NotesOrder {
  param($Notes)

  $list = @($Notes)
  if ($list.Count -le 1) { return $list }

  $order = Read-NotesOrder
  if (@($order).Count -eq 0) { return $list }

  $byId = @{}
  foreach ($note in $list) {
    $id = [string](Get-Prop $note 'id' '')
    if ($id -eq '') { continue }
    $byId[$id] = $note
  }

  $ordered = @()
  foreach ($id in $order) {
    if ($byId.ContainsKey($id)) {
      $ordered += $byId[$id]
      $byId.Remove($id)
    }
  }

  foreach ($note in $list) {
    $id = [string](Get-Prop $note 'id' '')
    if ($id -eq '') { continue }
    if ($byId.ContainsKey($id)) {
      $ordered += $byId[$id]
      $byId.Remove($id)
    }
  }

  return @($ordered)
}

function Reorder-Notes {
  param($Order)

  $existing = @(Get-NotesMeta)
  $validIds = @{}
  foreach ($note in $existing) {
    $id = [string](Get-Prop $note 'id' '')
    if ($id -ne '') {
      $validIds[$id] = $true
    }
  }

  $normalized = @()
  foreach ($id in @($Order)) {
    $text = ([string]$id).Trim()
    if ($text -eq '') { continue }
    if (-not $validIds.ContainsKey($text)) { continue }
    if ($normalized -contains $text) { continue }
    $normalized += $text
  }

  foreach ($note in $existing) {
    $id = [string](Get-Prop $note 'id' '')
    if ($id -eq '') { continue }
    if ($normalized -contains $id) { continue }
    $normalized += $id
  }

  Save-NotesOrder -Order $normalized
  Write-AppLog 'notes_reorder' ('count=' + $normalized.Count)
  return Get-NotesMeta
}

function Get-NotesDisplayMeta {
  Ensure-Dir $NotesDisplayDir
  $list = @()
  foreach ($f in Get-ChildItem -Path $NotesDisplayDir -Filter *.md -File -ErrorAction SilentlyContinue) {
    $id = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    $parsed = Parse-NoteFile $f.FullName
    $list += [ordered]@{ id=$id; title=$parsed.title; updated=$f.LastWriteTime.ToString('yyyyMMddHHmmss') }
  }
  return @($list | Sort-Object updated -Descending)
}

function Save-NoteContent {
  param([string]$Id, [string]$Title, [string]$Content)
  Ensure-Dir $NotesDir
  $title = $Title.Trim(); if ($title -eq '') { $title = 'Untitled' }
  $text = "Title: $title`nUpdated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`n`n$Content"
  [IO.File]::WriteAllText((Get-NotePath $Id), $text, [Text.Encoding]::UTF8)
}

function Save-NotesDisplayContent {
  param([string]$Id, [string]$Title, [string]$Content)
  Ensure-Dir $NotesDisplayDir
  $title = $Title.Trim(); if ($title -eq '') { $title = 'Untitled' }
  $text = "Title: $title`nUpdated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`n`n$Content"
  [IO.File]::WriteAllText((Get-NotesDisplayPath $Id), $text, [Text.Encoding]::UTF8)
}

function Create-Note {
  param([string]$Title = 'New Note')
  Ensure-Dir $NotesDir
  $id = (Get-Date).ToString('yyyyMMddHHmmss'); $seq = 1
  while (Test-Path (Get-NotePath $id)) { $seq += 1; $id = (Get-Date).ToString('yyyyMMddHHmmss') + '_' + $seq }
  Save-NoteContent -Id $id -Title $Title -Content ''
  Write-AppLog 'notes_new' ('id=' + $id)
  return $id
}

function Create-NotesDisplayNote {
  param([string]$Title = 'New Note')
  Ensure-Dir $NotesDisplayDir
  $id = (Get-Date).ToString('yyyyMMddHHmmss'); $seq = 1
  while (Test-Path (Get-NotesDisplayPath $id)) { $seq += 1; $id = (Get-Date).ToString('yyyyMMddHHmmss') + '_' + $seq }
  Save-NotesDisplayContent -Id $id -Title $Title -Content ''
  Write-AppLog 'notes_display_new' ('id=' + $id)
  return $id
}

function Load-Note {
  param([string]$Id)
  $path = Get-NotePath $Id
  if (!(Test-Path $path)) { return [ordered]@{ id=$Id; title='Untitled'; content='' } }
  $parsed = Parse-NoteFile $path
  return [ordered]@{ id=$Id; title=$parsed.title; content=$parsed.content }
}

function Load-NotesDisplayNote {
  param([string]$Id)
  $path = Get-NotesDisplayPath $Id
  if (!(Test-Path $path)) { return [ordered]@{ id=$Id; title='Untitled'; content='' } }
  $parsed = Parse-NoteFile $path
  return [ordered]@{ id=$Id; title=$parsed.title; content=$parsed.content }
}

function Delete-Note {
  param([string]$Id)
  $path = Get-NotePath $Id
  if (Test-Path $path) { Remove-Item -LiteralPath $path -Force }
  Write-AppLog 'notes_delete' ('id=' + $Id)
}

function Delete-NotesDisplayNote {
  param([string]$Id)
  $path = Get-NotesDisplayPath $Id
  if (Test-Path $path) { Remove-Item -LiteralPath $path -Force }
  Write-AppLog 'notes_display_delete' ('id=' + $Id)
}

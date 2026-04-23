function Get-NotePath {
  param([string]$Id)
  return (Join-Path $NotesDir ($Id + '.md'))
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
  return @($list | Sort-Object updated -Descending)
}

function Save-NoteContent {
  param([string]$Id, [string]$Title, [string]$Content)
  Ensure-Dir $NotesDir
  $title = $Title.Trim(); if ($title -eq '') { $title = 'Untitled' }
  $text = "Title: $title`nUpdated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`n`n$Content"
  [IO.File]::WriteAllText((Get-NotePath $Id), $text, [Text.Encoding]::UTF8)
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

function Load-Note {
  param([string]$Id)
  $path = Get-NotePath $Id
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

function Get-NotePath {
  param([string]$Id)
  return (Join-Path $NotesDir ($Id + '.md'))
}

function Get-NoteAssetDir {
  param([string]$Id)
  return (Join-Path (Join-Path $Root 'note-assets') $Id)
}

function Get-NotesOrderPath {
  return (Join-Path $NotesDir '_order.json')
}

function Get-NotesDisplayPath {
  param([string]$Id)
  return (Join-Path $NotesDisplayDir ($Id + '.md'))
}

function Get-NotesDisplayOrderPath {
  return (Join-Path $NotesDisplayDir '_order.json')
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
  return (Apply-NotesDisplayOrder -Notes @($list | Sort-Object updated -Descending))
}

function Read-NotesDisplayOrder {
  Ensure-Dir $NotesDisplayDir
  $path = Get-NotesDisplayOrderPath
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

function Save-NotesDisplayOrder {
  param($Order)
  Ensure-Dir $NotesDisplayDir
  $normalized = @()
  foreach ($id in @($Order)) {
    $text = ([string]$id).Trim()
    if ($text -eq '') { continue }
    if ($normalized -contains $text) { continue }
    $normalized += $text
  }
  $json = To-JsonNoBom $normalized
  [IO.File]::WriteAllText((Get-NotesDisplayOrderPath), $json, [Text.Encoding]::UTF8)
}

function Apply-NotesDisplayOrder {
  param($Notes)

  $list = @($Notes)
  if ($list.Count -le 1) { return $list }

  $order = Read-NotesDisplayOrder
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

function Reorder-NotesDisplay {
  param($Order)

  $existing = @(Get-NotesDisplayMeta)
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

  Save-NotesDisplayOrder -Order $normalized
  Write-AppLog 'notes_display_reorder' ('count=' + $normalized.Count)
  return Get-NotesDisplayMeta
}

function Save-NoteContent {
  param(
    [string]$Id,
    [string]$Title,
    [string]$Content
  )
  Ensure-Dir $NotesDir
  $normalizedContent = Convert-EmbeddedNoteImagesToFiles -Id $Id -Content $Content
  $title = $Title.Trim(); if ($title -eq '') { $title = 'Untitled' }
  $text = "Title: $title`nUpdated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`n`n$normalizedContent"
  $path = Get-NotePath $Id
  [IO.File]::WriteAllText($path, $text, [Text.Encoding]::UTF8)
  return [ordered]@{
    content = $normalizedContent
  }
}

function Get-ImageExtensionFromMimeType {
  param([string]$MimeType)
  $safeMimeType = [string]$MimeType
  switch ($safeMimeType.ToLowerInvariant()) {
    'image/png' { return 'png' }
    'image/jpeg' { return 'jpg' }
    'image/jpg' { return 'jpg' }
    'image/gif' { return 'gif' }
    'image/webp' { return 'webp' }
    'image/svg+xml' { return 'svg' }
    default { return 'bin' }
  }
}

function Convert-EmbeddedNoteImagesToFiles {
  param(
    [string]$Id,
    [string]$Content
  )

  $text = [string]$Content
  if ([string]::IsNullOrWhiteSpace($text)) {
    return $text
  }

  $assetDir = Get-NoteAssetDir $Id
  Ensure-Dir (Join-Path $Root 'note-assets')
  Ensure-Dir $assetDir

  $pattern = '!\[(?<alt>[^\]]*)\]\((?<src>data:image/(?<subtype>[a-z0-9.+-]+);base64,(?<data>[A-Za-z0-9+/=]+))\)'
  $rewritten = [System.Text.RegularExpressions.Regex]::Replace(
    $text,
    $pattern,
    {
      param($match)
      $alt = [string]$match.Groups['alt'].Value
      $mimeType = 'image/' + [string]$match.Groups['subtype'].Value
      $base64 = [string]$match.Groups['data'].Value
      if ([string]::IsNullOrWhiteSpace($base64)) {
        return $match.Value
      }

      try {
        $bytes = [Convert]::FromBase64String($base64)
      } catch {
        return $match.Value
      }

      $sha = [System.Security.Cryptography.SHA256]::Create()
      try {
        $hashBytes = $sha.ComputeHash($bytes)
      } finally {
        $sha.Dispose()
      }
      $hash = ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
      $ext = Get-ImageExtensionFromMimeType $mimeType
      $fileName = "$hash.$ext"
      $filePath = Join-Path $assetDir $fileName
      if (!(Test-Path -LiteralPath $filePath)) {
        [IO.File]::WriteAllBytes($filePath, $bytes)
      }

      $relativePath = "/note-assets/$Id/$fileName"
      return "![${alt}]($relativePath)"
    },
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
  )

  return $rewritten
}

function Resolve-PdfBrowserPath {
  $candidates = @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
  )

  foreach ($path in $candidates) {
    if (Test-Path -LiteralPath $path) {
      return $path
    }
  }

  throw '当前机器未找到可用的 Chrome / Edge，无法生成 PDF'
}

function Convert-NoteHtmlToPdfBytes {
  param(
    [string]$Html,
    [string]$Title = 'Untitled'
  )

  $browserPath = Resolve-PdfBrowserPath
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('notes_pdf_' + [guid]::NewGuid().ToString('N'))
  $htmlPath = Join-Path $tempRoot 'note.html'
  $pdfPath = Join-Path $tempRoot 'note.pdf'

  New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
  try {
    [IO.File]::WriteAllText($htmlPath, $Html, [Text.Encoding]::UTF8)
    $htmlUri = [System.Uri]::new($htmlPath).AbsoluteUri

    $argSets = @(
      @('--headless=new', '--disable-gpu', '--no-pdf-header-footer', ('--print-to-pdf=' + $pdfPath), $htmlUri),
      @('--headless', '--disable-gpu', '--no-pdf-header-footer', ('--print-to-pdf=' + $pdfPath), $htmlUri)
    )

    $generated = $false
    foreach ($args in $argSets) {
      if (Test-Path -LiteralPath $pdfPath) {
        Remove-Item -LiteralPath $pdfPath -Force -ErrorAction SilentlyContinue
      }
      $proc = Start-Process -FilePath $browserPath -ArgumentList $args -WindowStyle Hidden -PassThru -Wait
      if ($proc.ExitCode -eq 0 -and (Test-Path -LiteralPath $pdfPath)) {
        $generated = $true
        break
      }
    }

    if (-not $generated) {
      throw '浏览器 PDF 生成失败'
    }

    Write-AppLog 'notes_export_pdf' ('title=' + $Title)
    return [IO.File]::ReadAllBytes($pdfPath)
  }
  finally {
    if (Test-Path -LiteralPath $tempRoot) {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
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

function Get-NoteFileUpdatedAt {
  param([string]$Path)
  if (!(Test-Path -LiteralPath $Path)) { return 0 }
  try {
    return [DateTimeOffset](Get-Item -LiteralPath $Path).LastWriteTimeUtc
  } catch {
    return 0
  }
}

function Load-Note {
  param([string]$Id)
  $path = Get-NotePath $Id
  if (!(Test-Path $path)) { return [ordered]@{ id=$Id; title='Untitled'; content=''; updatedAt=0 } }
  $parsed = Parse-NoteFile $path
  return [ordered]@{
    id=$Id
    title=$parsed.title
    content=$parsed.content
    updatedAt=(Get-NoteFileUpdatedAt $path).ToUnixTimeMilliseconds()
  }
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

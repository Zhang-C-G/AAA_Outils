function Get-CaptureSettings {
  $ini = Read-Ini $DataFile
  $settings = [ordered]@{ upload_endpoint='https://0x0.st'; open_qr_after_upload=1; bridge_port=8787 }
  if ($ini.Contains('Capture')) {
    if ($ini['Capture'].Contains('upload_endpoint')) {
      $tmp = ([string]$ini['Capture']['upload_endpoint']).Trim()
      if ($tmp) { $settings.upload_endpoint = $tmp }
    }
    if ($ini['Capture'].Contains('open_qr_after_upload')) {
      $settings.open_qr_after_upload = if ([string]$ini['Capture']['open_qr_after_upload'] -eq '0') { 0 } else { 1 }
    }
    if ($ini['Capture'].Contains('bridge_port')) {
      $port = 8787
      [int]::TryParse([string]$ini['Capture']['bridge_port'], [ref]$port) | Out-Null
      $settings.bridge_port = [Math]::Min(65535, [Math]::Max(1024, $port))
    }
  }
  return $settings
}

function Save-CaptureSettings {
  param($Payload)
  $ini = Read-Ini $DataFile
  if (!$ini.Contains('Capture')) { $ini['Capture'] = [ordered]@{} }

  $endpoint = ([string](Get-Prop $Payload 'upload_endpoint' 'https://0x0.st')).Trim()
  if ($endpoint -eq '') { $endpoint = 'https://0x0.st' }
  $openQr = if ([string](Get-Prop $Payload 'open_qr_after_upload' '1') -eq '0') { 0 } else { 1 }
  $port = 8787
  [int]::TryParse([string](Get-Prop $Payload 'bridge_port' '8787'), [ref]$port) | Out-Null
  $port = [Math]::Min(65535, [Math]::Max(1024, $port))

  $ini['Capture']['upload_endpoint'] = $endpoint
  $ini['Capture']['open_qr_after_upload'] = [string]$openQr
  $ini['Capture']['bridge_port'] = [string]$port
  Write-Ini $ini
  [IO.File]::WriteAllText($ActionFile, 'reload', [Text.Encoding]::UTF8)
  Write-AppLog 'capture_settings_save' ('endpoint=' + $endpoint)
  return Get-CaptureSettings
}

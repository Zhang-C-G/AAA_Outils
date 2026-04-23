$startupDir = [Environment]::GetFolderPath('Startup')
$linkNames = @('Raccourci_Hotkey.lnk', 'GlobalQuickFill_MVP.lnk')
$removed = $false

foreach ($name in $linkNames) {
  $linkPath = Join-Path $startupDir $name
  if (Test-Path $linkPath) {
    Remove-Item -LiteralPath $linkPath -Force
    Write-Host "已移除开机启动：$linkPath"
    $removed = $true
  }
}

if (-not $removed) {
  Write-Host "未找到可移除的开机启动快捷方式。"
}

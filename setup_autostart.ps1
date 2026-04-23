$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = Join-Path $scriptDir 'main.ahk'
$startupDir = [Environment]::GetFolderPath('Startup')
$linkPath = Join-Path $startupDir 'ZCG-Raccourci Control.lnk'

if (!(Test-Path $mainScript)) {
  throw "未找到 main.ahk: $mainScript"
}

$ahkCandidates = @(
  "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
  "$env:ProgramFiles\AutoHotkey\AutoHotkey64.exe",
  "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe",
  "$env:ProgramFiles(x86)\AutoHotkey\AutoHotkey.exe"
)

$ahkExe = $ahkCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ahkExe) {
  $cmd = Get-Command AutoHotkey64.exe, AutoHotkey.exe -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cmd) { $ahkExe = $cmd.Source }
}
if (-not $ahkExe) {
  throw '未找到 AutoHotkey v2 可执行文件，请先安装 AutoHotkey v2。'
}

$wsh = New-Object -ComObject WScript.Shell
$link = $wsh.CreateShortcut($linkPath)
$link.TargetPath = $ahkExe
$link.Arguments = '"' + $mainScript + '"'
$link.WorkingDirectory = $scriptDir
$link.Description = 'ZCG-Raccourci Control Autostart'
$link.WindowStyle = 1
$link.Save()

Write-Host "已创建开机启动快捷方式：$linkPath"
Write-Host "目标：$ahkExe"
Write-Host "脚本：$mainScript"

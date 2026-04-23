param(
  [int]$DurationSec = 6,
  [int]$Fps = 10,
  [string]$OutputDir = ".\captures\probe",
  [string]$WindowTitleHint = " - Assistant"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing | Out-Null

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32Probe {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
  }
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

function Get-OverlayWindow {
  param([string]$TitleHint)
  $wins = Get-Process | ForEach-Object {
    try {
      if ($_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -like "*$TitleHint*") { $_ }
    } catch {}
  }
  if (!$wins) { return $null }
  return $wins | Select-Object -First 1
}

function Get-RectFromHandle {
  param([IntPtr]$Handle)
  $r = New-Object Win32Probe+RECT
  if (-not [Win32Probe]::GetWindowRect($Handle, [ref]$r)) {
    throw "GetWindowRect failed for handle=$Handle"
  }
  return @{
    Left = $r.Left
    Top = $r.Top
    Width = [Math]::Max(1, $r.Right - $r.Left)
    Height = [Math]::Max(1, $r.Bottom - $r.Top)
  }
}

function Compare-Images {
  param(
    [string]$PathA,
    [string]$PathB
  )

  $a = [System.Drawing.Bitmap]::new($PathA)
  $b = [System.Drawing.Bitmap]::new($PathB)
  try {
    $w = [Math]::Min($a.Width, $b.Width)
    $h = [Math]::Min($a.Height, $b.Height)
    if ($w -lt 1 -or $h -lt 1) { throw "Invalid frame size." }

    $stepX = [Math]::Max(1, [int]($w / 160))
    $stepY = [Math]::Max(1, [int]($h / 120))
    $sum = 0.0
    $count = 0
    for ($y = 0; $y -lt $h; $y += $stepY) {
      for ($x = 0; $x -lt $w; $x += $stepX) {
        $ca = $a.GetPixel($x, $y)
        $cb = $b.GetPixel($x, $y)
        $dr = [Math]::Abs($ca.R - $cb.R)
        $dg = [Math]::Abs($ca.G - $cb.G)
        $db = [Math]::Abs($ca.B - $cb.B)
        $sum += ($dr + $dg + $db) / 3.0
        $count++
      }
    }
    $avgDiff = if ($count -gt 0) { $sum / $count } else { 999.0 }
    return [Math]::Round($avgDiff, 2)
  }
  finally {
    $a.Dispose()
    $b.Dispose()
  }
}

function Ensure-Dir {
  param([string]$Path)
  if (!(Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Get-FfmpegPath {
  try {
    $cmd = Get-Command ffmpeg -ErrorAction Stop
    return $cmd.Source
  } catch {
    return $null
  }
}

Ensure-Dir -Path $OutputDir
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$videoPath = Join-Path $OutputDir "overlay_probe_$timestamp.mp4"
$frameVisible = Join-Path $OutputDir "overlay_probe_visible_$timestamp.png"
$frameHidden = Join-Path $OutputDir "overlay_probe_hidden_$timestamp.png"

$overlay = Get-OverlayWindow -TitleHint $WindowTitleHint
if ($null -eq $overlay) {
  throw "未找到悬浮窗。请先用你的快捷键呼出截图问答悬浮窗，再运行本脚本。TitleHint=$WindowTitleHint"
}

$hwnd = [IntPtr]$overlay.MainWindowHandle
$rect = Get-RectFromHandle -Handle $hwnd

Write-Host "[Probe] Overlay window: $($overlay.MainWindowTitle)"
Write-Host "[Probe] Rect: L=$($rect.Left) T=$($rect.Top) W=$($rect.Width) H=$($rect.Height)"

$ffmpeg = Get-FfmpegPath
if ($null -eq $ffmpeg) {
  throw "ffmpeg not found. Please install ffmpeg and add it to PATH."
}

if ($DurationSec -lt 4) { $DurationSec = 4 }
if ($Fps -lt 5) { $Fps = 5 }

Write-Host "[Probe] Start recording: $videoPath"

# During recording toggle one cycle: visible -> hidden -> visible
[Win32Probe]::ShowWindow($hwnd, 4) | Out-Null  # SW_SHOWNOACTIVATE

$ff = Start-Process -FilePath $ffmpeg -ArgumentList @(
  "-y",
  "-f", "gdigrab",
  "-framerate", "$Fps",
  "-i", "desktop",
  "-t", "$DurationSec",
  "-vcodec", "libx264",
  "-pix_fmt", "yuv420p",
  "$videoPath"
) -PassThru -NoNewWindow

Start-Sleep -Milliseconds 1100
[Win32Probe]::ShowWindow($hwnd, 0) | Out-Null  # SW_HIDE
Start-Sleep -Milliseconds 1000
[Win32Probe]::ShowWindow($hwnd, 4) | Out-Null  # SW_SHOWNOACTIVATE

$ff.WaitForExit()
if (!(Test-Path $videoPath)) {
  throw "Recording failed, output not found: $videoPath"
}

# Extract 2 frames: 1.0s (visible) and 2.0s (hidden)
& $ffmpeg -y -ss 1.0 -i $videoPath -frames:v 1 $frameVisible | Out-Null
& $ffmpeg -y -ss 2.0 -i $videoPath -frames:v 1 $frameHidden | Out-Null

if (!(Test-Path $frameVisible) -or !(Test-Path $frameHidden)) {
  throw "Frame extraction failed: $frameVisible / $frameHidden"
}

$diff = Compare-Images -PathA $frameVisible -PathB $frameHidden

Write-Host ""
Write-Host "=== Overlay Record Capture Result ==="
Write-Host "video: $videoPath"
Write-Host "frame_visible: $frameVisible"
Write-Host "frame_hidden:  $frameHidden"
Write-Host "avg_pixel_diff: $diff"

# Threshold notes:
# - low diff: visible/hidden frames are close => overlay likely not captured.
# - high diff: visible/hidden frames differ a lot => overlay likely captured.
if ($diff -lt 6.0) {
  Write-Host "PASS: overlay is not clearly captured in recording frames."
  exit 0
}
elseif ($diff -lt 12.0) {
  Write-Host "WARN: medium diff, please review extracted frames manually."
  exit 1
}
else {
  Write-Host "FAIL: large diff, overlay is likely captured in recording."
  exit 2
}

param(
  [ValidateSet('list', 'listen')]
  [string]$Mode = 'list',
  [string]$Provider = 'local_windows',
  [string]$TranscriptPath = '',
  [string]$StopPath = '',
  [string]$ErrorPath = '',
  [string]$DevicesJsonPath = '',
  [string]$SelectedDeviceId = '',
  [string]$DataFile = ''
)

$ErrorActionPreference = 'Stop'
if ($null -ne (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue)) {
  $PSNativeCommandUseErrorActionPreference = $false
}

function Write-ErrorFile {
  param([string]$Message)
  if ([string]::IsNullOrWhiteSpace($ErrorPath)) {
    return
  }
  [IO.File]::WriteAllText($ErrorPath, [string]$Message, [Text.Encoding]::UTF8)
}

function Ensure-TranscriptFile {
  if ([string]::IsNullOrWhiteSpace($TranscriptPath)) {
    return
  }
  if (-not (Test-Path -LiteralPath $TranscriptPath)) {
    [IO.File]::WriteAllText($TranscriptPath, '', [Text.Encoding]::UTF8)
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
    return ''
  }
}

function Normalize-XunfeiSecret {
  param([string]$Secret)
  $value = ([string]$Secret).Trim()
  if ($value -eq '') {
    return ''
  }
  if ($value -notmatch '^[A-Za-z0-9+/=]+$') {
    return $value
  }
  try {
    $decodedBytes = [Convert]::FromBase64String($value)
    $decoded = [Text.Encoding]::UTF8.GetString($decodedBytes).Trim()
    if ($decoded -match '^[\x20-\x7E]+$' -and $decoded.Length -ge 16 -and $decoded.Length -lt $value.Length) {
      return $decoded
    }
  } catch {}
  return $value
}

function Read-IniSection {
  param(
    [string]$Path,
    [string]$SectionName
  )

  $map = [ordered]@{}
  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
    return $map
  }

  $currentSection = ''
  foreach ($line in [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)) {
    $trimmed = ([string]$line).Trim()
    if ($trimmed -eq '') { continue }
    if ($trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) { continue }
    if ($trimmed -match '^\[(.+)\]$') {
      $currentSection = $matches[1].Trim()
      continue
    }
    if ($currentSection -ne $SectionName) { continue }
    $pair = $trimmed.Split('=', 2)
    if ($pair.Length -ne 2) { continue }
    $map[$pair[0].Trim()] = $pair[1]
  }
  return $map
}

function Get-XunfeiConfig {
  param([string]$IniPath)

  $sec = Read-IniSection -Path $IniPath -SectionName 'Assistant'
  $appId = if ($sec.Contains('xunfei_app_id')) { ([string]$sec['xunfei_app_id']).Trim() } else { '' }
  $apiKey = if ($sec.Contains('xunfei_api_key')) { ([string]$sec['xunfei_api_key']).Trim() } else { '' }
  $apiSecret = if ($sec.Contains('xunfei_api_secret')) { ([string]$sec['xunfei_api_secret']).Trim() } else { '' }

  if ($apiKey -eq '' -and $sec.Contains('xunfei_api_key_protected')) {
    $apiKey = Unprotect-AssistantSecret ([string]$sec['xunfei_api_key_protected'])
  }
  if ($apiSecret -eq '' -and $sec.Contains('xunfei_api_secret_protected')) {
    $apiSecret = Unprotect-AssistantSecret ([string]$sec['xunfei_api_secret_protected'])
  }
  $apiSecret = Normalize-XunfeiSecret $apiSecret

  return [ordered]@{
    app_id = $appId
    api_key = $apiKey
    api_secret = $apiSecret
  }
}

try {
  Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class AudioInputDeviceInfo {
    public string id { get; set; }
    public string label { get; set; }
    public bool is_default { get; set; }
}

public static class AudioEndpointBridge {
    public enum EDataFlow {
        eRender,
        eCapture,
        eAll,
        EDataFlow_enum_count
    }

    public enum ERole {
        eConsole,
        eMultimedia,
        eCommunications,
        ERole_enum_count
    }

    [Flags]
    public enum DEVICE_STATE : uint {
        ACTIVE = 0x00000001,
        DISABLED = 0x00000002,
        NOTPRESENT = 0x00000004,
        UNPLUGGED = 0x00000008,
        ALL = 0x0000000F
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROPERTYKEY {
        public Guid fmtid;
        public int pid;
        public PROPERTYKEY(Guid guid, int id) {
            fmtid = guid;
            pid = id;
        }
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct PROPVARIANT {
        [FieldOffset(0)]
        public ushort vt;
        [FieldOffset(8)]
        public IntPtr pointerValue;

        public string GetString() {
            if (vt == 31 && pointerValue != IntPtr.Zero) {
                return Marshal.PtrToStringUni(pointerValue);
            }
            return string.Empty;
        }
    }

    [DllImport("ole32.dll")]
    private static extern int PropVariantClear(ref PROPVARIANT pvar);

    [ComImport]
    [Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    private class MMDeviceEnumeratorComObject {
    }

    [ComImport]
    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceEnumerator {
        int EnumAudioEndpoints(EDataFlow dataFlow, DEVICE_STATE dwStateMask, out IMMDeviceCollection ppDevices);
        int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice ppEndpoint);
        int GetDevice(string pwstrId, out IMMDevice ppDevice);
        int RegisterEndpointNotificationCallback(IntPtr pClient);
        int UnregisterEndpointNotificationCallback(IntPtr pClient);
    }

    [ComImport]
    [Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceCollection {
        int GetCount(out uint pcDevices);
        int Item(uint nDevice, out IMMDevice ppDevice);
    }

    [ComImport]
    [Guid("D666063F-1587-4E43-81F1-B948E807363F")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDevice {
        int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
        int OpenPropertyStore(int stgmAccess, out IPropertyStore ppProperties);
        int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
        int GetState(out DEVICE_STATE pdwState);
    }

    [ComImport]
    [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IPropertyStore {
        int GetCount(out uint cProps);
        int GetAt(uint iProp, out PROPERTYKEY pkey);
        int GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
        int SetValue(ref PROPERTYKEY key, ref PROPVARIANT propvar);
        int Commit();
    }

    [ComImport]
    [Guid("F8679F50-850A-41CF-9C72-430F290290C8")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IPolicyConfig {
        int GetMixFormat();
        int GetDeviceFormat();
        int ResetDeviceFormat();
        int SetDeviceFormat();
        int GetProcessingPeriod();
        int SetProcessingPeriod();
        int GetShareMode();
        int SetShareMode();
        int GetPropertyValue();
        int SetPropertyValue();
        int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string wszDeviceId, ERole eRole);
        int SetEndpointVisibility();
    }

    [ComImport]
    [Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")]
    private class PolicyConfigClient {
    }

    private static IMMDeviceEnumerator CreateEnumerator() {
        return (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
    }

    private static string GetFriendlyName(IMMDevice device) {
        IPropertyStore store;
        int hr = device.OpenPropertyStore(0, out store);
        if (hr != 0 || store == null) {
            Marshal.ThrowExceptionForHR(hr);
        }
        PROPERTYKEY key = new PROPERTYKEY(new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"), 14);
        PROPVARIANT value;
        hr = store.GetValue(ref key, out value);
        if (hr != 0) {
            Marshal.ThrowExceptionForHR(hr);
        }
        try {
            return value.GetString() ?? string.Empty;
        } finally {
            PropVariantClear(ref value);
        }
    }

    public static List<AudioInputDeviceInfo> ListCaptureDevices() {
        var devices = new List<AudioInputDeviceInfo>();
        var enumerator = CreateEnumerator();
        IMMDeviceCollection collection;
        int hr = enumerator.EnumAudioEndpoints(EDataFlow.eCapture, DEVICE_STATE.ACTIVE, out collection);
        if (hr != 0) {
            Marshal.ThrowExceptionForHR(hr);
        }

        string defaultId = GetDefaultCaptureDeviceId();
        uint count;
        hr = collection.GetCount(out count);
        if (hr != 0) {
            Marshal.ThrowExceptionForHR(hr);
        }

        for (uint i = 0; i < count; i++) {
            IMMDevice device;
            hr = collection.Item(i, out device);
            if (hr != 0) {
                continue;
            }

            string id;
            hr = device.GetId(out id);
            if (hr != 0 || string.IsNullOrWhiteSpace(id)) {
                continue;
            }

            string label = string.Empty;
            try {
                label = GetFriendlyName(device);
            } catch {
                label = id;
            }

            devices.Add(new AudioInputDeviceInfo {
                id = id,
                label = string.IsNullOrWhiteSpace(label) ? id : label,
                is_default = string.Equals(defaultId, id, StringComparison.OrdinalIgnoreCase)
            });
        }

        return devices;
    }

    public static string GetDefaultCaptureDeviceId() {
        var enumerator = CreateEnumerator();
        IMMDevice device;
        int hr = enumerator.GetDefaultAudioEndpoint(EDataFlow.eCapture, ERole.eMultimedia, out device);
        if (hr != 0 || device == null) {
            return string.Empty;
        }
        string id;
        hr = device.GetId(out id);
        if (hr != 0) {
            return string.Empty;
        }
        return id ?? string.Empty;
    }

    public static void SetDefaultCaptureDevice(string deviceId) {
        if (string.IsNullOrWhiteSpace(deviceId)) {
            return;
        }
        var policy = (IPolicyConfig)(new PolicyConfigClient());
        policy.SetDefaultEndpoint(deviceId, ERole.eConsole);
        policy.SetDefaultEndpoint(deviceId, ERole.eMultimedia);
        policy.SetDefaultEndpoint(deviceId, ERole.eCommunications);
    }
}
"@ -Language CSharp
} catch {
  # Type may already be loaded in the current process.
}

function Get-CaptureDevices {
  return [AudioEndpointBridge]::ListCaptureDevices()
}

function Get-CaptureDeviceLabelById {
  param([string]$DeviceId)
  $target = ([string]$DeviceId).Trim()
  $devices = Get-CaptureDevices
  if ($target -ne '') {
    foreach ($device in $devices) {
      if ([string]$device.id -eq $target) {
        return ([string]$device.label).Trim()
      }
    }
  }
  foreach ($device in $devices) {
    if ($device.is_default) {
      return ([string]$device.label).Trim()
    }
  }
  if ($devices.Count -gt 0) {
    return ([string]$devices[0].label).Trim()
  }
  return ''
}

function Get-DShowAudioDeviceNames {
  $output = & ffmpeg -hide_banner -f dshow -list_devices true -i dummy 2>&1
  $names = New-Object 'System.Collections.Generic.List[string]'
  foreach ($line in $output) {
    $text = [string]$line
    if ($text -match '"(.+)" \(audio\)') {
      $name = $matches[1].Trim()
      if ($name -ne '' -and -not $names.Contains($name)) {
        [void]$names.Add($name)
      }
    }
  }
  return $names
}

function Resolve-DShowAudioDeviceName {
  param([string]$SelectedId)

  $preferred = Get-CaptureDeviceLabelById -DeviceId $SelectedId
  if (-not [string]::IsNullOrWhiteSpace($preferred)) {
    return $preferred
  }

  $candidates = Get-DShowAudioDeviceNames

  if ($candidates.Count -gt 0) {
    return $candidates[0]
  }
  return ''
}

function Invoke-FfmpegRawCapture {
  param(
    [string]$AudioPath,
    [string]$StopFlagPath,
    [string]$SelectedId
  )

  if ([string]::IsNullOrWhiteSpace($AudioPath)) {
    throw 'audio path missing'
  }

  $deviceName = Resolve-DShowAudioDeviceName -SelectedId $SelectedId
  if ([string]::IsNullOrWhiteSpace($deviceName)) {
    throw 'no DirectShow microphone found for ffmpeg capture'
  }

  if (Test-Path -LiteralPath $AudioPath) {
    Remove-Item -LiteralPath $AudioPath -Force
  }

  $args = @(
    '-hide_banner',
    '-loglevel', 'error',
    '-y',
    '-f', 'dshow',
    '-i', ('audio=' + $deviceName),
    '-ac', '1',
    '-ar', '16000',
    '-f', 's16le',
    $AudioPath
  )

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'ffmpeg'
  $quotedArgs = foreach ($arg in $args) {
    $text = [string]$arg
    if ($text -match '[\s"]') {
      '"' + ($text -replace '"', '\"') + '"'
    } else {
      $text
    }
  }
  $psi.Arguments = [string]::Join(' ', $quotedArgs)
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardError = $true

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  [void]$proc.Start()
  try {
    while (-not (Test-Path -LiteralPath $StopFlagPath)) {
      if ($proc.HasExited) {
        break
      }
      Start-Sleep -Milliseconds 100
    }
  } finally {
    if (-not $proc.HasExited) {
      try {
        $proc.StandardInput.WriteLine('q')
        $proc.StandardInput.Flush()
      } catch {}
      try {
        if (-not $proc.WaitForExit(4000)) {
          $proc.Kill()
          $proc.WaitForExit(2000) | Out-Null
        }
      } catch {}
    }
  }

  if (-not (Test-Path -LiteralPath $AudioPath)) {
    throw 'ffmpeg capture did not produce audio'
  }
}

function Get-XunfeiAuthUrl {
  param(
    [string]$ApiKey,
    [string]$ApiSecret
  )

  $wsHost = 'iat-api.xfyun.cn'
  $path = '/v2/iat'
  $date = [DateTime]::UtcNow.ToString('r')
  $signatureOrigin = "host: $wsHost`ndate: $date`nGET $path HTTP/1.1"
  $hmac = New-Object System.Security.Cryptography.HMACSHA256
  $hmac.Key = [Text.Encoding]::UTF8.GetBytes($ApiSecret)
  try {
    $signatureBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($signatureOrigin))
  } finally {
    $hmac.Dispose()
  }
  $signature = [Convert]::ToBase64String($signatureBytes)
  $authorizationOrigin = "api_key=`"$ApiKey`", algorithm=`"hmac-sha256`", headers=`"host date request-line`", signature=`"$signature`""
  $authorization = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($authorizationOrigin))
  return "wss://${wsHost}${path}?authorization=$([uri]::EscapeDataString($authorization))&date=$([uri]::EscapeDataString($date))&host=$wsHost"
}

function Send-WebSocketJson {
  param(
    [System.Net.WebSockets.ClientWebSocket]$Socket,
    [object]$Payload
  )
  $json = $Payload | ConvertTo-Json -Depth 8 -Compress
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $segment = [ArraySegment[byte]]::new($bytes)
  $Socket.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
}

function Receive-WebSocketMessage {
  param(
    [System.Net.WebSockets.ClientWebSocket]$Socket,
    [int]$TimeoutMs = 1500
  )

  $buffer = New-Object byte[] 8192
  $segment = [ArraySegment[byte]]::new($buffer)
  $stream = New-Object IO.MemoryStream
  try {
    while ($true) {
      $task = $Socket.ReceiveAsync($segment, [Threading.CancellationToken]::None)
      if (-not $task.Wait($TimeoutMs)) {
        if ($stream.Length -gt 0) {
          break
        }
        return $null
      }
      $result = $task.Result
      if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
        return [ordered]@{ type = 'close'; text = '' }
      }
      if ($result.Count -gt 0) {
        $stream.Write($buffer, 0, $result.Count)
      }
      if ($result.EndOfMessage) {
        break
      }
    }
    return [ordered]@{
      type = 'text'
      text = [Text.Encoding]::UTF8.GetString($stream.ToArray())
    }
  } finally {
    $stream.Dispose()
  }
}

function Get-XunfeiResultText {
  param($Payload)

  $parts = New-Object 'System.Collections.Generic.List[string]'
  $wsList = $Payload.data.result.ws
  foreach ($ws in @($wsList)) {
    foreach ($cw in @($ws.cw)) {
      $word = ([string]$cw.w).Trim()
      if ($word -ne '') {
        [void]$parts.Add($word)
      }
    }
  }
  return [string]::Join('', $parts)
}

function Invoke-XunfeiTranscription {
  param(
    [string]$AudioPath,
    [string]$IniPath
  )

  $cfg = Get-XunfeiConfig -IniPath $IniPath
  $appId = ([string]$cfg.app_id).Trim()
  $apiKey = ([string]$cfg.api_key).Trim()
  $apiSecret = ([string]$cfg.api_secret).Trim()

  if ($appId -eq '' -or $apiKey -eq '' -or $apiSecret -eq '') {
    throw 'xunfei websocket credentials missing in config.ini Assistant section'
  }
  if (-not (Test-Path -LiteralPath $AudioPath)) {
    throw 'xunfei audio file missing'
  }

  $pythonScript = Join-Path $PSScriptRoot 'xunfei_asr.py'
  if (-not (Test-Path -LiteralPath $pythonScript)) {
    throw 'xunfei python worker missing'
  }

  $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
  if ($null -eq $pythonCmd) {
    throw 'python not found for xunfei websocket asr'
  }

  $previousAppId = $env:XUNFEI_APP_ID
  $previousApiKey = $env:XUNFEI_API_KEY
  $previousApiSecret = $env:XUNFEI_API_SECRET
  try {
    $env:XUNFEI_APP_ID = $appId
    $env:XUNFEI_API_KEY = $apiKey
    $env:XUNFEI_API_SECRET = $apiSecret
    $resultLines = & $pythonCmd.Source $pythonScript --audio $AudioPath 2>&1
    $exitCode = $LASTEXITCODE
    $resultText = (($resultLines | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
    if ($exitCode -ne 0) {
      if ($resultText -eq '') {
        throw 'xunfei python worker failed'
      }
      throw $resultText
    }
    return $resultText
  } finally {
    $env:XUNFEI_APP_ID = $previousAppId
    $env:XUNFEI_API_KEY = $previousApiKey
    $env:XUNFEI_API_SECRET = $previousApiSecret
  }
}

if ($Mode -eq 'list') {
  $devices = Get-CaptureDevices
  $json = $devices | ConvertTo-Json -Depth 4
  if ([string]::IsNullOrWhiteSpace($DevicesJsonPath)) {
    $json
  } else {
    [IO.File]::WriteAllText($DevicesJsonPath, $json, [Text.Encoding]::UTF8)
  }
  exit 0
}

$providerKey = ([string]$Provider).Trim().ToLowerInvariant()
$previousDefault = ''
$shouldRestoreDefault = $false
$engine = $null
$tempAudioPath = ''

try {
  Ensure-TranscriptFile

  if ($providerKey -eq 'xunfei_websocket_asr') {
    $tempAudioPath = Join-Path $env:TEMP 'raccourci_voice_input_xunfei.pcm'
    Invoke-FfmpegRawCapture -AudioPath $tempAudioPath -StopFlagPath $StopPath -SelectedId $SelectedDeviceId
    $transcript = Invoke-XunfeiTranscription -AudioPath $tempAudioPath -IniPath $DataFile
    [IO.File]::WriteAllText($TranscriptPath, ([string]$transcript).Trim(), [Text.Encoding]::UTF8)
    exit 0
  }

  Add-Type -AssemblyName System.Speech

  if (-not [string]::IsNullOrWhiteSpace($SelectedDeviceId)) {
    $previousDefault = [AudioEndpointBridge]::GetDefaultCaptureDeviceId()
    if (-not [string]::IsNullOrWhiteSpace($previousDefault) -and $previousDefault -ne $SelectedDeviceId) {
      [AudioEndpointBridge]::SetDefaultCaptureDevice($SelectedDeviceId)
      $shouldRestoreDefault = $true
      Start-Sleep -Milliseconds 220
    }
  }

  try {
    $engine = New-Object System.Speech.Recognition.SpeechRecognitionEngine([System.Globalization.CultureInfo]::InstalledUICulture)
  } catch {
    $engine = New-Object System.Speech.Recognition.SpeechRecognitionEngine
  }

  $grammar = New-Object System.Speech.Recognition.DictationGrammar
  $engine.LoadGrammar($grammar)
  $engine.SetInputToDefaultAudioDevice()

  $parts = New-Object 'System.Collections.Generic.List[string]'

  while (-not (Test-Path -LiteralPath $StopPath)) {
    $result = $null
    try {
      $result = $engine.Recognize([TimeSpan]::FromMilliseconds(700))
    } catch {
      Start-Sleep -Milliseconds 120
      continue
    }
    if ($null -eq $result) { continue }

    $text = ([string]$result.Text).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { continue }
    if ($result.Confidence -lt 0.35) { continue }
    if ($parts.Count -gt 0 -and $parts[$parts.Count - 1] -eq $text) { continue }

    [void]$parts.Add($text)
    [IO.File]::WriteAllText($TranscriptPath, [string]::Join([Environment]::NewLine, $parts), [Text.Encoding]::UTF8)
  }

  Ensure-TranscriptFile
} catch {
  Write-ErrorFile $_.Exception.Message
  Ensure-TranscriptFile
} finally {
  try {
    if ($null -ne $engine) {
      $engine.Dispose()
    }
  } catch {}

  if ($shouldRestoreDefault -and -not [string]::IsNullOrWhiteSpace($previousDefault)) {
    try {
      [AudioEndpointBridge]::SetDefaultCaptureDevice($previousDefault)
    } catch {}
  }

  if ($tempAudioPath -ne '' -and (Test-Path -LiteralPath $tempAudioPath)) {
    try {
      Remove-Item -LiteralPath $tempAudioPath -Force
    } catch {}
  }
}

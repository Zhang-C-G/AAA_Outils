param(
  [ValidateSet('list', 'listen')]
  [string]$Mode = 'list',
  [string]$TranscriptPath = '',
  [string]$StopPath = '',
  [string]$ErrorPath = '',
  [string]$DevicesJsonPath = '',
  [string]$SelectedDeviceId = ''
)

$ErrorActionPreference = 'Stop'

function Write-ErrorFile {
  param([string]$Message)
  if ([string]::IsNullOrWhiteSpace($ErrorPath)) {
    return
  }
  [IO.File]::WriteAllText($ErrorPath, [string]$Message, [Text.Encoding]::UTF8)
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

if ($Mode -eq 'list') {
  $devices = [AudioEndpointBridge]::ListCaptureDevices()
  $json = $devices | ConvertTo-Json -Depth 4
  if ([string]::IsNullOrWhiteSpace($DevicesJsonPath)) {
    $json
  } else {
    [IO.File]::WriteAllText($DevicesJsonPath, $json, [Text.Encoding]::UTF8)
  }
  exit 0
}

$previousDefault = ''
$shouldRestoreDefault = $false
$engine = $null

try {
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

  if (-not (Test-Path -LiteralPath $TranscriptPath)) {
    [IO.File]::WriteAllText($TranscriptPath, '', [Text.Encoding]::UTF8)
  }
} catch {
  Write-ErrorFile $_.Exception.Message
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
}

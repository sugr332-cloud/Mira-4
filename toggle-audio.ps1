# スピーカー <-> ヘッドセット 切替 (出力 + マイク)
# 使い方: powershell -File toggle-audio.ps1 [-List] [-To speaker|headset]
param([switch]$List, [ValidateSet('speaker','headset','')][string]$To = '')

$ErrorActionPreference = 'Stop'
$cfg = Get-Content (Join-Path $PSScriptRoot 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(int flow, int mask, out IntPtr devices);
    int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice device);
}
[ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    int Activate(ref Guid iid, int ctx, IntPtr p, out IntPtr o);
    int OpenPropertyStore(int access, out IntPtr props);
    int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
}
[ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IPolicyConfig {
    int GetMixFormat(); int GetDeviceFormat(); int ResetDeviceFormat(); int SetDeviceFormat();
    int GetProcessingPeriod(); int SetProcessingPeriod(); int GetShareMode(); int SetShareMode();
    int GetPropertyValue(); int SetPropertyValue();
    [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role);
    int SetEndpointVisibility();
}
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCom {}
[ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")] class PolicyConfigCom {}

public static class Audio {
    public static string GetDefault(int flow) {   // flow: 0=出力 1=入力
        var e = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
        IMMDevice d; e.GetDefaultAudioEndpoint(flow, 1, out d);
        string id; d.GetId(out id); return id;
    }
    public static void SetDefault(string id) {    // 全ロール(通常/マルチメディア/通信)に設定
        var p = (IPolicyConfig)new PolicyConfigCom();
        for (int r = 0; r < 3; r++) {
            int hr = p.SetDefaultEndpoint(id, r);
            if (hr != 0) throw new Exception("SetDefaultEndpoint failed: 0x" + hr.ToString("X"));
        }
    }
}
'@

# 有効な音声エンドポイント一覧 (ID は "{0.0.x.00000000}.{GUID}")
$devs = Get-PnpDevice -Class AudioEndpoint -Status OK | ForEach-Object {
    $id = $_.InstanceId -replace '^SWD\\MMDEVAPI\\', ''
    [pscustomobject]@{ Name = $_.FriendlyName; Id = $id; Flow = $(if ($id -like '{0.0.0*') { 0 } else { 1 }) }
}

if ($List) {
    $devs | Sort-Object Flow, Name | ForEach-Object { '{0}  {1}' -f $(if ($_.Flow -eq 0) { '出力' } else { '入力' }), $_.Name }
    return
}

function Find-Dev($flow, $pattern) {
    $m = @($devs | Where-Object { $_.Flow -eq $flow -and $_.Name -match $pattern })
    if (-not $m) { throw "デバイスが見つかりません: '$pattern' (config.json を確認。-List で一覧表示)" }
    $m[0]
}

$hsOut  = Find-Dev 0 $cfg.headset.output
$hsIn   = Find-Dev 1 $cfg.headset.mic
$spOut  = Find-Dev 0 $cfg.speaker.output
$spIn   = Find-Dev 1 $cfg.speaker.mic

if (-not $To) {
    # 現在の出力がヘッドセットならスピーカーへ、それ以外ならヘッドセットへ
    $To = if ([Audio]::GetDefault(0) -eq $hsOut.Id) { 'speaker' } else { 'headset' }
}
$out, $in = if ($To -eq 'headset') { $hsOut, $hsIn } else { $spOut, $spIn }

[Audio]::SetDefault($out.Id)
[Audio]::SetDefault($in.Id)
Write-Host ("→ {0}`n  出力: {1}`n  マイク: {2}" -f $To, $out.Name, $in.Name)

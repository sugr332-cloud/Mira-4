# アプリを起動 or 最前面化して、ウィンドウ中央にマウスカーソルを移動する
# 使い方: powershell -File launch-focus.ps1 -App companion|aion2
param([Parameter(Mandatory)][ValidateSet('companion','aion2')][string]$App)

$apps = @{
    companion = @{ Process = 'FullAIon2Companion'; Launch = "$env:LOCALAPPDATA\Programs\FullAIon2Companion-ja\FullAIon2Companion.exe" }
    aion2     = @{ Process = 'AION2';              Launch = 'steam://rungameid/3393110' }
}
$a = $apps[$App]

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Win {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
'@
[void][Win]::SetProcessDPIAware()

function Get-AppWindow {
    Get-Process -Name $a.Process -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
        Select-Object -First 1
}

$p = Get-AppWindow
if (-not $p) {
    if (-not (Get-Process -Name $a.Process -ErrorAction SilentlyContinue)) {
        Start-Process $a.Launch
    }
    # ウィンドウが出るまで最大120秒待つ
    for ($i = 0; $i -lt 240 -and -not $p; $i++) {
        Start-Sleep -Milliseconds 500
        $p = Get-AppWindow
    }
    if (-not $p) { exit 1 }
    Start-Sleep -Milliseconds 800   # 描画待ち
}

$h = $p.MainWindowHandle
if ([Win]::IsIconic($h)) { [void][Win]::ShowWindow($h, 9) }   # 最小化なら復元
[Win]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)               # Alt押下: 前面化制限の回避
[void][Win]::SetForegroundWindow($h)
[Win]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)               # Alt解放

$r = New-Object Win+RECT
[void][Win]::GetWindowRect($h, [ref]$r)
[void][Win]::SetCursorPos([int](($r.L + $r.R) / 2), [int](($r.T + $r.B) / 2))

# アプリを起動 or 最前面化して、ウィンドウ中央にマウスカーソルを移動する
# 使い方: powershell -File launch-focus.ps1 -App companion|aion2
param([Parameter(Mandatory)][ValidateSet('companion','aion2','orca')][string]$App)

$apps = @{
    orca      = @{ Process = 'Orca';               Launch = "$env:LOCALAPPDATA\Programs\orca\Orca.exe"; Click = $true }   # 中央をクリックしてチャット欄にフォーカス
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
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr h, bool alt);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
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
# 現在の前面ウィンドウのスレッドに入力をアタッチして前面化権限を得る
$fg = [Win]::GetForegroundWindow()
$dummy = [uint32]0
$fgThread  = [Win]::GetWindowThreadProcessId($fg, [ref]$dummy)
$curThread = [Win]::GetCurrentThreadId()
[void][Win]::AttachThreadInput($curThread, $fgThread, $true)
[void][Win]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x0003)   # 一時的に最前面(TOPMOST)
[void][Win]::SetWindowPos($h, [IntPtr](-2), 0, 0, 0, 0, 0x0003)   # TOPMOST解除(最前面の位置は維持)
[void][Win]::BringWindowToTop($h)
[void][Win]::SetForegroundWindow($h)
[Win]::SwitchToThisWindow($h, $true)
[void][Win]::AttachThreadInput($curThread, $fgThread, $false)

$r = New-Object Win+RECT
[void][Win]::GetWindowRect($h, [ref]$r)
[void][Win]::SetCursorPos([int](($r.L + $r.R) / 2), [int](($r.T + $r.B) / 2))

if ($a.Click) {
    Start-Sleep -Milliseconds 150
    [Win]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)   # 左ボタン押下
    [Win]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)   # 左ボタン解放
}

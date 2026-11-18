# アプリを起動 or 最前面化して、ウィンドウ中央にマウスカーソルを移動する
# 使い方: powershell -File launch-focus.ps1 -App companion|aion2
param([Parameter(Mandatory)][ValidateSet('companion','aion2','orca','discord','youtube')][string]$App)

$apps = @{
    orca      = @{ Process = 'Orca';               Launch = "$env:LOCALAPPDATA\Programs\orca\Orca.exe"; Click = $true }   # 中央をクリックしてチャット欄にフォーカス
    companion = @{ Process = 'FullAIon2Companion'; Launch = "$env:LOCALAPPDATA\Programs\FullAIon2Companion-ja\FullAIon2Companion.exe" }
    aion2     = @{ Process = 'AION2';              Launch = 'steam://rungameid/3393110' }
    # Edge の Web アプリ(PWA)。プロセスではなくウィンドウタイトルで探し、起動済みなら新規起動せずそのウィンドウを前面化する
    discord   = @{ TitleMatch = 'Discord'; TitleExclude = 'Microsoft|Overlay'
                   Launch = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge_proxy.exe"
                   Args   = '--profile-directory=Default --app-id=pliiebkcmokkgndfalahlmimanmbjlab --app-url=https://discord.com/app --app-launch-source=19' }
    youtube   = @{ TitleMatch = 'YouTube'; TitleExclude = 'Microsoft'
                   Launch = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge_proxy.exe"
                   Args   = '--profile-directory=Default --app-id=agimnkijcaahngcdmfeangaknmldooml --app-launch-source=19' }
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
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
    // タイトルに match を含み exclude を含まない、Chromium系の可視トップレベルウィンドウを返す(正規表現)
    public static IntPtr FindByTitle(string match, string exclude) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, l) => {
            if (!IsWindowVisible(h)) return true;
            var c = new System.Text.StringBuilder(64); GetClassName(h, c, 64);
            if (c.ToString() != "Chrome_WidgetWin_1") return true;
            var t = new System.Text.StringBuilder(512); GetWindowText(h, t, 512);
            var ts = t.ToString();
            if (System.Text.RegularExpressions.Regex.IsMatch(ts, match) && (string.IsNullOrEmpty(exclude) || !System.Text.RegularExpressions.Regex.IsMatch(ts, exclude))) { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }
    [DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint action, uint param, IntPtr pv, uint flags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
'@
[void][Win]::SetProcessDPIAware()

function Get-AppWindow {
    if ($a.TitleMatch) {
        $w = [Win]::FindByTitle($a.TitleMatch, $a.TitleExclude)
        if ($w -ne [IntPtr]::Zero) { return [pscustomobject]@{ MainWindowHandle = $w } }
        return $null
    }
    Get-Process -Name $a.Process -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
        Select-Object -First 1
}

$p = Get-AppWindow
if (-not $p) {
    if ($a.TitleMatch -or -not (Get-Process -Name $a.Process -ErrorAction SilentlyContinue)) {
        if ($a.Args) { Start-Process $a.Launch -ArgumentList $a.Args } else { Start-Process $a.Launch }
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
[void][Win]::SystemParametersInfo(0x2001, 0, [IntPtr]::Zero, 0)   # 前面化ロックのタイムアウトを0に(このセッション中のみ)
[Win]::keybd_event(0x87, 0, 0, [UIntPtr]::Zero)                   # F24 空打ち: 入力を受けたプロセス扱いにして前面化を許可させる(Altと違いメニューは出ない)
[Win]::keybd_event(0x87, 0, 2, [UIntPtr]::Zero)
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

# ゲーム等に前面を奪い返された場合に備え、数秒間は目的のウィンドウが前面か見張って取り返す
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 150
    if ([Win]::GetForegroundWindow() -ne $h) { [void][Win]::SetForegroundWindow($h); [Win]::SwitchToThisWindow($h, $true) }
}
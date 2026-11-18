# 管理者権限で動く AION2 の起動中でも、前面化できるようにするための一度きりの設定。
# launch-focus.ps1 を「最上位の特権で実行」するタスクとして登録する (登録時にUACの確認が1回出る)。
# 登録後は launch-*.bat がタスクを呼び出すので、ボタンを押すたびの確認は出ない。
# 解除する場合: powershell -File setup-elevated-tasks.ps1 -Remove
param([switch]$Remove)

$apps = 'orca', 'discord', 'youtube', 'companion'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Remove) { $argList += ' -Remove' }
    Start-Process powershell -Verb RunAs -ArgumentList $argList -Wait
    return
}

$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
foreach ($app in $apps) {
    $name = "MiraFocus-$app"
    Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    if ($Remove) { "removed $name"; continue }

    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
                    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSScriptRoot\launch-focus.ps1`" -App $app"
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                    -ExecutionTimeLimit (New-TimeSpan -Minutes 3) -MultipleInstances Parallel
    Register-ScheduledTask -TaskName $name -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    "registered $name"
}
Start-Sleep -Seconds 2

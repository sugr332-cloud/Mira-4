@echo off
schtasks /query /tn "MiraFocus-youtube" >nul 2>&1
if not errorlevel 1 (
    schtasks /run /tn "MiraFocus-youtube" >nul 2>&1
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0launch-focus.ps1" -App youtube

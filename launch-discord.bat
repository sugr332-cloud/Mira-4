@echo off
schtasks /query /tn "MiraFocus-discord" >nul 2>&1
if not errorlevel 1 (
    schtasks /run /tn "MiraFocus-discord" >nul 2>&1
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0launch-focus.ps1" -App discord

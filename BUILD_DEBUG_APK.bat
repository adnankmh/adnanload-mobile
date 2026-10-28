@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title ADNANLOAD - Build Android Debug APK
echo ADNANLOAD Android Debug Build - see build_logs for diagnostics.
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Windows PowerShell not found.
  goto :failed
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build_android.ps1" -Mode debug
if errorlevel 1 goto :failed
echo [SUCCESS] Debug APK should be in build\app\outputs\flutter-apk\
pause
exit /b 0
:failed
echo [FAILED] Read newest log in build_logs.
pause
exit /b 1

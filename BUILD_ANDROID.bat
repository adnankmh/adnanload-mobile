@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title ADNANLOAD - Android APK Build (Release)
echo.
echo  ===========================================================
echo              ADNANLOAD MOBILE - ANDROID BUILDER
echo  ===========================================================
echo  This window will STAY OPEN if a build step fails.
echo  A dated build log will be saved in build_logs.
echo.
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Windows PowerShell was not found.
  echo         Please use Windows 10 or newer with PowerShell installed.
  goto :error
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build_android.ps1" -Mode release
set "BUILD_EXIT=%ERRORLEVEL%"
if not "%BUILD_EXIT%"=="0" goto :error
echo.
echo [SUCCESS] Android packaging finished. See the outputs shown above.
echo.
pause
exit /b 0
:error
echo.
echo [FAILED] Build could not finish. Read the explanation above and
echo          share the newest text log inside build_logs for diagnosis.
echo.
pause
exit /b 1

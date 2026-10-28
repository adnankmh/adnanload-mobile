@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
echo =======================================================
echo  ADNANLOAD - Upload Flutter source to private GitHub repo
echo =======================================================
echo This does NOT require Flutter or Android Studio.
echo Requires Git and GitHub CLI (gh).
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\upload_to_github.ps1"
set "EXITCODE=%ERRORLEVEL%"
echo.
if not "%EXITCODE%"=="0" echo Upload stopped with error %EXITCODE%. Read the message above.
if "%EXITCODE%"=="0" echo Upload finished. Check GitHub Actions for your APK.
echo.
pause
exit /b %EXITCODE%

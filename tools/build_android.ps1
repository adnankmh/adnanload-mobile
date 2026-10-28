# Windows PowerShell 5.1+ compatible. No Python installation required.
[CmdletBinding()]
param([ValidateSet('debug','release')][string]$Mode='release')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
$logDir = Join-Path $root 'build_logs'
if (!(Test-Path $logDir)) {New-Item -ItemType Directory -Path $logDir | Out-Null}
$logPath = Join-Path $logDir ('android_{0}_{1}.txt' -f $Mode,(Get-Date -Format 'yyyyMMdd_HHmmss'))
$script:transcript = $false
function Step([string]$message) {Write-Host "`n[ADNANLOAD] $message" -ForegroundColor Cyan}
function Run([string]$exe,[string[]]$arguments) {
  Write-Host ('> {0} {1}' -f $exe,($arguments -join ' '))
  & $exe @arguments
  if ($LASTEXITCODE -ne 0) { throw ('Command exited with {0}: {1}' -f $LASTEXITCODE,$exe) }
}
function FindFlutter {
  $command = Get-Command flutter -ErrorAction SilentlyContinue
  if ($null -ne $command) {return $command.Source}
  $candidates = @(
    (Join-Path $env:USERPROFILE 'development\flutter\bin\flutter.bat'),
    (Join-Path $env:USERPROFILE 'flutter\bin\flutter.bat'),
    'C:\src\flutter\bin\flutter.bat',
    'C:\flutter\bin\flutter.bat',
    (Join-Path $env:LOCALAPPDATA 'flutter\bin\flutter.bat')
  )
  if ($env:FLUTTER_ROOT) { $candidates += (Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat') }
  foreach ($candidate in $candidates) {if (Test-Path $candidate) {return $candidate}}
  return $null
}
try {
  try {Start-Transcript -Path $logPath -ErrorAction Stop | Out-Null; $script:transcript=$true} catch {Write-Host "Transcript unavailable: $_"}
  Step "Starting $Mode build at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  Write-Host "Source folder: $root"
  Write-Host "Log file: $logPath"
  $flutter = FindFlutter
  if (!$flutter) {
    throw ('Flutter SDK not found. Install stable Flutter 3.47 or newer from https://docs.flutter.dev/get-started/install/windows/mobile and add flutter\bin to PATH. Or use .github/workflows/android-ci.yml on GitHub Actions without installing Flutter on this PC.')
  }
  Step 'Check installed Flutter and Dart versions'
  $versionText = & $flutter '--version' '--machine'
  if ($LASTEXITCODE -ne 0) {throw 'Flutter SDK could not start. Verify installation and PATH.'}
  $version = ($versionText -join "`n") | ConvertFrom-Json
  Write-Host ('Flutter {0}, Dart {1}' -f $version.frameworkVersion,$version.dartSdkVersion)
  if ([version](($version.dartSdkVersion -split '[-+]')[0]) -lt [version]'3.13.0') {
    throw 'This project requires Dart >=3.13 (Flutter 3.47+). Run flutter channel stable, then flutter upgrade.'
  }
  $androidSdk = $env:ANDROID_HOME
  if (!$androidSdk) {$androidSdk=$env:ANDROID_SDK_ROOT}
  if (!$androidSdk) {$androidSdk=Join-Path $env:LOCALAPPDATA 'Android\Sdk'}
  if (!(Test-Path $androidSdk)) {
    throw ('Android SDK missing at {0}. Install Android Studio + Android SDK (SDK Platform & Build Tools), or build through GitHub Actions.' -f $androidSdk)
  }
  if (!(Get-Command java -ErrorAction SilentlyContinue) -and !$env:JAVA_HOME) {
    Write-Warning 'No Java on PATH. Android Studio bundled JBR may still be configured by Flutter; check flutter doctor -v if Gradle fails.'
  }
  if (!(Test-Path 'android/app/build.gradle.kts') -and !(Test-Path 'android/app/build.gradle')) {
    Step 'Generate missing Android project scaffold'
    Run $flutter @('create','--platforms=android','--org','com.adnanload','--project-name','adnanload_mobile','--no-pub','.')
  }
  Step 'Configure permissions, Gradle, icons and Arabic notifications'
  & (Join-Path $PSScriptRoot 'configure_android.ps1')
  if (!$?) {throw 'Android project configuration failed.'}
  Step 'Get Flutter packages'
  Run $flutter @('pub','get')
  Step 'Run Dart static analysis'
  Run $flutter @('analyze')
  Step 'Run Flutter tests'
  Run $flutter @('test')
  if ($Mode -eq 'debug') {
    Step 'Build debug APK'
    Run $flutter @('build','apk','--debug')
  } else {
    Step 'Build ARM64 release APK'
    Run $flutter @('build','apk','--release','--split-per-abi','--tree-shake-icons','--target-platform','android-arm64')
    Step 'Build Android App Bundle (AAB)'
    Run $flutter @('build','appbundle','--release')
  }
  Step 'Generate actual artifact size and SHA-256 report'
  $outputs = @()
  $outputDir = Join-Path $root 'build/app/outputs'
  if (Test-Path $outputDir) {
    $outputs = @(Get-ChildItem -Path $outputDir -Recurse -File | Where-Object { $_.Extension -in @('.apk','.aab') -and (($Mode -eq 'release' -and $_.Name -match 'release') -or ($Mode -eq 'debug' -and $_.Name -match 'debug')) })
  }
  if ($outputs.Count -eq 0) {throw 'No APK or AAB produced even though the build command completed.'}
  $report = @()
  foreach($file in $outputs) {
    $hash = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash
    $report += ('{0} | {1:N2} MB | SHA256 {2}' -f $file.FullName,($file.Length/1MB),$hash)
  }
  $reportPath = Join-Path $logDir ('artifacts_{0}.txt' -f $Mode)
  [System.IO.File]::WriteAllLines($reportPath,[string[]]$report,[System.Text.UTF8Encoding]::new($false))
  $report | ForEach-Object {Write-Host $_ -ForegroundColor Green}
  Write-Host ('Saved report: {0}' -f $reportPath)
  if ($Mode -eq 'release') { Write-Warning 'This is NOT a signed Play Store release. Configure your own signing key before publication.' }
  Step 'SUCCESS: APK output is under build\app\outputs\flutter-apk'
  exit 0
} catch {
  Write-Host "`n[BUILD ERROR] $($_.Exception.Message)" -ForegroundColor Red
  Write-Host 'Troubleshooting: read README_AR.md or build_logs\android_*.txt.' -ForegroundColor Yellow
  exit 1
} finally {
  if ($script:transcript) {try {Stop-Transcript | Out-Null} catch {}}
}

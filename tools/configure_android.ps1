# Idempotent PowerShell Android setup matching tools/configure_android.py.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteUtf8([string]$path,[string]$data) {
  [System.IO.File]::WriteAllText($path,$data,$utf8)
}
$android=Join-Path $root 'android'
$manifest=Join-Path $android 'app/src/main/AndroidManifest.xml'
if (!(Test-Path (Split-Path $manifest))) {throw 'Android scaffold missing. Run flutter create first.'}
Copy-Item (Join-Path $root 'platform_overrides/android/app/src/main/AndroidManifest.xml') $manifest -Force
$appKts=Join-Path $android 'app/build.gradle.kts'
$appGroovy=Join-Path $android 'app/build.gradle'
if (Test-Path $appKts) {
  $text=[System.IO.File]::ReadAllText($appKts)
  $text=[regex]::Replace($text,'\bminSdk\s*=\s*flutter\.minSdkVersion','minSdk = 24')
  if ($text -notmatch '\bminSdk\s*=\s*24') {throw 'Cannot set Android minSdk=24'}
  if ($text -notmatch 'isCoreLibraryDesugaringEnabled') {
    $text=$text.Replace('compileOptions {',"compileOptions {`n        isCoreLibraryDesugaringEnabled = true")
  }
  if ($text -notmatch 'coreLibraryDesugaring\(') {
    $text+="`n`ndependencies {`n    coreLibraryDesugaring(`"com.android.tools:desugar_jdk_libs_nio:2.1.5`")`n}`n"
  }
  WriteUtf8 $appKts $text
} elseif (Test-Path $appGroovy) {
  $text=[System.IO.File]::ReadAllText($appGroovy)
  $text=[regex]::Replace($text,'\bminSdkVersion\s+flutter\.minSdkVersion','minSdkVersion 24')
  if ($text -notmatch '\bminSdkVersion\s+24') {throw 'Cannot set Android minSdkVersion=24'}
  if ($text -notmatch 'coreLibraryDesugaringEnabled') {
    $text=$text.Replace('compileOptions {',"compileOptions {`n        coreLibraryDesugaringEnabled true")
  }
  if ($text -notmatch 'coreLibraryDesugaring\s+["'']') {
    $text+="`n`ndependencies {`n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs_nio:2.1.5'`n}`n"
  }
  WriteUtf8 $appGroovy $text
} else {throw 'Missing Android app Gradle file'}
$rootKts=Join-Path $android 'build.gradle.kts'
$rootGroovy=Join-Path $android 'build.gradle'
if (Test-Path $rootKts) {
  $text=[System.IO.File]::ReadAllText($rootKts)
  if ($text -notmatch 'https://jitpack.io') {
    if ($text -notmatch 'mavenCentral\(\)') {throw 'Missing mavenCentral repository in Gradle'}
    $text=[regex]::new('mavenCentral\(\)').Replace($text,"mavenCentral()`n        maven(url = `"https://jitpack.io`")",1)
    WriteUtf8 $rootKts $text
  }
} elseif(Test-Path $rootGroovy) {
  $text=[System.IO.File]::ReadAllText($rootGroovy)
  if ($text -notmatch 'https://jitpack.io') {
    $text=[regex]::new('mavenCentral\(\)').Replace($text,"mavenCentral()`n        maven { url 'https://jitpack.io' }",1)
    WriteUtf8 $rootGroovy $text
  }
}
foreach($density in @('mipmap-mdpi','mipmap-hdpi','mipmap-xhdpi','mipmap-xxhdpi','mipmap-xxxhdpi')) {
  $from=Join-Path $root "assets/android_icons/$density/ic_launcher.png"
  $to=Join-Path $android "app/src/main/res/$density/ic_launcher.png"
  New-Item -ItemType Directory -Path (Split-Path $to) -Force | Out-Null
  Copy-Item $from $to -Force
}
foreach($locale in @('values','values-ar')) {
  $from=Join-Path $root "platform_overrides/android/app/src/main/res/$locale/strings.xml"
  $to=Join-Path $android "app/src/main/res/$locale/strings.xml"
  New-Item -ItemType Directory -Path (Split-Path $to) -Force | Out-Null
  if (!(Test-Path $to)) {Copy-Item $from $to -Force; continue}
  [xml]$original=[System.IO.File]::ReadAllText($to)
  [xml]$supplement=[System.IO.File]::ReadAllText($from)
  foreach($node in $supplement.resources.ChildNodes) {
    if ($node.NodeType -ne 'Element') {continue}
    $name=$node.GetAttribute('name')
    $matches=@($original.resources.ChildNodes | Where-Object {$_.NodeType -eq 'Element' -and $_.GetAttribute('name') -eq $name})
    if ($matches.Count -eq 0) {$imported=$original.ImportNode($node,$true); [void]$original.resources.AppendChild($imported)}
  }
  WriteUtf8 $to $original.OuterXml
}
$sample=Join-Path $root 'test/widget_test.dart'
if (Test-Path $sample) {
  $text=[System.IO.File]::ReadAllText($sample)
  if ($text -match 'MyApp\(|Counter increments') {Remove-Item $sample -Force}
}
$settingsKts=Join-Path $android 'settings.gradle.kts'
if (Test-Path $settingsKts) {
  $text=[System.IO.File]::ReadAllText($settingsKts)
  $pattern='(id\s*\(\s*"org\.jetbrains\.kotlin\.android"\s*\)\s*version\s*")(\d+\.\d+\.\d+)(")'
  $new=[regex]::Replace($text,$pattern,{
    param($m)
    if ([version]$m.Groups[2].Value -lt [version]'2.1.0') {return $m.Groups[1].Value+'2.1.0'+$m.Groups[3].Value}
    return $m.Value
  })
  if ($new -ne $text) {WriteUtf8 $settingsKts $new}
}
Write-Host '[OK] Android manifest, minimum SDK, JitPack, desugaring, icons and translations configured.'

from pathlib import Path
import re
import shutil

root=Path(__file__).resolve().parents[1]
android=root/'android'
manifest=android/'app/src/main/AndroidManifest.xml'
if not manifest.parent.exists():
    raise SystemExit('Android Flutter scaffold missing. Run flutter create first.')
shutil.copy2(root/'platform_overrides/android/app/src/main/AndroidManifest.xml',manifest)

for gradle in [android/'app/build.gradle.kts',android/'app/build.gradle']:
    if not gradle.exists():
        continue
    src=gradle.read_text(encoding='utf-8')
    src,n=re.subn(r'\bminSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24',src)
    if not n:
        src,n=re.subn(r'\bminSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24',src)
    if not n and not re.search(r'\bminSdk\s*=\s*24|\bminSdkVersion\s+24',src):
        raise SystemExit(f'Please set minSdk = 24 in {gradle}')
    # The sharing plugin requires Android API 37 (targetSdk remains unchanged).
    src,found=re.subn(r'\bcompileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 37', src)
    if not found:
        src,found=re.subn(r'\bcompileSdk\s*=\s*\d+', 'compileSdk = 37', src)
    if not found:
        raise SystemExit('Cannot locate Android compileSdk setting to update to 37.')
    gradle.write_text(src,encoding='utf-8')
    print('Android configured:',gradle.relative_to(root))
    break
else:
    raise SystemExit('Android Gradle app build file not found')

# Playlist preview provider uses NewPipe Extractor from JitPack and requires
# Java desugaring. This is a source template patch, not a Gradle build check.
root_gradle=android/'build.gradle.kts'
if root_gradle.exists():
    text=root_gradle.read_text(encoding='utf-8')
    if 'https://jitpack.io' not in text:
        if 'mavenCentral()' not in text:
            raise SystemExit('Cannot add JitPack to Android root Gradle repositories.')
        text=text.replace('mavenCentral()', 'mavenCentral()\n        maven(url = "https://jitpack.io")',1)
        root_gradle.write_text(text,encoding='utf-8')
        print('JitPack enabled for playlist metadata provider.')
app_gradle=android/'app/build.gradle.kts'
if app_gradle.exists():
    text=app_gradle.read_text(encoding='utf-8')
    if 'isCoreLibraryDesugaringEnabled' not in text:
        if 'compileOptions {' not in text:
            raise SystemExit('Cannot enable desugaring in Android app Gradle file.')
        text=text.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true',1)
    if 'coreLibraryDesugaring(' not in text:
        text+='\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")\n}\n'
    # Native engine archives are intentionally carried under .zip.so names.
    if 'keepDebugSymbols.add("**/lib*.zip.so")' not in text:
        if 'android {' not in text:
            raise SystemExit('Cannot configure native archive packaging.')
        text=text.replace('android {', 'android {\n    packaging {\n        jniLibs {\n            keepDebugSymbols.add("**/lib*.zip.so")\n        }\n    }',1)
    # The app is distributed to testers as a fully functional APK. Native media
    # and extractor dependencies use reflection/service loaders. Avoid expensive
    # and potentially destructive R8 shrinking until compatibility is validated.
    # Flutter's Android plugin may enable shrinking by default in release mode.
    if 'isMinifyEnabled = false' not in text:
        text=text.replace('release {', 'release {\n            isMinifyEnabled = false\n            isShrinkResources = false', 1)
    # Modern AGP rejects android:extractNativeLibs on the manifest. Configure
    # the equivalent packaging behavior through the Gradle Kotlin DSL instead.
    if 'useLegacyPackaging = true' not in text:
        if 'jniLibs {' not in text:
            raise SystemExit('Cannot find jniLibs packaging block.')
        text=text.replace('jniLibs {', 'jniLibs {\n            useLegacyPackaging = true', 1)
    # Rhino uses optional JavaBeans APIs absent from Android. R8 must not
    # treat these optional references as fatal during Release optimization.
    if 'proguard-rules.pro' not in text:
        if 'release {' not in text:
            raise SystemExit('Cannot find Android release build type.')
        text=text.replace('release {',
            'release {\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")',1)
    app_gradle.write_text(text,encoding='utf-8')
    rules_path=app_gradle.parent/'proguard-rules.pro'
    rules=[
        '-dontwarn java.beans.BeanDescriptor',
        '-dontwarn java.beans.BeanInfo',
        '-dontwarn java.beans.IntrospectionException',
        '-dontwarn java.beans.Introspector',
        '-dontwarn java.beans.PropertyDescriptor',
    ]
    existing=rules_path.read_text(encoding='utf-8') if rules_path.exists() else '# Optional Rhino JavaBeans support is unavailable on Android.\n'
    for rule in rules:
        if rule not in existing.splitlines():
            existing+=rule+'\n'
    rules_path.write_text(existing,encoding='utf-8')

props=android/'gradle.properties'
content=props.read_text(encoding='utf-8') if props.exists() else ''
# Constrain memory on shared GitHub runners (7 GB-class machines).
# The default Flutter scaffold may allocate up to 8 GB to a single JVM,
# while Gradle and Kotlin can each launch separate Java processes.
settings = {
    'android.suppressUnsupportedCompileSdk': '37',
    'org.gradle.jvmargs': '-Xmx3072m -XX:MaxMetaspaceSize=768m -XX:+UseParallelGC',
    'kotlin.daemon.jvmargs': '-Xmx1536m -XX:MaxMetaspaceSize=512m',
    'org.gradle.workers.max': '2',
    'org.gradle.caching': 'true',
}
lines=[line for line in content.splitlines() if line.strip().split('=',1)[0] not in settings]
lines.extend(f'{key}={value}' for key,value in settings.items())
props.write_text('\n'.join(lines)+'\n',encoding='utf-8')

print('Manifest configured:',manifest.relative_to(root))

# Install prebuilt launcher icons (no external Pillow dependency on Windows).
for folder in ('mipmap-mdpi','mipmap-hdpi','mipmap-xhdpi','mipmap-xxhdpi','mipmap-xxxhdpi'):
    source=root/'assets/android_icons'/folder/'ic_launcher.png'
    dest=android/'app/src/main/res'/folder/'ic_launcher.png'
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,dest)
print('ADNANLOAD launcher icons copied.')

# Copy localized native notification controls (pause/resume/cancel).
for folder in ('values', 'values-ar'):
    source=root/'platform_overrides/android/app/src/main/res'/folder/'strings.xml'
    dest=android/'app/src/main/res'/folder/'strings.xml'
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        # Preserve any Flutter/Android strings already generated by the scaffold.
        import xml.etree.ElementTree as ET
        original=ET.parse(dest)
        supplement=ET.parse(source)
        existing={node.attrib.get('name') for node in original.getroot()}
        for node in supplement.getroot():
            if node.attrib.get('name') not in existing:
                original.getroot().append(node)
        original.write(dest, encoding='utf-8', xml_declaration=True)
    else:
        shutil.copy2(source, dest)
print('Native notification translations copied.')

# flutter create may add a default counter-app test that does not apply here.
sample=root/'test/widget_test.dart'
if sample.exists() and ('MyApp(' in sample.read_text(encoding='utf-8') or
                        'Counter increments' in sample.read_text(encoding='utf-8')):
    sample.unlink()
    print('Removed generated counter-app test.')

# background_downloader >=9 requires Kotlin Gradle plugin 2.1.0+.
# Upgrade only an older generated template; keep a newer plugin unchanged.
settings = [android/'settings.gradle.kts', android/'settings.gradle']
for settings_file in settings:
    if not settings_file.exists():
        continue
    text = settings_file.read_text(encoding='utf-8')
    pattern = r'(id\s*\(?\s*[\"\']org\.jetbrains\.kotlin\.android[\"\']\s*\)?\s*version\s*[\"\'])(\d+\.\d+\.\d+)([\"\'])'
    def upgrade_kotlin(match):
        major, minor, *_ = (int(n) for n in match.group(2).split('.'))
        if (major, minor) < (2, 1):
            print('Upgrading old Kotlin plugin to 2.1.0:', settings_file.name)
            return match.group(1) + '2.1.0' + match.group(3)
        return match.group(0)
    updated = re.sub(pattern, upgrade_kotlin, text)
    if updated != text:
        settings_file.write_text(updated, encoding='utf-8')
    break

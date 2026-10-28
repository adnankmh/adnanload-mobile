"""Static packaging checks; not a replacement for flutter analyze/test/build."""
from pathlib import Path
import re, sys, xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
errors=[]

def check(condition,message):
    if not condition: errors.append(message)

required=[
    'pubspec.yaml','lib/main.dart','lib/core/app_strings.dart',
    'lib/core/url_guard.dart','lib/core/theme.dart','lib/core/playlist_rules.dart',
    'lib/services/download_repository.dart','lib/models/download_entry.dart',
    'lib/widgets/new_download_sheet.dart',
    'lib/screens/downloads_page.dart','lib/screens/browser_page.dart',
    'lib/screens/media_page.dart','lib/screens/settings_page.dart',
    'platform_overrides/android/app/src/main/AndroidManifest.xml',
    'BUILD_ANDROID.bat','BUILD_ANDROID.sh','tools/configure_android.py',
    'test/localization_test.dart','test/url_guard_test.dart',
    'test/playlist_rules_test.dart','test/download_entry_playlist_test.dart',
    'assets/adnanload_mark.png',
    'lib/core/playlist_selection.dart','lib/core/media_detector.dart',
    'lib/services/backup_service.dart','lib/services/privacy_lock.dart',
    'lib/services/storage_audit.dart','lib/widgets/privacy_gate.dart',
    'lib/widgets/ultimate_tools_panel.dart','test/ultimate_v14_test.dart',
]
for name in required: check((root/name).is_file(),f'missing {name}')
for p in root.rglob('*'):
    if p.is_file() and p.suffix in {'.dart','.yaml','.yml','.md','.txt','.xml','.py','.sh','.bat'}:
        try: content=p.read_bytes().decode('utf-8')
        except UnicodeError: errors.append(f'not UTF-8: {p.relative_to(root)}'); continue
        if p.suffix=='.bat': check(not content.startswith('\ufeff'),f'BOM in {p}')
try: ET.parse(root/'platform_overrides/android/app/src/main/AndroidManifest.xml')
except Exception as exc: errors.append(f'Invalid Android manifest: {exc}')
source=(root/'lib/core/app_strings.dart').read_text(encoding='utf-8')
ar=source.split('static const Map<String, String> ar = {',1)[1].split('};',1)[0]
en=source.split('static const Map<String, String> en = {',1)[1].split('};',1)[0]
akeys=set(re.findall(r"'([^']+)':",ar));ekeys=set(re.findall(r"'([^']+)':",en))
check(akeys==ekeys,f'localization keys differ: missing EN {akeys-ekeys}, missing AR {ekeys-akeys}')
usage=set()
for p in (root/'lib').rglob('*.dart'):
    text=p.read_text(encoding='utf-8')
    usage.update(re.findall(r"\bt\('([^']+)'\)",text))
    usage.update(re.findall(r"\b(?:strings\.t|s\.t)\('([^']+)'\)",text))
check(usage.issubset(akeys),f'untranslated UI keys: {usage-akeys}')
for p in (root/'assets/android_icons').rglob('ic_launcher.png'):
    check(p.stat().st_size>0,f'empty app icon {p}')
check(len(list((root/'assets/android_icons').rglob('ic_launcher.png')))==5,'wrong number of Android icon densities')
check('android.permission.INTERNET' in (root/'platform_overrides/android/app/src/main/AndroidManifest.xml').read_text(),'no Internet permission')
for secret in ['private_key.pem','keygen.py','ONE_VALID_SERIAL.txt']:
    check(not list(root.rglob(secret)),f'private/admin artifact included {secret}')
if errors:
    print('STATIC VALIDATION FAILED')
    for error in errors:print(' -',error)
    sys.exit(1)
print('STATIC SOURCE CHECKS PASSED')
print('Bilingual key parity:',len(akeys),'keys')
print('Android icon resolutions: 5')
check(not (root/'ios').exists(), 'iOS project should not be included')
if errors: print('ADDITIONAL CHECK FAILED:',errors); sys.exit(1)
print('Android Manifest: XML well-formed')
print('Playlist/source declarations verified (not executed on Android)')
print('Flutter SDK available: not checked by this script')

# V1.5 source-only feature contract checks (NOT runtime tests).
pubspec=(root/'pubspec.yaml').read_text(encoding='utf-8')
check('version: 2.1.0+10' in pubspec, 'V1.6 version missing')
for dep in ('connectivity_plus:', 'battery_plus:', 'background_downloader:'):
    check(dep in pubspec, f'missing policy dependency: {dep}')
for name in ('lib/core/transfer_policy.dart','lib/core/download_metrics.dart',
             'lib/services/crash_journal.dart','test/transfer_policy_test.dart'):
    check((root/name).exists(), f'missing v1.5 source: {name}')
check('RUN_USER_INITIATED_JOBS' in (root/'platform_overrides/android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8'),'UIDT permission missing')
check('UIDTJobService' in (root/'platform_overrides/android/app/src/main/AndroidManifest.xml').read_text(encoding='utf-8'),'UIDT service missing')
check('flutter_secure_storage:' in pubspec, 'secure storage dependency missing')
check('file_picker:' in pubspec, 'backup picker dependency missing')
check((root/'platform_overrides/android/app/src/main/res/values-ar/strings.xml').exists(), 'Arabic notification controls missing')
if errors:
    print('V1.5 FEATURE VALIDATION FAILED:', errors)
    sys.exit(1)
print('V1.5 source feature declarations verified (no device runtime test)')

# V1.6 checks for Android-only best-effort schedules and private-session cleanup.
check('workmanager: ^0.10.10' in pubspec, 'WorkManager dependency missing')
for path in ['lib/services/android_schedule_service.dart', 'test/schedule_v16_test.dart']:
    check((root/path).is_file(), f'missing v1.6 file: {path}')
repository=(root/'lib/services/download_repository.dart').read_text(encoding='utf-8')
browser=(root/'lib/screens/browser_page.dart').read_text(encoding='utf-8')
check('scheduledExternally' in repository and 'AndroidScheduleService.register' in repository, 'OS scheduling not connected to repository')
check('clearLocalStorage' in browser and 'privateSessionWarning' in browser, 'private browsing cleanup missing')
if errors:
    print('V1.6 VALIDATION FAILED:', errors)
    sys.exit(1)
print('V1.6 Android scheduler and ephemeral browsing source contracts verified')

"""V1.7 source contract smoke checks. Does NOT compile Dart or install Android."""
from pathlib import Path
import subprocess, sys
root=Path(__file__).resolve().parents[1]
subprocess.run([sys.executable,str(root/'tools/validate_source.py')],check=True)
def src(name): return (root/name).read_text(encoding='utf-8')
checks={
  'release metadata': 'version: 2.1.0+10' in src('pubspec.yaml'),
  'atomic remove after cancellation': 'Future<void> remove(DownloadEntry item) async' in src('lib/services/download_repository.dart') and 'await cancel(item);' in src('lib/services/download_repository.dart'),
  'guard against canceled media events': "item.status == 'canceled'" in src('lib/services/download_repository.dart'),
  'restore native jobs on startup': 'await _reconcileInterruptedDirect();' in src('lib/services/download_repository.dart'),
  'serialize history writes': '_persistTail' in src('lib/services/download_repository.dart'),
  'keep active history': "...active.map((e) => jsonEncode(e.toJson()))" in src('lib/services/download_repository.dart'),
  'safe local error keys': "item.error = 'mediaFailedTryAgain'" in src('lib/services/download_repository.dart'),
  'filename search': "fileQuery" in src('lib/screens/files_hub_page.dart'),
  'large display navigation': "NavigationRail(" in src('lib/main.dart'),
  'smart playback retained': 'enqueueSelectedPlaylist' in src('lib/services/download_repository.dart'),
  'RTL retained': "TextDirection.rtl" in src('lib/main.dart'),
  'mobile medium only': not (root/'ios').exists(),
  'new focused Dart tests': (root/'test/final_optimization_v17_test.dart').is_file(),
  'build jobs': '--split-per-abi --tree-shake-icons' in src('BUILD_ANDROID.sh'),
}
fail=[key for key,ok in checks.items() if not ok]
for name, ok in checks.items(): print(('PASS' if ok else 'FAIL'),name)
if fail: raise SystemExit(1)
print('V1.7 static contract checks: %d/%d passed (Flutter tests not run)'%(len(checks),len(checks)))

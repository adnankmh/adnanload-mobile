"""V2.0 release source contract, not a Dart compilation/device test."""
from pathlib import Path
import re,subprocess,sys,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
subprocess.run([sys.executable,str(root/'tools/validate_source.py')],check=True)
# Keep v1.7 structural protections until replaced by device tests.
subprocess.run([sys.executable,str(root/'tools/validate_release_v17.py')],check=True)
checks={
  'new version': 'version: 2.1.0+10' in (root/'pubspec.yaml').read_text(),
  'batch parser': (root/'lib/core/batch_links.dart').exists(),
  'batch UI': (root/'lib/widgets/batch_download_sheet.dart').exists(),
  'playlist explorer': (root/'lib/widgets/playlist_explorer_sheet.dart').exists(),
  'converter': (root/'lib/services/media_converter.dart').exists(),
  'converter UI': (root/'lib/widgets/convert_media_sheet.dart').exists(),
  'storage quota': 'storageLimitMb' in (root/'lib/services/download_repository.dart').read_text(),
  'health center': 'downloadHealthSummary' in (root/'lib/services/download_repository.dart').read_text(),
  'stable media update': 'UpdateChannel.stable' in (root/'lib/services/download_repository.dart').read_text(),
  'size report script': (root/'tools/report_build_sizes.py').exists(),
  'no iOS': not (root/'ios').exists(),
  'native manifest valid': ET.parse(root/'platform_overrides/android/app/src/main/AndroidManifest.xml') is not None,
}
for k,v in checks.items():print(('PASS' if v else 'FAIL'),k)
if not all(checks.values()):raise SystemExit(1)
assert 'ffmpeg_kit_flutter_new_full' in (root/'pubspec.yaml').read_text()
assert 'yt_extractor' in (root/'pubspec.yaml').read_text()
print('V2.0 static checks complete — compilation/device execution NOT verified.')

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
command -v flutter >/dev/null || { echo 'Flutter SDK is required.'; exit 1; }
command -v python3 >/dev/null || { echo 'Python 3 is required.'; exit 1; }
if [[ ! -f android/app/build.gradle.kts && ! -f android/app/build.gradle ]]; then
    flutter create --platforms=android --org com.adnanload --project-name adnanload_mobile .
fi
python3 tools/configure_android.py
python3 tools/validate_release_v2.py
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi --tree-shake-icons --target-platform android-arm64
flutter build appbundle --release
python3 tools/report_build_sizes.py
echo 'APKs: build/app/outputs/flutter-apk/'
echo 'AAB: build/app/outputs/bundle/release/'
echo 'Verify signing before distribution: CI artifacts may use a debug signing key.'

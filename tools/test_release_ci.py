"""Regression checks for disk-safe Android CI and version consistency.

This test validates only CI source contracts, not an APK build.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ReleaseWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = (ROOT / ".github/workflows/android-ci.yml").read_text(encoding="utf-8")
        cls.pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
        match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", cls.pubspec, re.M)
        if not match:
            raise AssertionError("Invalid pubspec version")
        cls.version = match.group(1)

    def test_release_artifact_name_matches_pubspec(self):
        self.assertIn(f"ADNANLOAD-v{self.version}-RELEASE-APK", self.workflow)

    def test_pull_requests_do_not_upload_release_artifacts(self):
        # PR checks must be green when analyzer, tests and APK validation pass,
        # even when the separate GitHub Actions release-artifact quota is full.
        self.assertRegex(
            self.workflow,
            r"(?m)^      - name: Upload Release APKs\n"
            r"        if: \$\{\{ github\.event_name != 'pull_request' \}\}\n"
            r"        uses: actions/upload-artifact@v4",
        )
        self.assertIn("          retention-days: 3", self.workflow)

    def test_failure_diagnostics_do_not_consume_pr_artifact_quota(self):
        self.assertRegex(
            self.workflow,
            r"(?m)^      - name: Upload build failure diagnostics \(if any\)\n"
            r"        if: \$\{\{ failure\(\) && github\.event_name != 'pull_request' \}\}\n"
            r"        uses: actions/upload-artifact@v4",
        )
        self.assertIn("          retention-days: 1", self.workflow)

    def test_runner_cleans_only_unrelated_toolchains(self):
        self.assertIn("Reclaim non-Android disk space", self.workflow)
        self.assertIn("/usr/share/dotnet", self.workflow)
        self.assertNotIn("sudo rm -rf -- \"$ANDROID_HOME\"", self.workflow)
        self.assertNotIn("sudo rm -rf -- /usr/local/lib/android/sdk/ndk", self.workflow)

    def test_default_build_limits_native_cpu_architecture(self):
        self.assertIn("--target-platform android-arm64 --split-per-abi", self.workflow)
        self.assertIn("flutter build apk --release --no-pub --split-per-abi", self.workflow)

    def test_apk_validation_supports_both_build_modes(self):
        self.assertIn('apks=(build/app/outputs/flutter-apk/*.apk)', self.workflow)
        self.assertIn("unzip -tqq \"$apk\"", self.workflow)
        self.assertIn("com.adnanload.adnanload_mobile", self.workflow)
        self.assertIn("apk-contents.txt", self.workflow)
        self.assertIn("tools/report_apk_size.py", self.workflow)
        self.assertIn("--limit-mb 50", self.workflow)


if __name__ == "__main__":
    unittest.main(verbosity=2)

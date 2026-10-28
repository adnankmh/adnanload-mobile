"""APK size and split-ABI contract unit tests; no Android SDK needed."""
import io
from pathlib import Path
import tempfile
import unittest
import zipfile
from report_apk_size import inspect_apk


class ApkSizeReportTests(unittest.TestCase):
    def test_valid_arm64_split(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / "app-arm64-v8a-release.apk"
            with zipfile.ZipFile(apk, "w", compression=zipfile.ZIP_DEFLATED) as z:
                z.writestr("lib/arm64-v8a/libflutter.so", b"x" * 4096)
                z.writestr("classes.dex", b"dex")
            report = inspect_apk(apk)
            self.assertEqual(report["expected_abi"], "arm64-v8a")
            self.assertGreater(report["bytes"], 0)

    def test_rejects_fat_apk_masquerading_as_arm64_split(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / "app-arm64-v8a-release.apk"
            with zipfile.ZipFile(apk, "w") as z:
                z.writestr("lib/arm64-v8a/libflutter.so", b"native")
                z.writestr("lib/x86_64/libother.so", b"not for arm64")
            with self.assertRaisesRegex(ValueError, "incompatible native ABI"):
                inspect_apk(apk)

    def test_rejects_split_without_native_engine(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / "app-armeabi-v7a-release.apk"
            with zipfile.ZipFile(apk, "w") as z:
                z.writestr("classes.dex", b"dex")
            with self.assertRaisesRegex(ValueError, "no armeabi-v7a native libraries"):
                inspect_apk(apk)


if __name__ == "__main__":
    unittest.main(verbosity=2)

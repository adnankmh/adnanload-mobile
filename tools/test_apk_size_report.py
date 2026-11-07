"""APK size and split-ABI contract unit tests; no Android SDK needed."""
import io
import warnings
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


    def test_reports_largest_non_native_assets_separately(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / "app-arm64-v8a-release.apk"
            with zipfile.ZipFile(apk, "w", compression=zipfile.ZIP_STORED) as z:
                z.writestr("lib/arm64-v8a/libflutter.so", b"n" * 250)
                z.writestr("assets/flutter_assets/engine.dat", b"a" * 150)
                z.writestr("classes.dex", b"d" * 80)
                z.writestr("assets/flutter_assets/AssetManifest.bin", b"m" * 30)
            report = inspect_apk(apk)
            self.assertEqual(
                [item["path"] for item in report["top_non_native_files"]],
                ["assets/flutter_assets/engine.dat", "classes.dex",
                 "assets/flutter_assets/AssetManifest.bin"],
            )
            self.assertEqual(len(report["top_native_files"]), 1)
            self.assertEqual(report["top_native_files"][0]["path"],
                             "lib/arm64-v8a/libflutter.so")

    def test_rejects_duplicate_archive_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / "app-release.apk"
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                with zipfile.ZipFile(apk, "w") as z:
                    z.writestr("classes.dex", b"first")
                    z.writestr("classes.dex", b"second")
            with self.assertRaisesRegex(ValueError, "Duplicate APK entry"):
                inspect_apk(apk)

    def test_rejects_unsafe_archive_paths(self):
        for path in ("../classes.dex", "/classes.dex", "assets/../classes.dex",
                     "assets\\classes.dex", "assets//classes.dex"):
            with self.subTest(path=path), tempfile.TemporaryDirectory() as tmp:
                apk = Path(tmp) / "app-release.apk"
                with zipfile.ZipFile(apk, "w") as z:
                    z.writestr(path, b"x")
                with self.assertRaisesRegex(ValueError, "Unsafe APK entry path"):
                    inspect_apk(apk)

    def test_accepts_normal_directory_records(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / "app-release.apk"
            with zipfile.ZipFile(apk, "w") as z:
                z.writestr("assets/", b"")
                z.writestr("assets/data.bin", b"data")
            report = inspect_apk(apk)
            self.assertEqual(
                [item["path"] for item in report["top_non_native_files"]],
                ["assets/data.bin"],
            )

    def test_rejects_unsafe_directory_records(self):
        for path in ("../", "assets/../", "assets//", "/assets/",
                     "C:/assets/"):
            with self.subTest(path=path), tempfile.TemporaryDirectory() as tmp:
                apk = Path(tmp) / "app-release.apk"
                with zipfile.ZipFile(apk, "w") as z:
                    z.writestr(path, b"")
                with self.assertRaisesRegex(ValueError, "Unsafe APK entry path"):
                    inspect_apk(apk)

    def test_rejects_control_characters_and_drive_prefixes(self):
        for path in ("C:/classes.dex", "assets/a\n.txt",
                     "assets/\u202ereversed.dex", "assets/\u200bhidden.bin"):
            with self.subTest(path=path), tempfile.TemporaryDirectory() as tmp:
                apk = Path(tmp) / "app-release.apk"
                with zipfile.ZipFile(apk, "w") as z:
                    z.writestr(path, b"x")
                with self.assertRaisesRegex(ValueError, "Unsafe APK entry path"):
                    inspect_apk(apk)

    def test_equal_sized_entries_sort_by_filename(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / "app-arm64-v8a-release.apk"
            with zipfile.ZipFile(apk, "w", compression=zipfile.ZIP_STORED) as z:
                z.writestr("lib/arm64-v8a/z.so", b"n" * 40)
                z.writestr("lib/arm64-v8a/a.so", b"n" * 40)
                z.writestr("assets/z.bin", b"a" * 20)
                z.writestr("assets/a.bin", b"a" * 20)
            report = inspect_apk(apk)
            self.assertEqual(
                [item["path"] for item in report["top_native_files"]],
                ["lib/arm64-v8a/a.so", "lib/arm64-v8a/z.so"],
            )
            self.assertEqual(
                [item["path"] for item in report["top_non_native_files"]],
                ["assets/a.bin", "assets/z.bin"],
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)

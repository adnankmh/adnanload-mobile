"""Unit tests for bounded APK build retries (no Flutter SDK required)."""
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock

from retry_apk_build import run_build


class RetryApkBuildTests(unittest.TestCase):
    def run_case(self, outputs):
        with tempfile.TemporaryDirectory() as directory:
            runner = Mock(side_effect=[subprocess.CompletedProcess(["flutter"], code, output)
                                       for code, output in outputs])
            sleeper = Mock()
            path = Path(directory) / "build.log"
            code = run_build(["flutter", "build", "apk"], path, runner=runner,
                             sleep=sleeper)
            return code, runner.call_count, sleeper.call_args_list, path.read_text()

    def test_retries_429_then_succeeds(self):
        code, count, waits, log = self.run_case([
            (1, "Received status code 429 from server: Too Many Requests"),
            (0, "Built app-arm64-v8a-release.apk")])
        self.assertEqual((code, count), (0, 2))
        self.assertEqual(waits[0].args, (20,))
        self.assertIn("Built app-arm64", log)

    def test_non_transient_error_is_not_retried(self):
        code, count, waits, _ = self.run_case([(2, "Compilation failed")])
        self.assertEqual((code, count, len(waits)), (2, 1, 0))

    def test_exhausted_retries_preserves_failure(self):
        code, count, waits, _ = self.run_case([(1, "HTTP 429")] * 3)
        self.assertEqual((code, count), (1, 3))
        self.assertEqual([call.args[0] for call in waits], [20, 40])

    def test_invalid_attempts(self):
        with self.assertRaises(ValueError):
            run_build(["flutter"], "unused.log", attempts=0)


if __name__ == "__main__":
    unittest.main()

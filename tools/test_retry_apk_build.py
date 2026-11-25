"""Unit and real-subprocess tests for bounded APK build retries."""
import contextlib
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, Mock

from retry_apk_build import run_build, retry_delay


class RetryApkBuildTests(unittest.TestCase):
    def run_case(self, outputs, attempts=3):
        with tempfile.TemporaryDirectory() as directory:
            processes = []
            for code, output in outputs:
                process = MagicMock()
                process.__enter__.return_value = process
                process.stdout = io.StringIO(output)
                process.wait.return_value = code
                processes.append(process)
            popen = Mock(side_effect=processes)
            sleeper = Mock()
            path = Path(directory) / "build.log"
            console = io.StringIO()
            with contextlib.redirect_stdout(console):
                code = run_build(["flutter", "build", "apk"], path,
                                 popen=popen, sleep=sleeper, attempts=attempts)
            log = path.read_text(encoding="utf-8")
            self.assertEqual(log, console.getvalue())
            self.assertEqual(popen.call_args.kwargs["stderr"], subprocess.STDOUT)
            return code, popen.call_count, sleeper.call_args_list, log

    def test_retries_429_then_succeeds(self):
        code, count, waits, log = self.run_case([
            (1, "Received status code 429 from server: Too Many Requests\n"),
            (0, "Built app-arm64-v8a-release.apk\n")])
        self.assertEqual((code, count), (0, 2))
        self.assertEqual(waits[0].args, (120,))
        self.assertIn("Built app-arm64", log)
        self.assertIn("retrying in 120s", log)

    def test_non_transient_error_is_not_retried(self):
        code, count, waits, _ = self.run_case([(2, "Compilation failed\n")])
        self.assertEqual((code, count, len(waits)), (2, 1, 0))

    def test_exhausted_retries_preserves_failure(self):
        code, count, waits, _ = self.run_case([(7, "HTTP 429\n")] * 3)
        self.assertEqual((code, count), (7, 3))
        self.assertEqual([call.args[0] for call in waits], [120, 240])

    def test_invalid_attempts(self):
        with self.assertRaises(ValueError):
            run_build(["flutter"], "unused.log", attempts=0)

    def test_previous_attempt_does_not_mark_next_failure_transient(self):
        code, count, waits, _ = self.run_case([
            (1, "HTTP 429\n"), (9, "Compiler error\n")])
        self.assertEqual((code, count, len(waits)), (9, 2, 1))

    def test_ambiguous_text_is_not_rate_limit(self):
        code, count, waits, _ = self.run_case([
            (4, "Too Many Requests is a test label; HTTP 4290\n")])
        self.assertEqual((code, count, len(waits)), (4, 1, 0))

    def test_success_never_retries(self):
        code, count, waits, _ = self.run_case([(0, "HTTP 429 recovered\n")])
        self.assertEqual((code, count, len(waits)), (0, 1, 0))

    def test_delay_is_bounded(self):
        self.assertEqual([retry_delay(n) for n in (1, 2, 3, 1000)],
                         [120, 240, 300, 300])

    def test_stream_is_visible_before_process_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "build.log"
            process = MagicMock()
            process.__enter__.return_value = process
            console = io.StringIO()

            def lines():
                yield "first line\n"
                self.assertIn("first line", path.read_text(encoding="utf-8"))
                self.assertIn("first line", console.getvalue())
                yield "second line\n"

            process.stdout = lines()
            process.wait.return_value = 0
            with contextlib.redirect_stdout(console):
                self.assertEqual(run_build(["flutter"], path,
                                 popen=Mock(return_value=process)), 0)
            self.assertIn("second line", path.read_text(encoding="utf-8"))

    def test_real_subprocess_streams_stdout_stderr_and_exit_code(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "build.log"
            command = [sys.executable, "-u", "-c",
                       "import sys; print('stdout'); "
                       "print('stderr', file=sys.stderr); sys.exit(6)"]
            sleeper = Mock()
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(run_build(command, path, sleep=sleeper), 6)
            log = path.read_text(encoding="utf-8")
            self.assertIn("stdout", log)
            self.assertIn("stderr", log)
            sleeper.assert_not_called()


if __name__ == "__main__":
    unittest.main()

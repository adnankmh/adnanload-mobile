"""Bounded retry for transient Maven/Gradle HTTP 429 during APK builds."""
import argparse
import subprocess
import sys
import time
from pathlib import Path

RETRY_MARKERS = ("Received status code 429", "HTTP 429", "Too Many Requests")


def run_build(command, log_path, *, attempts=3, sleep=time.sleep, runner=subprocess.run):
    if attempts < 1:
        raise ValueError("attempts must be positive")
    path = Path(log_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(1, attempts + 1):
        with path.open("a", encoding="utf-8") as output:
            output.write(f"\\n--- APK build attempt {attempt}/{attempts} ---\\n")
            output.flush()
            result = runner(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, errors="replace", check=False)
            output.write(result.stdout or "")
        sys.stdout.write(result.stdout or "")
        if result.returncode == 0:
            return 0
        transient = any(marker.lower() in (result.stdout or "").lower()
                        for marker in RETRY_MARKERS)
        if not transient or attempt == attempts:
            return result.returncode or 1
        delay = min(20 * (2 ** (attempt - 1)), 80)
        print(f"Gradle HTTP 429 detected; retrying in {delay}s ({attempt}/{attempts}).",
              flush=True)
        sleep(delay)
    return 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True)
    parser.add_argument("--attempts", type=int, default=3)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("build command required")
    return run_build(command, args.log, attempts=args.attempts)


if __name__ == "__main__":
    sys.exit(main())

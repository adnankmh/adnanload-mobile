"""Stream APK build logs and back off on explicit Maven/Gradle HTTP 429."""
import argparse
import re
import subprocess
import sys
import time
from pathlib import Path

RATE_LIMIT = re.compile(r"\b(?:received status code|http(?:/\d(?:\.\d)?)?)\s+429\b", re.I)


def retry_delay(attempt):
    """Allow shared Maven rate limits to cool down without unbounded waits."""
    return 120 if attempt == 1 else 240 if attempt == 2 else 300


def run_build(command, log_path, *, attempts=3, sleep=time.sleep,
              popen=subprocess.Popen):
    if attempts < 1:
        raise ValueError("attempts must be positive")
    path = Path(log_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as output:
        def emit(message):
            output.write(message)
            output.flush()
            sys.stdout.write(message)
            sys.stdout.flush()

        for attempt in range(1, attempts + 1):
            emit(f"\n--- APK build attempt {attempt}/{attempts} ---\n")
            transient = False
            # Merge streams in order, and never retain the whole build output.
            with popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True, encoding="utf-8", errors="replace",
                       bufsize=1) as process:
                for line in process.stdout:
                    emit(line)
                    if RATE_LIMIT.search(line):
                        transient = True
                code = process.wait()
            if code == 0:
                return 0
            if not transient or attempt == attempts:
                return code
            delay = retry_delay(attempt)
            emit(f"\nGradle HTTP 429 detected; retrying in {delay}s "
                 f"({attempt}/{attempts}).\n")
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

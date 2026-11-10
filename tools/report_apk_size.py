"""Report actual APK footprint and enforce ABI isolation for split APKs.

The size target is advisory: do not discard a valid APK while optimizing the
large embedded yt-dlp/Python and FFmpeg native engines. Values are decimal MB.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
import zipfile
from collections import defaultdict
from pathlib import Path


def inspect_apk(apk: Path) -> dict:
    if not apk.is_file():
        raise FileNotFoundError(apk)
    by_abi = defaultdict(int)
    by_prefix = defaultdict(int)
    native_files = []
    non_native_files = []
    seen_entries = set()
    with zipfile.ZipFile(apk) as archive:
        bad = archive.testzip()
        if bad:
            raise ValueError(f"Corrupted APK entry: {bad}")
        for entry in archive.infolist():
            # Validate directory records too; a malicious "../" directory
            # must not bypass the archive integrity checks.
            name = entry.filename
            path = name[:-1] if entry.is_dir() else name
            parts = path.split("/")
            if (not path or path.startswith("/") or "\\" in path
                    or re.match(r"^[A-Za-z]:", path)
                    or any(part in ("", ".", "..") for part in parts)
                    or any(unicodedata.category(ch) in ("Cc", "Cf")
                           for ch in path)):
                raise ValueError(f"Unsafe APK entry path: {name}")
            if name in seen_entries:
                raise ValueError(f"Duplicate APK entry: {name}")
            seen_entries.add(name)
            if entry.is_dir():
                continue
            if len(parts) >= 3 and parts[0] == "lib":
                by_abi[parts[1]] += entry.compress_size
                native_files.append((entry.filename, entry.compress_size))
            else:
                by_prefix[parts[0]] += entry.compress_size
                non_native_files.append((entry.filename, entry.compress_size))

    name_match = re.fullmatch(
        r"app-(arm64-v8a|armeabi-v7a|x86_64)-release\.apk", apk.name
    )
    expected_abi = name_match.group(1) if name_match else None
    if expected_abi:
        unexpected = sorted(set(by_abi) - {expected_abi})
        if unexpected:
            raise ValueError(
                f"{apk.name} contains incompatible native ABI libraries: "
                + ", ".join(unexpected)
            )
        if not by_abi.get(expected_abi):
            raise ValueError(f"{apk.name} has no {expected_abi} native libraries")

    size = apk.stat().st_size
    return {
        "name": apk.name,
        "bytes": size,
        "mb": round(size / 1_000_000, 2),
        "mib": round(size / (1024 * 1024), 2),
        "expected_abi": expected_abi,
        "native_compressed_mb_by_abi": {
            key: round(value / 1_000_000, 2) for key, value in sorted(by_abi.items())
        },
        "other_compressed_mb": {
            key: round(value / 1_000_000, 2) for key, value in sorted(by_prefix.items())
        },
        "top_native_files": [
            {"path": filename, "compressed_mb": round(byte_count / 1_000_000, 2)}
            for filename, byte_count in sorted(
                native_files, key=lambda row: (-row[1], row[0])
            )[:18]
        ],
        "top_non_native_files": [
            {"path": filename, "compressed_mb": round(byte_count / 1_000_000, 2)}
            for filename, byte_count in sorted(
                non_native_files, key=lambda row: (-row[1], row[0])
            )[:18]
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("apks", nargs="+", type=Path)
    parser.add_argument("--out-dir", type=Path, default=Path("build/release-checksums"))
    parser.add_argument("--limit-mb", type=float, default=50)
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    results = []
    for path in args.apks:
        report = inspect_apk(path)
        results.append(report)
        print(f"{report['name']}: {report['mb']} MB ({report['mib']} MiB)")
        for entry in report["top_native_files"][:8]:
            print(f"  {entry['compressed_mb']} MB  {entry['path']}")
        for entry in report["top_non_native_files"][:8]:
            print(f"  {entry['compressed_mb']} MB  {entry['path']}")
        if report["mb"] > args.limit_mb:
            print(
                f"::warning title=APK size target not yet met::{report['name']} "
                f"is {report['mb']} MB; target <= {args.limit_mb} MB. "
                "Reducing yt-dlp/Python/FFmpeg would require a separate "
                "verified runtime-delivery design. No features have been removed."
            )
    document = {"limit_mb": args.limit_mb, "apks": results}
    (args.out_dir / "APK_SIZE_REPORT.json").write_text(
        json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    with (args.out_dir / "APK_SIZE_REPORT.txt").open("w", encoding="utf-8") as out:
        for report in results:
            out.write(
                f"{report['name']}: {report['mb']} MB ({report['mib']} MiB)\n"
            )
            out.write("Largest native files:\n")
            for entry in report["top_native_files"]:
                out.write(f"  {entry['compressed_mb']} MB {entry['path']}\n")
            out.write("Largest non-native files:\n")
            for entry in report["top_non_native_files"]:
                out.write(f"  {entry['compressed_mb']} MB {entry['path']}\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, zipfile.BadZipFile) as exc:
        print(f"::error title=APK inspection failed::{exc}")
        sys.exit(1)

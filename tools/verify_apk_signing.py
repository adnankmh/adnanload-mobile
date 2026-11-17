"""Verify release APKs with the Android SDK and record public signer fingerprints."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys


SIGNER_FINGERPRINT = re.compile(
    r"^Signer(?: #\d+| \(minSdkVersion=\d+(?: \(dev release=true\))?, maxSdkVersion=\d+\))"
    r" certificate SHA-256 digest:[ \t]*([0-9a-f:]+)[ \t]*$",
    re.I | re.M,
)


def normalize_fingerprint(value):
    digest = value.strip().replace(":", "").lower()
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("The required signer fingerprint must be a SHA-256 certificate digest.")
    return digest


def apk_signers(apksigner, apk):
    result = subprocess.run(
        [str(apksigner), "verify", "--print-certs", str(apk)],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        raise ValueError(f"Android signature verification failed for {apk.name}.\n{result.stderr.strip()}")
    fingerprints = frozenset(
        normalize_fingerprint(value) for value in SIGNER_FINGERPRINT.findall(result.stdout)
    )
    if not fingerprints:
        digest_labels = [line.partition(" digest:")[0] for line in result.stdout.splitlines()
                         if "certificate SHA-256 digest:" in line]
        details = f" Reported labels: {', '.join(digest_labels)}." if digest_labels else ""
        raise ValueError(f"No signing certificate reported for {apk.name}.{details}")
    return fingerprints


def verify_apks(apksigner, apks, expected=""):
    required = normalize_fingerprint(expected) if expected.strip() else None
    certificates = {}
    first = None
    for apk in apks:
        signers = apk_signers(apksigner, apk)
        if required and signers != {required}:
            raise ValueError(f"{apk.name} does not match the required signing certificate.")
        if first is not None and signers != first:
            raise ValueError(f"{apk.name} has a different signer from the other APKs in this build.")
        first = signers
        certificates[apk.name] = sorted(signers)
    return certificates


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apksigner", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("apks", nargs="+", type=Path)
    args = parser.parse_args()
    try:
        certificates = verify_apks(
            args.apksigner, args.apks, os.environ.get("ADNANLOAD_EXPECTED_SIGNING_CERT_SHA256", "")
        )
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(
            "".join(
                f"{fingerprint}  {name}\n"
                for name, signers in certificates.items() for fingerprint in signers
            ),
            encoding="ascii",
        )
    except (ValueError, OSError) as error:
        print(error, file=sys.stderr)
        return 1
    print(f"Verified Android signatures for {len(certificates)} APK(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

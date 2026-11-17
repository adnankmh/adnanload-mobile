from pathlib import Path
from subprocess import CompletedProcess
import unittest
from unittest.mock import patch

from verify_apk_signing import verify_apks


ARM = Path("app-arm64-v8a-release.apk")
X86 = Path("app-x86_64-release.apk")
CERT = "af" * 32
OTHER_CERT = "d1" * 32


def signed_response(fingerprint):
    output = f"Verified\nSigner #1 certificate SHA-256 digest: {fingerprint}\n"
    return CompletedProcess([], 0, output, "")


class ApkSigningTests(unittest.TestCase):
    def test_records_matching_split_signers_and_accepts_colon_notation(self):
        pin = ":".join(["AF"] * 32)
        with patch("verify_apk_signing.subprocess.run", return_value=signed_response(CERT)) as run:
            self.assertEqual(
                verify_apks("apksigner", [ARM, X86], pin),
                {ARM.name: [CERT], X86.name: [CERT]},
            )
        self.assertEqual(run.call_args.args[0], ["apksigner", "verify", "--print-certs", str(X86)])

    def test_different_signer_cannot_pass_the_pin_or_join_matching_splits(self):
        with patch("verify_apk_signing.subprocess.run", return_value=signed_response(OTHER_CERT)):
            with self.assertRaisesRegex(ValueError, "required signing certificate"):
                verify_apks("apksigner", [ARM], CERT)
        with patch("verify_apk_signing.subprocess.run",
                   side_effect=[signed_response(CERT), signed_response(OTHER_CERT)]):
            with self.assertRaisesRegex(ValueError, "different signer"):
                verify_apks("apksigner", [ARM, X86])

    def test_invalid_or_unverifiable_apk_fails(self):
        with patch("verify_apk_signing.subprocess.run",
                   return_value=CompletedProcess([], 1, "", "DOES NOT VERIFY")):
            with self.assertRaisesRegex(ValueError, "DOES NOT VERIFY"):
                verify_apks("apksigner", [ARM])
        with patch("verify_apk_signing.subprocess.run", return_value=CompletedProcess([], 0, "", "")):
            with self.assertRaisesRegex(ValueError, "No signing certificate"):
                verify_apks("apksigner", [ARM])


if __name__ == "__main__":
    unittest.main(verbosity=2)

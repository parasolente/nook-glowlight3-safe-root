import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from install_verified_apk import install


class VerifiedInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.apk = Path(self.temp.name) / "test.apk"
        self.apk.write_bytes(b"test payload")
        self.digest = hashlib.sha256(self.apk.read_bytes()).hexdigest()

    @patch("install_verified_apk.adb")
    def test_bad_device_hash_never_runs_package_manager(self, adb):
        adb.side_effect = [b"BNRV520\r\n", b"", b"0" * 64 + b"  file\r\n"]
        with self.assertRaises(ValueError):
            install("test-device", self.apk, self.digest, "org.example.reader", "/test/busybox")
        self.assertFalse(any("pm install" in str(call) for call in adb.call_args_list))

    @patch("install_verified_apk.adb")
    def test_zero_exit_without_success_is_not_an_installation(self, adb):
        adb.side_effect = [b"BNRV520\r\n", b"", self.digest.encode() + b"  file\r\n",
                           b"Failure [INSTALL_FAILED_INVALID_APK]\r\n"]
        with self.assertRaises(RuntimeError):
            install("test-device", self.apk, self.digest, "org.example.reader", "/test/busybox")

    @patch("install_verified_apk.adb")
    def test_success_requires_expected_package(self, adb):
        adb.side_effect = [b"BNRV520\r\n", b"", self.digest.encode() + b"  file\r\n",
                           b"Success\r\n", b"package:org.example.reader\r\n", b""]
        self.assertEqual(install("test-device", self.apk, self.digest,
                                "org.example.reader", "/test/busybox"), "org.example.reader")


if __name__ == "__main__":
    unittest.main()

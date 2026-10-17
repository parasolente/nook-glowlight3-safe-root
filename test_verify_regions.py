import gzip
import hashlib
from pathlib import Path
import tempfile
import unittest

from verify_regions import verify


class RegionVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.raw = bytes(range(256)) * 32769
        self.image = self.root / "test.gz"
        self.image.write_bytes(gzip.compress(self.raw))
        self.region = {"name": "system", "offset": 4194291, "size": 100,
                       "sha256": hashlib.sha256(self.raw[4194291:4194391]).hexdigest()}
        self.layout = {"expected_raw_bytes": len(self.raw), "regions": [self.region]}

    def test_region_crossing_read_boundary_is_extracted_and_hashed(self):
        output = self.root / "verified"
        result = verify(self.image, self.layout, output)
        self.assertEqual(result["raw_sha256"], hashlib.sha256(self.raw).hexdigest())
        self.assertEqual((output / "system.img").read_bytes(), self.raw[4194291:4194391])

    def test_mismatch_keeps_partial_extension(self):
        self.region["sha256"] = "0" * 64
        output = self.root / "verified"
        with self.assertRaises(ValueError):
            verify(self.image, self.layout, output)
        self.assertTrue((output / "system.img.partial").exists())
        self.assertFalse((output / "system.img").exists())

    def test_bad_boundaries_and_path_traversal_are_rejected(self):
        for key, value in (("offset", -1), ("size", 0), ("size", len(self.raw) + 1), ("name", "../outside")):
            original = self.region[key]
            self.region[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                verify(self.image, self.layout)
            self.region[key] = original

    def test_existing_extraction_directory_is_rejected(self):
        with self.assertRaises(FileExistsError):
            verify(self.image, self.layout, self.root)


if __name__ == "__main__":
    unittest.main()

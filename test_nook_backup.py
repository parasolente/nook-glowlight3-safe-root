import gzip
import hashlib
import io
import unittest
import zlib

from nook_backup import consume_gzip


class GzipIntegrityTests(unittest.TestCase):
    def test_binary_bytes_and_large_zero_runs_round_trip(self):
        raw = bytes(range(256)) * 128 + bytes(10 * 1024 * 1024)
        compressed = gzip.compress(raw)
        saved = io.BytesIO()
        result = consume_gzip(io.BytesIO(compressed), saved, len(raw))
        self.assertEqual(saved.getvalue(), compressed)
        self.assertEqual(result["raw_sha256"], hashlib.sha256(raw).hexdigest())
        self.assertEqual(result["gzip_sha256"], hashlib.sha256(compressed).hexdigest())

    def test_truncation_is_rejected(self):
        with self.assertRaises(ValueError):
            consume_gzip(io.BytesIO(gzip.compress(b"abc")[:-4]), io.BytesIO(), 3)

    def test_corrupt_crc_is_rejected(self):
        compressed = bytearray(gzip.compress(b"abc"))
        compressed[-8] ^= 1
        with self.assertRaises(zlib.error):
            consume_gzip(io.BytesIO(compressed), io.BytesIO(), 3)

    def test_unexpected_size_is_rejected_in_both_directions(self):
        for size in (2, 4):
            with self.subTest(size=size), self.assertRaises(ValueError):
                consume_gzip(io.BytesIO(gzip.compress(b"abc")), io.BytesIO(), size)

    def test_trailing_data_and_extra_members_are_rejected(self):
        for tail in (b"unexpected shell output", gzip.compress(b"second member")):
            with self.subTest(tail=tail), self.assertRaises(ValueError):
                consume_gzip(io.BytesIO(gzip.compress(b"abc") + tail), io.BytesIO(), 3)


if __name__ == "__main__":
    unittest.main()

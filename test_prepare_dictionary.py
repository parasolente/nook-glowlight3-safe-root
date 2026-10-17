from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

from prepare_dictionary import prepare, validate


class DictionaryValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ifo = self.root / "sample.ifo"
        self.index = b"book\0" + struct.pack(">II", 0, 5)
        self.ifo.write_text("StarDict's dict ifo file\nversion=2.4.2\nbookname=Test\nwordcount=1\nidxfilesize=13\n")
        (self.root / "sample.idx").write_bytes(self.index)
        (self.root / "sample.dict").write_bytes(b"libro")

    def test_valid_dictionary(self):
        self.assertEqual(validate(self.ifo)["wordcount"], 1)

    def test_index_beyond_data_is_rejected(self):
        (self.root / "sample.idx").write_bytes(b"book\0" + struct.pack(">II", 0, 99))
        with self.assertRaises(ValueError):
            validate(self.ifo)

    def test_truncated_index_is_rejected(self):
        (self.root / "sample.idx").write_bytes(self.index[:-1])
        with self.assertRaises(ValueError):
            validate(self.ifo)

    def test_zip_path_traversal_is_rejected_before_extraction(self):
        archive = self.root / "bad.zip"
        with zipfile.ZipFile(archive, "w") as output:
            output.writestr("../outside", "bad")
        with self.assertRaises(ValueError):
            prepare(archive, self.root / "output")
        self.assertFalse((self.root / "output").exists())


if __name__ == "__main__":
    unittest.main()

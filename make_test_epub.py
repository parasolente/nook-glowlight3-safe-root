#!/usr/bin/env python3
"""Build a deterministic, original EPUB for unauthenticated download testing."""
import argparse
import zipfile
from pathlib import Path

FILES = {
    "mimetype": "application/epub+zip",
    "META-INF/container.xml": '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    "content.opf": '<?xml version="1.0"?><package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">urn:nookarchive:download-test</dc:identifier><dc:title>NOOK Archive Download Test</dc:title><dc:creator>NOOK Archive project</dc:creator><dc:language>en</dc:language></metadata><manifest><item id="text" href="text.xhtml" media-type="application/xhtml+xml"/><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/></manifest><spine toc="ncx"><itemref idref="text"/></spine></package>',
    "toc.ncx": '<?xml version="1.0"?><ncx version="2005-1" xmlns="http://www.daisy.org/z3986/2005/ncx/"><head><meta name="dtb:uid" content="urn:nookarchive:download-test"/></head><docTitle><text>NOOK Archive Download Test</text></docTitle><navMap><navPoint id="test" playOrder="1"><navLabel><text>Download test</text></navLabel><content src="text.xhtml"/></navPoint></navMap></ncx>',
    "text.xhtml": '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>Download test</title></head><body><h1>Download test completed</h1><p>This original test book was downloaded using the KOReader integration.</p><p>No account token or membership download was used.</p><p>The file checksum matched before the book was saved.</p><p>Dictionary words: book. Palabra para el diccionario: libro.</p></body></html>',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    with args.output.open("xb") as output, zipfile.ZipFile(output, "w") as epub:
        for name, content in FILES.items():
            entry = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_STORED if name == "mimetype" else zipfile.ZIP_DEFLATED
            epub.writestr(entry, content.encode("utf-8"))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Extract a StarDict ZIP locally and validate its index before installation."""

import argparse
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import stat
import struct
import zipfile


def validate(ifo):
    ifo = Path(ifo)
    lines = ifo.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "StarDict's dict ifo file":
        raise ValueError("Not a StarDict metadata file")
    metadata = dict(line.split("=", 1) for line in lines[1:] if "=" in line)
    base = ifo.with_suffix("")
    idx_path = Path(str(base) + ".idx")
    index = idx_path.read_bytes()
    if len(index) != int(metadata["idxfilesize"]):
        raise ValueError("idxfilesize does not match the index")
    dict_path = Path(str(base) + ".dict")
    if dict_path.exists():
        dictionary_size = dict_path.stat().st_size
    else:
        dict_path = Path(str(base) + ".dict.dz")
        with gzip.open(dict_path, "rb") as source:
            dictionary_size = 0
            while data := source.read(4 * 1024 * 1024):
                dictionary_size += len(data)
    bits = int(metadata.get("idxoffsetbits", "32"))
    if bits not in (32, 64):
        raise ValueError("Unsupported index offset width")
    layout = ">II" if bits == 32 else ">QI"
    width = struct.calcsize(layout)
    count = position = 0
    while position < len(index):
        end = index.find(b"\0", position)
        if end <= position or end + 1 + width > len(index):
            raise ValueError("Truncated or empty index entry")
        index[position:end].decode("utf-8")
        offset, size = struct.unpack_from(layout, index, end + 1)
        if offset + size > dictionary_size:
            raise ValueError("Index entry points beyond the dictionary data")
        position = end + 1 + width
        count += 1
    if count != int(metadata["wordcount"]):
        raise ValueError("wordcount does not match the index")
    synonyms = 0
    syn_path = Path(str(base) + ".syn")
    if syn_path.exists():
        syn = syn_path.read_bytes()
        position = 0
        while position < len(syn):
            end = syn.find(b"\0", position)
            if end <= position or end + 5 > len(syn):
                raise ValueError("Truncated synonym entry")
            syn[position:end].decode("utf-8")
            entry, = struct.unpack_from(">I", syn, end + 1)
            if entry >= count:
                raise ValueError("Synonym points beyond the word index")
            position = end + 5
            synonyms += 1
    if synonyms != int(metadata.get("synwordcount", "0")):
        raise ValueError("synwordcount does not match the synonym file")
    return {"bookname": metadata.get("bookname"), "wordcount": count,
            "synwordcount": synonyms, "dictionary_bytes": dictionary_size,
            "metadata_file": ifo.name}


def prepare(archive, destination):
    destination = Path(destination)
    with zipfile.ZipFile(archive) as source:
        for info in source.infolist():
            path = PurePosixPath(info.filename)
            mode = info.external_attr >> 16
            if path.is_absolute() or ".." in path.parts or "\\" in info.filename:
                raise ValueError("Unsafe ZIP path")
            if stat.S_ISLNK(mode):
                raise ValueError("ZIP symbolic links are not accepted")
        destination.mkdir(parents=True, exist_ok=False)
        source.extractall(destination)
    dictionaries = [validate(ifo) for ifo in destination.rglob("*.ifo")]
    if not dictionaries:
        raise ValueError("Archive contains no StarDict dictionary")
    files = {}
    for path in destination.rglob("*"):
        if path.is_file():
            files[str(path.relative_to(destination))] = {
                "bytes": path.stat().st_size,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
    return {"archive_sha256": hashlib.sha256(Path(archive).read_bytes()).hexdigest(),
            "dictionaries": dictionaries, "files": files}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path, help="New local directory")
    args = parser.parse_args()
    print(json.dumps(prepare(args.archive, args.destination), indent=2))


if __name__ == "__main__":
    main()

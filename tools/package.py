"""Build or verify the installable addon ZIP against the current sources."""
from pathlib import Path
import argparse
import zipfile

root = Path(__file__).resolve().parents[1]
source = root / "VoidMarkNexus"
archive = root / "dist" / "VoidMarkNexus.zip"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--check", action="store_true")
args = parser.parse_args()
files = {p.relative_to(root).as_posix(): p for p in source.rglob("*") if p.is_file()}
if not args.check:
    archive.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as output:
        for name, path in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            output.writestr(info, path.read_bytes())
with zipfile.ZipFile(archive) as output:
    assert output.testzip() is None, "ZIP integrity failure"
    assert len(output.namelist()) == len(files), "Duplicate or missing ZIP entries"
    assert set(output.namelist()) == set(files), "ZIP file list differs from source"
    for name, path in files.items():
        assert output.read(name) == path.read_bytes(), f"Stale ZIP entry: {name}"
print(f"Verified {len(files)} packaged files against source: {archive.name}")

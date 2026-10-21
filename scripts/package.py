"""Build a reproducible zip containing one installable addon directory."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
source = root / "AwesomeForeverToolkit"
destination = root / "dist/AwesomeForeverToolkit-0.1.0.zip"
destination.parent.mkdir(parents=True, exist_ok=True)

with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(source.rglob("*")):
        if not path.is_file() or path.name == ".DS_Store":
            continue

        info = zipfile.ZipInfo(path.relative_to(root).as_posix(), date_time=(1980, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        archive.writestr(info, path.read_bytes())

print(destination)

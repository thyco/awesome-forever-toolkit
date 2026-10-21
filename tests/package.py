from pathlib import Path
import re
import subprocess
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
subprocess.run([sys.executable, "scripts/package.py"], cwd=root, check=True)
archive = root / "dist/AwesomeForeverToolkit-0.1.0.zip"
with zipfile.ZipFile(archive) as package:
    names = set(package.namelist())
    assert names
    assert all(name.startswith("AwesomeForeverToolkit/") for name in names)
    manifest = package.read("AwesomeForeverToolkit/AwesomeForeverToolkit.toc").decode()
    for line in manifest.splitlines():
        if line.endswith(".lua"):
            assert "AwesomeForeverToolkit/" + line in names, line
    assert "AwesomeForeverToolkit/Media/Icon.tga" in names
    assert "AwesomeForeverToolkit/Libs/LibCustomGlow-1.0/LICENSE" in names
    assert not any("/tests/" in name or "/.git/" in name or "Probe" in name for name in names)
    for name in names:
        if name.endswith(".lua"):
            text = package.read(name).decode()
            assert "/Users/" not in text
            for texture in re.findall(r'Interface\\\\AddOns\\\\AwesomeForeverToolkit\\\\([^"]+)', text):
                path = "AwesomeForeverToolkit/" + texture.replace("\\\\", "/")
                assert path in names, path

before = archive.read_bytes()
subprocess.run([sys.executable, "scripts/package.py"], cwd=root, check=True)
assert archive.read_bytes() == before, "package must be reproducible"
print(f"package: PASS ({len(names)} files)")

from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
files = sorted((root / "AwesomeForeverToolkit").rglob("*.lua")) + sorted((root / "tests").rglob("*.lua"))
for path in files:
    subprocess.run(["luac", "-p", str(path)], check=True)
print(f"syntax: PASS ({len(files)} Lua files)")

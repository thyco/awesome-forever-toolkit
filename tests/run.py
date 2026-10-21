from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
target = root / (sys.argv[1] if len(sys.argv) > 1 else "tests")
files = sorted(target.rglob("*.lua")) if target.is_dir() else [target]
tests = [path for path in files if path.name != "helpers.lua"]
failed = []

for path in tests:
    result = subprocess.run(["lua", str(path.relative_to(root))], cwd=root)
    if result.returncode:
        failed.append(str(path.relative_to(root)))

print(f"{len(tests) - len(failed)}/{len(tests)} test files passed")
if failed:
    print("Failed: " + ", ".join(failed))
    sys.exit(1)

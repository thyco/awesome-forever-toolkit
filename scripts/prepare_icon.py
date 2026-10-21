"""Convert the approved artwork to the shipped WoW texture (requires Pillow)."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / "artwork/awesome-forever-toolkit-icon.png"
destination = root / "AwesomeForeverToolkit/Media/Icon.tga"
image = Image.open(source).convert("RGBA").resize((256, 256), Image.Resampling.LANCZOS)
destination.parent.mkdir(parents=True, exist_ok=True)
image.save(destination, format="TGA")
print(f"Prepared {destination.name}: {image.size}, {image.mode}")

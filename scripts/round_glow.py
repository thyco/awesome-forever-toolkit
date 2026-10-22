"""Generate the rotationally symmetric, soft alpha halo used by round buttons."""
from pathlib import Path
import math
import struct

size = 256
radius = 80
pixels = bytearray()

for y in range(size):
    for x in range(size):
        distance = math.hypot(x + 0.5 - size / 2, y + 0.5 - size / 2) - radius
        alpha = 0.65 * math.exp(-0.5 * (distance / 4) ** 2)
        alpha += 0.30 * math.exp(-0.5 * (distance / 12) ** 2)
        pixels.extend((255, 255, 255, round(255 * alpha)))

# Uncompressed BGRA TGA, top-left origin, eight alpha bits.
header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
path = Path(__file__).resolve().parents[1] / 'AwesomeForeverToolkit/Media/RoundGlow.tga'
path.write_bytes(header + pixels)
print(path)

#!/usr/bin/env python3
"""Return a small color grid of the desktop before the media card opens."""
import io
import json
import subprocess
import sys
from PIL import Image

try:
    x, y, width, height = (round(float(value)) for value in sys.argv[1:])
    capture = subprocess.run(
        ["grim", "-l", "0", "-g", f"{x},{y} {width}x{height}", "-"],
        capture_output=True, check=True, timeout=2,
    )
    with Image.open(io.BytesIO(capture.stdout)) as image:
        grid = image.convert("RGB").resize((16, 24), Image.Resampling.BOX)
        print(json.dumps([list(grid.getpixel((x, y))) for y in range(24) for x in range(16)]))
except (OSError, ValueError, subprocess.SubprocessError):
    print("[]")

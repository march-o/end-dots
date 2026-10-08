#!/usr/bin/env python3
"""Sample the wallpaper patch beneath a bar control group (centered cover fit)."""
import sys
from PIL import Image, ImageStat

path = sys.argv[1]
screen_w, screen_h, x, y, width, height, zoom = map(float, sys.argv[2:])
if min(screen_w, screen_h, width, height, zoom) <= 0:
    raise SystemExit(1)
with Image.open(path) as image:
    scale = max(screen_w / image.width, screen_h / image.height) * zoom
    offset_x = (image.width * scale - screen_w) / 2
    offset_y = (image.height * scale - screen_h) / 2
    box = ((x + offset_x) / scale, (y + offset_y) / scale,
           (x + width + offset_x) / scale, (y + height + offset_y) / scale)
    patch = image.convert("RGB").crop(box).resize((48, 12))
    rgb = [round(channel) for channel in ImageStat.Stat(patch).mean]
    print("#{:02x}{:02x}{:02x}".format(*rgb))

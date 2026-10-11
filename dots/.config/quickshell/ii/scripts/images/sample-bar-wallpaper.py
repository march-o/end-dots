#!/usr/bin/env python3
"""Sample a centered-cover patch from a shared, content-addressed preview."""
import fcntl
import hashlib
import json
import mmap
import os
from pathlib import Path
import sys
import time

CACHE_VERSION = 'rgb-2048-area-v2'
path = Path(sys.argv[1]).resolve()
screen_w, screen_h, x, y, width, height, zoom = map(float, sys.argv[2:])
if min(screen_w, screen_h, width, height, zoom) <= 0:
    raise SystemExit(1)
cache = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'quickshell/bar-wallpaper'
cache.mkdir(parents=True, exist_ok=True)


def publish_index(index):
    temporary = cache / 'index.tmp'
    temporary.write_text(json.dumps(index))
    temporary.replace(cache / 'index.json')


# Lock before importing Pillow: a wallpaper switch refreshes dozens of controls.
# Only one process may decode, and waiting processes keep a small memory footprint.
with (cache / 'sample.lock').open('a') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    stat = path.stat()
    signature = [stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns, CACHE_VERSION]
    try:
        index = json.loads((cache / 'index.json').read_text())
    except (FileNotFoundError, ValueError):
        index = {}
    previous = index.get(str(path), {})
    key = previous.get('key')
    if previous.get('signature') != signature or not key:
        # Metadata changes require a cheap streamed hash, not another image decode.
        # Touching or renaming an unchanged image still reuses the same preview.
        digest = hashlib.sha256(CACHE_VERSION.encode())
        with path.open('rb') as source:
            for chunk in iter(lambda: source.read(131072), b''):
                digest.update(chunk)
        key = digest.hexdigest()
        index.pop(str(path), None)
        index[str(path)] = {'signature': signature, 'key': key}
        if len(index) > 256:
            index = dict(list(index.items())[-256:])
        publish_index(index)
        old_key = previous.get('key')
        if old_key and old_key != key and not any(entry['key'] == old_key for entry in index.values()):
            for extension in ('png', 'ppm'):
                (cache / (old_key + '.' + extension)).unlink(missing_ok=True)
    preview = cache / (key + '.ppm')
    if not preview.exists():
        from PIL import Image
        temporary = cache / (key + '.tmp')
        try:
            with Image.open(path) as original:
                original.draft('RGB', (2048, 2048))
                original.thumbnail((2048, 2048), Image.Resampling.LANCZOS)
                original.convert('RGB').save(temporary, format='PPM')
            temporary.replace(preview)
        finally:
            temporary.unlink(missing_ok=True)
        # Bounded LRU storage; old previews rebuild lazily from their source.
        total = 0
        for position, entry in enumerate(sorted(list(cache.glob('*.png')) + list(cache.glob('*.ppm')), key=lambda p: p.stat().st_mtime, reverse=True)):
            total += entry.stat().st_size
            if position >= 24 or total > 128 * 1024 * 1024:
                entry.unlink(missing_ok=True)
    elif time.time() - preview.stat().st_mtime > 60:
        preview.touch()
    # Read shared raw pixels without importing Pillow or decoding a preview for
    # each control. mmap shares the same file pages across all sampler processes.
    with preview.open('rb') as pixels:
        assert pixels.readline().strip() == b'P6'
        image_w, image_h = map(int, pixels.readline().split())
        assert pixels.readline().strip() == b'255'
        offset = pixels.tell()
        scale = max(screen_w / image_w, screen_h / image_h) * zoom
        offset_x = (image_w * scale - screen_w) / 2
        offset_y = (image_h * scale - screen_h) / 2
        left, top, right, bottom = map(round, ((x + offset_x) / scale, (y + offset_y) / scale,
                                             (x + width + offset_x) / scale, (y + height + offset_y) / scale))
        count = max(1, (right - left) * (bottom - top))
        totals = [0, 0, 0]
        with mmap.mmap(pixels.fileno(), 0, access=mmap.ACCESS_READ) as shared:
            for row in range(max(0, top), min(image_h, bottom)):
                start = offset + (row * image_w + max(0, left)) * 3
                end = offset + (row * image_w + min(image_w, right)) * 3
                if end <= start:
                    continue
                patch_row = shared[start:end]
                for channel in range(3):
                    totals[channel] += sum(patch_row[channel::3])
        rgb = [round(channel / count) for channel in totals]
        print('#{:02x}{:02x}{:02x}'.format(*rgb))

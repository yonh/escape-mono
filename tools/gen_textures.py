#!/usr/bin/env python3
"""Procedural tileable PBR albedo textures — stdlib only, no deps.

Writes PNGs to assets/textures/. Textures tile seamlessly: the value-noise
lattices wrap at the image edge, and seam/detail lines land on the border.

All output is generated code (source="generated", license CC0-1.0) and must be
registered in assets/manifest.json — check_manifest.py verifies.

Run from repo root: python3 tools/gen_textures.py
"""
import math
import os
import random
import struct
import zlib

SIZE = 256
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "textures")


def write_png(path: str, px: list) -> None:
    """px: SIZE rows of (r,g,b) tuples → 8-bit RGB PNG."""
    raw = b"".join(b"\x00" + bytes(v for p in row for v in p) for row in px)

    def chunk(tag: bytes, data: bytes) -> bytes:
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    print(f"wrote {path}")


def _lattice(seed: int, cells: int) -> list:
    rnd = random.Random(seed)
    return [[rnd.random() for _ in range(cells)] for _ in range(cells)]


def _vn(grid: list, x: float, y: float) -> float:
    """Value noise on a wrapping lattice; x,y in cell units."""
    n = len(grid)
    xi, yi = int(x) % n, int(y) % n
    xf, yf = x - math.floor(x), y - math.floor(y)
    a, b = grid[yi][xi], grid[yi][(xi + 1) % n]
    c, d = grid[(yi + 1) % n][xi], grid[(yi + 1) % n][(xi + 1) % n]

    def s(t: float) -> float:
        return t * t * (3 - 2 * t)

    u, v = s(xf), s(yf)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def _fbm(grids: list, x: float, y: float) -> float:
    """Octave stack over pre-built lattices; x,y in pixels → ~[0,2)."""
    total, amp = 0.0, 1.0
    for g in grids:
        n = len(g)
        total += amp * _vn(g, x / SIZE * n, y / SIZE * n)
        amp *= 0.5
    return total


def _clamp(v: float) -> int:
    return max(0, min(255, int(v)))


def wall_concrete() -> list:
    """Precast concrete wall panels: mottled grey, vertical panel seams on the
    wrap edge, horizontal form line, low-freq stain blotches, rain streaks."""
    rnd = random.Random(101)
    g1, g2, g3 = _lattice(11, 8), _lattice(12, 16), _lattice(13, 32)
    stain = _lattice(14, 4)
    grids = [g1, g2, g3]
    px = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            n = _fbm(grids, x, y) * 0.5  # ~0..1
            v = 0.62 + (n - 0.5) * 0.22
            v += (rnd.random() - 0.5) * 0.035  # grain
            # stain blotches
            s = _vn(stain, x / SIZE * 4, y / SIZE * 4)
            if s > 0.66:
                v -= (s - 0.66) * 0.55
            # rain streaks: horizontally-locked noise streaking downward
            r = _vn(g2, x / SIZE * 16, y / SIZE * 2)
            v -= max(0.0, r - 0.72) * 0.35
            # horizontal form line at y≈SIZE/2 and panel seam at wrap x=0
            if abs(y - SIZE // 2) <= 1:
                v *= 0.82
            if x <= 2:
                v *= 0.72
            elif x <= 4:
                v *= 0.9
            row.append((_clamp(v * 255), _clamp(v * 255), _clamp(v * 252)))
        px.append(row)
    return px


def floor_concrete() -> list:
    """Warehouse floor: darker concrete, tile expansion joints at 128px,
    speckle, sparse cracks (wrapped random walk), oil stains."""
    rnd = random.Random(202)
    g1, g2 = _lattice(21, 8), _lattice(22, 24)
    stain = _lattice(23, 3)
    grids = [g1, g2]
    # crack polylines as distance field — precompute a few wrapped segments
    cracks = []
    cr = random.Random(24)
    for _ in range(6):
        x0, y0 = cr.uniform(0, SIZE), cr.uniform(0, SIZE)
        ang, ln = cr.uniform(0, math.tau), cr.uniform(30, 90)
        cracks.append((x0, y0, math.cos(ang), math.sin(ang), ln))
    px = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            v = 0.34 + (_fbm(grids, x, y) * 0.5 - 0.5) * 0.16
            v += (rnd.random() - 0.5) * 0.05  # aggregate speckle
            s = _vn(stain, x / SIZE * 3, y / SIZE * 3)
            if s > 0.62:
                v -= (s - 0.62) * 0.5  # oil stains
            # expansion joints at half-image
            if abs(x - SIZE // 2) <= 1 or abs(y - SIZE // 2) <= 1:
                v *= 0.72
            # cracks: point-segment distance (wrapped)
            for cx, cy, dx, dy, ln in cracks:
                for oy in (-SIZE, 0, SIZE):
                    for ox in (-SIZE, 0, SIZE):
                        px_, py_ = x - ox, y - oy
                        t = max(0.0, min(ln, (px_ - cx) * dx + (py_ - cy) * dy))
                        d = math.hypot(px_ - (cx + dx * t), py_ - (cy + dy * t))
                        if d < 1.2:
                            v *= 0.55
            row.append((_clamp(v * 255), _clamp(v * 255), _clamp(v * 258)))
        px.append(row)
    return px


def metal_plate() -> list:
    """Corrugated/brushed ceiling deck: vertical streak bands, rivet rows
    every 64px, mild rust bleeding under rivets."""
    rnd = random.Random(303)
    g1 = _lattice(31, 8)
    g2 = _lattice(32, 32)
    px = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            # corrugation: sawtooth shading across x
            corr = 0.5 + 0.5 * math.sin(x / SIZE * math.tau * 8)
            v = 0.40 + corr * 0.12
            v += (_vn(g1, x / SIZE * 8, y / SIZE * 8) - 0.5) * 0.10
            v += (_vn(g2, x / SIZE * 32, y / SIZE * 2) - 0.5) * 0.10  # brushed
            v += (rnd.random() - 0.5) * 0.03
            # rivets on a 64px grid
            rx, ry = x % 64, y % 64
            dx = min(rx, 64 - rx)
            dy = min(ry, 64 - ry)
            d = math.hypot(dx, dy)
            if d < 3.0:
                v *= 0.55
            elif d < 5.0:
                v *= 0.8
            elif d < 14.0:
                v -= (1 - d / 14.0) * 0.10  # rust halo
            row.append((_clamp(v * 255 * 0.95), _clamp(v * 255), _clamp(v * 255 * 1.02)))
        px.append(row)
    return px


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    write_png(os.path.join(OUT, "wall_concrete.png"), wall_concrete())
    write_png(os.path.join(OUT, "floor_concrete.png"), floor_concrete())
    write_png(os.path.join(OUT, "metal_plate.png"), metal_plate())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

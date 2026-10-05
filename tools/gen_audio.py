#!/usr/bin/env python3
"""Synthesize the game's CC0 sound set into assets/audio/.

Pure-Python (stdlib only) 16-bit mono WAVs — no binary deps so it runs on any
Devin VM. Each recipe is deterministic (seeded), so the wavs are reproducible
and the script is the canonical "source" recorded in assets/manifest.json.

Run from repo root: python3 tools/gen_audio.py
"""
import math
import os
import random
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
RATE = 22050


def write_wav(name: str, samples: list) -> str:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    peak = max(1e-6, max(abs(s) for s in samples))
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s / peak)) * 32767)) for s in samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)
    print(f"wrote assets/audio/{name} ({len(samples) / RATE:.2f}s)")
    return path


def env_exp(t: float, k: float) -> float:
    return math.exp(-t * k)


def shot(name: str, dur: float, crack_hz: float, thump_hz: float, seed: int) -> None:
    """Gunshot: fast-decaying broadband crack + low thump."""
    rng = random.Random(seed)
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        noise = (rng.random() * 2 - 1) * env_exp(t, 55.0)
        crack = math.sin(2 * math.pi * crack_hz * t) * env_exp(t, 45.0)
        thump = math.sin(2 * math.pi * thump_hz * t) * env_exp(t, 14.0)
        out.append(noise * 0.55 + crack * 0.45 + thump * 0.9)
    write_wav(name, out)


def thud(name: str, dur: float, hz: float, seed: int) -> None:
    """Flesh hit / body fall: short low thud + noise."""
    rng = random.Random(seed)
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        body = math.sin(2 * math.pi * hz * t) * env_exp(t, 35.0)
        noise = (rng.random() * 2 - 1) * env_exp(t, 80.0) * 0.4
        out.append(body + noise)
    write_wav(name, out)


def click_train(name: str, durs_and_gaps: list, seed: int) -> None:
    """Reload-style: bursts of short filtered clicks. list = [(start, dur), ...]"""
    rng = random.Random(seed)
    total = int(RATE * max(s + d for s, d in durs_and_gaps) + RATE * 0.05)
    out = [0.0] * total
    for start, dur in durs_and_gaps:
        for i in range(int(RATE * dur)):
            t = i / RATE
            idx = int(RATE * start) + i
            out[idx] += (rng.random() * 2 - 1) * env_exp(t, 220.0) * 0.9
            out[idx] += math.sin(2 * math.pi * 2200 * t) * env_exp(t, 300.0) * 0.3
    write_wav(name, out)


def footstep(name: str, seed: int) -> None:
    rng = random.Random(seed)
    dur = 0.09
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        noise = (rng.random() * 2 - 1) * env_exp(t, 90.0)
        low = math.sin(2 * math.pi * 90 * t) * env_exp(t, 60.0)
        out.append(noise * 0.5 + low * 0.5)
    write_wav(name, out)


def rustle(name: str, dur: float, seed: int) -> None:
    """Search rustle: tremoloed mid noise."""
    rng = random.Random(seed)
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        trem = 0.5 + 0.5 * math.sin(2 * math.pi * 7 * t)
        out.append((rng.random() * 2 - 1) * trem * 0.5)
    write_wav(name, out)


def creak(name: str, seed: int) -> None:
    """Crate open: low sweep creak + end thunk."""
    rng = random.Random(seed)
    dur = 0.45
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        sweep = math.sin(2 * math.pi * (300 - 160 * (t / dur)) * t) * env_exp(t, 6.0) * 0.5
        noise = (rng.random() * 2 - 1) * env_exp(t, 9.0) * 0.15
        thunk = math.sin(2 * math.pi * 110 * t) * env_exp(max(0.0, t - 0.3), 40.0) if t > 0.3 else 0.0
        out.append(sweep + noise + thunk * 0.8)
    write_wav(name, out)


def ambient(name: str, dur: float, seed: int) -> None:
    """Room tone: brown-ish noise + faint 55Hz hum, looped (wrap-blended tail)."""
    rng = random.Random(seed)
    n = int(RATE * dur)
    last = 0.0
    out = []
    for i in range(n):
        t = i / RATE
        last += (rng.random() * 2 - 1) * 0.02
        last *= 0.995
        hum = math.sin(2 * math.pi * 55 * t) * 0.06
        out.append(last * 1.4 + hum)
    # blend tail into head for a clean loop
    fade = int(RATE * 0.5)
    for i in range(fade):
        w = i / fade
        out[i] = out[i] * w + out[n - fade + i] * (1 - w)
    out = out[: n - fade]
    write_wav(name, out)


def chime(name: str, freqs: list, seed: int) -> None:
    rng = random.Random(seed)
    dur = 0.6
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        v = 0.0
        for j, f in enumerate(freqs):
            st = j * 0.12
            if t >= st:
                v += math.sin(2 * math.pi * f * (t - st)) * env_exp(t - st, 8.0) * 0.6
        out.append(v + (rng.random() * 2 - 1) * 0.01)
    write_wav(name, out)


def sting(name: str, seed: int) -> None:
    """Death sting: falling sine + noise tail."""
    rng = random.Random(seed)
    dur = 1.1
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        f = 220 * math.exp(-t * 2.2) + 45
        tone = math.sin(2 * math.pi * f * t) * env_exp(t, 4.0) * 0.8
        noise = (rng.random() * 2 - 1) * env_exp(t, 7.0) * 0.25
        out.append(tone + noise)
    write_wav(name, out)


def door_slide(name: str, seed: int) -> None:
    rng = random.Random(seed)
    dur = 0.6
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        rumble = (rng.random() * 2 - 1) * (0.3 + 0.7 * math.sin(math.pi * t / dur)) * 0.4
        thunk = math.sin(2 * math.pi * 95 * t) * env_exp(max(0.0, t - 0.45), 30.0) if t > 0.45 else 0.0
        out.append(rumble + thunk * 0.9)
    write_wav(name, out)


def denied(name: str, seed: int) -> None:
    rng = random.Random(seed)
    dur = 0.12
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        sq = 1.0 if math.sin(2 * math.pi * 180 * t) > 0 else -1.0
        out.append(sq * env_exp(t, 60.0) * 0.4 + (rng.random() * 2 - 1) * env_exp(t, 90.0) * 0.3)
    write_wav(name, out)


def main() -> int:
    shot("sfx_shot_pm.wav", 0.28, 1500, 130, 11)       # 手枪脆响
    shot("sfx_shot_ak.wav", 0.30, 1200, 105, 22)       # 步枪低闷
    shot("sfx_shot_sg.wav", 0.45, 800, 75, 33)         # 霰弹轰
    shot("sfx_shot_scav.wav", 0.30, 1000, 95, 44)      # 敌枪远闷
    thud("sfx_hit.wav", 0.12, 140, 55)                 # 命中肉体
    thud("sfx_bodyfall.wav", 0.35, 90, 66)             # 倒地
    click_train("sfx_reload.wav", [(0.05, 0.04), (0.32, 0.05)], 77)
    footstep("sfx_footstep.wav", 88)
    rustle("sfx_search.wav", 0.7, 99)                  # 搜索沙沙（循环用）
    creak("sfx_crate_open.wav", 111)
    ambient("amb_factory_loop.wav", 8.0, 222)
    chime("sfx_extract_done.wav", [620, 830, 1100], 133)
    sting("sfx_death.wav", 144)
    door_slide("sfx_door_open.wav", 155)
    denied("sfx_door_denied.wav", 166)
    print("audio set generated")
    return 0


if __name__ == "__main__":
    sys.exit(main())

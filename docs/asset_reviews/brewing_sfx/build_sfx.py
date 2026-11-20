"""Build deterministic placeholder brewing SFX as mono 16-bit WAV files."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


RATE = 22050
ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "audio" / "sfx" / "brewing"
RNG = random.Random(24017)


def write(name: str, samples: list[float]) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    peak = max(1.0, max(abs(value) for value in samples))
    payload = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, value / peak)) * 32767))
        for value in samples
    )
    with wave.open(str(OUTPUT / name), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(payload)


def tone(duration: float, frequencies: tuple[float, ...], decay: float = 4.0) -> list[float]:
    result: list[float] = []
    for index in range(int(RATE * duration)):
        time = index / RATE
        envelope = math.exp(-decay * time)
        value = sum(math.sin(math.tau * frequency * time) for frequency in frequencies)
        result.append(envelope * value / len(frequencies))
    return result


def noise_loop(duration: float, tone_frequency: float, noise_amount: float) -> list[float]:
    length = int(RATE * duration)
    raw = [RNG.uniform(-1.0, 1.0) for _ in range(length)]
    result: list[float] = []
    smoothed = 0.0
    for index, sample in enumerate(raw):
        smoothed = smoothed * 0.93 + sample * 0.07
        time = index / RATE
        pulse = 0.55 + 0.45 * math.sin(math.tau * 3.0 * time) ** 2
        result.append(
            smoothed * noise_amount * pulse
            + math.sin(math.tau * tone_frequency * time) * 0.08
        )
    fade = min(int(RATE * 0.08), length // 4)
    for index in range(fade):
        blend = index / fade
        mixed = result[index] * blend + result[length - fade + index] * (1.0 - blend)
        result[index] = mixed
        result[length - fade + index] = mixed
    return result


def main() -> None:
    write("fire_loop.wav", noise_loop(0.8, 86.25, 0.48))
    write("boil_loop.wav", noise_loop(0.64, 172.5, 0.34))
    write("release_bad.wav", tone(0.24, (92.0, 111.0), 6.0))
    write("release_normal.wav", tone(0.20, (245.0, 326.0), 7.0))
    write("release_perfect.wav", tone(0.28, (523.25, 659.25, 783.99), 5.5))
    first = tone(0.22, (659.25, 987.77), 4.5)
    second = [0.0] * int(RATE * 0.07) + tone(0.38, (783.99, 1046.5, 1318.5), 4.0)
    length = max(len(first), len(second))
    perfect = [
        (first[index] if index < len(first) else 0.0)
        + (second[index] if index < len(second) else 0.0)
        for index in range(length)
    ]
    write("perfect_brew.wav", perfect)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Original Screwcraft sounds, synthesized offline with only the Python stdlib.

Run: python3 assets/audio/generate_audio.py
Writes reproducible, uncompressed, mono PCM16 48 kHz WAV masters alongside this
source. No samples, recordings, models, plugins, or network services are used.
"""
from array import array
from pathlib import Path
import math
import random
import struct
import wave

RATE = 48_000
OUT = Path(__file__).resolve().parent
TAU = math.tau


def empty(seconds):
    return array("d", [0.0]) * round(RATE * seconds)


def add_note(samples, at, frequency, duration, gain, material="felt"):
    """Soft modal synthesis: inharmonic wood or damped, piano-like partials."""
    start = round(at * RATE)
    count = min(round(duration * RATE), len(samples) - start)
    modes = ((1, 1, 1), (2.03, .20, .48), (3.96, .09, .24))
    if material == "wood":
        modes = ((1, 1, 1), (2.73, .37, .54), (5.12, .11, .27))
    for i in range(count):
        t = i / RATE
        attack = 1 - math.exp(-t / .0025)
        fade = min(1.0, (count - i) / (RATE * .016))
        val = sum(amp * math.sin(TAU * frequency * ratio * t)
                  * math.exp(-t / (duration * .23 * decay))
                  for ratio, amp, decay in modes)
        samples[start + i] += gain * val * attack * fade


def add_brush(samples, at, duration, gain, seed):
    """Quiet filtered friction: no sustained high-frequency white-noise fizz."""
    rng = random.Random(seed)
    start = round(at * RATE)
    count = min(round(duration * RATE), len(samples) - start)
    low = 0.0
    for i in range(count):
        t = i / RATE
        low += .095 * (rng.uniform(-1, 1) - low)
        envelope = math.sin(math.pi * i / max(1, count - 1)) ** 2
        samples[start + i] += low * gain * envelope * math.exp(-t * 12)


def write(name, samples, peak_limit=.68):
    peak = max(abs(v) for v in samples) or 1
    scale = min(1.0, peak_limit / peak)
    # Round and clamp as a last guard; synthesis never intentionally clips.
    pcm = b"".join(struct.pack("<h", round(max(-1, min(1, v * scale)) * 32767))
                   for v in samples)
    with wave.open(str(OUT / (name + ".wav")), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm)
    print(f"{name:20s} {len(samples) / RATE:5.2f}s  peak={peak * scale:.3f}")


def main():
    for variant, pitch in enumerate((.97, 1.0, 1.025), 1):
        click = empty(.115)
        add_note(click, 0, 790 * pitch, .09, .40, "wood")
        add_brush(click, 0, .026, .16, variant)
        write(f"click_{variant}", click)

        extract = empty(.235)
        add_note(extract, 0, 650 * pitch, .08, .30, "wood")
        add_brush(extract, .008, .11, .28, 20 + variant)
        add_note(extract, .075, 1010 * pitch, .12, .28)
        write(f"extract_{variant}", extract)

        release = empty(.30)
        add_note(release, 0, 220 * pitch, .27, .40, "wood")
        add_note(release, .020, 340 * pitch, .16, .13, "wood")
        add_brush(release, 0, .11, .20, 40 + variant)
        write(f"wood_{variant}", release)

        complete = empty(.64)
        for t, f, g in ((0, 587.33, .32), (.075, 739.99, .24), (.14, 880, .20)):
            add_note(complete, t, f * pitch, .46, g)
        write(f"complete_{variant}", complete)

        undo = empty(.32)
        add_note(undo, 0, 659.25 * pitch, .15, .25)
        add_note(undo, .065, 493.88 * pitch, .22, .29)
        write(f"undo_{variant}", undo)

    victory = empty(1.35)
    for t, f, g in ((0, 587.33, .32), (.12, 739.99, .28), (.24, 880, .25),
                    (.42, 1174.66, .26), (.42, 587.33, .15)):
        add_note(victory, t, f, .87, g)
    write("victory", victory)

    # A sparse original D-major miniature, with long silence between gestures.
    # The last notes decay before the loop point; both loop endpoints are zero.
    ambience = empty(24)
    for at, notes in ((0.3, (146.83, 293.66, 369.99)),
                      (5.4, (164.81, 329.63, 440.00)),
                      (10.6, (123.47, 246.94, 369.99)),
                      (16.1, (146.83, 293.66, 440.00))):
        for j, frequency in enumerate(notes):
            add_note(ambience, at + j * .48, frequency, 4.6, .28 - j * .04)
    write("workshop_ambience", ambience)


if __name__ == "__main__":
    main()

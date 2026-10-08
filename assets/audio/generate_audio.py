#!/usr/bin/env python3
"""Original Toybox Workshop sound kit, synthesized with the Python stdlib.

Run: python3 assets/audio/generate_audio.py
Writes reproducible, uncompressed, mono PCM16 48 kHz WAV masters. No sampled
recordings, models, plugins, network services, or third-party music are used.
The palette is rubbery pops, rotating toy ratchets, marimba and tiny bells.
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


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def add_note(samples, at, frequency, duration, gain, material="marimba"):
    """Damped resonators with a soft attack and guaranteed zero endpoint."""
    start = round(at * RATE)
    count = min(round(duration * RATE), len(samples) - start)
    modes = {
        "marimba": ((1, 1, 1), (4, .13, .32), (10, .022, .18)),
        "bell": ((1, 1, 1), (2, .26, .75), (3, .065, .48)),
        "wood": ((1, 1, 1), (2.73, .30, .45), (5.12, .065, .20)),
        "bass": ((1, 1, 1), (2, .19, .40), (3, .06, .24)),
    }[material]
    for i in range(count):
        t = i / RATE
        attack = 1 - math.exp(-t / .003)
        fade = min(1.0, (count - i - 1) / (RATE * .020))
        val = sum(amp * math.sin(TAU * frequency * ratio * t)
                  * math.exp(-t / (duration * .27 * decay))
                  for ratio, amp, decay in modes)
        samples[start + i] += gain * val * attack * fade


def add_pop(samples, at, pitch, duration, gain, up=False):
    """A small elastic toy pop; phase-integrated glide prevents discontinuity."""
    start = round(at * RATE)
    count = min(round(duration * RATE), len(samples) - start)
    phase = 0.0
    for i in range(count):
        x = i / max(1, count - 1)
        f = pitch * ((.62 + .54 * x) if up else (1.35 - .63 * x))
        phase += TAU * f / RATE
        env = math.sin(math.pi * x) ** .6 * math.exp(-x * 3.2)
        samples[start + i] += gain * env * (math.sin(phase) + .10 * math.sin(2 * phase))


def add_brush(samples, at, duration, gain, seed):
    """Quiet filtered movement; never a sustained high-frequency noise fizz."""
    rng = random.Random(seed)
    start = round(at * RATE)
    count = min(round(duration * RATE), len(samples) - start)
    low = 0.0
    for i in range(count):
        t = i / RATE
        low += .10 * (rng.uniform(-1, 1) - low)
        envelope = math.sin(math.pi * i / max(1, count - 1)) ** 2
        samples[start + i] += low * gain * envelope * math.exp(-t * 12)


def write(name, samples, peak_limit=.64):
    peak = max(abs(v) for v in samples) or 1
    scale = min(1.0, peak_limit / peak)
    pcm = b"".join(struct.pack("<h", round(max(-1, min(1, v * scale)) * 32767))
                   for v in samples)
    with wave.open(str(OUT / (name + ".wav")), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm)
    rms = math.sqrt(sum(v * v for v in samples) / len(samples)) * scale
    print(f"{name:20s} {len(samples) / RATE:5.2f}s  peak={peak * scale:.3f}  rms={rms:.3f}")


def main():
    # Three small variations avoid mechanical repetition without startling jumps.
    for variant, pitch in enumerate((.98, 1.0, 1.025), 1):
        click = empty(.14)
        add_pop(click, 0, 620 * pitch, .105, .70)
        add_note(click, .009, 1397 * pitch, .085, .10, "marimba")
        write(f"click_{variant}", click)

        extract = empty(.32)
        for j in range(4):
            add_note(extract, j * .033, (480 + 80 * j) * pitch,
                     .050, .18 - .022 * j, "wood")
        add_brush(extract, .01, .15, .17, 20 + variant)
        add_pop(extract, .106, 850 * pitch, .14, .43, up=True)
        add_note(extract, .145, hz(84) * pitch, .15, .13, "bell")
        write(f"extract_{variant}", extract)

        release = empty(.38)
        add_note(release, 0, 240 * pitch, .20, .42, "wood")
        add_note(release, .055, 360 * pitch, .14, .19, "wood")
        add_pop(release, .125, 460 * pitch, .18, .31)
        add_brush(release, 0, .12, .16, 40 + variant)
        write(f"wood_{variant}", release)

        complete = empty(.76)
        add_pop(complete, 0, 590 * pitch, .10, .39)
        for j, note in enumerate((76, 79, 84, 88)):
            add_note(complete, .035 + j * .066, hz(note) * pitch,
                     .49, .23 - j * .031, "bell")
        write(f"complete_{variant}", complete)

        undo = empty(.37)
        add_pop(undo, 0, 700 * pitch, .12, .38)
        add_note(undo, .030, hz(79) * pitch, .20, .17, "marimba")
        add_note(undo, .105, hz(72) * pitch, .24, .22, "marimba")
        write(f"undo_{variant}", undo)

    # The original "Pip did it!" signature: two hops and a smiling flourish.
    victory = empty(2.25)
    for beat, midi in ((0, 72), (.20, 76), (.38, 79), (.69, 84),
                       (.93, 81), (1.10, 83), (1.31, 84), (1.43, 88)):
        add_note(victory, beat, hz(midi), .68, .25 if midi < 84 else .19, "bell")
        add_note(victory, beat, hz(midi - 12), .32, .10, "marimba")
    for midi in (48, 55, 60):
        add_note(victory, 1.31, hz(midi), .85, .10, "bass")
    add_pop(victory, 1.31, 180, .25, .21)
    write("victory", victory)

    # Eight bars at 100 BPM. Gentle syncopated marimba on C / F / Am / G;
    # this is a playful toy workshop, with space for tactile gameplay sounds.
    beat = .6
    ambience = empty(8 * 4 * beat)
    chords = ((48, 64, 67), (48, 64, 67), (53, 65, 69), (53, 65, 69),
              (45, 60, 64), (45, 60, 64), (43, 59, 62), (48, 64, 67))
    melody = ((0, 76), (1.5, 79), (3, 76), (4.5, 74), (6, 72),
              (8, 77), (9.5, 81), (11, 79), (13, 77), (14.5, 76),
              (16, 76), (17.5, 79), (19, 81), (21, 79), (22.5, 76),
              (24, 74), (25.5, 71), (27, 74), (28.5, 72), (30, 76))
    for bar, (root, third, fifth) in enumerate(chords):
        at = bar * 4 * beat + .03
        add_note(ambience, at, hz(root), .42, .20, "bass")
        add_note(ambience, at + 2 * beat, hz(root + 7), .34, .13, "bass")
        for offset in (.5, 2.5):
            for note in (third, fifth):
                add_note(ambience, at + offset * beat, hz(note), .30, .085)
        for tick in range(4):
            add_brush(ambience, at + tick * beat, .055, .16, bar * 4 + tick)
    for i, (offset, note) in enumerate(melody):
        add_note(ambience, offset * beat + .03, hz(note), .56, .18)
        if i % 5 == 0:
            add_note(ambience, offset * beat + .03, hz(note + 12), .62, .065, "bell")
    write("workshop_ambience", ambience, .46)


if __name__ == "__main__":
    main()

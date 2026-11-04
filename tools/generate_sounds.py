"""Generates the Coin Rush sound effects and music loop (no external dependencies).

Usage (from the repository root):
    python tools/generate_sounds.py

Writes identical .wav files to classic-game/sounds/ and meds-game/game/sounds/.
The music file contains a `smpl` loop chunk, so Godot imports it as a looping stream.
"""

import math
import random
import struct
from pathlib import Path

RATE = 22050
ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIRS = [ROOT / "classic-game" / "sounds", ROOT / "meds-game" / "game" / "sounds"]


def note(name: str) -> float:
    offsets = {"C": -9, "C#": -8, "D": -7, "Eb": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "Ab": -1, "A": 0, "Bb": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((offsets[pitch] + (octave - 4) * 12) / 12)


def square(phase: float) -> float:
    return 1.0 if (phase % 1.0) < 0.5 else -1.0


def pulse(phase: float) -> float:
    return 1.0 if (phase % 1.0) < 0.25 else -1.0


def triangle(phase: float) -> float:
    return 4.0 * abs((phase % 1.0) - 0.5) - 1.0


def sine(phase: float) -> float:
    return math.sin(phase * math.tau)


def envelope(t: float, length: float, decay: float = 0.0, attack: float = 0.005, release: float = 0.02) -> float:
    if t < 0 or t >= length:
        return 0.0
    level = min(1.0, t / attack, (length - t) / release)
    if decay > 0:
        level *= math.exp(-t / decay)
    return level


def tone(buffer: list, start: float, length: float, freq_from: float, freq_to: float | None = None,
         wave=square, volume: float = 0.3, decay: float = 0.0) -> None:
    freq_to = freq_from if freq_to is None else freq_to
    phase = 0.0
    first = int(start * RATE)
    for i in range(min(int(length * RATE), len(buffer) - first)):
        t = i / RATE
        phase += (freq_from + (freq_to - freq_from) * (t / length)) / RATE
        buffer[first + i] += wave(phase) * volume * envelope(t, length, decay)


def noise(buffer: list, start: float, length: float, volume: float, decay: float) -> None:
    rng = random.Random(42)
    first = int(start * RATE)
    for i in range(min(int(length * RATE), len(buffer) - first)):
        buffer[first + i] += rng.uniform(-1, 1) * volume * envelope(i / RATE, length, decay)


def write_wav(path: Path, samples: list, loop: bool = False) -> None:
    peak = max(1.0, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(s / peak * 32767)) for s in samples)
    chunks = struct.pack("<4sIHHIIHH", b"fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16)
    if loop:
        # smpl chunk: 9 header fields + one forward loop (cue id, type, start, end, fraction, play count).
        header = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        loop_info = struct.pack("<6I", 0, 0, 0, len(samples), 0, 0)
        chunks += struct.pack("<4sI", b"smpl", len(header) + len(loop_info)) + header + loop_info
    chunks += struct.pack("<4sI", b"data", len(data)) + data
    path.write_bytes(struct.pack("<4sI4s", b"RIFF", 4 + len(chunks), b"WAVE") + chunks)


def silence(seconds: float) -> list:
    return [0.0] * int(seconds * RATE)


def coin() -> list:
    buffer = silence(0.2)
    tone(buffer, 0.0, 0.06, note("B5"), volume=0.25)
    tone(buffer, 0.06, 0.14, note("E6"), volume=0.25, decay=0.06)
    return buffer


def hit() -> list:
    buffer = silence(0.3)
    noise(buffer, 0.0, 0.25, volume=0.5, decay=0.06)
    tone(buffer, 0.0, 0.3, 320, 70, wave=triangle, volume=0.6, decay=0.12)
    return buffer


def level_up() -> list:
    buffer = silence(0.55)
    for i, name in enumerate(["C5", "E5", "G5"]):
        tone(buffer, i * 0.07, 0.07, note(name), wave=pulse, volume=0.2)
    tone(buffer, 0.21, 0.32, note("C6"), wave=pulse, volume=0.2, decay=0.15)
    return buffer


def game_over() -> list:
    buffer = silence(1.4)
    for i, name in enumerate(["G4", "Eb4", "C4"]):
        tone(buffer, i * 0.22, 0.22, note(name), wave=triangle, volume=0.45)
    tone(buffer, 0.66, 0.7, note("C3"), note("B2"), wave=triangle, volume=0.5, decay=0.35)
    return buffer


def music() -> list:
    beat = 60 / 120
    bar = beat * 4
    chords = [("A2", ["A4", "C5", "E5"]), ("F2", ["F4", "A4", "C5"]),
              ("C3", ["C5", "E5", "G5"]), ("G2", ["G4", "B4", "D5"])]
    buffer = silence(bar * len(chords))
    for bar_index, (bass, arpeggio) in enumerate(chords):
        bar_start = bar_index * bar
        for eighth in range(8):
            octave = 2.0 if eighth % 2 else 1.0
            tone(buffer, bar_start + eighth * beat / 2, beat / 2 * 0.9, note(bass) * octave, wave=triangle, volume=0.35)
        for sixteenth in range(16):
            name = arpeggio[1] if sixteenth % 4 == 3 else arpeggio[sixteenth % 3]
            tone(buffer, bar_start + sixteenth * beat / 4, beat / 4 * 0.95, note(name), wave=pulse, volume=0.08, decay=0.05)
        for kick in range(4):
            tone(buffer, bar_start + kick * beat, 0.12, 110, 45, wave=sine, volume=0.5, decay=0.05)
    return buffer


def main() -> None:
    sounds = {"coin.wav": coin(), "hit.wav": hit(), "level_up.wav": level_up(), "game_over.wav": game_over()}
    loop = music()
    for directory in OUTPUT_DIRS:
        directory.mkdir(parents=True, exist_ok=True)
        for name, samples in sounds.items():
            write_wav(directory / name, samples)
        write_wav(directory / "music.wav", loop, loop=True)
        print(f"Wrote {len(sounds) + 1} sounds to {directory.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

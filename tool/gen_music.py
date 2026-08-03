"""Generate a slow, spacious, loungey background loop for Word Sprint.

Pure synthesis (no samples) -> one small WAV, 44.1kHz 16-bit mono. Soft triangle
bass + a quiet sine chord pad + a sparse triangle melody that rests half the
bars, over lazy jazzy 7th chords in A. Slow (72 BPM) and mellow so it sits far
in the background of a thinking game. Loops cleanly (all notes envelope to zero
on the grid, so the seam is near-silence -> near-silence).

Re-run: python tool/gen_music.py
"""
import os
import wave
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")
SR = 44100
BPM = 72
SPB = SR * 60.0 / BPM          # samples per beat
BARS = 8
BEATS = BARS * 4
TOTAL = int(round(SPB * BEATS))


def hz(name):
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4,
             "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    n, octv = name[:-1], int(name[-1])
    semis = names[n] + (octv - 4) * 12
    return 440.0 * (2 ** (semis / 12.0))


def _env(n, attack, release):
    e = np.ones(n)
    a, r = int(SR * attack), int(SR * release)
    a = min(a, n)
    r = min(r, n - a)
    if a > 0:
        e[:a] = np.linspace(0, 1, a)
    if r > 0:
        e[-r:] = np.linspace(1, 0, r)
    return e


def _wave(freq, n, kind):
    t = np.arange(n) / SR
    if kind == "tri":
        return 2 * np.abs(2 * ((freq * t) % 1.0) - 1) - 1
    return np.sin(2 * np.pi * freq * t)  # sine


def place(buf, start_beat, dur_beats, freq, kind="tri", vol=0.3,
          attack=0.02, release=0.2):
    start = int(round(start_beat * SPB))
    n = int(round(dur_beats * SPB))
    if n <= 0:
        return
    seg = _wave(freq, n, kind) * _env(n, attack, release) * vol
    end = min(start + n, len(buf))
    buf[start:end] += seg[:end - start]


buf = np.zeros(TOTAL)

# Lazy jazzy 7th progression. Each entry: (bass root, [pad chord tones]).
PROG = [
    ("A2", ["A3", "C#4", "E4", "G#4"]),   # Amaj7
    ("C#3", ["C#4", "E4", "G#4", "B4"]),  # C#m7
    ("B2", ["B3", "D4", "F#4", "A4"]),    # Bm7
    ("E2", ["E3", "G#3", "B3", "D4"]),    # E7
    ("A2", ["A3", "C#4", "E4", "G#4"]),   # Amaj7
    ("F#2", ["F#3", "A3", "C#4", "E4"]),  # F#m7
    ("B2", ["B3", "D4", "F#4", "A4"]),    # Bm7
    ("E2", ["E3", "G#3", "B3", "D4"]),    # E7
]

# Sparse melody, only on odd bars (1,3,5,7); even bars breathe with just
# pad + bass. (bar index, start beat, note, duration in beats).
MELODY = [
    (0, 1.0, "E5", 2.0), (0, 3.0, "C#5", 1.0),
    (2, 0.5, "F#5", 1.5), (2, 2.5, "D5", 1.5),
    (4, 1.0, "A5", 2.0), (4, 3.0, "G#5", 1.0),
    (6, 0.5, "D5", 1.5), (6, 2.0, "F#5", 2.0),
]

for bar, (bass_root, tones) in enumerate(PROG):
    b0 = bar * 4
    root = hz(bass_root)

    # --- soft sine pad: whole-bar sustained chord, very quiet ---
    for tn in tones:
        place(buf, b0 + 0.05, 3.7, hz(tn), "sine", vol=0.055,
              attack=0.25, release=0.5)

    # --- sparse triangle bass: root held 2 beats, a gentle fifth for 2 more ---
    place(buf, b0 + 0.0, 1.9, root, "tri", vol=0.26, attack=0.01, release=0.2)
    place(buf, b0 + 2.0, 1.9, root * (2 ** (7 / 12.0)), "tri", vol=0.20,
          attack=0.01, release=0.2)

for bar, beat, note, dur in MELODY:
    place(buf, bar * 4 + beat, dur * 0.9, hz(note), "tri", vol=0.26,
          attack=0.03, release=0.25)

# Normalize to a modest peak; the player also plays this quietly, so the final
# in-game level is a distant background wash.
peak = np.max(np.abs(buf))
if peak > 0:
    buf = buf / peak * 0.72
pcm = (np.clip(buf, -1, 1) * 32767).astype(np.int16)

os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, "loop.wav")
with wave.open(path, "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print(f"loop.wav: {os.path.getsize(path)} bytes, "
      f"{len(pcm)/SR:.1f}s, {BPM} BPM, {BARS} bars")

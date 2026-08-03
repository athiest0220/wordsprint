"""Generate tiny, click-free WAV sound effects for Word Sprint.

Pure synthesis (no external assets) → each file is a few KB, 44.1kHz 16-bit mono.
Re-run to regenerate: python tool/gen_sfx.py
"""
import os
import struct
import wave
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
SR = 44100


def _env(n, attack=0.004, release=0.05):
    """Attack/release envelope (seconds) to avoid start/end clicks."""
    e = np.ones(n)
    a = int(SR * attack)
    r = int(SR * release)
    if a > 0:
        e[:a] = np.linspace(0, 1, a)
    if r > 0:
        e[-r:] = np.linspace(1, 0, r)
    return e


def tone(freq, dur, kind="sine", vol=0.5, attack=0.004, release=0.05):
    n = int(SR * dur)
    t = np.arange(n) / SR
    if kind == "square":
        wave_ = np.sign(np.sin(2 * np.pi * freq * t))
    else:
        wave_ = np.sin(2 * np.pi * freq * t)
    return wave_ * _env(n, attack, release) * vol


def glide(f0, f1, dur, vol=0.5, release=0.05):
    n = int(SR * dur)
    t = np.arange(n) / SR
    freq = np.linspace(f0, f1, n)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase) * _env(n, 0.004, release) * vol


def silence(dur):
    return np.zeros(int(SR * dur))


def chord(freqs, dur, vol=0.5, release=0.12):
    mix = sum(tone(f, dur, vol=vol / len(freqs), release=release) for f in freqs)
    return mix


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    data = np.clip(samples, -1, 1)
    pcm = (data * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"  {name}: {os.path.getsize(path)} bytes, {len(pcm)/SR*1000:.0f}ms")


# tap — soft, very short click
save("tap.wav", tone(1150, 0.028, vol=0.32, attack=0.002, release=0.02))

# valid — bright rising two-note blip
save("valid.wav", np.concatenate([
    tone(720, 0.055, vol=0.45, release=0.02),
    tone(1080, 0.10, vol=0.5, release=0.06),
]))

# invalid — low descending buzz
save("invalid.wav", glide(230, 150, 0.20, vol=0.5, release=0.08))

# warn — two quick urgent beeps
save("warn.wav", np.concatenate([
    tone(900, 0.07, vol=0.5, release=0.03),
    silence(0.05),
    tone(900, 0.09, vol=0.5, release=0.05),
]))

# start — quick ascending triad (C5 E5 G5)
save("start.wav", np.concatenate([
    tone(523.25, 0.06, vol=0.45, release=0.02),
    tone(659.25, 0.06, vol=0.45, release=0.02),
    tone(783.99, 0.12, vol=0.5, release=0.07),
]))

# end — resolved C-major chord
save("end.wav", chord([523.25, 659.25, 783.99], 0.42, vol=0.55, release=0.18))

# rankup — celebratory ascending fanfare for climbing to the next rank tier.
# Bright 8-bit arpeggio (C5 E5 G5 C6) capped with a sparkling C-major chord, so
# a level-up sounds clearly different from an ordinary accepted word.
save("rankup.wav", np.concatenate([
    tone(523.25, 0.075, kind="square", vol=0.40, release=0.02),   # C5
    tone(659.25, 0.075, kind="square", vol=0.40, release=0.02),   # E5
    tone(783.99, 0.075, kind="square", vol=0.42, release=0.02),   # G5
    tone(1046.50, 0.11, kind="square", vol=0.46, release=0.03),   # C6
    chord([523.25, 659.25, 783.99, 1046.50], 0.36, vol=0.5, release=0.20),
]))

print("done")

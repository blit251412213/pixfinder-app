#!/usr/bin/env python3
"""Synthesize an original ~15s funk groove and report beat timing."""
import numpy as np, json, wave, struct

SR = 44100
BPM = 112.0
beat = 60.0 / BPM          # quarter-note seconds
step = beat / 4.0          # 16th-note seconds
BARS = 8
total = BARS * 4 * beat
N = int(total * SR)
t = np.arange(N) / SR

rng = np.random.default_rng(7)

def env(length, a=0.002, d=0.08, mode="exp", sustain=0.0, rel=0.02):
    n = int(length * SR)
    e = np.zeros(n)
    ai = max(1, int(a * SR))
    e[:ai] = np.linspace(0, 1, ai)
    if mode == "exp":
        di = n - ai
        e[ai:] = np.exp(-np.arange(di) / SR / d)
    else:  # ad-ish with sustain
        di = max(1, int(d * SR))
        end = min(n, ai + di)
        e[ai:end] = np.linspace(1, sustain, end - ai)
        e[end:] = sustain
        ri = max(1, int(rel * SR))
        e[-ri:] *= np.linspace(1, 0, ri)
    return e

def place(buf, sig, at):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[: j - i]

def semis(base, s):
    return base * 2 ** (s / 12.0)

# ---- voices -------------------------------------------------------------
def kick(vel=1.0):
    d = 0.32
    n = int(d * SR); tt = np.arange(n) / SR
    f = 115 * np.exp(-tt * 30) + 46
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-tt * 9)
    click = (rng.random(n) * 2 - 1) * np.exp(-tt * 220) * 0.4
    return (body + click) * vel

def snare(vel=1.0):
    d = 0.22
    n = int(d * SR); tt = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # crude highpass via diff
    noise = np.diff(noise, prepend=0)
    tone = (np.sin(2*np.pi*180*tt) + 0.6*np.sin(2*np.pi*330*tt)) * np.exp(-tt*22)
    return (noise * np.exp(-tt * 16) * 0.9 + tone * 0.5) * vel

def hat(vel=1.0, open_=False):
    d = 0.16 if open_ else 0.045
    n = int(d * SR); tt = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = np.diff(noise, prepend=0)
    noise = np.diff(noise, prepend=0)  # steeper highpass
    return noise * np.exp(-tt * (40 if open_ else 95)) * 0.5 * vel

def bass(s, dur, vel=1.0):
    f = semis(41.2, s)  # E1 base
    n = int(dur * SR); tt = np.arange(n) / SR
    saw = 0.0
    for k in range(1, 9):
        saw += np.sin(2*np.pi*f*k*tt) / k
    sub = np.sin(2*np.pi*f*tt)
    e = env(dur, a=0.004, d=dur*0.6, mode="exp")
    # pluck brightness fades
    bright = np.exp(-tt * 7)
    sig = (sub * 0.9 + saw * 0.35 * bright) * e
    return sig * vel * 0.9

def clav(chord, dur, vel=1.0):
    n = int(dur * SR); tt = np.arange(n) / SR
    sig = np.zeros(n)
    for s in chord:
        f = semis(164.8, s)  # E3 base
        for k in (1, 2, 3, 4):
            sig += np.sin(2*np.pi*f*k*tt + rng.random()) / (k*1.3)
    e = env(dur, a=0.002, d=dur*0.5, mode="exp")
    bright = np.exp(-tt * 18)
    return sig * e * (0.5 + 0.5*bright) * vel * 0.18

def stab(chord, dur, vel=1.0):
    # brass-ish chord stab for accents
    n = int(dur * SR); tt = np.arange(n) / SR
    sig = np.zeros(n)
    for s in chord:
        f = semis(164.8, s)
        det = [0, 0.18, -0.18]
        for dd in det:
            saw = 0.0
            for k in range(1, 7):
                saw += np.sin(2*np.pi*(f+dd)*k*tt) / k
            sig += saw
    e = env(dur, a=0.006, d=dur*0.55, mode="ad", sustain=0.5, rel=0.04)
    return sig * e * vel * 0.05

# ---- patterns (16 steps per bar) ---------------------------------------
KICK = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,0,1,0]
SNR  = [0,0,0,0, 1,0,0,0, 0,0,1,0, 1,0,0,0]
HAT  = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]
HATA = [1,0,.6,0, 1,0,.6,0, 1,0,.6,0, 1,0,.7,.5]   # accents
HOPEN= [0,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,1]
# bass: semitone offsets from E1, None=rest
B = None
BASS = [0,B,B,0, B,0,B,12, B,7,B,B, 0,B,10,B]
Em7 = [0,3,7,10]        # E G B D
CLAV = [0,0,1,0, 0,1,0,0, 0,1,0,1, 0,0,1,0]

mix = np.zeros(N + SR)
beat_times = []
snare_times = []
accent_times = []

for bar in range(BARS):
    bar_t = bar * 4 * beat
    for s in range(16):
        ts = bar_t + s * step
        if KICK[s]:
            place(mix, kick(0.95 if s == 0 else 0.85), ts)
        if SNR[s]:
            place(mix, snare(0.9), ts); snare_times.append(ts)
        if HAT[s]:
            v = HATA[s] if HATA[s] else 0.35
            place(mix, hat(0.5 * v), ts)
        if HOPEN[s]:
            place(mix, hat(0.6, open_=True), ts)
        if BASS[s] is not None:
            place(mix, bass(BASS[s], step*1.9, 0.95), ts)
        if CLAV[s]:
            place(mix, clav(Em7, step*1.3, 0.9), ts)
    # quarter-note beat grid + section stabs
    for q in range(4):
        bt = bar_t + q * beat
        beat_times.append(bt)
    # big stab at start of every 2 bars = "drop"
    if bar % 2 == 0:
        place(mix, stab(Em7, beat*1.5, 1.0), bar_t)
        accent_times.append(bar_t)

mix = mix[:N]
# light bus compression / soft clip + normalize
mix = np.tanh(mix * 1.3)
mix /= np.max(np.abs(mix)) + 1e-9
mix *= 0.95
# tiny stereo width: delay one channel a hair + clav pan feel
L = mix.copy()
Rr = np.concatenate([np.zeros(12), mix])[:N] * 0.98
stereo = np.stack([L, Rr * 0.0 + mix * 1.0], axis=1)  # keep mostly mono-safe
stereo[:, 0] = mix
stereo[:, 1] = mix * 0.97 + np.concatenate([np.zeros(15), mix])[:N] * 0.06

# fade out last 0.4s
fo = int(0.4 * SR)
stereo[-fo:] *= np.linspace(1, 0, fo)[:, None]

# write 16-bit wav
data = (np.clip(stereo, -1, 1) * 32767).astype(np.int16)
with wave.open("funk.wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(data.tobytes())

json.dump({
    "bpm": BPM, "beat": beat, "duration": total,
    "beats": beat_times, "snares": snare_times, "accents": accent_times,
}, open("beats.json", "w"), indent=1)

print(f"funk.wav {total:.2f}s | beat={beat:.4f}s | snares={len(snare_times)} accents={len(accent_times)}")

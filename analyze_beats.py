#!/usr/bin/env python3
"""Detect tempo + downbeat phase of song_mono.wav for punch syncing."""
import numpy as np, wave, json

w = wave.open("song_mono.wav", "rb")
sr = w.getframerate(); n = w.getnframes()
x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32) / 32768.0
dur = len(x) / sr

# --- onset envelope via spectral flux ---
win = 2048; hop = 512
w_h = np.hanning(win)
frames = 1 + (len(x) - win) // hop
mag = np.zeros((frames, win // 2 + 1))
for i in range(frames):
    seg = x[i*hop:i*hop+win] * w_h
    mag[i] = np.abs(np.fft.rfft(seg))
flux = np.maximum(0, np.diff(mag, axis=0)).sum(axis=1)
flux = np.concatenate([[0], flux])
flux -= flux.mean(); flux = np.maximum(0, flux)
flux /= flux.max() + 1e-9
fps_env = sr / hop                       # onset-env frames per second

# --- tempo via autocorrelation (search 70-180 BPM) ---
ac = np.correlate(flux, flux, "full")[len(flux)-1:]
lo = int(fps_env * 60/180); hi = int(fps_env * 60/70)
lag = lo + np.argmax(ac[lo:hi])
period = lag / fps_env
bpm = 60 / period

# --- phase: offset in [0,period) that best lines up with onsets ---
tgrid = np.arange(frames) / fps_env
best_phi, best_s = 0.0, -1
for phi in np.linspace(0, period, 60, endpoint=False):
    bt = np.arange(phi, dur, period)
    idx = np.clip((bt * fps_env).astype(int), 0, frames-1)
    s = flux[idx].sum()
    if s > best_s: best_s, best_phi = s, phi

beats = list(np.arange(best_phi, dur, period))
print(f"dur={dur:.2f}s  bpm={bpm:.1f}  period={period:.4f}s  phi={best_phi:.3f}s  nbeats={len(beats)}")
print("first beats:", [round(b,3) for b in beats[:8]])
json.dump({"sr":sr,"dur":dur,"bpm":bpm,"period":period,"phi":best_phi,
           "beats":beats}, open("song_beats.json","w"))

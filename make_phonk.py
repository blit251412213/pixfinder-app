#!/usr/bin/env python3
"""Synthesize an original ~25.6s drift-phonk beat (cowbell, 808, hats)."""
import numpy as np, json, wave

SR = 44100
BPM = 150.0
beat = 60.0 / BPM        # 0.4s
step = beat / 4.0        # 0.1s  (16th)
BARS = 16
total = BARS * 4 * beat  # 25.6s
N = int(total * SR)
rng = np.random.default_rng(11)

def place(buf, sig, at):
    i = int(at * SR); j = min(len(buf), i + len(sig))
    if i < len(buf): buf[i:j] += sig[:j-i]

def semis(base, s): return base * 2 ** (s/12.0)

def sq(f, tt, n=9):
    o = np.zeros_like(tt)
    for k in range(1, n+1, 2): o += np.sin(2*np.pi*f*k*tt)/k
    return o

# ---- voices -----------------------------------------------------------
def kick(vel=1.0):
    d=0.28; n=int(d*SR); tt=np.arange(n)/SR
    f=150*np.exp(-tt*32)+50
    ph=2*np.pi*np.cumsum(f)/SR
    body=np.sin(ph)*np.exp(-tt*11)
    click=(rng.random(n)*2-1)*np.exp(-tt*260)*0.5
    return np.tanh((body+click)*1.4)*vel

def b808(semi, dur, vel=1.0, slide=None):
    n=int(dur*SR); tt=np.arange(n)/SR
    f0=semis(55.0, semi)            # ~A1 region, deep
    if slide is not None:
        fs=semis(55.0, slide)
        g=np.exp(-tt*55); f=fs*g+f0*(1-g)
    else:
        f=np.full(n,f0)
    ph=2*np.pi*np.cumsum(f)/SR
    e=np.exp(-tt*3.0); e[:int(0.005*SR)]*=np.linspace(0,1,int(0.005*SR))
    sig=np.sin(ph)*e
    return np.tanh(sig*4.0)*0.6*vel    # gritty distortion

def cowbell(semi, dur, vel=1.0):
    n=int(dur*SR); tt=np.arange(n)/SR
    f1=semis(540.0, semi); f2=semis(800.0, semi)
    tone=sq(f1,tt,7)*0.6+sq(f2,tt,7)*0.5
    e=np.exp(-tt*9.0); e[:int(0.002*SR)]*=np.linspace(0,1,int(0.002*SR))
    sig=np.tanh(tone*e*2.2)
    return sig*0.5*vel

def clap(vel=1.0):
    d=0.2; n=int(d*SR); tt=np.arange(n)/SR
    out=np.zeros(n)
    for off in (0,0.008,0.016):                 # layered claps
        s=int(off*SR); ln=n-s
        out[s:]+=rng.standard_normal(ln)*np.exp(-np.arange(ln)/SR*45)
    crack=np.sin(2*np.pi*1800*tt)*np.exp(-tt*40)*0.3
    out=np.diff(out,prepend=0)
    return (out*0.5+crack)*vel

def hat(vel=1.0, open_=False):
    d=0.12 if open_ else 0.04; n=int(d*SR); tt=np.arange(n)/SR
    nz=rng.standard_normal(n); nz=np.diff(nz,prepend=0); nz=np.diff(nz,prepend=0)
    return nz*np.exp(-tt*(28 if open_ else 110))*0.4*vel

# ---- patterns ---------------------------------------------------------
# cowbell riff over 2 bars (32 sixteenth steps), semitone offsets / None
_=None
RIFF=[0,_,0,_, 3,_,0,_, _,_,7,_, 5,_,3,_,  0,_,0,_, 3,_,5,_, 7,_,5,_, 3,_,0,_]
# 808 notes per 2 bars (root movement), (step, semi)
B808=[(0,0),(6,0),(10,3),(0+16,0),(6+16,7),(12+16,5)]
KICK=[0,10]                      # steps within a bar
SNAR=[4,12]                      # backbeats
HATV=[1,.5,.7,.5]*4              # 16 steps accent pattern

mix=np.zeros(N+SR)
for bar in range(BARS):
    bt=bar*4*beat
    # kick
    for s in KICK: place(mix, kick(0.95), bt+s*step)
    # snare/clap backbeat
    for s in SNAR: place(mix, clap(0.85), bt+s*step)
    # hats (16) + rolls every 4th bar on last beat
    for s in range(16):
        place(mix, hat(0.45*HATV[s]), bt+s*step)
    if bar%4==3:
        for r in range(3):
            place(mix, hat(0.5), bt+15*step+r*step/3)
    if bar%8==6:
        place(mix, hat(0.6, open_=True), bt+14*step)

# cowbell riff (loops every 2 bars)
for ph in range(BARS//2):
    base=ph*2*4*beat
    for s,note in enumerate(RIFF):
        if note is not None:
            place(mix, cowbell(note, step*1.8, 0.9), base+s*step)
# 808 (loops every 2 bars), with slides on phrase starts
for ph in range(BARS//2):
    base=ph*2*4*beat
    prev=None
    for (s,note) in B808:
        sl = prev if (s in (16,) and prev is not None) else None
        place(mix, b808(note, step*5.5, 0.95, slide=sl), base+s*step)
        prev=note

mix=mix[:N]
mix=np.tanh(mix*1.15)
mix/=np.max(np.abs(mix))+1e-9
mix*=0.96
# subtle stereo
L=mix.copy(); R=mix*0.97+np.concatenate([np.zeros(14),mix])[:N]*0.05
st=np.stack([L,R],axis=1)
fo=int(0.5*SR); st[-fo:]*=np.linspace(1,0,fo)[:,None]
fi=int(0.01*SR); st[:fi]*=np.linspace(0,1,fi)[:,None]

data=(np.clip(st,-1,1)*32767).astype(np.int16)
with wave.open("phonk.wav","wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

json.dump({"bpm":BPM,"beat":beat,"bar":4*beat,"duration":total}, open("phonk_beats.json","w"))
print(f"phonk.wav {total:.2f}s | beat={beat}s | bar={4*beat}s | rms={np.sqrt((mix**2).mean()):.3f}")

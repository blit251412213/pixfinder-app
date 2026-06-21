#!/usr/bin/env python3
"""Build the phonk TikTok montage with beat-synced zoom/shake."""
import subprocess, json

U = "/root/.claude/uploads/2ba1d80d-2350-5725-9543-aa4229e54926"
ORIG = f"{U}/3b5ee041-Screen_Recording_20260618_213610.mp4"
C1   = f"{U}/8f526b39-Screen_Recording_20260619_103653.mp4"
C2   = f"{U}/7a1efb50-Screen_Recording_20260619_111328.mp4"
SONG = "song.m4a"               # audio supplied by the user
OUT  = "tiktok_final.mp4"

# (input_index, start, dur) — cuts land on bars (1.6s); 25.6s total = 16 bars
SEGS = [
    (0, 0.5, 6.4),   # original  (4 bars)
    (1, 1.5, 6.4),   # c1        (4 bars)
    (2, 1.5, 4.8),   # c2        (3 bars)
    (0, 8.0, 1.6),   # rapid 1-bar cuts -> climax
    (1, 9.5, 1.6),
    (2, 9.5, 1.6),
    (0, 10.5, 1.6),
    (1, 12.0, 1.6),
]

# ---- beat math locked to the supplied song (30fps -> T = frame/30) ----
bd  = json.load(open("song_beats.json"))
P   = round(bd["period"], 5)      # detected beat period
PHI = round(bd["phi"], 5)         # detected downbeat offset
P2  = round(2*bd["period"], 5)    # every-other (strong) beat
T   = "(on/30)"
PB  = f"(({T}-{PHI})-{P}*floor(({T}-{PHI})/{P}))"      # phase within a beat
PS  = f"(({T}-{PHI})-{P2}*floor(({T}-{PHI})/{P2}))"    # phase within strong beat
# Gentle, lowered intensity (closer to the example): soft punch every beat,
# a touch more on the strong beat. No huge snap.
Z   = f"(1.05+0.07*exp(-{PB}*11)+0.06*exp(-{PS}*7))"
AMP = f"(6*exp(-{PB}*13)+11*exp(-{PS}*8))"
SX  = f"({AMP}*sin(220*{T}))"
SY  = f"({AMP}*0.85*sin(173*{T}+1.0))"

# ---- per-segment formatting to 1080x1920 (blurred bg + centered fg) ----
parts = []
labels = []
for i, (idx, s, d) in enumerate(SEGS):
    parts.append(
        f"[{idx}:v]trim=start={s}:duration={d},setpts=PTS-STARTPTS,split=2[a{i}][b{i}];"
        f"[a{i}]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,"
        f"gblur=sigma=24,eq=brightness=-0.16:saturation=1.05[bg{i}];"
        f"[b{i}]scale=1080:-2[fg{i}];"
        f"[bg{i}][fg{i}]overlay=(W-w)/2:(H-h)/2,setsar=1[seg{i}];"
    )
    labels.append(f"[seg{i}]")

concat = "".join(labels) + f"concat=n={len(SEGS)}:v=1:a=0[cat];"
finish = (
    "[cat]eq=contrast=1.08:saturation=1.18:brightness=0.01:gamma=0.96,unsharp=5:5:0.5,"
    # snap-zoom punch + shake at 30fps...
    f"zoompan=z='{Z}':x='(iw-iw/zoom)/2+{SX}':y='(ih-ih/zoom)/2+{SY}':d=1:s=1080x1920:fps=30,"
    # ...light frame-blend (2 neighbours) for a soft smear on the punch
    "tmix=frames=2,"
    "vignette=PI/4.6,noise=alls=2:allf=t,format=yuv420p[v]"
)
fc = "".join(parts) + concat + finish

cmd = [
    "ffmpeg", "-y",
    "-i", ORIG, "-i", C1, "-i", C2, "-i", SONG,
    "-filter_complex", fc,
    "-map", "[v]", "-map", "3:a",
    "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p", "-r", "30",
    "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
    "-max_muxing_queue_size", "1024",
    "-movflags", "+faststart", "-shortest", OUT,
]
print("running ffmpeg...")
r = subprocess.run(cmd, stderr=subprocess.PIPE, text=True)
print(r.stderr[-1200:])
print("exit", r.returncode)

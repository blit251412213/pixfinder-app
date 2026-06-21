#!/usr/bin/env python3
"""Digging->base edit: trimmed dig, grey freeze, beat-shake circling. 3 passes."""
import subprocess, json

U = "/root/.claude/uploads/2ba1d80d-2350-5725-9543-aa4229e54926"
MOV  = f"{U}/12f3d827-copy_279D250D58C14942931E35585A2E4E87.mov"   # digging clip
C1   = f"{U}/8f526b39-Screen_Recording_20260619_103653.mp4"
C2   = f"{U}/7a1efb50-Screen_Recording_20260619_111328.mp4"
SONG = "song.m4a"

def fmt(src, out):
    """blurred-bg 1080x1920 + grade for a labelled stream src -> out"""
    return (f"{src}split=2[{out}a][{out}b];"
            f"[{out}a]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,"
            f"gblur=sigma=24,eq=brightness=-0.16:saturation=1.05[{out}bg];"
            f"[{out}b]scale=1080:-2[{out}fg];"
            f"[{out}bg][{out}fg]overlay=(W-w)/2:(H-h)/2,"
            f"eq=contrast=1.08:saturation=1.16:brightness=0.01:gamma=0.97,unsharp=5:5:0.5,"
            f"setsar=1,fps=30[{out}];")

# ---------- PASS 1: content montage (video only, 30fps) ----------
# edit timeline (boundaries on the song's beat grid 0.291 + n*0.4992):
#   dig    0.000 -> 5.291   (mov 3.0 -> 8.291)
#   freeze 5.291 -> 6.791   (1.5s grey hold of mov@11.5)
#   circle 6.791 ->14.791   (mov 11.4 -> 19.4)
#   c1    14.791 ->19.791   (c1  2.0 -> 7.0)
#   c2    19.791 ->25.070   (c2  2.0 -> 7.279)
# build the per-segment format chains
parts = []
parts.append("[0:v]trim=3.0:8.291,setpts=PTS-STARTPTS[dig0];" + fmt("[dig0]", "dig"))
parts.append("[0:v]trim=11.4:19.4,setpts=PTS-STARTPTS[cir0];" + fmt("[cir0]", "cir"))
parts.append("[1:v]trim=2.0:7.0,setpts=PTS-STARTPTS[c10];"  + fmt("[c10]", "c1s"))
parts.append("[2:v]trim=2.0:7.279,setpts=PTS-STARTPTS[c20];" + fmt("[c20]", "c2s"))
# freeze (png input 3, looped) -> format -> desaturate + light grey wash
parts.append(
    fmt("[3:v]", "frz0")
    + "[frz0]eq=saturation=0.32:brightness=0.04:contrast=0.98,"
      "drawbox=x=0:y=0:w=iw:h=ih:color=0x9b9b9b@0.30:t=fill,fps=30[frz];"
)
concat = "[dig][frz][cir][c1s][c2s]concat=n=5:v=1:a=0[base]"
fc1 = "".join(parts) + concat

cmd1 = ["ffmpeg", "-y",
    "-i", MOV, "-i", C1, "-i", C2,
    "-loop", "1", "-t", "1.5", "-i", "freeze.png",
    "-filter_complex", fc1, "-map", "[base]",
    "-c:v", "libx264", "-preset", "medium", "-crf", "16", "-pix_fmt", "yuv420p", "-r", "30",
    "base.mp4"]

# ---------- PASS 2: 60fps + gated beat shake + motion blur (video only) ----------
bd = json.load(open("song_beats.json"))
P = round(bd["period"], 5); PHI = round(bd["phi"], 5); P2 = round(2*bd["period"], 5)
T = "(on/60)"
PB = f"(({T}-{PHI})-{P}*floor(({T}-{PHI})/{P}))"
PS = f"(({T}-{PHI})-{P2}*floor(({T}-{PHI})/{P2}))"
# gate: shakes OFF until the freeze ends (edit t=6.791), then ON (comma-free step)
G  = f"(0.5+0.5*({T}-6.791)/(abs({T}-6.791)+0.0001))"
Z  = f"(1.05+{G}*(0.07*exp(-{PB}*11)+0.06*exp(-{PS}*7)))"
AMP= f"({G}*(6*exp(-{PB}*13)+11*exp(-{PS}*8)))"
SX = f"({AMP}*sin(220*{T}))"
SY = f"({AMP}*0.85*sin(173*{T}+1.0))"
fc2 = (f"[0:v]fps=60,zoompan=z='{Z}':x='(iw-iw/zoom)/2+{SX}':y='(ih-ih/zoom)/2+{SY}':"
       f"d=1:s=1080x1920:fps=60,tmix=frames=2,vignette=PI/4.6,noise=alls=2:allf=t,"
       f"format=yuv420p[v]")
cmd2 = ["ffmpeg", "-y", "-i", "base.mp4", "-filter_complex", fc2, "-map", "[v]",
    "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-r", "60",
    "shaken.mp4"]

# ---------- PASS 3: mux user's song ----------
cmd3 = ["ffmpeg", "-y", "-i", "shaken.mp4", "-i", SONG,
    "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
    "-movflags", "+faststart", "-shortest", "tiktok_dig.mp4"]

import os
passes = [cmd1, cmd2, cmd3]
if os.path.exists("base.mp4") and os.environ.get("SKIP1"):
    passes[0] = None
for i, c in enumerate(passes, 1):
    print(f"\n=== PASS {i} ===")
    if c is None:
        print("skipped (base.mp4 exists)"); continue
    r = subprocess.run(c, stderr=subprocess.PIPE, text=True)
    if r.returncode != 0:
        print(r.stderr[-1500:]); print("FAILED pass", i); break
    print("ok")
else:
    print("\nALL DONE -> tiktok_dig.mp4")

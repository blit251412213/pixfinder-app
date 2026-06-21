#!/usr/bin/env bash
set -e
IN="/root/.claude/uploads/2ba1d80d-2350-5725-9543-aa4229e54926/3b5ee041-Screen_Recording_20260618_213610.mp4"
OUT="tiktok_funk.mp4"

# beat math driven by frame number (zoompan can't use 't', so T = on/30)
T="(on/30)"
P=0.535714        # quarter-note beat
A=4.285714        # accent / "drop" period (2 bars)

# per-beat phase, accent phase, snare-backbeat phase (comma-free)
PB="(${T}-${P}*floor(${T}/${P}))"
PA="(${T}-${A}*floor(${T}/${A}))"
PS="((${T}-${P})-1.071429*floor((${T}-${P})/1.071429))"

# zoom: base + sharp punch every beat + bigger swell on the drop
Z="(1.07+0.05*exp(-${PB}*11)+0.09*exp(-${PA}*5))"
# shake amplitude: snare backbeat hit + accent hit
AMP="(16*exp(-${PS}*15)+26*exp(-${PA}*7))"
SX="(${AMP}*sin(213.628*${T}))"
SY="(${AMP}*0.8*sin(169.646*${T}+1.0))"

FC="[0:v]split=2[a][b];\
[a]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,gblur=sigma=26,eq=brightness=-0.14:saturation=1.04[bg];\
[b]scale=1080:-2[fg];\
[bg][fg]overlay=(W-w)/2:(H-h)/2[comp];\
[comp]eq=contrast=1.07:saturation=1.17:brightness=0.012:gamma=0.97,unsharp=5:5:0.5[gr];\
[gr]zoompan=z='${Z}':x='(iw-iw/zoom)/2+${SX}':y='(ih-ih/zoom)/2+${SY}':d=1:s=1080x1920:fps=30,\
vignette=PI/4.6,noise=alls=4:allf=t,setsar=1,format=yuv420p[v]"

ffmpeg -y -i "$IN" -i funk.wav -filter_complex "$FC" \
  -map "[v]" -map 1:a \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 192k -ar 48000 \
  -movflags +faststart -shortest "$OUT"

echo "=== done ==="
ffprobe -v error -show_entries format=duration -show_entries stream=codec_type,width,height -of default=noprint_wrappers=1 "$OUT"

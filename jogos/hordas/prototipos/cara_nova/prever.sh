#!/bin/bash
# uso: prev.sh <prefixo sem _albedo> <saida.png> [zoom] ; junta albedo, normal e emissao (se tiver) sobre cinza
P="$1"; OUT="$2"; Z="${3:-3}"
A="${P}_albedo.png"; N="${P}_normal.png"; E="${P}_emissao.png"
W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$A")
H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$A")
if [ -f "$E" ]; then
ffmpeg -y -loglevel error -f lavfi -i color=c=0x5a5a64:s=${W}x${H} -i "$A" -i "$N" -i "$E" -filter_complex "[0]split=3[b1][b2][b3];[b1][1]overlay[x1];[b2][2]overlay[x2];[b3][3]overlay[x3];[x1][x2][x3]hstack=inputs=3,scale=iw*${Z}:ih*${Z}:flags=neighbor" -frames:v 1 "$OUT"
else
ffmpeg -y -loglevel error -f lavfi -i color=c=0x5a5a64:s=${W}x${H} -i "$A" -i "$N" -filter_complex "[0]split=2[b1][b2];[b1][1]overlay[x1];[b2][2]overlay[x2];[x1][x2]hstack=inputs=2,scale=iw*${Z}:ih*${Z}:flags=neighbor" -frames:v 1 "$OUT"
fi

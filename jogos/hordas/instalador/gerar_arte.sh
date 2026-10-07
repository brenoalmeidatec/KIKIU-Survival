#!/usr/bin/env bash
# Gera a arte do assistente do instalador Inno Setup, em BMP 24 bits, a partir da folha do cavaleiro (docs/imagens/cavaleiro.png)
# e do escudo do ícone (projeto/assets/icone). Pixel art: recorte 1:1 e ampliação inteira com vizinho mais próximo, sem filtro.
# Precisa do ffmpeg no PATH. Saída nesta pasta: wizard_164x314.bmp, wizard_328x628.bmp, small_55x58.bmp, small_110x116.bmp.
set -e
cd "$(dirname "$0")"
FOLHA=../../../docs/imagens/cavaleiro.png
FONTE=../projeto/assets/fonte/PressStart2P.ttf
ICONE=../projeto/assets/icone/kikiu_48.png
FUNDO=0x16131f

# Quadro frontal do cavaleiro (x 18..100, y 22..179 da folha: 82x157) ampliado 2x = 164x314; faixa escura embaixo e o nome.
ffmpeg -hide_banner -loglevel error -y -i "$FOLHA" -vf "crop=82:157:18:22,scale=164:314:flags=neighbor,drawbox=x=0:y=236:w=164:h=78:color=black@0.6:t=fill,vignette=PI/4,drawtext=fontfile=$FONTE:text=K.I.K.I.U:fontsize=16:fontcolor=0x8ab4ff:shadowx=1:shadowy=1:shadowcolor=black:x=(w-text_w)/2:y=268" -pix_fmt bgr24 wizard_164x314.bmp

# Mesma composição em 4x = 328x628, com o nome em 32 px.
ffmpeg -hide_banner -loglevel error -y -i "$FOLHA" -vf "crop=82:157:18:22,scale=328:628:flags=neighbor,drawbox=x=0:y=472:w=328:h=156:color=black@0.6:t=fill,vignette=PI/4,drawtext=fontfile=$FONTE:text=K.I.K.I.U:fontsize=32:fontcolor=0x8ab4ff:shadowx=2:shadowy=2:shadowcolor=black:x=(w-text_w)/2:y=536" -pix_fmt bgr24 wizard_328x628.bmp

# Miniatura do escudo (3x = 48 px) centrada num quadro 55x58; em 2x o escudo vira 96 px num quadro 110x116.
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "color=c=$FUNDO:s=55x58" -i "$ICONE" -filter_complex "[0:v][1:v]overlay=x=4:y=5" -frames:v 1 -pix_fmt bgr24 small_55x58.bmp

ffmpeg -hide_banner -loglevel error -y -f lavfi -i "color=c=$FUNDO:s=110x116" -i "$ICONE" -filter_complex "[1:v]scale=96:96:flags=neighbor[e];[0:v][e]overlay=x=7:y=10" -frames:v 1 -pix_fmt bgr24 small_110x116.bmp

ls -l wizard_164x314.bmp wizard_328x628.bmp small_55x58.bmp small_110x116.bmp

#!/usr/bin/env python3
"""Medidor de piscada LOCAL num clipe do Movie Maker (revisão do Q do LightWolf, 05/11/2026).

Procura, em células finas da tela, o padrão claro-escuro-claro rápido: um pico, um vale e outro pico
dentro de `--janela` quadros, com profundidade (o menor dos dois picos menos o vale) de `--prof` ou mais.
É o defeito que a média do quadro inteiro não pega (uma bola clara que apaga na fumaça escura e, logo
depois, um bloco claro no mesmo lugar). Lê os PNG `q*.png` do `--write-movie`, reduz para 960x540 (o
mundo do jogo; a saída sai maior quando o Windows amplia a janela) e mede a luminância média de cada
célula de 960/`--div` x 540/`--div` px (div 20 = 48x27 px).

Uso (fora do repositório; os quadros não se versionam):
  godot_fila.ps1 --path . --resolution 960x540 --write-movie <dir>/q.png --fixed-fps 60 --quit-after 420 \
      res://v2/mundo.tscn ++ --roteiro=lw_q --heroi=lightwolf
  python ferramentas/medir_piscadas_video.py <dir> [--div 20] [--de 0] [--ate 9999] [--regiao x0,y0,x1,y1]

Para "Reduzir piscadas", grave com uma APPDATA própria que tenha kikiu/opcoes.cfg com
[opcoes] reduzir_piscadas=true. Atenção: duas gravações ao mesmo tempo podem pausar o jogo (perda de
foco); confira um quadro antes de confiar no número. O resultado é evidência, não teste de CI.
"""
import argparse
import glob
import os
import sys

import numpy as np
from PIL import Image


def carregar(d, de, ate):
    fs = sorted(glob.glob(os.path.join(d, "q*.png")))[de:ate]
    if not fs:
        sys.exit("nenhum q*.png em " + d)
    out = []
    for f in fs:
        im = Image.open(f).convert("L")
        if im.size != (960, 540):
            im = im.resize((960, 540), Image.BOX)
        out.append(np.asarray(im, dtype=np.float32))
    return np.array(out)


def achados(serie, janela, prof):
    """(pico1, vale, pico2, profundidade) de cada claro-escuro-claro em menos de `janela` quadros."""
    res = []
    n = len(serie)
    for i in range(n):
        seg = serie[i:min(n, i + janela)]
        if len(seg) < 3:
            continue
        k = int(np.argmin(seg))
        if k == 0 or k == len(seg) - 1:
            continue
        p1, p2, v = seg[:k].max(), seg[k + 1:].max(), seg[k]
        dep = min(p1, p2) - v
        if dep >= prof:
            res.append((i + int(np.argmax(seg[:k])), i + k, i + k + 1 + int(np.argmax(seg[k + 1:])), round(float(dep), 1)))
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--div", type=int, default=20)
    ap.add_argument("--janela", type=int, default=30, help="quadros (30 = 0,5 s a 60 fps)")
    ap.add_argument("--prof", type=float, default=20.0)
    ap.add_argument("--de", type=int, default=0)
    ap.add_argument("--ate", type=int, default=99999)
    ap.add_argument("--regiao", default="", help="x0,y0,x1,y1 no mundo 960x540: imprime a série dessa região")
    a = ap.parse_args()
    q = carregar(a.dir, a.de, a.ate)
    if a.regiao:
        x0, y0, x1, y1 = [int(v) for v in a.regiao.split(",")]
        print(" ".join("%d:%.0f" % (a.de + i, v) for i, v in enumerate(q[:, y0:y1, x0:x1].mean(axis=(1, 2)))))
        return
    ch, cw = 540 // a.div, 960 // a.div
    cel = q[:, :ch * a.div, :cw * a.div].reshape(len(q), a.div, ch, a.div, cw).mean(axis=(2, 4))
    total = 0
    for y in range(a.div):
        for x in range(a.div):
            r = achados(cel[:, y, x], a.janela, a.prof)
            if r:
                total += 1
                pior = max(r, key=lambda t: t[3])
                print("celula (%d,%d) px %d-%d x %d-%d: picos q%d/q%d, vale q%d, profundidade %.1f"
                      % (x, y, x * cw, (x + 1) * cw, y * ch, (y + 1) * ch, a.de + pior[0], a.de + pior[2], a.de + pior[1], pior[3]))
    print("celulas %dx%d px com claro-escuro-claro em menos de %d quadros e profundidade >= %.0f: %d" % (cw, ch, a.janela, a.prof, total))


if __name__ == "__main__":
    main()

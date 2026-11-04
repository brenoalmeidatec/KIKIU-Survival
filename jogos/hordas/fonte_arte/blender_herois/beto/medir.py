"""Mede a silhueta dos quadros de cor de uma animação (Python com Pillow+numpy): largura/altura por direção e se algo encosta na borda do quadro.

    python medir.py <anim>
"""
import os
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
DIRECOES = ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"]
anim = sys.argv[1]
pasta = os.path.join(AQUI, "quadros", anim)
n = 0
while os.path.exists(os.path.join(pasta, "baixo_%d_cor.png" % n)):
    n += 1
for d in DIRECOES:
    larg, alt, tocam, x0s, x1s, y1s = [], [], [], [], [], []
    for q in range(n):
        a = np.array(Image.open(os.path.join(pasta, "%s_%d_cor.png" % (d, q))).convert("RGBA"))[:, :, 3] > 127
        ys, xs = np.nonzero(a)
        larg.append(xs.max() - xs.min() + 1)
        alt.append(ys.max() - ys.min() + 1)
        x0s.append(xs.min())
        x1s.append(xs.max())
        y1s.append(ys.max())
        tocam.append(bool(a[0].any() or a[:, 0].any() or a[:, -1].any()))
    print("%-10s largura %2d..%2d  altura %2d..%2d  x %2d..%2d  pé(y) %d..%d  borda: %s" % (
        d, min(larg), max(larg), min(alt), max(alt), min(x0s), max(x1s), min(y1s), max(y1s), "TOCA" if any(tocam) else "ok"))

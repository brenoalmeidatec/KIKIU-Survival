"""Mede a densidade de pixel de um PNG: fração de janelas 2x2 uniformes e comprimento médio de corrida de cor.

Uso: python medir_piso.py arquivo.png [mais.png ...]
Pixel de arte em 1 px de verdade tem poucas janelas 2x2 uniformes e corridas curtas.
Regra de bolso deste projeto: 2x2 uniforme acima de 0.55 = chapado demais (blocos de 2-3 px).
A borda é circular (o piso é tile).
"""
import sys

import numpy as np
from PIL import Image


def _corridas(m):
    ig = (m[:, 1:] == m[:, :-1]).all(-1)
    tot = m.shape[0] * m.shape[1]
    quebras = (~ig).sum() + m.shape[0]
    return tot / quebras


def medir_array(im):
    """im: array HxWx4 uint8. Devolve (w, h, cores, frac_2x2, corrida_h, corrida_v)."""
    a = im[..., 3] > 0
    h, w = im.shape[:2]
    r = np.roll(im, -1, axis=1)
    d = np.roll(im, -1, axis=0)
    rd = np.roll(r, -1, axis=0)
    uni = (im == r).all(-1) & (im == d).all(-1) & (im == rd).all(-1) & a
    frac22 = uni.sum() / max(1, a.sum())
    cores = len(np.unique(im.reshape(-1, 4), axis=0))
    return w, h, cores, frac22, _corridas(im), _corridas(im.transpose(1, 0, 2))


def medir(caminho):
    return medir_array(np.array(Image.open(caminho).convert("RGBA")))


if __name__ == "__main__":
    print("arquivo | tam | cores | 2x2_uniforme | corrida_h | corrida_v")
    for c in sys.argv[1:]:
        w, h, n, f, ch, cv = medir(c)
        print(f"{c} | {w}x{h} | {n} | {f:.3f} | {ch:.2f} | {cv:.2f}")

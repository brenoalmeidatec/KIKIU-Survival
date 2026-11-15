"""Troca a paleta do mecha direto na folha pronta, sem Blender (15/11/2026, paleta "aço carvão e latão").

Para cada material, recalcula as 4 faixas (escura, sombra, base, luz) com a mesma conta do `estilizar` do gerar.py e troca cor por cor.
O resultado é o mesmo de mudar a PALETA do modelo.py e renderizar de novo; o alfa, o contorno e o clarão do tiro (#f2ffff) não mudam.
As cores NOVAS já estão no modelo.py e no gerar.py; este script só serve para repetir a troca numa folha ainda na paleta ANTIGA.

Uso: python recolorir_paleta.py folha_albedo.png [outra.png ...]   (regrava no lugar)
"""
import sys

import numpy as np
from PIL import Image

ANTIGA = {"Casco azul": "#5b9dd9", "Casco claro": "#e6f2ff", "Casco escuro": "#294d7b"}
NOVA = {"Casco azul": "#4f6480", "Casco claro": "#b48c3a", "Casco escuro": "#2f384c"}
SOLTAS = {"#b3e8ff": "#8ea9c4"}  # luz de recorte (o mix do gerar.py)


def hexa(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def mais(base, soma, mult):
    return tuple(min(255, max(0, round(base[i] * mult + soma[i] * 255))) for i in range(3))


def faixas(base):
    return [mais(base, (0.008, 0.014, 0.030), 0.24), mais(base, (0.008, 0.014, 0.024), 0.52), base, mais(base, (0.065, 0.075, 0.095), 1.12)]


def mapa():
    m = {}
    for nome in ANTIGA:
        for a, b in zip(faixas(hexa(ANTIGA[nome])), faixas(hexa(NOVA[nome]))):
            m[a] = b
    for a, b in SOLTAS.items():
        m[hexa(a)] = hexa(b)
    return m


def recolorir(caminho):
    img = np.array(Image.open(caminho).convert("RGBA"))
    saida = img.copy()
    opaco = img[..., 3] > 0
    trocados = 0
    for cor in np.unique(img[opaco][:, :3], axis=0):
        cor = tuple(int(c) for c in cor)
        for de, para in mapa().items():
            if max(abs(de[i] - cor[i]) for i in range(3)) <= 2:  # folga do arredondamento do render
                sel = opaco & (img[..., 0] == cor[0]) & (img[..., 1] == cor[1]) & (img[..., 2] == cor[2])
                saida[sel, :3] = para
                trocados += int(sel.sum())
                break
    Image.fromarray(saida).save(caminho, optimize=True)
    print("%s: %d px trocados (%.1f%% do opaco)" % (caminho, trocados, 100.0 * trocados / max(1, int(opaco.sum()))))


if __name__ == "__main__":
    for c in sys.argv[1:]:
        recolorir(c)

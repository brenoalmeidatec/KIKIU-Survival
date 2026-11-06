"""Folhas do pixelfx (MIT) redesenhadas na grade de 1 px do mundo (pixel art: um tamanho de pixel para tudo).

O jogo nao escala mais folha por fracao (0,45, 0,7...): isso mistura pixels de tamanhos diferentes. Aqui cada folha que era tocada em escala
fracionaria vira uma folha nova ja no tamanho final, e o jogo a toca em escala 1. Reducao quadro a quadro (nunca a folha inteira, para nao
borrar a borda entre quadros), com media em alfa pre-multiplicado e limpeza de pixel: alfa em poucos degraus, nada de pixel fantasma e nada
de pixel solto fraco (a faisca solta BRILHANTE fica: ela e o efeito).

Alem das folhas redesenhadas (FOLHAS), as que o jogo toca em escala 1 (UM_PARA_UM: spawn-portal do chefe, soul-rise, collect-burst)
tambem passam pelo mesmo fecho de pixel art: alfa em ate 6 degraus e paleta enxuta (fonte_arte/quantizar_alfa.py), porque a folha
original do pixelfx tem 250 niveis de transparencia e dezenas de milhares de cores.

Uso (a partir da raiz do repositorio):  python jogos/hordas/fonte_arte/pixelfx/gerar_folhas.py
Fontes: jogos/hordas/fonte_arte/pixelfx/originais/<categoria>/<nome>.png (folha original do pixelfx) ou, se nao houver la, a de
jogos/hordas/projeto/assets/v2/pixelfx/<categoria>/<nome>.png. Saida: assets/v2/pixelfx/<categoria>/<nome>-e<NN>.png (NN = escala x 100) e,
no fim, os numeros (quadro, colunas, quadros, pivo) para o dados/v2_pixelfx.json.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
ASSETS = os.path.join(RAIZ, "projeto", "assets", "v2", "pixelfx")
ORIGINAIS = os.path.join(AQUI, "originais")
sys.path.insert(0, os.path.join(AQUI, ".."))
from quantizar_alfa import MODO_BRILHO, quantizar_imagem  # noqa: E402  (fonte_arte/quantizar_alfa.py)

# nome, categoria, escala, quadro [w,h], colunas, quadros (so os usados), pivo [x,y]
FOLHAS = [
    ("spawn-portal", "spawn", 0.7, (208, 150), 10, 70, (104, 122)),
    ("spawn-portal", "spawn", 0.8, (208, 150), 10, 70, (104, 122)),
    ("summon-rise", "spawn", 0.45, (176, 116), 10, 44, (88, 94)),
    ("chest-open", "pickups", 0.8, (176, 112), 10, 80, (88, 96)),
    ("loot-beam", "pickups", 0.55, (96, 176), 12, 72, (48, 162)),
    ("level-up", "ui", 0.75, (176, 138), 9, 18, (88, 114)),
]

# folhas tocadas em escala 1, sem redesenho: nome, categoria, cores da paleta (a folha original fica em originais/ ou, se faltar, no jogo)
UM_PARA_UM = [
    ("spawn-portal", "spawn", 64),
    ("soul-rise", "spawn", 64),
    ("collect-burst", "pickups", 48),
]
# cores da paleta de cada folha redesenhada (nome da folha -> cores)
CORES = {"spawn-portal": 64, "summon-rise": 64, "chest-open": 64, "loot-beam": 48, "level-up": 64}

DEGRAUS = 6  # niveis de alfa (alem do zero)
ALFA_MIN = 0.12  # abaixo disso o pixel some (neblina que nao fecha um pixel)
SOLTO_FRACO = 0.5  # pixel sem vizinho com alfa e mais fraco que isso: some


def achar(cat: str, nome: str) -> str:
    for base in (ORIGINAIS, ASSETS):
        p = os.path.join(base, cat, nome + ".png")
        if os.path.exists(p):
            return p
    sys.exit("folha original nao encontrada: %s/%s" % (cat, nome))


def reduzir_quadro(q: np.ndarray, nw: int, nh: int) -> np.ndarray:
    """q: (h, w, 4) float 0..1, nao pre-multiplicado. Devolve (nh, nw, 4) limpo."""
    a = q[..., 3:4]
    pre = np.concatenate([q[..., :3] * a, a], axis=-1)
    canais = []
    for c in range(4):
        im = Image.fromarray(np.ascontiguousarray(pre[..., c]).astype(np.float32), mode="F")
        canais.append(np.asarray(im.resize((nw, nh), Image.BOX), dtype=np.float32))
    pre = np.stack(canais, axis=-1)
    alfa = pre[..., 3]
    cor = np.where(alfa[..., None] > 1e-6, pre[..., :3] / np.maximum(alfa[..., None], 1e-6), 0.0)
    # alfa em degraus, sem fantasma
    alfa = np.where(alfa < ALFA_MIN, 0.0, np.ceil(alfa * DEGRAUS) / DEGRAUS)
    alfa = np.clip(alfa, 0.0, 1.0)
    # pixel solto fraco
    viz = np.zeros_like(alfa, dtype=bool)
    pad = np.pad(alfa > 0, 1)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx or dy:
                viz |= pad[1 + dy : 1 + dy + alfa.shape[0], 1 + dx : 1 + dx + alfa.shape[1]]
    alfa = np.where((~viz) & (alfa < SOLTO_FRACO), 0.0, alfa)
    return np.concatenate([np.clip(cor, 0, 1), alfa[..., None]], axis=-1)


def gerar(nome, cat, esc, quadro, colunas, quadros, pivo):
    src = Image.open(achar(cat, nome)).convert("RGBA")
    w, h = quadro
    nw, nh = max(1, round(w * esc)), max(1, round(h * esc))
    linhas = math.ceil(quadros / colunas)
    out = Image.new("RGBA", (nw * colunas, nh * linhas), (0, 0, 0, 0))
    arr = np.asarray(src, dtype=np.float32) / 255.0
    for i in range(quadros):
        cx, cy = (i % colunas) * w, (i // colunas) * h
        r = reduzir_quadro(arr[cy : cy + h, cx : cx + w], nw, nh)
        out.paste(Image.fromarray((r * 255.0 + 0.5).astype(np.uint8), "RGBA"), ((i % colunas) * nw, (i // colunas) * nh))
    out = quantizar_imagem(out, DEGRAUS, CORES.get(nome, 64))
    sufixo = "-e%d" % round(esc * 100)
    dest = os.path.join(ASSETS, cat, nome + sufixo + ".png")
    out.save(dest, optimize=True)
    return {
        "arquivo": "%s/%s%s.png" % (cat, nome, sufixo),
        "quadro": [nw, nh],
        "colunas": colunas,
        "quadros": quadros,
        "pivo": [round(pivo[0] * esc), round(pivo[1] * esc)],
    }


def fechar_um_para_um(nome, cat, cores):
    """Folha em escala 1: mesmo tamanho e quadros, so alfa em degraus e paleta enxuta. Grava em assets/v2/pixelfx/<cat>/<nome>.png."""
    img = quantizar_imagem(Image.open(achar(cat, nome)).convert("RGBA"), DEGRAUS, cores, MODO_BRILHO)
    dest = os.path.join(ASSETS, cat, nome + ".png")
    img.save(dest, optimize=True)
    return "%s/%s.png" % (cat, nome)


if __name__ == "__main__":
    for f in FOLHAS:
        print(f[0], f[2], json.dumps(gerar(*f)))
    for f in UM_PARA_UM:
        print(f[0], "1x", fechar_um_para_um(*f))

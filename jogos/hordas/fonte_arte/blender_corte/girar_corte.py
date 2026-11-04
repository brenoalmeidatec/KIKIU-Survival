"""Gira a folha do corte (Blender) em 22,5, 45 e 67,5 graus, quadro a quadro, com RotSprite (pixel art sem pixel solto).

Por que: o corte da katana era um sprite de pixel art girado em tempo de execucao por qualquer angulo. Girar pixel art livre
mistura pixels de tamanhos diferentes. Agora o jogo escolhe uma de 16 direcoes (passos de 22,5 graus). Os quadros dos multiplos de 90
graus saem de uma troca exata de UV no shader (efeitos.gd), sem reamostrar. Estes tres arquivos por variante sao os unicos que precisam de
reamostragem; o 0 grau e a folha original (corte_hazaki_folha.png, a mesma de assets/v2/efeitos/).

Limite conhecido: o quad do corte tem o tamanho do quadro, entao o que o giro leva para fora do quadro (a folha tem conteudo ate ~83 px do
centro, fora do circulo inscrito de raio 64) e cortado nos giros de 22,5, 45 e 67,5 graus; antes, com o no girado, o quad inteiro girava e
nada se perdia. O AVISO abaixo lista os quadros afetados. Aceito: a perda e so nos cantos extremos do arco e nao muda o alcance do golpe.

Algoritmo (RotSprite de Xenowhirl): ampliar 8x com Scale2x tres vezes (EPX, so cria cor onde ja existe), girar por vizinho mais proximo
no quadro ampliado em volta do centro (64, 64), reduzir pegando o pixel do meio de cada bloco 8x8. Sem media, entao as cores e os alfas
de saida sao um subconjunto dos de entrada.

Convencao do angulo = a do Godot: rotacao positiva = sentido horario na tela (y para baixo).

Uso (de qualquer pasta):  python girar_corte.py
Saida: jogos/hordas/projeto/assets/v2/efeitos/corte_hazaki_r{1,2,3}.png e corte_hazaki_ciano_r{1,2,3}.png
"""

import math
import os
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "v2", "efeitos"))
QUADRO = 128
FATOR = 8  # 3 passadas de Scale2x
PASSOS = (1, 2, 3)  # x 22,5 graus
# (arquivo-fonte, lado do pixel da arte). A ciano e desenhada numa grade 2x2 (cada pixel da arte = bloco 2x2): gira-se a versao reduzida
# (64x64 por quadro) e amplia-se de volta por repeticao, senao o RotSprite giraria a grade de 2 px como se fosse de 1 px e sairia pixel misto.
VARIANTES = {"corte_hazaki": ("corte_hazaki_folha.png", 1), "corte_hazaki_ciano": ("corte_hazaki_ciano_folha.png", 2)}


def codificar(rgba: np.ndarray) -> np.ndarray:
    """RGBA 8 bits -> uint32. Alfa 0 vira 0 (o RGB de um pixel transparente nao conta)."""
    r, g, b, a = (rgba[..., i].astype(np.uint32) for i in range(4))
    cod = (r << 24) | (g << 16) | (b << 8) | a
    cod[a == 0] = 0
    return cod


def decodificar(cod: np.ndarray) -> np.ndarray:
    return np.stack([(cod >> 24) & 255, (cod >> 16) & 255, (cod >> 8) & 255, cod & 255], axis=-1).astype(np.uint8)


def scale2x(c: np.ndarray) -> np.ndarray:
    """Scale2x (AdvMAME2x): cada pixel vira 2x2; so copia a cor de um vizinho, nunca inventa."""
    p = np.pad(c, 1, mode="constant")
    P = p[1:-1, 1:-1]
    A, D = p[:-2, 1:-1], p[2:, 1:-1]  # cima, baixo
    C, B = p[1:-1, :-2], p[1:-1, 2:]  # esquerda, direita
    e0 = np.where((C == A) & (C != D) & (A != B), A, P)
    e1 = np.where((A == B) & (A != C) & (B != D), B, P)
    e2 = np.where((D == C) & (D != B) & (C != A), C, P)
    e3 = np.where((B == D) & (B != A) & (D != C), D, P)
    out = np.zeros((c.shape[0] * 2, c.shape[1] * 2), dtype=c.dtype)
    out[0::2, 0::2], out[0::2, 1::2], out[1::2, 0::2], out[1::2, 1::2] = e0, e1, e2, e3
    return out


def girar_quadro(q: np.ndarray, graus: float) -> np.ndarray:
    """q = quadro 128x128 codificado. Devolve o quadro girado `graus` (horario na tela)."""
    g = q
    for _ in range(3):
        g = scale2x(g)
    n = g.shape[0]
    th = math.radians(graus)
    c, s = math.cos(th), math.sin(th)
    ys, xs = np.mgrid[0:n, 0:n]
    dx, dy = xs + 0.5 - n / 2, ys + 0.5 - n / 2
    # fonte = R(-th) * (p - centro) + centro
    sx = np.floor(c * dx + s * dy + n / 2).astype(int)
    sy = np.floor(-s * dx + c * dy + n / 2).astype(int)
    ok = (sx >= 0) & (sx < n) & (sy >= 0) & (sy < n)
    rot = np.zeros_like(g)
    rot[ok] = g[sy[ok], sx[ok]]
    return rot[FATOR // 2 :: FATOR, FATOR // 2 :: FATOR]  # o pixel do meio de cada bloco 8x8


def processar(nome: str, arq: str, bloco: int) -> None:
    im = np.array(Image.open(os.path.join(AQUI, arq)).convert("RGBA"))
    assert im.shape[0] == QUADRO and im.shape[1] % QUADRO == 0, im.shape
    n = im.shape[1] // QUADRO
    cod = codificar(im)
    quadro = QUADRO // bloco
    if bloco > 1:
        peq = cod[::bloco, ::bloco]
        assert np.array_equal(np.repeat(np.repeat(peq, bloco, axis=0), bloco, axis=1), cod), "a fonte nao e uma grade %dx%d pura" % (bloco, bloco)
        cod = peq
    # o conteudo precisa caber no circulo inscrito (raio 64): fora dele um giro cortaria o canto
    ys, xs = np.mgrid[0:quadro, 0:quadro]
    fora_circ = ((xs + 0.5 - quadro / 2) ** 2 + (ys + 0.5 - quadro / 2) ** 2) > (quadro / 2) ** 2
    for k in range(n):
        q = cod[:, k * quadro : (k + 1) * quadro]
        if np.any(q[fora_circ] != 0):
            print("  AVISO: %s quadro %d tem conteudo fora do circulo inscrito (%d px)" % (nome, k, int(np.count_nonzero(q[fora_circ]))))
    cores_ent = set(np.unique(cod).tolist())
    for passo in PASSOS:
        saida = np.zeros_like(cod)
        for k in range(n):
            saida[:, k * quadro : (k + 1) * quadro] = girar_quadro(cod[:, k * quadro : (k + 1) * quadro], passo * 22.5)
        assert set(np.unique(saida).tolist()) <= cores_ent, "cor nova: houve suavizacao"
        saida = np.repeat(np.repeat(saida, bloco, axis=0), bloco, axis=1)
        destino = os.path.join(SAIDA, "%s_r%d.png" % (nome, passo))
        Image.fromarray(decodificar(saida), "RGBA").save(destino, optimize=True)
        print("%s: %s (%d quadros, %d cores de entrada, alfa total %d -> %d)" % (nome, os.path.basename(destino), n, len(cores_ent), int((cod & 255).sum()), int((saida & 255).sum()) // (bloco * bloco)))


if __name__ == "__main__":
    for nome, (arq, bloco) in VARIANTES.items():
        processar(nome, arq, bloco)
    sys.exit(0)

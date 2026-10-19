# -*- coding: utf-8 -*-
"""Folhas animadas dos projéteis da v2 (grupo "projeteis").

Gera, pixel a pixel e sem rede, as tiras de voo e impacto de 10 sprites (PRJ-A, PRJ-G e PRJ-B de
docs/animacoes_armas_v2.md), o índice indice_projeteis.json (esquema de docs/combate_v2/SPEC_ARTE.md) e as
prévias GIF 4x. Rodar de novo dá as mesmas folhas (semente fixa).

    python -I gerar_projeteis.py            # gera tudo e confere
    python -I gerar_projeteis.py --conferir # só confere as folhas já gravadas

Regras seguidas: alfa só 0 ou 255, contorno escuro de 1 px nos corpos, luz fixa de cima à esquerda (o brilho
acompanha a luz também nos quadros girados), poucos tons por material e limpeza automática de pixel solto
(só as cores declaradas como faísca podem ficar sozinhas).
"""
import hashlib
import json
import math
import os
import sys
from collections import Counter

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", "..", ".."))
SAIDA = os.path.join(RAIZ, "jogos", "hordas", "projeto", "assets", "v2", "armas_anim")
PREVIAS = os.path.join(RAIZ, "docs", "combate_v2", "previas")
FUNDO_PREVIA = (0x2A, 0x2A, 0x30)
LUZ = (-0.7071, -0.7071)  # de cima à esquerda (y cresce para baixo)
TAU = math.tau


# --------------------------------------------------------------------------------------------------------------
# Utilidades de pixel
# --------------------------------------------------------------------------------------------------------------
def novo(w, h):
    return np.zeros((h, w, 4), np.uint8)


def por(a, x, y, cor, vazio=False):
    h, w = a.shape[:2]
    x, y = int(x), int(y)
    if 0 <= x < w and 0 <= y < h and not (vazio and a[y, x, 3]):
        a[y, x, :3] = cor
        a[y, x, 3] = 255


def viz4(m):
    n = np.zeros_like(m)
    n[1:] |= m[:-1]
    n[:-1] |= m[1:]
    n[:, 1:] |= m[:, :-1]
    n[:, :-1] |= m[:, 1:]
    return n


def contornar(a, cor, borda_livre=True):
    """Contorno de 1 px (vizinhança 4) em volta de tudo que é opaco."""
    m = a[..., 3] > 0
    if borda_livre:
        assert not (m[0].any() or m[-1].any() or m[:, 0].any() or m[:, -1].any()), "corpo encosta na borda"
    o = viz4(m) & ~m
    a[o, :3] = cor
    a[o, 3] = 255
    return a


def sob(base, fx):
    """Põe o efeito fx por baixo do corpo base."""
    r = fx.copy()
    m = base[..., 3] > 0
    r[m] = base[m]
    return r


def linha(a, x0, y0, x1, y1, cor, vazio=False):
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    e = dx + dy
    while True:
        por(a, x0, y0, cor, vazio)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * e
        if e2 >= dy:
            e += dy
            x0 += sx
        if e2 <= dx:
            e += dx
            y0 += sy


def raio_polar(a, cx, cy, ang, r0, r1, cor, vazio=False):
    linha(a, cx + r0 * math.cos(ang) - 0.5, cy + r0 * math.sin(ang) - 0.5,
          cx + r1 * math.cos(ang) - 0.5, cy + r1 * math.sin(ang) - 0.5, cor, vazio)


def disco(a, cx, cy, r, cor, vazio=False):
    h, w = a.shape[:2]
    for y in range(max(0, int(cy - r - 1)), min(h, int(cy + r + 2))):
        for x in range(max(0, int(cx - r - 1)), min(w, int(cx + r + 2))):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                por(a, x, y, cor, vazio)


def anel(a, cx, cy, r, esp, cor, filtro=None, vazio=False):
    h, w = a.shape[:2]
    for y in range(h):
        for x in range(w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if abs(math.hypot(dx, dy) - r) <= esp / 2 and (filtro is None or filtro(math.atan2(dy, dx))):
                por(a, x, y, cor, vazio)


def ruido_suave(w, h, esc, semente):
    rng = np.random.default_rng(semente)
    g = rng.random((h // esc + 3, w // esc + 3))
    ys, xs = np.arange(h) / esc, np.arange(w) / esc
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = (ys - y0)[:, None], (xs - x0)[None, :]
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a, b = g[y0][:, x0], g[y0][:, x0 + 1]
    c, d = g[y0 + 1][:, x0], g[y0 + 1][:, x0 + 1]
    return a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy


def isolados(a, faiscas=()):
    """Pixels opacos sem vizinho (8) da mesma cor, fora das cores de faísca."""
    h, w = a.shape[:2]
    fa = {tuple(c) for c in faiscas}
    res = []
    for y in range(h):
        for x in range(w):
            if not a[y, x, 3]:
                continue
            c = tuple(int(v) for v in a[y, x, :3])
            if c in fa:
                continue
            ok = False
            for yy in range(max(0, y - 1), min(h, y + 2)):
                for xx in range(max(0, x - 1), min(w, x + 2)):
                    if (yy, xx) != (y, x) and a[yy, xx, 3] and tuple(int(v) for v in a[yy, xx, :3]) == c:
                        ok = True
            if not ok:
                res.append((x, y))
    return res


def limpar(a, faiscas=(), protegidos=()):
    """Limpeza de pixel solto: o pixel que ficou sozinho na cor dele vira a cor mais comum em volta
    (ou some, se não tem vizinho nenhum). As faíscas declaradas ficam."""
    h, w = a.shape[:2]
    prot = {tuple(c) for c in protegidos}
    for _ in range(4):
        sol = isolados(a, faiscas)
        mudou = False
        for x, y in sol:
            if tuple(int(v) for v in a[y, x, :3]) in prot:
                continue
            viz = [tuple(int(v) for v in a[yy, xx, :3]) for yy in range(max(0, y - 1), min(h, y + 2))
                   for xx in range(max(0, x - 1), min(w, x + 2)) if (yy, xx) != (y, x) and a[yy, xx, 3]]
            if not viz:
                a[y, x] = 0
            else:
                # prefere um tom do material vizinho ao contorno (senão o contorno "come" o corpo)
                bons = [v for v in viz if v not in CONTORNOS] or viz
                a[y, x, :3] = Counter(bons).most_common(1)[0][0]
            mudou = True
        if not mudou:
            break
    return a


def sombrear(lab, rampas):
    """lab: grade de letras ('.' vazio). rampas: letra -> [escuro, médio, claro, brilho] ou uma cor fixa.
    Chanfro pela luz fixa de cima à esquerda: borda de cima/esquerda clara, de baixo/direita escura."""
    h, w = lab.shape
    a = novo(w, h)
    for y in range(h):
        for x in range(w):
            ch = lab[y, x]
            if ch == '.':
                continue
            r = rampas[ch]
            if isinstance(r, tuple):
                por(a, x, y, r)
                continue

            def dif(xx, yy):
                return not (0 <= xx < w and 0 <= yy < h) or lab[yy, xx] != ch

            s = int(dif(x, y - 1)) + int(dif(x - 1, y)) - int(dif(x, y + 1)) - int(dif(x + 1, y))
            i = 0 if s <= -1 else 1 if s == 0 else 2 if s == 1 else 3
            por(a, x, y, r[min(i, len(r) - 1)])
    return a


def grade(linhas):
    w = len(linhas[0])
    assert all(len(l) == w for l in linhas), [len(l) for l in linhas]
    return np.array([list(l) for l in linhas])


def rast(fn, w, h, ss=4):
    """Máscara por supersample (maioria das amostras dentro), sem antialias."""
    m = np.zeros((h, w), bool)
    of = [(i + 0.5) / ss for i in range(ss)]
    for y in range(h):
        for x in range(w):
            n = sum(1 for oy in of for ox in of if fn(x + ox, y + oy))
            m[y, x] = n * 2 >= ss * ss
    return m


# --------------------------------------------------------------------------------------------------------------
# Paletas (partindo das imagens paradas de assets/v2/armas e das fontes fonte_armas_*.webp)
# --------------------------------------------------------------------------------------------------------------
ROXO = [(62, 30, 92), (100, 52, 146), (150, 96, 204), (206, 170, 242)]
ROXO_C = (28, 16, 40)
ROXO_HASTE = [(60, 40, 80), (92, 66, 120), (128, 100, 156)]
ROXO_FUMO = [(74, 44, 104), (112, 70, 156)]
ROXO_FAISCA = (196, 150, 240)

GELO = [(58, 104, 150), (90, 148, 198), (150, 200, 236), (228, 246, 255)]
GELO_C = (26, 40, 74)
MADEIRA = [(70, 44, 36), (106, 68, 48), (140, 96, 62)]
AMARRA = [(60, 56, 70), (98, 88, 93)]

VERDE = [(48, 104, 32), (98, 170, 40), (168, 224, 72), (220, 250, 150)]
VERDE_C = (20, 44, 22)
PENA = [(100, 76, 44), (140, 110, 60), (176, 146, 84)]

OURO = [(214, 120, 40), (244, 173, 63), (250, 214, 110), (255, 248, 214)]
OURO_C = (150, 74, 26)

ACO = [(55, 53, 60), (88, 84, 94), (130, 124, 140), (196, 192, 210)]
ACO_C = (24, 18, 30)
BORRAO_ACO = (86, 88, 112)
CABO_VERM =[(78, 20, 15), (123, 42, 20), (160, 66, 34)]
LATAO = [(92, 64, 36), (150, 108, 52), (206, 160, 80), (240, 210, 130)]
SOMBRA = [(40, 28, 56), (70, 50, 100), (120, 90, 170)]
FERRUGEM = [(70, 38, 34), (104, 58, 40), (140, 82, 50), (186, 122, 72)]
FERRUGEM_C = (36, 20, 26)

FOGO = [(255, 246, 206), (250, 214, 110), (244, 173, 63), (242, 132, 62), (230, 74, 27), (191, 50, 28),
        (120, 34, 30)]
FOGO_C = (100, 26, 28)
FUMACA = [(48, 40, 50), (72, 62, 70), (102, 90, 96), (134, 122, 124)]
CHUMBO = [(50, 46, 54), (71, 68, 75), (98, 92, 104), (134, 128, 146), (190, 186, 206)]
CHUMBO_C = (22, 17, 28)
POEIRA = [(70, 60, 58), (104, 92, 86), (140, 126, 114), (182, 168, 150)]
POEIRA_C = (46, 40, 44)
BRANCO = (236, 236, 244)
CONTORNOS = {ROXO_C, GELO_C, VERDE_C, OURO_C, ACO_C, FERRUGEM_C, FOGO_C, CHUMBO_C, POEIRA_C}


# --------------------------------------------------------------------------------------------------------------
# PRJ-A: flecha roxa (flechas_sombrias), 24x8, cabeça em (18,4)
# --------------------------------------------------------------------------------------------------------------
FLECHA_CORPO = [
    "........................",
    "........................",
    "...............PP.......",
    "................PPP.....",
    "........WWWWWWWWPPPPP...",
    "................PPP.....",
    "...............PP.......",
    "........................",
]
# penas em 4 poses (a de cima e a de baixo fora de fase): batem com o vento
PENAS_CIMA = [[(8, 2), (9, 2), (10, 3), (11, 3)], [(7, 2), (8, 2), (9, 3), (10, 3)],
              [(9, 2), (10, 2), (10, 3), (11, 3)], [(8, 2), (9, 3), (10, 3), (11, 3)]]


def flecha_voo(t):
    lab = grade(FLECHA_CORPO)
    for i, pts in enumerate([PENAS_CIMA[t], PENAS_CIMA[(t + 2) % 4]]):
        for x, y in pts:
            lab[y if i == 0 else 8 - y, x] = 'F'
    corpo = sombrear(lab, {'P': ROXO, 'W': ROXO_HASTE, 'F': [ROXO[1], ROXO[2], ROXO[2]]})
    # fio de energia na ponta: corre pela aresta de cima da cabeça
    gx = [16, 17, 18, 17][t]
    por(corpo, gx, 3 if gx < 18 else 4, ROXO[3])
    por(corpo, gx + 1, 3 if gx + 1 < 18 else 4, ROXO[3])
    contornar(corpo, ROXO_C)
    fx = novo(24, 8)
    # chama de sombra atrás das penas: duas línguas que ondulam, mudam de tamanho e se abrem na ponta
    for (oy, comp, esp, fase, cor_m, cor_e) in [(-0.6, 8.5, 1.9, 0.0, ROXO_FUMO[1], ROXO_FUMO[0]),
                                                 (1.0, 7.0, 1.4, 0.5, ROXO_FUMO[1], ROXO_FUMO[0])]:
        comp_t = comp * (1 + 0.15 * math.sin(TAU * (t / 4 + fase)))
        for x in range(0, 10):
            u = (9.5 - x) / comp_t
            if not (0 <= u < 1):
                continue
            yc = 4.5 + oy + 1.4 * u * math.sin(TAU * (u * 0.9 - t / 4 + fase))
            hw = esp * (1 - u) ** 0.6 + 0.35
            for y in range(1, 8):
                dd = abs(y + 0.5 - yc)
                if dd <= hw:
                    por(fx, x, y, cor_m if dd <= hw * 0.45 else cor_e)
    # restos de sombra que se soltam e ficam para trás (3 px por quadro, período 12)
    for x0, y in [(2, 1), (7, 6), (10, 1), (5, 7)]:
        x = (x0 + 12 - 3 * t) % 12
        por(fx, x, y, ROXO_FAISCA)
    return limpar(sob(corpo, fx), faiscas=[ROXO_FAISCA, ROXO[3]])


def flecha_impacto(t):
    a = novo(20, 20)
    c = 10.0
    if t == 0:
        disco(a, c, c, 3.6, ROXO[0])
        disco(a, c, c, 2.4, ROXO[2])
        for ang in (0, 1, 2, 3):
            raio_polar(a, c, c, ang * TAU / 4, 2, 6.5, ROXO[2])
        disco(a, c, c, 1.2, ROXO[3])
    elif t == 1:
        anel(a, c, c, 5.6, 1.6, ROXO[1])
        anel(a, c, c, 4.4, 1.0, ROXO[0])
        disco(a, c, c, 1.6, ROXO[0])
        for i in range(6):
            ang = i * TAU / 6 + 0.3
            raio_polar(a, c, c, ang, 6.6, 8.6, ROXO[2])
    else:
        anel(a, c, c, 7.4, 1.2, ROXO_FUMO[0], filtro=lambda g: math.sin(3 * g + 0.6) > -0.2)
        for i in range(6):
            ang = i * TAU / 6 + 0.3
            por(a, c + 9.2 * math.cos(ang) - 0.5, c + 9.2 * math.sin(ang) - 0.5, ROXO_FAISCA)
        for i in range(3):
            ang = i * TAU / 3 + 1.1
            raio_polar(a, c, c, ang, 3.2, 4.4, ROXO[1])
    return limpar(a, faiscas=[ROXO_FAISCA, ROXO[3]])


# --------------------------------------------------------------------------------------------------------------
# PRJ-A: lança de gelo (lanca_geada), 30x6, cabeça em (22,3)
# --------------------------------------------------------------------------------------------------------------
LANCA_CORPO = [
    "..............................",
    "..................II..........",
    "...............IIIIIII........",
    "..WWWWWWWWWWBBIIIIIIIIIIII....",
    "...............IIIIIII........",
    "..............................",
]
# lascas de cristal que crescem e se soltam da cabeça (uma pose por quadro)
LANCA_LASCAS = [[(21, 1)], [(21, 1), (22, 1)], [(16, 1)], [(16, 1), (21, 1)]]


def lanca_voo(t):
    lab = grade(LANCA_CORPO)
    for x, y in LANCA_LASCAS[t]:
        lab[y, x] = 'I'
    corpo = sombrear(lab, {'I': GELO, 'W': MADEIRA, 'B': AMARRA})
    # brilho do gelo correndo pela aresta de cima até a ponta
    for x in ([16, 17], [18, 19], [20, 21], [22, 23])[t]:
        if x <= 21:
            por(corpo, x, 2, GELO[3])
        else:
            por(corpo, x, 3, GELO[3])
    contornar(corpo, GELO_C)
    fx = novo(30, 6)
    # rastro de geada: lascas que ficam para trás (4 px por quadro, período 16), em cima e embaixo da haste
    for x0, y, cor in [(3, 1, GELO[2]), (11, 5, GELO[1]), (8, 0, GELO[3]), (14, 5, GELO[3])]:
        x = (x0 + 16 - 4 * t) % 16
        por(fx, x, y, cor, vazio=True)
        if cor != GELO[3]:
            por(fx, x + 1, y, cor, vazio=True)
    # névoa fria na ponta de trás da haste
    for x in range(0, 3):
        y = 3 + round(1.2 * math.sin(TAU * (x / 4 + t / 4)))
        por(fx, x, y, GELO[1], vazio=True)
    return limpar(sob(corpo, fx), faiscas=[GELO[3]])


def lanca_impacto(t):
    a = novo(20, 20)
    c = 10.0
    if t == 0:
        for y in range(20):
            for x in range(20):
                d = abs(x + 0.5 - c) + abs(y + 0.5 - c)
                if d <= 2.5:
                    por(a, x, y, GELO[3])
                elif d <= 4:
                    por(a, x, y, GELO[2])
                elif d <= 5 and (x == 9 or x == 10 or y == 9 or y == 10):
                    por(a, x, y, GELO[1])
    elif t == 1:
        for y in range(20):
            for x in range(20):
                if abs(x + 0.5 - c) + abs(y + 0.5 - c) <= 2:
                    por(a, x, y, GELO[1])
        for i in range(6):
            ang = i * TAU / 6 + 0.25
            raio_polar(a, c, c, ang, 3.6, 6.6, GELO[2])
            raio_polar(a, c, c, ang + 0.18, 4.4, 6.0, GELO[1])
            por(a, c + 7.4 * math.cos(ang) - 0.5, c + 7.4 * math.sin(ang) - 0.5, GELO[3])
    else:
        for i in range(6):
            ang = i * TAU / 6 + 0.25
            raio_polar(a, c, c, ang, 7.4, 8.6, GELO[1])
            ang2 = ang + TAU / 12
            por(a, c + 5.4 * math.cos(ang2) - 0.5, c + 5.4 * math.sin(ang2) - 0.5, GELO[3])
        disco(a, c, c, 1.1, GELO[0])
    return limpar(a, faiscas=[GELO[3]])


# --------------------------------------------------------------------------------------------------------------
# PRJ-A: dardo verde (dardos_peconhentos), 16x8, cabeça em (12,4)
# --------------------------------------------------------------------------------------------------------------
DARDO_CORPO = [
    "................",
    "................",
    "................",
    "..........GG....",
    "..WWWWWWBWGGGG..",
    "..........GG....",
    "................",
    "................",
]
DARDO_PENAS = [[(3, 2), (4, 3)], [(2, 2), (3, 3), (4, 3)], [(3, 2), (4, 2), (4, 3)], [(2, 2), (3, 2), (4, 3)]]


def dardo_voo(t):
    lab = grade(DARDO_CORPO)
    for i, pts in enumerate([DARDO_PENAS[t], DARDO_PENAS[(t + 2) % 4]]):
        for x, y in pts:
            lab[y if i == 0 else 8 - y, x] = 'F'
    corpo = sombrear(lab, {'G': VERDE, 'W': MADEIRA, 'B': PENA[2], 'F': PENA})
    por(corpo, 12 + (t % 2), 3, VERDE[3])
    contornar(corpo, VERDE_C)
    fx = novo(16, 8)
    # gota de veneno que nasce embaixo da ponta, estica, solta e cai para trás
    gotas = {0: [(11, 6)], 1: [(11, 6), (11, 7)], 2: [(10, 7)], 3: []}[t]
    for x, y in gotas:
        por(fx, x, y, VERDE[2])
    if t == 3:
        por(fx, 8, 7, VERDE[1])
        por(fx, 9, 7, VERDE[1])
    # vapor de veneno que ondula atrás
    for x in range(0, 6):
        y = 4 + 1.6 * math.sin(TAU * (x / 6 + t / 4))
        por(fx, x, round(y), VERDE[1] if x > 2 else VERDE[0])
    for x0, y in [(1, 1), (6, 6)]:
        x = (x0 + 8 - 2 * t) % 8
        por(fx, x, y, VERDE[2])
    return limpar(sob(corpo, fx), faiscas=[VERDE[2], VERDE[3]])


def dardo_impacto(t):
    a = novo(20, 20)
    c = 10.0
    n = ruido_suave(20, 20, 3, 77)
    if t == 0:
        for y in range(20):
            for x in range(20):
                d = math.hypot(x + 0.5 - c, y + 0.5 - c) / (3.4 + 1.2 * n[y, x])
                if d <= 1:
                    por(a, x, y, VERDE[3] if d < 0.4 else VERDE[2] if d < 0.75 else VERDE[1])
    elif t == 1:
        for y in range(20):
            for x in range(20):
                d = math.hypot(x + 0.5 - c, y + 0.5 - c) / (4.6 + 1.6 * n[y, x])
                if 0.35 < d <= 1:
                    por(a, x, y, VERDE[2] if d < 0.7 else VERDE[1])
        for i in range(7):
            ang = i * TAU / 7 + 0.4
            disco(a, c + 7.2 * math.cos(ang), c + 7.2 * math.sin(ang), 1.0, VERDE[2])
    else:
        for i in range(7):
            ang = i * TAU / 7 + 0.4
            disco(a, c + 8.4 * math.cos(ang), c + 8.4 * math.sin(ang) + 1, 0.8, VERDE[1])
        anel(a, c, c, 3.6, 1.0, VERDE[0], filtro=lambda g: math.sin(4 * g) > -0.3)
    return limpar(a, faiscas=[VERDE[1], VERDE[2]])


# --------------------------------------------------------------------------------------------------------------
# PRJ-A: feixe dourado (raio_solar), 64x6, cabeça em (48,3)
# --------------------------------------------------------------------------------------------------------------
def feixe_voo(t):
    a = novo(64, 6)
    cab = 48
    # corpo do raio: núcleo de 2 linhas com contorno âmbar; a cauda se parte em traços que correm para trás
    for x in range(2, cab + 1):
        if x >= 30:
            liga = True
        elif x >= 14:
            liga = (x + 4 * t) % 16 < 11
        else:
            liga = False
        if liga:
            pulso = (x + 4 * t) % 8 < 2
            por(a, x, 2, OURO[3])
            por(a, x, 3, OURO[3] if pulso else OURO[2])
            por(a, x, 1, OURO_C)
            por(a, x, 4, OURO_C)
        elif x >= 2 and (x + 4 * t) % 16 < 6:
            por(a, x, 2 + ((x // 8 + t) % 2), OURO[1])
    # estrela da cabeça: muda de forma (cruz longa, x, cruz curta, x torto)
    braco = [3, 2, 3, 2][t]
    for y in range(3 - braco, 3 + braco):
        por(a, cab, y, OURO[3])
    frente = [5, 3, 6, 4][t]
    for x in range(cab + 1, cab + 1 + frente):
        por(a, x, 2, OURO[3])
        if x < cab + frente - 1:
            por(a, x, 3, OURO[2])
    if t % 2 == 1:
        for dx, dy in [(-2, -2), (2, -2), (-2, 2), (2, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)]:
            if 0 <= 2 + dy + (1 if dy > 0 else 0) - 1 < 6:
                por(a, cab + dx, 2 + dy + (1 if dy > 0 else 0), OURO[1])
    # fagulhas que se soltam do raio (4 px por quadro, período 16)
    for x0, y in [(36, 0), (44, 5), (25, 5), (31, 0)]:
        x = 20 + (x0 - 20 + 64 - 4 * t) % 28
        por(a, x, y, OURO[2], vazio=True)
    return limpar(a, faiscas=[OURO[1], OURO[2]])


def feixe_impacto(t):
    a = novo(20, 20)
    c = 10.0
    if t == 0:
        for i in range(8):
            ang = i * TAU / 8
            raio_polar(a, c, c, ang, 1, 7.5 if i % 2 == 0 else 4.5, OURO[2] if i % 2 else OURO[3])
        disco(a, c, c, 2.4, OURO[3])
    elif t == 1:
        anel(a, c, c, 6.0, 1.4, OURO[1])
        for i in range(8):
            ang = i * TAU / 8 + TAU / 16
            raio_polar(a, c, c, ang, 2.5, 9.0 if i % 2 == 0 else 6.5, OURO[2])
        disco(a, c, c, 1.6, OURO[3])
    else:
        anel(a, c, c, 8.2, 1.0, OURO[0], filtro=lambda g: math.sin(4 * g + 0.4) > -0.35)
        for i in range(4):
            ang = i * TAU / 4 + 0.4
            x, y = c + 4.5 * math.cos(ang) - 0.5, c + 4.5 * math.sin(ang) - 0.5
            por(a, x, y, OURO[3])
            por(a, x + 1, y, OURO[2])
            por(a, x - 1, y, OURO[2])
            por(a, x, y + 1, OURO[2])
            por(a, x, y - 1, OURO[2])
    return limpar(a, faiscas=[OURO[3]])


# --------------------------------------------------------------------------------------------------------------
# PRJ-G: giro. Cada quadro é um ângulo; a sombra é recalculada com a luz fixa depois do giro.
# --------------------------------------------------------------------------------------------------------------
ADAGA_0 = [
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
    "..P...U.......",
    ".PPGGGUBBBBBB.",
    ".PPGGGUBBBBB..",
    "..P...U.......",
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
]


def _adaga_45():
    # o mesmo desenho a 45° montado por coordenada (lâmina com 2 px de espessura e ponta)
    g = np.full((14, 14), '.')
    for x, y in [(2, 2), (3, 2), (2, 3), (3, 3)]:
        g[y, x] = 'P'
    for x, y in [(4, 3), (4, 4), (5, 4), (5, 5), (6, 5)]:
        g[y, x] = 'G'
    for x, y in [(5, 7), (6, 6), (7, 5)]:
        g[y, x] = 'U'
    for x, y in [(7, 6), (8, 7), (9, 8), (10, 9), (11, 10), (7, 7), (8, 8), (9, 9), (10, 10)]:
        g[y, x] = 'B'
    return g


def girar_grade(g, k):
    return np.rot90(g, -k).copy()  # k quartos de volta no sentido horário (y para baixo)


def arco_rastro(a, cx, cy, r, ang_fim, abertura, cor, passo=0.05):
    ang = ang_fim - abertura
    while ang <= ang_fim:
        por(a, math.floor(cx + r * math.cos(ang)), math.floor(cy + r * math.sin(ang)), cor, vazio=True)
        ang += passo


def adaga_voo(t):
    base = grade(ADAGA_0) if t % 2 == 0 else _adaga_45()
    lab = girar_grade(base, t // 2)
    corpo = sombrear(lab, {'B': ACO, 'G': CABO_VERM, 'U': LATAO[:3], 'P': ACO[:3]})
    contornar(corpo, ACO_C)
    ang = t * TAU / 8
    fx = novo(14, 14)
    arco_rastro(fx, 7.0, 7.0, 6.0, ang - 0.5, 0.35, BORRAO_ACO)
    return limpar(sob(corpo, fx), faiscas=[])


def shuriken_voo(t):
    # 4 pontas: simetria de 90°. 8 quadros a 33,75° = 3 voltas do padrão; emenda perfeita e giro rápido
    th = math.radians(33.75 * t)
    c = 7.0

    def partes(x, y):
        vx, vy = x - c, y - c
        r = math.hypot(vx, vy)
        if r < 1.0:
            return False, None
        if r <= 1.95:
            return True, ('cubo', vx / r, vy / r)
        for i in range(4):
            phi = th + i * TAU / 4
            ax, ay = math.cos(phi), math.sin(phi)
            tip = (c + 6.7 * ax, c + 6.7 * ay)
            b1 = (c + 2.3 * math.cos(phi - 1.0), c + 2.3 * math.sin(phi - 1.0))
            b2 = (c + 1.7 * math.cos(phi + 0.8), c + 1.7 * math.sin(phi + 0.8))
            if _no_tri((x, y), tip, b1, b2):
                lado = ax * vy - ay * vx
                n = (-ay, ax) if lado > 0 else (ay, -ax)
                return True, ('lamina', n[0], n[1])
        return False, None

    m = rast(lambda x, y: partes(x, y)[0], 14, 14)
    a = novo(14, 14)
    for y in range(14):
        for x in range(14):
            if not m[y, x]:
                continue
            p = partes(x + 0.5, y + 0.5)[1] or partes(x + 0.5 + 0.3, y + 0.5 + 0.3)[1] or ('lamina', 0, 0)
            d = p[1] * LUZ[0] + p[2] * LUZ[1]
            if p[0] == 'cubo':
                i = 3 if d > 0.6 else 2 if d > -0.1 else 1 if d > -0.7 else 0
                por(a, x, y, LATAO[i])
            else:
                i = 2 if d > 0.3 else 1 if d > -0.3 else 0
                por(a, x, y, ACO[i])
    # fio de luz: a aresta de cada ponta virada para a luz ganha o tom mais claro
    for y in range(14):
        for x in range(14):
            if m[y, x] and tuple(a[y, x, :3]) == ACO[2] and (y == 0 or not m[y - 1, x] or x == 0 or not m[y, x - 1]):
                por(a, x, y, ACO[3])
    contornar(a, ACO_C)
    fx = novo(14, 14)
    for i in range(4):
        arco_rastro(fx, c, c, 6.2, th + i * TAU / 4 - 0.22, 0.42, SOMBRA[1])
    return limpar(sob(a, fx), faiscas=[])


def _no_tri(p, a, b, c):
    def s(p1, p2, p3):
        return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
    d1, d2, d3 = s(p, a, b), s(p, b, c), s(p, c, a)
    return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))


def disco_voo(t):
    th = math.radians(33.75 * t)
    c = 10.0

    def dentro(x, y):
        vx, vy = x - c, y - c
        r = math.hypot(vx, vy)
        if r > 8.8 or r < 1.3:
            return False
        for i in range(4):
            phi = th + i * TAU / 4
            # cada meia-lua morde o disco fundo e, deslocada, deixa um gancho apontando no sentido do giro
            ox, oy = c + 8.0 * math.cos(phi), c + 8.0 * math.sin(phi)
            if math.hypot(x - ox, y - oy) < 4.3:
                return False
            ox, oy = c + 6.0 * math.cos(phi - 0.42), c + 6.0 * math.sin(phi - 0.42)
            if math.hypot(x - ox, y - oy) < 2.3:
                return False
        return True

    m = rast(dentro, 20, 20)
    a = novo(20, 20)
    for y in range(20):
        for x in range(20):
            if not m[y, x]:
                continue
            vx, vy = x + 0.5 - c, y + 0.5 - c
            r = math.hypot(vx, vy)
            if r <= 3.4:
                # cubo levantado em volta do furo
                d = (vx * LUZ[0] + vy * LUZ[1]) / max(r, 0.01)
                i = 3 if d > 0.5 else 2 if d > -0.3 else 1
            else:
                # disco abaulado: metade de cima/esquerda clara
                d = (vx * LUZ[0] + vy * LUZ[1]) / 8.6
                i = 2 if d > 0.25 else 1 if d > -0.3 else 0
            por(a, x, y, FERRUGEM[i])
    # ferrugem/marca de martelo presa ao metal (gira junto; repetida nas 4 lâminas)
    for i in range(4):
        phi = th + i * TAU / 4
        for rr, da in [(5.6, 0.55), (6.2, 0.75), (4.7, -0.35)]:
            x, y = math.floor(c + rr * math.cos(phi + da)), math.floor(c + rr * math.sin(phi + da))
            if m[y, x] and tuple(a[y, x, :3]) != FERRUGEM[0]:
                por(a, x, y, FERRUGEM[0] if da > 0 else FERRUGEM[3])
    # fio da borda virado para a luz
    for y in range(20):
        for x in range(20):
            if m[y, x] and math.hypot(x + 0.5 - c, y + 0.5 - c) > 3.6 and (not m[y - 1, x] or not m[y, x - 1]) \
                    and tuple(a[y, x, :3]) == FERRUGEM[2]:
                por(a, x, y, FERRUGEM[3])
    contornar(a, FERRUGEM_C)
    fx = novo(20, 20)
    for i in range(4):
        phi = th + i * TAU / 4
        arco_rastro(fx, c, c, 8.6, phi + 0.32 - 0.14, 0.28, (128, 92, 70))
    return limpar(sob(a, fx), faiscas=[FERRUGEM[3]])


def _laminas_base(ang):
    """Foice curta (cabo vermelho com argola, lâmina em meia-lua na ponta), ângulo 0 = lâmina à direita."""
    c = 12.0
    ca, sa = math.cos(-ang), math.sin(-ang)

    def local(x, y):  # leva o ponto para o espaço do objeto (sem girar = ângulo 0)
        vx, vy = x - c, y - c
        return c + vx * ca - vy * sa, c + vx * sa + vy * ca

    def parte(x, y):
        lx, ly = local(x, y)
        # argola do pomo
        rr = math.hypot(lx - 4.0, ly - 12.0)
        if 0.9 <= rr <= 2.3:
            return 'A'
        # cabo
        if 5.6 <= lx <= 13.2 and 11.0 <= ly <= 13.0:
            return 'G'
        # guarda (losango de latão)
        if abs(lx - 14.0) + abs(ly - 12.0) <= 1.9:
            return 'U'
        # lâmina: meia-lua, ponta de baixo mais longa
        da = math.hypot(lx - 11.0, ly - 12.6)
        db = math.hypot(lx - 8.6, ly - 11.6)
        if da <= 9.6 and db >= 8.4 and lx >= 13.0 and 3.6 <= ly <= 21.2:
            return 'B'
        return None

    lab = np.full((24, 24), '.')
    of = [0.125, 0.375, 0.625, 0.875]
    for y in range(24):
        for x in range(24):
            cont = Counter(parte(x + ox, y + oy) for oy in of for ox in of)
            nvazio = cont.pop(None, 0)
            if nvazio < 8 and cont:
                lab[y, x] = cont.most_common(1)[0][0]
    return lab


def laminas_voo(t):
    base = _laminas_base(0.0 if t % 2 == 0 else math.pi / 4)
    lab = girar_grade(base, t // 2)
    # tira os pixels de lâmina sem vizinho de lâmina (pontas soltas do supersample)
    for y in range(24):
        for x in range(24):
            if lab[y, x] != '.':
                v = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                        if 0 <= x + dx < 24 and 0 <= y + dy < 24 and lab[y + dy, x + dx] != '.')
                if v == 0:
                    lab[y, x] = '.'
    corpo = sombrear(lab, {'B': ACO, 'G': CABO_VERM, 'U': LATAO[1:], 'A': ACO[:3]})
    contornar(corpo, ACO_C)
    ang = t * TAU / 8
    fx = novo(24, 24)
    # rastro da lâmina (a ponta de baixo, que está a ~100° do eixo) e da argola
    arco_rastro(fx, 12.0, 12.0, 9.6, ang + 0.62 - 0.30, 0.55, SOMBRA[2])
    arco_rastro(fx, 12.0, 12.0, 10.4, ang - 0.50 - 0.25, 0.4, SOMBRA[1])
    arco_rastro(fx, 12.0, 12.0, 8.9, ang + math.pi - 0.35, 0.45, SOMBRA[1])
    return limpar(sob(corpo, fx), faiscas=[])


def faisca_metal(t, quente, frio, fio, semente, corte=False):
    """Impacto 20x20 de metal: estalo branco, riscos que voam e somem."""
    a = novo(20, 20)
    c = 10.0
    rng = np.random.default_rng(semente)
    angs = [i * TAU / 7 + rng.uniform(-0.25, 0.25) for i in range(7)]
    if t == 0:
        for i in range(4):
            raio_polar(a, c, c, i * TAU / 4 + 0.4, 0.5, 5.5, quente)
        disco(a, c, c, 1.7, BRANCO)
        if corte:
            anel(a, c - 3, c + 3, 7.0, 1.2, fio, filtro=lambda g: -1.7 < g < -0.1)
    elif t == 1:
        for g in angs:
            raio_polar(a, c, c, g, 3.2, 6.8, quente)
            por(a, c + 7.5 * math.cos(g) - 0.5, c + 7.5 * math.sin(g) - 0.5, BRANCO)
        disco(a, c, c, 1.1, fio)
        if corte:
            anel(a, c - 3, c + 3, 8.4, 1.0, fio, filtro=lambda g: -1.6 < g < -0.05)
    else:
        for g in angs:
            raio_polar(a, c, c, g, 7.6, 8.9, frio)
        for g in angs[::2]:
            por(a, c + 4.6 * math.cos(g + 0.4) - 0.5, c + 4.6 * math.sin(g + 0.4) - 0.5, fio)
    return limpar(a, faiscas=[BRANCO, fio, frio])


def adaga_impacto(t):
    return faisca_metal(t, OURO[2], OURO[0], ACO[3], 11)


def shuriken_impacto(t):
    a = faisca_metal(t, SOMBRA[2], SOMBRA[1], ROXO[3], 12)
    if t == 0:
        linha(a, 5, 5, 14, 14, SOMBRA[0], vazio=True)
        linha(a, 14, 5, 5, 14, SOMBRA[0], vazio=True)
    return limpar(a, faiscas=[BRANCO, ROXO[3], SOMBRA[1]])


def disco_impacto(t):
    a = faisca_metal(t, FOGO[2], FOGO[4], FERRUGEM[3], 13)
    if t == 1:
        anel(a, 10, 10, 4.6, 1.0, FERRUGEM[2], vazio=True)
    return limpar(a, faiscas=[BRANCO, FERRUGEM[3], FOGO[4]])


def laminas_impacto(t):
    return faisca_metal(t, OURO[2], CABO_VERM[2], ACO[3], 14, corte=True)


# --------------------------------------------------------------------------------------------------------------
# PRJ-B: bola de fogo (bola_fogo, fogo_do_ceu) 26x18 e bola de chumbo 24x16
# --------------------------------------------------------------------------------------------------------------
def tom_fogo(h):
    for lim, i in ((0.92, 0), (0.78, 1), (0.64, 2), (0.5, 3), (0.36, 4), (0.2, 5)):
        if h > lim:
            return FOGO[i]
    return FOGO[6]


LINGUAS = [  # deslocamento y, curva, comprimento, espessura, fase
    (0.0, 0.0, 16.0, 4.6, 0.00),
    (-2.6, -1.8, 11.5, 2.4, 0.30),
    (2.4, 1.6, 10.5, 2.3, 0.62),
    (-4.2, -2.6, 7.0, 1.5, 0.15),
    (4.0, 2.4, 6.5, 1.4, 0.80),
]


def bola_fogo_voo(t):
    W, H, cx, cy = 26, 18, 19.0, 9.0
    calor = np.full((H, W), -1.0)
    for y in range(H):
        for x in range(W):
            px, py = x + 0.5, y + 0.5
            d = math.hypot(px - cx - 0.5, py - cy - 0.5)
            if d <= 5.3:
                calor[y, x] = 1.1 - 0.075 * math.hypot(px - (cx + 2.2), py - (cy - 0.2)) * 1.6
            for (oy, curva, comp, esp, fase) in LINGUAS:
                comp_t = comp * (1 + 0.14 * math.sin(TAU * (t / 4 + fase)))
                u = (cx + 0.5 - px) / comp_t
                if not (0.0 <= u < 1.0):
                    continue
                yc = cy + 0.5 + oy * min(1.0, u * 2.5) + curva * u \
                    + 1.3 * u * math.sin(TAU * (u * 1.25 - t / 4 + fase))
                hw = esp * (1 - u) ** 0.75 * (1 + 0.18 * math.sin(TAU * (t / 4 + fase * 2)))
                if abs(py - yc) <= hw:
                    h = 0.86 - 0.9 * u - 0.28 * abs(py - yc) / max(hw, 0.1)
                    calor[y, x] = max(calor[y, x], h)
    a = novo(W, H)
    for y in range(H):
        for x in range(W):
            if calor[y, x] > -0.9:
                por(a, x, y, tom_fogo(calor[y, x]))
    # some com pontas soltas antes do contorno
    m = a[..., 3] > 0
    v = viz4(m)
    for y in range(H):
        for x in range(W):
            if m[y, x] and sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                               if 0 <= x + dx < W and 0 <= y + dy < H and m[y + dy, x + dx]) == 0:
                a[y, x] = 0
    a[:, 0] = 0
    contornar(a, FOGO_C, borda_livre=False)
    a[:, 0] = 0
    # brasas que se soltam e ficam para trás (3 px por quadro, período 12)
    for k, (x0, y) in enumerate([(2, 3), (8, 14), (5, 1), (11, 16)]):
        x = (x0 + 12 - 3 * t) % 12
        por(a, x, y, FOGO[2 if k % 2 else 3], vazio=True)
    return limpar(a, faiscas=[FOGO[2], FOGO[3], FOGO[0]])


def _bolhas(W, c, puffs, rampa, contorno, ruido, limiar, ruido2=None, corte2=None):
    """Nuvem de fumaça/poeira feita de bolhas, com sombra pela luz fixa e borda escura."""
    m = np.zeros((W, W), bool)
    alt = np.zeros((W, W))
    for y in range(W):
        for x in range(W):
            px, py = x + 0.5, y + 0.5
            for (bx, by, br) in puffs:
                q = math.hypot(px - bx, py - by) / (br * (0.8 + 0.4 * ruido[y, x]))
                if q <= 1:
                    alt[y, x] = max(alt[y, x], (1 - q * q) * br)
            if ruido2 is not None and ruido2[y, x] < corte2:
                continue
            m[y, x] = alt[y, x] > 0
    # tira farelo: pixel com menos de 2 vizinhos (4) some
    for _ in range(2):
        nv = sum(np.roll(m, s, ax) for s in (1, -1) for ax in (0, 1))
        m &= nv >= 2
    # cada bolha é um calombo: a luz de cima à esquerda clareia a encosta virada para ela
    gx = (np.roll(alt, -1, 1) - np.roll(alt, 1, 1)) / 2
    gy = (np.roll(alt, -1, 0) - np.roll(alt, 1, 0)) / 2
    lum = -(gx * LUZ[0] + gy * LUZ[1])
    a = novo(W, W)
    for y in range(W):
        for x in range(W):
            if not m[y, x]:
                continue
            v = lum[y, x]
            i = 3 if v > 1.1 else 2 if v > 0.35 else 0 if v < -0.45 else 1
            por(a, x, y, rampa[i])
    borda = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    a[borda, :3] = contorno
    return a


def bola_fogo_impacto(t):
    W, c = 56, 28.0
    rng = np.random.default_rng(2101)
    ph = rng.uniform(0, TAU, 4)
    n1 = ruido_suave(W, W, 5, 300 + t)
    n2 = ruido_suave(W, W, 3, 400 + t)
    faisc = [rng.uniform(0, TAU) for _ in range(12)]
    if t <= 3:
        R = [8.0, 15.0, 21.0, 23.5][t]
        heat = [1.75, 1.4, 1.08, 0.72][t]
        a = novo(W, W)
        for y in range(W):
            for x in range(W):
                dx, dy = x + 0.5 - c, y + 0.5 - c
                d, g = math.hypot(dx, dy), math.atan2(dy, dx)
                lump = 1 + 0.15 * math.sin(5 * g + ph[0] + t * 0.7) + 0.09 * math.sin(3 * g + ph[1] - t * 0.5) \
                    + 0.22 * (n1[y, x] - 0.5)
                de = d / (R * lump)
                if de > 1:
                    continue
                if t == 3 and de < 0.42 + 0.25 * (n2[y, x] - 0.5):
                    continue  # o miolo se abre
                T = heat * (1 - 0.8 * de) + 0.35 * (n2[y, x] - 0.5)
                if t >= 2:
                    T -= 0.35 * max(0.0, -dy / R) * (t - 1) / 2
                if T > 0.14:
                    cor = tom_fogo(T * 0.95 - 0.02)
                else:
                    lum = (dx * LUZ[0] + dy * LUZ[1]) / max(d, 1)
                    cor = FUMACA[2] if lum > 0.3 else FUMACA[1] if lum > -0.3 else FUMACA[0]
                por(a, x, y, cor)
        m = a[..., 3] > 0
        borda = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
        a[borda, :3] = FOGO_C if t < 3 else FUMACA[0]
        if t == 0:
            for i in range(4):
                raio_polar(a, c, c, i * TAU / 4 + 0.78, 7, 13, FOGO[1], vazio=True)
        for g in faisc:
            if t == 1:
                raio_polar(a, c, c, g, R + 1.5, R + 4.5, FOGO[1], vazio=True)
            elif t == 2:
                raio_polar(a, c, c, g, R + 3, R + 5, FOGO[2], vazio=True)
            elif t == 3:
                por(a, c + (R + 3.5) * math.cos(g) - 0.5, c + (R + 3.5) * math.sin(g) - 0.5 + 1, FOGO[4], vazio=True)
        return limpar(a, faiscas=[FOGO[1], FOGO[2], FOGO[4]])
    # 4 e 5: só fumaça que sobe e se desfaz, com brasas
    k = t - 4
    puffs = [(c, c - 3 - 2 * k, [9.0, 5.5][k])]
    for i in range([8, 6][k]):
        g = i * TAU / [8, 6][k] + ph[2]
        rho = [15.0, 17.5][k] * (0.9 + 0.2 * math.sin(i * 1.7))
        puffs.append((c + rho * math.cos(g), c + rho * math.sin(g) * 0.92 - 3 - 3 * k, [6.6, 4.2][k]))
    n3 = ruido_suave(W, W, 6, 450 + t)
    a = _bolhas(W, c, puffs, FUMACA, FUMACA[0], n1, 0, ruido2=n3, corte2=[0.12, 0.0][k])
    for y in range(W):
        for x in range(W):
            if a[y, x, 3] and n2[y, x] > [0.78, 0.86][k] and tuple(a[y, x, :3]) != FUMACA[0]:
                por(a, x, y, FOGO[4] if k == 0 else FOGO[5])
    for g in faisc[::2]:
        r = [24.0, 26.0][k]
        por(a, c + r * math.cos(g) - 0.5, c + r * math.sin(g) - 0.5 + 3 + 2 * k, FOGO[3 + k], vazio=True)
    return limpar(a, faiscas=[FOGO[3], FOGO[4], FOGO[5]])


RACHA = [(-3, -1), (-2, -1), (-1, 0), (0, 0), (0, 1), (1, 2), (1, -1), (2, -2)]


def bola_chumbo_voo(t):
    W, H, cx, cy, r = 24, 16, 18, 8, 4.6
    a = novo(W, H)
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) / r, (y - cy) / r
            q = dx * dx + dy * dy
            if q > 1:
                continue
            nz = math.sqrt(1 - q)
            lum = dx * -0.55 + dy * -0.6 + nz * 0.58
            i = 4 if lum > 0.93 else 3 if lum > 0.72 else 2 if lum > 0.42 else 1 if lum > 0.1 else 0
            por(a, x, y, CHUMBO[i])
    # rachadura que gira com a bola (um quarto de volta por quadro)
    for dx, dy in RACHA:
        for _ in range(t):
            dx, dy = -dy, dx
        x, y = cx + dx, cy + dy
        if (x - cx) ** 2 + (y - cy) ** 2 <= r * r - 1:
            cur = tuple(int(v) for v in a[y, x, :3])
            por(a, x, y, CHUMBO[0] if cur not in (CHUMBO[0], CHUMBO[1]) else CHUMBO_C)
    contornar(a, CHUMBO_C)
    fx = novo(W, H)
    # nuvens de poeira que saem de trás da bola, crescem e ficam para trás
    for k in range(3):
        p = ((t + k * 4 / 3) % 4) / 4
        bx = 13 - p * 11
        by = 8 + [-1.6, 1.4, 0.0][k] * (0.4 + p)
        br = 1.4 + p * 1.6
        for y in range(H):
            for x in range(W):
                dx, dy = x + 0.5 - bx, y + 0.5 - by
                if dx * dx + dy * dy <= br * br:
                    lum = (dx * LUZ[0] + dy * LUZ[1]) / br
                    por(fx, x, y, POEIRA[2] if lum > 0.2 else POEIRA[1] if lum > -0.4 else POEIRA[0], vazio=True)
    # pedrinhas que capotam
    for k, (x0, y0) in enumerate([(4, 3), (10, 12)]):
        x = (x0 + 12 - 3 * t) % 12
        forma = [[(0, 0), (1, 0)], [(0, 0), (0, 1)], [(0, 0), (1, 1), (1, 0)], [(0, 1), (1, 0), (1, 1)]][(t + k) % 4]
        for dx, dy in forma:
            por(fx, x + dx, y0 + dy, CHUMBO[1])
    # riscos de velocidade
    for y0, x0 in [(4, 6), (12, 3)]:
        xs = (x0 + 12 - 3 * t) % 12
        for x in range(xs, xs + 3):
            por(fx, x, y0, POEIRA[1], vazio=True)
    return limpar(sob(a, fx), faiscas=[])


def bola_chumbo_impacto(t):
    W, c = 56, 28.0
    rng = np.random.default_rng(2202)
    ph = rng.uniform(0, TAU)
    n1 = ruido_suave(W, W, 5, 500 + t)
    n2 = ruido_suave(W, W, 3, 600 + t)
    estilh = [(i * TAU / 9 + rng.uniform(-0.2, 0.2), rng.integers(0, 3)) for i in range(9)]
    if t == 0:
        a = novo(W, W)
        disco(a, c, c, 6.5, POEIRA[1])
        disco(a, c, c, 4.0, POEIRA[3])
        for i in range(8):
            raio_polar(a, c, c, i * TAU / 8 + 0.2, 4, 11 if i % 2 == 0 else 8, BRANCO if i % 2 == 0 else POEIRA[3])
        disco(a, c, c, 2.0, BRANCO)
        return limpar(a, faiscas=[BRANCO])
    k = t - 1
    rho = [3.5, 9.0, 13.0, 17.0, 19.5][k]
    rb = [8.0, 8.0, 7.5, 5.4, 3.6][k]
    corte = [0.0, 0.06, 0.18, 0.22, 0.12][k]
    puffs = [(c, c - k, [9.5, 8.5, 6.0, 0.0, 0.0][k])]
    for i in range(9):
        g = i * TAU / 9 + ph
        rr = rho * (0.85 + 0.3 * math.sin(i * 2.3))
        puffs.append((c + rr * math.cos(g), c + rr * math.sin(g) * 0.85 - k * 0.8, rb * (0.85 + 0.3 * math.cos(i * 1.9))))
    puffs = [p for p in puffs if p[2] > 0]
    n3 = ruido_suave(W, W, 6, 650 + t)
    a = _bolhas(W, c, puffs, POEIRA, POEIRA_C, n1, 0, ruido2=n3, corte2=corte)
    # estilhaços de metal que voam para fora e caem
    for g, forma in estilh:
        if k >= 4 and forma == 0:
            continue
        r = [11.0, 16.0, 20.5, 23.5, 25.0][k]
        x = int(c + r * math.cos(g))
        y = int(c + r * math.sin(g) + [0, 0, 1, 3, 5][k])
        pts = [[(0, 0), (1, 0), (0, 1), (1, 1)], [(0, 0), (1, 0), (2, 0), (1, 1)], [(0, 0), (0, 1), (1, 1), (1, 2)]][(forma + k) % 3]
        for dx, dy in pts:
            por(a, x + dx, y + dy, CHUMBO[4] if (dx, dy) == (0, 0) else CHUMBO[2])
        for dx, dy in pts:
            for ex, ey in ((1, 0), (0, 1)):
                if (dx + ex, dy + ey) not in pts:
                    por(a, x + dx + ex, y + dy + ey, CHUMBO_C)
        if k <= 1:
            raio_polar(a, c, c, g + 0.3, r + 1 - 2 * k, r + 3 - k, BRANCO, vazio=True)
    return limpar(a, faiscas=[BRANCO])


# --------------------------------------------------------------------------------------------------------------
# Catálogo
# --------------------------------------------------------------------------------------------------------------
IMP_A = dict(quadro=(20, 20), n=3, fps=20, loop=False, ancora=(10, 10))
IMP_B = dict(quadro=(56, 56), n=6, fps=15, loop=False, ancora=(28, 28))

SPRITES = {
    "flecha_roxa": dict(armas=["flechas_sombrias"],
                        voo=dict(fn=flecha_voo, quadro=(24, 8), n=4, fps=12, loop=True, ancora=(18, 4)),
                        impacto=dict(fn=flecha_impacto, **IMP_A)),
    "lanca_gelo": dict(armas=["lanca_geada"],
                       voo=dict(fn=lanca_voo, quadro=(30, 6), n=4, fps=12, loop=True, ancora=(22, 3)),
                       impacto=dict(fn=lanca_impacto, **IMP_A)),
    "dardo_verde": dict(armas=["dardos_peconhentos"],
                        voo=dict(fn=dardo_voo, quadro=(16, 8), n=4, fps=12, loop=True, ancora=(12, 4)),
                        impacto=dict(fn=dardo_impacto, **IMP_A)),
    "feixe_dourado": dict(armas=["raio_solar"],
                          voo=dict(fn=feixe_voo, quadro=(64, 6), n=4, fps=12, loop=True, ancora=(48, 3)),
                          impacto=dict(fn=feixe_impacto, **IMP_A)),
    "adaga_aco": dict(armas=["adagas_voadoras"],
                      voo=dict(fn=adaga_voo, quadro=(14, 14), n=8, fps=16, loop=True, ancora=(7, 7), gira=True),
                      impacto=dict(fn=adaga_impacto, **IMP_A)),
    "shuriken_sombria": dict(armas=["estrelas_sombra"],
                             voo=dict(fn=shuriken_voo, quadro=(14, 14), n=8, fps=16, loop=True, ancora=(7, 7),
                                      gira=True),
                             impacto=dict(fn=shuriken_impacto, **IMP_A)),
    "disco_ferro": dict(armas=["bumerangue_ferro"],
                        voo=dict(fn=disco_voo, quadro=(20, 20), n=8, fps=16, loop=True, ancora=(10, 10), gira=True),
                        impacto=dict(fn=disco_impacto, **IMP_A)),
    "laminas": dict(armas=["laminas"],
                    voo=dict(fn=laminas_voo, quadro=(24, 24), n=8, fps=16, loop=True, ancora=(12, 12), gira=True),
                    impacto=dict(fn=laminas_impacto, **IMP_A)),
    "bola_fogo": dict(armas=["bola_fogo", "fogo_do_ceu"],
                      voo=dict(fn=bola_fogo_voo, quadro=(26, 18), n=4, fps=12, loop=True, ancora=(19, 9)),
                      impacto=dict(fn=bola_fogo_impacto, **IMP_B)),
    "bola_chumbo": dict(armas=["bolas_chumbo"],
                        voo=dict(fn=bola_chumbo_voo, quadro=(24, 16), n=4, fps=12, loop=True, ancora=(18, 8)),
                        impacto=dict(fn=bola_chumbo_impacto, **IMP_B)),
}


def gerar_tira(spec):
    w, h = spec["quadro"]
    quadros = []
    for t in range(spec["n"]):
        q = spec["fn"](t)
        assert q.shape == (h, w, 4), (spec["fn"].__name__, q.shape)
        quadros.append(q)
    return np.concatenate(quadros, axis=1), quadros


def indice():
    folhas = {}
    for nome, s in SPRITES.items():
        anims = {}
        for an in ("voo", "impacto"):
            sp = s[an]
            d = {"arquivo": f"{nome}_{an}.png", "quadro": list(sp["quadro"]), "n": sp["n"], "fps": sp["fps"],
                 "loop": sp["loop"], "ancora": list(sp["ancora"])}
            if sp.get("gira"):
                d["gira"] = True
            anims[an] = d
        folhas[nome] = {"armas": s["armas"], "anims": anims}
    return {"_gerado_por": "jogos/hordas/fonte_arte/armas_anim/gerar_projeteis.py (nao edite a mao)",
            "folhas": folhas}


def previa(nome, voo, imp, sv, si):
    """GIF 4x sem suavizar: 3 voltas do voo e o impacto no ponto da cabeça, fundo #2a2a30."""
    (vw, vh), (ax, ay) = sv["quadro"], sv["ancora"]
    (iw, ih), (ix, iy) = si["quadro"], si["ancora"]
    pad = 4
    esq, cima = max(ax, ix) + pad, max(ay, iy) + pad
    W = esq + max(vw - ax, iw - ix) + pad
    H = cima + max(vh - ay, ih - iy) + pad
    frames, durs = [], []

    def quadro(img, ox, oy, dur):
        f = Image.new("RGBA", (W, H), FUNDO_PREVIA + (255,))
        f.alpha_composite(Image.fromarray(img, "RGBA"), (ox, oy))
        frames.append(f.convert("RGB").resize((W * 4, H * 4), Image.NEAREST))
        durs.append(dur)

    for _ in range(3):
        for q in voo:
            quadro(q, esq - ax, cima - ay, round(1000 / sv["fps"]))
    for q in imp:
        quadro(q, esq - ix, cima - iy, round(1000 / si["fps"]))
    quadro(np.zeros((1, 1, 4), np.uint8), 0, 0, 400)
    pal = [f.quantize(colors=255, method=Image.Quantize.MAXCOVERAGE) for f in frames]
    pal[0].save(os.path.join(PREVIAS, f"{nome}.gif"), save_all=True, append_images=pal[1:], duration=durs,
                loop=0, disposal=1)


def conferir():
    """Verificador: tamanho da tira, quadros diferentes, alfa só 0/255, pixels soltos e tons."""
    idx = json.load(open(os.path.join(SAIDA, "indice_projeteis.json"), encoding="utf-8"))
    falhas = []
    for nome, f in idx["folhas"].items():
        for an, d in f["anims"].items():
            img = np.array(Image.open(os.path.join(SAIDA, d["arquivo"])).convert("RGBA"))
            (w, h), n = d["quadro"], d["n"]
            msg = []
            if img.shape[:2] != (h, w * n):
                msg.append(f"tamanho {img.shape[1]}x{img.shape[0]} != {w * n}x{h}")
            al = set(np.unique(img[..., 3]).tolist())
            if not al <= {0, 255}:
                msg.append(f"alfa intermediario {sorted(al - {0, 255})[:5]}")
            qs = [img[:, i * w:(i + 1) * w] for i in range(n)]
            hs = [hashlib.sha1(q.tobytes()).hexdigest() for q in qs]
            if len(set(hs)) != n:
                msg.append("quadros repetidos")
            difs = [int(((qs[i] != qs[j]).any(axis=2)).sum()) for i in range(n) for j in range(i + 1, n)]
            vazios = [i for i, q in enumerate(qs) if not q[..., 3].any()]
            if vazios:
                msg.append(f"quadros vazios {vazios}")
            ax, ay = d["ancora"]
            if not (0 <= ax < w and 0 <= ay < h):
                msg.append("ancora fora")
            sp = SPRITES[nome][an]
            fa = None
            sol = sum(len(isolados(q, faiscas=())) for q in qs)
            cores = len({tuple(p) for p in img[img[..., 3] > 0][:, :3].tolist()})
            print(f"  {d['arquivo']:28s} {img.shape[1]:4d}x{img.shape[0]:<3d} n={n} tons={cores:2d} "
                  f"menor_dif={min(difs)}px soltos(faisca)={sol} {'OK' if not msg else 'FALHA: ' + '; '.join(msg)}")
            if msg:
                falhas.append((d["arquivo"], msg))
    return falhas


def main():
    os.makedirs(SAIDA, exist_ok=True)
    os.makedirs(PREVIAS, exist_ok=True)
    if "--conferir" not in sys.argv:
        for nome, s in SPRITES.items():
            tiras = {}
            for an in ("voo", "impacto"):
                tira, qs = gerar_tira(s[an])
                Image.fromarray(tira, "RGBA").save(os.path.join(SAIDA, f"{nome}_{an}.png"), optimize=True)
                tiras[an] = qs
            previa(nome, tiras["voo"], tiras["impacto"], s["voo"], s["impacto"])
        with open(os.path.join(SAIDA, "indice_projeteis.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(indice(), f, ensure_ascii=False, indent=1)
            f.write("\n")
    falhas = conferir()
    if falhas:
        print("FALHAS:", falhas)
        sys.exit(1)
    print("tudo certo")


if __name__ == "__main__":
    main()

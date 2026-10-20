# -*- coding: utf-8 -*-
"""Folhas animadas das evoluções que voam (grupo "evo_projeteis").

Gera, pixel a pixel e sem rede, as tiras de voo/impacto de urso_solar, chuva_de_lacas, bola_incendiaria,
chuva_de_ferro e tempestade_primordial, as peças que orbitam no anel_de_brasas (giro + impacto) e as duas auras
de chão (anel_de_brasas e aura_fogo, camada aditiva). Escreve o índice indice_evo_projeteis.json (esquema de
docs/combate_v2/SPEC_ARTE.md) e as prévias GIF 4x. Rodar de novo dá as mesmas folhas (semente fixa).

    python -I gerar_evo_projeteis.py            # gera tudo e confere
    python -I gerar_evo_projeteis.py --conferir # só confere as folhas já gravadas

Reaproveita as utilidades de pixel de gerar_projeteis.py (mesma pasta). Regras: alfa só 0 ou 255, contorno escuro
de 1 px nos corpos, luz fixa de cima à esquerda, poucos tons por material, limpeza de pixel solto (só as cores
declaradas como faísca ficam sozinhas). As auras esmaecem com pontilhado em traços de 2x1 e emendam no loop
(todo movimento depende do tempo só por múltiplos inteiros de 2*pi*t/n).
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
sys.path.insert(0, AQUI)
import gerar_projeteis as gp  # noqa: E402

from gerar_projeteis import (novo, por, viz4, contornar, sob, linha, raio_polar, disco, anel,  # noqa: E402
                             ruido_suave, isolados, sombrear, grade, rast, girar_grade, arco_rastro, tom_fogo,
                             FOGO, FOGO_C, FUMACA, ACO, ACO_C, ROXO, ROXO_C, ROXO_FUMO, ROXO_FAISCA, GELO, GELO_C,
                             OURO, BRANCO, LATAO, SOMBRA, LUZ, TAU)

RAIZ = gp.RAIZ
SAIDA = gp.SAIDA
PREVIAS = gp.PREVIAS
FUNDO_PREVIA = gp.FUNDO_PREVIA
INDICE = "indice_evo_projeteis.json"
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])

# --------------------------------------------------------------------------------------------------------------
# Paletas (das imagens paradas de assets/v2/armas/<id>.png)
# --------------------------------------------------------------------------------------------------------------
SOL = [(255, 252, 228), (255, 234, 146), (252, 204, 84), (240, 158, 52), (212, 110, 34), (158, 68, 26)]
SOL_C = (104, 46, 22)
LAMINA = [(70, 72, 96), (120, 126, 156), (180, 196, 222), (236, 246, 255)]
LAMINA_C = (30, 22, 44)
VENTO = [(150, 186, 226), (200, 226, 250)]
ROCHA = [(52, 34, 34), (82, 54, 44), (118, 80, 62), (160, 120, 100), (204, 178, 168)]
ROCHA_C = (30, 16, 20)
FERRO = [(52, 50, 58), (84, 80, 92), (124, 118, 132), (180, 174, 190)]
FERRO_C = (24, 18, 28)
BRASA_FERRO = [(150, 40, 24), (226, 92, 32), (252, 176, 70)]
CRISTAL = [(56, 96, 178), (88, 146, 226), (150, 200, 250), (228, 244, 255)]
CRISTAL_C = (24, 32, 76)
HASTE = [(70, 30, 82), (112, 52, 124), (160, 98, 168)]
GUARDA = [(92, 30, 32), (142, 58, 44), (190, 104, 70)]
RAIO = [(255, 252, 214), (255, 222, 110), (240, 170, 60)]
CARVAO = [(40, 22, 24), (70, 34, 30), (112, 44, 32)]
CARVAO_C = (24, 12, 16)
EMBER = [(255, 236, 170), (255, 170, 80), (238, 96, 40), (196, 50, 30)]

CONTORNOS = {SOL_C, LAMINA_C, ROCHA_C, FERRO_C, CRISTAL_C, CARVAO_C, FOGO_C, ROXO_C, GELO_C, ACO_C}

# auras (camada aditiva: tons claros; o mais escuro só aparece em pontilhado)
AURA_FOGO = [(255, 250, 222), (255, 224, 128), (255, 174, 66), (246, 118, 36), (206, 70, 24)]
AURA_BRASA = [(255, 232, 180), (255, 164, 92), (244, 98, 48), (214, 54, 34), (164, 34, 30)]


def limpar(a, faiscas=(), protegidos=()):
    """Como gerar_projeteis.limpar, mas com os contornos deste grupo."""
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
                bons = [v for v in viz if v not in CONTORNOS] or viz
                a[y, x, :3] = Counter(bons).most_common(1)[0][0]
            mudou = True
        if not mudou:
            break
    return a


def tira_pontas(a):
    """Some com pixel opaco sem vizinho (4) opaco: evita espinho de 1 px antes do contorno."""
    m = a[..., 3] > 0
    h, w = m.shape
    for y in range(h):
        for x in range(w):
            if m[y, x] and sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                               if 0 <= x + dx < w and 0 <= y + dy < h and m[y + dy, x + dx]) == 0:
                a[y, x] = 0
    return a


def faisca2(a, x, y, cor, horiz=True):
    por(a, x, y, cor, vazio=True)
    por(a, x + (1 if horiz else 0), y + (0 if horiz else 1), cor, vazio=True)


def ziguezague(a, rng, x0, y0, x1, y1, nseg, amp, cor, vazio=True):
    """Raio quebrado de (x0,y0) a (x1,y1); devolve os pontos."""
    pts = [(x0, y0)]
    for i in range(1, nseg):
        f = i / nseg
        px = x0 + (x1 - x0) * f
        py = y0 + (y1 - y0) * f
        nx, ny = -(y1 - y0), (x1 - x0)
        nn = math.hypot(nx, ny) or 1
        d = rng.uniform(-amp, amp)
        pts.append((px + nx / nn * d, py + ny / nn * d))
    pts.append((x1, y1))
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        linha(a, ax, ay, bx, by, cor, vazio)
    return pts


def calor_linguas(W, H, cx, cy, t, linguas, n=4):
    """Campo de calor das línguas de fogo que saem para trás (esquerda) de (cx, cy)."""
    calor = np.full((H, W), -1.0)
    for y in range(H):
        for x in range(W):
            px, py = x + 0.5, y + 0.5
            for (oy, curva, comp, esp, fase) in linguas:
                comp_t = comp * (1 + 0.14 * math.sin(TAU * (t / n + fase)))
                u = (cx - px) / comp_t
                if not (0.0 <= u < 1.0):
                    continue
                yc = cy + oy * min(1.0, u * 2.5) + curva * u + 1.3 * u * math.sin(TAU * (u * 1.25 - t / n + fase))
                hw = esp * (1 - u) ** 0.75 * (1 + 0.18 * math.sin(TAU * (t / n + fase * 2)))
                if abs(py - yc) <= hw:
                    h = 0.86 - 0.9 * u - 0.28 * abs(py - yc) / max(hw, 0.1)
                    calor[y, x] = max(calor[y, x], h)
    return calor


# --------------------------------------------------------------------------------------------------------------
# urso_solar: cabeça de urso feita de sol, crina de fogo dourado; 42x18, cabeça em (31,9)
# --------------------------------------------------------------------------------------------------------------
def tom_sol(h):
    for lim, i in ((0.9, 0), (0.74, 1), (0.56, 2), (0.4, 3), (0.24, 4)):
        if h > lim:
            return SOL[i]
    return SOL[5]


URSO_LINGUAS = [
    (0.0, 0.0, 22.0, 4.0, 0.00),
    (-3.0, -1.6, 15.0, 2.2, 0.30),
    (3.0, 1.4, 14.0, 2.1, 0.62),
    (-4.8, -2.2, 8.5, 1.4, 0.15),
    (4.6, 2.0, 8.0, 1.3, 0.80),
]


def urso_solar_voo(t):
    W, H = 42, 18
    hx, hy = 31.5, 9.5
    # crina de fogo: línguas para trás e uma juba que abraça a nuca
    calor = calor_linguas(W, H, 28.0, hy, t, URSO_LINGUAS)
    for y in range(H):
        for x in range(W):
            px, py = x + 0.5, y + 0.5
            d = math.hypot(px - hx, py - hy)
            g = math.atan2(py - hy, px - hx)
            if px < hx + 1.0 and d <= 7.0 + 0.9 * math.sin(5 * g + TAU * t / 4):
                calor[y, x] = max(calor[y, x], 0.7 - 0.09 * (d - 4.5))
    fogo = novo(W, H)
    for y in range(H):
        for x in range(W):
            if calor[y, x] > -0.9:
                por(fogo, x, y, tom_sol(calor[y, x] - 0.12))
    tira_pontas(fogo)
    fogo[:, 0] = 0
    contornar(fogo, SOL_C, borda_livre=False)
    fogo[:, 0] = 0
    # cabeça de urso de luz: cabeça redonda, duas orelhas e focinho, luz de cima à esquerda
    partes = [(36.8, 11.3, 2.4, 1.6, 'F'), (hx, hy + 0.5, 4.6, 4.5, 'C'), (28.4, 5.4, 1.7, 1.7, 'O'),
              (33.6, 5.0, 1.7, 1.7, 'O')]
    cab = novo(W, H)
    for y in range(H):
        for x in range(W):
            px, py = x + 0.5, y + 0.5
            for ox, oy, rx, ry, k in partes:
                q = ((px - ox) / rx) ** 2 + ((py - oy) / ry) ** 2
                if q <= 1:
                    lum = ((px - ox) / rx * LUZ[0] + (py - oy) / ry * LUZ[1])
                    if k == 'F':
                        cor = SOL[0] if lum > -0.3 else SOL[1]
                    else:
                        cor = SOL[0] if lum > 0.7 else SOL[1] if lum > 0.1 else SOL[2] if lum > -0.55 else SOL[3]
                    por(cab, x, y, cor)
                    break
    for x, y in ((28, 5), (33, 5), (34, 5)):
        por(cab, x, y, SOL[3])
    contornar(cab, SOL_C)
    a = fogo.copy()
    m = cab[..., 3] > 0
    a[m] = cab[m]
    # olho fechado de contente, nariz e a boca
    por(a, 33, 9, SOL_C)
    por(a, 34, 9, SOL_C)
    por(a, 38, 10, SOL_C)
    por(a, 39, 10, SOL_C)
    por(a, 36, 12, SOL[3])
    por(a, 37, 12, SOL[3])
    # brilho que pisca na testa (muda de lugar)
    gx, gy = [(29, 8), (30, 7), (29, 7), (30, 8)][t]
    por(a, gx, gy, SOL[0])
    por(a, gx + 1, gy, SOL[0])
    # raios de sol que pulsam em volta da cabeça (cruz e xis alternados)
    fx = novo(W, H)
    for i in range(4):
        ang = i * TAU / 4 + (TAU / 8 if t % 2 else 0) - 0.4
        r0 = 7.4
        r1 = r0 + (1.6 if t % 2 else 2.4)
        raio_polar(fx, hx + 1, hy, ang, r0, r1, SOL[1], vazio=True)
    # fagulhas douradas que ficam para trás (3 px por quadro, período 12)
    for k, (x0, y) in enumerate([(3, 3), (9, 14), (6, 1), (12, 16), (1, 9)]):
        x = (x0 + 12 - 3 * t) % 12
        faisca2(fx, x, y, SOL[1 if k % 2 else 2])
    return limpar(sob(a, fx), faiscas=[SOL[0], SOL[1], SOL[2]])


def urso_solar_impacto(t):
    """Patada de sol: três garras douradas riscam o ponto."""
    a = novo(20, 20)
    c = 10.0
    garras = [(-3.2, 0), (0, 0), (3.2, 0)]
    if t == 0:
        for i in range(4):
            raio_polar(a, c, c, i * TAU / 4 + 0.78, 1, 6.5, SOL[1])
        disco(a, c, c, 2.6, SOL[1])
        disco(a, c, c, 1.6, SOL[0])
        for ox, _ in garras:
            linha(a, c + ox - 1, c - 3, c + ox + 1, c + 1, SOL[2], vazio=True)
    elif t == 1:
        for ox, _ in garras:
            x0, y0, x1, y1 = c + ox - 3.0, c - 6.5, c + ox + 3.0, c + 6.5
            linha(a, x0 + 1, y0, x1 + 1, y1, SOL[2])
            linha(a, x0, y0 + 1, x1, y1 - 1, SOL[0])
        disco(a, c, c, 1.2, SOL[1], vazio=True)
    else:
        for ox, _ in garras:
            x0, y0, x1, y1 = c + ox - 3.0, c - 6.5, c + ox + 3.0, c + 6.5
            linha(a, x0 + (x1 - x0) * 0.3 + 1, y0 + (y1 - y0) * 0.3, x0 + (x1 - x0) * 0.75 + 1,
                  y0 + (y1 - y0) * 0.75, SOL[3])
        for i in range(5):
            ang = i * TAU / 5 + 0.5
            faisca2(a, c + 8.6 * math.cos(ang) - 0.5, c + 8.6 * math.sin(ang) - 0.5, SOL[1])
    return limpar(a, faiscas=[SOL[0], SOL[1]])


# --------------------------------------------------------------------------------------------------------------
# chuva_de_lacas: lâmina de aço com sulco de sombra roxa e rastro de vento claro; 40x12, cabeça em (30,6)
# --------------------------------------------------------------------------------------------------------------
LACA_CORPO = [
    "........................................",
    "........................................",
    "........................................",
    "...........UU...........................",
    "...........UU...........................",
    "....P......UUBBBBBBBBBBBBBBBBB..........",
    "...PPGGGGGGUURRRRRRRRRRRRBBBBBBBB.......",
    "....P......UUBBBBBBBBBBBBBBBBB..........",
    "...........UU...........................",
    "...........UU...........................",
    "........................................",
    "........................................",
]


def lacas_voo(t):
    W, H = 40, 12
    lab = grade(LACA_CORPO)
    # ponta muda de afiada para lascada (brilho de corte) e a guarda balança
    if t in (1, 3):
        lab[5, 29] = '.'
        lab[7, 29] = '.'
    corpo = sombrear(lab, {'B': LAMINA, 'R': [HASTE[0], HASTE[1], HASTE[2]], 'U': [GUARDA[0], GUARDA[1], GUARDA[2]],
                           'G': HASTE[:2], 'P': LATAO[1:]})
    # fio de luz correndo pela aresta de cima da lâmina
    for x in ([14, 15, 16], [19, 20, 21], [24, 25, 26], [28, 29, 30])[t]:
        por(corpo, x, 5 if x < 29 else 6, LAMINA[3])
    contornar(corpo, LAMINA_C)
    fx = novo(W, H)
    # sombra roxa que escorre do sulco e ondula para trás
    for x in range(0, 11):
        u = (10.5 - x) / 10.0
        yc = 6.5 + 1.6 * u * math.sin(TAU * (u * 0.9 - t / 4))
        hw = 1.6 * max(0.0, 1 - u) ** 0.6 + 0.3
        for y in range(2, 11):
            dd = abs(y + 0.5 - yc)
            if dd <= hw:
                por(fx, x, y, ROXO_FUMO[1] if dd <= hw * 0.45 else ROXO_FUMO[0], vazio=True)
    # riscos de vento claros acima e abaixo (4 px por quadro, período 16)
    for (x0, y, comp, cor) in [(6, 2, 5, VENTO[1]), (14, 9, 4, VENTO[0]), (1, 10, 3, VENTO[0]), (10, 1, 3, VENTO[0])]:
        xs = (x0 + 16 - 4 * t) % 16 + 6
        for x in range(xs, xs + comp):
            por(fx, x, y, cor, vazio=True)
    return limpar(sob(corpo, fx), faiscas=[LAMINA[3], ROXO_FAISCA])


def lacas_impacto(t):
    """Corte cruzado: risco branco em X, faíscas de aço e lascas de sombra."""
    a = novo(20, 20)
    c = 10.0
    rng = np.random.default_rng(31)
    angs = [i * TAU / 6 + rng.uniform(-0.25, 0.25) for i in range(6)]
    if t == 0:
        linha(a, 4, 6, 16, 14, LAMINA[3])
        linha(a, 4, 7, 15, 14, LAMINA[2])
        linha(a, 6, 15, 15, 5, LAMINA[2])
        disco(a, c, c, 1.6, BRANCO)
    elif t == 1:
        linha(a, 2, 5, 18, 15, LAMINA[2])
        linha(a, 4, 16, 16, 3, LAMINA[1])
        for g in angs:
            raio_polar(a, c, c, g, 4.0, 7.0, OURO[2], vazio=True)
            por(a, c + 7.8 * math.cos(g) - 0.5, c + 7.8 * math.sin(g) - 0.5, BRANCO)
        disco(a, c, c, 1.2, ROXO[2])
    else:
        for g in angs:
            raio_polar(a, c, c, g, 7.6, 8.8, OURO[0], vazio=True)
        for i in range(3):
            g = i * TAU / 3 + 0.9
            x, y = c + 4.6 * math.cos(g), c + 4.6 * math.sin(g)
            faisca2(a, x - 0.5, y - 0.5, ROXO[2])
            por(a, x - 0.5, y + 0.5, ROXO[1], vazio=True)
    return limpar(a, faiscas=[BRANCO, OURO[0], ROXO[2]])


# --------------------------------------------------------------------------------------------------------------
# bola_incendiaria: pedra pesada em brasa que rola, envolta em fogo; 40x20, cabeça em (30,10); explosão 56x56
# --------------------------------------------------------------------------------------------------------------
INC_LINGUAS = [
    (0.0, 0.0, 22.0, 5.4, 0.00),
    (-3.4, -2.0, 15.0, 2.8, 0.30),
    (3.2, 1.8, 14.0, 2.7, 0.62),
    (-5.6, -2.8, 9.0, 1.7, 0.15),
    (5.4, 2.6, 8.5, 1.6, 0.80),
]
RACHA_INC = [(-3, -1), (-2, -1), (-1, 0), (0, 0), (1, 0), (1, 1), (2, 2), (0, -1), (0, -2), (-1, 2), (-2, 2)]


def bola_inc_voo(t):
    W, H, cx, cy, r = 40, 20, 30, 10, 5.6
    # fogo: línguas para trás e uma capa de chama abraçando a metade de trás da pedra
    calor = calor_linguas(W, H, 29.0, 10.5, t, INC_LINGUAS)
    for y in range(H):
        for x in range(W):
            px, py = x + 0.5, y + 0.5
            d = math.hypot(px - cx - 0.5, py - cy - 0.5)
            if d <= r + 1.8 + 0.7 * math.sin(math.atan2(py - cy, px - cx) * 5 + TAU * t / 4) and px < cx + 2.5:
                calor[y, x] = max(calor[y, x], 0.62 - 0.08 * (d - r))
    fogo = novo(W, H)
    for y in range(H):
        for x in range(W):
            if calor[y, x] > -0.9:
                por(fogo, x, y, tom_fogo(calor[y, x]))
    tira_pontas(fogo)
    fogo[:, 0] = 0
    contornar(fogo, FOGO_C, borda_livre=False)
    fogo[:, 0] = 0
    # pedra: esfera de rocha com luz de cima à esquerda e rachas de lava que giram com ela
    pedra = novo(W, H)
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) / r, (y - cy) / r
            q = dx * dx + dy * dy
            if q > 1:
                continue
            nz = math.sqrt(1 - q)
            lum = dx * -0.55 + dy * -0.6 + nz * 0.58
            i = 4 if lum > 0.95 else 3 if lum > 0.72 else 2 if lum > 0.42 else 1 if lum > 0.1 else 0
            por(pedra, x, y, ROCHA[i])
    for k, (dx, dy) in enumerate(RACHA_INC):
        for _ in range(t):
            dx, dy = -dy, dx
        x, y = cx + dx, cy + dy
        if (x - cx) ** 2 + (y - cy) ** 2 <= r * r - 2:
            por(pedra, x, y, FOGO[1] if k in (3, 4) else FOGO[3])
    contornar(pedra, ROCHA_C)
    a = fogo.copy()
    m = pedra[..., 3] > 0
    a[m] = pedra[m]
    # brasas soltas que ficam para trás
    for k, (x0, y) in enumerate([(2, 3), (8, 16), (5, 1), (11, 18), (0, 10)]):
        x = (x0 + 12 - 3 * t) % 12
        faisca2(a, x, y, FOGO[2 if k % 2 else 3])
    return limpar(a, faiscas=[FOGO[1], FOGO[2], FOGO[3]], protegidos=[FOGO[1], FOGO[3]])


def _lasca(a, x, y, forma, k):
    """Pedaço de pedra (3 px de lado) que capota; luz em cima à esquerda, brasa embaixo nos primeiros quadros."""
    pts = [[(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1), (1, 2)],
           [(1, 0), (0, 1), (1, 1), (2, 1), (0, 2), (1, 2)],
           [(0, 0), (1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (2, 2)],
           [(1, 0), (2, 0), (0, 1), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2)]][(forma + k) % 4]
    for dx, dy in pts:
        topo = (dx, dy - 1) not in pts or (dx - 1, dy) not in pts
        base = (dx, dy + 1) not in pts and (dx + 1, dy) not in pts
        cor = ROCHA[4] if topo and not base else (FOGO[3] if k == 0 else ROCHA[1]) if base else ROCHA[2]
        por(a, x + dx, y + dy, cor)
    for dx, dy in pts:
        for ex, ey in ((1, 0), (0, 1), (-1, 0), (0, -1)):
            if (dx + ex, dy + ey) not in pts:
                por(a, x + dx + ex, y + dy + ey, ROCHA_C)


def bola_inc_impacto(t):
    W, c = 56, 28.0
    rng = np.random.default_rng(3303)
    ph = rng.uniform(0, TAU, 4)
    n1 = ruido_suave(W, W, 5, 900 + t)
    n2 = ruido_suave(W, W, 3, 950 + t)
    lascas = [(i * TAU / 8 + rng.uniform(-0.3, 0.3), int(rng.integers(0, 4))) for i in range(8)]
    if t == 0:
        a = novo(W, W)
        disco(a, c, c, 9.0, FOGO[3])
        disco(a, c, c, 6.5, FOGO[1])
        disco(a, c, c, 4.0, FOGO[0])
        for i in range(8):
            raio_polar(a, c, c, i * TAU / 8 + 0.2, 9.5, 15 if i % 2 == 0 else 12, FOGO[1] if i % 2 == 0 else FOGO[2],
                       vazio=True)
        m = a[..., 3] > 0
        borda = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
        a[borda & (a[..., 0] == FOGO[3][0]), :3] = FOGO_C
        return limpar(a, faiscas=[FOGO[1], FOGO[2]])
    if t <= 3:
        R = [0, 16.0, 22.0, 24.5][t]
        heat = [0, 1.55, 1.15, 0.78][t]
        a = novo(W, W)
        for y in range(W):
            for x in range(W):
                dx, dy = x + 0.5 - c, y + 0.5 - c
                d, g = math.hypot(dx, dy), math.atan2(dy, dx)
                lump = 1 + 0.17 * math.sin(6 * g + ph[0] + t) + 0.1 * math.sin(4 * g + ph[1] - t * 0.6) \
                    + 0.2 * (n1[y, x] - 0.5)
                de = d / (R * lump)
                if de > 1:
                    continue
                if t == 3 and de < 0.5 + 0.25 * (n2[y, x] - 0.5):
                    continue
                T = heat * (1 - 0.8 * de) + 0.35 * (n2[y, x] - 0.5)
                if t >= 2:
                    T -= 0.4 * max(0.0, -dy / R) * (t - 1) / 2
                if T > 0.16:
                    cor = tom_fogo(T * 0.95 - 0.02)
                else:
                    lum = (dx * LUZ[0] + dy * LUZ[1]) / max(d, 1)
                    cor = FUMACA[2] if lum > 0.3 else FUMACA[1] if lum > -0.3 else FUMACA[0]
                por(a, x, y, cor)
        m = a[..., 3] > 0
        borda = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
        a[borda, :3] = FOGO_C if t < 3 else FUMACA[0]
        k = t - 1
        for g, forma in lascas:
            rr = [14.0, 20.5, 24.5][k]
            x = int(c + rr * math.cos(g))
            y = int(c + rr * math.sin(g) + [0, 1, 3][k])
            _lasca(a, x, y, forma, k)
        return limpar(a, faiscas=[FOGO[2], FOGO[3]], protegidos=[FOGO[2]])
    k = t - 4
    puffs = [(c, c - 4 - 2 * k, [9.5, 6.0][k])]
    for i in range([9, 7][k]):
        g = i * TAU / [9, 7][k] + ph[2]
        rho = [16.0, 18.5][k] * (0.9 + 0.2 * math.sin(i * 1.3))
        puffs.append((c + rho * math.cos(g), c + rho * math.sin(g) * 0.9 - 3 - 3 * k, [6.4, 4.0][k]))
    n3 = ruido_suave(W, W, 6, 980 + t)
    a = gp._bolhas(W, c, puffs, FUMACA, FUMACA[0], n1, 0, ruido2=n3, corte2=[0.1, 0.02][k])
    for y in range(W):
        for x in range(W):
            if a[y, x, 3] and n2[y, x] > [0.76, 0.85][k] and tuple(a[y, x, :3]) != FUMACA[0]:
                por(a, x, y, FOGO[4] if k == 0 else FOGO[5])
    for g, forma in lascas[::2]:
        rr = [26.0, 0][k]
        if rr:
            _lasca(a, int(c + rr * math.cos(g)), int(c + rr * math.sin(g) + 6), forma, 2)
    for i in range(10):
        g = i * TAU / 10 + ph[3]
        rr = [23.0, 25.5][k]
        faisca2(a, c + rr * math.cos(g) - 0.5, c + rr * math.sin(g) * 0.9 - 0.5 + 2 * k, FOGO[3 + k])
    return limpar(a, faiscas=[FOGO[3], FOGO[4], FOGO[5]])


# --------------------------------------------------------------------------------------------------------------
# chuva_de_ferro: estrela de ferro serrilhada em brasa que gira, com redemoinho de fogo; 28x28 (gira)
# --------------------------------------------------------------------------------------------------------------
DENTES = 5
PASSO_FERRO = 3 * TAU / (8 * DENTES)  # 27°: 8 quadros = 3 dentes (o giro emenda e anda para a frente)


def ferro_voo(t):
    W = 28
    c = 14.0
    th = t * PASSO_FERRO

    def raio(g):
        f = ((DENTES * (g - th) / TAU) % 1.0)
        return 5.4 + 4.6 * (1 - f) ** 1.4

    def dentro(x, y):
        vx, vy = x - c, y - c
        r = math.hypot(vx, vy)
        return r <= raio(math.atan2(vy, vx))

    m = rast(dentro, W, W)
    a = novo(W, W)
    for y in range(W):
        for x in range(W):
            if not m[y, x]:
                continue
            vx, vy = x + 0.5 - c, y + 0.5 - c
            r = math.hypot(vx, vy)
            if r <= 2.2:
                por(a, x, y, BRASA_FERRO[2])
            elif r <= 3.6:
                por(a, x, y, BRASA_FERRO[1])
            else:
                d = (vx * LUZ[0] + vy * LUZ[1]) / 9.0
                i = 2 if d > 0.25 else 1 if d > -0.3 else 0
                por(a, x, y, FERRO[i])
    # fio claro nas arestas viradas para a luz; ponta dos dentes em brasa
    for y in range(W):
        for x in range(W):
            if m[y, x] and tuple(a[y, x, :3]) == FERRO[2] and (not m[y - 1, x] or not m[y, x - 1]):
                por(a, x, y, FERRO[3])
    for k in range(DENTES):
        g = th + k * TAU / DENTES + 0.12
        for rr in (8.4, 9.2):
            x, y = math.floor(c + rr * math.cos(g)), math.floor(c + rr * math.sin(g))
            if 0 <= x < W and 0 <= y < W and m[y, x]:
                por(a, x, y, BRASA_FERRO[1])
        # rebite
        x, y = math.floor(c + 5.0 * math.cos(g + 0.6)), math.floor(c + 5.0 * math.sin(g + 0.6))
        if m[y, x]:
            por(a, x, y, FERRO[0])
    contornar(a, FERRO_C)
    # redemoinho de fogo: línguas que saem das pontas e ficam para trás no giro (mudam a cada quadro)
    fx = novo(W, W)
    for k in range(DENTES):
        g = th + k * TAU / DENTES
        fl = 0.55 + 0.18 * math.sin(TAU * (t / 8) * 3 + k * 1.7)
        arco_rastro(fx, c, c, 11.2, g - 0.12, fl, FOGO[4])
        arco_rastro(fx, c, c, 10.4, g - 0.08, fl * 0.9, FOGO[3])
        arco_rastro(fx, c, c, 12.1, g - 0.25, fl * 0.55, FOGO[5])
        arco_rastro(fx, c, c, 9.6, g - 0.05, fl * 0.45, FOGO[2])
    return limpar(sob(a, fx), faiscas=[BRASA_FERRO[1], FERRO[0]], protegidos=[BRASA_FERRO[1]])


def ferro_impacto(t):
    """Estouro de ferro quente: clarão laranja, estilhaços que voam e uma baforada de fogo."""
    a = novo(20, 20)
    c = 10.0
    rng = np.random.default_rng(41)
    angs = [i * TAU / 7 + rng.uniform(-0.25, 0.25) for i in range(7)]
    if t == 0:
        disco(a, c, c, 4.6, FOGO[3])
        disco(a, c, c, 3.2, FOGO[1])
        disco(a, c, c, 1.6, BRANCO)
        for i in range(4):
            raio_polar(a, c, c, i * TAU / 4 + 0.4, 4.5, 8.0, FOGO[2], vazio=True)
    elif t == 1:
        anel(a, c, c, 5.0, 2.0, FOGO[4], filtro=lambda g: math.sin(5 * g + 0.5) > -0.5)
        anel(a, c, c, 4.0, 1.0, FOGO[2], filtro=lambda g: math.sin(5 * g + 0.5) > -0.2)
        for g in angs:
            x, y = c + 7.4 * math.cos(g) - 0.5, c + 7.4 * math.sin(g) - 0.5
            por(a, x, y, FERRO[3])
            por(a, x + 1, y, FERRO[1])
            por(a, x, y + 1, FERRO_C)
            por(a, x + 1, y + 1, FERRO_C)
    else:
        for g in angs:
            x, y = c + 8.6 * math.cos(g) - 0.5, c + 8.6 * math.sin(g) + 0.5
            por(a, x, y, FERRO[2])
            por(a, x + 1, y, FERRO_C)
        for i in range(3):
            g = i * TAU / 3 + 0.3
            faisca2(a, c + 3.6 * math.cos(g) - 0.5, c + 3.6 * math.sin(g) - 1.5, FUMACA[2])
            por(a, c + 3.6 * math.cos(g) - 0.5, c + 3.6 * math.sin(g) - 0.5, FUMACA[1], vazio=True)
    return limpar(a, faiscas=[BRANCO, FOGO[2], FERRO[2], FERRO[3]])


# --------------------------------------------------------------------------------------------------------------
# tempestade_primordial: lança de cristal azul, haste roxa, guarda de bronze e raios dourados; 72x18, cabeça (54,9)
# --------------------------------------------------------------------------------------------------------------
def _temp_lab():
    """Lança: pomo, haste roxa, guarda de bronze, alvado de aço e o cristal em losango que afina até a ponta."""
    W, H = 72, 18
    lab = np.full((H, W), '.')

    def faixa(x, h, ch):
        for y in range(H):
            if abs(y + 0.5 - 9.0) <= h:
                lab[y, x] = ch

    for x in (7, 8):
        faixa(x, 1.0 if x == 8 else 1.6, 'K')
    for x in range(9, 30):
        faixa(x, 1.0, 'H')
    for x in (30, 31):
        faixa(x, 6.0, 'U')
    for x in range(32, 38):
        faixa(x, 1.6 if x >= 36 else 1.0, 'S')
    for x in range(38, 64):
        h = 3.6 * min(1.0, (x - 37) / 4.5) if x <= 42 else 3.6 * (63.6 - x) / (63.6 - 42)
        faixa(x, max(0.6, h), 'C')
    return lab


def tempestade_voo(t):
    W, H = 72, 18
    lab = _temp_lab()
    corpo = sombrear(lab, {'C': CRISTAL, 'H': HASTE, 'U': GUARDA, 'S': ACO[1:], 'K': LATAO[1:3]})
    # veio de luz no meio do cristal que corre até a ponta
    for x in range([40, 46, 52, 58][t], [40, 46, 52, 58][t] + 4):
        por(corpo, x, 8, CRISTAL[3])
    por(corpo, [44, 50, 56, 42][t], 7, CRISTAL[3])
    contornar(corpo, CRISTAL_C)
    fx = novo(W, H)
    rng = np.random.default_rng(700 + t)
    # raios dourados que estalam em volta da haste (redesenhados a cada quadro)
    for lado in (-1, 1):
        y0 = 9 + lado * 3
        x_ini = rng.uniform(26, 30)
        pts = ziguezague(fx, rng, x_ini, 9 + lado * 1.5, rng.uniform(4, 10), y0 + lado * rng.uniform(0, 3), 6, 2.0,
                         RAIO[1])
        # galho que sai do raio
        i = int(rng.integers(2, 4))
        bx, by = pts[i]
        ziguezague(fx, rng, bx, by, bx - rng.uniform(4, 7), by + lado * rng.uniform(2, 4), 2, 1.0, RAIO[2])
    # estalos curtos perto da guarda e do cristal
    for (x0, y0, x1, y1) in [(33, 4, 37, 6), (34, 14, 38, 12)]:
        if (t + (x0 > 33)) % 2 == 0:
            ziguezague(fx, rng, x0, y0, x1, y1, 2, 1.0, RAIO[0])
    # lascas de gelo que ficam para trás (4 px por quadro, período 16)
    for x0, y, cor in [(3, 4, CRISTAL[2]), (11, 13, CRISTAL[1]), (7, 15, CRISTAL[3]), (14, 2, CRISTAL[3])]:
        x = (x0 + 16 - 4 * t) % 16 + 2
        faisca2(fx, x, y, cor)
    return limpar(sob(corpo, fx), faiscas=[RAIO[0], RAIO[1], RAIO[2], CRISTAL[2], CRISTAL[3]])


def tempestade_impacto(t):
    """Estouro elétrico: clarão, raios que se abrem e um anel azul que puxa para dentro."""
    a = novo(20, 20)
    c = 10.0
    rng = np.random.default_rng(800 + t)
    if t == 0:
        for i in range(4):
            g = i * TAU / 4 + 0.6
            ziguezague(a, rng, c, c, c + 8 * math.cos(g), c + 8 * math.sin(g), 3, 1.3, RAIO[1], vazio=False)
        disco(a, c, c, 2.6, RAIO[0])
        disco(a, c, c, 1.4, BRANCO)
    elif t == 1:
        anel(a, c, c, 7.6, 1.4, CRISTAL[1], filtro=lambda g: math.sin(4 * g) > -0.6)
        for i in range(5):
            g = i * TAU / 5 + 0.2
            pts = ziguezague(a, rng, c + 2 * math.cos(g), c + 2 * math.sin(g), c + 7 * math.cos(g),
                             c + 7 * math.sin(g), 3, 1.2, RAIO[1], vazio=False)
            por(a, pts[-1][0], pts[-1][1], RAIO[0])
        disco(a, c, c, 1.6, CRISTAL[3])
    else:
        anel(a, c, c, 4.6, 1.0, CRISTAL[2], filtro=lambda g: math.sin(3 * g + 0.4) > -0.1)
        for i in range(6):
            g = i * TAU / 6 + 0.5
            x, y = c + 8.2 * math.cos(g) - 0.5, c + 8.2 * math.sin(g) - 0.5
            faisca2(a, x, y, RAIO[2] if i % 2 else CRISTAL[3], horiz=i % 3 != 0)
    return limpar(a, faiscas=[BRANCO, RAIO[0], RAIO[2], CRISTAL[3]])


# --------------------------------------------------------------------------------------------------------------
# anel_de_brasas (peça): meia-lua de ferro em brasa que gira; 24x24 (gira)
# --------------------------------------------------------------------------------------------------------------
def brasa_voo(t):
    W = 24
    c = 12.0
    th = t * TAU / 8
    ux, uy = math.cos(th), math.sin(th)

    ESC, DESL = 0.88, 4.5  # a meia-lua gira em volta do próprio centro de massa

    def local(x, y):  # para o espaço do desenho (ângulo 0 = gume para a direita)
        vx, vy = x - c, y - c
        return (vx * ux + vy * uy) / ESC + DESL, (-vx * uy + vy * ux) / ESC

    def mundo(lx, ly):
        lx, ly = (lx - DESL) * ESC, ly * ESC
        return c + lx * ux - ly * uy, c + lx * uy + ly * ux

    def dentro(x, y):
        lx, ly = local(x, y)
        # meia-lua: dentro do círculo grande, fora do círculo deslocado para trás
        if math.hypot(lx + 1.0, ly) > 8.6:
            return False
        if math.hypot(lx + 4.6, ly + 0.8) < 8.0:
            return False
        return lx > -2.0

    m = rast(dentro, W, W)
    # tira pontas finas
    for _ in range(2):
        nv = sum(np.roll(m, s, ax) for s in (1, -1) for ax in (0, 1))
        m &= nv >= 2
    a = novo(W, W)
    for y in range(W):
        for x in range(W):
            if not m[y, x]:
                continue
            lx, ly = local(x + 0.5, y + 0.5)
            fio = math.hypot(lx + 1.0, ly)  # perto de 8.6 = gume de fora (mais quente)
            vx, vy = x + 0.5 - c, y + 0.5 - c
            lum = (vx * LUZ[0] + vy * LUZ[1]) / 9.0
            if fio > 7.4:
                cor = FOGO[1] if lum > 0.0 else FOGO[2]
            elif fio > 6.2:
                cor = FOGO[3] if lum > -0.2 else FOGO[4]
            else:
                cor = CARVAO[2] if lum > 0.3 else CARVAO[1] if lum > -0.4 else CARVAO[0]
            por(a, x, y, cor)
    # rachas de brasa no miolo escuro (giram com a peça)
    for (lx, ly) in [(4.2, -3.4), (5.0, -2.4), (4.6, 3.2), (5.4, 2.0)]:
        x, y = mundo(lx, ly)
        xi, yi = math.floor(x), math.floor(y)
        if 0 <= xi < W and 0 <= yi < W and m[yi, xi] and tuple(a[yi, xi, :3]) in CARVAO:
            por(a, xi, yi, FOGO[4])
    contornar(a, CARVAO_C)
    fx = novo(W, W)
    # chama nas duas pontas, que fica para trás no giro (muda de comprimento a cada quadro)
    for k, lado in enumerate((1, -1)):
        hx, hy = mundo(-1.6, lado * 8.4)
        alfa = math.atan2(hy - c, hx - c)
        rp = math.hypot(hx - c, hy - c)
        fl = 1 + 0.3 * math.sin(TAU * t / 8 * 2 + k * 2.1)
        arco_rastro(fx, c, c, rp - 0.4, alfa - 0.12, 0.75 * fl, FOGO[3])
        arco_rastro(fx, c, c, rp + 0.6, alfa - 0.18, 0.5 * fl, FOGO[4])
        arco_rastro(fx, c, c, rp - 1.3, alfa - 0.15, 0.35 * fl, FOGO[2])
    # labaredas curtas no gume de fora (sobem e descem fora de fase)
    for j, psi in enumerate((-0.75, 0.0, 0.75)):
        alt = 1.2 + 1.2 * ((t + j) % 2) + (0.6 if (t + j) % 4 == 0 else 0)
        e = 0.6
        while e <= alt:
            x, y = mundo(-1.0 + (8.6 + e) * math.cos(psi), (8.6 + e) * math.sin(psi))
            por(fx, math.floor(x), math.floor(y), FOGO[2] if e < 1.4 else FOGO[3], vazio=True)
            e += 0.5
    # fagulha que se solta
    g = th + math.pi - 0.4 * (t % 2)
    faisca2(fx, c + 10.6 * math.cos(g) - 0.5, c + 10.6 * math.sin(g) - 0.5, EMBER[1])
    return limpar(sob(a, fx), faiscas=[EMBER[1], FOGO[4]], protegidos=[FOGO[4]])


def brasa_impacto(t):
    """Brasas que estouram: clarão vermelho, pedaços de carvão aceso que voam e caem."""
    a = novo(20, 20)
    c = 10.0
    rng = np.random.default_rng(51)
    angs = [i * TAU / 6 + rng.uniform(-0.3, 0.3) for i in range(6)]
    if t == 0:
        disco(a, c, c, 4.0, EMBER[2])
        disco(a, c, c, 2.6, EMBER[1])
        disco(a, c, c, 1.3, EMBER[0])
        for g in angs[::2]:
            raio_polar(a, c, c, g, 4.5, 7.0, EMBER[1], vazio=True)
    elif t == 1:
        anel(a, c, c, 4.6, 1.6, EMBER[2], filtro=lambda g: math.sin(4 * g + 1) > -0.4)
        anel(a, c, c, 3.4, 1.0, EMBER[3], filtro=lambda g: math.sin(4 * g + 1) > 0.2)
        for g in angs:
            x, y = c + 6.8 * math.cos(g) - 0.5, c + 6.8 * math.sin(g) - 0.5
            por(a, x, y, EMBER[1])
            por(a, x + 1, y, EMBER[2])
            por(a, x, y + 1, EMBER[2])
            por(a, x + 1, y + 1, CARVAO[1])
    else:
        for g in angs:
            x, y = c + 8.4 * math.cos(g) - 0.5, c + 8.4 * math.sin(g) + 1.5
            por(a, x, y, EMBER[2])
            por(a, x + 1, y, CARVAO[1])
        for i in range(3):
            g = i * TAU / 3 + 0.7
            faisca2(a, c + 3.4 * math.cos(g) - 0.5, c + 3.4 * math.sin(g) - 2.0, EMBER[1], horiz=False)
    return limpar(a, faiscas=[EMBER[0], EMBER[1], EMBER[2]])


# --------------------------------------------------------------------------------------------------------------
# Auras de chão (128x82, loop 6q, camada aditiva)
# --------------------------------------------------------------------------------------------------------------
AW, AH = 128, 82
ACX, ACY = 64.0, 46.0
ARX, ARY = 52.0, 27.0
_YS, _XS = np.mgrid[0:AH, 0:AW]
_PX, _PY = _XS + 0.5, _YS + 0.5
# pontilhado em traços de 2x1 (o pixel nunca fica sozinho)
_BAY = (BAYER[_YS % 4, (_XS // 2) % 4] + 0.5) / 16


def _turb(t, n, sem):
    """Turbulência que sobe e emenda no loop (frequências de tempo inteiras)."""
    rng = np.random.default_rng(sem)
    s = np.zeros((AH, AW))
    for m in (1, 2, 1, 3):
        kx, ky = rng.uniform(0.18, 0.42), rng.uniform(0.35, 0.7)
        sx = rng.choice([-1, 1])
        s += np.sin(sx * kx * _PX + ky * _PY + TAU * m * t / n + rng.uniform(0, TAU))
    return s / 4


def _chamas(t, n, sem, qtd, alt, larg, sway):
    """Campo de calor das línguas que nascem na elipse do chão e sobem dançando."""
    rng = np.random.default_rng(sem)
    calor = np.full((AH, AW), -1.0)
    turb = _turb(t, n, sem + 1)
    fases = rng.uniform(0, 1, (qtd, 4))
    for i in range(qtd):
        phi = TAU * i / qtd + rng.uniform(-0.12, 0.12)
        bx, by = ACX + ARX * math.cos(phi), ACY + ARY * math.sin(phi)
        prof = (by - (ACY - ARY)) / (2 * ARY)  # 0 = fundo (atrás), 1 = frente
        s = 0.62 + 0.38 * prof
        p = fases[i]
        ht = s * alt * (1 + 0.28 * math.sin(TAU * (t / n + p[0])) + 0.12 * math.sin(TAU * (2 * t / n + p[1])))
        wb = s * larg * (1 + 0.15 * math.sin(TAU * (t / n + p[2])))
        v = (by - _PY) / ht
        xc = bx + s * sway * v * np.sin(TAU * (v * 0.75 - t / n + p[3]))
        dx = np.abs(_PX - xc)
        hw = np.where(v >= 0, wb * np.clip(1 - v, 0, 1) ** 0.75, wb * np.sqrt(np.clip(1 - (v / 0.22) ** 2, 0, 1)))
        ok = (v > -0.22) & (v < 1) & (dx <= hw)
        h = 0.95 * (1 - np.clip(v, 0, 1)) ** 0.8 - 0.55 * (dx / np.maximum(hw, 0.1)) ** 2 + 0.16 * turb
        calor = np.where(ok, np.maximum(calor, h), calor)
        # lambida pequena ao lado, fora de fase
        bx2 = bx + (wb * 0.9 if i % 2 else -wb * 0.9)
        ht2 = ht * (0.55 + 0.2 * math.sin(TAU * (t / n + p[1] + 0.5)))
        v2 = (by + 0.5 - _PY) / ht2
        xc2 = bx2 - s * sway * 0.6 * v2 * np.sin(TAU * (v2 * 0.9 - t / n + p[0]))
        hw2 = wb * 0.55 * np.clip(1 - v2, 0, 1) ** 0.8
        ok2 = (v2 >= 0) & (v2 < 1) & (np.abs(_PX - xc2) <= hw2)
        h2 = 0.7 * (1 - np.clip(v2, 0, 1)) - 0.5 * (np.abs(_PX - xc2) / np.maximum(hw2, 0.1)) ** 2 + 0.14 * turb
        calor = np.where(ok2, np.maximum(calor, h2), calor)
    return calor


def _pinta_calor(calor, pal, limiares, dens_baixa):
    """Calor -> índice de paleta; a faixa mais fria sai em pontilhado (esmaece)."""
    idx = np.full((AH, AW), -1)
    for i, lim in enumerate(limiares):
        idx = np.where((idx < 0) & (calor > lim), i, idx)
    frio = (idx < 0) & (calor > limiares[-1] - 0.16)
    dens = np.clip((calor - (limiares[-1] - 0.16)) / 0.16, 0, 1) * dens_baixa
    idx = np.where(frio & (_BAY < dens), len(limiares) - 1, idx)
    a = novo(AW, AH)
    for i, cor in enumerate(pal[:len(limiares)]):
        mm = idx == i
        a[mm, :3] = cor
        a[mm, 3] = 255
    return a


def _fagulhas(a, t, n, sem, qtd, subida, cores):
    """Fagulhas que nascem no anel, sobem e somem dentro do ciclo (emenda no loop)."""
    rng = np.random.default_rng(sem)
    for k in range(qtd):
        phi = rng.uniform(0, TAU)
        off = rng.uniform(0, 1)
        sub = subida * rng.uniform(0.6, 1.0)
        u = (t / n + off) % 1.0
        if u > 0.82:
            continue
        bx = ACX + ARX * math.cos(phi) * rng.uniform(0.92, 1.08)
        by = ACY + ARY * math.sin(phi) * rng.uniform(0.92, 1.08)
        x = bx + 2.2 * math.sin(TAU * (u + off))
        y = by - 6 - u * sub
        cor = cores[0] if u < 0.35 else cores[1] if u < 0.65 else cores[2]
        faisca2(a, x, y, cor, horiz=k % 3 != 0)


def _base_anel(a, t, n, pal_i, cor, esp, dens):
    """Faixa de calor rente ao chão na elipse, em pontilhado."""
    q = np.hypot((_PX - ACX) / ARX, (_PY - ACY) / ARY)
    g = np.arctan2(_PY - ACY, _PX - ACX)
    onda = 0.5 + 0.5 * np.sin(7 * g - TAU * t / n) * np.sin(3 * g + TAU * 2 * t / n + 1.0)
    mm = (np.abs(q - 1) < esp) & (_BAY < dens * (0.45 + 0.55 * onda)) & (a[..., 3] == 0)
    a[mm, :3] = cor
    a[mm, 3] = 255


def aura_fogo_quadro(t):
    n = 6
    calor = _chamas(t, n, 1201, 19, 20.0, 5.6, 3.2)
    a = _pinta_calor(calor, AURA_FOGO, [0.78, 0.6, 0.42, 0.26, 0.12], 0.85)
    _base_anel(a, t, n, 4, AURA_FOGO[4], 0.07, 0.75)
    _fagulhas(a, t, n, 1301, 26, 26.0, [AURA_FOGO[1], AURA_FOGO[2], AURA_FOGO[3]])
    return limpar(a, faiscas=[AURA_FOGO[1], AURA_FOGO[2], AURA_FOGO[3], AURA_FOGO[4]])


def _carvoes(a, t, n, sem, qtd):
    """Pedaços de carvão aceso no chão do anel: borda vermelha, rachas claras; o brilho pulsa fora de fase."""
    rng = np.random.default_rng(sem)
    for k in range(qtd):
        phi = TAU * k / qtd + rng.uniform(-0.1, 0.1)
        bx = ACX + ARX * math.cos(phi) * rng.uniform(0.96, 1.04)
        by = ACY + ARY * math.sin(phi) * rng.uniform(0.96, 1.04) + 1
        rx, ry = rng.uniform(2.6, 4.0), rng.uniform(1.6, 2.3)
        pulso = math.sin(TAU * (t / n + rng.uniform(0, 1)))
        mm = ((_PX - bx) / rx) ** 2 + ((_PY - by) / ry) ** 2 <= 1
        racha = mm & ((np.abs(_PX - bx - 0.6 * (_PY - by)) < 0.7) | (np.abs(_PY - by + 0.3) < 0.6))
        a[mm, :3] = AURA_BRASA[3] if pulso < 0 else AURA_BRASA[2]
        a[mm, 3] = 255
        a[racha, :3] = AURA_BRASA[1] if pulso < 0.4 else AURA_BRASA[0]
        a[racha, 3] = 255


def aura_brasa_quadro(t):
    n = 6
    calor = _chamas(t, n, 2201, 22, 13.0, 3.8, 2.4)
    a = _pinta_calor(calor, AURA_BRASA, [0.8, 0.62, 0.44, 0.28, 0.14], 0.8)
    _base_anel(a, t, n, 4, AURA_BRASA[4], 0.07, 0.9)
    _carvoes(a, t, n, 2251, 18)
    _fagulhas(a, t, n, 2301, 44, 30.0, [AURA_BRASA[0], AURA_BRASA[1], AURA_BRASA[2]])
    return limpar(a, faiscas=[AURA_BRASA[0], AURA_BRASA[1], AURA_BRASA[2], AURA_BRASA[4]])


# --------------------------------------------------------------------------------------------------------------
# Catálogo
# --------------------------------------------------------------------------------------------------------------
IMP_A = dict(quadro=(20, 20), n=3, fps=20, loop=False, ancora=(10, 10))
IMP_B = dict(quadro=(56, 56), n=6, fps=15, loop=False, ancora=(28, 28))
AURA = dict(quadro=(AW, AH), n=6, fps=10, loop=True, ancora=(64, 46))

SPRITES = {
    "urso_solar": dict(voo=dict(fn=urso_solar_voo, quadro=(42, 18), n=4, fps=12, loop=True, ancora=(31, 9)),
                       impacto=dict(fn=urso_solar_impacto, **IMP_A)),
    "chuva_de_lacas": dict(voo=dict(fn=lacas_voo, quadro=(40, 12), n=4, fps=12, loop=True, ancora=(30, 6)),
                           impacto=dict(fn=lacas_impacto, **IMP_A)),
    "bola_incendiaria": dict(voo=dict(fn=bola_inc_voo, quadro=(40, 20), n=4, fps=12, loop=True, ancora=(30, 10)),
                             impacto=dict(fn=bola_inc_impacto, **IMP_B)),
    "chuva_de_ferro": dict(voo=dict(fn=ferro_voo, quadro=(28, 28), n=8, fps=16, loop=True, ancora=(14, 14),
                                    gira=True),
                           impacto=dict(fn=ferro_impacto, **IMP_A)),
    "tempestade_primordial": dict(voo=dict(fn=tempestade_voo, quadro=(72, 18), n=4, fps=12, loop=True,
                                           ancora=(54, 9)),
                                  impacto=dict(fn=tempestade_impacto, **IMP_A)),
    "anel_de_brasas": dict(voo=dict(fn=brasa_voo, quadro=(24, 24), n=8, fps=16, loop=True, ancora=(12, 12),
                                    gira=True),
                           impacto=dict(fn=brasa_impacto, **IMP_A),
                           aura=dict(fn=aura_brasa_quadro, **AURA)),
    "aura_fogo": dict(aura=dict(fn=aura_fogo_quadro, **AURA)),
}
ORDEM = ("voo", "impacto", "aura")


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
        for an in ORDEM:
            if an not in s:
                continue
            sp = s[an]
            d = {"arquivo": f"{nome}_{an}.png", "quadro": list(sp["quadro"]), "n": sp["n"], "fps": sp["fps"],
                 "loop": sp["loop"], "ancora": list(sp["ancora"])}
            if sp.get("gira"):
                d["gira"] = True
            anims[an] = d
        folhas[nome] = {"armas": [nome], "anims": anims}
    return {"_gerado_por": "jogos/hordas/fonte_arte/armas_anim/gerar_evo_projeteis.py (nao edite a mao)",
            "folhas": folhas}


def _gravar_gif(frames, durs, destino):
    pal = [f.quantize(colors=255, method=Image.Quantize.MAXCOVERAGE) for f in frames]
    pal[0].save(destino, save_all=True, append_images=pal[1:], duration=durs, loop=0, disposal=1)


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
    _gravar_gif(frames, durs, os.path.join(PREVIAS, f"{nome}.gif"))


def previa_aura(nome, quadros, sp):
    """GIF 4x da aura somada (aditiva) sobre o fundo #2a2a30, 4 voltas do loop."""
    w, h = sp["quadro"]
    fundo = np.zeros((h, w, 3), np.int32) + np.array(FUNDO_PREVIA)
    frames, durs = [], []
    for _ in range(4):
        for q in quadros:
            m = q[..., 3:4] > 0
            f = np.clip(fundo + np.where(m, q[..., :3].astype(np.int32), 0), 0, 255).astype(np.uint8)
            frames.append(Image.fromarray(f, "RGB").resize((w * 4, h * 4), Image.NEAREST))
            durs.append(round(1000 / sp["fps"]))
    _gravar_gif(frames, durs, os.path.join(PREVIAS, nome))


def conferir():
    """Verificador: tamanho da tira, quadros diferentes, alfa só 0/255, quadros vazios, âncora, borda e tons."""
    idx = json.load(open(os.path.join(SAIDA, INDICE), encoding="utf-8"))
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
            if len({hashlib.sha1(q.tobytes()).hexdigest() for q in qs}) != n:
                msg.append("quadros repetidos")
            difs = [int(((qs[i] != qs[j]).any(axis=2)).sum()) for i in range(n) for j in range(i + 1, n)]
            vazios = [i for i, q in enumerate(qs) if not q[..., 3].any()]
            if vazios:
                msg.append(f"quadros vazios {vazios}")
            ax, ay = d["ancora"]
            if not (0 <= ax < w and 0 <= ay < h):
                msg.append("ancora fora")
            sol = sum(len(isolados(q, faiscas=())) for q in qs)
            cores = len({tuple(p) for p in img[img[..., 3] > 0][:, :3].tolist()})
            emenda = ""
            if d["loop"]:
                emenda = f" emenda(ult->1o)={int(((qs[-1] != qs[0]).any(axis=2)).sum())}px"
            print(f"  {d['arquivo']:34s} {img.shape[1]:4d}x{img.shape[0]:<3d} n={n} tons={cores:2d} "
                  f"menor_dif={min(difs)}px soltos(faisca)={sol}{emenda} {'OK' if not msg else 'FALHA: ' + '; '.join(msg)}")
            if msg:
                falhas.append((d["arquivo"], msg))
    return falhas


def main():
    os.makedirs(SAIDA, exist_ok=True)
    os.makedirs(PREVIAS, exist_ok=True)
    if "--conferir" not in sys.argv:
        for nome, s in SPRITES.items():
            tiras = {}
            for an in ORDEM:
                if an not in s:
                    continue
                tira, qs = gerar_tira(s[an])
                Image.fromarray(tira, "RGBA").save(os.path.join(SAIDA, f"{nome}_{an}.png"), optimize=True)
                tiras[an] = qs
            if "voo" in tiras:
                previa(nome, tiras["voo"], tiras["impacto"], s["voo"], s["impacto"])
            if "aura" in tiras:
                previa_aura(f"{nome}.gif" if "voo" not in tiras else f"{nome}_aura.gif", tiras["aura"], s["aura"])
        with open(os.path.join(SAIDA, INDICE), "w", encoding="utf-8", newline="\n") as f:
            json.dump(indice(), f, ensure_ascii=False, indent=1)
            f.write("\n")
    falhas = conferir()
    if falhas:
        print("FALHAS:", falhas)
        sys.exit(1)
    print("tudo certo")


if __name__ == "__main__":
    main()

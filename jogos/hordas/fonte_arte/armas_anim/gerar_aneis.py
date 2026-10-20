#!/usr/bin/env python3
"""Gera as folhas animadas dos aneis de choque da v2 (grupo "aneis", pacote ARE-A).

Uma animacao por folha: `expandir`, 6 quadros, 20 fps, uma vez. O anel nasce pequeno no centro e chega a borda da
celula, afinando e esmaecendo, visto no chao (elipse achatada). Cada quadro e redesenhado (nada de escalar a imagem
parada): q1 clarao, q2-q4 o anel abre com desaceleracao e deixa rastro, q5-q6 afina, esfarela e some.

Contrato: docs/combate_v2/SPEC_ARTE.md. Fundo transparente, alfa so 0 ou 255 (esmaecer = pontilhado), cores claras
(as folhas vao para a camada aditiva). Semente fixa, sem rede.

Uso:  python -I gerar_aneis.py
Grava: jogos/hordas/projeto/assets/v2/armas_anim/<sprite>_expandir.png e indice_aneis.json
       docs/combate_v2/previas/<sprite>.gif (4x, vizinho mais proximo, fundo #2a2a30, mistura aditiva como no jogo)
"""
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[4]
SAIDA = RAIZ / "jogos/hordas/projeto/assets/v2/armas_anim"
PREVIAS = RAIZ / "docs/combate_v2/previas"
SEMENTE = 20261019
N = 6
FPS = 20
PI = math.pi
TAU = 2 * PI

# Linha do tempo comum (raio normalizado da frente: 1.0 = borda da celula). Os saltos diminuem (desaceleracao).
R = [0.16, 0.47, 0.69, 0.84, 0.94, 1.00]
ESP = [0.16, 0.16, 0.13, 0.10, 0.07, 0.05]      # espessura da frente
DENS = [1.0, 1.0, 1.0, 0.92, 0.78, 0.55]        # densidade do pontilhado da frente
TRI = [0.0, 0.22, 0.24, 0.22, 0.18, 0.12]       # comprimento do rastro atras da frente
DTRI = [0.0, 0.6, 0.5, 0.42, 0.3, 0.0]          # densidade do rastro
QUEBRA = [0.0, 0.0, 0.04, 0.16, 0.36, 0.56]     # fracao do anel que esfarela

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])


class Tela:
    """Buffer de indices de paleta (0 = vazio) de um quadro."""

    def __init__(s, W, H, q):
        s.W, s.H, s.q = W, H, q
        s.idx = np.zeros((H, W), np.uint8)
        s.faisca = np.zeros((H, W), bool)
        ys, xs = np.mgrid[0:H, 0:W]
        s.xs, s.ys = xs, ys
        s.nx = (xs + 0.5 - W / 2) / (W / 2)
        s.ny = (ys + 0.5 - H / 2) / (H / 2)
        s.d = np.hypot(s.nx, s.ny)
        s.th = np.arctan2(s.ny, s.nx)
        # pontilhado em tracos de 2x1 (nunca deixa pixel sozinho)
        s.bayer = (BAYER[ys % 4, (xs // 2) % 4] + 0.5) / 16

    def ponto(s, r, th):
        """Ponto da elipse do chao em coordenadas de pixel (indice)."""
        return (s.W / 2 + r * s.W / 2 * math.cos(th) - 0.5, s.H / 2 + r * s.H / 2 * math.sin(th) - 0.5)

    def radial(s, th):
        vx, vy = s.W * math.cos(th), s.H * math.sin(th)
        n = math.hypot(vx, vy)
        return vx / n, vy / n

    def pinta(s, mask, cor, dens=1.0, faisca=False):
        mask = np.asarray(mask, bool)
        if dens < 1.0:
            mask = mask & (s.bayer < dens)
        s.idx[mask] = cor
        s.faisca[mask] = faisca

    def _mascara(s, desenho):
        im = Image.new("L", (s.W, s.H), 0)
        desenho(ImageDraw.Draw(im))
        return np.array(im) > 0

    def poligono(s, pts, cor, dens=1.0, faisca=False):
        s.pinta(s._mascara(lambda d: d.polygon([tuple(p) for p in pts], fill=255)), cor, dens, faisca)

    def linha(s, pts, cor, dens=1.0, faisca=False):
        s.pinta(s._mascara(lambda d: d.line([tuple(p) for p in pts], fill=255, width=1)), cor, dens, faisca)

    def disco(s, cx, cy, rx, ry):
        return ((s.xs - cx) / max(rx, 0.01)) ** 2 + ((s.ys - cy) / max(ry, 0.01)) ** 2 <= 1.0

    def px(s, x, y, cor, faisca=False):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < s.W and 0 <= y < s.H:
            s.idx[y, x] = cor
            s.faisca[y, x] = faisca


# ---------------------------------------------------------------- ruido e formas basicas

def ruido(rng, amp, kmin=2, kmax=9):
    """Ruido angular suave e periodico f(th, q) em [-amp, amp]; muda de forma coerente de um quadro para o outro."""
    termos = [(k, rng.uniform(0.3, 1.0) / k ** 0.5, rng.uniform(0, TAU), rng.uniform(-0.7, 0.7))
              for k in range(kmin, kmax + 1)]
    soma = sum(a for _, a, _, _ in termos)
    return lambda th, q=0: amp * sum(a * np.sin(k * th + f + w * q) for k, a, f, w in termos) / soma


def segmentos(rng, frac, kmin=3, kmax=12):
    """Mascara angular que corta o anel em arcos: tira ~frac do contorno. Retorna f(th, rot) -> bool."""
    if frac <= 0:
        return None
    termos = [(k, rng.uniform(0.4, 1.0), rng.uniform(0, TAU)) for k in range(kmin, kmax + 1)]

    def g(th):
        return sum(a * np.sin(k * th + f) for k, a, f in termos)

    lim = float(np.quantile(g(np.linspace(-PI, PI, 1440)), frac))
    return lambda th, rot=0.0: g(th - rot) >= lim


def esfarela(rng, frac):
    """Quebra fina do anel nos ultimos quadros (muitos pedacinhos, nao buracos grandes); mesma semente = coerente."""
    s = segmentos(rng, frac, 8, 30)
    return None if s is None else (lambda th: s(th))


# estrias radiais do rastro (rastro de movimento em vez de um campo de pontilhado)
_ER = random.Random(f"{SEMENTE}:estrias")
ESTRIA_PERTO = segmentos(_ER, 0.3, 14, 44)
ESTRIA_LONGE = segmentos(_ER, 0.62, 14, 44)


def onda(t, cores, r, esp, dens=1.0, nesp=None, desloc=None, seg=None, cor_trilha=None, tri=0.0, dtri=0.0):
    """Faixa do anel: frente clara por fora, corpo e borda escura por dentro, rastro em estrias atras."""
    th = t.th
    e = esp * (1 + nesp(th)) if nesp else np.full_like(th, esp)
    e = np.maximum(e, 1e-3)
    rr = r + desloc(th) if desloc else r
    u = (rr - t.d) / e
    ok = seg(th) if seg is not None else np.ones_like(th, bool)
    if cor_trilha and tri > 0 and dtri > 0:
        z = (u > 1) & (u <= 1 + tri / e) & ok
        meio = u <= 1 + 0.4 * tri / e
        t.pinta(z & meio & ESTRIA_PERTO(th, t.q * 0.05), cor_trilha, min(1.0, dtri + 0.25))
        t.pinta(z & ~meio & ESTRIA_LONGE(th, t.q * 0.05), cor_trilha, max(dtri, 0.3))
    lims = [0.0, 0.3, 0.65, 1.0001]
    for i, c in enumerate(cores):
        t.pinta((u >= lims[i]) & (u < lims[i + 1]) & ok, c, dens)


def rastro(t, a, tri, cor, dtri, ok=True):
    """Rastro em estrias radiais por dentro do raio a (mesmo desenho do rastro de onda())."""
    if tri <= 0 or dtri <= 0:
        return
    perto = (t.d < a) & (t.d >= a - 0.4 * tri) & ok
    longe = (t.d < a - 0.4 * tri) & (t.d > a - tri) & ok
    t.pinta(perto & ESTRIA_PERTO(t.th, t.q * 0.05), cor, min(1.0, dtri + 0.25))
    t.pinta(longe & ESTRIA_LONGE(t.th, t.q * 0.05), cor, max(dtri, 0.3))


def arcos(t, r, esp, seg_g, rot, cores, dens=1.0, nesp=None):
    """Arcos que afinam nas pontas (golpe de pincel) onde o ruido seg_g passa do limite."""
    g, lim, gmax = seg_g
    v = g(t.th - rot)
    f = np.clip((v - lim) / max(gmax - lim, 1e-3) * 2.2, 0, 1)
    e = esp * f * (1 + nesp(t.th) if nesp else 1)
    u = (r - t.d) / np.maximum(e, 1e-3)
    ok = (f > 0.12) & (e > 0)
    lims = [0.0, 0.3, 0.65, 1.0001]
    for i, c in enumerate(cores):
        t.pinta((u >= lims[i]) & (u < lims[i + 1]) & ok, c, dens)


def ruido_arcos(rng, frac, kmin=3, kmax=9):
    termos = [(k, rng.uniform(0.4, 1.0), rng.uniform(0, TAU)) for k in range(kmin, kmax + 1)]

    def g(th):
        return sum(a * np.sin(k * th + f) for k, a, f in termos)

    amostra = g(np.linspace(-PI, PI, 1440))
    return g, float(np.quantile(amostra, frac)), float(amostra.max())


def clarao(t, r, cores):
    """Nucleo do 1o quadro: clarao pequeno, centro mais claro."""
    t.pinta(t.d < r, cores[2], 0.5)
    t.pinta(t.d < r * 0.78, cores[1])
    t.pinta(t.d < r * 0.42, cores[0])


def e_quebra(a, b):
    if a is None:
        return b
    if b is None:
        return a
    return lambda th: a(th) & b(th)


def pedra(t, x, y, s, claro, escuro, dens=1.0):
    """Pedrinha com a face de cima-esquerda iluminada (2x2 se pequena, losango se maior)."""
    if s <= 1:
        x, y = int(round(x)), int(round(y))
        m = np.zeros((t.H, t.W), bool)
        m[max(y, 0):max(y + 2, 0), max(x, 0):max(x + 2, 0)] = True
        t.pinta(m, escuro, dens)
        t.px(x, y, claro)
        return
    x, y = int(round(x)), int(round(y))
    t.poligono([(x - s, y - s + 1), (x - s + 1, y - s), (x + s, y - s), (x + s, y + s - 1), (x + s - 1, y + s),
                (x - s, y + s)], escuro, dens)   # bloco com cantos lascados
    t.poligono([(x - s, y + s - 1), (x - s, y - s + 1), (x - s + 1, y - s), (x + s - 1, y - s)], claro, dens)


def estrela(t, x, y, s, c1, c2, faisca=True):
    """Brilho de 4 pontas (o braco vertical um pouco mais longo)."""
    x, y = int(round(x)), int(round(y))
    for o in range(-s, s + 1):
        t.px(x + o, y, c1 if s < 3 or abs(o) <= s // 2 else c2, faisca)
    for o in range(-s - 1, s + 2):
        t.px(x, y + o, c1 if s < 3 or abs(o) <= (s + 1) // 2 else c2, faisca)
    if s >= 4:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            t.px(x + dx, y + dy, c2, faisca)


def limpa(t):
    """Sem pixel solto: o pixel sem vizinho da mesma cor vira a cor da maioria dos vizinhos (ou some)."""
    idx = t.idx
    pad = np.pad(idx, 1)
    novo = idx.copy()
    for y, x in zip(*np.nonzero(idx)):
        if t.faisca[y, x]:
            continue
        viz = np.delete(pad[y:y + 3, x:x + 3].flatten(), 4)
        if (viz == idx[y, x]).any():
            continue
        op = viz[viz > 0]
        novo[y, x] = 0 if len(op) == 0 else np.bincount(op).argmax()
    t.idx = novo


# ---------------------------------------------------------------- motivos

def m_onda_branca(t, fx, rq):
    """Onda de ar branca: frente turbulenta, raios de pressao e pedras/poeira arremessadas."""
    q = t.q
    angs = [k * TAU / 28 + fx.uniform(-0.06, 0.06) for k in range(28)]
    rochas = [(fx.uniform(0, TAU), fx.uniform(0.75, 1.3), fx.uniform(0.7, 1.3)) for _ in range(12)]
    nesp = ruido(fx, 0.35)
    qb = esfarela(fx, QUEBRA[q])
    if q == 0:
        t.pinta(t.d < 0.24, 4, 0.5)
        clarao(t, 0.17, [1, 2, 3])
        for k in range(8):
            th = k * PI / 4 + 0.3
            t.linha([t.ponto(0.12, th), t.ponto(0.34 if k % 2 == 0 else 0.25, th)], 2)
        for th, tam, sp in rochas[:5]:
            x, y = t.ponto(0.2, th)
            pedra(t, x, y - 1, 1, 5, 6)
        return
    onda(t, [1, 2, 3], R[q], ESP[q], DENS[q], nesp=lambda th: nesp(th, q), seg=qb,
         cor_trilha=4, tri=TRI[q], dtri=DTRI[q])
    comp = [0, 0.2, 0.15, 0.1, 0.06, 0.03][q]
    for i, th in enumerate(angs):
        th += rq.uniform(-0.04, 0.04)
        longo = i % 4 == 0
        L = comp * (1.7 if longo else rq.uniform(0.4, 1.0))
        r0 = R[q] - ESP[q] * (1.0 if longo else 0.5)
        r1 = min(R[q] + L, 0.995)
        if qb is not None and not qb(np.array(th)):
            continue
        t.linha([t.ponto(r0, th), t.ponto(r1, th)], 1 if longo else 2, DENS[q])
    for th, tam, sp in rochas:
        s = int(round([0, 3, 3, 2.6, 2, 1][q] * tam))
        if s < 1:
            continue
        r = R[q] + [0, 0.06, 0.08, 0.06, 0.03, -0.05][q] * sp
        x, y = t.ponto(r, th)
        pedra(t, x, y - [0, 2, 4, 4, 2, 1][q] * sp, s, 5, 6, DENS[q])


GLIFOS = [   # selos sagrados 5x5 (formas geometricas, nada que leia como letra)
    ["..1..", ".1.1.", "1.1.1", ".1.1.", "..1.."],
    [".111.", "1.1.1", "1.1.1", "1...1", ".111."],
    ["1...1", ".1.1.", "..1..", ".1.1.", "1...1"],
    ["..1..", "..1..", "11.11", "..1..", "..1.."],
]


def runa(t, glifo, x, y, cor, dens=1.0):
    x0, y0 = int(round(x)) - 2, int(round(y)) - 2
    m = np.zeros((t.H, t.W), bool)
    for j, linha in enumerate(glifo):
        for i, ch in enumerate(linha):
            if ch == "1" and 0 <= x0 + i < t.W and 0 <= y0 + j < t.H:
                m[y0 + j, x0 + i] = True
    t.pinta(m, cor, dens)


def m_dourado(t, fx, rq):
    """Luz sagrada: linha de ouro fina com halo, estrelas de 4 pontas que piscam e runas que acendem atras."""
    q = t.q
    ang_est = [-PI / 2, PI / 2, 0, PI, -PI / 4 - 0.15, -3 * PI / 4 + 0.15, PI / 4 + 0.15, 3 * PI / 4 - 0.15]
    ang_runa = [i * PI / 4 + PI / 8 + fx.uniform(-0.08, 0.08) for i in range(8)]
    nesp = ruido(fx, 0.2)
    cx, cy = t.ponto(0, 0)
    if q == 0:
        t.pinta(t.d < 0.24, 4, 0.5)
        clarao(t, 0.15, [1, 2, 3])
        for k in range(8):
            th = k * PI / 4
            t.linha([t.ponto(0.12, th), t.ponto(0.42 if k % 2 == 0 else 0.28, th)], 2 if k % 2 == 0 else 3)
        estrela(t, cx, cy, 6, 1, 2)
        return
    qb = esfarela(fx, QUEBRA[q])
    rr = R[q] - ESP[q] * 0.3
    # halo dourado (dos dois lados da linha)
    onda(t, [4, 4, 4], R[q], ESP[q] * 1.3, max(0.5 * DENS[q], 0.25), nesp=lambda th: nesp(th, q), seg=qb)
    onda(t, [1, 2, 3], rr + ESP[q] * 0.2, max(ESP[q] * 0.45, 0.035), DENS[q], seg=qb,
         cor_trilha=4, tri=TRI[q] * 0.8, dtri=DTRI[q] * 0.8)
    if q == 1:
        for k in range(12):
            th = k * PI / 6 + 0.13
            t.linha([t.ponto(0.1, th), t.ponto(0.3, th)], 4, 0.65)
    if q in (2, 3, 4):
        for i, th in enumerate(ang_runa):
            x, y = t.ponto(rr - ESP[q] - 0.08, th)
            runa(t, GLIFOS[(i + q) % len(GLIFOS)], x, y, 2 if q < 4 else 3, 1.0 if q < 4 else 0.62)
    tam_a = [0, 4, 6, 5, 3, 2][q]
    tam_b = [0, 2, 3, 4, 3, 1][q]
    for i, th in enumerate(ang_est):
        s = tam_a if i < 4 else tam_b
        if s >= 1:
            x, y = t.ponto(rr, th)
            estrela(t, x, y, s, 1, 2)
    for _ in range([0, 6, 8, 8, 6, 4][q]):
        th = rq.uniform(0, TAU)
        x, y = t.ponto(R[q] + rq.uniform(-0.25, 0.06), th)
        t.px(x, y, 2, True)
        t.px(x, y + 1, 2, True)


def cristal(t, bx, by, h, inclina, cores, dens=1.0):
    """Cristal de gelo que brota do chao: prisma com ponta, face esquerda iluminada e aresta clara."""
    if h < 2:
        return
    w = max(1.0, h * 0.28)
    tx, ty = bx + inclina * h, by - h
    my = by - h * 0.65
    ml, mr = bx - w + inclina * h * 0.65, bx + w + inclina * h * 0.65
    t.poligono([(bx - w, by), (ml, my), (tx, ty), (mr, my), (bx + w, by)], cores[2], dens)
    t.poligono([(bx - w, by), (ml, my), (tx, ty), (bx + inclina * h * 0.3, by)], cores[1], dens)
    t.linha([(ml, my), (tx, ty)], cores[0], dens)


def m_gelo(t, fx, rq):
    """Anel gelado: frente de geada e cristais que brotam onde a frente passa (os de tras ficam e se partem)."""
    q = t.q
    base = [k * TAU / 13 + fx.uniform(-0.12, 0.12) for k in range(13)]
    tams = [fx.uniform(0.7, 1.25) for _ in base]
    H_Q = [4, 6, 9, 10, 7, 4]
    nesp = ruido(fx, 0.3)
    if q == 0:
        t.pinta(t.d < 0.24, 4, 0.5)
        clarao(t, 0.16, [1, 2, 3])
        for th in (-PI / 2 - 0.4, -PI / 2 + 0.5, 0.2, PI - 0.2):
            x, y = t.ponto(0.14, th)
            cristal(t, x, y + 1, 4, 0.3 * math.cos(th), (1, 2, 3))
        return
    qb = esfarela(fx, QUEBRA[q])
    onda(t, [1, 2, 3], R[q], ESP[q], DENS[q], nesp=lambda th: nesp(th, q), seg=qb,
         cor_trilha=4, tri=TRI[q], dtri=DTRI[q])
    lista = []
    if q >= 2:   # cristais do quadro anterior, ja para tras: menores e se partindo
        for i, th in enumerate(base):
            x, y = t.ponto(R[q - 1] - ESP[q - 1] * 0.45, th)
            lista.append((y, x, H_Q[q - 1] * tams[i] * 0.55, th, (2, 3, 4), 0.5))
    for i, th in enumerate(base):
        th = th + rq.uniform(-0.05, 0.05)
        x, y = t.ponto(R[q] - ESP[q] * 0.45, th)
        lista.append((y, x, H_Q[q] * tams[i], th, (1, 2, 3), DENS[q]))
    lista.sort(key=lambda e: e[0])
    for y, x, h, th, cores, dens in lista:
        inc = 0.3 * math.cos(th)
        lado = 1 if math.cos(th) >= 0 else -1
        cristal(t, x + lado * (h * 0.3 + 1), y + 0.5, h * 0.55, inc + 0.25 * lado, cores, dens)
        cristal(t, x, y, h, inc, cores, dens)
    for _ in range([0, 3, 5, 5, 4, 3][q]):
        th = rq.uniform(0, TAU)
        x, y = t.ponto(R[q] + rq.uniform(-0.3, 0.04), th)
        x, y = int(round(x)), int(round(y))
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            t.px(x + dx, y + dy, 1 if (dx, dy) == (0, 0) else 2, True)


def m_vermelho(t, fx, rq):
    """Grito de guerra: arcos sonoros vermelhos concentricos que giram de leve e se partem ao abrir."""
    q = t.q
    gA, gB, gC = ruido_arcos(fx, 0.0), ruido_arcos(fx, 0.0), ruido_arcos(fx, 0.0)
    rot = [0, 0, 0.3, 0.55, 0.75, 0.9][q]
    nesp = ruido(fx, 0.3)

    def lim(gx, frac):   # arcos encurtam ao longo da animacao (o som se desfaz)
        g, _, gmax = gx
        return g, float(np.quantile(g(np.linspace(-PI, PI, 1440)), frac)), gmax

    if q == 0:
        t.pinta(t.d < 0.22, 4, 0.5)
        clarao(t, 0.14, [1, 2, 3])
        arcos(t, 0.28, 0.07, lim(gA, 0.3), 0.0, [2, 3, 3])
        return
    r = R[q]
    dens = [1, 1, 1, 1, 0.85, 0.62][q]
    arcos(t, r, ESP[q] * 1.05, lim(gA, [0, 0.3, 0.3, 0.36, 0.44, 0.5][q]), rot, [1, 2, 3], dens,
          nesp=lambda th: nesp(th, q))
    arcos(t, r * 0.85, ESP[q] * 0.7, lim(gB, [0, 0.42, 0.42, 0.5, 0.62, 0.76][q]), rot * 1.4 + 1.0, [2, 3, 3], dens,
          nesp=lambda th: nesp(th, q + 2))
    if q >= 2:
        arcos(t, r * 0.71, ESP[q] * 0.55, lim(gC, [0, 0, 0.5, 0.58, 0.7, 0.84][q]), rot * 1.8 + 2.0, [3, 4, 4],
              dens)
    rastro(t, r * 0.71 - ESP[q] * 0.5, TRI[q] * 0.5, 4, DTRI[q] * 0.7)


def gera_rachas(fx):
    rachas = []
    for k in range(10):
        th = k * TAU / 10 + fx.uniform(-0.2, 0.2)
        r = 0.03
        pts = [(r, th)]
        while r < 0.99:
            r = min(r + fx.uniform(0.05, 0.09), 0.99)
            th += fx.uniform(-0.13, 0.13)
            pts.append((r, th))
        rachas.append(pts)
        if len(pts) > 6 and fx.random() < 0.8:
            i = fx.randint(2, len(pts) - 4)
            rb, tb = pts[i]
            lado = fx.choice([-1, 1])
            ram = [(rb, tb)]
            for _ in range(fx.randint(3, 5)):
                rb = min(rb + fx.uniform(0.05, 0.08), 0.99)
                tb += lado * fx.uniform(0.04, 0.12)
                ram.append((rb, tb))
            rachas.append(ram)
    return rachas


def puff(t, x, y, rp, dens, cores=(1, 2, 3, 4)):
    """Bolota de poeira/nevoa com luz de cima-esquerda (cores: brilho, claro, corpo, sombra)."""
    t.pinta(t.disco(x, y, rp, rp * 0.75), cores[3], dens)
    t.pinta(t.disco(x - rp * 0.15, y - rp * 0.15, rp * 0.8, rp * 0.6), cores[2], dens)
    t.pinta(t.disco(x - rp * 0.35, y - rp * 0.35, rp * 0.45, rp * 0.35), cores[1], dens)
    if rp >= 4:
        t.pinta(t.disco(x - rp * 0.45, y - rp * 0.45, rp * 0.22, rp * 0.18), cores[0], dens)


def m_terremoto(t, fx, rq):
    """Terremoto: rachaduras incandescentes correm para fora, poeira levanta na frente e pedrinhas saltam."""
    q = t.q
    rachas = gera_rachas(fx)
    pedras = [(fx.uniform(0, TAU), fx.choice([1, 2, 2]), fx.uniform(0.7, 1.3)) for _ in range(16)]
    rmax = R[q] - 0.03 if q > 0 else 0.15
    rmin = [0, 0, 0.27, 0.4, 0.58, 0.78][q]   # a parte velha da rachadura esfria e some do centro para fora
    if q > 0:   # poeira assentando atras da frente
        rastro(t, R[q] - ESP[q] * 0.6, TRI[q], 4, DTRI[q])
    for pts in rachas:
        for (ra, ta), (rb, tb) in zip(pts, pts[1:]):
            if ra >= rmax:
                break
            if rb > rmax:
                f = (rmax - ra) / (rb - ra)
                tb, rb = ta + (tb - ta) * f, rmax
            if rb < rmin:
                continue
            if ra < rmin:
                f = (rmin - ra) / (rb - ra)
                ta, ra = ta + (tb - ta) * f, rmin
            idade = rmax - rb
            cor = 6 if idade < 0.12 and q < 5 else (5 if idade < 0.35 else 4)
            dens = 1.0 if ra >= rmin + 0.1 else 0.5
            pa, pb = t.ponto(ra, ta), t.ponto(rb, tb)
            t.linha([pa, pb], cor, dens)
            if rb < 0.42 and q <= 3:
                t.linha([(pa[0] + 1, pa[1]), (pb[0] + 1, pb[1])], 5 if cor == 6 else cor, dens)
    nP = [7, 22, 26, 28, 26, 22][q]
    rp_q = [2.5, 5, 5.2, 4.2, 3.2, 2.4][q]
    rr = R[q] - ESP[q] * 0.3 if q > 0 else 0.1
    lista = []
    for k in range(nP):
        th = k * TAU / nP + rq.uniform(-0.1, 0.1)
        x, y = t.ponto(rr, th)
        rp = rp_q * rq.uniform(0.75, 1.3)
        lista.append((y, x, rp))
    dpuff = [1.0, 1.0, 1.0, 1.0, 0.85, 0.5][q]   # a poeira encolhe antes de esfarelar
    for y, x, rp in sorted(lista):
        puff(t, x, y - rp * 0.3, rp, dpuff)
    for i, (th, s, sp) in enumerate(pedras):
        if q == 0 and i >= 4:
            break
        r = (0.18 if q == 0 else R[q] + [0, 0.06, 0.08, 0.07, 0.04, -0.03][q] * sp)
        lift = [2, 3, 5, 5, 3, 1][q] * sp
        tam = s if q in (1, 2, 3) else 1
        x, y = t.ponto(r, th)
        pedra(t, x, y - lift, tam, 7, 8, 1.0 if q < 5 else 0.62)


def raio_zz(t, rq, x, y, dx, dy, nseg, comp, cor=1, cor_ponta=2, dens=1.0):
    """Raio em zigue-zague a partir de (x, y) na direcao (dx, dy)."""
    pxd, pyd = -dy, dx
    pts = [(x, y)]
    s = rq.choice([-1, 1])
    for _ in range(nseg):
        a = rq.uniform(1.5, 3.0)
        x += dx * comp + pxd * s * a
        y += dy * comp + pyd * s * a
        s = -s
        pts.append((x, y))
    t.linha(pts[:-1], cor, dens, True)
    t.linha(pts[-2:], cor_ponta, dens, True)
    return pts


def m_eletrico(t, fx, rq):
    """Martelo do trovao: anel eletrico que treme e solta raios novos a cada quadro."""
    q = t.q
    tremor = ruido(rq, 0.025, 6, 18)    # tremor radial novo a cada quadro
    nesp = ruido(fx, 0.25)
    if q == 0:
        t.pinta(t.d < 0.24, 4, 0.5)
        clarao(t, 0.15, [1, 2, 3])
        cx, cy = t.ponto(0, 0)
        for k in range(5):
            th = k * TAU / 5 + rq.uniform(-0.3, 0.3)
            dx, dy = t.radial(th)
            raio_zz(t, rq, cx + dx * 4, cy + dy * 3, dx, dy, 3, 3)
        return
    qb = esfarela(fx, QUEBRA[q])
    onda(t, [4, 4, 4], R[q], ESP[q] * 1.25, max(0.5 * DENS[q], 0.25), nesp=lambda th: nesp(th, q),
         desloc=lambda th: tremor(th), seg=qb)
    onda(t, [1, 2, 3], R[q] - ESP[q] * 0.25, max(ESP[q] * 0.4, 0.035), DENS[q], desloc=lambda th: tremor(th),
         seg=qb, cor_trilha=4, tri=TRI[q] * 0.6, dtri=DTRI[q] * 0.6)
    nb = [0, 9, 12, 11, 8, 5][q]
    comp = [0, 5, 6, 5, 4, 3][q]
    for k in range(nb):
        th = (k + rq.uniform(0.15, 0.85)) * TAU / max(nb, 1)   # espalhados pelo anel, em lugar novo a cada quadro
        r0 = R[q] - ESP[q] * 0.25 + float(tremor(np.array(th)))
        x, y = t.ponto(r0, th)
        dx, dy = t.radial(th)
        sentido = 1 if q < 3 or rq.random() < (0.7 if q < 4 else 0.35) else -1
        pts = raio_zz(t, rq, x, y, dx * sentido, dy * sentido, rq.randint(2, 4), comp, dens=DENS[q])
        if len(pts) > 2 and rq.random() < 0.45:
            bx, by = pts[1]
            g = rq.uniform(0.5, 0.9) * rq.choice([-1, 1])
            c, s_ = math.cos(g), math.sin(g)
            raio_zz(t, rq, bx, by, (dx * c - dy * s_) * sentido, (dx * s_ + dy * c) * sentido, 2, comp - 1,
                    dens=DENS[q])
    for _ in range([0, 4, 6, 6, 4, 3][q]):
        th = rq.uniform(0, TAU)
        x, y = t.ponto(R[q] + rq.uniform(-0.12, 0.08), th)
        t.px(x, y, 2, True)
        t.px(x + 1, y, 2, True)


FOLHAS = [  # orientacao da folha que gira (a = clara, b = escura)
    [".aab", "abbb", ".bb."],
    ["..ab", ".abb", "abb.", "b..."],
    [".a.", "aab", "abb", ".b."],
    ["ba..", "bab.", ".abb", "...b"],
]


def folha(t, x, y, ori, claro, escuro, dens=1.0):
    x0, y0 = int(round(x)), int(round(y))
    for j, linha in enumerate(FOLHAS[ori]):
        for i, ch in enumerate(linha):
            if ch != "." and 0 <= x0 + i < t.W and 0 <= y0 + j < t.H and (dens >= 1 or t.bayer[y0 + j, x0 + i] < dens):
                t.idx[y0 + j, x0 + i] = claro if ch == "a" else escuro
                t.faisca[y0 + j, x0 + i] = False


def m_redemoinho(t, fx, rq):
    """Rajada de vento: bracos de vento verde em espiral que giram enquanto abrem, levando folhas."""
    q = t.q
    rot = [0, 0.9, 1.6, 2.1, 2.45, 2.65][q]
    L = [3.6, 2.2, 2.3, 2.2, 2.0, 1.8][q]
    SP = [0.14, 0.3, 0.32, 0.3, 0.27, 0.22][q]
    esp_b = [0.1, 0.16, 0.14, 0.12, 0.09, 0.065][q]
    narm = 4
    offs = [fx.uniform(-0.25, 0.25) for _ in range(narm)]
    nesp = ruido(fx, 0.25)
    folhas = [(i % narm, fx.uniform(0.1, 1.5), fx.uniform(-0.05, 0.08)) for i in range(14)]
    th, d = t.th, t.d
    dens = DENS[q]

    def braco(phi, r, esp, Lb, sp, cores, dmin):
        delta = np.mod(phi - th, TAU)
        f = delta / Lb
        r_arm = r - sp * f
        e = np.maximum(esp * (1 - 0.65 * f) * (1 + nesp(th, q)), 1e-3)
        u = (r_arm - d) / e
        m = (f <= 1) & (u >= 0) & (u <= 1)
        c = np.where(f < 0.25, np.where(u < 0.4, cores[0], cores[1]),
                     np.where(f < 0.55, np.where(u < 0.4, cores[1], cores[2]),
                              np.where(f < 0.8, cores[2], cores[3])))
        for ci in sorted(set(cores)):
            dd = dens if ci != cores[3] else max(dmin, dens * 0.55)
            t.pinta(m & (c == ci), ci, dd)

    for k in range(narm):   # fiapos finos por fora, um pouco adiantados
        braco(TAU * k / narm + rot + offs[k] + PI / narm, R[q], esp_b * 0.35, L * 0.7, SP * 0.5, (2, 3, 3, 4), 0.25)
    for k in range(narm):
        braco(TAU * k / narm + rot + offs[k], R[q] - esp_b * 0.15, esp_b, L, SP, (1, 2, 3, 4), 0.4)
    for i, (k, dl, roff) in enumerate(folhas):
        if q == 0 and i >= 3:
            break
        if q == 5 and i % 2:
            continue
        f = dl / L
        if f > 1:
            continue
        phi = TAU * k / narm + rot + offs[k]
        x, y = t.ponto(R[q] - SP * f + roff - esp_b * 0.3, phi - dl)
        folha(t, x - 1, y - 1, (i + q) % 4, 5, 6, 1.0 if q < 5 else 0.62)


def m_espinhos(t, fx, rq):
    """Anel de espinhos: cipo trancado corre no chao e espinhos brotam, crescem e recolhem."""
    q = t.q
    angs = [k * TAU / 16 + fx.uniform(-0.1, 0.1) for k in range(16)]
    tams = [fx.uniform(0.7, 1.3) for _ in angs]
    LQ = [3, 5, 8, 10, 7, 4][q]
    qb = esfarela(fx, QUEBRA[q])
    th, d = t.th, t.d
    rc = R[q] - ESP[q] * 0.5
    amp = ESP[q] * 0.35
    w = max(ESP[q] * 0.32, 0.04)
    ph = 0.5 * q
    ok = qb(th) if qb is not None else np.ones_like(th, bool)
    if q > 0:   # torroes de terra revirada atras
        rastro(t, rc - w, TRI[q] * 0.6, 3, DTRI[q] * 0.8, ok)
    for sinal, (ce, ci) in ((-1, (2, 3)), (1, (1, 2))):
        rs = rc + sinal * amp * np.sin(9 * th + ph)
        dist = d - rs
        t.pinta((np.abs(dist) <= w / 2) & (dist >= 0) & ok, ce, DENS[q])
        t.pinta((np.abs(dist) <= w / 2) & (dist < 0) & ok, ci, DENS[q])
    lista = []
    for i, a in enumerate(angs):
        a += rq.uniform(-0.03, 0.03)
        if qb is not None and not qb(np.array(a)):
            continue
        x, y = t.ponto(rc, a)
        lista.append((y, x, a, LQ * tams[i]))
    lista.sort()
    dens = DENS[q]
    for by, bx, a, L in lista:
        rx, ry = t.radial(a)
        dx, dy = rx * 0.75, ry * 0.75 - 0.65
        n = math.hypot(dx, dy)
        dx, dy = dx / n, dy / n
        bw = max(1.5, L * 0.28)
        p1 = (bx - dy * bw, by + dx * bw)
        p2 = (bx + dy * bw, by - dx * bw)
        if p2[0] + p2[1] < p1[0] + p1[1]:   # p1 = o lado de cima-esquerda (luz)
            p1, p2 = p2, p1
        tip = (bx + dx * L, by + dy * L)
        t.poligono([p1, p2, tip], 6, dens)
        t.poligono([p1, (bx, by), tip], 5, dens)
        if L >= 5:
            t.linha([(bx + dx * L * 0.65, by + dy * L * 0.65), tip], 4, dens)
    if q in (2, 3, 4):   # brotos de folha no cipo
        for k in range(10):
            a = k * TAU / 10 + 0.2 + fx.uniform(-0.1, 0.1)
            x, y = t.ponto(rc + amp, a)
            t.px(x, y - 1, 1)
            t.px(x + 1, y - 2, 1)


def lua(t, x, y, s, c1, c2, dens=1.0):
    """Crescente aberto para a direita-baixo; borda de dentro mais escura."""
    fora = t.disco(x, y, s, s)
    corte = t.disco(x + s * 0.55, y - s * 0.3, s * 0.85, s * 0.85)
    m = fora & ~corte
    borda = m & t.disco(x + s * 0.4, y - s * 0.25, s * 1.0, s * 1.0)
    t.pinta(m, c1, dens)
    t.pinta(borda, c2, dens)


def m_lunar(t, fx, rq):
    """Luar: nevoa prateada e lilas que ondula, fio de luz, crescentes que correm o anel e estrelinhas."""
    q = t.q
    ang_luas = [fx.uniform(0, TAU) + k * TAU / 4 for k in range(4)]
    nesp = ruido(fx, 0.5, 2, 11)
    if q == 0:
        t.pinta(t.d < 0.26, 4, 0.5)
        t.pinta(t.d < 0.17, 3, 0.62)
        cx, cy = t.ponto(0, 0)
        lua(t, cx, cy, 5, 1, 2)
        for th in (0.3, 2.2, 3.9, 5.3):
            x, y = t.ponto(0.3, th)
            estrela(t, x, y, 1, 1, 2)
        return
    qb = esfarela(fx, QUEBRA[q])
    onda(t, [3, 3, 4], R[q], ESP[q] * 1.1, DENS[q], nesp=lambda th: nesp(th, q), seg=qb,
         cor_trilha=4, tri=TRI[q], dtri=DTRI[q])
    # nevoa em rolos que deriva ao longo do anel
    rp_q = [0, 4.0, 4.6, 3.8, 3.0, 2.2][q]
    dpuff = [1.0, 1.0, 1.0, 1.0, 0.85, 0.5][q]
    perim = PI * (t.W / 2 + t.H / 2) * R[q]
    n = int(perim / (1.7 * rp_q))
    lista = []
    for k in range(n):
        a = k * TAU / n + 0.12 * q + rq.uniform(-0.05, 0.05)
        if qb is not None and not qb(np.array(a)):
            continue
        x, y = t.ponto(R[q] - ESP[q] * 0.45, a)
        rp = rp_q * rq.uniform(0.75, 1.25)
        lista.append((y, x, rp))
    for y, x, rp in sorted(lista):
        puff(t, x, y - rp * 0.25, rp, dpuff, (1, 2, 3, 4))
    fio = segmentos(fx, 0.35)
    onda(t, [1, 1, 1], R[q] - ESP[q] * 1.15, max(ESP[q] * 0.2, 0.03), DENS[q],
         seg=e_quebra(lambda th: fio(th, 0.4 * q), qb))
    s = [0, 4, 5, 6, 5, 4][q]
    for i, a in enumerate(ang_luas):
        if q == 5 and i % 2:
            continue
        x, y = t.ponto(R[q] - ESP[q] * 1.4 - 0.08, a + 0.35 * q)
        lua(t, x, y, s, 1, 2, 1.0 if q < 5 else 0.62)
    for _ in range([0, 4, 5, 5, 4, 3][q]):
        a = rq.uniform(0, TAU)
        x, y = t.ponto(R[q] - rq.uniform(0.08, 0.3), a)
        estrela(t, x, y, 1 if rq.random() < 0.6 else 2, 1, 2)


# ---------------------------------------------------------------- folhas

SPRITES = [
    # sprite, arma, quadro, paleta (indice 1..), motivo
    ("anel_onda_branca", "onda_choque", (128, 84),
     [(255, 255, 255), (205, 220, 240), (135, 155, 195), (120, 125, 140), (215, 205, 190), (140, 130, 120)],
     m_onda_branca),
    ("anel_dourado", "pulso_sagrado", (128, 89),
     [(255, 250, 215), (255, 212, 85), (235, 150, 30), (160, 85, 15)], m_dourado),
    ("anel_gelo", "anel_gelado", (128, 60),
     [(240, 250, 255), (170, 222, 255), (100, 165, 240), (55, 100, 200)], m_gelo),
    ("anel_vermelho", "grito_guerra", (128, 70),
     [(255, 210, 190), (255, 105, 85), (230, 35, 35), (145, 20, 25)], m_vermelho),
    ("terremoto_poeira", "terremoto", (150, 69),
     [(255, 235, 195), (225, 185, 135), (175, 130, 85), (115, 80, 50), (255, 160, 55), (255, 235, 160),
      (210, 175, 135), (140, 105, 70)], m_terremoto),
    ("anel_eletrico", "martelo_trovao", (128, 63),
     [(255, 255, 235), (255, 240, 120), (245, 190, 40), (175, 105, 20)], m_eletrico),
    ("redemoinho_verde", "rajada_vento", (128, 73),
     [(225, 255, 225), (155, 240, 165), (75, 190, 105), (40, 120, 70), (215, 250, 90), (135, 195, 40)],
     m_redemoinho),
    ("anel_espinhos_verdes", "anel_espinhos", (128, 86),
     [(210, 250, 140), (135, 210, 75), (75, 145, 50), (255, 215, 160), (250, 140, 65), (190, 85, 40)],
     m_espinhos),
    ("anel_lunar", "anel_luar", (128, 89),
     [(245, 245, 255), (200, 205, 250), (150, 140, 225), (90, 85, 175)], m_lunar),
]


def gera_quadros(nome, W, H, paleta, motivo):
    lut = np.zeros((256, 4), np.uint8)
    for i, c in enumerate(paleta, 1):
        lut[i] = (*c, 255)
    quadros = []
    for q in range(N):
        t = Tela(W, H, q)
        motivo(t, random.Random(f"{SEMENTE}:{nome}:fixo"), random.Random(f"{SEMENTE}:{nome}:{q}"))
        limpa(t)
        quadros.append(lut[t.idx])
    return quadros


def grava_previa(quadros, W, H, destino):
    """3 expansoes com pausa curta, 4x, vizinho mais proximo, sobre #2a2a30 com mistura aditiva (como no jogo)."""
    fundo = np.array([42, 42, 48], np.int32)
    imgs, dur = [], []
    for _ in range(3):
        for f in quadros:
            rgb = np.broadcast_to(fundo, (H, W, 3)).copy()
            m = f[..., 3] > 0
            rgb[m] = np.minimum(rgb[m] + f[..., :3][m].astype(np.int32), 255)
            imgs.append(Image.fromarray(rgb.astype(np.uint8)).resize((W * 4, H * 4), Image.NEAREST))
            dur.append(1000 // FPS)
        imgs.append(Image.new("RGB", (W * 4, H * 4), tuple(int(v) for v in fundo)))
        dur.append(350)
    imgs[0].save(destino, save_all=True, append_images=imgs[1:], duration=dur, loop=0, optimize=False)


def verifica(caminho, W, H, n):
    """Tamanho = n*quadro, alfa so 0/255, quadros diferentes entre si, ultimo quadro na borda, centro livre."""
    erros = []
    im = Image.open(caminho)
    if im.mode != "RGBA":
        erros.append(f"modo {im.mode}")
    a = np.array(im.convert("RGBA"))
    if im.size != (W * n, H):
        erros.append(f"tamanho {im.size} != {(W * n, H)}")
    alfas = set(np.unique(a[..., 3]).tolist())
    if not alfas <= {0, 255}:
        erros.append(f"alfa fora de 0/255: {sorted(alfas)[:6]}")
    qs = [a[:, i * W:(i + 1) * W] for i in range(n)]
    menor = 1.0
    for i in range(n):
        if not (qs[i][..., 3] > 0).any():
            erros.append(f"quadro {i + 1} vazio")
        for j in range(i + 1, n):
            dif = float((qs[i] != qs[j]).any(axis=2).mean())
            menor = min(menor, dif)
            if dif < 0.03:
                erros.append(f"quadros {i + 1} e {j + 1} quase iguais ({dif:.1%})")
    ys, xs = np.mgrid[0:H, 0:W]
    nxv, nyv = (xs + 0.5 - W / 2) / (W / 2), (ys + 0.5 - H / 2) / (H / 2)
    dn = np.hypot(nxv, nyv)
    ult = qs[-1][..., 3] > 0
    quad = (nxv >= 0).astype(int) * 2 + (nyv >= 0).astype(int)
    na_borda = sum(bool((ult & (quad == k) & (dn >= 0.95)).any()) for k in range(4))
    if na_borda < 4:
        erros.append(f"ultimo quadro chega a borda em so {na_borda} de 4 quadrantes")
    for i in range(2, n):
        if (qs[i][..., 3][dn < 0.25] > 0).any():
            erros.append(f"quadro {i + 1} com pixel no centro")
    soltos = 0
    for q in qs:
        rgba = q.astype(np.int64)
        cod = (rgba[..., 0] << 24) | (rgba[..., 1] << 16) | (rgba[..., 2] << 8) | rgba[..., 3]
        pad = np.pad(cod, 1)
        mesmo = np.zeros((H, W), bool)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx or dy:
                    mesmo |= pad[1 + dy:1 + dy + H, 1 + dx:1 + dx + W] == cod
        soltos += int(((q[..., 3] > 0) & ~mesmo).sum())
    cores = len({tuple(c) for c in a[a[..., 3] > 0][:, :3].tolist()})
    return erros, menor, soltos, cores


def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    PREVIAS.mkdir(parents=True, exist_ok=True)
    indice = {"folhas": {}}
    falhou = False
    for nome, arma, (W, H), paleta, motivo in SPRITES:
        quadros = gera_quadros(nome, W, H, paleta, motivo)
        tira = Image.fromarray(np.concatenate(quadros, axis=1), "RGBA")
        arq = f"{nome}_expandir.png"
        tira.save(SAIDA / arq)
        grava_previa(quadros, W, H, PREVIAS / f"{nome}.gif")
        indice["folhas"][nome] = {"armas": [arma], "anims": {"expandir": {
            "arquivo": arq, "quadro": [W, H], "n": N, "fps": FPS, "loop": False, "ancora": [W // 2, H // 2]}}}
        erros, menor, soltos, cores = verifica(SAIDA / arq, W, H, N)
        falhou |= bool(erros)
        print(f"{nome:22s} {W}x{H}  menor diferenca entre quadros {menor:5.1%}  cores {cores:2d}  "
              f"pixels soltos (faiscas) {soltos:3d}  {'OK' if not erros else 'ERRO: ' + '; '.join(erros)}")
    with open(SAIDA / "indice_aneis.json", "w", encoding="utf-8", newline="\n") as f:
        json.dump(indice, f, ensure_ascii=False, indent=2)
        f.write("\n")
    if falhou:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

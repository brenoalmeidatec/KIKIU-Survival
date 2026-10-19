#!/usr/bin/env python3
"""Gera as folhas animadas dos meteoros da v2 (grupo "meteoros").

Contrato: docs/combate_v2/SPEC_ARTE.md e docs/animacoes_armas_v2.md (pacote MET).
Cada sprite tem 3 tiras horizontais em jogos/hordas/projeto/assets/v2/armas_anim/:
  <sprite>_queda.png   8 quadros, 16 fps, loop (aponta para a direita, cabeça a 3/4 da largura; chama que
                       tremula, cauda que ondula, rocha/espinho que gira em 8 ângulos desenhados, brasas que ficam)
  <sprite>_impacto.png 8 quadros, 15 fps, uma vez (clarão, onda achatada, fagulhas, fumaça)
  <sprite>_marca.png   4 quadros,  8 fps, 48x32 (chão que esfria e some)
e o índice indice_meteoros.json. As prévias GIF 4x ficam em docs/combate_v2/previas/<sprite>.gif.

Tudo é desenhado pixel a pixel (numpy), com semente fixa, sem rede e sem arquivo de terceiros.
Rodar:  python -I gerar_meteoros.py
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[4]
SAIDA = RAIZ / "jogos/hordas/projeto/assets/v2/armas_anim"
PREVIAS = RAIZ / "docs/combate_v2/previas"
SEMENTE = 20261019
FUNDO_PREVIA = (0x2A, 0x2A, 0x30)


def cor(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def cores(*hs):
    return [None if h is None else cor(h) for h in hs]


# ---------------------------------------------------------------- primitivas

def novo(w, h):
    return np.zeros((h, w, 4), np.uint8)


def px(f, x, y, c):
    h, w = f.shape[:2]
    x = int(math.floor(x))
    y = int(math.floor(y))
    if 0 <= x < w and 0 <= y < h:
        f[y, x, 0:3] = c
        f[y, x, 3] = 255


def pinta(f, m, c):
    f[m, 0:3] = c
    f[m, 3] = 255


def linha(f, x0, y0, x1, y1, c):
    """Bresenham (sem antialias)."""
    x0, y0, x1, y1 = [int(math.floor(v)) for v in (x0, y0, x1, y1)]
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        px(f, x0, y0, c)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def grade(w, h):
    return np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)


def borda4(m):
    """Pixels fora da máscara com vizinho (4) dentro: o contorno de 1 px."""
    p = np.pad(m, 1)
    viz = p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return viz & ~m


def poligono(w, h, pts):
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).polygon([tuple(p) for p in pts], fill=255)
    return np.array(im) > 0


class Ruido:
    """Ruído de valor 2D, periódico em x (gx células) e em y (gy células)."""

    def __init__(self, rng, gx=64, gy=64):
        self.g = rng.random((gy, gx))
        self.gx = gx
        self.gy = gy

    def __call__(self, X, Y):
        x0 = np.floor(X).astype(int)
        y0 = np.floor(Y).astype(int)
        fx = X - x0
        fy = Y - y0
        sx = fx * fx * (3 - 2 * fx)
        sy = fy * fy * (3 - 2 * fy)
        g, gx, gy = self.g, self.gx, self.gy
        a = g[y0 % gy, x0 % gx]
        b = g[y0 % gy, (x0 + 1) % gx]
        c = g[(y0 + 1) % gy, x0 % gx]
        d = g[(y0 + 1) % gy, (x0 + 1) % gx]
        return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy


def faixas(f, calor, tons, limiares, mascara=None):
    """Quantiza um campo de calor em poucos tons (do mais quente ao mais frio)."""
    feito = np.zeros(calor.shape, bool) if mascara is None else ~mascara
    for c, lim in zip(tons, limiares):
        m = (calor > lim) & ~feito
        pinta(f, m, c)
        feito |= m


def limpa(f, passes=10):
    """Tira pixels soltos: sem vizinho (8) da mesma cor -> vira a cor do vizinho ou some."""
    h, w = f.shape[:2]
    for _ in range(passes):
        a = f[:, :, 3] > 0
        rgb = f[:, :, :3].astype(np.int64)
        k = (rgb[:, :, 0] << 16) | (rgb[:, :, 1] << 8) | rgb[:, :, 2]
        k[~a] = -1
        mudou = False
        novo_f = f.copy()
        for y in range(h):
            for x in range(w):
                kk = k[y, x]
                if kk < 0:
                    continue
                igual = False
                v4, v8 = [], []
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        yy, xx = y + dy, x + dx
                        if 0 <= yy < h and 0 <= xx < w and k[yy, xx] >= 0:
                            if k[yy, xx] == kk:
                                igual = True
                            (v4 if dx == 0 or dy == 0 else v8).append(k[yy, xx])
                if igual:
                    continue
                mudou = True
                cand = v4 or v8
                if cand:
                    esc = max(sorted(set(cand)), key=cand.count)
                    novo_f[y, x, 0:3] = ((esc >> 16) & 255, (esc >> 8) & 255, esc & 255)
                    k[y, x] = esc  # atualiza já, para dois soltos vizinhos não trocarem de cor entre si
                else:
                    novo_f[y, x] = 0
                    k[y, x] = -1
        f[:] = novo_f
        if not mudou:
            break


def ponto2(f, x, y, c, vertical=False):
    """Fagulha de 2 px (nunca fica solta)."""
    px(f, x, y, c)
    if vertical:
        px(f, x, y + 1, c)
    else:
        px(f, x + 1, y, c)


def mais(f, x, y, c, braco):
    """Brilho em cruz (estrela/cintilação)."""
    px(f, x, y, c)
    for i in range(1, braco + 1):
        px(f, x + i, y, c)
        px(f, x - i, y, c)
        px(f, x, y + i, c)
        px(f, x, y - i, c)


def zigue(f, rng, x0, y0, x1, y1, c, passo=3, desvio=1.6):
    """Raio em zigue-zague de x0,y0 até x1,y1."""
    n = max(2, int(math.hypot(x1 - x0, y1 - y0) / passo))
    nx, ny = -(y1 - y0), (x1 - x0)
    nn = math.hypot(nx, ny) or 1
    nx, ny = nx / nn, ny / nn
    pts = [(x0, y0)]
    for i in range(1, n):
        s = i / n
        j = rng.uniform(-desvio, desvio)
        pts.append((x0 + (x1 - x0) * s + nx * j, y0 + (y1 - y0) * s + ny * j))
    pts.append((x1, y1))
    for (a, b), (c2, d) in zip(pts, pts[1:]):
        linha(f, a, b, c2, d, c)
    return pts


# ---------------------------------------------------------------- queda: rastro

LUZ = np.array([-0.55, -0.62, 0.56])
LUZ = LUZ / np.linalg.norm(LUZ)
NQ = 8          # quadros da queda (loop: o último emenda no primeiro)
FPS_QUEDA = 16


def campo_rastro(w, h, ax, ay, r, L, t, rz, larg=1.15, afina=0.8, pot=1.0, ganho=1.25, ruido=0.42, esc=1.0,
                 onda=0.0, ciclos=1.0, pulso=0.0, tremor=0.0):
    """Calor do rastro atrás da cabeça. O ruído corre para a esquerda e fecha o ciclo em NQ quadros.
    onda: amplitude (px) de um seno que anda pela cauda; pulso: o núcleo perto da cabeça esquenta e esfria;
    tremor: a largura da chama tremula (línguas que mudam de forma a cada quadro)."""
    X, Y = grade(w, h)
    cx, cy = ax + 0.5, ay + 0.5
    u = (cx - X) / L
    uc = np.clip(u, 0, 1)
    ph = 2 * math.pi * t / NQ
    if onda:
        cy = cy + onda * uc ** 1.1 * np.sin(2 * math.pi * ciclos * uc - ph)
    hw = larg * r * (1 - uc) ** afina + 0.7
    if tremor:
        ct = 2.5 * esc
        tl = rz[0]((X + ct * t * 4.0 / NQ) / ct, (Y - cy) / (1.6 * esc) + 30 + 1.2 * math.sin(ph))
        hw = hw * (1 + tremor * (tl - 0.5) * (0.4 + uc))
    v = (Y - cy) / hw
    base = (1 - uc) ** pot * np.clip(1 - v * v, 0, None)
    frente = np.clip((cx + r * 0.5 - X) / (r * 0.5 + 1), 0, 1)
    base = base * frente * (u < 1.02)
    c1, c2 = 6 * esc, 3.5 * esc
    passo = 4.0 / NQ   # o ruído tem 4 células de período em x: anda 4 células em NQ quadros
    n = (0.5 * (rz[0]((X + c1 * t * passo) / c1, (Y - cy) / (3 * esc)) - 0.5)
         + 0.35 * (rz[1]((X + c2 * t * passo) / c2, (Y - cy) / (2 * esc)) - 0.5)
         + 0.30 * (rz[2]((X + 3 * esc * math.cos(ph)) / (4 * esc) + 7, (Y - cy + 3 * esc * math.sin(ph)) / (2.5 * esc) + 7) - 0.5))
    amp = ruido * (0.45 + uc)
    calor = base * ganho + n * amp * 2
    if pulso:
        calor = calor + pulso * math.sin(ph) * (1 - uc) ** 3 * (base > 0)
    calor[base <= 0.0] = -1
    return calor


def brasas(f, rng_seed, ax, ay, r, L, t, tons, n=6, vel=(3, 5), vertical=False, cristal=None):
    """Brasas que se soltam da cauda, ficam para trás e esfriam; posição depende da idade (ciclo de NQ).
    cristal: cor de um brilho em cruz que algumas fazem no começo da vida (gelo, estrela)."""
    rg = np.random.default_rng(rng_seed)
    for i in range(n):
        u0 = rg.uniform(0.25, 0.7)
        lado = rg.choice([-1, 1])
        y0 = ay + lado * rg.uniform(0.4, 1.0) * r * (1 - u0) ** 0.8
        vx = rg.uniform(*vel) * 0.6
        vy = lado * rg.uniform(0.15, 0.55)
        fase = rg.uniform(0, NQ)
        idade = (t - fase) % NQ
        x = ax - u0 * L - idade * vx
        y = y0 + idade * vy
        c = tons[min(len(tons) - 1, int(idade * len(tons) / NQ))]
        if x < 0:
            continue
        if cristal is not None and i % 3 == 0 and idade < NQ * 0.4:
            mais(f, x, y, cristal if idade < NQ * 0.2 else c, 1)
        else:
            ponto2(f, x, y, c, vertical)


# ---------------------------------------------------------------- queda: cabeças

def esfera(w, h, cx, cy, raio_fn):
    X, Y = grade(w, h)
    dx = X - (cx + 0.5)
    dy = Y - (cy + 0.5)
    d = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    R = raio_fn(th)
    dentro = d <= R
    q = np.clip(d / R, 0, 1)
    nz = np.sqrt(np.clip(1 - q * q, 0, 1))
    lam = (dx / R) * LUZ[0] + (dy / R) * LUZ[1] + nz * LUZ[2]
    return dentro, dx, dy, d, th, R, lam


def gira3d(t, eixo=(0.32, 1.0, 0.38), voltas=1.0):
    """Matriz de rotação (Rodrigues) do quadro t: `voltas` voltas inteiras em NQ quadros em torno de `eixo`."""
    k = np.array(eixo, float)
    k /= np.linalg.norm(k)
    a = 2 * math.pi * voltas * t / NQ
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + math.sin(a) * K + (1 - math.cos(a)) * K @ K


def _poliedro(forma, k):
    """Rocha = interseção de k semiespaços (faces planas) com normais quase uniformes e alturas irregulares."""
    rg = np.random.default_rng(9100 + forma)
    i = np.arange(k) + 0.5
    fi = np.arccos(1 - 2 * i / k)
    th = math.pi * (1 + 5 ** 0.5) * i
    n = np.stack([np.cos(th) * np.sin(fi), np.sin(th) * np.sin(fi), np.cos(fi)], 1) + rg.normal(0, 0.12, (k, 3))
    n /= np.linalg.norm(n, axis=1, keepdims=True)
    d = rg.uniform(0.9, 1.03, k)
    furos = rg.normal(size=(2, 3))
    furos /= np.linalg.norm(furos, axis=1, keepdims=True)
    return n, d, furos


def cabeca_rocha(f, cx, cy, r, t, p, crateras=True, veios=None, forma=0, veios2=None, voltas=1.0):
    """Rocha facetada que capota de verdade: um poliedro 3D gira uma volta em NQ quadros e cada quadro é redesenhado
    (silhueta, faces e arestas) com a luz fixa de cima-esquerda. veios: arestas em brasa no lado da sombra
    (veios2: a cor delas nos quadros em que o núcleo pulsa)."""
    h, w = f.shape[:2]
    nf = 14 if r >= 5 else 12
    n0, d, furos = _poliedro(forma, nf)
    R = gira3d(t + forma * 0.37, voltas=voltas)
    N = n0 @ R.T
    X, Y = grade(w, h)
    re = r * 0.92                       # o poliedro passa um pouco do raio nas quinas: volta ao tamanho da rocha antiga
    sx = (X - (cx + 0.5)) / re
    sy = (Y - (cy + 0.5)) / re
    sup = np.full(sx.shape, np.inf)
    sup2 = np.full(sx.shape, np.inf)
    inf_ = np.full(sx.shape, -np.inf)
    face = np.zeros(sx.shape, int)
    ok = np.ones(sx.shape, bool)
    for j in range(nf):
        a = N[j, 2]
        b = d[j] - N[j, 0] * sx - N[j, 1] * sy
        if a > 1e-3:
            z = b / a
            menor = z < sup
            sup2 = np.where(menor, sup, np.minimum(sup2, z))
            face = np.where(menor, j, face)
            sup = np.minimum(sup, z)
        elif a < -1e-3:
            inf_ = np.maximum(inf_, b / a)
        else:
            ok &= b >= 0
    dentro = ok & (inf_ <= sup) & np.isfinite(sup)
    lam = N[:, 0] * LUZ[0] + N[:, 1] * LUZ[1] + N[:, 2] * LUZ[2]
    tom_face = np.digitize(lam, [0.12, 0.48, 0.8])
    tom = tom_face[face]
    # aresta entre duas faces da frente: a mais escura das duas ganha um risco de sombra (as arestas aparecem)
    aresta = dentro & ((sup2 - sup) * re < 0.42)
    if crateras and r >= 5:
        for fu in furos @ R.T:
            if fu[2] < 0.3:
                continue
            qx, qy = fu[0] * r * 0.62, fu[1] * r * 0.62
            s = 1.25 * fu[2] ** 0.5
            dx, dy = X - (cx + 0.5), Y - (cy + 0.5)
            dd = np.hypot(dx - qx, dy - qy)
            m = (dd <= s) & dentro
            tom[m] = np.maximum(tom[m] - 1, 0)
            rim = (np.hypot(dx - qx - 0.9, dy - qy - 0.9) <= s) & ~m & dentro & (dd <= s + 1.0)
            tom[rim] = np.minimum(tom[rim] + 1, 2)
    tom = np.where(aresta & (tom >= 2), tom - 1, tom)
    paleta = [p["esc"], p["med"], p["clr"], p["bri"]]
    for i, c in enumerate(paleta):
        pinta(f, dentro & (tom == i), c)
    if veios:
        cv = veios2 if (veios2 is not None and (t // 2) % 2 == 1) else veios
        pinta(f, aresta & (lam[face] < 0.5), cv)
    pinta(f, borda4(dentro), p["cont"])
    return dentro


def cabeca_cristal(f, cx, cy, r, t, p):
    """Núcleo de gelo hexagonal que gira 60°/NQ por quadro (fecha em 60°)."""
    h, w = f.shape[:2]
    rot = t * (math.pi / 3) / NQ
    pts = [(cx + 0.5 + math.cos(rot + i * math.pi / 3) * r, cy + 0.5 + math.sin(rot + i * math.pi / 3) * r) for i in range(6)]
    dentro = poligono(w, h, pts)
    X, Y = grade(w, h)
    dx = X - (cx + 0.5)
    dy = Y - (cy + 0.5)
    th = np.arctan2(dy, dx)
    # faceta = setor do hexágono; normal da faceta inclinada 45°
    setor = np.floor(((th - rot) % (2 * math.pi)) / (math.pi / 3))
    fa = rot + (setor + 0.5) * math.pi / 3
    d = np.hypot(dx, dy)
    nucleo = d < r * 0.45
    lam = np.where(nucleo, LUZ[2], np.cos(fa) * 0.7 * LUZ[0] + np.sin(fa) * 0.7 * LUZ[1] + 0.7 * LUZ[2])
    tons = [p["esc"], p["med"], p["clr"], p["bri"]]
    idx = np.digitize(lam, [0.2, 0.55, 0.85])
    for i, c in enumerate(tons):
        pinta(f, dentro & (idx == i), c)
    # brilho fixo em cima-esquerda
    hx, hy = int(cx - r * 0.35), int(cy - r * 0.35)
    for (a, b) in ((0, 0), (1, 0), (0, 1)):
        if dentro[hy + b, hx + a]:
            px(f, hx + a, hy + b, p["bri"])
    pinta(f, borda4(dentro), p["cont"])
    return dentro


def cabeca_vazio(f, cx, cy, r, t, p, rz):
    """Esfera de vazio: miolo escuro, aro de energia rosa na frente que tremula, reflexo fixo."""
    h, w = f.shape[:2]
    dentro, dx, dy, d, th, R, lam = esfera(w, h, cx, cy, lambda th: r + 0 * th)
    q = d / r
    ph = 2 * math.pi * t / NQ
    tremor = rz((np.cos(th) * 2 + math.cos(ph) * 1.5) + 5, (np.sin(th) * 2 + math.sin(ph) * 1.5) + 5)
    frente = np.cos(th)  # 1 na frente (direita)
    # aro em crescente na frente (direita/baixo), mais grosso no meio, tremulando a cada quadro
    lado = np.cos(th - 0.35)
    esp = np.clip(lado, 0, 1) * 0.26 + 0.1 * (tremor - 0.5)
    pinta(f, dentro, p["miolo"])
    pinta(f, dentro & (q > 0.6), p["sombra"])
    pinta(f, dentro & (q > 1 - esp - 0.13) & (lado > -0.1), p["aro2"])
    pinta(f, dentro & (q > 1 - esp) & (lado > 0.15), p["aro"])
    # reflexo fixo (cima-esquerda)
    hx, hy = int(cx - r * 0.42), int(cy - r * 0.5)
    for (a, b) in ((0, 0), (1, 0), (2, 0), (0, 1), (1, 1)):
        px(f, hx + a, hy + b, p["reflexo"])
    pinta(f, borda4(dentro) & ((f[:, :, 3] == 0) | (np.cos(th) > 0)), p["cont"])
    return dentro


def cabeca_estrela(f, cx, cy, r, t, p):
    """Estrela de 4 pontas que cintila: pontas compridas e diagonais crescem e encolhem se revezando, e um brilho
    em cruz pulsa por cima (ciclo de NQ)."""
    h, w = f.shape[:2]
    ph = 2 * math.pi * t / NQ
    longo = 0.82 + 0.2 * math.cos(ph)
    diag = 0.52 - 0.2 * math.cos(ph)
    rot = 0.13 * math.sin(ph)
    # brilho em cruz: braços finos que crescem e somem, atrás do corpo da estrela
    cruz = int(round(r * (0.75 + 0.55 * math.cos(ph + 0.8))))
    if cruz > 0:
        cc = p["miolo"] if math.cos(ph + 0.8) > 0.2 else p["corpo"]
        alto = min(h // 2 - 1, 2 + cruz)
        larg = min(w - cx - 2, 4 + cruz)
        linha(f, cx, cy - alto, cx, cy + alto, cc)
        linha(f, cx, cy, cx + larg, cy, cc)
    pts = []
    for i in range(8):
        a = rot + i * math.pi / 4
        if i % 2 == 0:
            rr = r * longo * (1.25 if i in (0, 4) else 1.0)
        else:
            rr = r * diag
        pts.append((cx + 0.5 + math.cos(a) * rr, cy + 0.5 + math.sin(a) * rr))
        a2 = a + math.pi / 8
        pts.append((cx + 0.5 + math.cos(a2) * r * 0.32, cy + 0.5 + math.sin(a2) * r * 0.32))
    dentro = poligono(w, h, pts)
    X, Y = grade(w, h)
    dx = X - (cx + 0.5)
    dy = Y - (cy + 0.5)
    d = np.hypot(dx, dy)
    pinta(f, dentro, p["borda"])
    pinta(f, dentro & (d < r * 0.62) & (dx + dy < r * 0.5), p["corpo"])
    pinta(f, dentro & (d < r * 0.42), p["corpo"])
    pinta(f, dentro & (d < r * 0.27) | (dentro & (np.hypot(dx + 0.7, dy + 0.7) < r * 0.3)), p["miolo"])
    pinta(f, borda4(dentro) & ((f[:, :, 3] == 0) | (dx > -r * 0.2)), p["cont"])
    return dentro


def cabeca_fogo(f, cx, cy, r, t, p, rz):
    """Bola de fogo celeste: núcleo claro que pulsa (claro/escuro) e borda que borbulha a cada quadro."""
    h, w = f.shape[:2]
    ph = 2 * math.pi * t / NQ

    def raio(th):
        return r + 0.4 * math.sin(ph) + 1.1 * (rz(np.cos(th) * 1.8 + math.cos(ph) * 1.2 + 3, np.sin(th) * 1.8 + math.sin(ph) * 1.2 + 3) - 0.5)

    dentro, dx, dy, d, th, R, lam = esfera(w, h, cx, cy, raio)
    q = d / R
    tm = rz(dx / 2.2 + math.cos(ph) * 1.3 + 11, dy / 2.2 + math.sin(ph) * 1.3 + 11)
    calor = (1 - q) * 1.1 + (lam - 0.3) * 0.5 + (tm - 0.5) * 0.45 + 0.17 * math.sin(ph)
    tons = [p["branco"], p["claro"], p["medio"], p["borda"]]
    # atrás (lado do rastro) só entram os tons claros: a bola se funde com a chama, sem costura
    dentro = dentro & ((dx > -r * 0.15) | (calor > 0.5) | (f[:, :, 3] == 0))
    faixas(f, calor, tons, [0.78, 0.5, 0.25, -9], dentro)
    pinta(f, borda4(dentro) & (f[:, :, 3] == 0), p["cont"])
    return dentro


def cabeca_orbe(f, cx, cy, r, t, p, rz, rng):
    """Orbe elétrico: núcleo branco-azul, faixas de plasma que mudam, arcos que pulam em volta."""
    h, w = f.shape[:2]
    ph = 2 * math.pi * t / NQ
    dentro, dx, dy, d, th, R, lam = esfera(w, h, cx, cy, lambda th: r + 0 * th)
    q = d / r
    tm = rz(dx / 2.0 + math.cos(ph) * 1.6 + 4, dy / 2.0 + math.sin(ph) * 1.6 + 4)
    calor = (1 - q) * 0.9 + (lam - 0.3) * 0.55 + (tm - 0.5) * 0.6 + 0.12 * math.sin(2 * ph)
    faixas(f, calor, [p["branco"], p["claro"], p["medio"], p["escuro"]], [0.75, 0.48, 0.22, -9], dentro)
    pinta(f, borda4(dentro) & (f[:, :, 3] == 0), p["cont"])
    # arcos elétricos em volta da cabeça (novos a cada quadro): um que abraça a esfera e dois que pulam para fora
    a0 = rng.uniform(-math.pi, math.pi)
    a1 = a0 + rng.choice([-1, 1]) * rng.uniform(1.2, 1.9)
    pts = [(cx + 0.5 + math.cos(a0 + (a1 - a0) * s) * (r + 1.6 + rng.uniform(-0.6, 0.9)),
            cy + 0.5 + math.sin(a0 + (a1 - a0) * s) * (r + 1.6 + rng.uniform(-0.6, 0.9))) for s in np.linspace(0, 1, 6)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        linha(f, x0, y0, x1, y1, p["arco"])
    for k in range(2):
        a0 = rng.uniform(-2.4, 2.4)
        a1 = a0 + rng.choice([-1, 1]) * rng.uniform(0.5, 1.0)
        r0, r1 = r + 1.5, r + rng.uniform(2.8, 4.5)
        c_arco = p["arco"] if k == 0 else p["branco"]
        pts = zigue(f, rng, cx + 0.5 + math.cos(a0) * r0, cy + 0.5 + math.sin(a0) * r0,
                    cx + 0.5 + math.cos(a1) * r1, cy + 0.5 + math.sin(a1) * r1, c_arco, passo=2, desvio=1.1)
        if k == 0 and len(pts) > 2:   # galho curto
            bx, by = pts[1]
            zigue(f, rng, bx, by, bx + rng.uniform(-3, 3), by + rng.uniform(-3, 3), p["claro"], passo=2, desvio=0.8)
    return dentro


def cabeca_espinho(f, cx, cy, t, p):
    """Espinho vegetal apontando para a direita que gira no próprio eixo: três farpas (a 120°) e um sulco dão a volta
    em NQ quadros; a que passa por trás fica escura e atrás do corpo, a da frente clara e por cima. Luz fixa de cima."""
    h, w = f.shape[:2]
    ey = cy + 0.5                       # eixo do espinho
    x0, x1 = 0.6, cx + 2.95             # base e ponta
    fi = 2 * math.pi * t / NQ

    def meia(x):
        s = np.clip((x - x0) / (x1 - x0), 0, 1)
        return 2.3 * (1 - s) ** 0.85 + 0.25

    X, Y = grade(w, h)
    corpo = (X >= x0) & (X <= x1) & (np.abs(Y - ey) <= meia(X))
    farpas_tras, farpas_frente = [], []
    for k in range(3):
        a = fi + k * 2 * math.pi / 3
        bx = [3.2, 4.6, 2.0][k]
        s, c = math.sin(a), math.cos(a)
        hb = float(meia(np.array(bx + 0.5)))
        y_base = ey + s * hb
        tri = [(bx - 0.2, y_base), (bx + 1.4, y_base), (bx - 1.0, ey + s * (hb + 2.0))]
        m = poligono(w, h, tri) if abs(s) > 0.3 else np.zeros((h, w), bool)
        (farpas_frente if c >= 0 else farpas_tras).append((m, a))
    tras = np.zeros((h, w), bool)
    for m, _ in farpas_tras:
        tras |= m
    pinta(f, tras & ~corpo, p["esc"])
    pinta(f, corpo, p["med"])
    pinta(f, corpo & (Y < ey - 0.6), p["clr"])
    pinta(f, corpo & (Y > ey + 1.0), p["esc"])
    # sulco em espiral: uma linha escura que rola pelo corpo (só a parte virada para a frente)
    for k in (0, 1):
        b = fi * 1.0 + k * math.pi + 0.4
        if math.cos(b) < 0.15:
            continue
        for xi in range(int(x0), int(x1)):
            hm = float(meia(np.array(xi + 0.5)))
            yy = ey + math.sin(b + (xi - x0) * 0.35) * hm * 0.8
            if corpo[int(yy), xi] if 0 <= int(yy) < h else False:
                px(f, xi, yy, p["esc"] if yy < ey else p["cont"])
    frente = np.zeros((h, w), bool)
    for m, a in farpas_frente:
        mm = m & ~corpo
        pinta(f, mm, p["clr"] if math.sin(a) < 0 else p["med"])
        frente |= m
    # farpa de frente apontando para quem olha: ponto claro no corpo
    for k in range(3):
        a = fi + k * 2 * math.pi / 3
        if math.cos(a) > 0.9:
            bx = [3.2, 4.6, 2.0][k]
            px(f, bx, ey - 0.5, p["clr"])
            px(f, bx + 1, ey - 0.5, p["clr"])
    dentro = corpo | tras | frente
    pinta(f, borda4(dentro), p["cont"])
    return dentro


# ---------------------------------------------------------------- impacto

def impacto(cfg, S, semente):
    rg = np.random.default_rng(semente)
    rzf = Ruido(rg)
    rzs = Ruido(rg)
    rza = Ruido(rg, 16, 16)
    k = S / 72.0
    cx = cy = S // 2
    X, Y = grade(S, S)
    dx = X - (cx + 0.5)
    dy = Y - (cy + 0.5)
    th = np.arctan2(dy, dx)

    faisc = []
    for i in range(cfg.get("n_faiscas", 14)):
        faisc.append(dict(a=rg.uniform(0, 2 * math.pi), s=rg.uniform(0.06, 0.12) * S, vz=rg.uniform(0.04, 0.1) * S,
                          t0=rg.uniform(0.4, 1.1), g=0.03 * S))
    pedacos = []
    for i in range(cfg.get("n_pedacos", 0)):
        pedacos.append(dict(a=rg.uniform(0, 2 * math.pi), s=rg.uniform(0.04, 0.085) * S, vz=rg.uniform(0.05, 0.09) * S,
                            t0=rg.uniform(0.6, 1.0), g=0.032 * S, tam=2 if rg.random() < 0.6 or S < 60 else 3,
                            c=rg.integers(0, 2)))
    fumacas = []
    for i in range(cfg.get("n_fumaca", 7)):
        a = rg.uniform(0, 2 * math.pi)
        fumacas.append(dict(x=math.cos(a) * rg.uniform(0.04, 0.26) * S, y=math.sin(a) * rg.uniform(0.04, 0.26) * S * 0.55,
                            nasc=rg.choice([2, 2, 3, 3, 4]), r0=rg.uniform(0.06, 0.09) * S, ox=rg.uniform(0, 40), oy=rg.uniform(0, 40)))
    cristais = []
    for i in range(cfg.get("n_cristais", 0)):
        a = (i + rg.uniform(-0.25, 0.25)) * 2 * math.pi / cfg["n_cristais"]
        cristais.append(dict(a=a, rho=rg.uniform(0.07, 0.2) * S, alt=rg.uniform(0.16, 0.26) * S, larg=rg.uniform(1.6, 2.4) * max(1, k * 1.2)))
    if cristais:
        for c in cristais:  # cada cristal estilhaça em lascas no quadro 5
            for j in range(3):
                faisc.append(dict(a=c["a"] + rg.uniform(-0.6, 0.6), s=rg.uniform(0.05, 0.1) * S, vz=rg.uniform(0.04, 0.08) * S,
                                  t0=4.5, g=0.03 * S, x0=math.cos(c["a"]) * c["rho"], y0=math.sin(c["a"]) * c["rho"],
                                  z0=c["alt"] * 0.5))

    def pos(sp, tau):
        kd = 0.25
        dist = sp["s"] * (1 - math.exp(-kd * tau)) / kd
        z = sp.get("z0", 0) + sp["vz"] * tau - 0.5 * sp["g"] * tau * tau
        gx = sp.get("x0", 0) + math.cos(sp["a"]) * dist
        gy = sp.get("y0", 0) + math.sin(sp["a"]) * dist
        return gx, gy, z

    def tela(gx, gy, z):
        return cx + 0.5 + gx, cy + 0.5 + gy * 0.55 - z

    quadros = []
    for t in range(8):
        f = novo(S, S)
        # 1) onda de choque achatada no chão
        rx = S * 0.47 * [0, 0.3, 0.52, 0.7, 0.84, 0.94, 1.0, 0][t]
        esp = max(1, round([0, 3, 3, 2.4, 2, 1.4, 1, 0][t] * max(k, 0.7)))
        if rx > 0:
            ry = rx * 0.55
            e_out = (dx / rx) ** 2 + (dy / ry) ** 2 <= 1
            e_in = (dx / max(rx - esp, 0.5)) ** 2 + (dy / max(ry - esp * 0.75, 0.5)) ** 2 <= 1
            anel = e_out & ~e_in
            lacuna = [0, 0, 0, 0.05, 0.18, 0.38, 0.62, 1][t]
            buraco = rza(np.cos(th) * 3 + 8 + t * 0.7, np.sin(th) * 3 + 8) < lacuna
            anel &= ~buraco
            c_anel = cfg["anel"][[0, 0, 0, 1, 1, 2, 2, 2][t]]
            pinta(f, anel, c_anel)
            if cfg.get("poeira_chao") and t >= 2:
                # poeira rasteira logo atrás da onda
                rr2 = rx - esp - 1
                if rr2 > 2:
                    e2 = (dx / rr2) ** 2 + (dy / (rr2 * 0.55)) ** 2
                    n = rzs(X / 2.5 + t, Y / 2.0)
                    m = (e2 <= 1) & (e2 > 0.62 + 0.1 * t / 7) & (n > 0.38 + 0.07 * t) & ~anel
                    pinta(f, m, cfg["fumaca"][1])
        # 2) fumaça que sobe e se desfaz
        for fm in fumacas:
            idade = t - fm["nasc"]
            if idade < 0:
                continue
            vida = 8 - fm["nasc"]
            r = fm["r0"] + 0.022 * S * idade
            fx, fy = tela(fm["x"], fm["y"], 0)
            fy -= (0.035 * S) * idade + 0.05 * S
            ddx, ddy = X - fx, Y - fy
            d = np.hypot(ddx, ddy * 1.1)
            n = rzs(X / (3.4 * max(k, 0.75)) + fm["ox"] + idade * 0.4, Y / (3.4 * max(k, 0.75)) + fm["oy"])
            lim = (idade / vida) ** 1.15
            vis = (1 - d / r) + (0.3 + 0.35 * idade / vida) * (n - 0.5) > lim * 0.95 + 0.04
            sh = (-ddx * 0.6 - ddy * 0.8) / r
            fc = cfg["fumaca"]
            pinta(f, vis & (sh <= -0.25), fc[2])
            pinta(f, vis & (sh > -0.25) & (sh <= 0.3), fc[1])
            pinta(f, vis & (sh > 0.3), fc[0])
        # 3) pedaços (pesados) e fagulhas: atrás da bola de fogo enquanto estão dentro dela
        for pd in pedacos:
            tau = t - pd["t0"]
            if tau <= 0:
                continue
            tl = 2 * pd["vz"] / pd["g"]
            if tau > tl:
                if t >= 7:
                    continue
                tau = tl
            gx, gy, z = pos(pd, tau)
            sx, sy = tela(gx, gy, max(z, 0))
            c = cfg["pedaco"][pd["c"]]
            for a in range(pd["tam"]):
                for b in range(pd["tam"]):
                    px(f, sx + a - 1, sy + b - 1, c)
        cf = cfg["faisca"]
        tipo = cfg.get("tipo_faisca", "risco")
        base_f, f = f, novo(S, S)  # fagulhas numa camada à parte, aplicada depois do fogo
        for sp in faisc:
            tau = t - sp["t0"]
            if tau <= 0:
                continue
            tl = (sp["vz"] + math.sqrt(sp["vz"] ** 2 + 2 * sp["g"] * sp.get("z0", 0))) / sp["g"]
            idade_c = cf[min(len(cf) - 1, int(tau / 1.3))]
            if tau > tl:
                ch = tau - tl
                if ch > 1.6:
                    continue
                gx, gy, z = pos(sp, tl)
                sx, sy = tela(gx, gy, 0)
                ponto2(f, sx, sy, cf[min(len(cf) - 1, 2 + int(ch))])
                continue
            gx, gy, z = pos(sp, tau)
            sx, sy = tela(gx, gy, z)
            if tipo == "brilho":
                braco = 2 if tau < 1.5 else 1
                mais(f, sx, sy, idade_c, braco)
            elif tipo == "folha":
                ponto2(f, sx, sy, idade_c, vertical=(t + int(sp["a"] * 3)) % 2 == 0)
            else:
                g0 = pos(sp, max(0.0, tau - 0.5))
                x0, y0 = tela(*g0)
                if math.hypot(sx - x0, sy - y0) < 1.5:
                    ponto2(f, sx, sy, idade_c)
                else:
                    linha(f, x0, y0, sx, sy, idade_c)
        camada_faiscas, f = f, base_f
        nucleo = np.zeros((S, S), bool)
        # 4) clarão que vira bola de fogo / poeira
        Rf = S * [0.2, 0.27, 0.28, 0.25, 0.19, 0.11, 0, 0][t] * cfg.get("bola", 1.0)
        if Rf > 0:
            sobe = S * [0, 0.01, 0.04, 0.07, 0.11, 0.14, 0, 0][t]
            dn = np.hypot(dx, (dy + sobe) / [0.75, 0.82, 0.85, 0.88, 0.9, 0.9][t]) / Rf
            I = [1.9, 1.3, 0.98, 0.76, 0.58, 0.44][t] * cfg.get("forca", 1.0)
            amp = [0.05, 0.16, 0.26, 0.3, 0.3, 0.28][t]
            esc_r = 4.5 * max(k, 0.75)
            n = rzf(X / esc_r + t * 1.7, Y / esc_r - t * 0.9)
            calor = I * (1 - dn) + amp * (n - 0.5) * 2
            calor[dn > 1.3] = -1
            faixas(f, calor, cfg["fogo"], [0.9, 0.62, 0.42, 0.26, 0.13])
            nucleo = calor > 0.62
            if t == 0 and cfg.get("clarao", True):
                # clarão rente ao chão: risco branco horizontal e um curto na vertical
                lx = Rf * 1.9
                linha(f, cx + 0.5 - lx, cy, cx + 0.5 + lx, cy, cfg["fogo"][0])
                linha(f, cx + 0.5 - lx * 0.7, cy + 1, cx + 0.5 + lx * 0.7, cy + 1, cfg["fogo"][0])
                linha(f, cx, cy + 0.5 - Rf * 1.25, cx, cy + 0.5 + Rf * 1.0, cfg["fogo"][0])
                linha(f, cx + 1, cy + 0.5 - Rf * 1.0, cx + 1, cy + 0.5 + Rf * 0.8, cfg["fogo"][0])
            if cfg.get("vazio") and 2 <= t <= 4:
                rv = Rf * [0, 0, 0.45, 0.55, 0.45][t]
                dv = np.hypot(dx, (dy + sobe) / 0.85)
                pinta(f, dv < rv + 1, cfg["vazio"][1])
                pinta(f, dv < rv, cfg["vazio"][0])
                nucleo |= dv < rv + 1
        mf = (camada_faiscas[:, :, 3] > 0) & ~nucleo
        f[mf] = camada_faiscas[mf]
        # 5) cristais que brotam do chão e estilhaçam
        for c in cristais:
            cresc = [0, 0.55, 1.0, 1.0, 0.92, 0, 0, 0][t]
            if cresc <= 0:
                continue
            bx, by = tela(math.cos(c["a"]) * c["rho"], math.sin(c["a"]) * c["rho"], 0)
            tipx = bx + math.cos(c["a"]) * c["alt"] * 0.55 * cresc
            tipy = by + math.sin(c["a"]) * c["alt"] * 0.25 * cresc - c["alt"] * cresc
            lw = c["larg"]
            ox, oy = -(tipy - by), (tipx - bx)
            nn = math.hypot(ox, oy) or 1
            ox, oy = ox / nn * lw, oy / nn * lw
            m = poligono(S, S, [(bx - ox, by - oy), (tipx, tipy), (bx + ox, by + oy)])
            lado = ((X - bx) * (tipy - by) - (Y - by) * (tipx - bx)) < 0
            pinta(f, m & lado, cfg["cristal"][0])
            pinta(f, m & ~lado, cfg["cristal"][1])
            if t == 4:  # trinca antes de quebrar
                linha(f, (bx + tipx) / 2, (by + tipy) / 2, (bx + tipx) / 2 + ox * 0.6, (by + tipy) / 2 + oy * 0.6, cfg["cristal"][2])
            pinta(f, borda4(m) & (f[:, :, 3] == 0), cfg["cristal"][2])
        # 6) raios que saem do centro
        if cfg.get("raios") and t <= 3:
            for i in range([4, 5, 4, 2][t]):
                a = rg.uniform(0, 2 * math.pi)
                L = S * [0.24, 0.4, 0.44, 0.34][t] * rg.uniform(0.7, 1.0)
                x1 = cx + 0.5 + math.cos(a) * L
                y1 = cy + 0.5 + math.sin(a) * L * 0.6
                pts = zigue(f, rg, cx + 0.5, cy + 0.5, x1, y1, cfg["raios"][min(t, 2)], passo=3, desvio=1.8)
                if t >= 1 and len(pts) > 3:
                    bx0, by0 = pts[len(pts) // 2]
                    a2 = a + rg.choice([-1, 1]) * 0.7
                    zigue(f, rg, bx0, by0, bx0 + math.cos(a2) * L * 0.35, by0 + math.sin(a2) * L * 0.35 * 0.6,
                          cfg["raios"][min(t + 1, 2)], passo=2, desvio=1.0)
        limpa(f)
        quadros.append(f)
    return quadros


# ---------------------------------------------------------------- marca no chão

def marca(cfg, semente, W=48, H=32):
    rg = np.random.default_rng(semente)
    rzb = Ruido(rg)
    rze = Ruido(rg)
    cx, cy = W // 2, H // 2
    X, Y = grade(W, H)
    dx = X - (cx + 0.5)
    dy = Y - (cy + 0.5)
    rx = cfg.get("rx", 19)
    ry = rx * 0.52
    e = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2) + (rzb(X / 3, Y / 2.2) - 0.5) * 0.38
    eros = rze(X / 2.2, Y / 1.8)
    trincas = []
    for i in range(cfg.get("n_trincas", 7)):
        a = (i + rg.uniform(-0.3, 0.3)) * 2 * math.pi / cfg.get("n_trincas", 7)
        comp = rg.uniform(0.6, 1.0)
        pts = [(cx + 0.5 + math.cos(a) * rx * 0.12, cy + 0.5 + math.sin(a) * ry * 0.12)]
        n = 4
        for j in range(1, n + 1):
            s = 0.12 + (comp - 0.12) * j / n
            aj = a + rg.uniform(-0.25, 0.25)
            pts.append((cx + 0.5 + math.cos(aj) * rx * s, cy + 0.5 + math.sin(aj) * ry * s))
        trincas.append(pts)
    brotos = [(cx + rg.uniform(-0.6, 0.6) * rx, cy + rg.uniform(-0.5, 0.6) * ry, rg.integers(0, 2)) for _ in range(cfg.get("n_brotos", 0))]
    quadros = []
    for t in range(4):
        f = novo(W, H)
        borda = [1.0, 0.97, 0.88, 0.7][t]
        limiar = [-1, 0.22, 0.45, 0.7][t]
        vis = (e < borda) & (eros > limiar)
        # pontilhado na borda que some (alfa só 0/255)
        xadrez = ((np.floor(X) + np.floor(Y)) % 2) == 0
        if t >= 2:
            vis &= ~((e > borda - 0.18) & xadrez)
        tons = cfg["chao"]
        pinta(f, vis & (e >= 0.72), tons[2])
        pinta(f, vis & (e < 0.72) & (e >= 0.4), tons[1])
        pinta(f, vis & (e < 0.4), tons[0])
        if cfg.get("aro"):
            pinta(f, vis & (e >= 0.78) & (dy < 0.3 * ry), cfg["aro"][0])
            pinta(f, vis & (e >= 0.78) & (dy >= 0.3 * ry), cfg["aro"][1])
        # trincas (brilham e esfriam)
        ct = cfg["trinca"][t]
        if ct is not None:
            for pts in trincas:
                corte = [1.0, 1.0, 0.75, 0.5][t]
                usa = pts[:max(2, int(len(pts) * corte))]
                tmp = novo(W, H)
                for (a, b), (c2, d) in zip(usa, usa[1:]):
                    linha(tmp, a, b, c2, d, ct)
                m = tmp[:, :, 3] > 0
                if t >= 1:
                    m &= (f[:, :, 3] > 0) | (t == 1)
                pinta(f, m, ct)
        # extras por material
        if cfg.get("brasas") and t <= 1:
            for i in range([5, 3][t]):
                bx = cx + rg.uniform(-0.55, 0.55) * rx
                by = cy + rg.uniform(-0.45, 0.45) * ry
                ponto2(f, bx, by, cfg["brasas"][t])
        if cfg.get("brilhos"):
            for i in range([6, 4, 3, 1][t]):
                bx = cx + rg.uniform(-0.7, 0.7) * rx
                by = cy + rg.uniform(-0.6, 0.6) * ry
                mais(f, bx, by, cfg["brilhos"][0 if (i + t) % 2 == 0 else 1], 1 if t < 2 else (1 if i == 0 else 0) or 1)
        if cfg.get("espetos"):
            for i, pts in enumerate(trincas):
                altura = [3, 3, 2, 1][t] - (i % 2)
                if altura <= 0 or (t == 3 and i % 3):
                    continue
                bx, by = pts[-1]
                linha(f, bx, by, bx, by - altura, cfg["espetos"][0])
                linha(f, bx + 1, by, bx + 1, by - altura + 1, cfg["espetos"][1])
        if cfg.get("fios") and cfg["fios"][t] is not None:
            for i in range([4, 3, 2, 1][t]):
                pts = trincas[rg.integers(0, len(trincas))]
                j = rg.integers(1, len(pts))
                ax_, ay_ = pts[j]
                bx_, by_ = pts[j - 1]
                zigue(f, rg, ax_, ay_ - 1, bx_ + rg.uniform(-2, 2), by_ - rg.uniform(0, 2), cfg["fios"][t], passo=2, desvio=1.2)
        if brotos:
            for i, (bx, by, tipo) in enumerate(brotos):
                alt = [1, 3, 3, 2][t]
                if t == 3 and i % 2:
                    continue
                c = cfg["broto"]
                linha(f, bx, by, bx, by - alt, c[1])
                if alt >= 2:
                    s = 1 if tipo else -1
                    ponto2(f, bx + (1 if s > 0 else -2), by - alt, c[0])
                    if t <= 2:
                        ponto2(f, bx + (-2 if s > 0 else 1), by - alt + 1, c[0])
        limpa(f)
        quadros.append(f)
    return quadros


# ---------------------------------------------------------------- definições

FOGO = cores("#fffdf1", "#f3c05f", "#f2843e", "#e64a1b", "#833019")
FUMACA_FOGO = cores("#62585d", "#474441", "#2a2724")
ROCHA = dict(cont="#3b1f2e", esc="#5d3729", med="#7c4832", clr="#a8643a", bri="#e8a070")


def def_meteoros():
    return [
        dict(sprite="meteoro_flamejante", armas=["meteoro_flamejante"], queda=(46, 30), imp=72,
             cabeca="rocha", r=6.6, rocha=ROCHA, veios="#f4ad3f", veios2="#e64a1b",
             rastro=dict(tons=cores("#ebe8c2", "#f3c05f", "#f2843e", "#e64a1b", "#bf321c"), lim=[0.95, 0.72, 0.5, 0.3, 0.15],
                         L=36, larg=1.2, tremor=0.4, pulso=0.2), brasas=cores("#f3c05f", "#f2843e", "#e64a1b", "#bf321c"),
             impacto=dict(fogo=FOGO, anel=cores("#f3c05f", "#f2843e", "#bf321c"), faisca=cores("#fffdf1", "#f3c05f", "#f2843e", "#bf321c"),
                          fumaca=FUMACA_FOGO, pedaco=cores("#5d3729", "#3b1f2e"), n_pedacos=7, n_faiscas=16, n_fumaca=8),
             marca=dict(chao=cores("#1c1410", "#2e1a1c", "#4a2c26"), trinca=cores("#f4ad3f", "#ea6123", "#a8301c", None),
                        brasas=cores("#f3c05f", "#e64a1b"))),
        dict(sprite="cometa_gelo", armas=["cometa_gelado"], queda=(36, 24), imp=48,
             cabeca="cristal", r=5.0, cristal=dict(cont="#24425e", esc="#487ba0", med="#6facd9", clr="#a2d5f3", bri="#eef8ff"),
             rastro=dict(tons=cores("#eef8ff", "#a2d5f3", "#6facd9", "#5490bf", "#487ba0"), lim=[1.0, 0.7, 0.48, 0.3, 0.17],
                         L=28, larg=1.25, onda=1.6, ciclos=1.2), brasas=cores("#eef8ff", "#a2d5f3", "#6facd9", "#5490bf"), brilho_brasa="#eef8ff",
             impacto=dict(fogo=cores("#ffffff", "#d9f6ff", "#a2d5f3", "#6facd9", "#487ba0"), anel=cores("#eef8ff", "#a2d5f3", "#6facd9"),
                          faisca=cores("#ffffff", "#d9f6ff", "#a2d5f3", "#6facd9"), fumaca=cores("#d9f6ff", "#a2cde3", "#6a9fc7"),
                          cristal=cores("#eef8ff", "#6facd9", "#24425e"), n_cristais=6, n_faiscas=8, n_fumaca=5, bola=0.85,
                          tipo_faisca="risco"),
             marca=dict(chao=cores("#d9f6ff", "#a2cde3", "#6a9fc7"), trinca=cores("#ffffff", "#eef8ff", "#d9f6ff", None),
                        espetos=cores("#eef8ff", "#6facd9"), rx=17)),
        dict(sprite="cometa_roxo", armas=["cometa_negro"], queda=(64, 42), imp=72,
             cabeca="vazio", r=10.0, vazio=dict(cont="#120f19", miolo="#120f19", sombra="#1f172b", aro2="#7b3397", aro="#d680b5", reflexo="#9086a5"),
             rastro=dict(tons=cores("#d680b5", "#7b3397", "#59295c", "#382055", "#2a1d3b"), lim=[0.95, 0.7, 0.48, 0.3, 0.16],
                         L=50, larg=1.1, esc=1.5, onda=2.4, ciclos=1.0), brasas=cores("#d680b5", "#9086a5", "#7a498c", "#5e446a"), brilho_brasa="#d680b5",
             impacto=dict(fogo=cores("#fef6f6", "#d680b5", "#7b3397", "#382055", "#1f172b"), anel=cores("#d680b5", "#7b3397", "#59295c"),
                          faisca=cores("#fef6f6", "#d680b5", "#9086a5", "#7a498c"), fumaca=cores("#5e446a", "#382055", "#1f172b"),
                          vazio=cores("#120f19", "#d680b5"), n_faiscas=16, n_fumaca=8),
             marca=dict(chao=cores("#120f19", "#1f172b", "#2a1d3b"), trinca=cores("#d680b5", "#a24fa0", "#59295c", None))),
        dict(sprite="estrela_cadente", armas=["estrelas_cadentes"], queda=(40, 18), imp=48,
             cabeca="estrela", r=6.0, estrela=dict(cont="#833019", borda="#f4ad3f", corpo="#f3c05f", miolo="#fffdf1"),
             rastro=dict(tons=cores("#ebe8c2", "#f0d798", "#f3c05f", "#f4ad3f", "#f2843e"), lim=[1.05, 0.75, 0.52, 0.34, 0.2],
                         L=30, larg=0.62, afina=1.0, onda=0.9, ciclos=1.0), brasas=cores("#ebe8c2", "#f3c05f", "#f4ad3f", "#f2843e"), brilho_brasa="#fffdf1",
             impacto=dict(fogo=cores("#fffdf1", "#ebe8c2", "#f3c05f", "#f4ad3f", "#f2843e"), anel=cores("#f0d798", "#f3c05f", "#f4ad3f"),
                          faisca=cores("#fffdf1", "#f0d798", "#f3c05f", "#f4ad3f"), fumaca=cores("#f0d798", "#c9a46a", "#8a6a48"),
                          n_faiscas=10, n_fumaca=4, tipo_faisca="brilho", bola=0.85),
             marca=dict(chao=cores("#2e1a1c", "#4a2c26", "#6b4a34"), trinca=cores("#f3c05f", "#f4ad3f", "#c97a34", None),
                        brilhos=cores("#fffdf1", "#f3c05f"), rx=16, n_trincas=5)),
        dict(sprite="espinho_verde", armas=["chuva_espinhos"], queda=(10, 16), imp=48,
             cabeca="espinho", espinho=dict(cont="#0e2a0e", esc="#175e17", med="#228a22", clr="#3adc3a"),
             rastro=None,
             impacto=dict(fogo=cores("#e0d2b4", "#c9b79c", "#9c8468", "#7c6450", "#6e5a48"), anel=cores("#c9b79c", "#9c8468", "#6e5a48"),
                          faisca=cores("#3adc3a", "#30d230", "#228a22", "#175e17"), fumaca=cores("#c9b79c", "#9c8468", "#6e5a48"),
                          pedaco=cores("#7c4832", "#5d3729"), n_pedacos=6, n_faiscas=10, n_fumaca=5, tipo_faisca="folha",
                          forca=0.8, bola=0.7, poeira_chao=True, clarao=False),
             marca=dict(chao=cores("#3b2a20", "#5d3729", "#7c4832"), trinca=cores("#2a1d16", "#2a1d16", "#2a1d16", None),
                        broto=cores("#3adc3a", "#228a22"), n_brotos=5, rx=15, n_trincas=5)),
        dict(sprite="pedra_vulcanica", armas=["pedras_vulcanicas"], queda=(16, 12), imp=48,
             cabeca="rocha", r=3.2, rocha=dict(cont="#1c1410", esc="#3b1f2e", med="#5d3729", clr="#7c4832", bri="#a8643a"), veios=None,
             rastro=dict(tons=cores("#f3c05f", "#f2843e", "#e64a1b", "#bf321c", "#833019"), lim=[1.0, 0.72, 0.5, 0.32, 0.18],
                         L=12, larg=1.1, esc=0.6, tremor=0.35, pulso=0.12), brasas=cores("#f3c05f", "#e64a1b", "#bf321c", "#833019"),
             impacto=dict(fogo=FOGO, anel=cores("#f2843e", "#e64a1b", "#833019"), faisca=cores("#f3c05f", "#f2843e", "#e64a1b", "#833019"),
                          fumaca=FUMACA_FOGO, pedaco=cores("#5d3729", "#3b1f2e"), n_pedacos=5, n_faiscas=10, n_fumaca=5, bola=0.85),
             marca=dict(chao=cores("#1c1410", "#2e1a1c", "#4a2c26"), trinca=cores("#f2843e", "#e64a1b", "#a8301c", None),
                        brasas=cores("#f3c05f", "#e64a1b"), rx=14, n_trincas=5)),
        dict(sprite="pedra_cinza", armas=["chuva_pedras"], queda=(24, 16), imp=48,
             cabeca="rocha", r=4.3, rocha=dict(cont="#1c1822", esc="#373534", med="#56504c", clr="#7c7570", bri="#b0a8a0"), veios=None,
             rastro=dict(tons=cores("#d8d0c6", "#b0a8a0", "#8d857f", "#62585d", "#474441"), lim=[1.4, 0.95, 0.55, 0.36, 0.22],
                         L=18, larg=0.85, ganho=1.0, ruido=0.5, esc=0.8, tremor=0.3), brasas=cores("#d8d0c6", "#b0a8a0", "#8d857f", "#62585d"),
             impacto=dict(fogo=cores("#e8e0d6", "#d8d0c6", "#b0a8a0", "#8d857f", "#62585d"), anel=cores("#d8d0c6", "#b0a8a0", "#8d857f"),
                          faisca=cores("#b0a8a0", "#8d857f", "#7c7570", "#56504c"), fumaca=cores("#d8d0c6", "#b0a8a0", "#8d857f"),
                          pedaco=cores("#7c7570", "#373534"), n_pedacos=9, n_faiscas=6, n_fumaca=6, forca=0.85, bola=0.9, poeira_chao=True, clarao=False),
             marca=dict(chao=cores("#373534", "#474441", "#62585d"), trinca=cores("#1c1822", "#1c1822", "#1c1822", None),
                        aro=cores("#b0a8a0", "#7c7570"), rx=15, n_trincas=6)),
        dict(sprite="fogo_do_ceu", armas=["fogo_do_ceu"], queda=(38, 26), imp=72,
             cabeca="fogo", r=6.0, fogo=dict(cont="#a8301c", branco="#fffdf1", claro="#f0d798", medio="#f3c05f", borda="#f2843e"),
             rastro=dict(tons=cores("#fffdf1", "#f0d798", "#f3c05f", "#f4ad3f", "#f2843e"), lim=[1.12, 0.82, 0.56, 0.34, 0.17],
                         L=30, larg=1.0, ruido=0.52, tremor=0.45, pulso=0.2), brasas=cores("#fffdf1", "#f3c05f", "#f4ad3f", "#f2843e"),
             impacto=dict(fogo=cores("#fffdf1", "#f0d798", "#f3c05f", "#f4ad3f", "#e8702a"), anel=cores("#f0d798", "#f3c05f", "#f2843e"),
                          faisca=cores("#fffdf1", "#f0d798", "#f3c05f", "#f2843e"), fumaca=cores("#8a7468", "#62585d", "#474441"),
                          n_faiscas=18, n_fumaca=7, bola=1.1),
             marca=dict(chao=cores("#241612", "#3b2418", "#5d3a26"), trinca=cores("#fffdf1", "#f3c05f", "#e8702a", None),
                        brasas=cores("#f0d798", "#f4ad3f"))),
        dict(sprite="raio_meteorico", armas=["raio_meteorico"], queda=(48, 32), imp=48,
             cabeca="orbe", r=6.2, orbe=dict(cont="#1e222c", branco="#f2f7ff", claro="#a2d5f3", medio="#6facd9", escuro="#487ba0", arco="#d9f6ff"),
             rastro=dict(tons=cores("#f2f7ff", "#a2d5f3", "#6facd9", "#5490bf", "#3a5f86"), lim=[1.05, 0.74, 0.5, 0.32, 0.18],
                         L=37, larg=1.05, onda=1.0, ciclos=1.3), raio_rastro="#f2f7ff", brasas=cores("#f2f7ff", "#d9f6ff", "#a2d5f3", "#6facd9"), brilho_brasa="#f2f7ff",
             impacto=dict(fogo=cores("#ffffff", "#d9f6ff", "#a2d5f3", "#6facd9", "#3a5f86"), anel=cores("#d9f6ff", "#a2d5f3", "#5490bf"),
                          faisca=cores("#ffffff", "#d9f6ff", "#a2d5f3", "#6facd9"), fumaca=cores("#738b8a", "#4a5560", "#2b2e35"),
                          raios=cores("#ffffff", "#d9f6ff", "#a2d5f3"), n_faiscas=10, n_fumaca=5, bola=0.8),
             marca=dict(chao=cores("#17191d", "#1e222c", "#2b2e35"), trinca=cores("#6facd9", "#487ba0", "#3a5f86", None),
                        fios=cores("#f2f7ff", "#d9f6ff", "#a2d5f3", None), rx=17)),
    ]


def params_rastro(rs):
    """Os parâmetros de campo_rastro que a definição do rastro traz (o resto fica no padrão)."""
    chaves = ("larg", "afina", "pot", "ganho", "ruido", "esc", "onda", "ciclos", "pulso", "tremor")
    return {k: rs[k] for k in chaves if k in rs}


def queda(d, semente):
    w, h = d["queda"]
    ax, ay = int(w * 3 / 4), h // 2
    rg = np.random.default_rng(semente)
    rz = [Ruido(rg, 4, 64), Ruido(rg, 4, 64), Ruido(rg)]
    rz_cab = Ruido(rg)
    quadros = []
    for t in range(NQ):
        f = novo(w, h)
        rr = d.get("r", 3)
        rs = d["rastro"]
        if rs:
            calor = campo_rastro(w, h, ax, ay, rr, rs["L"], t, rz, **params_rastro(rs))
            faixas(f, calor, rs["tons"], rs["lim"])
            limpa(f)
            brasas(f, semente + 7, ax, ay, rr, rs["L"], t, d["brasas"], n=max(4, int(rs["L"] / 4)),
                   vel=(rs["L"] / 10, rs["L"] / 6), cristal=cor(d["brilho_brasa"]) if d.get("brilho_brasa") else None)
            if d.get("raio_rastro"):
                # um risco de raio novo a cada quadro, correndo pelo rastro
                rr_ = np.random.default_rng(semente + 50 + t)
                y0 = ay + rr_.uniform(-0.4, 0.4) * rr
                zigue(f, rr_, ax - rr * 0.8, y0, ax - rs["L"] * rr_.uniform(0.7, 0.9), ay + rr_.uniform(-0.6, 0.6) * rr,
                      cor(d["raio_rastro"]), passo=3, desvio=1.5)
        cab = d["cabeca"]
        if cab == "rocha":
            p = {k: cor(v) for k, v in d["rocha"].items()}
            cabeca_rocha(f, ax, ay, rr, t, p, crateras=True, veios=cor(d["veios"]) if d.get("veios") else None,
                         veios2=cor(d["veios2"]) if d.get("veios2") else None, forma=d.get("forma", 0))
        elif cab == "cristal":
            cabeca_cristal(f, ax, ay, rr, t, {k: cor(v) for k, v in d["cristal"].items()})
        elif cab == "vazio":
            cabeca_vazio(f, ax, ay, rr, t, {k: cor(v) for k, v in d["vazio"].items()}, rz_cab)
        elif cab == "estrela":
            cabeca_estrela(f, ax, ay, rr, t, {k: cor(v) for k, v in d["estrela"].items()})
        elif cab == "fogo":
            cabeca_fogo(f, ax, ay, rr, t, {k: cor(v) for k, v in d["fogo"].items()}, rz_cab)
        elif cab == "orbe":
            cabeca_orbe(f, ax, ay, rr, t, {k: cor(v) for k, v in d["orbe"].items()}, rz_cab, np.random.default_rng(semente + 100 + t))
        elif cab == "espinho":
            p = {k: cor(v) for k, v in d["espinho"].items()}
            # rastro do espinho: riscos de vento e folhinhas que ficam para trás
            tons = cores("#93b350", "#5f8a3a")
            for i, (yy, x0, vel) in enumerate([(ay - 5, 3, 2.5), (ay + 5, 1, 1.25), (ay - 7, 6, 3.75), (ay + 6, 4, 2.5)]):
                x = (x0 - t * vel) % 10 - 2
                linha(f, x, yy, x + 2, yy, tons[i % 2])
            # duas folhinhas que se soltam e ficam para trás, virando (deitada/em pé) a cada dois quadros
            for k, (lf, ly) in enumerate([(cor("#3adc3a"), ay - 3), (cor("#228a22"), ay + 3)]):
                idade = (t + k * NQ // 2) % NQ
                fx = 5 - idade * 0.75
                fy = ly + (-1 if k == 0 else 1) * (idade // 3)
                ponto2(f, fx, fy, lf, vertical=(idade // 2) % 2 == 1)
            limpa(f)
            cabeca_espinho(f, ax, ay, t, p)
        limpa(f)
        quadros.append(f)
    return quadros, [ax, ay]


# ---------------------------------------------------------------- saída, prévia e verificação

def tira(quadros):
    h, w = quadros[0].shape[:2]
    out = np.zeros((h, w * len(quadros), 4), np.uint8)
    for i, q in enumerate(quadros):
        out[:, i * w:(i + 1) * w] = q
    return Image.fromarray(out, "RGBA")


def previa(caminho, seqs):
    """seqs: lista de (quadros, fps, voltas). Fundo #2a2a30, 4x, vizinho mais próximo."""
    W = max(q[0].shape[1] for q, _, _ in seqs) * 4 + 16
    H = max(q[0].shape[0] for q, _, _ in seqs) * 4 + 16
    imgs, dur = [], []
    for quadros, fps, voltas in seqs:
        for _ in range(voltas):
            for q in quadros:
                fundo = Image.new("RGB", (W, H), FUNDO_PREVIA)
                im = Image.fromarray(q, "RGBA")
                im = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
                fundo.paste(im, ((W - im.width) // 2, (H - im.height) // 2), im)
                imgs.append(fundo.convert("P", palette=Image.ADAPTIVE, colors=255, dither=Image.NONE))
                dur.append(int(round(1000 / fps)))
    imgs[0].save(caminho, save_all=True, append_images=imgs[1:], duration=dur, loop=0, disposal=1, optimize=False)


def soltos(q):
    a = q[:, :, 3] > 0
    rgb = q[:, :, :3].astype(np.int64)
    k = (rgb[:, :, 0] << 16) | (rgb[:, :, 1] << 8) | rgb[:, :, 2]
    k[~a] = -1
    p = np.pad(k, 1, constant_values=-2)
    h, w = k.shape
    igual = np.zeros(k.shape, bool)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx or dy:
                igual |= p[1 + dy:1 + dy + h, 1 + dx:1 + dx + w] == k
    return int((a & ~igual).sum())


def verifica(indice):
    erros = []
    for nome, folha in indice["folhas"].items():
        for anim, a in folha["anims"].items():
            im = Image.open(SAIDA / a["arquivo"])
            if im.mode != "RGBA":
                erros.append(f"{a['arquivo']}: modo {im.mode}")
            arr = np.array(im.convert("RGBA"))
            qw, qh = a["quadro"]
            if im.size != (qw * a["n"], qh):
                erros.append(f"{a['arquivo']}: tamanho {im.size} != {(qw * a['n'], qh)}")
            al = np.unique(arr[:, :, 3])
            if not set(al.tolist()) <= {0, 255}:
                erros.append(f"{a['arquivo']}: alfa intermediário {al}")
            qs = [arr[:, i * qw:(i + 1) * qw] for i in range(a["n"])]
            for i in range(a["n"]):
                if qs[i][:, :, 3].sum() == 0:
                    erros.append(f"{a['arquivo']}: quadro {i} vazio")
                for j in range(i + 1, a["n"]):
                    dif = (qs[i] != qs[j]).any(axis=2).sum()
                    opac = max(1, ((qs[i][:, :, 3] > 0) | (qs[j][:, :, 3] > 0)).sum())
                    if dif / opac < 0.08:
                        erros.append(f"{a['arquivo']}: quadros {i} e {j} quase iguais ({dif}/{opac})")
                s = soltos(qs[i])
                if s:
                    erros.append(f"{a['arquivo']}: quadro {i} tem {s} pixel(s) solto(s)")
            if anim == "marca":
                o0 = (qs[0][:, :, 3] > 0).sum()
                o3 = (qs[-1][:, :, 3] > 0).sum()
                if o3 > 0.3 * o0:
                    erros.append(f"{a['arquivo']}: último quadro não está quase vazio ({o3}/{o0})")
            ncor = len({tuple(c) for c in arr[arr[:, :, 3] > 0][:, :3].tolist()})
            print(f"  {a['arquivo']:34s} {im.size[0]:4d}x{im.size[1]:<3d} {ncor:2d} cores")
    return erros


def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    PREVIAS.mkdir(parents=True, exist_ok=True)
    indice = {"folhas": {}}
    for i, d in enumerate(def_meteoros()):
        base = SEMENTE + i * 1000
        q_queda, anc = queda(d, base + 1)
        q_imp = impacto({k: v for k, v in d["impacto"].items()}, d["imp"], base + 2)
        q_marca = marca(d["marca"], base + 3)
        nome = d["sprite"]
        anims = {}
        for anim, qs, fps, loop, ancora in (("queda", q_queda, FPS_QUEDA, True, anc),
                                            ("impacto", q_imp, 15, False, [d["imp"] // 2, d["imp"] // 2]),
                                            ("marca", q_marca, 8, False, [24, 16])):
            arq = f"{nome}_{anim}.png"
            tira(qs).save(SAIDA / arq)
            h, w = qs[0].shape[:2]
            anims[anim] = {"arquivo": arq, "quadro": [w, h], "n": len(qs), "fps": fps, "loop": loop, "ancora": ancora}
        indice["folhas"][nome] = {"armas": d["armas"], "anims": anims}
        previa(PREVIAS / f"{nome}.gif", [(q_queda, FPS_QUEDA, 2), (q_imp, 15, 1), (q_marca, 8, 1)])
    with open(SAIDA / "indice_meteoros.json", "w", encoding="utf-8") as fp:
        json.dump(indice, fp, ensure_ascii=False, indent=2)
        fp.write("\n")
    print("verificando:")
    erros = verifica(indice)
    if erros:
        print("PROBLEMAS:")
        for e in erros:
            print("  -", e)
        sys.exit(1)
    print("ok: todas as folhas passaram")


if __name__ == "__main__":
    main()

"""Impactos das armas no estilo do pixelfx, desenhados em 1 px do mundo (guia: docs/visual_2_5d/estilo_pixelfx.md).

As receitas (partículas que esticam com a velocidade, fogo que esfria em fumaça, raio com halo, corpo e núcleo, samambaia de queimadura, cruz de
acerto, dois buffers: cor e luz aditiva) são adaptadas do pixelfx, https://github.com/patch-gg/pixelfx, MIT License, Copyright (c) 2026 Patch e
Copyright (c) 2026 Hugo Duprez (Sprite Fusion, https://www.spritefusion.com/pixel-art-vfx). Os efeitos em si são desenhos novos para o KIKIU: cada
um já sai no tamanho final da área da arma, com poucos quadros, e não depende de Node nem do clone do pixelfx.

Uso (a partir da raiz do repositório):  python jogos/hordas/fonte_arte/armas_anim/gerar_pixelfx.py [--previa pasta]
Saída: assets/v2/armas_anim/pfx_<sprite>_impacto.png, indice_pixelfx.json e, com --previa, GIFs 4x sem suavizar. Semente fixa: dá sempre o mesmo.
"""

import argparse
import json
import math
import os
import random

import numpy as np
from PIL import Image

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ASSETS = os.path.join(RAIZ, "projeto", "assets", "v2", "armas_anim")
PASSO = 1.0 / 120.0  # a simulação anda sempre a 120 Hz: o movimento não depende dos fps da folha
GRAVIDADE = 950.0
TAU = math.tau
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1.0 / 32.0
ALFAS = 5  # alfa em 6 degraus (0, 0,2 ... 1): a regra da borda dura do jogo
BRANCO = (1.0, 1.0, 1.0)


def hexa(s):
    return tuple(int(s[i : i + 2], 16) / 255.0 for i in (1, 3, 5))


def rampa(*cores):
    return [hexa(c) for c in cores]


def mistura(a, b, k):
    return tuple(a[i] + (b[i] - a[i]) * k for i in range(3))


def escala(c, k):
    return tuple(min(1.0, v * k) for v in c)


FOGO = rampa("#ffffff", "#fff3a6", "#ffe26b", "#ffc23d", "#ff8a2a", "#f2561d", "#c9281f", "#8a1f17", "#4a1712")  # do branco ao que está apagando
FUMACA = rampa("#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e")
VOLT = rampa("#1b2a6b", "#2f4fc0", "#4f86f0", "#7fb6ff", "#b3d9ff", "#e4f6ff", "#ffffff")  # o azul de COR_RAIO (0,7 0,85 1,0) no meio
GELO = rampa("#1d3a6e", "#2f6fb0", "#4fa8d8", "#8cd9f0", "#c8f2fa", "#ffffff")
ACO = rampa("#3a4150", "#6b7486", "#a7b0bd", "#dfe5ea", "#ffffff")
PEDRA = rampa("#2e2620", "#544537", "#7d6a55", "#a08a70", "#c9b79c")
AQUECIDO = rampa("#ffffff", "#fff3a6", "#ffc23d", "#f2561d")


class Tela:
    """Dois buffers, como no pixelfx: cor (opaca, pontilhada ou translúcida) e luz aditiva, que só se somam no fim."""

    def __init__(self, w, h, ax, ay):
        self.w, self.h, self.ax, self.ay = w, h, ax, ay
        self.cor = np.zeros((h, w, 3))
        self.alfa = np.zeros((h, w))
        self.luz = np.zeros((h, w, 3))
        self.yy, self.xx = np.mgrid[0:h, 0:w]

    def px(self, x, y, c, a=1.0):
        i, j = int(math.floor(x + self.ax)), int(math.floor(y + self.ay))
        if 0 <= i < self.w and 0 <= j < self.h:
            velho = self.alfa[j, i]
            novo = a + velho * (1.0 - a)
            if novo > 0.0:
                self.cor[j, i] = (np.array(c) * a + self.cor[j, i] * velho * (1.0 - a)) / novo
            self.alfa[j, i] = novo

    def ponto(self, x, y, c, a=1.0):
        """Pixel que some em pontilhado (nunca em gradiente)."""
        i, j = int(math.floor(x + self.ax)), int(math.floor(y + self.ay))
        if a >= 1.0 or a > BAYER[j % 4, i % 4]:
            self.px(x, y, c)

    def _d(self, x, y, sy=1.0):
        return np.hypot(self.xx + 0.5 - self.ax - x, (self.yy + 0.5 - self.ay - y) / sy)

    def _pinta(self, m, c, a):
        velho = self.alfa
        novo = a + velho * (1.0 - a)
        cor = np.array(c) * a[..., None] + self.cor * (velho * (1.0 - a))[..., None]
        ok = novo > 0.0
        self.cor[ok] = cor[ok] / novo[ok][:, None]
        self.alfa = np.where(m, novo, velho)

    def circulo(self, x, y, r, c, sy=1.0):
        m = self._d(x, y, sy) <= r
        self._pinta(m, c, m.astype(float))

    def disco(self, x, y, r, c, a):
        """Volume translúcido (fumaça, vapor): macio por dentro, com a borda definida depois dos degraus de alfa."""
        d = self._d(x, y)
        m = d <= r
        self._pinta(m, c, np.where(m, a * np.clip(1.25 - (d / max(r, 0.01)) ** 2, 0.0, 1.0), 0.0))

    def anel(self, x, y, r, larg, c, a=1.0, sy=1.0):
        d = self._d(x, y, sy)
        m = np.abs(d - r) <= larg * 0.5
        self._pinta(m, c, m * float(a))

    def linha(self, x0, y0, x1, y1, c, a=1.0):
        n = max(math.ceil(max(abs(x1 - x0), abs(y1 - y0))) * 2, 1)
        for i in range(n + 1):
            u = i / n
            self.ponto(x0 + (x1 - x0) * u, y0 + (y1 - y0) * u, c, a)

    def brilho(self, x, y, r, c, k):
        f = np.clip(1.0 - self._d(x, y) / max(r, 0.01), 0.0, 1.0)
        self.luz += (f * f * k)[..., None] * np.array(c)


# ------------------------------------------------------------------ partículas (recorte do src/core/sim.js do pixelfx, unidades em px e segundos)
FAISCA, FOGUINHO, FOGO_PUFF, FUMO, BRASA, GRAO, FLOCO, POEIRA = range(8)


class Particulas:
    def __init__(self, r, chao=0.0, faiscas=None):
        self.r, self.chao, self.lista, self.t = r, chao, [], 0.0
        self.faiscas = faiscas or [FOGO[1], FOGO[2], FOGO[4], FOGO[5]]

    def nasce(self, k, x, y, vx, vy, vida, cor=BRANCO, tam=1.0, atraso=0.0, vira_fumaca=False):
        self.lista.append(dict(k=k, x=x, y=y, vx=vx, vy=vy, vida=vida, max=vida, cor=cor, tam=tam, atraso=atraso, fumo=vira_fumaca, s=self.r.random() * 100))

    def anda(self, dt):
        self.t += dt
        t = self.t
        for p in list(self.lista):
            if p["atraso"] > 0.0:
                p["atraso"] -= dt
                continue
            p["vida"] -= dt
            if p["vida"] <= 0.0:
                if p["k"] == FOGO_PUFF and p["fumo"]:
                    self.nasce(FUMO, p["x"], p["y"], p["vx"] * 0.6, p["vy"] * 0.6 - 6, self.r.uniform(0.08, 0.13), None, p["tam"] * 0.8)
                self.lista.remove(p)
                continue
            k = p["k"]
            if k == FAISCA or k == GRAO:
                g = 0.45 if k == FAISCA else 1.0
                arrasto = 2.2 if k == FAISCA else 0.8
                p["vy"] += GRAVIDADE * g * dt
                p["vx"] -= p["vx"] * arrasto * dt
                p["vy"] -= p["vy"] * arrasto * dt
                if p["vy"] > 0 and p["y"] + p["vy"] * dt >= self.chao:  # quica no chão
                    p["vy"] *= -0.4
                    p["vx"] *= 0.7
            elif k == FOGO_PUFF:
                p["vy"] -= 95 * dt
                p["vx"] += math.sin(t * 17 + p["s"]) * 30 * dt
                p["vx"] -= p["vx"] * 5 * dt
                p["vy"] -= p["vy"] * 3.2 * dt
            elif k == FUMO:
                p["vy"] -= 16 * dt
                p["vx"] -= p["vx"] * 1.6 * dt
                p["vy"] -= p["vy"] * 1.2 * dt
            elif k == BRASA:
                p["vy"] += (-30 + math.sin(t * 3 + p["s"]) * 20) * dt
                p["vx"] -= p["vx"] * 1.6 * dt
                p["vy"] -= p["vy"] * 1.6 * dt
            else:  # floco e poeira: rápidos no começo, à deriva depois
                p["vx"] -= p["vx"] * 4 * dt
                p["vy"] -= p["vy"] * 4 * dt
            p["x"] += p["vx"] * dt
            p["y"] += p["vy"] * dt

    def desenha(self, tela):
        for q in self.lista:
            if q["atraso"] > 0.0:
                continue
            k, x, y = q["vida"] / q["max"], q["x"], q["y"]
            v = math.hypot(q["vx"], q["vy"]) or 1.0
            ux, uy = q["vx"] / v, q["vy"] / v
            if q["k"] == FAISCA:  # estica com a velocidade, cabeça clara e cauda quente
                s = self.faiscas
                cabeca = s[0] if k > 0.6 else s[1] if k > 0.3 else s[2]
                n = min(7.0, 1.0 + v * 0.022)
                tela.linha(x - ux * n, y - uy * n, x - ux * n * 0.4, y - uy * n * 0.4, cabeca if k > 0.5 else s[3])
                tela.linha(x - ux * n * 0.45, y - uy * n * 0.45, x, y, cabeca)
                tela.brilho(x, y, 3, cabeca, 0.4 * k)
            elif q["k"] == FOGO_PUFF:  # a bola de chama desce a rampa do branco ao vermelho enquanto sobe
                idade = 1.0 - k
                calor = min(0.999, idade**0.62 + (q["s"] % 1) * 0.1)
                i = min(len(FOGO) - 2, int(calor * (len(FOGO) - 1)))
                r = q["tam"] * (0.55 + 0.45 * min(1.0, idade * 7)) * (1.0 - idade * 0.55)
                if i >= len(FOGO) - 2:
                    tela.disco(x, y, r, FOGO[i], min(1.0, k * 3) * 0.85)
                    continue
                tela.circulo(x, y, r, FOGO[min(len(FOGO) - 1, i + 2)])
                tela.circulo(x - r * 0.16, y - r * 0.22, r * 0.78, FOGO[i])
                if r > 1.6:
                    tela.circulo(x, y - r * 0.9, r * 0.42, FOGO[i])
                if i <= 3 and r > 1.8:
                    tela.circulo(x - r * 0.28, y - r * 0.34, r * 0.36, FOGO[max(0, i - 1)])
                if i < 6:
                    tela.brilho(x, y, r * 2.4 + 2, FOGO[i], 0.18 * k)
            elif q["k"] == FUMO:  # corpo, miolo mais denso e topo aceso enquanto é nova
                idade = 1.0 - k
                r = q["tam"] * (0.65 + min(1.0, idade * 2.5) * 0.45 + idade * 0.4)
                a = min(1.0, idade * 12) * min(1.0, k * 2.4) * 0.7
                c = q["cor"] or FUMACA[min(len(FUMACA) - 1, int(idade * 1.05 * len(FUMACA)))]
                tela.disco(x, y, r, c, a * 0.6)
                tela.disco(x + r * 0.05, y + r * 0.06, r * 0.74, c, a * 0.75)
                if idade < 0.5:
                    tela.disco(x - r * 0.22, y - r * 0.3, r * 0.5, mistura(c, BRANCO, 0.14), a * 0.5 * (1 - idade * 2))
            elif q["k"] == BRASA:
                if k >= 0.25 or math.sin(self.t * 40 + q["s"]) > 0:
                    c = self.faiscas[0] if k > 0.6 else self.faiscas[1] if k > 0.3 else self.faiscas[2]
                    tela.px(x, y, c)
                    tela.brilho(x, y, 3, c, 0.3 * k)
            elif q["k"] == GRAO:
                tela.px(x, y, q["cor"])
                if q["tam"] >= 2:
                    tela.px(x + 1, y, q["cor"])
                    tela.px(x, y + 1, escala(q["cor"], 0.8))
                    tela.px(x + 1, y + 1, escala(q["cor"], 0.7))
            elif q["k"] == FLOCO:
                tela.ponto(x, y, q["cor"], min(1.0, k * 3))
                if q["tam"] > 1.3:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        tela.ponto(x + dx, y + dy, escala(q["cor"], 0.8), min(1.0, k * 3) * 0.8)
            else:  # POEIRA
                tela.disco(x, y, q["tam"] * (0.6 + (1 - k) * 0.9), q["cor"], k**1.3 * 0.7)


# ------------------------------------------------------------------ formas


def ziguezague(r, x0, y0, x1, y1, jag=0.3):
    """Raio por deslocamento do ponto médio, até trechos de ~3 px (o `zigzag` do pixelfx, sem os galhos)."""
    pts = [(x0, y0), (x1, y1)]
    off = math.hypot(x1 - x0, y1 - y0) * jag
    while len(pts) < 2 + math.hypot(x1 - x0, y1 - y0) / 3:
        novo = [pts[0]]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            n = math.hypot(bx - ax, by - ay) or 1.0
            o = r.uniform(-off, off)
            novo += [((ax + bx) / 2 - (by - ay) / n * o, (ay + by) / 2 + (bx - ax) / n * o), (bx, by)]
        pts = novo
        off *= 0.52
    return pts


def traco(tela, pts, c, a=1.0):
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        tela.linha(ax, ay, bx, by, c, a)


def samambaia(r, galhos=6, comp=(11, 19)):
    """A queimadura que a corrente deixa: frondes que saem do centro e soltam frondes menores (Lichtenberg)."""
    saida = []

    def cresce(x, y, a, n, d, nivel):
        pts = [(x, y, d)]
        lado = r.choice((-1, 1))
        s = 0.0
        while s < n:
            a += r.uniform(-0.3, 0.3)
            x += math.cos(a) * 1.4
            y += math.sin(a) * 1.4 * 0.7  # achatada: ela corre pelo chão
            d += 1.4
            pts.append((x, y, d))
            if nivel < 2 and s > 2 and r.random() < 0.24:
                lado = -lado
                cresce(x, y, a + lado * r.uniform(0.55, 1.05), (n - s) * r.uniform(0.3, 0.55), d, nivel + 1)
            s += 1.4
        saida.append(pts)

    for i in range(galhos):
        cresce(0.0, 0.0, i / galhos * TAU + r.uniform(-0.35, 0.35), r.uniform(*comp), 0.0, 0)
    return saida


def raio_cruz(tela, x, y, a, n, larg, C, de=0.0):
    """Um braço da cruz de acerto: grosso na raiz, um fio na ponta, branco esfriando para fora."""
    c, s = math.cos(a), math.sin(a)
    d = de * n
    while d <= n:
        u = d / n
        meia = larg * (1 - u) ** 1.6
        cor = BRANCO if u < 0.3 else C[3] if u < 0.62 else C[2] if u < 0.88 else C[1]
        tela.px(x + c * d, y + s * d, cor)
        o = 0.5
        while o <= meia:
            for e in (-o, o):
                tela.px(x + c * d - s * e, y + s * d + c * e, C[3] if u < 0.3 and o < 1 else C[2])
            o += 0.5
        d += 0.5


def losango(tela, x, y, r, C):
    for dy in range(-r - 1, r + 2):
        for dx in range(-r - 1, r + 2):
            m = abs(dx) + abs(dy)
            if m <= r:
                tela.px(x + dx, y + dy, BRANCO)
            elif m == r + 1:
                tela.px(x + dx, y + dy, C[2])


def cristal(tela, x, base, alto, meia, inclina, C, a=1.0):
    """Ponta de gelo facetada: um lado aceso, outro na sombra, a crista clara."""
    for i in range(int(alto) + 1):
        u = i / max(alto, 1.0)
        cx = x + inclina * u
        w = meia * (1.0 - u) ** 0.8
        for dx in range(int(-w) - 1, int(w) + 2):
            if abs(dx) > w + 0.3:
                continue
            c = C[-1] if dx == 0 else C[-2] if dx < 0 else C[2]
            if abs(dx) >= w - 0.6:
                c = C[1]
            tela.ponto(cx + dx, base - i, c, a)


# ------------------------------------------------------------------ os efeitos (cada um devolve o desenho do tempo t)


def bola_fogo(r):
    """A explosão da Bola de Fogo: clarão branco de 2 quadros, anel no chão, chamas que esfriam em fumaça, faíscas e brasas."""
    RAD, Y = 17.0, -12.0
    ps = Particulas(r)
    for _ in range(6):  # o miolo: fica junto e segura a forma da bola
        ps.nasce(FOGO_PUFF, r.uniform(-5, 5), Y + r.uniform(-5, 5), r.uniform(-24, 24), r.uniform(-34, -6), r.uniform(0.2, 0.3), None, r.uniform(9.0, 12.0))
    for _ in range(18):  # a coroa que abre
        a, d, v = r.uniform(0, TAU), r.uniform(4, RAD * 0.8), r.uniform(40, 150)
        ps.nasce(FOGO_PUFF, math.cos(a) * d, Y + math.sin(a) * d * 0.8, math.cos(a) * v, math.sin(a) * v * 0.65 - 26, r.uniform(0.22, 0.36), None, r.uniform(6.0, 9.5), 0.0, r.random() < 0.6)
    for _ in range(4):  # a coluna que sobe
        ps.nasce(FOGO_PUFF, r.uniform(-4, 4), Y, r.uniform(-10, 10), r.uniform(-150, -90), r.uniform(0.28, 0.36), None, r.uniform(5.0, 7.0), r.uniform(0, 0.05), True)
    for _ in range(8):  # a fumaça entra por trás enquanto o fogo ainda queima
        a = r.uniform(0, TAU)
        ps.nasce(FUMO, math.cos(a) * 12, Y + math.sin(a) * 8, math.cos(a) * 40, math.sin(a) * 24 - 34, r.uniform(0.24, 0.32), None, r.uniform(8.0, 11.0), r.uniform(0.06, 0.14))
    for _ in range(10):
        a, v = r.uniform(0, TAU), r.uniform(170, 340)
        ps.nasce(FAISCA, 0, Y, math.cos(a) * v, math.sin(a) * v * 0.75 - 60, r.uniform(0.16, 0.3))
    for _ in range(5):
        a, v = r.uniform(0, TAU), r.uniform(40, 110)
        ps.nasce(BRASA, math.cos(a) * 8, Y + math.sin(a) * 6, math.cos(a) * v, math.sin(a) * v - 60, r.uniform(0.34, 0.5))

    def quadro(tela, t):
        k = t / 0.24
        if k < 1:  # a onda no chão, grossa no começo: o único anel
            tela.anel(0, 0, 44 * (1 - (1 - k) ** 3), max(1.0, 5 * (1 - k)), FOGO[3] if k < 0.5 else FOGO[5], 1.0 if k < 0.6 else 0.6, 0.62)
        ps.desenha(tela)
        if t < 0.09:  # o quadro-herói
            f = 1.0 - t / 0.09
            rr = RAD * (0.85 + 0.3 * f)
            tela.circulo(0, Y, rr + 1.2, FOGO[5])
            tela.circulo(0, Y, rr, FOGO[1] if f > 0.45 else FOGO[2])
            tela.circulo(0, Y, rr * 0.6, BRANCO if f > 0.45 else FOGO[1])
        tela.brilho(0, Y, 38, FOGO[4], 0.55 * math.exp(-t / 0.12))

    return ps, quadro


def raio(r):
    """O estalo do raio no alvo: nó de ziguezagues em volta de um coração branco, samambaia que queima para fora, faíscas que mudam de rumo."""
    tree = samambaia(r)
    faiscas = []
    for _ in range(9):
        a, v = r.uniform(0, TAU), r.uniform(110, 210)
        faiscas.append(dict(x=0.0, y=0.0, vx=math.cos(a) * v, vy=math.sin(a) * v - 30, vida=r.uniform(0.14, 0.28), idade=0.0, prox=r.uniform(0.02, 0.05), rastro=[]))
    ps = Particulas(r, chao=30.0, faiscas=[VOLT[-1], VOLT[5], VOLT[3], VOLT[2]])

    def anda(dt):
        for s in faiscas:
            s["idade"] += dt
            if s["idade"] >= s["vida"]:
                continue
            s["prox"] -= dt
            if s["prox"] <= 0:  # o tranco
                s["prox"] = r.uniform(0.025, 0.055)
                v, a = math.hypot(s["vx"], s["vy"]), math.atan2(s["vy"], s["vx"]) + r.choice((-1, 1)) * r.uniform(0.6, 1.3)
                s["vx"], s["vy"] = math.cos(a) * v, math.sin(a) * v
                s["rastro"] = (s["rastro"] + [(s["x"], s["y"])])[-4:]
            s["vx"] -= s["vx"] * 3 * dt
            s["vy"] -= s["vy"] * 3 * dt - 140 * dt
            s["x"] += s["vx"] * dt
            s["y"] += s["vy"] * dt

    ps.extra = anda

    def quadro(tela, t):
        fim = 1 - min(1.0, max(0.0, (t - 0.24) / 0.1))
        for galho in tree:  # esfria descendo a rampa; só as últimas brasas somem em pontilhado
            for (x0, y0, _), (x, y, d) in zip(galho, galho[1:]):
                idade = t - d / 260
                if idade < 0:
                    break
                k = math.exp(-idade / 0.1)
                c = BRANCO if k > 0.75 else VOLT[5] if k > 0.45 else VOLT[4] if k > 0.25 else VOLT[3] if k > 0.1 else VOLT[1]
                tela.linha(x0, y0, x, y, c, fim)
                if k > 0.1:
                    tela.brilho(x, y, 4, VOLT[4], 0.2 * k * fim)
        ps.desenha(tela)
        if t < 0.2:
            a = t / 0.2
            r2 = random.Random(int(t * 30) * 7 + 3)  # o nó é refeito a cada quadro: ele estala
            raio_no = 10 * (1 - a * 0.6)
            for _ in range(int(6 * (1 - a * 0.5))):
                g, d0 = r2.uniform(0, TAU), r2.uniform(0.5, raio_no * 0.5)
                g2, d1 = g + r2.uniform(-1.2, 1.2), r2.uniform(raio_no * 0.55, raio_no)
                pts = ziguezague(r2, math.cos(g) * d0, math.sin(g) * d0, math.cos(g2) * d1, math.sin(g2) * d1, 0.5)
                traco(tela, pts, VOLT[5] if a < 0.5 else VOLT[3])
            tela.circulo(0, 0, 3 * (1 - a) + 1, VOLT[5])
            tela.circulo(0, 0, 2 * (1 - a) + 0.5, BRANCO)
        for s in faiscas:
            if s["idade"] >= s["vida"]:
                continue
            k = 1 - s["idade"] / s["vida"]
            cam = s["rastro"] + [(s["x"], s["y"])]
            traco(tela, cam, VOLT[5] if k > 0.5 else VOLT[3])
            tela.px(s["x"], s["y"], BRANCO if k > 0.4 else VOLT[5])
            tela.brilho(s["x"], s["y"], 3, VOLT[4], 0.35 * k)
        tela.brilho(0, 0, 24, VOLT[3], 0.55 * math.exp(-t / 0.08) * (0.7 if int(t * 30) % 2 else 1.0))

    return ps, quadro


def acerto(r):
    """O acerto de lâmina: cruz torta em volta de um losango branco, depois lascas quentes que caem. Sem direção: serve de qualquer lado."""
    C = ACO
    ps = Particulas(r, chao=12.0, faiscas=AQUECIDO)
    for _ in range(6):
        a, v = r.uniform(0, TAU), r.uniform(110, 230)
        ps.nasce(FAISCA, 0, 0, math.cos(a) * v, math.sin(a) * v - 40, r.uniform(0.12, 0.2))
    for _ in range(4):
        a, v = r.uniform(0, TAU), r.uniform(50, 110)
        ps.nasce(GRAO, 0, 0, math.cos(a) * v, math.sin(a) * v - r.uniform(30, 70), r.uniform(0.14, 0.2), r.choice((C[3], C[2], AQUECIDO[2])))
    inc = r.uniform(-0.1, 0.1) + 0.35  # a cruz vem deitada, para não parecer um +
    bracos = [(inc, 16, 2.2), (inc + math.pi, 13, 2.2), (inc - math.pi / 2, 10, 2.4), (inc + math.pi / 2, 7, 2.2)]

    def quadro(tela, t):
        ps.desenha(tela)
        if t < 0.034:
            for a, n, w in bracos:
                raio_cruz(tela, 0, 0, a, n, w, C)
            losango(tela, 0, 0, 3, C)
        elif t < 0.067:
            for a, n, w in bracos:
                raio_cruz(tela, 0, 0, a, n * 1.2, w * 0.55, C, 0.12)
            losango(tela, 0, 0, 2, C)
        elif t < 0.1:
            a, n, _ = bracos[0]
            raio_cruz(tela, 0, 0, a, n * 1.3, 0.6, C, 0.4)
            raio_cruz(tela, 0, 0, a + math.pi, n * 1.1, 0.6, C, 0.4)
        tela.brilho(0, 0, 14, C[3], 0.5 * math.exp(-t / 0.04))

    return ps, quadro


def cometa_gelado(r):
    """O cometa bate e o gelo brota em roda: pontas que crescem, seguram um instante e quebram em cacos, com a geada abrindo no chão."""
    C = GELO
    ps = Particulas(r, faiscas=[C[-1], C[-2], C[-3], C[2]])
    pontas = []
    for i in range(11):
        a = i / 11 * TAU + r.uniform(-0.2, 0.2)
        d = r.uniform(16, 44)
        pontas.append(dict(x=math.cos(a) * d, y=math.sin(a) * d * 0.62, alto=r.uniform(14, 30) * (1.25 - d / 70), meia=r.uniform(3, 5), inc=math.cos(a) * r.uniform(2, 7), t0=d / 400))
    pontas.append(dict(x=0.0, y=2.0, alto=38.0, meia=7.0, inc=1.0, t0=0.0))
    pontas.sort(key=lambda p: p["y"])  # as de trás primeiro
    QUEBRA = 0.2
    cacos = []
    for p in pontas:
        for _ in range(2 if p["alto"] < 30 else 5):
            a = r.uniform(-math.pi, 0)
            v = r.uniform(70, 210)
            cacos.append(dict(x=p["x"] + r.uniform(-3, 3), y=p["y"] - r.uniform(0, p["alto"]), vx=math.cos(a) * v, vy=math.sin(a) * v, a=r.uniform(0, TAU), va=r.uniform(-14, 14), n=r.uniform(2.5, 4.5), vida=r.uniform(0.12, 0.24), t0=p["t0"]))
    for _ in range(6):
        a, v = r.uniform(0, TAU), r.uniform(20, 90)
        ps.nasce(FLOCO, math.cos(a) * 20, math.sin(a) * 12 - 8, math.cos(a) * v, math.sin(a) * v * 0.6 - 25, r.uniform(0.3, 0.5), C[-2], r.uniform(1, 2), r.uniform(0, 0.2))
    for i in range(14):  # o vapor frio: um cinturão contínuo que nasce na quebra das pontas
        a = i / 14 * TAU
        ps.nasce(POEIRA, math.cos(a) * 30, math.sin(a) * 17 - 3, math.cos(a) * r.uniform(30, 60), math.sin(a) * 18 - 10, r.uniform(0.24, 0.3), C[2], r.uniform(9, 12), QUEBRA - 0.04)
    relogio = [0.0]

    def anda(dt):
        relogio[0] += dt
        for c in cacos:
            if relogio[0] < QUEBRA + c["t0"]:  # quebra de dentro para fora, como cresceu
                continue
            c["vy"] += GRAVIDADE * 0.8 * dt
            c["vx"] -= c["vx"] * 1.2 * dt
            c["x"] += c["vx"] * dt
            c["y"] += c["vy"] * dt
            c["a"] += c["va"] * dt
            c["vida"] -= dt

    ps.extra = anda

    def quadro(tela, t):
        if t < 0.34:  # a geada abre no chão, branca na frente da onda
            k = min(1.0, t / 0.2)
            rr = 58 * (1 - (1 - k) ** 3)
            tela.anel(0, 0, rr, max(1.5, 5 * (1 - k)), C[-2], 1.0 if t < 0.2 else 0.6, 0.62)
        ps.desenha(tela)
        for p in pontas:
            u = min(1.0, max(0.0, (t - p["t0"]) / 0.07))
            if u > 0 and t < QUEBRA + p["t0"]:
                cristal(tela, p["x"], p["y"], p["alto"] * (1 - (1 - u) ** 3), p["meia"], p["inc"], C)
                tela.brilho(p["x"], p["y"] - p["alto"] * 0.5, 12, C[3], 0.1)
        for c in cacos:
            if c["vida"] > 0 and t >= QUEBRA + c["t0"]:
                dx, dy = math.cos(c["a"]) * c["n"], math.sin(c["a"]) * c["n"]
                for o in (0, 1):  # caco de 2 px: lê como pedaço, não como risco
                    tela.linha(c["x"] - dx, c["y"] - dy + o, c["x"] + dx, c["y"] + dy + o, C[-2] if o == 0 else C[2])
        if t < 0.07:
            f = 1 - t / 0.07
            tela.circulo(0, -8, 12 * f + 3, C[-2], 0.8)
            tela.circulo(0, -8, 8 * f + 1, BRANCO, 0.8)
        tela.brilho(0, -10, 56, C[3], 0.5 * math.exp(-t / 0.14))

    return ps, quadro


def chuva_pedras(r):
    """A pedra bate: rachadura que corre no chão, terra e lascas jogadas para cima, poeira rolando rente ao chão. Nada de luz: é peso."""
    C = PEDRA
    ps = Particulas(r, faiscas=[C[4], C[3], C[2], C[1]])
    for i in range(8):  # a poeira rola para os lados
        s = -1 if i % 2 else 1
        ps.nasce(POEIRA, s * r.uniform(0, 6), -r.uniform(1, 5), s * r.uniform(50, 110), -r.uniform(2, 14), r.uniform(0.26, 0.4), r.choice((C[3], C[2])), r.uniform(4, 6.5))
    for _ in range(4):
        ps.nasce(FUMO, r.uniform(-5, 5), -r.uniform(2, 8), r.uniform(-10, 10), -r.uniform(30, 70), r.uniform(0.28, 0.38), C[2], r.uniform(3.5, 5))
    for _ in range(14):
        u = r.uniform(-1, 1)
        a, v = -math.pi / 2 + u * 0.7, r.uniform(90, 230) * (1 - 0.35 * abs(u))
        ps.nasce(GRAO, u * 5, -1, math.cos(a) * v, math.sin(a) * v, r.uniform(0.26, 0.4), r.choice((C[4], C[3], C[2], C[1])), 2 if r.random() < 0.45 else 1)
    fendas = []
    for i in range(5):
        a = i / 5 * TAU + r.uniform(-0.4, 0.4)
        fendas.append(ziguezague(r, 0, 0, math.cos(a) * r.uniform(14, 26), math.sin(a) * r.uniform(8, 14), 0.25))

    def quadro(tela, t):
        some = 1 - min(1.0, max(0.0, (t - 0.2) / 0.16))
        k = min(1.0, t / 0.05)
        for f in fendas:
            traco(tela, f[: max(2, int(len(f) * k))], C[0], some)
        if t < 0.14:
            tela.anel(0, 0, 8 + 22 * (1 - (1 - t / 0.14) ** 3), 3 * (1 - t / 0.14) + 1, C[3], 1.0, 0.62)
        ps.desenha(tela)
        if t < 0.05:
            tela.circulo(0, -2, 6, C[4], 0.62)
            tela.circulo(0, -2, 3, BRANCO, 0.62)

    return ps, quadro


# id da folha -> (arma(s), função, quadro, âncora, quadros, fps, cores)
EFEITOS = {
    "bola_fogo": dict(fn=bola_fogo, quadro=(112, 96), ancora=(56, 68), n=13, fps=24, semente=11, cores=20),
    "raio": dict(fn=raio, quadro=(64, 56), ancora=(32, 28), n=10, fps=30, semente=5, cores=12),
    "adaga_aco": dict(fn=acerto, quadro=(48, 40), ancora=(24, 20), n=5, fps=30, semente=3, cores=10),
    "cometa_gelo": dict(fn=cometa_gelado, quadro=(128, 104), ancora=(64, 66), n=12, fps=24, semente=8, cores=12),
    "pedra_cinza": dict(fn=chuva_pedras, quadro=(72, 64), ancora=(36, 44), n=9, fps=24, semente=4, cores=12),
}


def achatar(tela):
    """Cor e luz viram um RGBA só: onde não há cor, a luz vira pixel translúcido da cor dela (em degraus, nunca em gradiente)."""
    a = tela.alfa
    luz = np.clip(tela.luz, 0.0, 1.0)
    ag = np.clip(luz.max(axis=2) * 0.9, 0.0, 1.0)
    ag = np.where(ag < 0.17, 0.0, ag)  # o halo fraco não vira névoa de pixels soltos
    fora = a + ag * (1 - a)
    pre = tela.cor * a[..., None] + luz * np.where(ag > 0, 1.0, 0.0)[..., None]
    rgb = np.clip(pre / np.maximum(fora, 1e-5)[..., None], 0.0, 1.0)
    return rgb, np.round(fora * ALFAS) / ALFAS


def limpar(rgb, a):
    """Tira o pixel translúcido sem vizinho (sujeira); faísca opaca fica."""
    tem = a > 0
    viz = np.zeros_like(a)
    pad = np.pad(tem, 1).astype(float)
    for dy in (0, 1, 2):
        for dx in (0, 1, 2):
            if (dx, dy) != (1, 1):
                viz += pad[dy : dy + a.shape[0], dx : dx + a.shape[1]]
    return rgb, np.where((viz == 0) & (a < 0.8), 0.0, a)


def gerar(nome, d):
    w, h = d["quadro"]
    r = random.Random(d["semente"])
    ps, quadro = d["fn"](r)
    extra = getattr(ps, "extra", None)
    feitos = []
    t = 0.0
    for i in range(d["n"]):
        alvo = i / d["fps"] + 0.004
        while t < alvo:
            ps.anda(PASSO)
            if extra:
                extra(PASSO)
            t += PASSO
        tela = Tela(w, h, d["ancora"][0], d["ancora"][1])
        quadro(tela, t)
        feitos.append(limpar(*achatar(tela)))
    # paleta enxuta para a folha inteira: as cores das bordas translúcidas caem nos mesmos tons do miolo
    tira_rgb = np.concatenate([f[0] for f in feitos], axis=1)
    tira_a = np.concatenate([f[1] for f in feitos], axis=1)
    img = Image.fromarray((tira_rgb * 255).astype(np.uint8), "RGB")
    visivel = np.where(tira_a[..., None] > 0, tira_rgb, 0.0)
    pal = Image.fromarray((visivel * 255).astype(np.uint8), "RGB").quantize(colors=d["cores"], method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    rgb = np.array(img.quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB"))
    alfa = (tira_a * 255).round().astype(np.uint8)
    rgba = np.dstack([np.where(alfa[..., None] > 0, rgb, 0), alfa])
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def previa(tira, d, caminho, fundo=(42, 42, 48)):
    """GIF ampliado 4x sem suavizar, na velocidade dos fps, sobre o cinza da SPEC_ARTE, com uma pausa no fim."""
    w, h = d["quadro"]
    quadros = []
    for i in range(d["n"]):
        q = Image.new("RGBA", (w, h), fundo + (255,))
        q.alpha_composite(tira.crop((i * w, 0, (i + 1) * w, h)))
        quadros.append(q.convert("RGB").resize((w * 4, h * 4), Image.NEAREST))
    durs = [int(1000 / d["fps"])] * (len(quadros) - 1) + [500]
    quadros[0].save(caminho, save_all=True, append_images=quadros[1:], duration=durs, loop=0, optimize=False, disposal=2)


# as armas que trocam o impacto: folha do índice antigo -> armas. O índice novo repete as outras animações, para a folha antiga seguir valendo.
ANTIGOS = {"bola_fogo": "indice_projeteis.json", "adaga_aco": "indice_projeteis.json", "raio": "indice_magias.json", "cometa_gelo": "indice_meteoros.json", "pedra_cinza": "indice_meteoros.json"}


def escrever_indice():
    folhas = {}
    for nome, d in EFEITOS.items():
        velho = json.load(open(os.path.join(ASSETS, ANTIGOS[nome]), encoding="utf-8"))["folhas"][nome]
        anims = dict(velho["anims"])
        anims["impacto"] = {"arquivo": "pfx_%s_impacto.png" % nome, "quadro": list(d["quadro"]), "n": d["n"], "fps": d["fps"], "loop": False, "ancora": list(d["ancora"])}
        folhas[nome] = {"armas": velho["armas"], "anims": anims}
    saida = {"_gerado_por": "jogos/hordas/fonte_arte/armas_anim/gerar_pixelfx.py (nao edite a mao)", "folhas": folhas}
    with open(os.path.join(ASSETS, "indice_pixelfx.json"), "w", encoding="utf-8") as f:
        json.dump(saida, f, ensure_ascii=False, indent=1)
        f.write("\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--previa", help="pasta dos GIFs 4x")
    args = ap.parse_args()
    for nome, d in EFEITOS.items():
        tira = gerar(nome, d)
        tira.save(os.path.join(ASSETS, "pfx_%s_impacto.png" % nome))
        if args.previa:
            os.makedirs(args.previa, exist_ok=True)
            previa(tira, d, os.path.join(args.previa, "pfx_%s_impacto.gif" % nome))
        print(nome, tira.size, "cores", len(set(map(tuple, np.array(tira)[np.array(tira)[..., 3] > 0][:, :3]))))
    escrever_indice()


if __name__ == "__main__":
    main()

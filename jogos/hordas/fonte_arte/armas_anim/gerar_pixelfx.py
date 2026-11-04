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


def tema(*base):
    """Rampa de 9 tons, do branco ao apagado, a partir de 5 cores-chave: toda família de efeito desce a mesma escada, só muda a cor."""
    c = [hexa(x) for x in base]
    return [mistura(c[min(i // 2, 3)], c[min(i // 2 + 1, 4)], (i % 2) * 0.5) for i in range(8)] + [c[4]]


FOGO = rampa("#ffffff", "#fff3a6", "#ffe26b", "#ffc23d", "#ff8a2a", "#f2561d", "#c9281f", "#8a1f17", "#4a1712")
FUMACA = rampa("#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e")
OURO = tema("#ffffff", "#fff3a6", "#ffd24a", "#c98a1c", "#5a3a10")
GELO = tema("#ffffff", "#c8f2fa", "#6cc4e8", "#2f6fb0", "#1d3a6e")
VOLT = tema("#ffffff", "#b3d9ff", "#4f86f0", "#2f4fc0", "#1b2a6b")
SOMBRA = tema("#e8d8ff", "#b088f0", "#6a3ab0", "#3a1a68", "#160a2a")
VENENO = tema("#f0ffc0", "#a8f04a", "#5ab82a", "#2a6a1a", "#123012")
ACO = tema("#ffffff", "#dfe5ea", "#a7b0bd", "#6b7486", "#3a4150")
PEDRA = tema("#e6d8c0", "#c9b79c", "#8a7660", "#544537", "#2e2620")
CHUMBO = tema("#d8dae0", "#9a9ea8", "#64687a", "#3c3f4c", "#20222c")
CIANO = tema("#ffffff", "#c8fff4", "#5ae8d0", "#1f8f8a", "#0e3f44")
SANGUE = tema("#ffe0e0", "#ff7a7a", "#d42a3a", "#7a1020", "#30060c")
ROSA = tema("#ffffff", "#e8d0ff", "#b890f0", "#6a50b0", "#2a2060")
BRANCA = tema("#ffffff", "#ffffff", "#e8e8e8", "#b0b0b0", "#707070")
AQUECIDO = [FOGO[0], FOGO[1], FOGO[3], FOGO[5]]


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
    def __init__(self, r, chao=0.0, faiscas=None, fogo=None):
        self.r, self.chao, self.lista, self.t = r, chao, [], 0.0
        self.faiscas = faiscas or [FOGO[1], FOGO[2], FOGO[4], FOGO[5]]
        self.fogo = fogo or FOGO

    def nasce(self, k, x, y, vx, vy, vida, cor=BRANCO, tam=1.0, atraso=0.0, vira_fumaca=False, chao=None):
        c = self.chao if chao is None else chao  # cada peça cai no seu chão: a de trás bate mais alto na tela, e isso dá a profundidade
        self.lista.append(dict(k=k, x=x, y=y, vx=vx, vy=vy, vida=vida, max=vida, cor=cor, tam=tam, atraso=atraso, fumo=vira_fumaca, s=self.r.random() * 100, chao=c))

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
                if p["vy"] > 0 and p["y"] + p["vy"] * dt >= p["chao"]:  # quica, perde energia no choque e o atrito segura
                    p["vy"] *= -0.4
                    p["vx"] *= 0.6
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
                F = self.fogo
                calor = min(0.999, idade**0.62 + (q["s"] % 1) * 0.1)
                i = min(len(F) - 2, int(calor * (len(F) - 1)))
                r = q["tam"] * (0.55 + 0.45 * min(1.0, idade * 7)) * (1.0 - idade * 0.55)
                if i >= len(F) - 2:
                    tela.disco(x, y, r, F[i], min(1.0, k * 3) * 0.85)
                    continue
                tela.circulo(x, y, r, F[min(len(F) - 1, i + 2)])
                tela.circulo(x - r * 0.16, y - r * 0.22, r * 0.78, F[i])
                if r > 1.6:
                    tela.circulo(x, y - r * 0.9, r * 0.42, F[i])
                if i <= 3 and r > 1.8:
                    tela.circulo(x - r * 0.28, y - r * 0.34, r * 0.36, F[max(0, i - 1)])
                if i < 6:
                    tela.brilho(x, y, r * 2.4 + 2, F[i], 0.18 * k)
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


class Cacos:
    """Pedaços rígidos: gravidade, arrasto do ar, giro, quique que perde energia, atrito no chão e repouso (o `Bits` do pixelfx)."""

    def __init__(self):
        self.lista = []

    def nasce(self, x, y, vx, vy, n, c, c2, vida, chao=0.0, g=1.0, atraso=0.0, r=None):
        giro = r.uniform(-16, 16) if r else 9.0
        self.lista.append(dict(x=x, y=y, vx=vx, vy=vy, a=giro, va=giro, n=n, c=c, c2=c2, vida=vida, max=vida, chao=chao, g=g, atraso=atraso, parado=False))

    def anda(self, dt):
        for b in self.lista:
            if b["atraso"] > 0:
                b["atraso"] -= dt
                continue
            b["vida"] -= dt
            if b["parado"]:
                continue
            b["vy"] += GRAVIDADE * b["g"] * dt
            b["vx"] -= b["vx"] * 0.9 * dt  # arrasto do ar
            b["vy"] -= b["vy"] * 0.9 * dt
            b["a"] += b["va"] * dt
            b["x"] += b["vx"] * dt
            b["y"] += b["vy"] * dt
            if b["vy"] > 0 and b["y"] >= b["chao"]:
                b["y"] = b["chao"]
                if b["vy"] < 90:  # sem energia para outro quique: assenta
                    b["parado"], b["vx"], b["vy"], b["va"] = True, 0.0, 0.0, 0.0
                else:
                    b["vy"] *= -0.38
                    b["vx"] *= 0.55
                    b["va"] *= 0.5

    def desenha(self, tela):
        for b in self.lista:
            if b["atraso"] > 0 or b["vida"] <= 0:
                continue
            a = min(1.0, b["vida"] / (b["max"] * 0.3))
            dx, dy = math.cos(b["a"]) * b["n"], math.sin(b["a"]) * b["n"]
            tela.linha(b["x"] - dx, b["y"] - dy, b["x"] + dx, b["y"] + dy, b["c"], a)
            tela.linha(b["x"] - dx, b["y"] - dy + 1, b["x"] + dx, b["y"] + dy + 1, b["c2"], a)


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


# ------------------------------------------------------------------ as famílias (cada uma devolve (animar, desenhar); a física anda em `animar`)


def _faiscas_de(T):
    return [T[1], T[2], T[4], T[5]]


def explosao(r, R=40.0, T=FOGO, fumaca=True, pedras=0, cor_pedra=None):
    """Área que estoura: clarão de 2 quadros, frente de choque no chão, chamas que sobem e esfriam, faíscas balísticas, lascas que quicam."""
    s = R / 40.0
    Y = -12.0 * s
    RAD = 17.0 * s
    ps = Particulas(r, faiscas=_faiscas_de(T), fogo=T)
    cc = Cacos()
    for _ in range(6):  # o miolo: fica junto e segura a forma da bola
        ps.nasce(FOGO_PUFF, r.uniform(-5, 5) * s, Y + r.uniform(-5, 5) * s, r.uniform(-24, 24), r.uniform(-34, -6), r.uniform(0.2, 0.3), None, r.uniform(9.0, 12.0) * s)
    for _ in range(int(14 + 4 * s)):  # a coroa: sai rápido, o arrasto freia e o empuxo leva para cima
        a, d, v = r.uniform(0, TAU), r.uniform(4, RAD * 0.8), r.uniform(40, 150) * s
        ps.nasce(FOGO_PUFF, math.cos(a) * d, Y + math.sin(a) * d * 0.8, math.cos(a) * v, math.sin(a) * v * 0.65 - 26, r.uniform(0.22, 0.36), None, r.uniform(6.0, 9.5) * s, 0.0, fumaca and r.random() < 0.6)
    for _ in range(4):
        ps.nasce(FOGO_PUFF, r.uniform(-4, 4), Y, r.uniform(-10, 10), r.uniform(-150, -90) * s, r.uniform(0.28, 0.36), None, r.uniform(5.0, 7.0) * s, r.uniform(0, 0.05), fumaca)
    if fumaca:
        for _ in range(8):  # a fumaça quente sobe depois do fogo e se dissipa inchando
            a = r.uniform(0, TAU)
            ps.nasce(FUMO, math.cos(a) * 12 * s, Y + math.sin(a) * 8 * s, math.cos(a) * 40, math.sin(a) * 24 - 34, r.uniform(0.24, 0.32), None, r.uniform(8.0, 11.0) * s, r.uniform(0.06, 0.14))
    for _ in range(10):
        a, v = r.uniform(0, TAU), r.uniform(170, 340) * s**0.5
        ps.nasce(FAISCA, 0, Y, math.cos(a) * v, math.sin(a) * v * 0.75 - 60, r.uniform(0.16, 0.3), chao=math.sin(a) * R * 0.5)
    for _ in range(5):
        a, v = r.uniform(0, TAU), r.uniform(40, 110)
        ps.nasce(BRASA, math.cos(a) * 8, Y + math.sin(a) * 6, math.cos(a) * v, math.sin(a) * v - 60, r.uniform(0.34, 0.5))
    C = cor_pedra or PEDRA
    for _ in range(pedras):  # o que o chão joga para cima: cada lasca cai no seu lugar do chão
        a, d, v = r.uniform(0, TAU), r.uniform(0.2, 0.9), r.uniform(60, 150) * s**0.5
        cc.nasce(math.cos(a) * 6, -2, math.cos(a) * v, -r.uniform(130, 260) * s**0.5, r.uniform(1.0, 2.2), C[2], C[5], r.uniform(0.4, 0.54), chao=math.sin(a) * R * 0.62 * d, r=r)

    def animar(dt):
        ps.anda(dt)
        cc.anda(dt)

    def quadro(tela, t):
        k = t / 0.24
        if k < 1:  # a frente de choque rente ao chão
            tela.anel(0, 0, R * 1.1 * (1 - (1 - k) ** 3), max(1.0, 5 * s * (1 - k)), T[3] if k < 0.5 else T[5], 1.0 if k < 0.6 else 0.6, 0.62)
        ps.desenha(tela)
        cc.desenha(tela)
        if t < 0.09:  # o quadro-herói
            f = 1.0 - t / 0.09
            rr = RAD * (0.85 + 0.3 * f)
            tela.circulo(0, Y, rr + 1.2, T[5])
            tela.circulo(0, Y, rr, T[1] if f > 0.45 else T[2])
            tela.circulo(0, Y, rr * 0.6, BRANCO if f > 0.45 else T[1])
        tela.brilho(0, Y, 38 * s, T[4], 0.55 * math.exp(-t / 0.12))  # a luz some em decaimento, não de uma vez

    return animar, quadro


def eletrico(r, R=26.0, T=VOLT, chao=30.0):
    """Corrente que descarrega: nó de ziguezagues, queimadura em samambaia que corre e esfria, faíscas que mudam de rumo em trancos."""
    s = R / 26.0
    tree = samambaia(r, comp=(11 * s, 19 * s))
    faiscas = []
    for _ in range(9):
        a, v = r.uniform(0, TAU), r.uniform(110, 210) * s**0.5
        faiscas.append(dict(x=0.0, y=0.0, vx=math.cos(a) * v, vy=math.sin(a) * v - 30, vida=r.uniform(0.14, 0.28), idade=0.0, prox=r.uniform(0.02, 0.05), rastro=[]))

    def animar(dt):
        for f in faiscas:
            f["idade"] += dt
            if f["idade"] >= f["vida"]:
                continue
            f["prox"] -= dt
            if f["prox"] <= 0:
                f["prox"] = r.uniform(0.025, 0.055)
                v, a = math.hypot(f["vx"], f["vy"]), math.atan2(f["vy"], f["vx"]) + r.choice((-1, 1)) * r.uniform(0.6, 1.3)
                f["vx"], f["vy"] = math.cos(a) * v, math.sin(a) * v
                f["rastro"] = (f["rastro"] + [(f["x"], f["y"])])[-4:]
            f["vx"] -= f["vx"] * 3 * dt
            f["vy"] -= f["vy"] * 3 * dt - 140 * dt
            f["x"] += f["vx"] * dt
            f["y"] += f["vy"] * dt

    def quadro(tela, t):
        fim = 1 - min(1.0, max(0.0, (t - 0.24) / 0.1))
        for galho in tree:
            for (x0, y0, _), (x, y, d) in zip(galho, galho[1:]):
                idade = t - d / 260
                if idade < 0:
                    break
                k = math.exp(-idade / 0.1)
                c = BRANCO if k > 0.75 else T[1] if k > 0.45 else T[2] if k > 0.25 else T[4] if k > 0.1 else T[6]
                tela.linha(x0, y0, x, y, c, fim)
                if k > 0.1:
                    tela.brilho(x, y, 4, T[3], 0.2 * k * fim)
        if t < 0.2:
            a = t / 0.2
            r2 = random.Random(int(t * 30) * 7 + 3)  # o nó é refeito a cada quadro: ele estala
            rn = 10 * s * (1 - a * 0.6)
            for _ in range(int(6 * (1 - a * 0.5))):
                g, d0 = r2.uniform(0, TAU), r2.uniform(0.5, rn * 0.5)
                g2, d1 = g + r2.uniform(-1.2, 1.2), r2.uniform(rn * 0.55, rn)
                traco(tela, ziguezague(r2, math.cos(g) * d0, math.sin(g) * d0, math.cos(g2) * d1, math.sin(g2) * d1, 0.5), T[1] if a < 0.5 else T[3])
            tela.circulo(0, 0, 3 * s * (1 - a) + 1, T[1])
            tela.circulo(0, 0, 2 * s * (1 - a) + 0.5, BRANCO)
        for f in faiscas:
            if f["idade"] >= f["vida"]:
                continue
            k = 1 - f["idade"] / f["vida"]
            traco(tela, f["rastro"] + [(f["x"], f["y"])], T[1] if k > 0.5 else T[3])
            tela.px(f["x"], f["y"], BRANCO if k > 0.4 else T[1])
            tela.brilho(f["x"], f["y"], 3, T[3], 0.35 * k)
        tela.brilho(0, 0, 24 * s, T[3], 0.55 * math.exp(-t / 0.08) * (0.7 if int(t * 30) % 2 else 1.0))

    return animar, quadro


def acerto(r, T=ACO, faiscas=None, lascas=None):
    """O acerto: cruz torta com losango branco e lascas que caem e quicam. As faíscas com a direção exata do golpe saem em tempo real (efeitos.faiscas)."""
    C = [T[7], T[5], T[3], T[1], T[0]]
    ps = Particulas(r, chao=12.0, faiscas=faiscas or AQUECIDO)
    cc = Cacos()
    for _ in range(6):
        a, v = r.uniform(0, TAU), r.uniform(90, 170)
        ps.nasce(FAISCA, 0, 0, math.cos(a) * v, math.sin(a) * v - 30, r.uniform(0.12, 0.2))
    for _ in range(4):
        a, v = r.uniform(0, TAU), r.uniform(50, 100)
        cc.nasce(2, 0, math.cos(a) * v, math.sin(a) * v - r.uniform(30, 70), 1.0, (lascas or C)[3], (lascas or C)[1], r.uniform(0.15, 0.2), chao=r.uniform(8, 14), r=r)
    inc = -0.3
    bracos = [(inc, 17, 2.2), (inc + math.pi, 8, 2.2), (inc - math.pi / 2, 10, 2.4), (inc + math.pi / 2, 7, 2.2)]

    def animar(dt):
        ps.anda(dt)
        cc.anda(dt)

    def quadro(tela, t):
        ps.desenha(tela)
        cc.desenha(tela)
        if t < 0.034:
            for a, n, w in bracos:
                raio_cruz(tela, 0, 0, a, n, w, C)
            losango(tela, 0, 0, 3, C)
        elif t < 0.067:
            for a, n, w in bracos:
                raio_cruz(tela, 0, 0, a, n * 1.2, w * 0.55, C, 0.12)
            losango(tela, 0, 0, 2, C)
        elif t < 0.1:
            raio_cruz(tela, 0, 0, inc, 22, 0.6, C, 0.4)
        tela.brilho(0, 0, 14, C[3], 0.5 * math.exp(-t / 0.04))

    return animar, quadro


def pontas(r, R=60.0, T=GELO):
    """O que brota do chão: pontas que crescem de dentro para fora, seguram e quebram em cacos que caem, com vapor frio rente ao chão."""
    s = R / 60.0
    C = [T[8], T[6], T[4], T[3], T[1], T[0]]
    ps = Particulas(r, faiscas=[C[-1], C[-2], C[-3], C[2]])
    cc = Cacos()
    QUEBRA = 0.2
    lista = []
    for i in range(max(6, int(11 * s))):
        a = i / max(6, int(11 * s)) * TAU + r.uniform(-0.2, 0.2)
        d = r.uniform(0.27, 0.73) * R
        lista.append(dict(x=math.cos(a) * d, y=math.sin(a) * d * 0.62, alto=r.uniform(14, 30) * (1.25 - d / (R * 1.17)) * s**0.5, meia=r.uniform(3, 5) * s**0.5, inc=math.cos(a) * r.uniform(2, 7), t0=d / 400))
    lista.append(dict(x=0.0, y=2.0, alto=38.0 * s**0.5, meia=7.0 * s**0.5, inc=1.0, t0=0.0))
    lista.sort(key=lambda p: p["y"])  # as de trás primeiro
    for p in lista:
        for _ in range(2 if p["alto"] < 30 else 5):
            a, v = r.uniform(-math.pi, 0), r.uniform(70, 210)
            cc.nasce(p["x"], p["y"] - r.uniform(0, p["alto"]), math.cos(a) * v, math.sin(a) * v, r.uniform(2.5, 4.5), C[-2], C[2], r.uniform(0.22, 0.32), chao=p["y"] + r.uniform(-4, 4), g=0.8, atraso=QUEBRA + p["t0"], r=r)
    for _ in range(6):
        a, v = r.uniform(0, TAU), r.uniform(20, 90)
        ps.nasce(FLOCO, math.cos(a) * R * 0.33, math.sin(a) * R * 0.2 - 8, math.cos(a) * v, math.sin(a) * v * 0.6 - 25, r.uniform(0.3, 0.42), C[-2], r.uniform(1, 2), r.uniform(0, 0.12))
    for i in range(14):  # o vapor: cinturão contínuo que nasce na quebra das pontas
        a = i / 14 * TAU
        ps.nasce(POEIRA, math.cos(a) * R * 0.5, math.sin(a) * R * 0.28 - 3, math.cos(a) * r.uniform(30, 60), math.sin(a) * 18 - 10, r.uniform(0.24, 0.3), C[2], r.uniform(9, 12) * s, QUEBRA - 0.04)

    def animar(dt):
        ps.anda(dt)
        cc.anda(dt)

    def quadro(tela, t):
        if t < 0.34:
            k = min(1.0, t / 0.2)
            tela.anel(0, 0, R * 0.97 * (1 - (1 - k) ** 3), max(1.5, 5 * (1 - k)), C[-2], 1.0 if t < 0.2 else 0.6, 0.62)
        ps.desenha(tela)
        for p in lista:
            u = min(1.0, max(0.0, (t - p["t0"]) / 0.07))
            if u > 0 and t < QUEBRA + p["t0"]:
                cristal(tela, p["x"], p["y"], p["alto"] * (1 - (1 - u) ** 3), p["meia"], p["inc"], C)
                tela.brilho(p["x"], p["y"] - p["alto"] * 0.5, 12, C[3], 0.1)
        cc.desenha(tela)
        if t < 0.07:
            f = 1 - t / 0.07
            tela.circulo(0, -8, 12 * f * s + 3, C[-2], 0.8)
            tela.circulo(0, -8, 8 * f * s + 1, BRANCO, 0.8)
        tela.brilho(0, -10, R * 0.93, C[3], 0.5 * math.exp(-t / 0.14))

    return animar, quadro


def terra(r, R=30.0, T=PEDRA):
    """Peso batendo no chão: rachadura que corre, torrões balísticos que quicam e assentam, poeira rolando rente e subindo devagar. Sem luz."""
    s = R / 30.0
    C = [T[8], T[6], T[4], T[2], T[1]]
    ps = Particulas(r)
    cc = Cacos()
    for i in range(8):
        d = -1 if i % 2 else 1
        ps.nasce(POEIRA, d * r.uniform(0, 6), -r.uniform(1, 5), d * r.uniform(50, 110) * s, -r.uniform(2, 14), r.uniform(0.26, 0.34), r.choice((C[3], C[2])), r.uniform(4, 6.5) * s)
    for _ in range(4):
        ps.nasce(FUMO, r.uniform(-5, 5), -r.uniform(2, 8), r.uniform(-10, 10), -r.uniform(30, 70), r.uniform(0.24, 0.32), C[2], r.uniform(3.5, 5) * s)
    for _ in range(int(9 * s**0.5)):
        a, d, v = r.uniform(0, TAU), r.uniform(0.2, 0.9), r.uniform(30, 90) * s**0.5
        cc.nasce(math.cos(a) * 4, -1, math.cos(a) * v, -r.uniform(120, 240), r.uniform(1.0, 2.2), C[3], C[1], r.uniform(0.3, 0.36), chao=math.sin(a) * R * 0.6 * d, r=r)
    fendas = []
    for i in range(5):
        a = i / 5 * TAU + r.uniform(-0.4, 0.4)
        fendas.append(ziguezague(r, 0, 0, math.cos(a) * r.uniform(0.5, 0.85) * R, math.sin(a) * r.uniform(0.27, 0.47) * R, 0.25))

    def animar(dt):
        ps.anda(dt)
        cc.anda(dt)

    def quadro(tela, t):
        some = 1 - min(1.0, max(0.0, (t - 0.2) / 0.16))
        k = min(1.0, t / 0.05)
        for f in fendas:
            traco(tela, f[: max(2, int(len(f) * k))], C[0], some)
        if t < 0.14:
            tela.anel(0, 0, (8 + 22 * (1 - (1 - t / 0.14) ** 3)) * s, 3 * (1 - t / 0.14) + 1, C[3], 1.0, 0.62)
        ps.desenha(tela)
        cc.desenha(tela)
        if t < 0.05:
            tela.circulo(0, -2, 6 * s, C[4], 0.62)
            tela.circulo(0, -2, 3 * s, BRANCO, 0.62)

    return animar, quadro


# ------------------------------------------------------------------ anéis e nuvens (camada aditiva: cores claras, o preto não aparece)


def anel(r, w, h, T, extra="poeira", dur=0.4):
    """A onda que corre pelo chão e levanta o que encontra. A folha vai do centro à borda da célula; o jogo escolhe o quadro pelo avanço da frente."""
    rmax, sy = w / 2 - 2, h / w
    ps = Particulas(r, faiscas=_faiscas_de(T), fogo=T)
    cc = Cacos()
    frente = lambda t: rmax * (1 - (1 - min(1.0, t / dur)) ** 2)
    pontas_ = []
    fendas = []
    for i in range(30):
        a = i / 30 * TAU + r.uniform(-0.15, 0.15)
        t0 = r.uniform(0.04, 0.8) * dur
        d = frente(t0)
        x, y = math.cos(a) * d, math.sin(a) * d * sy
        if extra == "poeira":
            ps.nasce(POEIRA, x, y, math.cos(a) * 30, math.sin(a) * 18 - 8, r.uniform(0.16, 0.26), T[3], r.uniform(4, 7), t0)
            if i % 2:
                cc.nasce(x, y - 1, math.cos(a) * r.uniform(30, 80), -r.uniform(90, 180), r.uniform(1.0, 2.0), T[2], T[4], 0.26, chao=y, atraso=t0, r=r)
        elif extra == "faisca":
            ps.nasce(FAISCA, x, y, math.cos(a) * r.uniform(60, 140), math.sin(a) * 50 - r.uniform(40, 120), r.uniform(0.12, 0.22), atraso=t0, chao=y + 3)
        elif extra == "luz":
            ps.nasce(BRASA, x, y, math.cos(a) * 20, -r.uniform(30, 90), r.uniform(0.2, 0.32), atraso=t0)
        elif extra == "vento":
            ps.nasce(FLOCO, x, y, -math.sin(a) * 120 + math.cos(a) * 60, math.cos(a) * 70 * sy, r.uniform(0.16, 0.24), T[2], r.uniform(1, 2), t0)
        elif extra == "ponta":
            pontas_.append(dict(x=x, y=y, t0=t0, alto=r.uniform(8, 15), inc=math.cos(a) * r.uniform(1, 4)))
    pontas_.sort(key=lambda p: p["y"])
    if extra == "racha":
        for i in range(7):
            a = i / 7 * TAU + r.uniform(-0.3, 0.3)
            fendas.append(ziguezague(r, 0, 0, math.cos(a) * rmax * 0.9, math.sin(a) * rmax * 0.9 * sy, 0.2))

    def animar(dt):
        ps.anda(dt)
        cc.anda(dt)

    def quadro(tela, t):
        k = min(1.0, t / dur)
        rr = max(2.0, frente(t))
        for f in fendas:
            traco(tela, f[: max(2, int(len(f) * k))], T[3], 1.0 - 0.5 * k)
        tela.anel(0, 0, rr, max(1.0, 6 * (1 - k)), T[1] if k < 0.5 else T[3], 1.0 if k < 0.7 else 0.6, sy)
        tela.anel(0, 0, rr * 0.8, 1.0, T[4], max(0.0, 0.8 - k), sy)
        ps.desenha(tela)
        cc.desenha(tela)
        C = [T[8], T[6], T[4], T[3], T[1], T[0]]
        for p in pontas_:
            u = (t - p["t0"]) / 0.09
            if 0 < u < 1.7:
                cristal(tela, p["x"], p["y"], p["alto"] * min(1.0, u * 2) * (1.0 if u < 1 else 1.7 - u), 2.5, p["inc"], C)
        if k < 0.15:
            tela.circulo(0, 0, 5 * (1 - k * 6) + 1, T[0], sy)

    return animar, quadro


def nuvem_desenho(r, w, h, T, extra):
    """Puffs que nascem, sobem por empuxo e se dissipam em ciclos inteiros (a volta da folha não tem emenda), mais o que cai ou sobe dentro."""
    rx, ry = w * 0.36, h * 0.3
    puffs = []
    aura = extra == "brasa"  # a aura é um cinturão em volta do herói: o miolo fica livre para ele aparecer
    for i in range(int(20 + w / 7)):
        a, d = r.uniform(0, TAU), r.uniform(0.82, 1.1) if aura else r.random() ** 0.5
        puffs.append(dict(x=math.cos(a) * rx * d, y=math.sin(a) * ry * d, tam=r.uniform(0.05, 0.09) * h if aura else r.uniform(0.14, 0.27) * h, fase=r.random(), sobe=r.uniform(4, 11), c=r.choice((T[3], T[4], T[4], T[5]))))
    puffs.sort(key=lambda p: p["y"])
    bits = []
    for i in range(int(7 + w / 16)):
        a, d = r.uniform(0, TAU), r.random() ** 0.5
        bits.append(dict(x=math.cos(a) * rx * d, y=math.sin(a) * ry * d, fase=r.random(), ciclos=r.choice((1, 2))))

    def desenhar(tela, u, f, sobe=0.0):
        for p in puffs:
            ph = (u + p["fase"]) % 1.0
            a = math.sin(math.pi * ph) * (0.6 if aura else 0.3) * f
            tela.disco(p["x"] + math.sin((u + p["fase"]) * TAU) * 2.5, p["y"] - ph * p["sobe"] - sobe, p["tam"] * (0.8 + 0.5 * ph), p["c"], a)
        for b in bits:
            ph = (u * b["ciclos"] + b["fase"]) % 1.0
            if f < 0.3:
                continue
            if extra == "gota":  # a gota acelera na queda (½gt²) e abre um respingo onde bate
                y = b["y"] - 16 + 26 * ph * ph
                if ph < 0.82:
                    tela.linha(b["x"], y - 3 - 4 * ph, b["x"], y, T[2])
                else:
                    tela.anel(b["x"], b["y"] + 10, (ph - 0.82) * 22, 1, T[2], 1.0, 0.5)
            elif extra == "floco":  # o floco cai devagar e balança (arrasto alto)
                tela.ponto(b["x"] + math.sin(ph * TAU) * 3, b["y"] - 10 + 20 * ph, T[1], min(1.0, (1 - ph) * 3))
            elif extra == "bolha":
                tela.anel(b["x"], b["y"] + 6 - 16 * ph, 1 + 2.2 * ph, 1, T[2], 1.0 if ph < 0.85 else 0.4)
            elif extra == "brasa":
                tela.px(b["x"] + math.sin(ph * 9) * 2, b["y"] + 6 - 24 * ph, T[1] if ph < 0.5 else T[3])
            elif extra == "cinza":  # cinza quente: sobe primeiro, depois a gravidade vence
                tela.ponto(b["x"] + ph * 5, b["y"] - 12 * math.sin(ph * math.pi), T[2], 0.9)

    return desenhar


def cura(r, T=VENENO):
    """A cura: fagulhas que sobem por empuxo, cada uma com a sua deriva, e uma cruz que se abre e some."""
    ps = Particulas(r, faiscas=[T[0], T[1], T[2], T[3]])
    for i in range(14):
        a = r.uniform(0, TAU)
        ps.nasce(BRASA, math.cos(a) * 10, math.sin(a) * 4 - 2, math.cos(a) * 8, -r.uniform(40, 90), r.uniform(0.3, 0.52), atraso=r.uniform(0, 0.14))

    def quadro(tela, t):
        ps.desenha(tela)
        if t < 0.24:
            k = t / 0.24
            tela.anel(0, 0, 4 + 12 * k, 2 * (1 - k) + 1, T[1], 1.0, 0.5)
        tela.brilho(0, -16, 18, T[2], 0.3 * math.exp(-t / 0.2))

    return ps.anda, quadro


def rastro(tira_velha, w, h, n, ancora, T, L):
    """Trilha de voo: o desenho antigo fica, e atrás dele o rastro esfria e cai, em ciclo inteiro. Devolve a tira nova e a âncora nova."""
    r = random.Random(w * 31 + h)
    pts = [dict(f=r.random(), y=r.uniform(-1, 1) * h * 0.16, s=r.choice((1, 1, 2))) for _ in range(int(L / 2.5))]
    feitos = []
    for i in range(n):
        tela = Tela(w + L, h, 0, 0)
        for p in pts:
            ph = (i / n + p["f"]) % 1.0
            x = L + ancora[0] * 0.5 - ph * (L + ancora[0] * 0.5)
            y = ancora[1] + p["y"] * (0.4 + ph) + 8 * ph * ph  # cai: a gravidade curva o rastro
            c = T[1] if ph < 0.3 else T[3] if ph < 0.6 else T[5]
            tela.ponto(x, y, c, 1.0 - ph * 0.8)
            if p["s"] == 2 and ph < 0.5:
                tela.ponto(x + 1, y, c)
            tela.brilho(x, y, 3, T[3], 0.3 * (1 - ph))
        rgb, a = achatar(tela)
        q = np.array(tira_velha.crop((i * w, 0, (i + 1) * w, h)).convert("RGBA")).astype(float) / 255.0
        m = q[..., 3:4]
        rgb[:, L:] = q[..., :3] * m + rgb[:, L:] * (1 - m)
        a[:, L:] = np.maximum(a[:, L:], q[..., 3])
        feitos.append((rgb, a))
    return tira_de(feitos, 24), (ancora[0] + L, ancora[1])


def marca(r, T, n=4, w=48, h=32):
    """O chão que apanhou: mancha queimada com rachaduras acesas que esfriam descendo a rampa até sumir."""
    fendas = [ziguezague(r, 0, 0, math.cos(a) * r.uniform(10, 20), math.sin(a) * r.uniform(5, 11), 0.25) for a in [i / 6 * TAU + r.uniform(-0.3, 0.3) for i in range(6)]]
    feitos = []
    for i in range(n):
        tela = Tela(w, h, w // 2, h // 2)
        k = i / (n - 1)
        tela.disco(0, 0, 18, T[8], 0.8 * (1 - k))
        for f in fendas:
            traco(tela, f, T[2 + i * 2] if i < 3 else T[8], 1.0 - k * 0.7)
        feitos.append(achatar(tela))
    return tira_de(feitos, 10)


# ------------------------------------------------------------------ o que cada arma usa


def _meteoro(fn, R, **op):
    w = int(math.ceil(max(R * 2.5, 64) / 8) * 8)
    return dict(fn=fn, op=dict(R=R, **op), quadro=(w, int(w * 0.82 / 2) * 2), ancora=(w // 2, int(w * 0.52)), n=13, fps=24)


def _bola(R, T, **op):
    w = int(math.ceil(R * 2.8 / 8) * 8)
    return dict(fn=explosao, op=dict(R=R, T=T, **op), quadro=(w, int(w * 0.86 / 2) * 2), ancora=(w // 2, int(w * 0.61)), n=13, fps=24)


def _acerto(T=ACO, **op):
    return dict(fn=acerto, op=dict(T=T, **op), quadro=(48, 44), ancora=(24, 22), n=5, fps=30)


IMPACTOS = {
    # projéteis: acerto com direção
    "adaga_aco": _acerto(), "disco_ferro": _acerto(), "laminas": _acerto(), "chuva_de_ferro": _acerto(),
    "flecha_roxa": _acerto(SOMBRA, faiscas=_faiscas_de(SOMBRA)), "shuriken_sombria": _acerto(SOMBRA, faiscas=_faiscas_de(SOMBRA)),
    "lanca_gelo": _acerto(GELO, faiscas=_faiscas_de(GELO)), "chuva_de_lacas": _acerto(GELO, faiscas=_faiscas_de(GELO)),
    "dardo_verde": _acerto(VENENO, faiscas=_faiscas_de(VENENO)),
    "feixe_dourado": _acerto(OURO, faiscas=_faiscas_de(OURO)), "urso_solar": _acerto(OURO, faiscas=_faiscas_de(OURO)),
    "tempestade_primordial": _acerto(VOLT, faiscas=_faiscas_de(VOLT)), "anel_de_brasas": _acerto(FOGO, faiscas=_faiscas_de(FOGO)),
    # bolas que estouram
    "bola_fogo": _bola(40.0, FOGO), "bola_incendiaria": _bola(50.0, FOGO, pedras=8), "bola_chumbo": _bola(24.0, CHUMBO, pedras=8, cor_pedra=CHUMBO),
    # o raio
    "raio": dict(fn=eletrico, op=dict(R=26.0), quadro=(64, 56), ancora=(32, 28), n=10, fps=30),
    # meteoros: a célula tem o tamanho da área, para o jogo não ampliar
    "meteoro_flamejante": _meteoro(explosao, 50.0, pedras=10), "fogo_do_ceu": _meteoro(explosao, 45.0, T=OURO), "pedreira_ardente": _meteoro(explosao, 60.0, pedras=14),
    "estrela_cadente": _meteoro(explosao, 40.0, T=OURO, fumaca=False), "juizo_final": _meteoro(explosao, 80.0, T=OURO, pedras=14),
    "cometa_roxo": _meteoro(explosao, 70.0, T=SOMBRA, fumaca=False, pedras=8, cor_pedra=SOMBRA), "eclipse_negro": _meteoro(explosao, 80.0, T=SOMBRA, fumaca=False, pedras=10, cor_pedra=SOMBRA),
    "pedra_vulcanica": _meteoro(explosao, 25.0, pedras=6), "pedra_cinza": _meteoro(terra, 30.0),
    "cometa_gelo": _meteoro(pontas, 60.0), "cometa_duplo": _meteoro(pontas, 55.0), "espinho_verde": _meteoro(pontas, 20.0, T=VENENO),
    "raio_meteorico": _meteoro(eletrico, 60.0),
}
EXPLOSAO_RUNA = {  # a runa não chama de impacto: a animação é `explosao`
    "runa": dict(_bola(42.0, CIANO, fumaca=False), anim="explosao"),
    "circulo_runico": dict(_bola(60.0, CIANO, fumaca=False), anim="explosao"),
}
# efeitos sem folha de arma: o que antes era só camada de código. Ids fx_* são lidos por Anim.de(...) direto.
SOLTOS = {
    "fx_explode": _bola(36.0, OURO, fumaca=False),  # o crítico explosivo da katana
    "fx_cabaca": _bola(48.0, FOGO, pedras=8),
    "fx_pancada": _meteoro(terra, 40.0),  # o golem e o colosso batendo no chão
    "fx_aliado": dict(_acerto(tema("#ffffff", "#ffffff", "#e8e8e8", "#b0b0b0", "#707070"), faiscas=[BRANCO, BRANCO, (0.85, 0.85, 0.85), (0.6, 0.6, 0.6)]), cinza=True),  # tingido pela cor do aliado
}
SOLTOS.update(
    {
        "fx_morte": dict(fn=terra, op=dict(R=13.0, T=tema("#f4f0e4", "#d8d2c0", "#a8a292", "#6e6a60", "#3a3834")), quadro=(56, 48), ancora=(28, 34), n=9, fps=24),
        "fx_dano_heroi": _acerto(SANGUE, faiscas=_faiscas_de(SANGUE)),
        "fx_cura": dict(fn=lambda r: cura(r), quadro=(48, 64), ancora=(24, 52), n=12, fps=20),
        "fx_fusao": dict(fn=lambda r: anel(r, 176, 112, BRANCA, "faisca", 0.42), quadro=(176, 112), ancora=(88, 56), n=10, fps=24),  # tingida pela cor da fusão
        "fx_queda_heroi": _bola(30.0, SANGUE),
        "fx_ui_anuncio": dict(fn=lambda r: anel(r, 208, 72, BRANCA, "faisca", 0.42), quadro=(208, 72), ancora=(104, 36), n=10, fps=24),
        "fx_ui_pronta": dict(fn=lambda r: anel(r, 96, 96, BRANCA, "luz", 0.42), quadro=(96, 96), ancora=(48, 48), n=10, fps=24),
    }
)
ANEIS = {
    "anel_onda_branca": (ACO, "poeira"), "anel_dourado": (OURO, "luz"), "anel_gelo": (GELO, "ponta"), "anel_vermelho": (CIANO, "faisca"),
    "terremoto_poeira": (PEDRA, "racha"), "anel_eletrico": (VOLT, "faisca"), "redemoinho_verde": (VENENO, "vento"), "anel_espinhos_verdes": (VENENO, "ponta"),
    "anel_lunar": (ROSA, "luz"), "estrondo": (OURO, "poeira"), "terra_partida": (PEDRA, "racha"), "juramento_sagrado": (OURO, "luz"),
}
NUVENS = {
    "nuvem_veneno": (VENENO, "bolha"), "nevoa_gelada": (GELO, "floco"), "nuvem_cinzas": (CHUMBO, "cinza"), "fumaca_sonolenta": (ROSA, "bolha"),
    "chuva_acida": (OURO, "gota"), "nuvem_neve": (ACO, "floco"), "nuvem_esporos": (PEDRA, "cinza"), "nuvem_sangue": (SANGUE, "gota"), "nevoa_espectral": (CIANO, "cinza"),
    "nevasca_congelante": (GELO, "floco"), "cinzas_acidas": (VENENO, "cinza"), "peste_negra": (VENENO, "bolha"), "furacao_glacial": (GELO, "floco"),
    "aura_fogo": (FOGO, "brasa"), "anel_de_brasas": (FOGO, "brasa"),
}
INDICES = ["projeteis", "evo_projeteis", "magias", "meteoros", "evo_met_aneis", "aneis", "nuvens", "evo_nuvens"]


def achatar(tela):
    """Cor e luz viram um RGBA só: onde não há cor, a luz vira pixel translúcido da cor dela (em degraus, nunca em gradiente)."""
    a = tela.alfa
    luz = np.clip(tela.luz, 0.0, 1.0)
    ag = np.clip(luz.max(axis=2) * 0.9, 0.0, 1.0)
    ag = np.where(ag < 0.17, 0.0, ag)  # o halo fraco não vira névoa de pixels soltos
    fora = a + ag * (1 - a)
    pre = tela.cor * a[..., None] + luz * np.where(ag > 0, 1.0, 0.0)[..., None]
    rgb = np.clip(pre / np.maximum(fora, 1e-5)[..., None], 0.0, 1.0)
    alfa = np.round(fora * ALFAS) / ALFAS
    tem = alfa > 0  # pixel translúcido sem vizinho é sujeira; faísca opaca fica
    pad = np.pad(tem, 1).astype(float)
    viz = sum(pad[dy : dy + a.shape[0], dx : dx + a.shape[1]] for dy in (0, 1, 2) for dx in (0, 1, 2) if (dx, dy) != (1, 1))
    return rgb, np.where((viz == 0) & (alfa < 0.8), 0.0, alfa)


def tira_de(feitos, cores):
    """Junta os quadros e prende a folha numa paleta enxuta: as bordas translúcidas caem nos mesmos tons do miolo."""
    rgb = np.concatenate([f[0] for f in feitos], axis=1)
    a = np.concatenate([f[1] for f in feitos], axis=1)
    img = Image.fromarray((np.where(a[..., None] > 0, rgb, 0.0) * 255).astype(np.uint8), "RGB")
    pal = img.quantize(colors=cores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q = np.array(Image.fromarray((rgb * 255).astype(np.uint8), "RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB"))
    alfa = (a * 255).round().astype(np.uint8)
    return Image.fromarray(np.dstack([np.where(alfa[..., None] > 0, q, 0), alfa]).astype(np.uint8), "RGBA")


def semente(nome):
    return sum(ord(c) * (i + 1) for i, c in enumerate(nome))


def simular(nome, d):
    r = random.Random(semente(nome))
    animar, quadro = d["fn"](r, **d.get("op", {}))
    w, h = d["quadro"]
    feitos, t = [], 0.0
    for i in range(d["n"]):
        while t < i / d["fps"] + 0.004:
            animar(PASSO)
            t += PASSO
        tela = Tela(w, h, *d["ancora"])
        quadro(tela, t)
        feitos.append(achatar(tela))
    return tira_de(feitos, 20)


def simular_anel(nome, w, h, T, extra, n=8):
    r = random.Random(semente(nome))
    dur = 0.4
    animar, quadro = anel(r, w, h, T, extra, dur)
    feitos, t = [], 0.0
    for i in range(n):
        while t < (i + 0.4) / n * dur:
            animar(PASSO)
            t += PASSO
        tela = Tela(w, h, w // 2, h // 2)
        quadro(tela, t)
        feitos.append(achatar(tela))
    return tira_de(feitos, 12)


def simular_nuvem(nome, w, h, T, extra, anim, n):
    desenhar = nuvem_desenho(random.Random(semente(nome)), w, h, T, extra)
    feitos = []
    for i in range(n):
        tela = Tela(w, h, w // 2, h // 2)
        if anim in ("loop", "aura"):
            desenhar(tela, i / n, 1.0)
        elif anim == "entrada":
            desenhar(tela, i / n * 0.3, (i + 1) / (n + 1))
        else:  # saída: o empuxo leva embora enquanto dissipa
            desenhar(tela, i / n * 0.3, 1 - (i + 1) / (n + 1), (i + 1) * 3.0)
        feitos.append(achatar(tela))
    return tira_de(feitos, 12)


def previa(tira, w, h, n, fps, caminho, fundo=(42, 42, 48)):
    """GIF ampliado 4x sem suavizar, na velocidade dos fps, sobre o cinza da SPEC_ARTE, com uma pausa no fim."""
    quadros = []
    for i in range(n):
        q = Image.new("RGBA", (w, h), fundo + (255,))
        q.alpha_composite(tira.crop((i * w, 0, (i + 1) * w, h)))
        quadros.append(q.convert("RGB").resize((w * 4, h * 4), Image.NEAREST))
    quadros[0].save(caminho, save_all=True, append_images=quadros[1:], duration=[int(1000 / fps)] * (n - 1) + [400], loop=0, disposal=2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--previa", help="pasta dos GIFs 4x")
    args = ap.parse_args()
    velho = {}
    for g in INDICES:
        velho.update(json.load(open(os.path.join(ASSETS, "indice_%s.json" % g), encoding="utf-8"))["folhas"])
    folhas = {}

    def grava(nome, anim, tira, w, h, n, fps, ancora, extra=None):
        arquivo = "pfx_%s_%s.png" % (nome, anim)
        tira.save(os.path.join(ASSETS, arquivo))
        if args.previa:
            os.makedirs(args.previa, exist_ok=True)
            previa(tira, w, h, n, fps, os.path.join(args.previa, arquivo.replace(".png", ".gif")))
        v = velho.get(nome, {"armas": [nome], "anims": {}})
        f = folhas.setdefault(nome, {"armas": v["armas"], "anims": dict(v["anims"])})
        f["anims"][anim] = {"arquivo": arquivo, "quadro": [w, h], "n": n, "fps": fps, "loop": anim in ("loop", "aura"), "ancora": list(ancora)}
        f["anims"][anim].update(extra or {})

    for tabela in (IMPACTOS, EXPLOSAO_RUNA, SOLTOS):
        for nome, d in tabela.items():
            w, h = d["quadro"]
            anim = d.get("anim", "impacto")
            grava(nome, anim, simular(nome, d), w, h, d["n"], d["fps"], d["ancora"])
    for nome, (T, extra) in ANEIS.items():
        q = velho[nome]["anims"]["expandir"]
        w, h = q["quadro"]
        grava(nome, "expandir", simular_anel(nome, w, h, T, extra), w, h, 8, q["fps"], (w // 2, h // 2))
    padrao = {explosao: FOGO, eletrico: VOLT, acerto: ACO, pontas: GELO, terra: PEDRA}
    for nome, d in IMPACTOS.items():  # as trilhas e as marcas seguem a cor do impacto da mesma folha
        T = d["op"].get("T", padrao[d["fn"]])
        anims = velho[nome]["anims"]
        for anim, L in (("voo", 18), ("queda", 26)):
            q = anims.get(anim)
            if q is None or q.get("gira"):
                continue
            w, h = q["quadro"]
            antiga = Image.open(os.path.join(ASSETS, q["arquivo"]))
            tira, anc = rastro(antiga, w, h, q["n"], q.get("ancora", (w * 3 // 4, h // 2)), T, L)
            grava(nome, anim, tira, w + L, h, q["n"], q["fps"], anc, {"loop": True})
        if "marca" in anims:
            q = anims["marca"]
            grava(nome, "marca", marca(random.Random(semente(nome)), T), 48, 32, 4, q["fps"], (24, 16))
    for nome, (T, extra) in NUVENS.items():
        for anim, q in velho[nome]["anims"].items():
            if anim in ("entrada", "loop", "saida", "aura"):
                w, h = q["quadro"]
                grava(nome, anim, simular_nuvem(nome, w, h, T, extra, anim, q["n"]), w, h, q["n"], q["fps"], q.get("ancora", (w // 2, h // 2)))
    with open(os.path.join(ASSETS, "indice_pixelfx.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"_gerado_por": "jogos/hordas/fonte_arte/armas_anim/gerar_pixelfx.py (nao edite a mao)", "folhas": folhas}, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(len(folhas), "folhas")


if __name__ == "__main__":
    main()

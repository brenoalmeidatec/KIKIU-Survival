"""Gera as folhas animadas das nuvens de área da v2 (grupo "nuvens", pacote ARE-N).

Contrato: docs/combate_v2/SPEC_ARTE.md. Para cada nuvem saem três tiras horizontais em
jogos/hordas/projeto/assets/v2/armas_anim/<sprite>_<anim>.png:
  entrada 3q 10 fps (a nuvem se forma do centro), loop 6q 6 fps (4q se a célula passa de
  130 px de largura; o último quadro emenda no primeiro), saida 3q 10 fps (dissolve).
Mais o índice indice_nuvens.json e as prévias GIF 4x em docs/combate_v2/previas/<sprite>.gif.

Como é desenhado: o corpo é uma união suave de "puffs" (elipses achatadas, vista do chão em 2.5D)
que orbitam devagar; o contorno é forte (1 px, claro no lado da luz, em cima à esquerda), o miolo
é um pontilhado ralo em traços de 2 px (a nuvem não esconde os inimigos) e a borda de cima de cada
puff da frente ganha um arco claro (as dobras andam junto com os puffs). Por cima vão as partículas
de cada tema (bolhas, cristais, brasas, espirais, gotas, flocos, esporos, rostos), todas com fase
fechada no ciclo, para o loop emendar sem salto. Alfa só 0 ou 255 (o esmaecer é pontilhado).

Rodar: python -I gerar_nuvens.py  (semente fixa, sem rede; rodar de novo dá as mesmas folhas)
"""
import json
import math
import os
import random

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, "..", "..", "..", ".."))
SAIDA = os.path.join(RAIZ, "jogos", "hordas", "projeto", "assets", "v2", "armas_anim")
PREVIAS = os.path.join(RAIZ, "docs", "combate_v2", "previas")
FUNDO_PREVIA = (0x2A, 0x2A, 0x30)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0
TAU = math.tau

# ---------------------------------------------------------------- temas
# pal: d (escuro: pontilhado do miolo), m (meio: contorno), l (claro: luz do contorno e dobras), h (brilho)
TEMAS = {
    "nuvem_veneno": dict(
        armas=["nuvem_veneno"], tam=(100, 64), cy=0.60, rx=0.43, ry=0.34, seed=11, part="bolhas",
        pal=dict(d=(60, 150, 30), m=(110, 200, 40), l=(170, 240, 70), h=(232, 255, 150))),
    "nevoa_gelada": dict(
        armas=["nevoeiro_gelado"], tam=(120, 74), cy=0.60, rx=0.44, ry=0.34, seed=12, part="cristais",
        pal=dict(d=(40, 110, 190), m=(70, 160, 230), l=(140, 210, 255), h=(228, 246, 255))),
    "nuvem_cinzas": dict(
        armas=["cinzas_vulcanicas"], tam=(160, 104), cy=0.58, rx=0.44, ry=0.36, seed=13, part="brasas",
        pal=dict(d=(120, 112, 110), m=(170, 160, 152), l=(214, 204, 194), h=(240, 234, 226),
                 b1=(255, 120, 30), b2=(255, 200, 60), b3=(255, 250, 200))),
    "fumaca_sonolenta": dict(
        armas=["fumaca_sonolenta"], tam=(110, 57), cy=0.60, rx=0.44, ry=0.33, seed=14, part="espirais",
        pal=dict(d=(120, 60, 170), m=(170, 100, 215), l=(226, 170, 238), h=(255, 228, 252))),
    "chuva_acida": dict(
        armas=["chuva_acida"], tam=(120, 80), cy=0.70, rx=0.44, ry=0.26, seed=15, part="chuva",
        pal=dict(d=(110, 150, 20), m=(170, 212, 30), l=(216, 246, 60), h=(250, 255, 175))),
    "nuvem_neve": dict(
        armas=["nevasca"], tam=(140, 91), cy=0.57, rx=0.44, ry=0.36, seed=16, part="flocos",
        pal=dict(d=(110, 130, 175), m=(160, 182, 220), l=(206, 222, 248), h=(252, 253, 255))),
    "nuvem_esporos": dict(
        armas=["nuvem_espora"], tam=(120, 77), cy=0.60, rx=0.44, ry=0.33, seed=17, part="esporos",
        pal=dict(d=(140, 125, 50), m=(192, 172, 70), l=(232, 212, 112), h=(255, 246, 182))),
    "nuvem_sangue": dict(
        armas=["cortina_sangue"], tam=(70, 50), cy=0.68, rx=0.44, ry=0.28, seed=18, part="sangue",
        pal=dict(d=(150, 22, 28), m=(212, 42, 42), l=(255, 92, 80), h=(255, 182, 160))),
    "nevoa_espectral": dict(
        armas=["nevoa_espectral"], tam=(100, 65), cy=0.62, rx=0.44, ry=0.31, seed=19, part="rostos",
        pal=dict(d=(50, 110, 150), m=(90, 170, 205), l=(150, 220, 242), h=(222, 250, 255))),
}


# ---------------------------------------------------------------- tela
class Tela:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), dtype=np.uint8)

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x, :3] = c
            self.a[y, x, 3] = 255

    def tira(self, x, y):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = (1, 0, 0, 0)  # marca de buraco (limpa a nuvem por baixo)

    def img(self):
        return Image.fromarray(self.a, "RGBA")


def visivel(x, y, limiar):
    """Pontilhado em blocos de 2x2 (sem pixel solto): True se o pixel sobrevive ao esmaecer `limiar`."""
    return BAYER[(int(y) // 2) % 4, (int(x) // 2) % 4] >= limiar


# ---------------------------------------------------------------- corpo da nuvem
def criar_puffs(t, rng):
    w, h = t["tam"]
    cx, cy = w / 2, h * t["cy"]
    Rx, Ry = w * t["rx"], h * t["ry"]
    puffs = []
    k = 9 if w >= 110 else 8
    for i in range(k):
        a = TAU * i / k + rng.uniform(-0.25, 0.25)
        f = rng.uniform(0.62, 0.74)
        px, py = cx + Rx * f * math.cos(a), cy + Ry * f * math.sin(a)
        r = Rx * rng.uniform(0.27, 0.36)
        ry = r * (Ry / Rx) * rng.uniform(1.0, 1.25) * (1.15 if math.sin(a) < 0 else 1.0)
        puffs.append([px, py, r, ry])
    for i in range(3):
        a = TAU * i / 3 + rng.uniform(0, 1)
        puffs.append([cx + Rx * 0.22 * math.cos(a), cy + Ry * 0.2 * math.sin(a) - Ry * 0.1,
                      Rx * rng.uniform(0.3, 0.38), Ry * rng.uniform(0.42, 0.55)])
    for i in range(k + 3):  # fiapos pequenos na borda (borda irregular)
        a = TAU * (i + 0.5) / (k + 3) + rng.uniform(-0.2, 0.2)
        f = rng.uniform(0.9, 1.0)
        r = Rx * rng.uniform(0.09, 0.14)
        puffs.append([cx + Rx * f * math.cos(a), cy + Ry * f * math.sin(a), r, r * rng.uniform(0.55, 0.75)])
    out = []
    for px, py, r, ry in puffs:
        amp = rng.uniform(1.6, 2.8) * (w / 110) ** 0.5
        out.append(dict(x=px, y=py, rx=r, ry=ry, ax=amp, ay=amp * 0.55, ph=rng.random(),
                        c=rng.choice([1, -1]), pp=rng.random()))
    return out, (cx, cy, Rx, Ry)


def puffs_no_tempo(puffs, centro, tq, escala):
    cx, cy = centro[:2]
    res = []
    for p in puffs:
        ang = TAU * (p["c"] * tq + p["ph"])
        x = p["x"] + p["ax"] * math.cos(ang)
        y = p["y"] + p["ay"] * math.sin(ang)
        pul = 1.0 + 0.07 * math.sin(TAU * (tq + p["pp"]))
        x = cx + (x - cx) * escala
        y = cy + (y - cy) * escala
        res.append((x, y, p["rx"] * pul * escala ** 0.85, p["ry"] * pul * escala ** 0.85))
    return res


def desenhar_corpo(tela, t, ps, limiar_mask=1.0, esmaecer=0.0):
    w, h = tela.w, tela.h
    pal = t["pal"]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    F = np.zeros((h, w), np.float32)
    ds = []
    for (x, y, rx, ry) in ps:
        d2 = ((xx - x) / rx) ** 2 + ((yy - y) / ry) ** 2
        ds.append(d2)
        F += np.exp(-1.6 * d2)
    T = math.exp(-1.6) * limiar_mask
    M = F > T
    M[0, :] = M[-1, :] = False
    M[:, 0] = M[:, -1] = False

    def erode(A):
        B = A.copy()
        B[1:, :] &= A[:-1, :]
        B[:-1, :] &= A[1:, :]
        B[:, 1:] &= A[:, :-1]
        B[:, :-1] &= A[:, 1:]
        return B
    # contorno = pixel da nuvem com vizinho de fora (4-vizinhança)
    E = erode(M)
    rim = M & ~E
    gy, gx = np.gradient(F)
    # normal para fora = -grad; luz de cima à esquerda
    nx, ny = -gx, -gy
    nn = np.sqrt(nx * nx + ny * ny) + 1e-6
    luz = ((nx / nn) * -0.6 + (ny / nn) * -0.8) > 0.35
    # profundidade (camadas de erosão): o pontilhado é mais denso perto da borda e some no miolo
    prof = np.zeros((h, w), np.int32)
    A = E
    for i in range(1, 9):
        prof[A] = i
        A = erode(A)
    E2 = prof >= 2
    dens = np.select([prof == 1, prof <= 3, prof <= 5, prof <= 7], [0.5, 0.31, 0.19, 0.1], 0.04)
    bay = BAYER[yy.astype(int) % 4, ((xx.astype(int) // 2) + (yy.astype(int) // 4)) % 4]
    miolo = E & (bay < dens)
    a = tela.a

    def pinta(mask, c):
        if esmaecer > 0:  # dissolve em blocos 2x2 (depois de achar contorno e miolo)
            mask = mask & (BAYER[(yy.astype(int) // 2) % 4, (xx.astype(int) // 2) % 4] >= esmaecer)
        a[mask, 0], a[mask, 1], a[mask, 2], a[mask, 3] = c[0], c[1], c[2], 255
    pinta(miolo, pal["d"])
    # dobras: arco de cima de cada puff grande, escondido pelos puffs que estão na frente (y maior)
    ordem = sorted(range(len(ps)), key=lambda i: ps[i][1])
    for i in ordem:
        x, y, rx, ry = ps[i]
        if rx < 0.18 * w * t["rx"]:
            continue
        d2 = ds[i]
        dentro = d2 <= 1.0
        borda = dentro.copy()
        fora = d2 > 1.0
        nb = np.zeros_like(dentro)
        nb[1:, :] |= fora[:-1, :]
        nb[:-1, :] |= fora[1:, :]
        nb[:, 1:] |= fora[:, :-1]
        nb[:, :-1] |= fora[:, 1:]
        borda &= nb
        arco = borda & (yy < y - ry * 0.3) & (xx < x + rx * 0.3) & (xx > x - rx * 0.85) & E2
        for j in range(len(ps)):
            if j != i and ps[j][1] > y and ps[j][2] >= 0.18 * w * t["rx"]:
                arco &= ds[j] > 1.0
        pinta(arco, pal["l"])
    # contorno: claro no lado da luz, meio nos lados, e tracejado embaixo (a névoa se desfaz no chão)
    baixo = (ny / nn) > 0.55
    tracejo = ((xx.astype(int) // 2) % 3) != 2
    pinta(rim & luz, pal["l"])
    pinta(rim & ~luz & ~baixo, pal["m"])
    pinta(rim & baixo & tracejo, pal["m"])
    return M


# ---------------------------------------------------------------- partículas
def u_de(tq, ph):
    return (tq + ph) % 1.0


def part_bolhas(tela, t, est, tq, n, vis):
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        k = int(round(u_de(tq, p["ph"]) * n)) % n  # quadro da vida da bolha
        u = k / n
        x = p["x"] + 1.5 * math.sin(TAU * (u * 1.5 + p["ph2"]))
        y = p["y"] - p["sobe"] * u
        if k == n - 1:  # estoura
            r = p["r"] + 1
            for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                tela.put(x + sx * r, y + sy * r, pal["h"])
                tela.put(x + sx * (r + 1), y + sy * (r + 1), pal["l"])
            continue
        r = 1 + int(p["r"] * (k + 1) / (n - 1))
        r = min(r, p["r"])
        if r <= 1:
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                tela.put(x + dx, y + dy, pal["l"])
            tela.put(x, y, pal["h"])
        else:
            xi, yi = int(round(x)), int(round(y))
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    d = math.hypot(dx, dy)
                    if d <= r + 0.4:
                        if d > r - 0.6:
                            tela.put(xi + dx, yi + dy, pal["l"] if dx + dy <= 0 else pal["m"])
                        else:
                            tela.tira(xi + dx, yi + dy)  # bolha oca: destaca do pontilhado
            tela.put(xi - r + 1, yi - 1, pal["h"])
            tela.put(xi - r + 1, yi - 2 if r > 2 else yi - 1, pal["h"])
            tela.put(xi - 1, yi - r + 1, pal["h"])


def part_cristais(tela, t, est, tq, n, vis):
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        if p["tipo"] == "brilho":
            k = int(round(u_de(tq, p["ph"]) * n)) % n
            braco = [0, 1, 2, 1, 0, 0][k * 6 // n]
            if braco:
                tela.put(p["x"], p["y"], pal["h"])
                for i in range(1, braco + 1):
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        tela.put(p["x"] + dx * i, p["y"] + dy * i, pal["l"] if i == braco else pal["h"])
            continue
        th = TAU * u_de(tq, p["ph"])
        hw = int(round(3 * abs(math.cos(th)) + 0.2))
        lado = math.sin(th) >= 0
        x0 = int(round(p["x"]))
        y0 = int(round(p["y"] + 2 * math.sin(TAU * (tq + p["ph2"]))))
        hh = p["h"]
        larg = int(hh * 0.4)
        for j in range(hh):
            if j <= larg:
                f = j / max(1, larg)
            else:
                f = (hh - 1 - j) / max(1, hh - 1 - larg)
            ww = int(round(hw * f ** 0.7))
            for dx in range(-ww, ww + 1):
                if dx == 0:
                    c = pal["h"]
                elif (dx < 0) == lado:
                    c = pal["l"]
                else:
                    c = pal["m"]
                tela.put(x0 + dx, y0 + j - hh // 2, c)


def part_brasas(tela, t, est, tq, n, vis):
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        k = int(round(u_de(tq, p["ph"]) * n)) % n
        if p["tipo"] == "foco":  # ponto quente pulsando dentro da nuvem
            braco = p["seq"][k]
            x, y = p["x"], p["y"]
            tela.put(x, y, pal["b3"])
            for i in range(1, braco + 1):
                c = pal["b2"] if i == 1 else pal["b1"]
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    tela.put(x + dx * i, y + dy * i, c)
            if braco >= 2:
                for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                    tela.put(x + dx, y + dy, pal["b1"])
            continue
        u = k / n
        x = p["x"] + 2.5 * math.sin(TAU * (u + p["ph2"]))
        y = p["y"] - p["sobe"] * u
        if k == n - 1:
            tela.put(x, y, pal["b1"])
            tela.put(x + 1, y, pal["b1"])
        elif p["grande"]:
            tela.put(x, y, pal["b3"])
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                tela.put(x + dx, y + dy, pal["b2"] if dy <= 0 else pal["b1"])
        else:
            tela.put(x, y, pal["b2"])
            tela.put(x, y + 1, pal["b1"])


def part_espirais(tela, t, est, tq, n, vis):
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        k = int(round(u_de(tq, p["ph"]) * n)) % n
        u = k / n
        cx = p["x"] + 2 * math.sin(TAU * (u + p["ph2"]))
        cy = p["y"] - p["sobe"] * u
        rmax = 2.5 + p["r"] * (k + 1) / n
        rot = TAU * u * p["dir"] * 0.75
        pts = []
        voltas = 2.2 * math.pi
        m = 80
        for i in range(m + 1):
            th = voltas * i / m
            r = rmax * th / voltas
            a = th * p["dir"] + rot
            pts.append((int(round(cx + r * math.cos(a))), int(round(cy + 0.78 * r * math.sin(a)))))
        vistos = []
        for q in pts:
            if vistos and q == vistos[-1]:
                continue
            if q in vistos:
                continue
            # tira a quina: traço de 1 px limpo (sem degrau duplo)
            if len(vistos) >= 2 and max(abs(q[0] - vistos[-2][0]), abs(q[1] - vistos[-2][1])) <= 1:
                vistos[-1] = q
            else:
                vistos.append(q)
        ultimo = k == n - 1
        for i, (x, y) in enumerate(vistos):
            if ultimo and (i // 2) % 2 == 1:  # se desfazendo
                continue
            c = pal["h"] if i > 3 else pal["l"]
            tela.put(x, y, c)


def part_chuva(tela, t, est, tq, n, vis):
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        k = (int(round(tq * n)) + p["fase"]) % n
        gx, gy = p["x"], p["y"]
        if k <= 3:  # caindo
            yh = gy - p["queda"] + (p["queda"] - 3) * (k + 1) / 4.0
            yh = int(round(yh))
            for i, c in enumerate("hhlllmm"):
                tela.put(gx, yh - i, pal[c])
            tela.put(gx + 1, yh, pal["l"])  # gota com cabeça de 2 px
        elif k == 4:  # respingo
            tela.put(gx, gy, pal["h"])
            for s in (-1, 1):
                tela.put(gx + s, gy - 1, pal["l"])
                tela.put(gx + 2 * s, gy - 2, pal["l"])
        else:  # anel no chão
            for dx in (-4, -3, 3, 4):
                tela.put(gx + dx, gy, pal["m"])
            for dx in (-2, -1, 1, 2):
                tela.put(gx + dx, gy - 1, pal["m"])
                tela.put(gx + dx, gy + 1, pal["m"])


FLOCO_MAIS = [(0, 0), (1, 0), (2, 0), (-1, 0), (-2, 0), (0, 1), (0, 2), (0, -1), (0, -2)]
FLOCO_X = [(0, 0), (1, 1), (2, 2), (-1, -1), (-2, -2), (1, -1), (2, -2), (-1, 1), (-2, 2)]


def part_flocos(tela, t, est, tq, n, vis):
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        k = (int(round(tq * n)) + p["fase"]) % n
        ang = TAU * (k / n) * p["dir"] + p["ph2"]
        x = p["x"] + p["giro"] * math.cos(ang)
        y = p["y"] + p["queda"] * k / n + p["giro"] * 0.5 * math.sin(ang)
        cruz = (k + p["fase"]) % 2 == 0
        if p["tam"] == 2:  # floco de 6 pontas girando (eixo vertical + duas diagonais achatadas)
            base = math.pi / 2 + (k + p["fase"]) * (math.pi / 6) * p["dir"]
            tela.put(x, y, pal["h"])
            for j in range(6):
                a = base + j * math.pi / 3
                for i in (1, 2, 3):
                    c = pal["h"] if i == 1 else (pal["l"] if i == 2 else pal["m"])
                    tela.put(x + i * math.cos(a), y + i * math.sin(a), c)
        elif p["tam"] == 1:
            forma = FLOCO_MAIS[:1] + [(1, 0), (-1, 0), (0, 1), (0, -1)] if cruz else \
                [(0, 0), (1, 1), (-1, -1), (1, -1), (-1, 1)]
            for dx, dy in forma:
                tela.put(x + dx, y + dy, pal["h"] if (dx, dy) == (0, 0) else pal["l"])
        else:
            tela.put(x, y, pal["h"])
            tela.put(x + (1 if cruz else 0), y + (0 if cruz else 1), pal["l"])


def part_esporos(tela, t, est, tq, n, vis):
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        k = int(round(u_de(tq, p["ph"]) * n)) % n
        if p["tipo"] == "bola":  # bola de esporos balançando no talo
            dy = [0, -1, -2, -2, -1, 0][k * 6 // n]
            x, y = int(round(p["x"])), int(round(p["y"] + dy))
            for yy in range(1, 6):  # talo
                tela.put(x, y + 4 + yy, pal["m"] if yy < 4 else pal["d"])
            for dx in range(-4, 5):
                for dyy in range(-4, 5):
                    d = dx * dx + dyy * dyy
                    if d <= 17:
                        borda = d >= 10
                        if borda:
                            c = pal["l"] if (dx + dyy) <= 0 else pal["m"]
                        elif (dx + dyy + k) % 3 == 0:
                            c = pal["h"]
                        else:
                            continue
                        tela.put(x + dx, y + dyy, c)
            continue
        u = k / n
        x = p["x"] + 2.5 * math.sin(TAU * (u + p["ph2"]))
        y = p["y"] - p["sobe"] * u
        if k == n - 1:
            tela.put(x, y, pal["m"])
            tela.put(x + 1, y, pal["m"])
        elif p["grande"]:
            tela.put(x, y, pal["h"])
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                tela.put(x + dx, y + dy, pal["l"])
        else:
            if k % 2 == 0:
                tela.put(x, y, pal["h"])
                tela.put(x + 1, y, pal["l"])
            else:
                tela.put(x, y, pal["h"])
                tela.put(x, y + 1, pal["l"])


def part_sangue(tela, t, est, tq, n, vis):
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        k = (int(round(tq * n)) + p["fase"]) % n
        gx, gy = p["x"], p["y"]
        if k <= 3:
            yh = int(round(gy - p["queda"] + (p["queda"] - 2) * (k + 1) / 4.0))
            tela.put(gx, yh, pal["l"])
            tela.put(gx + 1, yh, pal["l"])
            tela.put(gx, yh - 1, pal["h"])
            tela.put(gx + 1, yh - 1, pal["l"])
            tela.put(gx, yh - 2, pal["m"])
            if k >= 1:
                tela.put(gx, yh - 3, pal["m"])
        elif k == 4:
            tela.put(gx, gy, pal["h"])
            tela.put(gx + 1, gy, pal["l"])
            tela.put(gx - 1, gy - 1, pal["l"])
            tela.put(gx + 2, gy - 1, pal["l"])
            tela.put(gx - 2, gy - 2, pal["m"])
            tela.put(gx + 3, gy - 2, pal["m"])
        else:
            for dx in (-2, -1, 2, 3):
                tela.put(gx + dx, gy, pal["m"])


def part_rostos(tela, t, est, tq, n, vis):
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        k = int(round(u_de(tq, p["ph"]) * n)) % n
        u = k / n
        fx = p["x"] + 1.5 * math.sin(TAU * (u + p["ph2"]))
        fy = p["y"] - p["sobe"] * u
        rx, ry = 5, 5 + (1 if k >= n // 2 else 0)  # o rosto se alonga enquanto sobe
        esm = {0: 0.5, n - 1: 0.5}.get(k, 0.0)  # nasce e some pontilhado
        x0, y0 = int(round(fx)), int(round(fy))

        def ponto(x, y, c):
            if visivel(x, y, esm):
                tela.put(x, y, c)
        # capuz: só o contorno de cima e dos lados (oco: os inimigos aparecem através)
        for dy in range(-ry, 2):
            for dx in range(-rx, rx + 1):
                d = (dx / (rx + 0.5)) ** 2 + (dy / (ry + 0.5)) ** 2
                if d > 1.0:
                    continue
                borda = (((abs(dx) + 1) / (rx + 0.5)) ** 2 + (dy / (ry + 0.5)) ** 2 > 1.0 or
                         (dx / (rx + 0.5)) ** 2 + ((abs(dy) + 1) / (ry + 0.5)) ** 2 > 1.0)
                if borda and not (dy == -ry and abs(dx) > 2):
                    ponto(x0 + dx, y0 + dy, pal["l"] if dy < -1 else pal["m"])
        # dois fiapos descendo dos lados, ondulando
        for s in (-1, 1):
            for j in range(2, 8):
                sx = int(round(1.2 * math.sin(TAU * (u + j / 6.0 + (0.25 if s > 0 else 0)) + p["ph2"] * TAU)))
                xx = x0 + s * (rx - (j - 2) // 2) + sx
                ponto(xx, y0 + j, pal["m"] if j < 6 else pal["d"])
        # olhos tristes (traço de 2 px inclinado) e boca que abre num lamento
        for s in (-1, 1):
            ex = x0 + s * 2
            ponto(ex, y0 - 2 + (0 if s < 0 else 0), pal["h"])
            ponto(ex, y0 - 1, pal["h"])
            ponto(ex + s, y0 - 3, pal["l"])
        boca = [0, 1, 2, 2, 1, 0][k * 6 // n]
        if boca == 0:
            ponto(x0, y0 + 1, pal["l"])
            ponto(x0, y0 + 2, pal["l"])
        else:
            hb = boca + 1
            for dy in range(hb + 1):
                for dx in (-1, 1):
                    ponto(x0 + (dx if dy not in (0, hb) else 0), y0 + 1 + dy, pal["l"])


PARTS = dict(bolhas=part_bolhas, cristais=part_cristais, brasas=part_brasas, espirais=part_espirais,
             chuva=part_chuva, flocos=part_flocos, esporos=part_esporos, sangue=part_sangue, rostos=part_rostos)


def ponto_na_nuvem(rng, centro, fx=0.85, fy=0.8):
    cx, cy, Rx, Ry = centro
    while True:
        a, r = rng.uniform(0, TAU), math.sqrt(rng.random())
        return cx + Rx * fx * r * math.cos(a), cy + Ry * fy * r * math.sin(a)


def criar_particulas(t, rng, centro, n):
    w, h = t["tam"]
    cx, cy, Rx, Ry = centro
    tipo = t["part"]
    est = []
    def fases(q):
        base = [i / q for i in range(q)]
        rng.shuffle(base)
        return [b + rng.uniform(-0.02, 0.02) for b in base]
    if tipo == "bolhas":
        for i, ph in enumerate(fases(9)):
            x, y = ponto_na_nuvem(rng, centro, 0.8, 0.6)
            est.append(dict(x=x, y=y + 2, ph=ph, ph2=rng.random(), sobe=rng.uniform(12, 18), r=rng.choice([3, 3, 4])))
    elif tipo == "cristais":
        for i, ph in enumerate(fases(6)):
            x, y = ponto_na_nuvem(rng, centro, 0.8, 0.5)
            est.append(dict(tipo="cristal", x=x, y=y - 3, ph=ph, ph2=rng.random(), h=rng.choice([9, 11, 13])))
        for ph in fases(6):
            x, y = ponto_na_nuvem(rng, centro, 0.95, 0.9)
            est.append(dict(tipo="brilho", x=x, y=y, ph=ph))
    elif tipo == "brasas":
        for i, ph in enumerate(fases(20)):
            a = TAU * (i + rng.uniform(0, 0.8)) / 20
            r = math.sqrt(rng.uniform(0.1, 1.0))
            x, y = cx + Rx * 0.85 * r * math.cos(a), cy + Ry * 0.7 * r * math.sin(a)
            est.append(dict(tipo="brasa", x=x, y=y + 4, ph=ph, ph2=rng.random(), sobe=rng.uniform(14, 22),
                            grande=rng.random() < 0.5))
        seqs = [[1, 2, 3, 2], [2, 3, 2, 1], [0, 1, 2, 1], [1, 2, 1, 0], [2, 1, 2, 3], [3, 2, 1, 2]]
        lugares = [(-0.6, 0.1), (-0.25, 0.45), (0.1, -0.15), (0.45, 0.35), (0.65, -0.1), (-0.05, 0.6)]
        for i, (fx, fy) in enumerate(lugares):
            est.append(dict(tipo="foco", x=int(cx + Rx * fx), y=int(cy + Ry * fy), ph=0.0, seq=seqs[i]))
    elif tipo == "espirais":
        for i, ph in enumerate(fases(6)):
            x = cx + Rx * (-0.72 + 1.44 * i / 5) + rng.uniform(-3, 3)
            y = cy + Ry * rng.uniform(-0.05, 0.45)
            est.append(dict(x=x, y=y, ph=ph, ph2=rng.random(), sobe=rng.uniform(9, 13), r=rng.uniform(3.5, 4.5),
                            dir=rng.choice([1, -1])))
    elif tipo == "chuva":
        q = 21
        for i in range(q):
            x, y = ponto_na_nuvem(rng, centro, 0.9, 0.75)
            est.append(dict(x=int(x), y=int(y), fase=i % n, queda=int(rng.uniform(34, 52))))
    elif tipo == "flocos":
        for i in range(16):
            x, y = ponto_na_nuvem(rng, centro, 0.95, 0.85)
            tam = 2 if i < 5 else (1 if i < 11 else 0)
            est.append(dict(x=x, y=y - 8, fase=i % n, ph2=rng.uniform(0, TAU), dir=rng.choice([1, -1]),
                            giro=rng.uniform(2.5, 4.5), queda=rng.uniform(10, 16), tam=tam))
    elif tipo == "esporos":
        for ph in fases(14):
            x, y = ponto_na_nuvem(rng, centro, 0.9, 0.7)
            est.append(dict(tipo="esporo", x=x, y=y + 2, ph=ph, ph2=rng.random(), sobe=rng.uniform(8, 13),
                            grande=rng.random() < 0.4))
        for i, ph in enumerate([0.0, 1 / 3, 2 / 3]):
            x = cx + Rx * (-0.5 + 0.5 * i) + rng.uniform(-4, 4)
            y = cy - Ry * 0.15 + rng.uniform(-3, 3)
            est.append(dict(tipo="bola", x=x, y=y, ph=ph))
    elif tipo == "sangue":
        for i in range(10):
            x = cx + Rx * (-0.8 + 1.6 * i / 9) + rng.uniform(-2, 2)
            y = cy + Ry * rng.uniform(-0.4, 0.6)
            est.append(dict(x=int(x), y=int(y), fase=(i * 5) % n, queda=int(rng.uniform(18, 28))))
    elif tipo == "rostos":
        for i, ph in enumerate([0.0, 1 / 3, 2 / 3]):
            x = cx + Rx * (-0.48 + 0.48 * i) + rng.uniform(-3, 3)
            y = cy - Ry * 0.1 + rng.uniform(-2, 2)
            est.append(dict(x=x, y=y, ph=ph + rng.uniform(-0.03, 0.03), ph2=rng.random(), sobe=6))
    for i, p in enumerate(est):
        p["ordem"] = rng.random()
    return est


# ---------------------------------------------------------------- quadros
def quadro(t, puffs, centro, est, n, tq, escala=1.0, limiar=1.0, esm=0.0, frac=1.0):
    w, h = t["tam"]
    tela = Tela(w, h)
    ps = puffs_no_tempo(puffs, centro, tq, escala)
    desenhar_corpo(tela, t, ps, limiar, esm)
    cx, cy = centro[:2]
    def vis(p):
        if p["ordem"] >= frac:
            return False
        if esm > 0 and p["ordem"] < esm - 0.25:  # na saída as partículas somem aos poucos
            return False
        if escala < 1.0:  # na entrada, só o que já cabe na nuvem
            return (((p["x"] - cx) / (centro[2] * escala)) ** 2 +
                    ((p["y"] - cy) / (centro[3] * escala)) ** 2) <= 0.8
        return True
    camada = Tela(w, h)
    PARTS[t["part"]](camada, t, est, tq, n, vis)
    # halo de 1 px vazio em volta das partículas: elas se destacam do pontilhado da nuvem
    pm = camada.a[..., 3] > 0
    tirado = (camada.a[..., 3] == 0) & (camada.a[..., 0] == 1)
    p = np.pad(pm, 1)
    halo = np.zeros_like(pm)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            halo |= p[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
    tela.a[halo & ~pm] = 0
    tela.a[tirado] = 0
    tela.a[pm] = camada.a[pm]
    # limpa pixel solto (sem vizinho nenhum) que o halo ou o pontilhado deixaram
    m = tela.a[..., 3] > 0
    q = np.pad(m, 1)
    viz = np.zeros(m.shape, np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx or dy:
                viz += q[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
    tela.a[m & (viz == 0)] = 0
    return tela.img()


def gerar_tema(nome, t):
    rng = random.Random(t["seed"])
    w, h = t["tam"]
    n = 4 if w > 130 else 6
    puffs, centro = criar_puffs(t, rng)
    est = criar_particulas(t, rng, centro, n)
    loop = [quadro(t, puffs, centro, est, n, i / n) for i in range(n)]
    entrada = [quadro(t, puffs, centro, est, n, (k - 3) / n, escala=e, frac=f)
               for k, (e, f) in enumerate(((0.38, 0.25), (0.66, 0.55), (0.88, 0.85)))]
    saida = [quadro(t, puffs, centro, est, n, (k + 1) / n, escala=1.0 + 0.06 * (k + 1), limiar=l, esm=e)
             for k, (l, e) in enumerate(((1.6, 0.25), (2.6, 0.5), (4.0, 0.75)))]
    return dict(entrada=entrada, loop=loop, saida=saida), n


def tira(quadros):
    w, h = quadros[0].size
    im = Image.new("RGBA", (w * len(quadros), h), (0, 0, 0, 0))
    for i, q in enumerate(quadros):
        im.paste(q, (i * w, 0))
    return im


def previa(nome, anims, fps):
    quadros, dur = [], []
    seq = [("entrada", 1), ("loop", 2), ("saida", 1)]
    for anim, voltas in seq:
        for _ in range(voltas):
            for q in anims[anim]:
                big = q.resize((q.size[0] * 4, q.size[1] * 4), Image.NEAREST)
                fundo = Image.new("RGBA", big.size, FUNDO_PREVIA + (255,))
                fundo.alpha_composite(big)
                quadros.append(fundo.convert("RGB"))
                dur.append(int(round(1000 / fps[anim])))
    vazio = Image.new("RGB", quadros[0].size, FUNDO_PREVIA)
    quadros.append(vazio)
    dur.append(500)
    quadros[0].save(os.path.join(PREVIAS, nome + ".gif"), save_all=True, append_images=quadros[1:],
                    duration=dur, loop=0, disposal=1, optimize=False)


# ---------------------------------------------------------------- verificador
def diff(a, b):
    a, b = np.array(a), np.array(b)
    return int(np.any(a != b, axis=2).sum())


def isolados(img):
    a = np.array(img)
    m = a[..., 3] > 0
    p = np.pad(m, 1)
    viz = np.zeros_like(m, dtype=int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx or dy:
                viz += p[1 + dy:1 + dy + m.shape[0], 1 + dx:1 + dx + m.shape[1]]
    return int((m & (viz == 0)).sum())


def verificar(indice):
    erros = []
    for nome, f in indice["folhas"].items():
        for anim, d in f["anims"].items():
            im = Image.open(os.path.join(SAIDA, d["arquivo"]))
            qw, qh = d["quadro"]
            if im.size != (qw * d["n"], qh) or im.mode != "RGBA":
                erros.append(f"{d['arquivo']}: tamanho/modo {im.size} {im.mode}")
                continue
            a = np.array(im)
            alfas = set(np.unique(a[..., 3]).tolist())
            if not alfas <= {0, 255}:
                erros.append(f"{d['arquivo']}: alfa fora de 0/255 {sorted(alfas)[:5]}")
            qs = [im.crop((i * qw, 0, (i + 1) * qw, qh)) for i in range(d["n"])]
            difs = [diff(qs[i], qs[i + 1]) for i in range(d["n"] - 1)]
            cheios = [int((np.array(q)[..., 3] > 0).sum()) for q in qs]
            for i, df in enumerate(difs):
                if df < 0.12 * max(cheios[i], cheios[i + 1]):
                    erros.append(f"{d['arquivo']}: quadros {i} e {i + 1} quase iguais ({df} px)")
            iso = sum(isolados(q) for q in qs)
            linha = f"  {d['arquivo']:<34} difs={difs}"
            if d["loop"]:
                emenda = diff(qs[-1], qs[0])
                linha += f" emenda={emenda}"
                if emenda == 0 or emenda > 1.35 * max(difs):
                    erros.append(f"{d['arquivo']}: emenda do loop {emenda} vs passos {difs}")
            linha += f" isolados={iso}"
            print(linha)
    return erros


def main():
    os.makedirs(SAIDA, exist_ok=True)
    os.makedirs(PREVIAS, exist_ok=True)
    fps = dict(entrada=10, loop=6, saida=10)
    indice = {"folhas": {}}
    for nome, t in TEMAS.items():
        anims, n = gerar_tema(nome, t)
        w, h = t["tam"]
        ent = {}
        for anim in ("entrada", "loop", "saida"):
            arq = f"{nome}_{anim}.png"
            tira(anims[anim]).save(os.path.join(SAIDA, arq))
            ent[anim] = {"arquivo": arq, "quadro": [w, h], "n": len(anims[anim]), "fps": fps[anim],
                         "loop": anim == "loop", "ancora": [w // 2, h // 2]}
        indice["folhas"][nome] = {"armas": t["armas"], "anims": ent}
        previa(nome, anims, fps)
    with open(os.path.join(SAIDA, "indice_nuvens.json"), "w", encoding="utf-8") as fh:
        json.dump(indice, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    erros = verificar(indice)
    if erros:
        print("ERROS:")
        for e in erros:
            print("  " + e)
        raise SystemExit(1)
    print("ok: folhas verificadas")


if __name__ == "__main__":
    main()

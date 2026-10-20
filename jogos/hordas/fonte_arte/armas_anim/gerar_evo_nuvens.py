"""Gera as folhas animadas das nuvens evoluídas da v2 (grupo "evo_nuvens").

Contrato: docs/combate_v2/SPEC_ARTE.md. Para cada evolução saem três tiras horizontais em
jogos/hordas/projeto/assets/v2/armas_anim/<id>_<anim>.png:
  entrada 3q 10 fps, loop 4q 6 fps (6q se a célula tem até 130 px de largura; o último emenda no
  primeiro), saida 3q 10 fps. Mais o índice indice_evo_nuvens.json e as prévias GIF 4x em
  docs/combate_v2/previas/<id>.gif.

Mesmo esquema das nuvens base (gerar_nuvens.py, de onde vêm o corpo de puffs, a tela, as prévias e o
verificador): contorno de 1 px claro do lado da luz, miolo em pontilhado ralo, alfa só 0/255, partículas
com halo vazio e fase fechada no ciclo. As evoluções são mais imponentes (puffs em torre no alto) e têm
mais movimento por dentro:
  nevasca_congelante  cristais grandes girando, flocos de 6 pontas e rajadas de vento atravessando
  cinzas_acidas       cinza verde-oliva com brasas subindo e gotas ácidas pingando e respingando
  peste_negra         corpo roxo, fiapos verdes ondulando para cima, bolhas de esporo e moscas em oito
  furacao_glacial     turbilhão de 4 braços em espiral girando, com riscos que correm para o olho e
                      lascas de gelo levadas pelos braços

Rodar: python -I gerar_evo_nuvens.py  (semente fixa, sem rede; rodar de novo dá as mesmas folhas)
"""
import importlib.util
import json
import math
import os
import random

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("gerar_nuvens", os.path.join(AQUI, "gerar_nuvens.py"))
gn = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gn)

SAIDA, BAYER, TAU = gn.SAIDA, gn.BAYER, gn.TAU

VERDE = dict(m=(120, 196, 40), l=(176, 236, 70), h=(236, 255, 160))
GELO = dict(m=(110, 168, 238), l=(172, 214, 255), h=(240, 249, 255))

TEMAS = {
    "nevasca_congelante": dict(
        tam=(145, 114), cy=0.64, rx=0.45, ry=0.33, seed=31, corpo="puffs", torres=3,
        pal=dict(d=(70, 110, 180), m=(124, 168, 232), l=(186, 218, 255), h=(246, 251, 255))),
    "cinzas_acidas": dict(
        tam=(150, 130), cy=0.64, rx=0.45, ry=0.32, seed=32, corpo="puffs", torres=3,
        pal=dict(d=(104, 110, 76), m=(156, 162, 108), l=(204, 210, 148), h=(240, 242, 200),
                 b1=(255, 120, 30), b2=(255, 196, 60), b3=(255, 248, 196))),
    "peste_negra": dict(
        tam=(130, 121), cy=0.66, rx=0.45, ry=0.30, seed=33, corpo="puffs", torres=3,
        pal=dict(d=(96, 56, 150), m=(150, 96, 214), l=(202, 152, 248), h=(240, 218, 255))),
    "furacao_glacial": dict(
        tam=(160, 130), cy=0.51, rx=0.46, ry=0.45, seed=34, corpo="vortice", bracos=4, enrola=3.4,
        pal=dict(d=(70, 116, 186), m=(120, 170, 236), l=(182, 218, 255), h=(242, 249, 255))),
}


# ---------------------------------------------------------------- corpo: puffs com torres no alto
def criar_puffs_evo(t, rng):
    puffs, centro = gn.criar_puffs(t, rng)
    cx, cy, Rx, Ry = centro
    w = t["tam"][0]
    q = t["torres"]
    for i in range(q):  # torres: a nuvem cresce para cima (mais imponente que a base)
        x = cx + Rx * (-0.42 + 0.84 * i / (q - 1)) + rng.uniform(-4, 4)
        alto = 0.95 if i == q // 2 else rng.uniform(0.6, 0.75)
        amp = rng.uniform(1.8, 2.8) * (w / 110) ** 0.5
        puffs.append(dict(x=x, y=cy - Ry * alto, rx=Rx * rng.uniform(0.22, 0.27), ry=Ry * rng.uniform(0.5, 0.6),
                          ax=amp, ay=amp * 0.6, ph=rng.random(), c=rng.choice([1, -1]), pp=rng.random()))
    return puffs, centro


def corpo_puffs(tela, t, puffs, centro, tq, escala, limiar, esm):
    ps = gn.puffs_no_tempo(puffs, centro, tq, escala)
    gn.desenhar_corpo(tela, t, ps, limiar, esm)


# ---------------------------------------------------------------- corpo: vórtice
def erode(A):
    B = A.copy()
    B[1:, :] &= A[:-1, :]
    B[:-1, :] &= A[1:, :]
    B[:, 1:] &= A[:, :-1]
    B[:, :-1] &= A[:, 1:]
    return B


def corpo_vortice(tela, t, centro, tq, n, escala, limiar, esm):
    w, h = tela.w, tela.h
    pal = t["pal"]
    cx, cy, Rx, Ry = centro
    Rx, Ry = Rx * escala, Ry * escala
    k = t["bracos"]
    rot = TAU * tq / k
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx, ny = (xx + 0.5 - cx) / Rx, (yy + 0.5 - cy) / Ry
    r = np.sqrt(nx * nx + ny * ny)
    th = np.arctan2(ny, nx)
    band = 0.5 + 0.5 * np.cos(k * (th + t["enrola"] * r - rot))
    borda = 0.93 + 0.05 * np.cos(2 * k * (th - rot) + 1.0) + 0.03 * np.cos(3 * k * (th - rot) + 2.0)
    thr = 0.50 + 0.30 * np.clip(0.55 - r, 0, 1) + 0.12 * (limiar - 1)
    M = (band > thr) & (r < borda) & (r > 0.15)
    M[0, :] = M[-1, :] = M[:, 0] = M[:, -1] = False
    E = erode(M)
    rim = M & ~E
    luz = np.zeros_like(M)
    luz[1:, :] |= ~M[:-1, :]
    luz[:, 1:] |= ~M[:, :-1]
    luz &= rim
    prof = np.zeros((h, w), np.int32)
    A = E
    for i in range(1, 6):
        prof[A] = i
        A = erode(A)
    dens = np.select([prof == 1, prof <= 2, prof <= 4], [0.34, 0.19, 0.09], 0.04)
    bay = BAYER[yy.astype(int) % 4, ((xx.astype(int) // 2) + (yy.astype(int) // 4)) % 4]
    miolo = E & (bay < dens)
    # riscos na crista de cada braço, correndo para o olho (2 px por quadro, período 8 = 4 quadros)
    rho = (r * Rx).astype(np.int32)
    f = int(round(tq * n))
    crista = E & (band > 0.975) & (((rho + 2 * f) % 8) < 5) & (r > 0.22)
    # fio de vento entre os braços (tracejado que corre para fora, ao contrário dos riscos)
    meio = 0.5 + 0.5 * np.cos(k * (th + t["enrola"] * r - rot) + math.pi)
    fio = (meio > 0.985) & (r > 0.3) & (r < borda - 0.04) & (((rho - 2 * f) % 8) < 4)
    a = tela.a

    def pinta(mask, c):
        if esm > 0:
            mask = mask & (BAYER[(yy.astype(int) // 2) % 4, (xx.astype(int) // 2) % 4] >= esm)
        a[mask, 0], a[mask, 1], a[mask, 2], a[mask, 3] = c[0], c[1], c[2], 255
    pinta(miolo, pal["d"])
    pinta(fio, pal["m"])
    pinta(crista & (r < 0.6), pal["h"])
    pinta(crista & (r >= 0.6), pal["l"])
    pinta(rim & luz, pal["l"])
    pinta(rim & ~luz, pal["m"])


# ---------------------------------------------------------------- partículas novas
def part_vento(tela, t, est, tq, n, vis):
    """Rajada: risco inclinado que atravessa a nevasca, cresce, corre e se desfaz."""
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        k = (int(round(tq * n)) + p["fase"]) % n
        u = k / n
        x = p["x"] + p["dist"] * u
        y = p["y"] + p["dist"] * 0.3 * u
        comp = [6, 12, 16, 10][k * 4 // n]
        for j in range(comp):
            if k == n - 1 and (j // 2) % 2 == 1:
                continue
            c = pal["h"] if j < 4 else (pal["l"] if j < comp * 0.75 else pal["m"])
            tela.put(x - j, y - (j + 1) // 3, c)


def part_cristal_grande(tela, t, est, tq, n, vis):
    """Cristal de gelo grande girando no eixo vertical (a largura abre e fecha) e boiando."""
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        th = TAU * ((tq + p["ph"]) % 1.0)
        hw = max(1, int(round(p["hw"] * abs(math.cos(th)) + 0.3)))
        lado = math.sin(th) >= 0
        x0 = int(round(p["x"]))
        y0 = int(round(p["y"] + 2 * math.sin(TAU * (tq + p["ph2"]))))
        hh = p["h"]
        larg = int(hh * 0.38)
        for j in range(hh):
            f = j / max(1, larg) if j <= larg else (hh - 1 - j) / max(1, hh - 1 - larg)
            ww = int(round(hw * f ** 0.7))
            for dx in range(-ww, ww + 1):
                if dx == 0:
                    c = pal["h"]
                elif (dx < 0) == lado:
                    c = pal["l"]
                else:
                    c = pal["m"]
                tela.put(x0 + dx, y0 + j - hh // 2, c)


def part_gotas(tela, t, est, tq, n, vis):
    """Gota ácida: pinga da nuvem com um fio atrás, cai e respinga no chão."""
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        k = (int(round(tq * n)) + p["fase"]) % n
        gx, gy = int(p["x"]), int(p["y"])
        if k < n - 1:
            yh = int(round(gy - p["queda"] + p["queda"] * (k + 0.5) / (n - 1)))
            fio = 4 + 4 * k
            for i in range(fio):
                tela.put(gx, yh - 4 - i, pal["m"] if i > 2 else pal["l"])
            tela.put(gx, yh - 3, pal["l"])
            for dx in (-1, 0, 1):
                tela.put(gx + dx, yh - 2, pal["l"] if dx else pal["h"])
                tela.put(gx + dx, yh - 1, pal["h"] if dx < 1 else pal["l"])
                tela.put(gx + dx, yh, pal["l"] if dx < 1 else pal["m"])
            tela.put(gx, yh + 1, pal["m"])
        else:
            tela.put(gx, gy, pal["h"])
            tela.put(gx + 1, gy, pal["l"])
            for s in (-1, 1):
                tela.put(gx + (2 if s > 0 else -1), gy - 1, pal["l"])
                tela.put(gx + (3 if s > 0 else -2), gy - 2, pal["h"])
            for dx in (-4, -3, 4, 5):
                tela.put(gx + dx, gy + 1, pal["m"])


def part_fiapos(tela, t, est, tq, n, vis):
    """Fiapo de peste: linha verde que ondula subindo (a onda anda um comprimento por ciclo)."""
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        H = int(round(p["H"] * min(1.0, t["escala"]) * (0.86+ 0.14 * math.sin(TAU * (tq + p["ph"])))))
        x0, y0 = p["x"], int(p["y"])
        xa = None
        for j in range(H + 1):
            amp = p["A"] * (0.35 + 0.65 * j / H)
            x = int(round(x0 + amp * math.sin(TAU * (j / p["lam"] - tq - p["ph"]))))
            c = pal["m"] if j < H * 0.35 else (pal["l"] if j < H * 0.75 else pal["h"])
            xs = [x] if xa is None or abs(x - xa) <= 1 else range(min(x, xa) + 1, max(x, xa) + 1)
            for xi in xs:
                tela.put(xi, y0 - j, c)
            if j < H * 0.5:
                tela.put(x + 1, y0 - j, c)
            xa = x
        # bolinha que se solta da ponta e sobe
        u = (tq + p["ph"]) % 1.0
        by = y0 - H - 3 - int(round(7 * u))
        bx = int(round(x0 + p["A"] * math.sin(TAU * (H / p["lam"] - tq - p["ph"]))))
        tela.put(bx, by, pal["h"])
        tela.put(bx + 1, by, pal["l"])
        if u < 0.6:
            tela.put(bx, by + 1, pal["l"])
            tela.put(bx + 1, by + 1, pal["m"])


def part_moscas(tela, t, est, tq, n, vis):
    """Mosca: ponto claro voando em oito, com asa que bate (em V / reta)."""
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        a = TAU * (2 * tq + p["ph"]) * p["dir"]
        x = int(round(p["x"] + p["rx"] * math.cos(a)))
        y = int(round(p["y"] + p["ry"] * math.sin(2 * a)))
        k = int(round(tq * n)) + p["fase"]
        tela.put(x, y, pal["h"])
        if k % 2 == 0:
            tela.put(x - 1, y - 1, pal["l"])
            tela.put(x + 1, y - 1, pal["l"])
        else:
            tela.put(x - 1, y, pal["l"])
            tela.put(x + 1, y, pal["l"])


def part_lascas(tela, t, est, tq, n, vis):
    """Lasca de gelo levada pelo braço do turbilhão (losango alongado na direção do giro)."""
    pal = t["pal"]
    cx, cy, Rx, Ry = t["centro"]
    e = t["escala"]
    rot = TAU * tq / t["bracos"]
    lx, ly = -0.6, -0.8
    for p in est:
        if not vis(p):
            continue
        a = p["a"] + rot
        rr = p["r"] * e
        px, py = cx + rr * Rx * math.cos(a), cy + rr * Ry * math.sin(a)
        dx, dy = -Rx * math.sin(a), Ry * math.cos(a)
        dn = math.hypot(dx, dy)
        dx, dy = dx / dn - 0.3 * math.cos(a), dy / dn - 0.3 * math.sin(a)
        dn = math.hypot(dx, dy)
        dx, dy = dx / dn, dy / dn
        qx, qy = -dy, dx
        claro = (qx * lx + qy * ly) > 0
        L, W = p["L"] * e ** 0.5, p["W"]
        R = int(L) + 2
        for yy in range(-R, R + 1):
            for xx in range(-R, R + 1):
                ox, oy = xx + 0.5 - (px % 1), yy + 0.5 - (py % 1)
                uu, vv = ox * dx + oy * dy, ox * qx + oy * qy
                if abs(uu) / L + abs(vv) / W > 1.0:
                    continue
                if abs(vv) < 0.55:
                    c = pal["h"]
                elif (vv > 0) == claro:
                    c = pal["l"]
                else:
                    c = pal["m"]
                tela.put(int(px) + xx, int(py) + yy, c)


def part_brilhos(tela, t, est, tq, n, vis):
    pal = t["pal"]
    for p in est:
        if not vis(p):
            continue
        k = (int(round(tq * n)) + p["fase"]) % n
        braco = p["seq"][k]
        tela.put(p["x"], p["y"], pal["h"])
        for i in range(1, braco + 1):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                tela.put(p["x"] + dx * i, p["y"] + dy * i, pal["l"] if i == braco else pal["h"])
        if braco == 0:
            tela.put(p["x"] + 1, p["y"], pal["l"])


# ---------------------------------------------------------------- partículas de cada tema
def fases(rng, q):
    base = [i / q for i in range(q)]
    rng.shuffle(base)
    return [b + rng.uniform(-0.02, 0.02) for b in base]


def criar_partes(nome, t, rng, centro, n):
    cx, cy, Rx, Ry = centro
    w, h = t["tam"]
    pn = gn.ponto_na_nuvem
    partes = []
    if nome == "nevasca_congelante":
        cg = []
        for i, ph in enumerate(fases(rng, 6)):
            x = cx + Rx * (-0.78 + 1.56 * i / 5) + rng.uniform(-4, 4)
            y = cy - Ry * rng.uniform(0.0, 1.1)
            cg.append(dict(x=x, y=y, ph=ph, ph2=rng.random(), h=[17, 21, 19, 23, 18, 20][i], hw=rng.choice([3, 4, 4])))
        cr = []
        for ph in fases(rng, 8):
            x, y = pn(rng, centro, 1.0, 1.3)
            cr.append(dict(tipo="brilho", x=x, y=y - 6, ph=ph))
        fl = []
        for i in range(12):
            x, y = pn(rng, centro, 0.95, 0.9)
            fl.append(dict(x=x, y=y - 10, fase=i % n, ph2=rng.uniform(0, TAU), dir=rng.choice([1, -1]),
                           giro=rng.uniform(2.5, 4.5), queda=rng.uniform(10, 16), tam=2 if i < 5 else (1 if i < 9 else 0)))
        ve = []
        for i in range(12):
            x, y = pn(rng, centro, 0.85, 1.0)
            ve.append(dict(x=x - 12, y=y - 6, fase=i % n, dist=rng.uniform(26, 34)))
        partes = [(part_vento, None, ve), (gn.part_flocos, None, fl), (gn.part_cristais, None, cr),
                  (part_cristal_grande, None, cg)]
    elif nome == "cinzas_acidas":
        br = []
        for i, ph in enumerate(fases(rng, 18)):
            a = TAU * (i + rng.uniform(0, 0.8)) / 18
            r = math.sqrt(rng.uniform(0.1, 1.0))
            br.append(dict(tipo="brasa", x=cx + Rx * 0.85 * r * math.cos(a), y=cy + Ry * 0.8 * r * math.sin(a),
                           ph=ph, ph2=rng.random(), sobe=rng.uniform(16, 26), grande=rng.random() < 0.5))
        seqs = [[1, 2, 3, 2], [2, 3, 2, 1], [0, 1, 2, 1], [1, 2, 1, 0], [2, 1, 2, 3], [3, 2, 1, 2], [1, 0, 1, 2]]
        lugares = [(-0.6, 0.1), (-0.25, 0.5), (0.1, -0.3), (0.45, 0.35), (0.68, -0.1), (-0.05, 0.75), (-0.3, -0.8)]
        for i, (fx, fy) in enumerate(lugares):
            br.append(dict(tipo="foco", x=int(cx + Rx * fx), y=int(cy + Ry * fy), ph=0.0, seq=seqs[i]))
        go = []
        for i in range(11):
            x = cx + Rx * (-0.8 + 1.6 * i / 10) + rng.uniform(-3, 3)
            y = cy + Ry * rng.uniform(0.25, 0.8)
            go.append(dict(x=x, y=y, fase=(i * 3) % n, queda=int(rng.uniform(22, 34))))
        partes = [(gn.part_brasas, None, br), (part_gotas, VERDE, go)]
    elif nome == "peste_negra":
        fi = []
        bases = [(-0.78, 0.35, 24), (-0.45, 0.75, 40), (-0.2, -0.1, 30), (0.08, 0.55, 44), (0.35, 0.0, 26),
                 (0.55, 0.65, 36), (0.8, 0.25, 22)]
        for i, ph in enumerate(fases(rng, 7)):
            fx, fy, H = bases[i]
            fi.append(dict(x=cx + Rx * fx + rng.uniform(-2, 2), y=cy + Ry * fy, ph=ph, H=H + rng.uniform(-3, 3),
                           A=rng.uniform(2.0, 3.4), lam=rng.uniform(10, 15)))
        bo = []
        for ph in fases(rng, 6):
            x, y = pn(rng, centro, 0.8, 0.7)
            bo.append(dict(x=x, y=y - 4, ph=ph, ph2=rng.random(), sobe=rng.uniform(14, 20), r=rng.choice([2, 3, 3])))
        mo = []
        for i in range(10):
            x, y = pn(rng, centro, 1.0, 1.25)
            mo.append(dict(x=x, y=y - 12, ph=rng.random(), dir=rng.choice([1, -1]), rx=rng.uniform(4, 7),
                           ry=rng.uniform(2, 4), fase=i % 2))
        mpal = dict(l=(206, 190, 236), h=(246, 240, 255), m=(170, 140, 220))
        partes = [(part_fiapos, VERDE, fi), (gn.part_bolhas, VERDE, bo), (part_moscas, mpal, mo)]
    elif nome == "furacao_glacial":
        k = t["bracos"]
        la = []
        for g in range(4):
            r = 0.32 + 0.6 * g / 3 + rng.uniform(-0.03, 0.03)
            a0 = -t["enrola"] * r + rng.uniform(-0.25, 0.25)  # em cima da crista do braço
            L, W = rng.uniform(4, 6) + 4 * r, rng.uniform(1.9, 2.5)
            for j in range(k):
                a = a0 + TAU * j / k
                la.append(dict(r=r, a=a, L=L, W=W, x=cx + r * Rx * math.cos(a), y=cy + r * Ry * math.sin(a)))
        bl = []
        cantos = [(0.06, 0.12), (0.92, 0.1), (0.05, 0.86), (0.94, 0.88), (0.5, 0.03), (0.2, 0.5), (0.8, 0.52),
                  (0.3, 0.96)]
        seqs = [[0, 1, 2, 1], [1, 2, 1, 0], [2, 1, 0, 1], [1, 0, 1, 2]]
        for i, (fx, fy) in enumerate(cantos):
            bl.append(dict(x=int(fx * w), y=int(fy * h), fase=i % n, seq=seqs[i % 4]))
        partes = [(part_brilhos, GELO, bl), (part_lascas, GELO, la)]
    for _, _, est in partes:
        for p in est:
            p["ordem"] = rng.random()
    return partes


# ---------------------------------------------------------------- quadros
def quadro(nome, t, corpo, centro, partes, n, tq, escala=1.0, limiar=1.0, esm=0.0, frac=1.0):
    w, h = t["tam"]
    tela = gn.Tela(w, h)
    if t["corpo"] == "vortice":
        corpo_vortice(tela, t, centro, tq, n, escala, limiar, esm)
    else:
        corpo_puffs(tela, t, corpo, centro, tq, escala, limiar, esm)
    cx, cy = centro[:2]

    def vis(p):
        if p["ordem"] >= frac:
            return False
        if esm > 0 and p["ordem"] < esm - 0.25:
            return False
        if escala < 1.0:
            return (((p["x"] - cx) / (centro[2] * escala)) ** 2 + ((p["y"] - cy) / (centro[3] * escala)) ** 2) <= 0.8
        return True
    camada = gn.Tela(w, h)
    for fn, pal, est in partes:
        tp = dict(t, escala=escala, centro=centro)
        if pal:
            tp["pal"] = dict(t["pal"], **pal)
        fn(camada, tp, est, tq, n, vis)
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
    if t["corpo"] == "vortice":
        corpo, centro = None, (w / 2, h * t["cy"], w * t["rx"], h * t["ry"])
    else:
        corpo, centro = criar_puffs_evo(t, rng)
    partes = criar_partes(nome, t, rng, centro, n)
    loop = [quadro(nome, t, corpo, centro, partes, n, i / n) for i in range(n)]
    entrada = [quadro(nome, t, corpo, centro, partes, n, (k - 3) / n, escala=e, frac=f)
               for k, (e, f) in enumerate(((0.38, 0.25), (0.66, 0.55), (0.88, 0.85)))]
    saida = [quadro(nome, t, corpo, centro, partes, n, (k + 1) / n, escala=1.0 + 0.06 * (k + 1), limiar=l, esm=e)
             for k, (l, e) in enumerate(((1.6, 0.25), (2.6, 0.5), (4.0, 0.75)))]
    return dict(entrada=entrada, loop=loop, saida=saida)


def main():
    os.makedirs(SAIDA, exist_ok=True)
    os.makedirs(gn.PREVIAS, exist_ok=True)
    fps = dict(entrada=10, loop=6, saida=10)
    indice = {"folhas": {}}
    for nome, t in TEMAS.items():
        anims = gerar_tema(nome, t)
        w, h = t["tam"]
        ent = {}
        for anim in ("entrada", "loop", "saida"):
            arq = f"{nome}_{anim}.png"
            gn.tira(anims[anim]).save(os.path.join(SAIDA, arq))
            ent[anim] = {"arquivo": arq, "quadro": [w, h], "n": len(anims[anim]), "fps": fps[anim],
                         "loop": anim == "loop", "ancora": [w // 2, h // 2]}
        indice["folhas"][nome] = {"armas": [nome], "anims": ent}
        gn.previa(nome, anims, fps)
    with open(os.path.join(SAIDA, "indice_evo_nuvens.json"), "w", encoding="utf-8") as fh:
        json.dump(indice, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    erros = gn.verificar(indice)
    if erros:
        print("ERROS:")
        for e in erros:
            print("  " + e)
        raise SystemExit(1)
    print("ok: folhas verificadas")


if __name__ == "__main__":
    main()

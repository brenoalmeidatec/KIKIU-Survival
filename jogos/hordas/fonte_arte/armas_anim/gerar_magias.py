#!/usr/bin/env python3
"""Gera as folhas animadas do grupo "magias" da v2.

Sprites (contrato: docs/combate_v2/SPEC_ARTE.md):
  corvos, revoada_de_trovoes  voo 6q 12fps loop e bicada 4q 14fps loop, 36x30, vista de lado para a direita,
                              contorno escuro, mistura normal (luz so de cima: nada quebra no espelho)
  runa, circulo_runico        armar 4q 6fps, loop 4q 6fps loop, explosao 6q 15fps; glifo achatado no chao, aditivo
  raio                        impacto 4q 20fps, 32x32, aditivo
  ventania                    voo 4q 12fps loop, 64x32, aditivo
  onda                        voo 4q 12fps loop, 48x28, aditivo
  fura                        voo 4q 12fps loop, 40x10, ponta em (30, 5), aditivo

Pixel art de verdade: alfa so 0/255, esmaecer = pontilhado em tracos 2x1, poucos tons, sem pixel solto (so as
faiscas declaradas podem ficar sozinhas). Semente fixa, sem rede.

Uso:  python -I gerar_magias.py            # gera tudo e confere
      python -I gerar_magias.py --conferir # so confere as folhas ja gravadas
Grava: jogos/hordas/projeto/assets/v2/armas_anim/<sprite>_<anim>.png e indice_magias.json
       docs/combate_v2/previas/<sprite>.gif (4x, vizinho mais proximo, fundo #2a2a30; os aditivos somados ao fundo)
"""
import json
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[4]
SAIDA = RAIZ / "jogos/hordas/projeto/assets/v2/armas_anim"
PREVIAS = RAIZ / "docs/combate_v2/previas"
SEMENTE = 20261019
FUNDO = (42, 42, 48)
PI = math.pi
TAU = 2 * PI
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])


# ================================================================ tela de indices de paleta

class Tela:
    def __init__(s, W, H):
        s.W, s.H = W, H
        s.idx = np.zeros((H, W), np.uint8)
        s.fa = np.zeros((H, W), bool)          # faiscas: podem ficar sozinhas
        ys, xs = np.mgrid[0:H, 0:W]
        s.xs, s.ys = xs, ys
        s.bayer = (BAYER[ys % 4, (xs // 2) % 4] + 0.5) / 16   # pontilhado em tracos de 2x1

    def mascara(s, desenho):
        im = Image.new("L", (s.W, s.H), 0)
        desenho(ImageDraw.Draw(im))
        return np.array(im) > 0

    def pinta(s, m, cor, dens=1.0, faisca=False, so_vazio=False):
        m = np.asarray(m, bool)
        if dens < 1.0:
            m = m & (s.bayer < dens)
        if so_vazio:
            m = m & (s.idx == 0)
        s.idx[m] = cor
        s.fa[m] = faisca

    def poli(s, pts, cor, dens=1.0, faisca=False, so_vazio=False):
        s.pinta(s.mascara(lambda d: d.polygon([tuple(p) for p in pts], fill=255)), cor, dens, faisca, so_vazio)

    def linha(s, pts, cor, dens=1.0, faisca=False, larg=1, so_vazio=False):
        s.pinta(s.mascara(lambda d: d.line([tuple(p) for p in pts], fill=255, width=larg)), cor, dens, faisca,
                so_vazio)

    def elipse(s, cx, cy, rx, ry, cor, larg=1, dens=1.0, faisca=False, cheia=False, so_vazio=False):
        cx, cy, rx, ry = round(cx), round(cy), max(round(rx), 1), max(round(ry), 1)
        bb = [cx - rx, cy - ry, cx + rx, cy + ry]
        if cheia:
            m = s.mascara(lambda d: d.ellipse(bb, fill=255))
        else:
            m = s.mascara(lambda d: d.ellipse(bb, outline=255, width=larg))
        s.pinta(m, cor, dens, faisca, so_vazio)

    def arco(s, cx, cy, rx, ry, a0, a1, cor, larg=1, dens=1.0):
        cx, cy, rx, ry = round(cx), round(cy), max(round(rx), 1), max(round(ry), 1)
        if a1 - a0 >= 360:
            return s.elipse(cx, cy, rx, ry, cor, larg, dens)
        s.pinta(s.mascara(lambda d: d.arc([cx - rx, cy - ry, cx + rx, cy + ry], a0, a1, fill=255, width=larg)),
                cor, dens)

    def px(s, x, y, cor, faisca=False):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < s.W and 0 <= y < s.H:
            s.idx[y, x] = cor
            s.fa[y, x] = faisca

    def estrela(s, x, y, r, c1, c2=None, faisca=True):
        """Brilho em cruz: miolo c1, pontas c2."""
        c2 = c2 or c1
        x, y = int(round(x)), int(round(y))
        s.px(x, y, c1, faisca)
        for o in range(1, r + 1):
            c = c1 if o <= r // 2 else c2
            for dx, dy in ((o, 0), (-o, 0), (0, o), (0, -o)):
                s.px(x + dx, y + dy, c, faisca)


def viz4(m):
    n = np.zeros_like(m)
    n[1:] |= m[:-1]
    n[:-1] |= m[1:]
    n[:, 1:] |= m[:, :-1]
    n[:, :-1] |= m[:, 1:]
    return n


def soltos(idx, fa=None):
    """Mascara dos pixels opacos sem vizinho (8) da mesma cor."""
    H, W = idx.shape
    pad = np.pad(idx, 1)
    mesmo = np.zeros((H, W), bool)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx or dy:
                mesmo |= pad[1 + dy:1 + dy + H, 1 + dx:1 + dx + W] == idx
    r = (idx > 0) & ~mesmo
    return r if fa is None else r & ~fa


def limpa(t, evita=()):
    """Sem pixel solto: vira a cor da maioria dos vizinhos (fora das cores em `evita`) ou some."""
    for _ in range(10):
        sol = soltos(t.idx, t.fa)
        if not sol.any():
            return
        pad = np.pad(t.idx, 1)
        novo = t.idx.copy()
        for y, x in zip(*np.nonzero(sol)):
            viz = np.delete(pad[y:y + 3, x:x + 3].flatten(), 4)
            op = viz[viz > 0]
            bons = op[~np.isin(op, evita)] if len(evita) else op
            if len(bons) == 0:
                bons = op
            novo[y, x] = 0 if len(bons) == 0 else np.bincount(bons).argmax()
        t.idx = novo
    for _ in range(4):   # o que ainda oscila (par de pixels soltos se trocando) some
        sol = soltos(t.idx, t.fa)
        if not sol.any():
            return
        t.idx[sol] = 0


def rgba(t, paleta):
    lut = np.zeros((256, 4), np.uint8)
    for i, c in enumerate(paleta, 1):
        lut[i] = (*c, 255)
    return lut[t.idx]


def caminho_parcial(pts, f):
    """Prefixo de comprimento f (0..1) de uma poligonal."""
    if f >= 1:
        return list(pts)
    seg = [math.dist(a, b) for a, b in zip(pts, pts[1:])]
    alvo = f * sum(seg)
    res = [pts[0]]
    for (a, b), L in zip(zip(pts, pts[1:]), seg):
        if alvo >= L:
            res.append(b)
            alvo -= L
        else:
            k = alvo / L if L else 0
            res.append((a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k))
            break
    return res


# ================================================================ 1. corvos e revoada de trovoes

# tons (indice de paleta)
C_CONT, C_P1, C_P2, C_P3, C_P4, C_QUENTE, C_BICO1, C_BICO2, C_OLHO, C_EL1, C_EL2, C_FA1, C_FA2, C_IMP = range(1, 15)


def pal_corvo(eletrico):
    return [(14, 13, 19), (28, 28, 36), (43, 45, 55), (62, 66, 79), (92, 98, 114), (124, 109, 86),
            (58, 54, 52), (120, 112, 98),
            (245, 125, 40) if eletrico else (92, 142, 236),
            (66, 130, 236), (150, 205, 255), (226, 242, 255), (246, 228, 120), (206, 206, 216)]


# rotulos de material
L_LONGE, L_CAUDA, L_CORPO, L_CABECA, L_BICO, L_ASA, L_COB, L_PENA, L_ELET, L_OLHO = range(1, 11)
RAMPA = {   # escuro (borda de baixo), meio, claro (borda de cima)
    L_LONGE: (C_P1, C_P1, C_P2), L_CAUDA: (C_P1, C_P1, C_P2), L_CORPO: (C_P1, C_P2, C_P3),
    L_CABECA: (C_P1, C_P2, C_P4), L_BICO: (C_BICO1, C_BICO1, C_BICO2), L_ASA: (C_P2, C_P3, C_P4),
    L_COB: (C_P3, C_P4, C_QUENTE), L_PENA: (C_P1, C_P1, C_P1), L_ELET: (C_EL1, C_EL1, C_EL2),
    L_OLHO: (C_OLHO, C_OLHO, C_OLHO),
}

# contorno da asa no espaco (s = ao longo da envergadura, c = ao longo da corda); dedos das primarias na ponta
ASA = [(0, 0), (0.35, -0.1), (0.7, -0.08), (0.95, 0.0), (1.0, 0.12), (0.88, 0.45), (0.7, 0.72), (0.5, 0.95),
       (0.25, 1.05), (0, 1.0)]
COBERTAS = [(0, 0), (0.35, -0.1), (0.55, -0.09), (0.5, 0.4), (0.25, 0.55), (0, 0.5)]
# as primarias: dedos separados que abrem em leque na ponta da asa
DEDOS = [((0.85, 0.04), (1.24, -0.02)), ((0.82, 0.3), (1.2, 0.36)), ((0.76, 0.55), (1.1, 0.74)),
         ((0.66, 0.76), (0.94, 1.02))]
PENAS = [((0.3, 0.66), (0.62, 0.66))]
CORPO = [(-6, -1.8), (-3, -4), (1, -4.4), (4, -4), (6, -2), (5.8, 1.5), (3, 3.8), (-1, 4.2), (-4, 3), (-6.5, 0.5)]
RAIZ_PERTO = ((3, -3.6), (-6, -2.6))
RAIZ_LONGE = ((5, -4.6), (-3, -4))


def gira(p, a, c):
    x, y = p
    ca, sa = math.cos(a), math.sin(a)
    return (c[0] + x * ca - y * sa, c[1] + x * sa + y * ca)


def ponto_asa(s, c, ra, rb, env, afina=0.42):
    k = 1 - afina * min(s, 1.0)   # a asa afina para a ponta
    return (ra[0] + s * env[0] + c * (rb[0] - ra[0]) * k, ra[1] + s * env[1] + c * (rb[1] - ra[1]) * k)


def envergadura(e, L, recuo, incl=0.0):
    """Vetor da raiz a ponta da asa visto de lado (e: -90 alto, 0 apontando para a camera, 90 embaixo).
    O olho fica um pouco acima: a asa que vem para a camera aparece um pouco para baixo. Com o corpo inclinado
    (incl, graus) a asa fica no espaco do mundo e ainda puxa para tras, em vez de girar junto com o corpo."""
    r = math.radians(e)
    x, y = -recuo * L, L * math.sin(r) + 0.3 * L * math.cos(r)
    a = -math.radians(incl) * 1.2
    return (x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a))


def corvo(W, H, P, eletrico, rq):
    """Desenha um corvo na pose P. Retorna Tela pronta (ja sombreada e contornada)."""
    t = Tela(W, H)
    lab = np.zeros((H, W), np.int16)
    c, a = (P["cx"], P["cy"]), math.radians(P["incl"])
    n = P["pescoco"]

    def T(p):
        return gira(p, a, c)

    def poli(pts, rot, so_vazio=False):
        m = t.mascara(lambda d: d.polygon([T(p) for p in pts], fill=255))
        if so_vazio:
            m &= lab == 0
        lab[m] = rot

    def linha(p0, p1, rot):
        m = t.mascara(lambda d: d.line([T(p0), T(p1)], fill=255, width=1))
        lab[m & (lab > 0)] = rot

    e, L, rc = P["e"], P["L"], P["recuo"]
    # asa de longe (atras do corpo, mais escura, raiz um pouco a frente e acima)
    def asa(ra, rb, env, rot, rot_dedo):
        poli([ponto_asa(s, cc, ra, rb, env) for s, cc in ASA], rot)
        for p0, p1 in DEDOS:   # os dedos abrem em leque: afinam menos que a asa
            m = t.mascara(lambda d: d.line([T(ponto_asa(*p0, ra, rb, env)),
                                            T(ponto_asa(*p1, ra, rb, env, afina=0.1))], fill=255, width=1))
            lab[m] = rot_dedo

    env = envergadura(e, L * 0.85, rc, P["incl"])
    asa(*RAIZ_LONGE, env, L_LONGE, L_LONGE)
    # cauda em cunha
    ab = P["cauda"]
    poli([(-5, -1.4), (-11.5, -2.4 - ab), (-13, -1 - ab * 0.5), (-13, 1.2 + ab * 0.5), (-11.5, 3 + ab),
          (-5, 2)], L_CAUDA)
    poli(CORPO, L_CORPO)
    poli([(3, -4.2), (6 + n, -6), (8.5 + n, 0), (4.5, 2.6)], L_CABECA)   # pescoco
    hx, hy = 7.2 + n, -3.2
    poli([(hx + 3.4 * math.cos(k * TAU / 14), hy + 3.2 * math.sin(k * TAU / 14)) for k in range(14)], L_CABECA)
    if P.get("bico_aberto"):
        poli([(hx + 2.2, -5.2), (hx + 6.8, -4.8), (hx + 2.4, -3.2)], L_BICO)
        poli([(hx + 2.2, -2.2), (hx + 6.0, -0.2), (hx + 1.8, 0.0)], L_BICO)
    else:
        poli([(hx + 2.2, -5.0), (hx + 5.0, -4.0), (hx + 7.0, -2.2), (hx + 2.2, -1.2)], L_BICO)
    # asa de perto
    env = envergadura(e, L, rc, P["incl"])
    ra, rb = RAIZ_PERTO
    asa(ra, rb, env, L_ASA, L_ELET if eletrico else L_ASA)
    poli([ponto_asa(s, cc, ra, rb, env) for s, cc in COBERTAS], L_COB)
    if eletrico:   # a borda de ataque da mao tambem brilha
        m_asa = np.isin(lab, (L_ASA, L_COB, L_PENA, L_ELET))
        m = t.mascara(lambda d: d.line([T(ponto_asa(s, -0.06, ra, rb, env)) for s in (0.6, 0.8, 0.97)],
                                       fill=255, width=1))
        lab[m & m_asa] = L_ELET
    for p0, p1 in PENAS:
        linha(ponto_asa(*p0, ra, rb, env), ponto_asa(*p1, ra, rb, env), L_PENA)
    ox, oy = T((hx + 1.2, -3.8))
    ox, oy = int(math.floor(ox)), int(math.floor(oy))
    lab[oy, ox] = L_OLHO
    t.fa[oy, ox] = True   # o olho e um pixel so, de proposito

    # sombreamento so na vertical (luz de cima: o espelho horizontal nao quebra nada)
    up = np.pad(lab, ((1, 0), (0, 0)))[:-1]
    dn = np.pad(lab, ((0, 1), (0, 0)))[1:]
    topo, base = up != lab, dn != lab
    for rot, (esc, meio, claro) in RAMPA.items():
        m = lab == rot
        t.idx[m] = meio
        t.idx[m & topo & ~base] = claro
        t.idx[m & base & ~topo] = esc
    # a asa de perto se destaca do corpo: o corpo em volta dela escurece
    asa = np.isin(lab, (L_ASA, L_COB, L_PENA, L_ELET))
    fundo = np.isin(lab, (L_CORPO, L_CABECA, L_CAUDA, L_LONGE))
    t.idx[fundo & viz4(asa)] = C_P1
    limpa(t, evita=(C_CONT,))
    # buraco de 1 px dentro da silhueta vira pena escura (senao o contorno deixaria um pixel solto ali)
    m = t.idx > 0
    viz = sum(np.roll(m, d, axis=ax) for ax in (0, 1) for d in (-1, 1))
    t.idx[~m & (viz >= 3)] = C_P1
    limpa(t)
    m = t.idx > 0
    t.idx[viz4(m) & ~m] = C_CONT   # o verificador acusa se o contorno encostar na borda da celula
    return t, T, (hx, hy)


def faiscas_corvo(t, rq, pontos, n):
    """Raiozinhos eletricos (faisca) em volta de pontos dados, so no vazio."""
    for _ in range(n):
        x, y = rq.choice(pontos)
        ang = rq.uniform(0, TAU)
        dx, dy = math.cos(ang), math.sin(ang)
        x, y = x + dx * rq.uniform(1.5, 3), y + dy * rq.uniform(1.5, 3)
        pts = [(x, y)]
        s = rq.choice([-1, 1])
        for _ in range(rq.randint(2, 3)):
            x += dx * 2 - dy * s * 1.2
            y += dy * 2 + dx * s * 1.2
            s = -s
            pts.append((x, y))
        cor = C_FA1 if rq.random() < 0.6 else C_FA2
        pts = [(min(max(x, 1), t.W - 2), min(max(y, 1), t.H - 2)) for x, y in pts]
        t.linha(pts, cor, faisca=True, so_vazio=True)


VOO_CORVO = [   # asas no alto, descendo, meio, embaixo, subindo dobradas, subindo
    dict(e=-80, L=9.6, recuo=0.3, dy=0),
    dict(e=-36, L=11, recuo=0.24, dy=0),
    dict(e=24, L=11, recuo=0.2, dy=-1),
    dict(e=62, L=10.4, recuo=0.32, dy=-1),
    dict(e=22, L=8, recuo=0.85, dy=-1),
    dict(e=-48, L=9, recuo=0.6, dy=0),
]
BICADA_CORVO = [   # arma, investe, bica (golpe), recolhe
    dict(incl=18, pescoco=-1.0, e=-76, L=8.4, recuo=0.4, cauda=1.0, aberto=False),
    dict(incl=34, pescoco=1.0, e=-60, L=8.8, recuo=0.5, cauda=1.6, aberto=True),
    dict(incl=46, pescoco=2.2, e=-46, L=9.2, recuo=0.6, cauda=2.0, aberto=False),
    dict(incl=30, pescoco=1.0, e=-68, L=8.6, recuo=0.45, cauda=1.3, aberto=False),
]
CORVO_W, CORVO_H = 36, 30
CORVO_VOO_C = (19, 17)
CORVO_BIC_C = (15, 14)


def corvo_voo(eletrico):
    rqb = random.Random(f"{SEMENTE}:corvo_voo:{eletrico}")
    res = []
    for q, v in enumerate(VOO_CORVO):
        P = dict(cx=CORVO_VOO_C[0], cy=CORVO_VOO_C[1] + v["dy"], incl=0, pescoco=0, e=v["e"], L=v["L"],
                 recuo=v["recuo"], cauda=0.3 + 0.2 * (q % 3 == 1))
        t, T, cab = corvo(CORVO_W, CORVO_H, P, eletrico, rqb)
        if eletrico:
            env = envergadura(v["e"], v["L"], v["recuo"])
            pontas = [T(ponto_asa(s, cc, *RAIZ_PERTO, env)) for s, cc in ((1.08, 0.06), (1.0, 0.54), (0.92, 0.76))]
            faiscas_corvo(t, rqb, pontas + [T((-14, 0))], 3)
        res.append(t)
    return res


def corvo_bicada(eletrico):
    rqb = random.Random(f"{SEMENTE}:corvo_bicada:{eletrico}")
    res = []
    for q, v in enumerate(BICADA_CORVO):
        P = dict(cx=CORVO_BIC_C[0], cy=CORVO_BIC_C[1], incl=v["incl"], pescoco=v["pescoco"], e=v["e"], L=v["L"],
                 recuo=v["recuo"], cauda=v["cauda"], bico_aberto=v["aberto"])
        t, T, (hx, hy) = corvo(CORVO_W, CORVO_H, P, eletrico, rqb)
        ponta = T((hx + 7.4, -1.8))
        if q == 2:   # a bicada acerta: estalo na ponta do bico
            px_, py_ = ponta
            a = math.radians(v["incl"])
            for da, L in ((-0.9, 3), (0.0, 4), (0.9, 3)):
                dx, dy = math.cos(a + da), math.sin(a + da)
                fim = (min(max(px_ + dx * (2 + L), 1), CORVO_W - 2), min(max(py_ + dy * (2 + L), 1), CORVO_H - 2))
                t.linha([(px_ + dx * 2, py_ + dy * 2), fim],
                        C_FA1 if eletrico else C_IMP, faisca=True, so_vazio=True)
        if q == 3 and not eletrico:   # lasca do golpe ainda no ar
            px_, py_ = ponta
            t.linha([(px_ + 3, py_ + 3), (px_ + 4, py_ + 4)], C_IMP, faisca=True, so_vazio=True)
        if eletrico:
            env = envergadura(v["e"], v["L"], v["recuo"], v["incl"])
            pontas = [T(ponto_asa(s, cc, *RAIZ_PERTO, env)) for s, cc in ((1.08, 0.06), (0.92, 0.76))]
            faiscas_corvo(t, rqb, pontas + ([ponta] if q >= 1 else []), 3 if q != 2 else 4)
        res.append(t)
    return res


# ================================================================ 2. runa e circulo runico

# paleta aditiva
R_BRANCO, R_LILAS, R_ROXO, R_FUNDO, R_CIANO, R_BRASA, R_BRASA2 = range(1, 8)
PAL_RUNA = [(250, 250, 255), (214, 160, 255), (160, 82, 236), (88, 40, 150), (130, 228, 255), (255, 150, 55),
            (255, 220, 130)]

SIMB3 = [["010", "111", "010"], ["101", "010", "101"], ["110", "010", "011"], ["011", "010", "110"]]
SIMB5 = [["01010", "10101", "01010"], ["11011", "00100", "11011"], ["10001", "01110", "10001"],
         ["00100", "11111", "00100"], ["11100", "00100", "00111"], ["01110", "10001", "01110"]]

GEO_RUNA = dict(W=72, H=46, cx=36, cy=27, rx=33, ry=13, banda=None, circ=0.64, los=(13, 7), los_in=(7, 3.5),
                simb_n=8, simb_r=0.82, simb=SIMB3, sat=[], brasas=0, esp=14)
GEO_CIRC = dict(W=100, H=72, cx=50, cy=43, rx=46, ry=24, banda=0.84, circ=0.58, los=(16, 10), los_in=(9, 5.5),
                simb_n=12, simb_r=0.92, simb=SIMB5, sat=[-90, 30, 150], sat_tam=(6, 4), brasas=14, esp=22)


def no_elipse(G, r, ang):
    a = math.radians(ang)
    return (G["cx"] + r * G["rx"] * math.cos(a), G["cy"] + r * G["ry"] * math.sin(a))


def losango_pts(cx, cy, hx, hy):
    """Perimetro a partir da ponta esquerda, ida por cima ate a direita e volta por baixo (dois tracos)."""
    return ([(cx - hx, cy), (cx, cy - hy), (cx + hx, cy)], [(cx - hx, cy), (cx, cy + hy), (cx + hx, cy)])


def carimbo(t, glifo, x, y, cor, dens=1.0):
    h, w = len(glifo), len(glifo[0])
    x0, y0 = int(round(x)) - w // 2, int(round(y)) - h // 2
    m = np.zeros((t.H, t.W), bool)
    for j, ln in enumerate(glifo):
        for i, ch in enumerate(ln):
            if ch == "1" and 0 <= x0 + i < t.W and 0 <= y0 + j < t.H:
                m[y0 + j, x0 + i] = True
    t.pinta(m, cor, dens)


def glifo(t, G, st):
    """O desenho do circulo no chao. st: estado de cada parte (fracao desenhada, cor, densidade)."""
    cx, cy, rx, ry = G["cx"], G["cy"], G["rx"], G["ry"]
    d = st.get("dens", 1.0)
    halo = st.get("halo", 0)
    if halo:
        hr = st.get("halo_r", 1)
        t.elipse(cx, cy, rx + hr, ry + hr, R_FUNDO, dens=halo)
        t.elipse(cx, cy, rx - 1 - hr, ry - 1 - hr, R_FUNDO, dens=halo * 0.8)
    # circulo interno tracejado
    f = st.get("circ", 1)
    if f > 0:
        n = 16 if G["banda"] is None else 20
        passo = 360 / n
        for k in range(int(n * f + 0.999)):
            a0 = 90 + ((k + 1) // 2) * passo * (1 if k % 2 == 0 else -1)   # da frente para tras, dos dois lados
            t.arco(cx, cy, rx * G["circ"], ry * G["circ"], a0 - passo * 0.3, a0 + passo * 0.3,
                   st.get("circ_cor", R_ROXO), dens=d)
    # anel de fora (e a banda dupla do circulo runico): desenhado pelas duas pontas a partir da frente
    f = st.get("anel", 1)
    if f > 0:
        larg = st.get("anel_larg", 1)
        t.arco(cx, cy, rx, ry, 90 - 180 * f, 90 + 180 * f, st.get("anel_cor", R_LILAS), larg, d)
        if G["banda"]:
            b = G["banda"]
            t.arco(cx, cy, rx * b, ry * b, 90 - 180 * f, 90 + 180 * f, st.get("banda_cor", R_ROXO), larg, d)
        if st.get("canetas") and f < 1:
            for s_ in (-1, 1):
                x, y = no_elipse(G, 1, 90 + s_ * 180 * f)
                t.estrela(x, y, 1, R_BRANCO)
    # cruz
    f = st.get("cruz", 1)
    if f > 0:
        hx, hy = G["los"]
        rc = G["circ"]
        cor = st.get("cruz_cor", R_ROXO)
        for s_ in (-1, 1):
            x0, x1 = cx + s_ * hx, cx + s_ * (hx + (rx * rc - hx) * f)
            t.linha([(x0, cy), (x1, cy)], cor, d)
        t.linha([(cx, cy + hy), (cx, cy + hy + (ry * rc - hy) * f)], cor, d)
        t.linha([(cx, cy - hy), (cx, cy - hy - (ry * rc - hy) * f)], cor, d)
    # losangos
    for chave, tam in (("los", G["los"]), ("los_in", G["los_in"])):
        f = st.get(chave, 1)
        if f > 0:
            for tr in losango_pts(cx, cy, *tam):
                t.linha(caminho_parcial(tr, f), st.get(chave + "_cor", R_LILAS if chave == "los" else R_ROXO), d)
            if st.get("canetas") and f < 1:
                for tr in losango_pts(cx, cy, *tam):
                    x, y = caminho_parcial(tr, f)[-1]
                    t.estrela(x, y, 1, R_BRANCO)
    # simbolos na banda
    for i, cor in enumerate(st.get("simb", [])):
        if cor:
            ang = -90 + (i + 0.5) * 360 / G["simb_n"]
            x, y = no_elipse(G, G["simb_r"], ang)
            carimbo(t, G["simb"][i % len(G["simb"])], x, y, cor, d)
    # satelites (circulo runico): losangos pequenos em cima do anel
    for k, ss in enumerate(st.get("sat", [])):
        if not ss:
            continue
        fr, cor, no = ss
        x, y = no_elipse(G, 1, G["sat"][k])
        hx, hy = G["sat_tam"]
        x, y = round(x), round(y)
        if fr >= 1:
            t.poli([(x - hx + 1, y), (x, y - hy + 1), (x + hx - 1, y), (x, y + hy - 1)], 0)   # limpa o anel por dentro
        for tr in losango_pts(x, y, hx, hy):
            t.linha(caminho_parcial(tr, fr), cor, d)
        if no:
            t.estrela(x, y, no, R_BRANCO, R_CIANO)
    # nos: pontas do losango grande e o centro
    hx, hy = G["los"]
    for (x, y), r in zip(((cx - hx, cy), (cx, cy - hy), (cx + hx, cy), (cx, cy + hy)), st.get("nos", [])):
        if r:
            t.estrela(x, y, r, R_BRANCO, R_CIANO)
    if st.get("no_c"):
        t.estrela(cx, cy, st["no_c"], R_BRANCO, R_CIANO)
    # espiga de luz que sobe do centro
    e = st.get("espiga", 0)
    if e:
        t.linha([(cx, cy - hy - 1), (cx, cy - hy - e)], R_CIANO, st.get("espiga_dens", 1.0), True)


def brasas(t, G, rq, q, n, subida=2, periodo=8, espalha=1.0):
    """Brasas laranja que sobem em volta do circulo; o deslocamento repete a cada periodo (emenda o loop)."""
    for k in range(n):
        ang = rq.uniform(0, 360)
        r = rq.uniform(0.75, 1.15) * espalha
        x, y = no_elipse(G, r, ang)
        fase = rq.randint(0, periodo - 1)
        sobe = (fase + q * subida) % periodo
        cor = R_BRASA if k % 3 else R_BRASA2
        y = y - 4 - sobe
        if sobe < periodo - 2:
            t.linha([(x, y), (x, y + 1)], cor, faisca=True, so_vazio=True)
        else:
            t.px(x, y, cor, True)


def runa_armar(G, q):
    t = Tela(G["W"], G["H"])
    ns = G["simb_n"]
    if q == 0:
        st = dict(anel=0.22, circ=0, cruz=0.4, los=0, los_in=0, no_c=1, canetas=True)
    elif q == 1:
        st = dict(anel=0.55, circ=0.25, cruz=1, los=0.5, los_in=0, no_c=2, canetas=True,
                  sat=[(0.3, R_ROXO, 0)] * len(G["sat"]))
    elif q == 2:
        st = dict(anel=0.88, circ=0.75, cruz=1, los=1, los_in=0.6, no_c=2, canetas=True,
                  simb=[R_ROXO if i % 2 == 0 else 0 for i in range(ns)], sat=[(0.8, R_LILAS, 0)] * len(G["sat"]))
    else:
        st = dict(anel=1, circ=1, cruz=1, los=1, los_in=1, no_c=3, nos=[1, 1, 1, 1], halo=0.3,
                  simb=[R_LILAS if i % 4 == 3 else R_ROXO for i in range(ns)],
                  sat=[(1, R_LILAS, 1)] * len(G["sat"]), espiga=G["esp"] // 2, espiga_dens=0.5)
    glifo(t, G, st)
    if q == 3:   # as pontas se encontram atras: estalo
        x, y = no_elipse(G, 1, -90)
        t.estrela(x, y, 2, R_BRANCO, R_CIANO)
    limpa(t)
    return t


def runa_loop(G, q):
    t = Tela(G["W"], G["H"])
    ns = G["simb_n"]
    simb = []
    for i in range(ns):
        k = i % 4
        simb.append(R_BRANCO if k == q else (R_LILAS if k == (q - 1) % 4 else R_ROXO))
    nos = [2 if k == q else 1 for k in range(4)]
    sat = []
    for k in range(len(G["sat"])):
        sat.append((1, R_BRANCO if k == q else R_LILAS, 2 if k == q else 1))
    halo = [0.3, 0.45, 0.62, 0.45][q]
    glifo(t, G, dict(halo=halo, halo_r=[1, 1, 2, 1][q], simb=simb, nos=nos, no_c=[2, 3, 3, 2][q], sat=sat,
                     espiga=G["esp"] - [4, 2, 0, 2][q], espiga_dens=[0.5, 0.62, 1.0, 0.62][q]))
    # faiscas que sobem de dentro do circulo (periodo de 4 quadros)
    rq = random.Random(f"{SEMENTE}:{G['W']}:motes")
    for k in range(6 if G["banda"] is None else 9):
        ang = rq.uniform(0, 360)
        x, y = no_elipse(G, rq.uniform(0.3, 0.75), ang)
        fase = rq.randint(0, 3)
        sobe = ((fase + q) % 4) * 2
        t.linha([(x, y - sobe), (x, y - sobe - 1)], R_LILAS if sobe < 6 else R_ROXO, faisca=True, so_vazio=True)
    if G["brasas"]:
        brasas(t, G, random.Random(f"{SEMENTE}:brasas"), q, G["brasas"])
    limpa(t)
    return t


def coluna(t, cx, base, topo, larg, dens, quebra=None, rq=None):
    """Coluna de luz que sobe do chao: miolo branco, meio lilas e borda roxa pontilhada."""
    cores = (R_BRANCO, R_LILAS, R_ROXO)
    for (w, cor, dd) in sorted(zip(larg, cores, dens), key=lambda e: -e[0]):
        if w <= 0:
            continue
        x0, x1 = cx - w / 2, cx + w / 2 - 1
        m = (t.xs >= round(x0)) & (t.xs <= round(x1)) & (t.ys >= topo) & (t.ys <= base)
        # topo arredondado: o pixel da quina some
        m &= ~((t.ys == topo) & ((t.xs == round(x0)) | (t.xs == round(x1))))
        if quebra is not None:
            m &= ~quebra
        t.pinta(m, cor, dd)


def runa_explosao(G, q):
    t = Tela(G["W"], G["H"])
    cx, cy, rx, ry = G["cx"], G["cy"], G["rx"], G["ry"]
    k = 1.0 if G["banda"] is None else 1.4
    ns = G["simb_n"]
    rq = random.Random(f"{SEMENTE}:{G['W']}:explosao:{q}")
    fx = random.Random(f"{SEMENTE}:{G['W']}:explosao")
    smax = (G["W"] / 2 - 1) / rx
    if q == 0:   # o glifo inteiro acende de uma vez
        glifo(t, G, dict(anel_cor=R_BRANCO, banda_cor=R_LILAS, anel_larg=2, halo=0.7, halo_r=2, circ_cor=R_LILAS,
                         cruz_cor=R_LILAS, los_cor=R_BRANCO, los_in_cor=R_LILAS, simb=[R_BRANCO] * ns,
                         nos=[2, 2, 2, 2], no_c=4, sat=[(1, R_BRANCO, 2)] * len(G["sat"])))
        t.elipse(cx, cy, 4 * k, 2 * k, R_BRANCO, cheia=True)
        limpa(t)
        return t
    if q in (1, 2):
        glifo(t, G, dict(dens=[0, 0.85, 0.5][q], anel_cor=R_LILAS if q == 1 else R_ROXO, circ_cor=R_ROXO,
                         cruz=1 if q == 1 else 0, los_cor=R_LILAS if q == 1 else R_ROXO,
                         simb=[R_LILAS if q == 1 else R_ROXO] * ns, sat=[(1, R_LILAS, 1)] * len(G["sat"])
                         if q == 1 else []))
    if q == 3:
        t.elipse(cx, cy, rx, ry, R_FUNDO, dens=0.4)
    # anel de choque que corre pelo chao
    s = [0, 0.45, 0.72, 0.92, smax, smax][q]
    if q < 5:
        cor = [0, R_BRANCO, R_LILAS, R_LILAS, R_ROXO][q]
        dd = [0, 1, 1, 0.8, 0.55][q]
        t.elipse(cx, cy, rx * s, ry * s, cor, dens=dd)
        t.elipse(cx, cy, rx * s - 2, ry * s - 1, R_FUNDO if q > 1 else R_ROXO, larg=2, dens=dd * 0.6)
    else:
        t.elipse(cx, cy, rx * s, ry * s, R_FUNDO, larg=2, dens=0.3)
    # coluna de luz
    base = cy + 2
    if q == 1:
        coluna(t, cx, base, 6 if G["banda"] is None else 10, (4 * k, 8 * k, 12 * k), (1, 1, 0.5))
    elif q == 2:
        coluna(t, cx, base, 0, (6 * k, 10 * k, 16 * k), (1, 1, 0.55))
    elif q == 3:
        quebra = ((t.ys + (t.xs // 3)) % 7) < 2
        coluna(t, cx, base - 2, 2, (2 * k, 6 * k, 10 * k), (1, 0.8, 0.4), quebra=quebra)
    if q in (1, 2):   # pe da coluna espalhando luz no chao
        t.elipse(cx, cy, (8 + 3 * q) * k, (3 + q) * k, R_BRANCO if q == 1 else R_LILAS, cheia=True)
        t.elipse(cx, cy, (5 + 2 * q) * k, (2 + q * 0.5) * k, R_BRANCO, cheia=True)
    if G["sat"] and q in (1, 2, 3):   # colunas finas nos satelites
        for ang in G["sat"]:
            x, y = no_elipse(G, 1, ang)
            topo = max(0, round(y) - [0, 12, 22, 16][q])
            coluna(t, round(x), round(y) + 1, topo, ((2, 4, 6), (2, 4, 6), (0, 2, 4))[q - 1],
                   (1, 0.85, 0.5) if q < 3 else (0.8, 0.5, 0.3))
    # riscos de luz subindo (o que sobra da coluna)
    if q >= 2:
        nst = [0, 0, 5, 7, 7, 4][q]
        for i in range(nst):
            x = cx + fx.uniform(-9, 9) * k
            y0 = cy - fx.uniform(6, 20) * k - [0, 0, 4, 10, 18, 26][q] * k
            L = [0, 0, 4, 4, 3, 2][q]
            if y0 - L < 0:
                y0 = L + fx.uniform(0, 3)
            t.linha([(x, y0), (x, y0 - L)], R_LILAS if q < 4 else R_ROXO, faisca=True, so_vazio=q < 4)
    # brilhos espalhados pelo chao
    for _ in range([0, 4, 6, 6, 5, 3][q]):
        x, y = no_elipse(G, rq.uniform(0.3, s + 0.05), rq.uniform(0, 360))
        t.estrela(x, y, 1 if q > 2 else 2, R_BRANCO if q < 3 else R_LILAS, R_CIANO if q < 3 else R_ROXO)
    if G["brasas"]:   # brasas arremessadas para fora
        for i in range(G["brasas"]):
            ang = fx.uniform(0, 360)
            r = 0.4 + q * 0.16 + fx.uniform(-0.05, 0.1)
            x, y = no_elipse(G, min(r, smax), ang)
            y -= [0, 3, 6, 7, 6, 4][q] * fx.uniform(0.6, 1.2)
            if q >= 4 and i % 2:
                continue
            cor = R_BRASA2 if q < 3 else R_BRASA
            if q < 4:
                t.linha([(x, y), (x + math.cos(math.radians(ang)), y + 1)], cor, faisca=True)
            else:
                t.px(x, y, cor, True)
    limpa(t)
    return t


# ================================================================ 3. raio (impacto)

PAL_RAIO = [(250, 252, 255), (180, 222, 255), (92, 162, 255), (46, 92, 212)]


def zigue(t, rq, x, y, dx, dy, nseg, comp, cor, cor_ponta, desde=0):
    px_, py_ = -dy, dx
    pts = [(x, y)]
    s = rq.choice([-1, 1])
    for _ in range(nseg):
        a = rq.uniform(0.8, 1.8)
        x += dx * comp + px_ * s * a
        y += dy * comp * 0.6 + py_ * s * a * 0.6   # achatado: as faiscas correm rente ao chao
        s = -s
        pts.append((x, y))
    if len(pts) - 1 > desde:
        if len(pts[desde:-1]) > 1:
            t.linha(pts[desde:-1], cor, faisca=True)
        t.linha(pts[-2:], cor_ponta, faisca=True)
    return pts


def raio_impacto(q):
    t = Tela(32, 32)
    cx, cy = 16, 16
    rq = random.Random(f"{SEMENTE}:raio:{q}")
    fx = random.Random(f"{SEMENTE}:raio")
    angs = [k * TAU / 7 + fx.uniform(-0.25, 0.25) for k in range(7)]
    if q == 0:
        t.elipse(cx, cy, 7, 7, 3, dens=0.5, cheia=True)
        t.elipse(cx, cy, 5, 5, 2, cheia=True)
        t.elipse(cx, cy, 3, 3, 1, cheia=True)
        t.linha([(cx, cy - 4), (cx - 1, cy - 8), (cx + 1, cy - 11), (cx, cy - 14)], 1, faisca=True)  # a ponta do raio
        t.elipse(cx, cy + 1, 6, 3, 2)
        for a in angs:
            dx, dy = math.cos(a), math.sin(a)
            zigue(t, rq, cx + dx * 4, cy + dy * 3, dx, dy, 2, 2.5, 2, 3)
    elif q == 1:
        t.elipse(cx, cy + 1, 9, 4, 2)
        t.elipse(cx, cy + 1, 7, 3, 3, dens=0.5)
        t.elipse(cx, cy, 4, 3, 2, cheia=True)
        t.elipse(cx, cy, 2, 2, 1, cheia=True)
        for i, a in enumerate(angs):
            dx, dy = math.cos(a), math.sin(a)
            pts = zigue(t, rq, cx + dx * 3, cy + dy * 2, dx, dy, rq.randint(3, 4), 3, 2, 3)
            if i % 2 == 0 and len(pts) > 2:   # ramo
                g = rq.choice([-0.8, 0.8])
                c, s_ = math.cos(g), math.sin(g)
                zigue(t, rq, *pts[1], dx * c - dy * s_, dx * s_ + dy * c, 2, 2.4, 3, 4)
    elif q == 2:
        t.elipse(cx, cy + 1, 12, 6, 3)
        t.elipse(cx, cy + 1, 10, 5, 4, larg=2, dens=0.5)
        t.elipse(cx, cy, 1, 1, 2, cheia=True)
        for a in angs[::1]:
            dx, dy = math.cos(a + 0.15), math.sin(a + 0.15)
            zigue(t, rq, cx + dx * 7, cy + dy * 4, dx, dy, 3, 2.6, 3, 4, desde=1)
    else:
        t.elipse(cx, cy + 1, 14, 7, 4, dens=0.55)
        for a in angs[::2]:
            dx, dy = math.cos(a + 0.3), math.sin(a + 0.3)
            x, y = cx + dx * 12, cy + dy * 6.5
            t.linha([(x, y), (x + dx * 2, y + dy * 1.2)], 3, faisca=True)
        for _ in range(3):
            a = rq.uniform(0, TAU)
            t.px(cx + math.cos(a) * 8, cy + math.sin(a) * 4, 2, True)
    limpa(t)
    return t


# ================================================================ 4 e 5. ventania e onda (laminas de vento)

PAL_VENTANIA = [(246, 255, 255), (192, 244, 246), (110, 214, 232), (56, 138, 168), (176, 186, 250), (118, 132, 222)]
PAL_ONDA = [(246, 255, 250), (202, 250, 226), (128, 226, 182), (64, 156, 126), (176, 240, 210), (112, 196, 160)]

GEO_VENT = dict(W=64, H=32, cx1=44, cy=16, r1=(12.5, 12.5), cx2=55, r2=(9.5, 10.5), cauda_x=37, cauda_dy=8.5,
                cauda_fim=3, listras=True, fiapos=True)
GEO_ONDA = dict(W=48, H=28, cx1=32, cy=14, r1=(9.5, 10.5), cx2=41, r2=(7.5, 9.0), cauda_x=26, cauda_dy=7,
                cauda_fim=8, listras=False, fiapos=False)


def lamina(G, q):
    W, H = G["W"], G["H"]
    t = Tela(W, H)
    X, Y = t.xs + 0.5, t.ys + 0.5
    cy = G["cy"]
    pulso = [0, 0.4, 1.0, 0.7][q]
    r1x, r1y = G["r1"]
    r2x, r2y = G["r2"][0] + pulso * 0.6, G["r2"][1] - pulso * 0.4
    e1 = np.hypot((X - G["cx1"]) / r1x, (Y - cy) / r1y)
    e2 = np.hypot((X - G["cx2"]) / r2x, (Y - cy) / r2y)
    lua = (e1 <= 1) & (e2 > 1)
    d_in = (e2 - 1) * r2x            # distancia (px) da borda de dentro (a que corta)
    d_out = (1 - e1) * r1x           # distancia da borda de fora
    # caudas: dois fios que saem das costas da lamina e se desfazem para tras
    cx0, dy0, xf = G["cauda_x"], G["cauda_dy"], G["cauda_fim"]
    rqf = random.Random(f"{SEMENTE}:{W}:cauda")
    buracos = [rqf.random() for _ in range(32)]
    for lado in (-1, 1):
        u = np.clip((X - xf) / (cx0 - xf), 0, 1)        # 0 no fim da cauda, 1 na lamina
        yc = cy + lado * (dy0 - (1 - u) ** 1.2 * (4.5 if lado < 0 else 3.5))   # curva para dentro
        esp = 0.2 + 2.8 * u ** 1.7    # afina ate a ponta
        dist = (Y - yc) * lado                          # positivo = para fora
        dentro = (np.abs(dist) <= esp / 2 + 0.25) & (X >= xf) & (X <= cx0 + 2)
        # a cauda se desfaz em pedacos que correm para tras (4 px por quadro, periodo de 16)
        fase = ((t.xs + 4 * q) // 4) % 32
        ok = np.array(buracos)[fase] < 0.35 + 0.65 * np.clip(u * 1.6, 0, 1)
        dentro &= ok | (u > 0.7)
        perto = u > 0.45
        t.pinta(dentro & (dist < 0) & perto, 1)
        t.pinta(dentro & (dist < 0) & ~perto, 2)
        t.pinta(dentro & (dist >= 0), 3 if lado < 0 else 2)
        t.pinta(dentro & (dist >= 0) & ~perto, 3)
        glow = (np.abs(dist) <= esp / 2 + 1.3) & ~dentro & (X >= xf + 3) & (X <= cx0) & ok
        t.pinta(glow & (dist > 0), 4, 0.5, so_vazio=True)
    # corpo da lamina
    t.pinta(lua, 2)
    t.pinta(lua & (d_out < 1.6), 3)
    t.pinta(lua & (d_in < 1.6), 1)
    if G["listras"]:   # listras lilas paralelas ao corte, correm para a frente
        ls = lua & (np.mod(d_in - q, 4) < 1) & (d_in > 2.4) & (d_out > 1.8) & (np.abs(Y - cy) < r1y * 0.72)
        t.pinta(ls, 5)
    else:
        ls = lua & (np.abs(d_in - (3.0 + 0.8 * [0, 1, 2, 3][q])) < 0.5) & (d_out > 1.6) & (np.abs(Y - cy) < r1y * 0.6)
        t.pinta(ls, 5)
    halo = (e1 > 1) & (e1 <= 1 + 1.4 / r1x) & (e2 > 1) & (X < G["cx1"] + r1x * 0.5)
    t.pinta(halo, 4, 0.55, so_vazio=True)
    # fiapos soltos atras (derivam para tras e somem)
    if G["fiapos"]:
        rq = random.Random(f"{SEMENTE}:{W}:fiapos")
        for k in range(6):
            x0 = rq.uniform(4, 30)
            y0 = cy + rq.uniform(-5, 5)
            x = x0 - ((rq.randint(0, 3) + q) % 4) * 3
            L = rq.randint(3, 5)
            t.linha([(x, y0), (x + L, y0)], 6 if k % 2 else 4, so_vazio=True)
    # brilho nas pontas (o fio do corte)
    for lado in (-1, 1):
        ys = np.nonzero(lua.any(axis=1))[0]
        if not len(ys):
            continue
        y = ys.min() if lado < 0 else ys.max()
        xs = np.nonzero(lua[y])[0]
        if len(xs) and q % 2 == (0 if lado < 0 else 1):
            t.px(xs.max(), y, 1)
            t.px(xs.max() - 1, y, 1)
    limpa(t)
    return t


# ================================================================ 6. fura (lanca de luz)

PAL_FURA = [(250, 254, 255), (196, 246, 255), (104, 214, 246), (48, 132, 196)]
FURA_W, FURA_H, FURA_PONTA = 40, 10, (30, 5)


def fura(q):
    t = Tela(FURA_W, FURA_H)
    px_, cy = FURA_PONTA
    rq = random.Random(f"{SEMENTE}:fura:{q}")
    # rastro que tremula (ondula e se parte)
    for x in range(0, 13):
        onda = math.sin(x * 0.7 + q * PI / 2)
        y = cy + (1 if onda > 0.55 else (-1 if onda < -0.55 else 0))
        corte = ((x + q * 3) % 6) < (1 if x > 6 else 2)
        if corte:
            continue
        cor = 2 if x > 8 else (3 if x > 3 else 4)
        t.px(x, y, cor)
        if x > 8 and y == cy:
            t.px(x, y + (1 if q % 2 else -1), 4)
    # haste
    t.linha([(9, cy), (px_ - 6, cy)], 1)
    t.linha([(13 + (q % 2), cy - 1), (px_ - 6, cy - 1)], 2)
    t.linha([(13 + ((q + 1) % 2), cy + 1), (px_ - 6, cy + 1)], 2)
    t.linha([(17 + q, cy - 2), (px_ - 7, cy - 2)], 4, dens=0.55)
    t.linha([(19 - q, cy + 2), (px_ - 7, cy + 2)], 4, dens=0.55)
    # ponta (folha de lanca) e brilho
    t.poli([(px_, cy), (px_ - 4, cy - 2), (px_ - 7, cy - 2), (px_ - 6, cy), (px_ - 7, cy + 2), (px_ - 4, cy + 2)], 2)
    t.linha([(px_ - 8, cy), (px_, cy)], 1)
    t.linha([(px_ - 5, cy - 2), (px_ - 3, cy - 1)], 3)
    t.linha([(px_ - 5, cy + 2), (px_ - 3, cy + 1)], 3)
    if q % 2 == 0:   # clarao na ponta pulsa
        t.linha([(px_ + 1, cy), (px_ + 2 + (q // 2), cy)], 3)
        t.linha([(px_ - 4, cy - 3), (px_ - 2, cy - 3)], 4)
        t.linha([(px_ - 4, cy + 3), (px_ - 2, cy + 3)], 4)
    else:
        t.px(px_ + 1, cy, 2)
        t.px(px_ + 2, cy, 2)
        t.linha([(px_ - 6, cy - 3), (px_ - 4, cy - 3)], 4)
        t.linha([(px_ - 6, cy + 3), (px_ - 4, cy + 3)], 4)
    # cintilas em volta da haste
    for _ in range(2):
        x = rq.randint(12, 24)
        y = cy + rq.choice([-3, 3])
        t.px(x, y, 3, True)
    limpa(t)
    return t


# ================================================================ folhas, indice, previas, verificador

def folhas():
    """sprite -> (armas, paleta(s), aditivo, {anim: (quadros(Tela), quadro, fps, loop, ancora)})"""
    F = {}
    for nome, el in (("corvos", False), ("revoada_de_trovoes", True)):
        F[nome] = dict(armas=[nome], paleta=pal_corvo(el), aditivo=False, anims={
            "voo": (corvo_voo(el), (CORVO_W, CORVO_H), 12, True, CORVO_VOO_C),
            "bicada": (corvo_bicada(el), (CORVO_W, CORVO_H), 14, True, CORVO_BIC_C)})
    for nome, G in (("runa", GEO_RUNA), ("circulo_runico", GEO_CIRC)):
        tam, anc = (G["W"], G["H"]), (G["cx"], G["cy"])
        F[nome] = dict(armas=[nome], paleta=PAL_RUNA, aditivo=True, anims={
            "armar": ([runa_armar(G, q) for q in range(4)], tam, 6, False, anc),
            "loop": ([runa_loop(G, q) for q in range(4)], tam, 6, True, anc),
            "explosao": ([runa_explosao(G, q) for q in range(6)], tam, 15, False, anc)})
    F["raio"] = dict(armas=["raio"], paleta=PAL_RAIO, aditivo=True, anims={
        "impacto": ([raio_impacto(q) for q in range(4)], (32, 32), 20, False, (16, 16))})
    F["ventania"] = dict(armas=["ventania"], paleta=PAL_VENTANIA, aditivo=True, anims={
        "voo": ([lamina(GEO_VENT, q) for q in range(4)], (64, 32), 12, True, (32, 16))})
    F["onda"] = dict(armas=["onda"], paleta=PAL_ONDA, aditivo=True, anims={
        "voo": ([lamina(GEO_ONDA, q) for q in range(4)], (48, 28), 12, True, (24, 14))})
    F["fura"] = dict(armas=["fura"], paleta=PAL_FURA, aditivo=True, anims={
        "voo": ([fura(q) for q in range(4)], (FURA_W, FURA_H), 12, True, FURA_PONTA)})
    return F


def compoe(q, aditivo):
    fundo = np.array(FUNDO, np.int32)
    H, W = q.shape[:2]
    rgb = np.broadcast_to(fundo, (H, W, 3)).copy()
    m = q[..., 3] > 0
    if aditivo:
        rgb[m] = np.minimum(rgb[m] + q[..., :3][m].astype(np.int32), 255)
    else:
        rgb[m] = q[..., :3][m]
    return rgb.astype(np.uint8)


def previa(nome, f, tiras):
    """Todas as animacoes em sequencia (as de loop 3 vezes), 4x, vizinho mais proximo, ancora no mesmo ponto."""
    anims = f["anims"]
    pad = 3
    esq = max(a[4][0] for a in anims.values()) + pad
    cima = max(a[4][1] for a in anims.values()) + pad
    W = esq + max(a[1][0] - a[4][0] for a in anims.values()) + pad
    H = cima + max(a[1][1] - a[4][1] for a in anims.values()) + pad
    frames, durs = [], []
    for an, (qs, (w, h), fps, loop, (ax, ay)) in anims.items():
        for _ in range(3 if loop else 1):
            for q in tiras[an]:
                cel = np.zeros((H, W, 4), np.uint8)
                cel[cima - ay:cima - ay + h, esq - ax:esq - ax + w] = q
                frames.append(Image.fromarray(compoe(cel, f["aditivo"])).resize((W * 4, H * 4), Image.NEAREST))
                durs.append(round(1000 / fps))
        frames.append(Image.new("RGB", (W * 4, H * 4), FUNDO))
        durs.append(300)
    pal = [fr.quantize(colors=255, method=Image.Quantize.MAXCOVERAGE) for fr in frames]
    pal[0].save(PREVIAS / f"{nome}.gif", save_all=True, append_images=pal[1:], duration=durs, loop=0, disposal=1)


def indice(F):
    out = {"_gerado_por": "jogos/hordas/fonte_arte/armas_anim/gerar_magias.py (nao edite a mao)", "folhas": {}}
    for nome, f in F.items():
        anims = {}
        for an, (qs, tam, fps, loop, anc) in f["anims"].items():
            anims[an] = {"arquivo": f"{nome}_{an}.png", "quadro": list(tam), "n": len(qs), "fps": fps, "loop": loop,
                         "ancora": list(anc)}
        out["folhas"][nome] = {"armas": f["armas"], "anims": anims}
    return out


def conferir(F=None):
    """Tamanho, alfa 0/255, quadros nao vazios e diferentes, emenda do loop, ancora dentro, sem tocar a borda
    (os de mistura normal), contorno escuro fechado nos corvos, pixels soltos (fora das faiscas) e tons."""
    idx = json.load(open(SAIDA / "indice_magias.json", encoding="utf-8"))
    falhas = []
    for nome, f in idx["folhas"].items():
        for an, d in f["anims"].items():
            img = np.array(Image.open(SAIDA / d["arquivo"]).convert("RGBA"))
            (w, h), n = d["quadro"], d["n"]
            msg = []
            if img.shape[:2] != (h, w * n):
                msg.append(f"tamanho {img.shape[1]}x{img.shape[0]} != {w * n}x{h}")
            al = set(np.unique(img[..., 3]).tolist())
            if not al <= {0, 255}:
                msg.append(f"alfa intermediario {sorted(al - {0, 255})[:5]}")
            qs = [img[:, i * w:(i + 1) * w] for i in range(n)]
            menor = 1.0
            for i in range(n):
                if not qs[i][..., 3].any():
                    msg.append(f"quadro {i + 1} vazio")
                for j in range(i + 1, n):
                    dif = float((qs[i] != qs[j]).any(axis=2).mean())
                    menor = min(menor, dif)
                    if dif < 0.015:
                        msg.append(f"quadros {i + 1} e {j + 1} quase iguais ({dif:.1%})")
            ax, ay = d["ancora"]
            if not (0 <= ax < w and 0 <= ay < h):
                msg.append("ancora fora")
            normal = nome in ("corvos", "revoada_de_trovoes")
            sol = 0
            for qi, q in enumerate(qs):
                a = q[..., 3] > 0
                if normal and (a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any()):
                    msg.append(f"quadro {qi + 1} encosta na borda")
                cod = (q[..., 0].astype(np.int64) << 16) | (q[..., 1].astype(np.int64) << 8) | q[..., 2]
                cod = np.where(a, cod + 1, 0)
                sol += int(soltos(cod).sum())
                if normal:   # contorno: todo pixel opaco que encosta no vazio tem de ser contorno ou faisca
                    borda = a & viz4(~a)
                    cont = np.array(pal_corvo(nome != "corvos")[0])
                    fa = [np.array(c) for c in pal_corvo(nome != "corvos")[C_FA1 - 1:]]
                    ok = (q[..., :3] == cont).all(axis=2)
                    for c in fa:
                        ok |= (q[..., :3] == c).all(axis=2)
                    if (borda & ~ok).any():
                        msg.append(f"quadro {qi + 1} com contorno aberto ({int((borda & ~ok).sum())} px)")
            if F is not None:   # pixel solto que nao e faisca (no buffer de origem)
                ruins = sum(int(soltos(t.idx, t.fa).sum()) for t in F[nome]["anims"][an][0])
                if ruins:
                    msg.append(f"{ruins} pixels soltos")
            cores = len({tuple(p) for p in img[img[..., 3] > 0][:, :3].tolist()})
            print(f"  {d['arquivo']:32s} {img.shape[1]:4d}x{img.shape[0]:<3d} n={n} fps={d['fps']:2d} tons={cores:2d} "
                  f"menor_dif={menor:5.1%} soltos(faisca)={sol:3d} {'OK' if not msg else 'FALHA: ' + '; '.join(msg)}")
            if msg:
                falhas.append((d["arquivo"], msg))
    return falhas


def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    PREVIAS.mkdir(parents=True, exist_ok=True)
    F = None
    if "--conferir" not in sys.argv:
        F = folhas()
        for nome, f in F.items():
            tiras = {}
            for an, (qs, (w, h), fps, loop, anc) in f["anims"].items():
                quadros = [rgba(t, f["paleta"]) for t in qs]
                for q in quadros:
                    assert q.shape == (h, w, 4), (nome, an, q.shape)
                Image.fromarray(np.concatenate(quadros, axis=1), "RGBA").save(SAIDA / f"{nome}_{an}.png",
                                                                              optimize=True)
                tiras[an] = quadros
            previa(nome, f, tiras)
        with open(SAIDA / "indice_magias.json", "w", encoding="utf-8", newline="\n") as fp:
            json.dump(indice(F), fp, ensure_ascii=False, indent=1)
            fp.write("\n")
    falhas = conferir(F)
    if falhas:
        print("FALHAS:", falhas)
        sys.exit(1)
    print("tudo certo")


if __name__ == "__main__":
    main()

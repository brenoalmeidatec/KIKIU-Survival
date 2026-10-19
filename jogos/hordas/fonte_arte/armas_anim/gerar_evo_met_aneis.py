#!/usr/bin/env python3
"""Gera as folhas animadas das evolucoes de meteoro e de anel da v2 (grupo "evo_met_aneis").

Contrato: docs/combate_v2/SPEC_ARTE.md. Reaproveita as primitivas aprovadas de gerar_meteoros.py e gerar_aneis.py
(mesma pasta, importadas sem alteracao) e desenha por cima delas as formas novas de cada evolucao.

Meteoros evoluidos (3 tiras cada):  <id>_queda.png 8q 16 fps loop (aponta para a direita, cabeca a 3/4 da largura),
                                    <id>_impacto.png 8q 15 fps 72x72, <id>_marca.png 4q 8 fps 48x32
  pedreira_ardente   rocha de lava com duas pedras em orbita
  cometa_duplo       dois cometas de gelo que se trancam no voo
  eclipse_negro      esfera de vazio com coroa rosa de eclipse
  juizo_final        rocha envolta em fogo sagrado dourado; no impacto, coluna de luz do ceu
Aneis evoluidos (1 tira cada):      <id>_expandir.png 6q 20 fps, celula do tamanho da imagem parada
  estrondo           duas linhas de ouro com raios vermelhos e pedrinhas arremessadas
  terra_partida      blocos de rocha que se levantam com fendas de lava
  juramento_sagrado  coroa de espinhos de luz, raios violeta e runas
A frente dos aneis segue FRENTE_ANEL = [0.16, 0.47, 0.69, 0.84, 0.94, 1.0] (o codigo escolhe o quadro por ela).

Indice: jogos/hordas/projeto/assets/v2/armas_anim/indice_evo_met_aneis.json. Previas: docs/combate_v2/previas/<id>.gif.
Semente fixa, sem rede.  Rodar:  python -I gerar_evo_met_aneis.py
"""
import json
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))   # python -I nao poe a pasta do script no caminho
sys.dont_write_bytecode = True                              # sem __pycache__ na pasta da fonte

import numpy as np  # noqa: E402

import gerar_aneis as A  # noqa: E402
import gerar_meteoros as M  # noqa: E402

RAIZ = Path(__file__).resolve().parents[4]
SAIDA = RAIZ / "jogos/hordas/projeto/assets/v2/armas_anim"
PREVIAS = RAIZ / "docs/combate_v2/previas"
SEMENTE = 20261019 + 777
FRENTE_ANEL = [0.16, 0.47, 0.69, 0.84, 0.94, 1.0]
assert A.R == FRENTE_ANEL, "a linha do tempo dos aneis mudou em gerar_aneis.py"
PI, TAU = math.pi, 2 * math.pi
cor, cores = M.cor, M.cores


# ================================================================ meteoros: queda

def rastros(f, lista, t, rs, rz):
    """Varios rastros somados (o mais quente vence) e quantizados nos mesmos tons."""
    h, w = f.shape[:2]
    calor = np.full((h, w), -1.0)
    for hx, hy, r, L in lista:
        c = M.campo_rastro(w, h, hx, hy, r, L, t, rz, **M.params_rastro(rs))
        calor = np.maximum(calor, c)
    M.faixas(f, calor, rs["tons"], rs["lim"])
    M.limpa(f)


def queda_pedreira(d, t, ax, ay, rz, rz_cab, semente):
    w, h = d["queda"]
    f = M.novo(w, h)
    p = {k: cor(v) for k, v in d["rocha"].items()}
    r = d["r"]
    # duas pedras em orbita (fecham a volta em NQ quadros), uma na frente e outra atras da rocha
    sat = []
    for k in range(2):
        a = 0.5 + t * TAU / M.NQ + k * PI
        sat.append((ax - 6 + 4.0 * math.cos(a), ay + 8.6 * math.sin(a), math.cos(a)))
    rs = d["rastro"]
    rastros(f, [(ax, ay, r, rs["L"])] + [(x, y, 2.4, 10) for x, y, _ in sat], t, rs, rz)
    M.brasas(f, semente + 7, ax, ay, r, rs["L"], t, d["brasas"], n=8, vel=(rs["L"] / 10, rs["L"] / 6))
    for k, (x, y, z) in enumerate(sat):
        if z < 0:
            M.cabeca_rocha(f, x, y, 2.3, t, p, crateras=False, forma=1 + k)
    M.cabeca_rocha(f, ax, ay, r, t, p, crateras=True, veios=cor(d["veios"]), veios2=cor(d["veios2"]), forma=3)
    for k, (x, y, z) in enumerate(sat):
        if z >= 0:
            M.cabeca_rocha(f, x, y, 2.3, t, p, crateras=False, forma=1 + k)
    return f


def queda_duplo(d, t, ax, ay, rz, rz_cab, semente):
    w, h = d["queda"]
    f = M.novo(w, h)
    p = {k: cor(v) for k, v in d["cristal"].items()}
    ph = t * TAU / M.NQ
    sep = 4.4 + 1.1 * math.cos(ph)
    a = (ax + 1.6 * math.sin(ph), ay - sep, 4.6, d["rastro"]["L"])
    b = (ax - 4 - 1.6 * math.sin(ph), ay + sep, 3.6, d["rastro"]["L"] - 5)
    rs = d["rastro"]
    rastros(f, [a, b], t, rs, rz)
    cb = cor(d["brilho_brasa"])
    M.brasas(f, semente + 7, a[0], a[1], a[2], a[3], t, d["brasas"], n=6, vel=(3, 5), cristal=cb)
    M.brasas(f, semente + 8, b[0], b[1], b[2], b[3], t, d["brasas"], n=5, vel=(3, 4.5), cristal=cb)
    # quem esta na frente (sin > 0 => o de cima vem para a frente) e desenhado por ultimo
    ordem = [b, a] if math.sin(ph) >= 0 else [a, b]
    for i, (x, y, r, _) in enumerate(ordem):
        M.cabeca_cristal(f, x, y, r, (t + M.NQ // 2 * (x == b[0])) % M.NQ, p)
    return f


def queda_eclipse(d, t, ax, ay, rz, rz_cab, semente):
    w, h = d["queda"]
    f = M.novo(w, h)
    r = d["r"]
    rs = d["rastro"]
    rastros(f, [(ax, ay, r, rs["L"])], t, rs, rz)
    M.brasas(f, semente + 7, ax, ay, r, rs["L"], t, d["brasas"], n=10, vel=(rs["L"] / 10, rs["L"] / 6),
             cristal=cor(d["coroa"][0]))
    p = {k: cor(v) for k, v in d["vazio"].items()}
    M.cabeca_vazio(f, ax, ay, r, t, p, rz_cab)
    # coroa do eclipse: chamas rosa curtas por fora do contorno, que mudam a cada quadro
    X, Y = M.grade(w, h)
    dx, dy = X - (ax + 0.5), Y - (ay + 0.5)
    dd = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    ph = 2 * PI * t / M.NQ
    pulso = 0.95 + 0.25 * math.sin(ph)          # a coroa inteira cresce e encolhe
    n = rz_cab(np.cos(th) * 3 + math.cos(ph) * 1.4 + 17, np.sin(th) * 3 + math.sin(ph) * 1.4 + 17)
    lado = np.clip(np.cos(th - 0.2) + 0.45, 0, 1.2)
    topo = r + 1.0 + lado * (0.8 + 3.2 * np.clip(n - 0.35, 0, 1)) * pulso
    vazio = f[:, :, 3] == 0
    coroa = vazio & (dd > r + 0.8) & (dd <= topo)
    c1, c2 = cor(d["coroa"][0]), cor(d["coroa"][1])
    M.pinta(f, coroa & (dd > r + 2.3), c2)
    M.pinta(f, coroa & (dd <= r + 2.3), c1)
    return f


def queda_juizo(d, t, ax, ay, rz, rz_cab, semente):
    w, h = d["queda"]
    f = M.novo(w, h)
    r = d["r"]
    rs = d["rastro"]
    rastros(f, [(ax, ay, r, rs["L"])], t, rs, rz)
    M.brasas(f, semente + 7, ax, ay, r, rs["L"], t, d["brasas"], n=11, vel=(rs["L"] / 10, rs["L"] / 6))
    # aura de fogo sagrado em volta da rocha (frente e lados), borbulhando a cada quadro
    X, Y = M.grade(w, h)
    dx, dy = X - (ax + 0.5), Y - (ay + 0.5)
    dd = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    ph = 2 * PI * t / M.NQ
    pulso = 0.93 + 0.2 * math.sin(ph)         # a aura inteira respira
    n = rz_cab(np.cos(th) * 4.0 + math.cos(ph) * 1.3 + 5, np.sin(th) * 4.0 + math.sin(ph) * 1.3 + 5)
    # chamas finas na frente, linguas maiores em cima e embaixo que puxam para tras
    lado = np.abs(np.sin(th)) * np.clip(1.2 - np.cos(th), 0, 1.2)
    borda = r + 1.6 * pulso + (0.5 + 1.7 * lado) * (0.7 + 2.6 * np.clip(n - 0.25, 0, 1) ** 1.3) * pulso
    aura = (dd <= borda) & (np.cos(th) > -0.8)
    ta = cores(*d["aura"])
    q = (dd - r) / np.maximum(borda - r, 0.5)
    M.pinta(f, aura & (q > 0.72), ta[2])
    M.pinta(f, aura & (q <= 0.72), ta[1])
    M.pinta(f, aura & (q <= 0.34), ta[0])
    M.limpa(f)
    p = {k: cor(v) for k, v in d["rocha"].items()}
    M.cabeca_rocha(f, ax, ay, r, t, p, crateras=True, veios=cor(d["veios"]), veios2=cor(d["aura"][1]), forma=4)
    # cintilacoes sagradas em cruz que se revezam no rastro
    brilho = cor(d["aura"][0])
    for k, (u, v) in enumerate([(0.35, -0.55), (0.6, 0.5), (0.85, -0.2), (0.5, 0.05)]):
        if (k + t // 2) % 2:
            continue
        x = ax - u * rs["L"] - (t % 4) * 1.5
        y = ay + v * r
        M.mais(f, x, y, brilho, 1)
    return f


# ================================================================ meteoros: impacto extra

def coluna_luz(quadros, tons):
    """Coluna de luz que desce do ceu sobre o impacto (quadros 0-2), estreitando."""
    S = quadros[0].shape[0]
    c = S // 2
    for t, (larg, alt) in enumerate([(4, 1.0), (3, 0.9), (2, 0.7)]):
        f = quadros[t]
        topo = int(c - c * alt)
        for y in range(max(topo, 0), c - 2):
            meio = larg - (1 if (y - topo) < 3 and t > 0 else 0)
            for x in range(c - larg - 1, c + larg + 1):
                dxp = abs(x + 0.5 - c)
                if dxp <= meio - 1.5:
                    M.px(f, x, y, tons[0])
                elif dxp <= meio + 0.5 and f[y, x, 3] == 0 or dxp <= meio - 0.5:
                    M.px(f, x, y, tons[1])
        M.limpa(f)


# ================================================================ meteoros: definicoes

def def_meteoros():
    return [
        dict(sprite="pedreira_ardente", queda=(36, 26), desenha=queda_pedreira, r=6.4,
             rocha=dict(cont="#24181d", esc="#392c2e", med="#544644", clr="#784c37", bri="#a8735a"), veios="#f4ad3f", veios2="#dc4c12",
             rastro=dict(tons=cores("#f3c05f", "#ea8622", "#dc4c12", "#7b2a14", "#4e140f"), lim=[0.95, 0.7, 0.48, 0.3, 0.15],
                         L=24, larg=1.2, tremor=0.4, pulso=0.2), brasas=cores("#f3c05f", "#ea8622", "#dc4c12", "#7b2a14"),
             impacto=dict(fogo=M.FOGO, anel=cores("#ea8622", "#dc4c12", "#7b2a14"),
                          faisca=cores("#fffdf1", "#f3c05f", "#ea8622", "#7b2a14"), fumaca=M.FUMACA_FOGO,
                          pedaco=cores("#544644", "#392c2e"), n_pedacos=15, n_faiscas=16, n_fumaca=9, bola=1.05,
                          poeira_chao=True),
             marca=dict(chao=cores("#1c1410", "#2e1a1c", "#392c2e"), trinca=cores("#f4ad3f", "#dc4c12", "#7b2a14", None),
                        brasas=cores("#f3c05f", "#dc4c12"), rx=20, n_trincas=8)),
        dict(sprite="cometa_duplo", queda=(50, 24), desenha=queda_duplo,
             cristal=dict(cont="#1f3a66", esc="#4781cb", med="#67a1e3", clr="#88bdef", bri="#e6f6ff"),
             rastro=dict(tons=cores("#e6f6ff", "#b0dcf8", "#88bdef", "#67a1e3", "#4781cb"), lim=[1.0, 0.72, 0.5, 0.31, 0.17],
                         L=32, larg=1.15, onda=1.5, ciclos=1.2), brasas=cores("#e6f6ff", "#b0dcf8", "#88bdef", "#67a1e3"), brilho_brasa="#e6f6ff",
             impacto=dict(fogo=cores("#ffffff", "#e6f6ff", "#b0dcf8", "#67a1e3", "#4781cb"), anel=cores("#e6f6ff", "#b0dcf8", "#67a1e3"),
                          faisca=cores("#ffffff", "#e6f6ff", "#b0dcf8", "#67a1e3"), fumaca=cores("#e6f6ff", "#a2cde3", "#6a9fc7"),
                          cristal=cores("#e6f6ff", "#67a1e3", "#1f3a66"), n_cristais=9, n_faiscas=12, n_fumaca=6, bola=0.95),
             marca=dict(chao=cores("#e6f6ff", "#a2cde3", "#6a9fc7"), trinca=cores("#ffffff", "#e6f6ff", "#d9f6ff", None),
                        espetos=cores("#e6f6ff", "#67a1e3"), rx=20, n_trincas=8)),
        dict(sprite="eclipse_negro", queda=(56, 34), desenha=queda_eclipse, r=10.5,
             vazio=dict(cont="#120f19", miolo="#140a1a", sombra="#24181d", aro2="#782d70", aro="#d34c76", reflexo="#9c7384"),
             coroa=["#f08aa8", "#d34c76"],
             rastro=dict(tons=cores("#d34c76", "#9c7384", "#782d70", "#4e0f64", "#2a1235"), lim=[0.95, 0.7, 0.48, 0.3, 0.16],
                         L=40, larg=1.12, esc=1.5, onda=2.2, ciclos=1.0), brasas=cores("#f08aa8", "#b8a2ae", "#9c7384", "#754f7a"),
             impacto=dict(fogo=cores("#fef6f6", "#d34c76", "#782d70", "#4e0f64", "#250c2c"), anel=cores("#d34c76", "#782d70", "#4e0f64"),
                          faisca=cores("#fef6f6", "#f08aa8", "#9c7384", "#754f7a"), fumaca=cores("#754f7a", "#4e0f64", "#250c2c"),
                          vazio=cores("#120f19", "#d34c76"), pedaco=cores("#392c2e", "#24181d"), n_pedacos=6, n_faiscas=20,
                          n_fumaca=9, bola=1.12),
             marca=dict(chao=cores("#120f19", "#1f172b", "#2a1d3b"), trinca=cores("#f08aa8", "#d34c76", "#4e0f64", None),
                        brilhos=cores("#f08aa8", "#d34c76"), rx=20, n_trincas=8)),
        dict(sprite="juizo_final", queda=(60, 36), desenha=queda_juizo, r=8.6,
             rocha=dict(cont="#24181d", esc="#392c2e", med="#572b22", clr="#784c37", bri="#b07a50"), veios="#fff1b0",
             aura=["#fffdf1", "#f3c05f", "#ea8622"],
             rastro=dict(tons=cores("#fffdf1", "#f0d798", "#f3c05f", "#ea8622", "#d34c76"), lim=[1.1, 0.8, 0.55, 0.34, 0.17],
                         L=40, larg=1.25, ruido=0.5, esc=1.4, tremor=0.4, pulso=0.2), brasas=cores("#fffdf1", "#f3c05f", "#ea8622", "#d34c76"),
             impacto=dict(fogo=cores("#fffdf1", "#f0d798", "#f3c05f", "#ea8622", "#c43337"), anel=cores("#f0d798", "#f3c05f", "#ea8622"),
                          faisca=cores("#fffdf1", "#f0d798", "#f3c05f", "#ea8622"), fumaca=cores("#8a7468", "#62585d", "#474441"),
                          pedaco=cores("#572b22", "#392c2e"), n_pedacos=8, n_faiscas=14, n_fumaca=8, bola=1.2,
                          tipo_faisca="brilho"),
             coluna=cores("#fffdf1", "#f3c05f"),
             marca=dict(chao=cores("#241612", "#3b2418", "#5d3a26"), trinca=cores("#fffdf1", "#f3c05f", "#ea8622", None),
                        brilhos=cores("#fffdf1", "#f3c05f"), rx=20, n_trincas=8)),
    ]


def queda(d, semente):
    w, h = d["queda"]
    ax, ay = int(w * 3 / 4), h // 2
    rg = np.random.default_rng(semente)
    rz = [M.Ruido(rg, 4, 64), M.Ruido(rg, 4, 64), M.Ruido(rg)]
    rz_cab = M.Ruido(rg)
    quadros = []
    for t in range(M.NQ):
        f = d["desenha"](d, t, ax, ay, rz, rz_cab, semente)
        M.limpa(f)
        quadros.append(f)
    return quadros, [ax, ay]


def contorno_cabeca(q, ax, ay, cont):
    """A cabeca tem contorno escuro: andando da ancora para a direita, ha um pixel do contorno antes da coroa/aura
    (ou do vazio)."""
    trecho = q[max(ay - 7, 0):ay + 8, ax:, :]
    return bool(((trecho[..., 3] > 0) & (trecho[..., :3] == np.array(cont)).all(axis=-1)).any())


# ================================================================ aneis: motivos

def raio_grosso(t, rq, x, y, dx, dy, nseg, comp, c_nucleo, c_brilho, dens=1.0):
    """Raio de 2 px: nucleo claro com brilho colorido ao lado; a ponta fica so no brilho."""
    pts = A.raio_zz(t, rq, x, y, dx, dy, nseg, comp, cor=c_brilho, cor_ponta=c_brilho, dens=dens)
    t.linha([(px_ + 1, py_) for px_, py_ in pts[:-1]], c_brilho, dens, True)
    t.linha(pts[:-1], c_nucleo, dens, True)
    return pts


def m_estrondo(t, fx, rq):
    """Estrondo: duas linhas de ouro com halo, raios vermelhos que estalam e pedrinhas arremessadas."""
    q = t.q
    nesp = A.ruido(fx, 0.25)
    rochas = [(fx.uniform(0, TAU), fx.uniform(0.7, 1.3), fx.uniform(0.6, 1.2)) for _ in range(14)]
    ang_raio = [k * TAU / 8 + PI / 8 + fx.uniform(-0.2, 0.2) for k in range(8)]
    cx, cy = t.ponto(0, 0)
    if q == 0:
        t.pinta(t.d < 0.24, 4, 0.5)
        A.clarao(t, 0.15, [1, 2, 3])
        for th in ang_raio[::2]:
            dx, dy = t.radial(th)
            A.raio_zz(t, rq, cx + dx * 4, cy + dy * 3, dx, dy, 3, 3, cor=5, cor_ponta=6)
        A.estrela(t, cx, cy, 5, 1, 2)
        for th, tam, sp in rochas[:5]:
            x, y = t.ponto(0.19, th)
            A.pedra(t, x, y - 2, 1, 7, 8)
        return
    Rq, E, D = A.R[q], A.ESP[q], A.DENS[q]
    qb = A.esfarela(fx, A.QUEBRA[q])
    A.onda(t, [4, 4, 4], Rq, E * 1.3, max(0.5 * D, 0.25), nesp=lambda th: nesp(th, q), seg=qb)
    A.onda(t, [1, 2, 3], Rq, max(E * 0.4, 0.035), D, seg=qb)               # linha de fora = a frente
    ri = Rq * 0.86
    A.onda(t, [1, 2, 3], ri, max(E * 0.32, 0.03), D, seg=qb, cor_trilha=4, tri=A.TRI[q] * 0.7, dtri=A.DTRI[q] * 0.7)
    # raios vermelhos: atravessam as duas linhas; no fim correm para dentro (a frente ja esta na borda)
    nseg = [0, 4, 5, 5, 4, 3][q]
    for k, th in enumerate(ang_raio):
        if q == 5 and k % 2:
            continue
        th = th + 0.05 * q + rq.uniform(-0.06, 0.06)
        dx, dy = t.radial(th)
        escala = math.hypot(t.W / 2 * math.cos(th), t.H / 2 * math.sin(th))   # px por unidade da elipse
        if q <= 3:   # de dentro da linha interna ate um pouco alem da frente
            r0 = ri - [0, 0.22, 0.2, 0.17][q]
            x, y = t.ponto(r0, th)
            sentido = 1
            comp = (Rq + [0, 0.0, 0.05, 0.06][q] - r0) * escala / nseg
        else:
            x, y = t.ponto(Rq - E * 0.3, th)
            sentido = -1
            comp = [0, 0, 0, 0, 4.5, 3.5][q]
        pts = raio_grosso(t, rq, x, y, dx * sentido, dy * sentido, nseg, comp, 5, 6, D)
        if len(pts) > 3 and q <= 4:
            bx, by = pts[2]
            g = rq.uniform(0.6, 1.0) * rq.choice([-1, 1])
            c, s_ = math.cos(g), math.sin(g)
            A.raio_zz(t, rq, bx, by, (dx * c - dy * s_) * sentido, (dx * s_ + dy * c) * sentido, 2, comp * 0.8,
                      cor=5, cor_ponta=6, dens=D)
    for th, tam, sp in rochas:
        s = max(1, int(round([0, 3, 3, 2, 2, 1][q] * tam)))
        r = min(Rq + [0, 0.0, 0.05, 0.04, 0.0, -0.05][q] * sp, 0.97)
        x, y = t.ponto(r, th)
        A.pedra(t, x, y - [0, 2, 3, 3, 2, 1][q] * sp, s, 7, 8, D)
    for _ in range([0, 6, 8, 8, 6, 4][q]):
        th = rq.uniform(0, TAU)
        x, y = t.ponto(Rq + rq.uniform(-0.2, 0.0), th)
        t.px(x, y, 2, True)
        t.px(x + 1, y, 2, True)


def desce(m, k):
    """Mascara deslocada k px para baixo (sem dar a volta)."""
    out = np.zeros_like(m)
    out[k:] = m[:-k]
    return out


def bloco(t, x, y, s, seed, dens=1.0, lava=True):
    """Bloco de rocha arrancado do chao: face de cima clara, lado escuro, fenda de lava acesa embaixo."""
    rg = random.Random(seed)
    # face de cima: poligono irregular achatado e inclinado; o corpo e a face extrudada para baixo
    n = rg.choice([5, 5, 6])
    inc = rg.uniform(-0.35, 0.35)
    topo = []
    for i in range(n):
        a = i * TAU / n + rg.uniform(-0.3, 0.3)
        rr = s * rg.uniform(0.75, 1.1)
        px_, py_ = math.cos(a) * rr, math.sin(a) * rr * 0.55
        topo.append((x + px_, y - s * 0.35 + py_ + inc * px_))
    alt = max(2, int(round(s * rg.uniform(0.7, 1.0))))
    T = t._mascara(lambda d: d.polygon(topo, fill=255))
    if not T.any():
        return
    P = T.copy()
    for k in range(1, alt + 1):
        P |= desce(T, k)
    if lava:
        baixo = (desce(P, 1) | desce(P, 2)) & ~P & (t.ys > y - s * 0.35)
        t.pinta(baixo & ((t.idx == 0) | (t.idx == 4)), 2, dens)
    lado = P & ~T
    t.pinta(lado & (t.xs <= x + s * 0.15), 6, dens)
    t.pinta(lado & (t.xs > x + s * 0.15), 7, dens)
    t.pinta(T, 5, dens)
    if s >= 4:   # trinca na face de cima
        a = rg.uniform(-0.5, 0.5)
        t.linha([(x - s * 0.45, y - s * 0.45 + a), (x - s * 0.05, y - s * 0.3), (x + s * 0.35, y - s * 0.5 - a)], 6, dens)


def m_terra(t, fx, rq):
    """Terra partida: fendas de lava correm para fora e blocos de rocha se levantam na frente e afundam atras."""
    q = t.q
    rachas = A.gera_rachas(fx)
    nb = 19
    blocos = [(k * TAU / nb + fx.uniform(-0.1, 0.1), fx.uniform(0.65, 1.4), fx.randint(0, 10 ** 6)) for k in range(nb)]
    pedras = [(fx.uniform(0, TAU), fx.uniform(0.7, 1.3)) for _ in range(12)]
    Rq, E, D = A.R[q], A.ESP[q], A.DENS[q]
    if q == 0:
        t.pinta(t.d < 0.24, 4, 0.5)
        A.clarao(t, 0.15, [1, 2, 3])
    else:
        A.rastro(t, Rq - E * 0.6, A.TRI[q], 4, A.DTRI[q])
    rmax = Rq - 0.03 if q > 0 else 0.15
    rmin = [0, 0, 0.3, 0.4, 0.55, 0.75][q]
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
            c = 1 if idade < 0.12 and q < 5 else (2 if idade < 0.32 else 3)
            dens = 1.0 if ra >= rmin + 0.1 else 0.5
            pa, pb = t.ponto(ra, ta), t.ponto(rb, tb)
            t.linha([pa, pb], c, dens)
            if rb < 0.5 and q <= 3:
                t.linha([(pa[0] + 1, pa[1]), (pb[0] + 1, pb[1])], 2 if c == 1 else c, dens)
    # blocos: a borda de fora de cada bloco fica na frente do anel
    sq = [2.4, 4.5, 5.5, 5.5, 4.6, 3.4][q]
    lift = [1, 2, 3, 2, 1, 0][q]
    lista = []
    for i, (th, tam, seed) in enumerate(blocos):
        if q == 0 and i % 4:
            continue
        s = sq * tam
        th = th + rq.uniform(-0.02, 0.02)
        dx, dy = math.cos(th), math.sin(th)
        rn = s / math.hypot(t.W / 2 * dx, t.H / 2 * dy) * 1.05   # meio bloco em unidades da elipse
        rc = (0.17 if q == 0 else Rq) - rn
        x, y = t.ponto(rc, th)
        lista.append((y, x, s, seed + q))
    for y, x, s, seed in sorted(lista):
        bloco(t, x, y - lift, s, seed, 1.0 if q < 5 else 0.62, lava=q <= 3)
    if 1 <= q <= 4:
        for th, sp in pedras:
            r = min(Rq + [0, 0.05, 0.06, 0.04, 0.0][q] * sp, 0.96)
            x, y = t.ponto(r, th)
            A.pedra(t, x, y - [0, 4, 6, 5, 3][q] * sp, 1, 5, 7)


def m_juramento(t, fx, rq):
    """Juramento sagrado: coroa de espinhos de luz trancada, raios violeta, runas de ouro e estrelas."""
    q = t.q
    ang_raio = [k * TAU / 7 + fx.uniform(-0.2, 0.2) for k in range(7)]
    ang_runa = [i * PI / 4 + PI / 8 + fx.uniform(-0.08, 0.08) for i in range(8)]
    nesp = A.ruido(fx, 0.2)
    espinhos = [(k * TAU / 22 + fx.uniform(-0.05, 0.05), fx.uniform(0.75, 1.25), 1, 1) for k in range(22)]
    cx, cy = t.ponto(0, 0)
    if q == 0:
        t.pinta(t.d < 0.24, 4, 0.5)
        A.clarao(t, 0.15, [1, 2, 3])
        for k in range(8):
            th = k * PI / 4
            t.linha([t.ponto(0.12, th), t.ponto(0.4 if k % 2 == 0 else 0.27, th)], 7 if k % 2 == 0 else 3)
        A.estrela(t, cx, cy, 6, 1, 7)
        for th in ang_raio[:3]:
            x, y = t.ponto(0.2, th)
            A.raio_zz(t, rq, x, y, 0, -1, 2, 3, cor=5, cor_ponta=6)
        return
    Rq, E, D = A.R[q], A.ESP[q], A.DENS[q]
    qb = A.esfarela(fx, A.QUEBRA[q])
    LQ = [0, 3, 5, 6, 5, 3.5][q]
    ln = LQ / (t.W / 2)
    amp = E * 0.3
    w = max(E * 0.3, 0.035)
    rc = Rq - ln * 0.85 - amp - w / 2
    th, d = t.th, t.d
    ok = qb(th) if qb is not None else np.ones_like(th, bool)
    A.onda(t, [4, 4, 4], Rq, E * 1.2 + ln, max(0.45 * D, 0.25), nesp=lambda a: nesp(a, q), seg=qb)
    # dois galhos trancados
    for sinal, (ce, ci) in ((-1, (2, 3)), (1, (1, 2))):
        rs = rc + sinal * amp * np.sin(10 * th + 0.6 * q)
        dist = d - rs
        t.pinta((np.abs(dist) <= w / 2) & (dist >= 0) & ok, ce, D)
        t.pinta((np.abs(dist) <= w / 2) & (dist < 0) & ok, ci, D)
    # espinhos: a maioria para fora (as pontas fazem a frente), alguns para dentro
    lista = []
    for a, tam, lado, inc in espinhos:
        a += rq.uniform(-0.02, 0.02)
        if qb is not None and not qb(np.array(a)):
            continue
        x, y = t.ponto(rc + lado * (amp + w / 2), a)
        lista.append((y, x, a, LQ * (tam if lado > 0 else tam * 0.6), lado, inc))
    for by, bx, a, L, lado, inc in sorted(lista):
        if L < 1.5:
            continue
        rx_, ry_ = t.radial(a)
        dx, dy = rx_ * lado, ry_ * lado
        dx, dy = dx + inc * 0.35 * -dy, dy + inc * 0.35 * dx
        n = math.hypot(dx, dy)
        dx, dy = dx / n, dy / n
        bw = max(1.2, L * 0.24)
        p1 = (bx - dy * bw, by + dx * bw)
        p2 = (bx + dy * bw, by - dx * bw)
        if p2[0] + p2[1] < p1[0] + p1[1]:
            p1, p2 = p2, p1
        tip = (bx + dx * L, by + dy * L)
        t.poligono([p1, p2, tip], 3, D)
        t.poligono([p1, (bx, by), tip], 1, D)
    # raios violeta que sobem da coroa (lugar novo a cada quadro)
    comp = [0, 4, 5, 5, 4, 3][q]
    nseg = [0, 3, 4, 3, 3, 2][q]
    for k, a in enumerate(ang_raio):
        if q == 5 and k % 2:
            continue
        a = a + 0.12 * q + rq.uniform(-0.08, 0.08)
        x, y = t.ponto(rc, a)
        tx, ty = -math.sin(a), math.cos(a) * t.H / t.W
        lado = rq.choice([-1, 1])
        dx, dy = tx * 0.45 * lado, -0.9 + ty * 0.45 * lado
        n = math.hypot(dx, dy)
        raio_grosso(t, rq, x, y - 1, dx / n, dy / n, nseg, comp, 5, 6, D)
    if q in (2, 3, 4):
        for i, a in enumerate(ang_runa):
            x, y = t.ponto(rc - E - 0.1, a)
            A.runa(t, A.GLIFOS[(i + q) % len(A.GLIFOS)], x, y, 7, 1.0 if q < 4 else 0.62)
    tam_e = [0, 3, 4, 4, 3, 2][q]
    for i, a in enumerate([-PI / 2, PI / 2, 0, PI]):
        x, y = t.ponto(rc, a)
        A.estrela(t, x, y, tam_e, 1, 7)
    for _ in range([0, 5, 7, 7, 5, 3][q]):
        a = rq.uniform(0, TAU)
        x, y = t.ponto(Rq + rq.uniform(-0.25, -0.02), a)
        t.px(x, y, 7, True)
        t.px(x, y + 1, 7, True)


ANEIS = [
    ("estrondo", (140, 95),
     [(255, 250, 225), (255, 215, 120), (225, 150, 60), (130, 85, 40), (255, 120, 90), (235, 45, 35),
      (205, 170, 145), (130, 100, 85)], m_estrondo),
    ("terra_partida", (150, 106),
     [(255, 240, 170), (255, 165, 60), (225, 85, 35), (120, 80, 55), (220, 180, 145), (150, 108, 82),
      (95, 66, 52)], m_terra),
    ("juramento_sagrado", (140, 94),
     [(255, 250, 235), (235, 220, 185), (185, 160, 120), (110, 95, 75), (230, 185, 255), (165, 95, 245),
      (255, 210, 110)], m_juramento),
]


def verifica_frente(caminho, W, H):
    """A frente (borda de fora mais comum por angulo) segue FRENTE_ANEL nos quadros 2 a 6."""
    from PIL import Image
    a = np.array(Image.open(caminho).convert("RGBA"))
    ys, xs = np.mgrid[0:H, 0:W]
    nx, ny = (xs + 0.5 - W / 2) / (W / 2), (ys + 0.5 - H / 2) / (H / 2)
    dn = np.hypot(nx, ny)
    setor = ((np.arctan2(ny, nx) + PI) / TAU * 48).astype(int) % 48
    erros, medidas = [], []
    for q in range(1, 6):
        op = a[:, q * W:(q + 1) * W, 3] > 0
        maxs = [float(dn[op & (setor == k)].max()) for k in range(48) if (op & (setor == k)).any()]
        med = float(np.median(maxs)) if maxs else 0.0
        medidas.append(med)
        if not (FRENTE_ANEL[q] - 0.06 <= med <= FRENTE_ANEL[q] + 0.05):
            erros.append(f"frente do quadro {q + 1} em {med:.2f} (esperado {FRENTE_ANEL[q]:.2f})")
    return erros, medidas


# ================================================================ main

def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    PREVIAS.mkdir(parents=True, exist_ok=True)
    indice = {"folhas": {}}
    erros = []
    for i, d in enumerate(def_meteoros()):
        base = SEMENTE + i * 1000
        nome = d["sprite"]
        q_queda, anc = queda(d, base + 1)
        q_imp = M.impacto(dict(d["impacto"]), 72, base + 2)
        if d.get("coluna"):
            coluna_luz(q_imp, d["coluna"])
        q_marca = M.marca(d["marca"], base + 3)
        cont = cor((d.get("rocha") or d.get("cristal") or d.get("vazio"))["cont"])
        for k, q in enumerate(q_queda):
            if not contorno_cabeca(q, anc[0], anc[1], cont):
                erros.append(f"{nome}_queda.png: quadro {k} sem contorno escuro na frente da cabeca")
        anims = {}
        for anim, qs, fps, loop, ancora in (("queda", q_queda, M.FPS_QUEDA, True, anc),
                                            ("impacto", q_imp, 15, False, [36, 36]),
                                            ("marca", q_marca, 8, False, [24, 16])):
            arq = f"{nome}_{anim}.png"
            M.tira(qs).save(SAIDA / arq)
            h, w = qs[0].shape[:2]
            anims[anim] = {"arquivo": arq, "quadro": [w, h], "n": len(qs), "fps": fps, "loop": loop, "ancora": ancora}
        indice["folhas"][nome] = {"armas": [nome], "anims": anims}
        M.previa(PREVIAS / f"{nome}.gif", [(q_queda, M.FPS_QUEDA, 2), (q_imp, 15, 1), (q_marca, 8, 1)])
    print("verificando meteoros:")
    erros += M.verifica(indice)
    print("verificando aneis:")
    for nome, (W, H), paleta, motivo in ANEIS:
        quadros = A.gera_quadros(nome, W, H, paleta, motivo)
        arq = f"{nome}_expandir.png"
        M.tira(quadros).save(SAIDA / arq)
        A.grava_previa(quadros, W, H, PREVIAS / f"{nome}.gif")
        indice["folhas"][nome] = {"armas": [nome], "anims": {"expandir": {
            "arquivo": arq, "quadro": [W, H], "n": A.N, "fps": A.FPS, "loop": False, "ancora": [W // 2, H // 2]}}}
        e1, menor, soltos, ncor = A.verifica(SAIDA / arq, W, H, A.N)
        e2, med = verifica_frente(SAIDA / arq, W, H)
        erros += [f"{arq}: {e}" for e in e1 + e2]
        print(f"  {arq:34s} {W}x{H}  menor dif {menor:5.1%}  {ncor:2d} cores  soltos (faiscas) {soltos:3d}  "
              f"frente {' '.join(f'{m:.2f}' for m in med)}")
    with open(SAIDA / "indice_evo_met_aneis.json", "w", encoding="utf-8", newline="\n") as fp:
        json.dump(indice, fp, ensure_ascii=False, indent=2)
        fp.write("\n")
    if erros:
        print("PROBLEMAS:")
        for e in erros:
            print("  -", e)
        sys.exit(1)
    print("ok: todas as folhas passaram")


if __name__ == "__main__":
    main()

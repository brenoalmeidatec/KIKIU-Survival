#!/usr/bin/env python3
"""Gera as folhas animadas dos ataques INIMIGOS da v2 (grupo "perigo": chefes e elites).

Vermelho/carmim/roxo-escuro com brilho vermelho é a cor de PERIGO no jogo (nunca verde/azul, que são de aliado).
Contrato: docs/combate_v2/SPEC_ARTE.md. Folhas em jogos/hordas/projeto/assets/v2/armas_anim/:
  perigo_chuva_queda.png       8q 16 fps loop, 36x24, aponta para a direita (cabeça [27,12]): rocha sombria facetada
                               que gira, envolta em chama vermelho-escura, brasas que se soltam
  perigo_chuva_impacto.png     8q 15 fps, 64x64: clarão vermelho, onda achatada, lascas, fagulhas, fumaça escura
  perigo_estouro_impacto.png   6q 15 fps, 96x60 (elipse do chão): o chão racha e explode do centro para a borda
  perigo_investida_impacto.png 5q 15 fps, 32x20, âncora [16,14]: poeira que levanta e se desfaz, com pedrinhas
e o índice indice_perigo.json. Prévias GIF 4x em docs/combate_v2/previas/<id>.gif.

Usa as primitivas de gerar_meteoros.py (sem alterá-lo). Semente fixa, sem rede.
Rodar:  python -I gerar_perigo.py
"""
import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gerar_meteoros as gm  # noqa: E402
from gerar_meteoros import cor, cores, novo, px, pinta, linha, grade, borda4, Ruido, faixas, limpa, ponto2  # noqa: E402

SAIDA = gm.SAIDA
PREVIAS = gm.PREVIAS
SEMENTE = 20261019 + 777

# ---------------------------------------------------------------- paleta de perigo
CHAMA = cores("#ff7a5a", "#e8382e", "#b01e2a", "#7a1430", "#4a0e2a")       # quente -> frio
BRASA = cores("#ff7a5a", "#e8382e", "#b01e2a", "#7a1430")
ROCHA = dict(cont="#140a14", esc="#2a1424", med="#40202e", clr="#5c2c38", bri="#84404a")
FOGO_P = cores("#ffc4ae", "#ff5a3c", "#d42a2a", "#981632", "#561030")      # clarão/explosão
FUMACA_P = cores("#4e3446", "#33212f", "#1e131d")                         # clara, média, escura
LASCA = cores("#40202e", "#2a1424")
FAISCA = cores("#ffc4ae", "#ff5a3c", "#d42a2a", "#981632")
TRINCA_DESC = cor("#1e0c18")


# ---------------------------------------------------------------- 1) chuva: queda

def queda_chuva(semente, w=36, h=24, r=5.0, L=25):
    ax, ay = int(w * 3 / 4), h // 2
    rg = np.random.default_rng(semente)
    rz = [Ruido(rg, 4, 64), Ruido(rg, 4, 64), Ruido(rg)]
    rz_aura = Ruido(rg, 16, 16)
    p = {k: cor(v) for k, v in ROCHA.items()}
    X, Y = grade(w, h)
    dx, dy = X - (ax + 0.5), Y - (ay + 0.5)
    d = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    quadros = []
    for t in range(gm.NQ):
        f = novo(w, h)
        calor = gm.campo_rastro(w, h, ax, ay, r, L, t, rz, larg=1.25, tremor=0.5, pulso=0.22, ruido=0.45)
        faixas(f, calor, CHAMA, [0.98, 0.74, 0.5, 0.3, 0.14])
        # chama que envolve a rocha: um halo de línguas que tremulam (muda a cada quadro, fecha em NQ)
        ph = 2 * math.pi * t / gm.NQ
        n = rz_aura(np.cos(th) * 2.2 + math.cos(ph) * 1.8 + 4, np.sin(th) * 2.2 + math.sin(ph) * 1.8 + 4)
        tras = np.clip(-np.cos(th), 0, 1)      # mais grosso atrás e em cima (a chama é soprada para trás)
        alcance = r + 1.0 + 2.2 * (n - 0.35) + 1.4 * tras
        halo = (d <= alcance) & (f[:, :, 3] == 0)
        pinta(f, halo, CHAMA[3])
        pinta(f, (d <= alcance - 1.2) & halo, CHAMA[2])
        limpa(f)
        gm.brasas(f, semente + 7, ax, ay, r, L, t, BRASA, n=7, vel=(L / 10, L / 6))
        gm.cabeca_rocha(f, ax, ay, r, t, p, crateras=True, veios=cor("#ff5a3c"), veios2=cor("#b01e2a"), forma=3)
        limpa(f)
        quadros.append(f)
    return quadros, [ax, ay]


# ---------------------------------------------------------------- 1) chuva: impacto

def impacto_chuva(semente):
    cfg = dict(fogo=FOGO_P, anel=cores("#e8382e", "#b01e2a", "#7a1430"), faisca=FAISCA, fumaca=FUMACA_P,
               pedaco=LASCA, n_pedacos=8, n_faiscas=14, n_fumaca=8)
    return gm.impacto(cfg, 64, semente)


# ---------------------------------------------------------------- nuvem de bolhas (fumaça/poeira)

def bolhas(f, X, Y, puffs, tons, rz, lim, amp=0.35, esc=3.0, desloc=0.0):
    """Une círculos (x, y, r) num campo, corta pelo limiar (erosão) e sombreia com luz de cima-esquerda."""
    h, w = f.shape[:2]
    melhor = np.full((h, w), -9.0)
    sh = np.zeros((h, w))
    for (x, y, r) in puffs:
        if r <= 0.4:
            continue
        ddx, ddy = X - x, Y - y
        v = 1 - np.hypot(ddx, ddy * 1.1) / r
        m = v > melhor
        melhor = np.where(m, v, melhor)
        sh = np.where(m, (-ddx * 0.6 - ddy * 0.8) / r, sh)
    n = rz(X / esc + desloc, Y / esc + desloc * 0.5)
    vis = melhor + amp * (n - 0.5) * 2 > lim
    pinta(f, vis & (sh <= -0.25), tons[2])
    pinta(f, vis & (sh > -0.25) & (sh <= 0.3), tons[1])
    pinta(f, vis & (sh > 0.3), tons[0])
    return vis


def pedra(f, x, y, c_clr, c_esc, larg=2):
    """Pedrinha 2x2 (ou 3x2): linha de cima clara, de baixo escura (nenhum pixel solto)."""
    for a in range(larg):
        px(f, x + a, y, c_clr)
        px(f, x + a, y + 1, c_esc)


# ---------------------------------------------------------------- 2) estouro

def estouro(semente, W=96, H=60):
    rg = np.random.default_rng(semente)
    rzf = Ruido(rg)
    rzb = Ruido(rg)
    rzs = Ruido(rg)
    cx, cy = W // 2, H // 2
    rx, ry = W / 2 - 2, H / 2 - 3
    X, Y = grade(W, H)
    dx, dy = X - (cx + 0.5), Y - (cy + 0.5)
    th = np.arctan2(dy, dx)
    e = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2) + (rzb(X / 5, Y / 3.5) - 0.5) * 0.16

    def tela(u, v, z=0.0):     # u, v em unidades da elipse (-1..1)
        return cx + 0.5 + u * rx, cy + 0.5 + v * ry - z

    # trincas: polilinhas do centro até perto da borda, em zigue-zague, com galhos
    trincas = []
    nt = 11
    for i in range(nt):
        a = (i + rg.uniform(-0.3, 0.3)) * 2 * math.pi / nt
        comp = rg.uniform(0.75, 0.97)
        pts = [(0.0, 0.0)]
        for j in range(1, 7):
            s = comp * j / 6
            aj = a + rg.uniform(-0.22, 0.22)
            pts.append((math.cos(aj) * s, math.sin(aj) * s))
        trincas.append(pts)
        if i % 2 == 0:   # galho
            j0 = rg.integers(2, 4)
            bu, bv = pts[j0]
            a2 = a + rg.choice([-1, 1]) * rg.uniform(0.5, 0.9)
            s2 = rg.uniform(0.18, 0.3)
            trincas.append([(bu, bv), (bu + math.cos(a2) * s2 * 0.6, bv + math.sin(a2) * s2 * 0.6),
                            (bu + math.cos(a2) * s2, bv + math.sin(a2) * s2)])

    frente = [0.24, 0.52, 0.78, 0.96, 1.02, 1.05]
    dentro_ = [-1, -1, 0.3, 0.6, 0.8, 0.95]
    forca = [1.5, 1.35, 1.1, 0.85, 0.6, 0.0]
    erosao = [0, 0, 0.05, 0.25, 0.5, 1]

    lascas = []
    for i in range(16):
        a = rg.uniform(0, 2 * math.pi)
        rho = rg.uniform(0.05, 0.75)
        t0 = 0 if rho < 0.24 else (1 if rho < 0.52 else 2)
        lascas.append(dict(u=math.cos(a) * rho, v=math.sin(a) * rho, a=a, vs=rg.uniform(0.06, 0.12), vz=rg.uniform(4.5, 7.5),
                           g=2.6, t0=t0 + rg.uniform(-0.2, 0.3), larg=3 if rg.random() < 0.35 else 2))
    faiscas = []
    for i in range(18):
        a = rg.uniform(0, 2 * math.pi)
        rho = rg.uniform(0.0, 0.6)
        faiscas.append(dict(u=math.cos(a) * rho, v=math.sin(a) * rho, a=a, vs=rg.uniform(0.08, 0.16), vz=rg.uniform(4, 9),
                            g=2.4, t0=rg.uniform(0, 2.2)))
    fumacas = []
    for i in range(11):
        a = rg.uniform(0, 2 * math.pi)
        rho = rg.uniform(0.1, 0.75)
        fumacas.append(dict(u=math.cos(a) * rho, v=math.sin(a) * rho * 0.85, nasc=rg.choice([2, 2, 3, 3, 4]),
                            r0=rg.uniform(4.0, 6.5), sobe=rg.uniform(2.2, 3.4)))

    quadros = []
    for t in range(6):
        f = novo(W, H)
        # 1) trincas no chão: brilham à frente da explosão e escurecem depois que ela passa
        alcance = min(1.0, frente[t] + 0.28)
        if t < 5:
            tmp_brilho = novo(W, H)
            tmp_desc = novo(W, H)
            for pts in trincas:
                for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
                    if math.hypot(u0, v0) > alcance:
                        break
                    s = 1.0
                    if math.hypot(u1, v1) > alcance:
                        s = max(0.0, (alcance - math.hypot(u0, v0)) / max(1e-3, math.hypot(u1 - u0, v1 - v0)))
                    x0, y0 = tela(u0, v0)
                    x1, y1 = tela(u0 + (u1 - u0) * s, v0 + (v1 - v0) * s)
                    linha(tmp_brilho, x0, y0, x1, y1, (255, 0, 0))
                    linha(tmp_desc, x0, y0 + 1, x1, y1 + 1, (255, 0, 0))
            mb = tmp_brilho[:, :, 3] > 0
            md = (tmp_desc[:, :, 3] > 0) & ~mb
            if t >= 3:   # as trincas esfriam e somem por partes
                corta = rzs(X / 4 + 9, Y / 4 + 9) < [0, 0, 0, 0.3, 0.6][t]
                mb &= ~corta
                md &= ~corta
            pinta(f, md, TRINCA_DESC)
            quente = mb & (e > frente[t] - 0.05)
            pinta(f, mb & ~quente, cor("#7a1430") if t < 4 else cor("#4a0e2a"))
            pinta(f, quente, FOGO_P[1] if t < 3 else FOGO_P[2])
            if t <= 1:   # o miolo da trinca, logo à frente da explosão, fica quase branco
                pinta(f, mb & (e > frente[t] - 0.02) & (e < frente[t] + 0.12), FOGO_P[0])
        # 2) explosão: anel de fogo que corre do centro para a borda, com línguas que sobem
        if forca[t] > 0:
            n = rzf(X / 4.2 + t * 2.3, Y / 3.2 - t * 1.4)
            n2 = rzf(X / 2.6 + 30 - t * 1.1, Y / 2.6 + 30 + t * 0.7)
            lingua = (rzf(X / 3.0 + 50 + t * 1.9, np.zeros_like(Y) + 50) - 0.5) * 0.45
            ee = np.sqrt((dx / rx) ** 2 + ((dy + 4 * (lingua + 0.25) * (t > 0)) / ry) ** 2) + (n - 0.5) * 0.12
            fr, di = frente[t], dentro_[t]
            if di < 0:
                calor = forca[t] * (1 - ee / fr) * 1.15
            else:
                meio, meia = (fr + di) / 2, (fr - di) / 2
                calor = forca[t] * (1 - np.abs(ee - meio) / meia)
            calor = calor + 0.3 * (n2 - 0.5) * 2 - erosao[t] * n2
            calor[(ee > fr + 0.1)] = -1
            faixas(f, calor, FOGO_P, [0.95, 0.68, 0.45, 0.26, 0.1])
            if t == 0:   # clarão do centro: riscos rentes ao chão
                linha(f, cx - 20, cy, cx + 21, cy, FOGO_P[0])
                linha(f, cx - 13, cy + 1, cx + 14, cy + 1, FOGO_P[0])
                linha(f, cx, cy - 9, cx, cy + 6, FOGO_P[0])
                linha(f, cx + 1, cy - 7, cx + 1, cy + 5, FOGO_P[0])
        # 3) fumaça escura que sobe do chão queimado e some
        puffs = []
        lim_f = 9.0
        for fm in fumacas:
            idade = t - fm["nasc"]
            if idade < 0:
                continue
            x, y = tela(fm["u"], fm["v"])
            r = fm["r0"] + 1.6 * idade
            y = max(r * 0.8, y - fm["sobe"] * (idade + 1))
            puffs.append((x, y, r))
        if puffs:
            lim_f = [0, 0, 0.0, 0.08, 0.32, 0.72][t]
            camada = novo(W, H)
            bolhas(camada, X, Y, puffs, FUMACA_P, rzs, lim_f, amp=0.38, esc=3.2, desloc=t * 0.6)
            m = (camada[:, :, 3] > 0) & ~((f[:, :, 3] > 0) & (np.isin(f[:, :, 0], [FOGO_P[0][0], FOGO_P[1][0]])))
            f[m] = camada[m]
        # 4) lascas do chão e fagulhas
        for ls in lascas:
            tau = t - ls["t0"]
            if tau <= 0:
                continue
            tl = 2 * ls["vz"] / ls["g"]
            if tau > tl:
                if t >= 5:
                    continue
                tau = tl
            u = ls["u"] + math.cos(ls["a"]) * ls["vs"] * tau
            v = ls["v"] + math.sin(ls["a"]) * ls["vs"] * tau
            z = max(0.0, ls["vz"] * tau - 0.5 * ls["g"] * tau * tau)
            x, y = tela(u, v, z)
            pedra(f, x, y, LASCA[0], LASCA[1], ls["larg"])
        for sp in faiscas:
            tau = t - sp["t0"]
            if tau <= 0:
                continue
            z = sp["vz"] * tau - 0.5 * sp["g"] * tau * tau
            if z < -1 or tau > 3.6:
                continue
            u = sp["u"] + math.cos(sp["a"]) * sp["vs"] * tau
            v = sp["v"] + math.sin(sp["a"]) * sp["vs"] * tau
            x, y = tela(u, v, max(z, 0))
            c = FAISCA[min(3, int(tau / 0.9))]
            x0, y0 = tela(u - math.cos(sp["a"]) * sp["vs"] * 0.5, v - math.sin(sp["a"]) * sp["vs"] * 0.5,
                          max(0.0, sp["vz"] * (tau - 0.5) - 0.5 * sp["g"] * (tau - 0.5) ** 2))
            if math.hypot(x - x0, y - y0) < 1.5:
                ponto2(f, x, y, c)
            else:
                linha(f, x0, y0, x, y, c)
        if t == 5:   # restos: duas brasas que se apagam no chão
            for (u, v) in ((-0.42, 0.3), (0.5, -0.12), (0.12, 0.55)):
                x, y = tela(u, v)
                ponto2(f, x, y, cor("#7a1430"))
        limpa(f)
        quadros.append(f)
    return quadros


# ---------------------------------------------------------------- 3) investida: poeira

POEIRA = cores("#9a7868", "#6e5250", "#48343c")
PEDRINHA = cores("#3a2628", "#1a1014")


def investida(semente, W=32, H=20):
    rg = np.random.default_rng(semente)
    rz = Ruido(rg, 16, 16)
    X, Y = grade(W, H)
    ax, ay = 16, 14
    # (x, y, r, lado): bolhas da nuvem; lado = para onde ela se espalha
    base = [(-5, 0.5, 4.0, -1), (0, -0.5, 5.0, -0.2), (5, 0.5, 4.0, 1), (-2.5, -4, 3.6, -0.6), (3, -4.5, 3.4, 0.6),
            (9, 1.2, 2.6, 1.4), (-9, 1.2, 2.4, -1.4)]
    cresce = [0.45, 0.8, 1.0, 1.1, 1.15]
    sobe = [0, 1.0, 2.2, 3.4, 4.4]
    abre = [0, 0.9, 1.7, 2.4, 3.0]
    lim = [0.0, 0.0, 0.08, 0.28, 0.52]
    pedras = [(-2, -3.4, 4.0, 2), (2, 3.6, 3.4, 2), (0, 1.4, 4.8, 1)]   # (lado, vx, vz, largura)
    quadros = []
    for t in range(5):
        f = novo(W, H)
        puffs = []
        for (x, y, r, lado) in base:
            rr = r * cresce[t]
            yy = ay + 0.5 + y - sobe[t] * (1.0 if y < -1 else 0.6)
            yy = min(yy, ay + 3.5 - rr * 0.4)      # o pé da nuvem não passa do chão
            puffs.append((ax + 0.5 + x + lado * abre[t], yy, rr))
        bolhas(f, X, Y, puffs, POEIRA, rz, lim[t], amp=0.16 + 0.06 * t, esc=3.0, desloc=t * 1.3)
        # pedrinhas que pulam do chão e caem
        for i, (lado, vx, vz, larg) in enumerate(pedras):
            tau = t - 0.3 * i
            if tau <= 0:
                continue
            z = vz * tau - 0.5 * 2.2 * tau * tau
            if z < 0 and t >= 4:
                continue
            x = ax + vx * tau + lado
            y = ay + 1 - max(z, 0)
            pedra(f, x, y, PEDRINHA[0], PEDRINHA[1], larg if larg > 1 else 1)
            if larg == 1:
                px(f, x + 1, y, PEDRINHA[0])
        limpa(f)
        quadros.append(f)
    return quadros


# ---------------------------------------------------------------- saída

def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    PREVIAS.mkdir(parents=True, exist_ok=True)
    q_queda, anc = queda_chuva(SEMENTE + 1)
    q_imp = impacto_chuva(SEMENTE + 2)
    q_est = estouro(SEMENTE + 3)
    q_inv = investida(SEMENTE + 4)
    folhas = [
        ("perigo_chuva", [("queda", q_queda, 16, True, anc), ("impacto", q_imp, 15, False, [32, 32])]),
        ("perigo_estouro", [("impacto", q_est, 15, False, [48, 30])]),
        ("perigo_investida", [("impacto", q_inv, 15, False, [16, 14])]),
    ]
    indice = {"folhas": {}}
    for nome, anims_def in folhas:
        anims = {}
        for anim, qs, fps, loop, ancora in anims_def:
            arq = f"{nome}_{anim}.png"
            gm.tira(qs).save(SAIDA / arq)
            h, w = qs[0].shape[:2]
            anims[anim] = {"arquivo": arq, "quadro": [w, h], "n": len(qs), "fps": fps, "loop": loop, "ancora": ancora}
        indice["folhas"][nome] = {"armas": [nome], "anims": anims}
        seqs = [(qs, fps, 2 if loop else 1) for _, qs, fps, loop, _ in anims_def]
        if len(seqs) == 1:
            seqs = seqs * 2   # o efeito curto toca duas vezes na prévia
        gm.previa(PREVIAS / f"{nome}.gif", seqs)
    with open(SAIDA / "indice_perigo.json", "w", encoding="utf-8") as fp:
        json.dump(indice, fp, ensure_ascii=False, indent=2)
        fp.write("\n")
    print("verificando:")
    erros = gm.verifica(indice)
    # o estouro termina quase vazio
    o = [(q[:, :, 3] > 0).sum() for q in q_est]
    if o[-1] > 0.15 * max(o):
        erros.append(f"perigo_estouro_impacto.png: último quadro não está quase vazio ({o[-1]}/{max(o)})")
    # nada de verde/azul (cor de aliado): o canal vermelho manda em todo pixel colorido
    for nome, anims_def in folhas:
        for anim, qs, *_ in anims_def:
            for i, q in enumerate(qs):
                a = q[:, :, 3] > 0
                r, g, b = [q[:, :, k].astype(int) for k in range(3)]
                ruim = a & ((g > r + 8) | (b > r + 24))
                if ruim.any():
                    erros.append(f"{nome}_{anim}: quadro {i} tem {int(ruim.sum())} pixel(s) puxando para verde/azul")
    if erros:
        print("PROBLEMAS:")
        for e in erros:
            print("  -", e)
        sys.exit(1)
    print("ok: todas as folhas passaram")


if __name__ == "__main__":
    main()

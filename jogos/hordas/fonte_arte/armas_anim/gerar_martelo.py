#!/usr/bin/env python3
"""Gera a folha da queda do Martelo do Trovão da v2 (grupo "martelo").

Contrato: docs/combate_v2/SPEC_ARTE.md. Uma tira em jogos/hordas/projeto/assets/v2/armas_anim/:
  martelo_trovao_queda.png  8 quadros, 16 fps, loop, célula 32x32, âncora no centro
Um martelo de guerra (cabeça de pedra com cintas de metal e cabo de madeira com empunhadura de couro) que capota de
ponta-cabeça: cada um dos 8 ângulos (45° por quadro, sentido horário) é redesenhado com a luz fixa de cima-esquerda,
e raios azul-brancos novos estalam em volta a cada quadro. Índice: indice_martelo.json (folha "martelo_trovao_queda",
armas ["martelo_trovao_queda"]: o anel martelo_trovao fica no indice_aneis.json; o código busca a queda por esse id).
Prévia GIF 4x em docs/combate_v2/previas/martelo_trovao_queda.gif.

Usa as primitivas de gerar_meteoros.py (mesma pasta, sem alteração). Semente fixa, sem rede.
Rodar:  python -I gerar_martelo.py
"""
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))   # python -I nao poe a pasta do script no caminho
sys.dont_write_bytecode = True

import numpy as np  # noqa: E402

import gerar_meteoros as M  # noqa: E402

SAIDA = M.SAIDA
PREVIAS = M.PREVIAS
SEMENTE = 20261019 + 4242
S = 32
N = 8
FPS = 16
NOME = "martelo_trovao_queda"
L2 = np.array([-0.6, -0.8])   # luz no plano da tela (cima-esquerda)

C = {k: M.cor(v) for k, v in dict(
    cont="#1c1822",
    # cabeça de pedra
    p_esc="#373534", p_med="#56504c", p_clr="#7c7570", p_bri="#b0a8a0",
    # cintas de metal
    m_esc="#4a5560", m_med="#8a9bb0", m_clr="#d9f6ff",
    # cabo de madeira e couro
    w_esc="#5d3729", w_med="#7c4832", w_clr="#a8643a", couro="#3b1f2e",
    # raios
    r_branco="#f2f7ff", r_azul="#a2d5f3", r_fundo="#6facd9",
).items()}


def tom(nx, ny, limiares=(-0.35, 0.3, 0.75)):
    """Índice de tom (0 escuro .. 3 claro) de uma face cuja normal na tela é (nx, ny)."""
    return int(np.digitize(nx * L2[0] + ny * L2[1], limiares))


def quadro(t, rg):
    f = M.novo(S, S)
    a = 2 * math.pi * t / N
    ca, sa = math.cos(a), math.sin(a)
    X, Y = M.grade(S, S)
    dx, dy = X - S / 2, Y - S / 2
    u = dx * ca + dy * sa          # ao longo do cabo (positivo = para a cabeça)
    v = -dx * sa + dy * ca         # de lado

    def normal(nu, nv):            # normal local -> tela
        return nu * ca - nv * sa, nu * sa + nv * ca

    # ---- cabo: madeira de 3 px com lado claro/escuro conforme o ângulo, empunhadura de couro e pomo de metal
    cabo = (u >= -11.6) & (u <= 3.0) & (np.abs(v) <= 1.45)
    lados = [C["w_esc"], C["w_med"], C["w_clr"], C["w_clr"]]
    tn_mais = tom(*normal(0, 1))
    tn_menos = tom(*normal(0, -1))
    M.pinta(f, cabo, C["w_med"])
    M.pinta(f, cabo & (v > 0.45), lados[tn_mais])
    M.pinta(f, cabo & (v < -0.45), lados[tn_menos])
    couro = cabo & (u >= -10.6) & (u <= -5.0)
    faixa = (np.floor(u + 20) % 2) == 0
    M.pinta(f, couro & faixa, C["couro"])
    M.pinta(f, couro & ~faixa, C["w_esc"])
    pomo = np.hypot(u + 12.2, v) <= 1.9
    mt = [C["m_esc"], C["m_esc"], C["m_med"], C["m_clr"]]
    M.pinta(f, pomo, C["m_esc"])
    M.pinta(f, pomo & ((dx - (-12.2 * ca)) * L2[0] + (dy - (-12.2 * sa)) * L2[1] > 0.2), C["m_med"])

    # ---- cabeça: bloco de pedra com as bocas alargadas e chanfro de 1 px que pega a luz conforme o lado
    au = 4.1 + 0.9 * (np.abs(v) > 5.2)            # meia altura (ao longo do cabo), maior nas bocas
    cu = 6.3                                      # centro da cabeça no eixo do cabo
    cab = (np.abs(u - cu) <= au) & (np.abs(v) <= 7.1)
    pt = [C["p_esc"], C["p_med"], C["p_clr"], C["p_bri"]]
    M.pinta(f, cab, C["p_med"])
    bordas = [  # (máscara do chanfro, normal local)
        (cab & (u - cu > au - 1.4), (1, 0)),
        (cab & (u - cu < -au + 1.4), (-1, 0)),
        (cab & (v > 5.8), (0, 1)),
        (cab & (v < -5.8), (0, -1)),
    ]
    for m, (nu, nv) in bordas:
        M.pinta(f, m, pt[tom(*normal(nu, nv))])
    # cintas de metal perto das bocas (com a mesma luz)
    for sv in (1, -1):
        cinta = cab & (np.abs(v - sv * 4.2) <= 0.6)
        M.pinta(f, cinta, C["m_med"])
        for m, (nu, nv) in bordas[:2]:
            M.pinta(f, cinta & m, mt[tom(*normal(nu, nv))])
    # runa do trovão no meio da cabeça: risco em zigue-zague que pisca
    runa = C["r_branco"] if t % 2 == 0 else C["r_azul"]
    for (u0, v0), (u1, v1) in zip([(cu + 1.6, -1.2), (cu + 0.2, 0.6), (cu - 0.2, -0.6)], [(cu + 0.2, 0.6), (cu - 0.2, -0.6), (cu - 1.6, 1.2)]):
        M.linha(f, S / 2 + u0 * ca - v0 * sa, S / 2 + u0 * sa + v0 * ca, S / 2 + u1 * ca - v1 * sa, S / 2 + u1 * sa + v1 * ca, runa)
    corpo = cabo | pomo | cab
    M.limpa(f)
    M.pinta(f, M.borda4(corpo), C["cont"])

    # ---- raios que estalam em volta (novos a cada quadro): saem da cabeça e de uma quina do cabo
    def tela(uu, vv):
        return S / 2 + uu * ca - vv * sa, S / 2 + uu * sa + vv * ca

    uc = rg.uniform(-9, 0)
    fontes = [((cu + 4.6, rg.uniform(-6, 6)), cu), ((cu + rg.uniform(-3, 3), rg.choice([-1, 1]) * 7.6), cu),
              ((uc, rg.choice([-1, 1]) * 2.2), uc)]
    camada, base = M.novo(S, S), f
    f = camada                     # os raios passam por trás do martelo: desenhados à parte e aplicados no vazio
    # arcos grandes que pulam da boca da cabeça até o cabo, pelo vão ao lado do cabo (um de cada lado, alternando)
    for k, lado in enumerate((1, -1) if t % 2 == 0 else (-1, 1)):
        x0, y0 = tela(cu - rg.uniform(1.5, 4.0), lado * rg.uniform(7.8, 8.4))
        x1, y1 = tela(rg.uniform(-9.5, -3.0), lado * 2.6)
        xm, ym = tela(rg.uniform(-3.0, 0.5), lado * rg.uniform(6.0, 8.5))     # o arco se abre para fora
        c = C["r_branco"] if k == 0 else C["r_azul"]
        M.zigue(f, rg, x0, y0, xm, ym, c, passo=2, desvio=1.2)
        M.zigue(f, rg, xm, ym, x1, y1, c, passo=2, desvio=1.2)
        if k == 1 and t % 4 >= 2:
            break
    for k, ((us, vs), u_c) in enumerate(fontes):
        x0, y0 = tela(us, vs)
        hx, hy = tela(u_c, 0)
        ang = math.atan2(y0 - hy, x0 - hx) + rg.uniform(-0.6, 0.6)
        comp = rg.uniform(4.5, 7.5) if k < 2 else rg.uniform(3.0, 5.0)
        x1, y1 = x0 + math.cos(ang) * comp, y0 + math.sin(ang) * comp
        r1 = math.hypot(x1 - S / 2, y1 - S / 2)
        if r1 > 14.5:   # não deixa o raio bater na borda da célula
            x1, y1 = S / 2 + (x1 - S / 2) * 14.5 / r1, S / 2 + (y1 - S / 2) * 14.5 / r1
        pts = M.zigue(f, rg, x0, y0, x1, y1, C["r_branco"] if k < 2 else C["r_azul"], passo=2, desvio=1.3)
        if k == 0 and len(pts) > 2:   # galho
            bx, by = pts[len(pts) // 2]
            g = ang + rg.choice([-1, 1]) * rg.uniform(0.6, 1.1)
            M.zigue(f, rg, bx, by, bx + math.cos(g) * 3.5, by + math.sin(g) * 3.5, C["r_azul"], passo=2, desvio=0.8)
    f = base
    m = (camada[:, :, 3] > 0) & (f[:, :, 3] == 0)
    f[m] = camada[m]
    # fagulhas soltas (2 px) em volta
    for _ in range(3):
        g = rg.uniform(0, 2 * math.pi)
        rr = rg.uniform(10.5, 13.5)
        x, y = S / 2 + math.cos(g) * rr, S / 2 + math.sin(g) * rr
        if f[int(y), int(x), 3] == 0:
            M.ponto2(f, x, y, C["r_azul"] if rg.random() < 0.5 else C["r_fundo"], vertical=rg.random() < 0.5)
    M.limpa(f)
    return f


def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    PREVIAS.mkdir(parents=True, exist_ok=True)
    quadros = [quadro(t, np.random.default_rng(SEMENTE + t)) for t in range(N)]
    arq = f"{NOME}.png"
    M.tira(quadros).save(SAIDA / arq)
    indice = {"folhas": {NOME: {"armas": [NOME], "anims": {"queda": {
        "arquivo": arq, "quadro": [S, S], "n": N, "fps": FPS, "loop": True, "ancora": [S // 2, S // 2]}}}}}
    with open(SAIDA / "indice_martelo.json", "w", encoding="utf-8", newline="\n") as fp:
        json.dump(indice, fp, ensure_ascii=False, indent=2)
        fp.write("\n")
    M.previa(PREVIAS / f"{NOME}.gif", [(quadros, FPS, 3)])
    print("verificando:")
    erros = M.verifica(indice)
    if erros:
        print("PROBLEMAS:")
        for e in erros:
            print("  -", e)
        sys.exit(1)
    print("ok: a folha passou")


if __name__ == "__main__":
    main()

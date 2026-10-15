"""COMBO: 2 golpes x 6 quadros, o mesmo número de passos de dados/v2_herois.json (cfg.golpe.passos: "batida" e "pancada").
Quadros de cada golpe (o jogo reparte a duração do golpe em partes iguais, e o dano sai no quadro 3 nos dois): 0 antecipação, 1 antecipação funda
(longa e pesada), 2 golpe, 3 IMPACTO, 4 segura (a marreta afunda), 5 volta.

  golpe 1, "batida":  a marreta vem de trás do ombro direito do anão, varre a frente na altura da cintura e acerta à esquerda do herói (arco largo);
                      o corpo gira junto (torso + quadril) e ele se firma numa passada larga.
  golpe 2, "pancada": marreta lá em cima, atrás da cabeça, o corpo arqueia; desce por cima e BATE no chão à frente e de lado (azim 50 em módulo, para fora da silhueta nas direções de costas) (poeira e pedras no quadro 3 e 4).

A marreta é posada no espaço do herói (ossos.empunhar: onde fica a mão de baixo e para onde aponta o cabo) e as duas mãos seguram o cabo por IK
(ossos.segurar); o resto (tronco, quadril, pernas) é FK. Rode com NICAO_DEBUG=1 para listar quadros em que a mão não alcança o cabo.
"""
import math
import os

import ossos

N_QUADROS = 12
QUADROS_POR_GOLPE = 6
S_POR_QUADRO = [0.11, 0.13, 0.05, 0.06, 0.12, 0.09] + [0.12, 0.16, 0.05, 0.07, 0.16, 0.10]

D_BAIXA, D_ALTA = -0.75, -0.50     # onde as mãos seguram o cabo (distância do punho de repouso; o cabo vai de -1,18 a +1,98)

# marreta: g = onde fica a mão de baixo (espaço do herói em repouso), elev/azim em graus (ossos.dirv), inv = a mão DIREITA da tela é a de baixo,
# rolar = giro da marreta em torno do cabo. corpo: tz giro do tronco (rad; negativo = para a esquerda da tela), tx inclina o tronco (+ = para a frente),
# qz giro do quadril, agacha 0..1, frente = perna da frente ("e" ou "d"), ponta = sobe nos dedos (unidades)
QUADROS = [
    # ---- golpe 1: batida (horizontal, da direita do anão para a esquerda dele, varrendo a frente)
    dict(g=(-0.30, -0.30, 1.45), elev=30, azim=-140, inv=True, tz=-0.50, tx=-0.05, qz=-0.25, agacha=0.25, frente="d"),
    dict(g=(-0.20, -0.10, 1.45), elev=24, azim=-165, inv=True, tz=-0.75, tx=-0.12, qz=-0.40, agacha=0.55, frente="d"),
    dict(g=(0.00, -0.40, 1.45), elev=28, azim=25, inv=False, tz=0.05, tx=0.18, qz=0.10, agacha=0.55, frente="d"),
    dict(g=(0.20, -0.25, 1.35), elev=5, azim=70, inv=False, tz=0.50, tx=0.20, qz=0.40, agacha=0.50, frente="d"),
    dict(g=(0.25, -0.20, 1.30), elev=-5, azim=80, inv=False, tz=0.58, tx=0.22, qz=0.45, agacha=0.50, frente="d"),
    dict(g=(-0.15, -0.20, 1.30), elev=65, azim=10, inv=False, tz=0.25, tx=0.08, qz=0.12, agacha=0.20, frente="d"),
    # ---- golpe 2: pancada (por cima, bate no chão à frente)
    dict(g=(-0.10, -0.10, 2.00), elev=26, azim=180, inv=False, tz=0.0, tx=-0.25, qz=0.0, agacha=0.10, frente="e"),
    dict(g=(-0.10, 0.05, 2.25), elev=12, azim=180, inv=False, tz=0.0, tx=-0.50, qz=0.0, agacha=0.0, frente="e", ponta=0.06),
    dict(g=(-0.15, -0.35, 2.10), elev=36, azim=25, inv=False, tz=0.0, tx=0.35, qz=0.0, agacha=0.35, frente="e"),
    dict(g=(-0.30, -0.50, 2.45), elev=-56, azim=50, inv=False, tz=0.0, tx=0.55, qz=0.0, agacha=0.65, frente="e"),
    dict(g=(-0.30, -0.50, 2.40), elev=-58, azim=50, inv=False, tz=0.0, tx=0.58, qz=0.0, agacha=0.70, frente="e"),
    dict(g=(-0.20, -0.25, 1.55), elev=40, azim=30, inv=False, tz=0.0, tx=0.15, qz=0.0, agacha=0.25, frente="e"),
]


LATERAIS = (8, 9, 10, 11)     # quadros da pancada que se abrem para o lado (azim do QUADROS = módulo; o sinal sai da direção da câmera)


def posar(arm, quadro, n_quadros, ang=0.0):
    p = QUADROS[quadro]
    a = p["agacha"]
    f, t = ("e", "d") if p["frente"] == "e" else ("d", "e")       # f = perna da frente, t = de trás
    ossos.girar(arm, "perna_" + f, x=-(0.20 + 0.45 * a))
    ossos.girar(arm, "canela_" + f, x=0.15 + 0.85 * a)
    ossos.girar(arm, "perna_" + t, x=0.20 + 0.15 * a)
    ossos.girar(arm, "canela_" + t, x=0.10 + 0.45 * a)
    ossos.girar(arm, "pe_" + f, x=0.25 + 0.2 * a)
    ossos.girar(arm, "pe_" + t, x=-0.30)
    ossos.girar(arm, "quadril", z=p["qz"], x=-0.10 * a)
    ossos.girar(arm, "torso", z=p["tz"] - p["qz"], x=p["tx"])
    ossos.girar(arm, "cabeca", z=-0.45 * p["tz"], x=-0.55 * p["tx"])
    g, azim = p["g"], p["azim"]
    if quadro in LATERAIS:      # pancada: o golpe cai para o lado que fica FORA da silhueta em cada direção da câmera (sem isso a cabeça some atrás do corpo)
        mag = abs(azim)
        s = min((-1, 0, 1), key=lambda k: abs(math.cos(math.radians(k * mag + ang))) + (0.01 if k else 0.0) - (0.005 if k < 0 else 0.0))
        azim, g = s * mag, (s * abs(g[0]) if g[0] else 0.0, g[1], g[2])
    ossos.empunhar(arm, g, ossos.dirv(p["elev"], azim), d0=D_BAIXA)
    if p["inv"]:
        ossos.segurar(arm, mao_e=D_ALTA, mao_d=D_BAIXA)
    else:
        ossos.segurar(arm, mao_e=D_BAIXA, mao_d=D_ALTA)
    if os.environ.get("NICAO_DEBUG"):
        print("FALTA q%d ang%d: e=%.2f d=%.2f" % (quadro, ang, arm["falta_e"], arm["falta_d"]))
    ossos.pisar(arm, extra=p.get("ponta", 0.0))
    ossos.encaixar_x(arm)


# poeira e pedras da PANCADA (quadros 9 e 10 do combo = quadros 3 e 4 do golpe 2): (deslocamento x, y em relação à cabeça da marreta, tamanho) em unidades do
# mundo (1 px = 0,041), sobem e se abrem do quadro de impacto para o seguinte
POEIRA = {
    9: [(-0.30, 0.10, 0.12), (0.30, 0.14, 0.12), (-0.12, -0.28, 0.10), (0.18, -0.30, 0.10), (0.0, 0.34, 0.09), (-0.46, -0.10, 0.07), (0.48, -0.06, 0.07)],
    10: [(-0.50, 0.14, 0.09), (0.50, 0.18, 0.09), (-0.28, -0.40, 0.07), (0.30, -0.42, 0.07), (0.0, 0.52, 0.06)],
}
PEDRAS = {
    9: [(-0.36, 0.0, 0.40, 0.035), (0.40, 0.0, 0.52, 0.035), (-0.18, -0.2, 0.62, 0.03), (0.2, -0.2, 0.30, 0.03)],
    10: [(-0.52, 0.0, 0.28, 0.03), (0.58, 0.0, 0.20, 0.03)],
}
POEIRA_COR = ((176, 160, 148), (130, 118, 112))
PEDRA_COR = (84, 80, 96)


def efeito(arm, quadro, n_quadros, ang):
    """Poeira clara no chão em volta da cabeça da marreta e pedras que saltam (só nos quadros de impacto e segura da pancada)."""
    if quadro not in POEIRA:
        return []
    from mathutils import Vector
    c = ossos.cabeca_marreta(arm)
    base = Vector((c.x, c.y, arm["z_chao_mundo"]))
    # o ponto de impacto fica abaixo do centro da cabeça: no chão, na vertical dela
    saida = []
    for i, (dx, dy, t) in enumerate(POEIRA[quadro]):
        p = base + Vector((dx, dy, 0.0))
        saida.append(([p + Vector((-t, 0, 0)), p + Vector((t, 0, 0)), p + Vector((t, 0, t * 1.5)), p + Vector((-t, 0, t * 1.5))], POEIRA_COR[i % 2]))
    for dx, dy, h, t in PEDRAS[quadro]:
        p = base + Vector((dx, dy, h))
        saida.append(([p + Vector((-t, 0, -t)), p + Vector((t, 0, -t)), p + Vector((t, 0, t)), p + Vector((-t, 0, t))], PEDRA_COR))
    return saida

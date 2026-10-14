"""Nicão, o Guardião (herói da v2): tanque de marreta. Modelo 3D escrito do zero para a v2 (nada da v1 é reaproveitado).

Silhueta: o mais largo e pesado dos três heróis. Ombreiras de aço enormes, tronco em bloco, barba ruiva grossa sob o elmo e uma
marreta de pedra carregada ao lado, com a cabeça acima do ombro (o contorno de 32 px lê "martelo" de longe).
Paleta: aço frio (armadura), couro (cinto, luvas, botas), ouro (frisos), pele e o vermelho do sangue (barba, tira do peito).

Não roda sozinho: o gerador (prototipos/cara_nova/gerar_cara_nova.py, modo `heroi_v2`) importa este módulo e chama montar()/pose():
    blender -b -P gerar_cara_nova.py -- heroi_v2 nicao      (a partir de jogos/hordas/prototipos/cara_nova)
Contrato (o mesmo de gerar_herois_v2.py): NOME, QUADRO (w, h), PE (linha do pé no quadro), PAL (paleta), montar() -> (raiz, corpo, ossos)
e pose(corpo, ossos, acao, q) com acao "parado" ou "andar" (q = 0..7, o ciclo de 8 quadros).
"""
import math
import os
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import pixel3d as px3  # noqa: E402
from pixel3d import caixa, cilindro  # noqa: E402

NOME = "nicao"
QUADRO = (64, 60)
PE = 58
DIRECOES = [0.0, -90.0, 90.0, 180.0, -45.0, 45.0, -135.0, 135.0]
PAL = px3.paleta_de("aco", "couro", "ouro", "sangue", "osso", "pele", "pedra", "hz_neutro")


def osso(nome, pos, pai):
    bpy.ops.object.empty_add(location=pos)
    o = bpy.context.active_object
    o.name = nome
    px3.pendurar(o, pai)
    return o


def montar():
    t = lambda h: px3.material_toon("m_" + h, px3.cor(h))  # noqa: E731
    aco, aco_esc, aco_cla = t("2a2426"), t("1a1618"), t("3d3335")      # armadura: ferro escuro (hz_neutro)
    ombro, ombro_cla = t("1d1a2b"), t("2e2a40")                      # ombreiras e martelo: aço azulado, o que o distingue do Hazaki
    couro, couro_esc = t("4a3324"), t("2b1d18")
    ouro = t("8f6a2e")
    pele, pele_esc = t("6b3f2a"), t("3b2219")
    barba, barba_esc = t("7e2027"), t("4f1520")
    pedra, pedra_esc = t("2e2a40"), t("1d1a2b")
    cabo = t("2b1d18")
    visor = px3.material_toon("visor", px3.cor("0d0b14"), faixas=(1, 1, 1))

    bpy.ops.object.empty_add(location=(0, 0, 0))
    raiz = bpy.context.active_object
    bpy.ops.object.empty_add(location=(0, 0, 0))
    corpo = bpy.context.active_object
    corpo.parent = raiz
    p = {"raiz": raiz}
    torso = osso("torso", (0, 0, 1.0), corpo)
    cab = osso("cab", (0, 0, 1.78), torso)
    p["torso"], p["cab"] = torso, cab

    # ---- pernas curtas e grossas, botas de couro com biqueira de aço
    for lado, x in (("e", 0.2), ("d", -0.2)):
        perna = caixa("perna_" + lado, (0.34, 0.36, 0.72), (x, 0, 0.62), aco_esc, corpo, pivo=(x, 0, 1.0), chanfro=0.04)
        caixa("joelheira_" + lado, (0.3, 0.1, 0.2), (x, -0.2, 0.62), aco, perna, chanfro=0.03)
        caixa("bota_" + lado, (0.38, 0.5, 0.26), (x, -0.06, 0.13), couro_esc, perna, chanfro=0.03)
        caixa("biqueira_" + lado, (0.36, 0.14, 0.2), (x, -0.28, 0.12), ombro, perna, chanfro=0.02)
        p["perna_" + lado] = perna
    # ---- cinto largo com fivela de ouro e saiote de couro
    caixa("cinto", (0.9, 0.56, 0.14), (0, 0, 1.02), couro, corpo, chanfro=0.03)
    caixa("fivela", (0.2, 0.05, 0.14), (0, -0.3, 1.02), ouro, corpo)
    caixa("saiote", (0.7, 0.5, 0.26), (0, 0, 0.88), couro_esc, corpo, chanfro=0.03)
    # ---- tronco em bloco: placa de aço, friso de ouro e tira de pano vermelho
    caixa("barriga", (0.84, 0.54, 0.34), (0, 0, 1.24), aco_esc, torso, chanfro=0.04)
    caixa("peito", (1.0, 0.62, 0.46), (0, 0, 1.6), aco, torso, chanfro=0.06)
    caixa("friso", (0.96, 0.06, 0.06), (0, -0.33, 1.78), ouro, torso)
    caixa("tira", (0.14, 0.04, 0.5), (0, -0.33, 1.52), barba_esc, torso)
    caixa("costas", (0.7, 0.2, 0.5), (0, 0.38, 1.52), couro_esc, torso, chanfro=0.04)
    # ---- ombreiras enormes (parte do torso: giram junto) e braços
    for lado, x in (("e", 0.68), ("d", -0.68)):
        braco = caixa("braco_" + lado, (0.28, 0.3, 0.42), (x, 0, 1.52), pele, torso, pivo=(x, 0, 1.8), chanfro=0.03)
        caixa("ombreira_" + lado, (0.42, 0.5, 0.3), (x * 1.02, 0, 1.84), ombro_cla, braco, chanfro=0.06)
        caixa("espinho_" + lado, (0.1, 0.1, 0.16), (x * 1.04, 0, 2.06), ombro_cla, braco, chanfro=0.02)
        ante = caixa("antebraco_" + lado, (0.26, 0.28, 0.34), (x, 0, 1.16), couro, braco, pivo=(x, 0, 1.3), chanfro=0.03)
        caixa("braceleira_" + lado, (0.3, 0.32, 0.16), (x, 0, 1.2), aco, ante, chanfro=0.03)
        caixa("luva_" + lado, (0.28, 0.28, 0.2), (x, 0, 0.98), couro_esc, ante, chanfro=0.03)
        p["braco_" + lado] = braco
        p["ante_" + lado] = ante
    # ---- cabeça: elmo de aço (viseira escura), barba ruiva grossa que cobre o peito
    cilindro("pescoco", 0.14, 0.14, (0, 0, 1.82), pele_esc, cab, vertices=8)
    caixa("cabeca", (0.46, 0.42, 0.4), (0, 0, 2.02), pele, cab, chanfro=0.07)
    caixa("elmo", (0.54, 0.5, 0.26), (0, 0.01, 2.16), aco, cab, chanfro=0.07)
    caixa("elmo_aba", (0.58, 0.54, 0.07), (0, 0, 2.05), aco_cla, cab, chanfro=0.02)
    caixa("elmo_crista", (0.1, 0.4, 0.14), (0, 0.02, 2.36), aco_cla, cab, chanfro=0.03)
    caixa("visor", (0.38, 0.03, 0.07), (0, -0.215, 2.05), visor, cab)
    caixa("barba", (0.46, 0.2, 0.34), (0, -0.2, 1.88), barba, cab, chanfro=0.05)
    caixa("barba_ponta", (0.3, 0.14, 0.2), (0, -0.22, 1.66), barba_esc, cab, chanfro=0.04)
    caixa("bigode", (0.34, 0.06, 0.06), (0, -0.3, 1.97), barba_esc, cab)
    # ---- marreta na mão direita, apoiada ao lado com a cabeça perto do chão: cabo de couro e cabeça de pedra com bandas de aço
    ante_d = p["ante_d"]
    caixa("cabo_marreta", (0.1, 0.1, 1.8), (-0.7, -0.05, 0.98), cabo, ante_d, chanfro=0.01)
    caixa("martelo", (0.62, 0.44, 0.46), (-0.7, -0.05, 0.3), pedra, ante_d, chanfro=0.07)
    caixa("martelo_banda", (0.66, 0.48, 0.1), (-0.7, -0.05, 0.3), ombro_cla, ante_d, chanfro=0.03)
    caixa("martelo_ponta", (0.16, 0.46, 0.4), (-1.08, -0.05, 0.3), pedra_esc, ante_d, chanfro=0.04)
    return raiz, corpo, p


def pose(corpo, p, acao, q):
    """parado ou andar (q = 0..7). Passo curto e pesado: o corpo balança de um lado a outro, a marreta acompanha o braço direito."""
    def z(b, x=0.0, y=0.0, w=0.0):
        p[b].rotation_euler = (x, y, w)

    for b in ("perna_e", "perna_d", "braco_e", "braco_d", "torso", "cab"):
        z(b)
    p["torso"].location = (0, 0, 1.0)
    p["cab"].location = (0, 0, 1.78)
    corpo.location = (0, 0, 0)
    z("ante_e", -0.12)
    z("ante_d", -0.22)
    z("braco_d", -0.1, 0.26)         # braço da marreta: um pouco à frente e aberto para o lado, a marreta fica fora do corpo
    if acao == "andar":
        fase = 2 * math.pi * q / 8.0
        s = math.sin(fase)
        z("perna_e", 0.5 * s)
        z("perna_d", -0.5 * s)
        z("braco_e", -0.3 * s)
        z("braco_d", -0.1 + 0.12 * s, 0.26)
        z("torso", 0.0, 0.05 * s, -0.06 * s)
        corpo.location = (0, 0, 0.055 * abs(math.cos(fase)))

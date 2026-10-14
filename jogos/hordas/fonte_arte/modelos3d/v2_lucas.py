"""Lucas, o Caótico (herói da v2): adagueiro à distância. Modelo 3D escrito do zero para a v2 (nada da v1 é reaproveitado).

Silhueta: o mais magro e leve dos três. Capuz pontudo roxo, cachecol comprido que sai para trás, bandoleira cruzada de adagas e
uma adaga na mão. Pernas finas e passo largo (é o rápido). Paleta: caos (roxo), couro, aço (lâminas), osso (cabos) e o ouro do cachecol.

Não roda sozinho: o gerador (prototipos/cara_nova/gerar_cara_nova.py, modo `heroi_v2`) importa este módulo:
    blender -b -P gerar_cara_nova.py -- heroi_v2 lucas      (a partir de jogos/hordas/prototipos/cara_nova)
Contrato (o mesmo de v2_nicao.py): NOME, QUADRO, PE, PAL, DIRECOES, montar() -> (raiz, corpo, ossos), pose(corpo, ossos, acao, q).
"""
import math
import os
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import pixel3d as px3  # noqa: E402
from pixel3d import caixa, cilindro  # noqa: E402

NOME = "lucas"
QUADRO = (40, 46)
PE = 44
DIRECOES = [0.0, -90.0, 90.0, 180.0, -45.0, 45.0, -135.0, 135.0]
PAL = px3.paleta_de("caos", "couro", "ouro", "aco", "osso", "pele", "noite")


def osso(nome, pos, pai):
    bpy.ops.object.empty_add(location=pos)
    o = bpy.context.active_object
    o.name = nome
    px3.pendurar(o, pai)
    return o


def montar():
    t = lambda h: px3.material_toon("m_" + h, px3.cor(h))  # noqa: E731
    roxo, roxo_esc, roxo_cla = t("3d1046"), t("1a0a1f"), t("6e1a6e")
    couro, couro_esc = t("4a3324"), t("2b1d18")
    ouro, ouro_esc = t("c49a45"), t("8f6a2e")
    lamina, cabo = t("45405c"), t("a89e86")
    pele, pele_esc = t("6b3f2a"), t("3b2219")
    calca = t("0b1020")
    olho = t("eccb7a")

    bpy.ops.object.empty_add(location=(0, 0, 0))
    raiz = bpy.context.active_object
    bpy.ops.object.empty_add(location=(0, 0, 0))
    corpo = bpy.context.active_object
    corpo.parent = raiz
    p = {"raiz": raiz}
    torso = osso("torso", (0, 0, 0.9), corpo)
    cab = osso("cab", (0, 0, 1.45), torso)
    p["torso"], p["cab"] = torso, cab

    # ---- pernas finas, botas altas de couro com a boca dobrada
    for lado, x in (("e", 0.1), ("d", -0.1)):
        perna = caixa("perna_" + lado, (0.16, 0.2, 0.64), (x, 0, 0.54), calca, corpo, pivo=(x, 0, 0.88), chanfro=0.02)
        caixa("bota_" + lado, (0.19, 0.3, 0.3), (x, -0.03, 0.18), couro_esc, perna, chanfro=0.02)
        caixa("dobra_" + lado, (0.22, 0.24, 0.07), (x, 0, 0.36), couro, perna, chanfro=0.01)
        p["perna_" + lado] = perna
    # ---- túnica curta roxa, cinto e bandoleira de adagas cruzando o peito
    caixa("saia", (0.4, 0.28, 0.26), (0, 0, 0.8), roxo, corpo, chanfro=0.03)
    caixa("cinto", (0.36, 0.25, 0.07), (0, 0, 0.93), couro, corpo)
    caixa("tronco", (0.34, 0.23, 0.52), (0, 0, 1.18), roxo, torso, chanfro=0.04)
    caixa("bandoleira", (0.08, 0.26, 0.62), (0, -0.01, 1.2), couro, torso, rot=(0, 0.55, 0))
    for k in range(3):
        caixa("adaga_peito", (0.045, 0.05, 0.13), (-0.1 + 0.07 * k, -0.15, 1.03 + 0.12 * k), cabo, torso, rot=(0, 0.55, 0))
    caixa("costas", (0.3, 0.12, 0.4), (0, 0.15, 1.2), roxo_esc, torso, chanfro=0.03)
    # ---- cachecol: gola grossa e uma ponta comprida que cai pelas costas
    caixa("gola", (0.4, 0.3, 0.1), (0, 0, 1.46), ouro, torso, chanfro=0.03)
    caixa("cachecol", (0.14, 0.05, 0.78), (0.1, 0.24, 1.08), ouro_esc, torso, rot=(0.12, 0, 0.06), chanfro=0.01)
    caixa("cachecol_ponta", (0.17, 0.05, 0.12), (0.11, 0.27, 0.66), ouro, torso, rot=(0.12, 0, 0.06))
    # ---- braços finos
    for lado, x in (("e", 0.25), ("d", -0.25)):
        braco = caixa("braco_" + lado, (0.12, 0.13, 0.3), (x, 0, 1.26), roxo, torso, pivo=(x, 0, 1.4), chanfro=0.02)
        ante = caixa("antebraco_" + lado, (0.1, 0.11, 0.26), (x, 0, 1.0), roxo_cla, braco, pivo=(x, 0, 1.1), chanfro=0.02)
        caixa("luva_" + lado, (0.12, 0.13, 0.1), (x, 0, 0.84), couro_esc, ante, chanfro=0.01)
        p["braco_" + lado] = braco
        p["ante_" + lado] = ante
    # ---- cabeça: rosto pálido na sombra do capuz pontudo, olhos claros
    cilindro("pescoco", 0.07, 0.1, (0, 0, 1.5), pele_esc, cab, vertices=8)
    caixa("cabeca", (0.27, 0.25, 0.28), (0, 0, 1.64), pele, cab, chanfro=0.05)
    caixa("rosto_sombra", (0.24, 0.03, 0.12), (0, -0.14, 1.66), roxo_esc, cab)
    for x in (0.055, -0.055):
        caixa("olho", (0.04, 0.02, 0.03), (x, -0.16, 1.67), olho, cab)
    caixa("capuz", (0.34, 0.33, 0.2), (0, 0.025, 1.75), roxo, cab, chanfro=0.05)
    caixa("capuz_costas", (0.32, 0.12, 0.34), (0, 0.15, 1.62), roxo_esc, cab, chanfro=0.03)
    caixa("capuz_borda", (0.3, 0.06, 0.07), (0, -0.14, 1.78), roxo_cla, cab)
    caixa("capuz_ponta", (0.14, 0.14, 0.2), (0, 0.09, 1.95), roxo, cab, rot=(0.5, 0, 0), chanfro=0.02)
    # ---- adaga na mão direita
    ante_d = p["ante_d"]
    caixa("cabo_adaga", (0.045, 0.1, 0.045), (-0.25, -0.05, 0.82), couro_esc, ante_d)
    caixa("guarda", (0.12, 0.03, 0.04), (-0.25, -0.12, 0.82), ouro_esc, ante_d)
    caixa("lamina_adaga", (0.035, 0.34, 0.035), (-0.25, -0.3, 0.83), lamina, ante_d, rot=(-0.05, 0, 0))
    return raiz, corpo, p


def pose(corpo, p, acao, q):
    """parado ou andar (q = 0..7). Passada larga e leve: tronco inclinado para a frente, braços soltos, o corpo quica pouco."""
    def z(b, x=0.0, y=0.0, w=0.0):
        p[b].rotation_euler = (x, y, w)

    for b in ("perna_e", "perna_d", "braco_e", "braco_d", "torso", "cab"):
        z(b)
    p["torso"].location = (0, 0, 0.9)
    p["cab"].location = (0, 0, 1.45)
    corpo.location = (0, 0, 0)
    z("ante_e", -0.2)
    z("ante_d", -0.55)               # adaga erguida na frente
    z("braco_d", -0.35)
    if acao == "andar":
        fase = 2 * math.pi * q / 8.0
        s = math.sin(fase)
        z("perna_e", 0.75 * s)
        z("perna_d", -0.75 * s)
        z("braco_e", -0.55 * s)
        z("braco_d", -0.35 + 0.3 * s)
        z("torso", -0.14, 0.0, -0.1 * s)
        corpo.location = (0, 0, 0.05 * abs(math.cos(fase)))

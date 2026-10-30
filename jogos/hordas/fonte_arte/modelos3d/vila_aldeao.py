"""Aldeão morto-vivo da Vila (#449): modelo próprio para o pipeline cara_nova.

Blender 4.5: gerar_cara_nova.py -- monstro vila_aldeao aldeao_morto
Silhueta ereta, camisa rasgada e mandíbula caída; não reutiliza o cão recolorido.
"""
import math

import monstros
import pixel3d as px3
from monstros import braco, raiz_corpo
from pixel3d import caixa, esfera


def mats():
    m = monstros.mats_base()
    m["camisa"] = px3.material_toon("camisa_aldeao", px3.cor("675039"), ruido=0.15)
    m["calca"] = px3.material_toon("calca_aldeao", px3.cor("3b4241"))
    m["pele"] = px3.material_toon("pele_aldeao", px3.cor("9aa58a"))
    m["pele_e"] = px3.material_toon("pele_aldeao_escura", px3.cor("58644e"))
    return m


def aldeao_morto(m):
    raiz, corpo = raiz_corpo()
    partes = {}
    # Pernas separadas: o andar arrasta uma bota e avança o joelho oposto.
    for lado, x in (("e", 0.14), ("d", -0.14)):
        perna = braco("perna_" + lado, 0.18, 0.20, 0.65, (x, 0, 0.72), m["calca"], corpo)
        caixa("bota_" + lado, (0.21, 0.32, 0.15), (x, -0.07, 0.09), m["negro"], perna)
        partes["perna_" + lado] = perna
    caixa("quadril", (0.44, 0.30, 0.24), (0, 0, 0.75), m["calca"], corpo)
    caixa("camisa", (0.54, 0.34, 0.57), (0, 0, 1.14), m["camisa"], corpo, rot=(0.10, 0, 0), chanfro=0.025)
    caixa("cinto", (0.56, 0.36, 0.07), (0, 0, 0.91), m["negro"], corpo)
    caixa("fivela", (0.09, 0.025, 0.07), (-0.08, -0.19, 0.91), m["ferrugem"], corpo)
    # Retalhos de camisa desiguais e costelas pela abertura lateral.
    for i, x in enumerate((-0.20, -0.03, 0.14)):
        caixa("retalho%d" % i, (0.12, 0.04, 0.17 + i * 0.03), (x, -0.18, 0.82), m["camisa"], corpo, rot=(0, 0.08 * (i - 1), 0))
    caixa("rasgo", (0.18, 0.03, 0.27), (0.15, -0.18, 1.15), m["negro"], corpo)
    for z in (1.08, 1.15, 1.22):
        caixa("costela", (0.16, 0.04, 0.035), (0.15, -0.20, z), m["osso_e"], corpo)
    # Braços de comprimentos diferentes tornam o contorno reconhecível de longe.
    for lado, x, comprimento in (("e", 0.38, 0.68), ("d", -0.36, 0.53)):
        a = braco("braco_" + lado, 0.16, 0.17, comprimento, (x, 0, 1.38), m["pele_e"], corpo)
        caixa("manga_" + lado, (0.22, 0.22, 0.28), (x, 0, 1.26), m["camisa"], a)
        caixa("mao_" + lado, (0.18, 0.13, 0.20), (x, -0.02, 1.35 - comprimento), m["pele"], a)
        for k in (-1, 0, 1):
            caixa("dedo", (0.035, 0.04, 0.11), (x + k * 0.055, -0.02, 1.21 - comprimento), m["pele_e"], a)
        partes["braco_" + lado] = a
    caixa("pescoco", (0.16, 0.16, 0.17), (0.03, -0.03, 1.48), m["pele_e"], corpo)
    cab = esfera("cabeca", 0.23, (0.04, -0.04, 1.70), m["pele"], corpo, escala=(0.86, 0.86, 1.10))
    caixa("cabelo", (0.31, 0.27, 0.11), (0.04, 0.00, 1.89), m["negro"], corpo, rot=(0, 0.12, 0))
    caixa("boca", (0.21, 0.04, 0.12), (0.04, -0.23, 1.61), m["negro"], corpo)
    caixa("mandibula", (0.20, 0.15, 0.07), (0.03, -0.19, 1.51), m["osso_e"], corpo, rot=(0.15, 0, -0.12))
    for x in (-0.045, 0.125):
        caixa("orbita", (0.10, 0.03, 0.10), (x, -0.224, 1.75), m["negro"], corpo)
        esfera("olho", 0.039, (x, -0.249, 1.75), m["olho_f"], corpo)
    partes["cab"] = cab

    def pose(fase, quadro):
        s = math.sin(fase)
        partes["perna_e"].rotation_euler = (0.44 * s, 0, 0)
        partes["perna_d"].rotation_euler = (-0.24 * s, 0, 0)
        partes["braco_e"].rotation_euler = (-0.45 - 0.18 * s, 0, -0.10)
        partes["braco_d"].rotation_euler = (-0.22 + 0.12 * s, 0, 0.12)
        corpo.location = (0.025 * s, 0, 0.025 * abs(s))
        corpo.rotation_euler = (0.09, 0.02 * s, 0.03 * s)

    return raiz, corpo, partes, pose


INIMIGOS = {
    "aldeao_morto": (aldeao_morto, 44, 58, 0.0, ("couro", "osso", "musgo", "aco", "sangue", "fogo")),
}

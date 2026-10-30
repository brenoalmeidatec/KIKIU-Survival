"""Homúnculo da Torre (#449): corpo de cobaia assimétrico, sem arte de terceiros.

Blender 4.5: gerar_cara_nova.py -- monstro torre_homunculo homunculo
"""
import math

import monstros
from monstros import braco, raiz_corpo
from pixel3d import caixa, esfera

mats = monstros.mats_base


def homunculo(m):
    raiz, corpo = raiz_corpo()
    p = {}
    # Baixo e inchado, com cabeça grande: silhueta distinta da aranha original.
    esfera("abdome", 0.32, (0, 0.04, 0.65), m["pele"], corpo, escala=(1.05, 0.9, 1.2))
    caixa("costura", (0.035, 0.04, 0.42), (0.03, -0.25, 0.67), m["carne_e"], corpo)
    for z in (0.53, 0.64, 0.75):
        caixa("ponto", (0.12, 0.035, 0.025), (0.03, -0.28, z), m["osso_e"], corpo)
    esfera("cabeca", 0.27, (-0.07, -0.1, 1.12), m["osso"], corpo, escala=(1.05, 0.85, 1.05))
    caixa("mandibula", (0.29, 0.19, 0.09), (-0.07, -0.22, 0.94), m["pele_e"], corpo)
    caixa("boca", (0.2, 0.04, 0.055), (-0.07, -0.32, 0.99), m["negro"], corpo)
    esfera("olho_grande", 0.075, (-0.18, -0.32, 1.15), m["olho_v"], corpo)
    esfera("olho_pequeno", 0.04, (0.04, -0.32, 1.13), m["olho_v"], corpo)
    for lado, x, largura, comprimento in (("e", 0.37, 0.22, 0.72), ("d", -0.34, 0.13, 0.48)):
        p["braco_" + lado] = braco("braco_" + lado, largura, 0.18, comprimento, (x, 0, 0.95), m["pele_e"], corpo)
        esfera("mao_" + lado, largura * 0.65, (x, -0.02, 0.95 - comprimento), m["pele"], p["braco_" + lado])
    for lado, x in (("e", 0.17), ("d", -0.17)):
        p["perna_" + lado] = braco("perna_" + lado, 0.16, 0.17, 0.4, (x, 0.04, 0.44), m["pele_e"], corpo)
        caixa("pe_" + lado, (0.19, 0.29, 0.09), (x, -0.06, 0.05), m["osso_e"], p["perna_" + lado])
    # Frasco fixado às costas mantém uma leitura alquímica nas vistas traseiras.
    caixa("correia", (0.43, 0.08, 0.055), (0, 0.27, 0.75), m["ferrugem"], corpo)
    esfera("frasco", 0.13, (0.12, 0.3, 0.85), m["olho_v"], corpo, escala=(0.8, 0.8, 1.2))

    def pose(fase, quadro):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.5 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.5 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.15 - 0.22 * s, 0, 0.12)
        p["braco_d"].rotation_euler = (0.2 + 0.3 * s, 0, -0.1)
        corpo.location = (0.035 * s, 0, 0.035 * abs(math.cos(fase)))

    return raiz, corpo, p, pose


INIMIGOS = {"homunculo": (homunculo, 40, 46, 0.0, ("musgo", "osso", "veneno", "sangue", "couro"))}

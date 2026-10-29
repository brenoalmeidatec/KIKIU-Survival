"""Golem de vidro da Torre do Alquimista (#449): modelo próprio, sem textura externa.

Render: gerar_cara_nova.py -- monstro torre_golem_vidro golem_vidro.
O vidro usa facetas opacas e veios luminosos; não depende de transparência no atlas.
"""
import math

import monstros
from monstros import braco, espinho, raiz_corpo
from pixel3d import caixa, cone, esfera


def mats():
    t, c = monstros.T, monstros.C
    return {
        "vidro": t("vidro", c("81bccd")),
        "vidro_e": t("vidro_e", c("284a72")),
        "vidro_claro": t("vidro_claro", c("d9edf2")),
        "junta": t("junta", c("142a6e")),
        "olho": monstros.px3.material_emissao("olho_golem", c("8cd9ff")),
    }


def golem_vidro(m):
    """Autômato largo de cristal rachado, núcleo azul e ombros facetados."""
    raiz, corpo = raiz_corpo()
    p = {}
    for lado, x in (("e", 0.22), ("d", -0.22)):
        perna = braco("perna_" + lado, 0.26, 0.27, 0.62, (x, 0, 0.69), m["vidro_e"], corpo)
        caixa("canela_" + lado, (0.25, 0.24, 0.42), (x, 0, 0.34), m["vidro"], perna, rot=(0, 0, 0.09))
        caixa("pe_" + lado, (0.3, 0.36, 0.13), (x, -0.07, 0.075), m["vidro_e"], perna)
        p["perna_" + lado] = perna
    cone("abdomen", 0.34, 0.28, 0.42, (0, 0, 0.83), m["junta"], corpo, vertices=5)
    cone("peito", 0.36, 0.49, 0.63, (0, 0, 1.28), m["vidro"], corpo, vertices=6)
    caixa("racha_centro", (0.07, 0.045, 0.5), (0.04, -0.4, 1.28), m["vidro_claro"], corpo, rot=(0, 0.12, 0.17))
    caixa("racha_diagonal", (0.3, 0.04, 0.055), (-0.1, -0.4, 1.36), m["vidro_claro"], corpo, rot=(0, 0.35, 0))
    esfera("nucleo", 0.13, (0, -0.42, 1.12), m["olho"], corpo, escala=(1, 0.35, 1.2))
    for lado, x in (("e", 0.55), ("d", -0.55)):
        ombro = cone("ombro_" + lado, 0.23, 0.29, 0.39, (x, 0, 1.48), m["vidro_claro"], corpo, vertices=5)
        ombro.rotation_euler[1] = 0.3 if x > 0 else -0.3
        a = braco("braco_" + lado, 0.23, 0.25, 0.74, (x, 0, 1.42), m["vidro_e"], corpo)
        cone("punho_" + lado, 0.24, 0.19, 0.38, (x, -0.02, 0.77), m["vidro"], a, vertices=5)
        caixa("veio_" + lado, (0.055, 0.035, 0.47), (x, -0.14, 1.13), m["vidro_claro"], a)
        p["braco_" + lado] = a
    cone("cabeca", 0.22, 0.18, 0.37, (0, -0.01, 1.81), m["vidro_e"], corpo, vertices=5)
    cone("coroa", 0.2, 0, 0.2, (0, 0.01, 2.08), m["vidro_claro"], corpo, vertices=5)
    for x in (-0.08, 0.08):
        caixa("olho", (0.09, 0.045, 0.055), (x, -0.2, 1.86), m["olho"], corpo)
    for x in (-0.23, 0.23):
        espinho("cristal_costas", (x, 0.27, 1.5), (x, 0.4, 1), 0.35, 0.11, m["vidro_claro"], corpo)

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.32 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.32 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.25 * s, 0, 0)
        p["braco_d"].rotation_euler = (0.25 * s, 0, 0)
        corpo.location = (0, 0, 0.035 * abs(math.cos(fase)))
        corpo.rotation_euler = (0, 0.035 * s, 0)

    return raiz, corpo, p, pose


INIMIGOS = {"golem_vidro": (golem_vidro, 46, 54, 0, ("gelo", "cobalto", "aco"))}

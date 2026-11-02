"""COMBO: 2 tiros x 6 quadros (dados/v2_herois.json > lightwolf > cfg.golpe.passos: dois passos "tiro", lateral -5 e +5, acerto_em 0,2 = quadro 1 de cada tiro).
Os DOIS bracos ficam ESTENDIDOS PARA A FRENTE, antebracos (canhoes) horizontais e paralelos na direcao em que o heroi encara. Tiro 1: canhao da ESQUERDA da tela
(osso _e, x<0, lateral -5); tiro 2: o da direita. Quadros de cada tiro: 0 mira, 1 DISPARO (clarao ciano na boca do cano + inicio do recuo), 2 recuo maximo
(só o braço que atira recua; o corpo fica plantado), 3 volta, 4 estabiliza, 5 mira de novo.
Braco x=-0,8 com antebraco x=0 deixa o antebraco (45 graus abaixo da vertical em repouso) horizontal.
"""
import bpy

import ossos

N_QUADROS = 12
QUADROS_POR_TIRO = 6
S_POR_QUADRO = [0.06, 0.04, 0.05, 0.05, 0.04, 0.04] + [0.06, 0.04, 0.05, 0.05, 0.04, 0.04]

BRACO = -0.80
RECUO_Y = (0.0, 0.04, 0.10, 0.05, 0.015, 0.0)     # pistão curto: cerca de 2 px; sem balançar tronco e pernas
RECUO_X = (0.0, 0.015, 0.035, 0.015, 0.0, 0.0)


def posar(arm, quadro, n_quadros):
    t = quadro % QUADROS_POR_TIRO
    atira = "e" if quadro < QUADROS_POR_TIRO else "d"
    outro = "d" if atira == "e" else "e"
    # A mesma base do parado: nem a troca de braço nem o intervalo entre tiros deslocam cabeça, cockpit ou pés.
    ossos.girar(arm, "perna_e", x=-0.06)
    ossos.girar(arm, "perna_d", x=-0.06)
    ossos.girar(arm, "canela_e", x=0.10)
    ossos.girar(arm, "canela_d", x=0.10)
    ossos.girar(arm, "quadril")
    ossos.girar(arm, "torso")
    ossos.girar(arm, "cabeca")
    for l in (atira, outro):
        ossos.girar(arm, "braco_" + l, x=BRACO + (RECUO_X[t] if l == atira else 0.0))
        ossos.girar(arm, "antebraco_" + l, x=0.0)
    ossos.mover(arm, "braco_" + atira, y=RECUO_Y[t])
    if t == 1:                                   # quadro do disparo: clarao na boca do cano que atira
        for o in arm.children:
            if o.name.startswith("Olho clarao") and o.name.endswith("esquerda" if atira == "e" else "direita"):
                o.hide_render = False
    ossos.pisar(arm)
    ossos.encaixar_x(arm, meia_px=60.0)  # quadro de 128 px: não recentrar o corpo a cada clarão/recuo


def efeito(arm, quadro, n_quadros, ang):
    return []     # o clarao e geometria emissiva (Olho clarao ..., ligada em posar), nao polígono 2D

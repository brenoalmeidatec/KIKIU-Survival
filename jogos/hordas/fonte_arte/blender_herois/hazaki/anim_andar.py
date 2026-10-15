"""ANDAR: 6 quadros, ciclo do piloto (contato, descida, passagem, contato oposto, descida, passagem; 60 graus de fase por quadro),
agora com JOELHO e COTOVELO: a perna que balança dobra o joelho (a bota fica quase plana), o braço que vai à frente dobra o cotovelo.
O sobe-e-desce do quadril sai da própria geometria das pernas (ossos.pisar ancora o pé mais baixo no chão).
"""
import math

import ossos

N_QUADROS = 6
PERNA = 0.44        # rad de balanço da coxa
JOELHO = 0.75       # rad de dobra do joelho da perna que balança (pico na passagem)
JOELHO_BASE = 0.10  # joelho nunca totalmente esticado
BRACO = 0.24        # rad de balanço do braço (oposto à perna do mesmo lado)
BRACO_KATANA = 0.05 # o braço da katana balança pouco, para a lâmina continuar apontada para baixo e legível
QUADRIL = 0.10      # rad de giro do quadril (ombros giram ao contrário)


def posar(arm, quadro, n_quadros):
    f = 2 * math.pi * quadro / n_quadros
    c, s = math.cos(f), math.sin(f)
    # a perna da direita da tela (d) vai de trás (q=0) para a frente (q=3); a da esquerda (e) é a fase oposta
    coxa_e, coxa_d = -PERNA * c, PERNA * c
    joelho_e = JOELHO_BASE + JOELHO * max(0.0, -s)
    joelho_d = JOELHO_BASE + JOELHO * max(0.0, s)
    ossos.girar(arm, "perna_e", x=coxa_e)
    ossos.girar(arm, "perna_d", x=coxa_d)
    ossos.girar(arm, "canela_e", x=joelho_e)
    ossos.girar(arm, "canela_d", x=joelho_d)
    # a bota anula a inclinação da perna (apoio quase plano)
    ossos.girar(arm, "pe_e", x=-(coxa_e + joelho_e) * 0.9)
    ossos.girar(arm, "pe_d", x=-(coxa_d + joelho_d) * 0.9)
    # braços: oposto à perna do mesmo lado; o cotovelo dobra mais no braço que vai à frente
    ossos.girar(arm, "braco_e", x=BRACO * c)
    ossos.girar(arm, "braco_d", x=-BRACO_KATANA * c)
    ossos.girar(arm, "antebraco_e", x=-0.20 - 0.40 * max(0.0, -c))
    ossos.girar(arm, "antebraco_d", x=-0.04)
    ossos.girar(arm, "quadril", z=QUADRIL * c, x=-0.04)
    ossos.girar(arm, "torso", z=-2.0 * QUADRIL * c)
    ossos.girar(arm, "cabeca", z=QUADRIL * c)
    ossos.pisar(arm)

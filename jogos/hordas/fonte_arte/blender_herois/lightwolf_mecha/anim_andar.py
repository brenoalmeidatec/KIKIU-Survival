"""ANDAR: 6 quadros, ciclo do piloto (contato, descida, passagem, contato oposto, descida, passagem; 60 graus de fase por quadro).
Mecha pesado: passo curto, quadril balança mais que o do Hazaki, o corpo desce a cada apoio. Bracos soltos com os canhoes para a frente.
"""
import math

import ossos

N_QUADROS = 6
PERNA = 0.50        # rad de balanço da coxa (passo curto, mas legível: as pernas do anão têm só 1 unidade)
JOELHO = 0.85       # rad de dobra do joelho da perna que balança
JOELHO_BASE = 0.08
BRACO = 0.30        # balanço do braço direito (livre)
QUADRIL = 0.12      # giro do quadril (ombros giram ao contrário)


def posar(arm, quadro, n_quadros):
    f = 2 * math.pi * quadro / n_quadros
    c, s = math.cos(f), math.sin(f)
    coxa_e, coxa_d = -PERNA * c, PERNA * c
    joelho_e = JOELHO_BASE + JOELHO * max(0.0, -s)
    joelho_d = JOELHO_BASE + JOELHO * max(0.0, s)
    ossos.girar(arm, "perna_e", x=coxa_e)
    ossos.girar(arm, "perna_d", x=coxa_d)
    ossos.girar(arm, "canela_e", x=joelho_e)
    ossos.girar(arm, "canela_d", x=joelho_d)
    ossos.girar(arm, "pe_e", x=-(coxa_e + joelho_e) * 0.9)
    ossos.girar(arm, "pe_d", x=-(coxa_d + joelho_d) * 0.9)
    ossos.girar(arm, "quadril", z=QUADRIL * c, x=-0.05, y=0.10 * c)       # balanço de lado do anão pesado
    ossos.girar(arm, "torso", z=-2.0 * QUADRIL * c, x=0.10, y=-0.12 * c)
    ossos.girar(arm, "cabeca", z=QUADRIL * c, x=-0.06)
    # bracos pesados, soltos: balancam contra as pernas, canhoes para a frente e para baixo
    ossos.girar(arm, "braco_e", x=BRACO * c * 0.6 - 0.10)
    ossos.girar(arm, "braco_d", x=-BRACO * c * 0.6 - 0.10)
    ossos.girar(arm, "antebraco_e", x=-0.10 - 0.15 * max(0.0, -c))
    ossos.girar(arm, "antebraco_d", x=-0.10 - 0.15 * max(0.0, c))
    ossos.pisar(arm)

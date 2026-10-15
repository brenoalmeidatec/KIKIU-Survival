"""PARADO / RESPIRANDO: 4 quadros. Respiração de 1 px (peito e cabeça sobem juntos) e um leve balanço do corpo.

Contrato de toda animação (o gerar.py importa `anim_<nome>.py`): N_QUADROS e posar(arm, quadro, n_quadros).
O gerar.py zera a pose antes de cada chamada; a função só posa (use as funções de ossos.py).
"""
import math

import ossos

N_QUADROS = 4
PX = 0.074          # 1 px do jogo em unidades do modelo (0,55 de escala x 24,5 px/m)


def posar(arm, quadro, n_quadros):
    t = quadro / n_quadros
    ar = 0.5 - 0.5 * math.cos(2 * math.pi * t)     # 0 -> 1 -> 0: inspira e solta, uma vez por ciclo
    bal = math.sin(2 * math.pi * t)                 # balanço de lado: ida e volta no mesmo ciclo

    ossos.mover(arm, "torso", z=PX * ar)            # o peito sobe 1 px (a cabeça vai junto, é filha do torso)
    ossos.girar(arm, "torso", y=0.035 * bal, x=-0.03 * ar)
    ossos.girar(arm, "cabeca", y=-0.02 * bal)       # a cabeça compensa um pouco, sem acompanhar o ombro
    ossos.girar(arm, "quadril", y=-0.012 * bal)
    # braços acompanham: sobem um fio com o ombro e balançam levemente; o da katana mexe menos
    ossos.girar(arm, "braco_e", y=0.03 * ar, x=0.04 * bal)
    ossos.girar(arm, "braco_d", y=-0.02 * ar, x=-0.025 * bal)
    ossos.girar(arm, "antebraco_e", x=-0.06 * ar)
    ossos.girar(arm, "antebraco_d", x=-0.03 * ar)
    ossos.pisar(arm)

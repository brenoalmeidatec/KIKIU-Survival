"""STRAFE ATIRANDO: 6 quadros. Da cintura para baixo é o STRAFE (anim_strafe.py: o mesmo passo-junta, quadro a quadro e na mesma fase); da
cintura para cima é a MIRA do andar_tiro (anim_andar_tiro.py: braços do combo 0 estendidos, canhões na linha da mira). O torso desfaz o tombo
do quadril, então a mira fica no eixo; sobra o sobe-e-desce da base larga (ossos.pisar), que o gerar.py mede por quadro em bocas.json e o
montar_folha.py grava em animacoes.strafe_tiro.desvio_boca (o mesmo formato do andar_tiro).
"""
from mathutils import Euler

import anim_combo
import anim_strafe
import ossos

N_QUADROS = 6
S_POR_QUADRO = [0.11] * N_QUADROS


def posar(arm, quadro, n_quadros):
    peso = anim_strafe._pernas(arm, quadro, n_quadros)
    q = (-0.05, anim_strafe.QUADRIL_Y * peso, 0.0)
    ossos.girar(arm, "quadril", x=q[0], y=q[1], z=q[2])
    inv = Euler(q, "XYZ").to_matrix().inverted().to_euler("XYZ")
    ossos.girar(arm, "torso", x=inv.x, y=inv.y, z=inv.z)
    ossos.girar(arm, "cabeca")
    for lado in ("e", "d"):
        ossos.girar(arm, "braco_" + lado, x=anim_combo.BRACO)
        ossos.girar(arm, "antebraco_" + lado, x=0.0)
    ossos.pisar(arm)
    ossos.encaixar_x(arm, meia_px=60.0)  # o mesmo encaixe do combo e do andar_tiro

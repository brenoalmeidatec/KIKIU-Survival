"""ANDAR ATIRANDO: 6 quadros. Da cintura para baixo é o ANDAR (anim_andar.py: as mesmas coxas, joelhos e pés, na mesma fase de 60 graus por
quadro, então o jogo troca andar <-> andar_tiro sem tropeçar o passo); da cintura para cima é a MIRA do combo (anim_combo.py, quadro 0: os
dois braços estendidos, canhões horizontais e paralelos para a frente). Pedido do Alisson (05/11): "ainda falta animações enquanto anda e
atira ao mesmo tempo" (antes o heroi.gd segurava a pose de mira parada e as pernas deslizavam).
O tronco NÃO gira com o quadril: o giro do quadril é desfeito no torso (a mira fica no eixo, cabeça e canhões não balançam de lado); o que
sobra é o sobe-e-desce do apoio (ossos.pisar), que o gerar.py mede por quadro e o montar_folha.py grava em animacoes.andar_tiro.desvio_boca.
Sem recuo e sem clarão na geometria: o quadro não sabe quando o tiro sai; o clarão é o BOCA de v2/estalos_visual.gd, na boca medida.
"""
import math

from mathutils import Euler

import anim_andar
import anim_combo
import ossos

N_QUADROS = 6
S_POR_QUADRO = [0.11] * N_QUADROS   # o mesmo ritmo do andar (animacoes.andar.s_por_quadro): a fase das pernas é a mesma
QUADRIL = 0.06                     # metade do giro do andar: o mecha mirando anda mais "travado" no quadril


def posar(arm, quadro, n_quadros):
    f = 2 * math.pi * quadro / n_quadros
    c, s = math.cos(f), math.sin(f)
    coxa_e, coxa_d = -anim_andar.PERNA * c, anim_andar.PERNA * c
    joelho_e = anim_andar.JOELHO_BASE + anim_andar.JOELHO * max(0.0, -s)
    joelho_d = anim_andar.JOELHO_BASE + anim_andar.JOELHO * max(0.0, s)
    ossos.girar(arm, "perna_e", x=coxa_e)
    ossos.girar(arm, "perna_d", x=coxa_d)
    ossos.girar(arm, "canela_e", x=joelho_e)
    ossos.girar(arm, "canela_d", x=joelho_d)
    ossos.girar(arm, "pe_e", x=-(coxa_e + joelho_e) * 0.9)
    ossos.girar(arm, "pe_d", x=-(coxa_d + joelho_d) * 0.9)
    q = (-0.05, 0.05 * c, QUADRIL * c)
    ossos.girar(arm, "quadril", x=q[0], y=q[1], z=q[2])
    # o torso desfaz exatamente o giro do quadril (o torso é filho dele): tronco, cabeça e braços ficam no eixo da mira
    inv = Euler(q, "XYZ").to_matrix().inverted().to_euler("XYZ")
    ossos.girar(arm, "torso", x=inv.x, y=inv.y, z=inv.z)
    ossos.girar(arm, "cabeca")
    for lado in ("e", "d"):
        ossos.girar(arm, "braco_" + lado, x=anim_combo.BRACO)
        ossos.girar(arm, "antebraco_" + lado, x=0.0)
    ossos.pisar(arm)
    ossos.encaixar_x(arm, meia_px=60.0)  # o mesmo encaixe do combo: o corpo não é recentrado a cada passo

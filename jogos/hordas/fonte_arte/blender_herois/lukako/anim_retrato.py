"""Pose do RETRATO da Lukako (so o retrato usa; o gerar.py acha este arquivo na pasta do perfil): o parado com o braco do leque erguido
um pouco para fora, para o leque aberto (preso ao antebraco, em pe) aparecer ao lado do rosto no busto de 64x64."""
import anim_parado
import ossos

N_QUADROS = 1
BX, BY, AX, AZ = 0.0, -0.8, -0.3, 0.0


def posar(arm, quadro, n_quadros, ang=0.0):
    anim_parado.posar(arm, 0, anim_parado.N_QUADROS)
    ossos.girar(arm, "braco_d", x=BX, y=BY)
    ossos.girar(arm, "antebraco_d", x=AX, z=AZ)

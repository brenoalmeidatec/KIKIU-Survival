"""PARADO: 4 quadros. O mecha respira (tronco e ombros sobem ~1 px); bracos soltos ao lado, os canhoes dos antebracos apontam para a frente e para baixo."""
import ossos

N_QUADROS = 4
S_POR_QUADRO = [0.28, 0.28, 0.28, 0.28]


def posar(arm, quadro, n_quadros):
    sobe = (0.0, 0.5, 1.0, 0.5)[quadro]
    ossos.mover(arm, "torso", z=0.05 * sobe)
    ossos.mover(arm, "cabeca", z=0.02 * sobe)
    ossos.girar(arm, "torso", x=0.03 * sobe)
    for l in ("e", "d"):
        ossos.girar(arm, "braco_" + l, x=-0.06 - 0.03 * sobe)
        ossos.girar(arm, "antebraco_" + l, x=-0.05)
    ossos.girar(arm, "perna_e", x=-0.06)
    ossos.girar(arm, "perna_d", x=-0.06)
    ossos.girar(arm, "canela_e", x=0.10)
    ossos.girar(arm, "canela_d", x=0.10)
    ossos.pisar(arm)

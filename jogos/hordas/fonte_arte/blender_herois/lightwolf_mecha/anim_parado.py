"""PARADO: 4 quadros. O anão respira fundo (tronco e ombros sobem ~1 px), a mão esquerda segura a marreta plantada no chão e a direita pende."""
import ossos

N_QUADROS = 4
S_POR_QUADRO = [0.28, 0.28, 0.28, 0.28]


def posar(arm, quadro, n_quadros):
    sobe = (0.0, 0.5, 1.0, 0.5)[quadro]
    ossos.mover(arm, "torso", z=0.05 * sobe)
    ossos.mover(arm, "cabeca", z=0.02 * sobe)
    ossos.girar(arm, "torso", x=0.03 * sobe)
    ossos.girar(arm, "braco_d", x=-0.25 + 0.03 * sobe, y=-0.10)
    ossos.girar(arm, "antebraco_d", x=-0.55)
    ossos.mover(arm, "marreta", z=0.12)
    ossos.segurar(arm)
    ossos.pisar(arm)

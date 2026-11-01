"""DANO (levou um golpe): 2 quadros, uma vez só. q0 = IMPACTO: a cabeça jogada para trás, o tronco curvado, o corpo recua e os joelhos cedem, a mão
esquerda quase solta a marreta (o cabo balança para trás); q1 = RECUO máximo: peso nos calcanhares, a marreta volta a ser segurada. O jogo emenda no parado.

Sinais: tronco e cabeça x NEGATIVO = para trás; braço, antebraço, perna e canela x NEGATIVO = para a frente; marreta (aponta para cima) x NEGATIVO = a cabeça vai para trás.
"""
import ossos

N_QUADROS = 2
S_POR_QUADRO = [0.07, 0.13]

QUADROS = [
    dict(raiz=-0.06, tronco=-0.34, cabeca=-0.45, marreta=-0.45, mar_z=0.10, lado=0.30, mar_y=-0.30,
         braco_d=(0.35, -1.00), antebraco_d=-0.30, perna_e=0.20, canela_e=0.60, perna_d=-0.18, canela_d=0.45),
    dict(raiz=-0.10, tronco=-0.40, cabeca=-0.30, marreta=-0.25, mar_z=0.04, lado=0.15, mar_y=-0.12,
         braco_d=(0.25, -0.55), antebraco_d=-0.35, perna_e=0.38, canela_e=0.80, perna_d=-0.28, canela_d=0.60),
]


def posar(arm, quadro, n_quadros):
    p = QUADROS[quadro]
    ossos.girar(arm, "raiz", x=p["raiz"])
    ossos.girar(arm, "torso", x=p["tronco"], y=p["lado"])       # y: o tronco também pende de lado, para ler de frente e de costas
    ossos.girar(arm, "cabeca", x=p["cabeca"], y=-0.8 * p["lado"])
    ossos.girar(arm, "braco_d", x=p["braco_d"][0], y=p["braco_d"][1])
    ossos.girar(arm, "antebraco_d", x=p["antebraco_d"])
    ossos.girar(arm, "braco_e", x=0.25 * p["braco_d"][0], y=-0.5 * p["braco_d"][1])
    ossos.girar(arm, "antebraco_e", x=p["antebraco_d"])
    for lado in ("e", "d"):
        perna, canela = p["perna_" + lado], p["canela_" + lado]
        ossos.girar(arm, "perna_" + lado, x=perna)
        ossos.girar(arm, "canela_" + lado, x=canela)
        ossos.girar(arm, "pe_" + lado, x=-(perna + canela + p["raiz"]))
    ossos.pisar(arm)
    ossos.encaixar_x(arm)

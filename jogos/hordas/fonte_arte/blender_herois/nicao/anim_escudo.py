"""ESCUDO / DEFESA (guarda firme, o secundário do Nicão): 2 quadros. q0 = ENTRADA (a marreta sobe do chão na diagonal, o corpo se agacha); q1 = GUARDA: o cabo
atravessa o peito na horizontal, as duas mãos nele, a cabeça da marreta para a esquerda da tela, joelhos dobrados, o tronco pesa para a frente (o jogo
fica no último quadro enquanto o botão está apertado, ver heroi.gd: _coluna_por_tempo).

A marreta é posada no espaço do herói (ossos.empunhar) e as mãos a seguram por IK (ossos.segurar).
"""
import ossos

N_QUADROS = 2
S_POR_QUADRO = [0.07, 0.12]

# g = onde fica a mão em d0 (espaço do herói), elev/azim da marreta (graus), agacha, tronco
QUADROS = [
    dict(g=(0.05, -0.45, 1.55), elev=55, azim=-70, agacha=0.20, tx=0.08),
    dict(g=(0.00, -0.60, 1.80), elev=10, azim=-85, agacha=0.45, tx=0.15),
]


def posar(arm, quadro, n_quadros):
    p = QUADROS[quadro]
    a = p["agacha"]
    ossos.girar(arm, "perna_e", x=-(0.22 + 0.35 * a))
    ossos.girar(arm, "canela_e", x=0.20 + 0.70 * a)
    ossos.girar(arm, "perna_d", x=0.10 + 0.20 * a)
    ossos.girar(arm, "canela_d", x=0.10 + 0.40 * a)
    ossos.girar(arm, "pe_e", x=0.25)
    ossos.girar(arm, "pe_d", x=-0.15)
    ossos.girar(arm, "quadril", x=-0.08 * a)
    ossos.girar(arm, "torso", x=p["tx"])
    ossos.girar(arm, "cabeca", x=-0.5 * p["tx"])
    ossos.empunhar(arm, p["g"], ossos.dirv(p["elev"], p["azim"]), d0=0.0)
    ossos.segurar(arm, mao_e=0.55, mao_d=0.0)      # a cabeça aponta para -x: a mão da esquerda da tela é a de cima
    ossos.pisar(arm)
    ossos.encaixar_x(arm)

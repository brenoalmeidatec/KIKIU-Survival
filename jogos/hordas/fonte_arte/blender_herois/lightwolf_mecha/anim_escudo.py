"""ESCUDO / MATRIZ DE DEFESA: 2 quadros. q0 = ENTRADA (agacha, os canhoes sobem); q1 = GUARDA: antebracos levantados cruzando a frente do peito (os canhoes apontam para cima
e para a frente), joelhos dobrados, o tronco pesa para a frente. O jogo fica no ultimo quadro enquanto o botao esta apertado (heroi.gd: _coluna_por_tempo)."""
import ossos

N_QUADROS = 2
S_POR_QUADRO = [0.07, 0.12]

QUADROS = [dict(agacha=0.20, tx=0.06, braco=-0.50, ante=-0.60, y=0.10),
           dict(agacha=0.45, tx=0.14, braco=-0.70, ante=-1.10, y=0.28)]


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
    ossos.girar(arm, "braco_e", x=p["braco"], y=-p["y"])      # os bracos fecham para o centro
    ossos.girar(arm, "braco_d", x=p["braco"], y=p["y"])
    ossos.girar(arm, "antebraco_e", x=p["ante"])
    ossos.girar(arm, "antebraco_d", x=p["ante"])
    ossos.pisar(arm)
    ossos.encaixar_x(arm)

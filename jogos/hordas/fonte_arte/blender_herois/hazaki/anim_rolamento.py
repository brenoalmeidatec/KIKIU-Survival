"""ROLAMENTO / ESQUIVA: 6 quadros, uma vez só (não é ciclo). Mergulho curto e rápido para a frente, corpo encolhido, volta de pé.

Sequência: agachar (q0), impulso com a perna de trás esticada (q1), encolhido no ar (q2), ápice mais fechado (q3),
pousa e desenrola (q4), de pé (q5). Nos quadros de voo (q2, q3) a raiz sobe com `pisar(extra=...)`, para a bota não
encostar no chão; no resto as botas ficam no chão.

Sinal dos ângulos (x, em radianos): tronco e cabeça apontam para CIMA no rig, então x POSITIVO inclina para frente
(o topo vai para -y). Braços e pernas apontam para BAIXO, então x NEGATIVO leva para frente. O LEIA-ME diz o contrário
para o tronco; isso foi conferido no rig (gerar.py, osso "torso") e na folha de contato.
Os braços são dados em ângulo do mundo (cada osso soma o do pai), e o posar converte para relativos; a cabeça é relativa ao tronco.
A katana (antebraço direito) fica apontando para baixo, levemente para trás nos quadros de voo, para a lâmina não sair do quadro de 32x44.
"""
import ossos

N_QUADROS = 6

# (tronco, cabeça (relativa ao tronco), coxa_e, coxa_d, joelho_e, joelho_d,
#  braço_e (mundo), antebraço_e (mundo), braço_d (mundo), antebraço_d (mundo), subida da raiz)
QUADROS = (
    (0.20, 0.00, -0.35, -0.35, 0.80, 0.80, -0.10, -0.30, -0.10, 0.15, 0.00),    # q0: agachar, braços à frente
    (0.35, -0.05, -0.55, 0.30, 1.10, 0.20, -0.10, -0.20, -0.10, 0.15, 0.00),    # q1: impulso (perna de trás esticada)
    (0.50, -0.20, -1.05, -1.05, 1.85, 1.85, 0.20, -0.45, 0.00, 0.20, 0.30),     # q2: encolhido no ar
    (0.55, -0.20, -1.10, -1.10, 1.95, 1.95, 0.20, -0.45, 0.00, 0.20, 0.40),     # q3: ápice, o mais fechado
    (0.40, 0.00, -0.60, -0.40, 0.85, 0.65, -0.10, -0.30, -0.05, 0.10, 0.05),    # q4: pousa e desenrola
    (0.10, -0.05, -0.08, -0.08, 0.12, 0.12, -0.10, -0.30, -0.05, -0.10, 0.00),  # q5: de pé
)


def posar(arm, quadro, n_quadros):
    tronco, cabeca, c_e, c_d, j_e, j_d, b_e, a_e, b_d, a_d, subida = QUADROS[quadro]
    ossos.girar(arm, "torso", x=tronco)
    ossos.girar(arm, "cabeca", x=cabeca)
    ossos.girar(arm, "perna_e", x=c_e)
    ossos.girar(arm, "perna_d", x=c_d)
    ossos.girar(arm, "canela_e", x=j_e)
    ossos.girar(arm, "canela_d", x=j_d)
    # a bota acompanha a canela (quase plana no chão, dobrada no ar)
    ossos.girar(arm, "pe_e", x=-(c_e + j_e) * 0.9)
    ossos.girar(arm, "pe_d", x=-(c_d + j_d) * 0.9)
    ossos.girar(arm, "braco_e", x=b_e - tronco)
    ossos.girar(arm, "antebraco_e", x=a_e - b_e)
    ossos.girar(arm, "braco_d", x=b_d - tronco)
    ossos.girar(arm, "antebraco_d", x=a_d - b_d)
    ossos.pisar(arm, extra=subida)

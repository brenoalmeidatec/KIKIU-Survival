"""COMBO DA KATANA: 3 golpes x 4 quadros (antecipação, golpe, impacto com a lâmina estendida em arco amplo, volta).

Golpe 1: corte horizontal da direita para a esquerda, a lâmina varre a frente do peito (q0-q3).
Golpe 2: corte horizontal da esquerda para a direita, o contrário do golpe 1 (q4-q7).
Golpe 3: corte descendente mais forte, da altura do ombro direito para a frente-baixa, com passo à frente da perna esquerda (q8-q11).

Os ângulos de tronco e braço da katana foram resolvidos a partir da posição da PONTA da lâmina (cinemática direta
do rig: ombro-cotovelo 0,507, cotovelo-ponta 1,531). Limites para caber nos 32 px em todas as direções: ponta a até
~1,05 unidades do eixo do herói (o quadro tem ~1,25 de meia-largura), cotovelo fora do tórax, cabeça no topo do quadro.
O braço esquerdo fica voltado para dentro, para não encostar na borda do quadro nem cruzar a lâmina.
"""
import ossos

N_QUADROS = 12

# tronco, quadril e braço da katana em (x, y, z) (radianos; forma principal do giro);
# perna/canela da esquerda (_e) e da direita (_d) em x; o pé é compensado para manter a orientação do repouso.
QUADROS = [
    # GOLPE 1 (D -> E)
    dict(nome="antecipacao1", torso=(0.04, 0.0, 0.30), quadril=(0.0, 0.0, 0.12),
         braco=(2.838, -1.226, 2.692), antebraco=(1.773, -0.261, 2.056)),
    dict(nome="golpe1", torso=(0.06, 0.0, 0.05), quadril=(0.0, 0.0, 0.02),
         braco=(-3.132, -1.316, 2.663), antebraco=(1.931, -0.518, 2.196)),
    dict(nome="impacto1", torso=(0.10, 0.0, -0.40), quadril=(0.0, 0.0, -0.15),
         braco=(0.676, 0.268, 0.360), antebraco=(-1.377, -0.226, -0.854)),
    dict(nome="volta1", torso=(0.06, 0.0, -0.25), quadril=(0.0, 0.0, -0.10),
         braco=(2.823, 1.175, -0.851), antebraco=(-2.791, -1.187, -2.407)),
    # GOLPE 2 (E -> D)
    dict(nome="antecipacao2", torso=(0.04, 0.0, -0.35), quadril=(0.0, 0.0, -0.12),
         braco=(-0.728, 1.033, 2.157), antebraco=(-2.310, -1.157, -2.269)),
    dict(nome="golpe2", torso=(0.06, 0.0, 0.05), quadril=(0.0, 0.0, 0.0),
         braco=(-0.039, -1.483, -0.775), antebraco=(2.708, 1.274, -3.025)),
    dict(nome="impacto2", torso=(0.35, 0.0, 0.0), quadril=(0.0, 0.0, 0.0),
         braco=(2.405, -0.389, 1.843), antebraco=(-1.926, -0.574, -1.332)),
    dict(nome="volta2", torso=(0.06, 0.0, 0.10), quadril=(0.0, 0.0, 0.05),
         braco=(2.595, -1.392, 2.774), antebraco=(3.005, 1.485, -3.016)),
    # GOLPE 3 (descendente, com passo a frente da perna esquerda)
    dict(nome="antecipacao3", torso=(0.0, 0.0, 0.10), quadril=(0.0, 0.0, 0.04),
         braco=(0.853, 0.389, -2.462), antebraco=(-2.512, 1.031, 2.612)),
    dict(nome="golpe3", torso=(0.25, 0.0, 0.0), quadril=(0.0, 0.0, 0.0),
         braco=(2.880, -1.534, 2.901), antebraco=(2.794, 1.321, -2.947), perna_e=-0.30, canela_e=0.10),
    dict(nome="impacto3", torso=(0.30, 0.0, -0.05), quadril=(0.0, 0.0, 0.0),
         braco=(2.411, 1.091, -1.865), antebraco=(2.215, 1.263, -0.924),
         perna_e=-0.36, canela_e=0.22, perna_d=0.12, canela_d=0.25),
    dict(nome="volta3", torso=(0.12, 0.0, 0.10), quadril=(0.0, 0.0, 0.03),
         braco=(2.513, -0.677, -2.657), antebraco=(2.539, -0.806, 2.022),
         perna_e=-0.15, canela_e=0.10, perna_d=0.04, canela_d=0.10),
]


def _gira(arm, osso, v):
    ossos.girar(arm, osso, x=v[0], y=v[1], z=v[2])


def posar(arm, quadro, n_quadros):
    q = QUADROS[quadro]
    _gira(arm, "quadril", q["quadril"])
    _gira(arm, "torso", q["torso"])
    ossos.girar(arm, "cabeca", z=-0.5 * q["torso"][2])      # a cabeça desfaz metade do giro do tronco (olha para a frente)
    _gira(arm, "braco_d", q["braco"])
    _gira(arm, "antebraco_d", q["antebraco"])
    # braço esquerdo em guarda discreta, voltado para dentro (fora da borda e da lâmina)
    ossos.girar(arm, "braco_e", y=-0.10)
    ossos.girar(arm, "antebraco_e", x=-0.35)
    # pernas: repouso, exceto o passo do golpe 3 (perna esquerda à frente, direita atrás)
    pe, ca = q.get("perna_e", 0.0), q.get("canela_e", 0.0)
    pd, cd = q.get("perna_d", 0.0), q.get("canela_d", 0.0)
    ossos.girar(arm, "perna_e", x=pe)
    ossos.girar(arm, "canela_e", x=ca)
    ossos.girar(arm, "pe_e", x=-(pe + ca))
    ossos.girar(arm, "perna_d", x=pd)
    ossos.girar(arm, "canela_d", x=cd)
    ossos.girar(arm, "pe_d", x=-(pd + cd))
    ossos.pisar(arm)

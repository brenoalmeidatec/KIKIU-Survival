"""STRAFE (andar de lado, passo-junta) do Lucas: a MESMA receita do ../hazaki/anim_strafe.py (6 quadros no ritmo do andar, 0,09 s; dois passo-junta
de 3 quadros: junta, abre, apoia), com os braços do anim_andar do Lucas (balanço reduzido) e as adagas como no andar (só na mão direita).
O corpo fica de frente para a mira; as pernas abrem PERPENDICULAR à mira, no eixo x do herói. Tocado para a frente, o passo vai para o +x do
herói (a perna d, da adaga, abre e a e junta); tocado ao contrário (o jogo inverte o sentido do ciclo, como no recuo da rodada 4), vira o
passo-junta para -x com a perna e conduzindo. Uma animação só cobre os dois lados.

Convenção (ossos.py): girar(y=) inclina de lado com o TOPO indo para +x; numa perna (osso apontado para baixo) y NEGATIVO leva o pé para +x.
A bota anula a inclinação da perna (apoio plano); ossos.pisar ancora o pé mais baixo no chão (o sobe-e-desce sai das pernas).
Limite conhecido: o passo real do jogo (118 px/s x 0,27 s = ~32 px por passo-junta) não cabe numa célula de 32 px sem cruzar os pés; o pé
de apoio desliza ~1/3 disso, então ainda patina um pouco no jogo, como o andar de frente.
"""
import math

import ossos

N_QUADROS = 6

# por quadro do passo (0 junta, 1 abre, 2 apoia): (inclinação y da perna, levantada?) da perna d (conduz) e da e (segue); igual ao Hazaki
PASSO = [
    {"d": (-0.06, False), "e": (-0.08, True)},
    {"d": (-0.34, True), "e": (0.12, False)},
    {"d": (-0.24, False), "e": (0.26, False)},
]
JOELHO_ERGUIDO = 0.55   # dobra do joelho da perna que está no ar
COXA_ERGUIDA = -0.22    # a coxa no ar vai um pouco à frente (o pé sobe sem arrastar)
JOELHO_BASE = 0.10      # mesmo do andar
BALANCO = 0.04          # o quadril pende um pouco para o lado da perna de apoio (o tronco compensa)
BRACO = 0.12            # metade do balanço do anim_andar (0,24): de lado o braço quase não vai à frente
BRACO_ADAGA = 0.10      # metade do 0,20 do andar
ABRE_BRACO = 0.10       # o braço do lado que abre vai um pouco para fora (equilíbrio)


def _perna(arm, lado, inclina, erguida):
    coxa_x = COXA_ERGUIDA if erguida else 0.0
    joelho = JOELHO_BASE + (JOELHO_ERGUIDO if erguida else 0.0)
    ossos.girar(arm, "perna_" + lado, x=coxa_x, y=inclina)
    ossos.girar(arm, "canela_" + lado, x=joelho)
    ossos.girar(arm, "pe_" + lado, x=-(coxa_x + joelho) * 0.9, y=-inclina)


def posar(arm, quadro, n_quadros):
    p = PASSO[quadro % 3]
    _perna(arm, "d", *p["d"])
    _perna(arm, "e", *p["e"])
    abre = 1.0 if quadro % 3 == 1 else (0.5 if quadro % 3 == 2 else 0.0)
    apoio = -1.0 if p["d"][1] else (1.0 if p["e"][1] else 0.0)   # -1: apoio na e (topo pende para -x)
    ossos.girar(arm, "quadril", y=BALANCO * apoio, x=-0.04)
    ossos.girar(arm, "torso", y=-BALANCO * apoio)
    # braços do anim_andar (oposto à fase, cotovelo dobra no que vai à frente), com metade do balanço; o d abre quando a perna d abre
    c = math.cos(2 * math.pi * quadro / n_quadros)
    ossos.girar(arm, "braco_e", x=BRACO * c, y=0.03)
    ossos.girar(arm, "braco_d", x=-BRACO_ADAGA * c, y=-ABRE_BRACO * abre)
    ossos.girar(arm, "antebraco_e", x=-0.20 - 0.30 * max(0.0, -c))
    ossos.girar(arm, "antebraco_d", x=-0.20 - 0.30 * max(0.0, c))
    ossos.pisar(arm)

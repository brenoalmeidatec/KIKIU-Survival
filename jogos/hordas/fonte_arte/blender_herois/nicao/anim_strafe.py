"""STRAFE (andar de lado com o corpo virado para a mira): 6 quadros = dois "passo-junta" de 3 (junta, abre, apoia), no MESMO ritmo do andar
(0,11 s por quadro), para o jogo trocar andar <-> strafe sem travar o passo (a fase `_anim` é a mesma).

O passo vai para +x do herói (a direita da TELA quando ele olha para a câmera, linha "baixo"): a perna direita (_d) abre, apoia, e a esquerda (_e)
vem juntar. O lado oposto é esta MESMA animação tocada ao contrário (o heroi.gd usa sentido = lado): passo-junta invertido no tempo é o passo-junta
para o outro lado, com o pé de apoio parado no chão. Por isso o pé que está no chão SEMPRE anda para -x no espaço do corpo, quadro a quadro
(o corpo passa por cima dele), e o pé no ar avança para +x: tocado em qualquer sentido, nenhum pé patina para trás.

Pernas por abdução (girar y: a bota vai para o lado), a bota fica reta no chão (o pé desfaz a abdução) e o joelho dobra só na perna que está no ar.
O quadril cai sozinho quando as pernas abrem (ossos.pisar ancora pela bota mais baixa); o tronco inclina pouco para o lado do passo.
Braços e marreta: a pose do andar no meio do passo (c = 0 do anim_andar), com o IK das duas mãos depois do tronco (mesma ordem do anim_andar).
"""
import ossos

N_QUADROS = 6
S_POR_QUADRO = 0.11

A = 0.30            # rad: unidade de abdução (a abertura maior é 1,6 A + A entre as duas pernas)
LEVANTA = 0.80      # rad: dobra do joelho da perna no ar
INCLINA = 0.06      # rad: tronco inclina para o lado do passo

# por quadro do passo-junta (0 junta, 1 abre, 2 apoia): abdução da bota (+ = para +x) e quanto cada perna está no ar (0..1)
#   perna direita: 0 -> 1,6A (no ar, abrindo) -> A (apoiada; daí volta a 0 no chão, o corpo passa por cima)
#   perna esquerda: 0 -> -A (apoiada, o corpo passa por cima) -> -0,4A (no ar, vindo juntar) -> 0
ABD_D = (0.0, 1.6 * A, 1.0 * A)
ABD_E = (0.0, -1.0 * A, -0.4 * A)
AR_D = (0.0, 1.0, 0.0)
AR_E = (0.0, 0.0, 1.0)
LADO = (0.0, 1.0, 0.5)   # inclinação do tronco para +x (máxima quando abre)


def _perna(arm, lado, abd, ar):
    coxa_x = -0.30 * ar                      # a perna no ar vem um pouco à frente (o joelho do anão aparece)
    joelho = 0.06 + LEVANTA * ar
    ossos.girar(arm, "perna_" + lado, x=coxa_x, y=-abd)
    ossos.girar(arm, "canela_" + lado, x=joelho)
    ossos.girar(arm, "pe_" + lado, x=-(coxa_x + joelho) * 0.9, y=abd)


def posar(arm, quadro, n_quadros):
    k = quadro % 3
    _perna(arm, "d", ABD_D[k], AR_D[k])
    _perna(arm, "e", ABD_E[k], AR_E[k])
    lado = LADO[k]
    # quadril cai do lado da perna no ar; o tronco compensa e inclina para o passo; a cabeça fica reta (olha para a mira)
    ossos.girar(arm, "quadril", x=-0.05, y=-0.05 * (AR_D[k] - AR_E[k]))
    ossos.girar(arm, "torso", x=0.10, y=-INCLINA * lado)
    ossos.girar(arm, "cabeca", x=-0.06, y=0.5 * INCLINA * lado)
    # braço direito solto (pose do andar com c = 0), balança pouco para fora quando abre
    ossos.girar(arm, "braco_d", x=-0.15, y=-0.10 - 0.08 * lado)
    ossos.girar(arm, "antebraco_d", x=-0.45)
    # marreta: inclinada para a frente como no andar; o cabo quica no apoio (quadro 2)
    ossos.girar(arm, "marreta", x=0.30, y=0.03 * lado)
    ossos.mover(arm, "marreta", z=0.10 + 0.04 * (1.0 if k == 1 else 0.0), y=-0.10)
    ossos.segurar(arm)
    ossos.pisar(arm)

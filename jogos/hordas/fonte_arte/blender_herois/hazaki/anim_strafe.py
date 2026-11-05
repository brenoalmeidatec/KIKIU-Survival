"""STRAFE (andar de lado, passo-junta): 6 quadros no MESMO ritmo do andar (0,09 s), dois passo-junta de 3 quadros (junta, abre, apoia).
O corpo fica de frente para a mira (sem giro de quadril, tronco e cabeça retos); as pernas abrem PERPENDICULAR à mira, no eixo x do herói.
Tocado para a frente, o passo vai para o +x do herói (a perna d, da katana, abre na frente e a e junta); tocado ao contrário (o jogo inverte o
sentido do ciclo, como no recuo da rodada 4), vira o passo-junta para o -x, com a perna e conduzindo. Por isso uma animação só cobre os dois lados.

Convenção (ossos.py): girar(y=) inclina de lado com o TOPO indo para +x; numa perna (osso apontado para baixo) y NEGATIVO leva o pé para +x.
A bota anula a inclinação da perna (apoio plano); ossos.pisar ancora o pé mais baixo no chão (o sobe-e-desce sai das pernas).
"""
import ossos

N_QUADROS = 6

# por quadro do passo (0 junta, 1 abre, 2 apoia): (inclinação y da perna, levantada?) da perna d (conduz) e da e (segue)
#   junta: d plantada quase sob o quadril, e chega levantada ao lado dela
#   abre:  d sai levantada para +x, e plantada (já deslizando para -x em relação ao corpo, que anda para +x)
#   apoia: base aberta, as duas plantadas
PASSO = [
    {"d": (-0.06, False), "e": (-0.08, True)},
    {"d": (-0.34, True), "e": (0.12, False)},
    {"d": (-0.24, False), "e": (0.26, False)},
]
JOELHO_ERGUIDO = 0.55   # dobra do joelho da perna que está no ar
COXA_ERGUIDA = -0.22    # a coxa no ar vai um pouco à frente (o pé sobe sem arrastar)
JOELHO_BASE = 0.10      # joelho nunca totalmente esticado (mesmo do andar)
BALANCO = 0.04          # o quadril pende um pouco para o lado da perna de apoio
BRACO_E = 0.10          # o braço livre abre um pouco para fora quando a perna abre (equilíbrio); o da katana quase não mexe


def _perna(arm, lado, inclina, erguida):
    coxa_x = COXA_ERGUIDA if erguida else 0.0
    joelho = JOELHO_BASE + (JOELHO_ERGUIDO if erguida else 0.0)
    ossos.girar(arm, "perna_" + lado, x=coxa_x, y=inclina)
    ossos.girar(arm, "canela_" + lado, x=joelho)
    # bota plana: anula a inclinação de lado e a da coxa + joelho (como o andar)
    ossos.girar(arm, "pe_" + lado, x=-(coxa_x + joelho) * 0.9, y=-inclina)


def posar(arm, quadro, n_quadros):
    p = PASSO[quadro % 3]
    _perna(arm, "d", *p["d"])
    _perna(arm, "e", *p["e"])
    abre = 1.0 if quadro % 3 == 1 else (0.5 if quadro % 3 == 2 else 0.0)
    # quadril e tronco de frente para a mira: só um leve pender de lado para a perna de apoio, o tronco compensa (ombros nivelados)
    apoio = -1.0 if p["d"][1] else (1.0 if p["e"][1] else 0.0)   # -1: apoio na e (topo pende para -x)
    ossos.girar(arm, "quadril", y=BALANCO * apoio, x=-0.04)
    ossos.girar(arm, "torso", y=-BALANCO * apoio)
    # braços: a pose neutra do andar (cotovelos dobrados como no meio do ciclo), com pouco balanço
    ossos.girar(arm, "braco_e", x=0.0, y=BRACO_E * abre)
    ossos.girar(arm, "braco_d", x=-0.02)
    ossos.girar(arm, "antebraco_e", x=-0.30)
    ossos.girar(arm, "antebraco_d", x=-0.04)
    ossos.pisar(arm)

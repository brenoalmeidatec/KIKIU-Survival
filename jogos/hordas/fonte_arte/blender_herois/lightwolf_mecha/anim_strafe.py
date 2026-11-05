"""STRAFE (andar de lado): 6 quadros, dois PASSO-JUNTA de 3 (abre, apoia, junta) para o +x do rig, no mesmo ritmo do andar (0,11 s por quadro,
a mesma fase _anim do heroi.gd: trocar andar <-> strafe não tropeça o passo). Pedido do Alisson (05/11): "Faça animação do strafe (andar de
lado) que não parece existir". O corpo continua virado para a linha da folha (a mira); só as pernas abrem e fecham de lado.

Cinemática (unidades do modelo, x = lado do rig): o corpo anda D por passo-junta para +x. Fase p em [0, 1) de cada passo:
  p em [0, 1/2): a perna da FRENTE (_d, x > 0) voa de "junta" para "aberta" (+D/2); a de TRÁS (_e) está no chão e, no espaço do corpo,
                 escorrega para -x na velocidade do corpo (no chão ela está parada: pé plantado sem patinar).
  p em [1/2, 1): a da frente está no chão (volta de +D/2 a 0 no espaço do corpo) e a de trás voa de -D/2 de volta a 0 (junta).
As pernas só ABREM (abdução), nunca cruzam nem fecham além do repouso: as botas do mecha já quase se tocam em pé.
Os quadros amostram p = 1/6 (abre: a da frente no ar), 1/2 (apoia: as duas no chão, base larga) e 5/6 (junta: a de trás no ar).
Tocado de trás para a frente (o heroi.gd faz isso para o outro lado) é o passo-junta para -x: o pé plantado continua parado no chão.
"""
import math

import ossos

N_QUADROS = 6
S_POR_QUADRO = [0.11] * N_QUADROS   # o mesmo ritmo do andar (animacoes.andar.s_por_quadro)
ABRE = 0.75          # rad de abdução máxima da coxa na base larga (mais que o PERNA do andar: de frente, os canhões pendurados cobrem parte das pernas)
# Pé plantado sem patinar pediria ~10 px por quadro (vel 90 px/s x 0,11 s); com as pernas de ~0,64 de alavanca lateral medida (bota) o
# máximo legível dá ~7 px por quadro (o andar também anda menos que o corpo). Medido no Blender: ver o LEIA-ME (strafe).
LEVANTA = 0.75       # rad de dobra da coxa da perna no ar (o joelho dobra o dobro): o pé sai do chão
QUADRIL_Y = 0.05     # o quadril tomba de leve para o lado da perna de apoio


def _pernas(arm, quadro, n_quadros):
    """Posa as pernas do passo-junta e devolve o peso (-1 = apoio na _e, +1 = apoio na _d, 0 = nas duas)."""
    passos = 2
    por = n_quadros // passos
    p = ((quadro % por) + 0.5) / por                      # 1/6, 1/2, 5/6
    if p < 0.5:
        voo = p / 0.5                                      # progresso do voo da perna da frente
        e_d, e_e = voo, p / 0.5                            # fração da abertura; a de trás plantada anda -x no corpo, junto com ele
        lev_d, lev_e = math.sin(math.pi * voo), 0.0
        peso = -1.0
    else:
        voo = (p - 0.5) / 0.5
        e_d, e_e = 1.0 - voo, 1.0 - voo                    # a da frente plantada volta no corpo; a de trás voa de volta a junta
        lev_d, lev_e = 0.0, math.sin(math.pi * voo)
        peso = 1.0
    if abs(p - 0.5) < 1e-6:
        peso = 0.0
    for lado, e, lev, s in (("d", e_d, lev_d, 1.0), ("e", e_e, lev_e, -1.0)):
        ab = math.asin(e * math.sin(ABRE))                 # abdução: o pé vai para fora (+x na _d, -x na _e), LINEAR em x (asin):
        #                                                    o pé plantado anda no corpo a passo constante, sem acelerar nem frear
        ossos.girar(arm, "perna_" + lado, x=-LEVANTA * lev, y=-s * ab)
        ossos.girar(arm, "canela_" + lado, x=_joelho(lev))
        ossos.girar(arm, "pe_" + lado, x=-(-LEVANTA * lev + _joelho(lev)) * 0.9, y=s * ab)
    return peso


def _joelho(lev):
    return 0.08 + 2.0 * LEVANTA * lev


def posar(arm, quadro, n_quadros):
    peso = _pernas(arm, quadro, n_quadros)
    ossos.girar(arm, "quadril", x=-0.05, y=QUADRIL_Y * peso)
    ossos.girar(arm, "torso", x=0.10, y=-0.6 * QUADRIL_Y * peso)
    ossos.girar(arm, "cabeca", x=-0.06)
    # bracos pesados, soltos como no andar, sem o balanço para a frente (o passo é de lado): só acompanham o tombo do quadril
    for lado, s in (("e", -1.0), ("d", 1.0)):
        ossos.girar(arm, "braco_" + lado, x=-0.10, y=0.05 * peso)
        ossos.girar(arm, "antebraco_" + lado, x=-0.15)
    ossos.pisar(arm)

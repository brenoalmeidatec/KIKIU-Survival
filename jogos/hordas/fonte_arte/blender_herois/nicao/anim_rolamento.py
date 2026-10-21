"""ROLAMENTO / ESQUIVA: 6 quadros, uma vez só (não é ciclo). Mesma mecânica do rolamento do Hazaki (agacha, mergulha encolhido, gira mais de uma volta
em torno do próprio centro, abre e sai agachado), com a diferença do anão: peso e marreta.

A marreta fica DEITADA ao longo do eixo do rolamento (horizontal, de lado, presa às duas mãos junto ao peito): como o giro é em torno do eixo x,
o cabo gira sobre si e não varre um círculo grande em volta do corpo (de pé ela passaria do quadro e do chão). `ossos.ancorar` só conta o corpo
(a cabeça da marreta pode passar do chão no giro; sem chão desenhado, não aparece).

Como gira: `raiz` (pivô nos pés) recebe o ângulo do tombo para a frente (x POSITIVO = o topo vai para a frente); `ossos.ancorar` reposiciona o corpo
INTEIRO a cada quadro (encosta no chão, mesma linha de baixo, centra em x): ele rola "no lugar" e o jogo move a posição.
Poeira (`efeito`): quadradinhos claros no chão, atrás do herói, nos quadros 1 a 5.
"""
import math

import ossos

N_QUADROS = 6
S_POR_QUADRO = [0.08, 0.07, 0.06, 0.06, 0.07, 0.10]

# giro da raiz (rad), tronco, cabeça, coxas, canelas (rad; as duas pernas iguais), subida (extra_z), pé (0 = solto, 0.8 = plano), marreta (rad, em y; -1.5 = deitada)
QUADROS = [
    dict(giro=0.00, tronco=0.35, cabeca=0.10, coxa=-0.70, canela=1.30, sobe=0.0, pe=0.8, marreta=-0.9),
    dict(giro=0.60, tronco=1.60, cabeca=0.60, coxa=-1.90, canela=2.40, sobe=0.0, pe=0.0, marreta=-1.5),
    dict(giro=2.00, tronco=1.45, cabeca=0.80, coxa=-2.30, canela=2.75, sobe=0.08, pe=0.0, marreta=-1.5),
    dict(giro=4.20, tronco=1.45, cabeca=0.80, coxa=-2.30, canela=2.75, sobe=0.10, pe=0.0, marreta=-1.5),
    dict(giro=5.10, tronco=1.20, cabeca=0.60, coxa=-1.95, canela=2.50, sobe=0.04, pe=0.0, marreta=-1.5),
    dict(giro=2 * math.pi, tronco=0.30, cabeca=0.0, coxa=-0.60, canela=1.05, sobe=0.0, pe=0.8, marreta=-0.5),
]


def posar(arm, quadro, n_quadros):
    p = QUADROS[quadro]
    ossos.girar(arm, "raiz", x=p["giro"])
    ossos.girar(arm, "torso", x=p["tronco"])
    ossos.girar(arm, "cabeca", x=p["cabeca"])
    for lado in ("e", "d"):
        ossos.girar(arm, "perna_" + lado, x=p["coxa"])
        ossos.girar(arm, "canela_" + lado, x=p["canela"])
        ossos.girar(arm, "pe_" + lado, x=-(p["coxa"] + p["canela"]) * p["pe"])
    # marreta deitada de lado diante do peito, as duas mãos nela
    f = (-p["marreta"]) / 1.5
    ossos.girar(arm, "marreta", y=p["marreta"])
    ossos.mover(arm, "marreta", x=1.60 * f, y=-0.15 * f, z=0.25 * f)
    ossos.segurar(arm, mao_e=0.55 if f > 0.6 else 0.0, mao_d=-0.25 if f > 0.6 else None)
    if f <= 0.6:
        ossos.girar(arm, "braco_d", x=-0.4)
        ossos.girar(arm, "antebraco_d", x=-0.7)
    ossos.ancorar(arm, extra_z=p["sobe"])


# poeira: (quadro) -> lista de (distância atrás, lado, tamanho) em unidades do mundo (1 px = 0,041)
POEIRA = {
    1: [(0.55, -0.10, 0.11), (0.90, 0.12, 0.08)],
    2: [(0.60, 0.00, 0.12), (1.00, -0.14, 0.09), (1.20, 0.10, 0.07)],
    3: [(0.65, 0.12, 0.12), (1.05, -0.10, 0.09), (1.25, 0.02, 0.07)],
    4: [(0.60, -0.12, 0.11), (0.95, 0.10, 0.08)],
    5: [(0.55, 0.05, 0.10)],
}
POEIRA_COR = ((176, 160, 148), (130, 118, 112))


def efeito(arm, quadro, n_quadros, ang):
    from mathutils import Vector
    pts = POEIRA.get(quadro)
    if not pts:
        return []
    a = math.radians(ang)
    atras = Vector((-math.sin(a), math.cos(a), 0.0))      # oposto à frente do herói (a frente, a 0 grau, é -y)
    lado = Vector((math.cos(a), math.sin(a), 0.0))
    origem = Vector(arm.location)
    origem.z = 0.0
    saida = []
    for i, (d, s, t) in enumerate(pts):
        c = origem + atras * d + lado * s
        saida.append(([c + Vector((-t, 0, 0)), c + Vector((t, 0, 0)), c + Vector((t, 0, t * 1.4)), c + Vector((-t, 0, t * 1.4))],
                      POEIRA_COR[i % 2]))
    return saida

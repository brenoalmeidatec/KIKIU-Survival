"""MORTE: 6 quadros, uma vez só. Leva o golpe (q0), cede os joelhos e solta a marreta (q1), tomba DE LADO (q2, ease-in), BATE no chão (q3, o quadro de
impacto), rebate 1 px e assenta (q4) e fica deitado atravessado na tela, encolhido (q5, o quadro que fica). Mesma queda do Hazaki: o herói gira em pé o
MENOR ângulo que o deixa de frente ou de costas para a câmera e ROLA em torno do eixo frente-trás dele, terminando com a cabeça para a esquerda ou a direita
da TELA (nunca de cabeça para baixo). `ossos.ancorar` encosta o corpo (só o corpo) no chão e o centra em x a cada quadro.

A MARRETA escapa da mão: q0 e q1 ela ainda é segurada (IK); do q2 em diante é posada solta no mundo (ossos.empunhar): tomba para o lado oposto ao da cabeça
do anão e cai DEITADA no chão à frente dele, o cabo ao longo da tela. A posição do mundo é convertida para o espaço do herói (o objeto gira por direção).

Sinais: raiz x NEGATIVO = tomba para trás (pivô nos pés), y = rola de lado; tronco e cabeça: x NEGATIVO = para trás; braço, antebraço, perna e canela:
x NEGATIVO = para a frente. Braço y: o da marreta (esquerda da tela, _e) abre para fora com y POSITIVO... ver a tabela (herdada do anim_morte do Hazaki, com os lados trocados).
"""
import math

from mathutils import Vector

import ossos

N_QUADROS = 6
S_POR_QUADRO = [0.10, 0.11, 0.08, 0.05, 0.10, 0.40]

# raiz (tombo), tronco, cabeça (x, e z = rolagem para o lado), braços (x, y), antebraços (x), pernas e canelas (x), rebote (z extra)
QUADROS = [
    dict(raiz=0.0, tronco=-0.28, cabeca=-0.40,
         braco_e=(0.50, 0.15), antebraco_e=-0.40, braco_d=(0.60, -0.10), antebraco_d=-0.60,
         perna_e=0.10, canela_e=0.40, perna_d=-0.10, canela_d=0.30),
    dict(raiz=-0.30, tronco=-0.30, cabeca=-0.35,
         braco_e=(0.80, 0.25), antebraco_e=-0.30, braco_d=(0.90, -0.20), antebraco_d=-0.30,
         perna_e=-0.35, canela_e=0.80, perna_d=0.20, canela_d=0.55),
    dict(raiz=-0.85, tronco=-0.18, cabeca=-0.30,
         braco_e=(0.30, 0.45), antebraco_e=-0.20, braco_d=(0.30, -0.25), antebraco_d=-0.20,
         perna_e=-0.35, canela_e=0.75, perna_d=-0.15, canela_d=0.50),
    dict(raiz=-1.42, tronco=-0.10, cabeca=-0.45,
         braco_e=(0.0, 0.55), antebraco_e=-0.10, braco_d=(0.0, -0.20), antebraco_d=-0.90,
         perna_e=-0.75, canela_e=1.35, perna_d=-0.35, canela_d=0.75),
    dict(raiz=-1.30, tronco=-0.30, cabeca=-0.40, extra_z=0.12,
         braco_e=(0.15, 0.50), antebraco_e=-0.25, braco_d=(0.15, -0.20), antebraco_d=-1.00,
         perna_e=-0.80, canela_e=1.40, perna_d=-0.40, canela_d=0.80),
    dict(raiz=-1.52, tronco=0.0, cabeca=-0.10, cabeca_z=0.42,
         braco_e=(0.05, 0.30), antebraco_e=-0.05, braco_d=(0.05, -0.05), antebraco_d=-1.30,
         perna_e=-0.66, canela_e=1.25, perna_d=-0.25, canela_d=0.68),
]
DOBRA_PERNA = 1.5
DOBRA_CANELA = 0.6

# marreta solta (a partir do q2): t = quanto da queda já andou (0 = na mão, 1 = deitada no chão), posição do centro do cabo (relativa ao anão, no
# PLANO DA TELA: x direita, y para trás, z para cima) no fim da queda
MARRETA_T = {2: 0.55, 3: 0.92, 4: 1.0, 5: 1.0}
MARRETA_FIM = Vector((0.0, -1.05, 0.30))
MARRETA_INICIO = Vector((-1.14, -0.20, 1.60))


def escolher(ang):
    """(giro em radianos, sinal do rolamento): o herói gira em pé o MENOR ângulo que o deixa de frente ou de costas para a câmera e rola de lado,
    então a cabeça aponta para a lateral da TELA. O lado é o contrário do olhar (cai para trás do golpe); de frente ou de costas, para a direita da tela."""
    g = (-ang + 90.0) % 180.0 - 90.0
    yaw = round(math.cos(math.radians(ang + g)))
    lado = -1.0 if math.sin(math.radians(ang)) > 0.1 else 1.0
    return math.radians(g), lado * yaw


def _local(v, ang):
    """Vetor do mundo -> espaço do armature (o objeto está girado `ang` graus em z; a marreta solta não segue a raiz)."""
    a = -math.radians(ang)
    return Vector((v.x * math.cos(a) - v.y * math.sin(a), v.x * math.sin(a) + v.y * math.cos(a), v.z))


def posar(arm, quadro, n_quadros, ang=0.0):
    giro, sinal = escolher(ang)
    p = QUADROS[quadro]
    fase = min(1.0, abs(p["raiz"]) / 0.85)
    w = min(1.0, max(0.0, (abs(p["raiz"]) - 0.3) / 0.55))
    ossos.girar(arm, "raiz", x=p["raiz"] * (1.0 - w) * 0.6, y=sinal * abs(p["raiz"]) * w, z=giro * fase)
    dobra = min(1.0, max(0.0, (abs(p["raiz"]) - 0.85) / 0.55))
    ossos.girar(arm, "torso", x=p["tronco"] * (1.0 - 0.7 * dobra))
    ossos.girar(arm, "cabeca", x=p["cabeca"] * (1.0 - 0.7 * dobra), z=p.get("cabeca_z", 0.0) * 0.5)
    for lado in ("e", "d"):
        bx, by = p["braco_" + lado]
        by += (-0.40 if lado == "e" else 0.40) * fase
        ossos.girar(arm, "braco_" + lado, x=bx, y=by)
        ossos.girar(arm, "antebraco_" + lado, x=p["antebraco_" + lado])
        perna, canela = p["perna_" + lado] - DOBRA_PERNA * dobra, p["canela_" + lado] + DOBRA_CANELA * dobra
        ossos.girar(arm, "perna_" + lado, x=perna)
        ossos.girar(arm, "canela_" + lado, x=canela)
        plana = -(perna + canela + p["raiz"])
        ossos.girar(arm, "pe_" + lado, x=plana * max(0.0, 1.0 - fase * 1.3))
    ossos.ancorar(arm, extra_z=p.get("extra_z", 0.0))

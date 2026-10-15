"""MORTE: 8 quadros, uma vez só. Leva o golpe (q0), cede os joelhos e cambaleia (q1), tomba (q2, ease-in: o corpo ganha velocidade), BATE no chão
(q3, o quadro de impacto), REBOTA 1 px (q4), assenta (q5) e fica deitado (q6 e q7: dois quadros de repouso, a cabeça rola para o lado).

Enquadramento (célula fixa 32x44; o herói em pé tem 44 px): ele cai DE LADO. Primeiro cambaleia para trás (q1) e depois ROLA em torno do eixo
frente-trás dele (raiz y), terminando deitado de lado e encolhido (coxas e joelhos dobrados para a frente, que apontam para a câmera e quase não
somam largura), com a cabeça para a esquerda ou para a direita da TELA: atravessado, nunca de cabeça para baixo. O herói gira em pé o MENOR
ângulo que o deixa de frente ou de costas para a câmera (`escolher`, aos poucos, junto com o tombo); o lado é o contrário do olhar. Mesmo
encolhido, o corpo, as botas e a katana passam 3 a 5 px dos 32: o quadro corta (medir.py). `ossos.ancorar` encosta o corpo inteiro no chão e
centra a caixa em x a cada quadro (o `pisar` só olha as botas).

Sinais (ver anim_escudo.py): raiz x NEGATIVO = tomba para trás (pivô nos pés), y = rola de lado; tronco e cabeça: x NEGATIVO = para trás;
braço, antebraço, perna e canela: x NEGATIVO = para a frente. Braço y: o da katana (direito da tela, _d) abre para fora com y NEGATIVO, o esquerdo
com y POSITIVO. A cabeça NUNCA passa de ~0,5 rad relativos ao tronco em x (acima disso a junta do pescoço abre e a cabeça parece duplicada).
"""
import math

import ossos

N_QUADROS = 8
DOBRA_PERNA = 1.5
DOBRA_CANELA = 0.6
S_POR_QUADRO = [0.10, 0.10, 0.08, 0.05, 0.08, 0.10, 0.25, 0.30]    # tempos sugeridos (q3 = impacto, rápido; q6 e q7 = repouso)

# raiz (tombo), tronco, cabeça (x, e z = rolagem para o lado), braços (x, y), antebraços (x), pernas e canelas (x), rebote (z extra)
QUADROS = [
    # q0: leva o golpe, ainda de pé
    dict(raiz=0.0, tronco=-0.28, cabeca=-0.40,
         braco_e=(0.50, 0.15), antebraco_e=-0.40, braco_d=(0.60, -0.10), antebraco_d=-0.60,
         perna_e=0.10, canela_e=0.40, perna_d=-0.10, canela_d=0.30),
    # q1: os joelhos cedem, cambaleia, braços para trás
    dict(raiz=-0.30, tronco=-0.30, cabeca=-0.35,
         braco_e=(0.80, 0.25), antebraco_e=-0.30, braco_d=(0.90, -0.20), antebraco_d=-0.30,
         perna_e=-0.35, canela_e=0.80, perna_d=0.20, canela_d=0.55),
    # q2: tomba (já no ar, o corpo todo inclinado), braços e pernas soltos
    dict(raiz=-0.85, tronco=-0.18, cabeca=-0.30,
         braco_e=(0.30, 0.45), antebraco_e=-0.20, braco_d=(0.30, -0.25), antebraco_d=-0.20,
         perna_e=-0.35, canela_e=0.75, perna_d=-0.15, canela_d=0.50),
    # q3: IMPACTO, quase deitado, cabeça jogada para trás
    dict(raiz=-1.42, tronco=-0.10, cabeca=-0.45,
         braco_e=(0.0, 0.55), antebraco_e=-0.10, braco_d=(0.0, -0.20), antebraco_d=-0.90,
         perna_e=-0.75, canela_e=1.35, perna_d=-0.35, canela_d=0.75),
    # q4: rebote (o corpo sobe ~1 px e arqueia)
    dict(raiz=-1.30, tronco=-0.30, cabeca=-0.40, extra_z=0.12,
         braco_e=(0.15, 0.50), antebraco_e=-0.25, braco_d=(0.15, -0.20), antebraco_d=-1.00,
         perna_e=-0.80, canela_e=1.40, perna_d=-0.40, canela_d=0.80),
    # q5: assenta
    dict(raiz=-1.50, tronco=-0.04, cabeca=-0.30,
         braco_e=(0.0, 0.40), antebraco_e=-0.15, braco_d=(0.0, -0.10), antebraco_d=-1.20,
         perna_e=-0.70, canela_e=1.30, perna_d=-0.30, canela_d=0.70),
    # q6: repouso, a cabeça rola para o lado
    dict(raiz=-1.52, tronco=0.0, cabeca=-0.15, cabeca_z=0.30,
         braco_e=(0.0, 0.35), antebraco_e=-0.12, braco_d=(0.0, -0.08), antebraco_d=-1.30,
         perna_e=-0.70, canela_e=1.30, perna_d=-0.28, canela_d=0.70),
    # q7: repouso final (a cabeça cai um pouco mais, a mão relaxa)
    dict(raiz=-1.52, tronco=0.0, cabeca=-0.10, cabeca_z=0.42,
         braco_e=(0.05, 0.30), antebraco_e=-0.05, braco_d=(0.05, -0.05), antebraco_d=-1.30,
         perna_e=-0.66, canela_e=1.25, perna_d=-0.25, canela_d=0.68),
]


def escolher(ang):
    """(giro em radianos, sinal do rolamento): o herói gira em pé o MENOR ângulo que o deixa de frente ou de costas para a câmera (yaw total 0 ou 180)
    e rola de lado (em torno do eixo frente-trás dele), então a cabeça aponta para a lateral da TELA: deitado atravessado, nunca de cabeça para baixo.
    O lado é o contrário do olhar (cai para trás do golpe); de frente ou de costas, para a direita da tela."""
    g = (-ang + 90.0) % 180.0 - 90.0                      # giro em pé, em [-90, 90)
    yaw = round(math.cos(math.radians(ang + g)))          # +1 de frente para a câmera, -1 de costas
    lado = -1.0 if math.sin(math.radians(ang)) > 0.1 else 1.0     # lado da TELA para onde a cabeça aponta (+ = direita)
    return math.radians(g), lado * yaw


def posar(arm, quadro, n_quadros, ang=0.0):
    giro, sinal = escolher(ang)
    p = QUADROS[quadro]
    # o giro entra aos poucos (junto com o tombo), para o q0 ainda ser o herói em pé; antes de tombar ele só cambaleia para trás (x),
    # depois rola de lado (y) com as pernas encolhidas (fetal), que é o que cabe nos 32 px de largura
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

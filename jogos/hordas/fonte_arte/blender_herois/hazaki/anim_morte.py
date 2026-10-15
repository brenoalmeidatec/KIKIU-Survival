"""MORTE: 8 quadros, uma vez só. Leva o golpe (q0), cede os joelhos e cambaleia (q1), tomba (q2, ease-in: o corpo ganha velocidade), BATE no chão
(q3, o quadro de impacto), REBOTA 1 px (q4), assenta (q5) e fica deitado (q6 e q7: dois quadros de repouso, a cabeça rola para o lado).

Enquadramento (célula fixa 32x44; o herói em pé tem 44 px): deitado ele tem ~40 px de comprimento. Deitado na horizontal estoura os 32 px, então
nas 8 direções ele cai quase ao longo da profundidade da câmera, a ~22 graus dela (`ALVOS`): cabe em ~28 px de largura e ocupa ~30 px de altura.
Para LER como deitado (e não como um boneco de pé de braços abertos), a cabeça sempre fica do lado da câmera, com o corpo de cabeça para baixo na
tela. Quem olha de frente (baixo e diagonais de baixo) cai PARA A FRENTE, de bruços (`PRONO`); quem olha de costas ou de lado cai de costas
(`SUPINO`). O herói gira em pé o ângulo que falta (`raiz_z`, aos poucos, junto com o tombo). `ossos.ancorar` encosta o corpo inteiro no chão e centra
a caixa em x a cada quadro (o `pisar` só olha as botas).

Sinais (ver anim_escudo.py): raiz x NEGATIVO = tomba para trás (pivô nos pés), POSITIVO = para a frente; tronco e cabeça: x NEGATIVO = para trás;
braço, antebraço, perna e canela: x NEGATIVO = para a frente. Braço y: o da katana (direito da tela, _d) abre para fora com y NEGATIVO, o esquerdo
com y POSITIVO. A cabeça NUNCA passa de ~0,5 rad relativos ao tronco em x (acima disso a junta do pescoço abre e a cabeça parece duplicada).
"""
import math

import ossos

N_QUADROS = 8
S_POR_QUADRO = [0.10, 0.10, 0.08, 0.05, 0.08, 0.10, 0.25, 0.30]    # tempos sugeridos (q3 = impacto, rápido; q6 e q7 = repouso)

# raiz (tombo), tronco, cabeça (x, e z = rolagem para o lado), braços (x, y), antebraços (x), pernas e canelas (x), rebote (z extra)
SUPINO = [
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

# de bruços: o tombo é para a frente (raiz POSITIVO); os braços vêm à frente para amparar e depois ficam ao lado; os joelhos dobram para trás
PRONO = [
    SUPINO[0],
    dict(raiz=0.28, tronco=0.25, cabeca=0.15,
         braco_e=(-0.50, 0.0), antebraco_e=-0.60, braco_d=(-0.20, 0.0), antebraco_d=-0.10,
         perna_e=-0.40, canela_e=0.80, perna_d=0.15, canela_d=0.55),
    dict(raiz=0.85, tronco=0.12, cabeca=0.10,
         braco_e=(-0.80, 0.10), antebraco_e=-0.30, braco_d=(-0.30, -0.05), antebraco_d=-0.10,
         perna_e=-0.20, canela_e=0.60, perna_d=0.05, canela_d=0.45),
    dict(raiz=1.42, tronco=0.06, cabeca=0.0, cabeca_z=0.70,
         braco_e=(-0.30, 0.45), antebraco_e=-0.10, braco_d=(-0.10, -0.08), antebraco_d=0.30,
         perna_e=0.05, canela_e=0.90, perna_d=0.10, canela_d=0.55),
    dict(raiz=1.30, tronco=0.20, cabeca=-0.05, cabeca_z=0.70, extra_z=0.12,
         braco_e=(-0.20, 0.45), antebraco_e=-0.15, braco_d=(-0.10, -0.08), antebraco_d=0.30,
         perna_e=0.0, canela_e=1.00, perna_d=0.05, canela_d=0.65),
    dict(raiz=1.50, tronco=0.02, cabeca=0.0, cabeca_z=0.85,
         braco_e=(-0.05, 0.40), antebraco_e=-0.15, braco_d=(-0.05, -0.20), antebraco_d=0.0,
         perna_e=0.10, canela_e=0.85, perna_d=0.15, canela_d=0.50),
    dict(raiz=1.52, tronco=0.0, cabeca=0.0, cabeca_z=0.95,
         braco_e=(0.0, 0.35), antebraco_e=-0.10, braco_d=(0.0, -0.15), antebraco_d=0.10,
         perna_e=0.12, canela_e=0.80, perna_d=0.18, canela_d=0.45),
    dict(raiz=1.52, tronco=0.0, cabeca=0.0, cabeca_z=1.05,
         braco_e=(0.05, 0.30), antebraco_e=-0.05, braco_d=(0.05, -0.10), antebraco_d=0.15,
         perna_e=0.05, canela_e=0.15, perna_d=0.14, canela_d=0.10),
]

ALVOS = (18.0, -18.0, 162.0, -162.0)     # alvo do para-onde-a-cabeça-aponta no mundo (graus; 0 = para longe da câmera, 180 = para a câmera)


def _norm(a):
    return (a + 180.0) % 360.0 - 180.0


def _melhor(alvo_base, ang):
    """Menor giro (graus) que leva a direção `ang` a um dos alvos próximos de 180 (a cabeça na direção da câmera)."""
    melhor = None
    for alvo in ALVOS[2:]:
        d = _norm(alvo - ang)
        if melhor is None or abs(d) < abs(melhor) - 1e-6:
            melhor = d
    return melhor


def escolher(ang):
    """(quadros, giro em radianos): de bruços (cai para a frente) ou de costas, o que pedir o MENOR giro em pé. `ang` = giro do herói
    (o 'para trás' dele aponta para o mundo em `ang` graus; o 'para a frente', em `ang`+180)."""
    d_costas = _melhor(0, ang)                    # cabeça para a câmera caindo de costas
    d_bruços = _melhor(0, ang + 180.0)            # idem caindo para a frente
    if abs(d_bruços) < abs(d_costas) - 1e-6:
        return PRONO, math.radians(d_bruços)
    return SUPINO, math.radians(d_costas)


def posar(arm, quadro, n_quadros, ang=0.0):
    quadros, giro = escolher(ang)
    p = quadros[quadro]
    # o giro entra aos poucos (junto com o tombo), para o q0 ainda ser o herói em pé
    fase = min(1.0, abs(p["raiz"]) / 0.85)
    ossos.girar(arm, "raiz", x=p["raiz"], z=giro * fase)
    ossos.girar(arm, "torso", x=p["tronco"])
    ossos.girar(arm, "cabeca", x=p["cabeca"], z=p.get("cabeca_z", 0.0))
    for lado in ("e", "d"):
        bx, by = p["braco_" + lado]
        # os braços do modelo em repouso já abrem ~0,4 rad para fora; deitado, isso é largura de graça (32 px é pouco): fecha aos poucos
        by += (-0.40 if lado == "e" else 0.40) * fase
        ossos.girar(arm, "braco_" + lado, x=bx, y=by)
        ossos.girar(arm, "antebraco_" + lado, x=p["antebraco_" + lado])
        perna, canela = p["perna_" + lado], p["canela_" + lado]
        ossos.girar(arm, "perna_" + lado, x=perna)
        ossos.girar(arm, "canela_" + lado, x=canela)
        # de pé a bota fica plana no mundo; tombado ela acompanha a canela (sola para cima)
        plana = -(perna + canela + p["raiz"])
        ossos.girar(arm, "pe_" + lado, x=plana * max(0.0, 1.0 - fase * 1.3))
    ossos.ancorar(arm, extra_z=p.get("extra_z", 0.0))

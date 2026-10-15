"""ROLAMENTO / ESQUIVA: 6 quadros, uma vez só (não é ciclo). Um ROLAMENTO de verdade para a frente: agacha (q0), mergulha encolhido (q1), o corpo gira
mais de uma volta em torno do próprio centro com a cabeça passando pelos pés (q2 e q3, de cabeça para baixo no q3), abre a volta (q4) e sai em pé,
agachado de amortecimento (q5). Quadros curtos (0,07 s); o pico de compressão (a bola mais fechada) está nos quadros 2 e 3.

Como gira: `raiz` (pivô nos pés) recebe o ângulo do tombo para a frente (x POSITIVO = o topo vai para a frente, ver anim_escudo.py); como o pivô não é o
centro do corpo, `ossos.ancorar` reposiciona o corpo INTEIRO a cada quadro (encosta no chão, mesma linha de baixo, centra em x): o herói rola "no
lugar" e o jogo move a posição. Encolhido (coxas e canelas dobradas, tronco e cabeça curvados) o comprimento cai de 44 para ~25 px, e por isso cabe
nos 32 px de largura mesmo de perfil, que é a vista em que o corpo fica na horizontal. Sem inclinação para a frente o rolamento parece só um agachamento;
por isso o q1 já mergulha com o tronco bem à frente.

Poeira (`efeito`): quadradinhos claros no chão, ATRÁS do herói (o rolamento vai para a frente), nos quadros 1 a 5; o gerar.py pinta só onde o corpo não está.
"""
import math

import ossos

N_QUADROS = 6
S_POR_QUADRO = [0.07, 0.07, 0.06, 0.06, 0.07, 0.09]

# giro da raiz (rad), tronco, cabeça, coxas, canelas (rad; as duas pernas iguais), braço e antebraço esquerdo (o da katana tem os seus), subida (extra_z)
QUADROS = [
    dict(giro=0.00, tronco=0.35, cabeca=0.10, coxa=-0.70, canela=1.30, braco=-0.40, ante=-0.80, braco_d=-0.20, ante_d=0.0, sobe=0.0, pe=0.8),
    dict(giro=0.60, tronco=1.60, cabeca=0.60, coxa=-1.90, canela=2.40, braco=-1.00, ante=-1.30, braco_d=0.0, ante_d=-2.0, sobe=0.0, pe=0.0),
    dict(giro=2.00, tronco=1.45, cabeca=0.80, coxa=-2.30, canela=2.75, braco=-1.30, ante=-1.60, braco_d=-0.50, ante_d=-2.50, sobe=0.08, pe=0.0),
    dict(giro=4.20, tronco=1.45, cabeca=0.80, coxa=-2.30, canela=2.75, braco=-1.30, ante=-1.60, braco_d=-0.40, ante_d=-1.80, sobe=0.10, pe=0.0),
    dict(giro=5.1, tronco=1.20, cabeca=0.60, coxa=-1.95, canela=2.50, braco=-1.00, ante=-1.20, braco_d=-0.50, ante_d=-2.20, sobe=0.04, pe=0.0),
    dict(giro=2 * math.pi, tronco=0.30, cabeca=0.0, coxa=-0.60, canela=1.05, braco=-0.40, ante=-0.50, braco_d=0.0, ante_d=-0.20, sobe=0.0, pe=0.8),
]


def posar(arm, quadro, n_quadros):
    p = QUADROS[quadro]
    ossos.girar(arm, "raiz", x=p["giro"])
    ossos.girar(arm, "torso", x=p["tronco"])
    ossos.girar(arm, "cabeca", x=p["cabeca"])
    for lado in ("e", "d"):
        ossos.girar(arm, "perna_" + lado, x=p["coxa"])
        ossos.girar(arm, "canela_" + lado, x=p["canela"])
        # em pé/agachado a bota acompanha o chão (anula a coxa e a canela); na bola, ela fica solta
        ossos.girar(arm, "pe_" + lado, x=-(p["coxa"] + p["canela"]) * p["pe"])
    ossos.girar(arm, "braco_e", x=p["braco"])
    ossos.girar(arm, "antebraco_e", x=p["ante"])
    ossos.girar(arm, "braco_d", x=p["braco_d"])
    ossos.girar(arm, "antebraco_d", x=p["ante_d"])
    ossos.ancorar(arm, extra_z=p["sobe"])


# poeira: (quadro) -> lista de (distância atrás, lado, tamanho) em unidades do mundo (1 px = 0,041)
POEIRA = {
    1: [(0.45, -0.10, 0.10), (0.75, 0.12, 0.07)],
    2: [(0.50, 0.00, 0.11), (0.85, -0.14, 0.08), (1.05, 0.10, 0.06)],
    3: [(0.55, 0.12, 0.11), (0.90, -0.10, 0.08), (1.10, 0.02, 0.06)],
    4: [(0.50, -0.12, 0.10), (0.80, 0.10, 0.07)],
    5: [(0.45, 0.05, 0.09)],
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

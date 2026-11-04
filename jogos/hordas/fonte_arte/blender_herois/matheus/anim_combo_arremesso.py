"""COMBO DO MATHEUS: 3 ARREMESSOS de shuriken x 6 quadros = 18 quadros (no lugar do combo de katana do Hazaki, só para este perfil).

A mão ESQUERDA da tela segura a shuriken e é ela que arremessa; a katana (direita) fica parada na guarda, pendendo. Cada arremesso:
antecipação (a0: meio caminho até o recuo), recuo (a1: o braço da shuriken vai para trás e para cima, o tronco gira para trás),
soltura (g: o braço varre para a frente), ponto de soltura (i1: braço estendido à frente), segura (i2) e volta (v).

  arremesso 1 (q0-q5)   por cima: a shuriken sai da altura da cabeça, de trás para a frente.
  arremesso 2 (q6-q11)  lateral: a shuriken sai da altura do ombro, cruzando o corpo para a direita da tela.
  arremesso 3 (q12-q17) por baixo: a shuriken sai do quadril, em arco para a frente e para cima.

Contrato igual ao do anim_combo.py: N_QUADROS e posar(arm, quadro, n_quadros), com ossos.py. Os valores de cada pose são eixos do herói (x, y, z) em radianos.
"""
import bpy
from mathutils import Vector

import ossos

N_QUADROS = 18
# direção do voo de cada arremesso (x direita da tela, y para trás, z para cima), no espaço do herói
DIRECAO = {0: (0.0, -1.0, 0.5), 1: (0.7, -0.7, 0.1), 2: (0.0, -1.0, 0.3)}
S_POR_QUADRO = [0.07, 0.07, 0.04, 0.05, 0.08, 0.07] * 3

# repouso: katana pendendo na direita, braço da shuriken na frente do quadril (como no combo do Hazaki)
REPOUSO = dict(bd=(0.0, 0.0, 0.0), ad=(0.0, 0.0, 0.0), be=(0.0, -0.10, 0.0), ae=(-0.35, 0.0, 0.0), to=(0.0, 0.0, 0.0), qu=(0.0, 0.0, 0.0),
               pe=(0.0, 0.0), pd=(0.0, 0.0))


def _pose(**kw):
    p = dict(REPOUSO)
    p.update(kw)
    return p


ARREMESSOS = [
    dict(  # 1: por cima
        W=_pose(be=(-1.30, -0.10, 0.10), ae=(-1.70, 0.0, 0.0), to=(-0.20, 0.0, 0.30), qu=(0.0, 0.0, -0.10), pe=(0.10, 0.20), pd=(-0.05, 0.15)),
        S=_pose(be=(0.40, -0.20, 0.0), ae=(-0.10, 0.0, 0.0), to=(0.15, 0.0, -0.15), qu=(0.0, 0.0, 0.06), pe=(-0.10, 0.25), pd=(0.05, 0.15)),
        I=_pose(be=(0.95, -0.25, 0.0), ae=(-0.05, 0.0, 0.0), to=(0.25, 0.0, -0.25), qu=(0.0, 0.0, 0.10), pe=(-0.25, 0.30), pd=(0.10, 0.20)),
    ),
    dict(  # 2: lateral, cruzando o corpo
        W=_pose(be=(0.10, -0.90, 0.45), ae=(-0.90, 0.0, 0.0), to=(0.0, 0.0, 0.40), qu=(0.0, 0.0, 0.10), pe=(0.10, 0.20), pd=(-0.05, 0.15)),
        S=_pose(be=(0.25, -0.80, -0.35), ae=(-0.30, 0.0, 0.0), to=(0.0, 0.0, -0.25), qu=(0.0, 0.0, -0.06), pe=(-0.10, 0.25), pd=(0.05, 0.15)),
        I=_pose(be=(0.35, -0.60, -0.75), ae=(-0.10, 0.0, 0.0), to=(0.10, 0.0, -0.40), qu=(0.0, 0.0, -0.10), pe=(-0.20, 0.30), pd=(0.10, 0.20)),
    ),
    dict(  # 3: por baixo, em arco para a frente
        W=_pose(be=(0.60, -0.20, 0.0), ae=(-0.80, 0.0, 0.0), to=(0.20, 0.0, 0.10), qu=(0.0, 0.0, 0.05), pe=(0.10, 0.20), pd=(-0.05, 0.15)),
        S=_pose(be=(-0.20, -0.20, 0.0), ae=(-0.20, 0.0, 0.0), to=(-0.10, 0.0, -0.10), qu=(0.0, 0.0, -0.04), pe=(-0.15, 0.25), pd=(0.05, 0.15)),
        I=_pose(be=(-0.70, -0.30, 0.0), ae=(-0.05, 0.0, 0.0), to=(-0.20, 0.0, -0.20), qu=(0.0, 0.0, -0.08), pe=(-0.30, 0.35), pd=(0.10, 0.20)),
    ),
]


def mix(a, b, t):
    return {k: tuple(x + (y - x) * t for x, y in zip(a[k], b[k])) for k in a}


def pose_do_quadro(quadro):
    g, i = divmod(quadro, 6)
    k = ARREMESSOS[g]
    return {0: lambda: mix(REPOUSO, k["W"], 0.5), 1: lambda: k["W"], 2: lambda: k["S"], 3: lambda: k["I"],
            4: lambda: mix(k["I"], REPOUSO, 0.10), 5: lambda: mix(k["I"], REPOUSO, 0.55)}[i]()


def aplicar(arm, p):
    for osso, chave in (("braco_d", "bd"), ("antebraco_d", "ad"), ("braco_e", "be"), ("antebraco_e", "ae"), ("torso", "to"), ("quadril", "qu")):
        ossos.girar(arm, osso, x=p[chave][0], y=p[chave][1], z=p[chave][2])
    ossos.girar(arm, "cabeca", z=-0.5 * p["to"][2])
    for lado, chave in (("e", "pe"), ("d", "pd")):
        coxa, canela = p[chave]
        ossos.girar(arm, "perna_" + lado, x=coxa)
        ossos.girar(arm, "canela_" + lado, x=canela)
        ossos.girar(arm, "pe_" + lado, x=-(coxa + canela))


def posar(arm, quadro, n_quadros):
    aplicar(arm, pose_do_quadro(quadro))
    ossos.pisar(arm)
    ossos.encaixar_x(arm)


def efeito(arm, quadro, n_quadros, ang):
    """A SHURIKEN VOANDO: a partir da soltura (i=2) ela sai da mão na direção do arremesso (i=3 meio caminho, i=4 longe) e some no quadro 5.
    Desenhada como losango de aço claro, pintada só onde o corpo não está (gerar.py, pintar_poligonos)."""
    g, i = divmod(quadro, 6)
    if i not in (2, 3, 4):
        return []
    centro = bpy.data.objects["Shuriken miolo"].matrix_world.translation
    d = arm.matrix_world.to_3x3() @ Vector(DIRECAO[g]).normalized()
    c = centro + d * {2: 0.0, 3: 0.5, 4: 0.9}[i]
    r = 0.22
    pontos = [c + Vector((r, 0, 0)), c + Vector((0, 0, r)), c + Vector((-r, 0, 0)), c + Vector((0, 0, -r))]
    return [(pontos, (196, 208, 220))]

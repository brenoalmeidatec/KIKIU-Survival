"""COMBO DA KATANA: 3 golpes DIFERENTES x 6 quadros = 18 quadros. Cada golpe: antecipação (a0 e a1: o corpo se desloca para TRÁS e se enrola, a lâmina vai para trás),
golpe (g: a lâmina varre, com RASTRO), impacto (i1: pose esticada, rastro forte), HOLD (i2: segura o impacto, um quadro a mais) e volta (v).

  golpe 1 (q0-q5)   HORIZONTAL: da direita para a esquerda, na altura do peito (o tronco gira para o lado do golpe).
  golpe 2 (q6-q11)  DIAGONAL descendente: da altura do ombro direito para o quadril esquerdo, o tronco se curva à frente (corte de cima para baixo).
  golpe 3 (q12-q17) ESTOCADA: a katana recua até o quadril e dispara para a frente, com passo largo da perna esquerda (o golpe mais longo).

Lâmina: mais larga, mais longa e mais clara que o contorno (gerar.py). RASTRO (`efeito`): faixa clara que acompanha a lâmina entre duas poses (cinco amostras), mais
escura no começo e mais clara na ponta, pintada ATRÁS do corpo; nos quadros g (varredura) e i1 (impacto). Visível também de costas, onde o braço da katana some atrás do corpo.

Os ângulos do braço da katana (ombro e cotovelo, 3 eixos cada) foram resolvidos por `ik_katana.py` a partir de onde a GUARDA e a direção da LÂMINA devem ficar, no espaço do
herói (unidades do modelo, x direita da tela, y para trás, z para cima); as posições-alvo estão ao lado de cada pose. O corpo (tronco, quadril, pernas) foi desenhado à mão.
Limites: a ponta fica a ~1,15 unidades do eixo (o quadro tem ~1,2 de meia-largura); o que passar disso, `ossos.encaixar_x` desliza o corpo para dentro do quadro. Em cima,
a lâmina nunca passa da cabeça (o alvo mais alto é z = 3,1, a cabeça vai a 3,3).
"""
import math

import numpy as np
from mathutils import Vector

import ossos

N_QUADROS = 18
S_POR_QUADRO = [0.07, 0.07, 0.04, 0.05, 0.08, 0.07] * 3        # g é rápido, o impacto e o hold seguram

# pose = dicionário de tuplas: bd/ad = braço/antebraço da katana (x, y, z); be/ae = braço/antebraço esquerdo (x, y, z); to = tronco; qu = quadril;
# pe/pd = (coxa, canela) esquerda e direita (x). REPOUSO = a guarda discreta do combo (braço esquerdo para dentro).
REPOUSO = dict(bd=(0.0, 0.0, 0.0), ad=(0.0, 0.0, 0.0), be=(0.0, -0.10, 0.0), ae=(-0.35, 0.0, 0.0), to=(0.0, 0.0, 0.0), qu=(0.0, 0.0, 0.0),
               pe=(0.0, 0.0), pd=(0.0, 0.0))

GOLPES = [
    dict(  # 1: horizontal
        W=dict(bd=(-1.103, -0.133, -0.386), ad=(-3.281, -0.455, -0.237), be=(0.2, -0.10, 0.0), ae=(-0.35, 0.0, 0.0),
               to=(-0.10, 0.0, 0.40), qu=(0.0, 0.0, 0.15), pe=(0.10, 0.20), pd=(-0.05, 0.15)),          # guarda (0.70, 0.10, 1.95), lâmina (0.15, 0.95, 0.15)
        S=dict(bd=(-0.046, 0.253, 0.102), ad=(-1.383, -0.269, -0.685), be=(0.1, -0.10, 0.0), ae=(-0.35, 0.0, 0.0),
               to=(0.0, 0.0, 0.05), qu=(0.0, 0.0, 0.02), pe=(-0.10, 0.20), pd=(0.0, 0.15)),             # guarda (0.30, -0.55, 2.0), lâmina (-0.35, -0.9, 0.1)
        I=dict(bd=(-0.343, 0.449, -0.689), ad=(-1.168, 0.591, -0.335), be=(0.5, -0.20, 0.0), ae=(-0.45, 0.0, 0.0),
               to=(0.15, 0.0, -0.45), qu=(0.0, 0.0, -0.18), pe=(-0.28, 0.30), pd=(0.10, 0.20)),         # guarda (-0.10, -0.60, 1.95), lâmina (-0.8, -0.5, 0.1)
    ),
    dict(  # 2: diagonal descendente
        W=dict(bd=(-0.145, 1.091, 1.089), ad=(-2.340, -0.472, -0.555), be=(0.3, -0.10, 0.0), ae=(-0.35, 0.0, 0.0),
               to=(-0.25, 0.0, 0.25), qu=(0.0, 0.0, 0.10), pe=(0.10, 0.25), pd=(-0.05, 0.20)),          # guarda (0.55, 0.10, 2.35), lâmina (0.4, 0.2, 0.6)
        S=dict(bd=(0.139, 0.599, 0.379), ad=(-1.611, -0.351, -0.891), be=(0.2, -0.10, 0.0), ae=(-0.35, 0.0, 0.0),
               to=(0.12, 0.0, 0.0), qu=(0.0, 0.0, 0.0), pe=(-0.15, 0.25), pd=(0.0, 0.20)),              # guarda (0.30, -0.45, 2.2), lâmina (-0.2, -0.8, 0.4)
        I=dict(bd=(-0.333, 0.422, -0.970), ad=(-0.668, -0.424, 0.024), be=(0.6, -0.15, 0.0), ae=(-0.30, 0.0, 0.0),
               to=(0.42, 0.0, -0.30), qu=(0.0, 0.0, -0.12), pe=(-0.40, 0.50), pd=(0.15, 0.30)),         # guarda (-0.10, -0.65, 1.6), lâmina (-0.5, -0.7, -0.5)
    ),
    dict(  # 3: estocada
        W=dict(bd=(-0.289, 1.489, -1.901), ad=(-2.789, -0.367, -1.148), be=(0.4, -0.10, 0.0), ae=(-0.35, 0.0, 0.0),
               to=(-0.12, 0.0, 0.50), qu=(0.0, 0.0, 0.20), pe=(-0.10, 0.30), pd=(0.10, 0.20)),          # guarda (0.55, 0.05, 1.75), lâmina (0, -0.9, 0.4)
        S=dict(bd=(-0.178, 1.098, -1.976), ad=(-3.018, -0.318, -1.312), be=(0.5, -0.10, 0.0), ae=(-0.40, 0.0, 0.0),
               to=(0.12, 0.0, 0.10), qu=(0.0, 0.0, 0.04), pe=(-0.35, 0.40), pd=(0.20, 0.15)),           # guarda (0.40, -0.35, 1.85), lâmina (-0.05, -0.85, 0.5)
        I=dict(bd=(-0.000, 0.713, -1.914), ad=(-3.305, -0.309, -1.318), be=(0.8, -0.10, 0.0), ae=(-0.50, 0.0, 0.0),
               to=(0.28, 0.0, -0.30), qu=(0.0, 0.0, -0.12), pe=(-0.65, 0.50), pd=(0.40, 0.05)),         # guarda (0.35, -0.55, 1.9), lâmina (-0.1, -0.8, 0.6)
    ),
]


def mix(a, b, t):
    """Interpolação linear entre duas poses (dicionários de tuplas)."""
    return {k: tuple(x + (y - x) * t for x, y in zip(a[k], b[k])) for k in a}


def _a0(k):
    """Primeiro quadro da antecipação: o CORPO já se enrola (60% do tronco, quadril e pernas da antecipação funda), mas o braço da katana ainda está em repouso
    (interpolar os 3 eixos do braço dá poses estranhas no meio do caminho); no quadro seguinte a lâmina chega atrás."""
    m = mix(REPOUSO, k["W"], 0.60)
    m["bd"], m["ad"] = REPOUSO["bd"], REPOUSO["ad"]
    return m


def pose_do_quadro(quadro):
    """(golpe, índice dentro do golpe) -> pose do quadro: a0 = metade do caminho do repouso à antecipação, a1 = antecipação funda, g = varredura, i1 = impacto, i2 = hold
    (um fio de recuo), v = volta (metade do caminho de volta ao repouso)."""
    g, i = divmod(quadro, 6)
    k = GOLPES[g]
    return {0: lambda: _a0(k), 1: lambda: k["W"], 2: lambda: k["S"], 3: lambda: k["I"],
            4: lambda: mix(k["I"], REPOUSO, 0.10), 5: lambda: mix(k["I"], REPOUSO, 0.55)}[i]()


def aplicar(arm, p):
    for osso, chave in (("braco_d", "bd"), ("antebraco_d", "ad"), ("braco_e", "be"), ("antebraco_e", "ae"), ("torso", "to"), ("quadril", "qu")):
        ossos.girar(arm, osso, x=p[chave][0], y=p[chave][1], z=p[chave][2])
    ossos.girar(arm, "cabeca", z=-0.5 * p["to"][2])          # a cabeça desfaz metade do giro do tronco (olha para a frente)
    for lado, chave in (("e", "pe"), ("d", "pd")):
        coxa, canela = p[chave]
        ossos.girar(arm, "perna_" + lado, x=coxa)
        ossos.girar(arm, "canela_" + lado, x=canela)
        ossos.girar(arm, "pe_" + lado, x=-(coxa + canela))   # a bota fica plana, como no repouso


def posar(arm, quadro, n_quadros):
    aplicar(arm, pose_do_quadro(quadro))
    ossos.pisar(arm)
    ossos.encaixar_x(arm)


# ---------------------------------------------------------------- rastro da lâmina
# quadro -> (pose de partida, pose de chegada) do rastro (pose = função do quadro, não dicionário, para poder misturar)
def _rastro(quadro):
    g, i = divmod(quadro, 6)
    k = GOLPES[g]
    if i == 2:
        return mix(k["W"], k["S"], 0.45), k["S"]
    if i == 3:
        return k["S"], k["I"]
    return None


COR_ANTIGA = (140, 160, 186)
COR_NOVA = (222, 234, 246)


def efeito(arm, quadro, n_quadros, ang):
    par = _rastro(quadro)
    if par is None:
        return []
    a, b = par
    amostras = []
    for t in np.linspace(0.0, 1.0, 6):
        aplicar(arm, mix(a, b, float(t)))          # só os ossos de pose: a altura (pisar) e o deslocamento (encaixar_x) do quadro final ficam
        guarda, ponta = ossos.guarda_ponta(arm)
        amostras.append((guarda + (ponta - guarda) * 0.45, ponta))
    aplicar(arm, pose_do_quadro(quadro))           # devolve o herói à pose do quadro
    saida = []
    for j in range(len(amostras) - 1):
        (i0, p0), (i1, p1) = amostras[j], amostras[j + 1]
        cor = COR_ANTIGA if j < 2 else COR_NOVA
        saida.append(([i0, p0, p1, i1], cor))
    return saida

"""COMBO DE ARREMESSO: 3 arremessos x 4 quadros = 12 quadros (o golpe "adagas" do Lucas, 3 passos em cfg.golpe.passos). Cada arremesso:
  q0 PUXA     o corpo gira para trás e o braço de arremesso se arma ao lado da cabeça (a adaga na mão);
  q1 LANÇA    o braço dispara para a frente, a adaga SAI da mão (some do quadro e deixa um risco de luz na direção da lâmina);
  q2 ESTENDE  braço estendido, o corpo à frente, o risco no ar (o quadro mais forte: o impacto);
  q3 VOLTA    o braço recolhe e a próxima adaga já está na mão.

  arremesso 1 (q0-q3)   mão DIREITA da tela, de cima, com passo da perna esquerda;
  arremesso 2 (q4-q7)   mão ESQUERDA (o espelho do 1), para o combo alternar de lado;
  arremesso 3 (q8-q11)  LEQUE: as duas mãos cruzam o peito e abrem para fora, soltando uma adaga de cada lado (e a do meio) em leque; três riscos.

Ângulos (rad, eixos do herói, ver ossos.py): braço/antebraço (x, y, z); tronco (x, y, z); quadril z; pernas (coxa, canela) de cada lado. `espelhar` troca os lados
(esquerda <-> direita, y e z com o sinal trocado). O risco de cada adaga (`efeito`) sai da ponta da lâmina na direção em que ela aponta.
"""
import math

import numpy as np
from mathutils import Vector

import ossos

N_QUADROS = 12
S_POR_QUADRO = [0.07, 0.04, 0.06, 0.07] * 3        # lança é rápido, o estendido segura um pouco

# pose = dict(d=braço direito (x,y,z), ad=antebraço direito, e=braço esquerdo, ae=antebraço esquerdo, to=tronco (x,y,z), qu=quadril z,
#             pe=(coxa, canela) esquerda, pd=(coxa, canela) direita, vis=(adaga na mão direita, adaga na mão esquerda))
ARREMESSO_D = [
    dict(d=(0.50, -0.55, 0.0), ad=(-2.10, 0.0, 0.0), e=(-0.80, 0.15, 0.0), ae=(-0.35, 0.0, 0.0), to=(0.0, 0.0, 0.45), qu=0.18,
         pe=(-0.20, 0.25), pd=(0.15, 0.35), vis=(True, False)),
    dict(d=(-1.30, -0.20, 0.10), ad=(-0.15, 0.0, 0.0), e=(0.45, 0.25, 0.0), ae=(-0.55, 0.0, 0.0), to=(0.12, 0.0, -0.32), qu=-0.12,
         pe=(-0.55, 0.45), pd=(0.35, 0.20), vis=(False, False)),
    dict(d=(-1.55, -0.10, 0.12), ad=(-0.05, 0.0, 0.0), e=(0.70, 0.30, 0.0), ae=(-0.45, 0.0, 0.0), to=(0.28, 0.0, -0.45), qu=-0.18,
         pe=(-0.70, 0.55), pd=(0.42, 0.10), vis=(False, False)),
    dict(d=(-0.55, -0.20, 0.0), ad=(-1.10, 0.0, 0.0), e=(0.20, 0.12, 0.0), ae=(-0.55, 0.0, 0.0), to=(0.06, 0.0, -0.08), qu=-0.03,
         pe=(-0.25, 0.28), pd=(0.12, 0.22), vis=(True, True)),
]

LEQUE = [
    # as duas mãos cruzam o peito (cada mão perto do ombro oposto), o corpo agachado
    dict(d=(-0.95, 0.0, -0.40), ad=(-1.70, 0.0, 0.0), e=(-0.95, 0.0, 0.40), ae=(-1.70, 0.0, 0.0), to=(0.18, 0.0, 0.0), qu=0.0,
         pe=(-0.35, 0.60), pd=(-0.15, 0.60), vis=(True, True)),
    # abre: os braços disparam para fora e para a frente, em V
    dict(d=(-1.35, -0.08, 0.12), ad=(-0.10, 0.0, 0.0), e=(-1.35, 0.08, -0.12), ae=(-0.10, 0.0, 0.0), to=(0.10, 0.0, 0.0), qu=0.0,
         pe=(-0.55, 0.50), pd=(0.30, 0.20), vis=(False, False)),
    dict(d=(-1.60, -0.08, 0.12), ad=(-0.05, 0.0, 0.0), e=(-1.60, 0.08, -0.12), ae=(-0.05, 0.0, 0.0), to=(0.26, 0.0, 0.0), qu=0.0,
         pe=(-0.70, 0.55), pd=(0.40, 0.10), vis=(False, False)),
    # segue o arremesso: os dois braços ficam estendidos à frente (seguimento do gesto), sem adaga na mão (elas voam); o risco continua no ar
    dict(d=(-1.40, -0.06, 0.10), ad=(-0.12, 0.0, 0.0), e=(-1.40, 0.06, -0.10), ae=(-0.12, 0.0, 0.0), to=(0.20, 0.0, 0.0), qu=0.0,
         pe=(-0.55, 0.45), pd=(0.28, 0.18), vis=(False, False)),
]


def espelhar(p):
    """O mesmo arremesso com a outra mão: troca os lados, y e z mudam de sinal; as pernas trocam."""
    def f(v):
        return (v[0], -v[1], -v[2])
    return dict(d=f(p["e"]), ad=f(p["ae"]), e=f(p["d"]), ae=f(p["ad"]), to=f(p["to"]), qu=-p["qu"], pe=p["pd"], pd=p["pe"], vis=(p["vis"][1], p["vis"][0]))


def pose_do_quadro(quadro):
    g, i = divmod(quadro, 4)
    if g == 0:
        return ARREMESSO_D[i]
    if g == 1:
        p = espelhar(ARREMESSO_D[i])
        p["vis"] = ((True, True), (True, False), (True, False), (True, True))[i]      # a mão direita segura a sua adaga o tempo todo
        return p
    return LEQUE[i]


def aplicar(arm, p):
    for osso, chave in (("braco_d", "d"), ("antebraco_d", "ad"), ("braco_e", "e"), ("antebraco_e", "ae"), ("torso", "to")):
        ossos.girar(arm, osso, x=p[chave][0], y=p[chave][1], z=p[chave][2])
    ossos.girar(arm, "quadril", z=p["qu"])
    ossos.girar(arm, "cabeca", z=-0.5 * p["to"][2])          # a cabeça desfaz metade do giro do tronco (olha para o alvo)
    for lado, chave in (("e", "pe"), ("d", "pd")):
        coxa, canela = p[chave]
        ossos.girar(arm, "perna_" + lado, x=coxa)
        ossos.girar(arm, "canela_" + lado, x=canela)
        ossos.girar(arm, "pe_" + lado, x=-(coxa + canela))   # a bota fica plana, como no repouso
    ossos.adaga(arm, *p["vis"])


def posar(arm, quadro, n_quadros):
    aplicar(arm, pose_do_quadro(quadro))
    ossos.pisar(arm)
    ossos.encaixar_x(arm)


# ---------------------------------------------------------------- risco de luz da adaga solta
COR_ANTIGA = (140, 160, 186)
COR_NOVA = (226, 236, 246)


def _na_tela(d):
    """Comprimento aproximado (no plano da tela) de um vetor do mundo: x = direita da tela, vertical = z e y a 45 graus."""
    return math.hypot(d.x, d.z * 0.707 + d.y * 0.707)


def efeito(arm, quadro, n_quadros, ang):
    """Lâminas SEMPRE visíveis (2 a 3 px claros ou mais): a adaga na mão (q0 e q3 de cada arremesso) ganha um brilho no fio, e a adaga arremessada (q1, q2 e a
    pose final do leque) vira um risco de aço comprido saindo da mão. Pintado por cima do corpo (4o valor da cor = True), porque a lâmina vem à frente do
    herói; se a lâmina aponta para a câmera (encurtada na tela), a direção é puxada para fora do corpo para o risco não sumir."""
    g, i = divmod(quadro, 4)
    pose = pose_do_quadro(quadro)
    arremesso = i in (1, 2) or (g == 2 and i == 3)
    if arremesso:
        maos = ["d"] if g == 0 else (["e"] if g == 1 else ["d", "e"])
    else:
        maos = [lado for lado, v in (("d", pose["vis"][0]), ("e", pose["vis"][1])) if v]
    saida = []
    for lado in maos:
        guarda, ponta = ossos.mao_adaga(arm, lado)
        dirv = (ponta - guarda).normalized()
        if arremesso:      # a lâmina solta segue o antebraço (a direção do arremesso), não a lâmina presa na mão
            osso = arm.pose.bones["antebraco_" + lado]
            dirv = (arm.matrix_world @ osso.tail - arm.matrix_world @ osso.head).normalized()
            if abs(math.sin(math.radians(ang))) > 0.9:      # de perfil o braço bate na borda da célula: a lâmina sobe na diagonal, puxada para dentro
                sx = 1.0 if dirv.x >= 0 else -1.0
                dirv = Vector((0.25 * sx, -0.2, 0.9)).normalized()
        sinal = 1.0 if (ponta.x - arm.location.x) >= 0 else -1.0
        fora = Vector((sinal * 0.5, -0.6, 0.3)).normalized()
        if _na_tela(dirv) < 0.75:
            dirv = (dirv * (_na_tela(dirv) / 0.75) + fora * (1.0 - _na_tela(dirv) / 0.75)).normalized()
        if arremesso:
            base = guarda + dirv * 0.05 - (Vector((0.35 * sinal, 0, 0)) if abs(math.sin(math.radians(ang))) > 0.9 else Vector())      # a lâmina no instante da soltura: sai da mão, curta (o resto do voo é o projétil do jogo)
            comp = 0.55 if i == 1 else 0.70 if i == 2 else 0.50
            ramos = [dirv]
            if g == 2 and i >= 2:      # o leque: mais uma adaga para dentro, entre o centro e a mão
                frente = Vector((math.sin(math.radians(ang)), -math.cos(math.radians(ang)), 0.0))
                ramos = [dirv, (dirv * 0.8 + frente * 0.6).normalized()]
        else:
            base, comp, ramos = ponta - dirv * 0.40, 0.40, [dirv]      # brilho no fio da adaga que está na mão
        for d in ramos:
            fim = base + d * comp
            lado_v = Vector((0, 0, 1)).cross(d)
            lado_v = lado_v.normalized() * 0.09 if lado_v.length > 1e-3 else Vector((0.09, 0, 0))
            meio = base + d * comp * 0.55
            saida.append(([base, meio - lado_v, fim, meio + lado_v], COR_ANTIGA + (True,)))
            saida.append(([meio - lado_v * 0.1, fim - d * 0.02, meio + lado_v * 0.1], COR_NOVA + (True,)))
    return saida

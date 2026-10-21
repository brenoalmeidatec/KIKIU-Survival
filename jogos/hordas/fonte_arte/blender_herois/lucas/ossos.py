"""Ajudantes de pose do Hazaki (usados pelos anim_<nome>.py; carregados pelo gerar.py com sys.path).

Convenção dos eixos (do herói em repouso, olhando para a câmera = "baixo"), valem para girar() e mover(), SEMPRE no espaço do herói:
    x = direita da tela (a katana está em +x), y = para TRÁS do herói (a frente é -y), z = para cima.
    girar(x=): inclina para frente/trás (NEGATIVO = para frente: perna/braço vão à frente, tronco se curva à frente)
    girar(y=): inclina de lado (positivo = topo vai para +x)
    girar(z=): gira em pé (positivo = anti-horário visto de cima)
    unidades de mover(): do modelo (1 px do jogo ~ 0,074; o herói tem ~4,2 unidades de altura); ângulos em radianos.
Os ossos (ver OSSOS) têm todos o eixo X local = X do mundo, então a mesma convenção vale em qualquer osso.
"""
import math
import os

import bpy
from mathutils import Euler, Matrix, Vector

OSSOS = ("raiz", "quadril", "torso", "cabeca",
         "braco_e", "antebraco_e", "braco_d", "antebraco_d",
         "perna_e", "canela_e", "pe_e", "perna_d", "canela_d", "pe_d")
# _e = esquerda DA TELA (x < 0), _d = direita da tela (x > 0, onde fica a katana).
# braco = ombro->cotovelo, antebraco = cotovelo->punho (leva a mão e a katana), perna = quadril->joelho, canela = joelho->tornozelo, pe = bota.


def zerar(arm):
    """Volta todos os ossos à pose de repouso (o gerar.py chama antes de cada quadro)."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
    adaga(arm)


def _repouso(arm, nome):
    return arm.data.bones[nome].matrix_local.to_3x3()


def girar(arm, nome, x=0.0, y=0.0, z=0.0):
    """Gira o osso `nome` em torno do seu pivô (a cabeça do osso), com os eixos do herói (ver topo). Substitui a rotação anterior."""
    pb = arm.pose.bones[nome]
    rw = Euler((x, y, z), "XYZ").to_matrix()
    rb = _repouso(arm, nome)
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = (rb.inverted() @ rw @ rb).to_euler("XYZ")


def mover(arm, nome, x=0.0, y=0.0, z=0.0):
    """Desloca o osso (e tudo que está preso a ele) em unidades do modelo, eixos do herói."""
    pb = arm.pose.bones[nome]
    pb.location = _repouso(arm, nome).inverted() @ Vector((x, y, z))


def _min_z_botas(arm):
    """Menor z (no espaço do modelo, sem a escala do herói) dos cantos das botas já posadas."""
    bpy.context.view_layer.update()
    inv = arm.matrix_world.inverted()
    menor = 1e9
    for o in arm.children:
        if o.name.startswith("Bota"):
            for c in o.bound_box:
                menor = min(menor, (inv @ (o.matrix_world @ Vector(c))).z)
    return menor


def pisar(arm, extra=0.0):
    """Ancora o herói no chão: abaixa/sobe a raiz até o ponto mais baixo das botas encostar no chão de repouso (+ `extra` unidades,
    para sobe-e-desce deliberado). Chame DEPOIS de posar pernas e quadril. Não use em saltos e quedas."""
    chao = arm["chao"]
    arm.pose.bones["raiz"].location = (0.0, 0.0, 0.0)
    atual = _min_z_botas(arm)
    arm.pose.bones["raiz"].location = (0.0, 0.0, chao - atual + extra)


# ---------------------------------------------------------------- ancoragem no chão pela caixa do corpo inteiro (quedas, deitados)
import numpy as np  # noqa: E402


def verts_mundo(arm):
    """Todos os vértices (N x 3, mundo) das peças presas ao esqueleto, na pose e no giro atuais."""
    bpy.context.view_layer.update()
    pts = []
    for o in arm.children:
        if o.type != "MESH":
            continue
        if "Adaga na mão" in o.name and not arm.get("adaga_" + o.name[-1]):
            continue        # adaga escondida neste quadro: não conta na caixa do corpo
        n = len(o.data.vertices)
        a = np.empty(n * 3, np.float32)
        o.data.vertices.foreach_get("co", a)
        m = np.array(o.matrix_world)
        pts.append(a.reshape(n, 3) @ m[:3, :3].T + m[:3, 3])
    return np.concatenate(pts)


def calibrar(arm, elev):
    """Chame uma vez, no repouso de frente e sem giro: guarda o chão (z mínimo), a linha mais baixa da tela e a posição do objeto."""
    p = verts_mundo(arm)
    e = math.radians(elev)
    arm["elev"] = elev
    arm["z_chao_mundo"] = float(p[:, 2].min())
    arm["v_chao"] = float((p[:, 2] * math.cos(e) + p[:, 1] * math.sin(e)).min())
    arm["loc0"] = tuple(arm.location)


def ancorar(arm, extra_z=0.0, centrar_x=1.0):
    """Move o herói INTEIRO (o objeto) para o ponto mais baixo do corpo encostar no chão, a borda de baixo do desenho cair na linha do herói
    em pé e a caixa ficar centrada em x. Serve para quedas e deitados (`pisar` só olha as botas). `extra_z` levanta depois (rebote, salto)."""
    p = verts_mundo(arm)
    e = math.radians(arm["elev"])
    dz = arm["z_chao_mundo"] - float(p[:, 2].min())
    vmin = float((p[:, 2] * math.cos(e) + p[:, 1] * math.sin(e)).min()) + dz * math.cos(e)
    dy = (arm["v_chao"] - vmin) / math.sin(e)
    dx = -0.5 * float(p[:, 0].min() + p[:, 0].max()) * float(centrar_x)
    if os.environ.get("LUCAS_LARGURA"):      # depuração: largura real (px) do corpo, sem o corte do quadro
        print("LARGURA_PX %.1f" % ((p[:, 0].max() - p[:, 0].min()) * 24.5))
    arm.location = (arm.location[0] + dx, arm.location[1] + dy, arm.location[2] + dz + extra_z)


def encaixar_x(arm, meia_px=15.0):
    """Desliza o herói (o objeto) em x só o necessário para o corpo, a katana e o lenço caberem na meia-largura do quadro (`meia_px`, em px do jogo).
    Se a caixa for mais larga que o quadro, centra. Para golpes e estocadas, que esticam a katana para fora do corpo."""
    p = verts_mundo(arm)
    lo, hi = float(p[:, 0].min()), float(p[:, 0].max())
    meia = meia_px / 24.5
    if os.environ.get("LUCAS_LARGURA"):
        print("LARGURA_PX %.1f" % ((hi - lo) * 24.5))
    if hi - lo >= 2 * meia:
        dx = -0.5 * (lo + hi)
    else:
        dx = max(0.0, -meia - lo) - max(0.0, hi - meia)
    arm.location = (arm.location[0] + dx, arm.location[1], arm.location[2])


def adaga(arm, d=True, e=False):
    """Mostra (True) ou esconde a adaga da mão direita da tela (`d`) e da esquerda (`e`) neste quadro; o gerar.py lê isso ao renderizar.
    `zerar` volta ao padrão: adaga só na mão direita."""
    arm["adaga_d"], arm["adaga_e"] = bool(d), bool(e)


def mao_adaga(arm, lado="d"):
    """(guarda, ponta) da adaga da mão `lado` ('d' ou 'e') no mundo, como Vectors, na pose atual (existe mesmo escondida)."""
    bpy.context.view_layer.update()
    g = bpy.data.objects["Adaga na mão guarda " + lado]
    pg = sum((g.matrix_world @ v.co for v in g.data.vertices), Vector()) / len(g.data.vertices)
    o = bpy.data.objects["Adaga na mão ponta " + lado]
    pt = max((o.matrix_world @ v.co for v in o.data.vertices), key=lambda q: (q - pg).length)
    return pg, pt

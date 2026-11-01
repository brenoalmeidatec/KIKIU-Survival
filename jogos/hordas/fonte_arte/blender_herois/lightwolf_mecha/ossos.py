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

OSSOS = ("raiz", "quadril", "torso", "cabeca", "marreta",
         "braco_e", "antebraco_e", "braco_d", "antebraco_d",
         "perna_e", "canela_e", "pe_e", "perna_d", "canela_d", "pe_d")
# _e = esquerda DA TELA (x < 0), _d = direita da tela (x > 0).
# braco = ombro->cotovelo, antebraco = cotovelo->punho (leva a mão e a katana), perna = quadril->joelho, canela = joelho->tornozelo, pe = bota.


def zerar(arm):
    """Volta todos os ossos à pose de repouso (o gerar.py chama antes de cada quadro)."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


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


def verts_mundo(arm, sem_marreta=False):
    """Todos os vértices (N x 3, mundo) das peças presas ao esqueleto, na pose e no giro atuais (`sem_marreta`: só o corpo do anão)."""
    bpy.context.view_layer.update()
    pts = []
    for o in arm.children:
        if o.type != "MESH" or (sem_marreta and o.parent_bone == "marreta"):
            continue
        n = len(o.data.vertices)
        a = np.empty(n * 3, np.float32)
        o.data.vertices.foreach_get("co", a)
        m = np.array(o.matrix_world)
        pts.append(a.reshape(n, 3) @ m[:3, :3].T + m[:3, 3])
    return np.concatenate(pts)


def calibrar(arm, elev):
    """Chame uma vez, no repouso de frente e sem giro: guarda o chão (z mínimo), a linha mais baixa da tela e a posição do objeto."""
    p = verts_mundo(arm, True)
    e = math.radians(elev)
    arm["elev"] = elev
    arm["z_chao_mundo"] = float(p[:, 2].min())
    arm["v_chao"] = float((p[:, 2] * math.cos(e) + p[:, 1] * math.sin(e)).min())
    arm["loc0"] = tuple(arm.location)


def ancorar(arm, extra_z=0.0, centrar_x=1.0, sem_marreta=True):
    """Move o herói INTEIRO (o objeto) para o ponto mais baixo do corpo encostar no chão, a borda de baixo do desenho cair na linha do herói
    em pé e a caixa ficar centrada em x. Serve para quedas e deitados (`pisar` só olha as botas). `extra_z` levanta depois (rebote, salto).
    Por padrão só o corpo conta (a marreta, de 3,2, não entra na caixa: ela pode ficar para fora ou no chão ao lado)."""
    p = verts_mundo(arm, sem_marreta)
    e = math.radians(arm["elev"])
    dz = arm["z_chao_mundo"] - float(p[:, 2].min())
    vmin = float((p[:, 2] * math.cos(e) + p[:, 1] * math.sin(e)).min()) + dz * math.cos(e)
    dy = (arm["v_chao"] - vmin) / math.sin(e)
    dx = -0.5 * float(p[:, 0].min() + p[:, 0].max()) * float(centrar_x)
    if os.environ.get("NICAO_LARGURA"):      # depuração: largura real (px) do corpo, sem o corte do quadro
        print("LARGURA_PX %.1f" % ((p[:, 0].max() - p[:, 0].min()) * 24.5))
    arm.location = (arm.location[0] + dx, arm.location[1] + dy, arm.location[2] + dz + extra_z)


def encaixar_x(arm, meia_px=30.0):
    """Desliza o herói (o objeto) em x só o necessário para o corpo, a katana e o lenço caberem na meia-largura do quadro (`meia_px`, em px do jogo).
    Se a caixa for mais larga que o quadro, centra. Para golpes e estocadas, que esticam a katana para fora do corpo."""
    p = verts_mundo(arm)
    lo, hi = float(p[:, 0].min()), float(p[:, 0].max())
    meia = meia_px / 24.5
    if os.environ.get("NICAO_LARGURA"):
        print("LARGURA_PX %.1f" % ((hi - lo) * 24.5))
    if hi - lo >= 2 * meia:
        dx = -0.5 * (lo + hi)
    else:
        dx = max(0.0, -meia - lo) - max(0.0, hi - meia)
    arm.location = (arm.location[0] + dx, arm.location[1], arm.location[2])


# ---------------------------------------------------------------- MARRETA: as duas mãos seguram o cabo (IK analítico de dois ossos)
def _apontar(arm, nome, direcao):
    """Gira o osso `nome` (pelo caminho mais curto) para o eixo dele (cabeça -> cauda) apontar para `direcao` (espaço do armature)."""
    pb = arm.pose.bones[nome]
    bpy.context.view_layer.update()
    m = pb.matrix.copy()
    atual = m.to_3x3() @ Vector((0.0, 1.0, 0.0))
    r = atual.rotation_difference(Vector(direcao).normalized()).to_matrix()
    pb.matrix = Matrix.Translation(m.translation) @ (r @ m.to_3x3()).to_4x4()
    bpy.context.view_layer.update()


def ponto_marreta(arm, d=0.0):
    """Ponto do cabo da marreta a `d` unidades do punho esquerdo em repouso (a mão de baixo; d > 0 sobe pelo cabo), no espaço do armature."""
    bpy.context.view_layer.update()
    pb = arm.pose.bones["marreta"]
    return pb.matrix @ Vector((0.0, d, 0.0))


def alcancar(arm, lado, alvo, polo=None):
    """IK: leva o punho do braço `lado` ("e" ou "d") ao ponto `alvo` (espaço do armature, ver ponto_marreta). Se estiver longe demais, estica
    o braço inteiro apontando para o alvo. `polo` = para onde o cotovelo aponta (padrão: para fora, para baixo e um pouco para trás)."""
    s = 1.0 if lado == "d" else -1.0
    polo = Vector(polo) if polo is not None else Vector((0.7 * s, 0.35, -0.9))
    cima, baixo = arm.pose.bones["braco_" + lado], arm.pose.bones["antebraco_" + lado]
    bpy.context.view_layer.update()
    ombro = cima.head.copy()
    l1, l2 = cima.bone.length, baixo.bone.length
    v = Vector(alvo) - ombro
    dist = min(max(v.length, abs(l1 - l2) + 0.02), (l1 + l2) * 0.998)
    n = v.normalized()
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    perp = polo - n * polo.dot(n)
    perp = perp.normalized() if perp.length > 1e-6 else Vector((0.0, 0.0, -1.0))
    cotovelo = ombro + n * a + perp * h
    _apontar(arm, "braco_" + lado, cotovelo - ombro)
    _apontar(arm, "antebraco_" + lado, Vector(alvo) - baixo.head)
    falta = max(0.0, v.length - (l1 + l2) * 0.998)       # quanto o punho ficou longe do alvo (o braço esticou até o limite)
    arm["falta_" + lado] = falta


def segurar(arm, mao_e=0.0, mao_d=None, polo_e=None, polo_d=None):
    """Chame DEPOIS de posar tronco e marreta. A mão esquerda (da tela) segura o cabo a `mao_e` do ponto de empunhadura normal; a direita, a `mao_d`
    (None = solta: o braço direito fica como o `anim_` o posou, FK)."""
    alcancar(arm, "e", ponto_marreta(arm, mao_e), polo_e)
    if mao_d is not None:
        alcancar(arm, "d", ponto_marreta(arm, mao_d), polo_d)


def dirv(elev, azim):
    """Direção (Vector unitário, espaço do herói em repouso) a partir de ângulos em GRAUS: `elev` 90 = para cima, 0 = horizontal, -90 = para baixo;
    `azim` 0 = para a frente do herói (-y, para a câmera), +90 = para +x (direita da tela), -90 = para -x (esquerda da tela, o lado da marreta), 180 = para trás."""
    e, a = math.radians(elev), math.radians(azim)
    return Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


def empunhar(arm, ponto, direcao, d0=0.0, rolar=0.0):
    """Põe a marreta: o ponto do cabo a `d0` do punho de repouso (onde a mão esquerda segura, ver segurar(mao_e=d0)) vai para `ponto` e o cabo aponta
    para `direcao` (a cabeça da marreta fica no sentido dela). Espaço do armature (o herói em repouso, de frente), independe da pose do tronco.
    `rolar`: gira a marreta em torno do cabo (rad). Chame antes de segurar()."""
    bpy.context.view_layer.update()
    pb = arm.pose.bones["marreta"]
    base = pb.bone.matrix_local.to_3x3()
    d = Vector(direcao).normalized()
    r = (base @ Vector((0.0, 1.0, 0.0))).rotation_difference(d).to_matrix() @ base
    r = Matrix.Rotation(rolar, 3, d) @ r
    pb.matrix = Matrix.Translation(Vector(ponto) - d * d0) @ r.to_4x4()
    bpy.context.view_layer.update()


def cabeca_marreta(arm):
    """Centro da cabeça da marreta no mundo (Vector)."""
    bpy.context.view_layer.update()
    o = bpy.data.objects["Cabeça da marreta"]
    return sum((o.matrix_world @ v.co for v in o.data.vertices), Vector()) / len(o.data.vertices)

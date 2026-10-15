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

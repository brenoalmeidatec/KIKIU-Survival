"""Cavaleiro (dark fantasy) -> folha de andar 9x4 de 44x60 e rosto 52x52, no formato que o jogo já usa.

Roda (Blender 4.5 LTS):
    blender -b -P cavaleiro.py
Saída: ../../projeto/assets/personagens/cavaleiro/andando_8.png e rosto.png
Linhas da folha (igual a jogador.gd): baixo, esquerda, direita, cima. Coluna 0 parado, 1-8 andando.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import pixel3d as px3  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "personagens", "cavaleiro"))
QW, QH = 44, 60              # quadro da folha
PE_Y = 57                    # linha do pé dentro do quadro (o jogo desenha com offset (-22, -58))
DIRECOES = [0.0, -90.0, 90.0, 180.0]   # baixo, esquerda, direita, cima (rotação em Z, de frente = -Y)
PAL = px3.paleta_sem("1f2a24", "35473a", "566e55", "a89e86", "d6ccb2")   # sem musgo e osso


def pendurar(filho, pai):
    """Prende o filho no pai SEM mudar a posição no mundo (senão a posição soma duas vezes)."""
    bpy.context.view_layer.update()
    filho.parent = pai
    filho.matrix_parent_inverse = pai.matrix_world.inverted()


def caixa(nome, tam, pos, mat, pai=None, pivo=None):
    """Caixa de tamanho 'tam'. Se 'pivo' vier, a origem do objeto fica no pivô (pra girar membro no ombro/quadril)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.name = nome
    o.scale = tam
    bpy.ops.object.transform_apply(scale=True)
    if pivo is not None:
        o.data.transform(Matrix.Translation(Vector(pos) - Vector(pivo)))
        o.location = pivo
    else:
        o.location = pos
    o.data.materials.append(mat)
    if pai is not None:
        pendurar(o, pai)
    return o


def esfera(nome, raio, pos, mat, pai, escala=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=raio, segments=12, ring_count=8, location=pos)
    o = bpy.context.active_object
    o.name = nome
    o.scale = escala
    o.data.materials.append(mat)
    pendurar(o, pai)
    return o


def cilindro(nome, raio, altura, pos, mat, pai, rot=(0, 0, 0), vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(radius=raio, depth=altura, vertices=vertices, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.name = nome
    o.data.materials.append(mat)
    pendurar(o, pai)
    return o


def montar():
    m = {
        "aco": px3.material_toon("aco", px3.cor("7a7590")),
        "aco_escuro": px3.material_toon("aco_escuro", px3.cor("4f4a66")),
        "tabardo": px3.material_toon("tabardo", px3.cor("9e2a2f")),
        "capa": px3.material_toon("capa", px3.cor("5e1820")),
        "couro": px3.material_toon("couro", px3.cor("5a3d28")),
        "ouro": px3.material_toon("ouro", px3.cor("b08a40")),
        "fresta": px3.material_toon("fresta", px3.cor("0d0b14"), faixas=(1, 1, 1)),
        "madeira": px3.material_toon("madeira", px3.cor("3b2a1e")),
    }
    bpy.ops.object.empty_add(location=(0, 0, 0))
    raiz = bpy.context.active_object
    raiz.name = "raiz"
    bpy.ops.object.empty_add(location=(0, 0, 0))
    corpo = bpy.context.active_object
    corpo.name = "corpo"
    corpo.parent = raiz

    p = {}
    # pernas (pivô no quadril) com bota
    for lado, x in (("e", 0.13), ("d", -0.13)):
        perna = caixa("perna_" + lado, (0.17, 0.2, 0.62), (x, 0, 0.55), m["aco_escuro"], corpo, pivo=(x, 0, 0.86))
        caixa("bota_" + lado, (0.2, 0.28, 0.22), (x, -0.03, 0.11), m["couro"], perna)
        p["perna_" + lado] = perna
    # tronco, tabardo, cinto
    caixa("tronco", (0.52, 0.4, 0.62), (0, 0, 1.17), m["aco"], corpo)
    caixa("tabardo", (0.38, 0.06, 0.72), (0, -0.21, 1.08), m["tabardo"], corpo)
    caixa("cinto", (0.56, 0.44, 0.08), (0, 0, 0.9), m["couro"], corpo)
    caixa("fivela", (0.1, 0.04, 0.08), (0, -0.23, 0.9), m["ouro"], corpo)
    # capa nas costas (balança um pouco ao andar)
    capa = caixa("capa", (0.5, 0.05, 0.95), (0, 0.24, 0.98), m["capa"], corpo, pivo=(0, 0.22, 1.45))
    p["capa"] = capa
    # ombreiras
    for x in (0.33, -0.33):
        esfera("ombreira", 0.17, (x, 0, 1.42), m["aco"], corpo, escala=(1.1, 1.0, 0.8))
    # braços (pivô no ombro); direito com espada, esquerdo com escudo
    braco_d = caixa("braco_d", (0.14, 0.14, 0.5), (-0.36, 0, 1.12), m["aco_escuro"], corpo, pivo=(-0.36, 0, 1.4))
    caixa("luva_d", (0.16, 0.16, 0.12), (-0.36, 0, 0.84), m["couro"], braco_d)
    cilindro("cabo", 0.035, 0.2, (-0.36, -0.08, 0.8), m["couro"], braco_d, rot=(math.radians(90), 0, 0))
    caixa("guarda", (0.24, 0.05, 0.05), (-0.36, -0.2, 0.8), m["ouro"], braco_d)
    caixa("lamina", (0.06, 0.6, 0.02), (-0.36, -0.52, 0.8), m["aco"], braco_d)
    braco_e = caixa("braco_e", (0.14, 0.14, 0.5), (0.36, 0, 1.12), m["aco_escuro"], corpo, pivo=(0.36, 0, 1.4))
    caixa("luva_e", (0.16, 0.16, 0.12), (0.36, 0, 0.84), m["couro"], braco_e)
    escudo = cilindro("escudo", 0.24, 0.06, (0.47, -0.04, 1.02), m["madeira"], braco_e, rot=(0, math.radians(90), 0), vertices=16)
    cilindro("aro", 0.25, 0.04, (0.48, -0.04, 1.02), m["ouro"], braco_e, rot=(0, math.radians(90), 0), vertices=16)
    esfera("umbo", 0.07, (0.51, -0.04, 1.02), m["aco"], braco_e)
    p["braco_d"] = braco_d
    p["braco_e"] = braco_e
    # elmo grande (cabeça de cavaleiro), fresta do visor e penacho
    cilindro("elmo", 0.25, 0.42, (0, 0, 1.72), m["aco"], corpo, vertices=16)
    esfera("domo", 0.25, (0, 0, 1.93), m["aco"], corpo, escala=(1, 1, 0.55))
    caixa("fresta", (0.34, 0.04, 0.05), (0, -0.245, 1.76), m["fresta"], corpo)
    caixa("nariz", (0.05, 0.04, 0.2), (0, -0.25, 1.66), m["aco_escuro"], corpo)
    caixa("penacho", (0.07, 0.36, 0.2), (0, 0.06, 2.08), m["tabardo"], corpo)
    _ = escudo
    return raiz, corpo, p


def pose(corpo, p, fase, andando):
    s = math.sin(fase) if andando else 0.0
    p["perna_e"].rotation_euler = (0.55 * s, 0, 0)
    p["perna_d"].rotation_euler = (-0.55 * s, 0, 0)
    p["braco_e"].rotation_euler = (-0.35 * s, 0, 0)
    p["braco_d"].rotation_euler = (0.35 * s, 0, 0)
    p["capa"].rotation_euler = (-0.15 - 0.12 * abs(s) if andando else -0.05, 0, 0)
    corpo.location = (0, 0, 0.04 * abs(math.cos(fase)) if andando else 0.0)


def main():
    import numpy as np
    px3.limpar_cena()
    px3.preparar_render(QW, QH)
    cam = px3.camera(elevacao_graus=32.0, escala=2.55)
    px3.luz()
    raiz, corpo, p = montar()
    pose(corpo, p, 0.0, False)
    px3.calibrar_pe(cam, PE_Y, QW, QH)
    folha = np.zeros((QH * 4, QW * 9, 4), dtype=np.float32)
    for linha, ang in enumerate(DIRECOES):
        raiz.rotation_euler = (0, 0, math.radians(ang))
        for col in range(9):
            pose(corpo, p, 2 * math.pi * (col - 1) / 8.0, col > 0)
            q = px3.pixelar(px3.render_rgba(), paleta=PAL)
            folha[linha * QH:(linha + 1) * QH, col * QW:(col + 1) * QW] = q
    px3.salvar_png(folha, os.path.join(SAIDA, "andando_8.png"))
    # rosto 52x52: de frente, câmera fechada no elmo
    raiz.rotation_euler = (0, 0, 0)
    pose(corpo, p, 0.0, False)
    px3.preparar_render(52, 52)
    cam.data.ortho_scale = 1.05
    cam.data.shift_x = 0.0
    cam.data.shift_y = 0.0
    el = math.radians(20.0)
    cam.location = (0.0, -20.0 * math.cos(el), 1.62 + 20.0 * math.sin(el))
    cam.rotation_euler = (math.pi / 2 - el, 0.0, 0.0)
    px3.salvar_png(px3.pixelar(px3.render_rgba(), paleta=PAL), os.path.join(SAIDA, "rosto.png"))
    print("CAVALEIRO OK ->", SAIDA)


main()

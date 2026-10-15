"""Resolve (offline) os ângulos do braço da katana (ombro e cotovelo em 3 eixos cada) a partir de onde a GUARDA e a PONTA da lâmina devem ficar.
Ferramenta de autoria: roda uma vez, imprime os números e eles vão para o anim_<nome>.py (as animações não dependem deste arquivo).

    blender -b hazaki_rig.blend -P ik_katana.py -- gx gy gz  dx dy dz  [braco_x braco_y braco_z ante_x ante_y ante_z (ponto de partida)]

Coordenadas no espaço do herói em repouso, em UNIDADES DO MODELO (herói com ~3,3 de altura; x = direita da tela, y = para TRÁS, a frente é -y, z = para cima).
(gx, gy, gz) = posição da guarda; (dx, dy, dz) = direção da lâmina (não precisa ser unitária). Ombro em (0.40, 0, 2.20): a guarda tem de ficar a < 1.0 dele.
Saída: IK braco=(x, y, z) antebraco=(x, y, z) e o erro. Mínimos quadrados amortecidos (Levenberg-Marquardt) com derivada numérica, só numpy.
O mesmo vale para o braço esquerdo, passando LADO=e na variável de ambiente e usando o ponto da mão (sem lâmina: só gx gy gz).
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ossos  # noqa: E402

arm = bpy.data.objects["Hazaki rig"]
args = [float(a) for a in sys.argv[sys.argv.index("--") + 1:]]
LADO = os.environ.get("LADO", "d")


def centro(nome):
    o = bpy.data.objects[nome]
    return sum((o.matrix_world @ v.co for v in o.data.vertices), Vector()) / len(o.data.vertices)


def local(p):
    return arm.matrix_world.inverted() @ p


def pontos():
    bpy.context.view_layer.update()
    if LADO == "d":
        g = local(centro("Guarda da katana"))
        o = bpy.data.objects["Ponta da katana"]
        ponta = max((local(o.matrix_world @ v.co) for v in o.data.vertices), key=lambda q: (q - g).length)
        return np.array(g), np.array(ponta)
    return np.array(local(centro("Mão esquerda"))), np.zeros(3)


def pose(v):
    ossos.zerar(arm)
    ossos.girar(arm, "braco_" + LADO, x=v[0], y=v[1], z=v[2])
    ossos.girar(arm, "antebraco_" + LADO, x=v[3], y=v[4], z=v[5])


def residuo(v, alvo_g, alvo_d):
    pose(v)
    g, ponta = pontos()
    r = list(g - alvo_g)
    if alvo_d is not None:
        d = ponta - g
        d = d / (np.linalg.norm(d) + 1e-9)
        r += list((d - alvo_d) * float(os.environ.get("WDIR", "0.6")))
    return np.array(r)


alvo_g = np.array(args[0:3])
alvo_d = None
if LADO == "d":
    alvo_d = np.array(args[3:6])
    alvo_d = alvo_d / np.linalg.norm(alvo_d)
inicio = np.array(args[6:12] if len(args) >= 12 else [-0.8, 0.0, 0.0, -1.2, 0.0, 0.0])
v = inicio.copy()
lam = 0.1
r = residuo(v, alvo_g, alvo_d)
for it in range(80):
    J = np.zeros((len(r), 6))
    for k in range(6):
        w = v.copy()
        w[k] += 1e-3
        J[:, k] = (residuo(w, alvo_g, alvo_d) - r) / 1e-3
    A = J.T @ J + lam * np.eye(6)
    # regulariza para ficar perto do ponto de partida (evita voltas inúteis do ombro/cotovelo)
    passo = np.linalg.solve(A, -(J.T @ r) - 0.02 * (v - inicio))
    novo = v + passo
    rn = residuo(novo, alvo_g, alvo_d)
    if rn @ rn < r @ r:
        v, r, lam = novo, rn, max(lam * 0.5, 1e-4)
    else:
        lam *= 4.0
    if r @ r < 1e-7:
        break
pose(v)
g, ponta = pontos()
print("IK braco=(%.3f, %.3f, %.3f) antebraco=(%.3f, %.3f, %.3f) erro=%.4f guarda=%s ponta=%s" % (
    v[0], v[1], v[2], v[3], v[4], v[5], float(np.linalg.norm(r)), np.round(g, 2), np.round(ponta, 2)))

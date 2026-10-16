"""Previa das folhas de efeito com a MESMA conta do shader do corte: cor = mix(tinta, branco, calor*0.55); soma rgb*alfa*2 no fundo.

    python previa_efeitos.py <pasta_com_folhas>
Gera <nome>.gif (3x, 15 fps) e uma tira <nome>_tira.png por efeito, mais 'todos.gif' lado a lado.
"""
import os
import sys

import numpy as np
from PIL import Image

PASTA = os.path.abspath(sys.argv[1])
TAM, ESC = 128, 3
FUNDO = np.array([0.10, 0.09, 0.14], dtype=np.float32)
TINTAS = {"cristal": (0.55, 0.75, 1.0), "estrela": (1.0, 0.85, 0.55), "anel": (1.0, 0.55, 0.30), "espiral": (0.80, 0.92, 1.0)}


def quadros(nome):
    f = np.asarray(Image.open(os.path.join(PASTA, "efeito_%s_folha.png" % nome)).convert("RGBA"), dtype=np.float32) / 255.0
    n = f.shape[1] // TAM
    cor = np.array(TINTAS[nome], dtype=np.float32)
    out = []
    for i in range(n):
        q = f[:, i * TAM:(i + 1) * TAM]
        h, a = q[..., 0:1], q[..., 3:4]
        c = cor * (1 - h * 0.55) + h * 0.55
        img = np.clip(FUNDO + c * a * 2.0, 0, 1)
        img = np.repeat(np.repeat(img, ESC, axis=0), ESC, axis=1)
        out.append(Image.fromarray((img * 255 + 0.5).astype(np.uint8)))
    return out


todos = {}
for nome in TINTAS:
    if not os.path.exists(os.path.join(PASTA, "efeito_%s_folha.png" % nome)):
        continue
    qs = quadros(nome)
    todos[nome] = qs
    qs[0].save(os.path.join(PASTA, nome + ".gif"), save_all=True, append_images=qs[1:] + [qs[-1]] * 6, duration=66, loop=0)
    tira = Image.new("RGB", (TAM * ESC // 2 * len(qs), TAM * ESC // 2))
    for i, q in enumerate(qs):
        tira.paste(q.resize((TAM * ESC // 2, TAM * ESC // 2), Image.NEAREST), (i * TAM * ESC // 2, 0))
    tira.save(os.path.join(PASTA, nome + "_tira.png"))

if todos:
    n = max(len(v) for v in todos.values()) + 6
    lado = TAM * ESC
    frames = []
    for i in range(n):
        f = Image.new("RGB", (lado * len(todos), lado))
        for j, qs in enumerate(todos.values()):
            f.paste(qs[min(i, len(qs) - 1)] if i < len(qs) else Image.new("RGB", (lado, lado), tuple(int(x * 255) for x in FUNDO)), (j * lado, 0))
        frames.append(f)
    frames[0].save(os.path.join(PASTA, "todos.gif"), save_all=True, append_images=frames[1:], duration=66, loop=0)
print("PREVIA OK", list(todos))

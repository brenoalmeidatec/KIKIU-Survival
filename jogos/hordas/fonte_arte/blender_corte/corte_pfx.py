"""Cortes da katana no estilo do pixelfx: a folha do Blender fica (a lâmina e o arco), e por cima entram o rastro largo que esfria e as faíscas que a
lâmina arranca, indo pela tangente do arco com arrasto. Guia: docs/visual_2_5d/estilo_pixelfx.md.

Uso (a partir da raiz do repositório):  python jogos/hordas/fonte_arte/blender_corte/corte_pfx.py && python jogos/hordas/fonte_arte/blender_corte/girar_corte.py
Saída: corte_pfx_folha.png e corte_pfx_ciano_folha.png aqui, e as cópias corte_pfx.png e corte_pfx_ciano.png em assets/v2/efeitos. Semente fixa.
Formato da folha: R = calor, A = intensidade (shader do corte, v2/efeitos.gd).
"""

import math
import os
import random

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "v2", "efeitos"))
Q = 128
RAIO = 54.0  # onde o arco da folha passa
GOLPE = 4  # o quadro em que a lâmina começa a varrer
TONS = ((255, 255), (170, 212), (85, 128), (40, 64))  # (calor, intensidade), do fio ao que esfria


def ponto(g, x, y, tom, b):
    i, j = int(x / b), int(y / b)
    if (x - 64) ** 2 + (y - 64) ** 2 < 62**2 and g[j, i, 3] < TONS[tom][1]:
        g[j, i] = (TONS[tom][0], TONS[tom][0], TONS[tom][0], TONS[tom][1])


def linha(g, x0, y0, x1, y1, tom, b):
    n = int(max(abs(x1 - x0), abs(y1 - y0), 1)) * 2
    for k in range(n + 1):
        ponto(g, x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n, tom, b)


def fazer(arq, saida, n, b, semente):
    r = random.Random(semente)
    im = np.array(Image.open(os.path.join(AQUI, arq)).convert("RGBA"))
    faiscas = []
    for f in range(GOLPE, GOLPE + 3):  # a lâmina passa e arranca faíscas onde está naquele quadro
        meio = -60 + (f - GOLPE) * 60
        for _ in range(9):
            a = math.radians(meio + r.uniform(-28, 28))
            v = r.uniform(3.5, 8.0)
            faiscas.append(dict(f0=f, x=64 + math.cos(a) * RAIO, y=64 + math.sin(a) * RAIO, vx=-math.sin(a) * v + math.cos(a) * 1.2, vy=math.cos(a) * v + math.sin(a) * 1.2, vida=r.randint(4, 8)))
    for f in range(n):
        g = im[::b, f * Q : (f + 1) * Q : b].copy()
        idade = f - GOLPE - 2
        if 0 <= idade < 5:  # o rastro largo: três fios que descem a rampa e se abrem
            for fio, dr in enumerate((-6, -3, 0)):
                for grau in range(-78, 80, 2):
                    if (grau + fio * 5 + idade * 7) % 11 < 11 - idade * 2:
                        a = math.radians(grau)
                        rr = RAIO + dr - idade * 0.8
                        ponto(g, 64 + math.cos(a) * rr, 64 + math.sin(a) * rr, min(3, 1 + idade // 2 + (fio == 0)), b)
        for s in faiscas:
            k = f - s["f0"]
            if 0 <= k < s["vida"]:
                x0, y0 = s["x"], s["y"]
                s["x"] += s["vx"]
                s["y"] += s["vy"]
                s["vx"] *= 0.84  # o arrasto freia
                s["vy"] *= 0.84
                linha(g, x0, y0, s["x"], s["y"], min(3, k * 3 // s["vida"]), b)
        cheio = np.repeat(np.repeat(g, b, axis=0), b, axis=1)
        im[:, f * Q : (f + 1) * Q] = cheio
    Image.fromarray(im, "RGBA").save(os.path.join(AQUI, saida + "_folha.png"), optimize=True)
    Image.fromarray(im, "RGBA").save(os.path.join(SAIDA, saida + ".png"), optimize=True)


if __name__ == "__main__":
    fazer("corte_hazaki_folha.png", "corte_pfx", 16, 1, 21)
    fazer("corte_hazaki_ciano_folha.png", "corte_pfx_ciano", 12, 2, 22)

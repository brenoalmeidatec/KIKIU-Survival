"""Cortes da katana no estilo do pixelfx: a folha do Blender fica (a lâmina e o arco), e por cima entram o rastro largo que esfria e as faíscas que a
lâmina arranca, indo pela tangente do arco com arrasto. Guia: docs/visual_2_5d/estilo_pixelfx.md.

Em 1 px de arte = 1 px do jogo (regra das folhas por tamanho, folhas_1px.py): a base de cada tamanho é a folha que o folhas_1px.py renderiza no Blender
(1px/corte_hazaki_e<L>.png e 1px/corte_hazaki_ciano_e<L>.png, aqui ao lado, 4 linhas = 0, 22,5, 45 e 67,5 graus). O rastro e as faíscas são
desenhados ponto a ponto direto em cada tamanho (as coordenadas do desenho de 128 px escalam por L/128 e giram 22,5 graus por linha; o ponto cai num
pixel inteiro, nada é reamostrado nem girado depois), com os tons que a folha já usa (o mais perto de cada tom do pixelfx). Na ciano, o ponto do
rastro que sairia sozinho é descartado (a folha não pode ter pixel solto) e nada encosta na borda do quadro.

Uso (a partir da raiz do repositório, depois do folhas_1px.py, sem Blender):  python jogos/hordas/fonte_arte/blender_corte/corte_pfx.py
Saída: assets/v2/efeitos/corte_pfx_e<L>.png e corte_pfx_ciano_e<L>.png (os tamanhos de dados/v2_folhas_fx.json). Semente fixa.
Formato da folha: R = calor, A = intensidade (shader do corte, v2/efeitos.gd).
"""

import json
import math
import os
import random

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto"))
SAIDA = os.path.join(PROJETO, "assets", "v2", "efeitos")
BASE = os.path.join(AQUI, "1px")  # as folhas do Blender por tamanho (folhas_1px.py)
Q = 128  # o desenho é pensado num quadro de 128 px e escala para o tamanho de cada folha
RAIO = 54.0  # onde o arco da folha passa
GOLPE = 4  # o quadro em que a lâmina começa a varrer
TONS = ((255, 255), (170, 212), (85, 128), (40, 64))  # (calor, intensidade), do fio ao que esfria
GIRO = 22.5  # graus por linha da folha
VARIANTES = {"corte": ("corte_hazaki_e%d.png", "corte_pfx_e%d.png", 21), "corte_ciano": ("corte_hazaki_ciano_e%d.png", "corte_pfx_ciano_e%d.png", 22)}


def perto(valores: np.ndarray, v: int) -> int:
    return int(min(valores.tolist(), key=lambda x: (abs(x - v), -x)))


def faiscas_do_golpe(semente: int) -> list:
    r = random.Random(semente)
    lista = []
    for f in range(GOLPE, GOLPE + 3):  # a lâmina passa e arranca faíscas onde está naquele quadro
        meio = -60 + (f - GOLPE) * 60
        for _ in range(9):
            a = math.radians(meio + r.uniform(-28, 28))
            v = r.uniform(3.5, 8.0)
            lista.append(dict(f0=f, x=64 + math.cos(a) * RAIO, y=64 + math.sin(a) * RAIO, vx=-math.sin(a) * v + math.cos(a) * 1.2, vy=math.cos(a) * v + math.sin(a) * 1.2, vida=r.randint(4, 8)))
    return lista


def desenho(n: int, semente: int) -> list:
    """Por quadro, a lista de traços (x0, y0, x1, y1, tom) no quadro de 128 px (ponto = traço de comprimento zero)."""
    faiscas = faiscas_do_golpe(semente)
    quadros = []
    for f in range(n):
        tracos = []
        idade = f - GOLPE - 2
        if 0 <= idade < 5:  # o rastro largo: três fios que descem a rampa e se abrem
            for fio, dr in enumerate((-6, -3, 0)):
                for grau in range(-78, 80, 2):
                    if (grau + fio * 5 + idade * 7) % 11 < 11 - idade * 2:
                        a = math.radians(grau)
                        rr = RAIO + dr - idade * 0.8
                        x, y = 64 + math.cos(a) * rr, 64 + math.sin(a) * rr
                        tracos.append((x, y, x, y, min(3, 1 + idade // 2 + (fio == 0))))
        for s in faiscas:
            k = f - s["f0"]
            if 0 <= k < s["vida"]:
                x0, y0 = s["x"], s["y"]
                s["x"] += s["vx"]
                s["y"] += s["vy"]
                s["vx"] *= 0.84  # o arrasto freia
                s["vy"] *= 0.84
                tracos.append((x0, y0, s["x"], s["y"], min(3, k * 3 // s["vida"])))
        quadros.append(tracos)
    return quadros


def fazer(nome: str, lado: int, linhas: int) -> None:
    entrada, saida, semente = VARIANTES[nome]
    im = np.array(Image.open(os.path.join(BASE, entrada % lado)).convert("RGBA"))
    n = im.shape[1] // lado
    vis = im[..., 3] > 0
    alfas, calores = np.unique(im[..., 3][vis]), np.unique(im[..., 0][vis])
    tons = [(perto(calores, c), perto(alfas, a)) for c, a in TONS]
    esc = lado / Q
    meio = lado / 2.0
    for lin in range(linhas):
        cg, sg = math.cos(math.radians(GIRO * lin)), math.sin(math.radians(GIRO * lin))  # tela com y para baixo: gira no sentido horário
        for f, tracos in enumerate(desenho(n, semente)):
            g = im[lin * lado : (lin + 1) * lado, f * lado : (f + 1) * lado]
            novo = np.zeros((lado, lado), bool)
            for x0, y0, x1, y1, tom in tracos:
                passos = max(1, int(math.ceil(max(abs(x1 - x0), abs(y1 - y0)) * esc * 2)))
                for k in range(passos + 1):
                    dx = (x0 + (x1 - x0) * k / passos - 64) * esc
                    dy = (y0 + (y1 - y0) * k / passos - 64) * esc
                    if dx * dx + dy * dy >= (62 * esc) ** 2:
                        continue
                    i, j = int(math.floor(meio + dx * cg - dy * sg)), int(math.floor(meio + dx * sg + dy * cg))
                    if not (1 <= i < lado - 1 and 1 <= j < lado - 1):  # nada encosta na borda do quadro
                        continue
                    c, a = tons[tom]
                    if g[j, i, 3] < a:
                        g[j, i] = (c, c, c, a)
                        novo[j, i] = True
            if nome == "corte_ciano":  # ponto novo sem vizinho nenhum vira pixel solto: sai
                v = np.pad(g[..., 3] > 0, 1)
                viz = sum(v[1 + a : 1 + a + lado, 1 + b : 1 + b + lado] for a in (-1, 0, 1) for b in (-1, 0, 1) if (a, b) != (0, 0))
                g[novo & (viz == 0)] = 0
    Image.fromarray(im, "RGBA").save(os.path.join(SAIDA, saida % lado), optimize=True)
    print(nome, lado, saida % lado)


if __name__ == "__main__":
    with open(os.path.join(PROJETO, "dados", "v2_folhas_fx.json"), encoding="utf-8") as arq:
        dados = json.load(arq)
    for variante in VARIANTES:
        for par in dados[variante]["tam"]:
            fazer(variante, int(par[0]), int(dados[variante]["linhas"]))

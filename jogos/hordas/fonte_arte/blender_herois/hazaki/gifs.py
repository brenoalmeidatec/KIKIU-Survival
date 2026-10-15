"""GIFs do Hazaki (Python com Pillow): um GIF por animação (8 direções lado a lado) e um comparativo com o herói atual do jogo.

    python gifs.py <pasta_de_saida>

Lê quadros/<anim>/ desta pasta e a folha atual do jogo em ../../../projeto/prototipos/cara_nova/sprites/hazaki_albedo.png.
A velocidade de cada GIF é a do hazaki_final.json (s_por_quadro). No comparativo, o atual roda 4 quadros e o novo 6 no mesmo
ciclo de 0,54 s (o atual fica a 0,135 s por quadro aqui; no jogo o PASSO_ANIM de heroi.gd é 0,13 s), para comparar as poses.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.normpath(os.path.join(AQUI, "..", "..", "..", "projeto"))
W, H, Z = 32, 44, 4
DIRECOES = ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"]
FUNDO = (34, 34, 42)
ROTULO = {"baixo": "baixo", "esquerda": "esq", "direita": "dir", "cima": "cima", "baixo_esq": "b.esq",
          "baixo_dir": "b.dir", "cima_esq": "c.esq", "cima_dir": "c.dir"}


def quadro(anim, q, d):
    return Image.open(os.path.join(AQUI, "quadros", anim, "%s_%d_cor.png" % (d, q))).convert("RGBA")


def tira(celulas, rotulos=True, titulo=None):
    """Uma linha com as 8 direções ampliadas Z vezes (filtro nearest, o pixel do jogo continua nítido).
    Rótulo das direções em cima (se rotulos) e título da linha embaixo (se titulo)."""
    topo = 14
    base = topo + H * Z + 2
    altura = base + (14 if titulo else 0)
    img = Image.new("RGB", (len(celulas) * (W * Z + 8) + 8, altura), FUNDO)
    d = ImageDraw.Draw(img)
    for j, (c, nome) in enumerate(celulas):
        g = c.resize((W * Z, H * Z), Image.NEAREST)
        img.paste(g, (8 + j * (W * Z + 8), topo), g)
        if rotulos:
            d.text((10 + j * (W * Z + 8), 2), ROTULO[nome], fill=(190, 190, 200))
    if titulo:
        d.text((10, base), titulo, fill=(230, 200, 150))
    return img


def gif_animacao(anim, n, s, saida):
    quadros = []
    for q in range(n):
        celulas = [(quadro(anim, q, d), d) for d in DIRECOES]
        quadros.append(tira(celulas))
    caminho = os.path.join(saida, anim + ".gif")
    quadros[0].save(caminho, save_all=True, append_images=quadros[1:], duration=int(round(s * 1000)), loop=0, disposal=2)
    return caminho


def gif_comparativo(saida):
    """Atual (folha do jogo, colunas andar0, andar2, andar4, andar6 = o que heroi.gd usa) x novo (andar do Blender, 6 quadros)."""
    atual_info = json.load(open(os.path.join(PROJETO, "prototipos", "cara_nova", "sprites", "hazaki.json"), encoding="utf-8"))
    folha = Image.open(os.path.join(PROJETO, "prototipos", "cara_nova", "sprites", "hazaki_albedo.png")).convert("RGBA")
    linhas_atual = atual_info["linhas"]
    colunas_passo = [1, 2, 3, 4]  # c = 1 + passo % (colunas.size() - 1) em heroi.gd: andar0, andar2, andar4, andar6

    def celula_atual(i, d):
        col = colunas_passo[i]
        lin = linhas_atual.index(d)
        return folha.crop((col * W, lin * H, col * W + W, lin * H + H))

    ciclo = 540  # ms: 4 quadros do atual a 135 ms e 6 do novo a 90 ms fecham o mesmo ciclo
    dur_atual, dur_novo = ciclo / 4.0, ciclo / 6.0
    eventos = sorted(set([int(round(i * dur_atual)) for i in range(4)] + [int(round(i * dur_novo)) for i in range(6)]))
    eventos.append(ciclo)
    # o GIF guarda o tempo em centésimos: as marcas são arredondadas para 10 ms, acumuladas, e o ciclo continua somando 540 ms
    marcas = [int(round(t / 10.0)) * 10 for t in eventos]
    quadros, duracoes = [], []
    for k in range(len(eventos) - 1):
        t = eventos[k]
        i_atual = int(t // dur_atual) % 4
        i_novo = int(t // dur_novo) % 6
        linha_a = [(celula_atual(i_atual, d), d) for d in DIRECOES]
        linha_n = [(quadro("andar", i_novo, d), d) for d in DIRECOES]
        cima = tira(linha_a, titulo="atual (jogo hoje): 0,135 s por quadro")
        baixo = tira(linha_n, rotulos=False, titulo="novo (andar do Blender): 0,09 s por quadro")
        img = Image.new("RGB", (cima.width, cima.height + baixo.height + 6), FUNDO)
        img.paste(cima, (0, 0))
        img.paste(baixo, (0, cima.height + 6))
        quadros.append(img)
        duracoes.append(marcas[k + 1] - marcas[k])
    caminho = os.path.join(saida, "comparativo_atual_x_novo.gif")
    quadros[0].save(caminho, save_all=True, append_images=quadros[1:], duration=duracoes, loop=0, disposal=2)
    return caminho


def main():
    if len(sys.argv) < 2:
        raise SystemExit("uso: python gifs.py <pasta_de_saida>")
    saida = sys.argv[1]
    os.makedirs(saida, exist_ok=True)
    info = json.load(open(os.path.join(AQUI, "hazaki_final.json"), encoding="utf-8"))
    for anim, dados in info["animacoes"].items():
        n = dados["quadros"]
        print(gif_animacao(anim, n, dados["s_por_quadro"], saida))
    print(gif_comparativo(saida))


main()

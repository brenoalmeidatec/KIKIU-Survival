"""GIFs do Lucas (Python com Pillow): um GIF por animação (8 direções lado a lado) e um comparativo com o sprite que o jogo tinha antes.

    python gifs.py <pasta_de_saida>

Lê quadros/<anim>/ desta pasta e a folha antiga do Lucas (sprite_antigo_albedo.png + sprite_antigo.json, cópia do que o jogo usava antes: 40x46, 5 colunas).
A velocidade de cada GIF é a do lucas_final.json (s_por_quadro / s_quadros). No comparativo, o antigo roda 4 quadros e o novo 6 no mesmo ciclo de 0,54 s
(o antigo fica a 0,135 s por quadro; no jogo o PASSO_ANIM de heroi.gd é 0,13 s), para comparar as poses.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
W, H, Z = 32, 44, 4
DIRECOES = ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"]
FUNDO = (34, 34, 42)
ROTULO = {"baixo": "baixo", "esquerda": "esq", "direita": "dir", "cima": "cima", "baixo_esq": "b.esq",
          "baixo_dir": "b.dir", "cima_esq": "c.esq", "cima_dir": "c.dir"}


def quadro(anim, q, d):
    return Image.open(os.path.join(AQUI, "quadros", anim, "%s_%d_cor.png" % (d, q))).convert("RGBA")


def tira(celulas, rotulos=True, titulo=None, w=W, h=H):
    """Uma linha com as 8 direções ampliadas Z vezes (filtro nearest, o pixel do jogo continua nítido), cada célula de w x h px.
    Rótulo das direções em cima (se rotulos) e título da linha embaixo (se titulo)."""
    topo = 14
    base = topo + h * Z + 2
    altura = base + (14 if titulo else 0)
    img = Image.new("RGB", (len(celulas) * (w * Z + 8) + 8, altura), FUNDO)
    d = ImageDraw.Draw(img)
    for j, (c, nome) in enumerate(celulas):
        g = c.resize((w * Z, h * Z), Image.NEAREST)
        img.paste(g, (8 + j * (w * Z + 8), topo), g)
        if rotulos:
            d.text((10 + j * (w * Z + 8), 2), ROTULO[nome], fill=(190, 190, 200))
    if titulo:
        d.text((10, base), titulo, fill=(230, 200, 150))
    return img


def gif_animacao(anim, n, s, saida, tempos=None):
    """`tempos` = segundos de cada quadro (s_quadros do json: impacto rápido, hold e repouso longos); sem ele, `s` para todos."""
    quadros = []
    for q in range(n):
        celulas = [(quadro(anim, q, d), d) for d in DIRECOES]
        quadros.append(tira(celulas))
    caminho = os.path.join(saida, anim + ".gif")
    duracao = [int(round(t * 1000)) for t in tempos] if tempos else int(round(s * 1000))
    quadros[0].save(caminho, save_all=True, append_images=quadros[1:], duration=duracao, loop=0, disposal=2)
    return caminho


def gif_comparativo(saida):
    """Antigo (folha do jogo antes: colunas andar0, andar2, andar4, andar6 = o que heroi.gd usava) x novo (andar do Blender, 6 quadros)."""
    antigo_info = json.load(open(os.path.join(AQUI, "sprite_antigo.json"), encoding="utf-8"))
    folha = Image.open(os.path.join(AQUI, "sprite_antigo_albedo.png")).convert("RGBA")
    aw, ah = antigo_info["quadro"]
    linhas_antigo = antigo_info["linhas"]
    colunas_passo = [1, 2, 3, 4]  # c = 1 + passo % (colunas.size() - 1) em heroi.gd

    def celula_antigo(i, d):
        col = colunas_passo[i]
        lin = linhas_antigo.index(d)
        return folha.crop((col * aw, lin * ah, col * aw + aw, lin * ah + ah))

    ciclo = 540  # ms: 4 quadros do antigo a 135 ms e 6 do novo a 90 ms fecham o mesmo ciclo
    dur_antigo, dur_novo = ciclo / 4.0, ciclo / 6.0
    eventos = sorted(set([int(round(i * dur_antigo)) for i in range(4)] + [int(round(i * dur_novo)) for i in range(6)]))
    eventos.append(ciclo)
    # o GIF guarda o tempo em centésimos: as marcas são arredondadas para 10 ms, acumuladas, e o ciclo continua somando 540 ms
    marcas = [int(round(t / 10.0)) * 10 for t in eventos]
    quadros, duracoes = [], []
    for k in range(len(eventos) - 1):
        t = eventos[k]
        i_antigo = int(t // dur_antigo) % 4
        i_novo = int(t // dur_novo) % 6
        linha_a = [(celula_antigo(i_antigo, d), d) for d in DIRECOES]
        linha_n = [(quadro("andar", i_novo, d), d) for d in DIRECOES]
        cima = tira(linha_a, titulo="antes (sprite do jogo, 40x46): 0,135 s por quadro", w=aw, h=ah)
        baixo = tira(linha_n, rotulos=False, titulo="novo (andar do Blender, 32x44): 0,09 s por quadro")
        larg = max(cima.width, baixo.width)
        img = Image.new("RGB", (larg, cima.height + baixo.height + 6), FUNDO)
        img.paste(cima, (0, 0))
        img.paste(baixo, (0, cima.height + 6))
        quadros.append(img)
        duracoes.append(marcas[k + 1] - marcas[k])
    caminho = os.path.join(saida, "comparativo_antes_x_novo.gif")
    quadros[0].save(caminho, save_all=True, append_images=quadros[1:], duration=duracoes, loop=0, disposal=2)
    return caminho


def main():
    if len(sys.argv) < 2:
        raise SystemExit("uso: python gifs.py <pasta_de_saida>")
    saida = sys.argv[1]
    os.makedirs(saida, exist_ok=True)
    info = json.load(open(os.path.join(AQUI, "lucas_final.json"), encoding="utf-8"))
    for anim, dados in info["animacoes"].items():
        n = dados["quadros"]
        print(gif_animacao(anim, n, dados["s_por_quadro"], saida, dados.get("s_quadros")))
    print(gif_comparativo(saida))


main()

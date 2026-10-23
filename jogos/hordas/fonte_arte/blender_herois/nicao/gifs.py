"""GIFs do Nicão (Python com Pillow): um GIF por animação (8 direções lado a lado) e um comparativo com o sprite que o jogo usava antes.

    python gifs.py <pasta_de_saida> [--atual=<pasta com nicao_albedo.png e nicao.json antigos>]

Lê quadros/<anim>/ desta pasta. A velocidade de cada GIF é a do nicao_final.json (s_quadros / s_por_quadro). O sprite ANTIGO (a folha 64x60 de 5 colunas,
que o jogo usava até este PR) vem de --atual (padrão: ../../../projeto/prototipos/cara_nova/sprites/, que já tem a folha nova: para comparar, extraia a
antiga com `git show origin/main:jogos/hordas/projeto/prototipos/cara_nova/sprites/nicao_albedo.png`). No comparativo o antigo roda 4 quadros e o novo 6
no mesmo ciclo de 0,66 s (o antigo a 0,165 s por quadro; no jogo o PASSO_ANIM do heroi.gd é 0,13 s), na mesma escala 1:1 de pixel (o antigo, 64x60, fica
com o pé na linha 58 do quadro; o novo, 64x96, na linha 74), então a altura do anão é comparável.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.normpath(os.path.join(AQUI, "..", "..", "..", "projeto"))
W, H, Z = 64, 96, 3
DIRECOES = ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"]
FUNDO = (34, 34, 42)
ROTULO = {"baixo": "baixo", "esquerda": "esq", "direita": "dir", "cima": "cima", "baixo_esq": "b.esq",
          "baixo_dir": "b.dir", "cima_esq": "c.esq", "cima_dir": "c.dir"}


def quadro(anim, q, d):
    return Image.open(os.path.join(AQUI, "quadros", anim, "%s_%d_cor.png" % (d, q))).convert("RGBA")


def tira(celulas, rotulos=True, titulo=None, w=W, h=H, z=Z, pe=None):
    """Uma linha com as 8 direções ampliadas z vezes (filtro nearest). Rótulo das direções em cima e título embaixo. `pe` alinha uma célula mais baixa
    pelo pé: o desenho é colado com o pé na linha `pe` de uma célula W x H (para comparar sprites de quadros diferentes)."""
    topo = 14
    base = topo + h * z + 2
    altura = base + (14 if titulo else 0)
    img = Image.new("RGB", (len(celulas) * (w * z + 8) + 8, altura), FUNDO)
    d = ImageDraw.Draw(img)
    for j, (c, nome) in enumerate(celulas):
        g = c.resize((c.width * z, c.height * z), Image.NEAREST)
        img.paste(g, (8 + j * (w * z + 8) + (w * z - g.width) // 2, topo + (h * z - g.height)), g)
        if rotulos:
            d.text((10 + j * (w * z + 8), 2), ROTULO[nome], fill=(190, 190, 200))
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


def gif_comparativo(saida, atual):
    """Antigo (folha do jogo até este PR, colunas andar0, andar2, andar4, andar6 = o que o heroi.gd usava) x novo (andar do Blender, 6 quadros)."""
    info = json.load(open(os.path.join(atual, "nicao.json"), encoding="utf-8"))
    folha = Image.open(os.path.join(atual, "nicao_albedo.png")).convert("RGBA")
    aw, ah = info["quadro"]
    linhas_atual = info["linhas"]
    colunas_passo = [1, 2, 3, 4]  # c = 1 + passo % (colunas.size() - 1) em heroi.gd

    def celula_atual(i, d):
        col, lin = colunas_passo[i], linhas_atual.index(d)
        tela = Image.new("RGBA", (aw, H), (0, 0, 0, 0))     # o pé do antigo (pe_y do json) cai na mesma linha do pé do novo (74)
        tela.paste(folha.crop((col * aw, lin * ah, col * aw + aw, lin * ah + ah)), (0, 74 - int(info["pe_y"])))
        return tela

    ciclo = 660  # ms: 4 quadros do antigo a 165 ms e 6 do novo a 110 ms fecham o mesmo ciclo
    dur_atual, dur_novo = ciclo / 4.0, ciclo / 6.0
    eventos = sorted(set([int(round(i * dur_atual)) for i in range(4)] + [int(round(i * dur_novo)) for i in range(6)]))
    eventos.append(ciclo)
    marcas = [int(round(t / 10.0)) * 10 for t in eventos]
    quadros, duracoes = [], []
    for k in range(len(eventos) - 1):
        t = eventos[k]
        i_atual = int(t // dur_atual) % 4
        i_novo = int(t // dur_novo) % 6
        linha_a = [(celula_atual(i_atual, d), d) for d in DIRECOES]
        linha_n = [(quadro("andar", i_novo, d), d) for d in DIRECOES]
        cima = tira(linha_a, titulo="antes (jogo até este PR): 64x60, 0,165 s por quadro")
        baixo = tira(linha_n, rotulos=False, titulo="novo (Blender): 64x96, 0,11 s por quadro")
        img = Image.new("RGB", (max(cima.width, baixo.width), cima.height + baixo.height + 6), FUNDO)
        img.paste(cima, (0, 0))
        img.paste(baixo, (0, cima.height + 6))
        quadros.append(img)
        duracoes.append(marcas[k + 1] - marcas[k])
    caminho = os.path.join(saida, "comparativo_atual_x_novo.gif")
    quadros[0].save(caminho, save_all=True, append_images=quadros[1:], duration=duracoes, loop=0, disposal=2)
    # e um PNG: o quadro parado dos dois, de frente, lado a lado, na mesma escala
    return caminho


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        raise SystemExit("uso: python gifs.py <pasta_de_saida> [--atual=<pasta>]")
    saida = args[0]
    atual = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--atual=")),
                 os.path.join(PROJETO, "prototipos", "cara_nova", "sprites"))
    os.makedirs(saida, exist_ok=True)
    info = json.load(open(os.path.join(AQUI, "nicao_final.json"), encoding="utf-8"))
    for anim, dados in info["animacoes"].items():
        n = dados["quadros"]
        print(gif_animacao(anim, n, dados["s_por_quadro"], saida, dados.get("s_quadros")))
    print(gif_comparativo(saida, atual))


main()

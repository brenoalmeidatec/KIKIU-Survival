"""Prévias do piloto (Python com Pillow): GIF do andar nas 8 direções e GIF antes x depois contra o sprite atual do jogo.

    python previa_gif.py [pasta_de_saida]     (padrão: docs/visual_2_5d/blender_herois)
Lê hazaki_samurai_blender_{albedo,normal}.png (aqui) e hazaki_samurai_{albedo,normal}.png (sprite atual do protótipo).
Cor = albedo com uma luz simples vinda da normal (só para a prévia ler volume; o jogo faz a luz dele).
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, "..", "..", "..", ".."))
ATUAL = os.path.join(AQUI, "..", "..", "projeto", "prototipos", "cara_nova", "sprites")
SAIDA = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, "docs", "visual_2_5d", "blender_herois")
W, H, Z = 32, 44, 4
LINHAS = ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"]
FUNDO = (34, 34, 42)
CICLO = 0.54      # s: mesma duração de ciclo nos dois, para a comparação ser justa
PASSO_MS = 30


def folha(pasta, nome):
    alb = np.array(Image.open(os.path.join(pasta, nome + "_albedo.png")).convert("RGBA")).astype(np.float32) / 255
    nor = np.array(Image.open(os.path.join(pasta, nome + "_normal.png")).convert("RGBA")).astype(np.float32) / 255
    luz = np.array([-0.45, 0.55, 0.7])
    luz /= np.linalg.norm(luz)
    n = nor[:, :, :3] * 2 - 1
    k = np.clip((n * luz).sum(axis=2), 0, 1)
    alb[:, :, :3] *= (0.6 + 0.55 * k)[:, :, None]
    return Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8), "RGBA")


def quadro(f, linha, col):
    return f.crop((col * W, linha * H, (col + 1) * W, (linha + 1) * H))


def cena(celulas, rotulos, larg_cel):
    """celulas: lista de listas (linhas de imagens W x H). Devolve imagem RGB ampliada."""
    nl, nc = len(celulas), len(celulas[0])
    img = Image.new("RGB", (nc * larg_cel, nl * (H * Z + 14)), FUNDO)
    d = ImageDraw.Draw(img)
    for i, linha in enumerate(celulas):
        for j, c in enumerate(linha):
            x, y = j * larg_cel + (larg_cel - W * Z) // 2, i * (H * Z + 14) + 14
            img.paste(c.resize((W * Z, H * Z), Image.NEAREST), (x, y), c.resize((W * Z, H * Z), Image.NEAREST))
            d.text((j * larg_cel + 4, i * (H * Z + 14) + 2), rotulos[i][j], fill=(190, 190, 200))
    return img


def main():
    os.makedirs(SAIDA, exist_ok=True)
    novo = folha(AQUI, "hazaki_samurai_blender")
    velho = folha(ATUAL, "hazaki_samurai")
    n_novo, n_velho = 6, 4
    passos = int(round(CICLO * 1000 / PASSO_MS))
    # 1) 8 direções, só o novo
    quadros = []
    for t in range(passos * 2):
        col = 1 + int(t * PASSO_MS / 1000 / (CICLO / n_novo)) % n_novo
        quadros.append(cena([[quadro(novo, l, col) for l in range(8)]], [LINHAS], W * Z + 8))
    quadros[0].save(os.path.join(SAIDA, "andar_8_direcoes.gif"), save_all=True, append_images=quadros[1:], duration=PASSO_MS,
                    loop=0, optimize=False)
    # 2) antes (sprite atual: 4 quadros de andar) x depois (Blender, 6 quadros), 4 direções
    dirs = [0, 2, 3, 5]
    quadros = []
    for t in range(passos * 2):
        cv = 1 + int(t * PASSO_MS / 1000 / (CICLO / n_velho)) % n_velho
        cn = 1 + int(t * PASSO_MS / 1000 / (CICLO / n_novo)) % n_novo
        quadros.append(cena([[quadro(velho, l, cv) for l in dirs], [quadro(novo, l, cn) for l in dirs]],
                            [["ATUAL " + LINHAS[l] for l in dirs], ["BLENDER " + LINHAS[l] for l in dirs]], W * Z + 12))
    quadros[0].save(os.path.join(SAIDA, "antes_depois.gif"), save_all=True, append_images=quadros[1:], duration=PASSO_MS,
                    loop=0, optimize=False)
    # 3) folha inteira ampliada (cor), para olhar quadro a quadro
    cel = [[quadro(novo, l, c) for c in range(7)] for l in range(8)]
    cena(cel, [["" for _ in range(7)] for _ in range(8)], W * Z + 4).save(os.path.join(SAIDA, "folha_ampliada.png"))
    print("ok", SAIDA)


main()

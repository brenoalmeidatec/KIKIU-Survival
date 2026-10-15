"""Prévia das animações do Hazaki (Python com Pillow): GIF das 8 direções lado a lado e uma folha de contato (PNG) por animação.

    python previa.py <anim> [pasta_de_saida] [--normal]       (padrão: a pasta quadros/ ao lado; --normal mostra o mapa de normais)
Lê quadros/<anim>/<direcao>_<i>_{cor,normal}.png. A cor usa um fundo escuro liso; --normal mostra a normal crua.
"""
import os
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
W, H, Z = 32, 44, 4
DIRECOES = ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"]
FUNDO = (34, 34, 42)


def carregar(anim, tipo):
    pasta = os.path.join(AQUI, "quadros", anim)
    n = 0
    while os.path.exists(os.path.join(pasta, "baixo_%d_cor.png" % n)):
        n += 1
    return [[Image.open(os.path.join(pasta, "%s_%d_%s.png" % (d, q, tipo))).convert("RGBA") for d in DIRECOES] for q in range(n)]


def montar(linha):
    img = Image.new("RGB", (len(linha) * (W * Z + 8) + 8, H * Z + 16), FUNDO)
    d = ImageDraw.Draw(img)
    for j, c in enumerate(linha):
        g = c.resize((W * Z, H * Z), Image.NEAREST)
        img.paste(g, (8 + j * (W * Z + 8), 14), g)
        d.text((10 + j * (W * Z + 8), 2), DIRECOES[j], fill=(190, 190, 200))
    return img


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    anim = args[0]
    saida = args[1] if len(args) > 1 else os.path.join(AQUI, "quadros")
    tipo = "normal" if "--normal" in sys.argv else "cor"
    os.makedirs(saida, exist_ok=True)
    quadros = carregar(anim, tipo)
    imgs = [montar(l) for l in quadros]
    sufixo = "_normal" if tipo == "normal" else ""
    ciclo_ms = 130 if anim == "andar" else 220     # só a prévia; a velocidade no jogo é decidida no jogo
    imgs[0].save(os.path.join(saida, anim + sufixo + ".gif"), save_all=True, append_images=imgs[1:], duration=ciclo_ms, loop=0, disposal=2)
    folha = Image.new("RGB", (imgs[0].width, imgs[0].height * len(imgs)), FUNDO)
    for i, im in enumerate(imgs):
        folha.paste(im, (0, i * im.height))
    folha.save(os.path.join(saida, anim + sufixo + "_folha.png"))
    print("ok", anim, tipo, len(imgs), "quadros")


main()

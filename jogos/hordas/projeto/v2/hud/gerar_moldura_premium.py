"""Gera a moldura dourada e a faixa de seleção dos menus da v2 (visual premium, #152 V6).

Arte nova, em arquivos novos: a moldura de pedra do Alisson (moldura_pedra.png, gerar_molduras.py) continua como está.
  moldura_premium.png  32x32, 9-slice com margem de 10 px: contorno preto, bisel dourado (claro em cima e à esquerda,
                       escuro embaixo e à direita), filete escuro, filete dourado apagado por dentro e um losango em cada
                       canto. O miolo é azul-noite quase preto e um pouco transparente (o jogo aparece de leve atrás).
  moldura_premium_fina.png  16x16, 9-slice com margem de 5 px (a mesma da pedra): a versão fina para as caixas pequenas do HUD.
  foco_premium.png     64x16, 9-slice (margem 3 nos lados, 2 em cima e embaixo): a linha escolhida de um menu. Barra
                       dourada à esquerda, brilho dourado que some para a direita e filetes em cima e embaixo que somem junto.
Uso: python -I gerar_moldura_premium.py  (grava ao lado deste arquivo)
"""

import os

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))

PRETO = (0, 0, 0, 255)
OURO_ESCURO = (122, 84, 36, 255)
OURO_CLARO = (246, 211, 128, 255)
OURO = (214, 164, 78, 255)
OURO_SOMBRA = (142, 96, 40, 255)
FILETE = (22, 15, 8, 255)
FILETE_OURO = (104, 76, 38, 170)
MIOLO = (7, 9, 18, 236)
BRILHO = (255, 236, 170, 255)


def moldura_premium() -> Image.Image:
    lado = 32
    im = Image.new("RGBA", (lado, lado), MIOLO)
    px = im.load()
    for y in range(lado):
        for x in range(lado):
            anel = min(x, y, lado - 1 - x, lado - 1 - y)
            if anel == 0:
                px[x, y] = PRETO
            elif anel == 1:
                px[x, y] = OURO_ESCURO
            elif anel == 2:
                # bisel: claro em cima e à esquerda, escuro embaixo e à direita
                if y == 2 or x == 2:
                    px[x, y] = OURO_CLARO if (x < lado - 3 and y < lado - 3) else OURO
                else:
                    px[x, y] = OURO_SOMBRA
            elif anel == 3:
                px[x, y] = OURO
            elif anel == 4:
                px[x, y] = FILETE
            elif anel == 6:
                px[x, y] = FILETE_OURO
    # losango em cada canto, por cima do bisel
    for cx, cy in ((4, 4), (lado - 5, 4), (4, lado - 5), (lado - 5, lado - 5)):
        for dy in range(-4, 5):
            for dx in range(-4, 5):
                d = abs(dx) + abs(dy)
                if d <= 4:
                    cor = PRETO if d == 4 else (OURO_CLARO if d <= 1 else (BRILHO if d == 2 and dy < 0 else OURO))
                    if d == 0:
                        cor = FILETE
                    px[cx + dx, cy + dy] = cor
    return im


def moldura_premium_fina() -> Image.Image:
    """A versão fina (16x16, margem de 5 px) para as caixas pequenas do HUD: relógio, abates, XP, chefe e nível."""
    lado = 16
    im = Image.new("RGBA", (lado, lado), (7, 9, 18, 225))
    px = im.load()
    for y in range(lado):
        for x in range(lado):
            anel = min(x, y, lado - 1 - x, lado - 1 - y)
            if anel == 0:
                px[x, y] = PRETO
            elif anel == 1:
                claro = (y == 1 or x == 1) and x < lado - 2 and y < lado - 2
                px[x, y] = OURO_CLARO if claro else OURO_SOMBRA
            elif anel == 2:
                px[x, y] = FILETE
            elif anel == 3:
                px[x, y] = FILETE_OURO
    for cx, cy in ((1, 1), (lado - 2, 1), (1, lado - 2), (lado - 2, lado - 2)):
        px[cx, cy] = BRILHO
    return im


def foco_premium() -> Image.Image:
    w, h = 64, 16
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for x in range(w):
        f = 1.0 - x / (w - 1)
        a_fundo = int(round(110 * f**1.4))
        a_filete = int(round(230 * f**0.9))
        for y in range(h):
            if y in (0, h - 1):
                px[x, y] = (255, 214, 120, a_filete)
            else:
                # o brilho é mais forte no meio da altura
                meio = 1.0 - abs((y - (h - 1) / 2) / ((h - 1) / 2)) * 0.35
                px[x, y] = (255, 186, 84, int(a_fundo * meio))
    for y in range(h):
        px[0, y] = (255, 236, 170, 255)
        px[1, y] = (255, 205, 96, 255)
    return im


if __name__ == "__main__":
    moldura_premium().save(os.path.join(AQUI, "moldura_premium.png"))
    moldura_premium_fina().save(os.path.join(AQUI, "moldura_premium_fina.png"))
    foco_premium().save(os.path.join(AQUI, "foco_premium.png"))
    print("moldura_premium.png, moldura_premium_fina.png e foco_premium.png gravadas em", AQUI)

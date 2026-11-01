"""Ícone PROVISÓRIO do slot S do Luke (a fumaça, DEF-5): uma bomba de ferro com o pavio aceso e a fumaça subindo, 32x32.

Arte própria, feita por código (nenhuma arte de terceiros). Vale até o Isac aprovar a arte A26 (ChatGPT); aí o `lucas.png` é trocado.
Uso (a partir da raiz do repo): python jogos/hordas/fonte_arte/secundario_s/gerar_fumaca_luke.py
Saída: jogos/hordas/projeto/assets/v2/secundario_s/lucas.png (o HUD lê assets/v2/secundario_s/<chave do herói>.png)."""

import math
import os

from PIL import Image

SAIDA = os.path.join(os.path.dirname(__file__), "..", "..", "projeto", "assets", "v2", "secundario_s", "lucas.png")
T = 32
CONTORNO = (22, 18, 28, 255)


def disco(im, cx, cy, r, cor):
    for y in range(T):
        for x in range(T):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                im.putpixel((x, y), cor)


def com_contorno(im, desenho):
    """Desenha com `desenho(img)` numa camada e põe 1 px de contorno escuro em volta, por baixo."""
    camada = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    desenho(camada)
    saida = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    for y in range(T):
        for x in range(T):
            if camada.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < T and 0 <= ny < T and camada.getpixel((nx, ny))[3] > 0:
                        saida.putpixel((x, y), CONTORNO)
                        break
    saida.alpha_composite(camada)
    im.alpha_composite(saida)


def fumaca(img):
    # três tufos cinza-azulados, do claro (em cima) ao escuro (embaixo)
    for cx, cy, r, cor in (
        (22.0, 8.0, 5.0, (176, 182, 196, 255)),
        (15.5, 11.0, 4.5, (150, 156, 172, 255)),
        (26.0, 14.0, 4.0, (138, 144, 160, 255)),
        (19.5, 15.0, 4.5, (118, 124, 142, 255)),
    ):
        disco(img, cx, cy, r, cor)
    for cx, cy, r in ((21.0, 6.5, 2.2), (14.5, 9.5, 1.8), (25.0, 12.5, 1.6)):  # brilho
        disco(img, cx, cy, r, (214, 218, 228, 255))


def bomba(img):
    disco(img, 12.0, 21.0, 8.5, (58, 56, 70, 255))
    disco(img, 12.0, 22.0, 6.5, (74, 72, 90, 255))
    disco(img, 9.5, 18.5, 2.3, (132, 132, 152, 255))  # brilho do ferro
    for x in range(5, 20):  # cinta
        for y in range(21, 23):
            if (x + 0.5 - 12.0) ** 2 + (y + 0.5 - 21.0) ** 2 <= 8.5**2:
                img.putpixel((x, y), (40, 38, 52, 255))
    for i in range(5):  # pavio, curvando para cima e para a direita
        img.putpixel((16 + i // 2, 14 - i), (186, 150, 96, 255))
        img.putpixel((17 + i // 2, 14 - i), (150, 116, 70, 255))


def faisca(img):
    cx, cy = 19, 8
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        img.putpixel((cx + dx, cy + dy), (255, 214, 90, 255))
    img.putpixel((cx, cy), (255, 250, 220, 255))
    for dx, dy in ((2, -1), (-2, 1), (1, -2), (-1, 2)):
        img.putpixel((cx + dx, cy + dy), (255, 150, 60, 255))


def main():
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    com_contorno(im, fumaca)
    com_contorno(im, bomba)
    faisca(im)
    # alfa duro: nada de meio-transparente
    for y in range(T):
        for x in range(T):
            r, g, b, a = im.getpixel((x, y))
            im.putpixel((x, y), (r, g, b, 255 if a >= 128 else 0))
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    im.save(SAIDA)
    print("salvo", os.path.normpath(SAIDA))


if __name__ == "__main__":
    main()

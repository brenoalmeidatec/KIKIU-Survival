"""Gera as coroas dos chefes da v2 (Devourer of Land e Devourer of Structure) em pixel art na grade de 1 px.

Antes, v2/chefe_visual.gd desenhava a coroa por código (polígonos multiplicados pela escala do chefe): no chefão (4x) cada "pixel" da
coroa tinha 4 px de tela e a gema era um bloco de 8 px. Agora a coroa é uma folha pequena desenhada JÁ no tamanho final, em escala 1 (um
pixel da arte é um pixel do mundo de 960x540), com contorno de 1 px, dois tons de luz e gemas com brilho de 1 px.

Arte PRÓPRIA, gerada por este script (nenhuma imagem de terceiros). Saída em jogos/hordas/projeto/assets/v2/chefes/:
    coroa_rei.png      57x45, ouro e gemas magenta (o Rei Espantalho, Devourer of Land)
    coroa_rainha.png   37x28, ouro pálido e gemas verdes (a Rainha Tecelã, Devourer of Structure)
Uso (a partir da raiz do repositório):  python jogos/hordas/fonte_arte/chefes_v2/gerar_coroas.py
Depois rode `godot --headless --path jogos/hordas/projeto --import` para criar os .import.
"""

import os
import sys

from PIL import Image

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
SAIDA = os.path.join(RAIZ, "jogos", "hordas", "projeto", "assets", "v2", "chefes")

T = (0, 0, 0, 0)


def cor(r, g, b):
    return (r, g, b, 255)


def desenhar(larg, alto, n, base_w, h_banda, h_grande, h_pequena, tam_gema, ouro, gema, contorno):
    """`n` pontas lado a lado (as pares, 0, 2, 4, altas; as ímpares baixas) sobre uma faixa, com uma gema na ponta de cada uma e uma
    gema no meio da faixa. `ouro` = (luz, meio, sombra, fundo); `gema` = (luz, meio, sombra)."""
    luz, meio, sombra, fundo = ouro
    g_luz, g_meio, g_sombra = gema
    im = [[T for _ in range(larg)] for _ in range(alto)]

    def pix(x, y, c):
        if 0 <= x < larg and 0 <= y < alto:
            im[y][x] = c

    y_banda = alto - 1 - h_banda  # a faixa ocupa as últimas h_banda linhas (e 1 linha de contorno embaixo)
    x0 = (larg - n * base_w) // 2
    topo_pontas = []
    # pontas: triângulos de base base_w que se estreitam até 1 px na ponta
    for k in range(n):
        h = h_grande if k % 2 == 0 else h_pequena
        cx = x0 + k * base_w + base_w // 2
        for r in range(h + 1):
            y = y_banda - r
            meia = int(round((base_w // 2) * (1.0 - r / float(h))))
            for x in range(cx - meia, cx + meia + 1):
                lado = x - cx
                if lado < 0 or (lado == 0 and r % 2 == 0):
                    c = luz if lado <= -meia + 1 or r > h * 0.55 else meio
                elif lado > 0:
                    c = sombra if lado >= meia - 1 else meio
                else:
                    c = meio
                pix(x, y, c)
        topo_pontas.append((cx, y_banda - h, h))
    # faixa: topo claro, meio, base sombreada, com pérolas de 1 px
    for y in range(y_banda, y_banda + h_banda):
        for x in range(x0, x0 + n * base_w):
            f = y - y_banda
            c = meio
            if f == 0:
                c = luz
            elif f >= h_banda - 2:
                c = sombra if f == h_banda - 2 else fundo
            pix(x, y, c)
    for x in range(x0 + 2, x0 + n * base_w - 2, 4):  # as pérolas (1 px claro com 1 px escuro embaixo)
        pix(x, y_banda + 2, luz)
        pix(x, y_banda + 3, sombra)

    def gema_px(cx, cy, d):
        """Gema de d x d com cantos cortados, luz no canto de cima e sombra embaixo."""
        for j in range(d):
            for i in range(d):
                canto = (i in (0, d - 1)) and (j in (0, d - 1))
                if canto and d >= 4:
                    continue
                c = g_meio
                if i + j <= 1 and not canto:
                    c = g_luz
                elif j >= d - 2 or i >= d - 1:
                    c = g_sombra
                pix(cx - d // 2 + i, cy - d // 2 + j, c)
        pix(cx - d // 2 + 1, cy - d // 2 + 1, g_luz)

    for cx, ytop, h in topo_pontas:  # gema na ponta
        gema_px(cx, ytop, tam_gema)
    gema_px(x0 + (n * base_w) // 2, y_banda + h_banda // 2, tam_gema)  # e uma no meio da faixa
    # contorno de 1 px (por fora de tudo que é opaco)
    pronto = [[im[y][x] for x in range(larg)] for y in range(alto)]
    for y in range(alto):
        for x in range(larg):
            if im[y][x][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < larg and 0 <= yy < alto and im[yy][xx][3] > 0:
                        pronto[y][x] = contorno
                        break
    out = Image.new("RGBA", (larg, alto), T)
    out.putdata([pronto[y][x] for y in range(alto) for x in range(larg)])
    return out


def main():
    os.makedirs(SAIDA, exist_ok=True)
    rei = desenhar(
        57, 45, 5, 11, 10, 26, 17, 5,
        (cor(255, 236, 150), cor(255, 209, 77), cor(204, 140, 34), cor(120, 66, 18)),
        (cor(255, 170, 220), cor(255, 51, 166), cor(150, 10, 92)),
        cor(40, 14, 30),
    )
    rei.save(os.path.join(SAIDA, "coroa_rei.png"))
    rainha = desenhar(
        37, 28, 5, 7, 6, 14, 9, 3,
        (cor(243, 255, 200), cor(217, 255, 140), cor(140, 190, 70), cor(70, 110, 40)),
        (cor(190, 255, 205), cor(51, 255, 89), cor(10, 140, 50)),
        cor(18, 42, 24),
    )
    rainha.save(os.path.join(SAIDA, "coroa_rainha.png"))
    print("coroas em", SAIDA, rei.size, rainha.size)


if __name__ == "__main__":
    sys.exit(main())

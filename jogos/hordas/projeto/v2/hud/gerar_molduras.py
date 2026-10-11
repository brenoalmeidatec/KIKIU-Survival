"""Gera as molduras e barras do HUD da v2 em pixel art (Pillow).

Uso (a partir de qualquer pasta): python gerar_molduras.py
Escreve os PNG ao lado deste script. Tudo é feito pixel a pixel, sem anti-aliasing e sem dithering, com
semente fixa: rodar de novo gera os mesmos arquivos.

Tamanhos são na resolução do mundo (960x540). As molduras são 9-patch: a margem (5 px) é o canto, que não estica;
o miolo das bordas repete em mosaico (NinePatchRect em TILE), então o pixel não vira borrão.

Paleta: docs/visual_2_5d/paleta.json (painel, borda, ouro, vida, fragmentos) mais tons de pedra e metal.
"""

import random
from pathlib import Path

from PIL import Image, ImageDraw

AQUI = Path(__file__).resolve().parent

# Pedra escura e metal (tons de pedra inventados a partir do painel #01030b e da borda #86898f).
PEDRA_A = (38, 38, 46, 255)
PEDRA_B = (46, 46, 55, 255)
PEDRA_C = (29, 29, 36, 255)
BISEL_CLARO = (74, 74, 88, 255)
BISEL_ESCURO = (16, 16, 22, 255)
CONTORNO = (8, 8, 12, 255)
METAL = (125, 134, 144, 255)  # borda #86898f, um pouco mais escura
METAL_CLARO = (196, 204, 212, 255)
METAL_ESCURO = (58, 64, 72, 255)
VERMELHO = (185, 33, 45, 255)  # vida #b9212d (paleta.json)
VERMELHO_CLARO = (226, 92, 98, 255)
VERMELHO_ESCURO = (98, 16, 24, 255)
OURO = (224, 188, 72, 255)  # ouro #e0bc48 (paleta.json)
OURO_CLARO = (250, 230, 156, 255)
OURO_ESCURO = (132, 104, 26, 255)
AZUL = (74, 163, 217, 255)
AZUL_CLARO = (210, 234, 255, 255)
AZUL_ESCURO = (29, 95, 143, 255)
VAZIO_ESCURO = (6, 6, 10, 255)
VAZIO = (22, 22, 30, 255)
PAINEL = (1, 3, 11, 205)  # painel #01030b, translúcido
FANTASMA_CLARO = (255, 240, 214, 255)  # barra fantasma do chefe: o dano recente que desce devagar
FANTASMA = (236, 206, 176, 255)
FANTASMA_ESCURO = (176, 134, 116, 255)


def moldura_pedra() -> Image.Image:
    """20x20: contorno, bisel, miolo de pedra em ruído e cantos de metal com rebite vermelho. Miolo translúcido (painel)."""
    rng = random.Random(20)
    img = Image.new("RGBA", (20, 20), PAINEL)
    px = img.load()
    # Miolo (x e y em 5..14) é o painel translúcido: fica como está.
    for y in range(20):
        for x in range(20):
            if 5 <= x <= 14 and 5 <= y <= 14:
                continue
            if x in (0, 19) or y in (0, 19):
                px[x, y] = CONTORNO
                continue
            if y < 5 or y > 14:  # faixa de cima ou de baixo
                if y == 1:
                    cor = BISEL_CLARO
                elif y == 4 or y == 15:
                    cor = BISEL_ESCURO
                elif y == 17 and 5 <= x <= 14:
                    cor = VERMELHO  # detalhe vermelho: filete no meio da faixa de baixo
                elif y == 18:
                    cor = PEDRA_C
                else:
                    cor = rng.choice([PEDRA_A, PEDRA_A, PEDRA_B, PEDRA_C])
            else:  # faixa da esquerda ou da direita
                if x == 1:
                    cor = BISEL_CLARO
                elif x in (4, 15):
                    cor = BISEL_ESCURO
                elif x == 18:
                    cor = BISEL_ESCURO
                else:
                    cor = rng.choice([PEDRA_A, PEDRA_A, PEDRA_B, PEDRA_C])
            px[x, y] = cor
    # Cantos: 5x5 de metal, desenhado uma vez (canto superior esquerdo) e espelhado.
    canto = Image.new("RGBA", (5, 5), METAL)
    cp = canto.load()
    for y in range(5):
        for x in range(5):
            if x == 0 or y == 0:
                cp[x, y] = CONTORNO
            elif x == 1 or y == 1:
                cp[x, y] = METAL_CLARO
            elif x == 4 or y == 4:
                cp[x, y] = METAL_ESCURO
    cp[2, 2] = VERMELHO
    cp[2, 1] = VERMELHO_CLARO
    cp[3, 3] = VERMELHO_ESCURO
    img.paste(canto, (0, 0))
    img.paste(canto.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (15, 0))
    img.paste(canto.transpose(Image.Transpose.FLIP_TOP_BOTTOM), (0, 15))
    img.paste(canto.transpose(Image.Transpose.ROTATE_180), (15, 15))
    return img


def barra(cores: list[tuple]) -> Image.Image:
    """3 colunas iguais (o miolo horizontal repete) e uma linha por cor, de cima para baixo. Margem 1 em volta."""
    img = Image.new("RGBA", (3, len(cores)), (0, 0, 0, 0))
    for y, cor in enumerate(cores):
        for x in range(3):
            img.putpixel((x, y), cor)
    return img


def selo() -> Image.Image:
    """24x24: moeda de nível, anel dourado e miolo escuro. O número vai por cima, num Label."""
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, 23, 23], fill=CONTORNO)
    d.ellipse([1, 1, 22, 22], fill=OURO_ESCURO)
    d.ellipse([2, 2, 21, 21], fill=OURO)
    d.ellipse([4, 4, 19, 19], fill=(16, 16, 24, 255))
    for x in range(7, 11):
        img.putpixel((x, 5), OURO_CLARO)
    img.putpixel((5, 7), OURO_CLARO)
    img.putpixel((5, 8), OURO_CLARO)
    return img


def moldura_faixa() -> Image.Image:
    """20x20: moldura da faixa de anúncio. Metal claro (o anúncio tinge por tipo com modulate), cantos cortados em degrau e miolo escuro translúcido."""
    img = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    px = img.load()
    for y in range(20):
        for x in range(20):
            dx = min(x, 19 - x)
            dy = min(y, 19 - y)
            s = dx + dy
            if s < 3:  # canto cortado: transparente
                continue
            if s == 3 or dx == 0 or dy == 0:
                px[x, y] = CONTORNO
            elif dx == 1 or dy == 1:
                px[x, y] = METAL_CLARO
            elif dx == 2 or dy == 2:
                px[x, y] = METAL
            elif dy == 3:
                px[x, y] = (40, 44, 56, 235)  # filete de luz no alto do miolo
            else:
                px[x, y] = PAINEL
    return img


def anel_luz() -> Image.Image:
    """20x20: anel de luz do pop de nível (círculo de 2 px, dourado claro). Cresce por escala no HUD."""
    img = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, 19, 19], outline=OURO_CLARO, width=2)
    return img


def main() -> None:
    saidas = {
        "moldura_pedra.png": moldura_pedra(),
        "barra_fundo.png": barra([VAZIO_ESCURO, VAZIO, VAZIO, VAZIO, VAZIO_ESCURO]),
        "barra_vida.png": barra([VERMELHO_CLARO, VERMELHO, VERMELHO, VERMELHO, VERMELHO, VERMELHO, VERMELHO_ESCURO]),
        "barra_xp.png": barra([OURO_CLARO, OURO, OURO, OURO, OURO, OURO, OURO_ESCURO]),
        "barra_folego.png": barra([AZUL_CLARO, AZUL, AZUL, AZUL_ESCURO]),
        "selo_nivel.png": selo(),
        "moldura_faixa.png": moldura_faixa(),
        "anel_luz.png": anel_luz(),
        "barra_fantasma.png": barra([FANTASMA_CLARO, FANTASMA, FANTASMA, FANTASMA_ESCURO, FANTASMA_ESCURO]),
    }
    for nome, img in saidas.items():
        img.save(AQUI / nome, optimize=False)
        print("ok", nome, img.size)


if __name__ == "__main__":
    main()

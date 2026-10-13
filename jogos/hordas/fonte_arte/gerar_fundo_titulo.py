"""Gera o fundo da tela de título da v2 (v2/menu_principal.tscn): a arte sem o título K.I.K.I.U, em 960x540.

Roda:  python gerar_fundo_titulo.py          (precisa de Pillow)
Entrada: fundo_titulo_fonte.webp (arte gerada no GPT pelo Alisson, 1672x941; o centro-superior e o centro-inferior são escuros,
         livres para o logo e o menu)
Saída:   ../projeto/assets/titulo/fundo.png

Mesmo pipeline do gerar_entrada.py (recorte 16:9, redução BOX, 48 cores com mediana de corte e sem dithering), só que no
tamanho da tela da v2 (960x540) e sem desenhar o título: o logo K.I.K.I.U e os botões são desenhados pelo Godot por cima.
A arte não tem grade de pixel fixa (conferido: a troca de cor não se concentra em nenhum resto de x ou y), por isso BOX e não NEAREST.
"""

import os

from PIL import Image

from gerar_entrada import recortar_16_9

AQUI = os.path.dirname(os.path.abspath(__file__))
FONTE = os.path.join(AQUI, "fundo_titulo_fonte.webp")
SAIDA = os.path.join(AQUI, "..", "projeto", "assets", "titulo", "fundo.png")

W, H = 960, 540
CORES = 48


def main():
    arte = recortar_16_9(Image.open(FONTE).convert("RGB"))
    img = arte.resize((W, H), Image.Resampling.BOX)
    img = img.quantize(colors=CORES, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    img.save(SAIDA, optimize=True)
    print(f"ok: {os.path.normpath(SAIDA)} ({W}x{H}, {CORES} cores)")


if __name__ == "__main__":
    main()

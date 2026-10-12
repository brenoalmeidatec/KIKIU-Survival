"""Gera o fundo da tela de título da v2 (v2/menu_principal.tscn): a arte da entrada, sem o título K.I.K.I.U, em 960x540.

Roda:  python gerar_fundo_titulo.py          (precisa de Pillow)
Entrada: entrada_fonte.webp (arte do Alisson, 1672x941, com a faixa escura vazia no terço de cima para o logo)
Saída:   ../projeto/assets/titulo/fundo.png

Mesmo pipeline do gerar_entrada.py (recorte 16:9, redução BOX, 48 cores com mediana de corte e sem dithering), só que no
tamanho da tela da v2 (960x540) e sem desenhar o título: o logo KIKILL e os botões são desenhados pelo Godot por cima.
"""

import os

from PIL import Image

from gerar_entrada import FONTE_ARTE, recortar_16_9

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.join(AQUI, "..", "projeto", "assets", "titulo", "fundo.png")

W, H = 960, 540
CORES = 48


def main():
    arte = recortar_16_9(Image.open(FONTE_ARTE).convert("RGB"))
    img = arte.resize((W, H), Image.Resampling.BOX)
    img = img.quantize(colors=CORES, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    img.save(SAIDA, optimize=True)
    print(f"ok: {os.path.normpath(SAIDA)} ({W}x{H}, {CORES} cores)")


if __name__ == "__main__":
    main()

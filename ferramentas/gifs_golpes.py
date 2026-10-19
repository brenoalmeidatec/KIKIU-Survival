"""Junta os quadros de testes/fotos/golpes_gif.tscn em GIFs ampliados 4x sem suavizar (vizinho mais próximo), a 30 quadros por segundo.

Uso: python -I ferramentas/gifs_golpes.py PASTA_DOS_QUADROS PASTA_DOS_GIFS
Cada subpasta de PASTA_DOS_QUADROS (uma por cena, com q000.png, q001.png...) vira PASTA_DOS_GIFS/<cena>.gif.
"""

import sys
from pathlib import Path

from PIL import Image

ESCALA = 4
MS_POR_QUADRO = 33  # os quadros saem a cada 2 passos de 1/60 s


def main() -> None:
    origem = Path(sys.argv[1])
    destino = Path(sys.argv[2])
    destino.mkdir(parents=True, exist_ok=True)
    for cena in sorted(p for p in origem.iterdir() if p.is_dir()):
        quadros = sorted(cena.glob("q*.png"))
        if not quadros:
            continue
        imgs = []
        for q in quadros:
            im = Image.open(q).convert("RGB")
            imgs.append(im.resize((im.width * ESCALA, im.height * ESCALA), Image.NEAREST))
        saida = destino / f"{cena.name}.gif"
        imgs[0].save(saida, save_all=True, append_images=imgs[1:], duration=MS_POR_QUADRO, loop=0, optimize=True)
        print(f"{saida} {len(imgs)} quadros {saida.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()

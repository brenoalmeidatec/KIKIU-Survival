"""ARTE PROVISORIA do LightWolf (LW-1, #511): recolor das folhas do Nick (mecha) e do Luke (lobo), sem Blender, ate a arte final do LW-7 chegar.

    python recolor.py            # gera lightwolf_mecha e lightwolf_lobo em projeto/prototipos/cara_nova/sprites/
    python recolor.py --prever   # tambem grava uma previa x3 de cada folha na pasta deste script (previa_*.png)

Precisa do Pillow (pip install pillow). Roda a partir de qualquer pasta. Nao mexe nas folhas de origem.

Mecha = folha do Nick (64x96, mesmos quadros, a marreta continua na mao: e provisorio): o azul do casaco e da cabeca da marreta viram o casco azul
claro; o metal e o capacete ficam quase brancos; a barba e o rosto viram o visor ciano; couro e cabo viram azul profundo; o dourado vira ciano.
Lobo = folha do Luke (32x44): tudo em tons de branco gelo, com a sombra azulada; so a luz do kunai fica branca pura.
Paleta do plano (notas/plano_2026-11-01.md, 3.2): casco #bfe4ff / #8cc6f0 / #3b6fa6, brilho ciano #7ff3ff, lobo #f4f8ff, contorno marinho #1d2c4a.
A normal e copiada sem mudar (a forma e a mesma). O json ganha "provisorio": true e "origem", para ninguem tomar isto por arte final.
"""
import colorsys
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

AQUI = Path(__file__).resolve().parent
SPRITES = AQUI.parents[2] / "projeto" / "prototipos" / "cara_nova" / "sprites"

CASCO = [(0x3B, 0x6F, 0xA6), (0x8C, 0xC6, 0xF0), (0xBF, 0xE4, 0xFF)]  # sombra, meio, luz
BRANCO = [(0x8C, 0xC6, 0xF0), (0xDD, 0xEE, 0xFF), (0xF4, 0xF8, 0xFF)]
VISOR = [(0x3B, 0x6F, 0xA6), (0x5F, 0xC8, 0xE8), (0x7F, 0xF3, 0xFF)]
MARINHO = [(0x1D, 0x2C, 0x4A), (0x2A, 0x45, 0x70), (0x3B, 0x6F, 0xA6)]
GELO = [(0x4A, 0x6E, 0xA0), (0xC4, 0xDC, 0xF4), (0xF4, 0xF8, 0xFF)]  # lobo: sombra azulada ate branco
CONTORNO = (0x1D, 0x2C, 0x4A)


def rampa(cores, v):
    """Cor na rampa de 3 tons para um brilho v em 0..1."""
    v = max(0.0, min(1.0, v))
    if v < 0.5:
        a, b, t = cores[0], cores[1], v / 0.5
    else:
        a, b, t = cores[1], cores[2], (v - 0.5) / 0.5
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def classe_mecha(h, s, v):
    """Qual rampa usar para um pixel da folha do Nick (h em graus, s e v em 0..1)."""
    if v < 0.2:
        return None  # contorno
    if s < 0.2:
        return BRANCO  # metal e capacete
    if 190 <= h <= 270:
        return CASCO  # casaco e cabeca da marreta
    if h <= 20 or h >= 340:
        return VISOR  # barba e rosto
    if 20 < h <= 60 and s > 0.55 and v > 0.55:
        return VISOR  # dourado
    return MARINHO  # couro, cabo, botas


def recolorir(origem, destino, classe):
    im = Image.open(origem).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            rampa_do_pixel = classe(h * 360, s, v)
            if rampa_do_pixel is None:
                px[x, y] = CONTORNO + (a,)
            else:
                px[x, y] = rampa(rampa_do_pixel, (v - 0.15) / 0.8) + (a,)
    im.save(destino)
    return im


def classe_lobo(h, s, v):
    if v < 0.2:
        return None
    return GELO


def gerar(origem_nome, destino_nome, classe, prever):
    for sufixo in ("_normal.png",):
        shutil.copyfile(SPRITES / (origem_nome + sufixo), SPRITES / (destino_nome + sufixo))
    info = json.loads((SPRITES / (origem_nome + ".json")).read_text(encoding="utf-8"))
    info["provisorio"] = True
    info["origem"] = origem_nome + " (recolor.py, LW-1; troca pela arte final do LW-7)"
    (SPRITES / (destino_nome + ".json")).write_text(json.dumps(info, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    im = recolorir(SPRITES / (origem_nome + "_albedo.png"), SPRITES / (destino_nome + "_albedo.png"), classe)
    if prever:
        w, h = info["quadro"]
        quadros = Image.new("RGBA", (w * 6, h * 2), (60, 60, 70, 255))
        for linha in range(2):
            for col in range(6):
                quadros.alpha_composite(im.crop((col * w, linha * h, (col + 1) * w, (linha + 1) * h)), (col * w, linha * h))
        quadros.resize((quadros.width * 3, quadros.height * 3), Image.NEAREST).save(AQUI / ("previa_" + destino_nome + ".png"))
    print("ok", destino_nome)


if __name__ == "__main__":
    prever = "--prever" in sys.argv
    gerar("nicao", "lightwolf_mecha", classe_mecha, prever)
    gerar("lucas", "lightwolf_lobo", classe_lobo, prever)

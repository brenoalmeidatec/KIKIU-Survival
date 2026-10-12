#!/usr/bin/env python3
"""Prévia dos brutos do Blender (fonte_arte/mapas_v2/brutos/<mapa>/): objetos lado a lado sobre cinza, com um boneco de 40 px de altura
(o Hazaki) como régua de escala. Uso: python previa_brutos.py <mapa> SAIDA.png [nomes...] [--esc=3] [--normal]"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

AQUI = Path(__file__).resolve().parent
args = [a for a in sys.argv[1:] if not a.startswith("--")]
opts = {a.split("=")[0]: (a.split("=")[1] if "=" in a else True) for a in sys.argv[1:] if a.startswith("--")}
mapa, saida, nomes = args[0], args[1], args[2:]
esc = int(opts.get("--esc", 3))
sufixo = "_n" if "--normal" in opts else ""
pasta = AQUI / "brutos" / mapa
arqs = sorted(p for p in pasta.glob("*.png") if not p.stem.endswith("_n") and p.stem != "piso")
if nomes:
    arqs = [p for p in arqs if p.stem in nomes]
itens = []
for p in arqs:
    im = Image.open(p.with_name(p.stem + sufixo + ".png")).convert("RGBA")
    box = im.getbbox() or (0, 0, im.width, im.height)
    itens.append((p.stem, im.crop(box)))
larg_max = 1500
x = y = lin = 0
pos = []
for nome, im in itens:
    w, h = im.width * esc + 14, im.height * esc + 30
    if x + w > larg_max:
        x, y, lin = 0, y + lin, 0
    pos.append((x, y))
    x += w
    lin = max(lin, h)
tela = Image.new("RGBA", (larg_max, y + lin + 10), (92, 96, 104, 255))
d = ImageDraw.Draw(tela)
for (nome, im), (x, y) in zip(itens, pos):
    g = im.resize((im.width * esc, im.height * esc), Image.NEAREST)
    tela.alpha_composite(g, (x + 6, y + 18))
    d.text((x + 6, y + 4), nome, fill=(255, 255, 255, 255))
# régua: 40 px de altura
d.rectangle((larg_max - 40, 6, larg_max - 40 + 14 * esc // 3, 6 + 40 * esc // 3), outline=(255, 200, 80, 255))
tela.convert("RGB").save(saida)
print(saida, tela.size)

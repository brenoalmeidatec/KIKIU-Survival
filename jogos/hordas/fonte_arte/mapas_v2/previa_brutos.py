#!/usr/bin/env python3
"""Prévia dos brutos do Blender (fonte_arte/mapas_v2/brutos/<mapa>/): objetos lado a lado sobre cinza, com um boneco de 40 px de altura
(o Hazaki) como régua de escala.

Uso: python previa_brutos.py <mapa> SAIDA.png [nomes...] [--esc=3] [--normal] [--final] [--heroi] [--luz] [--tabela]
  --normal  mostra o normal map no lugar do albedo
  --final   passa o objeto pelo mesmo tratamento do jogo (alfa binário, contorno, paleta curta): é o que o jogador vê
  --heroi   um Hazaki de 39 px ao lado de cada objeto, com os pés na frente da pegada (a régua de escala de verdade)
  --luz     luz de ponto laranja (como as do jogo) de cima/esquerda sobre o albedo + normal: mostra se o relevo faz sentido
  --tabela  (só cidade) imprime a tabela em markdown: tamanho final do sprite, pegada e fontes de luz de cada objeto; não gera imagem
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

AQUI = Path(__file__).resolve().parent
args = [a for a in sys.argv[1:] if not a.startswith("--")]
opts = {a.split("=")[0]: (a.split("=")[1] if "=" in a else True) for a in sys.argv[1:] if a.startswith("--")}
mapa, saida, nomes = args[0], args[1], args[2:]
esc = int(opts.get("--esc", 3))
sufixo = "_n" if "--normal" in opts else ""
pasta = AQUI / "brutos" / mapa
arqs = sorted(p for p in pasta.glob("*.png") if not p.stem.endswith("_n") and p.stem != "piso" and not p.stem.startswith("_"))
if nomes:
    arqs = [p for p in arqs if p.stem in nomes]
    arqs.sort(key=lambda p: nomes.index(p.stem))

proc = None
if "--final" in opts or "--luz" in opts:
    sys.path.insert(0, str(AQUI.parent))
    import gerar_v2_mapas as g
    proc = g.processar_objeto

heroi = None
if "--heroi" in opts:
    sp = AQUI.parent.parent / "projeto" / "prototipos" / "cara_nova" / "sprites" / "hazaki_albedo.png"
    folha = Image.open(sp).convert("RGBA").crop((0, 0, 32, 44))
    heroi = folha.crop(folha.getbbox())

try:
    sys.path.insert(0, str(AQUI))
    import importlib
    med = importlib.import_module("medidas_cidade") if mapa == "cidade" else None
except Exception:
    med = None


def luz(alb, nor, centro, raio=170.0, cor=(1.0, 0.62, 0.26), amb=(0.16, 0.2, 0.26), altura=40.0):
    """Luz de ponto 2D com normal map (o que o PointLight2D do Godot faz, em uma conta só): vetor da luz com a altura h."""
    a = np.asarray(alb.convert("RGB"), dtype=np.float32) / 255.0
    n = np.asarray(nor.convert("RGB"), dtype=np.float32) / 255.0 * 2.0 - 1.0
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = centro[0] - xx, centro[1] - yy
    dist = np.sqrt(dx * dx + dy * dy)
    lv = np.stack([dx, -dy, np.full_like(dx, altura)], axis=2)
    lv /= np.linalg.norm(lv, axis=2, keepdims=True)
    # o normal do jogo tem y para cima na tela (convenção do Blender): n.y positivo = voltado para cima
    nd = np.clip((n * lv).sum(axis=2), 0.0, 1.0)
    atenua = np.clip(1.0 - dist / raio, 0.0, 1.0) ** 1.4
    luz_ = (np.array(cor)[None, None, :] * (nd * atenua)[..., None] * 2.2) + np.array(amb)[None, None, :]
    out = np.clip(a * luz_ * 1.6, 0.0, 1.0)
    im = Image.fromarray((out * 255).astype(np.uint8), "RGB").convert("RGBA")
    im.putalpha(alb.getchannel("A"))
    return im


if "--tabela" in opts:
    sys.path.insert(0, str(AQUI.parent))
    import gerar_v2_mapas as g
    import medidas_cidade as md
    print("| objeto | sprite (px) | pegada (m) | luz |")
    print("|---|---|---|---|")
    for p in arqs:
        alb, _n, _o = g.processar_objeto(mapa, p.stem)
        m_ = md.MEDIDAS[p.stem]
        col = "%.2f x %.2f" % (m_["w"], m_["d"]) if m_["col"] else "passável"
        print("| `%s` | %d x %d | %s | %s |" % (p.stem, alb.width, alb.height, col, ", ".join(f["tipo"] for f in md.LUZES.get(p.stem, [])) or "-"))
    sys.exit(0)

itens = []
for p in arqs:
    nome = p.stem
    if proc is not None:
        alb, nor, orig = proc(mapa, nome)
        im = nor if "--normal" in opts else alb
        if "--luz" in opts:
            cx = alb.width * 0.5
            im = luz(alb, nor, (cx - alb.width * 0.15, -alb.height * 0.1 + 4))
        orig_rel = orig
    else:
        im = Image.open(p.with_name(p.stem + sufixo + ".png")).convert("RGBA")
        box = im.getbbox() or (0, 0, im.width, im.height)
        info = json.loads(p.with_suffix(".json").read_text())
        orig_rel = (info["origem"][0] - box[0], info["origem"][1] - box[1])
        im = im.crop(box)
    pe = (orig_rel[0], orig_rel[1] + (med.MEDIDAS[nome]["d"] * 11.315 if med and nome in med.MEDIDAS else 0.0))
    itens.append((nome, im, pe))

larg_max = 1500
x = y = lin = 0
pos = []
for nome, im, pe in itens:
    w, h = im.width * esc + 14, im.height * esc + 30
    if heroi is not None:
        w += (heroi.width + 6) * esc
        h = max(h, int(pe[1] * esc) + 30 + 6)
    if x + w > larg_max:
        x, y, lin = 0, y + lin, 0
    pos.append((x, y))
    x += w
    lin = max(lin, h)
tela = Image.new("RGBA", (larg_max, y + lin + 10), (92, 96, 104, 255))
d = ImageDraw.Draw(tela)
for (nome, im, pe), (x, y) in zip(itens, pos):
    g = im.resize((im.width * esc, im.height * esc), Image.NEAREST)
    tela.alpha_composite(g, (x + 6, y + 18))
    d.text((x + 6, y + 4), "%s %dx%d" % (nome, im.width, im.height), fill=(255, 255, 255, 255))
    if heroi is not None:
        hg = heroi.resize((heroi.width * esc, heroi.height * esc), Image.NEAREST)
        hx = x + 6 + im.width * esc + 6 * esc
        hy = y + 18 + int(pe[1] * esc) - hg.height + 1 * esc
        tela.alpha_composite(hg, (hx, max(y + 18, hy)))
if heroi is None:
    d.rectangle((larg_max - 40, 6, larg_max - 40 + 14 * esc // 3, 6 + 40 * esc // 3), outline=(255, 200, 80, 255))
tela.convert("RGB").save(saida)
print(saida, tela.size)

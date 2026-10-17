"""Monta a prancha de conferência do Golem (docs/visual_2_5d/golem/prancha.png) a partir da folha do jogo.

Chão escuro de floresta, vizinho do herói (40 px) para a escala, ampliado com vizinho mais próximo. Linhas = as 5 vistas, colunas =
8 de andar e 8 de ataque (o quadro do impacto leva a borda amarela). Uso: python prancha.py [fator]
"""
import json
import os
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto"))
DOCS = os.path.normpath(os.path.join(AQUI, "..", "..", "..", "..", "docs", "visual_2_5d", "golem"))
FATOR = int(sys.argv[1]) if len(sys.argv) > 1 else 2
CHAO = (34, 44, 32, 255)


def main():
    folha = Image.open(os.path.join(PROJETO, "assets", "v2", "armas", "golem_barro_dir.png")).convert("RGBA")
    with open(os.path.join(AQUI, "golem_barro_dir.json"), encoding="utf-8") as f:
        info = json.load(f)
    w, h = info["quadro"]
    andar, ataque = info["andar"], info["ataque"]
    cols = andar + ataque
    margem = 4
    rotulo = 14
    larg = cols * (w * FATOR + margem) + margem
    alt = len(info["linhas"]) * (h * FATOR + margem) + margem + rotulo
    prancha = Image.new("RGBA", (larg, alt), CHAO)
    d = ImageDraw.Draw(prancha)
    for c in range(cols):
        nome = ("andar %d" % c) if c < andar else ("ataque %d%s" % (c - andar, " IMPACTO" if c - andar == info["impacto"] else ""))
        d.text((margem + c * (w * FATOR + margem) + 2, 1), nome, fill=(230, 220, 170, 255))
    for r in range(len(info["linhas"])):
        for c in range(cols):
            q = folha.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)).resize((w * FATOR, h * FATOR), Image.NEAREST)
            x, y = margem + c * (w * FATOR + margem), rotulo + margem + r * (h * FATOR + margem)
            prancha.alpha_composite(q, (x, y))
            if c - andar == info["impacto"]:
                d.rectangle((x - 1, y - 1, x + w * FATOR, y + h * FATOR), outline=(255, 210, 60, 255))
    os.makedirs(DOCS, exist_ok=True)
    prancha.convert("RGB").save(os.path.join(DOCS, "prancha.png"))
    print("PRANCHA", prancha.size)


main()

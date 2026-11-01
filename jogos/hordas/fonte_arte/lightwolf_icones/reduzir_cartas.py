"""Reduz a folha A23 (cartas do LightWolf, LW-6) aos tamanhos dos ícones de carta do jogo.

Uso (da raiz do repositório): python jogos/hordas/fonte_arte/lightwolf_icones/reduzir_cartas.py

A folha tem 1448x1086 e só as 4 primeiras células preenchidas (Siphon, Wide Matrix, Rescue Cable, Lunar Dawn), mas os desenhos não caem na grade de 362 px:
o script acha cada um pelas colunas com alfa (um vão de pelo menos 12 px separa dois ícones). Para cada ícone, como em reduzir_icones.py: corta o halo de alfa baixo
(alfa < 160 vira 0), recorta pela caixa do objeto, encaixa no quadrado com a proporção mantida, reduz com média de caixa (BOX) com cor pré-multiplicada, endurece o alfa
(>= 128 vira 255) e centra no quadro. Saídas, por carta (id do dado em dados/v2_cartas.json):
  projeto/assets/v2/icones_cartas/<id>.png      32x32 (escolha, baú e slots da HUD)
  projeto/assets/v2/icones_cartas/16/<id>.png   16x16 (linha do card SUA BUILD)
  projeto/assets/gerado/<icone>.png             16x16 (o ícone antigo, reserva e teste de ícones únicos: o campo `icone` da carta)
E acrescenta as 4 entradas em projeto/assets/v2/icones_cartas/indice.json com "proprio": true (o gerar_objetos.py icones preserva essas entradas).
"""

import json
from pathlib import Path

from PIL import Image

AQUI = Path(__file__).resolve().parent
PROJETO = AQUI.parent.parent / "projeto"
FOLHA = AQUI / "A23_lw_cartas.png"
ICONES = PROJETO / "assets/v2/icones_cartas"
GERADO = PROJETO / "assets/gerado"
# (id da carta, categoria no índice, campo `icone` do dado); a ordem é a das células da folha
CARTAS = [
    ("sifao", "modificador", "icone_matriz_sifao"),
    ("ampla", "modificador", "icone_matriz_ampla"),
    ("cabo", "modificador", "icone_cabo_resgate"),
    ("aurora_lunar", "evolucao", None),
]
VAO = 12  # px sem alfa que separam dois ícones


def achar_icones(im: Image.Image) -> list[Image.Image]:
    a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    cols = [a.crop((x, 0, x + 1, im.height)).getbbox() is not None for x in range(im.width)]
    faixas: list[list[int]] = []
    for x, tem in enumerate(cols):
        if not tem:
            continue
        if faixas and x - faixas[-1][1] <= VAO:
            faixas[-1][1] = x
        else:
            faixas.append([x, x])
    assert len(faixas) == len(CARTAS), f"achei {len(faixas)} ícones na folha, esperava {len(CARTAS)}: {faixas}"
    return [im.crop((x0, 0, x1 + 1, im.height)) for x0, x1 in faixas]


def reduzir(im: Image.Image, tam: int, lado_max: int) -> Image.Image:
    im = im.convert("RGBA")
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v < 160 else v)
    im = Image.merge("RGBA", (r, g, b, a))
    im = im.crop(im.getchannel("A").getbbox())
    k = lado_max / max(im.size)
    novo = (max(1, round(im.width * k)), max(1, round(im.height * k)))
    pre = Image.new("RGBA", im.size)
    px, po = im.load(), pre.load()
    for y in range(im.height):
        for x in range(im.width):
            cr, cg, cb, ca = px[x, y]
            po[x, y] = (cr * ca // 255, cg * ca // 255, cb * ca // 255, ca)
    peq = pre.resize(novo, Image.BOX)
    saida = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    ox, oy = (tam - novo[0]) // 2, (tam - novo[1]) // 2
    ps, pq = saida.load(), peq.load()
    for y in range(novo[1]):
        for x in range(novo[0]):
            cr, cg, cb, ca = pq[x, y]
            if ca < 128:
                continue
            ps[ox + x, oy + y] = (min(255, cr * 255 // ca), min(255, cg * 255 // ca), min(255, cb * 255 // ca), 255)
    return saida


def main() -> None:
    folha = Image.open(FOLHA).convert("RGBA")
    icones = achar_icones(folha)
    (ICONES / "16").mkdir(parents=True, exist_ok=True)
    indice_arq = ICONES / "indice.json"
    indice = json.loads(indice_arq.read_text(encoding="utf-8"))
    for (cid, categoria, antigo), fonte in zip(CARTAS, icones):
        reduzir(fonte, 32, 30).save(ICONES / f"{cid}.png")
        pequeno = reduzir(fonte, 16, 15)
        pequeno.save(ICONES / "16" / f"{cid}.png")
        if antigo:
            pequeno.save(GERADO / f"{antigo}.png")
        indice["icones"][cid] = {"arquivo": f"{cid}.png", "pequeno": f"16/{cid}.png", "categoria": categoria, "proprio": True}
        print(f"{cid}: {fonte.size[0]}x{fonte.size[1]} -> 32x32 e 16x16")
    indice_arq.write_text(json.dumps(indice, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()

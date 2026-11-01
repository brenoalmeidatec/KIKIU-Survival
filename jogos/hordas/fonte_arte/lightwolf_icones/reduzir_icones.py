"""Reduz as fontes A19 (E mísseis), A22 (matriz), A20 (Q autodestruição) e A21 (Q chamar o mecha) do LightWolf ao tamanho do slot (32x32).

Uso (da raiz do repositório): python jogos/hordas/fonte_arte/lightwolf_icones/reduzir_icones.py

Passos: corta o halo de alfa baixo (alfa < 160 vira 0), recorta pela caixa do objeto, encaixa no quadrado
de 30 px com a proporção mantida, reduz com média de caixa (BOX), endurece o alfa (>= 128 vira 255) e
centra num quadro de 32x32. Saídas:
  projeto/assets/v2/secundario_s/lightwolf.png   (slot S: a matriz, v2/hud_habilidades.gd)
  projeto/assets/v2/habilidade_e/lightwolf.png   (slot E: os mísseis; ligado no LW-4)
  projeto/assets/v2/especial_q/lightwolf.png     (círculo do Q do mecha: a autodestruição; LW-5)
  projeto/assets/v2/especial_q/lightwolf_lobo.png (círculo do Q do Lobo: chamar o mecha; LW-5)
"""

from pathlib import Path

from PIL import Image

AQUI = Path(__file__).resolve().parent
PROJETO = AQUI.parent.parent / "projeto"
TAM = 32
LADO_MAX = 30
SAIDAS = {
    "A22_lw_matriz.png": PROJETO / "assets/v2/secundario_s/lightwolf.png",
    "A19_lw_misseis.png": PROJETO / "assets/v2/habilidade_e/lightwolf.png",
    "A20_lw_autodestruicao.png": PROJETO / "assets/v2/especial_q/lightwolf.png",
    "A21_lw_chamar_mecha.png": PROJETO / "assets/v2/especial_q/lightwolf_lobo.png",
}


def reduzir(fonte: Path, destino: Path) -> None:
    im = Image.open(fonte).convert("RGBA")
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v < 160 else v)
    im = Image.merge("RGBA", (r, g, b, a))
    caixa = im.getchannel("A").getbbox()
    im = im.crop(caixa)
    k = LADO_MAX / max(im.size)
    novo = (max(1, round(im.width * k)), max(1, round(im.height * k)))
    # pré-multiplica antes de reduzir para a cor das bordas não escurecer com o alfa zero
    pre = Image.new("RGBA", im.size)
    px, po = im.load(), pre.load()
    for y in range(im.height):
        for x in range(im.width):
            cr, cg, cb, ca = px[x, y]
            po[x, y] = (cr * ca // 255, cg * ca // 255, cb * ca // 255, ca)
    peq = pre.resize(novo, Image.BOX)
    saida = Image.new("RGBA", (TAM, TAM), (0, 0, 0, 0))
    ox, oy = (TAM - novo[0]) // 2, (TAM - novo[1]) // 2
    ps, pq = saida.load(), peq.load()
    for y in range(novo[1]):
        for x in range(novo[0]):
            cr, cg, cb, ca = pq[x, y]
            if ca < 128:
                continue
            ps[ox + x, oy + y] = (min(255, cr * 255 // ca), min(255, cg * 255 // ca), min(255, cb * 255 // ca), 255)
    destino.parent.mkdir(parents=True, exist_ok=True)
    saida.save(destino)
    print(f"{fonte.name} -> {destino.relative_to(PROJETO)} ({novo[0]}x{novo[1]} em {TAM}x{TAM})")


if __name__ == "__main__":
    for nome, destino in SAIDAS.items():
        reduzir(AQUI / nome, destino)

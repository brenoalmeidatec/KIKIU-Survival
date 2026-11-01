"""Reduz a fonte A17 (rosto do LightWolf, LW-7) ao tamanho dos rostos do jogo (52x52, como assets/personagens/hazaki/rosto.png).

Uso (da raiz do repositório): python jogos/hordas/fonte_arte/lightwolf_rosto/reduzir_rosto.py

Mesmo método de reduzir_icones.py: corta o halo de alfa baixo (alfa < 160 vira 0), recorta pela caixa do objeto,
encaixa com a proporção mantida no quadro de 50 px, reduz com média de caixa (BOX) com cor pré-multiplicada, endurece
o alfa (>= 128 vira 255) e centra num quadro de 52x52. Saída:
  projeto/assets/personagens/lightwolf/rosto.png (52x52 RGBA)
"""

from pathlib import Path

from PIL import Image

AQUI = Path(__file__).resolve().parent
PROJETO = AQUI.parent.parent / "projeto"
FONTE = AQUI / "A17_lw_rosto.png"
DESTINO = PROJETO / "assets/personagens/lightwolf/rosto.png"
TAM = 52
LADO_MAX = 50


def reduzir(fonte: Path, destino: Path) -> None:
    im = Image.open(fonte).convert("RGBA")
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v < 160 else v)
    im = Image.merge("RGBA", (r, g, b, a))
    im = im.crop(im.getchannel("A").getbbox())
    k = LADO_MAX / max(im.size)
    novo = (max(1, round(im.width * k)), max(1, round(im.height * k)))
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
    reduzir(FONTE, DESTINO)

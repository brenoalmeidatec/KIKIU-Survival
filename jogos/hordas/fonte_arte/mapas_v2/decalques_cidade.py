"""Decalques de chão exclusivos da cidade (Pillow, vistos de cima e achatados por sen 45 como os de kit_decalques.py): tampa de bueiro (fechada e aberta).
O def_cidade.py os põe em DECALQUES, por exemplo:  "bueiro": lambda rng: dc.bueiro(rng)  e  "bueiro_aberto": lambda rng: dc.bueiro(rng, aberto=True)."""
import math

from PIL import Image, ImageDraw

from kit_decalques import achatar, cor


def bueiro(rng, d=34, aberto=False):
    """Tampa de bueiro de ferro de ~1 m (d px de diâmetro antes de achatar): caixilho, aro, nervuras em cruz e em anel, ferrugem. Aberto: buraco preto
    com a tampa caída ao lado."""
    S = d + (34 if aberto else 12)
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    c = S / 2.0
    r = d / 2.0

    def disco(cx, cy, raio, fill=None, outline=None, largura=1):
        dr.ellipse((cx - raio, cy - raio, cx + raio, cy + raio), fill=fill, outline=outline, width=largura)

    disco(c, c, r + 2.5, fill=cor("14151a"))                        # caixilho de concreto escuro
    disco(c, c, r + 1.2, fill=cor("2a2c30"))
    if aberto:
        disco(c, c, r - 1.0, fill=cor("050607"))
        disco(c - 3, c - 4, r * 0.55, fill=cor("0a0c0e"))
        for k in range(5):   # degraus de ferro na parede do poço
            y = c + 1 + k * 3
            dr.line((c - 3, y, c + 3, y), fill=cor("3a3d42"))
        # a tampa, caída ao lado
        tx, ty = c + r * 1.05, c + r * 0.85
        disco(tx, ty, r * 0.78, fill=cor("34363a"), outline=cor("5a5d62"))
        for k in (-1, 0, 1):
            dr.line((tx - r * 0.55, ty + k * 4, tx + r * 0.55, ty + k * 4), fill=cor("232529"))
        return achatar(im)
    disco(c, c, r - 1.0, fill=cor("3d3f44"), outline=cor("62656b"))                    # tampa e aro
    disco(c, c, r * 0.72, outline=cor("2a2c30"))                                         # anel de nervuras
    disco(c, c, r * 0.4, outline=cor("2a2c30"))
    for ang in (0.0, math.pi / 4, math.pi / 2, 3 * math.pi / 4):                        # nervuras em cruz
        dx, dy = math.cos(ang) * (r - 3), math.sin(ang) * (r - 3)
        dr.line((c - dx, c - dy, c + dx, c + dy), fill=cor("2a2c30"), width=1)
    disco(c - 2, c - 3, r * 0.18, fill=cor("55585d"))                                    # brilho do ferro
    for _ in range(7):   # ferrugem e sujeira
        a, rr = rng.uniform(0, 6.28), rng.uniform(0.2, 0.85) * r
        x, y = c + math.cos(a) * rr, c + math.sin(a) * rr
        disco(x, y, rng.uniform(0.6, 1.4), fill=cor(rng.choice(["4a3022", "3a261a", "2a1f18"]), 170))
    return achatar(im)

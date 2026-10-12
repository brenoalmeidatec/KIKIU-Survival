"""Decalques de chão dos mapas novos da v2, desenhados em Pillow (manchas, poças, rachaduras, faixas, selos, cabos).

Tudo é desenhado "visto de cima" e depois achatado na vertical por sen(45) (ACHATA), para casar com a câmera 3/4 dos objetos. Cada função
devolve uma imagem RGBA; o gerador empacota e escreve decalques.png e decalques.json. As cores já saem levantadas (o jogo multiplica por
ganho_decalques). O alfa é quase binário: pixel art não tem borda macia, só uns degraus de alfa nas manchas.
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ACHATA = math.sin(math.radians(45.0))


def cor(h, a=255):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mais(c, k):
    """Clareia (k > 0) ou escurece (k < 0) uma cor RGBA em k * 255."""
    return tuple(max(0, min(255, int(v + k * 255))) for v in c[:3]) + (c[3],)


def achatar(im):
    return im.resize((im.width, max(2, int(round(im.height * ACHATA)))), Image.BOX)


def _mascara(w, h, rng, n=7, espalha=0.34, rugosidade=0.5):
    """Mancha irregular: união de elipses, suavizada e recortada com ruído (borda de pixel art, não de degradê)."""
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((w * 0.18, h * 0.18, w * 0.82, h * 0.82), fill=255)
    for _ in range(n):
        cx, cy = w * (0.5 + rng.uniform(-espalha, espalha)), h * (0.5 + rng.uniform(-espalha, espalha))
        rx, ry = w * rng.uniform(0.12, 0.3), h * rng.uniform(0.12, 0.3)
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(max(1.0, min(w, h) * 0.05)))
    a = np.asarray(m, dtype=np.float32) / 255.0
    ruido = np.array([[rng.random() for _ in range(w)] for _ in range(h)], dtype=np.float32)
    a = a + (ruido - 0.5) * rugosidade * 0.5
    return Image.fromarray(((a > 0.5) * 255).astype(np.uint8), "L")


def _pintar(mascara, c):
    im = Image.new("RGBA", mascara.size, (0, 0, 0, 0))
    solido = Image.new("RGBA", mascara.size, c)
    im.paste(solido, (0, 0), mascara)
    return im


def mancha(w, h, rng, base, claro=None, alfa=210):
    """Mancha de sujeira/óleo/sangue: miolo escuro, borda mais fraca (alfa em degraus)."""
    m = _mascara(w, h, rng)
    fora = _pintar(m, base[:3] + (int(alfa * 0.55),))
    dentro_m = m.filter(ImageFilter.MinFilter(5))
    dentro = _pintar(dentro_m, base[:3] + (alfa,))
    fora.alpha_composite(dentro)
    if claro is not None:
        pm = _mascara(max(4, w // 3), max(3, h // 3), rng, n=3)
        brilho = _pintar(pm, claro[:3] + (150,))
        fora.alpha_composite(brilho, (int(w * 0.22), int(h * 0.2)))
    return achatar(fora)


def poca(w, h, rng, agua, brilho, borda, alfa=235):
    """Poça: borda escura e molhada, água lisa por dentro e riscos de reflexo."""
    m = _mascara(w, h, rng, n=5, rugosidade=0.35)
    im = _pintar(m, borda[:3] + (alfa,))
    miolo = m.filter(ImageFilter.MinFilter(5))
    im.alpha_composite(_pintar(miolo, agua[:3] + (alfa,)))
    d = ImageDraw.Draw(im)
    for _ in range(3):
        x = rng.uniform(w * 0.3, w * 0.7)
        y = rng.uniform(h * 0.3, h * 0.6)
        d.line((x, y, x + rng.uniform(w * 0.1, w * 0.22), y - rng.uniform(1, 3)), fill=brilho[:3] + (210,), width=1)
    # só o que cai dentro da poça fica: recorta o reflexo pela máscara
    sai = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sai.paste(im, (0, 0), m)
    return achatar(sai)


def rachadura(w, h, rng, c, ramos=2):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    def cam(x, y, ang, comp, larg):
        for _ in range(comp):
            ang += rng.uniform(-0.55, 0.55)
            nx, ny = x + math.cos(ang) * rng.uniform(2, 4), y + math.sin(ang) * rng.uniform(1.5, 3)
            d.line((x, y, nx, ny), fill=c, width=larg)
            d.point((int(nx), int(ny) + 1), fill=mais(c, 0.12))
            x, y = nx, ny
            if not (0 <= x < w and 0 <= y < h):
                break

    cam(rng.uniform(0, w * 0.2), h * rng.uniform(0.3, 0.7), rng.uniform(-0.3, 0.3), int(w / 3.2), 1)
    for _ in range(ramos):
        cam(w * rng.uniform(0.25, 0.75), h * rng.uniform(0.3, 0.7), rng.uniform(-1.4, 1.4), int(w / 8), 1)
    return achatar(im)


def faixa_diagonal(w, h, c1, c2, passo, rng, desgaste=0.12):
    """Retângulo de listras diagonais (perigo), com falhas de tinta gasta."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y in range(h):
        for x in range(w):
            if rng.random() < desgaste:
                continue
            px[x, y] = c1 if ((x + y) // passo) % 2 == 0 else c2
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w - 1, 0), fill=mais(c2, -0.1))
    d.rectangle((0, h - 1, w - 1, h - 1), fill=mais(c2, -0.1))
    return achatar(im)


def seta(w, h, c, rng, desgaste=0.18):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cy = h / 2
    d.polygon([(w * 0.05, cy - h * 0.16), (w * 0.58, cy - h * 0.16), (w * 0.58, cy - h * 0.42), (w * 0.97, cy), (w * 0.58, cy + h * 0.42),
               (w * 0.58, cy + h * 0.16), (w * 0.05, cy + h * 0.16)], fill=c)
    px = im.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and rng.random() < desgaste:
                px[x, y] = (0, 0, 0, 0)
    return achatar(im)


def anel(d, esp, c, marcas, c2=None):
    """Selo circular (visto de cima): anel grosso, anel fino por dentro e marcas radiais."""
    im = Image.new("RGBA", (d, d), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    dr.ellipse((0, 0, d - 1, d - 1), outline=c, width=esp)
    dr.ellipse((esp * 2.2, esp * 2.2, d - 1 - esp * 2.2, d - 1 - esp * 2.2), outline=c2 or c, width=max(1, esp // 2))
    for k in range(marcas):
        a = k * 2 * math.pi / marcas
        r0, r1 = d / 2 - esp * 5.5, d / 2 - esp * 3.0
        dr.line((d / 2 + math.cos(a) * r0, d / 2 + math.sin(a) * r0, d / 2 + math.cos(a) * r1, d / 2 + math.sin(a) * r1), fill=c2 or c, width=max(1, esp // 2))
    return achatar(im)


def cabo(w, h, rng, c, conector=None):
    """Cabo grosso serpenteando no chão, com brilho em cima e sombra embaixo."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fase, amp = rng.uniform(0, 6), h * 0.32
    pts = [(x, h / 2 + math.sin(x / w * math.pi * rng.uniform(1.4, 2.6) + fase) * amp) for x in range(2, w - 2, 2)]
    d.line([(x, y + 1.5) for x, y in pts], fill=(10, 10, 12, 190), width=3)
    d.line(pts, fill=c, width=3)
    d.line([(x, y - 1) for x, y in pts], fill=mais(c, 0.16), width=1)
    if conector:
        d.rectangle((w - 7, pts[-1][1] - 3, w - 2, pts[-1][1] + 3), fill=conector)
    return achatar(im)


def grade(w, h, c, fundo, rng):
    im = Image.new("RGBA", (w, h), fundo)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w - 1, h - 1), outline=c, width=2)
    for x in range(5, w - 3, 5):
        d.line((x, 3, x, h - 4), fill=c, width=2)
    d.line((2, h - 3, w - 3, h - 3), fill=mais(fundo, -0.05), width=1)
    return achatar(im)


def papeis(w, h, rng, tons=("c4c8cc", "b0a98a", "9a9e92")):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for _ in range(rng.randint(4, 7)):
        pw, ph = rng.randint(8, 14), rng.randint(6, 10)
        pa = Image.new("RGBA", (pw, ph), cor(rng.choice(tons)))
        ImageDraw.Draw(pa).line((1, ph // 2, pw - 2, ph // 2), fill=(70, 74, 80, 255), width=1)
        pa = pa.rotate(rng.uniform(0, 360), expand=True, resample=Image.NEAREST)
        im.alpha_composite(pa, (rng.randint(0, max(0, w - pa.width)), rng.randint(0, max(0, h - pa.height))))
    return achatar(im)


def retangulo(w, h, c, borda=None, rng=None, desgaste=0.0):
    im = Image.new("RGBA", (w, h), c)
    if borda:
        ImageDraw.Draw(im).rectangle((0, 0, w - 1, h - 1), outline=borda, width=1)
    if rng and desgaste:
        px = im.load()
        for y in range(h):
            for x in range(w):
                if rng.random() < desgaste:
                    px[x, y] = (0, 0, 0, 0)
    return achatar(im)


def lajotas(w, h, rng, tons, rejunte):
    """Pedaço de calçada/ladrilho: grade de lajotas de tons variados com rejunte escuro."""
    im = Image.new("RGBA", (w, h), rejunte)
    d = ImageDraw.Draw(im)
    lado = 16
    for y in range(1, h - 1, lado):
        for x in range(1, w - 1, lado):
            c = rng.choice(tons)
            d.rectangle((x, y, min(w - 2, x + lado - 2), min(h - 2, y + lado - 2)), fill=c)
            d.line((x, y, min(w - 2, x + lado - 2), y), fill=mais(c, 0.05))
    return achatar(im)

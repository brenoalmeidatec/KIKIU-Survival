"""Gera a arte provisória do jogo de hordas (pixel art desenhada por código).

Roda:  python3 gerar_arte.py
Saída: ../projeto/assets/gerado/*.png

Cada inimigo vira uma folha com 3 quadros lado a lado: [normal, pulinho, branco (piscar ao apanhar)].
Ícones de cartas: 16x16.
"""
import math
import os
import random

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.join(AQUI, "..", "projeto", "assets", "gerado")
os.makedirs(SAIDA, exist_ok=True)

K = (26, 16, 32, 255)  # contorno


def salvar(img, nome):
    img.save(os.path.join(SAIDA, nome + ".png"))


def contorno(img, cor=K):
    """Põe contorno de 1 px em volta de tudo que não é transparente."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    o = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                        o[x, y] = cor
                        break
    return out


def branco(img):
    out = img.copy()
    p = out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if p[x, y][3] > 0:
                p[x, y] = (255, 255, 255, 255)
    return out


def folha(quadro):
    """[normal, pulinho de 1 px, branco]"""
    w, h = quadro.size
    f = Image.new("RGBA", (w * 3, h))
    f.paste(quadro, (0, 0))
    pulo = Image.new("RGBA", (w, h))
    pulo.paste(quadro.crop((0, 1, w, h)), (0, 0))
    f.paste(pulo, (w, 0))
    f.paste(branco(quadro), (w * 2, 0))
    return f


def olhos(d, x, y, dist=4, bravo=True):
    for ox in (0, dist):
        d.rectangle([x + ox, y, x + ox + 1, y + 1], fill=(255, 255, 255, 255))
        d.point((x + ox + (1 if ox == 0 else 0), y + 1), fill=K)
    if bravo:
        d.line([x - 1, y - 2, x + 1, y - 1], fill=K)
        d.line([x + dist + 2, y - 2, x + dist, y - 1], fill=K)


# ---------------- inimigos ----------------

def bug():
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    # perninhas
    for y in (7, 10, 13):
        d.line([1, y - 1, 4, y], fill=K)
        d.line([14, y - 1, 11, y], fill=K)
    d.line([5, 1, 6, 3], fill=K)
    d.line([10, 1, 9, 3], fill=K)
    d.ellipse([4, 3, 11, 7], fill=(46, 125, 50, 255))
    d.ellipse([3, 6, 12, 14], fill=(79, 191, 64, 255))
    d.line([7, 7, 7, 13], fill=(30, 90, 40, 255))
    d.point((5, 9), fill=(155, 229, 100, 255))
    d.point((10, 11), fill=(155, 229, 100, 255))
    d.point((5, 4), fill=(232, 59, 59, 255))
    d.point((9, 4), fill=(232, 59, 59, 255))
    return contorno(im)


def popup():
    im = Image.new("RGBA", (14, 13))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 12, 11], fill=(240, 240, 235, 255))
    d.rectangle([1, 1, 12, 3], fill=(40, 90, 200, 255))
    d.rectangle([10, 1, 12, 3], fill=(220, 50, 50, 255))
    d.point((11, 2), fill=(255, 255, 255, 255))
    olhos(d, 4, 6, 4)
    d.line([5, 9, 8, 9], fill=K)
    return contorno(im)


def spam():
    im = Image.new("RGBA", (16, 13))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 2, 14, 11], fill=(250, 230, 160, 255))
    d.line([1, 2, 7, 7], fill=(190, 150, 80, 255))
    d.line([14, 2, 8, 7], fill=(190, 150, 80, 255))
    olhos(d, 4, 7, 6)
    d.rectangle([6, 9, 9, 10], fill=(200, 40, 40, 255))
    return contorno(im)


def trojan(tam=22, cor=(130, 70, 170)):
    im = Image.new("RGBA", (tam + 4, tam + 4))
    d = ImageDraw.Draw(im)
    c = (tam + 4) / 2
    r = tam / 2 - 2
    for i in range(10):
        a = i * math.tau / 10
        x2, y2 = c + math.cos(a) * (r + 3), c + math.sin(a) * (r + 3)
        d.line([c, c, x2, y2], fill=tuple(int(v * 0.7) for v in cor) + (255,), width=2)
        d.ellipse([x2 - 1.5, y2 - 1.5, x2 + 1.5, y2 + 1.5], fill=(240, 90, 90, 255))
    d.ellipse([c - r, c - r, c + r, c + r], fill=cor + (255,))
    d.ellipse([c - r + 2, c - r + 2, c - r / 3, c - r / 3], fill=tuple(min(255, v + 50) for v in cor) + (255,))
    e = int(tam / 6)
    olhos(d, int(c - e - 1), int(c - 2), 2 * e + 1)
    d.arc([c - 4, c + 2, c + 4, c + 7], 200, 340, fill=K)
    return contorno(im)


def minerador():
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    d.ellipse([1, 3, 14, 15], fill=(240, 180, 40, 255))
    d.ellipse([3, 5, 12, 13], fill=(255, 210, 80, 255))
    d.text((5, 5), "B", fill=(170, 110, 20, 255))
    d.rectangle([2, 0, 13, 3], fill=(60, 60, 70, 255))  # capacete
    d.rectangle([7, 1, 8, 2], fill=(255, 255, 160, 255))
    return contorno(im)


def ransomware():
    im = Image.new("RGBA", (20, 22))
    d = ImageDraw.Draw(im)
    d.arc([4, 0, 15, 12], 180, 360, fill=(170, 170, 180, 255), width=3)
    d.rectangle([2, 7, 17, 20], fill=(200, 40, 50, 255))
    d.rectangle([3, 8, 16, 9], fill=(240, 90, 90, 255))
    olhos(d, 6, 11, 6)
    d.rectangle([8, 15, 11, 18], fill=(40, 10, 20, 255))
    return contorno(im)


def tela_azul():
    im = Image.new("RGBA", (44, 42))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 42, 30], fill=(60, 60, 70, 255))
    d.rectangle([4, 4, 39, 27], fill=(20, 80, 200, 255))
    d.text((8, 6), ":(", fill=(255, 255, 255, 255))
    for i in range(3):
        d.line([8, 18 + i * 3, 34 - i * 6, 18 + i * 3], fill=(170, 200, 255, 255))
    d.rectangle([18, 31, 25, 35], fill=(80, 80, 90, 255))
    d.rectangle([11, 35, 32, 37], fill=(80, 80, 90, 255))
    # pernas
    d.line([13, 37, 10, 41], fill=K, width=2)
    d.line([30, 37, 33, 41], fill=K, width=2)
    return contorno(im)


INIMIGOS = {
    "bug": bug(),
    "popup": popup(),
    "spam": spam(),
    "trojan": trojan(),
    "minerador": minerador(),
    "ransomware": ransomware(),
    "trojan_gigante": trojan(40, (110, 40, 150)),
    "tela_azul": tela_azul(),
}
for nome, q in INIMIGOS.items():
    salvar(folha(q), "inimigo_" + nome)


# ---------------- projéteis e objetos ----------------

def proj_pendrive():
    im = Image.new("RGBA", (10, 6))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 1, 6, 4], fill=(40, 120, 220, 255))
    d.rectangle([7, 2, 9, 3], fill=(200, 200, 210, 255))
    d.point((2, 2), fill=(255, 255, 255, 255))
    return im


def proj_ssd():
    im = Image.new("RGBA", (14, 8))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 11, 7], fill=(30, 30, 40, 255))
    d.rectangle([1, 1, 10, 6], fill=(120, 60, 220, 255))
    d.rectangle([12, 2, 13, 5], fill=(240, 200, 60, 255))
    d.text((2, -2), "5", fill=(255, 255, 255, 255))
    return im


def proj_email():
    im = Image.new("RGBA", (8, 6))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 7, 5], fill=(255, 240, 200, 255))
    d.line([0, 0, 3, 3], fill=(200, 60, 60, 255))
    d.line([7, 0, 4, 3], fill=(200, 60, 60, 255))
    return contorno(im)


def proj_cadeado():
    im = Image.new("RGBA", (8, 9))
    d = ImageDraw.Draw(im)
    d.arc([1, 0, 6, 6], 180, 360, fill=(220, 220, 230, 255), width=2)
    d.rectangle([0, 4, 7, 8], fill=(240, 80, 80, 255))
    return im


def helice(cor=(90, 200, 255), grande=False):
    t = 16 if grande else 12
    im = Image.new("RGBA", (t, t))
    d = ImageDraw.Draw(im)
    c = t / 2
    for i in range(4):
        a = i * math.tau / 4
        x, y = c + math.cos(a) * c * 0.75, c + math.sin(a) * c * 0.75
        d.ellipse([x - 2.5, y - 2.5, x + 2.5, y + 2.5], fill=cor + (255,))
    d.ellipse([c - 2, c - 2, c + 2, c + 2], fill=(60, 60, 70, 255))
    return contorno(im)


def gema(cor, t=5):
    im = Image.new("RGBA", (t + 2, t + 2))
    d = ImageDraw.Draw(im)
    c = (t + 1) / 2
    d.polygon([(c, 0), (t + 1, c), (c, t + 1), (0, c)], fill=cor + (255,))
    d.point((int(c) - 1, int(c) - 1), fill=(255, 255, 255, 255))
    return im


def bau():
    im = Image.new("RGBA", (18, 15))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 4, 16, 13], fill=(160, 100, 40, 255))
    d.rectangle([1, 1, 16, 5], fill=(190, 125, 55, 255))
    d.rectangle([1, 5, 16, 6], fill=(240, 200, 60, 255))
    d.rectangle([7, 4, 10, 8], fill=(240, 200, 60, 255))
    return contorno(im)


def marmita():
    im = Image.new("RGBA", (12, 9))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 2, 11, 8], fill=(200, 200, 205, 255))
    d.rectangle([0, 1, 11, 3], fill=(230, 230, 235, 255))
    d.rectangle([3, 4, 8, 6], fill=(240, 140, 60, 255))
    return contorno(im)


def wifi_pickup():
    im = Image.new("RGBA", (12, 10))
    d = ImageDraw.Draw(im)
    for r, cor in ((5, (80, 200, 255)), (3, (120, 220, 255))):
        d.arc([6 - r, 8 - r, 6 + r, 8 + r], 220, 320, fill=cor + (255,), width=2)
    d.rectangle([5, 7, 6, 8], fill=(255, 255, 255, 255))
    return contorno(im)


def tomada():
    im = Image.new("RGBA", (16, 18))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 14, 16], fill=(235, 235, 230, 255))
    d.ellipse([3, 4, 12, 13], fill=(200, 200, 195, 255))
    d.rectangle([5, 7, 6, 9], fill=K)
    d.rectangle([9, 7, 10, 9], fill=K)
    d.rectangle([7, 11, 8, 12], fill=K)
    return contorno(im)


salvar(proj_pendrive(), "proj_pendrive")
salvar(proj_ssd(), "proj_ssd")
salvar(proj_email(), "proj_email")
salvar(proj_cadeado(), "proj_cadeado")
salvar(helice(), "proj_ventoinha")
salvar(helice((120, 255, 200), True), "proj_water_cooler")
salvar(gema((70, 160, 255)), "gema_1")
salvar(gema((80, 230, 120), 6), "gema_2")
salvar(gema((255, 80, 90), 7), "gema_3")
salvar(bau(), "bau")
salvar(marmita(), "marmita")
salvar(wifi_pickup(), "wifi")
salvar(tomada(), "tomada")


# ---------------- chão ----------------

def chao():
    rnd = random.Random(7)
    t = 32
    im = Image.new("RGBA", (t * 4, t * 4))
    d = ImageDraw.Draw(im)
    for ty in range(4):
        for tx in range(4):
            base = (196, 186, 166) if (tx + ty) % 2 == 0 else (186, 176, 158)
            x0, y0 = tx * t, ty * t
            d.rectangle([x0, y0, x0 + t - 1, y0 + t - 1], fill=base + (255,))
            for _ in range(10):
                px, py = x0 + rnd.randrange(2, t - 2), y0 + rnd.randrange(2, t - 2)
                v = rnd.choice((-10, -6, 6))
                d.point((px, py), fill=tuple(max(0, min(255, c + v)) for c in base) + (255,))
            d.line([x0, y0 + t - 1, x0 + t - 1, y0 + t - 1], fill=(150, 140, 125, 255))
            d.line([x0 + t - 1, y0, x0 + t - 1, y0 + t - 1], fill=(150, 140, 125, 255))
            d.line([x0, y0, x0 + t - 2, y0], fill=(210, 202, 184, 255))
    # uma rachadura e uma mancha de café pra quebrar a repetição
    d.line([40, 70, 46, 76, 44, 82], fill=(140, 130, 115, 255))
    d.ellipse([90, 20, 98, 25], fill=(150, 120, 90, 255))
    return im


salvar(chao(), "chao")


def deco():
    """Enfeites espalhados pelo chão (sem colisão): planta, lixeira, cadeira caída, papel."""
    planta = Image.new("RGBA", (14, 18))
    d = ImageDraw.Draw(planta)
    d.rectangle([3, 11, 10, 17], fill=(170, 90, 50, 255))
    for x, y in ((2, 4), (7, 1), (11, 5), (5, 7), (9, 8)):
        d.ellipse([x - 2, y - 2, x + 3, y + 4], fill=(60, 150, 60, 255))
    lixeira = Image.new("RGBA", (10, 12))
    d = ImageDraw.Draw(lixeira)
    d.rectangle([1, 2, 8, 11], fill=(60, 110, 200, 255))
    d.rectangle([0, 1, 9, 2], fill=(80, 130, 220, 255))
    papel = Image.new("RGBA", (8, 6))
    d = ImageDraw.Draw(papel)
    d.polygon([(0, 1), (6, 0), (7, 5), (1, 5)], fill=(245, 245, 240, 255))
    d.line([2, 2, 5, 2], fill=(150, 150, 160, 255))
    cadeira = Image.new("RGBA", (14, 12))
    d = ImageDraw.Draw(cadeira)
    d.rectangle([1, 4, 12, 7], fill=(40, 80, 160, 255))
    d.rectangle([9, 0, 12, 7], fill=(40, 80, 160, 255))
    d.line([2, 8, 2, 11], fill=(90, 90, 100, 255))
    d.line([11, 8, 11, 11], fill=(90, 90, 100, 255))
    w = sum(i.width for i in (planta, lixeira, papel, cadeira)) + 3
    f = Image.new("RGBA", (w, 18))
    x = 0
    for i in (planta, lixeira, papel, cadeira):
        f.paste(contorno(i), (x, 18 - i.height))
        x += i.width + 1
    return f


salvar(deco(), "deco")


# ---------------- ícones 16x16 das cartas ----------------

def icone(desenho, fundo=None):
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    desenho(d)
    return contorno(im)


def i_pendrive(d):
    d.rectangle([2, 5, 10, 11], fill=(40, 120, 220, 255))
    d.rectangle([11, 6, 14, 10], fill=(200, 200, 210, 255))
    d.rectangle([12, 7, 13, 7], fill=K)
    d.point((4, 7), fill=(255, 255, 255, 255))


def i_ssd(d):
    d.rectangle([1, 3, 13, 12], fill=(30, 30, 40, 255))
    d.rectangle([2, 4, 12, 11], fill=(120, 60, 220, 255))
    d.rectangle([14, 6, 14, 9], fill=(240, 200, 60, 255))
    d.text((3, 3), "SSD", fill=(255, 255, 255, 255))


def i_cabo(d):
    d.line([2, 13, 5, 8, 9, 10, 12, 4], fill=(240, 200, 60, 255), width=2)
    d.rectangle([11, 1, 14, 5], fill=(220, 220, 225, 255))
    d.point((12, 3), fill=(240, 200, 60, 255))


def i_fibra(d):
    for i, cor in enumerate(((255, 80, 200), (120, 220, 255), (255, 240, 120))):
        d.line([1, 14 - i, 6, 8 - i, 10, 10 - i, 14, 2 + i], fill=cor + (255,))
    d.ellipse([11, 0, 15, 4], fill=(255, 255, 255, 255))


def i_ventoinha(d):
    d.rectangle([1, 1, 14, 14], fill=(60, 60, 70, 255))
    for i in range(4):
        a = i * math.tau / 4 + 0.4
        x, y = 7.5 + math.cos(a) * 4, 7.5 + math.sin(a) * 4
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(90, 200, 255, 255))
    d.ellipse([6, 6, 9, 9], fill=(200, 200, 210, 255))


def i_water(d):
    d.rectangle([1, 1, 14, 14], fill=(30, 30, 40, 255))
    d.ellipse([2, 2, 13, 13], fill=(255, 60, 160, 255))
    d.ellipse([4, 4, 11, 11], fill=(120, 255, 200, 255))
    d.ellipse([6, 6, 9, 9], fill=(30, 30, 40, 255))


def i_cafe(d):
    d.rectangle([3, 5, 11, 13], fill=(240, 240, 235, 255))
    d.rectangle([4, 6, 10, 8], fill=(110, 60, 30, 255))
    d.arc([9, 7, 14, 12], 270, 90, fill=(240, 240, 235, 255), width=2)
    d.line([5, 1, 6, 3], fill=(200, 200, 200, 255))
    d.line([8, 1, 9, 3], fill=(200, 200, 200, 255))


def i_garrafa(d):
    d.rectangle([4, 4, 11, 14], fill=(200, 40, 50, 255))
    d.rectangle([5, 1, 10, 4], fill=(40, 40, 50, 255))
    d.rectangle([5, 7, 10, 10], fill=(240, 240, 235, 255))
    d.text((5, 6), "C", fill=(110, 60, 30, 255))


def i_wifi(d):
    for r in (6, 4, 2):
        d.arc([8 - r, 12 - r, 8 + r, 12 + r], 220, 320, fill=(80, 200, 255, 255), width=2)
    d.rectangle([7, 11, 8, 12], fill=(255, 255, 255, 255))


def i_roteador(d):
    d.rectangle([1, 8, 14, 13], fill=(40, 40, 50, 255))
    for x in (3, 7, 11):
        d.line([x, 8, x - 1, 1], fill=(40, 40, 50, 255), width=1)
    for x in (4, 7, 10):
        d.point((x, 10), fill=(80, 255, 120, 255))
    d.text((9, 0), "5G", fill=(255, 240, 80, 255))


def i_energetico(d):
    d.rectangle([4, 2, 11, 14], fill=(40, 40, 50, 255))
    d.rectangle([5, 3, 10, 4], fill=(180, 180, 190, 255))
    d.polygon([(9, 5), (6, 9), (8, 9), (6, 13), (10, 8), (8, 8)], fill=(120, 255, 80, 255))


def i_overclock(d):
    d.rectangle([2, 2, 13, 13], fill=(40, 120, 60, 255))
    d.rectangle([4, 4, 11, 11], fill=(30, 30, 40, 255))
    for i in range(3, 13, 3):
        d.point((i, 0), fill=(240, 200, 60, 255))
        d.point((i, 15), fill=(240, 200, 60, 255))
    d.polygon([(8, 3), (6, 8), (8, 8), (7, 12), (10, 7), (8, 7)], fill=(255, 120, 40, 255))


def i_monitor(d):
    d.rectangle([0, 2, 15, 10], fill=(40, 40, 50, 255))
    d.rectangle([1, 3, 14, 9], fill=(90, 170, 255, 255))
    d.rectangle([6, 11, 9, 12], fill=(60, 60, 70, 255))
    d.rectangle([4, 13, 11, 13], fill=(60, 60, 70, 255))


def i_ctrlc(d):
    d.rectangle([1, 3, 7, 9], fill=(230, 230, 235, 255))
    d.text((2, 2), "C", fill=K)
    d.rectangle([8, 7, 14, 13], fill=(230, 230, 235, 255))
    d.text((9, 6), "V", fill=K)


def i_tenis(d):
    d.polygon([(1, 8), (6, 8), (9, 4), (12, 9), (15, 10), (15, 13), (1, 13)], fill=(240, 240, 235, 255))
    d.rectangle([1, 12, 15, 13], fill=(220, 50, 50, 255))
    d.line([7, 8, 10, 8], fill=(40, 100, 200, 255))


def i_marmita(d):
    d.rectangle([1, 5, 14, 13], fill=(200, 200, 205, 255))
    d.rectangle([1, 4, 14, 6], fill=(230, 230, 235, 255))
    d.rectangle([3, 7, 7, 11], fill=(245, 245, 240, 255))
    d.rectangle([8, 7, 12, 11], fill=(120, 70, 30, 255))
    d.point((10, 9), fill=(80, 160, 60, 255))


def i_antena(d):
    d.line([7, 4, 7, 14], fill=(170, 170, 180, 255), width=2)
    d.ellipse([5, 1, 10, 6], fill=(220, 50, 50, 255))
    d.arc([1, 0, 14, 10], 200, 340, fill=(80, 200, 255, 255))


def i_fitinha(d):
    """Ímã de Almas: ímã em U (vermelho e azul, pontas prateadas) com almas azuis em volta."""
    d.rectangle([2, 2, 13, 12], fill=(200, 50, 50, 255))
    d.rectangle([10, 2, 13, 12], fill=(50, 110, 220, 255))
    d.rectangle([6, 2, 9, 9], fill=(0, 0, 0, 0))   # o vão do U
    d.rectangle([2, 2, 5, 3], fill=(200, 200, 210, 255))
    d.rectangle([10, 2, 13, 3], fill=(200, 200, 210, 255))
    d.ellipse([0, 8, 2, 10], fill=(170, 240, 255, 255))
    d.ellipse([14, 4, 15, 6], fill=(170, 240, 255, 255))
    d.point((7, 14), fill=(170, 240, 255, 255))


def i_vento_sopro(d):
    """Sopro Ágil: três rajadas de vento com a ponta enrolada."""
    c = (170, 235, 255, 255)
    d.line([1, 4, 10, 4], fill=c, width=1)
    d.arc([9, 2, 14, 7], 270, 90, fill=c, width=1)
    d.line([3, 8, 12, 8], fill=c, width=1)
    d.arc([11, 6, 15, 10], 270, 90, fill=c, width=1)
    d.line([1, 12, 8, 12], fill=c, width=1)
    d.arc([6, 10, 11, 14], 270, 90, fill=c, width=1)
    d.point((2, 2), fill=(255, 230, 90, 255))   # faíscas de velocidade


def i_brasa_coracao(d):
    """Coração de Brasa: coração vermelho com miolo de brasa e fagulhas."""
    d.polygon([(8, 14), (1, 6), (3, 2), (6, 2), (8, 4), (10, 2), (13, 2), (15, 6)], fill=(205, 50, 45, 255))
    d.polygon([(8, 12), (4, 7), (5, 5), (7, 5), (8, 6), (9, 5), (11, 5), (12, 7)], fill=(255, 140, 40, 255))
    d.polygon([(8, 10), (6, 8), (8, 7), (10, 8)], fill=(255, 220, 90, 255))
    d.point((1, 0), fill=(255, 200, 60, 255))
    d.point((14, 1), fill=(255, 200, 60, 255))
    d.point((15, 11), fill=(255, 200, 60, 255))


def i_coco(d):
    d.ellipse([2, 3, 13, 14], fill=(90, 170, 60, 255))
    d.ellipse([4, 5, 10, 10], fill=(140, 210, 90, 255))
    d.line([9, 0, 7, 6], fill=(240, 80, 120, 255), width=2)


def i_apostila(d):
    d.rectangle([2, 1, 13, 14], fill=(240, 240, 230, 255))
    d.rectangle([2, 1, 4, 14], fill=(40, 90, 200, 255))
    for y in (4, 7, 10):
        d.line([6, y, 11, y], fill=(120, 120, 130, 255))


def i_mouse(d):
    d.rounded_rectangle([3, 1, 12, 14], radius=4, fill=(40, 40, 50, 255))
    d.rectangle([7, 1, 8, 6], fill=(120, 120, 140, 255))
    d.rectangle([3, 6, 12, 6], fill=(120, 120, 140, 255))
    d.rectangle([7, 3, 8, 5], fill=(255, 60, 90, 255))
    d.point((4, 10), fill=(255, 60, 90, 255))
    d.point((11, 10), fill=(60, 220, 255, 255))


def i_vida(d):
    d.polygon([(8, 14), (1, 6), (3, 2), (6, 2), (8, 4), (10, 2), (13, 2), (15, 6)], fill=(230, 50, 70, 255))


def i_moeda(d):
    d.ellipse([2, 2, 13, 13], fill=(240, 200, 60, 255))
    d.ellipse([4, 4, 11, 11], fill=(255, 225, 110, 255))
    d.text((5, 3), "$", fill=(170, 120, 20, 255))


ICONES = {
    "pendrive": i_pendrive, "ssd": i_ssd, "cabo_rede": i_cabo, "fibra_optica": i_fibra,
    "ventoinha": i_ventoinha, "water_cooler": i_water, "cafe": i_cafe, "garrafa_termica": i_garrafa,
    "wifi": i_wifi, "roteador_5g": i_roteador,
    "energetico": i_energetico, "overclock": i_overclock, "monitor": i_monitor, "ctrl_c_v": i_ctrlc,
    "tenis": i_tenis, "marmita": i_marmita, "antena": i_antena, "fitinha": i_fitinha,
    "agua_coco": i_coco, "mouse": i_mouse, "apostila": i_apostila, "vida": i_vida, "moeda": i_moeda,
    "vento_sopro": i_vento_sopro, "brasa_coracao": i_brasa_coracao,
}
for nome, fn in ICONES.items():
    salvar(icone(fn), "icone_" + nome)

print("arte gerada em", os.path.normpath(SAIDA))

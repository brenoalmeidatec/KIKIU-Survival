#!/usr/bin/env python3
"""Escudos de verdade, um por personagem (PR "escudos reais", #467). Arte propria, desenhada por script (Python + PIL), sem imagem de terceiros.

Cada escudo vira uma faixa em projeto/assets/v2/escudos/<arquivo>.png:
  0 frente   1 lado (3/4, estreito)   2 costas (alca, tabuas, couro)   3 rachado   4..7 os quatro pedacos da quebra (mesma posicao da frente)
Faixas de 32 px (hazaki, lucas, matheus): 256x32, 8 celulas. Faixa M do Nick (nicao_m.png, DEF-4a): celulas de 48 px, 12 celulas (576x48):
  as 8 de cima e, a partir da 8, a camada 1 (nivel 6 do Nick): 8 frente, 9 lado, 10 costas, 11 rachado, com aro de reforco.
O centro do escudo fica no centro da celula. Luz de cima-esquerda, contorno de 1 px, 4 tons por material.

Uso:  python gerar_escudos.py [saida_dir] [--previa arquivo.png]
      (padrao: ../../projeto/assets/v2/escudos). Imprime os centroides dos pedacos (vao para dados/v2_secundario.json > escudo > visual).
Ids: hazaki (tate de laca vermelha com mon dourado), nicao (redondo de ferro rebitado e amassado), lucas (broquel de couro e bronze),
matheus (escudo de laca azul em gota com um sino, a assinatura dele; joga com o kit do Hazaki mas tem a propria folha de sprites).
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

C = 32  # celula em px (muda por faixa, em ESCUDOS, com usar())
F = 1.0  # zoom: uma unidade de desenho (celula de 32) vira F px; a celula de 32 usa F = 1, entao o desenho e o mesmo de antes
SS = 4  # supersampling das formas (so para curvas boas; o resultado e binario)


def P(v):
    """Coordenada de desenho (sobre a celula de 32, centro em 16) para px da celula atual (centro em C/2, escala F)."""
    return C / 2.0 + (v - 16.0) * F


def usar(celula, zoom):
    """Escolhe a celula e o zoom das proximas faixas."""
    global C, F
    C, F = celula, zoom
CELULAS = ["frente", "lado", "costas", "rachado", "frag0", "frag1", "frag2", "frag3"]


def hexa(s):
    s = s.lstrip("#")
    return tuple(int(s[i : i + 2], 16) for i in (0, 2, 4)) + (255,)


# ---------------------------------------------------------------- formas (mascaras binarias)
def forma(fn, sx=1.0):
    """fn(d, f) desenha numa imagem 'L' de (C*SS) px; f(x,y) converte coordenadas da celula (x espremido por sx em torno de 16)."""
    im = Image.new("L", (C * SS, C * SS), 0)
    d = ImageDraw.Draw(im)

    def f(x, y):
        return (P(16 + (x - 16) * sx) * SS, P(y) * SS)

    fn(d, f)
    return im.resize((C, C), Image.BOX).point(lambda v: 255 if v >= 128 else 0)


def poligono(pts):
    return lambda d, f: d.polygon([f(*p) for p in pts], fill=255)


def elipse(cx, cy, rx, ry):
    return lambda d, f: d.ellipse([*f(cx - rx, cy - ry), *f(cx + rx, cy + ry)], fill=255)


def retangulo(x0, y0, x1, y1):
    return lambda d, f: d.rectangle([*f(x0, y0), *f(x1, y1)], fill=255)


def uniao(*fns):
    def g(d, f):
        for fn in fns:
            fn(d, f)

    return g


def sub(a, b):
    return ImageChops.subtract(a, b)


def e(a, b):
    return ImageChops.multiply(a, b).point(lambda v: 255 if v > 0 else 0)


def desloca(m, dx, dy):
    return ImageChops.offset(m, dx, dy)


def borda_sombra(m, n=1):
    """Faixa de n px no lado de baixo-direita (longe da luz)."""
    return sub(m, desloca(m, -n, -n))


def borda_luz(m, n=1):
    return sub(m, desloca(m, n, n))


# ---------------------------------------------------------------- tela
class Tela:
    def __init__(self):
        self.im = Image.new("RGBA", (C, C), (0, 0, 0, 0))

    def pintar(self, mascara, cor, dentro=None):
        if dentro is not None:
            mascara = e(mascara, dentro)
        self.im.paste(Image.new("RGBA", (C, C), cor), (0, 0), mascara)

    def pixel(self, x, y, cor, dentro=None):
        x, y = round(P(x)), round(P(y))
        if 0 <= x < C and 0 <= y < C and (dentro is None or dentro.getpixel((x, y))):
            self.im.putpixel((x, y), cor)

    def linha(self, pts, cor, dentro=None):
        m = Image.new("L", (C, C), 0)
        ImageDraw.Draw(m).line([(round(P(x)), round(P(y))) for x, y in pts], fill=255, width=1)
        self.pintar(m, cor, dentro)

    def contorno(self, base, cor):
        """Contorno externo de 1 px (4 vizinhos) em volta de tudo o que ja foi pintado."""
        a = self.im.getchannel("A").point(lambda v: 255 if v > 0 else 0)
        dil = a.filter(ImageFilter.MaxFilter(3))
        anel = sub(dil, a)
        self.im.paste(Image.new("RGBA", (C, C), cor), (0, 0), anel)


def sombrear(t, m, tons, brilho=True):
    """Preenche a mascara m com 4 tons (0 escuro..3 claro): meio, 1 px de sombra embaixo-direita, mais 1 px mais escuro, e brilho em cima-esquerda."""
    t.pintar(m, tons[1])
    t.pintar(borda_sombra(m, 2), tons[0], m)
    t.pintar(borda_sombra(m, 1), tons[0], m)
    t.pintar(sub(borda_sombra(m, 2), borda_sombra(m, 1)), tons[0], m)
    if brilho:
        t.pintar(borda_luz(m, 1), tons[3], m)
        t.pintar(sub(borda_luz(m, 2), borda_luz(m, 1)), tons[2], m)


OUT = hexa("160c0e")

# ---------------------------------------------------------------- HAZAKI: tate de madeira laqueada vermelha com mon dourado
HZ_LACA = [hexa(c) for c in ("4a0f16", "8c1b22", "c43a2f", "ec6a4a")]
HZ_OURO = [hexa(c) for c in ("7a4e10", "c08a22", "efc74f", "fff1a8")]
HZ_FERRO = [hexa(c) for c in ("14101a", "2a2330", "4a4256", "6e6680")]
HZ_MADEIRA = [hexa(c) for c in ("2d1a0e", "4b2d17", "6e4624", "93602f")]


def hazaki(vista):
    sx = 0.52 if vista == "lado" else 1.0
    corpo = forma(poligono([(9, 7), (12, 4), (20, 4), (23, 7), (23, 25), (21, 27), (11, 27), (9, 25)]), sx)
    t = Tela()
    if vista == "costas":
        sombrear(t, corpo, HZ_MADEIRA)
        for x in (12, 16, 20):  # juntas das tabuas
            t.linha([(x, 5), (x, 26)], HZ_MADEIRA[0], corpo)
        for y in (10, 21):  # tiras de ferro
            t.pintar(forma(retangulo(9, y, 23, y + 2)), HZ_FERRO[1], corpo)
            t.linha([(9, y), (23, y)], HZ_FERRO[3], corpo)
        t.pintar(forma(retangulo(13, 13, 19, 19)), HZ_FERRO[0], corpo)  # a alca de ferro (argola)
        t.pintar(forma(retangulo(14, 14, 18, 18)), HZ_MADEIRA[2], corpo)
        t.pixel(13, 13, HZ_FERRO[3])
        t.pixel(14, 14, HZ_MADEIRA[3])
        t.contorno(corpo, OUT)
        return t.im
    sombrear(t, corpo, HZ_LACA)
    # estrias da laca (brilho em diagonal)
    t.linha([(11, 9), (11, 14)], HZ_LACA[3], corpo)
    t.linha([(12, 7), (12, 8)], HZ_LACA[3], corpo)
    # aro negro e as duas tiras de ferro
    aro = sub(corpo, forma(poligono([(10, 8), (12, 5), (20, 5), (22, 8), (22, 24), (20, 26), (12, 26), (10, 24)]), sx))
    t.pintar(aro, HZ_FERRO[1], corpo)
    t.pintar(borda_luz(aro, 1), HZ_FERRO[3], corpo)
    for y in (10, 21):
        t.pintar(forma(retangulo(9, y, 23, y + 1)), HZ_FERRO[1], corpo)
        t.pintar(forma(retangulo(9, y, 23, y)), HZ_FERRO[3], corpo)
    if vista == "frente" or vista == "rachado":
        # mon: aro dourado com cinco petalas
        t.pintar(forma(elipse(16, 15.5, 4.5, 4.5)), HZ_OURO[1], corpo)
        t.pintar(forma(elipse(16, 15.5, 3.2, 3.2)), HZ_LACA[0], corpo)
        t.pintar(borda_luz(forma(elipse(16, 15.5, 4.5, 4.5)), 1), HZ_OURO[3], corpo)
        t.pintar(borda_sombra(forma(elipse(16, 15.5, 4.5, 4.5)), 1), HZ_OURO[0], corpo)
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1), (0, 0)):
            t.pixel(16 + dx, 15 + dy, HZ_OURO[2])
        t.pixel(16, 15, HZ_OURO[3])
        # pregos dourados nos cantos
        for p in ((11, 6), (21, 6), (10, 25), (22, 25)):
            t.pixel(*p, HZ_OURO[2])
    else:  # lado: so uma pincelada de ouro (o mon espremido)
        t.pintar(forma(elipse(16, 15.5, 4.5, 4.5), sx), HZ_OURO[1], corpo)
        t.pixel(16, 14, HZ_OURO[3])
    if vista == "lado":  # espessura da madeira: a lateral, mais escura, a direita
        esp = sub(forma(poligono([(9, 7), (12, 4), (20, 4), (23, 7), (23, 25), (21, 27), (11, 27), (9, 25)]), sx), Image.new("L", (C, C), 0))
        lat = e(desloca(corpo, 2, 0), ImageChops.invert(corpo))
        t.pintar(lat, HZ_MADEIRA[1])
        t.pintar(borda_sombra(lat, 1), HZ_MADEIRA[0])
        corpo = ImageChops.lighter(corpo, lat)
    t.contorno(corpo, OUT)
    return t.im


# ---------------------------------------------------------------- NICAO: redondo de ferro rebitado, amassado e enferrujado
NK_FERRO = [hexa(c) for c in ("232838", "424b60", "6f7b94", "b2bfd6")]
NK_FERR = [hexa(c) for c in ("4a2410", "7e4420", "b06a2e", "d9954a")]
NK_COURO = [hexa(c) for c in ("231509", "3f2813", "5e3d1d", "7e5530")]


def _aro_reforco(t, corpo, sx, vista):
    """Aro de reforco do escudo do Nick (camada 1): uma faixa de ferro mais clara entre os raios 9,4 e 11, com 16 rebites (de costas e de frente; de lado, nenhum)."""
    aro = sub(corpo, forma(elipse(16, 16, 9.4, 9.4), sx))
    t.pintar(aro, NK_FERRO[2], corpo)
    t.pintar(borda_luz(aro, 1), NK_FERRO[3], corpo)
    t.pintar(borda_sombra(aro, 1), NK_FERRO[0], corpo)
    if vista != "lado":
        for k in range(16):
            a = math.tau * k / 16 + 0.2
            t.pixel(16 + math.cos(a) * 10.2, 16 + math.sin(a) * 10.2, NK_FERRO[3], corpo)


def nicao(vista, reforco=False):
    sx = 0.5 if vista == "lado" else 1.0
    base = uniao(elipse(16, 16, 11, 11))
    corpo = forma(base, sx)
    mordida = forma(elipse(8.2, 24.5, 3.1, 3.1), sx)  # o amassado: um bocado arrancado na borda
    corpo = sub(corpo, mordida)
    t = Tela()
    if vista == "costas":
        sombrear(t, corpo, NK_FERRO)
        for y in (11, 21):
            t.pintar(forma(retangulo(6, y, 26, y + 2), sx), NK_COURO[1], corpo)
            t.pintar(forma(retangulo(6, y, 26, y), sx), NK_COURO[3], corpo)
        t.pintar(forma(retangulo(13, 13, 19, 19), sx), NK_FERRO[0], corpo)
        t.pintar(forma(retangulo(14, 14, 18, 18), sx), NK_COURO[2], corpo)
        t.pintar(forma(retangulo(14, 14, 18, 14), sx), NK_COURO[3], corpo)
        if reforco:
            _aro_reforco(t, corpo, sx, vista)
        t.pixel(16, 16, NK_FERRO[3])
        t.contorno(corpo, OUT)
        return t.im
    sombrear(t, corpo, NK_FERRO)
    anel_i = forma(elipse(16, 16, 8.4, 8.4), sx)
    anel = sub(corpo, anel_i)
    t.pintar(anel, NK_FERRO[0], corpo)  # faixa externa mais escura
    t.pintar(borda_luz(anel, 1), NK_FERRO[2], corpo)
    t.pintar(borda_luz(forma(elipse(16, 16, 8.4, 8.4), sx), 1), NK_FERRO[0], corpo)
    if reforco:  # camada 1 (nivel 6 do Nick): aro de reforco mais largo, com mais rebites
        _aro_reforco(t, corpo, sx, vista)
    # ferrugem em manchas
    for cx, cy, r in ((21, 21, 2.4), (11, 12, 1.6), (22, 11, 1.4)):
        mm = forma(elipse(cx, cy, r, r), sx)
        t.pintar(mm, NK_FERR[1], corpo)
        t.pintar(borda_luz(mm, 1), NK_FERR[3], corpo)
        t.pintar(borda_sombra(mm, 1), NK_FERR[0], corpo)
    # tiras cruzadas (reforco)
    for r in (forma(retangulo(15, 6, 17, 26), sx), forma(retangulo(6, 15, 26, 17), sx)):
        t.pintar(e(r, anel_i), NK_FERRO[2], corpo)
        t.pintar(borda_sombra(e(r, anel_i), 1), NK_FERRO[0], corpo)
        t.pintar(borda_luz(e(r, anel_i), 1), NK_FERRO[3], corpo)
    # rebites no aro
    if vista != "lado":
        for k in range(8):
            a = math.tau * k / 8 + 0.39
            x = 16 + math.cos(a) * 9.6
            y = 16 + math.sin(a) * 9.6
            t.pixel(x, y, NK_FERRO[3], corpo)
            t.pixel(x + 1, y + 1, NK_FERRO[0], corpo)
    else:
        for y in (9, 13, 19, 23):
            t.pixel(16 + round(-8 * sx), y, NK_FERRO[3], corpo)
    # o umbo (cupula central)
    umbo = forma(elipse(16, 16, 3.8, 3.8), sx)
    t.pintar(umbo, NK_FERRO[2], corpo)
    t.pintar(borda_sombra(umbo, 1), NK_FERRO[0], corpo)
    t.pintar(borda_luz(umbo, 1), NK_FERRO[3], corpo)
    t.pixel(15, 15, hexa("e8f0ff"))
    # amassados: arcos escuros e um riscado de batida
    t.linha([(21, 8), (23, 10), (24, 13)], NK_FERRO[0], corpo)
    t.linha([(8, 18), (9, 20)], NK_FERRO[0], corpo)
    if vista == "lado":  # espessura da borda: lateral clara a direita
        lat = e(desloca(corpo, 2, 0), ImageChops.invert(corpo))
        t.pintar(lat, NK_FERRO[1])
        t.pintar(borda_luz(lat, 1), NK_FERRO[2])
        t.pintar(borda_sombra(lat, 1), NK_FERRO[0])
        corpo = ImageChops.lighter(corpo, lat)
    t.contorno(corpo, OUT)
    return t.im


# ---------------------------------------------------------------- LUCAS: broquel leve de couro e bronze
LK_COURO = [hexa(c) for c in ("2a170a", "4a2c14", "7a4c24", "a9703a")]
LK_BRONZE = [hexa(c) for c in ("4e3410", "9a6a1e", "d9a443", "f7dc86")]
LK_ROXO = [hexa(c) for c in ("3f1a5e", "6a2c8f", "a456d6", "e5b8ff")]


def lucas(vista):
    sx = 0.5 if vista == "lado" else 1.0
    corpo = forma(elipse(16, 16, 7.6, 7.6), sx)
    t = Tela()
    if vista == "costas":
        sombrear(t, corpo, LK_COURO)
        t.pintar(forma(retangulo(8, 14, 24, 18), sx), LK_COURO[0], corpo)  # alca
        t.pintar(forma(retangulo(8, 15, 24, 16), sx), LK_COURO[2], corpo)
        t.pintar(forma(retangulo(13, 13, 19, 19), sx), LK_BRONZE[1], corpo)
        t.pixel(14, 14, LK_BRONZE[3], corpo)
        t.contorno(corpo, OUT)
        return t.im
    sombrear(t, corpo, LK_COURO)
    miolo = forma(elipse(16, 16, 5.4, 5.4), sx)
    aro = sub(corpo, miolo)
    t.pintar(aro, LK_BRONZE[1], corpo)  # aro de bronze
    t.pintar(borda_luz(aro, 1), LK_BRONZE[3], corpo)
    t.pintar(borda_sombra(corpo, 1), LK_BRONZE[0], corpo)
    # costura
    if vista != "lado":
        for k in range(10):
            a = math.tau * k / 10
            t.pixel(round(16 + math.cos(a) * 4.0), round(16 + math.sin(a) * 4.0), LK_COURO[3], miolo)
    # umbo de bronze com uma gema roxa
    umbo = forma(elipse(16, 16, 2.8, 2.8), sx)
    t.pintar(umbo, LK_BRONZE[2], corpo)
    t.pintar(borda_sombra(umbo, 1), LK_BRONZE[0], corpo)
    t.pintar(borda_luz(umbo, 1), LK_BRONZE[3], corpo)
    t.pixel(16, 16, LK_ROXO[2])
    t.pixel(15, 15, LK_ROXO[3])
    if vista == "lado":
        lat = e(desloca(corpo, 2, 0), ImageChops.invert(corpo))
        t.pintar(lat, LK_BRONZE[1])
        t.pintar(borda_sombra(lat, 1), LK_BRONZE[0])
        corpo = ImageChops.lighter(corpo, lat)
    t.contorno(corpo, OUT)
    return t.im


# ---------------------------------------------------------------- MATHEUS: escudo em gota de laca azul, aro de aco, sino dourado
MT_LACA = [hexa(c) for c in ("0e2048", "1c4590", "2f73e0", "78b0ff")]
MT_ACO = [hexa(c) for c in ("2e3648", "5a6680", "9aa8c2", "e2ebfa")]
MT_OURO = HZ_OURO


def matheus(vista):
    sx = 0.52 if vista == "lado" else 1.0
    pts = [(8, 5), (24, 5), (24, 14), (21.5, 21), (16, 27), (10.5, 21), (8, 14)]
    corpo = forma(poligono(pts), sx)
    t = Tela()
    if vista == "costas":
        sombrear(t, corpo, HZ_MADEIRA)
        for x in (12, 16, 20):
            t.linha([(x, 6), (x, 24)], HZ_MADEIRA[0], corpo)
        t.pintar(forma(retangulo(8, 10, 24, 12), sx), MT_ACO[1], corpo)
        t.pintar(forma(retangulo(8, 10, 24, 10), sx), MT_ACO[3], corpo)
        t.pintar(forma(retangulo(13, 14, 19, 19), sx), HZ_FERRO[0], corpo)
        t.pintar(forma(retangulo(14, 15, 18, 17), sx), HZ_MADEIRA[2], corpo)
        t.pixel(14, 14, MT_ACO[3])
        t.contorno(corpo, OUT)
        return t.im
    sombrear(t, corpo, MT_LACA)
    interno = forma(poligono([(9.5, 6.5), (22.5, 6.5), (22.5, 13.5), (20.5, 20), (16, 25), (11.5, 20), (9.5, 13.5)]), sx)
    aro = sub(corpo, interno)
    t.pintar(aro, MT_ACO[1], corpo)
    t.pintar(borda_luz(aro, 1), MT_ACO[3], corpo)
    t.pintar(borda_sombra(corpo, 1), MT_ACO[0], corpo)
    t.linha([(11, 8), (11, 12)], MT_LACA[3], corpo)
    if vista != "lado":
        # o sino: copa, boca aberta e badalo
        sino = forma(poligono([(14, 10), (18, 10), (19, 12), (19.5, 15), (21, 17), (11, 17), (12.5, 15), (13, 12)]))
        t.pintar(sino, MT_OURO[2], corpo)
        t.pintar(borda_luz(sino, 1), MT_OURO[3], corpo)
        t.pintar(borda_sombra(sino, 1), MT_OURO[0], corpo)
        t.pixel(15, 9, MT_OURO[1])
        t.pixel(16, 9, MT_OURO[1])
        t.pixel(16, 19, MT_OURO[3])
        t.pixel(16, 18, MT_OURO[1])
        t.linha([(11, 17), (21, 17)], MT_OURO[0], corpo)
    else:
        t.pintar(forma(retangulo(14, 10, 18, 17), sx), MT_OURO[1], corpo)
        t.pixel(16, 12, MT_OURO[3])
    if vista == "lado":
        lat = e(desloca(corpo, 2, 0), ImageChops.invert(corpo))
        t.pintar(lat, MT_ACO[1])
        t.pintar(borda_sombra(lat, 1), MT_ACO[0])
        corpo = ImageChops.lighter(corpo, lat)
    t.contorno(corpo, OUT)
    return t.im


# ---------------------------------------------------------------- rachaduras e pedacos
def rachar(frente, semente):
    """Quadro 'rachado': a frente com uma trinca em zigue-zague e lascas claras na borda. Deterministico por semente."""
    im = frente.copy()
    a = frente.getchannel("A")
    rng = _Rng(semente)
    x, y = 16 + rng.inteiro(-2, 2), 6
    d = ImageDraw.Draw(im)
    pts = [(x, y)]
    while y < 26:
        y += rng.inteiro(2, 4)
        x += rng.inteiro(-2, 2)
        pts.append((x, y))
    tr = Image.new("L", (C, C), 0)
    ImageDraw.Draw(tr).line([(round(P(px)), round(P(py))) for px, py in pts], fill=255, width=1)
    tr = e(tr, a.point(lambda v: 255 if v > 0 else 0))
    im.paste(Image.new("RGBA", (C, C), hexa("0a0608")), (0, 0), tr)
    # ramo lateral
    k = len(pts) // 2
    bx, by = pts[k]
    ramo = Image.new("L", (C, C), 0)
    ImageDraw.Draw(ramo).line([(round(P(px)), round(P(py))) for px, py in [(bx, by), (bx + 4, by + 2), (bx + 6, by + 1)]], fill=255, width=1)
    ramo = e(ramo, a.point(lambda v: 255 if v > 0 else 0))
    im.paste(Image.new("RGBA", (C, C), hexa("0a0608")), (0, 0), ramo)
    # lado da trinca a direita fica um pixel mais claro (a quebra levanta)
    lado = desloca(tr, 1, 0)
    lado = sub(e(lado, a.point(lambda v: 255 if v > 0 else 0)), tr)
    im.paste(Image.new("RGBA", (C, C), (255, 255, 255, 70)), (0, 0), lado)
    return im


class _Rng:
    def __init__(self, s):
        self.s = (s * 2654435761 + 12345) & 0xFFFFFFFF

    def prox(self):
        self.s = (self.s * 1664525 + 1013904223) & 0xFFFFFFFF
        return self.s / 0xFFFFFFFF

    def inteiro(self, a, b):
        return a + int(self.prox() * (b - a + 1))


def pedacos(frente, semente):
    """Quatro pedacos irregulares (Voronoi com a borda entortada por uma onda) que juntos refazem a frente. Devolve (imagens, centroides)."""
    a = frente.getchannel("A")
    caixa = a.getbbox()
    cx = (caixa[0] + caixa[2]) / 2.0
    cy = (caixa[1] + caixa[3]) / 2.0
    lx = (caixa[2] - caixa[0]) / 4.0
    ly = (caixa[3] - caixa[1]) / 4.0
    rng = _Rng(semente)
    sementes = [(cx + sx * lx + rng.inteiro(-1, 1), cy + sy * ly + rng.inteiro(-1, 1)) for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1))]
    fase = rng.prox() * 6.0
    imgs = [Image.new("RGBA", (C, C), (0, 0, 0, 0)) for _ in range(4)]
    soma = [[0, 0, 0] for _ in range(4)]
    for yy in range(C):
        for xx in range(C):
            if a.getpixel((xx, yy)) == 0:
                continue
            ond = 1.1 * math.sin(xx * 1.1 + yy * 0.8 + fase)
            melhor = min(range(4), key=lambda i: math.hypot(xx - sementes[i][0], yy - sementes[i][1]) + ond * (1 if i in (0, 3) else -1))
            imgs[melhor].putpixel((xx, yy), frente.getpixel((xx, yy)))
            s = soma[melhor]
            s[0] += xx
            s[1] += yy
            s[2] += 1
    cent = [(round(s[0] / s[2], 1), round(s[1] / s[2], 1)) if s[2] else (16.0, 16.0) for s in soma]
    return imgs, cent


# ---------------------------------------------------------------- montagem
# A faixa M do Nick: celula de 48 px, com o desenho ampliado (zoom) para o corpo de raio 11 (da celula de 32) ocupar 36 px
# de diametro; com o contorno de 1 px, a frente fica com 38 x 38 px (pedido 9: escudo claramente maior que o de 24 x 24).
NICAO_ZOOM = 36.0 / 22.0

# Uma entrada por personagem (a chave e o id do escudo no jogo). A ordem define a semente de cada faixa: nao mudar.
# arquivo: o nome do PNG em projeto/assets/v2/escudos; celula: lado da celula em px; reforco: tem as 4 celulas da camada 1 (nivel 6 do Nick).
ESCUDOS = {
    "hazaki": {"fn": hazaki, "arquivo": "hazaki", "celula": 32, "zoom": 1.0, "reforco": False},
    "nicao": {"fn": nicao, "arquivo": "nicao_m", "celula": 48, "zoom": NICAO_ZOOM, "reforco": True},
    "lucas": {"fn": lucas, "arquivo": "lucas", "celula": 32, "zoom": 1.0, "reforco": False},
    "matheus": {"fn": matheus, "arquivo": "matheus", "celula": 32, "zoom": 1.0, "reforco": False},
}


def faixa(fn, semente, reforco=False):
    frente = fn("frente")
    lado = fn("lado")
    costas = fn("costas")
    rach = rachar(frente, semente)
    frags, cent = pedacos(frente, semente + 7)
    quadros = [frente, lado, costas, rach] + frags
    if reforco:  # camada 1: frente, lado, costas e rachado de novo, com o aro de reforco (celulas 8 a 11); os pedacos da quebra sao os da camada 0
        fr = fn("frente", True)
        quadros += [fr, fn("lado", True), fn("costas", True), rachar(fr, semente)]
    fx = Image.new("RGBA", (C * len(quadros), C), (0, 0, 0, 0))
    for i, im in enumerate(quadros):
        fx.paste(im, (i * C, 0))
    return fx, cent


def main():
    argv = sys.argv[1:]
    previa = None
    if "--previa" in argv:
        i = argv.index("--previa")
        previa = Path(argv[i + 1])
        del argv[i : i + 2]
    args = [a for a in argv if not a.startswith("--")]
    saida = Path(args[0]) if args else Path(__file__).resolve().parents[2] / "projeto" / "assets" / "v2" / "escudos"
    saida.mkdir(parents=True, exist_ok=True)
    centroides = {}
    todas = []
    for i, (estilo, cfg) in enumerate(ESCUDOS.items()):
        usar(cfg["celula"], cfg["zoom"])
        fx, cent = faixa(cfg["fn"], 11 + i * 5, cfg["reforco"])
        fx.save(saida / f"{cfg['arquivo']}.png")
        centroides[estilo] = cent
        todas.append(fx)
    print(json.dumps(centroides))
    if previa is not None:
        esc = 5
        larg = max(fx.width for fx in todas) * esc
        alt = sum(fx.height for fx in todas) * esc
        im = Image.new("RGBA", (larg, alt), (38, 50, 52, 255))
        y = 0
        for fx in todas:
            g = fx.resize((fx.width * esc, fx.height * esc), Image.NEAREST)
            im.paste(g, (0, y), g)
            y += g.height
        im.save(previa)


if __name__ == "__main__":
    main()

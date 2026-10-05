"""Sprites no formato da referencia: proporcao mais realista (cabeca ~1/4 da altura), contorno escuro,
sombras em 2-3 tons. Quadro 32x48; folhas: parado (4) e andando (4) x baixo/esquerda/direita/cima."""
import sys, os
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
from retratos3 import CAIRU

FW, FH = 32, 48
OUT = (22, 18, 24)
NICAO = dict(
    pal={'K': OUT, 'H': (40, 32, 30), 'h': (74, 58, 50), 'S': (208, 150, 110), 's': (170, 112, 82), 'L': (230, 182, 142),
         'B': (54, 40, 36), 'b': (92, 68, 56), 'E': (26, 18, 18), 'W': (226, 218, 208), 'M': (168, 92, 88), 'm': (120, 60, 58)},
    # cabeca de frente 14x15 (inclui orelhas)
    frente=[
        "....KKKKKK....",
        "...KHhHHhHK...",
        "..KHHHHHHHHK..",
        "..KHHHHHHHHK..",
        "..KHSSLLSSHK..",
        ".KKSHHSSHHSKK.",
        ".KSSEWSsWESSK.",
        ".KsSSSSsSSSsK.",
        "..KSSSssSSSK..",
        "..KBSBBBBSBK..",
        "..KBBmMMmBBK..",
        "..KBBBBBBBBK..",
        "...KBBbbBBK...",
        "....KBBBBK....",
        ".....KKKK.....",
    ],
    costas=[
        "....KKKKKK....",
        "...KHhHHhHK...",
        "..KHHHHHHHHK..",
        "..KHHHHHHHHK..",
        "..KHHHHHHHHK..",
        ".KKHHHHHHHHKK.",
        ".KSHHHHHHHHSK.",
        ".KsHHHHHHHHsK.",
        "..KHHHHHHHHK..",
        "..KhHHHHHHhK..",
        "..KsSSSSSSsK..",
        "...KsSSSSsK...",
        "....KsSSsK....",
        ".....KKKK.....",
        "..............",
    ],
    # perfil olhando para a direita
    lado=[
        "....KKKKK.....",
        "...KHhHHhKK...",
        "..KHHHHHHHHK..",
        "..KHHHHHHHHK..",
        "..KHHHHHSLSK..",
        "..KHHHHHHHSK..",
        "..KHSSHSSEWK..",
        "..KHSsHSSSSKK.",
        "..KHHSSSSSSSK.",
        "..KHBBSSSSsK..",
        "...KBBBBBmMK..",
        "...KBBBBBBBK..",
        "....KBBbbBK...",
        ".....KBBBK....",
        "......KKK.....",
    ],
)

def grade(rows, pal):
    h, w = len(rows), len(rows[0])
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); p = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != '.': p[x, y] = pal[c] + (255,)
    return im

def contorno(im):
    a = im.load(); w, h = im.size; o = im.copy(); q = o.load()
    for y in range(h):
        for x in range(w):
            if a[x, y][3]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and a[nx, ny][3] and a[nx, ny][:3] != OUT:
                    q[x, y] = OUT + (255,); break
    return o

def R(d, x0, y0, x1, y1, c):
    if x1 >= x0 and y1 >= y0: d.rectangle([x0, y0, x1, y1], fill=tuple(c) + (255,))

CALCA, CALCA_S, CALCA_L = (44, 52, 82), (30, 34, 56), (64, 74, 110)
TENIS, SOLA = (40, 40, 46), (214, 214, 220)

def corpo_frente(d, pal, acao, f, costas=False):
    """acao parado/andando; f 0..3. devolve deslocamento vertical (respiracao/passo)"""
    T, t, U = CAIRU['T'], CAIRU['t'], CAIRU['U']
    S, s = pal['S'], pal['s']
    cx = 16
    if acao == 'parado':
        bob = [0, 0, 1, 1][f]; pern = [(0, 0), (0, 0)]; braco = [0, 0]
    else:
        bob = [0, 1, 0, 1][f]
        pern = [(2, 0), (0, 0), (0, 2), (0, 0)][f]
        pern = [(pern[0], 0), (pern[1], 0)]
        braco = [[1, -1], [0, 0], [-1, 1], [0, 0]][f]
    top = 16 + bob                       # ombros
    hip = 29 + bob
    # pernas
    for i, (lift, _) in enumerate(pern):
        x0 = cx - 5 if i == 0 else cx + 1
        yb = 44 - lift
        R(d, x0, hip, x0 + 3, yb - 2, CALCA)
        R(d, x0 + (3 if i else 0), hip + 1, x0 + (3 if i else 0), yb - 2, CALCA_S if i else CALCA_L)
        R(d, x0 - (1 if i == 0 else 0), yb - 1, x0 + 3 + (1 if i else 0), yb, TENIS)
        R(d, x0 - (1 if i == 0 else 0), yb + 1, x0 + 3 + (1 if i else 0), yb + 1, SOLA)
    R(d, cx - 5, hip - 1, cx + 4, hip + 1, CALCA)
    # tronco
    R(d, cx - 5, top, cx + 4, hip - 1, T)
    R(d, cx + 2, top + 1, cx + 4, hip - 1, t)
    R(d, cx - 5, top + 1, cx - 4, hip - 2, U)
    R(d, cx - 5, hip - 1, cx + 4, hip - 1, t)
    # bracos atras do tronco
    for i, sw in enumerate(braco):
        xa = cx - 8 if i == 0 else cx + 5
        R(d, xa, top + 1 + sw, xa + 2, top + 4 + sw, T if i == 0 else t)
        R(d, xa + (1 if i == 0 else -1) * 0, top + 1 + sw, xa + 2, top + 1 + sw, U if i == 0 else T)
        R(d, xa, top + 5 + sw, xa + 2, top + 10 + sw, S if i == 0 else s)
        R(d, xa, top + 11 + sw, xa + 2, top + 11 + sw, s)
        R(d, xa + (3 if i == 0 else -1), top + 1 + sw, xa + (3 if i == 0 else -1), top + 11 + sw, OUT)
    if not costas:
        R(d, cx - 2, top, cx + 1, top, pal['s'])                              # gola
        for (x, y) in [(cx - 3, top + 3), (cx - 2, top + 3), (cx - 1, top + 3), (cx - 3, top + 4)]:
            d.point((x, y), fill=CAIRU['W'] + (255,))
    return bob

def corpo_lado(d, pal, acao, f):
    T, t, U = CAIRU['T'], CAIRU['t'], CAIRU['U']
    S, s = pal['S'], pal['s']
    cx = 16
    if acao == 'parado':
        bob = [0, 0, 1, 1][f]; sw = 0; ar = 0
    else:
        bob = [0, 1, 0, 1][f]; sw = [4, 0, -4, 0][f]; ar = [-3, 0, 3, 0][f]
    top = 16 + bob; hip = 29 + bob
    def perna(off, near):
        c = CALCA if near else CALCA_S
        for y in range(hip, 43):
            k = (y - hip) / (43 - hip)
            x0 = cx - 2 + round(off * k)
            R(d, x0, y, x0 + 3, y, c)
        fx = cx - 2 + off
        lift = 1 if (off < 0 and sw != 0) else 0
        R(d, fx, 43 - lift, fx + 5, 44 - lift, TENIS if near else (30, 30, 34))
        R(d, fx, 45 - lift, fx + 5, 45 - lift, SOLA)
    perna(-sw, False)
    def braco(a, near):
        cs, cc = (T, S) if near else (t, s)
        R(d, cx - 1, top + 1, cx + 1, top + 4, cs)
        if near: R(d, cx - 2, top + 1, cx - 2, top + 4, OUT); R(d, cx + 2, top + 2, cx + 2, top + 4, OUT)
        for y in range(top + 5, top + 12):
            k = (y - top - 5) / 6
            x = cx - 1 + round(a * k)
            R(d, x, y, x + 2, y, cc)
            if near: d.point((x - 1, y), fill=OUT + (255,)); d.point((x + 3, y), fill=OUT + (255,))
    braco(-ar, False)
    R(d, cx - 4, top, cx + 4, hip - 1, T)
    R(d, cx + 2, top + 1, cx + 4, hip - 1, t)
    R(d, cx - 4, top + 1, cx - 3, hip - 2, U)
    R(d, cx - 4, hip - 1, cx + 3, hip + 1, CALCA)
    perna(sw, True)
    braco(ar, True)
    return bob

def folha(P, acoes=('parado', 'andando')):
    pal = P['pal']
    heads = {'baixo': grade(P['frente'], pal), 'cima': grade(P['costas'], pal), 'direita': grade(P['lado'], pal)}
    sheet = Image.new('RGBA', (FW * 4 * len(acoes), FH * 4), (0, 0, 0, 0))
    for ai, acao in enumerate(acoes):
        for row, dr in enumerate(['baixo', 'esquerda', 'direita', 'cima']):
            for f in range(4):
                im = Image.new('RGBA', (FW, FH), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
                if dr in ('baixo', 'cima'):
                    bob = corpo_frente(d, pal, acao, f, costas=(dr == 'cima')); h = heads[dr]
                else:
                    bob = corpo_lado(d, pal, acao, f); h = heads['direita']
                im.alpha_composite(h, (16 - 7, 2 + bob))
                im = contorno(im)
                if dr == 'esquerda': im = im.transpose(Image.FLIP_LEFT_RIGHT)
                sheet.paste(im, ((ai * 4 + f) * FW, row * FH))
    return sheet

if __name__ == '__main__':
    sh = folha(NICAO)
    sh.save('nicao_sprites_ref.png')
    big = Image.new('RGBA', (sh.width * 5, sh.height * 5), (30, 30, 38, 255))
    big.alpha_composite(sh.resize((sh.width * 5, sh.height * 5), Image.NEAREST)); big.save('chk.png')

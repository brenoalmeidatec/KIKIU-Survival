import random, sys, os
from PIL import Image, ImageDraw
from nicao import pad, lift_leg

PAL = {
    '.': None,
    'K': (40, 24, 18),      # contorno
    'H': (104, 58, 34),     # cabelo cacheado
    'h': (164, 98, 52),     # pontas mais claras do cacho
    'S': (196, 140, 98),    # pele
    's': (156, 104, 70),    # sombra da pele
    'L': (222, 170, 124),   # luz da pele
    'E': (24, 16, 12),      # olho
    'B': (50, 32, 24),      # cavanhaque
    'M': (150, 84, 64),     # boca
    'T': (236, 236, 230),   # regata branca
    't': (190, 192, 196),   # sombra regata
    'U': (255, 255, 255),
    'P': (34, 34, 40),      # short preto
    'p': (20, 20, 26),
    'F': (232, 232, 232),   # tenis branco
    'f': (150, 150, 158),
    'C': (205, 210, 222),   # corrente / pulseira prata
}

TORSO = [
    ".KSKTTTTTTTTKSK.",
    ".KSKTTTTTTTTKSK.",
    ".KSKTTTTTTTTKSK.",
    ".KSKtTTTTTTtKSK.",
    ".KCKTTTTTTTTKSK.",
    ".KsKTTTTTTTTKsK.",
    "..KKPPPPPPPPKK..",
]
FRONT_TOP = [
    "....KK.KK.KK....",
    "...KhhKhhKhhK...",
    "..KhHHHHhHHHHK..",
    ".KHHhHHHHHhHHHK.",
    ".KhHHHHhHHHHhHK.",
    ".KhHHSSSSSSHHhK.",
    ".KHHSHHSSHHSHHK.",
    ".KhHSEESSEESHhK.",
    ".KHhSSSssSSShHK.",
    "..KHSSBBBBSSHK..",
    "..KhSSMMMMSShK..",
    "...KSSBBBBSSK...",
    "....KSSBBSSK....",
    ".....KKBBKK.....",
    "....KKsSSsKK....",
    "..KTTTsSSsTTTK..",
    ".KTTTTTTTTTTTTK.",
] + TORSO
BACK_TOP = [
    "....KK.KK.KK....",
    "...KhhKhhKhhK...",
    "..KhHHHHhHHHHK..",
    ".KHHhHHHHHhHHHK.",
    ".KhHHHHhHHHHhHK.",
    ".KHHHhHHHHHhHHK.",
    ".KhHHHHHhHHHHhK.",
    ".KHHHhHHHHHhHHK.",
    ".KHHHhHHHHhHHHK.",
    "..KHHhHHHHhHHK..",
    "..KShHhHHhHhSK..",
    "...KSSSSSSSSK...",
    "....KSSSSSSK....",
    ".....KSSSSK.....",
    "....KKSSSSKK....",
    "..KTTTTTTTTTTK..",
    ".KTTTTTTTTTTTTK.",
] + TORSO
LEGS_FRONT = [
    "...KPPPPPPPPK...",
    "...KPPPKKPPPK...",
    "...KPpK..KpPK...",
    "...KSSK..KSSK...",
    "...KSsK..KsSK...",
    "...KFFK..KFFK...",
    "..KFFFK..KFFFK..",
    "..KffKK..KKffK..",
]
SIDE_TOP = [
    "....KK.KK.KK....",
    "...KhhKhhKhhK...",
    "..KhHHHHhHHHHK..",
    ".KHHhHHHHHhHHHK.",
    ".KhHHHHhHHHHhHK.",
    ".KHHHhHHHHSSSSK.",
    ".KhHHHHHHSHHSSK.",
    ".KHHhHHHSSESSSK.",
    ".KHHHHhSSSSSSSSK",
    ".KhHHHHSSSSSSsK.",
    "..KHhHSSSSBBBK..",
    "..KhHSSSSSSMMK..",
    "...KHSSSSSBBK...",
    "....KKSSSSBBK...",
    ".....KsSSsKK....",
    "....KTTTsTK.....",
    "...KTTTTTTTK....",
    "...KTTKSKTTTK...",
    "...KTTKSKTTTK...",
    "...KTTKSKTTTK...",
    "...KtTKSKTTtK...",
    "...KTTKCKTTTK...",
    "...KTTKsKTTTK...",
    "....KKKPPPPK....",
]
LEGS_SIDE_IDLE = [
    "....KPPPPPPK....",
    "....KPPPPPPK....",
    ".....KPPPPK.....",
    ".....KSSSSK.....",
    ".....KSssSK.....",
    ".....KFFFFK.....",
    ".....KFFFFFK....",
    ".....KffffffK...",
]
LEGS_SIDE_WALK_A = [
    "....KPPPPPPK....",
    "....KPPPPPPK....",
    "...KpPK.KPPK....",
    "..KSsK...KSSK...",
    "..KssK...KSsK...",
    ".KFFK.....KFFK..",
    ".KFFFK....KFFFK.",
    ".KffKK....KfffK.",
]
LEGS_SIDE_WALK_B = [
    "....KPPPPPPK....",
    "....KPPPPPPK....",
    "...KPPK.KpPK....",
    "..KSSK...KssK...",
    "..KSsK...KssK...",
    ".KFFK.....KFFK..",
    ".KFFFK....KFFFK.",
    ".KffKK....KfffK.",
]

def render(rows, mirror=False):
    rows = pad(rows)
    assert len(rows) == 32, len(rows)
    img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        assert len(r) == 32, (y, r, len(r))
        for x, c in enumerate(r):
            if PAL[c]:
                img.putpixel((31 - x if mirror else x, y), PAL[c] + (255,))
    return img

def sprites(out):
    down = [FRONT_TOP + LEGS_FRONT, FRONT_TOP + lift_leg(LEGS_FRONT, True), FRONT_TOP + lift_leg(LEGS_FRONT, False)]
    up = [BACK_TOP + LEGS_FRONT, BACK_TOP + lift_leg(LEGS_FRONT, True), BACK_TOP + lift_leg(LEGS_FRONT, False)]
    side = [SIDE_TOP + LEGS_SIDE_IDLE, SIDE_TOP + LEGS_SIDE_WALK_A, SIDE_TOP + LEGS_SIDE_WALK_B]
    fr = {'baixo': [render(f) for f in down], 'esquerda': [render(f, True) for f in side],
          'direita': [render(f) for f in side], 'cima': [render(f) for f in up]}
    sheet = Image.new('RGBA', (96, 128), (0, 0, 0, 0))
    for row, d in enumerate(['baixo', 'esquerda', 'direita', 'cima']):
        for col, im in enumerate(fr[d]):
            sheet.paste(im, (col * 32, row * 32))
    sheet.save(f'{out}/lucas_sprites.png')
    S = 8
    prev = Image.new('RGBA', (96 * S + 40, 128 * S + 50), (120, 170, 110, 255))
    prev.alpha_composite(sheet.resize((96 * S, 128 * S), Image.NEAREST), (20, 25))
    prev.save(f'{out}/preview_sprites.png')
    gif = []
    for d in ['baixo', 'direita', 'cima', 'esquerda']:
        f = fr[d]
        for _ in range(2):
            for im in [f[1], f[0], f[2], f[0]]:
                bg = Image.new('RGBA', (32, 32), (120, 170, 110, 255))
                bg.alpha_composite(im)
                gif.append(bg.resize((256, 256), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
    gif[0].save(f'{out}/lucas_andando.gif', save_all=True, append_images=gif[1:], duration=150, loop=0)

def retrato(out):
    random.seed(3)
    N = 48
    fig = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(fig)
    C = lambda k: PAL[k] + (255,)
    # ombros de fora + regata
    d.polygon([(3, 47), (6, 40), (15, 37), (33, 37), (42, 40), (45, 47)], fill=C('S'))
    d.polygon([(12, 47), (13, 41), (17, 39), (31, 39), (35, 41), (36, 47)], fill=C('T'))
    d.polygon([(17, 39), (24, 44), (31, 39)], fill=C('S'))
    d.line([(13, 42), (13, 47)], fill=C('t'))
    d.line([(35, 42), (35, 47)], fill=C('t'))
    d.line([(7, 41), (7, 47)], fill=C('s'))
    d.line([(41, 41), (41, 47)], fill=C('s'))
    # pescoco
    d.rectangle([19, 31, 29, 39], fill=C('s'))
    # corrente prata
    d.line([(18, 37), (21, 41), (24, 42), (27, 41), (30, 37)], fill=C('C'))
    # rosto (mais fino)
    d.ellipse([15, 9, 33, 38], fill=C('S'))
    d.rectangle([15, 16, 33, 27], fill=C('S'))
    d.ellipse([12, 21, 16, 28], fill=C('S'))
    d.ellipse([32, 21, 36, 28], fill=C('S'))
    for p in [(21, 13), (22, 13), (26, 13), (19, 24), (29, 24)]:
        d.point(p, fill=C('L'))
    # cabelo: nuvem de cachos
    blobs = [(24, 12, 10)]
    for _ in range(26):
        ang = random.uniform(3.3, 6.1)
        import math
        r = random.uniform(7, 10.5)
        cx, cy = 24 + math.cos(ang) * r * 1.1, 13 + math.sin(ang) * r * 0.75
        blobs.append((cx, cy, random.uniform(2.5, 3.5)))
    for cx, cy, r in [(14, 15, 3), (34, 15, 3), (13, 19, 3), (35, 19, 3), (14, 23, 2), (34, 23, 2)]:
        blobs.append((cx, cy, r))
    for cx, cy, r in blobs:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C('H'))
    # franja caindo um pouco na testa
    for cx in (18, 22, 27, 31):
        d.ellipse([cx - 2, 13, cx + 2, 17], fill=C('H'))
    for cx, cy, r in blobs + [(18, 15, 2), (22, 15, 2), (27, 15, 2), (31, 15, 2)]:
        d.arc([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], 200, 300, fill=C('h'))
        d.arc([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], 20, 110, fill=(66, 34, 20, 255))
    # brinco
    d.point((13, 29), fill=C('C'))
    # sobrancelhas
    d.line([(18, 18), (22, 18)], fill=C('B'))
    d.line([(26, 18), (30, 17)], fill=C('B'))
    # olhos (um meio apertado, cara de deboche)
    d.line([(19, 21), (22, 21)], fill=C('E'))
    d.point([(19, 22), (22, 22)], fill=(236, 226, 212, 255))
    d.line([(20, 22), (21, 22)], fill=C('E'))
    d.line([(26, 21), (29, 21)], fill=C('E'))
    d.line([(26, 22), (29, 22)], fill=C('s'))
    d.point((27, 22), fill=C('E'))
    # nariz
    d.line([(24, 22), (24, 26)], fill=C('L'))
    d.line([(23, 23), (23, 26)], fill=C('s'))
    d.point([(22, 27), (26, 27)], fill=C('s'))
    d.line([(23, 28), (25, 28)], fill=C('s'))
    # bigode fino + sorriso de lado + cavanhaque
    d.line([(21, 29), (27, 29)], fill=C('B'))
    d.line([(21, 31), (27, 30)], fill=C('M'))
    d.point((28, 30), fill=C('s'))
    d.polygon([(21, 33), (27, 33), (26, 37), (24, 38), (22, 37)], fill=C('B'))
    d.point([(17, 30), (18, 32), (30, 32), (31, 30)], fill=C('s'))

    o = fig.copy()
    for y in range(N):
        for x in range(N):
            if fig.getpixel((x, y))[3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < N and 0 <= ny < N and fig.getpixel((nx, ny))[3] == 0:
                    o.putpixel((x, y), C('K'))
                    break
    bg = Image.new('RGBA', (N, N), (120, 186, 232, 255))
    bd = ImageDraw.Draw(bg)
    for y in range(32, N):
        bd.line([(0, y), (N, y)], fill=(236, 214, 160, 255))
    bg.alpha_composite(o)
    bd.rectangle([0, 0, N - 1, N - 1], outline=C('K'))
    bg.save(f'{out}/lucas_retrato.png')
    bg.resize((N * 8, N * 8), Image.NEAREST).save(f'{out}/preview_retrato.png')

if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    sprites(out)
    retrato(out)

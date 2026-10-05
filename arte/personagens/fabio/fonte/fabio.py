import sys, os, random
from PIL import Image, ImageDraw
import nicao
from nicao import pad, lift_leg, LEGS_FRONT, LEGS_SIDE_IDLE, LEGS_SIDE_WALK_A, LEGS_SIDE_WALK_B
import joao

PAL = dict(nicao.PAL)
PAL.update({
    'H': (20, 18, 16),      # cabelo curtinho
    'h': (48, 42, 38),
    'S': (104, 66, 46),     # pele
    's': (82, 52, 36),
    'L': (132, 90, 64),
    'M': (92, 56, 46),
    'B': (32, 22, 18),      # bigode fino / barba no queixo
    'T': (246, 160, 40),    # camisa laranja da Costa do Marfim
    't': (220, 132, 24),
    'U': (255, 196, 90),
    'N': (24, 140, 70),     # gola verde
    'R': (24, 140, 70),     # escudo
    'F': (236, 236, 236),
    'f': (150, 150, 158),
})

ARMS = [
    "KSKTTTTTTTTTTKSK",
    "KSKTTTTTTTTTTKSK",
    "KSKtTTTTTTTTtKSK",
    "KsKTTTTTTTTTTKsK",
    ".KKKPPPPPPPPKKK.",
]
FRONT_TOP = [
    "................",
    "....KKKKKKKK....",
    "...KHHhHHhHHK...",
    "..KHHHHHHHHHHK..",
    "..KHSSSSSSSSHK..",
    "..KSSLSSSSLSSK..",
    "..KSHHHSSHHHSK..",
    "..KSssSSSSssSK..",
    "..KSEESSSSEESK..",
    "..KSSSSssSSSSK..",
    "..KsSSssssSSsK..",
    "..KsSBMMMMBSsK..",
    "...KsSSMMSSsK...",
    "....KsSBBSsK....",
    "...KKsSSSSsKK...",
    ".KTTNNsSSsNNTTK.",
    "KTTTTNNssNNTTTTK",
    "KTTTTTTNNTTTRTTK",
    "KNKTTTTTTTTTTKNK",
] + ARMS
BACK_TOP = [
    "................",
    "....KKKKKKKK....",
    "...KHHhHHhHHK...",
    "..KHHHHHHHHHHK..",
    "..KHHhHHHHhHHK..",
    "..KHHHHHHHHHHK..",
    "..KHHHHHhHHHHK..",
    "..KhHHHHHHHHhK..",
    "..KShHHHHHHhSK..",
    "..KSSHHHHHHSSK..",
    "..KsSSSSSSSSsK..",
    "..KsSSSSSSSSsK..",
    "...KsSSSSSSsK...",
    "....KsSSSSsK....",
    "...KKsSSSSsKK...",
    ".KTTNNNNNNNNTTK.",
    "KTTTTTTTTTTTTTTK",
    "KTTTTTTTTTTTTTTK",
    "KNKTTTTTTTTTTKNK",
] + ARMS
SIDE_TOP = [
    "................",
    "....KKKKKKKK....",
    "...KHHhHHhHHK...",
    "..KHHHHHHHHHHK..",
    "..KHHHHHHHHSSK..",
    "..KHHHHSSSSSSK..",
    "..KHHHSSSHHHSK..",
    "..KHHsSSSSssSK..",
    "..KHsSsSSSSESK..",
    "..KHHsSSSSSSSSK.",
    "..KhSSSSSSSssK..",
    "..KsSSSSSSMMMK..",
    "...KsSSSSSMMK...",
    "....KsSSSSSK....",
    "....KsSSSSK.....",
    "...KTTNNNNTTK...",
    "..KTTTTTTTTTK...",
    "..KTTTTTTTTTTK..",
    "..KTTKNKTTTTTK..",
    "..KTTKSKTTTTTK..",
    "..KTTKSKTTTTTK..",
    "..KtTKSKTTTTtK..",
    "..KTTKsKTTTTK...",
    "...KKKPPPPPK....",
]

# corpo mais magro (1,78m / 78kg)
TORSO_F = [
    "....KKsSSsKK....",
    "..KTNNSSSSNNTK..",
    ".KTTTTNNNNTTTTK.",
    ".KTtTTTTTTTRTtK.",
    ".KNKTTTTTTTTKNK.",
    ".KSKTTTTTTTTKSK.",
    ".KSKTTTTTTTTKSK.",
    ".KSKtTTTTTTtKSK.",
    ".KsKTTTTTTTTKsK.",
    "..KKPPPPPPPPKK..",
]
TORSO_B = ["....KKsSSsKK....", "..KTNNNNNNNNTK..", ".KTTTTTTTTTTTTK.", ".KTtTTTTTTTTtTK."] + TORSO_F[4:]
TORSO_S = [
    "...KTNNNTTK.....",
    "...KTTTTTTTK....",
    "...KTTtTTTTK....",
    "...KTKNKTTTK....",
    "...KTKSKTTTK....",
    "...KTKSKTTTK....",
    "...KtKSKTTtK....",
    "...KTKsKTTTK....",
    "....KKKPPPK.....",
]
FRONT_TOP = FRONT_TOP[:14] + TORSO_F
BACK_TOP = BACK_TOP[:14] + TORSO_B
SIDE_TOP = SIDE_TOP[:15] + TORSO_S

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
    sheet.save(f'{out}/fabio_sprites.png')
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
    gif[0].save(f'{out}/fabio_andando.gif', save_all=True, append_images=gif[1:], duration=220, loop=0)

def retrato(out):
    random.seed(4)
    N = 48
    fig = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(fig)
    C = lambda k: PAL[k] + (255,)
    # camisa branca larga
    d.polygon([(4, 47), (6, 40), (15, 36), (33, 36), (42, 40), (44, 47)], fill=C('T'))
    d.line([(9, 41), (9, 47)], fill=C('t'))
    d.line([(39, 41), (39, 47)], fill=C('t'))
    # pescoco grosso + gola V azul
    d.rectangle([18, 29, 30, 37], fill=C('s'))
    d.ellipse([15, 32, 33, 40], fill=C('N'))
    d.ellipse([16, 32, 32, 38], fill=C('U'))
    d.ellipse([17, 32, 31, 37], fill=C('s'))
    # escudo
    d.rectangle([32, 41, 35, 45], fill=C('R'))
    d.point([(33, 42), (34, 43), (33, 44)], fill=(240, 240, 240, 255))
    d.point((34, 39), fill=(200, 170, 80, 255))
    # orelhas
    d.ellipse([9, 18, 14, 27], fill=C('S'))
    d.ellipse([34, 18, 39, 27], fill=C('S'))
    d.point([(11, 21), (11, 22), (37, 21), (37, 22)], fill=C('s'))
    # rosto cheio
    d.ellipse([13, 5, 35, 37], fill=C('S'))
    d.rectangle([12, 14, 36, 26], fill=C('S'))
    # cabelo baixinho com linha reta
    d.ellipse([12, 3, 36, 13], fill=C('H'))
    d.rectangle([12, 9, 13, 18], fill=C('H'))
    d.rectangle([35, 9, 36, 18], fill=C('H'))
    d.rectangle([13, 8, 35, 9], fill=C('H'))
    for _ in range(30):
        x, y = random.randint(14, 34), random.randint(4, 9)
        if fig.getpixel((x, y))[:3] == PAL['H']:
            d.point((x, y), fill=C('h'))
    for p in [(20, 12), (21, 12), (27, 12), (28, 12), (16, 24), (32, 24)]:
        d.point(p, fill=C('L'))
    # sobrancelhas
    d.line([(16, 16), (21, 16)], fill=C('H'), width=2)
    d.line([(27, 16), (32, 16)], fill=C('H'), width=2)
    # olhos cansados, palpebra caida
    for ex in (17, 27):
        d.line([(ex, 19), (ex + 4, 19)], fill=C('s'))
        d.line([(ex, 20), (ex + 4, 20)], fill=C('E'))
        d.point((ex + 1, 21), fill=(226, 214, 200, 255))
        d.point((ex + 2, 21), fill=C('E'))
        d.point((ex + 3, 21), fill=C('E'))
        d.line([(ex, 22), (ex + 4, 22)], fill=C('s'))
    # nariz largo
    d.line([(24, 21), (24, 25)], fill=C('L'))
    d.line([(23, 22), (23, 25)], fill=C('s'))
    d.line([(20, 27), (28, 27)], fill=C('s'))
    d.point([(20, 26), (28, 26)], fill=C('s'))
    # labios grossos, boca fechada
    d.line([(20, 28), (28, 28)], fill=C('B'))
    d.point([(19, 29), (29, 29)], fill=C('B'))
    d.line([(21, 30), (27, 30)], fill=(64, 38, 30, 255))
    d.line([(21, 31), (27, 31)], fill=C('M'))
    # barba por fazer
    d.line([(22, 35), (26, 35)], fill=C('B'))
    d.line([(18, 33), (21, 35)], fill=C('B'))
    d.line([(30, 33), (27, 35)], fill=C('B'))
    for _ in range(0):
        x, y = random.randint(15, 33), random.randint(29, 37)
        if fig.getpixel((x, y))[:3] == PAL['S']:
            d.point((x, y), fill=C('s'))
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
    bg = Image.new('RGBA', (N, N))
    for y in range(N):
        t = y / (N - 1)
        c = tuple(int(a + (b - a) * t) for a, b in zip((40, 170, 190), (110, 70, 170)))
        for x in range(N):
            bg.putpixel((x, y), c + (255,))
    bg.alpha_composite(o)
    ImageDraw.Draw(bg).rectangle([0, 0, N - 1, N - 1], outline=C('K'))
    bg.save(f'{out}/fabio_retrato.png')
    bg.resize((N * 8, N * 8), Image.NEAREST).save(f'{out}/preview_retrato.png')

if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    sprites(out)
    retrato(out)

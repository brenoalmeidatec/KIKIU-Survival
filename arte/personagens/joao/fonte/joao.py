import sys, os, random
from PIL import Image, ImageDraw
import nicao
from nicao import pad, lift_leg, LEGS_FRONT, LEGS_SIDE_IDLE, LEGS_SIDE_WALK_A, LEGS_SIDE_WALK_B

PAL = dict(nicao.PAL)
PAL.update({
    'H': (34, 26, 22),      # sobrancelha / cabelo
    'h': (92, 66, 52),      # cabelo raspado
    'S': (152, 102, 72),    # pele
    's': (120, 78, 54),
    'L': (186, 134, 98),    # brilho da careca
    'B': (40, 30, 26),      # bigode / cavanhaque
    'M': (110, 66, 50),
    'T': (44, 140, 70),     # camisa verde
    't': (30, 104, 50),
    'U': (78, 176, 100),
    'W': (245, 245, 245),   # numero 10
    'R': (200, 40, 40),     # escudo
    'C': (205, 210, 222),   # corrente
    'F': (40, 40, 44),      # sapato preto
    'f': (90, 90, 96),
})

FRONT_TOP = [
    "................",
    "................",
    "....KKKKKKKK....",
    "...KSSLLLLSSK...",
    "..KhSSSSSSSShK..",
    "..KhSSSSSSSShK..",
    "..KhHHHSSHHHhK..",
    "..KSSEESSEESSK..",
    "..KSSSSssSSSSK..",
    "..KsSBBBBBBSsK..",
    "..KsSBSMMSBSsK..",
    "..KsSSSBBSSSsK..",
    "...KsSSBBSSsK...",
    "....KKKBBKKK....",
    "....KsCSSCsK....",
    "..KTTTtSStTTTK..",
    ".KUTTTTCCTTTTUK.",
    ".KTTTTTTTTTRTTK.",
    ".KtKTTTTTTTTKtK.",
    ".KSKTTTTTTTTKSK.",
    ".KSKTTTTTTTTKSK.",
    ".KSKtTTTTTTtKSK.",
    ".KsKTTTTTTTTKsK.",
    "..KKPPPPPPPPKK..",
]
BACK_TOP = [
    "................",
    "................",
    "....KKKKKKKK....",
    "...KSSLLLLSSK...",
    "..KhSSSSSSSShK..",
    "..KhhSSSSSShhK..",
    "..KhhhhhhhhhhK..",
    "..KhhhhhhhhhhK..",
    "..KHhhhhhhhhHK..",
    "..KsHHHHHHHHsK..",
    "..KsSSSSSSSSsK..",
    "..KsSSSSSSSSsK..",
    "...KsSSSSSSsK...",
    "....KKSSSSKK....",
    "....KsSSSSsK....",
    "..KTTTTTTTTTTK..",
    ".KTTTTTTTTTTTTK.",
    ".KTTTTWTWWWTTTK.",
    ".KtKTWWTWTWTKtK.",
    ".KSKTTWTWTWTKSK.",
    ".KSKTTWTWTWTKSK.",
    ".KSKtTWTWTWtKSK.",
    ".KsKTTWTWWWTKsK.",
    "..KKPPPPPPPPKK..",
]
SIDE_TOP = [
    "................",
    "................",
    "....KKKKKKK.....",
    "...KSSLLLLSK....",
    "..KhSSSSSSSSK...",
    "..KhhSSSSSSSK...",
    "..KhhhSSSHHHK...",
    "..KhhsSSSSESK...",
    "..KhhSsSSSSSSK..",
    "..KhSSSSSBBBK...",
    "..KsSSSSBSMMK...",
    "...KsSSSSBBBK...",
    "....KsSSSBBK....",
    ".....KKKKKK.....",
    ".....KsSSsK.....",
    "...KTTTTTtTTK...",
    "...KTTTTTTTTK...",
    "...KTTtTTTTRK...",
    "...KTKtKTTTTK...",
    "...KTKSKTTTTK...",
    "...KTKSKTTTTK...",
    "...KtKSKTTTtK...",
    "...KTKsKTTTTK...",
    "....KKKPPPPK....",
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
    sheet.save(f'{out}/joao_sprites.png')
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
    gif[0].save(f'{out}/joao_andando.gif', save_all=True, append_images=gif[1:], duration=200, loop=0)

def retrato(out):
    random.seed(10)
    N = 48
    fig = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(fig)
    C = lambda k: PAL[k] + (255,)
    # camisa verde larga
    d.polygon([(2, 47), (5, 40), (14, 36), (34, 36), (43, 40), (46, 47)], fill=C('T'))
    d.line([(8, 41), (8, 47)], fill=C('t'))
    d.line([(40, 41), (40, 47)], fill=C('t'))
    d.line([(24, 41), (24, 47)], fill=C('W'))            # friso branco
    d.rectangle([32, 42, 35, 45], fill=C('W'))           # escudo
    d.line([(33, 43), (34, 43)], fill=C('R'))
    d.line([(33, 45), (34, 45)], fill=C('K'))
        # pescoco + gola
    d.rectangle([18, 30, 30, 38], fill=C('s'))
    d.polygon([(16, 36), (32, 36), (28, 40), (20, 40)], fill=C('s'))
    d.line([(16, 36), (20, 40), (28, 40), (32, 36)], fill=C('t'))
    d.line([(18, 35), (21, 38), (27, 38), (30, 35)], fill=C('C'))
    # orelhas
    d.ellipse([11, 19, 15, 28], fill=C('S'))
    d.ellipse([33, 19, 37, 28], fill=C('S'))
    d.point([(13, 22), (13, 23), (35, 22), (35, 23)], fill=C('s'))
    # cabeca: testa alta, careca na frente
    d.ellipse([13, 5, 35, 37], fill=C('S'))
    d.rectangle([13, 15, 35, 26], fill=C('S'))
    # cabelo raspado so nas laterais e atras
    d.arc([13, 5, 35, 32], 140, 205, fill=C('h'), width=3)
    d.arc([13, 5, 35, 32], 335, 40, fill=C('h'), width=3)
    for p in [(21, 8), (22, 8), (23, 7), (24, 7), (25, 7), (22, 9), (20, 10), (26, 8)]:
        d.point(p, fill=C('L'))
    # sobrancelhas grossas e retas
    d.line([(17, 16), (22, 16)], fill=C('H'), width=2)
    d.line([(26, 16), (31, 16)], fill=C('H'), width=2)
    # olhar fixo, serio
    for ex in (18, 27):
        d.line([(ex, 19), (ex + 3, 19)], fill=C('s'))
        d.point((ex, 20), fill=(232, 222, 210, 255))
        d.point((ex + 1, 20), fill=C('E'))
        d.point((ex + 2, 20), fill=C('E'))
        d.point((ex + 3, 20), fill=(232, 222, 210, 255))
        d.line([(ex, 21), (ex + 3, 21)], fill=C('s'))
    # nariz largo
    d.line([(24, 20), (24, 25)], fill=C('L'))
    d.line([(23, 21), (23, 25)], fill=C('s'))
    d.line([(21, 26), (27, 26)], fill=C('s'))
    d.point([(21, 25), (27, 25)], fill=C('s'))
    # bigode cheio caindo nos cantos + cavanhaque
    d.polygon([(19, 28), (29, 28), (30, 31), (28, 29), (20, 29), (18, 31)], fill=C('B'))
    d.line([(21, 30), (27, 30)], fill=C('M'))
    d.line([(18, 31), (19, 34)], fill=C('B'))
    d.line([(30, 31), (29, 34)], fill=C('B'))
    d.polygon([(22, 33), (26, 33), (25, 36), (24, 37), (23, 36)], fill=C('B'))
    for _ in range(14):
        x, y = random.randint(17, 31), random.randint(30, 36)
        if fig.getpixel((x, y))[:3] == PAL['S']:
            d.point((x, y), fill=C('s'))
    # contorno automatico
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
    # fundo estilo figurinha (azul-piscina pro roxo)
    bg = Image.new('RGBA', (N, N))
    for y in range(N):
        t = y / (N - 1)
        c = tuple(int(a + (b - a) * t) for a, b in zip((40, 170, 190), (110, 70, 170)))
        for x in range(N):
            bg.putpixel((x, y), c + (255,))
    bg.alpha_composite(o)
    ImageDraw.Draw(bg).rectangle([0, 0, N - 1, N - 1], outline=C('K'))
    bg.save(f'{out}/joao_retrato.png')
    bg.resize((N * 8, N * 8), Image.NEAREST).save(f'{out}/preview_retrato.png')

if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    sprites(out)
    retrato(out)

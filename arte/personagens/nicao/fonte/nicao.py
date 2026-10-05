from PIL import Image

PAL = {
    '.': None,
    'K': (38, 24, 20),      # contorno
    'H': (30, 22, 20),      # cabelo
    'h': (62, 46, 40),      # brilho do cabelo
    'S': (176, 120, 80),    # pele
    's': (138, 90, 58),     # sombra da pele
    'L': (204, 148, 104),   # luz da pele
    'E': (20, 14, 12),      # olho
    'B': (44, 32, 28),      # barba
    'b': (70, 52, 44),      # barba clara
    'M': (120, 70, 54),     # labio
    'T': (36, 44, 62),      # camiseta azul-marinho
    't': (24, 30, 44),      # sombra camiseta
    'U': (54, 66, 90),      # luz camiseta
    'P': (64, 80, 110),     # calca jeans
    'p': (46, 58, 84),      # sombra calca
    'F': (90, 90, 96),      # tenis
    'f': (225, 225, 230),   # sola
    'W': (245, 245, 245),   # fone branco
}

def pad(rows):
    return ['........' + r + '........' for r in rows]

FRONT_TOP = [
    "................",
    "....KKKKKKKK....",
    "...KHHhHHhHHK...",
    "..KHhHHHHhHHHK..",
    "..KHHHHhHHHHHK..",
    "..KHSLSSSSLSHK..",
    "..KSHHSSSSHHSK..",
    "..KSSSSSSSSSSK..",
    "..WSsEESSEEsSK..",
    "..KBSSSssSSSBK..",
    "..KBBBMMMMBBBK..",
    "..KBBBbBBbBBBK..",
    "...KBBBBBBBBK...",
    ".....KBBBBK.....",
    "...KKWsSSsTKK...",
    "..KTTWUTTUTTTK..",
    ".KTTUWTTTTTTTTK.",
    ".KTtTWTTTTTTtTK.",
    ".KtKTWTTTTTTKtK.",
    ".KSKTTTTTTTTKSK.",
    ".KSKTTTTTTTTKSK.",
    ".KSKtTTTTTTtKSK.",
    ".KsKTTTTTTTTKsK.",
    "..KKPPPPPPPPKK..",
]
BACK_TOP = [
    "................",
    "....KKKKKKKK....",
    "...KHHhHHhHHK...",
    "..KHhHHHHhHHHK..",
    "..KHHHHhHHHHHK..",
    "..KHHhHHHHhHHK..",
    "..KHHHHHhHHHHK..",
    "..KHhHHHHHHhHK..",
    "..KHHHHHHHHHHK..",
    "..KhHHHHHHHHhK..",
    "..KshhhhhhhhsK..",
    "..KsSSSSSSSSsK..",
    "...KsSSSSSSsK...",
    ".....KSSSSK.....",
    "...KKTTTTTTKK...",
    "..KTTTTTTTTTTK..",
    ".KTTTTTTTTTTTTK.",
    ".KTtTTTTTTTTtTK.",
    ".KtKTTTTTTTTKtK.",
    ".KSKTTTTTTTTKSK.",
    ".KSKTTTTTTTTKSK.",
    ".KSKtTTTTTTtKSK.",
    ".KsKTTTTTTTTKsK.",
    "..KKPPPPPPPPKK..",
]
LEGS_FRONT = [
    "...KPPPPPPPPK...",
    "...KPPPKKPPPK...",
    "...KPPK..KPPK...",
    "...KPPK..KPPK...",
    "...KpPK..KPpK...",
    "...KFFK..KFFK...",
    "..KFFFK..KFFFK..",
    "..KffKK..KKffK..",
]
SIDE_TOP = [
    "................",
    "....KKKKKKK.....",
    "...KHHhHHhHK....",
    "..KHhHHHHhHHK...",
    "..KHHHHhHHHHHK..",
    "..KHHhHHHSLLSK..",
    "..KHHHHSSHHSSK..",
    "..KHHHSSSSsESK..",
    "..KHHWsSSSSSSSK.",
    "..KHHsSSSSSssK..",
    "..KHSBBBBBBMMK..",
    "..KHBBBbBBBBBK..",
    "...KBBBBBBBBK...",
    "....KKBBBBK.....",
    "....KWsSSsK.....",
    "...KTWTTTUTK....",
    "...KTWTTTTTK....",
    "...KTTtTTTTK....",
    "...KTKtKTTTK....",
    "...KTKSKTTTK....",
    "...KTKSKTTTK....",
    "...KtKSKTTtK....",
    "...KTKsKTTTK....",
    "....KKKPPPK.....",
]
LEGS_SIDE_IDLE = [
    "....KPPPPPPK....",
    "....KPPPPPPK....",
    ".....KPPPPK.....",
    ".....KPPPPK.....",
    ".....KpPPpK.....",
    ".....KFFFFK.....",
    ".....KFFFFFK....",
    ".....KffffffK...",
]
LEGS_SIDE_WALK_A = [
    "....KPPPPPPK....",
    "....KPPPPPPK....",
    "...KpPK.KPPK....",
    "..KpPK...KPPK...",
    "..KppK...KPpK...",
    ".KFFK.....KFFK..",
    ".KFFFK....KFFFK.",
    ".KffKK....KfffK.",
]
LEGS_SIDE_WALK_B = [
    "....KPPPPPPK....",
    "....KPPPPPPK....",
    "...KPPK.KpPK....",
    "..KPPK...KppK...",
    "..KPpK...KppK...",
    ".KFFK.....KFFK..",
    ".KFFFK....KFFFK.",
    ".KffKK....KfffK.",
]

def lift_leg(legs, left):
    """levanta uma perna 1px (passo visto de frente/costas)"""
    cols = range(0, 8) if left else range(8, 16)
    rows = [list(r) for r in legs]
    out = [list(r) for r in legs]
    for y in range(2, len(rows)):
        for x in cols:
            out[y - 1][x] = rows[y][x] if y - 1 >= 2 else out[y - 1][x]
    for x in cols:
        out[-1][x] = '.'
    return [''.join(r) for r in out]

def swing_arms(top, left_up):
    """mao de um lado sobe 1px, do outro desce (balanco dos bracos)"""
    rows = [list(r) for r in top]
    def shift(col_l, col_r, up):
        for x in range(col_l, col_r + 1):
            col = [rows[y][x] for y in range(18, 24)]
            if up:
                col = col[1:] + ['.']
                col[-2] = 'K'
            else:
                col = [rows[18][x]] + col[:-1]
            for i, y in enumerate(range(18, 24)):
                rows[y][x] = col[i]
    return [''.join(r) for r in rows]

def render(rows, mirror=False):
    rows = pad(rows)
    assert len(rows) == 32, len(rows)
    img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        assert len(r) == 32, (y, r, len(r))
        for x, c in enumerate(r):
            col = PAL[c]
            if col:
                img.putpixel((31 - x if mirror else x, y), col + (255,))
    return img

def frames():
    down = [FRONT_TOP + LEGS_FRONT,
            FRONT_TOP + lift_leg(LEGS_FRONT, True),
            FRONT_TOP + lift_leg(LEGS_FRONT, False)]
    up = [BACK_TOP + LEGS_FRONT,
          BACK_TOP + lift_leg(LEGS_FRONT, True),
          BACK_TOP + lift_leg(LEGS_FRONT, False)]
    side = [SIDE_TOP + LEGS_SIDE_IDLE,
            SIDE_TOP + LEGS_SIDE_WALK_A,
            SIDE_TOP + LEGS_SIDE_WALK_B]
    return {
        'baixo': [render(f) for f in down],
        'esquerda': [render(f, mirror=True) for f in side],
        'direita': [render(f) for f in side],
        'cima': [render(f) for f in up],
    }

if __name__ == '__main__':
    import os, sys
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    fr = frames()
    sheet = Image.new('RGBA', (96, 128), (0, 0, 0, 0))
    for row, d in enumerate(['baixo', 'esquerda', 'direita', 'cima']):
        for col, im in enumerate(fr[d]):
            sheet.paste(im, (col * 32, row * 32))
    sheet.save(f'{out}/nicao_sprites.png')
    # preview ampliado com fundo
    S = 8
    prev = Image.new('RGBA', (96 * S + 40, 128 * S + 50), (120, 170, 110, 255))
    big = sheet.resize((96 * S, 128 * S), Image.NEAREST)
    prev.alpha_composite(big, (20, 25))
    prev.save(f'{out}/preview_sprites.png')
    # gif andando (ordem: idle, A, idle, B), devagar porque o Nicao e lento
    gif = []
    for d in ['baixo', 'direita', 'cima', 'esquerda']:
        f = fr[d]
        for _ in range(2):
            for im in [f[1], f[0], f[2], f[0]]:
                bg = Image.new('RGBA', (32, 32), (120, 170, 110, 255))
                bg.alpha_composite(im)
                gif.append(bg.resize((256, 256), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
    gif[0].save(f'{out}/nicao_andando.gif', save_all=True, append_images=gif[1:], duration=260, loop=0)

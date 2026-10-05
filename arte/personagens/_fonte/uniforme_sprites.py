import sys, os
from PIL import Image
sys.path.insert(0, '.')
import nicao, lucas, joao, matheus, beto, lukako, fabio, breno

CAIRU = dict(T=(24, 72, 214), t=(16, 52, 168), U=(70, 120, 245), K=(10, 36, 130), W=(255, 255, 255))
VERDE = dict(T=(30, 150, 70), t=(20, 112, 52), U=(86, 190, 112), K=(10, 70, 32), W=(255, 255, 255))

# (pasta com o sprite antigo, modulo com PAL, chaves da camisa a trocar, chaves de gola a escurecer, chaves de emblema a apagar)
CFG = {
    'nicao':   ('out',  nicao,   'Ttu', '', ''),
    'lucas':   ('outl', lucas,   'Ttu', '', ''),
    'joao':    ('outj', joao,    'TtU', '', 'RW'),
    'matheus': ('outm', matheus, 'TtU', 'N', 'R'),
    'beto':    ('outb', beto,    'TtU', 'N', 'RU'),
    'lukako':  ('outk', lukako,  'TtU', 'N', 'R'),
    'fabio':   ('outf', fabio,   'TtU', 'N', 'R'),
    'breno':   ('outp', breno,   'TtU', '', ''),
}
LOGO_FRONT = [(16, 17), (17, 17), (18, 17), (16, 18), (17, 18)]

def aplicar(name, cor):
    pasta, mod, cam, gola, emb = CFG[name]
    P = mod.PAL
    sheet = Image.open(f'{pasta}/{name}_sprites.png').convert('RGBA')
    px = sheet.load()
    shade = {P['T']: cor['T'], P['t']: cor['t'], P['U']: cor['U']}
    for k in gola:
        shade[P[k]] = cor['K']
    for k in emb:
        shade[P[k]] = cor['T']
    skin = {P['S'], P['s'], P['L']}
    for y in range(sheet.height):
        for x in range(sheet.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in shade:
                px[x, y] = shade[(r, g, b)] + (255,)
    # mangas curtas e logo
    for row in range(4):
        for col in range(3):
            ox, oy = col * 32, row * 32
            if row in (0, 3):
                xs, ys = (10, 21), (18, 19, 20)
            elif row == 2:      # direita
                xs, ys = (14,), (19, 20)
            else:               # esquerda (espelhado)
                xs, ys = (17,), (19, 20)
            for x in xs:
                for y in ys:
                    r, g, b, a = px[ox + x, oy + y]
                    if a and (r, g, b) in skin:
                        px[ox + x, oy + y] = (cor['t'] if y == ys[-1] else cor['T']) + (255,)
            if row == 0:
                for (x, y) in LOGO_FRONT:
                    px[ox + x, oy + y] = cor['W'] + (255,)
    return sheet

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    S = 8
    for variante, cor in (('cairu', CAIRU), ('verde', VERDE)):
        folha = Image.new('RGBA', (4 * (96 * S // 2 + 20), 2 * (128 * S // 2 + 20)), (120, 170, 110, 255))
        for i, n in enumerate(CFG):
            sh = aplicar(n, cor)
            sh.save(f'{out}/{n}_sprites_{variante}.png')
            big = sh.resize((96 * S // 2, 128 * S // 2), Image.NEAREST)
            folha.alpha_composite(big, ((i % 4) * (96 * S // 2 + 20) + 10, (i // 4) * (128 * S // 2 + 20) + 10))
        folha.save(f'{out}/todos_sprites_{variante}.png')

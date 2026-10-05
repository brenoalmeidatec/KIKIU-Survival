import random, sys
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
from nicao import PAL

random.seed(7)
N = 48
fig = Image.new('RGBA', (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(fig)
C = lambda k: PAL[k] + (255,)

# ombros / camiseta
d.polygon([(4, 47), (7, 40), (15, 37), (33, 37), (41, 40), (44, 47)], fill=C('T'))
d.line([(9, 41), (9, 47)], fill=C('t'))
d.line([(39, 41), (39, 47)], fill=C('t'))
d.line([(15, 38), (32, 38)], fill=C('U'))
# pescoco
d.rectangle([18, 31, 30, 38], fill=C('s'))
d.polygon([(17, 37), (31, 37), (28, 40), (20, 40)], fill=C('s'))
# orelhas
d.ellipse([10, 20, 15, 29], fill=C('S'))
d.ellipse([33, 20, 38, 29], fill=C('S'))
d.point([(12, 23), (12, 24), (35, 23), (35, 24)], fill=C('s'))
# rosto
d.ellipse([13, 8, 35, 38], fill=C('S'))
d.rectangle([14, 16, 34, 28], fill=C('S'))
# luz na testa e bochecha
for p in [(20, 13), (21, 13), (22, 12), (26, 12), (27, 13), (17, 21), (31, 21)]:
    d.point(p, fill=C('L'))
# cabelo (curto, crespinho, laterais baixas)
d.ellipse([12, 4, 36, 16], fill=C('H'))
d.rectangle([14, 10, 34, 12], fill=C('H'))
d.rectangle([13, 11, 14, 19], fill=C('H'))
d.rectangle([34, 11, 35, 19], fill=C('H'))
for _ in range(40):
    x, y = random.randint(14, 34), random.randint(4, 12)
    if fig.getpixel((x, y))[:3] == PAL['H']:
        d.point((x, y), fill=C('h'))
# sobrancelhas grossas
d.line([(17, 17), (22, 16)], fill=C('H'), width=2)
d.line([(26, 16), (31, 17)], fill=C('H'), width=2)
# olhos sonolentos: palpebra pesada
for ex in (18, 27):
    d.line([(ex, 20), (ex + 4, 20)], fill=C('s'))       # palpebra
    d.line([(ex, 21), (ex + 4, 21)], fill=C('E'))       # linha do olho
    d.point((ex + 1, 22), fill=(230, 220, 205, 255))
    d.point((ex + 2, 22), fill=C('E'))
    d.point((ex + 3, 22), fill=C('E'))
    d.point((ex + 4, 22), fill=(230, 220, 205, 255))
    d.line([(ex, 23), (ex + 4, 23)], fill=C('s'))
# nariz
d.line([(24, 22), (24, 26)], fill=C('L'))
d.line([(23, 23), (23, 26)], fill=C('s'))
d.point([(21, 27), (22, 28), (26, 28), (27, 27)], fill=C('s'))
d.line([(23, 28), (25, 28)], fill=C('s'))
# barba cheia
d.polygon([(14, 24), (16, 30), (19, 36), (24, 39), (29, 36), (32, 30), (34, 24),
           (34, 30), (31, 37), (24, 41), (17, 37), (14, 30)], fill=C('B'))
d.polygon([(15, 25), (17, 31), (20, 30), (20, 33), (28, 33), (28, 30), (31, 31), (33, 25),
           (33, 32), (29, 38), (24, 40), (19, 38), (15, 32)], fill=C('B'))
d.polygon([(19, 29), (22, 29), (24, 30), (26, 29), (29, 29), (30, 31), (18, 31)], fill=C('B'))
for _ in range(30):
    x, y = random.randint(15, 33), random.randint(28, 40)
    if fig.getpixel((x, y))[:3] == PAL['B']:
        d.point((x, y), fill=C('b'))
# boca
d.line([(21, 32), (27, 32)], fill=C('M'))
d.line([(22, 33), (26, 33)], fill=(150, 92, 72, 255))
# fone branco + fio
d.rectangle([11, 26, 13, 28], fill=C('W'))
d.line([(12, 29), (13, 35), (15, 40), (16, 47)], fill=C('W'))

# contorno automatico
out = fig.copy()
for y in range(N):
    for x in range(N):
        if fig.getpixel((x, y))[3] == 0:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < N and 0 <= ny < N and fig.getpixel((nx, ny))[3] == 0:
                out.putpixel((x, y), C('K'))
                break

bg = Image.new('RGBA', (N, N), (232, 206, 160, 255))
bd = ImageDraw.Draw(bg)
for y in range(N):
    if y > 30:
        bd.line([(0, y), (N, y)], fill=(214, 186, 140, 255))
bg.alpha_composite(out)
bd.rectangle([0, 0, N - 1, N - 1], outline=C('K'))
outdir = sys.argv[1]
bg.save(f'{outdir}/nicao_retrato.png')
bg.resize((N * 8, N * 8), Image.NEAREST).save(f'{outdir}/preview_retrato.png')

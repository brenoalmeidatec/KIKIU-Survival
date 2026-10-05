import sys, os
from PIL import Image, ImageEnhance, ImageFilter
U = '/root/.claude/uploads/6ba9e05a-030f-5eb6-bf76-b30a73755dea/'
# (arquivo, caixa quadrada x0,y0,x1,y1 na foto original)
CHARS = {
    'nicao':   ('e4b20987-image.png', (115, 395, 445, 725)),
    'lucas':   ('8d63d3bd-image.png', (0, 470, 300, 770)),
    'joao':    ('c008d1a9-image.png', (205, 70, 695, 560)),
    'matheus': ('c2dbba9f-image.png', (215, 50, 695, 530)),
    'beto':    ('3e139a59-image.png', (245, 55, 665, 475)),
    'lukako':  ('ac0a8833-image.png', (185, 145, 855, 815)),
    'fabio':   ('47084391-image.png', (215, 40, 575, 400)),
    'breno':   ('573248f3-image.png', (875, 950, 1975, 2050)),
}
G = 64      # grade do pixel art
COLORS = 28
SCALE = 10  # ampliacao nearest-neighbor

def make(name, box=None, grid=G, colors=COLORS, tall=0.125):
    f, b = CHARS[name]
    x0, y0, x1, y1 = box or b
    w = x1 - x0
    im = Image.open(U + f).convert('RGB').crop((x0, y0, x1, y1 + int(w * tall)))
    im = ImageEnhance.Contrast(im).enhance(1.15)
    im = ImageEnhance.Color(im).enhance(1.2)
    im = im.resize((grid, int(grid * (1 + tall))), Image.LANCZOS)
    im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    q = im.quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.NONE).convert('RGB')
    return q

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    names = list(CHARS)
    sheet = Image.new('RGB', (4 * 330, 2 * 330), (30, 30, 30))
    for i, n in enumerate(names):
        q = make(n)
        q.resize((320, 320), Image.NEAREST).save(f'{out}/prev_{n}.png')
        sheet.paste(q.resize((320, 320), Image.NEAREST), ((i % 4) * 330 + 5, (i // 4) * 330 + 5))
    sheet.save(f'{out}/sheet.png')

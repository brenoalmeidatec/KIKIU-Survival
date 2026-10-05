import sys, os
import numpy as np, cv2
from PIL import Image, ImageEnhance, ImageFilter, ImageDraw
sys.path.insert(0, '.')
from foto2pixel import CHARS, U

GW, GH = 80, 104
COLORS = 30
EXP = 1.25
TALL = GH / GW
BG = (240, 226, 188)
CAIRU = dict(T=(24, 72, 214), t=(16, 52, 168), U=(70, 120, 245), K=(10, 30, 110), W=(255, 255, 255))
VERDE = dict(T=(30, 150, 70), t=(20, 112, 52), U=(86, 190, 112), K=(10, 70, 32), W=(255, 255, 255))
# linha do pescoco (y da gola) por personagem, ajustada olhando as imagens
NY = dict(nicao=70, lucas=66, joao=74, matheus=73, beto=64, lukako=69, fabio=65, breno=71)

def crop(name, scale):
    f, (x0, y0, x1, y1) = CHARS[name]
    w = x1 - x0
    cx = (x0 + x1) / 2
    nw = w * EXP
    bx0, by0 = cx - nw / 2, y0 - w * 0.12
    arr = np.array(Image.open(U + f).convert('RGB'))
    M = 900
    arr = np.pad(arr, ((M, M), (M, M), (0, 0)), mode='edge')
    im = Image.fromarray(arr).crop((int(bx0 + M), int(by0 + M), int(bx0 + M + nw), int(by0 + M + nw * TALL)))
    return im.resize((GW * scale, GH * scale), Image.LANCZOS)

RECT = dict(nicao=(.12, .02, .70, .97))

def person_mask(hi, name='x'):
    h, w = hi.shape[:2]
    mask = np.zeros((h, w), np.uint8)
    fx, fy, fw, fh = RECT.get(name, (.08, .02, .84, .97))
    rect = (int(w * fx), int(h * fy), int(w * fw), int(h * fh))
    bgd, fgd = np.zeros((1, 65)), np.zeros((1, 65))
    cv2.grabCut(cv2.cvtColor(hi, cv2.COLOR_RGB2BGR), mask, rect, bgd, fgd, 6, cv2.GC_INIT_WITH_RECT)
    m = np.where((mask == 1) | (mask == 3), 255, 0).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    return m

def pixelize(im, colors=COLORS):
    im = ImageEnhance.Contrast(im).enhance(1.15)
    im = ImageEnhance.Color(im).enhance(1.2)
    im = im.resize((GW, GH), Image.LANCZOS)
    im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    return im.quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.NONE).convert('RGB')

def make(name, cor=CAIRU, uniform=True):
    S = 4
    hi = crop(name, S)
    m_hi = person_mask(np.array(hi), name)
    q = pixelize(hi)
    m = Image.fromarray(m_hi).resize((GW, GH), Image.NEAREST)
    out = Image.new('RGB', (GW, GH), BG)
    out.paste(q, (0, 0), m)
    if uniform:
        out = cairu(out, q, m, name, cor)
    # contorno escuro no recorte
    px, mp = out.load(), m.load()
    return out

def cairu(out, q, m, name, cor):
    ny = NY[name]
    mp = m.load()
    xs0 = [x for y in range(ny - 8, ny - 3) for x in range(GW // 4, 3 * GW // 4) if mp[x, y]]
    cx0 = sum(xs0) / len(xs0) if xs0 else GW / 2
    for y in range(max(0, ny - 12), GH):
        allow = 21 - 0.65 * (y - (ny - 12))
        for x in range(GW):
            if abs(x - cx0) > allow and mp[x, y]:
                mp[x, y] = 0
                out.putpixel((x, y), BG)
    xs = [x for y in range(ny - 8, ny - 3) for x in range(GW // 4, 3 * GW // 4) if mp[x, y]]
    cx = sum(xs) / len(xs) if xs else GW / 2
    nw = 12
    d = ImageDraw.Draw(out)
    # camiseta: ombros caindo ate as laterais
    sh_y = ny + 14
    poly = [(cx - nw, ny), (cx - nw - 6, ny + 1), (0, sh_y), (0, GH), (GW, GH), (GW, sh_y), (cx + nw + 6, ny + 1), (cx + nw, ny)]
    keep = out.copy()
    d.polygon(poly, fill=cor['T'])
    # sombra nas laterais e dobras
    d.line([(cx - nw - 6, ny + 1), (0, sh_y)], fill=cor['K'])
    d.line([(cx + nw + 6, ny + 1), (GW - 1, sh_y)], fill=cor['K'])
    # pescoco (pele da foto) dentro de elipse + gola
    ell = [cx - nw + 1, ny - 7, cx + nw - 1, ny + 7]
    mask_n = Image.new('L', out.size, 0)
    ImageDraw.Draw(mask_n).ellipse(ell, fill=255)
    top_only = Image.new('L', out.size, 0)
    ImageDraw.Draw(top_only).rectangle([0, 0, GW, ny + 2], fill=255)
    from PIL import ImageChops
    keep_mask = ImageChops.multiply(mask_n, top_only)
    out.paste(keep, (0, 0), keep_mask)
    d.arc(ell, 0, 180, fill=cor['K'], width=2)
    d.arc([ell[0] + 2, ell[1] + 2, ell[2] - 2, ell[3] - 2], 10, 170, fill=cor['U'])
    # logo "Cairu" branco no peito
    G = {'C': ["###", "#..", "#..", "#..", "###"],
         'a': [None, None, ".##", "#.#", ".##"],
         'i': ["#", None, "#", "#", "#"],
         'r': [None, None, "##", "#.", "#."],
         'u': [None, None, "#.#", "#.#", "###"]}
    lx, ly = int(cx + 9), ny + 17
    for ch in "Cairu":
        rows = G[ch]
        for yy, r in enumerate(rows):
            if r:
                for xx, c in enumerate(r):
                    if c == '#':
                        d.point((lx + xx, ly + yy), fill=cor['W'])
        lx += len(rows[0] or rows[2]) + 1
    return out

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    names = list(CHARS)
    S = 4
    sheet = Image.new('RGB', (4 * (GW * S + 10), 2 * (GH * S + 10)), (30, 30, 30))
    for i, n in enumerate(names):
        q = make(n)
        big = q.resize((GW * S, GH * S), Image.NEAREST)
        sheet.paste(big, ((i % 4) * (GW * S + 10) + 5, (i // 4) * (GH * S + 10) + 5))
    sheet.save(f'{out}/sheet4.png')

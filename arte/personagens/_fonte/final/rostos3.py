"""rosto.png: 27 quadros 52x52 (ordem QUADROS). Foto pixelada (GrabCut em escala reduzida),
fundo padrao, contorno escuro e gola azul Cairu igual em todos; boca/olhos animados por cima."""
import sys, os, cv2, numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, '.')
import foto2pixel as F
from final import QUADROS
U = '/root/.claude/uploads/6ba9e05a-030f-5eb6-bf76-b30a73755dea/'
BG = (74, 78, 96); OUT = (22, 18, 24); AZUL = (36, 84, 200); AZUL2 = (24, 56, 150); BRANCO = (230, 232, 240)
G = 50
FOTO = {'nicao': ('68d0401f-image.png', None)}
for k, (f, b) in F.CHARS.items():
    if k != 'nicao': FOTO[k] = (f, b)
AJ = {'nicao': {'topo': .55, 'queixo': 1.22}}


def face_box(g, hint):
    c = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    fs = c.detectMultiScale(g, 1.05, 4, minSize=(50, 50))
    if hint is None: return max(fs, key=lambda r: r[2])
    return min(fs, key=lambda r: (r[0] + r[2] / 2 - hint[0]) ** 2 + (r[1] + r[3] / 2 - hint[1]) ** 2)


def prep(nome, aj):
    f, box = FOTO[nome]
    img = cv2.imread(U + f)
    if nome == 'nicao':
        fx, fy, fw, fh = 29, 18, 172, 172
        mm = np.zeros(img.shape[:2], np.uint8)
        for (cx, cy, r) in [(78, 38, 13), (50, 2, 30)]: cv2.circle(mm, (cx, cy), r, 255, -1)
        img = cv2.inpaint(img, mm, 9, cv2.INPAINT_TELEA)
        ex = np.full((50, img.shape[1], 3), (42, 34, 30), np.uint8)
        ex = np.clip(ex.astype(int) + np.random.default_rng(3).integers(0, 14, ex.shape[:2])[..., None], 0, 255).astype(np.uint8)
        img = np.vstack([ex, img]); fy += 50
        elm = np.zeros(img.shape[:2], np.uint8); cv2.ellipse(elm, (116, 158), (93, 136), 0, 0, 360, 1, -1)
    else:
        elm = None
        x0, y0, x1, y1 = box
        s = 260 / max(1, (x1 - x0))
        img = cv2.resize(img, None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
        g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        fx, fy, fw, fh = [int(v) for v in face_box(g, ((x0 + x1) / 2 * s, (y0 + y1) / 2 * s))]
    s = 200 / fw
    img = cv2.resize(img, None, fx=s, fy=s, interpolation=cv2.INTER_AREA if s < 1 else cv2.INTER_CUBIC)
    if elm is not None: elm = cv2.resize(elm, (img.shape[1], img.shape[0]), interpolation=cv2.INTER_NEAREST)
    fx, fy, fw, fh = [int(v * s) for v in (fx, fy, fw, fh)]
    d = aj.get('d', (0, 0)); fx += d[0]; fy += d[1]
    pad = 300
    img = cv2.copyMakeBorder(img, pad, pad, pad, pad, cv2.BORDER_REPLICATE); fx += pad; fy += pad
    if elm is not None: elm = cv2.copyMakeBorder(elm, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=0)
    cx = fx + fw // 2
    half = int(fw * aj.get('zoom', 1.0))
    top = fy - int(fw * aj.get('topo', .6))
    crop = (cx - half, top, cx + half, top + 2 * half)
    sub = img[crop[1]:crop[3], crop[0]:crop[2]].copy()
    m = np.full(sub.shape[:2], cv2.GC_BGD, np.uint8)
    ox, oy = fx - crop[0], fy - crop[1]
    cv2.ellipse(m, (ox + fw // 2, oy + int(fh * .35)), (int(fw * .78), int(fh * 1.05)), 0, 0, 360, cv2.GC_PR_FGD, -1)
    cv2.rectangle(m, (ox + int(fw * .3), oy + fh), (ox + int(fw * .7), sub.shape[0] - 1), cv2.GC_PR_FGD, -1)
    cv2.ellipse(m, (ox + fw // 2, oy + int(fh * .55)), (int(fw * .38), int(fh * .45)), 0, 0, 360, cv2.GC_FGD, -1)
    bgm, fgm = np.zeros((1, 65)), np.zeros((1, 65))
    cv2.grabCut(sub, m, None, bgm, fgm, 4, cv2.GC_INIT_WITH_MASK)
    mk = ((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)).astype(np.uint8)
    if elm is not None:
        mk = elm[crop[1]:crop[3], crop[0]:crop[2]].copy()
    hsv = cv2.cvtColor(sub, cv2.COLOR_BGR2HSV)
    estranho = ((hsv[..., 0] > 75) & (hsv[..., 0] < 150) & (hsv[..., 1] > 90) & (hsv[..., 2] > 90)) | \
               ((hsv[..., 0] < 22) & (hsv[..., 1] > 170) & (hsv[..., 2] > 170)) | \
               ((hsv[..., 0] > 35) & (hsv[..., 0] <= 75) & (hsv[..., 1] > 90) & (hsv[..., 2] > 90)) | ((hsv[..., 1] < 45) & (hsv[..., 2] > 195))
    core = np.zeros_like(mk)
    cv2.ellipse(core, (ox + fw // 2, oy + int(fh * .55)), (int(fw * .42), int(fh * .5)), 0, 0, 360, 1, -1)
    if not aj.get('branco', True): estranho &= ~((hsv[..., 1] < 45) & (hsv[..., 2] > 195))
    mk = mk & (1 - (estranho & (core == 0)).astype(np.uint8))
    mk = cv2.morphologyEx(mk, cv2.MORPH_OPEN, np.ones((9, 9), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(mk)
    if n > 1: mk = (lab == 1 + np.argmax(st[1:, 4])).astype(np.uint8)
    mk = cv2.morphologyEx(mk, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8))
    yq = oy + int(fh * aj.get('queixo', 1.08))
    im = cv2.bilateralFilter(sub, 9, 30, 9)
    L = cv2.cvtColor(im, cv2.COLOR_BGR2LAB).astype(float)
    l = L[..., 0]; b = cv2.GaussianBlur(l, (0, 0), sub.shape[1] / 5); mu = l[mk > 0].mean()
    l = l - .3 * (b - mu); l = mu + (l - mu) * 1.22 + aj.get('luz', 0); L[..., 0] = np.clip(l, 0, 255)
    L[..., 1:] = 128 + (L[..., 1:] - 128) * 1.1
    im = cv2.cvtColor(L.astype(np.uint8), cv2.COLOR_LAB2RGB)
    sc = G / sub.shape[1]
    small = Image.fromarray(im).resize((G, G), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1, 60, 2))
    q = small.quantize(colors=20, method=Image.MEDIANCUT, dither=Image.NONE).convert('RGB')
    ms = np.array(Image.fromarray(mk * 255).resize((G, G), Image.BILINEAR)) > 120
    yqs = min(G - 6, int(yq * sc))
    a = np.array(q); outm = np.zeros((G, G, 3), np.uint8); outm[:] = BG
    ms[yqs + 1:, :] = False
    pw = max(4, int(fw * sc * .28)); pcx = int((ox + fw / 2) * sc)
    pele = np.median(a[int((oy + fh * .60) * sc):int((oy + fh * .70) * sc),
                       int((ox + fw * .22) * sc):int((ox + fw * .34) * sc)].reshape(-1, 3), 0).astype(int)
    outm[ms] = a[ms]
    allm = ms.copy()
    sombra = (pele * .74).astype(int)
    for y in range(yqs - 1, min(G, yqs + 5)):
        for x in range(pcx - pw, pcx + pw + 1):
            if not ms[y, x] or y > yqs:
                outm[y, x] = sombra if y <= yqs + 1 else pele; allm[y, x] = True
    ys = yqs + 4
    for y in range(ys, G):
        w = min(G // 2 + 1, int(pw + 4 + (y - ys) * 2.4))
        for x in range(pcx - w, pcx + w + 1):
            if 0 <= x < G: outm[y, x] = AZUL; allm[y, x] = True
    for k in range(4):
        y = ys + k
        if y >= G: break
        for x in (pcx - pw - 1 + k, pcx + pw + 1 - k): outm[y, x] = AZUL2
    for (x, y) in [(pcx - pw - 7, ys + 5), (pcx - pw - 6, ys + 5), (pcx - pw - 7, ys + 6)]:
        if 0 <= x < G and y < G: outm[y, x] = BRANCO
    sh = np.pad(allm, 1)
    borda = (~allm) & (sh[:-2, 1:-1] | sh[2:, 1:-1] | sh[1:-1, :-2] | sh[1:-1, 2:])
    outm[borda] = OUT
    rim = Image.fromarray(outm)
    boca_ = (int((ox + fw * .5) * sc) + aj.get('bx', 0), int((oy + fh * .80) * sc) + aj.get('by', 0))
    olhos = [(int((ox + fw * f_) * sc) + aj.get('ex', 0), int((oy + fh * .43) * sc) + aj.get('ey', 0)) for f_ in (.31, .69)]
    return rim, boca_, olhos, tuple(int(v) for v in pele), yqs, int(fw * sc * .5)


def fala(img, mx, my, yq, meia, est, sorri=False):
    """abre a boca deslocando o queixo para baixo (k px) como mandibula de verdade"""
    a = np.array(img).copy()
    k = {'c': 0, 'm': 1, 'o': 2, 'l': 2}[est]
    x0, x1 = mx - meia - 1, mx + meia + 2
    if k:
        a[my + k:yq + k + 1, x0:x1] = np.array(img)[my:yq + 1, x0:x1]
        for j in range(k): a[my + j, x0:x1] = np.array(img)[my - 1, x0:x1]
        w = {1: 2, 2: 3}[k] + (1 if est == 'l' else 0)
        esc, den, lab = (52, 20, 26), (232, 226, 216), (150, 82, 80)
        for j in range(k + 1):
            ww = w - (1 if j in (0, k) and k > 1 else 0)
            for x in range(mx - ww, mx + ww + 1): a[my + j, x] = esc
        if k == 2:
            for x in range(mx - w + 2, mx + w - 1): a[my, x] = den
        for x in range(mx - w + 1, mx + w): a[my + k + 1, x] = lab
    if sorri:
        for s_ in (-1, 1):
            x = mx + s_ * (({0: 3, 1: 3, 2: 4}[k]) + (1 if est == 'l' else 0)); a[my - 1, x] = (52, 20, 26)
    return Image.fromarray(a)


def sobrancelha(img, olhos, sobe=1):
    a = np.array(img).copy(); b = np.array(img)
    for (ex, ey) in olhos:
        for y in range(ey - 6, ey - 1):
            a[y - sobe, ex - 4:ex + 5] = b[y, ex - 4:ex + 5]
    return Image.fromarray(a)


def boca(img, mx, my, est):
    a = img.copy(); p = a.load(); w = 3
    if est == 'c': return a
    if est == 'm':
        for x in range(mx - w + 1, mx + w): p[x, my] = (70, 28, 32)
        for x in range(mx - w + 2, mx + w - 1): p[x, my + 1] = (150, 80, 78)
    else:
        for y in range(my, my + 3):
            e = 0 if y == my + 1 else 1
            for x in range(mx - w + e, mx + w + 1 - e): p[x, y] = (70, 28, 32)
        for x in range(mx - w + 2, mx + w - 1): p[x, my] = (236, 230, 222)
        for x in range(mx - w + 2, mx + w - 1): p[x, my + 3] = (150, 80, 78)
    return a


def piscar(img, olhos, pele):
    a = img.copy(); p = a.load(); esc = tuple(int(v * .82) for v in pele)
    for (ex, ey) in olhos:
        for x in range(ex - 2, ex + 3):
            p[x, ey - 1] = esc; p[x, ey] = pele; p[x, ey + 1] = (40, 26, 24)
    return a


EXPR = {'talk2': ('sob',), 'point': ('sob',), 'shrug': ('sob',), 'wave': ('sor',), 'laugh': ('sor', 'sob')}


def rosto(nome):
    r, (mx, my), olhos, pele, yq, meia = prep(nome, AJ.get(nome, {}))
    sh = Image.new('RGBA', (52 * len(QUADROS), 52), (0, 0, 0, 0))
    for i, nm in enumerate(QUADROS):
        p = nm.split('_')
        b = p[1] if len(p) > 1 and p[1] in ('c', 'm', 'o') else 'c'
        if nm.startswith('laugh'): b = 'o'
        if nm.startswith('wave'): b = 'm' if nm.endswith('a') else 'o'
        ex = EXPR.get(p[0], ())
        if nm.startswith('laugh'): b = 'l'
        im = sobrancelha(r, olhos) if 'sob' in ex else r
        im = fala(im, mx, my, yq, meia, b, 'sor' in ex)
        if nm in ('piscar', 'laugh_a', 'laugh_b'): im = piscar(im, olhos, pele)
        if nm == 'laugh_b': im = Image.fromarray(np.vstack([np.array(im)[1:], np.array(im)[-1:]]))
        fr = Image.new('RGB', (52, 52), (150, 150, 166)); fr.paste(im, (1, 1))
        sh.paste(fr, (i * 52, 0))
    return sh


if __name__ == '__main__':
    out = sys.argv[1]
    for n in sys.argv[2:]:
        os.makedirs(f'{out}/{n}', exist_ok=True); rosto(n).save(f'{out}/{n}/rosto.png'); print('ok', n, flush=True)

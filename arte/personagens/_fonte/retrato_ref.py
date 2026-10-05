"""Rosto para dialogo no formato da referencia: foto pixelada com paleta curta, fundo escuro, moldura.
Gera quadros de boca (fechada, meia, aberta) e piscar desenhados por cima."""
import sys, numpy as np, cv2
from PIL import Image
sys.path.insert(0, '.')
from traco import mascara

BG = (74, 78, 96)

def retrato(foto, face, crop, GW, GH, cores=28, elipse=None, manchas=None, circulo=None, topo_extra=0, cabelo=(30, 34, 42)):
    img = cv2.imread(foto); H0, W0 = img.shape[:2]
    if manchas:
        mm = np.zeros(img.shape[:2], np.uint8)
        for (cx, cy, r) in manchas: cv2.circle(mm, (cx, cy), r, 255, -1)
        img = cv2.inpaint(img, mm, 9, cv2.INPAINT_TELEA)
    if topo_extra:
        # completa o alto da cabeca cortado na foto com cabelo (textura escura)
        rng = np.random.default_rng(3)
        ex_ = np.zeros((topo_extra, W0, 3), np.float32) + np.array(cabelo, np.float32)
        ex_ += rng.normal(0, 9, ex_.shape[:2])[..., None]
        ex_ = cv2.GaussianBlur(ex_, (0, 0), 1.2)
        img = np.vstack([np.clip(ex_, 0, 255).astype(np.uint8), img])
        y_ = lambda v: v + topo_extra
        face = (face[0], y_(face[1]), face[2], face[3])
        if elipse: elipse = ((elipse[0][0], y_(elipse[0][1])), elipse[1])
        if circulo: circulo = None
        crop = (crop[0], y_(crop[1]), crop[2], y_(crop[3]))
        H0 += topo_extra
    mk = mascara(img, face) if not elipse else np.ones(img.shape[:2], np.uint8)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    fundo = ((hsv[..., 0] < 22) & (hsv[..., 1] > 150) & (hsv[..., 2] > 150)) | ((hsv[..., 1] < 40) & (hsv[..., 2] > 170))
    if elipse:
        nucleo = np.zeros(img.shape[:2], np.uint8); (ex, ey), (a, b) = elipse
        cv2.ellipse(nucleo, (ex, ey + 10), (int(a * .72), int(b * .78)), 0, 0, 360, 1, -1)
        fundo = fundo & (nucleo == 0)
    mk = cv2.morphologyEx(mk & ~fundo.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    if elipse:
        el = np.zeros_like(mk); (ex, ey), (a, b) = elipse; cv2.ellipse(el, (ex, ey), (a, b), 0, 0, 360, 1, -1)
        topo = np.zeros_like(mk); topo[:8] = 1
        mk = mk & el
        if circulo:
            cc = np.zeros_like(mk); (cx_, cy_), r_ = circulo; cv2.circle(cc, (cx_, cy_), r_, 1, -1); mk = mk & cc
    x0, y0, x1, y1 = crop
    pad = 80
    big = cv2.copyMakeBorder(img, pad, pad, pad, pad, cv2.BORDER_REPLICATE)
    bm = cv2.copyMakeBorder(mk, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=0)
    sl = (slice(y0 + pad, y1 + pad), slice(x0 + pad, x1 + pad))
    im = big[sl].copy(); m = bm[sl]
    im = cv2.bilateralFilter(im, 7, 25, 7)
    # luz: clareia o lado escuro um pouco
    lab = cv2.cvtColor(im, cv2.COLOR_BGR2LAB).astype(float)
    L = lab[..., 0]; bl = cv2.GaussianBlur(L, (0, 0), im.shape[1] / 4)
    L = L - .25 * (bl - L[m > 0].mean()); mu = L[m > 0].mean(); lab[..., 0] = np.clip(mu + (L - mu) * 1.18, 0, 255)
    lab[..., 1:] = 128 + (lab[..., 1:] - 128) * 1.15
    im = cv2.cvtColor(lab.astype(np.uint8), cv2.COLOR_LAB2BGR)
    rgb = cv2.cvtColor(im, cv2.COLOR_BGR2RGB)
    small = Image.fromarray(rgb).resize((GW, GH), Image.LANCZOS)
    ms = Image.fromarray(m * 255).resize((GW, GH), Image.BILINEAR).point(lambda v: 255 if v > 110 else 0)
    from PIL import ImageFilter
    small = small.filter(ImageFilter.MedianFilter(3)) if GW < 80 else small
    q = small.quantize(colors=cores, method=Image.MEDIANCUT, dither=Image.NONE).convert('RGB')
    out = Image.new('RGBA', (GW, GH), BG + (255,))
    out.paste(q, (0, 0), ms)
    return out

def boca(img, mx, my, w, estado, lip=(176, 100, 96)):
    """desenha a boca aberta por cima do retrato (coordenadas no grid)"""
    a = img.copy(); p = a.load()
    if estado == 'c': return a
    h = 1 if estado == 'm' else 3
    for y in range(my, my + h):
        for x in range(mx - w + (1 if y in (my, my + h - 1) and h > 1 else 0), mx + w + 1 - (1 if y in (my, my + h - 1) and h > 1 else 0)):
            p[x, y] = (64, 22, 28, 255)
    if estado == 'o':
        for x in range(mx - w + 2, mx + w - 1): p[x, my] = (236, 230, 222, 255)
        for x in range(mx - w + 2, mx + w - 1): p[x, my + h] = lip + (255,)
    else:
        for x in range(mx - w + 1, mx + w): p[x, my + 1] = lip + (255,)
    return a

def piscar(img, olhos, w, cor):
    a = img.copy(); p = a.load()
    for (ex, ey) in olhos:
        for y in (ey - 1, ey):
            for x in range(ex - w, ex + w + 1): p[x, y] = cor + (255,)
        for x in range(ex - w, ex + w + 1): p[x, ey + 1] = (40, 26, 24, 255)
    return a

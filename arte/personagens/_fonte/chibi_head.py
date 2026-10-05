import sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
import cena, retratos3 as R

HWC, HHC = 28, 26
EYE_Y, MOUTH_Y, NOSE_Y = 14, 20, 17
OUT = (26, 16, 34)

def luma(c): return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]
def sh(c, f): return tuple(max(0, min(255, int(v * f))) for v in c)
def sat(c, k=1.18):
    g = luma(c); return tuple(max(0, min(255, int(g + (v - g) * k))) for v in c)

EXPR = dict(nicao='sleepy', lucas='smirk', joao='serio', matheus='sleepy', beto='serio', lukako='serio', fabio='calmo', breno='sorriso')
HAIR_KEEP = dict(joao=True)

def remap(arr, ey):
    """arr: bool HxW (cabeca da foto 40x52). devolve bool 26x28 com a linha dos olhos em EYE_Y"""
    h, w = arr.shape
    im = Image.fromarray((arr * 255).astype('uint8'))
    top = im.crop((0, 0, w, ey)).resize((HWC, EYE_Y), Image.BOX)
    bot = im.crop((0, ey, w, h)).resize((HWC, HHC - EYE_Y), Image.BOX)
    out = Image.new('L', (HWC, HHC)); out.paste(top, (0, 0)); out.paste(bot, (0, EYE_Y))
    return np.array(out) > 120

TH = {}
FULL = {}

def parts(name):
    pal, mouth, eyes, skin = cena.cabeca(name)
    a = np.array(pal)
    m = a[..., 3] > 0
    rgb = a[..., :3].astype(float)
    L = rgb @ np.array([.3, .59, .11])
    ey = int(round((eyes[0][1] + eyes[1][1]) / 2))
    H, W = m.shape
    ys, xs = np.mgrid[0:H, 0:W]
    # limiar de Otsu entre cabelo/barba (escuro) e pele, olhando a parte de cima do rosto
    reg = m & (ys < ey + 9)
    vals = L[reg].astype(int)
    hist = np.bincount(np.clip(vals, 0, 255), minlength=256).astype(float)
    tot, sum_all = hist.sum(), (hist * np.arange(256)).sum()
    wb = sb = 0.0; best, thr = 0, 0
    for t in range(256):
        wb += hist[t]; sb += hist[t] * t
        if wb == 0 or wb == tot: continue
        wf = tot - wb; mb, mf = sb / wb, (sum_all - sb) / wf
        v = wb * wf * (mb - mf) ** 2
        if v > best: best, thr = v, t
    lo, hi_ = vals[vals <= thr], vals[vals > thr]
    if len(lo) < 10 or len(hi_) < 10 or hi_.mean() - lo.mean() < 38:
        thr = -1
    thr = TH.get(name, thr)
    sl = float(np.median(L[m & (L > thr) & (ys > ey) & (ys < ey + 14)])) if (m & (L > thr)).sum() else luma(skin)
    skin = tuple(int(v) for v in np.median(rgb[m & (L > thr) & (ys > ey - 2) & (ys < ey + 14)], axis=0)) if thr > 0 else skin
    dark = m & (L <= thr)
    cx = (eyes[0][0] + eyes[1][0]) / 2
    hair = dark & (ys <= ey - 5)
    side = dark & (np.abs(xs - cx) > 0.34 * W) & (ys > ey - 5) & (ys < ey + 7)
    hair = hair | side
    beard = dark & (ys >= ey + 6)
    low = m & (ys >= ey + 9)
    cover = (beard & (ys >= ey + 9)).sum() / max(1, low.sum())
    if cover < FULL.get(name, 0.62):
        beard = beard & (np.abs(xs - cx) < 0.26 * W)
    def dk(msk):
        px_ = rgb[msk]; l_ = L[msk]
        return np.mean(px_[l_ <= np.percentile(l_, 45)], axis=0)
    hc = dk(hair) if hair.sum() > 8 else None
    bc = dk(beard) if beard.sum() > 8 else None
    sil = remap(m, ey)
    hm = remap(hair, ey) & sil if hair.sum() > 8 else np.zeros_like(sil)
    bm = remap(beard, ey) & sil if beard.sum() > 8 else np.zeros_like(sil)
    return dict(sil=sil, hair=hm, beard=bm, hc=hc, bc=bc, skin=skin, eyes=eyes, mouth=mouth, src=(m, ey))

def clean_colors(p):
    skin = sat(p['skin'], 1.22)
    skin = tuple(int(v) for v in skin)
    hc = tuple(int(v) for v in (sat(p['hc'], 1.1) if p['hc'] is not None else sh(skin, .45)))
    bc = tuple(int(v) for v in (sat(p['bc'], 1.1) if p['bc'] is not None else hc))
    hc = sh(hc, .85) if luma(hc) > 90 else hc
    return skin, hc, bc

def head_front(name, p, boca='c', olhos='aberto'):
    skin, hc, bc = clean_colors(p)
    s2, s3, s4 = sh(skin, .85), sh(skin, .7), sh(skin, 1.14)
    h2, h3 = sh(hc, 1.35), sh(hc, .7)
    im = Image.new('RGBA', (HWC, HHC), (0, 0, 0, 0)); px = im.load()
    sil, hm, bm = p['sil'], p['hair'], p['beard']
    for y in range(HHC):
        for x in range(HWC):
            if not sil[y, x]: continue
            c = skin
            if x >= 21 or y >= 23: c = s2
            if x >= 24 and y >= 12: c = s3 if y > 20 else s2
            if 5 <= x <= 11 and 6 <= y <= 9 and not hm[y, x]: c = s4
            px[x, y] = c + (255,)
    for y in range(HHC):
        for x in range(HWC):
            if hm[y, x]:
                c = hc
                if y < 5 and x < 15: c = h2
                elif (x + y) % 6 == 0 and y < 7: c = h2
                elif x >= 22 or y > 9: c = h3
                px[x, y] = c + (255,)
            if bm[y, x]:
                px[x, y] = (bc if (x + y) % 5 else sh(bc, 1.25)) + (255,)
    d = ImageDraw.Draw(im)
    ex = [(8, EYE_Y), (19, EYE_Y)]
    esc = (22, 14, 20, 255)
    ex_ = EXPR[name]
    for k, (x, y) in enumerate(ex):
        if olhos == 'piscar':
            d.line([(x - 1, y + 1), (x + 2, y + 1)], fill=esc)
        elif olhos == 'apertado':
            d.point([(x - 1, y + 2), (x, y + 1), (x + 1, y + 1), (x + 2, y + 2)], fill=esc)
        else:
            alt = 2 if ex_ in ('sleepy',) else 3
            d.rectangle([x, y + (3 - alt), x + 1, y + 2], fill=esc)
            d.point((x, y + (3 - alt)), fill=(250, 250, 250, 255))
            if ex_ == 'sleepy':
                d.line([(x - 1, y - 1 + 0), (x + 2, y - 1 + 0)], fill=s3 + (255,))
        # sobrancelha
        by = y - 3 - (1 if (ex_ == 'smirk' and k == 1) else 0)
        d.line([(x - 1, by), (x + 2, by)], fill=sh(hc, 1.0) + (255,) if p['hc'] is not None else s3 + (255,))
    # nariz
    d.point([(14, NOSE_Y), (13, NOSE_Y + 1), (14, NOSE_Y + 1)], fill=s3 + (255,))
    # boca
    mc = (60, 20, 28, 255); dente = (246, 240, 232, 255); lingua = (214, 92, 108, 255); lab = sh(skin, .62) + (255,)
    my = MOUTH_Y
    if boca == 'c':
        if ex_ == 'sorriso':
            d.line([(12, my), (16, my)], fill=lab); d.point([(11, my - 1), (17, my - 1)], fill=lab)
        elif ex_ == 'smirk':
            d.line([(12, my), (15, my)], fill=lab); d.point((16, my - 1), fill=lab)
        else:
            d.line([(12, my), (16, my)], fill=lab)
    elif boca == 'm':
        d.rectangle([12, my - 1, 16, my + 1], fill=mc)
    elif boca == 'o':
        d.rectangle([11, my - 1, 17, my + 2], fill=mc)
        d.line([(12, my - 1), (16, my - 1)], fill=dente)
        d.line([(13, my + 2), (15, my + 2)], fill=lingua)
    elif boca == 'r':
        d.rectangle([10, my - 2, 18, my + 2], fill=mc)
        d.line([(11, my - 2), (17, my - 2)], fill=dente); d.line([(11, my - 1), (17, my - 1)], fill=dente)
        d.line([(12, my + 2), (16, my + 2)], fill=lingua)
    # barba por cima da boca fechada: mantem boca visivel
    return im

if __name__ == '__main__':
    names = list(R.CHARS)
    S = 10
    sheet = Image.new('RGBA', (4 * (HWC * S + 20), 2 * (HHC * S + 20)), (230, 226, 240, 255))
    for i, n in enumerate(names):
        p = parts(n)
        h = head_front(n, p, 'm')
        o = Image.new('RGBA', (HWC + 2, HHC + 2), (0, 0, 0, 0)); o.alpha_composite(h, (1, 1))
        from sprites4 import outline
        o = outline(o)
        sheet.alpha_composite(o.resize(((HWC + 2) * S, (HHC + 2) * S), Image.NEAREST), ((i % 4) * (HWC * S + 20) + 8, (i // 4) * (HHC * S + 20) + 8))
    sheet.save('outx/heads_chibi.png')

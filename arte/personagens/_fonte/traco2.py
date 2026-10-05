"""Rosto tracado da foto (formas e sombras reais) + olhos, sobrancelhas e boca redesenhados limpos
nas posicoes medidas na foto (boca animavel)."""
import sys, numpy as np, cv2
from PIL import Image
sys.path.insert(0, '.')
from headgen import ramp, mix, OUT
from traco import mascara

def base(path, crop, N, P, face, elipse, flat=.8):
    img = cv2.imread(path); H0, W0 = img.shape[:2]
    mk = mascara(img, face)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    fundo = ((hsv[..., 0] < 22) & (hsv[..., 1] > 150) & (hsv[..., 2] > 150)) | ((hsv[..., 1] < 40) & (hsv[..., 2] > 170))
    mk = cv2.morphologyEx(mk & ~fundo.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    pad = 60; x0, y0, x1, y1 = crop
    big = cv2.copyMakeBorder(img, pad, pad, pad, pad, cv2.BORDER_REPLICATE)
    bm = cv2.copyMakeBorder(mk, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=0)
    fora = np.ones_like(bm); fora[pad:pad + H0, pad:pad + W0] = 0
    el = np.zeros_like(bm); (ex, ey), (ax_, ay_) = elipse
    cv2.ellipse(el, (ex + pad, ey + pad), (ax_, ay_), 0, 0, 360, 1, -1)
    bm = (bm | fora) & el
    sl = (slice(y0 + pad, y1 + pad), slice(x0 + pad, x1 + pad))
    im, m, fo = big[sl], bm[sl], fora[sl]
    sm = im.copy()
    for _ in range(5): sm = cv2.bilateralFilter(sm, 9, 35, 9)
    lab = cv2.cvtColor(sm, cv2.COLOR_BGR2LAB).astype(float)
    L = lab[..., 0]; mm = m > 0
    blur = cv2.GaussianBlur(L, (0, 0), (x1 - x0) / 5)
    L = L - flat * (blur - L[mm].mean())                       # tira a luz lateral da foto
    small = cv2.resize(L, (N, N), interpolation=cv2.INTER_AREA)
    ms = cv2.resize(m.astype(np.float32), (N, N), interpolation=cv2.INTER_AREA) > .5
    fs = cv2.resize(fo.astype(np.float32), (N, N), interpolation=cv2.INTER_AREA) > .3
    C = np.hypot(lab[..., 1] - 128, lab[..., 2] - 128)
    Cs = cv2.resize(C, (N, N), interpolation=cv2.INTER_AREA)
    Lr = cv2.resize(lab[..., 0], (N, N), interpolation=cv2.INTER_AREA)
    sk, hr, bd = ramp(P['skin']), ramp(P['hair']), ramp(P['beard'])
    out = np.zeros((N, N, 4), np.uint8)
    pelo = ms & (Cs < P.get('c_pelo', 17)) & (Lr < 165)
    pele = ms & ~pelo
    v = small[pele & ~fs]
    q1, q2 = np.percentile(v, [25, 72])
    out[pele & (small < q1)] = sk['lo'] + (255,)
    out[pele & (small >= q1) & (small < q2)] = sk['mid'] + (255,)
    out[pele & (small >= q2)] = sk['hi'] + (255,)
    yy = np.arange(N)[:, None] * np.ones((1, N))
    cab = pelo & (yy < N * P.get('linha_cab', .30))
    out[pelo & ~cab] = bd['mid'] + (255,)
    out[pelo & ~cab & (Lr < 40)] = bd['lo'] + (255,)
    out[cab] = hr['mid'] + (255,)
    out[cab & (Lr < 40)] = hr['lo'] + (255,)
    out[fs & ms] = hr['mid'] + (255,)
    # limpeza
    for _ in range(3):
        res = out.copy()
        for y in range(1, N - 1):
            for x in range(1, N - 1):
                if not ms[y, x]: continue
                win = [tuple(p) for p in out[y - 1:y + 2, x - 1:x + 2].reshape(-1, 4) if p[3]]
                me = tuple(out[y, x]); cnt = {c: win.count(c) for c in set(win)}
                best = max(cnt, key=cnt.get)
                if cnt.get(me, 0) <= 2 and cnt[best] >= 4: res[y, x] = best
        out = res
    if P.get('simetria', True):
        cx = (P['centro'] - x0) * N / (x1 - x0)
        src = out.copy(); msk = ms.copy()
        for x in range(N):
            xm = int(round(2 * cx - x))
            if x < cx and 0 <= xm < N:
                out[:, x] = src[:, xm]; ms[:, x] = msk[:, xm]
        # volume: sombra na borda direita
        a = out[..., 3] > 0
        borda = a & ~np.roll(a, -1, 1) | a & ~np.roll(a, -2, 1)
        lo_ = mix(P['skin'], (70, 30, 60), .38)
        for y, x in zip(*np.where(borda)):
            c = tuple(out[y, x, :3])
            if c in (ramp(P['skin'])['mid'], ramp(P['skin'])['hi']): out[y, x, :3] = lo_
    return out, ms

def to_grid(p, crop, N):
    x0, y0, x1, y1 = crop
    return ((p[0] - x0) * N / (x1 - x0), (p[1] - y0) * N / (y1 - y0))

def feicoes(out, N, P, crop, mouth='c', eyes='open'):
    sk, hr = ramp(P['skin']), ramp(P['hair'])
    s = N / 48
    def px(x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < N and 0 <= y < N: out[y, x] = tuple(c) + (255,)
    def rect(xa, ya, xb, yb, c):
        for yy in range(int(round(ya)), int(round(yb)) + 1):
            for xx in range(int(round(xa)), int(round(xb)) + 1): px(xx, yy, c)
    for (ex, ey) in P['olhos']:
        cx, cy = to_grid((ex, ey), crop, N)
        ew = max(1, round(2.2 * s))
        # sobrancelha
        by = cy - 3.2 * s
        rect(cx - ew - 1 * s, by - .5 * s, cx + ew + 1 * s, by + .4 * s, hr['lo'])
        if eyes == 'blink':
            rect(cx - ew, cy, cx + ew, cy, OUT); continue
        rect(cx - ew, cy - .5 * s, cx + ew, cy + .5 * s, (236, 228, 218))
        rect(cx - .6 * s, cy - .6 * s, cx + .6 * s, cy + .6 * s, (54, 32, 26))
        rect(cx - ew, cy - 1.4 * s, cx + ew, cy - 1.0 * s, OUT)
        if N >= 40: px(cx - .5, cy - .6, (250, 248, 244))
    mx, my = to_grid(P['boca'], crop, N)
    lip = P['lip']; lip_lo = mix(lip, (90, 40, 50), .4); dentro = (70, 26, 32)
    mw = P.get('boca_l', 3.4) * s
    abre = {'c': 0, 'm': 1.2 * s, 'o': 2.6 * s}[mouth]
    rect(mx - mw, my - 1.0 * s, mx + mw, my - .5 * s, lip_lo)
    if abre:
        rect(mx - mw + .5, my, mx + mw - .5, my + abre, dentro)
        if mouth == 'o': rect(mx - mw + 1, my, mx + mw - 1, my + .4 * s, (240, 236, 228))
    else:
        rect(mx - mw, my, mx + mw, my, mix(lip_lo, OUT, .45))
    rect(mx - mw + .5, my + abre + .5 * s, mx + mw - .5, my + abre + 1.5 * s, lip)

def contorno(out):
    a = out[..., 3] > 0
    pd = np.pad(a, 1); nb = pd[:-2, 1:-1] | pd[2:, 1:-1] | pd[1:-1, :-2] | pd[1:-1, 2:]
    out = out.copy(); out[nb & ~a] = OUT + (255,)
    return Image.fromarray(out, 'RGBA')

_cache = {}
def rosto(P, N, mouth='c', eyes='open'):
    key = (id(P), N)
    if key not in _cache: _cache[key] = base(P['foto'], P['crop'], N, P, P['face'], P['elipse'])
    out, ms = _cache[key]; out = out.copy()
    feicoes(out, N, P, P['crop'], mouth, eyes)
    return contorno(out)

NICAO = dict(skin=(206, 150, 112), hair=(46, 36, 34), beard=(58, 44, 40), lip=(184, 108, 106),
             foto='/root/.claude/uploads/6ba9e05a-030f-5eb6-bf76-b30a73755dea/68d0401f-image.png',
             crop=(12, -18, 222, 242), face=(29, 18, 172, 172), elipse=((117, 112), (90, 130)),
             olhos=[(81, 89), (147, 89)], boca=(115, 165), boca_l=3.4, centro=115)

if __name__ == '__main__':
    P = NICAO
    foto = Image.open(P['foto']).convert('RGBA')
    c = Image.new('RGBA', (236 + 20 + 288 * 2 + 40 + 26 * 8, 300), (240, 226, 188, 255)); c.alpha_composite(foto, (0, 0))
    c.alpha_composite(rosto(P, 48).resize((288, 288), Image.NEAREST), (256, 0))
    c.alpha_composite(rosto(P, 48, 'o').resize((288, 288), Image.NEAREST), (256 + 298, 0))
    c.alpha_composite(rosto(P, 26).resize((208, 208), Image.NEAREST), (256 + 600, 0))
    c.save('chk.png')

"""Pixel art tracada da foto: mascara da cabeca, suavizacao, reducao, mapeamento para paleta curta e limpeza."""
import sys, numpy as np, cv2
from PIL import Image
sys.path.insert(0, '.')
from headgen import ramp, mix, OUT

def mascara(img, face):
    fx, fy, fw, fh = face
    H, W = img.shape[:2]
    m = np.full((H, W), cv2.GC_PR_BGD, np.uint8)
    cv2.ellipse(m, (fx + fw // 2, fy + fh // 2 + fh // 8), (int(fw * .62), int(fh * .80)), 0, 0, 360, cv2.GC_PR_FGD, -1)
    cv2.ellipse(m, (fx + fw // 2, fy + fh // 2 + fh // 10), (int(fw * .38), int(fh * .52)), 0, 0, 360, cv2.GC_FGD, -1)
    m[:, :max(1, fx - fw // 6)] = cv2.GC_BGD; m[:, min(W - 1, fx + fw + fw // 6):] = cv2.GC_BGD
    bg = np.zeros((1, 65)); fg = np.zeros((1, 65))
    cv2.grabCut(img, m, None, bg, fg, 8, cv2.GC_INIT_WITH_MASK)
    mk = np.where((m == 1) | (m == 3), 1, 0).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(mk)
    mk = (lab == 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])).astype(np.uint8)
    mk = cv2.morphologyEx(mk, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8))
    mk = cv2.morphologyEx(mk, cv2.MORPH_OPEN, np.ones((9, 9), np.uint8))
    return mk

def paleta(P):
    sk, hr, bd = ramp(P['skin']), ramp(P['hair']), ramp(P['beard'])
    cores = [sk['hi'], sk['mid'], sk['lo'], mix(sk['lo'], (60, 30, 40), .35),
             hr['hi'], hr['mid'], hr['lo'], bd['mid'],
             P['lip'], mix(P['lip'], (90, 40, 50), .4), (236, 228, 218), (40, 26, 26)]
    return np.array(cores, float)

def traca(path, crop, N, P, face=None, ganho=1.0, elipse=None, olhos=None, boca=None):
    img = cv2.imread(path)
    if face is None:
        g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        c = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
        face = max(c.detectMultiScale(g, 1.05, 3), key=lambda r: r[2])
    mk = mascara(img, face)
    H0, W0 = img.shape[:2]
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    fundo = ((hsv[..., 0] < 22) & (hsv[..., 1] > 150) & (hsv[..., 2] > 150)) | ((hsv[..., 1] < 40) & (hsv[..., 2] > 170))
    mk = mk & ~fundo.astype(np.uint8)
    mk = cv2.morphologyEx(mk, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    x0, y0, x1, y1 = crop
    pad = 40
    big = cv2.copyMakeBorder(img, pad, pad, pad, pad, cv2.BORDER_REPLICATE)
    bm = cv2.copyMakeBorder(mk, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=0)
    fora = np.ones_like(bm); fora[pad:pad + H0, pad:pad + W0] = 0
    if elipse:
        el = np.zeros_like(bm); (ex, ey), (ax_, ay_) = elipse
        cv2.ellipse(el, (ex + pad, ey + pad), (ax_, ay_), 0, 0, 360, 1, -1)
        bm = (bm | fora) & el
    im = big[y0 + pad:y1 + pad, x0 + pad:x1 + pad]; m = bm[y0 + pad:y1 + pad, x0 + pad:x1 + pad]
    fo = cv2.resize(fora[y0 + pad:y1 + pad, x0 + pad:x1 + pad].astype(np.float32), (N, N), interpolation=cv2.INTER_AREA) > .3
    sm = im.copy()
    for _ in range(4): sm = cv2.bilateralFilter(sm, 9, 30, 7)
    rgb = cv2.cvtColor(sm, cv2.COLOR_BGR2RGB)
    # normaliza luz: estica contraste dentro da mascara
    small = cv2.resize(rgb, (N, N), interpolation=cv2.INTER_AREA).astype(float)
    ms = cv2.resize(m.astype(np.float32), (N, N), interpolation=cv2.INTER_AREA) > .5
    v = small[ms]; lo, hi = np.percentile(v, 2, 0), np.percentile(v, 98, 0)
    small = np.clip((small - lo) / (hi - lo + 1e-6), 0, 1)
    # converte para a faixa da paleta: escala pela luminancia da pele do perfil
    pal = paleta(P)
    pmin, pmax = pal.min(0), pal.max(0)
    tgt = small * (pmax - pmin) + pmin
    Lp = cv2.cvtColor(pal[None].astype(np.uint8), cv2.COLOR_RGB2LAB)[0].astype(float)
    Lt = cv2.cvtColor(np.clip(tgt, 0, 255).astype(np.uint8), cv2.COLOR_RGB2LAB).astype(float)
    w = np.array([1.0, ganho * 1.6, ganho * 1.6])
    d = (((Lt[:, :, None, :] - Lp[None, None]) * w) ** 2).sum(-1)
    yy, xx = np.mgrid[0:N, 0:N]
    def zona(boxes):
        z = np.zeros((N, N), bool)
        for (bx0, by0, bx1, by1) in boxes or []:
            sx = N / (x1 - x0); sy = N / (y1 - y0)
            z[int((by0 - y0) * sy):int(np.ceil((by1 - y0) * sy)), int((bx0 - x0) * sx):int(np.ceil((bx1 - x0) * sx))] = True
        return z
    zo, zb = zona(olhos), zona(boca)
    d[..., 10][~zo] += 1e9
    d[..., 8][~zb] += 1e9; d[..., 9][~zb] += 1e9
    idx = d.argmin(-1)
    idx[fo & ms] = 5
    out = np.zeros((N, N, 4), np.uint8)
    out[..., :3] = pal[idx].astype(np.uint8); out[..., 3] = ms * 255
    # limpeza: pixel isolado vira o vizinho mais comum
    for _ in range(2):
        res = out.copy()
        for y in range(1, N - 1):
            for x in range(1, N - 1):
                if not ms[y, x]: continue
                win = [tuple(p) for p in out[y - 1:y + 2, x - 1:x + 2].reshape(-1, 4) if p[3]]
                me = tuple(out[y, x]); cnt = {q: win.count(q) for q in set(win)}
                best = max(cnt, key=cnt.get)
                if cnt.get(me, 0) == 1 and cnt[best] >= 4: res[y, x] = best
        out = res
    a = out[..., 3] > 0
    pd = np.pad(a, 1); nb = pd[:-2, 1:-1] | pd[2:, 1:-1] | pd[1:-1, :-2] | pd[1:-1, 2:]
    out[nb & ~a] = OUT + (255,)
    return Image.fromarray(out, 'RGBA')

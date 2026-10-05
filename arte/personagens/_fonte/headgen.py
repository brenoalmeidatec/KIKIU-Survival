"""Cabecas chibi desenhadas por codigo a partir de parametros (pele, cabelo, barba, tracos).
Mesma geometria para frente/lado/costas e para qualquer resolucao N -> estilo unico e harmonico."""
import numpy as np
from PIL import Image

OUT = (34, 24, 30)

def mix(a, b, t): return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))
def ramp(base):
    """sombra puxa para vinho, luz puxa para amarelo quente (mesmo para todos)"""
    return dict(lo=mix(base, (70, 30, 60), .38), mid=base, hi=mix(base, (255, 232, 190), .22))

PERFIS = {
    'nicao': dict(skin=(204, 148, 104), hair=(70, 54, 46), beard=(64, 48, 44), estilo='fade', barba='cheia', sobr=1.0, olho='pesado', face=1.0),
}

def grid(N):
    ax = (np.arange(N) + .5) / N * 2 - 1
    return np.meshgrid(ax, ax)

def se(X, Y, cx, cy, rx, ry, p=2.0):
    return (np.abs((X - cx) / rx) ** p + np.abs((Y - cy) / ry) ** p) < 1

def shade_of(mask, k):
    """borda inferior/direita (sombra) e superior/esquerda (luz) de uma mascara"""
    lo = mask & ~np.roll(np.roll(mask, -k, 0), -k, 1)
    hi = mask & ~np.roll(np.roll(mask, k, 0), k, 1)
    return lo, hi

def head(perfil, view='front', mouth='c', eyes='open', N=26):
    P = perfil; X, Y = grid(N); k = 1 if N < 40 else 2
    sk = ramp(P['skin']); hr = ramp(P['hair']); bd = ramp(P['beard']) if P.get('barba') else None
    img = np.zeros((N, N, 4), np.uint8)
    def paint(mask, col): img[mask] = col + (255,)
    fw = P.get('face', 1.0)
    chk = ((np.arange(N)[:, None] + np.arange(N)[None, :]) % 2) == 0
    big = N >= 40
    def textura(mask, col, paso=11):
        if not big: return
        gx, gy = np.floor(X * N / 3), np.floor(Y * N / 3)
        paint(mask & (((gx * 5 + gy * 3) % paso) == 0), col)
    if view == 'front':
        face = se(X, Y, 0, .14, .80 * fw, .80, 2.5)
        ears = se(X, Y, -.84 * fw, .14, .13, .19) | se(X, Y, .84 * fw, .14, .13, .19)
        paint(ears, sk['mid']); paint(face, sk['mid'])
        paint(se(X, Y, -.84 * fw, .15, .06, .10) | se(X, Y, .84 * fw, .15, .06, .10), sk['lo'])
        lo, hi = shade_of(face, k); paint(lo, sk['lo'])
        # nariz
        paint(se(X, Y, 0, .30, .10 * fw, .05) & face, sk['lo'])
        paint(se(X, Y, -.015, .20, .035, .09) & face, sk['hi'])
        # barba
        if P.get('barba') == 'cheia':
            linha = .44 - .52 * np.abs(X) / fw
            bmask = (face & (Y > linha)) | (face & (np.abs(X) > .66 * fw) & (Y > .02))
            paint(bmask, bd['mid']); l2, h2 = shade_of(bmask, k); paint(l2 & bmask, bd['lo'])
            paint(se(X, Y, 0, .50, .34, .09) & face, bd['hi'])           # bigode/queixo mais claro (volume)
            textura(bmask, bd['lo'], 9)
        # cabelo
        if P['estilo'] == 'fade':
            topo = se(X, Y, 0, -.12, .90 * fw, .88, 2.2) & (Y < -.34 + .24 * (X / fw) ** 2)
            lado = (np.abs(X) > .64 * fw) & (Y < .14) & face
            hair = topo | lado
            paint(hair, hr['mid'])
            h_lo, h_hi = shade_of(hair, k)
            paint(h_lo & (Y > -.4), hr['lo']); paint(h_hi & (Y < -.3), hr['hi'])
            paint(se(X, Y, -.30, -.52, .22, .08) & topo, hr['hi'])        # brilho
            textura(topo, hr['hi'], 13)
        # sobrancelhas grossas
        for sx in (-1, 1):
            paint(se(X, Y, sx * .36 * fw, -.13, .22, .055 * P['sobr'] + .025, 2.0), hr['lo'])
        # olhos
        ey = .06
        for sx in (-1, 1):
            cx = sx * .36 * fw
            if eyes == 'blink':
                paint(se(X, Y, cx, .09, .14, .035), OUT)
            else:
                e = se(X, Y, cx, ey, .105, .15, 2.0); paint(e, OUT)
                paint(se(X, Y, cx - .03, ey - .06, .04, .045) & e, (250, 246, 238))
                paint(se(X, Y, cx, ey - .125, .15, .055) & face, sk['lo'])      # palpebra pesada
        # boca
        my = .60
        if mouth == 'c':
            paint(se(X, Y, 0, my, .19, .035), (118, 54, 54))
        elif mouth == 'm':
            paint(se(X, Y, 0, my, .19, .08), (60, 24, 30)); paint(se(X, Y, 0, my + .04, .12, .035), (190, 84, 90))
        else:
            paint(se(X, Y, 0, my + .01, .21, .14), (60, 24, 30)); paint(se(X, Y, 0, my + .09, .14, .05), (200, 88, 96))
            paint(se(X, Y, 0, my - .08, .16, .03), (244, 240, 232))
    elif view == 'back':
        face = se(X, Y, 0, .14, .80 * fw, .80, 2.5)
        ears = se(X, Y, -.84 * fw, .14, .13, .19) | se(X, Y, .84 * fw, .14, .13, .19)
        paint(ears, sk['mid']); paint(face, hr['mid'])
        lo, hi = shade_of(face, k); paint(lo, hr['lo']); paint(hi & (Y < -.2), hr['hi'])
        paint(se(X, Y, -.30, -.52, .22, .08) & face, hr['hi'])
        paint(face & (Y > .40) & (Y <= .62) & chk, mix(hr['mid'], sk['mid'], .45))
        paint(face & (Y > .60) & (np.abs(X) < .40), sk['lo'])
        paint(face & (Y > .60) & (np.abs(X) >= .40), hr['lo'])
        textura(face & (Y < .4), hr['hi'], 13)
    else:  # lado, olhando para a direita
        cx0 = -.05
        head_ = se(X, Y, cx0, .14, .76, .80, 2.5)
        face = head_ | se(X, Y, .46, .42, .30, .30)
        nose = se(X, Y, .84, .24, .10, .08)
        paint(face | nose, sk['mid'])
        lo, hi = shade_of(face | nose, k); paint(lo & (Y > .55), sk['lo'])
        if P.get('barba') == 'cheia':
            bm = face & (((Y > .34) & (X > -.20 - .3 * (Y - .34))) | ((X > -.06) & (X < .16) & (Y > .04)))
            paint(bm, bd['mid'])
            if big: l2, h2 = shade_of(bm, k); paint(l2 & bm, bd['lo'])
            paint(se(X, Y, .66, .50, .20, .10) & face, bd['hi'])
            textura(bm, bd['lo'], 9)
        hair = head_ & ((Y < -.30 + .25 * np.clip(X - .35, 0, 9)) | ((X < -.12 - .45 * np.clip(Y - .05, 0, 9)) & (Y < .46)))
        paint(hair, hr['mid'])
        if big: h_lo, h_hi = shade_of(hair, k); paint(h_lo & (X < 0), hr['lo']); paint(h_hi & (Y < -.3), hr['hi'])
        paint(se(X, Y, -.30, -.52, .22, .08) & hair, hr['hi'])
        textura(hair & (Y < .1), hr['hi'], 13)
        paint(se(X, Y, -.02, .20, .12, .17), sk['lo']); paint(se(X, Y, -.04, .19, .05, .10), sk['mid'])   # orelha
        if eyes == 'blink': paint(se(X, Y, .44, .09, .09, .035), OUT)
        else:
            e = se(X, Y, .44, .06, .085, .15); paint(e, OUT); paint(se(X, Y, .41, 0, .035, .045) & e, (250, 246, 238))
            paint(se(X, Y, .44, -.065, .13, .05) & face, sk['lo'])
        paint(se(X, Y, .45, -.14, .20, .055 * P['sobr'] + .025), hr['lo'])
        w = {'c': .09, 'm': .10, 'o': .12}[mouth]; h = {'c': .035, 'm': .07, 'o': .12}[mouth]
        paint(se(X, Y, .66, .60, w, h), (118, 54, 54) if mouth == 'c' else (60, 24, 30))
    # contorno
    a = img[..., 3] > 0
    pad = np.pad(a, 1)
    nb = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    ol = nb & ~a
    img[ol] = OUT + (255,)
    return Image.fromarray(img, 'RGBA')

if __name__ == '__main__':
    P = PERFIS['nicao']
    S = 8
    sheet = Image.new('RGBA', (4 * 60 * 1, 3 * 60), (240, 226, 188, 255))
    row = Image.new('RGBA', (26 * S * 3 + 40, 26 * S + 10), (240, 226, 188, 255))
    for i, v in enumerate(['front', 'side', 'back']):
        h = head(P, v, N=26).resize((26 * S, 26 * S), Image.NEAREST); row.alpha_composite(h, (i * (26 * S + 20), 5))
    row.save('hg_teste.png')
    big = Image.new('RGBA', (3 * 64 * 5 + 40, 64 * 5 + 10), (240, 226, 188, 255))
    for i, m in enumerate(['c', 'm', 'o']):
        h = head(P, 'front', mouth=m, N=64).resize((64 * 5, 64 * 5), Image.NEAREST); big.alpha_composite(h, (i * (64 * 5 + 20), 5))
    big.save('hg_grande.png')

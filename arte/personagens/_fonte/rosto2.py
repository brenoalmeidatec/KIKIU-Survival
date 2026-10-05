"""Cabeca v2: proporcoes medidas na foto de frente (testa, sobrancelha, olho, nariz, boca, queixo).
Y vai de -1 (topo do cabelo) a +1 (queixo/barba); X de -1 a 1."""
import numpy as np
from PIL import Image
from headgen import ramp, mix, grid, se, shade_of, OUT

NICAO = dict(
    skin=(206, 150, 112), hair=(46, 36, 34), beard=(66, 50, 44), lip=(176, 100, 98),
    larg=.66,          # meia largura do rosto
    testa=-.60,        # linha do cabelo
    sobr_y=-.39, olho_y=-.24, olho_x=.27, nariz_y=.13, boca_y=.36,
    barba='cheia', barba_bochecha=.06, sobr_g=1.0, nariz_l=.13,
)

def jaw(Y, w):
    return w * (1 - .42 * np.clip((Y - .20) / .80, 0, 1) ** 1.6)

def frente(P, mouth='c', eyes='open', N=48):
    X, Y = grid(N); k = 1 if N < 40 else 2; big = N >= 40
    sk, hr, bd = ramp(P['skin']), ramp(P['hair']), ramp(P['beard'])
    img = np.zeros((N, N, 4), np.uint8)
    def paint(m, c): img[m] = tuple(c) + (255,)
    w = P['larg']
    face = (np.abs(X) < jaw(Y, w) * np.sqrt(np.clip(1 - ((Y - .02) / .98) ** 2, 0, 1)) ** .5) & (Y > -.92)
    ears = se(X, Y, -w - .02, -.12, .09, .16) | se(X, Y, w + .02, -.12, .09, .16)
    paint(ears, sk['mid']); paint(se(X, Y, -w - .01, -.11, .04, .09) | se(X, Y, w + .01, -.11, .04, .09), sk['lo'])
    paint(face, sk['mid'])
    lo, hi = shade_of(face, k); paint(lo, sk['lo'])
    paint(se(X, Y, -.12, -.72 + .0, .20, .06) & face, sk['hi'])                         # brilho testa
    # olheira + olhos
    oy, ox = P['olho_y'], P['olho_x']
    for sx in (-1, 1):
        cx = sx * ox
        paint(se(X, Y, cx, oy + .075, .12, .035) & face, sk['lo'])
        if eyes == 'blink':
            paint(se(X, Y, cx, oy + .01, .12, .022), OUT)
        else:
            paint(se(X, Y, cx, oy, .12, .058), (236, 228, 218))
            paint(se(X, Y, cx, oy + .005, .055, .062), (64, 38, 30))
            paint(se(X, Y, cx, oy + .005, .028, .035), (24, 16, 18))
            paint(se(X, Y, cx - .02, oy - .02, .016, .016), (250, 248, 244)) if big else None
            paint(se(X, Y, cx, oy - .055, .13, .02), OUT)                                 # palpebra
        # sobrancelha grossa, quase reta, cai um pouco para fora
        by = P['sobr_y'] + .05 * np.clip(sx * X - ox, -1, 1)
        paint((np.abs(X - cx) < .16) & (np.abs(Y - by) < .035 * P['sobr_g'] + .01) & face, hr['lo'])
    # nariz largo
    ny, nl = P['nariz_y'], P['nariz_l']
    paint(se(X, Y, 0, ny - .10, .035, .13) & face, sk['hi'])
    paint(se(X, Y, .06, ny - .08, .03, .12) & face, sk['lo'])
    paint(se(X, Y, 0, ny + .01, nl, .045) & face, sk['lo'])
    paint(se(X, Y, -nl * .55, ny, .035, .022) | se(X, Y, nl * .55, ny, .035, .022), mix(sk['lo'], OUT, .35))
    # barba
    my = P['boca_y']
    if P.get('barba'):
        ax = np.abs(X)
        chk = ((np.arange(N)[:, None] + np.arange(N)[None, :]) % 2) == 0
        rala = face & (Y > ny + .02 - .30 * np.clip(ax - .25, 0, 1)) & (ax > .22)       # bochecha: barba rala
        densa = face & ((Y > my + .10) | ((ax > .30) & (Y > ny + .14 - .25 * (ax - .30))) | ((ax > w - .12) & (Y > -.15)))
        bigode = (np.abs(X) < .22) & (Y > my - .11) & (Y < my - .045) & face
        paint(rala & chk, mix(bd['mid'], sk['lo'], .35))
        paint(densa | bigode, bd['mid'])
        paint(densa & ~np.roll(densa, -k, 1) & (X > 0), bd['lo'])
        paint(densa & ~np.roll(densa, -k, 0), bd['lo'])
    # boca / labios
    lip = P['lip']; lip_lo = mix(lip, (90, 40, 50), .35); dentro = (70, 26, 32)
    abre = {'c': 0, 'm': .045, 'o': .10}[mouth]
    paint(se(X, Y, 0, my - .03, .17, .03), lip_lo)                                      # labio de cima
    if abre:
        paint(se(X, Y, 0, my + abre / 2, .15, .02 + abre / 2), dentro)
        if mouth == 'o': paint(se(X, Y, 0, my + .005, .12, .018), (240, 236, 228))
    else:
        paint((np.abs(X) < .15) & (np.abs(Y - my) < .012 + .5 / N), mix(lip_lo, OUT, .4))
    paint(se(X, Y, 0, my + .045 + abre, .15, .04), lip)                                 # labio de baixo
    paint(se(X, Y, -.04, my + .035 + abre, .05, .015), mix(lip, (255, 220, 210), .35)) if big else None
    # cabelo curto
    hair = se(X, Y, 0, -.38, w + .05, .62, 2.4) & ((Y < P['testa'] + .10 * (X / w) ** 4) | (np.abs(X) > w - .06) & (Y < -.20))
    hair &= ~ears
    paint(hair, hr['mid'])
    h_lo, h_hi = shade_of(hair, k); paint(h_lo & (Y > -.75), hr['lo']); paint(h_hi & (Y < -.75), hr['hi'])
    paint(se(X, Y, -.18, -.86, .22, .04) & hair, hr['hi'])
    if big:
        gx, gy = np.floor(X * N / 3), np.floor(Y * N / 3)
        paint(hair & (((gx * 5 + gy * 3) % 9) == 0) & (Y < -.66), hr['hi'])
    a = img[..., 3] > 0
    pad = np.pad(a, 1); nb = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    img[nb & ~a] = OUT + (255,)
    return Image.fromarray(img, 'RGBA')

if __name__ == '__main__':
    F = '/root/.claude/uploads/6ba9e05a-030f-5eb6-bf76-b30a73755dea/68d0401f-image.png'
    foto = Image.open(F).convert('RGBA').crop((-5, -8, 241, 238)).resize((288, 288))
    c = Image.new('RGBA', (288 * 3 + 40, 288 + 160), (240, 226, 188, 255))
    c.alpha_composite(foto, (0, 0))
    c.alpha_composite(frente(NICAO, N=48).resize((288, 288), Image.NEAREST), (308, 0))
    c.alpha_composite(frente(NICAO, N=26).resize((26 * 11, 26 * 11), Image.NEAREST), (616, 0))
    for i, m in enumerate('cmo'):
        c.alpha_composite(frente(NICAO, mouth=m, N=48).resize((144, 144), Image.NEAREST), (308 + i * 150, 296))
    c.save('chk.png')

def _contorno(img):
    a = img[..., 3] > 0
    pad = np.pad(a, 1); nb = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    img[nb & ~a] = OUT + (255,)
    return Image.fromarray(img, 'RGBA')

def lado(P, mouth='c', eyes='open', N=26):
    """perfil olhando para a direita, mesmas alturas da frente"""
    X, Y = grid(N); k = 1 if N < 40 else 2; big = N >= 40
    sk, hr, bd = ramp(P['skin']), ramp(P['hair']), ramp(P['beard'])
    img = np.zeros((N, N, 4), np.uint8)
    def paint(m, c): img[m] = tuple(c) + (255,)
    oy, ny, my = P['olho_y'], P['nariz_y'], P['boca_y']
    cranio = se(X, Y, -.06, -.10, .66, .86, 2.3)
    rosto = (X > -.30) & (X < .50 - .25 * np.clip((Y - .45) / .55, 0, 1) ** 1.3) & (Y > -.62) & (Y < .97)
    face = cranio | rosto
    nariz = se(X, Y, .56, ny - .03, .13, .09) & (Y < ny + .04) & (Y > ny - .2)
    paint(face | nariz, sk['mid'])
    lo, hi = shade_of(face, k); paint(lo & (Y > .2), sk['lo'])
    if P.get('barba'):
        bm = face & (((Y > ny + .10) & (X > -.25)) | ((X > -.26) & (X < -.04) & (Y > .05)))
        bm &= ~((X > .28) & (np.abs(Y - my) < .05))
        paint(bm, bd['mid']); paint(bm & (Y > .75), bd['lo'])
    paint(se(X, Y, .47, my, .07, {'c': .02, 'm': .05, 'o': .08}[mouth]), P['lip'] if mouth == 'c' else (70, 26, 32))
    hair = cranio & ((Y < P['testa'] + .35 * np.clip(-X, 0, 1)) | ((X < -.22) & (Y < .18 - .4 * np.clip(-.22 - X, 0, 1))))
    orelha = se(X, Y, -.14, -.10, .10, .17)
    paint(hair & ~orelha, hr['mid'])
    if big: h_lo, h_hi = shade_of(hair, k); paint(h_hi & (Y < -.7), hr['hi'])
    paint(se(X, Y, -.18, -.86, .22, .04) & hair, hr['hi'])
    paint(orelha, sk['mid']); paint(se(X, Y, -.14, -.09, .05, .10), sk['lo'])
    if eyes == 'blink': paint(se(X, Y, .36, oy + .01, .07, .022), OUT)
    else:
        paint(se(X, Y, .37, oy, .06, .06), (236, 228, 218)); paint(se(X, Y, .39, oy, .035, .06), (40, 24, 22))
        paint(se(X, Y, .36, oy - .055, .08, .02), OUT)
    paint((np.abs(X - .35) < .13) & (np.abs(Y - P['sobr_y']) < .045), hr['lo'])
    return _contorno(img)

def costas(P, N=26):
    X, Y = grid(N); k = 1 if N < 40 else 2
    sk, hr = ramp(P['skin']), ramp(P['hair'])
    img = np.zeros((N, N, 4), np.uint8)
    def paint(m, c): img[m] = tuple(c) + (255,)
    w = P['larg']
    cab = se(X, Y, 0, -.12, w + .04, .86, 2.3)
    ears = se(X, Y, -w - .03, -.12, .09, .16) | se(X, Y, w + .03, -.12, .09, .16)
    pesc = (np.abs(X) < w * .62) & (Y > .5) & (Y < .98)
    paint(ears | pesc, sk['lo']); paint(cab, hr['mid'])
    chk = ((np.arange(N)[:, None] + np.arange(N)[None, :]) % 2) == 0
    paint(cab & (Y > .45) & chk, mix(hr['mid'], sk['lo'], .5))
    lo, hi = shade_of(cab, k); paint(lo, hr['lo'])
    paint(se(X, Y, -.18, -.80, .24, .05) & cab, hr['hi'])
    return _contorno(img)

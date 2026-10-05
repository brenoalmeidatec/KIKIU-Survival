import sys, os
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
import retratos3 as R
from retratos3 import CAIRU, VERDE

FW, FH = 44, 60            # tamanho de cada quadro
HW, HH = 24, 24            # cabeca de frente
SW = 20                    # cabeca de lado
OUT = (28, 20, 22)

# corpo por personagem: largura do tronco, calca, sapato, perna de fora?
CORPO = {
    'nicao':   dict(tw=14, altura=0, pants=(48, 62, 96), shoe=(70, 70, 76), bare=False),
    'lucas':   dict(tw=14, altura=0, pants=(30, 30, 36), shoe=(236, 236, 236), bare=True),
    'joao':    dict(tw=16, altura=0, pants=(48, 62, 96), shoe=(36, 36, 40), bare=False),
    'matheus': dict(tw=18, altura=0, pants=(48, 62, 96), shoe=(236, 236, 236), bare=False),
    'beto':    dict(tw=15, altura=0, pants=(48, 62, 96), shoe=(36, 36, 40), bare=False),
    'lukako':  dict(tw=18, altura=0, pants=(48, 62, 96), shoe=(236, 236, 236), bare=False),
    'fabio':   dict(tw=13, altura=0, pants=(48, 62, 96), shoe=(236, 236, 236), bare=False),
    'breno':   dict(tw=16, altura=0, pants=(28, 34, 72), shoe=(236, 232, 222), bare=True),
}

def sombra(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)

def partes(name):
    """quantizado, mascara e posicao do pescoco do retrato"""
    hi = R.crop(name, 4)
    m_hi = R.person_mask(np.array(hi), name)
    q = R.pixelize(hi)
    m = Image.fromarray(m_hi).resize((R.GW, R.GH), Image.NEAREST)
    return q, m

def cabeca(name):
    q, m = partes(name)
    ny = R.NY[name]
    mp = m.load(); qa = q.load()
    # so a cabeca: acima do pescoco, sem o contorno branco da figurinha
    rgba = Image.new('RGBA', q.size, (0, 0, 0, 0)); rp = rgba.load()
    xs0 = [x for y in range(ny - 8, ny - 3) for x in range(R.GW // 4, 3 * R.GW // 4) if mp[x, y]]
    cx0 = sum(xs0) / len(xs0) if xs0 else R.GW / 2
    for y in range(0, ny - 2):
        allow = 21 - 0.75 * max(0, y - (ny - 14))
        for x in range(R.GW):
            r, g, b = qa[x, y]
            if mp[x, y] and abs(x - cx0) <= allow and not (r > 232 and g > 232 and b > 232):
                rp[x, y] = (r, g, b, 255)
    bb = rgba.getbbox()
    cab = rgba.crop(bb)
    def reduz(img, w, h):
        a = np.array(img).astype(float)
        mask = a[..., 3] > 0
        mean = a[mask][:, :3].mean(0)
        a[~mask, :3] = mean
        rgb = Image.fromarray(a[..., :3].astype('uint8')).resize((w, h), Image.LANCZOS)
        al = Image.fromarray((mask * 255).astype('uint8')).resize((w, h), Image.BILINEAR)
        out = rgb.convert('RGBA'); out.putalpha(al.point(lambda v: 255 if v > 120 else 0))
        # paleta curta
        pal = out.convert('RGB').quantize(colors=14, method=Image.MEDIANCUT, dither=Image.NONE).convert('RGB')
        pal = pal.convert('RGBA'); pal.putalpha(out.getchannel('A'))
        return pal
    frente = reduz(cab, HW, HH)
    lado = reduz(cab, SW, HH)
    # pele: mediana das bochechas
    fa = np.array(frente)
    reg = fa[11:17, 7:17, :3].reshape(-1, 3)
    skin = tuple(int(v) for v in np.median(reg, axis=0))
    # costas: textura da faixa do cabelo esticada na silhueta
    costas = frente.copy(); cp = costas.load(); fp = frente.load()
    for y in range(HH):
        for x in range(HW):
            if fp[x, y][3]:
                sy = 1 + (y * 7 // HH) % 8
                r, g, b, a = fp[x, min(HW - 1, x)] if False else fp[x, sy]
                if not fp[x, sy][3]:
                    r, g, b, a = fp[x, 2]
                cp[x, y] = sombra((r, g, b), .85) + (255,)
    for y in range(int(HH * .90), HH):
        for x in range(HW):
            if fp[x, y][3]:
                cp[x, y] = sombra(skin, .8) + (255,)
    return frente, lado, costas, skin

def outline(im):
    a = im.load(); w, h = im.size
    out = im.copy(); o = out.load()
    for y in range(h):
        for x in range(w):
            if a[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and a[nx, ny][3]:
                        o[x, y] = OUT + (255,); break
    return out

def rect(d, x0, y0, x1, y1, c):
    if x1 >= x0 and y1 >= y0: d.rectangle([x0, y0, x1, y1], fill=c + (255,))

def corpo(d, direcao, frame, p, cor, skin, tw, logo=True):
    """desenha tronco, bracos e pernas. frame: 0 parado, 1 passo A, 2 passo B"""
    T, t, U, W = cor['T'], cor['t'], cor['U'], cor['W']
    P = p['pants']; Ps = sombra(P, .75); F = p['shoe']; Fs = sombra(F, .72)
    sk, sks = skin, sombra(skin, .8)
    cx = FW // 2
    ty0, ty1 = 27, 41
    ly0, ly1 = 42, 56
    lado = direcao in ('esquerda', 'direita')
    passo = {0: 0, 1: 1, 2: -1}[frame]
    if not lado:
        tl = cx - tw // 2; tr = tl + tw - 1
        # pernas (frente e costas)
        for i, (x0, x1) in enumerate(((cx - 6, cx - 1), (cx, cx + 5))):
            up = 2 if (i == 0 and passo == 1) or (i == 1 and passo == -1) else 0
            if p['bare']:
                rect(d, x0, ly0, x1, ly0 + 5 - up, P)
                rect(d, x0, ly0 + 6 - up, x1, ly1 - 3 - up, sk)
                rect(d, x1, ly0 + 6 - up, x1, ly1 - 3 - up, sks)
            else:
                rect(d, x0, ly0, x1, ly1 - 3 - up, P)
                rect(d, x1, ly0, x1, ly1 - 3 - up, Ps)
            rect(d, x0 - 0, ly1 - 2 - up, x1, ly1 - up, F)
            rect(d, x0, ly1 - up, x1, ly1 - up, Fs)
        rect(d, cx - 1, ly0 + 1, cx, ly0 + 3, Ps) if not p['bare'] else None
        # tronco
        rect(d, tl, ty0, tr, ty1, T)
        rect(d, tl, ty0, tl, ty1 - 1, U)
        rect(d, tr - 1, ty0, tr, ty1, t)
        rect(d, tl, ty1, tr, ty1, t)
        # bracos
        for side in (0, 1):
            sw = (passo if side == 0 else -passo)
            ax1 = tl - 4 if side == 0 else tr + 1
            ax0 = tl - 1 if side == 0 else tr + 4
            xa, xb = min(ax0, ax1), max(ax0, ax1)
            rect(d, xa, ty0 + 1 + sw, xb, ty0 + 6 + sw, T)
            rect(d, xa if side == 0 else xb, ty0 + 1 + sw, xa if side == 0 else xb, ty0 + 6 + sw, U if side == 0 else t)
            rect(d, xa + 1, ty0 + 7 + sw, xb - 1, ty0 + 12 + sw, sk)
            rect(d, xa + 1 if side == 0 else xb - 1, ty0 + 7 + sw, xa + 1 if side == 0 else xb - 1, ty0 + 12 + sw, sks)
            rect(d, xa + 1, ty0 + 13 + sw, xb - 1, ty0 + 14 + sw, sk)
        # gola
        if direcao == 'baixo':
            rect(d, cx - 3, ty0, cx + 2, ty0 + 1, cor['K'])
            rect(d, cx - 2, ty0 - 1, cx + 1, ty0, sks)
            if logo:
                for (x, y) in [(cx + 3, ty0 + 5), (cx + 4, ty0 + 5), (cx + 5, ty0 + 5), (cx + 3, ty0 + 6), (cx + 4, ty0 + 6)]:
                    d.point((x, y), fill=W + (255,))
        else:
            rect(d, cx - 3, ty0, cx + 2, ty0, cor['K'])
    else:
        sg = 1 if direcao == 'direita' else -1
        tl = cx - 5; tr = cx + 5
        # perna de tras e da frente (tesoura)
        sw = {0: 0, 1: 3, 2: -3}[frame]
        for k, (xo, fr) in enumerate(((-sw, 0), (sw, 1))):
            for y in range(ly0, ly1 - 2):
                f = (y - ly0) / (ly1 - ly0)
                x0 = cx - 3 + int(round(xo * f)); x1 = x0 + 5
                bare = p['bare'] and y > ly0 + 5
                c = (sk if bare else P)
                if k == 0: c = sombra(c, .78)
                rect(d, x0, y, x1, y, c)
            xo2 = cx - 3 + xo
            rect(d, xo2, ly1 - 2, xo2 + 7, ly1 - 1, F if k else Fs)
            rect(d, xo2, ly1, xo2 + 7, ly1, Fs)
        rect(d, cx - 3, ly0 - 1, cx + 3, ly0 + 5, P)
        rect(d, tl, ty0, tr, ty1, T)
        rect(d, tl, ty0, tl + 1, ty1 - 1, U)
        rect(d, tr - 1, ty0, tr, ty1, t)
        rect(d, tl, ty1, tr, ty1, t)
        # braco que balanca
        sw2 = {0: 0, 1: -3, 2: 3}[frame]
        ax = cx - 2
        rect(d, ax, ty0 + 1, ax + 3, ty0 + 6, T)
        rect(d, ax, ty0 + 1, ax, ty0 + 6, U)
        for y in range(ty0 + 7, ty0 + 15):
            f = (y - ty0 - 7) / 8
            xx = ax + int(round(sw2 * f))
            rect(d, xx, y, xx + 3, y, sk if y < ty0 + 13 else sk)
        rect(d, cx - 2, ty0 - 1, cx + 1, ty0, sks)
        for (x, y) in [(cx + 1, ty0 + 3), (cx + 2, ty0 + 3)]:
            pass

def sprite(name, cor):
    frente, lado, costas, skin = cabeca(name)
    p = CORPO[name]; tw = p['tw']
    sheet = Image.new('RGBA', (FW * 3, FH * 4), (0, 0, 0, 0))
    for row, dr in enumerate(['baixo', 'esquerda', 'direita', 'cima']):
        for col in range(3):
            im = Image.new('RGBA', (FW, FH), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
            bob = 1 if col else 0
            corpo(d, dr, col, p, cor, skin, tw, logo=(dr == 'baixo'))
            cx = FW // 2
            if dr == 'baixo': h, hx = frente, cx - HW // 2
            elif dr == 'cima': h, hx = costas, cx - HW // 2
            elif dr == 'direita': h, hx = lado, cx - SW // 2 + 1
            else: h, hx = lado.transpose(Image.FLIP_LEFT_RIGHT), cx - SW // 2 - 1
            im.alpha_composite(h, (hx, 3 - (1 if bob and False else 0)))
            if dr == 'esquerda':
                pass
            im = outline(im)
            sheet.paste(im, (col * FW, row * FH))
    return sheet

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    nomes = sys.argv[2:] or list(R.CHARS)
    S = 5
    folha = Image.new('RGBA', (4 * (FW * 3 * S // 2 + 16), 2 * (FH * 4 * S // 2 + 16)), (120, 170, 110, 255))
    for i, n in enumerate(R.CHARS):
        if n not in nomes: continue
        sh = sprite(n, CAIRU)
        sh.save(f'{out}/{n}_sprites_v2.png')
        big = sh.resize((FW * 3 * S // 2, FH * 4 * S // 2), Image.NEAREST)
        folha.alpha_composite(big, ((i % 4) * (FW * 3 * S // 2 + 16) + 8, (i // 4) * (FH * 4 * S // 2 + 16) + 8))
    folha.save(f'{out}/sheet_v2.png')

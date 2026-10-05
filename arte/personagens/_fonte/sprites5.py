"""sprites v3: cabeca da foto alinhada ao corpo (pescoco coberto, ombros da largura da cabeca) e ciclo de andar de 4 passos.
Folha: 4 colunas (parado, passo A, passo B, passagem) x 4 linhas (baixo, esquerda, direita, cima). Quadro 44x60."""
import sys, os
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
import retratos3 as R
from retratos3 import CAIRU, VERDE
from sprites4 import cabeca, outline, rect, sombra, CORPO, HW, HH, SW, FW, FH

COLS = 4
HEAD_Y = 7            # topo da cabeca (quadro parado)
SH_Y = 28             # linha dos ombros (cabeca cobre 3px do tronco)
TORSO_H = 15
HIP_Y = SH_Y + TORSO_H   # 39
FOOT_Y = 56

def perna_v(d, x0, x1, ytop, ybot, P, sk, F, p, lift):
    """perna de frente/costas: calca (ou pele) ate ybot, sapato"""
    yb = ybot - lift
    if p['bare']:
        rect(d, x0, ytop, x1, ytop + 5, P)
        rect(d, x0, ytop + 6, x1, yb - 3, sk); rect(d, x1, ytop + 6, x1, yb - 3, sombra(sk, .8))
    else:
        rect(d, x0, ytop, x1, yb - 3, P); rect(d, x1, ytop, x1, yb - 3, sombra(P, .75))
    rect(d, x0 - 1 if x0 < FW // 2 else x0, yb - 2, x1 + (1 if x0 >= FW // 2 else 0), yb, F)
    rect(d, x0 - 1 if x0 < FW // 2 else x0, yb, x1 + (1 if x0 >= FW // 2 else 0), yb, sombra(F, .72))

def corpo_v(d, dr, fr, p, cor, skin, bob):
    """frente (baixo) ou costas (cima). fr: 0 parado,1 A,2 B,3 passagem"""
    T, t, U, W, K = cor['T'], cor['t'], cor['U'], cor['W'], cor['K']
    P = p['pants']; F = p['shoe']; sk = skin
    cx = FW // 2
    tw = p['tw'] + 4                      # ombros da largura da cabeca
    tl = cx - tw // 2; tr = tl + tw - 1
    sy = SH_Y - bob; hy = HIP_Y - bob
    lifts = {0: (0, 0), 1: (2, 0), 2: (0, 2), 3: (0, 0)}[fr]   # perna esq, dir levantada
    sw = {0: 0, 1: 1, 2: -1, 3: 0}[fr]                          # braco oposto a perna
    # pernas
    for i, (x0, x1) in enumerate(((cx - 6, cx - 1), (cx, cx + 5))):
        perna_v(d, x0, x1, hy + 1, FOOT_Y, P, sk, F, p, lifts[i])
    rect(d, cx - 1, hy, cx, hy + 3, sombra(P, .7)) if not p['bare'] else None
    # bracos (atras do tronco nas bordas)
    for side in (0, 1):
        s = sw if side == 0 else -sw
        xa = tl - 3 if side == 0 else tr + 1
        xb = xa + 2
        ya = sy + 1 + s
        rect(d, xa, ya, xb, ya + 4, T)                          # manga
        rect(d, xa if side == 0 else xb, ya, xa if side == 0 else xb, ya + 4, U if side == 0 else t)
        rect(d, xa, ya + 5, xb, ya + 9, sk)                     # antebraco
        rect(d, xb if side == 0 else xa, ya + 5, xb if side == 0 else xa, ya + 9, sombra(sk, .8))
        rect(d, xa, ya + 10, xb, ya + 11, sombra(sk, .92))      # mao
    # tronco
    rect(d, tl, sy, tr, hy - 1, T)
    rect(d, tl, sy, tl, hy - 2, U)
    rect(d, tr - 1, sy, tr, hy - 1, t)
    rect(d, tl, hy - 1, tr, hy - 1, t)
    if dr == 'baixo':
        rect(d, cx - 3, sy, cx + 2, sy + 1, K)
        for (x, y) in [(tr - 5, sy + 6), (tr - 4, sy + 6), (tr - 3, sy + 6), (tr - 5, sy + 7), (tr - 4, sy + 7)]:
            d.point((x, y), fill=W + (255,))
    else:
        rect(d, cx - 3, sy, cx + 2, sy, K)

def corpo_s(d, fr, p, cor, skin, bob):
    """vista lateral virada para a direita"""
    T, t, U, W, K = cor['T'], cor['t'], cor['U'], cor['W'], cor['K']
    P = p['pants']; F = p['shoe']; sk = skin
    cx = FW // 2
    sy = SH_Y - bob; hy = HIP_Y - bob
    swing = {0: 0, 1: 4, 2: -4, 3: 0}[fr]                       # perna da frente (proxima)
    def perna(xo, lift, near):
        shade = 1 if near else .74
        for y in range(hy, FOOT_Y - 2 - lift + 1):
            f = (y - hy) / max(1, (FOOT_Y - 2 - hy))
            x0 = cx - 3 + int(round(xo * f)); x1 = x0 + 4
            c = sk if (p['bare'] and y > hy + 5) else P
            rect(d, x0, y, x1, y, sombra(c, shade))
        fx = cx - 3 + xo
        yb = FOOT_Y - lift
        rect(d, fx, yb - 2, fx + 7, yb - 1, sombra(F, shade))
        rect(d, fx, yb, fx + 7, yb, sombra(F, .6 * shade + .2))
    lt_back = max(0, -swing) // 2 + (2 if swing > 0 else 0)
    perna(-swing, 2 if swing != 0 else 0, False)
    perna(swing, 0, True) if swing >= 0 else perna(swing, 2, True)
    rect(d, cx - 3, hy - 1, cx + 3, hy + 3, P)
    # braco de tras
    a = {0: 0, 1: -3, 2: 3, 3: 0}[fr]
    def braco(a, near):
        sh = 1 if near else .78
        bx = cx - 2
        rect(d, bx, sy + 1, bx + 3, sy + 6, sombra(t, sh))
        rect(d, bx, sy + 1, bx + 3, sy + 1, sombra(U, sh))
        for y in range(sy + 7, sy + 14):
            f = (y - sy - 7) / 6
            xx = bx + int(round(a * f))
            rect(d, xx, y, xx + 3, y, sombra(sk, sh))
    braco(-a, False)
    # tronco
    tl, tr = cx - 7, cx + 6
    rect(d, tl, sy, tr, hy - 1, T)
    rect(d, tl, sy, tl + 1, hy - 2, U); rect(d, tr - 1, sy, tr, hy - 1, t); rect(d, tl, hy - 1, tr, hy - 1, t)
    braco(a, True)

def nuca(frente, skin):
    """vista de costas: cor do cabelo (topo da foto) lisa, com leve textura e a nuca"""
    a = np.array(frente); al = a[..., 3] > 0
    ys, xs = np.where(al); top = ys.min()
    reg = a[top:top + 5][al[top:top + 5]][:, :3]
    H = np.median(reg, axis=0)
    out = Image.new('RGBA', frente.size, (0, 0, 0, 0)); o = out.load()
    h = ys.max() - top + 1
    for y, x in zip(ys, xs):
        k = (y - top) / h
        f = 1.0 if k < .55 else (.86 if k < .85 else .0)
        if f == 0:
            c = tuple(int(v * .82) for v in skin)
        else:
            f *= .9 if (x * 3 + y * 5) % 7 == 0 else 1
            c = tuple(int(min(255, v * f)) for v in H)
        o[x, y] = c + (255,)
    return out

def sprite(name, cor):
    frente, lado, costas, skin = cabeca(name)
    costas = nuca(frente, skin)
    p = CORPO[name]
    sheet = Image.new('RGBA', (FW * COLS, FH * 4), (0, 0, 0, 0))
    cx = FW // 2
    for row, dr in enumerate(['baixo', 'esquerda', 'direita', 'cima']):
        for col in range(COLS):
            im = Image.new('RGBA', (FW, FH), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
            bob = 1 if col == 3 else 0
            if dr in ('baixo', 'cima'):
                corpo_v(d, dr, col, p, cor, skin, bob)
                h = frente if dr == 'baixo' else costas; hx = cx - HW // 2
            else:
                corpo_s(d, col, p, cor, skin, bob)
                h = lado; hx = cx - SW // 2 + 1
            im.alpha_composite(h, (hx, HEAD_Y - bob))
            im = outline(im)
            if dr == 'esquerda':
                im = im.transpose(Image.FLIP_LEFT_RIGHT)
            sheet.paste(im, (col * FW, row * FH))
    return sheet

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    nomes = sys.argv[2:] or list(R.CHARS)
    S = 4
    cell = FW * COLS * S // 2 + 16
    folha = Image.new('RGBA', (4 * cell, 2 * (FH * 4 * S // 2 + 16)), (120, 170, 110, 255))
    for i, n in enumerate(R.CHARS):
        if n not in nomes: continue
        sh = sprite(n, CAIRU); sh.save(f'{out}/{n}_sprites_v3.png')
        big = sh.resize((FW * COLS * S // 2, FH * 4 * S // 2), Image.NEAREST)
        folha.alpha_composite(big, ((i % 4) * cell + 8, (i // 4) * (FH * 4 * S // 2 + 16) + 8))
    folha.save(f'{out}/sheet_v3.png')

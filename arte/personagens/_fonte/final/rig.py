"""Corpo com esqueleto simples (quadril, joelho, pe; ombro, cotovelo, mao) em camadas com contorno proprio.
Andar de 8 quadros (contato, desce, passagem, sobe x2), cabeca presa ao tronco (sobe/desce/balanca junto)."""
import math
from PIL import Image, ImageDraw
import elenco
from sprites8 import contorno, OUT, CALCA, CALCA_S, CALCA_L, TENIS, SOLA
from retratos3 import CAIRU

FW, FH = 32, 48
T, t, U, LOGO = CAIRU['T'], CAIRU['t'], CAIRU['U'], CAIRU['W']
CHAO = 45          # linha da sola


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height: im.putpixel((int(x), int(y)), tuple(c) + (255,))


def bloco(im, x, y, w, c):
    x0 = int(round(x - (w - 1) / 2)); y0 = int(round(y - (w - 1) / 2))
    for i in range(w):
        for j in range(w): px(im, x0 + i, y0 + j, c)


def seg(im, a, b, w, c):
    n = max(1, int(max(abs(b[0] - a[0]), abs(b[1] - a[1])) * 2))
    for i in range(n + 1):
        k = i / n; bloco(im, a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, w, c)


def ik(q, p, l1, l2, dirx):
    """joelho/cotovelo entre q e p, dobrando para o lado dirx (+1 frente)"""
    dx, dy = p[0] - q[0], p[1] - q[1]; d = math.hypot(dx, dy)
    d = max(.5, min(d, l1 + l2 - .01))
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d); h = math.sqrt(max(0, l1 * l1 - a * a))
    ux, uy = dx / (d or 1), dy / (d or 1)
    mx, my = q[0] + ux * a, q[1] + uy * a
    c1 = (mx - uy * h, my + ux * h); c2 = (mx + uy * h, my - ux * h)
    return c1 if (c1[0] - mx) * dirx >= (c2[0] - mx) * dirx else c2


# biotipo: (largura extra de cada lado, barriga)
CORPO = {'beto': (3, 2), 'lukako': (1, 2), 'joao': (1, 4)}


def biotipo(nome):
    return CORPO.get(nome, (0, 0))


def barriga(k, b):
    return round(b * max(0.0, 1 - abs(k - .74) / .4)) if b else 0


def tronco_frente(d, cx, top, hip, w, b, costas=False, gola=None):
    """tronco de frente/costas; barriga cresce para os lados na metade de baixo"""
    d.rectangle([cx - 5 - w, hip - 1, cx + 4 + w, hip + 1], fill=CALCA + (255,))
    for y in range(top, hip):
        k = (y - top) / max(1, hip - 1 - top); e = barriga(k, b) if not costas else max(0, barriga(k, b) - 1)
        x0, x1 = cx - 5 - w - e, cx + 4 + w + e
        d.line([(x0, y), (x1, y)], fill=T + (255,))
        if y > top:
            d.line([(x1 - 2, y), (x1, y)], fill=t + (255,))
            if y < hip - 1: d.line([(x0, y), (x0 + 1, y)], fill=U + (255,))
        if b >= 2 and not costas and .5 < k < .8:
            d.line([(cx - 2 - e // 2, y), (cx - 1, y)], fill=U + (255,))
        if b >= 3 and not costas and k > .88:
            d.line([(x0 + 1, y), (x1 - 1, y)], fill=t + (255,))
    d.line([(cx - 5 - w - barriga(1, b), hip - 1), (cx + 4 + w + barriga(1, b), hip - 1)], fill=t + (255,))
    if not costas and gola:
        d.line([(cx - 2, top), (cx + 1, top)], fill=gola + (255,))
        for (x, y) in [(cx - 3, top + 3), (cx - 2, top + 3), (cx - 1, top + 3), (cx - 3, top + 4)]: d.point((x, y), fill=LOGO + (255,))


def camada():
    return Image.new('RGBA', (FW, FH), (0, 0, 0, 0))


def perna_lado(hip, pe, lift, cor, escuro):
    L = camada()
    joelho = ik(hip, pe, 7.0, 7.15, +1)
    seg(L, hip, joelho, 4, cor); seg(L, joelho, (pe[0], pe[1] - 1), 3, cor)
    # tenis (aponta para frente, +x); calcanhar sobe um pouco quando levanta
    fx, fy = int(round(pe[0])), int(round(pe[1]))
    inc = 1 if lift else 0
    for x in range(fx - 2, fx + 4):
        px(L, x, fy, TENIS if not escuro else (30, 30, 34))
        px(L, x, fy + 1 - (inc if x < fx else 0), SOLA)
    px(L, fx - 2, fy - 1, TENIS if not escuro else (30, 30, 34))
    return contorno(L)


def braco_lado(ombro, mao, cor_manga, cor_pele, mao_cor):
    L = camada()
    cot = ik(ombro, mao, 5.2, 5.6, -1)
    seg(L, ombro, cot, 3, cor_manga)
    k = .45; seg(L, (ombro[0] + (cot[0] - ombro[0]) * k, ombro[1] + (cot[1] - ombro[1]) * k), cot, 3, cor_pele)
    seg(L, cot, mao, 3, cor_pele); bloco(L, mao[0], mao[1], 3, mao_cor)
    seg(L, ombro, (ombro[0] + (cot[0] - ombro[0]) * .55, ombro[1] + (cot[1] - ombro[1]) * .55), 3, cor_manga)
    return contorno(L)


# trajetoria de um pe no andar (8 quadros), comecando como pe da frente no contato
PE_X = [5, 3, 0, -3, -5, -5, -1, 3]
PE_UP = [0, 0, 0, 0, 0, 1, 3, 2]
BOB = [0, 1, 0, -1, 0, 1, 0, -1]


def lado(nome, acao, f, cabeca_img):
    pal = elenco.C[nome]['pal']; S, s, Lc = pal['S'], pal['s'], pal['L']
    if acao == 'parado':
        bob = [0, 0, 1, 1][f]; a = b = (0, 0); sw = 0; lean = 0
        pa, pb = (1, 0), (-1, 0)
    elif acao == 'passagem':
        bob = -1; pa, pb = (1, 0), (-1, 1); sw = 0; lean = 0
    else:
        bob = BOB[f]
        pa = (PE_X[f], PE_UP[f]); pb = (PE_X[(f + 4) % 8], PE_UP[(f + 4) % 8])
        sw = pa[0]; lean = 1 if f in (0, 1, 4, 5) else 0
    cx = 16; hip = (cx, 30 + (bob if acao != 'parado' else 0))
    top = 16 + bob
    perna_tras = perna_lado(hip, (cx + pb[0], CHAO - 1 - pb[1]), pb[1], CALCA_S, True)
    perna_frente = perna_lado(hip, (cx + pa[0], CHAO - 1 - pa[1]), pa[1], CALCA, False)
    ombro = (cx + lean, top + 2)
    # braco oposto a perna: braco de tras acompanha a perna da frente
    hb = (ombro[0] + round(-pb[0] * .8), ombro[1] + 10 - abs(pb[0]) * .15)
    hf = (ombro[0] + round(-pa[0] * .8), ombro[1] + 10 - abs(pa[0]) * .15)
    braco_tras = braco_lado(ombro, hb, t, s, s)
    braco_frente = braco_lado(ombro, hf, T, S, Lc)
    tr = camada(); d = ImageDraw.Draw(tr)
    w, b = biotipo(nome)
    d.rectangle([cx - 4 - w // 2, hip[1] - 1, cx + 3 + w // 2, hip[1] + 1], fill=CALCA + (255,))
    for y in range(top, hip[1]):
        k = (y - top) / max(1, hip[1] - 1 - top); ox = round(lean * (1 - k)); e = barriga(k, b + w)
        x0, x1 = cx - 4 - (w + 1) // 2 + ox, cx + 3 + w // 2 + ox + e
        d.line([(x0, y), (x1, y)], fill=T + (255,))
        d.point((x1, y), fill=t + (255,)); d.point((x0, y), fill=U + (255,))
    tr.alpha_composite(cabeca_img, (9 + lean, 2 + bob))
    tr = contorno(tr)
    im = camada()
    for L in (braco_tras, perna_tras, tr, perna_frente, braco_frente): im.alpha_composite(L)
    return im


def frente(nome, acao, f, cabeca_img, costas=False):
    pal = elenco.C[nome]['pal']; S, s, Lc = pal['S'], pal['s'], pal['L']
    if acao == 'parado':
        bob = [0, 0, 1, 1][f]; la = lb = 0; sway = 0; ba = bb = 0
    elif acao == 'passagem':
        bob = -1; la = lb = 0; sway = 0; ba = bb = 0
    else:
        bob = BOB[f]; la = PE_UP[f]; lb = PE_UP[(f + 4) % 8]
        sway = [0, 0, 1, 1, 0, 0, -1, -1][f] if not costas else -[0, 0, 1, 1, 0, 0, -1, -1][f]
        ba = PE_X[f]; bb = PE_X[(f + 4) % 8]
    cx = 16 + sway; top = 16 + bob; hip = 30 + (bob if acao != 'parado' else 0)
    w, b = biotipo(nome); lw = 4 + (w + 1) // 2
    im = camada()
    # pernas: a que levanta encolhe (joelho vem pra frente: fica mais clara em cima)
    pernas = []
    for i, lift in enumerate((la, lb)):
        L = camada(); d = ImageDraw.Draw(L)
        x0 = cx - 5 - w if i == 0 else cx + 1 + w - (lw - 4)
        xb = x0 - sway  # pe fica no chao, quadril balanca
        yb = CHAO - 1 - lift
        for y in range(hip, yb - 1):
            k = (y - hip) / max(1, yb - 1 - hip); x = round(x0 + (xb - x0) * k)
            d.line([(x, y), (x + lw - 1, y)], fill=CALCA + (255,))
            d.point((x + (lw - 1 if i else 0), y), fill=(CALCA_S if i else CALCA_L) + (255,))
        if lift >= 2:
            d.line([(xb, hip + 6), (xb + lw - 1, hip + 6)], fill=CALCA_L + (255,))
        d.rectangle([xb - (1 if i == 0 else 0), yb - 1, xb + lw - 1 + (1 if i else 0), yb], fill=TENIS + (255,))
        d.line([(xb - (1 if i == 0 else 0), yb + 1), (xb + lw - 1 + (1 if i else 0), yb + 1)], fill=SOLA + (255,))
        pernas.append(contorno(L))
    tr = camada(); d = ImageDraw.Draw(tr)
    tronco_frente(d, cx, top, hip, w, b, costas, s)
    tr.alpha_composite(cabeca_img, (cx - 7, 2 + bob))
    tr = contorno(tr)
    bracos = []
    for i, sw in enumerate((bb, ba)):  # braco esquerdo da tela vai com a perna direita
        L = camada()
        xo = cx - 7 - w if i == 0 else cx + 6 + w
        ombro = (xo, top + 2)
        fwd = -sw if not costas else sw          # >0: braco indo pra frente (mao sobe e entra)
        mao = (xo + (1 if i == 0 else -1) * (1 if fwd > 2 else 0), top + 12 - (1 if fwd > 2 else 0) + (0 if fwd > -3 else 0))
        cot = (xo, top + 7)
        lado_c = (T, S, Lc) if i == 0 else (t, s, s)
        seg(L, ombro, cot, 3, lado_c[0]); seg(L, (xo, top + 6), mao, 3, lado_c[1])
        seg(L, ombro, (xo, top + 4), 3, lado_c[0])
        bloco(L, mao[0], mao[1] + 1, 3, lado_c[2])
        bracos.append(contorno(L))
    for L in pernas: im.alpha_composite(L)
    im.alpha_composite(tr)
    for L in bracos: im.alpha_composite(L)
    return im

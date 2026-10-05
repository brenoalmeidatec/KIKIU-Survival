"""acoes.png: animacoes de corpo inteiro no mesmo estilo do andar (rig.py).
Quadros de 64x64, pe no chao em y=61, centro x=32 (offset no Godot: (-32,-61)).
Cada linha e uma acao; acoes 'de lado' olham para a DIREITA (o jogo espelha para a esquerda)."""
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
import elenco, rig
from rig import seg, bloco, ik, CORPO, biotipo, barriga, tronco_frente, T, t, U, LOGO
from sprites8 import contorno, OUT, CALCA, CALCA_S, CALCA_L, TENIS, SOLA
from final2 import cabeca

W = H = 64
CHAO = 61
ACOES = [  # nome, vista, quadros, fps, loop
    ('abrir_porta_cima', 'cima', 6, 8, False),
    ('abrir_porta_lado', 'lado', 6, 8, False),
    ('cair', 'lado', 8, 10, False),
    ('caido', 'lado', 4, 4, True),
    ('levantar', 'lado', 6, 8, False),
    ('soco', 'lado', 6, 12, False),
    ('empurrao', 'lado', 6, 10, False),
    ('apanhar', 'lado', 6, 10, False),
    ('correr', 'lado', 8, 12, True),
    ('comemorar', 'baixo', 6, 8, True),
    ('cocar_cabeca', 'baixo', 4, 6, True),
    ('bracos_cruzados', 'baixo', 4, 4, True),
    ('apontar', 'lado', 4, 6, False),
    ('assustado', 'baixo', 4, 10, False),
]


def camada():
    return Image.new('RGBA', (W, H), (0, 0, 0, 0))


def girar(im, ang, centro):
    """gira pixel art sem borrar: amplia 8x, gira por vizinho, reduz pegando o centro de cada bloco"""
    if abs(ang) < 1: return im
    k = 8
    big = im.resize((im.width * k, im.height * k), Image.NEAREST)
    big = big.rotate(-ang, resample=Image.NEAREST, center=(centro[0] * k + k / 2, centro[1] * k + k / 2))
    a = np.array(big)[k // 2::k, k // 2::k]
    return Image.fromarray(a)


def perna(hip, pe, cor, escuro, dobra=+1, lift=0):
    L = camada()
    joelho = ik(hip, pe, 7.0, 7.15, dobra)
    seg(L, hip, joelho, 4, cor); seg(L, joelho, (pe[0], pe[1] - 1), 3, cor)
    fx, fy = int(round(pe[0])), int(round(pe[1]))
    ten = TENIS if not escuro else (30, 30, 34)
    for x in range(fx - 2, fx + 4):
        rig.px(L, x, fy, ten); rig.px(L, x, fy + 1 - (1 if (lift and x < fx) else 0), SOLA)
    rig.px(L, fx - 2, fy - 1, ten)
    return contorno(L)


def braco(ombro, mao, manga, pele, mao_cor, dobra=-1):
    L = camada()
    cot = ik(ombro, mao, 5.2, 5.6, dobra)
    seg(L, ombro, cot, 3, manga)
    k = .45; seg(L, (ombro[0] + (cot[0] - ombro[0]) * k, ombro[1] + (cot[1] - ombro[1]) * k), cot, 3, pele)
    seg(L, cot, mao, 3, pele); bloco(L, mao[0], mao[1], 3, mao_cor)
    seg(L, ombro, (ombro[0] + (cot[0] - ombro[0]) * .55, ombro[1] + (cot[1] - ombro[1]) * .55), 3, manga)
    return contorno(L)


def punho(ombro, mao, manga, pele, mao_cor, dobra=-1):
    """braco com mao fechada maior (soco)"""
    L = braco(ombro, mao, manga, pele, mao_cor, dobra)
    d = camada(); bloco(d, mao[0], mao[1], 4, mao_cor); bloco(d, mao[0] - .5, mao[1] + .5, 2, pele)
    L.alpha_composite(contorno(d))
    return L


# ------------------------------------------------------------ vista de lado
def lado(nome, P):
    """P: hip(x,y), inc (graus, + = inclina para frente), pa/pb pes (frente/tras), ma/mb maos (frente/tras),
    cab (dx,dy), giro_cab (graus), olhos, boca, expr, punho_a/punho_b, dobra_a/dobra_b (joelho), cot_a/cot_b (cotovelo)"""
    pal = elenco.C[nome]['pal']; S, s, Lc = pal['S'], pal['s'], pal['L']
    w, b = biotipo(nome)
    hx, hy = P.get('hip', (32, 46))
    ang = math.radians(P.get('inc', 0))
    ax, ay = math.sin(ang), -math.cos(ang)            # eixo do tronco (para cima)
    nx, ny = -ay, ax                                  # normal (para frente)
    top = (hx + ax * 14, hy + ay * 14)
    ombro = (top[0] + ax * -2, top[1] + ay * -2)
    pa, pb = P.get('pa', (34, CHAO - 1)), P.get('pb', (30, CHAO - 1))
    perna_b = perna((hx, hy), pb, CALCA_S, True, P.get('dobra_b', 1), P.get('lift_b', 0))
    perna_a = perna((hx, hy), pa, CALCA, False, P.get('dobra_a', 1), P.get('lift_a', 0))
    ma, mb = P.get('ma', (ombro[0] + 1, ombro[1] + 10)), P.get('mb', (ombro[0] - 1, ombro[1] + 10))
    fb = punho if P.get('punho_b') else braco
    fa = punho if P.get('punho_a') else braco
    braco_b = fb(ombro, mb, t, s, s, P.get('cot_b', -1))
    braco_a = fa(ombro, ma, T, S, Lc, P.get('cot_a', -1))
    # tronco: poligono girado, barriga para frente
    tr = camada(); d = ImageDraw.Draw(tr)
    back, front = 4 + (w + 1) // 2, 3 + w // 2
    for i in range(0, 15):
        k = i / 14; e = barriga(1 - k, b + w)
        c = (hx + ax * i, hy + ay * i)
        p0 = (c[0] - nx * back, c[1] - ny * back); p1 = (c[0] + nx * (front + e), c[1] + ny * (front + e))
        d.line([p0, p1], fill=T + (255,), width=2)
    for i in range(0, 15):
        k = i / 14; e = barriga(1 - k, b + w); c = (hx + ax * i, hy + ay * i)
        d.point((round(c[0] + nx * (front + e)), round(c[1] + ny * (front + e))), fill=t + (255,))
        d.point((round(c[0] - nx * back), round(c[1] - ny * back)), fill=U + (255,))
    for i in range(-1, 2):
        c = (hx + ax * i, hy + ay * i)
        d.line([(c[0] - nx * back, c[1] - ny * back), (c[0] + nx * front, c[1] + ny * front)], fill=CALCA + (255,), width=2)
    h = cabeca(nome, P.get('vista_cab', 'lado'), P.get('boca', 'c'), P.get('olhos', 'abertos'), P.get('expr', ()))
    cdx, cdy = P.get('cab', (0, 0))
    hl = camada(); hl.alpha_composite(h, (int(round(top[0] - 7 + cdx)), int(round(top[1] - 14 + cdy))))
    gc = P.get('giro_cab', P.get('inc', 0))
    if abs(gc) >= 8: hl = girar(hl, gc, (top[0], top[1]))
    tr.alpha_composite(hl)
    tr = contorno(tr)
    im = camada()
    ordem = [braco_b, perna_b, tr, perna_a, braco_a] if not P.get('braco_a_atras') else [braco_b, braco_a, perna_b, tr, perna_a]
    for L in ordem: im.alpha_composite(L)
    if P.get('girar'):  # corpo inteiro (queda): gira numa tela maior e recentraliza no chao
        big = Image.new('RGBA', (W * 2, H * 2), (0, 0, 0, 0)); big.alpha_composite(im, (W // 2, H // 2))
        pv = P.get('pivo', (32, CHAO)); big = girar(big, P['girar'], (pv[0] + W // 2, pv[1] + H // 2))
        x0, y0, x1, y1 = big.getbbox()
        cxb = (x0 + x1) // 2 if P['girar'] > 40 else pv[0] + W // 2 + (P['girar'] // 4)
        im = big.crop((cxb - W // 2, y1 - (CHAO + 2), cxb + W // 2, y1 - (CHAO + 2) + H))
    if P.get('dy'): im = im.transform(im.size, Image.AFFINE, (1, 0, 0, 0, 1, -P['dy']))
    if P.get('dx'): im = im.transform(im.size, Image.AFFINE, (1, 0, -P['dx'], 0, 1, 0))
    return im


# ------------------------------------------------------------ vista de frente/costas
def frente(nome, P, costas=False):
    pal = elenco.C[nome]['pal']; S, s, Lc = pal['S'], pal['s'], pal['L']
    w, b = biotipo(nome); lw = 4 + (w + 1) // 2
    cx, hip = P.get('hip', (32, 46)); top = hip - 14 - P.get('resp', 0)
    im = camada()
    for i in range(2):
        L = camada(); d = ImageDraw.Draw(L)
        x0 = cx - 5 - w if i == 0 else cx + 1 + w - (lw - 4)
        lift = P.get('lift', (0, 0))[i]; pe_dx = P.get('pes_dx', (0, 0))[i]
        xb = x0 + pe_dx; yb = P.get('chao', CHAO) - 1 - lift
        for y in range(hip, yb - 1):
            k = (y - hip) / max(1, yb - 1 - hip); x = round(x0 + (xb - x0) * k)
            d.line([(x, y), (x + lw - 1, y)], fill=CALCA + (255,))
            d.point((x + (lw - 1 if i else 0), y), fill=(CALCA_S if i else CALCA_L) + (255,))
        d.rectangle([xb - (1 if i == 0 else 0), yb - 1, xb + lw - 1 + (1 if i else 0), yb], fill=TENIS + (255,))
        d.line([(xb - (1 if i == 0 else 0), yb + 1), (xb + lw - 1 + (1 if i else 0), yb + 1)], fill=SOLA + (255,))
        im.alpha_composite(contorno(L))
    tr = camada(); d = ImageDraw.Draw(tr)
    tronco_frente(d, cx, top, hip, w, b, costas, s)
    h = cabeca(nome, 'costas' if costas else 'frente', P.get('boca', 'c'), P.get('olhos', 'abertos'), P.get('expr', ()))
    cdx, cdy = P.get('cab', (0, 0))
    tr.alpha_composite(h, (cx - 7 + cdx, top - 14 + cdy))
    tr = contorno(tr)
    oE, oD = (cx - 7 - w, top + 2), (cx + 6 + w, top + 2)
    mE = P.get('mE', (oE[0], oE[1] + 10)); mD = P.get('mD', (oD[0], oD[1] + 10))
    ce, cd = (T, S, Lc), (t, s, s)
    bE = braco(oE, mE, *ce, dobra=P.get('cotE', -1)); bD = braco(oD, mD, *cd, dobra=P.get('cotD', 1))
    atras = P.get('atras', ())
    for nm_, L in (('E', bE), ('D', bD)):
        if nm_ in atras: im.alpha_composite(L)
    im.alpha_composite(tr)
    for nm_, L in (('E', bE), ('D', bD)):
        if nm_ not in atras: im.alpha_composite(L)
    if P.get('dy'): im = im.transform(im.size, Image.AFFINE, (1, 0, 0, 0, 1, -P['dy']))
    return im


# ------------------------------------------------------------ acoes (quadros-chave)
def em_pe(**kw):
    P = dict(hip=(32, 46), pa=(34, CHAO - 1), pb=(30, CHAO - 1)); P.update(kw); return P


def quadros(nome, acao):
    O = (32, 46 - 14 + 2)  # ombro de pe (lado)
    ox, oy = 32, 34
    F = []
    if acao == 'abrir_porta_cima':
        # de costas: estica o braco ate a macaneta, empurra e da um passo
        F = [dict(), dict(mD=(40, 26), cotD=1), dict(mD=(40, 20), cotD=1), dict(mD=(40, 20), cotD=1, dy=1, lift=(0, 1)),
             dict(mD=(39, 17), cotD=1, dy=2, lift=(2, 0), atras=('D',)), dict(mD=(38, 18), cotD=1, dy=1, lift=(0, 0))]
        return [frente(nome, P, costas=True) for P in F]
    if acao == 'abrir_porta_lado':
        F = [em_pe(), em_pe(ma=(43, 38), cot_a=-1), em_pe(ma=(45, 37), inc=5),
             em_pe(ma=(47, 37), inc=8, pa=(37, CHAO - 1), hip=(33, 46)),
             em_pe(ma=(48, 36), inc=6, pa=(40, CHAO - 1), pb=(31, CHAO - 2), lift_b=1, hip=(35, 46)),
             em_pe(ma=(47, 40), inc=2, pa=(40, CHAO - 1), pb=(36, CHAO - 1), hip=(37, 46))]
        return [lado(nome, P) for P in F]
    if acao == 'cair':
        # tropeca, bracos sobem, tomba para frente, bate no chao e quica
        F = [em_pe(inc=6, pa=(38, CHAO - 3), lift_a=1, ma=(38, 42), mb=(26, 42)),
             em_pe(inc=14, hip=(33, 47), pa=(40, CHAO - 4), pb=(30, CHAO - 1), ma=(42, 30), mb=(36, 26), olhos='fechados', boca='o', expr=('sobrancelha',)),
             em_pe(inc=18, girar=25, pivo=(30, CHAO), ma=(44, 26), mb=(38, 22), boca='o', expr=('sobrancelha',)),
             em_pe(inc=18, girar=50, pivo=(30, CHAO), ma=(46, 30), mb=(40, 24), boca='o', expr=('sobrancelha',)),
             em_pe(inc=10, girar=78, pivo=(30, CHAO), ma=(42, 34), mb=(36, 30), boca='o', olhos='fechados'),
             em_pe(girar=90, pivo=(30, CHAO), dy=1, ma=(40, 36), mb=(36, 34), olhos='fechados'),
             em_pe(girar=88, pivo=(30, CHAO), dy=2, ma=(40, 38), mb=(36, 36), olhos='fechados'),
             em_pe(girar=90, pivo=(30, CHAO), dy=1, ma=(39, 41), mb=(35, 40), olhos='fechados')]
        return [lado(nome, P) for P in F]
    if acao == 'caido':
        F = [em_pe(girar=90, pivo=(30, CHAO), dy=1, ma=(39, 41), mb=(35, 40), olhos='fechados'),
             em_pe(girar=90, pivo=(30, CHAO), dy=1, ma=(39, 41), mb=(35, 40), olhos='fechados', hip=(32, 45)),
             em_pe(girar=90, pivo=(30, CHAO), dy=1, ma=(39, 41), mb=(35, 40), olhos='fechados'),
             em_pe(girar=90, pivo=(30, CHAO), dy=1, ma=(39, 41), mb=(35, 40), boca='m')]
        return [lado(nome, P) for P in F]
    if acao == 'levantar':
        F = [em_pe(girar=90, pivo=(30, CHAO), dy=1, ma=(39, 41), mb=(35, 40)),
             em_pe(girar=60, pivo=(30, CHAO), ma=(44, 44), mb=(40, 44), inc=10),
             # ajoelhado: um joelho no chao
             dict(hip=(31, 52), inc=28, pa=(38, CHAO - 1), pb=(24, CHAO - 1), dobra_b=1, ma=(42, CHAO - 2), mb=(38, CHAO - 2)),
             dict(hip=(31, 50), inc=18, pa=(37, CHAO - 1), pb=(25, CHAO - 1), ma=(40, 48), mb=(36, 46)),
             em_pe(hip=(32, 48), inc=8, pb=(28, CHAO - 1), ma=(36, 42), mb=(30, 42)),
             em_pe(boca='m', expr=('sobrancelha',))]
        return [lado(nome, P) for P in F]
    if acao == 'soco':
        guarda = dict(ma=(39, 34), mb=(36, 33), cot_a=1, cot_b=1, punho_a=True, punho_b=True)
        F = [em_pe(**guarda), em_pe(**{**guarda, 'inc': -4, 'ma': (34, 34)}),
             em_pe(**{**guarda, 'inc': 8, 'ma': (47, 32), 'cot_a': -1, 'pa': (37, CHAO - 1), 'hip': (33, 46), 'boca': 'o', 'expr': ('sobrancelha',)}),
             em_pe(**{**guarda, 'inc': 9, 'ma': (48, 32), 'cot_a': -1, 'pa': (37, CHAO - 1), 'hip': (33, 46), 'boca': 'o'}),
             em_pe(**{**guarda, 'inc': 4, 'ma': (42, 33), 'hip': (33, 46), 'pa': (36, CHAO - 1)}), em_pe(**guarda)]
        return [lado(nome, P) for P in F]
    if acao == 'empurrao':
        F = [em_pe(), em_pe(ma=(38, 34), mb=(36, 34), inc=-3),
             em_pe(ma=(46, 34), mb=(44, 35), inc=12, pa=(38, CHAO - 1), hip=(34, 46), boca='o', expr=('sobrancelha',)),
             em_pe(ma=(47, 34), mb=(45, 35), inc=14, pa=(39, CHAO - 1), pb=(28, CHAO - 1), hip=(34, 46), boca='o'),
             em_pe(ma=(42, 38), mb=(40, 38), inc=6, pa=(38, CHAO - 1), hip=(33, 46)), em_pe()]
        return [lado(nome, P) for P in F]
    if acao == 'apanhar':
        F = [em_pe(), em_pe(inc=-12, giro_cab=-20, cab=(-1, 0), ma=(28, 38), mb=(26, 36), olhos='fechados', boca='o', dx=-1),
             em_pe(inc=-16, giro_cab=-25, cab=(-1, 1), ma=(26, 36), mb=(22, 34), olhos='fechados', boca='o', dx=-3, pb=(27, CHAO - 1)),
             em_pe(inc=-8, ma=(30, 42), mb=(26, 40), boca='m', dx=-4, pb=(26, CHAO - 1), pa=(31, CHAO - 2), lift_a=1),
             em_pe(inc=-3, dx=-4, boca='m', expr=('sobrancelha',)), em_pe(dx=-4, expr=('sobrancelha',))]
        return [lado(nome, P) for P in F]
    if acao == 'correr':
        PX = [8, 4, 0, -5, -8, -5, 0, 5]; UP = [0, 0, 1, 3, 4, 3, 2, 1]; BOB = [1, 2, 0, -1, 1, 2, 0, -1]
        for f in range(8):
            g = (f + 4) % 8
            F.append(em_pe(hip=(32, 46 + BOB[f]), inc=12, pa=(32 + PX[f], CHAO - 1 - UP[f]), pb=(32 + PX[g], CHAO - 1 - UP[g]),
                           lift_a=UP[f] > 0, lift_b=UP[g] > 0, dobra_a=1, dobra_b=1,
                           ma=(36 - PX[f] * .7, 38 + BOB[f] - 2), mb=(36 - PX[g] * .7, 38 + BOB[f] - 2), cot_a=-1, cot_b=-1))
        return [lado(nome, P) for P in F]
    if acao == 'comemorar':
        F = [dict(), dict(dy=-1, mE=(20, 26), mD=(44, 26), boca='m', expr=('sorriso',)),
             dict(dy=-4, mE=(21, 18), mD=(43, 18), lift=(2, 2), boca='o', expr=('sorriso',)),
             dict(dy=-6, mE=(22, 15), mD=(42, 15), lift=(3, 3), boca='o', expr=('riso', 'sorriso')),
             dict(dy=-3, mE=(21, 19), mD=(43, 19), lift=(1, 1), boca='o', expr=('sorriso',)),
             dict(dy=0, mE=(20, 26), mD=(44, 26), boca='m', expr=('sorriso',))]
        return [frente(nome, P) for P in F]
    if acao == 'cocar_cabeca':
        F = [dict(mD=(38, 20), cotD=1, expr=('lado',)), dict(mD=(37, 19), cotD=1, expr=('lado',)),
             dict(mD=(38, 20), cotD=1, expr=('lado',), olhos='fechados'), dict(mD=(37, 19), cotD=1, expr=('lado',))]
        return [frente(nome, P) for P in F]
    if acao == 'bracos_cruzados':
        F = [dict(mE=(36, 40), mD=(28, 41), cotE=-1, cotD=1), dict(mE=(36, 40), mD=(28, 41), cotE=-1, cotD=1, dy=0),
             dict(mE=(36, 40), mD=(28, 41), cotE=-1, cotD=1, olhos='fechados'), dict(mE=(36, 40), mD=(28, 41), cotE=-1, cotD=1)]
        return [frente(nome, P) for P in F]
    if acao == 'apontar':
        F = [em_pe(), em_pe(ma=(42, 32), cot_a=-1), em_pe(ma=(46, 30), inc=3, boca='m', expr=('sobrancelha',)),
             em_pe(ma=(46, 30), inc=3, boca='o', expr=('sobrancelha',))]
        return [lado(nome, P) for P in F]
    if acao == 'assustado':
        F = [dict(), dict(dy=-3, mE=(20, 22), mD=(44, 22), lift=(2, 2), boca='o', expr=('sobrancelha',)),
             dict(dy=-1, mE=(22, 28), mD=(42, 28), boca='o', expr=('sobrancelha',)),
             dict(mE=(24, 34), mD=(40, 34), boca='m', expr=('sobrancelha',))]
        return [frente(nome, P) for P in F]
    raise KeyError(acao)


def folha(nome):
    n = max(a[2] for a in ACOES)
    sh = Image.new('RGBA', (W * n, H * len(ACOES)), (0, 0, 0, 0))
    for r, (ac, _, nq, _, _) in enumerate(ACOES):
        fr = quadros(nome, ac)
        assert len(fr) == nq, (ac, len(fr))
        for c, im in enumerate(fr): sh.paste(im, (c * W, r * H))
    return sh


if __name__ == '__main__':
    out = sys.argv[1]
    for n in sys.argv[2:]:
        os.makedirs(f'{out}/{n}', exist_ok=True); folha(n).save(f'{out}/{n}/acoes.png'); print('ok', n, flush=True)

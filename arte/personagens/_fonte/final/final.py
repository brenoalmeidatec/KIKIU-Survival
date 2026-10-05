"""Arte final dos personagens no formato aprovado (referencia do Breno).
Gera, por personagem: andando.png (44x60, 4x4, igual ao jogo), cena.png (27 quadros 100x140, ordem QUADROS),
rosto.png (27 quadros 52x52 do rosto para dialogo, mesma ordem) e folha_completa.png (parado+andando 32x48)."""
import sys, os, json
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
import elenco
from sprites8 import grade, contorno, corpo_frente, corpo_lado, R, OUT, CALCA, CALCA_S, CALCA_L, TENIS, SOLA
from retratos3 import CAIRU

QUADROS = ["idle_c", "idle_m", "idle_o", "talk1_c", "talk1_m", "talk1_o", "talk2_c", "talk2_m", "talk2_o",
           "point_c", "point_m", "point_o", "shrug_c", "shrug_m", "shrug_o", "think_c", "think_m", "think_o",
           "cross_c", "cross_m", "cross_o", "idle_b", "piscar", "laugh_a", "laugh_b", "wave_a", "wave_b"]

LABIO = (128, 64, 62); ESCURO = (70, 28, 32)

def cabeca(nome, vista='frente', boca='c', olhos='abertos'):
    d = elenco.C[nome]; rows = [list(r) for r in d[vista]]
    pal = dict(d['pal']); pal['M'] = LABIO
    if vista != 'costas':
        if vista == 'frente':
            ry, x0, x1 = d['boca']
            for x in range(x0, x1 + 1):
                if rows[ry][x] in 'mM':
                    rows[ry][x] = {'c': 'M' if rows[ry][x] == 'M' else 's', 'm': 'm', 'o': 'm'}[boca]
            if boca == 'o':
                for x in range(x0 + 1, x1):
                    if rows[ry + 1][x] not in 'K.': rows[ry + 1][x] = 'm'
                for x in range(x0 + 1, x1):
                    if rows[ry][x] == 'm': rows[ry][x] = 'T'
                    break
        else:
            for y, r in enumerate(rows):
                for x, ch in enumerate(r):
                    if ch == 'm': rows[y][x] = {'c': 's', 'm': 'm', 'o': 'm'}[boca]
                    if ch == 'M': rows[y][x] = 'M' if boca == 'c' else 'm'
        if olhos != 'abertos':
            for y in d['olhos'] if vista == 'frente' else range(15):
                for x, ch in enumerate(rows[y]):
                    if ch in 'EW': rows[y][x] = 'K' if (olhos == 'fechados' and ch == 'E') else 's'
    pal['m'] = ESCURO
    return grade([''.join(r) for r in rows], pal)

def folha_completa(nome):
    pal = elenco.C[nome]['pal']
    sh = Image.new('RGBA', (32 * 8, 48 * 4), (0, 0, 0, 0))
    for ai, acao in enumerate(('parado', 'andando')):
        for row, dr in enumerate(['baixo', 'esquerda', 'direita', 'cima']):
            for f in range(4):
                im = Image.new('RGBA', (32, 48), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
                if dr in ('baixo', 'cima'):
                    bob = corpo_frente(d, pal, acao, f, costas=(dr == 'cima'))
                    h = cabeca(nome, 'frente' if dr == 'baixo' else 'costas')
                else:
                    bob = corpo_lado(d, pal, acao, f); h = cabeca(nome, 'lado')
                im.alpha_composite(h, (9, 2 + bob))
                im = contorno(im)
                if dr == 'esquerda': im = im.transpose(Image.FLIP_LEFT_RIGHT)
                sh.paste(im, ((ai * 4 + f) * 32, row * 48))
    return sh

def andando(sh):
    """layout do jogo: 44x60, colunas parado, passo A, passo B, passagem; pe em y=58"""
    g = Image.new('RGBA', (44 * 4, 60 * 4), (0, 0, 0, 0))
    for row in range(4):
        for col, src in enumerate([0, 4, 6, 5]):
            g.paste(sh.crop((src * 32, row * 48, src * 32 + 32, row * 48 + 48)), (col * 44 + 6, row * 60 + 13))
    return g

# ---- poses de corpo inteiro (desenhadas em 1x 33x46 e ampliadas 3x) ----
PW, PH = 33, 46
def braco(d, ombro, cotovelo, mao, pal, frente=True):
    S = pal['S']; T = CAIRU['T']
    for w, cor in ((5, OUT), (3, None)):
        d.line([ombro, cotovelo], fill=(OUT if cor else T) + (255,), width=w)
        d.line([cotovelo, mao], fill=(OUT if cor else S) + (255,), width=w)
    mx, my = mao
    d.rectangle([mx - 1, my - 1, mx + 1, my + 1], fill=pal['L'] + (255,))
    # manga cobre o comeco do braco
    ox, oy = ombro; cx_, cy_ = cotovelo
    d.line([ombro, (round(ox + (cx_ - ox) * .55), round(oy + (cy_ - oy) * .55))], fill=T + (255,), width=3)

POSES = {
    # (cotovelo, mao) relativos ao ombro, braco da esquerda da tela (L) e da direita (R)
    'idle':  (((-1, 6), (-1, 11)), ((1, 6), (1, 11))),
    'talk1': (((-1, 6), (-1, 11)), ((2, 6), (6, 3))),
    'talk2': (((-3, 5), (-6, 8)), ((3, 5), (6, 8))),
    'point': (((-1, 6), (-1, 11)), ((5, 0), (11, 0))),
    'shrug': (((-4, 4), (-8, 1)), ((4, 4), (8, 1))),
    'think': (((-1, 6), (5, 7)), ((2, 7), (-3, -2))),
    'cross': (((-1, 6), (9, 5)), ((1, 6), (-9, 6))),
    'wave':  (((-1, 6), (-1, 11)), ((4, -3), (5, -9))),
    'wave2': (((-1, 6), (-1, 11)), ((4, -3), (8, -8))),
    'laugh': (((-2, 6), (4, 9)), ((2, 6), (-4, 9))),
}

def pose(nome, gesto, boca, olhos, bob=0):
    pal = elenco.C[nome]['pal']
    im = Image.new('RGBA', (PW, PH), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    cx = 16; top = 16 + bob; hip = 29 + bob
    T, t, U = CAIRU['T'], CAIRU['t'], CAIRU['U']
    for i in range(2):
        x0 = cx - 5 if i == 0 else cx + 1
        R(d, x0, hip, x0 + 3, 42, CALCA)
        R(d, x0 + (3 if i else 0), hip + 1, x0 + (3 if i else 0), 42, CALCA_S if i else CALCA_L)
        R(d, x0 - (1 if i == 0 else 0), 43, x0 + 3 + (1 if i else 0), 44, TENIS)
        R(d, x0 - (1 if i == 0 else 0), 45, x0 + 3 + (1 if i else 0), 45, SOLA)
    R(d, cx - 5, hip - 1, cx + 4, hip + 1, CALCA)
    R(d, cx - 5, top, cx + 4, hip - 1, T); R(d, cx + 2, top + 1, cx + 4, hip - 1, t)
    R(d, cx - 5, top + 1, cx - 4, hip - 2, U); R(d, cx - 5, hip - 1, cx + 4, hip - 1, t)
    R(d, cx - 2, top, cx + 1, top, pal['s'])
    for (x, y) in [(cx - 3, top + 3), (cx - 2, top + 3), (cx - 1, top + 3), (cx - 3, top + 4)]:
        d.point((x, y), fill=CAIRU['W'] + (255,))
    (le, lm), (re_, rm) = POSES[gesto]
    oL = (cx - 6, top + 2); oR = (cx + 5, top + 2)
    na_frente = gesto in ('cross', 'think', 'laugh')
    bracos = [(oL, le, lm), (oR, re_, rm)]
    if not na_frente:
        for o, e, m in bracos: braco(d, o, (o[0] + e[0], o[1] + e[1]), (o[0] + m[0], o[1] + m[1]), pal)
    h = cabeca(nome, 'frente', boca, olhos)
    im.alpha_composite(h, (cx - 7, 2 + bob))
    if na_frente:
        for o, e, m in bracos: braco(d, o, (o[0] + e[0], o[1] + e[1]), (o[0] + m[0], o[1] + m[1]), pal)
    return contorno(im)

def cena(nome):
    sh = Image.new('RGBA', (100 * len(QUADROS), 140), (0, 0, 0, 0))
    for i, q in enumerate(QUADROS):
        if q in ('idle_b',): im = pose(nome, 'idle', 'c', 'abertos', 1)
        elif q == 'piscar': im = pose(nome, 'idle', 'c', 'fechados')
        elif q == 'laugh_a': im = pose(nome, 'laugh', 'o', 'fechados')
        elif q == 'laugh_b': im = pose(nome, 'laugh', 'o', 'fechados', 1)
        elif q == 'wave_a': im = pose(nome, 'wave', 'm', 'abertos')
        elif q == 'wave_b': im = pose(nome, 'wave2', 'o', 'abertos')
        else:
            g, b = q.split('_'); im = pose(nome, g, b, 'abertos')
        big = im.resize((PW * 3, PH * 3), Image.NEAREST)
        sh.alpha_composite(big, (i * 100 + 1, 140 - PH * 3))
    return sh

if __name__ == '__main__':
    out = sys.argv[1]
    for n in (sys.argv[2:] or list(elenco.C)):
        os.makedirs(f'{out}/{n}', exist_ok=True)
        fc = folha_completa(n); fc.save(f'{out}/{n}/folha_completa.png')
        andando(fc).save(f'{out}/{n}/andando.png')
        cena(n).save(f'{out}/{n}/cena.png')
        print('ok', n)

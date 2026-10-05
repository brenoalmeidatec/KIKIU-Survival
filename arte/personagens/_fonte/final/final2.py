"""Versao 2 da arte final: esqueleto (rig.py) com andar de 8 quadros, cabeca presa ao tronco,
expressoes (sobrancelha, sorriso, olhar, riso) e poses de cena com o corpo acompanhando."""
import sys, os
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
import elenco, rig
LABIO = (112, 54, 52)
from final import QUADROS, ESCURO, PW, PH, POSES, braco
from sprites8 import grade, contorno, R, CALCA, CALCA_S, CALCA_L, TENIS, SOLA
from retratos3 import CAIRU


def queixo(rows):
    """queixo mais curto e arredondado: mantem ate a linha 12 e fecha com contorno embaixo"""
    rows = [r[:] for r in rows]
    base = rows[12]
    xs = [x for x, ch in enumerate(base) if ch not in 'K.']
    if not xs: return rows
    rows[13] = ['.'] * 14; rows[14] = ['.'] * 14
    for x in range(min(xs), max(xs) + 1): rows[13][x] = 'K'
    return rows


def cabeca(nome, vista='frente', boca='c', olhos='abertos', expr=()):
    d = elenco.C[nome]; rows = [list(r) for r in d[vista]]
    if vista != 'costas' and not d.get('gemini'): rows = queixo(rows)
    pal = dict(d['pal']); pal['M'] = LABIO; pal['m'] = ESCURO
    if vista == 'costas': return grade([''.join(r) for r in rows], pal)
    if vista == 'frente':
        ry, x0, x1 = d['boca']; oy = d['olhos'][0]
        sorri = 'sorriso' in expr
        for x in range(x0, x1 + 1):
            if rows[ry][x] in 'mM':
                rows[ry][x] = {'c': 'M' if rows[ry][x] == 'M' else 's', 'm': 'm', 'o': 'm'}[boca]
                if sorri and boca == 'c': rows[ry][x] = 'm' if x not in (x0, x1) else rows[ry][x]
        if boca == 'o':
            for x in range(x0 + 1, x1):
                if rows[ry + 1][x] not in 'K.': rows[ry + 1][x] = 'm'
            for x in range(x0 + 1, x1):
                if rows[ry][x] == 'm': rows[ry][x] = 'T'; break
        if sorri:  # cantos da boca sobem
            for x in (x0 - 1, x1 + 1):
                if rows[ry - 1][x] not in 'K.': rows[ry - 1][x] = 'm' if boca != 'c' else 's'
            for x in (x0, x1):
                if rows[ry][x] not in 'K.' and boca == 'c': rows[ry][x] = 's'
            for x in (x0 - 1, x1 + 1):
                if rows[ry - 1][x] not in 'K.': rows[ry - 1][x] = 'm'
        if 'sobrancelha' in expr:  # sobrancelhas sobem 1 px
            for x in range(14):
                if rows[oy - 1][x] in 'Hh' and rows[oy - 2][x] in 'SLs':
                    rows[oy - 2][x] = rows[oy - 1][x]; rows[oy - 1][x] = 'S'
        if 'bravo' in expr:  # pontas internas descem
            for x in range(4, 10):
                if rows[oy - 1][x] in 'SLs' and (rows[oy - 1][x - 1] in 'Hh' or rows[oy - 1][x + 1] in 'Hh') and x in (5, 6, 7, 8):
                    pass
        if 'lado' in expr:  # olha para o lado (pupilas para a direita da tela)
            r = rows[oy]
            for x in range(13):
                if r[x] == 'E' and r[x + 1] == 'W': r[x], r[x + 1] = 'W', 'E'
        if 'esq' in expr:  # olha para a esquerda da tela
            r = rows[oy]
            for x in range(13):
                if r[x] == 'W' and r[x + 1] == 'E': r[x], r[x + 1] = 'E', 'W'
        if 'bravo' in expr:  # sobrancelhas em V
            r = rows[oy - 1]; hs = [x for x in range(14) if r[x] in 'Hh']
            if len(hs) >= 4:
                a_, b_, c_, d_ = hs[0], hs[1], hs[-2], hs[-1]
                r[b_] = 'K'; r[c_] = 'K'
                if rows[oy - 2][a_] in 'SLs': rows[oy - 2][a_] = 'H'; r[a_] = 'S'
                if rows[oy - 2][d_] in 'SLs': rows[oy - 2][d_] = 'H'; r[d_] = 'S'
            if boca == 'c':
                ry, x0, x1 = d['boca']
                for x in range(x0, x1 + 1):
                    if rows[ry][x] in 'sMm': rows[ry][x] = 'm'
                for x in (x0 - 1, x1 + 1):
                    if rows[ry + 1][x] not in 'K.': rows[ry + 1][x] = 'm'
        if 'vergonha' in expr:  # bochechas coradas e olhar para baixo
            pal['V'] = (226, 118, 118)
            r = rows[oy + 1]; xs = [x for x in range(14) if r[x] not in 'K.']
            for x in (xs[0] + 1, xs[-1] - 1) if xs else ():
                r[x] = 'V'
            for x in range(14):
                if rows[oy][x] == 'W': rows[oy][x] = 's'
        if 'lagrima' in expr:
            pal['A'] = (120, 190, 250)
            r = rows[oy + 1]; xs = [x for x in range(14) if r[x] not in 'K.']
            for x in (xs[1], xs[-2]) if len(xs) > 3 else ():
                r[x] = 'A'
                if rows[oy + 2][x] not in 'K.': rows[oy + 2][x] = 'A'
        if 'riso' in expr or olhos == 'fechados':
            for x in range(14):
                if rows[oy][x] in 'EW':
                    rows[oy][x] = 'K' if rows[oy][x] == 'E' or 'riso' in expr else 's'
            if 'riso' in expr:
                for x in range(14):
                    if rows[oy][x] == 'K' and 0 < x < 13 and rows[oy][x - 1] not in 'K.' and rows[oy][x + 1] not in 'K.':
                        pass
    else:
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch == 'm': rows[y][x] = {'c': 's', 'm': 'm', 'o': 'm'}[boca]
                if ch == 'M': rows[y][x] = 'M' if boca == 'c' else 'm'
        if olhos != 'abertos':
            for y in range(15):
                for x, ch in enumerate(rows[y]):
                    if ch in 'EW': rows[y][x] = 'K' if ch == 'E' else 's'
    return grade([''.join(r) for r in rows], pal)


# ---------------- folhas de andar ----------------
DIRS = ['baixo', 'esquerda', 'direita', 'cima']


def quadro(nome, dr, acao, f, olhos='abertos'):
    if dr in ('baixo', 'cima'):
        h = cabeca(nome, 'frente' if dr == 'baixo' else 'costas', olhos=olhos)
        return rig.frente(nome, acao, f, h, costas=(dr == 'cima'))
    im = rig.lado(nome, acao, f, cabeca(nome, 'lado', olhos=olhos))
    return im.transpose(Image.FLIP_LEFT_RIGHT) if dr == 'esquerda' else im


def folha_completa(nome):
    """12 colunas de 32x48: parado 0-3, andando 4-11 (8 quadros); 4 linhas de direcao"""
    sh = Image.new('RGBA', (32 * 12, 48 * 4), (0, 0, 0, 0))
    for row, dr in enumerate(DIRS):
        for col in range(12):
            acao, f = ('parado', col) if col < 4 else ('andando', col - 4)
            sh.paste(quadro(nome, dr, acao, f, 'fechados' if (acao == 'parado' and f == 3) else 'abertos'), (col * 32, row * 48))
    return sh


def andando(nome):
    """layout atual do jogo: 44x60, colunas parado, passo A, passo B, passagem (CICLO 1,3,2,3)"""
    g = Image.new('RGBA', (44 * 4, 60 * 4), (0, 0, 0, 0))
    for row, dr in enumerate(DIRS):
        for col, (acao, f) in enumerate([('parado', 0), ('andando', 0), ('andando', 4), ('passagem', 0)]):
            g.paste(quadro(nome, dr, acao, f), (col * 44 + 6, row * 60 + 13))
    return g


def andando8(nome):
    """opcional, mais fluido: 9 colunas de 44x60 (parado + 8 do andar). CICLO 1..8 a 10 fps"""
    g = Image.new('RGBA', (44 * 9, 60 * 4), (0, 0, 0, 0))
    for row, dr in enumerate(DIRS):
        for col in range(9):
            acao, f = ('parado', 0) if col == 0 else ('andando', col - 1)
            g.paste(quadro(nome, dr, acao, f), (col * 44 + 6, row * 60 + 13))
    return g


# ---------------- poses de cena ----------------
# por gesto: expressao, deslocamento da cabeca (dx, dy), ombros (dy), inclinacao do tronco
GESTO = {
    'idle':  dict(expr=(), cab=(0, 0), omb=0),
    'talk1': dict(expr=(), cab=(1, 0), omb=0),
    'talk2': dict(expr=('sobrancelha',), cab=(0, 0), omb=0),
    'point': dict(expr=('sobrancelha',), cab=(1, 0), omb=0),
    'shrug': dict(expr=('sobrancelha',), cab=(0, 1), omb=-1),
    'think': dict(expr=('lado',), cab=(1, 1), omb=0),
    'cross': dict(expr=(), cab=(0, 0), omb=0),
    'wave':  dict(expr=('sorriso',), cab=(-1, 0), omb=0),
    'wave2': dict(expr=('sorriso',), cab=(-1, 0), omb=0),
    'laugh': dict(expr=('riso', 'sorriso'), cab=(0, -1), omb=0),
}


def pose(nome, gesto, boca, olhos, bob=0):
    pal = elenco.C[nome]['pal']; G = GESTO[gesto]
    im = Image.new('RGBA', (PW, PH), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    cx = 16; top = 16 + bob + G['omb']; hip = 29
    w, b = rig.biotipo(nome); lw = 4 + (w + 1) // 2
    for i in range(2):
        x0 = cx - 5 - w if i == 0 else cx + 1 + w - (lw - 4); x1 = x0 + lw - 1
        R(d, x0, hip, x1, 42, CALCA)
        R(d, x1 if i else x0, hip + 1, x1 if i else x0, 42, CALCA_S if i else CALCA_L)
        R(d, x0 - (1 if i == 0 else 0), 43, x1 + (1 if i else 0), 44, TENIS)
        R(d, x0 - (1 if i == 0 else 0), 45, x1 + (1 if i else 0), 45, SOLA)
    rig.tronco_frente(d, cx, top, hip, w, b, False, pal['s'])
    (le, lm), (re_, rm) = POSES[gesto]
    oL = (cx - 6 - w, top + 2); oR = (cx + 5 + w, top + 2)
    na_frente = gesto in ('cross', 'think', 'laugh')
    bracos = [(oL, le, lm), (oR, re_, rm)]
    if not na_frente:
        for o, e, m in bracos: braco(d, o, (o[0] + e[0], o[1] + e[1]), (min(PW - 3, o[0] + m[0]), o[1] + m[1]), pal)
    h = cabeca(nome, 'frente', boca, olhos, G['expr'])
    hx, hy = G['cab']
    im.alpha_composite(h, (cx - 7 + hx, 2 + bob + hy + G['omb'] * 0))
    if na_frente:
        for o, e, m in bracos: braco(d, o, (o[0] + e[0], o[1] + e[1]), (o[0] + m[0], o[1] + m[1]), pal)
    return contorno(im)


def cena(nome):
    sh = Image.new('RGBA', (100 * len(QUADROS), 140), (0, 0, 0, 0))
    for i, q in enumerate(QUADROS):
        if q == 'idle_b': im = pose(nome, 'idle', 'c', 'abertos', 1)
        elif q == 'piscar': im = pose(nome, 'idle', 'c', 'fechados')
        elif q == 'laugh_a': im = pose(nome, 'laugh', 'o', 'fechados')
        elif q == 'laugh_b': im = pose(nome, 'laugh', 'o', 'fechados', 1)
        elif q == 'wave_a': im = pose(nome, 'wave', 'm', 'abertos')
        elif q == 'wave_b': im = pose(nome, 'wave2', 'o', 'abertos')
        else:
            g, b = q.split('_'); im = pose(nome, g, b, 'abertos')
        sh.alpha_composite(im.resize((PW * 3, PH * 3), Image.NEAREST), (i * 100 + 1, 140 - PH * 3))
    return sh


if __name__ == '__main__':
    out = sys.argv[1]
    for n in (sys.argv[2:] or list(elenco.C)):
        os.makedirs(f'{out}/{n}', exist_ok=True)
        folha_completa(n).save(f'{out}/{n}/folha_completa.png')
        andando(n).save(f'{out}/{n}/andando.png')
        andando8(n).save(f'{out}/{n}/andando_8.png')
        cena(n).save(f'{out}/{n}/cena.png')
        print('ok', n, flush=True)

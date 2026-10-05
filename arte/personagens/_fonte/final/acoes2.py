"""acoes2.png: animacoes de detalhe (mesmo formato do acoes.png: quadros 64x64, pe em y=61, centro x=32).
Linhas 'lado' olham para a DIREITA (o jogo espelha para a esquerda)."""
import sys, os
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
import rig
from acoes import lado, frente, em_pe, camada, W, H, CHAO
from sprites8 import contorno
from final2 import cabeca

ACOES2 = [  # nome, vista, quadros, fps, repete
    ('respirar', 'baixo', 4, 4, True),
    ('piscar', 'baixo', 3, 10, False),
    ('olhar_lados', 'baixo', 6, 4, False),
    ('bocejar', 'baixo', 6, 6, False),
    ('sentar', 'lado', 4, 8, False),
    ('digitar', 'lado', 4, 10, True),
    ('levantar_cadeira', 'lado', 4, 8, False),
    ('pegar_objeto', 'lado', 6, 8, False),
    ('beber', 'lado', 6, 6, False),
    ('rir_alto', 'baixo', 4, 10, True),
    ('chorar_de_rir', 'baixo', 6, 10, True),
    ('bravo', 'baixo', 4, 8, True),
    ('envergonhado', 'baixo', 4, 4, True),
    ('andar_de_costas', 'lado', 8, 10, True),
    ('comemorar_lado', 'lado', 6, 8, True),
    ('rir_lado', 'lado', 4, 10, True),
    ('assustado_lado', 'lado', 4, 10, False),
]

CADEIRA, CADEIRA2 = (52, 56, 66), (34, 36, 44)


def cadeira():
    L = camada(); d = ImageDraw.Draw(L)
    d.rectangle([18, 52, 33, 54], fill=CADEIRA + (255,))          # assento
    d.rectangle([18, 36, 20, 52], fill=CADEIRA + (255,))          # encosto
    d.rectangle([25, 55, 26, 59], fill=CADEIRA2 + (255,))         # coluna
    d.rectangle([20, 60, 31, 60], fill=CADEIRA2 + (255,))         # base
    return contorno(L)


def com_cadeira(im):
    c = cadeira(); c.alpha_composite(im); return c


def objeto(im, tipo, pos):
    L = camada(); d = ImageDraw.Draw(L); x, y = int(round(pos[0])), int(round(pos[1]))
    if tipo == 'copo':
        d.rectangle([x, y - 3, x + 2, y + 1], fill=(236, 236, 240, 255)); d.line([(x, y - 3), (x + 2, y - 3)], fill=(110, 70, 40, 255))
    elif tipo == 'caixa':
        d.rectangle([x - 2, y - 3, x + 3, y + 1], fill=(170, 120, 70, 255)); d.line([(x - 2, y - 1), (x + 3, y - 1)], fill=(130, 88, 50, 255))
    im = im.copy(); im.alpha_composite(contorno(L)); return im


def sentado(**kw):
    P = dict(hip=(27, 52), inc=0, pa=(37, CHAO - 1), pb=(36, CHAO - 1), dobra_a=1, dobra_b=1, ma=(35, 49), mb=(33, 49))
    P.update(kw); return P


def andar64(nome, f):
    """quadro do andar (rig) colocado no quadro 64x64"""
    im = rig.lado(nome, 'andando', f, cabeca(nome, 'lado'))
    c = camada(); c.alpha_composite(im, (16, 16)); return c


def quadros(nome, acao):
    if acao == 'respirar':
        return [frente(nome, dict(resp=r, mE=(23, 44 - r), mD=(42, 44 - r))) for r in (0, 1, 1, 0)]
    if acao == 'piscar':
        return [frente(nome, dict()), frente(nome, dict(olhos='fechados')), frente(nome, dict())]
    if acao == 'olhar_lados':
        F = [dict(), dict(expr=('lado',)), dict(expr=('lado',), cab=(1, 0)), dict(), dict(expr=('esq',)), dict(expr=('esq',), cab=(-1, 0))]
        return [frente(nome, P) for P in F]
    if acao == 'bocejar':
        F = [dict(), dict(resp=1, mE=(22, 30), mD=(42, 30), boca='m', olhos='fechados'),
             dict(resp=1, mE=(24, 18), mD=(40, 18), boca='o', olhos='fechados', dy=-1),
             dict(resp=1, mE=(25, 16), mD=(39, 16), boca='o', olhos='fechados', dy=-1),
             dict(resp=1, mE=(22, 30), mD=(42, 30), boca='m', olhos='fechados'), dict()]
        return [frente(nome, P) for P in F]
    if acao in ('sentar', 'levantar_cadeira'):
        F = [em_pe(hip=(30, 46)), em_pe(hip=(29, 48), inc=14, pa=(36, CHAO - 1), pb=(31, CHAO - 1), ma=(38, 44), mb=(34, 44)),
             sentado(hip=(28, 51), inc=10, ma=(37, 48), mb=(35, 48)), sentado()]
        fr = [com_cadeira(lado(nome, P)) for P in F]
        return fr if acao == 'sentar' else fr[::-1]
    if acao == 'digitar':
        F = [sentado(inc=8, ma=(42, 45), mb=(40, 46), cot_a=-1, cot_b=-1, cab=(1, 1)),
             sentado(inc=8, ma=(43, 46), mb=(40, 45), cot_a=-1, cot_b=-1, cab=(1, 1)),
             sentado(inc=8, ma=(42, 45), mb=(41, 46), cot_a=-1, cot_b=-1, cab=(1, 1), olhos='fechados'),
             sentado(inc=8, ma=(43, 46), mb=(40, 45), cot_a=-1, cot_b=-1, cab=(1, 1))]
        return [com_cadeira(lado(nome, P)) for P in F]
    if acao == 'pegar_objeto':
        caixa = (44, 59)
        F = [(em_pe(), caixa), (em_pe(inc=20, hip=(31, 48), ma=(41, 50), mb=(38, 50)), caixa),
             (em_pe(inc=42, hip=(29, 51), pa=(36, CHAO - 1), pb=(28, CHAO - 1), ma=(43, 57), mb=(41, 57)), caixa),
             (em_pe(inc=42, hip=(29, 51), pa=(36, CHAO - 1), pb=(28, CHAO - 1), ma=(43, 56), mb=(41, 56)), 'mao'),
             (em_pe(inc=20, hip=(31, 48), ma=(41, 47), mb=(39, 47)), 'mao'), (em_pe(ma=(38, 42), mb=(36, 42), cot_a=1, cot_b=1), 'mao')]
        out = []
        for P, cx in F:
            im = lado(nome, P)
            out.append(objeto(im, 'caixa', cx if cx != 'mao' else (P['ma'][0] + 1, P['ma'][1] + 1)))
        return out
    if acao == 'beber':
        F = [em_pe(ma=(37, 44), cot_a=1), em_pe(ma=(38, 37), cot_a=1), em_pe(ma=(37, 31), cot_a=1, inc=-3, giro_cab=-10, olhos='fechados'),
             em_pe(ma=(36, 30), cot_a=1, inc=-4, giro_cab=-16, olhos='fechados'), em_pe(ma=(38, 37), cot_a=1, boca='m'), em_pe(ma=(37, 44), cot_a=1)]
        return [objeto(lado(nome, P), 'copo', (P['ma'][0] + 1, P['ma'][1] - 1)) for P in F]
    if acao == 'rir_alto':
        F = [dict(mE=(29, 42), mD=(35, 42), boca='o', expr=('riso', 'sorriso')),
             dict(mE=(29, 43), mD=(35, 43), boca='o', expr=('riso', 'sorriso'), dy=1, cab=(0, 1)),
             dict(mE=(29, 42), mD=(35, 42), boca='o', expr=('riso', 'sorriso'), cab=(1, 0)),
             dict(mE=(29, 43), mD=(35, 43), boca='o', expr=('riso', 'sorriso'), dy=1, cab=(-1, 1))]
        return [frente(nome, P) for P in F]
    if acao == 'chorar_de_rir':
        e = ('riso', 'sorriso', 'lagrima')
        F = [dict(mE=(29, 42), mD=(35, 42), boca='o', expr=e), dict(mE=(29, 43), mD=(35, 43), boca='o', expr=e, dy=1, cab=(0, 1)),
             dict(mE=(29, 42), mD=(38, 24), cotD=1, boca='o', expr=e), dict(mE=(29, 43), mD=(37, 23), cotD=1, boca='o', expr=e, dy=1),
             dict(mE=(29, 44), mD=(35, 44), boca='o', expr=e, dy=2, cab=(0, 2)), dict(mE=(29, 43), mD=(35, 43), boca='o', expr=e, dy=1)]
        return [frente(nome, P) for P in F]
    if acao == 'bravo':
        F = [dict(mE=(22, 44), mD=(42, 44), expr=('bravo',)), dict(mE=(22, 43), mD=(42, 43), expr=('bravo',), lift=(2, 0), boca='m'),
             dict(mE=(22, 44), mD=(42, 44), expr=('bravo',), dy=1), dict(mE=(22, 43), mD=(42, 43), expr=('bravo',), boca='o')]
        return [frente(nome, P) for P in F]
    if acao == 'envergonhado':
        e = ('vergonha', 'esq')
        F = [dict(mD=(38, 19), cotD=1, expr=e, cab=(-1, 0)), dict(mD=(37, 18), cotD=1, expr=e, cab=(-1, 0)),
             dict(mD=(38, 19), cotD=1, expr=e, cab=(-1, 1), olhos='fechados'), dict(mD=(37, 18), cotD=1, expr=e, cab=(-1, 0))]
        return [frente(nome, P) for P in F]
    if acao == 'andar_de_costas':
        return [andar64(nome, f) for f in (7, 6, 5, 4, 3, 2, 1, 0)]
    if acao == 'comemorar_lado':
        F = [em_pe(), em_pe(ma=(38, 26), mb=(34, 24), boca='m'), em_pe(ma=(39, 20), mb=(35, 19), dy=-4, lift_a=1, lift_b=1, boca='o', olhos='fechados'),
             em_pe(ma=(39, 19), mb=(35, 18), dy=-6, boca='o', olhos='fechados'), em_pe(ma=(38, 22), mb=(34, 21), dy=-3, boca='o'), em_pe(ma=(38, 26), mb=(34, 24), boca='m')]
        return [lado(nome, P) for P in F]
    if acao == 'rir_lado':
        F = [em_pe(inc=-6, ma=(36, 42), mb=(34, 42), boca='o', olhos='fechados'), em_pe(inc=-8, ma=(36, 43), mb=(34, 43), boca='o', olhos='fechados', dy=-1),
             em_pe(inc=6, ma=(37, 44), mb=(35, 44), boca='o', olhos='fechados'), em_pe(inc=-6, ma=(36, 42), mb=(34, 42), boca='o', olhos='fechados', dy=-1)]
        return [lado(nome, P) for P in F]
    if acao == 'assustado_lado':
        F = [em_pe(), em_pe(inc=-12, ma=(38, 24), mb=(34, 22), dy=-4, dx=-2, boca='o', lift_a=1, lift_b=1),
             em_pe(inc=-10, ma=(37, 26), mb=(33, 24), dx=-3, boca='o'), em_pe(inc=-5, ma=(35, 34), mb=(32, 33), dx=-3, boca='m')]
        return [lado(nome, P) for P in F]
    raise KeyError(acao)


def folha(nome):
    sh = Image.new('RGBA', (W * 8, H * len(ACOES2)), (0, 0, 0, 0))
    for r, (ac, _, nq, _, _) in enumerate(ACOES2):
        fr = quadros(nome, ac); assert len(fr) == nq, (ac, len(fr))
        for c, im in enumerate(fr): sh.paste(im, (c * W, r * H))
    return sh


if __name__ == '__main__':
    out = sys.argv[1]
    for n in sys.argv[2:]:
        os.makedirs(f'{out}/{n}', exist_ok=True); folha(n).save(f'{out}/{n}/acoes2.png'); print('ok', n, flush=True)

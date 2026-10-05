"""NPCs: alunos genericos (sem farda da Cairu) e Seu Mauro (limpeza, baixinho, grisalho, chapeu de palha).
Cabecas 14x15 geradas por formas (cabelo por estilo) no mesmo formato das do elenco; corpo pelo mesmo rig,
so trocando as cores da roupa. Uso: ELENCO=gemini python3 npc.py SAIDA"""
import os, sys, json, math
os.environ['ELENCO'] = 'gemini'
from PIL import Image, ImageDraw

GW = 14


def elipse(cx, cy, rx, ry):
    return lambda x, y: ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1


def cabeca_npc(estilo, chapeu=None, bigode=False, barba=False, menina=False):
    """devolve frente, costas, lado (linhas 0..12 preenchidas) + boca/olhos"""
    out = {}
    for vista in ('frente', 'costas', 'lado'):
        if vista == 'lado':
            cranio = elipse(6.2, 6.4, 5.4, 6.0)
            def dentro(x, y):
                if y >= 9 and x < 3 + (y - 8) * 1.4: return False       # mandibula sobe para tras
                return cranio(x, y) or (x == 12 and y == 7)
        else:
            cranio = elipse(7, 6.5, 5.7, 6.0)
            def dentro(x, y):
                if y >= 10: return cranio(x, y) and abs(x + .5 - 7) < 5.2 - (y - 10) * 1.1
                return cranio(x, y)
        g = [['.'] * GW for _ in range(15)]
        for y in range(13):
            for x in range(GW):
                if dentro(x, y): g[y][x] = 'S'
        # cabelo
        def cab(x, y):
            if vista == 'frente':
                base = {'curto': y <= 3 or (y <= 5 and (x <= 2 or x >= 11)),
                        'raspado': y <= 2,
                        'afro': y <= 4 or (y <= 6 and (x <= 2 or x >= 11)),
                        'longo': y <= 3 or (x <= 2 or x >= 11),
                        'rabo': y <= 3 or (y <= 5 and (x <= 2 or x >= 11)),
                        'coque': y <= 3 or (y <= 5 and (x <= 2 or x >= 11)),
                        'careca_lados': (5 <= y <= 7 and (x <= 1 or x >= 12))}[estilo]
            elif vista == 'costas':
                base = {'curto': y <= 8, 'raspado': y <= 7, 'afro': y <= 9, 'longo': True,
                        'rabo': y <= 8 or (5 <= x <= 8), 'coque': y <= 8, 'careca_lados': 5 <= y <= 8}[estilo]
            else:
                base = {'curto': y <= 3 or (x <= 5 and y <= 7),
                        'raspado': y <= 2 or (x <= 4 and y <= 6),
                        'afro': y <= 4 or (x <= 6 and y <= 8),
                        'longo': y <= 3 or x <= 6,
                        'rabo': y <= 3 or (x <= 5 and y <= 7),
                        'coque': y <= 3 or (x <= 5 and y <= 7),
                        'careca_lados': 5 <= y <= 8 and x <= 3}[estilo]
            return base
        for y in range(13):
            for x in range(GW):
                if g[y][x] == 'S' and cab(x, y): g[y][x] = 'H'
        # volume fora do cranio
        extra = []
        if estilo == 'afro':
            big = elipse(7 if vista != 'lado' else 5.8, 4.6, 7.0, 5.0)
            extra = [(x, y) for y in range(10) for x in range(GW) if big(x, y)]
        if estilo == 'longo':
            if vista == 'frente': extra = [(x, y) for y in range(3, 13) for x in (1, 12)]
            elif vista == 'costas': extra = [(x, y) for y in range(2, 13) for x in range(1, 13)]
            else: extra = [(x, y) for y in range(2, 13) for x in range(1, 6)]
        if estilo == 'rabo':
            if vista == 'costas': extra = [(x, y) for y in range(9, 13) for x in (6, 7)]
            if vista == 'lado': extra = [(x, y) for y in range(3, 9) for x in (0, 1) if y > 3 or x == 1]
        if estilo == 'coque':
            if vista != 'lado': extra = [(x, 0) for x in range(5, 9)] + [(x, 1) for x in range(5, 9)]
            else: extra = [(x, y) for y in (0, 1, 2) for x in (2, 3, 4)]
        for x, y in extra:
            if 0 <= x < GW and 0 <= y < 13 and (g[y][x] in '.S'):
                if g[y][x] == 'S' and vista == 'frente' and estilo == 'longo' and 2 < x < 11: continue
                g[y][x] = 'H'
        # chapeu / bone
        if chapeu:
            for y in range(0, 5):
                for x in range(GW):
                    if y <= 3 and g[y][x] in 'SH': g[y][x] = 'C'
            aba = {'frente': range(0, GW), 'costas': range(0, GW), 'lado': range(1, GW)}[vista] if chapeu == 'palha' \
                else {'frente': range(3, 11), 'costas': range(4, 10), 'lado': range(6, GW)}[vista]
            for x in aba: g[4][x] = 'c'
            if chapeu == 'palha':
                for x in range(3, 11): g[3][x] = 'C' if g[3][x] != '.' else 'C'
                for x in range(4, 10): g[1][x] = 'C' if g[1][x] in '.SH' else g[1][x]
                for x in range(4, 10):
                    if g[2][x] != '.': g[2][x] = 'c' if x in (4, 9) else 'C'
                for x in range(3, 11): g[3][x] = 'k'                  # fita
        # tracos
        if vista == 'frente':
            for x in (3, 4, 9, 10):
                if g[5][x] == 'S': g[5][x] = 'H'
            g[6][3], g[6][4], g[6][9], g[6][10] = 'W', 'E', 'E', 'W'
            g[7][7] = 's'
            for x, ch in zip(range(5, 9), 'mMMm'): g[9][x] = ch
            if bigode:
                for x in range(5, 9): g[8][x] = 'B'
            if barba:
                for y, xs in ((10, range(3, 11)), (11, range(4, 10)), (12, range(5, 9))):
                    for x in xs:
                        if g[y][x] == 'S': g[y][x] = 'B'
            if menina:
                g[6][2] = 'K' if g[6][2] == 'S' else g[6][2]; g[6][11] = 'K' if g[6][11] == 'S' else g[6][11]
        elif vista == 'lado':
            for x in (9, 10):
                if g[5][x] == 'S': g[5][x] = 'H'
            g[6][9], g[6][10] = 'E', 'W'
            g[9][10], g[9][11] = 'm', 'M'
            if g[7][5] == 'S': g[7][5] = 's'
            if bigode: g[8][10] = 'B'; g[8][11] = 'B'
            if barba:
                for y in (10, 11, 12):
                    for x in range(GW):
                        if g[y][x] == 'S': g[y][x] = 'B'
        # sombra na borda da pele e brilho no cabelo
        for y in range(13):
            xs = [x for x in range(GW) if g[y][x] != '.']
            for x in xs:
                if g[y][x] == 'S' and (x == xs[0] or x == xs[-1] or (y > 0 and g[y - 1][x] in 'HCc')): g[y][x] = 's'
                if g[y][x] == 'H' and y <= 2 and (x + y) % 3 == 0: g[y][x] = 'h'
        # contorno
        cheio = [[g[y][x] != '.' for x in range(GW)] for y in range(15)]
        for y in range(15):
            for x in range(GW):
                if not cheio[y][x] and any(0 <= y + dy < 15 and 0 <= x + dx < GW and cheio[y + dy][x + dx]
                                           for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))):
                    g[y][x] = 'K'
        out[vista] = [''.join(r) for r in g]
    out['boca'] = (9, 5, 8); out['olhos'] = (6,)
    return out


def tom(c, k): return tuple(int(max(0, min(255, v * k))) for v in c)


PELES = [(232, 186, 150), (214, 160, 120), (190, 132, 96), (160, 106, 74), (122, 78, 54), (96, 60, 42)]
CABELOS = {'preto': (26, 22, 24), 'castanho': (82, 52, 34), 'loiro': (206, 166, 92), 'ruivo': (160, 70, 36), 'cinza': (170, 170, 172)}

# nome, estilo, pele, cabelo, camisa, calca, tenis, menina, biotipo, extras
ALUNOS = [
    ('aluno1', 'curto', 2, 'preto', (200, 60, 60), (52, 66, 110), (40, 40, 46), False, (0, 0), {}),
    ('aluno2', 'afro', 4, 'preto', (240, 200, 70), (40, 40, 46), (230, 230, 236), False, (0, 0), {}),
    ('aluno3', 'raspado', 3, 'preto', (60, 150, 90), (120, 100, 76), (40, 40, 46), False, (1, 2), {}),
    ('aluno4', 'curto', 0, 'loiro', (230, 230, 236), (52, 66, 110), (180, 60, 60), False, (0, 0), {'barba': True}),
    ('aluno5', 'longo', 1, 'castanho', (220, 110, 160), (52, 66, 110), (230, 230, 236), True, (0, 0), {}),
    ('aluno6', 'rabo', 3, 'preto', (130, 90, 200), (40, 40, 46), (230, 230, 236), True, (0, 0), {}),
    ('aluno7', 'coque', 5, 'preto', (240, 150, 60), (60, 60, 70), (40, 40, 46), True, (0, 1), {}),
    ('aluno8', 'longo', 0, 'ruivo', (90, 170, 200), (110, 80, 60), (40, 40, 46), True, (0, 0), {}),
    ('aluno9', 'afro', 2, 'castanho', (50, 50, 56), (52, 66, 110), (230, 230, 236), True, (0, 0), {}),
    ('aluno10', 'curto', 4, 'preto', (150, 150, 156), (40, 40, 46), (200, 50, 50), False, (0, 0), {'bone': (40, 40, 46)}),
]


def corpo_cores(camisa, calca, tenis):
    return dict(T=camisa, t=tom(camisa, .74), U=tom(camisa, 1.18), W=camisa,
                CALCA=calca, CALCA_S=tom(calca, .72), CALCA_L=tom(calca, 1.25), TENIS=tenis)


def registra():
    """devolve dict nome -> (entrada elenco json, cores do corpo, biotipo)"""
    R = {}
    for nome, est, ip, cab, cam, calca, ten, menina, bio, ex in ALUNOS:
        h = cabeca_npc(est, chapeu='bone' if 'bone' in ex else None, barba=ex.get('barba', False), menina=menina)
        pele = PELES[ip]; H = CABELOS[cab]
        pal = dict(S=pele, s=tom(pele, .8), L=tom(pele, 1.1), H=H, h=tom(H, 1.4) if sum(H) < 200 else tom(H, 1.15),
                   B=tom(H, 1.1), b=tom(H, 1.3))
        if 'bone' in ex: pal.update(C=ex['bone'], c=tom(ex['bone'], .7), k=tom(ex['bone'], .5))
        R[nome] = (dict(pal=pal, **h), corpo_cores(cam, calca, ten), bio)
    # Seu Mauro
    h = cabeca_npc('careca_lados', bigode=True)           # careca em cima, cabelo curto grisalho nos lados (foto)
    pele = (132, 86, 66)
    pal = dict(S=pele, s=tom(pele, .8), L=(160, 112, 92), H=(96, 90, 88), h=(130, 124, 120), B=(150, 144, 138), b=(120, 114, 108),
               C=(224, 194, 112), c=(182, 150, 80), k=(120, 60, 40))
    R['mauro'] = (dict(pal=pal, **h), dict(T=(84, 122, 116), t=(60, 92, 88), U=(110, 150, 142), W=(84, 122, 116),
                  CALCA=(66, 96, 92), CALCA_S=(48, 70, 68), CALCA_L=(86, 120, 116), TENIS=(50, 34, 26)), (0, 1))
    return R


def json_npc(R):
    J = {}
    for n, (d, _, _) in R.items():
        dd = dict(d); dd['pal'] = {k: list(v) for k, v in d['pal'].items()}; J[n] = dd
    json.dump(J, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'elenco_npc.json'), 'w'), indent=1)


def veste(cores, bio, nome):
    import rig, acoes, final2, acoes2, final, retratos3
    retratos3.CAIRU.update(T=cores['T'], t=cores['t'], U=cores['U'], W=cores['W'])
    for m in (rig, acoes, final2, acoes2, final):
        for k, v in (('T', cores['T']), ('t', cores['t']), ('U', cores['U']), ('LOGO', cores['W']),
                     ('CALCA', cores['CALCA']), ('CALCA_S', cores['CALCA_S']), ('CALCA_L', cores['CALCA_L']), ('TENIS', cores['TENIS'])):
            if hasattr(m, k): setattr(m, k, v)
    rig.CORPO[nome] = bio


def baixinho(im, fw, fh, tira=4):
    """Seu Mauro mais baixo: tira linhas do tronco e das pernas em cada quadro (pe continua no chao)"""
    a = im.copy(); out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    for y0 in range(0, im.height, fh):
        for x0 in range(0, im.width, fw):
            q = a.crop((x0, y0, x0 + fw, y0 + fh)); bb = q.getbbox()
            if not bb: continue
            top, bot = bb[1], bb[3]
            if bot - top < 30: out.paste(q, (x0, y0)); continue
            h = bot - top
            corta = sorted({top + int(h * .42), top + int(h * .5), top + int(h * .7), top + int(h * .78)})[:tira]
            linhas = [y for y in range(fh) if y not in corta]
            nq = Image.new('RGBA', (fw, fh), (0, 0, 0, 0))
            # empilha de baixo para cima mantendo o chao
            dst = fh - 1
            for y in reversed(linhas):
                nq.paste(q.crop((0, y, fw, y + 1)), (0, dst)); dst -= 1
            out.paste(nq, (x0, y0))
    return out


MAURO_EXTRAS = [('varrendo', 'lado', 6, 8, True), ('celular', 'baixo', 6, 4, True), ('parado_vassoura', 'lado', 4, 3, True),
                ('tocando_violao', 'lado', 6, 6, True), ('chupando_cana', 'lado', 6, 5, True)]


def mauro_extras():
    from acoes import lado, frente, em_pe, camada, W, H, CHAO
    from sprites8 import contorno
    CABO, PALHA, PALHA2 = (150, 100, 56), (214, 184, 96), (170, 140, 70)

    def vassoura(im, mao, base):
        L = camada(); d = ImageDraw.Draw(L)
        d.line([mao, (base[0], base[1] - 4)], fill=CABO + (255,), width=1)
        d.polygon([(base[0] - 3, base[1]), (base[0] + 3, base[1]), (base[0] + 2, base[1] - 4), (base[0] - 2, base[1] - 4)], fill=PALHA + (255,))
        d.line([(base[0] - 3, base[1]), (base[0] + 3, base[1])], fill=PALHA2 + (255,))
        o = contorno(L); o.alpha_composite(im); return o

    def celular(im, pos):
        L = camada(); d = ImageDraw.Draw(L); x, y = pos
        d.rectangle([x, y, x + 2, y + 3], fill=(30, 30, 38, 255)); d.point((x + 1, y + 1), fill=(120, 200, 255, 255))
        im = im.copy(); im.alpha_composite(contorno(L)); return im
    sh = Image.new('RGBA', (W * 8, H * len(MAURO_EXTRAS)), (0, 0, 0, 0))
    # varrendo: vassoura vai e vem na frente do corpo
    xs = [40, 44, 47, 44, 40, 37]
    for i, bx in enumerate(xs):
        P = em_pe(inc=10, ma=(bx - 4, 44), mb=(bx - 7, 38), cot_a=-1, cot_b=-1)
        im = lado('mauro', P); sh.paste(vassoura(im, (bx - 8, 34), (bx, CHAO)), (i * W, 0))
    # celular: olhando o celular e rindo sozinho / envergonhado
    E = [dict(), dict(expr=('sorriso',)), dict(expr=('sorriso',), boca='m'), dict(expr=('vergonha',)),
         dict(expr=('riso', 'sorriso'), boca='o'), dict(expr=('vergonha', 'sorriso'))]
    for i, e in enumerate(E):
        P = dict(mE=(30, 40), mD=(34, 40), cotE=1, cotD=1); P.update(e)
        sh.paste(celular(frente('mauro', P), (31, 36)), (i * W, H))
    # parado apoiado na vassoura
    for i, r in enumerate((0, 1, 1, 0)):
        P = em_pe(ma=(38, 38 + r), mb=(36, 40 + r), cot_a=1)
        sh.paste(vassoura(lado('mauro', P), (39, 30), (40, CHAO)), (i * W, 2 * H))
    # tocando violao sentado num banquinho
    from acoes2 import sentado
    MAD, MAD2, CORPO_V, CORPO_V2, BRACO_V = (140, 96, 56), (104, 70, 40), (196, 132, 66), (150, 96, 46), (92, 58, 32)
    pal = elenco.C['mauro']['pal']

    def banquinho():
        L = camada(); d = ImageDraw.Draw(L)
        d.rectangle([19, 52, 33, 54], fill=MAD + (255,)); d.line([(19, 54), (33, 54)], fill=MAD2 + (255,))
        for x in (20, 31): d.rectangle([x, 55, x + 1, 60], fill=MAD2 + (255,))
        return contorno(L)

    def violao(im, strum, traste, nota):
        L = camada(); d = ImageDraw.Draw(L)
        d.line([(40, 47), (49, 42)], fill=BRACO_V + (255,), width=2)              # braco
        d.rectangle([49, 39, 51, 42], fill=MAD2 + (255,))                         # cabeca do violao
        d.ellipse([29, 45, 37, 54], fill=CORPO_V + (255,)); d.ellipse([34, 44, 41, 51], fill=CORPO_V + (255,))
        d.arc([29, 45, 37, 54], 90, 200, fill=CORPO_V2 + (255,))
        o = im.copy(); o.alpha_composite(contorno(L)); d = ImageDraw.Draw(o)
        d.rectangle([35, 48, 36, 49], fill=(40, 24, 14, 255))                     # boca do violao
        for (x, y) in (strum, traste):                                            # maos por cima
            d.rectangle([x, y, x + 1, y + 1], fill=pal['S'] + (255,)); d.point((x, y + 1), fill=pal['s'] + (255,))
        if nota:                                                                  # notinha musical
            x, y = nota; d.line([(x + 2, y), (x + 2, y + 4)], fill=(250, 250, 250, 255)); d.rectangle([x, y + 3, x + 1, y + 4], fill=(250, 250, 250, 255))
            d.point((x + 3, y), fill=(250, 250, 250, 255))
        return o
    ST = [(37, 49), (37, 51), (38, 49), (37, 51), (37, 49), (38, 51)]
    TR = [(45, 43), (45, 43), (46, 42), (46, 42), (45, 43), (45, 43)]
    NT = [None, (46, 22), (48, 18), None, (44, 24), (46, 20)]
    for i in range(6):
        P = sentado(ma=ST[i], mb=TR[i], cot_a=-1, cot_b=-1, inc=4, cab=(0, i % 2), olhos='fechados' if i in (2, 3) else None,
                    expr=('sorriso',), boca='o' if i in (1, 4) else None)
        P = {k: v for k, v in P.items() if v is not None}
        b = banquinho(); b.alpha_composite(lado('mauro', P))
        sh.paste(violao(b, ST[i], TR[i], NT[i]), (i * W, 3 * H))
    # chupando cana: segura a cana na boca e mastiga
    CANA, CANA2, NO = (196, 200, 92), (150, 160, 60), (110, 120, 40)

    def cana(im, topo, mao):
        L = camada(); d = ImageDraw.Draw(L)
        bx, by = mao[0] - 1, mao[1] + 9
        d.line([topo, (bx, by)], fill=CANA + (255,), width=2)
        for k in (0.3, 0.62, 0.9):
            x = round(topo[0] + (bx - topo[0]) * k); y = round(topo[1] + (by - topo[1]) * k)
            d.line([(x - 1, y), (x + 1, y)], fill=NO + (255,))
        d.point(topo, fill=(236, 230, 170, 255))
        o = contorno(L); o2 = im.copy(); o2.alpha_composite(o); d = ImageDraw.Draw(o2)
        d.rectangle([mao[0], mao[1], mao[0] + 1, mao[1] + 1], fill=pal['S'] + (255,))
        return o2
    C = [dict(boca='m'), dict(), dict(boca='m', cab=(0, 1)), dict(), dict(boca='m', olhos='fechados', expr=('sorriso',)), dict(expr=('sorriso',))]
    for i, e in enumerate(C):
        P = em_pe(ma=(39, 37), cot_a=1, mb=(31, 46)); P.update(e)
        dy = e.get('cab', (0, 0))[1]
        sh.paste(cana(lado('mauro', P), (38, 27 + dy), (39, 37)), (i * W, 4 * H))
    return sh


if __name__ == '__main__':
    out = sys.argv[1]
    R = registra(); json_npc(R)
    import elenco
    elenco.carrega_npc()
    import final2, acoes, acoes2
    so = sys.argv[2:] or list(R)
    for n in so:
        _, cores, bio = R[n]
        veste(cores, bio, n)
        pasta = f'{out}/mauro' if n == 'mauro' else f'{out}/alunos/{n}'
        os.makedirs(pasta, exist_ok=True)
        folhas = {'andando.png': (final2.andando(n), 44, 60), 'andando_8.png': (final2.andando8(n), 44, 60),
                  'cena.png': (final2.cena(n), 100, 140), 'folha_completa.png': (final2.folha_completa(n), 32, 48),
                  'acoes.png': (acoes.folha(n), 64, 64), 'acoes2.png': (acoes2.folha(n), 64, 64)}
        for arq, (im, fw, fh) in folhas.items():
            if n == 'mauro' and arq != 'folha_completa.png': im = baixinho(im, fw, fh)
            im.save(f'{pasta}/{arq}')
        if n == 'mauro': baixinho(mauro_extras(), 64, 64).save(f'{pasta}/extras.png')
        print('ok', n, flush=True)


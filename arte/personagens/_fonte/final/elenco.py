"""Cabecas 14x15 de cada personagem (frente, costas, lado direito), desenhadas a mao a partir das fotos."""
OUT = (22, 18, 24)
BASE = {'K': OUT, 'E': (26, 18, 18), 'W': (226, 218, 208), 'M': (168, 92, 88), 'm': (82, 34, 38), 'T': (236, 230, 222), 'G': (230, 196, 90)}

def pal(S, s, L, H, h, B=None, b=None):
    p = dict(BASE); p.update(S=S, s=s, L=L, H=H, h=h, B=B or H, b=b or h); return p

C = {}
# ---------------- Nicão: cabelo curto escuro com volume, barba cheia
C['nicao'] = dict(pal=pal((208, 150, 110), (170, 112, 82), (230, 182, 142), (40, 32, 30), (74, 58, 50), (54, 40, 36), (92, 68, 56)),
 frente=["....KKKKKK....",
         "...KHhHHhHK...",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         "..KHSSLLSSHK..",
         ".KKSHHSSHHSKK.",
         ".KSSEWSsWESSK.",
         ".KsSSSSsSSSsK.",
         "..KSSSssSSSK..",
         "..KBSBBBBSBK..",
         "..KBBmMMmBBK..",
         "..KBBBBBBBBK..",
         "...KBBbbBBK...",
         "....KBBBBK....",
         ".....KKKK....."],
 costas=["....KKKKKK....",
         "...KHhHHhHK...",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         ".KKHHHHHHHHKK.",
         ".KSHHHHHHHHSK.",
         ".KsHHHHHHHHsK.",
         "..KHHHHHHHHK..",
         "..KhHHHHHHhK..",
         "..KsSSSSSSsK..",
         "...KsSSSSsK...",
         "....KsSSsK....",
         ".....KKKK.....",
         ".............."],
 lado=  ["....KKKKK.....",
         "...KHhHHhKK...",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         "..KHHHHHSLSK..",
         "..KHHHHHHHSK..",
         "..KHSSHSSEWK..",
         "..KHSsHSSSSKK.",
         "..KHHSSSSSSSK.",
         "..KHBBSSSSsK..",
         "...KBBBBBmMK..",
         "...KBBBBBBBK..",
         "....KBBbbBK...",
         ".....KBBBK....",
         "......KKK....."],
 boca=(10, 5, 8), olhos=(6,), alt=1.0)

# ---------------- Lucas: cachos castanhos volumosos, bigode fino e cavanhaque ralo
C['lucas'] = dict(pal=pal((214, 158, 120), (176, 118, 88), (236, 192, 154), (86, 54, 36), (132, 86, 52), (100, 66, 46), (140, 98, 70)),
 frente=["..KKKhKKhKKK..",
         ".KHhHHhHHhHHK.",
         "KHHHhHHHHhHHhK",
         "KhHHHHhHHHHHHK",
         "KHHhSSLLSShHhK",
         "KHHSHHSSHHSHHK",
         "KHSSEWSsWESSHK",
         ".KsSSSSsSSSsK.",
         "..KSSSssSSSK..",
         "..KSSBBBBSSK..",
         "..KSSmMMmSSK..",
         "..KsSSSSSSsK..",
         "...KsSbbSsK...",
         "....KSBBSK....",
         ".....KKKK....."],
 costas=["..KKKhKKhKKK..",
         ".KHhHHhHHhHHK.",
         "KHHHhHHHHhHHhK",
         "KhHHHHhHHHHHHK",
         "KHHhHHHHhHHhHK",
         "KHHHHhHHHHHHHK",
         "KHhHHHHhHHHhHK",
         ".KHHhHHHHhHHK.",
         "..KHHHHHHHHK..",
         "..KhHHhHHhHK..",
         "..KsSSSSSSsK..",
         "...KsSSSSsK...",
         "....KsSSsK....",
         ".....KKKK.....",
         ".............."],
 lado=  ["..KKKhKKhK....",
         ".KHhHHhHHhKK..",
         "KHHHhHHHHHHhK.",
         "KhHHHHhHHhHHK.",
         "KHHhHHHHhSLSK.",
         "KHHHhHHHHHHSK.",
         "KHhHSSHSSSEWK.",
         ".KHHSsHSSSSSKK",
         "..KHHSSSSSSSSK",
         "..KHSSSSSBBSK.",
         "...KSSSSSmMSK.",
         "...KsSSSSSSSK.",
         "....KsSSSbbK..",
         ".....KSSSBK...",
         "......KKKK...."],
 boca=(10, 5, 8), olhos=(6,), alt=1.0)

# ---------------- João: careca em cima, laterais raspadas, bigode e cavanhaque escuros
C['joao'] = dict(pal=pal((180, 118, 82), (142, 88, 60), (214, 160, 120), (40, 32, 30), (70, 56, 48), (36, 28, 26), (66, 52, 44)),
 frente=["....KKKKKK....",
         "...KSLLLLSK...",
         "..KSSLLSSSSK..",
         "..KSSSSSSSSK..",
         "..KhSSSSSShK..",
         ".KKSHHSSHHSKK.",
         ".KShEWSsWEhSK.",
         ".KsSSSSsSSSsK.",
         "..KSSSssSSSK..",
         "..KSBBBBBBSK..",
         "..KSBmMMmBSK..",
         "..KsSSBBSSsK..",
         "...KsSBBSsK...",
         "....KSBBSK....",
         ".....KKKK....."],
 costas=["....KKKKKK....",
         "...KSLLLLSK...",
         "..KSSLLSSSSK..",
         "..KSSSSSSSSK..",
         "..KhSSSSSShK..",
         ".KKhhhhhhhhKK.",
         ".KShHHHHHHhSK.",
         ".KshHHHHHHhsK.",
         "..KHHHHHHHHK..",
         "..KhHHHHHHhK..",
         "..KsSSSSSSsK..",
         "...KsSSSSsK...",
         "....KsSSsK....",
         ".....KKKK.....",
         ".............."],
 lado=  ["....KKKKK.....",
         "...KSLLLLKK...",
         "..KSSLLSSSSK..",
         "..KSSSSSSSSK..",
         "..KhhSSSSLSK..",
         "..KhhhSSHHSK..",
         "..KhSShSSEWK..",
         "..KhSshSSSSKK.",
         "..KhhSSSSSSSK.",
         "..KhSSSSBBBK..",
         "...KSSSSBmMK..",
         "...KsSSSBBBK..",
         "....KsSSBBK...",
         ".....KSSBK....",
         "......KKK....."],
 boca=(10, 5, 8), olhos=(6,), alt=1.0)

# ---------------- Matheus: pele escura, cabelo bem baixo, rosto largo, bigode ralo
C['matheus'] = dict(pal=pal((128, 80, 58), (98, 58, 42), (160, 108, 80), (22, 18, 20), (50, 42, 42), (40, 28, 26), (70, 52, 46)),
 frente=["...KKKKKKKK...",
         "..KHhHHHHhHK..",
         ".KHHHHHHHHHHK.",
         ".KHHHHHHHHHHK.",
         ".KHSSLLLLSSHK.",
         "KKSSHHSSHHSSKK",
         "KSSsEWSSWEsSSK",
         "KsSSSSSsSSSSsK",
         ".KSSSsssSSSSK.",
         ".KSSSBBBBSSSK.",
         ".KSSSmMMmSSSK.",
         ".KsSSSMMSSSsK.",
         "..KsSSSSSSsK..",
         "...KKsSSsKK...",
         ".....KKKK....."],
 costas=["...KKKKKKKK...",
         "..KHhHHHHhHK..",
         ".KHHHHHHHHHHK.",
         ".KHHHHHHHHHHK.",
         ".KHHHHHHHHHHK.",
         "KKHHHHHHHHHHKK",
         "KSHHHHHHHHHHSK",
         "KsHHHHHHHHHHsK",
         ".KhHHHHHHHHhK.",
         ".KsSSSSSSSSsK.",
         ".KsSSSSSSSSsK.",
         "..KsSSSSSSsK..",
         "...KsSSSSsK...",
         "....KKKKKK....",
         ".............."],
 lado=  ["....KKKKKK....",
         "...KHhHHHHKK..",
         "..KHHHHHHHHHK.",
         "..KHHHHHHHHHK.",
         "..KHHHHHHSLSK.",
         "..KHHHHHHHHSK.",
         "..KHSSHSSSEWK.",
         "..KHSsHSSSSSKK",
         "..KhSSSSSSSSSK",
         "..KsSSSSSBBSK.",
         "..KsSSSSSmMSK.",
         "...KsSSSSSSSK.",
         "....KsSSSSSK..",
         ".....KKsSSK...",
         ".......KKK...."],
 boca=(10, 5, 8), olhos=(6,), alt=1.0)

# ---------------- Beto: mais velho, cabelo preto penteado com volume, bigode fino
C['beto'] = dict(pal=pal((188, 130, 94), (150, 96, 68), (218, 168, 130), (20, 22, 30), (52, 56, 70), (40, 30, 30), (70, 56, 50)),
 frente=["...KKKKKKKK...",
         "..KHhhHHHHHK..",
         ".KHHHHhHHHHHK.",
         ".KHHHHHHHHHHK.",
         ".KHHSSLLSSSHK.",
         "KKHSHHSSHHSHKK",
         "KSSsEWSsWEsSSK",
         ".KsSSSSsSSSsK.",
         "..KSsSssSsSK..",
         "..KSSBBBBSSK..",
         "..KSSmMMmSSK..",
         "..KsSSSSSSsK..",
         "...KsSSSSsK...",
         "....KsSSsK....",
         ".....KKKK....."],
 costas=["...KKKKKKKK...",
         "..KHhhHHHHHK..",
         ".KHHHHhHHHHHK.",
         ".KHHHHHHHHHHK.",
         ".KHHHHHHHHHHK.",
         "KKHHHHHHHHHHKK",
         "KSHHHHHHHHHHSK",
         ".KsHHHHHHHHsK.",
         "..KHHHHHHHHK..",
         "..KhHHHHHHhK..",
         "..KsSSSSSSsK..",
         "...KsSSSSsK...",
         "....KsSSsK....",
         ".....KKKK.....",
         ".............."],
 lado=  ["...KKKKKKK....",
         "..KHhhHHHHKK..",
         ".KHHHHhHHHHHK.",
         ".KHHHHHHHHHHK.",
         ".KHHHHHHHSLSK.",
         "..KHHHHHHHHSK.",
         "..KHSSHSSSEWK.",
         "..KHSsHSSSSSKK",
         "..KHSSSSSSSSSK",
         "..KHSSSSSBBSK.",
         "...KSSSSSmMSK.",
         "...KsSSSSSSSK.",
         "....KsSSSSSK..",
         ".....KsSSSK...",
         "......KKKK...."],
 boca=(10, 5, 8), olhos=(6,), alt=1.0)

# ---------------- Lukako: pele escura, cabelo alto e curto, rosto redondo e largo, nariz largo
C['lukako'] = dict(pal=pal((122, 76, 54), (92, 54, 40), (154, 104, 78), (18, 16, 18), (46, 40, 40), (34, 26, 24), (60, 46, 40)),
 frente=["..KKKKKKKKKK..",
         ".KHhHHHhHHhHK.",
         ".KHHHHHHHHHHK.",
         ".KHHHHHHHHHHK.",
         ".KHSSSLLSSSHK.",
         "KKSSHHSSHHSSKK",
         "KSSsEWSSWEsSSK",
         "KsSSSSSsSSSSsK",
         ".KSSssssssSSK.",
         ".KSSSBBBBSSSK.",
         ".KSSSmMMmSSSK.",
         ".KsSSSMMSSSsK.",
         "..KsSSSSSSsK..",
         "...KKsSSsKK...",
         ".....KKKK....."],
 costas=["..KKKKKKKKKK..",
         ".KHhHHHhHHhHK.",
         ".KHHHHHHHHHHK.",
         ".KHHHHHHHHHHK.",
         ".KHHHHHHHHHHK.",
         "KKHHHHHHHHHHKK",
         "KSHHHHHHHHHHSK",
         "KsHHHHHHHHHHsK",
         ".KhHHHHHHHHhK.",
         ".KsSSSSSSSSsK.",
         ".KsSSSSSSSSsK.",
         "..KsSSSSSSsK..",
         "...KsSSSSsK...",
         "....KKKKKK....",
         ".............."],
 lado=  ["...KKKKKKK....",
         "..KHhHHHhHKK..",
         "..KHHHHHHHHHK.",
         "..KHHHHHHHHHK.",
         "..KHHHHHHSLSK.",
         "..KHHHHHHHHSK.",
         "..KHSSHSSSEWK.",
         "..KHSsHSSSSSKK",
         "..KhSSSSSSSSsK",
         "..KsSSSSSBBSK.",
         "..KsSSSSSmMSK.",
         "...KsSSSSSSSK.",
         "....KsSSSSSK..",
         ".....KKsSSK...",
         ".......KKK...."],
 boca=(10, 5, 8), olhos=(6,), alt=1.0)

# ---------------- Fábio: rosto fino, cabelo curto preto, orelhas de abano, bigode e cavanhaque finos
C['fabio'] = dict(pal=pal((134, 88, 62), (102, 64, 46), (166, 116, 86), (20, 18, 20), (48, 42, 42), (30, 24, 24), (56, 44, 40)),
 frente=["....KKKKKK....",
         "...KHhHHhHK...",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         "..KHSSLLSSHK..",
         "KKKSHHSSHHSKKK",
         "KSKSEWSsWESKSK",
         "KsKsSSSsSSsKsK",
         ".K.KSSssSSK.K.",
         "...KSBBBBSK...",
         "...KSmMMmSK...",
         "...KsSSSSsK...",
         "....KsBBsK....",
         ".....KBBK.....",
         "......KK......"],
 costas=["....KKKKKK....",
         "...KHhHHhHK...",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         "KKKHHHHHHHHKKK",
         "KSKHHHHHHHHKSK",
         "KsKHHHHHHHHKsK",
         ".K.KhHHHHhK.K.",
         "...KsSSSSsK...",
         "...KsSSSSsK...",
         "....KsSSsK....",
         ".....KSSK.....",
         "......KK......",
         ".............."],
 lado=  ["....KKKKK.....",
         "...KHhHHhKK...",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         "..KHHHHHHSLK..",
         "..KHHHHHHHSK..",
         ".KSSKHSSSEWK..",
         ".KSsKHSSSSSKK.",
         "..KKHSSSSSSSK.",
         "...KsSSSSBBK..",
         "...KsSSSSmMK..",
         "....KsSSSSSK..",
         ".....KsSBBK...",
         "......KSBK....",
         ".......KK....."],
 boca=(10, 6, 7), olhos=(6,), alt=1.0)

# ---------------- Breno: cabelo castanho curto degrade, rosto redondo, bigode fino e cavanhaque
C['breno'] = dict(pal=pal((222, 166, 130), (184, 126, 96), (240, 198, 164), (66, 46, 32), (104, 76, 54), (70, 48, 36), (110, 80, 60)),
 frente=["....KKKKKK....",
         "...KHhHHhHK...",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         "..KhSSLLSShK..",
         ".KKSHHSSHHSKK.",
         ".KSSEWSsWESSK.",
         ".KsSSSSsSSSsK.",
         "..KSSSssSSSK..",
         "..KSSBBBBSSK..",
         "..KSSmMMmSSK..",
         "..KsSSSSSSsK..",
         "...KsSBBSsK...",
         "....KSBBSK....",
         ".....KKKK....."],
 costas=["....KKKKKK....",
         "...KHhHHhHK...",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         ".KKHHHHHHHHKK.",
         ".KShHHHHHHhSK.",
         ".KshHHHHHHhsK.",
         "..KhhhhhhhhK..",
         "..KsSSSSSSsK..",
         "..KsSSSSSSsK..",
         "...KsSSSSsK...",
         "....KsSSsK....",
         ".....KKKK.....",
         ".............."],
 lado=  ["....KKKKK.....",
         "...KHhHHhKK...",
         "..KHHHHHHHHK..",
         "..KHHHHHHHHK..",
         "..KhHHHHHSLK..",
         "..KhhHHHHHSK..",
         "..KhSShSSEWK..",
         "..KhSshSSSSKK.",
         "..KhhSSSSSSSK.",
         "..KhSSSSSBBK..",
         "...KSSSSSmMK..",
         "...KsSSSSSSK..",
         "....KsSSBBK...",
         ".....KSSBK....",
         "......KKK....."],
 boca=(10, 5, 8), olhos=(6,), alt=1.0)

for n, c in C.items():
    for v in ('frente', 'costas', 'lado'):
        assert len(c[v]) == 15, (n, v, len(c[v]))
        for i, r in enumerate(c[v]): assert len(r) == 14, (n, v, i, r, len(r))


# tom de pele medido na foto (rostos7.py grava pele.json): bonecos com a mesma cor do rosto de dialogo
try:
    import json as _j, os as _o
    _P = _j.load(open(_o.path.join(_o.path.dirname(_o.path.abspath(__file__)), 'pele.json')))
    for _n, _c in _P.items():
        if _n in C:
            _b = tuple(int(v) for v in _c)
            C[_n]['pal']['S'] = _b
            C[_n]['pal']['s'] = tuple(int(v * .8) for v in _b)
            C[_n]['pal']['L'] = tuple(min(255, int(v * 1.12 + 6)) for v in _b)
except FileNotFoundError:
    pass


# cabecas refeitas a partir dos retratos do Gemini (cabecas_gemini.py): ELENCO=gemini
def _carrega(_G):
    for _n, _d in _G.items():
        _p = dict(BASE); _p.update({k: tuple(v) for k, v in _d['pal'].items()})
        _desl = {}
        _vs = {}
        for _v in ('frente', 'costas', 'lado'):
            _r = [list(x) for x in _d[_v]]
            _ult = max(y for y in range(15) if any(ch not in 'K.' for ch in _r[y]))
            _r = _r[:_ult + 1]
            _k = 12 - _ult; _desl[_v] = _k                      # ultima linha de pele/barba na 12, queixo na 13
            _r = [['.'] * 14 for _ in range(max(0, _k))] + _r[max(0, -_k):]
            _r = (_r + [['.'] * 14 for _ in range(15)])[:15]
            _xs = [x for x in range(14) if _r[12][x] not in 'K.']
            _c = (min(_xs) + max(_xs)) / 2 + (-.5 if _v == 'lado' else 0)
            _a, _b = int(round(_c - 1.5)), int(round(_c + 1.5))
            _r[13] = ['.'] * 14; _r[14] = ['.'] * 14
            for x in range(min(_xs), max(_xs) + 1): _r[13][x] = 'K'        # contorno do queixo
            for y in (13, 14):                                              # pescoco ate a gola
                for x in range(_a, _b + 1): _r[y][x] = 's' if (y == 13 or x in (_a, _b)) else 'S'
                if _r[y][_a - 1] == '.': _r[y][_a - 1] = 'K'
                if _r[y][_b + 1] == '.': _r[y][_b + 1] = 'K'
            if _v == 'lado':   # perfil: pescoco sai de baixo da mandibula, atras do queixo, alinhado ao tronco
                for y in (13, 14): _r[y] = ['.'] * 14
                _m = [x for x in range(14) if _r[8][x] not in 'K.']
                _a = int(round((min(_m) + max(_m)) / 2 - 2.5)); _b = _a + 3
                _cheio = lambda y, x: _r[y][x] not in 'K.'
                for x in range(_a, _b + 1):
                    _ys = [y for y in range(13) if _cheio(y, x)]
                    _y0 = (max(_ys) + 1) if _ys else 10
                    for y in range(_y0, 15):
                        _r[y][x] = 's' if (x == _a or y == _y0) else 'S'
                # contorno em volta do pescoco e embaixo do queixo
                _novo = [r[:] for r in _r]
                for y in range(9, 15):
                    for x in range(14):
                        if _r[y][x] == '.' and any(0 <= y + dy < 15 and 0 <= x + dx < 14 and _cheio(y + dy, x + dx)
                                                   for dy, dx in ((0, 1), (0, -1), (-1, 0))):
                            _novo[y][x] = 'K'
                _r = _novo
            _vs[_v] = [''.join(x) for x in _r]
        C[_n] = dict(pal=_p, frente=_vs['frente'], costas=_vs['costas'], lado=_vs['lado'], gemini=True,
                     boca=(_d['boca'][0] + _desl['frente'], _d['boca'][1], _d['boca'][2]), olhos=(_d['olhos'][0] + _desl['frente'],), alt=_d.get('alt', 1.0))


def carrega_npc():
    """alunos e Seu Mauro (npc.py grava elenco_npc.json)"""
    _carrega(_j.load(open(_o.path.join(_o.path.dirname(_o.path.abspath(__file__)), 'elenco_npc.json'))))


if _o.environ.get('ELENCO') == 'gemini':
    _G = _j.load(open(_o.path.join(_o.path.dirname(_o.path.abspath(__file__)), 'elenco_gemini.json')))
    _carrega(_G)
    if 'lucas' in _G:  # brincos
        _p = C['lucas']['pal']; _p['G'] = (214, 214, 222)
        for _v in ('frente', 'lado'):
            _oy = C['lucas']['olhos'][0] + 1 + (0 if _v == 'frente' else 0)
            _r = [list(x) for x in C['lucas'][_v]]
            _xs = [x for x in range(14) if _r[_oy][x] not in 'K.']
            if _xs:
                if _v == 'frente': _r[_oy][_xs[0]] = 'G'; _r[_oy][_xs[-1]] = 'G'
                else: _r[_oy][_xs[0] + 2] = 'G'
            C['lucas'][_v] = [''.join(x) for x in _r]
    if 'lucas' in _G:  # colar prateado na base do pescoco (igual ao do retrato)
        for _v in ('frente', 'lado', 'costas'):
            _r = [list(x) for x in C['lucas'][_v]]
            for x in range(14):
                if _r[14][x] in 'sS': _r[14][x] = 'G'
            if _v == 'frente':
                _xs = [x for x in range(14) if _r[14][x] == 'G']
                if _xs: _r[14][_xs[0]] = 'G'
            C['lucas'][_v] = [''.join(x) for x in _r]

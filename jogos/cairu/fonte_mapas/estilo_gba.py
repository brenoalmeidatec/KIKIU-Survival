"""Peças comuns do estilo GBA (o mesmo da Sala 204) pra montar os outros mapas.

Parede de frente em 3/4 com pintura, meia-cana, lambri e rodapé; piso com volume;
paredes dos lados escuras; portas com folha que abre; janelas, relógio, ar-condicionado
e murais; sombras de contato pontilhadas; e os móveis antigos passados pra paleta única
(paleta.py, Endesga 32) com contorno escuro por fora.

Cada mapa tem seu gerador (recepcao_gba.py, corredor_gba.py, ...). Todos usam isto.
A escala continua a de sempre: 1 m = 26 px, chão começa em y = CHAO.
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFont

from paleta import P, contornar, faixa_sombra, mais_perto, quantizar, rgb, sombrear

AQUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(AQUI, '..', 'projeto', 'capitulos', 'mapas')
FONTE = os.path.join(AQUI, '..', 'projeto', 'assets', 'fonte', 'PressStart2P.ttf')
F8 = ImageFont.truetype(FONTE, 8)
F16 = ImageFont.truetype(FONTE, 16)
CHAO = 102          # onde a parede do fundo encontra o chão (igual à Sala 204)


def novo(w, h, cor=None):
    im = Image.new('RGBA', (w, h), P[cor] if cor else (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def r(d, x, y, w, h, cor):
    if w > 0 and h > 0:
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=P[cor])


def ln(d, x0, y0, x1, y1, cor):
    d.line([x0, y0, x1, y1], fill=P[cor])


def texto(d, x, y, s, cor, fonte=F8):
    d.text((x, y), s, font=fonte, fill=P[cor])


def texto_centro(d, cx, y, s, cor, fonte=F8):
    w = d.textlength(s, font=fonte)
    d.text((cx - w // 2, y), s, font=fonte, fill=P[cor])


# ================================================================ temas de parede
TEMAS = {
    # a parede de sempre da Cairu: branca em cima, lambri azul embaixo
    'cairu': dict(topo='noite', topo2='ardosia', pintura='cinza_c', emenda='cinza', luz='branco',
                  meia='azul', meia_luz='ciano', lambri='azul_n', lambri_luz='azul', lambri_risco='noite',
                  rodape='noite', rodape_luz='cinza_e'),
    # presidência: madeira escura com friso dourado
    'madeira': dict(topo='preto', topo2='vinho', pintura='vinho', emenda='preto', luz='marrom',
                    meia='amarelo', meia_luz='amarelo_c', lambri='marrom', lambri_luz='tijolo', lambri_risco='vinho',
                    rodape='preto', rodape_luz='vinho'),
}


def parede(im, d, W, tema='cairu', chao=CHAO, emenda=48, risco=24):
    t = TEMAS[tema]
    alto_lambri = 33 + (chao - CHAO)
    y_meia = chao - 46 - (chao - CHAO)
    r(d, 0, 0, W, 6, t['topo'])                    # espessura da parede (topo)
    r(d, 0, 6, W, 2, t['topo2'])
    r(d, 0, 8, W, y_meia - 8, t['pintura'])
    for x in range(emenda // 2, W, emenda):        # emendas de placa com volume
        ln(d, x, 8, x, y_meia - 1, t['emenda'])
        ln(d, x + 1, 8, x + 1, y_meia - 1, t['luz'])
    r(d, 0, y_meia, W, 1, t['meia_luz'])           # meia-cana
    r(d, 0, y_meia + 1, W, 3, t['meia'])
    r(d, 0, y_meia + 4, W, 1, 'noite')
    r(d, 0, y_meia + 5, W, alto_lambri, t['lambri'])
    for x in range(risco // 2, W, risco):
        ln(d, x, y_meia + 5, x, chao - 9, t['lambri_risco'])
        ln(d, x + 1, y_meia + 5, x + 1, chao - 9, t['lambri_luz'])
    r(d, 0, chao - 8, W, 1, t['rodape_luz'])       # rodapé
    r(d, 0, chao - 7, W, 7, t['rodape'])
    faixa_sombra(im, 0, 8, W, 13)                  # sombra do teto na parede
    return y_meia


# ================================================================ pisos
def piso(im, d, W, H, tipo='creme', chao=CHAO, semente=1):
    rnd = random.Random(semente)
    if tipo in ('creme', 'frio'):
        base, junta, luz, pinta = (('creme', 'areia', 'branco', 'areia') if tipo == 'creme'
                                   else ('cinza_c', 'cinza', 'branco', 'cinza'))
        for y in range(chao, H, 32):
            for x in range(0, W, 32):
                r(d, x, y, 32, 32, base)
                ln(d, x, y + 31, x + 31, y + 31, junta)
                ln(d, x + 31, y, x + 31, y + 31, junta)
                ln(d, x, y, x + 6, y, luz)
                ln(d, x, y, x, y + 4, luz)
                for _ in range(3):
                    d.point((x + rnd.randint(3, 28), y + rnd.randint(3, 28)), fill=P[pinta])
    elif tipo == 'xadrez':                          # corredor: creme e areia alternados
        for y in range(chao, H, 16):
            for x in range(0, W, 16):
                r(d, x, y, 16, 16, 'creme')
                if ((x + y) // 16) % 2:                 # ladrilho mais claro: pontilhado de branco
                    for yy in range(y, y + 15, 2):
                        for xx in range(x + (yy // 2) % 2, x + 15, 2):
                            d.point((xx, yy), fill=P['branco'])
                ln(d, x, y + 15, x + 15, y + 15, 'areia')
                ln(d, x + 15, y, x + 15, y + 15, 'areia')
                d.point((x + 2, y + 2), fill=P['branco'])
    elif tipo == 'pedra':                           # pátio: tijolinho de pedra
        for y in range(chao, H, 16):
            off = 12 if (y // 16) % 2 else 0
            for x in range(-24, W, 24):
                r(d, x + off, y, 24, 16, 'creme')
                if rnd.random() < 0.2:                  # pedra mais gasta: pontilhado leve
                    for yy in range(y + 1, y + 14, 2):
                        for xx in range(x + off + 1 + (yy // 2) % 2, x + off + 22, 2):
                            d.point((xx, yy), fill=P['areia'])
                ln(d, x + off, y + 15, x + off + 23, y + 15, 'areia_e')
                ln(d, x + off + 23, y, x + off + 23, y + 15, 'areia_e')
                ln(d, x + off, y, x + off + 5, y, 'branco')
                if rnd.random() < 0.3:
                    d.point((x + off + rnd.randint(3, 20), y + rnd.randint(3, 12)), fill=P['areia_e'])
    elif tipo == 'madeira':                         # assoalho escuro (presidência)
        for y in range(chao, H, 8):
            off = (y // 8 * 53) % 96
            r(d, 0, y, W, 8, 'marrom')
            ln(d, 0, y + 7, W, y + 7, 'vinho')
            for x in range(-off, W, 96):
                ln(d, x, y, x, y + 6, 'vinho')
                ln(d, x + 1, y, x + 6, y, 'tijolo')
                for k in range(3):
                    gx = x + 14 + rnd.randint(0, 70)
                    ln(d, gx, y + 3 + k % 2, gx + rnd.randint(4, 12), y + 3 + k % 2, 'vinho' if k else 'tijolo')
    faixa_sombra(im, 0, chao, W, chao + 10)         # a parede faz sombra no chão


def grama(im, d, x0, y0, w, h, semente=3):
    """Canteiro com borda de meio-fio e tufos (sem verde claro: ele é a cor dos LEDs)."""
    rnd = random.Random(semente)
    r(d, x0, y0, w, h, 'verde')
    for _ in range(w * h // 60):
        px, py = x0 + rnd.randint(2, w - 4), y0 + rnd.randint(5, h - 4)
        r(d, px, py, 1, 3, 'verde_e')
        r(d, px + 2, py + 1, 1, 2, 'verde_e')
    for _ in range(w * h // 400):                  # florzinhas
        d.point((x0 + rnd.randint(4, w - 5), y0 + rnd.randint(6, h - 5)),
                fill=P[rnd.choice(['amarelo_c', 'branco', 'rosa'])])
    r(d, x0 - 2, y0 - 2, w + 4, 2, 'cinza_c')       # meio-fio
    r(d, x0 - 2, y0, w + 4, 2, 'cinza')
    faixa_sombra(im, x0, y0 + 2, x0 + w, y0 + 6)


# ================================================================ paredes dos lados e de baixo
def bordas(im, d, W, H, esq=None, dir=None, baixo=None, larg_esq=12, larg_dir=12, chao=CHAO,
           cor='noite', luz='ardosia'):
    """esq/dir = (y0, y1) da abertura no lado; baixo = (x0, x1) da abertura embaixo."""
    for x0, lw, gap, lado in ((0, larg_esq, esq, 1), (W - larg_dir, larg_dir, dir, -1)):
        trechos = [(0, H)] if not gap else [(0, gap[0]), (gap[1], H)]
        for a, b in trechos:
            r(d, x0, a, lw, b - a, cor)
            xi = x0 + lw - 1 if lado == 1 else x0
            r(d, xi, max(a, 8), 1, b - max(a, 8) - (8 if b == H else 0), luz)
        xs = x0 + lw if lado == 1 else x0 - 6
        for a, b in ([(chao, H - 9)] if not gap else [(chao, gap[0] - 2), (gap[1] + 2, H - 9)]):
            if b - a > 6:
                sombrear(im, xs, a, xs + 5, b, forma='ret', borda=2)
        if gap:                                     # batente da passagem
            for yy in (gap[0] - 3, gap[1]):
                r(d, x0, yy, lw, 3, luz)
    trechos = [(0, W)] if not baixo else [(0, baixo[0]), (baixo[1], W)]
    for a, b in trechos:
        r(d, a, H - 8, b - a, 8, cor)
        r(d, max(a, larg_esq), H - 8, min(b, W - larg_dir) - max(a, larg_esq), 1, luz)


def capacho(d, x, y, w, h, cor='cinza_e'):
    r(d, x, y, w, h, cor)
    r(d, x, y, w, 1, 'cinza')
    for k in range(x + 2, x + w - 2, 3):
        ln(d, k, y + 2, k, y + h - 2, 'ardosia')


def portas_vidro(d, x0, x1, H):
    """Entrada de vidro na parede de baixo."""
    for x in range(x0, x1, 24):
        r(d, x, H - 10, 24, 10, 'ciano')
        r(d, x, H - 10, 24, 3, 'azul')
        ln(d, x, H - 10, x, H, 'cinza_e')
        ln(d, x + 3, H - 6, x + 8, H - 6, 'branco')


# ================================================================ coisas da parede
def porta(d, x, rotulo=None, chao=CHAO, cor='tijolo'):
    """Porta de 48 de largura na parede do fundo. A folha (cor tijolo, moldura marrom) é
    achada pelo jogo e abre de verdade. Devolve o retângulo da folha [x, y, w, h]."""
    if rotulo:
        larg = len(rotulo) * 8
        r(d, x + 24 - larg // 2 - 4, 14, larg + 8, 13, 'noite')
        r(d, x + 24 - larg // 2 - 4, 14, larg + 8, 1, 'ardosia')
        texto(d, x + 24 - larg // 2, 17, rotulo, 'branco')
    topo = chao - 74
    r(d, x, topo, 48, 74, 'marrom')                # batente
    r(d, x + 1, topo, 46, 1, 'tijolo' if cor == 'tijolo' else 'cinza_c')
    r(d, x + 4, topo + 4, 40, 70, cor)             # folha
    r(d, x + 4, topo + 4, 1, 70, 'areia_e' if cor == 'tijolo' else 'cinza_c')
    r(d, x + 9, topo + 10, 30, 16, 'azul')         # visor
    r(d, x + 9, topo + 10, 30, 6, 'ciano')
    for yy in (topo + 32, topo + 52):              # almofadas (sem linha escura)
        r(d, x + 9, yy, 30, 1, 'areia_e' if cor == 'tijolo' else 'cinza_c')
        r(d, x + 9, yy + 14, 30, 1, 'laranja_c' if cor == 'tijolo' else 'branco')
    r(d, x + 36, topo + 38, 4, 4, 'amarelo')
    r(d, x + 36, topo + 38, 4, 1, 'amarelo_c')
    r(d, x - 2, chao, 52, 2, 'vinho')               # soleira
    return [x + 4, topo + 4, 40, 70]


def janela(im, d, x, y, w, h, arvore=True):
    r(d, x - 4, y - 4, w + 8, h + 8, 'cinza_e')    # batente
    r(d, x - 3, y - 3, w + 6, h + 6, 'cinza')
    for i in range(h):                             # céu de Salvador
        r(d, x, y + i, w, 1, 'ciano' if i < h * 0.45 else 'azul')
    if arvore:
        r(d, x, y + h - 8, w, 8, 'verde')
        for k in range(0, w, 6):
            r(d, x + k, y + h - 10 + (k * 7) % 4, 5, 3, 'verde')
            d.point((x + k + 2, y + h - 9 + (k * 7) % 4), fill=P['verde_e'])
    for i in range(1, 3):
        ln(d, x + i * w // 3, y, x + i * w // 3, y + h - 1, 'cinza')
        ln(d, x + i * w // 3 + 1, y, x + i * w // 3 + 1, y + h - 1, 'branco')
    r(d, x, y, w, 7, 'creme')                      # persiana meio baixada
    for k in range(0, 7, 3):
        ln(d, x, y + k + 2, x + w - 1, y + k + 2, 'areia')
    ln(d, x + 5, y + 10, x + 11, y + 10, 'branco')  # brilho no vidro
    r(d, x - 6, y + h + 3, w + 12, 3, 'branco')    # peitoril com volume
    r(d, x - 6, y + h + 6, w + 12, 2, 'cinza')
    faixa_sombra(im, x - 6, y + h + 8, x + w + 6, y + h + 12)


def janela_escura(im, d, x, y, w, h, folhas=3):
    """Janela de vidro fumê (laboratório)."""
    r(d, x - 4, y - 4, w + 8, h + 8, 'cinza_e')
    r(d, x - 3, y - 3, w + 6, h + 6, 'cinza')
    lf = (w - (folhas + 1) * 3) // folhas
    for i in range(folhas):
        xx = x + 3 + i * (lf + 3)
        r(d, xx, y + 2, lf, h - 4, 'noite')
        r(d, xx, y + 2, lf, 3, 'ardosia')
        ln(d, xx + 3, y + 7, xx + 10, y + 7, 'cinza_e')
    r(d, x - 6, y + h + 3, w + 12, 3, 'branco')
    r(d, x - 6, y + h + 6, w + 12, 2, 'cinza')
    faixa_sombra(im, x - 6, y + h + 8, x + w + 6, y + h + 12)


def relogio(d, x, y):
    d.ellipse([x - 12, y - 12, x + 12, y + 12], fill=P['noite'])
    d.ellipse([x - 10, y - 10, x + 10, y + 10], fill=P['branco'])
    for k in range(12):
        a = k * math.pi / 6
        d.point((x + round(math.cos(a) * 8), y + round(math.sin(a) * 8)), fill=P['cinza'])
    ln(d, x, y, x, y - 7, 'preto')
    ln(d, x, y, x + 5, y + 1, 'preto')
    d.arc([x - 10, y - 10, x + 10, y + 10], 200, 290, fill=P['cinza_c'])


def ar_cond(im, d, x, y, led=True):
    r(d, x, y, 84, 18, 'branco')
    r(d, x, y + 18, 84, 6, 'cinza_c')              # face de baixo
    for k in range(3):
        ln(d, x + 4, y + 19 + k * 2, x + 79, y + 19 + k * 2, 'cinza')
    if led:
        r(d, x + 70, y + 5, 5, 2, 'verde_c')
    d.rectangle([x - 1, y - 1, x + 84, y + 24], outline=P['cinza_e'])
    faixa_sombra(im, x, y + 25, x + 84, y + 29)


def mural(im, d, x, y, w, h, n=5, semente=5):
    """Quadro de cortiça. Os papéis ficam onde o animados_mapas.papeis_mural(x, y, w, n) espera."""
    r(d, x - 3, y - 3, w + 6, h + 6, 'marrom')
    r(d, x - 2, y - 2, w + 4, 1, 'tijolo')
    r(d, x, y, w, h, 'areia_e')
    rnd = random.Random(semente)
    for _ in range(w * h // 80):
        d.point((x + rnd.randint(1, w - 2), y + rnd.randint(1, h - 2)), fill=P['tijolo'])
    cores = ('branco', 'amarelo_c', 'ciano', 'rosa', 'branco')
    for i in range(n):
        px, py = x + 4 + i * (w - 8) // n, y + 4 + (i % 2) * 4
        pw, ph = min(14, (w - 8) // n - 1), min(18, h - 6 - (i % 2) * 4)
        r(d, px, py, pw, ph, cores[i % len(cores)])
        for k in range(0, ph - 6, 4):
            ln(d, px + 2, py + 5 + k, px + pw - 3, py + 5 + k, 'cinza')
        r(d, px + pw // 2 - 1, py - 1, 3, 3, 'vermelho')
    faixa_sombra(im, x - 3, y + h + 3, x + w + 3, y + h + 6)


def placa(im, d, x, y, w, h, linhas, fonte=F8, cor='branco'):
    """Placa azul-escura com texto (centralizado em cada linha)."""
    r(d, x, y, w, h, 'noite')
    r(d, x + 2, y + 2, w - 4, h - 4, 'azul_n')
    r(d, x + 2, y + 2, w - 4, 1, 'azul')
    alto = 16 if fonte == F16 else 8
    total = len(linhas) * (alto + 3) - 3
    for i, (s, c) in enumerate(linhas):
        texto_centro(d, x + w // 2, y + (h - total) // 2 + i * (alto + 3), s, c or cor, fonte)
    faixa_sombra(im, x, y + h, x + w, y + h + 4)


def cartazes(d, x, y, cores=('amarelo_c', 'branco', 'rosa')):
    for i, cor in enumerate(cores):
        px = x + i * 22
        r(d, px, y, 18, 26, cor)
        for k in range(4):
            ln(d, px + 3, y + 5 + k * 5, px + 14, y + 5 + k * 5, 'cinza')
        r(d, px + 7, y - 1, 3, 3, 'vermelho')


def sombras(im, objetos, extra=None):
    """Sombra de contato (elipse pontilhada) no chão, embaixo de cada móvel com corpo."""
    extra = extra or {}
    for o in objetos:
        nome = o.get('imagem', '')
        w = extra.get(nome)
        if w is None:
            s = o.get('solido')
            if not s or s[0] <= 0:
                continue
            w = s[0] + 6
        if w <= 0:
            continue
        x, y = o['x'], o['y']
        sombrear(im, x - w / 2, y - 4, x + w / 2, y + 3)


# ================================================================ móveis antigos -> paleta
# cores do desenho antigo (laboratorio.C e companhia) -> nome na paleta
TROCA = {
    '#2a49c9': 'azul_n', '#4d6be0': 'azul', '#1b2f8f': 'noite', '#16204f': 'noite',
    '#f4f6fb': 'branco', '#fdfdfd': 'branco', '#fbfbf2': 'branco', '#f1f3f8': 'branco', '#f1f3fb': 'cinza_c',
    '#e9edf6': 'cinza_c', '#c4c9d6': 'cinza_c', '#9aa1b5': 'cinza', '#6b7288': 'cinza_e',
    '#15171f': 'preto', '#3a3f4e': 'ardosia', '#2b2f3a': 'noite', '#4a5060': 'cinza_e', '#3a3f55': 'ardosia',
    '#a8713d': 'tijolo', '#7a4e26': 'marrom', '#c98f52': 'areia_e', '#94602f': 'tijolo', '#5a3a1e': 'vinho',
    '#5fa8ff': 'azul', '#a8d4ff': 'ciano', '#bfe3ff': 'ciano', '#dff1ff': 'branco',
    '#2f8a3a': 'verde', '#49b555': 'verde', '#4bd06a': 'verde_c', '#b6f0a8': 'verde_c',
    '#b5562f': 'ferrugem', '#d03a3a': 'vermelho', '#b02e2e': 'vermelho_e', '#ffd34e': 'amarelo',
    '#ffb07a': 'areia', '#e8b04a': 'amarelo', '#d98b3a': 'laranja_c', '#2a3550': 'noite',
    '#cfc6aa': 'creme', '#d8cfb4': 'creme', '#a89f84': 'areia_e', '#3a5a3a': 'verde_n',
    '#3d2414': 'vinho', '#5a3520': 'marrom', '#2a1a10': 'preto', '#6e4226': 'marrom', '#2a170a': 'preto',
    '#d8a83a': 'amarelo', '#b8902e': 'laranja', '#e8c45a': 'amarelo_c', '#e8e0d0': 'creme', '#f0e6c8': 'creme',
    '#d8c8a0': 'areia', '#9a1e24': 'vermelho_e', '#b8262c': 'vermelho', '#6e1418': 'vinho',
    '#2b3a2e': 'verde_n', '#e8efe6': 'branco', '#3a6ab0': 'azul', '#4a8a3a': 'verde', '#2a3a6a': 'azul_n',
    '#3a5a2a': 'verde_e', '#5a8a6a': 'verde_e', '#2b2f3a': 'noite', '#5a5a5a': 'cinza_e',
}
_TROCA = {tuple(int(k[i:i + 2], 16) for i in (1, 3, 5)): rgb(v) for k, v in TROCA.items()}


def passar_pra_paleta(im):
    im = im.convert('RGBA')
    px = im.load()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] == 0:
                continue
            k = c[:3]
            if k not in cache:
                cache[k] = _TROCA.get(k) or mais_perto(k)
            px[x, y] = cache[k] + (255 if c[3] > 100 else 0,)
    return im


def luz_no_topo(im):
    """Primeira linha de cada coluna fica um tom mais clara (a luz do teto bate em cima)."""
    from paleta import ESCURO
    claro = {v: k for k, v in ESCURO.items()}
    px = im.load()
    for x in range(im.width):
        for y in range(im.height):
            c = px[x, y]
            if c[3]:
                if c[:3] in claro and c[:3] not in (rgb('preto'), rgb('noite')):
                    px[x, y] = claro[c[:3]] + (255,)
                break


def movel_gba(caminho, luz=True):
    """Passa um móvel antigo (png) pro estilo novo: paleta, luz em cima e contorno.
    Ganha 1 px de margem em volta (o contorno); o pé continua no mesmo lugar."""
    im = passar_pra_paleta(Image.open(caminho))
    if luz:
        luz_no_topo(im)
    big = Image.new('RGBA', (im.width + 2, im.height + 2), (0, 0, 0, 0))
    big.alpha_composite(im, (1, 1))
    contornar(big)
    big.save(caminho)
    return big


# ================================================================ JSON do mapa
def carregar(mid):
    return json.load(open(os.path.join(OUT, mid + '.json'), encoding='utf-8'))


def gravar(mid, m):
    json.dump(m, open(os.path.join(OUT, mid + '.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)


def trocar_enfeites(m):
    """Vasos e lixeiras desenhados pelo jogo (tipo "planta"/"lixeira") viram os da Sala 204."""
    for o in m.get('objetos', []):
        if o.get('tipo') == 'planta':
            o.pop('tipo')
            o['imagem'] = 'sala204_planta.png'
            o['solido'] = [18, 8]
        elif o.get('tipo') == 'lixeira':
            o.pop('tipo')
            o['imagem'] = 'sala204_lixeira.png'
            o['solido'] = [16, 8]


def folhas_das_portas(m, folhas):
    """Grava o retângulo da folha de cada porta da parede de cima (destino -> [x, y, w, h])."""
    for p in m.get('portas', []):
        if p['para'] in folhas:
            p['folha'] = folhas[p['para']]


def salvar_fundo(im, nome):
    quantizar(im).save(os.path.join(OUT, nome + '.png'))

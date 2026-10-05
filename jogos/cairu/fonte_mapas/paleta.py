"""Paleta única do JOGO: Endesga 32 (Lospec, livre para usar).

Todo cenário novo usa só estas 32 cores. Sombra não é preto transparente: cada cor
escurece para a vizinha mais escura da mesma "rampa" (como nos jogos de GBA), e a borda
da sombra é pontilhada.

    from paleta import P, sombrear, contornar, quantizar
"""
from PIL import Image

P = {
    'preto': '#181425', 'noite': '#262b44', 'ardosia': '#3a4466', 'cinza_e': '#5a6988',
    'cinza': '#8b9bb4', 'cinza_c': '#c0cbdc', 'branco': '#ffffff',
    'azul_n': '#124e89', 'azul': '#0099db', 'ciano': '#2ce8f5',
    'verde_n': '#193c3e', 'verde_e': '#265c42', 'verde': '#3e8948', 'verde_c': '#63c74d',
    'creme': '#ead4aa', 'areia': '#e4a672', 'areia_e': '#c28569', 'pele': '#e8b796',
    'tijolo': '#b86f50', 'marrom': '#733e39', 'vinho': '#3e2731',
    'vermelho_e': '#a22633', 'vermelho': '#e43b44', 'rosa': '#f6757a', 'pink': '#ff0044',
    'ferrugem': '#be4a2f', 'laranja_c': '#d77643', 'laranja': '#f77622', 'amarelo': '#feae34',
    'amarelo_c': '#fee761', 'roxo': '#68386c', 'magenta': '#b55088',
}

# cada cor -> a próxima mais escura da mesma rampa
_RAMPAS = [
    ['branco', 'cinza_c', 'cinza', 'cinza_e', 'ardosia', 'noite', 'preto'],
    ['creme', 'areia', 'areia_e', 'tijolo', 'marrom', 'vinho', 'preto'],
    ['pele', 'areia_e'],
    ['ciano', 'azul', 'azul_n', 'noite'],
    ['verde_c', 'verde', 'verde_e', 'verde_n', 'preto'],
    ['amarelo_c', 'amarelo', 'laranja', 'ferrugem', 'vermelho_e', 'vinho'],
    ['laranja_c', 'tijolo'],
    ['rosa', 'vermelho', 'vermelho_e', 'vinho'],
    ['pink', 'vermelho_e'],
    ['magenta', 'roxo', 'vinho'],
]


def rgb(nome):
    h = P[nome].lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


ESCURO = {}
for r in _RAMPAS:
    for a, b in zip(r, r[1:]):
        ESCURO.setdefault(rgb(a), rgb(b))
CORES = [rgb(n) for n in P]


def mais_perto(c):
    return min(CORES, key=lambda p: (p[0] - c[0]) ** 2 * 3 + (p[1] - c[1]) ** 2 * 4 + (p[2] - c[2]) ** 2 * 2)


def escurecer(c, vezes=1):
    c = tuple(c[:3])
    if c not in ESCURO:
        c = mais_perto(c)
    for _ in range(vezes):
        c = ESCURO.get(c, c)
    return c


def sombrear(im, x0, y0, x1, y1, forma='elipse', vezes=1, borda=2):
    """Escurece uma área do fundo na rampa da paleta; borda pontilhada (xadrez)."""
    px = im.load()
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rx, ry = max((x1 - x0) / 2, 1), max((y1 - y0) / 2, 1)
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            if not (0 <= x < im.width and 0 <= y < im.height):
                continue
            if forma == 'elipse':
                dd = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if dd > 1:
                    continue
                miolo = dd < (1 - borda / max(rx, ry)) ** 2
            else:
                miolo = x0 + borda <= x <= x1 - borda and y0 + borda <= y <= y1 - borda
            if not miolo and (x + y) % 2:
                continue
            c = px[x, y]
            px[x, y] = escurecer(c, vezes) + ((c[3],) if len(c) == 4 else ())


def faixa_sombra(im, x0, y0, x1, y1, vezes=1):
    """Sombra em degradê pontilhado de cima (forte) pra baixo (some)."""
    px = im.load()
    alto = max(y1 - y0, 1)
    for y in range(y0, y1):
        f = 1 - (y - y0) / alto
        for x in range(x0, x1):
            if f > 0.66 or (f > 0.33 and (x + y) % 2 == 0) or (f > 0 and (x % 2 == 0 and y % 2 == 0)):
                c = px[x, y]
                px[x, y] = escurecer(c, vezes) + ((c[3],) if len(c) == 4 else ())


def contornar(im, cor='preto'):
    """Contorno de 1 px por fora da silhueta (precisa de 1 px de margem livre)."""
    c = rgb(cor) + (255,)
    a = im.split()[3].load()
    px = im.load()
    alvo = []
    for y in range(im.height):
        for x in range(im.width):
            if a[x, y] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < im.width and 0 <= ny < im.height and a[nx, ny] > 0:
                    alvo.append((x, y))
                    break
    for x, y in alvo:
        px[x, y] = c


def quantizar(im):
    """Leva todos os pixels opacos para a cor mais perto da paleta."""
    im = im.convert('RGBA')
    px = im.load()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            k = (r, g, b)
            if k not in cache:
                cache[k] = mais_perto(k)
            px[x, y] = cache[k] + (255 if a > 127 else 0,)
    return im

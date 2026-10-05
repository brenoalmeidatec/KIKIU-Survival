"""Põe os detalhes animados ("animados") e o balanço das árvores/plantas em cada mapa.

Acha sozinho as telas de computador, os LEDs e os enfeites dourados nos desenhos
(fundo e móveis) e junta com os que são colocados à mão (relógio, mural, bebedouro...).
Roda de novo sempre que um mapa for redesenhado:  python3 animados_mapas.py
"""
import json
import os

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
MAPAS = os.path.join(AQUI, '..', 'projeto', 'capitulos', 'mapas')


def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def manchas(img, cores, minimo=4, maximo=10 ** 6):
    """Retângulos de cada pedaço contínuo das cores dadas."""
    px = img.load()
    w, h = img.size
    visto = set()
    saida = []
    for y in range(h):
        for x in range(w):
            if (x, y) in visto or px[x, y][3] == 0 or px[x, y][:3] not in cores:
                continue
            pilha = [(x, y)]
            visto.add((x, y))
            xs, ys = [], []
            while pilha:
                a, b = pilha.pop()
                xs.append(a)
                ys.append(b)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = (a + dx, b + dy)
                    if 0 <= n[0] < w and 0 <= n[1] < h and n not in visto and px[n][3] > 0 and px[n][:3] in cores:
                        visto.add(n)
                        pilha.append(n)
            if minimo <= len(xs) <= maximo:
                saida.append((min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1))
    return saida


def no_mapa(m, cores, minimo=4, maximo=10 ** 6, fundo_tambem=True, moldura=None, pular=()):
    """[(x, y, w, h, base)] no mapa todo: fundo (base = embaixo da mancha) e móveis (base = pé do móvel).
    moldura = cor que tem que estar logo acima e à esquerda da mancha (a borda preta do monitor);
    pular = pedaços do nome de imagens que não entram (plantas, árvores)."""
    achados = []
    fundo = Image.open(os.path.join(MAPAS, m['fundo']['imagem'])).convert('RGBA')
    for x, y, w, h in (manchas(fundo, cores, minimo, maximo) if fundo_tambem else []):
        achados.append((x, y, w, h, y + h))
    for o in m.get('objetos', []):
        if 'imagem' not in o or any(p in o['imagem'] for p in pular):
            continue
        im = Image.open(os.path.join(MAPAS, o['imagem'])).convert('RGBA')
        px = im.load()
        ox, oy = o['x'] - im.width // 2, o['y'] - im.height
        for x, y, w, h in manchas(im, cores, minimo, maximo):
            if moldura and not (x > 0 and y > 0 and px[x - 1, y - 1][:3] == moldura):
                continue
            achados.append((ox + x, oy + y, w, h, o['y']))
    return achados


# desenho antigo e paleta nova (paleta.py): a tela é azul+ciano com borda preta em volta
TELA = {rgb('#5fa8ff'), rgb('#a8d4ff'), rgb('#0099db'), rgb('#2ce8f5')}
PRETO = rgb('#181425')
LED = {rgb('#4bd06a'), rgb('#63c74d')}
OURO = {rgb('#d8a83a'), rgb('#ffd34e'), rgb('#feae34')}
SEM_LED = ('planta', 'arvore')


def telas(m, estilos=('codigo', 'brilho')):
    out = []
    for i, (x, y, w, h, b) in enumerate(no_mapa(m, TELA, 60, fundo_tambem=False, moldura=PRETO)):
        if w >= 12 and h >= 6:
            out.append({'tipo': 'tela', 'x': x, 'y': y, 'w': w, 'h': h, 'base': b + 0.5,
                        'estilo': estilos[i % len(estilos)]})
    return out


def leds(m):
    out = []
    for x, y, w, h, b in no_mapa(m, LED, 2, 12, pular=SEM_LED):
        out.append({'tipo': 'led', 'x': x, 'y': y, 'w': w, 'h': h, 'base': b + 0.5, 'ritmo': 0.6 + (x % 7) * 0.15})
    return out


def brilhos(m, minimo=6, maximo=400, passo=1):
    out = []
    for i, (x, y, w, h, b) in enumerate(no_mapa(m, OURO, minimo, maximo)):
        if i % passo == 0:
            out.append({'tipo': 'brilho', 'x': x + w - 2, 'y': y + 1, 'base': b + 0.6, 'periodo': 3.0 + (i * 1.7) % 4})
    return out


def papeis_mural(x, y, w, n):
    out = []
    for i in range(n):
        px = x + 4 + i * (w - 8) // n
        py = y + 4 + (i % 2) * 4
        out.append({'tipo': 'papel', 'x': px, 'y': py, 'w': 14, 'h': 18, 'ritmo': 1.6 + i * 0.35})
    return out


def montar():
    a = {}
    # ---------------- recepção
    m = carregar('recepcao')
    # x 734 é o galão do bebedouro, não uma tela
    a['recepcao'] = [t for t in telas(m, ('brilho',)) if t['x'] != 734] + leds(m) + papeis_mural(600, 18, 100, 5) + [
        {'tipo': 'relogio', 'x': 200, 'y': 32, 'r': 9, 'base': 40},
        {'tipo': 'bolhas', 'x': 736, 'y': 170, 'w': 8, 'h': 9, 'base': 200.5},
        {'tipo': 'letreiro', 'x': 262, 'y': 10, 'w': 276, 'h': 40, 'cor': '#ffd34e', 'base': 60},
    ] + brilhos(m, 8, 200, 2)
    # ---------------- pátio
    m = carregar('patio')
    a['patio'] = leds(m) + [
        {'tipo': 'letreiro', 'x': 160, 'y': 6, 'w': 160, 'h': 20, 'cor': '#feae34', 'base': 30},
        {'tipo': 'tremeluz', 'x': 532, 'y': 60, 'w': 34, 'h': 70, 'cor': '#9fd8ff', 'forca': 0.08, 'periodo': 9, 'base': 134.5},
    ]
    # ---------------- sala 204
    m = carregar('sala_aula')
    a['sala_aula'] = papeis_mural(502, 44, 80, 5) + [
        {'tipo': 'led', 'x': 574, 'y': 17, 'w': 5, 'h': 2, 'cor': '#63c74d', 'base': 40, 'ritmo': 0.5, 'ligado': 0.85},
        {'tipo': 'relogio', 'x': 124, 'y': 32, 'r': 10, 'base': 45},
        {'tipo': 'nuvens', 'x': 24, 'y': 27, 'w': 68, 'h': 17, 'colunas': [46, 69], 'velocidade': 2.5, 'base': 60},
        {'tipo': 'brilho', 'x': 678, 'y': 66, 'base': 104, 'periodo': 5},
        {'tipo': 'brilho', 'x': 458, 'y': 12, 'base': 90, 'periodo': 6.5, 'tam': 5},
    ]
    # ---------------- corredor
    m = carregar('corredor')
    a['corredor'] = sum((papeis_mural(x + 3, 33, 50, 3) for x in (184, 360, 536)), []) + [
        {'tipo': 'tremeluz', 'x': 420, 'y': 104, 'w': 120, 'h': 158, 'forca': 0.05, 'periodo': 6.5, 'base': 104},
    ] + brilhos(m, 6, 40)
    # ---------------- laboratório
    m = carregar('laboratorio')
    a['laboratorio'] = telas(m, ('codigo', 'brilho', 'codigo', 'codigo', 'brilho')) + leds(m)
    # ---------------- núcleo
    m = carregar('nucleo')
    velhas = []
    for i, (x, y, w, h, b) in enumerate(no_mapa(m, {rgb('#2a3550'), rgb('#3a5a3a'), rgb('#262b44'), rgb('#193c3e')}, 40)):
        if w == 10 and h == 8:
            velhas.append({'tipo': 'tela', 'x': x, 'y': y, 'w': w, 'h': h, 'base': b + 0.5,
                           'estilo': ('chiado', 'verde', 'chiado', 'brilho')[i % 4]})
    a['nucleo'] = telas(m, ('codigo',)) + velhas[::2] + leds(m) + [
        {'tipo': 'relogio', 'x': 640, 'y': 30, 'r': 9, 'base': 40},
    ]
    # ---------------- presidência
    m = carregar('presidencia')
    im = Image.open(os.path.join(MAPAS, 'presidencia_mesa2.png'))
    globo = (470 - im.width // 2 + 20, 270 - im.height + 12)
    a['presidencia'] = brilhos(m, 6, 600, 3) + [
        {'tipo': 'globo', 'x': globo[0], 'y': globo[1], 'r': 11, 'base': 270.5},
    ]
    balanco = {'patio_arvore.png': 1.6, 'sala204_planta.png': 1.0, 'planta': 1.0}
    for mid, lista in a.items():
        m = carregar(mid)
        m['animados'] = lista
        for o in m.get('objetos', []):
            k = o.get('imagem', o.get('tipo'))
            if k in balanco:
                o['balanco'] = balanco[k]
        json.dump(m, open(os.path.join(MAPAS, mid + '.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
        print(mid, len(lista), 'animados')


def carregar(mid):
    return json.load(open(os.path.join(MAPAS, mid + '.json'), encoding='utf-8'))


if __name__ == '__main__':
    montar()

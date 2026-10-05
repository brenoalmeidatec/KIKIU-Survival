"""Sala 204 no estilo GBA (Pokémon FireRed): perspectiva 3/4, parede de frente com
rodapé e lambri, janela e móveis com volume, contorno escuro, sombra de contato e
só as cores da paleta única (paleta.py, Endesga 32).

Saída em projeto/capitulos/mapas/: sala_aula.png (fundo), sala204_*.png (móveis) e
os "objetos" do sala_aula.json (o resto do JSON fica como está).
    python3 sala204_gba.py
"""
import json
import os
import random

from PIL import Image, ImageDraw, ImageFont

from paleta import P, contornar, faixa_sombra, quantizar, sombrear

AQUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(AQUI, '..', 'projeto', 'capitulos', 'mapas')
FONTE = os.path.join(AQUI, '..', 'projeto', 'assets', 'fonte', 'PressStart2P.ttf')
F8 = ImageFont.truetype(FONTE, 8)
W, H = 720, 448
CHAO = 102          # onde a parede encontra o chão


def novo(w, h, cor=None):
    im = Image.new('RGBA', (w, h), P[cor] if cor else (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def r(d, x, y, w, h, cor):
    if w > 0 and h > 0:
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=P[cor])


def ln(d, x0, y0, x1, y1, cor):
    d.line([x0, y0, x1, y1], fill=P[cor])


# ================================================================ fundo
def parede(im, d):
    r(d, 0, 0, W, 6, 'noite')                       # espessura da parede (topo)
    r(d, 0, 6, W, 2, 'ardosia')
    r(d, 0, 8, W, 48, 'cinza_c')                   # pintura de cima
    for x in range(24, W, 48):                     # emendas de placa com volume
        ln(d, x, 8, x, 55, 'cinza')
        ln(d, x + 1, 8, x + 1, 55, 'branco')
    r(d, 0, 56, W, 1, 'ciano')                     # meia-cana
    r(d, 0, 57, W, 3, 'azul')
    r(d, 0, 60, W, 1, 'noite')
    r(d, 0, 61, W, 33, 'azul_n')                   # lambri azul da Cairu
    for x in range(12, W, 24):
        ln(d, x, 61, x, 93, 'noite')
        ln(d, x + 1, 61, x + 1, 93, 'azul')
    r(d, 0, 94, W, 1, 'cinza_e')                   # rodapé
    r(d, 0, 95, W, 7, 'noite')
    faixa_sombra(im, 0, 8, W, 13)                  # sombra do teto na parede


def piso(im, d):
    rnd = random.Random(204)
    for y in range(CHAO, H, 32):
        for x in range(0, W, 32):
            r(d, x, y, 32, 32, 'creme')
            ln(d, x, y + 31, x + 31, y + 31, 'areia')
            ln(d, x + 31, y, x + 31, y + 31, 'areia')
            ln(d, x, y, x + 6, y, 'branco')
            ln(d, x, y, x, y + 4, 'branco')
            for _ in range(3):
                d.point((x + rnd.randint(3, 28), y + rnd.randint(3, 28)), fill=P['areia'])
    faixa_sombra(im, 0, CHAO, W, CHAO + 10)        # parede faz sombra no chão


def bordas(im, d):
    r(d, 0, 0, 12, H, 'noite')
    r(d, 11, 8, 1, H - 16, 'ardosia')
    r(d, W - 12, 0, 12, H, 'noite')
    r(d, W - 12, 8, 1, H - 16, 'ardosia')
    r(d, 0, H - 8, W, 8, 'noite')
    r(d, 12, H - 8, W - 24, 1, 'ardosia')
    for x0 in (12, W - 18):                        # sombra das paredes do lado
        sombrear(im, x0, CHAO, x0 + 5, H - 9, forma='ret', borda=2)


def janela(im, d, x, y, w, h):
    r(d, x - 4, y - 4, w + 8, h + 8, 'cinza_e')    # batente
    r(d, x - 3, y - 3, w + 6, h + 6, 'cinza')
    for i in range(h):                             # céu de Salvador
        cor = 'ciano' if i < h * 0.45 else 'azul'
        r(d, x, y + i, w, 1, cor)
    r(d, x, y + 30, w, h - 30, 'verde')            # copa das árvores lá fora
    for k in range(0, w, 6):
        r(d, x + k, y + 28 + (k * 7) % 4, 5, 3, 'verde_c')
    for i in range(1, 3):
        ln(d, x + i * w // 3, y, x + i * w // 3, y + h - 1, 'cinza')
        ln(d, x + i * w // 3 + 1, y, x + i * w // 3 + 1, y + h - 1, 'branco')
    r(d, x, y, w, 9, 'creme')                      # persiana meio baixada
    for k in range(0, 9, 3):
        ln(d, x, y + k + 2, x + w - 1, y + k + 2, 'areia')
    ln(d, x + 6, y + 12, x + 12, y + 12, 'branco')  # brilho no vidro
    r(d, x - 6, y + h + 3, w + 12, 3, 'branco')    # peitoril com volume
    r(d, x - 6, y + h + 6, w + 12, 2, 'cinza')
    faixa_sombra(im, x - 6, y + h + 8, x + w + 6, y + h + 12)


def relogio(d, x, y):
    d.ellipse([x - 12, y - 12, x + 12, y + 12], fill=P['noite'])
    d.ellipse([x - 10, y - 10, x + 10, y + 10], fill=P['branco'])
    for k in range(12):
        import math
        a = k * math.pi / 6
        d.point((x + round(math.cos(a) * 8), y + round(math.sin(a) * 8)), fill=P['cinza'])
    ln(d, x, y, x, y - 7, 'preto')
    ln(d, x, y, x + 5, y + 1, 'preto')
    ln(d, x, y, x - 3, y + 6, 'vermelho')
    d.arc([x - 10, y - 10, x + 10, y + 10], 200, 290, fill=P['cinza_c'])


def quadro(im, d, x, y, w, h):
    r(d, x - 4, y - 4, w + 8, h + 8, 'cinza_e')    # moldura de alumínio
    r(d, x - 3, y - 3, w + 6, 1, 'branco')
    r(d, x - 3, y - 2, w + 6, h + 4, 'cinza')
    r(d, x, y, w, h, 'branco')
    for (ax, ay, aw) in ((x + 200, y + 50, 60), (x + 30, y + 58, 40), (x + 150, y + 10, 30)):
        r(d, ax, ay, aw, 2, 'cinza_c')             # borrões de apagador
    d.text((x + 12, y + 8), 'AULA 3: CUSTOS', font=F8, fill=P['azul_n'])
    ln(d, x + 12, y + 20, x + 128, y + 20, 'vermelho')
    for k, cor in enumerate(('verde', 'verde', 'azul_n')):
        ln(d, x + 12, y + 30 + k * 9, x + 100 + k * 20, y + 30 + k * 9, cor)
    # gráfico de barras
    ln(d, x + 196, y + 12, x + 196, y + 52, 'azul_n')
    ln(d, x + 196, y + 52, x + 268, y + 52, 'azul_n')
    for k, hh in enumerate((14, 24, 18, 34)):
        r(d, x + 204 + k * 16, y + 52 - hh, 10, hh, 'vermelho' if k == 3 else 'azul')
    d.text((x + 164, y + 44), 'R$', font=F8, fill=P['verde'])
    # bandeja dos pincéis com volume
    r(d, x - 6, y + h + 4, w + 12, 3, 'cinza_c')
    r(d, x - 6, y + h + 7, w + 12, 2, 'cinza_e')
    for k, cor in enumerate(('vermelho', 'azul_n', 'preto', 'verde')):
        r(d, x + 16 + k * 14, y + h + 2, 10, 3, cor)
    r(d, x + w - 40, y + h + 1, 18, 4, 'noite')    # apagador
    r(d, x + w - 40, y + h + 1, 18, 1, 'ardosia')
    faixa_sombra(im, x - 6, y + h + 9, x + w + 6, y + h + 13)


def ar_cond(im, d, x, y):
    r(d, x, y, 84, 18, 'branco')
    r(d, x, y + 18, 84, 6, 'cinza_c')              # face de baixo
    for k in range(3):
        ln(d, x + 4, y + 19 + k * 2, x + 79, y + 19 + k * 2, 'cinza')
    r(d, x + 70, y + 5, 5, 2, 'verde_c')
    d.rectangle([x - 1, y - 1, x + 84, y + 24], outline=P['cinza_e'])
    faixa_sombra(im, x, y + 25, x + 84, y + 29)


def mural(im, d, x, y, w, h):
    r(d, x - 3, y - 3, w + 6, h + 6, 'marrom')
    r(d, x - 2, y - 2, w + 4, 1, 'tijolo')
    r(d, x, y, w, h, 'areia_e')
    rnd = random.Random(5)
    for _ in range(30):
        d.point((x + rnd.randint(1, w - 2), y + rnd.randint(1, h - 2)), fill=P['tijolo'])
    cores = ('branco', 'amarelo_c', 'ciano', 'rosa', 'branco')
    for i in range(5):
        px, py = x + 4 + i * (w - 8) // 5, y + 4 + (i % 2) * 6
        r(d, px, py, 13, 16, cores[i])
        for k in range(3):
            ln(d, px + 2, py + 5 + k * 3, px + 10, py + 5 + k * 3, 'cinza')
        r(d, px + 5, py - 1, 3, 3, 'vermelho')
    faixa_sombra(im, x - 3, y + h + 3, x + w + 3, y + h + 6)


def porta(d, x):
    """Porta de 48 de largura; a folha (cor tijolo) é achada pelo jogo e abre de verdade."""
    r(d, x + 24 - 15, 14, 30, 13, 'noite')
    d.text((x + 24 - 12, 17), '204', font=F8, fill=P['branco'])
    r(d, x, 28, 48, 74, 'marrom')                  # batente
    r(d, x + 1, 28, 46, 1, 'tijolo')
    r(d, x + 4, 32, 40, 70, 'tijolo')              # folha
    r(d, x + 4, 32, 1, 70, 'areia_e')
    r(d, x + 9, 38, 30, 16, 'azul')                # visor
    r(d, x + 9, 38, 30, 6, 'ciano')
    for yy in (60, 80):                            # almofadas (sem linha escura)
        r(d, x + 9, yy, 30, 1, 'areia_e')
        r(d, x + 9, yy + 14, 30, 1, 'laranja_c')
    r(d, x + 36, 66, 4, 4, 'amarelo')
    r(d, x + 36, 66, 4, 1, 'amarelo_c')
    r(d, x - 2, 102, 52, 2, 'vinho')               # soleira


def extintor(d, x, y):
    r(d, x - 2, y - 14, 14, 9, 'vermelho')         # plaquinha
    d.text((x - 1, y - 14), '!', font=F8, fill=P['branco'])
    r(d, x, y, 9, 20, 'vermelho')
    r(d, x, y, 2, 20, 'rosa')
    r(d, x + 7, y, 2, 20, 'vermelho_e')
    r(d, x + 2, y - 3, 5, 3, 'preto')
    ln(d, x + 7, y - 2, x + 11, y + 8, 'preto')


def fundo(objetos):
    im, d = novo(W, H, 'creme')
    piso(im, d)
    parede(im, d)
    janela(im, d, 24, 16, 68, 36)
    relogio(d, 124, 32)
    quadro(im, d, 180, 14, 280, 64)
    ar_cond(im, d, 504, 12)
    mural(im, d, 502, 44, 80, 32)
    extintor(d, 606, 70)
    r(d, 626, 62, 6, 9, 'branco')                  # interruptor
    r(d, 628, 64, 2, 3, 'cinza')
    porta(d, 640)
    bordas(im, d)
    # sombra de contato embaixo de cada móvel
    for o in objetos:
        w = o['sombra']
        sombrear(im, o['x'] - w / 2, o['y'] - 4, o['x'] + w / 2, o['y'] + 3)
    return quantizar(im)


# ================================================================ móveis
def finalizar(im, nome):
    im = quantizar(im)
    contornar(im)
    im.save(os.path.join(OUT, nome + '.png'))


def carteira(variante):
    im, d = novo(34, 46)
    o = 2
    r(d, o + 3, o + 6, 20, 9, 'azul')              # assento (mais longe, aparece em cima)
    r(d, o + 3, o + 6, 20, 1, 'ciano')
    r(d, o + 17, o + 1, 13, 12, 'creme')           # prancheta (tampo)
    r(d, o + 17, o + 1, 13, 1, 'branco')
    r(d, o + 17, o + 13, 13, 2, 'areia_e')         # espessura da prancheta
    if variante == 'caderno':
        r(d, o + 18, o + 3, 11, 8, 'branco')
        ln(d, o + 23, o + 3, o + 23, o + 10, 'cinza')
        for k in range(3):
            ln(d, o + 19, o + 5 + k * 2, o + 22, o + 5 + k * 2, 'azul')
        r(d, o + 25, o + 5, 4, 1, 'vermelho')
    r(d, o + 2, o + 14, 22, 3, 'azul')             # aro do encosto
    r(d, o + 2, o + 14, 22, 1, 'ciano')
    r(d, o + 2, o + 17, 22, 13, 'azul_n')          # costas do encosto
    r(d, o + 10, o + 20, 6, 2, 'noite')            # alça vazada
    r(d, o + 3, o + 17, 1, 12, 'azul')
    for x in (o + 4, o + 20):                      # pés de metal
        r(d, x, o + 30, 2, 12, 'cinza_e')
        r(d, x, o + 30, 1, 12, 'cinza')
    r(d, o + 4, o + 37, 18, 1, 'cinza_e')
    r(d, o + 26, o + 15, 2, 15, 'cinza_e')         # braço da prancheta
    if variante == 'mochila':
        r(d, o + 0, o + 19, 9, 13, 'vermelho')
        r(d, o + 0, o + 19, 9, 4, 'vermelho_e')
        r(d, o + 3, o + 27, 3, 2, 'amarelo')
        ln(d, o + 2, o + 16, o + 2, o + 19, 'noite')
    if variante == 'casaco':
        r(d, o + 1, o + 13, 24, 6, 'verde')
        r(d, o + 1, o + 13, 24, 1, 'verde_c')
        r(d, o + 2, o + 19, 5, 9, 'verde')
        r(d, o + 19, o + 19, 5, 7, 'verde_e')
    finalizar(im, 'sala204_carteira' + ('' if variante == 'vazia' else '_' + variante))


def mesa_prof():
    im, d = novo(100, 60)
    o = 2
    r(d, o + 56, o + 0, 22, 14, 'noite')           # encosto da cadeira (atrás da mesa)
    r(d, o + 56, o + 0, 22, 2, 'ardosia')
    r(d, o + 0, o + 12, 96, 16, 'areia')           # tampo
    r(d, o + 0, o + 12, 96, 1, 'creme')
    r(d, o + 0, o + 26, 96, 2, 'creme')            # quina da frente
    r(d, o + 10, o + 2, 28, 15, 'cinza')           # notebook (tampa virada pro professor)
    r(d, o + 10, o + 2, 28, 1, 'cinza_c')
    r(d, o + 21, o + 7, 6, 5, 'cinza_c')
    r(d, o + 8, o + 16, 32, 3, 'cinza_e')
    r(d, o + 46, o + 15, 16, 10, 'branco')         # pilha de provas
    r(d, o + 46, o + 24, 16, 2, 'cinza_c')
    r(d, o + 48, o + 17, 10, 1, 'cinza')
    r(d, o + 70, o + 13, 8, 9, 'vermelho')         # caneca
    r(d, o + 70, o + 13, 8, 2, 'vinho')
    r(d, o + 78, o + 15, 2, 4, 'vermelho')
    r(d, o + 84, o + 18, 6, 6, 'verde_c')          # maçã do professor
    r(d, o + 86, o + 16, 1, 2, 'marrom')
    r(d, o + 0, o + 28, 96, 26, 'tijolo')          # frente
    r(d, o + 4, o + 31, 42, 20, 'marrom')
    r(d, o + 50, o + 31, 42, 20, 'marrom')
    r(d, o + 5, o + 32, 40, 18, 'tijolo')
    r(d, o + 51, o + 32, 40, 18, 'tijolo')
    r(d, o + 5, o + 32, 40, 1, 'areia_e')
    r(d, o + 51, o + 32, 40, 1, 'areia_e')
    r(d, o + 2, o + 54, 4, 2, 'marrom')
    r(d, o + 90, o + 54, 4, 2, 'marrom')
    finalizar(im, 'sala204_mesa_prof')


def planta():
    im, d = novo(32, 50)
    o = 2
    folhas = [(4, 4, 10, 18, 'verde'), (14, 0, 10, 20, 'verde'), (8, 10, 14, 14, 'verde_e'),
              (0, 14, 10, 12, 'verde'), (18, 12, 10, 12, 'verde_e'), (10, 2, 4, 8, 'verde_c'),
              (2, 16, 3, 5, 'verde_c'), (20, 14, 3, 5, 'verde_c'), (16, 2, 3, 6, 'verde_c')]
    for x, y, w, h, cor in folhas:
        d.ellipse([o + x, o + y, o + x + w, o + y + h], fill=P[cor])
    r(d, o + 5, o + 26, 18, 4, 'laranja_c')        # borda do vaso
    r(d, o + 6, o + 26, 16, 2, 'vinho')            # terra
    r(d, o + 6, o + 30, 16, 14, 'tijolo')
    r(d, o + 6, o + 30, 3, 14, 'laranja_c')
    r(d, o + 19, o + 30, 3, 14, 'marrom')
    finalizar(im, 'sala204_planta')


def lixeira():
    im, d = novo(22, 28)
    o = 2
    r(d, o + 3, o + 1, 4, 5, 'branco')             # papel amassado saindo
    r(d, o + 9, o + 0, 5, 4, 'cinza_c')
    d.ellipse([o + 0, o + 3, o + 17, o + 9], fill=P['cinza_c'])
    d.ellipse([o + 2, o + 4, o + 15, o + 8], fill=P['noite'])
    r(d, o + 1, o + 7, 16, 15, 'cinza')
    r(d, o + 1, o + 7, 3, 15, 'cinza_c')
    r(d, o + 14, o + 7, 3, 15, 'cinza_e')
    for k in range(3):
        ln(d, o + 6 + k * 3, o + 10, o + 6 + k * 3, o + 19, 'cinza_e')
    finalizar(im, 'sala204_lixeira')


def bolinha():
    im, d = novo(9, 8)
    d.ellipse([2, 2, 7, 6], fill=P['branco'])
    d.point((4, 4), fill=P['cinza_c'])
    finalizar(im, 'sala204_papel')


def estante():
    im, d = novo(52, 62)
    o = 2
    r(d, o, o, 48, 4, 'areia')                     # tampo
    r(d, o, o, 48, 1, 'creme')
    r(d, o, o + 4, 48, 54, 'tijolo')
    rnd = random.Random(3)
    for k, yy in enumerate((o + 6, o + 24, o + 42)):
        r(d, o + 3, yy, 42, 15, 'marrom')
        x = o + 4
        while x < o + 42:
            w = rnd.randint(3, 6)
            hh = rnd.randint(10, 14)
            cor = rnd.choice(['azul', 'vermelho', 'verde', 'amarelo', 'azul_n', 'creme', 'roxo'])
            r(d, x, yy + 15 - hh, w, hh, cor)
            r(d, x, yy + 15 - hh, 1, hh, 'branco' if cor in ('azul_n', 'roxo') else 'creme')
            x += w + (1 if rnd.random() < 0.7 else 4)
        r(d, o + 3, yy + 15, 42, 2, 'areia_e')
    finalizar(im, 'sala204_estante')


# ================================================================ montar
def main():
    for v in ('vazia', 'mochila', 'caderno', 'casaco'):
        carteira(v)
    mesa_prof()
    planta()
    lixeira()
    bolinha()
    estante()
    rnd = random.Random(42)
    objetos = [{'imagem': 'sala204_mesa_prof.png', 'x': 320, 'y': 168, 'solido': [92, 24], 'sombra': 100},
               {'imagem': 'sala204_planta.png', 'x': 112, 'y': 128, 'solido': [18, 8], 'sombra': 22},
               {'imagem': 'sala204_estante.png', 'x': 42, 'y': 300, 'solido': [48, 26], 'sombra': 54},
               {'imagem': 'sala204_lixeira.png', 'x': 616, 'y': 132, 'solido': [16, 8], 'sombra': 18},
               {'imagem': 'sala204_papel.png', 'x': 600, 'y': 136, 'sombra': 6},
               {'imagem': 'sala204_planta.png', 'x': 690, 'y': 430, 'solido': [18, 8], 'sombra': 22}]
    vari = ['', '', '', '', '_mochila', '_caderno', '_caderno', '_casaco']
    for ly, y in enumerate((236, 296, 356, 416)):
        for cx in (140, 206, 272, 384, 450, 516):
            v = rnd.choice(vari)
            objetos.append({'imagem': 'sala204_carteira%s.png' % v, 'x': cx + rnd.randint(-3, 3),
                            'y': y + rnd.randint(-2, 2), 'solido': [26, 10], 'sombra': 28})
    fundo(objetos).save(os.path.join(OUT, 'sala_aula.png'))
    caminho = os.path.join(OUT, 'sala_aula.json')
    m = json.load(open(caminho, encoding='utf-8'))
    m['objetos'] = [{k: v for k, v in o.items() if k != 'sombra'} for o in objetos]
    json.dump(m, open(caminho, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print(len(objetos), 'objetos')


if __name__ == '__main__':
    main()

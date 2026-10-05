"""Fundos das cutscenes em visão lateral (palco lateral: !lateral <nome> na cena).

Mesma paleta e mesmo jeito de desenhar dos mapas (estilo_gba). A sala é vista de lado,
na altura das pessoas: parede do fundo + uma faixa de chão. Medida: 480x135
(o jogo mostra em dobro); quem está em pé pisa em y = 126.
Se um fundo tiver lado_<nome>_frente.png, ele vai na frente dos bonecos (banco, por ex.).

    python3 lado_gba.py
"""
import random

from PIL import Image, ImageDraw

from estilo_gba import F16, janela, ln, novo, parede, piso, placa, porta, r, relogio, salvar_fundo
from paleta import P, faixa_sombra, sombrear

W, H = 480, 135
CHAO = 110          # onde a parede encontra o chão
PE = 126            # onde fica o pé de quem está em pé


def quadro(d, x, y, w, h, fundo, rnd):
    r(d, x - 3, y - 3, w + 6, h + 6, 'amarelo')
    r(d, x - 2, y - 2, w + 4, h + 4, 'ferrugem')
    r(d, x, y, w, h, fundo)
    cx = x + w // 2                                   # retrato de um ex-presidente (bem simples)
    r(d, cx - 5, y + 6, 10, 11, 'pele')
    r(d, cx - 5, y + 5, 10, 3, rnd.choice(['preto', 'cinza', 'marrom']))
    r(d, cx - 9, y + 18, 18, h - 18, rnd.choice(['noite', 'preto', 'ardosia']))
    r(d, cx - 1, y + 18, 2, 6, 'branco')
    r(d, x - 3, y + h + 3, w + 6, 1, 'amarelo_c')


def mesa_lado(d, x):
    """Mesa do presidente vista de lado, com o computador e a cadeira vermelha atrás."""
    # cadeira vermelha (encosto alto)
    r(d, x + 70, PE - 52, 12, 36, 'vermelho_e')
    r(d, x + 71, PE - 51, 9, 34, 'vermelho')
    r(d, x + 71, PE - 51, 2, 34, 'rosa')
    r(d, x + 56, PE - 20, 26, 6, 'vermelho_e')
    r(d, x + 57, PE - 20, 24, 2, 'vermelho')
    r(d, x + 67, PE - 14, 3, 10, 'preto')
    r(d, x + 58, PE - 4, 22, 2, 'preto')
    # mesa
    r(d, x, PE - 34, 64, 4, 'marrom')
    r(d, x, PE - 34, 64, 1, 'tijolo')
    r(d, x + 2, PE - 30, 6, 30, 'vinho')
    r(d, x + 56, PE - 30, 6, 30, 'vinho')
    r(d, x + 8, PE - 30, 48, 14, 'marrom')
    r(d, x + 8, PE - 30, 48, 1, 'vinho')
    # monitor
    r(d, x + 18, PE - 56, 22, 16, 'preto')
    r(d, x + 20, PE - 54, 18, 12, 'azul_n')
    r(d, x + 20, PE - 54, 18, 4, 'azul')
    r(d, x + 27, PE - 40, 4, 6, 'noite')
    r(d, x + 22, PE - 36, 14, 2, 'noite')
    # papelada e a placa "PRESIDENTE"
    r(d, x + 44, PE - 37, 12, 3, 'branco')
    r(d, x + 45, PE - 39, 10, 2, 'cinza_c')
    r(d, x + 4, PE - 38, 12, 4, 'amarelo')
    r(d, x + 4, PE - 38, 12, 1, 'amarelo_c')


def planta(d, x):
    r(d, x, PE - 14, 14, 14, 'tijolo')
    r(d, x, PE - 14, 14, 2, 'laranja_c')
    r(d, x + 1, PE - 3, 12, 3, 'marrom')
    for k, (dx, w, h) in enumerate(((-4, 10, 22), (6, 10, 28), (2, 12, 16))):
        y = PE - 14 - h
        r(d, x + dx, y, w, h, ['verde_e', 'verde', 'verde_c'][k % 3])
        r(d, x + dx + 2, y, 2, h, 'verde_c' if k != 2 else 'verde')


def presidencia():
    rnd = random.Random(4)
    im, d = novo(W, H, 'marrom')
    piso(im, d, W, H, 'madeira', chao=CHAO)
    parede(im, d, W, 'madeira', chao=CHAO, emenda=32, risco=32)
    porta(d, 24, 'SAIDA', chao=CHAO)
    placa(im, d, 150, 12, 180, 22, [('PRESIDENCIA', 'amarelo_c')], F16, cor='vinho')
    for k, x in enumerate((112, 168, 224, 280)):
        quadro(d, x, 44, 22, 28, ['azul_n', 'verde_e', 'roxo', 'vermelho_e'][k], rnd)
    janela(im, d, 330, 30, 46, 40, arvore=True)
    relogio(d, 410, 20)
    mesa_lado(d, 380)
    planta(d, 96)
    planta(d, 456)
    # tapete vermelho no meio
    r(d, 120, PE - 2, 200, 4, 'vermelho_e')
    r(d, 120, PE - 2, 200, 1, 'vermelho')
    faixa_sombra(im, 0, CHAO, W, CHAO + 3)
    salvar_fundo(im, 'lado_presidencia')


def banco(d_fundo, d_frente, x, w=84):
    """Banco de praça comprido (de madeira, pés de ferro), encostado na parede do fundo.
    O encosto fica atrás de quem senta; o assento e os pés, na frente."""
    for px in (x + 4, x + w - 7):                      # pés de trás e suporte do encosto
        r(d_fundo, px, PE - 34, 3, 34, 'preto')
    for k, yy in enumerate((PE - 32, PE - 25)):         # duas tábuas do encosto
        r(d_fundo, x, yy, w, 5, 'marrom')
        r(d_fundo, x, yy, w, 1, 'tijolo')
        r(d_fundo, x, yy + 4, w, 1, 'vinho')
    r(d_frente, x - 2, PE - 8, w + 4, 4, 'tijolo')     # assento
    r(d_frente, x - 2, PE - 8, w + 4, 1, 'laranja_c')
    r(d_frente, x - 2, PE - 5, w + 4, 1, 'marrom')
    for px in (x + 2, x + w - 5):                      # pés da frente
        r(d_frente, px, PE - 4, 3, 6, 'preto')
        r(d_frente, px - 1, PE + 1, 5, 1, 'preto')


def arvore(d, x):
    r(d, x - 6, PE - 62, 12, 62, 'marrom')
    r(d, x - 6, PE - 62, 3, 62, 'tijolo')
    r(d, x + 4, PE - 62, 2, 62, 'vinho')
    for (dx, dy, raio, cor) in ((0, -84, 34, 'verde_e'), (-20, -74, 22, 'verde'), (20, -76, 22, 'verde'),
                                (2, -96, 22, 'verde'), (-8, -92, 12, 'verde_c'), (14, -86, 10, 'verde_c')):
        d.ellipse([x + dx - raio, PE + dy - raio * 0.8, x + dx + raio, PE + dy + raio * 0.8], fill=P[cor])
    r(d, x - 24, PE - 1, 48, 2, 'verde_n')


def patio():
    rnd = random.Random(9)
    im, d = novo(W, H, 'creme')
    piso(im, d, W, H, 'pedra', chao=CHAO, semente=7)
    parede(im, d, W, chao=CHAO)
    for x in (40, 150, 380):
        janela(im, d, x, 26, 44, 34, arvore=False)
    placa(im, d, 250, 14, 104, 16, [('CANTINA', 'branco')])
    arvore(d, 112)
    arvore(d, 440)
    frente = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    df = ImageDraw.Draw(frente)
    banco(d, df, 262)
    sombrear(im, 258, PE - 1, 350, PE + 3)
    salvar_fundo(im, 'lado_patio')
    from estilo_gba import OUT
    import os
    frente.save(os.path.join(OUT, 'lado_patio_frente.png'))


if __name__ == '__main__':
    presidencia()
    patio()
    print('fundos laterais ok')

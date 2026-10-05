"""Gera três mapas da Cairu em pixel art: recepção, pátio com cantina e sala de aula.

Mesmo estilo do laboratorio.py (paleta azul e branca). Saída em
projeto/capitulos/mapas/: <mapa>.png (fundo) e <mapa>_<movel>.png (móveis
que o jogo ordena na frente/atrás do personagem).
"""
from PIL import Image, ImageDraw, ImageFont
import os
from laboratorio import C, ret, OUT, monitor_costas, gabinete, cadeira_escritorio

FONTE = os.path.join(os.path.dirname(__file__), '..', 'projeto', 'assets', 'fonte', 'PressStart2P.ttf')
F8 = ImageFont.truetype(FONTE, 8)
F16 = ImageFont.truetype(FONTE, 16)
C.update(grama='#5fae4f', grama_e='#4a9440', grama_c='#7cc66a', pedra='#d3cab8', pedra2='#c6bca8',
         pedra_r='#ab a08c'.replace(' ', ''), tronco='#7a4e26', folha='#3f9a48', folha_e='#2e7a38',
         folha_c='#62c06a', cortica='#c9955a', lousa='#2b3a2e', giz='#e8efe6')


def novo(w, h, cor=(0, 0, 0, 0)):
    im = Image.new('RGBA', (w, h), cor)
    return im, ImageDraw.Draw(im)


def texto(d, x, y, s, cor, fonte=F8):
    d.text((x, y), s, font=fonte, fill=cor)


def piso_ladrilho(d, w, h, y0, c1, c2, grout, t=16):
    for y in range(y0, h, t):
        for x in range(0, w, t):
            ret(d, x, y, t, t, c2 if ((x + y) // t) % 2 else c1)
            d.line([x, y + t - 1, x + t - 1, y + t - 1], fill=grout)
            d.line([x + t - 1, y, x + t - 1, y + t - 1], fill=grout)
            d.point((x + 2, y + 2), fill=C['branco'])


def parede(d, w, altura=104):
    ret(d, 0, 0, w, altura - 46, C['branco'])
    ret(d, 0, altura - 46, w, 42, C['azul'])
    ret(d, 0, altura - 46, w, 2, C['azul_c'])
    ret(d, 0, 0, w, 4, C['navy'])
    ret(d, 0, altura - 6, w, 8, C['navy'])
    ret(d, 0, altura + 2, w, 3, C['rejunte'])


def porta_fundo(d, x, rotulo=None):
    """Porta na parede do fundo (48 de largura, chão em y=98)."""
    ret(d, x, 32, 48, 66, C['madeira_e'])
    ret(d, x + 4, 36, 40, 62, C['madeira'])
    ret(d, x + 8, 42, 32, 16, C['tela_c'])
    ret(d, x + 34, 68, 4, 4, C['amarelo'])
    if rotulo:
        larg = len(rotulo) * 8
        ret(d, x + 24 - larg // 2 - 3, 16, larg + 6, 13, C['navy'])
        texto(d, x + 24 - larg // 2, 19, rotulo, C['branco'])


def relogio(d, x, y):
    d.ellipse([x - 11, y - 11, x + 11, y + 11], fill=C['preto'])
    d.ellipse([x - 9, y - 9, x + 9, y + 9], fill='white')
    d.line([x, y, x, y - 7], fill=C['preto'], width=2)
    d.line([x, y, x + 5, y], fill=C['vermelho'])


def ar_cond(d, x, y):
    ret(d, x - 2, y - 2, 88, 28, C['cinza_e'])
    ret(d, x, y, 84, 24, C['cinza_c'])
    ret(d, x, y, 84, 20, '#fdfdfd')
    for i in range(4):
        d.line([x + 8, y + 14 + i % 2, x + 76, y + 14 + i % 2], fill=C['cinza_c'])
    ret(d, x + 70, y + 4, 6, 3, '#4bd06a')


def janela(d, x, y, w, h):
    ret(d, x - 3, y - 3, w + 6, h + 6, C['cinza_e'])
    ret(d, x, y, w, h, C['tela_c'])
    for i in range(1, 3):
        d.line([x + i * w // 3, y, x + i * w // 3, y + h], fill=C['cinza_e'], width=2)
    d.line([x + 4, y + 4, x + 14, y + 4], fill='white')


def papeis(d, x, y, w, h, n):
    cores = [C['papel'], C['amarelo'], '#a8d4ff', '#ffb07a', C['papel']]
    for i in range(n):
        px = x + 4 + i * (w - 8) // n
        ret(d, px, y + 4 + (i % 2) * 4, 14, 18, cores[i % len(cores)])
        for k in range(3):
            d.line([px + 3, y + 9 + (i % 2) * 4 + k * 4, px + 10, y + 9 + (i % 2) * 4 + k * 4], fill=C['cinza'])
        ret(d, px + 5, y + 3 + (i % 2) * 4, 3, 3, C['vermelho'])


def bordas(d, w, h, esq=None, dir=None, baixo=None):
    """Paredes laterais e de baixo; esq/dir = (y0, y1) da abertura, baixo = (x0, x1)."""
    for x0, gap in ((0, esq), (w - 12, dir)):
        if gap:
            ret(d, x0, 0, 12, gap[0], C['navy'])
            ret(d, x0, gap[1], 12, h - gap[1], C['navy'])
        else:
            ret(d, x0, 0, 12, h, C['navy'])
    if baixo:
        ret(d, 0, h - 8, baixo[0], 8, C['navy'])
        ret(d, baixo[1], h - 8, w - baixo[1], 8, C['navy'])
    else:
        ret(d, 0, h - 8, w, 8, C['navy'])


def salvar(im, nome):
    im.save(os.path.join(OUT, nome + '.png'))


# ================================================================ RECEPÇÃO
def recepcao():
    W, H = 800, 448
    im, d = novo(W, H, C['piso'])
    piso_ladrilho(d, W, H, 104, '#e6eaf3', '#d9dfec', C['rejunte'], 32)
    # tapete azul da entrada até o balcão
    ret(d, 356, 222, 88, H - 222, C['azul_e'])
    ret(d, 360, 226, 80, H - 226, C['azul'])
    for y in range(240, H, 24):
        ret(d, 396, y, 8, 8, C['azul_c'])
    parede(d, W)
    # placa FACULDADE CAIRU
    ret(d, 262, 10, 276, 42, C['navy'])
    ret(d, 266, 14, 268, 34, C['azul_e'])
    texto(d, 280, 23, 'FACULDADE CAIRU', 'white', F16)
    relogio(d, 200, 32)
    # mural de cortiça
    ret(d, 596, 14, 108, 54, C['madeira_e'])
    ret(d, 600, 18, 100, 46, C['cortica'])
    papeis(d, 600, 18, 100, 46, 5)
    porta_fundo(d, 60, 'SALAS')
    # portas de vidro da entrada (embaixo)
    bordas(d, W, H, dir=(256, 344), baixo=(352, 448))
    for x in range(352, 448, 24):
        ret(d, x, H - 10, 24, 10, C['tela_c'])
        d.line([x, H - 10, x, H], fill=C['cinza_e'])
    # tapete da passagem pro pátio
    ret(d, W - 40, 264, 28, 72, C['cinza'])
    salvar(im, 'recepcao')

    # balcão da recepção (quem atende fica atrás: pé 10 px acima do pé do balcão, x = 182 na imagem)
    b, d = novo(224, 40)
    ret(d, 0, 8, 224, 10, C['cinza_c'])            # tampo
    ret(d, 1, 9, 222, 8, C['branco'])
    monitor_costas(d, 193, 1)                      # monitor do lado de quem atende, tela pra ele
    gabinete(d, 211, 4)
    ret(d, 120, 11, 7, 5, C['amarelo'])            # campainha
    ret(d, 122, 10, 3, 2, C['cinza_e'])
    ret(d, 40, 10, 22, 6, C['papel'])              # folhetos
    ret(d, 43, 12, 16, 1, C['azul'])
    ret(d, 80, 11, 10, 5, '#a8d4ff')               # porta-canetas
    ret(d, 0, 18, 224, 22, C['azul'])              # frente (0,85 m)
    ret(d, 0, 18, 224, 2, C['azul_c'])
    ret(d, 0, 36, 224, 4, C['navy'])
    texto(d, 92, 24, 'CAIRU', 'white')
    salvar(b, 'recepcao_balcao')
    salvar(cadeira_escritorio(), 'cadeira_escritorio')

    # sofá de espera (3 lugares)
    s, d = novo(88, 36)
    ret(d, 0, 0, 88, 16, C['azul_e'])
    ret(d, 2, 2, 84, 12, C['azul'])
    ret(d, 0, 14, 88, 14, C['azul_e'])
    for i in range(3):
        ret(d, 3 + i * 28, 16, 26, 9, C['azul_c'])
    ret(d, 4, 28, 3, 8, C['preto'])
    ret(d, 81, 28, 3, 8, C['preto'])
    salvar(s, 'recepcao_sofa')

    # mesinha com revistas
    m, d = novo(44, 24)
    ret(d, 0, 0, 44, 14, C['madeira_e'])
    ret(d, 1, 1, 42, 11, C['madeira'])
    ret(d, 6, 3, 12, 8, '#ffb07a')
    ret(d, 22, 4, 12, 7, '#a8d4ff')
    ret(d, 4, 14, 3, 10, C['madeira_e'])
    ret(d, 37, 14, 3, 10, C['madeira_e'])
    salvar(m, 'recepcao_mesinha')

    # bebedouro (1,1 m)
    e, d = novo(14, 30)
    ret(d, 3, 0, 8, 9, '#a8d4ff')
    ret(d, 4, 1, 3, 6, 'white')
    ret(d, 1, 9, 12, 21, C['cinza_c'])
    ret(d, 2, 10, 10, 19, C['branco'])
    ret(d, 4, 13, 6, 3, C['cinza_e'])
    ret(d, 6, 17, 2, 2, C['tela'])
    salvar(e, 'recepcao_bebedouro')

    # banner do vestibular (2 m)
    v, d = novo(26, 54)
    ret(d, 2, 0, 22, 3, C['cinza_e'])
    ret(d, 3, 3, 20, 45, C['azul'])
    ret(d, 3, 3, 20, 10, C['amarelo'])
    texto(d, 1, 4, 'VEM', C['navy'])
    for k in range(4):
        ret(d, 6, 17 + k * 6, 14, 2, 'white')
    ret(d, 5, 41, 16, 4, C['amarelo'])
    ret(d, 0, 48, 26, 6, C['cinza_e'])
    salvar(v, 'recepcao_banner')


# ================================================================ PÁTIO
def arvore():
    a, d = novo(72, 96)
    ret(d, 30, 56, 12, 40, C['tronco'])
    ret(d, 32, 56, 3, 40, '#94602f')
    for x, y, r, c in ((36, 30, 30, 'folha_e'), (22, 38, 18, 'folha'), (50, 38, 18, 'folha'),
                       (36, 24, 22, 'folha'), (30, 18, 10, 'folha_c'), (46, 30, 8, 'folha_c')):
        d.ellipse([x - r, y - r, x + r, y + r], fill=C[c])
    d.ellipse([22, 90, 50, 96], fill=(0, 0, 0, 50))
    return a


def patio():
    W, H = 864, 480
    im, d = novo(W, H, C['pedra'])
    # piso de pedra (tijolinho)
    for y in range(120, H, 16):
        off = 12 if (y // 16) % 2 else 0
        for x in range(-24, W, 24):
            ret(d, x + off, y, 24, 16, C['pedra2'] if ((x // 24) + (y // 16)) % 3 == 0 else C['pedra'])
            d.line([x + off, y + 15, x + off + 23, y + 15], fill=C['pedra_r'])
            d.line([x + off + 23, y, x + off + 23, y + 15], fill=C['pedra_r'])
    # canteiros de grama
    for x0, y0, w, h in ((620, 200, 220, 120), (12, 392, 180, 80), (640, 380, 212, 92)):
        ret(d, x0, y0, w, h, C['grama'])
        ret(d, x0, y0, w, 3, C['grama_e'])
        for k in range(0, w * h // 180):
            px = x0 + (k * 37) % (w - 4) + 2
            py = y0 + 6 + (k * 23) % (h - 10)
            ret(d, px, py, 2, 3, C['grama_c'] if k % 2 else C['grama_e'])
    # fachada da cantina
    ret(d, 0, 0, W, 76, C['branco'])
    ret(d, 0, 76, W, 40, C['azul'])
    ret(d, 0, 76, W, 2, C['azul_c'])
    ret(d, 0, 0, W, 4, C['navy'])
    ret(d, 0, 112, W, 8, C['navy'])
    # janela de atendimento
    ret(d, 116, 40, 248, 72, C['navy'])
    ret(d, 120, 44, 240, 68, '#3a3f55')
    for s in range(2):                                   # prateleiras com produtos
        y = 54 + s * 22
        ret(d, 124, y + 14, 232, 3, C['madeira'])
        for i in range(14):
            cor = (C['vermelho'], C['amarelo'], '#4bd06a', C['tela'], '#ffb07a')[(i + s) % 5]
            ret(d, 128 + i * 16, y + 2, 10, 12, cor)
    # toldo listrado
    for i in range(16):
        ret(d, 108 + i * 17, 26, 17, 18, C['azul'] if i % 2 else 'white')
    for i in range(16):
        d.polygon([(108 + i * 17, 44), (116 + i * 17, 50), (125 + i * 17, 44)], fill=C['azul'] if i % 2 else 'white')
    ret(d, 160, 6, 160, 20, C['navy'])
    texto(d, 184, 8, 'CANTINA', C['amarelo'], F16)
    # quadro do cardápio
    ret(d, 382, 26, 132, 70, C['madeira_e'])
    ret(d, 386, 30, 124, 62, C['lousa'])
    texto(d, 394, 36, 'CARDAPIO', C['amarelo'])
    for i, linha in enumerate(('CAFE    3', 'SALGADO 6', 'SUCO    5', 'PF     18')):
        texto(d, 394, 50 + i * 10, linha, C['giz'])
    # banheiros
    for x, rot in ((610, 'M'), (700, 'F')):
        ret(d, x, 40, 52, 72, C['cinza_e'])
        ret(d, x + 4, 44, 44, 68, C['cinza_c'])
        ret(d, x + 18, 52, 16, 14, C['navy'])
        texto(d, x + 22, 55, rot, 'white')
        ret(d, x + 38, 80, 4, 4, C['cinza_e'])
    ret(d, 606, 22, 150, 13, C['navy'])
    texto(d, 645, 25, 'BANHEIROS', 'white')
    bordas(d, W, H, esq=(256, 344))
    ret(d, 12, 264, 26, 72, C['cinza'])                  # tapete da porta
    salvar(im, 'patio')

    # balcão da cantina com vitrine
    b, d = novo(264, 44)
    ret(d, 0, 0, 264, 18, C['cinza_c'])
    ret(d, 1, 1, 262, 15, C['branco'])
    ret(d, 20, -2, 120, 16, '#bfe3ff')                    # vitrine de salgados
    ret(d, 22, 0, 116, 12, '#dff1ff')
    for i in range(9):
        ret(d, 26 + i * 12, 4, 9, 7, '#d98b3a' if i % 2 else '#e8b04a')
    ret(d, 176, 0, 30, 14, C['cinza_e'])                 # caixa registradora
    ret(d, 180, 2, 22, 5, '#4bd06a')
    ret(d, 220, 2, 8, 12, C['vermelho'])                 # garrafas
    ret(d, 232, 2, 8, 12, '#4bd06a')
    ret(d, 0, 16, 264, 28, C['azul'])
    ret(d, 0, 16, 264, 2, C['azul_c'])
    ret(d, 0, 40, 264, 4, C['navy'])
    salvar(b, 'patio_balcao')

    # máquina de lanches (1,8 m)
    m, d = novo(28, 50)
    ret(d, 0, 0, 28, 50, C['vermelho'])
    ret(d, 1, 1, 26, 48, '#b02e2e')
    ret(d, 3, 4, 16, 32, '#2a3550')
    for r in range(4):
        for c in range(3):
            ret(d, 4 + c * 5, 6 + r * 7, 4, 5, (C['amarelo'], '#4bd06a', C['tela'], '#ffb07a')[(r + c) % 4])
    ret(d, 21, 6, 4, 9, C['cinza_c'])
    ret(d, 3, 39, 16, 6, C['preto'])
    salvar(m, 'patio_maquina')

    # mesa redonda com 4 banquinhos
    t, d = novo(60, 46)
    for x, y in ((6, 4), (42, 4)):
        d.ellipse([x, y, x + 12, y + 8], fill=C['azul_e'])
    d.ellipse([8, 8, 52, 32], fill=C['cinza_e'])
    d.ellipse([8, 6, 52, 30], fill='white')
    d.ellipse([12, 9, 48, 27], fill='#f1f3fb')
    ret(d, 28, 30, 4, 10, C['cinza_e'])
    for x, y in ((2, 30), (46, 30)):
        d.ellipse([x, y, x + 12, y + 8], fill=C['azul'])
        ret(d, x + 5, y + 8, 2, 6, C['cinza_e'])
    ret(d, 22, 12, 8, 6, '#d98b3a')                      # salgado
    ret(d, 34, 14, 5, 7, C['vermelho'])                  # copo
    salvar(t, 'patio_mesa')

    salvar(arvore(), 'patio_arvore')

    # banco de praça
    s, d = novo(64, 30)
    for k in range(3):
        ret(d, 0, 2 + k * 5, 64, 4, C['madeira'] if k % 2 else C['madeira_c'])
    ret(d, 0, 18, 64, 6, C['madeira'])
    ret(d, 4, 18, 4, 12, C['cinza_e'])
    ret(d, 56, 18, 4, 12, C['cinza_e'])
    salvar(s, 'patio_banco')


# ================================================================ SALA DE AULA
def sala_aula():
    W, H = 720, 448
    im, d = novo(W, H, C['piso'])
    piso_ladrilho(d, W, H, 104, '#e8ebf3', '#dde2ee', C['rejunte'])
    parede(d, W)
    # quadro branco grande
    ret(d, 176, 10, 288, 76, C['cinza_e'])
    ret(d, 180, 14, 280, 66, '#fbfbf7')
    texto(d, 192, 22, 'AULA 3: CUSTOS', C['azul_e'])
    d.line([192, 36, 330, 36], fill=C['vermelho'])
    for k in range(3):
        d.line([192, 46 + k * 9, 300 + k * 40, 46 + k * 9], fill='#3a8a4a')
    d.rectangle([380, 40, 440, 72], outline=C['azul_e'])
    d.line([380, 56, 440, 56], fill=C['azul_e'])
    ret(d, 176, 86, 288, 4, C['cinza'])
    ret(d, 200, 84, 10, 3, C['vermelho'])                # pincéis
    ret(d, 214, 84, 10, 3, C['azul'])
    relogio(d, 120, 34)
    janela(d, 20, 16, 72, 40)
    ar_cond(d, 504, 14)
    porta_fundo(d, 640, '204')
    bordas(d, W, H)
    salvar(im, 'sala_aula')

    # mesa do professor
    m, d = novo(92, 56)
    ret(d, 56, 0, 18, 12, C['preto'])                    # cadeira
    ret(d, 57, 1, 16, 9, '#3a3f55')
    ret(d, 0, 12, 92, 18, C['madeira_c'])
    ret(d, 1, 13, 90, 15, C['madeira'])
    ret(d, 10, 2, 26, 16, C['cinza_e'])                  # notebook
    ret(d, 12, 4, 22, 11, C['tela'])
    ret(d, 50, 16, 16, 10, C['papel'])
    ret(d, 70, 14, 10, 8, C['vermelho'])                 # caneca
    ret(d, 0, 28, 92, 28, C['madeira_e'])
    ret(d, 4, 30, 84, 22, C['madeira'])
    d.line([46, 30, 46, 52], fill=C['madeira_e'])
    salvar(m, 'sala_aula_mesa_prof')

    # carteira universitária (cadeira com braço)
    c, d = novo(30, 42)
    ret(d, 3, 4, 22, 12, C['azul_e'])                    # assento (de costas pra quem olha)
    ret(d, 4, 5, 20, 9, C['azul_c'])
    ret(d, 18, 0, 12, 14, C['cinza_c'])                  # prancheta
    ret(d, 19, 1, 10, 12, C['branco'])
    ret(d, 21, 3, 6, 1, C['cinza'])
    ret(d, 4, 14, 20, 16, C['azul_e'])                   # encosto
    ret(d, 5, 15, 18, 13, C['azul'])
    ret(d, 5, 30, 2, 12, C['cinza_e'])
    ret(d, 21, 30, 2, 12, C['cinza_e'])
    salvar(c, 'sala_aula_carteira')


# ================================================================ CORREDOR
PORTAS_CORREDOR = (('204', 104), ('LAB', 280), ('NUCLEO', 456), ('PRESIDENCIA', 632))


def corredor():
    W, H = 800, 270
    im, d = novo(W, H, C['piso'])
    piso_ladrilho(d, W, H, 104, '#efe6d2', '#e2d6bd', '#cbbd9f')
    parede(d, W)
    for rot, x in PORTAS_CORREDOR:
        porta_fundo(d, x, rot)
    for x in (184, 360, 536):                            # cartazes entre as portas
        ret(d, x, 30, 56, 44, C['madeira_e'])
        ret(d, x + 3, 33, 50, 38, C['cortica'])
        papeis(d, x + 3, 33, 50, 38, 3)
    janela(d, 20, 22, 60, 36)
    janela(d, 716, 22, 60, 36)
    bordas(d, W, H, esq=(150, 250))
    ret(d, 12, 154, 22, 92, C['cinza'])
    salvar(im, 'corredor')


# ================================================================ NÚCLEO DE INFORMÁTICA
def pc_velho(d, x, y, k):
    """Computador velho (monitor de tubo bege, 16 x 14) com defeitos variados."""
    bege, bege_e = '#d8cfb4', '#a89f84'
    ret(d, x, y, 16, 13, bege_e)
    ret(d, x + 1, y + 1, 14, 11, bege)
    tela = ('#2a3550', '#15171f', '#3a5a3a', '#2a3550')[k % 4]
    ret(d, x + 3, y + 2, 10, 8, tela)
    if k % 3 == 0:                                       # tela rachada
        d.line([x + 4, y + 3, x + 9, y + 9], fill=C['cinza_c'])
        d.line([x + 9, y + 4, x + 6, y + 8], fill=C['cinza_c'])
    if k % 4 == 1:
        ret(d, x + 12, y + 10, 2, 1, C['vermelho'])
    ret(d, x + 5, y + 13, 6, 2, bege_e)


def nucleo():
    W, H = 720, 448
    im, d = novo(W, H, C['piso'])
    piso_ladrilho(d, W, H, 104, C['piso'], C['piso2'], C['rejunte'])
    parede(d, W)
    relogio(d, 640, 30)
    ar_cond(d, 300, 12)
    ret(d, 40, 14, 80, 30, C['navy'])
    texto(d, 48, 20, 'NUCLEO', 'white')
    texto(d, 48, 31, 'DE TI', C['amarelo'])
    bordas(d, W, H, baixo=(320, 384))
    ret(d, 320, H - 10, 64, 10, C['cinza'])              # capacho da entrada
    for x in range(322, 382, 4):
        d.line([x, H - 9, x, H - 1], fill=C['cinza_e'])
    salvar(im, 'nucleo')

    # armário grande de parede a parede (2,6 m), cheio de computadores quebrados
    a, d = novo(696, 68)
    ret(d, 0, 0, 696, 68, C['madeira_e'])
    ret(d, 3, 3, 690, 62, '#5a3a1e')
    k = 0
    for prat in range(3):
        y = 4 + prat * 20
        ret(d, 3, y + 17, 690, 3, C['madeira'])
        x = 8
        while x < 674:
            if k % 5 == 3:                               # gabinete deitado / peças
                ret(d, x, y + 9, 20, 8, '#cfc6aa')
                ret(d, x + 2, y + 11, 6, 1, C['cinza_e'])
                ret(d, x + 15, y + 12, 3, 3, '#4bd06a' if k % 2 else C['vermelho'])
                x += 24
            elif k % 7 == 5:                             # emaranhado de cabos
                for c in range(4):
                    d.arc([x + c * 2, y + 5, x + 14 + c * 2, y + 17], 180, 360,
                          fill=(C['preto'], C['cinza'], C['tela'], C['amarelo'])[c])
                x += 22
            else:
                pc_velho(d, x, y + 2, k)
                x += 20
            k += 1
    ret(d, 0, 64, 696, 4, C['navy'])
    salvar(a, 'nucleo_armario')

    # divisória fina no meio da sala, cheia de anotações e cartazes
    v, d = novo(440, 52)
    ret(d, 0, 0, 440, 4, C['cinza_e'])
    ret(d, 0, 4, 440, 40, '#f1f3f8')
    ret(d, 0, 40, 440, 8, C['azul'])
    ret(d, 0, 48, 440, 4, C['navy'])
    for x in range(0, 440, 110):
        ret(d, x, 4, 2, 44, C['cinza_c'])
    cores = [C['amarelo'], C['papel'], '#ffb07a', '#a8d4ff', C['papel'], '#b6f0a8', C['amarelo']]
    x, i = 6, 0
    while x < 430:
        w = 12 + (i * 5) % 9
        h = 12 + (i * 7) % 14
        y = 6 + (i * 11) % (32 - h + 6)
        ret(d, x, y, w, h, cores[i % len(cores)])
        for kk in range(0, h - 6, 4):
            d.line([x + 2, y + 4 + kk, x + w - 3, y + 4 + kk], fill=C['cinza'])
        ret(d, x + w // 2 - 1, y - 1, 3, 3, (C['vermelho'], C['azul'])[i % 2])
        x += w + 3 + (i % 3) * 2
        i += 1
    salvar(v, 'nucleo_divisoria')

    # balcão branco de parede a parede (deixa a portinhola livre no canto).
    # O Nicão fica atrás, em x = 196 na imagem, com o monitor do lado e a tela virada pra ele.
    b, d = novo(604, 40)
    ret(d, 0, 8, 604, 10, C['cinza_c'])                  # tampo
    ret(d, 1, 9, 602, 8, C['branco'])
    monitor_costas(d, 207, 1)
    gabinete(d, 226, 4)
    ret(d, 300, 10, 14, 6, C['papel'])                   # fichas de chamado
    ret(d, 318, 11, 10, 5, '#ffb07a')
    ret(d, 420, 4, 18, 8, '#3a3f4e')                     # notebook aberto pra conserto (tampa de costas)
    ret(d, 421, 5, 16, 6, '#cfc6aa')
    ret(d, 418, 12, 22, 4, '#a89f84')
    ret(d, 470, 11, 4, 5, C['vermelho'])                 # chave de fenda
    ret(d, 471, 9, 2, 3, C['cinza'])
    ret(d, 500, 11, 9, 5, C['amarelo'])                  # caixinha de parafusos
    ret(d, 0, 18, 604, 22, C['branco'])                  # frente (0,85 m)
    ret(d, 0, 18, 604, 2, C['cinza_c'])
    ret(d, 0, 32, 604, 6, C['azul'])
    ret(d, 0, 38, 604, 2, C['navy'])
    salvar(b, 'nucleo_balcao')

    # portinhola (aberta, encostada), da altura do balcão
    pt, d = novo(8, 30)
    ret(d, 0, 0, 8, 30, C['cinza_c'])
    ret(d, 1, 1, 6, 28, C['branco'])
    ret(d, 0, 22, 8, 8, C['azul'])
    ret(d, 2, 10, 4, 3, C['cinza_e'])
    salvar(pt, 'nucleo_portinhola')


# ================================================================ PRESIDÊNCIA
def retrato(d, x, y, k):
    pele = ('#e0b48a', '#c08a5e', '#8a5a3a', '#f0c8a0')[k % 4]
    cabelo = ('#e8e8e8', '#3a2a1e', '#9a9a9a', '#1a1a1a', '#d8d0c0')[k % 5]
    fundo = ('#4a2a2a', '#2a3a4a', '#3a4a2a')[k % 3]
    ret(d, x, y, 30, 38, '#b8902e')
    ret(d, x + 2, y + 2, 26, 34, '#e8c45a')
    ret(d, x + 4, y + 4, 22, 30, fundo)
    ret(d, x + 9, y + 9, 12, 14, pele)                   # rosto
    ret(d, x + 8, y + 7, 14, 4 if k % 3 else 2, cabelo)
    ret(d, x + 11, y + 14, 2, 2, C['preto'])
    ret(d, x + 17, y + 14, 2, 2, C['preto'])
    if k % 2:
        ret(d, x + 11, y + 19, 8, 2, cabelo)             # bigode
    ret(d, x + 6, y + 25, 18, 9, C['preto'])             # paletó
    ret(d, x + 13, y + 25, 4, 6, 'white')
    ret(d, x + 14, y + 26, 2, 5, C['vermelho'])


def presidencia():
    W, H = 640, 448
    im, d = novo(W, H, '#3d2414')
    # assoalho de madeira escura
    for y in range(104, H, 8):
        off = (y // 8 * 37) % 64
        ret(d, 0, y, W, 8, '#4a2c18' if (y // 8) % 2 else '#432714')
        d.line([0, y + 7, W, y + 7], fill='#2e1a0c')
        for x in range(-off, W, 64):
            d.line([x, y, x, y + 7], fill='#2e1a0c')
            d.point((x + 10, y + 3), fill='#5a3820')
    # tapete vermelho até a cadeira
    ret(d, 264, 150, 112, 290, '#6e1418')
    ret(d, 268, 154, 104, 282, '#9a1e24')
    d.rectangle([276, 162, 363, 427], outline='#d8a83a')
    # parede de madeira escura com lambri
    ret(d, 0, 0, W, 104, '#5a3520')
    for x in range(0, W, 32):
        d.line([x, 4, x, 98], fill='#4a2a18')
    ret(d, 0, 58, W, 3, '#d8a83a')
    ret(d, 0, 0, W, 4, '#2a170a')
    ret(d, 0, 98, W, 8, '#2a170a')
    # galeria de presidentes
    k = 0
    for x in list(range(16, 250, 38)) + list(range(392, 600, 38)):
        retrato(d, x, 10 + (k % 2) * 4, k)
        k += 1
    # retrato grande do atual, acima da cadeira
    ret(d, 284, 6, 72, 52, '#b8902e')
    ret(d, 287, 9, 66, 46, '#e8c45a')
    ret(d, 290, 12, 60, 40, '#2a1a3a')
    ret(d, 310, 18, 20, 20, '#d8a880')
    ret(d, 308, 15, 24, 6, '#5a5a5a')
    ret(d, 302, 38, 36, 14, C['preto'])
    ret(d, 318, 38, 4, 10, C['vermelho'])
    bordas(d, W, H, baixo=(288, 352))
    for x0 in (0, W - 12):
        ret(d, x0, 0, 12, H, '#2a170a')
    ret(d, 0, H - 8, 288, 8, '#2a170a')
    ret(d, 352, H - 8, W - 352, 8, '#2a170a')
    ret(d, 288, H - 10, 64, 10, '#6e1418')
    salvar(im, 'presidencia')

    # cadeira vermelha do presidente (1,5 m de encosto, maior que uma cadeira normal, mas cabe na sala)
    c, d = novo(30, 40)
    ret(d, 4, 0, 22, 26, '#d8a83a')
    ret(d, 5, 1, 20, 24, '#9a1e24')
    ret(d, 8, 4, 14, 18, '#b8262c')
    for yy in (8, 15):
        for xx in (10, 14, 18):
            ret(d, xx, yy, 1, 1, '#6e1418')
    ret(d, 0, 18, 6, 14, '#9a1e24')                      # braços
    ret(d, 24, 18, 6, 14, '#9a1e24')
    ret(d, 0, 18, 6, 2, '#d8a83a')
    ret(d, 24, 18, 6, 2, '#d8a83a')
    ret(d, 5, 25, 20, 7, '#b8262c')                      # assento
    ret(d, 5, 31, 20, 2, '#6e1418')
    ret(d, 6, 33, 3, 7, '#2a170a')
    ret(d, 21, 33, 3, 7, '#2a170a')
    salvar(c, 'presidencia_cadeira')

    # mesa do presidente, na frente da cadeira (monitor de costas, tela pra ele)
    m, d = novo(76, 40)
    ret(d, 0, 10, 76, 12, '#7a4e26')                     # tampo
    ret(d, 1, 11, 74, 10, '#94602f')
    monitor_costas(d, 46, 3)
    ret(d, 8, 13, 14, 6, C['papel'])                     # papéis
    ret(d, 10, 14, 9, 1, C['cinza'])
    ret(d, 26, 16, 12, 3, '#d8a83a')                     # plaquinha PRESIDENTE
    ret(d, 27, 17, 10, 1, '#2a170a')
    ret(d, 64, 12, 6, 7, '#e8e0d0')                      # cafezinho
    ret(d, 0, 22, 76, 18, '#5a3520')                     # frente (0,75 m)
    ret(d, 2, 24, 72, 14, '#6e4226')
    ret(d, 0, 22, 76, 1, '#d8a83a')
    ret(d, 34, 28, 8, 4, '#d8a83a')                      # brasão
    salvar(m, 'presidencia_mesa_pres')

    # três mesas de museu, cada uma com coisas velhas diferentes
    for n in range(3):
        m, d = novo(96, 52)
        ret(d, 0, 18, 96, 20, '#7a4e26')
        ret(d, 1, 19, 94, 17, '#94602f')
        ret(d, 0, 36, 96, 8, '#5a3520')
        ret(d, 4, 44, 5, 8, '#3d2414')
        ret(d, 87, 44, 5, 8, '#3d2414')
        if n == 0:                                       # máquina de escrever, telefone antigo, livros
            ret(d, 8, 10, 30, 18, '#2b2f3a')
            ret(d, 10, 6, 26, 6, C['papel'])
            ret(d, 12, 20, 22, 5, '#5a5a5a')
            ret(d, 48, 14, 18, 12, C['preto'])
            ret(d, 46, 10, 22, 5, C['preto'])
            d.ellipse([52, 16, 62, 24], fill='#d8a83a')
            for i, cor in enumerate(('#6e1418', '#2a3a6a', '#3a5a2a')):
                ret(d, 72, 20 - i * 4, 18, 4, cor)
        elif n == 1:                                     # globo, troféu, vaso
            d.ellipse([8, 0, 32, 24], fill='#3a6ab0')
            ret(d, 12, 6, 8, 6, '#4a8a3a')
            ret(d, 22, 12, 6, 6, '#4a8a3a')
            ret(d, 18, 24, 4, 4, '#d8a83a')
            ret(d, 42, 6, 16, 12, '#d8a83a')
            ret(d, 46, 18, 8, 6, '#d8a83a')
            ret(d, 44, 24, 12, 4, '#7a4e26')
            ret(d, 70, 8, 14, 20, '#e8e0d0')
            ret(d, 72, 4, 10, 4, '#e8e0d0')
            ret(d, 72, 14, 10, 2, '#2a3a6a')
        else:                                            # gramofone, relógio de mesa, pergaminho
            ret(d, 8, 18, 22, 10, '#5a3520')
            d.polygon([(18, 18), (6, 0), (34, 0)], fill='#d8a83a')
            d.polygon([(18, 18), (12, 4), (28, 4)], fill='#b8902e')
            ret(d, 44, 6, 18, 22, '#7a4e26')
            d.ellipse([46, 8, 60, 22], fill='#f0e6c8')
            d.line([53, 15, 53, 10], fill=C['preto'])
            ret(d, 70, 18, 20, 8, '#f0e6c8')
            ret(d, 68, 17, 4, 10, '#d8c8a0')
            ret(d, 88, 17, 4, 10, '#d8c8a0')
        salvar(m, 'presidencia_mesa%d' % (n + 1))

    # dois armários com coisas velhas (portas de vidro, 2,6 m)
    for n in range(2):
        a, d = novo(56, 68)
        ret(d, 0, 0, 56, 68, '#3d2414')
        ret(d, 2, 2, 52, 64, '#5a3520')
        ret(d, 0, 0, 56, 4, '#d8a83a')
        for prat in range(3):
            y = 7 + prat * 19
            ret(d, 5, y, 46, 17, '#2a1a10')
            ret(d, 5, y + 15, 46, 2, '#7a4e26')
            for i in range(4):
                x = 7 + i * 11
                tipo = (prat + i + n) % 5
                if tipo == 0:
                    ret(d, x, y + 5, 7, 10, '#d8a83a')              # taça
                elif tipo == 1:
                    ret(d, x, y + 3, 6, 12, ('#6e1418', '#2a3a6a')[i % 2])  # livro
                elif tipo == 2:
                    d.ellipse([x, y + 6, x + 7, y + 13], fill='#e8e0d0')    # prato
                elif tipo == 3:
                    ret(d, x + 2, y + 4, 4, 11, '#5a8a6a')          # garrafa
                else:
                    ret(d, x, y + 8, 8, 7, '#b8902e')               # caixinha
        for x in (5, 29):                                # reflexo do vidro
            d.line([x + 3, 10, x + 10, 30], fill=(255, 255, 255, 60))
        d.line([28, 6, 28, 64], fill='#d8a83a')
        salvar(a, 'presidencia_armario%d' % (n + 1))


if __name__ == '__main__':
    # Os mapas agora são gerados no estilo GBA (paleta única). Este arquivo só guarda os desenhos
    # antigos dos móveis, que os geradores novos reaproveitam. Rode:  python3 gerar_mapas.py
    print('Use: python3 gerar_mapas.py  (este arquivo é só a base dos móveis)')

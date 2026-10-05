"""Gera o mapa do Laboratório de Informática (Cairu) em pixel art.

Saída em projeto/capitulos/mapas/: laboratorio.png (fundo)
e os móveis separados (laboratorio_*.png), que o jogo ordena na frente/atrás do personagem.
Referência: fonte_mapas/ref_nucleo_informatica.png (sem a catraca, a pedido do Breno) (visão superior).
"""
from PIL import Image, ImageDraw
import os

OUT = os.path.join(os.path.dirname(__file__), '..', 'projeto', 'capitulos', 'mapas')
W, H = 928, 448
PAREDE = 104

C = dict(
    azul='#2a49c9', azul_e='#1b2f8f', azul_c='#4d6be0', navy='#16204f', branco='#f4f6fb',
    piso='#e9edf6', piso2='#e2e7f2', rejunte='#cdd4e6', madeira='#a8713d', madeira_e='#7a4e26',
    madeira_c='#c98f52', preto='#15171f', vidro='#232c48', vidro_c='#34406a', cinza='#9aa1b5',
    cinza_e='#6b7288', cinza_c='#c4c9d6', tela='#5fa8ff', tela_c='#a8d4ff', verde='#2f8a3a',
    verde_c='#49b555', vaso='#b5562f', vermelho='#d03a3a', amarelo='#ffd34e', papel='#fbfbf2',
    sombra=(0, 0, 0, 40),
)


def ret(d, x, y, w, h, cor):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=cor)


def contorno(d, x, y, w, h, cor):
    d.rectangle([x, y, x + w - 1, y + h - 1], outline=cor)


# ---------------------------------------------------------------- escala
# Medida de tudo: o personagem tem uns 18 x 45 px (1,75 m), então 1 m = 26 px.
# Balcão de atendimento: frente de 22 px (0,85 m) + tampo de 10 px; quem fica atrás
# pisa 8 px acima do pé do balcão e aparece da cintura pra cima.
# Mesa: frente de 18 px. Monitor: 16 x 12 (+ pé). Gabinete: 6 x 12. Cadeira: 14 px de largura.
def monitor_costas(d, x, y):
    """Monitor visto por trás (a tela vira pra quem está atrás do balcão). x, y = canto de cima."""
    ret(d, x, y, 16, 11, C['preto'])
    ret(d, x + 1, y + 1, 14, 9, '#3a3f4e')
    for k in range(3):
        d.line([x + 4, y + 3 + k * 2, x + 11, y + 3 + k * 2], fill='#2b2f3a')   # respiro
    ret(d, x + 6, y + 11, 4, 3, C['preto'])                                     # pé
    ret(d, x + 4, y + 13, 8, 2, '#3a3f4e')
    d.point((x + 14, y + 9), fill='#4bd06a')                                    # luzinha


def monitor_frente(d, x, y):
    """Monitor de frente (tela pra baixo, pra quem senta do lado de cá da mesa)."""
    ret(d, x, y, 16, 11, C['preto'])
    ret(d, x + 1, y + 1, 14, 8, C['tela'])
    ret(d, x + 2, y + 2, 5, 1, C['tela_c'])
    ret(d, x + 6, y + 11, 4, 2, C['preto'])
    ret(d, x + 4, y + 12, 8, 2, '#3a3f4e')


def gabinete(d, x, y):
    ret(d, x, y, 6, 12, C['preto'])
    ret(d, x + 1, y + 1, 4, 1, '#3a3f4e')
    d.point((x + 2, y + 3), fill='#4bd06a')


def cadeira_escritorio():
    """Cadeira de escritório vista de frente (fica atrás do balcão, do lado de quem atende)."""
    im = Image.new('RGBA', (16, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ret(d, 2, 0, 12, 12, C['preto'])            # encosto
    ret(d, 3, 1, 10, 10, '#3a3f4e')
    ret(d, 0, 11, 16, 5, C['preto'])            # assento
    ret(d, 1, 12, 14, 3, '#4a5060')
    ret(d, 7, 16, 2, 6, C['preto'])             # coluna
    ret(d, 2, 22, 12, 2, C['preto'])            # base
    for x in (1, 7, 13):
        ret(d, x, 24, 2, 2, '#2b2f3a')          # rodinhas
    return im


# ---------------------------------------------------------------- fundo
def fundo():
    im = Image.new('RGBA', (W, H), C['piso'])
    d = ImageDraw.Draw(im)
    # piso branco em ladrilhos 16x16
    for y in range(PAREDE, H, 16):
        for x in range(0, W, 16):
            if ((x + y) // 16) % 2:
                ret(d, x, y, 16, 16, C['piso2'])
            d.line([x, y + 15, x + 15, y + 15], fill=C['rejunte'])
            d.line([x + 15, y, x + 15, y + 15], fill=C['rejunte'])
            d.point((x + 2, y + 2), fill=C['branco'])
    # parede: branca em cima, azul embaixo
    ret(d, 0, 0, W, 58, C['branco'])
    ret(d, 0, 58, W, 42, C['azul'])
    ret(d, 0, 58, W, 2, C['azul_c'])
    ret(d, 0, 0, W, 4, C['navy'])
    ret(d, 0, 98, W, 8, C['navy'])            # rodapé / bancada da parede do fundo
    ret(d, 0, 106, W, 3, C['rejunte'])
    # janelas (pretas)
    for x in (192, 536):
        ret(d, x - 3, 8, 150, 40, C['cinza_e'])
        ret(d, x, 11, 144, 34, C['preto'])
        for i in range(3):
            ret(d, x + 3 + i * 47, 14, 44, 28, C['vidro'])
            d.line([x + 6 + i * 47, 16, x + 14 + i * 47, 16], fill=C['vidro_c'])
    # ar-condicionado
    ret(d, 386, 10, 88, 28, C['cinza_e'])
    ret(d, 388, 12, 84, 24, C['cinza_c'])
    ret(d, 388, 12, 84, 20, '#fdfdfd')
    for i in range(6):
        d.line([396, 26 + (i % 2), 464, 26 + (i % 2)], fill=C['cinza_c'])
    ret(d, 458, 16, 6, 3, '#4bd06a')
    # cartazes perto do balcão
    for x, cor in ((28, C['amarelo']), (50, C['papel']), (72, '#ffb07a')):
        ret(d, x, 16, 18, 26, cor)
        for k in range(4):
            d.line([x + 3, 21 + k * 5, x + 14, 21 + k * 5], fill=C['cinza'])
        ret(d, x + 7, 15, 3, 3, C['vermelho'])
    # armários de parede (madeira) sobre a faixa azul
    for x, w in ((60, 126), (352, 162), (612, 164)):
        ret(d, x, 52, w, 44, C['madeira_e'])
        ret(d, x + 2, 54, w - 4, 40, C['madeira'])
        ret(d, x + 2, 54, w - 4, 2, C['madeira_c'])
        portas = w // 40
        for i in range(1, portas):
            px = x + i * w // portas
            d.line([px, 56, px, 92], fill=C['madeira_e'])
        for i in range(portas):
            cx = x + (i + 0.5) * w / portas
            ret(d, int(cx) - 4, 72, 2, 5, C['amarelo'])
            ret(d, int(cx) + 2, 72, 2, 5, C['amarelo'])
    # nicho com materiais azuis
    ret(d, 192, 56, 60, 40, C['navy'])
    for i, cor in enumerate((C['azul_c'], C['cinza_c'], C['azul_c'], C['amarelo'], C['azul_c'])):
        ret(d, 196 + i * 11, 64, 9, 28, cor)
    # planta no canto
    ret(d, 8, 82, 18, 14, C['vaso'])
    for px, py, pw, ph in ((4, 60, 10, 24), (12, 54, 10, 30), (20, 62, 10, 22)):
        ret(d, px, py, pw, ph, C['verde'])
    ret(d, 15, 58, 3, 16, C['verde_c'])
    # paredes laterais e de baixo (com a abertura da entrada)
    ret(d, 0, 0, 4, H, C['navy'])
    ret(d, W - 12, 0, 12, H, C['navy'])
    ret(d, W - 14, 0, 2, H, C['azul_e'])
    ret(d, 0, H - 8, 840, 8, C['navy'])
    ret(d, 904, H - 8, W - 904, 8, C['navy'])
    ret(d, 840, H - 10, 64, 10, C['cinza'])          # capacho da entrada
    for x in range(842, 902, 4):
        d.line([x, H - 9, x, H - 1], fill=C['cinza_e'])
    return im


# ---------------------------------------------------------------- móveis
def balcao():
    """Balcão do João: ele fica atrás (pé 8 px acima do pé do balcão, x = 60 na imagem)
    e o monitor fica do lado dele, de costas pra quem chega."""
    im = Image.new('RGBA', (100, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # tampo
    ret(d, 0, 8, 100, 10, C['cinza_c'])
    ret(d, 1, 9, 98, 8, C['branco'])
    monitor_costas(d, 71, 1)
    gabinete(d, 89, 4)
    ret(d, 6, 10, 12, 6, C['papel'])                    # papéis
    ret(d, 7, 11, 9, 1, C['cinza'])
    ret(d, 24, 11, 9, 5, C['preto'])                    # telefone
    ret(d, 25, 10, 7, 2, C['cinza_e'])
    ret(d, 40, 12, 6, 4, C['amarelo'])                  # post-its
    # frente do balcão (0,85 m)
    ret(d, 0, 18, 100, 22, C['branco'])
    ret(d, 0, 18, 100, 2, C['cinza_c'])
    ret(d, 0, 32, 100, 6, C['azul'])
    ret(d, 0, 38, 100, 2, C['navy'])
    return im


def pc_fileira():
    """Fileira de 5 computadores: telas viradas pra baixo, cadeiras do lado de cá (de costas pra câmera)."""
    im = Image.new('RGBA', (304, 54), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ret(d, 0, 8, 304, 16, C['cinza_c'])                 # tampo
    ret(d, 1, 9, 302, 13, C['branco'])
    ret(d, 0, 24, 304, 14, C['cinza'])                  # frente da mesa (some atrás das cadeiras)
    ret(d, 0, 24, 304, 1, C['cinza_e'])
    for i in range(5):
        x = 6 + i * 60
        if i:
            d.line([x - 6, 10, x - 6, 22], fill=C['cinza_c'])
        monitor_frente(d, x + 20, 0)
        gabinete(d, x + 42, 4)
        ret(d, x + 19, 17, 18, 3, C['cinza_e'])         # teclado
        ret(d, x + 39, 17, 3, 3, C['preto'])            # mouse
        # cadeira azul (de costas pra quem olha)
        cx = x + 21
        ret(d, cx, 30, 14, 11, C['azul_e'])
        ret(d, cx + 1, 31, 12, 8, C['azul'])
        ret(d, cx - 1, 41, 16, 3, C['azul_e'])
        ret(d, cx + 6, 44, 2, 6, C['preto'])
        ret(d, cx + 1, 50, 12, 2, C['preto'])
        for xx in (cx, cx + 6, cx + 12):
            ret(d, xx, 52, 2, 2, '#2b2f3a')
    return im


def mesa_lucas():
    """Mesinha do Lucas: ele senta do lado esquerdo, de lado, e digita olhando pra direita.
    O monitor fica de perfil, com a tela virada pra ele. Ponto (0, 0) da imagem = (Lucas + 7, Lucas - 38)."""
    im = Image.new('RGBA', (30, 37), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ret(d, 0, 13, 30, 8, C['madeira_c'])                # tampo
    ret(d, 1, 14, 28, 6, C['madeira'])
    ret(d, 0, 21, 30, 16, C['madeira_e'])               # frente
    ret(d, 2, 23, 26, 12, C['madeira'])
    ret(d, 13, 28, 4, 2, C['madeira_c'])                # puxador
    ret(d, 18, 0, 3, 13, C['preto'])                    # monitor de perfil
    ret(d, 18, 1, 1, 10, C['tela_c'])                   # brilho da tela virada pro Lucas
    ret(d, 21, 2, 3, 8, C['preto'])                     # traseira
    ret(d, 21, 3, 2, 6, '#3a3f4e')
    ret(d, 19, 13, 2, 3, C['preto'])                    # pé
    ret(d, 16, 16, 7, 1, '#3a3f4e')
    ret(d, 1, 16, 9, 2, C['cinza_e'])                   # teclado
    ret(d, 11, 16, 2, 2, C['preto'])                    # mouse
    ret(d, 25, 14, 3, 4, C['vermelho'])                 # latinha
    return im


def cadeira_lucas():
    """A cadeira que vem desenhada nos quadros do Lucas sentado, pra ela continuar lá quando ele levanta.
    Ponto (0, 0) da imagem = (Lucas - 15, Lucas - 26)."""
    folha = Image.open(os.path.join(os.path.dirname(__file__), '..', 'projeto', 'assets',
                                    'personagens', 'lucas', 'acoes2.png')).convert('RGBA')
    q = folha.crop((3 * 64, 6 * 64, 4 * 64, 7 * 64)).load()
    im = Image.new('RGBA', (12, 28), (0, 0, 0, 0))
    p = im.load()
    cores = {(22, 18, 24), (52, 56, 66), (34, 36, 44)}
    for y in range(35, 63):
        for x in range(17, 28):
            if q[x, y][3] and q[x, y][:3] in cores:
                p[x - 17, y - 35] = q[x, y]
    for y in range(51, 56):
        p[11, y - 35] = (22, 18, 24, 255)               # fecha a ponta do assento
    return im


def armario_ti():
    im = Image.new('RGBA', (48, 62), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ret(d, 6, 0, 12, 6, C['azul'])                      # caixas em cima
    ret(d, 22, 1, 12, 5, C['vermelho'])
    ret(d, 0, 6, 48, 56, C['navy'])
    ret(d, 2, 8, 44, 52, C['preto'])
    cores = [C['cinza_c'], C['azul_c'], C['amarelo'], C['cinza'], C['tela'], C['vermelho']]
    for s in range(4):
        y = 9 + s * 13
        ret(d, 2, y + 11, 44, 2, C['navy'])
        x = 4
        k = s
        while x < 43:
            w = min(4 + (k * 3) % 5, 45 - x)
            ret(d, x, y + 3, w, 8, cores[k % len(cores)])
            x += w + 1
            k += 1
    return im


def armario_mat():
    im = Image.new('RGBA', (40, 58), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ret(d, 10, 0, 18, 7, C['verde'])                    # caixa verde em cima
    ret(d, 12, 2, 14, 2, C['verde_c'])
    ret(d, 0, 7, 40, 51, C['madeira_e'])
    ret(d, 2, 9, 36, 47, C['madeira'])
    ret(d, 2, 9, 36, 2, C['madeira_c'])
    d.line([20, 11, 20, 54], fill=C['madeira_e'])
    ret(d, 16, 30, 2, 6, C['amarelo'])
    ret(d, 22, 30, 2, 6, C['amarelo'])
    return im


def divisoria():
    im = Image.new('RGBA', (792, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ret(d, 0, 0, 792, 6, C['navy'])
    ret(d, 0, 6, 792, 30, C['branco'])
    ret(d, 0, 6, 792, 1, C['cinza_c'])
    ret(d, 0, 36, 792, 18, C['azul'])
    ret(d, 0, 36, 792, 2, C['azul_c'])
    ret(d, 0, 54, 792, 6, C['navy'])
    for x in range(0, 792, 132):                        # emendas da divisória
        d.line([x, 6, x, 53], fill=C['cinza_c'])
    papeis = [(250, C['papel']), (268, C['amarelo']), (410, C['papel']),
              (560, C['papel']), (578, '#a8d4ff'), (596, C['papel']), (710, '#ffb07a')]
    for x, cor in papeis:
        ret(d, x, 10, 15, 21, cor)
        for k in range(3):
            d.line([x + 3, 15 + k * 5, x + 11, 15 + k * 5], fill=C['cinza'])
        ret(d, x + 6, 9, 3, 3, C['vermelho'])
    return im


def cadeiras_espera():
    im = Image.new('RGBA', (36, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for x in (2, 20):
        ret(d, x, 0, 14, 10, C['azul_e'])               # encosto
        ret(d, x + 1, 1, 12, 8, C['azul'])
        ret(d, x - 1, 10, 16, 6, C['azul_e'])           # assento
        ret(d, x, 11, 14, 4, C['azul_c'])
        ret(d, x + 1, 16, 2, 8, C['preto'])
        ret(d, x + 11, 16, 2, 8, C['preto'])
    return im


if __name__ == '__main__':
    # O laboratório agora é gerado por laboratorio_gba.py (estilo GBA). Rode:  python3 gerar_mapas.py
    print('Use: python3 gerar_mapas.py  (este arquivo é só a base dos móveis)')

"""Gera os ícones pixel art 24x24 do santuário (melhorias, conquistas, modos, visuais, estruturas e portais).

Uso: python gerar.py   (grava em ../../projeto/assets/v2/icones_santuario/<id>.png e a prancha _previa.png)
Arte própria, desenhada por código: sem arte de terceiros. Paleta de v2/paleta.gd. Contorno escuro de 1 px gerado da silhueta.
Para um id novo, acrescente uma função em ICONES; quem não tiver cai no ícone "generico".
"""

import math
import os
import sys

from PIL import Image, ImageDraw

N = 24
AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.join(AQUI, "..", "..", "projeto", "assets", "v2", "icones_santuario")

# Cores (v2/paleta.gd e tons próximos)
CONTORNO = (10, 8, 20, 255)
VIDA = (185, 33, 45)
VIDA_CLARA = (240, 100, 100)
OURO = (255, 219, 107)
OURO_ESC = (200, 150, 50)
ALMA = (204, 168, 255)
ALMA_ESC = (130, 90, 200)
AZUL = (74, 163, 217)
AZUL_CLARO = (160, 215, 250)
VERDE = (140, 242, 158)
VERDE_ESC = (50, 140, 80)
CINZA = (204, 209, 230)
CINZA_MED = (153, 153, 179)
CINZA_ESC = (92, 87, 115)
MARROM = (140, 90, 50)
MARROM_ESC = (90, 55, 35)
LARANJA = (255, 140, 51)
VERMELHO = (255, 84, 77)
CIANO = (128, 242, 255)
BRANCO = (255, 255, 255)


class Tela:
    def __init__(self):
        self.im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def poly(self, pts, cor):
        self.d.polygon(pts, fill=cor + (255,))

    def rect(self, x0, y0, x1, y1, cor):
        self.d.rectangle([x0, y0, x1, y1], fill=cor + (255,))

    def elip(self, x0, y0, x1, y1, cor):
        self.d.ellipse([x0, y0, x1, y1], fill=cor + (255,))

    def linha(self, pts, cor, w=1):
        self.d.line(pts, fill=cor + (255,), width=w)

    def arco(self, caixa, ini, fim, cor, w=1):
        self.d.arc(caixa, ini, fim, fill=cor + (255,), width=w)

    def px(self, x, y, cor):
        self.d.point((x, y), fill=cor + (255,))

    def final(self):
        a = self.im.split()[3].point(lambda v: 255 if v > 0 else 0)
        px = a.load()
        out = self.im.copy()
        po = out.load()
        for y in range(N):
            for x in range(N):
                if px[x, y]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < N and 0 <= yy < N and px[xx, yy]:
                        po[x, y] = CONTORNO
                        break
        return out


def vida(t):
    t.elip(3, 4, 11, 12, VIDA)
    t.elip(12, 4, 20, 12, VIDA)
    t.poly([(3, 9), (20, 9), (11.5, 21)], VIDA)
    t.rect(5, 7, 18, 10, VIDA)
    t.rect(5, 6, 8, 7, VIDA_CLARA)
    t.px(6, 5, BRANCO)
    t.px(5, 6, VIDA_CLARA)
    t.px(7, 5, VIDA_CLARA)


def dano(t):
    t.poly([(18, 2), (21, 2), (21, 5), (9, 17), (6, 14)], CINZA)
    t.poly([(18, 2), (19, 2), (8, 15), (6, 14)], BRANCO)
    t.poly([(4, 13), (10, 19), (8, 21), (2, 15)], OURO)
    t.poly([(3, 18), (6, 21), (3, 22)], MARROM)
    t.px(8, 19, OURO_ESC)


def velocidade(t):
    t.poly([(10, 3), (16, 3), (16, 12), (21, 15), (21, 20), (10, 20)], MARROM)
    t.rect(10, 3, 16, 5, MARROM_ESC)
    t.rect(10, 18, 21, 20, CINZA_MED)
    t.rect(11, 6, 12, 10, (190, 130, 80))
    for y in (7, 11, 15):
        t.linha([(1, y), (6, y)], AZUL_CLARO)
    t.linha([(3, 9), (7, 9)], BRANCO)


def folego(t):
    t.linha([(3, 8), (14, 8)], AZUL_CLARO, 2)
    t.arco([10, 3, 19, 11], 270, 90, AZUL_CLARO, 2)
    t.linha([(3, 13), (17, 13)], AZUL, 2)
    t.arco([13, 12, 21, 20], 270, 90, AZUL, 2)
    t.linha([(5, 18), (13, 18)], BRANCO, 2)


def treino(t):
    t.rect(8, 11, 15, 13, CINZA_MED)
    t.rect(4, 6, 7, 18, CINZA)
    t.rect(16, 6, 19, 18, CINZA)
    t.rect(2, 9, 3, 15, CINZA_MED)
    t.rect(20, 9, 21, 15, CINZA_MED)
    t.rect(4, 6, 5, 18, BRANCO)
    t.rect(16, 6, 17, 18, BRANCO)
    t.px(4, 17, CINZA_ESC)


def ima(t):
    t.arco([3, 3, 20, 20], 180, 360, VERMELHO, 5)
    t.rect(3, 11, 7, 19, VERMELHO)
    t.rect(16, 11, 20, 19, VERMELHO)
    t.rect(3, 16, 7, 19, CINZA)
    t.rect(16, 16, 20, 19, CINZA)
    t.px(7, 5, VIDA_CLARA)
    t.px(5, 8, VIDA_CLARA)
    t.px(5, 22, ALMA)
    t.px(18, 22, ALMA)
    t.px(11, 21, ALMA)
    t.px(12, 22, ALMA)


def almas(t):
    t.elip(5, 8, 18, 21, ALMA)
    t.poly([(11, 2), (16, 11), (7, 11)], ALMA)
    t.poly([(5, 18), (11, 23), (18, 18)], ALMA_ESC)
    t.elip(8, 12, 10, 15, (30, 20, 60))
    t.elip(13, 12, 15, 15, (30, 20, 60))
    t.px(8, 12, BRANCO)
    t.px(13, 12, BRANCO)
    t.rect(7, 9, 8, 10, BRANCO)


def raridade(t):
    t.poly([(7, 3), (16, 3), (21, 9), (11.5, 22), (2, 9)], (89, 168, 255))
    t.poly([(2, 9), (21, 9), (11.5, 22)], (60, 120, 220))
    t.poly([(7, 3), (11, 9), (2, 9)], AZUL_CLARO)
    t.poly([(16, 3), (11, 9), (7, 3)], (200, 230, 255))
    t.px(4, 8, BRANCO)
    t.px(8, 4, BRANCO)


def rolagem(t):
    t.rect(4, 4, 19, 19, CINZA)
    t.rect(4, 4, 19, 5, BRANCO)
    t.rect(18, 5, 19, 19, CINZA_MED)
    t.rect(4, 18, 19, 19, CINZA_MED)
    for x, y in ((6, 6), (14, 6), (10, 10), (6, 14), (14, 14)):
        t.rect(x, y, x + 2, y + 2, VIDA)


def sobreviva_5min(t):
    t.rect(4, 2, 19, 4, MARROM)
    t.rect(4, 20, 19, 22, MARROM)
    t.poly([(6, 5), (17, 5), (12, 12), (17, 19), (6, 19), (11, 12)], AZUL_CLARO)
    t.poly([(7, 5), (16, 5), (12, 9)], (110, 160, 210))
    t.poly([(7, 19), (16, 19), (12, 14)], OURO)
    t.rect(11, 12, 12, 14, OURO)


def derrota_chefe(t):
    t.poly([(2, 2), (6, 6), (5, 10), (2, 8)], OURO)
    t.poly([(21, 2), (17, 6), (18, 10), (21, 8)], OURO)
    t.elip(5, 4, 18, 16, CINZA)
    t.rect(8, 14, 15, 21, CINZA)
    t.rect(8, 19, 15, 21, CINZA_MED)
    t.rect(8, 9, 10, 12, (20, 10, 30))
    t.rect(13, 9, 15, 12, (20, 10, 30))
    t.px(9, 10, VERMELHO)
    t.px(14, 10, VERMELHO)
    t.rect(11, 13, 12, 14, CINZA_ESC)
    for x in (9, 11, 13):
        t.px(x, 19, CINZA_ESC)
        t.px(x, 20, CINZA_ESC)


def combo_50(t):
    t.poly([(12, 1), (17, 8), (20, 13), (18, 19), (12, 22), (6, 19), (4, 13), (8, 9), (9, 5)], LARANJA)
    t.poly([(12, 8), (16, 14), (15, 19), (12, 21), (9, 19), (8, 14)], OURO)
    t.poly([(12, 14), (14, 17), (12, 20), (10, 17)], (255, 250, 220))
    t.px(7, 13, VERMELHO)
    t.px(18, 15, VERMELHO)


def pesadelo(t):
    t.poly([(2, 2), (8, 6), (5, 11)], (150, 40, 190))
    t.poly([(21, 2), (15, 6), (18, 11)], (150, 40, 190))
    t.elip(4, 5, 19, 20, (110, 30, 140))
    t.rect(7, 18, 16, 21, (110, 30, 140))
    t.poly([(6, 10), (10, 12), (6, 14)], VERMELHO)
    t.poly([(17, 10), (13, 12), (17, 14)], VERMELHO)
    t.px(7, 12, OURO)
    t.px(16, 12, OURO)
    t.rect(8, 17, 15, 18, (20, 10, 30))
    for x in (9, 11, 13):
        t.px(x, 18, BRANCO)


def rastro_katana(t):
    t.poly([(21, 2), (15, 4), (9, 8), (5, 13), (3, 20), (6, 17), (11, 13), (16, 9), (20, 6)], CIANO)
    t.poly([(21, 2), (15, 5), (10, 9), (6, 14), (4, 19), (9, 13), (15, 8)], AZUL_CLARO)
    t.poly([(21, 2), (17, 5), (12, 9), (8, 13)], BRANCO)
    t.px(3, 22, CIANO)
    t.px(8, 21, AZUL_CLARO)
    t.px(1, 16, CIANO)


def estatuas(t):
    t.rect(4, 19, 19, 22, CINZA_MED)
    t.rect(6, 16, 17, 19, CINZA)
    t.elip(9, 2, 14, 7, CINZA)
    t.rect(8, 7, 15, 16, CINZA)
    t.poly([(8, 8), (4, 14), (6, 15), (9, 11)], CINZA)
    t.poly([(15, 8), (19, 14), (17, 15), (14, 11)], CINZA)
    t.rect(8, 7, 9, 16, BRANCO)
    t.rect(14, 10, 15, 16, CINZA_MED)
    t.px(10, 4, CINZA_ESC)
    t.px(13, 4, CINZA_ESC)


def altar(t):
    t.rect(3, 12, 20, 15, CINZA)
    t.rect(3, 12, 20, 12, BRANCO)
    t.rect(5, 15, 18, 22, CINZA_MED)
    t.rect(5, 15, 6, 22, CINZA)
    t.rect(9, 17, 14, 22, CINZA_ESC)
    t.poly([(11.5, 2), (15, 8), (14, 11), (9, 11), (8, 8)], LARANJA)
    t.poly([(11.5, 6), (13, 10), (10, 10)], OURO)
    t.px(11, 8, BRANCO)


def codice(t):
    t.poly([(2, 5), (11, 7), (11, 21), (2, 19)], (150, 70, 90))
    t.poly([(21, 5), (12, 7), (12, 21), (21, 19)], (150, 70, 90))
    t.poly([(3, 6), (10, 8), (10, 19), (3, 17)], (245, 230, 190))
    t.poly([(20, 6), (13, 8), (13, 19), (20, 17)], (245, 230, 190))
    for y in (10, 12, 14, 16):
        t.linha([(4, y - 1), (9, y + 1)], MARROM_ESC)
        t.linha([(14, y + 1), (19, y - 1)], MARROM_ESC)
    t.poly([(11, 2), (13, 2), (13, 8), (12, 7), (11, 8)], OURO)


def portal_floresta(t):
    t.rect(10, 15, 13, 22, MARROM)
    t.elip(3, 2, 20, 14, VERDE_ESC)
    t.elip(6, 7, 17, 17, VERDE_ESC)
    t.elip(5, 3, 14, 10, (80, 190, 100))
    t.elip(7, 4, 11, 7, VERDE)
    t.px(15, 12, (30, 100, 60))
    t.px(8, 13, (30, 100, 60))


def portal_laboratorio(t):
    t.rect(9, 2, 14, 4, CINZA)
    t.rect(10, 4, 13, 9, (200, 235, 245))
    t.poly([(10, 9), (13, 9), (20, 20), (20, 22), (3, 22), (3, 20)], (200, 235, 245))
    t.poly([(7, 15), (16, 15), (20, 20), (20, 22), (3, 22), (3, 20)], (60, 190, 200))
    t.px(9, 18, BRANCO)
    t.px(14, 17, BRANCO)
    t.px(12, 12, CIANO)
    t.px(11, 6, BRANCO)


def portal_cidade(t):
    t.rect(2, 10, 8, 22, CINZA_ESC)
    t.rect(9, 3, 16, 22, CINZA_MED)
    t.rect(17, 8, 22, 22, CINZA_ESC)
    for x in (10, 13):
        for y in range(5, 20, 3):
            t.rect(x, y, x + 1, y + 1, OURO)
    for y in range(12, 20, 3):
        t.px(4, y, OURO)
        t.px(6, y, (110, 110, 140))
        t.px(19, y - 2, OURO)
        t.px(21, y - 2, OURO)
    t.rect(9, 3, 16, 3, CINZA)


def portal_medio(t):
    t.rect(4, 10, 19, 22, CINZA_MED)
    for x in (4, 8, 12, 16):
        t.rect(x, 6, x + 2, 10, CINZA_MED)
    t.rect(4, 10, 19, 11, CINZA)
    t.poly([(9, 22), (9, 16), (11.5, 13), (14, 16), (14, 22)], (40, 30, 50))
    t.px(6, 14, CINZA_ESC)
    t.px(17, 14, CINZA_ESC)


def generico(t):
    t.elip(3, 3, 20, 20, CINZA_ESC)
    t.rect(10, 15, 13, 17, BRANCO)
    t.arco([8, 5, 16, 13], 180, 80, BRANCO, 2)
    t.rect(11, 12, 12, 13, BRANCO)


ICONES = {
    "vida": vida,
    "dano": dano,
    "velocidade": velocidade,
    "folego": folego,
    "treino": treino,
    "ima": ima,
    "almas": almas,
    "raridade": raridade,
    "rolagem": rolagem,
    "sobreviva_5min": sobreviva_5min,
    "derrota_chefe": derrota_chefe,
    "combo_50": combo_50,
    "pesadelo": pesadelo,
    "rastro_katana": rastro_katana,
    "estatuas": estatuas,
    "altar": altar,
    "codice": codice,
    "portal_floresta": portal_floresta,
    "portal_laboratorio": portal_laboratorio,
    "portal_cidade": portal_cidade,
    "portal_medio": portal_medio,
    "generico": generico,
}


def main():
    os.makedirs(SAIDA, exist_ok=True)
    imgs = []
    for nome, f in ICONES.items():
        t = Tela()
        f(t)
        im = t.final()
        im.save(os.path.join(SAIDA, nome + ".png"))
        imgs.append(im)
    # prancha de prévia ampliada 6x (fundo escuro do jogo), 6 por linha
    esc, cols = 6, 6
    lin = math.ceil(len(imgs) / cols)
    cel = N * esc + 12
    pr = Image.new("RGBA", (cols * cel, lin * cel), (18, 17, 26, 255))
    for i, im in enumerate(imgs):
        g = im.resize((N * esc, N * esc), Image.NEAREST)
        pr.alpha_composite(g, ((i % cols) * cel + 6, (i // cols) * cel + 6))
    pr.save(os.path.join(AQUI, "_previa.png"))
    print(len(imgs), "icones em", os.path.normpath(SAIDA))


if __name__ == "__main__":
    sys.exit(main())

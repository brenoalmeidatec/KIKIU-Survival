"""Pátio com a cantina no estilo GBA (igual à Sala 204). Mesmas posições e colisões de antes.
A parede da cantina é mais alta (o chão começa em y = 118).
    python3 patio_gba.py
"""
import os

import novos_mapas
from estilo_gba import (F16, OUT, bordas, capacho, carregar, gravar, grama, ln, movel_gba, novo, parede,
                        piso, r, salvar_fundo, sombras, texto, texto_centro, trocar_enfeites)
from paleta import faixa_sombra

W, H = 864, 480
CHAO = 118
MOVEIS = ('patio_balcao', 'patio_maquina', 'patio_mesa', 'patio_arvore', 'patio_banco')


def cantina(im, d):
    r(d, 112, 36, 256, CHAO - 44, 'noite')            # vão de atendimento
    r(d, 116, 40, 248, CHAO - 48, 'ardosia')
    faixa_sombra(im, 116, 40, 364, 52, 2)
    cores = ('vermelho', 'amarelo', 'verde_c', 'azul', 'areia', 'rosa', 'ciano')
    for s in range(2):                                 # prateleiras com produtos
        y = 54 + s * 22
        for i in range(14):
            cor = cores[(i * 3 + s) % len(cores)]
            r(d, 128 + i * 16, y + 2, 10, 12, cor)
            r(d, 128 + i * 16, y + 2, 10, 2, 'branco' if cor not in ('amarelo', 'areia') else 'amarelo_c')
            r(d, 128 + i * 16 + 8, y + 4, 2, 10, 'noite')
        r(d, 124, y + 14, 232, 3, 'tijolo')
        r(d, 124, y + 14, 232, 1, 'areia_e')
    for i in range(16):                                # toldo listrado
        cor = 'azul_n' if i % 2 else 'branco'
        r(d, 108 + i * 17, 26, 17, 16, cor)
        d.polygon([(108 + i * 17, 42), (116 + i * 17, 48), (124 + i * 17, 42)], fill='#124e89' if i % 2 else '#ffffff')
    r(d, 108, 26, 272, 1, 'cinza_c')
    faixa_sombra(im, 112, 49, 368, 56, 1)
    r(d, 160, 4, 160, 20, 'noite')                     # letreiro
    r(d, 162, 6, 156, 16, 'azul_n')
    texto_centro(d, 240, 8, 'CANTINA', 'amarelo', F16)


def cardapio(im, d):
    r(d, 382, 26, 132, 70, 'marrom')
    r(d, 382, 26, 132, 1, 'tijolo')
    r(d, 386, 30, 124, 62, 'verde_n')
    texto(d, 394, 36, 'CARDAPIO', 'amarelo')
    for i, linha in enumerate(('CAFE    3', 'SALGADO 6', 'SUCO    5', 'PF     18')):
        texto(d, 394, 50 + i * 10, linha, 'branco')
    faixa_sombra(im, 382, 96, 514, 100)


def banheiros(im, d):
    r(d, 606, 24, 150, 13, 'noite')
    texto_centro(d, 681, 27, 'BANHEIROS', 'branco')
    for x, rot in ((610, 'M'), (700, 'F')):
        r(d, x, CHAO - 74, 52, 74, 'cinza_e')
        r(d, x + 4, CHAO - 70, 44, 70, 'cinza_c')
        r(d, x + 4, CHAO - 70, 1, 70, 'branco')
        r(d, x + 18, CHAO - 62, 16, 14, 'noite')
        texto(d, x + 22, CHAO - 59, rot, 'branco')
        r(d, x + 38, CHAO - 36, 4, 4, 'cinza_e')
        r(d, x - 2, CHAO, 56, 2, 'cinza_e')


def main():
    novos_mapas.patio()
    for nome in MOVEIS:
        movel_gba(os.path.join(OUT, nome + '.png'))
    m = carregar('patio')
    trocar_enfeites(m)
    im, d = novo(W, H, 'creme')
    piso(im, d, W, H, 'pedra', chao=CHAO, semente=7)
    for k, (x0, y0, w, h) in enumerate(((620, 200, 220, 120), (12, 392, 180, 80), (640, 380, 212, 92))):
        grama(im, d, x0, y0, w, h, semente=k + 3)
    parede(im, d, W, chao=CHAO)
    cantina(im, d)
    cardapio(im, d)
    banheiros(im, d)
    bordas(im, d, W, H, esq=(256, 344), chao=CHAO)
    capacho(d, 12, 264, 26, 72)
    sombras(im, m['objetos'], {'patio_arvore.png': 30})
    salvar_fundo(im, 'patio')
    gravar('patio', m)
    print('patio ok')


if __name__ == '__main__':
    main()

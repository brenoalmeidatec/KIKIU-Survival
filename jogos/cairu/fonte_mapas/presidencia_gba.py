"""Presidência no estilo GBA (igual à Sala 204, com madeira escura e dourado).
Mesmas posições e colisões de antes.
    python3 presidencia_gba.py
"""
import os

import novos_mapas
from estilo_gba import (OUT, bordas, carregar, gravar, movel_gba, novo, parede, piso, r, salvar_fundo,
                        sombras, trocar_enfeites)
from paleta import faixa_sombra

W, H = 640, 448
MOVEIS = ('presidencia_cadeira', 'presidencia_mesa_pres', 'presidencia_mesa1', 'presidencia_mesa2',
          'presidencia_mesa3', 'presidencia_armario1', 'presidencia_armario2')


def tapete(d):
    r(d, 264, 150, 112, H - 158, 'vinho')
    r(d, 268, 154, 104, H - 162, 'vermelho_e')
    r(d, 268, 154, 104, 1, 'vermelho')
    d.rectangle([276, 162, 363, H - 16], outline='#feae34')
    for y in range(176, H - 24, 28):                 # losangos dourados
        d.polygon([(320, y - 4), (324, y), (320, y + 4), (316, y)], fill='#feae34')


def galeria(im, d):
    k = 0
    for x in list(range(16, 250, 38)) + list(range(392, 600, 38)):
        novos_mapas.retrato(d, x, 10 + (k % 2) * 4, k)
        faixa_sombra(im, x, 10 + (k % 2) * 4 + 38, x + 30, 10 + (k % 2) * 4 + 41)
        k += 1
    # retrato grande do atual, acima da cadeira
    r(d, 284, 6, 72, 48, 'laranja')
    r(d, 287, 9, 66, 42, 'amarelo')
    r(d, 287, 9, 66, 1, 'amarelo_c')
    r(d, 290, 12, 60, 36, 'roxo')
    r(d, 310, 18, 20, 20, 'pele')
    r(d, 308, 15, 24, 6, 'cinza_e')
    r(d, 313, 25, 3, 2, 'preto')
    r(d, 324, 25, 3, 2, 'preto')
    r(d, 302, 38, 36, 10, 'preto')
    r(d, 318, 38, 4, 8, 'vermelho')
    faixa_sombra(im, 284, 54, 356, 58)


def main():
    novos_mapas.presidencia()
    for nome in MOVEIS:
        movel_gba(os.path.join(OUT, nome + '.png'))
    m = carregar('presidencia')
    trocar_enfeites(m)
    im, d = novo(W, H, 'marrom')
    piso(im, d, W, H, 'madeira')
    tapete(d)
    parede(im, d, W, 'madeira', emenda=32, risco=32)
    galeria(im, d)
    bordas(im, d, W, H, baixo=(288, 352), cor='preto', luz='vinho')
    r(d, 288, H - 10, 64, 10, 'vinho')
    r(d, 290, H - 9, 60, 8, 'vermelho_e')
    sombras(im, m['objetos'])
    salvar_fundo(im, 'presidencia')
    gravar('presidencia', m)
    print('presidencia ok')


if __name__ == '__main__':
    main()

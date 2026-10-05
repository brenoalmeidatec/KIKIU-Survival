"""Recepção no estilo GBA (igual à Sala 204). Mesmas posições, colisões e portas de antes.
    python3 recepcao_gba.py
"""
import os

import novos_mapas
from estilo_gba import (F16, OUT, bordas, capacho, carregar, folhas_das_portas, gravar, ln, movel_gba,
                        mural, novo, parede, piso, placa, porta, portas_vidro, r, relogio, salvar_fundo,
                        sombras, trocar_enfeites)

W, H = 800, 448
MOVEIS = ('recepcao_balcao', 'recepcao_sofa', 'recepcao_mesinha', 'recepcao_bebedouro',
          'recepcao_banner', 'cadeira_escritorio')


def tapete(d):
    r(d, 356, 222, 88, H - 222, 'noite')
    r(d, 359, 225, 82, H - 225, 'azul_n')
    r(d, 359, 225, 82, 1, 'azul')
    for y in range(240, H - 8, 24):
        r(d, 396, y, 8, 8, 'azul')
        r(d, 396, y, 8, 1, 'ciano')
    for x in (362, 437):                            # franja dourada
        for y in range(228, H - 8, 4):
            d.point((x, y), fill='#feae34')


def main():
    novos_mapas.recepcao()                          # móveis no desenho antigo (mesma escala)...
    for nome in MOVEIS:                             # ...passados pro estilo novo
        movel_gba(os.path.join(OUT, nome + '.png'))
    m = carregar('recepcao')
    trocar_enfeites(m)

    im, d = novo(W, H, 'cinza_c')
    piso(im, d, W, H, 'frio', semente=11)
    tapete(d)
    parede(im, d, W)
    placa(im, d, 262, 10, 276, 40, [('FACULDADE CAIRU', 'branco')], F16)
    relogio(d, 200, 32)
    mural(im, d, 600, 18, 100, 46, 5)
    folha = porta(d, 60, 'SALAS')
    bordas(im, d, W, H, dir=(256, 344), baixo=(352, 448))
    portas_vidro(d, 352, 448, H)
    capacho(d, W - 40, 264, 28, 72)
    sombras(im, m['objetos'], {'cadeira_escritorio.png': 0})
    salvar_fundo(im, 'recepcao')

    folhas_das_portas(m, {'corredor': folha})
    gravar('recepcao', m)
    print('recepcao ok')


if __name__ == '__main__':
    main()

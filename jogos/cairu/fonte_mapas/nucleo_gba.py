"""Núcleo de Informática no estilo GBA (igual à Sala 204). Mesmas posições e colisões de antes.
    python3 nucleo_gba.py
"""
import os

import novos_mapas
from estilo_gba import (OUT, ar_cond, bordas, capacho, carregar, gravar, movel_gba, novo, parede, piso,
                        placa, relogio, salvar_fundo, sombras, trocar_enfeites)

W, H = 720, 448
MOVEIS = ('nucleo_armario', 'nucleo_divisoria', 'nucleo_balcao', 'nucleo_portinhola')


def main():
    novos_mapas.nucleo()
    for nome in MOVEIS:
        movel_gba(os.path.join(OUT, nome + '.png'))
    m = carregar('nucleo')
    trocar_enfeites(m)
    im, d = novo(W, H, 'cinza_c')
    piso(im, d, W, H, 'frio', semente=31)
    parede(im, d, W)
    placa(im, d, 40, 14, 80, 30, [('NUCLEO', 'branco'), ('DE TI', 'amarelo')])
    ar_cond(im, d, 300, 12)
    relogio(d, 640, 30)
    bordas(im, d, W, H, baixo=(320, 384))
    capacho(d, 320, H - 10, 64, 10)
    sombras(im, m['objetos'], {'nucleo_portinhola.png': 10})
    salvar_fundo(im, 'nucleo')
    gravar('nucleo', m)
    print('nucleo ok')


if __name__ == '__main__':
    main()

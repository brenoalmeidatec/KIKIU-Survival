"""Laboratório de Informática no estilo GBA (igual à Sala 204). Mesmas posições e colisões de antes.
    python3 laboratorio_gba.py
"""
import os

import laboratorio as antigo
from estilo_gba import (OUT, ar_cond, bordas, capacho, carregar, cartazes, gravar, janela_escura, ln, movel_gba,
                        novo, parede, piso, r, salvar_fundo, sombras, trocar_enfeites)
from paleta import P, faixa_sombra

W, H = 928, 448
MOVEIS = ('balcao', 'pcs', 'armario_ti', 'armario_mat', 'divisoria', 'cadeiras', 'mesa_lucas')


def armario_parede(im, d, x, w):
    """Armário suspenso de madeira em cima do lambri."""
    r(d, x, 52, w, 44, 'marrom')
    r(d, x + 2, 54, w - 4, 40, 'tijolo')
    r(d, x + 2, 54, w - 4, 2, 'areia_e')
    portas = w // 40
    for i in range(1, portas):
        px = x + i * w // portas
        ln(d, px, 56, px, 92, 'marrom')
        ln(d, px + 1, 56, px + 1, 92, 'areia_e')
    for i in range(portas):
        cx = int(x + (i + 0.5) * w / portas)
        r(d, cx - 4, 72, 2, 5, 'amarelo')
        r(d, cx + 2, 72, 2, 5, 'amarelo')
    r(d, x, 96, w, 2, 'vinho')
    faixa_sombra(im, x, 98, x + w, 101)


def nicho(d):
    r(d, 192, 56, 60, 40, 'noite')
    r(d, 192, 56, 60, 2, 'ardosia')
    for i, cor in enumerate(('azul', 'cinza_c', 'azul', 'amarelo', 'azul')):
        r(d, 196 + i * 11, 64, 9, 28, cor)
        r(d, 196 + i * 11, 64, 9, 1, 'branco' if cor != 'amarelo' else 'amarelo_c')


def planta_canto(d):
    r(d, 8, 82, 18, 14, 'ferrugem')
    r(d, 8, 82, 18, 2, 'laranja_c')
    for px, py, pw, ph, cor in ((4, 60, 10, 24, 'verde_e'), (12, 54, 10, 30, 'verde'), (20, 62, 10, 22, 'verde_e')):
        d.ellipse([px, py, px + pw, py + ph], fill=P[cor])
    r(d, 15, 58, 2, 14, 'verde')


def main():
    for nome, f in (('balcao', antigo.balcao), ('pcs', antigo.pc_fileira), ('armario_ti', antigo.armario_ti),
                    ('armario_mat', antigo.armario_mat), ('divisoria', antigo.divisoria),
                    ('cadeiras', antigo.cadeiras_espera), ('mesa_lucas', antigo.mesa_lucas)):
        f().save(os.path.join(OUT, 'laboratorio_%s.png' % nome))
    for nome in MOVEIS:
        movel_gba(os.path.join(OUT, 'laboratorio_%s.png' % nome))
    m = carregar('laboratorio')
    trocar_enfeites(m)
    im, d = novo(W, H, 'cinza_c')
    piso(im, d, W, H, 'frio', semente=21)
    parede(im, d, W)
    for x in (192, 536):
        janela_escura(im, d, x, 10, 144, 30)
    ar_cond(im, d, 388, 12)
    cartazes(d, 28, 16)
    for x, w in ((60, 126), (352, 162), (612, 164)):
        armario_parede(im, d, x, w)
    nicho(d)
    planta_canto(d)
    bordas(im, d, W, H, baixo=(840, 904), larg_esq=4)
    capacho(d, 840, H - 10, 64, 10)
    sombras(im, m['objetos'], {'laboratorio_cadeira_lucas.png': 0, 'laboratorio_divisoria.png': 0})
    salvar_fundo(im, 'laboratorio')
    gravar('laboratorio', m)
    print('laboratorio ok')


if __name__ == '__main__':
    main()

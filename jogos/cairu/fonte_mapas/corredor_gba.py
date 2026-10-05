"""Corredor no estilo GBA (igual à Sala 204). Mesmas portas e posições de antes.
    python3 corredor_gba.py
"""
from estilo_gba import (bordas, capacho, carregar, folhas_das_portas, gravar, janela, mural, novo, parede,
                        piso, porta, salvar_fundo, sombras, trocar_enfeites)

W, H = 800, 270
PORTAS = (('204', 104, 'sala_aula'), ('LAB', 280, 'laboratorio'), ('NUCLEO', 456, 'nucleo'),
          ('PRESIDENCIA', 632, 'presidencia'))


def main():
    m = carregar('corredor')
    trocar_enfeites(m)
    im, d = novo(W, H, 'creme')
    piso(im, d, W, H, 'xadrez')
    parede(im, d, W)
    folhas = {}
    for rot, x, para in PORTAS:
        folhas[para] = porta(d, x, rot)
    for x in (184, 360, 536):                       # cartazes entre as portas
        mural(im, d, x + 3, 33, 50, 38, 3, semente=x)
    janela(im, d, 22, 22, 56, 30)
    janela(im, d, 722, 22, 56, 30)
    bordas(im, d, W, H, esq=(150, 250))
    capacho(d, 12, 154, 22, 92)
    sombras(im, m['objetos'])
    salvar_fundo(im, 'corredor')
    folhas_das_portas(m, folhas)
    gravar('corredor', m)
    print('corredor ok')


if __name__ == '__main__':
    main()

"""Poses novas pras cutscenes em visão lateral, feitas a partir dos quadros que já existem
(mesma arte de cada personagem). Acrescenta 2 linhas no fim de cada acoes2.png:

  linha 17  agachado_dor  agachado, uma mão no chão e outra no peito, soluçando (4 quadros)
  linha 18  sentar_banco  o "sentar" sem a cadeira de escritório (pra sentar em banco)

Pode rodar de novo: se as linhas já existem, ele refaz.
    python3 poses_extra.py
"""
import glob
import os

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
PASTA = os.path.join(AQUI, '..', 'projeto', 'assets', 'personagens')
Q = 64
LINHAS_ORIGINAIS = 17
CONTORNO = (22, 18, 24)
CADEIRA = {(52, 56, 66), (34, 36, 44)}          # encosto e pé da cadeira (iguais em todos)


def quadro(folha, linha, col):
    return folha.crop((col * Q, linha * Q, col * Q + Q, linha * Q + Q))


def pele(f):
    """Duas cores de pele do personagem (a mão que encosta no chão, na ponta do braço)."""
    cont = {}
    for y in range(52, 62):
        for x in range(38, 48):
            p = f.getpixel((x, y))
            r, g, b = p[:3]
            if p[3] and r > g > b and r - b > 50 and r > 120:
                cont[p[:3]] = cont.get(p[:3], 0) + 1
    cores = sorted(cont, key=lambda c: -cont[c])
    if not cores:
        return (225, 151, 109), (180, 120, 87)
    clara = max(cores[:3], key=sum)
    escura = min(cores[:3], key=sum)
    return clara, escura


def mao_no_peito(f, clara, escura):
    g = f.copy()
    px = g.load()
    for y in range(41, 45):
        for x in range(32, 37):
            borda = y in (41, 44) or x in (32, 36)
            px[x, y] = CONTORNO + (255,) if borda else (clara if y == 42 else escura) + (255,)
    return g


def soluco(f, dy=-1):
    """Sobe a parte de cima do corpo 1 px (ombro e cabeça), as pernas ficam no chão."""
    g = Image.new('RGBA', f.size, (0, 0, 0, 0))
    cima = f.crop((0, 0, Q, 47))
    baixo = f.crop((0, 47, Q, Q))
    g.paste(baixo, (0, 47), baixo)
    g.paste(cima, (0, dy), cima)
    meio = f.crop((0, 46, Q, 47))                   # tapa o buraco de 1 px que ficou
    g.paste(meio, (0, 46 + dy + 1), meio)
    return g


def sem_cadeira(f):
    g = f.copy()
    px = g.load()
    for y in range(Q):
        for x in range(Q):
            if px[x, y][3] and px[x, y][:3] in CADEIRA:
                px[x, y] = (0, 0, 0, 0)
    # contorno que só servia pra cadeira (sem nada do corpo encostado) some também
    for _ in range(2):
        tirar = []
        for y in range(Q):
            for x in range(Q):
                if px[x, y][3] and px[x, y][:3] == CONTORNO:
                    corpo = False
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            xx, yy = x + dx, y + dy
                            if 0 <= xx < Q and 0 <= yy < Q:
                                c = px[xx, yy]
                                if c[3] and c[:3] != CONTORNO:
                                    corpo = True
                    if not corpo:
                        tirar.append((x, y))
        for x, y in tirar:
            px[x, y] = (0, 0, 0, 0)
    return g


def main():
    n = 0
    for caminho in sorted(glob.glob(os.path.join(PASTA, '*', 'acoes2.png'))):
        quem = os.path.basename(os.path.dirname(caminho))
        a2 = Image.open(caminho).convert('RGBA')
        a1_cam = os.path.join(os.path.dirname(caminho), 'acoes.png')
        if not os.path.exists(a1_cam):
            continue
        a1 = Image.open(a1_cam).convert('RGBA')
        base = a2.crop((0, 0, a2.width, LINHAS_ORIGINAIS * Q))
        nova = Image.new('RGBA', (a2.width, (LINHAS_ORIGINAIS + 2) * Q), (0, 0, 0, 0))
        nova.paste(base, (0, 0))
        agach = quadro(a1, 4, 2)                      # "levantar", quadro 2: agachado com a mão no chão
        clara, escura = pele(agach)
        com_mao = mao_no_peito(agach, clara, escura)
        dor = [com_mao, soluco(com_mao), com_mao, soluco(com_mao)]
        y = LINHAS_ORIGINAIS * Q
        for i, f in enumerate(dor):
            nova.paste(f, (i * Q, y), f)
        for i in range(4):                            # "sentar" (acoes2 linha 4) sem a cadeira
            f = sem_cadeira(quadro(a2, 4, i))
            nova.paste(f, (i * Q, y + Q), f)
        nova.save(caminho)
        n += 1
    print('poses extras em', n, 'personagens')


if __name__ == '__main__':
    main()

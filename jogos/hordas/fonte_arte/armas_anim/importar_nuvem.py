"""Esporos da carta Nuvem de Esporos (`nuvem_espora`): loop novo, entrada e saída derivadas, ícone novo.

Fonte: jogos/hordas/projeto/assets/v2/armas/nuvem_esporos.png (cartão parado, 120x77, cogumelos-bola
dourados e névoa âmbar). Daí saem, em jogos/hordas/projeto/assets/v2/:
  armas_anim/nuvem_esporos_loop.png     6 quadros de 120x77, 6 fps, emenda no primeiro (720x77)
  armas_anim/nuvem_esporos_entrada.png  3 quadros, a nuvem se forma a partir do quadro 1 do loop (360x77)
  armas_anim/nuvem_esporos_saida.png    3 quadros, a nuvem se desfaz a partir do último quadro do loop (360x77)
  icones_cartas/nuvem_espora.png        ícone 32x32 (recorte 1:1 do pod central, sem reescala)
  icones_cartas/16/nuvem_espora.png     ícone 16x16 (reamostrado do de 32 px)

Nomes, tamanhos, fps e âncora são os de indice_nuvens.json (nuvem_esporos), então o índice não muda.

Como o loop é feito (tudo fechado em 6 quadros, para emendar sem salto):
  - contorno da névoa: a cada quadro, 1/6 dos pixels da borda some (padrão diagonal que gira com o quadro),
    então a borda tremula sem mover a forma;
  - grãos dourados: 8 grãos percorrem a elipse em volta do centro, com um balanço de 0,35 rad (o ângulo
    volta ao início no fim do ciclo).
Entrada e saída são o quadro do loop com dissolve em blocos 2x2 (matriz de Bayer 4x4), igual ao esmaecer das
nuvens de gerar_nuvens.py.

Sem ChatGPT: o plano previa a folha do loop gerada no ChatGPT (A01). Aqui o loop sai do próprio cartão, por
decisão do PR PER-5 (registrada no corpo do PR); se uma folha gerada chegar, basta trocar FONTE_LOOP por ela.

Rodar: python -I importar_nuvem.py  (sem semente aleatória, sem rede; rodar de novo dá os mesmos arquivos)
"""
import math
import os

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, "..", "..", "..", ".."))
PROJETO = os.path.join(RAIZ, "jogos", "hordas", "projeto")
ASSETS = os.path.join(PROJETO, "assets", "v2")
FONTE_LOOP = os.path.join(ASSETS, "armas", "nuvem_esporos.png")

QUADRO = (120, 77)
ANCORA = (60, 38)
N_LOOP = 6
N_BORDA = 6  # a borda some em um sexto por quadro
GRAOS = 8
ELIPSE = (46.0, 20.0)  # raio horizontal e vertical da órbita dos grãos
BALANCO = 0.35  # rad de balanço do grão em volta da órbita (fechado no ciclo)
COR_GRAO = (255, 240, 170, 255)
COR_GRAO_CLARO = (255, 252, 214, 255)
ICONE_CAIXA = (56, 29, 88, 61)  # recorte 32x32 centrado no pod central da carta (1:1, sem reescala)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0


def carregar_cartao():
    img = Image.open(FONTE_LOOP).convert("RGBA")
    if img.size != QUADRO:
        raise SystemExit("cartão %s com tamanho %s, esperava %s" % (FONTE_LOOP, img.size, QUADRO))
    return np.array(img, dtype=np.uint8)


def borda_da_nuvem(a):
    """Pixels com alfa > 0 que têm vizinho de alfa 0 (4-vizinhança)."""
    m = a[:, :, 3] > 0
    viz = np.zeros_like(m)
    viz[1:, :] |= ~m[:-1, :]
    viz[:-1, :] |= ~m[1:, :]
    viz[:, 1:] |= ~m[:, :-1]
    viz[:, :-1] |= ~m[:, 1:]
    return m & viz


def quadro_do_loop(base, k):
    f = base.copy()
    h, w = f.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    # 1) borda tremula: no quadro k somem os pixels com (5x + 3y) % 6 == k
    borda = borda_da_nuvem(base)
    some = borda & (((5 * xx + 3 * yy) % N_BORDA) == k)
    f[some, 3] = 0
    # 2) grãos dourados orbitando, com balanço fechado no ciclo
    cx, cy = ANCORA
    for i in range(GRAOS):
        theta0 = math.tau * i / GRAOS
        ang = theta0 + BALANCO * math.sin(math.tau * k / N_LOOP + i)
        gx = cx + ELIPSE[0] * math.cos(ang)
        gy = cy + ELIPSE[1] * math.sin(ang)
        x, y = int(round(gx)), int(round(gy))
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            if 0 <= x + dx < w and 0 <= y + dy < h:
                f[y + dy, x + dx] = COR_GRAO
        if 0 <= x < w and 0 <= y < h:
            f[y, x] = COR_GRAO_CLARO
    return f


def dissolve(f, limiar):
    """Mantém os blocos 2x2 com valor de Bayer menor que `limiar` (0 a 1); o resto fica transparente."""
    h, w = f.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    bay = BAYER[(yy // 2) % 4, (xx // 2) % 4]
    g = f.copy()
    g[bay >= limiar, 3] = 0
    return g


def salvar_tira(quadros, caminho):
    tira = np.concatenate(quadros, axis=1)
    Image.fromarray(tira, "RGBA").save(caminho)


def main():
    base = carregar_cartao()
    loop = [quadro_do_loop(base, k) for k in range(N_LOOP)]
    # entrada: a nuvem se forma a partir do quadro 1 do loop, em três estágios de dissolve
    entrada = [dissolve(loop[0], lim) for lim in (1 / 3, 2 / 3, 1.0)]
    # saída: desfaz o último quadro do loop, em três estágios de dissolve decrescentes
    saida = [dissolve(loop[N_LOOP - 1], lim) for lim in (2 / 3, 1 / 3, 1 / 6)]

    pasta_anim = os.path.join(ASSETS, "armas_anim")
    salvar_tira(loop, os.path.join(pasta_anim, "nuvem_esporos_loop.png"))
    salvar_tira(entrada, os.path.join(pasta_anim, "nuvem_esporos_entrada.png"))
    salvar_tira(saida, os.path.join(pasta_anim, "nuvem_esporos_saida.png"))

    # ícone: recorte 1:1 do pod central (sem reescala, o pixel fica nítido)
    icone = Image.fromarray(base, "RGBA").crop(ICONE_CAIXA)
    pasta_icone = os.path.join(ASSETS, "icones_cartas")
    icone.save(os.path.join(pasta_icone, "nuvem_espora.png"))
    icone.resize((16, 16), Image.NEAREST).save(os.path.join(pasta_icone, "16", "nuvem_espora.png"))
    print("nuvem_esporos: loop 6q, entrada 3q, saida 3q, icone 32 e 16 px")


if __name__ == "__main__":
    main()

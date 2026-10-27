"""Vila Amaldiçoada da v2: as casas (os mesmos seis nomes e medidas de antes: predio_loja, predio_bar, predio_apto_a/b, predio_torre, predio_ruina).
Casas medievais de pedra embaixo e enxaimel em cima (reboco com vigas escuras), telhado de telha ou palha em duas águas, janelas com postigos (algumas
acesas), porta de madeira, chaminé e uma lanterna na frente; a "torre" é uma capela com campanário e a "ruína" uma casa queimada. A frente é o lado -Y.
"""
import math

from vila_pecas import (CARVAO, FERRO, LATAO, LONA, LONA_ESC, MADEIRA, MADEIRA_CLARA, MADEIRA_ESC, MUSGO, PALHA, PEDRA, PEDRA_CLARA, PEDRA_ESC, REBOCO,
                        REBOCO_ESC, ROXO, TELHA, TELHA_ESC, VELA, VERMELHO, E, M, ferro, lanterna, madeira, pedra)
from mapas_v2 import B, C, barra, esfera, px3


def reboco(c=REBOCO):
    return M(c, 0.95, 0.6, 0.3, 4.0)


def janela(x, z, y, w=0.7, h=0.9, acesa=True, cor=VELA, postigos=True):
    """Janela na face y: moldura de pedra, vidro aceso (ou escuro), travessas e postigos de madeira abertos de cada lado."""
    B(w + 0.2, 0.08, h + 0.2, x, y - 0.02, z - 0.1, pedra(PEDRA_CLARA), ch=0.02)
    B(w, 0.06, h, x, y - 0.05, z, E(cor, 1.8) if acesa else M("141a20", 0.3), ch=0.0)
    B(0.04, 0.07, h, x, y - 0.07, z, madeira(MADEIRA_ESC), ch=0.0)
    B(w, 0.07, 0.04, x, y - 0.07, z + h * 0.55, madeira(MADEIRA_ESC), ch=0.0)
    if postigos:
        for s in (-1, 1):
            B(w * 0.45, 0.04, h, x + s * (w / 2 + w * 0.26), y - 0.08, z, madeira(MADEIRA), ch=0.01, rot=(0, 0, s * 0.25))


def porta(x, y, w=0.95, h=1.9, cor=MADEIRA):
    B(w + 0.3, 0.1, h + 0.25, x, y - 0.03, 0.0, pedra(PEDRA_CLARA), ch=0.03)
    B(w, 0.08, h, x, y - 0.08, 0.0, madeira(cor), ch=0.02)
    for k in range(4):
        B(0.02, 0.09, h - 0.1, x - w * 0.37 + k * w * 0.25, y - 0.09, 0.05, M(CARVAO, 0.9), ch=0.0)
    for z in (0.4, 1.4):
        B(w, 0.09, 0.07, x, y - 0.09, z, ferro(), ch=0.0)
    esfera("macaneta", 0.04, (x + w * 0.32, y - 0.13, 1.0), M(LATAO, 0.4))


def telhado(w, d, zw, hr, c=TELHA, ov=0.35, palha=False, x=0.0):
    """Telhado de duas águas ao longo de X: duas lajes inclinadas, cumeeira escura e beirais; a água da frente é a que a câmera vê."""
    s = d / 2.0 + ov
    a = math.atan2(hr, s)
    L = math.hypot(s, hr) + 0.1
    mat = M(PALHA, 0.98, 0.7, 0.4, 20.0) if palha else M(c, 0.9, 0.8, 0.3, 5.0)
    mat2 = M("8f7438", 0.98, 0.7, 0.4, 20.0) if palha else M(TELHA_ESC, 0.9, 0.8, 0.3, 5.0)
    B(w + 0.5, L, 0.14, x, -s / 2, zw + hr / 2, mat, ch=0.03, rot=(a, 0, 0))
    B(w + 0.5, L, 0.14, x, s / 2, zw + hr / 2, mat2, ch=0.03, rot=(-a, 0, 0))
    B(w + 0.45, 0.16, 0.12, x, 0, zw + hr + 0.03, madeira(MADEIRA_ESC), ch=0.02)
    # empena (a parede triangular dos lados): fila de blocos que sobem
    for sx in (-1, 1):
        for k in range(4):
            comp = d * (1.0 - k / 4.0)
            B(0.2, comp, hr / 4.0, x + sx * (w / 2 + 0.05), 0, zw + k * hr / 4.0, reboco(), ch=0.01)


def chamine(x, y, zw, h=1.4):
    B(0.6, 0.6, h, x, y, zw, pedra(PEDRA_ESC), ch=0.03)
    B(0.72, 0.72, 0.14, x, y, zw + h, pedra(PEDRA), ch=0.03)
    B(0.4, 0.4, 0.04, x, y, zw + h + 0.14, M(CARVAO, 0.95), ch=0.0)


def vigas(w, d, z0, z1, y, passo=1.3):
    """Enxaimel: vigas escuras verticais, uma horizontal em cima e diagonais, sobre o reboco da face y."""
    v = madeira(MADEIRA_ESC)
    n = max(2, int(round(w / passo)))
    for i in range(n + 1):
        B(0.14, 0.1, z1 - z0, -w / 2 + i * w / n, y - 0.03, z0, v, ch=0.01)
    B(w, 0.1, 0.14, 0, y - 0.03, z0, v, ch=0.01)
    B(w, 0.1, 0.14, 0, y - 0.03, z1 - 0.14, v, ch=0.01)
    for i in range(n):
        x0, x1 = -w / 2 + i * w / n, -w / 2 + (i + 1) * w / n
        barra((x0 + 0.05, y - 0.05, z0 + 0.1) if i % 2 == 0 else (x1 - 0.05, y - 0.05, z0 + 0.1),
              (x1 - 0.05, y - 0.05, z1 - 0.1) if i % 2 == 0 else (x0 + 0.05, y - 0.05, z1 - 0.1), 0.05, v, v=6)


def _casa(r, w, d, h1, h2, hr, palha=False, janelas=(), sinal=None, chamine_x=None, c_reboco=REBOCO, ov=0.0):
    """Casa de dois andares: base de pedra (h1), andar de cima de enxaimel (h2) com um beiral mais largo (ov), telhado de altura hr. `janelas` = (x, andar,
    acesa); `sinal` = 'taverna' ou 'loja' (placa de ferro pendurada)."""
    yf = -d / 2.0
    B(w + 0.1, d + 0.1, 0.18, 0, 0, 0.0, pedra(PEDRA_ESC), ch=0.03)
    # térreo: pedra em fiadas
    B(w, d, h1, 0, 0, 0.18, pedra(), ch=0.03)
    for k in range(int(h1 / 0.3)):
        B(w + 0.02, 0.02, 0.025, 0, yf - 0.01, 0.4 + k * 0.3, M(PEDRA_ESC, 0.95), ch=0.0)
    for k in range(int(w / 0.5)):
        B(0.025, 0.02, 0.3, -w / 2 + 0.25 + k * 0.5 + (0.25 if k % 2 else 0.0), yf - 0.01, 0.3 + (k % 3) * 0.3, M(PEDRA_ESC, 0.95), ch=0.0)
    # andar de cima (balanço de 0,18 m na frente)
    zc = 0.18 + h1
    B(w + 0.1, d + 0.36, 0.2, 0, -0.09, zc, madeira(MADEIRA_ESC), ch=0.02)
    B(w, d + 0.2, h2, 0, -0.04, zc + 0.2, reboco(c_reboco), ch=0.02)
    vigas(w, d, zc + 0.2, zc + 0.2 + h2, yf - 0.14)
    zw = zc + 0.2 + h2
    telhado(w, d, zw, hr, palha=palha, ov=ov or 0.4)
    if chamine_x is not None:
        chamine(chamine_x, 0.2, zw + hr * 0.3, 1.4)
    for x, andar, acesa in janelas:
        janela(x, 0.65 if andar == 0 else zc + 0.55, yf - (0.0 if andar == 0 else 0.22), acesa=acesa)
    return yf, zc, zw


def predio_loja(r):
    """Casa de comércio (6,2 x 2,6 m): térreo de pedra com a porta e a vitrine acesa, balcão de feira à frente, placa de ferro e lanterna."""
    yf, zc, zw = _casa(r, 6.0, 2.6, 2.3, 1.7, 1.6, janelas=[(-1.5, 1, True), (0.6, 1, False), (2.2, 1, True)], chamine_x=2.0)
    porta(1.2, yf, 1.0, 1.9)
    janela(-1.0, 0.7, yf, w=1.3, h=1.1, acesa=True, postigos=False)
    # balcão e toldo de lona à frente
    B(1.6, 0.6, 0.8, -1.0, yf - 0.55, 0.0, madeira(MADEIRA), ch=0.02)
    for k in range(5):
        B(0.32, 1.0, 0.04, -1.6 + k * 0.32, yf - 0.85, 1.92, M(LONA if k % 2 == 0 else LONA_ESC, 0.95), ch=0.0, rot=(0.18, 0, 0))
    barra((-1.9, yf - 0.4, 1.9), (-1.9, yf - 0.4, 0.8), 0.04, madeira(MADEIRA_ESC), v=6)
    barra((-0.1, yf - 0.4, 1.9), (-0.1, yf - 0.4, 0.8), 0.04, madeira(MADEIRA_ESC), v=6)
    barra((2.3, yf - 0.1, 3.0), (2.3, yf - 0.5, 3.0), 0.025, ferro(), v=5)
    B(0.5, 0.05, 0.4, 2.3, yf - 0.55, 2.65, M(LATAO, 0.45), ch=0.02)
    lanterna(-0.5, yf - 0.3, 3.0, VELA, 3.0, 1.3)
    for k in range(3):
        C(0.1, 0.2, -1.4 + k * 0.4, yf - 0.55, 0.8, M(["7a2a2a", "a88b4c", "4a6a3a"][k], 0.9), v=10)


def predio_bar(r):
    """Taverna (5,6 x 2,6 m): palha no telhado, porta larga, janelas acesas, tabuleta com caneca e uma lanterna roxa de feitiço."""
    yf, zc, zw = _casa(r, 5.4, 2.6, 2.2, 1.8, 1.6, palha=True, janelas=[(-1.7, 1, True), (0.4, 1, True), (1.9, 1, False)], chamine_x=-1.6, c_reboco=REBOCO_ESC)
    porta(0.0, yf, 1.3, 2.0, MADEIRA_ESC)
    janela(-1.7, 0.8, yf, w=0.9, h=0.8)
    janela(1.6, 0.8, yf, w=0.9, h=0.8)
    barra((2.2, yf - 0.05, 2.6), (2.2, yf - 0.55, 2.6), 0.03, ferro(), v=6)
    B(0.62, 0.06, 0.45, 2.2, yf - 0.6, 2.2, madeira(MADEIRA_CLARA), ch=0.02)
    esfera("caneca", 0.12, (2.2, yf - 0.66, 2.4), M(LATAO, 0.5), escala=(1, 0.3, 1.1))
    lanterna(-0.7, yf - 0.45, 2.55, ROXO, 3.4, 1.4)
    for k in range(3):
        C(0.28, 0.65, -2.2 + k * 0.5, yf - 0.55, 0.0, madeira(MADEIRA_CLARA if k % 2 else MADEIRA), v=12, ch=0.02)
        C(0.3, 0.05, -2.2 + k * 0.5, yf - 0.55, 0.3, ferro(), v=12)


def predio_apto(r, variante="a"):
    """Casa alta e estreita de três andares (5,4 x 2,1 m): enxaimel apertado, janelas acesas em andares alternados e um balanço no meio."""
    jan = [(-1.7, 1, True), (0.0, 1, variante == "a"), (1.7, 1, variante != "a")]
    yf, zc, zw = _casa(r, 5.2, 2.1, 2.2, 2.3, 1.6, janelas=jan, chamine_x=1.9 if variante == "a" else -1.9, c_reboco=REBOCO if variante == "a" else "a89d82")
    # segundo balanço: o terceiro andar em cima do telhado... aqui, uma sacada de madeira no andar de cima
    B(1.6, 0.5, 0.1, -1.7 if variante == "a" else 1.7, yf - 0.45, zc + 0.15, madeira(MADEIRA_ESC), ch=0.02)
    for k in range(5):
        B(0.04, 0.04, 0.4, (-1.7 if variante == "a" else 1.7) - 0.7 + k * 0.35, yf - 0.68, zc + 0.25, madeira(MADEIRA_ESC), ch=0.0)
    porta(-0.3 if variante == "a" else 0.3, yf, 1.0, 1.9)
    janela(1.4 if variante == "a" else -1.4, 0.75, yf, w=0.8, h=0.9, acesa=True)
    lanterna(0.7 if variante == "a" else -0.7, yf - 0.2, 2.1, VELA, 3.0, 1.2)


def predio_apto_a(r):
    predio_apto(r, "a")


def predio_apto_b(r):
    predio_apto(r, "b")


def predio_torre(r):
    """Capela com campanário (5,6 x 2,0 m, 7,3 m de altura): nave de pedra com janela de vitral à esquerda e uma torre de sino à direita com pináculo."""
    # nave
    B(3.6, 2.0, 3.4, -0.8, 0, 0.0, pedra(), ch=0.03)
    for k in range(10):
        B(3.62, 0.02, 0.025, -0.8, -1.01, 0.3 + k * 0.32, M(PEDRA_ESC, 0.95), ch=0.0)
    for x in (-2.4, -0.8, 0.8):
        B(0.3, 0.4, 3.6, x, -1.0, 0.0, pedra(PEDRA_CLARA), ch=0.03)
    telhado(3.6, 2.0, 3.4, 1.4, x=-0.8)
    # vitral em arco
    B(0.9, 0.08, 1.7, -1.6, -1.05, 1.3, pedra(PEDRA_CLARA), ch=0.03)
    B(0.7, 0.06, 1.5, -1.6, -1.1, 1.4, E("58b8ff", 1.6), ch=0.0)
    esfera("arco", 0.35, (-1.6, -1.1, 2.9), E("58b8ff", 1.6), escala=(1, 0.2, 1))
    B(0.04, 0.07, 1.8, -1.6, -1.13, 1.3, madeira(MADEIRA_ESC), ch=0.0)
    B(0.7, 0.07, 0.04, -1.6, -1.13, 2.0, madeira(MADEIRA_ESC), ch=0.0)
    porta(0.0, -1.0, 1.1, 2.2, MADEIRA_ESC)
    # campanário
    B(2.0, 2.0, 5.4, 1.8, 0, 0.0, pedra(), ch=0.03)
    for k in range(17):
        B(2.02, 0.02, 0.025, 1.8, -1.01, 0.3 + k * 0.32, M(PEDRA_ESC, 0.95), ch=0.0)
    B(2.1, 2.1, 0.2, 1.8, 0, 3.6, pedra(PEDRA_ESC), ch=0.03)
    B(1.0, 0.08, 1.2, 1.8, -1.02, 4.2, M("0c0a08", 1.0), ch=0.0)       # a boca do sino
    esfera("sino", 0.32, (1.8, -0.95, 4.65), M(LATAO, 0.4), escala=(1, 0.8, 1.2))
    px3.cone("pinaculo", 1.45, 0.0, 1.9, (1.8, 0, 5.4 + 0.95), M(TELHA_ESC, 0.9, 0.8, 0.3, 5.0), vertices=4)
    barra((1.8, 0, 7.3), (1.8, 0, 7.55), 0.02, ferro(), v=4)
    lanterna(-0.1, -1.2, 3.0, VERMELHO, 3.2, 1.4)
    B(0.25, 0.04, 0.5, 3.0, -1.02, 1.5, M(CARVAO, 0.9), ch=0.0)      # uma fenda vertical, seteira


def predio_ruina(r):
    """Casa queimada (5,8 x 2,2 m): paredes de pedra enegrecidas pela metade, vigas calcinadas no ar, sem telhado, cinzas e brasas fracas dentro."""
    carvao = M("302a27", 0.95, 0.6, 0.4, 5.0)
    B(5.8, 2.2, 0.3, 0, 0, 0.0, pedra(PEDRA_ESC), ch=0.03)
    cols = [2.6, 2.2, 1.4, 0.9, 0.5, 1.0, 1.9, 2.7, 3.1, 2.4]
    for i, alt in enumerate(cols):
        x = -2.9 + 0.58 * (i + 0.5)
        z = 0.3
        k = 0
        while z < 0.3 + alt:
            h = min(0.3, 0.3 + alt - z)
            B(0.58, 2.1, h * 0.98, x + (0.06 if k % 2 else -0.06), 0, z, pedra(PEDRA_ESC if (i + k) % 3 else PEDRA), ch=0.025)
            z += h
            k += 1
    # reboco queimado na frente: faixa preta onde as chamas lamberam
    for x, larg, alt in [(-2.0, 1.2, 1.6), (0.8, 1.0, 1.2), (2.2, 1.3, 2.0)]:
        B(larg, 0.03, alt, x, -1.12, 0.3, carvao, ch=0.0)
    # vigas calcinadas: caídas e em pé
    for x, a in [(-1.5, 0.5), (0.2, -0.4), (1.8, 0.7)]:
        barra((x, -0.4, 0.4), (x + 0.9 * math.cos(a), -0.6, 2.2), 0.09, carvao, v=6)
    barra((-2.6, -0.2, 0.3), (-2.6, -0.2, 3.3), 0.11, carvao, v=6)
    barra((2.7, -0.2, 0.3), (2.7, -0.2, 3.6), 0.11, carvao, v=6)
    barra((-2.6, -0.2, 3.3), (-0.6, -0.5, 3.4), 0.08, carvao, v=6)
    # um pedaço de telhado pendurado e o entulho na frente
    B(1.6, 0.9, 0.12, -2.1, -0.2, 3.1, M(TELHA_ESC, 0.9, 0.8, 0.3, 5.0), ch=0.03, rot=(0.4, 0, 0.1))
    for k in range(10):
        B(r.uniform(0.2, 0.5), r.uniform(0.2, 0.4), r.uniform(0.1, 0.3), r.uniform(-2.6, 2.6), -1.3 - r.uniform(0, 0.8), 0.0, pedra(PEDRA_ESC), ch=0.03,
          rot=(0, 0, r.uniform(0, 3)))
    esfera("cinza", 0.9, (0.0, 0.6, 0.35), M("2c2623", 1.0), escala=(2.2, 0.8, 0.1))
    for k in range(6):
        esfera("brasa", 0.05, (r.uniform(-1.5, 1.5), r.uniform(0.2, 0.8), 0.42), E("c0501a", 1.0), escala=(1, 1, 0.5))
    janela(-0.2, 1.2, -1.1, acesa=False, postigos=False)

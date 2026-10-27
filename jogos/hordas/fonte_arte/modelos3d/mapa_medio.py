"""Ruínas da Floresta da v2 (id "medio"): os objetos e o piso (veja mapas_v2.py, que lê OBJETOS e PISO daqui). Cada função monta UM objeto
com a origem no chão, no centro da pegada, a frente voltada para -Y. Medidas em metros (1 m = 32 px na horizontal e 22,6 px na vertical).
Tom: um templo de pedra cinza-azulada que a floresta engoliu: colunas inteiras e partidas, muros em degraus, um arco, estátua sem cabeça,
fonte seca, sarcófagos; musgo nas bases e hera subindo pelas faces, runas azuis frias nos obeliscos.

    blender -b -P modelos3d/mapas_v2.py -- medio                # tudo (o piso leva alguns minutos)
    blender -b -P modelos3d/mapas_v2.py -- medio coluna_alta    # só os citados ("piso" é o chão)
"""
import math

from mapas_v2 import B, C, E, M, cilindro, caixa, esfera, px3

# ------------------------------------------------------------------ cores (pedra fria e acinzentada, verde só no musgo e na hera)
PEDRA_A = "848d97"
PEDRA_B = "6f7882"
PEDRA_C = "99a1a9"
PEDRA_ESC = "50585f"
JUNTA = "30363c"
MUSGO = "46633a"
MUSGO_ESC = "2f4a2b"
HERA = "3e7a45"
HERA_ESC = "2a5833"
TERRA = "3a352f"
RUNA = "62d4ff"
OSSO = "b8b4a2"


def dim(w, d, h, extra_w=0.0, extra_h=0.0):
    """Tela do render (largura, altura, linha da origem) para um objeto w x d x h metros, com margem de 8 px."""
    larg = int(math.ceil((w + extra_w) * 32.0)) + 16
    larg += larg % 2
    alt_px = (h + extra_h + d) * 22.63
    alt = int(math.ceil(alt_px)) + 16
    pe_y = (h + extra_h + d / 2.0) * 22.63 + 8
    return larg, alt, pe_y


def tela(w, d, h, f, **kw):
    larg, alt, pe_y = dim(w, d, h, **kw)
    return (larg, alt, pe_y, f)


def pedra(r, claro=0.0):
    """Uma das pedras do conjunto (o mesmo material por nome: o Blender reaproveita)."""
    hexa = r.choice([PEDRA_A, PEDRA_A, PEDRA_B, PEDRA_C])
    return M(hexa, 0.92, 0.7, 0.24, 7.0)


def pedra_esc():
    return M(PEDRA_ESC, 0.95, 0.7, 0.2, 7.0)


def musgo(x, y, z, rx, ry, rz=0.07, escuro=False):
    """Almofada de musgo (esfera achatada) sobre a pedra."""
    esfera("musgo", 1.0, (x, y, z), M(MUSGO_ESC if escuro else MUSGO, 0.98, 0.5, 0.3, 14.0), escala=(rx * 0.8, ry * 0.8, rz))


def hera(r, x, y, z0, z1, n=None):
    """Hera subindo por uma face voltada para -Y: ramo fino e folhas em tufos de duas tintas."""
    ramo = M(HERA_ESC, 0.9)
    B(0.045, 0.04, z1 - z0, x, y, z0, ramo, ch=0.0)
    n = n or max(3, int((z1 - z0) / 0.2))
    for i in range(n):
        z = z0 + (z1 - z0) * (i + r.random() * 0.8) / n
        lado = r.choice((-1, 1))
        esfera("folha", 1.0, (x + lado * r.uniform(0.04, 0.12), y - 0.03, z), M(HERA if i % 2 else HERA_ESC, 0.9, 0.2, 0.2, 18.0),
               escala=(r.uniform(0.07, 0.13), 0.05, r.uniform(0.06, 0.1)))


def bloco(x, y, z, w, d, h, mat, rot=(0, 0, 0), ch=0.03):
    return B(w, d, h, x, y, z, mat, ch=ch, rot=rot)


# ------------------------------------------------------------------ colunas
def _capitel(x, y, z, larg, r):
    topo = pedra(r)
    bloco(x, y, z, larg, larg, 0.16, pedra_esc(), ch=0.03)
    bloco(x, y, z + 0.16, larg * 1.12, larg * 1.12, 0.2, topo, ch=0.04)
    C(larg * 0.4, 0.1, x, y, z + 0.36, topo, v=14, ch=0.02)


def coluna_alta(r):
    """Coluna inteira de 4,2 m: base quadrada, fuste de 14 faces, capitel; musgo na base e hera numa face."""
    p = pedra(r)
    bloco(0, 0, 0, 1.0, 1.0, 0.18, pedra_esc(), ch=0.03)
    bloco(0, 0, 0.18, 0.84, 0.84, 0.16, p, ch=0.03)
    C(0.37, 3.2, 0, 0, 0.34, p, v=14, ch=0.02)
    for a in range(8):  # caneluras: sulcos de pedra escura
        ang = a * math.pi / 4.0
        B(0.035, 0.035, 3.0, 0.37 * math.cos(ang), 0.37 * math.sin(ang), 0.44, M(PEDRA_ESC, 0.95), ch=0.0)
    C(0.4, 0.1, 0, 0, 3.52, pedra_esc(), v=14)
    _capitel(0, 0, 3.62, 0.8, r)
    musgo(0.05, -0.38, 0.2, 0.5, 0.32, 0.12)
    musgo(-0.3, -0.2, 0.18, 0.22, 0.22, 0.1, True)
    hera(r, 0.12, -0.38, 0.3, 2.5)
    hera(r, -0.18, -0.36, 0.3, 1.5)
    bloco(0.32, -0.45, 0.0, 0.16, 0.12, 0.1, pedra(r), rot=(0, 0, 0.5))


def coluna_quebrada(r):
    """Coluna partida a 2 m: topo em dentes, lascas no chão, musgo e hera."""
    p = pedra(r)
    bloco(0, 0, 0, 1.0, 1.0, 0.18, pedra_esc(), ch=0.03)
    bloco(0, 0, 0.18, 0.84, 0.84, 0.16, p, ch=0.03)
    C(0.37, 1.1, 0, 0, 0.34, p, v=14, ch=0.02)
    for a in range(6):
        ang = a * math.pi / 3.0 + 0.2
        B(0.035, 0.035, 0.95, 0.37 * math.cos(ang), 0.37 * math.sin(ang), 0.44, M(PEDRA_ESC, 0.95), ch=0.0)
    # topo em dentes: alturas diferentes, cortados em ângulo
    for i, (dx, dy, h) in enumerate([(-0.17, -0.05, 0.75), (0.1, 0.12, 0.45), (0.2, -0.12, 0.25), (-0.05, 0.2, 0.55)]):
        bloco(dx, dy, 1.44, 0.3, 0.3, h * 0.5 + 0.1, p, rot=(r.uniform(-0.2, 0.2), r.uniform(-0.2, 0.2), r.uniform(0, 1.5)), ch=0.02)
    bloco(0.5, -0.45, 0.0, 0.3, 0.22, 0.2, p, rot=(0, 0, 0.6))
    bloco(-0.5, -0.4, 0.0, 0.22, 0.18, 0.14, pedra_esc(), rot=(0, 0, -0.4))
    musgo(0, -0.4, 0.2, 0.5, 0.3, 0.12)
    musgo(0.1, 0.0, 1.5, 0.3, 0.25, 0.06)
    hera(r, -0.1, -0.38, 0.3, 1.5)


def base_coluna(r):
    """O tambor de uma coluna que não existe mais: base e meio metro de fuste, coberta de musgo."""
    p = pedra(r)
    bloco(0, 0, 0, 1.0, 1.0, 0.2, pedra_esc(), ch=0.03)
    bloco(0, 0, 0.2, 0.84, 0.84, 0.14, p, ch=0.03)
    C(0.34, 0.5, 0, 0, 0.34, p, v=12, ch=0.02)
    musgo(0, -0.1, 0.8, 0.3, 0.28, 0.1)
    musgo(0.2, -0.42, 0.22, 0.4, 0.2, 0.09, True)


def coluna_caida(r):
    """Coluna tombada ao longo de X, partida em tambores que rolaram um pouco, com o capitel numa ponta."""
    p = pedra(r)
    ang = 0.0
    for i, (cx, cy, comp) in enumerate([(-1.35, 0.06, 1.0), (-0.2, -0.02, 1.2), (0.95, 0.1, 0.9)]):
        c = cilindro("tambor", 0.37, comp, (cx, cy, 0.38), p, rot=(0, math.pi / 2, ang + (i - 1) * 0.04), vertices=14)
        for a in range(5):  # caneluras só no lado de cima e da frente
            t = -0.3 + a * 0.35
            B(comp * 0.98, 0.035, 0.035, cx, cy + 0.37 * math.sin(t - 1.2), 0.38 + 0.37 * math.cos(t - 1.2) * 0.9, M(PEDRA_ESC, 0.95), ch=0.0)
    bloco(1.55, 0.05, 0.0, 0.5, 0.82, 0.62, pedra_esc(), ch=0.04)       # o capitel, de lado
    bloco(1.78, 0.05, 0.0, 0.14, 0.96, 0.76, p, ch=0.03)
    musgo(-0.4, -0.05, 0.72, 1.3, 0.2, 0.08)
    musgo(0.9, -0.34, 0.12, 0.6, 0.15, 0.08, True)
    hera(r, -1.2, -0.36, 0.1, 0.6, 3)


def tambor_coluna(r):
    """Um tambor de coluna deitado, sozinho no mato."""
    cilindro("tambor", 0.36, 0.7, (0, 0, 0.36), pedra(r), rot=(math.pi / 2, 0, 0.5), vertices=14)
    musgo(0.0, 0.0, 0.7, 0.4, 0.22, 0.07)
    musgo(0.1, -0.38, 0.1, 0.4, 0.15, 0.07, True)


# ------------------------------------------------------------------ muros
def _muro(r, larg, prof, alturas, passo=0.4, janela=None, hera_n=2):
    """Muro de pedra em fiadas de 0,3 m: cada coluna de `passo` de largura sobe até sua altura (topo em degraus); `janela` = (x0, x1, z0, z1)
    abre um vão (que o resto do muro atravessa por cima, como o lintel)."""
    n = int(round(larg / passo))
    cores = [M(h, 0.93, 0.8, 0.26, 7.0) for h in (PEDRA_A, PEDRA_B, PEDRA_C, PEDRA_B)]
    for i in range(n):
        x = -larg / 2.0 + passo * (i + 0.5)
        alt = alturas[i % len(alturas)]
        z = 0.0
        k = 0
        while z < alt - 0.02:
            h = min(0.3 + (0.04 if (k + i) % 2 else 0.0), alt - z)
            if janela and janela[0] <= x <= janela[1] and janela[2] <= z + h / 2 <= janela[3]:
                z += h
                k += 1
                continue
            desloc = 0.06 if (k % 2) else -0.06
            bloco(x + desloc * 0.4, 0, z, passo * 0.97, prof * (0.96 + 0.04 * ((i + k) % 3)), h * 0.98, cores[(i * 3 + k) % 4], ch=0.025)
            z += h
            k += 1
    musgo(-larg * 0.2, -prof * 0.45, 0.14, larg * 0.22, 0.12, 0.1)
    musgo(larg * 0.25, -prof * 0.46, 0.12, larg * 0.16, 0.1, 0.09, True)
    for j in range(hera_n):
        xh = r.uniform(-larg * 0.4, larg * 0.4)
        hera(r, xh, -prof * 0.5 - 0.02, 0.2, r.uniform(0.9, min(alturas) + 0.4))


def muro_ruina_a(r):
    _muro(r, 3.2, 0.6, [2.4, 2.1, 1.5, 0.9, 1.2, 2.0, 1.8, 0.6])


def muro_ruina_b(r):
    _muro(r, 2.4, 0.6, [1.2, 0.9, 0.6, 0.9, 1.5, 0.6], hera_n=1)


def muro_alto(r):
    """Muro de 3,8 m com uma janela em arco e o topo roído: fecha as bordas do mapa."""
    _muro(r, 3.4, 0.8, [3.8, 3.5, 3.8, 3.1, 3.8, 3.4, 3.6, 2.9], janela=(-0.45, 0.45, 1.5, 2.7))
    bloco(0, 0, 2.7, 1.1, 0.8, 0.34, M(PEDRA_C, 0.9, 0.6, 0.2, 7.0), ch=0.05)   # lintel da janela
    hera(r, 0.6, -0.42, 0.2, 3.2)
    hera(r, -1.0, -0.42, 0.2, 2.6)


def muro_ruina_c(r):
    """Fundação de muro: uma fiada ou duas, quase só o desenho no chão (passa por cima? não: 0,5 m ainda impede)."""
    _muro(r, 2.8, 0.6, [0.5, 0.35, 0.5, 0.65, 0.35, 0.5, 0.5], hera_n=0)
    musgo(0.0, 0.0, 0.52, 1.1, 0.25, 0.06)


# ------------------------------------------------------------------ arco
def arco_ruina(r):
    """Arco de 4 m de vão e 4,4 m de altura: dois pilares e uma volta de aduelas que se perde pela direita."""
    p = pedra(r)
    for sx in (-1, 1):
        px_ = sx * 1.55
        bloco(px_, 0, 0, 1.0, 0.8, 0.22, pedra_esc(), ch=0.03)
        for k in range(8):
            bloco(px_ + ((k % 2) * 2 - 1) * 0.02, 0, 0.22 + k * 0.4, 0.84, 0.7, 0.38, M(PEDRA_A if k % 3 else PEDRA_B, 0.93, 0.8, 0.26, 7.0), ch=0.03)
    R = 1.5
    zc = 3.4
    n = 11
    for i in range(n):
        t = math.pi * (i + 0.5) / n
        # a volta se parte do lado direito: as últimas aduelas faltam, e uma está torta
        if t < 0.5:
            continue
        x, z = R * math.cos(t), zc + R * math.sin(t) * 0.95
        bloco(x, 0, z, 0.5, 0.7, 0.46, M(PEDRA_A if i % 2 else PEDRA_C, 0.93, 0.8, 0.26, 7.0), rot=(0, math.pi / 2 - t, 0), ch=0.03)
    bloco(1.2, -0.05, 0.0, 0.5, 0.45, 0.35, p, rot=(0, 0, 0.5))
    musgo(-1.5, -0.4, 0.24, 0.55, 0.2, 0.1)
    musgo(1.5, -0.4, 0.24, 0.45, 0.2, 0.1, True)
    hera(r, -1.7, -0.38, 0.3, 3.4)
    hera(r, -1.35, -0.38, 0.3, 2.3)
    hera(r, 1.4, -0.38, 0.3, 1.8)


# ------------------------------------------------------------------ pedras soltas e escombros
def bloco_pedra(r):
    p = pedra(r)
    bloco(0, 0, 0, 0.9, 0.8, 0.5, p, rot=(0, 0, 0.12), ch=0.05)
    bloco(0.08, 0.02, 0.5, 0.6, 0.55, 0.3, pedra(r), rot=(0, 0, -0.3), ch=0.05)
    musgo(-0.1, -0.35, 0.52, 0.35, 0.2, 0.1)
    musgo(0.1, 0.0, 0.8, 0.28, 0.24, 0.07, True)


def pilha_escombros(r):
    """Monte de blocos caídos de um muro: 9 pedras de tamanhos e giros diferentes."""
    pos = [(-0.5, -0.1, 0.0, 0.6), (0.2, 0.05, 0.0, 0.7), (0.65, -0.15, 0.0, 0.45), (-0.2, 0.15, 0.4, 0.5), (0.35, -0.05, 0.5, 0.45),
           (-0.65, 0.1, 0.0, 0.4), (0.0, -0.3, 0.0, 0.35), (0.1, 0.15, 0.9, 0.3), (-0.75, -0.25, 0.0, 0.3)]
    for i, (x, y, z, s) in enumerate(pos):
        bloco(x, y, z, s * r.uniform(1.0, 1.4), s * r.uniform(0.8, 1.1), s * 0.75, pedra(r),
              rot=(r.uniform(-0.15, 0.15), r.uniform(-0.15, 0.15), r.uniform(0, 3.1)), ch=0.05)
    musgo(0.0, -0.1, 0.55, 0.6, 0.35, 0.1)
    musgo(0.5, -0.3, 0.2, 0.3, 0.15, 0.08, True)
    hera(r, -0.3, -0.42, 0.2, 0.7, 3)


def laje_tombada(r):
    """Laje inclinada sobre dois blocos (dá para passar por cima do canto baixo dela)."""
    bloco(-0.7, 0.1, 0.0, 0.5, 0.5, 0.3, pedra_esc(), ch=0.04)
    bloco(0.0, 0.0, 0.18, 2.0, 1.3, 0.22, pedra(r), rot=(0.16, 0, 0.1), ch=0.04)
    bloco(0.0, 0.0, 0.15, 1.9, 1.2, 0.05, M(JUNTA, 0.9), ch=0.0, rot=(0.16, 0, 0.1))
    musgo(0.2, -0.3, 0.4, 0.8, 0.4, 0.06)
    musgo(-0.5, 0.1, 0.42, 0.4, 0.3, 0.06, True)


def degraus(r):
    """Três degraus gastos (passáveis), com musgo no meio e uma lasca faltando."""
    for i in range(3):
        bloco(0, 0.3 - i * 0.45, 0.0, 2.4 - i * 0.12, 0.45, 0.14 + i * 0.14, M([PEDRA_A, PEDRA_B, PEDRA_C][i], 0.93, 0.8, 0.26, 7.0), ch=0.03)
    musgo(0.1, -0.25, 0.3, 0.7, 0.2, 0.05)
    musgo(-0.8, 0.1, 0.18, 0.4, 0.18, 0.05, True)
    bloco(0.9, -0.5, 0.0, 0.4, 0.3, 0.12, pedra(r), rot=(0, 0, 0.6))


# ------------------------------------------------------------------ estátuas, fonte, túmulos, obelisco
def pedestal_ruina(r):
    """Pedestal sem estátua, musgo no topo e uma vela de cera gasta."""
    p = pedra(r)
    bloco(0, 0, 0, 1.0, 1.0, 0.3, pedra_esc(), ch=0.04)
    bloco(0, 0, 0.3, 0.8, 0.8, 0.75, p, ch=0.04)
    bloco(0, 0, 1.05, 0.95, 0.95, 0.16, pedra(r), ch=0.04)
    musgo(0.05, 0.0, 1.22, 0.35, 0.32, 0.06)
    musgo(0.0, -0.46, 0.22, 0.5, 0.2, 0.09, True)
    hera(r, 0.15, -0.42, 0.3, 1.1, 3)


def estatua_quebrada(r):
    """Guerreiro de pedra sem cabeça, um braço partido, sobre o pedestal; hera no corpo."""
    p = pedra(r)
    bloco(0, 0, 0, 1.0, 1.0, 0.3, pedra_esc(), ch=0.04)
    bloco(0, 0, 0.3, 0.8, 0.8, 0.6, p, ch=0.04)
    c = M(PEDRA_C, 0.9, 0.7, 0.2, 7.0)
    bloco(-0.12, 0, 0.9, 0.18, 0.2, 0.85, c, ch=0.04)                    # pernas
    bloco(0.12, 0, 0.9, 0.18, 0.2, 0.85, c, ch=0.04)
    bloco(0, 0, 1.7, 0.5, 0.28, 0.7, c, ch=0.05)                         # torso com a túnica
    bloco(0, 0, 1.55, 0.58, 0.3, 0.3, pedra(r), ch=0.05)
    bloco(-0.34, 0, 1.95, 0.14, 0.14, 0.4, c, ch=0.03)                   # braço esquerdo
    bloco(0.34, -0.02, 2.2, 0.14, 0.14, 0.12, c, rot=(0, 0, 0.5), ch=0.03)  # o outro, em toco
    bloco(0, 0, 2.38, 0.16, 0.16, 0.14, c, ch=0.03)                      # o pescoço que sobrou
    bloco(0.5, -0.55, 0.0, 0.34, 0.3, 0.3, c, rot=(0, 0, 0.4), ch=0.05)    # a cabeça rolou: um bloco redondo no chão
    esfera("cabeca", 0.17, (0.62, -0.62, 0.2), c)
    musgo(0.0, -0.2, 0.92, 0.35, 0.2, 0.06)
    musgo(0.0, -0.46, 0.34, 0.45, 0.2, 0.08, True)
    hera(r, -0.15, -0.16, 0.9, 2.2)
    hera(r, 0.2, -0.16, 0.9, 1.7, 5)


def fonte_seca(r):
    """Bacia circular de 2,6 m de pedra, seca e cheia de folhas e musgo, com um pé de coluna no meio."""
    p = pedra(r)
    n = 14
    for i in range(n):
        t = 2 * math.pi * i / n
        bloco(1.1 * math.cos(t), 1.1 * math.sin(t), 0.0, 0.62, 0.42, 0.72 if i != 3 else 0.4, p, rot=(0, 0, t + math.pi / 2), ch=0.04)
    C(1.05, 0.12, 0, 0, 0.0, M(TERRA, 1.0, 0.3, 0.3, 12.0), v=18)
    C(0.2, 0.7, 0, 0, 0.1, pedra(r), v=10, ch=0.02)
    C(0.34, 0.12, 0, 0, 0.8, pedra_esc(), v=12)
    musgo(0.1, -0.1, 0.12, 0.8, 0.6, 0.06)
    musgo(0.3, -1.12, 0.74, 0.5, 0.15, 0.07, True)
    musgo(-0.7, 0.5, 0.12, 0.35, 0.3, 0.05, True)


def sarcofago(r):
    """Sarcófago de pedra com a tampa deslocada e rachada; musgo e hera na frente."""
    p = pedra(r)
    bloco(0, 0, 0, 0.95, 2.05, 0.6, p, ch=0.05)
    bloco(0.0, 0.0, 0.0, 1.0, 2.1, 0.12, pedra_esc(), ch=0.04)
    bloco(0.08, 0.12, 0.6, 0.9, 1.9, 0.26, pedra(r), rot=(0, 0, 0.05), ch=0.06)
    bloco(0.0, -0.1, 0.84, 0.5, 1.2, 0.08, pedra_esc(), rot=(0, 0, 0.05), ch=0.03)
    B(0.04, 1.4, 0.04, 0.12, 0.1, 0.87, M(JUNTA, 0.9), ch=0.0)
    musgo(-0.1, -0.5, 0.88, 0.3, 0.45, 0.06)
    musgo(0.0, -1.0, 0.45, 0.5, 0.15, 0.1, True)
    hera(r, 0.2, -1.05, 0.15, 0.9, 4)


def obelisco_runico(r):
    """Obelisco de 4 m com as runas brilhando em azul-gelo (a luz azul do jogo sai daqui)."""
    p = pedra(r)
    bloco(0, 0, 0, 1.0, 1.0, 0.3, pedra_esc(), ch=0.04)
    bloco(0, 0, 0.3, 0.74, 0.74, 0.3, p, ch=0.04)
    px3.cone("obelisco", 0.46, 0.22, 3.0, (0, 0, 0.6 + 1.5), M(PEDRA_B, 0.92, 0.7, 0.22, 7.0), vertices=4)
    bloco(0, 0, 3.55, 0.3, 0.3, 0.2, p, ch=0.03)
    px3.cone("ponta", 0.2, 0.0, 0.42, (0, 0, 3.75 + 0.21), p, vertices=4)
    em = E(RUNA, 3.2)
    for k, (zz, w, s) in enumerate([(1.0, 0.18, 0), (1.45, 0.1, 1), (1.85, 0.2, 0), (2.25, 0.12, 1), (2.6, 0.16, 0)]):
        B(w, 0.03, 0.06, s * 0.05, -0.37 + (zz - 0.6) * 0.058, zz, em, ch=0.0)
        B(0.05, 0.03, 0.2, (-1 if k % 2 else 1) * 0.1, -0.36 + (zz - 0.6) * 0.058, zz - 0.06, em, ch=0.0)
    musgo(0, -0.4, 0.34, 0.5, 0.2, 0.1)
    musgo(0.4, 0.0, 0.34, 0.2, 0.4, 0.09, True)
    hera(r, -0.28, -0.4, 0.3, 1.1, 4)


def lapide_antiga(r):
    """Lápide torta de pedra clara, musgo na base."""
    p = pedra(r)
    bloco(0, 0, 0, 0.7, 0.35, 0.12, pedra_esc(), rot=(0, 0, 0.1), ch=0.03)
    bloco(0, 0, 0.1, 0.5, 0.2, 0.85, p, rot=(0.05, 0.08, 0.1), ch=0.05)
    bloco(0.0, -0.1, 0.78, 0.1, 0.04, 0.16, M(PEDRA_ESC, 0.95), ch=0.0)
    musgo(0, -0.18, 0.12, 0.35, 0.15, 0.1)


def cacos_pedra(r):
    """Cacos pequenos e lascas de pedra no chão (passável)."""
    for i in range(6):
        s = r.uniform(0.1, 0.25)
        bloco(r.uniform(-0.45, 0.45), r.uniform(-0.2, 0.2), 0.0, s * 1.4, s, s * 0.6, pedra(r), rot=(0, 0, r.uniform(0, 3)), ch=0.03)
    musgo(0.0, 0.0, 0.06, 0.5, 0.25, 0.04)


def samambaia(r):
    """Tufo de samambaia crescendo entre as lajes (passável)."""
    verde = [M(HERA, 0.9, 0.2, 0.2, 18.0), M(HERA_ESC, 0.9, 0.2, 0.2, 18.0), M("57925a", 0.9, 0.2, 0.2, 18.0)]
    for i in range(9):
        t = 2 * math.pi * i / 9 + r.uniform(-0.2, 0.2)
        L = r.uniform(0.35, 0.55)
        esfera("fronde", 1.0, (0.18 * math.cos(t), 0.12 * math.sin(t) - 0.02, 0.2 + 0.05 * (i % 3)), verde[i % 3],
               escala=(L * 0.55, L * 0.32, 0.06))
    for i in range(5):
        esfera("fronde", 1.0, (r.uniform(-0.1, 0.1), r.uniform(-0.08, 0.08), 0.32 + 0.04 * i), verde[(i + 1) % 3], escala=(0.14, 0.1, 0.07))


def cranio_antigo(r):
    """Crânio e ossos entre as pedras (passável)."""
    osso = M(OSSO, 0.9, 0.2, 0.2, 14.0)
    esfera("cranio", 0.16, (0, 0, 0.14), osso, escala=(1.0, 1.1, 0.9))
    B(0.14, 0.12, 0.08, 0, -0.1, 0.04, osso, ch=0.02)
    for i, (x, y, rz) in enumerate([(0.4, 0.1, 0.4), (-0.35, 0.18, -0.3), (0.25, -0.2, 1.1)]):
        B(0.32, 0.05, 0.05, x, y, 0.03, osso, ch=0.02, rot=(0, 0, rz))
    musgo(0.0, 0.1, 0.02, 0.4, 0.22, 0.03)


OBJETOS = {
    "coluna_alta": tela(0.9, 0.9, 4.2, coluna_alta, extra_h=0.2),
    "coluna_quebrada": tela(0.9, 0.9, 2.3, coluna_quebrada),
    "base_coluna": tela(0.9, 0.9, 1.1, base_coluna),
    "coluna_caida": tela(3.9, 1.0, 0.9, coluna_caida),
    "tambor_coluna": tela(0.9, 0.9, 0.9, tambor_coluna),
    "muro_ruina_a": tela(3.2, 0.6, 2.4, muro_ruina_a, extra_h=0.35),
    "muro_ruina_b": tela(2.4, 0.6, 1.5, muro_ruina_b, extra_h=0.35),
    "muro_ruina_c": tela(2.8, 0.6, 0.7, muro_ruina_c, extra_h=0.2),
    "muro_alto": tela(3.4, 0.8, 3.8, muro_alto, extra_h=0.35),
    "arco_ruina": tela(4.2, 0.8, 4.7, arco_ruina, extra_h=0.35),
    "bloco_pedra": tela(1.0, 0.9, 0.9, bloco_pedra),
    "pilha_escombros": tela(1.8, 1.0, 1.3, pilha_escombros),
    "laje_tombada": tela(2.2, 1.4, 0.8, laje_tombada),
    "degraus": tela(2.4, 1.4, 0.5, degraus),
    "pedestal_ruina": tela(1.0, 1.0, 1.4, pedestal_ruina),
    "estatua_quebrada": tela(1.3, 1.3, 2.6, estatua_quebrada),
    "fonte_seca": tela(2.7, 2.7, 1.0, fonte_seca),
    "sarcofago": tela(1.1, 2.2, 1.0, sarcofago),
    "obelisco_runico": tela(1.0, 1.0, 4.2, obelisco_runico),
    "lapide_antiga": tela(0.8, 0.4, 1.1, lapide_antiga),
    "cacos_pedra": tela(1.1, 0.6, 0.3, cacos_pedra),
    "samambaia": tela(1.0, 0.6, 0.5, samambaia),
    "cranio_antigo": tela(1.0, 0.6, 0.3, cranio_antigo),
}


# ------------------------------------------------------------------ piso: lajes grandes e irregulares, musgo e terra nas juntas, 16 m de lado
def piso_ruina(r):
    N = 16
    junta = M("4d4f4b", 1.0, 0.5, 0.4, 10.0)
    B(N, N, 0.1, N / 2.0, N / 2.0, -0.1, junta, ch=0.0)
    tons = [M(h, 0.95, 0.6, 0.26, 6.0) for h in ("5f6872", "6a737d", "555e68", "737c86", "4d565f")]
    verdes = [M(MUSGO, 1.0, 0.5, 0.35, 12.0), M(MUSGO_ESC, 1.0, 0.5, 0.35, 12.0), M("5d7d44", 1.0, 0.5, 0.35, 14.0)]
    # lajes de 2 x 1 / 1 x 1 / 1 x 2 m, arrumadas por uma grade de 16 x 16 ocupada por tentativa; as que sobram ficam como terra com musgo
    ocupado = [[False] * N for _ in range(N)]
    formas = [(2, 2), (2, 1), (1, 2), (2, 2), (3, 2), (2, 3), (1, 1)]
    for j in range(N):
        for i in range(N):
            if ocupado[i][j]:
                continue
            if r.random() < 0.34:   # buraco de terra com musgo e erva
                ocupado[i][j] = True
                c = r.choice(verdes)
                B(1.0, 1.0, 0.05 + r.random() * 0.02, i + 0.5, j + 0.5, 0.0, c, ch=0.03)
                for _ in range(r.randrange(2, 5)):
                    esfera("tufo", 1.0, (i + r.uniform(0.15, 0.85), j + r.uniform(0.15, 0.85), 0.08), r.choice(verdes), escala=(0.2, 0.2, 0.05))
                continue
            for w, h in r.sample(formas, len(formas)):
                if i + w <= N and j + h <= N and all(not ocupado[i + a][j + b] for a in range(w) for b in range(h)):
                    break
            else:
                w, h = 1, 1
            for a in range(w):
                for b in range(h):
                    ocupado[i + a][j + b] = True
            alt = 0.06 + r.random() * 0.03
            B(w - 0.05, h - 0.05, alt, i + w / 2.0, j + h / 2.0, 0.0, r.choice(tons), ch=0.03)
            if r.random() < 0.3:   # musgo cobrindo um canto da laje
                esfera("musgo", 1.0, (i + r.uniform(0.2, w - 0.2), j + r.uniform(0.2, h - 0.2), alt), r.choice(verdes),
                       escala=(r.uniform(0.15, 0.4), r.uniform(0.12, 0.3), 0.03))
            if r.random() < 0.12:  # rachadura: uma fenda fina escura
                B(r.uniform(0.3, w * 0.8), 0.03, 0.01, i + w / 2.0, j + h / 2.0 + r.uniform(-0.2, 0.2), alt, M(JUNTA, 0.9), ch=0.0,
                  rot=(0, 0, r.uniform(-0.6, 0.6)))


PISO = (16, piso_ruina)

"""Cidade da v2: caçamba, contêineres, barricadas, sacos de areia, pneus, entulho, muros e o ponto de ônibus. Origem no chão, no centro da pegada,
frente para -Y (veja cidade_pecas.py)."""
import math

import bpy

from cidade_pecas import CONCRETO, CR, FERRUGEM, MADEIRA_VELHA, METAL_ESC, E, M, metal, tijolo, toro
from mapas_v2 import B, C, barra, vidro


def _saco(x, y, z, sx, sy, sz, rz, mat):
    """Saco de areia: elipsoide liso, deitado."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=10, radius=1.0, location=(x, y, z))
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    o.rotation_euler = (0.0, 0.0, rz)
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    return o


def sacos_areia(r):
    """Muro baixo de sacos de areia empilhados (3 fileiras desencontradas), alguns rasgados com areia no chão."""
    cores = ["6f6446", "7a6e4e", "5f563c", "857850"]
    B(2.7, 0.5, 0.07, 0, 0, 0.0, M("221d14", 0.95), ch=0.0)
    for fila, (n, z, desloc) in enumerate(((7, 0.13, 0.0), (6, 0.37, 0.18), (5, 0.6, 0.0))):
        larg = 2.5 / 7.0
        for k in range(n):
            x = -1.25 + larg * (k + 0.5) + (0.18 if fila == 1 else 0.0) + r.uniform(-0.03, 0.03)
            if fila == 1 and k == n - 1:
                continue
            _saco(x, r.uniform(-0.04, 0.04), z + r.uniform(-0.02, 0.02), larg * 0.62, 0.3, 0.17, r.uniform(-0.12, 0.12),
                  M(r.choice(cores), 0.95, 0.4, 0.25, 12.0))
    for k in range(9):   # areia derramada no pé
        B(r.uniform(0.08, 0.2), r.uniform(0.06, 0.14), 0.03, r.uniform(-1.3, 1.3), -0.42 - r.uniform(0, 0.15), 0.0, M("9a8a62", 0.95, 0.4, 0.3), ch=0.01,
          rot=(0, 0, r.uniform(0, 3)))
    B(0.5, 0.02, 0.2, 0.3, -0.31, 0.45, M("3a3226", 0.9), ch=0.0)


def _jersey(x, y, ang, r, cor="7a7c7c"):
    """Barreira de concreto (jersey): três degraus, faixa refletiva gasta no topo, rachaduras."""
    c = M(cor, 0.9, 0.5, 0.3, 4.0)
    B(2.0, 0.62, 0.26, x, y, 0.0, c, ch=0.04, rot=(0, 0, ang))
    B(2.0, 0.44, 0.3, x, y, 0.26, c, ch=0.04, rot=(0, 0, ang))
    B(2.0, 0.28, 0.32, x, y, 0.56, c, ch=0.04, rot=(0, 0, ang))
    ca, sa = math.cos(ang), math.sin(ang)
    for k in range(5):   # faixas diagonais vermelho/branco na frente do topo
        dx = -0.8 + k * 0.4
        B(0.2, 0.012, 0.2, x + dx * ca + 0.15 * sa, y + dx * sa - 0.15 * ca, 0.62, M("a8302a" if k % 2 == 0 else "c4c0b0", 0.7, 0.3, 0.3), ch=0.0,
          rot=(0, 0, ang))
    for k in range(3):
        dx = r.uniform(-0.8, 0.8)
        B(0.04, 0.012, r.uniform(0.15, 0.4), x + dx * ca + 0.2 * sa, y + dx * sa - 0.2 * ca, r.uniform(0.1, 0.4), M("26282a", 0.9), ch=0.0, rot=(0, 0, ang))
    for k in range(2):   # ferro de armação exposto na ponta
        barra((x + 1.0 * ca, y + 1.0 * sa, 0.5 + 0.1 * k), (x + 1.2 * ca, y + 1.2 * sa, 0.55 + 0.2 * k), 0.012, M(FERRUGEM, 0.8, 0.4, 0.4), v=6)


def barricada_concreto(r):
    _jersey(-1.05, 0.05, 0.1, r)
    _jersey(1.05, -0.05, -0.08, r, "6c7070")
    for k in range(4):   # pedaços caídos
        B(r.uniform(0.1, 0.25), r.uniform(0.08, 0.2), r.uniform(0.05, 0.12), r.uniform(-1.8, 1.8), -0.5 - r.uniform(0, 0.25), 0.0, M(CONCRETO, 0.9, 0.5, 0.3),
          ch=0.02, rot=(0, 0, r.uniform(0, 3)))


def barricada_madeira(r):
    """Cavaletes de madeira cruzados com tábuas, um pallet encostado e arame farpado no topo."""
    mad = M(MADEIRA_VELHA, 0.9, 0.55, 0.35, 14.0)
    mad2 = M("6a5238", 0.9, 0.5, 0.35, 14.0)
    for sx in (-1.15, 1.15):
        for s in (-1, 1):   # as pernas em X
            B(0.1, 0.1, 1.6, sx + s * 0.02, 0.0, 0.0, mad, ch=0.01, rot=(0, s * 0.42, 0))
        B(0.1, 0.12, 0.1, sx, 0.0, 1.25, mad2, ch=0.01)
    for k, z in enumerate((0.3, 0.62, 0.95, 1.22)):   # tábuas atravessadas, algumas faltando
        if k == 2 and r.random() < 0.5:
            continue
        B(2.9, 0.06, 0.14, r.uniform(-0.05, 0.05), -0.1 - 0.02 * k, z, mad if k % 2 else mad2, ch=0.01, rot=(0, r.uniform(-0.03, 0.03), 0))
    # pallet em pé, encostado
    for k in range(4):
        B(1.0, 0.04, 0.1, -0.1, -0.3, 0.1 + k * 0.28, mad2, ch=0.005, rot=(-0.12, 0, 0))
    for x in (-0.55, -0.1, 0.35):
        B(0.1, 0.06, 1.0, x, -0.28, 0.1, mad, ch=0.005, rot=(-0.12, 0, 0))
    # arame farpado no topo
    barra((-1.45, -0.1, 1.45), (1.45, -0.1, 1.5), 0.012, M("1a1b1d", 0.5), v=6)
    barra((-1.45, -0.14, 1.52), (1.45, -0.14, 1.46), 0.012, M("1a1b1d", 0.5), v=6)
    for k in range(14):
        B(0.03, 0.03, 0.08, -1.4 + k * 0.21, -0.12, 1.45 + 0.02 * (k % 2), M("2a2b2d", 0.5), ch=0.0, rot=(0, 0, k))
    B(0.16, 0.012, 0.3, 0.7, -0.14, 0.5, M("a8302a", 0.9, 0.3, 0.3), ch=0.0)    # restos de tinta vermelha


def pneus(r):
    """Pilha de pneus velhos, mais dois deitados em volta."""
    bor = M("17181a", 0.9, 0.4, 0.4, 8.0)
    for k in range(4):
        toro(0.27, 0.115, (r.uniform(-0.03, 0.03), r.uniform(-0.03, 0.03), 0.115 + k * 0.23), bor, seg=18, seg_menor=8)
        C(0.2, 0.02, 0, 0, 0.0 + 0.23 * k + 0.2, M("0b0b0c", 0.9), v=14)
    toro(0.27, 0.115, (0.65, -0.1, 0.115), bor, seg=18, seg_menor=8)
    toro(0.27, 0.115, (0.6, 0.35, 0.115), bor, seg=18, seg_menor=8)
    toro(0.27, 0.115, (-0.55, -0.35, 0.275), bor, rot=(1.1, 0.2, 0.0), seg=18, seg_menor=8)
    for k in range(2):
        B(0.04, 0.012, 0.1, 0.0, -0.3, 0.1 + 0.23 * k, M("c9c6b4", 0.7), ch=0.0)


def cacamba(r):
    """Caçamba de entulho de ferro verde, enferrujada e transbordando lixo e entulho."""
    verde = metal("3d5a46", 0.5, 0.35, 0.3, 8.0)
    esc = metal("22342a", 0.55, 0.3, 0.3, 8.0)
    ferr = M(FERRUGEM, 0.8, 0.5, 0.4, 10.0)
    L, W = 2.4, 1.2
    for y in (-0.4, 0.4):   # esquis
        B(L + 0.3, 0.1, 0.1, 0, y, 0.0, esc, ch=0.01)
    B(L, W, 0.06, 0, 0, 0.1, esc, ch=0.0)
    B(L, 0.07, 1.0, 0, -W / 2 + 0.03, 0.12, verde, ch=0.01, rot=(0.1, 0, 0))
    B(L, 0.07, 1.0, 0, W / 2 - 0.03, 0.12, verde, ch=0.01, rot=(-0.1, 0, 0))
    B(0.07, W, 1.0, -L / 2 + 0.03, 0, 0.12, verde, ch=0.01, rot=(0, -0.1, 0))
    B(0.07, W, 1.0, L / 2 - 0.03, 0, 0.12, verde, ch=0.01, rot=(0, 0.1, 0))
    for k in range(8):   # nervuras da frente
        B(0.07, 0.05, 0.9, -L / 2 + 0.2 + k * (L - 0.4) / 7.0, -W / 2 - 0.04, 0.16, esc, ch=0.005, rot=(0.1, 0, 0))
    B(L + 0.12, 0.09, 0.09, 0, -W / 2 - 0.1, 1.07, esc, ch=0.01)           # borda de cima
    B(L + 0.12, 0.09, 0.09, 0, W / 2 + 0.08, 1.07, esc, ch=0.01)
    for k in range(6):   # faixa refletiva amarela e preta
        B(0.2, 0.012, 0.16, -0.5 + k * 0.2, -W / 2 - 0.085, 0.2, M("c8a020" if k % 2 == 0 else "14161a", 0.7), ch=0.0)
    for k in range(9):
        B(r.uniform(0.1, 0.4), 0.012, r.uniform(0.05, 0.3), r.uniform(-1.0, 1.0), -W / 2 - 0.08, r.uniform(0.3, 0.9), ferr, ch=0.0)
    for s in (-1, 1):   # olhais de içamento
        CR(0.08, 0.04, s * (L / 2 + 0.05), -0.3, 0.9, esc, (0, math.pi / 2, 0), v=10)
    # carga que passa da borda: sacos, tábuas, caixas
    cores = ["2a2e32", "5a6a56", "7a6a4a", "6a3a30", "9a9890", "3a3f45"]
    for k in range(16):
        B(r.uniform(0.15, 0.5), r.uniform(0.12, 0.4), r.uniform(0.08, 0.3), r.uniform(-1.0, 1.0), r.uniform(-0.45, 0.4), 1.0 + r.uniform(0, 0.25),
          M(r.choice(cores), 0.9, 0.3, 0.3), ch=0.03, rot=(r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), r.uniform(0, 3)))
    barra((0.2, 0.0, 1.0), (0.8, -0.3, 1.5), 0.03, M(MADEIRA_VELHA, 0.9), v=6)
    barra((-0.5, 0.1, 1.0), (-0.2, -0.2, 1.4), 0.03, M(MADEIRA_VELHA, 0.9), v=6)


def _container(r, cor, ferrugem=0.4, aberto=False):
    L, W, H = 6.0, 2.4, 2.5
    pint = M(cor, 0.55, 0.3, 0.3, 6.0)
    pint2 = M(cor, 0.6, 0.35, 0.4, 5.0)
    esc = metal("22262b", 0.5, 0.3, 0.3)
    B(L, W, H, 0, 0, 0.1, pint, ch=0.03)
    n = 26
    for k in range(n):   # chapa ondulada na frente
        B(0.1, 0.045, H - 0.3, -L / 2 + (k + 0.5) * L / n, -W / 2 - 0.02, 0.25, pint2 if k % 2 else pint, ch=0.005)
    B(L + 0.05, 0.1, 0.14, 0, -W / 2 - 0.04, H - 0.04, esc, ch=0.01)
    B(L + 0.05, 0.1, 0.14, 0, -W / 2 - 0.04, 0.1, esc, ch=0.01)
    for s in (-1, 1):
        B(0.18, 0.12, H, s * (L / 2 - 0.09), -W / 2 - 0.05, 0.1, esc, ch=0.01)
    for k in range(9):   # ondulação do teto
        B(L - 0.3, 0.1, 0.03, 0, -W / 2 + 0.2 + k * (W - 0.4) / 8.0, H + 0.1, pint2, ch=0.0)
    # etiquetas e marcas
    B(0.9, 0.012, 0.5, -1.9, -W / 2 - 0.07, 1.8, M("b9b6a4", 0.7, 0.3, 0.3), ch=0.0)
    B(0.8, 0.012, 0.08, -1.9, -W / 2 - 0.08, 1.95, M("20262c", 0.7), ch=0.0)
    B(0.6, 0.012, 0.08, -1.9, -W / 2 - 0.08, 1.75, M("20262c", 0.7), ch=0.0)
    B(0.35, 0.012, 0.25, 1.5, -W / 2 - 0.07, 1.9, M("a8302a", 0.8, 0.3, 0.3), ch=0.0)
    ferr = M(FERRUGEM, 0.85, 0.5, 0.4, 10.0)
    for k in range(int(8 + 12 * ferrugem)):   # ferrugem escorrida
        c = r.uniform(0.3, 1.1)
        B(r.uniform(0.06, 0.18), 0.012, c, r.uniform(-2.8, 2.8), -W / 2 - 0.07, r.uniform(0.3 + c, H - 0.2), ferr if r.random() < 0.8 else M("4a2a1a", 0.9, 0.4, 0.4),
          ch=0.0)
    B(0.9, 0.03, 0.5, 0.9, -W / 2 - 0.06, 0.9, M("20262a", 0.7, 0.4, 0.4), ch=0.0, rot=(0, 0, 0.0))     # chapa amassada
    if aberto:   # porta aberta na ponta: fundo escuro
        B(0.05, W - 0.3, H - 0.3, L / 2 + 0.01, 0, 0.25, M("07090b", 1.0), ch=0.0)


def container_a(r):
    _container(r, "35566e", 0.4)


def container_b(r):
    _container(r, "7a3a2a", 0.7)


def _pilha(r, raio, n, alt, cores=None, ferros=4):
    cores = cores or [CONCRETO, "5a5750", "7a4034", "46484b", "6f4a3c", "8a8a84"]
    for k in range(n):
        a = r.uniform(0, 6.28)
        d = abs(r.gauss(0.0, raio * 0.45))
        x, y = d * math.cos(a), d * math.sin(a) * 0.8
        s = r.uniform(0.12, 0.42)
        z = max(0.0, alt * (1.0 - math.hypot(x, y / 0.8) / raio) * r.uniform(0.0, 1.0))
        B(s, s * r.uniform(0.6, 1.2), s * r.uniform(0.3, 0.8), x, y, z, M(r.choice(cores), 0.9, 0.5, 0.3), ch=0.03,
          rot=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4), r.uniform(0, 3)))
    for k in range(ferros):
        a = r.uniform(0, 6.28)
        d = r.uniform(0.0, raio * 0.6)
        x, y = d * math.cos(a), d * math.sin(a) * 0.8
        barra((x, y, alt * 0.5), (x + r.uniform(-0.3, 0.3), y + r.uniform(-0.2, 0.2), alt * 0.5 + r.uniform(0.3, 0.7)), 0.014, M(FERRUGEM, 0.8, 0.4, 0.4), v=6)


def entulho_a(r):
    _pilha(r, 0.7, 14, 0.35, ferros=3)


def entulho_b(r):
    _pilha(r, 1.4, 38, 0.8, ferros=7)
    B(1.3, 0.8, 0.12, 0.3, -0.2, 0.55, M(CONCRETO, 0.9, 0.5, 0.3), ch=0.02, rot=(0.4, 0.1, 0.2))     # laje inclinada


def muro_tijolo(r, quebrado=False):
    """Muro de tijolo de 3 m com capa de concreto, grafite e arame farpado; o quebrado tem um vão aberto e tijolos no pé."""
    w, d, h = 3.0, 0.4, 2.0
    yf = -d / 2
    B(w, d, h, 0, 0, 0, tijolo("6e4638", "593228", "35302d"), ch=0.02)
    B(w + 0.1, d + 0.1, 0.1, 0, 0, h, M(CONCRETO, 0.9, 0.5, 0.3), ch=0.02)
    for x in (-1.4, 0.0, 1.4):   # pilares
        B(0.3, 0.12, h, x, yf - 0.06, 0.0, M("6a6a66", 0.9, 0.5, 0.3, 4.0), ch=0.02)
    for k, cor in enumerate(("c8a020", "b8307a", "2f8fbf")):   # grafite
        B(r.uniform(0.3, 0.7), 0.012, 0.12, -0.9 + k * 0.7, yf - 0.1, 0.9 + 0.2 * (k % 2), M(cor, 0.8, 0.2, 0.3), ch=0.0, rot=(0, r.uniform(-0.3, 0.3), 0))
    if quebrado:
        B(0.9, d + 0.02, 1.25, 0.6, 0, 0.0, M("060809", 1.0), ch=0.0)      # vão escuro (o "buraco" mostra o lado de dentro)
        B(0.95, d + 0.1, 0.14, 0.6, 0, 1.25, M("5a3226", 0.9, 0.5, 0.3), ch=0.03, rot=(0, 0, 0.0))
        for k in range(14):
            B(r.uniform(0.15, 0.3), r.uniform(0.1, 0.2), r.uniform(0.07, 0.12), 0.6 + r.uniform(-0.8, 0.8), yf - r.uniform(0.1, 0.6), 0.0,
              M(r.choice(["7a4034", "6a3a30", "5a5750"]), 0.9, 0.5, 0.3), ch=0.02, rot=(0, 0, r.uniform(0, 3)))
    # arame farpado: hastes inclinadas e três fios
    for x in (-1.45, -0.5, 0.5, 1.45):
        barra((x, 0, h + 0.1), (x, -0.16, h + 0.5), 0.015, M("26282a", 0.5), v=6)
    for k in range(3):
        barra((-1.45, -0.04 - 0.04 * k, h + 0.2 + 0.1 * k), (1.45, -0.04 - 0.04 * k, h + 0.2 + 0.1 * k), 0.008, M("1a1b1d", 0.5), v=5)
    for k in range(10):
        B(0.1, 0.012, 0.35, -1.3 + k * 0.28 + r.uniform(-0.05, 0.05), yf - 0.01, 0.3 + r.uniform(0, 1.3), M("1a1512", 0.95, 0.3, 0.3), ch=0.0)


def muro_quebrado(r):
    muro_tijolo(r, quebrado=True)


def ponto_onibus(r):
    """Abrigo de ponto de ônibus: teto, painel de propaganda ACESO (luz fria), vidros trincados, banco de ripas e a placa na haste."""
    aco = metal(METAL_ESC, 0.45, 0.25, 0.25)
    for sx in (-1.5, 1.5):
        B(0.09, 0.09, 2.3, sx, 0.45, 0.0, aco, ch=0.01)
        B(0.09, 0.09, 2.2, sx, -0.45, 0.0, aco, ch=0.01)
    B(3.4, 1.3, 0.1, 0, 0, 2.3, metal("1c1f23", 0.5, 0.3, 0.2), ch=0.02, rot=(0.04, 0, 0))
    B(3.4, 0.08, 0.1, 0, -0.65, 2.25, aco, ch=0.01)
    # fundo: painel de propaganda aceso e vidro trincado
    B(1.3, 0.12, 1.9, 0.75, 0.46, 0.1, metal("1c1f23", 0.5, 0.3, 0.2), ch=0.015)
    B(1.15, 0.02, 1.7, 0.75, 0.39, 0.2, E("cfe2ff", 1.1), ch=0.0)
    B(0.8, 0.012, 0.6, 0.75, 0.375, 0.9, M("7a2a4a", 0.7), ch=0.0)
    B(0.5, 0.012, 0.15, 0.75, 0.375, 0.6, M("e8e6d8", 0.6), ch=0.0)
    B(0.25, 0.012, 0.5, 1.1, 0.375, 0.95, M("2f6a8a", 0.7), ch=0.0, rot=(0, 0.3, 0))
    B(1.3, 0.04, 1.9, -0.8, 0.46, 0.1, vidro("2a4a58"), ch=0.0)
    for k in range(6):
        B(r.uniform(0.2, 0.6), 0.012, 0.015, -1.2 + r.uniform(0, 0.8), 0.43, 0.4 + r.uniform(0, 1.4), M("a8c6d0", 0.2), ch=0.0, rot=(0, r.uniform(-1, 1), 0))
    B(0.04, 0.9, 1.9, -1.5, 0.0, 0.1, vidro("2a4a58"), ch=0.0)
    # banco de ripas
    B(1.4, 0.4, 0.05, -0.55, 0.15, 0.5, M(MADEIRA_VELHA, 0.9, 0.5, 0.3, 14.0), ch=0.01)
    for sx in (-1.2, 0.1):
        B(0.05, 0.4, 0.5, sx, 0.15, 0.0, aco, ch=0.01)
    # placa na haste, ao lado
    C(0.04, 2.6, 1.95, -0.2, 0.0, aco, v=10)
    CR(0.3, 0.03, 1.95, -0.26, 2.3, M("2a5a9a", 0.5, 0.2, 0.2), (math.pi / 2, 0, 0), v=18)
    B(0.34, 0.012, 0.18, 1.95, -0.285, 2.28, M("e8e6d8", 0.6), ch=0.0)
    for k in range(5):
        B(r.uniform(0.1, 0.25), r.uniform(0.1, 0.2), 0.03, r.uniform(-1.2, 1.2), -0.4 - r.uniform(0, 0.3), 0.0, M(r.choice(["b0a98a", "8a8a84", "4a6a4a"]), 0.9), ch=0.01,
          rot=(0, 0, r.uniform(0, 3)))
    # propaganda rasgada na lateral
    B(0.5, 0.012, 0.7, -1.55, -0.1, 0.9, M("b9b6a4", 0.95, 0.3, 0.3), ch=0.0, rot=(0, 0, 0.0))

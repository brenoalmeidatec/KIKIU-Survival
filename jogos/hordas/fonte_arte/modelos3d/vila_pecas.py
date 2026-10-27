"""Vila Amaldiçoada da v2 (id interno "cidade"): peças comuns (cores, materiais com cache), objetos de rua, carroças e adereços. As casas ficam em
vila_casas.py e o piso em vila_piso.py; quem junta tudo e diz o tamanho da tela de cada objeto é mapa_cidade.py (lido por mapas_v2.py).

Cada função monta UM objeto com a origem no chão, no centro da pegada, a frente voltada para -Y. Medidas em metros (1 m = 32 px na horizontal e
22,6 px na vertical); as medidas e as luzes ficam em mapas_v2/medidas_cidade.py (Python puro, lido também pelo def_cidade.py), que são as mesmas de
antes da #429: o que era cidade pós-apocalíptica (concreto, tijolo, carros, neon, semáforo, contêiner) virou vila medieval amaldiçoada (pedra e madeira,
telhado de telha e palha, lampiões, carroças, barracas, poço, barricadas de estacas), sem mexer em nomes, pegadas nem planta.
"""
import math

import bpy

from mapas_v2 import B, C, barra, cilindro, esfera, px3, vidro

# ------------------------------------------------------------------ cores
PEDRA = "77716a"
PEDRA_ESC = "4a4642"
PEDRA_CLARA = "958e82"
MADEIRA = "5a3f28"
MADEIRA_ESC = "3a281a"
MADEIRA_CLARA = "7d5c3a"
REBOCO = "b7a98a"
REBOCO_ESC = "8f8268"
TELHA = "633328"
TELHA_ESC = "492319"
PALHA = "a88b4c"
FERRO = "2d3034"
FERRO_CLARO = "5a5e64"
LATAO = "c9a24a"
LONA = "b3a784"
LONA_ESC = "6e3030"
VELA = "ffb257"
VERMELHO = "e0453a"
ROXO = "a678f0"
AZUL = "58b8ff"
VERDE = "5fe08a"
CARVAO = "1c1816"
MUSGO = "46633a"


# ------------------------------------------------------------------ materiais (com cache por nome: a cena tem centenas de caixas)
def M(hexa, rug=0.85, relevo=0.0, var=0.0, escala=6.0):
    nome = "vm_%s_%s_%s_%s_%s" % (hexa, rug, relevo, var, escala)
    m = bpy.data.materials.get(nome)
    if m is None:
        m = px3.material_suave(nome, px3.cor(hexa), rugosidade=rug, relevo=relevo, variacao=var, escala=escala)
    return m


def E(hexa, forca=1.6):
    """Material que brilha sozinho (janela, lampião, vela): só pinta o pixel; a luz e o halo no chão são do jogo."""
    nome = "ve_%s_%s" % (hexa, forca)
    m = bpy.data.materials.get(nome)
    if m is None:
        m = px3.material_emissao(nome, px3.cor(hexa), forca)
    return m


def pedra(c=PEDRA):
    return M(c, 0.93, 0.8, 0.26, 6.0)


def madeira(c=MADEIRA):
    return M(c, 0.88, 0.5, 0.3, 14.0)


def ferro():
    nome = "vmf"
    m = bpy.data.materials.get(nome)
    if m is None:
        m = px3.material_suave(nome, px3.cor(FERRO), rugosidade=0.5, relevo=0.2, variacao=0.14, escala=8.0)
        m.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.5
    return m


def CR(r, h, x, y, z, mat, rot, v=16, nome="cilindro"):
    """Cilindro DEITADO (rot) com o CENTRO em (x, y, z): roda, barril de lado, tora."""
    return cilindro(nome, r, h, (x, y, z), mat, vertices=v, rot=rot)


def girar(antes, ang):
    """Gira em torno do eixo Z (pela origem) tudo que foi criado desde 'antes'."""
    from mathutils import Matrix
    bpy.context.view_layer.update()
    rz = Matrix.Rotation(ang, 4, "Z")
    for o in list(bpy.data.objects):
        if o.name not in antes and o.type == "MESH":
            o.matrix_world = rz @ o.matrix_world


def vira(f, ang):
    """Versão do objeto f girada em ang (para as carroças no sentido de Y)."""
    def g(r):
        antes = set(bpy.data.objects.keys())
        f(r)
        girar(antes, ang)
    g.__name__ = f.__name__ + "_girado"
    return g


def lanterna(x, y, z, cor=VELA, forca=3.0, esc=1.0):
    """Lanterna de ferro com a chama acesa: base, cúpula e um miolo brilhante."""
    C(0.07 * esc, 0.04 * esc, x, y, z, ferro(), v=8)
    C(0.06 * esc, 0.16 * esc, x, y, z + 0.04 * esc, E(cor, forca), v=8)
    esfera("tampa", 0.08 * esc, (x, y, z + 0.22 * esc), ferro(), escala=(1, 1, 0.55))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        C(0.008 * esc, 0.2 * esc, x + 0.065 * esc * math.cos(a), y + 0.065 * esc * math.sin(a), z + 0.03 * esc, ferro(), v=4)


# ------------------------------------------------------------------ rua: lampiões, postes, placas
def _poste_base(r):
    C(0.22, 0.2, 0, 0, 0, pedra(PEDRA_ESC), v=10, ch=0.01)
    C(0.13, 0.6, 0, 0, 0.2, ferro(), v=12)
    C(0.17, 0.08, 0, 0, 0.5, ferro(), v=12)


def poste_rua(r, lado=1):
    """Lampião de ferro forjado de 5,4 m: fuste fino com anéis, braço curvo com volutas e a lanterna acesa pendurada (a luz é do jogo)."""
    _poste_base(r)
    px3.cone("haste", 0.1, 0.055, 4.3, (0, 0, 0.8 + 2.15), ferro(), vertices=12)
    for z in (1.0, 2.6, 4.0):
        C(0.1, 0.05, 0, 0, z, ferro(), v=12)
    pts = [(0, 0, 5.04), (0.22 * lado, 0, 5.3), (0.62 * lado, 0, 5.42), (1.05 * lado, 0, 5.4), (1.35 * lado, 0, 5.3)]
    for a, b in zip(pts, pts[1:]):
        barra(a, b, 0.045, ferro(), v=8)
    barra((0.5 * lado, 0, 5.38), (0.8 * lado, 0, 5.05), 0.025, ferro(), v=6)           # voluta
    barra((1.35 * lado, 0, 5.3), (1.42 * lado, 0, 5.22), 0.02, ferro(), v=6)
    lanterna(1.42 * lado, 0.0, 5.0, VELA, 3.4, 1.9)
    esfera("halo", 0.16, (1.42 * lado, 0, 5.12), E("ffcf80", 0.9), escala=(1, 1, 1.2))
    B(0.2, 0.02, 0.4, 0, -0.14, 1.45, M("b0a47e", 0.95, 0.3, 0.3), ch=0.0)             # um cartaz amarelado pregado no fuste
    B(0.12, 0.02, 0.2, 0.01, -0.145, 1.9, M("7a2a2a", 0.95), ch=0.0)


def poste_rua_e(r):
    poste_rua(r, lado=-1)


def poste_quebrado(r):
    """Lampião derrubado pela metade: o fuste parte a 3 m, a lanterna esmagada no chão e o braço torto."""
    _poste_base(r)
    px3.cone("haste", 0.1, 0.07, 2.4, (0, 0, 0.8 + 1.2), ferro(), vertices=12)
    barra((0.0, 0.0, 3.2), (0.7, 0.0, 3.0), 0.07, ferro(), v=8)
    barra((0.0, 0.0, 3.2), (0.25, -0.08, 3.5), 0.04, ferro(), v=6)
    barra((0.7, 0.0, 3.0), (1.6, -1.1, 0.12), 0.05, ferro(), v=8)
    lanterna(1.7, -1.5, 0.05, "c07a30", 1.6, 1.3)
    for k in range(5):
        B(r.uniform(0.06, 0.12), r.uniform(0.04, 0.08), 0.02, 1.4 + r.uniform(0, 0.8), -1.2 - r.uniform(0, 0.6), 0.0, vidro("7a6a50"), ch=0.0, rot=(0, 0, r.uniform(0, 3)))


def semaforo(r, torto=False, aceso=True):
    """Poste de madeira com uma lanterna rubra pendurada num braço (a luz vermelha é do jogo): marca a entrada da vila."""
    inc = 0.07 if torto else 0.0
    C(0.2, 0.12, 0, 0, 0, pedra(PEDRA_ESC), v=10)
    px3.cone("poste", 0.12, 0.09, 3.3, (0.0, 0.0, 0.12 + 1.65), madeira(MADEIRA_ESC), vertices=8)
    barra((0, 0, 3.2), (-0.55, -0.16, 3.2), 0.04, madeira(MADEIRA_ESC), v=8)
    barra((0, 0, 2.85), (-0.3, -0.1, 3.2), 0.03, madeira(MADEIRA_ESC), v=6)
    barra((-0.55, -0.16, 3.2), (-0.55, -0.16, 3.0), 0.012, ferro(), v=4)
    lanterna(-0.55, -0.16, 2.78, VERMELHO if aceso else "5a2a22", 3.0 if aceso else 0.0, 1.8)
    B(0.3, 0.04, 0.24, 0.0, -0.13, 1.5, madeira(MADEIRA_CLARA), ch=0.01)                # tábua de aviso
    for k in range(3):
        B(0.2, 0.02, 0.025, 0.0, -0.16, 1.55 + k * 0.06, M(CARVAO, 0.9), ch=0.0)


def semaforo_torto(r):
    semaforo(r, torto=True, aceso=False)


def placa_pare(r):
    """Tábua de aviso numa estaca: AFASTE-SE em runas riscadas."""
    px3.cone("estaca", 0.08, 0.05, 2.3, (0, 0, 1.15), madeira(MADEIRA_ESC), vertices=8)
    B(0.7, 0.05, 0.5, 0, -0.07, 1.65, madeira(MADEIRA_CLARA), ch=0.02)
    for k in range(3):
        B(0.5, 0.02, 0.04, 0, -0.1, 1.78 - k * 0.1, M(CARVAO, 0.9), ch=0.0)
    B(0.12, 0.03, 0.12, 0.22, -0.1, 1.5, E(VERMELHO, 1.4), ch=0.0)


def placa_rua(r):
    """Poste de madeira com setas de tábua apontando para os becos e uma corrente."""
    px3.cone("poste", 0.09, 0.06, 2.6, (0, 0, 1.3), madeira(MADEIRA_ESC), vertices=8)
    for k, (z, dx, w) in enumerate([(2.3, 0.28, 0.9), (1.95, -0.25, 0.8)]):
        B(w, 0.05, 0.22, dx, -0.1, z, madeira(MADEIRA_CLARA), ch=0.02)
        px3.cone("ponta", 0.12, 0.0, 0.2, (dx + (w / 2 + 0.08) * (1 if dx > 0 else -1), -0.1, z + 0.11), madeira(MADEIRA_CLARA), vertices=4)
        B(w * 0.7, 0.02, 0.03, dx, -0.13, z + 0.1, M(CARVAO, 0.9), ch=0.0)
    barra((0.0, -0.1, 1.7), (0.3, -0.1, 1.5), 0.012, ferro(), v=4)


def placa_neon(r):
    """Tabuleta de taverna presa num braço de ferro, com a lanterna roxa de feitiço acesa embaixo (luz do jogo)."""
    px3.cone("poste", 0.1, 0.07, 3.1, (0, 0, 1.55), madeira(MADEIRA_ESC), vertices=8)
    barra((0, 0, 3.2), (0.45, -0.1, 3.2), 0.035, ferro(), v=6)
    B(0.62, 0.05, 0.4, 0.28, -0.12, 2.65, madeira(MADEIRA_CLARA), ch=0.02)
    esfera("caneca", 0.1, (0.28, -0.17, 2.85), M(LATAO, 0.5), escala=(1, 0.3, 1.1))
    B(0.2, 0.02, 0.08, 0.28, -0.16, 2.7, M(CARVAO, 0.9), ch=0.0)
    lanterna(0.0, -0.2, 2.6, ROXO, 3.2, 1.4)


def hidrante(r):
    """Bomba d'água de ferro e madeira sobre uma pedra: cano curto com alavanca e balde."""
    C(0.22, 0.14, 0, 0, 0, pedra(PEDRA_ESC), v=10)
    C(0.1, 0.5, 0, 0, 0.14, ferro(), v=10)
    B(0.34, 0.06, 0.06, 0.1, 0, 0.55, ferro(), ch=0.01, rot=(0, 0.25, 0))
    barra((0.0, 0.0, 0.62), (0.22, 0.0, 0.5), 0.03, ferro(), v=6)
    C(0.1, 0.16, 0.14, -0.13, 0.0, madeira(), v=10)


def cone_transito(r, tombado=False):
    """Toco de árvore cortado com um machado cravado."""
    C(0.2, 0.55, 0, 0, 0, madeira(MADEIRA_ESC), v=10, ch=0.02)
    C(0.19, 0.04, 0, 0, 0.55, madeira(MADEIRA_CLARA), v=10)
    for a in range(3):
        B(0.05, 0.12, 0.2, 0.2 * math.cos(a * 2.1), 0.2 * math.sin(a * 2.1), 0.0, madeira(MADEIRA_ESC), ch=0.01, rot=(0, 0, a * 2.1))
    barra((0.05, -0.02, 0.62), (0.25, -0.02, 0.7), 0.025, madeira(MADEIRA), v=6)
    B(0.12, 0.03, 0.1, 0.04, -0.02, 0.62, ferro(), ch=0.01)


def cone_tombado(r):
    """Tábuas e achas de lenha espalhadas no chão (passável)."""
    for k in range(4):
        B(r.uniform(0.4, 0.7), 0.1, 0.07, r.uniform(-0.2, 0.2), r.uniform(-0.2, 0.2), 0.0, madeira(r.choice([MADEIRA, MADEIRA_ESC, MADEIRA_CLARA])), ch=0.01,
          rot=(0, 0, r.uniform(0, 3)))


def barril_fogo(r):
    """Braseiro de ferro: bacia sobre três pés, apagada (o fogo é partícula e luz do jogo)."""
    for k in range(3):
        a = k * 2.1 + 0.4
        barra((0.22 * math.cos(a), 0.22 * math.sin(a), 0.0), (0.12 * math.cos(a), 0.12 * math.sin(a), 0.5), 0.035, ferro(), v=6)
    C(0.32, 0.2, 0, 0, 0.5, ferro(), v=14, ch=0.02)
    C(0.28, 0.04, 0, 0, 0.7, M(CARVAO, 0.9), v=14)
    for k in range(5):
        esfera("brasa", 0.05, (0.12 * math.cos(k * 1.3), 0.12 * math.sin(k * 1.3), 0.74), E("c0501a", 1.2), escala=(1, 1, 0.6))


def lixeira_metal(r):
    """Barril de madeira com aros de ferro, tampa solta."""
    C(0.31, 0.9, 0, 0, 0, madeira(MADEIRA_ESC), v=14, ch=0.03)
    for z in (0.12, 0.7):
        C(0.33, 0.06, 0, 0, z, ferro(), v=14)
    C(0.3, 0.05, 0, 0, 0.9, madeira(MADEIRA_CLARA), v=14)


def lixeira_rodas(r, cor=MADEIRA):
    """Carrinho de mão com lenha: caçamba de tábuas, uma roda e dois cabos."""
    B(0.7, 0.55, 0.25, 0, 0.0, 0.4, madeira(cor), ch=0.02)
    for x in (-0.28, 0.28):
        barra((x, 0.2, 0.55), (x, 0.7, 0.9), 0.025, madeira(MADEIRA_ESC), v=6)
    CR(0.2, 0.06, 0.0, -0.3, 0.2, ferro(), (0, math.pi / 2, 0), v=14)
    for k in range(4):
        C(0.06, 0.55, -0.22 + k * 0.15, 0.0, 0.65, madeira(MADEIRA_CLARA), v=7, rot=(math.pi / 2, 0, 0))


def lixeira_azul(r):
    """Poço de pedra com a roldana de madeira e o balde pendurado (o poço da praça)."""
    for k in range(10):
        a = k * math.pi * 2 / 10
        B(0.24, 0.18, 0.55, 0.28 * math.cos(a), 0.28 * math.sin(a), 0.0, pedra(PEDRA_CLARA if k % 2 else PEDRA), ch=0.03, rot=(0, 0, a + math.pi / 2))
    C(0.22, 0.04, 0, 0, 0.1, M("0e1a22", 0.2), v=14)
    for x in (-0.3, 0.3):
        B(0.06, 0.06, 1.0, x, 0.0, 0.5, madeira(MADEIRA_ESC), ch=0.01)
    CR(0.05, 0.7, 0.0, 0.0, 1.45, madeira(MADEIRA_ESC), (0, math.pi / 2, 0), v=8)
    B(0.8, 0.05, 0.08, 0.0, 0.0, 1.5, madeira(MADEIRA), ch=0.01, rot=(0, 0, 0))
    barra((0.0, 0.0, 1.45), (0.0, 0.0, 0.8), 0.01, ferro(), v=4)
    C(0.07, 0.1, 0.0, 0.0, 0.7, madeira(), v=8)


def banco(r):
    """Banco de tábuas com pés de ferro forjado."""
    B(1.8, 0.5, 0.07, 0, 0.0, 0.46, madeira(MADEIRA_CLARA), ch=0.01)
    B(1.8, 0.06, 0.4, 0, 0.24, 0.55, madeira(MADEIRA), ch=0.01, rot=(-0.12, 0, 0))
    for x in (-0.75, 0.75):
        B(0.07, 0.5, 0.46, x, 0.0, 0.0, ferro(), ch=0.01)
        B(0.07, 0.07, 0.5, x, 0.24, 0.46, ferro(), ch=0.01)
    esfera("folha", 0.07, (0.5, -0.1, 0.52), M(MUSGO, 0.9), escala=(1.5, 1, 0.3))


# ------------------------------------------------------------------ carroças (os "_v" são as mesmas viradas ao longo de Y)
def _roda(x, y, z, raio=0.5):
    CR(raio, 0.09, x, y, z, madeira(MADEIRA_ESC), (math.pi / 2, 0, 0), v=14)
    CR(raio * 1.02, 0.06, x, y, z, ferro(), (math.pi / 2, 0, 0), v=14)
    CR(raio * 0.82, 0.1, x, y, z, M(CARVAO, 0.9), (math.pi / 2, 0, 0), v=14)
    CR(0.1, 0.13, x, y, z, madeira(MADEIRA_ESC), (math.pi / 2, 0, 0), v=8)
    for k in range(6):
        a = k * math.pi / 6
        barra((x + raio * 0.85 * math.cos(a), y, z + raio * 0.85 * math.sin(a)), (x - raio * 0.85 * math.cos(a), y, z - raio * 0.85 * math.sin(a)), 0.03,
              madeira(MADEIRA_ESC), v=6)


def _carroca(r, lona=LONA, queimada=False, quebrada=True, carga="barris"):
    """Carroça de 4,5 x 1,9 m ao longo de X: assoalho, taipais, duas rodas grandes, o varal da tração e uma cobertura de lona em arco (ou a carga).
    `queimada`: tudo carvão e o arco só de costelas; `quebrada`: uma roda faltando e o eixo no chão."""
    cor = "2a2320" if queimada else MADEIRA
    B(3.4, 1.5, 0.12, -0.2, 0.0, 0.55, madeira(cor), ch=0.02)
    for sy in (-0.78, 0.78):
        B(3.4, 0.07, 0.5, -0.2, sy, 0.6, madeira(MADEIRA_ESC if not queimada else CARVAO), ch=0.015)
    for sx in (-1.9, 1.5):
        B(0.07, 1.6, 0.5, sx, 0.0, 0.6, madeira(MADEIRA_ESC if not queimada else CARVAO), ch=0.015)
    # eixo e rodas
    CR(0.06, 1.9, -0.1, 0.0, 0.5, madeira(MADEIRA_ESC), (math.pi / 2, 0, 0), v=8)
    _roda(-0.1, -0.95, 0.5, 0.5)
    if quebrada and not queimada:
        B(0.1, 0.5, 0.5, -0.05, 0.9, 0.0, madeira(MADEIRA_ESC), ch=0.02, rot=(0, 0, 0.3))   # a outra roda soltou e ficou caída
        CR(0.5, 0.09, 0.15, 1.4, 0.09, madeira(MADEIRA_ESC), (0, 0, 0), v=14)
    else:
        _roda(-0.1, 0.95, 0.5, 0.5)
    # varais
    barra((1.4, -0.35, 0.65), (2.45, -0.3, 0.55), 0.06, madeira(MADEIRA_ESC), v=8)
    barra((1.4, 0.35, 0.65), (2.45, 0.3, 0.55), 0.06, madeira(MADEIRA_ESC), v=8)
    # cobertura / carga
    if queimada:
        for k in range(5):
            x = -1.5 + k * 0.7
            barra((x, -0.7, 0.67), (x, 0.0, 1.45), 0.04, M(CARVAO, 0.95), v=6)
            barra((x, 0.0, 1.45), (x, 0.7, 0.67), 0.04, M(CARVAO, 0.95), v=6)
        B(1.4, 0.8, 0.18, -0.6, 0.1, 0.67, M(CARVAO, 0.95, 0.5, 0.4), ch=0.04, rot=(0, 0, 0.2))
        esfera("cinza", 0.4, (-0.2, 0.0, 0.7), M("3a3532", 1.0), escala=(1.6, 1, 0.25))
    elif carga == "lona":
        cilindro("arco", 0.78, 3.0, (-0.2, 0.0, 0.62), M(lona, 0.95, 0.3, 0.3), vertices=14, rot=(0, math.pi / 2, 0))
        B(3.1, 1.7, 0.3, -0.2, 0.0, 0.28, madeira(MADEIRA_ESC), ch=0.0)
        for k in range(4):
            B(0.05, 1.6, 0.04, -1.5 + k * 0.85, 0.0, 1.36, madeira(MADEIRA_ESC), ch=0.0)
    else:
        for k in range(6):
            C(0.26, 0.6, -1.4 + (k % 3) * 0.6, -0.4 + (k // 3) * 0.8, 0.67, madeira(MADEIRA_CLARA if k % 2 else MADEIRA), v=12, ch=0.02)
            C(0.28, 0.05, -1.4 + (k % 3) * 0.6, -0.4 + (k // 3) * 0.8, 0.9, ferro(), v=12)


def carro_a(r):
    _carroca(r, LONA, carga="lona")


def carro_b(r):
    _carroca(r, LONA_ESC, carga="lona")


def carro_c(r):
    _carroca(r, LONA, quebrada=False, carga="barris")


def carro_queimado(r):
    _carroca(r, queimada=True)


# ------------------------------------------------------------------ barricadas, entulho e muros
def _saco(x, y, z, sx, sy, sz, rz, mat):
    esfera("saco", 1.0, (x, y, z + sz), mat, escala=(sx, sy, sz))


def sacos_areia(r):
    """Pilha de sacos de grão: duas fileiras de sacos tombados, um rasgado com o grão escorrendo."""
    mat = M("a89a72", 0.98, 0.5, 0.3, 14.0)
    mat2 = M("8c7e5c", 0.98, 0.5, 0.3, 14.0)
    for k in range(5):
        _saco(-1.0 + k * 0.5, 0.0, 0.0, 0.26, 0.3, 0.2, 0.0, mat if k % 2 else mat2)
    for k in range(4):
        _saco(-0.75 + k * 0.5, 0.02, 0.38, 0.26, 0.28, 0.2, 0.0, mat2 if k % 2 else mat)
    for k in range(2):
        _saco(-0.4 + k * 0.6, 0.0, 0.74, 0.25, 0.26, 0.17, 0.0, mat)
    esfera("grao", 0.2, (0.9, -0.3, 0.02), M("c4b27a", 0.95), escala=(1.5, 0.8, 0.25))


def _estaca(x, y, z, ang_x, ang_y, h=1.5):
    """Estaca de madeira de ponta afiada, inclinada."""
    from mathutils import Vector
    d = Vector((math.sin(ang_y), -math.sin(ang_x), math.cos(ang_x) * math.cos(ang_y))).normalized() * h
    barra((x, y, z), (x + d.x, y + d.y, z + d.z), 0.06, madeira(MADEIRA_ESC), v=8)


def barricada_concreto(r):
    """Muro baixo de pedra solta e entulho, com estacas atrás (4,4 m)."""
    for k in range(9):
        B(0.5 + r.uniform(0, 0.2), 0.7, 0.4, -1.9 + k * 0.47, 0.0, 0.0, pedra(r.choice([PEDRA, PEDRA_CLARA, PEDRA_ESC])), ch=0.05, rot=(0, 0, r.uniform(-0.1, 0.1)))
    for k in range(7):
        B(0.5, 0.65, 0.35, -1.7 + k * 0.55, 0.0, 0.4, pedra(r.choice([PEDRA, PEDRA_CLARA])), ch=0.05, rot=(0, 0, r.uniform(-0.15, 0.15)))
    for k in range(4):
        B(0.45, 0.6, 0.15, -1.2 + k * 0.7, 0.05, 0.75, pedra(), ch=0.04, rot=(0, 0, r.uniform(-0.3, 0.3)))
    esfera("musgo", 1.0, (0.4, -0.3, 0.45), M(MUSGO, 0.98, 0.5, 0.3, 14.0), escala=(0.8, 0.3, 0.08))


def barricada_madeira(r):
    """Cavalos-de-frisa: três cruzes de estacas amarradas, de ponta afiada (3,2 m)."""
    for x in (-1.1, 0.0, 1.1):
        for sg in (-1, 1):
            barra((x - sg * 0.5, -0.1, 0.0), (x + sg * 0.35, 0.1, 1.5), 0.06, madeira(MADEIRA_ESC), v=8)
            px3.cone("ponta", 0.06, 0.0, 0.22, (x + sg * 0.38, 0.11, 1.58), madeira(MADEIRA_CLARA), vertices=6)
        barra((x - 0.1, 0.0, 0.7), (x + 0.1, 0.0, 0.7), 0.04, ferro(), v=6)
    barra((-1.4, 0.0, 0.8), (1.4, 0.0, 0.8), 0.05, madeira(MADEIRA), v=8)
    barra((-1.4, 0.0, 0.2), (1.4, 0.0, 0.25), 0.04, madeira(MADEIRA), v=8)
    B(0.5, 0.03, 0.4, 0.0, -0.25, 0.7, M(LONA, 0.95), ch=0.0, rot=(0.1, 0, 0.1))


def pneus(r):
    """Fardos de feno e uma pilha de lenha (1,3 x 1,1 m)."""
    for k in range(3):
        B(0.55, 0.45, 0.4, -0.3 + (k % 2) * 0.1, -0.1 + k * 0.1, k * 0.38, M(PALHA, 0.98, 0.5, 0.4, 20.0), ch=0.05)
    for k in range(5):
        C(0.08, 0.6, 0.35, -0.3 + k * 0.17, 0.0, madeira(MADEIRA_CLARA if k % 2 else MADEIRA), v=8, rot=(0, math.pi / 2, 0))
    for k in range(4):
        C(0.08, 0.6, 0.35, -0.2 + k * 0.17, 0.0, madeira(MADEIRA if k % 2 else MADEIRA_CLARA), v=8, rot=(0, math.pi / 2, 0))
        # fim
    B(0.65, 0.5, 0.05, -0.3, -0.05, 0.78, M(PALHA, 0.98), ch=0.0)


def cacamba(r):
    """Carroça de feno parada: caçamba de tábuas, feno em cima, duas rodas, varal no chão."""
    B(2.0, 1.1, 0.12, 0, 0.0, 0.4, madeira(), ch=0.02)
    for sy in (-0.56, 0.56):
        B(2.0, 0.06, 0.4, 0, sy, 0.45, madeira(MADEIRA_ESC), ch=0.01)
    esfera("feno", 1.0, (0, 0, 0.78), M(PALHA, 0.98, 0.5, 0.4, 20.0), escala=(0.95, 0.5, 0.4))
    _roda(0.2, -0.6, 0.38, 0.38)
    _roda(0.2, 0.6, 0.38, 0.38)
    barra((1.0, 0.0, 0.42), (1.6, 0.0, 0.1), 0.05, madeira(MADEIRA_ESC), v=8)
    barra((1.0, 0.2, 0.42), (1.6, 0.2, 0.1), 0.05, madeira(MADEIRA_ESC), v=8)


def _celeiro(r, aberto=False):
    """Galpão de madeira de 6 x 2,4 m com telhado de palha em duas águas, fechado (A) ou aberto com a carga à mostra (B)."""
    B(6.0, 2.4, 0.3, 0, 0.0, 0.0, pedra(PEDRA_ESC), ch=0.03)
    for k in range(13):
        B(0.45, 0.14, 1.9, -2.85 + k * 0.475, -1.1, 0.3, madeira(MADEIRA if k % 2 else MADEIRA_ESC), ch=0.01)
    for x in (-2.9, 0.0, 2.9):
        B(0.2, 0.2, 2.4, x, -1.15, 0.2, madeira(MADEIRA_ESC), ch=0.02)
    if aberto:
        B(2.6, 0.1, 1.7, 0.4, -1.12, 0.35, M("0f0b08", 1.0), ch=0.0)
        for k in range(6):
            C(0.28, 0.6, -0.4 + (k % 3) * 0.7, -0.9 + (k // 3) * 0.1, 0.35 + (k // 3) * 0.55, madeira(MADEIRA_CLARA), v=12, ch=0.02)
    else:
        B(1.3, 0.08, 1.7, 0.8, -1.2, 0.35, madeira(MADEIRA_ESC), ch=0.01)
        B(0.05, 0.1, 1.7, 0.8, -1.25, 0.35, ferro(), ch=0.0)
        lanterna(-0.9, -1.35, 1.5, VELA, 2.6, 1.1)
    s, hr, zw = 1.75, 0.95, 2.35
    a = math.atan2(hr, s)
    L = math.hypot(s, hr) + 0.1
    B(6.5, L, 0.14, 0, -s / 2, zw + hr / 2, M(PALHA, 0.98, 0.7, 0.4, 20.0), ch=0.03, rot=(a, 0, 0))
    B(6.5, L, 0.14, 0, s / 2, zw + hr / 2, M("8f7438", 0.98, 0.7, 0.4, 20.0), ch=0.03, rot=(-a, 0, 0))
    B(6.4, 0.14, 0.12, 0, 0, zw + hr + 0.02, madeira(MADEIRA_ESC), ch=0.02)


def container_a(r):
    _celeiro(r, aberto=False)


def container_b(r):
    _celeiro(r, aberto=True)


def _pilha(r, raio, n, alt, cores=None, ferros=4):
    """Monte de pedras e tábuas quebradas."""
    cores = cores or [PEDRA, PEDRA_CLARA, PEDRA_ESC]
    for k in range(n):
        a = r.uniform(0, 6.28)
        d = raio * math.sqrt(r.random())
        h = r.uniform(0.1, alt * (1.0 - d / (raio * 1.3)))
        B(r.uniform(0.18, 0.4), r.uniform(0.15, 0.3), h + 0.1, d * math.cos(a), d * math.sin(a) * 0.8, 0.0, pedra(r.choice(cores)), ch=0.03,
          rot=(r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), r.uniform(0, 3)))
    for k in range(ferros):
        a = r.uniform(0, 6.28)
        barra((0.3 * math.cos(a), 0.2 * math.sin(a), 0.1), (0.5 * math.cos(a + 0.5), 0.35 * math.sin(a + 0.5), alt * 0.9), 0.025, madeira(MADEIRA_ESC), v=5)


def entulho_a(r):
    _pilha(r, 0.45, 8, 0.35, ferros=2)


def entulho_b(r):
    _pilha(r, 0.9, 22, 0.9, ferros=5)
    esfera("musgo", 1.0, (0.2, -0.3, 0.55), M(MUSGO, 0.98, 0.5, 0.3, 14.0), escala=(0.5, 0.25, 0.08))


def muro_tijolo(r, quebrado=False):
    """Muro de pedra de 3 m com a crista de hera; no quebrado, falta um pedaço e as pedras estão caídas à frente."""
    cores = [pedra(PEDRA), pedra(PEDRA_CLARA), pedra(PEDRA_ESC)]
    n = 10
    for i in range(n):
        x = -1.5 + 0.3 * (i + 0.5)
        alt = 2.0 if not quebrado else [2.0, 1.9, 1.2, 0.7, 0.4, 0.3, 0.9, 1.6, 2.0, 1.9][i]
        z = 0.0
        k = 0
        while z < alt - 0.03:
            h = min(0.25, alt - z)
            B(0.3, 0.4 * (0.96 + 0.04 * ((i + k) % 3)), h * 0.98, x + (0.05 if k % 2 else -0.05), 0.0, z, cores[(i + k) % 3], ch=0.025)
            z += h
            k += 1
    B(3.06, 0.46, 0.1, 0.0, 0.0, 2.0 if not quebrado else 0.1, pedra(PEDRA_ESC), ch=0.03) if not quebrado else None
    for xh in (-0.9, 0.6):
        barra((xh, -0.22, 0.2), (xh + 0.1, -0.22, 1.7), 0.02, M(MUSGO, 0.9), v=5)
        for k in range(5):
            esfera("folha", 1.0, (xh + 0.04 * (k % 2), -0.24, 0.5 + k * 0.28), M("3e7a45" if k % 2 else "2a5833", 0.9), escala=(0.09, 0.04, 0.07))
    if quebrado:
        for k in range(6):
            B(r.uniform(0.15, 0.3), r.uniform(0.12, 0.22), r.uniform(0.1, 0.22), r.uniform(-0.5, 0.6), -0.45 - r.uniform(0, 0.4), 0.0, pedra(), ch=0.03,
              rot=(0, 0, r.uniform(0, 3)))


def muro_quebrado(r):
    muro_tijolo(r, quebrado=True)


def ponto_onibus(r):
    """Barraca de mercado: balcão de madeira, quatro postes, toldo de lona listrada em declive e uma lanterna acesa na frente (luz do jogo)."""
    for x in (-1.6, 1.6):
        for y in (-0.55, 0.55):
            C(0.05, 2.3 if y > 0 else 1.9, x, y, 0.0, madeira(MADEIRA_ESC), v=8)
    B(3.2, 0.8, 0.12, 0.0, 0.1, 0.8, madeira(MADEIRA_CLARA), ch=0.02)
    B(3.0, 0.7, 0.8, 0.0, 0.1, 0.0, madeira(), ch=0.02)
    B(3.4, 1.5, 0.05, 0.0, 0.0, 2.1, M(LONA_ESC, 0.95, 0.3, 0.3), ch=0.01, rot=(-0.14, 0, 0))
    for k in range(7):
        B(0.24, 1.5, 0.055, -1.4 + k * 0.47, 0.0, 2.11, M(LONA if k % 2 == 0 else LONA_ESC, 0.95, 0.3, 0.3), ch=0.0, rot=(-0.14, 0, 0))
    for k in range(4):
        C(0.1, 0.22, -1.0 + k * 0.6, 0.05, 0.92, M(["7a2a2a", "a88b4c", "4a6a3a", "8a5a2a"][k], 0.9), v=10)
    esfera("pao", 0.18, (1.2, 0.05, 1.0), M("a8763a", 0.9), escala=(1.4, 0.8, 0.7))
    barra((0.75, -0.55, 1.95), (0.75, -0.55, 1.6), 0.01, ferro(), v=4)
    lanterna(0.75, -0.55, 1.35, VELA, 3.0, 1.3)

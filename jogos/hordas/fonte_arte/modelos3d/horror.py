"""Inimigos de horror (#32 item 5): 4 comuns + 1 elite + 1 chefe, dark fantasy "cavaleiros no caos".

Roda (Blender 4.5 LTS):
    blender -b -P horror.py            # todos
    blender -b -P horror.py carnical   # só um (carnical, cavaleiro_oco, espectro, cao_ossos, abominacao, arauto)
Saída: ../../projeto/assets/gerado/inimigo_<nome>.png (folha de 3 quadros lado a lado: andar A, andar B, branco
de dano; o mesmo formato dos vírus, em 1x: o jogo lê "escala" em dados/inimigos.json) e proj_<nome>.png.
Os bichos olham pra DIREITA, como os vírus: o jogo espelha quando o bicho está à direita do herói
(inimigos.gd, `vira = v.pos.x > jx`), e aí ele olha pro herói. O render sai olhando pra esquerda, então cada quadro é espelhado. Olhos e chamas são emissivos: a cor
precisa existir na paleta passada ao pixelar, senão o brilho some.
"""
import math
import os
import sys

import bpy
import numpy as np

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import pixel3d as px3  # noqa: E402
from pixel3d import caixa, cilindro, cone, esfera  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "gerado"))
PPU = 60.0 / 2.55      # pixels por unidade do Blender: a MESMA escala do cavaleiro/Hazaki (herói ~1,9 u = 45 px)
T = px3.material_toon
C = px3.cor


def mats():
    """Materiais compartilhados. Cores base perto do tom claro da rampa; o toon escurece em 3 faixas."""
    return {
        "aco": T("aco", C("6f6a86"), ruido=0.25, escala_ruido=9.0),
        "aco_e": T("aco_e", C("4a4560")),
        "ferrugem": T("ferrugem", C("6e4c32"), ruido=0.3, escala_ruido=8.0),
        "osso": T("osso", C("c9bfa6")),
        "osso_e": T("osso_e", C("8c8470")),
        "carne": T("carne", C("a8302c"), ruido=0.2, escala_ruido=5.0),
        "carne_e": T("carne_e", C("6a1c24")),
        "pele": T("pele", C("6c8068"), ruido=0.22, escala_ruido=7.0),      # cinza-esverdeada, apodrecida
        "pele_e": T("pele_e", C("3b4a3d")),
        "pano": T("pano", C("3c3552"), ruido=0.2, escala_ruido=6.0),        # manto roxo-noite
        "pano_s": T("pano_s", C("6a1c24"), ruido=0.2, escala_ruido=6.0),    # manto sangue seco
        "negro": T("negro", C("0d0b14"), faixas=(1, 1, 1)),
        "ouro": T("ouro", C("8a6a34")),
        "olho_v": px3.material_emissao("olho_v", C("e4ffb0")),    # verde-pálido (espectro, carniçal)
        "olho_f": px3.material_emissao("olho_f", C("ffd060")),    # âmbar (cavaleiro oco, abominação)
        "olho_r": px3.material_emissao("olho_r", C("ff3a2a")),    # brasa vermelha (cão, chefe)
        "fogo": px3.material_emissao("fogo", C("fff2b0")),
    }


# ------------------------------------------------------------------ utilidades

def braco(nome, w, d, L, pivo, mat, pai):
    """Caixa pendurada num pivô (ombro/quadril): gira em X pra balançar."""
    return caixa(nome, (w, d, L), (pivo[0], pivo[1], pivo[2] - L / 2), mat, pai, pivo=pivo)


def raiz_corpo():
    bpy.ops.object.empty_add(location=(0, 0, 0))
    raiz = bpy.context.active_object
    raiz.name = "raiz"
    bpy.ops.object.empty_add(location=(0, 0, 0))
    corpo = bpy.context.active_object
    corpo.name = "corpo"
    corpo.parent = raiz
    return raiz, corpo


def apontar(o, direcao):
    from mathutils import Vector
    o.rotation_euler = Vector(direcao).normalized().to_track_quat("Z", "Y").to_euler()


def espinho(nome, base, direcao, comp, r, mat, pai):
    c = cone(nome, r, 0.0, comp, (0, 0, 0), mat, None)
    from mathutils import Vector
    c.location = Vector(base) + Vector(direcao).normalized() * comp / 2
    apontar(c, direcao)
    px3.pendurar(c, pai)
    return c


# ------------------------------------------------------------------ modelos
# Cada um devolve (raiz, corpo, partes, pose(fase, quadro)); a frente do bicho é -Y.

def carnical(m):
    """Carniçal rastejante: de quatro, peito erguido, cabeça pálida de boca aberta, braços compridos de garra."""
    raiz, corpo = raiz_corpo()
    p = {}
    caixa("tronco", (0.5, 0.8, 0.42), (0, 0.0, 0.62), m["pele"], corpo, rot=(-0.38, 0, 0), chanfro=0.04)
    caixa("quadril", (0.44, 0.34, 0.36), (0, 0.5, 0.42), m["pele_e"], corpo)
    for i, (y, z) in enumerate(((-0.2, 0.9), (0.0, 0.88), (0.2, 0.8), (0.4, 0.68))):   # coluna aparecendo nas costas
        caixa("vert%d" % i, (0.1, 0.1, 0.1), (0, y, z), m["osso"], corpo)
    for lado, x in (("e", 0.34), ("d", -0.34)):
        a = braco("braco_" + lado, 0.15, 0.15, 0.85, (x, -0.3, 0.78), m["pele"], corpo)
        for k in (-0.05, 0.0, 0.05):
            caixa("garra", (0.03, 0.03, 0.2), (x + k, -0.3, -0.1), m["osso"], a)
        p["braco_" + lado] = a
        p["coxa_" + lado] = braco("coxa_" + lado, 0.17, 0.17, 0.55, (x * 0.8, 0.62, 0.5), m["pele_e"], corpo)
    cab = esfera("cabeca", 0.24, (0, -0.52, 0.9), m["osso"], corpo, escala=(1.0, 1.0, 0.95))
    caixa("mandibula", (0.2, 0.22, 0.06), (0, -0.64, 0.66), m["osso_e"], corpo)
    caixa("boca", (0.16, 0.12, 0.05), (0, -0.7, 0.72), m["negro"], corpo)
    for k in (-0.06, 0.0, 0.06):
        caixa("dente", (0.025, 0.025, 0.07), (k, -0.76, 0.75), m["osso"], corpo)
    for x in (0.1, -0.1):
        esfera("olho", 0.085, (x, -0.72, 0.97), m["olho_v"], corpo)
    p["cab"] = cab

    def pose(fase, q):
        s = math.sin(fase)
        p["braco_e"].rotation_euler = (-0.5 - 0.5 * s, 0, 0)
        p["braco_d"].rotation_euler = (-0.5 + 0.5 * s, 0, 0)
        p["coxa_e"].rotation_euler = (0.7 + 0.3 * s, 0, 0)
        p["coxa_d"].rotation_euler = (0.7 - 0.3 * s, 0, 0)
        corpo.location = (0, 0, 0.05 * abs(s))
        corpo.rotation_euler = (0.05 * s, 0, 0)
    return raiz, corpo, p, pose


def cao_ossos(m):
    """Cão de ossos: esqueleto de quatro patas, caveira com olhos de brasa."""
    raiz, corpo = raiz_corpo()
    p = {}
    for i, y in enumerate((-0.3, -0.12, 0.06, 0.24, 0.42, 0.6)):
        caixa("vert%d" % i, (0.08, 0.14, 0.08), (0, y, 0.7), m["osso"], corpo)
    for i, y in enumerate((-0.2, -0.02, 0.16, 0.34)):   # costelas: duas hastes por lado + arco
        for x in (0.2, -0.2):
            caixa("costela", (0.045, 0.05, 0.36), (x, y, 0.52), m["osso_e"], corpo)
        caixa("arco", (0.42, 0.05, 0.05), (0, y, 0.72), m["osso"], corpo)
    caixa("pelve", (0.34, 0.2, 0.16), (0, 0.62, 0.62), m["osso_e"], corpo)
    # caveira
    caixa("cranio", (0.26, 0.34, 0.24), (0, -0.52, 0.78), m["osso"], corpo, chanfro=0.03)
    caixa("focinho", (0.17, 0.26, 0.13), (0, -0.78, 0.72), m["osso"], corpo)
    caixa("mandibula", (0.14, 0.24, 0.04), (0, -0.76, 0.6), m["osso_e"], corpo)
    for k in (-0.05, 0.0, 0.05):
        caixa("dente", (0.02, 0.02, 0.05), (k, -0.9, 0.64), m["osso"], corpo)
    for x in (0.09, -0.09):
        caixa("orbita", (0.09, 0.04, 0.09), (x, -0.67, 0.83), m["negro"], corpo)
        esfera("olho", 0.055, (x, -0.7, 0.83), m["olho_r"], corpo)
    for x in (0.1, -0.1):   # orelhas pontudas
        espinho("orelha", (x, -0.45, 0.88), (x * 2, 0.0, 1.0), 0.2, 0.05, m["osso"], corpo)
    # patas: dianteiras e traseiras
    for nome, x, y in (("fe", 0.17, -0.26), ("fd", -0.17, -0.26), ("te", 0.17, 0.58), ("td", -0.17, 0.58)):
        p[nome] = braco("pata_" + nome, 0.1, 0.1, 0.62, (x, y, 0.64), m["osso"], corpo)
        caixa("pe", (0.09, 0.16, 0.05), (x, y - 0.05, 0.05), m["osso_e"], p[nome])
    # cauda de vértebras
    for i in range(4):
        caixa("cauda%d" % i, (0.06, 0.12, 0.06), (0, 0.78 + i * 0.1, 0.7 + i * 0.07), m["osso_e"], corpo)

    def pose(fase, q):
        s = math.sin(fase)
        p["fe"].rotation_euler = (0.7 * s, 0, 0)
        p["td"].rotation_euler = (0.7 * s, 0, 0)
        p["fd"].rotation_euler = (-0.7 * s, 0, 0)
        p["te"].rotation_euler = (-0.7 * s, 0, 0)
        corpo.location = (0, 0, 0.06 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def cavaleiro_oco(m):
    """Cavaleiro oco: armadura vazia, ferrugem, visor com dois olhos âmbar, montante gigante arrastando."""
    raiz, corpo = raiz_corpo()
    p = {}
    for lado, x in (("e", 0.14), ("d", -0.14)):
        perna = caixa("perna_" + lado, (0.15, 0.17, 0.68), (x, 0, 0.52), m["aco_e"], corpo, pivo=(x, 0, 0.86))
        caixa("bota_" + lado, (0.19, 0.3, 0.2), (x, -0.04, 0.1), m["ferrugem"], perna)
        p["perna_" + lado] = perna
    caixa("tronco", (0.5, 0.36, 0.56), (0, 0, 1.2), m["aco"], corpo, chanfro=0.03)
    caixa("racha", (0.05, 0.04, 0.4), (0.06, -0.19, 1.2), m["negro"], corpo)           # rachadura no peito: vazio por dentro
    caixa("cinto", (0.52, 0.4, 0.07), (0, 0, 0.9), m["ferrugem"], corpo)
    caixa("saia", (0.46, 0.34, 0.2), (0, 0, 0.78), m["aco_e"], corpo)
    # farrapo de manto nas costas
    capa = caixa("capa", (0.5, 0.04, 1.0), (0, 0.22, 1.0), m["pano_s"], corpo, pivo=(0, 0.2, 1.5))
    p["capa"] = capa
    for x in (0.34, -0.34):
        esfera("ombreira", 0.18, (x, 0, 1.45), m["aco"], corpo, escala=(1.1, 1.0, 0.8))
        espinho("espeto", (x * 1.15, 0, 1.55), (x, 0, 1.4), 0.26, 0.05, m["aco_e"], corpo)
    # sem pescoço: o elmo flutua, com um vão escuro embaixo
    caixa("vao", (0.2, 0.2, 0.12), (0, 0, 1.55), m["negro"], corpo)
    cilindro("elmo", 0.24, 0.4, (0, 0, 1.82), m["aco"], corpo, vertices=14)
    esfera("domo", 0.24, (0, 0, 2.02), m["aco"], corpo, escala=(1, 1, 0.55))
    caixa("visor", (0.34, 0.05, 0.1), (0, -0.235, 1.84), m["negro"], corpo)
    for x in (0.08, -0.08):
        caixa("olho", (0.1, 0.03, 0.09), (x, -0.255, 1.84), m["olho_f"], corpo)
    espinho("pena", (0, 0.1, 2.12), (0, 0.6, 1.0), 0.45, 0.07, m["pano_s"], corpo)
    # braço direito com a espada (a ponta quase toca o chão); esquerdo caído
    bd = braco("braco_d", 0.14, 0.14, 0.7, (-0.36, 0, 1.4), m["aco_e"], corpo)
    caixa("luva_d", (0.16, 0.16, 0.12), (-0.36, 0, 0.74), m["ferrugem"], bd)
    caixa("lamina", (0.09, 0.04, 1.5), (-0.36, -0.1, 0.1), m["aco"], bd)
    caixa("guarda", (0.3, 0.07, 0.07), (-0.36, -0.1, 0.8), m["ferrugem"], bd)
    be = braco("braco_e", 0.14, 0.14, 0.7, (0.36, 0, 1.4), m["aco_e"], corpo)
    caixa("luva_e", (0.16, 0.16, 0.12), (0.36, 0, 0.74), m["ferrugem"], be)
    p["braco_d"], p["braco_e"] = bd, be

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.45 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.45 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.3 * s, 0, 0)
        p["braco_d"].rotation_euler = (-0.55 + 0.1 * s, 0, 0)     # espada levantada, pesada
        p["capa"].rotation_euler = (-0.12 - 0.12 * abs(s), 0, 0)
        corpo.location = (0, 0, 0.05 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def espectro(m):
    """Espectro encapuzado: manto roxo sem pernas, capuz vazio com olhos verdes, esfera de energia na mão."""
    raiz, corpo = raiz_corpo()
    p = {}
    cone("manto", 0.52, 0.17, 1.45, (0, 0, 0.78), m["pano"], corpo)
    for i in range(7):   # bainha esfarrapada
        a = math.tau * i / 7.0
        t = cone("farrapo%d" % i, 0.11, 0.0, 0.34, (math.cos(a) * 0.45, math.sin(a) * 0.4, 0.17), m["pano"], corpo)
        t.rotation_euler = (math.sin(a) * 0.25, -math.cos(a) * 0.25, 0)
        p["farrapo%d" % i] = t
    esfera("capuz", 0.3, (0, 0.02, 1.72), m["pano"], corpo, escala=(0.95, 1.0, 1.2))
    esfera("vazio", 0.2, (0, -0.15, 1.7), m["negro"], corpo, escala=(0.95, 0.7, 1.15))
    for x in (0.075, -0.075):
        esfera("olho", 0.07, (x, -0.3, 1.74), m["olho_v"], corpo)
    ombro = (0.0, 0.0, 1.35)
    be = braco("manga_e", 0.13, 0.13, 0.6, (0.32, -0.02, 1.4), m["pano"], corpo)
    esfera("mao_e", 0.07, (0.32, -0.02, 0.78), m["osso_e"], be)
    bd = braco("manga_d", 0.13, 0.13, 0.6, (-0.32, -0.02, 1.4), m["pano"], corpo)
    esfera("mao_d", 0.07, (-0.32, -0.02, 0.78), m["osso_e"], bd)
    esfera("orbe", 0.13, (-0.32, -0.3, 0.9), m["olho_v"], bd)
    p["manga_e"], p["manga_d"] = be, bd
    _ = ombro

    def pose(fase, q):
        s = math.sin(fase)
        p["manga_e"].rotation_euler = (-0.4 - 0.2 * s, 0, 0)
        p["manga_d"].rotation_euler = (-0.9 + 0.15 * s, 0, 0)
        corpo.rotation_euler = (0.05 * s, 0.04 * s, 0)
        for i in range(7):
            p["farrapo%d" % i].scale = (1, 1, 1.0 + 0.35 * math.sin(fase + i))
        corpo.location = (0, 0, 0.03 * s)
    return raiz, corpo, p, pose


def abominacao(m):
    """Abominação de carne (elite): massa de carne com costelas de fora, boca enorme e vários olhos âmbar."""
    raiz, corpo = raiz_corpo()
    p = {}
    for lado, x in (("e", 0.38), ("d", -0.38)):
        p["perna_" + lado] = caixa("perna_" + lado, (0.4, 0.4, 0.8), (x, 0.05, 0.4), m["carne_e"], corpo, pivo=(x, 0.05, 0.82))
        caixa("pe_" + lado, (0.5, 0.6, 0.18), (x, -0.08, 0.08), m["osso_e"], p["perna_" + lado])
    esfera("massa", 0.95, (0, 0.05, 1.35), m["carne"], corpo, escala=(1.1, 0.95, 0.95))
    esfera("papo", 0.5, (0.35, -0.55, 1.1), m["carne"], corpo)
    esfera("calombo", 0.4, (-0.55, -0.1, 1.95), m["carne_e"], corpo)
    esfera("calombo2", 0.3, (0.5, 0.3, 2.0), m["carne"], corpo)
    for i, y in enumerate((-0.2, 0.05, 0.3)):    # costelas expostas nas costas e no flanco
        caixa("costela%d" % i, (0.08, 0.06, 0.8), (0.88, y, 1.5), m["osso"], corpo, rot=(0, 0.35, 0))
    for i in range(5):                           # tiras de tendão
        caixa("tendao%d" % i, (0.05, 0.05, 0.9), (-0.6 + i * 0.3, -0.7, 1.4), m["ferrugem"], corpo, rot=(0.2, 0.0, 0.25 * (i - 2)))
    # boca
    caixa("boca", (1.0, 0.1, 0.26), (-0.05, -0.8, 1.0), m["negro"], corpo)
    for i in range(7):
        espinho("dente%d" % i, (-0.5 + i * 0.16, -0.86, 1.1), (0, -0.2, -1.0), 0.17, 0.045, m["osso"], corpo)
        espinho("dente_b%d" % i, (-0.5 + i * 0.16, -0.86, 0.9), (0, -0.2, 1.0), 0.14, 0.04, m["osso"], corpo)
    # olhos de tamanhos diferentes
    for (x, z, r) in ((-0.22, 1.62, 0.1), (0.2, 1.7, 0.13), (-0.5, 1.4, 0.07), (0.55, 1.45, 0.08), (0.0, 1.95, 0.06)):
        esfera("olho", r, (x, -0.8 + (x * x) * 0.2, z), m["olho_f"], corpo)
    # braços: um enorme, um mirrado
    bd = braco("braco_d", 0.38, 0.38, 1.5, (-1.0, 0.0, 1.9), m["carne_e"], corpo)
    for k in (-0.12, 0.0, 0.12):
        caixa("garra", (0.05, 0.05, 0.3), (-1.0 + k, -0.02, 0.5), m["osso"], bd)
    be = braco("braco_e", 0.2, 0.2, 1.0, (1.0, 0.0, 1.8), m["carne"], corpo)
    caixa("mao", (0.24, 0.24, 0.2), (1.0, 0.0, 0.88), m["osso_e"], be)
    p["braco_d"], p["braco_e"] = bd, be

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.35 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.35 * s, 0, 0)
        p["braco_d"].rotation_euler = (-0.5 * s, 0, 0.25)
        p["braco_e"].rotation_euler = (0.35 * s, 0, -0.1)
        corpo.location = (0, 0, 0.07 * abs(math.cos(fase)))
        corpo.scale = (1.0 + 0.025 * s, 1.0, 1.0 - 0.02 * s)
    return raiz, corpo, p, pose


def arauto(m):
    """O Arauto Sem Rosto (chefe): manto negro e coroa de espinhos, máscara lisa sem feições, peito aberto em brasa,
    montante enorme e três chamas que giram em volta."""
    raiz, corpo = raiz_corpo()
    p = {}
    cone("veste", 0.95, 0.4, 2.1, (0, 0.05, 1.05), m["pano"], corpo)
    for i in range(9):
        a = math.tau * i / 9.0
        t = cone("farrapo%d" % i, 0.16, 0.0, 0.5, (math.cos(a) * 0.82, 0.05 + math.sin(a) * 0.7, 0.25), m["pano_s"], corpo)
        t.rotation_euler = (math.sin(a) * 0.2, -math.cos(a) * 0.2, 0)
        p["farrapo%d" % i] = t
    caixa("peito", (0.95, 0.5, 0.9), (0, 0, 2.55), m["aco"], corpo, chanfro=0.05)
    caixa("buraco", (0.4, 0.06, 0.55), (0, -0.27, 2.55), m["negro"], corpo)
    caixa("brasa", (0.26, 0.04, 0.38), (0, -0.3, 2.52), m["olho_r"], corpo)
    caixa("gola", (1.1, 0.5, 0.14), (0, 0, 3.02), m["aco_e"], corpo)
    for x in (0.7, -0.7):
        esfera("ombreira", 0.36, (x, 0, 2.85), m["aco"], corpo, escala=(1.2, 1.0, 0.85))
        for k in range(3):
            espinho("espeto", (x * (1.1 + 0.1 * k), 0, 2.95), (x * 0.6, 0, 1.0 + 0.4 * k), 0.4 + 0.1 * k, 0.07, m["aco_e"], corpo)
    # cabeça: máscara lisa, sem feições, e coroa de espinhos quebrados
    esfera("mascara", 0.34, (0, 0, 3.4), m["osso"], corpo, escala=(0.9, 0.95, 1.25))
    caixa("fenda", (0.025, 0.03, 0.34), (0, -0.33, 3.4), m["negro"], corpo)
    for i in range(7):
        a = math.tau * i / 7.0
        espinho("coroa%d" % i, (math.cos(a) * 0.27, math.sin(a) * 0.27, 3.72), (math.cos(a) * 0.5, math.sin(a) * 0.5, 1.0), 0.5 + 0.12 * (i % 3), 0.06, m["ouro"], corpo)
    # braço direito segura o montante; esquerdo erguido com chama
    bd = braco("braco_d", 0.28, 0.28, 1.5, (-0.95, 0, 2.8), m["aco_e"], corpo)
    esfera("mao_d", 0.17, (-0.95, 0, 1.3), m["aco"], bd)
    caixa("lamina", (0.16, 0.06, 2.6), (-0.95, -0.06, 0.1), m["aco"], bd)
    caixa("guarda", (0.7, 0.1, 0.1), (-0.95, -0.06, 1.3), m["ouro"], bd)
    be = braco("braco_e", 0.28, 0.28, 1.5, (0.95, 0, 2.8), m["aco_e"], corpo)
    esfera("mao_e", 0.17, (0.95, 0, 1.3), m["aco"], be)
    esfera("chama", 0.2, (0.95, -0.15, 1.05), m["olho_r"], be)
    p["braco_d"], p["braco_e"] = bd, be
    # chamas orbitais
    p["orbes"] = []
    for i in range(3):
        p["orbes"].append(esfera("orbe%d" % i, 0.17, (0, 0, 0), m["olho_r" if i != 1 else "fogo"], corpo))

    def pose(fase, q):
        s = math.sin(fase)
        p["braco_d"].rotation_euler = (-0.15 + 0.08 * s, 0, 0.1)
        p["braco_e"].rotation_euler = (-1.7 - 0.12 * s, 0, 0)
        for i in range(9):
            p["farrapo%d" % i].scale = (1, 1, 1.0 + 0.3 * math.sin(fase + i))
        corpo.location = (0, 0, 0.07 * s)
        for i, o in enumerate(p["orbes"]):
            a = fase * 0.5 + math.tau * i / 3.0
            o.location = (math.cos(a) * 1.5, math.sin(a) * 0.9 - 0.2, 3.35 + 0.25 * math.sin(a * 2.0 + 1.0))
    return raiz, corpo, p, pose


# nome: (modelo, largura, altura, giro do corpo em graus, paleta)
INIMIGOS = {
    "carnical": (carnical, 40, 36, -50.0, ("musgo", "osso", "aco", "veneno")),
    "cao_ossos": (cao_ossos, 46, 38, -60.0, ("osso", "sangue", "aco")),
    "cavaleiro_oco": (cavaleiro_oco, 42, 56, -40.0, ("aco", "couro", "sangue", "fogo", "osso")),
    "espectro": (espectro, 40, 54, -35.0, ("aco", "veneno", "osso", "musgo")),
    "abominacao": (abominacao, 76, 72, -35.0, ("sangue", "osso", "couro", "fogo", "aco")),
    "arauto": (arauto, 80, 108, -25.0, ("aco", "sangue", "osso", "ouro", "fogo", "couro")),
}


def paleta(nomes):
    base = px3.paleta_de(*nomes)
    vermelho = np.array([[1.0, 0x3a / 255.0, 0x2a / 255.0]])   # brasa dos olhos: clara o bastante pra atravessar a escuridão
    return np.vstack([base, vermelho])


def gerar(nome):
    modelo, W, H, giro, ramps = INIMIGOS[nome]
    px3.limpar_cena()
    px3.preparar_render(W, H)
    cam = px3.camera(elevacao_graus=32.0, escala=max(W, H) / PPU)
    px3.luz()
    m = mats()
    raiz, corpo, p, pose = modelo(m)
    raiz.rotation_euler = (0, 0, math.radians(giro))
    pose(0.0, 0)
    px3.calibrar_pe(cam, H - 2, W, H)
    pal = paleta(ramps)
    folha = np.zeros((H, W * 3, 4), dtype=np.float32)
    for q, fase in enumerate((0.0, math.pi)):
        pose(fase, q)
        folha[:, q * W:(q + 1) * W] = px3.pixelar(px3.render_rgba(), paleta=pal)[:, ::-1]   # olhando pra direita
    branco = folha[:, :W].copy()
    branco[branco[:, :, 3] > 0.5, :3] = 1.0
    folha[:, 2 * W:] = branco
    px3.salvar_png(folha, os.path.join(SAIDA, "inimigo_%s.png" % nome))
    print("HORROR OK", nome, W, H)


def orbe(nome, n, rampa):
    """Projétil redondo e brilhante, com miolo claro, 2 anéis e contorno escuro."""
    out = np.zeros((n, n, 4), dtype=np.float32)
    c = (n - 1) / 2.0
    cores = [np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]) for h in rampa]
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - c, y - c) / (n / 2.0)
            if d > 1.0:
                continue
            k = min(len(cores) - 1, int((1.0 - d) * len(cores) * 1.05))
            out[y, x, :3] = cores[k] if d < 0.92 else px3.CONTORNO
            out[y, x, 3] = 1.0
    px3.salvar_png(out, os.path.join(SAIDA, "proj_%s.png" % nome))


def main():
    quais = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else []
    for n in (quais or list(INIMIGOS)):
        gerar(n)
    if not quais:
        orbe("orbe_espectral", 9, ["1d4a2a", "2f7a3a", "56b04a", "a6e070", "e4ffb0"])
        orbe("orbe_arauto", 11, ["4f1520", "b0342f", "d9614a", "f0921e", "fff2b0"])
        print("HORROR projeteis OK")


main()

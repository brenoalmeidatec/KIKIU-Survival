"""Reino Sombrio (#64, região 5): o que faltava além dos tenebrosos de horror.py, que continuam sendo o povo da região.
Um atirador comum, uma elite e O Soberano do Caos, o chefe final (no lugar da Tela Azul provisória).

Roda (Blender 4.5 LTS):
    blender -b -P reino.py                    # todos
    blender -b -P reino.py -- soberano_caos   # só um
Saída: ../../projeto/assets/gerado/inimigo_<nome>.png (3 colunas x 5 vistas, veja monstros.py) e proj_<nome>.png.
Clima (#68): onde o caos começou. Armadura negra rachada com o caos aceso por dentro (magenta), mantos vinho e roxo-noite.
Duas fases da região são escuras (escuridao.gd): os olhos e as rachaduras acesas são o que se vê de longe.
"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import monstros  # noqa: E402
from monstros import braco, espinho, galho, junta, raiz_corpo  # noqa: E402
from pixel3d import caixa, cilindro, cone, esfera  # noqa: E402

T = monstros.T
C = monstros.C


def mats():
    m = monstros.mats_base()
    m.update({
        "armadura": T("armadura", C("2e2a40"), ruido=0.25, escala_ruido=9.0),   # aço negro
        "manto": T("manto", C("6e1a6e"), ruido=0.2, escala_ruido=6.0),          # roxo do caos (vivo: lê no chão escuro)
        "sombra": T("sombra", C("1a0a1f"), faixas=(0.6, 0.8, 1.0)),             # asas de sombra
        "couro_d": T("couro_d", C("4a3324")),
        "caos": monstros.px3.material_emissao("caos", C("e04aa8")),             # rachaduras, fio da espada
        "caos_c": monstros.px3.material_emissao("caos_c", C("ff9ad8")),         # olhos e brasas
    })
    return m


# ------------------------------------------------------------------ modelos (frente = -Y, chão = z 0)

def cultista(m):
    """Cultista do caos: manto escuro de capuz fundo, só os olhos acesos, as mãos juntas segurando uma brasa do caos. Atira."""
    raiz, corpo = raiz_corpo()
    p = {}
    cone("manto", 0.36, 0.17, 1.2, (0, 0, 0.6), m["manto"], corpo, vertices=12)
    caixa("faixa", (0.08, 0.02, 0.9), (0, -0.28, 0.5), m["pano_s"], corpo, rot=(-0.17, 0, 0))
    esfera("ombros", 0.2, (0, 0, 1.15), m["manto"], corpo, escala=(1.2, 0.9, 0.7))
    esfera("capuz", 0.18, (0, 0.02, 1.36), m["manto"], corpo, escala=(1.0, 1.1, 1.15))
    caixa("rosto", (0.18, 0.06, 0.16), (0, -0.15, 1.33), m["negro"], corpo)   # o fundo do capuz
    for x in (0.045, -0.045):
        esfera("olho", 0.022, (x, -0.18, 1.35), m["caos_c"], corpo)
    espinho("ponta", (0, 0.1, 1.48), (0, 0.6, 1), 0.2, 0.08, m["manto"], corpo)
    for lado in (1, -1):
        nome = "braco_e" if lado > 0 else "braco_d"
        p[nome] = braco(nome, 0.09, 0.09, 0.45, (0.2 * lado, -0.02, 1.18), m["manto"], corpo)
    esfera("brasa", 0.07, (0, -0.36, 0.9), m["caos_c"], corpo)   # entre as mãos

    def pose(fase, q):
        s = math.sin(fase)
        p["braco_e"].rotation_euler = (-0.9 + 0.08 * s, 0, 0)
        p["braco_d"].rotation_euler = (-0.9 + 0.08 * s, 0, 0)
        corpo.rotation_euler = (0, 0.04 * s, 0)
        corpo.location = (0, 0, 0.02 * abs(math.cos(fase)))   # desliza: o manto esconde os pés
    return raiz, corpo, p, pose


def cavaleiro_caos(m):
    """Cavaleiro do caos (elite): armadura negra rachada com o caos aceso nas frestas, elmo de chifres com a viseira acesa,
    capa vinho em farrapos e um montante de fio aceso."""
    raiz, corpo = raiz_corpo()
    p = {}
    for x in (0.13, -0.13):
        nome = "perna_e" if x > 0 else "perna_d"
        p[nome] = braco(nome, 0.15, 0.17, 0.78, (x, 0, 0.82), m["armadura"], corpo)
        caixa(nome + "_racha", (0.02, 0.02, 0.3), (x + 0.03, -0.09, 0.5), m["caos"], p[nome])
    caixa("capa", (0.6, 0.06, 1.2), (0, 0.24, 0.95), m["pano_s"], corpo, rot=(-0.1, 0, 0))
    for k in range(4):
        caixa("farrapo%d" % k, (0.12, 0.05, 0.25), (-0.22 + k * 0.15, 0.3, 0.3 - (k % 2) * 0.08), m["pano_s"], corpo)
    caixa("saia", (0.5, 0.32, 0.3), (0, 0, 0.84), m["armadura"], corpo, chanfro=0.04)
    caixa("tronco", (0.54, 0.34, 0.6), (0, 0, 1.3), m["armadura"], corpo, chanfro=0.07)
    for k, (x, z, rz) in enumerate(((0.1, 1.38, 0.5), (-0.12, 1.2, -0.4), (0.05, 1.08, 0.2))):
        caixa("racha%d" % k, (0.2, 0.02, 0.025), (x, -0.175, z), m["caos"], corpo, rot=(0, rz, 0))
    for lado in (1, -1):
        esfera("ombreira", 0.18, (0.33 * lado, 0, 1.56), m["armadura"], corpo, escala=(1.15, 1.0, 0.8))
        espinho("espinho_o", (0.36 * lado, 0, 1.68), (0.5 * lado, 0, 1), 0.2, 0.05, m["armadura"], corpo)
        espinho("chifre", (0.15 * lado, 0, 1.9), (0.7 * lado, 0.2, 1), 0.3, 0.05, m["armadura"], corpo)
        nome = "braco_e" if lado > 0 else "braco_d"
        p[nome] = braco(nome, 0.12, 0.12, 0.6, (0.35 * lado, 0, 1.52), m["armadura"], corpo)
    esfera("elmo", 0.19, (0, -0.02, 1.8), m["armadura"], corpo, escala=(0.95, 1.0, 1.05))
    caixa("viseira", (0.24, 0.04, 0.05), (0, -0.2, 1.8), m["caos_c"], corpo)
    galho("punho", (-0.35, 0.05, 0.92), (-0.35, -0.12, 0.92), 0.03, m["couro_d"], p["braco_d"])
    caixa("guarda", (0.3, 0.05, 0.05), (-0.35, -0.13, 0.92), m["armadura"], p["braco_d"])
    galho("lamina", (-0.35, -0.14, 0.92), (-0.35, -1.15, 1.0), 0.065, m["aco"], p["braco_d"], vertices=4)
    galho("fio", (-0.35, -0.2, 0.95), (-0.35, -1.12, 1.03), 0.02, m["caos"], p["braco_d"], vertices=4)
    corpo.scale = (1.2, 1.2, 1.2)   # elite: bem maior que os cavaleiros ocos

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.3 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.3 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.3 * s, 0, 0)
        p["braco_d"].rotation_euler = (-0.4 + 0.2 * s, 0, 0)
        corpo.location = (0, 0, 0.03 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def soberano_caos(m):
    """O Soberano do Caos (chefe final, no Trono do Caos): rei colossal que flutua sobre um manto rasgado em fiapos de sombra.
    Armadura negra rachada com o caos aceso por dentro, rosto que é só escuro e dois olhos, coroa de ouro, auréola de
    espinhos atrás da cabeça, asas de sombra em leque, um cetro com a estrela do caos e um orbe na outra mão."""
    raiz, corpo = raiz_corpo()
    p = {}
    cone("manto", 0.95, 0.5, 2.0, (0, 0.05, 1.3), m["manto"], corpo, vertices=14)
    for k in range(7):
        a = k * math.tau / 7
        espinho("fiapo%d" % k, (math.cos(a) * 0.8, 0.05 + math.sin(a) * 0.8, 0.4), (math.cos(a) * 0.4, math.sin(a) * 0.4, -1), 0.45, 0.14, m["manto"], corpo)
    caixa("faixa", (0.16, 0.03, 1.7), (0, -0.66, 1.25), m["pano_s"], corpo, rot=(-0.22, 0, 0))
    esfera("peito", 0.62, (0, 0, 2.75), m["armadura"], corpo, escala=(1.15, 0.8, 0.95))
    for k, (x, z, rz) in enumerate(((0.25, 2.95, 0.6), (-0.3, 2.7, -0.5), (0.05, 2.5, 0.15), (0.35, 2.45, -0.3))):
        caixa("racha%d" % k, (0.42, 0.03, 0.04), (x, -0.49, z), m["caos"], corpo, rot=(0, rz, 0))
    for lado in (1, -1):
        esfera("ombreira", 0.36, (0.72 * lado, 0, 3.15), m["armadura"], corpo, escala=(1.1, 1.0, 0.8))
        for k in range(3):
            espinho("esp%d" % k, ((0.72 + (k - 1) * 0.15) * lado, 0, 3.4), (0.4 * lado, 0, 1), 0.35 - k * 0.06, 0.07, m["armadura"], corpo)
    esfera("cabeca", 0.34, (0, -0.1, 3.75), m["armadura"], corpo)
    caixa("vazio", (0.4, 0.06, 0.32), (0, -0.42, 3.72), m["negro"], corpo)
    for x in (0.1, -0.1):
        esfera("olho", 0.055, (x, -0.47, 3.78), m["caos_c"], corpo)
    cilindro("coroa", 0.36, 0.14, (0, -0.1, 4.05), m["ouro"], corpo, vertices=12)
    for k in range(7):
        a = k * math.tau / 7
        espinho("ponta%d" % k, (math.cos(a) * 0.34, -0.1 + math.sin(a) * 0.34, 4.12), (0, 0, 1), 0.3, 0.06, m["ouro"], corpo)
    j = junta("aureola", (0, 0.3, 3.85), corpo)   # auréola de espinhos atrás da cabeça (larga: passa dos ombros)
    for k in range(16):
        a = k * math.tau / 16
        espinho("halo%d" % k, (math.cos(a) * 0.95, 0.3, 3.85 + math.sin(a) * 0.95), (math.cos(a), 0, math.sin(a)), 0.32, 0.07,
                m["caos"] if k % 2 else m["armadura"], j)
    p["aureola"] = j
    for lado in (1, -1):   # asas de sombra: leque de lâminas que afinam na ponta (pena, não tábua)
        nome = "asa_e" if lado > 0 else "asa_d"
        jj = junta(nome, (0.45 * lado, 0.45, 3.2), corpo)
        for k in range(6):
            ang = 0.15 + k * 0.25
            comp = 2.3 - abs(k - 2) * 0.22
            espinho(nome + "_pena%d" % k, (0.45 * lado, 0.45 + 0.04 * k, 3.2), (math.cos(ang) * lado, 0.08, math.sin(ang) * 0.75),
                    comp, 0.2 - k * 0.015, m["sombra"], jj)
        p[nome] = jj
    for lado in (1, -1):
        nome = "braco_e" if lado > 0 else "braco_d"
        p[nome] = braco(nome, 0.26, 0.28, 1.2, (0.82 * lado, 0, 3.05), m["armadura"], corpo)
    galho("cetro", (-0.82, 0.2, 1.4), (-0.82, -0.5, 2.7), 0.06, m["ouro"], p["braco_d"])
    esfera("estrela", 0.16, (-0.82, -0.55, 2.8), m["caos_c"], p["braco_d"])
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        espinho("raio_e%d" % k, (-0.82, -0.55, 2.8), (math.cos(a), -0.2, math.sin(a)), 0.3, 0.05, m["caos"], p["braco_d"])
    esfera("orbe", 0.2, (0.82, -0.3, 1.8), m["caos"], p["braco_e"])
    corpo.scale = (1.35, 1.35, 1.35)   # o maior de todos

    def pose(fase, q):
        s = math.sin(fase)
        corpo.location = (0, 0, 0.45 + 0.1 * s)   # flutua acima do chão
        p["asa_e"].rotation_euler = (0, -0.25 * s, 0)
        p["asa_d"].rotation_euler = (0, 0.25 * s, 0)
        p["braco_e"].rotation_euler = (-0.5 + 0.15 * s, 0, 0)
        p["braco_d"].rotation_euler = (-0.3 - 0.1 * s, 0, 0)
    return raiz, corpo, p, pose


# nome: (modelo, largura, altura, giro (não usado), rampas da paleta)
INIMIGOS = {
    "cultista": (cultista, 38, 52, 0.0, ("caos", "sangue", "aco")),
    "cavaleiro_caos": (cavaleiro_caos, 70, 84, 0.0, ("aco", "caos", "sangue", "couro")),
    "soberano_caos": (soberano_caos, 180, 180, 0.0, ("aco", "caos", "ouro", "sangue")),
}

monstros.rodar(INIMIGOS, mats, projeteis=(
    ("bola_caos", 9, ["3d1046", "6e1a6e", "a62a8f", "e04aa8", "ff9ad8"]),
    ("estrela_caos", 13, ["ff9ad8", "e04aa8", "3d1046", "0d0b14"]),   # ao contrário: borda acesa, miolo escuro
), rotulo="REINO")

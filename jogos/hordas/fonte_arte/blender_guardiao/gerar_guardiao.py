"""Guardião de Pedra (aliado "guardiao_pedra") em 3D procedural, 5 vistas, ANDAR e ATAQUE (esmaga com os dois punhos).

Mesmo esquema de câmera dos monstros v2, do Golem e do Urso: 45 graus, ortográfica, 24,5 px por unidade, vistas 0/45/90/135/180
(frente, 3/4 frente, lado, 3/4 costas, costas), o bicho olhando para a DIREITA (o jogo espelha para a esquerda).
Mesmo esqueleto e mesmo andar do Golem (gerar_golem.py: o pé é posicionado e não escorrega), mas de blocos de pedra cinza com rachaduras e
musgo, mais quadrado, ereto e menor que o Golem.

Saída: projeto/assets/v2/armas/guardiao_pedra_dir.png, 16 colunas x 5 linhas de quadros do mesmo tamanho:
  colunas 0-7  = ciclo de ANDAR (passo pesado, 2 pisadas por ciclo: os quadros 2 e 6; o 2 também é o "parado"),
  colunas 8-15 = ATAQUE (8 antecipação, 9 e 10 braços subindo, 11 pico, 12 PANCADA = impacto, 13 punhos no chão, 14 e 15 volta).
  linhas       = frente, 3/4 frente, lado, 3/4 costas, costas.
O .json ao lado (e a cópia em assets/v2/armas/) guarda o quadro, o pé, a passada medida NOS PIXELS por vista e o alcance dos punhos no impacto;
o jogo (v2/andante.gd, ficha `guardiao_pedra`) tem os mesmos números e o teste v2_andante confere.
Uso (Blender 4.5 LTS), em segundo plano:
    blender -b -P gerar_guardiao.py                    # a folha final
    blender -b -P gerar_guardiao.py -- previa <png>    # prévia (frente, 3/4 e perfil; andar e ataque) para ajustar o modelo
    blender -b -P gerar_guardiao.py -- diag            # sem render: o chão e os pés em cada quadro de andar
"""
import json
import math
import os
import sys

import bpy
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
HORDAS = os.path.normpath(os.path.join(AQUI, ".."))
sys.path.insert(0, os.path.join(HORDAS, "modelos3d"))
import pixel3d as px3  # noqa: E402
from monstros import junta, raiz_corpo  # noqa: E402
from pixel3d import caixa, esfera  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIA = ARGS[1] if len(ARGS) >= 2 and ARGS[0] == "previa" else None
DIAG = bool(ARGS) and ARGS[0] == "diag"
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "v2", "armas"))

ELEVACAO = 45.0
PPU = 24.5               # igual aos monstros v2 e ao herói
ESCALA = 0.66            # escala geral do modelo (o guardião é ~1,3x o herói; o Golem, com 0,76, é maior)
VISTAS = (0.0, 45.0, 90.0, 135.0, 180.0)
ANDAR = 8
ATAQUE = 8
IMPACTO = 4
W0, H0 = 40, 48          # ponto de partida; o quadro cresce até caber
CONT = np.array([0x1a, 0x1c, 0x22]) / 255.0
NOME = "guardiao_pedra_dir"

FAIXAS = (0.35, 0.62, 1.0)
BASES = {
    "pedra": "8f9298", "pedra_e": "5d616b", "pedra_c": "b9bcbd", "racha": "2b2e35", "musgo": "5f8a3a", "musgo_c": "8db24c",
}


def _srgb(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def _tons(hexa):
    lin = [px3.linear(int(hexa[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    return [[_srgb(c * f) for c in lin] for f in FAIXAS]


OLHO = "ffd86b"
PAL = np.array([t for h in BASES.values() for t in _tons(h)] + [[int(OLHO[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]])


def modelo():
    """O guardião em repouso (frente = -Y, chão = z 0). Devolve as juntas que a pose mexe. Mesmo esqueleto do Golem (mesmas juntas e medidas),
    mas de blocos de pedra cinza, mais quadrado e ereto: sem corcunda, ombros de bloco, rachaduras escuras e musgo."""
    T = px3.material_toon
    C = px3.cor
    mat = {
        "pedra": T("pedra", C(BASES["pedra"]), ruido=0.30, escala_ruido=8.0),
        "pedra_e": T("pedra_e", C(BASES["pedra_e"]), ruido=0.25, escala_ruido=10.0),
        "pedra_c": T("pedra_c", C(BASES["pedra_c"]), ruido=0.30, escala_ruido=12.0),
        "racha": T("racha", C(BASES["racha"])),
        "musgo": T("musgo", C(BASES["musgo"]), ruido=0.35, escala_ruido=14.0),
        "musgo_c": T("musgo_c", C(BASES["musgo_c"]), ruido=0.30, escala_ruido=14.0),
        "olho": px3.material_emissao("olho", C(OLHO)),
    }
    raiz, corpo = raiz_corpo()
    J = {"raiz": raiz, "corpo": corpo}
    # pelve e pernas de bloco
    caixa("pelve", (1.3, 0.9, 0.46), (0, 0, 1.2), mat["pedra_e"], corpo, chanfro=0.06)
    for lado, s in (("e", 1.0), ("d", -1.0)):
        x = 0.45 * s
        quadril = junta("quadril_" + lado, (x, 0, 1.15), corpo)
        caixa("coxa_" + lado, (0.62, 0.66, 0.62), (x, 0, 0.86), mat["pedra"], quadril, chanfro=0.06)
        caixa("racha_coxa_" + lado, (0.06, 0.05, 0.34), (x + 0.12 * s, -0.34, 0.9), mat["racha"], quadril, rot=(0, 0, 0.35))
        joelho = junta("joelho_" + lado, (x, 0, 0.58), quadril)
        caixa("canela_" + lado, (0.58, 0.6, 0.46), (x, 0, 0.4), mat["pedra_e"], joelho, chanfro=0.06)
        caixa("joelheira_" + lado, (0.5, 0.2, 0.3), (x, -0.36, 0.62), mat["pedra_c"], joelho, chanfro=0.05)
        tornozelo = junta("tornozelo_" + lado, (x, 0, 0.3), joelho)
        caixa("pe_" + lado, (0.74, 1.0, 0.3), (x, -0.14, 0.15), mat["pedra"], tornozelo, chanfro=0.06)
        caixa("dedos_" + lado, (0.66, 0.12, 0.2), (x, -0.62, 0.14), mat["pedra_c"], tornozelo, chanfro=0.03)
        J["quadril_" + lado] = quadril
        J["joelho_" + lado] = joelho
        J["tornozelo_" + lado] = tornozelo
    # tronco: um bloco alto e quadrado, placa no peito, lajes nas costas
    tronco = junta("tronco", (0, 0, 1.4), corpo)
    J["tronco"] = tronco
    caixa("torso", (1.5, 1.0, 1.3), (0, 0, 2.05), mat["pedra"], tronco, chanfro=0.07)
    caixa("peitoral", (1.1, 0.22, 0.8), (0, -0.55, 2.2), mat["pedra_c"], tronco, chanfro=0.05)
    caixa("cinto", (1.4, 0.95, 0.2), (0, 0, 1.46), mat["pedra_e"], tronco, chanfro=0.04)
    caixa("laje_costas", (1.1, 0.2, 0.9), (0, 0.55, 2.15), mat["pedra_e"], tronco, chanfro=0.05)
    # rachaduras (linhas escuras) no peito, nas costas e no cinto
    caixa("racha_p1", (0.07, 0.05, 0.7), (0.22, -0.67, 2.2), mat["racha"], tronco, rot=(0, 0, 0.35))
    caixa("racha_p2", (0.4, 0.05, 0.07), (-0.2, -0.67, 2.0), mat["racha"], tronco, rot=(0, -0.3, 0))
    caixa("racha_p3", (0.07, 0.05, 0.45), (-0.34, -0.67, 2.35), mat["racha"], tronco, rot=(0, 0, -0.4))
    caixa("racha_c1", (0.07, 0.05, 0.8), (0.25, 0.66, 2.15), mat["racha"], tronco, rot=(0, 0, -0.3))
    caixa("racha_c2", (0.55, 0.05, 0.07), (-0.1, 0.66, 2.2), mat["racha"], tronco)
    # musgo: no ombro, nas costas e no peito
    esfera("musgo_costas", 0.4, (-0.25, 0.4, 2.7), mat["musgo"], tronco, escala=(1.3, 1.0, 0.4))
    esfera("musgo_costas2", 0.22, (0.35, 0.62, 2.45), mat["musgo_c"], tronco, escala=(1.0, 0.5, 1.2))
    esfera("musgo_peito", 0.2, (0.4, -0.62, 1.8), mat["musgo"], tronco, escala=(1.2, 0.5, 0.9))
    # cabeça: um cubo afundado nos ombros, testa pesada, olhos em fresta
    caixa("cabeca", (0.74, 0.7, 0.62), (0, -0.1, 3.0), mat["pedra"], tronco, chanfro=0.07)
    caixa("testa", (0.82, 0.26, 0.16), (0, -0.4, 3.16), mat["pedra_e"], tronco, chanfro=0.04)
    caixa("queixo", (0.52, 0.2, 0.2), (0, -0.4, 2.82), mat["pedra_e"], tronco, chanfro=0.04)
    for x in (0.18, -0.18):
        caixa("olho", (0.15, 0.06, 0.07), (x, -0.45, 3.0), mat["olho"], tronco)
    esfera("musgo_cabeca", 0.26, (-0.1, -0.02, 3.34), mat["musgo"], tronco, escala=(1.2, 1.0, 0.4))
    esfera("musgo_cabeca2", 0.12, (0.2, 0.12, 3.34), mat["musgo_c"], tronco, escala=(1.0, 1.0, 0.5))
    # braços de bloco: ombro quadrado, cotovelo, punho de pedra
    for lado, s in (("e", 1.0), ("d", -1.0)):
        x = 1.05 * s
        ombro = junta("ombro_" + lado, (x, 0, 2.38), tronco)
        caixa("ombreira_" + lado, (0.72, 0.8, 0.52), (x, 0, 2.5), mat["pedra_c"], ombro, chanfro=0.07)
        caixa("braco_" + lado, (0.6, 0.6, 0.95), (x, 0, 1.95), mat["pedra"], ombro, chanfro=0.06)
        caixa("racha_braco_" + lado, (0.06, 0.05, 0.45), (x + 0.1 * s, -0.31, 1.95), mat["racha"], ombro, rot=(0, 0, 0.3 * s))
        if lado == "e":
            esfera("musgo_ombro", 0.26, (x, 0.0, 2.8), mat["musgo"], ombro, escala=(1.2, 1.1, 0.4))
        cot = junta("cotovelo_" + lado, (x, 0, 1.45), ombro)
        caixa("antebraco_" + lado, (0.54, 0.54, 0.5), (x, 0, 1.25), mat["pedra_e"], cot, chanfro=0.05)
        caixa("punho_" + lado, (0.95, 0.95, 0.74), (x, -0.04, 0.72), mat["pedra"], cot, chanfro=0.08)
        caixa("nocaute_" + lado, (0.74, 0.18, 0.2), (x, -0.5, 0.78), mat["pedra_c"], cot, chanfro=0.03)
        caixa("racha_punho_" + lado, (0.05, 0.05, 0.4), (x - 0.15 * s, -0.5, 0.56), mat["racha"], cot, rot=(0, 0, -0.3 * s))
        J["ombro_" + lado] = ombro
        J["cotovelo_" + lado] = cot
    raiz.scale = (ESCALA, ESCALA, ESCALA)
    return J


# poses ---------------------------------------------------------------------------------------------------------------------------
# Rotação em X: perna/braço pendurado vai para a frente (-Y) com ângulo NEGATIVO; o tronco se inclina para a frente com ângulo POSITIVO.
ATQ = (
    # (z do corpo, inclinação do tronco, ombro, cotovelo, torção do tronco, abertura das pernas)
    (-0.10, -0.06, -0.55, -0.70, 0.00, 0.20),    # 8  agacha e junta os braços à frente
    (-0.04, -0.20, -1.70, -0.60, 0.08, 0.10),    # 9  os braços sobem
    (0.08, -0.34, -2.55, -0.40, 0.10, 0.05),     # 10 quase no alto, tronco para trás
    (0.16, -0.42, -3.00, -0.25, 0.06, 0.0),      # 11 pico: punhos acima da cabeça
    (-0.16, 0.42, -0.45, -0.10, -0.04, 0.25),    # 12 PANCADA: tronco cai para a frente, punhos no chão
    (-0.22, 0.46, -0.40, -0.05, -0.04, 0.30),    # 13 punhos afundados no chão
    (-0.10, 0.18, -0.35, -0.30, 0.0, 0.15),      # 14 começa a se erguer
    (-0.02, 0.06, -0.20, -0.35, 0.0, 0.05),      # 15 volta ao repouso
)
MEMBROS = ("quadril_e", "quadril_d", "joelho_e", "joelho_d", "tornozelo_e", "tornozelo_d", "tronco", "ombro_e", "ombro_d", "cotovelo_e", "cotovelo_d")

# Andar: o pé é posicionado (não é um seno no ângulo do quadril): no apoio ele corre para trás em linha reta, em S/4 por quadro, e o
# corpo avança a velocidade constante, então o pé NÃO escorrega. A perna e o pé de apoio ficam retos e o corpo desce o que a geometria manda.
L = 0.85                 # do quadril ao tornozelo (a perna esticada)
L2 = 0.58                # do joelho ao chão (a canela, para a flexão do joelho)
TETA = 1.05              # ângulo máximo do quadril no apoio duplo (quadros 2 e 6)
A = L * math.sin(TETA)   # o pé vai de +A a -A em relação ao quadril; separação no apoio duplo = 2A; o ciclo (2 passos) = 4A
LEVANTA = 0.36           # quanto a perna que balança sobe acima do chão no meio do passo
BALANCO_X = 0.15         # o corpo se desloca para o lado do pé de apoio
ROLL = 0.14              # o tronco inclina para o lado do apoio


def _suave(t):
    return 0.5 - 0.5 * math.cos(math.pi * t)


def _perna(phi):
    """phi 0..1 = fase da perna (0 = o pé encosta à frente). Devolve (u = pé à frente do quadril, apoio?, progresso do balanço 0..1)."""
    phi %= 1.0
    if phi < 0.5:
        return A * (1.0 - 4.0 * phi), True, 0.0
    psi = (phi - 0.5) * 2.0
    return -A + 2.0 * A * _suave(psi), False, psi


def passo(q):
    """Estado do andar no quadro q (0..7): dicionário por perna ('e', 'd') com ângulo do quadril, joelho, levantada e tornozelo, e o z do corpo."""
    ph = {"d": (q - 2) / 8.0, "e": (q - 6) / 8.0}       # a perna d bate o pé à frente no quadro 2, a e no 6
    est = {}
    for lado in ("e", "d"):
        u, apoio, psi = _perna(ph[lado])
        est[lado] = {"u": u, "apoio": apoio, "psi": psi, "teta": -math.asin(max(-1.0, min(1.0, u / L)))}
    ap = [e for e in est.values() if e["apoio"]]
    z_corpo = -L * (1.0 - min(math.cos(e["teta"]) for e in ap))
    return est, z_corpo


def pose(J, q):
    """q 0..7 = andar; 8..15 = ataque."""
    corpo, tronco = J["corpo"], J["tronco"]
    for n in MEMBROS:
        J[n].rotation_euler = (0, 0, 0)
        J[n].delta_location = (0, 0, 0)
    corpo.rotation_euler = (0, 0, 0)
    if q < ANDAR:
        est, z_corpo = passo(q)
        f = 2.0 * math.pi * q / ANDAR
        for lado in ("e", "d"):
            e = est[lado]
            teta, joelho, sobe = e["teta"], 0.0, 0.0
            if not e["apoio"]:
                # a perna que balança sobe o que a geometria deixaria abaixo do chão, mais a passada por cima dele; o joelho dobra
                afunda = max(0.0, -(z_corpo + L - L * math.cos(teta)))
                lev = afunda + LEVANTA * math.sin(math.pi * e["psi"])
                r_joelho = min(0.75 * lev, 0.9 * L2)
                joelho = math.acos(1.0 - r_joelho / L2)
                sobe = lev - r_joelho
                teta -= 0.30 * math.sin(math.pi * e["psi"])       # a coxa vai à frente do pé enquanto a canela dobra
            J["quadril_" + lado].rotation_euler = (teta, 0, 0)
            J["quadril_" + lado].delta_location = (0, 0, sobe)
            J["joelho_" + lado].rotation_euler = (joelho, 0, 0)
            J["tornozelo_" + lado].rotation_euler = (-(teta + joelho) + 0.15 * math.sin(math.pi * e["psi"]), 0, 0)
            # o braço balança contra a perna do mesmo lado (perna à frente = braço atrás)
            J["ombro_" + lado].rotation_euler = (-0.15 + 0.80 * (e["u"] / A), 0, 0.05 * (1.0 if lado == "e" else -1.0))
            J["cotovelo_" + lado].rotation_euler = (-0.30 - 0.25 * max(0.0, -e["u"] / A), 0, 0)
        # peso: o corpo balança para o lado do pé de apoio, o tronco inclina e gira com o passo
        lado_ap = math.cos(f)     # 1 = apoio na perna e (quadro 0), -1 = na d (quadro 4)
        corpo.location = (BALANCO_X * lado_ap, 0, z_corpo)
        tronco.rotation_euler = (0.10 + 0.04 * abs(math.sin(f)), -ROLL * lado_ap, 0.16 * math.sin(f))
        corpo.rotation_euler = (0, 0.0, -0.08 * math.sin(f))
    else:
        z, lean, omb, cot, giro, abre = ATQ[q - ANDAR]
        corpo.location = (0, 0, z)
        tronco.rotation_euler = (lean, 0, giro)
        for lado, sg in (("e", 1.0), ("d", -1.0)):
            J["ombro_" + lado].rotation_euler = (omb, 0, 0.06 * sg * (1.0 if omb < -1.0 else 0.0))
            J["cotovelo_" + lado].rotation_euler = (cot, 0, 0)
            J["quadril_" + lado].rotation_euler = (-abre * 0.3 * sg, 0, 0.0)


def diag(J, cam=None):
    """Por quadro de andar: o ponto mais baixo de cada pé (z, tem de ser ~0 no apoio e acima de 0 no balanço) e o x do pé no sentido do passo
    (y do modelo, a frente é -Y) em unidades do modelo; no apoio ele anda a mesma distância por quadro (o pé não escorrega)."""
    from mathutils import Vector
    J["raiz"].rotation_euler = (0, 0, 0)
    for q in range(ANDAR):
        pose(J, q)
        bpy.context.view_layer.update()
        linha = []
        for lado in ("e", "d"):
            o = bpy.data.objects["pe_" + lado]
            cs = [o.matrix_world @ Vector(c) for c in o.bound_box]
            zmin = min(c.z for c in cs)
            frente = -sum(c.y for c in cs) / 8.0
            tela = ""
            if cam is not None:
                from bpy_extras.object_utils import world_to_camera_view
                ys = [(1.0 - world_to_camera_view(bpy.context.scene, cam, c).y) * H0 for c in cs]
                tela = " tela_base=%.1f" % max(ys)
            linha.append("%s z=%.3f frente=%.3f%s" % (lado, zmin / ESCALA, frente / ESCALA, tela))
        print("DIAG q=%d  %s   corpo_z=%.3f" % (q, "   ".join(linha), J["corpo"].location.z))
    print("DIAG A=%.4f separacao=%.4f ciclo_px=%.2f" % (A, 2 * A, 4 * A * ESCALA * PPU))


def medir_apoio(J, cena, cam, W, H):
    """O pé de apoio (o d, quadros 2 a 6) como a câmera o vê, medido NOS PIXELS: com o resto do corpo escondido (os punhos balançam e, de frente,
    descem até a altura dos pés e enganam qualquer medida na folha inteira), renderiza só o pé em cada vista e pega o centro do contorno dele.
    Devolve (ciclo_linha, deslize, pes): `ciclo_linha[v]` = px que o corpo anda por ciclo de andar na vista v (2 x o deslocamento do pé de apoio
    entre os quadros 2 e 6: se o corpo andar menos, o pé escorrega); `deslize[v]` = o quanto o pé sai da reta entre o quadro 2 e o 6 (px, 0 = não escorrega);
    `pes[v]` = [x, y] do pé nos quadros 2 a 6, no mesmo sistema da folha (x já espelhado)."""
    raiz = J["raiz"]
    malhas = [o for o in bpy.data.objects if o.type == "MESH"]
    pe = bpy.data.objects["pe_d"]
    ciclos, desl, pes = [], [], []
    for v in range(len(VISTAS)):
        raiz.rotation_euler = (0, 0, -math.radians(VISTAS[v]))
        for o in malhas:
            o.hide_render = o is not pe
        pts = []
        for q in range(2, 7):
            pose(J, q)
            cx = px3.caixa_alfa(px3.render_rgba())
            pts.append(((cx[0] + cx[2]) / 2.0, (cx[1] + cx[3]) / 2.0))
        for o in malhas:
            o.hide_render = False
        pts = [(W - 1 - x, y) for x, y in pts]  # o espelho da folha
        a, b = np.array(pts[0]), np.array(pts[-1])
        ciclos.append(round(2.0 * float(np.linalg.norm(b - a)), 1))
        reta = [a + (b - a) * (i / 4.0) for i in range(5)]
        desl.append(round(max(float(np.linalg.norm(np.array(p) - r)) for p, r in zip(pts, reta)), 2))
        pes.append([[round(x, 1), round(y, 1)] for x, y in pts])
    return ciclos, desl, pes


def alcance_punho(J):
    """Distância (unidades do modelo) do centro do corpo à frente dos punhos no quadro da pancada: o jogo usa para o alcance do golpe.
    Depois do render a raiz fica girada na última vista (costas): zera antes de medir (senão mede o fundo)."""
    from mathutils import Vector
    J["raiz"].rotation_euler = (0, 0, 0)
    pose(J, ANDAR + IMPACTO)
    bpy.context.view_layer.update()
    frente = 0.0
    for n in ("punho_e", "punho_d"):
        o = bpy.data.objects[n]
        frente = max(frente, -min((o.matrix_world @ Vector(c)).y for c in o.bound_box))
    return frente / ESCALA


def main():
    px3.limpar_cena()
    px3.preparar_render(W0, H0)
    cam = px3.camera(elevacao_graus=ELEVACAO, escala=max(W0, H0) / PPU)
    px3.luz()
    J = modelo()
    cena = bpy.context.scene
    if DIAG:
        diag(J, cam)
        print("DIAG alcance_punho=%.3f" % alcance_punho(J))
        return
    esc0 = cam.data.ortho_scale
    cena.render.resolution_x, cena.render.resolution_y = W0 * 3, H0 * 3
    cam.data.ortho_scale = esc0 * 3.0
    vistas = (0, 1, 2) if PREVIA else range(len(VISTAS))
    quadros = range(ANDAR + ATAQUE)
    uniao = None
    raiz = J["raiz"]
    for v in vistas:
        raiz.rotation_euler = (0, 0, -math.radians(VISTAS[v]))
        for q in quadros:
            pose(J, q)
            cx = px3.caixa_alfa(px3.render_rgba())
            uniao = list(cx) if uniao is None else [min(uniao[0], cx[0]), min(uniao[1], cx[1]), max(uniao[2], cx[2]), max(uniao[3], cx[3])]
    uw, uh = uniao[2] - uniao[0] + 1, uniao[3] - uniao[1] + 1
    W, H = max(W0, int(math.ceil(uw)) + 2), max(H0, int(math.ceil(uh)) + 3)
    cx_n = (uniao[0] + uniao[2]) / 2.0 - W0 * 3 / 2.0 + W / 2.0
    by_n = uniao[3] - H0 * 3 / 2.0 + H / 2.0
    cena.render.resolution_x, cena.render.resolution_y = W, H
    maior = max(W, H)
    cam.data.ortho_scale = maior / PPU
    cam.data.shift_x = (cx_n - (W - 1) / 2.0) / maior
    cam.data.shift_y = -(by_n - (H - 2)) / maior
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector
    o = world_to_camera_view(cena, cam, Vector((0.0, 0.0, 0.0)))
    pe_x, pe_y = int(round(o.x * W - 0.5)), int(round((1.0 - o.y) * H - 0.5))
    pe_x = W - 1 - pe_x  # a folha sai espelhada em x ([:, ::-1] abaixo, para o bicho olhar para a direita): o ponto do chão espelha junto
    ciclo = 0.0
    ciclo_linha, deslize, pes_apoio = [], [], []
    if not PREVIA:
        ciclo_linha, deslize, pes_apoio = medir_apoio(J, cena, cam, W, H)
        ciclo = ciclo_linha[2]
    folha = np.zeros((H * len(vistas), W * len(quadros), 4), np.float32)
    for i, v in enumerate(vistas):
        raiz.rotation_euler = (0, 0, -math.radians(VISTAS[v]))
        for j, q in enumerate(quadros):
            pose(J, q)
            im = px3.pixelar(px3.render_rgba(), contorno=True, paleta=PAL, luz_borda=False)[:, ::-1]
            borda = (im[:, :, 3] > 0.5) & np.all(np.abs(im[:, :, :3] - px3.CONTORNO) < 1e-4, axis=2)
            im = im.copy()
            im[:, :, :3][borda] = CONT
            folha[i * H:(i + 1) * H, j * W:(j + 1) * W] = im
    if PREVIA:
        fundo = np.zeros_like(folha)
        fundo[:] = (0.13, 0.17, 0.12, 1.0)
        a = folha[:, :, 3:4]
        comp = fundo * (1 - a) + folha * a
        comp = np.repeat(np.repeat(comp, 2, axis=0), 2, axis=1)
        px3.salvar_png(comp, PREVIA)
        print("GUARDIAO PREVIA", W, H, pe_x, pe_y)
        return
    os.makedirs(SAIDA, exist_ok=True)
    alcance = alcance_punho(J)
    px3.salvar_png(folha, os.path.join(SAIDA, NOME + ".png"))
    info = {"quadro": [W, H], "pe_x": pe_x, "pe_y": pe_y, "andar": ANDAR, "ataque": ATAQUE, "impacto": IMPACTO, "ciclo_px": ciclo,
            "ciclo_linha": ciclo_linha, "deslize_px": deslize, "pe_apoio": pes_apoio, "alcance_pata_px": round(alcance * ESCALA * PPU, 1),
            "linhas": ["frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"]}
    for destino in (os.path.join(AQUI, NOME + ".json"), os.path.join(SAIDA, NOME + ".json")):
        with open(destino, "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1)
            f.write("\n")
    print("GUARDIAO OK", W, H, pe_x, pe_y, "alcance_punho", info["alcance_pata_px"])


main()

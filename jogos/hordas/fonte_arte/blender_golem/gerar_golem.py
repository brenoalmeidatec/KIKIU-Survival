"""Golem de Barro (aliado "golem_barro", e o Colosso de Pedra que é a fusão dele) em 3D procedural, 5 vistas, ANDAR e ATAQUE.

Mesmo esquema de câmera dos monstros v2 (gerar_cara_nova.py): 45 graus, ortográfica, 24,5 px por unidade, vistas 0/45/90/135/180
(frente, 3/4 frente, lado, 3/4 costas, costas), o bicho olhando para a DIREITA (o jogo espelha para a esquerda).

Saída: projeto/assets/v2/armas/golem_barro_dir.png, 16 colunas x 5 linhas de quadros do mesmo tamanho:
  colunas 0-7  = ciclo de ANDAR (passo pesado, 2 pisadas por ciclo: os quadros 2 e 6, pernas afastadas e corpo baixo; o 2 também é o "parado"),
  colunas 8-15 = ATAQUE (8 quadros: 8 antecipação, 9 e 10 braços subindo, 11 pico, 12 PANCADA = impacto, 13 punhos no chão, 14 e 15 volta).
  linhas       = frente, 3/4 frente, lado, 3/4 costas, costas.
O .json ao lado (e a cópia em assets/v2/armas/) guarda o tamanho do quadro e o pé (ponto do chão); o jogo (v2/golem.gd) tem as mesmas constantes e o teste confere.
Uso (Blender 4.5 LTS), em segundo plano:
    blender -b -P gerar_golem.py                    # a folha final
    blender -b -P gerar_golem.py -- previa <png>    # prévia pequena (2 vistas, alguns quadros) para ajustar o modelo
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
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "v2", "armas"))

ELEVACAO = 45.0
PPU = 24.5               # igual aos monstros v2 e ao herói
ESCALA = 0.76            # escala geral do modelo (o golem tem de ficar um bom pedaço maior que o herói)
VISTAS = (0.0, 45.0, 90.0, 135.0, 180.0)
ANDAR = 8
ATAQUE = 8
W0, H0 = 64, 72          # ponto de partida; o quadro cresce até caber
CONT = np.array([0x24, 0x12, 0x0e]) / 255.0

FAIXAS = (0.35, 0.62, 1.0)
BASES = {
    "barro": "b8653d", "barro_e": "824630", "terra": "d9a36e", "pedra": "9a8f86",
}


def _srgb(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def _tons(hexa):
    lin = [px3.linear(int(hexa[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    return [[_srgb(c * f) for c in lin] for f in FAIXAS]


BRASA = "ffb347"
OLHO = "ffe9a0"
PAL = np.array([t for h in BASES.values() for t in _tons(h)]
               + [[int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] for h in (BRASA, OLHO)])


def modelo():
    """O golem em repouso (frente = -Y, chão = z 0). Devolve as juntas que a pose mexe."""
    T = px3.material_toon
    C = px3.cor
    mat = {
        "barro": T("barro", C(BASES["barro"]), ruido=0.28, escala_ruido=7.0),
        "barro_e": T("barro_e", C(BASES["barro_e"]), ruido=0.2, escala_ruido=9.0),
        "terra": T("terra", C(BASES["terra"]), ruido=0.3, escala_ruido=11.0),
        "pedra": T("pedra", C(BASES["pedra"]), ruido=0.25, escala_ruido=10.0),
        "brasa": px3.material_emissao("brasa", C(BRASA)),
        "olho": px3.material_emissao("olho", C(OLHO)),
    }
    raiz, corpo = raiz_corpo()
    J = {"raiz": raiz, "corpo": corpo}
    # pelve e pernas curtas e grossas
    caixa("pelve", (1.35, 0.85, 0.5), (0, 0, 1.2), mat["barro_e"], corpo, chanfro=0.12)
    for lado, x in (("e", 0.45), ("d", -0.45)):
        quadril = junta("quadril_" + lado, (x, 0, 1.15), corpo)
        caixa("coxa_" + lado, (0.6, 0.62, 1.0), (x, 0, 0.62), mat["barro"], quadril, chanfro=0.1)
        caixa("pe_" + lado, (0.74, 1.0, 0.3), (x, -0.14, 0.15), mat["barro_e"], quadril, chanfro=0.07)
        esfera("joelho_" + lado, 0.22, (x * 1.1, -0.28, 0.72), mat["terra"], quadril, escala=(1.0, 0.8, 0.8))
        J["quadril_" + lado] = quadril
    # tronco largo, corcunda e ombros de pedregulho
    tronco = junta("tronco", (0, 0, 1.4), corpo)
    J["tronco"] = tronco
    caixa("torso", (1.55, 1.0, 1.15), (0, 0, 2.0), mat["barro"], tronco, chanfro=0.14)
    caixa("barriga", (1.1, 0.5, 0.6), (0, -0.42, 1.75), mat["barro_e"], tronco, chanfro=0.1)
    esfera("corcunda", 0.58, (0, 0.38, 2.35), mat["barro"], tronco, escala=(1.15, 1.0, 0.85))
    esfera("peito", 0.5, (0, -0.25, 2.35), mat["barro"], tronco, escala=(1.35, 0.55, 0.8))
    for x in (0.55, -0.55):
        esfera("terra_peito", 0.16, (x, -0.52, 1.95), mat["terra"], tronco, escala=(1.0, 0.7, 0.8))
    # brasas dentro das rachaduras do peito e das costas (o que dá vida ao barro)
    caixa("racha_p1", (0.1, 0.06, 0.62), (0.16, -0.53, 2.05), mat["brasa"], tronco, rot=(0, 0.0, 0.3))
    caixa("racha_p2", (0.42, 0.06, 0.1), (-0.05, -0.53, 1.9), mat["brasa"], tronco, rot=(0, 0.2, 0.0))
    caixa("racha_p3", (0.09, 0.06, 0.4), (-0.28, -0.53, 2.2), mat["brasa"], tronco, rot=(0, -0.0, -0.4))
    caixa("racha_c1", (0.08, 0.05, 0.6), (0.2, 0.51, 2.0), mat["brasa"], tronco, rot=(0, 0, -0.25))
    caixa("racha_c2", (0.5, 0.05, 0.08), (-0.1, 0.51, 2.15), mat["brasa"], tronco)
    # cabeça afundada nos ombros: testa pesada, olhos de brasa
    caixa("cabeca", (0.7, 0.66, 0.5), (0, -0.12, 2.98), mat["barro"], tronco, chanfro=0.09)
    caixa("testa", (0.78, 0.26, 0.16), (0, -0.4, 3.12), mat["barro_e"], tronco, chanfro=0.04)
    caixa("queixo", (0.5, 0.2, 0.2), (0, -0.4, 2.8), mat["barro_e"], tronco, chanfro=0.04)
    for x in (0.17, -0.17):
        esfera("olho", 0.1, (x, -0.46, 2.98), mat["olho"], tronco)
    esfera("pedra_cabeca", 0.14, (0.28, 0.1, 3.28), mat["pedra"], tronco, escala=(1.0, 1.0, 0.8))
    # braços enormes: ombro, cotovelo e punho de pedregulho
    for lado, s in (("e", 1.0), ("d", -1.0)):
        x = 1.05 * s
        ombro = junta("ombro_" + lado, (x, 0, 2.38), tronco)
        esfera("ombreira_" + lado, 0.52, (x, 0, 2.42), mat["barro"], ombro, escala=(1.0, 0.95, 0.85))
        esfera("pedra_ombro_" + lado, 0.17, (x + 0.12 * s, 0.1, 2.85), mat["pedra"], ombro, escala=(1, 1, 0.8))
        esfera("terra_ombro_" + lado, 0.15, (x, -0.35, 2.78), mat["terra"], ombro, escala=(1, 0.8, 0.8))
        caixa("braco_" + lado, (0.62, 0.62, 0.95), (x, 0, 1.95), mat["barro"], ombro, chanfro=0.1)
        cot = junta("cotovelo_" + lado, (x, 0, 1.45), ombro)
        caixa("antebraco_" + lado, (0.55, 0.55, 0.5), (x, 0, 1.25), mat["barro_e"], cot, chanfro=0.08)
        caixa("punho_" + lado, (0.95, 0.95, 0.72), (x, -0.04, 0.72), mat["barro"], cot, chanfro=0.14)
        caixa("nocaute_" + lado, (0.7, 0.2, 0.2), (x, -0.5, 0.78), mat["terra"], cot, chanfro=0.04)
        esfera("pedra_punho_" + lado, 0.15, (x - 0.2 * s, -0.46, 0.95), mat["pedra"], cot)
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
MEMBROS = ("quadril_e", "quadril_d", "tronco", "ombro_e", "ombro_d", "cotovelo_e", "cotovelo_d")


def pose(J, q):
    """q 0..7 = andar; 8..15 = ataque."""
    corpo, tronco = J["corpo"], J["tronco"]
    for n in MEMBROS:
        J[n].rotation_euler = (0, 0, 0)
        J[n].delta_location = (0, 0, 0)
    if q < ANDAR:
        f = 2.0 * math.pi * q / ANDAR
        s, c = math.sin(f), math.cos(f)
        for lado, sg in (("e", 1.0), ("d", -1.0)):
            J["quadril_" + lado].rotation_euler = (0.62 * s * sg, 0, 0)
            J["quadril_" + lado].delta_location = (0, 0, 0.16 * max(0.0, c * sg))
            J["ombro_" + lado].rotation_euler = (-0.12 - 0.50 * s * sg, 0, 0)
            J["cotovelo_" + lado].rotation_euler = (-0.30 - 0.18 * max(0.0, -s * sg), 0, 0)
        corpo.location = (0.03 * s, 0, -0.13 * abs(s) + 0.1)
        tronco.rotation_euler = (0.10, 0.10 * s, 0.14 * s)
        corpo.rotation_euler = (0, 0, 0)
    else:
        z, lean, omb, cot, giro, abre = ATQ[q - ANDAR]
        corpo.location = (0, 0, z)
        corpo.rotation_euler = (0, 0, 0)
        tronco.rotation_euler = (lean, 0, giro)
        for lado, sg in (("e", 1.0), ("d", -1.0)):
            J["ombro_" + lado].rotation_euler = (omb, 0, 0.06 * sg * (1.0 if omb < -1.0 else 0.0))
            J["cotovelo_" + lado].rotation_euler = (cot, 0, 0)
            J["quadril_" + lado].rotation_euler = (-abre * 0.3 * sg, 0, 0.0)


def main():
    px3.limpar_cena()
    px3.preparar_render(W0, H0)
    cam = px3.camera(elevacao_graus=ELEVACAO, escala=max(W0, H0) / PPU)
    px3.luz()
    J = modelo()
    cena = bpy.context.scene
    esc0 = cam.data.ortho_scale
    cena.render.resolution_x, cena.render.resolution_y = W0 * 3, H0 * 3
    cam.data.ortho_scale = esc0 * 3.0
    vistas = (0, 2) if PREVIA else range(len(VISTAS))
    quadros = (0, 2, 4, 6, 9, 11, 12, 13) if PREVIA else range(ANDAR + ATAQUE)
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
        comp = np.repeat(np.repeat(comp, 3, axis=0), 3, axis=1)
        px3.salvar_png(comp, PREVIA)
        print("GOLEM PREVIA", W, H, pe_x, pe_y)
        return
    os.makedirs(SAIDA, exist_ok=True)
    px3.salvar_png(folha, os.path.join(SAIDA, "golem_barro_dir.png"))
    info = {"quadro": [W, H], "pe_x": pe_x, "pe_y": pe_y, "andar": ANDAR, "ataque": ATAQUE, "impacto": 4,
            "linhas": ["frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"]}
    for destino in (os.path.join(AQUI, "golem_barro_dir.json"), os.path.join(SAIDA, "golem_barro_dir.json")):
        with open(destino, "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1)
            f.write("\n")
    print("GOLEM OK", W, H, pe_x, pe_y)


main()

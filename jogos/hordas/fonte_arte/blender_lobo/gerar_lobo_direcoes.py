"""Folha do Lobo Espiritual (lobo_espirito) em 5 vistas, a partir do modelo 3D do lobo_sombrio, com material espectral.

A corrida de lado (gerar_lobo_corre.py, arte do Breno) continua sendo a vista de lado. Este script entrega as vistas que ela
não tem: de frente, de costas e os dois 3/4. Mesmo esquema de câmera dos monstros (gerar_cara_nova.py): 45 graus, ortográfica,
vistas 0/45/90/135/180 (frente, 3/4 frente, lado, 3/4 costas, costas), o bicho olhando para a DIREITA (o jogo espelha para a esquerda).

Saída: projeto/assets/v2/armas/lobo_espiritual_dir.png, 8 quadros de corrida (colunas) x 5 vistas (linhas), e o .json com o tamanho do quadro ao lado deste script.
Uso (Blender 4.5 LTS), em segundo plano:
    blender -b -P gerar_lobo_direcoes.py [-- <pasta_de_saida>]
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
sys.path.insert(0, os.path.join(AQUI, "..", "modelos3d"))
import pixel3d as px3  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAIDA = ARGS[0] if ARGS else os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "v2", "armas"))

ELEVACAO = 45.0
PPU = 30.0                 # pixels por unidade: ~58 px de focinho a rabo, o tamanho da arte de lado
QUADROS = 8
VISTAS = (0.0, 45.0, 90.0, 135.0, 180.0)
LARGURA = (1.55, 1.0, 1.1)   # escala do modelo (x = largura do corpo, y = comprimento, z = altura)
W0, H0 = 56, 44            # só o ponto de partida; o quadro cresce até caber
CONT = np.array([0x1e, 0x22, 0x2c]) / 255.0

# tons do espírito (sRGB), do mais escuro ao claro; o toon multiplica a cor-base por 0.35 / 0.62 / 1.0
PAL = np.array([
    [0x4a, 0x5a, 0x72], [0x72, 0x8c, 0xa8], [0xa4, 0xc4, 0xdc], [0xd2, 0xec, 0xfa], [0xf4, 0xfd, 1.0 * 255],
    [0x2a, 0x30, 0x40],            # nariz
    [0x7c, 0xe2, 0xff],            # olho
]) / 255.0

COR_POR_NOME = {          # cor-base (sRGB) por nome de material do lobo_sombrio
    "pelo": (0xf0, 0xf8, 0xff), "pelo_e": (0xb4, 0xd2, 0xec), "osso": (0xff, 0xff, 0xff),
    "carne_e": (0x7c, 0x96, 0xb4), "negro": (0x32, 0x3a, 0x4c),
}


def _lin(h):
    return tuple(px3.linear(c / 255.0) for c in h) + (1.0,)


def toon_espectral(nome, cor_base, faixas=(0.35, 0.62, 1.0), limites=(0.22, 0.55), ruido=0.0, escala_ruido=6.0):
    cor = _lin(COR_POR_NOME.get(nome, (0xd8, 0xea, 0xf8)))
    return px3.material_toon_orig(nome, cor, (0.5, 0.74, 1.0), limites, ruido, escala_ruido)


def emissao_espectral(nome, cor_base, forca=1.0):
    return px3.material_emissao_orig(nome, _lin((0x7c, 0xe2, 0xff)), forca)


px3.material_toon_orig, px3.material_emissao_orig = px3.material_toon, px3.material_emissao
px3.material_toon, px3.material_emissao = toon_espectral, emissao_espectral
import monstros  # noqa: E402

monstros.rodar = lambda *a, **k: None
import floresta  # noqa: E402


def pose_corrida(p, corpo, fase):
    """Galope curto: os pares de patas em oposição, o corpo sobe e desce, balança de um lado e arfa. Os balanços são exagerados
    de propósito: de frente e de costas a câmera alta quase não vê o passo, e o bicho parecia deslizar."""
    s, c = math.sin(fase), math.cos(fase)
    for nome, sinal in (("fe", 1), ("td", 1), ("fd", -1), ("te", -1)):
        p[nome].rotation_euler = (0.95 * s * sinal, 0, 0)
        p[nome].delta_location = (0, 0, 0.07 * max(0.0, c * sinal))
    p["cauda"].rotation_euler = (0, 0, 0.5 * s)
    corpo.location = (0.05 * s, 0, 0.09 * abs(c))
    corpo.rotation_euler = (0.07 * c, 0.10 * s, 0)


def main():
    px3.limpar_cena()
    px3.preparar_render(W0, H0)
    cam = px3.camera(elevacao_graus=ELEVACAO, escala=max(W0, H0) / PPU)
    px3.luz()
    m = floresta.mats()
    raiz, corpo, p, _pose = floresta.lobo_sombrio(m)
    raiz.scale = LARGURA   # o lobo_sombrio é magro de propósito; o espírito precisa de corpo para ler de frente e de costas
    fases = [2.0 * math.pi * k / QUADROS for k in range(QUADROS)]
    cena = bpy.context.scene
    esc0 = cam.data.ortho_scale
    cena.render.resolution_x, cena.render.resolution_y = W0 * 2, H0 * 2
    cam.data.ortho_scale = esc0 * 2.0
    uniao = None
    for ang in VISTAS:
        raiz.rotation_euler = (0, 0, -math.radians(ang))
        for fase in fases:
            pose_corrida(p, corpo, fase)
            cx = px3.caixa_alfa(px3.render_rgba())
            uniao = list(cx) if uniao is None else [min(uniao[0], cx[0]), min(uniao[1], cx[1]), max(uniao[2], cx[2]), max(uniao[3], cx[3])]
    uw, uh = uniao[2] - uniao[0] + 1, uniao[3] - uniao[1] + 1
    W, H = max(W0, int(math.ceil(uw)) + 2), max(H0, int(math.ceil(uh)) + 3)
    cx_n = (uniao[0] + uniao[2]) / 2.0 - W0 + W / 2.0
    by_n = uniao[3] - H0 + H / 2.0
    cena.render.resolution_x, cena.render.resolution_y = W, H
    maior = max(W, H)
    cam.data.ortho_scale = maior / PPU
    cam.data.shift_x = (cx_n - (W - 1) / 2.0) / maior
    cam.data.shift_y = -(by_n - (H - 2)) / maior
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector
    o = world_to_camera_view(cena, cam, Vector((0.0, 0.0, 0.0)))   # onde o chão sob o corpo cai no quadro (o ponto "pé" do jogo)
    pe_x, pe_y = int(round(o.x * W - 0.5)), int(round((1.0 - o.y) * H - 0.5))
    folha = np.zeros((H * len(VISTAS), W * QUADROS, 4), np.float32)
    for v, ang in enumerate(VISTAS):
        raiz.rotation_euler = (0, 0, -math.radians(ang))
        for q, fase in enumerate(fases):
            pose_corrida(p, corpo, fase)
            im = px3.pixelar(px3.render_rgba(), contorno=True, paleta=PAL, luz_borda=False)[:, ::-1]
            borda = (im[:, :, 3] > 0.5) & np.all(np.abs(im[:, :, :3] - px3.CONTORNO) < 1e-4, axis=2)
            im = im.copy()
            im[:, :, :3][borda] = CONT
            folha[v * H:(v + 1) * H, q * W:(q + 1) * W] = im
    os.makedirs(SAIDA, exist_ok=True)
    px3.salvar_png(folha, os.path.join(SAIDA, "lobo_espiritual_dir.png"))
    with open(os.path.join(AQUI, "lobo_espiritual_dir.json"), "w", encoding="utf-8") as f:
        json.dump({"quadro": [W, H], "pe_x": pe_x, "pe_y": pe_y, "quadros": QUADROS,
                   "linhas": ["frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"]}, f, indent=1)
    print("LOBO_DIR OK", W, H, pe_x, pe_y)


main()

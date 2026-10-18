"""Fantasma da Mata (aliado "fantasma_mata") em 3D procedural, 5 vistas, FLUTUAR (o véu ondula) e ASSOMBRAR (bote do capuz com garras de névoa).

Mesmo esquema de câmera dos monstros v2, do Golem e do Espírito do Urso (../blender_urso/gerar_urso.py): 45 graus, ortográfica, 24,5 px por
unidade, vistas 0/45/90/135/180 (frente, 3/4 frente, lado, 3/4 costas, costas), o bicho olhando para a DIREITA (o jogo espelha para a esquerda).
O fantasma é uma figura encapuzada verde-clara, sem pernas: a barra do manto termina em tiras de névoa. A transparência é ASSADA no png (corpo
meio transparente, mais ralo para a barra; olhos e contorno firmes); o brilho e a névoa de surgir e sumir são feitos em código (v2/andante.gd).

Saída: projeto/assets/v2/armas/fantasma_mata_dir.png, 16 colunas x 5 linhas de quadros do mesmo tamanho:
  colunas 0-7  = ciclo de FLUTUAR (o manto ondula em onda do ombro para a barra; fecha em período 8: o jogo roda o ciclo no relógio, `ciclo_s`),
  colunas 8-15 = ATAQUE (8 recua e se encolhe, 9 e 10 abre os braços e cresce, 11 começa o bote, 12 BOTE = impacto: o capuz avança de boca aberta
                 com as garras de névoa à frente, 13 segura, 14 e 15 volta).
  linhas       = frente, 3/4 frente, lado, 3/4 costas, costas.
O .json ao lado (e a cópia em assets/v2/armas/) guarda o tamanho do quadro, o pé (o chão sob o fantasma) e o alcance do bote.
Uso (Blender 4.5 LTS), em segundo plano:
    blender -b -P gerar_fantasma.py                    # a folha final
    blender -b -P gerar_fantasma.py -- previa <png>    # prévia (frente, 3/4 e perfil, flutuar e ataque inteiros) para ajustar o modelo
"""
import json
import math
import os
import sys
import traceback

import bpy
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
HORDAS = os.path.normpath(os.path.join(AQUI, ".."))
sys.path.insert(0, os.path.join(HORDAS, "modelos3d"))
import pixel3d as px3  # noqa: E402
from monstros import junta, raiz_corpo  # noqa: E402
from pixel3d import cone, esfera  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIA = ARGS[1] if len(ARGS) >= 2 and ARGS[0] == "previa" else None
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "v2", "armas"))
NOME = "fantasma_mata_dir"

ELEVACAO = 45.0
PPU = 24.5               # igual aos monstros v2, ao herói e ao Golem
ESCALA = 0.85            # escala geral do modelo
VISTAS = (0.0, 45.0, 90.0, 135.0, 180.0)
ANDAR = 8
ATAQUE = 8
IMPACTO = 4
W0, H0 = 72, 80          # ponto de partida; o quadro cresce até caber

FAIXAS = (0.55, 0.78, 1.0)
BASES = {
    "manto": "a4eeb0", "manto_e": "5fb27a", "capuz": "c4f6c8", "rosto": "0e2a1e", "garra": "ecfff0", "nevoa": "d6fbe0",
}
OLHO = "f4ffc8"


def _srgb(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def _tons(hexa, faixas=FAIXAS):
    lin = [px3.linear(int(hexa[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    return [[_srgb(c * f) for c in lin] for f in faixas]


OLHO_RGB = np.array([int(OLHO[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
PAL = np.array([t for h in BASES.values() for t in _tons(h)] + [list(OLHO_RGB)])
CONT = np.array([0x14, 0x3a, 0x2a]) / 255.0     # contorno verde-escuro (em vez do quase preto dos bichos opacos)

# medidas (unidades do modelo, antes da ESCALA)
PIVO_Z = 0.25            # o tronco inclina e avança em torno daqui (perto da barra: o ombro vai à frente, a barra fica)
OMBRO_Z = 1.5
ROB = (1.5, 1.1, 0.72, 0.40)            # altura do topo de cada gomo do manto (a cadeia que ondula)
RAIO_ROB = ((0.36, 0.44), (0.44, 0.52), (0.52, 0.60), (0.60, 0.66))   # (raio em cima, raio embaixo) de cada gomo
N_TIRAS = 7


def modelo():
    """O fantasma em repouso (frente = -Y, barra em z 0). Devolve as juntas que a pose mexe."""
    T = px3.material_toon
    C = px3.cor
    mat = {n: T(n, C(h), faixas=FAIXAS, ruido=0.18, escala_ruido=8.0) for n, h in BASES.items() if n != "rosto"}
    mat["rosto"] = T("rosto", C(BASES["rosto"]), faixas=(1.0, 1.0, 1.0))
    mat["olho"] = px3.material_emissao("olho", C(OLHO))
    raiz, corpo = raiz_corpo()
    J = {"raiz": raiz, "corpo": corpo}
    tronco = junta("tronco", (0, 0, PIVO_Z), corpo)
    J["tronco"] = tronco
    # gomos do manto: cada um pendurado no de cima, para a onda descer do ombro até a barra
    pai = tronco
    J["rob"] = []
    for i, topo in enumerate(ROB):
        j = junta("rob%d" % i, (0, 0, topo), pai)
        base = ROB[i + 1] if i + 1 < len(ROB) else 0.38
        r_cima, r_baixo = RAIO_ROB[i]
        cone("manto%d" % i, r_baixo, r_cima, topo - base + 0.04, (0, 0, (topo + base) / 2.0), mat["manto"] if i % 2 == 0 else mat["capuz"], j)
        J["rob"].append(j)
        pai = j
    # tiras de névoa na barra (o manto esgarçando): pontas para baixo, uma coroa em volta
    J["tira"] = []
    for k in range(N_TIRAS):
        a = 2.0 * math.pi * k / N_TIRAS + 0.3
        r = 0.5
        comp = (0.55, 0.42, 0.62, 0.38, 0.5, 0.45, 0.58)[k]
        j = junta("tira%d" % k, (r * math.sin(a), -r * math.cos(a), 0.4), pai)
        cone("tira_p%d" % k, 0.0, 0.17, comp, (r * math.sin(a), -r * math.cos(a), 0.4 - comp / 2.0 + 0.02), mat["manto_e"] if k % 2 else mat["nevoa"], j)
        J["tira"].append(j)
    # ombros e capuz
    esfera("ombros", 0.42, (0, 0.0, OMBRO_Z), mat["capuz"], tronco, escala=(1.2, 0.95, 0.55))
    cabeca = junta("cabeca", (0, 0.0, OMBRO_Z + 0.1), tronco)
    J["cabeca"] = cabeca
    esfera("capuz", 0.37, (0, 0.02, OMBRO_Z + 0.42), mat["capuz"], cabeca, escala=(0.95, 1.0, 1.1))
    ponta = cone("capuz_ponta", 0.2, 0.0, 0.5, (0, 0.2, OMBRO_Z + 0.88), mat["capuz"], cabeca)
    ponta.rotation_euler = (-0.55, 0, 0)         # a ponta do capuz cai para trás
    esfera("rosto", 0.31, (0, -0.2, OMBRO_Z + 0.42), mat["rosto"], cabeca, escala=(0.95, 0.62, 1.1))      # o vão do capuz: um buraco escuro grande, para os olhos saltarem
    for x in (0.1, -0.1):
        esfera("olho", 0.1, (x * 1.1, -0.4, OMBRO_Z + 0.48), mat["olho"], cabeca, escala=(1.0, 0.7, 1.35))
    # boca: um oval escuro que abre no bote (a escala em Z é a abertura)
    boca = junta("boca", (0, -0.4, OMBRO_Z + 0.28), cabeca)
    J["boca"] = boca
    esfera("boca_p", 0.1, (0, -0.4, OMBRO_Z + 0.28), mat["rosto"], boca, escala=(0.8, 0.4, 1.0))
    # braços: manga larga que pende, com a mão de névoa e três garras
    J["braco"] = {}
    for lado, x in (("e", 0.4), ("d", -0.4)):
        b = junta("braco_" + lado, (x, -0.02, OMBRO_Z - 0.05), tronco)
        cone("manga_" + lado, 0.2, 0.1, 0.8, (x, -0.02, OMBRO_Z - 0.45), mat["capuz"], b)
        mao = junta("mao_" + lado, (x, -0.02, OMBRO_Z - 0.85), b)
        esfera("palma_" + lado, 0.12, (x, -0.02, OMBRO_Z - 0.88), mat["garra"], mao, escala=(1.0, 1.0, 0.8))
        for k, dx in enumerate((-0.07, 0.0, 0.07)):
            cone("garra_%s%d" % (lado, k), 0.06, 0.0, 0.42, (x + dx * 1.3, -0.02, OMBRO_Z - 1.14), mat["garra"], mao)
        J["braco"][lado] = (b, mao)
    raiz.scale = (ESCALA, ESCALA, ESCALA)
    return J


# poses ---------------------------------------------------------------------------------------------------------------------------
# Rotação em X: o tronco se inclina para a frente (-Y) com ângulo POSITIVO; o braço pendurado vai para a frente com ângulo NEGATIVO.
ATQ = (
    # (y do corpo, z do corpo, inclina o tronco, braço (X, somado à inclinação), braço aberto (Z), mão (X), cabeça, boca, onda do manto)
    (0.22, -0.05, -0.25, -0.2, 0.95, 0.2, -0.25, 0.0, 0.5),       # 8  recua e se encolhe, braços abertos para trás
    (0.12, 0.05, -0.35, -0.8, 1.15, -0.2, -0.30, 0.3, 0.6),       # 9  cresce, braços abrindo
    (0.05, 0.12, -0.35, -1.9, 0.9, -0.4, -0.35, 0.8, 0.5),        # 10 pico: braços para o alto, boca abrindo
    (-0.20, 0.05, 0.15, -1.8, 0.8, -0.3, 0.0, 1.0, 0.7),          # 11 começa o bote
    (-0.70, -0.05, 0.30, -1.3, 1.25, -0.1, 0.0, 1.0, 1.1),        # 12 BOTE: capuz à frente, braços abertos e garras estendidas
    (-0.60, -0.04, 0.28, -1.3, 1.25, -0.1, 0.0, 0.9, 1.0),        # 13 segura
    (-0.25, 0.0, 0.15, -1.2, 0.45, 0.0, 0.1, 0.3, 0.8),           # 14 volta
    (-0.05, 0.0, 0.05, -0.6, 0.4, 0.0, 0.0, 0.0, 0.7),            # 15 assenta
)


def pose(J, q):
    """q 0..7 = flutuar; 8..15 = ataque."""
    corpo, tronco = J["corpo"], J["tronco"]
    for j in (corpo, J["cabeca"], J["boca"]):
        j.rotation_euler = (0, 0, 0)
    anda = q < ANDAR
    if anda:
        f = 2.0 * math.pi * q / ANDAR
        amp, y, z, lean, bx, bz, mao, cab, boca = 1.0, 0.0, 0.05 * math.sin(f), 0.10, -0.45, 0.38, 0.0, 0.0, 0.0
    else:
        f = 2.0 * math.pi * (q - ANDAR) / ANDAR
        y, z, lean, bx, bz, mao, cab, boca, amp = ATQ[q - ANDAR]
    corpo.location = (0, y, z)
    tronco.rotation_euler = (lean + (0.02 * math.sin(2 * f) if anda else 0.0), 0, 0)
    J["cabeca"].rotation_euler = (cab + (0.06 * math.sin(f - 1.2) if anda else 0.0), 0, 0.05 * math.sin(f) if anda else 0.0)
    J["boca"].scale = (1.0, 1.0, max(0.05, boca * 1.6))
    # o manto ondula: a onda desce do ombro até a barra (cada gomo atrasado no anterior) e a barra balança mais
    for i, j in enumerate(J["rob"]):
        a = (0.05 + 0.045 * i) * amp
        j.rotation_euler = (a * 1.6 * math.sin(f - 1.0 * i) + (0.05 * i if not anda else 0.0), a * 1.3 * math.cos(f - 1.0 * i), 0)
    for k, j in enumerate(J["tira"]):
        j.rotation_euler = (0.35 * amp * math.sin(f - 3.3 + 1.1 * k), 0.3 * amp * math.cos(f - 3.3 + 1.7 * k), 0)
    for lado, sinal in (("e", 1.0), ("d", -1.0)):
        b, mao_j = J["braco"][lado]
        fase = f - 0.9 + (math.pi * 0.6 if lado == "d" else 0.0)
        ox = 0.16 * math.sin(fase) if anda else 0.0
        oz = 0.10 * math.cos(fase) if anda else 0.0
        b.rotation_euler = (bx + ox, -sinal * bz * 0.9 + sinal * oz, 0)    # braço aberto: o do lado +x sai para +x
        mao_j.rotation_euler = (mao + (0.25 * math.sin(fase - 0.6) if anda else 0.0), 0, 0)


def alcance_bote():
    """Distância (unidades do modelo) do centro do corpo à ponta mais à frente do fantasma no quadro do bote (garras ou capuz)."""
    from mathutils import Vector
    J_GLOBAL["raiz"].rotation_euler = (0, 0, 0)  # depois do render a raiz fica girada na última vista (costas): mede de frente para -Y
    pose(J_GLOBAL, ANDAR + IMPACTO)
    bpy.context.view_layer.update()
    ponta = 0.0
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        cs = [o.matrix_world @ Vector(c) for c in o.bound_box]
        ponta = max(ponta, -min(c.y for c in cs))
    return ponta / ESCALA


def assar_transparencia(folha, W, H, pe_y):
    """Faz o corpo meio transparente: mais firme em cima (capuz, ombros), mais ralo na barra. Olhos e contorno ficam firmes."""
    cheio = folha[:, :, 3] > 0.5
    ys = np.arange(folha.shape[0]) % H                       # a linha dentro do quadro
    sobe = np.clip((pe_y - ys) / 30.0, 0.0, 1.0)             # 0 na barra, 1 a 30 px acima do chão
    col = (np.arange(folha.shape[1]) // W)[None, :]
    reforco = np.where((col >= 11) & (col <= 13), 0.20, 0.0)     # no bote (quadros 11 a 13) o corpo fica mais firme: destaca do chão e leva o olho ao capuz
    corpo = np.minimum(0.46 + 0.38 * sobe[:, None] + reforco, 0.92)
    olho = cheio & np.all(np.abs(folha[:, :, :3] - OLHO_RGB) < 0.02, axis=2)
    borda = cheio & np.all(np.abs(folha[:, :, :3] - CONT) < 1e-3, axis=2)
    garra = np.zeros_like(cheio)
    for t in _tons(BASES["garra"]):
        garra |= cheio & np.all(np.abs(folha[:, :, :3] - np.array(t)) < 2e-3, axis=2)
    novo = np.where(cheio, corpo, 0.0)
    novo = np.where(garra, np.maximum(novo, 0.92), novo)
    novo = np.where(borda, np.maximum(novo, 0.92), novo)     # contorno verde-escuro de 1 px quase opaco: separa o fantasma do chão
    novo = np.where(olho, 1.0, novo)
    folha[:, :, 3] = novo


J_GLOBAL = None


def main():
    global J_GLOBAL
    px3.limpar_cena()
    px3.preparar_render(W0, H0)
    cam = px3.camera(elevacao_graus=ELEVACAO, escala=max(W0, H0) / PPU)
    px3.luz()
    J = modelo()
    J_GLOBAL = J
    cena = bpy.context.scene
    esc0 = cam.data.ortho_scale
    cena.render.resolution_x, cena.render.resolution_y = W0 * 3, H0 * 3
    cam.data.ortho_scale = esc0 * 3.0
    vistas = (0, 1, 2) if PREVIA else range(len(VISTAS))
    quadros = range(ANDAR + ATAQUE)
    uniao = None
    raiz = J["raiz"]
    for v in range(len(VISTAS)):
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
    pe_x = W - 1 - pe_x  # a folha sai espelhada em x: o ponto do chão espelha junto
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
    alcance = alcance_bote()
    assar_transparencia(folha, W, H, pe_y)
    if PREVIA:
        fundo = np.zeros_like(folha)
        fundo[:] = (0.13, 0.17, 0.12, 1.0)
        a = folha[:, :, 3:4]
        comp = fundo * (1 - a) + folha * a
        comp = np.repeat(np.repeat(comp, 2, axis=0), 2, axis=1)
        px3.salvar_png(comp, PREVIA)
        print("FANTASMA PREVIA", W, H, pe_x, pe_y, "alcance_px", round(alcance * ESCALA * PPU, 1))
        return
    os.makedirs(SAIDA, exist_ok=True)
    px3.salvar_png(folha, os.path.join(SAIDA, NOME + ".png"))
    info = {"quadro": [W, H], "pe_x": pe_x, "pe_y": pe_y, "andar": ANDAR, "ataque": ATAQUE, "impacto": IMPACTO,
            "alcance_pata_px": round(alcance * ESCALA * PPU, 1),
            "linhas": ["frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"]}
    for destino in (os.path.join(AQUI, NOME + ".json"), os.path.join(SAIDA, NOME + ".json")):
        with open(destino, "w", encoding="utf-8", newline="\n") as f:
            json.dump(info, f, indent=1)
            f.write("\n")
    print("FANTASMA OK", W, H, pe_x, pe_y, "alcance", info["alcance_pata_px"])


try:
    main()
except Exception:
    with open(os.path.join(os.environ.get("TEMP", AQUI), "gerar_fantasma_erro.txt"), "w", encoding="utf-8") as f:
        traceback.print_exc(file=f)
    raise

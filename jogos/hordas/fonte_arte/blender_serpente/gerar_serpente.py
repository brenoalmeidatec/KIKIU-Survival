"""Serpente Ardente (aliado "serpente_ardente") em 3D procedural, 5 vistas, ONDULAR (rastejar) e BOTE (a cabeça de brasa dispara e estala).

Mesmo esquema de câmera dos monstros v2, do Golem e do Espírito do Urso (../blender_urso/gerar_urso.py): 45 graus, ortográfica, 24,5 px por
unidade, vistas 0/45/90/135/180 (frente, 3/4 frente, lado, 3/4 costas, costas), o bicho olhando para a DIREITA (o jogo espelha para a esquerda).
A serpente é uma fila de esferas de brasa (vermelho-brasa por baixo, laranja por cima, um fio amarelo no meio das costas) com uma crista de chamas
e a cabeça de brasa com presas e olhos amarelos. O corpo tem comprimento FIXO: a linha central (onda lateral e vertical, mais o pescoço erguido) é
refeita a cada quadro e as esferas são postas a passos iguais de comprimento de arco, então a cobra nunca estica nem se parte. O ar de fogo (halo,
névoa de nascer e sumir, faíscas do estalo) é feito em código, em v2/andante.gd.

Saída: projeto/assets/v2/armas/serpente_ardente_dir.png, 16 colunas x 5 linhas de quadros do mesmo tamanho:
  colunas 0-7  = ciclo de RASTEJAR (a onda desce da cabeça à cauda e fecha em período 8; o jogo roda o ciclo no relógio, `ciclo_s`),
  colunas 8-15 = ATAQUE (8 se enrosca, 9 e 10 ergue o pescoço e arma o bote, 11 dispara, 12 BOTE = impacto: a cabeça chega à frente de boca aberta,
                 13 segura e estala, 14 e 15 recolhe).
  linhas       = frente, 3/4 frente, lado, 3/4 costas, costas.
O .json ao lado (e a cópia em assets/v2/armas/) guarda o tamanho do quadro, o pé e o alcance do bote (a ponta da cabeça).
Uso (Blender 4.5 LTS), em segundo plano:
    blender -b -P gerar_serpente.py                    # a folha final
    blender -b -P gerar_serpente.py -- previa <png>    # prévia (frente, 3/4 e perfil, rastejar e ataque inteiros) para ajustar o modelo
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
NOME = "serpente_ardente_dir"

ELEVACAO = 45.0
PPU = 24.5               # igual aos monstros v2, ao herói e ao Golem
ESCALA = 0.80            # escala geral do modelo
VISTAS = (0.0, 45.0, 90.0, 135.0, 180.0)
ANDAR = 8
ATAQUE = 8
IMPACTO = 4
W0, H0 = 72, 80          # ponto de partida; o quadro cresce até caber

FAIXAS = (0.62, 0.82, 1.0)
BASES = {"corpo": "f2641a", "ventre": "b8300e", "cabeca": "ffa030", "boca": "4a0a06", "presa": "fff0cc"}
EMISSAO = {"chama": "ff9a28", "nucleo": "ffd84e", "olho": "fff7a8"}


def _srgb(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def _tons(hexa, faixas=FAIXAS):
    lin = [px3.linear(int(hexa[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    return [[_srgb(c * f) for c in lin] for f in faixas]


def _rgb(hexa):
    return [int(hexa[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]


PAL = np.array([t for h in BASES.values() for t in _tons(h)] + [_rgb(h) for h in EMISSAO.values()])
CONT = np.array([0x3a, 0x0c, 0x06]) / 255.0

N = 19                   # esferas do corpo (da cabeça à cauda)
COMPRIMENTO = 3.1        # comprimento fixo da cobra (unidades do modelo)
M = 240                  # amostras da linha central
ONDAS = 1.5              # ondas inteiras ao longo do corpo
K_CHAMA = (2, 4, 6, 8, 10, 12, 14)   # em quais esferas nasce uma chama das costas


def raio(t):
    """Raio da esfera na posição t (0 = cabeça, 1 = cauda): grosso no meio, afina na cauda."""
    base = 0.2 if t < 0.55 else 0.2 * (1.0 - (t - 0.55) / 0.45) ** 0.9
    return 1.15 * (base + 0.045 + 0.04 * math.sin(math.pi * min(1.0, t * 1.6)))


def modelo():
    """A serpente em repouso. Devolve as peças que a pose mexe."""
    T = px3.material_toon
    C = px3.cor
    mat = {n: T(n, C(h), faixas=FAIXAS, ruido=0.12, escala_ruido=9.0) for n, h in BASES.items() if n != "boca"}
    mat["boca"] = T("boca", C(BASES["boca"]), faixas=(1.0, 1.0, 1.0))
    for n, h in EMISSAO.items():
        mat[n] = px3.material_emissao(n, C(h))
    raiz, corpo = raiz_corpo()
    J = {"raiz": raiz, "corpo": corpo, "seg": [], "chama": {}, "r": []}
    for i in range(N):
        t = i / (N - 1)
        r = raio(t)
        s = junta("seg%d" % i, (0, 0, 0), corpo)
        esfera("seg_c%d" % i, r, (0, 0, 0), mat["ventre"], s, escala=(1.0, 1.05, 0.95))
        esfera("seg_t%d" % i, r * 0.88, (0, 0, r * 0.22), mat["corpo"], s, escala=(0.95, 1.0, 0.9))
        esfera("seg_f%d" % i, r * 0.38, (0, 0, r * 0.82), mat["nucleo"], s, escala=(0.9, 1.3, 0.7))   # o fio amarelo no meio das costas
        if i in K_CHAMA:
            c = cone("chama%d" % i, r * 0.55, 0.0, 0.34, (0, 0, r + 0.12), mat["chama"], s)
            c.rotation_euler = (-0.4, 0, 0)       # a ponta da chama cai para trás
            c2 = cone("chama_n%d" % i, r * 0.3, 0.0, 0.2, (0, 0.0, r + 0.08), mat["nucleo"], s)
            c2.rotation_euler = (-0.4, 0, 0)
            J["chama"][i] = (c, c2)
        J["seg"].append(s)
        J["r"].append(r)
    # cabeça (de frente para -Y, pivô no centro): crânio, focinho, mandíbula que abre, presas, olhos e uma crista de brasa
    cab = junta("cabeca", (0, 0, 0), corpo)
    J["cabeca"] = cab
    esfera("cranio", 0.27, (0, -0.02, 0.02), mat["cabeca"], cab, escala=(1.0, 1.2, 0.82))
    esfera("focinho", 0.17, (0, -0.3, -0.01), mat["cabeca"], cab, escala=(0.9, 1.25, 0.68))
    mand = junta("mandibula", (0, -0.12, -0.1), cab)
    J["mandibula"] = mand
    esfera("mand_p", 0.15, (0, -0.28, -0.12), mat["ventre"], mand, escala=(0.9, 1.4, 0.45))
    esfera("boca_p", 0.13, (0, -0.28, -0.06), mat["boca"], mand, escala=(0.85, 1.3, 0.35))
    for x in (0.07, -0.07):
        cone("presa", 0.0, 0.035, 0.15, (x, -0.38, -0.12), mat["presa"], cab)
        esfera("olho", 0.075, (x * 2.0, -0.15, 0.13), mat["olho"], cab, escala=(1.0, 0.8, 1.2))
    for k, (x, y, h) in enumerate(((0.0, 0.1, 0.34), (0.14, 0.14, 0.26), (-0.14, 0.14, 0.26))):
        c = cone("crista%d" % k, 0.07, 0.0, h, (x, y, 0.28 + h / 2.0 - 0.05), mat["chama"], cab)
        c.rotation_euler = (-0.5, 0, 0)
    raiz.scale = (ESCALA, ESCALA, ESCALA)
    return J


# poses ---------------------------------------------------------------------------------------------------------------------------
# Rastejar: a cabeça fica em y = -1,45 e a cauda em y = +1,55 (o centro da cobra perto da origem). A linha central é uma onda lateral (x) e uma
# ondulação vertical (z) que descem da cabeça à cauda, mais o pescoço erguido (`alto` na cabeça, descendo até o chão em `pescoco`).
REPOUSO = {"cab_y": -1.45, "cau_y": 1.55, "alto": 0.45, "pescoco": 1.0, "amp": 0.32, "rip": 0.07, "boca": 0.0, "pitch": 0.15, "chama": 1.0}
ATQ = (
    # cab_y, cau_y, alto (cabeça), pescoço (comprimento), amp (onda lateral), rip (ondulação vertical), boca, pitch (cabeça: + olha para cima), chama
    {"cab_y": -1.20, "cau_y": 1.50, "alto": 0.70, "pescoco": 1.0, "amp": 0.50, "rip": 0.10, "boca": 0.0, "pitch": 0.2, "chama": 0.9},     # 8  se enrosca
    {"cab_y": -0.85, "cau_y": 1.40, "alto": 1.10, "pescoco": 1.1, "amp": 0.60, "rip": 0.10, "boca": 0.2, "pitch": 0.0, "chama": 1.1},     # 9  ergue o pescoço
    {"cab_y": -0.65, "cau_y": 1.30, "alto": 1.50, "pescoco": 1.2, "amp": 0.65, "rip": 0.08, "boca": 0.5, "pitch": -0.1, "chama": 1.3},    # 10 arma o bote (a cabeça de lado para a frente)
    {"cab_y": -1.25, "cau_y": 1.00, "alto": 1.00, "pescoco": 1.0, "amp": 0.45, "rip": 0.06, "boca": 0.9, "pitch": -0.35, "chama": 1.3},   # 11 dispara
    {"cab_y": -2.20, "cau_y": 0.55, "alto": 0.38, "pescoco": 0.8, "amp": 0.22, "rip": 0.03, "boca": 1.0, "pitch": -0.30, "chama": 1.5},   # 12 BOTE
    {"cab_y": -2.10, "cau_y": 0.55, "alto": 0.32, "pescoco": 0.8, "amp": 0.20, "rip": 0.03, "boca": 1.0, "pitch": -0.25, "chama": 1.6},   # 13 segura e estala
    {"cab_y": -1.75, "cau_y": 0.95, "alto": 0.50, "pescoco": 0.9, "amp": 0.34, "rip": 0.05, "boca": 0.4, "pitch": 0.0, "chama": 1.2},    # 14 recolhe
    {"cab_y": -1.50, "cau_y": 1.40, "alto": 0.45, "pescoco": 1.0, "amp": 0.32, "rip": 0.07, "boca": 0.0, "pitch": 0.15, "chama": 1.0},    # 15 assenta
)


def linha_central(p, f):
    """Os M pontos da linha central (da cabeça à cauda) para os parâmetros p e a fase f da onda."""
    t = np.linspace(0.0, 1.0, M)
    y = p["cab_y"] + (p["cau_y"] - p["cab_y"]) * t
    ond = 2.0 * math.pi * ONDAS * t - f
    x = p["amp"] * (0.3 + 0.7 * t) * np.sin(ond)
    z = p["rip"] * (0.5 + 0.5 * np.sin(ond + 1.2))
    s = np.abs(y - p["cab_y"])
    z = z + p["alto"] * np.clip(1.0 - s / p["pescoco"], 0.0, 1.0) ** 2
    return np.stack([x, y, z], axis=1)


def amostrar(c, n, comprimento):
    """n pontos em passos iguais de comprimento de arco sobre a polilinha c (o que passa do fim fica empilhado na cauda)."""
    seg = np.linalg.norm(np.diff(c, axis=0), axis=1)
    acum = np.concatenate([[0.0], np.cumsum(seg)])
    alvo = np.minimum(np.linspace(0.0, comprimento, n), acum[-1])
    return np.stack([np.interp(alvo, acum, c[:, k]) for k in range(3)], axis=1)


def pose(J, q):
    """q 0..7 = rastejar; 8..15 = ataque."""
    from mathutils import Vector
    anda = q < ANDAR
    p = REPOUSO if anda else ATQ[q - ANDAR]
    f = 2.0 * math.pi * (q % ANDAR) / ANDAR
    pts = amostrar(linha_central(p, f), N, COMPRIMENTO)
    for i, s in enumerate(J["seg"]):
        s.location = (pts[i][0], pts[i][1], pts[i][2] + J["r"][i])
        if i in J["chama"]:
            esc = p["chama"] * (0.85 + 0.3 * math.sin(f + 1.7 * i)) * (1.0 + 0.2 * math.sin(2.0 * f + i))
            for c in J["chama"][i]:
                c.scale = (1.0, 1.0, esc)
    cab = J["cabeca"]
    topo = pts[0] + np.array([0.0, 0.0, J["r"][0]])
    cab.location = (topo[0], topo[1], topo[2])
    yaw = math.atan2(pts[0][0] - pts[2][0], pts[2][1] - pts[0][1]) * 0.6      # a cabeça acompanha a curva do pescoço
    cab.rotation_euler = (-p["pitch"], 0.0, yaw)       # rotação em X positiva baixa o focinho: pitch positivo olha para cima
    cab.scale = (1.4, 1.4, 1.4)
    J["mandibula"].rotation_euler = (p["boca"] * 0.95, 0, 0)
    if q >= ANDAR + IMPACTO:        # o estalo: a cabeça treme
        cab.location = (topo[0] + 0.03 * math.sin(f * 4.0), topo[1], topo[2])
    return Vector(topo)


def alcance_bote():
    """Distância (unidades do modelo) do centro do corpo à ponta mais à frente da cobra no quadro do bote (a ponta do focinho)."""
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
    if PREVIA:
        fundo = np.zeros_like(folha)
        fundo[:] = (0.13, 0.12, 0.12, 1.0)
        a = folha[:, :, 3:4]
        comp = fundo * (1 - a) + folha * a
        comp = np.repeat(np.repeat(comp, 2, axis=0), 2, axis=1)
        px3.salvar_png(comp, PREVIA)
        print("SERPENTE PREVIA", W, H, pe_x, pe_y, "alcance_px", round(alcance * ESCALA * PPU, 1))
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
    print("SERPENTE OK", W, H, pe_x, pe_y, "alcance", info["alcance_pata_px"])


try:
    main()
except Exception:
    with open(os.path.join(os.environ.get("TEMP", AQUI), "gerar_serpente_erro.txt"), "w", encoding="utf-8") as f:
        traceback.print_exc(file=f)
    raise

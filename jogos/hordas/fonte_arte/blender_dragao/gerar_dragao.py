"""Dragãozinho (aliado "dragao_filhote") em 3D procedural, 5 vistas, VOO (bater de asas) e ATAQUE (sopro de fogo em leque).

Mesmo esquema de câmera dos monstros v2, do Golem e do Urso: 45 graus, ortográfica, 24,5 px por unidade, vistas 0/45/90/135/180
(frente, 3/4 frente, lado, 3/4 costas, costas), o bicho olhando para a DIREITA (o jogo espelha para a esquerda).
Dragão pequeno e vermelho, de asas abertas e cauda curta, barriga amarela, chifres de osso. Ele VOA: o "andar" é o bater de asas (8 quadros por
ciclo, contado no RELÓGIO pelo jogo: `ciclo_s` na ficha), e o corpo está centrado na origem (o ponto do chão do .json é o centro do corpo: o jogo
levanta o desenho `altura` px e deixa a sombra no chão).

Saída: projeto/assets/v2/armas/dragao_filhote_dir.png, 16 colunas x 5 linhas de quadros do mesmo tamanho:
  colunas 0-7  = ciclo de BATER DE ASAS (0 asas no alto, 4 asas embaixo; o 2 também é o "parado"),
  colunas 8-15 = ATAQUE (8 recua a cabeça, 9 e 10 enche o peito e abre a boca, 11 pico, 12 SOPRO = impacto: boca escancarada e o corpo é
                 empurrado para trás, 13 sopro acabando, 14 e 15 fecha a boca e volta).
  linhas       = frente, 3/4 frente, lado, 3/4 costas, costas.
O fogo do sopro NÃO está na folha (é feito em código por cima, no quadro do impacto): a folha mostra a boca abrindo e o corpo recuando.
O .json ao lado (e a cópia em assets/v2/armas/) guarda o quadro, o ponto do corpo e o alcance da boca + sopro no impacto; o jogo (v2/andante.gd,
ficha `dragao_filhote`) tem os mesmos números e o teste v2_andante confere.
Uso (Blender 4.5 LTS), em segundo plano:
    blender -b -P gerar_dragao.py                    # a folha final
    blender -b -P gerar_dragao.py -- previa <png>    # prévia (frente, 3/4 e perfil; voo e ataque) para ajustar o modelo
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
NOME = "dragao_filhote_dir"

ELEVACAO = 45.0
PPU = 24.5               # igual aos monstros v2, ao herói e ao Golem
ESCALA = 1.1             # escala geral do modelo (envergadura de ~58 px)
CABECA_ESC = 1.25        # a cabeça maior que o natural, para ler bem em tamanho de jogo
VISTAS = (0.0, 45.0, 90.0, 135.0, 180.0)
ANDAR = 8
ATAQUE = 8
IMPACTO = 4
W0, H0 = 52, 60          # ponto de partida; o quadro cresce até caber
CICLO_S = 0.5            # segundos por ciclo de bater de asas (o jogo conta no relógio)
SOPRO_PX = 14.0          # o leque de fogo passa da ponta do focinho (em px): entra no alcance do golpe
CONT = np.array([0x2a, 0x0e, 0x0e]) / 255.0

FAIXAS = (0.35, 0.62, 1.0)
BASES = {
    "verm": "d23a30", "verm_e": "8a2222", "barriga": "f0b646", "membrana": "dc5a3a", "osso": "efe3c5", "espinho": "5e1717",
}


def _srgb(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def _tons(hexa):
    lin = [px3.linear(int(hexa[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    return [[_srgb(c * f) for c in lin] for f in FAIXAS]


OLHO = "fff07a"
PAL = np.array([t for h in BASES.values() for t in _tons(h)] + [[int(OLHO[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]])

# Perfil da asa no plano dela (x = para fora a partir do ombro, y = para trás; a frente do bicho é -Y). A parte de dentro (ombro ao cotovelo, mais os
# dedos de trás) fica numa junta no ombro e a de fora (cotovelo à ponta), numa junta no cotovelo; a aresta cotovelo-P5 é o eixo do cotovelo.
COTOVELO = (0.42, -0.14)
DENTRO = [(0.0, -0.02), COTOVELO, (0.42, 0.26), (0.42, 0.5), (0.2, 0.32), (0.04, 0.4)]
FORA = [COTOVELO, (0.92, 0.02), (0.64, 0.16), (0.74, 0.42), (0.42, 0.26)]
OMBRO = (0.15, -0.04, 0.13)


def membrana(nome, pts, pos, mat, pai, s):
    """Polígono plano de asa (com um pouco de espessura) no plano XY da junta; `s` = +1 asa esquerda, -1 direita (espelho em x)."""
    verts = [(s * x, y, 0.0) for x, y in pts]
    me = bpy.data.meshes.new(nome)
    me.from_pydata(verts, [], [list(range(len(verts)))])
    me.update()
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.location = pos
    m = o.modifiers.new("esp", "SOLIDIFY")
    m.thickness = 0.03
    m.offset = 0.0
    o.data.materials.append(mat)
    px3.pendurar(o, pai)
    return o


def osso_asa(nome, a, b, mat, pai, s, pos_junta, esp=0.05):
    """Haste fina da asa de `a` a `b` (coordenadas do perfil), relativa à junta (por isso soma pos_junta)."""
    ax, ay = a[0] * s, a[1]
    bx, by = b[0] * s, b[1]
    comp = math.hypot(bx - ax, by - ay)
    ang = math.atan2(by - ay, bx - ax)
    cx, cy = (ax + bx) / 2.0, (ay + by) / 2.0
    p = (pos_junta[0] + cx, pos_junta[1] + cy, pos_junta[2] + 0.015)
    return caixa(nome, (comp, esp, esp), p, mat, pai, rot=(0, 0, ang))


def modelo():
    """O dragãozinho em repouso (frente = -Y, centro do corpo na origem). Devolve as juntas que a pose mexe."""
    T = px3.material_toon
    C = px3.cor
    mat = {
        "verm": T("verm", C(BASES["verm"]), ruido=0.25, escala_ruido=14.0),
        "verm_e": T("verm_e", C(BASES["verm_e"]), ruido=0.2, escala_ruido=12.0),
        "barriga": T("barriga", C(BASES["barriga"]), ruido=0.2, escala_ruido=10.0),
        "membrana": T("membrana", C(BASES["membrana"]), ruido=0.15, escala_ruido=10.0),
        "osso": T("osso", C(BASES["osso"])),
        "espinho": T("espinho", C(BASES["espinho"])),
        "olho": px3.material_emissao("olho", C(OLHO)),
    }
    raiz, corpo = raiz_corpo()
    J = {"raiz": raiz, "corpo": corpo}
    tronco = junta("tronco", (0, 0, 0), corpo)
    J["tronco"] = tronco
    esfera("corpo_m", 0.25, (0, 0, 0), mat["verm"], tronco, escala=(0.82, 1.3, 0.78))
    esfera("barriga", 0.2, (0, -0.02, -0.08), mat["barriga"], tronco, escala=(0.78, 1.25, 0.6))
    for k, y in enumerate((-0.2, 0.0, 0.2)):  # espinhos nas costas
        caixa("espinho%d" % k, (0.045, 0.1, 0.1), (0, y, 0.2 - 0.02 * k), mat["espinho"], tronco, chanfro=0.01)
    # pernas encolhidas de quem voa
    for lado, s in (("e", 1.0), ("d", -1.0)):
        caixa("perna_f" + lado, (0.08, 0.1, 0.2), (0.11 * s, -0.14, -0.2), mat["verm_e"], tronco, chanfro=0.02)
        caixa("garra_f" + lado, (0.09, 0.14, 0.05), (0.11 * s, -0.17, -0.32), mat["osso"], tronco)
        caixa("perna_t" + lado, (0.1, 0.12, 0.2), (0.13 * s, 0.16, -0.2), mat["verm_e"], tronco, chanfro=0.02)
        caixa("garra_t" + lado, (0.11, 0.16, 0.05), (0.13 * s, 0.13, -0.32), mat["osso"], tronco)
    # pescoço e cabeça
    esfera("pescoco1", 0.13, (0, -0.3, 0.1), mat["verm"], tronco)
    esfera("pescoco2", 0.12, (0, -0.42, 0.19), mat["verm"], tronco)
    esfera("papo", 0.1, (0, -0.33, 0.05), mat["barriga"], tronco, escala=(0.8, 0.9, 0.9))
    cabeca = junta("cabeca", (0, -0.5, 0.22), tronco)
    J["cabeca"] = cabeca
    cabeca.scale = (CABECA_ESC, CABECA_ESC, CABECA_ESC)
    esfera("cranio", 0.19, (0, -0.58, 0.25), mat["verm"], cabeca, escala=(1.0, 1.05, 0.92))
    caixa("focinho", (0.2, 0.24, 0.12), (0, -0.76, 0.22), mat["verm"], cabeca, chanfro=0.03)
    caixa("ventas", (0.14, 0.04, 0.03), (0, -0.885, 0.26), mat["espinho"], cabeca)
    for x in (0.1, -0.1):
        esfera("olho", 0.055, (x * 1.1, -0.64, 0.3), mat["olho"], cabeca)
        caixa("chifre", (0.045, 0.06, 0.17), (x * 0.85, -0.5, 0.4), mat["osso"], cabeca, rot=(-0.6, 0.0, 0.0))
    mandibula = junta("mandibula", (0, -0.65, 0.17), cabeca)
    J["mandibula"] = mandibula
    caixa("mandibula_p", (0.15, 0.24, 0.05), (0, -0.77, 0.15), mat["verm_e"], mandibula, chanfro=0.01)
    caixa("lingua", (0.07, 0.14, 0.02), (0, -0.74, 0.18), mat["membrana"], mandibula)
    # cauda curta, em duas partes
    c1 = junta("cauda1", (0, 0.26, 0.0), tronco)
    esfera("cauda1_m", 0.13, (0, 0.38, 0.0), mat["verm"], c1, escala=(0.8, 1.35, 0.7))
    c2 = junta("cauda2", (0, 0.5, 0.0), c1)
    esfera("cauda2_m", 0.09, (0, 0.6, 0.0), mat["verm"], c2, escala=(0.8, 1.35, 0.7))
    caixa("ponta_cauda", (0.15, 0.12, 0.035), (0, 0.72, 0.0), mat["espinho"], c2, chanfro=0.01)
    J["cauda1"], J["cauda2"] = c1, c2
    # asas: duas partes cada (a de dentro e a de fora, com o cotovelo no meio)
    for lado, s in (("e", 1.0), ("d", -1.0)):
        pos = (OMBRO[0] * s, OMBRO[1], OMBRO[2])
        ombro = junta("asa_" + lado, pos, tronco)
        membrana("mem_dentro_" + lado, DENTRO, pos, mat["membrana"], ombro, s)
        osso_asa("osso_braco_" + lado, (0.0, -0.02), COTOVELO, mat["verm_e"], ombro, s, pos, 0.07)
        osso_asa("osso_dedo_" + lado, COTOVELO, (0.42, 0.5), mat["verm_e"], ombro, s, pos, 0.035)
        cp = (pos[0] + COTOVELO[0] * s, pos[1] + COTOVELO[1], pos[2])
        cot = junta("cot_" + lado, cp, ombro)
        rel = [(x - COTOVELO[0], y - COTOVELO[1]) for x, y in FORA]
        membrana("mem_fora_" + lado, rel, cp, mat["membrana"], cot, s)
        osso_asa("osso_ant_" + lado, (0.0, 0.0), (0.5, 0.16), mat["verm_e"], cot, s, cp, 0.05)
        osso_asa("osso_dedo2_" + lado, (0.0, 0.0), (0.32, 0.56), mat["verm_e"], cot, s, cp, 0.03)
        caixa("garra_asa_" + lado, (0.06, 0.06, 0.06), (cp[0] + 0.52 * s, cp[1] + 0.16, cp[2]), mat["osso"], cot)
        J["asa_" + lado], J["cot_" + lado] = ombro, cot
    raiz.scale = (ESCALA, ESCALA, ESCALA)
    return J


# poses ---------------------------------------------------------------------------------------------------------------------------
# Rotação em X: o tronco com a cabeça para cima = ângulo NEGATIVO (inclinar para a frente, focinho para baixo, é POSITIVO).
ATQ = (
    # (inclinação do tronco, recuo do corpo em y, cabeça, boca)
    (-0.22, 0.04, -0.1, 0.12),    # 8  recua a cabeça, pega fôlego
    (-0.40, 0.08, -0.2, 0.30),    # 9  enche o peito
    (-0.52, 0.12, -0.28, 0.55),   # 10 boca abrindo, cabeça para trás
    (-0.46, 0.14, -0.22, 0.75),   # 11 pico: boca aberta, prestes a cuspir
    (-0.18, 0.24, 0.10, 0.95),    # 12 SOPRO: cabeça vem para a frente, boca escancarada, o corpo é empurrado para trás
    (-0.10, 0.20, 0.08, 0.85),    # 13 sopro acabando
    (0.0, 0.10, 0.0, 0.35),       # 14 fecha a boca
    (0.06, 0.03, 0.0, 0.08),      # 15 volta
)
MEMBROS = ("asa_e", "asa_d", "cot_e", "cot_d", "cauda1", "cauda2", "cabeca", "mandibula", "tronco")


def pose(J, q):
    """q 0..7 = bater de asas; 8..15 = ataque (as asas continuam batendo, com a descida mais forte no sopro)."""
    for n in MEMBROS:
        J[n].rotation_euler = (0, 0, 0)
    corpo = J["corpo"]
    k = q % 8
    fase = 2.0 * math.pi * k / 8.0
    flap = math.cos(fase)         # 1 = asas no alto, -1 = asas embaixo
    if q < ANDAR:
        incl, recuo, cab, boca = 0.10, 0.0, 0.0, 0.04
    else:
        incl, recuo, cab, boca = ATQ[k]
    amp = 0.62 if q < ANDAR else 0.72
    ang = 0.08 + amp * flap       # ângulo da asa sobre a horizontal
    lag = 0.55 * math.cos(fase - 0.9)  # a ponta da asa atrasa em relação ao ombro
    varre = 0.20 - 0.10 * flap    # asa varrida para trás na descida
    for lado, s in (("e", 1.0), ("d", -1.0)):
        J["asa_" + lado].rotation_euler = (0, -s * ang, s * varre)
        J["cot_" + lado].rotation_euler = (0, -s * lag, s * 0.04)
    corpo.location = (0, recuo, -0.07 * flap)
    J["tronco"].rotation_euler = (incl, 0, 0.03 * math.sin(fase))
    J["cabeca"].rotation_euler = (cab, 0, 0)
    J["mandibula"].rotation_euler = (boca, 0, 0)
    J["cauda1"].rotation_euler = (-0.12 + 0.10 * flap, 0, 0.18 * math.sin(fase + 0.6))
    J["cauda2"].rotation_euler = (-0.05 + 0.10 * flap, 0, 0.30 * math.sin(fase + 1.4))


def alcance_boca(J):
    """Distância (unidades do modelo) do centro do corpo à ponta do focinho no quadro do sopro. A raiz fica girada na última vista depois do
    render: zera antes de medir."""
    from mathutils import Vector
    J["raiz"].rotation_euler = (0, 0, 0)
    pose(J, ANDAR + IMPACTO)
    bpy.context.view_layer.update()
    frente = 0.0
    for n in ("focinho", "mandibula_p"):
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
    # o ponto de referência é o centro do corpo (a origem): o quadro é recortado com folga de 1-2 px em volta da união de todas as poses
    cx_n = (uniao[0] + uniao[2]) / 2.0 - W0 * 3 / 2.0 + W / 2.0
    cy_n = (uniao[1] + uniao[3]) / 2.0 - H0 * 3 / 2.0 + H / 2.0
    cena.render.resolution_x, cena.render.resolution_y = W, H
    maior = max(W, H)
    cam.data.ortho_scale = maior / PPU
    cam.data.shift_x = (cx_n - (W - 1) / 2.0) / maior
    cam.data.shift_y = -(cy_n - (H - 1) / 2.0) / maior
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector
    o = world_to_camera_view(cena, cam, Vector((0.0, 0.0, 0.0)))
    pe_x, pe_y = int(round(o.x * W - 0.5)), int(round((1.0 - o.y) * H - 0.5))
    pe_x = W - 1 - pe_x  # a folha sai espelhada em x: o ponto do corpo espelha junto
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
        print("DRAGAO PREVIA", W, H, pe_x, pe_y)
        return
    boca = alcance_boca(J) * ESCALA * PPU
    os.makedirs(SAIDA, exist_ok=True)
    px3.salvar_png(folha, os.path.join(SAIDA, NOME + ".png"))
    info = {"quadro": [W, H], "pe_x": pe_x, "pe_y": pe_y, "andar": ANDAR, "ataque": ATAQUE, "impacto": IMPACTO, "ciclo_s": CICLO_S,
            "alcance_boca_px": round(boca, 1), "sopro_px": SOPRO_PX, "alcance_pata_px": round(boca + SOPRO_PX, 1),
            "linhas": ["frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"]}
    for destino in (os.path.join(AQUI, NOME + ".json"), os.path.join(SAIDA, NOME + ".json")):
        with open(destino, "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1)
            f.write("\n")
    print("DRAGAO OK", W, H, pe_x, pe_y, "boca", info["alcance_boca_px"])


main()

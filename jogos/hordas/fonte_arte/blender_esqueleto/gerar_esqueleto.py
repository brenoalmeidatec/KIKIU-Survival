"""Esqueleto Guerreiro (aliado "esqueleto_guerreiro") em 3D procedural, 5 vistas, ANDAR (corrida) e ATAQUE (corte em arco com a espada curta).

Mesmo esquema de câmera dos monstros v2, do Golem e do Urso: 45 graus, ortográfica, 24,5 px por unidade, vistas 0/45/90/135/180
(frente, 3/4 frente, lado, 3/4 costas, costas), o bicho olhando para a DIREITA (o jogo espelha para a esquerda).
Esqueleto humanoide de ossos branco-amarelados, caveira grande de olhos acesos, caixa torácica com vãos escuros e uma espada curta na mão.

Saída: projeto/assets/v2/armas/esqueleto_guerreiro_dir.png, 16 colunas x 5 linhas de quadros do mesmo tamanho:
  colunas 0-7  = ciclo de ANDAR (corrida: 2 pisadas por ciclo, quadros 2 e 6, pernas afastadas; o 2 também é o "parado"),
  colunas 8-15 = ATAQUE (8 prepara, 9 e 10 a espada sobe, 11 pico atrás da cabeça, 12 CORTE = impacto, 13 espada embaixo, 14 e 15 volta).
  linhas       = frente, 3/4 frente, lado, 3/4 costas, costas.
O .json ao lado (e a cópia em assets/v2/armas/) guarda o tamanho do quadro, o pé, a passada medida NOS PIXELS por vista e o alcance da espada
no impacto (`alcance_pata_px`); o jogo (v2/andante.gd) copia os números na ficha `esqueleto_guerreiro` e o teste confere.
Uso (Blender 4.5 LTS), em segundo plano:
    blender -b -P gerar_esqueleto.py                              # a folha final
    blender -b -P gerar_esqueleto.py -- previa <png> [a|t|todas]  # prévia (frente, 3/4 e perfil; a = só andar, t = só ataque)
    blender -b -P gerar_esqueleto.py -- diag                      # sem render: o chão e os pés em cada quadro, o alcance da espada
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
PARTE = ARGS[2] if len(ARGS) >= 3 else "todas"
DIAG = bool(ARGS) and ARGS[0] == "diag"
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "v2", "armas"))
NOME = "esqueleto_guerreiro_dir"

ELEVACAO = 45.0
PPU = 24.5               # igual aos monstros v2, ao herói e ao Golem
ESCALA = 0.56            # escala geral do modelo: o esqueleto fica do tamanho do herói (~40 px de altura de perfil, medido na folha)
VISTAS = (0.0, 45.0, 90.0, 135.0, 180.0)
ANDAR = 8
ATAQUE = 8
IMPACTO = 4
W0, H0 = 64, 72          # ponto de partida; o quadro cresce até caber
CONT = np.array([0x1c, 0x18, 0x22]) / 255.0
LADO_ESPADA = "e"        # o braço da espada (o que fica perto da câmera no perfil)

FAIXAS = (0.35, 0.62, 1.0)
BASES = {
    "osso": "ece0bc", "osso_e": "b5a47c", "vao": "34303c", "aco": "f0f6f8", "cabo": "7b5233", "ouro": "c9a447",
}


def _srgb(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def _tons(hexa):
    lin = [px3.linear(int(hexa[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    return [[_srgb(c * f) for c in lin] for f in FAIXAS]


OLHO = "9ff2ff"
PAL = np.array([t for h in BASES.values() for t in _tons(h)] + [[int(OLHO[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]])

# medidas do esqueleto (em unidades do modelo, antes da ESCALA)
QUADRIL_Z = 1.42
JOELHO_Z = 0.80
TORN_Z = 0.22
X_PERNA = 0.30
OMBRO_Z = 2.70
X_OMBRO = 0.90
COTOVELO_Z = 2.03
MAO_Z = 1.40
ALFA_ESPADA = -0.52      # a espada sai da mão 30 graus à frente do antebraço (negativo = para a frente)


def modelo():
    """O esqueleto em repouso (frente = -Y, chão = z 0). Devolve as juntas que a pose mexe."""
    T = px3.material_toon
    C = px3.cor
    mat = {
        "osso": T("osso", C(BASES["osso"]), ruido=0.25, escala_ruido=10.0),
        "osso_e": T("osso_e", C(BASES["osso_e"]), ruido=0.2, escala_ruido=9.0),
        "vao": T("vao", C(BASES["vao"])),
        "aco": T("aco", C(BASES["aco"]), ruido=0.1, escala_ruido=8.0),
        "cabo": T("cabo", C(BASES["cabo"]), ruido=0.2, escala_ruido=8.0),
        "ouro": T("ouro", C(BASES["ouro"])),
        "olho": px3.material_emissao("olho", C(OLHO)),
    }
    raiz, corpo = raiz_corpo()
    J = {"raiz": raiz, "corpo": corpo}
    # bacia e pernas de osso (coxa, joelho, canela, pé)
    caixa("pelve", (0.95, 0.5, 0.34), (0, 0.0, 1.5), mat["osso_e"], corpo, chanfro=0.07)
    caixa("sacro", (0.3, 0.2, 0.3), (0, 0.18, 1.55), mat["osso"], corpo, chanfro=0.04)
    for lado, x in (("e", X_PERNA), ("d", -X_PERNA)):
        quadril = junta("quadril_" + lado, (x, 0, QUADRIL_Z), corpo)
        caixa("coxa_" + lado, (0.27, 0.29, 0.64), (x, 0, 1.1), mat["osso"], quadril, chanfro=0.06)
        joelho = junta("joelho_" + lado, (x, 0, JOELHO_Z), quadril)
        esfera("rotula_" + lado, 0.17, (x, -0.04, JOELHO_Z), mat["osso_e"], joelho)
        caixa("canela_" + lado, (0.22, 0.24, 0.6), (x, 0, 0.5), mat["osso"], joelho, chanfro=0.05)
        torn = junta("tornozelo_" + lado, (x, 0, TORN_Z), joelho)
        caixa("pe_" + lado, (0.3, 0.62, 0.2), (x, -0.14, 0.1), mat["osso_e"], torn, chanfro=0.05)
        J["quadril_" + lado], J["joelho_" + lado], J["tornozelo_" + lado] = quadril, joelho, torn
    # tronco: coluna, caixa torácica (costelas com vãos escuros entre elas), clavículas
    tronco = junta("tronco", (0, 0, 1.7), corpo)
    J["tronco"] = tronco
    caixa("coluna", (0.2, 0.22, 1.1), (0, 0.16, 2.2), mat["osso_e"], tronco, chanfro=0.04)
    caixa("miolo", (0.78, 0.5, 0.96), (0, 0.0, 2.3), mat["vao"], tronco)
    for k, (z, w) in enumerate(((1.95, 0.92), (2.28, 1.04), (2.6, 0.92))):
        caixa("costela%d" % k, (w, 0.62, 0.2), (0, -0.02, z), mat["osso"], tronco, chanfro=0.04)
    caixa("esterno", (0.16, 0.1, 0.9), (0, -0.34, 2.3), mat["osso"], tronco, chanfro=0.03)
    caixa("clavicula", (1.64, 0.26, 0.17), (0, -0.04, 2.8), mat["osso_e"], tronco, chanfro=0.04)
    # caveira grande (1/4 da altura), olhos acesos nas órbitas escuras
    cabeca = junta("cabeca", (0, 0, 2.8), tronco)
    J["cabeca"] = cabeca
    caixa("pescoco", (0.16, 0.16, 0.22), (0, 0.02, 2.88), mat["osso_e"], cabeca)
    esfera("cranio", 0.44, (0, 0.0, 3.12), mat["osso"], cabeca, escala=(1.0, 1.08, 0.96))
    caixa("maxilar", (0.34, 0.3, 0.16), (0, -0.28, 2.9), mat["osso"], cabeca, chanfro=0.03)
    for x in (0.19, -0.19):
        esfera("orbita", 0.125, (x, -0.38, 3.16), mat["vao"], cabeca, escala=(1.0, 0.55, 1.15))
        esfera("olho", 0.06, (x, -0.44, 3.16), mat["olho"], cabeca)
    caixa("nariz", (0.08, 0.08, 0.13), (0, -0.46, 3.0), mat["vao"], cabeca)
    mandibula = junta("mandibula", (0, -0.05, 2.92), cabeca)
    J["mandibula"] = mandibula
    caixa("queixo", (0.38, 0.46, 0.14), (0, -0.28, 2.82), mat["osso_e"], mandibula, chanfro=0.03)
    caixa("dentes", (0.32, 0.06, 0.07), (0, -0.5, 2.9), mat["osso"], mandibula)
    # braços de osso; a espada curta na mão do braço LADO_ESPADA
    for lado, s in (("e", 1.0), ("d", -1.0)):
        x = X_OMBRO * s
        ombro = junta("ombro_" + lado, (x, 0, OMBRO_Z), tronco)
        esfera("ombreira_" + lado, 0.2, (x, 0, OMBRO_Z), mat["osso_e"], ombro)
        caixa("umero_" + lado, (0.21, 0.23, 0.62), (x, 0, 2.34), mat["osso"], ombro, chanfro=0.05)
        cot = junta("cotovelo_" + lado, (x, 0, COTOVELO_Z), ombro)
        esfera("cotovelo_p_" + lado, 0.14, (x, 0, COTOVELO_Z), mat["osso_e"], cot)
        caixa("antebraco_" + lado, (0.19, 0.21, 0.58), (x, 0, 1.72), mat["osso"], cot, chanfro=0.05)
        esfera("mao_" + lado, 0.15, (x, 0, MAO_Z), mat["osso_e"], cot)
        J["ombro_" + lado], J["cotovelo_" + lado] = ombro, cot
    # a espada: sai da mão 30 graus à frente do antebraço; a lâmina é larga no plano do corte (vê-se de lado)
    cot = J["cotovelo_" + LADO_ESPADA]
    x = X_OMBRO * (1.0 if LADO_ESPADA == "e" else -1.0)

    def na_espada(d):
        return (x, math.sin(ALFA_ESPADA) * d, MAO_Z - math.cos(ALFA_ESPADA) * d)

    rot = (ALFA_ESPADA, 0, 0)
    caixa("cabo", (0.1, 0.1, 0.3), na_espada(0.05), mat["cabo"], cot, rot=rot)
    caixa("guarda", (0.42, 0.12, 0.08), na_espada(0.24), mat["ouro"], cot, rot=rot)
    caixa("lamina", (0.07, 0.24, 0.98), na_espada(0.77), mat["aco"], cot, rot=rot, chanfro=0.02)
    caixa("ponta", (0.07, 0.15, 0.18), na_espada(1.34), mat["aco"], cot, rot=rot)
    raiz.scale = (ESCALA, ESCALA, ESCALA)
    return J


# poses ---------------------------------------------------------------------------------------------------------------------------
# Rotação em X: perna/braço pendurado vai para a frente (-Y) com ângulo NEGATIVO; o tronco se inclina para a frente com ângulo POSITIVO.
# Rotação em Z do tronco: POSITIVA leva o ombro da espada (+x) para trás.
ATQ = (
    # (abertura das pernas, inclinação do tronco, giro do tronco, ombro da espada, cotovelo da espada, ombro livre, cotovelo livre, cabeça, boca)
    (0.40, -0.12, 0.30, -1.30, -0.90, -0.40, -0.50, -0.05, 0.00),    # 8  prepara, espada recuando
    (0.42, -0.24, 0.45, -2.30, -0.60, -0.70, -0.40, -0.12, 0.10),    # 9  a espada sobe
    (0.45, -0.34, 0.52, -3.00, -0.45, -1.00, -0.40, -0.20, 0.25),    # 10 quase no alto
    (0.45, -0.40, 0.56, -3.30, -0.35, -1.20, -0.40, -0.26, 0.40),    # 11 pico: a espada atrás da cabeça
    (0.62, 0.38, -0.40, -0.85, -0.15, 0.55, -0.60, 0.20, 0.45),      # 12 CORTE: avança, tronco cai, espada à frente e para baixo
    (0.66, 0.46, -0.55, -0.25, 0.00, 0.70, -0.60, 0.26, 0.15),       # 13 a espada termina embaixo
    (0.50, 0.24, -0.25, -0.60, -0.70, 0.30, -0.70, 0.10, 0.00),      # 14 recolhe
    (0.32, 0.10, -0.05, -0.45, -1.00, 0.10, -0.80, 0.03, 0.00),      # 15 volta
)
MEMBROS = (
    "quadril_e", "quadril_d", "joelho_e", "joelho_d", "tornozelo_e", "tornozelo_d", "tronco", "cabeca", "mandibula",
    "ombro_e", "ombro_d", "cotovelo_e", "cotovelo_d",
)

# Andar: o pé é posicionado: no apoio ele corre para trás em linha reta, em S/4 por quadro, e o corpo avança a velocidade constante, então o pé
# NÃO escorrega. Mesma conta do Golem.
L = QUADRIL_Z - TORN_Z   # do quadril ao tornozelo (a perna esticada)
L2 = JOELHO_Z            # do joelho ao chão (para a flexão do joelho)
TETA = 0.72              # ângulo máximo do quadril no apoio duplo (quadros 2 e 6)
A = L * math.sin(TETA)
LEVANTA = 0.46           # quanto a perna que balança sobe acima do chão no meio do passo (corrida)
BALANCO_X = 0.08
ROLL = 0.06


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
    """Estado do andar no quadro q (0..7): dicionário por perna ('e', 'd') com a posição do pé, e o z do corpo."""
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
    corpo.location = (0, 0, 0)
    if q < ANDAR:
        est, z_corpo = passo(q)
        f = 2.0 * math.pi * q / ANDAR
        for lado in ("e", "d"):
            e = est[lado]
            teta, joelho, sobe = e["teta"], 0.0, 0.0
            if not e["apoio"]:
                afunda = max(0.0, -(z_corpo + L - L * math.cos(teta)))
                lev = afunda + LEVANTA * math.sin(math.pi * e["psi"])
                r_joelho = min(0.75 * lev, 0.9 * L2)
                joelho = math.acos(1.0 - r_joelho / L2)
                sobe = lev - r_joelho
                teta -= 0.34 * math.sin(math.pi * e["psi"])       # a coxa vai à frente do pé enquanto a canela dobra
            J["quadril_" + lado].rotation_euler = (teta, 0, 0)
            J["quadril_" + lado].delta_location = (0, 0, sobe)
            J["joelho_" + lado].rotation_euler = (joelho, 0, 0)
            J["tornozelo_" + lado].rotation_euler = (-(teta + joelho) + 0.15 * math.sin(math.pi * e["psi"]), 0, 0)
            # o braço balança contra a perna do mesmo lado; o da espada balança menos e fica dobrado, com a lâmina para a frente
            if lado == LADO_ESPADA:
                J["ombro_" + lado].rotation_euler = (-0.55 + 0.35 * (e["u"] / A), 0, 0.05)
                J["cotovelo_" + lado].rotation_euler = (-1.0, 0, 0)
            else:
                J["ombro_" + lado].rotation_euler = (-0.25 + 0.95 * (e["u"] / A), 0, -0.05)
                J["cotovelo_" + lado].rotation_euler = (-0.85 - 0.3 * max(0.0, -e["u"] / A), 0, 0)
        lado_ap = math.cos(f)     # 1 = apoio na perna e (quadro 0), -1 = na d (quadro 4)
        corpo.location = (BALANCO_X * lado_ap, 0, z_corpo)
        tronco.rotation_euler = (0.20 + 0.04 * abs(math.sin(f)), -ROLL * lado_ap, 0.14 * math.sin(f))
        J["cabeca"].rotation_euler = (-0.10 + 0.03 * math.cos(2 * f), 0, -0.10 * math.sin(f))
        corpo.rotation_euler = (0, 0.0, -0.06 * math.sin(f))
    else:
        s, lean, giro, omb, cot, ombl, cotl, cab, boca = ATQ[q - ANDAR]
        impacto = (q - ANDAR) >= IMPACTO
        # as pernas abertas por igual (a e atrás na preparação, a e à frente do corte): os dois pés ficam no chão sem escorregar nem afundar
        teta_e = -s if impacto else s
        corpo.location = (0, 0, -L * (1.0 - math.cos(s)))
        J["quadril_e"].rotation_euler = (teta_e, 0, 0)
        J["quadril_d"].rotation_euler = (-teta_e, 0, 0)
        J["tornozelo_e"].rotation_euler = (-teta_e, 0, 0)
        J["tornozelo_d"].rotation_euler = (teta_e, 0, 0)
        tronco.rotation_euler = (lean, 0, giro)
        J["cabeca"].rotation_euler = (cab, 0, -0.5 * giro)
        J["mandibula"].rotation_euler = (boca, 0, 0)
        livre = "d" if LADO_ESPADA == "e" else "e"
        J["ombro_" + LADO_ESPADA].rotation_euler = (omb, 0, 0.04)
        J["cotovelo_" + LADO_ESPADA].rotation_euler = (cot, 0, 0)
        J["ombro_" + livre].rotation_euler = (ombl, 0, -0.04)
        J["cotovelo_" + livre].rotation_euler = (cotl, 0, 0)


def _caixa_mundo(nomes):
    """(x0, y0, z0, x1, y1, z1) das peças `nomes` no mundo, em unidades do modelo (sem a ESCALA)."""
    from mathutils import Vector
    bpy.context.view_layer.update()
    pts = []
    for n in nomes:
        o = bpy.data.objects[n]
        pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    return [f(c[i] for c in pts) / ESCALA for f in (min, max) for i in range(3)]


def alcance_espada():
    """Distância (unidades do modelo) do centro do corpo à ponta da espada no quadro do corte, para a frente (-Y), e a altura da ponta."""
    J_GLOBAL["raiz"].rotation_euler = (0, 0, 0)  # depois do render a raiz fica girada na última vista (costas): mede de frente para -Y
    pose(J_GLOBAL, ANDAR + IMPACTO)
    b = _caixa_mundo(["lamina", "ponta", "guarda"])
    return -b[1], b[2]


def diag(J, cam=None):
    """Por quadro de andar: o ponto mais baixo de cada pé (z, ~0 no apoio e acima de 0 no balanço) e a posição no sentido do passo."""
    J["raiz"].rotation_euler = (0, 0, 0)
    for q in range(ANDAR + ATAQUE):
        pose(J, q)
        linha = []
        for lado in ("e", "d"):
            b = _caixa_mundo(["pe_" + lado])
            linha.append("%s z=%.3f frente=%.3f" % (lado, b[2], -(b[1] + b[4]) / 2.0))
        print("DIAG q=%d  %s   corpo_z=%.3f" % (q, "   ".join(linha), J["corpo"].location.z))
    print("DIAG A=%.4f separacao=%.4f ciclo_px=%.2f" % (A, 2 * A, 4 * A * ESCALA * PPU))
    h = _caixa_mundo([o.name for o in bpy.data.objects if o.type == "MESH"])
    pose(J, PARADO)
    h = _caixa_mundo([o.name for o in bpy.data.objects if o.type == "MESH"])
    print("DIAG altura parado = %.2f un = %.1f px de tela" % (h[5], h[5] * ESCALA * PPU * math.cos(math.radians(ELEVACAO))))


PARADO = 2


def medir_apoio(J, cena, cam, W, H):
    """O pé de apoio (o d, quadros 2 a 6) como a câmera o vê, medido NOS PIXELS: com o resto do corpo escondido, renderiza só o pé em cada vista e
    pega o centro do contorno. Devolve (ciclo_linha, deslize, pes): `ciclo_linha[v]` = px que o corpo anda por ciclo de andar na vista v (2 x o
    deslocamento do pé de apoio entre os quadros 2 e 6); `deslize[v]` = o quanto o pé sai da reta (px); `pes[v]` = [x, y] nos quadros 2 a 6
    (x já espelhado, como na folha)."""
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
    if DIAG:
        diag(J, cam)
        print("DIAG alcance_espada=%.3f altura_ponta=%.3f" % alcance_espada())
        return
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
    ciclo = 0.0
    ciclo_linha, deslize, pes_apoio = [], [], []
    if not PREVIA:
        ciclo_linha, deslize, pes_apoio = medir_apoio(J, cena, cam, W, H)
        ciclo = ciclo_linha[2]
    if PREVIA and PARTE == "a":
        quadros = range(ANDAR)
    elif PREVIA and PARTE == "t":
        quadros = range(ANDAR, ANDAR + ATAQUE)
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
        k = 3 if PARTE in ("a", "t") else 2
        comp = np.repeat(np.repeat(comp, k, axis=0), k, axis=1)
        px3.salvar_png(comp, PREVIA)
        print("ESQUELETO PREVIA", W, H, pe_x, pe_y)
        return
    alcance, z_ponta = alcance_espada()
    os.makedirs(SAIDA, exist_ok=True)
    px3.salvar_png(folha, os.path.join(SAIDA, NOME + ".png"))
    info = {"quadro": [W, H], "pe_x": pe_x, "pe_y": pe_y, "andar": ANDAR, "ataque": ATAQUE, "impacto": IMPACTO, "ciclo_px": ciclo,
            "ciclo_linha": ciclo_linha, "deslize_px": deslize, "pe_apoio": pes_apoio,
            "alcance_pata_px": round(alcance * ESCALA * PPU, 1),
            "linhas": ["frente", "tres_quartos_frente", "lado", "tres_quartos_costas", "costas"]}
    for destino in (os.path.join(AQUI, NOME + ".json"), os.path.join(SAIDA, NOME + ".json")):
        with open(destino, "w", encoding="utf-8") as f:
            json.dump(info, f, indent=1)
            f.write("\n")
    print("ESQUELETO OK", W, H, pe_x, pe_y, "alcance_espada", info["alcance_pata_px"], "z_ponta", round(z_ponta, 3))


main()

"""Espírito do Urso (aliado "espirito_urso") em 3D procedural, 5 vistas, ANDAR e ATAQUE (patada).

Mesmo esquema de câmera dos monstros v2 e do Golem (gerar_golem.py): 45 graus, ortográfica, 24,5 px por unidade, vistas 0/45/90/135/180
(frente, 3/4 frente, lado, 3/4 costas, costas), o bicho olhando para a DIREITA (o jogo espelha para a esquerda).
O urso é pardo, de pelagem grossa, com musgo e flores nas costas (a arte que o jogo já tinha); o ar de espírito (surgir em névoa, brilho nos
olhos, dissolver) é feito em código, em v2/andante.gd, por cima desta folha.

Saída: projeto/assets/v2/armas/urso_espiritual_dir.png, 16 colunas x 5 linhas de quadros do mesmo tamanho:
  colunas 0-7  = ciclo de ANDAR (trote: pares diagonais, 2 pisadas por ciclo nos quadros 2 e 6, pernas afastadas; o 2 também é o "parado"),
  colunas 8-15 = ATAQUE (8 quadros: 8 agacha, 9 e 10 se ergue nas patas de trás, 11 pico de pé com a boca aberta, 12 PATADA = impacto,
                 13 patas no chão, 14 e 15 volta).
  linhas       = frente, 3/4 frente, lado, 3/4 costas, costas.
O .json ao lado (e a cópia em assets/v2/armas/) guarda o tamanho do quadro, o pé, a passada medida NOS PIXELS por vista e o alcance da pata
no impacto; o jogo (v2/andante.gd) lê esse .json e o teste confere.
Uso (Blender 4.5 LTS), em segundo plano:
    blender -b -P gerar_urso.py                    # a folha final
    blender -b -P gerar_urso.py -- previa <png>    # prévia (frente, 3/4 e perfil, andar e ataque inteiros) para ajustar o modelo
    blender -b -P gerar_urso.py -- diag            # sem render: o chão e a posição das patas em cada quadro de andar
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
NOME = "urso_espiritual_dir"

ELEVACAO = 45.0
PPU = 24.5               # igual aos monstros v2, ao herói e ao Golem
ESCALA = 0.80            # escala geral do modelo
VISTAS = (0.0, 45.0, 90.0, 135.0, 180.0)
ANDAR = 8
ATAQUE = 8
IMPACTO = 4
W0, H0 = 72, 80          # ponto de partida; o quadro cresce até caber
CONT = np.array([0x22, 0x12, 0x0c]) / 255.0

FAIXAS = (0.35, 0.62, 1.0)
BASES = {
    "pelo": "9a6a3e", "pelo_e": "6a4428", "barriga": "cfa574", "musgo": "6b8f3c", "musgo_c": "93b350",
    "flor_v": "e0463e", "flor_r": "f3a3c0", "flor_b": "f4efdc", "osso": "ece2c4", "nariz": "1c1410",
}


def _srgb(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def _tons(hexa):
    lin = [px3.linear(int(hexa[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    return [[_srgb(c * f) for c in lin] for f in FAIXAS]


OLHO = "bff7e6"
PAL = np.array([t for h in BASES.values() for t in _tons(h)] + [[int(OLHO[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]])

# medidas do esqueleto (em unidades do modelo, antes da ESCALA)
QUADRIL_Z = 1.0          # altura do quadril e do ombro
X_PERNA = 0.40
Y_FRENTE = -0.58         # ombros
Y_TRAS = 0.58            # quadris (e o pivô do tronco ao se erguer)
J_Z = 0.55               # joelho
T_Z = 0.18               # tornozelo (a pata tem 0,18 de altura)


def modelo():
    """O urso em repouso (frente = -Y, chão = z 0). Devolve as juntas que a pose mexe."""
    T = px3.material_toon
    C = px3.cor
    mat = {
        "pelo": T("pelo", C(BASES["pelo"]), ruido=0.3, escala_ruido=12.0),
        "pelo_e": T("pelo_e", C(BASES["pelo_e"]), ruido=0.25, escala_ruido=10.0),
        "barriga": T("barriga", C(BASES["barriga"]), ruido=0.2, escala_ruido=9.0),
        "musgo": T("musgo", C(BASES["musgo"]), ruido=0.35, escala_ruido=14.0),
        "musgo_c": T("musgo_c", C(BASES["musgo_c"]), ruido=0.3, escala_ruido=14.0),
        "flor_v": T("flor_v", C(BASES["flor_v"])),
        "flor_r": T("flor_r", C(BASES["flor_r"])),
        "flor_b": T("flor_b", C(BASES["flor_b"])),
        "osso": T("osso", C(BASES["osso"])),
        "nariz": T("nariz", C(BASES["nariz"])),
        "olho": px3.material_emissao("olho", C(OLHO)),
    }
    raiz, corpo = raiz_corpo()
    J = {"raiz": raiz, "corpo": corpo}
    # pernas de trás (presas ao corpo: ficam no chão quando o tronco se ergue)
    for lado, x in (("e", X_PERNA), ("d", -X_PERNA)):
        _perna_modelo(J, mat, "t" + lado, x, Y_TRAS, corpo, grossa=1.0)
    # o tronco gira no quadril (pivô atrás): costas, ombros, cabeça e pernas da frente vão junto
    tronco = junta("tronco", (0, Y_TRAS, QUADRIL_Z), corpo)
    J["tronco"] = tronco
    esfera("lombo", 0.6, (0, 0.25, 1.1), mat["pelo"], tronco, escala=(0.98, 1.1, 0.88))
    esfera("peito", 0.62, (0, -0.32, 1.12), mat["pelo"], tronco, escala=(1.0, 1.0, 0.95))
    esfera("corcunda", 0.5, (0, -0.5, 1.5), mat["pelo"], tronco, escala=(1.0, 0.95, 0.8))
    esfera("barriga", 0.5, (0, 0.0, 0.78), mat["barriga"], tronco, escala=(0.85, 1.35, 0.45))
    esfera("cauda", 0.13, (0, 0.98, 1.2), mat["pelo_e"], tronco)
    # musgo e flores nas costas, no ombro e no quadril (o que dá a cara de espírito da mata)
    for nome, pos, r, esc, m in (
        ("musgo1", (0.14, -0.1, 1.67), 0.34, (1.15, 1.35, 0.4), "musgo"),
        ("musgo2", (-0.18, 0.5, 1.6), 0.3, (1.1, 1.1, 0.4), "musgo_c"),
        ("musgo3", (0.44, -0.55, 1.58), 0.22, (0.7, 1.0, 0.8), "musgo"),
        ("musgo4", (-0.42, 0.7, 1.35), 0.2, (0.6, 1.0, 0.9), "musgo"),
        ("musgo5", (0.0, -0.75, 1.85), 0.2, (1.0, 1.0, 0.6), "musgo_c"),
    ):
        esfera(nome, r, pos, mat[m], tronco, escala=esc)
    for k, (pos, m) in enumerate((
        ((0.1, -0.15, 1.86), "flor_v"), ((-0.1, 0.5, 1.8), "flor_r"), ((0.2, 0.3, 1.8), "flor_b"), ((0.48, -0.55, 1.78), "flor_v"),
        ((-0.2, 0.7, 1.66), "flor_v"), ((0.0, -0.78, 2.02), "flor_r"), ((0.26, -0.4, 1.9), "flor_b"), ((-0.4, 0.72, 1.55), "flor_r"),
    )):
        esfera("flor%d" % k, 0.075, pos, mat[m], tronco)
    # cabeça (gira no pescoço)
    cabeca = junta("cabeca", (0, -0.95, 1.4), tronco)
    J["cabeca"] = cabeca
    esfera("crânio", 0.4, (0, -1.17, 1.32), mat["pelo"], cabeca, escala=(0.98, 1.0, 0.92))
    esfera("focinho", 0.21, (0, -1.5, 1.2), mat["barriga"], cabeca, escala=(0.8, 1.25, 0.7))
    esfera("nariz", 0.07, (0, -1.72, 1.24), mat["nariz"], cabeca, escala=(1.2, 0.8, 0.8))
    for x in (0.27, -0.27):
        esfera("orelha", 0.12, (x, -1.05, 1.66), mat["pelo_e"], cabeca, escala=(1.0, 0.7, 1.0))
        esfera("olho", 0.055, (x * 0.66, -1.5, 1.4), mat["olho"], cabeca)
    esfera("musgo_cabeca", 0.17, (0.12, -1.0, 1.7), mat["musgo"], cabeca, escala=(1.0, 1.0, 0.5))
    esfera("flor_cabeca", 0.07, (0.14, -1.0, 1.76), mat["flor_r"], cabeca)
    for x in (0.1, -0.1):
        caixa("presa_sup", (0.05, 0.05, 0.1), (x, -1.62, 1.07), mat["osso"], cabeca)
    mandibula = junta("mandibula", (0, -1.3, 1.1), cabeca)
    J["mandibula"] = mandibula
    caixa("mandibula_p", (0.3, 0.45, 0.1), (0, -1.48, 1.04), mat["barriga"], mandibula, chanfro=0.03)
    for x in (0.09, -0.09):
        caixa("presa_inf", (0.05, 0.05, 0.1), (x, -1.64, 1.12), mat["osso"], mandibula)
    # pernas da frente (presas ao tronco)
    for lado, x in (("e", X_PERNA), ("d", -X_PERNA)):
        _perna_modelo(J, mat, "f" + lado, x, Y_FRENTE, tronco, grossa=1.12)
    raiz.scale = (ESCALA, ESCALA, ESCALA)
    return J


def _perna_modelo(J, mat, n, x, y, pai, grossa):
    """Perna de duas partes (coxa e canela) com pata plana e garras: quadril -> joelho -> tornozelo, como as do Golem."""
    g = grossa
    quad = junta("quad_" + n, (x, y, QUADRIL_Z), pai)
    caixa("coxa_" + n, (0.46 * g, 0.5 * g, 0.5), (x, y, 0.78), mat["pelo"], quad, chanfro=0.1)
    joelho = junta("joe_" + n, (x, y, J_Z), quad)
    caixa("canela_" + n, (0.4 * g, 0.42 * g, 0.4), (x, y, 0.35), mat["pelo_e"], joelho, chanfro=0.08)
    torn = junta("tor_" + n, (x, y, T_Z), joelho)
    caixa("pata_" + n, (0.5 * g, 0.66, 0.18), (x, y - 0.1, 0.09), mat["pelo_e"], torn, chanfro=0.06)
    for k in (-1, 0, 1):
        caixa("garra_%s%d" % (n, k), (0.05, 0.1, 0.05), (x + k * 0.13 * g, y - 0.46, 0.06), mat["osso"], torn)
    J["quad_" + n], J["joe_" + n], J["tor_" + n] = quad, joelho, torn


# poses ---------------------------------------------------------------------------------------------------------------------------
# Rotação em X: perna pendurada vai para a frente (-Y) com ângulo NEGATIVO; o tronco se inclina para a frente (focinho para baixo) com ângulo POSITIVO.
ATQ = (
    # (z do corpo, tronco, braço no mundo, cotovelo, cabeça, boca, quadril de trás, joelho de trás)
    (-0.18, 0.12, -0.15, 0.30, 0.25, 0.0, 0.25, 0.9),     # 8  agacha, cabeça baixa
    (-0.10, -0.55, -1.0, 0.20, -0.2, 0.15, 0.1, 0.5),     # 9  levanta o peito
    (-0.04, -0.95, -1.9, -0.2, -0.45, 0.4, 0.03, 0.2),    # 10 de pé, patas subindo
    (0.0, -1.15, -2.45, -0.45, -0.55, 0.65, 0.0, 0.1),    # 11 pico: patas acima da cabeça, boca aberta
    (-0.12, 0.22, -0.65, 0.0, 0.3, 0.4, 0.15, 0.6),       # 12 PATADA: tronco cai, patas no chão à frente
    (-0.14, 0.26, -0.55, 0.0, 0.3, 0.1, 0.18, 0.7),       # 13 patas apoiadas
    (-0.08, 0.05, -0.35, 0.2, 0.1, 0.0, 0.12, 0.5),       # 14 levanta
    (-0.02, 0.0, -0.15, 0.25, 0.05, 0.0, 0.03, 0.15),     # 15 volta ao repouso
)
MEMBROS = (
    "quad_te", "quad_td", "joe_te", "joe_td", "tor_te", "tor_td", "quad_fe", "quad_fd", "joe_fe", "joe_fd", "tor_fe", "tor_fd",
    "tronco", "cabeca", "mandibula",
)

# Andar (trote): o pé é posicionado: no apoio ele corre para trás em linha reta, em S/4 por quadro, e o corpo avança a velocidade constante,
# então o pé NÃO escorrega. Mesma conta do Golem; os pares diagonais (frente-esquerda com trás-direita) andam juntos, meio ciclo defasados.
L = QUADRIL_Z - T_Z                 # do quadril ao tornozelo (a perna esticada)
L2 = J_Z                            # do joelho ao chão (para a flexão do joelho)
TETA = 0.75              # ângulo máximo do quadril no apoio duplo (quadros 2 e 6)
A = L * math.sin(TETA)
LEVANTA = 0.30           # quanto a pata que balança sobe acima do chão no meio do passo
BALANCO_X = 0.10         # o corpo se desloca para o lado das patas de apoio
ROLL = 0.07


def _suave(t):
    return 0.5 - 0.5 * math.cos(math.pi * t)


def _perna(phi):
    """phi 0..1 = fase da perna (0 = a pata encosta à frente). Devolve (u = pata à frente do quadril, apoio?, progresso do balanço 0..1)."""
    phi %= 1.0
    if phi < 0.5:
        return A * (1.0 - 4.0 * phi), True, 0.0
    psi = (phi - 0.5) * 2.0
    return -A + 2.0 * A * _suave(psi), False, psi


def passo(q):
    """Estado do andar no quadro q (0..7) por par diagonal ('a' = frente-esquerda e trás-direita, 'b' = o outro) e o z do corpo."""
    ph = {"a": (q - 2) / 8.0, "b": (q - 6) / 8.0}
    est = {}
    for par in ("a", "b"):
        u, apoio, psi = _perna(ph[par])
        est[par] = {"u": u, "apoio": apoio, "psi": psi, "teta": -math.asin(max(-1.0, min(1.0, u / L)))}
    ap = [e for e in est.values() if e["apoio"]]
    z_corpo = -L * (1.0 - min(math.cos(e["teta"]) for e in ap))
    return est, z_corpo


PARES = {"fe": "a", "td": "a", "fd": "b", "te": "b"}


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
        for n, par in PARES.items():
            e = est[par]
            teta, joelho, sobe = e["teta"], 0.0, 0.0
            if not e["apoio"]:
                afunda = max(0.0, -(z_corpo + L - L * math.cos(teta)))
                lev = afunda + LEVANTA * math.sin(math.pi * e["psi"])
                r_joelho = min(0.75 * lev, 0.9 * L2)
                joelho = math.acos(1.0 - r_joelho / L2)
                sobe = lev - r_joelho
                teta -= 0.25 * math.sin(math.pi * e["psi"])
            J["quad_" + n].rotation_euler = (teta, 0, 0)
            J["quad_" + n].delta_location = (0, 0, sobe)
            J["joe_" + n].rotation_euler = (joelho, 0, 0)
            J["tor_" + n].rotation_euler = (-(teta + joelho), 0, 0)
        lado_ap = math.cos(f)
        corpo.location = (BALANCO_X * lado_ap, 0, z_corpo)
        tronco.rotation_euler = (0, -ROLL * lado_ap, 0.03 * math.sin(f))   # sem arfar o tronco: as patas da frente saem do chão se ele inclina
        J["cabeca"].rotation_euler = (0.12 + 0.05 * math.cos(2 * f), 0, -0.10 * math.sin(f))
        corpo.rotation_euler = (0, 0.0, -0.04 * math.sin(f))
    else:
        _ataque(J, q - ANDAR)


def _min_z(nome):
    """Altura (unidades do modelo) do ponto mais baixo da peça `nome`."""
    from mathutils import Vector
    bpy.context.view_layer.update()
    o = bpy.data.objects[nome]
    return min((o.matrix_world @ Vector(c)).z for c in o.bound_box) / ESCALA


def _resolver(aplicar, medir, lo, hi):
    """Acha o valor em [lo, hi] que leva `medir()` a 0 (bisseção; a medida cresce ou cai de forma monótona com o valor)."""
    aplicar(lo)
    f_lo = medir()
    aplicar(hi)
    f_hi = medir()
    if f_lo * f_hi > 0:
        return lo if abs(f_lo) < abs(f_hi) else hi
    for _ in range(22):
        meio = (lo + hi) / 2.0
        aplicar(meio)
        f = medir()
        if f * f_lo > 0:
            lo, f_lo = meio, f
        else:
            hi = meio
    return (lo + hi) / 2.0


SOL = {}


def _ataque(J, k):
    """Quadro k (0..7) do ataque. As patas que têm de estar no chão (marcadas em PLANTA) são resolvidas por bisseção: o ângulo do braço (frente)
    e a flexão do joelho (trás) que levam a sola a z = 0, para a pata nunca afundar nem boiar."""
    z, lean, omb, cot, cab, boca, qt, jt = ATQ[k]
    J["corpo"].location = (0, 0, z)
    J["tronco"].rotation_euler = (lean, 0, 0)
    J["cabeca"].rotation_euler = (cab, 0, 0)
    J["mandibula"].rotation_euler = (boca, 0, 0)

    def braco(v):
        for lado in ("e", "d"):
            J["quad_f" + lado].rotation_euler = (v - lean, 0, 0.05 if lado == "e" else -0.05)  # o ombro desfaz a inclinação do tronco
            J["joe_f" + lado].rotation_euler = (cot, 0, 0)
            J["tor_f" + lado].rotation_euler = (-(v + cot) if k in PLANTA_F else 0.3, 0, 0)

    def trás(v):
        for lado in ("e", "d"):
            J["quad_t" + lado].rotation_euler = (-qt, 0, 0)
            J["joe_t" + lado].rotation_euler = (v, 0, 0)
            J["tor_t" + lado].rotation_euler = (qt - v, 0, 0)

    trás(jt)
    braco(omb)
    if k in PLANTA_F:
        if k not in SOL:
            SOL[k] = {}
        SOL[k]["f"] = _resolver(braco, lambda: _min_z("pata_fe"), omb - 0.7, omb + 0.7) if "f" not in SOL[k] else SOL[k]["f"]
        braco(SOL[k]["f"])
    if k in PLANTA_T:
        if k not in SOL:
            SOL[k] = {}
        SOL[k]["t"] = _resolver(trás, lambda: _min_z("pata_te"), 0.0, 1.5) if "t" not in SOL[k] else SOL[k]["t"]
        trás(SOL[k]["t"])


PLANTA_F = (0, 4, 5, 7)   # quadros do ataque em que as patas da frente estão no chão
PLANTA_T = (0, 1, 2, 3, 4, 5, 6, 7)   # as de trás estão sempre


def pata_da_frente():
    """Distância (unidades do modelo) do centro do corpo à frente da pata da frente, no quadro da patada: o jogo usa para o alcance."""
    from mathutils import Vector
    pose(J_GLOBAL, ANDAR + IMPACTO)
    bpy.context.view_layer.update()
    o = bpy.data.objects["pata_fe"]
    cs = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return -min(c.y for c in cs) / ESCALA, min(c.z for c in cs) / ESCALA


def diag(J, cam=None):
    """Por quadro de andar: o ponto mais baixo de cada pata (z, ~0 no apoio e acima de 0 no balanço) e a posição no sentido do passo."""
    from mathutils import Vector
    J["raiz"].rotation_euler = (0, 0, 0)
    for q in range(ANDAR):
        pose(J, q)
        bpy.context.view_layer.update()
        linha = []
        for n in ("fe", "td", "fd", "te"):
            o = bpy.data.objects["pata_" + n]
            cs = [o.matrix_world @ Vector(c) for c in o.bound_box]
            linha.append("%s z=%.3f frente=%.3f" % (n, min(c.z for c in cs) / ESCALA, -sum(c.y for c in cs) / 8.0 / ESCALA))
        print("DIAG q=%d  %s   corpo_z=%.3f" % (q, "   ".join(linha), J["corpo"].location.z))
    for q in range(ANDAR, ANDAR + ATAQUE):
        pose(J, q)
        bpy.context.view_layer.update()
        linha = []
        for n in ("fe", "te"):
            o = bpy.data.objects["pata_" + n]
            cs = [o.matrix_world @ Vector(c) for c in o.bound_box]
            linha.append("%s z=%.3f y=%.3f" % (n, min(c.z for c in cs) / ESCALA, -min(c.y for c in cs) / ESCALA))
        print("DIAG ataque q=%d  %s" % (q - ANDAR, "   ".join(linha)))
    print("DIAG A=%.4f separacao=%.4f ciclo_px=%.2f" % (A, 2 * A, 4 * A * ESCALA * PPU))


def medir_apoio(J, cena, cam, W, H):
    """A pata de apoio (a frente-esquerda, quadros 2 a 6) como a câmera a vê, medida NOS PIXELS: com o resto do corpo escondido, renderiza só a pata em
    cada vista e pega o centro do contorno. Devolve (ciclo_linha, deslize, pes): `ciclo_linha[v]` = px que o corpo anda por ciclo de andar na vista v
    (2 x o deslocamento da pata de apoio entre os quadros 2 e 6); `deslize[v]` = o quanto a pata sai da reta (px); `pes[v]` = [x, y] nos quadros 2 a 6
    (x já espelhado, como na folha)."""
    raiz = J["raiz"]
    malhas = [o for o in bpy.data.objects if o.type == "MESH"]
    pe = bpy.data.objects["pata_fe"]
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
        pts = [(W - 1 - x, y) for x, y in pts]
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
        print("DIAG alcance_pata=%.3f z_baixo=%.3f" % pata_da_frente())
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
        print("URSO PREVIA", W, H, pe_x, pe_y)
        return
    alcance, z_baixo = pata_da_frente()
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
    print("URSO OK", W, H, pe_x, pe_y, "alcance_pata", info["alcance_pata_px"], "z_baixo", round(z_baixo, 3))


main()

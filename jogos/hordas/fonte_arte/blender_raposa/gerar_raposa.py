"""Espírito Raposa (aliado "espirito_raposa") em 3D procedural, 5 vistas, ANDAR (trote rápido) e ATAQUE (bote: agacha, salta e cai com as patas sobre o inimigo).

Mesmo esquema de câmera dos monstros v2, do Golem e do Urso: 45 graus, ortográfica, 24,5 px por unidade, vistas 0/45/90/135/180
(frente, 3/4 frente, lado, 3/4 costas, costas), o bicho olhando para a DIREITA (o jogo espelha para a esquerda).
Raposa laranja esguia, de patas escuras, orelhas grandes, olhos dourados e uma cauda longa e felpuda de ponta branca. O ar de espírito (surgir em
névoa, brilho, faíscas, dissolver) é feito em código, em v2/andante.gd, por cima desta folha.

Saída: projeto/assets/v2/armas/raposa_espiritual_dir.png, 16 colunas x 5 linhas de quadros do mesmo tamanho:
  colunas 0-7  = ciclo de ANDAR (trote: pares diagonais, 2 pisadas por ciclo nos quadros 2 e 6, patas afastadas; o 2 também é o "parado"),
  colunas 8-15 = ATAQUE (8 agacha, 9 se encolhe, 10 salta, 11 pico do salto com a boca aberta, 12 BOTE = impacto, as patas da frente no chão,
                 13 pousa, 14 e 15 volta). O corpo vai para a frente DENTRO do quadro (o bicho não anda durante o ataque): o salto está na folha.
  linhas       = frente, 3/4 frente, lado, 3/4 costas, costas.
O .json ao lado (e a cópia em assets/v2/armas/) guarda o tamanho do quadro, o pé, a passada medida NOS PIXELS por vista e o alcance do bote
(`alcance_pata_px`: até onde a pata da frente chega à frente do centro do corpo no impacto); o jogo (v2/andante.gd) copia os números na ficha.
Uso (Blender 4.5 LTS), em segundo plano:
    blender -b -P gerar_raposa.py                              # a folha final
    blender -b -P gerar_raposa.py -- previa <png> [a|t|todas]  # prévia (frente, 3/4 e perfil; a = só andar, t = só ataque)
    blender -b -P gerar_raposa.py -- diag                      # sem render: o chão e as patas em cada quadro
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
from pixel3d import caixa, cone, esfera  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIA = ARGS[1] if len(ARGS) >= 2 and ARGS[0] == "previa" else None
PARTE = ARGS[2] if len(ARGS) >= 3 else "todas"
DIAG = bool(ARGS) and ARGS[0] == "diag"
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "v2", "armas"))
NOME = "raposa_espiritual_dir"

ELEVACAO = 45.0
PPU = 24.5               # igual aos monstros v2, ao herói e ao Golem
ESCALA = 0.42            # escala geral do modelo (bem menor que o urso, que é 0,80)
VISTAS = (0.0, 45.0, 90.0, 135.0, 180.0)
ANDAR = 8
ATAQUE = 8
IMPACTO = 4
PARADO = 2
W0, H0 = 64, 64          # ponto de partida; o quadro cresce até caber
CONT = np.array([0x3a, 0x16, 0x0c]) / 255.0

FAIXAS = (0.35, 0.62, 1.0)
BASES = {
    "pelo": "ee7d2c", "pelo_e": "b9501c", "creme": "f8e3bd", "pata": "4a2a1c", "ponta": "fff2dc", "nariz": "1c1210",
}


def _srgb(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def _tons(hexa):
    lin = [px3.linear(int(hexa[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    return [[_srgb(c * f) for c in lin] for f in FAIXAS]


OLHO = "ffe070"
PAL = np.array([t for h in BASES.values() for t in _tons(h)] + [[int(OLHO[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]])

# medidas do esqueleto (em unidades do modelo, antes da ESCALA)
QUADRIL_Z = 1.29         # altura do quadril e do ombro (pernas compridas: a passada tem de ser grande para a vel 200 do aliado)
X_PERNA = 0.30
Y_FRENTE = -0.72         # ombros
Y_TRAS = 0.72            # quadris (e o pivô do tronco)
J_Z = 0.70               # joelho
T_Z = 0.14               # tornozelo (a pata tem 0,14 de altura)


def modelo():
    """A raposa em repouso (frente = -Y, chão = z 0). Devolve as juntas que a pose mexe."""
    T = px3.material_toon
    C = px3.cor
    mat = {
        "pelo": T("pelo", C(BASES["pelo"]), ruido=0.2, escala_ruido=12.0),
        "pelo_e": T("pelo_e", C(BASES["pelo_e"]), ruido=0.2, escala_ruido=10.0),
        "creme": T("creme", C(BASES["creme"]), ruido=0.15, escala_ruido=10.0),
        "pata": T("pata", C(BASES["pata"]), ruido=0.15, escala_ruido=10.0),
        "ponta": T("ponta", C(BASES["ponta"]), ruido=0.15, escala_ruido=10.0),
        "nariz": T("nariz", C(BASES["nariz"])),
        "olho": px3.material_emissao("olho", C(OLHO)),
    }
    raiz, corpo = raiz_corpo()
    J = {"raiz": raiz, "corpo": corpo}
    # pernas de trás (presas ao corpo: ficam no chão quando o tronco se inclina)
    for lado, x in (("e", X_PERNA), ("d", -X_PERNA)):
        _perna_modelo(J, mat, "t" + lado, x, Y_TRAS, corpo, grossa=1.1)
    # o tronco gira no quadril (pivô atrás): costas, ombros, cabeça, cauda e pernas da frente vão junto
    tronco = junta("tronco", (0, Y_TRAS, QUADRIL_Z), corpo)
    J["tronco"] = tronco
    esfera("lombo", 0.5, (0, 0.38, 1.55), mat["pelo"], tronco, escala=(0.88, 1.3, 0.82))
    esfera("peito", 0.5, (0, -0.5, 1.6), mat["pelo"], tronco, escala=(0.88, 1.15, 0.95))
    esfera("barriga", 0.4, (0, -0.1, 1.3), mat["creme"], tronco, escala=(0.7, 1.4, 0.5))
    esfera("papo", 0.28, (0, -0.95, 1.55), mat["creme"], tronco, escala=(0.8, 0.9, 0.9))
    # cauda longa e felpuda (pivô na base): sobe e termina numa ponta branca
    cauda = junta("cauda", (0, Y_TRAS + 0.25, 1.5), tronco)
    J["cauda"] = cauda
    for nome, pos, r, esc, m in (
        ("cauda1", (0, 1.25, 1.52), 0.22, (0.9, 1.3, 0.9), "pelo"),
        ("cauda2", (0, 1.75, 1.66), 0.32, (1.0, 1.45, 1.0), "pelo"),
        ("cauda3", (0, 2.3, 1.82), 0.34, (1.0, 1.4, 1.0), "pelo"),
        ("cauda_ponta", (0, 2.8, 1.96), 0.28, (0.95, 1.3, 0.95), "ponta"),
    ):
        esfera(nome, r, pos, mat[m], cauda, escala=esc)
    # cabeça (gira no pescoço): crânio, focinho comprido de ponta escura, orelhas grandes, olhos dourados
    cabeca = junta("cabeca", (0, -1.0, 1.7), tronco)
    J["cabeca"] = cabeca
    esfera("cranio", 0.34, (0, -1.3, 1.8), mat["pelo"], cabeca, escala=(0.95, 1.0, 0.9))
    esfera("focinho", 0.2, (0, -1.68, 1.7), mat["pelo"], cabeca, escala=(0.65, 1.5, 0.55))
    esfera("bochecha_e", 0.15, (0.2, -1.5, 1.66), mat["creme"], cabeca, escala=(0.6, 1.2, 0.8))
    esfera("bochecha_d", 0.15, (-0.2, -1.5, 1.66), mat["creme"], cabeca, escala=(0.6, 1.2, 0.8))
    esfera("nariz", 0.07, (0, -2.0, 1.72), mat["nariz"], cabeca)
    for x in (0.23, -0.23):
        cone("orelha", 0.17, 0.0, 0.62, (x, -1.12, 2.28), mat["pelo"], cabeca, vertices=4)
        cone("orelha_i", 0.1, 0.0, 0.4, (x, -1.17, 2.22), mat["pata"], cabeca, vertices=4)
        esfera("olho", 0.055, (x * 0.8, -1.6, 1.86), mat["olho"], cabeca)
    mandibula = junta("mandibula", (0, -1.45, 1.62), cabeca)
    J["mandibula"] = mandibula
    caixa("queixo", (0.2, 0.46, 0.08), (0, -1.74, 1.57), mat["creme"], mandibula, chanfro=0.02)
    # pernas da frente (presas ao tronco)
    for lado, x in (("e", X_PERNA), ("d", -X_PERNA)):
        _perna_modelo(J, mat, "f" + lado, x, Y_FRENTE, tronco, grossa=0.95)
    raiz.scale = (ESCALA, ESCALA, ESCALA)
    return J


def _perna_modelo(J, mat, n, x, y, pai, grossa):
    """Perna de duas partes (coxa laranja e canela escura, de meia) com pata plana: quadril -> joelho -> tornozelo, como as do Urso."""
    g = grossa
    quad = junta("quad_" + n, (x, y, QUADRIL_Z), pai)
    if n[0] == "t":
        esfera("anca_" + n, 0.3, (x * 1.2, y + 0.05, QUADRIL_Z + 0.1), mat["pelo"], quad, escala=(0.85, 1.1, 1.0))
    caixa("coxa_" + n, (0.3 * g, 0.36 * g, 0.62), (x, y, 1.0), mat["pelo"], quad, chanfro=0.07)
    joelho = junta("joe_" + n, (x, y, J_Z), quad)
    caixa("canela_" + n, (0.24 * g, 0.28 * g, 0.58), (x, y, 0.42), mat["pata"], joelho, chanfro=0.05)
    torn = junta("tor_" + n, (x, y, T_Z), joelho)
    caixa("pata_" + n, (0.28 * g, 0.5, 0.14), (x, y - 0.1, 0.07), mat["pata"], torn, chanfro=0.04)
    J["quad_" + n], J["joe_" + n], J["tor_" + n] = quad, joelho, torn


# poses ---------------------------------------------------------------------------------------------------------------------------
# Rotação em X: perna pendurada vai para a frente (-Y) com ângulo NEGATIVO; o tronco se inclina para a frente (focinho para baixo) com ângulo POSITIVO.
ATQ = (
    # (corpo para a frente (-y), z do corpo, tronco, braço no mundo, cotovelo, cabeça, boca, quadril de trás, joelho de trás, cauda)
    (0.00, -0.30, 0.15, -0.30, 0.60, 0.15, 0.00, 0.55, 0.90, 0.20),     # 8  agacha, cabeça baixa
    (0.15, -0.45, 0.20, -0.20, 0.90, 0.20, 0.00, 0.90, 1.15, 0.40),     # 9  se encolhe (as patas de trás juntas sob o corpo)
    (-0.50, 0.30, -0.35, -1.50, 0.00, -0.20, 0.25, -0.60, 0.20, 0.10),  # 10 salta: o focinho sobe, as patas de trás empurram
    (-1.00, 0.70, -0.10, -1.90, -0.10, 0.00, 0.50, -0.80, 0.10, 0.00),  # 11 pico do salto: as patas da frente à frente, boca aberta
    (-1.50, -0.05, 0.45, -0.90, 0.10, 0.30, 0.45, 0.20, 0.70, -0.25),   # 12 BOTE: cai sobre o inimigo, as patas da frente no chão
    (-1.35, -0.30, 0.35, -0.60, 0.30, 0.30, 0.20, 0.40, 0.90, -0.10),   # 13 pousa
    (-0.70, -0.15, 0.15, -0.40, 0.30, 0.10, 0.00, 0.30, 0.70, 0.10),    # 14 levanta
    (-0.15, -0.10, 0.05, -0.20, 0.00, 0.05, 0.00, 0.10, 0.30, 0.15),    # 15 volta ao repouso
)
PLANTA_F = (0, 1, 4, 5, 6, 7)   # quadros do ataque em que as patas da frente estão no chão
PLANTA_T = (0, 1, 4, 5, 6, 7)   # as de trás também (nos quadros 2 e 3 a raposa está no ar)
MEMBROS = (
    "quad_te", "quad_td", "joe_te", "joe_td", "tor_te", "tor_td", "quad_fe", "quad_fd", "joe_fe", "joe_fd", "tor_fe", "tor_fd",
    "tronco", "cabeca", "mandibula", "cauda",
)

# Andar (trote): o pé é posicionado: no apoio ele corre para trás em linha reta, em S/4 por quadro, e o corpo avança a velocidade constante,
# então o pé NÃO escorrega. Mesma conta do Urso; os pares diagonais (frente-esquerda com trás-direita) andam juntos, meio ciclo defasados.
L = QUADRIL_Z - T_Z                 # do quadril ao tornozelo (a perna esticada)
L2 = J_Z                            # do joelho ao chão (para a flexão do joelho)
TETA = 0.95              # ângulo máximo do quadril no apoio duplo (quadros 2 e 6)
A = L * math.sin(TETA)
LEVANTA = 0.42           # quanto a pata que balança sobe acima do chão no meio do passo
BALANCO_X = 0.04
ROLL = 0.04


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
    corpo.location = (0, 0, 0)
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
                teta -= 0.30 * math.sin(math.pi * e["psi"])
            J["quad_" + n].rotation_euler = (teta, 0, 0)
            J["quad_" + n].delta_location = (0, 0, sobe)
            J["joe_" + n].rotation_euler = (joelho, 0, 0)
            J["tor_" + n].rotation_euler = (-(teta + joelho), 0, 0)
        lado_ap = math.cos(f)
        corpo.location = (BALANCO_X * lado_ap, 0, z_corpo)
        tronco.rotation_euler = (0, -ROLL * lado_ap, 0.03 * math.sin(f))   # sem arfar o tronco: as patas da frente saem do chão se ele inclina
        J["cabeca"].rotation_euler = (0.10 + 0.05 * math.cos(2 * f), 0, -0.08 * math.sin(f))
        J["cauda"].rotation_euler = (0.25 + 0.12 * math.sin(2 * f), 0, 0.28 * math.sin(f))
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
    """Quadro k (0..7) do ataque. As patas que têm de estar no chão (PLANTA_F e PLANTA_T) são resolvidas por bisseção: o ângulo do braço (frente) e a
    flexão do joelho (trás) que levam a sola a z = 0, para a pata nunca afundar nem boiar. No salto (2 e 3) elas ficam soltas, no ar."""
    dy, z, lean, omb, cot, cab, boca, qt, jt, cau = ATQ[k]
    J["corpo"].location = (0, dy, z)
    J["tronco"].rotation_euler = (lean, 0, 0)
    J["cabeca"].rotation_euler = (cab, 0, 0)
    J["mandibula"].rotation_euler = (boca, 0, 0)
    J["cauda"].rotation_euler = (cau, 0, 0)

    def braco(v):
        for lado in ("e", "d"):
            J["quad_f" + lado].rotation_euler = (v - lean, 0, 0.04 if lado == "e" else -0.04)  # o ombro desfaz a inclinação do tronco
            J["joe_f" + lado].rotation_euler = (cot, 0, 0)
            J["tor_f" + lado].rotation_euler = (-(v + cot) if k in PLANTA_F else 0.35, 0, 0)

    def trás(v):
        for lado in ("e", "d"):
            J["quad_t" + lado].rotation_euler = (-qt, 0, 0)
            J["joe_t" + lado].rotation_euler = (v, 0, 0)
            J["tor_t" + lado].rotation_euler = (qt - v if k in PLANTA_T else 0.4, 0, 0)

    trás(jt)
    braco(omb)
    if k in PLANTA_F:
        SOL.setdefault(k, {})
        if "f" not in SOL[k]:
            SOL[k]["f"] = _resolver(braco, lambda: _min_z("pata_fe"), omb - 0.9, omb + 0.9)
        braco(SOL[k]["f"])
    if k in PLANTA_T:
        SOL.setdefault(k, {})
        if "t" not in SOL[k]:
            SOL[k]["t"] = _resolver(trás, lambda: _min_z("pata_te"), 0.0, 2.0)
        trás(SOL[k]["t"])


def pata_da_frente():
    """Distância (unidades do modelo) do centro do corpo à frente da pata da frente, no quadro do bote: o jogo usa para o alcance."""
    from mathutils import Vector
    J_GLOBAL["raiz"].rotation_euler = (0, 0, 0)  # depois do render a raiz fica girada na última vista (costas): mede de frente para -Y
    pose(J_GLOBAL, ANDAR + IMPACTO)
    bpy.context.view_layer.update()
    o = bpy.data.objects["pata_fe"]
    cs = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return -min(c.y for c in cs) / ESCALA, min(c.z for c in cs) / ESCALA


def diag(J, cam=None):
    """Por quadro: o ponto mais baixo de cada pata (z, ~0 no apoio e acima de 0 no balanço) e a posição no sentido do passo."""
    from mathutils import Vector
    J["raiz"].rotation_euler = (0, 0, 0)
    for q in range(ANDAR + ATAQUE):
        pose(J, q)
        bpy.context.view_layer.update()
        linha = []
        for n in ("fe", "td", "fd", "te"):
            o = bpy.data.objects["pata_" + n]
            cs = [o.matrix_world @ Vector(c) for c in o.bound_box]
            linha.append("%s z=%.3f frente=%.3f" % (n, min(c.z for c in cs) / ESCALA, -sum(c.y for c in cs) / 8.0 / ESCALA))
        print("DIAG q=%d  %s   corpo_z=%.3f" % (q, "   ".join(linha), J["corpo"].location.z))
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
        print("RAPOSA PREVIA", W, H, pe_x, pe_y)
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
    print("RAPOSA OK", W, H, pe_x, pe_y, "alcance_pata", info["alcance_pata_px"], "z_baixo", round(z_baixo, 3))


main()

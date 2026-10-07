"""Monstros do Pântano Pútrido (#64, região 2): 5 comuns + 1 elite + a guardiã das fases + o chefe da região.

Roda (Blender 4.5 LTS):
    blender -b -P pantano.py               # todos
    blender -b -P pantano.py -- afogado    # só um
Saída: ../../projeto/assets/gerado/inimigo_<nome>.png (N+1 colunas x 5 vistas: ciclo de andar + branco, veja monstros.py) e proj_<nome>.png.
Clima (#68): lama, névoa verde e afogados que não ficaram no fundo. Tons de lodo, pele inchada azulada, brilho de veneno.
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
        "lodo": T("lodo", C("566e55"), ruido=0.35, escala_ruido=7.0),        # lama verde
        "lodo_e": T("lodo_e", C("35473a"), ruido=0.3, escala_ruido=9.0),
        "barro": T("barro", C("6e4c32"), ruido=0.35, escala_ruido=8.0),      # lama marrom
        "verruga": T("verruga", C("466a2c")),
        "sapo": T("sapo", C("6a943d"), ruido=0.25, escala_ruido=10.0),       # pele de sapo
        "barriga": T("barriga", C("a89e86")),
        "sangue_s": T("sangue_s", C("7e2027"), ruido=0.2, escala_ruido=12.0),   # sanguessuga
        "afogado": T("afogado", C("6f8fc8"), ruido=0.3, escala_ruido=9.0),   # pele inchada azulada
        "afogado_e": T("afogado_e", C("3a5794")),
        "trapo": T("trapo", C("45405c"), ruido=0.3, escala_ruido=8.0),
        "alga": T("alga", C("2d4721")),
        "escama": T("escama", C("466a2c"), ruido=0.4, escala_ruido=14.0),    # jacaré (verde médio: lê no chão escuro)
        "fatuo": monstros.px3.material_emissao("fatuo", C("a6e070")),
        "fatuo_c": monstros.px3.material_emissao("fatuo_c", C("e4ffb0")),
        "coroa": T("coroa", C("c49a45")),
    })
    return m


# ------------------------------------------------------------------ modelos (frente = -Y, chão = z 0)

def sanguessuga(m):
    """Sanguessuga gigante: cinco gomos vermelho-escuros que ondulam, boca redonda cheia de dentinhos."""
    raiz, corpo = raiz_corpo()
    p = {"gomos": []}
    for i in range(5):
        r = 0.16 - i * 0.018
        g = esfera("gomo%d" % i, r, (0, -0.22 + i * 0.17, r), m["sangue_s"], corpo, escala=(1.0, 1.15, 0.8))
        p["gomos"].append(g)
    esfera("brilho", 0.05, (0.06, -0.24, 0.24), m["carne"], corpo)
    cilindro("boca", 0.1, 0.04, (0, -0.37, 0.14), m["negro"], corpo, rot=(math.pi / 2, 0, 0), vertices=10)
    for k in range(6):
        a = k * math.tau / 6
        espinho("dente%d" % k, (math.cos(a) * 0.08, -0.38, 0.14 + math.sin(a) * 0.08), (-math.cos(a), -0.4, -math.sin(a)), 0.05, 0.015, m["osso"], corpo)

    def pose(fase, q):
        for i, g in enumerate(p["gomos"]):
            g.location.z = (0.16 - i * 0.018) + 0.04 * math.sin(fase + i * 1.2)
    return raiz, corpo, p, pose


def sapo_podre(m):
    """Sapo podre: gordo, cheio de verrugas, olhos amarelos saltados, barriga clara. Anda aos pulos."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("corpo", 0.32, (0, 0.04, 0.34), m["sapo"], corpo, escala=(1.1, 1.0, 0.75))
    esfera("barriga", 0.27, (0, -0.06, 0.26), m["barriga"], corpo, escala=(1.0, 0.9, 0.6))
    for x in (0.14, -0.14):
        esfera("olho_base", 0.09, (x, -0.16, 0.58), m["sapo"], corpo)
        esfera("olho", 0.06, (x, -0.22, 0.62), m["olho_f"], corpo)
        caixa("pupila", (0.015, 0.02, 0.05), (x, -0.27, 0.62), m["negro"], corpo)
    caixa("boca", (0.42, 0.04, 0.03), (0, -0.28, 0.36), m["negro"], corpo)
    for i, (x, y, z) in enumerate(((0.2, 0.1, 0.56), (-0.18, 0.2, 0.54), (0.05, 0.25, 0.6), (0.25, -0.05, 0.44), (-0.26, 0.0, 0.42))):
        esfera("verruga%d" % i, 0.045, (x, y, z), m["verruga"], corpo)
    for x in (0.18, -0.18):
        nome = "frente_e" if x > 0 else "frente_d"
        p[nome] = braco(nome, 0.07, 0.07, 0.24, (x, -0.2, 0.24), m["sapo"], corpo)
    for x in (0.26, -0.26):
        nome = "tras_e" if x > 0 else "tras_d"
        j = junta(nome, (x, 0.2, 0.3), corpo)
        galho(nome + "_c", (x, 0.2, 0.3), (x * 1.5, 0.05, 0.16), 0.07, m["sapo"], j)
        galho(nome + "_p", (x * 1.5, 0.05, 0.16), (x * 1.3, 0.3, 0.02), 0.05, m["sapo"], j)
        p[nome] = j

    def pose(fase, q):
        pulo = 0.5 - 0.5 * math.cos(fase)   # 0 agachado (fase 0), 1 no ar (fase pi): o pulo sobe e desce suave pelo ciclo todo
        corpo.location = (0, 0, 0.18 * pulo)
        for nome in ("tras_e", "tras_d"):
            p[nome].rotation_euler = (-0.7 * pulo, 0, 0)
        for nome in ("frente_e", "frente_d"):
            p[nome].rotation_euler = (0.5 * pulo - 0.1 * (1.0 - pulo), 0, 0)
    return raiz, corpo, p, pose


def afogado(m):
    """Afogado: corpo inchado azulado, roupa em farrapos, alga pendurada, órbitas com brilho verde. Arrasta os pés."""
    raiz, corpo = raiz_corpo()
    p = {}
    for x in (0.12, -0.12):
        nome = "perna_e" if x > 0 else "perna_d"
        p[nome] = braco(nome, 0.14, 0.14, 0.62, (x, 0, 0.66), m["afogado_e"], corpo)
    caixa("tronco", (0.46, 0.3, 0.56), (0, 0, 1.0), m["afogado"], corpo, chanfro=0.08)
    esfera("barriga", 0.24, (0, -0.08, 0.92), m["afogado"], corpo, escala=(1, 0.8, 1))   # inchaço
    caixa("trapo", (0.5, 0.33, 0.3), (0, 0, 0.76), m["trapo"], corpo, chanfro=0.03)
    for i, x in enumerate((-0.18, -0.06, 0.06, 0.18)):
        espinho("rasgo%d" % i, (x, -0.02, 0.6), (x * 0.4, 0, -1), 0.14, 0.05, m["trapo"], corpo)
    esfera("cabeca", 0.2, (0, -0.04, 1.44), m["afogado"], corpo, escala=(1.0, 0.95, 1.05))
    for x in (0.075, -0.075):
        caixa("orbita", (0.08, 0.04, 0.07), (x, -0.22, 1.47), m["negro"], corpo)
        esfera("olho", 0.03, (x, -0.24, 1.47), m["olho_v"], corpo)
    caixa("boca", (0.12, 0.04, 0.05), (0, -0.22, 1.36), m["negro"], corpo)
    for i in range(5):   # alga pendurada na cabeça e nos ombros
        x = -0.22 + i * 0.11
        caixa("alga%d" % i, (0.03, 0.03, 0.34 - (i % 2) * 0.1), (x, -0.08 + (i % 2) * 0.1, 1.38 - (i % 2) * 0.1), m["alga"], corpo)
    for lado in (1, -1):
        nome = "braco_e" if lado > 0 else "braco_d"
        p[nome] = braco(nome, 0.11, 0.11, 0.56, (0.3 * lado, -0.02, 1.22), m["afogado"], corpo)
        p[nome].rotation_euler = (-1.2, 0, 0)

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.35 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.35 * s, 0, 0)
        p["braco_e"].rotation_euler = (-1.25 + 0.15 * s, 0, 0)   # braços pra frente, como quem tateia
        p["braco_d"].rotation_euler = (-1.25 - 0.15 * s, 0, 0)
        corpo.rotation_euler = (0, 0.08 * s, 0)
        corpo.location = (0, 0, 0.03 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def fogo_fatuo(m):
    """Fogo-fátuo: chama verde que flutua sobre o pântano, com dois olhos ocos e rabinho de fogo."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("nucleo", 0.17, (0, 0, 0.6), m["fatuo_c"], corpo)
    esfera("chama", 0.22, (0, 0.03, 0.62), m["fatuo"], corpo, escala=(1.0, 1.0, 1.2))
    for k in range(5):
        a = k * math.tau / 5
        espinho("lingua%d" % k, (math.cos(a) * 0.12, math.sin(a) * 0.12 + 0.04, 0.72), (math.cos(a) * 0.3, math.sin(a) * 0.3 + 0.2, 1), 0.24, 0.07, m["fatuo"], corpo)
    for k in range(3):
        espinho("rabo%d" % k, (0, 0.12 + k * 0.06, 0.52 - k * 0.04), ((k - 1) * 0.3, 1, -0.4), 0.26 - k * 0.05, 0.06, m["fatuo"], corpo)
    for x in (0.06, -0.06):
        esfera("olho", 0.035, (x, -0.2, 0.64), m["negro"], corpo)

    def pose(fase, q):
        s = math.sin(fase)
        corpo.location = (0, 0, 0.06 * s)
        corpo.scale = (1.0 + 0.06 * s, 1.0 + 0.06 * s, 1.0 - 0.06 * s)
    return raiz, corpo, p, pose


def jacare_lodo(m):
    """Jacaré de lodo: comprido, escamas com placas nas costas, sujo de lama, olhos amarelos acima do focinho."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("corpo", 0.26, (0, 0.1, 0.28), m["escama"], corpo, escala=(1.0, 2.2, 0.62))
    for i in range(7):
        espinho("placa%d" % i, (0, -0.32 + i * 0.13, 0.42 - abs(i - 3) * 0.015), (0, 0.3, 1), 0.12, 0.05, m["lodo_e"], corpo)
    caixa("cabeca", (0.28, 0.3, 0.16), (0, -0.48, 0.26), m["escama"], corpo, chanfro=0.04)
    caixa("focinho", (0.2, 0.42, 0.1), (0, -0.82, 0.22), m["escama"], corpo, chanfro=0.03)
    caixa("maxila", (0.18, 0.4, 0.05), (0, -0.82, 0.15), m["lodo_e"], corpo)
    for k in range(5):
        for x in (0.085, -0.085):
            espinho("dente", (x, -0.66 - k * 0.07, 0.17), (0, 0, -1), 0.04, 0.012, m["osso"], corpo)
    for x in (0.08, -0.08):
        esfera("olho_base", 0.05, (x, -0.42, 0.36), m["escama"], corpo)
        esfera("olho", 0.03, (x, -0.46, 0.38), m["olho_f"], corpo)
    for i in range(3):
        esfera("lama%d" % i, 0.1, ((i - 1) * 0.14, 0.1 + i * 0.1, 0.4), m["barro"], corpo, escala=(1, 1, 0.4))
    for nome, x, y in (("fe", 0.22, -0.28), ("fd", -0.22, -0.28), ("te", 0.22, 0.42), ("td", -0.22, 0.42)):
        j = junta("pata_" + nome, (x, y, 0.22), corpo)
        galho(nome + "_c", (x, y, 0.22), (x * 1.45, y - 0.04, 0.04), 0.06, m["escama"], j)
        p[nome] = j
    p["cauda"] = junta("cauda", (0, 0.55, 0.26), corpo)
    for k in range(4):
        galho("cauda%d" % k, (0, 0.55 + k * 0.22, 0.26 - k * 0.04), (0, 0.77 + k * 0.22, 0.22 - k * 0.04), 0.12 - k * 0.025, m["escama"], p["cauda"])
    corpo.scale = (1.3, 1.3, 1.3)   # grandão: é o inimigo pesado do pântano

    def pose(fase, q):
        s = math.sin(fase)
        p["fe"].rotation_euler = (0.6 * s, 0, 0)
        p["td"].rotation_euler = (0.6 * s, 0, 0)
        p["fd"].rotation_euler = (-0.6 * s, 0, 0)
        p["te"].rotation_euler = (-0.6 * s, 0, 0)
        p["cauda"].rotation_euler = (0, 0, 0.3 * s)
        corpo.rotation_euler = (0, 0, 0.06 * s)
    return raiz, corpo, p, pose


def golem_lodo(m):
    """Golem de lodo (elite): monte de lama que anda, ossos e uma caveira presos no barro, olhos verdes, gotas pingando."""
    raiz, corpo = raiz_corpo()
    p = {}
    for i, (x, y, z, r) in enumerate(((0, 0, 0.9, 0.55), (0.2, 0.1, 1.3, 0.42), (-0.25, 0.05, 1.25, 0.4), (0, -0.05, 1.55, 0.36))):
        esfera("massa%d" % i, r, (x, y, z), m["lodo"] if i % 2 == 0 else m["barro"], corpo, escala=(1, 0.9, 0.9))
    esfera("cranio", 0.15, (0.12, -0.36, 1.35), m["osso"], corpo)
    for x in (0.07, 0.17):
        esfera("orbita", 0.04, (x, -0.48, 1.38), m["negro"], corpo)
    for x in (-0.12, 0.0):
        esfera("olho", 0.05, (x, -0.42, 1.58), m["olho_v"], corpo)
    for i, (a, b) in enumerate((((-0.3, -0.3, 1.0), (-0.5, -0.5, 1.2)), ((0.35, -0.2, 0.8), (0.6, -0.4, 0.75)), ((-0.1, -0.4, 0.7), (-0.15, -0.65, 0.6)))):
        galho("osso%d" % i, a, b, 0.04, m["osso_e"], corpo)
    for lado in (1, -1):
        nome = "braco_e" if lado > 0 else "braco_d"
        j = junta(nome, (0.5 * lado, 0, 1.3), corpo)
        esfera(nome + "_o", 0.24, (0.62 * lado, -0.05, 1.15), m["lodo"], j)
        esfera(nome + "_m", 0.26, (0.7 * lado, -0.15, 0.7), m["barro"], j, escala=(1, 1, 1.2))
        p[nome] = j
    for x in (0.22, -0.22):
        nome = "perna_e" if x > 0 else "perna_d"
        p[nome] = braco(nome, 0.26, 0.26, 0.5, (x, 0, 0.5), m["lodo_e"], corpo)
    for k in range(4):
        esfera("gota%d" % k, 0.04, (math.cos(k) * 0.4, -0.2 - math.sin(k) * 0.2, 0.55 - k * 0.1), m["lodo"], corpo)

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.4 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.4 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.3 * s, 0, 0)
        p["braco_d"].rotation_euler = (0.3 * s, 0, 0)
        corpo.location = (0, 0, 0.04 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def rainha_sapo(m):
    """Rainha Sapo (guardiã das fases): sapo enorme de coroa de ouro velho e capa de musgo, papo amarelado inflado."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("corpo", 0.6, (0, 0.06, 0.62), m["sapo"], corpo, escala=(1.15, 1.0, 0.8))
    esfera("papo", 0.38, (0, -0.32, 0.5), m["barriga"], corpo, escala=(1.0, 0.8, 0.85))
    esfera("capa", 0.55, (0, 0.28, 0.78), m["lodo_e"], corpo, escala=(1.2, 0.8, 0.7))
    for i, (x, y, z) in enumerate(((0.35, 0.0, 1.0), (-0.32, 0.1, 0.98), (0.1, 0.2, 1.1), (0.45, -0.2, 0.75), (-0.48, -0.15, 0.72), (0.2, -0.05, 1.08))):
        esfera("verruga%d" % i, 0.06, (x, y, z), m["verruga"], corpo)
    for x in (0.24, -0.24):
        esfera("olho_base", 0.15, (x, -0.24, 1.08), m["sapo"], corpo)
        esfera("olho", 0.1, (x, -0.32, 1.12), m["olho_f"], corpo)
        caixa("pupila", (0.025, 0.03, 0.09), (x, -0.41, 1.12), m["negro"], corpo)
    caixa("boca", (0.7, 0.05, 0.04), (0, -0.55, 0.78), m["negro"], corpo)
    cilindro("coroa", 0.2, 0.12, (0, -0.02, 1.32), m["coroa"], corpo, vertices=8)
    for k in range(5):
        a = k * math.tau / 5
        espinho("ponta%d" % k, (math.cos(a) * 0.18, -0.02 + math.sin(a) * 0.18, 1.38), (0, 0, 1), 0.14, 0.04, m["coroa"], corpo)
    esfera("joia", 0.04, (0, -0.22, 1.33), m["olho_r"], corpo)
    for x in (0.38, -0.38):
        nome = "frente_e" if x > 0 else "frente_d"
        p[nome] = braco(nome, 0.12, 0.12, 0.42, (x, -0.35, 0.42), m["sapo"], corpo)
    for x in (0.55, -0.55):
        nome = "tras_e" if x > 0 else "tras_d"
        j = junta(nome, (x, 0.3, 0.5), corpo)
        galho(nome + "_c", (x, 0.3, 0.5), (x * 1.45, 0.1, 0.25), 0.13, m["sapo"], j)
        galho(nome + "_p", (x * 1.45, 0.1, 0.25), (x * 1.3, 0.45, 0.03), 0.09, m["sapo"], j)
        p[nome] = j

    def pose(fase, q):
        pulo = 0.5 - 0.5 * math.cos(fase)   # 0 agachado (fase 0), 1 no ar (fase pi): o pulo sobe e desce suave pelo ciclo todo
        corpo.location = (0, 0, 0.14 * pulo)
        corpo.scale = (1.0, 1.0, 0.96 + 0.10 * pulo)   # papo inflando
        for nome in ("tras_e", "tras_d"):
            p[nome].rotation_euler = (-0.5 * pulo, 0, 0)
    return raiz, corpo, p, pose


def mae_do_lodo(m):
    """Mãe do Lodo (chefe do Pântano): uma massa de lama que sobe de uma poça, cheia de olhos verdes, boca de dentes de
    osso, quatro braços de lodo e uma coroa de juncos e ossos. Alga pendurada por todo lado."""
    raiz, corpo = raiz_corpo()
    p = {}
    cilindro("poca", 1.25, 0.12, (0, 0, 0.06), m["lodo_e"], corpo, vertices=16)
    for i, (z, r) in enumerate(((0.6, 0.95), (1.3, 0.8), (1.95, 0.66), (2.5, 0.5))):
        esfera("massa%d" % i, r, (0.05 * math.sin(i), 0, z), m["lodo"] if i % 2 == 0 else m["barro"], corpo, escala=(1, 0.9, 0.85))
    for i, (x, z, r) in enumerate(((0.28, 2.15, 0.09), (-0.3, 2.2, 0.08), (0.0, 2.45, 0.1), (0.45, 1.7, 0.07), (-0.48, 1.65, 0.07), (0.12, 1.85, 0.06))):
        caixa("orbita%d" % i, (r * 2.2, 0.08, r * 1.8), (x, -0.5 - 0.1 * (z > 2.0), z), m["negro"], corpo)
        esfera("olho%d" % i, r, (x, -0.55 - 0.1 * (z > 2.0), z), m["olho_v"], corpo)
    caixa("boca", (0.6, 0.1, 0.24), (0, -0.82, 1.3), m["negro"], corpo)
    for k in range(6):
        espinho("dente%d" % k, ((k - 2.5) * 0.1, -0.86, 1.43), (0, -0.2, -1), 0.14, 0.035, m["osso"], corpo)
    for k in range(7):
        a = -0.5 + k * 0.16
        espinho("junco%d" % k, (math.sin(a) * 0.35, 0.05, 2.85), (math.sin(a) * 0.6, 0.1, 1), 0.5 + (k % 2) * 0.2, 0.035, m["alga"], corpo)
    for k in range(3):
        esfera("cranio%d" % k, 0.11, ((k - 1) * 0.28, -0.25, 2.8), m["osso"], corpo)
    for i, (lado, z) in enumerate(((1, 1.9), (-1, 1.9), (1, 1.2), (-1, 1.2))):
        nome = "tent%d" % i
        j = junta(nome, (0.6 * lado, 0, z), corpo)
        pts = [(0.6 * lado, 0, z), (1.1 * lado, -0.3, z + 0.2), (1.5 * lado, -0.6, z - 0.1), (1.7 * lado, -0.95, z - 0.5)]
        for k in range(3):
            galho("%s_%d" % (nome, k), pts[k], pts[k + 1], 0.2 - k * 0.05, m["lodo"], j)
        esfera(nome + "_mao", 0.13, pts[3], m["barro"], j)
        p[nome] = j
    for k in range(8):
        a = k * math.tau / 8
        caixa("alga%d" % k, (0.05, 0.05, 0.5), (math.cos(a) * 0.82, math.sin(a) * 0.72, 1.55), m["alga"], corpo)

    def pose(fase, q):
        s = math.sin(fase)
        for i in range(4):
            p["tent%d" % i].rotation_euler = (0.2 * s * (1 if i % 2 == 0 else -1), 0.15 * s, 0)
        corpo.scale = (1.0 + 0.03 * s, 1.0 + 0.03 * s, 1.0 - 0.03 * s)   # respira
    return raiz, corpo, p, pose


# nome: (modelo, largura, altura, giro (não usado), rampas da paleta)
INIMIGOS = {
    "sanguessuga": (sanguessuga, 26, 22, 0.0, ("sangue", "osso", "pele")),
    "sapo_podre": (sapo_podre, 40, 34, 0.0, ("folha", "musgo", "osso", "fogo")),
    "afogado": (afogado, 40, 56, 0.0, ("noite", "aco", "folha", "veneno")),
    "fogo_fatuo": (fogo_fatuo, 32, 36, 0.0, ("veneno", "noite")),
    "jacare_lodo": (jacare_lodo, 66, 34, 0.0, ("musgo", "folha", "couro", "osso", "fogo")),
    "golem_lodo": (golem_lodo, 62, 66, 0.0, ("musgo", "couro", "osso", "veneno")),
    "rainha_sapo": (rainha_sapo, 70, 62, 0.0, ("folha", "musgo", "osso", "fogo", "ouro")),
    "mae_do_lodo": (mae_do_lodo, 124, 136, 0.0, ("musgo", "couro", "folha", "veneno", "osso")),
}

monstros.rodar(INIMIGOS, mats, projeteis=(
    ("bolha_veneno", 10, ["1d4a2a", "2f7a3a", "56b04a", "a6e070", "e4ffb0"]),
    ("chama_fatuo", 9, ["2f7a3a", "56b04a", "a6e070", "e4ffb0"]),
    ("lodo", 11, ["2b1d18", "4a3324", "566e55", "6e4c32"]),
), rotulo="PANTANO")

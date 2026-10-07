"""Monstros do Pico Congelado (#64, região 4): 5 comuns + 1 elite + o guardião das fases + o chefe da região.

Roda (Blender 4.5 LTS):
    blender -b -P gelo.py                # todos
    blender -b -P gelo.py -- urso_gelo   # só um
Saída: ../../projeto/assets/gerado/inimigo_<nome>.png (N+1 colunas x 5 vistas: ciclo de andar + branco, veja monstros.py) e proj_<nome>.png.
Clima (#68): vento que corta, gelo que não derrete e gigantes enterrados. O chão é CLARO (neve), como no deserto: os
corpos são escuros (pele azul-noite, aço, pelo pardo, pedra) e o gelo claro fica nos detalhes (chifres, barba, placas).
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
        "gelo": T("gelo", C("b8d8ec"), ruido=0.2, escala_ruido=10.0),        # gelo claro dos detalhes
        "gelo_e": T("gelo_e", C("4a6a88"), ruido=0.25, escala_ruido=8.0),    # cristal fundo
        "neve": T("neve", C("e8f6ff")),
        "pele_az": T("pele_az", C("2a3d52"), ruido=0.2, escala_ruido=7.0),   # diabrete: azul-noite
        "pele_az_c": T("pele_az_c", C("4a6a88")),
        "pelo": T("pelo", C("4a3324"), ruido=0.35, escala_ruido=12.0),      # urso pardo
        "troll": T("troll", C("5a6878"), ruido=0.25, escala_ruido=6.0),     # pele azul-acinzentada
        "capa": T("capa", C("6e4c32"), ruido=0.3, escala_ruido=9.0),        # couro e pele de bicho
        "pedra_g": T("pedra_g", C("3a3430"), ruido=0.3, escala_ruido=6.0),   # corpo do gigante
        "olho_c": monstros.px3.material_emissao("olho_c", C("e8f6ff")),      # olhos de geada
        "raio": monstros.px3.material_emissao("raio", C("fff2b0")),          # raios da coroa do gigante
    })
    return m


def cristal(nome, a, b, r, mat, pai):
    """Prisma de 6 faces de a até b, com ponta: um cristal de gelo."""
    from mathutils import Vector
    va, vb = Vector(a), Vector(b)
    meio = va + (vb - va) * 0.75
    galho(nome, a, tuple(meio), r, mat, pai, vertices=6)
    espinho(nome + "_ponta", tuple(meio), tuple((vb - va).normalized()), (vb - va).length * 0.25, r, mat, pai)


# ------------------------------------------------------------------ modelos (frente = -Y, chão = z 0)

def diabrete_gelo(m):
    """Diabrete de gelo: diabinho de pele azul-noite, chifres de pingente, orelhas pontudas, rabo fino e olhos de geada."""
    raiz, corpo = raiz_corpo()
    p = {}
    for x in (0.08, -0.08):
        nome = "perna_e" if x > 0 else "perna_d"
        p[nome] = braco(nome, 0.07, 0.07, 0.3, (x, 0, 0.32), m["pele_az"], corpo)
    esfera("tronco", 0.17, (0, 0, 0.47), m["pele_az"], corpo, escala=(1.0, 0.85, 1.1))
    esfera("barriga", 0.1, (0, -0.1, 0.44), m["pele_az_c"], corpo)
    esfera("cabeca", 0.17, (0, -0.04, 0.74), m["pele_az"], corpo, escala=(1.1, 1.0, 0.95))
    for x in (0.06, -0.06):
        esfera("olho", 0.035, (x, -0.19, 0.76), m["olho_c"], corpo)
    caixa("boca", (0.1, 0.03, 0.03), (0, -0.19, 0.66), m["negro"], corpo)
    espinho("rabo", (0, 0.14, 0.4), (0, 1, 0.4), 0.32, 0.03, m["pele_az"], corpo)
    for lado in (1, -1):
        espinho("chifre", (0.09 * lado, -0.02, 0.86), (0.35 * lado, 0.1, 1), 0.24, 0.045, m["gelo"], corpo)
        espinho("orelha", (0.17 * lado, 0.0, 0.76), (1 * lado, 0.2, 0.35), 0.15, 0.04, m["pele_az"], corpo)
        nome = "braco_e" if lado > 0 else "braco_d"
        p[nome] = braco(nome, 0.06, 0.06, 0.28, (0.19 * lado, -0.02, 0.6), m["pele_az"], corpo)
        espinho(nome + "_garra", (0.19 * lado, -0.03, 0.33), (0, -0.5, -1), 0.09, 0.03, m["gelo"], p[nome])

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.5 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.5 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.6 - 0.4 * s, 0, 0)   # garras pra frente, correndo
        p["braco_d"].rotation_euler = (-0.6 + 0.4 * s, 0, 0)
        corpo.location = (0, 0, 0.04 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def espirito_nevasca(m):
    """Espírito da nevasca: redemoinho de flocos em volta de um rosto de gelo escuro (lê na neve), olhos de geada e um rabo
    de vento. Flutua e atira estilhaços."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("rosto", 0.2, (0, 0, 0.78), m["gelo_e"], corpo, escala=(1.0, 0.9, 1.1))
    for x in (0.07, -0.07):
        esfera("olho", 0.04, (x, -0.17, 0.82), m["olho_c"], corpo)
    caixa("boca", (0.09, 0.03, 0.06), (0, -0.18, 0.7), m["negro"], corpo)
    j = junta("redemoinho", (0, 0, 0.78), corpo)
    for k in range(12):
        a = k * math.tau / 12
        esfera("floco%d" % k, 0.075 - (k % 3) * 0.015, (math.cos(a) * 0.34, math.sin(a) * 0.34, 0.78 + math.sin(a * 2) * 0.14), m["neve"], j)
    p["redemoinho"] = j
    espinho("rabo", (0, 0.02, 0.62), (0, 0.4, -1), 0.45, 0.12, m["gelo"], corpo)

    def pose(fase, q):
        p["redemoinho"].rotation_euler = (0, 0, fase * 0.35)   # os flocos giram (0,35 rad: o desenho não se repete)
        corpo.location = (0, 0, 0.06 * math.sin(fase))
    return raiz, corpo, p, pose


def guerreiro_congelado(m):
    """Guerreiro congelado: morto-vivo de armadura escura com neve nos ombros, elmo de chifres, barba de pingentes e machado
    de lâmina de gelo; olhos de geada."""
    raiz, corpo = raiz_corpo()
    p = {}
    for x in (0.11, -0.11):
        nome = "perna_e" if x > 0 else "perna_d"
        p[nome] = braco(nome, 0.13, 0.14, 0.66, (x, 0, 0.7), m["aco_e"], corpo)
        caixa(nome + "_bota", (0.15, 0.2, 0.12), (x, -0.03, 0.08), m["capa"], p[nome])
    caixa("saia", (0.42, 0.28, 0.26), (0, 0, 0.72), m["capa"], corpo, chanfro=0.03)
    caixa("tronco", (0.46, 0.3, 0.52), (0, 0, 1.1), m["aco"], corpo, chanfro=0.06)
    caixa("cinto", (0.48, 0.32, 0.06), (0, 0, 0.86), m["capa"], corpo)
    for lado in (1, -1):
        esfera("ombro", 0.15, (0.27 * lado, 0, 1.32), m["aco_e"], corpo, escala=(1.1, 1, 0.8))
        esfera("neve_ombro", 0.1, (0.28 * lado, 0.02, 1.4), m["neve"], corpo, escala=(1.2, 1, 0.5))
        espinho("chifre", (0.15 * lado, 0, 1.62), (1 * lado, 0, 0.8), 0.22, 0.045, m["osso"], corpo)
    esfera("elmo", 0.17, (0, 0, 1.55), m["aco"], corpo)
    caixa("viseira", (0.22, 0.04, 0.06), (0, -0.16, 1.54), m["negro"], corpo)
    for x in (0.05, -0.05):
        esfera("olho", 0.025, (x, -0.18, 1.54), m["olho_c"], corpo)
    for k in range(5):
        espinho("barba%d" % k, ((k - 2) * 0.045, -0.15, 1.46), (0, -0.15, -1), 0.16 + (k % 2) * 0.06, 0.03, m["gelo"], corpo)
    p["braco_e"] = braco("braco_e", 0.1, 0.1, 0.52, (0.29, 0, 1.3), m["aco_e"], corpo)
    p["braco_d"] = braco("braco_d", 0.1, 0.1, 0.52, (-0.29, 0, 1.3), m["aco_e"], corpo)
    galho("cabo", (-0.29, 0.12, 0.66), (-0.29, -0.35, 0.92), 0.025, m["capa"], p["braco_d"])
    caixa("lamina", (0.04, 0.16, 0.24), (-0.29, -0.37, 0.95), m["gelo"], p["braco_d"], chanfro=0.02)

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.4 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.4 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.35 * s, 0, 0)
        p["braco_d"].rotation_euler = (-0.5 + 0.3 * s, 0, 0)
        corpo.location = (0, 0, 0.03 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def urso_gelo(m):
    """Urso pardo congelado: enorme, pelo escuro com placas de gelo nas costas, geada na testa e olhos de geada. Investida."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("corpo", 0.5, (0, 0.15, 0.72), m["pelo"], corpo, escala=(0.85, 1.35, 0.8))
    esfera("ombros", 0.42, (0, -0.4, 0.8), m["pelo"], corpo, escala=(0.95, 0.9, 0.9))   # corcova
    esfera("cabeca", 0.26, (0, -0.85, 0.75), m["pelo"], corpo, escala=(0.9, 1.0, 0.85))
    esfera("focinho", 0.13, (0, -1.08, 0.68), m["capa"], corpo, escala=(0.9, 1.1, 0.8))
    esfera("nariz", 0.05, (0, -1.21, 0.71), m["negro"], corpo)
    esfera("geada", 0.12, (0, -0.98, 0.84), m["neve"], corpo, escala=(1.3, 0.6, 0.4))
    for x in (0.1, -0.1):
        esfera("olho", 0.035, (x, -1.03, 0.8), m["olho_c"], corpo)
        esfera("orelha", 0.07, (x * 1.6, -0.8, 0.98), m["pelo"], corpo)
    for k in range(5):   # placas de gelo nas costas
        espinho("placa%d" % k, (0, -0.45 + k * 0.25, 1.08 - abs(k - 2) * 0.06), (0, 0.25, 1), 0.3 - abs(k - 2) * 0.05, 0.09, m["gelo"], corpo)
    for x, y, nome in ((0.3, -0.55, "pata_fe"), (-0.3, -0.55, "pata_fd"), (0.3, 0.6, "pata_te"), (-0.3, 0.6, "pata_td")):
        p[nome] = braco(nome, 0.2, 0.22, 0.55, (x, y, 0.58), m["pelo"], corpo)
        caixa(nome + "_garra", (0.2, 0.08, 0.05), (x, y - 0.12, 0.04), m["osso"], p[nome])

    def pose(fase, q):
        s = math.sin(fase)
        for nome, k in (("pata_fe", 1), ("pata_td", 1), ("pata_fd", -1), ("pata_te", -1)):
            p[nome].rotation_euler = (0.45 * s * k, 0, 0)
        corpo.location = (0, 0, 0.04 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def sentinela_cristal(m):
    """Sentinela de cristal: gente feita de cristais de gelo, com um núcleo escuro no peito e um olho só. Lenta e dura."""
    raiz, corpo = raiz_corpo()
    p = {}
    for x in (0.14, -0.14):
        nome = "perna_e" if x > 0 else "perna_d"
        j = junta(nome, (x, 0, 0.8), corpo)
        galho(nome + "_c", (x, 0, 0.8), (x, -0.02, 0.02), 0.12, m["gelo_e"], j, vertices=6)
        p[nome] = j
    for k, (a, b, r) in enumerate((((0, 0, 0.75), (0, 0, 1.75), 0.24), ((0.18, 0.06, 0.8), (0.34, 0.12, 1.6), 0.13),
                                   ((-0.18, 0.06, 0.8), (-0.32, 0.14, 1.55), 0.13), ((0.02, 0.18, 0.85), (0.06, 0.34, 1.85), 0.12))):
        cristal("corpo%d" % k, a, b, r, m["gelo"] if k % 2 else m["gelo_e"], corpo)
    esfera("nucleo", 0.11, (0, -0.2, 1.12), m["negro"], corpo)
    esfera("olho", 0.055, (0, -0.21, 1.48), m["olho_c"], corpo)
    for lado in (1, -1):
        nome = "braco_e" if lado > 0 else "braco_d"
        j = junta(nome, (0.32 * lado, 0, 1.4), corpo)
        galho(nome + "_b", (0.32 * lado, 0, 1.4), (0.42 * lado, -0.05, 0.85), 0.09, m["gelo_e"], j, vertices=6)
        for k in range(3):
            espinho(nome + "_c%d" % k, (0.42 * lado, -0.05, 0.85), ((k - 1) * 0.5, -0.3, -1), 0.25, 0.07, m["gelo"], j)
        p[nome] = j

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.25 * s, 0, 0)   # passo duro, de pedra
        p["perna_d"].rotation_euler = (-0.25 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.2 * s, 0, 0)
        p["braco_d"].rotation_euler = (0.2 * s, 0, 0)
        corpo.location = (0, 0, 0.02 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def troll_gelo(m):
    """Troll do gelo (elite): corcunda e enorme, pele azul-acinzentada, sobrancelhas e barba de geada, presas e um porrete
    de tronco congelado cheio de pingentes."""
    raiz, corpo = raiz_corpo()
    p = {}
    for x in (0.22, -0.22):
        nome = "perna_e" if x > 0 else "perna_d"
        p[nome] = braco(nome, 0.24, 0.26, 0.7, (x, 0.05, 0.72), m["troll"], corpo)
    caixa("tanga", (0.6, 0.4, 0.3), (0, 0.05, 0.75), m["capa"], corpo, chanfro=0.05)
    esfera("barriga", 0.48, (0, -0.05, 1.15), m["troll"], corpo, escala=(1.0, 0.85, 0.9))
    esfera("costas", 0.5, (0, 0.18, 1.55), m["troll"], corpo, escala=(1.1, 0.9, 0.8))   # corcunda
    esfera("cabeca", 0.22, (0, -0.35, 1.72), m["troll"], corpo, escala=(1.0, 1.0, 0.9))  # cabeça baixa, pra frente
    caixa("sobrancelha", (0.3, 0.08, 0.06), (0, -0.53, 1.8), m["neve"], corpo)
    for x in (0.08, -0.08):
        esfera("olho", 0.035, (x, -0.55, 1.74), m["olho_c"], corpo)
        espinho("presa", (x, -0.52, 1.6), (x * 2, -0.2, 1), 0.12, 0.035, m["osso"], corpo)
    for k in range(5):
        espinho("barba%d" % k, ((k - 2) * 0.06, -0.48, 1.58), (0, -0.2, -1), 0.2 + (k % 2) * 0.08, 0.04, m["neve"], corpo)
    for k in range(4):
        espinho("pingente%d" % k, ((k - 1.5) * 0.18, 0.45, 1.75), (0, 0.4, 1), 0.2, 0.06, m["gelo"], corpo)
    for lado in (1, -1):
        nome = "braco_e" if lado > 0 else "braco_d"
        p[nome] = braco(nome, 0.18, 0.2, 0.95, (0.55 * lado, -0.05, 1.6), m["troll"], corpo)   # braços compridos
    galho("porrete", (-0.55, -0.05, 0.62), (-0.6, -0.65, 0.45), 0.13, m["capa"], p["braco_d"])
    for k in range(4):
        espinho("gelo_p%d" % k, (-0.6, -0.4 - k * 0.07, 0.5 + (k % 2) * 0.08), ((-1) ** k * 0.6, -0.2, 0.7), 0.18, 0.05, m["gelo"], p["braco_d"])
    corpo.scale = (1.25, 1.25, 1.25)   # elite: bem maior que os comuns

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.3 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.3 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.3 * s, 0, 0)
        p["braco_d"].rotation_euler = (-0.3 + 0.25 * s, 0, 0)
        corpo.location = (0, 0, 0.04 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def jarl_congelado(m):
    """O Jarl Congelado (guardião das fases): rei morto-vivo de armadura escura e capa de pele, coroa de ferro com
    pingentes, barba de gelo e espada larga de gelo."""
    raiz, corpo = raiz_corpo()
    p = {}
    for x in (0.13, -0.13):
        nome = "perna_e" if x > 0 else "perna_d"
        p[nome] = braco(nome, 0.15, 0.16, 0.8, (x, 0, 0.84), m["aco_e"], corpo)
    caixa("capa", (0.66, 0.08, 1.35), (0, 0.26, 1.0), m["capa"], corpo, rot=(-0.12, 0, 0), chanfro=0.03)   # atrás: a armadura aparece de frente
    caixa("saia", (0.52, 0.34, 0.36), (0, 0, 0.85), m["aco"], corpo, chanfro=0.04)
    caixa("tronco", (0.56, 0.36, 0.62), (0, 0, 1.34), m["aco"], corpo, chanfro=0.07)
    esfera("gola", 0.3, (0, 0.05, 1.68), m["neve"], corpo, escala=(1.25, 0.9, 0.45))   # gola de pele branca
    esfera("cabeca", 0.17, (0, -0.03, 1.86), m["troll"], corpo)
    for x in (0.06, -0.06):
        esfera("olho", 0.03, (x, -0.18, 1.88), m["olho_c"], corpo)
    for k in range(6):
        espinho("barba%d" % k, ((k - 2.5) * 0.045, -0.15, 1.78), (0, -0.25, -1), 0.24 + (k % 2) * 0.08, 0.035, m["gelo"], corpo)
    cilindro("coroa", 0.18, 0.1, (0, -0.02, 2.02), m["aco_e"], corpo, vertices=10)
    for k in range(6):
        a = k * math.tau / 6
        espinho("ponta%d" % k, (math.cos(a) * 0.17, -0.02 + math.sin(a) * 0.17, 2.06), (0, 0, 1), 0.14, 0.035, m["gelo"], corpo)
    for lado in (1, -1):
        esfera("ombreira", 0.17, (0.33 * lado, 0, 1.6), m["aco_e"], corpo, escala=(1.1, 1, 0.8))
        nome = "braco_e" if lado > 0 else "braco_d"
        p[nome] = braco(nome, 0.12, 0.12, 0.62, (0.36 * lado, 0, 1.56), m["aco_e"], corpo)
    galho("punho", (-0.36, 0.08, 0.94), (-0.36, -0.12, 0.94), 0.03, m["capa"], p["braco_d"])
    caixa("guarda", (0.26, 0.05, 0.05), (-0.36, -0.13, 0.94), m["aco_e"], p["braco_d"])
    galho("lamina", (-0.36, -0.14, 0.94), (-0.36, -1.0, 1.0), 0.06, m["gelo"], p["braco_d"], vertices=4)
    corpo.scale = (1.15, 1.15, 1.15)   # guardião: maior que os guerreiros dele

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.3 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.3 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.3 * s, 0, 0)
        p["braco_d"].rotation_euler = (-0.4 + 0.2 * s, 0, 0)   # espada erguida pra frente
        corpo.location = (0, 0, 0.03 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def gigante_tempestade(m):
    """O Gigante da Tempestade (chefe do Pico): gigante que dormia enterrado no gelo. Corpo de pedra escura com placas de
    gelo, canelas ainda presas no gelo, barba de pingentes, coroa de nuvem com raios e um martelo de gelo."""
    raiz, corpo = raiz_corpo()
    p = {}
    for x in (0.42, -0.42):
        nome = "perna_e" if x > 0 else "perna_d"
        p[nome] = braco(nome, 0.42, 0.46, 1.5, (x, 0.05, 1.55), m["pedra_g"], corpo)
        caixa(nome + "_gelo", (0.5, 0.54, 0.34), (x, 0.05, 0.22), m["gelo"], p[nome], chanfro=0.05)
    caixa("cinto", (1.2, 0.7, 0.3), (0, 0.05, 1.6), m["capa"], corpo, chanfro=0.06)
    esfera("tronco", 0.85, (0, 0.05, 2.55), m["pedra_g"], corpo, escala=(1.05, 0.75, 1.05))
    for i, (x, z) in enumerate(((0.35, 2.75), (-0.4, 2.35), (0.1, 2.15))):
        caixa("placa%d" % i, (0.32, 0.12, 0.36), (x, -0.6, z), m["gelo"], corpo, rot=(0.15, 0, 0.3 * (i - 1)), chanfro=0.04)
    esfera("cabeca", 0.38, (0, -0.15, 3.6), m["pedra_g"], corpo, escala=(0.95, 0.95, 1.05))
    for x in (0.14, -0.14):
        esfera("olho", 0.06, (x, -0.5, 3.66), m["olho_c"], corpo)
    caixa("sobrancelha", (0.5, 0.1, 0.08), (0, -0.48, 3.78), m["gelo"], corpo)
    for k in range(7):
        espinho("barba%d" % k, ((k - 3) * 0.09, -0.4, 3.42), (0, -0.25, -1), 0.45 + (k % 2) * 0.18, 0.06, m["gelo"], corpo)
    for k in range(6):   # coroa de nuvem de tempestade
        a = k * math.tau / 6
        esfera("nuvem%d" % k, 0.2, (math.cos(a) * 0.32, -0.15 + math.sin(a) * 0.28, 4.02), m["aco"], corpo, escala=(1.2, 1.2, 0.7))
    for k in range(3):
        a = k * math.tau / 3 + 0.4
        espinho("raio%d" % k, (math.cos(a) * 0.3, -0.15 + math.sin(a) * 0.25, 4.1), (math.cos(a) * 0.4, math.sin(a) * 0.4, 1), 0.4, 0.05, m["raio"], corpo)
    for lado in (1, -1):
        esfera("ombro", 0.42, (0.95 * lado, 0.05, 3.15), m["pedra_g"], corpo, escala=(1, 1, 0.85))
        espinho("pico_ombro", (0.95 * lado, 0.05, 3.45), (0.3 * lado, 0, 1), 0.4, 0.12, m["gelo"], corpo)
        nome = "braco_e" if lado > 0 else "braco_d"
        p[nome] = braco(nome, 0.34, 0.36, 1.6, (1.05 * lado, 0.0, 3.1), m["pedra_g"], corpo)
    galho("cabo", (-1.05, 0.45, 1.45), (-1.05, -1.0, 1.75), 0.08, m["capa"], p["braco_d"])
    caixa("martelo", (0.55, 0.5, 0.45), (-1.05, -1.05, 1.75), m["gelo"], p["braco_d"], chanfro=0.06)
    corpo.scale = (1.3, 1.3, 1.3)   # gigante de verdade: quase três heróis de altura

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.25 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.25 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.3 * s, 0, 0)
        p["braco_d"].rotation_euler = (-0.35 + 0.2 * s, 0, 0)
        corpo.location = (0, 0, 0.05 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


# nome: (modelo, largura, altura, giro (não usado), rampas da paleta)
INIMIGOS = {
    "diabrete_gelo": (diabrete_gelo, 30, 32, 0.0, ("gelo", "noite", "aco")),
    "espirito_nevasca": (espirito_nevasca, 34, 40, 0.0, ("gelo", "noite")),
    "guerreiro_congelado": (guerreiro_congelado, 44, 60, 0.0, ("aco", "gelo", "couro", "osso")),
    "urso_gelo": (urso_gelo, 70, 48, 0.0, ("couro", "gelo", "osso", "aco")),
    "sentinela_cristal": (sentinela_cristal, 46, 60, 0.0, ("gelo", "noite", "aco")),
    "troll_gelo": (troll_gelo, 76, 80, 0.0, ("gelo", "aco", "couro", "osso")),
    "jarl_congelado": (jarl_congelado, 64, 82, 0.0, ("aco", "gelo", "couro", "osso")),
    "gigante_tempestade": (gigante_tempestade, 150, 150, 0.0, ("pedra", "gelo", "aco", "couro", "fogo")),
}

monstros.rodar(INIMIGOS, mats, projeteis=(
    ("estilhaco", 9, ["2a3d52", "4a6a88", "7fa6c4", "e8f6ff"]),            # borda escura: lê na neve
    ("orbe_geada", 10, ["16202e", "2a3d52", "4a6a88", "7fa6c4", "b8d8ec"]),
    ("granizo", 12, ["fff2b0", "7fa6c4", "2a3d52", "0d0b14"]),               # ao contrário: borda de raio, miolo de tempestade
), rotulo="GELO")

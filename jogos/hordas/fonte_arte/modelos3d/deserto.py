"""Monstros do Deserto de Ossos (#64, região 3): 5 comuns + 1 elite + o guardião das fases + o chefe da região.

Roda (Blender 4.5 LTS):
    blender -b -P deserto.py               # todos
    blender -b -P deserto.py -- mumia      # só um
Saída: ../../projeto/assets/gerado/inimigo_<nome>.png (N+1 colunas x 5 vistas: ciclo de andar + branco, veja monstros.py) e proj_<nome>.png.
Clima (#68): sol que não se põe, caravanas mortas e tumbas abertas. O chão é CLARO (areia), ao contrário da floresta e do
pântano: os bichos são escuros ou de sombra forte (casco azul-faiança quase preto, quitina negra, linho com sombra marrom)
e os projéteis fogem da cor da areia (azul, sol negro).
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
        "casco": T("casco", C("2f63a0"), ruido=0.2, escala_ruido=8.0),        # escaravelho: azul de faiança, quase preto na sombra
        "casco_e": T("casco_e", C("1d3a6a")),
        "lapis": T("lapis", C("4f9ac8")),
        "linho": T("linho", C("c9bfa6"), ruido=0.35, escala_ruido=14.0),      # faixas da múmia: cinza-sujo (a areia é amarela)
        "linho_e": T("linho_e", C("6e4c32"), ruido=0.3, escala_ruido=12.0),
        "turbante": T("turbante", C("7e2027"), ruido=0.2, escala_ruido=6.0),   # pano vinho desbotado
        "couro_d": T("couro_d", C("6e4c32"), ruido=0.3, escala_ruido=8.0),
        "cobra": T("cobra", C("4a3a24"), ruido=0.4, escala_ruido=16.0),        # cuspideira de escama escura (lê na areia)
        "cobra_b": T("cobra_b", C("cdb06e")),                                   # barriga e frente do capelo
        "quitina": T("quitina", C("45405c"), ruido=0.25, escala_ruido=10.0),    # escorpião: preto-arroxeado
        "pena": T("pena", C("4a3324"), ruido=0.3, escala_ruido=10.0),          # abutre
        "careca": T("careca", C("c98e62")),                                     # cabeça pelada do abutre
        "veneno": monstros.px3.material_emissao("veneno", C("e4ffb0")),
    })
    return m


def _tripe(p, nomes, s, amplitude):
    """Patas de inseto em tripé alternado: a 1ª e a 3ª de um lado andam junto com a 2ª do outro."""
    for i in range(nomes):
        for lado, suf in ((1, "e"), (-1, "d")):
            k = 1 if (i % 2 == 0) == (lado > 0) else -1
            p["pata%d%s" % (i, suf)].rotation_euler = (0, 0, amplitude * s * k)


# ------------------------------------------------------------------ modelos (frente = -Y, chão = z 0)

def escaravelho(m):
    """Escaravelho: besouro do tamanho de um gato, casco azul-faiança com a risca de ouro, chifre curto e seis patas."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("casco", 0.34, (0, 0.08, 0.3), m["casco"], corpo, escala=(0.9, 1.15, 0.62))
    esfera("risca", 0.34, (0, 0.08, 0.3), m["ouro"], corpo, escala=(0.05, 1.18, 0.68))   # a junta das asas, na curva do casco
    esfera("pronoto", 0.2, (0, -0.26, 0.28), m["casco_e"], corpo, escala=(1.15, 0.8, 0.7))
    esfera("cabeca", 0.12, (0, -0.44, 0.22), m["casco_e"], corpo, escala=(1.25, 1.0, 0.7))
    espinho("chifre", (0, -0.5, 0.26), (0, -0.5, 1), 0.2, 0.045, m["ouro"], corpo)
    for x in (0.08, -0.08):
        esfera("olho", 0.03, (x, -0.53, 0.25), m["olho_f"], corpo)
    for i, y in enumerate((-0.24, 0.02, 0.26)):
        for lado in (1, -1):
            nome = "pata%d%s" % (i, "e" if lado > 0 else "d")
            j = junta(nome, (0.2 * lado, y, 0.22), corpo)
            galho(nome + "_a", (0.2 * lado, y, 0.22), (0.4 * lado, y - 0.04, 0.3), 0.032, m["negro"], j)
            galho(nome + "_b", (0.4 * lado, y - 0.04, 0.3), (0.5 * lado, y + (i - 1) * 0.1, 0.0), 0.026, m["negro"], j)
            p[nome] = j

    def pose(fase, q):
        _tripe(p, 3, math.sin(fase), 0.35)
        corpo.location = (0, 0, 0.012 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def abutre(m):
    """Abutre: penas marrom-escuras, gola de penugem clara, pescoço pelado e cabeça rosada, bico de gancho e as pontas da
    asa abertas como dedos. Voa (flutua no jogo)."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("corpo", 0.2, (0, 0.04, 0.62), m["pena"], corpo, escala=(0.9, 1.5, 0.85))
    esfera("gola", 0.13, (0, -0.2, 0.7), m["osso"], corpo, escala=(1.2, 0.8, 0.8))
    galho("pescoco", (0, -0.22, 0.72), (0, -0.34, 0.86), 0.05, m["careca"], corpo)
    esfera("cabeca", 0.09, (0, -0.37, 0.88), m["careca"], corpo, escala=(0.9, 1.2, 0.9))
    espinho("bico", (0, -0.45, 0.88), (0, -1, -0.6), 0.14, 0.04, m["osso_e"], corpo)
    for x in (0.045, -0.045):
        esfera("olho", 0.022, (x, -0.42, 0.91), m["olho_r"], corpo)
    for i in range(5):
        espinho("cauda%d" % i, (0, 0.3, 0.6), ((i - 2) * 0.22, 1, 0.0), 0.24, 0.05, m["pena"], corpo)
    for lado in (1, -1):
        nome = "asa_e" if lado > 0 else "asa_d"
        j = junta(nome, (0.14 * lado, 0.0, 0.68), corpo)
        caixa(nome + "_b", (0.46, 0.3, 0.04), (0.36 * lado, 0.02, 0.68), m["pena"], j)
        for k in range(5):   # rêmiges abertas na ponta da asa
            caixa(nome + "_p%d" % k, (0.08, 0.22 + 0.04 * k, 0.03), ((0.6 + 0.08 * k) * lado, 0.1 + 0.03 * k, 0.68), m["pena"], j)
        p[nome] = j
    for x in (0.06, -0.06):
        galho("garra", (x, 0.04, 0.46), (x, -0.04, 0.3), 0.022, m["osso_e"], corpo)

    def pose(fase, q):
        s = math.sin(fase)
        p["asa_e"].rotation_euler = (0, -0.7 * s, 0)
        p["asa_d"].rotation_euler = (0, 0.7 * s, 0)
        corpo.location = (0, 0, 0.08 * s)
    return raiz, corpo, p, pose


def esqueleto_areia(m):
    """Esqueleto das areias: ossos amarelados de sol, turbante e tanga vinho, cimitarra enferrujada e escudo de couro."""
    raiz, corpo = raiz_corpo()
    p = {}
    for x in (0.1, -0.1):
        nome = "perna_e" if x > 0 else "perna_d"
        j = junta(nome, (x, 0, 0.74), corpo)
        galho(nome + "_c", (x, 0, 0.74), (x, -0.03, 0.4), 0.045, m["osso"], j)
        galho(nome + "_t", (x, -0.03, 0.4), (x, 0.01, 0.06), 0.04, m["osso"], j)
        caixa(nome + "_pe", (0.09, 0.18, 0.05), (x, -0.05, 0.03), m["osso_e"], j)
        p[nome] = j
    caixa("bacia", (0.3, 0.15, 0.1), (0, 0, 0.78), m["osso_e"], corpo, chanfro=0.03)
    caixa("tanga", (0.34, 0.2, 0.22), (0, 0, 0.7), m["turbante"], corpo, chanfro=0.02)
    galho("espinha", (0, 0.04, 0.8), (0, 0.04, 1.3), 0.04, m["osso_e"], corpo)
    caixa("vazio", (0.26, 0.14, 0.34), (0, 0.02, 1.1), m["negro"], corpo)   # o escuro entre as costelas
    for k in range(4):
        caixa("costela%d" % k, (0.36 - abs(k - 1.5) * 0.04, 0.2, 0.035), (0, 0.0, 0.98 + k * 0.085), m["osso"], corpo, chanfro=0.01)
    caixa("ombros", (0.44, 0.14, 0.06), (0, 0.02, 1.32), m["osso"], corpo, chanfro=0.02)
    esfera("cranio", 0.15, (0, -0.02, 1.52), m["osso"], corpo, escala=(0.95, 1.0, 1.05))
    caixa("queixo", (0.15, 0.1, 0.07), (0, -0.09, 1.38), m["osso"], corpo, chanfro=0.02)
    for x in (0.06, -0.06):
        caixa("orbita", (0.07, 0.04, 0.06), (x, -0.15, 1.53), m["negro"], corpo)
        esfera("olho", 0.025, (x, -0.17, 1.53), m["olho_f"], corpo)
    esfera("turbante", 0.17, (0, 0.0, 1.6), m["turbante"], corpo, escala=(1.05, 1.05, 0.62))
    caixa("ponta", (0.06, 0.05, 0.36), (0.12, 0.12, 1.42), m["turbante"], corpo, rot=(0.3, 0, 0.2))   # ponta solta do turbante
    p["braco_d"] = braco("braco_d", 0.07, 0.07, 0.5, (-0.25, 0, 1.3), m["osso"], corpo)
    caixa("guarda", (0.12, 0.04, 0.03), (-0.25, -0.03, 0.8), m["ouro"], p["braco_d"])
    curva = [(-0.25, -0.03, 0.8), (-0.25, -0.3, 0.84), (-0.25, -0.52, 0.94), (-0.25, -0.66, 1.1)]   # cimitarra: lâmina curva
    for k in range(3):
        galho("lamina%d" % k, curva[k], curva[k + 1], 0.035 - k * 0.006, m["ferrugem"], p["braco_d"], vertices=4)
    p["braco_e"] = braco("braco_e", 0.07, 0.07, 0.5, (0.25, 0, 1.3), m["osso"], corpo)
    cilindro("escudo", 0.19, 0.04, (0.27, -0.08, 0.92), m["couro_d"], p["braco_e"], rot=(math.pi / 2, 0, 0), vertices=12)
    esfera("bossa", 0.05, (0.27, -0.11, 0.92), m["ouro"], p["braco_e"])

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.45 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.45 * s, 0, 0)
        p["braco_d"].rotation_euler = (-0.5 - 0.25 * s, 0, 0)   # cimitarra erguida pra frente
        p["braco_e"].rotation_euler = (-0.45 + 0.15 * s, 0, 0)  # escudo na frente do peito
        corpo.location = (0, 0, 0.03 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def mumia(m):
    """Múmia: enrolada em faixas de linho velho (as faixas em diagonal com sombra marrom), tiras soltas balançando, olhos
    de brasa âmbar numa fresta e os braços estendidos. Lenta e dura."""
    raiz, corpo = raiz_corpo()
    p = {}
    for x in (0.11, -0.11):
        nome = "perna_e" if x > 0 else "perna_d"
        p[nome] = braco(nome, 0.15, 0.15, 0.66, (x, 0, 0.7), m["linho"], corpo)
        for k in range(3):
            caixa(nome + "_f%d" % k, (0.17, 0.17, 0.035), (x, 0, 0.6 - k * 0.2), m["linho_e"], p[nome])
    caixa("tronco", (0.44, 0.28, 0.62), (0, 0, 1.04), m["linho"], corpo, chanfro=0.07)
    for k in range(6):
        caixa("faixa%d" % k, (0.47, 0.31, 0.035), (0, 0, 0.78 + k * 0.1), m["linho_e"], corpo, rot=(0, 0.12 * (1 if k % 2 else -1), 0))
    esfera("cabeca", 0.17, (0, -0.02, 1.5), m["linho"], corpo, escala=(0.95, 1.0, 1.1))
    caixa("faixa_c", (0.36, 0.36, 0.04), (0, -0.02, 1.6), m["linho_e"], corpo, rot=(0, 0.25, 0))
    caixa("fresta", (0.22, 0.04, 0.06), (0, -0.18, 1.5), m["negro"], corpo)
    for x in (0.055, -0.055):
        esfera("olho", 0.03, (x, -0.19, 1.5), m["olho_f"], corpo)
    for lado in (1, -1):
        nome = "braco_e" if lado > 0 else "braco_d"
        p[nome] = braco(nome, 0.11, 0.11, 0.56, (0.29 * lado, -0.02, 1.28), m["linho"], corpo)
        caixa(nome + "_f", (0.13, 0.13, 0.035), (0.29 * lado, -0.02, 0.95), m["linho_e"], p[nome])
    for k, x in enumerate((-0.15, 0.05, 0.18)):   # tiras soltas penduradas
        caixa("solta%d" % k, (0.05, 0.03, 0.3 + k * 0.06), (x, -0.15, 0.62), m["linho"], corpo, rot=(0.1, 0, 0.1 * (k - 1)))

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.3 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.3 * s, 0, 0)
        p["braco_e"].rotation_euler = (-1.35 + 0.1 * s, 0, 0)
        p["braco_d"].rotation_euler = (-1.35 - 0.1 * s, 0, 0)
        corpo.rotation_euler = (0, 0.06 * s, 0)
        corpo.location = (0, 0, 0.025 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def naja(m):
    """Naja: cobra enrolada na areia, pescoço erguido e capelo aberto (frente clara com faixas), olhos de veneno.
    Cospe veneno (atira no jogo)."""
    raiz, corpo = raiz_corpo()
    p = {}
    for k in range(40):   # rodilha: espiral de esferas bem juntas (lê como um corpo só, não como bolotas)
        a = k * 0.33
        r = 0.34 - k * 0.0045
        esfera("rodilha%d" % k, 0.1 - k * 0.0008, (math.cos(a) * r, math.sin(a) * r + 0.12, 0.08 + k * 0.007), m["cobra"], corpo)
    j = junta("pescoco", (0, 0.0, 0.3), corpo)
    pts = [(0, 0.0, 0.3), (0, -0.08, 0.6), (0, -0.1, 0.85), (0, -0.08, 1.05)]
    for k in range(3):
        galho("pesc%d" % k, pts[k], pts[k + 1], 0.09 - k * 0.01, m["cobra"], j)
    esfera("capelo", 0.4, (0, -0.04, 1.0), m["cobra"], j, escala=(0.95, 0.2, 1.1))
    esfera("capelo_b", 0.34, (0, -0.1, 0.98), m["cobra_b"], j, escala=(0.85, 0.1, 1.0))
    for k in range(3):   # faixas escuras na frente clara do capelo
        caixa("faixa%d" % k, (0.42 - k * 0.08, 0.03, 0.04), (0, -0.14, 0.82 + k * 0.13), m["cobra"], j)
    esfera("cabeca", 0.12, (0, -0.18, 1.38), m["cobra"], j, escala=(0.9, 1.3, 0.65))
    for x in (0.055, -0.055):
        esfera("olho", 0.027, (x, -0.28, 1.41), m["veneno"], j)
    caixa("lingua", (0.012, 0.12, 0.012), (0, -0.4, 1.33), m["carne"], j)
    p["pescoco"] = j

    def pose(fase, q):
        s = math.sin(fase)
        p["pescoco"].rotation_euler = (0.08 * s, 0.12 * s, 0)   # balança, de olho na presa
    return raiz, corpo, p, pose


def escorpiao_gigante(m):
    """Escorpião gigante (elite): quitina negra-arroxeada, pinças grandes, oito patas e a cauda curvada por cima das costas
    com o ferrão brilhando de veneno."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("cefalo", 0.34, (0, -0.25, 0.36), m["quitina"], corpo, escala=(1.0, 1.05, 0.5))
    for k in range(4):
        esfera("seg%d" % k, 0.3 - k * 0.025, (0, 0.12 + k * 0.2, 0.34), m["quitina"], corpo, escala=(1.05, 0.7, 0.48))
    for x in (0.08, -0.08):
        esfera("olho", 0.035, (x, -0.52, 0.48), m["olho_r"], corpo)
    j = junta("cauda", (0, 0.8, 0.36), corpo)
    pts = [(0, 0.8, 0.36), (0, 0.98, 0.62), (0, 0.95, 0.92), (0, 0.78, 1.15), (0, 0.52, 1.26), (0, 0.3, 1.18)]
    for k in range(5):
        a, b = pts[k], pts[k + 1]
        esfera("gomo%d" % k, 0.12 - k * 0.012, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), m["quitina"], j)
    esfera("bolsa", 0.1, pts[5], m["quitina"], j)
    espinho("ferrao", pts[5], (0, -0.6, -0.8), 0.22, 0.05, m["veneno"], j)
    p["cauda"] = j
    for lado in (1, -1):
        nome = "pinca_e" if lado > 0 else "pinca_d"
        jj = junta(nome, (0.25 * lado, -0.4, 0.36), corpo)
        galho(nome + "_1", (0.25 * lado, -0.4, 0.36), (0.42 * lado, -0.62, 0.4), 0.07, m["quitina"], jj)
        galho(nome + "_2", (0.42 * lado, -0.62, 0.4), (0.38 * lado, -0.85, 0.4), 0.06, m["quitina"], jj)
        esfera(nome + "_mao", 0.14, (0.38 * lado, -0.95, 0.4), m["quitina"], jj, escala=(0.8, 1.2, 0.7))
        espinho(nome + "_dedo1", (0.42 * lado, -1.05, 0.4), (0.3 * lado, -1, 0), 0.2, 0.05, m["quitina"], jj)
        espinho(nome + "_dedo2", (0.33 * lado, -1.05, 0.4), (-0.3 * lado, -1, 0), 0.18, 0.045, m["quitina"], jj)
        p[nome] = jj
    for i, y in enumerate((-0.3, -0.1, 0.12, 0.34)):
        for lado in (1, -1):
            nome = "pata%d%s" % (i, "e" if lado > 0 else "d")
            jj = junta(nome, (0.26 * lado, y, 0.32), corpo)
            meio = (0.52 * lado, y + (i - 1.5) * 0.06, 0.42)
            galho(nome + "_a", (0.26 * lado, y, 0.32), meio, 0.04, m["quitina"], jj)
            galho(nome + "_b", meio, (0.66 * lado, y + (i - 1.5) * 0.12, 0.0), 0.032, m["quitina"], jj)
            p[nome] = jj
    corpo.scale = (1.35, 1.35, 1.35)   # elite: bem maior que os comuns (a pose não mexe na escala)

    def pose(fase, q):
        s = math.sin(fase)
        _tripe(p, 4, s, 0.25)
        p["pinca_e"].rotation_euler = (0, 0, 0.12 * s)
        p["pinca_d"].rotation_euler = (0, 0, 0.12 * s)
        p["cauda"].rotation_euler = (0.1 * s, 0, 0)
        corpo.location = (0, 0, 0.015 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def sacerdote_areia(m):
    """Sacerdote das Areias (guardião das fases): morto-vivo de túnica escura, gola larga de ouro e lápis, toucado alto
    listrado, rosto de osso com olhos de brasa e um cajado com o disco do sol negro."""
    raiz, corpo = raiz_corpo()
    p = {}
    cone("tunica", 0.42, 0.2, 1.15, (0, 0, 0.58), m["pano"], corpo, vertices=12)
    caixa("faixa_t", (0.08, 0.02, 0.9), (0, -0.33, 0.52), m["ouro"], corpo, rot=(-0.19, 0, 0))
    esfera("peito", 0.22, (0, 0, 1.2), m["pano"], corpo, escala=(1.1, 0.8, 1.0))
    cilindro("gola", 0.3, 0.06, (0, -0.02, 1.32), m["ouro"], corpo, vertices=16)
    cilindro("gola2", 0.25, 0.065, (0, -0.02, 1.335), m["lapis"], corpo, vertices=16)
    esfera("cranio", 0.15, (0, -0.03, 1.5), m["osso"], corpo, escala=(0.9, 1.0, 1.1))
    for x in (0.055, -0.055):
        caixa("orbita", (0.06, 0.04, 0.05), (x, -0.16, 1.52), m["negro"], corpo)
        esfera("olho", 0.024, (x, -0.18, 1.52), m["olho_r"], corpo)
    caixa("boca", (0.09, 0.03, 0.03), (0, -0.15, 1.41), m["negro"], corpo)
    cone("toucado", 0.17, 0.1, 0.5, (0, 0.02, 1.82), m["lapis"], corpo, vertices=10)
    for k in range(3):
        cilindro("listra%d" % k, 0.168 - k * 0.022, 0.035, (0, 0.02, 1.65 + k * 0.13), m["ouro"], corpo, vertices=10)
    for lado in (1, -1):
        caixa("aba", (0.08, 0.16, 0.3), (0.17 * lado, -0.02, 1.42), m["lapis"], corpo)
        nome = "braco_e" if lado > 0 else "braco_d"
        p[nome] = braco(nome, 0.1, 0.1, 0.5, (0.28 * lado, -0.02, 1.28), m["pano"], corpo)
    j = junta("cajado", (-0.36, -0.17, 0.0), corpo)   # o cajado balança a partir do pé dele
    galho("vara", (-0.36, -0.17, 0.0), (-0.36, -0.17, 1.95), 0.03, m["ouro"], j)
    cilindro("coroa_sol", 0.2, 0.03, (-0.36, -0.15, 2.05), m["fogo"], j, rot=(math.pi / 2, 0, 0), vertices=16)
    cilindro("sol_negro", 0.15, 0.04, (-0.36, -0.19, 2.05), m["negro"], j, rot=(math.pi / 2, 0, 0), vertices=16)
    p["cajado"] = j

    def pose(fase, q):
        s = math.sin(fase)
        p["braco_d"].rotation_euler = (-0.35, 0, 0)               # segura o cajado
        p["braco_e"].rotation_euler = (-1.0 + 0.2 * s, 0, 0)      # a outra mão erguida, conjurando
        p["cajado"].rotation_euler = (0.05 * s, 0, 0)
        corpo.rotation_euler = (0, 0.04 * s, 0)
        corpo.location = (0, 0, 0.03 * s)                        # desliza: a túnica esconde os pés
    return raiz, corpo, p, pose


def rei_escaravelho(m):
    """O Rei Escaravelho (chefe do Deserto): besouro do tamanho de uma carroça, casco azul-faiança com borda de ouro,
    chifres de ouro segurando o sol negro (disco escuro com coroa de luz), mandíbulas, seis patas e olhos de brasa."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("borda", 1.12, (0, 0.3, 0.92), m["ouro"], corpo, escala=(0.95, 1.2, 0.36))   # aparece em volta do casco
    esfera("casco", 1.08, (0, 0.3, 1.0), m["casco"], corpo, escala=(0.92, 1.18, 0.55))
    esfera("risca", 1.08, (0, 0.3, 1.0), m["ouro"], corpo, escala=(0.06, 1.21, 0.6))   # fatia fina do casco: segue a curva
    esfera("pronoto", 0.62, (0, -0.85, 0.95), m["casco_e"], corpo, escala=(1.2, 0.75, 0.7))
    esfera("cabeca", 0.38, (0, -1.32, 0.78), m["casco_e"], corpo, escala=(1.25, 0.9, 0.75))
    for x in (0.2, -0.2):
        esfera("olho", 0.07, (x, -1.62, 0.86), m["olho_r"], corpo)
    for lado in (1, -1):
        galho("chifre%d" % lado, (0.18 * lado, -1.45, 1.0), (0.3 * lado, -1.6, 1.55), 0.07, m["ouro"], corpo)
        galho("chifre_p%d" % lado, (0.3 * lado, -1.6, 1.55), (0.2 * lado, -1.55, 1.95), 0.05, m["ouro"], corpo)
        espinho("mandibula%d" % lado, (0.15 * lado, -1.6, 0.6), (0.4 * lado, -1, -0.1), 0.35, 0.06, m["ouro"], corpo)
    j = junta("sol", (0, -1.6, 1.75), corpo)
    cilindro("coroa_sol", 0.42, 0.04, (0, -1.58, 1.75), m["fogo"], j, rot=(math.pi / 2, 0, 0), vertices=20)
    cilindro("sol_negro", 0.32, 0.06, (0, -1.62, 1.75), m["negro"], j, rot=(math.pi / 2, 0, 0), vertices=20)
    p["sol"] = j
    for i, y in enumerate((-0.75, 0.1, 0.85)):   # patas curtas e grossas, quase escondidas sob o casco (besouro, não aranha)
        for lado in (1, -1):
            nome = "pata%d%s" % (i, "e" if lado > 0 else "d")
            jj = junta(nome, (0.7 * lado, y, 0.75), corpo)
            joelho = (1.15 * lado, y - 0.05, 0.85)
            pe = (1.35 * lado, y + (i - 1) * 0.25, 0.0)
            galho(nome + "_a", (0.7 * lado, y, 0.75), joelho, 0.15, m["casco_e"], jj)
            galho(nome + "_b", joelho, pe, 0.12, m["casco_e"], jj)
            espinho(nome + "_garra", (pe[0], pe[1], 0.08), (0.3 * lado, 0, -1), 0.15, 0.05, m["ouro"], jj)
            p[nome] = jj

    def pose(fase, q):
        s = math.sin(fase)
        _tripe(p, 3, s, 0.18)
        p["sol"].scale = (1.0 + 0.06 * s, 1.0 + 0.06 * s, 1.0 + 0.06 * s)   # o sol negro pulsa
        corpo.location = (0, 0, 0.02 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


# nome: (modelo, largura, altura, giro (não usado), rampas da paleta)
INIMIGOS = {
    "escaravelho": (escaravelho, 30, 24, 0.0, ("lapis", "ouro", "aco", "fogo")),
    "abutre": (abutre, 56, 40, 0.0, ("couro", "pele", "osso", "aco")),
    "esqueleto_areia": (esqueleto_areia, 42, 58, 0.0, ("osso", "areia", "sangue", "couro", "ouro", "fogo")),
    "mumia": (mumia, 42, 58, 0.0, ("osso", "pedra", "couro", "fogo")),
    "naja": (naja, 38, 46, 0.0, ("areia", "couro", "veneno", "sangue")),
    "escorpiao_gigante": (escorpiao_gigante, 74, 56, 0.0, ("aco", "veneno")),
    "sacerdote_areia": (sacerdote_areia, 54, 76, 0.0, ("aco", "lapis", "ouro", "osso", "fogo")),
    "rei_escaravelho": (rei_escaravelho, 136, 116, 0.0, ("lapis", "ouro", "fogo", "aco")),
}

monstros.rodar(INIMIGOS, mats, projeteis=(
    ("cuspe_naja", 9, ["2f7a3a", "56b04a", "a6e070", "e4ffb0"]),
    ("orbe_lapis", 10, ["0f1f3a", "1d3a6a", "2f63a0", "4f9ac8", "8fd0e0"]),
    ("sol_negro", 12, ["fff2b0", "eccb7a", "5c4320", "0d0b14"]),   # ao contrário: borda clara, miolo preto
), rotulo="DESERTO")

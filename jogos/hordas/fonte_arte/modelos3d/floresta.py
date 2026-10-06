"""Monstros da Floresta Sombria (#64, região 1): 5 comuns + 1 elite + o guardião das fases + o chefe da região.

Roda (Blender 4.5 LTS):
    blender -b -P floresta.py              # todos
    blender -b -P floresta.py lobo_sombrio # só um
Saída: ../../projeto/assets/gerado/inimigo_<nome>.png (3 colunas x 5 vistas, veja monstros.py) e proj_<nome>.png.
Clima (#68, Dimraeth): floresta que vai de convidativa a ameaçadora. Musgo, casca podre, olhos que brilham no escuro.
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
        "pelo": T("pelo", C("6f6a86"), ruido=0.3, escala_ruido=10.0),     # lobo: cinza médio (no chão escuro, o escuro sumia)
        "pelo_e": T("pelo_e", C("45405c")),
        "casca": T("casca", C("6e4c32"), ruido=0.35, escala_ruido=7.0),   # casca de árvore
        "casca_e": T("casca_e", C("4a3324")),
        "folha": T("folha", C("466a2c"), ruido=0.3, escala_ruido=6.0),
        "folha_e": T("folha_e", C("2d4721")),
        "musgo": T("musgo", C("566e55"), ruido=0.25, escala_ruido=12.0),
        "quitina": T("quitina", C("2e2a40"), ruido=0.15, escala_ruido=14.0),   # aranha
        "palha": T("palha", C("c49a45"), ruido=0.3, escala_ruido=12.0),
        "saco": T("saco", C("9a6d45"), ruido=0.3, escala_ruido=14.0),      # aniagem do espantalho
        "chapeu": T("chapeu", C("1d1a2b")),
        "cogumelo": T("cogumelo", C("7e2027"), ruido=0.15, escala_ruido=8.0),
        "pena": T("pena", C("152040"), ruido=0.2, escala_ruido=12.0),       # corvo: preto-azulado
        "bico": T("bico", C("8f6a2e")),
        "manto_v": T("manto_v", C("566e55"), ruido=0.25, escala_ruido=8.0),   # bruxa: verde-musgo claro (lê no chão escuro)
        "casaco": T("casaco", C("6e4c32"), ruido=0.3, escala_ruido=10.0),   # espantalho: aniagem marrom
        "lanterna": monstros.px3.material_emissao("lanterna", C("a6e070")),
    })
    return m


# ------------------------------------------------------------------ modelos (frente = -Y, chão = z 0)

def lobo_sombrio(m):
    """Lobo sombrio: magro, pelo eriçado nas costas, olhos de brasa e presas."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("torso", 0.28, (0, 0.06, 0.62), m["pelo"], corpo, escala=(0.85, 1.65, 0.9))
    esfera("peito", 0.25, (0, -0.32, 0.62), m["pelo"], corpo, escala=(0.9, 1.0, 1.05))
    for i, y in enumerate((-0.32, -0.14, 0.04, 0.22)):
        espinho("eriçado%d" % i, (0, y, 0.84), (0, 0.6, 1), 0.2, 0.07, m["pelo_e"], corpo)
    caixa("pescoco", (0.2, 0.22, 0.24), (0, -0.5, 0.76), m["pelo"], corpo, chanfro=0.04)
    caixa("cabeca", (0.26, 0.3, 0.24), (0, -0.64, 0.88), m["pelo"], corpo, chanfro=0.05)
    caixa("focinho", (0.14, 0.26, 0.12), (0, -0.86, 0.82), m["pelo_e"], corpo, chanfro=0.03)
    caixa("nariz", (0.06, 0.05, 0.05), (0, -0.99, 0.86), m["negro"], corpo)
    caixa("boca", (0.12, 0.2, 0.04), (0, -0.86, 0.74), m["carne_e"], corpo)
    for k in (-0.045, 0.045):
        espinho("presa", (k, -0.94, 0.77), (0, -0.2, -1), 0.07, 0.022, m["osso"], corpo)
    for x in (0.075, -0.075):
        esfera("olho", 0.04, (x, -0.78, 0.94), m["olho_r"], corpo)
        espinho("orelha", (x * 1.2, -0.58, 0.98), (x * 2.5, 0.25, 1), 0.17, 0.05, m["pelo_e"], corpo)
    for nome, x, y in (("fe", 0.14, -0.36), ("fd", -0.14, -0.36), ("te", 0.14, 0.4), ("td", -0.14, 0.4)):
        p[nome] = braco("pata_" + nome, 0.1, 0.12, 0.56, (x, y, 0.58), m["pelo"], corpo)
        caixa("pe", (0.1, 0.14, 0.05), (x, y - 0.04, 0.03), m["pelo_e"], p[nome])
    p["cauda"] = junta("cauda", (0, 0.5, 0.72), corpo)
    galho("cauda_g", (0, 0.5, 0.72), (0, 0.9, 0.82), 0.07, m["pelo_e"], p["cauda"])

    def pose(fase, q):
        s = math.sin(fase)
        p["fe"].rotation_euler = (0.75 * s, 0, 0)
        p["td"].rotation_euler = (0.75 * s, 0, 0)
        p["fd"].rotation_euler = (-0.75 * s, 0, 0)
        p["te"].rotation_euler = (-0.75 * s, 0, 0)
        p["cauda"].rotation_euler = (0, 0, 0.35 * s)
        corpo.location = (0, 0, 0.06 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def aranha_tecela(m):
    """Aranha tecelã: abdômen grande com uma caveira pálida desenhada, seis olhos verdes, oito patas finas."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("abdomen", 0.34, (0, 0.34, 0.5), m["quitina"], corpo, escala=(1.0, 1.25, 0.85))
    esfera("marca", 0.14, (0, 0.3, 0.76), m["osso"], corpo, escala=(1.0, 1.0, 0.35))       # a caveira nas costas
    for x in (0.05, -0.05):
        esfera("marca_olho", 0.035, (x, 0.24, 0.8), m["negro"], corpo)
    esfera("torax", 0.2, (0, -0.12, 0.42), m["quitina"], corpo, escala=(1.0, 1.1, 0.8))
    esfera("cabeca", 0.13, (0, -0.32, 0.42), m["quitina"], corpo)
    for x, z in ((0.06, 0.5), (-0.06, 0.5), (0.1, 0.46), (-0.1, 0.46), (0.035, 0.44), (-0.035, 0.44)):
        esfera("olho", 0.03, (x, -0.42, z), m["olho_v"], corpo)
    for x in (0.05, -0.05):
        espinho("quelicera", (x, -0.42, 0.36), (x * 2, -0.6, -1), 0.13, 0.03, m["osso_e"], corpo)
    for lado in (1, -1):
        for i, y in enumerate((-0.28, -0.14, 0.0, 0.14)):
            nome = "p%d%s" % (i, "e" if lado > 0 else "d")
            base = (0.14 * lado, y, 0.44)
            j = junta(nome, base, corpo)
            joelho = (0.55 * lado, y * 1.7 - 0.05, 0.78)
            pe = (0.78 * lado, y * 2.2 - 0.1, 0.0)
            galho(nome + "_a", base, joelho, 0.035, m["quitina"], j)
            galho(nome + "_b", joelho, pe, 0.028, m["quitina"], j)
            p[nome] = j

    def pose(fase, q):
        s = math.sin(fase)
        for lado in ("e", "d"):
            for i in range(4):
                alterna = 1 if (i % 2 == 0) == (lado == "e") else -1
                p["p%d%s" % (i, lado)].rotation_euler = (0, 0, 0.22 * s * alterna)
        corpo.location = (0, 0, 0.03 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def espantalho(m):
    """Espantalho podre: saco de aniagem costurado na cabeça, olhos de brasa, chapéu torto, palha saindo de tudo."""
    raiz, corpo = raiz_corpo()
    p = {}
    for x in (0.12, -0.12):
        p["perna_e" if x > 0 else "perna_d"] = braco("perna", 0.08, 0.08, 0.7, (x, 0, 0.72), m["casca"], corpo)
    caixa("casaco", (0.5, 0.32, 0.6), (0, 0, 1.0), m["casaco"], corpo, chanfro=0.05)
    for i, x in enumerate((-0.18, -0.06, 0.06, 0.18)):
        espinho("barra%d" % i, (x, -0.02, 0.72), (x * 0.5, 0, -1), 0.14, 0.06, m["casaco"], corpo)   # barra rasgada
    caixa("cinto", (0.52, 0.34, 0.06), (0, 0, 0.84), m["casca_e"], corpo)
    p["bracos"] = junta("bracos", (0, 0, 1.16), corpo)
    caixa("trave", (1.2, 0.08, 0.08), (0, 0.02, 1.16), m["casca"], p["bracos"])
    for x in (0.38, -0.38):
        caixa("manga", (0.3, 0.2, 0.2), (x, 0, 1.16), m["casaco"], p["bracos"], chanfro=0.03)
        for k in range(3):
            espinho("palha_mao", (x * 1.55, 0, 1.16), (x * 2, (k - 1) * 0.6, -0.5 + k * 0.4), 0.16, 0.03, m["palha"], p["bracos"])
    for k in range(5):
        a = k * math.tau / 5
        espinho("palha_gola", (0, 0, 1.3), (math.cos(a), math.sin(a), 0.5), 0.14, 0.035, m["palha"], corpo)
    esfera("cabeca", 0.2, (0, -0.02, 1.48), m["saco"], corpo, escala=(1.0, 0.95, 1.05))
    for x in (0.07, -0.07):
        esfera("olho", 0.035, (x, -0.2, 1.52), m["fogo"], corpo)
    for i, x in enumerate((-0.08, -0.03, 0.02, 0.07)):
        caixa("ponto%d" % i, (0.012, 0.02, 0.05), (x, -0.2, 1.4), m["negro"], corpo)   # boca costurada
    caixa("boca", (0.18, 0.02, 0.012), (0, -0.2, 1.4), m["negro"], corpo)
    cilindro("aba", 0.32, 0.03, (0, 0, 1.64), m["chapeu"], corpo, rot=(0.15, 0.1, 0))
    cone("copa", 0.17, 0.02, 0.42, (0.03, 0.04, 1.84), m["chapeu"], corpo)

    def pose(fase, q):
        s = math.sin(fase)
        p["perna_e"].rotation_euler = (0.45 * s, 0, 0)
        p["perna_d"].rotation_euler = (-0.45 * s, 0, 0)
        p["bracos"].rotation_euler = (0, 0.12 * s, 0)
        corpo.location = (0, 0, 0.07 * abs(math.sin(fase)))   # anda aos pulinhos
    return raiz, corpo, p, pose


def cogumelo_errante(m):
    """Cogumelo errante: chapéu vermelho-sangue com pintas, perninhas curtas e dois olhinhos amarelos."""
    raiz, corpo = raiz_corpo()
    p = {}
    cilindro("caule", 0.15, 0.36, (0, 0, 0.3), m["osso"], corpo, vertices=10)
    esfera("chapeu", 0.3, (0, 0, 0.5), m["cogumelo"], corpo, escala=(1.0, 1.0, 0.6))
    for i in range(7):
        a = i * math.tau / 7 + 0.3
        r = 0.18 if i % 2 else 0.1
        esfera("pinta%d" % i, 0.045, (math.cos(a) * r, math.sin(a) * r, 0.66 - r * 0.25), m["osso"], corpo)
    caixa("lamelas", (0.46, 0.46, 0.03), (0, 0, 0.45), m["carne_e"], corpo)
    for x in (0.06, -0.06):
        esfera("olho", 0.03, (x, -0.14, 0.34), m["olho_f"], corpo)
    caixa("boca", (0.08, 0.02, 0.02), (0, -0.15, 0.26), m["negro"], corpo)
    for x in (0.08, -0.08):
        p["pe_e" if x > 0 else "pe_d"] = braco("pe", 0.07, 0.07, 0.14, (x, 0, 0.14), m["osso_e"], corpo)

    def pose(fase, q):
        s = math.sin(fase)
        p["pe_e"].rotation_euler = (0.6 * s, 0, 0)
        p["pe_d"].rotation_euler = (-0.6 * s, 0, 0)
        corpo.rotation_euler = (0, 0.12 * s, 0)   # bamboleia
        corpo.location = (0, 0, 0.03 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def corvo_carniceiro(m):
    """Corvo carniceiro: grande, preto-azulado, olho vermelho, asas abertas batendo (voa: flutua no jogo)."""
    raiz, corpo = raiz_corpo()
    p = {}
    esfera("corpo", 0.18, (0, 0.04, 0.5), m["pena"], corpo, escala=(0.85, 1.45, 0.9))
    esfera("cabeca", 0.12, (0, -0.24, 0.62), m["pena"], corpo)
    espinho("bico", (0, -0.34, 0.6), (0, -1, -0.25), 0.2, 0.05, m["bico"], corpo)
    for x in (0.06, -0.06):
        esfera("olho", 0.03, (x, -0.3, 0.66), m["olho_r"], corpo)
    for i in range(4):
        espinho("cauda%d" % i, (0, 0.28, 0.5), ((i - 1.5) * 0.25, 1, 0.05), 0.26, 0.05, m["pena"], corpo)
    for lado in (1, -1):
        nome = "asa_e" if lado > 0 else "asa_d"
        j = junta(nome, (0.12 * lado, 0.0, 0.56), corpo)
        caixa(nome + "_b", (0.36, 0.26, 0.04), (0.3 * lado, 0.02, 0.56), m["pena"], j)
        for k in range(4):
            caixa(nome + "_p%d" % k, (0.1, 0.2 + 0.05 * k, 0.03), ((0.42 + 0.09 * k) * lado, 0.14 + 0.02 * k, 0.56), m["pena"], j)
        p[nome] = j
    for x in (0.05, -0.05):
        galho("garra", (x, 0.02, 0.36), (x, -0.06, 0.22), 0.02, m["bico"], corpo)

    def pose(fase, q):
        s = math.sin(fase)
        p["asa_e"].rotation_euler = (0, -0.9 * s, 0)
        p["asa_d"].rotation_euler = (0, 0.9 * s, 0)
        corpo.location = (0, 0, 0.08 * s)
    return raiz, corpo, p, pose


def galhudo(m):
    """Galhudo (elite): árvore jovem que anda. Tronco de casca podre, cara entalhada com olhos verdes, braços de galho
    com espinhos, raízes no lugar dos pés e uma copa de folhas escuras."""
    raiz, corpo = raiz_corpo()
    p = {}
    cilindro("tronco", 0.32, 1.1, (0, 0, 0.95), m["casca"], corpo, vertices=10, chanfro=0.03)
    for i in range(5):
        a = i * math.tau / 5
        caixa("veio%d" % i, (0.05, 0.05, 0.9), (math.cos(a) * 0.31, math.sin(a) * 0.31, 0.95), m["casca_e"], corpo)
    for i, (x, z) in enumerate(((0.2, 0.7), (-0.18, 1.1), (0.1, 1.3))):
        esfera("musgo%d" % i, 0.12, (x, -0.2, z), m["musgo"], corpo, escala=(1, 0.5, 0.7))
    for x in (0.1, -0.1):
        caixa("orbita", (0.1, 0.06, 0.08), (x, -0.31, 1.22), m["negro"], corpo)
        esfera("olho", 0.04, (x, -0.33, 1.22), m["olho_v"], corpo)
    caixa("boca", (0.2, 0.06, 0.1), (0, -0.31, 1.0), m["negro"], corpo)
    for lado in (1, -1):
        nome = "braco_e" if lado > 0 else "braco_d"
        j = junta(nome, (0.3 * lado, 0, 1.3), corpo)
        galho(nome + "_1", (0.3 * lado, 0, 1.3), (0.65 * lado, -0.12, 0.95), 0.08, m["casca"], j)
        galho(nome + "_2", (0.65 * lado, -0.12, 0.95), (0.78 * lado, -0.2, 0.6), 0.06, m["casca"], j)
        for k in range(3):
            espinho(nome + "_dedo%d" % k, (0.78 * lado, -0.2, 0.6), ((k - 1) * 0.5 * lado + 0.3 * lado, -0.4, -1), 0.18, 0.03, m["casca_e"], j)
        espinho(nome + "_esp", (0.5 * lado, -0.06, 1.12), (lado, -0.2, 0.6), 0.16, 0.04, m["casca_e"], j)
        p[nome] = j
    for lado in (1, -1):
        nome = "raiz_e" if lado > 0 else "raiz_d"
        j = junta(nome, (0.16 * lado, 0, 0.45), corpo)
        galho(nome + "_1", (0.16 * lado, 0, 0.45), (0.26 * lado, -0.1, 0.02), 0.1, m["casca_e"], j)
        galho(nome + "_2", (0.26 * lado, -0.1, 0.02), (0.42 * lado, -0.3, 0.0), 0.06, m["casca_e"], j)
        p[nome] = j
    for i, (x, y, z, r) in enumerate(((0, 0, 1.75, 0.42), (0.3, 0.1, 1.6, 0.3), (-0.3, 0.05, 1.62, 0.3), (0.05, -0.18, 1.62, 0.26), (0, 0.22, 1.66, 0.3))):
        esfera("copa%d" % i, r, (x, y, z), m["folha"] if i % 2 == 0 else m["folha_e"], corpo, escala=(1, 1, 0.8))

    def pose(fase, q):
        s = math.sin(fase)
        p["raiz_e"].rotation_euler = (0.5 * s, 0, 0)
        p["raiz_d"].rotation_euler = (-0.5 * s, 0, 0)
        p["braco_e"].rotation_euler = (-0.25 * s, 0, 0)
        p["braco_d"].rotation_euler = (0.25 * s, 0, 0)
        corpo.rotation_euler = (0, 0.05 * s, 0)
        corpo.location = (0, 0, 0.04 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


def bruxa_do_mato(m):
    """Bruxa do Mato (guardiã das fases): curvada num manto verde-musgo em farrapos, capuz, nariz comprido, olhos
    verdes; segura um cajado torto com uma lanterna de vaga-lumes."""
    raiz, corpo = raiz_corpo()
    p = {}
    cone("saia", 0.42, 0.2, 0.9, (0, 0.04, 0.5), m["manto_v"], corpo, vertices=10)
    for i in range(7):
        a = i * math.tau / 7
        espinho("farrapo%d" % i, (math.cos(a) * 0.38, math.sin(a) * 0.38 + 0.04, 0.12), (math.cos(a) * 0.4, math.sin(a) * 0.4, -1), 0.14, 0.06, m["manto_v"], corpo)
    esfera("costas", 0.26, (0, 0.12, 1.02), m["manto_v"], corpo, escala=(1.0, 1.0, 0.9))   # corcunda
    esfera("cabeca", 0.15, (0, -0.12, 1.16), m["pele"], corpo)
    cone("capuz", 0.22, 0.04, 0.42, (0, -0.02, 1.32), m["pano"], corpo)
    espinho("nariz", (0, -0.26, 1.15), (0, -1, -0.4), 0.16, 0.035, m["pele"], corpo)
    for x in (0.055, -0.055):
        esfera("olho", 0.03, (x, -0.24, 1.21), m["olho_v"], corpo)
    for i in range(3):
        caixa("cabelo%d" % i, (0.03, 0.03, 0.3), ((i - 1) * 0.1, -0.12, 0.98), m["osso_e"], corpo)
    p["cajado"] = junta("cajado", (0.3, -0.18, 0.9), corpo)
    galho("cajado_g", (0.3, -0.18, 0.0), (0.32, -0.22, 1.5), 0.035, m["casca"], p["cajado"])
    galho("cajado_c", (0.32, -0.22, 1.5), (0.4, -0.3, 1.62), 0.03, m["casca"], p["cajado"])
    esfera("lanterna", 0.09, (0.42, -0.32, 1.52), m["lanterna"], p["cajado"])
    for k in range(4):
        a = k * math.tau / 4
        galho("gaiola%d" % k, (0.42 + math.cos(a) * 0.1, -0.32 + math.sin(a) * 0.1, 1.42), (0.42 + math.cos(a) * 0.1, -0.32 + math.sin(a) * 0.1, 1.62), 0.012, m["aco_e"], p["cajado"])
    galho("mao", (0.2, -0.1, 1.0), (0.3, -0.2, 0.92), 0.05, m["pele"], corpo)
    galho("mao2", (-0.2, -0.05, 1.0), (-0.26, -0.22, 0.86), 0.05, m["pele"], corpo)
    for k in range(3):
        espinho("unha%d" % k, (-0.26, -0.22, 0.86), ((k - 1) * 0.4, -1, -0.3), 0.1, 0.02, m["osso_e"], corpo)

    def pose(fase, q):
        s = math.sin(fase)
        p["cajado"].rotation_euler = (0.12 * s, 0, 0)
        corpo.rotation_euler = (0, 0.06 * s, 0)
        corpo.location = (0, 0, 0.05 + 0.04 * s)   # flutua um pouco (no jogo, "flutua")
    return raiz, corpo, p, pose


def velho_carvalho(m):
    """O Velho Carvalho (chefe da Floresta): um carvalho enorme e podre que arrancou as raízes do chão. Rosto no tronco
    com olhos e boca de brasa verde, braços de galho com dedos de ramo, copa escura com barba de musgo pendurada e
    cogumelos crescendo no tronco."""
    raiz, corpo = raiz_corpo()
    p = {}
    cilindro("tronco", 0.62, 2.0, (0, 0, 1.45), m["casca"], corpo, vertices=12, chanfro=0.04)
    cilindro("base", 0.78, 0.5, (0, 0, 0.62), m["casca_e"], corpo, vertices=12)
    for i in range(8):
        a = i * math.tau / 8
        caixa("veio%d" % i, (0.08, 0.08, 1.8), (math.cos(a) * 0.6, math.sin(a) * 0.6, 1.45), m["casca_e"], corpo)
    # rosto
    for x in (0.22, -0.22):
        caixa("orbita", (0.2, 0.08, 0.16), (x, -0.6, 1.9), m["negro"], corpo)
        esfera("olho", 0.08, (x, -0.63, 1.9), m["lanterna"], corpo)
        caixa("sobrancelha", (0.28, 0.1, 0.08), (x, -0.62, 2.04), m["casca_e"], corpo, rot=(0, 0.35 if x > 0 else -0.35, 0))
    caixa("boca", (0.42, 0.08, 0.26), (0, -0.6, 1.42), m["negro"], corpo)
    esfera("garganta", 0.1, (0, -0.58, 1.42), m["lanterna"], corpo, escala=(1.6, 0.5, 0.9))
    for k in range(4):
        espinho("dente%d" % k, ((k - 1.5) * 0.1, -0.64, 1.56), (0, -0.2, -1), 0.1, 0.03, m["osso_e"], corpo)
    # cogumelos no tronco
    for i, (a, z) in enumerate(((0.4, 1.0), (2.4, 1.3), (4.0, 0.9), (5.4, 1.7))):
        x, y = math.cos(a) * 0.64, math.sin(a) * 0.64
        esfera("cogu%d" % i, 0.12, (x, y, z), m["cogumelo"], corpo, escala=(1, 1, 0.5))
    # braços de galho
    for lado in (1, -1):
        nome = "braco_e" if lado > 0 else "braco_d"
        j = junta(nome, (0.55 * lado, 0, 2.0), corpo)
        galho(nome + "_1", (0.55 * lado, 0, 2.0), (1.15 * lado, -0.3, 1.7), 0.16, m["casca"], j)
        galho(nome + "_2", (1.15 * lado, -0.3, 1.7), (1.35 * lado, -0.55, 1.15), 0.12, m["casca"], j)
        for k in range(4):
            espinho(nome + "_dedo%d" % k, (1.35 * lado, -0.55, 1.15), ((k - 1.5) * 0.45 * lado + 0.2 * lado, -0.6, -1), 0.34, 0.05, m["casca_e"], j)
        galho(nome + "_ramo", (0.9 * lado, -0.15, 1.85), (1.15 * lado, 0.1, 2.35), 0.06, m["casca"], j)
        p[nome] = j
    # raízes como pernas (4)
    for i, (x, y) in enumerate(((0.5, -0.35), (-0.5, -0.35), (0.55, 0.4), (-0.55, 0.4))):
        nome = "raiz%d" % i
        j = junta(nome, (x * 0.7, y * 0.7, 0.55), corpo)
        galho(nome + "_1", (x * 0.7, y * 0.7, 0.55), (x * 1.5, y * 1.5, 0.15), 0.16, m["casca_e"], j)
        galho(nome + "_2", (x * 1.5, y * 1.5, 0.15), (x * 2.0, y * 2.0, 0.0), 0.1, m["casca_e"], j)
        p[nome] = j
    # copa e barba de musgo
    for i, (x, y, z, r) in enumerate(((0, 0, 2.9, 0.9), (0.75, 0.2, 2.6, 0.6), (-0.75, 0.15, 2.65, 0.6), (0.2, -0.45, 2.55, 0.5), (-0.3, 0.5, 2.7, 0.55))):
        esfera("copa%d" % i, r, (x, y, z), m["folha"] if i % 2 == 0 else m["folha_e"], corpo, escala=(1, 1, 0.75))
    for i in range(6):
        a = i * math.tau / 6 + 0.4
        caixa("barba%d" % i, (0.06, 0.06, 0.6), (math.cos(a) * 0.7, math.sin(a) * 0.7 - 0.1, 2.05), m["musgo"], corpo)

    def pose(fase, q):
        s = math.sin(fase)
        for i in range(4):
            p["raiz%d" % i].rotation_euler = (0.25 * s * (1 if i % 2 == 0 else -1), 0, 0)
        p["braco_e"].rotation_euler = (-0.2 * s, 0, 0.1 * s)
        p["braco_d"].rotation_euler = (0.2 * s, 0, -0.1 * s)
        corpo.rotation_euler = (0, 0.04 * s, 0)
        corpo.location = (0, 0, 0.05 * abs(math.cos(fase)))
    return raiz, corpo, p, pose


# nome: (modelo, largura, altura, giro (não usado), rampas da paleta)
INIMIGOS = {
    "lobo_sombrio": (lobo_sombrio, 48, 40, 0.0, ("aco", "sangue", "osso", "noite")),
    "aranha_tecela": (aranha_tecela, 54, 34, 0.0, ("noite", "aco", "osso", "veneno")),
    "espantalho": (espantalho, 44, 58, 0.0, ("couro", "ouro", "noite", "fogo", "aco")),
    "cogumelo_errante": (cogumelo_errante, 26, 26, 0.0, ("sangue", "osso", "ouro", "fogo")),
    "corvo_carniceiro": (corvo_carniceiro, 46, 32, 0.0, ("noite", "ouro", "sangue", "aco")),
    "galhudo": (galhudo, 62, 64, 0.0, ("couro", "folha", "musgo", "veneno")),
    "bruxa_do_mato": (bruxa_do_mato, 50, 60, 0.0, ("musgo", "folha", "pele", "noite", "couro", "veneno", "aco")),
    "velho_carvalho": (velho_carvalho, 116, 128, 0.0, ("couro", "folha", "musgo", "veneno", "sangue", "osso")),
}

monstros.rodar(INIMIGOS, mats, projeteis=(
    ("teia", 9, ["8c8470", "c9bfa6", "d6ccb2", "ece8f2"]),
    ("orbe_bruxa", 10, ["1d4a2a", "2f7a3a", "56b04a", "a6e070", "e4ffb0"]),
    ("esporo", 11, ["5c4320", "8f6a2e", "a6e070", "e4ffb0"]),
), rotulo="FLORESTA")

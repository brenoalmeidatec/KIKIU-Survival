"""Laboratório da v2: os objetos e o piso (veja mapas_v2.py). Cada função monta UM objeto com a origem no chão, no centro da pegada,
a frente voltada para -Y. Medidas em metros (1 m = 32 px na horizontal e 22,6 px na vertical). Tom: laboratório de contenção
abandonado, aço frio e concreto sujo, com os brilhos de líquido verde, tela ciano e lâmpada de emergência vermelha.
"""
import math

from mapas_v2 import B, C, E, M, barra, cilindro, caixa, esfera, metal, px3, vidro

# ------------------------------------------------------------------ cores
ACO = "5a6573"
ACO_ESC = "323a44"
ACO_CLARO = "8795a4"
CONCRETO = "666c74"
CONCRETO_ESC = "40454c"
PERIGO = "d2a824"
PRETO = "181a1f"
COBRE = "a9683e"
FERRUGEM = "845232"
BRANCO = "c4c8cc"
VERDE = "68e881"
CIANO = "5adcf2"
VERMELHO = "ec3b2e"
AZUL = "2b4d86"


def dim(w, d, h, extra_w=0.0, extra_h=0.0):
    """Tela do render (largura, altura, linha da origem) para um objeto w x d x h metros, com margem de 8 px."""
    larg = int(math.ceil((w + extra_w) * 32.0)) + 16
    larg += larg % 2
    alt_px = (h + extra_h + d) * 22.63
    alt = int(math.ceil(alt_px)) + 16
    pe_y = (h + extra_h + d / 2.0) * 22.63 + 8
    return larg, alt, pe_y


def tela(w, d, h, f, **kw):
    larg, alt, pe_y = dim(w, d, h, **kw)
    return (larg, alt, pe_y, f)


def faixas_perigo(x0, x1, y, z, alt, prof=0.02, passo=0.22):
    """Faixa de perigo: caixas amarelas e pretas alternadas ao longo de x."""
    amarelo, preto = M(PERIGO, 0.6, 0.1, 0.1), M(PRETO, 0.7)
    n = int(round((x1 - x0) / passo))
    for i in range(n):
        B(passo, prof, alt, x0 + passo * (i + 0.5), y, z, amarelo if i % 2 == 0 else preto, ch=0.0)


def led(x, y, z, cor, tam=0.05):
    B(tam, 0.03, tam, x, y, z, E(cor, 3.0), ch=0.0)


# ------------------------------------------------------------------ estrutura
def _parede_base(r, janela=False, quebrada=False):
    conc = M("7a828c", 0.9, 0.5, 0.18, 5.0)
    aco = metal("4a5562")
    painel = M("8d95a0", 0.8, 0.3, 0.12, 8.0)
    B(3.0, 0.5, 3.2, 0, 0, 0, conc, ch=0.03)
    # rodapé escuro com a faixa de perigo
    B(3.02, 0.06, 0.9, 0, -0.27, 0.0, M("5b626b", 0.85, 0.4, 0.2, 6.0), ch=0.02)
    faixas_perigo(-1.5, 1.5, -0.31, 0.42, 0.1)
    # painéis do alto, com juntas
    for i in range(3):
        B(0.9, 0.05, 1.2, -1.0 + i * 1.0, -0.275, 1.55, painel, ch=0.02)
    # fita de luz fria no alto do rodapé (só brilho no albedo: quem ilumina o chão é a luz do jogo)
    B(2.9 if not quebrada else 1.3, 0.03, 0.05, 0 if not quebrada else -0.8, -0.31, 0.97, E(CIANO, 1.3), ch=0.0)
    # tubos no topo
    barra((-1.5, -0.3, 3.0), (1.5, -0.3, 3.0), 0.1, metal(COBRE, 0.35))
    barra((-1.5, -0.3, 2.72), (1.5, -0.3, 2.72), 0.07, aco)
    for x in (-1.2, 0.0, 1.2):
        B(0.1, 0.08, 0.36, x, -0.3, 2.72, aco, ch=0.01)
    if janela:
        B(1.3, 0.07, 0.95, 0.15, -0.29, 1.6, aco, ch=0.02)
        B(1.15, 0.05, 0.8, 0.15, -0.325, 1.67, E(CIANO, 0.9), ch=0.0)
        for k in range(3):
            B(0.03, 0.04, 0.8, -0.2 + k * 0.35, -0.34, 1.67, aco, ch=0.0)
        B(1.15, 0.04, 0.03, 0.15, -0.34, 2.05, aco, ch=0.0)
    if quebrada:
        # buraco no painel: fundo escuro, canos expostos e fios soltos
        B(0.85, 0.06, 0.95, -0.35, -0.3, 1.4, M("0e1013", 1.0), ch=0.0)
        for k in range(3):
            barra((-0.7 + k * 0.28, -0.32, 1.35), (-0.62 + k * 0.28, -0.36, 2.25), 0.025, M(["a9683e", "c8a020", "3a60a8"][k], 0.5))
        led(-0.15, -0.34, 1.9, "ff9a3a", 0.07)
        for k in range(6):  # entulho no pé
            B(r.uniform(0.1, 0.22), r.uniform(0.1, 0.2), r.uniform(0.05, 0.15), -0.8 + r.uniform(0, 0.9), -0.45 - r.uniform(0, 0.12), 0.0,
              conc, ch=0.02, rot=(0, 0, r.uniform(0, 3)))


def parede_lab_a(r):
    _parede_base(r)


def parede_lab_b(r):
    _parede_base(r, janela=True)


def parede_lab_c(r):
    _parede_base(r, quebrada=True)


def pilar_lab(r):
    conc = M("7a828c", 0.9, 0.5, 0.18, 5.0)
    B(0.8, 0.8, 3.2, 0, 0, 0, conc, ch=0.04)
    B(0.92, 0.92, 0.2, 0, 0, 0.0, M(CONCRETO_ESC, 0.85, 0.3, 0.2), ch=0.02)
    B(0.92, 0.92, 0.18, 0, 0, 3.02, M(CONCRETO_ESC, 0.85, 0.3, 0.2), ch=0.02)
    amarelo, preto = M(PERIGO, 0.6, 0.1, 0.1), M(PRETO, 0.7)
    for i in range(8):
        B(0.82, 0.03, 0.11, 0, -0.41, 0.25 + i * 0.11, amarelo if i % 2 == 0 else preto, ch=0.0)
    for k in range(4):  # rachaduras
        B(0.03, 0.02, r.uniform(0.3, 0.7), r.uniform(-0.3, 0.3), -0.41, 1.4 + r.uniform(0, 1.2), M("22252a", 1.0), ch=0.0,
          rot=(0, r.uniform(-0.4, 0.4), 0))


# ------------------------------------------------------------------ equipamentos altos
def rack_servidores(r):
    aco = metal(ACO_ESC, 0.45)
    B(0.9, 0.8, 2.2, 0, 0, 0, aco, ch=0.02)
    B(0.84, 0.04, 2.08, 0, -0.41, 0.06, M("1b1e23", 0.6), ch=0.0)
    for i in range(9):
        z = 0.12 + i * 0.22
        B(0.76, 0.05, 0.17, 0, -0.43, z, metal("46505c", 0.4, 0.05, 0.05), ch=0.01)
        cor = r.choice([VERDE, VERDE, VERDE, VERMELHO, "ffb23a"])
        led(-0.28, -0.47, z + 0.07, cor)
        led(-0.18, -0.47, z + 0.07, VERDE if r.random() < 0.8 else VERMELHO)
        B(0.38, 0.02, 0.025, 0.12, -0.47, z + 0.04, M("15181c", 0.9), ch=0.0)
        B(0.38, 0.02, 0.025, 0.12, -0.47, z + 0.11, M("15181c", 0.9), ch=0.0)
    for k in range(3):  # cabos que sobem pelo lado
        barra((0.4 + k * 0.03, -0.38, 0.3), (0.42 + k * 0.03, -0.38, 2.28), 0.018, M(["1a1a1a", "a9683e", "3a60a8"][k], 0.5))


def armario_aco(r):
    aco = metal("66717e", 0.4, 0.2, 0.12)
    B(1.0, 0.6, 1.9, 0, 0, 0, aco, ch=0.03)
    for s in (-1, 1):
        B(0.46, 0.05, 1.7, s * 0.25, -0.32, 0.1, metal("73808d", 0.4, 0.15, 0.12), ch=0.015)
        for k in range(7):
            B(0.34, 0.03, 0.025, s * 0.25, -0.355, 1.38 + k * 0.045, M("20242a", 0.9), ch=0.0)
        B(0.04, 0.06, 0.2, s * 0.07, -0.36, 0.95, M(ACO_CLARO, 0.3), ch=0.01)
    B(0.28, 0.02, 0.18, -0.25, -0.345, 0.55, M(PERIGO, 0.6), ch=0.0)
    B(0.06, 0.04, 0.5, 0.45, -0.34, 0.5, M(FERRUGEM, 0.9, 0.3, 0.3), ch=0.0)


def tanque_alto(r):
    aco = metal(ACO_ESC, 0.4)
    C(0.82, 0.38, 0, 0, 0, aco, v=24, ch=0.02)
    for k in range(8):
        a = k * math.pi / 4
        C(0.05, 0.06, 0.74 * math.cos(a), 0.74 * math.sin(a), 0.38, M(ACO_CLARO, 0.3), v=8)
    C(0.64, 2.3, 0, 0, 0.38, vidro("2f6f74"), v=28)
    C(0.58, 2.2, 0, 0, 0.42, E("3fcf6a", 1.1), v=28)
    # vulto escuro boiando no líquido
    esfera("cabeca", 0.17, (0.02, -0.02, 1.95), M("0d2e1b", 0.9), escala=(1, 1, 1.15))
    esfera("tronco", 0.24, (0.0, 0.0, 1.45), M("0d2e1b", 0.9), escala=(1, 0.8, 1.6))
    barra((-0.2, 0, 1.6), (-0.42, -0.05, 1.05), 0.05, M("0d2e1b", 0.9))
    barra((0.2, 0, 1.6), (0.45, 0.03, 1.15), 0.05, M("0d2e1b", 0.9))
    for k in range(7):
        esfera("bolha", r.uniform(0.025, 0.05), (r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.2), 0.7 + r.uniform(0, 1.6)), E("b8ffc8", 2.0))
    C(0.76, 0.4, 0, 0, 2.62, aco, v=24, ch=0.02)
    C(0.16, 0.5, -0.3, 0, 3.0, metal(COBRE, 0.35), v=14)
    C(0.1, 0.5, 0.3, 0, 3.0, aco, v=12)
    B(0.3, 0.04, 0.2, 0, -0.78, 0.5, M("15181c", 0.9), ch=0.0)
    led(-0.08, -0.81, 0.62, VERDE)
    led(0.0, -0.81, 0.62, "ffb23a")
    led(0.08, -0.81, 0.62, VERMELHO)


def tanque_quebrado(r):
    aco = metal(ACO_ESC, 0.4)
    C(0.82, 0.38, 0, 0, 0, aco, v=24, ch=0.02)
    C(0.58, 0.05, 0, 0, 0.38, M("26422f", 0.5), v=28)   # resto do líquido seco no fundo
    for k in range(10):
        a = r.uniform(0, 2 * math.pi)
        alt = r.uniform(0.3, 1.9)
        B(0.14, 0.02, alt, 0.6 * math.cos(a), 0.6 * math.sin(a), 0.4, vidro("4a8a90"), ch=0.0, rot=(0, 0, a + math.pi / 2))
    for k in range(6):  # cacos no chão em volta
        B(r.uniform(0.08, 0.2), r.uniform(0.05, 0.12), 0.02, r.uniform(-0.9, 0.9), -r.uniform(0.5, 0.9), 0.0, vidro("7bc6cc"), ch=0.0,
          rot=(0, 0, r.uniform(0, 3)))
    C(0.76, 0.4, 0, 0, 2.62, aco, v=24, ch=0.02)
    barra((0.1, 0, 2.62), (0.25, -0.1, 1.5), 0.02, M("1a1a1a", 0.5))   # cabo solto
    C(0.16, 0.5, -0.3, 0, 3.0, metal(COBRE, 0.35), v=14)
    esfera("gosma", 0.2, (0.0, 0.0, 0.5), E("2fa855", 0.6), escala=(1, 1, 0.3))
    led(0.0, -0.81, 0.62, VERMELHO)


def capsula_cripto(r):
    aco = metal(ACO_ESC, 0.4)
    B(1.0, 2.0, 0.5, 0, 0, 0, aco, ch=0.03)
    B(0.8, 1.7, 0.1, 0, 0, 0.5, metal(ACO, 0.4), ch=0.02)
    barra((0, -0.8, 0.82), (0, 0.8, 0.82), 0.4, vidro("3a7f8a"), v=24)
    barra((0, -0.74, 0.82), (0, 0.74, 0.82), 0.33, E("7de8ff", 0.55), v=24)
    for y in (-0.82, 0.82):
        barra((0, y, 0.82), (0, y + (0.1 if y > 0 else -0.1), 0.82), 0.43, aco, v=24)
    B(0.5, 0.05, 0.22, 0, -1.02, 0.18, M("15181c", 0.9), ch=0.0)
    led(-0.12, -1.06, 0.3, VERDE)
    led(0.0, -1.06, 0.3, CIANO)
    led(0.12, -1.06, 0.3, VERMELHO)
    for k in range(3):  # tubulação até o chão
        barra((-0.4 + k * 0.4, 0.9, 0.4), (-0.4 + k * 0.4, 1.2, 0.05), 0.04, M(["3a60a8", "a9683e", "1a1a1a"][k], 0.5))


def gerador(r):
    aco = metal("4e5a68", 0.4, 0.2, 0.12)
    B(2.0, 1.4, 1.2, 0, 0, 0.25, aco, ch=0.04)
    B(2.1, 1.5, 0.25, 0, 0, 0.0, metal(ACO_ESC), ch=0.03)
    faixas_perigo(-1.0, 1.0, -0.72, 0.3, 0.14)
    for k in range(7):  # grade de ventilação
        B(0.55, 0.03, 0.04, -0.55, -0.72, 0.62 + k * 0.08, M("14171b", 0.9), ch=0.0)
    for s in (0, 1):
        x = 0.35 + s * 0.4
        C(0.15, 0.1, x, -0.74, 0.95, M("e8e8e8", 0.4), v=18, rot=(math.pi / 2, 0, 0))
        barra((x, -0.8, 0.95), (x + 0.05 * (1 if s else -1), -0.8, 1.05), 0.012, E(VERMELHO, 2.0), v=6)
    C(0.2, 1.0, -0.6, 0.3, 1.45, metal(ACO_ESC), v=16)
    C(0.15, 0.8, 0.0, 0.3, 1.45, metal(ACO_ESC), v=16)
    C(0.25, 0.08, -0.6, 0.3, 2.43, metal(ACO_ESC), v=16)
    C(0.1, 0.18, 0.7, 0.35, 1.45, E("ff9a3a", 2.4), v=12)
    barra((0.9, 0.2, 0.5), (1.2, 0.3, 0.1), 0.06, M("1a1a1a", 0.6))


def cano_grosso(r):
    cobre = metal(COBRE, 0.35, 0.12, 0.12)
    aco = metal(ACO, 0.4)
    C(0.3, 3.0, 0, 0, 0, aco, v=24)
    for z in (0.15, 1.2, 2.2, 2.85):
        C(0.38, 0.16, 0, 0, z, metal(ACO_ESC), v=24, ch=0.01)
        for k in range(6):
            a = k * math.pi / 3
            C(0.03, 0.2, 0.34 * math.cos(a), 0.34 * math.sin(a), z - 0.02, M(ACO_CLARO, 0.3), v=6)
    barra((0, -0.1, 1.6), (0.8, -0.1, 1.6), 0.14, cobre)
    C(0.2, 0.05, 0.8, -0.1, 1.45, metal(ACO_ESC), v=16, rot=(0, math.pi / 2, 0))
    barra((0, -0.38, 1.0), (0, -0.55, 1.0), 0.03, M(VERMELHO, 0.5))
    cilindro("volante", 0.16, 0.03, (0, -0.58, 1.0), M(VERMELHO, 0.5), vertices=16, rot=(math.pi / 2, 0, 0))
    for k in range(4):
        a = k * math.pi / 4
        barra((-0.16 * math.cos(a), -0.58, 1.0 - 0.16 * math.sin(a)), (0.16 * math.cos(a), -0.58, 1.0 + 0.16 * math.sin(a)), 0.012,
              M(VERMELHO, 0.5), v=6)


# ------------------------------------------------------------------ mobília e baixos
def mesa_lab(r):
    aco = metal(ACO_CLARO, 0.35)
    for x in (-0.72, 0.72):
        for y in (-0.32, 0.32):
            B(0.07, 0.07, 0.85, x, y, 0, metal(ACO_ESC), ch=0.01)
    B(1.7, 0.85, 0.07, 0, 0, 0.85, M("69737d", 0.4, 0.1, 0.1), ch=0.015)
    B(1.5, 0.65, 0.05, 0, 0, 0.3, aco, ch=0.01)
    for i, (x, cor) in enumerate([(-0.5, VERDE), (-0.28, "b24cff"), (0.5, "ffb23a")]):
        C(0.08, 0.2, x, 0.0, 0.92, vidro("5f9aa0"), v=12)
        C(0.065, 0.12, x, 0.0, 0.93, E(cor, 1.6), v=12)
    esfera("balao", 0.14, (0.05, 0.1, 1.08), E("5adcf2", 1.2))
    C(0.04, 0.2, 0.05, 0.1, 1.15, vidro("5f9aa0"), v=10)
    B(0.4, 0.3, 0.02, 0.2, -0.15, 0.92, M(BRANCO, 0.9), ch=0.0, rot=(0, 0, 0.3))
    B(0.2, 0.16, 0.3, -0.1, 0.18, 0.92, metal("2a3138"), ch=0.01)
    C(0.05, 0.12, -0.1, 0.1, 1.2, metal(ACO_CLARO), v=10)


def bancada_lab(r):
    corpo = metal("535e6b", 0.45, 0.15, 0.12)
    B(3.0, 0.9, 0.95, 0, 0, 0.0, corpo, ch=0.03)
    B(3.06, 0.96, 0.08, 0, 0, 0.95, M("2a3036", 0.35, 0.1, 0.1), ch=0.02)
    for i in range(4):
        B(0.62, 0.04, 0.78, -1.1 + i * 0.73, -0.47, 0.08, metal("63707d", 0.4, 0.1, 0.1), ch=0.015)
        B(0.04, 0.05, 0.2, -1.1 + i * 0.73 + 0.22, -0.5, 0.4, M(ACO_CLARO, 0.3), ch=0.01)
    # pia, centrífuga e tubos
    B(0.7, 0.5, 0.05, -0.9, 0.0, 1.03, M(ACO_CLARO, 0.3), ch=0.01)
    barra((-0.9, 0.2, 1.05), (-0.9, 0.2, 1.4), 0.03, M(ACO_CLARO, 0.3))
    barra((-0.9, 0.2, 1.4), (-0.9, 0.0, 1.4), 0.03, M(ACO_CLARO, 0.3))
    C(0.28, 0.3, 0.2, 0.0, 1.03, metal("3b4550"), v=20)
    C(0.22, 0.05, 0.2, 0.0, 1.33, E("ff9a3a", 1.3), v=20)
    for k in range(6):
        C(0.035, 0.22, 0.85 + k * 0.1, 0.1, 1.03, vidro("5f9aa0"), v=8)
        C(0.027, 0.12, 0.85 + k * 0.1, 0.1, 1.04, E(r.choice([VERDE, CIANO, "b24cff"]), 1.8), v=8)
    B(0.5, 0.05, 0.38, 1.25, 0.2, 1.03, M("15181c", 0.6), ch=0.01)
    B(0.44, 0.03, 0.3, 1.25, 0.17, 1.07, E(CIANO, 0.9), ch=0.0)


def console(r, quebrado=False):
    aco = metal("49535f", 0.4, 0.15, 0.1)
    B(1.2, 0.75, 0.8, 0, 0, 0, aco, ch=0.03)
    B(1.26, 0.8, 0.06, 0, 0, 0.8, metal(ACO_ESC), ch=0.02)
    B(1.1, 0.5, 0.06, 0, -0.1, 0.9, metal(ACO_ESC), ch=0.02, rot=(0.35, 0, 0))
    for i in range(7):
        for j in range(2):
            B(0.1, 0.1, 0.03, -0.45 + i * 0.15, -0.16 - j * 0.12, 0.98 - j * 0.06 + 0.05, M(["a8b0b8", "33383f"][(i + j) % 2], 0.5), ch=0.0,
              rot=(0.35, 0, 0))
    for k in range(3):
        led(0.45 + 0.1 * k, -0.34, 1.0, [VERDE, "ffb23a", VERMELHO][k], 0.04)
    B(1.0, 0.08, 0.62, 0, 0.25, 0.98, metal("22272e"), ch=0.02, rot=(-0.12, 0, 0))
    if quebrado:
        B(0.88, 0.04, 0.5, 0, 0.19, 1.04, M("101215", 0.3), ch=0.0, rot=(-0.12, 0, 0))
        barra((-0.4, 0.17, 1.55), (0.4, 0.17, 1.1), 0.012, E("e8f6ff", 2.4), v=6)
        barra((0.1, 0.17, 1.55), (0.3, 0.17, 1.2), 0.01, E("e8f6ff", 2.4), v=6)
        for k in range(5):
            esfera("fagulha", 0.025, (r.uniform(-0.5, 0.5), 0.1, 1.4 + r.uniform(0, 0.4)), E("ffb23a", 3.0))
        barra((0.55, 0.3, 1.0), (0.7, 0.1, 0.3), 0.02, M("1a1a1a", 0.5))
    else:
        B(0.88, 0.04, 0.5, 0, 0.19, 1.04, E(CIANO, 0.85), ch=0.0, rot=(-0.12, 0, 0))
        for k in range(5):
            B(0.5 - 0.06 * k, 0.02, 0.025, -0.1 - 0.03 * k, 0.17, 1.4 - k * 0.08, E("e8fbff", 1.4), ch=0.0, rot=(-0.12, 0, 0))
    B(0.2, 0.2, 0.05, 0, 0.35, 0.8, aco, ch=0.01)


def console_quebrado(r):
    console(r, quebrado=True)


def caixa_suprimentos(r):
    cor = r.choice(["4b5a4a", "5a5444", "46525f"])
    B(1.0, 1.0, 0.78, 0, 0, 0.0, M(cor, 0.8, 0.3, 0.15, 7.0), ch=0.04)
    B(1.06, 1.06, 0.1, 0, 0, 0.7, M("2c3238", 0.7, 0.1, 0.1), ch=0.03)
    for s in (-1, 1):
        B(0.1, 0.04, 0.2, s * 0.3, -0.52, 0.45, metal(ACO_CLARO), ch=0.01)
    B(0.55, 0.02, 0.18, 0, -0.51, 0.25, M(PERIGO, 0.6), ch=0.0)
    B(0.3, 0.02, 0.06, 0, -0.52, 0.31, M(PRETO, 0.7), ch=0.0)


def caixa_empilhada(r):
    cores = ["4b5a4a", "5a5444", "46525f"]
    for i, (x, y, z, s, rot) in enumerate([(0, 0, 0, 1.05, 0), (0.05, 0.02, 0.8, 0.95, 0.12)]):
        cor = cores[i % 3]
        B(s, s, 0.78, x, y, z, M(cor, 0.8, 0.3, 0.15, 7.0), ch=0.04, rot=(0, 0, rot))
        B(s + 0.06, s + 0.06, 0.1, x, y, z + 0.7, M("2c3238", 0.7, 0.1, 0.1), ch=0.03, rot=(0, 0, rot))
    B(0.6, 0.02, 0.18, 0.03, -0.54, 0.3, M(PERIGO, 0.6), ch=0.0)
    B(0.5, 0.45, 0.4, -0.3, -0.1, 1.65, M("6a5f4a", 0.9, 0.3, 0.2), ch=0.02, rot=(0, 0, 0.5))


def barril_toxico(r):
    verde = M("3f6f45", 0.55, 0.15, 0.2, 8.0)
    C(0.34, 0.95, 0, 0, 0, verde, v=24, ch=0.01)
    for z in (0.12, 0.47, 0.8):
        C(0.355, 0.05, 0, 0, z, metal(ACO_ESC), v=24)
    C(0.3, 0.04, 0, 0, 0.95, metal(ACO_ESC), v=20)
    B(0.3, 0.02, 0.24, 0, -0.35, 0.36, M(PERIGO, 0.6), ch=0.0)
    cilindro("trevo", 0.08, 0.02, (0, -0.37, 0.48), M(PRETO, 0.7), vertices=3, rot=(math.pi / 2, 0, 0))
    B(0.03, 0.03, 0.35, 0.18, -0.36, 0.0, E("5bf07a", 1.5), ch=0.0)
    esfera("pingo", 0.05, (0.18, -0.38, 0.03), E("5bf07a", 2.0), escala=(1.2, 1, 0.5))


def maca(r):
    aco = metal(ACO_CLARO, 0.35)
    for x in (-0.38, 0.38):
        for y in (-0.8, 0.8):
            B(0.05, 0.05, 0.55, x, y, 0.1, aco, ch=0.005)
            cilindro("roda", 0.07, 0.04, (x, y, 0.07), M(PRETO, 0.8), vertices=12, rot=(0, math.pi / 2, 0))
    B(0.82, 1.9, 0.07, 0, 0, 0.6, aco, ch=0.015)
    B(0.74, 1.8, 0.09, 0, 0, 0.67, M("8a8f94", 0.95), ch=0.04)
    B(0.62, 1.0, 0.04, 0, -0.1, 0.76, M("a9aaa0", 0.95, 0.3, 0.3), ch=0.02, rot=(0, 0, 0.04))   # lençol com mancha
    B(0.2, 0.2, 0.01, 0.05, -0.3, 0.8, M("5c1d1d", 0.9), ch=0.0)
    for y in (-0.15, 0.2):
        B(0.78, 0.07, 0.03, 0, y, 0.78, M("3a3028", 0.9), ch=0.0)
    B(0.5, 0.35, 0.12, 0, 0.7, 0.76, M("77797a", 0.95), ch=0.04)


def gaiola(r):
    aco = metal(ACO_ESC, 0.45)
    B(1.3, 1.0, 0.1, 0, 0, 0.0, aco, ch=0.02)
    B(1.3, 1.0, 0.08, 0, 0, 1.32, aco, ch=0.02)
    B(1.2, 0.9, 0.04, 0, 0, 0.1, M("141619", 0.9), ch=0.0)
    for i in range(11):
        x = -0.6 + i * 0.12
        C(0.012, 1.22, x, -0.48, 0.1, metal(ACO), v=6)
        C(0.012, 1.22, x, 0.48, 0.1, metal(ACO), v=6)
    for k in range(7):
        y = -0.4 + k * 0.133
        C(0.012, 1.22, -0.62, y, 0.1, metal(ACO), v=6)
        C(0.012, 1.22, 0.62, y, 0.1, metal(ACO), v=6)
    barra((-0.6, -0.48, 0.7), (0.6, -0.48, 0.7), 0.014, metal(ACO), v=6)
    esfera("tigela", 0.12, (0.3, 0.1, 0.2), M("6b5f4f", 0.8), escala=(1, 1, 0.4))
    B(0.2, 0.05, 0.1, -0.5, -0.5, 0.45, M(FERRUGEM, 0.9), ch=0.0)


def lampada_emergencia(r):
    aco = metal(ACO_ESC, 0.4)
    C(0.18, 0.12, 0, 0, 0, aco, v=16, ch=0.01)
    C(0.04, 1.9, 0, 0, 0.1, aco, v=10)
    B(0.34, 0.34, 0.1, 0, 0, 2.0, aco, ch=0.02)
    C(0.15, 0.3, 0, 0, 2.1, E("ff4a3c", 3.2), v=16)
    for k in range(6):
        a = k * math.pi / 3
        C(0.012, 0.32, 0.17 * math.cos(a), 0.17 * math.sin(a), 2.09, aco, v=6)
    C(0.17, 0.04, 0, 0, 2.42, aco, v=16)


def cacos_vidro(r):
    for k in range(12):
        B(r.uniform(0.08, 0.22), r.uniform(0.05, 0.14), 0.03, r.uniform(-0.45, 0.45), r.uniform(-0.3, 0.3), 0.0, vidro(r.choice(["6fb6bd", "9ad8de"])),
          ch=0.0, rot=(r.uniform(-0.2, 0.2), r.uniform(-0.2, 0.2), r.uniform(0, 3)))


def lixo_lab(r):
    for k in range(9):
        B(r.uniform(0.12, 0.28), r.uniform(0.1, 0.22), r.uniform(0.02, 0.07), r.uniform(-0.45, 0.45), r.uniform(-0.3, 0.3), 0.0,
          M(r.choice([BRANCO, "9a9e92", "b0a98a"]), 0.95), ch=0.01, rot=(0, 0, r.uniform(0, 3)))
    B(0.3, 0.3, 0.35, 0.3, 0.1, 0.0, metal(ACO_ESC), ch=0.02, rot=(0.1, 0.4, 0.2))


def restos_cobaia(r):
    """Restos de uma cobaia: carcaça rasa numa poça de gosma, com costelas, coluna, caveira e rabo (antes era uma bola com quatro pernas e
    parecia tartaruga). Deitada ao longo de x, a caveira para a direita."""
    carne = M("7a5a5e", 0.8, 0.3, 0.35, 9.0)
    osso = M("cbc4b0", 0.7, 0.1, 0.15, 12.0)
    escuro = M("26181b", 0.9)
    esfera("gosma", 0.6, (0.0, 0.05, 0.01), E("2fa855", 0.32), escala=(1.45, 1.0, 0.04))
    esfera("sangue", 0.3, (-0.2, -0.3, 0.012), M("5a1414", 0.4), escala=(1.4, 0.8, 0.03))
    # só a parte de trás ainda tem carne; o peito está aberto e mostra as costelas
    esfera("quadril", 0.26, (-0.42, 0.02, 0.1), carne, escala=(1.25, 0.95, 0.5))
    esfera("pelo", 0.18, (-0.62, 0.1, 0.07), M("4a3a3e", 0.9, 0.2, 0.4), escala=(1.3, 1.0, 0.5))
    barra((-0.5, 0.0, 0.1), (0.38, 0.0, 0.1), 0.035, osso, v=8)  # coluna
    for xi in (-0.2, -0.02, 0.16):
        for s in (-1, 1):
            barra((xi, s * 0.03, 0.1), (xi - 0.02, s * 0.2, 0.2), 0.034, osso, v=8)  # costela: sobe e abre
            barra((xi - 0.02, s * 0.2, 0.2), (xi - 0.06, s * 0.3, 0.07), 0.03, osso, v=8)  # e desce de volta ao chão
    esfera("peito", 0.15, (-0.04, 0.0, 0.06), escuro, escala=(2.1, 0.8, 0.3))  # cavidade escura entre as costelas
    # caveira de focinho comprido (roedor) com os olhos ainda acesos
    esfera("cranio", 0.12, (0.5, 0.0, 0.11), osso, escala=(1.0, 0.85, 0.85))
    esfera("focinho", 0.08, (0.64, 0.02, 0.08), osso, escala=(1.4, 0.8, 0.7))
    for s in (-1, 1):
        esfera("olho", 0.035, (0.52, s * 0.07, 0.17), E("c8ff6a", 2.6))
    # rabo comprido e fino, dobrado no chão
    barra((-0.82, 0.12, 0.05), (-1.0, 0.3, 0.03), 0.032, carne, v=6)
    barra((-1.0, 0.3, 0.03), (-0.88, 0.52, 0.025), 0.026, carne, v=6)
    # ossos soltos e um pedaço de jaleco
    for x, y, a in [(0.1, 0.38, 0.4), (-0.3, -0.42, 2.0), (0.38, -0.34, 1.1)]:
        B(0.2, 0.045, 0.045, x, y, 0.02, osso, ch=0.01, rot=(0, 0, a))
    B(0.34, 0.26, 0.025, 0.15, -0.18, 0.015, M("b8bcc0", 0.95), ch=0.0, rot=(0, 0, 0.3))


def porta_blindada(r):
    """Trecho de parede com porta blindada (variedade para a parede dos fundos): moldura de faixa de perigo, folha de aço com nervuras, volante e luz de status."""
    _parede_base(r)
    aco = metal("65727f", 0.4, 0.2, 0.12)
    claro = metal(ACO_CLARO, 0.35)
    amarelo, preto = M(PERIGO, 0.6, 0.1, 0.1), M(PRETO, 0.7)
    B(1.9, 0.07, 2.5, 0, -0.31, 0.0, M("14171b", 0.8), ch=0.01)  # vão escuro
    for i in range(11):  # moldura em listras de perigo (cima)
        B(0.17, 0.05, 0.12, -0.85 + i * 0.17, -0.355, 2.38, amarelo if i % 2 == 0 else preto, ch=0.0)
    for s in (-1, 1):
        for i in range(12):
            B(0.1, 0.05, 0.2, s * 0.93, -0.355, 0.0 + i * 0.2, amarelo if i % 2 == 0 else preto, ch=0.0)
    B(1.64, 0.1, 2.28, 0, -0.38, 0.04, aco, ch=0.02)  # folha da porta
    for k in range(5):  # nervuras horizontais
        B(1.5, 0.03, 0.05, 0, -0.45, 0.35 + k * 0.42, M("39424c", 0.6, 0.1, 0.1), ch=0.0)
    B(0.08, 0.04, 2.2, 0, -0.45, 0.06, M("39424c", 0.6), ch=0.0)  # junta do meio
    cilindro("volante", 0.2, 0.05, (0.45, -0.46, 1.1), claro, vertices=16, rot=(math.pi / 2, 0, 0))
    for a in range(4):
        barra((0.45, -0.46, 1.1), (0.45 + 0.2 * math.cos(a * math.pi / 2 + 0.4), -0.46, 1.1 + 0.2 * math.sin(a * math.pi / 2 + 0.4)), 0.02, claro, v=6)
    B(0.34, 0.05, 0.62, -0.5, -0.45, 1.5, M("15181c", 0.9), ch=0.0)  # painel de status
    led(-0.6, -0.49, 1.95, VERMELHO, 0.09)
    led(-0.4, -0.49, 1.95, "ffb23a", 0.07)
    B(0.26, 0.02, 0.18, -0.5, -0.485, 1.55, E(CIANO, 1.1), ch=0.0)


def duto_ventilacao(r):
    """Unidade de ventilação alta: caixa de aço com veneziana no alto, ventoinha embaixo e dutos que saem pelo topo e pelo lado."""
    aco = metal("5a6573", 0.4, 0.2, 0.12)
    escuro = M("15181c", 0.9)
    B(1.1, 0.8, 2.1, 0, 0, 0, aco, ch=0.03)
    B(1.16, 0.86, 0.1, 0, 0, 0.0, M(CONCRETO_ESC, 0.85), ch=0.02)
    B(0.9, 0.04, 0.62, 0, -0.42, 1.28, escuro, ch=0.0)  # abertura da veneziana
    for k in range(7):
        B(0.9, 0.05, 0.035, 0, -0.45, 1.3 + k * 0.085, metal(ACO_CLARO, 0.35), ch=0.0, rot=(0.35, 0, 0))
    cilindro("aro", 0.36, 0.06, (0, -0.43, 0.6), metal(ACO_ESC, 0.4), vertices=24, rot=(math.pi / 2, 0, 0))
    cilindro("ventoinha", 0.3, 0.04, (0, -0.46, 0.6), escuro, vertices=24, rot=(math.pi / 2, 0, 0))
    for k in range(5):  # pás
        a = k * 2 * math.pi / 5 + 0.3
        barra((0, -0.49, 0.6), (0.26 * math.cos(a), -0.49, 0.6 + 0.26 * math.sin(a)), 0.035, metal("46505c", 0.4), v=6)
    cilindro("cubo", 0.06, 0.06, (0, -0.5, 0.6), metal(ACO_CLARO, 0.3), vertices=12, rot=(math.pi / 2, 0, 0))
    C(0.3, 0.5, 0.0, 0.0, 2.1, metal("6a7580", 0.4), v=20)  # duto que sobe
    barra((0.0, 0.0, 2.45), (0.5, 0.0, 2.45), 0.2, metal("6a7580", 0.4), v=16)  # e dobra para o lado
    for x in (0.2, 0.38):
        C(0.23, 0.05, x, 0.0, 2.45, metal(ACO_ESC, 0.4), v=16, rot=(0, math.pi / 2, 0))
    led(0.38, -0.43, 0.2, "ffb23a", 0.07)
    led(0.38, -0.43, 0.33, VERDE, 0.06)
    B(0.3, 0.02, 0.2, -0.33, -0.43, 0.15, M(PERIGO, 0.6), ch=0.0)


def estante_amostras(r):
    """Estante de aço com frascos de amostra: alguns acesos de verde e âmbar (luz fraca no albedo, só o brilho do vidro)."""
    aco = metal("4f5a66", 0.4, 0.2, 0.1)
    for x in (-0.86, 0.86):
        for y in (-0.25, 0.25):
            B(0.07, 0.07, 2.05, x, y, 0.0, aco, ch=0.01)
    B(1.78, 0.58, 0.06, 0, 0, 0.0, M("262d35", 0.7), ch=0.01)
    for z in (0.5, 0.98, 1.46, 1.94):
        B(1.78, 0.58, 0.05, 0, 0, z, metal("66717e", 0.35), ch=0.01)
    B(1.74, 0.04, 2.0, 0, 0.29, 0.05, M("1b1f24", 0.9), ch=0.0)  # fundo
    cores = [("3fcf6a", 1.2), ("ffb23a", 1.0), ("7de8ff", 0.9), (None, 0), ("3fcf6a", 0.9)]
    for nivel, z in enumerate((0.06, 0.55, 1.03, 1.51)):
        x = -0.72
        while x < 0.75:
            tipo = r.random()
            if tipo < 0.6:
                c, f = r.choice(cores)
                h = r.uniform(0.2, 0.34)
                C(0.085, h, x, r.uniform(-0.1, 0.1), z, vidro("6fb6bd") if c is None else E(c, f), v=14)
                C(0.09, 0.03, x, 0.0, z + h, metal(ACO_ESC), v=14)
                x += 0.2
            elif tipo < 0.85:
                B(r.uniform(0.22, 0.34), 0.28, r.uniform(0.14, 0.26), x + 0.1, 0.0, z, M(r.choice(["4b5a4a", "5a5444", "46525f"]), 0.8, 0.2, 0.15), ch=0.02)
                x += 0.38
            else:
                x += 0.22  # vão
    B(0.5, 0.02, 0.12, 0.0, -0.3, 0.52, M(PERIGO, 0.6), ch=0.0)


OBJETOS = {
    "parede_lab_a": tela(3.0, 0.5, 3.2, parede_lab_a, extra_h=0.35),
    "parede_lab_b": tela(3.0, 0.5, 3.2, parede_lab_b, extra_h=0.35),
    "parede_lab_c": tela(3.0, 0.5, 3.2, parede_lab_c, extra_h=0.35),
    "pilar_lab": tela(0.95, 0.95, 3.2, pilar_lab),
    "rack_servidores": tela(0.95, 0.85, 2.3, rack_servidores),
    "armario_aco": tela(1.05, 0.65, 1.95, armario_aco),
    "tanque_alto": tela(1.7, 1.7, 3.1, tanque_alto, extra_h=0.6),
    "tanque_quebrado": tela(1.7, 1.7, 3.1, tanque_quebrado, extra_h=0.6),
    "capsula_cripto": tela(1.1, 2.4, 1.2, capsula_cripto),
    "gerador": tela(2.2, 1.6, 2.5, gerador),
    "cano_grosso": tela(1.4, 1.0, 3.1, cano_grosso),
    "mesa_lab": tela(1.8, 0.9, 1.6, mesa_lab),
    "bancada_lab": tela(3.1, 1.0, 1.8, bancada_lab),
    "console": tela(1.3, 0.9, 1.7, console),
    "console_quebrado": tela(1.3, 0.9, 1.8, console_quebrado),
    "caixa_suprimentos": tela(1.1, 1.1, 0.85, caixa_suprimentos),
    "caixa_empilhada": tela(1.2, 1.2, 2.1, caixa_empilhada),
    "barril_toxico": tela(0.8, 0.8, 1.0, barril_toxico),
    "maca": tela(0.95, 2.1, 1.0, maca),
    "gaiola": tela(1.4, 1.1, 1.5, gaiola),
    "lampada_emergencia": tela(0.6, 0.6, 2.5, lampada_emergencia),
    "cacos_vidro": tela(1.0, 0.7, 0.15, cacos_vidro),
    "lixo_lab": tela(1.1, 0.8, 0.4, lixo_lab),
    "restos_cobaia": tela(2.3, 1.3, 0.5, restos_cobaia),
    "porta_blindada": tela(3.0, 0.5, 3.2, porta_blindada, extra_h=0.35),
    "duto_ventilacao": tela(1.2, 0.9, 2.75, duto_ventilacao),
    "estante_amostras": tela(1.8, 0.65, 2.1, estante_amostras),
}


# ------------------------------------------------------------------ piso: placas de aço de 1 m, 16 m de lado
def piso_lab(r):
    N = 16
    rejunte = M("0d0f12", 1.0)
    B(N, N, 0.1, N / 2.0, N / 2.0, -0.1, rejunte, ch=0.0)
    tons = [metal(h, 0.5, 0.35, 0.22, 6.0) for h in ("4a535e", "444d58", "505a66", "3e4752")]
    grade = M("14171b", 0.9, 0.2)
    perigo_a, perigo_p = M(PERIGO, 0.6, 0.2, 0.18), M(PRETO, 0.7)
    especiais = {}
    for _ in range(9):
        especiais[(r.randrange(N), r.randrange(N))] = "grade"
    for _ in range(4):
        especiais[(r.randrange(N), r.randrange(N))] = "perigo"
    for i in range(N):
        for j in range(N):
            alt = 0.06 + r.random() * 0.012
            tipo = especiais.get((i, j))
            B(0.96, 0.96, alt, i + 0.5, j + 0.5, 0.0, tons[(i // 2 + j // 2 + r.randrange(2)) % 4] if tipo != "grade" else grade, ch=0.02)
            if tipo == "grade":
                for k in range(6):
                    B(0.84, 0.05, 0.03, i + 0.5, j + 0.14 + k * 0.145, alt, M("2c333b", 0.5, 0.3), ch=0.005)
            elif tipo == "perigo":
                for k in range(5):
                    B(0.96, 0.09, 0.012, i + 0.5, j + 0.12 + k * 0.19, alt, perigo_a if k % 2 == 0 else perigo_p, ch=0.0)
            else:
                for dx in (0.12, 0.88):
                    for dy in (0.12, 0.88):
                        cilindro("parafuso", 0.025, 0.02, (i + dx, j + dy, alt + 0.01), M("2a3038", 0.4), vertices=8)
                if r.random() < 0.18:   # mancha escura de óleo
                    cilindro("mancha", r.uniform(0.15, 0.35), 0.004, (i + r.uniform(0.2, 0.8), j + r.uniform(0.2, 0.8), alt + 0.004),
                             M("15181c", 0.4), vertices=14)


PISO = (16, piso_lab)

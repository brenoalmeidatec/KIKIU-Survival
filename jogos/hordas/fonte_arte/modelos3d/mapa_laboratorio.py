"""Torre do Alquimista da v2 (id interno "laboratorio"): os objetos e o piso (veja mapas_v2.py, que lê OBJETOS e PISO daqui). Cada função monta UM
objeto com a origem no chão, no centro da pegada, a frente voltada para -Y. Medidas em metros (1 m = 32 px na horizontal e 22,6 px na vertical).
Tom: dark fantasy, uma torre de pedra e madeira escura com bancadas de alquimia, alambiques de cobre, estantes de grimórios, frascos que brilham
(verde, azul-arcano, âmbar) e círculos rúnicos no piso. O que era "laboratório de contenção" (aço, concreto, faixa de perigo, LED, tela) saiu inteiro
(#429). Os NOMES dos objetos e as medidas (OBJETOS, no fim) são os de antes: a planta, a colisão e as passagens não mudam, só a roupa.
"""
import math

from mapas_v2 import B, C, E, M, barra, cilindro, caixa, esfera, metal, px3, vidro

# ------------------------------------------------------------------ cores
PEDRA = "6d6862"
PEDRA_ESC = "413d3a"
PEDRA_CLARA = "8a847b"
MADEIRA = "6a4a2f"
MADEIRA_ESC = "3f2b1b"
MADEIRA_CLARA = "8c6a45"
COBRE = "b0693a"
LATAO = "c9a24a"
FERRO = "3a3d42"
PERGAMINHO = "d8c9a0"
VERDE = "5fe08a"
AZUL = "58b8ff"
ROXO = "a678f0"
AMBAR = "ffb23a"
VERMELHO = "e0453a"
CERA = "e8dcc0"


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


# ------------------------------------------------------------------ materiais e peças pequenas
def pedra(c=PEDRA):
    return M(c, 0.92, 0.7, 0.24, 6.0)


def madeira(c=MADEIRA):
    return M(c, 0.85, 0.5, 0.3, 14.0)


def cobre():
    return metal(COBRE, 0.38, 0.12, 0.12, 10.0)


def latao():
    return metal(LATAO, 0.35, 0.1, 0.1, 10.0)


def ferro():
    return metal(FERRO, 0.5, 0.2, 0.14, 8.0)


def frasco(x, y, z, cor, h=0.24, r=0.065, forca=1.6):
    """Frasco com o líquido aceso: corpo de vidro, miolo emissivo, gargalo e rolha."""
    C(r, h * 0.7, x, y, z, vidro("5f8f90"), v=12)
    C(r * 0.82, h * 0.62, x, y, z + 0.02, E(cor, forca), v=12)
    C(r * 0.38, h * 0.3, x, y, z + h * 0.7, vidro("5f8f90"), v=8)
    C(r * 0.4, 0.04, x, y, z + h, madeira(MADEIRA_CLARA), v=8)


def vela(x, y, z, h=0.16):
    C(0.03, h, x, y, z, M(CERA, 0.8), v=8)
    esfera("chama", 0.028, (x, y, z + h + 0.03), E("ffb04a", 3.0), escala=(0.8, 0.8, 1.5))


def livro(x, y, z, c, w=0.2, d=0.15, h=0.04, rot=0.0):
    B(w, d, h, x, y, z, M(c, 0.8, 0.3, 0.2), ch=0.01, rot=(0, 0, rot))
    B(w * 0.96, d * 0.92, h * 0.55, x, y, z + h * 0.2, M(PERGAMINHO, 0.9), ch=0.0, rot=(0, 0, rot))


def alambique(x, y, z, esc=1.0, brilho=VERDE):
    """Alambique: bojo de cobre, pescoço, cabeça e o cano que dobra; o líquido acende no bojo."""
    esfera("bojo", 0.2 * esc, (x, y, z + 0.2 * esc), cobre(), escala=(1, 1, 0.95))
    esfera("agua", 0.14 * esc, (x, y - 0.04 * esc, z + 0.18 * esc), E(brilho, 1.4))
    C(0.07 * esc, 0.22 * esc, x, y, z + 0.38 * esc, cobre(), v=12)
    esfera("cabeca", 0.09 * esc, (x, y, z + 0.64 * esc), cobre())
    barra((x, y, z + 0.66 * esc), (x + 0.28 * esc, y, z + 0.54 * esc), 0.03 * esc, cobre(), v=8)
    barra((x + 0.28 * esc, y, z + 0.54 * esc), (x + 0.28 * esc, y, z + 0.22 * esc), 0.03 * esc, cobre(), v=8)
    frasco(x + 0.28 * esc, y, z, brilho, 0.2 * esc, 0.06 * esc, 1.4)


def runa(x, y, z, c=AZUL, tam=0.14):
    """Runa gravada e acesa numa face voltada para -Y: uma barra, um traço torto e um ponto."""
    em = E(c, 2.6)
    B(0.025, 0.02, tam, x, y, z, em, ch=0.0)
    B(0.025, 0.02, tam * 0.6, x + 0.045, y, z + tam * 0.35, em, ch=0.0, rot=(0, 0.7, 0))
    B(0.03, 0.02, 0.03, x - 0.05, y, z + tam * 0.1, em, ch=0.0)


# ------------------------------------------------------------------ paredes (3 m) e pilar
def _parede_base(r, janela=False, quebrada=False):
    """Parede de pedra de 3 x 0,5 x 3,2 m: fiadas de blocos, rodapé escuro, vigas de madeira e um arco; versões com janela em arco e com buraco."""
    p = pedra()
    B(3.0, 0.5, 3.2, 0, 0, 0, p, ch=0.03)
    for k in range(8):  # juntas das fiadas
        B(3.0, 0.02, 0.025, 0, -0.26, 0.38 + k * 0.38, M(PEDRA_ESC, 0.95), ch=0.0)
    for k in range(10):
        B(0.025, 0.02, 0.38, -1.4 + k * 0.31 + (0.15 if k % 2 else 0.0), -0.26, 0.4 + (k % 4) * 0.76, M(PEDRA_ESC, 0.95), ch=0.0)
    B(3.04, 0.08, 0.7, 0, -0.28, 0.0, pedra(PEDRA_ESC), ch=0.02)                # rodapé
    for x in (-1.45, 0.0, 1.45):                                                  # vigas de madeira
        B(0.16, 0.12, 3.2, x, -0.3, 0.0, madeira(MADEIRA_ESC), ch=0.02)
    B(3.04, 0.14, 0.18, 0, -0.3, 3.0, madeira(MADEIRA_ESC), ch=0.02)
    if janela:  # janela em arco com vitral azul
        B(0.7, 0.07, 1.1, 0.7, -0.29, 1.5, pedra(PEDRA_ESC), ch=0.02)
        B(0.56, 0.06, 0.96, 0.7, -0.33, 1.57, E(AZUL, 0.9), ch=0.0)
        esfera("arco", 0.28, (0.7, -0.33, 2.52), E(AZUL, 0.9), escala=(1, 0.2, 1))
        B(0.04, 0.07, 1.2, 0.7, -0.36, 1.5, ferro(), ch=0.0)
        B(0.56, 0.07, 0.04, 0.7, -0.36, 2.0, ferro(), ch=0.0)
    if quebrada:  # buraco no reboco: pedras caídas e uma raiz entrando
        B(0.85, 0.06, 0.95, -0.55, -0.3, 1.2, M("0f0e0d", 1.0), ch=0.0)
        for k in range(5):
            B(r.uniform(0.12, 0.26), r.uniform(0.1, 0.2), r.uniform(0.08, 0.2), -1.0 + r.uniform(0, 0.9), -0.46 - r.uniform(0, 0.1), 0.0,
              pedra(), ch=0.02, rot=(0, 0, r.uniform(0, 3)))
        barra((-0.9, -0.34, 2.4), (-0.5, -0.38, 1.3), 0.03, madeira(MADEIRA_ESC), v=6)
    else:  # tocha de parede e estandarte
        B(0.05, 0.06, 0.3, -0.7, -0.33, 1.6, ferro(), ch=0.0)
        esfera("chama", 0.05, (-0.7, -0.34, 1.98), E("ff9a3a", 3.0), escala=(0.8, 0.8, 1.5))
        B(0.34, 0.03, 0.7, -0.7, -0.33, 2.1, M("5a2330", 0.9, 0.3, 0.2), ch=0.0)


def parede_lab_a(r):
    _parede_base(r)


def parede_lab_b(r):
    _parede_base(r, janela=True)


def parede_lab_c(r):
    _parede_base(r, quebrada=True)


def pilar_lab(r):
    """Coluna de pedra com anéis de latão e runas azuis que acendem."""
    p = pedra()
    B(0.92, 0.92, 0.22, 0, 0, 0.0, pedra(PEDRA_ESC), ch=0.03)
    C(0.38, 2.78, 0, 0, 0.22, p, v=14, ch=0.02)
    B(0.92, 0.92, 0.2, 0, 0, 3.0, pedra(PEDRA_ESC), ch=0.03)
    for z in (0.5, 2.6):
        C(0.41, 0.07, 0, 0, z, latao(), v=14)
    for k, z in enumerate((1.0, 1.5, 2.0)):
        runa(-0.1 + 0.1 * (k % 2), -0.4, z, AZUL if k != 1 else VERDE, 0.2)


# ------------------------------------------------------------------ móveis altos
def rack_servidores(r):
    """Estante de grimórios de 2,2 m: caixa de madeira escura, cinco prateleiras de lombadas coloridas."""
    c = madeira(MADEIRA_ESC)
    B(0.9, 0.8, 2.2, 0, 0, 0, c, ch=0.02)
    B(0.84, 0.04, 2.08, 0, -0.41, 0.06, M("1c130c", 0.9), ch=0.0)
    cores = ["6b2a2a", "2d4a6b", "3b5a35", "5c3b6b", "8a6a30", "4a2e1e"]
    for i in range(5):
        z = 0.1 + i * 0.4
        B(0.84, 0.05, 0.04, 0, -0.42, z, madeira(MADEIRA_CLARA), ch=0.0)
        x = -0.36
        while x < 0.34:
            w = r.uniform(0.05, 0.1)
            B(w, 0.06, r.uniform(0.22, 0.34), x + w / 2, -0.44, z + 0.04, M(r.choice(cores), 0.7, 0.2, 0.2), ch=0.005)
            x += w + 0.008
    B(0.94, 0.86, 0.08, 0, 0, 2.2, madeira(MADEIRA_CLARA), ch=0.02)
    vela(0.3, -0.1, 2.28)
    B(0.2, 0.06, 0.12, -0.2, -0.43, 1.78, M(PERGAMINHO, 0.9), ch=0.0)


def armario_aco(r):
    """Armário de madeira com duas portas, ferragens de latão e frascos num nicho."""
    B(1.05, 0.65, 1.95, 0, 0, 0, madeira(), ch=0.03)
    for x in (-0.26, 0.26):
        B(0.46, 0.05, 1.7, x, -0.34, 0.12, madeira(MADEIRA_CLARA), ch=0.02)
        B(0.3, 0.03, 0.3, x, -0.375, 1.15, madeira(MADEIRA_ESC), ch=0.01)
        C(0.025, 0.05, x + (0.18 if x < 0 else -0.18), -0.38, 0.95, latao(), v=8, rot=(math.pi / 2, 0, 0))
    B(1.09, 0.7, 0.1, 0, 0, 1.95, madeira(MADEIRA_CLARA), ch=0.02)
    frasco(-0.3, -0.12, 2.05, AMBAR)
    frasco(0.0, -0.12, 2.05, VERDE, 0.28)
    livro(0.3, -0.12, 2.05, "6b2a2a", 0.22, 0.17)


def tanque_alto(r):
    """Cuba de alquimia: base de pedra com anel de cobre, vidro cheio de líquido verde com um vulto boiando, tampa de cobre e canos."""
    C(0.82, 0.42, 0, 0, 0, pedra(PEDRA_ESC), v=24, ch=0.02)
    C(0.78, 0.07, 0, 0, 0.42, cobre(), v=24)
    for k in range(8):
        a = k * math.pi / 4
        C(0.05, 0.08, 0.72 * math.cos(a), 0.72 * math.sin(a), 0.49, latao(), v=8)
    C(0.64, 2.2, 0, 0, 0.49, vidro("3f7f72"), v=28)
    C(0.58, 2.1, 0, 0, 0.53, E(VERDE, 1.1), v=28)
    esfera("vulto", 0.2, (0.0, 0.0, 1.5), M("0e2a1c", 0.9), escala=(1, 0.8, 1.5))
    esfera("cabeca", 0.15, (0.02, -0.02, 1.95), M("0e2a1c", 0.9))
    for k in range(7):
        esfera("bolha", r.uniform(0.025, 0.05), (r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.2), 0.7 + r.uniform(0, 1.6)), E("c8ffd8", 2.0))
    C(0.76, 0.18, 0, 0, 2.7, cobre(), v=24, ch=0.02)
    esfera("domo", 0.5, (0, 0, 2.88), cobre(), escala=(1, 1, 0.55))
    C(0.1, 0.5, -0.3, 0, 3.0, cobre(), v=12)
    barra((-0.3, 0, 3.5), (0.3, 0, 3.3), 0.05, cobre(), v=8)
    B(0.3, 0.04, 0.2, 0, -0.84, 0.5, madeira(MADEIRA_ESC), ch=0.0)
    runa(0.0, -0.87, 0.52, VERDE, 0.14)


def tanque_quebrado(r):
    """Cuba rachada: vidro em lascas, o líquido escorrido, cacos no chão e a tampa torta."""
    C(0.82, 0.42, 0, 0, 0, pedra(PEDRA_ESC), v=24, ch=0.02)
    C(0.78, 0.07, 0, 0, 0.42, cobre(), v=24)
    C(0.58, 0.05, 0, 0, 0.49, M("26422f", 0.5), v=28)
    for k in range(10):
        a = r.uniform(0, 2 * math.pi)
        B(0.14, 0.02, r.uniform(0.3, 1.9), 0.6 * math.cos(a), 0.6 * math.sin(a), 0.5, vidro("4a8a85"), ch=0.0, rot=(0, 0, a + math.pi / 2))
    for k in range(6):
        B(r.uniform(0.08, 0.2), r.uniform(0.05, 0.12), 0.02, r.uniform(-0.9, 0.9), -r.uniform(0.5, 0.9), 0.0, vidro("7bc6bb"), ch=0.0,
          rot=(0, 0, r.uniform(0, 3)))
    C(0.76, 0.18, 0, 0, 2.7, cobre(), v=24, ch=0.02, rot=(0.1, 0.05, 0))
    barra((0.1, 0, 2.7), (0.25, -0.1, 1.5), 0.02, ferro(), v=6)
    esfera("gosma", 0.2, (0.0, 0.0, 0.52), E("2fa855", 0.6), escala=(1, 1, 0.3))


def capsula_cripto(r):
    """Caixão de cristal arcano: leito de pedra e tampa de vidro azul com névoa dentro."""
    B(1.0, 2.0, 0.5, 0, 0, 0, pedra(PEDRA_ESC), ch=0.04)
    B(0.84, 1.8, 0.1, 0, 0, 0.5, pedra(PEDRA_CLARA), ch=0.03)
    barra((0, -0.8, 0.86), (0, 0.8, 0.86), 0.4, vidro("3a6f9a"), v=24)
    barra((0, -0.74, 0.86), (0, 0.74, 0.86), 0.33, E("8fd8ff", 0.55), v=24)
    for y in (-0.82, 0.82):
        barra((0, y, 0.86), (0, y + (0.1 if y > 0 else -0.1), 0.86), 0.43, latao(), v=24)
    for k in range(3):
        B(0.05, 0.9, 0.04, -0.2 + k * 0.2, 0.0, 1.2, latao(), ch=0.0)
    runa(-0.15, -1.02, 0.2, AZUL, 0.2)
    runa(0.15, -1.02, 0.2, ROXO, 0.2)


def gerador(r):
    """Athanor: forno de pedra com boca de fogo, cúpula e chaminé de cobre."""
    B(2.0, 1.4, 1.1, 0, 0, 0, pedra(), ch=0.05)
    B(2.2, 1.6, 0.18, 0, 0, 0.0, pedra(PEDRA_ESC), ch=0.04)
    B(0.8, 0.1, 0.62, -0.4, -0.7, 0.2, M("0f0d0b", 1.0), ch=0.0)
    B(0.62, 0.06, 0.46, -0.4, -0.76, 0.28, E("ff8a2a", 2.4), ch=0.0)
    B(0.9, 0.14, 0.08, -0.4, -0.74, 0.86, ferro(), ch=0.01)
    esfera("domo", 0.62, (0.2, 0.0, 1.35), cobre(), escala=(1.3, 1.0, 0.95))
    C(0.25, 0.8, 0.5, 0.1, 1.9, cobre(), v=14)
    C(0.3, 0.1, 0.5, 0.1, 2.5, latao(), v=14)
    C(0.1, 0.9, -0.5, 0.2, 1.1, cobre(), v=10)
    for x in (0.4, 0.8):
        runa(x, -0.72, 0.5, AMBAR, 0.2)
    for x in (-0.9, 0.9):
        C(0.1, 0.08, x, -0.5, 1.1, latao(), v=10)


def cano_grosso(r):
    """Coluna de destilação: fuste de pedra com serpentina de cobre em volta e um gargalo de vidro no alto."""
    C(0.34, 2.4, 0, 0, 0, pedra(), v=12, ch=0.02)
    B(0.8, 0.8, 0.2, 0, 0, 0.0, pedra(PEDRA_ESC), ch=0.03)
    for k in range(7):
        a = k * 1.1
        barra((0.38 * math.cos(a), 0.38 * math.sin(a), 0.4 + k * 0.28), (0.38 * math.cos(a + 1.1), 0.38 * math.sin(a + 1.1), 0.68 + k * 0.28), 0.045, cobre(), v=8)
    C(0.22, 0.5, 0, 0, 2.4, vidro("3f7f72"), v=14)
    C(0.17, 0.46, 0, 0, 2.42, E(VERDE, 1.0), v=14)
    esfera("tampa", 0.2, (0, 0, 2.95), cobre(), escala=(1, 1, 0.7))
    barra((0.0, 0.0, 3.05), (0.3, 0.0, 2.7), 0.04, cobre(), v=8)


# ------------------------------------------------------------------ mesas e bancadas
def mesa_lab(r):
    """Mesa de madeira com frascos, um livro aberto e uma vela."""
    B(1.8, 0.9, 0.12, 0, 0, 0.86, madeira(MADEIRA_CLARA), ch=0.02)
    for x in (-0.78, 0.78):
        for y in (-0.34, 0.34):
            B(0.1, 0.1, 0.86, x, y, 0.0, madeira(MADEIRA_ESC), ch=0.02)
    B(1.6, 0.08, 0.1, 0, -0.38, 0.72, madeira(MADEIRA_ESC), ch=0.01)
    frasco(-0.6, -0.1, 0.98, VERDE)
    frasco(-0.4, 0.15, 0.98, ROXO, 0.2)
    frasco(0.5, 0.1, 0.98, AMBAR, 0.28)
    livro(0.05, -0.12, 0.98, "5c2a2a", 0.3, 0.22, 0.05, 0.2)
    vela(0.72, -0.18, 0.98)
    alambique(0.2, 0.25, 0.98, 0.5, AZUL)


def bancada_lab(r):
    """Bancada de alquimia de 3 m: tampo de pedra sobre cavaletes de madeira, um alambique grande, frascos em suporte e pilão."""
    B(3.1, 1.0, 0.14, 0, 0, 0.9, pedra(PEDRA_CLARA), ch=0.03)
    B(3.0, 0.9, 0.9, 0, 0, 0.0, madeira(MADEIRA_ESC), ch=0.03)
    for x in (-0.75, 0.75):
        B(0.7, 0.06, 0.7, x, -0.46, 0.1, madeira(MADEIRA), ch=0.02)
        C(0.025, 0.04, x + 0.22, -0.5, 0.45, latao(), v=8, rot=(math.pi / 2, 0, 0))
    alambique(-1.0, 0.0, 1.04, 1.0, VERDE)
    B(1.0, 0.06, 0.04, 0.5, -0.05, 1.28, madeira(MADEIRA), ch=0.0)
    for k in range(4):
        frasco(0.1 + k * 0.24, -0.05, 1.32, [AMBAR, AZUL, VERDE, ROXO][k], 0.22)
    C(0.1, 0.09, 1.2, 0.0, 1.04, pedra(PEDRA_ESC), v=12)
    barra((1.2, 0.0, 1.1), (1.28, -0.05, 1.3), 0.02, madeira(MADEIRA_CLARA), v=6)
    livro(0.45, 0.28, 1.04, "2d4a6b", 0.26, 0.2, 0.05, -0.2)


def console(r, quebrado=False):
    """Escrivaninha arcana: pedestal inclinado de madeira com um cristal azul no alto e um grimório aberto (quebrada: o cristal rachou)."""
    B(1.3, 0.9, 0.9, 0, 0, 0.0, madeira(MADEIRA_ESC), ch=0.03)
    B(1.2, 0.7, 0.1, 0, -0.02, 0.9, madeira(MADEIRA_CLARA), ch=0.03, rot=(-0.2, 0, 0))
    livro(0.0, -0.1, 1.0, "2d4a6b", 0.5, 0.36, 0.06)
    B(0.2, 0.2, 0.55, 0.0, 0.2, 0.95, madeira(MADEIRA_ESC), ch=0.02)
    if not quebrado:
        px3.cone("cristal", 0.2, 0.0, 0.55, (0, 0.2, 1.8), E(AZUL, 2.0), vertices=6)
        esfera("halo", 0.1, (0, 0.2, 1.5), E("d8f4ff", 2.6))
    else:
        px3.cone("cristal", 0.2, 0.0, 0.4, (0.05, 0.2, 1.7), E(AZUL, 1.0), vertices=6, )
        B(0.14, 0.06, 0.34, -0.2, 0.2, 1.46, E(AZUL, 2.0), ch=0.0, rot=(0, 0.6, 0.3))
        esfera("faisca", 0.04, (0.25, -0.1, 1.2), E("ffe08a", 3.4))
    vela(-0.5, -0.18, 1.0, 0.12)
    B(0.3, 0.05, 0.14, 0, -0.46, 0.5, madeira(MADEIRA_CLARA), ch=0.01)


def console_quebrado(r):
    console(r, quebrado=True)


# ------------------------------------------------------------------ caixas, barris, maca, gaiola, lâmpada
def caixa_suprimentos(r):
    """Caixote de madeira com cintas de ferro e palha saindo."""
    B(1.1, 1.1, 0.85, 0, 0, 0, madeira(MADEIRA), ch=0.03)
    for z in (0.1, 0.65):
        B(1.14, 1.14, 0.08, 0, 0, z, ferro(), ch=0.01)
    for k in range(5):
        B(1.04, 0.02, 0.03, 0, -0.56, 0.12 + k * 0.14, M(MADEIRA_ESC, 0.9), ch=0.0)
    for k in range(5):
        B(0.06, 0.04, 0.2, -0.4 + k * 0.2, r.uniform(-0.3, 0.3), 0.85, M("c8b070", 0.9), ch=0.0, rot=(0, 0, r.uniform(0, 3)))


def caixa_empilhada(r):
    """Dois baús empilhados, o de cima com tampa curva e fecho de latão."""
    B(1.2, 1.2, 0.95, 0, 0, 0, madeira(MADEIRA_ESC), ch=0.03)
    B(1.24, 1.24, 0.1, 0, 0, 0.45, ferro(), ch=0.01)
    B(1.0, 1.0, 0.7, 0.05, 0, 0.95, madeira(), ch=0.03)
    barra((-0.45, 0, 1.65), (0.55, 0, 1.65), 0.5, madeira(MADEIRA), v=16)
    B(0.14, 0.05, 0.2, 0.05, -0.51, 1.35, latao(), ch=0.01)
    B(0.06, 1.04, 0.74, -0.42, 0, 0.95, ferro(), ch=0.01)


def barril_toxico(r):
    """Barril de poção: aduelas de madeira, aros de ferro e a tampa aberta com um líquido verde brilhando."""
    C(0.36, 0.95, 0, 0, 0, madeira(MADEIRA_ESC), v=14, ch=0.03)
    for z in (0.14, 0.7):
        C(0.38, 0.07, 0, 0, z, ferro(), v=14)
    C(0.3, 0.04, 0, 0, 0.94, E(VERDE, 1.5), v=14)
    C(0.34, 0.06, 0, 0, 0.9, madeira(MADEIRA_CLARA), v=14)
    esfera("gota", 0.04, (0.18, -0.32, 0.4), E(VERDE, 2.0), escala=(1, 0.6, 1.8))


def maca(r):
    """Mesa de dissecação de pedra, com correntes e uma manta; sulcos de sangue seco."""
    B(0.95, 2.1, 0.7, 0, 0, 0.0, pedra(PEDRA_ESC), ch=0.04)
    B(0.8, 1.9, 0.14, 0, 0, 0.7, pedra(PEDRA_CLARA), ch=0.03)
    B(0.08, 1.5, 0.03, 0.2, 0.0, 0.84, M("4a1a1a", 0.6), ch=0.0)
    B(0.7, 0.6, 0.05, 0.0, 0.5, 0.84, M("5a3f35", 0.95, 0.4, 0.3), ch=0.01, rot=(0, 0, 0.1))
    for y in (-0.5, 0.2):
        barra((-0.4, y, 0.78), (-0.5, y, 0.45), 0.02, ferro(), v=6)
        barra((0.4, y, 0.78), (0.5, y, 0.4), 0.02, ferro(), v=6)
    B(0.2, 0.08, 0.04, -0.52, -0.5, 0.35, ferro(), ch=0.0)


def gaiola(r):
    """Gaiola de ferro forjado com uma criatura de olhos acesos lá dentro."""
    for x in (-0.6, 0.6):
        for y in (-0.45, 0.45):
            C(0.04, 1.3, x, y, 0.1, ferro(), v=8)
    for z in (0.1, 1.38):
        B(1.3, 1.0, 0.06, 0, 0, z, ferro(), ch=0.01)
    for k in range(7):
        C(0.02, 1.3, -0.54 + k * 0.18, -0.46, 0.1, ferro(), v=6)
    esfera("cria", 0.26, (0.1, 0.1, 0.45), M("1c1516", 0.9), escala=(1.2, 1.0, 0.9))
    for s in (-1, 1):
        esfera("olho", 0.035, (0.04 + s * 0.09, -0.12, 0.55), E(VERMELHO, 3.0))
    esfera("cupula", 0.55, (0, 0, 1.44), ferro(), escala=(1.1, 0.85, 0.35))
    barra((0, 0, 1.6), (0, 0, 1.85), 0.025, ferro(), v=6)


def lampada_emergencia(r):
    """Lampião de ferro num poste de madeira, com um cristal rubi aceso."""
    C(0.05, 2.2, 0, 0, 0.0, madeira(MADEIRA_ESC), v=8)
    C(0.15, 0.06, 0, 0, 0.0, ferro(), v=10)
    B(0.08, 0.5, 0.05, 0.18, 0, 2.15, ferro(), ch=0.0)
    C(0.1, 0.06, 0.36, 0, 2.0, ferro(), v=8)
    C(0.09, 0.22, 0.36, 0, 2.05, E(VERMELHO, 2.4), v=8)
    esfera("tampa", 0.1, (0.36, 0, 2.3), ferro(), escala=(1, 1, 0.55))
    esfera("halo", 0.14, (0.36, 0, 2.15), E("ff7060", 0.8), escala=(1, 1, 1.2))


def cacos_vidro(r):
    """Cacos de frascos e uma poça de poção que ainda brilha."""
    esfera("poca", 0.34, (0.0, 0.0, 0.0), E(VERDE, 0.7), escala=(1.3, 0.8, 0.04))
    for k in range(9):
        B(r.uniform(0.05, 0.16), r.uniform(0.04, 0.1), 0.02, r.uniform(-0.45, 0.45), r.uniform(-0.25, 0.25), 0.0, vidro("7bc6bb"), ch=0.0,
          rot=(0, 0, r.uniform(0, 3)))


def lixo_lab(r):
    """Pergaminhos amassados e penas no chão."""
    for k in range(6):
        B(r.uniform(0.2, 0.4), r.uniform(0.15, 0.3), 0.025, r.uniform(-0.4, 0.4), r.uniform(-0.2, 0.2), 0.0, M(PERGAMINHO, 0.95), ch=0.01,
          rot=(r.uniform(-0.2, 0.2), r.uniform(-0.2, 0.2), r.uniform(0, 3)))
    for k in range(2):
        barra((r.uniform(-0.3, 0.3), 0.0, 0.03), (r.uniform(-0.3, 0.3), r.uniform(-0.2, 0.2), 0.05), 0.012, M("2a2a30", 0.9), v=5)
    esfera("tinta", 0.1, (0.3, -0.1, 0.0), M("101018", 0.4), escala=(1.4, 1, 0.05))


def restos_cobaia(r):
    """Restos de um homúnculo: carcaça rasa numa poça de gosma, com costelas, coluna, caveira e rabo; deitada ao longo de x, a caveira para a direita."""
    carne = M("7a5a5e", 0.8, 0.3, 0.35, 9.0)
    osso = M("cbc4b0", 0.7, 0.1, 0.15, 12.0)
    escuro = M("26181b", 0.9)
    esfera("gosma", 0.6, (0.0, 0.05, 0.01), E("2fa855", 0.32), escala=(1.45, 1.0, 0.04))
    esfera("sangue", 0.3, (-0.2, -0.3, 0.012), M("5a1414", 0.4), escala=(1.4, 0.8, 0.03))
    esfera("quadril", 0.26, (-0.42, 0.02, 0.1), carne, escala=(1.25, 0.95, 0.5))
    esfera("pelo", 0.18, (-0.62, 0.1, 0.07), M("4a3a3e", 0.9, 0.2, 0.4), escala=(1.3, 1.0, 0.5))
    barra((-0.5, 0.0, 0.1), (0.38, 0.0, 0.1), 0.035, osso, v=8)
    for xi in (-0.2, -0.02, 0.16):
        for s in (-1, 1):
            barra((xi, s * 0.03, 0.1), (xi - 0.02, s * 0.2, 0.2), 0.034, osso, v=8)
            barra((xi - 0.02, s * 0.2, 0.2), (xi - 0.06, s * 0.3, 0.07), 0.03, osso, v=8)
    esfera("peito", 0.15, (-0.04, 0.0, 0.06), escuro, escala=(2.1, 0.8, 0.3))
    esfera("cranio", 0.12, (0.5, 0.0, 0.11), osso, escala=(1.0, 0.85, 0.85))
    esfera("focinho", 0.08, (0.64, 0.02, 0.08), osso, escala=(1.4, 0.8, 0.7))
    for s in (-1, 1):
        esfera("olho", 0.035, (0.52, s * 0.07, 0.17), E("c8ff6a", 2.6))
    barra((-0.82, 0.12, 0.05), (-1.0, 0.3, 0.03), 0.032, carne, v=6)
    barra((-1.0, 0.3, 0.03), (-0.88, 0.52, 0.025), 0.026, carne, v=6)
    for x, y, a in [(0.1, 0.38, 0.4), (-0.3, -0.42, 2.0), (0.38, -0.34, 1.1)]:
        B(0.2, 0.045, 0.045, x, y, 0.02, osso, ch=0.01, rot=(0, 0, a))
    B(0.34, 0.26, 0.025, 0.15, -0.18, 0.015, M("3a2f4a", 0.95), ch=0.0, rot=(0, 0, 0.3))   # um pedaço de manto


def porta_blindada(r):
    """Trecho de parede com uma porta de madeira reforçada de ferro, arco de pedra e uma runa acesa em cima."""
    _parede_base(r)
    B(1.7, 0.1, 2.5, 0, -0.32, 0.0, pedra(PEDRA_CLARA), ch=0.03)
    B(1.5, 0.1, 2.3, 0, -0.38, 0.0, madeira(MADEIRA_ESC), ch=0.02)
    for k in range(5):
        B(0.02, 0.04, 2.2, -0.6 + k * 0.3, -0.44, 0.05, M("1f140c", 0.9), ch=0.0)
    for z in (0.5, 1.2, 1.9):
        B(1.46, 0.04, 0.12, 0, -0.45, z, ferro(), ch=0.01)
        for x in (-0.6, 0.0, 0.6):
            esfera("rebite", 0.03, (x, -0.48, z + 0.06), latao())
    C(0.06, 0.05, 0.5, -0.47, 1.15, latao(), v=10, rot=(math.pi / 2, 0, 0))
    runa(0.0, -0.45, 2.5, AZUL, 0.18)


def duto_ventilacao(r):
    """Chaminé de cobre com um fogão de pedra embaixo: tubo grosso que sobe, dobra e sai pelo teto."""
    B(1.1, 0.8, 0.9, 0, 0, 0.0, pedra(PEDRA_ESC), ch=0.04)
    B(0.5, 0.06, 0.4, -0.2, -0.42, 0.2, M("0f0d0b", 1.0), ch=0.0)
    B(0.36, 0.05, 0.26, -0.2, -0.45, 0.26, E("ff8a2a", 2.2), ch=0.0)
    C(0.3, 1.6, 0.0, 0.0, 0.9, cobre(), v=18)
    for z in (1.1, 1.8):
        C(0.34, 0.08, 0.0, 0.0, z, latao(), v=18)
    barra((0.0, 0.0, 2.5), (0.5, 0.0, 2.65), 0.22, cobre(), v=16)
    C(0.26, 0.08, 0.25, 0.0, 2.55, latao(), v=16, rot=(0, math.pi / 2 + 0.3, 0))
    esfera("fuligem", 0.2, (0.0, -0.3, 1.6), M("1a1614", 0.95), escala=(1, 0.3, 1.2))


def estante_amostras(r):
    """Estante de madeira com frascos de poção acesos e potes de ervas, prateleira por prateleira."""
    for x in (-0.86, 0.86):
        for y in (-0.25, 0.25):
            B(0.08, 0.08, 2.05, x, y, 0.0, madeira(MADEIRA_ESC), ch=0.01)
    B(1.78, 0.58, 0.06, 0, 0, 0.0, madeira(MADEIRA_ESC), ch=0.01)
    for z in (0.5, 0.98, 1.46, 1.94):
        B(1.78, 0.58, 0.05, 0, 0, z, madeira(MADEIRA_CLARA), ch=0.01)
    B(1.74, 0.04, 2.0, 0, 0.29, 0.05, M("1c130c", 0.9), ch=0.0)
    cores = [(VERDE, 1.2), (AMBAR, 1.0), (AZUL, 0.9), (None, 0), (ROXO, 0.9)]
    for z in (0.06, 0.55, 1.03, 1.51):
        x = -0.72
        while x < 0.75:
            t = r.random()
            if t < 0.6:
                c, f = r.choice(cores)
                h = r.uniform(0.2, 0.34)
                C(0.085, h, x, r.uniform(-0.1, 0.1), z, vidro("6f9a95") if c is None else E(c, f), v=14)
                C(0.09, 0.03, x, 0.0, z + h, madeira(MADEIRA_CLARA), v=14)
                x += 0.2
            elif t < 0.85:
                B(r.uniform(0.22, 0.34), 0.28, r.uniform(0.14, 0.26), x + 0.1, 0.0, z, M(r.choice(["4b5a3a", "5a4444", "46425f"]), 0.8, 0.2, 0.15), ch=0.02)
                x += 0.38
            else:
                x += 0.22
    vela(0.7, 0.0, 2.0, 0.12)


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


# ------------------------------------------------------------------ piso: lajes de pedra e tábuas de madeira, 16 m de lado, com círculos rúnicos gravados
def piso_lab(r):
    N = 16
    B(N, N, 0.1, N / 2.0, N / 2.0, -0.1, M("1c1814", 1.0), ch=0.0)
    tons = [M(h, 0.93, 0.5, 0.25, 6.0) for h in ("5d5851", "56514b", "645f58", "4f4a45")]
    taboas = [M(h, 0.85, 0.45, 0.3, 16.0) for h in ("5a3f28", "50371f", "62452c", "4b331f")]
    for i in range(N):
        for j in range(N):
            alt = 0.06 + r.random() * 0.012
            if (i // 4 + j // 4) % 3 == 1:   # trechos de assoalho de madeira (4 x 4 m), tábuas ao longo de x
                for k in range(4):
                    B(0.98, 0.23, alt, i + 0.5, j + 0.125 + k * 0.25, 0.0, r.choice(taboas), ch=0.012)
                if r.random() < 0.3:
                    B(0.05, 0.05, 0.02, i + r.uniform(0.2, 0.8), j + r.uniform(0.2, 0.8), alt, ferro(), ch=0.0)
                continue
            B(0.96, 0.96, alt, i + 0.5, j + 0.5, 0.0, tons[(i // 2 + j // 2 + r.randrange(2)) % 4], ch=0.025)
            if r.random() < 0.14:   # musgo seco / mancha escura
                C(r.uniform(0.15, 0.3), 0.004, i + r.uniform(0.2, 0.8), j + r.uniform(0.2, 0.8), alt + 0.004, M("2c2a20", 0.5), v=14)
            if r.random() < 0.1:    # rachadura
                B(r.uniform(0.3, 0.8), 0.03, 0.01, i + 0.5, j + r.uniform(0.3, 0.7), alt, M("15110e", 0.9), ch=0.0, rot=(0, 0, r.uniform(-0.5, 0.5)))
    # círculos rúnicos (inteiros no azulejo: o azulejo repete, então cada um mora longe da borda)
    em = E(AZUL, 1.3)
    for cx, cy, rr in [(5.0, 5.0, 2.4), (11.5, 11.0, 1.6)]:
        for k in range(48):
            a = k * math.pi * 2 / 48
            B(0.17, 0.05, 0.012, cx + rr * math.cos(a), cy + rr * math.sin(a), 0.07, em, ch=0.0, rot=(0, 0, a + math.pi / 2))
        for k in range(8):
            a = k * math.pi / 4 + 0.2
            B(0.05, rr * 0.8, 0.012, cx + rr * 0.45 * math.cos(a), cy + rr * 0.45 * math.sin(a), 0.07, E(AZUL, 0.9), ch=0.0, rot=(0, 0, a + math.pi / 2))


PISO = (16, piso_lab)

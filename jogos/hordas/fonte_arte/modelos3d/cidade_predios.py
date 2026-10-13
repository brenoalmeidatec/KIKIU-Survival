"""Cidade da v2: os prédios (fachada voltada para -Y) e as peças de fachada (janela, toldo, escada de incêndio, telhado, entulho).

Cada prédio tem 3 a 6 m de altura de parede e 2,4 a 3,2 m de profundidade (o desenho é uma fachada com o teto à vista: o jogo nunca vê os
fundos). O piso tem terrenos de 7 m, então a largura vai até 6,4 m. O sprite vai de 150 a 215 px de altura (árvore da floresta).
"""
import math

from cidade_pecas import (CONCRETO, CONCRETO_CLARO, CONCRETO_ESC, CR, FERRUGEM, FERRUGEM_ESC, JANELA, JANELA_FRIA, MADEIRA_VELHA, METAL_ESC, E, M, metal,
                          NEON_AZUL, NEON_ROSA, NEON_VERDE, NEON_VERM, TIJOLO_A, TIJOLO_B, reboco, texto, tijolo)
from mapas_v2 import B, C, barra, cone, esfera, vidro


# ------------------------------------------------------------------ peças de fachada
def janela(x, z, w, h, yf, estado="escura", r=None, moldura="2b2f34", grade=False, peitoril=True, sal=0.07):
    """Janela na fachada que está no plano y = yf (voltada para -Y): moldura que sobressai, vidro (escuro, aceso, tapado ou quebrado),
    montantes, peitoril e verga. x e z: centro e base."""
    fr = metal(moldura, 0.5, 0.2, 0.2)
    B(w + 0.12, sal, h + 0.12, x, yf - sal / 2.0, z - 0.06, fr, ch=0.01)
    gy = yf - sal - 0.006
    if estado == "aceso":
        B(w, 0.02, h, x, gy, z, E(JANELA, 1.5), ch=0.0)
        if r is not None and r.random() < 0.6:   # cortina meio fechada
            B(w * 0.38, 0.02, h * 0.9, x - w * 0.3, gy - 0.012, z, M("6a3c26", 0.9), ch=0.0)
    elif estado == "fria":
        B(w, 0.02, h, x, gy, z, E(JANELA_FRIA, 1.1), ch=0.0)
    elif estado == "tapada":
        B(w, 0.02, h, x, gy, z, M("0a1016", 0.3), ch=0.0)
        for k in range(3):
            B(w + 0.14, 0.035, 0.13, x, gy - 0.025, z + h * (0.2 + 0.3 * k), M(MADEIRA_VELHA, 0.9, 0.5, 0.3, 14.0), ch=0.008,
              rot=(0, (0.05 if k % 2 else -0.04), 0))
    elif estado == "quebrada":
        B(w, 0.02, h, x, gy, z, M("0a1016", 0.3), ch=0.0)
        for k in range(5):   # cacos que sobraram na moldura
            B(r.uniform(0.06, 0.16), 0.012, r.uniform(0.1, 0.3), x + r.uniform(-w / 2, w / 2) * 0.9, gy - 0.012,
              z + (h * 0.8 if r.random() < 0.5 else 0.05), vidro("6f8a94"), ch=0.0, rot=(0, r.uniform(-0.5, 0.5), 0))
    else:
        B(w, 0.02, h, x, gy, z, M("0f1a22", 0.12), ch=0.0)
        B(w * 0.12, 0.012, h * 0.85, x - w * 0.15, gy - 0.012, z + h * 0.07, M("2d4252", 0.2), ch=0.0)
        B(w * 0.07, 0.012, h * 0.6, x + w * 0.05, gy - 0.012, z + h * 0.2, M("2a3c4a", 0.2), ch=0.0)
    B(0.035, 0.03, h, x, gy - 0.02, z, fr, ch=0.0)
    B(w, 0.03, 0.035, x, gy - 0.02, z + h * 0.55, fr, ch=0.0)
    if grade:
        for k in range(5):
            B(0.025, 0.04, h + 0.05, x - w / 2 + (k + 0.5) * w / 5, gy - 0.04, z - 0.02, M("1a1d21", 0.5, 0.2, 0.2), ch=0.0)
    if peitoril:
        B(w + 0.3, 0.17, 0.06, x, yf - 0.085, z - 0.12, M(CONCRETO_CLARO, 0.85, 0.4, 0.3), ch=0.015)
        B(w + 0.2, 0.1, 0.08, x, yf - 0.05, z + h + 0.1, M(CONCRETO, 0.85, 0.4, 0.3), ch=0.015)


def toldo(x, w, z, yf, prof, c1, c2, n=8, inclina=0.42):
    """Toldo listrado, inclinado para a frente, com a barra e uma franja na ponta."""
    m1, m2 = M(c1, 0.8, 0.4, 0.3, 14.0), M(c2, 0.8, 0.4, 0.3, 14.0)
    lar = w / n
    for k in range(n):
        B(lar, prof, 0.045, x - w / 2 + lar * (k + 0.5), yf - prof / 2 * math.cos(inclina), z - prof / 2 * math.sin(inclina),
          m1 if k % 2 == 0 else m2, ch=0.005, rot=(inclina, 0, 0))
    ze = z - prof * math.sin(inclina)
    ye = yf - prof * math.cos(inclina)
    for k in range(n):
        B(lar, 0.03, 0.2, x - w / 2 + lar * (k + 0.5), ye - 0.02, ze - 0.2, m1 if k % 2 == 0 else m2, ch=0.0)
    B(w, 0.06, 0.05, x, ye - 0.02, ze - 0.02, metal(METAL_ESC), ch=0.005)
    for s in (-1, 1):   # hastes de apoio
        barra((x + s * (w / 2 - 0.1), yf, z - 0.02), (x + s * (w / 2 - 0.1), ye, ze - 0.02), 0.025, metal(METAL_ESC), v=6)


def manchas(x0, x1, z0, z1, yf, r, n, cor="1a1816", larg=(0.05, 0.16), comp=(0.5, 1.6)):
    """Escorridos de sujeira na parede: tiras escuras e finas, caídas de cima para baixo."""
    for k in range(n):
        c = r.uniform(*comp)
        B(r.uniform(*larg), 0.012, c, r.uniform(x0, x1), yf - 0.006, r.uniform(z0 + c, z1), M(cor, 0.95, 0.2, 0.2), ch=0.0)


def marca_x(x, z, yf, tam=0.6, cor="8a1f1c"):
    """X de tinta em spray (marca de casa vistoriada), um clássico do fim do mundo."""
    for s in (-1, 1):
        B(0.07, 0.012, tam * 1.35, x, yf - 0.006, z, M(cor, 0.9, 0.2, 0.2), ch=0.0, rot=(0, s * 0.72, 0))


def escada_incendio(x0, x1, yf, andares, prof=0.85, sobe_direita=True):
    """Escada de incêndio de ferro: plataformas de grade em cada andar, guarda-corpo, lances em zigue-zague e a escada de descida do primeiro andar."""
    fe = metal("272b30", 0.5, 0.35, 0.3)
    fe2 = M(FERRUGEM_ESC, 0.8, 0.4, 0.4)
    w = x1 - x0
    xc = (x0 + x1) / 2.0
    for zf in andares:
        B(w, prof, 0.05, xc, yf - prof / 2, zf, fe, ch=0.01)
        for j in range(7):   # grade do piso
            B(w - 0.06, 0.02, 0.012, xc, yf - 0.1 - j * (prof - 0.14) / 6, zf + 0.03, M("101215", 0.7), ch=0.0)
        B(w, 0.04, 0.05, xc, yf - prof + 0.02, zf + 0.95, fe, ch=0.0)
        for xx in (x0 + 0.03, x1 - 0.03):
            B(0.04, 0.04, 0.95, xx, yf - prof + 0.02, zf, fe, ch=0.0)
            B(0.04, prof, 0.04, xx, yf - prof / 2, zf + 0.95, fe, ch=0.0)
        for j in range(5):
            B(0.02, 0.03, 0.85, x0 + 0.15 + j * (w - 0.3) / 4, yf - prof + 0.02, zf + 0.06, fe, ch=0.0)
        for xx in (x0 + 0.1, x1 - 0.1):   # esquadros que prendem na parede
            barra((xx, yf, zf - 0.02), (xx, yf - prof * 0.9, zf - 0.4), 0.015, fe2, v=6)
    # lances de escada entre os andares: degraus na diagonal
    for a, b in zip(andares, andares[1:]):
        lado = x1 - 0.55 if sobe_direita else x0 + 0.55
        L = b - a
        passo = 8
        for j in range(passo):
            zz = a + 0.05 + L * (j + 0.5) / passo
            yy = yf - 0.12 - (prof - 0.24) * (1 - (j + 0.5) / passo)
            B(0.5, 0.2, 0.025, lado, yy, zz, fe, ch=0.0)
        for s in (-0.27, 0.27):
            barra((lado + s, yf - prof + 0.06, a + 0.05), (lado + s, yf - 0.12, b + 0.9), 0.014, fe, v=6)
    # lance de descida do primeiro andar para o chão
    z0 = andares[0]
    lado = x0 + 0.5 if sobe_direita else x1 - 0.5
    zb = max(0.9, z0 - 1.3)
    for s in (-0.22, 0.22):
        barra((lado + s, yf - prof + 0.03, z0), (lado + s, yf - prof - 0.3, zb), 0.014, fe, v=6)
    for j in range(5):
        t = (j + 0.5) / 5
        B(0.4, 0.03, 0.02, lado, yf - prof + 0.03 - 0.33 * t, z0 * (1 - t) + zb * t, fe, ch=0.0)


def telhado(w, d, z, r, ar=1, caixa_dagua=False, antena=False, parabola=False, alt_parapeito=0.4):
    """Teto de piche com platibanda, unidades de ar condicionado, caixa d'água, antena e entulho."""
    piche = M("2d2f33", 0.95, 0.5, 0.35, 5.0)
    B(w, d, 0.1, 0, 0, z, piche, ch=0.01)
    pc = M("6a6c6e", 0.9, 0.4, 0.3, 4.0)
    B(w + 0.18, 0.18, alt_parapeito, 0, -d / 2 - 0.02, z, pc, ch=0.02)          # frente
    B(w + 0.18, 0.18, alt_parapeito, 0, d / 2, z, pc, ch=0.02)                  # fundo
    for s in (-1, 1):
        B(0.18, d + 0.2, alt_parapeito, s * (w / 2), 0, z, pc, ch=0.02)
    B(w + 0.24, 0.24, 0.07, 0, -d / 2 - 0.02, z + alt_parapeito, M(CONCRETO_CLARO, 0.85, 0.4, 0.3), ch=0.015)
    zt = z + 0.1
    for k in range(ar):
        ax = r.uniform(-w / 2 + 0.7, w / 2 - 0.7)
        ay = r.uniform(-d / 2 + 0.6, d / 2 - 0.6)
        B(0.8, 0.55, 0.5, ax, ay, zt, metal("6a7076", 0.5, 0.25, 0.25), ch=0.03)
        CR(0.2, 0.05, ax, ay - 0.28, zt + 0.28, M("1a1d21", 0.6), (math.pi / 2, 0, 0), v=14)
    if caixa_dagua:
        cx = r.uniform(-w / 2 + 0.7, w / 2 - 0.7)
        for sx in (-0.3, 0.3):
            for sy in (-0.2, 0.2):
                B(0.06, 0.06, 0.45, cx + sx, -0.3 + sy, zt, M(FERRUGEM_ESC, 0.8, 0.4, 0.4), ch=0.0)
        C(0.5, 0.8, cx, -0.3, zt + 0.45, M("6a4a30", 0.9, 0.6, 0.4, 14.0), v=18)
        for zz in (0.65, 1.0):
            C(0.515, 0.04, cx, -0.3, zt + zz, metal(METAL_ESC), v=18)
        cone("tampa", 0.55, 0.05, 0.28, (cx, -0.3, zt + 1.4), metal("3a3e44", 0.5), vertices=18)
    if antena:
        ax = r.uniform(-w / 2 + 0.5, w / 2 - 0.5)
        barra((ax, 0, zt), (ax, 0, zt + 1.1), 0.025, metal(METAL_ESC), v=8)
        for k in range(3):
            B(0.5 - 0.1 * k, 0.02, 0.025, ax, 0, zt + 0.5 + 0.2 * k, metal(METAL_ESC), ch=0.0)
    if parabola:
        px_ = r.uniform(-w / 2 + 0.5, w / 2 - 0.5)
        esfera("parabola", 0.3, (px_, -d / 2 + 0.5, zt + 0.5), M("a8aaa6", 0.5, 0.2, 0.2), escala=(1, 0.2, 1))
    # remendos de piche, poças de chuva, tubos, chaminés, lona e mato: o teto é metade do que se vê do prédio
    for k in range(r.randint(5, 8)):
        B(r.uniform(0.5, 1.4), r.uniform(0.35, 0.8), 0.012, r.uniform(-w / 2 + 0.7, w / 2 - 0.7), r.uniform(-d / 2 + 0.4, d / 2 - 0.4), zt - 0.02,
          M(r.choice(["3c3f43", "25272a", "4a4c4f", "454038"]), 0.95, 0.5, 0.4), ch=0.0, rot=(0, 0, r.uniform(-0.2, 0.2)))
    for k in range(2):
        B(r.uniform(0.5, 1.0), r.uniform(0.3, 0.6), 0.01, r.uniform(-w / 2 + 0.8, w / 2 - 0.8), r.uniform(-d / 2 + 0.4, d / 2 - 0.4), zt - 0.005,
          M("0e1822", 0.05), ch=0.0)
    for k in range(r.randint(1, 2)):
        vx, vy = r.uniform(-w / 2 + 0.6, w / 2 - 0.6), r.uniform(-d / 2 + 0.5, d / 2 - 0.5)
        C(0.11, 0.45, vx, vy, zt, metal("5a5f64", 0.5, 0.3, 0.3), v=12)
        cone("capuz", 0.2, 0.05, 0.14, (vx, vy, zt + 0.5), metal("3a3e44", 0.5), vertices=12)
    y0 = r.uniform(-d / 2 + 0.5, d / 2 - 0.5)
    barra((-w / 2 + 0.5, y0, zt + 0.12), (w / 2 - 1.3, y0 + r.uniform(-0.2, 0.2), zt + 0.12), 0.05, metal("4a4f55", 0.5, 0.3, 0.3), v=8)
    for sx in (-w / 2 + 1.0, 0.0):
        B(0.07, 0.07, 0.12, sx, y0, zt, metal("2a2e33"), ch=0.0)
    if r.random() < 0.8:
        B(0.9, 0.9, 0.3, r.uniform(-w / 2 + 1.0, w / 2 - 1.0), r.uniform(-d / 2 + 0.55, d / 2 - 0.5), zt, M("6a6c6e", 0.9, 0.4, 0.3), ch=0.03)
    if r.random() < 0.7:   # lona azul rasgada
        B(r.uniform(1.0, 1.4), r.uniform(0.6, 0.9), 0.04, r.uniform(-w / 2 + 1.0, w / 2 - 1.0), r.uniform(-d / 2 + 0.5, d / 2 - 0.5), zt + 0.02,
          M(r.choice(["2f4f6a", "6a4a30", "3a5a3a"]), 0.9, 0.2, 0.3), ch=0.01, rot=(r.uniform(-0.05, 0.05), r.uniform(-0.05, 0.05), r.uniform(-0.3, 0.3)))
    for k in range(5):   # mato no pé da platibanda
        mx = r.uniform(-w / 2 + 0.3, w / 2 - 0.3)
        for j in range(3):
            B(0.05, 0.05, r.uniform(0.15, 0.3), mx + r.uniform(-0.1, 0.1), d / 2 - 0.25 + r.uniform(-0.1, 0.1), zt, M(r.choice(["39502f", "4a5a36", "2c3f27"]), 0.9),
              ch=0.0, rot=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4), 0))
    for k in range(r.randint(2, 4)):   # entulho solto
        B(r.uniform(0.1, 0.3), r.uniform(0.1, 0.25), r.uniform(0.03, 0.12), r.uniform(-w / 2 + 0.3, w / 2 - 0.3), r.uniform(-d / 2 + 0.3, d / 2 - 0.3), zt,
          M(r.choice(["3a3d40", "5a5144", "46484b"]), 0.9, 0.3, 0.3), ch=0.02, rot=(0, 0, r.uniform(0, 3)))


def rodape(w, yf, alt=0.5):
    """Barra de concreto sujo no pé da fachada."""
    B(w + 0.06, 0.1, alt, 0, yf - 0.05, 0, M(CONCRETO_ESC, 0.88, 0.5, 0.35, 4.0), ch=0.02)


def cantoneiras(w, h, yf, cor=CONCRETO, larg=0.34):
    """Pilastras de canto, que sobressaem da fachada."""
    for s in (-1, 1):
        B(larg, 0.12, h, s * (w / 2 - larg / 2), yf - 0.06, 0, M(cor, 0.85, 0.5, 0.3, 4.0), ch=0.02)


def cornija(w, h, yf, cor=CONCRETO_CLARO, alt=0.2):
    B(w + 0.3, 0.3, alt, 0, yf - 0.12, h - alt, M(cor, 0.85, 0.4, 0.3), ch=0.02)


def entulho_pe(w, yf, r, n=5):
    """Caixas, tijolos e restos no pé da fachada."""
    for k in range(n):
        B(r.uniform(0.15, 0.4), r.uniform(0.12, 0.3), r.uniform(0.1, 0.25), r.uniform(-w / 2, w / 2), yf - r.uniform(0.1, 0.45), 0.0,
          M(r.choice(["6a5f4a", "55524c", "46484b"]), 0.9, 0.3, 0.3), ch=0.02, rot=(0, 0, r.uniform(0, 3)))


# ------------------------------------------------------------------ prédios
def predio_loja(r):
    """Farmácia 24 h num térreo de loja: vitrine acesa, porta, toldo e o letreiro de neon verde com a cruz."""
    w, d, h = 6.2, 2.6, 4.0
    yf = -d / 2
    B(w, d, h, 0, 0, 0, reboco("7a7468", 0.9, 0.5, 0.35, 3.0), ch=0.03)
    rodape(w, yf, 0.45)
    cantoneiras(w, h, yf, CONCRETO)
    cornija(w, h, yf)
    manchas(-w / 2 + 0.3, w / 2 - 0.3, 0.6, h - 0.3, yf, r, 9)
    # vitrine acesa, com prateleiras e produtos em silhueta
    B(3.7, 0.12, 1.7, -1.0, yf - 0.06, 0.55, metal("22262b", 0.5, 0.3, 0.2), ch=0.015)
    B(3.5, 0.02, 1.5, -1.0, yf - 0.125, 0.65, E("cfeaff", 1.15), ch=0.0)
    for k in range(3):
        B(3.4, 0.03, 0.03, -1.0, yf - 0.15, 0.9 + k * 0.4, M("20262b", 0.6), ch=0.0)
        for j in range(r.randint(5, 8)):
            B(r.uniform(0.12, 0.28), 0.02, r.uniform(0.12, 0.3), -2.6 + r.uniform(0, 3.3), yf - 0.16, 0.93 + k * 0.4,
              M(r.choice(["2a5a7a", "7a2a2a", "3a6a4a", "8a7a3a"]), 0.7), ch=0.0)
    for x in (-2.15, -1.0, 0.15):   # montantes
        B(0.06, 0.05, 1.55, x, yf - 0.14, 0.62, metal("1a1d21"), ch=0.0)
    for k in range(4):   # vidro rachado: lascas
        B(r.uniform(0.3, 0.7), 0.012, 0.015, -2.5 + r.uniform(0, 3.0), yf - 0.17, 1.0 + r.uniform(0, 1.0), M("c9e6f4", 0.2), ch=0.0,
          rot=(0, r.uniform(-0.9, 0.9), 0))
    # porta de vidro com o "24"
    B(1.15, 0.12, 2.2, 2.05, yf - 0.06, 0.0, metal("22262b", 0.5, 0.3, 0.2), ch=0.015)
    B(0.46, 0.02, 1.9, 1.78, yf - 0.125, 0.12, E("d6f2ff", 0.9), ch=0.0)
    B(0.46, 0.02, 1.9, 2.32, yf - 0.125, 0.12, M("0b1218", 0.3), ch=0.0)
    B(0.5, 0.03, 0.5, 2.32, yf - 0.14, 1.9, M("0d1014", 0.5), ch=0.0)
    texto("24", 2.32, 1.55, yf - 0.14, 0.05, E(NEON_VERDE, 2.6))
    B(0.04, 0.05, 0.3, 2.28, yf - 0.15, 0.95, M(CONCRETO_CLARO, 0.4), ch=0.0)
    toldo(-0.4, 5.4, 2.72, yf, 0.55, "2f6a45", "9aa08e", n=9, inclina=0.35)
    # letreiro: placa escura com FARMA em neon verde e a cruz
    B(5.5, 0.12, 0.95, 0, yf - 0.07, 2.95, metal("1a1d21", 0.5, 0.3, 0.2), ch=0.02)
    texto("FARMA", -0.55, 3.18, yf - 0.13, 0.095, E(NEON_VERDE, 3.0))
    B(0.55, 0.03, 0.14, 2.35, yf - 0.14, 3.34, E(NEON_VERDE, 3.0), ch=0.0)
    B(0.14, 0.03, 0.55, 2.35, yf - 0.14, 3.13, E(NEON_VERDE, 3.0), ch=0.0)
    for s in (-1, 1):   # contorno do letreiro
        B(0.035, 0.03, 0.8, s * 2.65, yf - 0.14, 3.02, E(NEON_VERDE, 2.0), ch=0.0)
    marca_x(-2.4, 3.2, yf, 0.5)
    telhado(w, d, h, r, ar=2, antena=True)
    entulho_pe(w, yf, r, 5)


def predio_bar(r):
    """Bar de tijolo escuro: porta com neon vermelho, janelas gradeadas com neon rosa e azul, letreiro BAR e toldo rasgado."""
    w, d, h = 5.6, 2.6, 4.2
    yf = -d / 2
    B(w, d, h, 0, 0, 0, tijolo(*TIJOLO_B, "2e2926"), ch=0.03)
    rodape(w, yf, 0.5)
    cantoneiras(w, h, yf, "55524f")
    cornija(w, h, yf, "7a7a76")
    manchas(-w / 2 + 0.3, w / 2 - 0.3, 0.6, h - 0.3, yf, r, 8, "14110f")
    # porta
    B(1.2, 0.12, 2.2, -1.6, yf - 0.06, 0.0, metal("1d1f23", 0.5, 0.3, 0.2), ch=0.015)
    B(0.95, 0.02, 1.95, -1.6, yf - 0.125, 0.1, M("120c10", 0.5), ch=0.0)
    B(0.8, 0.02, 0.9, -1.6, yf - 0.14, 0.9, E("ff6aa6", 0.55), ch=0.0)        # luz que vaza por dentro
    for s in (-1, 1):
        B(0.04, 0.03, 2.1, -1.6 + s * 0.5, yf - 0.14, 0.05, E(NEON_VERM, 3.0), ch=0.0)
    B(1.0, 0.03, 0.04, -1.6, yf - 0.14, 2.12, E(NEON_VERM, 3.0), ch=0.0)
    B(0.05, 0.05, 0.3, -1.35, yf - 0.16, 1.0, M(CONCRETO_CLARO, 0.4), ch=0.0)
    # janelas do térreo, com grade e brilho de neon
    for x, cor in ((0.35, NEON_ROSA), (1.95, NEON_AZUL)):
        janela(x, 0.95, 1.1, 1.05, yf, "escura", r, grade=True)
        B(0.95, 0.02, 0.9, x, yf - 0.1, 1.02, E(cor, 0.55), ch=0.0)
        B(0.85, 0.02, 0.02, x, yf - 0.115, 1.02 + 0.45, E(cor, 3.0), ch=0.0)
        B(0.3, 0.02, 0.3, x + 0.3, yf - 0.115, 1.12, E(cor, 3.0), ch=0.0, rot=(0, 0.78, 0))
    # taça de neon (triângulo, haste, base) à esquerda
    for s in (-1, 1):
        B(0.05, 0.03, 0.46, -2.45 + s * 0.1, yf - 0.14, 1.45, E(NEON_AZUL, 3.0), ch=0.0, rot=(0, -s * 0.5, 0))
    B(0.28, 0.03, 0.04, -2.45, yf - 0.14, 1.65, E(NEON_AZUL, 3.0), ch=0.0)
    B(0.04, 0.03, 0.4, -2.45, yf - 0.14, 1.0, E(NEON_AZUL, 3.0), ch=0.0)
    B(0.28, 0.03, 0.04, -2.45, yf - 0.14, 1.0, E(NEON_AZUL, 3.0), ch=0.0)
    toldo(0.15, 3.6, 2.5, yf, 0.55, "7a2a2a", "3a3330", n=7, inclina=0.4)
    # letreiro BAR
    B(4.1, 0.14, 1.0, 0.3, yf - 0.08, 2.75, metal("14161a", 0.5, 0.3, 0.2), ch=0.02)
    for xx in (-1.72, 2.32):
        B(0.04, 0.03, 0.85, xx, yf - 0.16, 2.82, E(NEON_ROSA, 2.4), ch=0.0)
    B(3.9, 0.03, 0.04, 0.3, yf - 0.16, 3.68, E(NEON_ROSA, 2.4), ch=0.0)
    B(3.9, 0.03, 0.04, 0.3, yf - 0.16, 2.8, E(NEON_ROSA, 2.4), ch=0.0)
    texto("BAR", 0.3, 2.95, yf - 0.16, 0.13, E("ff6ab6", 3.4))
    # andar de cima
    manchas(-w / 2 + 0.4, w / 2 - 0.4, 2.0, 3.9, yf, r, 5, "100d0b")
    marca_x(2.15, 2.0, yf, 0.5)
    telhado(w, d, h, r, ar=2, parabola=True)
    entulho_pe(w, yf, r, 4)


def predio_apto(r, variante="a"):
    """Prédio de apartamentos de 3 andares. a: tijolo com escada de incêndio de ferro. b: reboco azulado descascado, varandas e roupa no varal."""
    w, d, h = 5.4, 2.1, 5.8
    yf = -d / 2
    if variante == "a":
        B(w, d, h, 0, 0, 0, tijolo(*TIJOLO_A), ch=0.03)
    else:
        B(w, d, h, 0, 0, 0, reboco("56666f", 0.9, 0.6, 0.4, 3.0), ch=0.03)
        for k in range(6):   # reboco caído: tijolo aparecendo
            B(r.uniform(0.3, 0.8), 0.012, r.uniform(0.3, 0.8), r.uniform(-w / 2 + 0.5, w / 2 - 0.5), yf - 0.006, r.uniform(0.8, h - 0.8), tijolo(*TIJOLO_B),
              ch=0.0)
    rodape(w, yf, 0.55)
    cantoneiras(w, h, yf, "6a6a66" if variante == "a" else "88908c")
    cornija(w, h, yf, "7a7a74")
    manchas(-w / 2 + 0.3, w / 2 - 0.3, 0.7, h - 0.3, yf, r, 11)
    estados = {"a": [["escura", "aceso", "quebrada"], ["aceso", "tapada", "escura"]], "b": [["aceso", "escura", "aceso"], ["escura", "escura", "tapada"]]}[variante]
    xs = (-1.75, 0.0, 1.75)
    # térreo: porta e a loja fechada com grade
    B(1.1, 0.12, 2.0, -1.5, yf - 0.06, 0.0, metal("23262a", 0.5, 0.3, 0.2), ch=0.015)
    B(0.85, 0.02, 1.8, -1.5, yf - 0.125, 0.05, M("0d1013", 0.5), ch=0.0)
    B(0.12, 0.05, 0.3, -1.2, yf - 0.15, 0.9, M(CONCRETO_CLARO, 0.4), ch=0.0)
    janela(1.0, 0.65, 2.0, 1.0, yf, "tapada", r, grade=True)
    # andares 2 e 3
    for fi, zf in enumerate((2.2, 4.05)):
        for xi, x in enumerate(xs):
            if variante == "b" and fi == 0:
                B(1.2, 0.5, 0.06, x, yf - 0.28, zf - 0.02, M(CONCRETO, 0.85, 0.4, 0.3), ch=0.01)   # laje da varanda
                B(1.2, 0.03, 0.55, x, yf - 0.52, zf, metal("22262a", 0.5, 0.3, 0.2), ch=0.0)
                for j in range(7):
                    B(0.025, 0.03, 0.55, x - 0.55 + j * 0.183, yf - 0.52, zf, metal("22262a"), ch=0.0)
            janela(x, zf + 0.2, 0.85, 1.0, yf, estados[fi][xi], r)
    if variante == "a":
        escada_incendio(0.55, 2.55, yf - 0.12, [2.15, 4.0])
    else:
        barra((-1.0, yf - 0.55, 3.15), (1.0, yf - 0.62, 3.0), 0.012, M("101214", 0.5), v=6)   # varal
        for k in range(5):
            B(0.14, 0.012, 0.3, -0.8 + k * 0.4, yf - 0.58, 2.8, M(r.choice(["7a6a50", "4a5a7a", "8a8a82", "6a3a3a"]), 0.9), ch=0.0)
        B(0.7, 0.3, 0.4, -0.85, yf - 0.15, 3.65, metal("8a8e92", 0.5, 0.2, 0.2), ch=0.03)      # ar condicionado
        CR(0.14, 0.04, -0.85, yf - 0.32, 3.85, M("1c1e22", 0.6), (math.pi / 2, 0, 0), v=14)
        esfera("antena", 0.22, (1.9, yf - 0.4, 4.9), M("b4b6b2", 0.5, 0.2, 0.2), escala=(1, 0.2, 1))
    barra((-w / 2 + 0.42, yf - 0.1, 0.2), (-w / 2 + 0.42, yf - 0.1, h - 0.3), 0.045, metal("3a3e44", 0.5, 0.3, 0.3), v=8)   # tubo de descida
    marca_x(-2.1 if variante == "a" else 2.1, 1.35, yf, 0.55)
    telhado(w, d, h, r, ar=1, caixa_dagua=(variante == "a"), antena=(variante == "b"))
    entulho_pe(w, yf, r, 4)


def predio_apto_a(r):
    predio_apto(r, "a")


def predio_apto_b(r):
    predio_apto(r, "b")


def predio_torre(r):
    """Torre de escritórios de concreto e vidro escuro: janelões em fita (alguns acesos em luz fria), saguão aceso, antena com baliza vermelha."""
    w, d, h = 5.6, 2.0, 6.0
    yf = -d / 2
    B(w, d, h, 0, 0, 0, reboco("70767b", 0.88, 0.5, 0.35, 3.5), ch=0.03)
    cornija(w, h, yf, "88898a", 0.3)
    estados = [["escura", "fria", "escura", "escura"], ["fria", "escura", "quebrada", "fria"]]
    for k in range(5):
        B(0.34, 0.18, h - 0.2, -2.4 + k * 1.2, yf - 0.09, 0.0, M("5b6166", 0.88, 0.5, 0.35, 3.0), ch=0.02)
    for fi, zf in enumerate((2.4, 4.2)):
        for k in range(4):
            x = -1.8 + k * 1.2
            B(0.95, 0.06, 1.3, x, yf - 0.03, zf - 0.05, metal("22262b", 0.45, 0.3, 0.2), ch=0.01)
            st = estados[fi][k]
            gy = yf - 0.07
            if st == "fria":
                B(0.85, 0.02, 1.2, x, gy, zf, E("6fa8d0", 0.85), ch=0.0)
                for j in range(2):   # divisórias e silhuetas de mesas
                    B(0.85, 0.02, 0.03, x, gy - 0.012, zf + 0.35 + j * 0.45, M("7a8a94", 0.5), ch=0.0)
            elif st == "quebrada":
                B(0.85, 0.02, 1.2, x, gy, zf, M("070b0e", 0.3), ch=0.0)
                for j in range(5):
                    B(r.uniform(0.05, 0.14), 0.012, r.uniform(0.1, 0.35), x + r.uniform(-0.4, 0.4), gy - 0.012, zf + r.choice([0.05, 0.85]), vidro("6f8a94"),
                      ch=0.0, rot=(0, r.uniform(-0.5, 0.5), 0))
            else:
                B(0.85, 0.02, 1.2, x, gy, zf, M("0d171f", 0.12), ch=0.0)
                B(0.1, 0.012, 1.0, x - 0.2, gy - 0.012, zf + 0.1, M("2a3d4b", 0.2), ch=0.0)
            B(1.05, 0.14, 0.06, x, yf - 0.07, zf - 0.1, M(CONCRETO_CLARO, 0.85, 0.4, 0.3), ch=0.012)
    # térreo: saguão com a porta giratória acesa e vitrines escuras
    B(5.0, 0.1, 2.0, 0, yf - 0.05, 0.0, metal("1e2226", 0.45, 0.3, 0.2), ch=0.015)
    for k in range(4):
        x = -1.8 + k * 1.2
        if k == 1:
            B(1.0, 0.03, 1.8, x, yf - 0.11, 0.1, E("8fc4e6", 0.85), ch=0.0)
            CR(0.3, 0.03, x, yf - 0.14, 0.9, M("0d1014", 0.4), (math.pi / 2, 0, 0), v=18)
            B(0.05, 0.03, 1.5, x, yf - 0.16, 0.15, metal("2a2e33"), ch=0.0)
        else:
            B(0.95, 0.03, 1.7, x, yf - 0.11, 0.15, M("0b1217", 0.15) if k != 3 else E("6fa8d0", 0.8), ch=0.0)
    B(5.2, 0.14, 0.12, 0, yf - 0.1, 2.05, M("2a2d30", 0.5, 0.3, 0.2), ch=0.015)
    manchas(-w / 2 + 0.3, w / 2 - 0.3, 0.5, h - 0.3, yf, r, 10, "1a1b1d", larg=(0.06, 0.2))
    telhado(w, d, h, r, ar=2, alt_parapeito=0.3)
    # letreiro HOTEL em neon vermelho, em pé no teto, sobre a platibanda da frente
    ys = yf + 0.45
    for sx in (-1.45, 1.45):
        B(0.07, 0.07, 0.75, sx, ys, h + 0.3, metal(METAL_ESC), ch=0.0)
    B(3.2, 0.1, 0.95, 0, ys, h + 0.62, metal("1a1d21", 0.5, 0.3, 0.2), ch=0.02)
    texto("HOTEL", 0.0, h + 0.78, ys - 0.05, 0.12, E(NEON_VERM, 3.2))
    B(3.0, 0.03, 0.035, 0, ys - 0.06, h + 0.64, E(NEON_VERM, 2.4), ch=0.0)
    B(3.0, 0.03, 0.035, 0, ys - 0.06, h + 1.5, E(NEON_VERM, 2.4), ch=0.0)
    # antena com baliza vermelha
    barra((1.9, 0.1, h + 0.1), (1.9, 0.1, h + 1.1), 0.03, metal(METAL_ESC), v=8)
    for k in range(3):
        B(0.5 - 0.12 * k, 0.02, 0.025, 1.9, 0.1, h + 0.45 + 0.2 * k, metal(METAL_ESC), ch=0.0)
    esfera("baliza", 0.06, (1.9, 0.1, h + 1.14), E(NEON_VERM, 4.0))
    # letreiro apagado da empresa: placa no alto
    B(2.2, 0.08, 0.45, -1.4, yf - 0.1, h - 0.85, metal("1b1e22", 0.5, 0.3, 0.2), ch=0.015)
    for k in range(4):
        B(0.3, 0.02, 0.3, -2.3 + k * 0.45, yf - 0.15, h - 0.78, M("2a2d30", 0.5), ch=0.0)


def predio_ruina(r):
    """Prédio que desabou em parte: o térreo e a ala esquerda de pé, a fachada do meio-direita caída (laje do 2o andar à vista, parede de fundo com
    quartos abertos, ferros de armação), entulho no pé."""
    w, d, h = 5.8, 2.2, 5.2
    yf = -d / 2
    parede = tijolo("6e4a3e", "593a30", "2f2a27")
    conc = M(CONCRETO, 0.9, 0.5, 0.3)
    B(w, d, 2.9, 0, 0, 0, parede, ch=0.03)                                     # térreo inteiro
    B(2.1, d, 2.3, -1.85, 0, 2.9, parede, ch=0.03)                             # ala esquerda sobe até 5,2
    B(w, d, 0.2, 0, 0, 2.8, conc, ch=0.02)                                     # laje do 2o andar (aparece onde a fachada caiu)
    B(0.9, d, 0.9, 2.45, 0, 2.9, parede, ch=0.03)                              # toco da direita (até 3,8)
    # parede de fundo, que ficou: quartos abertos, escura, com a borda de cima rasgada
    B(3.7, 0.25, 2.0, 0.45, d / 2 - 0.15, 3.0, tijolo("5a3e34", "4a3028", "2a2623"), ch=0.0)
    for k, (bx, bw, bh) in enumerate(((-1.0, 0.9, 0.5), (0.0, 0.8, 0.9), (1.0, 0.9, 0.3), (1.8, 0.6, 0.6))):   # borda de cima irregular
        B(bw, 0.25, bh, bx, d / 2 - 0.15, 5.0, tijolo("5a3e34", "4a3028", "2a2623"), ch=0.03, rot=(0, 0, r.uniform(-0.05, 0.05)))
    B(3.4, 0.05, 1.5, 0.5, d / 2 - 0.3, 3.1, M("20262a", 0.95, 0.4, 0.4), ch=0.0)       # sombra do quarto
    # móveis e restos dentro: cama, armário, geladeira tombada
    B(1.0, 0.7, 0.45, -0.1, 0.1, 3.0, M("3a3028", 0.9, 0.3, 0.3), ch=0.03, rot=(0, 0, 0.3))
    B(0.6, 0.5, 1.0, 1.3, 0.25, 3.0, M("4a4a4c", 0.7, 0.3, 0.3), ch=0.03)
    B(0.5, 0.4, 0.9, 0.5, 0.35, 3.0, M("6a5a44", 0.9, 0.4, 0.3), ch=0.03, rot=(0, 0, 0.5))
    # ferros de armação saindo das quebras e um pedaço de laje pendurado
    for k in range(9):
        a = r.uniform(-0.6, 3.0)
        barra((a, yf + 0.1, 3.0), (a + r.uniform(-0.2, 0.2), yf - r.uniform(0.2, 0.7), 3.0 + r.uniform(-0.2, 0.3)), 0.014, M(FERRUGEM, 0.8, 0.4, 0.4), v=6)
    B(1.1, 0.9, 0.12, 2.35, yf + 0.4, 3.9, conc, ch=0.02, rot=(0.5, 0.0, 0.1))
    for k in range(5):
        a = r.uniform(1.6, 3.0)
        barra((a, yf + 0.3, 3.8), (a + r.uniform(-0.1, 0.1), yf - r.uniform(0.2, 0.5), 3.5), 0.014, M(FERRUGEM, 0.8, 0.4, 0.4), v=6)
    rodape(w, yf, 0.55)
    cantoneiras(w, 2.9, yf, "5e5d58")
    janela(-2.0, 3.45, 0.85, 1.0, yf, "escura", r)
    janela(-2.0, 1.65, 0.85, 1.0, yf, "tapada", r)
    janela(-0.7, 1.55, 0.9, 1.0, yf, "escura", r)
    janela(1.3, 1.55, 0.9, 1.0, yf, "quebrada", r)
    B(1.1, 0.12, 2.0, 2.1, yf - 0.06, 0.0, metal("23262a", 0.5, 0.3, 0.2), ch=0.015)
    B(0.85, 0.02, 1.8, 2.1, yf - 0.125, 0.05, M("0d1013", 0.5), ch=0.0)
    for x in (-0.7, 1.3):   # fuligem em cima das janelas queimadas
        B(1.3, 0.012, 0.9, x, yf - 0.007, 2.55, M("0e0d0c", 0.95, 0.3, 0.3), ch=0.0)
    manchas(-w / 2 + 0.3, w / 2 - 0.3, 0.7, 2.9, yf, r, 8, "100e0c")
    marca_x(-2.2, 0.95, yf, 0.55)
    telhado_resto(-1.85, 2.1, d, 5.2, r)
    # montanha de entulho no pé: concreto, tijolo, ferros e uma laje inclinada
    for k in range(26):
        x = r.uniform(-w / 2 + 0.2, w / 2 + 0.2)
        y = yf - r.uniform(0.1, 1.0) * (1.0 - abs(x) / (w / 2 + 0.4)) - 0.1
        s = r.uniform(0.14, 0.5)
        B(s, s * r.uniform(0.6, 1.2), s * r.uniform(0.3, 0.8), x, y, 0.0, M(r.choice([CONCRETO, "5a5750", "7a4034", "46484b", "6f4a3c"]), 0.9, 0.5, 0.3),
          ch=0.03, rot=(r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), r.uniform(0, 3)))
    B(1.4, 0.9, 0.14, 0.8, yf - 0.5, 0.28, conc, ch=0.02, rot=(0.35, 0, 0.1))
    for k in range(6):
        barra((r.uniform(-1.5, 2.0), yf - r.uniform(0.2, 0.9), 0.15), (r.uniform(-1.5, 2.0), yf - r.uniform(0.2, 1.0), r.uniform(0.5, 1.0)), 0.014,
              M(FERRUGEM, 0.8, 0.4, 0.4), v=6)


def telhado_resto(x, w, d, z, r):
    """O pedaço de teto que sobrou na ala esquerda da ruína: piche rasgado, platibanda quebrada e uma caixa d'água caída."""
    B(w, d, 0.1, x, 0, z, M("2d2f33", 0.95, 0.5, 0.35, 5.0), ch=0.01)
    pc = M("6a6c6e", 0.9, 0.4, 0.3, 4.0)
    B(w + 0.18, 0.18, 0.4, x, -d / 2 - 0.02, z, pc, ch=0.02)
    B(0.18, d + 0.2, 0.4, x - w / 2, 0, z, pc, ch=0.02)
    B(0.18, d + 0.2, 0.25, x + w / 2, 0, z, pc, ch=0.02, rot=(0, 0, 0.0))
    B(w, 0.18, 0.4, x, d / 2, z, pc, ch=0.02)
    B(w + 0.24, 0.24, 0.07, x, -d / 2 - 0.02, z + 0.4, M(CONCRETO_CLARO, 0.85, 0.4, 0.3), ch=0.015)
    for k in range(4):
        B(r.uniform(0.3, 0.8), r.uniform(0.3, 0.6), 0.012, x + r.uniform(-0.7, 0.7), r.uniform(-0.4, 0.4), z + 0.1, M(r.choice(["3c3f43", "25272a", "4a4c4f"]), 0.95, 0.5, 0.4),
          ch=0.0, rot=(0, 0, r.uniform(-0.2, 0.2)))
    C(0.45, 0.7, x + 0.3, 0.1, z + 0.1, M("6a4a30", 0.9, 0.6, 0.4, 14.0), v=16)
    for k in range(3):
        B(r.uniform(0.1, 0.25), r.uniform(0.1, 0.2), r.uniform(0.03, 0.1), x + r.uniform(-0.8, 0.8), r.uniform(-0.4, 0.4), z + 0.1, M("46484b", 0.9, 0.3, 0.3), ch=0.02,
          rot=(0, 0, r.uniform(0, 3)))

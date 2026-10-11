"""Chão da floresta amaldiçoada à noite (protótipo 2.5D cara nova), procedural: só numpy e Pillow.

Saídas em jogos/hordas/projeto/prototipos/piso/:
    piso.png         albedo 512x512 sem emenda, 1 texel = 1 px de tela a 960x540. Paleta fixa (PAL), sem dithering.
    piso_normal.png  normal map (R = x, G = y para cima, B = z, convenção de cara_nova/LEIA-ME.md). A altura sai das
                     próprias formas: domo por pedra, raízes e gravetos elevados, rachaduras afundadas, musgo um pouco alto.

Prévia (sem Godot) em jogos/hordas/prints/prototipo_piso_novo.png, 4 painéis de 960x540:
    (a) albedo (2x2 cópias do quadro de 512, a emenda aparece em x=512 e y=512 se existir);
    (b) luz laranja à esquerda (Lambert com o normal, ambiente 0,15);  (c) luz roxa à direita;
    (d) recorte de 240x135 do albedo ampliado 4x, para ver o pixel.

Como o chão é montado:
    1. Zonas grandes (100 a 200 px): terra batida x musgo, por ruído periódico com domain warping e borda esfiapada.
    2. Elementos com forma, colocados por amostragem de Poisson ponderada (mínimo de distância + densidade alta perto
       da borda das zonas e agrupada por ruído): pedras, tufos de grama, montinhos de folhas, raízes, gravetos, rachaduras.
    3. Todo detalhe claro faz parte de uma forma (aresta de pedra, ponta de lâmina, borda de raiz); uma passada final
       remove qualquer pixel claro isolado.
Todas as colocações usam wrap (módulo N), então o quadro emenda. A semente é fixa: a mesma execução gera o mesmo PNG.

Uso (Python 3 com numpy e Pillow), de qualquer pasta:
    python jogos/hordas/prototipos/cara_nova/piso/gerar_piso.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
HORDAS = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
SAIDA = os.path.join(HORDAS, "projeto", "prototipos", "piso")
PREVIA = os.path.join(HORDAS, "prints", "prototipo_piso_novo.png")

N = 512
TELA_W, TELA_H = 960, 540
SEMENTE = 2611
rng = np.random.default_rng(SEMENTE)

# Paleta (30 cores). Base: docs/visual_2_5d/paleta.json (fogo, painel) e amostras do chão de
# fonte_arte/entrada_fonte.webp (musgo verde-oliva, laje marrom-acinzentada, folha vermelha, sombra quase preta).
# O albedo é escuro de propósito (noite); a luz do jogo é que clareia.
PAL = {
    "terra1": "#25211c", "terra2": "#2f2920", "terra3": "#3a3126", "terra4": "#4a3d2f",
    "musgo1": "#1c281d", "musgo2": "#243323", "musgo3": "#2e412c", "musgo4": "#455f34", "musgo5": "#718f3c",
    "erva_base": "#284a28", "erva": "#4a7632", "erva_luz": "#88b345",
    "pedra_sombra": "#0f1210", "pedra1": "#384443", "pedra2": "#586966", "pedra3": "#83968f", "pedra_luz": "#c0d3c9",
    "tan1": "#4c4031", "tan2": "#6c5c4a", "tan3": "#968365", "tan_luz": "#c8b38a",
    "folha_marrom": "#543321", "folha_ocre": "#9c612c", "folha_verm_esc": "#8d211a", "folha_verm": "#ec4024",
    "raiz_sombra": "#0d0908", "raiz": "#4a2e1f", "raiz_luz": "#9c6940",
    "galho": "#745637",
    "fenda": "#07090a",
}
NOMES = list(PAL)
IDX = {k: i for i, k in enumerate(NOMES)}
PAL_RGB = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in PAL.values()], dtype=np.uint8)
CLARAS = [IDX[k] for k in ("musgo5", "erva_luz", "pedra_luz", "tan_luz", "pedra3", "tan3", "folha_verm", "folha_ocre",
                           "raiz_luz", "terra4")]

YY, XX = np.mgrid[0:N, 0:N]
col = np.zeros((N, N), np.int16)
alt = np.zeros((N, N), np.float32)


# ---------------------------------------------------------------- ruído periódico, warp, amostragem
def ruido_z(sigma):
    """Ruído gaussiano periódico (filtro no domínio da frequência), média 0, desvio 1."""
    w = rng.standard_normal((N, N))
    k = np.fft.fftfreq(N)
    k2 = k[:, None] ** 2 + k[None, :] ** 2
    r = np.fft.ifft2(np.fft.fft2(w) * np.exp(-2 * (np.pi * sigma) ** 2 * k2)).real
    return (r - r.mean()) / r.std()


def unif(sigma):
    """Ruído periódico com histograma uniforme em 0..1 (zonas equilibradas)."""
    r = ruido_z(sigma)
    rank = np.argsort(np.argsort(r.ravel()))
    return (rank / (r.size - 1)).reshape(N, N)


def amostrar(campo, dx, dy):
    return campo[(YY + np.round(dy).astype(int)) % N, (XX + np.round(dx).astype(int)) % N]


def borra(a, vezes=1):
    for _ in range(vezes):
        a = (np.roll(a, 1, 0) + 2 * a + np.roll(a, -1, 0)) / 4
        a = (np.roll(a, 1, 1) + 2 * a + np.roll(a, -1, 1)) / 4
    return a


def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def poisson(alvo, dmin, dens, tentativas=60000, ocupados=None):
    """Dart throwing ponderado por `dens` (campo NxN, 0..1), com distância mínima `dmin` e wrap. Devolve [(x, y)]."""
    pts = np.zeros((0, 2))
    out = []
    xs = rng.integers(0, N, tentativas)
    ys = rng.integers(0, N, tentativas)
    ps = rng.random(tentativas)
    for x, y, p in zip(xs, ys, ps):
        if p > dens[y, x]:
            continue
        if len(pts):
            d = np.abs(pts - (x, y))
            d = np.minimum(d, N - d)
            if (d[:, 0] ** 2 + d[:, 1] ** 2 < dmin * dmin).any():
                continue
        pts = np.vstack([pts, (x, y)])
        out.append((int(x), int(y)))
        if len(out) >= alvo:
            break
    return out


def pinta(cy, cx, mascara, cores, alturas=None, modo="max"):
    """Escreve um recorte local (cy, cx = canto superior esquerdo) com wrap. cores: grade de índices (<0 = não mexe)."""
    h, w = mascara.shape
    ys = (cy + np.arange(h)) % N
    xs = (cx + np.arange(w)) % N
    ix = np.ix_(ys, xs)
    m = mascara & (cores >= 0)
    col[ix] = np.where(m, cores, col[ix])
    if alturas is not None:
        a = alt[ix]
        if modo == "max":
            novo = np.maximum(a, alturas)
        elif modo == "min":
            novo = np.minimum(a, alturas)
        else:
            novo = alturas
        alt[ix] = np.where(m, novo, a)


def desloca(m, dy, dx):
    return np.roll(np.roll(m, dy, 0), dx, 1)


# ---------------------------------------------------------------- 1. zonas e base
def base():
    global ZM
    dx = 46 * ruido_z(34)
    dy = 46 * ruido_z(34)
    z = amostrar(unif(52), dx, dy)  # domain warping: a borda das zonas serpenteia
    ragged = (unif(5) - 0.5) * 0.30 + (unif(2.2) - 0.5) * 0.10
    ZM = z + ragged  # >0.5 = musgo; a borda é esfiapada em manchas de 5 a 30 px
    musgo = ZM > 0.5
    prof = suave(0.5, 0.78, ZM)  # quão fundo no musgo

    # terra batida: tons de baixo contraste com borda esfiapada, mais placas claras pequenas
    t = unif(15) + (unif(3) - 0.5) * 0.14
    terra = np.where(t < 0.20, IDX["terra1"], np.where(t < 0.86, IDX["terra2"], IDX["terra3"]))
    placas = limpa((unif(6) > 0.93) & (unif(1.6) > 0.35), 3)
    terra = np.where(placas, IDX["terra4"], terra)
    # grão de terra: traços de 2 a 3 px, só escuros (nada de ponto claro)
    for _ in range(380):
        x, y = rng.integers(0, N, 2)
        for i in range(int(rng.integers(2, 4))):
            terra[y % N, (x + i) % N] = IDX["terra1"]

    # musgo: base de três tons quase iguais + tufinhos de 2 a 6 px em grupos, com aresta de luz no topo
    m = unif(10) + (unif(3) - 0.5) * 0.16
    musgo_base = np.where(m < 0.14, IDX["musgo1"], np.where(m < 0.80, IDX["musgo2"], IDX["musgo3"]))
    grupo = suave(0.50, 0.80, unif(14))
    tufos = limpa(unif(1.5) > (0.993 - 0.13 * grupo - 0.03 * prof), 4)
    topo = tufos & ~desloca(tufos, 1, 0) & desloca(tufos, -1, 0) & desloca(tufos, -2, 0)
    musgo_base = np.where(tufos, IDX["musgo4"], musgo_base)
    musgo_base = np.where(topo & (grupo > 0.4), IDX["musgo5"], musgo_base)

    col[:] = np.where(musgo, musgo_base, terra)
    # altura: musgo um pouco elevado e tufos mais ainda (formas, não ruído)
    alt[:] = borra(musgo.astype(np.float32) * 0.25, 2) + borra((tufos & musgo).astype(np.float32) * 0.35, 1)


def limpa(m, minimo=3):
    """Remove pixels de máscara com menos de `minimo - 1` vizinhos 4-conexos (nada de ponto solto)."""
    viz = desloca(m, 1, 0).astype(int) + desloca(m, -1, 0) + desloca(m, 0, 1) + desloca(m, 0, -1)
    return m & (viz >= minimo - 1)


# ---------------------------------------------------------------- densidades
def densidades():
    borda = np.exp(-(((ZM - 0.5) / 0.15) ** 2))  # 1 na borda entre zonas, ~0 no miolo
    musgo = suave(0.45, 0.62, ZM)

    def grupos(sigma, a, b):
        return suave(a, b, unif(sigma))

    return borda, musgo, grupos


# ---------------------------------------------------------------- pedras
def pedra(cx, cy, w, familia, em_musgo):
    h = max(2, int(round(w * 0.7))) + (1 if w >= 6 else 0)
    pad = 3
    H, W = h + 2 * pad, w + 2 * pad + 1
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cyl = (H - 1) / 2 + rng.uniform(-0.3, 0.3)
    cxl = (W - 1) / 2 + rng.uniform(-0.3, 0.3)
    u = (xx - cxl) / (w / 2)
    v = (yy - cyl) / (h / 2)
    th = np.arctan2(v, u)
    f = rng.uniform(0, 6.28, 3)
    r = 1 + 0.15 * np.cos(2 * th + f[0]) + 0.11 * np.cos(3 * th + f[1]) + 0.06 * np.cos(5 * th + f[2])
    rho2 = (u * u + v * v) / (r * r)
    lim = 1.0
    while (rho2 <= lim).sum() < 4:
        lim += 0.15
    m = rho2 <= lim
    dome = np.sqrt(np.clip(1 - rho2 / lim, 0, 1))
    hs = 0.34 * w + 0.7
    a = hs * dome

    s = -(0.55 * u + 0.85 * v) + 0.0
    for _ in range(1 if w < 7 else 2):  # facetas: planos aleatórios dão cara de pedra lascada
        ph = rng.uniform(0, 6.28)
        s = s + 0.55 * np.sign(u * np.cos(ph) + v * np.sin(ph) - rng.uniform(-0.3, 0.3))
    s = s + 0.3 * dome
    if familia == "cinza":
        c0, c1, c2, c3, cl = (IDX[k] for k in ("pedra_sombra", "pedra1", "pedra2", "pedra3", "pedra_luz"))
    else:
        c0, c1, c2, c3, cl = (IDX[k] for k in ("pedra_sombra", "tan1", "tan2", "tan3", "tan_luz"))
    corpo = np.where(s > 0.55, c3, np.where(s > -0.05, c2, np.where(s > -0.8, c1, c0)))
    if w <= 4:
        corpo = np.where(s > 0.0, c2, c1)
    topo = m & ~desloca(m, 1, 0)
    fundo = m & ~desloca(m, -1, 0)
    cores = np.where(m, corpo, -1)
    if h >= 3:
        cores = np.where(topo & (s > -0.6), cl if w >= 5 else c3, cores)
    cores = np.where(fundo, c0, cores)
    if w >= 8:  # rachadura curta na pedra grande
        y, x = int(cyl - 1), int(cxl - w // 4)
        for _ in range(w):
            if m[y, x] and not topo[y, x]:
                cores[y, x] = c0
            x += 1
            y += int(rng.integers(0, 2)) if rng.random() < 0.5 else 0
            y = min(max(y, 0), H - 1)
            x = min(x, W - 1)
    if em_musgo and w >= 5:  # capa de musgo no topo
        capa = topo | desloca(topo, 1, 0)
        capa = capa & m & (rng.random(m.shape) < 0.75)
        capa = limpa(capa, 2) & ~fundo
        cores = np.where(capa, IDX["musgo3"] if rng.random() < 0.5 else IDX["musgo4"], cores)
    # sombra projetada (luz vem de cima à esquerda)
    sh = desloca(m, 1 + (w >= 6), 1 + (w >= 8)) | desloca(m, 1, 0)
    sh = sh & ~m
    full = np.where(sh, IDX["fenda"], -1)
    pinta(cy - H // 2, cx - W // 2, sh, full)
    pinta(cy - H // 2, cx - W // 2, m, cores, a)


def plano_pedras(borda, musgo, grupos):
    """Sorteia os grupos de pedras (uma principal + pedrinhas em volta); o desenho vem depois das folhas."""
    dens = (0.08 + 0.92 * borda) * (0.02 + grupos(18, 0.50, 0.80))
    plano = []
    for sx, sy in poisson(34, 20, dens):
        em_m = ZM[sy, sx] > 0.5
        fam = "cinza" if (em_m or rng.random() < 0.3) else "tan"
        w = int(rng.choice([4, 5, 6, 7, 8, 9, 10], p=[0.04, 0.08, 0.16, 0.22, 0.24, 0.16, 0.10]))
        pedras_grupo = [(sx, sy, w)]
        if rng.random() < 0.55:  # segunda pedra grande encostada na primeira
            pedras_grupo.append((int(sx + rng.choice([-1, 1]) * (w * 0.7 + 3)), int(sy + rng.integers(-3, 5)),
                                 int(rng.integers(5, 9))))
        for _ in range(int(rng.integers(3, 8))):
            ang = rng.uniform(0, 6.28)
            dist = rng.uniform(w * 0.5 + 4, 24)
            pw = int(rng.choice([3, 4, 5, 6], p=[0.38, 0.30, 0.20, 0.12]))
            pedras_grupo.append((int(sx + np.cos(ang) * dist * 1.3), int(sy + np.sin(ang) * dist * 0.8), pw))
        plano.append((fam, pedras_grupo))
    return plano


def desenha_pedras(plano):
    for fam, grupo in plano:
        for x, y, w in sorted(grupo, key=lambda t: t[1]):  # de cima para baixo: quem está à frente cobre
            pedra(x, y, w, fam, ZM[y % N, x % N] > 0.5)


# ---------------------------------------------------------------- folhas
def folha(cx, cy, cor):
    comp = int(rng.integers(2, 5))
    larg = 1.6
    ang = rng.uniform(0, np.pi)
    pad = 3
    S = comp + 2 * pad
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    c = (S - 1) / 2
    ux = (xx - c) * np.cos(ang) + (yy - c) * np.sin(ang)
    uy = -(xx - c) * np.sin(ang) + (yy - c) * np.cos(ang)
    m = (ux / (comp / 2 + 0.2)) ** 2 + (uy / (larg / 2 + 0.1)) ** 2 <= 1.0
    if m.sum() < 2:
        m[int(c), int(c)] = m[int(c), int(c) + 1] = True
    cores = np.where(m, IDX[cor], -1)
    sombra = m & ~desloca(m, -1, 0)  # pixel de baixo mais escuro, só em folha de 3 px ou mais
    escuro = {"folha_ocre": "folha_marrom", "folha_marrom": "folha_marrom", "folha_verm_esc": "folha_marrom",
              "folha_verm": "folha_verm_esc"}[cor]
    if m.sum() >= 4:
        cores = np.where(sombra, IDX[escuro], cores)
    pinta(cy - S // 2, cx - S // 2, m, cores, np.where(m, 0.35, 0), "max")


def folha_estrela(cx, cy):
    """Folha vermelha de 5 pontas, pequena (como as da referência)."""
    pts = [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, -1), (-2, -1), (1, 2), (-1, 2), (0, -2)]
    keep = [p for p in pts if p in pts[:5] or rng.random() < 0.7]
    m = np.zeros((7, 7), bool)
    cores = np.full((7, 7), -1, np.int16)
    for x, y in keep:
        m[y + 3, x + 3] = True
        cores[y + 3, x + 3] = IDX["folha_verm_esc"] if (x, y) != (0, 0) else IDX["folha_verm"]
    pinta(cy - 3, cx - 3, m, cores, np.where(m, 0.4, 0))


def folhas(borda, musgo, grupos, plano):
    dens = (0.10 + 0.9 * borda) * (0.04 + grupos(14, 0.50, 0.76))
    sementes = poisson(40, 15, dens)
    # montinhos também junto das pedras (as folhas se acumulam contra elas)
    for fam, grupo in plano:
        if rng.random() < 0.6:
            x, y, w = grupo[0]
            sementes.append((int(x + rng.choice([-1, 1]) * (w * 0.6 + 3)), int(y + w * 0.3)))
    nomes = ["folha_marrom", "folha_ocre", "folha_verm_esc", "folha_verm"]
    p = [0.38, 0.40, 0.16, 0.06]
    for sx, sy in sementes:
        for _ in range(int(rng.integers(5, 13))):
            folha(int(sx + rng.normal(0, 5.5)), int(sy + rng.normal(0, 3.8)), str(rng.choice(nomes, p=p)))
        if rng.random() < 0.2:
            folha_estrela(int(sx + rng.normal(0, 4)), int(sy + rng.normal(0, 3)))
    return len(sementes)


# ---------------------------------------------------------------- grama
def tufo(cx, cy):
    n = int(rng.integers(6, 12))
    base_ang = np.linspace(-58, 58, n) + rng.normal(0, 6, n)
    sh = np.zeros((10, 14), bool)
    sh[8, 4:10] = True
    pinta(cy - 7, cx - 7, np.pad(sh, 0), np.where(sh, IDX["fenda"], -1))  # sombra de contato
    tipo = int(rng.integers(0, 2))
    for a in base_ang:
        comp = (4 + 7 * (1 - abs(a) / 70)) * rng.uniform(0.7, 1.15)
        ang = np.radians(a)
        curva = rng.normal(0, 0.05)
        x, y = float(cx + (a / 58) * 2.0), float(cy)
        passos = int(round(comp))
        for i in range(passos):
            ix, iy = int(round(x)), int(round(y))
            if i < passos * 0.35:
                c = IDX["erva_base"]
            elif i < passos - 1 or passos < 4:
                c = IDX["erva"]
            else:
                c = IDX["erva_luz"] if tipo == 0 else IDX["erva"]
            col[iy % N, ix % N] = c
            alt[iy % N, ix % N] = max(alt[iy % N, ix % N], 0.7)
            x += np.sin(ang)
            y -= np.cos(ang)
            ang += curva


def grama(borda, musgo, grupos):
    dens = (0.05 + 0.95 * borda) * (0.25 + 0.75 * musgo) * (0.03 + grupos(16, 0.45, 0.72))
    sementes = poisson(70, 11, dens)
    for sx, sy in sementes:
        for _ in range(int(rng.integers(1, 4))):
            tufo(int(sx + rng.normal(0, 4)), int(sy + rng.normal(0, 3)))
    return len(sementes)


# ---------------------------------------------------------------- raízes, gravetos, rachaduras
def anda(x, y, ang, comp, largura, prof, mask, grosso, fase=None, curva=0.22):
    fase = rng.uniform(0, 6.28) if fase is None else fase
    t = 0
    prox = int(rng.integers(8, 16))
    while t < comp:
        ix, iy = int(round(x)), int(round(y))
        espessura = largura if t < comp * 0.55 else 1
        mask[iy % N, ix % N] = True
        if espessura >= 2:
            grosso[iy % N, ix % N] = True
            mask[(iy + 1) % N, ix % N] = True
            grosso[(iy + 1) % N, ix % N] = True
            mask[iy % N, (ix + 1) % N] = True
            grosso[iy % N, (ix + 1) % N] = True
        ang += rng.normal(0, curva) + 0.12 * np.sin(t / 8.0 + fase)
        x += np.cos(ang)
        y += np.sin(ang)
        t += 1
        if prof < 2 and t > prox and t < comp - 6:
            lado = 1 if rng.random() < 0.5 else -1
            anda(x, y, ang + lado * rng.uniform(0.5, 1.1), (comp - t) * rng.uniform(0.35, 0.7), 1, prof + 1, mask,
                 grosso)
            prox = t + int(rng.integers(10, 22))


def raizes(borda, musgo, grupos):
    mask = np.zeros((N, N), bool)
    grosso = np.zeros((N, N), bool)
    dens = 0.05 + 0.95 * borda
    for sx, sy in poisson(13, 40, dens):
        anda(sx, sy, rng.uniform(0, 6.28), rng.uniform(55, 130), 2, 0, mask, grosso)
    raiz_m = mask
    top = raiz_m & ~desloca(raiz_m, 1, 0) & desloca(grosso, -1, 0)  # aresta de luz só onde a raiz tem 2 px
    bot = raiz_m & ~desloca(raiz_m, -1, 0) & grosso
    sombra = desloca(grosso, 1, 1) & ~raiz_m
    col[sombra] = IDX["fenda"]
    col[raiz_m] = IDX["raiz"]
    col[top] = IDX["raiz_luz"]
    col[bot] = IDX["raiz_sombra"]
    a = borra(grosso.astype(np.float32) * 1.7 + (raiz_m & ~grosso) * 0.9, 1)
    np.maximum(alt, np.where(raiz_m, np.maximum(a, 0.9), alt), out=alt)


def gravetos(borda, musgo, grupos):
    mask = np.zeros((N, N), bool)
    dens = (0.08 + 0.92 * borda) * (0.05 + grupos(14, 0.5, 0.75))
    for sx, sy in poisson(40, 12, dens):
        x, y = float(sx), float(sy)
        ang = rng.uniform(0, 6.28)
        for seg in range(int(rng.integers(2, 4))):
            comp = int(rng.integers(5, 11))
            for _ in range(comp):
                mask[int(round(y)) % N, int(round(x)) % N] = True
                x += np.cos(ang)
                y += np.sin(ang)
            if rng.random() < 0.7:  # forquilha curta
                fa = ang + rng.choice([-1, 1]) * rng.uniform(0.5, 0.9)
                fx, fy = x, y
                for _ in range(int(rng.integers(3, 6))):
                    mask[int(round(fy)) % N, int(round(fx)) % N] = True
                    fx += np.cos(fa)
                    fy += np.sin(fa)
            ang += rng.uniform(-0.6, 0.6)
    sombra = desloca(mask, 1, 1) & ~mask
    col[sombra] = IDX["fenda"]
    col[mask] = IDX["galho"]
    np.maximum(alt, borra(mask.astype(np.float32) * 0.9, 1), out=alt)


def rachaduras():
    mask = np.zeros((N, N), bool)
    dens = (1 - suave(0.40, 0.55, ZM)) * 0.6 * (0.1 + suave(0.35, 0.8, unif(22)))
    for sx, sy in poisson(11, 40, dens):
        def risco(x, y, ang, comp, prof):
            for t in range(int(comp)):
                mask[int(round(y)) % N, int(round(x)) % N] = True
                ang += rng.normal(0, 0.30) + (rng.choice([-1, 1]) * 0.9 if rng.random() < 0.05 else 0)
                x += np.cos(ang)
                y += np.sin(ang)
                if prof < 2 and rng.random() < 0.04:
                    risco(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.6, 1.2), comp * rng.uniform(0.2, 0.5),
                          prof + 1)
        risco(float(sx), float(sy), rng.uniform(0, 6.28), rng.uniform(25, 70), 0)
    mask = mask & (ZM < 0.55)
    mask = limpa(mask, 2)
    col[mask] = IDX["fenda"]
    a = borra(mask.astype(np.float32) * -1.4, 1)
    np.minimum(alt, np.where(mask | (a < -0.3), a, alt), out=alt)


# ---------------------------------------------------------------- finalização
def vizinho8(m):
    r = np.zeros_like(m)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                r |= desloca(m, dy, dx)
    return r


def sem_pontos_claros():
    """Todo pixel claro precisa ter um vizinho (8-conexo) da mesma cor; senão vira a cor do vizinho de cima."""
    total = 0
    for _ in range(2):
        for c in CLARAS:
            m = col == c
            viz = vizinho8(m)
            solto = m & ~viz
            if solto.any():
                total += int(solto.sum())
                col[solto] = np.roll(col, 1, 0)[solto]
    return total


def conta_pontos_claros():
    n = 0
    for c in CLARAS:
        m = col == c
        n += int((m & ~vizinho8(m)).sum())
    return n


S_NORMAL = 1.1


def normal_de(a):
    """Altura -> normal (R = x, G = y para cima, B = z). Diferença central com wrap."""
    gx = (np.roll(a, -1, axis=1) - np.roll(a, 1, axis=1)) / 2.0
    gy = (np.roll(a, -1, axis=0) - np.roll(a, 1, axis=0)) / 2.0
    nx = -gx * S_NORMAL
    ny = gy * S_NORMAL  # y da imagem cresce para baixo; G precisa crescer para cima
    nz = np.ones_like(a)
    norma = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    v = np.stack([nx / norma, ny / norma, nz / norma], axis=-1)
    return np.clip(v * 0.5 + 0.5, 0, 1)


def construir():
    base()
    borda, musgo, grupos = densidades()
    rachaduras()
    raizes(borda, musgo, grupos)
    gravetos(borda, musgo, grupos)
    plano = plano_pedras(borda, musgo, grupos)
    folhas(borda, musgo, grupos, plano)
    grama(borda, musgo, grupos)
    desenha_pedras(plano)
    return sem_pontos_claros()


# ---------------------------------------------------------------- prévia
def mosaico(a, w=TELA_W, h=TELA_H):
    return np.tile(a, (2, 2, 1))[:h, :w]


def iluminar(alb, nor, luz_xy, altura, raio, energia, cor, ambiente):
    """Lambert com o normal + queda quadrática pela distância (luz pontual, altura em px de tela)."""
    H, W = alb.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    lx, ly = luz_xy
    dx = lx - xx
    dy = yy - ly  # y para cima: luz acima do pixel tem dy > 0
    dist2d = np.sqrt(dx ** 2 + dy ** 2)
    dist = np.sqrt(dist2d ** 2 + altura ** 2)
    ndl = np.clip(nor[..., 0] * dx / dist + nor[..., 1] * dy / dist + nor[..., 2] * altura / dist, 0, 1)
    atten = np.clip(1 - dist2d / raio, 0, 1) ** 2
    luz = ambiente + np.array(cor, np.float32)[None, None, :] * energia * (ndl * atten)[..., None]
    return np.clip(alb * luz, 0, 1)


def previa(alb, nor):
    alb_t = mosaico(alb).astype(np.float32) / 255.0
    nor_t = mosaico(nor).astype(np.float32) * 2 - 1
    nor_t = nor_t / np.linalg.norm(nor_t, axis=-1, keepdims=True)
    a = alb_t
    b = iluminar(a, nor_t, (230.0, 270.0), 45.0, 430.0, 4.2, (1.0, 0.62, 0.26), 0.15)
    c = iluminar(a, nor_t, (730.0, 270.0), 45.0, 430.0, 4.2, (0.62, 0.36, 1.0), 0.15)
    # recorte 240x135 do albedo, ampliado 4x, onde há mais variedade de cores (janela móvel de 20 px)
    melhor, pos = -1, (0, 0)
    for y in range(0, TELA_H - 135, 15):
        for x in range(0, TELA_W - 240, 15):
            v = len(np.unique(col_tile[y:y + 135, x:x + 240]))
            ac = (np.isin(col_tile[y:y + 135, x:x + 240], CLARAS_ARR)).sum()
            if v + ac / 40 > melhor:
                melhor, pos = v + ac / 40, (x, y)
    x0, y0 = pos
    d = a[y0:y0 + 135, x0:x0 + 240]
    d = np.repeat(np.repeat(d, 4, axis=0), 4, axis=1)

    paineis = [Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8), "RGB") for x in (a, b, c, d)]
    legendas = ["(a) albedo 1 texel = 1 px (2x2 do quadro, emenda em x=512 e y=512)", "(b) luz laranja a esquerda + normal",
                "(c) luz roxa a direita + normal", f"(d) recorte 240x135 do albedo em x4 (origem {x0},{y0})"]
    gap, topo = 12, 34
    tela = Image.new("RGB", (TELA_W * 2 + gap, (TELA_H + topo) * 2), (0, 0, 0))
    draw = ImageDraw.Draw(tela)
    try:
        fonte = ImageFont.load_default(size=18)
    except TypeError:
        fonte = ImageFont.load_default()
    for i, (im, leg) in enumerate(zip(paineis, legendas)):
        x = (i % 2) * (TELA_W + gap)
        y = (i // 2) * (TELA_H + topo)
        tela.paste(im, (x, y + topo))
        draw.text((x + 8, y + 7), leg, fill=(230, 230, 225), font=fonte)
    os.makedirs(os.path.dirname(PREVIA), exist_ok=True)
    tela.save(PREVIA)


def main():
    global col_tile, CLARAS_ARR
    pontos = construir()
    albedo = PAL_RGB[col]
    nor8 = (normal_de(alt) * 255).round().astype(np.uint8)
    cores_usadas = len(np.unique(albedo.reshape(-1, 3), axis=0))
    assert cores_usadas <= 32, cores_usadas
    assert conta_pontos_claros() == 0

    os.makedirs(SAIDA, exist_ok=True)
    Image.fromarray(albedo, "RGB").save(os.path.join(SAIDA, "piso.png"))
    Image.fromarray(nor8, "RGB").save(os.path.join(SAIDA, "piso_normal.png"))
    col_tile = mosaico(col[..., None])[..., 0]
    CLARAS_ARR = np.array(CLARAS)
    previa(albedo, nor8)

    lum = albedo.astype(np.float32) @ np.array([0.299, 0.587, 0.114], np.float32)
    print(f"cores no albedo: {cores_usadas} (paleta de {len(PAL)}); pontos claros removidos: {pontos}")
    print(f"albedo medio RGB: {albedo.reshape(-1, 3).mean(0).round(1)}  luminancia {lum.mean():.1f}")
    print(f"musgo {(ZM > 0.5).mean():.2f}; altura min/max {alt.min():.2f}/{alt.max():.2f}")
    print(f"saidas: {SAIDA}, previa: {PREVIA}")


if __name__ == "__main__":
    main()

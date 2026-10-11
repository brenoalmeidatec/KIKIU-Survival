"""Chão novo da cena 2.5D (protótipo cara nova), procedural: só numpy e Pillow, sem IA de imagem.

Saídas em jogos/hordas/projeto/prototipos/piso/:
    piso.png         albedo 512x512 sem emenda (ruído periódico e elementos com wrap). 1 texel = 1 px de tela a 960x540.
                     Paleta fixa de 24 cores (PAL abaixo), escura: a luz do jogo é que clareia.
    piso_normal.png  normal map na convenção do protótipo: R = x, G = y para cima, B = z (ver cara_nova/LEIA-ME.md).
                     A altura vem das camadas: pedras e raízes altas, rachaduras baixas, musgo um pouco alto.

Prévia (sem Godot) em jogos/hordas/prints/prototipo_piso_novo.png, lado a lado:
    (a) só o albedo, 960x540 (2x2 cópias do quadro 512);
    (b) iluminado por uma luz pontual laranja à esquerda, Lambert com o normal e queda pela distância;
    (c) o chão antigo (floresta/piso.png) na escala do jogo (x2, ganho 2,4 e tom verde do cenário), com a mesma luz e normal plano.

Uso (Python 3 com numpy e Pillow), de qualquer pasta:
    python jogos/hordas/prototipos/cara_nova/piso/gerar_piso.py

A semente é fixa: a mesma execução gera o mesmo PNG.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
HORDAS = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
SAIDA = os.path.join(HORDAS, "projeto", "prototipos", "piso")
PREVIA = os.path.join(HORDAS, "prints", "prototipo_piso_novo.png")
CHAO_ANTIGO = os.path.join(HORDAS, "projeto", "assets", "cenarios", "floresta", "piso.png")

N = 512
TELA_W, TELA_H = 960, 540
SEMENTE = 2610
rng = np.random.default_rng(SEMENTE)

# 24 cores. Base: docs/visual_2_5d/paleta.json (painel, texto_secundario, fogo etc.) e amostras da
# imagem de entrada fonte_arte/entrada_fonte.webp (chão baixo e direita, topo escuro). Escuro de propósito.
PAL = {
    "fundo": "#0c1517",
    "terra_a": "#0f1c1d",
    "terra_b": "#162526",
    "terra_c": "#192725",
    "terra_marrom": "#2a2219",
    "musgo_a": "#1e322e",
    "musgo_b": "#2b2e24",
    "musgo_c": "#303a31",
    "musgo_d": "#38493e",
    "grama_seca": "#67593b",
    "terra_ocre": "#4b3a2a",
    "pedra_a": "#3a4442",
    "pedra_b": "#4e6868",
    "pedra_c": "#6f7c79",
    "pedra_luz": "#8f9a94",
    "pedra_luz_quente": "#8e7758",
    "folha_marrom": "#4b3025",
    "folha_ocre": "#6b4424",
    "folha_verm_escura": "#7a1f16",
    "folha_verm": "#b0301c",
    "raiz": "#251615",
    "galho": "#1a1410",
    "fenda": "#080d0d",
    "fenda_fundo": "#010303",
}
NOMES = list(PAL.keys())
IDX = {nome: i for i, nome in enumerate(NOMES)}
PAL_RGB = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in PAL.values()], dtype=np.uint8)

LUT_BASE = np.array([IDX[k] for k in ("fundo", "terra_a", "terra_b", "terra_c", "terra_marrom")])
LUT_MUSGO = np.array([IDX[k] for k in ("musgo_a", "musgo_b", "musgo_c", "musgo_d")])
PEDRAS = [IDX["pedra_a"], IDX["pedra_b"], IDX["pedra_c"]]
PEDRAS_P = [0.35, 0.4, 0.25]
FOLHAS = [IDX[k] for k in ("folha_marrom", "folha_ocre", "folha_verm_escura", "folha_verm")]
FOLHAS_P = [0.45, 0.35, 0.14, 0.06]

# alturas (0 a 1) de cada camada, para o normal map
H_BASE, H_MUSGO, H_TUFO, H_SECO = 0.25, 0.42, 0.50, 0.30
H_FOLHA, H_GALHO, H_RAIZ, H_FENDA = 0.38, 0.50, 0.72, 0.05
S_NORMAL = 3.0  # ESTICA: força da inclinação (escolha de arte, como no LEIA-ME)


def ruido(sigma):
    """Ruído periódico: ruído branco filtrado por gaussiana no domínio da frequência. Média 0, desvio 1, sem emenda."""
    branco = rng.standard_normal((N, N))
    f = np.fft.fftfreq(N)
    fy, fx = np.meshgrid(f, f, indexing="ij")
    filtro = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    r = np.real(np.fft.ifft2(np.fft.fft2(branco) * filtro))
    return (r - r.mean()) / (r.std() + 1e-9)


def carimbar(col, alt, cy, cx, mascara, idx, altura):
    """Cola um bloco (mascara bool, cores idx, alturas) com canto em (cy, cx), dando a volta nas bordas (wrap)."""
    h, w = mascara.shape
    yy, xx = np.meshgrid((np.arange(h) + cy) % N, (np.arange(w) + cx) % N, indexing="ij")
    yy, xx = yy[mascara], xx[mascara]
    col[yy, xx] = np.broadcast_to(idx, mascara.shape)[mascara]
    alt[yy, xx] = np.broadcast_to(altura, mascara.shape)[mascara]


def pedra():
    """Pedrinha de 2 a 6 px: elipse irregular, cúpula, 1 px de luz no topo-esquerda e 1 px de sombra embaixo-direita."""
    ax = rng.uniform(1.1, 3.2)
    ay = ax * rng.uniform(0.55, 0.9)
    th = rng.uniform(0, np.pi)
    fase = rng.uniform(0, 2 * np.pi, 2)
    R = int(np.ceil(ax)) + 2
    v = np.arange(-R, R + 1)
    X, Y = np.meshgrid(v, v, indexing="ij")
    u = X * np.cos(th) + Y * np.sin(th)
    w = -X * np.sin(th) + Y * np.cos(th)
    ang = np.arctan2(w, u)
    r = np.sqrt((u / ax) ** 2 + (w / ay) ** 2)
    d = r * (1 + 0.10 * np.cos(2 * ang + fase[0]) + 0.06 * np.cos(3 * ang + fase[1]))
    mascara = d <= 1.0
    pad = np.pad(mascara, 1)
    cima, esq = pad[:-2, 1:-1], pad[1:-1, :-2]
    baixo, dire = pad[2:, 1:-1], pad[1:-1, 2:]
    luz = mascara & (~cima | ~esq)
    sombra = mascara & (~baixo | ~dire) & ~luz
    corpo = rng.choice(PEDRAS, p=PEDRAS_P)
    idx = np.full(mascara.shape, corpo)
    idx[luz] = IDX["pedra_luz_quente"] if rng.random() < 0.3 else IDX["pedra_luz"]
    idx[sombra] = IDX["terra_a"]
    altura = np.where(mascara, 0.55 + 0.45 * np.clip((1 - d) * 2.5, 0, 1), 0.0)
    return mascara, idx, altura


def caminho(passos):
    """Passeio aleatório suave em pixels (linha torta de 1 px)."""
    y, x = rng.uniform(0, N, 2)
    ang = rng.uniform(0, 2 * np.pi)
    pts = []
    for _ in range(passos):
        ang += rng.normal(0, 0.28)
        y += np.sin(ang)
        x += np.cos(ang)
        pts.append((int(round(y)) % N, int(round(x)) % N))
    return pts


def traco(col, alt, pontos, idx, altura):
    for y, x in pontos:
        col[y, x] = idx
        alt[y, x] = altura


FORMAS_FOLHA = [
    np.array([[1, 1], [1, 0]], bool),  # 3 px
    np.array([[1, 1, 1]], bool),  # 3 px em linha
    np.array([[0, 1], [1, 1]], bool),  # 3 px
    np.array([[1, 1]], bool),  # 2 px
    np.array([[1], [1]], bool),  # 2 px vertical
    np.array([[1, 0], [0, 1]], bool),  # 2 px diagonal
]


def construir():
    col = np.zeros((N, N), dtype=np.int64)
    alt = np.full((N, N), H_BASE, dtype=np.float32)

    # 1. terra escura de base, em manchas grandes (quase preta, verde-azulada)
    g = 0.7 * ruido(14) + 0.3 * ruido(4)
    col[:] = LUT_BASE[np.digitize(g, [-0.3, 0.3, 1.0, 1.5])]
    alt += 0.03 * g.astype(np.float32)

    # 2. musgo em manchas (altura um pouco acima do chão)
    m = 0.6 * ruido(10) + 0.4 * ruido(3)
    musgo = m > np.quantile(m, 0.86)
    m2 = ruido(7)
    col[musgo] = LUT_MUSGO[np.digitize(m2, [-0.3, 0.7, 1.5])][musgo]
    alt[musgo] = H_MUSGO

    # 3. terra seca em manchas pequenas, fora do musgo
    seco = (~musgo) & (ruido(6) > 1.6)
    col[seco] = IDX["terra_marrom"]
    alt[seco] = H_SECO

    # 4. grama baixa: tufos de 2 a 3 px dentro do musgo
    pos_musgo = np.argwhere(musgo)
    tufos = [
        [(0, 0), (-1, 0)],
        [(0, 0), (-1, 0), (-1, 1)],
        [(0, 0), (-1, -1), (-1, 1)],
    ]
    for k in rng.choice(len(pos_musgo), size=min(220, len(pos_musgo)), replace=False):
        y, x = pos_musgo[k]
        cor = IDX["grama_seca"] if rng.random() < 0.06 else (IDX["musgo_b"] if rng.random() < 0.6 else IDX["musgo_c"])
        for dy, dx in tufos[rng.integers(len(tufos))]:
            col[(y + dy) % N, (x + dx) % N] = cor
            alt[(y + dy) % N, (x + dx) % N] = H_TUFO

    # 5. rachaduras: linhas de 1 px, escuras e baixas
    for _ in range(12):
        for i, (y, x) in enumerate(caminho(int(rng.integers(40, 110)))):
            col[y, x] = IDX["fenda_fundo"] if i % 3 == 0 else IDX["fenda"]
            alt[y, x] = H_FENDA

    # 6. folhas secas: 2 a 3 px, poucas vermelhas
    for _ in range(90):
        forma = FORMAS_FOLHA[rng.integers(len(FORMAS_FOLHA))]
        cor = FOLHAS[rng.choice(len(FOLHAS), p=FOLHAS_P)]
        cy, cx = rng.integers(0, N, 2)
        carimbar(col, alt, cy, cx, forma, cor, H_FOLHA)

    # 7. gravetos finos (1 px, torcidos) e raízes altas
    for _ in range(55):
        pts = caminho(int(rng.integers(12, 32)))
        traco(col, alt, pts, IDX["galho"], H_GALHO)
    for _ in range(14):
        pts = caminho(int(rng.integers(45, 120)))
        traco(col, alt, pts, IDX["raiz"], H_RAIZ)

    # 8. pedrinhas por último: cobrem raízes e rachaduras, e são as partes mais altas do relevo
    for _ in range(200):
        mascara, idx, altura = pedra()
        cy, cx = rng.integers(0, N, 2)
        carimbar(col, alt, cy, cx, mascara, idx, altura)

    return col, alt


def normal_de(alt):
    """Altura -> normal (R = x, G = y para cima, B = z). Diferença central com wrap, sem suavizar."""
    gx = (np.roll(alt, -1, axis=1) - np.roll(alt, 1, axis=1)) / 2.0
    gy = (np.roll(alt, -1, axis=0) - np.roll(alt, 1, axis=0)) / 2.0
    nx = -gx * S_NORMAL
    ny = gy * S_NORMAL  # y da imagem cresce para baixo; G precisa crescer para cima
    nz = np.ones_like(alt)
    norma = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    v = np.stack([nx / norma, ny / norma, nz / norma], axis=-1)
    return np.clip(v * 0.5 + 0.5, 0, 1)


def mosaico(a, w=TELA_W, h=TELA_H):
    return np.tile(a, (2, 2, 1))[:h, :w]


def iluminar(alb, nor, luz_xy, altura, raio, energia, cor, ambiente):
    """Lambert com o normal + queda quadrática pela distância (uma luz pontual, altura em px de tela)."""
    H, W = alb.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    lx, ly = luz_xy
    dx = lx - xx
    dy = yy - ly  # y para cima: a luz acima do pixel tem dy > 0
    dist2d = np.sqrt(dx ** 2 + dy ** 2)
    dist = np.sqrt(dist2d ** 2 + altura ** 2)
    lxn, lyn, lzn = dx / dist, dy / dist, altura / dist
    ndl = np.clip(nor[..., 0] * lxn + nor[..., 1] * lyn + nor[..., 2] * lzn, 0, 1)
    atten = np.clip(1 - dist2d / raio, 0, 1) ** 2
    luz = ambiente[None, None, :] + np.array(cor, np.float32)[None, None, :] * energia * (ndl * atten)[..., None]
    return np.clip(alb * luz, 0, 1)


def previa(alb, nor):
    alb_t = mosaico(alb).astype(np.float32) / 255.0
    nor_t = mosaico(nor).astype(np.float32) * 2 - 1
    nor_t = nor_t / np.linalg.norm(nor_t, axis=-1, keepdims=True)

    # chão antigo como o jogo mostra: texel vira 2x2 px (escala 2), depois ganho 2,4 e tom verde do shader do gd
    antigo = np.asarray(Image.open(CHAO_ANTIGO).convert("RGB")).astype(np.float32) / 255.0
    antigo = np.repeat(np.repeat(antigo, 2, axis=0), 2, axis=1)
    antigo = np.tile(antigo, (2, 2, 1))[:TELA_H, :TELA_W]
    antigo = np.clip(antigo * 2.4 * np.array([0.78, 1.0, 0.8], np.float32), 0, 1)
    nor_plano = np.zeros_like(nor_t)
    nor_plano[..., 2] = 1.0  # o chão antigo não tem normal map

    luz_xy = (250.0, 260.0)
    altura, raio, energia = 45.0, 230.0, 16.0
    cor = (1.0, 0.62, 0.26)  # laranja da tocha (#ff9e42)
    amb = np.array([0x1C, 0x2A, 0x24], np.float32) / 255.0

    a = np.clip(alb_t[:TELA_H, :TELA_W], 0, 1)
    b = iluminar(a, nor_t[:TELA_H, :TELA_W], luz_xy, altura, raio, energia, cor, amb)
    c = iluminar(antigo, nor_plano[:TELA_H, :TELA_W], luz_xy, altura, raio, energia, cor, amb)

    paineis = [Image.fromarray((x * 255).astype(np.uint8), "RGB") for x in (a, b, c)]
    legendas = ["(a) albedo, 1 texel = 1 px", "(b) luz laranja + normal map", "(c) chão antigo, escala x2 do jogo"]
    gap, topo = 12, 36
    tela = Image.new("RGB", (TELA_W * 3 + gap * 2, TELA_H + topo), (0, 0, 0))
    draw = ImageDraw.Draw(tela)
    try:
        fonte = ImageFont.load_default(size=18)
    except TypeError:
        fonte = ImageFont.load_default()
    for i, (im, leg) in enumerate(zip(paineis, legendas)):
        x = i * (TELA_W + gap)
        tela.paste(im, (x, topo))
        draw.text((x + 8, 8), leg, fill=(230, 230, 225), font=fonte)
    os.makedirs(os.path.dirname(PREVIA), exist_ok=True)
    tela.save(PREVIA)


def main():
    col, alt = construir()
    albedo = PAL_RGB[col]  # (N, N, 3) uint8
    nor = normal_de(alt)
    nor8 = (nor * 255).round().astype(np.uint8)

    cores_usadas = len(np.unique(albedo.reshape(-1, 3), axis=0))
    assert cores_usadas <= 24, cores_usadas

    os.makedirs(SAIDA, exist_ok=True)
    Image.fromarray(albedo, "RGB").save(os.path.join(SAIDA, "piso.png"))
    Image.fromarray(nor8, "RGB").save(os.path.join(SAIDA, "piso_normal.png"))
    previa(albedo, nor8)

    lum = albedo.astype(np.float32) @ np.array([0.299, 0.587, 0.114], np.float32)
    antigo = np.asarray(Image.open(CHAO_ANTIGO).convert("RGB")).astype(np.float32)
    lum_antigo = antigo @ np.array([0.299, 0.587, 0.114], np.float32)
    print(f"cores no albedo: {cores_usadas} (paleta de {len(PAL)})")
    print(f"albedo medio RGB: {albedo.reshape(-1, 3).mean(0).round(1)}  luminancia {lum.mean():.1f}")
    print(f"chao antigo luminancia {lum_antigo.mean():.1f}, x2.4 no jogo {np.clip(lum_antigo * 2.4, 0, 255).mean():.1f}")
    print(f"altura min/max {alt.min():.2f}/{alt.max():.2f}")
    print(f"saidas: {SAIDA}, previa: {PREVIA}")


if __name__ == "__main__":
    main()

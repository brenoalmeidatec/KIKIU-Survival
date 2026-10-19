# Gera as texturas de detalhe do Vornak 3D (512 x 512, cinza em 5 níveis) para o toon de 5 tons.
# Cada nível desloca o tom da rampa: 0 = -2 (fissura funda), 64 = -1 (sombra de casca), 128 = 0,
# 192 = +1 (relevo, nó claro), 255 = +2 (brilho). A Godot amostra com nearest, então o detalhe fica em pixel.
# Rodar: uv run --python 3.12 --with numpy --with pillow python -I docs/v3/chefes/gerar_texturas_vornak.py
import os

import numpy as np
from PIL import Image

N = 512
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SAIDA = os.path.join(RAIZ, "v3", "godot", "assets", "3d", "texturas")
rng = np.random.default_rng(4242)
yy, xx = np.mgrid[0:N, 0:N].astype(float)
NIVEIS = np.array([0, 64, 128, 192, 255], dtype=np.uint8)


def ruido_suave(escala, oitavas=3):
    """Ruído de valor periódico (encaixa nas bordas) em [0, 1]."""
    total = np.zeros((N, N))
    amp, soma = 1.0, 0.0
    for o in range(oitavas):
        g = int(escala * 2 ** o)
        grade = rng.random((g, g))
        # repetir em mosaico 3x3 e cortar o centro deixa a borda contínua
        grade3 = np.tile(grade, (3, 3))
        img = Image.fromarray((grade3 * 255).astype(np.uint8)).resize((N * 3, N * 3), Image.BICUBIC)
        total += amp * np.asarray(img, dtype=float)[N:2 * N, N:2 * N] / 255
        soma += amp
        amp *= 0.5
    return total / soma


def salvar(nome, niv):
    """niv: inteiros de -2 a +2."""
    img = NIVEIS[np.clip(niv, -2, 2).astype(int) + 2]
    os.makedirs(SAIDA, exist_ok=True)
    Image.fromarray(img, "L").save(os.path.join(SAIDA, nome + ".png"))
    cont = {int(v): int((niv == v).sum()) for v in range(-2, 3)}
    print(nome, img.shape, cont)


def madeira():
    """Casca: placas verticais com fissuras onduladas, rachas horizontais e nós com anel."""
    niv = np.zeros((N, N), int)
    onda = (ruido_suave(4, 2) - 0.5) * 26
    x = (xx + onda) % N
    larguras = []
    pos = 0
    while pos < N:
        w = int(rng.integers(14, 30))
        larguras.append((pos, min(N, pos + w)))
        pos += w
    for a, b in larguras:
        dentro = (x >= a) & (x < b)
        niv[dentro & (x < a + 2)] = -2                 # fissura funda
        niv[dentro & (x >= a + 2) & (x < a + 4)] = -1  # borda da placa na sombra
        niv[dentro & (x >= b - 3)] = 1                 # borda da placa na luz
    # veios finos: traços verticais curtos dentro das placas (seguem a mesma onda das fissuras)
    for _ in range(420):
        cy, cx, comp = int(rng.integers(0, N)), int(rng.integers(0, N)), int(rng.integers(6, 22))
        v = -1 if rng.random() < 0.7 else 1
        for k in range(comp):
            yk = (cy + k) % N
            xk = int(cx + onda[yk, cx]) % N
            if niv[yk, xk] == 0:
                niv[yk, xk] = v
    # manchas largas de casca mais escura (pouco contraste, só -1 em áreas grandes)
    mancha = ruido_suave(5, 2)
    niv[(niv == 0) & (mancha > 0.7)] = -1
    # rachas horizontais curtas
    for _ in range(40):
        cy, cx, comp = rng.integers(0, N), rng.integers(0, N), rng.integers(8, 22)
        for k in range(comp):
            niv[(cy + (k // 6)) % N, (cx + k) % N] = -2
    # nós: anel escuro, miolo claro, ponto escuro no centro
    for _ in range(14):
        cy, cx = rng.integers(0, N, 2)
        ry, rx = rng.uniform(9, 15), rng.uniform(6, 9)
        dy = np.minimum(np.abs(yy - cy), N - np.abs(yy - cy)) / ry
        dx = np.minimum(np.abs(xx - cx), N - np.abs(xx - cx)) / rx
        d = np.sqrt(dx ** 2 + dy ** 2)
        niv[(d < 1.25) & (d >= 1.0)] = -1
        niv[(d < 1.0) & (d >= 0.75)] = -2
        niv[d < 0.75] = 1
        niv[d < 0.3] = -1
    return niv


def musgo():
    """Musgo em blocos: tufos de 12 a 28 px com topo claro, base escura e pontos de brilho."""
    niv = np.full((N, N), -1, int)
    y = 0
    while y < N:
        h = int(rng.integers(12, 24))
        x = int(rng.integers(0, 12))
        while x < N + 12:
            w = int(rng.integers(14, 28))
            y0, x0 = y + int(rng.integers(-3, 4)), x
            ys = np.arange(y0, y0 + h) % N
            xs = np.arange(x0, x0 + w - 2) % N
            bloco = np.zeros((len(ys), len(xs)), int)
            bloco[:3, :] = 1          # topo na luz
            bloco[-3:, :] = -1        # base na sombra
            bloco[:, :2] = np.minimum(bloco[:, :2], 0)
            bloco[1, 2:5] = 2         # brilho no canto
            niv[np.ix_(ys, xs)] = bloco
            x += w
        y += h
    pontos = rng.random((N, N)) > 0.985
    niv[pontos & (niv == 0)] = 1
    return niv


def cipo():
    """Cipó e rosto: fibras em diagonal torcida."""
    t = (xx + yy * 0.6 + (ruido_suave(6, 2) - 0.5) * 30) % 18
    niv = np.zeros((N, N), int)
    niv[t < 2] = -2
    niv[(t >= 2) & (t < 4)] = -1
    niv[(t >= 13) & (t < 16)] = 1
    return niv


def energia():
    """Fendas: núcleo brilhante ondulado com halo, faíscas soltas."""
    niv = np.full((N, N), -1, int)
    for k in range(6):
        centro = (k + 0.5) * N / 6 + (ruido_suave(5, 2) - 0.5) * 40
        d = np.abs(xx - centro)
        niv[d < 9] = 0
        niv[d < 5] = 1
        niv[d < 2] = 2
    niv[(rng.random((N, N)) > 0.992)] = 2
    return niv


def olho():
    """Olho: brilho radial em degraus (centro +2) repetido em 4x4 (a UV do olho é pequena)."""
    c = N / 8
    dx = (xx % (N / 4)) - c
    dy = (yy % (N / 4)) - c
    d = np.sqrt(dx ** 2 + dy ** 2) / c
    niv = np.full((N, N), -1, int)
    niv[d < 0.95] = 0
    niv[d < 0.65] = 1
    niv[d < 0.3] = 2
    return niv


def dente():
    """Dentes: listras verticais com borda escura, centro claro e ponta brilhante."""
    t = xx % 32
    niv = np.zeros((N, N), int)
    niv[t < 3] = -2
    niv[(t >= 3) & (t < 6)] = -1
    niv[(t >= 14) & (t < 20)] = 1
    niv[((t >= 15) & (t < 18)) & ((yy % 64) < 10)] = 2
    return niv


if __name__ == "__main__":
    salvar("madeira", madeira())
    salvar("musgo", musgo())
    salvar("cipo", cipo())
    salvar("energia", energia())
    salvar("olho", olho())
    salvar("dente", dente())

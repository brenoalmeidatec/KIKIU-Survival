"""Folha da BOLA da explosão do mecha (Q do LightWolf, "Colapso da Matriz"), rodada 7.

Arte própria, procedural (numpy), sem nada de terceiros: a D.Va de Overwatch foi só referência de IDEIA/ritmo (antecipação, clarão
curto, cúpula em camadas, anel de choque, raios, dissipação em degraus), nenhuma forma, cor ou quadro copiado.

Saída: jogos/hordas/projeto/assets/v2/efeitos/lw_q_bola.png, grade de COLS colunas, cada célula LxA px, alfa só 0/1 e só as cores da paleta
do mecha (PALETA abaixo, as mesmas de v2/explosao_mecha.gd). O jogo desenha célula a célula em posição inteira, sem escala nem giro.
O tempo de cada quadro (pesos) fica em dados/v2_especial.json > autodestruicao.explosao.folha: este script só desenha. Os pesos usados aqui
para escolher o "tempo de desenho" de cada quadro são lidos de lá também (mesma tabela), para a arte casar com o ritmo do jogo.

Roda (da raiz do repositório):
    python jogos/hordas/fonte_arte/explosao_lw_q/gerar_bola.py [--folha_contato caminho.png]
"""

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]  # jogos/hordas
JSON = RAIZ / "projeto" / "dados" / "v2_especial.json"
SAIDA = RAIZ / "projeto" / "assets" / "v2" / "efeitos" / "lw_q_bola.png"

BRANCO = (255, 255, 255)
CIANO_CLARO = (199, 245, 255)
CIANO = (102, 204, 255)
AZUL = (46, 107, 230)
AZUL_ESC = (20, 36, 102)
FUMACA = (77, 84, 102)
FUMACA_ESC = (41, 43, 56)
PALETA = [BRANCO, CIANO_CLARO, CIANO, AZUL, AZUL_ESC, FUMACA, FUMACA_ESC]  # índice 0..6, do mais claro ao mais escuro
VAZIO = 255


def ler_folha():
    d = json.loads(JSON.read_text(encoding="utf-8"))
    e = d["autodestruicao"]["explosao"]
    f = e["folha"]
    return int(e["bola"]), f


def tempos(pesos, total):
    """O instante (s de RELÓGIO desde o estouro) que cada quadro representa: o meio do quadro, o 1º é o próprio estouro."""
    s = float(sum(pesos))
    out, acc = [], 0.0
    for i, p in enumerate(pesos):
        d = p / s * total
        out.append(0.0 if i == 0 else acc + d * 0.5)
        acc += d
    return out


def ruido(h, w, passo, semente):
    """Ruído de valor bilinear [0, 1) numa grade de `passo` px (fixo pela semente)."""
    rng = np.random.default_rng(semente)
    gh, gw = h // passo + 3, w // passo + 3
    g = rng.random((gh, gw))
    y = np.arange(h) / passo
    x = np.arange(w) / passo
    y0 = np.floor(y).astype(int)
    x0 = np.floor(x).astype(int)
    fy = (y - y0)[:, None]
    fx = (x - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0] * (1 - fx) + g[y0][:, x0 + 1] * fx
    b = g[y0 + 1][:, x0] * (1 - fx) + g[y0 + 1][:, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def borda(ang, t, semente, amp=1.0):
    """Raio relativo da borda irregular no ângulo (1 +- ~0,18), que ondula devagar com o tempo."""
    rng = np.random.default_rng(semente)
    v = np.ones_like(ang)
    for n, a in ((3, 0.035), (5, 0.04), (7, 0.045), (11, 0.04), (17, 0.026), (23, 0.016)):
        ph = rng.random() * math.tau
        w = (rng.random() - 0.5) * 3.0
        v = v + amp * a * np.cos(n * ang + ph + w * t)
    return v


def linha(buf, x0, y0, x1, y1, cor, so_vazio=False):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    xs = np.rint(np.linspace(x0, x1, n)).astype(int)
    ys = np.rint(np.linspace(y0, y1, n)).astype(int)
    h, w = buf.shape
    ok = (xs >= 0) & (xs < w) & (ys >= 0) & (ys < h)
    xs, ys = xs[ok], ys[ok]
    if so_vazio:
        m = buf[ys, xs] == VAZIO
        xs, ys = xs[m], ys[m]
    buf[ys, xs] = cor


def gerar():
    R, folha = ler_folha()
    pesos = folha["pesos"]
    n = len(pesos)
    assert n == int(folha["quadros"]), "quadros e pesos fora de sincronia no JSON"
    total = float(folha["dur_relogio"])
    L, A = int(folha["celula"][0]), int(folha["celula"][1])
    cx, cy = int(folha["centro"][0]), int(folha["centro"][1])
    cols = int(folha["colunas"])
    ts = tempos(pesos, total)

    yy, xx = np.mgrid[0:A, 0:L].astype(float)
    # campos fixos (a "matéria" da bola): turbulência que sobe, máscara de esfarelar, dither
    turb_a = ruido(A + 120, L, 9, 41)
    turb_b = ruido(A + 120, L, 5, 42)
    hp = 0.6 * ruido(A, L, 3, 4) + 0.4 * np.random.default_rng(3).random((A, L))  # a máscara do esfarelar: pedaços de 2-4 px, não pontos soltos
    dither = ((xx.astype(int) + yy.astype(int)) % 2 == 0)

    # os puffs de fumaça (posição relativa ao centro da bola, nascimento, subida, raio)
    rng = np.random.default_rng(77)
    puffs = []
    for i in range(16):  # a copa e as laterais
        a = -math.pi * (0.08 + 0.84 * (i + rng.random() * 0.6) / 16.0)  # metade de cima
        rel = 0.62 + rng.random() * 0.3
        puffs.append(dict(a=a, rel=rel, nasce=0.30 + rng.random() * 0.32, sobe=22 + rng.random() * 26, r=10 + rng.random() * 9, s=i))
    for i in range(6):  # a coluna (cogumelo): discos empilhados acima do miolo
        puffs.append(dict(a=-math.pi / 2, rel=0.15 + 0.16 * i, nasce=0.42 + 0.05 * i, sobe=30 + 4 * i, r=12 - i * 0.8, s=40 + i, coluna=True))
    for i in range(6):  # a saia no chão
        a = math.pi * (0.1 + 0.8 * i / 5.0)
        puffs.append(dict(a=a, rel=0.75, nasce=0.40 + rng.random() * 0.2, sobe=-2, r=9 + rng.random() * 5, s=60 + i, chao=True))

    raios_ang = [math.tau * (i + 0.5 + (np.random.default_rng(100 + i).random() - 0.5) * 0.5) / 12.0 for i in range(12)]
    raios_comp = [0.6 + 0.4 * np.random.default_rng(200 + i).random() for i in range(12)]

    quadros = []
    for k in range(n):
        t = ts[k]
        buf = np.full((A, L), VAZIO, dtype=np.uint8)

        # ---------------------------------------------------- a cúpula: casca + miolo defasado
        cresce = 1.0 - (1.0 - min(1.0, t / 0.5)) ** 3
        rc = R * 0.95 * (0.17 + 0.83 * cresce) + R * 0.07 * min(1.0, max(0.0, (t - 0.5) / 0.8))
        tm = max(0.0, t - 0.06)  # o miolo vem 2 quadros atrás
        rm = R * 0.62 * (0.25 + 0.75 * (1.0 - (1.0 - min(1.0, tm / 0.5)) ** 3))
        sobe = round(R * 0.25 * min(1.0, max(0.0, (t - 0.45) / 0.85)))
        bx, by = cx, cy - sobe
        dx = xx - bx
        dy = yy - by
        dist = np.sqrt(dx * dx + dy * dy)
        ang = np.arctan2(dy, dx)
        b1 = borda(ang, t, 7, 1.0 if k > 0 else 0.5)
        d = dist / np.maximum(rc * b1, 1.0)
        rolar = int(round(34 * t))  # a turbulência sobe
        nz = 0.6 * turb_a[120 - rolar : 120 - rolar + A] + 0.4 * turb_b[120 - int(round(55 * t)) : 120 - int(round(55 * t)) + A]
        quente = 1.0 - 0.55 * min(1.0, t / 0.75) - 0.4 * min(1.0, max(0.0, (t - 0.6) / 0.65))
        calor = quente * (1.08 - 0.55 * d * d) + 0.3 * (nz - 0.5)
        b2 = borda(ang, t * 1.3, 9, 0.8)
        miolo = dist < rm * b2
        calor = np.where(miolo, calor + 0.3 * quente * (1.0 - min(1.0, t / 0.7)), calor)
        calor = np.where(d > 0.86, calor - 0.22, calor)  # a borda escura da casca
        dentro = d <= 1.0
        # o miolo abre (a bola vira anel e fumaça)
        oco = min(0.62, max(0.0, (t - 0.55) / 0.55) * 0.62)
        b3 = borda(ang, 0.0, 11, 1.6)
        dentro &= ~(d < oco * b3)
        # o esfarelar de fora para dentro (máscara fixa, cada pixel some uma vez)
        er = max(0.0, (t - 0.78) / 0.55) * 1.2
        dentro &= ~(hp * 0.45 + (1.0 - d) * 0.75 < er)

        # ---------------------------------------------------- a fumaça (atrás da cúpula)
        fum = np.full((A, L), VAZIO, dtype=np.uint8)
        for p in puffs:
            if t < p["nasce"]:
                continue
            idade = t - p["nasce"]
            r = p["r"] * min(1.0, 0.45 + idade / 0.18)
            # some em degraus de tamanho no fim (nunca alfa)
            if t > 1.0:
                r *= [1.0, 0.75, 0.5, 0.3][min(3, int((t - 1.0) / 0.09))]
            if r < 2.0:
                continue
            base_r = rc * p["rel"]
            px = cx + math.cos(p["a"]) * base_r * (1.0 if not p.get("coluna") else 0.0)
            py = cy - 8 + math.sin(p["a"]) * base_r * (0.75 if not p.get("chao") else 0.35) - p["sobe"] * min(1.0, idade / 0.7)
            if p.get("chao"):
                px = cx + math.cos(p["a"]) * base_r * (1.0 + 0.4 * min(1.0, idade / 0.6))
                py = cy + 10 + math.sin(p["a"]) * 10
            px, py = round(px), round(py)
            ddx = xx - px
            ddy = yy - py
            dd = np.sqrt(ddx * ddx + ddy * ddy) / r
            m = dd <= 1.0
            # sombreado: topo mais claro, base mais escura, borda pontilhada (dither em vez de alfa)
            sombra = turb_b[:A] * 0.7 + (ddy / r) * 0.45
            tom = np.where(sombra < 0.38, 5, 6)
            tom = np.where((dd > 0.78) & dither, 6, tom)
            if t < 0.62:  # ainda quente perto da bola: azul escuro por baixo
                tom = np.where(ddy > r * 0.2, 4, tom)
            # furos antes de sumir
            furo = hp < max(0.0, (t - 0.95) / 0.38) * 0.85
            m &= ~furo
            fum = np.where(m & (fum == VAZIO), tom, fum).astype(np.uint8)
        buf = fum

        # cor da cúpula pelo calor
        cor = np.select(
            [calor > 0.93, calor > 0.75, calor > 0.56, calor > 0.4, calor > 0.27, calor > 0.15],
            [0, 1, 2, 3, 4, 5],
            default=6,
        ).astype(np.uint8)
        if t > 0.8:  # a fumaça escura entra pela borda com pontilhado
            cor = np.where((cor >= 4) & dither & (d > 0.7), 6, cor).astype(np.uint8)
        buf = np.where(dentro, cor, buf).astype(np.uint8)

        # ---------------------------------------------------- o estalo: núcleo branco e raios (quadro 0) que viram chicotes (1..3)
        if k == 0:
            nucleo = dist < 14 * borda(ang, 0.0, 5, 0.6)
            buf[nucleo] = 0
            buf[(dist >= 14) & (dist < 18) & (buf == VAZIO) & dither] = 1
            for i in range(12):
                a = raios_ang[i]
                comp = 14 + 22 * raios_comp[i] * 1.4
                for off in (-1, 0, 1):
                    ox, oy = -math.sin(a) * off, math.cos(a) * off
                    fim = comp * (1.0 if off == 0 else 0.55)
                    linha(buf, bx + ox + math.cos(a) * 10, by + oy + math.sin(a) * 10, bx + ox + math.cos(a) * fim, by + oy + math.sin(a) * fim, 0)
        elif k <= 3:
            for i in range(12):
                a = raios_ang[i]
                comp = rc * (1.25 + 0.9 * raios_comp[i]) + 6 * k
                pontos = []
                for s in range(7):
                    u = s / 6.0
                    r = rc * 0.8 + (comp - rc * 0.8) * u
                    torce = math.sin(u * 3.1 + i * 1.7 + k * 0.9) * (2 + 3 * k) * u
                    pontos.append((bx + math.cos(a) * r - math.sin(a) * torce, by + math.sin(a) * r + math.cos(a) * torce))
                c = [1, 2, 3][k - 1]
                for (x0, y0), (x1, y1) in zip(pontos, pontos[1:]):
                    linha(buf, x0, y0, x1, y1, c)
                    if k == 1:
                        linha(buf, x0 + 1, y0, x1 + 1, y1, c, so_vazio=True)

        # ---------------------------------------------------- o anel de choque no ar (elipse que ondula e quebra em arcos)
        if 0 < t < 0.46:
            u = t / 0.46
            ra = 22 + (min(L // 2, A - cy) - 3 - 22) * (1.0 - (1.0 - u) ** 2)
            c = 1 if u < 0.4 else (2 if u < 0.75 else 3)
            npts = int(math.tau * ra)
            for j in range(npts):
                a = math.tau * j / npts
                if u > 0.5:
                    seg = int(a / math.tau * 22)
                    if np.random.default_rng(300 + seg).random() < (u - 0.5) * 1.6:
                        continue
                rr = ra + 1.5 * math.sin(3 * a + 0.7) + 1.0 * math.sin(5 * a + 2.1) + 0.8 * math.sin(8 * a + 4.0)
                x = round(bx + math.cos(a) * rr)
                y = round(by + math.sin(a) * rr * 0.8)
                if 0 <= x < L and 0 <= y < A and buf[y, x] == VAZIO:
                    buf[y, x] = c

        # ---------------------------------------------------- arcos elétricos (mudam de forma a cada 2 quadros)
        if 0.14 < t < 0.9:
            g = np.random.default_rng(500 + k // 2)
            nb = 8 if t < 0.55 else 5
            for i in range(nb):
                a = g.random() * math.tau
                r0 = rc * borda(np.array([a]), t, 7)[0] * 0.92
                comp = 12 + g.random() * 18
                x, y = bx + math.cos(a) * r0, by + math.sin(a) * r0
                passos = 4 + int(g.random() * 3)
                c = 1 if t < 0.5 else 2
                for s in range(passos):
                    ja = a + (g.random() - 0.5) * 1.3
                    nx = x + math.cos(ja) * comp / passos
                    ny = y + math.sin(ja) * comp / passos
                    linha(buf, x, y, nx, ny, c)
                    x, y = nx, ny

        quadros.append(buf)

    linhas = (n + cols - 1) // cols
    folha_px = np.zeros((linhas * A, cols * L, 4), dtype=np.uint8)
    pal = np.array([list(c) + [255] for c in PALETA] + [[0, 0, 0, 0]] * (256 - len(PALETA)), dtype=np.uint8)
    pal[VAZIO] = [0, 0, 0, 0]
    for k, q in enumerate(quadros):
        r, c = divmod(k, cols)
        folha_px[r * A : (r + 1) * A, c * L : (c + 1) * L] = pal[q]
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(folha_px, "RGBA").save(SAIDA, optimize=True)
    print("folha %s: %d quadros de %dx%d" % (SAIDA, n, L, A))
    return quadros, pal, L, A


def folha_contato(quadros, pal, L, A, caminho, cols=9, escala=3):
    linhas = (len(quadros) + cols - 1) // cols
    m = 4
    img = Image.new("RGBA", (cols * (L + m), linhas * (A + m)), (34, 36, 44, 255))
    for k, q in enumerate(quadros):
        r, c = divmod(k, cols)
        fundo = Image.new("RGBA", (L, A), (34, 36, 44, 255))
        fundo.alpha_composite(Image.fromarray(pal[q], "RGBA"))
        img.paste(fundo, (c * (L + m), r * (A + m)))
    img = img.resize((img.width * escala, img.height * escala), Image.NEAREST)
    Path(caminho).parent.mkdir(parents=True, exist_ok=True)
    img.save(caminho)
    print("folha de contato:", caminho)


if __name__ == "__main__":
    qs, pal, L, A = gerar()
    if "--folha_contato" in sys.argv:
        folha_contato(qs, pal, L, A, sys.argv[sys.argv.index("--folha_contato") + 1])

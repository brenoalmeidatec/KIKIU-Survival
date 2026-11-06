"""Folhas da TEIA DA ARANHA (v2): a teia no chão, abrindo, queimando, partida por corte e estilhaçada por martelo, mais a bolota que voa e a
rede que abre no ar. Tudo por script (Python, Pillow e numpy), determinístico (sementes fixas), sem nenhuma imagem de entrada: a A25
(notas/artes_chatgpt/A25_teia_ref.png, gerada para o projeto no ChatGPT) serviu só de direção de paleta e de ritmo e NÃO é asset.

Pixel art: 1 px de arte = 1 px de 960x540, alfa só 0 ou 255, sem rotação livre (a elipse é projetada pelo achatamento do chão, 0,62, o mesmo de
v2/avisos.gd e v2/teias.gd), cada fio é uma reta de Bresenham de 1 px com um pixel de sombra escura embaixo (o contorno escuro do projeto).

Uso (a partir da raiz do repositório):  python jogos/hordas/fonte_arte/teia/gerar_teia.py
Saída: jogos/hordas/projeto/assets/v2/teias/*.png (o jogo carrega por dados/v2_teia.json > folhas). Imprime a tabela quadro/colunas/linhas e a
luminância média de cada quadro da queima (o teste v2_teia_folhas confere que ela sobe uma vez e desce uma vez, WCAG 2.3.1).

Folhas (cada uma com SEMENTES linhas por geometria de teia; o jogo sorteia a geometria de cada teia uma vez e a mantém até o fim):
  teia_abre.png   96x64, 6 quadros, 1 linha por geometria: cai e abre em elipse (o último quadro é o repouso, sem folha de idle).
  teia_queima.png 96x64, 8 quadros, 4 linhas por geometria (bit 0 = espelha H, bit 1 = espelha V: o canto da ignição): o fogo nasce num ponto e corre
                  pelo anel, os fios encolhem em brasa e cinza e somem.
  teia_corte.png  96x64, 7 quadros, 2 linhas por geometria (0 = golpe em "/", 1 = golpe em "\\"): o risco brilhante atravessa, a rede parte em pedaços que
                  se soltam, encolhem e somem.
  teia_quebra.png 96x64, 7 quadros, 1 linha por geometria: martelo e giro de 360 graus: onda branca e a rede estilhaça para fora.
  teia_some.png   96x64, 6 quadros, 1 linha por geometria: a teia que expirou desmancha de fora para dentro.
  teia_bolota.png 16x16, 4 quadros: a bolota de teia girando (loop).
  teia_abre_ar.png 24x24, 4 quadros: a bolota abrindo em rede no ar, nos últimos instantes do voo.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.abspath(os.path.join(AQUI, "..", "..", "projeto", "assets", "v2", "teias"))

W, H = 96, 64  # o quadro da teia no chão; o centro (pivô) cai em (48, 32)
CX, CY = 48.0, 32.0
RX = 40.0  # raio da teia no chão (dados/v2_teia.json > teia > raio)
ACHATA = 0.62  # o chão aparece comprimido pela câmera a 45 graus (v2/avisos.gd ACHATA)
RY = RX * ACHATA
SEMENTES = [11, 29]  # duas geometrias de teia
QUADROS = {"abre": 6, "queima": 8, "corte": 7, "quebra": 7, "some": 6}

# paleta (RGB). Fios: azul-branco; sombra escura embaixo; fogo do claro ao escuro; brasa e cinza.
CLARO = (226, 236, 247)
MEDIO = (169, 189, 214)
TENUE = (118, 136, 168)
SOMBRA = (30, 38, 60)
FOGO = [(255, 248, 205), (255, 220, 100), (255, 158, 44), (226, 92, 32), (154, 44, 30)]
BRASA = [(120, 40, 30), (78, 32, 38)]
CINZA = [(104, 106, 122), (66, 68, 84)]
RISCO = [(255, 255, 236), (255, 226, 120), (255, 168, 60)]


# ------------------------------------------------------------------ geometria da teia (fios de 1 px)


def reta(x0, y0, x1, y1):
    """Bresenham: os pixels inteiros de (x0,y0) a (x1,y1)."""
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    out = []
    while True:
        out.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    return out


class Fio:
    """Os pixels de uma teia: x, y inteiros relativos ao centro (px), r (0 no centro, 1 na borda da elipse), th (rad, na elipse), rnd (0 a 1) e tipo
    (0 raio, 1 anel)."""

    def __init__(self):
        self.x = []
        self.y = []
        self.r = []
        self.th = []
        self.rnd = []
        self.tipo = []

    def arr(self):
        return (np.array(self.x), np.array(self.y), np.array(self.r), np.array(self.th), np.array(self.rnd), np.array(self.tipo))


def teia(semente, escala=1.0, aneis_ate=99, pontas=True, esparso=0.0):
    """A geometria de uma teia: 12 raios e 6 anéis (com a barriga para dentro), tudo projetado na elipse do chão. `escala` encolhe tudo (a abertura),
    `aneis_ate` limita quantos anéis existem, `esparso` (0 a 1) tira pixels ao acaso (a rede ainda esticando)."""
    rng = random.Random(semente)
    n = 12
    ang = [i * math.tau / n + rng.uniform(-0.09, 0.09) for i in range(n)]
    fim = [rng.uniform(0.9, 1.04) for _ in range(n)]
    aneis = [0.13, 0.27, 0.42, 0.58, 0.74, 0.9]
    f = Fio()
    visto = set()

    def pt(r, th):
        return CX + math.cos(th) * r * RX * escala, CY + math.sin(th) * r * RY * escala

    def pinta(x, y, tipo):
        xi, yi = int(round(x - CX)), int(round(y - CY))
        if (xi, yi) in visto:
            return
        visto.add((xi, yi))
        u, v = xi / RX, yi / RY
        r = math.hypot(u, v)
        f.x.append(xi)
        f.y.append(yi)
        f.r.append(r / max(escala, 0.05))
        f.th.append(math.atan2(v, u))
        f.rnd.append(rng.random())
        f.tipo.append(tipo)

    for i in range(n):
        a = pt(0.0, ang[i])
        b = pt(fim[i] if pontas else 0.92, ang[i])
        for (x, y) in reta(a[0], a[1], b[0], b[1]):
            pinta(x, y, 0)
    for k, rk in enumerate(aneis):
        if k >= aneis_ate:
            break
        for i in range(n):
            j = (i + 1) % n
            r1 = rk * (1 + rng.uniform(-0.03, 0.03))
            r2 = rk * (1 + rng.uniform(-0.03, 0.03))
            th1 = ang[i]
            th2 = ang[j] + (math.tau if j == 0 else 0.0)
            meio = (th1 + th2) / 2
            pm = pt(min(r1, r2) * 0.93, meio)  # a barriga do fio entre dois raios: puxa para o centro
            p1, p2 = pt(r1, th1), pt(r2, th2)
            for (x, y) in reta(p1[0], p1[1], pm[0], pm[1]) + reta(pm[0], pm[1], p2[0], p2[1]):
                pinta(x, y, 1)
    if esparso > 0.0:
        keep = [k for k in range(len(f.x)) if rng.random() >= esparso]
        for nome in ("x", "y", "r", "th", "rnd", "tipo"):
            setattr(f, nome, [getattr(f, nome)[k] for k in keep])
    return f


# ------------------------------------------------------------------ quadro (RGBA) e composição


class Quadro:
    def __init__(self, w=W, h=H, cx=CX, cy=CY):
        self.w, self.h, self.cx, self.cy = w, h, int(round(cx)), int(round(cy))
        self.px = np.zeros((h, w, 4), np.uint8)

    def pinta(self, x, y, cor):
        xi, yi = self.cx + int(x), self.cy + int(y)
        if 0 <= xi < self.w and 0 <= yi < self.h:
            self.px[yi, xi] = (cor[0], cor[1], cor[2], 255)

    def vazio(self, x, y):
        xi, yi = self.cx + int(x), self.cy + int(y)
        return 0 <= xi < self.w and 0 <= yi < self.h and self.px[yi, xi, 3] == 0

    def fios(self, xs, ys, rs, rnds, tipos, sombra=True, cor_fn=None):
        """Desenha os fios com 1 px de sombra escura embaixo (onde estiver livre) e a cor por raio."""
        for k in range(len(xs)):
            cor = cor_fn(k) if cor_fn is not None else cor_fio(rs[k], rnds[k], tipos[k])
            if cor is not None:
                self.pinta(xs[k], ys[k], cor)
        if sombra:
            for k in range(len(xs)):
                if (cor_fn(k) if cor_fn is not None else True) is None:
                    continue
                if self.vazio(xs[k], ys[k] + 1):
                    self.pinta(xs[k], ys[k] + 1, SOMBRA)

    def imagem(self):
        return Image.fromarray(self.px, "RGBA")


def cor_fio(r, rnd, tipo):
    if r < 0.22:
        return CLARO
    if r > 0.86:
        return MEDIO if rnd > 0.3 else TENUE
    if tipo == 0:
        return CLARO if rnd > 0.25 else MEDIO
    return MEDIO if rnd > 0.3 else CLARO


def teia_repouso(semente):
    q = Quadro()
    xs, ys, rs, th, rnd, tp = teia(semente).arr()
    q.fios(xs, ys, rs, rnd, tp)
    return q


# ------------------------------------------------------------------ abre


def folha_abre(semente):
    """6 quadros: a bolota cai e a rede se abre (raios primeiro, depois os anéis; as pontas soltas esticam e somem). O último é o repouso."""
    quadros = []
    esc = [0.30, 0.55, 0.78, 0.95, 1.04, 1.0]
    aneis = [1, 2, 3, 5, 6, 6]
    esparso = [0.45, 0.3, 0.15, 0.06, 0.0, 0.0]
    for k in range(6):
        q = Quadro()
        if k == 5:
            xs, ys, rs, th, rnd, tp = teia(semente).arr()
        else:
            xs, ys, rs, th, rnd, tp = teia(semente, escala=esc[k], aneis_ate=aneis[k], esparso=esparso[k]).arr()
        q.fios(xs, ys, rs, rnd, tp)
        if k < 4:  # fiapos soltos que a pancada joga para fora (ficam 1 quadro, 2 a 3 px, na direção do raio)
            rng = random.Random(semente * 100 + k)
            for _ in range(10):
                a = rng.random() * math.tau
                r0 = esc[k] * 1.0 * rng.uniform(1.0, 1.12)
                x0, y0 = math.cos(a) * r0 * RX, math.sin(a) * r0 * RY
                for t in range(rng.randint(2, 4)):
                    q.pinta(round(x0 + math.cos(a) * t * 1.5), round(y0 + math.sin(a) * t * 0.9), MEDIO)
        quadros.append(q)
    return quadros


# ------------------------------------------------------------------ queima


def ang_dist(a, b):
    d = abs((a - b + math.pi) % math.tau - math.pi)
    return d


def folha_queima(semente):
    """8 quadros (linha 0 = ignição no canto de cima à esquerda; as outras 3 vêm por espelho). O fogo nasce num ponto do anel e corre pelos dois
    lados; do anel desce pelos raios para o centro. Cada pixel: fio, chama (do claro ao vermelho), brasa, cinza e some."""
    f = teia(semente)
    xs, ys, rs, th, rnd, tp = f.arr()
    th0 = math.radians(215.0)  # o ponto da ignição na elipse (em cima, à esquerda)
    n = len(xs)
    rng = random.Random(semente * 7 + 3)
    # instante (0 a ~0.55) em que cada pixel pega fogo: o anel queima por distância angular, o raio por distância ao anel
    t_ign = np.zeros(n)
    for k in range(n):
        da = ang_dist(th[k], th0) / math.pi  # 0 no ponto da ignição, 1 no oposto
        t_ign[k] = da * 0.34 + (1.0 - min(rs[k], 1.0)) * 0.2 + rnd[k] * 0.03
    quadros = []
    for k in range(8):
        tau = k / 7.0
        q = Quadro()
        frng = random.Random(semente * 31 + k)

        def cor(i):
            idade = tau - t_ign[i]
            if idade < 0:
                return cor_fio(rs[i], rnd[i], tp[i])
            if idade < 0.18:
                c = idade / 0.18
                return FOGO[min(int(c * 3.2 + rnd[i] * 0.8), 3)]
            if idade < 0.3:
                return BRASA[0] if rnd[i] > 0.35 else BRASA[1]
            if idade < 0.5:
                return None if rnd[i] < (idade - 0.3) / 0.2 * 0.9 + 0.1 else CINZA[0 if rnd[i] > 0.5 else 1]
            return None

        q.fios(xs, ys, rs, rnd, tp, sombra=True, cor_fn=cor)
        # as línguas de fogo: sobem 1 a 4 px acima de cada pixel que está em chamas
        for i in range(n):
            idade = tau - t_ign[i]
            if 0 <= idade < 0.2 and rnd[i] < 0.62:
                forca = 1.0 - idade / 0.2
                alt = 1 + int(forca * (2.4 + 2.0 * frng.random()))
                if k == 0 and idade < 0.02:
                    alt = 2
                for h in range(alt):
                    t = h / max(alt - 1, 1)
                    cc = FOGO[min(int(1 + t * 3), 4)] if h > 0 else FOGO[1]
                    jx = frng.choice((-1, 0, 0, 1)) if h >= 2 else 0
                    q.pinta(xs[i] + jx, ys[i] - 1 - h, cc)
        # faíscas que sobem
        if 0.05 < tau < 0.9:
            for i in range(n):
                idade = tau - t_ign[i]
                if 0.02 < idade < 0.12 and rnd[i] > 0.93:
                    q.pinta(xs[i] + frng.randint(-2, 2), ys[i] - 5 - frng.randint(0, 4), FOGO[1])
        quadros.append(q)
    return quadros


# ------------------------------------------------------------------ corte e quebra


def desloca(q, xs, ys, cores, dx, dy):
    for i in range(len(xs)):
        if cores[i] is not None:
            q.pinta(xs[i] + int(round(dx[i])), ys[i] + int(round(dy[i])), cores[i])


def sombras(q, cores_xy):
    for (x, y), c in cores_xy:
        if q.vazio(x, y + 1):
            q.pinta(x, y + 1, SOMBRA)


def risco(q, a, b, largura, fase):
    """O risco brilhante do golpe: do ponto a ao b, miolo branco e bordas amarela e laranja, mais fino nas pontas. `fase` 0..1: quanto da reta."""
    n = max(int(math.hypot(b[0] - a[0], b[1] - a[1]) * 1.5), 1)
    for s in range(int(n * fase) + 1):
        t = s / n
        x = a[0] + (b[0] - a[0]) * t
        y = a[1] + (b[1] - a[1]) * t
        w = largura * (1 - (2 * t - 1) ** 2) ** 0.7
        for dy in range(-2, 3):
            d = abs(dy) / 1.6
            if d <= w / 2.0 + 0.2:
                cor = RISCO[0] if d < 0.45 else (RISCO[1] if d < 0.95 else RISCO[2])
                q.pinta(round(x), round(y) + dy, cor)


def folha_corte(semente, invertido):
    """7 quadros: o risco atravessa (em "/"; `invertido` espelha para "\\"), a rede parte em dois lados que se afastam e em pedaços que encolhem e somem."""
    f = teia(semente)
    xs, ys, rs, th, rnd, tp = f.arr()
    n = len(xs)
    rng = random.Random(semente * 13 + 5)
    a = (-36.0, 19.0)
    b = (36.0, -19.0)
    dxl, dyl = b[0] - a[0], b[1] - a[1]
    comp = math.hypot(dxl, dyl)
    ux, uy = dxl / comp, dyl / comp
    nx, ny = uy, -ux  # normal da reta
    lado = np.array([1.0 if ((xs[i] - a[0]) * ny - (ys[i] - a[1]) * nx) * -1 > 0 else -1.0 for i in range(n)])
    # sinal pela distância assinada à reta
    dist = np.array([(xs[i] - a[0]) * nx + (ys[i] - a[1]) * ny for i in range(n)])
    lado = np.where(dist >= 0, 1.0, -1.0)
    # os pedaços: sementes espalhadas em cada lado; cada pixel vai para a mais próxima do mesmo lado
    sem = []
    for s in (1.0, -1.0):
        for _ in range(4):
            t = rng.uniform(-0.8, 0.8)
            off = s * rng.uniform(4, 20)
            sem.append((a[0] + dxl * (t + 1) / 2 + nx * off, a[1] + dyl * (t + 1) / 2 + ny * off, s))
    chunk = np.zeros(n, int)
    for i in range(n):
        melhor, bd = 0, 1e9
        for c, (sx, sy, s) in enumerate(sem):
            if s != lado[i]:
                continue
            d = (xs[i] - sx) ** 2 + ((ys[i] - sy) / ACHATA) ** 2
            if d < bd:
                melhor, bd = c, d
        chunk[i] = melhor
    cen = {}
    for c in set(chunk.tolist()):
        idx = np.where(chunk == c)[0]
        cen[c] = (float(xs[idx].mean()), float(ys[idx].mean()))
    vel = {c: (nx * lado[np.where(chunk == c)[0][0]] * rng.uniform(0.8, 1.4) + rng.uniform(-0.5, 0.5) * ux,
               ny * lado[np.where(chunk == c)[0][0]] * rng.uniform(0.8, 1.4) + rng.uniform(-0.5, 0.5) * uy) for c in cen}
    vida = {c: rng.uniform(0.55, 1.0) for c in cen}  # quando (0 a 1 do tempo de pedaços) o pedaço some inteiro
    quadros = []
    for k in range(7):
        q = Quadro()
        if k <= 1:
            q.fios(xs, ys, rs, rnd, tp)
            risco(q, a, b, 4.0 if k == 1 else 3.0, 0.5 if k == 0 else 1.0)
        else:
            t = (k - 2) / 4.0  # 0 a 1 ao longo dos 5 quadros em que a rede se solta
            cores = []
            dx = []
            dy = []
            for i in range(n):
                c = int(chunk[i])
                sol = 1.6 + 5.0 * t + (1.0 + 3.0 * t) * t
                encolhe = 1.0 - 0.5 * t
                px = cen[c][0] + (xs[i] - cen[c][0]) * encolhe
                py = cen[c][1] + (ys[i] - cen[c][1]) * encolhe
                dx.append(px - xs[i] + vel[c][0] * sol)
                dy.append(py - ys[i] + vel[c][1] * sol * 0.8 + 0.6 * t * t * 4)
                morre = t > vida[c] * 1.05 or rnd[i] < t * t * 0.9
                cores.append(None if morre else cor_fio(rs[i], rnd[i], tp[i]))
            pos = []
            for i in range(n):
                if cores[i] is not None:
                    pos.append(((int(xs[i] + round(dx[i])), int(ys[i] + round(dy[i]))), cores[i]))
            # sombra primeiro (não cobre fio) e fios depois
            for (xy, c) in pos:
                q.pinta(xy[0], xy[1], c)
            for (xy, c) in pos:
                if q.vazio(xy[0], xy[1] + 1):
                    q.pinta(xy[0], xy[1] + 1, SOMBRA)
            if k <= 4:  # o rastro do risco some e solta faíscas ao longo da reta
                risco(q, (a[0] + ux * 3 * (k - 1), a[1] + uy * 3 * (k - 1)), (b[0] - ux * 3 * (k - 1), b[1] - uy * 3 * (k - 1)), 2.0 if k == 2 else 1.0, 1.0)
            frng = random.Random(semente * 17 + k)
            for _ in range(14 if k <= 3 else 5):
                s = frng.uniform(0, 1)
                px_ = a[0] + dxl * s + frng.uniform(-6, 6)
                py_ = a[1] + dyl * s + frng.uniform(-5, 5) - k
                q.pinta(round(px_), round(py_), RISCO[frng.choice((0, 1, 1, 2))])
        if invertido:
            q.px = q.px[:, ::-1].copy()
        quadros.append(q)
    return quadros


def folha_quebra(semente):
    """7 quadros: o martelo (ou o giro de 360 graus) estoura a rede de dentro para fora: uma onda branca na elipse e 20 pedaços que voam para fora, encolhem e somem."""
    f = teia(semente)
    xs, ys, rs, th, rnd, tp = f.arr()
    n = len(xs)
    rng = random.Random(semente * 19 + 1)
    setores = 10
    chunk = np.array([int(((th[i] % math.tau) / math.tau) * setores) * 2 + (0 if rs[i] < 0.55 else 1) for i in range(n)])
    cen = {}
    for c in set(chunk.tolist()):
        idx = np.where(chunk == c)[0]
        cen[c] = (float(xs[idx].mean()), float(ys[idx].mean()))
    vel = {c: rng.uniform(0.9, 1.5) for c in cen}
    vida = {c: rng.uniform(0.5, 1.0) for c in cen}
    quadros = []
    for k in range(7):
        q = Quadro()
        t = k / 6.0
        if k >= 1:
            t = (k - 1) / 5.0
        pos = []
        for i in range(n):
            c = int(chunk[i])
            ox, oy = cen[c]
            d = math.hypot(ox / RX, oy / RY) + 1e-6
            ex, ey = (ox / RX) / d, (oy / RY) / d  # rumo para fora (no plano do chão)
            if k == 0:
                sol = 0.0
            else:
                sol = (3.0 + 9.0 * t) * vel[c]
            encolhe = 1.0 - (0.0 if k == 0 else 0.55 * t)
            px = ox + (xs[i] - ox) * encolhe + ex * sol * 1.0
            py = oy + (ys[i] - oy) * encolhe + ey * sol * ACHATA - (4.0 * t * (1 - t) * 3.0 if k > 0 else 0.0)
            morre = k > 0 and (t > vida[c] * 1.05 or rnd[i] < t * t * 0.85)
            if not morre:
                pos.append(((int(round(px)), int(round(py))), cor_fio(rs[i], rnd[i], tp[i])))
        for (xy, c) in pos:
            q.pinta(xy[0], xy[1], c)
        for (xy, c) in pos:
            if q.vazio(xy[0], xy[1] + 1):
                q.pinta(xy[0], xy[1] + 1, SOMBRA)
        if k <= 3:  # a onda do golpe: um anel branco que abre na elipse
            raio = (0.35 + 0.28 * k)
            m = int(220 * RX * raio)
            for s in range(m):
                a = s / m * math.tau
                cor = RISCO[0] if k <= 1 else RISCO[1]
                q.pinta(round(math.cos(a) * RX * raio), round(math.sin(a) * RY * raio), cor)
        quadros.append(q)
    return quadros


def folha_some(semente):
    """6 quadros: o repouso e a teia desmancha de fora para dentro (pixels que somem aos poucos, sem meio-alfa). O último é vazio."""
    f = teia(semente)
    xs, ys, rs, th, rnd, tp = f.arr()
    quadros = []
    for k in range(6):
        q = Quadro()
        prog = k / 5.0
        corte = 1.15 - prog * 1.35  # o raio abaixo do qual o fio ainda existe (vai de fora para dentro)
        q.fios(xs, ys, rs, rnd, tp, cor_fn=lambda i: (cor_fio(rs[i], rnd[i], tp[i]) if (rs[i] + rnd[i] * 0.35 < corte or (k == 0)) else None))
        quadros.append(q)
    return quadros


# ------------------------------------------------------------------ bolota e rede no ar


def folha_bolota():
    """16x16, 4 quadros: a bola de teia (raio 4) girando: três 'meridianos' que andam a cada quadro."""
    quadros = []
    for k in range(4):
        q = Quadro(16, 16, 8, 8)
        r = 4.2
        pts = []
        for y in range(-5, 6):
            for x in range(-5, 6):
                if (x * x + y * y) <= r * r + 0.5:
                    pts.append((x, y))
        for (x, y) in pts:
            q.pinta(x, y, MEDIO)
        for m in range(3):
            a0 = (m / 3.0 + k / 12.0) * math.pi
            for s in range(-12, 13):
                t = s / 12.0
                x = math.cos(a0) * t * r
                y = math.sin(a0) * t * r
                if abs(x) + abs(y) < 99 and (round(x), round(y)) in pts:
                    q.pinta(round(x), round(y), CLARO)
        for (x, y) in pts:
            if (x * x + y * y) >= (r - 0.9) ** 2 and (x + y + k) % 2 == 0:
                q.pinta(x, y, TENUE)
        # contorno escuro (1 px) em volta
        q2 = Quadro(16, 16, 8, 8)
        q2.px = q.px.copy()
        for yy in range(16):
            for xx in range(16):
                if q.px[yy, xx, 3] == 0:
                    for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        x2, y2 = xx + dx, yy + dy
                        if 0 <= x2 < 16 and 0 <= y2 < 16 and q.px[y2, x2, 3] > 0 and tuple(q.px[y2, x2, :3]) != SOMBRA:
                            q2.px[yy, xx] = (SOMBRA[0], SOMBRA[1], SOMBRA[2], 255)
                            break
        quadros.append(q2)
    return quadros


def folha_abre_ar():
    """24x24, 4 quadros: a bolota vira uma rede que abre no ar (elipse 0,62, a mesma da teia no chão): raio 4, 7, 9 e 11 px."""
    quadros = []
    for k, rx in enumerate((4, 7, 9, 11)):
        q = Quadro(24, 24, 12, 12)
        ry = rx * ACHATA
        n = 8
        for i in range(n):
            a = i * math.tau / n + 0.2
            for (x, y) in reta(0, 0, math.cos(a) * rx, math.sin(a) * ry):
                q.pinta(x, y, CLARO)
        for rr in ((0.5,) if k < 2 else (0.4, 0.75)):
            for i in range(n):
                a1 = i * math.tau / n + 0.2
                a2 = (i + 1) * math.tau / n + 0.2
                p1 = (math.cos(a1) * rx * rr, math.sin(a1) * ry * rr)
                p2 = (math.cos(a2) * rx * rr, math.sin(a2) * ry * rr)
                pm = (math.cos((a1 + a2) / 2) * rx * rr * 0.9, math.sin((a1 + a2) / 2) * ry * rr * 0.9)
                for (x, y) in reta(p1[0], p1[1], pm[0], pm[1]) + reta(pm[0], pm[1], p2[0], p2[1]):
                    q.pinta(x, y, MEDIO)
        for yy in range(24):
            for xx in range(24):
                if q.px[yy, xx, 3] > 0 and tuple(q.px[yy, xx, :3]) != SOMBRA and yy + 1 < 24 and q.px[yy + 1, xx, 3] == 0:
                    q.px[yy + 1, xx] = (SOMBRA[0], SOMBRA[1], SOMBRA[2], 255)
        quadros.append(q)
    return quadros


# ------------------------------------------------------------------ montagem


def monta(linhas):
    """linhas: lista de listas de Quadro (uma por linha da folha). Devolve a imagem."""
    n_col = len(linhas[0])
    w, h = linhas[0][0].w, linhas[0][0].h
    img = Image.new("RGBA", (w * n_col, h * len(linhas)), (0, 0, 0, 0))
    for l, qs in enumerate(linhas):
        for c, q in enumerate(qs):
            img.paste(q.imagem(), (c * w, l * h))
    return img


def espelha(qs, h=False, v=False):
    out = []
    for q in qs:
        n = Quadro(q.w, q.h, q.cx, q.cy)
        px = q.px
        if h:
            px = px[:, ::-1]
        if v:
            px = px[::-1, :]
        n.px = px.copy()
        out.append(n)
    return out


def luminancia_media(q):
    a = q.px.astype(np.float32)
    lum = (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]) / 255.0
    return float((lum * (a[..., 3] / 255.0)).mean())


def principal():
    os.makedirs(SAIDA, exist_ok=True)
    abre = [folha_abre(s) for s in SEMENTES]
    monta(abre).save(os.path.join(SAIDA, "teia_abre.png"))
    linhas_q = []
    lums = []
    for s in SEMENTES:
        base = folha_queima(s)
        lums.append([luminancia_media(q) for q in base])
        for bits in range(4):
            linhas_q.append(espelha(base, h=bool(bits & 1), v=bool(bits & 2)))
    monta(linhas_q).save(os.path.join(SAIDA, "teia_queima.png"))
    cortes = []
    for s in SEMENTES:
        cortes.append(folha_corte(s, False))
        cortes.append(folha_corte(s, True))
    monta(cortes).save(os.path.join(SAIDA, "teia_corte.png"))
    monta([folha_quebra(s) for s in SEMENTES]).save(os.path.join(SAIDA, "teia_quebra.png"))
    monta([folha_some(s) for s in SEMENTES]).save(os.path.join(SAIDA, "teia_some.png"))
    monta([folha_bolota()]).save(os.path.join(SAIDA, "teia_bolota.png"))
    monta([folha_abre_ar()]).save(os.path.join(SAIDA, "teia_abre_ar.png"))
    print("folhas em", SAIDA)
    for nome, (w, h, c, l) in {
        "teia_abre": (W, H, 6, len(SEMENTES)),
        "teia_queima": (W, H, 8, 4 * len(SEMENTES)),
        "teia_corte": (W, H, 7, 2 * len(SEMENTES)),
        "teia_quebra": (W, H, 7, len(SEMENTES)),
        "teia_some": (W, H, 6, len(SEMENTES)),
        "teia_bolota": (16, 16, 4, 1),
        "teia_abre_ar": (24, 24, 4, 1),
    }.items():
        print("%-14s quadro %dx%d colunas %d linhas %d" % (nome, w, h, c, l))
    for s, l in zip(SEMENTES, lums):
        print("luminancia queima semente %d:" % s, " ".join("%.4f" % v for v in l))


if __name__ == "__main__":
    principal()

"""Folhas do golpe de MARTELO (kanabo do Nick): rastro de impacto pesado, impacto da batida e onda de choque da pancada em volta.

Arte PROCEDURAL própria (numpy + Pillow, semente fixa), no mesmo formato das folhas de efeito em 1 px de arte = 1 px do jogo
(dados/v2_folhas_fx.json, v2/efeitos.gd): R = calor, A = intensidade, quadros em linha, UM ARQUIVO POR TAMANHO, desenho ponto a ponto direto
no tamanho final (nada é reamostrado nem girado depois). O katana/naginata continuam com o corte de lâmina (corte_pfx.py); isto aqui é só do martelo.

  martelo_rastro  : o martelo descendo, 16 direções como o corte (4 linhas = 0, 22,5, 45 e 67,5 graus; os quartos de volta são o UV trocado no
                    shader). Rastro CURTO e GROSSO que afina para trás, com a cabeça (bloco) na frente e um clarão pequeno no contato.
  martelo_impacto : o ponto onde a batida cai: flash, anel de choque achatado no chão (0,62 no Y, avisos.ACHATA), rachaduras radiais que
                    crescem e somem, pedrinhas que saltam e poeira. Sem direção.
  martelo_onda    : a pancada em volta (360 graus): disco de choque, dois anéis, rachaduras em estrela, mais pedras e poeira. Sem direção.

Uso (da raiz do repositório):  python jogos/hordas/fonte_arte/martelo/gerar_martelo.py
Saída: projeto/assets/v2/efeitos/efeito_martelo_<nome>_e<largura>.png e as três entradas em projeto/dados/v2_folhas_fx.json (as demais ficam como estão).
Opcional: --previa <pasta>  grava folhas de contato ampliadas (só para olhar, fora do jogo).

Referência de IDEIA: o hammer-smash do pixelfx (MIT, notas/pixelfx/src/fx/melee/hammer-smash.js). Nenhuma imagem nem código de terceiros foi copiado.
"""

import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto"))
SAIDA = os.path.join(PROJETO, "assets", "v2", "efeitos")
JSON_FX = os.path.join(PROJETO, "dados", "v2_folhas_fx.json")

ACHATA = 0.62  # a mesma de v2/avisos.gd: o chão visto de 2.5D
TONS = ((255, 255), (170, 212), (85, 128), (40, 64), (0, 212), (0, 128), (0, 64))  # (calor, intensidade), do mais claro ao mais fraco (os mesmos do corte)
# Tons 4 a 6 = RACHADURA ESCURA (calor 0): o jogo desenha calor 0 como terra escura em mistura normal (v2/efeitos.gd SHADER_CHAO_MARTELO), nunca como luz.
ESCURO = 4
GIRO = 22.5  # graus por linha da folha do rastro

# nome: quadros, linhas, larguras dos tamanhos. O jogo escolhe o tamanho mais perto do pedido (v2/efeitos.gd:tamanho_perto).
RASTRO = dict(quadros=10, linhas=4, larguras=[96, 128, 160, 200, 248, 312])
IMPACTO = dict(quadros=12, linhas=1, larguras=[56, 72, 96, 128, 168])
ONDA = dict(quadros=14, linhas=1, larguras=[96, 128, 168, 216, 280])
QUADRO_ACERTO = 5  # no rastro, o quadro em que a cabeça toca o chão (o acerto do Nick cai em ~metade do rastro)


def par(v: float) -> int:
    return int(round(v / 2.0)) * 2


class Quadro:
    """Um quadro: tom (0 a 3, menor = mais claro) por pixel; 9 = vazio."""

    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.t = np.full((h, w), 9, dtype=np.uint8)

    def pinta(self, x: int, y: int, tom: int) -> None:
        if 0 <= x < self.w and 0 <= y < self.h and 0 <= tom <= 6 and tom < self.t[y, x]:
            self.t[y, x] = tom

    def mascara(self, m: np.ndarray, tom: int) -> None:
        if 0 <= tom <= 6:
            self.t[m & (self.t > tom)] = tom

    def linha(self, x0: int, y0: int, x1: int, y1: int, tom: int, grossura: int = 1) -> None:
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            for ox in range(grossura):
                for oy in range(grossura):
                    self.pinta(x0 + ox, y0 + oy, tom)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def rgba(self) -> np.ndarray:
        saida = np.zeros((self.h, self.w, 4), dtype=np.uint8)
        for tom, (calor, alfa) in enumerate(TONS):
            m = self.t == tom
            saida[m] = (calor, calor, calor, alfa)
        return saida


def tom_de(nivel: float) -> int:
    """Nível de brilho (0 a 1) vira tom (0 a 3); abaixo do piso, 9 (some)."""
    if nivel >= 0.75:
        return 0
    if nivel >= 0.5:
        return 1
    if nivel >= 0.28:
        return 2
    if nivel > 0.1:
        return 3
    return 9


def ease_out(u: float) -> float:
    u = min(max(u, 0.0), 1.0)
    return 1.0 - (1.0 - u) * (1.0 - u)


def grade(w: int, h: int):
    ys, xs = np.mgrid[0:h, 0:w]
    return xs + 0.5 - w / 2.0, ys + 0.5 - h / 2.0


# ----------------------------------------------------------------------------------------------------------------- chão (impacto e onda)


def pedras(rng: random.Random, n: int, raio: float, forte: float) -> list:
    lista = []
    for _ in range(n):
        a = rng.uniform(0, math.tau)
        v = rng.uniform(0.55, 1.15)
        lista.append(
            dict(
                vx=math.cos(a) * raio * 0.085 * v,
                vy=math.sin(a) * raio * 0.085 * v * ACHATA,
                vz=raio * 0.2 * forte * rng.uniform(0.7, 1.2),
                g=raio * 0.032 * forte,
                x0=math.cos(a) * raio * 0.18,
                y0=math.sin(a) * raio * 0.18 * ACHATA,
                tam=rng.choice((1, 1, 2)),
            )
        )
    return lista


def rachaduras(rng: random.Random, n: int, raio: float) -> list:
    """Cada rachadura: lista de pontos (x, y) já achatados em ACHATA, do centro para fora, mais um galho curto."""
    lista = []
    giro = rng.uniform(0, math.tau)
    for i in range(n):
        a = giro + math.tau * (i + rng.uniform(-0.25, 0.25)) / n
        comp = raio * rng.uniform(0.55, 0.95)
        pts = []
        r = raio * 0.12
        while r < comp:
            a += math.radians(rng.uniform(-16, 16))
            pts.append((math.cos(a) * r, math.sin(a) * r * ACHATA))
            r += max(2.0, raio * rng.uniform(0.07, 0.12))
        pts.append((math.cos(a) * comp, math.sin(a) * comp * ACHATA))
        galho = None
        if len(pts) >= 4 and rng.random() < 0.8:
            k = rng.randint(2, len(pts) - 2)
            ag = a + math.radians(rng.choice((-1, 1)) * rng.uniform(35, 55))
            bx, by = pts[k]
            gl = comp * rng.uniform(0.18, 0.3)
            galho = [(bx, by), (bx + math.cos(ag) * gl, by + math.sin(ag) * gl * ACHATA)]
        lista.append(dict(pts=pts, galho=galho))
    return lista


def poeira(rng: random.Random, n: int, raio: float) -> list:
    lista = []
    for i in range(n):
        a = math.tau * (i + rng.uniform(-0.3, 0.3)) / n
        lista.append(dict(a=a, f0=rng.randint(2, 4), pr=raio * rng.uniform(0.06, 0.1), sobe=raio * rng.uniform(0.01, 0.025)))
    return lista


def chao(tipo: dict, w: int, onda: bool, semente: int) -> list:
    """Os quadros (Quadro) do impacto da batida (onda=False) ou da pancada em volta (onda=True) para a largura w."""
    h = par(w * ACHATA)
    n = tipo["quadros"]
    raio = w / 2.0 - 2.0
    rng = random.Random(semente + w)
    xs, ys = grade(w, h)
    dist = np.sqrt(xs * xs + (ys / ACHATA) ** 2)
    rach = rachaduras(rng, 12 if onda else 7, raio)
    ped = pedras(rng, 14 if onda else 8, raio, 1.15 if onda else 1.0)
    poe = poeira(rng, 14 if onda else 8, raio)
    fim_anel = int(n * (0.62 if onda else 0.58))
    quadros = []
    for f in range(n):
        q = Quadro(w, h)
        u = f / (n - 1)
        vida = 1.0 - u
        # onda: em vez do disco cheio, um anel fino e fraco que abre (sem preencher o chão, os monstros continuam à vista)
        if onda and 1 <= f <= fim_anel:
            rr = raio * (0.18 + 0.82 * ease_out(f / fim_anel)) * 0.9
            q.mascara(np.abs(dist - rr) < 1.0, tom_de(0.45 - 0.35 * f / fim_anel))
        # clarão do contato: PEQUENO e curto (1 a 2 quadros), só no centro, bem dentro do anel
        if f <= 1:
            rf = raio * (0.06, 0.09)[f] * (1.2 if onda else 1.0)
            q.mascara(dist < rf, 0 if f == 0 else 1)
            if f == 1:
                q.mascara(dist < rf * 1.3, 2)
        # anel(éis) de choque, achatado
        pulsos = [(0, 1.0)] + ([(4, 0.72)] if onda else [])
        for atraso, forca in pulsos:
            fa = f - atraso
            if fa < 1 or fa > fim_anel + 3:
                continue
            ua = min(fa / fim_anel, 1.0)
            rr = raio * forca * (0.2 + 0.8 * ease_out(ua))
            grossura = max(1.0, raio * (0.07 if onda else 0.055) * (1.0 - 0.7 * ua)) * (1.0 if atraso == 0 else 0.7)
            nivel = min(0.7, 1.0 - 0.9 * ua) * (1.0 if atraso == 0 else 0.8)  # teto 0,7: o anel nunca passa do 2o degrau (170 / 212)
            q.mascara(np.abs(dist - rr) < grossura * 0.5, tom_de(nivel))
            if grossura >= 2.4:  # a borda de dentro: a faixa de poeira atrás da frente da onda
                q.mascara((np.abs(dist - (rr - grossura * 0.9)) < grossura * 0.35) & (((xs + ys).astype(int)) % 2 == 0), tom_de(nivel - 0.3))
        # rachaduras ESCURAS de piso partido: crescem em 3 quadros e esmaecem (escuro 212 -> 128 -> 64 -> some); no começo, 1 px de borda clara
        if f >= 1:
            g = min((f - 1) / 3.0, 1.0) ** 0.6
            ue = (f - 1) / (n - 2)
            tr = ESCURO if ue < 0.4 else (ESCURO + 1 if ue < 0.7 else (ESCURO + 2 if ue < 0.9 else 9))
            if tr != 9:
                for rc in rach:
                    pts = rc["pts"]
                    ate = max(1, int(round(len(pts) * g)))
                    seg = [(w // 2, h // 2)] + [(w // 2 + int(round(x)), h // 2 + int(round(y))) for x, y in pts[:ate]]
                    ramos = [(a, b, 2 if (onda and raio > 70 and a == seg[0]) else 1) for a, b in zip(seg, seg[1:])]
                    if rc["galho"] and g >= 0.75:
                        (ax, ay), (bx, by) = rc["galho"]
                        ramos.append(((w // 2 + int(round(ax)), h // 2 + int(round(ay))), (w // 2 + int(round(bx)), h // 2 + int(round(by))), 1))
                    if f <= 3:  # a borda clara: 1 px acima do traço, só nos primeiros quadros (luz batendo na quina do piso)
                        for a, b, gr in ramos:
                            q.linha(a[0], a[1] - 1, b[0], b[1] - 1, 3 if f > 1 else 2, 1)
                    for a, b, gr in ramos:
                        q.linha(a[0], a[1], b[0], b[1], tr, gr)
        # pedrinhas que saltam (sobem, caem, somem)
        grande = 2 if raio > 60 else 1
        for p in ped:
            t = f - 1
            if t < 0:
                continue
            z = p["vz"] * t - 0.5 * p["g"] * t * t
            if z < -1:
                continue
            x = w / 2 + p["x0"] + p["vx"] * t
            y = h / 2 + p["y0"] + p["vy"] * t - max(z, 0.0)
            tam = min(p["tam"], grande)
            tp = 0 if z > p["vz"] * 0.5 else 1
            for ox in range(tam):
                for oy in range(tam):
                    q.pinta(int(x) + ox, int(y) + oy, tp)
        # poeira: bolotas em xadrez que sobem devagar e esmaecem
        for pu in poe:
            fa = f - pu["f0"]
            if fa < 0 or fa > n - 2 - pu["f0"]:
                continue
            up = fa / max(1, n - 2 - pu["f0"])
            rr = raio * (0.55 + 0.4 * ease_out(min(1.0, (f - 1) / fim_anel))) if onda else raio * (0.45 + 0.4 * ease_out(min(1.0, (f - 1) / fim_anel)))
            cx = w / 2 + math.cos(pu["a"]) * rr
            cy = h / 2 + math.sin(pu["a"]) * rr * ACHATA - pu["sobe"] * fa * 2.5
            pr = pu["pr"] * (0.8 + 0.8 * up)
            td = tom_de(0.55 - 0.5 * up)
            if td == 9:
                continue
            m = ((xs + w / 2 - cx) ** 2 + (ys + h / 2 - cy) ** 2 < pr * pr) & (((xs + ys).astype(int)) % 2 == 0)
            q.mascara(m, max(td, 2))
        quadros.append(q)
    # nada na borda do quadro (a folha não pode ter pixel preso à borda)
    for q in quadros:
        q.t[0, :] = 9
        q.t[-1, :] = 9
        q.t[:, 0] = 9
        q.t[:, -1] = 9
    return quadros


# ----------------------------------------------------------------------------------------------------------------- rastro (martelo descendo)


def rastro(tipo: dict, l: int, linha: int) -> list:
    """Os quadros do rastro do martelo para o quadro quadrado de lado l, na linha `linha` (direção 22,5 x linha graus)."""
    n = tipo["quadros"]
    metade = l / 2.0
    rho = metade * 0.615  # onde a cabeça passa: o ponto do acerto (0,8 do alcance de um quadro de 2 x 1,3 alcance)
    xs, ys = grade(l, l)
    r = np.sqrt(xs * xs + ys * ys)
    a = np.degrees(np.arctan2(ys, xs)) - GIRO * linha  # o ângulo do pixel no desenho "apontando para leste"
    a = (a + 180.0) % 360.0 - 180.0
    quadros = []
    for f in range(n):
        q = Quadro(l, l)
        if f <= QUADRO_ACERTO:
            u = f / QUADRO_ACERTO
            cab = -85.0 * (1.0 - u ** 1.6)  # a cabeça acelera: parte de cima (-85 graus) e desce até o leste (0)
            cauda_graus = 30.0 + 55.0 * min(1.0, u * 1.3)  # o rastro fica mais comprido conforme ganha velocidade
            vivo = 1.0
        else:
            cab = 0.0
            ap = (f - QUADRO_ACERTO) / (n - 1 - QUADRO_ACERTO)  # 0 a 1 depois do acerto
            cauda_graus = 85.0 * (1.0 - 0.85 * ap)  # o rastro encolhe de trás para a frente
            vivo = 1.0 - ap
        # posição ao longo do rastro: s = 0 na cabeça, 1 na ponta de trás (ângulos MENORES que o da cabeça)
        s = (cab - a) / max(cauda_graus, 1.0)
        dentro = (s >= 0.0) & (s <= 1.0)
        meia = metade * 0.17 * (1.0 - 0.7 * np.clip(s, 0.0, 1.0) ** 0.8)  # grosso na frente, afina para trás
        if f > QUADRO_ACERTO:
            meia = meia * (0.5 + 0.5 * vivo)
        m = dentro & (np.abs(r - rho) < meia)
        # veios: falhas finas só na metade de trás dão sensação de velocidade
        veio = (np.floor(a / 4.0).astype(int) % 3 == 0) & (s > 0.55) & (np.abs(r - rho) > meia * 0.5)
        m &= ~veio
        limites = ((0.0, 0.18, 0), (0.18, 0.42, 1), (0.42, 0.72, 2), (0.72, 1.01, 3))
        for lo, hi, tom in limites:
            sub = m & (s <= hi) & ((s > lo) if lo > 0 else (s >= 0))
            tt = tom_de((1.0 - tom * 0.22) * vivo) if f > QUADRO_ACERTO else tom
            if tt != 9:
                q.mascara(sub, tt)
        # a cabeça do martelo: um bloco claro e curto na frente do rastro
        if f <= QUADRO_ACERTO:
            ah = math.radians(cab + GIRO * linha)
            hx, hy = math.cos(ah) * rho, math.sin(ah) * rho
            rx, ry = math.cos(ah), math.sin(ah)
            tx, ty = -ry, rx
            dx, dy = xs - hx, ys - hy
            rad = dx * rx + dy * ry
            tan = dx * tx + dy * ty
            cab_r = metade * 0.15
            cab_t = metade * 0.07
            q.mascara((np.abs(rad) < cab_r) & (tan > -cab_t) & (tan < cab_t * 0.6), 0)
        # no contato e logo depois: um clarão pequeno e um aro curto no ponto do acerto
        if QUADRO_ACERTO <= f <= QUADRO_ACERTO + 3:
            k = f - QUADRO_ACERTO
            ponto_x = math.cos(math.radians(GIRO * linha)) * rho
            ponto_y = math.sin(math.radians(GIRO * linha)) * rho
            dd = np.sqrt((xs - ponto_x) ** 2 + (ys - ponto_y) ** 2)
            if k == 0:
                q.mascara(dd < metade * 0.13, 0)
            elif k == 1:
                q.mascara(dd < metade * 0.1, 1)
            if k >= 1:
                rr = metade * (0.12 + 0.06 * k)
                q.mascara(np.abs(dd - rr) < max(1.0, metade * 0.03), tom_de(1.0 - k * 0.3))
        for lado in (0, l - 1):
            q.t[lado, :] = 9
            q.t[:, lado] = 9
        quadros.append(q)
    return quadros


# ----------------------------------------------------------------------------------------------------------------- folhas


def monta(quadros_por_linha: list) -> Image.Image:
    """quadros_por_linha: lista de linhas, cada uma uma lista de Quadro. Devolve a folha RGBA."""
    h = quadros_por_linha[0][0].h
    w = quadros_por_linha[0][0].w
    n = len(quadros_por_linha[0])
    folha = np.zeros((h * len(quadros_por_linha), w * n, 4), dtype=np.uint8)
    for li, linha in enumerate(quadros_por_linha):
        for fi, q in enumerate(linha):
            folha[li * h : (li + 1) * h, fi * w : (fi + 1) * w] = q.rgba()
    return Image.fromarray(folha, "RGBA")


def gera() -> dict:
    os.makedirs(SAIDA, exist_ok=True)
    tam = {"martelo_rastro": [], "martelo_impacto": [], "martelo_onda": []}
    folhas = {}
    for l in RASTRO["larguras"]:
        im = monta([rastro(RASTRO, l, k) for k in range(RASTRO["linhas"])])
        im.save(os.path.join(SAIDA, "efeito_martelo_rastro_e%d.png" % l), optimize=True)
        tam["martelo_rastro"].append([l, l])
        folhas[("rastro", l)] = im
    for nome, tipo, onda, sem in (("martelo_impacto", IMPACTO, False, 31), ("martelo_onda", ONDA, True, 47)):
        for w in tipo["larguras"]:
            qs = chao(tipo, w, onda, sem)
            im = monta([qs])
            im.save(os.path.join(SAIDA, "efeito_%s_e%d.png" % (nome, w)), optimize=True)
            tam[nome].append([w, qs[0].h])
            folhas[(nome, w)] = im
    return tam, folhas


def grava_json(tam: dict) -> None:
    with open(JSON_FX, encoding="utf8") as f:
        d = json.load(f)
    d["martelo_rastro"] = {"quadros": RASTRO["quadros"], "linhas": RASTRO["linhas"], "tam": tam["martelo_rastro"]}
    d["martelo_impacto"] = {"quadros": IMPACTO["quadros"], "linhas": IMPACTO["linhas"], "tam": tam["martelo_impacto"]}
    d["martelo_onda"] = {"quadros": ONDA["quadros"], "linhas": ONDA["linhas"], "tam": tam["martelo_onda"]}
    with open(JSON_FX, "w", encoding="utf8", newline="\n") as f:
        f.write(json.dumps(d, indent=1, ensure_ascii=False) + "\n")


def previa(folhas: dict, pasta: str) -> None:
    """Folhas de contato ampliadas (3x) sobre fundo escuro, só para olhar: tom -> cinza/ocre, com o alfa."""
    os.makedirs(pasta, exist_ok=True)
    for (nome, l), im in folhas.items():
        fundo = Image.new("RGBA", im.size, (38, 40, 34, 255))
        cor = Image.new("RGBA", im.size, (255, 205, 140, 255))
        a = im.split()[3]
        cor.putalpha(a)
        fundo.alpha_composite(cor)
        k = 2 if l > 150 else 3
        fundo.resize((fundo.width * k, fundo.height * k), Image.NEAREST).save(os.path.join(pasta, "previa_%s_%d.png" % (nome, l)))


if __name__ == "__main__":
    tam, folhas = gera()
    grava_json(tam)
    if "--previa" in sys.argv:
        previa(folhas, sys.argv[sys.argv.index("--previa") + 1])
    print("ok:", {k: [t[0] for t in v] for k, v in tam.items()})

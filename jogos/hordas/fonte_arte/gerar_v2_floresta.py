#!/usr/bin/env python3
"""Monta o ponto de partida de dados/v2_floresta.json (a floresta da v2, 2880x1620 = 3x3 telas).

Uso:  python jogos/hordas/fonte_arte/gerar_v2_floresta.py [--previa SAIDA.png]

Semente fixa: a saída é sempre a mesma. O JSON é DADOS: depois de gerado, pode ser editado à mão (e este script deixa de ser a
fonte). A prévia (--previa) cola os objetos e decalques de prototipos/ num PNG de 1/2 tamanho, só para olhar a composição (sem luz).

Composição (coordenadas do mundo, y para baixo):
  - o santuário no centro: o enquadramento aprovado do protótipo (círculo, torii, braseiro, ruínas, altar, lanternas) deslocado para o
    centro do mapa;
  - seis clareiras (acampamento NW, pântano NE, altar do crânio SW, ruína quebrada SE, cemitério N, campo de pedras S) ligadas ao
    santuário por trilhas de lajes;
  - árvores densas nas bordas, fechando o mapa; floresta rala no meio, fora de trilhas e clareiras;
  - poças, raízes na base das árvores grandes e grupos de folhas, musgo e galhos.
"""
import json
import math
import random
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
PROJ = RAIZ / "projeto"
SAIDA = PROJ / "dados" / "v2_floresta.json"
W, H = 2880, 1620
DESL = (960, 516)  # protótipo (960x540, círculo em 480,314) -> centro do mapa (círculo em 1440,830)
rng = random.Random(2025)

objetos = []  # [nome, x, y]
decalques = []  # [nome, x, y]
luzes = []  # dict
ocupados = []  # (x, y, raio) para não empilhar
tem = {}  # nome -> (w, h) dos objetos, preenchido ao ler o cenario.json


def obj(nome, x, y, raio=None, ocupa=True):
    x, y = int(round(x)), int(round(y))
    objetos.append([nome, x, y])
    if ocupa:
        r = raio if raio is not None else (34 if nome.startswith("arvore") else 14)
        ocupados.append((x, y, r))


def dec(nome, x, y):
    decalques.append([nome, int(round(x)), int(round(y))])


def livre(x, y, raio):
    return all((x - ox) ** 2 + (y - oy) ** 2 >= (raio + orr) ** 2 for ox, oy, orr in ocupados)


def d(p):
    return (p[0] + DESL[0], p[1] + DESL[1])


# ------------------------------------------------------------------ santuário (protótipo deslocado)
CIRC = d((480, 314))
dec("circulo", *CIRC)
for n, p in [("trilha_reta", (205, 338)), ("trilha_reta", (40, 342)), ("trilha_diagonal", (392, 478)), ("trilha_curva", (742, 392))]:
    dec(n, *d(p))
# árvores que enquadram o santuário (as mesmas do protótipo)
for n, p in [
    ("arvore", (82, 190)), ("arvore", (884, 178)), ("arvore", (470, 78)), ("arvore_pantano", (62, 536)), ("arvore_pantano", (906, 538)),
    ("arvore_morta", (330, 92)), ("arvore_morta", (655, 98)), ("arvore_morta", (24, 352)), ("arvore_morta", (940, 360)),
]:
    obj(n, *d(p))
# círculo de ruína em volta do herói
for n, p in [
    ("obelisco", (482, 212)), ("coluna", (392, 226)), ("pilar", (578, 232)), ("lapide", (334, 252)), ("lapide", (630, 258)),
    ("muro", (318, 268)), ("muro", (704, 296)), ("runa", (447, 236)), ("coluna", (352, 352)), ("pedestal", (610, 384)),
    ("lapide", (652, 338)), ("coluna", (628, 352)), ("pilar", (412, 402)), ("coluna", (540, 408)), ("lapide", (480, 418)),
]:
    obj(n, *d(p))
POS_POSTE, POS_TORO, POS_ALTAR = d((250, 160)), d((780, 215)), d((130, 445))
for n, p in [
    ("poste_lanterna", (250, 160)), ("toro", (780, 215)), ("altar", (130, 445)), ("caixa_oferenda", (86, 492)), ("torii", (240, 332)),
    ("braseiro", (322, 380)), ("fogueira", (858, 470)), ("torii_quebrado", (860, 300)), ("cranio", (188, 463)),
]:
    obj(n, *d(p), raio=20)
for n, p in [
    ("arbusto", (142, 214)), ("arbusto", (160, 524)), ("arbusto", (826, 206)), ("arbusto", (852, 520)), ("arbusto", (372, 118)), ("arbusto", (618, 128)),
    ("arbusto", (206, 292)), ("arbusto", (752, 468)), ("juncos", (190, 262)), ("juncos", (206, 276)), ("juncos", (742, 432)), ("juncos", (764, 446)),
    ("juncos", (790, 330)), ("raizes", (58, 206)), ("raizes", (924, 206)), ("raizes", (118, 498)), ("raizes", (884, 504)), ("cogumelos", (170, 312)),
    ("cogumelos", (808, 300)), ("cogumelos", (560, 486)), ("cogumelos", (304, 456)), ("toco", (222, 424)), ("tronco", (262, 446)), ("pedra", (120, 336)),
    ("rocha", (862, 410)), ("pedras", (566, 156)), ("pedras", (404, 468)), ("pedra", (700, 476)), ("rocha", (268, 206)), ("pedras", (770, 190)),
    ("toco", (700, 150)), ("tronco", (380, 520)),
]:
    obj(n, *d(p))
# raízes na base das árvores grandes, poças perto dos juncos
for n, p in [
    ("raiz_no", (82, 194)), ("raiz_estrela", (884, 184)), ("raiz_forquilha", (470, 86)), ("raiz_longa", (78, 528)), ("raiz_no", (902, 530)),
    ("raiz_forquilha", (330, 98)), ("raiz_longa", (655, 104)), ("raiz_estrela", (32, 360)), ("raiz_forquilha", (940, 366)),
]:
    dec(n, *d(p))
for p in [(176, 282), (758, 458), (804, 344)]:
    dec("poca", *d(p))
GRUPOS_PROTO = [(150, 250), (230, 420), (360, 140), (620, 150), (790, 240), (840, 420), (700, 480), (420, 500), (110, 420), (560, 490), (300, 470), (760, 130), (180, 130), (520, 130)]

FOLHAS, MUSGO, MIUDO, GALHOS = ["folhas_1", "folhas_2", "folhas_3"], ["musgo_1", "musgo_2", "musgo_3"], ["pedrinhas_1", "pedrinhas_2", "grama"], ["galho_1", "galho_2"]


def grupo(nomes, cx, cy, n, rx, ry):
    for _ in range(n):
        a, r = rng.random() * math.tau, math.sqrt(rng.random())
        dec(rng.choice(nomes), cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r)


def mancha(cx, cy, folhas=3, musgo=2, miudo=3, galhos=1, k=1.0):
    grupo(FOLHAS, cx, cy, folhas, 46 * k, 22 * k)
    grupo(MUSGO, cx + rng.uniform(-30, 30), cy + rng.uniform(-14, 14), musgo, 50 * k, 24 * k)
    grupo(MIUDO, cx, cy, miudo, 54 * k, 26 * k)
    grupo(GALHOS, cx, cy, galhos, 60 * k, 24 * k)


for c in GRUPOS_PROTO:
    mancha(*d(c))

# luzes do santuário que não são de objeto
luzes.append({"tipo": "magia_roxa", "pos": list(d((735, 250))), "orbe": [0, 0]})
luzes.append({"tipo": "magia_azul", "pos": list(d((590, 380))), "orbe": [0, 0]})
SANTUARIO = (960, 516, 1920, 1056)  # retângulo do enquadramento do protótipo no mundo

# ------------------------------------------------------------------ clareiras e trilhas
CLAREIRAS = {
    "acampamento": (520, 430, 250, 150),
    "pantano": (2380, 430, 270, 160),
    "altar": (520, 1230, 250, 150),
    "ruina": (2370, 1230, 260, 150),
    "cemiterio": (1450, 270, 230, 110),
    "pedras": (1440, 1410, 240, 100),
}
trilhas = []  # polilinhas (para o vazio da floresta)
PASSO_H, PASSO_D = 150, (62, 84)  # trilha_reta a cada 150 px; trilha_diagonal a cada (62, -84) px


def peca_h(x, y):
    dec("trilha_reta", x + rng.uniform(-4, 4), y + rng.uniform(-3, 3))


def peca_d(x, y, sx, sy):
    # trilha_diagonal da arte vai de baixo-esq. a cima-dir. ("/"); o outro sentido é a mesma peça espelhada (campo 4 do json)
    if sx * sy < 0:  # "/" : x cresce e y diminui (ou o contrário)
        dec("trilha_diagonal", x + rng.uniform(-4, 4), y + rng.uniform(-3, 3))
    else:
        decalques.append(["trilha_diagonal", int(round(x + rng.uniform(-4, 4))), int(round(y + rng.uniform(-3, 3))), 1])


def trilha(pontos):
    """Liga os pontos por trechos horizontais e diagonais. Cada trecho: horizontal até o x certo, depois diagonais até o y."""
    trilhas.append([list(p) for p in pontos])
    for (x0, y0), (x1, y1) in zip(pontos, pontos[1:]):
        dx, dy = x1 - x0, y1 - y0
        sx = 1 if dx >= 0 else -1
        sy = 1 if dy >= 0 else -1
        nd = int(round(abs(dy) / PASSO_D[1]))
        x, y = x0, y0
        # horizontal: o que sobra do dx depois das diagonais, dividido em duas metades (uma antes, outra depois)
        resto = abs(dx) - nd * PASSO_D[0]
        if resto < 0:
            nd = int(round(abs(dx) / PASSO_D[0]))
            resto = 0
        nh = int(round(resto / PASSO_H))
        antes = nh // 2
        for _ in range(antes):
            x += sx * PASSO_H
            peca_h(x - sx * PASSO_H / 2, y)
        for _ in range(nd):
            x += sx * PASSO_D[0]
            y += sy * PASSO_D[1]
            peca_d(x - sx * PASSO_D[0] / 2, y - sy * PASSO_D[1] / 2, sx, sy)
        for _ in range(nh - antes):
            x += sx * PASSO_H
            peca_h(x - sx * PASSO_H / 2, y)


# saídas do santuário (as trilhas do protótipo já chegam até aqui): oeste (1000,858), sul (1352,994), leste (1702,908)
trilha([(990, 858), (880, 858)])  # tronco comum a oeste
trilha([(880, 858), (560, 1140)])  # sudoeste, para a clareira do altar
trilha([(880, 858), (610, 520)])  # noroeste, para o acampamento
trilha([(1760, 930), (1900, 940)])  # tronco comum a leste
trilha([(1900, 940), (2330, 1130)])  # sudeste, para a ruína
trilha([(1900, 940), (2300, 520)])  # nordeste, para o pântano
trilha([(1330, 1010), (1380, 1080), (1330, 1170), (1380, 1250), (1330, 1340)])  # sul, em zigue-zague
trilha([(1540, 720), (1600, 640), (1540, 560), (1600, 480), (1540, 400), (1600, 330)])  # norte, em zigue-zague pela fresta entre as árvores

# ------------------------------------------------------------------ conteúdo das clareiras
cx, cy, rx, ry = CLAREIRAS["acampamento"]
obj("fogueira", cx, cy, raio=22)
for n, dx, dy in [("toco", -90, 20), ("toco", 80, 36), ("tronco", -60, -34), ("tronco", 110, -20), ("pedra", 20, 70), ("pedras", -130, -30), ("arbusto", 150, 30),
                  ("rocha", -150, 50), ("cogumelos", 60, -50), ("poste_lanterna", 130, -50)]:
    obj(n, cx + dx, cy + dy)
for _ in range(9):
    mancha(cx + rng.uniform(-rx * 0.8, rx * 0.8), cy + rng.uniform(-ry * 0.8, ry * 0.8), 2, 1, 2, 1)

cx, cy, rx, ry = CLAREIRAS["pantano"]
for p in [(-150, 20), (-60, 80), (70, 40), (150, 90), (-10, -50), (110, -40)]:
    dec("poca", cx + p[0], cy + p[1])
for i in range(12):
    obj("juncos", cx + rng.uniform(-rx * 0.8, rx * 0.8), cy + rng.uniform(-ry * 0.7, ry * 0.9), raio=10)
for n, dx, dy in [("toro", -170, -10), ("toro", 180, 60), ("lapide", -40, -70), ("lapide", 40, -80), ("cogumelos", -100, 70), ("cogumelos", 100, 20),
                  ("raizes", -190, 70), ("raizes", 200, -20), ("arvore_pantano", -230, 40), ("arvore_pantano", 235, -30), ("arvore_pantano", 40, -135),
                  ("pedra", 130, -60), ("tronco", -130, 90)]:
    obj(n, cx + dx, cy + dy)
luzes.append({"tipo": "magia_roxa", "pos": [cx - 60, cy + 10], "orbe": [0, 0]})
luzes.append({"tipo": "magia_roxa", "pos": [cx + 90, cy + 70], "orbe": [0, 0]})
for _ in range(7):
    mancha(cx + rng.uniform(-rx * 0.8, rx * 0.8), cy + rng.uniform(-ry * 0.8, ry * 0.8), 2, 3, 1, 1)

cx, cy, rx, ry = CLAREIRAS["altar"]
obj("altar", cx, cy, raio=20)
obj("cranio", cx + 58, cy + 18, raio=14)
obj("caixa_oferenda", cx - 50, cy + 44, raio=14)
for n, dx, dy in [("coluna", -140, -40), ("coluna", 130, -30), ("lapide", -90, -70), ("lapide", 90, -80), ("arvore_morta", -210, 20), ("arvore_morta", 220, 40),
                  ("cogumelos", 40, 80), ("raizes", -180, 70), ("pedras", 120, 70), ("muro", 10, -100), ("tronco", -120, 90)]:
    obj(n, cx + dx, cy + dy)
luzes.append({"tipo": "magia_azul", "pos": [cx + 20, cy - 60], "orbe": [0, 0]})
for _ in range(8):
    mancha(cx + rng.uniform(-rx * 0.8, rx * 0.8), cy + rng.uniform(-ry * 0.8, ry * 0.8), 3, 1, 2, 2)

cx, cy, rx, ry = CLAREIRAS["ruina"]
obj("torii_quebrado", cx, cy - 20, raio=24)
for n, dx, dy in [("muro", -150, 30), ("muro", 150, 20), ("muro", -90, 90), ("coluna", -60, -60), ("coluna", 100, -70), ("coluna", 70, 70), ("pilar", -190, -20),
                  ("pilar", 200, 60), ("obelisco", 0, 100), ("runa", -30, 40), ("runa", 40, 30), ("lapide", 160, -60), ("lapide", -140, -70), ("lapide", -20, -110),
                  ("lapide", 210, -20), ("pedestal", 60, 110), ("fogueira", -110, 110)]:
    obj(n, cx + dx, cy + dy)
luzes.append({"tipo": "magia_roxa", "pos": [cx - 20, cy + 50], "orbe": [0, 0]})
for _ in range(8):
    mancha(cx + rng.uniform(-rx * 0.8, rx * 0.8), cy + rng.uniform(-ry * 0.8, ry * 0.8), 3, 2, 3, 1)

cx, cy, rx, ry = CLAREIRAS["cemiterio"]
for i in range(8):
    obj("lapide", cx - 175 + i * 50 + rng.uniform(-6, 6), cy - 20 + (i % 2) * 38 + rng.uniform(-4, 4))
for n, dx, dy in [("runa", -60, 50), ("runa", 70, 55), ("pedestal", 0, 20), ("cranio", 120, 70), ("obelisco", 0, -60), ("pilar", -200, 40), ("pilar", 210, 30),
                  ("arvore_morta", -240, -10), ("arvore_morta", 245, -20)]:
    obj(n, cx + dx, cy + dy)
luzes.append({"tipo": "magia_azul_fixa", "pos": [cx + 20, cy + 20], "orbe": [0, 0]})
for _ in range(6):
    mancha(cx + rng.uniform(-rx * 0.8, rx * 0.8), cy + rng.uniform(-ry * 0.8, ry * 0.8), 2, 3, 2, 1)

cx, cy, rx, ry = CLAREIRAS["pedras"]
for n, dx, dy in [("rocha", -170, 10), ("rocha", 140, 20), ("rocha", 20, -50), ("pedra", -80, 40), ("pedra", 100, 60), ("pedras", -30, 70), ("pedras", 60, 10),
                  ("pedras", -120, -40), ("toco", 190, -20), ("tronco", -210, 60), ("poste_lanterna", -50, -50), ("poste_lanterna", 90, -60), ("arbusto", -220, -20),
                  ("arbusto", 220, 50), ("cogumelos", 10, 90)]:
    obj(n, cx + dx, cy + dy)
for _ in range(6):
    mancha(cx + rng.uniform(-rx * 0.8, rx * 0.8), cy + rng.uniform(-ry * 0.8, ry * 0.8), 2, 2, 4, 1)

# lanternas de pedra ao longo das trilhas
for p in [(1020, 880), (700, 720), (760, 1010), (2000, 960), (2190, 760), (2150, 1090), (1330, 1190), (1590, 600)]:
    obj("toro" if rng.random() < 0.5 else "poste_lanterna", *p, raio=16)


# ------------------------------------------------------------------ floresta
def dist_trilha(x, y):
    m = 1e9
    for t in trilhas:
        for (x0, y0), (x1, y1) in zip(t, t[1:]):
            vx, vy = x1 - x0, y1 - y0
            s = max(0.0, min(1.0, ((x - x0) * vx + (y - y0) * vy) / (vx * vx + vy * vy or 1)))
            m = min(m, math.hypot(x - (x0 + s * vx), y - (y0 + s * vy)))
    return m


def proibido(x, y, folga=0):
    # trilhas (as do protótipo também: retângulos em volta das saídas), clareiras (elipse) e o enquadramento do santuário
    if SANTUARIO[0] - folga <= x <= SANTUARIO[2] + folga and SANTUARIO[1] - folga <= y <= SANTUARIO[3] + folga:
        return True
    for cx_, cy_, rx_, ry_ in CLAREIRAS.values():
        if ((x - cx_) / (rx_ + 60 + folga)) ** 2 + ((y - cy_) / (ry_ + 50 + folga)) ** 2 < 1:
            return True
    return dist_trilha(x, y) < 75 + folga


ARV = ["arvore", "arvore_pantano", "arvore_morta"]


def tipo_arvore(x, y):
    # leste (pântano) com árvores de pântano, sul/sudeste mortas, resto misto
    pesos = [3.0, 1.2, 1.2]
    if x > 2000 and y < 900:
        pesos = [1.2, 3.0, 1.0]
    elif y > 1200 and x > 1800:
        pesos = [1.5, 1.0, 3.0]
    elif x < 800 and y > 1000:
        pesos = [1.5, 1.0, 2.5]
    return rng.choices(ARV, pesos)[0]


# bordas: 3 fileiras de árvores em todo o contorno (os pés dentro do mapa; a copa sai pela borda)
passo = 78
for fil, prof in enumerate([22, 92, 160]):
    for lado in ("N", "S", "L", "O"):
        comp = W if lado in ("N", "S") else H
        n = int(comp / passo)
        for i in range(n + 1):
            u = i * comp / n + rng.uniform(-22, 22) + (passo / 2 if fil % 2 else 0)
            u = min(max(u, 10), comp - 10)
            prof_j = prof + rng.uniform(-10, 14)
            x, y = {"N": (u, prof_j + 60), "S": (u, H - prof_j + 2), "L": (W - prof_j, u), "O": (prof_j, u)}[lado]
            if not (0 < x < W and 0 < y < H) or proibido(x, y):
                continue
            if lado == "N":  # a fileira de cima precisa de pé suficiente para a copa (150 px) caber
                y = max(y, 70 + prof * 0.3)
            if livre(x, y, 22):
                nome = tipo_arvore(x, y)
                obj(nome, x, y)
                if nome != "arvore_morta" and rng.random() < 0.35:
                    dec(rng.choice(["raiz_no", "raiz_estrela", "raiz_forquilha", "raiz_longa"]), x, y + 6)

# miolo: floresta mais rala, mais densa perto das bordas; arbustos e pedras no meio
tent = 0
while tent < 9000:
    tent += 1
    x, y = rng.uniform(40, W - 40), rng.uniform(80, H - 30)
    if proibido(x, y, 10):
        continue
    borda = min(x, W - x, y, H - y)
    p = 0.95 if borda < 330 else (0.55 if borda < 520 else 0.22)
    if rng.random() > p * 0.25:
        continue
    r = rng.random()
    if r < 0.42:
        nome, raio = tipo_arvore(x, y), 40
    elif r < 0.62:
        nome, raio = "arbusto", 20
    elif r < 0.70:
        nome, raio = rng.choice(["toco", "tronco"]), 18
    elif r < 0.78:
        nome, raio = rng.choice(["pedra", "rocha", "pedras"]), 16
    elif r < 0.88:
        nome, raio = rng.choice(["juncos", "cogumelos", "raizes"]), 12
    else:
        nome, raio = "arvore_morta", 36
    if livre(x, y, raio):
        obj(nome, x, y, raio=raio)
        if nome.startswith("arvore") and rng.random() < 0.3:
            dec(rng.choice(["raiz_no", "raiz_estrela", "raiz_forquilha", "raiz_longa"]), x, y + 6)
for _ in range(120):
    x, y = rng.uniform(60, W - 60), rng.uniform(80, H - 40)
    if not (SANTUARIO[0] < x < SANTUARIO[2] and SANTUARIO[1] < y < SANTUARIO[3]):
        mancha(x, y, 2, 2, 3, 1)
for _ in range(8):  # poças soltas na região úmida do leste
    x, y = rng.uniform(2000, 2800), rng.uniform(150, 900)
    if not proibido(x, y, -40):
        dec("poca", x, y)

# ------------------------------------------------------------------ saída
AJUDA = (
    "A floresta da v2 (2880x1620 = 3x3 telas, y para baixo), lida por v2/cenario.gd. Foi montada por fonte_arte/gerar_v2_floresta.py (semente fixa) como ponto de partida; "
    "depois disso o JSON é a fonte: edite aqui. \"mapa\": tam (px), chao (piso de prototipos/piso: ganho, verde, dessat), ambiente (cor do CanvasModulate), "
    "luar (e = energia, h = altura, ang = graus), borda_andavel (px da beira do mapa que o herói e os monstros não pisam: as árvores das bordas fecham o mapa), ganho_objetos e ganho_decalques (levantam a arte escura antes da luz). \"nascimento\": heroi = onde o herói "
    "começa; monstros = zonas {centro, raio (onde nascem), n (quantos), vaga (raio em que passeiam)}. \"luz_tipos\": cor (rgb 0 a 1), e (energia), r (raio em px), "
    "h (altura da luz, vale para a sombra), tremor (oscilação relativa), orbe (tamanho do brilho aditivo, 0 = sem), orbita ([rx, ry], gira em volta do ponto), "
    "faiscas (partículas subindo). \"luz_objetos\": o objeto com este nome ganha uma luz do tipo dado: luz = deslocamento do pé ao ponto no chão que ela "
    "ilumina; orbe = deslocamento do brilho (ou \"fogo\" = o ponto de fogo do item no cenario.json); fogo = escala do fogo em partículas. \"luzes\": luzes "
    "soltas {tipo, pos, orbe (desloc. do brilho), fogo}. \"objetos\": [nome do prototipos/objetos/cenario.json, x, y do pé]. \"decalques\": [nome do "
    "prototipos/decalques/decalques.json, x, y do centro, 1 = espelhado na horizontal (opcional)]. Fora da tela, luz, objeto e decalque não gastam nada."
)
LUZ_TIPOS = {
    "tocha": {"cor": [1.0, 0.62, 0.26], "e": 1.9, "r": 290, "h": 45, "tremor": 0.07},
    "aura": {"cor": [0.45, 0.72, 1.0], "e": 0.7, "r": 120, "h": 60},
    "lanterna": {"cor": [1.0, 0.72, 0.3], "e": 1.3, "r": 125, "h": 40, "tremor": 0.06, "orbe": 0.2},
    "lanterna_toro": {"cor": [1.0, 0.7, 0.28], "e": 1.2, "r": 125, "h": 35, "tremor": 0.06, "orbe": 0.2},
    "vela": {"cor": [1.0, 0.68, 0.32], "e": 1.1, "r": 105, "h": 35, "tremor": 0.06, "orbe": 0.2},
    "braseiro": {"cor": [1.0, 0.55, 0.2], "e": 2.5, "r": 250, "h": 45, "tremor": 0.1, "orbe": 0.2},
    "fogueira": {"cor": [1.0, 0.58, 0.22], "e": 1.4, "r": 170, "h": 32, "tremor": 0.1, "orbe": 0.2},
    "magia_roxa": {"cor": [0.7, 0.12, 1.0], "e": 2.65, "r": 230, "h": 60, "orbe": 0.55, "faiscas": True},
    "magia_azul": {"cor": [0.25, 0.65, 1.0], "e": 2.3, "r": 170, "h": 60, "orbe": 0.55, "faiscas": True, "orbita": [60, 30]},
    "magia_azul_fixa": {"cor": [0.25, 0.65, 1.0], "e": 2.3, "r": 170, "h": 60, "orbe": 0.55, "faiscas": True},
}
LUZ_OBJETOS = {
    "poste_lanterna": {"tipo": "lanterna", "luz": [23, 2], "orbe": [23, -40]},
    "toro": {"tipo": "lanterna_toro", "luz": [0, -4], "orbe": [0, -30]},
    "altar": {"tipo": "vela", "luz": [15, -4], "orbe": [15, -27]},
    "braseiro": {"tipo": "braseiro", "luz": [0, -6], "orbe": "fogo", "fogo": 1.0},
    "fogueira": {"tipo": "fogueira", "luz": [0, -6], "orbe": "fogo", "fogo": 0.7},
}
MONSTROS = [
    {"centro": [520, 440], "raio": 150, "n": 3, "vaga": 100},
    {"centro": [2380, 440], "raio": 160, "n": 3, "vaga": 100},
    {"centro": [520, 1240], "raio": 150, "n": 3, "vaga": 100},
    {"centro": [2370, 1240], "raio": 160, "n": 3, "vaga": 100},
    {"centro": [1450, 280], "raio": 150, "n": 2, "vaga": 90},
    {"centro": [1440, 1410], "raio": 150, "n": 2, "vaga": 90},
    {"centro": [780, 860], "raio": 70, "n": 2, "vaga": 80},
    {"centro": [2050, 940], "raio": 70, "n": 2, "vaga": 80},
]


def num(v):
    return json.dumps(v, ensure_ascii=False)


def escreve():
    linhas = ["{", '\t"_ajuda": ' + json.dumps(AJUDA, ensure_ascii=False) + ","]
    linhas.append('\t"semente": 11,')
    linhas.append('\t"mapa": ' + json.dumps({
        "tam": [W, H], "chao": {"piso": "piso", "ganho": 3.6, "verde": 0.8, "dessat": 0.3}, "ambiente": "172a30",
        "luar": {"e": 0.32, "h": 0.2, "ang": 90}, "ganho_objetos": 1.7, "ganho_decalques": 1.4, "borda_andavel": 150}, ensure_ascii=False) + ",")
    linhas.append('\t"nascimento": ' + json.dumps({"heroi": [CIRC[0] - 10, CIRC[1] - 22], "monstros": MONSTROS}, ensure_ascii=False) + ",")
    linhas.append('\t"luz_tipos": {\n' + ",\n".join("\t\t%s: %s" % (json.dumps(k), json.dumps(v)) for k, v in LUZ_TIPOS.items()) + "\n\t},")
    linhas.append('\t"luz_objetos": {\n' + ",\n".join("\t\t%s: %s" % (json.dumps(k), json.dumps(v)) for k, v in LUZ_OBJETOS.items()) + "\n\t},")
    linhas.append('\t"luzes": [\n' + ",\n".join("\t\t" + json.dumps(v) for v in luzes) + "\n\t],")
    linhas.append('\t"objetos": [\n' + ",\n".join("\t\t" + json.dumps(v, ensure_ascii=False) for v in objetos) + "\n\t],")
    linhas.append('\t"decalques": [\n' + ",\n".join("\t\t" + json.dumps(v, ensure_ascii=False) for v in decalques) + "\n\t]")
    linhas.append("}")
    SAIDA.write_text("\n".join(linhas) + "\n", encoding="utf-8")
    print("objetos", len(objetos), "decalques", len(decalques), "luzes", len(luzes), "->", SAIDA)


def previa(caminho):
    from PIL import Image, ImageEnhance
    cen = json.loads((PROJ / "prototipos/objetos/cenario.json").read_text())
    atlas = Image.open(PROJ / "prototipos/objetos/enfeites.png").convert("RGBA")
    dj = json.loads((PROJ / "prototipos/decalques/decalques.json").read_text())
    datl = Image.open(PROJ / "prototipos/decalques/decalques.png").convert("RGBA")
    piso = Image.open(PROJ / "prototipos/piso/piso.png").convert("RGBA")
    tela = Image.new("RGBA", (W, H))
    for y in range(0, H, piso.height):
        for x in range(0, W, piso.width):
            tela.paste(piso, (x, y))
    tela = ImageEnhance.Brightness(tela.convert("RGB")).enhance(1.6).convert("RGBA")
    ditens = {i["nome"]: i for i in dj["itens"]}
    for n, x, y, *r in decalques:
        i = ditens[n]
        rg = i["regiao"]
        im = datl.crop((rg[0], rg[1], rg[0] + rg[2], rg[1] + rg[3]))
        if r:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        tela.paste(im, (int(x - i["centro"][0]), int(y - i["centro"][1])), im)
    oitens = {i["nome"]: i for i in cen["itens"]}
    for n, x, y in sorted(objetos, key=lambda o: o[2]):
        i = oitens[n]
        rg = i["regiao"]
        im = atlas.crop((rg[0], rg[1], rg[0] + rg[2], rg[1] + rg[3]))
        px, py = int(x - i["pe"][0]), int(y - i["pe"][1])
        tela.paste(im, (px, py), im)
    from PIL import ImageDraw
    dr = ImageDraw.Draw(tela)
    for l in luzes:
        dr.ellipse((l["pos"][0] - 8, l["pos"][1] - 8, l["pos"][0] + 8, l["pos"][1] + 8), outline=(255, 0, 255), width=3)
    for z in MONSTROS:
        dr.ellipse((z["centro"][0] - 6, z["centro"][1] - 6, z["centro"][0] + 6, z["centro"][1] + 6), fill=(255, 40, 40))
    for k in range(1, 3):
        dr.line((k * 960, 0, k * 960, H), fill=(255, 255, 0), width=1)
        dr.line((0, k * 540, W, k * 540), fill=(255, 255, 0), width=1)
    tela.convert("RGB").resize((W // 2, H // 2), Image.LANCZOS).save(caminho)
    print("prévia ->", caminho)


if __name__ == "__main__":
    escreve()
    if "--previa" in sys.argv:
        previa(sys.argv[sys.argv.index("--previa") + 1])

"""Laboratório da v2: o que cada objeto é para o jogo (colisão), os decalques de chão e o desenho do mapa (2880x1620 = 3x3 telas).

Os objetos e o piso vêm do Blender (modelos3d/mapa_laboratorio.py); este arquivo diz como entram no jogo e onde ficam. Lido por
fonte_arte/gerar_v2_mapas.py. Composição (coordenadas do mundo, y para baixo): a sala de contenção no centro, onde o herói nasce (selo no
chão, quatro tanques em volta), e oito áreas ao redor (servidores, triagem, espécimes, depósito, criogenia, geradores, operações,
ruínas), ligadas por corredores de piso aberto. As bordas fecham o mapa com a parede dos fundos e fileiras de equipamento alto.
"""
import math

import kit_decalques as kd
from kit_decalques import cor

SEMENTE = 31
W, H = 2880, 1620
AJUDA = (
    "O laboratório da v2 (2880x1620 = 3x3 telas, y para baixo), lido por v2/cenario.gd como a floresta (mesmo formato; veja v2_floresta.json), com "
    "\"mapa.pastas\" apontando para a arte (assets/v2/mapas/laboratorio), \"minimapa\" (cores do minimapa por objeto e decalque) e \"atmosfera\" (partículas "
    "do ambiente). Foi montado por fonte_arte/gerar_v2_mapas.py (semente fixa) a partir dos objetos do Blender; depois disso o JSON é a fonte: edite aqui."
)

# nome: col = como colide (passavel | disco | larga | parede (ry) | pegada | disco_fino (r)); fogo = ponto da chama (fração do sprite)
OBJETOS = {
    "parede_lab_a": {"col": "caixa", "w": 3.0, "d": 0.5, "folga": 1.0},
    "parede_lab_b": {"col": "caixa", "w": 3.0, "d": 0.5, "folga": 1.0},
    "parede_lab_c": {"col": "caixa", "w": 3.0, "d": 0.5, "folga": 1.0},
    "pilar_lab": {"col": "caixa", "w": 0.8, "d": 0.8},
    "rack_servidores": {"col": "caixa", "w": 0.9, "d": 0.8},
    "armario_aco": {"col": "caixa", "w": 1.0, "d": 0.6},
    "tanque_alto": {"col": "caixa", "w": 1.5, "d": 1.5},
    "tanque_quebrado": {"col": "caixa", "w": 1.5, "d": 1.5},
    "capsula_cripto": {"col": "caixa", "w": 1.0, "d": 2.0},
    "gerador": {"col": "caixa", "w": 2.0, "d": 1.4},
    "cano_grosso": {"col": "caixa", "w": 0.7, "d": 0.7},
    "mesa_lab": {"col": "caixa", "w": 1.6, "d": 0.8},
    "bancada_lab": {"col": "caixa", "w": 3.0, "d": 0.9},
    "console": {"col": "caixa", "w": 1.2, "d": 0.75},
    "console_quebrado": {"col": "caixa", "w": 1.2, "d": 0.75},
    "caixa_suprimentos": {"col": "caixa", "w": 1.0, "d": 1.0},
    "caixa_empilhada": {"col": "caixa", "w": 1.1, "d": 1.1},
    "barril_toxico": {"col": "caixa", "w": 0.7, "d": 0.7},
    "maca": {"col": "caixa", "w": 0.8, "d": 1.9},
    "gaiola": {"col": "caixa", "w": 1.3, "d": 1.0},
    "lampada_emergencia": {"col": "caixa", "w": 0.36, "d": 0.36},
    "cacos_vidro": {"col": "passavel", "d": 0.7},
    "lixo_lab": {"col": "passavel", "d": 0.8},
    "restos_cobaia": {"col": "passavel", "d": 1.1},
    "porta_blindada": {"col": "caixa", "w": 3.0, "d": 0.5, "folga": 1.0},
    "duto_ventilacao": {"col": "caixa", "w": 1.1, "d": 0.8},
    "estante_amostras": {"col": "caixa", "w": 1.7, "d": 0.55},
}
LARGOS = {"gerador", "capsula_cripto", "bancada_lab", "estante_amostras", "porta_blindada"}  # o passo ao longo da borda deixa de ser curto demais para eles

# temas das bordas: o que cada trecho tem na fileira alta (atrás) e na baixa (na frente) e a luz que o ilumina
TEMAS = {
    "servidores": {"alto": ["rack_servidores", "rack_servidores", "rack_servidores", "armario_aco", "duto_ventilacao"],
                   "baixo": ["console", "mesa_lab", "console", "caixa_suprimentos", "mesa_lab"], "luz": "borda_ciano"},
    "deposito": {"alto": ["caixa_empilhada", "caixa_empilhada", "armario_aco", "estante_amostras", "caixa_empilhada"],
                 "baixo": ["caixa_suprimentos", "caixa_suprimentos", "barril_toxico", "mesa_lab", "caixa_suprimentos"], "luz": "borda_ambar"},
    "biologia": {"alto": ["tanque_alto", "estante_amostras", "tanque_alto", "estante_amostras", "tanque_quebrado"],
                 "baixo": ["bancada_lab", "gaiola", "maca", "barril_toxico", "gaiola"], "luz": "borda_verde"},
    "energia": {"alto": ["cano_grosso", "duto_ventilacao", "gerador", "cano_grosso", "pilar_lab", "duto_ventilacao"],
                "baixo": ["barril_toxico", "caixa_suprimentos", "barril_toxico", "console", "mesa_lab"], "luz": "borda_ambar"},
    "ruinas": {"alto": ["tanque_quebrado", "rack_servidores", "caixa_empilhada", "tanque_quebrado", "armario_aco"],
               "baixo": ["console_quebrado", "maca", "gaiola", "console_quebrado", "caixa_suprimentos"], "luz": "borda_vermelha"},
    "criogenia": {"alto": ["pilar_lab", "tanque_alto", "armario_aco", "estante_amostras", "pilar_lab"],
                  "baixo": ["capsula_cripto", "bancada_lab", "console", "capsula_cripto", "mesa_lab"], "luz": "borda_ciano"},
}


# ------------------------------------------------------------------ piso: desgaste por cima do azulejo do Blender (já achatado)
def detalhar_piso(img):
    """O azulejo do Blender sai limpo e regular demais ao lado da floresta (que tem pedra, musgo e terra em cada pixel). Aqui entram: brilho
    próprio de cada placa, quina clara em cima e à esquerda e escura embaixo e à direita, sujeira nos cantos, grão, riscos, ferrugem e
    manchas de água. Tudo dá a volta nas bordas (o azulejo repete) e usa semente fixa."""
    import numpy as np
    from PIL import Image

    r = np.random.RandomState(SEMENTE + 2)
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    h, w, _ = a.shape
    n = 16
    th = h / float(n)
    yy, xx = np.mgrid[0:h, 0:w]
    ti, tj = np.minimum(xx // 32, n - 1), np.minimum((yy / th).astype(int), n - 1)
    tx, ty = (xx % 32).astype(np.float32), (yy % th).astype(np.float32)
    # 0. as manchas redondas do Blender (cilindros pretos) viram sujeira picotada: metade dos pixels delas clareia
    lum = a.mean(axis=2)
    interior = (tx >= 3) & (tx < 29) & (ty >= 2.2) & (ty < 19.4)
    pinta_mancha = interior & (lum < 27)
    clareia = pinta_mancha & (r.rand(h, w) < 0.55)
    a[clareia] *= 1.7
    # 1. cada placa com o seu brilho e um leve degradê (uma metade mais clara, como chapa que pegou luz do teto)
    base = 0.82 + 0.34 * r.rand(n, n)
    fator = base[tj, ti]
    inclina = (r.rand(n, n) - 0.5)[tj, ti] * 0.18
    fator = fator * (1.0 + inclina * (tx / 32.0 - 0.5) * 2.0)
    a *= fator[..., None]
    # 2. quinas: claro em cima e à esquerda, escuro embaixo e à direita
    luz = ((tx >= 1) & (tx < 3)) | ((ty >= 0.7) & (ty < 1.8))
    sombra = ((tx >= 28) & (tx < 31)) | ((ty >= 19.6) & (ty < 21.9))
    a[luz] *= 1.28
    a[sombra] *= 0.72
    # 3. cantos sujos: o canto de baixo de cada placa escurece e uns cantos ganham ferrugem
    canto = np.clip((tx - 18) / 14.0, 0, 1) * np.clip((ty - 11) / 11.0, 0, 1)
    a *= (1.0 - 0.28 * canto)[..., None]
    # 4. grão: pixels soltos mais claros e mais escuros
    g = r.rand(h, w)
    a[g < 0.06] *= 1.22
    a[(g > 0.06) & (g < 0.14)] *= 0.8
    # 5. riscos claros curtos e arranhões diagonais
    for _ in range(150):
        x0, y0 = r.randint(0, w), r.randint(0, h)
        comp = r.randint(5, 16)
        dx, dy = (1, 0) if r.rand() < 0.45 else ((1, 1) if r.rand() < 0.5 else (1, -1))
        for k in range(comp):
            px, py = (x0 + dx * k) % w, (y0 + dy * k) % h
            a[py, px] += np.array([22, 26, 30], np.float32)
    # 6. ferrugem e água: manchas de pixels (blobs irregulares com borda picotada)
    def blob(cx, cy, rx, ry, cor, forca):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d < 1.0 and r.rand() < (1.0 - d) * 1.4:
                    p = (y % h, x % w)
                    a[p] = a[p] * (1 - forca) + np.array(cor, np.float32) * forca
    for _ in range(46):
        blob(r.randint(0, w), r.randint(0, h), r.uniform(3, 10), r.uniform(2, 5), (118, 70, 40), r.uniform(0.35, 0.6))
    for _ in range(22):
        blob(r.randint(0, w), r.randint(0, h), r.uniform(8, 20), r.uniform(4, 9), (20, 30, 40), r.uniform(0.25, 0.4))
    for _ in range(16):
        blob(r.randint(0, w), r.randint(0, h), r.uniform(4, 9), r.uniform(2, 5), (40, 108, 120), r.uniform(0.18, 0.3))
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


# ------------------------------------------------------------------ decalques (já achatados por sen 45)
def _poca_acido(w, h):
    return lambda rng: kd.poca(w, h, rng, cor("33b560"), cor("b8ffcb"), cor("1b5e36"))


def _poca_oleo(w, h):
    return lambda rng: kd.poca(w, h, rng, cor("13161a"), cor("6b7c8c"), cor("2a3036"))


def _mancha(w, h, c="0c0e11", alfa=190):
    return lambda rng: kd.mancha(w, h, rng, cor(c), alfa=alfa)


DECALQUES = {
    "selo_central": lambda rng: kd.anel(300, 4, cor("d6ac26"), 24, cor("98791a")),
    "selo_pequeno": lambda rng: kd.anel(120, 3, cor("d6ac26"), 12, cor("98791a")),
    "faixa_perigo_g": lambda rng: kd.faixa_diagonal(176, 20, cor("d6ac26"), cor("15171b"), 6, rng),
    "faixa_perigo_p": lambda rng: kd.faixa_diagonal(88, 20, cor("d6ac26"), cor("15171b"), 6, rng),
    "seta_chao": lambda rng: kd.seta(88, 44, cor("c9cdd1"), rng),
    "poca_acido_g": _poca_acido(110, 76),
    "poca_acido_p": _poca_acido(64, 44),
    "poca_oleo_g": _poca_oleo(100, 70),
    "poca_oleo_p": _poca_oleo(58, 40),
    "mancha_a": _mancha(96, 66),
    "mancha_b": _mancha(70, 48),
    "mancha_c": _mancha(120, 80, alfa=150),
    "mancha_sangue": _mancha(76, 52, "4a1515", 200),
    "rachadura_a": lambda rng: kd.rachadura(130, 40, rng, cor("0b0c0e")),
    "rachadura_b": lambda rng: kd.rachadura(100, 36, rng, cor("0b0c0e")),
    "rachadura_c": lambda rng: kd.rachadura(150, 44, rng, cor("0b0c0e"), ramos=3),
    "cabo_a": lambda rng: kd.cabo(140, 34, rng, cor("1b1d22"), cor("8c2a24")),
    "cabo_b": lambda rng: kd.cabo(110, 30, rng, cor("1b1d22"), cor("8a8f96")),
    "cabo_c": lambda rng: kd.cabo(170, 36, rng, cor("2a2218"), cor("c8a020")),
    "grade_dreno": lambda rng: kd.grade(72, 44, cor("39424c"), cor("0a0c0e"), rng),
    "placa_chao": lambda rng: kd.retangulo(76, 52, cor("39424d"), cor("20262c"), rng, 0.04),
    "papeis_a": lambda rng: kd.papeis(60, 40, rng),
    "papeis_b": lambda rng: kd.papeis(48, 34, rng),
}


# ------------------------------------------------------------------ luzes
LUZ_TIPOS = {
    "tocha": {"cor": [1.0, 0.62, 0.26], "e": 1.9, "r": 290, "h": 45, "tremor": 0.07},
    "aura": {"cor": [0.45, 0.72, 1.0], "e": 0.7, "r": 120, "h": 60},
    "tanque_verde": {"cor": [0.3, 1.0, 0.45], "e": 1.7, "r": 190, "h": 55, "tremor": 0.05, "orbe": 0.4},
    "tanque_fraco": {"cor": [0.3, 0.9, 0.5], "e": 0.8, "r": 120, "h": 40, "tremor": 0.2, "orbe": 0.15},
    "tela_ciano": {"cor": [0.3, 0.85, 1.0], "e": 1.2, "r": 130, "h": 30, "tremor": 0.03, "orbe": 0.15},
    "emergencia": {"cor": [1.0, 0.16, 0.1], "e": 1.8, "r": 220, "h": 60, "tremor": 0.28, "orbe": 0.4},
    "cripto_azul": {"cor": [0.35, 0.82, 1.0], "e": 1.5, "r": 150, "h": 30, "tremor": 0.04, "orbe": 0.25},
    "toxico": {"cor": [0.4, 1.0, 0.4], "e": 0.8, "r": 95, "h": 20, "tremor": 0.1, "orbe": 0.0},
    "gerador": {"cor": [1.0, 0.6, 0.25], "e": 1.4, "r": 160, "h": 40, "tremor": 0.12, "orbe": 0.25},
    "fio_solto": {"cor": [0.8, 0.92, 1.0], "e": 1.8, "r": 130, "h": 45, "tremor": 0.4, "orbe": 0.3, "faiscas": True},
    # luzes das bordas (sem orbe): altas e largas, para pegar a frente do equipamento alto que a câmera vê de frente
    "borda_ciano": {"cor": [0.3, 0.8, 1.0], "e": 1.1, "r": 250, "h": 70, "tremor": 0.03, "orbe": 0.0},
    "borda_verde": {"cor": [0.3, 1.0, 0.5], "e": 1.0, "r": 240, "h": 70, "tremor": 0.06, "orbe": 0.0},
    "borda_ambar": {"cor": [1.0, 0.62, 0.26], "e": 1.0, "r": 240, "h": 70, "tremor": 0.1, "orbe": 0.0},
    "borda_vermelha": {"cor": [1.0, 0.2, 0.12], "e": 1.0, "r": 230, "h": 70, "tremor": 0.25, "orbe": 0.0},
}
LUZ_OBJETOS = {
    "tanque_alto": {"tipo": "tanque_verde", "luz": [0, -8], "orbe": [0, -58]},
    "tanque_quebrado": {"tipo": "tanque_fraco", "luz": [0, -8], "orbe": [0, -40]},
    "console": {"tipo": "tela_ciano", "luz": [0, 4], "orbe": [0, -42]},
    "console_quebrado": {"tipo": "fio_solto", "luz": [0, 4], "orbe": [0, -44]},
    "lampada_emergencia": {"tipo": "emergencia", "luz": [0, 6], "orbe": [0, -56]},
    "capsula_cripto": {"tipo": "cripto_azul", "luz": [0, 8], "orbe": [0, -22]},
    "barril_toxico": {"tipo": "toxico", "luz": [0, 2], "orbe": [0, -8]},
    "gerador": {"tipo": "gerador", "luz": [0, 6], "orbe": [18, -40]},
}
MINIMAPA = {
    "chao": "222b34",
    "fechado": "0d1217",
    "objetos": {
        "parede_lab_a": ["56626f", 2], "parede_lab_b": ["56626f", 2], "parede_lab_c": ["56626f", 2], "pilar_lab": ["56626f", 2],
        "rack_servidores": ["7a8896", 1], "armario_aco": ["7a8896", 1], "tanque_alto": ["44d870", 2], "tanque_quebrado": ["2f9a50", 2],
        "capsula_cripto": ["5adcf2", 2], "gerador": ["d6ac26", 2], "cano_grosso": ["8c6a4a", 1], "mesa_lab": ["8a98a6", 1],
        "bancada_lab": ["8a98a6", 2], "console": ["5adcf2", 1], "console_quebrado": ["8aa0b0", 1], "caixa_suprimentos": ["8a7a5a", 1],
        "caixa_empilhada": ["8a7a5a", 1], "barril_toxico": ["5bd06a", 1], "maca": ["b9bdc2", 1], "gaiola": ["7a8896", 1],
        "lampada_emergencia": ["ec3b2e", 1], "porta_blindada": ["56626f", 2], "duto_ventilacao": ["7a8896", 1], "estante_amostras": ["7a8896", 1],
    },
    "decalques": {"selo_central": ["ddcc80", 5, "anel"], "poca_acido_g": ["3fcf6a", 2], "faixa_perigo_g": ["d6ac26", 1]},
    "luzes_fortes": ["gerador"],
}
ATMOSFERA = {
    "vaga": {"n": 26, "cor": [0.55, 0.95, 1.0], "tam": 0.8, "vel": 0.6},
    "folhas": {"n": 14, "cor": [0.75, 0.8, 0.85, 0.55], "tam": 0.7, "vel": 0.45},
}


# ------------------------------------------------------------------ o mapa
def montar(tam, rng):
    objetos, decalques, luzes, ocupados = [], [], [], []

    def raio(nome):
        w, h, pe = tam[nome]
        return max(10.0, w * 0.42)

    def obj(nome, x, y, ocupa=True, r=None):
        objetos.append([nome, int(round(x)), int(round(y))])
        if ocupa:
            ocupados.append((x, y, r if r is not None else raio(nome)))

    def dec(nome, x, y, espelha=False):
        decalques.append([nome, int(round(x)), int(round(y))] + ([1] if espelha else []))

    def livre(x, y, r):
        return all((x - ox) ** 2 + (y - oy) ** 2 >= (r + orr) ** 2 for ox, oy, orr in ocupados)

    def grupo(nomes, cx, cy, n, rx, ry):
        for _ in range(n):
            a, r = rng.random() * math.tau, math.sqrt(rng.random())
            dec(rng.choice(nomes), cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r, rng.random() < 0.5)

    CX, CY = 1440, 830
    # ---------------------------------------------------------------- sala de contenção (o herói nasce no selo)
    dec("selo_central", CX, CY)
    dec("selo_pequeno", CX, CY)
    for n, dx, dy in [("tanque_alto", -230, -120), ("tanque_alto", 230, -120), ("tanque_quebrado", -230, 150), ("tanque_alto", 230, 150)]:
        obj(n, CX + dx, CY + dy, r=30)
    for n, dx, dy in [("console", 0, -190), ("console", -120, 215), ("console", 120, 215), ("lampada_emergencia", -330, 20), ("lampada_emergencia", 330, 20),
                      ("lampada_emergencia", 0, 270)]:
        obj(n, CX + dx, CY + dy)
    for n, dx, dy in [("cabo_a", -110, -150), ("cabo_b", 150, -170), ("cabo_c", -170, 190), ("cabo_a", 190, 200), ("poca_acido_g", -240, 215), ("poca_acido_p", 250, 215),
                      ("seta_chao", -400, 230), ("seta_chao", 410, -190), ("rachadura_a", 70, 120), ("rachadura_c", -90, -60), ("grade_dreno", 0, 175),
                      ("grade_dreno", 0, -105)]:
        dec(n, CX + dx, CY + dy, rng.random() < 0.5)
    for dx in (-1, 1):
        dec("faixa_perigo_g", CX + dx * 310, CY - 20)
    obj("restos_cobaia", CX - 260, CY + 165, ocupa=False)
    obj("cacos_vidro", CX - 190, CY + 210, ocupa=False)

    # ---------------------------------------------------------------- áreas ao redor
    areas = {}

    def area(nome, cx, cy, rx, ry):
        areas[nome] = (cx, cy, rx, ry)

    # NW: servidores
    cx, cy = 560, 360
    area("servidores", cx, cy, 340, 180)
    for i in range(5):
        obj("rack_servidores", cx - 180 + i * 90, cy - 70)
        obj("rack_servidores" if i % 2 == 0 else "armario_aco", cx - 180 + i * 90, cy + 90)
    for n, dx, dy in [("console", -270, 10), ("console", 270, 10), ("mesa_lab", 0, 10), ("lampada_emergencia", 230, 140), ("cano_grosso", -280, 140)]:
        obj(n, cx + dx, cy + dy)
    for n, dx, dy in [("cabo_a", -120, 5), ("cabo_c", 130, 10), ("cabo_b", 0, 150), ("grade_dreno", 60, 60), ("papeis_a", -200, 120), ("papeis_b", 190, 120)]:
        dec(n, cx + dx, cy + dy, rng.random() < 0.5)
    for n, dx, dy in [("lixo_lab", 100, 150), ("cacos_vidro", -60, 160)]:
        obj(n, cx + dx, cy + dy, ocupa=False)

    # N: triagem (duas bancadas e um muro com abertura)
    cx, cy = 1440, 320
    area("triagem", cx, cy, 330, 150)
    for k, x in enumerate([cx - 250, cx - 160, cx - 70]):
        obj("porta_blindada" if k == 1 else "parede_lab_a", x, 430)
    for k, x in enumerate([cx + 70, cx + 160, cx + 250]):
        obj("parede_lab_c" if k == 1 else "parede_lab_a", x, 430)
    for n, dx, dy in [("bancada_lab", -190, 330), ("bancada_lab", 190, 330), ("mesa_lab", -60, 260), ("mesa_lab", 80, 275), ("console", 0, 215),
                      ("caixa_suprimentos", -300, 290), ("barril_toxico", 300, 280)]:
        obj(n, cx + dx, cy + dy - 100)
    for n, dx, dy in [("faixa_perigo_p", 0, 460), ("poca_oleo_g", -200, 400), ("mancha_a", 190, 380), ("papeis_a", -30, 330), ("cabo_b", 40, 270)]:
        dec(n, cx + dx, cy + dy - 100, rng.random() < 0.5)

    # NE: espécimes
    cx, cy = 2330, 370
    area("especimes", cx, cy, 340, 190)
    for i in range(3):
        obj("tanque_alto" if i != 1 else "tanque_quebrado", cx - 170 + i * 170, cy - 60)
    for n, dx, dy in [("gaiola", -250, 110), ("gaiola", -120, 150), ("maca", 100, 130), ("maca", 220, 120), ("console_quebrado", 280, -20),
                      ("lampada_emergencia", -290, -40), ("restos_cobaia", 20, 170)]:
        obj(n, cx + dx, cy + dy, ocupa=n != "restos_cobaia")
    for n, dx, dy in [("poca_acido_g", -40, 70), ("mancha_sangue", 160, 190), ("mancha_sangue", -190, 190), ("cabo_a", 130, -10), ("rachadura_b", -100, 130)]:
        dec(n, cx + dx, cy + dy, rng.random() < 0.5)

    # W: depósito
    cx, cy = 430, 830
    area("deposito", cx, cy, 280, 200)
    for n, dx, dy in [("caixa_empilhada", -190, -120), ("caixa_empilhada", -100, -150), ("caixa_empilhada", 90, -130), ("caixa_suprimentos", -240, 0),
                      ("caixa_suprimentos", -150, 20), ("caixa_suprimentos", 150, -30), ("barril_toxico", -230, 130), ("barril_toxico", -190, 150),
                      ("barril_toxico", 190, 100), ("armario_aco", 0, -160), ("caixa_suprimentos", 10, 150), ("mesa_lab", 100, 150)]:
        obj(n, cx + dx, cy + dy)
    for n, dx, dy in [("papeis_b", -60, 60), ("mancha_b", 80, 60), ("poca_acido_p", -190, 190), ("seta_chao", 250, 30), ("rachadura_a", -120, 90)]:
        dec(n, cx + dx, cy + dy, rng.random() < 0.5)

    # E: criogenia
    cx, cy = 2440, 830
    area("cripto", cx, cy, 300, 190)
    for i in range(4):
        obj("capsula_cripto", cx - 190 + i * 125, cy - 80)
    for n, dx, dy in [("bancada_lab", -60, 120), ("console", 160, 110), ("console", -230, 120), ("lampada_emergencia", 230, -130), ("cano_grosso", 260, 40)]:
        obj(n, cx + dx, cy + dy)
    for n, dx, dy in [("cabo_c", -50, 40), ("cabo_a", 150, 60), ("grade_dreno", 60, 10), ("poca_oleo_p", -240, 40), ("papeis_a", -100, 175)]:
        dec(n, cx + dx, cy + dy, rng.random() < 0.5)

    # SW: geradores
    cx, cy = 520, 1280
    area("geradores", cx, cy, 330, 170)
    for n, dx, dy in [("gerador", -130, -20), ("gerador", 110, 30), ("cano_grosso", -280, -60), ("cano_grosso", -260, 60), ("cano_grosso", 280, -40),
                      ("barril_toxico", 20, 130), ("barril_toxico", 70, 145), ("caixa_suprimentos", -190, 120), ("lampada_emergencia", 250, 100),
                      ("armario_aco", 0, -130)]:
        obj(n, cx + dx, cy + dy)
    for n, dx, dy in [("faixa_perigo_g", -130, 55), ("faixa_perigo_g", 110, 105), ("poca_oleo_g", 200, 20), ("mancha_c", -130, -20), ("cabo_a", 0, 60),
                      ("cabo_c", -50, 160), ("rachadura_c", 30, -70)]:
        dec(n, cx + dx, cy + dy, rng.random() < 0.5)

    # S: operações
    cx, cy = 1440, 1290
    area("operacoes", cx, cy, 330, 150)
    for k, x in enumerate([cx - 250, cx - 160, cx - 70]):
        obj("parede_lab_a" if k != 2 else "parede_lab_b", x, 1190)
    for k, x in enumerate([cx + 70, cx + 160, cx + 250]):
        obj("parede_lab_a" if k == 1 else ("parede_lab_c" if k == 0 else "porta_blindada"), x, 1190)
    for n, dx, dy in [("maca", -230, 70), ("maca", -120, 80), ("mesa_lab", 40, 70), ("mesa_lab", 160, 60), ("console", 270, 80), ("lampada_emergencia", -300, -10),
                      ("lampada_emergencia", 320, -10)]:
        obj(n, cx + dx, cy + dy)
    for n, dx, dy in [("mancha_sangue", -170, 130), ("faixa_perigo_p", 0, -60), ("papeis_a", 100, 150), ("poca_oleo_g", 230, 140), ("cabo_b", -40, 20)]:
        dec(n, cx + dx, cy + dy, rng.random() < 0.5)
    obj("cacos_vidro", cx + 70, cy + 140, ocupa=False)

    # SE: ruínas do laboratório (tudo quebrado)
    cx, cy = 2350, 1290
    area("ruinas", cx, cy, 340, 170)
    for n, dx, dy in [("tanque_quebrado", -150, -20), ("tanque_quebrado", 90, 20), ("console_quebrado", 230, -30), ("console_quebrado", -260, 40),
                      ("caixa_empilhada", 10, -110), ("parede_lab_c", -200, -130), ("parede_lab_c", 120, -130), ("barril_toxico", 220, 110),
                      ("lampada_emergencia", -300, -50), ("maca", 20, 140)]:
        obj(n, cx + dx, cy + dy)
    for n, dx, dy in [("poca_acido_g", -140, 100), ("poca_acido_p", 110, 90), ("rachadura_c", 0, 40), ("rachadura_a", 190, 130), ("rachadura_b", -230, 130),
                      ("mancha_c", 20, 20), ("cabo_a", 60, -40), ("cabo_c", -130, 40)]:
        dec(n, cx + dx, cy + dy, rng.random() < 0.5)
    obj("cacos_vidro", cx - 60, cy + 90, ocupa=False)
    obj("restos_cobaia", cx + 150, cy + 150, ocupa=False)
    obj("cacos_vidro", cx + 160, cy + 20, ocupa=False)

    # ---------------------------------------------------------------- bordas: o mapa é fechado por paredes e equipamento alto
    # Cada trecho da borda (480 px no norte e no sul, 380 px no oeste e no leste) tem um TEMA, com os seus equipamentos e uma luz da cor dele:
    # a borda muda de cara ao andar e as fileiras altas (que a câmera vê de frente e ficam pretas sem luz) ganham o seu clarão.
    nomes_t = list(TEMAS)

    def sorteia_temas(n):
        t = rng.sample(nomes_t, min(n, len(nomes_t)))
        while len(t) < n:
            t.append(rng.choice(nomes_t))
        return t

    def passo(nome, a, b):
        return max(rng.uniform(a, b), tam[nome][0] * 0.62) if nome in LARGOS else rng.uniform(a, b)

    t_norte, t_sul, t_oeste, t_leste = sorteia_temas(6), sorteia_temas(6), sorteia_temas(4), sorteia_temas(4)
    # norte: parede dos fundos (pé em y=146, logo acima da faixa andável, com portas blindadas aqui e ali) e uma fileira de equipamento atrás dela
    paredes = ["parede_lab_a"] * 4 + ["parede_lab_b"] * 2 + ["parede_lab_c"] * 2 + ["porta_blindada"]
    x, anterior = 50, ""
    while x < W - 30:
        nome = rng.choice(paredes)
        if nome == "porta_blindada" and anterior == nome:
            nome = "parede_lab_a"
        obj(nome, x, 146, ocupa=False)
        anterior = nome
        x += 92
    x = 40
    while x < W:
        nome = rng.choice(TEMAS[t_norte[min(5, int(x // 480))]]["alto"])
        obj(nome, x + rng.uniform(-14, 14), 96 + rng.uniform(-10, 8), ocupa=False)
        x += passo(nome, 58, 84)
    # sul: baixo na frente da faixa andável, alto mais atrás da câmera
    x = 40
    while x < W:
        nome = rng.choice(TEMAS[t_sul[min(5, int(x // 480))]]["baixo"])
        obj(nome, x + rng.uniform(-10, 10), 1500 + rng.uniform(-6, 10), ocupa=False)
        x += passo(nome, 78, 120)
    x = 30
    while x < W:
        nome = rng.choice(TEMAS[t_sul[min(5, int(x // 480))]]["alto"])
        obj(nome, x + rng.uniform(-14, 14), 1595 + rng.uniform(-8, 14), ocupa=False)
        x += passo(nome, 56, 80)
    # oeste e leste: duas colunas de equipamento (o miolo fica livre; a câmera para na borda)
    for lado, xs, temas in (("O", (62, 118), t_oeste), ("L", (W - 62, W - 118), t_leste)):
        for k, xc in enumerate(xs):
            y = 170 + (k * 31)
            while y < 1500:
                nome = rng.choice(TEMAS[temas[min(3, int((y - 150) // 380))]]["alto" if k == 0 else "baixo"])
                obj(nome, xc + rng.uniform(-8, 8), y, ocupa=False)
                y += rng.uniform(56, 82)
    # uma luz fraca por trecho, na cor do tema (sem orbe: só clareia o equipamento e o chão da borda)
    for i in range(6):
        cx_ = 240 + i * 480
        luzes.append({"tipo": TEMAS[t_sul[i]]["luz"], "pos": [round(cx_ + rng.uniform(-60, 60)), 1525], "orbe": [0, 0]})
        luzes.append({"tipo": TEMAS[t_norte[i]]["luz"], "pos": [round(cx_ + rng.uniform(-60, 60)), 128], "orbe": [0, 0]})
    for i in range(4):
        cy_ = 340 + i * 380
        luzes.append({"tipo": TEMAS[t_oeste[i]]["luz"], "pos": [round(150 + rng.uniform(-20, 20)), cy_], "orbe": [0, 0]})
        luzes.append({"tipo": TEMAS[t_leste[i]]["luz"], "pos": [round(W - 150 + rng.uniform(-20, 20)), cy_], "orbe": [0, 0]})
    # chão da borda: cabos, ralos, faixas e poças, para a faixa de equipamento não ficar sobre piso limpo
    chao_borda = ["cabo_a", "cabo_b", "cabo_c", "grade_dreno", "faixa_perigo_p", "poca_oleo_p", "poca_acido_p", "mancha_b", "papeis_a", "placa_chao",
                  "rachadura_b", "rachadura_c", "seta_chao"]
    x = 120
    while x < W - 100:
        dec(rng.choice(chao_borda), x, rng.choice([1455, 1470]) + rng.uniform(-8, 8), rng.random() < 0.5)
        dec(rng.choice(chao_borda), x + rng.uniform(0, 60), 196 + rng.uniform(-8, 12), rng.random() < 0.5)
        x += rng.uniform(110, 190)
    y = 260
    while y < 1420:
        dec(rng.choice(chao_borda), 196 + rng.uniform(-8, 10), y, rng.random() < 0.5)
        dec(rng.choice(chao_borda), W - 196 + rng.uniform(-10, 8), y + rng.uniform(0, 40), rng.random() < 0.5)
        y += rng.uniform(120, 200)
    for x, y in [(380, 1490), (1100, 1500), (1840, 1485), (2540, 1495), (610, 190), (1960, 184), (180, 640), (2700, 1100)]:
        obj(rng.choice(["restos_cobaia", "cacos_vidro", "lixo_lab"]), x, y, ocupa=False)

    # ---------------------------------------------------------------- miolo: desordem nos corredores (decalques e entulho, sem bloquear)
    prib = [(cx_ - rx - 20, cy_ - ry - 20, cx_ + rx + 20, cy_ + ry + 20) for cx_, cy_, rx, ry in areas.values()]
    prib.append((CX - 380, CY - 250, CX + 380, CY + 330))
    manchas = ["mancha_a", "mancha_b", "mancha_c", "poca_oleo_p", "papeis_a", "papeis_b", "rachadura_a", "rachadura_b", "rachadura_c", "cabo_b", "poca_acido_p"]
    for _ in range(95):
        x, y = rng.uniform(190, W - 190), rng.uniform(190, H - 190)
        if any(a <= x <= c and b <= y <= d for a, b, c, d in prib):
            dec(rng.choice(manchas), x, y, rng.random() < 0.5)
        else:
            dec(rng.choice(manchas), x, y, rng.random() < 0.5)
    # caixotes, barris e cacos soltos nos corredores
    soltos = ["caixa_suprimentos", "barril_toxico", "caixa_suprimentos", "mesa_lab", "pilar_lab", "armario_aco"]
    tent = 0
    n_soltos = 0
    while tent < 4000 and n_soltos < 26:
        tent += 1
        x, y = rng.uniform(220, W - 220), rng.uniform(220, H - 220)
        nome = rng.choice(soltos)
        if any(a <= x <= c and b <= y <= d for a, b, c, d in prib):
            continue
        if livre(x, y, raio(nome) + 22):
            obj(nome, x, y)
            n_soltos += 1
    for _ in range(14):
        x, y = rng.uniform(220, W - 220), rng.uniform(220, H - 220)
        if livre(x, y, 24):
            obj(rng.choice(["cacos_vidro", "lixo_lab"]), x, y, ocupa=False)

    # ---------------------------------------------------------------- luzes soltas
    for p, t in [((CX - 90, CY + 30), "tela_ciano"), ((CX + 90, CY - 40), "tela_ciano")]:
        luzes.append({"tipo": t, "pos": list(p), "orbe": [0, 0]})
    luzes.append({"tipo": "fio_solto", "pos": [2250, 1330], "orbe": [0, 0]})

    monstros = [
        {"centro": [620, 560], "raio": 150, "n": 3, "vaga": 100},
        {"centro": [2330, 560], "raio": 150, "n": 3, "vaga": 100},
        {"centro": [540, 1060], "raio": 140, "n": 3, "vaga": 100},
        {"centro": [2360, 1060], "raio": 150, "n": 3, "vaga": 100},
        {"centro": [1130, 620], "raio": 120, "n": 2, "vaga": 90},
        {"centro": [1760, 1060], "raio": 120, "n": 2, "vaga": 90},
        {"centro": [940, 1000], "raio": 70, "n": 2, "vaga": 80},
        {"centro": [1960, 650], "raio": 70, "n": 2, "vaga": 80},
    ]
    return {
        "semente": SEMENTE,
        "mapa": {"tam": [W, H], "chao": {"piso": "piso", "ganho": 2.2, "verde": 1.0, "dessat": 0.3}, "ambiente": "16232d",
                 "luar": {"e": 0.3, "h": 0.2, "ang": 70}, "ganho_objetos": 1.8, "ganho_decalques": 1.4, "borda_andavel": 150},
        "nascimento": {"heroi": [CX - 10, CY - 22], "monstros": monstros},
        "luz_tipos": LUZ_TIPOS,
        "luz_objetos": LUZ_OBJETOS,
        "luzes": luzes,
        "minimapa": MINIMAPA,
        "atmosfera": ATMOSFERA,
        "objetos": objetos,
        "decalques": decalques,
    }

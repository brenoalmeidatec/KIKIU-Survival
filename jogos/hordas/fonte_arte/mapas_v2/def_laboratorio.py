"""Laboratório da v2: o que cada objeto é para o jogo (colisão), os decalques de chão e o desenho do mapa (2880x1620 = 3x3 telas).

Os objetos e o piso vêm do Blender (modelos3d/mapa_laboratorio.py); este arquivo diz como entram no jogo e onde ficam. Lido por
fonte_arte/gerar_v2_mapas.py. O mapa segue a planta de docs/laboratorio/PLANTA_PROPOSTA.md: uma grade 3x3 de salas (servidores, comando,
espécimes / depósito, contenção, criogenia / geradores, pesquisa, ruínas) separadas por quatro corredores de 160 px, cada sala montada por uma
"receita" (fileiras com passo, equipamento alto encostado na parede, ilhas no miolo, decalques junto do objeto que os explica). A sala de
contenção fica no centro, onde o herói nasce no selo. As bordas fecham o mapa com a parede dos fundos e fileiras de equipamento alto.
"""
import math

import kit_decalques as kd
from kit_decalques import cor

SEMENTE = 31
W, H = 2880, 1620
AJUDA = (
    "O laboratório da v2 (2880x1620 = 3x3 telas, y para baixo), lido por v2/cenario.gd como a floresta (mesmo formato; veja v2_floresta.json), com "
    "\"mapa.pastas\" apontando para a arte (assets/v2/mapas/laboratorio), \"minimapa\" (cores do minimapa por objeto e decalque) e \"atmosfera\" (partículas "
    "do ambiente). É GERADO por fonte_arte/gerar_v2_mapas.py laboratorio --so-mapa (semente fixa; a planta das salas está em mapas_v2/def_laboratorio.py e em "
    "docs/laboratorio/PLANTA_PROPOSTA.md): para mudar onde as coisas ficam, mude o gerador e regere; editar este JSON à mão se perde na próxima geração."
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
# Pegada de cada tipo (cenario.json): meia-largura (LARG) e quanto o corpo se estende ATRÁS do pé (PROF). Serve para encostar na parede sem
# sobrepor nem deixar fresta. A colisão de verdade é a do atlas, por TIPO (pegadas_laboratorio.json), então desenho e colisão andam juntos:
# mudar um objeto de lugar aqui muda os dois.
LARG = {"parede_lab_a": 49, "parede_lab_b": 49, "parede_lab_c": 49, "porta_blindada": 49, "pilar_lab": 13.4, "rack_servidores": 15, "armario_aco": 17,
        "tanque_alto": 25.2, "tanque_quebrado": 25.2, "capsula_cripto": 16.8, "gerador": 34, "cano_grosso": 11.8, "mesa_lab": 27, "bancada_lab": 49,
        "console": 20.2, "console_quebrado": 20.2, "caixa_suprimentos": 16.8, "caixa_empilhada": 18.5, "barril_toxico": 11.8, "maca": 13.4, "gaiola": 21.8,
        "lampada_emergencia": 6, "duto_ventilacao": 18.5, "estante_amostras": 29}
PROF = {"parede_lab_a": 12, "parede_lab_b": 12, "parede_lab_c": 12, "porta_blindada": 12, "pilar_lab": 18.6, "rack_servidores": 18, "armario_aco": 16,
        "tanque_alto": 34.8, "tanque_quebrado": 34.8, "capsula_cripto": 46.4, "gerador": 30, "cano_grosso": 16.2, "mesa_lab": 18, "bancada_lab": 22,
        "console": 17.4, "console_quebrado": 17.4, "caixa_suprimentos": 23.2, "caixa_empilhada": 25.5, "barril_toxico": 16.2, "maca": 44.1, "gaiola": 23.2,
        "lampada_emergencia": 8.4, "duto_ventilacao": 18.6, "estante_amostras": 14}

# A planta (docs/laboratorio/PLANTA_PROPOSTA.md): grade 3x3 de salas separadas por dois corredores horizontais (H1, H2) e dois verticais (V1, V2),
# todos com 160 px. Nenhum sólido dentro deles, a não ser a quina das paredes e as lâmpadas coladas na parede.
COL = {"O": (150, 1000), "C": (1160, 1720), "L": (1880, 2730)}  # x das salas (oeste, centro, leste)
LIN = {"N": (150, 560), "M": (720, 1000), "S": (1160, 1470)}  # y das salas (norte, meio, sul)
CORREDORES = {"H1": (150, 560, 2730, 720), "H2": (150, 1000, 2730, 1160), "V1": (1000, 150, 1160, 1470), "V2": (1720, 150, 1880, 1470)}
SALAS = {
    "servidores": ("O", "N"), "comando": ("C", "N"), "especimes": ("L", "N"),
    "deposito": ("O", "M"), "contencao": ("C", "M"), "criogenia": ("L", "M"),
    "geradores": ("O", "S"), "pesquisa": ("C", "S"), "ruinas": ("L", "S"),
}
# Parede de FRENTE das salas do norte e do meio (pé na divisa sul da sala) e as portas dela, (centro x, largura). Uma parede esconde os 85 px que
# ficam atrás dela (a câmera olha de frente), então a faixa escondida cai dentro da sala, não no corredor, e a sala não guarda nada que importe
# ali. Os lados de cima das salas do meio e do sul são abertos para o corredor (equipamento baixo e a fileira de cada sala).
PAREDES_S = {
    560: {"O": [(620, 190)], "C": [(1440, 190)], "L": [(2330, 190)]},
    1000: {"O": [(870, 210)], "C": [(1440, 240)], "L": [(2300, 190)]},
}
# Lados verticais das salas (os que dão para V1 e V2): fechados só por uma coluna curta de equipamento alto no canto, o resto é abertura larga.
# QUINA diz o equipamento de cada canto, por (sala, lado); sem entrada vale caixa_empilhada.
ABERTURA_V = {"N": (190, 510), "M": (748, 950), "S": (1212, 1425)}
QUINA = {("servidores", "L"): "rack_servidores", ("especimes", "O"): "tanque_alto", ("deposito", "L"): "caixa_empilhada", ("criogenia", "O"): "capsula_cripto",
         ("geradores", "L"): "gerador", ("ruinas", "O"): "armario_aco", ("comando", "O"): "armario_aco", ("comando", "L"): "armario_aco",
         ("contencao", "O"): "pilar_lab", ("contencao", "L"): "pilar_lab", ("pesquisa", "O"): "armario_aco", ("pesquisa", "L"): "armario_aco"}


def montar(tam, rng):
    objetos, decalques, luzes = [], [], []

    def _a2(v):  # grade de 2 px: o desenho não treme em fração de pixel
        return int(round(v / 2.0)) * 2

    def obj(nome, x, y):
        objetos.append([nome, _a2(x), _a2(y)])

    def dec(nome, x, y, espelha=False):
        decalques.append([nome, _a2(x), _a2(y)] + ([1] if espelha else []))

    def fila(nome, xs, y):
        for x in xs:
            obj(nome, x, y)

    def flip():
        return rng.random() < 0.5

    # ---------------------------------------------------------------- paredes de frente (y=560 e y=1000), com portas
    def parede_h(y, x0, x1, portas):
        trechos, ini = [], x0 + (2 if x0 == 150 else 0)
        x1 -= 2 if x1 == 2730 else 0
        for c, larg in sorted(portas):
            trechos.append((ini, c - larg / 2.0))
            ini = c + larg / 2.0
        trechos.append((ini, x1))
        for k, (a, b) in enumerate(trechos):
            if b - a < 50:  # sobra curta entre a porta e a quina: o pilar da quina já fecha (um módulo de 98 px invadiria a porta)
                continue
            n = max(1, int(math.ceil((b - a) / 97.0)))  # a colisão do módulo tem 98 px: com passo até 97 não sobra fresta
            for i in range(n):
                nome = rng.choice(["parede_lab_a"] * 4 + ["parede_lab_b"] * 2 + ["parede_lab_c"] * 2)
                if (k < len(trechos) - 1 and i == n - 1) or (k > 0 and i == 0):
                    nome = "porta_blindada"  # a porta blindada ladeia cada abertura
                obj(nome, a + (i + 0.5) * (b - a) / n, y)

    for y, por_sala in PAREDES_S.items():
        for col, portas in por_sala.items():
            parede_h(y, COL[col][0], COL[col][1], portas)
            for lado, x in (("O", COL[col][0] + 13), ("L", COL[col][1] - 13)):
                if (col == "O" and lado == "O") or (col == "L" and lado == "L"):
                    continue
                obj("pilar_lab", x, y + 6)  # a quina onde a parede termina no cruzamento dos corredores

    # ---------------------------------------------------------------- colunas curtas nos lados verticais (a divisa é aberta no meio)
    def quina_v(sala, col, lado, linha):
        x0, x1 = COL[col]
        nome = QUINA.get((sala, lado), "caixa_empilhada")
        y0, y1 = LIN[linha]
        a0, a1 = ABERTURA_V[linha]
        xc = (x1 - LARG[nome] + 4) if lado == "L" else (x0 + LARG[nome] - 4)  # 4 px para dentro do corredor: fecha o entalhe da quina
        passo = max(14.0, PROF[nome] * 0.92)
        if linha == "M":  # no meio: só um pilar no canto de cima (embaixo a parede de frente e a quina já fecham)
            obj("pilar_lab", (x1 - LARG["pilar_lab"]) if lado == "L" else (x0 + LARG["pilar_lab"]), y0 + PROF["pilar_lab"] + 2)
            return
        for k in range(max(1, int(math.ceil((a0 - y0) / passo)))):  # de cima: do limite da sala até a abertura
            obj(nome, xc, y0 + PROF[nome] + 4 + k * passo)
        if linha == "S":  # de baixo (o sul do mapa): da borda até a abertura
            for k in range(max(1, int(math.ceil((y1 - a1) / passo)))):
                obj(nome, xc, y1 + 3 - k * passo)

    # ---------------------------------------------------------------- receitas das salas
    CX, CY = 1440, 830

    # NO Servidores: duas fileiras de rack com passo 90 (corredor frio no meio), consoles nas pontas da fileira
    fila("rack_servidores", [220 + 90 * i for i in range(8)], 150 + PROF["rack_servidores"] + 4)  # encostado: o fundo fica a 4 px do limite andável (y=150), que o corpo (3,5 px de meia-altura) ainda ocupa
    fila("rack_servidores", [310 + 90 * i for i in range(6)], 380)
    obj("console", 240, 290)
    obj("console", 905, 290)
    obj("mesa_lab", 905, 440)
    for n, x, y in [("cabo_a", 262, 296), ("cabo_c", 800, 294), ("cabo_b", 560, 262), ("grade_dreno", 620, 296), ("cabo_b", 450, 462), ("grade_dreno", 330, 460),
                    ("papeis_a", 870, 458), ("papeis_b", 944, 452)]:
        dec(n, x, y, flip())
    obj("lixo_lab", 180, 450)

    # N Comando: arco de consoles voltado para o sul, mesa e papéis atrás, estantes nos cantos de cima
    for k in range(-3, 4):
        obj("console", CX + 72 * k, 270 + 7 * k * k)
    obj("mesa_lab", CX, 206)
    obj("estante_amostras", 1280, 150 + PROF["estante_amostras"] + 4)
    obj("estante_amostras", 1600, 150 + PROF["estante_amostras"] + 4)
    for n, x, y in [("papeis_a", CX + 24, 214), ("papeis_b", CX - 40, 232), ("cabo_a", 1330, 304), ("cabo_c", 1560, 308), ("grade_dreno", CX, 350), ("cabo_b", 1400, 364)]:
        dec(n, x, y, flip())
    luzes.append({"tipo": "tela_ciano", "pos": [CX, 300], "orbe": [0, 0]})

    # NE Espécimes: tanques em fileira (passo 170) na parede norte, gaiolas e macas embaixo (acima da faixa que a parede de frente esconde)
    ty = 260  # a planta põe a fileira de tanques no meio da sala (passo 170), com um corredor atrás deles
    for i in range(4):
        obj("tanque_quebrado" if i == 2 else "tanque_alto", 2030 + 170 * i, ty)
    dec("poca_acido_g", 2370, ty + 14)
    dec("poca_acido_p", 2320, ty + 28)
    fila("gaiola", [1990 + 72 * i for i in range(4)], 440)
    fila("maca", [2500, 2580], 446)
    obj("console_quebrado", 2660, 410)
    obj("restos_cobaia", 2420, 372)
    for n, x, y in [("mancha_sangue", 2540, 456), ("mancha_sangue", 2130, 456), ("rachadura_b", 2300, 330), ("cabo_a", 2640, 440), ("papeis_b", 2640, 398)]:
        dec(n, x, y, flip())

    # O Depósito: caixas 2x3 na parede oeste, barris 2x2 sobre a faixa de perigo, armários na frente norte
    for cx_ in (262, 292):
        for cy_ in (798, 820, 842):
            obj("caixa_empilhada", cx_, cy_)
    fila("caixa_suprimentos", [390, 416], 842)
    dec("faixa_perigo_g", 585, 868)
    for dx, dy in ((0, 0), (26, 0), (0, 22), (26, 22)):
        obj("barril_toxico", 572 + dx, 852 + dy)
    fila("armario_aco", [470 + 40 * i for i in range(4)], 720 + PROF["armario_aco"] + 4)
    obj("mesa_lab", 800, 860)
    for n, x, y in [("poca_oleo_p", 600, 892), ("papeis_b", 790, 836), ("papeis_a", 770, 874), ("poca_acido_p", 645, 872), ("seta_chao", 930, 790)]:
        dec(n, x, y, flip())
    obj("lixo_lab", 700, 892)

    # Centro Contenção: selo, 4 tanques simétricos em volta do herói, consoles e faixas de perigo nas bocas das portas
    dec("selo_central", CX, CY)
    dec("selo_pequeno", CX, CY)
    for n, dx, dy in [("tanque_alto", -230, -62), ("tanque_alto", 230, -62), ("tanque_quebrado", -230, 62), ("tanque_alto", 230, 62)]:
        obj(n, CX + dx, CY + dy)
    fila("console", [1290, 1350, 1530, 1590], 760)
    for dx in (-1, 1):
        dec("faixa_perigo_g", CX + dx * 205, CY + 110)
    dec("faixa_perigo_p", CX, 744)
    for n, x, y in [("cabo_a", 1330, 790), ("cabo_b", 1560, 795), ("cabo_c", 1250, 905), ("cabo_a", 1640, 910), ("grade_dreno", CX, 898), ("grade_dreno", CX, 770),
                    ("rachadura_c", 1380, 870), ("rachadura_a", 1500, 800), ("poca_acido_g", 1230, 920), ("poca_acido_p", 1688, 906)]:
        dec(n, x, y, flip())
    obj("restos_cobaia", CX - 260, CY + 100)
    obj("cacos_vidro", CX - 190, CY + 85)
    luzes.append({"tipo": "tela_ciano", "pos": [CX - 90, CY + 30], "orbe": [0, 0]})
    luzes.append({"tipo": "tela_ciano", "pos": [CX + 90, CY - 40], "orbe": [0, 0]})

    # L Criogenia: cápsulas em fileira de 5 (passo 125) na parede norte, bancadas em ilha de 2, canos na parede leste
    fila("capsula_cripto", [2150 + 125 * i for i in range(5)], 720 + PROF["capsula_cripto"] + 8)
    obj("bancada_lab", 2400, 856)
    obj("bancada_lab", 2400, 880)
    obj("console", 2200, 870)
    obj("console", 2620, 870)
    fila("cano_grosso", [2710, 2710, 2710], 830)
    objetos[-2][2] = 846
    objetos[-1][2] = 862
    for n, x, y in [("cabo_c", 2300, 840), ("cabo_a", 2520, 844), ("grade_dreno", 2400, 924), ("poca_oleo_p", 2680, 892), ("papeis_a", 2330, 902)]:
        dec(n, x, y, flip())
    obj("cacos_vidro", 2680, 770)

    # SO Geradores: 3 geradores alinhados sobre a faixa de perigo, canos na parede oeste, barris juntos num canto
    for x in (330, 500, 670):
        obj("gerador", x, 1320)
        dec("faixa_perigo_g", x, 1338)
    dec("poca_oleo_g", 500, 1362)
    dec("poca_oleo_p", 335, 1366)
    for y in (1250, 1266, 1282):
        obj("cano_grosso", 170, y)
    for dx, dy in ((0, 0), (26, 0), (0, 22), (26, 22)):
        obj("barril_toxico", 790 + dx, 1400 + dy)
    fila("armario_aco", [400, 440], 1160 + PROF["armario_aco"] + 6)
    obj("lampada_emergencia", 760, 1205)
    for n, x, y in [("cabo_a", 410, 1346), ("cabo_c", 590, 1350), ("poca_oleo_p", 920, 1384), ("rachadura_c", 700, 1240)]:
        dec(n, x, y, flip())
    obj("lixo_lab", 250, 1420)

    # S Pesquisa: duas ilhas de 2 bancadas de costas e macas em fileira na parede sul
    for x in (1300, 1580):
        obj("bancada_lab", x, 1296)
        obj("bancada_lab", x, 1320)
    fila("maca", [1262, 1362, 1462, 1562], 1438)
    fila("estante_amostras", [1290, 1590], 1160 + PROF["estante_amostras"] + 4)
    obj("console", 1440, 1210)
    obj("mesa_lab", 1440, 1330)
    for n, x, y in [("papeis_a", 1240, 1334), ("papeis_b", 1640, 1340), ("papeis_a", 1440, 1354), ("cabo_b", 1440, 1256), ("mancha_sangue", 1370, 1458),
                    ("mancha_sangue", 1520, 1454)]:
        dec(n, x, y, flip())
    obj("cacos_vidro", 1388, 1356)
    obj("lixo_lab", 1500, 1366)

    # SE Ruínas: a única sala quebrada (paredes com falha, tanques e consoles quebrados); mesmo aqui tudo na grade, só faltam peças
    fila("parede_lab_c", [1990, 2082, 2174], 1186)
    fila("parede_lab_c", [2540, 2632], 1186)
    fila("tanque_quebrado", [2090, 2290, 2490], 1290)
    fila("console_quebrado", [2050, 2220, 2400, 2600], 1400)
    fila("caixa_empilhada", [2650, 2684], 1318)
    obj("maca", 2300, 1444)
    obj("barril_toxico", 2680, 1444)
    obj("barril_toxico", 2706, 1436)
    for n, x, y in [("poca_acido_g", 2290, 1316), ("poca_acido_p", 2090, 1316), ("rachadura_c", 2200, 1240), ("rachadura_a", 2560, 1344), ("rachadura_b", 1990, 1334),
                    ("rachadura_c", 2400, 1262), ("mancha_c", 2390, 1426), ("cabo_a", 2060, 1408), ("cabo_c", 2600, 1408)]:
        dec(n, x, y, flip())
    obj("cacos_vidro", 2180, 1360)
    obj("restos_cobaia", 2420, 1376)
    obj("cacos_vidro", 2540, 1224)
    luzes.append({"tipo": "fio_solto", "pos": [2250, 1350], "orbe": [0, 0]})

    for sala, (col, linha) in SALAS.items():
        for lado in ("O", "L"):
            if (col == "O" and lado == "O") or (col == "L" and lado == "L"):
                continue  # a borda do mapa já fecha
            quina_v(sala, col, lado, linha)

    # ---------------------------------------------------------------- corredores: só luz, faixa, seta e cabo, em ritmo fixo
    for x in (300, 880, 1630, 2600):  # lâmpadas de emergência coladas na parede de frente (sem vão entre as duas: o corpo entalaria)
        obj("lampada_emergencia", x, 568)
    for x in (300, 2600):
        obj("lampada_emergencia", x, 1008)
    for y, portas in ((560, [620, 1440, 2330]), (1000, [870, 1440, 2300])):
        for c in portas:
            dec("faixa_perigo_p", c, y + 18)
    for yy in (640, 1080):
        for x, fl in ((430, False), (1060, False), (2010, True), (2480, True)):
            dec("seta_chao", x, yy, fl)
    for x in (470, 1090, 1790, 2400):
        dec("cabo_b", x, 604 + rng.uniform(-6, 6), flip())
        dec("cabo_c", x + 180, 1044 + rng.uniform(-6, 6), flip())

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
    # norte: parede dos fundos (pé em y=146, logo acima da faixa andável, com portas blindadas aqui e ali) e uma fileira rala de equipamento atrás dela
    paredes = ["parede_lab_a"] * 4 + ["parede_lab_b"] * 2 + ["parede_lab_c"] * 2 + ["porta_blindada"]
    x, anterior = 50, ""
    while x < W - 30:
        nome = rng.choice(paredes)
        if nome == "porta_blindada" and anterior == nome:
            nome = "parede_lab_a"
        obj(nome, x, 146)
        anterior = nome
        x += 92
    x = 70
    while x < W:
        nome = rng.choice(TEMAS[t_norte[min(5, int(x // 480))]]["alto"])
        obj(nome, x + rng.uniform(-14, 14), 96 + rng.uniform(-10, 8))
        x += passo(nome, 120, 175)
    # sul: uma fileira só, com o equipamento alto e o baixo do tema do trecho
    x = 50
    while x < W:
        t = TEMAS[t_sul[min(5, int(x // 480))]]
        nome = rng.choice(t["alto"] + t["baixo"])
        obj(nome, x + rng.uniform(-10, 10), max(1540 + rng.uniform(-8, 12), 1470 + 36 + 1.05 * PROF[nome]))  # o fundo não entra na faixa andável
        x += passo(nome, 82, 120)
    # oeste e leste: duas colunas de equipamento, a de fora mais rala (o miolo fica livre; a câmera para na borda)
    for xs, temas in (((62, 118), t_oeste), ((W - 62, W - 118), t_leste)):
        for k, xc in enumerate(xs):
            y = 170 + (k * 31)
            while y < 1500:
                nome = rng.choice(TEMAS[temas[min(3, int((y - 150) // 380))]]["alto" if k == 0 else "baixo"])
                if k == 1:  # a coluna de dentro fica fora da faixa andável (o corpo do herói não acha um fiapo de chão entre as peças)
                    xc = (W - 150 + 24 + LARG[nome]) if xs[0] > W / 2 else (150 - 24 - LARG[nome])
                obj(nome, xc + rng.uniform(-4, 4), y)
                y += rng.uniform(96, 132) if k == 0 else rng.uniform(72, 100)
    # uma luz fraca por trecho, na cor do tema (sem orbe: só clareia o equipamento e o chão da borda)
    for i in range(6):
        cx_ = 240 + i * 480
        luzes.append({"tipo": TEMAS[t_sul[i]]["luz"], "pos": [round(cx_ + rng.uniform(-60, 60)), 1525], "orbe": [0, 0]})
        luzes.append({"tipo": TEMAS[t_norte[i]]["luz"], "pos": [round(cx_ + rng.uniform(-60, 60)), 128], "orbe": [0, 0]})
    for i in range(4):
        cy_ = 340 + i * 380
        luzes.append({"tipo": TEMAS[t_oeste[i]]["luz"], "pos": [round(150 + rng.uniform(-20, 20)), cy_], "orbe": [0, 0]})
        luzes.append({"tipo": TEMAS[t_leste[i]]["luz"], "pos": [round(W - 150 + rng.uniform(-20, 20)), cy_], "orbe": [0, 0]})
    # chão da borda: só cabo, ralo, placa e rachadura (coisas sem dono não cabem aqui: poça, papel e sangue ficam junto do que as faz)
    chao_borda = ["cabo_a", "cabo_b", "cabo_c", "grade_dreno", "rachadura_b", "rachadura_c"]
    x = 170
    while x < W - 150:
        dec(rng.choice(chao_borda), x, 1458 + rng.uniform(-6, 8), flip())
        dec(rng.choice(chao_borda), x + rng.uniform(0, 60), 190 + rng.uniform(-6, 10), flip())
        x += rng.uniform(250, 330)
    y = 300
    while y < 1400:
        dec(rng.choice(chao_borda), 196 + rng.uniform(-8, 10), y, flip())
        dec(rng.choice(chao_borda), W - 196 + rng.uniform(-10, 8), y + rng.uniform(0, 40), flip())
        y += rng.uniform(250, 320)
    for x, y in [(1100, 1500), (2540, 1495), (610, 190), (1960, 184)]:
        obj(rng.choice(["restos_cobaia", "cacos_vidro", "lixo_lab"]), x, y)

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
                 "luar": {"e": 0.3, "h": 0.2, "ang": 70}, "ganho_objetos": 1.8, "ganho_decalques": 1.4, "borda_andavel": 150,
                 "sombra_ambiente": {"e": 1.1, "ang": 58, "comp": 0.6}, "copas_altura_min": 52},
        "nascimento": {"heroi": [CX - 10, CY - 22], "monstros": monstros},
        "luz_tipos": LUZ_TIPOS,
        "luz_objetos": LUZ_OBJETOS,
        "luzes": luzes,
        "minimapa": MINIMAPA,
        "atmosfera": ATMOSFERA,
        "objetos": objetos,
        "decalques": decalques,
    }

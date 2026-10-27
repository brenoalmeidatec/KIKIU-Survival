"""Vila Amaldiçoada da v2 (id interno "cidade"): o que cada objeto é para o jogo (colisão), os decalques de chão e o desenho do mapa (2880x1620 = 3x3 telas).

Os objetos e o piso vêm do Blender (modelos3d/mapa_cidade.py); as medidas (pegada, altura e luz de cada um) estão em mapas_v2/medidas_cidade.py, que este arquivo lê.
Lido por fonte_arte/gerar_v2_mapas.py. A planta é a de antes da #429 (a cidade pós-apocalíptica virou vila medieval amaldiçoada sem mexer em nomes de objeto,
pegadas nem posições): uma grade de 5 x 4 quarteirões. Cada azulejo do piso (512 x 362 px) tem um cruzamento no canto e um quarteirão no meio, com o lote de
7 x 7 m. As RUAS ficam livres: o herói e os monstros andam pelo eixo e pelas pistas. Carroças estacionadas, lampiões e placas ficam no meio-fio; as casas encostam
no fundo dos lotes (predio_* = casas, taverna, capela e uma casa queimada); a praça (B) tem a barraca de mercado, bancos e o braseiro; as bordas do mapa (fora da
área andável) têm a fileira de casas e de celeiros que fecha a vila. O herói nasce no cruzamento central.
"""
import math

import decalques_cidade as dc
import kit_decalques as kd
import medidas_cidade as med
from kit_decalques import cor

SEMENTE = 47
W, H = 2880, 1620
AJUDA = (
    "A Vila Amaldiçoada da v2 (id cidade, 2880x1620 = 3x3 telas, y para baixo), lida por v2/cenario.gd como o laboratório (mesmo formato; veja v2_floresta.json), com "
    "\"mapa.pastas\" apontando para a arte (assets/v2/mapas/cidade), \"minimapa\" (cores do minimapa por objeto e decalque) e \"atmosfera\" (partículas "
    "do ambiente). Foi montada por fonte_arte/gerar_v2_mapas.py (semente fixa) a partir dos objetos do Blender (modelos3d/mapa_cidade.py) e das medidas "
    "de mapas_v2/medidas_cidade.py; depois disso o JSON é a fonte: edite aqui."
)

TW, TH = med.PISO["tam_px"]          # azulejo do piso: 512 x 362 px (16 m x 16 m)
MEIA_RUA_X = 104.0                   # meia rua de 6,5 m na horizontal (px)
MEIA_RUA_Y = 73.5                    # meia rua de 6,5 m na vertical (px)
FRENTE = 11.315                      # do centro da pegada à frente dela: metade da profundidade projetada (px por metro, sen 45)
BORDA_ANDAVEL = 150                  # a área andável é o mapa menos 150 px (mundo.gd)

# nome: col = como colide (caixa = a pegada w x d, em elipse; passavel = o herói passa por cima). Vem de medidas_cidade.MEDIDAS.
OBJETOS = {
    nome: ({"col": "passavel", "d": m["d"]} if m["col"] is None else {"col": "caixa", "w": m["w"], "d": m["d"]})
    for nome, m in med.MEDIDAS.items()
}

# o tipo de cada quarteirão, de cima para baixo (linha j) e da esquerda para a direita (coluna i):
# P = prédio no lote; E = pátio com contêiner, caçamba e pneus; B = praça com ponto de ônibus, bancos e fogueira de barril;
# R = ruína (muro partido, entulho e carro queimado); V = lote vazio com tapume e manchas.
GRADE = ["PRPEP", "EPBPR", "PVPEP", "RPEPV"]
PREDIOS_LOTE = ["predio_loja", "predio_bar", "predio_apto_a", "predio_ruina", "predio_apto_b", "predio_torre"]
BORDA_N = ["predio_ruina", "predio_apto_a", "predio_loja", "predio_apto_b", "predio_bar", "predio_torre"]   # fileira do norte (pé em y=126)
BORDA_S = ["container_a", "cacamba", "container_b", "barricada_concreto", "entulho_b", "container_b"]      # fileira do sul (pé em y=1532)
BORDA_L = ["predio_ruina", "predio_apto_b", "predio_loja", "predio_apto_a", "predio_ruina"]               # colunas das laterais
CARROS_H = ["carro_a", "carro_b", "carro_c", "carro_queimado"]
CARROS_V = ["carro_a_v", "carro_b_v", "carro_c_v"]
RUA_DEC = ["poca_chuva_p", "poca_chuva_g", "poca_oleo_p", "poca_oleo_g", "mancha_a", "mancha_b", "mancha_c", "rachadura_a", "rachadura_b",
           "rachadura_c", "papeis_a", "papeis_b", "fuligem", "mancha_sangue", "cabo_b"]
EXTRAS = med.luzes_extras()          # luzes além da principal (fachada com vitrine e neon): viram "luzes" soltas ao lado de cada cópia


# ------------------------------------------------------------------ chão: decalques (Pillow, achatados por sen 45)
def _poca_oleo(w, h):
    return lambda rng: kd.poca(w, h, rng, cor("2a2018"), cor("7a6a52"), cor("3e3226"))   # poça de lama


def _poca_chuva(w, h):
    return lambda rng: kd.poca(w, h, rng, cor("1d2a33"), cor("a9c2cf"), cor("3b4b56"), alfa=200)


def _mancha(w, h, c="14100c", alfa=190):
    return lambda rng: kd.mancha(w, h, rng, cor(c), alfa=alfa)


DECALQUES = {
    "bueiro": lambda rng: dc.bueiro(rng),
    "bueiro_aberto": lambda rng: dc.bueiro(rng, aberto=True),
    "poca_oleo_g": _poca_oleo(100, 70),
    "poca_oleo_p": _poca_oleo(58, 40),
    "poca_chuva_g": _poca_chuva(120, 78),
    "poca_chuva_p": _poca_chuva(66, 44),
    "mancha_a": _mancha(96, 66),
    "mancha_b": _mancha(70, 48),
    "mancha_c": _mancha(120, 80, alfa=150),
    "mancha_sangue": _mancha(76, 52, "4a1515", 200),
    "fuligem": _mancha(150, 96, "0b0b0d", 120),
    "rachadura_a": lambda rng: kd.rachadura(130, 40, rng, cor("0b0c0e")),
    "rachadura_b": lambda rng: kd.rachadura(100, 36, rng, cor("0b0c0e")),
    "rachadura_c": lambda rng: kd.rachadura(150, 44, rng, cor("0b0c0e"), ramos=3),
    "cabo_b": lambda rng: kd.cabo(110, 30, rng, cor("6b5030"), cor("3a2a18")),      # corda
    "grade_dreno": lambda rng: kd.grade(72, 44, cor("4a4540"), cor("0a0907"), rng),
    "papeis_a": lambda rng: kd.papeis(60, 40, rng, ("d8c9a0", "c4b48a", "b0a07a")),   # pergaminhos
    "papeis_b": lambda rng: kd.papeis(48, 34, rng, ("d8c9a0", "c4b48a", "b0a07a")),
    "faixa_obra_g": lambda rng: kd.retangulo(176, 20, cor("5a3f28"), cor("2e2014"), rng, 0.1),   # tábuas
    "faixa_obra_p": lambda rng: kd.retangulo(88, 20, cor("5a3f28"), cor("2e2014"), rng, 0.1),
}


# ------------------------------------------------------------------ luzes
# os tipos da vila vêm de medidas_cidade (lampião, vitral roxo, lanterna rubra, janela quente...); tocha e aura são as do herói (como no laboratório)
LUZ_TIPOS = dict(med.LUZ_TIPOS)
LUZ_TIPOS["tocha"] = {"cor": [1.0, 0.62, 0.26], "e": 1.9, "r": 290, "h": 45, "tremor": 0.07}
LUZ_TIPOS["aura"] = {"cor": [0.45, 0.72, 1.0], "e": 0.7, "r": 120, "h": 60}
LUZ_OBJETOS = med.luz_objetos()
MINIMAPA = {
    "chao": "2e2a26",
    "fechado": "0e0c0a",
    "objetos": {
        "predio_loja": ["9a7a5a", 2], "predio_bar": ["a8885a", 2], "predio_apto_a": ["8f7a62", 2], "predio_apto_b": ["8f7a62", 2],
        "predio_torre": ["9a948a", 2], "predio_ruina": ["4a443e", 2], "poste_rua": ["ffb257", 1], "poste_rua_e": ["ffb257", 1],
        "semaforo": ["e0453a", 1], "placa_neon": ["a678f0", 1], "barril_fogo": ["ff8a3d", 1], "ponto_onibus": ["b04a4a", 1],
        "container_a": ["a88b4c", 2], "container_b": ["a88b4c", 2], "cacamba": ["a88b4c", 1], "pneus": ["a88b4c", 1],
        "carro_a": ["7d5c3a", 1], "carro_b": ["7d5c3a", 1], "carro_c": ["7d5c3a", 1], "carro_queimado": ["2b2b2b", 1],
        "carro_a_v": ["7d5c3a", 1], "carro_b_v": ["7d5c3a", 1], "carro_c_v": ["7d5c3a", 1],
        "muro_tijolo": ["8a8478", 1], "muro_quebrado": ["8a8478", 1], "barricada_concreto": ["8a8478", 1],
        "barricada_madeira": ["8a6a3a", 1], "sacos_areia": ["a89a72", 1], "lixeira_azul": ["8aa0b0", 1],
    },
    "decalques": {"bueiro": ["5a4a38", 1], "poca_chuva_g": ["4d7a8c", 2], "poca_oleo_g": ["3e3226", 1]},
}
ATMOSFERA = {
    "vaga": {"n": 20, "cor": [1.0, 0.62, 0.3], "tam": 0.7, "vel": 0.7},          # faíscas e brasas
    "folhas": {"n": 12, "cor": [0.55, 0.4, 0.25, 0.6], "tam": 0.8, "vel": 0.5},  # folhas secas que caem
}


# ------------------------------------------------------------------ o mapa
def montar(tam, rng):
    objetos, decalques, luzes = [], [], []
    ocupados = []  # (cx, cy, rx, ry) das elipses de colisão já postas (a conta de "livre" usa o raio maior)

    def obj(nome, cx, cy):
        """Põe o objeto pela ORIGEM (centro da pegada, no chão). O JSON guarda o pé, que é a frente da pegada (o gerador conta a diferença)."""
        m = med.MEDIDAS[nome]
        x, y = cx, cy + m["d"] * FRENTE
        objetos.append([nome, int(round(x)), int(round(y))])
        if m["col"] is not None:
            ocupados.append((cx, cy, m["w"] * 16.0 * 1.05, max(m["d"] * FRENTE * 1.05, 3.0)))
        for f in EXTRAS.get(nome, []):
            luzes.append({"tipo": f["tipo"], "pos": [round(x + f["luz"][0]), round(y + f["luz"][1])],
                          "orbe": [round(f["orbe"][0] - f["luz"][0], 1), round(f["orbe"][1] - f["luz"][1], 1)]})

    def dec(nome, x, y, espelha=False):
        decalques.append([nome, int(round(x)), int(round(y))] + ([1] if espelha else []))

    def livre(x, y, folga):
        return all((x - ex) ** 2 + (y - ey) ** 2 >= (max(rx, ry) + folga) ** 2 for ex, ey, rx, ry in ocupados)

    def quarteirao(i, j, tipo):
        bx, by = i * TW + MEIA_RUA_X, j * TH + MEIA_RUA_Y        # canto noroeste da calçada (a rua acaba aqui)
        lx, ly, lw, lh = med.lote_px(i, j)                      # o lote de concreto de 7 x 7 m (px do mundo)
        cx, cy = lx + lw / 2.0, ly + lh / 2.0
        if tipo == "P":
            nome = PREDIOS_LOTE[(i + 2 * j) % len(PREDIOS_LOTE)]
            obj(nome, cx, ly + 4 + med.MEDIDAS[nome]["d"] * FRENTE)     # fundo encostado no norte do lote; a frente dá para a calçada
            dec(rng.choice(["papeis_a", "papeis_b"]), lx + 30, ly + lh - 14, rng.random() < 0.5)
            dec(rng.choice(["mancha_a", "mancha_b", "mancha_c"]), lx + 190, cy + 20, rng.random() < 0.5)
            obj(rng.choice(["lixeira_azul", "lixeira_rodas"]), lx + 196, ly + 132)   # lixeira no quintal da frente
        elif tipo == "E":
            obj("container_a" if (i + j) % 2 == 0 else "container_b", cx + 2, ly + 4 + 2.4 * FRENTE)
            obj("cacamba", lx + 52, ly + 112)
            obj("pneus", lx + 178, ly + 118)
            obj("sacos_areia", cx - 6, ly + lh - 10)
            dec("faixa_obra_g", cx - 30, cy - 4, rng.random() < 0.5)
            dec("poca_oleo_p", lx + 90, cy + 36, rng.random() < 0.5)
        elif tipo == "B":
            obj("ponto_onibus", cx, ly + lh + 14)                   # no meio-fio do sul, com a vitrine
            obj("banco", lx + 58, cy - 40)
            obj("banco", lx + 166, cy - 40)
            obj("barril_fogo", cx + 52, cy + 36)                    # fogueira de barril com luz laranja
            obj("lixeira_metal", lx + 14, ly + 14)
            obj("placa_neon", lx + 214, ly + 18)
            dec("mancha_sangue" if rng.random() < 0.4 else "mancha_b", lx + 90, cy + 40)
            dec("papeis_b", cx - 30, cy + 24, rng.random() < 0.5)
        elif tipo == "R":
            obj("muro_quebrado", cx - 34, ly + 8)
            obj("muro_tijolo", cx + 64, ly + 8)
            obj("entulho_b", lx + 52, cy + 44)
            obj("carro_queimado", cx + 24, cy - 14)
            obj("cone_tombado", lx + 180, cy + 46)
            dec("fuligem", cx, cy + 10, rng.random() < 0.5)
            dec("mancha_sangue", lx + 150, cy + 56, rng.random() < 0.5)
            obj("pneus", lx + 196, ly + 120)
        elif tipo == "V":
            obj("barricada_madeira", lx + 60, ly + lh - 34)        # tapume no sul do lote
            obj("cone", lx + 200, cy + 30)
            dec("rachadura_c", cx - 20, cy - 18, rng.random() < 0.5)
            dec("poca_chuva_g", lx + 150, cy - 30, rng.random() < 0.5)
            dec("mancha_c", cx + 40, cy + 40, rng.random() < 0.5)
            obj("cone", lx + 44, cy + 64)
            obj("sacos_areia", lx + 170, cy + 58)
        # calçada: um poste por quarteirão (canto alternado), lixeira e hidrante no meio-fio
        if (i + j) % 2 == 0:
            obj("poste_rua", bx + 8, by + 8)
        else:
            obj("poste_rua_e", bx + 296, by + 208)
        if rng.random() < 0.5:
            obj(rng.choice(["lixeira_metal", "lixeira_rodas", "lixeira_azul"]), bx + 200 + rng.uniform(-30, 30), by + 14)
        if rng.random() < 0.3:
            obj("hidrante", bx + 40, by + 210)
        if rng.random() < 0.4:
            obj("placa_rua", bx + 120, by + 14)
        if rng.random() < 0.35:
            obj(rng.choice(["lixeira_metal", "lixeira_rodas", "lixeira_azul"]), bx + 260 + rng.uniform(-10, 10), by + 200)

    for j, linha in enumerate(GRADE):
        for i, tipo in enumerate(linha):
            quarteirao(i, j, tipo)

    # cruzamentos (cantos das calçadas, sorteados): semáforo no nordeste e placa de pare no sudoeste (o noroeste e o sudeste são dos postes)
    for i in range(1, 5):
        for j in range(1, 4):
            if rng.random() < 0.45:
                obj("semaforo", i * TW + 110, j * TH - 80)
            if rng.random() < 0.3:
                obj("placa_pare", i * TW - 110, j * TH + 80)

    # carros estacionados no meio-fio: uma faixa por lado, nunca no eixo da rua (o herói sempre passa)
    for j in range(1, 4):                # ruas horizontais em y = 362 j
        for i in range(5):               # quarteirão entre x = 512 i e 512 (i + 1)
            for lado in (-1, 1):
                if rng.random() < 0.35:
                    obj(rng.choice(CARROS_H), i * TW + rng.uniform(176, 336), j * TH + lado * 52.0)
    for i in range(1, 5):                # ruas verticais em x = 512 i
        for j in range(4):               # quarteirão entre y = 362 j e 362 (j + 1)
            for lado in (-1, 1):
                if rng.random() < 0.3:
                    obj(rng.choice(CARROS_V), i * TW + lado * 52.0, j * TH + rng.uniform(128, 234))

    # o chão das ruas (só decalque: não bloqueia): bueiros, poças, óleo, manchas e rachaduras
    for i in range(1, 5):
        for j in range(4):
            dec("bueiro_aberto" if rng.random() < 0.2 else "bueiro", i * TW + rng.choice([-40, 40]), j * TH + rng.uniform(96, 262))
            for _ in range(2):
                dec(rng.choice(RUA_DEC), i * TW + rng.uniform(-84, 84), j * TH + rng.uniform(90, 272), rng.random() < 0.5)
    for j in range(1, 4):
        for i in range(5):
            dec("bueiro" if rng.random() < 0.8 else "bueiro_aberto", i * TW + rng.uniform(150, 360), j * TH + rng.choice([-40, 40]))
            for _ in range(2):
                dec(rng.choice(RUA_DEC), i * TW + rng.uniform(120, 392), j * TH + rng.uniform(-62, 62), rng.random() < 0.5)
    for i in range(1, 5):
        for j in range(1, 4):
            dec(rng.choice(RUA_DEC), i * TW + rng.uniform(-60, 60), j * TH + rng.uniform(-60, 60), rng.random() < 0.5)

    # bordas (fora da área andável): fileira de prédios no norte, contêineres no sul, colunas nas laterais
    for k, x in enumerate(range(60, W, 280)):
        nome = BORDA_N[k % len(BORDA_N)]
        obj(nome, x, 126 - med.MEDIDAS[nome]["d"] * FRENTE)
    for k, x in enumerate(range(120, W - 60, 260)):
        nome = BORDA_S[k % len(BORDA_S)]
        obj(nome, x, 1532 - med.MEDIDAS[nome]["d"] * FRENTE)
    for lado, x_borda in ((-1, BORDA_ANDAVEL), (1, W - BORDA_ANDAVEL)):
        for k, y in enumerate((230, 500, 770, 1040, 1310)):
            nome = BORDA_L[(k + (1 if lado > 0 else 0)) % len(BORDA_L)]
            rx = med.MEDIDAS[nome]["w"] * 16.0 * 1.05
            x = x_borda - 3 - rx if lado < 0 else x_borda + 3 + rx
            obj(nome, x, y - med.MEDIDAS[nome]["d"] * FRENTE)

    # zonas de monstros: livres, na área andável, longe do herói e umas das outras
    heroi = (1536.0, 724.0)
    zonas = []
    tentativas = 0
    while len(zonas) < 8 and tentativas < 6000:
        tentativas += 1
        x, y = rng.uniform(230, W - 230), rng.uniform(230, H - 230)
        if math.hypot(x - heroi[0], y - heroi[1]) < 450 or not livre(x, y, 60):
            continue
        if any(math.hypot(x - zx, y - zy) < 380 for zx, zy, _ in zonas):
            continue
        zonas.append((x, y, rng.choice([110, 130, 150])))
    monstros = [{"centro": [round(x), round(y)], "raio": r, "n": 3 if k % 2 == 0 else 2, "vaga": 100} for k, (x, y, r) in enumerate(zonas)]

    return {
        "semente": SEMENTE,
        "mapa": {"tam": [W, H], "chao": {"piso": "piso", "ganho": 2.7, "verde": 0.9, "dessat": 0.2}, "ambiente": "1c1d26",
                 "luar": {"e": 0.25, "h": 0.2, "ang": 70}, "ganho_objetos": 1.8, "ganho_decalques": 1.4, "borda_andavel": BORDA_ANDAVEL},
        "nascimento": {"heroi": [int(heroi[0]), int(heroi[1])], "monstros": monstros},
        "luz_tipos": LUZ_TIPOS,
        "luz_objetos": LUZ_OBJETOS,
        "luzes": luzes,
        "minimapa": MINIMAPA,
        "atmosfera": ATMOSFERA,
        "objetos": objetos,
        "decalques": decalques,
    }

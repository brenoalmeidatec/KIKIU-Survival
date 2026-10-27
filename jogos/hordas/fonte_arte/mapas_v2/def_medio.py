"""Ruínas da Floresta da v2 (id "medio"): o que cada objeto é para o jogo (colisão), os decalques de chão e o desenho do mapa (2880x1620).

Até a #425 as Ruínas eram a Floresta com sete estruturas por cima (mesmos 579 objetos e a mesma disposição). Agora têm cenário próprio: um
templo de pedra cinza-azulada que a mata engoliu. Os objetos de pedra vêm do Blender (modelos3d/mapa_medio.py: colunas, muros, arco, estátua,
fonte seca, sarcófagos, obeliscos de runas); árvores, arbustos, raízes e as fogueiras vêm do atlas da floresta, esfriados em `tingir` (a vegetação
"tomando as pedras"). O piso (lajes grandes com musgo nas juntas) e os decalques (pavimento, musgo, folhas, rachaduras, selo de runas) são daqui.

Composição (coordenadas do mundo, y para baixo): alameda de colunas no oeste, praça da fonte seca no centro, cripta de sarcófagos no noroeste,
salões em ruína (parede de fundo com aberturas e colunas dos lados), arco de entrada para o platô do chefe no leste, trilhas de entulho entre
tudo. Quatro regras mantêm o mapa aberto, como no Laboratório: (1) nada sólido dentro dos discos reservados dos marcadores, do nascimento, das
zonas de monstros e dos espinhos; (2) dois sólidos nunca ficam a menos de FOLGA px um do outro (o corpo largo da horda passa em qualquer vão);
(3) muro só em trechos curtos com abertura, e coluna caída deitada ao longo do caminho; (4) o que fica na borda andável é pisado fora dela.
Os MARCADORES, o NASCIMENTO e as sete estruturas m4_* (Marco 4, arte do Codex) são da jogabilidade: o gerador os mantém como estão no JSON.
"""
import json
import math
from pathlib import Path

import kit_decalques as kd
from kit_decalques import cor
from PIL import Image, ImageDraw

SEMENTE = 53
W, H = 2880, 1620
AQUI = Path(__file__).resolve().parent
PROJ = AQUI.parent.parent / "projeto"
AJUDA = (
    "As Ruínas da Floresta da v2 (id medio, 2880x1620 = 3x3 telas, y para baixo), lidas por v2/cenario.gd como a floresta (mesmo formato; veja "
    "v2_floresta.json), com \"mapa.pastas\" apontando para a arte própria (assets/v2/mapas/medio), \"minimapa\" (cores por objeto e decalque) e "
    "\"atmosfera\". Objetos, decalques, luzes e piso SAEM de fonte_arte/gerar_v2_mapas.py medio --so-mapa (semente fixa; a composição está em "
    "fonte_arte/mapas_v2/def_medio.py): para mudar onde as coisas ficam, mude o gerador e regere. \"marcadores\", \"nascimento\" e as sete estruturas "
    "m4_* (arte do Codex, atlas em assets/v2/marco4) são da jogabilidade e o gerador os mantém: edite à mão. Marcadores (`marcadores`), na ordem da rota: "
    "tipo, pos [x, y], raio (px; o efeito acontece ao o herói ENTRAR no raio), forcar (cartas do baú), marca (id de dados/v2_cartas.json > chefes.marcas). "
    "Tipos: bau (cai ao chegar), bau_trancado (precisa da chave), chave (ruína; abre o baú trancado), fragmento (4 montam uma relíquia, que faz cair um baú), "
    "chefe (mini-chefe), atalho e portao (só dados por enquanto), alavanca, placa, mercador, pilar, mirante, defesa e espinhos (rect + seguro). O teste "
    "testes/v2_mapas confere que cada ponto está livre e alcançável."
)
PRESERVAR = ["nascimento", "marcadores"]

# estruturas do Marco 4 que o mapa usa (nome, x, y do pé): ficam onde sempre estiveram, amarradas aos marcadores
M4 = [("m4_ruina", 2469, 310), ("m4_altar", 1498, 1242), ("m4_passagem", 2512, 462), ("m4_plato", 2528, 1110), ("m4_portao", 1537, 1401),
      ("m4_torre", 1006, 522), ("m4_mirante", 1363, 1127)]


def ATLAS_EXTRA():
    """O atlas do Marco 4 (cenario.json): o gerador junta os tamanhos ao `tam` que recebe o montar."""
    cen = json.loads((PROJ / "assets" / "v2" / "marco4" / "cenario.json").read_text(encoding="utf-8"))
    return {i["nome"]: i for i in cen["itens"]}


# ------------------------------------------------------------------ objetos
# col: caixa (pegada w x d em metros, elipse inscrita) | passavel | manual (formas em px, relativas ao pé) | importar (vem da floresta, com a colisão dela)
OBJETOS = {
    "coluna_alta": {"col": "caixa", "w": 0.8, "d": 0.8},
    "coluna_quebrada": {"col": "caixa", "w": 0.85, "d": 0.85},
    "base_coluna": {"col": "caixa", "w": 0.85, "d": 0.85},
    "coluna_caida": {"col": "caixa", "w": 3.5, "d": 0.8, "folga": 1.0},
    "tambor_coluna": {"col": "caixa", "w": 0.7, "d": 0.6},
    "muro_ruina_a": {"col": "caixa", "w": 3.2, "d": 0.6, "folga": 1.0},
    "muro_ruina_b": {"col": "caixa", "w": 2.4, "d": 0.6, "folga": 1.0},
    "muro_ruina_c": {"col": "caixa", "w": 2.8, "d": 0.6, "folga": 1.0},
    "muro_alto": {"col": "caixa", "w": 3.4, "d": 0.8, "folga": 1.0},
    "arco_ruina": {"col": "manual", "d": 0.8, "formas": [{"tipo": "elipse", "centro": [-49.6, -9.1], "raio": [16.5, 9.0]},
                                                  {"tipo": "elipse", "centro": [49.6, -9.1], "raio": [16.5, 9.0]}]},
    "bloco_pedra": {"col": "caixa", "w": 0.9, "d": 0.75},
    "pilha_escombros": {"col": "caixa", "w": 1.6, "d": 0.9},
    "laje_tombada": {"col": "passavel", "d": 1.4},
    "degraus": {"col": "passavel", "d": 1.4},
    "pedestal_ruina": {"col": "caixa", "w": 0.95, "d": 0.95},
    "estatua_quebrada": {"col": "caixa", "w": 1.0, "d": 1.0},
    "fonte_seca": {"col": "caixa", "w": 2.5, "d": 2.5},
    "sarcofago": {"col": "caixa", "w": 0.95, "d": 2.0},
    "obelisco_runico": {"col": "caixa", "w": 0.8, "d": 0.8},
    "lapide_antiga": {"col": "caixa", "w": 0.5, "d": 0.3},
    "cacos_pedra": {"col": "passavel", "d": 0.6},
    "samambaia": {"col": "passavel", "d": 0.6},
    "cranio_antigo": {"col": "passavel", "d": 0.6},
    # da floresta, com outra tinta (colisão, pé e fogo vêm de lá)
    "arvore": {"importar": "arvore"}, "arvore_morta": {"importar": "arvore_morta"}, "arvore_pantano": {"importar": "arvore_pantano"},
    "arbusto": {"importar": "arbusto"}, "raizes": {"importar": "raizes"}, "toco": {"importar": "toco"}, "tronco": {"importar": "tronco"},
    "cogumelos": {"importar": "cogumelos"}, "pedras": {"importar": "pedras"}, "pedra": {"importar": "pedra"}, "rocha": {"importar": "rocha"},
    "braseiro": {"importar": "braseiro"}, "fogueira": {"importar": "fogueira"}, "altar": {"importar": "altar"},
    "caixa_oferenda": {"importar": "caixa_oferenda"},
}
# nomes (entre os importados) que são só chão: sem colisão para o teste de vão
PASSAVEIS = {n for n, c in OBJETOS.items() if c.get("col") == "passavel"}
CINZA_FRIO = (0.9, 1.0, 1.12)  # multiplicador de cor da vegetação importada


def tingir(img, nome):
    """Esfria o objeto da floresta: o verde vira verde-musgo apagado e o castanho vira cinza-azulado; o quente (fogo, vela, brasa) fica."""
    import numpy as np

    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    rgb, al = a[..., :3], a[..., 3:]
    quente = (rgb[..., 0] > rgb[..., 1] * 1.25) & (rgb[..., 0] > rgb[..., 2] * 1.5) & (rgb[..., 0] > 70)
    lum = (rgb * np.array([0.3, 0.55, 0.15], np.float32)).sum(axis=2, keepdims=True)
    frio = lum + (rgb - lum) * 0.5                       # dessatura pela metade
    frio = frio * np.array(CINZA_FRIO, np.float32)       # e puxa para o azul
    frio = frio * 1.04 + np.array([2, 4, 8], np.float32)
    out = np.where(quente[..., None], rgb, frio)
    return Image.fromarray(np.concatenate([np.clip(out, 0, 255), al], axis=2).astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ decalques (já achatados por sen 45, menos os que são "em pé")
def _musgo(w, h, escuro=False):
    return lambda rng: kd.mancha(w, h, rng, cor("2c4528" if escuro else "3b5a33"), cor("5f8a4d"), alfa=215)


def _terra(w, h):
    return lambda rng: kd.mancha(w, h, rng, cor("2a2723"), alfa=200)


def _folhas(w, h, n):
    tons = [cor("5b7a3a"), cor("3f5f2f"), cor("6e6a3a"), cor("4c3b2c"), cor("7a8a52")]

    def f(rng):
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for _ in range(n):
            x, y = rng.randrange(0, w - 3), rng.randrange(0, h - 2)
            d.rectangle((x, y, x + rng.choice((1, 2, 2, 3)), y + rng.choice((1, 1, 2))), fill=rng.choice(tons))
        return kd.achatar(im)
    return f


def _ervas(w, h, n):
    verdes = [cor("4d7a3c"), cor("38592c"), cor("6b9250"), cor("2f4b27")]

    def f(rng):  # folhas de capim em pé (desenhadas de lado, sem achatar)
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for _ in range(n):
            x = rng.randrange(2, w - 2)
            y1 = h - 1 - rng.randrange(0, max(1, h // 4))
            alt = rng.randrange(max(3, h // 3), h - 2)
            lado = rng.choice((-1, 0, 1))
            c = rng.choice(verdes)
            d.line((x, y1, x + lado * (alt // 3), y1 - alt), fill=c, width=1)
            d.point((x + lado * (alt // 3), y1 - alt), fill=kd.mais(c, 0.12))
        return im
    return f


def _pavimento(w, h, tons, fundo="1e2429"):
    """Trecho de pavimento de lajes grandes: lajotas de 20 a 28 px com junta escura e a borda comida (alfa picotado), para dar a trilha de pedra."""
    def f(rng):
        im = Image.new("RGBA", (w, h), cor(fundo))
        d = ImageDraw.Draw(im)
        y = 1
        while y < h - 1:
            alt = rng.choice((18, 22, 26))
            x = 1 + rng.randrange(0, 12)
            while x < w - 1:
                larg = rng.choice((22, 28, 36))
                c = rng.choice(tons)
                d.rectangle((x, y, min(w - 2, x + larg - 2), min(h - 2, y + alt - 2)), fill=c)
                d.line((x, y, min(w - 2, x + larg - 2), y), fill=kd.mais(c, 0.07))
                d.line((x, min(h - 2, y + alt - 2), min(w - 2, x + larg - 2), min(h - 2, y + alt - 2)), fill=kd.mais(c, -0.06))
                if rng.random() < 0.18:
                    d.line((x + 3, y + 3, x + larg // 2, y + alt - 4), fill=cor("171c20"), width=1)
                x += larg
            y += alt
        # a borda gasta: máscara de mancha por cima, o alfa vira o dela
        m = kd._mascara(w, h, rng, n=9, espalha=0.42, rugosidade=0.8)
        im.putalpha(m)
        return kd.achatar(im)
    return f


FRIOS = [cor("5f6b75"), cor("68747e"), cor("56616a"), cor("727e88"), cor("4d5961")]
DECALQUES = {
    "pavimento_g": _pavimento(260, 170, FRIOS),
    "pavimento_m": _pavimento(170, 120, FRIOS),
    "pavimento_p": _pavimento(100, 80, FRIOS),
    "musgo_g": _musgo(110, 74),
    "musgo_m": _musgo(70, 48),
    "musgo_p": _musgo(40, 28, True),
    "terra_a": _terra(90, 60),
    "terra_b": _terra(60, 40),
    "folhas_a": _folhas(64, 40, 14),
    "folhas_b": _folhas(46, 30, 9),
    "folhas_c": _folhas(90, 56, 22),
    "ervas_a": _ervas(28, 18, 11),
    "ervas_b": _ervas(20, 14, 7),
    "rachadura_a": lambda rng: kd.rachadura(130, 40, rng, cor("14181c")),
    "rachadura_b": lambda rng: kd.rachadura(100, 36, rng, cor("14181c")),
    "rachadura_c": lambda rng: kd.rachadura(150, 44, rng, cor("14181c"), ramos=3),
    "poca_ruina": lambda rng: kd.poca(104, 70, rng, cor("1b2b33"), cor("86a9b6"), cor("33513b"), alfa=215),
    "poca_ruina_p": lambda rng: kd.poca(60, 42, rng, cor("1b2b33"), cor("86a9b6"), cor("33513b"), alfa=215),
    "selo_runico": lambda rng: kd.anel(300, 3, cor("4f7f9c"), 16, cor("2f566d")),
    "selo_pequeno": lambda rng: kd.anel(110, 2, cor("4f7f9c"), 8, cor("2f566d")),
}

# ------------------------------------------------------------------ luzes
LUZ_TIPOS = {
    "tocha": {"cor": [1.0, 0.62, 0.26], "e": 1.9, "r": 290, "h": 45, "tremor": 0.07},
    "aura": {"cor": [0.45, 0.72, 1.0], "e": 0.7, "r": 120, "h": 60},
    "vela": {"cor": [1.0, 0.68, 0.32], "e": 1.1, "r": 105, "h": 35, "tremor": 0.06, "orbe": 0.2},
    "braseiro": {"cor": [1.0, 0.55, 0.2], "e": 2.5, "r": 250, "h": 45, "tremor": 0.1, "orbe": 0.2},
    "fogueira": {"cor": [1.0, 0.58, 0.22], "e": 1.4, "r": 170, "h": 40, "tremor": 0.08, "orbe": 0.2},
    "magia_roxa": {"cor": [0.74, 0.34, 1.0], "e": 1.5, "r": 260, "h": 50, "tremor": 0.04, "orbe": 0.3},
    "magia_azul": {"cor": [0.3, 0.7, 1.0], "e": 1.4, "r": 240, "h": 50, "tremor": 0.04, "orbe": 0.3},
    "magia_azul_fixa": {"cor": [0.3, 0.7, 1.0], "e": 1.4, "r": 240, "h": 50, "orbe": 0.3},
    "runa_fria": {"cor": [0.4, 0.82, 1.0], "e": 1.3, "r": 190, "h": 60, "tremor": 0.03, "orbe": 0.0},
}
LUZ_OBJETOS = {
    "obelisco_runico": {"tipo": "runa_fria", "luz": [0, 8], "orbe": [0, -58]},
    "altar": {"tipo": "vela", "luz": [15, -4], "orbe": [15, -27]},
    "braseiro": {"tipo": "braseiro", "luz": [0, -6], "orbe": "fogo", "fogo": 1.0},
    "fogueira": {"tipo": "fogueira", "luz": [0, -6], "orbe": "fogo", "fogo": 0.7},
}
MINIMAPA = {
    "chao": "2a3036",
    "fechado": "0d1216",
    "objetos": {
        "coluna_alta": ["8a949f", 2], "coluna_quebrada": ["7a848f", 2], "base_coluna": ["7a848f", 1], "coluna_caida": ["7a848f", 2],
        "tambor_coluna": ["7a848f", 1], "muro_ruina_a": ["6c7782", 2], "muro_ruina_b": ["6c7782", 2], "muro_ruina_c": ["6c7782", 1],
        "muro_alto": ["5d6873", 2], "arco_ruina": ["9aa4ae", 2], "bloco_pedra": ["7a848f", 1], "pilha_escombros": ["6c7782", 1],
        "pedestal_ruina": ["8a949f", 1], "estatua_quebrada": ["a6b0ba", 2], "fonte_seca": ["7aa0b8", 2], "sarcofago": ["8a949f", 2],
        "obelisco_runico": ["62d4ff", 2], "lapide_antiga": ["8a949f", 1], "arvore": ["34503a", 2], "arvore_morta": ["3a4540", 2],
        "arvore_pantano": ["2f4a38", 2], "arbusto": ["3d5a40", 1], "toco": ["4a4438", 1], "tronco": ["4a4438", 1], "rocha": ["6c7782", 1],
        "braseiro": ["ff8a3d", 1], "fogueira": ["ff8a3d", 1], "altar": ["d9b36a", 1], "m4_torre": ["8a949f", 2], "m4_ruina": ["8a949f", 2],
        "m4_plato": ["6c7782", 2], "m4_mirante": ["8a949f", 2], "m4_portao": ["8a949f", 2], "m4_altar": ["d9b36a", 2], "m4_passagem": ["5d6873", 2],
    },
    "decalques": {"pavimento_g": ["3c464e", 2], "poca_ruina": ["3a6478", 2], "selo_runico": ["4f7f9c", 3, "anel"]},
}
ATMOSFERA = {
    "vaga": {"n": 22, "cor": [0.55, 0.78, 1.0], "tam": 0.7, "vel": 0.55},          # poeira de luz fria, como esporos de pedra
    "folhas": {"n": 14, "cor": [0.46, 0.62, 0.38, 0.8], "tam": 0.8, "vel": 0.5},   # folhas verde-musgo caindo
}


# ------------------------------------------------------------------ geometria (px): formas de colisão de cada tipo, relativas ao pé
def _formas_tipo(nome, atlas_formas):
    """[(dx, dy, rx, ry)] da colisão do tipo (as elipses do atlas, que o gerador calcula do `col` acima)."""
    cfg = OBJETOS.get(nome)
    if nome in atlas_formas:
        return atlas_formas[nome]
    if cfg and cfg.get("col") == "caixa":
        f = cfg.get("folga", 1.05)
        rx, ry = cfg["w"] * 16.0 * f, max(cfg["d"] * 11.315 * f, 3.0)
        return [(0.0, -cfg["d"] * 11.315, rx, ry)]
    if cfg and cfg.get("col") == "manual":
        return [(f["centro"][0], f["centro"][1], f["raio"][0], f["raio"][1]) for f in cfg["formas"]]
    return []


def _carregar_formas_importadas():
    cen = json.loads((PROJ / "prototipos" / "objetos" / "cenario.json").read_text(encoding="utf-8"))
    por = {i["nome"]: [(f["centro"][0], f["centro"][1], f["raio"][0], f["raio"][1]) for f in i["colisao"]] for i in cen["itens"]}
    sai = {}
    for n, c in OBJETOS.items():
        if "importar" in c:
            sai[n] = por[c["importar"]]
    m4 = ATLAS_EXTRA()
    for n, i in m4.items():
        sai[n] = [(f["centro"][0], f["centro"][1], f["raio"][0], f["raio"][1]) for f in i["colisao"]]
    return sai


def _dentro(el, x, y, folga):
    cx, cy, rx, ry = el
    return ((x - cx) / (rx + folga)) ** 2 + ((y - cy) / (ry + folga)) ** 2 <= 1.0


def _toca(a, b, folga):
    """Duas elipses (cx, cy, rx, ry) ficam a menos de `folga` px uma da outra? Amostra o contorno de cada uma contra a outra, inflada."""
    if abs(a[0] - b[0]) > a[2] + b[2] + folga or abs(a[1] - b[1]) > a[3] + b[3] + folga:
        return False
    if _dentro(b, a[0], a[1], folga) or _dentro(a, b[0], b[1], folga):
        return True
    for k in range(20):
        t = 2 * math.pi * k / 20
        if _dentro(b, a[0] + a[2] * math.cos(t), a[1] + a[3] * math.sin(t), folga):
            return True
        if _dentro(a, b[0] + b[2] * math.cos(t), b[1] + b[3] * math.sin(t), folga):
            return True
    return False


# ------------------------------------------------------------------ o mapa
DEPURAR = {}        # (reservas, sólidos) da última montagem: o --previa do gerador desenha por cima
FOLGA = 58          # vão mínimo entre dois sólidos (px): o corpo largo da horda tem 28 px de diâmetro
ANDAVEL = (150, 150, 2730, 1470)
MARGEM_BORDA = 10   # um sólido de borda não pode chegar a menos disto da faixa andável


def montar(tam, rng):
    from_atlas = _carregar_formas_importadas()
    anterior = json.loads((PROJ / "dados" / "v2_medio.json").read_text(encoding="utf-8"))  # marcadores e nascimento (o gerador os repõe depois)
    objetos, decalques, luzes = [], [], []
    solidos = []     # elipses (cx, cy, rx, ry) dos sólidos postos
    reservas = []    # elipses livres (discos dos marcadores etc.): (cx, cy, rx, ry)
    avisos = []
    ultimo = [None]  # por que a última peça não coube (depuração do gerador)

    def _a2(v):
        return int(round(v / 2.0)) * 2

    def elipses(nome, x, y):
        return [(x + dx, y + dy, rx, ry) for dx, dy, rx, ry in _formas_tipo(nome, from_atlas)]

    def livre(nome, x, y, folga=FOLGA, borda=False, desde=None):
        es = elipses(nome, x, y)
        for e in es:
            if not borda and not (ANDAVEL[0] + 4 < e[0] - e[2] and e[0] + e[2] < ANDAVEL[2] - 4 and ANDAVEL[1] + 4 < e[1] - e[3] and e[1] + e[3] < ANDAVEL[3] - 4):
                return False  # o interior não encosta na faixa de fora: lá o corpo não anda e vira um fiapo de chão
            if borda and not (e[0] + e[2] < ANDAVEL[0] - MARGEM_BORDA or e[0] - e[2] > ANDAVEL[2] + MARGEM_BORDA
                              or e[1] + e[3] < ANDAVEL[1] - MARGEM_BORDA or e[1] - e[3] > ANDAVEL[3] + MARGEM_BORDA):
                return False
            for r in reservas:
                if _toca(e, r, 4):
                    ultimo[0] = ("reserva", tuple(int(v) for v in r))
                    return False
            for k, s in enumerate(solidos):
                if _toca(e, s, 8 if (desde is not None and k >= desde) else folga):
                    ultimo[0] = ("sólido", tuple(int(v) for v in s))
                    return False
        return True

    def pe(nome, x, y, borda=False, folga=FOLGA, desde=None):
        """Põe o objeto se couber (retorna True). Passável entra sem teste de vão (só não cai em cima de um sólido)."""
        if nome in PASSAVEIS:
            for s in solidos:
                if abs(s[0] - x) < s[2] * 0.6 and abs(s[1] - y) < s[3] + 10:
                    return False
            objetos.append([nome, _a2(x), _a2(y)])
            return True
        if not livre(nome, x, y, folga, borda, desde):
            avisos.append((nome, x, y))
            return False
        objetos.append([nome, _a2(x), _a2(y)])
        solidos.extend(elipses(nome, _a2(x), _a2(y)))
        return True

    def dec(nome, x, y, espelha=False):
        decalques.append([nome, _a2(x), _a2(y)] + ([1] if espelha else []))

    def flip():
        return rng.random() < 0.5

    # ---------------------------------------------------------------- reservas e fixos
    nasc = anterior["nascimento"]
    reservas.append((nasc["heroi"][0], nasc["heroi"][1], 70, 50))
    for z in nasc["monstros"]:
        reservas.append((z["centro"][0], z["centro"][1], 60, 48))  # o centro livre (o resto da zona os monstros acham)
    for m in anterior["marcadores"]:
        x, y = m["pos"]
        r = 150 if m["tipo"] == "chefe" else 56
        reservas.append((x, y, r, r * 0.8))
        if m["tipo"] == "espinhos":
            rx, ry, rw, rh = m["rect"]
            reservas.append((rx + rw / 2.0, ry + rh / 2.0, rw / 2.0 + 60, rh / 2.0 + 60))
    for n, x, y in M4:  # estruturas do Marco 4: sólidas, nas posições de sempre
        objetos.append([n, x, y])
        solidos.extend(elipses(n, x, y))

    # os pontos de luz e de abrigo do mapa de antes (altar, braseiro, fogueiras): ficam onde a rota espera luz e ponto de parada
    for nome, x, y in [("braseiro", 1282, 896), ("fogueira", 520, 430), ("fogueira", 1818, 986), ("fogueira", 2260, 1340),
                       ("altar", 520, 1230), ("altar", 1090, 961), ("caixa_oferenda", 470, 1274), ("caixa_oferenda", 1046, 1008)]:
        pe(nome, x, y)
    pe("cranio_antigo", 578, 1248)
    pe("cranio_antigo", 1148, 979)

    # os três obeliscos de runas marcam os pilares do enigma (terra, água, fogo), logo ao norte do marcador
    for m in anterior["marcadores"]:
        if m["tipo"] == "pilar":
            ox, oy = m["pos"][0], m["pos"][1] - 34
            reservas[:] = [r for r in reservas if not (abs(r[0] - m["pos"][0]) < 1 and abs(r[1] - m["pos"][1]) < 1)]
            pe("obelisco_runico", ox, oy, folga=20)
            reservas.append((m["pos"][0], m["pos"][1], 40, 28))
            dec("selo_pequeno", m["pos"][0], m["pos"][1] + 4)

    def rx_de(nome):
        fs = _formas_tipo(nome, from_atlas)
        return max([f[2] for f in fs] + [10.0])

    def grupo(pecas, cx, cy):
        """Põe todas as peças de uma vez ou nenhuma: pecas = [(nome, dx, dy)]; só vale se cada uma couber depois das anteriores."""
        n_obj, n_sol = len(objetos), len(solidos)
        for nome, dx, dy in pecas:
            if not pe(nome, cx + dx, cy + dy, desde=n_sol):
                del objetos[n_obj:]
                del solidos[n_sol:]
                return False
        return True

    def fiada(seq):
        """Fachada em ruína ao longo de x: seq = [(nome, vão antes dele em px)]; os vãos de 60 a 70 px são juntas, os de 110 a 140 são portas.
        Devolve as peças com dx relativo ao centro da fileira, prontas para `grupo`."""
        xs, x = [], 0.0
        for nome, vao in seq:
            x += (vao + rx_de(nome) if xs else rx_de(nome))
            xs.append((nome, x))
            x += rx_de(nome)
        meio = x / 2.0
        return [(n, xx - meio, 0.0) for n, xx in xs]

    # ---------------------------------------------------------------- praça da fonte seca (centro), com o selo de runas e as colunas em volta
    pe("fonte_seca", 1440, 860)
    dec("selo_runico", 1440, 860)
    dec("pavimento_g", 1440, 860)
    for ang, nome in [(40, "coluna_alta"), (140, "coluna_quebrada"), (220, "coluna_alta"), (320, "coluna_quebrada")]:
        a = math.radians(ang)
        pe(nome, 1440 + 250 * math.cos(a), 860 + 175 * math.sin(a) + 26)
    pe("degraus", 1440, 1040)
    pe("estatua_quebrada", 1440, 650)
    dec("pavimento_m", 1440, 720)

    # ---------------------------------------------------------------- alameda de colunas (oeste ao centro): duas fileiras
    nomes = ["coluna_alta", "coluna_quebrada", "coluna_alta", "base_coluna", "coluna_alta", "coluna_quebrada", "coluna_alta"]
    for k, x in enumerate(range(560, 1260, 112)):
        pe(nomes[k % len(nomes)], x, 660 + rng.uniform(-6, 6))
        pe(nomes[(k + 3) % len(nomes)], x + rng.uniform(-8, 8), 930 + rng.uniform(-6, 6))
    for x in range(560, 1260, 170):
        dec("pavimento_m", x + 40, 795, flip())

    # ---------------------------------------------------------------- cripta de sarcófagos (noroeste)
    for k in range(4):
        pe("sarcofago", 400 + k * 150, 400 + (k % 2) * 30)
        dec("musgo_p", 400 + k * 150, 410 + (k % 2) * 30, flip())
    for k in range(5):
        pe("lapide_antiga", 330 + k * 120, 540 + rng.uniform(-8, 8))
    pe("pedestal_ruina", 320, 230)
    pe("estatua_quebrada", 960, 340)

    # ---------------------------------------------------------------- fachadas em ruína (muro em trechos com porta, coluna nas pontas) e o arco de entrada
    modelos = [
        [("coluna_alta", 0), ("muro_ruina_a", 64), ("coluna_quebrada", 130), ("muro_ruina_c", 64)],
        [("muro_ruina_a", 0), ("coluna_quebrada", 130), ("muro_ruina_b", 64), ("coluna_alta", 64)],
        [("coluna_alta", 0), ("muro_ruina_b", 64), ("coluna_alta", 130), ("base_coluna", 64)],
        [("muro_ruina_b", 0), ("coluna_quebrada", 64), ("muro_ruina_c", 140), ("coluna_alta", 64)],
        [("muro_ruina_c", 0), ("muro_ruina_a", 64), ("coluna_alta", 130)],
    ]
    achados, centros = 0, []
    for tent in range(1500):
        if achados >= 18:
            break
        cx, cy = rng.uniform(300, 2600), rng.uniform(260, 1400)
        if any((cx - ax) ** 2 + (cy - ay) ** 2 < 330 ** 2 for ax, ay in centros):
            continue
        if grupo(fiada(modelos[achados % len(modelos)]), cx, cy):
            achados += 1
            centros.append((cx, cy))
            dec("pavimento_g", cx, cy + 90, flip())
            dec("musgo_m", cx + rng.uniform(-60, 60), cy + 10, flip())
    pontos = centros
    for cx, cy in [(2230, 1000), (1000, 1250), (1500, 560)]:
        if pe("arco_ruina", cx, cy):
            dec("pavimento_m", cx, cy + 18)
    print("  fachadas postas: %d de %d" % (achados, len(pontos)))

    # ---------------------------------------------------------------- estátuas e pedestais pelas trilhas
    for x, y in [(380, 1120), (900, 1130), (1700, 520), (2330, 800), (2400, 1330), (1220, 1330), (1700, 1220), (800, 560), (1840, 1240)]:
        pe(rng.choice(["estatua_quebrada", "pedestal_ruina", "estatua_quebrada"]), x, y)

    # ---------------------------------------------------------------- desabamentos: pedra caída junta (pilha, bloco, tambor, coluna deitada), em manchas pelo mapa
    for cx, cy in [(520, 760), (1160, 640), (1850, 800), (2250, 1130), (1300, 1250), (400, 1020), (2000, 1020), (860, 520), (2640, 1400),
                   (1560, 1440), (2300, 300), (1040, 300)]:
        grupo([("pilha_escombros", 0, 0), ("bloco_pedra", rng.uniform(70, 100), rng.uniform(-30, 30)), ("tambor_coluna", -rng.uniform(70, 95), rng.uniform(-25, 30)),
               ("coluna_caida", rng.uniform(-30, 30), 78)], cx, cy)

    # ---------------------------------------------------------------- borda: fecha o mapa (norte: muros e árvores; sul: escombros e árvores; lados: colunas e árvores)
    x = 40
    while x < W + 60:  # norte: parede dos fundos (pé em y=132) e árvores atrás
        pe(rng.choice(["muro_alto", "muro_alto", "muro_ruina_a"]), x, 132 + rng.uniform(-4, 4), borda=True, folga=0)
        x += 108 + rng.uniform(0, 30)
    x = 20
    while x < W + 60:
        pe(rng.choice(["arvore_pantano", "arvore", "arvore_morta", "arvore_morta"]), x, 82 + rng.uniform(-18, 14), borda=True, folga=0)
        x += rng.uniform(70, 120)
    x = 40
    while x < W + 60:  # sul: escombros e colunas partidas na frente e árvores
        pe(rng.choice(["pilha_escombros", "coluna_quebrada", "muro_ruina_c", "bloco_pedra", "muro_ruina_b"]), x, 1548 + rng.uniform(-6, 10), borda=True, folga=0)
        x += rng.uniform(90, 130)
    x = 60
    while x < W + 60:
        pe(rng.choice(["arvore", "arvore_pantano", "arvore_morta"]), x, 1606 + rng.uniform(-8, 6), borda=True, folga=0)
        x += rng.uniform(90, 150)
    y = 170
    while y < H:  # oeste e leste: colunas e árvores
        pe(rng.choice(["coluna_alta", "arvore", "coluna_quebrada", "arvore_pantano"]), 92 + rng.uniform(-8, 6), y, borda=True, folga=0)
        pe(rng.choice(["coluna_alta", "arvore", "coluna_quebrada", "arvore_pantano"]), W - 80 + rng.uniform(-6, 8), y + 30, borda=True, folga=0)
        y += rng.uniform(100, 150)
    y = 140
    while y < H:
        pe(rng.choice(["arvore_morta", "arvore", "arvore_pantano"]), 32 + rng.uniform(-4, 8), y, borda=True, folga=0)
        pe(rng.choice(["arvore_morta", "arvore", "arvore_pantano"]), W - 28 + rng.uniform(-8, 4), y + 40, borda=True, folga=0)
        y += rng.uniform(110, 160)

    # ---------------------------------------------------------------- miolo: o que a mata e o tempo espalharam (cada um só entra onde há vão)
    def espalhar(nome, n, tentativas=60, folga=FOLGA):
        puestos = 0
        for _ in range(n * tentativas):
            if puestos >= n:
                break
            if pe(nome, rng.uniform(175, 2705), rng.uniform(175, 1445), folga=folga):
                puestos += 1

    # bosques: a mata fecha em manchas, com árvores no meio, arbustos e raízes em volta (a pedra some debaixo delas)
    for cx, cy, r in [(300, 650, 190), (1180, 190, 150), (2000, 1400, 190), (2650, 760, 170), (780, 1420, 150), (1650, 250, 130), (2380, 1000, 140),
                      (500, 1180, 100)]:
        for _ in range(60):
            a = rng.uniform(0, 6.283)
            d = r * math.sqrt(rng.random())
            pe(rng.choice(["arvore", "arvore_morta", "arvore_pantano", "arvore"]), cx + d * math.cos(a), cy + d * math.sin(a) * 0.8)
        for _ in range(40):
            a = rng.uniform(0, 6.283)
            d = r * 1.15 * math.sqrt(rng.random())
            pe(rng.choice(["arbusto", "raizes", "arbusto", "cogumelos"]), cx + d * math.cos(a), cy + d * math.sin(a) * 0.8)
    for nome, n in [("pilha_escombros", 8), ("bloco_pedra", 10), ("tambor_coluna", 6), ("base_coluna", 6), ("coluna_quebrada", 5), ("lapide_antiga", 8),
                    ("toco", 6), ("tronco", 6), ("rocha", 6), ("pedra", 6), ("pedras", 10), ("arbusto", 12), ("cogumelos", 6)]:
        espalhar(nome, n)
    for nome, n in [("laje_tombada", 14), ("degraus", 4), ("cacos_pedra", 60), ("samambaia", 60), ("cranio_antigo", 6)]:
        c = 0
        for _ in range(n * 40):
            if c >= n:
                break
            if pe(nome, rng.uniform(175, 2705), rng.uniform(175, 1445)):
                c += 1

    # ---------------------------------------------------------------- decalques de chão: pavimento em trilhas, musgo e folhas junto das pedras, ervas, rachaduras
    for _ in range(30):
        dec(rng.choice(["pavimento_m", "pavimento_p", "pavimento_g"]), rng.uniform(200, 2680), rng.uniform(200, 1420), flip())
    for _ in range(80):
        dec(rng.choice(["musgo_g", "musgo_m", "musgo_m", "musgo_p"]), rng.uniform(170, 2710), rng.uniform(170, 1450), flip())
    for _ in range(60):
        dec(rng.choice(["terra_a", "terra_b"]), rng.uniform(170, 2710), rng.uniform(170, 1450), flip())
    for _ in range(110):
        dec(rng.choice(["folhas_a", "folhas_b", "folhas_c"]), rng.uniform(150, 2730), rng.uniform(150, 1470), flip())
    for _ in range(140):
        dec(rng.choice(["ervas_a", "ervas_b"]), rng.uniform(150, 2730), rng.uniform(150, 1470), flip())
    for _ in range(55):
        dec(rng.choice(["rachadura_a", "rachadura_b", "rachadura_c"]), rng.uniform(170, 2710), rng.uniform(170, 1450), flip())
    for _ in range(10):
        dec(rng.choice(["poca_ruina", "poca_ruina_p"]), rng.uniform(250, 2630), rng.uniform(250, 1370), flip())
    # musgo e folhas encostados em cada pedra grande
    for nome, x, y in [o for o in objetos if o[0] in ("coluna_alta", "coluna_quebrada", "sarcofago", "estatua_quebrada", "fonte_seca", "arco_ruina")]:
        if rng.random() < 0.7:
            dec(rng.choice(["musgo_m", "musgo_p"]), x + rng.uniform(-24, 24), y + rng.uniform(-4, 10), flip())
        if rng.random() < 0.5:
            dec(rng.choice(["folhas_a", "folhas_b"]), x + rng.uniform(-30, 30), y + rng.uniform(0, 16), flip())

    # ---------------------------------------------------------------- luzes: as magias dos marcadores ficam como estavam; uma luz azul fraca por salão e na cripta
    luzes.extend(l for l in anterior["luzes"] if str(l["tipo"]).startswith("magia"))
    for x, y in [(620, 1020), (2120, 620), (1980, 1300), (680, 300)]:
        luzes.append({"tipo": "runa_fria", "pos": [x, y], "orbe": [0, 0]})

    DEPURAR["reservas"], DEPURAR["solidos"] = list(reservas), list(solidos)
    if avisos:
        print("  (%d peças não couberam e foram puladas)" % len(avisos))
    return {
        "semente": SEMENTE,
        "mapa": {"tam": [W, H], "chao": {"piso": "piso", "ganho": 3.2, "verde": 0.9, "dessat": 0.12}, "ambiente": "1b2832",
                 "luar": {"e": 0.34, "h": 0.2, "ang": 90}, "ganho_objetos": 1.9, "ganho_decalques": 1.4, "borda_andavel": 150},
        "nascimento": nasc,
        "marcadores": anterior["marcadores"],
        "luz_tipos": LUZ_TIPOS,
        "luz_objetos": LUZ_OBJETOS,
        "luzes": luzes,
        "minimapa": MINIMAPA,
        "atmosfera": ATMOSFERA,
        "objetos": objetos,
        "decalques": decalques,
    }

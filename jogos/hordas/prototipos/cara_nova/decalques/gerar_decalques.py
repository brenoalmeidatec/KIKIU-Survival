"""Decalques de chao do protótipo cara nova (plano, deitado no chao), mais o chao candidato de 8.webp.

Fontes (copiadas ao lado, em fontes/): fonte_detalhes.webp (12 detalhes: folhas, musgo, pedrinhas, poca, galhos,
grama), fonte_raizes.webp (4 raizes), fonte_trilhas.webp (3 trilhas de lajes), fonte_circulo.webp (circulo de pedra
ritual) e fonte_chao_ia.webp (textura de chao candidata).

Saidas em jogos/hordas/projeto/prototipos/:
    decalques/decalques.png           atlas albedo, ~48 cores, alfa binario, sem dithering
    decalques/decalques_normal.png    atlas normal (mesmo layout; R = x, G = y para cima, B = z)
    decalques/decalques.json          itens: nome, regiao [x, y, w, h] no atlas, centro [x, y] dentro da regiao
    piso/piso_ia.png, piso/piso_ia_normal.png   chao candidato 512x512 sem emenda (o piso.png atual nao e tocado)

Previas em jogos/hordas/prints/: prototipo_decalques.png (escala do jogo + ampliado 2x) e
prototipo_piso_ia_vs_atual.png (2x2 de cada chao, lado a lado).

Como funciona:
    1. Recorte: o fundo (alfa baixo ou transparente) e o que encosta na borda do sheet, por flood fill. As pecas
       sao componentes conectados. Pecas perto de um decalque ficam (bordas fragmentadas de proposito); as perdidas
       longe do corpo do decalque sao descartadas.
    2. Reducao BOX (premultiplicada) para a escala do jogo a 960x540; alfa binario a 50%.
    3. Runas do circulo: marcas escuras fechadas dentro de uma laje (que parecem letras) recebem a mediana do anel de
       pedra em volta.
    4. Normal por tipo: domo por laje/pedra (separadas pelos rejuntes escuros), elevacao para raizes e galhos,
       depressao lisa na poca, e passa-alta da luminancia para o detalhe.
    5. Quantizacao unica para o atlas, sem dithering.

Uso (Python 3 com numpy e Pillow), de qualquer pasta:
    python jogos/hordas/prototipos/cara_nova/decalques/gerar_decalques.py
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
HORDAS = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
FONTES = os.path.join(AQUI, "fontes")
SAIDA = os.path.join(HORDAS, "projeto", "prototipos", "decalques")
PISO = os.path.join(HORDAS, "projeto", "prototipos", "piso")
PRINTS = os.path.join(HORDAS, "prints")

LIMITE_FUNDO = 12        # alfa <= isto conta como fundo (ruido de compressao)
LIMIAR_ALFA = 128        # alfa binario: 50%
DIST_PEDACO = 40         # px da fonte: peca a mais disto do corpo do decalque e perdida (descartada)
PAD = 2                  # espaco entre sprites no atlas
LARGURA_ATLAS = 512      # largura maxima do atlas (empacotamento em prateleiras)
CORES_ATLAS = 48         # paleta unica do atlas de decalques
CORES_CHAO = 32          # paleta do chao candidato (o chao atual tem 30)

LUM_PEDRA = 100          # laje/pedra (cinza-bege, lum ~100 a 120): acima disto e pedra; terra e musgo ficam abaixo
LUM_NUCLEO = 65          # runa: nucleo escuro (lum ~42 a 60 no sprite; rejunte ~14 e tambem entra, mas o anel o recusa)
LUM_ANEL = 90            # runa: mediana do anel em volta (pedra) acima disto; rejunte tem anel de 25 a 50
LUM_ANEL_MIN = 60        # runa: 10o percentil do anel acima disto (nenhum pedaco escuro encostado)
LUM_HALO = 100           # halo de antialias apagado junto da runa: so tons abaixo disto
LUM_NUCLEO_MANUAL = 85   # dentro das caixas manuais: tons abaixo disto sao marca (pedra fica acima de ~100)
# Caixas manuais (x0, y0, x1, y1) no circulo reduzido a 380 px: marcas com nucleo fraco demais para o automatico.
# Achadas olhando o circulo ampliado 4x depois da passada automatica (letras "Ϸ", "Q" e um ramo de runa).
CAIXAS_RUNAS = [(288, 55, 310, 74), (60, 108, 82, 132), (296, 116, 316, 134), (306, 86, 336, 108)]
AREA_FURO_PEDRA = 200    # buraco da pedra (musgo) ate isto e preenchido para o domo ficar liso
LUM_AGUA = 110           # poca: escura e quase sem saturacao
SAT_AGUA = 14            # max-min dos canais abaixo disto = agua (cinza), terra tem saturacao maior

ALT_PEDRA = 2.2          # altura do domo de cada laje/pedra (px de normal)
DIVISOR_DETALHE = 40.0   # 40 niveis de luminancia = 1 unidade de altura

# Largura alvo no jogo (px a 960x540). Raizes: escala uniforme, media de 160 px.
ALVO_LARGURA = {
    "circulo": 380,
    "trilha_reta": 170, "trilha_diagonal": 110, "trilha_curva": 100,
    "folhas_1": 50, "folhas_2": 50, "folhas_3": 50,
    "musgo_1": 60, "musgo_2": 60, "musgo_3": 60,
    "pedrinhas_1": 45, "pedrinhas_2": 45, "poca": 50,
    "galho_1": 60, "galho_2": 60, "grama": 45,
}
LARGURA_MEDIA_RAIZES = 160

# Ordem de leitura de cada sheet (linhas da esquerda para a direita, de cima para baixo).
ORDEM_DETALHES = [
    "folhas_1", "folhas_2", "folhas_3",
    "musgo_1", "musgo_2", "musgo_3",
    "pedrinhas_1", "pedrinhas_2", "poca",
    "galho_1", "galho_2", "grama",
]
# Centros aproximados (px da fonte) das pecas de sheets em que os decalques se tocam: atribuicao pelo centro mais perto.
CENTROS_RAIZES = {
    "raiz_longa": (430, 270), "raiz_forquilha": (1100, 290),
    "raiz_no": (400, 790), "raiz_estrela": (1100, 790),
}
CENTROS_TRILHAS = {
    "trilha_reta": (318, 590), "trilha_diagonal": (830, 560), "trilha_curva": (1260, 555),
}

# Tipo de relevo de cada decalque (ver normal_do_decalque).
TIPOS = {
    "chao": dict(alt_borda=0.8, raio_borda=3, peso=1.0),
    "pedra": dict(alt_borda=0.5, raio_borda=2, peso=0.6, pedras=True),
    "elevado": dict(alt_borda=2.5, raio_borda=4, peso=0.8),
    "agua": dict(alt_borda=0.3, raio_borda=3, peso=0.0, agua=True),
}
TIPO_DE = {
    "circulo": "pedra", "trilha_reta": "pedra", "trilha_diagonal": "pedra", "trilha_curva": "pedra",
    "raiz_longa": "elevado", "raiz_forquilha": "elevado", "raiz_no": "elevado", "raiz_estrela": "elevado",
    "galho_1": "elevado", "galho_2": "elevado",
    "folhas_1": "chao", "folhas_2": "chao", "folhas_3": "chao",
    "musgo_1": "chao", "musgo_2": "chao", "musgo_3": "chao",
    "pedrinhas_1": "pedra", "pedrinhas_2": "pedra", "poca": "agua", "grama": "chao",
}


# ---------------------------------------------------------------- recorte e componentes

def carregar(caminho):
    """RGBA uint8, HxWx4."""
    return np.asarray(Image.open(caminho).convert("RGBA"))


def fundo_por_borda(alfa):
    """Flood fill a partir das bordas: marca como fundo o que tem alfa baixo e encosta na borda do sheet."""
    h, w = alfa.shape
    baixo = bytearray((alfa.ravel() <= LIMITE_FUNDO).astype(np.uint8).tobytes())
    fundo = bytearray(w * h)
    pilha = []

    def semente(i):
        if baixo[i] and not fundo[i]:
            fundo[i] = 1
            pilha.append(i)

    for x in range(w):
        semente(x)
        semente((h - 1) * w + x)
    for y in range(h):
        semente(y * w)
        semente(y * w + w - 1)
    while pilha:
        i = pilha.pop()
        y, x = divmod(i, w)
        vizinhos = []
        if y > 0:
            vizinhos.append(i - w)
        if y < h - 1:
            vizinhos.append(i + w)
        if x > 0:
            vizinhos.append(i - 1)
        if x < w - 1:
            vizinhos.append(i + 1)
        for j in vizinhos:
            if baixo[j] and not fundo[j]:
                fundo[j] = 1
                pilha.append(j)
    return np.frombuffer(bytes(fundo), np.uint8).reshape(h, w).astype(bool)


def rotular(mascara):
    """Componentes conectados (8 vizinhos) de uma mascara booleana.
    Devolve (rotulo int32 HxW com 0 fora, lista de dicts com id, area, caixa e centro)."""
    h, w = mascara.shape
    m = bytearray(mascara.ravel().astype(np.uint8).tobytes())
    rot = [0] * (w * h)
    comps = []
    n = 0
    for s in np.flatnonzero(mascara.ravel()).tolist():
        if rot[s]:
            continue
        n += 1
        rot[s] = n
        pilha = [s]
        pontos = []
        while pilha:
            i = pilha.pop()
            pontos.append(i)
            y, x = divmod(i, w)
            for dy in (-1, 0, 1):
                ny = y + dy
                if not 0 <= ny < h:
                    continue
                for dx in (-1, 0, 1):
                    nx = x + dx
                    if 0 <= nx < w:
                        j = ny * w + nx
                        if m[j] and not rot[j]:
                            rot[j] = n
                            pilha.append(j)
        p = np.asarray(pontos)
        ys, xs = np.divmod(p, w)
        comps.append(dict(id=n, area=len(p), x0=int(xs.min()), x1=int(xs.max()),
                          y0=int(ys.min()), y1=int(ys.max()), cx=float(xs.mean()), cy=float(ys.mean())))
    return np.asarray(rot, np.int32).reshape(h, w), comps


def distancia_gap(a, b):
    dx = max(0, max(a["x0"], b["x0"]) - min(a["x1"], b["x1"]))
    dy = max(0, max(a["y0"], b["y0"]) - min(a["y1"], b["y1"]))
    return max(dx, dy)


def agrupar(comps, gap):
    """Une componentes cujas caixas ficam a menos de `gap` px uma da outra. Devolve listas de dicts."""
    pai = list(range(len(comps)))

    def raiz(a):
        while pai[a] != a:
            pai[a] = pai[pai[a]]
            a = pai[a]
        return a

    for i in range(len(comps)):
        for j in range(i + 1, len(comps)):
            if distancia_gap(comps[i], comps[j]) <= gap:
                pai[raiz(i)] = raiz(j)
    grupos = {}
    for i, c in enumerate(comps):
        grupos.setdefault(raiz(i), []).append(c)
    return list(grupos.values())


def perto_do_corpo(grupo, gap):
    """Mantem as pecas do grupo perto do corpo (as maiores); descarta as perdidas longe dele."""
    maior = max(c["area"] for c in grupo)
    corpo = [c for c in grupo if c["area"] >= 0.1 * maior]
    caixa = dict(x0=min(c["x0"] for c in corpo), x1=max(c["x1"] for c in corpo),
                 y0=min(c["y0"] for c in corpo), y1=max(c["y1"] for c in corpo))
    return [c for c in grupo if distancia_gap(c, caixa) <= gap]


def atribuir_por_centro(comps, centros):
    """Cada peca vai para o decalque cujo centro esta mais perto do centro da peca."""
    saida = {nome: [] for nome in centros}
    for c in comps:
        nome = min(centros, key=lambda k: (c["cx"] - centros[k][0]) ** 2 + (c["cy"] - centros[k][1]) ** 2)
        saida[nome].append(c)
    return saida


def recortar_mascara(rgba, mascara):
    """Recorte RGBA na caixa da mascara, com alfa so dentro dela."""
    ys, xs = np.nonzero(mascara)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    recorte = rgba[y0:y1, x0:x1].copy()
    recorte[..., 3] = np.where(mascara[y0:y1, x0:x1], recorte[..., 3], 0)
    return recorte


def reduzir(rgba, largura):
    """Reducao BOX premultiplicada para a largura alvo, alfa binario."""
    h, w = rgba.shape[:2]
    nh = max(1, int(round(h * largura / w)))
    im = Image.fromarray(rgba, "RGBA").convert("RGBa").resize((largura, nh), Image.BOX).convert("RGBA")
    out = np.asarray(im).copy()
    out[..., 3] = np.where(out[..., 3] >= LIMIAR_ALFA, 255, 0)
    return out


# ---------------------------------------------------------------- utilitarios de mascara

def erosao_contagem(mascara):
    """Distancia (Chebyshev) de cada pixel ate o fora da mascara: 1 na borda, cresce para o miolo."""
    d = np.zeros(mascara.shape, np.float32)
    atual = mascara.copy()
    h, w = mascara.shape
    while atual.any():
        d += atual
        p = np.pad(atual, 1, constant_values=False)
        nova = np.ones_like(atual)
        for dy in range(3):
            for dx in range(3):
                nova &= p[dy:dy + h, dx:dx + w]
        atual = nova
    return d


def caixa_media(a, r, modo="edge"):
    h, w = a.shape
    p = np.pad(a, r, mode=modo)
    soma = np.zeros((h, w), np.float32)
    for dy in range(2 * r + 1):
        for dx in range(2 * r + 1):
            soma += p[dy:dy + h, dx:dx + w]
    return soma / float((2 * r + 1) ** 2)


def sobel(h, modo="edge"):
    p = np.pad(h, 1, mode=modo)
    gx = (p[:-2, 2:] + 2 * p[1:-1, 2:] + p[2:, 2:] - p[:-2, :-2] - 2 * p[1:-1, :-2] - p[2:, :-2]) / 8.0
    gy = (p[2:, :-2] + 2 * p[2:, 1:-1] + p[2:, 2:] - p[:-2, :-2] - 2 * p[:-2, 1:-1] - p[:-2, 2:]) / 8.0
    return gx, gy


def luminancia(rgb):
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def furos(mascara):
    """Componentes do fundo da mascara cercados por ela (nao tocam a borda da imagem).
    Devolve lista de (ys, xs, anel_ys, anel_xs): o anel e o vizinho de 1 px (4 direcoes) fora do componente."""
    lab, comps = rotular(~mascara)
    h, w = mascara.shape
    saida = []
    for c in comps:
        if c["x0"] == 0 or c["y0"] == 0 or c["x1"] == w - 1 or c["y1"] == h - 1:
            continue
        if c["area"] > 4000:
            continue
        y0, y1 = c["y0"] - 1, c["y1"] + 2
        x0, x1 = c["x0"] - 1, c["x1"] + 2
        sub = lab[y0:y1, x0:x1] == c["id"]
        dil = sub.copy()
        dil[1:, :] |= sub[:-1, :]
        dil[:-1, :] |= sub[1:, :]
        dil[:, 1:] |= sub[:, :-1]
        dil[:, :-1] |= sub[:, 1:]
        anel = dil & ~sub
        ys, xs = np.nonzero(sub)
        ay, ax = np.nonzero(anel)
        saida.append((ys + y0, xs + x0, ay + y0, ax + x0))
    return saida


# ---------------------------------------------------------------- runas do circulo

def dilatar(m, passos=1):
    for _ in range(passos):
        p = np.pad(m, 1, constant_values=False)
        h, w = m.shape
        m = (p[1:h + 1, 1:w + 1] | p[0:h, 1:w + 1] | p[2:h + 2, 1:w + 1]
             | p[1:h + 1, 0:w] | p[1:h + 1, 2:w + 2])
    return m


def preencher_pedra(rgb, alfa, lum, regiao):
    """Cada pixel da regiao recebe a mediana dos vizinhos de pedra (janela 7x7, fora da regiao)."""
    h, w = alfa.shape
    boa = alfa & ~regiao & (lum >= LUM_HALO)
    for y, x in zip(*np.nonzero(regiao)):
        raio = 3
        while True:
            y0, y1 = max(0, y - raio), min(h, y + raio + 1)
            x0, x1 = max(0, x - raio), min(w, x + raio + 1)
            ok = boa[y0:y1, x0:x1]
            if ok.sum() >= 3 or (y0 == 0 and x0 == 0 and y1 == h and x1 == w):
                break
            raio += 2
        if ok.sum() < 1:
            continue
        rgb[y, x, :3] = np.round(np.median(rgb[y0:y1, x0:x1, :3][ok].astype(np.float32), axis=0)).astype(np.uint8)


def apagar_runas(rgb, alfa, relatorio=None):
    """Marcas escuras fechadas dentro da pedra (parecem letras) viram a cor da pedra em volta.
    Automatico: nucleo escuro (luminancia < LUM_NUCLEO) cercado por pedra clara (anel: mediana >= LUM_ANEL e
    10o percentil >= LUM_ANEL_MIN). Rejunte e terra escura nao passam (anel escuro). Manual: as CAIXAS_RUNAS, para
    marcas com nucleo fraco demais no sprite reduzido (conferidas ampliadas). A regiao apagada inclui o halo de
    antialias (2 px, so tons escuros). Muta `rgb`; devolve a mascara apagada."""
    lum = luminancia(rgb.astype(np.float32))
    h, w = alfa.shape
    nucleo = alfa & (lum < LUM_NUCLEO)
    lab, comps = rotular(nucleo)
    apagada = np.zeros_like(alfa)
    regioes = []
    for c in comps:
        if c["area"] < 6 or c["x0"] == 0 or c["y0"] == 0 or c["x1"] == w - 1 or c["y1"] == h - 1:
            continue
        nucl = lab == c["id"]
        anel = dilatar(nucl) & ~nucl
        valores = lum[anel]
        if np.median(valores) < LUM_ANEL or np.percentile(valores, 10) < LUM_ANEL_MIN:
            continue
        regioes.append(nucl)
    for x0, y0, x1, y1 in CAIXAS_RUNAS:
        caixa = np.zeros_like(alfa)
        caixa[y0:y1, x0:x1] = True
        regioes.append(caixa & alfa & (lum < LUM_NUCLEO_MANUAL))
    for nucl in regioes:
        if not nucl.any():
            continue
        regiao = nucl.copy()
        for _ in range(2):
            regiao = regiao | (dilatar(regiao) & alfa & (lum < LUM_HALO))
        preencher_pedra(rgb, alfa, lum, regiao)
        apagada |= regiao
        if relatorio is not None:
            ys, xs = np.nonzero(regiao)
            relatorio.append((int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()), int(regiao.sum())))
    return apagada


def normal_do_decalque(rgb, alfa, tipo):
    """Normal (RGBA uint8) de um decalque, em espaco de chao: domo por laje e por pedra, elevacao por tipo,
    passa-alta da luminancia, e a poca afundada e lisa."""
    p = TIPOS[tipo]
    h, w = alfa.shape
    lum = luminancia(rgb.astype(np.float32))
    dist_borda = erosao_contagem(alfa)
    altura = p["alt_borda"] * np.sqrt(np.minimum(dist_borda / float(p["raio_borda"]), 1.0))
    if p.get("pedras"):
        pedra = alfa & (lum > LUM_PEDRA)
        pedra |= alfa & furos_preenchidos(pedra)
        lab, comps = rotular(pedra)
        for c in comps:
            if c["area"] < 4:
                continue
            m = lab == c["id"]
            d = erosao_contagem(m)
            altura += np.where(m, ALT_PEDRA * np.sqrt(d / max(d.max(), 1.0)), 0.0)
    if p.get("agua"):
        mx = rgb.max(axis=2).astype(np.float32)
        mn = rgb.min(axis=2).astype(np.float32)
        agua = alfa & ((mx - mn) < SAT_AGUA) & (lum < LUM_AGUA)
        lab, comps = rotular(agua)
        if comps:
            maior = max(comps, key=lambda c: c["area"])
            m = lab == maior["id"]
            d = erosao_contagem(m)
            # afundada e lisa: rebaixo com borda suave, sem passa-alta
            rebaixo = -1.6 * np.sqrt(np.minimum(d / 6.0, 1.0))
            altura = np.where(m, rebaixo, altura)
    else:
        det = (lum - caixa_media(lum, 3)) / DIVISOR_DETALHE
        altura = altura + p["peso"] * det * alfa
    altura = np.where(alfa, altura, 0.0).astype(np.float32)
    gx, gy = sobel(altura)
    nx = -gx
    ny = gy
    m = np.sqrt(nx * nx + ny * ny + 1.0)
    nx, ny, nz = nx / m, ny / m, 1.0 / m
    nx, ny, nz = _suaviza(nx, alfa), _suaviza(ny, alfa), _suaviza(nz, alfa)
    m = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-9
    nx, ny, nz = nx / m, ny / m, nz / m
    out = np.zeros((h, w, 4), np.uint8)
    out[..., 0] = np.clip(np.round((nx * 0.5 + 0.5) * 255), 0, 255)
    out[..., 1] = np.clip(np.round((ny * 0.5 + 0.5) * 255), 0, 255)
    out[..., 2] = np.clip(np.round((nz * 0.5 + 0.5) * 255), 0, 255)
    out[..., 3] = np.where(alfa, 255, 0)
    out[~alfa, :3] = (128, 128, 255)
    return out


def _suaviza(a, alfa):
    """Media 3x3 so entre pixels opacos (a borda nao puxa para o vazio)."""
    h, w = a.shape
    p = np.pad(a * alfa, 1)
    q = np.pad(alfa.astype(np.float32), 1)
    soma = np.zeros((h, w), np.float32)
    n = np.zeros((h, w), np.float32)
    for dy in range(3):
        for dx in range(3):
            soma += p[dy:dy + h, dx:dx + w]
            n += q[dy:dy + h, dx:dx + w]
    return np.where(alfa, soma / np.maximum(n, 1.0), 0.0).astype(np.float32)


def furos_preenchidos(mascara):
    """Mascara dos furos pequenos cercados por `mascara` (preenche musgo dentro da pedra para o domo ficar liso)."""
    saida = np.zeros_like(mascara)
    for ys, xs, ay, ax in furos(mascara):
        if len(ys) <= AREA_FURO_PEDRA and mascara[ay, ax].all():
            saida[ys, xs] = True
    return saida


# ---------------------------------------------------------------- atlas e quantizacao

def empacotar(tamanhos):
    """Prateleiras: devolve [(x, y)] por tamanho (w, h) e o tamanho do atlas."""
    ordem = sorted(range(len(tamanhos)), key=lambda i: -tamanhos[i][1])
    pos = [None] * len(tamanhos)
    x = y = linha = 0
    for i in ordem:
        w, h = tamanhos[i]
        if x + w > LARGURA_ATLAS:
            x = 0
            y += linha + PAD
            linha = 0
        pos[i] = (x, y)
        x += w + PAD
        linha = max(linha, h)
    altura = y + linha
    return pos, (LARGURA_ATLAS, altura)


def quantizar(rgb, mascara, cores):
    """Paleta unica para os pixels opacos, mapeamento sem dithering."""
    amostra = rgb[mascara][:, :3].reshape(-1, 1, 3).astype(np.uint8)
    paleta = Image.fromarray(amostra, "RGB").quantize(colors=cores, method=Image.Quantize.MEDIANCUT,
                                                      dither=Image.Dither.NONE)
    q = Image.fromarray(rgb[..., :3].astype(np.uint8), "RGB").quantize(palette=paleta, dither=Image.Dither.NONE)
    return np.asarray(q.convert("RGB"))


# ---------------------------------------------------------------- chao candidato

def emenda(a):
    """Diferenca media entre pixels de lados opostos (wrap) comparada com a dos vizinhos internos."""
    return dict(
        borda_x=round(float(np.abs(a[:, 0] - a[:, -1]).mean()), 2),
        vizinhos_x=round(float(np.abs(a[:, 1:] - a[:, :-1]).mean()), 2),
        borda_y=round(float(np.abs(a[0] - a[-1]).mean()), 2),
        vizinhos_y=round(float(np.abs(a[1:] - a[:-1]).mean()), 2),
    )


def chao_ia(src):
    """8.webp: 1254 px -> 512 px, verificacao de emenda e correcao por mistura com deslocamento (quatro variantes).
    Devolve (RGB uint8 512x512, (costura antes, costura depois))."""
    im = Image.fromarray(src[..., :3], "RGB").resize((512, 512), Image.BOX)
    a = np.asarray(im).astype(np.float32)
    n = a.shape[0]
    antes = emenda(a)
    if antes["borda_x"] <= 1.5 * antes["vizinhos_x"] and antes["borda_y"] <= 1.5 * antes["vizinhos_y"]:
        return a.astype(np.uint8), (antes, antes)
    meio = n // 2
    s_xy = np.roll(a, (meio, meio), axis=(0, 1))
    s_x = np.roll(a, meio, axis=1)
    s_y = np.roll(a, meio, axis=0)
    t = np.arange(n)
    dist = np.minimum(t, n - 1 - t).astype(np.float32)
    faixa = 64.0
    wb = 0.5 * (1.0 + np.cos(np.pi * np.minimum(dist / faixa, 1.0)))
    wx_s = wb[None, :, None]
    wx_n = 1.0 - wx_s
    wy_s = wb[:, None, None]
    wy_n = 1.0 - wy_s
    out = wx_s * wy_s * s_xy + wx_s * wy_n * s_x + wx_n * wy_s * s_y + wx_n * wy_n * a
    saida = np.clip(np.round(out), 0, 255).astype(np.uint8)
    return saida, (antes, emenda(saida.astype(np.float32)))


def normal_chao(rgb):
    """Normal do chao em espaco de chao (mesma convencao do piso atual), com wrap (o quadro emenda)."""
    lum = luminancia(rgb.astype(np.float32))
    det = (lum - caixa_media(lum, 2, modo="wrap")) / DIVISOR_DETALHE
    gx, gy = sobel(det, modo="wrap")
    return gx, gy


def salvar_normal(gx, gy, k):
    nx = -k * gx
    ny = k * gy
    m = np.sqrt(nx * nx + ny * ny + 1.0)
    nx, ny, nz = nx / m, ny / m, 1.0 / m
    out = np.zeros(gx.shape + (3,), np.uint8)
    out[..., 0] = np.clip(np.round((nx * 0.5 + 0.5) * 255), 0, 255)
    out[..., 1] = np.clip(np.round((ny * 0.5 + 0.5) * 255), 0, 255)
    out[..., 2] = np.clip(np.round((nz * 0.5 + 0.5) * 255), 0, 255)
    return out


# ---------------------------------------------------------------- pipeline

def pecas_do_sheet(caminho):
    rgba = carregar(caminho)
    fundo = fundo_por_borda(rgba[..., 3])
    lab, comps = rotular(~fundo & (rgba[..., 3] > LIMITE_FUNDO))
    return rgba, lab, comps


def montar_decalques():
    decalques = {}   # nome -> (mascara bool no sheet, rgba do sheet, lab, ids)

    # sheet 1: 12 detalhes em grupos separados (gap de DIST_PEDACO)
    rgba, lab, comps = pecas_do_sheet(os.path.join(FONTES, "fonte_detalhes.webp"))
    grupos = [g for g in agrupar(comps, DIST_PEDACO) if sum(c["area"] for c in g) >= 40]
    assert len(grupos) == len(ORDEM_DETALHES), f"detalhes: {len(grupos)} grupos, esperado {len(ORDEM_DETALHES)}"

    def linha(g):
        return (sum(c["y0"] + c["y1"] for c in g) / (2.0 * len(g)))
    faixas = [g for g in sorted(grupos, key=linha)]
    linhas = [faixas[0:3], faixas[3:6], faixas[6:9], faixas[9:12]]
    ordenados = []
    for lg in linhas:
        ordenados += sorted(lg, key=lambda g: min(c["x0"] for c in g))
    for nome, g in zip(ORDEM_DETALHES, ordenados):
        ids = [c["id"] for c in perto_do_corpo(g, DIST_PEDACO)]
        decalques[nome] = (rgba, lab, ids)

    # sheet 2: 4 raizes (atribuicao pelo centro)
    rgba, lab, comps = pecas_do_sheet(os.path.join(FONTES, "fonte_raizes.webp"))
    grupos = atribuir_por_centro([c for c in comps if c["area"] >= 12], CENTROS_RAIZES)
    for nome, lista in grupos.items():
        ids = [c["id"] for c in perto_do_corpo(lista, DIST_PEDACO)]
        decalques[nome] = (rgba, lab, ids)

    # sheet 3: 3 trilhas
    rgba, lab, comps = pecas_do_sheet(os.path.join(FONTES, "fonte_trilhas.webp"))
    grupos = atribuir_por_centro([c for c in comps if c["area"] >= 12], CENTROS_TRILHAS)
    for nome, lista in grupos.items():
        ids = [c["id"] for c in perto_do_corpo(lista, DIST_PEDACO)]
        decalques[nome] = (rgba, lab, ids)

    # sheet 4: circulo
    rgba, lab, comps = pecas_do_sheet(os.path.join(FONTES, "fonte_circulo.webp"))
    ids = [c["id"] for c in perto_do_corpo([c for c in comps if c["area"] >= 12], DIST_PEDACO)]
    decalques["circulo"] = (rgba, lab, ids)
    return decalques


def iluminar(alb, nor):
    """Previa: luz quente de cima-esquerda com Lambert no normal, mais ambiente escuro (como o chao no jogo)."""
    n = nor.astype(np.float32) / 255.0 * 2.0 - 1.0
    m = np.sqrt((n * n).sum(axis=2)) + 1e-6
    n = n / m[..., None]
    luz = np.array([-0.5, 0.6, 0.62], np.float32)
    luz /= np.linalg.norm(luz)
    lam = np.clip((n * luz).sum(axis=2), 0.0, 1.0)
    ambiente = np.array([0.20, 0.24, 0.22], np.float32)
    cor = np.array([1.0, 0.86, 0.66], np.float32) * 0.95
    intensidade = ambiente + lam[..., None] * cor
    return np.clip(alb.astype(np.float32) * intensidade, 0, 255).astype(np.uint8)


def cena(chao_alb, chao_nor, pecas, pos):
    """Compoe o chao (lado a lado, repetido) e as pecas sobre ele. Devolve (albedo, normal) 960x540."""
    h, w = 540, 960
    ty = np.tile(chao_alb, (3, 3, 1))[:h, :w].copy()
    tn = np.tile(chao_nor, (3, 3, 1))[:h, :w].copy()
    for nome, (alb, nor, alfa) in pecas.items():
        x, y = pos[nome]
        hh, ww = alfa.shape
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(w, x + ww), min(h, y + hh)
        if x1 <= x0 or y1 <= y0:
            continue
        sel = alfa[y0 - y:y1 - y, x0 - x:x1 - x]
        ty[y0:y1, x0:x1][sel] = alb[y0 - y:y1 - y, x0 - x:x1 - x][sel]
        tn[y0:y1, x0:x1][sel] = nor[y0 - y:y1 - y, x0 - x:x1 - x][sel]
    return ty, tn


# posicoes (canto superior esquerdo) na cena de 960x540 da previa dos decalques
POSICOES_CENA = {
    "circulo": (110, 96),
    "trilha_reta": (555, 110),
    "trilha_diagonal": (790, 170),
    "trilha_curva": (40, 330),
    "raiz_longa": (560, 370),
    "raiz_forquilha": (780, 40),
    "raiz_no": (470, 245),
    "raiz_estrela": (160, 430),
    "folhas_1": (380, 470), "folhas_2": (670, 500), "folhas_3": (255, 330),
    "musgo_1": (780, 470), "musgo_2": (880, 360), "musgo_3": (20, 240),
    "pedrinhas_1": (20, 470), "pedrinhas_2": (420, 370), "poca": (880, 180),
    "galho_1": (840, 240), "galho_2": (340, 520), "grama": (580, 205),
}


def main():
    os.makedirs(SAIDA, exist_ok=True)
    os.makedirs(PRINTS, exist_ok=True)
    decalques = montar_decalques()
    print("decalques lidos:", len(decalques))

    recortes = {}
    for nome, (rgba, lab, ids) in decalques.items():
        mascara = np.isin(lab, ids)
        recortes[nome] = recortar_mascara(rgba, mascara)
    raizes = ("raiz_longa", "raiz_forquilha", "raiz_no", "raiz_estrela")
    media = float(np.mean([recortes[n].shape[1] for n in raizes]))
    alvos = dict(ALVO_LARGURA)
    for n in raizes:
        alvos[n] = int(round(recortes[n].shape[1] * LARGURA_MEDIA_RAIZES / media))
        assert 130 <= alvos[n] <= 190, (n, alvos[n])

    sprites = {}
    for nome in sorted(recortes):
        sprites[nome] = reduzir(recortes[nome], alvos[nome])

    runas = []
    # apagar_runas muta o RGB em vista (o sprite do circulo passa a ter as runas apagadas)
    apagar_runas(sprites["circulo"][..., :3], sprites["circulo"][..., 3] > 0, runas)
    print("runas apagadas (x0, y0, x1, y1, px):", runas)

    # normais e atlas
    nomes = sorted(sprites)
    pecas_nor = {}
    for nome in nomes:
        sp = sprites[nome]
        alfa = sp[..., 3] > 0
        pecas_nor[nome] = normal_do_decalque(sp[..., :3], alfa, TIPO_DE[nome])
    tamanhos = [(sprites[n].shape[1], sprites[n].shape[0]) for n in nomes]
    pos, (aw, ah) = empacotar(tamanhos)
    atlas = np.zeros((ah, aw, 4), np.uint8)
    atlas_nor = np.zeros((ah, aw, 4), np.uint8)
    atlas_nor[..., 0:2] = 128
    atlas_nor[..., 2] = 255
    for nome, (x, y) in zip(nomes, pos):
        sp = sprites[nome]
        h, w = sp.shape[:2]
        atlas[y:y + h, x:x + w] = sp
        atlas_nor[y:y + h, x:x + w] = pecas_nor[nome]
    alfa_atlas = atlas[..., 3] > 0
    quant = quantizar(atlas, alfa_atlas, CORES_ATLAS)
    atlas[..., :3] = quant
    atlas[..., :3][~alfa_atlas] = 0
    Image.fromarray(atlas, "RGBA").save(os.path.join(SAIDA, "decalques.png"))
    Image.fromarray(atlas_nor, "RGBA").save(os.path.join(SAIDA, "decalques_normal.png"))

    itens = []
    for nome, (x, y) in zip(nomes, pos):
        sp = sprites[nome]
        h, w = sp.shape[:2]
        ys, xs = np.nonzero(sp[..., 3] > 0)
        cx = int(round(xs.mean())) if len(xs) else w // 2
        cy = int(round(ys.mean())) if len(ys) else h // 2
        itens.append(dict(nome=nome, regiao=[x, y, w, h], centro=[min(cx, w - 1), min(cy, h - 1)]))
    with open(os.path.join(SAIDA, "decalques.json"), "w", encoding="utf-8") as f:
        json.dump(dict(atlas=[aw, ah], itens=itens), f, ensure_ascii=False, indent=1)
    for it in itens:
        print(f"{it['nome']:>16} regiao={it['regiao']} centro={it['centro']} tipo={TIPO_DE[it['nome']]}")
    print("atlas", aw, ah, "cores unicas:", len(np.unique(atlas[alfa_atlas][:, :3], axis=0)))

    # chao candidato
    chao_src = carregar(os.path.join(FONTES, "fonte_chao_ia.webp"))
    chao, (antes, depois) = chao_ia(chao_src)
    print("chao IA: costura antes", antes, "depois", depois)
    rgb_q = quantizar(chao, np.ones(chao.shape[:2], bool), CORES_CHAO)
    gx, gy = normal_chao(rgb_q)
    base = salvar_normal(gx, gy, 1.0)
    alvo_std = 13.0
    desvio = float(np.sqrt(((base[..., :2].astype(np.float32) - 128.0) ** 2).mean()))
    k = alvo_std / max(desvio, 1e-6)
    nor_chao = salvar_normal(gx, gy, k)
    print("chao IA: K do normal", round(k, 3), "std RG", np.round(nor_chao[..., :2].reshape(-1, 2).std(0), 1),
          "media", np.round(nor_chao.reshape(-1, 3).mean(0), 1))
    Image.fromarray(rgb_q, "RGB").save(os.path.join(PISO, "piso_ia.png"))
    Image.fromarray(nor_chao, "RGB").save(os.path.join(PISO, "piso_ia_normal.png"))

    # previas
    previa_decalques(atlas, atlas_nor, pos, nomes, sprites)
    previa_piso(rgb_q, nor_chao)


def previa_decalques(atlas, atlas_nor, pos, nomes, sprites):
    """Prévia: todos os decalques sobre o chão atual, em 960x540 (em cima) e um recorte ampliado 2x (embaixo)."""
    piso = np.asarray(Image.open(os.path.join(PISO, "piso.png")).convert("RGB"))
    piso_n = np.asarray(Image.open(os.path.join(PISO, "piso_normal.png")).convert("RGB"))
    pecas = {}
    for nome, (x, y) in zip(nomes, pos):
        h, w = sprites[nome].shape[:2]
        alfa = atlas[y:y + h, x:x + w, 3] > 0
        pecas[nome] = (atlas[y:y + h, x:x + w, :3], atlas_nor[y:y + h, x:x + w, :3], alfa)
    alb, nor = cena(piso, piso_n, pecas, POSICOES_CENA)
    fundo = Image.fromarray(iluminar(alb, nor), "RGB")
    zoom = fundo.crop((120, 100, 600, 370)).resize((960, 540), Image.NEAREST)
    quadro = Image.new("RGB", (960, 1080), (0, 0, 0))
    quadro.paste(fundo, (0, 0))
    quadro.paste(zoom, (0, 540))
    quadro.save(os.path.join(PRINTS, "prototipo_decalques.png"))


def previa_piso(rgb_q, nor_chao):
    piso = np.asarray(Image.open(os.path.join(PISO, "piso.png")).convert("RGB"))
    piso_n = np.asarray(Image.open(os.path.join(PISO, "piso_normal.png")).convert("RGB"))
    lados = []
    for alb, nor, rotulo in ((piso, piso_n, "ATUAL piso.png"), (rgb_q, nor_chao, "CANDIDATO 8.webp")):
        bloco = np.tile(alb, (2, 2, 1))
        bloco_n = np.tile(nor, (2, 2, 1))
        recorte = bloco[242:782, 0:960]
        recorte_n = bloco_n[242:782, 0:960]
        lit = iluminar(recorte, recorte_n)
        im = Image.fromarray(lit, "RGB")
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 260, 22), fill=(0, 0, 0))
        d.text((8, 6), rotulo, fill=(240, 230, 200))
        lados.append(im)
    quadro = Image.new("RGB", (1920, 540))
    quadro.paste(lados[0], (0, 0))
    quadro.paste(lados[1], (960, 0))
    quadro.save(os.path.join(PRINTS, "prototipo_piso_ia_vs_atual.png"))


if __name__ == "__main__":
    main()

"""Gera a folha de enfeites da cara nova (vegetacao + pedras e ruinas) para o protototipo 2.5D.

Entrada (ao lado deste script, com fundo branco/transparente):
    fonte_vegetacao.webp   9 objetos em 2 linhas (5 + 4)
    fonte_pedras.webp      14 objetos em 3 linhas (5 + 5 + 4)
    fonte_santuario.webp   5 objetos em 1 linha (torii, torii quebrado, braseiro, fogueira, caixa de oferenda)

Saida, em jogos/hordas/projeto/prototipos/objetos/ (mesmo layout nas duas folhas):
    enfeites.png           albedo: cor chapada, alfa binario, contorno escuro de 1 px
    enfeites_normal.png    normal map (R = x, G = y para cima, B = z), mesma convencao do gerar_cara_nova.py
    cenario.json           itens com nome, peso, pe (base dentro da regiao), regiao [x, y, w, h] e colisao
                           (elipses relativas ao pe; lista vazia = atravessavel)
    as previas em jogos/hordas/prints/prototipo_objetos_novos.png e v2_colisao_formas.png (elipses por cima)

Uso (so precisa de Pillow):
    python gerar_objetos.py           enfeites e pedras da cara nova (prototipo)
    python gerar_objetos.py armas     sprites das armas da v2 (fonte_armas_*.webp) -> projeto/assets/v2/armas/

Passos: fundo = alfa 0 (ou branco) ligado a borda, por flood fill; objetos = componentes do que sobrou,
juntados por proximidade; ordem = linha e coluna; BOX para a escala do jogo; alfa binario a 50%;
quantizacao sem dithering; normal = domo pela distancia ate a borda + um pouco da luminancia.
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
HORDAS = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
SAIDA = os.path.join(HORDAS, "projeto", "prototipos", "objetos")
PREVIA = os.path.join(HORDAS, "prints", "prototipo_objetos_novos.png")
PREVIA_COLISAO = os.path.join(HORDAS, "prints", "v2_colisao_formas.png")

# ------------------------------------------------------------------ escolhas de arte
# (nome, eixo do alvo, tamanho alvo em px no jogo 960x540, peso do cenario)
# eixo "A" = altura do alvo; "L" = largura do alvo. A ordem e a de linha e coluna da imagem.
FOLHAS = [
    ("fonte_vegetacao.webp", [5, 4], [
        ("arvore", "A", 150, 1),
        ("arvore_pantano", "A", 130, 2),
        ("arvore_morta", "A", 105, 2),
        ("toco", "A", 40, 3),
        ("tronco", "L", 75, 2),
        ("arbusto", "L", 48, 4),
        ("cogumelos", "A", 20, 2),
        ("juncos", "A", 44, 3),
        ("raizes", "L", 55, 2),
    ]),
    ("fonte_pedras.webp", [5, 5, 4], [
        ("pedra", "L", 46, 2),
        ("rocha", "A", 44, 2),
        ("pedras", "L", 22, 3),
        ("coluna", "A", 56, 2),
        ("pilar", "A", 88, 1),
        ("obelisco", "A", 92, 1),
        ("pedestal", "A", 50, 2),
        ("muro", "L", 66, 2),
        ("runa", "A", 38, 1),
        ("lapide", "A", 28, 1),
        ("poste_lanterna", "A", 62, 1),
        ("toro", "A", 56, 1),
        ("altar", "L", 46, 1),
        ("cranio", "L", 36, 1),
    ]),
    ("fonte_santuario.webp", [5], [
        ("torii", "A", 165, 1),
        ("torii_quebrado", "A", 140, 1),
        ("braseiro", "A", 62, 2),
        ("fogueira", "L", 58, 2),
        ("caixa_oferenda", "L", 36, 2),
    ]),
]

# Ponto da chama dos objetos com fogo: fracao (x, y) do sprite, o centro da lenha. Vai ao cenario.json como "fogo".
FOGO = {"braseiro": (0.5, 0.22), "fogueira": (0.48, 0.44)}
FRACAO_PILAR = 0.75      # linha (fracao da altura) em que o torii so tem os dois pilares: vigas, pano e corda ficam acima

LIMITE_FUNDO = 12        # alfa <= isto conta como fundo (ruido de compressao)
MIN_RUIDO = 12           # pedacos com menos pixels que isto sao descartados
GAP_JUNTA = 6            # pedacos cujas caixas ficam a menos disto (px da fonte) viram o mesmo objeto
LIMIAR_ALFA = 128        # alfa binario: 50%
COR_MAX = 40             # cores da folha toda (albedo)
LARGURA_FOLHA = 480      # largura maxima da folha em px (empacotamento em prateleiras)
PAD = 2                  # espaco entre sprites na folha
INCLINA = 1.0           # ganho do gradiente (Sobel) da altura -> normal
ALTURA_DOMO = 4.0        # altura do domo na borda: sqrt(distancia / raio), ~55 graus na borda
BOJO_AMPLO = 10.0        # bojo amplo (metade do menor lado): o corpo inteiro inclina, e o lado da luz muda
PESO_DETALHE = 8.0       # peso do passa-alta da luminancia (casca, tufos, tijolos, rachaduras)
RAIO_DOMO = 0.25         # raio do domo = fracao do menor lado do objeto...
RAIO_MIN, RAIO_MAX = 6.0, 10.0   # ...limitado entre 6 e 10 px
RAIO_HP = 3              # raio do borrao do passa-alta (albedo menos borrao)
AMB_PREVIA = 0.25        # ambiente da previa (Lambert + ambiente)
COR_QUENTE = (1.0, 0.86, 0.66)   # cor da luz quente da previa
LUM_CONTORNO = 60        # borda com luminancia acima disto ganha contorno escuro
AMBIENTE = [0.6, 0.7, 0.62]


# ------------------------------------------------------------------ leitura e fundo
def carregar(caminho):
    im = Image.open(caminho).convert("RGBA")
    return im.width, im.height, im.tobytes()


def fundo_por_borda(w, h, alfa):
    """Flood fill a partir das bordas: marca como fundo o que e transparente (ou branco) e encosta na borda."""
    fundo = bytearray(w * h)
    pilha = []

    def semente(i):
        if alfa[i] <= LIMITE_FUNDO and not fundo[i]:
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
        for j in ((i - w) if y > 0 else -1, (i + w) if y < h - 1 else -1,
                  (i - 1) if x > 0 else -1, (i + 1) if x < w - 1 else -1):
            if j >= 0 and not fundo[j] and alfa[j] <= LIMITE_FUNDO:
                fundo[j] = 1
                pilha.append(j)
    return fundo


def componentes(w, h, mascara):
    """Componentes conectados (8 vizinhos) de uma mascara 0/1. Devolve listas de indices."""
    visto = bytearray(w * h)
    comps = []
    for s in range(w * h):
        if not mascara[s] or visto[s]:
            continue
        visto[s] = 1
        pilha = [s]
        idx = []
        while pilha:
            i = pilha.pop()
            idx.append(i)
            y, x = divmod(i, w)
            for dy in (-1, 0, 1):
                ny = y + dy
                if not 0 <= ny < h:
                    continue
                for dx in (-1, 0, 1):
                    nx = x + dx
                    if 0 <= nx < w:
                        j = ny * w + nx
                        if mascara[j] and not visto[j]:
                            visto[j] = 1
                            pilha.append(j)
        comps.append(idx)
    return comps


def caixa(idx, w):
    xs = [i % w for i in idx]
    ys = [i // w for i in idx]
    return (min(xs), min(ys), max(xs), max(ys))


def dist_caixas(a, b):
    dx = max(0, max(a[0], b[0]) - min(a[2], b[2]))
    dy = max(0, max(a[1], b[1]) - min(a[3], b[3]))
    return max(dx, dy)


def agrupar(w, h, data, nome_folha, esperado, linhas, por_centro=False, gap=GAP_JUNTA, juntar_caixas=True):
    alfa = data[3::4]
    fundo = fundo_por_borda(w, h, alfa)
    fg = bytearray(w * h)
    for i in range(w * h):
        if not fundo[i] and alfa[i] > LIMITE_FUNDO:
            fg[i] = 1
    ruido_descartado = 0
    pedacos = []
    for idx in componentes(w, h, fg):
        if len(idx) < MIN_RUIDO:
            ruido_descartado += len(idx)
            continue
        pedacos.append({"idx": idx, "caixa": caixa(idx, w), "area": len(idx)})
    # junta pedacos com caixas proximas (um objeto pode ter partes soltas)
    grupos = [dict(p, idx=list(p["idx"])) for p in pedacos]
    # Folhas densas podem ter caixas sobrepostas sem pixels conectados. Nesse caso,
    # preserva componentes completos; apenas fragmentos excedentes vao ao mais proximo.
    mudou = juntar_caixas
    while mudou:
        mudou = False
        for a in range(len(grupos)):
            for b in range(a + 1, len(grupos)):
                if dist_caixas(grupos[a]["caixa"], grupos[b]["caixa"]) <= gap:
                    _fundir(grupos, a, b, w)
                    mudou = True
                    break
            if mudou:
                break
    # se sobrou mais pedaco que objeto, o menor vai para o objeto mais proximo
    while len(grupos) > esperado:
        menor = min(range(len(grupos)), key=lambda k: grupos[k]["area"])
        prox = min((k for k in range(len(grupos)) if k != menor),
                   key=lambda k: dist_caixas(grupos[menor]["caixa"], grupos[k]["caixa"]))
        print("  [%s] pedaco de %d px (caixa %s) juntado ao objeto mais proximo" % (
            nome_folha, grupos[menor]["area"], grupos[menor]["caixa"]))
        _fundir(grupos, prox, menor, w)
    if len(grupos) < esperado:
        raise SystemExit("%s: achei %d objetos, esperava %d" % (nome_folha, len(grupos), esperado))
    if por_centro:
        # folha sem faixas limpas entre as linhas (particulas de uma linha tocam a outra): ordena pelo centro
        # vertical e corta pelas contagens de cada linha; dentro da linha, da esquerda para a direita
        grupos.sort(key=lambda g: g["caixa"][1] + g["caixa"][3])
        ordenados, inicio = [], 0
        for n in linhas:
            ordenados.extend(sorted(grupos[inicio:inicio + n], key=lambda g: g["caixa"][0] + g["caixa"][2]))
            inicio += n
        print("%s: %d objetos em %d linhas (pelo centro), ruido descartado %d px" % (
            nome_folha, len(ordenados), len(linhas), ruido_descartado))
        return ordenados
    # linhas: intervalos verticais que se sobrepoem ficam na mesma linha
    grupos.sort(key=lambda g: g["caixa"][1])
    fileiras, atual, fim = [], [], -1
    for g in grupos:
        if atual and g["caixa"][1] > fim:
            fileiras.append(atual)
            atual, fim = [], -1
        atual.append(g)
        fim = max(fim, g["caixa"][3])
    fileiras.append(atual)
    if [len(f) for f in fileiras] != linhas:
        raise SystemExit("%s: linhas %s, esperava %s" % (nome_folha, [len(f) for f in fileiras], linhas))
    ordenados = []
    for f in fileiras:
        ordenados.extend(sorted(f, key=lambda g: (g["caixa"][0] + g["caixa"][2])))
    print("%s: %d objetos em %d linhas, ruido descartado %d px" % (nome_folha, len(ordenados), len(fileiras), ruido_descartado))
    return ordenados


def _fundir(grupos, a, b, w):
    ga, gb = grupos[a], grupos[b]
    ga["idx"].extend(gb["idx"])
    ga["area"] += gb["area"]
    x0 = min(ga["caixa"][0], gb["caixa"][0])
    y0 = min(ga["caixa"][1], gb["caixa"][1])
    x1 = max(ga["caixa"][2], gb["caixa"][2])
    y1 = max(ga["caixa"][3], gb["caixa"][3])
    ga["caixa"] = (x0, y0, x1, y1)
    del grupos[b]


# ------------------------------------------------------------------ recorte, escala e contorno
def recortar(grupo, w, data):
    x0, y0, x1, y1 = grupo["caixa"]
    bw, bh = x1 - x0 + 1, y1 - y0 + 1
    out = bytearray(bw * bh * 4)
    for i in grupo["idx"]:
        y, x = divmod(i, w)
        j = ((y - y0) * bw + (x - x0)) * 4
        out[j:j + 4] = data[i * 4:i * 4 + 4]
    return Image.frombytes("RGBA", (bw, bh), bytes(out))


def escalar(img, eixo, alvo):
    bw, bh = img.size
    s = alvo / float(bh if eixo == "A" else bw)
    nw = max(1, round(bw * s))
    nh = max(1, round(bh * s))
    return img.resize((nw, nh), Image.BOX)


def binarizar(img, limiar=LIMIAR_ALFA):
    w, h = img.size
    dados = bytearray(img.tobytes())
    for i in range(w * h):
        j = i * 4
        if dados[j + 3] < limiar:
            dados[j:j + 4] = b"\x00\x00\x00\x00"
        else:
            dados[j + 3] = 255
    return Image.frombytes("RGBA", (w, h), bytes(dados))


def contorno(img):
    """Borda opaca que nao e escura ganha contorno de 1 px (cor escura da propria cor)."""
    w, h = img.size
    dados = bytearray(img.tobytes())
    alfa = dados[3::4]

    def opaco(x, y):
        return 0 <= x < w and 0 <= y < h and alfa[y * w + x] == 255

    pintar = []
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if alfa[i] != 255:
                continue
            if opaco(x - 1, y) and opaco(x + 1, y) and opaco(x, y - 1) and opaco(x, y + 1):
                continue
            j = i * 4
            r, g, b = dados[j], dados[j + 1], dados[j + 2]
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if lum > LUM_CONTORNO:
                pintar.append((j, int(r * 0.3), int(g * 0.3), int(b * 0.3)))
    for j, r, g, b in pintar:
        dados[j], dados[j + 1], dados[j + 2] = r, g, b
    return Image.frombytes("RGBA", (w, h), bytes(dados))


def pe_do_objeto(img):
    """Pe = pixel opaco da base mais perto do centro da base (as duas ultimas linhas opacas)."""
    w, h = img.size
    alfa = img.tobytes()[3::4]
    ultima = max(y for y in range(h) if any(alfa[y * w + x] for x in range(w)))
    xs = [x for y in range(max(0, ultima - 1), ultima + 1) for x in range(w) if alfa[y * w + x]]
    media = sum(xs) / float(len(xs))
    px = min(xs, key=lambda x: abs(x - media))
    py = max(y for y in range(h) if alfa[y * w + px])
    return [px, py]


def _trechos(alfa, w, y):
    """Trechos opacos de uma linha: lista de (x0, x1), inclusive."""
    trechos, ini = [], None
    for x in range(w + 1):
        on = x < w and alfa[y * w + x] > 0
        if on and ini is None:
            ini = x
        elif not on and ini is not None:
            trechos.append((ini, x - 1))
            ini = None
    return trechos


def pilares_do_portal(img):
    """Os dois pilares do torii: as duas faixas opacas mais largas da linha FRACAO_PILAR (ali so ha pilar).
    Devolve [(x0, x1), ...] e a base de cada pilar (ultima linha opaca da faixa)."""
    w, h = img.size
    alfa = img.tobytes()[3::4]
    y = int(FRACAO_PILAR * h)
    pilares = sorted(sorted(_trechos(alfa, w, y), key=lambda f: f[1] - f[0], reverse=True)[:2])
    if len(pilares) != 2:
        raise SystemExit("torii: achei %d pilares na linha %d, esperava 2" % (len(pilares), y))

    def base_da_coluna(x):
        for yy in range(h - 1, -1, -1):
            if alfa[yy * w + x]:
                return yy
        return -1

    bases = [max(base_da_coluna(x) for x in range(a, b + 1)) for a, b in pilares]
    return pilares, bases


def pe_do_portal(img):
    """Torii: pe = meio entre os dois pilares, na base. pe = meio dos centros; y = media das duas bases."""
    pilares, bases = pilares_do_portal(img)
    cx = [(a + b) / 2.0 for a, b in pilares]
    print("      pilares: colunas %s, bases y %s" % (pilares, bases))
    return [int(round(sum(cx) / 2.0)), int(round(sum(bases) / 2.0))]


# ------------------------------------------------------------------ colisao (formas relativas ao pe)
# Solido = elipses no chao, em px do jogo e relativas ao pe. A pegada e a base do objeto (linhas opacas de baixo,
# perto do pe), vista a 45 graus: ry = 0,5 * rx, e a borda de baixo da elipse encosta no pe.
# Objeto que nao estiver em nenhum dos dois conjuntos faz a geracao parar: classifique o novo aqui.
SOLIDOS = {
    "arvore", "arvore_pantano", "arvore_morta", "toco", "tronco", "pedra", "rocha", "pedras", "coluna", "pilar",
    "obelisco", "pedestal", "muro", "runa", "lapide", "poste_lanterna", "toro", "altar", "braseiro", "fogueira",
    "caixa_oferenda", "cranio", "torii", "torii_quebrado",
}
PASSAVEIS = {"arbusto", "cogumelos", "juncos", "raizes"}
COLISAO_FRACAO_BASE = 0.10   # faixa de base = fracao da altura do sprite...
COLISAO_MIN_LINHAS = 4       # ...limitada a este intervalo de linhas
COLISAO_MAX_LINHAS = 12
# Base arredondada (a linha do pe e a mais estreita, e o corpo largo fica uns px acima): faixa mais funda.
COLISAO_FRACAO_ESPECIAL = {"fogueira": 0.30, "caixa_oferenda": 0.30, "lapide": 0.50, "cranio": 0.50}
# Arvores, tocos e tronco caido: a PEGADA cobre a base visual inteira (tronco, raizes principais, faixa do chao),
# com todos os pixels opacos das COLISAO_LINHAS_BASE linhas de baixo (pe incluso), trechos separados das raizes incluidos.
PEGADA = {"arvore", "arvore_pantano", "arvore_morta", "toco", "tronco"}
COLISAO_LINHAS_BASE = 12     # a faixa visual que o corpo nao pode invadir (o mesmo corte do teste v2_arvores)
COLISAO_RAIO_CIRCULO = 16.0  # raio maximo de um circulo da pegada: base mais larga que 2x isto vira mais de um circulo
COLISAO_LARGA = {"muro"}     # objeto longo: uma elipse larga cobre o trecho de base (lisa: sem quina)
COLISAO_RX_MIN = 3.0         # raio minimo em x (poste fino ainda ganha um disco)
COLISAO_RY_RX = 0.5          # ry = 0,5 * rx


def _mediana(v):
    v = sorted(v)
    n = len(v)
    return v[n // 2] if n % 2 else (v[n // 2 - 1] + v[n // 2]) / 2.0


def _percentil(v, q):
    """Valor de ordem q (0 a 1) de uma lista: com q = 0,75 o raio nao cai na quina da base."""
    v = sorted(v)
    return v[int(round(q * (len(v) - 1)))]


def _faixa_de_base(img, pe, nome):
    """Linhas opacas de baixo, perto do pe. Em cada linha, o trecho opaco mais perto do pe.
    Devolve [(dy, x0, x1), ...] relativos ao pe, da linha do pe para cima."""
    w, h = img.size
    alfa = img.tobytes()[3::4]
    px, py = pe
    if nome in COLISAO_FRACAO_ESPECIAL:
        n = max(1, int(round(COLISAO_FRACAO_ESPECIAL[nome] * h)))
    else:
        n = max(COLISAO_MIN_LINHAS, min(COLISAO_MAX_LINHAS, int(round(COLISAO_FRACAO_BASE * h))))
    faixa = []
    for y in range(py, max(-1, py - n), -1):
        trechos = _trechos(alfa, w, y)
        if not trechos:
            continue
        l, r = min(trechos, key=lambda t: max(0, t[0] - px, px - t[1]))
        faixa.append((y - py, l - px, r - px))
    if not faixa:
        raise SystemExit("colisao: nenhuma linha opaca perto do pe %s" % (pe,))
    return faixa


def _forma(dx, dy_base, rx):
    """Elipse com a borda de baixo em dy_base (relativo ao pe) e centro logo acima dela."""
    ry = COLISAO_RY_RX * rx
    return {"tipo": "elipse", "centro": [round(dx, 1), round(dy_base - ry, 1)], "raio": [round(rx, 1), round(ry, 1)]}


def _elipse_da_base(img, pe, nome):
    """Um disco com a borda de baixo no pe. Raio = percentil 75 da metade da largura da faixa; centro = mediana
    do meio da faixa. O percentil 75 tira a raiz que abre na base da arvore, e a mediana, a quina."""
    faixa = _faixa_de_base(img, pe, nome)
    rx = max(COLISAO_RX_MIN, _percentil([(r - l + 1) / 2.0 for _, l, r in faixa], 0.75))
    return [_forma(_mediana([(l + r) / 2.0 for _, l, r in faixa]), 0.0, rx)]


def _elipse_larga(img, pe, nome):
    """Objeto longo (muro, tronco deitado): uma elipse que cobre o trecho de base todo. Uma so e lisa, sem quina
    entre duas: o corpo desliza ao longo dela. A borda de baixo fica na linha mais baixa de corpo largo
    (>= 80% da maior largura da faixa), que nem sempre e o pe."""
    faixa = _faixa_de_base(img, pe, nome)
    esq = min(l for _, l, _r in faixa)
    dir_ = max(r for _, _l, r in faixa)
    maior = max(r - l + 1 for _, l, r in faixa)
    base = max(dy for dy, l, r in faixa if r - l + 1 >= 0.8 * maior)
    rx = max(COLISAO_RX_MIN, (dir_ - esq + 1) / 2.0)
    return [_forma((esq + dir_) / 2.0, base, rx)]


def _elipses_do_torii(img, pe):
    """Torii: uma elipse em cada pilar, na base de cada um. O vao entre elas e a passagem."""
    pilares, bases = pilares_do_portal(img)
    return [_forma((a + b) / 2.0 - pe[0], base + 1 - pe[1], max(COLISAO_RX_MIN, (b - a + 1) / 2.0))
            for (a, b), base in zip(pilares, bases)]


def _circulo_minimo(pontos):
    """Menor circulo que cobre os pontos (Welzl iterativo; ordem embaralhada com semente fixa). Devolve (cx, cy, r)."""
    import random
    P = list(pontos)
    random.Random(7).shuffle(P)

    def dist(a, b):
        return math.hypot(a[0] - b[0], a[1] - b[1])

    def circ2(a, b):
        return ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0, dist(a, b) / 2.0)

    def circ3(a, b, c):
        ax, ay = a
        bx, by = b
        cx, cy = c
        d = 2.0 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
        if abs(d) < 1e-9:  # colineares: o circulo do par mais afastado cobre os tres
            return max((circ2(a, b), circ2(b, c), circ2(a, c)), key=lambda t: t[2])
        a2, b2, c2 = ax * ax + ay * ay, bx * bx + by * by, cx * cx + cy * cy
        ux = (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / d
        uy = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d
        return (ux, uy, dist((ux, uy), a))

    def dentro(c, p):
        return dist((c[0], c[1]), p) <= c[2] + 1e-7

    c = None
    for i, p in enumerate(P):
        if c is None or not dentro(c, p):
            c = (p[0], p[1], 0.0)
            for j in range(i):
                q = P[j]
                if not dentro(c, q):
                    c = circ2(p, q)
                    for k in range(j):
                        r = P[k]
                        if not dentro(c, r):
                            c = circ3(p, q, r)
    return c


def _pegada_de_base(img, pe, nome):
    """Pegada da arvore, do toco e do tronco caido: a base visual inteira, no chao.

    Os pontos sao os pixels opacos das COLISAO_LINHAS_BASE linhas de baixo (pe incluso), em (x, 2 * dy): o chao do
    corpo, que e a escala em que a elipse vira circulo (ry = rx / 2, a base vista a 45 graus). Quando a base e larga
    (raizes que se abrem), ela e dividida em faixas de no maximo 2 * COLISAO_RAIO_CIRCULO, e cada faixa ganha o menor
    circulo que cobre os seus pontos. Assim nenhum pixel visual da base fica de fora: o corpo para a r px de qualquer um.
    """
    w, h = img.size
    alfa = img.tobytes()[3::4]
    px, py = pe
    pontos = []
    for dy in range(0, -COLISAO_LINHAS_BASE, -1):
        y = py + dy
        if not 0 <= y < h:
            continue
        for x in range(w):
            if alfa[y * w + x]:
                pontos.append((float(x - px), 2.0 * dy))
    if not pontos:
        raise SystemExit("pegada: %s sem pixel opaco na base (pe %s)" % (nome, pe))
    x0 = min(p[0] for p in pontos)
    largura = max(p[0] for p in pontos) - x0 + 1.0
    k = max(1, int(math.ceil(largura / (2.0 * COLISAO_RAIO_CIRCULO))))
    faixas = [[] for _ in range(k)]
    for p in pontos:
        faixas[min(k - 1, int((p[0] - x0) / (largura / k)))].append(p)
    formas = []
    for faixa in faixas:
        cx, cy, r = _circulo_minimo(faixa)
        # arredondado para o json (centro a 0,1 px, raio com 0,1 px de folga para o arredondamento nao deixar ponto de fora)
        cx_j, cy_j = round(cx, 1), round(cy / 2.0, 1)
        # raio para cima, com 0,1 px de folga, num multiplo de 0,2: ry = rx / 2 sai exato com uma casa decimal
        r_j = round(math.ceil((max(r, COLISAO_RX_MIN) + 0.1) / 0.2 - 1e-9) * 0.2, 1)
        ry_j = round(r_j * COLISAO_RY_RX, 1)
        # confere com os numeros que vao ao json, na mesma conta do resolver (y * rx / ry): todo pixel da faixa cabe
        k = r_j / ry_j
        pior = max(dist_ponto((p[0], p[1] / 2.0 * k), cx_j, cy_j * k) for p in faixa) - r_j
        if pior > 1e-6:
            raise SystemExit("pegada: %s, ponto fora do circulo por %.3f px" % (nome, pior))
        formas.append({"tipo": "elipse", "centro": [cx_j, cy_j], "raio": [r_j, ry_j]})
    return formas


def dist_ponto(p, cx, cy):
    return math.hypot(p[0] - cx, p[1] - cy)


def formas_de_colisao(nome, img, pe):
    if nome in PASSAVEIS:
        return []
    if nome not in SOLIDOS:
        raise SystemExit("colisao: %s nao esta em SOLIDOS nem em PASSAVEIS" % nome)
    if nome.startswith("torii"):
        return _elipses_do_torii(img, pe)
    if nome in PEGADA:
        return _pegada_de_base(img, pe, nome)
    if nome in COLISAO_LARGA:
        return _elipse_larga(img, pe, nome)
    return _elipse_da_base(img, pe, nome)


def previa_colisao(folha, pos, sprites, caminho):
    """Folha de albedo em 2x, com as elipses de colisao por cima e um ponto verde no pe."""
    ESC = 2
    fundo = (0x5a, 0x5a, 0x64, 255)
    tela = Image.new("RGBA", (folha.width * ESC, folha.height * ESC), fundo)
    tela.alpha_composite(folha.resize((folha.width * ESC, folha.height * ESC), Image.NEAREST))
    camada = Image.new("RGBA", tela.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)
    fonte = ImageFont.load_default(size=11)
    for (x, y), (nome, _peso, _alb, _nor, pe, formas) in zip(pos, sprites):
        for f in formas:
            cx = (x + pe[0] + f["centro"][0]) * ESC
            cy = (y + pe[1] + f["centro"][1]) * ESC
            rx, ry = f["raio"][0] * ESC, f["raio"][1] * ESC
            d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(255, 40, 40, 90), outline=(255, 40, 40, 255), width=1)
        ox, oy = (x + pe[0]) * ESC, (y + pe[1]) * ESC
        d.ellipse([ox - 2, oy - 2, ox + 2, oy + 2], fill=(60, 255, 120, 255))
        d.rectangle([x * ESC, y * ESC, x * ESC + 6 * len(nome), y * ESC + 12], fill=(0, 0, 0, 170))
        d.text((x * ESC + 2, y * ESC), nome, fill=(255, 255, 255, 255), font=fonte)
    tela = Image.alpha_composite(tela, camada)
    tela.convert("RGB").save(caminho)


# ------------------------------------------------------------------ normal map
def _borrao(vals, w, h, r):
    """Borrao de caixa de raio r (separado em x e y). Bordas usam so os vizinhos que existem."""
    tmp = [0.0] * (w * h)
    for y in range(h):
        for x in range(w):
            ks = range(max(0, x - r), min(w, x + r + 1))
            tmp[y * w + x] = sum(vals[y * w + k] for k in ks) / len(ks)
    out = [0.0] * (w * h)
    for y in range(h):
        for x in range(w):
            ks = range(max(0, y - r), min(h, y + r + 1))
            out[y * w + x] = sum(tmp[k * w + x] for k in ks) / len(ks)
    return out


def _distancia(alfa, w, h):
    """Distancia (aprox. euclidiana, chamfer 3-4) de cada pixel opaco ate o pixel transparente mais perto."""
    INF = 1e9
    d = [0.0 if a == 0 else INF for a in alfa]
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if d[i] == 0.0:
                continue
            v = d[i]
            if x > 0:
                v = min(v, d[i - 1] + 1.0)
            if y > 0:
                v = min(v, d[i - w] + 1.0)
                if x > 0:
                    v = min(v, d[i - w - 1] + 1.414)
                if x < w - 1:
                    v = min(v, d[i - w + 1] + 1.414)
            d[i] = v
    for y in range(h - 1, -1, -1):
        for x in range(w - 1, -1, -1):
            i = y * w + x
            v = d[i]
            if x < w - 1:
                v = min(v, d[i + 1] + 1.0)
            if y < h - 1:
                v = min(v, d[i + w] + 1.0)
                if x < w - 1:
                    v = min(v, d[i + w + 1] + 1.414)
                if x > 0:
                    v = min(v, d[i + w - 1] + 1.414)
            d[i] = v
    return d


def normal_do_objeto(img):
    """Altura = domo (sqrt da distancia ate a borda do alfa) + passa-alta da luminancia (textura).
    Normal pelo Sobel dessa altura. Borda do alfa: sem passa-alta (nada de faixa do contorno), e o
    domo cai a zero na borda, entao a normal vira inclinada e continua, sem degrau. 1 passe 3x3."""
    w0, h0 = img.size
    base = Image.new("RGBA", (w0 + 4, h0 + 4), (0, 0, 0, 0))
    base.paste(img, (2, 2))
    w, h = base.size
    dados = base.tobytes()
    alfa = dados[3::4]
    n = w * h
    opaco = [1.0 if a else 0.0 for a in alfa]
    d = _distancia(alfa, w, h)
    raio = max(RAIO_MIN, min(RAIO_MAX, RAIO_DOMO * min(w0, h0)))
    dmax_amplo = max(1.0, 0.5 * min(w0, h0))
    lum = [0.0] * n
    for i in range(n):
        if alfa[i]:
            j = i * 4
            lum[i] = (0.299 * dados[j] + 0.587 * dados[j + 1] + 0.114 * dados[j + 2]) / 255.0
    borr_num = _borrao([lum[i] * opaco[i] for i in range(n)], w, h, RAIO_HP)
    borr_den = _borrao(opaco, w, h, RAIO_HP)
    H = [0.0] * n
    for i in range(n):
        if not alfa[i]:
            continue
        t = min(d[i] / raio, 1.0)
        hp = 0.0
        if d[i] > 1.5 and borr_den[i] > 0:
            hp = lum[i] - borr_num[i] / borr_den[i]
        bojo = BOJO_AMPLO * math.sqrt(min(d[i] / dmax_amplo, 1.0))
        H[i] = ALTURA_DOMO * math.sqrt(t) + bojo + PESO_DETALHE * hp

    def hh(x, y):
        return H[y * w + x] if 0 <= x < w and 0 <= y < h else 0.0

    NX = [0.0] * n
    NY = [0.0] * n
    NZ = [1.0] * n
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if not alfa[i]:
                continue
            gx = (hh(x + 1, y - 1) + 2 * hh(x + 1, y) + hh(x + 1, y + 1)
                  - hh(x - 1, y - 1) - 2 * hh(x - 1, y) - hh(x - 1, y + 1)) / 8.0
            gy = (hh(x - 1, y + 1) + 2 * hh(x, y + 1) + hh(x + 1, y + 1)
                  - hh(x - 1, y - 1) - 2 * hh(x, y - 1) - hh(x + 1, y - 1)) / 8.0
            nx = -INCLINA * gx
            ny = INCLINA * gy           # y da imagem cresce para baixo; G da normal sobe
            m = math.sqrt(nx * nx + ny * ny + 1.0)
            NX[i], NY[i], NZ[i] = nx / m, ny / m, 1.0 / m
    SX, SY, SZ = list(NX), list(NY), list(NZ)
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if not alfa[i]:
                continue
            ax = ay = az = 0.0
            k_n = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and alfa[yy * w + xx]:
                        k = yy * w + xx
                        ax += NX[k]
                        ay += NY[k]
                        az += NZ[k]
                        k_n += 1
            ax, ay, az = ax / k_n, ay / k_n, az / k_n
            m = math.sqrt(ax * ax + ay * ay + az * az) or 1.0
            SX[i], SY[i], SZ[i] = ax / m, ay / m, az / m
    out = bytearray(w * h * 4)
    for i in range(n):
        j = i * 4
        if not alfa[i]:
            out[j:j + 4] = b"\x80\x80\xff\x00"
        else:
            out[j] = max(0, min(255, int(round((SX[i] * 0.5 + 0.5) * 255))))
            out[j + 1] = max(0, min(255, int(round((SY[i] * 0.5 + 0.5) * 255))))
            out[j + 2] = max(0, min(255, int(round((SZ[i] * 0.5 + 0.5) * 255))))
            out[j + 3] = 255
    normal = Image.frombytes("RGBA", (w, h), bytes(out))
    return normal.crop((2, 2, w0 + 2, h0 + 2))


def inclinacao_graus(nor, alb):
    """Diagnostico: inclinacao da normal (graus da vertical) na borda do alfa e no miolo."""
    w, h = nor.size
    dn = nor.tobytes()
    da = alb.tobytes()
    borda, miolo = [], []
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if da[i * 4 + 3] == 0:
                continue
            nz = dn[i * 4 + 2] / 255.0 * 2 - 1
            ang = math.degrees(math.acos(max(-1.0, min(1.0, nz))))
            fronteira = any(not (0 <= xx < w and 0 <= yy < h and da[(yy * w + xx) * 4 + 3])
                            for xx, yy in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
            (borda if fronteira else miolo).append(ang)
    borda.sort()
    miolo.sort()
    return (borda[len(borda) // 2] if borda else 0.0, miolo[int(len(miolo) * 0.95)] if miolo else 0.0)


# ------------------------------------------------------------------ folha
def empacotar(tamanhos):
    pos = []
    x = y = linha_h = largura = 0
    for (w, h) in tamanhos:
        if x > 0 and x + w > LARGURA_FOLHA:
            x = 0
            y += linha_h + PAD
            linha_h = 0
        pos.append((x, y))
        x += w + PAD
        linha_h = max(linha_h, h)
        largura = max(largura, x - PAD)
    return pos, largura, y + linha_h


def quantizar(folha, cores):
    """Paleta unica para a folha toda, so com pixels opacos; mapeamento sem dithering."""
    alfa = folha.getchannel("A")
    rgb = folha.convert("RGB")
    dados = rgb.tobytes()
    ab = alfa.tobytes()
    opacos = bytearray()
    for i in range(len(ab)):
        if ab[i] == 255:
            opacos += dados[i * 3:i * 3 + 3]
    amostra = Image.frombytes("RGB", (len(opacos) // 3, 1), bytes(opacos))
    paleta = amostra.quantize(colors=cores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q = rgb.quantize(palette=paleta, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(alfa)
    return q


def _normaliza(v):
    m = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / m for c in v)


def iluminar(alb, nor, lado):
    """Lambert sobre a normal + ambiente AMB_PREVIA, com luz quente. lado = -1 (esquerda) ou +1 (direita)."""
    luz = _normaliza((0.95 * lado, 0.3, 0.3))
    w, h = alb.size
    da = alb.tobytes()
    dn = nor.tobytes()
    out = bytearray(w * h * 4)
    for i in range(w * h):
        j = i * 4
        if da[j + 3] == 0:
            continue
        nx = dn[j] / 255.0 * 2 - 1
        ny = dn[j + 1] / 255.0 * 2 - 1
        nz = dn[j + 2] / 255.0 * 2 - 1
        lamb = max(0.0, nx * luz[0] + ny * luz[1] + nz * luz[2])
        k = AMB_PREVIA + (1.0 - AMB_PREVIA) * lamb
        for c in range(3):
            out[j + c] = min(255, int(da[j + c] * k * COR_QUENTE[c]))
        out[j + 3] = 255
    return Image.frombytes("RGBA", (w, h), bytes(out))


def previa(faixas, caminho):
    """Cada faixa: 3 linhas (albedo, luz da esquerda, luz da direita), escala 3x, objetos lado a lado."""
    ESC = 3
    GAP = 14
    fonte = ImageFont.load_default(size=13)
    cinza = (0x5a, 0x5a, 0x64, 255)
    rotulos = ["albedo", "luz quente da esquerda", "luz quente da direita"]
    prontas = []
    for titulo, itens in faixas:
        linhas = [
            [alb for _, alb, _n in itens],
            [iluminar(alb, nor, -1) for _, alb, nor in itens],
            [iluminar(alb, nor, +1) for _, alb, nor in itens],
        ]
        prontas.append((titulo, itens, linhas))
    largura = 0
    altura = 0
    for titulo, itens, linhas in prontas:
        larg = GAP + sum(a.width * ESC + GAP for a in linhas[0])
        largura = max(largura, larg)
        for linha in linhas:
            altura += 16 + max(a.height for a in linha) * ESC + 12
        altura += 22 + 30 + 20
    tela = Image.new("RGBA", (largura, altura + 10), cinza)
    d = ImageDraw.Draw(tela)
    y0 = 10
    for titulo, itens, linhas in prontas:
        d.text((GAP, y0), titulo, fill=(255, 255, 255, 255), font=fonte)
        y = y0 + 22
        for rotulo, linha in zip(rotulos, linhas):
            d.text((GAP, y), rotulo, fill=(255, 240, 200, 255), font=fonte)
            y += 16
            alt_linha = max(a.height for a in linha) * ESC
            x = GAP
            for a in linha:
                a3 = a.resize((a.width * ESC, a.height * ESC), Image.NEAREST)
                tela.alpha_composite(a3, (x, y + alt_linha - a3.height))
                x += a3.width + GAP
            y += alt_linha + 12
        x = GAP
        for (nome, _a, _n), a in zip(itens, linhas[0]):
            d.text((x, y), nome, fill=(230, 230, 230, 255), font=fonte)
            x += a.width * ESC + GAP
        y += 30
        y0 = y + 20
    tela.convert("RGB").save(caminho)


def main():
    if not os.path.isdir(SAIDA):
        os.makedirs(SAIDA)
    sprites = []      # (nome, peso, albedo, normal, pe, formas de colisao)
    faixas = []
    for arquivo, linhas, lista in FOLHAS:
        w, h, data = carregar(os.path.join(AQUI, arquivo))
        grupos = agrupar(w, h, data, arquivo, len(lista), linhas)
        itens = []
        for g, (nome, eixo, alvo, peso) in zip(grupos, lista):
            cru = recortar(g, w, data)
            esc = escalar(cru, eixo, alvo)
            alb = contorno(binarizar(esc))
            alb = alb.crop(alb.getbbox())      # tira a linha/coluna transparente que sobra do limiar
            nor = normal_do_objeto(alb)
            borda_g, miolo_g = inclinacao_graus(nor, alb)
            print("      inclinacao na borda %.0f graus (mediana), no miolo %.0f (p95)" % (borda_g, miolo_g))
            pe = pe_do_portal(alb) if nome.startswith("torii") else pe_do_objeto(alb)
            formas = formas_de_colisao(nome, alb, pe)
            sprites.append((nome, peso, alb, nor, pe, formas))
            itens.append((nome, alb, nor))
            print("  %-15s %3dx%-3d  (alvo %s %d)  pe %s  colisao %d" % (
                nome, alb.width, alb.height, eixo, alvo, pe, len(formas)))
        faixas.append((arquivo, itens))

    pos, largura, altura = empacotar([(s[2].width, s[2].height) for s in sprites])
    folha = Image.new("RGBA", (largura, altura), (0, 0, 0, 0))
    folha_n = Image.new("RGBA", (largura, altura), (128, 128, 255, 0))
    for (x, y), s in zip(pos, sprites):
        folha.paste(s[2], (x, y))
        folha_n.paste(s[3], (x, y))
    folha = quantizar(folha, COR_MAX)
    cores = len(folha.getcolors(1 << 20))
    folha.save(os.path.join(SAIDA, "enfeites.png"))
    folha_n.save(os.path.join(SAIDA, "enfeites_normal.png"))
    print("folha %dx%d, %d cores distintas" % (largura, altura, cores))
    previa_colisao(folha, pos, sprites, PREVIA_COLISAO)

    itens = []
    for (x, y), (nome, peso, alb, _nor, pe, formas) in zip(pos, sprites):
        item = {"nome": nome, "peso": peso, "pe": pe, "regiao": [x, y, alb.width, alb.height], "colisao": formas}
        if nome in FOGO:
            fx, fy = FOGO[nome]
            item["fogo"] = [int(fx * alb.width), int(fy * alb.height)]
        itens.append(item)
    cen = {
        "_gerado_por": "jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py (nao edite a mao)",
        "enfeites": "enfeites.png",
        "enfeites_normal": "enfeites_normal.png",
        "ambiente": AMBIENTE,
        "itens": itens,
        "fixos": [],
    }
    with open(os.path.join(SAIDA, "cenario.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(cen, f, ensure_ascii=False, indent=1)
        f.write("\n")
    previa([(arq, itens_) for arq, itens_ in faixas], PREVIA)
    print("previa", PREVIA)


# ------------------------------------------------------------------ armas da v2 (python gerar_objetos.py armas)
# Arte propria: folhas do Alisson (GPT) e do Codex do Alisson (imagegen); cobertura dos 50 golpes e 25 evolucoes.
# Folhas de arte propria que o Alisson gerou no GPT: 16 projeteis e meteoros (fundo branco), 9 aliados
# (fundo branco), 12 efeitos de area da folha 20 e 9 da folha 21 (fundo preto, aditivos). Saida: um PNG por
# sprite em projeto/assets/v2/armas/ (normal map so onde a luz 2D age: projetil e aliado), indice.json e a previa.
# A v2 le o indice.json em v2/armas_novas.gd (um sprite por golpe).
ARMAS_SAIDA = os.path.join(HORDAS, "projeto", "assets", "v2", "armas")
ARMAS_PREVIA = os.path.join(HORDAS, "prints", "v2_armas_sprites.png")
LIMITE_CLARO_FUNDO = 236     # folha clara: min(R, G, B) acima disto e fundo branco (so o que liga a borda)
LIMITE_ESCURO_FUNDO = 10     # folha escura: max(R, G, B) abaixo disto e fundo preto
LIMITE_ADITIVO = 6           # efeito aditivo: brilho abaixo disto vira zero (ruido do fundo)
LIMIAR_ARMAS = 64            # sprite claro: alfa a 25% (e nao 50%) para a haste fina de 1 px nao sumir na reducao
COR_ARMAS_CLARO = 48         # paleta unica de cada folha clara (sem dithering)
COR_ARMAS_ADITIVO = 40       # paleta unica da folha de efeitos

# (arquivo ao lado deste script, modo, linhas da folha, tipo no indice, sprites na ordem de linha e coluna)
# sprite = (nome, familia, caixa, armas_sugeridas, armas_aproximadas, obs); caixa = (largura, altura) em px
# no jogo 960x540. Efeito de area: altura 0 (sai da proporcao da folha).
ARMAS_FOLHAS = [
    ("fonte_armas_projeteis.webp", "claro", [4, 4, 4, 4], "projetil", [
        ("flecha_roxa", "projetil", (12, 3), ["flechas_sombrias"], [], "fina e escura: contorno claro de 1 px"),
        ("adaga_aco", "projetil", (10, 4), ["adagas_voadoras"], [], ""),
        ("lanca_gelo", "projetil", (18, 4), ["lanca_geada"], [], ""),
        ("shuriken_sombria", "projetil", (8, 8), ["estrelas_sombra"], [], "escura: contorno claro de 1 px"),
        ("bola_fogo", "projetil", (16, 16), ["bola_fogo"], ["fogo_do_ceu"], ""),
        ("dardo_verde", "projetil", (8, 3), ["dardos_peconhentos"], [], "3 px de altura (a spec pede 2) para a ponta nao sumir; fino: contorno claro de 1 px"),
        ("feixe_dourado", "projetil", (40, 3), ["raio_solar"], [], ""),
        ("disco_ferro", "projetil", (16, 16), ["bumerangue_ferro"], [], ""),
        ("bola_chumbo", "projetil", (14, 14), ["bolas_chumbo"], ["chuva_pedras"], ""),
        ("pedra_vulcanica", "meteoro", (10, 10), ["pedras_vulcanicas"], [], ""),
        ("meteoro_flamejante", "meteoro", (28, 28), ["meteoro_flamejante"], [], ""),
        ("cometa_gelo", "meteoro", (22, 22), ["cometa_gelado"], [], ""),
        ("cometa_roxo", "meteoro", (40, 40), ["cometa_negro"], [], ""),
        ("estrela_cadente", "meteoro", (24, 16), ["estrelas_cadentes"], [], ""),
        ("espinho_verde", "meteoro", (6, 14), ["chuva_espinhos"], [], ""),
        ("estilhaco_azul", "meteoro", (30, 30), [], ["raio_meteorico"], "estilhaco azul com faiscas: so aproxima o meteoro eletrico"),
    ]),
    ("fonte_armas_aliados.webp", "claro", [3, 3, 3], "aliado", [
        ("lobo_fantasma", "aliado", (36, 28), ["lobo_espirito"], [], ""),
        ("raposa_de_fogo", "aliado", (28, 18), ["espirito_raposa"], [], ""),
        ("guardiao_de_pedra", "aliado", (44, 52), ["guardiao_pedra"], [], ""),
        ("fantasma_encapuzado", "aliado", (24, 34), ["fantasma_mata"], [], ""),
        ("serpente_de_brasa", "aliado", (40, 22), ["serpente_ardente"], [], ""),
        ("urso_espiritual", "aliado", (52, 40), ["espirito_urso"], [], ""),
        ("golem_de_barro", "aliado", (46, 54), ["golem_barro"], [], ""),
        ("dragao_vermelho", "aliado", (32, 26), ["dragao_filhote"], [], ""),
        ("esqueleto_guerreiro", "aliado", (30, 44), ["esqueleto_guerreiro"], [], ""),
    ]),
    ("fonte_armas_areas.webp", "escuro", [4, 4, 4], "area", [
        ("nuvem_veneno", "nuvem", (100, 0), ["nuvem_veneno"], [], ""),
        ("nevoa_gelada", "nuvem", (120, 0), ["nevoeiro_gelado"], [], ""),
        ("nuvem_cinzas", "nuvem", (160, 0), ["cinzas_vulcanicas"], [], ""),
        ("nuvem_esporos", "nuvem", (120, 0), ["nuvem_espora"], [], ""),
        ("nevoa_fantasmal", "nuvem", (100, 0), [], [], "descartado: a folha 21 traz a nevoa espectral"),
        ("nuvem_sangue", "nuvem", (70, 0), ["cortina_sangue"], [], ""),
        ("anel_fogo", "anel", (128, 0), [], ["aura_fogo"], "referencia anterior da aura; sprite proprio aura_fogo tem prioridade"),
        ("anel_dourado", "anel", (128, 0), ["pulso_sagrado"], [], ""),
        ("anel_onda_branca", "anel", (128, 0), ["onda_choque"], [], ""),
        ("anel_espinhos_verdes", "anel", (128, 0), ["anel_espinhos"], [], ""),
        ("anel_lunar", "anel", (128, 0), ["anel_luar"], [], ""),
        ("anel_vento", "anel", (128, 0), [], [], "descartado: a folha 21 traz a rajada de vento"),
    ]),
    ("fonte_armas_areas_2.webp", "escuro", [3, 3, 3], "area", [
        ("terremoto_poeira", "nuvem", (150, 0), ["terremoto"], [], "poeira e pedras rente ao chao"),
        ("anel_eletrico", "anel", (128, 0), ["martelo_trovao"], [], "anel amarelo com faiscas eletricas"),
        ("anel_gelo", "anel", (128, 0), ["anel_gelado"], [], "anel azul-gelo com cristais"),
        ("fumaca_sonolenta", "nuvem", (110, 0), ["fumaca_sonolenta"], [], "fumaca lilas com letras Z"),
        ("chuva_acida", "nuvem", (120, 0), ["chuva_acida"], [], "gotas verde-amareladas caindo numa area"),
        ("nuvem_neve", "nuvem", (140, 0), ["nevasca"], [], "nuvem branca alta com flocos"),
        ("nevoa_espectral", "nuvem", (100, 0), ["nevoa_espectral"], [], "nevoa azulada com rostos"),
        ("anel_vermelho", "anel", (128, 0), ["grito_guerra"], [], "anel vermelho de energia"),
        ("redemoinho_verde", "anel", (128, 0), ["rajada_vento"], [], "espiral de vento, nao anel"),
    ]),
    ("fonte_armas_evolucoes_projeteis.png", "claro", [4, 4, 3], "projetil", [
        ("laminas", "orbita", (18, 10), ["laminas"], [], "arte propria: evolucao ou familia base"),
        ("anel_de_brasas", "orbita", (22, 14), ["anel_de_brasas"], [], "arte propria: evolucao ou familia base"),
        ("urso_solar", "projetil", (26, 16), ["urso_solar"], [], "arte propria: evolucao ou familia base"),
        ("chuva_de_lacas", "projetil", (22, 7), ["chuva_de_lacas"], [], "arte propria: evolucao ou familia base"),
        ("bola_incendiaria", "projetil", (24, 18), ["bola_incendiaria"], [], "arte propria: evolucao ou familia base"),
        ("pedreira_ardente", "meteoro", (22, 22), ["pedreira_ardente"], [], "arte propria: evolucao ou familia base"),
        ("cometa_duplo", "meteoro", (32, 18), ["cometa_duplo"], [], "arte propria: evolucao ou familia base"),
        ("chuva_de_ferro", "projetil", (24, 18), ["chuva_de_ferro"], [], "arte propria: evolucao ou familia base"),
        ("eclipse_negro", "meteoro", (36, 28), ["eclipse_negro"], [], "arte propria: evolucao ou familia base"),
        ("tempestade_primordial", "projetil", (44, 16), ["tempestade_primordial"], [], "arte propria: evolucao ou familia base"),
        ("juizo_final", "meteoro", (40, 30), ["juizo_final"], [], "arte propria: evolucao ou familia base"),
    ]),
    ("fonte_armas_evolucoes_aliados.png", "claro", [3, 2, 2], "aliado", [
        ("corvos", "corvos", (33, 27), ["corvos"], [], "arte propria: evolucao ou familia base"),
        ("revoada_de_trovoes", "corvos", (36, 30), ["revoada_de_trovoes"], [], "arte propria: evolucao ou familia base"),
        ("dragao_de_brasa", "aliado", (40, 36), ["dragao_de_brasa"], [], "arte propria: evolucao ou familia base"),
        ("cacada_espiritual", "aliado", (44, 32), ["cacada_espiritual"], [], "arte propria: evolucao ou familia base"),
        ("exercito_esquecido", "aliado", (34, 44), ["exercito_esquecido"], [], "arte propria: evolucao ou familia base"),
        ("colosso_de_pedra", "aliado", (48, 54), ["colosso_de_pedra"], [], "arte propria: evolucao ou familia base"),
        ("eclipse_de_almas", "aliado", (48, 38), ["eclipse_de_almas"], [], "arte propria: evolucao ou familia base"),
    ]),
    ("fonte_armas_evolucoes_areas.png", "escuro", [4, 4, 4], "area", [
        ("aura_fogo", "aura", (128, 0), ["aura_fogo"], [], "arte propria: evolucao ou familia base"),
        ("raio", "raio", (100, 0), ["raio"], [], "arte propria: evolucao ou familia base"),
        ("runa", "runa", (72, 0), ["runa"], [], "arte propria: evolucao ou familia base"),
        ("circulo_runico", "runa", (100, 0), ["circulo_runico"], [], "arte propria: evolucao ou familia base"),
        ("ventania", "katana", (120, 0), ["ventania"], [], "arte propria: evolucao ou familia base"),
        ("nevasca_congelante", "nuvem", (145, 0), ["nevasca_congelante"], [], "arte propria: evolucao ou familia base"),
        ("cinzas_acidas", "nuvem", (150, 0), ["cinzas_acidas"], [], "arte propria: evolucao ou familia base"),
        ("estrondo", "anel", (140, 0), ["estrondo"], [], "arte propria: evolucao ou familia base"),
        ("terra_partida", "anel", (150, 0), ["terra_partida"], [], "arte propria: evolucao ou familia base"),
        ("peste_negra", "nuvem", (130, 0), ["peste_negra"], [], "arte propria: evolucao ou familia base"),
        ("juramento_sagrado", "anel", (140, 0), ["juramento_sagrado"], [], "arte propria: evolucao ou familia base"),
        ("furacao_glacial", "nuvem", (160, 0), ["furacao_glacial"], [], "arte propria: evolucao ou familia base"),
    ]),

]

# Folga para juntar pedacos de um mesmo sprite: a folha 21 tem sprites da linha de baixo a 1-2 px um do outro, e com
# a folga de 6 px eles viravam um so (7 objetos em vez de 9). Folhas 18 a 20 seguem com a folga padrao.
GAP_FOLHA = {"fonte_armas_areas_2.webp": 0, "fonte_armas_evolucoes_aliados.png": 0}
# Projeteis finos ou escuros: ganham 1 px claro em volta (depois da paleta, que fica igual), para ler no piso escuro.
CONTORNO_CLARO = {"flecha_roxa", "shuriken_sombria", "dardo_verde", "laminas", "chuva_de_lacas"}
COR_CONTORNO = (236, 240, 248)
# Cortados (a folha 20 tem 12 celulas, e a grade precisa delas) mas trocados pelos da folha 21: nao saem no indice.
ARMAS_DESCARTADOS = {"nevoa_fantasmal", "anel_vento"}

ARMAS_AJUDA = (
    "Sprites das armas da v2, recortados de arte propria do Alisson (GPT) e do Codex do Alisson (imagegen). "
    "Chave = nome do sprite. arquivo = PNG nesta pasta. normal = normal map pareado para a luz 2D "
    "(so projetil e aliado; efeito de area nao tem). tipo: projetil (aponta para a direita; o codigo gira "
    "pelo angulo do voo, e o meteoro que cai fica com a ponta para baixo), aliado (de pe: a borda de baixo e o chao) "
    "e area (efeito aditivo: o fundo preto virou transparencia e o brilho virou alfa; desenhar com mistura aditiva). "
    "tamanho = largura x altura em px no jogo (960x540); em area a altura sai da proporcao da folha. "
    "Cobertura: 50 golpes base e 25 evolucoes. armas_sugeridas = armas que o sprite serve bem; armas_aproximadas = sprite "
    "provisorio, serve a arma mas nao e o ideal. Ligado ao desenho em v2/armas.gd e v2/armas_novas.gd: o golpe usa o sprite "
    "da sua arma; sem sprite, mantem a forma antiga."
)


def carregar_folha_armas(caminho, modo):
    """Le a folha (RGB) e poe alfa 0 no fundo (branco ou preto, conforme o modo) e 255 no resto.
    O fundo so vira 0 onde a cor e de fundo; o flood fill de fundo_por_borda separa o que liga a borda."""
    rgb = Image.open(caminho).convert("RGB")
    w, h = rgb.size
    px = rgb.tobytes()
    out = bytearray(w * h * 4)
    for i in range(w * h):
        r, g, b = px[3 * i], px[3 * i + 1], px[3 * i + 2]
        if modo == "claro":
            fundo = min(r, g, b) >= LIMITE_CLARO_FUNDO
        else:
            fundo = max(r, g, b) <= LIMITE_ESCURO_FUNDO
        out[4 * i:4 * i + 4] = bytes((r, g, b, 0 if fundo else 255))
    return w, h, bytes(out)


def aditivo(rgb):
    """Efeito sobre fundo preto -> RGBA: alfa = brilho maximo do pixel (quase a luminancia, mas nao apaga
    o vermelho ou o verde saturados); cor = a cor sem o brilho. Sobre preto, a composicao volta ao original."""
    w, h = rgb.size
    px = rgb.tobytes()
    out = bytearray(w * h * 4)
    for i in range(w * h):
        r, g, b = px[3 * i], px[3 * i + 1], px[3 * i + 2]
        a = max(r, g, b)
        if a < LIMITE_ADITIVO:
            continue
        out[4 * i:4 * i + 4] = bytes((min(255, round(r * 255 / a)), min(255, round(g * 255 / a)),
                                      min(255, round(b * 255 / a)), a))
    return Image.frombytes("RGBA", (w, h), bytes(out))


def fit_em_caixa(img, w, h):
    """Reduz (BOX, em espaco pre-multiplicado pelo Pillow) para caber em w x h, mantendo a proporcao."""
    bw, bh = img.size
    s = min(w / float(bw), h / float(bh))
    return img.resize((max(1, min(w, round(bw * s))), max(1, min(h, round(bh * s)))), Image.BOX)


def em_tela(img, w, h, base):
    """Poe o sprite numa tela w x h: centralizado, ou com a borda de baixo no fundo da caixa (base 'pe')."""
    tela = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = (w - img.width) // 2
    y = h - img.height if base == "pe" else (h - img.height) // 2
    tela.paste(img, (x, y))
    return tela


def quantizar_lista(imagens, cores):
    """Uma paleta so para a folha (cores de pixels visiveis), mapeamento sem dithering; a alfa nao muda."""
    amostra = bytearray()
    for im in imagens:
        alfa = im.getchannel("A").tobytes()
        rgb = im.convert("RGB").tobytes()
        for i in range(len(alfa)):
            if alfa[i] >= LIMITE_ADITIVO:
                amostra += rgb[3 * i:3 * i + 3]
    paleta = Image.frombytes("RGB", (len(amostra) // 3, 1), bytes(amostra)).quantize(
        colors=cores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    saida = []
    for im in imagens:
        q = im.convert("RGB").quantize(palette=paleta, dither=Image.Dither.NONE).convert("RGBA")
        q.putalpha(im.getchannel("A"))
        saida.append(q)
    return saida


def com_contorno(img):
    """Sprite com 1 px claro em volta (os 8 vizinhos do que e opaco): a imagem cresce 2 px em cada eixo."""
    base = Image.new("RGBA", (img.width + 2, img.height + 2), (0, 0, 0, 0))
    base.paste(img, (1, 1))
    w, h = base.size
    alfa = base.getchannel("A").tobytes()
    out = bytearray(base.tobytes())
    for y in range(h):
        for x in range(w):
            if alfa[y * w + x]:
                continue
            vizinho = any(
                alfa[(y + dy) * w + x + dx]
                for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                if 0 <= x + dx < w and 0 <= y + dy < h
            )
            if vizinho:
                out[4 * (y * w + x):4 * (y * w + x) + 4] = bytes(COR_CONTORNO + (255,))
    return Image.frombytes("RGBA", (w, h), bytes(out))


def gerar_armas():
    os.makedirs(ARMAS_SAIDA, exist_ok=True)
    sprites = {}
    previa = []                  # (tipo, nome, imagem, armas_sugeridas, armas_aproximadas)
    for arquivo, modo, linhas, tipo, lista in ARMAS_FOLHAS:
        w, h, data = carregar_folha_armas(os.path.join(AQUI, arquivo), modo)
        grupos = agrupar(w, h, data, arquivo, len(lista), linhas, por_centro=True, gap=GAP_FOLHA.get(arquivo, GAP_JUNTA),
                         juntar_caixas=arquivo != "fonte_armas_evolucoes_aliados.png")
        feitos = []
        for g, (nome, familia, caixa, sugeridas, aproximadas, obs) in zip(grupos, lista):
            cru = recortar(g, w, data)
            if modo == "claro":
                alb = binarizar(fit_em_caixa(cru, caixa[0], caixa[1]), LIMIAR_ARMAS)
                if tipo == "aliado":
                    alb = contorno(em_tela(alb, caixa[0], caixa[1], "pe"))
                else:
                    alb = em_tela(alb, caixa[0], caixa[1], "centro")
            else:
                nh = max(1, round(cru.height * caixa[0] / float(cru.width)))
                alb = aditivo(cru.convert("RGB").resize((caixa[0], nh), Image.BOX))
            feitos.append((nome, familia, sugeridas, aproximadas, obs, alb))
        quant = quantizar_lista([f[5] for f in feitos], COR_ARMAS_CLARO if modo == "claro" else COR_ARMAS_ADITIVO)
        escritos = [(f, q) for f, q in zip(feitos, quant) if f[0] not in ARMAS_DESCARTADOS]
        for (nome, familia, sugeridas, aproximadas, obs, _), q in escritos:
            if nome in CONTORNO_CLARO:
                q = com_contorno(q)
            tem_normal = tipo in ("projetil", "aliado")
            q.save(os.path.join(ARMAS_SAIDA, nome + ".png"))
            if tem_normal:
                nor = normal_do_objeto(q)
                nor.save(os.path.join(ARMAS_SAIDA, nome + "_normal.png"))
            entrada = {
                "arquivo": nome + ".png",
                "normal": nome + "_normal.png" if tem_normal else None,
                "tipo": tipo,
                "familia": familia,
                "tamanho": [q.width, q.height],
                "armas_sugeridas": sugeridas,
                "armas_aproximadas": aproximadas,
            }
            if obs:
                entrada["obs"] = obs
            sprites[nome] = entrada
            previa.append((tipo, nome, q, sugeridas, aproximadas))
            print("  %-22s %-7s %3dx%-3d sugeridas %s%s" % (
                nome, tipo, q.width, q.height, sugeridas, (" aprox %s" % aproximadas) if aproximadas else ""))
        print("%s: %d sprites, %s" % (arquivo, len(escritos), "paleta de %d cores" % (COR_ARMAS_CLARO if modo == "claro" else COR_ARMAS_ADITIVO)))
    indice = {
        "_ajuda": ARMAS_AJUDA,
        "_gerado_por": "jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py armas (nao edite a mao)",
        "sprites": sprites,
    }
    with open(os.path.join(ARMAS_SAIDA, "indice.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(indice, f, ensure_ascii=False, indent=1)
        f.write("\n")
    sug = sum(len(s["armas_sugeridas"]) for s in sprites.values())
    apr = sum(len(s["armas_aproximadas"]) for s in sprites.values())
    print("armas: %d com sprite adequado, %d com sprite aproximado" % (sug, apr))
    previa_armas(previa, ARMAS_PREVIA)
    print("previa", ARMAS_PREVIA)


def previa_armas(itens, caminho):
    """Prancha escura: cada sprite em 3x (projetil, aliado) ou 2x (area), com as armas que ele serve.
    Azul-claro = arma servida; laranja = so aproximada (sprite provisorio)."""
    fonte = ImageFont.load_default(size=13)
    fonte_titulo = ImageFont.load_default(size=16)
    medidor = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    branco, laranja, cinza = (236, 236, 236, 255), (255, 178, 84, 255), (150, 150, 162, 255)
    fundo = (22, 20, 28, 255)
    margem = 32
    secoes = [
        ("projetil", "Projeteis e meteoros (bases e evolucoes: 27 sprites)", 8, 3),
        ("aliado", "Aliados (bases e evolucoes: 16 sprites)", 5, 3),
        ("area", "Efeitos de area, aditivos (bases e evolucoes: 31 sprites)", 4, 2),
    ]
    plano = []
    largura = 0
    for tipo, titulo, colunas, esc in secoes:
        sel = [it for it in itens if it[0] == tipo]
        imgs = [it[2].resize((it[2].width * esc, it[2].height * esc), Image.NEAREST) for it in sel]
        txts = [[(it[1], branco)] + [("-> " + a, branco) for a in it[3]] + [("~ " + a, laranja) for a in it[4]]
                for it in sel]
        larg_txt = max(medidor.textlength(t, font=fonte) for linhas in txts for t, _ in linhas)
        cel_w = int(24 + max(max(im.width for im in imgs), larg_txt))
        linhas_cel = []
        for r in range(0, len(sel), colunas):
            idx = list(range(r, min(r + colunas, len(sel))))
            linhas_cel.append((idx, max(imgs[i].height for i in idx), max(len(txts[i]) for i in idx) * 16))
        plano.append((titulo, cel_w, imgs, txts, linhas_cel))
        largura = max(largura, colunas * cel_w)
    altura = 110
    for _, _, _, _, linhas_cel in plano:
        altura += 34 + sum(alt + 12 + txt + 18 for _, alt, txt in linhas_cel)
    tela = Image.new("RGBA", (2 * margem + largura, altura), fundo)
    d = ImageDraw.Draw(tela)
    d.text((margem, 14), "Armas da v2: Alisson (GPT) e Codex do Alisson (imagegen) - 50 golpes, 25 evolucoes",
           fill=branco, font=fonte_titulo)
    d.text((margem, 40), "-> arma que o sprite serve bem        ~ sprite provisorio (serve a arma, mas nao e o ideal)",
           fill=cinza, font=fonte)
    y = 90
    for titulo, cel_w, imgs, txts, linhas_cel in plano:
        d.text((margem, y), titulo, fill=branco, font=fonte_titulo)
        y += 34
        for idx, alt_img, alt_txt in linhas_cel:
            base = y + alt_img
            for k, i in enumerate(idx):
                cx = margem + k * cel_w
                im = imgs[i]
                d.rectangle([cx, y - 4, cx + cel_w - 10, y + alt_img + alt_txt + 14], outline=(44, 40, 54, 255))
                tela.alpha_composite(im, (cx + (cel_w - 10 - im.width) // 2, base - im.height))
                ty = base + 8
                for texto, cor in txts[i]:
                    d.text((cx + 10, ty), texto, fill=cor, font=fonte)
                    ty += 16
            y += alt_img + 12 + alt_txt + 18
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    tela.convert("RGB").save(caminho)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "armas":
        gerar_armas()
    else:
        main()

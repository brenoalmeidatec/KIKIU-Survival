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
    python gerar_objetos.py hud       molduras 9-slice do HUD (folhas do #290, fonte_arte/hud_molduras/) -> projeto/v2/hud/moldura_{retrato,barra,habilidade}.png
    python gerar_objetos.py icones    icones das cartas da v2 (folhas do #272, fonte_arte/icones_cartas/) -> projeto/assets/v2/icones_cartas/
    python gerar_objetos.py marco4    8 estruturas do Marco 4 (fonte_arte/marco4/fonte_estruturas.png, grade 4x2) -> projeto/assets/v2/marco4/
    python gerar_objetos.py fusoes    moldura, halo, Ventania e icone das fusoes (fonte_arte/fusoes/) -> projeto/assets/v2/fusoes/
    python gerar_objetos.py especial_q  icone do Q de cada heroi (fonte_arte/especial_q/, #349) -> projeto/assets/v2/especial_q/ (32 px)
    python gerar_objetos.py habilidade_e  icones da E de Nicao/Lucas (fonte_arte/habilidade_e/, #387) -> projeto/assets/v2/habilidade_e/ (32 px)
    python gerar_objetos.py chefes      busto de cada chefe da v2 (fonte_arte/chefes_v2/, #360) -> projeto/assets/v2/chefes/ (36 px, barra do chefe)

Passos: fundo = alfa 0 (ou branco) ligado a borda, por flood fill; objetos = componentes do que sobrou,
juntados por proximidade; ordem = linha e coluna; BOX para a escala do jogo; alfa binario a 50%;
quantizacao sem dithering; normal = domo pela distancia ate a borda + um pouco da luminancia.
"""
import json
import math
import os
import re
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


# ------------------------------------------------------------------ icones das cartas (v2): folhas do #272 -> 32 px e 16 px
ICONES_FONTE = os.path.join(HORDAS, "fonte_arte", "icones_cartas")
ICONES_SAIDA = os.path.join(HORDAS, "projeto", "assets", "v2", "icones_cartas")
ICONES_PREVIA = os.path.join(HORDAS, "prints", "v2_icones_cartas.png")
ICONES_GRADE = (4, 3)        # colunas e linhas de cada folha (ordem: esquerda para a direita, de cima para baixo)
ICONES_CELULA = 362          # lado de cada celula (1448x1086 = 4 x 3 celulas)
ICONES_TAM = 32              # icone da carta: a escolha (o cartao tem 32 px), o bau e os slots da HUD
ICONES_TAM_PEQUENO = 16      # SUA BUILD: a linha do card tem 18 px (HUD) e 20 px (visual); 32 px nao cabe
ICONES_COR = 64              # paleta unica para as duas medidas, sem dithering
ICONES_LIMIAR = 64           # alfa binario a 25% (e nao 50%): a lamina e a haste finas nao somem na reducao para 16 px
ICONES_AJUDA = (
    "Icones proprios das cartas da v2 (arte do PR #272, folhas em jogos/hordas/fonte_arte/icones_cartas/). "
    "A chave e o ID da carta em dados/v2_cartas.json (unico entre categorias; INDICE.md traz categoria + ID). "
    "arquivo = 32x32, o icone da escolha de cartas, do bau e dos slots da HUD; pequeno = 16x16 (pasta 16/), o da linha do card SUA BUILD. "
    "ID sem entrada (ou arquivo faltando) cai no campo antigo icone (assets/gerado/, 16x16). "
    "Nao edite a mao: rode `python gerar_objetos.py icones`."
)


def ler_indice_icones():
    """(folha, celula, categoria, id) de cada linha da tabela de INDICE.md. As celulas vazias nao tem linha."""
    folha = None
    itens = []
    with open(os.path.join(ICONES_FONTE, "INDICE.md"), encoding="utf-8") as f:
        for linha in f:
            m = re.match(r"## Folha (\d+)\b", linha)
            if m:
                folha = int(m.group(1))
                continue
            m = re.match(r"\| (\d+)[^|]*\| ([^|]+?) / ([^|]+?) \|", linha)  # a célula pode trazer "(linha 1, coluna 1; ...)"
            if m and folha is not None:
                itens.append((folha, int(m.group(1)), m.group(2).strip(), m.group(3).strip()))
    return itens


def recortar_celula(cel):
    """Celula RGB de fundo branco -> RGBA: alfa 0 no branco que liga a borda (flood fill); o branco preso dentro do desenho fica."""
    w, h = cel.size
    px = cel.tobytes()
    alfa = bytearray(w * h)
    for i in range(w * h):
        if min(px[3 * i], px[3 * i + 1], px[3 * i + 2]) < LIMITE_CLARO_FUNDO:
            alfa[i] = 255
    fundo = fundo_por_borda(w, h, alfa)
    out = bytearray(w * h * 4)
    for i in range(w * h):
        out[4 * i:4 * i + 4] = bytes((px[3 * i], px[3 * i + 1], px[3 * i + 2], 0 if fundo[i] else 255))
    return Image.frombytes("RGBA", (w, h), bytes(out))


def icone_da_celula(cel, tam):
    """Icone de tam x tam: caixa justa do desenho, BOX para caber com 1 px de folga, alfa binario e contorno escuro de 1 px."""
    img = recortar_celula(cel)
    img = img.crop(img.getchannel("A").getbbox())
    lado = tam - 2  # a folga de 1 px de cada lado e do contorno
    img = binarizar(fit_em_caixa(img, lado, lado), ICONES_LIMIAR)
    return contorno(em_tela(img, tam, tam, "centro"))


# Cartas sem desenho próprio ainda (vieram com o Nicão e o Lucas no #242): ícone emprestado até o Codex entregar o delas.
ICONES_PROVISORIOS = {
    "abalo": "terremoto",  # Abalo sísmico: onda de choque da pancada no chão
    "muralha": "guardiao_pedra",  # Peso de muralha: empurra e atordoa mais
    "chuva": "adagas_voadoras",  # Chuva de adagas
    "mira": "fura",  # Mira longa: adagas mais longe e mais rápidas
}


def gerar_icones():
    cols, linhas = ICONES_GRADE
    esperado = (cols * ICONES_CELULA, linhas * ICONES_CELULA)
    folhas = {}
    feitos = []  # (id, categoria, folha, celula, icone 32, icone 16)
    ids = set()
    for folha, celula, categoria, cid in ler_indice_icones():
        if cid in ids:
            raise SystemExit("ID repetido no INDICE.md: %s" % cid)
        ids.add(cid)
        if folha not in folhas:
            caminho = os.path.join(ICONES_FONTE, "folha_%02d.png" % folha)
            im = Image.open(caminho).convert("RGB")
            if im.size != esperado and abs(im.width - esperado[0]) <= 4 and abs(im.height - esperado[1]) <= 4:
                # o gerador de imagem às vezes entrega 1-2 px a mais ou a menos: completa com branco ou corta a sobra
                tela = Image.new("RGB", esperado, (255, 255, 255))
                tela.paste(im, (0, 0))
                im = tela
            if im.size != esperado:
                raise SystemExit("%s: %dx%d, esperado %dx%d" % (caminho, im.width, im.height, esperado[0], esperado[1]))
            folhas[folha] = im
        k = celula - 1
        x0 = (k % cols) * ICONES_CELULA
        y0 = (k // cols) * ICONES_CELULA
        cel = folhas[folha].crop((x0, y0, x0 + ICONES_CELULA, y0 + ICONES_CELULA))
        feitos.append((cid, categoria, folha, celula, icone_da_celula(cel, ICONES_TAM), icone_da_celula(cel, ICONES_TAM_PEQUENO)))
    n = len(feitos)
    quant = quantizar_lista([f[4] for f in feitos] + [f[5] for f in feitos], ICONES_COR)
    os.makedirs(os.path.join(ICONES_SAIDA, "16"), exist_ok=True)
    icones = {}
    for i, (cid, categoria, folha, celula, _, _) in enumerate(feitos):
        quant[i].save(os.path.join(ICONES_SAIDA, cid + ".png"))
        quant[n + i].save(os.path.join(ICONES_SAIDA, "16", cid + ".png"))
        icones[cid] = {
            "arquivo": cid + ".png",
            "pequeno": "16/" + cid + ".png",
            "categoria": categoria,
            "folha": "folha_%02d.png" % folha,
            "celula": celula,
        }
        print("  %-24s %-10s folha %d celula %2d" % (cid, categoria, folha, celula))
    # cartas que ainda não têm desenho próprio usam, por enquanto, o ícone de outra carta parecida (pedido ao Codex)
    for cid, base in ICONES_PROVISORIOS.items():
        if cid not in icones and base in icones:
            icones[cid] = dict(icones[base], provisorio_de=base)
            print("  %-24s provisório: usa o ícone de %s" % (cid, base))
    # icones desenhados em codigo (gerar_icones_ataques.py, "proprio": true) nao vem de folha: preserva as entradas do indice anterior
    try:
        with open(os.path.join(ICONES_SAIDA, "indice.json"), encoding="utf-8") as f:
            for cid, entrada in json.load(f).get("icones", {}).items():
                if entrada.get("proprio") and cid not in icones:
                    icones[cid] = entrada
    except (OSError, ValueError):
        pass
    indice = {
        "_ajuda": ICONES_AJUDA,
        "_gerado_por": "jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py icones (nao edite a mao)",
        "tamanhos": {"carta": ICONES_TAM, "pequeno": ICONES_TAM_PEQUENO},
        "icones": icones,
    }
    with open(os.path.join(ICONES_SAIDA, "indice.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(indice, f, ensure_ascii=False, indent=1)
        f.write("\n")
    previa_icones([q for q in quant[:n]], [q for q in quant[n:]], ICONES_PREVIA)
    print("icones: %d cartas em %s (%d px) e 16/ (%d px), paleta de %d cores" % (n, ICONES_SAIDA, ICONES_TAM, ICONES_TAM_PEQUENO, ICONES_COR))
    print("previa", ICONES_PREVIA)


def previa_icones(grandes, pequenos, caminho):
    """Conferencia para olhar: os 32 px e os 16 px sobre o fundo escuro da carta, ambos em 3x (nearest)."""
    fundo = (34, 30, 42)
    colunas = 10
    passo = 3 * ICONES_TAM + 12
    blocos = [(grandes, ICONES_TAM), (pequenos, ICONES_TAM_PEQUENO)]
    altura = sum(((len(lista) + colunas - 1) // colunas) * passo + 12 for lista, _ in blocos)
    tela = Image.new("RGB", (colunas * passo, altura), fundo)
    y0 = 0
    for lista, tam in blocos:
        for i, im in enumerate(lista):
            g = im.resize((tam * 3, tam * 3), Image.NEAREST)
            tela.paste(g, ((i % colunas) * passo + 6, y0 + (i // colunas) * passo + 6), g)
        y0 += ((len(lista) + colunas - 1) // colunas) * passo + 12
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    tela.save(caminho)


# ------------------------------------------------------------------ estruturas do Marco 4 (python gerar_objetos.py marco4)
# Folha do Codex do Alisson (imagegen): fonte_arte/marco4/fonte_estruturas.png, 1774x887 sobre branco, grade 4x2.
# O LEIA-ME pede completar com 2 px brancos a direita e 1 px embaixo (1776x888 = celulas de 444 px). Uma peca por celula.
# Saida: projeto/assets/v2/marco4/ (enfeites.png, enfeites_normal.png e cenario.json, no formato do atlas da cara nova;
# v2/cenario.gd le esta pasta junto com a dos enfeites). Nao toca nas outras pastas nem nos outros modos.
MARCO4_FONTE = os.path.join(HORDAS, "fonte_arte", "marco4", "fonte_estruturas.png")
MARCO4_SAIDA = os.path.join(HORDAS, "projeto", "assets", "v2", "marco4")
MARCO4_PREVIA = os.path.join(HORDAS, "prints", "v2_marco4_estruturas.png")
MARCO4_PREVIA_COLISAO = os.path.join(HORDAS, "prints", "v2_marco4_colisao.png")
MARCO4_GRADE = (4, 2)        # colunas e linhas da folha (ordem: esquerda para a direita, de cima para baixo)
MARCO4_CELULA = 444          # lado de cada celula (4 x 444 = 1776, 2 x 444 = 888)
MARCO4_COR = 40              # paleta unica da folha toda, sem dithering (o teto dos enfeites)
# (nome no mapa, eixo do alvo, tamanho alvo em px no jogo, colisao). Colisao: [] = atravessavel; cada elipse e
# (x do centro, y da base e raio em x), em fracao da largura e da altura do sprite recortado (ry = 0,5 * rx).
MARCO4_ITENS = [
    # arco: duas pernas solidas, vao central livre (~47 px no jogo; o corpo do heroi tem 7 px de raio)
    ("m4_ruina", "L", 130, [(0.39, 0.90, 0.09), (0.74, 0.90, 0.09)]),
    # plinto de pedra: um disco na base
    ("m4_altar", "L", 74, [(0.5, 0.95, 0.36)]),
    # ponte de madeira: passa por cima, sem colisao (o caminho seguro dos espinhos e reto; ela ainda nao tem vao no mapa)
    ("m4_ponte", "L", 220, []),
    # corredor entre duas paredes de rocha: as paredes solidas, o chao livre (~82 px)
    ("m4_passagem", "L", 170, [(0.20, 0.92, 0.20), (0.80, 0.92, 0.20)]),
    # terraço: bloco solido (a escada e o topo nao sao caminho, como manda o LEIA-ME)
    ("m4_plato", "L", 190, [(0.5, 0.92, 0.36)]),
    # portao: os dois pilares solidos, o vao entre eles livre
    ("m4_portao", "L", 150, [(0.15, 0.95, 0.10), (0.83, 0.95, 0.12)]),
    ("m4_torre", "A", 170, [(0.5, 0.95, 0.31)]),
    ("m4_mirante", "L", 150, [(0.62, 0.94, 0.25)]),
]
MARCO4_AJUDA = (
    "Estruturas do Marco 4 da v2 (arte do Codex, folha em jogos/hordas/fonte_arte/marco4/). Nomes m4_* sao unicos no "
    "jogo: o mapa os usa em dados/v2_medio.json (objetos). pe = base no chao (a posicao do objeto); colisao em elipses "
    "relativas ao pe, como no atlas dos enfeites. Nao edite a mao: rode `python gerar_objetos.py marco4`."
)


def gerar_marco4():
    cols, linhas = MARCO4_GRADE
    largura, altura = cols * MARCO4_CELULA, linhas * MARCO4_CELULA
    fonte = Image.open(MARCO4_FONTE).convert("RGB")
    if fonte.width > largura or fonte.height > altura or largura - fonte.width > 2 or altura - fonte.height > 2:
        raise SystemExit("%s: %dx%d, esperado %dx%d (aceita ate 2 px de diferenca)"
                         % (MARCO4_FONTE, fonte.width, fonte.height, largura, altura))
    if len(MARCO4_ITENS) != cols * linhas:
        raise SystemExit("MARCO4_ITENS tem %d pecas, a grade tem %d celulas" % (len(MARCO4_ITENS), cols * linhas))
    tela = Image.new("RGB", (largura, altura), (255, 255, 255))
    tela.paste(fonte, (0, 0))
    sprites = []
    for k, (nome, eixo, alvo, colisao) in enumerate(MARCO4_ITENS):
        x0 = (k % cols) * MARCO4_CELULA
        y0 = (k // cols) * MARCO4_CELULA
        rec = recortar_celula(tela.crop((x0, y0, x0 + MARCO4_CELULA, y0 + MARCO4_CELULA)))
        rec = rec.crop(rec.getchannel("A").getbbox())
        alb = contorno(binarizar(escalar(rec, eixo, alvo), LIMIAR_ALFA))
        alb = alb.crop(alb.getbbox())
        nor = normal_do_objeto(alb)
        pe = pe_do_objeto(alb)
        formas = [_forma(fx * alb.width - pe[0], fy * alb.height - pe[1], max(COLISAO_RX_MIN, fr * alb.width))
                  for fx, fy, fr in colisao]
        sprites.append((nome, 1, alb, nor, pe, formas))
        print("  %-12s %3dx%-3d  (alvo %s %d)  pe %s  colisao %d" % (nome, alb.width, alb.height, eixo, alvo, pe, len(formas)))
    pos, larg_folha, alt_folha = empacotar([(s[2].width, s[2].height) for s in sprites])
    folha = Image.new("RGBA", (larg_folha, alt_folha), (0, 0, 0, 0))
    folha_n = Image.new("RGBA", (larg_folha, alt_folha), (128, 128, 255, 0))
    for (x, y), s in zip(pos, sprites):
        folha.paste(s[2], (x, y))
        folha_n.paste(s[3], (x, y))
    folha = quantizar(folha, MARCO4_COR)
    cores = len(folha.getcolors(1 << 20))
    os.makedirs(MARCO4_SAIDA, exist_ok=True)
    folha.save(os.path.join(MARCO4_SAIDA, "enfeites.png"))
    folha_n.save(os.path.join(MARCO4_SAIDA, "enfeites_normal.png"))
    itens = []
    for (x, y), (nome, _peso, alb, _nor, pe, formas) in zip(pos, sprites):
        itens.append({"nome": nome, "pe": pe, "regiao": [x, y, alb.width, alb.height], "colisao": formas})
    cen = {
        "_gerado_por": "jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py marco4 (nao edite a mao)",
        "_ajuda": MARCO4_AJUDA,
        "enfeites": "enfeites.png",
        "enfeites_normal": "enfeites_normal.png",
        "itens": itens,
    }
    with open(os.path.join(MARCO4_SAIDA, "cenario.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(cen, f, ensure_ascii=False, indent=1)
        f.write("\n")
    previa_colisao(folha, pos, sprites, MARCO4_PREVIA_COLISAO)
    previa([("fonte_estruturas.png", [(s[0], s[2], s[3]) for s in sprites])], MARCO4_PREVIA)
    print("marco4: %d estruturas em %s, folha %dx%d, paleta de %d cores" % (
        len(sprites), MARCO4_SAIDA, larg_folha, alt_folha, cores))
    print("previas", MARCO4_PREVIA, MARCO4_PREVIA_COLISAO)
# ------------------------------------------------------------------ molduras do HUD (modo "hud")
# Folhas do Codex (#290): 3 x 3 celulas, fundo branco, pecas soltas (cantos, bordas, centro). Vira texturas de 9-slice na escala do HUD.
HUD_FONTE = os.path.join(HORDAS, "fonte_arte", "hud_molduras")
HUD_SAIDA = os.path.join(HORDAS, "projeto", "v2", "hud")
HUD_PREVIA = os.path.join(HORDAS, "prints", "v2_hud_molduras.png")
HUD_LADO = 1254              # cada folha: 3 x 3 celulas de 418 px; aceita 1 a 2 px de diferenca (a geracao nao garante o tamanho exato)
HUD_TOLERANCIA = 2
HUD_COR = 32                 # paleta por textura, sem dithering
HUD_LIMIAR = 96              # alfa binario a 37%: a fina linha de metal nao some na reducao
HUD_MIOLO = 0.4              # fracao central de cada borda que sobra (as pontas tem arremate e nao se repetem)
HUD_MIOLO_LARG = 6           # largura final do trecho esticavel da borda (px)
# arquivo de saida, folha, espessura da borda em px de HUD. Cantos e bordas saem na mesma escala (a da espessura medida no braco do canto).
HUD_MOLDURAS = [
    ("moldura_retrato.png", "retrato.png", 6),
    ("moldura_barra.png", "barras.png", 4),
    ("moldura_habilidade.png", "habilidades.png", 4),
]


def hud_celulas(caminho):
    """As 9 pecas da folha (RGBA, fundo transparente, caixa justa), na ordem de leitura. Aceita 1-2 px de diferenca no tamanho."""
    im = Image.open(caminho).convert("RGB")
    if abs(im.width - HUD_LADO) > HUD_TOLERANCIA or abs(im.height - HUD_LADO) > HUD_TOLERANCIA:
        raise SystemExit("%s: %dx%d, esperado %dx%d (+-%d)" % (caminho, im.width, im.height, HUD_LADO, HUD_LADO, HUD_TOLERANCIA))
    lado_x = im.width / 3.0
    lado_y = im.height / 3.0
    pecas = []
    for k in range(9):
        x0 = round((k % 3) * lado_x)
        y0 = round((k // 3) * lado_y)
        cel = im.crop((x0, y0, round(x0 + lado_x), round(y0 + lado_y)))
        rgba = recortar_celula(cel)
        caixa_ = rgba.getchannel("A").getbbox()
        if caixa_ is None:
            raise SystemExit("%s: celula %d vazia" % (caminho, k + 1))
        pecas.append(rgba.crop(caixa_))
    return pecas


def hud_espessura_braco(canto, horizontal):
    """Espessura do braco reto do canto (px de origem): o menor entre as contagens de opacos nas colunas (ou linhas) a 10% e a 90% do lado.
    Uma delas cai no braco paralelo ao eixo (fino); a outra, no braco perpendicular (percorre o canto todo)."""
    a = canto.getchannel("A")
    w, h = canto.size
    if horizontal:
        cols = (int(w * 0.1), int(w * 0.9))
        return min(sum(1 for y in range(h) if a.getpixel((x, y)) >= 128) for x in cols)
    lins = (int(h * 0.1), int(h * 0.9))
    return min(sum(1 for x in range(w) if a.getpixel((x, y)) >= 128) for y in lins)


def hud_deslocamento_braco(canto, lado):
    """Distancia (px de origem) da borda externa do canto (lado "t", "b", "l" ou "r") ate o inicio do braco reto, lida longe do vertice."""
    a = canto.getchannel("A")
    w, h = canto.size
    if lado in ("t", "b"):
        x = min((int(w * 0.1), int(w * 0.9)), key=lambda c: sum(1 for y in range(h) if a.getpixel((c, y)) >= 128))
        ys = [y for y in range(h) if a.getpixel((x, y)) >= 128]
        return ys[0] if lado == "t" else h - 1 - ys[-1]
    y = min((int(h * 0.1), int(h * 0.9)), key=lambda c: sum(1 for x in range(w) if a.getpixel((x, c)) >= 128))
    xs = [x for x in range(w) if a.getpixel((x, y)) >= 128]
    return xs[0] if lado == "l" else w - 1 - xs[-1]


def hud_montar(pecas, alvo_espessura):
    """9-slice na escala do HUD: (imagem, margem do canto, relatorio)."""
    tl, topo, tr, esq, centro, dir_, bl, base, br = pecas
    # espessura de origem: a media dos bracos retos dos quatro cantos; a escala vem dela
    medidas = [hud_espessura_braco(c, h) for c in (tl, tr, bl, br) for h in (True, False)]
    esp_origem = sum(medidas) / float(len(medidas))
    s = alvo_espessura / esp_origem
    # os quatro cantos ficam quadrados do mesmo tamanho m (a diferenca de 1-2 px entre eles na folha some aqui), senao sobra frestas na emenda
    m = max(1, round(max(max(c.width, c.height) for c in (tl, tr, bl, br)) * s))
    cantos = [c.resize((m, m), Image.BOX) for c in (tl, tr, bl, br)]

    def miolo(p, horizontal):
        comp = p.width if horizontal else p.height
        ini = int(comp * (1.0 - HUD_MIOLO) / 2.0)
        fim = int(comp * (1.0 + HUD_MIOLO) / 2.0)
        corte = p.crop((ini, 0, fim, p.height)) if horizontal else p.crop((0, ini, p.width, fim))
        tam = (HUD_MIOLO_LARG, alvo_espessura) if horizontal else (alvo_espessura, HUD_MIOLO_LARG)
        return corte.resize(tam, Image.BOX)

    lado = 2 * m + HUD_MIOLO_LARG
    tela = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    tela.paste(cantos[0], (0, 0))
    tela.paste(cantos[1], (lado - cantos[1].width, 0))
    tela.paste(cantos[2], (0, lado - cantos[2].height))
    tela.paste(cantos[3], (lado - cantos[3].width, lado - cantos[3].height))
    # cada borda alinhada ao braco dos dois cantos vizinhos (o braco comeca um pouco depois da borda externa do canto)
    dt = round(s * (hud_deslocamento_braco(tl, "t") + hud_deslocamento_braco(tr, "t")) / 2.0)
    db = round(s * (hud_deslocamento_braco(bl, "b") + hud_deslocamento_braco(br, "b")) / 2.0)
    de = round(s * (hud_deslocamento_braco(tl, "l") + hud_deslocamento_braco(bl, "l")) / 2.0)
    dd = round(s * (hud_deslocamento_braco(tr, "r") + hud_deslocamento_braco(br, "r")) / 2.0)
    tela.paste(miolo(topo, True), (m, dt))
    tela.paste(miolo(base, True), (m, lado - alvo_espessura - db))
    tela.paste(miolo(esq, False), (de, m))
    tela.paste(miolo(dir_, False), (lado - alvo_espessura - dd, m))
    rel = "braco medido %s px de origem -> HUD %d px (escala %.4f), canto %d px" % (medidas, alvo_espessura, s, m)
    return tela, m, rel


def gerar_hud():
    os.makedirs(HUD_SAIDA, exist_ok=True)
    montados = []
    for saida, folha, espessura in HUD_MOLDURAS:
        pecas = hud_celulas(os.path.join(HUD_FONTE, folha))
        tela, margem, rel = hud_montar(pecas, espessura)
        montados.append((saida, binarizar(tela, HUD_LIMIAR), margem, espessura, rel))
    quant = quantizar_lista([mm[1] for mm in montados], HUD_COR)
    info = {}
    for (saida, _, margem, espessura, rel), img in zip(montados, quant):
        img.save(os.path.join(HUD_SAIDA, saida))
        info[saida] = {"margem": margem, "espessura": espessura, "tamanho": list(img.size)}
        print("  %-26s %dx%d margem %d  %s" % (saida, img.width, img.height, margem, rel))
    with open(os.path.join(HUD_SAIDA, "molduras_codex.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"_gerado_por": "jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py hud (nao edite a mao)",
                   "_ajuda": "9-slice das molduras do HUD (fonte: fonte_arte/hud_molduras). margem = patch_margin nos 4 lados; o centro fica transparente.",
                   "molduras": info}, f, ensure_ascii=False, indent=1)
        f.write("\n")
    os.makedirs(os.path.dirname(HUD_PREVIA), exist_ok=True)
    tela = Image.new("RGB", (len(quant) * 8 * 40 + 20, 8 * 40 + 40), (34, 30, 42))
    x = 20
    for img in quant:
        g = img.resize((img.width * 8, img.height * 8), Image.NEAREST)
        tela.paste(g, (x, 20), g)
        x += g.width + 20
    tela.save(HUD_PREVIA)
    print("previa", HUD_PREVIA)
# ------------------------------------------------------------------ arte das fusoes (v2, PR #289 do Codex): moldura, halo, Ventania e icone
# Fontes em jogos/hordas/fonte_arte/fusoes/ (RGBA com alfa real, sem recorte). Saida em projeto/assets/v2/fusoes/, com indice.json
# no mesmo esquema do indice das armas. A Ventania entra por ele e vale por cima da entrada de armas/ de mesma id (v2/armas_novas.gd).
FUSOES_FONTE = os.path.join(HORDAS, "fonte_arte", "fusoes")
FUSOES_SAIDA = os.path.join(HORDAS, "projeto", "assets", "v2", "fusoes")
FUSOES_PREVIA = os.path.join(HORDAS, "prints", "v2_fusoes_arte.png")
MOLDURA_TAM = (600, 200)           # o cartao da fusao (v2/hud.gd: FUSAO_L x FUSAO_A)
MOLDURA_BORDA = 12                 # margem do 9-slice no alvo: cantos de 12 x 12 px sem escala; so o miolo estica
MOLDURA_CANTO = 52                 # cantos e faixas da borda, em px da fonte: o filete dourado da fonte fica a 41-49 px da borda
MOLDURA_MIOLO = (10, 8, 20, 250)   # miolo liso #0a0814 para o texto (a fonte tem grao sobre o mesmo violeta)
MOLDURA_COR = 40                   # paleta unica da moldura, sem dithering
HALO_TAM = 48                      # halo branco: a cor da fusao vem do modulate (v2/armas.gd e v2/hud.gd)
DEGRAUS_ALFA = [0, 64, 128, 192, 255]  # o desvanecer do halo e da onda em faixas, sem meio-tom novo
VENTANIA_TAM = (64, 32)            # onda da Ventania Cortante: 2:1, como pede a especificacao
VENTANIA_LIMIAR = 40               # alfa abaixo disto some (o chiado de pixels claros da fonte)
VENTANIA_COR = 24                  # paleta unica da onda, sem dithering
ICONE_TAM = 16                     # icone da fusao: 16 px, mostrado em 2x; mesmo caminho dos icones de carta
FUSOES_AJUDA = (
    "Arte das fusoes da v2 (PR #289 do Codex; fontes em jogos/hordas/fonte_arte/fusoes/). moldura.png = 600x200 em 9-slice "
    "(borda de 12 px, NinePatchRect na HUD). halo.png = 48x48 branco, tingido pela cor da fusao. icone.png = 16x16, mostrado em 2x. "
    "sprites.ventania entra no registro de armas (v2/armas_novas.gd) e vale por cima da arte de armas/ de mesma id. "
    "Nao edite a mao: rode `python gerar_objetos.py fusoes`."
)


def _degrau(v, limiar=0):
    """Alfa v no degrau mais proximo de DEGRAUS_ALFA; abaixo de limiar some."""
    if v < limiar:
        return 0
    return min(DEGRAUS_ALFA, key=lambda n: abs(n - v))


def moldura_fusao(caminho):
    """Moldura 600 x 200 em 9-slice. O corpo da fonte (sem a margem transparente) e que vira o alvo: cantos de 40 px
    viram 12 x 12 px, as faixas viram 12 px de espessura, o miolo estica e fica liso. Sem reduzir o canvas inteiro."""
    im = Image.open(caminho).convert("RGBA")
    # o corpo e o alfa opaco (>= 128): com alfa > 12, pixels soltos acima da borda empurram o recorte e perdem o filete dourado
    corpo = im.crop(im.getchannel("A").point(lambda v: 255 if v >= LIMIAR_ALFA else 0).getbbox())
    w, h = corpo.size
    c, b = MOLDURA_CANTO, MOLDURA_BORDA
    tw, th = MOLDURA_TAM
    if w <= 2 * c or h <= 2 * c:
        raise SystemExit("moldura: corpo %dx%d pequeno demais para cantos de %d px" % (w, h, c))
    saida = Image.new("RGBA", (tw, th), MOLDURA_MIOLO)
    cantos = [
        ((0, 0), (0, 0, c, c)),
        ((tw - b, 0), (w - c, 0, w, c)),
        ((0, th - b), (0, h - c, c, h)),
        ((tw - b, th - b), (w - c, h - c, w, h)),
    ]
    for pos, caixa in cantos:
        saida.paste(corpo.crop(caixa).resize((b, b), Image.BOX), pos)
    saida.paste(corpo.crop((c, 0, w - c, c)).resize((tw - 2 * b, b), Image.BOX), (b, 0))
    saida.paste(corpo.crop((c, h - c, w - c, h)).resize((tw - 2 * b, b), Image.BOX), (b, th - b))
    saida.paste(corpo.crop((0, c, c, h - c)).resize((b, th - 2 * b), Image.BOX), (0, b))
    saida.paste(corpo.crop((w - c, c, w, h - c)).resize((b, th - 2 * b), Image.BOX), (tw - b, b))
    return quantizar_lista([binarizar(saida, LIMIAR_ALFA)], MOLDURA_COR)[0]


def halo_fusao(caminho):
    """Halo 48 x 48: BOX da fonte inteira (a margem transparente ja esta la), branco puro e alfa em degraus."""
    im = Image.open(caminho).convert("RGBA").resize((HALO_TAM, HALO_TAM), Image.BOX)
    saida = Image.new("RGBA", im.size, (255, 255, 255, 0))
    saida.putalpha(im.getchannel("A").point(_degrau))
    return saida


def ventania_fusao(caminho):
    """Onda 64 x 32: a fonte inteira vira 64 x 32 (BOX), alfa em degraus e o chiado claro some; cor por paleta sem dithering."""
    im = Image.open(caminho).convert("RGBA").resize(VENTANIA_TAM, Image.BOX)
    im.putalpha(im.getchannel("A").point(lambda v: _degrau(v, VENTANIA_LIMIAR)))
    return quantizar_lista([im], VENTANIA_COR)[0]


def icone_fusao(caminho):
    """Icone 16 x 16 pelo caminho dos icones de carta: caixa justa, quadrado, BOX em 14 px (1 px de folga), alfa binario a 25%
    e contorno escuro de 1 px (contorno() escurece a borda opaca)."""
    im = Image.open(caminho).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda v: 255 if v > LIMITE_FUNDO else 0).getbbox())
    lado = max(im.size)
    quadrado = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    quadrado.paste(im, ((lado - im.width) // 2, (lado - im.height) // 2))
    img = binarizar(fit_em_caixa(quadrado, ICONE_TAM - 2, ICONE_TAM - 2), ICONES_LIMIAR)
    img = contorno(em_tela(img, ICONE_TAM, ICONE_TAM, "centro"))
    return quantizar_lista([img], ICONES_COR)[0]


def previa_fusoes(feitos, caminho):
    """Conferencia para olhar: moldura em 1x e as outras em escala inteira (nearest), sobre o fundo do cartao."""
    tela = Image.new("RGBA", (980, 420), (34, 30, 42, 255))

    def cola(img, x, y, s):
        tela.alpha_composite(img.resize((img.width * s, img.height * s), Image.NEAREST), (x, y))

    cola(feitos["moldura"], 10, 10, 1)
    cola(feitos["halo"], 620, 10, 4)
    cola(feitos["ventania"], 620, 230, 3)
    cola(feitos["icone"], 840, 230, 6)
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    tela.convert("RGB").save(caminho)


def gerar_fusoes():
    os.makedirs(FUSOES_SAIDA, exist_ok=True)
    feitos = {
        "moldura": moldura_fusao(os.path.join(FUSOES_FONTE, "moldura.png")),
        "halo": halo_fusao(os.path.join(FUSOES_FONTE, "halo.png")),
        "ventania": ventania_fusao(os.path.join(FUSOES_FONTE, "ventania.png")),
        "icone": icone_fusao(os.path.join(FUSOES_FONTE, "icone.png")),
    }
    for nome, img in feitos.items():
        img.save(os.path.join(FUSOES_SAIDA, nome + ".png"))
        print("  %-9s %3dx%-3d" % (nome, img.width, img.height))
    tam = {nome: [img.width, img.height] for nome, img in feitos.items()}
    indice = {
        "_ajuda": FUSOES_AJUDA,
        "_gerado_por": "jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py fusoes (nao edite a mao)",
        "sprites": {
            "ventania": {
                "arquivo": "ventania.png",
                "normal": None,
                "tipo": "area",
                "familia": "katana",
                "tamanho": tam["ventania"],
                "armas_sugeridas": ["ventania"],
                "armas_aproximadas": [],
                "obs": "arte da fusao Ventania Cortante (Codex, #289): troca a onda da evolucao",
            },
        },
        "arte": {
            "moldura": {"arquivo": "moldura.png", "tamanho": tam["moldura"], "borda": MOLDURA_BORDA},
            "halo": {"arquivo": "halo.png", "tamanho": tam["halo"]},
            "icone": {"arquivo": "icone.png", "tamanho": tam["icone"]},
        },
    }
    with open(os.path.join(FUSOES_SAIDA, "indice.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(indice, f, ensure_ascii=False, indent=1)
        f.write("\n")
    previa_fusoes(feitos, FUSOES_PREVIA)
    print("previa", FUSOES_PREVIA)


# ------------------------------------------------------------------ icones do Q por heroi (v2): fontes do Codex (#349) -> 32 px
ESPECIAL_Q_FONTE = os.path.join(HORDAS, "fonte_arte", "especial_q")
ESPECIAL_Q_SAIDA = os.path.join(HORDAS, "projeto", "assets", "v2", "especial_q")
ESPECIAL_Q_HEROIS = ("hazaki", "nicao", "lucas")  # o nome do arquivo e a chave do heroi (v2/herois.gd): o circulo do Q (v2/hud_ultimate.gd) o procura por ela


def icone_especial_q(caminho):
    """Icone 32 x 32 pelo caminho dos icones de carta. A fonte (1254 px) traz residuos de alfa 1 a 8 nas bordas: so o alfa acima de LIMITE_FUNDO
    entra na caixa justa. Depois: quadrado, BOX em 30 px (1 px de folga), alfa binario a 25% e contorno escuro de 1 px."""
    im = Image.open(caminho).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda v: 255 if v > LIMITE_FUNDO else 0).getbbox())
    lado = max(im.size)
    quadrado = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    quadrado.paste(im, ((lado - im.width) // 2, (lado - im.height) // 2))
    img = binarizar(fit_em_caixa(quadrado, ICONES_TAM - 2, ICONES_TAM - 2), ICONES_LIMIAR)
    return contorno(em_tela(img, ICONES_TAM, ICONES_TAM, "centro"))


def gerar_especiais_q():
    os.makedirs(ESPECIAL_Q_SAIDA, exist_ok=True)
    feitos = [icone_especial_q(os.path.join(ESPECIAL_Q_FONTE, h + ".png")) for h in ESPECIAL_Q_HEROIS]
    for h, img in zip(ESPECIAL_Q_HEROIS, quantizar_lista(feitos, ICONES_COR)):
        img.save(os.path.join(ESPECIAL_Q_SAIDA, h + ".png"))
        print("  %-7s %dx%d" % (h, img.width, img.height))


# ------------------------------------------------------------------ icones da E (#387): mesma receita/paleta do Q, sem substituir icones de cartas ou escudo secundario
def gerar_habilidades_e():
    fonte = os.path.join(HORDAS, "fonte_arte", "habilidade_e")
    saida = os.path.join(HORDAS, "projeto", "assets", "v2", "habilidade_e")
    herois = ("nicao", "lucas")
    os.makedirs(saida, exist_ok=True)
    feitos = [icone_especial_q(os.path.join(fonte, h + ".png")) for h in herois]
    for h, img in zip(herois, quantizar_lista(feitos, ICONES_COR)):
        img.save(os.path.join(saida, h + ".png"))
        print("  %-7s %dx%d" % (h, img.width, img.height))


# ------------------------------------------------------------------ bustos dos chefes da v2 (#360): fontes do Codex (#349) -> barra do chefe, 36 px
CHEFES_FONTE = os.path.join(HORDAS, "fonte_arte", "chefes_v2")
CHEFES_SAIDA = os.path.join(HORDAS, "projeto", "assets", "v2", "chefes")
CHEFES_BUSTOS = ("cavaleiro_rubro", "rainha_tecela", "rei_espantalho")  # o nome do arquivo e a chave do busto em v2/hud.gd (BUSTOS)
CHEFES_TAM = 36  # a barra do chefe tem 46 px com a moldura de pedra de 5 px: o busto cabe no miolo, sem encostar na moldura


def icone_chefe(caminho):
    """Busto 36 x 36: a mesma receita do Q (caixa justa, sem os residuos de alfa 1 a 8 das fontes, BOX em 34 px, alfa binario a 25%, contorno de 1 px)."""
    im = Image.open(caminho).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda v: 255 if v > LIMITE_FUNDO else 0).getbbox())
    lado = max(im.size)
    quadrado = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    quadrado.paste(im, ((lado - im.width) // 2, (lado - im.height) // 2))
    img = binarizar(fit_em_caixa(quadrado, CHEFES_TAM - 2, CHEFES_TAM - 2), ICONES_LIMIAR)
    return contorno(em_tela(img, CHEFES_TAM, CHEFES_TAM, "centro"))


def gerar_chefes():
    os.makedirs(CHEFES_SAIDA, exist_ok=True)
    feitos = [icone_chefe(os.path.join(CHEFES_FONTE, b + ".png")) for b in CHEFES_BUSTOS]
    for b, img in zip(CHEFES_BUSTOS, quantizar_lista(feitos, ICONES_COR)):
        img.save(os.path.join(CHEFES_SAIDA, b + ".png"))
        print("  %-14s %dx%d" % (b, img.width, img.height))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "especial_q":
        gerar_especiais_q()
    elif len(sys.argv) > 1 and sys.argv[1] == "habilidade_e":
        gerar_habilidades_e()
    elif len(sys.argv) > 1 and sys.argv[1] == "hud":
        gerar_hud()
    elif len(sys.argv) > 1 and sys.argv[1] == "armas":
        gerar_armas()
    elif len(sys.argv) > 1 and sys.argv[1] == "icones":
        gerar_icones()
    elif len(sys.argv) > 1 and sys.argv[1] == "marco4":
        gerar_marco4()
    elif len(sys.argv) > 1 and sys.argv[1] == "fusoes":
        gerar_fusoes()
    elif len(sys.argv) > 1 and sys.argv[1] == "chefes":
        gerar_chefes()
    else:
        main()

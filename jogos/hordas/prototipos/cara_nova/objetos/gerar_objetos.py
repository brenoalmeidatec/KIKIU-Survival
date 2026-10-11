"""Gera a folha de enfeites da cara nova (vegetacao + pedras e ruinas) para o protototipo 2.5D.

Entrada (ao lado deste script, com fundo branco/transparente):
    fonte_vegetacao.webp   9 objetos em 2 linhas (5 + 4)
    fonte_pedras.webp      14 objetos em 3 linhas (5 + 5 + 4)

Saida, em jogos/hordas/projeto/prototipos/objetos/ (mesmo layout nas duas folhas):
    enfeites.png           albedo: cor chapada, alfa binario, contorno escuro de 1 px
    enfeites_normal.png    normal map (R = x, G = y para cima, B = z), mesma convencao do gerar_cara_nova.py
    cenario.json           itens com nome, peso, pe (base dentro da regiao) e regiao [x, y, w, h]
    e a previa em jogos/hordas/prints/prototipo_objetos_novos.png

Uso (so precisa de Pillow):
    python gerar_objetos.py

Passos: fundo = alfa 0 (ou branco) ligado a borda, por flood fill; objetos = componentes do que sobrou,
juntados por proximidade; ordem = linha e coluna; BOX para a escala do jogo; alfa binario a 50%;
quantizacao sem dithering; normal = domo pela distancia ate a borda + um pouco da luminancia.
"""
import json
import math
import os

from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
HORDAS = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
SAIDA = os.path.join(HORDAS, "projeto", "prototipos", "objetos")
PREVIA = os.path.join(HORDAS, "prints", "prototipo_objetos_novos.png")

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
]

LIMITE_FUNDO = 12        # alfa <= isto conta como fundo (ruido de compressao)
MIN_RUIDO = 12           # pedacos com menos pixels que isto sao descartados
GAP_JUNTA = 6            # pedacos cujas caixas ficam a menos disto (px da fonte) viram o mesmo objeto
LIMIAR_ALFA = 128        # alfa binario: 50%
COR_MAX = 40             # cores da folha toda (albedo)
LARGURA_FOLHA = 480      # largura maxima da folha em px (empacotamento em prateleiras)
PAD = 2                  # espaco entre sprites na folha
ESTICA = 2.0             # exagero da inclinacao da normal
ALTURA_LUM = 0.25        # quanto a luminancia entra no relevo (casca, folhas)
ALTURA_BORDA = 0.30      # raio do domo = este fracao do menor lado (limitado entre 3 e 10 px)
RAIO_MIN, RAIO_MAX = 3.0, 10.0
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


def agrupar(w, h, data, nome_folha, esperado, linhas):
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
    mudou = True
    while mudou:
        mudou = False
        for a in range(len(grupos)):
            for b in range(a + 1, len(grupos)):
                if dist_caixas(grupos[a]["caixa"], grupos[b]["caixa"]) <= GAP_JUNTA:
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


def binarizar(img):
    w, h = img.size
    dados = bytearray(img.tobytes())
    for i in range(w * h):
        j = i * 4
        if dados[j + 3] < LIMIAR_ALFA:
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


# ------------------------------------------------------------------ normal map
def normal_do_objeto(img):
    """Domo pela distancia ate a borda do alfa + um pouco da luminancia; suaviza 1 passe."""
    w0, h0 = img.size
    base = Image.new("RGBA", (w0 + 2, h0 + 2), (0, 0, 0, 0))
    base.paste(img, (1, 1))
    w, h = base.size
    dados = base.tobytes()
    alfa = dados[3::4]
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
    raio = max(RAIO_MIN, min(RAIO_MAX, ALTURA_BORDA * min(w0, h0)))
    H = [0.0] * (w * h)
    for i in range(w * h):
        if alfa[i] == 0:
            continue
        j = i * 4
        lum = (0.299 * dados[j] + 0.587 * dados[j + 1] + 0.114 * dados[j + 2]) / 255.0
        t = min(d[i] / raio, 1.0)
        H[i] = math.sqrt(max(0.0, 1.0 - (1.0 - t) ** 2)) + ALTURA_LUM * lum

    def h_em(x, y):
        return H[y * w + x] if 0 <= x < w and 0 <= y < h else 0.0

    NX = [0.0] * (w * h)
    NY = [0.0] * (w * h)
    NZ = [1.0] * (w * h)
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if alfa[i] == 0:
                continue
            dhx = (h_em(x + 1, y) - h_em(x - 1, y)) / 2.0
            dhy = (h_em(x, y + 1) - h_em(x, y - 1)) / 2.0
            nx = -ESTICA * dhx
            ny = ESTICA * dhy           # y de imagem cresce para baixo; G da normal sobe
            m = math.sqrt(nx * nx + ny * ny + 1.0)
            NX[i], NY[i], NZ[i] = nx / m, ny / m, 1.0 / m
    # 1 passe de suavizacao 3x3 so entre pixels opacos
    SX, SY, SZ = list(NX), list(NY), list(NZ)
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if alfa[i] == 0:
                continue
            ax = ay = az = 0.0
            n = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and alfa[yy * w + xx]:
                        k = yy * w + xx
                        ax += NX[k]
                        ay += NY[k]
                        az += NZ[k]
                        n += 1
            ax, ay, az = ax / n, ay / n, az / n
            m = math.sqrt(ax * ax + ay * ay + az * az) or 1.0
            SX[i], SY[i], SZ[i] = ax / m, ay / m, az / m
    out = bytearray(w * h * 4)
    for i in range(w * h):
        j = i * 4
        if alfa[i] == 0:
            out[j:j + 4] = b"\x80\x80\xff\x00"
        else:
            out[j] = max(0, min(255, int(round((SX[i] * 0.5 + 0.5) * 255))))
            out[j + 1] = max(0, min(255, int(round((SY[i] * 0.5 + 0.5) * 255))))
            out[j + 2] = max(0, min(255, int(round((SZ[i] * 0.5 + 0.5) * 255))))
            out[j + 3] = 255
    normal = Image.frombytes("RGBA", (w, h), bytes(out))
    return normal.crop((1, 1, w0 + 1, h0 + 1))


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


def previa(faixas, caminho):
    """Faixas (lista de (titulo, [(nome, albedo, normal)])) em escala 3x: albedo em cima, normal embaixo."""
    ESC = 3
    GAP = 14
    fonte = ImageFont.load_default(size=13)
    cinza = (0x5a, 0x5a, 0x64, 255)
    alturas = []
    larguras = []
    for _, itens in faixas:
        larg = sum(a.width * ESC + GAP for _, a, _n in itens) + GAP
        alt = max(a.height for _, a, _n in itens) * ESC
        larguras.append(larg)
        alturas.append(alt * 2 + 60)
    tela = Image.new("RGBA", (max(larguras), sum(alturas) + 20 * len(faixas)), cinza)
    d = ImageDraw.Draw(tela)
    y0 = 10
    for (titulo, itens), alt in zip(faixas, alturas):
        d.text((GAP, y0), titulo, fill=(255, 255, 255, 255), font=fonte)
        y_alb = y0 + 24
        alt_linha = max(a.height for _, a, _n in itens) * ESC
        y_nor = y_alb + alt_linha + 14
        x = GAP
        for nome, alb, nor in itens:
            a3 = alb.resize((alb.width * ESC, alb.height * ESC), Image.NEAREST)
            n3 = nor.resize((nor.width * ESC, nor.height * ESC), Image.NEAREST)
            tela.alpha_composite(a3, (x, y_alb + alt_linha - a3.height))
            tela.alpha_composite(n3, (x, y_nor + alt_linha - n3.height))
            d.text((x, y_nor + alt_linha + 4), nome, fill=(230, 230, 230, 255), font=fonte)
            x += a3.width + GAP
        y0 += alt + 20
    tela.convert("RGB").save(caminho)


def main():
    if not os.path.isdir(SAIDA):
        os.makedirs(SAIDA)
    sprites = []      # (nome, peso, albedo, normal, pe)
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
            pe = pe_do_objeto(alb)
            sprites.append((nome, peso, alb, nor, pe))
            itens.append((nome, alb, nor))
            print("  %-15s %3dx%-3d  (alvo %s %d)  pe %s" % (nome, alb.width, alb.height, eixo, alvo, pe))
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

    itens = []
    for (x, y), (nome, peso, alb, _nor, pe) in zip(pos, sprites):
        itens.append({"nome": nome, "peso": peso, "pe": pe, "regiao": [x, y, alb.width, alb.height]})
    cen = {
        "_gerado_por": "jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py (nao edite a mao)",
        "enfeites": "enfeites.png",
        "enfeites_normal": "enfeites_normal.png",
        "ambiente": AMBIENTE,
        "itens": itens,
        "fixos": [],
    }
    with open(os.path.join(SAIDA, "cenario.json"), "w", encoding="utf-8") as f:
        json.dump(cen, f, ensure_ascii=False, indent=1)
        f.write("\n")
    previa([(arq, itens_) for arq, itens_ in faixas], PREVIA)
    print("previa", PREVIA)


if __name__ == "__main__":
    main()

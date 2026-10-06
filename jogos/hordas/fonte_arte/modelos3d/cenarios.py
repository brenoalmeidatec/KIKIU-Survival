"""Os 3 cenários do K.I.K.I.U (dark fantasy, pixel art com luz do Blender):
laboratório de alquimia, masmorra e cidade à noite (ruas de pedra).

Roda (Blender 4.5 LTS):
    blender -b -P cenarios.py
Saída por cenário em ../../projeto/assets/cenarios/<nome>/:
    piso.png      azulejo 256x256 que repete sem emenda (visto de cima, 1 px de jogo = 1 px de tela)
    enfeites.png  atlas com os enfeites (vistos de 3/4, como os personagens) e os halos de luz
    cenario.json  onde está cada enfeite no atlas, o ponto do pé, a luz de cada um e o tom do ambiente

A luz é "assada" pelo Blender (mesma direção das sombras do jogo). No jogo só entram truques baratos:
tom de ambiente (CanvasModulate) e halos somados (blend ADD). Roda em qualquer PC.
"""
import json
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import pixel3d as px3  # noqa: E402
from pixel3d import caixa, cilindro, cone, esfera  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "cenarios"))
PX = 60.0 / 2.55            # pixels por unidade do Blender (a mesma densidade do cavaleiro: tudo em 1x)
PISO = 256                  # lado do azulejo do chão, em pixels
L = PISO / PX               # lado do azulejo no mundo do Blender
ENFEITE = 128               # tela onde cada enfeite é renderizado antes do recorte
FATOR = 4                   # piso renderizado 4x maior e reduzido pela média (pré-renderizado)
RUA = 7.0                   # cidade: largura da rua e da calçada (unidades do Blender; 1 = ~23,5 px)
CALCADA = 2.0


SUAVE = [False]   # True enquanto monta o piso (render suave no Cycles, onde o toon não funciona)


def toon(hexa, nome=None, **kw):
    if SUAVE[0]:
        return px3.material_suave("s_" + hexa, px3.cor(hexa))
    return px3.material_toon(nome or ("m_" + hexa), px3.cor(hexa), **kw)


def chao(hexa, ruido=0.18):
    """Material de piso (render suave: a luz real e a oclusão nas frestas fazem o volume)."""
    return px3.material_suave("p_" + hexa, px3.cor(hexa), rugosidade=0.9, relevo=0.9, variacao=0.32, escala=3.0)


def brilha(hexa, forca=1.0):
    return px3.material_emissao("e_" + hexa, px3.cor(hexa), forca)


# ================================================================ pisos (vistos de cima, repetem sem emenda)

def piso_masmorra(r):
    caixa("rejunte", (L, L, 0.1), (L / 2, L / 2, -0.05), toon("2c2724"))
    pedras = [chao(h) for h in ("5e544a", "544b42", "675c50", "4a423a")]
    musgo = toon("35473a")
    trinca = toon("1a1716")
    n = 4
    c = L / n
    for i in range(n):
        for j in range(n):
            partes = [(i * c, j * c, c, c)]
            if r.random() < 0.45:   # algumas lajes partidas em duas
                if r.random() < 0.5:
                    partes = [(i * c, j * c, c / 2, c), (i * c + c / 2, j * c, c / 2, c)]
                else:
                    partes = [(i * c, j * c, c, c / 2), (i * c, j * c + c / 2, c, c / 2)]
            for (x, y, w, h) in partes:
                alt = 0.25 + r.random() * 0.08
                caixa("laje", (w - 0.16, h - 0.16, alt), (x + w / 2, y + h / 2, alt / 2), r.choice(pedras),
                      rot=(r.uniform(-0.02, 0.02), r.uniform(-0.02, 0.02), r.uniform(-0.015, 0.015)), chanfro=0.1)
                if r.random() < 0.3:
                    caixa("trinca", (w * 0.5, 0.04, 0.02), (x + w / 2, y + h * r.uniform(0.3, 0.7), alt + 0.01), trinca,
                          rot=(0, 0, r.uniform(-0.6, 0.6)))
                if r.random() < 0.25:   # tufo de musgo: bolinhas achatadas espalhadas no canto da laje
                    mx, my = x + 0.2, y + r.uniform(0.3, h - 0.3)
                    for _ in range(6):
                        esfera("musgo", r.uniform(0.05, 0.11), (mx + r.uniform(-0.15, 0.15), my + r.uniform(-0.2, 0.2), alt),
                               musgo, escala=(1, 1, 0.35))


def piso_laboratorio(r):
    caixa("rejunte", (L, L, 0.1), (L / 2, L / 2, -0.05), toon("1d1a2b"))
    escuro, claro = chao("2e2a40", 0.1), chao("45405c", 0.1)
    mancha = brilha("1d4a2a", 0.6)
    n = 8
    c = L / n
    for i in range(n):
        for j in range(n):
            alt = 0.12 + r.random() * 0.03
            caixa("ladrilho", (c - 0.08, c - 0.08, alt), (i * c + c / 2, j * c + c / 2, alt / 2),
                  claro if (i + j) % 2 == 0 else escuro, chanfro=0.05)
    for _ in range(3):   # respingos de poção (fracos, só um brilho no chão)
        x, y = r.uniform(1, L - 1), r.uniform(1, L - 1)
        for k in range(4):
            cilindro("respingo", r.uniform(0.08, 0.25), 0.02, (x + r.uniform(-0.4, 0.4), y + r.uniform(-0.4, 0.4), 0.16),
                     mancha, vertices=8)


def piso_cidade(r):
    """Um cruzamento de ruas (referência: cidade vista de cima, em loop). O azulejo repete: o mapa vira uma grade
    de ruas. Asfalto com relevo e rachaduras, faixa tracejada, faixa de pedestre, calçada elevada com meio-fio,
    bueiro e, nos cantos, calçamento de praça. Os postes ficam fixos nas 4 esquinas (veja FIXOS_CIDADE)."""
    c = L / 2
    rw, sw = RUA, CALCADA
    asfalto = px3.material_suave("asfalto", px3.cor("2e2b33"), rugosidade=0.7, relevo=0.6, variacao=0.22, escala=2.0)
    remendo = px3.material_suave("remendo", px3.cor("25232a"), rugosidade=0.7, relevo=0.4, variacao=0.1, escala=3.0)
    tinta = px3.material_suave("tinta", px3.cor("d6ccb2"), rugosidade=0.5, relevo=0.3, variacao=0.08, escala=6.0)
    amarelo = px3.material_suave("amarelo", px3.cor("c49a45"), rugosidade=0.5, relevo=0.3, variacao=0.08, escala=6.0)
    calcada = [chao(h) for h in ("766a5d", "6c6155")]
    meiofio = chao("958775", 0.1)
    praca = [chao(h) for h in ("5e544a", "544b42", "675c50")]
    ferro = px3.material_suave("ferro", px3.cor("1d1a2b"), rugosidade=0.4)
    # asfalto (o chão todo) e uns remendos
    caixa("asfalto", (L, L, 0.1), (c, c, -0.05), asfalto)
    for _ in range(3):
        caixa("remendo", (r.uniform(1.0, 2.2), r.uniform(0.8, 1.6), 0.02), (r.uniform(c - rw / 2 + 1, c + rw / 2 - 1),
              r.choice((r.uniform(0.5, c - rw / 2 - 1), r.uniform(c + rw / 2 + 1, L - 0.5))), 0.005), remendo)
    # calçadas (faixas em volta das ruas) e praça nos 4 cantos
    for qx in (0, 1):
        for qy in (0, 1):
            x0 = 0.0 if qx == 0 else c + rw / 2
            y0 = 0.0 if qy == 0 else c + rw / 2
            x1 = c - rw / 2 if qx == 0 else L
            y1 = c - rw / 2 if qy == 0 else L
            # meio-fio: um degrau claro em volta do quarteirão
            caixa("meiofio", (x1 - x0, y1 - y0, 0.18), ((x0 + x1) / 2, (y0 + y1) / 2, 0.09), meiofio, chanfro=0.05)
            # placas de concreto da calçada (faixa de largura sw junto da rua)
            for (ax, ay, bx, by) in ((x0, y0, x1, y1),):
                passo = 0.9
                xs = [ax + 0.12 + passo * k for k in range(int((bx - ax - 0.24) / passo))]
                ys = [ay + 0.12 + passo * k for k in range(int((by - ay - 0.24) / passo))]
                for x in xs:
                    for y in ys:
                        perto_rua = (min(abs(x - (c - rw / 2)), abs(x + passo - (c + rw / 2))) < sw or
                                     min(abs(y - (c - rw / 2)), abs(y + passo - (c + rw / 2))) < sw)
                        mat = r.choice(calcada) if perto_rua else r.choice(praca)
                        caixa("placa", (passo - 0.06, passo - 0.06, 0.05), (x + passo / 2, y + passo / 2, 0.205), mat,
                              chanfro=0.02)
    # faixa tracejada no meio das duas ruas (para antes da faixa de pedestre)
    for k in range(int(L / 1.2)):
        p = 0.3 + k * 1.2
        if abs(p + 0.35 - c) < rw / 2 + 1.6:
            continue
        caixa("tracejado", (0.7, 0.1, 0.01), (p + 0.35, c, 0.006), amarelo)
        caixa("tracejado", (0.1, 0.7, 0.01), (c, p + 0.35, 0.006), amarelo)
    # faixa de pedestre nos 4 lados do cruzamento
    for lado in (-1, 1):
        for k in range(7):
            o = -rw / 2 + 0.55 + k * (rw - 1.1) / 6.0
            caixa("zebra", (1.1, 0.42, 0.01), (c + lado * (rw / 2 + 0.75), c + o, 0.006), tinta)
            caixa("zebra", (0.42, 1.1, 0.01), (c + o, c + lado * (rw / 2 + 0.75), 0.006), tinta)
        caixa("parada", (0.12, rw * 0.46, 0.01), (c + lado * (rw / 2 + 1.55), c - lado * rw * 0.24, 0.006), tinta)
        caixa("parada", (rw * 0.46, 0.12, 0.01), (c + lado * rw * 0.24, c + lado * (rw / 2 + 1.55), 0.006), tinta)
    # bueiro e grade de escoamento junto do meio-fio
    cilindro("bueiro", 0.42, 0.03, (c + rw * 0.28, c - rw * 0.3, 0.015), ferro, vertices=16, chanfro=0.02)
    caixa("grade", (0.9, 0.35, 0.03), (c - rw / 2 + 0.25, c + rw * 0.32, 0.015), ferro)
    # rachaduras no asfalto
    for _ in range(4):
        x, y = r.uniform(0.5, L - 0.5), r.choice((r.uniform(c - rw / 2 + 0.4, c + rw / 2 - 0.4),))
        for s in range(3):
            caixa("racha", (r.uniform(0.3, 0.6), 0.04, 0.01), (x + s * 0.3, y + r.uniform(-0.15, 0.15), 0.004),
                  remendo, rot=(0, 0, r.uniform(-0.8, 0.8)))


def repetir_3x3():
    """Cerca o azulejo com 8 cópias dele: luz e sombra também se repetem, sem emenda na borda."""
    originais = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            for o in originais:
                c = o.copy()
                c.location = (o.location.x + dx * L, o.location.y + dy * L, o.location.z)
                bpy.context.collection.objects.link(c)


# ================================================================ enfeites (vistos de 3/4)
# Cada um devolve a fonte de luz (ponto 3D + rampa + raio) ou None.

def tocha_em_pe():
    ferro, chama = toon("2e2a40"), brilha("f0921e", 1.0)
    cilindro("haste", 0.06, 1.6, (0, 0, 0.8), ferro, vertices=8)
    cilindro("base", 0.22, 0.08, (0, 0, 0.04), ferro, vertices=8, chanfro=0.02)
    cone("braseiro", 0.12, 0.26, 0.22, (0, 0, 1.68), ferro, vertices=10)
    cone("chama", 0.2, 0.0, 0.45, (0, 0, 1.98), chama, vertices=8)
    cone("miolo", 0.1, 0.0, 0.3, (0, -0.06, 1.92), brilha("ffd060", 1.0), vertices=6)
    return {"ponto": (0, 0, 1.95), "rampa": "fogo", "raio": 64, "pisca": 0.18}


def barril():
    madeira, aro = toon("6e4c32"), toon("2e2a40")
    cilindro("barril", 0.34, 0.8, (0, 0, 0.4), madeira, vertices=14, chanfro=0.03)
    for z in (0.15, 0.65):
        cilindro("aro", 0.355, 0.06, (0, 0, z), aro, vertices=14)
    return None


def pilha_ossos(r):
    osso = toon("d6ccb2")
    for k in range(5):
        caixa("osso", (0.5, 0.07, 0.07), (r.uniform(-0.3, 0.3), r.uniform(-0.25, 0.25), 0.05 + 0.04 * k), osso,
              rot=(0, 0, r.uniform(0, math.pi)))
    esfera("cranio", 0.16, (0.05, -0.05, 0.22), osso, escala=(1, 1.1, 0.9))
    caixa("olho", (0.05, 0.02, 0.04), (-0.01, -0.21, 0.24), toon("0d0b14"))
    caixa("olho2", (0.05, 0.02, 0.04), (0.11, -0.21, 0.24), toon("0d0b14"))
    return None


def caixote():
    madeira, escura = toon("9a6d45"), toon("4a3324")
    caixa("caixote", (0.7, 0.7, 0.6), (0, 0, 0.3), madeira, chanfro=0.04)
    for z in (0.12, 0.48):
        caixa("tabua", (0.72, 0.72, 0.06), (0, 0, z), escura)
    caixa("diagonal", (0.06, 0.72, 0.5), (0, -0.01, 0.3), escura, rot=(0.75, 0, 0))
    return None


def coluna_quebrada(r):
    pedra = toon("7d7163")
    cilindro("base", 0.4, 0.2, (0, 0, 0.1), pedra, vertices=10, chanfro=0.03)
    cilindro("fuste", 0.3, 1.1, (0, 0, 0.75), pedra, vertices=10)
    caixa("quebra", (0.5, 0.5, 0.3), (0.05, 0, 1.3), pedra, rot=(0.4, 0.3, 0.2), chanfro=0.05)
    for k in range(3):
        caixa("caco", (0.18, 0.14, 0.1), (r.uniform(-0.6, 0.6), r.uniform(-0.5, 0.3), 0.05), pedra,
              rot=(0, 0, r.uniform(0, 3)), chanfro=0.02)
    return None


def grilhao():
    madeira, ferro = toon("4a3324"), toon("45405c")
    caixa("poste", (0.18, 0.18, 1.4), (0, 0, 0.7), madeira, chanfro=0.03)
    for k in range(6):
        cilindro("elo", 0.06, 0.03, (0.14, -0.05, 1.2 - k * 0.12), ferro, rot=(math.pi / 2, 0, (k % 2) * math.pi / 2), vertices=8)
    cilindro("algema", 0.12, 0.05, (0.14, -0.05, 0.45), ferro, rot=(math.pi / 2, 0, 0), vertices=10)
    return None


def mesa_alquimia(r):
    madeira, latao = toon("6e4c32"), toon("c49a45")
    caixa("tampo", (1.3, 0.7, 0.08), (0, 0, 0.75), madeira, chanfro=0.02)
    for x in (-0.55, 0.55):
        for y in (-0.28, 0.28):
            caixa("perna", (0.08, 0.08, 0.72), (x, y, 0.36), madeira)
    cores = ["56b04a", "a6e070", "b0342f", "3a5794"]
    for k, x in enumerate((-0.45, -0.15, 0.2, 0.45)):
        cor = cores[k % len(cores)]
        esfera("frasco", 0.11, (x, r.uniform(-0.1, 0.1), 0.92), brilha(cor, 0.9))
        cilindro("gargalo", 0.035, 0.14, (x, 0, 1.06), latao, vertices=6)
    return {"ponto": (0, 0, 1.0), "rampa": "veneno", "raio": 44, "pisca": 0.05}


def caldeirao():
    ferro, liquido = toon("2e2a40"), brilha("56b04a", 1.0)
    esfera("panela", 0.45, (0, 0, 0.45), ferro, escala=(1, 1, 0.8))
    cilindro("borda", 0.4, 0.06, (0, 0, 0.82), ferro, vertices=14)
    cilindro("caldo", 0.36, 0.04, (0, 0, 0.85), liquido, vertices=14)
    for x in (-0.25, 0.1, 0.3):
        esfera("bolha", 0.06, (x, -0.05, 0.88), brilha("a6e070", 1.0))
    for a in range(3):
        caixa("pe", (0.08, 0.08, 0.2), (0.32 * math.cos(a * 2.1), 0.32 * math.sin(a * 2.1), 0.08), ferro)
    cone("fogo", 0.2, 0.0, 0.25, (0, 0, 0.08), brilha("f0921e", 1.0), vertices=8)
    return {"ponto": (0, 0, 0.8), "rampa": "veneno", "raio": 60, "pisca": 0.12}


def estante(r):
    madeira = toon("4a3324")
    caixa("fundo", (1.2, 0.35, 1.9), (0, 0, 0.95), madeira, chanfro=0.03)
    livros = [toon(h) for h in ("7e2027", "35473a", "8f6a2e", "223566", "6e4c32")]
    for z in (0.4, 0.95, 1.5):
        caixa("prateleira", (1.22, 0.4, 0.06), (0, -0.02, z - 0.3), madeira)
        x = -0.5
        while x < 0.5:
            w = r.uniform(0.06, 0.12)
            h = r.uniform(0.3, 0.42)
            caixa("livro", (w, 0.28, h), (x + w / 2, -0.06, z - 0.27 + h / 2), r.choice(livros))
            x += w + 0.01
    return None


def jarra_grande():
    vidro, latao, coisa = brilha("1d4a2a", 0.8), toon("c49a45"), toon("a89e86")
    cilindro("jarra", 0.32, 0.9, (0, 0, 0.5), vidro, vertices=14)
    esfera("especime", 0.16, (0, -0.05, 0.55), coisa, escala=(1, 1, 1.4))
    cilindro("tampa", 0.34, 0.1, (0, 0, 0.98), latao, vertices=14, chanfro=0.02)
    cilindro("base", 0.34, 0.08, (0, 0, 0.04), latao, vertices=14)
    return {"ponto": (0, 0, 0.5), "rampa": "veneno", "raio": 40, "pisca": 0.06}


def candelabro():
    latao, cera = toon("c49a45"), toon("d6ccb2")
    cilindro("base", 0.2, 0.06, (0, 0, 0.03), latao, vertices=10)
    cilindro("haste", 0.04, 1.0, (0, 0, 0.5), latao, vertices=6)
    caixa("braco", (0.6, 0.05, 0.05), (0, 0, 1.0), latao)
    for x in (-0.28, 0.0, 0.28):
        cilindro("vela", 0.05, 0.2, (x, 0, 1.12), cera, vertices=6)
        cone("chama", 0.05, 0.0, 0.12, (x, 0, 1.28), brilha("ffd060", 1.0), vertices=6)
    return {"ponto": (0, 0, 1.25), "rampa": "fogo", "raio": 48, "pisca": 0.15}


def poste_rua():
    """Poste de rua moderno com lâmpada de sódio (a luz laranja de cidade à noite)."""
    ferro, lampada = toon("2e2a40"), brilha("f0921e", 1.0)
    cilindro("base", 0.16, 0.25, (0, 0, 0.125), ferro, vertices=8, chanfro=0.03)
    cilindro("poste", 0.07, 3.3, (0, 0, 1.75), ferro, vertices=8)
    caixa("braco", (1.0, 0.08, 0.08), (0.5, 0, 3.35), ferro)   # braço de lado (de frente pra câmera ele sumia)
    caixa("cabeca", (0.5, 0.3, 0.12), (1.0, 0, 3.3), ferro, chanfro=0.03)
    caixa("lampada", (0.4, 0.22, 0.04), (1.0, 0, 3.23), lampada)
    return {"ponto": (1.0, 0, 3.2), "rampa": "fogo", "raio": 84, "pisca": 0.03}


def lixeira():
    metal, tampa = toon("35473a"), toon("1f2a24")
    cilindro("lixeira", 0.26, 0.75, (0, 0, 0.375), metal, vertices=12, chanfro=0.02)
    cilindro("tampa", 0.28, 0.08, (0, 0, 0.79), tampa, vertices=12, chanfro=0.02)
    return None


def hidrante():
    vermelho, metal = toon("b0342f"), toon("7e2027")
    cilindro("corpo", 0.15, 0.55, (0, 0, 0.3), vermelho, vertices=10)
    esfera("topo", 0.16, (0, 0, 0.6), vermelho, escala=(1, 1, 0.7))
    cilindro("bocal", 0.07, 0.42, (0, 0, 0.4), metal, rot=(0, math.pi / 2, 0), vertices=8)
    cilindro("base", 0.21, 0.08, (0, 0, 0.04), metal, vertices=10)
    return None


def cone_transito():
    laranja, branco = toon("d9614a"), toon("ece8f2")
    caixa("base", (0.42, 0.42, 0.05), (0, 0, 0.025), toon("1d1a2b"))
    px3.cone("cone", 0.17, 0.03, 0.55, (0, 0, 0.32), laranja, vertices=10)
    cilindro("faixa", 0.105, 0.08, (0, 0, 0.34), branco, vertices=10)
    return None


# ---- enfeites baixos e escuros da #32 item 2 (enchem o mapa sem competir com personagens: contraste menor, nada passa de ~1 u)

def vela_chao(r):
    """Toco de vela derretida num pires: uma chama pequena (luz fraca e trêmula)."""
    cera, ferro = toon("a89e86"), toon("2e2a40")
    cilindro("pires", 0.16, 0.04, (0, 0, 0.02), ferro, vertices=8)
    cilindro("cera", 0.07, 0.16, (0, 0, 0.12), cera, vertices=7)
    cone("chama", 0.05, 0.0, 0.12, (0, 0, 0.26), brilha("ffd060", 1.0), vertices=6)
    return {"ponto": (0, 0, 0.26), "rampa": "fogo", "raio": 30, "pisca": 0.3}


def livros_chao(r):
    cores = [toon(h) for h in ("7e2027", "35473a", "8f6a2e", "223566", "4a3324")]
    for k in range(4):
        caixa("livro", (0.34, 0.24, 0.07), (r.uniform(-0.1, 0.1), r.uniform(-0.08, 0.08), 0.04 + 0.075 * k), r.choice(cores),
              rot=(0, 0, r.uniform(-0.5, 0.5)), chanfro=0.01)
    caixa("solto", (0.3, 0.22, 0.06), (0.4, 0.2, 0.03), r.choice(cores), rot=(0, 0, 0.8), chanfro=0.01)
    return None


def tubo_quebrado(r):
    """Tubo de ensaio grande caído, com um resto de poção brilhando."""
    vidro, poca = toon("a89e86"), brilha("56b04a", 0.9)
    cilindro("tubo", 0.13, 0.8, (0, 0, 0.13), vidro, rot=(0, math.pi / 2, 0.4), vertices=8)
    cilindro("poca", 0.3, 0.02, (0.25, 0.1, 0.01), poca, vertices=10)
    for k in range(3):
        caixa("caco", (0.1, 0.07, 0.03), (-0.2 + 0.2 * k, r.uniform(-0.2, 0.2), 0.02), vidro, rot=(0, 0, r.uniform(0, 3)))
    return {"ponto": (0.25, 0.1, 0.1), "rampa": "veneno", "raio": 26, "pisca": 0.1}


def cadeira_tombada(r):
    madeira = toon("4a3324")
    caixa("assento", (0.4, 0.4, 0.05), (0, 0, 0.14), madeira, rot=(0.0, 1.2, 0.3))
    caixa("encosto", (0.4, 0.05, 0.45), (-0.15, 0.1, 0.3), madeira, rot=(0.2, 0.1, 0.3))
    for x, y in ((0.18, 0.18), (0.18, -0.18), (-0.18, 0.18), (-0.18, -0.18)):
        caixa("perna", (0.05, 0.05, 0.4), (x + 0.3, y, 0.1), madeira, rot=(0, 1.3, 0.3))
    return None


def pilha_pedras(r):
    pedra = [toon(h) for h in ("5e544a", "675c50", "4a423a")]
    for k in range(7):
        a = r.uniform(0, 6.28)
        d = r.uniform(0.0, 0.32)
        caixa("pedra", (r.uniform(0.14, 0.3), r.uniform(0.14, 0.26), r.uniform(0.1, 0.22)), (math.cos(a) * d, math.sin(a) * d, 0.08 + 0.05 * (k > 4)),
              r.choice(pedra), rot=(r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), r.uniform(0, 3)), chanfro=0.04)
    return None


def braseiro_baixo(r):
    ferro, brasa = toon("2e2a40"), brilha("f0921e", 1.0)
    cilindro("bojo", 0.3, 0.12, (0, 0, 0.32), ferro, vertices=10, chanfro=0.02)
    cone("perna", 0.2, 0.06, 0.3, (0, 0, 0.15), ferro, vertices=8)
    cilindro("brasa", 0.26, 0.03, (0, 0, 0.4), brasa, vertices=10)
    cone("chama", 0.14, 0.0, 0.3, (0, 0, 0.55), brasa, vertices=7)
    return {"ponto": (0, 0, 0.5), "rampa": "fogo", "raio": 58, "pisca": 0.22}


def jarro_barro(r):
    barro, escuro = toon("8c5a3c"), toon("4a3324")
    esfera("bojo", 0.24, (0, 0, 0.26), barro, escala=(1, 1, 1.1))
    cilindro("gargalo", 0.11, 0.14, (0, 0, 0.5), barro, vertices=8)
    cilindro("boca", 0.14, 0.04, (0, 0, 0.58), escuro, vertices=8)
    return None


def cranio_vela(r):
    osso, cera = toon("d6ccb2"), toon("a89e86")
    esfera("cranio", 0.17, (0, 0, 0.17), osso, escala=(1, 1.05, 0.95))
    caixa("mandibula", (0.14, 0.1, 0.06), (0, -0.1, 0.05), osso)
    cilindro("cera", 0.05, 0.18, (0, 0.02, 0.4), cera, vertices=6)
    cone("chama", 0.04, 0.0, 0.11, (0, 0.02, 0.54), brilha("ffd060", 1.0), vertices=6)
    return {"ponto": (0, 0.02, 0.54), "rampa": "fogo", "raio": 34, "pisca": 0.3}


def saco_lixo(r):
    saco = toon("1f2a24")
    for k, (x, y, s) in enumerate(((0, 0, 0.3), (0.32, 0.1, 0.24), (-0.1, 0.3, 0.22))):
        esfera("saco", s, (x, y, s * 0.8), saco, escala=(1, 1, 0.85))
        cone("laco", 0.05, 0.0, 0.14, (x, y, s * 1.5), saco, vertices=5)
    return None


def banco_praca(r):
    madeira, ferro = toon("6e4c32"), toon("2e2a40")
    for z in (0.34, 0.42, 0.5):
        caixa("ripa", (1.0, 0.1, 0.04), (0, -0.14 + (z - 0.34) * 0.6, z), madeira)
    caixa("encosto", (1.0, 0.04, 0.3), (0, 0.16, 0.62), madeira, rot=(-0.2, 0, 0))
    for x in (-0.42, 0.42):
        caixa("pe", (0.05, 0.4, 0.34), (x, 0, 0.17), ferro)
    return None


def barril_fogo(r):
    ferro, brasa = toon("45405c"), brilha("f0921e", 1.0)
    cilindro("barril", 0.3, 0.7, (0, 0, 0.35), ferro, vertices=12, chanfro=0.03)
    cilindro("brasa", 0.26, 0.03, (0, 0, 0.72), brasa, vertices=10)
    cone("chama", 0.17, 0.0, 0.4, (0, 0, 0.9), brasa, vertices=8)
    cone("miolo", 0.08, 0.0, 0.25, (0, -0.03, 0.86), brilha("ffd060", 1.0), vertices=6)
    return {"ponto": (0, 0, 0.85), "rampa": "fogo", "raio": 66, "pisca": 0.25}


def caixa_correio(r):
    azul, metal = toon("223566"), toon("2e2a40")
    caixa("poste", (0.08, 0.08, 0.5), (0, 0, 0.25), metal)
    caixa("caixa", (0.42, 0.3, 0.28), (0, 0, 0.62), azul, chanfro=0.03)
    caixa("aba", (0.42, 0.04, 0.12), (0, -0.16, 0.7), toon("1d1a2b"))
    return None


def fixos_cidade():
    """Postes nas 4 esquinas do cruzamento, na calçada junto do meio-fio (em pixels do azulejo, com o pé)."""
    c = L / 2
    d = RUA / 2 + 0.8
    return [{"item": "poste", "pos": [round(x * PX), round((L - y) * PX)]}
            for x in (c - d, c + d) for y in (c - d, c + d)]


# ================================================================ floresta sombria (#64, região 1; clima #68)

def piso_floresta(r):
    """Chão de mata fechada visto de cima: terra escura, tufos de capim, folhas caídas, raízes, musgo e pedrinhas."""
    caixa("terra", (L, L, 0.1), (L / 2, L / 2, -0.05), toon("2b1d18"))
    terras = [chao(h) for h in ("3a2a20", "33261d", "42302a")]
    for _ in range(14):   # manchas de terra com relevo (o "chão" de verdade)
        x, y = r.uniform(0.8, L - 0.8), r.uniform(0.8, L - 0.8)
        esfera("torrao", r.uniform(0.5, 1.1), (x, y, -0.25), r.choice(terras), escala=(1, r.uniform(0.6, 1.4), 0.4))
    capins = [chao(h) for h in ("2d4721", "1d2e17", "35473a")]
    for _ in range(26):   # tufos de capim: bolinhas de verde amontoadas
        x, y = r.uniform(0.5, L - 0.5), r.uniform(0.5, L - 0.5)
        mat = r.choice(capins)
        for _k in range(r.randint(4, 8)):
            esfera("capim", r.uniform(0.06, 0.13), (x + r.uniform(-0.25, 0.25), y + r.uniform(-0.25, 0.25), r.uniform(0.0, 0.08)), mat, escala=(1, 1, 1.6))
    folhas = [toon(h) for h in ("6e4c32", "7e2027", "8f6a2e", "4a3324")]
    for _ in range(70):   # folhas caídas: plaquinhas rotacionadas
        caixa("folha", (0.12, 0.07, 0.02), (r.uniform(0.3, L - 0.3), r.uniform(0.3, L - 0.3), 0.02), r.choice(folhas),
              rot=(r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), r.uniform(0, math.pi)))
    raizes = toon("4a3324")
    for _ in range(4):    # raízes atravessando o chão
        x, y = r.uniform(1.5, L - 1.5), r.uniform(1.5, L - 1.5)
        a = r.uniform(0, math.pi)
        for k in range(5):
            cilindro("raiz", 0.09 - k * 0.012, 0.6, (x + math.cos(a) * k * 0.5, y + math.sin(a) * k * 0.5, 0.05), raizes,
                     rot=(math.pi / 2, 0, a + math.pi / 2 + r.uniform(-0.3, 0.3)), vertices=6)
    musgo = toon("566e55")
    for _ in range(6):
        x, y = r.uniform(1, L - 1), r.uniform(1, L - 1)
        for _k in range(7):
            esfera("musgo", r.uniform(0.07, 0.14), (x + r.uniform(-0.3, 0.3), y + r.uniform(-0.3, 0.3), 0.02), musgo, escala=(1, 1, 0.3))
    pedras = [chao(h) for h in ("4a423b", "5e544a")]
    for _ in range(8):
        esfera("pedrinha", r.uniform(0.08, 0.18), (r.uniform(0.5, L - 0.5), r.uniform(0.5, L - 0.5), 0.03), r.choice(pedras), escala=(1, 0.8, 0.5))


def arvore_viva(r):
    """Árvore de copa escura: tronco grosso com raízes saindo, copa em bolhas de folha (o marco da floresta)."""
    casca, casca_e = toon("6e4c32"), toon("4a3324")
    folhas = [toon(h) for h in ("2d4721", "466a2c", "1d2e17")]
    cilindro("tronco", 0.28, 2.2, (0, 0, 1.1), casca, vertices=10, chanfro=0.03)
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        cilindro("raiz", 0.1, 0.7, (math.cos(a) * 0.35, math.sin(a) * 0.35, 0.12), casca_e, rot=(0.5 * math.sin(a), -0.5 * math.cos(a), 0), vertices=6)
    for i, (x, y, z, rr) in enumerate(((0, 0, 2.7, 0.95), (0.6, 0.2, 2.45, 0.6), (-0.6, 0.1, 2.5, 0.65), (0.1, -0.5, 2.4, 0.55), (-0.2, 0.55, 2.6, 0.6))):
        esfera("copa", rr, (x, y, z), folhas[i % 3], escala=(1, 1, 0.8))
    return None


def arvore_morta(r):
    """Árvore morta: tronco cinza retorcido, galhos secos apontando pro céu."""
    madeira = toon("5e544a")
    cilindro("tronco", 0.2, 1.9, (0, 0, 0.95), madeira, vertices=8, rot=(0.06, -0.05, 0))
    for i, (a, z, comp) in enumerate(((0.4, 1.5, 0.8), (2.2, 1.2, 0.7), (4.0, 1.75, 0.6), (5.2, 1.0, 0.5))):
        cilindro("galho", 0.05, comp, (math.cos(a) * comp * 0.45, math.sin(a) * comp * 0.45, z + comp * 0.3), madeira,
                 rot=(0.9 * math.sin(a), -0.9 * math.cos(a), 0), vertices=6)
    return None


def toco(r):
    casca, miolo = toon("6e4c32"), toon("9a6d45")
    cilindro("toco", 0.32, 0.45, (0, 0, 0.22), casca, vertices=10, chanfro=0.03)
    cilindro("aneis", 0.27, 0.02, (0, 0, 0.455), miolo, vertices=10)
    for k in range(3):
        a = k * math.tau / 3
        cilindro("raiz", 0.07, 0.4, (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.06), casca, rot=(0.6 * math.sin(a), -0.6 * math.cos(a), 0), vertices=6)
    for k in range(3):
        esfera("cogu", 0.06, (0.2 + k * 0.08, -0.22, 0.32 + k * 0.03), toon("7e2027"), escala=(1, 1, 0.5))
    return None


def tronco_caido(r):
    casca, miolo, musgo = toon("4a3324"), toon("9a6d45"), toon("566e55")
    cilindro("tronco", 0.24, 1.6, (0, 0, 0.24), casca, rot=(0, math.pi / 2, 0.3), vertices=10, chanfro=0.02)
    cilindro("ponta", 0.2, 0.02, (0.77, 0.24, 0.24), miolo, rot=(0, math.pi / 2, 0.3), vertices=10)
    for k in range(5):
        esfera("musgo", 0.1, (-0.5 + k * 0.25, k * 0.07, 0.44), musgo, escala=(1.2, 1, 0.4))
    return None


def arbusto(r):
    folhas = [toon(h) for h in ("2d4721", "466a2c", "1d2e17")]
    for i in range(6):
        esfera("moita", r.uniform(0.25, 0.38), (r.uniform(-0.3, 0.3), r.uniform(-0.2, 0.2), 0.25 + r.uniform(0, 0.2)), folhas[i % 3], escala=(1, 1, 0.85))
    for i in range(3):
        esfera("fruta", 0.04, (r.uniform(-0.3, 0.3), -0.32, 0.3 + r.uniform(0, 0.25)), toon("b0342f"))
    return None


def pedra_musgo(r):
    pedra, musgo = toon("5e544a"), toon("566e55")
    esfera("pedra", 0.42, (0, 0, 0.25), pedra, escala=(1.2, 0.9, 0.75))
    esfera("pedra2", 0.22, (0.4, 0.15, 0.12), pedra, escala=(1, 1, 0.8))
    for k in range(6):
        esfera("musgo", 0.12, (r.uniform(-0.3, 0.3), r.uniform(-0.2, 0.2), 0.5), musgo, escala=(1.2, 1, 0.35))
    return None


def cogumelos_luz(r):
    """Cogumelos que brilham: a luz verde-fria da floresta à noite."""
    caule = toon("d6ccb2")
    for i, (x, y, h) in enumerate(((0, 0, 0.32), (0.18, 0.08, 0.22), (-0.16, 0.1, 0.18), (0.06, -0.16, 0.14))):
        cilindro("caule", 0.035, h, (x, y, h / 2), caule, vertices=6)
        esfera("chapeu", 0.1 - i * 0.012, (x, y, h), brilha("a6e070", 0.9), escala=(1, 1, 0.55))
    return {"ponto": (0, 0, 0.3), "rampa": "veneno", "raio": 46, "pisca": 0.08}


def cranio_cervo(r):
    osso, osso_e = toon("d6ccb2"), toon("a89e86")
    caixa("cranio", (0.22, 0.34, 0.18), (0, 0, 0.12), osso, chanfro=0.04, rot=(0, 0, 0.4))
    for lado in (1, -1):
        for k in range(3):
            cone("chifre", 0.03, 0.0, 0.45 - k * 0.1, (lado * (0.12 + k * 0.14), 0.12 + k * 0.05, 0.3 + k * 0.12), osso_e)
    caixa("orbita", (0.05, 0.03, 0.04), (0.05, -0.17, 0.16), toon("0d0b14"))
    return None


def teia(r):
    madeira, fio = toon("4a3324"), toon("d6ccb2")
    cilindro("estaca", 0.04, 1.0, (-0.45, 0, 0.5), madeira, rot=(0, 0.15, 0), vertices=6)
    cilindro("estaca", 0.04, 0.9, (0.45, 0, 0.45), madeira, rot=(0, -0.2, 0), vertices=6)
    for k in range(6):
        a = k * math.tau / 6
        cilindro("raio", 0.008, 0.5, (math.cos(a) * 0.22, -0.02, 0.6 + math.sin(a) * 0.22), fio, rot=(0, -a + math.pi / 2, 0), vertices=4)
    for rr in (0.12, 0.24):
        for k in range(6):
            a = k * math.tau / 6 + math.tau / 12
            cilindro("anel", 0.006, rr * 1.0, (math.cos(a) * rr, -0.02, 0.6 + math.sin(a) * rr), fio, rot=(0, -a, 0), vertices=4)
    esfera("aranha", 0.06, (0.08, -0.04, 0.64), toon("2e2a40"))
    return None


def fogueira(r):
    """Fogueira de acampamento abandonado: a única luz quente da floresta."""
    pedra, lenha = toon("4a423b"), toon("4a3324")
    for k in range(7):
        a = k * math.tau / 7
        esfera("pedra", 0.1, (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.06), pedra, escala=(1, 1, 0.7))
    for k in range(3):
        a = k * math.tau / 3
        cilindro("lenha", 0.05, 0.5, (math.cos(a) * 0.1, math.sin(a) * 0.1, 0.12), lenha, rot=(0.9 * math.sin(a), -0.9 * math.cos(a), 0), vertices=6)
    cone("chama", 0.17, 0.0, 0.42, (0, 0, 0.32), brilha("f0921e", 1.0), vertices=8)
    cone("miolo", 0.08, 0.0, 0.28, (0, -0.04, 0.26), brilha("ffd060", 1.0), vertices=6)
    return {"ponto": (0, 0, 0.35), "rampa": "fogo", "raio": 70, "pisca": 0.2}


# ================================================================ pântano pútrido (#64, região 2)

def piso_pantano(r):
    """Lama vista de cima: poças d'água escura, limo verde, vitórias-régias e juncos."""
    caixa("lama", (L, L, 0.1), (L / 2, L / 2, -0.05), toon("2b2a20"))
    lamas = [chao(h) for h in ("3a3a2a", "35473a", "33301f")]
    for _ in range(16):
        x, y = r.uniform(0.8, L - 0.8), r.uniform(0.8, L - 0.8)
        esfera("torrao", r.uniform(0.5, 1.2), (x, y, -0.28), r.choice(lamas), escala=(1, r.uniform(0.6, 1.4), 0.4))
    agua = px3.material_suave("agua_pantano", px3.cor("152a26"), rugosidade=0.15, relevo=0.0, variacao=0.05, escala=2.0)
    for _ in range(5):   # poças: água parada e escura, quase espelhada
        x, y = r.uniform(1.4, L - 1.4), r.uniform(1.4, L - 1.4)
        esfera("poca", r.uniform(0.7, 1.2), (x, y, -0.32), agua, escala=(1, r.uniform(0.6, 1.0), 0.4))
        vit = toon("466a2c")
        for _k in range(r.randint(1, 3)):
            cilindro("vitoria", r.uniform(0.12, 0.2), 0.02, (x + r.uniform(-0.5, 0.5), y + r.uniform(-0.4, 0.4), 0.06), vit, vertices=10)
    limo = toon("566e55")
    for _ in range(10):
        x, y = r.uniform(0.6, L - 0.6), r.uniform(0.6, L - 0.6)
        for _k in range(6):
            esfera("limo", r.uniform(0.07, 0.15), (x + r.uniform(-0.3, 0.3), y + r.uniform(-0.3, 0.3), 0.02), limo, escala=(1, 1, 0.3))
    junco = toon("6a943d")
    for _ in range(14):   # juncos vistos de cima: pontinhos verdes em tufo
        x, y = r.uniform(0.5, L - 0.5), r.uniform(0.5, L - 0.5)
        for _k in range(r.randint(5, 9)):
            cilindro("junco", 0.02, 0.4, (x + r.uniform(-0.15, 0.15), y + r.uniform(-0.15, 0.15), 0.2), junco, vertices=4)
    tabua = toon("4a3324")
    for _ in range(2):
        x, y = r.uniform(1.5, L - 1.5), r.uniform(1.5, L - 1.5)
        caixa("tabua", (0.9, 0.18, 0.05), (x, y, 0.03), tabua, rot=(0, 0, r.uniform(0, math.pi)), chanfro=0.02)


def arvore_pantano(r):
    """Árvore do pântano: tronco torto, raízes em arco saindo da lama e barba de musgo pendurada nos galhos."""
    casca, musgo = toon("4a3324"), toon("566e55")
    cilindro("tronco", 0.22, 1.8, (0, 0, 1.1), casca, rot=(0.08, 0.06, 0), vertices=8)
    for k in range(4):
        a = k * math.tau / 4 + 0.3
        cilindro("raiz", 0.08, 0.8, (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.3), casca, rot=(0.8 * math.sin(a), -0.8 * math.cos(a), 0), vertices=6)
    for i, (a, z) in enumerate(((0.3, 1.7), (2.5, 1.9), (4.4, 1.6))):
        cilindro("galho", 0.06, 0.9, (math.cos(a) * 0.45, math.sin(a) * 0.45, z + 0.2), casca, rot=(1.0 * math.sin(a), -1.0 * math.cos(a), 0), vertices=6)
        for k in range(3):
            caixa("barba", (0.04, 0.04, 0.5 + k * 0.1), (math.cos(a) * (0.6 + k * 0.12), math.sin(a) * (0.6 + k * 0.12), z - 0.05), musgo)
    return None


def juncos(r):
    verde, ponta = toon("6a943d"), toon("6e4c32")
    for k in range(10):
        x, y, h = r.uniform(-0.3, 0.3), r.uniform(-0.2, 0.2), r.uniform(0.6, 1.1)
        cilindro("junco", 0.025, h, (x, y, h / 2), verde, rot=(r.uniform(-0.12, 0.12), r.uniform(-0.12, 0.12), 0), vertices=4)
        if k % 3 == 0:
            cilindro("taboa", 0.045, 0.16, (x, y, h - 0.05), ponta, vertices=6)
    return None


def poca_vitorias(r):
    agua, vit, flor = toon("152a26"), toon("466a2c"), toon("d6ccb2")
    cilindro("poca", 0.75, 0.03, (0, 0, 0.015), agua, vertices=16)
    for k in range(4):
        a = k * math.tau / 4 + 0.5
        cilindro("vitoria", 0.17, 0.02, (math.cos(a) * 0.4, math.sin(a) * 0.35, 0.04), vit, vertices=10)
    esfera("flor", 0.06, (0.4, 0.0, 0.08), flor, escala=(1, 1, 0.6))
    return None


def passarela(r):
    madeira, madeira_e = toon("6e4c32"), toon("4a3324")
    for k in range(5):
        caixa("tabua", (0.22, 0.9, 0.05), (-0.5 + k * 0.25, 0, 0.32 + r.uniform(-0.04, 0.04)), madeira if k % 2 else madeira_e,
              rot=(0, r.uniform(-0.08, 0.08), r.uniform(-0.05, 0.05)), chanfro=0.01)
    for x in (-0.6, 0.6):
        for y in (-0.38, 0.38):
            cilindro("estaca", 0.05, 0.42, (x, y, 0.15), madeira_e, vertices=6)
    return None


def lanterna_poste(r):
    """Lanterna de pântano num poste torto: luz verde-fria (o fogo-fátuo preso numa gaiola)."""
    madeira, ferro = toon("4a3324"), toon("2e2a40")
    cilindro("poste", 0.05, 1.5, (0, 0, 0.75), madeira, rot=(0.05, 0.08, 0), vertices=6)
    caixa("braco", (0.4, 0.05, 0.05), (0.18, 0, 1.45), madeira)
    caixa("gaiola", (0.16, 0.16, 0.2), (0.36, 0, 1.3), ferro, chanfro=0.02)
    esfera("chama", 0.07, (0.36, -0.02, 1.3), brilha("a6e070", 1.0))
    return {"ponto": (0.36, 0, 1.3), "rampa": "veneno", "raio": 60, "pisca": 0.12}


def barco_podre(r):
    madeira, agua = toon("4a3324"), toon("152a26")
    cilindro("agua", 0.7, 0.02, (0, 0, 0.01), agua, vertices=14)
    esfera("casco", 0.45, (0, 0, 0.05), madeira, escala=(0.6, 1.4, 0.45))
    caixa("banco", (0.5, 0.08, 0.04), (0, 0.1, 0.22), toon("6e4c32"))
    cilindro("remo", 0.025, 0.8, (0.25, -0.2, 0.25), toon("6e4c32"), rot=(0.4, 0.9, 0), vertices=5)
    return None


def lapide_torta(r):
    pedra, musgo = toon("5e544a"), toon("566e55")
    caixa("lapide", (0.36, 0.1, 0.55), (0, 0, 0.26), pedra, rot=(0.25, 0, 0.15), chanfro=0.05)
    esfera("topo", 0.18, (0, 0.04, 0.5), pedra, escala=(1, 0.3, 0.6))
    for k in range(4):
        esfera("musgo", 0.08, (r.uniform(-0.15, 0.15), -0.06, r.uniform(0.1, 0.4)), musgo, escala=(1, 0.4, 1))
    return None


def ossos_lodo(r):
    osso = toon("a89e86")
    esfera("cranio", 0.12, (0, 0, 0.08), toon("d6ccb2"), escala=(1, 1.1, 0.9))
    for k in range(4):
        a = r.uniform(0, math.pi)
        cilindro("osso", 0.03, 0.4, (r.uniform(-0.3, 0.3), r.uniform(-0.2, 0.2), 0.03), osso, rot=(math.pi / 2, 0, a), vertices=5)
    return None


def raizes_arco(r):
    casca = toon("4a3324")
    for k in range(3):
        a = k * 0.5 - 0.5
        for s in (-1, 1):
            cilindro("arco", 0.07, 0.7, (s * 0.25 + a * 0.2, a * 0.3, 0.3), casca, rot=(0, s * 0.7, a), vertices=6)
    return None


def velas_toco(r):
    """Velas derretidas num toco: alguém deixou oferendas pro que mora na água. Luz quente."""
    casca, cera = toon("4a3324"), toon("d6ccb2")
    cilindro("toco", 0.26, 0.3, (0, 0, 0.15), casca, vertices=10)
    for k, (x, y, h) in enumerate(((0.0, 0.0, 0.22), (0.12, 0.08, 0.16), (-0.1, 0.06, 0.12))):
        cilindro("vela", 0.04, h, (x, y, 0.3 + h / 2), cera, vertices=6)
        cone("chama", 0.035, 0.0, 0.09, (x, y, 0.3 + h + 0.04), brilha("ffd060", 1.0), vertices=5)
    return {"ponto": (0, 0, 0.6), "rampa": "fogo", "raio": 50, "pisca": 0.22}


# ================================================================ deserto de ossos (#64, região 3)

def _barra(nome, a, b, raio, mat, vertices=6):
    """Cilindro do ponto a ao ponto b (costela, chifre, raio de roda, perna de tripé)."""
    from mathutils import Vector
    va, vb = Vector(a), Vector(b)
    rot = (vb - va).normalized().to_track_quat("Z", "Y").to_euler()
    return cilindro(nome, raio, (vb - va).length, tuple((va + vb) / 2), mat, rot=tuple(rot), vertices=vertices)


def piso_deserto(r):
    """Areia vista de cima: montes baixos, marcas do vento, placas de barro rachado, capim seco, pedrinhas e ossos miúdos.
    Tom médio de propósito: os bichos escuros e os ossos claros se leem por cima."""
    caixa("areia", (L, L, 0.1), (L / 2, L / 2, -0.05), toon("cdb06e"))   # clara: a luz do render escurece até o tom médio
    areias = [chao(h) for h in ("c4a468", "b8975a", "d4b878")]
    for _ in range(8):   # ondulações largas e baixas (duna, não torrão)
        x, y = r.uniform(0.8, L - 0.8), r.uniform(0.8, L - 0.8)
        esfera("duna", r.uniform(0.9, 1.6), (x, y, -0.3), r.choice(areias), escala=(1, r.uniform(0.5, 1.2), 0.22))
    vento = toon("e6d3a0")
    for _ in range(9):   # marcas do vento: ondinhas paralelas
        x, y = r.uniform(1.0, L - 1.0), r.uniform(1.0, L - 1.0)
        a = r.uniform(-0.3, 0.3)
        for k in range(r.randint(3, 5)):
            cilindro("onda", 0.03, r.uniform(0.6, 1.1), (x, y + k * 0.16, 0.0), vento, rot=(0, math.pi / 2, a), vertices=5)
    barro = [toon(h) for h in ("8f6a2e", "7a6038")]
    for _ in range(3):   # barro seco rachado: placas em grade com frestas finas (a areia aparece nas rachaduras)
        x0, y0 = r.uniform(1.2, L - 2.4), r.uniform(1.2, L - 2.2)
        for i in range(4):
            for j in range(3):
                if r.random() < 0.2:
                    continue
                caixa("placa", (0.3, 0.26, 0.05), (x0 + i * 0.33 + r.uniform(-0.02, 0.02), y0 + j * 0.29 + r.uniform(-0.02, 0.02), -0.005),
                      barro[1 if r.random() < 0.3 else 0], rot=(0, 0, r.uniform(-0.15, 0.15)), chanfro=0.015)
    capim = toon("8f6a2e")
    for _ in range(10):
        x, y = r.uniform(0.5, L - 0.5), r.uniform(0.5, L - 0.5)
        for _k in range(r.randint(4, 7)):
            cilindro("capim", 0.015, 0.25, (x + r.uniform(-0.12, 0.12), y + r.uniform(-0.12, 0.12), 0.1), capim,
                     rot=(r.uniform(-0.6, 0.6), r.uniform(-0.6, 0.6), 0), vertices=4)
    pedras = [chao(h) for h in ("766a5d", "5e544a")]
    for _ in range(12):
        esfera("pedra", r.uniform(0.06, 0.16), (r.uniform(0.3, L - 0.3), r.uniform(0.3, L - 0.3), 0.0), r.choice(pedras),
               escala=(1, r.uniform(0.7, 1.3), 0.5))
    osso = toon("d6ccb2")
    for _ in range(6):
        cilindro("osso", 0.025, r.uniform(0.2, 0.35), (r.uniform(0.5, L - 0.5), r.uniform(0.5, L - 0.5), 0.02), osso,
                 rot=(math.pi / 2, 0, r.uniform(0, math.pi)), vertices=5)


def costela_gigante(r):
    """Costelas de um bicho colossal saindo da areia: a espinha meio enterrada e cinco pares de costelas em arco."""
    osso, osso_e = toon("d6ccb2"), toon("a89e86")
    E = 1.4
    for k in range(6):
        esfera("vertebra", 0.16 * E, (0, (-1.0 + k * 0.4) * E, 0.06), osso_e, escala=(1.2, 0.8, 0.7))
    for k in range(5):
        y = (-0.8 + k * 0.4) * E
        h = (1.3 - abs(k - 2) * 0.18) * E   # as do meio são as mais altas
        for lado in (1, -1):
            pts = [(0.15 * lado * E, y, 0.08), (0.6 * lado * E, y, h * 0.5), (0.58 * lado * E, y, h * 0.88), (0.32 * lado * E, y, h)]
            for i in range(3):
                _barra("costela", pts[i], pts[i + 1], (0.07 - i * 0.015) * E, osso)
    return None


def cranio_gigante(r):
    """Crânio enorme de chifres, com a nuca coberta de areia e as órbitas escuras."""
    osso, osso_e, escuro = toon("d6ccb2"), toon("a89e86"), toon("2a2015")
    esfera("cranio", 0.6, (0, 0, 0.3), osso, escala=(1.0, 1.2, 0.8))
    esfera("focinho", 0.4, (0, -0.65, 0.18), osso, escala=(0.8, 1.0, 0.6))
    for x in (0.25, -0.25):
        esfera("orbita", 0.15, (x, -0.45, 0.48), escuro, escala=(1, 0.6, 1))
    for x in (0.1, -0.1):
        esfera("narina", 0.06, (x, -1.0, 0.25), escuro)
    for k in range(3):
        cilindro("dente", 0.03, 0.12, ((k - 1) * 0.12, -0.95, 0.06), osso, vertices=5)
    for lado in (1, -1):
        pts = [(0.45 * lado, 0.1, 0.6), (0.9 * lado, 0.0, 0.9), (1.1 * lado, -0.3, 1.25), (1.0 * lado, -0.55, 1.4)]
        for i in range(3):
            _barra("chifre", pts[i], pts[i + 1], 0.13 - i * 0.035, osso_e)
    esfera("monte", 0.9, (0, 0.35, 0.0), toon("a8884e"), escala=(1.2, 1.0, 0.3))   # a areia que cobre a nuca
    return None


def pilar_quebrado(r):
    """Coluna de arenito quebrada, com faixas entalhadas, topo lascado e pedaços caídos."""
    pedra, pedra_e = toon("b8975a"), toon("8f6a2e")
    cilindro("base", 0.36, 0.2, (0, 0, 0.1), pedra_e, vertices=10)
    h = r.uniform(1.2, 1.8)
    cilindro("fuste", 0.27, h, (0, 0, 0.2 + h / 2), pedra, vertices=10)
    for k in range(int(h / 0.4)):
        cilindro("faixa", 0.285, 0.05, (0, 0, 0.4 + k * 0.4), pedra_e, vertices=10)
    cone("lasca", 0.27, 0.12, 0.25, (0.04, 0.02, 0.2 + h + 0.12), pedra, vertices=7)
    for k in range(3):
        caixa("caco", (r.uniform(0.15, 0.3), r.uniform(0.12, 0.25), r.uniform(0.1, 0.18)), (r.uniform(-0.7, 0.7), r.uniform(-0.6, 0.2), 0.06),
              pedra, rot=(0, 0, r.uniform(0, 3)), chanfro=0.03)
    return None


def obelisco(r):
    """Obelisco de pedra escura, rachado, com runas que ainda brilham azul: a luz fria do deserto."""
    pedra, escuro = toon("766a5d"), toon("2a2015")
    runa = brilha("8fd0e0", 1.0)
    caixa("base", (0.7, 0.7, 0.18), (0, 0, 0.09), toon("5e544a"), chanfro=0.03)
    for k in range(4):   # o fuste afina em 4 blocos
        lado = 0.5 - k * 0.07
        z = 0.18 + 0.28 + k * 0.56
        caixa("bloco", (lado, lado, 0.56), (0, 0, z), pedra, chanfro=0.02)
        caixa("runa", (0.07, 0.02, 0.2), (0, -lado / 2 - 0.006, z), runa)
    ponta = cone("ponta", 0.205, 0.0, 0.32, (0, 0, 0.18 + 4 * 0.56 + 0.16), toon("c49a45"), vertices=4)
    ponta.rotation_euler = (0, 0, math.pi / 4)   # o piramidião alinhado com o bloco de baixo
    caixa("racha", (0.03, 0.02, 0.7), (0.08, -0.256, 0.9), escuro, rot=(0, 0.3, 0))
    return {"ponto": (0, -0.3, 1.3), "rampa": "noite", "raio": 45, "pisca": 0.1}


def cabeca_estatua(r):
    """Cabeça de uma estátua gigante, afundada na areia até o queixo: rosto gasto, toucado listrado, nariz quebrado."""
    pedra, pedra_e, escuro = toon("b8a892"), toon("766a5d"), toon("2a2015")
    esfera("cabeca", 0.5, (0, 0, 0.42), pedra, escala=(0.95, 0.9, 1.05))
    esfera("toucado", 0.56, (0, 0.08, 0.55), pedra_e, escala=(1.05, 0.9, 0.95))
    for lado in (1, -1):
        caixa("aba", (0.18, 0.4, 0.6), (0.48 * lado, -0.05, 0.3), pedra_e, chanfro=0.04)
        for k in range(3):
            caixa("listra", (0.2, 0.42, 0.04), (0.48 * lado, -0.05, 0.12 + k * 0.18), pedra, chanfro=0.01)
    for x in (0.17, -0.17):
        caixa("olho", (0.16, 0.03, 0.05), (x, -0.46, 0.52), escuro)
    caixa("nariz", (0.1, 0.1, 0.14), (0, -0.47, 0.38), pedra_e, chanfro=0.02)   # quebrado: só o toco
    caixa("boca", (0.2, 0.03, 0.03), (0, -0.44, 0.2), escuro)
    esfera("monte", 0.85, (0, 0.05, 0.0), toon("a8884e"), escala=(1.3, 1.1, 0.25))
    return None


def braseiro(r):
    """Braseiro de bronze num tripé, com brasa e fogo: a luz quente dos acampamentos."""
    bronze = toon("8f6a2e")
    for k in range(3):
        a = k * math.tau / 3 + 0.3
        _barra("perna", (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.0), (math.cos(a) * 0.12, math.sin(a) * 0.12, 0.75), 0.035, bronze)
    cilindro("bacia", 0.3, 0.16, (0, 0, 0.82), bronze, vertices=12)
    esfera("brasa", 0.24, (0, 0, 0.9), brilha("f0921e", 1.0), escala=(1, 1, 0.35))
    for k in range(4):
        cone("chama", 0.08, 0.0, 0.3, (r.uniform(-0.12, 0.12), r.uniform(-0.12, 0.12), 1.05), brilha("ffd060", 1.0), vertices=5)
    return {"ponto": (0, 0, 1.05), "rampa": "fogo", "raio": 75, "pisca": 0.22}


def rocha_vento(r):
    """Rocha que o vento comeu: mais larga em cima que embaixo, em camadas de cor."""
    camadas = [toon(h) for h in ("8f6a2e", "a8884e", "7a6038", "b8975a")]
    for k, (rr, z, sx) in enumerate(((0.35, 0.25, 1.0), (0.3, 0.6, 0.9), (0.5, 0.95, 1.2), (0.42, 1.25, 1.1))):
        esfera("camada", rr, (r.uniform(-0.05, 0.05), 0, z), camadas[k], escala=(sx, 0.9, 0.55))
    return None


def jarros(r):
    """Jarros de barro de uma caravana: dois em pé, um tombado e os cacos de um quebrado."""
    barro, barro_e = toon("9a6d45"), toon("6e4c32")
    for x, y, h in ((-0.25, 0.1, 0.55), (0.18, 0.2, 0.45)):
        esfera("bojo", 0.22, (x, y, h * 0.45), barro, escala=(1, 1, 1.15))
        cilindro("gargalo", 0.08, 0.14, (x, y, h * 0.45 + 0.28), barro_e, vertices=8)
        cilindro("faixa", 0.225, 0.04, (x, y, h * 0.45), barro_e, vertices=12)
    esfera("tombado", 0.2, (0.15, -0.35, 0.18), barro, escala=(1.15, 1, 1))
    cilindro("boca", 0.08, 0.14, (-0.05, -0.38, 0.18), barro_e, rot=(0, math.pi / 2, 0), vertices=8)
    for _k in range(4):
        caixa("caco", (0.1, 0.07, 0.03), (r.uniform(-0.3, 0.45), r.uniform(-0.6, -0.4), 0.02), barro, rot=(0, 0, r.uniform(0, 3)))
    return None


def tenda_rasgada(r):
    """Tenda de caravana abandonada: duas estacas, o pano de trás em pé, o da frente rasgado e caído, e um baú."""
    madeira, pano, pano_e = toon("6e4c32"), toon("7e2027"), toon("4f1520")
    for x in (-0.55, 0.55):
        cilindro("estaca", 0.04, 1.2, (x, 0.1, 0.6), madeira, rot=(0, 0.15 * (1 if x > 0 else -1), 0), vertices=6)
    caixa("cumeeira", (1.2, 0.04, 0.04), (0, 0.1, 1.18), madeira)
    caixa("pano", (1.1, 0.04, 0.9), (0, 0.4, 0.75), pano, rot=(0.55, 0, 0))
    caixa("rasgado", (0.6, 0.04, 0.5), (-0.25, -0.2, 0.5), pano_e, rot=(-0.6, 0.1, 0.1))
    caixa("bau", (0.36, 0.24, 0.22), (0.35, -0.3, 0.11), madeira, chanfro=0.02)
    caixa("ferro", (0.38, 0.26, 0.03), (0.35, -0.3, 0.18), toon("2e2a40"))
    return None


def roda_carroca(r):
    """Roda de carroça quebrada, deitada e meio coberta de areia: o que sobrou das caravanas."""
    madeira = toon("6e4c32")
    R, cz, inc = 0.5, 0.16, 0.3   # deitada e um pouco inclinada (nada abaixo do chão)

    def ponto(a, raio):
        return (math.cos(a) * raio, math.sin(a) * raio * math.cos(inc), cz + math.sin(a) * raio * math.sin(inc))
    for k in range(12):
        if k in (4, 5):   # um pedaço do aro faltando
            continue
        a = k * math.tau / 12
        _barra("aro", ponto(a, R), ponto(a + math.tau / 12, R), 0.05, madeira)
    for k in range(6):
        _barra("raio", ponto(0, 0), ponto(k * math.tau / 6 + 0.2, R), 0.03, madeira)
    esfera("cubo", 0.1, ponto(0, 0), toon("4a3324"), escala=(1, 1, 0.6))
    esfera("monte", 0.4, (0.35, -0.2, 0.0), toon("a8884e"), escala=(1.3, 0.9, 0.35))
    return None


CENARIOS = {
    "deserto": {
        "piso": piso_deserto, "ambiente": [1.0, 0.94, 0.84],
        "paleta": ("areia", "pedra", "osso", "ouro", "sangue", "fogo", "noite", "lapis", "aco"),   # sem "couro": puxava a areia pro laranja
        "enfeites": [("costelas", costela_gigante, 1), ("cranio", cranio_gigante, 1), ("pilar", pilar_quebrado, 2), ("obelisco", obelisco, 1),
                     ("cabeca", cabeca_estatua, 1), ("braseiro", braseiro, 1), ("rocha", rocha_vento, 3), ("jarros", jarros, 2),
                     ("tenda", tenda_rasgada, 1), ("roda", roda_carroca, 2), ("ossos", ossos_lodo, 3)],
    },
    "pantano": {
        "piso": piso_pantano, "ambiente": [0.56, 0.68, 0.6],
        "paleta": ("musgo", "folha", "couro", "pedra", "osso", "veneno", "fogo", "noite"),
        "enfeites": [("arvore", arvore_pantano, 2), ("juncos", juncos, 4), ("vitorias", poca_vitorias, 2), ("passarela", passarela, 1),
                     ("lanterna", lanterna_poste, 2), ("barco", barco_podre, 1), ("lapide", lapide_torta, 2), ("ossos", ossos_lodo, 2),
                     ("raizes", raizes_arco, 2), ("velas", velas_toco, 1)],
    },
    "floresta": {
        "piso": piso_floresta, "ambiente": [0.6, 0.7, 0.62],
        "paleta": ("couro", "folha", "musgo", "pedra", "osso", "veneno", "fogo", "sangue", "noite"),
        "enfeites": [("arvore", arvore_viva, 1), ("arvore_morta", arvore_morta, 2), ("toco", toco, 3), ("tronco", tronco_caido, 2),
                     ("arbusto", arbusto, 4), ("pedra", pedra_musgo, 2), ("cogumelos", cogumelos_luz, 2),
                     ("cranio", cranio_cervo, 1), ("teia", teia, 1), ("fogueira", fogueira, 1)],
    },
    "masmorra": {
        "piso": piso_masmorra, "ambiente": [0.62, 0.58, 0.7],
        "paleta": ("pedra", "musgo", "osso", "fogo", "couro", "aco"),
        "enfeites": [("tocha", tocha_em_pe, 2), ("barril", barril, 2), ("ossos", pilha_ossos, 3),
                     ("caixote", caixote, 2), ("coluna", coluna_quebrada, 1), ("grilhao", grilhao, 1),
                     ("pedras", pilha_pedras, 3), ("braseiro", braseiro_baixo, 1), ("jarro", jarro_barro, 2),
                     ("cranio_vela", cranio_vela, 1)],
    },
    "laboratorio": {
        "piso": piso_laboratorio, "ambiente": [0.7, 0.76, 0.82],
        "paleta": ("aco", "veneno", "couro", "ouro", "fogo", "osso", "sangue", "noite", "musgo"),
        "enfeites": [("mesa", mesa_alquimia, 2), ("caldeirao", caldeirao, 1), ("estante", estante, 2),
                     ("jarra", jarra_grande, 2), ("candelabro", candelabro, 2),
                     ("vela", vela_chao, 2), ("livros", livros_chao, 3), ("tubo", tubo_quebrado, 2), ("cadeira", cadeira_tombada, 2)],
    },
    "cidade": {
        "piso": piso_cidade, "piso_px": 512, "ambiente": [0.5, 0.55, 0.78], "fixos": fixos_cidade,
        "paleta": ("pedra", "noite", "fogo", "aco", "ouro", "osso", "sangue", "musgo"),
        "enfeites": [("poste", poste_rua, 0), ("lixeira", lixeira, 2), ("hidrante", hidrante, 1), ("cone", cone_transito, 2),
                     ("caixote", caixote, 1), ("barril", barril, 1),
                     ("sacos", saco_lixo, 3), ("banco", banco_praca, 1), ("barril_fogo", barril_fogo, 1), ("correio", caixa_correio, 1)],
    },
}


def chamar(f, r):
    return f(r) if f.__code__.co_argcount == 1 else f()


def gerar(nome, cfg):
    import numpy as np
    pal = px3.paleta_de(*cfg["paleta"])
    pasta = os.path.join(SAIDA, nome)
    # ---- piso (cada cenário pode ter um azulejo maior: a cidade usa 512 px, um cruzamento inteiro)
    global L
    tam = cfg.get("piso_px", PISO)
    L = tam / PX
    px3.limpar_cena()
    px3.preparar_suave(tam, tam, FATOR)
    px3.camera_topo(L)
    px3.luz(rasante=True, suave=True)
    SUAVE[0] = True
    cfg["piso"](random.Random(nome))
    SUAVE[0] = False
    repetir_3x3()
    bruto = px3.reduzir(px3.render_rgba(), FATOR)
    piso = px3.pixelar(bruto, contorno=False, paleta=pal, luz_borda=False, pontilhado=0.03)
    piso[:, :, 3] = 1.0
    px3.salvar_png(piso, os.path.join(pasta, "piso.png"))
    # ---- enfeites
    imagens, itens = [], []
    for nome_e, f, peso in cfg["enfeites"]:
        px3.limpar_cena()
        px3.preparar_render(ENFEITE, ENFEITE)
        cam = px3.camera(elevacao_graus=32.0, escala=ENFEITE / PX)
        px3.luz()
        luz = chamar(f, random.Random(nome + nome_e))
        bpy.context.view_layer.update()
        pe = px3.pe_na_tela(cam)
        img, pe_rel = px3.recortar(px3.pixelar(px3.render_rgba(), paleta=pal), pe)
        item = {"nome": nome_e, "peso": peso, "pe": [round(pe_rel[0]), round(pe_rel[1])]}
        imagens.append(img)
        if luz:
            fx, fy = px3.pe_na_tela(cam, luz["ponto"])
            item["luz"] = {"fonte": [round(fx - pe[0]), round(fy - pe[1])], "pisca": luz["pisca"], "raio": luz["raio"]}
            imagens.append(px3.brilho(luz["raio"], luz["rampa"]))                 # poça de luz no chão
            imagens.append(px3.brilho(max(8, luz["raio"] // 4), luz["rampa"], 3))  # halo na fonte
        itens.append(item)
    atlas, pos = px3.empacotar(imagens)
    k = 0
    for item in itens:
        item["regiao"] = list(pos[k])
        k += 1
        if "luz" in item:
            item["luz"]["poca"] = list(pos[k])
            item["luz"]["halo"] = list(pos[k + 1])
            k += 2
    px3.salvar_png(atlas, os.path.join(pasta, "enfeites.png"))
    with open(os.path.join(pasta, "cenario.json"), "w", encoding="utf-8") as fp:
        json.dump({"_gerado_por": "fonte_arte/modelos3d/cenarios.py (não edite à mão)", "piso": "piso.png",
                   "enfeites": "enfeites.png", "ambiente": cfg["ambiente"], "itens": itens,
                   "fixos": cfg["fixos"]() if "fixos" in cfg else []}, fp, ensure_ascii=False, indent=1)
    _ = np
    print("CENARIO OK", nome, "itens", len(itens), "atlas", atlas.shape[1], "x", atlas.shape[0])


def main():
    so = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else []
    for nome, cfg in CENARIOS.items():
        if not so or nome in so:
            gerar(nome, cfg)


main()

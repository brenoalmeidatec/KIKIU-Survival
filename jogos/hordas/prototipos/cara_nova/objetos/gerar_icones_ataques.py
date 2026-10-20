"""Icones PROPRIOS (desenhados em codigo, sem folha de imagem) das cartas da leva 6: Sentinela de Bambu, Cabaca de Polvora e as duas fusoes
(Pagode do Trovao e Fogos de Festival). Mesmo formato dos outros icones de carta (assets/v2/icones_cartas): 32x32 (escolha, bau, slots da
HUD) e 16x16 em 16/ (linha do SUA BUILD), RGBA com alfa binario e contorno escuro de 1 px.

Uso (a partir desta pasta):
    python gerar_icones_ataques.py                 grava os 8 PNG e acrescenta as 4 entradas ao indice.json (nao mexe nas outras)
    python gerar_icones_ataques.py --previa X.png  grava tambem uma previa (3x) para olhar

As entradas levam "proprio": true: `python gerar_objetos.py icones` (que refaz o indice das folhas do #272) as preserva (ver gerar_icones).
"""
import json
import os
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "..", "projeto", "assets", "v2", "icones_cartas"))
CONTORNO = (30, 20, 14, 255)

# (id, categoria)
ICONES = [
    ("sentinela_bambu", "golpe"),
    ("cabaca_polvora", "golpe"),
    ("pagode_do_trovao", "evolucao"),
    ("fogos_de_festival", "evolucao"),
]

BAMBU = (214, 178, 102, 255)
BAMBU_LUZ = (244, 220, 156, 255)
BAMBU_SOMBRA = (140, 100, 50, 255)
MARROM = (96, 62, 30, 255)
AMBAR = (255, 186, 64, 255)
BRANCO_QUENTE = (255, 244, 196, 255)
OCRE = (208, 144, 52, 255)
OCRE_SOMBRA = (150, 96, 34, 255)
OCRE_LUZ = (244, 200, 116, 255)
AZUL = (56, 82, 132, 255)
AZUL_LUZ = (150, 196, 255, 255)
AZUL_FRIO = (210, 235, 255, 255)


class Pena:
    """Desenha em coordenadas de 32 px numa tela de `lado` px (escala lado/32), sem suavizacao."""

    def __init__(self, lado):
        self.s = lado / 32.0
        self.im = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def p(self, x, y):
        return (x * self.s, y * self.s)

    def pontos(self, pts):
        return [self.p(x, y) for x, y in pts]

    def poligono(self, pts, cor):
        self.d.polygon(self.pontos(pts), fill=cor)

    def linha(self, a, b, cor, larg=1.0):
        self.d.line([self.p(*a), self.p(*b)], fill=cor, width=max(1, round(larg * self.s)))

    def circulo(self, cx, cy, r, cor):
        r = max(0.5, r * self.s)
        x, y = cx * self.s, cy * self.s
        self.d.ellipse([x - r, y - r, x + r, y + r], fill=cor)

    def ponto(self, x, y, cor):
        self.d.point(self.p(x, y), fill=cor)

    def pronto(self):
        """Alfa binario e contorno escuro de 1 px em volta."""
        im = self.im
        a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
        im.putalpha(a)
        w, h = im.size
        saida = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        px = im.load()
        sp = saida.load()
        for y in range(h):
            for x in range(w):
                if px[x, y][3]:
                    sp[x, y] = px[x, y]
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3]:
                        sp[x, y] = CONTORNO
                        break
        return saida


def sentinela(pe):
    # perna de tras e pernas da frente (bambu com nos)
    pe.linha((16, 14), (16, 28), BAMBU_SOMBRA, 2)
    pe.linha((16, 14), (8, 28), BAMBU, 3)
    pe.linha((16, 14), (24, 28), BAMBU, 3)
    for f in (0.4, 0.75):
        for fx in (8, 24):
            x = 16 + (fx - 16) * f
            y = 14 + 14 * f
            pe.linha((x - 2, y), (x + 2, y), MARROM, 1)
    pe.linha((14, 15), (13, 24), BAMBU_LUZ, 1)
    # plataforma e balestra (arco de bambu curvo, corda e virote armado apontando para cima)
    pe.poligono([(10, 12), (22, 12), (22, 15), (10, 15)], BAMBU_SOMBRA)
    pe.linha((10, 12), (22, 12), BAMBU_LUZ, 1)
    pe.poligono([(5, 9), (7, 7), (16, 10), (25, 7), (27, 9), (16, 12)], MARROM)
    pe.linha((6, 8), (16, 11), BAMBU, 1.5)
    pe.linha((26, 8), (16, 11), BAMBU, 1.5)
    pe.linha((6, 9), (26, 9), (245, 240, 215, 255), 1)  # a corda
    pe.linha((16, 10), (16, 2), AMBAR, 2)
    pe.poligono([(14, 4), (16, 0), (18, 4)], BRANCO_QUENTE)
    pe.circulo(25, 3, 1.2, AMBAR)  # faisca da boca
    pe.ponto(25, 3, BRANCO_QUENTE)


def cabaca(pe):
    pe.circulo(16, 21, 8.5, OCRE)
    pe.circulo(16, 12.5, 5.5, OCRE)
    pe.circulo(16, 17, 6, OCRE)  # a cintura da cabaca
    pe.circulo(18.5, 23.5, 5, OCRE_SOMBRA)
    pe.circulo(18, 23.5, 3, OCRE)
    pe.circulo(12.5, 19.5, 2.2, OCRE_LUZ)
    pe.circulo(14, 10.5, 1.5, OCRE_LUZ)
    pe.linha((12, 15.5), (20, 15.5), MARROM, 2)  # corda do gargalo
    pe.linha((16, 8), (17, 5), MARROM, 1.5)  # pavio
    pe.linha((17, 5), (20, 3.5), MARROM, 1.5)
    pe.circulo(22.5, 3, 2.6, AMBAR)  # a faisca na ponta
    pe.circulo(22.5, 3, 1.3, BRANCO_QUENTE)
    pe.linha((22.5, -0.5), (22.5, 6.5), BRANCO_QUENTE, 1)
    pe.linha((19, 3), (26, 3), BRANCO_QUENTE, 1)


def pagode(pe):
    # base e pilares
    pe.poligono([(5, 27), (27, 27), (27, 30), (5, 30)], BAMBU_SOMBRA)
    pe.linha((7, 27), (7, 19), BAMBU, 2)
    pe.linha((25, 27), (25, 19), BAMBU, 2)
    pe.linha((16, 27), (16, 19), BAMBU_SOMBRA, 2)
    # telhado de baixo (largo) e de cima (menor), azuis com a beirada clara
    pe.poligono([(2, 19), (30, 19), (24, 13), (8, 13)], AZUL)
    pe.linha((2, 19), (30, 19), AZUL_LUZ, 1.5)
    pe.linha((9, 14), (23, 14), (86, 120, 180, 255), 1)
    pe.linha((10, 13), (10, 8), BAMBU, 2)
    pe.linha((22, 13), (22, 8), BAMBU, 2)
    pe.poligono([(6, 9), (26, 9), (21, 4), (11, 4)], AZUL)
    pe.linha((6, 9), (26, 9), AZUL_LUZ, 1.5)
    # o orbe elétrico no alto e um raio em zigue-zague de lado
    pe.circulo(16, 2.5, 2.4, AZUL_LUZ)
    pe.circulo(16, 2.5, 1.2, AZUL_FRIO)
    pe.poligono([(28, 8), (23, 17), (26, 17), (21, 28), (29, 15), (26, 15), (30, 8)], AMBAR)
    pe.poligono([(27, 9), (24.5, 16), (27.5, 16), (24, 24), (28, 15), (25, 15), (28.5, 9)], BRANCO_QUENTE)


def fogos(pe):
    import math

    def explosao(cx, cy, r_longo, r_curto, cor, miolo, n=8):
        for i in range(n):
            a = math.tau * i / n
            r = r_longo if i % 2 == 0 else r_curto
            pe.linha((cx + math.cos(a) * 2, cy + math.sin(a) * 2), (cx + math.cos(a) * r, cy + math.sin(a) * r), cor, 2 if i % 2 == 0 else 1)
            pe.circulo(cx + math.cos(a) * (r + 1.2), cy + math.sin(a) * (r + 1.2), 1.1, miolo)
        pe.circulo(cx, cy, 2.4, miolo)

    explosao(11, 21, 9, 5, (214, 56, 48, 255), (255, 170, 150, 255))
    explosao(22, 10, 8, 4, (255, 210, 70, 255), BRANCO_QUENTE)
    explosao(25, 25, 5, 3, (70, 210, 100, 255), (190, 255, 200, 255), 6)
    pe.circulo(22, 10, 2, BRANCO_QUENTE)
    pe.circulo(11, 21, 1.5, BRANCO_QUENTE)


DESENHOS = {"sentinela_bambu": sentinela, "cabaca_polvora": cabaca, "pagode_do_trovao": pagode, "fogos_de_festival": fogos}


def gerar(previa=None):
    os.makedirs(os.path.join(SAIDA, "16"), exist_ok=True)
    indice_c = os.path.join(SAIDA, "indice.json")
    with open(indice_c, encoding="utf-8") as f:
        indice = json.load(f)
    grandes = []
    pequenos = []
    for cid, categoria in ICONES:
        g = Pena(32)
        DESENHOS[cid](g)
        g = g.pronto()
        q = Pena(16)
        DESENHOS[cid](q)
        q = q.pronto()
        g.save(os.path.join(SAIDA, cid + ".png"))
        q.save(os.path.join(SAIDA, "16", cid + ".png"))
        indice["icones"][cid] = {"arquivo": cid + ".png", "pequeno": "16/" + cid + ".png", "categoria": categoria, "proprio": True}
        grandes.append(g)
        pequenos.append(q)
        print("  %-20s %s" % (cid, categoria))
    with open(indice_c, "w", encoding="utf-8", newline="\n") as f:
        json.dump(indice, f, ensure_ascii=False, indent=1)
        f.write("\n")
    if previa:
        tela = Image.new("RGBA", (len(ICONES) * 112 + 8, 3 * 32 + 3 * 16 + 24), (34, 30, 42, 255))
        for i, (g, q) in enumerate(zip(grandes, pequenos)):
            tela.alpha_composite(g.resize((96, 96), Image.NEAREST), (8 + i * 112, 8))
            tela.alpha_composite(q.resize((48, 48), Image.NEAREST), (8 + i * 112 + 24, 112))
        tela.convert("RGB").save(previa)
        print("previa", previa)


if __name__ == "__main__":
    pv = None
    if "--previa" in sys.argv:
        pv = sys.argv[sys.argv.index("--previa") + 1]
    gerar(pv)

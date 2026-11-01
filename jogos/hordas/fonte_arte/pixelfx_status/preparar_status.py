"""Prepara as folhas de status do pixelfx (MIT, Copyright (c) 2026 Patch e Hugo Duprez) para os monstros do KIKIU.

As folhas originais (status/slowed, status/stunned) trazem tambem o corpo do boneco padrao. Aqui ficam so as partes de cima
(o relogio da lentidao e as estrelas do atordoamento), o relogio e reduzido a metade com media de caixa (o monstro do jogo e pequeno); as estrelas ficam no tamanho original.
A chama (burning) NAO sai do pixelfx: o quadro original e o boneco inteiro em chamas. Ela e desenhada por este script,
quadro a quadro, com paleta propria (arte nossa, sem origem externa).

Uso: python preparar_status.py <pasta com status/slowed/slowed.png e status/stunned/stunned.png> <pasta de saida>
"""
import math
import sys
from pathlib import Path

from PIL import Image


def quadros(folha, w, h, cols, n):
    for i in range(n):
        c, r = i % cols, i // cols
        yield folha.crop((c * w, r * h, c * w + w, r * h + h))


def reduzir(q, caixa):
    """Recorta `caixa` do quadro e reduz a metade (media de caixa), com alfa de borda dura."""
    rec = q.crop(caixa)
    w, h = rec.size
    pre = Image.new("RGBA", (w, h))
    px, dst = rec.load(), pre.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            dst[x, y] = (r * a // 255, g * a // 255, b * a // 255, a)  # alfa premultiplicado antes de misturar
    mini = pre.resize((w // 2, h // 2), Image.BOX)
    out = Image.new("RGBA", mini.size)
    m, o = mini.load(), out.load()
    for y in range(mini.height):
        for x in range(mini.width):
            r, g, b, a = m[x, y]
            if a >= 96:
                k = 255.0 / a
                o[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), 255)
    return out


def recortar(q, caixa):
    return q.crop(caixa)


def montar(qs, cols):
    w, h = qs[0].size
    lin = math.ceil(len(qs) / cols)
    folha = Image.new("RGBA", (w * cols, h * lin))
    for i, q in enumerate(qs):
        folha.paste(q, ((i % cols) * w, (i // cols) * h))
    return folha


def chama(n=12, w=24, h=32):
    cores = [(150, 28, 22), (232, 84, 24), (255, 176, 40), (255, 238, 150)]  # borda, laranja, amarelo, miolo
    linguas = [(12, 20, 5.2, 0, 0.0), (7, 14, 3.6, 1, 2.1), (17, 16, 4.0, 1, 4.2)]  # x da base, altura, largura, harmonica, fase
    qs = []
    for f in range(n):
        im = Image.new("RGBA", (w, h))
        px = im.load()
        a = 2 * math.pi * f / n
        for bx, alt, larg, harm, fase in linguas:
            alt_f = alt + 3.0 * math.sin(a * (1 + harm) + fase)
            for y in range(int(alt_f)):
                t = y / alt_f
                lw = larg * (1.0 - t**1.6) * 0.5
                cx = bx + 1.6 * t * math.sin(a * (1 + harm) + fase + t * 2.0)
                for camada, esc in enumerate((1.0, 0.68, 0.4, 0.2)):
                    ww = lw * esc
                    if ww < 0.4:
                        continue
                    for x in range(int(round(cx - ww)), int(round(cx + ww)) + 1):
                        yy = h - 2 - y
                        if 0 <= x < w and 0 <= yy < h:
                            px[x, yy] = cores[camada] + (255,)
        for k in range(3):  # brasas que sobem
            fase = (f + k * n / 3.0) / n
            ex = 6 + (k * 7 + f) % 13
            ey = h - 8 - int(fase * 20)
            if 0 <= ey < h:
                px[ex, ey] = (255, 200, 80, 255) if fase < 0.6 else (230, 90, 30, 255)
        qs.append(im)
    return qs


def main():
    ent, saida = Path(sys.argv[1]), Path(sys.argv[2])
    saida.mkdir(parents=True, exist_ok=True)
    lento = Image.open(ent / "status/slowed/slowed.png").convert("RGBA")
    qs = [reduzir(q, (4, 0, 60, 54)) for q in quadros(lento, 64, 76, 10, 72)]
    montar(qs, 10).save(saida / "slowed.png")
    print("slowed", qs[0].size, len(qs))
    atord = Image.open(ent / "status/stunned/stunned.png").convert("RGBA")
    qs = [recortar(q, (4, 0, 56, 42)) for q in quadros(atord, 60, 64, 8, 60)]
    montar(qs, 8).save(saida / "stunned.png")
    print("stunned", qs[0].size, len(qs))
    qs = chama()
    montar(qs, 6).save(saida / "burning.png")
    print("burning", qs[0].size, len(qs))


main()

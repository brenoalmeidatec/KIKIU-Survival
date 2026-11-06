"""Gera as folhas da chama de status (fogo sobre o monstro): arte propria, procedural, sem origem externa.

Tres tamanhos pre-desenhados (P, M, G) para o monstro comum, o grande e o elite/chefe grandes. Cada quadro ja traz o conjunto de linguas de fogo (uma
principal alta e pontuda, outras menores dos lados e um leito baixo e largo na base), com fase e harmonica diferentes por lingua, e as brasas soltas
subindo. O ciclo emenda sem salto: tudo e funcao periodica de f/N com harmonicas inteiras. Pixel art 1:1: alfa 0 ou 255, sem suavizacao, contorno
escuro de 1 px, paleta de 5 tons (vermelho, laranja, ambar, amarelo, miolo claro). Referencia de direcao: notas/artes_chatgpt/A24_queimando_ref.png
(gerada para o projeto, so direcao: nada dela entra nas folhas).

Uso: python gerar_chama.py [pasta de saida]   (padrao: projeto/assets/v2/pixelfx/status)
Saida: chama_p.png, chama_m.png, chama_g.png (6 colunas x 2 linhas, 12 quadros) e, no stdout, as medidas que o teste v2_chama_sprites confere.
Os numeros de cada tamanho (quadro, pivo, fps) vivem em dados/v2_pixelfx.json (entradas chama_p, chama_m, chama_g); mudar aqui pede mudar la.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

N = 12  # quadros por ciclo (14 fps: ~0,86 s por volta)
COLUNAS = 6

CONTORNO = (88, 14, 12)
PALETA = [(204, 42, 20), (238, 102, 24), (255, 166, 38), (255, 214, 92), (255, 242, 176)]  # vermelho, laranja, ambar, amarelo, miolo
BRASA_COR = [(255, 242, 176), (255, 190, 60), (238, 102, 24), (204, 42, 20)]  # nova -> velha

# Cada lingua: x da base (px a partir do centro), altura, meia-largura na base, balanco lateral, harmonica (1 ou 2), fase (rad), inclinacao da ponta (px).
# O ultimo "leito" e a lingua baixa e larga que une as outras na base.
TAMANHOS = {
    "p": {
        "quadro": (40, 48),
        "linguas": [
            (0, 35, 7.0, 3.6, 1, 0.0, 0.0),
            (-8, 22, 5.0, 2.8, 2, 1.7, -2.0),
            (8, 26, 5.2, 3.0, 1, 3.4, 2.0),
            (0, 11, 13.0, 1.2, 2, 0.8, 0.0),
        ],
        "brasas": 3,
        "subida": 16,
    },
    "m": {
        "quadro": (72, 88),
        "linguas": [
            (0, 60, 11.0, 5.4, 1, 0.0, 0.0),
            (-14, 40, 8.0, 4.0, 2, 1.7, -3.5),
            (14, 46, 8.4, 4.6, 1, 3.4, 3.5),
            (-26, 26, 6.0, 3.2, 1, 5.0, -2.5),
            (26, 30, 6.0, 3.2, 2, 0.9, 2.5),
            (0, 17, 25.0, 1.6, 2, 0.8, 0.0),
        ],
        "brasas": 5,
        "subida": 28,
    },
    "g": {
        "quadro": (104, 128),
        "linguas": [
            (-2, 98, 15.0, 7.0, 1, 0.0, -1.5),
            (-22, 68, 12.0, 5.6, 2, 1.7, -5.0),
            (20, 78, 12.4, 6.0, 1, 3.4, 5.0),
            (8, 54, 10.0, 4.6, 2, 5.4, 1.5),
            (-38, 42, 9.0, 4.0, 1, 2.6, -3.5),
            (36, 48, 9.0, 4.0, 2, 4.4, 3.5),
            (0, 26, 42.0, 2.4, 2, 0.8, 0.0),
        ],
        "brasas": 8,
        "subida": 46,
    },
}


def lingua_pixels(cfg, f):
    """Mascara booleana (h x w) das linguas no quadro f e o calor (0 a 1) de cada pixel: 1 no eixo de uma lingua, perto da base; 0 na borda e na ponta.
    Linha 0 da matriz = topo; os pes ficam na ultima linha."""
    w, h = cfg["quadro"]
    m = np.zeros((h, w), dtype=bool)
    calor = np.zeros((h, w), dtype=float)
    fase = 2.0 * math.pi * f / N
    cx0 = w // 2
    for bx, alt, larg, bal, harm, psi, incl in cfg["linguas"]:
        alt_f = alt * (1.0 + 0.11 * math.sin(fase * (1 + harm % 2) + psi * 1.3))
        for y in range(int(alt_f) + 1):
            v = y / alt_f
            hw = larg * max(1.0 - v**1.15, 0.0) ** 0.85 * min(1.0, 0.7 + v * 2.2)
            if y < 2:
                hw *= 0.6 + 0.2 * y  # base arredondada
            cx = cx0 + bx + bal * v**1.35 * math.sin(fase * harm + psi - v * 2.3) + incl * v * v
            if hw < 0.4:
                hw = 0.4 if v < 0.97 else 0.0  # a ponta fina de 1 px
            if hw <= 0.0:
                continue
            lin = h - 1 - y
            for x in range(int(round(cx - hw)), int(round(cx + hw)) + 1):
                if 0 <= x < w and 0 <= lin < h:
                    m[lin, x] = True
                    u = min(1.0, abs(x - cx) / max(hw, 0.5))
                    q = (1.0 - u**1.4) * (1.0 - 0.7 * v) ** 1.1
                    calor[lin, x] = max(calor[lin, x], q)
    return m, calor


def quadro(cfg, f):
    w, h = cfg["quadro"]
    m, calor = lingua_pixels(cfg, f)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    pad = np.pad(m, 1, constant_values=False)
    pad[-1, :] = pad[-2, :]  # a base nao tem contorno: ela se funde ao costado do monstro
    borda = m & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    for lin in range(h):
        for x in range(w):
            if not m[lin, x]:
                continue
            if borda[lin, x]:
                img[lin, x] = CONTORNO + (255,)
                continue
            c = calor[lin, x]
            idx = 0 if c < 0.2 else 1 if c < 0.4 else 2 if c < 0.6 else 3 if c < 0.8 else 4
            img[lin, x] = PALETA[idx] + (255,)
    # brasas soltas: nascem perto do topo das linguas, sobem e esfriam; uma volta por ciclo
    topo = int(np.argmax(m.any(axis=1))) if m.any() else h - 1
    n = cfg["brasas"]
    for i in range(n):
        a = (f / N + i / n + 0.13 * (i % 3)) % 1.0
        ex = w // 2 + int(round(((i * 7) % 11 - 5) * w / 30.0 + 2.0 * math.sin(2.0 * math.pi * (a + i * 0.21))))
        ey = topo + int(0.3 * (h - topo)) - int(a * cfg["subida"])
        if a > 0.92 or not (0 <= ex < w and 0 <= ey < h):
            continue
        tam = 2 if (cfg["quadro"][1] >= 100 and a < 0.45) else 1
        cor = BRASA_COR[min(3, int(a * 4))]
        for dy in range(tam):
            for dx in range(tam):
                px, py = ex + dx, ey + dy
                if 0 <= px < w and 0 <= py < h and not m[py, px]:
                    img[py, px] = cor + (255,)
    return Image.fromarray(img, "RGBA")


def folha(cfg):
    w, h = cfg["quadro"]
    lin = math.ceil(N / COLUNAS)
    out = Image.new("RGBA", (w * COLUNAS, h * lin))
    for f in range(N):
        out.paste(quadro(cfg, f), ((f % COLUNAS) * w, (f // COLUNAS) * h))
    return out


def altura_opaca(im, cfg):
    """Maior altura (px) de pixel opaco em qualquer quadro, contada de baixo."""
    w, h = cfg["quadro"]
    a = np.array(im)[:, :, 3]
    pior = 0
    for f in range(N):
        c, r = f % COLUNAS, f // COLUNAS
        q = a[r * h : (r + 1) * h, c * w : (c + 1) * w]
        lin = np.where(q.any(axis=1))[0]
        if len(lin):
            pior = max(pior, h - int(lin[0]))
    return pior


def main():
    padrao = Path(__file__).resolve().parents[2] / "projeto/assets/v2/pixelfx/status"
    saida = Path(sys.argv[1]) if len(sys.argv) > 1 else padrao
    saida.mkdir(parents=True, exist_ok=True)
    for nome, cfg in TAMANHOS.items():
        im = folha(cfg)
        im.save(saida / f"chama_{nome}.png")
        w, h = cfg["quadro"]
        print(f"chama_{nome}: quadro {w}x{h}, {N} quadros, folha {im.size[0]}x{im.size[1]}, altura opaca max {altura_opaca(im, cfg)} px")


if __name__ == "__main__":
    main()

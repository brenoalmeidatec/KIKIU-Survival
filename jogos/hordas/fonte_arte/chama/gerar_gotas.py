"""Folha procedural das GOTAS DE FOGO de quem queima (v2/chama_gotas.gd).

Arte PROPRIA do KIKIU, sem nenhum arquivo de terceiros: cada gota e uma mini-animacao de labareda (8 quadros) desenhada aqui por regra,
com sementes fixas (mesma saida sempre). Roda: python jogos/hordas/fonte_arte/chama/gerar_gotas.py  (numpy + Pillow)

Saida: jogos/hordas/projeto/assets/v2/efeitos/chama_gotas.png
  - 4 tamanhos de labareda: p (3x4 px), m (4x5), g (4x7), xg (5x8); 2 variantes de cada (a ponta balanca para lados opostos);
    fila = tamanho * 2 + variante; 8 quadros por fila (coluna = quadro). Celula 9x12 px, ancora = centro da BASE (coluna 4, linha 11):
    e a ancora que o jogo coloca num pixel opaco do corpo do monstro.
  - o quadro avanca pela IDADE da gota: 0-1 nasce gorda e clara, 2-3 estica e a ponta tremula, 4-5 a ponta se destaca em fagulha e o corpo sobe e encolhe,
    6 corpo minusculo, 7 so uma fagulha escura. Cor por quadro (amarelo-claro, ambar, laranja, vermelho, vermelho escuro), mais clara no miolo e na base,
    mais escura nas bordas (o "contorno" so onde ajuda a leitura: lados do corpo largo).
  - alfa 0/1, sem suavizacao (pixel art 1:1, filtro NEAREST).
"""
import os
import numpy as np
from PIL import Image

CW, CH = 9, 12
CX = 4  # coluna da ancora; a linha da ancora e CH - 1
NQ = 8
PALETA = [
    (255, 244, 176),  # 0 amarelo-claro
    (255, 200, 64),  # 1 ambar
    (242, 128, 32),  # 2 laranja
    (206, 58, 22),  # 3 vermelho
    (128, 28, 16),  # 4 vermelho escuro
]
TAMANHOS = [("p", 3, 4), ("m", 4, 5), ("g", 4, 7), ("xg", 5, 8)]
ALT = [0.65, 0.9, 1.0, 1.0, 0.85, 0.6, 0.35, 0.0]  # altura do corpo (fracao da altura do tamanho)
LARG = [1.0, 1.0, 0.95, 0.85, 0.7, 0.55, 0.4, 0.0]  # largura do corpo
SOBE = [0, 0, 0, 0, 1, 2, 3, 0]  # linhas que o corpo se desprende da base
TOM = [0, 0, 1, 1, 2, 2, 3, 4]  # tom base por quadro
BALANCO = [0, 0, 1, -1, 1, -1, 1, 0]  # a ponta tremula (para qual lado, antes de ajustar a variante)


def quadro(w0, h0, q, var, rng):
    g = np.full((CH, CW), -1, dtype=np.int8)
    sinal = 1 if var == 0 else -1
    hb = int(round(h0 * ALT[q]))
    wb = max(1, int(round(w0 * LARG[q])))
    lift = SOBE[q] if q < 7 else 0
    amp = 1 if w0 <= 4 else 2
    # corpo: de baixo para cima, a largura afina; a ponta (terco de cima) balanca
    if hb > 0:
        for r in range(hb):
            f = r / max(hb, 1)
            wr = max(1, int(round(wb * (1.0 - f ** 1.5))))
            if r == hb - 1:
                wr = 1
            # a ponta tremula: o desvio cresce com o quadrado da altura (sobe em degraus de 1 px, o corpo fica ligado)
            off = int(round(sinal * BALANCO[q] * (1.5 if (w0 >= 4 and h0 >= 7) else 1) * f ** 2 * 1.4))
            esq = CX - (wr - 1) // 2 + off
            y = CH - 1 - lift - r
            if y < 0:
                continue
            for x in range(esq, esq + wr):
                if 0 <= x < CW:
                    tom = TOM[q] + 1.5 * f
                    if wr >= 3 and (x == esq or x == esq + wr - 1):
                        tom += 0.9  # borda do corpo largo: um tom mais escuro (contorno)
                    elif wr >= 2 and r < max(1, hb // 2) and q <= 3:
                        tom -= 0.9  # miolo/base mais claro
                    g[y, x] = int(min(4, max(0, round(tom))))
    # fagulha que se destaca da ponta (quadros 4 a 6), um pouco mais clara que o corpo (brasa)
    if 4 <= q <= 6:
        gap = {4: 1, 5: 2, 6: 3}[q]
        ysp = CH - 1 - lift - hb - gap + 1
        xsp = CX + sinal * BALANCO[q]
        tom = max(0, TOM[q] - 1) if q < 6 else TOM[q]
        for dy in range(2 if (h0 >= 7 and q == 4) else 1):
            if 0 <= ysp - dy < CH and 0 <= xsp < CW:
                g[ysp - dy, xsp] = tom
    if q == 7:  # so a brasa escura que sobra (uma ou duas fagulhas)
        base = CH - 1 - SOBE[6] - 2
        g[base - (h0 // 3), CX + sinal] = 4
        if h0 >= 7:
            g[base - h0 // 3 + 2, CX - sinal] = 4
    return g


def main():
    rng = np.random.default_rng(6677)
    filas = len(TAMANHOS) * 2
    folha = np.zeros((filas * CH, NQ * CW, 4), dtype=np.uint8)
    for t, (nome, w0, h0) in enumerate(TAMANHOS):
        for var in (0, 1):
            fila = t * 2 + var
            for q in range(NQ):
                g = quadro(w0, h0, q, var, rng)
                for y in range(CH):
                    for x in range(CW):
                        if g[y, x] >= 0:
                            folha[fila * CH + y, q * CW + x] = (*PALETA[g[y, x]], 255)
    aqui = os.path.dirname(os.path.abspath(__file__))
    destino = os.path.normpath(os.path.join(aqui, "..", "..", "projeto", "assets", "v2", "efeitos", "chama_gotas.png"))
    Image.fromarray(folha, "RGBA").save(destino, optimize=True)
    print("gravado", destino, folha.shape[1], "x", folha.shape[0], "px;", filas, "filas de", NQ, "quadros")
    if os.environ.get("PREVIA"):
        im = Image.fromarray(folha, "RGBA")
        fundo = Image.new("RGBA", im.size, (40, 34, 36, 255))
        fundo.alpha_composite(im)
        fundo.resize((im.width * 6, im.height * 6), Image.NEAREST).save(os.environ["PREVIA"])


if __name__ == "__main__":
    main()

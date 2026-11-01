"""Desenha o rosto do LightWolf (LW-7) em blocos de pixel, no estilo do rosto do Hazaki (52x52, poucas cores chapadas,
contorno escuro de 1 px, sem degradê, busto de frente enchendo a largura). Formas por polígonos num quadro de 52x52
sem suavização; a A17 (A17_lw_rosto.png) é a referência de cores e de desenho (cabeça de lobo branca/azul-gelo, olhos
ciano, gola azul com frisos brancos e luz no peito). Nenhuma arte de terceiros entra no resultado.

Uso (da raiz do repositório): python jogos/hordas/fonte_arte/lightwolf_rosto/gerar_rosto.py
Saída: projeto/assets/personagens/lightwolf/rosto.png (52x52 RGBA)
"""

from pathlib import Path

from PIL import Image, ImageDraw

AQUI = Path(__file__).resolve().parent
DESTINO = AQUI.parent.parent / "projeto/assets/personagens/lightwolf/rosto.png"
TAM = 52

CONT = (13, 18, 38, 255)  # contorno azul-marinho
BRANCO = (244, 249, 255, 255)
GELO = (190, 218, 245, 255)  # pelo na meia-luz
SOMBRA = (122, 168, 222, 255)  # sombra do pelo
AZ_ESC = (38, 56, 104, 255)  # gola na sombra
AZ_MED = (62, 98, 168, 255)  # gola
AZ_CLA = (96, 146, 214, 255)  # gola na luz
CIANO = (127, 243, 255, 255)
NARIZ = (30, 40, 70, 255)


def desenhar() -> Image.Image:
    im = Image.new("RGBA", (TAM, TAM), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    def poly(pts, cor):
        d.polygon(pts, fill=cor)

    # ombros e gola (embaixo, cortados pela borda como no Hazaki)
    poly([(1, 51), (3, 41), (13, 36), (39, 36), (49, 41), (51, 51)], AZ_MED)
    poly([(26, 51), (26, 36), (39, 36), (49, 41), (51, 51)], AZ_ESC)  # lado direito na sombra
    poly([(3, 41), (13, 36), (20, 38), (12, 46), (2, 49)], AZ_CLA)  # luz da esquerda no ombro
    # friso branco da gola em V
    poly([(14, 37), (26, 49), (38, 37), (35, 36), (26, 44), (17, 36)], BRANCO)
    poly([(21, 44), (26, 51), (31, 44), (26, 47)], AZ_ESC)  # peito dentro do V
    d.rectangle([24, 48, 27, 51], fill=CIANO)  # luzinha do peito

    # orelhas (por trás da cabeça)
    poly([(9, 2), (21, 14), (11, 25), (6, 20)], BRANCO)
    poly([(43, 2), (31, 14), (41, 25), (46, 20)], GELO)
    poly([(10, 8), (18, 15), (11, 21)], SOMBRA)  # miolo da orelha
    poly([(42, 8), (34, 15), (41, 21)], SOMBRA)

    # cabeça: testa larga, bochechas com tufos, focinho afinando até o queixo
    poly([(10, 21), (14, 13), (38, 13), (42, 21), (46, 28), (41, 35), (33, 41), (19, 41), (11, 35), (6, 28)], BRANCO)
    poly([(26, 13), (38, 13), (42, 21), (46, 28), (41, 35), (33, 41), (26, 41)], GELO)  # lado direito na meia-luz
    poly([(6, 28), (10, 21), (13, 29), (12, 35)], SOMBRA)  # tufo da bochecha esquerda
    poly([(46, 28), (42, 21), (39, 29), (40, 35)], SOMBRA)  # tufo da bochecha direita
    # focinho claro
    poly([(21, 28), (31, 28), (33, 36), (26, 41), (19, 36)], BRANCO)
    poly([(26, 28), (31, 28), (33, 36), (26, 41)], GELO)
    # olhos ciano com sobrancelha reta (cara decidida)
    d.rectangle([13, 21, 20, 22], fill=CONT)  # sobrancelha esquerda
    d.rectangle([32, 21, 39, 22], fill=CONT)
    d.rectangle([14, 23, 19, 25], fill=CIANO)
    d.rectangle([33, 23, 38, 25], fill=CIANO)
    d.rectangle([16, 23, 17, 25], fill=NARIZ)  # pupila
    d.rectangle([35, 23, 36, 25], fill=NARIZ)
    # nariz e boca
    d.rectangle([24, 31, 28, 33], fill=NARIZ)
    d.line([(26, 34), (26, 36)], fill=NARIZ)
    d.line([(22, 37), (24, 38)], fill=SOMBRA)
    d.line([(30, 37), (28, 38)], fill=SOMBRA)

    # contorno de 1 px em volta da silhueta toda (4 vizinhos)
    px = im.load()
    cheios = {(x, y) for y in range(TAM) for x in range(TAM) if px[x, y][3]}
    for x, y in cheios:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in cheios and 0 <= q[0] < TAM and 0 <= q[1] < TAM:
                px[q] = CONT
    # linha escura entre cabeça e gola (queixo) e dentro das orelhas
    d.line([(19, 41), (33, 41)], fill=CONT)
    return im


if __name__ == "__main__":
    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    desenhar().save(DESTINO)
    print(f"-> {DESTINO} ({TAM}x{TAM})")

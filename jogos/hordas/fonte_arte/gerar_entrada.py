"""Gera a tela de entrada (boot splash) do K.I.K.I.U a partir da arte do Alisson.

Roda:  python gerar_entrada.py          (precisa de Pillow: python -m pip install pillow)
Entrada: entrada_fonte.webp (1672x941, arte com uma faixa escura vazia no terço de cima)
Saídas:
  ../projeto/assets/icone/entrada.png        o boot splash (640x360) com o título
  entrada_antes_640x360.png                  a arte original reduzida, sem título (para o PR)

Pipeline:
  1. recorte 16:9 da fonte;
  2. redução para 640x360 com filtro BOX (média de área), não NEAREST;
  3. quantização para 48 cores, mediana de corte, sem dithering (sem grade de pontos);
  4. título PressStart2P em escala 1 (fontmode "1", sem anti-aliasing) na faixa escura;
  5. bg_color = média das bordas da imagem final (impresso no fim, para o project.godot).
"""
import os

from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.join(AQUI, "..", "projeto")
FONTE_ARTE = os.path.join(AQUI, "entrada_fonte.webp")
FONTE_TEXTO = os.path.join(PROJ, "assets", "fonte", "PressStart2P.ttf")
SAIDA = os.path.join(PROJ, "assets", "icone", "entrada.png")
SAIDA_ANTES = os.path.join(AQUI, "entrada_antes_640x360.png")

W, H = 640, 360
CORES = 48
TAM_TITULO = 32  # múltiplo de 8: 4 pixels de tela por pixel da fonte
TEXTO = "K.I.K.I.U"
TOPO_TITULO = 68  # faixa escura medida em y 44..120 (ver o relatório do PR)

OSSO = (239, 230, 210)  # texto, branco quente
CONTORNO = (10, 7, 8)  # quase preto, 2 px em volta
BRASA = (217, 86, 31)  # brilho laranja-brasa, 1 px embaixo


def recortar_16_9(img):
    """Maior recorte 16:9 que cabe na imagem, a partir do canto superior esquerdo."""
    sw, sh = img.size
    cw = min(sw, round(sh * 16 / 9))
    ch = round(cw * 9 / 16)
    return img.crop((0, 0, cw, ch))


def titulo(img, fonte):
    """Desenha o título com contorno e brilho, tudo sem pixel de transição."""
    d = ImageDraw.Draw(img)
    # Centraliza pelo bbox da tinta (máscara), não pelo bbox do glifo.
    mascara = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mascara).text((0, TOPO_TITULO), TEXTO, font=fonte, fill=255, fontmode="1")
    x0, _, x1, _ = mascara.getbbox()
    dx = (W - (x1 - x0)) // 2 - x0
    x, y = dx, TOPO_TITULO

    for ox in range(-2, 3):
        for oy in range(-2, 3):
            if (ox, oy) != (0, 0) and abs(ox) + abs(oy) >= 2:
                d.text((x + ox, y + oy), TEXTO, font=fonte, fill=CONTORNO, fontmode="1")
    d.text((x, y + 1), TEXTO, font=fonte, fill=BRASA, fontmode="1")
    d.text((x, y), TEXTO, font=fonte, fill=OSSO, fontmode="1")


def cor_media_bordas(img):
    """Média simples das cores de todas as bordas da imagem (linhas e colunas de fora)."""
    w, h = img.size
    p = img.load()
    pontos = [p[x, 0] for x in range(w)] + [p[x, h - 1] for x in range(w)]
    pontos += [p[0, y] for y in range(h)] + [p[w - 1, y] for y in range(h)]
    n = len(pontos)
    return tuple(sum(c[i] for c in pontos) / n / 255 for i in range(3))


def main():
    fonte = ImageFont.truetype(FONTE_TEXTO, TAM_TITULO)
    arte = recortar_16_9(Image.open(FONTE_ARTE).convert("RGB"))

    antes = arte.resize((W, H), Image.Resampling.BOX)
    antes.save(SAIDA_ANTES, optimize=True)

    img = antes.quantize(colors=CORES, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    img = img.convert("RGB")
    titulo(img, fonte)

    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    img.save(SAIDA, optimize=True)
    r, g, b = cor_media_bordas(img)
    print(f"ok: {SAIDA} ({W}x{H}, {CORES} cores)")
    print(f"bg_color=Color({r:.8f}, {g:.8f}, {b:.8f}, 1)  (hex #{round(r*255):02x}{round(g*255):02x}{round(b*255):02x})")


if __name__ == "__main__":
    main()

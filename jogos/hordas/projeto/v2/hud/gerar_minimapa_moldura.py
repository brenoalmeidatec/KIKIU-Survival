"""Gera v2/hud/minimapa_moldura.png: a moldura do minimapa da v2 (pedra escura com metal dourado).

Uso: python v2/hud/gerar_minimapa_moldura.py   (grava minimapa_moldura.png ao lado deste script; semente fixa, sempre o mesmo arquivo)

Layout: 170x104 px. A borda tem 10 px de espessura (é a margem do NinePatchRect, então estica sem deformar os cantos).
O miolo, de (10, 10) a (160, 94) = 150x84, sai transparente: ali o minimapa aparece por baixo. Cores de
docs/visual_2_5d/paleta.json (metal da borda, ouro, painel escuro). Os cantos são cortados em diagonal, como no HUD.
"""

import os
import random

from PIL import Image

W, H, M = 170, 104, 10
SEMENTE = 7

COR = {
    "fora": (7, 9, 13),  # contorno externo
    "pedra_clara": (46, 52, 62),  # bisel de cima e da esquerda
    "pedra": (30, 35, 43),  # corpo
    "pedra_escura": (20, 23, 29),  # bisel de baixo e da direita, argamassa
    "pedra_pingo": (40, 46, 56),  # pontinhos de textura
    "metal": (134, 137, 143),  # #86898f da paleta (borda)
    "metal_claro": (190, 194, 200),
    "metal_escuro": (79, 83, 91),
    "ouro": (224, 188, 72),  # #e0bc48 da paleta (ouro)
    "ouro_escuro": (150, 112, 32),
    "ranhura": (11, 13, 17),
}


def _cortado(x, y):
    """Canto cortado em diagonal: fica transparente."""
    return min(x + y, (W - 1 - x) + y, x + (H - 1 - y), (W - 1 - x) + (H - 1 - y)) < 4


def _rebite(x, y):
    """Rebite de ouro (3x3) em cada canto da borda. Retorna a cor ou None."""
    for cx, cy in [(5, 5), (W - 6, 5), (5, H - 6), (W - 6, H - 6)]:
        if abs(x - cx) <= 1 and abs(y - cy) <= 1:
            return COR["ouro"] if (x, y) == (cx, cy) or (x == cx and y < cy) or (y == cy and x < cx) else COR["ouro_escuro"]
    return None


def _losango(x, y):
    """Losango de ouro no meio de cima e de baixo (o 'losango' do HUD). Retorna a cor ou None."""
    for cy in (3, H - 4):
        if abs(x - W // 2) + abs(y - cy) <= 2:
            return COR["ouro"] if y <= cy else COR["ouro_escuro"]
    return None


def cor_do_pixel(x, y, rnd):
    """Cor de uma posição da borda (fora do miolo), RGBA."""
    if _cortado(x, y):
        return (0, 0, 0, 0)
    d = min(x, y, W - 1 - x, H - 1 - y)  # distância da borda externa
    if d == 0:
        return COR["fora"] + (255,)
    cor = _rebite(x, y) or _losango(x, y)
    if cor is not None:
        return cor + (255,)
    if d == 1:  # bisel externo
        return (COR["pedra_clara"] if x + y < W else COR["pedra_escura"]) + (255,)
    if 2 <= d <= 4:  # corpo de pedra em blocos (argamassa em linhas e colunas)
        if d == 2 and x % 16 == 0:
            return COR["pedra_escura"] + (255,)
        if d == 3 and y % 2 == 0 and (x + 8) % 16 == 0:
            return COR["pedra_escura"] + (255,)
        if rnd.random() < 0.08:
            return COR["pedra_pingo"] + (255,)
        return COR["pedra"] + (255,)
    if d == 5:  # metal: a linha de borda, clara em cima e à esquerda, escura embaixo e à direita
        if y < 8 or x < 8:
            return COR["metal_claro"] + (255,)
        if y > H - 9 or x > W - 9:
            return COR["metal_escuro"] + (255,)
        return COR["metal"] + (255,)
    if d == 6:  # ranhura entre o metal e o bisel interno
        return COR["ranhura"] + (255,)
    if d == 7:  # bisel interno
        return (COR["pedra_clara"] if y < H // 2 else COR["pedra_escura"]) + (255,)
    # d 8 e 9: aro de metal escuro encostado no miolo transparente
    return (COR["metal_escuro"] if y < H // 2 else COR["ranhura"]) + (255,)


def gerar(caminho):
    rnd = random.Random(SEMENTE)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(H):
        for x in range(W):
            if M <= x < W - M and M <= y < H - M:
                continue  # miolo transparente
            px[x, y] = cor_do_pixel(x, y, rnd)
    img.save(caminho)
    return img.size


if __name__ == "__main__":
    destino = os.path.join(os.path.dirname(os.path.abspath(__file__)), "minimapa_moldura.png")
    tam = gerar(destino)
    print("minimapa_moldura.png", tam, destino)

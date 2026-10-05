"""sprites v4: cabeca desenhada por codigo (headgen) sobre o corpo do sprites5; folha de andar + rostos grandes."""
import sys, os
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
import headgen as HG
import sprites5 as S5
from sprites5 import corpo_v, corpo_s, FW, FH, COLS, HEAD_Y
from sprites4 import outline, CORPO
from retratos3 import CAIRU

HN = 26   # lado da cabeca nos sprites

def sprite(nome):
    P = HG.PERFIS[nome]; p = CORPO[nome]; skin = HG.ramp(P['skin'])['mid']
    heads = {v: HG.head(P, v, N=HN) for v in ('front', 'side', 'back')}
    sheet = Image.new('RGBA', (FW * COLS, FH * 4), (0, 0, 0, 0)); cx = FW // 2
    for row, dr in enumerate(['baixo', 'esquerda', 'direita', 'cima']):
        for col in range(COLS):
            im = Image.new('RGBA', (FW, FH), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
            bob = 1 if col == 3 else 0
            if dr in ('baixo', 'cima'):
                corpo_v(d, dr, col, p, CAIRU, skin, bob); h = heads['front' if dr == 'baixo' else 'back']; hx = cx - HN // 2
            else:
                corpo_s(d, col, p, CAIRU, skin, bob); h = heads['side']; hx = cx - HN // 2 + 1
            im.alpha_composite(h, (hx, HEAD_Y - 1 - bob))
            im = outline(im)
            if dr == 'esquerda': im = im.transpose(Image.FLIP_LEFT_RIGHT)
            sheet.paste(im, (col * FW, row * FH))
    return sheet

def busto(nome, N=56):
    """rosto grande para a conversa: cabeca + ombros da farda; 6 quadros c,m,o,riso,surpresa,triste"""
    P = HG.PERFIS[nome]; skin = HG.ramp(P['skin'])['mid']
    W, H = N + 8, N + 14
    est = [('c', 'open'), ('m', 'open'), ('o', 'open'), ('o', 'blink'), ('o', 'open'), ('c', 'open')]
    sheet = Image.new('RGBA', (W * 6, H), (0, 0, 0, 0))
    for i, (m, e) in enumerate(est):
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        T, t, U, K = CAIRU['T'], CAIRU['t'], CAIRU['U'], CAIRU['K']
        d.rounded_rectangle([2, N - 4, W - 3, H + 8], radius=10, fill=T + (255,))
        d.rectangle([3, N - 2, 6, H], fill=U + (255,)); d.rectangle([W - 8, N - 2, W - 4, H], fill=t + (255,))
        d.polygon([(W // 2 - 10, N - 4), (W // 2 + 10, N - 4), (W // 2, N + 7)], fill=skin + (255,))
        d.line([(W // 2 - 10, N - 4), (W // 2, N + 7), (W // 2 + 10, N - 4)], fill=K + (255,), width=2)
        im.alpha_composite(HG.head(P, 'front', mouth=m, eyes=e, N=N), (4, 0))
        sheet.paste(outline(im), (i * W, 0))
    return sheet

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    for n in sys.argv[2:]:
        sprite(n).save(f'{out}/{n}_sprites_v4.png'); busto(n).save(f'{out}/{n}_busto.png')

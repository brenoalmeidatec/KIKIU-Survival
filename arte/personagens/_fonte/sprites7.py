"""sprites v5: cabeca de rosto2 (proporcoes da foto) no corpo do sprites5."""
import sys, os
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
import rosto2 as R2
import traco2 as T2
from headgen import ramp
from sprites5 import corpo_v, corpo_s, FW, FH, COLS, HEAD_Y
from sprites4 import outline, CORPO
from retratos3 import CAIRU
HN = 26
PERFIS = {'nicao': R2.NICAO}

def sprite(nome):
    P = PERFIS[nome]; p = CORPO[nome]; skin = ramp(P['skin'])['mid']
    heads = {'front': T2.rosto(T2.NICAO, HN), 'side': R2.lado(P, N=HN), 'back': R2.costas(P, N=HN)}
    sheet = Image.new('RGBA', (FW * COLS, FH * 4), (0, 0, 0, 0)); cx = FW // 2
    for row, dr in enumerate(['baixo', 'esquerda', 'direita', 'cima']):
        for col in range(COLS):
            im = Image.new('RGBA', (FW, FH), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
            bob = 1 if col == 3 else 0
            if dr in ('baixo', 'cima'):
                corpo_v(d, dr, col, p, CAIRU, skin, bob); h = heads['front' if dr == 'baixo' else 'back']
            else:
                corpo_s(d, col, p, CAIRU, skin, bob); h = heads['side']
            im.alpha_composite(h, (cx - HN // 2 + (1 if dr in ('esquerda', 'direita') else 0), HEAD_Y - 1 - bob))
            im = outline(im)
            if dr == 'esquerda': im = im.transpose(Image.FLIP_LEFT_RIGHT)
            sheet.paste(im, (col * FW, row * FH))
    return sheet

def busto(nome, N=48):
    P = PERFIS[nome]; skin = ramp(P['skin'])['mid']
    W, H = N + 8, N + 14
    est = [('c', 'open'), ('m', 'open'), ('o', 'open'), ('o', 'blink'), ('o', 'open'), ('c', 'open')]
    sheet = Image.new('RGBA', (W * 6, H), (0, 0, 0, 0))
    T, t, U, K = CAIRU['T'], CAIRU['t'], CAIRU['U'], CAIRU['K']
    for i, (m, e) in enumerate(est):
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        d.rounded_rectangle([2, N - 4, W - 3, H + 8], radius=10, fill=T + (255,))
        d.rectangle([3, N - 2, 6, H], fill=U + (255,)); d.rectangle([W - 8, N - 2, W - 4, H], fill=t + (255,))
        d.polygon([(W // 2 - 9, N - 4), (W // 2 + 9, N - 4), (W // 2, N + 6)], fill=ramp(P['skin'])['lo'] + (255,))
        d.line([(W // 2 - 9, N - 4), (W // 2, N + 6), (W // 2 + 9, N - 4)], fill=K + (255,), width=2)
        im.alpha_composite(T2.rosto(T2.NICAO, N, m, e), (4, 0))
        sheet.paste(outline(im), (i * W, 0))
    return sheet

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    for n in sys.argv[2:]:
        sprite(n).save(f'{out}/{n}_sprites_v5.png'); busto(n).save(f'{out}/{n}_busto.png')

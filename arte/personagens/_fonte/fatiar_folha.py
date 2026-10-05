"""Corta uma folha de sprites gerada por IA em quadros nitidos e sem fundo verde.

Uso: python3 fatiar_folha.py FOLHA.png COLUNAS LINHAS SAIDA.png [ALTURA_QUADRO=64] [CORES=28]
- tira o fundo (cor do canto da imagem) com tolerancia e remove franjas
- acha o personagem em cada celula e alinha todos pelo chao e pelo centro
- reduz para uma grade pequena (todos com o mesmo tamanho de pixel), paleta curta, sem borrar
- grava a folha final e um preview ampliado com vizinho mais proximo
"""
import sys
import numpy as np
from PIL import Image

def tira_fundo(im, tol=46):
    a = np.array(im.convert('RGB')).astype(int)
    h, w, _ = a.shape
    cantos = np.array([a[2, 2], a[2, w - 3], a[h - 3, 2], a[h - 3, w - 3]])
    bg = np.median(cantos, axis=0)
    dist = np.abs(a - bg).sum(axis=2)
    alpha = (dist > tol).astype(np.uint8) * 255
    # limpa pontinhos soltos e franjas de 1px
    from PIL import ImageFilter
    al = Image.fromarray(alpha).filter(ImageFilter.MedianFilter(3))
    out = im.convert('RGBA'); out.putalpha(al)
    return out

def fatiar(path, cols, rows, saida, alt=64, cores=28):
    im = tira_fundo(Image.open(path))
    W, H = im.size
    cw, ch = W // cols, H // rows
    celulas, caixas = [], []
    for r in range(rows):
        for c in range(cols):
            cel = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            bb = cel.getchannel('A').getbbox()
            celulas.append(cel); caixas.append(bb)
    validos = [b for b in caixas if b]
    maxh = max(b[3] - b[1] for b in validos); maxw = max(b[2] - b[0] for b in validos)
    esc = (alt - 4) / maxh                      # mesma escala para todos os quadros
    fw = int(maxw * esc) + 6
    frames = []
    for cel, bb in zip(celulas, caixas):
        q = Image.new('RGBA', (fw, alt), (0, 0, 0, 0))
        if bb:
            rec = cel.crop(bb)
            nw, nh = max(1, round(rec.width * esc)), max(1, round(rec.height * esc))
            rec = rec.resize((nw, nh), Image.BOX)
            q.alpha_composite(rec, ((fw - nw) // 2, alt - 2 - nh))   # centro e chao alinhados
        frames.append(q)
    folha = Image.new('RGBA', (fw * cols, alt * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        folha.alpha_composite(f, ((i % cols) * fw, (i // cols) * alt))
    # paleta curta, sem tremida; alfa binario
    al = folha.getchannel('A').point(lambda v: 255 if v > 127 else 0)
    pal = folha.convert('RGB').quantize(colors=cores, method=Image.MEDIANCUT, dither=Image.NONE).convert('RGBA')
    pal.putalpha(al)
    pal.save(saida)
    S = 6
    prev = Image.new('RGBA', (pal.width * S, pal.height * S), (127, 209, 127, 255))
    prev.alpha_composite(pal.resize((pal.width * S, pal.height * S), Image.NEAREST))
    prev.save(saida.replace('.png', '_preview.png'))
    print('quadros', cols * rows, 'de', fw, 'x', alt)

if __name__ == '__main__':
    a = sys.argv
    fatiar(a[1], int(a[2]), int(a[3]), a[4], int(a[5]) if len(a) > 5 else 64, int(a[6]) if len(a) > 6 else 28)

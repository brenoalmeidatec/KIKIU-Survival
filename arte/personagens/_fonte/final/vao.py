import sys, numpy as np
from PIL import Image
FMT = {'andando.png': (44, 60), 'andando_8.png': (44, 60), 'acoes.png': (64, 64), 'acoes2.png': (64, 64), 'cena.png': (100, 140)}
base = sys.argv[1]; tot = 0
for n in 'nicao lucas joao matheus beto lukako fabio breno'.split():
    for f, (w, h) in FMT.items():
        a = np.asarray(Image.open(f'{base}/{n}/{f}').convert('RGBA'))[..., 3] > 0
        for y0 in range(0, a.shape[0], h):
            for x0 in range(0, a.shape[1], w):
                q = a[y0:y0 + h, x0:x0 + w]
                if not q.any(): continue
                # componente principal: maior componente conexa; outras partes grandes = cabeca solta
                import cv2
                nlab, lab, st, _ = cv2.connectedComponentsWithStats(q.astype(np.uint8), connectivity=8)
                big = [i for i in range(1, nlab) if st[i, 4] >= 25]
                if len(big) > 1:
                    tot += 1; print('solto', n, f, x0 // w, y0 // h, [int(st[i, 4]) for i in big])
print('quadros com partes soltas:', tot)

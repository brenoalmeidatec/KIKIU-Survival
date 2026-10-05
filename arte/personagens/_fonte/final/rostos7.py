"""rosto_hd.png: rosto de dialogo = a propria foto pixelada, fiel (sem redesenhar olhos/boca).
104x104 por quadro (o dobro de detalhe do rosto.png de 52; no jogo desenha em escala 1 no mesmo tamanho de tela).
Usa os pontos do rosto so para alinhar, recortar e animar: boca abre baixando o queixo da foto,
piscar fecha a palpebra com a pele da propria foto. Tambem gera rosto.png 52x52 (reduzido) para compatibilidade."""
import sys, os, cv2, numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, '.')
import rostos6 as R6
from final import QUADROS

N = 100; S = 2; NS = N * S          # face em 100 px, trabalho em 200
R6.G, R6.K, R6.GK = N, S, NS
BG = (74, 78, 96); OUT = (22, 18, 24); AZUL = (36, 84, 200); AZUL2 = (24, 56, 150)
AJ = {
    'nicao': dict(dist=17, olho_y=34, capacete=True, duro=(.6, .74), manchas=[(78, 38, 14), (50, 2, 31), (186, 10, 8)]),
    'lucas': dict(dist=15, olho_y=36, espelho='esquerda', teto=1.3, cab_l=.9, cab_a=.9, duro=(.66, .78)),
    'joao': dict(dist=17, olho_y=34),
    'matheus': dict(dist=16, olho_y=34),
    'beto': dict(dist=16, olho_y=34),
    'lukako': dict(dist=16, olho_y=34),
    'fabio': dict(dist=17, olho_y=34),
    'breno': dict(dist=17, olho_y=34, teto=1.25, luz=1.12),
}


def base(nome):
    aj = AJ[nome]
    a, f = R6.alinhar(nome, aj)
    mk, _ = R6.mascara(a, f, aj)
    fs = f / S
    # tira reflexo verde/azul do cabelo e da pele (parede, figurinha)
    hsv_ = cv2.cvtColor(a, cv2.COLOR_BGR2HSV)
    verde = (hsv_[..., 0] > 35) & (hsv_[..., 0] < 100)
    hsv_[..., 1] = np.where(verde, hsv_[..., 1] // 4, hsv_[..., 1]); a = cv2.cvtColor(hsv_, cv2.COLOR_HSV2BGR)
    if nome == 'nicao':  # fundo laranja do lado das temporas
        lar = (hsv_[..., 0] < 20) & (hsv_[..., 1] > 120) & (hsv_[..., 2] > 120)
        nuc = np.zeros(mk.shape, np.uint8); cv2.fillConvexPoly(nuc, cv2.convexHull(f[R6.OVAL].astype(np.int32)), 1)
        mk = mk & ~(lar & (nuc == 0))
    rgb = cv2.cvtColor(a, cv2.COLOR_BGR2RGB)
    small = Image.fromarray(rgb).resize((N, N), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 50, 2))
    q = np.array(small.quantize(colors=56, method=Image.MEDIANCUT, dither=Image.NONE).convert('RGB'))
    ms = cv2.resize(mk * 255, (N, N), interpolation=cv2.INTER_AREA) > 120
    # limpa franja fria/branca na borda (fundo de figurinha)
    hsv = cv2.cvtColor(q, cv2.COLOR_RGB2HSV)
    for _ in range(2):
        sh_ = np.pad(ms, 1)
        borda = ms & ~(sh_[:-2, 1:-1] & sh_[2:, 1:-1] & sh_[1:-1, :-2] & sh_[1:-1, 2:])
        frio = ((hsv[..., 0] > 70) & (hsv[..., 0] < 150) & (hsv[..., 1] > 50)) | ((hsv[..., 2] > 190) & (hsv[..., 1] < 60))
        ms = ms & ~(borda & frio)
    inv = np.pad((~ms).astype(np.uint8), 1, constant_values=1); fm = np.zeros((N + 4, N + 4), np.uint8)
    cv2.floodFill(inv, fm, (0, 0), 2); ms = ms | (inv[1:-1, 1:-1] != 2)
    # centraliza o rosto no quadro (centro do contorno do rosto em x = N/2)
    dx = int(round(N / 2 - fs[R6.OVAL][:, 0].mean()))
    q = np.roll(q, dx, axis=1); ms = np.roll(ms, dx, axis=1); fs = fs.copy(); fs[:, 0] += dx
    if dx > 0: ms[:, :dx] = False
    elif dx < 0: ms[:, dx:] = False
    out = np.zeros((N, N, 3), np.uint8); out[:] = BG
    allm = np.zeros((N, N), bool)
    larg = np.ptp(fs[R6.OVAL][:, 0]); cx = N // 2
    yq = int(round(fs[152][1])) + 1
    amostra = np.vstack([q[int(fs[i][1]) - 1:int(fs[i][1]) + 2, int(fs[i][0]) - 1:int(fs[i][0]) + 2].reshape(-1, 3) for i in (205, 425, 50, 280)])
    pele = np.median(amostra, 0)
    tom = lambda k: np.clip(pele * .9 * k, 0, 255).astype(np.uint8)
    # pescoco: coluna larga ~40% do rosto, luz a esquerda, sombra a direita e embaixo do queixo
    nw = max(10, int(larg * .5)); x0n, x1n = cx - nw // 2, cx + nw // 2
    ys = yq + 6
    for y in range(int(yq - larg * .35), min(N, ys + 3)):
        for x in range(x0n, x1n + 1):
            k = 1.0
            if x <= x0n + 1: k = 1.08
            if x >= x1n - 2: k = .78
            if yq - 2 <= y <= yq + 3: k *= .72          # sombra do queixo
            out[y, x] = tom(k); allm[y, x] = True
    # camisa: ombros arredondados, sombra a direita, gola redonda
    for y in range(ys, N):
        dy = y - ys
        w = int(nw / 2 + 2 + 36 * (1 - np.exp(-dy / 5.5)))
        for x in range(cx - w, cx + w + 1):
            if 0 <= x < N:
                out[y, x] = AZUL if x < cx + w * .55 else AZUL2
                if x < cx - w + 3: out[y, x] = (70, 120, 245)
                allm[y, x] = True
    for x in range(x0n - 2, x1n + 3):                     # gola
        yy = ys + int(2.5 * (1 - ((x - cx) / (nw / 2 + 2)) ** 2))
        for y in (yy, yy + 1):
            if 0 <= y < N: out[y, x] = AZUL2
    for x in range(x0n + 1, x1n):                          # pele dentro da gola
        yy = ys + int(2.5 * (1 - ((x - cx) / (nw / 2 + 2)) ** 2))
        for y in range(ys, yy):
            out[y, x] = tom(.9)
    out[ms] = q[ms]; allm |= ms
    sh = np.pad(allm, 1)
    bd = (~allm) & (sh[:-2, 1:-1] | sh[2:, 1:-1] | sh[1:-1, :-2] | sh[1:-1, 2:])
    out[bd] = OUT
    return out, dict(fs=fs, yq=yq, pele=[int(v) for v in pele * .9])


def boca(img, info, est, sorri=False):
    """abre a boca da foto: o queixo (tudo abaixo da linha dos labios) desce k px"""
    if est == 'c' and not sorri: return img.copy()
    a = img.copy(); fs = info['fs']
    l, r = fs[61], fs[291]; my = int(round((fs[13][1] + fs[14][1]) / 2))
    x0, x1 = int(round(l[0])), int(round(r[0]))
    k = {'c': 0, 'm': 2, 'o': 4}[est]
    if k:
        larg = int(np.ptp(fs[R6.OVAL][:, 0]) / 2) + 3; cx = int(round(fs[152][0]))
        xa, xb = max(0, cx - larg), min(N, cx + larg + 1)
        yq = info['yq']
        a[my + k:yq + k + 1, xa:xb] = img[my:yq + 1, xa:xb]
        for j in range(k): a[my + j, xa:xb] = img[my - 1, xa:xb]
        # interior da boca: elipse escura, dentes em cima
        cxm = (x0 + x1) / 2; rx = (x1 - x0) / 2 - 1; ry = (k + 1) / 2
        for y in range(my - 1, my + k + 1):
            for x in range(x0 + 1, x1):
                if ((x - cxm) / rx) ** 2 + ((y - (my + k / 2 - .5)) / max(ry, .8)) ** 2 <= 1:
                    a[y, x] = (48, 18, 22)
        if k >= 4:
            for x in range(int(cxm - rx * .6), int(cxm + rx * .6) + 1): a[my, x] = (226, 220, 210)
    if sorri:
        cor = img[my, int(round((x0 + x1) / 2))]
        for x, dx in ((x0, -1), (x1, 1)):
            a[my - 1, x + dx] = (np.array(cor) * .7).astype(np.uint8); a[my - 2, x + 2 * dx] = (np.array(cor) * .7).astype(np.uint8)
    return a


def piscar(img, info):
    """fecha os olhos com a pele da palpebra da propria foto"""
    a = img.copy(); fs = info['fs']
    for ext, inn, cima, baixo in ((33, 133, 159, 145), (263, 362, 386, 374)):
        x0, x1 = sorted((int(round(fs[ext][0])), int(round(fs[inn][0]))))
        yc, yb = int(round(fs[cima][1])) - 1, int(round(fs[baixo][1])) + 1
        for x in range(x0 - 1, x1 + 2):
            src = img[max(0, yc - 2), x]
            for y in range(yc, yb): a[y, x] = src
            a[yb - 1, x] = (np.array(src) * .45).astype(np.uint8)
    return a


EXPR = {'wave': dict(sorri=True), 'laugh': dict(sorri=True)}


def folhas(nome):
    b, info = base(nome)
    hd = Image.new('RGBA', (104 * len(QUADROS), 104), (0, 0, 0, 0))
    lo = Image.new('RGBA', (52 * len(QUADROS), 52), (0, 0, 0, 0))
    for i, nm in enumerate(QUADROS):
        pp = nm.split('_')
        bo = pp[1] if len(pp) > 1 and pp[1] in ('c', 'm', 'o') else 'c'
        if nm.startswith('laugh'): bo = 'o'
        if nm.startswith('wave'): bo = 'm' if nm.endswith('a') else 'o'
        im = boca(b, info, bo, EXPR.get(pp[0], {}).get('sorri', False))
        if nm in ('piscar', 'laugh_a', 'laugh_b'): im = piscar(im, info)
        if nm == 'laugh_b': im = np.vstack([im[2:], im[-2:]])
        fr = Image.new('RGB', (104, 104), (150, 150, 166)); fr.paste(Image.fromarray(im), (2, 2))
        hd.paste(fr, (i * 104, 0))
        lo.paste(fr.resize((52, 52), Image.LANCZOS).quantize(64, dither=Image.NONE).convert('RGB'), (i * 52, 0))
    return hd, lo, info['pele']


if __name__ == '__main__':
    out = sys.argv[1]
    for n in sys.argv[2:]:
        os.makedirs(f'{out}/{n}', exist_ok=True)
        hd, lo, pele = folhas(n); hd.save(f'{out}/{n}/rosto_hd.png'); lo.save(f'{out}/{n}/rosto.png')
        import json
        try: P = json.load(open('pele.json'))
        except Exception: P = {}
        P[n] = pele; json.dump(P, open('pele.json', 'w'), indent=1); print('ok', n, flush=True)

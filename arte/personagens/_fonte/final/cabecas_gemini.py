"""Cabecas 14x15 dos bonecos refeitas a partir dos retratos do Gemini (rosto_gemini.png).
Frente vem do quadro 0, lado (olhando para a direita) do tres quartos que olha para a direita,
costas sai da silhueta da frente. Tracos (olhos, sobrancelha, nariz, boca) ficam em posicoes fixas
tiradas dos pontos do rosto, para as expressoes do final2.cabeca continuarem funcionando.
Grava elenco_gemini.json (frente, costas, lado, pal, boca, olhos) que o elenco.py carrega quando ELENCO=gemini."""
import sys, json, cv2, numpy as np
from PIL import Image
import mediapipe as mp
from mediapipe.tasks.python import vision, BaseOptions

import os
FINAL = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'final', '')  # arte/personagens/final/
OW, OH = 144, 192
LM = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
    base_options=BaseOptions(model_asset_path='face_landmarker.task', delegate=BaseOptions.Delegate.CPU), num_faces=1))
GW = 14


def quadro(nome, q):
    a = np.asarray(Image.open(FINAL + nome + '/rosto_gemini.png').convert('RGB'))
    return np.ascontiguousarray(a[:, q * OW:(q + 1) * OW])


def pontos(im):
    big = cv2.resize(im, None, fx=3, fy=3, interpolation=cv2.INTER_CUBIC)
    r = LM.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(big)))
    if not r.face_landmarks: return None
    return np.array([(p.x * im.shape[1], p.y * im.shape[0]) for p in r.face_landmarks[0]])


def fundo_mask(im):
    ref = np.median(np.vstack([im[:6, :6].reshape(-1, 3), im[:6, -6:].reshape(-1, 3)]), 0)
    d = np.abs(im.astype(int) - ref).sum(2)
    m = (d < 40).astype(np.uint8)
    # so o fundo ligado a borda de cima/lados
    n, lab = cv2.connectedComponents(m)
    bord = set(lab[0]) | set(lab[:OH // 2, 0]) | set(lab[:OH // 2, -1])
    return np.isin(lab, [b for b in bord if b != 0] or [-1])


def regiao(rgb, f, bg, vista):
    """caixa da cabeca: do topo do cabelo ao queixo; largura das orelhas/cabelo na altura dos olhos"""
    ey = int(np.mean([f[468][1], f[473][1]]))
    yq = f[152][1]
    cols = np.where(~bg[ey])[0]
    # limita a cabeca: largura ate 1.45x a distancia do queixo ao meio dos olhos
    cx = f[[234, 454]].mean(0)[0] if vista == 'frente' else f[[168, 152]].mean(0)[0]
    lim = (yq - ey) * (1.7 if nome_atual[0] == 'lucas' else 1.35)
    cols = cols[(cols > cx - lim) & (cols < cx + lim)]
    x0, x1 = cols.min(), cols.max() + 1
    ys = np.where((~bg[:, int(x0):int(x1)]).any(1))[0]
    y0 = ys.min()
    return x0, y0, x1, yq + (yq - y0) * .05


def classes(rgb, f, bg, temp_pal=None):
    """cores de pele, cabelo e barba a partir do proprio retrato"""
    def amostra(ids, r=2):
        return np.vstack([rgb[int(f[i][1]) - r:int(f[i][1]) + r + 1, int(f[i][0]) - r:int(f[i][0]) + r + 1].reshape(-1, 3) for i in ids])
    pele = np.median(amostra((205, 425, 50, 280, 151)), 0)
    # cabelo: faixa acima da testa
    ys = np.where((~bg).any(1))[0]; y0 = ys.min(); ey = int(f[468][1])
    x10 = int(f[10][0]); w = int(abs(f[454][0] - f[234][0]) / 2)
    band = rgb[y0:y0 + max(3, int((ey - y0) * .3)), x10 - w:x10 + w]; bm = ~bg[y0:y0 + max(3, int((ey - y0) * .3)), x10 - w:x10 + w]
    cab = band[bm]
    cab = cab[np.abs(cab.astype(int) - pele).sum(1) > 70]
    if len(cab) > 30:
        lum = cab.sum(1); cabelo = np.median(cab[lum <= np.percentile(lum, 50)], 0)
    else:
        cabelo = None
    barba_px = amostra((152, 175, 199, 428), 2)
    barba = np.median(barba_px, 0)
    tem_barba = barba.mean() < pele.mean() * .8
    return pele, cabelo, (barba if tem_barba else None)


def paleta(pele, cabelo, barba):
    c = lambda v: tuple(int(x) for x in np.clip(v, 0, 255))
    H = cabelo if cabelo is not None else pele * .5
    B = barba if barba is not None else H
    return dict(S=c(pele), s=c(pele * .8), L=c(pele * 1.12 + 6), H=c(H * .9), h=c(H * 1.25 + 12), B=c(B * .95), b=c(B * 1.2 + 8))


OVAL = [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109]


def rotulos(rgb, f, bg, pal, usa_barba):
    """0 fundo, 1 pele, 2 cabelo, 3 barba (em alta resolucao, depois vira grade)"""
    lab = cv2.cvtColor(rgb, cv2.COLOR_RGB2LAB).astype(float)
    P = lambda c: cv2.cvtColor(np.uint8([[c]]), cv2.COLOR_RGB2LAB)[0, 0].astype(float)
    dp = np.linalg.norm(lab - P(pal['S']), axis=2)
    dh = np.linalg.norm(lab - P(pal['H']), axis=2)
    escuro = lab[..., 0] < P(pal['S'])[0] * .62
    L = np.ones(bg.shape, np.uint8)
    L[(dh < dp) | escuro] = 2
    rosto = np.zeros(bg.shape, np.uint8)
    cv2.fillConvexPoly(rosto, cv2.convexHull(f[OVAL].astype(np.int32)), 1)
    # dentro do rosto, acima do nariz: pele (olhos e sobrancelhas sao desenhados depois)
    ny = f[2][1]; testa = f[10][1] + (f[168][1] - f[10][1]) * .35
    yy = np.arange(bg.shape[0])[:, None] * np.ones(bg.shape[1])[None]
    L[(rosto > 0) & (yy > testa) & (yy < ny + 1)] = 1
    # abaixo do nariz dentro do rosto: escuro = barba
    bz = (rosto > 0) & (yy >= ny + 1) & (L == 2)
    L[bz] = 3 if usa_barba else 1
    # boca: pele
    m = np.zeros(bg.shape, np.uint8); cv2.fillConvexPoly(m, cv2.convexHull(f[[61, 291, 0, 17]].astype(np.int32)), 1)
    L[(m > 0) & (L == 3)] = 3
    ey = (f[468][1] + f[473][1]) / 2
    if nome_atual[0] != 'lucas':
        L[(rosto == 0) & (yy > ey) & (L == 2)] = 1        # orelhas/pescoco, nao cabelo comprido
    my = (f[13][1] + f[14][1]) / 2
    L[(rosto == 0) & (yy > my) & ((L != 2) | (nome_atual[0] == 'lucas'))] = 0   # abaixo da boca so o queixo (sem pescoco nem cachos pendurados)
    L[bg] = 0
    L = cv2.medianBlur(L, 3)
    return L


def grade_de(rgb, f, bg, pal, usa_barba, vista):
    x0, y0, x1, yq = regiao(rgb, f, bg, vista)
    L = rotulos(rgb, f, bg, pal, usa_barba)
    hh = (yq - y0) / 12.0; ww = (x1 - x0) / (GW - 2)
    lab = np.zeros((15, GW), np.uint8)
    for gy in range(13):
        for gx in range(1, GW - 1):
            ya, yb = int(y0 + gy * hh), max(int(y0 + gy * hh) + 1, int(y0 + (gy + 1) * hh))
            xa, xb = int(x0 + (gx - 1) * ww), max(int(x0 + (gx - 1) * ww) + 1, int(x0 + gx * ww))
            b = L[ya:yb, xa:xb].reshape(-1)
            cnt = np.bincount(b, minlength=4)
            if cnt[0] > b.size * .5: continue
            cnt[0] = 0; lab[gy, gx] = 3 if cnt[3] > b.size * .28 else int(np.argmax(cnt))
    rows = [['.'] * GW for _ in range(15)]
    for gy in range(15):
        xs = [x for x in range(GW) if lab[gy, x]]
        for gx in range(GW):
            v = lab[gy, gx]
            if not v: continue
            if v == 1:
                ch = 'S'
                if xs and (gx == xs[0] or gx == xs[-1]): ch = 's'
                if gy > 0 and lab[gy - 1, gx] == 2: ch = 's'          # sombra embaixo do cabelo
                if vista == 'frente' and xs and gx == xs[0] + 2 and 3 <= gy <= 8 and lab[gy, gx - 1] == 1: ch = 'L'
            elif v == 2:
                ch = 'h' if (gy == 1 and gx % 3 == 1) or (gy == 2 and gx % 4 == 3) else 'H'
            else:
                ch = 'B' if (gy + gx) % 4 else 'b'
            rows[gy][gx] = ch
    for gy in range(15):
        for gx in range(GW):
            if not lab[gy, gx] and any(0 <= gy + dy < 15 and 0 <= gx + dx < GW and lab[gy + dy, gx + dx]
                                       for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))):
                rows[gy][gx] = 'K'
    G = lambda p: (int(np.clip(1 + (p[0] - x0) / ww, 1, GW - 2)), int(np.clip((p[1] - y0) / hh, 0, 12)))
    return rows, G


def frente(nome, rgb, f, bg, pal, usa_barba):
    rows, G = grade_de(rgb, f, bg, pal, usa_barba, 'frente')
    el, oy = G(f[468]); er, _ = G(f[473])
    if er - el < 3: el, er = 4, 9
    # sobrancelhas
    for x in (el - 1, el, er, er + 1):
        if rows[oy - 1][x] not in 'K.': rows[oy - 1][x] = 'H'
    for x in (el, el + 1, er - 1, er):
        pass
    # olhos: E (iris) por dentro, W (branco) por fora
    for x in range(el - 1, er + 2):
        if rows[oy][x] not in 'K.': rows[oy][x] = 'S' if rows[oy][x] in 'Hh' else rows[oy][x]
    rows[oy][el - 1], rows[oy][el] = 'W', 'E'
    rows[oy][er], rows[oy][er + 1] = 'E', 'W'
    # nariz
    nx, ny = G(f[4])
    if rows[ny][nx] not in 'K.': rows[ny][nx] = 's'
    # boca
    _, my = G((f[13] + f[14]) / 2); my = max(my, ny + 1)
    cx = (el + er) / 2
    x0m, x1m = int(round(cx - 1.5)), int(round(cx + 1.5))
    for x in range(x0m, x1m + 1):
        rows[my][x] = 'M' if x0m < x < x1m else 'm'
    return rows, dict(boca=(my, x0m, x1m), olhos=(oy,), alt=1.0)


def lado(nome, rgb, f, bg, pal, usa_barba):
    rows, G = grade_de(rgb, f, bg, pal, usa_barba, 'lado')
    # olho da frente (mais a direita)
    e = f[468] if f[468][0] > f[473][0] else f[473]
    ex, oy = G(e)
    xs_ = [x for x in range(GW) if rows[oy][x] not in 'K.']
    ex = min(ex, xs_[-1] - 2) if xs_ else min(ex, GW - 3)
    for x in range(GW):
        if rows[oy][x] in 'EW': rows[oy][x] = 'S'
    rows[oy][ex], rows[oy][ex + 1] = 'E', 'W'
    if rows[oy - 1][ex] not in 'K.': rows[oy - 1][ex] = 'H'
    if rows[oy - 1][ex + 1] not in 'K.': rows[oy - 1][ex + 1] = 'H'
    _, my = G((f[13] + f[14]) / 2)
    xs = [x for x in range(GW) if rows[my][x] not in 'K.']
    if xs:
        xf = xs[-1]
        rows[my][xf] = 'M'
        if xf - 1 >= 0 and rows[my][xf - 1] not in 'K.': rows[my][xf - 1] = 'm'
    # orelha: um s no meio de tras da cabeca na altura dos olhos
    xs = [x for x in range(GW) if rows[oy + 1][x] not in 'K.']
    if xs:
        xo = xs[0] + 2
        if rows[oy + 1][xo] in 'Hh': rows[oy + 1][xo] = 'S'
    return rows


def costas(fr, meta, careca):
    oy = meta['olhos'][0]; my = meta['boca'][0]
    rows = [r[:] for r in fr]
    for y in range(15):
        xs = [x for x in range(GW) if rows[y][x] not in 'K.']
        for i, x in enumerate(xs):
            borda = i < 2 or i >= len(xs) - 2
            if y < my - 1:
                if careca:
                    v = 'L' if y < oy - 2 and 3 < x < 10 else 'S'
                    if y >= oy - 1 and borda: v = 'H'
                else:
                    v = 'h' if (y < 3 and x % 3 == 1) else 'H'
                    if y in (oy, oy + 1) and i == 0 or y in (oy, oy + 1) and i == len(xs) - 1: v = 'S'  # orelhas
            else:
                v = 's' if borda else 'S'
            rows[y][x] = v
    return rows


nome_atual = ['']


def faz(nome):
    nome_atual[0] = nome
    q0 = quadro(nome, 0); f0 = pontos(q0); bg0 = fundo_mask(q0)
    pele, cabelo, barba = classes(q0, f0, bg0)
    pal = paleta(pele, cabelo, barba)
    fr, meta = frente(nome, q0, f0, bg0, pal, barba is not None)
    careca = sum(fr[y][x] in 'SsL' for y in (1, 2) for x in range(GW)) > sum(fr[y][x] in 'Hh' for y in (1, 2) for x in range(GW))
    # tres quartos que olha para a direita
    melhor = None
    for q in (8, 7):
        im = quadro(nome, q); f = pontos(im)
        if f is None: continue
        meio = f[[234, 454]].mean(0)[0]
        if f[4][0] > meio + 2: melhor = (im, f); break
    if melhor is None:
        im = quadro(nome, 7)[:, ::-1].copy(); melhor = (im, pontos(im))
    im, f = melhor
    ld = lado(nome, im, f, fundo_mask(im), pal, barba is not None)
    ct = costas(fr, meta, careca)
    j = lambda rr: [''.join(r) for r in rr]
    return dict(pal=pal, frente=j(fr), costas=j(ct), lado=j(ld), **meta)


if __name__ == '__main__':
    out = {}
    for n in sys.argv[1:]:
        out[n] = faz(n); print(n); print('\n'.join(a + '  ' + b + '  ' + c for a, b, c in zip(out[n]['frente'], out[n]['costas'], out[n]['lado'])), flush=True)
    try: old = json.load(open('elenco_gemini.json'))
    except Exception: old = {}
    old.update(out); json.dump(old, open('elenco_gemini.json', 'w'), indent=1)

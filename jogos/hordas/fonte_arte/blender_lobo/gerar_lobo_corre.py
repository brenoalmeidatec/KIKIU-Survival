"""Folha da corrida do Lobo Espiritual (lobo_espirito) a partir da referência do Breno.

A referência (referencia_run_breno.png, 16 poses 4x4, lobo azul) é a fonte da arte. O script:
  1. recorta as 16 células, apaga o número do canto, o fundo e a grade do chão;
  2. alinha: focinho na mesma coluna e pata mais baixa na mesma linha (o corpo sobe e desce no galope);
  3. troca o azul por branco (3 tons), reduz 4:1 em pixel art, tira pixels soltos e o granulado (maioria 3x3);
  4. reordena as poses no ciclo de menor salto entre quadros (a referência não está em ordem de galope);
  5. desenha olho, trufa, linha da boca, rastro de espíritos e contorno de 1 px;
  6. grava a folha do jogo (16 quadros em linha) em projeto/assets/v2/armas/lobo_espiritual_corre.png.

Uso (Blender 5.2, em segundo plano):
    blender -b -P gerar_lobo_corre.py [-- <pasta_dos_quadros_soltos>]
"""
import math
import os
import sys

import bpy
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(AQUI, "referencia_run_breno.png")
FOLHA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "v2", "armas", "lobo_espiritual_corre.png"))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SOLTOS = ARGS[0] if ARGS else ""

F = 4                     # 4 px da referência = 1 px do jogo (lobo um pouco maior que o herói)
LIM0, LIM1 = 0.13, 0.20   # luminância: abaixo de LIM0 é fundo, acima de LIM1 é lobo
PAD = 60
TONS = np.array([0.66, 0.84, 1.0])
CONT = np.array([0x1e, 0x22, 0x2c]) / 255.0
NARIZ = np.array([0x26, 0x2a, 0x34]) / 255.0
ARO = np.array([0x3a, 0x40, 0x4e]) / 255.0
OLHO_B = np.array([0xd8, 0xfa, 0xff]) / 255.0
OLHO_C = np.array([0x7c, 0xe2, 0xff]) / 255.0
LABIO = np.array([0x6c, 0x72, 0x80]) / 255.0
SOMB = np.array([0.62, 0.64, 0.66])
ALMA = [np.array(c) / 255.0 for c in ((0xe6, 0xfa, 0xff), (0xa8, 0xdc, 0xf0), (0x74, 0xa8, 0xc8))]
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def ler(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1].copy()
    bpy.data.images.remove(img)
    return a


def salvar(a, path):
    im = bpy.data.images.new("tmp_lobo", width=a.shape[1], height=a.shape[0], alpha=True)
    im.pixels.foreach_set(np.ascontiguousarray(a[::-1]).ravel())
    im.filepath_raw = path
    im.file_format = 'PNG'
    im.save()
    bpy.data.images.remove(im)


def borrar(a, n):
    for _ in range(n):
        p = np.pad(a, 1, mode='edge')
        a = (p[:-2, :-2] + p[:-2, 1:-1] + p[:-2, 2:] + p[1:-1, :-2] + p[1:-1, 1:-1] + p[1:-1, 2:]
             + p[2:, :-2] + p[2:, 1:-1] + p[2:, 2:]) / 9.0
    return a


def celulas(L):
    h, w = L.shape
    cw, ch = w / 4.0, h / 4.0
    cels = []
    for r in range(4):
        for c in range(4):
            Lc = L[int(round(r * ch)):int(round((r + 1) * ch)), int(round(c * cw)):int(round((c + 1) * cw))].copy()
            Lc[0:95, 0:115] = 0.0          # número do quadro no canto
            cels.append(Lc)
    hm = min(x.shape[0] for x in cels)
    wm = min(x.shape[1] for x in cels)
    return [x[:hm, :wm] for x in cels]


def alinhar(cels):
    hm, wm = cels[0].shape
    marcas = []
    for Lc in cels:
        ys, xs = np.where(Lc > LIM1)
        marcas.append((xs.max(), ys.max()))
    ref_x = int(np.median([m[0] for m in marcas]))
    ref_y = int(np.median([m[1] for m in marcas]))
    out = []
    for Lc, (sx, by) in zip(cels, marcas):
        big = np.zeros((hm + 2 * PAD, wm + 2 * PAD), np.float32)
        dx, dy = ref_x - sx, ref_y - by
        big[PAD + dy:PAD + dy + hm, PAD + dx:PAD + dx + wm] = Lc
        out.append(big)
    return out


def moda3(idx, m):
    out = idx.copy()
    H, W = idx.shape
    for y in range(H):
        for x in range(W):
            if not m[y, x]:
                continue
            vals = [idx[yy, xx] for yy in range(max(0, y - 1), min(H, y + 2))
                    for xx in range(max(0, x - 1), min(W, x + 2)) if m[yy, xx]]
            cont = np.bincount(vals, minlength=len(TONS))
            if cont[idx[y, x]] <= 2:
                out[y, x] = int(cont.argmax())
    return out


def reduzir(Lc):
    a = np.clip((borrar(Lc, 1) - LIM0) / (LIM1 - LIM0), 0, 1)
    v = np.clip((borrar(Lc, 3) - LIM0) / (0.85 - LIM0), 0, 1) ** 0.75
    hh, ww = Lc.shape[0] // F, Lc.shape[1] // F
    sa = a.reshape(hh, F, ww, F).sum(axis=(1, 3))
    sv = (v * a).reshape(hh, F, ww, F).sum(axis=(1, 3))
    vv = 0.5 + 0.5 * sv / np.maximum(sa, 1e-6)
    m = sa / (F * F) >= 0.5
    pad = np.pad(m, 1)
    m &= (pad[:-2, 1:-1].astype(int) + pad[2:, 1:-1] + pad[1:-1, :-2] + pad[1:-1, 2:]) > 0
    return moda3(np.abs(vv[:, :, None] - TONS[None, None, :]).argmin(axis=2), m), m


def ordem_suave(mascaras):
    n = len(mascaras)
    hh, ww = mascaras[0].shape
    desc = [m[hh // 3:, ww // 3:].astype(np.float32) for m in mascaras]
    D = np.array([[np.abs(desc[i] - desc[j]).sum() for j in range(n)] for i in range(n)])

    def custo(o):
        return sum(D[o[i], o[(i + 1) % n]] for i in range(n))
    melhor = None
    for s in range(n):
        o = [s]
        resto = set(range(n)) - {s}
        while resto:
            j = min(resto, key=lambda k: D[o[-1], k])
            o.append(j)
            resto.remove(j)
        mudou = True
        while mudou:
            mudou = False
            for i in range(1, n - 1):
                for j in range(i + 1, n):
                    o2 = o[:i] + o[i:j + 1][::-1] + o[j + 1:]
                    if custo(o2) < custo(o) - 1e-6:
                        o, mudou = o2, True
        if melhor is None or custo(o) < custo(melhor):
            melhor = o
    i0 = melhor.index(0)
    return melhor[i0:] + melhor[:i0]


def compor(idx, m, t):
    hh, ww = m.shape
    out = np.zeros((hh, ww, 4), np.float32)
    tv = TONS[idx]
    out[:, :, 0], out[:, :, 1], out[:, :, 2], out[:, :, 3] = tv * 0.95, tv * 0.97, tv, m
    out[~m] = 0
    ys, xs = np.where(m)
    sup = ys < hh * 0.6
    tx = xs[sup].max()
    ty = int(round(ys[sup][xs[sup] >= tx - 1].mean()))

    def px(x, y, cor):
        if 0 <= y < hh and 0 <= x < ww and m[y, x]:
            out[y, x, :3] = cor
            out[y, x, 3] = 1.0
    # trufa na ponta do focinho
    px(tx, ty - 1, NARIZ); px(tx, ty, NARIZ); px(tx - 1, ty - 1, NARIZ)
    # lábio: de baixo da trufa até a comissura, embaixo da frente do olho
    for d, dy in ((1, 1), (2, 1), (3, 1), (4, 2), (5, 2), (6, 2)):
        x, y = tx - d, ty + dy
        if 0 <= y + 1 < hh and m[y, x] and m[y + 1, x]:
            px(x, y, LABIO)
    # olho amendoado no "stop", canto de trás mais alto, com sombra da testa
    px(tx - 7, ty - 5, SOMB); px(tx - 8, ty - 5, SOMB)
    px(tx - 9, ty - 4, ARO); px(tx - 8, ty - 4, OLHO_B); px(tx - 7, ty - 4, OLHO_C); px(tx - 6, ty - 3, ARO)
    # rastro: espíritos soltando da chama da cauda e fiapos no chão, ficando para trás
    esq = xs.min()
    perto_esq = xs <= esq + 6
    meio_y = int(np.median(ys[perto_esq])) if perto_esq.any() else hh // 3
    chao = ys.max()
    pts = []
    for i in range(9):
        a = (t - i / 9.0) % 1.0
        pts.append((esq + 4 - 16 * a + 1.2 * math.sin(a * 7 + i), meio_y + (i % 5 - 2) * 1.6 - 5 * a, a))
    for j in range(6):
        a = (t - (j + 0.5) / 6.0) % 1.0
        pts.append((esq + 18 + j * 5 - 26 * a, chao - 1 - 2.5 * a, a * 1.15))
    for x, y, a in pts:
        xi, yi = int(round(x)), int(round(y))
        if a < 0.3:
            pix = [(0, 0, 0), (1, 0, 1), (0, 1, 1)]
        elif a < 0.65:
            pix = [(0, 0, 1), (1, 0, 2)]
        else:
            pix = [(0, 0, 2)] if BAYER[yi % 4, xi % 4] < (1.1 - a) * 2 else []
        for dx, dy, c in pix:
            qx, qy = xi + dx, yi + dy
            if 0 <= qx < ww and 0 <= qy < hh and not m[qy, qx]:
                out[qy, qx, :3] = ALMA[c]
                out[qy, qx, 3] = 1.0
    pad = np.pad(m, 1)
    viz = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    borda = viz & ~m & (out[:, :, 3] == 0)
    out[borda, :3] = CONT
    out[borda, 3] = 1.0
    return out


def main():
    arr = ler(REF)
    L = 0.3 * arr[:, :, 0] + 0.59 * arr[:, :, 1] + 0.11 * arr[:, :, 2]
    alinh = alinhar(celulas(L))
    uniao = np.zeros(alinh[0].shape, bool)
    for b in alinh:
        uniao |= b > LIM1
    ys, xs = np.where(uniao)
    y0, y1 = max(0, ys.min() - 3 * F), min(uniao.shape[0], ys.max() + 2 * F)
    x0, x1 = max(0, xs.min() - 14 * F), min(uniao.shape[1], xs.max() + 2 * F)   # sobra à esquerda para o rastro
    y1 = y0 + ((y1 - y0) // F) * F
    x1 = x0 + ((x1 - x0) // F) * F
    base = [reduzir(b[y0:y1, x0:x1]) for b in alinh]
    ordem = ordem_suave([m for _, m in base])
    quadros = [compor(base[k][0], base[k][1], n / len(ordem)) for n, k in enumerate(ordem)]
    folha = np.concatenate(quadros, axis=1)
    os.makedirs(os.path.dirname(FOLHA), exist_ok=True)
    salvar(folha, FOLHA)
    if SOLTOS:
        os.makedirs(SOLTOS, exist_ok=True)
        for n, q in enumerate(quadros):
            salvar(q, os.path.join(SOLTOS, f"run_{n:02d}.png"))
    h, w = quadros[0].shape[:2]
    print(f"folha {folha.shape[1]}x{folha.shape[0]}: {len(quadros)} quadros de {w}x{h}, ordem {ordem} -> {FOLHA}")


main()

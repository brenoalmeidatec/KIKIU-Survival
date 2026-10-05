"""rosto.png v6: rosto de dialogo fiel a foto.
1) pontos do rosto (mediapipe) -> alinha olhos na mesma altura/escala para todos;
2) Lucas (foto de lado) e espelhado/frontalizado pela malha do rosto;
3) olhos, sobrancelhas e boca da foto sao apagados (inpaint) e redesenhados nitidos nas posicoes medidas;
4) pele em rampa de 4 tons, cabelo/barba em poucas cores, contorno e gola Cairu padrao.
Saida: 27 quadros 52x52 na ordem QUADROS (mesmo contrato do rosto.png anterior)."""
import sys, os, cv2, numpy as np
from PIL import Image
sys.path.insert(0, '.')
from marcos import marcos
from final import QUADROS

G = 50; K = 4; GK = G * K
BG = (74, 78, 96); OUT = (22, 18, 24); AZUL = (36, 84, 200); AZUL2 = (24, 56, 150); BRANCO = (230, 232, 240)
OLHO_E, OLHO_D = (33, 133, 159, 145, 468), (263, 362, 386, 374, 473)   # canto ext, canto int, cima, baixo, iris
SOBR_E, SOBR_D = (70, 63, 105, 66, 107), (300, 293, 334, 296, 336)
OVAL = [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152, 148, 176, 149,
        150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109]
# ajustes por pessoa: escala (distancia entre olhos em px de 50), olho_y, frontal (espelhar), teto do cabelo...
AJ = {
    'nicao': dict(dist=10.5, capacete=(34, 28, 26), duro=(.62, .74), barba=((46, 34, 30), (30, 22, 20))),
    'lucas': dict(cachos=True, dist=8.8, espelho='esquerda', cab_l=.9, cab_a=.9, duro=(.66, .78)),
    'joao': dict(dist=10.5),
    'matheus': dict(dist=10.0),
    'beto': dict(dist=10.0),
    'lukako': dict(dist=10.0),
    'fabio': dict(dist=10.5),
    'breno': dict(dist=10.5, teto=1.25, luz=1.15),
}

_SYM = None
def simetria():
    """indice espelhado de cada ponto, calculado num rosto bem frontal (Joao)"""
    global _SYM
    if _SYM is None:
        _, f = marcos('joao')
        ol, od = f[468], f[473]
        ang = np.arctan2(od[1] - ol[1], od[0] - ol[0]); c, s = np.cos(-ang), np.sin(-ang)
        p = (f - f[168]) @ np.array([[c, s], [-s, c]])
        m = p.copy(); m[:, 0] *= -1
        _SYM = np.array([np.argmin(((p - q) ** 2).sum(1)) for q in m])
    return _SYM


def warp_tri(img, src, dst):
    """warp por triangulos (malha do rosto + borda fixa)"""
    h, w = img.shape[:2]
    borda = np.array([[0, 0], [w / 2, 0], [w - 1, 0], [w - 1, h / 2], [w - 1, h - 1], [w / 2, h - 1], [0, h - 1], [0, h / 2]])
    S = np.vstack([src, borda]); D = np.vstack([dst, borda])
    sub = cv2.Subdiv2D((0, 0, w, h))
    for p in D: sub.insert((float(np.clip(p[0], 0, w - 1)), float(np.clip(p[1], 0, h - 1))))
    out = img.copy()
    for tr in sub.getTriangleList():
        pts = tr.reshape(3, 2)
        idx = [int(np.argmin(((D - q) ** 2).sum(1))) for q in pts]
        a, b = S[idx].astype(np.float32), D[idx].astype(np.float32)
        r = cv2.boundingRect(b)
        if r[2] <= 0 or r[3] <= 0: continue
        M = cv2.getAffineTransform(a, b)
        warped = cv2.warpAffine(img, M, (w, h), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
        m = np.zeros((h, w), np.uint8); cv2.fillConvexPoly(m, b.astype(np.int32), 1)
        out[m > 0] = warped[m > 0]
    return out


def alinhar(nome, aj):
    img, f = marcos(nome)
    if aj.get('manchas'):
        mm = np.zeros(img.shape[:2], np.uint8)
        for (cx_, cy_, r_) in aj['manchas']: cv2.circle(mm, (cx_, cy_), r_, 255, -1)
        img = cv2.inpaint(img, mm, 9, cv2.INPAINT_TELEA)
    if aj.get('frontal'):
        sym = simetria()
        ol, od = f[468], f[473]
        mid = (ol + od) / 2; ang = np.arctan2(od[1] - ol[1], od[0] - ol[0])
        u = np.array([np.cos(ang), np.sin(ang)])           # eixo dos olhos
        # espelha cada ponto pelo eixo vertical do rosto (perpendicular aos olhos, passando pelo nariz)
        eixo = f[168] * .5 + f[4] * .5
        def esp(p):
            d = (p - eixo) @ u
            return p - 2 * np.outer(d, u)
        alvo = (f + esp(f[sym])) / 2
        alvo = f + (alvo - f) * aj['frontal']
        img = warp_tri(img, f, alvo); f = alvo
    el, ed = f[[33, 133]].mean(0), f[[263, 362]].mean(0)
    dist = aj.get('dist', 12.5) * K
    ang = np.arctan2(ed[1] - el[1], ed[0] - el[0]); esc = dist / np.hypot(*(ed - el))
    c, s = np.cos(-ang) * esc, np.sin(-ang) * esc
    alvo_mid = np.array([G / 2 * K, aj.get('olho_y', 21) * K])
    mid = (el + ed) / 2
    M = np.array([[c, -s, 0], [s, c, 0]], float)
    M[:, 2] = alvo_mid - M[:, :2] @ mid
    a = cv2.warpAffine(img, M, (GK, GK), flags=cv2.INTER_AREA, borderMode=cv2.BORDER_REPLICATE)
    fa = f @ M[:, :2].T + M[:, 2]
    if aj.get('espelho'):
        eixo = int(round((fa[168][0] + fa[4][0] + fa[152][0]) / 3))
        if aj['espelho'] == 'direita':
            lado = a[:, eixo:eixo + min(eixo, GK - eixo)]
            a[:, eixo - lado.shape[1]:eixo] = lado[:, ::-1]
            esq = fa[:, 0] < eixo; fa[esq, 0] = fa[esq, 0]  # pontos do lado espelhado: usa simetricos
            sym = simetria()
            for i in np.where(esq)[0]:
                j = sym[i]; fa[i] = (2 * eixo - fa[j][0], fa[j][1])
        else:
            lado = a[:, max(0, 2 * eixo - GK):eixo]
            a[:, eixo:eixo + lado.shape[1]] = lado[:, ::-1]
            sym = simetria()
            for i in np.where(fa[:, 0] > eixo)[0]:
                j = sym[i]; fa[i] = (2 * eixo - fa[j][0], fa[j][1])
    if aj.get('capacete'):
        # foto cortada no alto da cabeca: acha a borda da foto (acima dela a imagem so repete a ultima linha)
        # e completa o cabelo espelhando para cima o proprio cabelo da foto
        g = a.astype(int)
        dif = np.abs(np.diff(g, axis=0)).sum(2)            # (H-1, W)
        borda = np.argmax(dif > 6, axis=0)                  # primeira linha com textura em cada coluna
        H_ = a.shape[0]
        for x in range(a.shape[1]):
            e = int(borda[x])
            if e <= 0: continue
            for y in range(e):
                src = min(H_ - 1, e + (e - y) % max(1, int(aj.get('espelho_cab', 14) * K)))
                a[y, x] = a[src, x]
    if aj.get('luz'):
        a = np.clip(a.astype(float) * aj['luz'], 0, 255).astype(np.uint8)
    return a, fa


def mascara(a, f, aj):
    m = np.full(a.shape[:2], cv2.GC_BGD, np.uint8)
    hull = cv2.convexHull(f[OVAL].astype(np.int32))
    cx, cy = f[OVAL].mean(0); w = np.ptp(f[OVAL][:, 0]); h = np.ptp(f[OVAL][:, 1])
    de = np.hypot(*(f[[263, 362]].mean(0) - f[[33, 133]].mean(0))); w = min(w, 2.4 * de)
    cx = (f[168][0] + f[152][0]) / 2
    cv2.ellipse(m, (int(cx), int(cy - h * .2)), (int(w * aj.get('cab_l', .82)), int(h * aj.get('cab_a', .9))), 0, 0, 360, cv2.GC_PR_FGD, -1)
    queixo = f[152]
    cv2.rectangle(m, (int(cx - w * .28), int(queixo[1] - 10)), (int(cx + w * .28), GK - 1), cv2.GC_PR_FGD, -1)
    cv2.fillConvexPoly(m, hull, cv2.GC_FGD)
    bg, fg = np.zeros((1, 65)), np.zeros((1, 65))
    cv2.grabCut(a, m, None, bg, fg, 5, cv2.GC_INIT_WITH_MASK)
    mk = ((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)).astype(np.uint8)
    hsv = cv2.cvtColor(a, cv2.COLOR_BGR2HSV)
    fundo = ((hsv[..., 0] > 75) & (hsv[..., 0] < 150) & (hsv[..., 1] > 60) & (hsv[..., 2] > 40)) | \
            ((hsv[..., 0] < 22) & (hsv[..., 1] > 170) & (hsv[..., 2] > 170)) | \
            ((hsv[..., 0] > 35) & (hsv[..., 0] <= 75) & (hsv[..., 1] > 90) & (hsv[..., 2] > 90)) | \
            ((hsv[..., 1] < 45) & (hsv[..., 2] > 195))
    nucleo = np.zeros_like(mk); cv2.fillConvexPoly(nucleo, hull, 1)
    mk = mk & (1 - (fundo & (nucleo == 0)).astype(np.uint8))
    if 'teto' in aj:  # corta coisas acima do cabelo (luz, teto)
        ytop = int(f[10][1] - (f[152][1] - f[10][1]) * (aj['teto'] - 1))
        mk[:max(0, ytop)] = 0
    if aj.get('duro'):
        el = np.zeros_like(mk); dl, da = aj['duro']
        cv2.ellipse(el, (int(cx), int(cy - h * .12)), (int(w * dl), int(h * da)), 0, 0, 360, 1, -1); mk = mk & el
    mk = cv2.morphologyEx(mk, cv2.MORPH_OPEN, np.ones((7, 7), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(mk)
    if n > 1: mk = (lab == 1 + np.argmax(st[1:, 4])).astype(np.uint8)
    mk = cv2.morphologyEx(mk, cv2.MORPH_CLOSE, np.ones((13, 13), np.uint8))
    # orelhas/pescoco: abaixo do queixo so fica o pescoco
    yq = int(queixo[1] + 2)
    mk[yq:, :] = 0
    return mk, nucleo


def apaga_tracos(a, f):
    """apaga olhos, sobrancelhas e boca (inpaint) para redesenhar limpo"""
    m = np.zeros(a.shape[:2], np.uint8)
    for ids, pad in ((OLHO_E[:4], 6), (OLHO_D[:4], 6), (SOBR_E, 5), (SOBR_D, 5), ((61, 291, 0, 17, 13, 14), 4)):
        p = f[list(ids)]
        x0, y0 = p.min(0) - pad; x1, y1 = p.max(0) + pad
        cv2.rectangle(m, (int(x0), int(y0)), (int(x1), int(y1)), 255, -1)
    return cv2.inpaint(a, m, 7, cv2.INPAINT_TELEA)


def base(nome):
    aj = AJ.get(nome, {})
    a, f = alinhar(nome, aj)
    mk, nucleo = mascara(a, f, aj)
    limpo = apaga_tracos(a, f)
    sm = cv2.pyrMeanShiftFiltering(limpo, 6, 18)
    small = cv2.resize(sm, (G, G), interpolation=cv2.INTER_AREA)
    cru = cv2.cvtColor(cv2.resize(limpo, (G, G), interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2LAB).astype(float)
    lab = cv2.cvtColor(small, cv2.COLOR_BGR2LAB).astype(float)
    ms = cv2.resize(mk * 255, (G, G), interpolation=cv2.INTER_AREA) > 110
    fs = f / K
    # tom de pele de referencia: bochechas
    bo = [fs[i] for i in (50, 280, 205, 425, 36, 266)]
    ref = np.median(np.array([lab[int(y), int(x)] for x, y in bo]), 0)
    dc = np.hypot(lab[..., 1] - ref[1], lab[..., 2] - ref[2])
    cr = np.hypot(lab[..., 1] - 128, lab[..., 2] - 128); cref = np.hypot(ref[1] - 128, ref[2] - 128)
    pele = ms & (dc < 16) & (lab[..., 0] > ref[0] - 24) & (cr > cref * .62)
    oval = np.zeros((G, G), np.uint8)
    ctr = fs[OVAL].mean(0); pts = ctr + (fs[OVAL] - ctr) * 1.04
    cv2.fillPoly(oval, [np.round(pts).astype(np.int32)], 1)
    pele = pele & (oval > 0)
    rgb = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
    out = np.zeros((G, G, 3), np.uint8); out[:] = BG
    tons = []
    for dl, ch in ((-30, 1.12), (-15, 1.06), (0, 1.0), (14, .94)):
        c = np.array([np.clip(ref[0] + dl, 0, 255), 128 + (ref[1] - 128) * ch, 128 + (ref[2] - 128) * ch], np.uint8)
        tons.append(cv2.cvtColor(c.reshape(1, 1, 3), cv2.COLOR_LAB2RGB)[0, 0])
    Ls = lab[..., 0][pele]
    qs = np.quantile(Ls, [.15, .45, .85])
    idx = np.digitize(lab[..., 0], qs)
    for _ in range(2):
        p = np.pad(idx, 1, mode='edge')
        viz = np.stack([p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]])
        igual = (viz == viz[0]).all(0)
        idx = np.where(igual & (viz[0] != idx), viz[0], idx)
    for k in range(4): out[pele & (idx == k)] = tons[k]
    resto = ms & ~pele
    if resto.sum() > 6:
        v = cru[resto].astype(np.float32); kk = min(6, len(v))
        _, lb, cen = cv2.kmeans(v, kk, None, (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, .5), 4, cv2.KMEANS_PP_CENTERS)
        cen = cv2.cvtColor(cen.astype(np.uint8).reshape(-1, 1, 3), cv2.COLOR_LAB2RGB).reshape(-1, 3)
        out[resto] = cen[lb.ravel()]
    if AJ.get(nome, {}).get('barba'):
        # barba cheia: do meio da bochecha ate o queixo, com bigode
        c1, c2 = [np.array(c, np.uint8) for c in AJ[nome]['barba']]
        i0, i1 = OVAL.index(132), OVAL.index(361)
        baixo = [fs[i] for i in OVAL[i1:] + OVAL[:0]] if False else [fs[i] for i in OVAL[i1:i0 + 1]] if i1 < i0 else []
        poly = np.array([fs[i] for i in OVAL[OVAL.index(361):OVAL.index(132) + 1]] + [fs[205], fs[98], fs[2], fs[327], fs[425]], np.float32)
        bm = np.zeros((G, G), np.uint8); cv2.fillPoly(bm, [np.round(poly).astype(np.int32)], 1)
        bm = bm.astype(bool) & ms
        Lb = lab[..., 0]
        out[bm] = c1; out[bm & (Lb < np.median(Lb[bm]))] = c2
        pele = pele & ~bm
    if AJ.get(nome, {}).get('cachos'):
        cab_m = ms & ~(oval > 0)
        rng = np.random.default_rng(11); nz = rng.random((G, G))
        base_c = np.median(out[cab_m], 0)
        esc_c, cla_c = escurece(base_c, .62), np.clip(base_c * 1.25 + 8, 0, 255).astype(np.uint8)
        for y in range(G):
            for x in range(G):
                if cab_m[y, x]:
                    v = (np.sin(x * 1.9 + y * .7) + np.sin(y * 2.3 - x * .9)) * .25 + nz[y, x] * .5
                    out[y, x] = esc_c if v > .55 else (cla_c if v < .05 else base_c)
    # cabelo escuro de referencia (para sobrancelha) = cor mais escura do resto
    cab = out[resto][np.argmin(out[resto].sum(1))] if resto.sum() else np.array([40, 30, 26])
    # pescoco + gola + contorno
    yq = int(round(fs[152][1])) + 1
    allm = ms.copy()
    pcx = int(round(fs[152][0])); pw = max(4, int(np.ptp(fs[OVAL][:, 0]) * .26))
    for y in range(yq - 1, min(G, yq + 5)):
        for x in range(pcx - pw, pcx + pw + 1):
            if not allm[y, x] or y > yq:
                out[y, x] = tons[0] if y <= yq + 1 else tons[1]; allm[y, x] = True
    ys = yq + 4
    for y in range(ys, G):
        w = min(G // 2 + 1, int(pw + 4 + (y - ys) * 2.4))
        for x in range(pcx - w, pcx + w + 1):
            if 0 <= x < G: out[y, x] = AZUL; allm[y, x] = True
    for k in range(4):
        y = ys + k
        if y >= G: break
        for x in (pcx - pw - 1 + k, pcx + pw + 1 - k):
            if 0 <= x < G: out[y, x] = AZUL2
    for (x, y) in [(pcx - pw - 7, ys + 5), (pcx - pw - 6, ys + 5), (pcx - pw - 7, ys + 6)]:
        if 0 <= x < G and y < G: out[y, x] = BRANCO
    sh = np.pad(allm, 1)
    borda = (~allm) & (sh[:-2, 1:-1] | sh[2:, 1:-1] | sh[1:-1, :-2] | sh[1:-1, 2:])
    out[borda] = OUT
    info = dict(fs=fs, tons=tons, cab=np.array(cab), yq=yq, pele=ref)
    return out, info


def escurece(c, k): return np.clip(np.array(c, float) * k, 0, 255).astype(np.uint8)


def p(a, x, y, c):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < G and 0 <= y < G: a[y, x] = c


def tracos(img, info, boca='c', olhos='abertos', sobe=0, sorriso=False):
    a = img.copy(); fs = info['fs']; tons = info['tons']
    escuro = np.array([34, 22, 22], np.uint8); branco = np.array([232, 226, 218], np.uint8)
    sobr = escurece(info['cab'], .85)
    # olhos
    for ids in (OLHO_E, OLHO_D):
        ext, inn, cima, baixo, iris = fs[list(ids)]
        y = int(round((cima[1] + baixo[1]) / 2))
        x0, x1 = sorted((int(round(ext[0])), int(round(inn[0]))))
        if olhos == 'abertos':
            y -= 1
            for x in range(x0, x1 + 1): p(a, x, y - 1, escuro)           # palpebra de cima
            for x in range(x0 + 1, x1): p(a, x, y, branco); p(a, x, y + 1, branco)
            ix = int(round(iris[0]))
            for yy in (y, y + 1): p(a, ix, yy, escuro); p(a, ix + (1 if ix < (x0 + x1) / 2 else -1), yy, np.array([82, 56, 44], np.uint8))
            p(a, x0, y, escuro); p(a, x1, y, tons[0]); p(a, x0, y + 1, tons[0]); p(a, x1, y + 1, tons[0])
            for x in range(x0 + 1, x1): p(a, x, y + 2, tons[1])            # palpebra de baixo
        else:
            for x in range(x0, x1 + 1): p(a, x, y - 2, tons[2]); p(a, x, y - 1, tons[1]); p(a, x, y, escuro if olhos == 'fechados' else tons[1])
            if olhos == 'riso':
                for x in range(x0 + 1, x1): p(a, x, y - 1, escuro)
                p(a, x0, y, escuro); p(a, x1, y, escuro)
    # sobrancelhas
    for ids in (SOBR_E, SOBR_D):
        pts = fs[list(ids)]
        for i in range(len(pts) - 1):
            for k in np.linspace(0, 1, 4):
                q = pts[i] * (1 - k) + pts[i + 1] * k
                p(a, q[0], q[1] - sobe, sobr)
    # nariz: sombra embaixo e narinas
    nb = fs[2]; nl, nr = fs[98], fs[327]
    for x in range(int(round(nl[0])) + 1, int(round(nr[0]))): p(a, x, nb[1] + .4, tons[0])
    p(a, nl[0], nl[1], tons[0]); p(a, nr[0], nr[1], tons[0])
    # boca
    l, r = fs[61], fs[291]; my = int(round((fs[13][1] + fs[14][1]) / 2))
    x0, x1 = int(round(l[0])), int(round(r[0]))
    labio = escurece(tons[0], .78); labio[0] = min(255, int(labio[0]) + 18)
    if boca == 'c':
        for x in range(x0, x1 + 1): p(a, x, my, labio)
        for x in range(x0 + 1, x1): p(a, x, my + 1, tons[3] if not sorriso else tons[2])
        if sorriso: p(a, x0 - 1, my - 1, labio); p(a, x1 + 1, my - 1, labio)
    else:
        k = 1 if boca == 'm' else 2
        # mandibula desce k px
        lado = int(np.ptp(fs[OVAL][:, 0]) / 2) + 2; cx = int(round(fs[152][0]))
        yq = info['yq']
        a[my + k:yq + k + 1, cx - lado:cx + lado + 1] = img[my:yq + 1, cx - lado:cx + lado + 1].copy() if False else a[my:yq + 1, cx - lado:cx + lado + 1].copy()
        for j in range(k): a[my + j, cx - lado:cx + lado + 1] = a[my - 1, cx - lado:cx + lado + 1]
        for j in range(k + 1):
            enc = 1 if (j == k and k == 2) else 0
            for x in range(x0 + enc + (0 if j else 1), x1 - enc - (0 if j else 1) + 1): p(a, x, my + j, np.array([58, 18, 24], np.uint8))
        if k == 2:
            for x in range(x0 + 2, x1 - 1): p(a, x, my, branco)
        for x in range(x0 + 1, x1): p(a, x, my + k + 1, labio)
        if sorriso: p(a, x0 - 1, my - 1, labio); p(a, x1 + 1, my - 1, labio)
    return a


EXPR = {'talk2': dict(sobe=1), 'point': dict(sobe=1), 'shrug': dict(sobe=1), 'wave': dict(sorriso=True),
        'laugh': dict(sorriso=True, sobe=1)}


def rosto(nome):
    b, info = base(nome)
    sh = Image.new('RGBA', (52 * len(QUADROS), 52), (0, 0, 0, 0))
    for i, nm in enumerate(QUADROS):
        pp = nm.split('_')
        bo = pp[1] if len(pp) > 1 and pp[1] in ('c', 'm', 'o') else 'c'
        ex = EXPR.get(pp[0], {})
        ol = 'abertos'
        if nm == 'piscar': ol = 'fechados'
        if nm.startswith('laugh'): bo = 'o'; ol = 'riso'
        if nm.startswith('wave'): bo = 'm' if nm.endswith('a') else 'o'
        im = tracos(b, info, bo, ol, ex.get('sobe', 0), ex.get('sorriso', False))
        if nm == 'laugh_b': im = np.vstack([im[1:], im[-1:]])
        fr = Image.new('RGB', (52, 52), (150, 150, 166)); fr.paste(Image.fromarray(im), (1, 1))
        sh.paste(fr, (i * 52, 0))
    return sh


if __name__ == '__main__':
    out = sys.argv[1]
    for n in sys.argv[2:]:
        os.makedirs(f'{out}/{n}', exist_ok=True); rosto(n).save(f'{out}/{n}/rosto.png'); print('ok', n, flush=True)

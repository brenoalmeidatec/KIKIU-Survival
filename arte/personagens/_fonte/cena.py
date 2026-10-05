import sys, os, math, json
import numpy as np, cv2
from PIL import Image, ImageDraw
sys.path.insert(0, '.')
import retratos3 as R
from retratos3 import CAIRU
from sprites4 import CORPO, sombra, outline, OUT

CW, CH = 100, 140
HW, HH = 40, 52
FC = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
MOUTH_DX = dict(nicao=3, lucas=0, joao=0, matheus=0, beto=0, lukako=0, fabio=0, breno=0)
MOUTH_DY = dict(nicao=-.02, lucas=0, joao=0, matheus=0, beto=.01, lukako=0, fabio=0, breno=-.01)

def cabeca(name):
    hi = R.crop(name, 4)
    a = np.array(hi)
    m = R.person_mask(a, name)
    g = cv2.cvtColor(a, cv2.COLOR_RGB2GRAY)
    fs = FC.detectMultiScale(g, 1.1, 5, minSize=(100, 100))
    fx, fy, fw, fh = [int(v) for v in fs[0]]
    ny = R.NY[name] * 4
    q = np.array(R.pixelize(hi).resize(hi.size, Image.NEAREST))
    # cabeca em alta resolucao: foto + mascara, sem corpo e sem borda branca
    ys, xs = np.where(m[: ny - 8, :] > 0)
    row = m[ny - 40: ny - 12, :]
    cols = np.where(row.any(0))[0]
    cx0 = fx + fw / 2
    rgba = np.zeros((a.shape[0], a.shape[1], 4), np.uint8)
    for y in range(0, ny - 8):
        allow = (26 - 0.9 * max(0, y / 4 - (ny / 4 - 14))) * 4
        x0, x1 = int(max(0, cx0 - allow)), int(min(a.shape[1], cx0 + allow))
        seg = m[y, x0:x1] > 0
        rgba[y, x0:x1, :3] = a[y, x0:x1]
        rgba[y, x0:x1, 3] = np.where(seg, 255, 0)
    white = (a[..., 0] > 232) & (a[..., 1] > 232) & (a[..., 2] > 232)
    rgba[..., 3][white] = 0
    ys, xs = np.where(rgba[..., 3] > 0)
    bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    cab = Image.fromarray(rgba).crop((bx0, by0, bx1, by1))
    arr = np.array(cab).astype(float)
    mask = arr[..., 3] > 0
    arr[~mask, :3] = arr[mask][:, :3].mean(0)
    from PIL import ImageEnhance
    rgb = Image.fromarray(arr[..., :3].astype('uint8'))
    rgb = ImageEnhance.Contrast(rgb).enhance(1.15); rgb = ImageEnhance.Color(rgb).enhance(1.2)
    rgb = rgb.resize((HW, HH), Image.LANCZOS)
    al = Image.fromarray((mask * 255).astype('uint8')).resize((HW, HH), Image.BILINEAR).point(lambda v: 255 if v > 120 else 0)
    pal = rgb.quantize(colors=18, method=Image.MEDIANCUT, dither=Image.NONE).convert('RGBA')
    pal.putalpha(al)
    sx, sy = HW / (bx1 - bx0), HH / (by1 - by0)
    mouth = ((fx + fw * .5 - bx0) * sx + MOUTH_DX[name], (fy + fh * (.78 + MOUTH_DY[name]) - by0) * sy)
    eyes = [((fx + fw * k - bx0) * sx, (fy + fh * .40 - by0) * sy) for k in (.30, .70)]
    pa = np.array(pal)
    reg = pa[int(eyes[0][1]) + 4: int(mouth[1]) - 2, int(HW * .3): int(HW * .7), :3].reshape(-1, 3)
    skin = tuple(int(v) for v in np.median(reg, axis=0))
    return pal, mouth, eyes, skin

def desenha_boca(img, mouth, skin, estado):
    d = ImageDraw.Draw(img)
    mx, my = int(round(mouth[0])), int(round(mouth[1]))
    lab = sombra(skin, .62)
    escuro, dente, lingua = (46, 14, 18, 255), (244, 238, 228, 255), (196, 84, 96, 255)
    if estado == 'm':
        d.rectangle([mx - 4, my - 1, mx + 4, my + 1], fill=escuro)
        d.line([(mx - 4, my + 2), (mx + 4, my + 2)], fill=lab + (255,))
    elif estado == 'o':
        d.rectangle([mx - 5, my - 2, mx + 5, my + 3], fill=escuro)
        d.line([(mx - 4, my - 2), (mx + 4, my - 2)], fill=dente)
        d.line([(mx - 2, my + 3), (mx + 2, my + 3)], fill=lingua)
        d.line([(mx - 5, my + 4), (mx + 5, my + 4)], fill=lab + (255,))
    elif estado == 'r':      # risada
        d.rectangle([mx - 6, my - 2, mx + 6, my + 4], fill=escuro)
        d.line([(mx - 5, my - 2), (mx + 5, my - 2)], fill=dente)
        d.line([(mx - 5, my - 1), (mx + 5, my - 1)], fill=dente)
        d.rectangle([mx - 3, my + 2, mx + 3, my + 4], fill=lingua)
        d.point([(mx - 7, my - 3), (mx + 7, my - 3)], fill=lab + (255,))

def desenha_olhos(img, eyes, skin, estado):
    if estado == 'aberto': return
    d = ImageDraw.Draw(img)
    pele, esc = sombra(skin, .95) + (255,), (30, 18, 16, 255)
    for ex, ey in eyes:
        ex, ey = int(round(ex)), int(round(ey))
        d.rectangle([ex - 4, ey - 2, ex + 4, ey + 2], fill=pele)
        if estado == 'piscando':
            d.line([(ex - 3, ey + 1), (ex + 3, ey + 1)], fill=esc)
        else:   # apertado de rir
            d.line([(ex - 3, ey + 1), (ex, ey - 1)], fill=esc); d.line([(ex, ey - 1), (ex + 3, ey + 1)], fill=esc)

def membro(d, p0, p1, w, cor, claro):
    d.line([p0, p1], fill=cor + (255,), width=w)
    d.ellipse([p0[0] - w // 2, p0[1] - w // 2, p0[0] + w // 2, p0[1] + w // 2], fill=cor + (255,))
    d.ellipse([p1[0] - w // 2, p1[1] - w // 2, p1[0] + w // 2, p1[1] + w // 2], fill=cor + (255,))
    if w >= 6:
        d.line([(p0[0] - 1, p0[1]), (p1[0] - 1, p1[1])], fill=claro + (255,), width=max(1, w // 3))

def braco(d, ombro, lado, ua, fa, cor, skin):
    s = 1 if lado == 'R' else -1
    ul, fl = 21, 19
    e = (ombro[0] + s * ul * math.sin(math.radians(ua)), ombro[1] + ul * math.cos(math.radians(ua)))
    h = (e[0] + s * fl * math.sin(math.radians(fa)), e[1] + fl * math.cos(math.radians(fa)))
    membro(d, tuple(map(round, ombro)), tuple(map(round, e)), 11, cor['T'], cor['U'])
    membro(d, tuple(map(round, e)), tuple(map(round, h)), 8, skin, sombra(skin, 1.12))
    hx, hy = round(h[0]), round(h[1])
    d.ellipse([hx - 5, hy - 5, hx + 5, hy + 5], fill=skin + (255,))
    d.ellipse([hx - 3, hy - 4, hx, hy - 1], fill=sombra(skin, 1.12) + (255,))

POSES = {   # (braco R: ua, fa), (braco L: ua, fa), arma_na_frente
    'idle':   ((7, 4), (7, 4)),
    'talk1':  ((30, 112), (7, 4)),
    'talk2':  ((8, 22), (32, 118)),
    'point':  ((82, 84), (7, 4)),
    'shrug':  ((50, 132), (50, 132)),
    'think':  ((22, -165), (4, -100)),
    'cross':  ((6, -100), (6, -96)),
    'laugh':  ((3, -72), (3, -72)),
    'wave':   ((100, 158), (7, 4)),
    'wave2':  ((104, 176), (7, 4)),
}

def frame(name, ctx, pose, boca='c', olhos='aberto', dy=0):
    pal, mouth, eyes, skin = ctx['head']
    cor, p = CAIRU, CORPO[name]
    tw = p['tw'] * 2 + 6
    cx = CW // 2
    im = Image.new('RGBA', (CW, CH), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    P, F = p['pants'], p['shoe']
    # pernas
    for sx_ in (-1, 1):
        x0 = cx - 13 if sx_ < 0 else cx + 1
        if p['bare']:
            d.rectangle([x0, 94 + dy, x0 + 12, 108 + dy], fill=P + (255,))
            d.rectangle([x0 + 1, 109 + dy, x0 + 11, 133], fill=skin + (255,))
            d.rectangle([x0 + 8, 109 + dy, x0 + 11, 133], fill=sombra(skin, .82) + (255,))
        else:
            d.rectangle([x0, 94 + dy, x0 + 12, 133], fill=P + (255,))
            d.rectangle([x0 + 9, 94 + dy, x0 + 12, 133], fill=sombra(P, .75) + (255,))
        d.rectangle([x0 - 1, 134, x0 + 13, 139], fill=F + (255,))
        d.rectangle([x0 - 1, 138, x0 + 13, 139], fill=sombra(F, .72) + (255,))
    # tronco
    tl, tr = cx - tw // 2, cx + tw // 2
    d.rounded_rectangle([tl, 55 + dy, tr, 97 + dy], radius=6, fill=cor['T'] + (255,))
    d.rectangle([tl + 1, 58 + dy, tl + 3, 94 + dy], fill=cor['U'] + (255,))
    d.rectangle([tr - 4, 58 + dy, tr - 1, 96 + dy], fill=cor['t'] + (255,))
    d.rectangle([tl + 3, 94 + dy, tr - 3, 97 + dy], fill=cor['t'] + (255,))
    # logo
    lx, ly = cx - 8, 70 + dy
    G = {'C': ["###", "#..", "#..", "#..", "###"], 'a': [None, None, ".##", "#.#", ".##"], 'i': ["#", None, "#", "#", "#"], 'r': [None, None, "##", "#.", "#."], 'u': [None, None, "#.#", "#.#", "###"]}
    for ch in "Cairu":
        rows = G[ch]
        for yy, r_ in enumerate(rows):
            if r_:
                for xx, c in enumerate(r_):
                    if c == '#': d.point((lx + xx, ly + yy), fill=cor['W'] + (255,))
        lx += len(rows[0] or rows[2]) + 1
    # pescoco
    d.rectangle([cx - 5, 48 + dy, cx + 5, 57 + dy], fill=sombra(skin, .85) + (255,))
    d.rectangle([cx - 7, 55 + dy, cx + 7, 58 + dy], fill=cor['K'] + (255,))
    # cabeca
    cab = pal.copy()
    desenha_boca(cab, mouth, skin, {'c': 'c', 'm': 'm', 'o': 'o', 'r': 'r'}[boca])
    desenha_olhos(cab, eyes, skin, olhos)
    hdy = -2 if boca == 'r' else 0
    im.alpha_composite(cab, (cx - HW // 2, 4 + dy + hdy))
    # bracos
    (rua, rfa), (lua, lfa) = POSES[pose]
    ombroR = (tr - 2, 62 + dy); ombroL = (tl + 2, 62 + dy)
    if pose == 'cross':
        braco(d, ombroL, 'L', lua, lfa, cor, skin); braco(d, ombroR, 'R', rua, rfa, cor, skin)
    else:
        braco(d, ombroL, 'L', lua, lfa, cor, skin); braco(d, ombroR, 'R', rua, rfa, cor, skin)
    return outline(im)

# quadros: (nome, pose, boca, olhos, dy)
QUADROS = []
for pz in ('idle', 'talk1', 'talk2', 'point', 'shrug', 'think', 'cross'):
    for b in ('c', 'm', 'o'):
        QUADROS.append((f'{pz}_{b}', pz, b, 'aberto', 0))
QUADROS += [('idle_b', 'idle', 'c', 'aberto', 1), ('piscar', 'idle', 'c', 'piscando', 0),
            ('laugh_a', 'laugh', 'r', 'apertado', 0), ('laugh_b', 'laugh', 'r', 'apertado', 2),
            ('wave_a', 'wave', 'm', 'aberto', 0), ('wave_b', 'wave2', 'o', 'aberto', 0)]

def folha(name):
    ctx = dict(head=cabeca(name))
    sh = Image.new('RGBA', (CW * len(QUADROS), CH), (0, 0, 0, 0))
    for i, (_, pz, b, o, dy) in enumerate(QUADROS):
        sh.paste(frame(name, ctx, pz, b, o, dy), (i * CW, 0))
    return sh

if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    json.dump([q[0] for q in QUADROS], open(f'{out}/quadros.json', 'w'))
    nomes = sys.argv[2:] or list(R.CHARS)
    for n in nomes:
        folha(n).save(f'{out}/{n}_cena.png')
    # painel de conferencia
    pick = ['idle_c', 'talk1_o', 'talk2_m', 'point_o', 'shrug_o', 'think_c', 'cross_m', 'laugh_a', 'wave_a']
    idx = {q[0]: i for i, q in enumerate(QUADROS)}
    for n in nomes:
        sh = Image.open(f'{out}/{n}_cena.png')
        pn = Image.new('RGBA', (CW * len(pick), CH), (214, 222, 240, 255))
        for k, nm in enumerate(pick):
            pn.alpha_composite(sh.crop((idx[nm] * CW, 0, idx[nm] * CW + CW, CH)), (k * CW, 0))
        pn.resize((pn.width * 2 // 2, pn.height), Image.NEAREST).save(f'{out}/painel_{n}.png')

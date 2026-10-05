"""Retratos de dialogo gerados no Gemini -> rosto_gemini.png (12 quadros 144x192) + rosto_hd.png (27 quadros QUADROS, 104x104).
Ordem dos 12: 0 boca fechada, 1 entreaberta, 2 aberta, 3 'o', 4 sorrindo, 5 inclinado esq, 6 inclinado dir,
7 tres quartos esq, 8 tres quartos dir, 9 piscando, 10 rindo, 11 olhando para cima."""
import sys, os, cv2, numpy as np
from PIL import Image
sys.path.insert(0, '.')
from final import QUADROS

U = '/root/.claude/uploads/6ba9e05a-030f-5eb6-bf76-b30a73755dea/'
OW, OH = 144, 192
BG = np.array((74, 78, 96))
AZUL = np.array((34, 66, 178))

# arquivo, colunas (inicio de cada separador), linhas (topo, base)
FOLHAS = {
    'breno': ('8ef02e07', [0, 190, 381, 572, 763], [(65, 369), (373, 688), (695, 1020)]),
    'fabio': ('9acd936f', [0, 192, 384, 575, 767], [(63, 369), (377, 696), (704, 1016)]),
    'joao': ('fd8b840d', [0, 192, 384, 576, 768], [(52, 289), (294, 533), (538, 778), (785, 1023)]),
    'lukako': ('8083d92e', [0, 191, 383, 574, 766], [(79, 340), (347, 634), (648, 1023)]),
    'matheus': ('fc74bc61', [0, 191, 385, 578, 772], [(69, 308), (312, 551), (554, 792), (796, 1023)]),
    'lucas': ('9677186a', [0, 255, 509, 763, 1017], [(84, 373), (377, 680), (684, 1017)]),
    'nicao': ('4fd93b2e', [0, 222, 446, 669, 893], [(75, 420), (424, 795), (798, 1196)]),
    'beto': ('12e6a64e', [14, 226, 442, 659, 875], [(105, 427), (436, 777), (789, 1118)]),
}
# qual painel (linha, coluna) vira cada um dos 12 quadros; ('rot', i, graus) gira o quadro i; ('esp', painel) espelha
ORDEM_PADRAO = [(r, c) for r in range(3) for c in range(4)]
ORDEM = {
    'matheus': [(0, 0), (0, 1), (0, 2), (0, 3), (1, 0), (1, 1), (1, 2), (1, 3), (2, 0), (2, 1), (2, 2), (3, 3)],
    'lucas': [(0, 0), (0, 1), (0, 2), (0, 3), (2, 3), ('rot', 1, 9), ('rot', 1, -9), (1, 2), ('esp', (1, 3)), (2, 0), (2, 1), (2, 2)],
}


def painel(a, cols, rows, r, c, borda=10):
    if cols[0] == 14: borda = 18
    x0, x1 = cols[c] + borda, cols[c + 1] - borda + (4 if c == 3 else 0)
    y0, y1 = rows[r][0] + borda, rows[r][1] - borda
    return a[y0:y1, x0:x1]


_lm = None


def olhos(p):
    """distancia e altura dos olhos (pontos do rosto) num painel RGB"""
    global _lm
    import mediapipe as mp
    from mediapipe.tasks.python import vision, BaseOptions
    if _lm is None:
        _lm = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path='face_landmarker.task', delegate=BaseOptions.Delegate.CPU), num_faces=1))
    r = _lm.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(p)))
    f = np.array([(q.x * p.shape[1], q.y * p.shape[0]) for q in r.face_landmarks[0]])
    el, ed = f[[33, 133]].mean(0), f[[263, 362]].mean(0)
    return np.hypot(*(ed - el)), (el[1] + ed[1]) / 2, (el[0] + ed[0]) / 2


def enquadra(p, esc, ey_base, ex):
    """recorta 3:4 dentro do painel: olhos a 42% da altura; base presa ao fundo do painel"""
    h, w = p.shape[:2]
    cw = OW / esc; ch = OH / esc
    ey = h - ey_base                      # olho na mesma distancia do fundo que no quadro 1
    y0 = min(max(0, ey - ch * .42), max(0, h - ch)); x0 = (w - cw) / 2
    M = np.array([[esc, 0, -x0 * esc], [0, esc, -y0 * esc]], float)
    return cv2.warpAffine(p, M, (OW, OH), flags=cv2.INTER_AREA, borderMode=cv2.BORDER_REPLICATE)


def fundo(im, flut=False):
    """separa a pessoa do fundo (GrabCut) e troca o fundo por BG"""
    h, w = im.shape[:2]
    m = np.full((h, w), cv2.GC_PR_FGD, np.uint8)
    hsv = cv2.cvtColor(im, cv2.COLOR_RGB2HSV)
    m[:3, :] = cv2.GC_BGD; m[:int(h * .6), :3] = cv2.GC_BGD; m[:int(h * .6), -3:] = cv2.GC_BGD
    m[:int(h * .2), :int(w * .12)] = cv2.GC_BGD; m[:int(h * .2), -int(w * .12):] = cv2.GC_BGD
    m[int(h * .92):, :] = cv2.GC_FGD
    m[int(h * .3):int(h * .55), int(w * .42):int(w * .58)] = cv2.GC_FGD
    bg, fg = np.zeros((1, 65)), np.zeros((1, 65))
    cv2.grabCut(cv2.cvtColor(im, cv2.COLOR_RGB2BGR), m, None, bg, fg, 4, cv2.GC_INIT_WITH_MASK)
    bgm = (m == cv2.GC_BGD) | (m == cv2.GC_PR_BGD)
    bgm = cv2.morphologyEx(bgm.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)) > 0
    out = im.copy(); out[bgm] = BG
    return out, bgm


def limpa_logos(im, bgm):
    """apaga logo/texto no canto de baixo a direita da camisa"""
    h, w = im.shape[:2]
    hsv = cv2.cvtColor(im, cv2.COLOR_RGB2HSV)
    zona = np.zeros((h, w), bool); zona[int(h * .76):, :] = True
    camisa = zona & (hsv[..., 0] > 100) & (hsv[..., 0] < 135) & (hsv[..., 1] > 120)
    ref = np.median(im[camisa], 0) if camisa.sum() > 50 else np.array((34, 66, 178))
    dif = np.abs(im.astype(int) - ref).sum(2)
    lum = cv2.cvtColor(im, cv2.COLOR_RGB2GRAY).astype(int)
    f_ = im.astype(int); pele = (f_[..., 0] > f_[..., 1]) & (f_[..., 1] > f_[..., 2]) & (f_[..., 0] - f_[..., 2] > 25)
    m = zona & ~pele & (dif > 70) & (lum > cv2.cvtColor(ref[None, None].astype(np.uint8), cv2.COLOR_RGB2GRAY)[0, 0] - 10) & ~bgm
    m = cv2.dilate(m.astype(np.uint8) * 255, np.ones((5, 5), np.uint8))
    return cv2.inpaint(im, m, 5, cv2.INPAINT_TELEA)


def camisa_cairu(im, bgm, ey, de):
    """Beto: troca a camisa listrada/gola vermelha pela camiseta azul lisa da Cairu"""
    h, w = im.shape[:2]
    f = im.astype(int); R, G, B = f[..., 0], f[..., 1], f[..., 2]
    hsv = cv2.cvtColor(im, cv2.COLOR_RGB2HSV)
    azul = (hsv[..., 0] > 95) & (hsv[..., 0] < 140) & (hsv[..., 1] > 130)
    verm = (R > 2.05 * G + 4) & (R > 45)
    branco = (hsv[..., 1] < 60) & (hsv[..., 2] > 150)
    m = (azul | verm | branco) & ~bgm
    m[:int(ey + de * 1.2)] = False
    n, lab = cv2.connectedComponents(m.astype(np.uint8))
    base = set(np.unique(lab[-3:])) - {0}
    m = np.isin(lab, list(base))
    m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)) > 0
    m &= ~bgm
    lum = cv2.medianBlur(cv2.cvtColor(im, cv2.COLOR_RGB2GRAY), 9).astype(float)
    ref = np.median(lum[m]) if m.any() else 1
    k = np.clip(lum / ref, .6, 1.12)[..., None]
    out = im.copy()
    out[m] = np.clip(AZUL * k, 0, 255)[m].astype(np.uint8)
    return out


def girar(im, g):
    M = cv2.getRotationMatrix2D((OW / 2, OH * .9), g, 1)
    return cv2.warpAffine(im, M, (OW, OH), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)


def quadros(nome):
    arq, cols, rows = FOLHAS[nome]
    a = np.asarray(Image.open(U + arq + '-image.png').convert('RGB'))
    p0 = painel(a, cols, rows, 0, 0)
    de, ey, ex = olhos(p0)
    usados = [it for it in ORDEM.get(nome, ORDEM_PADRAO) if isinstance(it[0], int)] + [it[1] for it in ORDEM.get(nome, []) if it[0] == 'esp']
    wmin = min(painel(a, cols, rows, *rc).shape[1] for rc in usados); hmin = min(painel(a, cols, rows, *rc).shape[0] for rc in usados)
    esc = max(OW * .175 / de, OH / hmin); ey_base = p0.shape[0] - ey
    cache = {}

    def pega(rc):
        if rc not in cache:
            cache[rc] = enquadra(painel(a, cols, rows, *rc), esc, ey_base, ex)
        return cache[rc]
    fr = []
    for it in ORDEM.get(nome, ORDEM_PADRAO):
        if it[0] == 'rot': im = None; fr.append(('rot', it[1], it[2])); continue
        if it[0] == 'esp': fr.append(pega(it[1])[:, ::-1].copy()); continue
        fr.append(pega(it))
    fr = [girar(fr[x[1]], x[2]) if isinstance(x, tuple) else x for x in fr]
    eyo = OH * .42; deo = de * esc
    out = []
    for im in fr:
        bgm = np.zeros(im.shape[:2], bool)
        im = limpa_logos(im, bgm)
        if nome == 'beto': im = camisa_cairu(im, bgm, eyo, deo)
        if nome == 'nicao':  # numeros no canto de cima a esquerda
            m = np.zeros(im.shape[:2], np.uint8); m[:int(OH * .16), :int(OW * .2)] = 255
            g = cv2.cvtColor(im, cv2.COLOR_RGB2GRAY); m &= ((g > 170).astype(np.uint8) * 255)
            im = cv2.inpaint(im, cv2.dilate(m, np.ones((5, 5), np.uint8)), 5, cv2.INPAINT_TELEA)
        out.append(im)
    return out


# rosto_hd (27 quadros antigos) a partir dos 12
MAPA_HD = {'idle': 0, 'talk1': 1, 'talk2': 2, 'point': 1, 'shrug': 3, 'think': 11, 'cross': 0, 'idle_b': 0,
           'piscar': 9, 'laugh_a': 10, 'laugh_b': 10, 'wave_a': 4, 'wave_b': 4}
BOCA = {'c': 0, 'm': 1, 'o': 2}


def hd(fr):
    sh = Image.new('RGB', (104 * len(QUADROS), 104))
    for i, nm in enumerate(QUADROS):
        pp = nm.rsplit('_', 1)
        if len(pp) == 2 and pp[1] in BOCA:
            g = pp[0]; b = BOCA[pp[1]]
            q = {'idle': [0, 1, 2], 'talk1': [0, 1, 2], 'talk2': [0, 1, 2], 'point': [0, 1, 2], 'shrug': [3, 1, 2],
                 'think': [11, 11, 11], 'cross': [0, 1, 2]}[g][b]
            if g == 'think' and b: q = 11
        else:
            q = MAPA_HD[nm]
        im = fr[q][int(OH - OW) // 3:, :]          # quadrado da cabeca e ombros
        im = Image.fromarray(im[:OW]).resize((100, 100), Image.LANCZOS)
        fr_ = Image.new('RGB', (104, 104), (150, 150, 166)); fr_.paste(im, (2, 2))
        sh.paste(fr_, (i * 104, 0))
    return sh


if __name__ == '__main__':
    out = sys.argv[1]
    for n in sys.argv[2:]:
        fr = quadros(n)
        os.makedirs(f'{out}/{n}', exist_ok=True)
        sh = Image.new('RGB', (OW * 12, OH))
        for i, im in enumerate(fr): sh.paste(Image.fromarray(im), (i * OW, 0))
        sh.save(f'{out}/{n}/rosto_gemini.png')
        h = hd(fr); h.save(f'{out}/{n}/rosto_hd.png')
        lo = Image.new('RGB', (52 * len(QUADROS), 52))
        for i in range(len(QUADROS)):
            lo.paste(h.crop((i * 104, 0, i * 104 + 104, 104)).resize((52, 52), Image.LANCZOS), (i * 52, 0))
        lo.save(f'{out}/{n}/rosto.png')
        print('ok', n, flush=True)

"""Acabamento 2D do PADRÃO DO ELENCO (issue #586), aplicado em cada quadro de COR depois do render (só numpy: roda dentro do Blender e fora dele).

    contorno(px, mascara, escuro)        anel de 1 px na borda da silhueta, escurecido (contorno escuro garantido em volta do boneco)
    rim(px, mascara, direcao, cor, forca) luz de recorte: 1 px logo DENTRO do contorno, no lado de onde vem a luz (separa o boneco do chão escuro)
    aplicar(px, mascara, cfg)             os dois, na ordem certa, a partir do dicionário de parâmetros do perfil (ver gerar.py: ESTILO_2D)

`px` = H x W x 4 float 0..1 (valores do PNG, sem conversão de cor), alterado no lugar; `mascara` = H x W bool (alfa > 0,5).
A silhueta (alfa) NÃO muda: cor e normal continuam com a mesma silhueta. Sem meio-tom: cada pixel vira uma cor só.
Também serve aos frameworks com estrutura própria (nicao/, lucas/): `sys.path.insert(0, <.../hazaki>)` e `import estilo2d`.
"""
import numpy as np

# vizinhos-4 (contorno) e o passo de cada direção de luz na tela (x para a direita, y para BAIXO)
_V4 = ((0, 1), (0, -1), (1, 0), (-1, 0))


def _desloca(m, dy, dx):
    """m deslocada de (dy, dx), com False fora da borda: _desloca(m, 0, 1)[y, x] = m[y, x - 1]."""
    out = np.zeros_like(m)
    h, w = m.shape
    ys = slice(max(dy, 0), h + min(dy, 0))
    yo = slice(max(-dy, 0), h + min(-dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    xo = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = m[yo, xo]
    return out


def borda(mascara, abre_baixo=False):
    """Anel externo da silhueta: pixel opaco com algum vizinho-4 transparente (ou na borda do quadro). `abre_baixo`: a borda de baixo do quadro
    não conta como fora (retrato: os ombros cortados não ganham contorno)."""
    cheio = np.pad(mascara, 1, constant_values=False)
    if abre_baixo:
        cheio[-1, 1:-1] = mascara[-1]
    interno = mascara.copy()
    for dy, dx in _V4:
        interno &= cheio[1 + dy:1 + dy + mascara.shape[0], 1 + dx:1 + dx + mascara.shape[1]]
    return mascara & ~interno


def _lum(c):
    return 0.299 * c[..., 0] + 0.587 * c[..., 1] + 0.114 * c[..., 2]


def contorno(px, mascara, escuro=0.30, teto=0.16, abre_baixo=False):
    """Escurece o anel da silhueta: cor * `escuro` (mantém o matiz, como o contorno por casca), e nenhum pixel do anel fica com luminância acima de
    `teto`. Pixel do anel que já é escuro (a casca do Blender já desenhou ali) fica como está. Devolve a máscara do anel."""
    anel = borda(mascara, abre_baixo)
    c = px[..., :3]
    alvo = c * escuro
    lum = _lum(alvo)
    k = np.where(lum > teto, teto / np.maximum(lum, 1e-6), 1.0)[..., None]
    alvo = alvo * k
    ja_escuro = _lum(c) <= teto
    troca = anel & ~ja_escuro
    c[troca] = alvo[troca]
    return anel


def _borrar(m, n=2):
    """Caixa 3x3 repetida n vezes (borda fora = 0): suaviza a máscara para tirar a direção da borda."""
    b = m.astype(np.float32)
    for _ in range(n):
        p = np.pad(b, 1)
        b = sum(p[1 + dy:1 + dy + m.shape[0], 1 + dx:1 + dx + m.shape[1]] for dy in (-1, 0, 1) for dx in (-1, 0, 1)) / 9.0
    return b


def rim(px, mascara, anel, direcao=(1, -1), cor=(0.86, 0.93, 1.0), forca=0.55, largura=1, limiar=0.45):
    """Luz de recorte: a primeira faixa de pixels logo DENTRO do contorno (vizinho-4 do anel), só nas bordas viradas para a luz.
    `direcao` = de onde vem a luz na tela (x para a direita, y para BAIXO: (1, -1) = de cima à direita). A direção de cada borda sai do gradiente da
    máscara suavizada; a borda acende se o cosseno entre ela e a luz passa de `limiar` (0,45 ~ até 63 graus de cada lado: o topo e a direita acendem,
    a esquerda e o pé não). Mistura a cor do pixel com `cor` por `forca` (0..1). `largura` = quantas faixas para dentro."""
    lx, ly = float(direcao[0]), float(direcao[1])
    n = max(1e-6, (lx * lx + ly * ly) ** 0.5)
    lx, ly = lx / n, ly / n
    gy, gx = np.gradient(_borrar(mascara))
    nx, ny = -gx, -gy                                           # normal da borda, para fora da silhueta
    norma = np.maximum(np.hypot(nx, ny), 1e-6)
    virada = (nx * lx + ny * ly) / norma > float(limiar)
    dentro = mascara & ~anel
    faixa = np.zeros_like(mascara)
    alvo = anel.copy()
    for _ in range(max(1, int(largura))):
        viz = np.zeros_like(mascara)
        for dy, dx in _V4:
            viz |= _desloca(alvo, dy, dx)
        nova = dentro & viz & virada & ~faixa
        faixa |= nova
        alvo = nova
    c = px[..., :3]
    cor = np.asarray(cor[:3], dtype=c.dtype)
    c[faixa] = c[faixa] + (cor - c[faixa]) * float(forca)
    return faixa


def aplicar(px, mascara, cfg):
    """cfg = {"contorno": bool, "escuro": float, "teto": float, "rim": bool, "rim_dir": (x, y), "rim_cor": (r, g, b), "rim_forca": float, "rim_largura": int,
    "rim_limiar": float, "abre_baixo": bool}."""
    if not cfg:
        return
    ab = bool(cfg.get("abre_baixo"))
    anel = borda(mascara, ab)
    if cfg.get("contorno"):
        anel = contorno(px, mascara, cfg.get("escuro", 0.30), cfg.get("teto", 0.16), ab)
    if cfg.get("rim"):
        rim(px, mascara, anel, cfg.get("rim_dir", (1, -1)), cfg.get("rim_cor", (0.86, 0.93, 1.0)), cfg.get("rim_forca", 0.55), cfg.get("rim_largura", 1),
            cfg.get("rim_limiar", 0.45))

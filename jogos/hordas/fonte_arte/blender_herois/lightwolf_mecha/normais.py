"""Pós-processo do mapa de normais (numpy puro), o MESMO tratamento do pipeline do jogo em prototipos/cara_nova/gerar_cara_nova.py
(pos_normal, biselar, suavizar): desfaz a elevação da câmera, estica o XY, soma um bisel de borda, suaviza e põe o contorno como normal
"reta" (0.5, 0.5, 1). Aqui a máscara final é a do quadro de COR (contorno incluído), para cor e normal terem exatamente a mesma silhueta.
"""
import math

import numpy as np

ELEVACAO = 45.0
ESTICA = 2.0
BISEL = 0.9
BISEL_PX = 3
SUAVIZA = 1
RETA = (0.5, 0.5, 1.0)


def _contorno(cheio):
    viz = np.zeros_like(cheio)
    viz[1:, :] |= cheio[:-1, :]
    viz[:-1, :] |= cheio[1:, :]
    viz[:, 1:] |= cheio[:, :-1]
    viz[:, :-1] |= cheio[:, 1:]
    return viz & ~cheio


def _erodir(m):
    p = np.pad(m, 1, constant_values=False)
    return m & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]


def _biselar(px):
    m = px[:, :, 3] > 0.5
    if not m.any():
        return px
    h = np.zeros(m.shape, np.float32)
    cur = m.copy()
    for _ in range(BISEL_PX):
        cur = _erodir(cur)
        h += cur
    drow, dcol = np.gradient(h)
    n = px[:, :, :3] * 2.0 - 1.0
    v = np.stack([n[:, :, 0] - dcol * BISEL, n[:, :, 1] + drow * BISEL, np.maximum(n[:, :, 2], 0.2)], axis=2)
    v /= np.linalg.norm(v, axis=2, keepdims=True) + 1e-8
    px[:, :, :3] = np.where(m[:, :, None], v * 0.5 + 0.5, px[:, :, :3])
    return px


def _suavizar(px):
    m = (px[:, :, 3] > 0.5).astype(np.float32)
    n = (px[:, :, :3] * 2.0 - 1.0) * m[:, :, None]
    pn = np.pad(n, ((1, 1), (1, 1), (0, 0)))
    pm = np.pad(m, 1)
    soma = sum(pn[dy:dy + n.shape[0], dx:dx + n.shape[1]] for dy in range(3) for dx in range(3))
    cont = sum(pm[dy:dy + n.shape[0], dx:dx + n.shape[1]] for dy in range(3) for dx in range(3))
    v = soma / np.maximum(cont, 1)[:, :, None]
    v /= np.linalg.norm(v, axis=2, keepdims=True) + 1e-8
    out = px.copy()
    out[:, :, :3] = np.where(m[:, :, None] > 0, v * 0.5 + 0.5, px[:, :, :3])
    return out


def pos_normal(px, mascara_cor):
    """px: render cru da normal em espaço de câmera (H, W, 4; só o corpo, sem as cascas do contorno).
    mascara_cor: bool (H, W), alfa do quadro de cor. Devolve (H, W, 4) float 0..1 pronto para gravar."""
    out = np.zeros_like(px)
    cheio = px[:, :, 3] > 0.5
    out[:, :, :3][cheio] = px[:, :, :3][cheio]
    out[:, :, 3][cheio] = 1.0
    c, s = math.cos(math.radians(ELEVACAO)), math.sin(math.radians(ELEVACAO))
    v = out[:, :, :3] * 2.0 - 1.0
    ny = c * v[:, :, 1] + s * v[:, :, 2]
    nz = -s * v[:, :, 1] + c * v[:, :, 2]
    v = np.stack([v[:, :, 0], ny, nz], axis=2)
    v[:, :, 0] *= ESTICA
    v[:, :, 1] *= ESTICA
    v /= np.linalg.norm(v, axis=2, keepdims=True) + 1e-8
    out[:, :, :3] = np.where(cheio[:, :, None], v * 0.5 + 0.5, out[:, :, :3])
    out = _biselar(out)
    for _ in range(SUAVIZA):
        out = _suavizar(out)
    # tudo que é do contorno (e qualquer pixel da silhueta de cor que o corpo não cobriu) vira a normal reta
    reta = mascara_cor & ~cheio
    out[:, :, :3][reta] = RETA
    out[:, :, 3][reta] = 1.0
    sobra = ~mascara_cor
    out[:, :, :3][sobra] = 0.0
    out[:, :, 3][sobra] = 0.0
    return out

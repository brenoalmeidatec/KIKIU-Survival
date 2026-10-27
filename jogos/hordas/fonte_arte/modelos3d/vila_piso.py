"""Piso da Vila Amaldiçoada (id interno "cidade"): azulejo de 16 m (512 px) que repete sem emenda, com RUA de paralelepípedos e lama, CALÇADA de lajes e um LOTE
de terra batida e pedra no meio de cada azulejo. A geometria é a de antes da #429 (ruas de 6,5 m com o eixo nas bordas, bloco de 9,5 m, lote de 7 m): só a
pele mudou (asfalto -> calçamento, concreto -> lajes e terra, tinta de rua saiu, buracos -> poças de lama, marcas de pneu -> sulcos de roda).

Em vez de 256 caixas (como o piso do laboratório), o chão é um CAMPO DE ALTURAS (malha de 1024 x 1024 quadrinhos, 1,56 cm cada) montado em numpy e
renderizado pelo Blender de cima, com o sol rasante: as sombras e o normal map saem da geometria de verdade (meio-fio, juntas, pedras, rachaduras, lama),
e a cor é uma textura pintada em numpy sobre a mesma malha. Tudo é periódico: o azulejo não tem emenda.

Desenho de um azulejo (metros, x para a direita, y para cima na imagem; o jogo põe o azulejo na ordem do mapa):
  - RUAS de calçamento de 6,5 m de largura com o eixo em x = 0 e y = 0 (as bordas do azulejo): uma rua que cruza a outra no canto do azulejo;
  - BLOCO de calçada de 9,5 m (de 3,25 a 12,75) com o meio-fio de pedra levantado 14 cm e cantos arredondados; a calçada tem 1,25 m de largura;
  - LOTE de 7 m (de 4,5 a 11,5): lajes de 1,75 m, rachadas, com terra, mato e musgo. As casas ficam no lote, com a fachada voltada para o sul.
"""
import os

import bpy
import numpy as np

import pixel3d as px3

LADO = 16
N = 1024
CELULA = LADO / float(N)

# geometria (metros): o resto do pipeline (def_cidade.py) lê estas constantes em mapas_v2/medidas_cidade.py
BLOCO_0, BLOCO_1 = 3.25, 12.75
LOTE_0, LOTE_1 = 4.5, 11.5
ALT_MEIO_FIO = 0.14

# cores (sRGB 0 a 255)
C_ASFALTO = (104, 96, 85)      # calçamento (o nome é o de antes: a rua)
C_CALCADA = (116, 106, 92)
C_MEIO_FIO = (150, 142, 126)
C_LOTE = (92, 82, 66)
C_TERRA = (66, 54, 40)
C_MATO = (58, 84, 44)
C_MUSGO = (62, 84, 50)
C_JUNTA = (30, 26, 22)
C_LAMA = (52, 40, 28)
C_AMARELO = (186, 152, 46)
C_BRANCO = (178, 176, 166)


# ------------------------------------------------------------------ ferramentas de numpy (tudo periódico)
def suave(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def ruido(rng, beta, kmin=1.0, kmax=None):
    """Ruído periódico com espectro 1/f^beta (beta alto = manchas grandes), média 0 e desvio 1."""
    f_ = rng.normal(size=(N, N)) + 1j * rng.normal(size=(N, N))
    fx = np.fft.fftfreq(N) * N
    f = np.hypot(fx[None, :], fx[:, None])
    f[0, 0] = 1.0
    amp = f ** (-beta / 2.0)
    amp[f < kmin] = 0.0
    if kmax is not None:
        amp[f > kmax] = 0.0
    r = np.fft.ifft2(f_ * amp).real
    return r / r.std()


def borrar(a, sigma):
    """Borrão gaussiano periódico (por FFT), sigma em quadrinhos."""
    fx = np.fft.fftfreq(N)
    f2 = fx[None, :] ** 2 + fx[:, None] ** 2
    return np.fft.ifft2(np.fft.fft2(a) * np.exp(-2.0 * (np.pi * sigma) ** 2 * f2)).real


def pedras_calcamento(X, Y):
    """Paralelepípedos de 0,32 x 0,25 m em fiadas deslocadas (50 colunas e 64 fiadas por azulejo: periódico). Devolve a distância até a junta (m) e um
    número 0..1 por pedra (para o brilho e a altura de cada uma)."""
    cw, ch = 0.32, 0.25
    row = np.floor(Y / ch)
    u = X / cw + 0.5 * (row % 2)
    cx = np.floor(u)
    fx = u - cx
    fy = Y / ch - row
    dj = np.minimum(np.minimum(fx, 1 - fx) * cw, np.minimum(fy, 1 - fy) * ch)
    cid = (cx % 50 + 50 * (row % 64)).astype(np.int64)
    hs = ((cid * 2654435761) % 4294967296) / 4294967296.0
    return dj, hs


def sdf_caixa_redonda(X, Y, cx, cy, hx, hy, raio):
    """Distância com sinal (negativa dentro) de um retângulo de cantos arredondados."""
    qx = np.abs(X - cx) - (hx - raio)
    qy = np.abs(Y - cy) - (hy - raio)
    return np.hypot(np.maximum(qx, 0.0), np.maximum(qy, 0.0)) + np.minimum(np.maximum(qx, qy), 0.0) - raio


def carimbar(m, pts, raio):
    """Marca uma lista de pontos (em quadrinhos, x e y) numa máscara, com um disco de 'raio' quadrinhos; dá a volta nas bordas."""
    offs = [(dx, dy) for dx in range(-raio, raio + 1) for dy in range(-raio, raio + 1) if dx * dx + dy * dy <= raio * raio + 0.5]
    pts = np.asarray(pts)
    ix = np.round(pts[:, 0]).astype(int)
    iy = np.round(pts[:, 1]).astype(int)
    for dx, dy in offs:
        m[(iy + dy) % N, (ix + dx) % N] = True


def trilha(m, rng, p, ang, n_seg, raio, prof=0):
    """Rachadura: caminhada com desvio, em segmentos, que se ramifica (até 2 níveis). p em quadrinhos."""
    p = np.array(p, dtype=float)
    for _ in range(n_seg):
        passo = rng.uniform(5.0, 14.0)
        ang += rng.normal(0.0, 0.32)
        q = p + passo * np.array([np.cos(ang), np.sin(ang)])
        n = int(passo) + 1
        pts = [p + (q - p) * t / n for t in range(n + 1)]
        carimbar(m, pts, raio)
        if prof < 2 and rng.random() < 0.13:
            trilha(m, rng, q, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.1), int(n_seg * 0.5), raio, prof + 1)
        p = q


def mascara_rachaduras(rng, n, n_seg, raio, regiao):
    m = np.zeros((N, N), dtype=bool)
    ys, xs = np.nonzero(regiao[::8, ::8])
    for _ in range(n):
        j = rng.integers(len(xs))
        trilha(m, rng, (xs[j] * 8.0, ys[j] * 8.0), rng.uniform(0, 2 * np.pi), int(rng.integers(max(2, n_seg // 2), n_seg + 1)), raio)
    return m & regiao


# ------------------------------------------------------------------ o piso
def campos(semente=7):
    """Devolve (altura em metros, albedo float 0..1 (N, N, 3)). Linha 0 da imagem = norte (y = 16)."""
    rng = np.random.default_rng(semente)
    yy, xx = np.mgrid[0:N, 0:N]
    X = (xx + 0.5) * CELULA
    Y = LADO - (yy + 0.5) * CELULA

    d_bloco = sdf_caixa_redonda(X, Y, 8.0, 8.0, 4.75, 4.75, 0.8)         # < 0: dentro do meio-fio (calçada e lote)
    d_lote = sdf_caixa_redonda(X, Y, 8.0, 8.0, 3.5, 3.5, 0.12)           # < 0: dentro do lote
    asf = d_bloco >= 0.0
    dj_c, hs_c = pedras_calcamento(X, Y)
    cal = (d_bloco < 0.0) & (d_lote >= 0.0)
    lote = d_lote < 0.0

    n_baixo = ruido(rng, 2.6, 1, 14)
    n_med = ruido(rng, 1.6, 4, 60)
    n_alto = ruido(rng, 0.9, 40, 380)
    n_musgo = ruido(rng, 2.2, 1, 12)
    n_terra = ruido(rng, 2.0, 1, 16)

    # ---------------- alturas
    h = np.zeros((N, N))
    t = suave(0.0, -0.065, d_bloco)
    h += ALT_MEIO_FIO * t                                              # meio-fio com chanfro
    sulco_calha = np.exp(-((d_bloco - 0.12) / 0.14) ** 2) * (d_bloco > 0)
    h -= 0.012 * sulco_calha                                           # calha de sujeira ao lado do meio-fio
    h += asf * (0.035 * suave(0.006, 0.05, dj_c) * (0.6 + 0.8 * hs_c)) + 0.003 * n_alto * asf   # paralelepípedos abaulados
    h += 0.0035 * n_alto * (cal | lote) + 0.002 * n_med * (cal | lote)

    # lajes da calçada (1,25 m) e do lote (1,75 m): cada uma com um desnível e uma inclinação própria
    ix_c = np.clip(np.floor((X - BLOCO_0) / 1.25).astype(int), 0, 7)
    iy_c = np.clip(np.floor((Y - BLOCO_0) / 1.25).astype(int), 0, 7)
    off_c = rng.normal(0.0, 0.0045, (8, 8))
    gx_c, gy_c = rng.normal(0.0, 0.012, (8, 8)), rng.normal(0.0, 0.012, (8, 8))
    cxl = BLOCO_0 + 1.25 * (ix_c + 0.5)
    cyl = BLOCO_0 + 1.25 * (iy_c + 0.5)
    h += cal * (off_c[iy_c, ix_c] + gx_c[iy_c, ix_c] * (X - cxl) + gy_c[iy_c, ix_c] * (Y - cyl))
    ix_l = np.clip(np.floor((X - LOTE_0) / 1.75).astype(int), 0, 3)
    iy_l = np.clip(np.floor((Y - LOTE_0) / 1.75).astype(int), 0, 3)
    off_l = rng.normal(0.0, 0.006, (4, 4))
    gx_l, gy_l = rng.normal(0.0, 0.014, (4, 4)), rng.normal(0.0, 0.014, (4, 4))
    cxl2 = LOTE_0 + 1.75 * (ix_l + 0.5)
    cyl2 = LOTE_0 + 1.75 * (iy_l + 0.5)
    h += lote * (off_l[iy_l, ix_l] + gx_l[iy_l, ix_l] * (X - cxl2) + gy_l[iy_l, ix_l] * (Y - cyl2))

    # juntas: sulcos de ~3 cm
    def linhas(coord, passo, ini, larg=0.03):
        d = np.abs(((coord - ini + passo / 2.0) % passo) - passo / 2.0)
        return np.exp(-(d / larg) ** 2)
    junta_cal = np.maximum(linhas(X, 1.25, BLOCO_0), linhas(Y, 1.25, BLOCO_0)) * cal
    junta_lote = np.maximum(linhas(X, 1.75, LOTE_0), linhas(Y, 1.75, LOTE_0)) * lote
    # a borda entre calçada e lote também é uma junta
    junta_borda = np.exp(-(d_lote / 0.03) ** 2) * (d_bloco < 0)
    juntas = np.clip(np.maximum(np.maximum(junta_cal, junta_lote), junta_borda), 0.0, 1.0)
    h -= 0.014 * juntas

    # rachaduras: no asfalto (compridas e finas), na calçada e no lote (curtas, algumas largas)
    r_asf = mascara_rachaduras(rng, 26, 16, 0, asf)
    r_cal = mascara_rachaduras(rng, 22, 6, 1, cal)
    r_lote = mascara_rachaduras(rng, 22, 8, 1, lote)
    r_larga = mascara_rachaduras(rng, 6, 8, 2, lote | asf)
    rach = borrar((r_asf | r_cal | r_lote | r_larga).astype(float), 0.8) * 2.0
    rach = np.clip(rach, 0, 1)
    h -= 0.022 * rach

    # buracos no asfalto: depressões irregulares com borda esfarelada
    buracos = np.zeros((N, N))
    for k in range(4):
        for _ in range(60):
            cx, cy = rng.uniform(0, LADO, 2)
            if asf[int((LADO - cy) / CELULA) % N, int(cx / CELULA) % N] and d_bloco[int((LADO - cy) / CELULA) % N, int(cx / CELULA) % N] > 1.2:
                break
        r0 = rng.uniform(0.32, 0.65)
        f1, f2 = rng.uniform(0, 6.28, 2)
        dx = (X - cx + LADO / 2) % LADO - LADO / 2
        dy = (Y - cy + LADO / 2) % LADO - LADO / 2
        ang = np.arctan2(dy, dx)
        r_ang = r0 * (1 + 0.22 * np.sin(3 * ang + f1) + 0.14 * np.sin(5 * ang + f2))
        d = np.hypot(dx, dy) - r_ang
        buracos = np.maximum(buracos, suave(0.0, -0.14, d))
        h += 0.012 * (n_alto > 0.9) * suave(0.28, 0.0, d) * (d > 0)      # pedaços soltos em volta
    h -= 0.065 * buracos
    # remendos de asfalto novo (levemente mais altos)
    remendos = np.zeros((N, N), dtype=bool)
    for k in range(5):
        cx, cy = rng.uniform(0, LADO, 2)
        w_, h_ = rng.uniform(0.8, 2.2), rng.uniform(0.6, 1.4)
        dx = (X - cx + LADO / 2) % LADO - LADO / 2
        dy = (Y - cy + LADO / 2) % LADO - LADO / 2
        remendos |= (np.abs(dx) < w_ / 2) & (np.abs(dy) < h_ / 2) & asf & (d_bloco > 0.9)
    remendos[:] = False                                                # (sem remendo de asfalto na vila)
    h += 0.006 * remendos

    # pedriscos no asfalto e na calçada
    imp = np.zeros((N, N))
    n_p = 3200
    imp[rng.integers(0, N, n_p), rng.integers(0, N, n_p)] = rng.uniform(0.4, 1.0, n_p)
    sig = 0.9
    ped = borrar(imp, sig) * (2 * np.pi * sig * sig)
    h += 0.010 * ped * (asf | cal)

    # mato nas juntas e rachaduras (e uns tufos soltos no lote)
    perto = borrar(np.maximum(juntas * 0.6, rach), 1.4) > 0.22
    semente_mato = rng.random((N, N)) < 0.07
    mato = borrar((semente_mato & perto & (cal | lote | (asf & (d_bloco < 0.8)))).astype(float), 1.1) > 0.12
    tufos = np.zeros((N, N))
    tufos[rng.integers(0, N, 90), rng.integers(0, N, 90)] = 1.0
    tufos = borrar(tufos, 5.0) > 0.0025
    mato |= tufos & lote
    h += 0.02 * borrar(mato.astype(float), 0.9)

    # ---------------- cor
    luz_var = (1.0 + 0.09 * n_baixo + 0.07 * n_alto + 0.05 * n_med) * np.where(asf, 0.7 + 0.6 * hs_c, 1.0)
    cor = np.zeros((N, N, 3))
    for c in range(3):
        cor[..., c] = np.where(asf, C_ASFALTO[c], np.where(cal, C_CALCADA[c], C_LOTE[c])) * luz_var
    # pedriscos claros no asfalto
    for c in range(3):
        cor[..., c] += (ped > 0.35) * 22.0 * asf
    # calha suja, meio-fio claro, topo
    calha = np.clip(sulco_calha * 1.2, 0, 1)
    for c in range(3):
        cor[..., c] = cor[..., c] * (1 - 0.22 * calha)
    topo = suave(-0.06, -0.12, d_bloco) * (d_bloco < 0) * suave(-0.34, -0.2, d_bloco) * (d_bloco > -0.34)
    meio = np.clip(topo, 0, 1) * (cal | lote)
    for c in range(3):
        cor[..., c] = cor[..., c] * (1 - meio) + C_MEIO_FIO[c] * (0.9 + 0.1 * n_alto) * meio
    # lote: terra e musgo
    terra = np.clip((n_terra - 0.9) * 1.1, 0, 1) * lote
    for c in range(3):
        cor[..., c] = cor[..., c] * (1 - 0.7 * terra) + C_TERRA[c] * 0.7 * terra
    musgo = np.clip((n_musgo - 1.0) * 0.9, 0, 1) * (cal | lote) * 0.65
    for c in range(3):
        cor[..., c] = cor[..., c] * (1 - musgo) + C_MUSGO[c] * musgo
    # manchas de óleo e sujeira no asfalto
    oleo = np.clip((n_med - 1.15) * 1.5, 0, 1) * asf
    cor *= (1 - 0.28 * oleo[..., None])
    # juntas e rachaduras escuras
    escuro = np.clip(juntas * 0.55 + rach * 0.95 + asf * (1 - suave(0.004, 0.03, dj_c)) * 0.9, 0, 1)
    for c in range(3):
        cor[..., c] = cor[..., c] * (1 - escuro) + C_JUNTA[c] * escuro
    # remendos mais escuros
    cor[remendos] *= 0.78
    # buraco: escuro, com brita
    for c in range(3):
        cor[..., c] = cor[..., c] * (1 - 0.75 * buracos) + C_LAMA[c] * 0.75 * buracos * (1.0 + 0.25 * n_alto)
    # mato
    mato_f = borrar(mato.astype(float), 0.6)
    for c in range(3):
        cor[..., c] = cor[..., c] * (1 - np.clip(mato_f * 1.4, 0, 1)) + C_MATO[c] * (0.8 + 0.4 * (n_alto > 0)) * np.clip(mato_f * 1.4, 0, 1)

    # ---------------- sulcos de roda (a tinta de rua saiu)
    desgaste = (n_alto > -0.45) & (n_med > -1.25)
    dxr = np.abs(((X + LADO / 2) % LADO) - LADO / 2)          # distância ao eixo x = 0 (rua norte-sul)
    dyr = np.abs(((Y + LADO / 2) % LADO) - LADO / 2)          # distância ao eixo y = 0 (rua leste-oeste)
    na_ns = asf & (dxr < 3.25) & (dyr > 3.25)                  # trecho da rua norte-sul entre cruzamentos
    na_lo = asf & (dyr < 3.25) & (dxr > 3.25)
    sul, leste = Y < 8.0, X > 8.0           # só uma ponta de cada rua tem faixa de pedestre e linha de retenção (menos repetição)
    amarela = (((dxr > 0.05) & (dxr < 0.17)) & na_ns & ((dyr > 5.3) | (~sul & (dyr > 3.9)))) |               (((dyr > 0.05) & (dyr < 0.17)) & na_lo & ((dxr > 5.3) | (~leste & (dxr > 3.9))))
    # faixas de pedestre (0,45 m com 0,4 m de vão) e a linha de retenção
    zebra_ns = na_ns & sul & (dyr > 3.6) & (dyr < 4.9) & (dxr < 3.0) & (np.abs(((dxr + 0.425) % 0.85) - 0.425) < 0.225)
    zebra_lo = na_lo & leste & (dxr > 3.6) & (dxr < 4.9) & (dyr < 3.0) & (np.abs(((dyr + 0.425) % 0.85) - 0.425) < 0.225)
    retencao = (na_ns & sul & (dyr > 5.0) & (dyr < 5.28) & (dxr > 0.3) & (dxr < 3.0)) | (na_lo & leste & (dxr > 5.0) & (dxr < 5.28) & (dyr > 0.3) & (dyr < 3.0))
    for faixa, tom in ():   # sem tinta de rua na vila
        a = faixa & desgaste
        af = np.clip(borrar(a.astype(float), 0.7) * 1.2, 0, 1) * 0.92
        for c in range(3):
            cor[..., c] = cor[..., c] * (1 - af) + tom[c] * (0.85 + 0.15 * n_alto) * af
    # marcas de pneu: faixas escuras no meio de cada pista
    for ctr in (1.62,):
        pista = (np.abs(dxr - ctr) < 0.5) & na_ns & (dyr > 5.4)
        pista |= (np.abs(dyr - ctr) < 0.5) & na_lo & (dxr > 5.4)
        pf = borrar(pista.astype(float), 6.0) * 0.8
        cor *= (1 - 0.3 * pf[..., None])
    return h, np.clip(cor / 255.0, 0.0, 1.0)


def malha(h):
    """Malha de (N x N) quadrinhos: vértices nos cantos, alturas por quadrinho com volta periódica, UV de 0 a 1 (linha 0 da imagem = norte)."""
    nv = (N + 1) * (N + 1)
    ks = np.arange(N + 1)
    xs = ks * CELULA
    ys = LADO - ks * CELULA
    X, Y = np.meshgrid(xs, ys)
    Z = h[np.ix_(ks % N, ks % N)]
    co = np.stack([X.ravel(), Y.ravel(), Z.ravel()], axis=1).astype(np.float32)
    ii, kk = np.meshgrid(np.arange(N), np.arange(N), indexing="ij")
    v00 = (ii * (N + 1) + kk).ravel()
    v01 = v00 + 1
    v10 = v00 + (N + 1)
    v11 = v10 + 1
    lacos = np.stack([v00, v10, v11, v01], axis=1).astype(np.int32).ravel()
    nf = N * N
    uvs = np.stack([np.stack([kk / N, 1.0 - ii / N], axis=-1), np.stack([kk / N, 1.0 - (ii + 1) / N], axis=-1),
                    np.stack([(kk + 1) / N, 1.0 - (ii + 1) / N], axis=-1), np.stack([(kk + 1) / N, 1.0 - ii / N], axis=-1)], axis=2).reshape(-1, 2)
    me = bpy.data.meshes.new("piso_vila")
    me.vertices.add(nv)
    me.vertices.foreach_set("co", co.ravel())
    me.loops.add(4 * nf)
    me.loops.foreach_set("vertex_index", lacos)
    me.polygons.add(nf)
    me.polygons.foreach_set("loop_start", np.arange(nf, dtype=np.int32) * 4)
    me.polygons.foreach_set("loop_total", np.full(nf, 4, dtype=np.int32))
    me.polygons.foreach_set("use_smooth", np.ones(nf, dtype=bool))
    uv = me.uv_layers.new(name="uv")
    uv.data.foreach_set("uv", uvs.astype(np.float32).ravel())
    me.update()
    me.validate()
    return me


def piso_vila(r):
    """Constrói o piso na cena: malha de alturas + textura de cor. Também grava a cor e a altura em brutos/cidade/ para conferir a olho."""
    h, alb = campos()
    pasta = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mapas_v2", "brutos", "cidade"))
    os.makedirs(pasta, exist_ok=True)
    caminho = os.path.join(pasta, "_piso_albedo.png")
    px3.salvar_png(np.dstack([alb, np.ones((N, N))]).astype(np.float32), caminho)
    hn = (h - h.min()) / (h.max() - h.min())
    px3.salvar_png(np.dstack([hn, hn, hn, np.ones((N, N))]).astype(np.float32), os.path.join(pasta, "_piso_altura.png"))
    me = malha(h)
    ob = bpy.data.objects.new("piso_vila", me)
    bpy.context.collection.objects.link(ob)
    m = bpy.data.materials.new("piso_vila")
    m.use_nodes = True
    n, l = m.node_tree.nodes, m.node_tree.links
    p = n.get("Principled BSDF")
    p.inputs["Roughness"].default_value = 0.92
    p.inputs["Specular IOR Level"].default_value = 0.25
    tex = n.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(caminho)
    tex.image.colorspace_settings.name = "sRGB"
    tex.interpolation = "Closest"
    tex.extension = "REPEAT"
    l.new(tex.outputs["Color"], p.inputs["Base Color"])
    me.materials.append(m)

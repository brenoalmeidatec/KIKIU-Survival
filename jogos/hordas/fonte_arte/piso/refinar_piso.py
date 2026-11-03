"""Refina o piso da floresta para a grade de 1 px (um tamanho de pixel para tudo).

Entrada : fonte_arte/piso/piso_floresta_base.png (o piso.png do protótipo, saído de
          prototipos/cara_nova/piso/gerar_piso.py, 512x512, ~30 cores, manchas chapadas de 2 a 20 px).
Saída   : projeto/prototipos/piso/piso.png (o que o jogo carrega, ver v2/cenario.gd).
          O piso_normal.png NÃO muda: a altura vem das formas (pedras, raízes, musgo) e o refino só mexe no tom.

O que o script faz (só numpy e Pillow, determinístico: a semente é fixa; tudo usa wrap, então o tile continua sem emenda):
    1. Separa o "terreno" (3 tons de musgo e 4 de terra, as manchas grandes) dos detalhes com forma (capim, pedras, raízes,
       folhas, brasas); só o passo 4 mexe nas folhas, o resto desses detalhes não é tocado.
    2. Borda das manchas: onde dois tons de terreno se encostam, as duas faixas de 1 px de cada lado viram xadrez de
       1 px (a 1ª faixa, 50%; a 2ª, 25%), em vez de uma curva lisa de degraus de 2 a 5 px.
    3. Dentro das manchas: ordenado (Bayer 4x4) de baixo contraste entre tons vizinhos da mesma rampa, guiado por ruído
       periódico de baixa frequência, para o chapado de dezenas de pixels ganhar textura de 1 px sem mudar a cor média.
    4. Folhas e brasas de 2 a 3 px: os "montinhos" de folha (musgo4/erva) que formam blocos 2x2 ou maiores perdem o pixel
       de baixo-direita de cada janela 2x2 ainda cheia (varredura sequencial), ficando com 1 px de espessura.

Uso: python refinar_piso.py            (regrava o piso.png do jogo e imprime a medição antes/depois)
     python refinar_piso.py --medir    (só mede)
"""
import os
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(AQUI, "piso_floresta_base.png")
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "prototipos", "piso", "piso.png"))
sys.path.insert(0, AQUI)
from medir_piso import medir_array  # noqa: E402

SEMENTE = 4417


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


# rampas do terreno, do mais escuro ao mais claro (as mesmas cores de gerar_piso.py)
MUSGO = [rgb("#1c281d"), rgb("#243323"), rgb("#2e412c")]
TERRA = [rgb("#25211c"), rgb("#2f2920"), rgb("#3a3126"), rgb("#4a3d2f")]
FOLHAS = [rgb("#455f34"), rgb("#4a7632"), rgb("#284a28")]  # musgo4, erva, erva_base (montinhos de folha)

AMP = 0.9 # amplitude do ordenado interno, em níveis da rampa (0 desliga)
SIGMA_RUIDO = (3.0, 7.0)


def ruido_z(rng, n, sigma):
    """Ruído gaussiano periódico (filtro na frequência), média 0, desvio 1."""
    w = rng.standard_normal((n, n))
    k = np.fft.fftfreq(n)
    k2 = k[:, None] ** 2 + k[None, :] ** 2
    r = np.fft.ifft2(np.fft.fft2(w) * np.exp(-2 * (np.pi * sigma) ** 2 * k2)).real
    return (r - r.mean()) / r.std()


BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) + 0.5) / 16.0


def refinar(base):
    h, w = base.shape[:2]
    rgbi = base[..., :3]
    rng = np.random.default_rng(SEMENTE)
    yy, xx = np.mgrid[0:h, 0:w]
    xadrez = ((xx + yy) % 2) == 0

    # rampas -> campos (familia -1 = detalhe, 0 musgo, 1 terra; nivel)
    fam = np.full((h, w), -1, np.int8)
    niv = np.zeros((h, w), np.int8)
    for f, rampa in enumerate((MUSGO, TERRA)):
        for k, c in enumerate(rampa):
            m = (rgbi == np.array(c, np.uint8)).all(-1)
            fam[m] = f
            niv[m] = k
    terreno = fam >= 0

    def cor_de(f, k):
        out = np.zeros((h, w, 3), np.uint8)
        for fi, rampa in enumerate((MUSGO, TERRA)):
            for ki, c in enumerate(rampa):
                out[(f == fi) & (k == ki)] = c
        return out

    # 2) borda: xadrez de 1 px nas duas faixas de cada lado
    fam2, niv2 = fam.copy(), niv.copy()
    desvio = np.zeros((h, w), bool)  # pixels já mexidos (o ordenado interno os deixa quietos)

    def vizinho_diferente(f, k, mascara):
        """Para cada pixel, (existe, fam, nivel) de um vizinho de 4 que é terreno e tem outra cor."""
        achou = np.zeros((h, w), bool)
        vf = np.zeros((h, w), np.int8)
        vk = np.zeros((h, w), np.int8)
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            nf = np.roll(np.roll(f, dy, 0), dx, 1)
            nk = np.roll(np.roll(k, dy, 0), dx, 1)
            ok = (nf >= 0) & ((nf != f) | (nk != k)) & mascara & ~achou
            vf[ok] = nf[ok]
            vk[ok] = nk[ok]
            achou |= ok
        return achou, vf, vk

    ach1, vf1, vk1 = vizinho_diferente(fam, niv, terreno)
    ach1 &= terreno
    flip1 = ach1 & xadrez
    fam2[flip1] = vf1[flip1]
    niv2[flip1] = vk1[flip1]
    desvio |= ach1
    # 2ª faixa: vizinho (de 4) da 1ª faixa, ainda intocado, com a cor da outra margem, 1 px em cada 4
    um_em_quatro = ((xx % 2) == 0) & ((yy % 2) == 0)
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        prox = np.roll(np.roll(ach1, dy, 0), dx, 1)
        pf = np.roll(np.roll(vf1, dy, 0), dx, 1)
        pk = np.roll(np.roll(vk1, dy, 0), dx, 1)
        pf0 = np.roll(np.roll(fam, dy, 0), dx, 1)
        pk0 = np.roll(np.roll(niv, dy, 0), dx, 1)
        # o pixel é da mesma cor do vizinho de borda (mesma margem) e ainda não foi mexido: puxa a cor da outra margem
        cand = terreno & ~desvio & prox & (pf0 == fam) & (pk0 == niv) & um_em_quatro
        fam2[cand] = pf[cand]
        niv2[cand] = pk[cand]
        desvio |= cand

    # 3) ordenado interno de baixo contraste, guiado por ruído periódico
    if AMP > 0:
        n = sum(ruido_z(rng, h, s) for s in SIGMA_RUIDO) / len(SIGMA_RUIDO)
        n = n / n.std()
        s = np.clip(n, -1.6, 1.6) * AMP / 1.6
        thr = BAYER4[yy % 4, xx % 4]
        passo = np.floor(s + thr).astype(np.int8)
        novo = niv2 + passo
        for f, rampa in enumerate((MUSGO, TERRA)):
            novo = np.where(fam2 == f, np.clip(novo, 0, len(rampa) - 1), novo)
        mexe = terreno & ~desvio & (fam2 >= 0)
        niv2 = np.where(mexe, novo, niv2).astype(np.int8)

    saida = base.copy()
    mudou = terreno
    cores = cor_de(fam2, niv2)
    saida[..., :3] = np.where(mudou[..., None], cores, saida[..., :3])

    # 4) montinhos de folha: tira o que fecha blocos 2x2 (xadrez), deixando 1 px de espessura
    fol = np.zeros((h, w), bool)
    for c in FOLHAS:
        fol |= (saida[..., :3] == np.array(c, np.uint8)).all(-1)
    # varredura sequencial: cada janela 2x2 de folha ainda cheia perde o pixel de baixo-direita (vira o tom de terreno
    # mais comum em volta, incluindo diagonais); como a folha atualizada é relida, nenhum bloco 2x2 sobra
    for y in range(h):
        for x in range(w):
            y1, x1 = (y + 1) % h, (x + 1) % w
            if not (fol[y, x] and fol[y, x1] and fol[y1, x] and fol[y1, x1]):
                continue
            viz = []
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy2, xx2 = (y1 + dy) % h, (x1 + dx) % w
                    if terreno[yy2, xx2] and not fol[yy2, xx2]:
                        viz.append(tuple(saida[yy2, xx2, :3]))
            if viz:
                saida[y1, x1, :3] = max(set(viz), key=viz.count)
                fol[y1, x1] = False
    return saida


def main():
    base = np.array(Image.open(BASE).convert("RGBA"))
    novo = refinar(base)
    for nome, im in (("base", base), ("novo", novo)):
        w, h, n, f, ch, cv = medir_array(im)
        print(f"{nome}: {w}x{h} cores={n} 2x2_uniforme={f:.3f} corrida_h={ch:.2f} corrida_v={cv:.2f}")
    if "--medir" not in sys.argv:
        Image.fromarray(novo).save(SAIDA, optimize=True)
        print("gravado", SAIDA)


if __name__ == "__main__":
    main()

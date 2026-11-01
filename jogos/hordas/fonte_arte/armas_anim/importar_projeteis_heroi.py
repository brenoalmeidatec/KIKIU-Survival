"""Folhas de voo dos projéteis dos heróis (PER-2b): shuriken, kunai e flecha.

Entrada: as artes do ChatGPT desta pasta (A06_shuriken_voo.png, A07_kunai_voo.png, A08_flecha_voo.png).
Elas são RGBA de verdade: 67% a 92% dos pixels têm alfa 0, e o brilho em volta do objeto é halo de alfa
baixo (até 32 a 159). Por isso o script lê com convert('RGBA') e corta pelo canal A: alfa >= 160 vira objeto
(alfa 255), o resto vira transparente. Nunca converter para RGB antes do corte.

Redução: vizinho mais próximo, sem suavizar. Shuriken: o 1º quadro é girado em passos de 11,25 graus (8
quadros fecham 90 graus, a simetria de 4 pontas), a 14x14. Kunai (24x10) e flecha (28x8): os 4 quadros das
artes, cada objeto recortado pela caixa dele, com a escala comum (a do maior quadro) e centrado no quadro.

Saída: assets/v2/armas_anim/<nome>_heroi_voo.png e as entradas <nome>_heroi em indice_projeteis.json
(merge: as outras folhas do índice ficam como estão). Roda com:
    python importar_projeteis_heroi.py
Depois confira com:
    python gerar_projeteis.py --conferir
"""

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SAIDA = os.path.join(RAIZ, "jogos", "hordas", "projeto", "assets", "v2", "armas_anim")
LIMIAR_ALFA = 160

# nome da folha (= o `proj` do passo, mais o sufixo _heroi), arte, quadro, n, fps, âncora (ponta do projétil)
HEROIS = {
    "shuriken_heroi": dict(arte="A06_shuriken_voo.png", grade=(4, 2), quadro=(14, 14), n=8, fps=16, ancora=(7, 7)),
    "kunai_heroi": dict(arte="A07_kunai_voo.png", grade=(2, 2), quadro=(24, 10), n=4, fps=12, ancora=(20, 5)),
    "flecha_heroi": dict(arte="A08_flecha_voo.png", grade=(2, 2), quadro=(28, 8), n=4, fps=12, ancora=(24, 4)),
}


def cortar(img_rgba):
    """Corte por alfa: objeto em alfa 255, o resto em (0, 0, 0, 0)."""
    a = np.array(img_rgba)
    obj = a[..., 3] >= LIMIAR_ALFA
    out = np.zeros_like(a)
    out[obj] = a[obj]
    out[..., 3] = np.where(obj, 255, 0).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def celulas(img, grade):
    cols, linhas = grade
    w, h = img.size[0] // cols, img.size[1] // linhas
    return [img.crop((c * w, r * h, (c + 1) * w, (r + 1) * h)) for r in range(linhas) for c in range(cols)]


def caixa(img):
    """Caixa do objeto (alfa 255) dentro da célula: (x0, y0, x1, y1), com x1/y1 exclusivos."""
    x0, y0, x1, y1 = img.getchannel("A").getbbox()
    return x0, y0, x1, y1


def gerar_shuriken(cel, cfg):
    """Um quadro de referência, girado em passos de 360/(4*n) graus, em 8 quadros de 14x14."""
    w, h = cfg["quadro"]
    n = cfg["n"]
    x0, y0, x1, y1 = caixa(cel)
    obj = cel.crop((x0, y0, x1, y1))
    # o centro é o da caixa (a estrela é simétrica); o raio é a maior distância de um pixel do objeto a ele
    a = np.array(obj.getchannel("A")) > 0
    ys, xs = np.nonzero(a)
    cx, cy = (obj.size[0] - 1) / 2.0, (obj.size[1] - 1) / 2.0
    raio = float(np.max(np.hypot(xs - cx, ys - cy))) + 0.5
    lado = w * n  # a folha de trabalho é 8x a do jogo: o giro e a redução por vizinho mais próximo ficam limpos
    tela_meio = lado / 2.0
    escala = (tela_meio - 1.0) / raio  # a estrela cabe no círculo com 1 px de margem, em qualquer ângulo
    cheio = obj.resize((max(1, round(obj.size[0] * escala)), max(1, round(obj.size[1] * escala))), Image.NEAREST)
    base = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    base.alpha_composite(cheio, (round(tela_meio - (cx + 0.5) * escala), round(tela_meio - (cy + 0.5) * escala)))
    quadros = []
    for k in range(n):
        girado = base.rotate(k * 360.0 / (4 * n), resample=Image.NEAREST, center=(lado / 2.0, lado / 2.0))
        quadros.append(girado.resize((w, h), Image.NEAREST))
    return quadros


def gerar_alongado(cels, cfg):
    """Um quadro por célula, objeto recortado pela caixa, escala comum e centro no meio do quadro."""
    w, h = cfg["quadro"]
    caixas = [caixa(c) for c in cels]
    bw = max(x1 - x0 for x0, _, x1, _ in caixas)
    bh = max(y1 - y0 for _, y0, _, y1 in caixas)
    escala = min(w / bw, h / bh)
    quadros = []
    for c, (x0, y0, x1, y1) in zip(cels, caixas):
        recorte = c.crop((x0, y0, x1, y1))
        nw = max(1, round(recorte.size[0] * escala))
        nh = max(1, round(recorte.size[1] * escala))
        peca = recorte.resize((nw, nh), Image.NEAREST)
        quadro = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        quadro.alpha_composite(peca, ((w - nw) // 2, (h - nh) // 2))
        quadros.append(quadro)
    return quadros


def tira(quadros):
    w, h = quadros[0].size
    t = Image.new("RGBA", (w * len(quadros), h), (0, 0, 0, 0))
    for i, q in enumerate(quadros):
        t.alpha_composite(q, (i * w, 0))
    return t


def entrada_indice(nome, cfg):
    return {"armas": [nome], "anims": {"voo": {
        "arquivo": f"{nome}_voo.png", "quadro": list(cfg["quadro"]), "n": cfg["n"], "fps": cfg["fps"],
        "loop": True, "ancora": list(cfg["ancora"])}}}


def main():
    os.makedirs(SAIDA, exist_ok=True)
    caminho_idx = os.path.join(SAIDA, "indice_projeteis.json")
    idx = json.load(open(caminho_idx, encoding="utf-8"))
    for nome, cfg in HEROIS.items():
        origem = Image.open(os.path.join(HERE, cfg["arte"])).convert("RGBA")
        cels =[cortar(c) for c in celulas(origem, cfg["grade"])]
        cels = [c for c in cels if c.getchannel("A").getbbox()]
        if nome == "shuriken_heroi":
            quadros = gerar_shuriken(cels[0], cfg)
        else:
            quadros = gerar_alongado(cels, cfg)
        assert len(quadros) == cfg["n"], (nome, len(quadros))
        fita = tira(quadros)
        fita.save(os.path.join(SAIDA, f"{nome}_voo.png"), optimize=True)
        idx["folhas"][nome] = entrada_indice(nome, cfg)
        print(nome, fita.size, "quadros", len(quadros))
    with open(caminho_idx, "w", encoding="utf-8", newline="\n") as f:
        json.dump(idx, f, ensure_ascii=False, indent=1)
        f.write("\n")


if __name__ == "__main__":
    sys.exit(main())

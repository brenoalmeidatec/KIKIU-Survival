"""Conferidor de sprite de objeto de mapa (checklist da PIPELINE_OBJETOS.md). So precisa de Pillow e numpy.

Uso:
    python ferramentas/conferir_objeto.py albedo.png [normal.png] [--cores 40] [--max 160]
    python ferramentas/conferir_objeto.py pasta_com_pngs/        # confere todo X.png (e X_n.png / X_normal.png se existir)

Serve para sprites avulsos (os brutos do Blender); um atlas encosta na borda de proposito e falha nessa regra.
Confere: alfa binario (so 0 ou 255); no maximo N cores; contorno escuro de 1 px (>= 90% da borda); sem pixels soltos;
sprite nao encostado no limite da imagem (nao cortado); tamanho dentro do limite; normal map do mesmo tamanho, com
vetores de comprimento ~1, B >= 0 e fundo neutro onde o albedo e transparente. Sai com codigo 1 se algo falhar.
"""
import os
import sys

import numpy as np
from PIL import Image


def conferir(albedo, normal=None, cores_max=40, lado_max=160):
    erros, avisos = [], []
    a = np.array(Image.open(albedo).convert("RGBA"))
    h, w = a.shape[:2]
    alfa = a[..., 3]
    if max(h, w) > lado_max:
        avisos.append("tamanho %dx%d acima de %d px (heroi tem ~40 px; ok so para predio/piso)" % (w, h, lado_max))
    meio = int(((alfa > 0) & (alfa < 255)).sum())
    if meio:
        erros.append("alfa nao binario: %d pixels com alfa entre 1 e 254" % meio)
    solido = alfa > 127
    if not solido.any():
        return ["imagem vazia"], avisos
    cores = len({tuple(p) for p in a[solido][:, :3]})
    if cores > cores_max:
        erros.append("%d cores (limite %d)" % (cores, cores_max))
    ys, xs = np.where(solido)
    if xs.min() == 0 or ys.min() == 0 or xs.max() == w - 1 or ys.max() == h - 1:
        erros.append("sprite encosta na borda da imagem (cortado?)")
    pad = np.pad(solido, 1)
    viz = [pad[:-2, 1:-1], pad[2:, 1:-1], pad[1:-1, :-2], pad[1:-1, 2:]]
    borda = solido & ~(viz[0] & viz[1] & viz[2] & viz[3])
    lum = a[..., :3].astype(float) @ np.array([0.299, 0.587, 0.114])
    escuro = lum < 60
    prop = float((borda & escuro).sum()) / max(1, int(borda.sum()))
    if prop < 0.9:
        erros.append("contorno escuro em %d%% da borda (minimo 90%%)" % round(prop * 100))
    soltos = int((solido & ~(viz[0] | viz[1] | viz[2] | viz[3])).sum())
    if soltos:
        erros.append("%d pixels soltos (sem vizinho de 4 direcoes)" % soltos)
    if normal:
        n = np.array(Image.open(normal).convert("RGBA"))
        if n.shape[:2] != (h, w):
            erros.append("normal %dx%d difere do albedo %dx%d" % (n.shape[1], n.shape[0], w, h))
        else:
            v = n[..., :3].astype(float) / 255.0 * 2.0 - 1.0
            comp = np.linalg.norm(v[solido], axis=1)
            if abs(float(np.median(comp)) - 1.0) > 0.12:
                erros.append("normal nao unitaria (mediana do comprimento %.2f)" % float(np.median(comp)))
            neg = float((v[solido][:, 2] < -0.05).mean())
            if neg > 0.02:
                avisos.append("%d%% dos pixels com B < 0 (normal virada para longe da camera)" % round(neg * 100))
    return erros, avisos


def main(argv):
    cores, lado, itens = 40, 160, []
    i = 0
    while i < len(argv):
        if argv[i] == "--cores":
            cores = int(argv[i + 1]); i += 2
        elif argv[i] == "--max":
            lado = int(argv[i + 1]); i += 2
        else:
            itens.append(argv[i]); i += 1
    if not itens:
        print(__doc__); return 2
    pares = []
    if os.path.isdir(itens[0]):
        for f in sorted(os.listdir(itens[0])):
            b, e = os.path.splitext(f)
            if e != ".png" or b.endswith(("_n", "_normal")):
                continue
            nm = next((os.path.join(itens[0], b + s + ".png") for s in ("_n", "_normal")
                       if os.path.exists(os.path.join(itens[0], b + s + ".png"))), None)
            pares.append((os.path.join(itens[0], f), nm))
    else:
        pares.append((itens[0], itens[1] if len(itens) > 1 else None))
    falhou = 0
    for alb, nor in pares:
        er, av = conferir(alb, nor, cores, lado)
        print("%s %s" % ("FALHA" if er else "ok   ", os.path.basename(alb)))
        for m in er:
            print("   erro:  " + m)
        for m in av:
            print("   aviso: " + m)
        falhou += bool(er)
    return 1 if falhou else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

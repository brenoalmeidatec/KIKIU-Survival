"""Monta o GIF 'antes x depois' a partir das capturas do jogo (testes/captura_corte.gd).

    blender -b -P gif_jogo.py -- <pasta_antes> <pasta_depois> <saida.gif> [quadro_ini quadro_fim x0 y0 largura altura escala atraso_cs]
Corta a regiao do heroi, poe os dois lado a lado e usa paleta adaptativa (corte mediano) de 256 cores. Python do Blender (numpy), sem Pillow.
"""
import os
import struct
import sys

import bpy
import numpy as np

A = sys.argv[sys.argv.index("--") + 1:]
ANTES, DEPOIS, GIF = [os.path.abspath(a) for a in A[:3]]
ini, fim, x0, y0, lw, lh, esc, atraso = [int(v) for v in (A[3:] + ["20", "62", "380", "190", "240", "160", "2", "3"][len(A) - 3:])]


def png(caminho):
    img = bpy.data.images.load(caminho)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "CHANNEL_PACKED"
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]
    bpy.data.images.remove(img)
    return (a * 255 + 0.5).astype(np.uint8)


def recorta(p):
    c = png(p)[y0:y0 + lh, x0:x0 + lw]
    return np.repeat(np.repeat(c, esc, axis=0), esc, axis=1)


def lzw(indices, bits):
    clear, fim_ = 1 << bits, (1 << bits) + 1
    tab = {bytes([i]): i for i in range(clear)}
    prox, tam = fim_ + 1, bits + 1
    saida, buf, nb = bytearray(), 0, 0

    def emite(code):
        nonlocal buf, nb
        buf |= code << nb
        nb += tam
        while nb >= 8:
            saida.append(buf & 255)
            buf >>= 8
            nb -= 8

    emite(clear)
    atual = b""
    for px in indices:
        novo = atual + bytes([px])
        if novo in tab:
            atual = novo
        else:
            emite(tab[atual])
            if prox < 4096:
                tab[novo] = prox
                prox += 1
                if prox > (1 << tam) and tam < 12:
                    tam += 1
            else:
                emite(clear)
                tab = {bytes([i]): i for i in range(clear)}
                prox, tam = fim_ + 1, bits + 1
            atual = bytes([px])
    emite(tab[atual])
    emite(fim_)
    if nb:
        saida.append(buf & 255)
    return bytes(saida)


def paleta(pixels, n=256):
    chaves = ((pixels[:, 0] >> 3).astype(np.int32) << 10) | ((pixels[:, 1] >> 3).astype(np.int32) << 5) | (pixels[:, 2] >> 3).astype(np.int32)
    uniq, cont = np.unique(chaves, return_counts=True)
    rgb = np.stack([((uniq >> 10) & 31) << 3 | 4, ((uniq >> 5) & 31) << 3 | 4, (uniq & 31) << 3 | 4], axis=1).astype(np.float32)
    caixas = [(np.arange(len(uniq)))]
    while len(caixas) < n:
        i = max(range(len(caixas)), key=lambda k: (np.ptp(rgb[caixas[k]], axis=0).max() * cont[caixas[k]].sum()) if len(caixas[k]) > 1 else -1)
        idx = caixas[i]
        if len(idx) < 2:
            break
        canal = int(np.argmax(np.ptp(rgb[idx], axis=0)))
        ordem = idx[np.argsort(rgb[idx, canal])]
        acum = np.cumsum(cont[ordem])
        corte = int(np.searchsorted(acum, acum[-1] / 2)) + 1
        corte = min(max(corte, 1), len(ordem) - 1)
        caixas[i:i + 1] = [ordem[:corte], ordem[corte:]]
    pal = np.stack([(rgb[b] * cont[b][:, None]).sum(axis=0) / cont[b].sum() for b in caixas]).round().astype(np.uint8)
    mapa = np.empty(len(uniq), np.uint8)
    for k, b in enumerate(caixas):
        mapa[b] = k
    return pal, uniq, mapa


quadros = []
for i in range(ini, fim + 1):
    a = recorta(os.path.join(ANTES, "q%03d.png" % i))
    d = recorta(os.path.join(DEPOIS, "q%03d.png" % i))
    sep = np.full((a.shape[0], 4, 3), 255, np.uint8)
    quadros.append(np.concatenate([a, sep, d], axis=1))
h, w = quadros[0].shape[:2]
amostra = np.concatenate([q.reshape(-1, 3)[::3] for q in quadros])
pal, uniq, mapa = paleta(amostra)
bits = 8
palf = np.zeros((256, 3), np.uint8)
palf[:len(pal)] = pal
out = bytearray(b"GIF89a" + struct.pack("<HHBBB", w, h, 0x80 | (bits - 1), 0, 0) + palf.tobytes())
out += b"\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00"
for q in quadros:
    px = q.reshape(-1, 3)
    ch = ((px[:, 0] >> 3).astype(np.int32) << 10) | ((px[:, 1] >> 3).astype(np.int32) << 5) | (px[:, 2] >> 3).astype(np.int32)
    pos = np.searchsorted(uniq, ch)
    pos = np.clip(pos, 0, len(uniq) - 1)
    ok = uniq[pos] == ch
    ind = np.zeros(len(ch), np.uint8)
    ind[ok] = mapa[pos[ok]]
    if not ok.all():  # cores fora da amostra: mais proxima da paleta
        falta = px[~ok].astype(np.int32)
        d2 = ((falta[:, None, :] - pal[None, :, :].astype(np.int32)) ** 2).sum(axis=2)
        ind[~ok] = d2.argmin(axis=1).astype(np.uint8)
    out += b"\x21\xf9\x04\x00" + struct.pack("<H", atraso) + b"\x00\x00"
    out += b"\x2c" + struct.pack("<HHHHB", 0, 0, w, h, 0) + bytes([bits])
    dados = lzw(ind.tolist(), bits)
    for k in range(0, len(dados), 255):
        blk = dados[k:k + 255]
        out += bytes([len(blk)]) + blk
    out += b"\x00"
out += b"\x3b"
open(GIF, "wb").write(out)
print("GIF_JOGO", GIF, len(quadros), "quadros", w, "x", h, len(out) // 1024, "KB")

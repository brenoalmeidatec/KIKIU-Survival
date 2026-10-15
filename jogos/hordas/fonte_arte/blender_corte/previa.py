"""Previa do corte: monta GIF e uma tira PNG sobre fundo escuro, com a MESMA conta do shader do jogo (add de cor tingida).

    blender -b -P previa.py -- <folha.png> <saida_gif> [saida_tira_png]
Roda no Python do Blender (numpy); o GIF e escrito aqui mesmo (LZW), sem Pillow.
"""
import os
import struct
import sys

import bpy
import numpy as np

ARGS = sys.argv[sys.argv.index("--") + 1:]
FOLHA, GIF = os.path.abspath(ARGS[0]), os.path.abspath(ARGS[1])
TIRA = ARGS[2] if len(ARGS) > 2 else None
TAM, ESC = 128, 3
CIANO = "ciano" in os.path.basename(FOLHA)
N = 12 if CIANO else 16
RAMPA = np.array([(0.04, 0.55, 0.62), (0.10, 0.80, 0.85), (0.40, 0.95, 1.0), (0.92, 1.0, 1.0)], dtype=np.float32)
FUNDO = np.array([0.17, 0.16, 0.20], dtype=np.float32)
TINTAS = [((1.0, 0.92, 0.75), 1.0), ((0.85, 0.95, 1.0), -1.0)]   # cores dos 2 cortes do combo; lado 1 e -1


def carrega(caminho):
    img = bpy.data.images.load(caminho)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "STRAIGHT"
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]   # topo primeiro
    return a


def aplica(q, cor, lado):
    if lado < 0:
        q = q[::-1]
    h, a = q[..., 0:1], q[..., 3:4]
    if CIANO:  # mesma rampa do shader do jogo (modo fixo)
        pos = np.clip(h[..., 0], 0, 1) * 3.0
        i0 = np.clip(np.floor(pos).astype(int), 0, 2)
        c = RAMPA[i0] * (1 - (pos - i0)[..., None]) + RAMPA[i0 + 1] * (pos - i0)[..., None]
        return c * a * 2.0
    c = np.array(cor, dtype=np.float32) * (1 - h * 0.55) + h * 0.55   # mix(cor, branco, calor*0.55), igual ao jogo
    return c * a * 2.0                                                  # blend_add: rgb * alfa (mesmo fator de brilho do jogo)


def quadro(folha, i, cor, lado):
    i = min(i, N - 1)
    q = folha[:, i * TAM:(i + 1) * TAM]
    add = aplica(q, cor, lado)
    img = np.clip(FUNDO + add, 0, 1)
    img = np.repeat(np.repeat(img, ESC, axis=0), ESC, axis=1)
    return (img * 255 + 0.5).astype(np.uint8)


def lzw(indices, bits):
    clear, fim = 1 << bits, (1 << bits) + 1
    tab = {bytes([i]): i for i in range(clear)}
    prox, tam = fim + 1, bits + 1
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
                prox, tam = fim + 1, bits + 1
            atual = bytes([px])
    emite(tab[atual])
    emite(fim)
    if nb:
        saida.append(buf & 255)
    return bytes(saida)


def escreve_gif(quadros, atrasos, caminho):
    h, w = quadros[0].shape[:2]
    todas = np.concatenate([q.reshape(-1, 3) for q in quadros])
    cores, inv = np.unique(todas, axis=0, return_inverse=True)
    if len(cores) > 256:   # reduz tirando os 3 bits baixos
        todas = (todas // 8) * 8
        cores, inv = np.unique(todas, axis=0, return_inverse=True)
    assert len(cores) <= 256, len(cores)
    bits = max(2, int(np.ceil(np.log2(len(cores)))))
    pal = np.zeros((1 << bits, 3), np.uint8)
    pal[:len(cores)] = cores
    out = bytearray(b"GIF89a" + struct.pack("<HHBBB", w, h, 0x80 | (bits - 1), 0, 0) + pal.tobytes())
    out += b"\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00"
    off = 0
    for q, at in zip(quadros, atrasos):
        n = q.shape[0] * q.shape[1]
        ind = inv[off:off + n].astype(np.uint8)
        off += n
        out += b"\x21\xf9\x04\x00" + struct.pack("<H", at) + b"\x00\x00"
        out += b"\x2c" + struct.pack("<HHHHB", 0, 0, w, h, 0) + bytes([bits])
        dados = lzw(ind.tolist(), bits)
        for k in range(0, len(dados), 255):
            blk = dados[k:k + 255]
            out += bytes([len(blk)]) + blk
        out += b"\x00"
    out += b"\x3b"
    open(caminho, "wb").write(out)


folha = carrega(FOLHA)
seq, atr = [], []
for cor, lado in TINTAS:
    for i in range(N):
        seq.append(quadro(folha, i, cor, lado))
        atr.append(5 if i < 3 else (3 if i < 6 else (9 if i < 8 else 5)))   # centesimos de segundo
    seq.append(quadro(folha, N - 1, cor, lado) * 0 + (np.clip(FUNDO, 0, 1) * 255).astype(np.uint8))
    atr.append(40)
escreve_gif(seq, atr, GIF)
print("GIF", GIF, len(seq), "quadros")

if TIRA:
    lin = [np.concatenate([quadro(folha, i, TINTAS[0][0], 1.0) for i in range(r * 8, r * 8 + 8)], axis=1) for r in range((N + 7) // 8)]
    tira = np.concatenate(lin, axis=0)
    img = bpy.data.images.new("tira", tira.shape[1], tira.shape[0], alpha=False)
    img.colorspace_settings.name = "Non-Color"
    rgba = np.ones((tira.shape[0], tira.shape[1], 4), np.float32)
    rgba[..., :3] = tira / 255.0
    img.pixels = rgba[::-1].reshape(-1).tolist()
    img.filepath_raw = TIRA
    img.file_format = "PNG"
    img.save()
    print("TIRA", TIRA)

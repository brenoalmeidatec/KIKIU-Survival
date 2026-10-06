"""Mede as músicas (OGG) por dados: duração, pico, RMS, centróide espectral, tonalidade dominante,
estalo no ponto de laço, e salva um espectrograma PNG por faixa. Uso:
  python analisar_musica.py <pasta_com_oggs> <pasta_saida> [rotulo]
Escreve <pasta_saida>/relatorio_<rotulo>.json e espectro_<rotulo>_<faixa>.png (precisa de ffmpeg)."""
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

SR = 32000
NOTAS = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
KK_MAIOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
KK_MENOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])


def ler(caminho):
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", caminho, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                       capture_output=True, check=True)
    return np.frombuffer(r.stdout, np.float32).reshape(-1, 2).T.copy()


def tonalidade(mono):
    n = 8192
    janelas = np.lib.stride_tricks.sliding_window_view(mono, n)[::n * 2]
    esp = np.abs(np.fft.rfft(janelas * np.hanning(n), axis=1)).mean(0) ** 2
    f = np.fft.rfftfreq(n, 1 / SR)
    chroma = np.zeros(12)
    for fi, e in zip(f, esp):
        if 40 < fi < 2000:
            chroma[int(round(12 * np.log2(fi / 440) + 69)) % 12] += e
    chroma /= chroma.sum()
    melhor = None
    for modo, perfil in (("maior", KK_MAIOR), ("menor", KK_MENOR)):
        for t in range(12):
            c = np.corrcoef(chroma, np.roll(perfil, t))[0, 1]
            if melhor is None or c > melhor[0]:
                melhor = (c, f"{NOTAS[t]} {modo}")
    grave = np.zeros(12)   # nota mais forte no grave (30-130 Hz, FFT do arquivo todo): costuma ser a tônica
    P = np.abs(np.fft.rfft(mono * np.hanning(len(mono)))) ** 2
    fg = np.fft.rfftfreq(len(mono), 1 / SR)
    sel = (fg > 30) & (fg < 130)
    for fi, e in zip(fg[sel], P[sel]):
        grave[int(round(12 * np.log2(fi / 440) + 69)) % 12] += e
    return melhor[1], NOTAS[int(np.argmax(chroma))], NOTAS[int(np.argmax(grave))]


def espectrograma(mono, caminho):
    n, h = 1024, 512
    jan = np.lib.stride_tricks.sliding_window_view(mono, n)[::h]
    s = np.abs(np.fft.rfft(jan * np.hanning(n), axis=1)).T
    db = 20 * np.log10(s + 1e-7)
    db = np.clip(db, db.max() - 90, db.max())
    f = np.fft.rfftfreq(n, 1 / SR)
    alvo = np.geomspace(35, 12000, 360)   # eixo de frequência em escala log
    idx = np.searchsorted(f, alvo).clip(0, len(f) - 1)
    img = db[idx][::-1]
    v = ((img - img.min()) / (img.max() - img.min()) * 255).astype(np.uint8)
    cores = np.stack([v, (v * 0.55).astype(np.uint8), (255 - v) // 2 + (v // 4)], -1)
    im = Image.fromarray(cores)
    im.resize((min(1400, im.width), 360), Image.BILINEAR).save(caminho)


def analisar(caminho, saida=None, nome=""):
    x = ler(caminho)
    mono = x.mean(0)
    pico = float(np.abs(x).max())
    rms = float(np.sqrt((x ** 2).mean()))
    n = 4096
    jan = np.lib.stride_tricks.sliding_window_view(mono, n)[::n]
    e = np.abs(np.fft.rfft(jan * np.hanning(n), axis=1))
    f = np.fft.rfftfreq(n, 1 / SR)
    cent = (e * f).sum(1) / (e.sum(1) + 1e-9)
    ativo = e.sum(1) > e.sum(1).max() * 0.02
    clip = int((np.abs(x) >= 0.999).sum())
    # estalo no laço: salto entre última e primeira amostra vs. variação típica entre amostras vizinhas
    salto = float(np.abs(mono[-1] - mono[0]))
    tip = float(np.abs(np.diff(mono)).mean())
    ton, chroma, grave = tonalidade(mono)
    r = {"duracao_s": round(len(mono) / SR, 1), "pico_dBFS": round(float(20 * np.log10(pico + 1e-9)), 2),
         "rms_dBFS": round(float(20 * np.log10(rms + 1e-9)), 2), "centroide_Hz": round(float(cent[ativo].mean()), 0),
         "tonalidade": ton, "nota_dominante": chroma, "nota_grave": grave, "amostras_clipadas": clip,
         "laco_salto_vs_tipico": round(salto / (tip + 1e-9), 1), "tamanho_KB": round(os.path.getsize(caminho) / 1024)}
    if saida:
        espectrograma(mono, os.path.join(saida, f"espectro_{nome}.png"))
    return r


if __name__ == "__main__":
    pasta, saida = sys.argv[1], sys.argv[2]
    rot = sys.argv[3] if len(sys.argv) > 3 else "x"
    os.makedirs(saida, exist_ok=True)
    rel = {}
    for a in sorted(os.listdir(pasta)):
        if a.endswith((".ogg", ".mp3")):
            rel[a[:-4]] = analisar(os.path.join(pasta, a), saida, f"{rot}_{a[:-4]}")
            print(a[:-4], rel[a[:-4]])
    json.dump(rel, open(os.path.join(saida, f"relatorio_{rot}.json"), "w"), indent=1, ensure_ascii=False)

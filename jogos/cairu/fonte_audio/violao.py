"""Violão do Seu Mauro (minijogo "Resenha no violão").

Tudo sintetizado aqui, sem sample de fora: corda de nylon pelo método Karplus-Strong
(um ruído curto que vai circulando num atraso do tamanho da nota e perdendo os agudos,
como uma corda de verdade) e um filtro de "caixa" de violão por cima.
A música é ORIGINAL (melodia e acompanhamento feitos aqui), em Sol maior, num xote.

Saída:
  ../projeto/assets/audio/musica/violao_mauro.ogg     acompanhamento (sem a melodia)
  ../projeto/assets/audio/efeitos/violao_<nota>.wav   cada nota da melodia (o jogador toca)
  ../projeto/assets/audio/efeitos/violao_abafado.wav  corda abafada (nota perdida)
  ../projeto/minijogos/violao_musica.json             tempo de cada nota (as bolinhas)

    python3 violao.py
"""
import json
import os
import subprocess
import wave

import numpy as np

SR = 44100
AQUI = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.join(AQUI, "..", "projeto")
BPM = 96
OITAVO = 60.0 / BPM / 2          # duração de uma colcheia (s)
COMPASSO = OITAVO * 8            # 4/4
INTRO = 1                        # compassos só de acompanhamento antes da melodia

# ------------------------------------------------------------------ a música

# Acordes (um por compasso, depois da introdução)
ACORDES = ["G", "Em", "C", "D", "G", "Em", "Am", "D", "C", "D", "G", "G"]
NOTAS_ACORDE = {  # cordas do violão de baixo pra cima (MIDI)
    "G": [43, 47, 50, 55, 59, 67], "Em": [40, 47, 52, 55, 59, 64], "C": [48, 52, 55, 60, 64],
    "D": [50, 57, 62, 66], "Am": [45, 52, 57, 60, 64],
}
BAIXO = {"G": (43, 50), "Em": (40, 47), "C": (48, 43), "D": (50, 45), "Am": (45, 40)}

# Melodia: por compasso, (colcheia em que começa, nota MIDI, quantas colcheias dura)
MELODIA = [
    [(0, 74, 2), (2, 71, 1), (3, 74, 1), (4, 79, 2), (6, 78, 1), (7, 76, 1)],
    [(0, 74, 3), (3, 71, 1), (4, 67, 2), (6, 71, 2)],
    [(0, 72, 1), (1, 72, 1), (2, 76, 2), (4, 74, 1), (5, 72, 1), (6, 71, 2)],
    [(0, 69, 2), (2, 71, 1), (3, 72, 1), (4, 74, 4)],
    [(0, 79, 2), (2, 78, 1), (3, 76, 1), (4, 74, 2), (6, 71, 2)],
    [(0, 76, 1), (1, 74, 1), (2, 71, 2), (4, 67, 2), (6, 69, 1), (7, 71, 1)],
    [(0, 72, 2), (2, 72, 1), (3, 71, 1), (4, 69, 2), (6, 76, 2)],
    [(0, 74, 3), (3, 72, 1), (4, 69, 2), (6, 66, 2)],
    [(0, 64, 1), (1, 67, 1), (2, 72, 2), (4, 72, 1), (5, 74, 1), (6, 76, 2)],
    [(0, 78, 1), (1, 76, 1), (2, 74, 2), (4, 72, 1), (5, 71, 1), (6, 69, 2)],
    [(0, 71, 2), (2, 74, 2), (4, 79, 2), (6, 78, 1), (7, 79, 1)],
    [(0, 79, 6)],
]


def faixa(nota):
    """Nota grave fica na esquerda, aguda na direita (0 esquerda, 1 baixo, 2 cima, 3 direita)."""
    if nota <= 67:
        return 0
    if nota <= 71:
        return 1
    if nota <= 74:
        return 2
    return 3


# ------------------------------------------------------------------ a corda

_cache = {}


def corda(nota, dur=2.0, brilho=0.5, decai=0.996):
    """Uma corda de nylon beliscada (Karplus-Strong em blocos)."""
    chave = (nota, round(dur, 2), brilho, decai)
    if chave in _cache:
        return _cache[chave]
    f = 440.0 * 2 ** ((nota - 69) / 12)
    n_total = int(dur * SR)
    N = max(int(round(SR / f - 0.5)), 2)
    rng = np.random.default_rng(nota * 7 + 3)
    # forma da corda puxada pelo dedo (triângulo com o pico perto do cavalete) + um pouco de ruído
    xs = np.arange(N) / N
    pico = 0.18
    ex = np.where(xs < pico, xs / pico, (1 - xs) / (1 - pico))
    ex = ex - ex.mean() + rng.uniform(-1, 1, N) * (0.15 + brilho * 0.25)
    # belisco: tira um pouco do agudo do ruído inicial (nylon é macio) e marca o ponto do dedo
    for _ in range(int(2 + (1 - brilho) * 6)):
        ex = 0.5 * (ex + np.roll(ex, 1))
    p = max(1, int(N * 0.13))
    ex = ex - np.roll(ex, p) * 0.35
    ex -= ex.mean()
    y = np.zeros(n_total + N + 1)
    y[1:N + 1] = ex
    k = N + 1
    while k < len(y):
        fim = min(k + N, len(y))
        y[k:fim] = decai * 0.5 * (y[k - N:fim - N] + y[k - N - 1:fim - N - 1])
        k = fim
    y = y[1:n_total + 1]
    # nota alta morre mais rápido; o fim some sem estalo
    t = np.arange(n_total) / SR
    y *= np.exp(-t * (0.4 + max(0, 60 - nota) * 0.02))
    y[-200:] *= np.linspace(1, 0, 200)
    y /= max(np.abs(y).max(), 1e-9)
    _cache[chave] = y
    return y


def ressonancia(x, f0, q, ganho):
    """Filtro de pico (biquad) pra dar o 'corpo' da caixa do violão."""
    w = 2 * np.pi * f0 / SR
    alfa = np.sin(w) / (2 * q)
    A = 10 ** (ganho / 40)
    b0, b1, b2 = 1 + alfa * A, -2 * np.cos(w), 1 - alfa * A
    a0, a1, a2 = 1 + alfa / A, -2 * np.cos(w), 1 - alfa / A
    b = np.array([b0, b1, b2]) / a0
    a = np.array([1, a1 / a0, a2 / a0])
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        v = b[0] * x[i] + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
        x2, x1, y2, y1 = x1, x[i], y1, v
        y[i] = v
    return y


def caixa(x):
    """Corpo do violão: graves em ~110 Hz e ~220 Hz, tira um pouco dos agudos."""
    x = ressonancia(x, 110, 1.4, 5)
    x = ressonancia(x, 230, 1.8, 3)
    x = ressonancia(x, 3200, 0.7, -4)
    return x


def por(buf, som, t, vol):
    i = int(t * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(som))
    buf[i:j] += som[:j - i] * vol


def batida(buf, t, acorde, pra_baixo=True, vol=0.18, so_agudas=False):
    """Rasqueado: as cordas uma depois da outra, bem rapidinho."""
    notas = NOTAS_ACORDE[acorde]
    if so_agudas:
        notas = notas[-3:]
    if not pra_baixo:
        notas = notas[::-1]
    for k, n in enumerate(notas):
        por(buf, corda(n, 1.2, 0.55, 0.994), t + k * 0.011, vol * (0.8 if not pra_baixo else 1.0))


def ganzá(buf, t, vol):
    n = int(0.05 * SR)
    r = np.random.default_rng(int(t * 1000)).uniform(-1, 1, n)
    r = r - np.roll(r, 1)
    por(buf, r * np.linspace(1, 0, n) ** 2, t, vol)


# ------------------------------------------------------------------ montar


def acompanhamento():
    compassos = INTRO + len(ACORDES)
    dur = compassos * COMPASSO + 2.0
    buf = np.zeros(int(dur * SR))
    for c in range(compassos):
        ac = ACORDES[0] if c < INTRO else ACORDES[c - INTRO]
        t0 = c * COMPASSO
        b1, b2 = BAIXO[ac]
        # xote: baixo no 1 e no "e" do 2, batida nos contratempos
        por(buf, corda(b1, 1.6, 0.35, 0.997), t0, 0.42)
        por(buf, corda(b2, 1.2, 0.35, 0.997), t0 + OITAVO * 3, 0.32)
        por(buf, corda(b1, 1.2, 0.35, 0.997), t0 + OITAVO * 4, 0.36)
        batida(buf, t0 + OITAVO * 2, ac, True, 0.14, so_agudas=True)
        batida(buf, t0 + OITAVO * 5, ac, False, 0.11, so_agudas=True)
        batida(buf, t0 + OITAVO * 6, ac, True, 0.15, so_agudas=True)
        for k in range(8):
            ganzá(buf, t0 + k * OITAVO, 0.035 if k % 2 else 0.05)
    # acorde final, deixa soar
    fim = compassos * COMPASSO
    batida(buf, fim, "G", True, 0.2)
    por(buf, corda(43, 2.0, 0.35, 0.997), fim, 0.4)
    buf = caixa(buf)
    return buf / np.abs(buf).max() * 0.8


def nota_solo(n):
    x = np.concatenate([np.zeros(64), corda(n, 2.0, 0.6, 0.9995)])
    x = caixa(x)
    return x / np.abs(x).max() * 0.85


def abafado():
    x = corda(55, 0.12, 0.3, 0.9) * np.exp(-np.arange(int(0.12 * SR)) / SR * 40)
    x = caixa(x)
    return x / np.abs(x).max() * 0.5


def grade():
    """Lista das notas da melodia, com o tempo (s) em que cada uma tem que ser tocada."""
    notas = []
    for c, compasso in enumerate(MELODIA):
        for (col, n, d) in compasso:
            t = (INTRO + c) * COMPASSO + col * OITAVO
            notas.append({"t": round(t, 4), "nota": n, "faixa": faixa(n), "dura": d,
                          "forte": col % 2 == 0})
    acordes = [ACORDES[0]] * INTRO + ACORDES
    return {"bpm": BPM, "compasso": round(COMPASSO, 4), "intro": INTRO, "duracao": round(
        (INTRO + len(ACORDES)) * COMPASSO + 1.5, 3), "acordes": acordes,
        "notas_acorde": {a: [n for n in v if n >= 55][:4] for a, v in NOTAS_ACORDE.items()},
        "notas": notas}


def gravar_wav(caminho, x):
    x = np.clip(x, -1, 1)
    with wave.open(caminho, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def main():
    pm = os.path.join(PROJ, "assets", "audio", "musica")
    pe = os.path.join(PROJ, "assets", "audio", "efeitos")
    g = grade()
    usadas = sorted({n["nota"] for n in g["notas"]} | {n for v in g["notas_acorde"].values() for n in v})
    for n in usadas:
        gravar_wav(os.path.join(pe, "violao_%d.wav" % n), nota_solo(n))
    gravar_wav(os.path.join(pe, "violao_abafado.wav"), abafado())
    tmp = os.path.join(pm, "violao_mauro_tmp.wav")
    gravar_wav(tmp, acompanhamento())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5",
                    os.path.join(pm, "violao_mauro.ogg")], check=True)
    os.remove(tmp)
    with open(os.path.join(PROJ, "minijogos", "violao_musica.json"), "w", encoding="utf-8") as f:
        json.dump(g, f, ensure_ascii=False, indent=1)
    print("violão ok:", len(g["notas"]), "notas,", g["duracao"], "s, notas:", usadas)


if __name__ == "__main__":
    main()

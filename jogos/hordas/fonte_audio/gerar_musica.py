"""Gera as músicas do K.I.K.I.U (dark fantasy) em OGG estéreo com laço perfeito.

Tudo é sintetizado aqui com numpy, sem samples: drones graves, coro (síntese aditiva com formantes),
sinos inarmônicos, órgão, cello/baixo, tambores de guerra, sussurros e reverb de convolução.
Toda a composição é CIRCULAR: notas e reverb que passam do fim voltam ao começo, então o fim
emenda no início sem estalo (basta o jogo tocar em laço).

Uso (a partir desta pasta):   python gerar_musica.py [faixa ...]
Saída: ../projeto/assets/audio/musica/<faixa>.ogg  (precisa de ffmpeg com libvorbis no PATH)
Depois rode o import do Godot:  Godot --headless --path ../projeto --import
Faixas: menu, minijogo_tenso (as fases), chefe, minijogo_retro (duelo PvP), fim, horror.
Medidas antes/depois: python analisar_musica.py <pasta_oggs> <saida> <rotulo>
"""
import os
import subprocess
import sys

import numpy as np
import soundfile as sf

SR = 24000
AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.join(AQUI, "..", "projeto", "assets", "audio", "musica")

# ------------------------------------------------------------------ utilidades


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def suave(n):
    """menor inteiro >= n só com fatores 2, 3 e 5 (FFT rápida no tamanho exato do laço)"""
    while True:
        m = n
        for p in (2, 3, 5):
            while m % p == 0:
                m //= p
        if m == 1:
            return n
        n += 1


def tempo(d):
    return np.arange(int(d * SR)) / SR


def filtro(x, fc, ordem=2, alto=False, circ=False):
    """passa-baixa (ou alta) de fase zero por FFT; x pode ser (n,) ou (2, n)"""
    n = x.shape[-1]
    m = n if circ else suave(n + int(SR * 0.25))
    X = np.fft.rfft(x, n=m, axis=-1)
    f = np.fft.rfftfreq(m, 1 / SR)
    r = (f / fc) ** (2 * ordem) if not alto else (fc / np.maximum(f, 1e-3)) ** (2 * ordem)
    X = X / np.sqrt(1 + r)
    return np.fft.irfft(X, n=m, axis=-1)[..., :n]


def banda(x, f1, f2):
    return filtro(filtro(x, f2, 2), f1, 2, alto=True)


def env(n, a, r, curva=1.5):
    e = np.ones(n)
    na, nr = min(int(a * SR), n), min(int(r * SR), n)
    if na:
        e[:na] = np.linspace(0, 1, na, endpoint=False) ** curva
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr) ** curva
    return e


def pan_gl(p):
    ang = (p + 1) * np.pi / 4
    return np.cos(ang), np.sin(ang)


# ------------------------------------------------------------------ instrumentos


def drone(m, dur, brilho=700.0, detune=(-6, 0, 7)):
    """grave contínuo: dente-de-serra aditivo, três vozes desafinadas, vibrato lento"""
    t = tempo(dur)
    f0 = hz(m)
    out = np.zeros(len(t))
    for k, c in enumerate(detune):
        f = f0 * 2 ** (c / 1200)
        lfo = 0.0015 * np.sin(2 * np.pi * (0.11 + 0.037 * k) * t + k)
        fase = 2 * np.pi * f * (t + np.cumsum(lfo) / SR * 0 + lfo / (2 * np.pi * 0.11))
        for h in range(1, 40):
            if f * h > brilho * 2.5:
                break
            a = (1 / h ** 1.1) * np.exp(-(f * h / brilho) ** 2)
            out += a * np.sin(h * fase + 1.7 * h * k)
    out += 0.9 * np.sin(2 * np.pi * f0 * t)
    return out * env(len(t), min(2.5, dur * 0.4), min(3.0, dur * 0.4)) / 3.0


FORMANTES = {
    "o": [(430, 90, 1.0), (820, 110, 0.5), (2300, 250, 0.07)],
    "a": [(690, 110, 1.0), (1150, 120, 0.6), (2500, 250, 0.1)],
    "u": [(320, 70, 1.0), (700, 90, 0.35), (2200, 250, 0.04)],
    "e": [(500, 90, 1.0), (1700, 140, 0.35), (2400, 250, 0.1)],
}


def coro(m, dur, vogal="o", vozes=4, ataque=1.4, solta=1.8, vib=0.6):
    """coro: vozes desafinadas, harmônicos moldados por formantes, respiração; devolve (2, n)"""
    t = tempo(dur)
    n = len(t)
    out = np.zeros((2, n))
    rng = np.random.default_rng(int(m * 100 + dur * 10))
    forms = FORMANTES[vogal]
    f0 = hz(m)
    for v in range(vozes):
        c = rng.uniform(-14, 14)
        f = f0 * 2 ** (c / 1200)
        vr = rng.uniform(4.6, 5.8)
        vd = 0.006 * vib * np.clip(t * 0.6 - 0.2, 0, 1)
        fase = 2 * np.pi * f * t + (vd * f / vr) * np.sin(2 * np.pi * vr * t + rng.uniform(0, 6.28))
        s = np.zeros(n)
        for h in range(1, 40):
            fh = f * h
            if fh > 3300:
                break
            a = sum(g * np.exp(-0.5 * ((fh - fc) / bw) ** 2) for fc, bw, g in forms) + 0.03 / h
            s += (a / h ** 0.5) * np.sin(h * fase + rng.uniform(0, 6.28))
        gl, gr = pan_gl(rng.uniform(-0.8, 0.8))
        out[0] += s * gl
        out[1] += s * gr
    resp = banda(np.random.default_rng(5).normal(size=n), 700, 2800) * 0.05
    out += resp
    return out * env(n, ataque, solta, 2.0) / (vozes * 1.5)


def sino(m, dur=7.0, brilho=1.0, tau=1.6):
    """sino/gongo inarmônico (tom de luto): parcial grave, terça menor, quinta"""
    t = tempo(dur)
    f0 = hz(m)
    razoes = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 3.011, 4.166]
    amps = [0.55, 1.0, 0.6, 0.35, 0.45, 0.2, 0.14, 0.08]
    taus = [1.0, 1.0, 0.8, 0.65, 0.5, 0.33, 0.22, 0.14]
    out = np.zeros(len(t))
    for i, (r, a, ta) in enumerate(zip(razoes, amps, taus)):
        if f0 * r > 6000:
            continue
        g = a * (brilho if i > 3 else 1.0)
        out += g * np.exp(-t / (tau * ta)) * np.sin(2 * np.pi * f0 * r * (1 + 0.0015 * i) * t + i)
    bat = 0.35 * np.exp(-t / (tau * 0.9)) * np.sin(2 * np.pi * (f0 * 1.003) * t)   # batimento (som "rachado")
    out += bat
    golpe = np.random.default_rng(int(m)).normal(size=len(t)) * np.exp(-t / 0.012)
    out += 0.2 * filtro(golpe, 2500)
    return out * env(len(t), 0.002, 0.3) / 2.6


def orgao(m, dur, ataque=0.5, solta=1.0, mais_grave=True):
    t = tempo(dur)
    f = hz(m)
    out = np.zeros(len(t))
    draw = [(0.5, 0.5), (1, 1.0), (2, 0.55), (3, 0.4), (4, 0.25), (6, 0.12), (8, 0.08)]
    for d, a in draw:
        for c in (-5, 5):
            out += a * np.sin(2 * np.pi * f * d * 2 ** (c / 1200) * t + d + c)
    out *= 1 + 0.06 * np.sin(2 * np.pi * 5.3 * t)
    return filtro(out, 1500, 2) * env(len(t), ataque, solta, 1.5) / 7.0


def baixo(m, dur, queda=1.2, brilho=1100.0):
    """cello/baixo pesado: dente-de-serra aditivo cujo brilho decai"""
    t = tempo(dur)
    f = hz(m)
    out = np.zeros(len(t))
    for h in range(1, 40):
        if f * h > brilho * 2.5:
            break
        out += (1 / h) * np.exp(-t * queda * h * 0.12) * np.exp(-(f * h / brilho) ** 2) * np.sin(2 * np.pi * f * h * t + h)
    out += 0.7 * np.sin(2 * np.pi * f * t)
    return out * env(len(t), 0.02, min(0.25, dur * 0.4)) / 2.0


def metal(m, dur, abre=0.18, fc=950.0):
    """sopro grave de metais: dente-de-serra desafinada com filtro que abre no ataque"""
    t = tempo(dur)
    out = np.zeros(len(t))
    corte = fc * (0.45 + 0.55 * (1 - np.exp(-t / abre)))
    for c in (-9, 0, 9):
        f = hz(m) * 2 ** (c / 1200)
        for h in range(1, 40):
            if f * h > fc * 2.4:
                break
            out += (1 / h) * np.exp(-(f * h / corte) ** 2) * np.sin(2 * np.pi * f * h * t + h * c)
    return out * env(len(t), 0.05, 0.12) / 2.5


_cache = {}


def tambor(f0=58.0, dur=1.4, corpo=0.38, couro=0.5):
    """tambor de guerra (taiko grave): seno com queda de afinação + estalo de couro filtrado"""
    k = ("tambor", f0, dur, corpo, couro)
    if k in _cache:
        return _cache[k]
    t = tempo(dur)
    freq = f0 * (1 + 1.4 * np.exp(-t / 0.045))
    fase = 2 * np.pi * np.cumsum(freq) / SR
    x = np.sin(fase) * np.exp(-t / corpo) + 0.35 * np.sin(fase * 1.58 + 0.5) * np.exp(-t / (corpo * 0.5))
    rud = np.random.default_rng(int(f0)).normal(size=len(t))
    x += couro * filtro(rud, 700, 2) * np.exp(-t / 0.05)
    x *= env(len(t), 0.001, 0.1)
    _cache[k] = x
    return x


def caixa(dur=0.45, tom=210.0, fc=2600.0):
    """tarol de guerra, escuro: ruído filtrado + corpo curto"""
    k = ("caixa", dur, tom, fc)
    if k in _cache:
        return _cache[k]
    t = tempo(dur)
    r = filtro(np.random.default_rng(int(tom)).normal(size=len(t)), fc, 2)
    x = 0.8 * r * np.exp(-t / 0.09) + 0.6 * np.sin(2 * np.pi * tom * (1 + 0.5 * np.exp(-t / 0.02)) * t) * np.exp(-t / 0.07)
    _cache[k] = x * env(len(t), 0.001, 0.05)
    return _cache[k]


def sussurro(dur, semente, f1=1100, f2=3800):
    """sussurro: ruído com máscara espectral 'vocal' e envelope de respiração; devolve mono"""
    n = int(dur * SR)
    rng = np.random.default_rng(semente)
    m = suave(n)
    X = np.fft.rfft(rng.normal(size=m))
    f = np.fft.rfftfreq(m, 1 / SR)
    centro = rng.uniform(f1 * 1.2, f2 * 0.6)
    larg = rng.uniform(0.6, 1.1)
    mask = np.exp(-0.5 * (np.log2(np.maximum(f, 1) / centro) / larg) ** 2)
    mask *= 1 + 0.7 * np.sin(2 * np.pi * f / rng.uniform(180, 420) + rng.uniform(0, 6))
    x = np.fft.irfft(X * mask, n=m)[:n]
    t = np.arange(n) / SR
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2.5 * (0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(2.2, 4.0) * t + 1))
    return x * e * 0.3 / max(np.abs(x).max(), 1e-6)


def rumor(dur, fc=60, semente=3):
    n = int(dur * SR)
    x = filtro(np.random.default_rng(semente).normal(size=n), fc, 3)
    return x / max(np.abs(x).max(), 1e-6)


# ------------------------------------------------------------------ mesa de mixagem


# equilíbrio por instrumento (o ouvido pesa menos o grave que a energia bruta)
MIX = {"drone": 0.5, "coro": 1.9, "sino": 1.7, "sussurro": 6.0, "orgao": 1.5, "baixo": 0.85, "rumor": 0.6,
       "tambor": 1.35, "caixa": 1.2, "metal": 1.0, "coracao": 1.1}


class Faixa:
    def __init__(self, nome, bpm, compassos, semente=1):
        self.nome, self.compassos = nome, compassos
        self.N = suave(int(round(compassos * 4 * 60 / bpm * SR)))
        self.cs = self.N / SR / compassos          # duração de um compasso (s)
        self.b = self.cs / 4                        # um tempo (s)
        self.bpm = compassos * 4 * 60 / (self.N / SR)
        self.seco = np.zeros((2, self.N))
        self.rev = np.zeros((2, self.N))
        self.rng = np.random.default_rng(semente)
        self.energia = {}

    def poe(self, sig, t, g=1.0, pan=0.0, rev=0.3, rotulo="x", seco=1.0):
        """soma sig (n,) ou (2, n) no instante t (s), dando a volta no fim do laço"""
        if sig.ndim == 1:
            gl, gr = pan_gl(pan)
            sig = np.stack([sig * gl, sig * gr])
        sig = sig * g * MIX.get(rotulo, 1.0)
        n = sig.shape[1]
        i = int(round(t * SR)) % self.N
        self.energia[rotulo] = self.energia.get(rotulo, 0.0) + float((sig ** 2).sum()) / self.N
        pos = 0
        while pos < n:
            k = min(n - pos, self.N - i)
            self.seco[:, i:i + k] += sig[:, pos:pos + k] * seco
            self.rev[:, i:i + k] += sig[:, pos:pos + k] * rev
            pos += k
            i = 0

    def reverb(self, tempo_rev, escuro=0.4, pre=0.035, semente=11):
        """convolução circular com resposta ruidosa; graves duram mais que agudos"""
        L = int(tempo_rev * SR * 1.2)
        out = np.zeros_like(self.rev)
        for c in range(2):
            r = np.random.default_rng(semente + c * 7).normal(size=L)
            tt = np.arange(L) / SR
            lo = filtro(r, 1200, 2)
            hi = r - lo
            ir = lo * np.exp(-tt / (tempo_rev / 6.9)) + 0.5 * hi * np.exp(-tt / (tempo_rev * escuro / 6.9))
            ir = np.concatenate([np.zeros(int(pre * SR)), ir])[:L]
            ir /= np.sqrt((ir ** 2).sum())
            irp = np.zeros(self.N)
            irp[:len(ir)] = ir
            out[c] = np.fft.irfft(np.fft.rfft(self.rev[c]) * np.fft.rfft(irp), n=self.N)
        return out

    def masterizar(self, rev_t=4.0, rev_mix=0.55, corte=3200, rms_alvo=-21.0, escuro=0.35, fundo_baixo=1.0):
        molhado = self.reverb(rev_t, escuro)
        x = self.seco + rev_mix * molhado
        # filtro final de fase zero (circular, não quebra o laço): tira agudos e o que está abaixo de 28 Hz
        x = filtro(x, corte, 2, circ=True)
        x = filtro(x, 28, 2, alto=True, circ=True)
        rms = np.sqrt((x ** 2).mean())
        x *= 10 ** (rms_alvo / 20) / max(rms, 1e-9)
        lim = 0.74   # ~ -2,6 dBFS: limitador suave, nunca passa disso
        x = lim * np.tanh(x / lim)
        return x

    def relatorio(self):
        tot = sum(self.energia.values()) or 1
        return {k: round(100 * v / tot) for k, v in sorted(self.energia.items(), key=lambda a: -a[1])}


def escala(ton, iv, g):
    o, i = divmod(g, len(iv))
    return ton + 12 * o + iv[i]


MENOR = [0, 2, 3, 5, 7, 8, 10]
FRIGIO = [0, 1, 3, 5, 7, 8, 10]
DORICO = [0, 2, 3, 5, 7, 9, 10]
ACORDE = {"m": [0, 3, 7], "M": [0, 4, 7], "dim": [0, 3, 6], "cl": [0, 1, 6], "m1": [0, 3, 7, 10]}


def acorde(raiz, tipo):
    return [raiz + i for i in ACORDE[tipo]]


# ------------------------------------------------------------------ as faixas


def faixa_menu():
    """menu: lento e agourento; D frígio; drone, coro, sinos longínquos, coração distante"""
    f = Faixa("menu", 46, 16, 1)
    prog = [(38, "m", "o"), (39, "M", "u"), (36, "m", "o"), (38, "m", "a")]   # Dm | Eb | Cm | Dm
    for c, (raiz, tipo, vog) in enumerate(prog):
        t0 = c * 4 * f.cs
        f.poe(drone(raiz - 12, 4 * f.cs + 3.5, 520), t0 - 0.4, 0.9, 0, 0.25, "drone")
        notas = acorde(raiz + 12, tipo) + [raiz + 24]
        for k, nn in enumerate(notas):
            f.poe(coro(nn, 4 * f.cs + 2.5, vog, 4), t0 + 0.2 * k, 0.55, (-0.6, 0.0, 0.6, 0.2)[k], 0.7, "coro")
        f.poe(baixo(raiz, 4 * f.cs * 0.9, 0.3, 500), t0, 0.5, 0, 0.4, "baixo")
        # sinos esparsos: fraseado lento pela escala frígia de ré
        grau = int(f.rng.integers(2, 5))
        for q in range(int(f.rng.integers(2, 4))):
            grau = int(np.clip(grau + f.rng.choice([-2, -1, 1, 2]), 0, 8))
            f.poe(sino(escala(50, FRIGIO, grau), 9.0, 0.6), t0 + f.cs * (0.7 + 1.1 * q + float(f.rng.uniform(0, 0.4))), 0.55,
                  float(f.rng.uniform(-0.7, 0.7)), 0.9, "sino")
    # coração distante: dois tambores surdos por compasso, bem baixos
    for c in range(f.compassos):
        f.poe(tambor(55, 1.6, 0.55, 0.15), c * f.cs, 0.55, 0, 0.8, "tambor")
        if c % 2 == 0:
            f.poe(tambor(55, 1.6, 0.55, 0.15), c * f.cs + 0.75 * f.b * 2, 0.3, 0, 0.8, "tambor")
    f.poe(rumor(f.N / SR, 55, 4), 0, 0.35, 0, 0.1, "rumor")
    for q in range(3):
        f.poe(sussurro(9.0, 20 + q), q * f.N / SR / 3 + 3, 0.4, float(f.rng.uniform(-0.8, 0.8)), 1.0, "sussurro")
    return f, dict(rev_t=5.5, rev_mix=0.6, corte=2800, rms_alvo=-22.5)


def faixa_fase():
    """fases: tambores de guerra pesados, ostinato grave, coro e sinos; E frígio, 72 bpm"""
    f = Faixa("fase", 72, 24, 2)
    prog = [(40, "m"), (40, "m"), (41, "M"), (40, "m"), (36, "M"), (45, "m"), (41, "M"), (40, "m"),
            (40, "m"), (41, "M"), (38, "m"), (40, "m")]    # 12 acordes de 2 compassos
    for c, (raiz, tipo) in enumerate(prog):
        t0 = c * 2 * f.cs
        dur = 2 * f.cs
        f.poe(drone(raiz - 12, dur + 3, 650), t0 - 0.3, 0.8, 0, 0.2, "drone")
        for k, nn in enumerate(acorde(raiz + 12, tipo)):
            f.poe(coro(nn, dur + 2.2, "o" if c % 2 == 0 else "a", 4, 1.0), t0 + 0.05 * k, 0.5, (-0.6, 0.6, 0.0)[k], 0.65, "coro")
        # ostinato "galope" de baixo: colcheias graves, acento no primeiro
        for bar in range(2):
            tb = t0 + bar * f.cs
            for i, (q, oit, g) in enumerate([(0, 0, 1.0), (0.5, 0, 0.55), (1.0, 0, 0.7), (2.0, 0, 0.9), (2.5, 12, 0.5), (3.0, 0, 0.7), (3.5, 0, 0.55)]):
                f.poe(baixo(raiz + oit, f.b * 0.9, 1.6, 900), tb + q * f.b, 0.62 * g, 0, 0.2, "baixo")
        # órgão sombrio a cada 4 compassos, sinos na virada
        if c % 2 == 0:
            f.poe(orgao(raiz + 12, 2 * dur * 0.9, 0.8, 2.0), t0, 0.42, -0.2, 0.7, "orgao")
            f.poe(orgao(raiz + 19 if tipo == "m" else raiz + 16, 2 * dur * 0.9, 0.8, 2.0), t0, 0.28, 0.3, 0.7, "orgao")
        grau = int(f.rng.integers(3, 7))
        for q in range(2):
            grau = int(np.clip(grau + f.rng.choice([-2, -1, 1, 2]), 1, 9))
            f.poe(sino(escala(52, FRIGIO, grau), 8.0, 0.7), t0 + f.cs * (0.5 + 0.9 * q) + float(f.rng.uniform(0, 0.3)), 0.5,
                  float(f.rng.uniform(-0.6, 0.6)), 0.9, "sino")
    # percussão: taiko no 1 e no 3, tom surdo no 2.5, preenchimento a cada 4 compassos
    for c in range(f.compassos):
        t0 = c * f.cs
        f.poe(tambor(61.7, 1.5, 0.42), t0, 1.0, -0.1, 0.45, "tambor")
        f.poe(tambor(61.7, 1.5, 0.42), t0 + 2 * f.b, 0.85, 0.1, 0.45, "tambor")
        f.poe(tambor(82.4, 0.9, 0.3), t0 + 2.5 * f.b, 0.5, 0.3, 0.5, "tambor")
        if c % 2 == 1:
            f.poe(tambor(82.4, 0.9, 0.3), t0 + 3.5 * f.b, 0.55, -0.3, 0.5, "tambor")
        if c % 4 == 3:
            for q in range(4):
                f.poe(tambor(95 - 6 * q, 0.7, 0.2), t0 + (3 + q * 0.25) * f.b, 0.55 + 0.1 * q, 0.4 - 0.25 * q, 0.5, "tambor")
    f.poe(rumor(f.N / SR, 70, 5), 0, 0.4, 0, 0.1, "rumor")
    return f, dict(rev_t=3.2, rev_mix=0.5, corte=3400, rms_alvo=-20.5)


def faixa_chefe():
    """chefe: tambor insistente, metais graves em cromatismo, coro em cluster dissonante (2ª menor e trítono)"""
    f = Faixa("chefe", 92, 28, 3)
    raiz0 = 42   # F#2
    prog = [(0, "m"), (1, "M"), (0, "cl"), (-2, "M"), (0, "m"), (-4, "M"), (1, "cl"), (0, "m")]  # F#m, G, F#(b2 trítono), E ...
    barras_por_acorde = 3.5
    for c in range(8):
        d, tipo = prog[c]
        t0 = c * barras_por_acorde * f.cs
        raiz = raiz0 + d
        dur = barras_por_acorde * f.cs
        f.poe(drone(raiz - 12, dur + 2.5, 800, (-12, 0, 11)), t0 - 0.3, 0.9, 0, 0.2, "drone")
        notas = acorde(raiz + 12, tipo) + [raiz + 13, raiz + 18]   # + segunda menor e trítono acima da tônica
        for k, nn in enumerate(notas):
            f.poe(coro(nn, dur + 1.5, "a" if k % 2 else "o", 4, 0.6, 1.5, 1.0), t0 + 0.04 * k, 0.4, (-0.7, 0.7, 0, -0.3, 0.4)[k], 0.6, "coro")
        f.poe(orgao(raiz, dur, 0.4, 1.2), t0, 0.35, 0, 0.6, "orgao")
    # metais: motivo cromático curto (tônica, b2, tônica, trítono) a cada 2 compassos
    motivo = [(0, 0), (1.5, 1), (2.0, 0), (3.0, 6)]
    for c in range(0, f.compassos, 2):
        d, _ = prog[min(int(c / barras_por_acorde), 7)]
        for q, (pos, iv) in enumerate(motivo):
            f.poe(metal(raiz0 + d + iv, f.b * (1.1 if q != 3 else 2.2)), c * f.cs + pos * f.b, 0.7, (-0.3, 0.3)[q % 2], 0.4, "metal")
    # percussão: batida de marcha pesada, colcheias de taiko
    for c in range(f.compassos):
        t0 = c * f.cs
        for q, g in [(0, 1.0), (0.5, 0.45), (1.5, 0.6), (2, 0.95), (2.5, 0.5), (3.5, 0.65)]:
            f.poe(tambor(69.3 if q == 1.5 else 46.25, 1.2, 0.34), t0 + q * f.b, g * 0.95, 0.0, 0.4, "tambor")
        f.poe(caixa(), t0 + 1 * f.b, 0.5, -0.2, 0.4, "caixa")
        f.poe(caixa(), t0 + 3 * f.b, 0.55, 0.2, 0.4, "caixa")
        if c % 4 == 3:   # rufar de caixa na virada
            for q in range(8):
                f.poe(caixa(0.3), t0 + 2 * f.b + q * 0.25 * f.b, 0.15 + 0.07 * q, 0.2 * (-1) ** q, 0.4, "caixa")
    # sinos de alarme no trítono, bem espaçados
    for c in range(0, f.compassos, 4):
        f.poe(sino(54, 7.0, 0.8), c * f.cs + 0.0, 0.5, -0.4, 0.8, "sino")
        f.poe(sino(60, 7.0, 0.8), c * f.cs + 2 * f.b, 0.4, 0.4, 0.8, "sino")
    f.poe(rumor(f.N / SR, 80, 8), 0, 0.5, 0, 0.1, "rumor")
    return f, dict(rev_t=2.8, rev_mix=0.45, corte=3600, rms_alvo=-19.5)


def faixa_duelo():
    """duelo PvP: marcha de guerra, A dórico, ostinato de órgão/pluck e coro curto"""
    f = Faixa("duelo", 88, 28, 4)
    prog = [(45, "m"), (45, "m"), (50, "M"), (45, "m"), (43, "M"), (50, "M"), (48, "M"), (45, "m")]   # Am Am D Am G D C Am
    barras = f.compassos / 8
    for c, (raiz, tipo) in enumerate(prog):
        t0 = c * barras * f.cs
        dur = barras * f.cs
        f.poe(drone(raiz - 12, dur + 2, 700), t0 - 0.2, 0.8, 0, 0.2, "drone")
        for k, nn in enumerate(acorde(raiz + 12, tipo)):
            f.poe(coro(nn, dur + 1.5, "o", 3, 0.5, 1.2), t0 + 0.03 * k, 0.4, (-0.5, 0.5, 0)[k], 0.5, "coro")
        # ostinato pulsante em colcheias
        for bar in range(int(barras)):
            for q in range(8):
                nn = raiz + [0, 0, 12, 0, 7, 0, 12, 10][q] - (0 if tipo == "m" else 0)
                f.poe(baixo(nn, f.b * 0.45, 3.0, 1100), t0 + bar * f.cs + q * f.b / 2, 0.55 * (1.0 if q % 4 == 0 else 0.6), 0, 0.2, "baixo")
        # melodia de órgão lenta por cima
        g0 = int(f.rng.integers(5, 9))
        for q in range(3):
            g0 = int(np.clip(g0 + f.rng.choice([-2, -1, 1, 2]), 3, 11))
            f.poe(orgao(escala(57, DORICO, g0), f.b * 2.2, 0.15, 0.4), t0 + f.cs * (0.25 + 0.95 * q), 0.4, 0.2, 0.6, "orgao")
        if c % 2 == 0:
            f.poe(sino(escala(57, DORICO, int(f.rng.integers(6, 11))), 7.0, 0.8), t0 + f.cs, 0.5, float(f.rng.uniform(-0.6, 0.6)), 0.9, "sino")
    for c in range(f.compassos):
        t0 = c * f.cs
        f.poe(tambor(55, 1.3, 0.36), t0, 1.0, 0, 0.4, "tambor")
        f.poe(tambor(55, 1.3, 0.36), t0 + 2 * f.b, 0.9, 0, 0.4, "tambor")
        f.poe(tambor(82.4, 0.8, 0.26), t0 + 1.5 * f.b, 0.5, 0.3, 0.4, "tambor")
        f.poe(caixa(0.4, 190, 2400), t0 + f.b, 0.5, -0.2, 0.4, "caixa")
        f.poe(caixa(0.4, 190, 2400), t0 + 3 * f.b, 0.55, 0.2, 0.4, "caixa")
        if c % 4 == 3:
            f.poe(tambor(70, 0.8, 0.26), t0 + 3.5 * f.b, 0.7, -0.3, 0.4, "tambor")
            f.poe(tambor(64, 0.8, 0.26), t0 + 3.75 * f.b, 0.8, 0.3, 0.4, "tambor")
    f.poe(rumor(f.N / SR, 70, 6), 0, 0.35, 0, 0.1, "rumor")
    return f, dict(rev_t=2.6, rev_mix=0.45, corte=3600, rms_alvo=-20.0)


def faixa_fim():
    """fim/resultado: lamento, G eólio, 40 bpm; coro, cello longo, um sino de finados por compasso"""
    f = Faixa("fim", 40, 12, 5)
    prog = [(43, "m", "o"), (39, "M", "u"), (36, "m", "o"), (38, "M", "a")]   # Gm Eb Cm D
    for c, (raiz, tipo, vog) in enumerate(prog):
        t0 = c * 3 * f.cs
        dur = 3 * f.cs
        f.poe(drone(raiz - 12, dur + 3, 500), t0 - 0.4, 0.85, 0, 0.25, "drone")
        for k, nn in enumerate(acorde(raiz + 12, tipo) + [raiz + 19]):
            f.poe(coro(nn, dur + 2.5, vog, 4, 1.8, 2.2), t0 + 0.25 * k, 0.55, (-0.7, 0.0, 0.7, 0.3)[k], 0.8, "coro")
        f.poe(baixo(raiz, dur * 0.95, 0.15, 450), t0, 0.55, 0, 0.5, "baixo")
        f.poe(baixo(raiz + 7, dur * 0.7, 0.15, 450), t0 + 0.5 * f.cs, 0.3, 0.3, 0.5, "baixo")
    for c in range(f.compassos):
        f.poe(sino(43 if c % 4 else 38, 11.0, 0.5, 2.6), c * f.cs, 0.55, -0.2 if c % 2 else 0.2, 0.95, "sino")
        f.poe(tambor(49, 1.8, 0.7, 0.1), c * f.cs + 2 * f.b, 0.4, 0, 0.8, "tambor")
    for q in range(3):
        f.poe(sussurro(10.0, 40 + q), q * f.N / SR / 3 + 2, 0.4, float(f.rng.uniform(-0.8, 0.8)), 1.0, "sussurro")
    f.poe(rumor(f.N / SR, 50, 7), 0, 0.3, 0, 0.1, "rumor")
    return f, dict(rev_t=6.0, rev_mix=0.65, corte=2600, rms_alvo=-22.5)


def faixa_horror():
    """fase de horror: quase sem melodia; drone com trítono batendo, sussurros, coração, sinos raros"""
    f = Faixa("horror", 60, 16, 6)
    total = f.N / SR
    f.poe(drone(26, total + 5, 420, (-20, 0, 18)), -2.5, 0.85, 0, 0.25, "drone")
    f.poe(drone(32, total + 5, 420, (-25, 3, 21)), -2.5, 0.55, 0.2, 0.25, "drone")        # trítono batendo contra o ré
    f.poe(orgao(38, total + 4, 6.0, 6.0), -2.0, 0.18, 0, 0.8, "orgao")
    f.poe(rumor(total, 45, 9), 0, 0.5, 0, 0.1, "rumor")
    # coração fraco ("tum-tum") a cada ~1,28 s; 50 batidas cabem no laço de 64 s
    per = total / 50
    for i in range(50):
        g = 0.55 + 0.1 * np.sin(i * 0.31)
        f.poe(tambor(51.9, 0.9, 0.22, 0.1), i * per, g * 0.8, 0, 0.5, "coracao")
        f.poe(tambor(49, 0.8, 0.18, 0.1), i * per + 0.26, g * 0.45, 0, 0.5, "coracao")
    # sussurros: camadas longas, cada uma num canto
    for i in range(7):
        f.poe(sussurro(float(f.rng.uniform(5, 9)), 60 + i), float(f.rng.uniform(0, total)), 0.5, float(f.rng.uniform(-1, 1)), 1.0, "sussurro")
    # clusters de coro muito lentos (2ª menor), só duas vezes, e sinos raros baixos
    for tt, nn in [(6.0, 50), (38.0, 49)]:
        for k, d in enumerate([0, 1, 6]):
            f.poe(coro(nn + d, 14.0, "u", 3, 5.0, 6.0, 1.5), tt + k * 0.7, 0.3, (-0.6, 0.6, 0)[k], 1.0, "coro")
    for tt, nn in [(17.0, 45), (29.5, 51), (47.0, 45), (58.0, 40)]:
        f.poe(sino(nn, 12.0, 0.4, 2.8), tt, 0.5, float(f.rng.uniform(-0.6, 0.6)), 1.0, "sino")
    return f, dict(rev_t=6.5, rev_mix=0.75, corte=2300, rms_alvo=-24.0, escuro=0.3)


FAIXAS = {"menu": faixa_menu, "minijogo_tenso": faixa_fase, "chefe": faixa_chefe, "minijogo_retro": faixa_duelo,
          "fim": faixa_fim, "horror": faixa_horror}


def gerar(nome):
    f, cfg = FAIXAS[nome]()
    x = f.masterizar(**cfg)
    tmp = os.path.join(SAIDA, nome + "_tmp.wav")
    sf.write(tmp, x.T.astype(np.float32), SR, subtype="FLOAT")
    destino = os.path.join(SAIDA, nome + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "2", destino], check=True)
    os.remove(tmp)
    print(nome, f"{f.N / SR:.1f}s", f"{f.bpm:.1f}bpm", "pico", round(20 * np.log10(np.abs(x).max()), 2), "dBFS", f.relatorio())


if __name__ == "__main__":
    os.makedirs(SAIDA, exist_ok=True)
    for n in (sys.argv[1:] or FAIXAS):
        gerar(n)

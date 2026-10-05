"""Gera as músicas (OGG em loop) e os efeitos sonoros (WAV) do JOGO.

Tudo é sintetizado aqui, sem nenhum sample de fora: ondas quadradas, triângulo e
ruído, no estilo dos videogames antigos. Pra mudar uma música, edite MUSICAS e rode
de novo:  python3 gerar_audio.py
Saída: ../projeto/assets/audio/musica/*.ogg e ../projeto/assets/audio/efeitos/*.wav
"""
import os
import random
import subprocess
import wave

import numpy as np

SR = 22050
AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.join(AQUI, "..", "projeto", "assets", "audio")

# ------------------------------------------------------------------ sintetizadores


def freq(nota):
    """nota MIDI -> Hz"""
    return 440.0 * 2 ** ((nota - 69) / 12)


def env(n, a=0.005, d=0.08, s=0.6, r=0.05):
    t = np.arange(n) / SR
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na, endpoint=False) if na else e[:na]
    fim_d = min(na + nd, n)
    if fim_d > na:
        e[na:fim_d] = np.linspace(1, s, fim_d - na, endpoint=False)
    if nr and n > nr:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def pulso(f, dur, duty=0.5, vib=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    fase = f * t
    if vib:
        fase += vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 3 - 0.3, 0, 1) / (2 * np.pi * 5.5) * f
    return np.where((fase % 1.0) < duty, 1.0, -1.0)


def tri(f, dur):
    n = int(dur * SR)
    fase = (f * np.arange(n) / SR) % 1.0
    return 4 * np.abs(fase - 0.5) - 1


def seno(f, dur):
    return np.sin(2 * np.pi * f * np.arange(int(dur * SR)) / SR)


def ruido(dur, seed=0):
    return np.random.default_rng(seed).uniform(-1, 1, int(dur * SR))


def passa_alta(x, k=0.9):
    y = np.zeros_like(x)
    ant_x = ant_y = 0.0
    for i, v in enumerate(x):
        ant_y = k * (ant_y + v - ant_x)
        ant_x = v
        y[i] = ant_y
    return y


def passa_baixa(x, k=0.2):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


# baterias (pré-calculadas)
def _bumbo():
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    f = 110 * np.exp(-t * 25) + 42
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 18)


def _surdo():
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    f = 80 * np.exp(-t * 10) + 55
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7)


def _caixa():
    n = int(0.14 * SR)
    t = np.arange(n) / SR
    return (ruido(0.14, 3) * 0.8 + seno(190, 0.14) * 0.4) * np.exp(-t * 28)


def _chimbal():
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    return passa_alta(ruido(0.05, 7), 0.6) * np.exp(-t * 90)


def _agogo(alto=True):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    f = 1250 if alto else 940
    return (seno(f, 0.12) + 0.4 * seno(f * 2.76, 0.12)) * np.exp(-t * 30)


BATERIA = {"b": _bumbo(), "s": _surdo(), "c": _caixa(), "h": _chimbal(), "a": _agogo(True), "g": _agogo(False)}

# ------------------------------------------------------------------ composição

ESCALAS = {"maior": [0, 2, 4, 5, 7, 9, 11], "menor": [0, 2, 3, 5, 7, 8, 10], "dorico": [0, 2, 3, 5, 7, 9, 10]}


def acorde(tom, escala, grau):
    """Notas (semitom relativo ao tom) da tríade sobre o grau (0..6) da escala."""
    e = ESCALAS[escala]
    return [e[(grau + k) % 7] + 12 * ((grau + k) // 7) for k in (0, 2, 4)]


def mistura(buf, som, pos, vol):
    i = int(pos * SR)
    if i >= len(buf):
        return
    fim = min(len(buf), i + len(som))
    buf[i:fim] += som[: fim - i] * vol


def compor(c):
    rnd = random.Random(c["semente"])
    bpm = c["bpm"]
    batida = 60.0 / bpm
    compassos = len(c["progressao"]) * c.get("voltas", 2)
    total = compassos * 4 * batida
    buf = np.zeros(int(total * SR) + SR)
    tom = c["tom"]
    escala = c["escala"]
    esc = ESCALAS[escala]

    # motivos rítmicos da melodia (em batidas, somam 4); None = pausa
    ritmos = c.get("ritmos", [
        [1, 0.5, 0.5, 1, 1], [0.5, 0.5, 1, 0.5, 0.5, 1], [1.5, 0.5, 1, 1], [1, 1, 2],
        [0.5, 0.5, 0.5, 0.5, 1, 1], [2, 0.5, 0.5, 1], [0.75, 0.75, 0.5, 1, 1],
    ])
    motivos = [rnd.choice(ritmos) for _ in range(4)]
    forma = c.get("forma", [0, 1, 0, 2, 0, 1, 3, 2])
    graus_melodia = {}

    for v in range(c.get("voltas", 2)):
        for b, grau in enumerate(c["progressao"]):
            idx = v * len(c["progressao"]) + b
            t0 = idx * 4 * batida
            ac = acorde(tom, escala, grau)
            # baixo
            for k, (tb, nb) in enumerate(c["baixo"]):
                nota = tom - 24 + ac[nb % 3] + (12 if nb >= 3 else 0)
                d = batida * c.get("dur_baixo", 0.9)
                s = tri(freq(nota), d) * env(int(d * SR), 0.003, 0.05, 0.8, 0.03)
                mistura(buf, s, t0 + tb * batida, c.get("vol_baixo", 0.32))
            # acompanhamento (acorde quebrado ou batido)
            for tb, k in c["acomp"]:
                nota = tom - 12 + ac[k % 3] + (12 if k >= 3 else 0)
                d = batida * c.get("dur_acomp", 0.45)
                s = pulso(freq(nota), d, c.get("duty_acomp", 0.25)) * env(int(d * SR), 0.003, 0.06, 0.35, 0.03)
                mistura(buf, s, t0 + tb * batida, c.get("vol_acomp", 0.09))
            # bateria
            for tb, peca, vol in c.get("bateria", []):
                mistura(buf, BATERIA[peca], t0 + tb * batida, vol)
            # melodia: o motivo da forma, com notas que caem no acorde nos tempos fortes
            chave = (forma[b % len(forma)], grau)
            if v == 1 and chave in graus_melodia and rnd.random() < 0.75:
                notas = graus_melodia[chave]
            else:
                ritmo = motivos[forma[b % len(forma)]]
                notas = []
                pos = rnd.choice([0, 2, 4])
                for i, dur in enumerate(ritmo):
                    if i > 0 and rnd.random() < 0.12:
                        notas.append((dur, None))
                        continue
                    forte = i == 0 or dur >= 1
                    if forte:
                        alvo = rnd.choice(ac)
                        cands = [k for k in range(-7, 15) if (esc[k % 7] + 12 * (k // 7)) % 12 == alvo % 12]
                        pos = min(cands, key=lambda k: abs(k - pos) + rnd.random())
                    else:
                        pos += rnd.choice([-1, 1, 1, -1, 2, -2])
                    pos = max(-3, min(11, pos))
                    notas.append((dur, pos))
                graus_melodia[chave] = notas
            tm = t0
            for dur, p in notas:
                if p is not None:
                    nota = tom + esc[p % 7] + 12 * (p // 7)
                    d = dur * batida * 0.92
                    s = pulso(freq(nota), d, c.get("duty", 0.5), vib=c.get("vib", 0.004)) * env(int(d * SR), 0.004, 0.08, 0.55, 0.04)
                    mistura(buf, s, tm, c.get("vol_mel", 0.13))
                    if c.get("eco"):
                        mistura(buf, s, tm + batida * 0.75, c.get("vol_mel", 0.13) * 0.35)
                tm += dur * batida
    n = int(total * SR)
    # o que passou do fim volta pro começo, pra emenda do loop ficar perfeita
    resto = buf[n:]
    buf = buf[:n]
    buf[: len(resto)] += resto
    buf = passa_baixa(buf, c.get("brilho", 0.55))
    buf /= max(1e-6, np.max(np.abs(buf))) / 0.8
    return buf


# ------------------------------------------------------------------ as músicas

QUARTOS = [(i * 0.5, "h", 0.18) for i in range(8)]
MUSICAS = {
    "menu": dict(semente=11, bpm=104, tom=72, escala="maior", progressao=[0, 5, 3, 4, 0, 5, 1, 4],
                 baixo=[(0, 0), (1.5, 2), (2, 0), (3, 1)], acomp=[(0.5, 0), (1, 1), (1.5, 2), (2.5, 1), (3, 2), (3.5, 3)],
                 bateria=[(0, "b", .5), (2, "c", .35), (2.5, "b", .35)] + QUARTOS),
    "cairu": dict(semente=4, bpm=96, tom=69, escala="maior", progressao=[0, 3, 4, 0, 5, 3, 1, 4],
                  baixo=[(0, 0), (1, 2), (2, 1), (3, 2)], acomp=[(0, 0), (0.5, 1), (1, 2), (1.5, 3), (2, 0), (2.5, 1), (3, 2), (3.5, 1)],
                  bateria=[(0, "b", .4), (2, "c", .25)] + [(i, "h", .12) for i in range(4)], vol_acomp=0.06, duty=0.25),
    "patio": dict(semente=21, bpm=112, tom=67, escala="maior", progressao=[0, 3, 4, 3, 0, 3, 4, 0],
                  baixo=[(0, 0), (0.75, 0), (1.5, 2), (2, 0), (3, 2), (3.5, 1)],
                  acomp=[(0.5, 0), (1.25, 1), (2.5, 2), (3.25, 1)],
                  # samba-reggae: surdo marcando, caixa repicando e agogô
                  bateria=[(0, "s", .55), (2, "s", .45), (1, "c", .2), (1.75, "c", .15), (3, "c", .2), (3.5, "c", .15),
                           (0, "a", .12), (0.75, "g", .12), (1.5, "a", .12), (2.5, "g", .12), (3, "a", .12)] + QUARTOS,
                  duty=0.5, vol_mel=0.12),
    "sala": dict(semente=33, bpm=72, tom=76, escala="maior", progressao=[0, 5, 3, 4],
                 voltas=3, baixo=[(0, 0), (2, 2)], acomp=[(i * 0.5, [0, 1, 2, 3, 2, 1, 0, 1][i]) for i in range(8)],
                 bateria=[], duty_acomp=0.125, vol_acomp=0.07, duty=0.125, vol_mel=0.1, eco=True, brilho=0.4,
                 ritmos=[[2, 2], [1, 1, 2], [3, 1], [1.5, 0.5, 2]]),
    "lab": dict(semente=8, bpm=124, tom=64, escala="dorico", progressao=[0, 0, 6, 6, 5, 5, 3, 4],
                baixo=[(i * 0.5, 0 if i % 2 == 0 else 3) for i in range(8)],
                acomp=[(i * 0.25, [0, 1, 2, 3][i % 4]) for i in range(16)], dur_acomp=0.22, vol_acomp=0.06,
                bateria=[(0, "b", .45), (1, "c", .25), (2, "b", .45), (2.5, "b", .3), (3, "c", .25)] + [(i * 0.25, "h", .08) for i in range(16)],
                duty=0.25, vol_mel=0.1),
    "presidencia": dict(semente=5, bpm=76, tom=62, escala="menor", progressao=[0, 5, 3, 4, 0, 3, 4, 0],
                        baixo=[(0, 0), (2, 0)], dur_baixo=1.8, acomp=[(0, 0), (0, 1), (0, 2), (2, 0), (2, 1), (2, 2)],
                        dur_acomp=1.8, duty_acomp=0.5, vol_acomp=0.05, bateria=[(0, "s", .35), (3, "c", .12), (3.5, "c", .12)],
                        duty=0.5, vol_mel=0.11, ritmos=[[1.5, 0.5, 2], [1, 1, 1, 1], [3, 1], [2, 1, 1]]),
    "minijogo": dict(semente=17, bpm=148, tom=70, escala="maior", progressao=[0, 4, 5, 3],
                     voltas=4, baixo=[(i * 0.5, 0 if i % 2 == 0 else 3) for i in range(8)],
                     acomp=[(0.5, 0), (1.5, 1), (2.5, 2), (3.5, 1)],
                     bateria=[(0, "b", .5), (1, "c", .3), (2, "b", .5), (3, "c", .3)] + QUARTOS, duty=0.5),
    "fim": dict(semente=2, bpm=92, tom=72, escala="maior", progressao=[0, 3, 4, 0], voltas=2,
                baixo=[(0, 0), (1, 1), (2, 2), (3, 1)], acomp=[(i * 0.5, i % 4) for i in range(8)],
                bateria=[(0, "b", .35), (2, "c", .2)], duty=0.25, eco=True),
    # ---- músicas por lugar e por clima (rodada 2)
    "recepcao": dict(semente=41, bpm=88, tom=67, escala="maior", progressao=[0, 5, 1, 4, 0, 5, 1, 4],
                     # bossa: baixo alternando, violão sincopado
                     baixo=[(0, 0), (1.5, 2), (2, 2), (3.5, 0)],
                     acomp=[(0, 1), (0.75, 2), (1.5, 1), (2.25, 3), (3, 2), (3.5, 1)], dur_acomp=0.3, duty_acomp=0.125,
                     bateria=[(0, "b", .3), (1.5, "b", .2), (2, "b", .3), (3.5, "b", .2)] + [(i * 0.5, "h", .07) for i in range(8)],
                     duty=0.25, vol_mel=0.1, ritmos=[[1.5, 0.5, 1, 1], [1, 0.5, 0.5, 2], [0.5, 1, 0.5, 2], [2, 1, 1]]),
    "nucleo": dict(semente=52, bpm=74, tom=62, escala="dorico", progressao=[0, 3, 0, 3, 5, 4, 0, 4],
                   # na manha do Nicão: devagar, acordes longos e eco
                   baixo=[(0, 0), (2.5, 2)], dur_baixo=1.6, acomp=[(0, 0), (0, 1), (0, 2), (2, 1), (2, 2), (2, 3)],
                   dur_acomp=1.7, duty_acomp=0.5, vol_acomp=0.045, bateria=[(0, "b", .3), (2, "c", .14)] + [(i, "h", .06) for i in range(4)],
                   duty=0.125, vol_mel=0.09, eco=True, brilho=0.3, ritmos=[[2, 2], [3, 1], [1, 1, 2], [4]]),
    "corredor": dict(semente=63, bpm=100, tom=65, escala="maior", progressao=[0, 4, 5, 3, 0, 4, 3, 4],
                     baixo=[(0, 0), (1, 1), (2, 2), (3, 1)], acomp=[(0.5, 0), (1.5, 1), (2.5, 2), (3.5, 1)],
                     bateria=[(0, "b", .35), (2, "c", .2), (3.5, "b", .2)] + [(i, "h", .1) for i in range(4)], duty=0.5, vol_mel=0.11),
    "cap2": dict(semente=74, bpm=116, tom=69, escala="maior", progressao=[0, 3, 0, 4, 5, 3, 4, 0],
                 # axé: surdo no 1 e no 3, agogô e caixa repicada
                 baixo=[(0, 0), (0.75, 2), (1.5, 0), (2, 1), (3, 2)], acomp=[(0.5, 0), (1, 1), (1.5, 2), (2.5, 1), (3, 2), (3.5, 0)],
                 bateria=[(0, "s", .5), (2, "s", .4), (0.5, "c", .15), (1.5, "c", .2), (2.5, "c", .15), (3.5, "c", .2),
                          (0, "a", .1), (1, "g", .1), (2, "a", .1), (3, "g", .1)] + QUARTOS, duty=0.5, vol_mel=0.11),
    "festa": dict(semente=85, bpm=126, tom=72, escala="maior", progressao=[0, 4, 5, 3, 0, 4, 3, 4],
                  baixo=[(i * 0.5, 0 if i % 2 == 0 else 3) for i in range(8)], acomp=[(i * 0.5, i % 4) for i in range(8)],
                  bateria=[(0, "s", .5), (2, "s", .5), (1, "c", .3), (3, "c", .3), (0.5, "a", .1), (1.5, "g", .1), (2.5, "a", .1), (3.5, "g", .1)] + QUARTOS,
                  duty=0.5, vol_mel=0.12, eco=True),
    "minijogo_tenso": dict(semente=96, bpm=160, tom=64, escala="menor", progressao=[0, 5, 6, 4],
                           voltas=4, baixo=[(i * 0.5, 0) for i in range(8)], acomp=[(i * 0.25, [0, 1, 2, 1][i % 4]) for i in range(16)],
                           dur_acomp=0.2, vol_acomp=0.05, bateria=[(0, "b", .5), (1, "c", .3), (2, "b", .5), (2.5, "b", .3), (3, "c", .3)] + [(i * 0.25, "h", .07) for i in range(16)],
                           duty=0.25),
    "minijogo_retro": dict(semente=107, bpm=140, tom=72, escala="menor", progressao=[0, 0, 5, 6],
                           voltas=4, baixo=[(i * 0.5, 0 if i % 2 == 0 else 3) for i in range(8)],
                           acomp=[(i * 0.125, [0, 1, 2, 3][i % 4]) for i in range(32)], dur_acomp=0.12, duty_acomp=0.5, vol_acomp=0.05,
                           bateria=[(0, "b", .45), (1, "c", .3), (2, "b", .45), (3, "c", .3)], duty=0.125, vol_mel=0.12),
}

# ------------------------------------------------------------------ efeitos


def sfx():
    e = {}
    t = lambda d: np.arange(int(d * SR)) / SR
    e["blip"] = pulso(880, 0.035, 0.5) * env(int(0.035 * SR), 0.001, 0.01, 0.6, 0.01) * 0.35
    e["cursor"] = pulso(1320, 0.04, 0.25) * env(int(0.04 * SR), 0.001, 0.02, 0.4, 0.01) * 0.4
    e["confirmar"] = np.concatenate([pulso(988, 0.05, 0.5), pulso(1480, 0.08, 0.5)]) * 0.35
    e["confirmar"] *= env(len(e["confirmar"]), 0.001, 0.05, 0.6, 0.03)
    e["abrir"] = np.concatenate([pulso(660, 0.04, 0.25), pulso(880, 0.06, 0.25)]) * 0.3
    e["fechar"] = np.concatenate([pulso(880, 0.04, 0.25), pulso(660, 0.06, 0.25)]) * 0.3
    n = int(0.06 * SR)
    e["passo"] = passa_baixa(ruido(0.06, 9), 0.35) * np.exp(-t(0.06) * 60) * 0.5
    d = 0.35
    porta = passa_baixa(ruido(d, 5), 0.15) * np.exp(-t(d) * 12) * 0.9 + seno(90, d) * np.exp(-t(d) * 14) * 0.6
    e["porta"] = porta * 0.6
    d = 0.9
    e["tremor"] = passa_baixa(ruido(d, 11), 0.05) * 3.0 * env(int(d * SR), 0.05, 0.2, 0.7, 0.3)
    e["acerto"] = np.concatenate([pulso(1047, 0.06, 0.5), pulso(1568, 0.1, 0.5)]) * 0.3
    e["acerto"] *= env(len(e["acerto"]), 0.001, 0.05, 0.6, 0.04)
    e["erro"] = np.concatenate([pulso(220, 0.09, 0.5), pulso(165, 0.16, 0.5)]) * 0.3
    e["erro"] *= env(len(e["erro"]), 0.001, 0.05, 0.7, 0.06)
    jingle = [72, 76, 79, 84, 79, 84]
    durs = [0.09, 0.09, 0.09, 0.2, 0.09, 0.4]
    e["vitoria"] = np.concatenate([pulso(freq(n), d, 0.5) * env(int(d * SR), 0.002, 0.04, 0.7, 0.02) for n, d in zip(jingle, durs)]) * 0.3
    triste = [67, 66, 65, 64]
    durs = [0.18, 0.18, 0.18, 0.5]
    e["derrota"] = np.concatenate([pulso(freq(n), d, 0.5, vib=0.01) * env(int(d * SR), 0.002, 0.04, 0.7, 0.04) for n, d in zip(triste, durs)]) * 0.3
    # ---- animações (porta, briga, queda)
    d = 0.55
    tt = t(d)
    f = 180 + 140 * np.sin(tt * 9) + 60 * tt
    rangido = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * (0.5 + 0.5 * np.sin(tt * 47))
    e["porta_abrir"] = (passa_baixa(rangido, 0.25) * 0.5 + passa_baixa(ruido(d, 21), 0.1) * 0.6) * env(int(d * SR), 0.03, 0.2, 0.6, 0.15) * 0.45
    d = 0.3
    e["porta_fechar"] = (passa_baixa(ruido(d, 22), 0.12) * np.exp(-t(d) * 18) * 1.4 + seno(70, d) * np.exp(-t(d) * 16) * 0.7) * 0.6
    d = 0.18
    e["soco"] = (passa_baixa(ruido(d, 23), 0.3) * np.exp(-t(d) * 30) * 1.2
                 + np.sin(2 * np.pi * np.cumsum(np.linspace(220, 60, int(d * SR))) / SR) * np.exp(-t(d) * 22) * 0.8) * 0.55
    d = 0.5
    e["queda"] = (passa_baixa(ruido(d, 24), 0.06) * np.exp(-t(d) * 9) * 2.2
                  + np.sin(2 * np.pi * np.cumsum(np.linspace(120, 40, int(d * SR))) / SR) * np.exp(-t(d) * 10) * 0.8) * 0.55
    d = 0.25
    e["whoosh"] = passa_alta(ruido(d, 25), 0.6) * np.sin(np.linspace(0, np.pi, int(d * SR))) ** 2 * 0.35
    d = 0.22
    e["pulo"] = np.sign(np.sin(2 * np.pi * np.cumsum(np.linspace(300, 700, int(d * SR))) / SR)) * env(int(d * SR), 0.002, 0.05, 0.5, 0.08) * 0.22
    d = 0.4
    e["plim"] = (pulso(freq(88), 0.08, 0.5).tolist() + pulso(freq(93), d - 0.08, 0.5).tolist())
    e["plim"] = np.array(e["plim"]) * env(int(d * SR), 0.001, 0.05, 0.5, 0.25) * 0.2
    for nome, nota in [("cima", 76), ("direita", 79), ("baixo", 72), ("esquerda", 74)]:
        d = 0.25
        e["nota_" + nome] = (pulso(freq(nota), d, 0.5) * 0.6 + tri(freq(nota), d) * 0.4) * env(int(d * SR), 0.002, 0.05, 0.6, 0.08) * 0.35
    # "KIKIUU!": o grito do Breno quando acontece algo muito foda (ki, ki, uuuu)
    def varre(f0, f1, d, vib=0.0, duty=0.5):
        tt = t(d)
        fr = np.linspace(f0, f1, len(tt)) * (1 + vib * np.sin(2 * np.pi * 7 * tt))
        fase = np.cumsum(fr) / SR
        return np.where((fase % 1.0) < duty, 1.0, -1.0)
    ki = varre(1300, 1900, 0.07, duty=0.35) * env(int(0.07 * SR), 0.002, 0.03, 0.7, 0.02)
    gap = np.zeros(int(0.035 * SR))
    uu1 = varre(1500, 2300, 0.18, vib=0.02, duty=0.4)
    uu2 = varre(2300, 1500, 0.42, vib=0.035, duty=0.4)
    uu = np.concatenate([uu1, uu2]) * env(int(0.6 * SR), 0.01, 0.1, 0.8, 0.2)
    e["kikiuu"] = passa_baixa(np.concatenate([ki, gap, ki, gap, uu]), 0.6) * 0.45
    return e


# ------------------------------------------------------------------ gravar


def gravar_wav(caminho, x):
    x = np.clip(x, -1, 1)
    dados = (x * 32767).astype("<i2").tobytes()
    with wave.open(caminho, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dados)


def main():
    pm = os.path.join(SAIDA, "musica")
    pe = os.path.join(SAIDA, "efeitos")
    os.makedirs(pm, exist_ok=True)
    os.makedirs(pe, exist_ok=True)
    for nome, x in sfx().items():
        gravar_wav(os.path.join(pe, nome + ".wav"), x)
    for nome, c in MUSICAS.items():
        x = compor(c)
        tmp = os.path.join(pm, nome + "_tmp.wav")
        gravar_wav(tmp, x)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                        os.path.join(pm, nome + ".ogg")], check=True)
        os.remove(tmp)
        print(nome, round(len(x) / SR, 1), "s")


if __name__ == "__main__":
    main()

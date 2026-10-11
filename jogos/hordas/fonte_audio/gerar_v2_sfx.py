"""Gera os efeitos do COMBATE da v2 (WAV, 22050 Hz, mono) em projeto/assets/audio/v2/.

Tudo é sintetizado, sem sample de fora. Reaproveita os sintetizadores do gerador do jogo (jogos/cairu/fonte_audio/gerar_audio.py: pulso,
tri, seno, ruido, filtros e envelope), importando-o sem alterar. Para mudar um som, edite sfx_v2() e rode:  python3 gerar_v2_sfx.py
"""
import importlib.util
import os

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
ORIGEM = os.path.join(AQUI, "..", "..", "cairu", "fonte_audio", "gerar_audio.py")
SAIDA = os.path.join(AQUI, "..", "projeto", "assets", "audio", "v2")

_spec = importlib.util.spec_from_file_location("gerar_audio_base", ORIGEM)
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)
SR = base.SR


def t(d):
    return np.arange(int(d * SR)) / SR


def varre(f0, f1, d, onda="seno"):
    """Onda cuja frequência vai de f0 a f1 (Hz) em d segundos."""
    fase = np.cumsum(np.linspace(f0, f1, int(d * SR))) / SR
    if onda == "quad":
        return np.where((fase % 1.0) < 0.5, 1.0, -1.0)
    if onda == "serra":
        return 2 * (fase % 1.0) - 1
    return np.sin(2 * np.pi * fase)


def corte(d, seed, f_ini, f_fim, ganho):
    """Assobio de lâmina: ruído agudo com envelope de ataque rápido e uma varredura fina."""
    n = int(d * SR)
    ru = base.passa_alta(base.ruido(d, seed), 0.55)
    sw = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    return (ru * 0.55 + varre(f_ini, f_fim, d) * 0.18) * sw * ganho


def sfx_v2():
    e = {}
    e["corte1"] = corte(0.16, 31, 1800, 700, 0.9)
    e["corte2"] = corte(0.16, 32, 2200, 900, 0.9)
    d = 0.24
    e["estocada"] = (corte(d, 33, 1100, 260, 1.0) + varre(150, 55, d) * np.exp(-t(d) * 14) * 0.7) * 0.9
    d = 0.14
    e["impacto"] = (base.passa_baixa(base.ruido(d, 41), 0.35) * np.exp(-t(d) * 38) * 1.3 + varre(190, 55, d) * np.exp(-t(d) * 26) * 0.9) * 0.6
    d = 0.38
    anel = base.pulso(1760, d, 0.25) * np.exp(-t(d) * 12) * 0.22 + varre(2600, 1500, d) * np.exp(-t(d) * 9) * 0.25
    e["critico"] = (np.pad(e["impacto"], (0, int(d * SR) - len(e["impacto"]))) * 1.2 + anel) * 0.8
    d = 0.34
    estalo = base.ruido(d, 44) * (np.random.default_rng(5).uniform(0, 1, int(d * SR)) > 0.9) * np.exp(-t(d) * 14) * 0.4
    e["morte"] = (base.passa_baixa(base.ruido(d, 43), 0.18) * np.exp(-t(d) * 11) * 1.4 + varre(320, 70, d, "quad") * np.exp(-t(d) * 12) * 0.28 + estalo) * 0.6
    d = 0.32
    e["dano_heroi"] = (varre(210, 60, d, "serra") * np.exp(-t(d) * 9) * 0.5 + base.passa_baixa(base.ruido(d, 45), 0.12) * np.exp(-t(d) * 16) * 1.3) * 0.7
    d = 0.26
    e["esquiva"] = base.passa_alta(base.ruido(d, 46), 0.45) * np.sin(np.linspace(0, np.pi, int(d * SR))) ** 2 * 0.42
    d = 0.1
    e["orbe"] = (base.seno(1568, d) * 0.6 + base.pulso(3136, d, 0.25) * 0.15) * base.env(int(d * SR), 0.001, 0.03, 0.4, 0.06) * 0.42
    notas = [72, 76, 79, 84, 88]
    partes = [base.pulso(base.freq(n), 0.075, 0.5) * base.env(int(0.075 * SR), 0.002, 0.03, 0.7, 0.02) for n in notas]
    fim = (base.pulso(base.freq(91), 0.45, 0.5) * 0.6 + base.tri(base.freq(79), 0.45) * 0.5) * base.env(int(0.45 * SR), 0.002, 0.08, 0.6, 0.3)
    e["nivel"] = np.concatenate(partes + [fim]) * 0.3
    d = 0.9
    e["onda"] = (base.tri(98, d) * 0.7 + base.tri(147, d) * 0.5 + base.pulso(49, d, 0.5) * 0.18) * base.env(int(d * SR), 0.08, 0.2, 0.8, 0.45) * 0.55
    triste = [67, 64, 60, 55]
    durs = [0.2, 0.2, 0.25, 0.8]
    e["derrota"] = np.concatenate([base.tri(base.freq(n), q) * base.env(int(q * SR), 0.004, 0.06, 0.7, 0.08) for n, q in zip(triste, durs)]) * 0.55
    d = 0.38
    e["ofego"] = base.passa_baixa(base.passa_alta(base.ruido(d, 47), 0.7), 0.5) * np.sin(np.linspace(0, np.pi, int(d * SR))) ** 2 * 1.1
    e["carta"] = base.pulso(1175, 0.05, 0.25) * base.env(int(0.05 * SR), 0.001, 0.02, 0.5, 0.02) * 0.35
    e["escolher"] = np.concatenate([base.pulso(784, 0.05, 0.5), base.pulso(1175, 0.07, 0.5), base.pulso(1568, 0.1, 0.5)]) * 0.3
    e["escolher"] *= base.env(len(e["escolher"]), 0.001, 0.05, 0.7, 0.05)
    return e


def main():
    os.makedirs(SAIDA, exist_ok=True)
    for nome, x in sfx_v2().items():
        base.gravar_wav(os.path.join(SAIDA, nome + ".wav"), x)
        print(nome, round(len(x) / SR, 2), "s", "pico", round(float(np.max(np.abs(x))), 2))


if __name__ == "__main__":
    main()

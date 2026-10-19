# Sintetiza os sons do Vornak (v3) por script, sem nenhum arquivo de terceiros.
# Saída: WAV mono, 16 bits, 22050 Hz em v3/godot/assets/audio/vornak/.
# Rodar: uv run --python 3.12 --with numpy python -I docs/v3/chefes/sintetizar_sons_vornak.py
import os
import wave

import numpy as np

SR = 22050
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SAIDA = os.path.join(RAIZ, "v3", "godot", "assets", "audio", "vornak")
rng = np.random.default_rng(1977)  # semente fixa: o mesmo script gera sempre os mesmos arquivos


def t_de(seg):
    return np.arange(int(SR * seg)) / SR


def ruido(seg):
    return rng.standard_normal(int(SR * seg))


def passa_baixa(x, corte_hz):
    """Passa-baixa de 1 polo (corte fixo ou um valor por amostra)."""
    corte = np.broadcast_to(np.asarray(corte_hz, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * corte / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def passa_baixa2(x, corte_hz):
    return passa_baixa(passa_baixa(x, corte_hz), corte_hz)


def passa_alta(x, corte_hz):
    return x - passa_baixa(x, corte_hz)


def eco(x, atraso_s, ganho, repeticoes):
    n = int(SR * atraso_s)
    y = np.concatenate([x, np.zeros(n * repeticoes)])
    for k in range(1, repeticoes + 1):
        y[k * n:k * n + len(x)] += x * (ganho ** k)
    return y


def env_impacto(seg, ataque=0.004, queda=0.12):
    t = t_de(seg)
    return np.minimum(1.0, t / ataque) * np.exp(-t / queda)


def normalizar(x, pico=0.9):
    x = x - np.mean(x)
    m = np.max(np.abs(x))
    return x * (pico / m) if m > 0 else x


def fade(x, ms_in=3, ms_out=30):
    a, b = int(SR * ms_in / 1000), int(SR * ms_out / 1000)
    x = x.copy()
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b)
    return x


def salvar(nome, x, pico=0.9):
    x = fade(normalizar(x, pico))
    dados = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(SAIDA, exist_ok=True)
    caminho = os.path.join(SAIDA, nome + ".wav")
    with wave.open(caminho, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dados.tobytes())
    print(f"{nome}.wav  {len(x) / SR:.2f} s  pico {np.max(np.abs(x)):.2f}")


# passo: impacto grave (senoide caindo de 90 para 45 Hz) + ruído de terra filtrado, eco curto
def passo():
    seg = 0.45
    t = t_de(seg)
    f = 45 + 45 * np.exp(-t / 0.05)
    grave = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_impacto(seg, 0.003, 0.09)
    terra = passa_baixa2(ruido(seg), 700) * env_impacto(seg, 0.002, 0.05) * 1.6
    return eco(grave + terra, 0.07, 0.25, 2)


# rugido: senoides graves (55, 82, 110 Hz) com tremor de 7 Hz + ruído rouco, eco de floresta
def rugido():
    seg = 2.2
    t = t_de(seg)
    env = np.minimum(1, t / 0.35) * np.clip((seg - t) / 0.9, 0, 1)
    tremor = 1 + 0.35 * np.sin(2 * np.pi * 7 * t) * np.clip((t - 0.5) / 0.4, 0, 1)
    desvio = 1 + 0.02 * np.sin(2 * np.pi * 2.3 * t)
    tons = sum(a * np.sin(2 * np.pi * np.cumsum(np.full_like(t, f) * desvio) / SR) for f, a in [(55, 1.0), (82, 0.6), (110, 0.45), (165, 0.2)])
    rouco = passa_baixa2(ruido(seg), 380) * 2.4
    x = (tons + rouco * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t))) * env * tremor
    return eco(x, 0.23, 0.35, 4)


# estalo de madeira: ruído passa-alta com queda curtíssima + "toc" de 420 Hz
def estalo_madeira():
    seg = 0.3
    t = t_de(seg)
    clique = passa_alta(ruido(seg), 1500) * env_impacto(seg, 0.0005, 0.012)
    toc = np.sin(2 * np.pi * 420 * t) * env_impacto(seg, 0.001, 0.03) * 0.5
    rachado = passa_baixa(passa_alta(ruido(seg), 600), 3000) * env_impacto(seg, 0.002, 0.06) * 0.4
    return clique + toc + rachado


# terra rachando: ruído grave com envelope longo e crepitar de estalos aleatórios
def terra_rachando():
    seg = 1.4
    t = t_de(seg)
    env = np.minimum(1, t / 0.08) * np.exp(-t / 0.55)
    ronco = passa_baixa2(ruido(seg), 250) * 3.0
    crepitar = np.zeros_like(t)
    for _ in range(26):
        i = int(rng.uniform(0, 0.9) * SR)
        n = int(0.02 * SR)
        crepitar[i:i + n] += passa_alta(rng.standard_normal(n), 900) * np.exp(-np.arange(n) / (0.004 * SR)) * rng.uniform(0.4, 1.0)
    return (ronco + crepitar * 0.8) * env


# zumbido verde de energia: senoide de 180 Hz (+ harmônico) com pulsação de 6 Hz
def zumbido_energia():
    seg = 1.0
    t = t_de(seg)
    pulso = 0.55 + 0.45 * np.sin(2 * np.pi * 6 * t)
    x = np.sin(2 * np.pi * 180 * t) + 0.35 * np.sin(2 * np.pi * 360 * t + 0.4) + 0.12 * np.sin(2 * np.pi * 543 * t)
    env = np.minimum(1, t / 0.06) * np.clip((seg - t) / 0.35, 0, 1)
    return x * pulso * env


# golpe no chão: pancada grave (70 -> 35 Hz) com ruído, cauda de eco
def golpe_chao():
    seg = 0.9
    t = t_de(seg)
    f = 35 + 50 * np.exp(-t / 0.06)
    grave = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_impacto(seg, 0.002, 0.22)
    estouro = passa_baixa(ruido(seg), 1800) * env_impacto(seg, 0.001, 0.04) * 1.2
    poeira = passa_baixa2(ruido(seg), 400) * env_impacto(seg, 0.01, 0.3) * 1.5
    return eco(grave * 1.3 + estouro + poeira, 0.12, 0.3, 3)


# sucção da absorção: ruído com passa-baixa cujo corte sobe (200 -> 2600 Hz) e volume crescente, corte seco no fim
def succao_absorcao():
    seg = 1.3
    t = t_de(seg)
    corte = 200 + 2400 * (t / seg) ** 2
    x = passa_baixa2(ruido(seg), corte) * 2.0
    env = (t / seg) ** 1.5 * np.clip((seg - t) / 0.06, 0, 1)
    sopro = np.sin(2 * np.pi * np.cumsum(90 + 120 * t / seg) / SR) * 0.25
    return (x + sopro) * env


if __name__ == "__main__":
    salvar("passo", passo(), 0.8)
    salvar("rugido", rugido(), 0.95)
    salvar("estalo_madeira", estalo_madeira(), 0.8)
    salvar("terra_rachando", terra_rachando(), 0.85)
    salvar("zumbido_energia", zumbido_energia(), 0.6)
    salvar("golpe_chao", golpe_chao(), 0.95)
    salvar("succao_absorcao", succao_absorcao(), 0.75)

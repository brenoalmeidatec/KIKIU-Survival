"""Prepara as músicas de licença aberta (Kevin MacLeod / incompetech.com, CC BY 4.0) pro jogo.
Entrada: MP3 baixados de https://incompetech.com/music/royalty-free/mp3-royaltyfree/<Titulo>.mp3 numa pasta.
Saída: OGG Vorbis estéreo 44,1 kHz (q4) em assets/audio/musica/, com:
  - corte (início/duração) e laço sem estalo (o fim se funde no começo por crossfade de potência igual),
  - ganho até um RMS alvo, com limitador suave nos picos que passam de -1,5 dBFS.
Uso: python preparar_musica_cc.py <pasta_mp3> <pasta_saida_ogg> [faixa ...]   (precisa de ffmpeg e numpy)
Os detalhes de cada faixa estão em docs/LICENCAS_AUDIO.md."""
import subprocess
import sys

import numpy as np

SR = 44100
# arquivo do jogo: (mp3, início s, duração s, crossfade s, RMS alvo dBFS)
FAIXAS = {
    "menu": ("Oppressive Gloom", 0, 185, 4, -21),
    "minijogo_tenso": ("Crypto", 0, 190, 4, -21),
    "minijogo_tenso_b": ("Giant Wyrm", 0, 185, 4, -21),
    "chefe": ("Ignosi", 0, 180, 3, -19),
    "minijogo_retro": ("Crusade", 0, 185, 4, -20),
    "fim": ("Wounded", 0, 185, 4, -21),
    "horror": ("Long Note Four", 120, 150, 6, -24),
}


def ler(caminho, ini, dur):
    r = subprocess.run(["ffmpeg", "-v", "error", "-ss", str(ini), "-t", str(dur), "-i", caminho, "-f", "f32le",
                        "-ac", "2", "-ar", str(SR), "-"], capture_output=True, check=True)
    return np.frombuffer(r.stdout, np.float32).reshape(-1, 2).copy()


def laco(x, xf):
    n = int(xf * SR)
    t = np.linspace(0, np.pi / 2, n)[:, None]
    novo = x[:len(x) - n].copy()
    novo[:n] = x[:n] * np.sin(t) + x[len(x) - n:] * np.cos(t)   # potência igual: cabeça sobe, cauda desce
    return novo


def gravar(x, destino):
    p = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                          "-c:a", "libvorbis", "-q:a", "4", destino], stdin=subprocess.PIPE)
    p.communicate(x.astype(np.float32).tobytes())


def preparar(nome, pasta_mp3, pasta_ogg):
    mp3, ini, dur, xf, alvo = FAIXAS[nome]
    x = laco(ler(f"{pasta_mp3}/{mp3}.mp3", ini, dur), xf)
    g = 10 ** (alvo / 20) / float(np.sqrt(np.mean(x ** 2)))
    x = x * g
    teto = 10 ** (-1.5 / 20)
    pico = float(np.abs(x).max())
    if pico > teto:   # joelho suave só nos picos acima do teto; o resto fica intacto
        joelho = teto * 0.8
        a = np.abs(x)
        acima = a > joelho
        a[acima] = joelho + (teto - joelho) * np.tanh((a[acima] - joelho) / (teto - joelho))
        x = np.sign(x) * a
    gravar(x, f"{pasta_ogg}/{nome}.ogg")
    print(nome, mp3, f"pico_antes={20 * np.log10(pico):.1f}dB ganho={20 * np.log10(g):.1f}dB")


if __name__ == "__main__":
    for nome in (sys.argv[3:] or FAIXAS):
        preparar(nome, sys.argv[1], sys.argv[2])

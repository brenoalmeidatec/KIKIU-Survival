"""Gera as folhas do corte da katana e dos efeitos (cristal, estrela, anel, espiral) em 1 px de arte = 1 px do jogo, uma folha por tamanho.

Por que: o jogo desenhava essas folhas (quadro de 128 px, ou de 64 px dobrado para 128) com uma escala que quase nunca era inteira
(alcance 46 -> quadro de 133 px a partir de 128; estrela de raio 11 -> 22 px a partir de 128; o chao ainda achatado a 0,62 no Y). Pixel de arte
do tamanho errado no meio do mundo de 960x540. Agora cada tamanho e RENDERIZADO de novo no Blender no tamanho final (nada e ampliado ou
reamostrado), e o jogo escolhe a folha mais perto do alcance pedido e desenha com escala 1.

Como: chama o Blender (4.5 ou 5.2; sem janela) com os scripts de sempre, que agora aceitam o tamanho de quadro por variavel de ambiente
(CORTE_TAM / CORTE_GIROS em corte_hazaki*.py, EFEITO_TAM / EFEITO_ALTURA em ../blender_efeitos/efeitos_kikiu.py).
  - corte e corte ciano: uma folha por tamanho com 4 linhas = a cena girada em 0, 22,5, 45 e 67,5 graus (a camera gira: cada giro e desenhado
    de verdade, sem RotSprite). Os outros 12 dos 16 angulos do jogo sao quartos de volta trocados no shader (efeitos.gd), exatos.
  - efeitos: uma folha por tamanho; os de chao (cristal, anel, espiral) saem ja achatados em H/W = 0,62 (H par).
Saidas: fonte_arte/blender_corte/1px/{corte_hazaki,corte_hazaki_ciano}_e<L>.png (a base do corte: depois rode corte_pfx.py, que desenha o rastro e
as faiscas do pixelfx e grava assets/v2/efeitos/corte_pfx*_e<L>.png, as que o jogo usa), assets/v2/efeitos/efeito_<nome>_e<L>.png e
jogos/hordas/projeto/dados/v2_folhas_fx.json (a lista de tamanhos por folha, que o jogo le).

Uso (de qualquer pasta):  python folhas_1px.py [corte corte_ciano cristal estrela anel espiral]    (sem argumento: tudo, ~2 min)
Variavel BLENDER = caminho do blender.exe (senao procura em C:\\Program Files\\Blender Foundation).
"""

import glob
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto"))
SAIDA = os.path.join(PROJETO, "assets", "v2", "efeitos")
JSON = os.path.join(PROJETO, "dados", "v2_folhas_fx.json")
CHAO = 0.62  # o achatamento em Y dos efeitos de chao (era a escala do Y no codigo)

# Larguras do quadro (px do jogo). Passos de ~15 a 25%: o jogo escolhe a mais perto do tamanho pedido (erro de no maximo ~10%).
# O corte tem o quadro quadrado (a troca de quartos de volta no shader so e exata assim) e e 2 x alcance x 1,45: o alcance 46 do Hazaki pede 133.
TAMANHOS = {
    "corte": [56, 72, 92, 112, 134, 160, 192, 224, 264, 312],
    "corte_ciano": [56, 72, 92, 112, 134, 160, 192, 224, 264, 312],
    "cristal": [44, 60, 80, 104, 136, 176, 232, 304],
    "estrela": [22, 30, 40, 56, 76, 104],
    "anel": [64, 88, 116, 152, 200, 260],
    "espiral": [40, 56, 76, 100, 132],
}
QUADROS = {"corte": 16, "corte_ciano": 12, "cristal": 14, "estrela": 9, "anel": 18, "espiral": 12}
GIROS = {"corte": 4, "corte_ciano": 4}  # linhas da folha (0, 22,5, 45 e 67,5 graus)
ACHATADOS = ("cristal", "anel", "espiral")
ARQUIVO = {"corte": "corte_hazaki_e%d.png", "corte_ciano": "corte_hazaki_ciano_e%d.png"}
NIVEIS_ALFA = {"corte": 7, "corte_ciano": 5, "cristal": 5, "estrela": 5, "anel": 5, "espiral": 5}  # tons de alfa que a folha pode ter


def altura(nome: str, largura: int) -> int:
    """Altura do quadro: igual a largura, ou (chao) CHAO x largura arredondado para PAR (o sprite centrado precisa de borda inteira)."""
    if nome not in ACHATADOS:
        return largura
    return 2 * round(CHAO * largura / 2)


def acha_blender() -> str:
    if os.environ.get("BLENDER"):
        return os.environ["BLENDER"]
    achados = sorted(glob.glob(r"C:\Program Files\Blender Foundation\Blender *\blender.exe"))
    if not achados:
        sys.exit("Blender nao encontrado: defina a variavel BLENDER")
    return achados[-1]


def roda(blender: str, script: str, pasta: str, extra_args: list, env_extra: dict) -> None:
    env = dict(os.environ, **env_extra)
    flags = getattr(subprocess, "BELOW_NORMAL_PRIORITY_CLASS", 0)  # nao atrapalha quem esta usando o PC
    r = subprocess.run([blender, "-b", "-P", script, "--", pasta] + extra_args, env=env, capture_output=True, text=True, creationflags=flags)
    if r.returncode != 0 or "FOLHA" not in r.stdout:
        sys.exit("Blender falhou em %s:\n%s\n%s" % (script, r.stdout[-1500:], r.stderr[-1500:]))


def centro_de_massa(q: np.ndarray) -> tuple:
    """(angulo em graus, tela: y para baixo, horario positivo; distancia) do centro de massa do alfa de um quadro, em relacao ao centro."""
    a = q[..., 3].astype(np.float64)
    ys, xs = np.mgrid[0 : q.shape[0], 0 : q.shape[1]]
    dx = (xs + 0.5 - q.shape[1] / 2) * a
    dy = (ys + 0.5 - q.shape[0] / 2) * a
    cx, cy = dx.sum() / a.sum(), dy.sum() / a.sum()
    return math.degrees(math.atan2(cy, cx)), math.hypot(cx, cy)


def confere(nome: str, largura: int, im: Image.Image) -> None:
    n, h = QUADROS[nome], altura(nome, largura)
    linhas = GIROS.get(nome, 1)
    assert im.size == (n * largura, h * linhas), (nome, largura, im.size, (n * largura, h * linhas))
    a = np.array(im.convert("RGBA"))
    assert len(set(np.unique(a[..., 3]).tolist())) <= NIVEIS_ALFA[nome], (nome, largura, "mais tons de alfa que o esperado")
    if nome == "corte_ciano":  # o contorno nao pode sair reto na borda do PNG (cortado) nem ter pixel solto (ruido da amostragem)
        for lin in range(linhas):
            for q in range(n):
                f = a[lin * h : (lin + 1) * h, q * largura : (q + 1) * largura, 3]
                borda = np.concatenate([f[0], f[-1], f[:, 0], f[:, -1]])
                assert borda.max() < 255, (nome, largura, "linha", lin, "quadro", q, "o desenho encosta na borda do quadro")
                vis = np.pad(f > 0, 1)
                viz = sum(vis[1 + dy : 1 + dy + h, 1 + dx : 1 + dx + largura] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dy, dx) != (0, 0))
                assert not np.any((f > 0) & (viz == 0)), (nome, largura, "linha", lin, "quadro", q, "pixel solto")
    if linhas > 1:  # o giro k tem de levar o miolo do desenho k x 22,5 graus no sentido horario da tela
        q = 6  # o quadro do crescente cheio
        base = a[0:h, q * largura : (q + 1) * largura]
        ang0, dist0 = centro_de_massa(base)
        assert dist0 > 5.0, (nome, largura, "quadro de teste sem miolo")
        for k in range(1, linhas):
            ang, _ = centro_de_massa(a[k * h : (k + 1) * h, q * largura : (q + 1) * largura])
            erro = abs((ang - ang0 - 22.5 * k + 180.0) % 360.0 - 180.0)
            assert erro < 6.0, "%s %d: o giro %d girou %.1f graus em vez de %.1f" % (nome, largura, k, (ang - ang0 + 180.0) % 360.0 - 180.0, 22.5 * k)


def gera(blender: str, nome: str, tmp: str) -> list:
    """Gera todas as folhas de `nome`; devolve a lista [[L, H], ...] gravada."""
    pares = []
    for lar in TAMANHOS[nome]:
        h = altura(nome, lar)
        pasta = os.path.join(tmp, "%s_%d" % (nome, lar))
        os.makedirs(pasta, exist_ok=True)
        if nome in ARQUIVO:
            ciano = nome == "corte_ciano"
            script = os.path.join(AQUI, "corte_hazaki_ciano.py" if ciano else "corte_hazaki.py")
            roda(blender, script, pasta, [], {"CORTE_TAM": str(lar), "CORTE_GIROS": "1"})
            origem = os.path.join(pasta, "corte_hazaki_ciano_giros.png" if ciano else "corte_hazaki_giros.png")
            destino = os.path.join(AQUI, "1px", ARQUIVO[nome] % lar)  # base: o jogo usa a versao do corte_pfx.py
        else:
            script = os.path.normpath(os.path.join(AQUI, "..", "blender_efeitos", "efeitos_kikiu.py"))
            roda(blender, script, pasta, [nome], {"EFEITO_TAM": str(lar), "EFEITO_ALTURA": str(h)})
            origem = os.path.join(pasta, "efeito_%s_folha.png" % nome)
            destino = os.path.join(SAIDA, "efeito_%s_e%d.png" % (nome, lar))
        im = Image.open(origem)
        confere(nome, lar, im)
        im.save(destino, optimize=True)
        print("%s: %s (%dx%d, %d quadros)" % (nome, os.path.basename(destino), im.size[0], im.size[1], QUADROS[nome]))
        pares.append([lar, h])
    return pares


def main() -> None:
    pedidos = sys.argv[1:] or list(TAMANHOS)
    blender = acha_blender()
    os.makedirs(SAIDA, exist_ok=True)
    os.makedirs(os.path.join(AQUI, "1px"), exist_ok=True)
    dados = {}
    if os.path.exists(JSON):
        with open(JSON, encoding="utf-8") as f:
            dados = json.load(f)
    with tempfile.TemporaryDirectory() as tmp:
        for nome in pedidos:
            pares = gera(blender, nome, tmp)
            dados[nome] = {"quadros": QUADROS[nome], "linhas": GIROS.get(nome, 1), "tam": pares}
    dados["_ajuda"] = (
        "Folhas de efeito em 1 px de arte = 1 px do jogo, UMA POR TAMANHO (gerado por fonte_arte/blender_corte/folhas_1px.py; nao editar a mao). "
        "Por folha: quadros (por linha), linhas (4 no corte: 0, 22,5, 45 e 67,5 graus) e tam = lista de [largura, altura] do quadro em px; o arquivo de "
        "cada tamanho e assets/v2/efeitos/<corte_pfx|corte_pfx_ciano|efeito_<nome>>_e<largura>.png (o corte sai do corte_pfx.py, por cima da base do Blender). v2/efeitos.gd escolhe o tamanho mais perto do "
        "pedido e desenha com escala 1 (sem ampliar nada); o corte (e o ciano) tem quadro quadrado, os efeitos de chao (cristal, anel, espiral) vem achatados a 0,62 no Y."
    )
    ordem = {"_ajuda": dados.pop("_ajuda")}
    for k in TAMANHOS:
        if k in dados:
            ordem[k] = dados[k]
    with open(JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump(ordem, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("OK", JSON, "(agora rode corte_pfx.py para as folhas do corte)")


if __name__ == "__main__":
    main()

"""Máquina comum dos monstros (horror.py e os das regiões, #64): materiais base, peças, paleta e a folha de 5 vistas.

Cada arquivo de monstros (horror.py, floresta.py, ...) define os modelos e uma tabela
    nome: (modelo, largura, altura, giro, rampas)
e chama gerar(nome, tabela, mats_fn). A folha tem N+1 colunas x 5 linhas: as N primeiras são o CICLO DE ANDAR (a fase do passo
amostrada em N pontos de 0 a 2*pi: pose(fase) já é contínua, então N quadros dão um passo de verdade, e não o pisca-pisca de 2 poses)
e a última é o branco de dano. N = "quadros_andar" de dados/animacao_monstros.json (6), com troca por bicho em "quadros"; o número de
colunas de cada folha vai pra dados/quadros_monstros.json (o jogo lê lá; folha que não está lá é antiga: 3 colunas = 2 de andar + branco).
Uma linha por VISTA:
0 frente (olhando pra câmera), 1 3/4 frente-direita, 2 perfil direito, 3 3/4 costas-direita, 4 costas. O lado esquerdo é o
espelho das vistas 1-3 (o jogo espelha; "vistas": 5 em dados/inimigos.json). Mesma câmera nas 5 vistas: escala e pé iguais; o
tamanho do quadro cresce se o corpo não couber. Os bichos olham pra DIREITA (o render sai olhando pra esquerda e é espelhado).
Olhos e chamas são emissivos: a cor precisa existir na paleta passada ao pixelar, senão o brilho some.
"""
import json
import math
import os
import sys

import bpy
import numpy as np

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import pixel3d as px3  # noqa: E402
from pixel3d import caixa, cone, esfera  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "assets", "gerado"))
PPU = 60.0 / 2.55      # pixels por unidade do Blender: a MESMA escala do cavaleiro/Hazaki (herói ~1,9 u = 45 px)
T = px3.material_toon
C = px3.cor
VISTAS = 5                          # 0 frente, 1 3/4 frente, 2 perfil, 3 3/4 costas, 4 costas (o jogo espelha pro lado esquerdo)
ANG_VISTA = (0.0, 45.0, 90.0, 135.0, 180.0)   # graus que o corpo gira da frente (olhando pra câmera) até cada vista


DADOS = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto", "dados"))


def quadros_de(sprite):
    """Quadros de andar desta folha (sem o branco): dados/animacao_monstros.json > quadros[sprite] ou quadros_andar."""
    try:
        with open(os.path.join(DADOS, "animacao_monstros.json"), encoding="utf-8") as f:
            cfg = json.load(f)
    except (OSError, ValueError):
        cfg = {}
    return max(2, int(cfg.get("quadros", {}).get(sprite, cfg.get("quadros_andar", 6))))


def registrar_colunas(sprite, colunas):
    """Grava 'sprite: colunas' em dados/quadros_monstros.json (junta com o que já tem; trava por arquivo pra os
    processos paralelos do Blender, um por região, não perderem a linha uns dos outros)."""
    caminho = os.path.join(DADOS, "quadros_monstros.json")
    trava = caminho + ".trava"
    import time
    for _ in range(600):
        try:
            fd = os.open(trava, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.close(fd)
            break
        except FileExistsError:
            time.sleep(0.05)
    try:
        try:
            with open(caminho, encoding="utf-8") as f:
                tab = json.load(f)
        except (OSError, ValueError):
            tab = {}
        tab["_ajuda"] = ("GERADO por fonte_arte/modelos3d/monstros.py (não edite à mão): quantas colunas tem cada folha de monstro "
                         "(quadros de andar + 1 de branco de dano, sempre a última). Folha que não está aqui é antiga: 3 colunas.")
        tab[sprite] = colunas
        ordenado = {k: tab[k] for k in sorted(tab)}
        with open(caminho, "w", encoding="utf-8") as f:
            json.dump(ordenado, f, ensure_ascii=False, indent=1)
            f.write("\n")
    finally:
        try:
            os.remove(trava)
        except OSError:
            pass


def mats_base():
    """Materiais compartilhados. Cores base perto do tom claro da rampa; o toon escurece em 3 faixas."""
    return {
        "aco": T("aco", C("6f6a86"), ruido=0.25, escala_ruido=9.0),
        "aco_e": T("aco_e", C("4a4560")),
        "ferrugem": T("ferrugem", C("6e4c32"), ruido=0.3, escala_ruido=8.0),
        "osso": T("osso", C("c9bfa6")),
        "osso_e": T("osso_e", C("8c8470")),
        "carne": T("carne", C("a8302c"), ruido=0.2, escala_ruido=5.0),
        "carne_e": T("carne_e", C("6a1c24")),
        "pele": T("pele", C("6c8068"), ruido=0.22, escala_ruido=7.0),      # cinza-esverdeada, apodrecida
        "pele_e": T("pele_e", C("3b4a3d")),
        "pano": T("pano", C("3c3552"), ruido=0.2, escala_ruido=6.0),        # manto roxo-noite
        "pano_s": T("pano_s", C("6a1c24"), ruido=0.2, escala_ruido=6.0),    # manto sangue seco
        "negro": T("negro", C("0d0b14"), faixas=(1, 1, 1)),
        "ouro": T("ouro", C("8a6a34")),
        "olho_v": px3.material_emissao("olho_v", C("e4ffb0")),    # verde-pálido (espectro, carniçal)
        "olho_f": px3.material_emissao("olho_f", C("ffd060")),    # âmbar (cavaleiro oco, abominação)
        "olho_r": px3.material_emissao("olho_r", C("ff3a2a")),    # brasa vermelha (cão, chefe)
        "fogo": px3.material_emissao("fogo", C("fff2b0")),
    }


# ------------------------------------------------------------------ peças

def braco(nome, w, d, L, pivo, mat, pai):
    """Caixa pendurada num pivô (ombro/quadril): gira em X pra balançar."""
    return caixa(nome, (w, d, L), (pivo[0], pivo[1], pivo[2] - L / 2), mat, pai, pivo=pivo)


def raiz_corpo():
    bpy.ops.object.empty_add(location=(0, 0, 0))
    raiz = bpy.context.active_object
    raiz.name = "raiz"
    bpy.ops.object.empty_add(location=(0, 0, 0))
    corpo = bpy.context.active_object
    corpo.name = "corpo"
    corpo.parent = raiz
    return raiz, corpo


def apontar(o, direcao):
    from mathutils import Vector
    o.rotation_euler = Vector(direcao).normalized().to_track_quat("Z", "Y").to_euler()


def espinho(nome, base, direcao, comp, r, mat, pai):
    c = cone(nome, r, 0.0, comp, (0, 0, 0), mat, None)
    from mathutils import Vector
    c.location = Vector(base) + Vector(direcao).normalized() * comp / 2
    apontar(c, direcao)
    px3.pendurar(c, pai)
    return c


def bola(nome, r, pos, mat, pai, escala=(1, 1, 1)):
    return esfera(nome, r, pos, mat, pai, escala=escala)


def galho(nome, a, b, r, mat, pai, vertices=6):
    """Cilindro do ponto a ao ponto b (pata de aranha, galho, raiz, cajado)."""
    from mathutils import Vector
    from pixel3d import cilindro
    va, vb = Vector(a), Vector(b)
    o = cilindro(nome, r, (vb - va).length, tuple((va + vb) / 2), mat, None, vertices=vertices)
    apontar(o, vb - va)
    px3.pendurar(o, pai)
    return o


def junta(nome, pos, pai):
    """Pivô vazio em 'pos' (preso no pai): pendure peças nele e gire o pivô pra animar a perna/asa inteira."""
    bpy.ops.object.empty_add(location=pos)
    j = bpy.context.active_object
    j.name = nome
    px3.pendurar(j, pai)
    return j


# ------------------------------------------------------------------ paleta e folha

def paleta(nomes):
    base = px3.paleta_de(*nomes)
    vermelho = np.array([[1.0, 0x3a / 255.0, 0x2a / 255.0]])   # brasa dos olhos: clara o bastante pra atravessar a escuridão
    return np.vstack([base, vermelho])


def gerar(nome, tabela, mats_fn, rotulo="MONSTRO"):
    """Folha: N quadros de andar + 1 de branco do flash (colunas) x 5 linhas (as vistas). Mesma câmera nas 5 vistas: a escala e
    o pé (a origem do modelo) caem no mesmo pixel em todas; a câmera é calibrada pela união dos retângulos de todas."""
    modelo, W, H, giro, ramps = tabela[nome]
    N = quadros_de("inimigo_" + nome)
    fases = [2.0 * math.pi * k / N for k in range(N)]   # o ciclo todo, sem repetir o quadro 0 no fim
    px3.limpar_cena()
    px3.preparar_render(W, H)
    cam = px3.camera(elevacao_graus=32.0, escala=max(W, H) / PPU)
    px3.luz()
    m = mats_fn()
    raiz, corpo, p, pose = modelo(m)
    cam.data.shift_x = 0.0
    cam.data.shift_y = 0.0
    cena = bpy.context.scene
    esc0 = cam.data.ortho_scale
    cena.render.resolution_x, cena.render.resolution_y = W * 2, H * 2   # medir numa tela de dobro do tamanho (a mesma densidade de pixels): nada é cortado
    cam.data.ortho_scale = esc0 * 2.0
    uniao = None
    for v in range(VISTAS):
        raiz.rotation_euler = (0, 0, -math.radians(ANG_VISTA[v]))
        for k, fase in enumerate(fases):
            pose(fase, k)
            cx =px3.caixa_alfa(px3.render_rgba())
            if cx is None:
                raise RuntimeError("o modelo não apareceu no render")
            uniao = list(cx) if uniao is None else [min(uniao[0], cx[0]), min(uniao[1], cx[1]), max(uniao[2], cx[2]), max(uniao[3], cx[3])]
    # a folha cresce se o corpo não couber (a espada pra frente, o perfil comprido): a densidade de pixels é a mesma,
    # então o bicho não muda de tamanho na tela; o fundo do quadro é o ponto mais baixo (como antes) e o centro, o do conjunto
    uw, uh = uniao[2] - uniao[0] + 1, uniao[3] - uniao[1] + 1
    Wn, Hn = max(W, int(math.ceil(uw)) + 2), max(H, int(math.ceil(uh)) + 3)
    cx_n = (uniao[0] + uniao[2]) / 2.0 - W + Wn / 2.0
    by_n = uniao[3] - H + Hn / 2.0
    W, H = Wn, Hn
    cena.render.resolution_x, cena.render.resolution_y = W, H
    maior = max(W, H)
    cam.data.ortho_scale = maior / PPU
    cam.data.shift_x = (cx_n - (W - 1) / 2.0) / maior
    cam.data.shift_y = -(by_n - (H - 2)) / maior
    print(rotulo, "quadro", nome, W, H)
    pal = paleta(ramps)
    folha = np.zeros((H * VISTAS, W * (N + 1), 4), dtype=np.float32)
    for v in range(VISTAS):
        raiz.rotation_euler = (0, 0, -math.radians(ANG_VISTA[v]))
        y0 = v * H
        for q, fase in enumerate(fases):
            pose(fase, q)
            folha[y0:y0 + H, q * W:(q + 1) * W] = px3.pixelar(px3.render_rgba(), paleta=pal)[:, ::-1]   # olhando pra direita
        branco = folha[y0:y0 + H, :W].copy()
        branco[branco[:, :, 3] > 0.5, :3] = 1.0
        folha[y0:y0 + H, N * W:] = branco
    px3.salvar_png(folha, os.path.join(SAIDA, "inimigo_%s.png" % nome))
    registrar_colunas("inimigo_" + nome, N + 1)
    print(rotulo, "OK", nome, W, H, "vistas", VISTAS, "quadros", N)


def orbe(nome, n, rampa):
    """Projétil redondo e brilhante, com miolo claro, 2 anéis e contorno escuro."""
    out = np.zeros((n, n, 4), dtype=np.float32)
    c = (n - 1) / 2.0
    cores = [np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]) for h in rampa]
    for y in range(n):
        for x in range(n):
            d = math.hypot(x - c, y - c) / (n / 2.0)
            if d > 1.0:
                continue
            k = min(len(cores) - 1, int((1.0 - d) * len(cores) * 1.05))
            out[y, x, :3] = cores[k] if d < 0.92 else px3.CONTORNO
            out[y, x, 3] = 1.0
    px3.salvar_png(out, os.path.join(SAIDA, "proj_%s.png" % nome))


def rodar(tabela, mats_fn, projeteis=(), rotulo="MONSTRO"):
    """Linha de comando comum: `blender -b -P arquivo.py` gera todos; `-- nome1 nome2` só esses (sem os projéteis)."""
    quais = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else []
    for n in (quais or list(tabela)):
        gerar(n, tabela, mats_fn, rotulo)
    if not quais:
        for nome, n, rampa in projeteis:
            orbe(nome, n, rampa)
        print(rotulo, "projeteis OK")

"""Dragão do Hazaki (#20, seção 8 do design): dragão oriental com identidade própria, nada copiado.
Escamas de cobalto (a mesma energia da aura do Hazaki), ventre e chifres de ouro velho, juba de chamas
vermelhas e bigodes de energia ciano que brilham. Corpo serpentino: no jogo ele é uma CORRENTE de peças
que segue o rastro da cabeça e ondula no ar (scripts/hordas/dragao.gd), então aqui cada peça sai sozinha.

Roda (Blender 4.5 LTS):
    blender -b -P dragao.py
Saída: ../../projeto/assets/personagens/hazaki/dragao/<peca>.png e ../../projeto/assets/gerado/icone_dragao.png

Cada folha tem 16 colunas = 16 direções (coluna k olha pro ângulo k*22.5° na tela: 0 = direita, 4 = baixo,
8 = esquerda, 12 = cima) e uma linha por variação:
- cabeca.png (64x64): linha 0 boca fechada, linha 1 boca aberta (baforada, rugido);
- corpo.png (48x48): linhas 0..3 = o mesmo gomo em 4 tamanhos (100%, 85%, 70%, 55%), afinando pra cauda;
- pernas_frente.png / pernas_tras.png (48x48): 4 quadros das patas remando no ar;
- cauda.png (48x48): ponta da cauda com o tufo de chamas.
O centro do quadro é o centro da peça (o jogo desenha a peça centrada no ponto da corrente).
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import pixel3d as px3  # noqa: E402
from pixel3d import caixa, cilindro, cone, esfera  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.normpath(os.path.join(AQUI, "..", "..", "projeto"))
SAIDA = os.path.join(PROJ, "assets", "personagens", "hazaki", "dragao")
U = 2.55 / 60.0          # unidades do Blender por pixel: a MESMA escala do Hazaki (o dragão não encolhe nem incha)
DIRS = 16
PAL = px3.paleta_de("cobalto", "ouro", "sangue", "fogo", "osso")
TAMANHOS = [1.0, 0.85, 0.7, 0.55]
ESCALA = 1.25        # o dragão inteiro é 25% maior que a escala do Hazaki: tem que ficar claro que ele virou dragão
CAB, GOMO = 64, 48   # lado do quadro da cabeça e das outras peças

PECAS = {}               # nome -> [objetos]
_atual = ["cabeca"]


def em(nome):
    _atual[0] = nome
    PECAS.setdefault(nome, [])


def _r(o):
    PECAS[_atual[0]].append(o)
    return o


def apontar(o, direcao):
    """Gira o objeto (que nasce apontando pra +Z) pra apontar na direção dada."""
    o.rotation_euler = Vector(direcao).normalized().to_track_quat("Z", "Y").to_euler()


def espinho(nome, base, direcao, comp, r, mat, pai=None):
    """Cone que nasce em 'base' e aponta pra 'direcao' (chifre, espinho, chama da juba)."""
    d = Vector(direcao).normalized()
    o = cone(nome, r, 0.0, comp, tuple(Vector(base) + d * comp / 2.0), mat)
    apontar(o, d)
    if pai is not None:
        px3.pendurar(o, pai)
    return _r(o)


def fio(nome, base, direcao, comp, r, mat, pai=None):
    d = Vector(direcao).normalized()
    o = cilindro(nome, r, comp, tuple(Vector(base) + d * comp / 2.0), mat, vertices=6)
    apontar(o, d)
    if pai is not None:
        px3.pendurar(o, pai)
    return _r(o)


def materiais():
    t = lambda nome, h, **k: px3.material_toon(nome, px3.cor(h), **k)  # noqa: E731
    return {
        "escama": t("escama", "2a4fc0", ruido=0.3, escala_ruido=16.0),   # ruído = aglomerados de escamas
        "escama_esc": t("escama_esc", "142a6e"),
        "ouro": t("ouro", "c49a45"),
        "ouro_esc": t("ouro_esc", "8f6a2e"),
        "juba": t("juba", "b0342f"),
        "osso": t("osso", "d6ccb2"),
        "chama": px3.material_emissao("chama", px3.cor("f0921e")),
        "bigode": px3.material_emissao("bigode", px3.cor("8cd9ff")),
        "olho": px3.material_emissao("olho", px3.cor("ffd060")),
    }


def montar_cabeca(m):
    """Cabeça olhando pra -Y (pra câmera), centrada na origem. Devolve a mandíbula (abre na baforada)."""
    em("cabeca")
    _r(esfera("cranio", 0.22, (0, 0.02, 0.05), m["escama"], escala=(1.0, 1.1, 0.85)))
    _r(caixa("focinho", (0.26, 0.42, 0.14), (0, -0.3, 0.03), m["escama"], chanfro=0.05))
    _r(caixa("testa", (0.3, 0.12, 0.05), (0, -0.1, 0.14), m["ouro"], chanfro=0.02))       # crista sobre os olhos
    for x in (-0.08, 0.08):
        _r(esfera("narina", 0.07, (x, -0.48, 0.08), m["escama"]))
    for x in (-0.13, 0.13):
        _r(esfera("olho", 0.045, (x, -0.14, 0.12), m["olho"]))
    for x in (-0.07, 0.07):   # presas de cima (aparecem com a boca aberta)
        espinho("presa", (x, -0.44, -0.03), (0, -0.2, -1), 0.1, 0.03, m["osso"])
    mand = _r(caixa("mandibula", (0.22, 0.38, 0.08), (0, -0.28, -0.08), m["escama_esc"], pivo=(0, -0.06, -0.06), chanfro=0.03))
    _r(caixa("lingua", (0.08, 0.28, 0.03), (0, -0.28, -0.04), m["juba"], pai=mand))
    for x in (-0.06, 0.06):
        espinho("presa_baixo", (x, -0.42, -0.05), (0, 0, 1), 0.08, 0.025, m["osso"], pai=mand)
    # chifres de ouro, varridos pra trás, com um galho cada (cervo, não touro: é o que lê como dragão do oriente)
    for lado in (-1, 1):
        espinho("chifre", (0.1 * lado, 0.08, 0.18), (0.35 * lado, 0.9, 0.75), 0.48, 0.05, m["ouro"])
        espinho("galho", (0.17 * lado, 0.22, 0.32), (0.5 * lado, 0.2, 0.9), 0.18, 0.03, m["ouro"])
    # juba de chamas atrás do crânio
    for i, (x, z, ang) in enumerate([(-0.16, 0.0, 1.5), (0.16, 0.0, 1.5), (-0.1, 0.15, 1.2), (0.1, 0.15, 1.2),
                                     (0.0, 0.2, 1.05), (-0.2, -0.1, 1.8), (0.2, -0.1, 1.8)]):
        d = (x * 1.6, math.sin(ang), math.cos(ang))
        espinho("juba", (x, 0.12, z), d, 0.36, 0.07, m["juba"])
        if i % 2 == 0:
            espinho("ponta_juba", (x * 1.2, 0.3, z + 0.08), d, 0.16, 0.04, m["chama"])
    # bigodes de energia: longos, saem do focinho e flutuam pra trás
    for lado in (-1, 1):
        fio("bigode", (0.1 * lado, -0.46, 0.02), (0.9 * lado, 0.35, -0.15), 0.42, 0.022, m["bigode"])
    return mand


def montar_gomo(m, nome, s, patas=None):
    """Um gomo do corpo no tamanho s. patas = lista que recebe as patas (pra animar), ou None."""
    em(nome)
    _r(esfera("corpo", 0.3 * s, (0, 0, 0), m["escama"], escala=(1.0, 1.25, 0.95)))
    _r(esfera("ventre", 0.29 * s, (0, -0.02 * s, -0.13 * s), m["ouro"], escala=(1.0, 1.2, 0.62)))
    espinho("espinho", (0, 0.06 * s, 0.22 * s), (0, 0.6, 1), 0.34 * s, 0.1 * s, m["juba"])
    espinho("ponta_espinho", (0, 0.2 * s, 0.44 * s), (0, 0.6, 1), 0.12 * s, 0.05 * s, m["chama"])
    if patas is None:
        return
    for lado in (-1, 1):
        ombro = (0.22 * s * lado, -0.05 * s, -0.05 * s)
        coxa = _r(caixa("coxa", (0.13 * s, 0.13 * s, 0.32 * s), (ombro[0] + 0.05 * s * lado, ombro[1], ombro[2] - 0.12 * s),
                        m["escama"], pivo=ombro, chanfro=0.02))
        pe = (ombro[0] + 0.09 * s * lado, ombro[1] - 0.02 * s, ombro[2] - 0.33 * s)
        _r(esfera("pe", 0.08 * s, pe, m["ouro_esc"], pai=coxa))
        for g in (-1, 0, 1):   # três garras de ouro
            espinho("garra", (pe[0] + 0.04 * s * g, pe[1] - 0.04 * s, pe[2] - 0.02 * s), (0.3 * g, -1, -0.5), 0.15 * s, 0.035 * s, m["ouro"], pai=coxa)
        patas.append((coxa, lado))


def montar_cauda(m):
    em("cauda")
    _r(esfera("ponta", 0.2, (0, -0.05, 0), m["escama"], escala=(0.9, 1.4, 0.85)))
    _r(esfera("ventre_ponta", 0.16, (0, -0.06, -0.06), m["ouro"], escala=(0.8, 1.3, 0.6)))
    for i, (x, z) in enumerate([(0, 0.05), (-0.09, 0.0), (0.09, 0.0), (0, -0.06), (-0.05, 0.1), (0.05, 0.1)]):
        espinho("tufo", (x, 0.18, z), (x * 3.0, 1.0, z * 3.0 + 0.2), 0.34 if i < 3 else 0.24, 0.07, m["juba"])
        if i < 3:
            espinho("tufo_chama", (x * 1.3, 0.4, z + 0.03), (x * 3.0, 1.0, z * 3.0 + 0.2), 0.16, 0.045, m["chama"])


def mostrar(nome):
    for n, objs in PECAS.items():
        for o in objs:
            o.hide_render = n != nome


def folha(raiz, nome, lado, linhas, preparar):
    """Renderiza a peça nas 16 direções x 'linhas' variações (preparar(linha) monta a pose da linha)."""
    px3.preparar_render(lado, lado)
    bpy.context.scene.camera.data.ortho_scale = lado * U
    mostrar(nome)
    out = np.zeros((lado * linhas, lado * DIRS, 4), dtype=np.float32)
    sem = np.zeros_like(out)   # a mesma folha SEM contorno: o jogo desenha por cima e some a costura entre gomos
    for li in range(linhas):
        preparar(li)
        for k in range(DIRS):
            # ângulo na tela (0 = direita, 90 = baixo) -> giro do modelo, que nasce olhando pra câmera (baixo)
            raiz.rotation_euler = (0, 0, math.radians(90.0 - k * 360.0 / DIRS))
            px = px3.render_rgba()
            out[li * lado:(li + 1) * lado, k * lado:(k + 1) * lado] = px3.pixelar(px, paleta=PAL)
            sem[li * lado:(li + 1) * lado, k * lado:(k + 1) * lado] = px3.pixelar(px, paleta=PAL, contorno=False)
    px3.salvar_png(out, os.path.join(SAIDA, nome + ".png"))
    px3.salvar_png(sem, os.path.join(SAIDA, nome + "_sem.png"))
    return out, sem


def main():
    px3.limpar_cena()
    px3.preparar_render(48, 48)
    px3.camera(elevacao_graus=32.0, escala=48 * U)
    px3.luz(preenche=2.2)
    m = materiais()
    mand = montar_cabeca(m)
    patas_f, patas_t = [], []
    montar_gomo(m, "pernas_frente", 1.0, patas_f)
    montar_gomo(m, "pernas_tras", 0.85, patas_t)
    for i, s in enumerate(TAMANHOS):
        montar_gomo(m, "corpo_%d" % i, s)
    montar_cauda(m)
    # tudo pendurado numa raiz só, que gira pras 16 direções
    raiz = bpy.data.objects.new("raiz", None)
    raiz.scale = (ESCALA, ESCALA, ESCALA)
    bpy.context.collection.objects.link(raiz)
    # a cabeça é 45% maior que o resto (no jogo é ela que diz "virou dragão")
    cab = bpy.data.objects.new("cab", None)
    bpy.context.collection.objects.link(cab)
    cab.scale = (1.45, 1.45, 1.45)
    for o in PECAS["cabeca"]:
        if o.parent is None:
            px3.pendurar(o, cab)
    px3.pendurar(cab, raiz)
    for objs in PECAS.values():
        for o in objs:
            if o.parent is None:
                px3.pendurar(o, raiz)

    def boca(li):
        mand.rotation_euler = (0.5 if li == 1 else 0.0, 0, 0)

    def remar(patas):
        def f(li):
            for coxa, lado in patas:
                fase = 2 * math.pi * li / 4.0 + (0 if lado < 0 else math.pi)
                coxa.rotation_euler = (0.7 * math.sin(fase) - 0.3, 0.35 * lado, 0)   # rema e abre pro lado
        return f

    folha(raiz, "cabeca", CAB, 2, boca)
    folha(raiz, "pernas_frente", GOMO, 4, remar(patas_f))
    folha(raiz, "pernas_tras", GOMO, 4, remar(patas_t))
    # os 4 tamanhos do gomo viram as 4 linhas de corpo.png
    gomos = [folha(raiz, "corpo_%d" % i, GOMO, 1, lambda li: None) for i in range(len(TAMANHOS))]
    px3.salvar_png(np.concatenate([g[0] for g in gomos], axis=0), os.path.join(SAIDA, "corpo.png"))
    px3.salvar_png(np.concatenate([g[1] for g in gomos], axis=0), os.path.join(SAIDA, "corpo_sem.png"))
    for i in range(len(TAMANHOS)):
        for suf in ("", "_sem"):
            os.remove(os.path.join(SAIDA, "corpo_%d%s.png" % (i, suf)))
    folha(raiz, "cauda", GOMO, 1, lambda li: None)
    # ícone 32x32 (HUD e cartas): a cabeça de boca aberta, olhando pra baixo-esquerda
    px3.preparar_render(32, 32)
    bpy.context.scene.camera.data.ortho_scale = 1.9 * ESCALA
    mostrar("cabeca")
    boca(1)
    raiz.rotation_euler = (0, 0, math.radians(90.0 - 125.0))
    px3.salvar_png(px3.pixelar(px3.render_rgba(), paleta=PAL), os.path.join(PROJ, "assets", "gerado", "icone_dragao.png"))
    print("DRAGAO OK pecas:", ", ".join(PECAS))


main()

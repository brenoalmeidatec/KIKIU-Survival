"""Enfeites da Floresta para o protótipo da cara nova: ALBEDO CHAPADO, sem as faixas de sombra do toon.

Por que existe: o atlas de hoje (`projeto/assets/cenarios/floresta/enfeites.png`) foi renderizado com `material_toon` (3 faixas de
sombra) e luz fixa vinda de cima e da esquerda. O lado escuro de cada árvore, pedra e arbusto fica ASSADO no pixel, sempre do mesmo
lado, e parece uma sombra parada que não gira com a luz. Aqui os mesmos modelos 3D de `fonte_arte/modelos3d/cenarios.py` são renderizados
com a câmera a 45 graus e cor chapada (igual ao `gerar_cara_nova.py`); a sombra no chão passa a ser desenhada em tempo real pelo Godot.

Nada de `cenarios.py` ou `assets/` é alterado: o módulo é lido por `exec` sem o `main()` (que regravaria os cenários do jogo) e o
`material_toon` é trocado só em memória.

Uso (Blender 4.5), a partir de jogos/hordas/prototipos/cara_nova:
    blender -b -P gerar_cenario_cara_nova.py            (enfeites, ~5 s)
    blender -b -P gerar_cenario_cara_nova.py -- piso    (o chão, ~1 min)
Saída em sprites/: floresta_enfeites_albedo.png + floresta_enfeites.json (região e pé de cada enfeite, em pixels do atlas) e
floresta_piso.png (o chão com a MESMA arte e o mesmo sorteio do `piso.png` de hoje, mas com a luz sem sombra projetada).

O chão também tinha sombra assada: o `piso.png` é renderizado no Cycles com um sol rasante COM sombra, então cada tufo de capim,
cogumelo, pedrinha e galho caído leva uma sombra escura para o mesmo lado (sudeste), que não gira com as luzes do jogo.
"""
import json
import os
import random
import sys

import bpy
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
GERADORES = os.path.normpath(os.path.join(AQUI, "..", "..", "fonte_arte", "modelos3d"))
SAIDA = os.path.join(AQUI, "..", "..", "projeto", "prototipos", "cara_nova", "sprites")  # dentro do projeto: o exe só lê res://
sys.path.insert(0, GERADORES)
import pixel3d as px3  # noqa: E402

ELEVACAO = 45.0
PPU = 24.5          # mesmo do herói e dos monstros do protótipo
GAMA_ALBEDO = 0.85  # levanta só um pouco (os monstros usam 0.6): árvores e pedras já são escuras e a luz do jogo faz o resto
ENFEITE = 128
CORES = []          # cores chapadas dos materiais: viram a paleta (o albedo é cor chapada, então a quantização só limpa o antialias)
ITENS = ("arvore", "arvore_morta", "toco", "tronco", "arbusto", "pedra", "cogumelos", "cranio")


def _emissao(nome, cor):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    emi = nt.nodes.new("ShaderNodeEmission")
    emi.inputs[0].default_value = cor
    emi.inputs[1].default_value = 1.0
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emi.outputs[0], out.inputs[0])
    return m


def material_toon_novo(nome, cor_base, faixas=None, limites=None, ruido=0.0, escala_ruido=6.0):
    cor = tuple(min(1.0, c) ** GAMA_ALBEDO for c in cor_base[:3]) + (1.0,)
    CORES.append(cor[:3])
    return _emissao("alb_" + nome, cor)


def material_emissao_novo(nome, cor_base, forca=1.0):
    CORES.append(tuple(cor_base[:3]))
    return _emissao("alb_" + nome, tuple(cor_base[:3]) + (1.0,))


def _srgb(lin):
    """O render sai codificado em sRGB (view transform Standard); as cores dos materiais são lineares."""
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(np.maximum(lin, 1e-6), 1 / 2.4) - 0.055).astype(np.float32)


def carregar_cenarios():
    """Lê cenarios.py sem rodar o main() dele (ele regravaria os cenários do jogo)."""
    caminho = os.path.join(GERADORES, "cenarios.py")
    with open(caminho, encoding="utf-8") as f:
        src = f.read()
    corte = src.rstrip().rsplit("\nmain()", 1)
    assert len(corte) == 2 and corte[1].strip() == "", "cenarios.py mudou: o main() não está mais no fim"
    ns = {"__name__": "cenarios_novo", "__file__": caminho}
    exec(compile(corte[0], caminho, "exec"), ns)
    return ns


def gerar_piso(ns, cfg):
    """Mesmo caminho do `gerar()` do cenarios.py para o piso (mesma semente, mesmos objetos), só que o sol não projeta sombra."""
    pal = px3.paleta_de(*cfg["paleta"])
    tam = ns["PISO"]
    ns["L"] = tam / ns["PX"]
    px3.limpar_cena()
    px3.preparar_suave(tam, tam, ns["FATOR"])
    px3.camera_topo(ns["L"])
    px3.luz(rasante=True, suave=True)
    for lz in bpy.data.lights:
        lz.use_shadow = False      # a única diferença para o piso.png de hoje
    ns["SUAVE"][0] = True
    cfg["piso"](random.Random("floresta"))
    ns["SUAVE"][0] = False
    ns["repetir_3x3"]()
    bruto = px3.reduzir(px3.render_rgba(), ns["FATOR"])
    piso = px3.pixelar(bruto, contorno=False, paleta=pal, luz_borda=False, pontilhado=0.0)
    piso[:, :, 3] = 1.0
    px3.salvar_png(piso, os.path.join(SAIDA, "floresta_piso.png"))
    print("CENARIO_CARA_NOVA piso OK")


def main():
    px3.material_toon = material_toon_novo
    px3.material_emissao = material_emissao_novo
    ns = carregar_cenarios()
    cfg = ns["CENARIOS"]["floresta"]
    os.makedirs(SAIDA, exist_ok=True)
    if "piso" in sys.argv:
        gerar_piso(ns, cfg)    # blender -b -P gerar_cenario_cara_nova.py -- piso   (leva ~1 min: Cycles em 1024x1024)
        return
    imagens, itens = [], []
    for nome_e, f, peso in cfg["enfeites"]:
        if nome_e not in ITENS:
            continue
        px3.limpar_cena()
        px3.preparar_render(ENFEITE, ENFEITE)
        cam = px3.camera(elevacao_graus=ELEVACAO, escala=ENFEITE / PPU)
        px3.luz()
        ns["chamar"](f, random.Random("floresta" + nome_e))
        bpy.context.view_layer.update()
        pe = px3.pe_na_tela(cam)
        pal = _srgb(np.array(sorted(set(CORES)), dtype=np.float32))
        img, pe_rel = px3.recortar(px3.pixelar(px3.render_rgba(), paleta=pal, luz_borda=False), pe)
        imagens.append(img)
        itens.append({"nome": nome_e, "pe": [round(pe_rel[0]), round(pe_rel[1])]})
    atlas, pos = px3.empacotar(imagens, 256)
    for it, p in zip(itens, pos):
        it["regiao"] = list(p)
    px3.salvar_png(atlas, os.path.join(SAIDA, "floresta_enfeites_albedo.png"))
    with open(os.path.join(SAIDA, "floresta_enfeites.json"), "w", encoding="utf-8") as fp:
        json.dump({"elevacao": ELEVACAO, "ppu": PPU, "itens": itens}, fp, ensure_ascii=False, indent=1)
    print("CENARIO_CARA_NOVA OK", len(itens), "itens, atlas", atlas.shape[1], "x", atlas.shape[0])


main()

"""Variante 'ciano' do corte: so o rastro de energia (sem katana), crescente turquesa/ciano com borda interna branca, pixel art grosso.

    blender -b -P corte_hazaki_ciano.py -- [pasta_de_saida]
Reaproveita os blocos de corte_hazaki.py. Renderiza em 64x64 e dobra (nearest) para 128x128: pixels de 2 px, silhueta serrilhada de proposito.
Saidas: corte_hazaki_ciano.blend, corte_hazaki_ciano_folha.png (12x1 = 1536x128, quantizada). O jogo pinta a rampa de cores no shader
(calor 0 = turquesa, 1 = branco azulado), entao a cor do golpe do combo NAO muda esta variante.

Linha do tempo (12 quadros): 1-3 o arco nasce e varre a tela (partida extremamente rapida); 4 flash branco do impacto; 5-12 o rastro some da cauda
para a ponta, com 2 trilhas translucidas atrasadas e uma imagem-fantasma maior atras, e se desfaz em pixels brilhantes.
"""
import math
import os
import random
import sys

import bpy
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\dev\kikiu_cortes\jogos\hordas\fonte_arte\blender_corte"
sys.path.insert(0, AQUI)
import corte_hazaki as b  # noqa: E402  (blocos de geometria/material compartilhados)

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAIDA = os.path.abspath(ARGS[0]) if ARGS else AQUI
N2, T2, ESC = 12, 64, 2
R2 = 0.82


def material_ciano(nome):
    """Corpo cheio de bordas nitidas; calor alto na borda INTERNA (branco azulado), baixo na externa (turquesa)."""
    m = bpy.data.materials.new(nome)
    nt = m.node_tree
    nt.nodes.clear()
    uvn = nt.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uvn.outputs[0], sep.inputs[0])
    u, v = sep.outputs[0], sep.outputs[1]
    cab, pon, ite = b.valor(nt, "cabeca"), b.valor(nt, "ponta_do_rastro"), b.valor(nt, "intensidade")
    H, P, I = cab.outputs[0], pon.outputs[0], ite.outputs[0]
    mat = b.mat
    vao = mat(nt, "MAXIMUM", mat(nt, "SUBTRACT", H, P), 0.02)
    q = mat(nt, "DIVIDE", mat(nt, "SUBTRACT", u, P), vao, clamp=True)
    dentro = mat(nt, "MULTIPLY", mat(nt, "LESS_THAN", u, mat(nt, "ADD", H, 0.004)), mat(nt, "GREATER_THAN", u, P))
    perfil = mat(nt, "MULTIPLY", mat(nt, "MULTIPLY", v, 7.0, clamp=True), mat(nt, "MULTIPLY", mat(nt, "SUBTRACT", 1.0, v), 12.0, clamp=True))
    corpo = mat(nt, "ADD", 0.45, mat(nt, "MULTIPLY", mat(nt, "POWER", q, 0.8), 0.55))
    k = mat(nt, "MULTIPLY", mat(nt, "MULTIPLY", dentro, perfil), mat(nt, "MULTIPLY", corpo, I))
    d = mat(nt, "SUBTRACT", H, u)
    pt = mat(nt, "DIVIDE", d, 0.06)
    clarao = mat(nt, "MULTIPLY", mat(nt, "EXPONENT", mat(nt, "MULTIPLY", mat(nt, "MULTIPLY", pt, pt), -1.0)), mat(nt, "MULTIPLY", dentro, I))
    k = mat(nt, "ADD", k, mat(nt, "MULTIPLY", clarao, 0.5), clamp=True)
    interna = mat(nt, "POWER", mat(nt, "SUBTRACT", 1.0, v), 2.4)
    calor = mat(nt, "ADD", mat(nt, "MULTIPLY", interna, 1.1), mat(nt, "ADD", mat(nt, "MULTIPLY", mat(nt, "POWER", q, 6.0), 0.35), clarao), clamp=True)
    comb = nt.nodes.new("ShaderNodeCombineColor")
    for i in range(3):
        nt.links.new(calor, comb.inputs[i])
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(comb.outputs[0], em.inputs["Color"])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(mat(nt, "MAXIMUM", mat(nt, "MINIMUM", k, 1.0), 0.0), mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(mix.outputs[0], out.inputs[0])
    return m, cab, pon, ite


def monta():
    b.cena = bpy.context.scene
    b.limpa()
    b.etapa_base()
    cena = bpy.context.scene
    b.lin()
    cena.frame_start, cena.frame_end = 1, N2
    cena.render.resolution_x = cena.render.resolution_y = T2
    cena.cycles.filter_width = 0.01           # sem suavizacao de borda: pixel nitido
    cena.cycles.samples = 4
    # arco principal + 2 trilhas + imagem-fantasma + flash
    def arco(nome, larg, r_ext, chaves, escala=None):
        m, c, p, i = material_ciano(nome)
        ob = b.crescente(nome, larg, m, r_ext=r_ext, perfil=0.5)
        b.keyar_rastro((c, p, i), chaves)
        if escala:
            for f, s in escala:
                b.keyar(ob, f, esc=(s, s, 1))
        return ob

    F = lambda t: t                                                       # noqa: E731
    principal = [(1, .45, 0, 1), (2, .9, 0, 1), (3, 1.03, 0, 1), (4, 1.03, 0, 1), (5, 1.03, .08, .95), (6, 1.03, .25, .8),
                 (7, 1.03, .45, .65), (8, 1.03, .65, .45), (9, 1.03, .8, .3), (10, 1.03, .92, .2), (11, 1.03, 1.0, .1), (12, 1.03, 1.03, 0)]
    arco("principal", 0.30, R2, principal)
    atras = lambda k: [(f, c, min(p + .06 * k, 1.03), max(i - .22 * k, 0)) for f, c, p, i in principal]       # noqa: E731
    arco("trilha_1", 0.15, R2 - 0.09, [(f, max(c - .12, 0), p, i) for f, c, p, i in atras(1)])
    arco("trilha_2", 0.10, R2 - 0.17, [(f, max(c - .25, 0), p, i) for f, c, p, i in atras(2)])
    fant = [(f, 1.03, 0.0, 0.0 if f < 4 else max(.55 - .09 * (f - 4), 0)) for f in range(1, N2 + 1)]
    arco("fantasma", 0.26, R2, fant, escala=[(f, 1.0 + 0.012 * max(f - 3, 0) ** 1.5) for f in range(1, N2 + 1)])
    flash = [(f, 1.03, 0.0, 0.7 if f == 4 else 0.0) for f in range(1, N2 + 1)]
    arco("flash", 0.38, R2 + 0.02, flash)
    # estrela do impacto
    mb, _ = b.emissivo("branco", 1.0)
    ix, iy = math.cos(b.rad(-30)) * R2, math.sin(b.rad(-30)) * R2
    for nome, comp, rot in (("estrela_a", 0.36, 20), ("estrela_b", 0.24, 110)):
        o = b.lente(nome, comp, 0.03, mb, 0.1)
        for f in range(1, N2 + 1):
            s = {4: 1.0, 5: 0.6, 6: 0.25}.get(f, 0.0001)
            b.keyar(o, f, loc=(ix, iy, 0.1), esc=(s, s, 1), rot=b.rad(rot))
    # pixels que se desprendem do arco
    random.seed(5)
    for i in range(60):
        o = b.poli("pixel_%02d" % i, [(-.03, -.03), (.03, -.03), (.03, .03), (-.03, .03)], mb, 0.2)
        nasce = random.choice([3, 4, 4, 5, 5, 6])
        vida = random.choice([3, 4, 5, 6])
        a = b.rad(random.uniform(-58, 58))
        r = R2 - random.uniform(0.0, 0.3)
        x0, y0 = math.cos(a) * r, math.sin(a) * r
        d = a + random.uniform(-0.7, 0.7)
        vel = random.uniform(0.03, 0.11)
        for f in range(1, N2 + 1):
            t = f - nasce
            if t < 0 or t >= vida:
                b.keyar(o, f, loc=(x0, y0, 0.2), esc=(0.0001, 0.0001, 1))
                continue
            s = 1.0 if t < vida - 1 else 0.5
            b.keyar(o, f, loc=(x0 + math.cos(d) * vel * t, y0 + math.sin(d) * vel * t - 0.006 * t * t, 0.2), esc=(s, s, 1))


def renderiza():
    cena = bpy.context.scene
    os.makedirs(os.path.join(SAIDA, "saida_ciano"), exist_ok=True)
    cena.render.filepath = os.path.join(SAIDA, "saida_ciano", "quadro_")
    bpy.ops.render.render(animation=True)
    quadros = []
    for f in range(1, N2 + 1):
        img = bpy.data.images.load(os.path.join(SAIDA, "saida_ciano", "quadro_%04d.png" % f))
        img.colorspace_settings.name = "Non-Color"
        img.alpha_mode = "STRAIGHT"
        q = np.array(img.pixels[:], dtype=np.float32).reshape(T2, T2, 4)
        bpy.data.images.remove(img)
        a, rgb = q[..., 3], q[..., :3].mean(axis=2)
        a = np.where(a < 0.14, 0.0, np.round(a * 4.0) / 4.0)             # pixel art: 4 degraus de transparencia
        h = np.where(a > 0, np.round(np.clip(rgb, 0, 1) * 3.0) / 3.0, 0.0)
        o = np.zeros_like(q)
        o[..., 0] = o[..., 1] = o[..., 2] = h
        o[..., 3] = a
        quadros.append(np.repeat(np.repeat(o, ESC, axis=0), ESC, axis=1))      # dobra com pixel nitido
    folha = np.concatenate(quadros, axis=1)
    img = bpy.data.images.new("folha", T2 * ESC * N2, T2 * ESC, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "STRAIGHT"
    img.pixels = folha.reshape(-1).tolist()
    img.filepath_raw = os.path.join(SAIDA, "corte_hazaki_ciano_folha.png")
    img.file_format = "PNG"
    img.save()
    print("FOLHA CIANO OK", img.filepath_raw)


if __name__ == "__main__" and bpy.app.background:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    monta()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SAIDA, "corte_hazaki_ciano.blend"), copy=True)
    renderiza()

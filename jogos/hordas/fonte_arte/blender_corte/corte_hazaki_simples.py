"""Corte SIMPLES da katana (primeira arma do Hazaki): um arco fino e afiado varrendo rapido, flash BRANCO no impacto e poucas faiscas.
Sem katana desenhada, sem fantasmas, sem ondas. 10 quadros, 128x128.

    blender -b -P corte_hazaki_simples.py -- [pasta_de_saida]      (ou monta() no Blender aberto)
Saidas: corte_hazaki_simples.blend, corte_hazaki_simples_folha.png (10x1 = 1280x128, quantizada; RGB = calor, A = intensidade).

Quadros: 1-2 o arco varre (fio fino, ja com a ponta clara)   3 flash branco (corte grosso 100% branco)   4 linha fina cheia
         5-10 a linha afina e some da cauda para a ponta; faiscas curtas saem do ponto de corte nos quadros 3-6.
"""
import math
import os
import random
import sys

import bpy
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\dev\kikiu_cortes\jogos\hordas\fonte_arte\blender_corte"
sys.path.insert(0, AQUI)
import corte_hazaki as b  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAIDA = os.path.abspath(ARGS[0]) if ARGS else AQUI
N3 = 10
R3 = 0.82


def monta():
    b.cena = bpy.context.scene
    b.limpa()
    b.etapa_base()
    cena = bpy.context.scene
    b.lin()
    cena.frame_start, cena.frame_end = 1, N3
    # linha fina: nasce varrendo (quadros 1-2), fica cheia no 4 e some da cauda para a ponta
    m, c, p, i = b.material_rastro("fino")
    b.crescente("fino", 0.10, m, r_ext=R3 + 0.03, perfil=0.5)
    ch = [(1, 0.5, 0.0, 0.9), (2, 1.03, 0.0, 1.0), (3, 1.03, 0.0, 1.0), (4, 1.03, 0.0, 1.0)]
    for f in range(5, N3 + 1):
        t = (f - 4) / (N3 - 4)
        ch.append((f, 1.03, min(t * 1.05, 1.03), max(1.0 - 0.85 * t, 0.0) if f < N3 else 0.0))
    b.keyar_rastro((c, p, i), ch)
    # flash branco: o mesmo arco, grosso, 100% branco, so no quadro 3 (meio quadro no 4)
    mb, nb = b.emissivo("flash_branco", 1.0, 1.0, animado=True)
    b.crescente("flash", 0.34, mb, r_ext=R3 + 0.02, perfil=0.5)
    for f in range(1, N3 + 1):
        nb.outputs[0].default_value = {3: 1.0, 4: 0.5}.get(f, 0.0)
        nb.outputs[0].keyframe_insert("default_value", frame=f)
    # faiscas curtas (quadrados brancos) saindo do arco
    mw, _ = b.emissivo("branco", 1.0)
    random.seed(3)
    for k in range(16):
        o = b.lente("faisca_%02d" % k, 1.0, 0.18, mw, 0.2)
        nasce = random.choice([3, 3, 4, 4, 5])
        vida = random.choice([3, 4, 4, 5])
        a = b.rad(random.uniform(-45, 45))
        x0, y0 = math.cos(a) * R3, math.sin(a) * R3
        d = a + random.uniform(-0.5, 0.5)
        vel = random.uniform(0.07, 0.16)
        comp = random.uniform(0.05, 0.10)
        for f in range(1, N3 + 1):
            t = f - nasce
            if t < 0 or t >= vida:
                b.keyar(o, f, loc=(x0, y0, 0.2), esc=(0.0001, 0.0001, 1), rot=d)
                continue
            s = comp * (1.0 - 0.6 * t / vida)
            b.keyar(o, f, loc=(x0 + math.cos(d) * vel * t, y0 + math.sin(d) * vel * t, 0.2), esc=(s, s * 0.22, 1), rot=d)


def renderiza():
    cena = bpy.context.scene
    os.makedirs(os.path.join(SAIDA, "saida_simples"), exist_ok=True)
    cena.render.filepath = os.path.join(SAIDA, "saida_simples", "quadro_")
    bpy.ops.render.render(animation=True)
    quadros = []
    for f in range(1, N3 + 1):
        img = bpy.data.images.load(os.path.join(SAIDA, "saida_simples", "quadro_%04d.png" % f))
        img.colorspace_settings.name = "Non-Color"
        img.alpha_mode = "STRAIGHT"
        q = np.array(img.pixels[:], dtype=np.float32).reshape(b.TAM, b.TAM, 4)
        bpy.data.images.remove(img)
        quadros.append(b.quantiza(q))
    folha = np.concatenate(quadros, axis=1)
    img = bpy.data.images.new("folha", b.TAM * N3, b.TAM, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "STRAIGHT"
    img.pixels = folha.reshape(-1).tolist()
    img.filepath_raw = os.path.join(SAIDA, "corte_hazaki_simples_folha.png")
    img.file_format = "PNG"
    img.save()
    print("FOLHA SIMPLES OK", img.filepath_raw)


if __name__ == "__main__" and bpy.app.background:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    monta()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SAIDA, "corte_hazaki_simples.blend"), copy=True)
    renderiza()

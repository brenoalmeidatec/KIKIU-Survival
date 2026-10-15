"""Corte da katana do Hazaki, animado no Blender (leve: Cycles emissivo, 128x128, 12 quadros).

Rodar (do PC de casa, sem abrir o Blender):
    blender -b -P corte_hazaki.py -- [pasta_de_saida]

Saidas (padrao: esta pasta):
    corte_hazaki.blend              cena para refazer/ajustar
    saida/quadro_####.png           quadros crus
    corte_hazaki_folha.png          folha 12x1 (1536x128) JA quantizada, a que o jogo usa
O jogo (v2/efeitos.gd) le a folha com RGB = "calor" (0..1, tinge de cor do golpe + branco no fio) e alfa = intensidade.

Como o efeito e feito:
- malha em crescente (mesmo formato do rastro antigo), UV.x = posicao no arco, UV.y = largura;
- material emissivo guiado por 3 valores animados (cabeca, ponta_do_rastro, intensidade): o golpe nasce fino (antecipacao),
  corre rapido pelo arco, e o rastro se desfaz da cauda para a ponta (dissipacao);
- brilho no fio: linha clara na borda externa + clarao em estrela na cabeca da lamina;
- lascas/faiscas: pecinhas emissivas que saem da cabeca da lamina durante o golpe.
Aponta para +x (angulo 0), arco de 125 graus, sentido 'lado = 1' do jogo (de cima para baixo na tela). O jogo espelha para lado = -1.
"""
import math
import os
import random
import sys

import bpy
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAIDA = os.path.abspath(ARGS[0]) if ARGS else AQUI

TAM = 128          # px de cada quadro
N = 12             # quadros
ARCO = math.radians(125.0)
R_EXT = 0.80       # raio externo (a tela vai de -1 a 1; sobra margem para as lascas)
LARG = 0.40        # largura maxima do crescente
random.seed(7)


# ------------------------------------------------------------------ cena limpa
bpy.ops.wm.read_factory_settings(use_empty=True)
cena = bpy.context.scene
cena.frame_start, cena.frame_end = 1, N
cena.render.resolution_x = cena.render.resolution_y = TAM
cena.render.resolution_percentage = 100
cena.render.film_transparent = True
cena.render.engine = "CYCLES"
cena.cycles.device = "CPU"
cena.cycles.samples = 12
cena.cycles.use_denoising = False
cena.cycles.max_bounces = 0
for nome, valor in (("view_transform", "Standard"), ("look", "None")):
    try:
        setattr(cena.view_settings, nome, valor)
    except TypeError:
        pass
cena.render.image_settings.file_format = "PNG"
cena.render.image_settings.color_mode = "RGBA"
cena.render.image_settings.color_depth = "8"
cena.render.use_motion_blur = False
bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"  # chaves lineares (golpe seco)

cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 2.0
cam = bpy.data.objects.new("camera", cam_d)
cam.location = (0, 0, 5)
cena.collection.objects.link(cam)
cena.camera = cam


# ------------------------------------------------------------------ rastro em crescente
def crescente():
    # u = 0 no comeco do corte (cima), 1 no fim (baixo); v = 0 borda interna, 1 borda externa.
    na, nr = 72, 6
    verts, uvs, faces = [], [], []
    meio = ARCO / 2
    for i in range(na + 1):
        u = i / na
        a = meio - u * ARCO                      # +meio (cima) -> -meio (baixo), vista de cima
        t = max(1.0 - (abs(a) / meio) ** 2, 0.0)
        r_int = R_EXT - LARG * (t ** 0.7)
        for j in range(nr + 1):
            v = j / nr
            r = r_int + (R_EXT - r_int) * v
            verts.append((math.cos(a) * r, math.sin(a) * r, 0.0))
            uvs.append((u, v))
    for i in range(na):
        for j in range(nr):
            k = i * (nr + 1) + j
            faces.append((k, k + nr + 1, k + nr + 2, k + 1))
    me = bpy.data.meshes.new("crescente")
    me.from_pydata(verts, [], faces)
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            uv.data[li].uv = uvs[me.loops[li].vertex_index]
    ob = bpy.data.objects.new("crescente", me)
    cena.collection.objects.link(ob)
    return ob


def valor(nt, nome, x, y):
    n = nt.nodes.new("ShaderNodeValue")
    n.label = nome
    n.location = (x, y)
    return n


def mat(nt, op, a, b=None, clamp=False, x=0, y=0):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    n.location = (x, y)
    for idx, src in enumerate((a, b)):
        if src is None:
            continue
        if isinstance(src, (int, float)):
            n.inputs[idx].default_value = src
        else:
            nt.links.new(src, n.inputs[idx])
    return n.outputs[0]


def material_rastro():
    m = bpy.data.materials.new("rastro")
    nt = m.node_tree
    nt.nodes.clear()
    uvn = nt.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uvn.outputs[0], sep.inputs[0])
    u, v = sep.outputs[0], sep.outputs[1]

    cabeca = valor(nt, "cabeca", -600, 300)
    ponta = valor(nt, "ponta_do_rastro", -600, 200)
    inten = valor(nt, "intensidade", -600, 100)
    H, P, I = cabeca.outputs[0], ponta.outputs[0], inten.outputs[0]

    # onde estou no rastro (0 na ponta, 1 na cabeca)
    vao = mat(nt, "MAXIMUM", mat(nt, "SUBTRACT", H, P), 0.02)
    q = mat(nt, "DIVIDE", mat(nt, "SUBTRACT", u, P), vao, clamp=True)
    dentro = mat(nt, "MULTIPLY", mat(nt, "LESS_THAN", u, mat(nt, "ADD", H, 0.004)), mat(nt, "GREATER_THAN", u, P))
    tendencia = mat(nt, "POWER", q, 1.5)

    # perfil de largura: interior transparente, exterior forte
    interior = mat(nt, "MULTIPLY", mat(nt, "POWER", v, 1.5), 0.65)
    base = mat(nt, "ADD", 0.35, interior)
    k = mat(nt, "MULTIPLY", mat(nt, "MULTIPLY", dentro, tendencia), mat(nt, "MULTIPLY", base, I))
    k = mat(nt, "MULTIPLY", k, mat(nt, "MULTIPLY", v, 6.0, clamp=True))  # borda interna some suave

    # brilho no fio: linha clara na borda externa + clarao logo atras da cabeca
    linha = mat(nt, "MULTIPLY", mat(nt, "SUBTRACT", v, 0.78), 4.5, clamp=True)
    d = mat(nt, "SUBTRACT", H, u)
    clarao = mat(nt, "EXPONENT", mat(nt, "MULTIPLY", mat(nt, "MULTIPLY", mat(nt, "DIVIDE", d, 0.05), mat(nt, "DIVIDE", d, 0.05)), -1.0))
    clarao = mat(nt, "MULTIPLY", clarao, mat(nt, "MULTIPLY", dentro, I))
    k = mat(nt, "ADD", k, mat(nt, "MULTIPLY", mat(nt, "MULTIPLY", linha, dentro), mat(nt, "MULTIPLY", tendencia, I)))
    k = mat(nt, "ADD", k, mat(nt, "MULTIPLY", clarao, 0.8), clamp=True)

    calor = mat(nt, "ADD", mat(nt, "MULTIPLY", mat(nt, "POWER", q, 2.5), mat(nt, "POWER", v, 1.0)),
                mat(nt, "ADD", mat(nt, "MULTIPLY", linha, 0.55), clarao), clamp=True)

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
    return m, cabeca, ponta, inten


def material_emissivo(nome, radial=False):
    m = bpy.data.materials.new(nome)
    nt = m.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1, 1, 1, 1)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    if radial:  # disco de brilho macio
        tc = nt.nodes.new("ShaderNodeTexCoord")
        gr = nt.nodes.new("ShaderNodeTexGradient")
        gr.gradient_type = "QUADRATIC_SPHERE"
        nt.links.new(tc.outputs["Object"], gr.inputs[0])
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(gr.outputs[0], mix.inputs[0])
        nt.links.new(tr.outputs[0], mix.inputs[1])
        nt.links.new(em.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs[0])
    else:
        nt.links.new(em.outputs[0], out.inputs[0])
    return m


def plano(nome, w, h, material):
    me = bpy.data.meshes.new(nome)
    me.from_pydata([(-w, -h, 0), (w, -h, 0), (w, h, 0), (-w, h, 0)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new(nome, me)
    ob.data.materials.append(material)
    cena.collection.objects.link(ob)
    return ob


# ------------------------------------------------------------------ animacao
rastro = crescente()
m_rastro, v_cabeca, v_ponta, v_inten = material_rastro()
rastro.data.materials.append(m_rastro)

# (quadro, cabeca, ponta_do_rastro, intensidade): antecipacao (1-2), golpe (3-6), dissipacao (7-12)
CHAVES = [
    (1, 0.02, 0.00, 0.30), (2, 0.07, 0.00, 0.50),                                    # antecipacao: fio fino se armando
    (3, 0.32, 0.00, 1.00), (4, 0.64, 0.00, 1.00), (5, 0.93, 0.03, 1.00), (6, 1.03, 0.14, 1.00),
    (7, 1.03, 0.26, 0.95), (8, 1.03, 0.42, 0.80), (9, 1.03, 0.60, 0.62), (10, 1.03, 0.78, 0.45),
    (11, 1.03, 0.92, 0.28), (12, 1.03, 1.02, 0.12),
]
for f, c, p, i in CHAVES:
    for no, val in ((v_cabeca, c), (v_ponta, p), (v_inten, i)):
        no.outputs[0].default_value = val
        no.outputs[0].keyframe_insert("default_value", frame=f)


def pos_cabeca(u, raio=R_EXT):
    a = ARCO / 2 - u * ARCO
    return math.cos(a) * raio, math.sin(a) * raio, a


def keyar(ob, f, loc=None, esc=None, rot=None):
    if loc is not None:
        ob.location = loc
        ob.keyframe_insert("location", frame=f)
    if esc is not None:
        ob.scale = esc
        ob.keyframe_insert("scale", frame=f)
    if rot is not None:
        ob.rotation_euler = (0, 0, rot)
        ob.keyframe_insert("rotation_euler", frame=f)


# clarao em estrela + disco na cabeca da lamina
m_branco = material_emissivo("branco")
m_disco = material_emissivo("disco", radial=True)
estr1 = plano("estrela_a", 1.0, 0.07, m_branco)
estr2 = plano("estrela_b", 0.07, 0.7, m_branco)
disco = plano("disco", 1.0, 1.0, m_disco)
cabeca_u = {f: c for f, c, _, _ in CHAVES}
for f in range(1, N + 1):
    u = min(cabeca_u[f], 1.0)
    x, y, a = pos_cabeca(u, R_EXT - 0.04)
    forca = {1: 0.0, 2: 0.25, 3: 0.55, 4: 0.8, 5: 1.0, 6: 0.9, 7: 0.55, 8: 0.25}.get(f, 0.0)
    # a estrela gira junto com o corte
    for ob, base, rot in ((estr1, 0.20, a), (estr2, 0.20, a + math.pi / 2), (disco, 0.11, 0.0)):
        s = max(forca * base, 0.0001)
        keyar(ob, f, loc=(x, y, 0.1), esc=(s, s, 1), rot=rot)

# lascas/faiscas saindo da cabeca durante o golpe
LASCAS = 16
for i in range(LASCAS):
    ob = plano("lasca_%02d" % i, 1.0, 0.18, m_branco)
    nasce = random.choice([4, 4, 5, 5, 5, 6, 6, 7])
    vida = random.choice([3, 4, 4, 5])
    u0 = min(cabeca_u[nasce], 1.0)
    x0, y0, a0 = pos_cabeca(u0, R_EXT - random.uniform(0.0, 0.1))
    saida = a0 + random.uniform(-0.55, 0.55)                       # para fora do arco, espalhando
    vel = random.uniform(0.07, 0.16)
    comp = random.uniform(0.05, 0.11)
    for f in range(1, N + 1):
        t = f - nasce
        if t < 0 or t >= vida:
            keyar(ob, f, loc=(x0, y0, 0.2), esc=(0.0001, 0.0001, 1), rot=saida)
            continue
        vida_k = 1.0 - t / vida
        px = x0 + math.cos(saida) * vel * t - 0.005 * t * t
        py = y0 + math.sin(saida) * vel * t - 0.012 * t * t         # cai um pouco: peso de lasca
        s = comp * (0.4 + 0.6 * vida_k)
        keyar(ob, f, loc=(px, py, 0.2), esc=(s, s * 0.45, 1), rot=saida)

# ------------------------------------------------------------------ renderiza e monta a folha
os.makedirs(os.path.join(SAIDA, "saida"), exist_ok=True)
cena.render.filepath = os.path.join(SAIDA, "saida", "quadro_")
bpy.ops.render.render(animation=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SAIDA, "corte_hazaki.blend"), copy=True)


def le(caminho):
    img = bpy.data.images.load(caminho)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "STRAIGHT"
    a = np.array(img.pixels[:], dtype=np.float32).reshape(TAM, TAM, 4)
    bpy.data.images.remove(img)
    return a


def quantiza(q):
    a, rgb = q[..., 3], q[..., :3].mean(axis=2)
    a = np.where(a < 0.09, 0.0, np.round(a * 6.0) / 6.0)       # 7 degraus de intensidade
    h = np.round(np.clip(rgb, 0, 1) * 3.0) / 3.0                  # 4 degraus de calor
    h = np.where(a > 0, h, 0.0)
    out = np.zeros_like(q)
    out[..., 0] = out[..., 1] = out[..., 2] = h
    out[..., 3] = a
    return out


quadros = [quantiza(le(os.path.join(SAIDA, "saida", "quadro_%04d.png" % f))) for f in range(1, N + 1)]
folha = np.concatenate(quadros, axis=1)
img = bpy.data.images.new("folha", TAM * N, TAM, alpha=True)
img.colorspace_settings.name = "Non-Color"
img.alpha_mode = "STRAIGHT"
img.pixels = folha.reshape(-1).tolist()
img.filepath_raw = os.path.join(SAIDA, "corte_hazaki_folha.png")
img.file_format = "PNG"
img.save()
print("FOLHA OK", img.filepath_raw)

"""Corte da katana do Hazaki, animado no Blender (leve: Cycles so com emissao, 128x128, 16 quadros).

Rodar (sem abrir o Blender):
    blender -b -P corte_hazaki.py -- [pasta_de_saida]
Ou, no Blender aberto, importar o modulo e chamar monta_tudo() (ou as etapas: limpa, etapa_base, etapa_katana, etapa_fio, etapa_faiscas).

Saidas: corte_hazaki.blend, corte_hazaki_folha.png (16x1 = 2048x128, JA quantizada, a que o jogo usa).
O jogo (v2/efeitos.gd) le a folha com RGB = "calor" (0..1: tinge de cor do golpe e vai ao branco no fio) e alfa = intensidade.

Linha do tempo (quadro: o que acontece):
    1-3   antecipacao: a katana se arma para tras, um brilho corre pelo fio
    4-6   golpe: a katana passa MUITO rapido, com imagens-fantasma atras e um rastro fino colado na ponta
    7-8   impacto (congelado 2 quadros): flash branco, o corte grosso e a linha fina de anime surgem de uma vez, estrela e anel de choque
    9-16  a linha afina e some da cauda para a ponta, o anel abre, as lascas voam e a katana some
Aponta para +x (angulo 0), arco de 125 graus, sentido 'lado = 1' do jogo (de cima para baixo na tela); o jogo espelha para lado = -1.
"""
import math
import os
import random
import sys

import bpy
import numpy as np

try:
    AQUI = os.path.dirname(os.path.abspath(__file__))
except NameError:
    AQUI = r"D:\dev\kikiu_cortes\jogos\hordas\fonte_arte\blender_corte"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAIDA = os.path.abspath(ARGS[0]) if ARGS else AQUI

TAM = 128
N = 16
ARCO = math.radians(125.0)
MEIO = ARCO / 2
R_EXT = 0.80
IMPACTO = 7                       # quadro do impacto (o dano do jogo cai por volta do 7)
ANG = {1: 100, 2: 116, 3: 124, 4: 70, 5: 5, 6: -55, 7: -90, 8: -96, 9: -98}   # graus da katana por quadro
cena = bpy.context.scene


def lin():
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"


def rad(g):
    return math.radians(g)


def ang_katana(f):
    return ANG.get(f, ANG[9])


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


# ------------------------------------------------------------------ materiais
def valor(nt, nome):
    n = nt.nodes.new("ShaderNodeValue")
    n.label = nome
    return n


def mat(nt, op, a, b=None, clamp=False):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    for idx, src in enumerate((a, b)):
        if src is None:
            continue
        if isinstance(src, (int, float)):
            n.inputs[idx].default_value = src
        else:
            nt.links.new(src, n.inputs[idx])
    return n.outputs[0]


def emissivo(nome, calor, alfa=1.0, animado=False):
    """Emissivo cinza (calor 0..1) com alfa fixo ou animado (devolve o no 'alfa' para keyar)."""
    m = bpy.data.materials.new(nome)
    nt = m.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (calor, calor, calor, 1)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    if alfa >= 1.0 and not animado:
        nt.links.new(em.outputs[0], out.inputs[0])
        return m, None
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    no = valor(nt, "alfa")
    no.outputs[0].default_value = alfa
    nt.links.new(no.outputs[0], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    return m, no


def material_rastro(nome):
    m = bpy.data.materials.new(nome)
    nt = m.node_tree
    nt.nodes.clear()
    uvn = nt.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "UVMap"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uvn.outputs[0], sep.inputs[0])
    u, v = sep.outputs[0], sep.outputs[1]
    cabeca, ponta, inten = valor(nt, "cabeca"), valor(nt, "ponta_do_rastro"), valor(nt, "intensidade")
    H, P, I = cabeca.outputs[0], ponta.outputs[0], inten.outputs[0]
    vao = mat(nt, "MAXIMUM", mat(nt, "SUBTRACT", H, P), 0.02)
    q = mat(nt, "DIVIDE", mat(nt, "SUBTRACT", u, P), vao, clamp=True)
    dentro = mat(nt, "MULTIPLY", mat(nt, "LESS_THAN", u, mat(nt, "ADD", H, 0.004)), mat(nt, "GREATER_THAN", u, P))
    tend = mat(nt, "POWER", q, 1.2)
    interior = mat(nt, "MULTIPLY", mat(nt, "POWER", v, 1.5), 0.65)
    base = mat(nt, "ADD", 0.35, interior)
    k = mat(nt, "MULTIPLY", mat(nt, "MULTIPLY", dentro, tend), mat(nt, "MULTIPLY", base, I))
    k = mat(nt, "MULTIPLY", k, mat(nt, "MULTIPLY", v, 6.0, clamp=True))
    linha = mat(nt, "MULTIPLY", mat(nt, "SUBTRACT", v, 0.70), 3.3, clamp=True)       # fio claro na borda externa
    d = mat(nt, "SUBTRACT", H, u)
    clarao = mat(nt, "EXPONENT", mat(nt, "MULTIPLY", mat(nt, "MULTIPLY", mat(nt, "DIVIDE", d, 0.05), mat(nt, "DIVIDE", d, 0.05)), -1.0))
    clarao = mat(nt, "MULTIPLY", clarao, mat(nt, "MULTIPLY", dentro, I))
    k = mat(nt, "ADD", k, mat(nt, "MULTIPLY", mat(nt, "MULTIPLY", linha, dentro), mat(nt, "MULTIPLY", tend, I)))
    k = mat(nt, "ADD", k, mat(nt, "MULTIPLY", clarao, 0.8), clamp=True)
    calor = mat(nt, "ADD", mat(nt, "MULTIPLY", mat(nt, "POWER", q, 1.5), mat(nt, "POWER", v, 0.7)),
                mat(nt, "ADD", mat(nt, "MULTIPLY", linha, 0.6), clarao), clamp=True)
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


def keyar_rastro(nos, chaves):
    cab, pon, ite = nos
    for f, c, p, i in chaves:
        for no, val in ((cab, c), (pon, p), (ite, i)):
            no.outputs[0].default_value = val
            no.outputs[0].keyframe_insert("default_value", frame=f)


# ------------------------------------------------------------------ geometria
def poli(nome, pts, material, z=0.0):
    me = bpy.data.meshes.new(nome)
    me.from_pydata([(x, y, 0) for x, y in pts], [], [tuple(range(len(pts)))])
    ob = bpy.data.objects.new(nome, me)
    ob.data.materials.append(material)
    ob.location.z = z
    cena.collection.objects.link(ob)
    return ob


def lente(nome, comp, larg, material, z=0.0):
    """Losango fino e afiado nas duas pontas, centrado na origem, ao longo de +x."""
    return poli(nome, [(-comp, 0), (0, larg), (comp, 0), (0, -larg)], material, z)


def anel(nome, r_ext, r_int, material, n=48):
    me = bpy.data.meshes.new(nome)
    vs, fs = [], []
    for i in range(n):
        a = math.tau * i / n
        vs += [(math.cos(a) * r_ext, math.sin(a) * r_ext, 0), (math.cos(a) * r_int, math.sin(a) * r_int, 0)]
    for i in range(n):
        j = (i + 1) % n
        fs.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    me.from_pydata(vs, [], fs)
    ob = bpy.data.objects.new(nome, me)
    ob.data.materials.append(material)
    cena.collection.objects.link(ob)
    return ob


def crescente(nome, larg, material, r_ext=R_EXT, perfil=0.5):
    na, nr = 72, 6
    verts, uvs, faces = [], [], []
    for i in range(na + 1):
        u = i / na
        a = MEIO - u * ARCO
        t = max(1.0 - (abs(a) / MEIO) ** 2, 0.0)
        r_int = r_ext - larg * (t ** perfil)
        for j in range(nr + 1):
            v = j / nr
            r = r_int + (r_ext - r_int) * v
            verts.append((math.cos(a) * r, math.sin(a) * r, 0.0))
            uvs.append((u, v))
    for i in range(na):
        for j in range(nr):
            k = i * (nr + 1) + j
            faces.append((k, k + nr + 1, k + nr + 2, k + 1))
    me = bpy.data.meshes.new(nome)
    me.from_pydata(verts, [], faces)
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            uv.data[li].uv = uvs[me.loops[li].vertex_index]
    ob = bpy.data.objects.new(nome, me)
    ob.data.materials.append(material)
    cena.collection.objects.link(ob)
    return ob


# ------------------------------------------------------------------ etapas
def limpa():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for bloco in (bpy.data.meshes, bpy.data.materials, bpy.data.actions):
        for it in list(bloco):
            bloco.remove(it)


def etapa_base():
    """Cena, camera ortografica de cima e render leve."""
    lin()
    cena.frame_start, cena.frame_end = 1, N
    cena.render.resolution_x = cena.render.resolution_y = TAM
    cena.render.resolution_percentage = 100
    cena.render.film_transparent = True
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = 12
    cena.cycles.use_denoising = False
    cena.cycles.max_bounces = 0
    for nome, valor_ in (("view_transform", "Standard"), ("look", "None")):
        try:
            setattr(cena.view_settings, nome, valor_)
        except TypeError:
            pass
    cena.render.image_settings.file_format = "PNG"
    cena.render.image_settings.color_mode = "RGBA"
    cena.render.image_settings.color_depth = "8"
    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cd.ortho_scale = 2.0
    cam = bpy.data.objects.new("camera", cd)
    cam.location = (0, 0, 5)
    cena.collection.objects.link(cam)
    cena.camera = cam


def lamina_katana(sufixo, calor_corpo, calor_fio, alfa, animado=False):
    """Katana (lamina + fio + lombada + cabo + tsuba) filha de um pivo na origem; devolve (pivo, nos_de_alfa)."""
    piv = bpy.data.objects.new("pivo_katana" + sufixo, None)
    cena.collection.objects.link(piv)
    m_corpo, n1 = emissivo("lamina" + sufixo, calor_corpo, alfa, animado)
    m_fio, n2 = emissivo("fio" + sufixo, calor_fio, alfa, animado)
    m_cabo, n3 = emissivo("cabo" + sufixo, calor_corpo * 0.5, alfa, animado)
    pecas = [
        poli("lamina" + sufixo, [(0.20, 0.024), (0.80, 0.022), (0.90, 0.0), (0.87, -0.013), (0.20, -0.024)], m_corpo),
        poli("fio" + sufixo, [(0.22, -0.013), (0.86, -0.011), (0.87, -0.013), (0.20, -0.024)], m_fio, 0.01),
        poli("lombada" + sufixo, [(0.20, 0.024), (0.80, 0.022), (0.80, 0.015), (0.20, 0.015)], m_fio, 0.01),
        poli("cabo" + sufixo, [(0.00, 0.020), (0.19, 0.017), (0.19, -0.017), (0.00, -0.020)], m_cabo),
        poli("tsuba" + sufixo, [(0.185, 0.055), (0.215, 0.055), (0.215, -0.055), (0.185, -0.055)], m_fio, 0.01),
    ]
    for p in pecas:
        p.parent = piv
    return piv, [n for n in (n1, n2, n3) if n is not None]


def etapa_katana():
    """A katana passando na frente (3 imagens-fantasma atras) e o brilho correndo no fio."""
    lin()
    piv, _ = lamina_katana("", 0.66, 1.0, 1.0)
    for f in range(1, N + 1):
        keyar(piv, f, esc=(1, 1, 1) if f <= 9 else (0.0001, 0.0001, 1), rot=rad(ang_katana(f)))
    # fantasmas: a mesma katana alguns quadros atras, mais fracos (efeito de velocidade)
    for lag, calor, alfa in ((1, 0.66, 0.6),):
        g, _ = lamina_katana("_f%d" % lag, calor, calor, alfa)
        for f in range(1, N + 1):
            fa = f - lag
            vis = 5 <= f <= 7 and fa >= 3
            keyar(g, f, esc=(1, 1, 1) if vis else (0.0001, 0.0001, 1), rot=rad(ang_katana(max(fa, 1))))
    # brilho que corre pelo fio nos quadros 3-4 (a lamina "lampeja" antes de cortar)
    m_br, _ = emissivo("brilho_fio", 1.0)
    br = lente("brilho_fio", 0.07, 0.03, m_br, 0.05)
    piv_br = bpy.data.objects.new("pivo_brilho", None)
    cena.collection.objects.link(piv_br)
    br.parent = piv_br
    for f in range(1, N + 1):
        a = rad(ang_katana(f))
        x = {3: 0.35, 4: 0.78}.get(f)
        keyar(piv_br, f, rot=a)
        keyar(br, f, loc=(x if x else 0.5, 0, 0.05), esc=(1, 1, 1) if x else (0.0001, 0.0001, 1))


def etapa_fio():
    """O fio da katana: arco fino e afiado colado na ponta da lamina (cresce com ela), flash branco no fim da passada e some da cauda para a ponta."""
    lin()
    m, c, p, i = material_rastro("fio_arco")
    crescente("fio_arco", 0.10, m, r_ext=R_EXT + 0.03, perfil=0.5)
    ch = []
    for f in range(1, N + 1):
        u = min(max((math.degrees(MEIO) - ang_katana(f)) / math.degrees(ARCO), 0.0), 1.03)
        if f < 4:
            ch.append((f, 0.0, 0.0, 0.0))
        elif f <= IMPACTO:
            ch.append((f, u, 0.0, 1.0))
        else:
            t = (f - IMPACTO) / (N - IMPACTO)
            ch.append((f, 1.03, min(t * 1.1, 1.03), max(1.0 - 0.85 * t, 0.0) if f < N else 0.0))
    keyar_rastro((c, p, i), ch)
    # flash branco: o mesmo arco, grosso, 100% branco, so no quadro do impacto
    mb, nb = emissivo("flash_branco", 1.0, 1.0, animado=True)
    crescente("flash", 0.34, mb, r_ext=R_EXT + 0.02, perfil=0.5)
    for f in range(1, N + 1):
        nb.outputs[0].default_value = 1.0 if f == IMPACTO else 0.0
        nb.outputs[0].keyframe_insert("default_value", frame=f)


def etapa_faiscas():
    """Lascas e faiscas: rajada no impacto, riscos compridos e pontinhos que sobem."""
    lin()
    random.seed(7)
    m_b, _ = emissivo("branco_fx", 1.0)
    ix, iy = math.cos(rad(-35)) * R_EXT, math.sin(rad(-35)) * R_EXT
    for i in range(44):
        longo = i < 28
        ob = lente("fasca_%02d" % i, 1.0, 0.16 if longo else 0.5, m_b, 0.2)
        nasce = random.choice([IMPACTO, IMPACTO, IMPACTO, IMPACTO + 1, IMPACTO + 1, IMPACTO + 2])
        vida = random.choice([3, 4, 5, 6]) if longo else random.choice([4, 6, 8])
        a_arc = rad(random.uniform(-62, 62) * 0.9)
        x0 = math.cos(a_arc) * (R_EXT - random.uniform(0, 0.08))
        y0 = math.sin(a_arc) * (R_EXT - random.uniform(0, 0.08))
        if i < 18:                                   # parte nasce no ponto do choque
            x0, y0 = ix + random.uniform(-0.05, 0.05), iy + random.uniform(-0.05, 0.05)
        dir_ = a_arc + random.uniform(-0.6, 0.6) if i >= 18 else random.uniform(0, math.tau)
        vel = random.uniform(0.09, 0.20) if longo else random.uniform(0.02, 0.05)
        comp = random.uniform(0.06, 0.13) if longo else random.uniform(0.012, 0.025)
        for f in range(1, N + 1):
            t = f - nasce
            if t < 0 or t >= vida:
                keyar(ob, f, loc=(x0, y0, 0.2), esc=(0.0001, 0.0001, 1), rot=dir_)
                continue
            vk = 1.0 - t / vida
            px = x0 + math.cos(dir_) * vel * t
            py = y0 + math.sin(dir_) * vel * t + (0.012 * t if not longo else -0.008 * t * t)
            s = comp * (0.5 + 0.5 * vk)
            keyar(ob, f, loc=(px, py, 0.2), esc=(s, s * 0.2 if longo else s, 1), rot=dir_)


def monta_tudo():
    limpa()
    etapa_base()
    etapa_katana()
    etapa_fio()
    etapa_faiscas()


# ------------------------------------------------------------------ render + folha
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


def renderiza_e_monta():
    os.makedirs(os.path.join(SAIDA, "saida"), exist_ok=True)
    cena.render.filepath = os.path.join(SAIDA, "saida", "quadro_")
    bpy.ops.render.render(animation=True)
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


if __name__ == "__main__" and bpy.app.background:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cena = bpy.context.scene
    monta_tudo()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SAIDA, "corte_hazaki.blend"), copy=True)
    renderiza_e_monta()

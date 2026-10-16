"""Efeitos inspirados no video de referencia KiKiu (docs/visual_2_5d/referencia_kikiu/ANALISE.md), feitos do zero no Blender.

    blender -b -P efeitos_kikiu.py -- <pasta_de_saida> [nome ...]
    (ou python efeitos_kikiu.py -- ... com o modulo bpy)

Mesmo formato do corte ciano (blender_corte/corte_hazaki_ciano.py): render 64x64 so com emissao, sem suavizacao, quantizado
(4 degraus de alfa, 4 de calor) e dobrado (nearest) para 128x128 = pixel de 2 px. A folha guarda RGB = calor e A = intensidade;
o shader do jogo tinge com a cor do efeito (mix(cor, branco, calor*0.55), blend add).

Efeitos (referencia da ANALISE.md):
  cristal  M6  bola branca com halo 3 q -> estouro de espinhos finos em 1-2 q -> anel + polvilho          14 quadros
  estrela  A2  estrela de 4 pontas 2-3 q -> anel curto -> lascas finas que voam e somem                    9 quadros
  anel     M2  esfera carregando -> nucleo branco estoura -> anel DUPLO cresce ~2x em 4-5 q e fica -> desfaz 18 quadros
  espiral  V1  redemoinho de vento no pe do heroi: 3 arcos que giram, afinam e somem                       12 quadros
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
PEDIDOS = ARGS[1:]
T, ESC = 64, 2

cena = None


# ------------------------------------------------------------------ base
def limpa():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for bloco in (bpy.data.meshes, bpy.data.materials, bpy.data.actions, bpy.data.cameras):
        for it in list(bloco):
            bloco.remove(it)


def base(n):
    global cena
    cena = bpy.context.scene
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    cena.frame_start, cena.frame_end = 1, n
    cena.render.resolution_x = cena.render.resolution_y = T
    cena.render.resolution_percentage = 100
    cena.render.film_transparent = True
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = 4
    cena.cycles.filter_width = 0.01
    cena.cycles.use_denoising = False
    cena.cycles.max_bounces = 0
    cena.view_settings.view_transform = "Standard"
    cena.render.image_settings.file_format = "PNG"
    cena.render.image_settings.color_mode = "RGBA"
    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cd.ortho_scale = 2.0
    cam = bpy.data.objects.new("camera", cd)
    cam.location = (0, 0, 5)
    cena.collection.objects.link(cam)
    cena.camera = cam


def material(nome, calor):
    """Emissivo cinza (calor 0..1) com alfa animavel; devolve (material, socket do alfa)."""
    m = bpy.data.materials.new(nome)
    nt = m.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (calor, calor, calor, 1)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    alfa = nt.nodes.new("ShaderNodeValue")
    alfa.outputs[0].default_value = 1.0
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(alfa.outputs[0], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    return m, alfa.outputs[0]


def malha(nome, verts, faces, calor, z=0.0):
    me = bpy.data.meshes.new(nome)
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new(nome, me)
    m, alfa = material(nome, calor)
    ob.data.materials.append(m)
    ob.location.z = z
    cena.collection.objects.link(ob)
    return ob, alfa


def poli(nome, pts, calor, z=0.0):
    return malha(nome, [(x, y, 0) for x, y in pts], [tuple(range(len(pts)))], calor, z)


def lente(nome, comp, larg, calor, z=0.0, atras=None):
    """Losango fino ao longo de +x; 'atras' encurta a ponta de tras (espinho que nasce no centro)."""
    a = comp if atras is None else atras
    return poli(nome, [(-a, 0), (0, larg), (comp, 0), (0, -larg)], calor, z)


def disco(nome, r, calor, z=0.0, n=32):
    return poli(nome, [(math.cos(math.tau * i / n) * r, math.sin(math.tau * i / n) * r) for i in range(n)], calor, z)


def anel(nome, r_ext, r_int, calor, z=0.0, n=48, a0=0.0, a1=math.tau):
    vs, fs = [], []
    fechado = abs(a1 - a0 - math.tau) < 1e-6
    passos = n if fechado else n + 1
    for i in range(passos):
        a = a0 + (a1 - a0) * i / n
        vs += [(math.cos(a) * r_ext, math.sin(a) * r_ext, 0), (math.cos(a) * r_int, math.sin(a) * r_int, 0)]
    for i in range(n):
        j = (i + 1) % passos
        fs.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    return malha(nome, vs, fs, calor, z)


def chave(ob, alfa, f, a=None, loc=None, esc=None, rot=None):
    if a is not None:
        alfa.default_value = a
        alfa.keyframe_insert("default_value", frame=f)
    if loc is not None:
        ob.location = (loc[0], loc[1], ob.location.z)
        ob.keyframe_insert("location", frame=f)
    if esc is not None:
        ob.scale = (esc, esc, 1) if isinstance(esc, (int, float)) else (esc[0], esc[1], 1)
        ob.keyframe_insert("scale", frame=f)
    if rot is not None:
        ob.rotation_euler = (0, 0, rot)
        ob.keyframe_insert("rotation_euler", frame=f)


def some_fora(ob, alfa, n, vivo):
    """Alfa 0 e escala minima fora do intervalo [ini, fim] de quadros."""
    ini, fim = vivo
    for f in range(1, n + 1):
        if f < ini or f > fim:
            chave(ob, alfa, f, a=0.0, esc=0.0001)


def polvilho(prefixo, n, qtd, nasce, vida, r0, r1, calor, semente, gravidade=0.0, giro=0.0):
    """Pixels quadrados que saem do raio r0 ate r1 e piscam ao sumir (o 'polvilho' do fim das explosoes)."""
    rnd = random.Random(semente)
    for i in range(qtd):
        d = rnd.uniform(0, math.tau)
        lado = rnd.choice((0.022, 0.032, 0.032, 0.045))
        o, al = poli("%s_%02d" % (prefixo, i), [(-lado, -lado), (lado, -lado), (lado, lado), (-lado, lado)], calor, 0.3)
        ini = nasce + rnd.randint(0, 2)
        dur = vida + rnd.randint(-1, 2)
        alvo = rnd.uniform(r0 + (r1 - r0) * 0.5, r1)
        for f in range(1, n + 1):
            t = f - ini
            if t < 0 or t > dur:
                chave(o, al, f, a=0.0, esc=0.0001)
                continue
            u = t / max(dur, 1)
            r = r0 + (alvo - r0) * (1 - (1 - u) ** 2)
            a = d + giro * u
            pisca = 1.0 if (t < dur - 2 or t % 2 == 0) else 0.35
            chave(o, al, f, a=pisca * (1 - 0.5 * u), loc=(math.cos(a) * r, math.sin(a) * r - gravidade * t * t), esc=1.0 if u < 0.7 else 0.7)


# ------------------------------------------------------------------ efeitos
def cristal():
    """M6: bola branca com halo -> estouro de espinhos finos (cristal quebrando) -> anel fino + polvilho."""
    n = 14
    base(n)
    bola, ab = disco("bola", 0.16, 1.0, 0.2)
    halo, ah = anel("halo", 0.27, 0.20, 0.45, 0.1)
    for f, s, a in ((1, 0.6, 0.8), (2, 0.85, 1.0), (3, 1.0, 1.0), (4, 1.25, 1.0), (5, 0.6, 0.7), (6, 0.2, 0.3)):
        chave(bola, ab, f, a=a, esc=s)
        chave(halo, ah, f, a=0.0 if f >= 4 else 0.7, esc=s * 1.05)
    some_fora(bola, ab, n, (1, 6))
    some_fora(halo, ah, n, (1, 3))
    rnd = random.Random(7)
    k = 16
    for i in range(k):
        ang = math.tau * i / k + rnd.uniform(-0.12, 0.12)
        comp = rnd.uniform(0.62, 0.92) if i % 2 == 0 else rnd.uniform(0.38, 0.55)   # espinhos alternados longo/curto
        o, al = lente("espinho_%02d" % i, comp, 0.045 if i % 2 == 0 else 0.035, 0.6 if i % 2 == 0 else 0.3, 0.15, atras=0.05)
        o.rotation_euler = (0, 0, ang)
        for f in range(1, n + 1):
            if f < 4:
                chave(o, al, f, a=0.0, esc=0.0001, rot=ang)
            elif f == 4:
                chave(o, al, f, a=1.0, esc=(0.55, 1.4), rot=ang)       # estoura em 1 quadro, grosso
            elif f <= 10:
                u = (f - 4) / 6
                chave(o, al, f, a=1.0 - 0.75 * u, esc=(0.55 + 0.6 * (1 - (1 - u) ** 2), 1.2 - 0.9 * u), rot=ang)
            else:
                chave(o, al, f, a=0.0, esc=0.0001, rot=ang)
    onda, ao = anel("onda", 1.0, 0.93, 0.0, 0.05, n=64)
    for f in range(1, n + 1):
        if 4 <= f <= 10:
            u = (f - 4) / 6
            chave(onda, ao, f, a=0.8 * (1 - u), esc=0.3 + 0.62 * (1 - (1 - u) ** 2))
        else:
            chave(onda, ao, f, a=0.0, esc=0.0001)
    polvilho("polvilho", n, 22, 5, 8, 0.25, 0.9, 0.6, 11)
    return n


def estrela():
    """A2/M3: estrela de impacto de 4 pontas (2 longas, 2 curtas) que nasce cheia, afina e gira um pouco; anel curto e lascas."""
    n = 9
    base(n)
    longas = []
    for i, (ang, comp, larg) in enumerate(((0, 0.78, 0.075), (math.pi / 2, 0.62, 0.07), (math.pi / 4, 0.36, 0.05), (-math.pi / 4, 0.36, 0.05))):
        o, al = lente("ponta_%d" % i, comp, larg, 0.67 if i < 2 else 0.33, 0.2)
        longas.append((o, al, ang))
    for o, al, ang in longas:
        for f, sx, sy, a in ((1, 0.75, 1.3, 1.0), (2, 1.0, 1.0, 1.0), (3, 1.05, 0.6, 1.0), (4, 0.9, 0.35, 0.75), (5, 0.6, 0.2, 0.4)):
            chave(o, al, f, a=a, esc=(sx, sy), rot=ang + 0.06 * (f - 1))
        some_fora(o, al, n, (1, 5))
    nucleo, an = disco("nucleo", 0.14, 1.0, 0.25)
    for f, s, a in ((1, 1.3, 1.0), (2, 1.0, 1.0), (3, 0.6, 0.8)):
        chave(nucleo, an, f, a=a, esc=s)
    some_fora(nucleo, an, n, (1, 3))
    onda, ao = anel("onda", 1.0, 0.86, 0.0, 0.1, n=48)
    for f, s, a in ((2, 0.25, 0.9), (3, 0.42, 0.7), (4, 0.52, 0.45), (5, 0.58, 0.2)):
        chave(onda, ao, f, a=a, esc=s)
    some_fora(onda, ao, n, (2, 5))
    rnd = random.Random(3)
    for i in range(7):
        d = rnd.uniform(0, math.tau)
        o, al = lente("lasca_%d" % i, 0.07, 0.018, 0.35, 0.15)
        for f in range(1, n + 1):
            t = f - 2
            if t < 0 or t > 6:
                chave(o, al, f, a=0.0, esc=0.0001, rot=d)
                continue
            r = 0.15 + 0.7 * (1 - (1 - t / 6) ** 2)
            chave(o, al, f, a=1.0 - t / 7, loc=(math.cos(d) * r, math.sin(d) * r), esc=(1.6 - 0.15 * t, 1.0), rot=d)
    return n


def anel_duplo():
    """M2: esfera carregando -> nucleo branco estoura -> anel DUPLO nasce, cresce ~2x e fica pulsando com particulas dentro -> desfaz."""
    n = 18
    base(n)
    esfera, ae = disco("esfera", 0.2, 0.35, 0.1)
    casca, ac = anel("casca", 0.22, 0.17, 0.7, 0.15)
    for f, s, a in ((1, 0.7, 0.7), (2, 0.85, 0.85), (3, 0.95, 1.0), (4, 0.8, 1.0)):
        chave(esfera, ae, f, a=a, esc=s)
        chave(casca, ac, f, a=a, esc=s)
    some_fora(esfera, ae, n, (1, 4))
    some_fora(casca, ac, n, (1, 4))
    nucleo, an = disco("nucleo", 0.16, 1.0, 0.3)
    for f, s, a in ((4, 0.6, 1.0), (5, 1.6, 1.0), (6, 0.9, 0.6)):
        chave(nucleo, an, f, a=a, esc=s)
    some_fora(nucleo, an, n, (4, 6))
    # dois aneis concentricos: o externo mais fino e mais quente na borda
    ext, a1 = anel("anel_ext", 1.0, 0.9, 0.33, 0.2, n=64)
    inn, a2 = anel("anel_int", 0.76, 0.64, 0.0, 0.2, n=64)
    for f in range(1, n + 1):
        if f < 5:
            chave(ext, a1, f, a=0.0, esc=0.0001)
            chave(inn, a2, f, a=0.0, esc=0.0001)
            continue
        if f <= 9:  # nasce em 1-2 q e cresce ate ~2x em 4-5 q
            u = (f - 5) / 4
            s = 0.4 + 0.42 * (1 - (1 - u) ** 3)
            a = 1.0
        elif f <= 15:  # fica, pulsando de leve
            s = 0.82 + 0.02 * math.sin((f - 9) * 1.7)
            a = 1.0 if f % 3 else 0.75
        else:  # desfaz
            u = (f - 15) / 3
            s = 0.84 + 0.06 * u
            a = 0.75 * (1 - u)
        chave(ext, a1, f, a=a, esc=s)
        chave(inn, a2, f, a=a * 0.9, esc=s * (0.98 if f > 9 else 0.9), rot=0.0)
    # particulas orbitando dentro (a 'bolha com petalas')
    rnd = random.Random(5)
    for i in range(10):
        d0 = math.tau * i / 10 + rnd.uniform(-0.2, 0.2)
        r = rnd.uniform(0.25, 0.55)
        lado = 0.028
        o, al = poli("orbita_%d" % i, [(-lado, -lado), (lado, -lado), (lado, lado), (-lado, lado)], 1.0, 0.35)
        for f in range(1, n + 1):
            if f < 8 or f > 16:
                chave(o, al, f, a=0.0, esc=0.0001)
                continue
            a = d0 + (f - 8) * 0.35
            chave(o, al, f, a=0.9 if (f + i) % 4 else 0.4, loc=(math.cos(a) * r, math.sin(a) * r), esc=1.0)
    polvilho("polvilho", n, 20, 15, 4, 0.7, 0.95, 0.8, 9, giro=0.6)
    return n


def espiral():
    """V1: redemoinho de vento no pe do heroi (fica no chao enquanto ele segue): 3 arcos que giram, abrem, afinam e somem."""
    n = 12
    base(n)
    arcos = []
    for i, (r, larg, a0, comp) in enumerate(((0.62, 0.11, 0.0, 2.6), (0.44, 0.09, 2.1, 2.2), (0.27, 0.07, 4.2, 1.9))):
        o, al = anel("arco_%d" % i, r, r - larg, 0.67 - 0.33 * i, 0.1 + 0.05 * i, n=36, a0=0.0, a1=comp)
        arcos.append((o, al, a0, i))
    for o, al, a0, i in arcos:
        for f in range(1, n + 1):
            t = f - 1 - i
            if t < 0:
                chave(o, al, f, a=0.0, esc=0.0001, rot=a0)
                continue
            u = min(t / 9, 1.0)
            chave(o, al, f, a=max(1.0 - u * 1.1, 0.0), esc=(0.55 + 0.55 * (1 - (1 - u) ** 2), (0.55 + 0.55 * (1 - (1 - u) ** 2)) * 0.62),
                  rot=a0 + 0.55 * t)   # achatado: visto de cima a 45 graus fica eliptico no chao
    polvilho("poeira", n, 10, 2, 8, 0.2, 0.75, 0.4, 13, giro=1.2)
    return n


EFEITOS = {"cristal": cristal, "estrela": estrela, "anel": anel_duplo, "espiral": espiral}


# ------------------------------------------------------------------ render + folha
def renderiza(nome, n):
    pasta = os.path.join(SAIDA, "quadros_" + nome)
    os.makedirs(pasta, exist_ok=True)
    cena.render.filepath = os.path.join(pasta, "q_")
    bpy.ops.render.render(animation=True)
    quadros = []
    for f in range(1, n + 1):
        img = bpy.data.images.load(os.path.join(pasta, "q_%04d.png" % f))
        img.colorspace_settings.name = "Non-Color"
        img.alpha_mode = "STRAIGHT"
        q = np.array(img.pixels[:], dtype=np.float32).reshape(T, T, 4)
        bpy.data.images.remove(img)
        a, rgb = q[..., 3], q[..., :3].mean(axis=2)
        a = np.where(a < 0.14, 0.0, np.round(a * 4.0) / 4.0)             # 4 degraus de transparencia
        h = np.where(a > 0, np.round(np.clip(rgb, 0, 1) * 3.0) / 3.0, 0.0)  # 4 degraus de calor
        o = np.zeros_like(q)
        o[..., 0] = o[..., 1] = o[..., 2] = h
        o[..., 3] = a
        quadros.append(np.repeat(np.repeat(o, ESC, axis=0), ESC, axis=1))
    folha = np.concatenate(quadros, axis=1)
    img = bpy.data.images.new("folha_" + nome, T * ESC * n, T * ESC, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "STRAIGHT"
    img.pixels = folha.reshape(-1).tolist()
    img.filepath_raw = os.path.join(SAIDA, "efeito_%s_folha.png" % nome)
    img.file_format = "PNG"
    img.save()
    print("FOLHA OK", nome, n, img.filepath_raw)


if __name__ == "__main__" and bpy.app.background:
    for nome in (PEDIDOS or list(EFEITOS)):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        limpa()
        n = EFEITOS[nome]()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SAIDA, "efeito_%s.blend" % nome), copy=True)
        renderiza(nome, n)

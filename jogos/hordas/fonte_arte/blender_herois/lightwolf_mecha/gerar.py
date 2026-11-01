"""Framework de animação do Nicão (Blender 4.5): modelo por script (modelo.py, da referência do Codex) + RIG com joelho, cotovelo e osso da MARRETA
+ materiais em 4 faixas + luz + câmera do jogo, e uma função de pose por animação (anim_<nome>.py). Mesma técnica e mesmo contrato do Hazaki
(../hazaki/gerar.py; ver LEIA-ME.md): Cycles em pixel nativo, 1 amostra, contorno no tom escuro da cor, câmera a 45 graus, 24,5 px/m.

    blender -b -t 6 -P gerar.py                       # todas as animações (anim_*.py desta pasta)
    blender -b -t 6 -P gerar.py -- --anim=andar       # só uma
Saída: quadros/<anim>/<direcao>_<i>_{cor,normal}.png (W x H, ver LEIA-ME.md) e lightwolf_mecha_rig.blend.
Diferença para o Hazaki: o quadro é maior (64x96): a marreta de 3,2 passa da cabeça e os golpes a levam longe do corpo.
"""
import importlib
import inspect
import math
import os
import random
import shutil
import sys
from pathlib import Path

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
import normais  # noqa: E402
import ossos  # noqa: E402

CODEX = AQUI.parent / "codex_estudo" / "criar_estudo.py"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SO_ANIM = next((a.split("=", 1)[1] for a in ARGS if a.startswith("--anim=")), None)
SAIDA = AQUI / "quadros"

W, H = 64, 96             # quadro (o Hazaki usa 32x44): a marreta de 3,2 passa da cabeça e as pancadas a levam longe do corpo
PPU = 24.5                # px por metro (câmera do jogo)
ELEV = 45.0               # graus
MARGEM_BAIXO = 20        # px abaixo do pé: a cabeça da marreta bate no chão À FRENTE do herói, que na câmera 45 graus cai abaixo da linha do pé
PE_LINHA = H - 1 - MARGEM_BAIXO   # última linha do desenho (pé = PE_LINHA - 1, mais 1 px de contorno)
ESCALA = 0.55             # unidades do modelo -> metros do jogo (3,0 de anão = 1,65 m = 40 px)
LARGURA = 1.0             # largura relativa (1.0: o IK dos braços trabalha em escala uniforme)
CONTORNO = 0.062          # espessura da casca do contorno, em metros do mundo (~1 px)
# ordem das linhas do jogo (v2/sprites.gd) e ângulo do herói em torno de Z (0 = de frente para a câmera)
DIRECOES = [("baixo", 0.0), ("esquerda", -90.0), ("direita", 90.0), ("cima", 180.0),
            ("baixo_esq", -45.0), ("baixo_dir", 45.0), ("cima_esq", -135.0), ("cima_dir", 135.0)]


def hexa(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


LUZ_PRINCIPAL = Vector((-0.80, -0.35, 0.50)).normalized()
LUZ_CONTRA = Vector((0.60, 0.75, 0.30)).normalized()


def srgb_para_linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def lin(c):
    return tuple(srgb_para_linear(max(0.0, min(1.0, v))) for v in c) + (1.0,)


def clampc(c):
    return tuple(max(0.0, min(1.0, v)) for v in c)


def mais(c, t, k=1.0):
    return tuple(a * k + b for a, b in zip(c, t))


# ============================================================ 1. modelo (modelo.py): anão, marreta no osso próprio
import modelo  # noqa: E402

src = CODEX.read_text(encoding="utf-8")
defs = src.split("# Base de pedra")[0]
ns = {"__name__": "codex_estudo", "__file__": str(CODEX)}
exec(compile(defs, str(CODEX), "exec"), ns)
heroi, OSSO_DE, PONTOS, HY = modelo.construir(ns)
PALETA = dict(modelo.PALETA)
BRILHANTES = dict(getattr(modelo, "BRILHANTES", {}))

# ============================================================ 2. materiais: 4 faixas por emissão (técnica do Codex), cores do jogo


def estilizar(material, base):
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    saida = nodes.new("ShaderNodeOutputMaterial")
    emissao = nodes.new("ShaderNodeEmission")
    links.new(emissao.outputs[0], saida.inputs["Surface"])
    geo = nodes.new("ShaderNodeNewGeometry")
    dot = nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = LUZ_PRINCIPAL
    links.new(geo.outputs["Normal"], dot.inputs[0])
    remap = nodes.new("ShaderNodeMath")
    remap.operation = "MULTIPLY_ADD"
    remap.inputs[1].default_value = 0.5
    remap.inputs[2].default_value = 0.5
    links.new(dot.outputs["Value"], remap.inputs[0])
    ao = nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 32
    ao.inputs["Distance"].default_value = 0.18
    mult = nodes.new("ShaderNodeMath")
    mult.operation = "MULTIPLY"
    links.new(remap.outputs[0], mult.inputs[0])
    links.new(ao.outputs["AO"], mult.inputs[1])
    rampa = nodes.new("ShaderNodeValToRGB")
    rampa.color_ramp.interpolation = "CONSTANT"
    escura = clampc(mais(base, (0.012, 0.022, 0.058), 0.36))
    sombra = clampc(mais(base, (0.008, 0.014, 0.034), 0.64))
    luz = clampc(mais(base, (0.075, 0.042, 0.004), 1.10))
    for i, (pos, cor) in enumerate([(0.0, escura), (0.30, sombra), (0.52, base), (0.76, luz)]):
        el = rampa.color_ramp.elements[i] if i < 2 else rampa.color_ramp.elements.new(pos)
        el.position = pos
        el.color = lin(cor)
    links.new(mult.outputs[0], rampa.inputs[0])
    dot2 = nodes.new("ShaderNodeVectorMath")
    dot2.operation = "DOT_PRODUCT"
    dot2.inputs[1].default_value = LUZ_CONTRA
    links.new(geo.outputs["Normal"], dot2.inputs[0])
    borda = nodes.new("ShaderNodeMath")
    borda.operation = "GREATER_THAN"
    borda.inputs[1].default_value = 0.45
    links.new(dot2.outputs["Value"], borda.inputs[0])
    fac = nodes.new("ShaderNodeMath")
    fac.operation = "MULTIPLY"
    fac.inputs[1].default_value = 0.70
    links.new(borda.outputs[0], fac.inputs[0])
    mix = nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MIX"
    mix.inputs["Color2"].default_value = lin(clampc(mais(base, (0.09, 0.16, 0.30), 0.55)))
    links.new(fac.outputs[0], mix.inputs["Fac"])
    links.new(rampa.outputs["Color"], mix.inputs["Color1"])
    links.new(mix.outputs["Color"], emissao.inputs["Color"])
    emissao.inputs["Strength"].default_value = 1.0
    material.diffuse_color = lin(base)


def emissivo(material, cor, forca=1.0):
    nodes = material.node_tree.nodes
    nodes.clear()
    saida = nodes.new("ShaderNodeOutputMaterial")
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = lin(cor)
    em.inputs["Strength"].default_value = forca
    material.node_tree.links.new(em.outputs[0], saida.inputs["Surface"])


usados = {m.name for o in heroi if hasattr(o.data, "materials") for m in o.data.materials if m}
for m in list(bpy.data.materials):
    if m.name not in usados or not m.use_nodes:
        continue
    if m.name in BRILHANTES:
        emissivo(m, hexa(BRILHANTES[m.name]))
    elif m.name == "Olho":
        emissivo(m, hexa(PALETA["Olho"]))
    elif m.name in PALETA:
        estilizar(m, hexa(PALETA[m.name]))
    else:
        raise RuntimeError("material sem cor na paleta: " + m.name)

# material da passada de NORMAL (espaço de câmera; Z invertido, medido no Blender 4.5: igual ao do pipeline do jogo)
mat_normal = bpy.data.materials.new("passe_normal")
mat_normal.use_nodes = True
_nt = mat_normal.node_tree
_nt.nodes.clear()
_geo, _tr = _nt.nodes.new("ShaderNodeNewGeometry"), _nt.nodes.new("ShaderNodeVectorTransform")
_tr.vector_type, _tr.convert_from, _tr.convert_to = "NORMAL", "WORLD", "CAMERA"
_mad = _nt.nodes.new("ShaderNodeVectorMath")
_mad.operation = "MULTIPLY_ADD"
_mad.inputs[1].default_value = (0.5, 0.5, -0.5)
_mad.inputs[2].default_value = (0.5, 0.5, 0.5)
_emi, _out = _nt.nodes.new("ShaderNodeEmission"), _nt.nodes.new("ShaderNodeOutputMaterial")
_nt.links.new(_geo.outputs["Normal"], _tr.inputs["Vector"])
_nt.links.new(_tr.outputs["Vector"], _mad.inputs[0])
_nt.links.new(_mad.outputs["Vector"], _emi.inputs["Color"])
_nt.links.new(_emi.outputs["Emission"], _out.inputs["Surface"])

# ============================================================ 3. contorno: casca invertida no tom ESCURO DA PRÓPRIA COR
cascas = {}


def material_contorno(m):
    if m.name in cascas:
        return cascas[m.name]
    base = hexa(PALETA.get(m.name, "#4a5a70"))
    escuro = clampc(mais(base, (0.010, 0.014, 0.034), 0.20))
    novo = bpy.data.materials.new("Contorno " + m.name)
    novo.use_nodes = True
    n = novo.node_tree.nodes
    n.clear()
    sai, mx, geo = n.new("ShaderNodeOutputMaterial"), n.new("ShaderNodeMixShader"), n.new("ShaderNodeNewGeometry")
    transp, em = n.new("ShaderNodeBsdfTransparent"), n.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = lin(escuro)
    lk = novo.node_tree.links
    lk.new(geo.outputs["Backfacing"], mx.inputs[0])
    lk.new(transp.outputs[0], mx.inputs[1])
    lk.new(em.outputs[0], mx.inputs[2])
    lk.new(mx.outputs[0], sai.inputs["Surface"])
    cascas[m.name] = novo
    return novo


bpy.context.view_layer.update()
S = Matrix.Diagonal((ESCALA * LARGURA, ESCALA, ESCALA))
CASCAS = []
for original in list(heroi):
    if original.type != "MESH" or len(original.data.polygons) < 6 or original.name.startswith(("Olho", "Sobrancelha")):
        continue
    mats = [m for m in original.data.materials if m]
    if not mats:
        continue
    copia = original.copy()
    copia.data = original.data.copy()
    copia.name = "Contorno — " + original.name
    bpy.context.collection.objects.link(copia)
    A = S @ original.matrix_world.to_3x3()
    Ai = A.inverted()
    for v in copia.data.vertices:
        v.co = v.co + Ai @ ((Ai.transposed() @ v.normal).normalized() * CONTORNO)
    copia.data.update()
    copia.data.materials.clear()
    copia.data.materials.append(material_contorno(mats[0]))
    copia.visible_shadow = False
    OSSO_DE[copia] = OSSO_DE[original]
    CASCAS.append(copia)
heroi += CASCAS

# ============================================================ 4. RIG: armature com joelho e cotovelo; peças presas por osso
arm_data = bpy.data.armatures.new("LWMecha")
arm = bpy.data.objects.new("LW mecha rig", arm_data)
bpy.context.collection.objects.link(arm)
arm.location = (0.0, HY, 0.0)      # o pivô do herói é o próprio armature: escala e giro por direção ficam nele
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")


def L(nome):
    """Posição da articulação em coordenadas do armature (mundo do modelo menos o deslocamento H do Codex)."""
    p = PONTOS[nome]
    return Vector((p[0], p[1] - HY, p[2]))


def osso(nome, cabeca, cauda, pai=None):
    eb = arm_data.edit_bones.new(nome)
    eb.head, eb.tail = cabeca, cauda
    eixo_x = Vector((1.0, 0.0, 0.0))
    dirv = (cauda - cabeca).normalized()
    eb.align_roll(eixo_x.cross(dirv))      # eixo X local = X do mundo em todos os ossos (ver ossos.py)
    if pai:
        eb.parent = arm_data.edit_bones[pai]
    return eb


osso("raiz", Vector((0, 0, 0)), Vector((0, 0.3, 0)))
osso("quadril", Vector((0, 0, 1.00)), Vector((0, 0, 1.25)), "raiz")
osso("torso", Vector((0, 0, 1.25)), Vector((0, 0, 2.10)), "quadril")
osso("cabeca", Vector((0, 0, 2.10)), Vector((0, 0, 3.00)), "torso")
osso("marreta", L("marreta"), L("marreta") + Vector((0, 0, 0.5)), "torso")   # a marreta tem osso próprio: as mãos (IK em ossos.py) a seguram
for sfx in ("_e", "_d"):
    osso("braco" + sfx, L("ombro" + sfx), L("cotovelo" + sfx), "torso")
    osso("antebraco" + sfx, L("cotovelo" + sfx), L("punho" + sfx), "braco" + sfx)
    osso("perna" + sfx, L("quadril" + sfx), L("joelho" + sfx), "quadril")
    osso("canela" + sfx, L("joelho" + sfx), L("tornozelo" + sfx), "perna" + sfx)
    osso("pe" + sfx, L("tornozelo" + sfx), L("tornozelo" + sfx) + Vector((0, -0.20, -0.25)), "canela" + sfx)
bpy.ops.object.mode_set(mode="OBJECT")
assert set(b.name for b in arm_data.bones) == set(ossos.OSSOS), "ossos fora de ossos.OSSOS"
arm.show_in_front = True
bpy.context.view_layer.update()


def prender(o, nome_osso):
    """Prende o objeto ao osso mantendo a posição do mundo (a matriz do pai de osso é medida, não presumida)."""
    o.parent = arm
    o.parent_type = "BONE"
    o.parent_bone = nome_osso
    o.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    pai = o.matrix_world @ o.matrix_basis.inverted()
    o.matrix_parent_inverse = pai.inverted()


for o in heroi:
    prender(o, OSSO_DE[o])
bpy.context.view_layer.update()
arm.scale = (ESCALA * LARGURA, ESCALA, ESCALA)
arm["chao"] = 0.0
arm["chao"] = ossos._min_z_botas(arm)      # altura da sola das botas em repouso = chão

CORPO = [o for o in heroi if o not in CASCAS]
MAT_COR = {o: list(o.data.materials) for o in CORPO}

# ============================================================ 5. cena: Cycles pixel nativo, câmera do jogo
cena = bpy.context.scene
cena.render.engine = "CYCLES"
cena.cycles.device = "CPU"
cena.cycles.samples = 1
cena.cycles.use_denoising = False
cena.cycles.pixel_filter_type = "BOX"
cena.cycles.filter_width = 0.01
cena.cycles.max_bounces = 3
cena.cycles.transparent_max_bounces = 16
cena.render.film_transparent = True
cena.render.resolution_x, cena.render.resolution_y, cena.render.resolution_percentage = W, H, 100
cena.render.image_settings.file_format = "PNG"
cena.render.image_settings.color_mode = "RGBA"
cena.render.image_settings.color_depth = "8"
cena.render.dither_intensity = 0
cena.view_settings.look = "None"
cena.view_settings.exposure = 0
cena.view_settings.gamma = 1
cena.render.threads_mode = "FIXED"
cena.render.threads = 6

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = max(W, H) / PPU
cam = bpy.data.objects.new("cam", cam_data)
bpy.context.collection.objects.link(cam)
el = math.radians(ELEV)
cam.location = (0.0, -20.0 * math.cos(el), 20.0 * math.sin(el))
cam.rotation_euler = (math.pi / 2 - el, 0.0, 0.0)
cena.camera = cam

TMP = Path(os.environ.get("TEMP", "/tmp")) / ("lw_mecha_gerar_%d" % os.getpid())
TMP.mkdir(parents=True, exist_ok=True)


def renderizar(caminho, normal=False):
    """Renderiza um quadro. Cor: sRGB 'Standard'. Normal: 'Raw' (o número escrito é o número do material) e sem as cascas do contorno."""
    cena.view_settings.view_transform = "Raw" if normal else "Standard"
    for c in CASCAS:
        c.hide_render = normal
    for o in CORPO:
        o.data.materials[0] = mat_normal if normal else MAT_COR[o][0]
    cena.render.filepath = str(caminho)
    bpy.ops.render.render(write_still=True)


def ler(caminho, cru):
    img = bpy.data.images.load(str(caminho), check_existing=False)
    if cru:
        img.colorspace_settings.name = "Non-Color"
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1].copy()
    bpy.data.images.remove(img)
    return px


def gravar_normal(px, caminho):
    img = bpy.data.images.new("n", W, H, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels[:] = px[::-1].ravel()
    img.filepath_raw = str(caminho)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


# calibra: o fundo do desenho (com contorno) cai na linha PE_LINHA, no repouso de frente; vale para todas as animações
ossos.zerar(arm)
ossos.pisar(arm)
arm.rotation_euler = (0, 0, 0)
renderizar(TMP / "calibra.png")
px = ler(TMP / "calibra.png", False)
ys, xs = np.nonzero(px[:, :, 3] > 0.5)
dy = ys.max() - PE_LINHA
cam_data.shift_y = -dy / max(W, H)
ossos.calibrar(arm, ELEV)
LOC0 = Vector(arm["loc0"])
print("calibragem: caixa y %d..%d x %d..%d (largura %d px); desloca %d px" % (ys.min(), ys.max(), xs.min(), xs.max(), xs.max() - xs.min() + 1, dy))


def animacoes():
    achadas = sorted(p.stem[len("anim_"):] for p in AQUI.glob("anim_*.py"))
    if SO_ANIM:
        if SO_ANIM not in achadas:
            raise SystemExit("animação '%s' não existe; há: %s" % (SO_ANIM, ", ".join(achadas)))
        return [SO_ANIM]
    return achadas


def projetar(co):
    """Ponto do mundo -> (x, y) em pixels do quadro (y para baixo), pela câmera do jogo."""
    v = world_to_camera_view(cena, cam, co)
    return v.x * W, (1.0 - v.y) * H


def pintar_poligonos(cor, normal, mascara, poligonos):
    """Efeitos 2D de golpe (rastro da lâmina): poligonos = [(pontos_no_mundo, (r, g, b) 0-255), ...]. Pinta só onde o corpo NÃO está (o rastro
    fica atrás do herói), sem meio-tom (alfa 1), e na normal usa a normal reta (contorno). Altera cor e normal no lugar."""
    ys, xs = np.mgrid[0:H, 0:W]
    cx, cy = xs + 0.5, ys + 0.5
    for pts, rgb in poligonos:
        p = [projetar(Vector(q)) for q in pts]
        dentro = np.zeros((H, W), bool)
        for i in range(1, len(p) - 1):
            (ax, ay), (bx, by), (qx, qy) = p[0], p[i], p[i + 1]
            d = (by - qy) * (ax - qx) + (qx - bx) * (ay - qy)
            if abs(d) < 1e-9:
                continue
            l1 = ((by - qy) * (cx - qx) + (qx - bx) * (cy - qy)) / d
            l2 = ((qy - ay) * (cx - qx) + (ax - qx) * (cy - qy)) / d
            dentro |= (l1 >= 0) & (l2 >= 0) & (1 - l1 - l2 >= 0)
        dentro &= ~mascara
        cor[dentro] = (rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0, 1.0)
        normal[dentro] = (0.5, 0.5, 1.0, 1.0)


def renderizar_animacao(nome):
    mod = importlib.import_module("anim_" + nome)
    n = mod.N_QUADROS
    pasta = SAIDA / nome
    pasta.mkdir(parents=True, exist_ok=True)
    usa_ang = len(inspect.signature(mod.posar).parameters) >= 4          # posar(arm, quadro, n, ang): ang = giro do herói na direção
    efeito = getattr(mod, "efeito", None)                                # efeito(arm, quadro, n, ang) -> polígonos 2D do golpe (ver pintar_poligonos)
    for q in range(n):
        for dname, ang in DIRECOES:
            ossos.zerar(arm)
            arm.location = LOC0
            arm.rotation_euler = (0, 0, math.radians(ang))
            if usa_ang:
                mod.posar(arm, q, n, ang)
            else:
                mod.posar(arm, q, n)
            bpy.context.view_layer.update()
            base = pasta / ("%s_%d" % (dname, q))
            renderizar(str(base) + "_cor.png")
            cor = ler(str(base) + "_cor.png", False)
            mascara = cor[:, :, 3] > 0.5
            tmp = TMP / "n.png"
            renderizar(tmp, normal=True)
            nor = normais.pos_normal(ler(tmp, True), mascara)
            polis = efeito(arm, q, n, ang) if efeito else []
            if polis:
                cor = ler(str(base) + "_cor.png", True)
                pintar_poligonos(cor, nor, mascara, polis)
                gravar_normal(cor, str(base) + "_cor.png")
            gravar_normal(nor, str(base) + "_normal.png")
    arm.location = LOC0
    arm.rotation_euler = (0, 0, 0)
    print("ANIM_OK %s: %d quadros x %d direções" % (nome, n, len(DIRECOES)))


for nome in animacoes():
    renderizar_animacao(nome)

ossos.zerar(arm)
for c in CASCAS:
    c.hide_render = False
for o in CORPO:
    o.data.materials[0] = MAT_COR[o][0]
arm.rotation_euler = (0, 0, 0)
if not SO_ANIM:
    bpy.ops.wm.save_as_mainfile(filepath=str(AQUI / "lightwolf_mecha_rig.blend"), compress=True)
shutil.rmtree(TMP, ignore_errors=True)
print("NICAO_OK")

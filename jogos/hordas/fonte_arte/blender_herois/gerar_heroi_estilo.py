"""Estudo: herói do Blender no ESTILO DO JOGO (dark fantasy, paleta fechada).

Junta duas coisas:
  - MODELO e TÉCNICA de render do estudo do Codex do Alisson (codex_estudo/criar_estudo.py e criar_pixel_art.py): geometria do herói
    (rosto, cabelo espetado, lenço, cinto, botas, katana), materiais em 4 faixas por emissão, contorno geométrico por casca invertida e
    render em pixel nativo (Cycles, 1 amostra, filtro BOX mínimo, sem suavização, sem bloom);
  - A CARA DO JOGO: paleta escura e dessaturada (traje vinho, sombras frias azuladas, pele menos laranja, aço sem ciano neon), contorno
    no tom escuro de cada cor (não preto puro), luz principal quente lateral (a tocha que anda com o herói) e contraluz frio leve.
Renderiza JÁ no tamanho do quadro do herói no jogo (32x44, câmera ortográfica a 45 graus, 24,5 px/m, pé na linha 42), o mesmo do piloto
(gerar_heroi_andar.py), e exagera o que precisa ler pequeno (olhos, sobrancelhas, mechas, lenço, katana).

Uso (Blender 4.5, segundo plano):
    blender -b -t 6 -P gerar_heroi_estilo.py [-- <pasta_de_saida>]
Saída: hazaki_blender_estilo_albedo.png + .json (mesmo formato das folhas do salão/herói: 8 linhas x [parado, andar0..andar5],
aqui só o quadro parado repetido nas colunas), .blend. Estudo: o jogo NÃO usa esta folha.
"""
import math
import os
import random
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

AQUI = Path(__file__).resolve().parent
CODEX = AQUI / "codex_estudo" / "criar_estudo.py"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAIDA = Path(ARGS[0]) if ARGS else AQUI / "estudo_estilo"
SAIDA.mkdir(parents=True, exist_ok=True)

W, H = 32, 44             # quadro do herói no jogo
PPU = 24.5                # px por metro (câmera do jogo)
ELEV = 45.0               # graus
PE_LINHA = 43             # última linha do desenho (pé = 42 + 1 px de contorno)
ESCALA = 0.55             # o modelo do Codex tem ~3 m; o do jogo, ~2,3 m
LARGURA = 0.95            # estreita o herói (braços e katana cabem nos 32 px)
CONTORNO = 0.062          # espessura da casca do contorno, em metros do mundo (~1 px)
NOME = "hazaki_blender_estilo"
DIRECOES = [0.0, -90.0, 90.0, 180.0, -45.0, 45.0, -135.0, 135.0]   # baixo, esq, dir, cima, baixo_esq, baixo_dir, cima_esq, cima_dir
COLUNAS = 7               # [parado, andar0..andar5]


def hexa(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# ------------------------------------------------------------------ paleta do jogo (sRGB), por material do modelo do Codex
# vermelho do traje mais escuro e dessaturado (vinho), pele sem o laranja saturado, aço azul-acinzentado sem ciano neon
PALETA = {
    "Tecido vermelho queimado": "#7a2a32",
    "Vermelho iluminado": "#93383b",
    "Dobras do tecido": "#4c1c2c",
    "Calça azul carvão": "#2f384c",
    "Cabelo quase preto": "#222839",
    "Couro castanho": "#503829",
    "Pele": "#9a7360",
    "Rosto iluminado": "#b78c74",
    "Aço azulado": "#66798d",
    "Fio polido": "#b9c4cf",
    "Latão antigo": "#9a7a3e",
    "Olho": "#0a0c14",
}
BRILHANTES = {"Reflexo frio": "#8ea9c4"}      # o fio azul refletido da lâmina: só um traço frio e fosco, sem neon
LUZ_PRINCIPAL = Vector((-0.80, -0.35, 0.50)).normalized()   # tocha: da esquerda, um pouco à frente e acima (a tocha anda com o herói)
LUZ_CONTRA = Vector((0.60, 0.75, 0.30)).normalized()        # contraluz frio de trás/direita


def srgb_para_linear(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def lin(c):
    return tuple(srgb_para_linear(max(0.0, min(1.0, v))) for v in c) + (1.0,)


def clampc(c):
    return tuple(max(0.0, min(1.0, v)) for v in c)


def mais(c, t, k=1.0):
    return tuple(a * k + b for a, b in zip(c, t))


# ------------------------------------------------------------------ modelo (geometria do Codex, com ajustes de escala para 32x44)
src = CODEX.read_text(encoding="utf-8")
defs = src.split("# Base de pedra")[0]
heroi_src = "# Herói original" + src.split("# Herói original", 1)[1].split("# Portal de pedra")[0]


def trocar(txt, de, para):
    assert de in txt, "trecho não encontrado: " + de
    return txt.replace(de, para)


# katana apontada para baixo ao lado do corpo (a do estudo aponta para fora e estouraria os 32 px) e mais curta
heroi_src = trocar(heroi_src, "Vector((1.05,.25,.20))", "Vector((0.50,0.22,-0.85))")
heroi_src = trocar(heroi_src, "direction*1.45", "direction*0.95")
# cabelo mais grosso e mechas mais compridas (lê melhor em 44 px)
heroi_src = trocar(heroi_src, "segment('Mecha de cabelo',root,tip,.105,0,hair,4)", "segment('Mecha de cabelo',root,tip,.15,0,hair,4)")
heroi_src = trocar(heroi_src, "3.19+random.uniform(-.05,.13)", "3.23+random.uniform(-.05,.12)")

ns = {"__name__": "codex_estudo", "__file__": str(CODEX)}
exec(compile(defs, str(CODEX), "exec"), ns)
antes = set(bpy.data.objects)
random.seed(26)
exec(compile(heroi_src, str(CODEX), "exec"), ns)
heroi = [o for o in bpy.data.objects if o not in antes]
print("objetos do herói:", len(heroi))

# cabelo um pouco mais alto e para trás (descobre a testa e os olhos) e franja mais alta
heroi_src = trocar(heroi_src, "ico('Cabelo — volume',P(0,.05,2.94),(.35,.29,.24),hair,2)", "ico('Cabelo — volume',P(0,.10,3.09),(.34,.29,.19),hair,2)")
heroi_src = trocar(heroi_src, "[(-.2,2.89),(-.02,2.94),(.17,2.91)]", "[(-.2,3.02),(-.02,3.07),(.17,3.04)]")

# sem a franja (3 triângulos escondem a testa e os olhos em 44 px) e sem a boca (1 px de ruído)
for o in [o for o in heroi if o.name.startswith(("Franja", "Boca"))]:
    heroi.remove(o)
    bpy.data.objects.remove(o, do_unlink=True)

# lenço mais curto (o do estudo vai a -1,5 m e sairia do quadro) e olhos/sobrancelhas mais grossos
for o in heroi:
    if o.type == "MESH" and o.name in ("Lenço ao vento", "Face escura do lenço"):
        for v in o.data.vertices:
            if v.co.x < -0.13:
                v.co.x = -0.13 + (v.co.x + 0.13) * 0.52
        o.data.update()
    elif o.name.startswith("Olho"):
        o.scale = (1.45, 1.3, 2.3)
        o.location.y -= 0.01
    elif o.name.startswith("Sobrancelha") and o.type == "CURVE":
        o.data.bevel_depth = 0.032

# cabeça maior (chibi, como no estudo do Codex, mas mais ainda: o rosto precisa ler em ~10 px), em torno do pescoço
CABECA = 1.22
centro = Vector((0.0, ns["H"], 2.45))
for o in heroi:
    if o.name.startswith(("Cabeça", "Orelha", "Olho", "Sobrancelha", "Nariz", "Boca", "Cabelo", "Mecha", "Franja")):
        o.matrix_world = Matrix.Translation(centro) @ Matrix.Scale(CABECA, 4) @ Matrix.Translation(-centro) @ o.matrix_world

# ------------------------------------------------------------------ materiais: 4 faixas por emissão (técnica do Codex), cores do jogo


def estilizar(material, base):
    """Quatro degraus de cor por luz principal x oclusão, sombra fria, lado quente, mais um traço de contraluz frio."""
    nodes = material.node_tree.nodes
    links = material.node_tree.links
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
    escura = clampc(mais(base, (0.012, 0.022, 0.058), 0.36))       # sombra fria azulada
    sombra = clampc(mais(base, (0.008, 0.014, 0.034), 0.64))
    luz = clampc(mais(base, (0.075, 0.042, 0.004), 1.10))          # lado da tocha: quente
    for i, (pos, cor) in enumerate([(0.0, escura), (0.30, sombra), (0.52, base), (0.76, luz)]):
        el = rampa.color_ramp.elements[i] if i < 2 else rampa.color_ramp.elements.new(pos)
        el.position = pos
        el.color = lin(cor)
    links.new(mult.outputs[0], rampa.inputs[0])

    # contraluz frio: só nas bordas voltadas para trás/direita, um degrau
    dot2 = nodes.new("ShaderNodeVectorMath")
    dot2.operation = "DOT_PRODUCT"
    dot2.inputs[1].default_value = LUZ_CONTRA
    links.new(geo.outputs["Normal"], dot2.inputs[0])
    borda = nodes.new("ShaderNodeMath")
    borda.operation = "GREATER_THAN"
    borda.inputs[1].default_value = 0.58
    links.new(dot2.outputs["Value"], borda.inputs[0])
    fac = nodes.new("ShaderNodeMath")
    fac.operation = "MULTIPLY"
    fac.inputs[1].default_value = 0.55
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
        emissivo(m, hexa(PALETA["Olho"]))     # olho chapado, quase preto azulado, para ler como 2 px nítidos
    elif m.name in PALETA:
        estilizar(m, hexa(PALETA[m.name]))
    else:
        raise RuntimeError("material sem cor na paleta: " + m.name)

# ------------------------------------------------------------------ contorno: casca invertida no tom ESCURO DA PRÓPRIA COR (não preto puro)
cascas = {}


def material_contorno(m):
    if m.name in cascas:
        return cascas[m.name]
    base = hexa(PALETA.get(m.name, "#4a5a70")) if m.name in PALETA else hexa("#4a5a70")
    escuro = clampc(mais(base, (0.010, 0.014, 0.034), 0.20))
    novo = bpy.data.materials.new("Contorno " + m.name)
    novo.use_nodes = True
    n = novo.node_tree.nodes
    n.clear()
    sai = n.new("ShaderNodeOutputMaterial")
    mx = n.new("ShaderNodeMixShader")
    geo = n.new("ShaderNodeNewGeometry")
    transp = n.new("ShaderNodeBsdfTransparent")
    em = n.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = lin(escuro)
    l = novo.node_tree.links
    l.new(geo.outputs["Backfacing"], mx.inputs[0])
    l.new(transp.outputs[0], mx.inputs[1])
    l.new(em.outputs[0], mx.inputs[2])
    l.new(mx.outputs[0], sai.inputs["Surface"])
    cascas[m.name] = novo
    return novo


# pivô: a escala do herói para o jogo e a rotação por direção ficam nele (a escala é em torno do pivô, no centro do boneco no chão)
pivo = bpy.data.objects.new("Pivô do herói", None)
bpy.context.collection.objects.link(pivo)
pivo.location = Vector((0.0, ns["H"], 0.0))
bpy.context.view_layer.update()
S = Matrix.Diagonal((ESCALA * LARGURA, ESCALA, ESCALA))          # a escala final aplicada sobre o mundo do modelo

novos = []
for original in list(heroi):
    if original.type != "MESH" or len(original.data.polygons) < 6 or original.name.startswith(("Olho", "Sobrancelha", "Boca")):
        continue
    mats = [m for m in original.data.materials if m]
    if not mats:
        continue
    copia = original.copy()
    copia.data = original.data.copy()
    copia.name = "Contorno — " + original.name
    bpy.context.collection.objects.link(copia)
    A = S @ original.matrix_world.to_3x3()                      # parte linear local -> mundo final
    Ai = A.inverted()
    for v in copia.data.vertices:
        n_final = (Ai.transposed() @ v.normal).normalized()      # normal no mundo final
        v.co = v.co + Ai @ (n_final * CONTORNO)                  # empurra CONTORNO metros (do mundo final) para fora
    copia.data.update()
    copia.data.materials.clear()
    copia.data.materials.append(material_contorno(mats[0]))
    copia.visible_shadow = False
    novos.append(copia)
heroi += novos

for o in heroi:
    mw = o.matrix_world.copy()
    o.parent = pivo
    o.matrix_parent_inverse = pivo.matrix_world.inverted()       # com o pivô ainda sem escala/rotação
    o.matrix_world = mw
pivo.scale = (ESCALA * LARGURA, ESCALA, ESCALA)
bpy.context.view_layer.update()

# ------------------------------------------------------------------ cena: Cycles pixel nativo, câmera do jogo
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
cena.render.resolution_x = W
cena.render.resolution_y = H
cena.render.resolution_percentage = 100
cena.render.image_settings.file_format = "PNG"
cena.render.image_settings.color_mode = "RGBA"
cena.render.dither_intensity = 0
cena.view_settings.view_transform = "Standard"
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

TMP = SAIDA / "_tmp_estilo"
TMP.mkdir(exist_ok=True)


def renderizar(nome):
    cena.render.filepath = str(TMP / (nome + ".png"))
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(str(TMP / (nome + ".png")))
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1]
    bpy.data.images.remove(img)
    return px


# calibra: o fundo do desenho (com contorno) cai na linha PE_LINHA e o corpo fica centrado no pivô
pivo.rotation_euler = (0, 0, 0)
cam_data.shift_x = 0.0
cam_data.shift_y = 0.0
px = renderizar("calibra")
ys, xs = np.nonzero(px[:, :, 3] > 0.5)
dy = ys.max() - PE_LINHA
cam_data.shift_y = -dy / max(W, H)
print("calibragem: caixa y %d..%d x %d..%d; desloca %d px" % (ys.min(), ys.max(), xs.min(), xs.max(), dy))

quadros = []
for k, ang in enumerate(DIRECOES):
    pivo.rotation_euler = (0, 0, math.radians(ang))
    quadros.append(renderizar("dir%d" % k))

# monta a folha: 8 linhas x 7 colunas (o quadro parado repetido onde faltar andar)
folha = np.zeros((H * len(DIRECOES), W * COLUNAS, 4), np.float32)
for k, q in enumerate(quadros):
    for c in range(COLUNAS):
        folha[k * H:(k + 1) * H, c * W:(c + 1) * W] = q
folha[:, :, :3] *= (folha[:, :, 3:4] > 0.5)
folha[:, :, 3] = (folha[:, :, 3] > 0.5).astype(np.float32)       # alfa binário: pixel cheio ou vazio
img = bpy.data.images.new("folha", folha.shape[1], folha.shape[0], alpha=True)
img.pixels[:] = folha[::-1].ravel()
img.filepath_raw = str(SAIDA / (NOME + "_albedo.png"))
img.file_format = "PNG"
img.save()
import json
with open(SAIDA / (NOME + ".json"), "w", encoding="utf-8") as f:
    json.dump({"quadro": [W, H], "elevacao": ELEV, "ppu": PPU,
               "linhas": ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"],
               "colunas": ["parado"] + ["andar%d" % k for k in range(COLUNAS - 1)],
               "nota": "estudo: quadro parado repetido nas colunas de andar"}, f, indent=1)
pivo.rotation_euler = (0, 0, 0)
bpy.ops.wm.save_as_mainfile(filepath=str(SAIDA / (NOME + ".blend")), compress=True)
import shutil
shutil.rmtree(TMP, ignore_errors=True)
print("HEROI_ESTILO_OK", folha.shape)

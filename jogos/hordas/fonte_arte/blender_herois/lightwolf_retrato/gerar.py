"""Retrato "estilo D.Va" do LightWolf (issue #584): o LOBO encostado no MECHA de pé, numa cena só, no Blender 4.5.

Reaproveita os dois rigs prontos, sem refazer modelo nem material:
    ../lightwolf_mecha/lightwolf_mecha_rig.blend  (+ ossos.py e anim_parado.py da mesma pasta)  -> mecha 128x192 aprovado
    ../lightwolf_lobo/lobo_rig.blend              (+ ../lucas/ossos.py, o rig do Luke)          -> lobo azul-gelo + ciano
Abre o rig do mecha, acrescenta (append) as peças do lobo, posa os dois e renderiza com a câmera do jogo (ortográfica, 45 graus), em pixel nativo
(Cycles, 1 amostra, filtro BOX), nos dois tamanhos pedidos: cada tamanho é um render próprio, sem redimensionar. Depois, o acabamento 2D do elenco
(../hazaki/estilo2d.py): contorno escuro de 1 px + rim light. O lobo, que fica na frente, ganha o próprio contorno de 1 px também contra o mecha
(sem isso os dois azuis se fundem); o mecha só tem contorno contra o fundo.

    blender -b -t 4 -P gerar.py                                   # retrato_dupla.png (256x256) e retrato_dupla_128.png
    blender -b -t 4 -P gerar.py -- --mecha=<pasta lightwolf_mecha> # se o mecha não estiver ao lado (worktree antiga)
    blender -b -t 4 -P gerar.py -- --previa=<png>                  # também grava a prévia (256 em x2 e 128 em x4, fundo escuro e claro)
    blender -b -t 4 -P gerar.py -- --elev=45                       # câmera das folhas (padrão do retrato: 30 graus)
Saída: ../../../projeto/assets/personagens/lightwolf/retrato_dupla.png (256) e retrato_dupla_128.png (128).
"""
import importlib.util
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

AQUI = Path(__file__).resolve().parent
HEROIS = AQUI.parent
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OPC = {a.split("=", 1)[0].lstrip("-"): (a.split("=", 1)[1] if "=" in a else True) for a in ARGS}
PASTA_MECHA = Path(OPC.get("mecha", HEROIS / "lightwolf_mecha"))
PASTA_LOBO = HEROIS / "lightwolf_lobo"
PASTA_LUCAS = HEROIS / "lucas"
DESTINO = HEROIS.parents[1] / "projeto" / "assets" / "personagens" / "lightwolf"

sys.path.insert(0, str(HEROIS / "hazaki"))
import estilo2d  # noqa: E402

sys.path.remove(str(HEROIS / "hazaki"))

# ------------------------------------------------------------------ parâmetros da cena (unidades do mundo do Blender; ângulos em graus)
ELEV = float(OPC.get("elev", 30.0))   # a folha usa 45; no retrato, 30 mostra o visor do mecha e o rosto do lobo (45 mostra o topo da cabeça)
PPU_FOLHA = 24.5            # px por metro das duas folhas (o contorno-casca do lobo foi feito para ~1 px nesta escala)
TAMANHOS = {256: "retrato_dupla.png", 128: "retrato_dupla_128.png"}
MARGEM = {256: 8, 128: 4}   # px livres em cima e embaixo (o desenho todo cabe; nada é cortado)

MECHA_ANG = -22.0           # mecha em 3/4, virado um pouco para a esquerda da tela
LOBO_ANG = -14.0            # lobo quase de frente, um pouco virado para a esquerda da tela (para fora do mecha)
LOBO_ESCALA = 0.9           # relativo à escala da folha (1,0 = proporção do jogo, que põe o topo das orelhas no peito do mecha)
LOBO_RECOSTA = 8.0          # o lobo recosta para trás (graus), com as costas na canela do mecha
LOBO_X = -0.12              # x do lobo em relação ao centro da canela esquerda (da tela) do mecha
CONTATO = 0.04              # sobreposição (m) entre as costas do lobo e a canela/coxa do mecha: encostado, sem vão
POSE_CABECA = {"y": -0.10, "z": 0.12, "x": 0.10}        # cabeça um pouco inclinada, olhando para a câmera
POSE_BRACO_E = {"x": -0.30, "y": -0.22}                 # braços cruzados no peito (o esquerdo da tela por baixo, com a pistola)
POSE_ANTEBRACO_E = {"x": -1.35, "z": 1.15}
POSE_BRACO_D = {"x": -0.38, "y": 0.22}
POSE_ANTEBRACO_D = {"x": -1.45, "z": -1.15}
ESTILO = {"contorno": True, "escuro": 0.30, "teto": 0.16, "rim": True, "rim_dir": (1, -1), "rim_cor": (0.84, 0.93, 1.0),
          "rim_forca": 0.55, "rim_largura": 1}


def carregar_modulo(nome, caminho, ossos_mod=None):
    """Importa `caminho` com nome próprio (as duas pastas têm ossos.py e anim_parado.py). `ossos_mod` = o ossos que o módulo deve enxergar."""
    if ossos_mod is not None:
        sys.modules["ossos"] = ossos_mod
    spec = importlib.util.spec_from_file_location(nome, str(caminho))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    sys.modules.pop("ossos", None)
    return mod


# ------------------------------------------------------------------ 1. cena: abre o rig do mecha e acrescenta as peças do lobo
blend_mecha = PASTA_MECHA / "lightwolf_mecha_rig.blend"
if not blend_mecha.exists():
    raise SystemExit("rig do mecha não encontrado: %s (use -- --mecha=<pasta lightwolf_mecha>)" % blend_mecha)
bpy.ops.wm.open_mainfile(filepath=str(blend_mecha))
cena = bpy.context.scene
arm_m = bpy.data.objects["LW mecha rig"]
MECHA = [o for o in arm_m.children]
cam = cena.camera
cam_data = cam.data

with bpy.data.libraries.load(str(PASTA_LOBO / "lobo_rig.blend"), link=False) as (de, para):
    nomes_lobo = [n for n in de.objects if n != "cam"]
    para.objects = list(nomes_lobo)
LOBO_DE = dict(zip(nomes_lobo, para.objects))           # nome original no rig do lobo -> objeto acrescentado (pode ganhar sufixo .001)
for o in para.objects:
    cena.collection.objects.link(o)
arm_l = LOBO_DE["Lucas rig"]
LOBO = [o for o in para.objects if o is not arm_l]
CASCAS = [o for o in LOBO if o.name.startswith("Contorno — ")]
ARMA = [o for o in LOBO if "Adaga na mão" in o.name]     # pistola de cada mão (e as cascas dela)

# base e delta de cada casca (casca = cópia da malha original + normal * CONTORNO): para afinar a casca e mantê-la com ~1 px no retrato
DELTA = {}
for c in CASCAS:
    orig = LOBO_DE[c.name[len("Contorno — "):]]
    n = len(c.data.vertices)
    assert n == len(orig.data.vertices), "casca e original com malhas diferentes: " + c.name
    b, d = np.empty(n * 3, np.float32), np.empty(n * 3, np.float32)
    orig.data.vertices.foreach_get("co", b)
    c.data.vertices.foreach_get("co", d)
    DELTA[c] = (b, d - b)

ossos_m = carregar_modulo("ossos_mecha", PASTA_MECHA / "ossos.py")
parado_m = carregar_modulo("parado_mecha", PASTA_MECHA / "anim_parado.py", ossos_m)
ossos_l = carregar_modulo("ossos_lobo", PASTA_LUCAS / "ossos.py")

# ------------------------------------------------------------------ 2. render: o rig do mecha foi salvo com a transformação "Raw" (passada de normal)
cena.render.engine = "CYCLES"
cena.cycles.samples = 1
cena.cycles.use_denoising = False
cena.cycles.pixel_filter_type = "BOX"
cena.cycles.filter_width = 0.01
cena.render.film_transparent = True
cena.render.threads_mode = "FIXED"
cena.render.threads = 4
cena.view_settings.view_transform = "Standard"
cena.view_settings.look = "None"
cena.render.dither_intensity = 0
cena.render.image_settings.file_format = "PNG"
cena.render.image_settings.color_mode = "RGBA"
cena.render.image_settings.color_depth = "8"
el = math.radians(ELEV)
cam.location = (0.0, -20.0 * math.cos(el), 20.0 * math.sin(el))
cam.rotation_euler = (math.pi / 2 - el, 0.0, 0.0)
cam_data.shift_x = cam_data.shift_y = 0.0
TMP = Path(bpy.app.tempdir or ".") / "lw_retrato"
TMP.mkdir(parents=True, exist_ok=True)


# ------------------------------------------------------------------ 3. poses
def posar_mecha():
    ossos_m.zerar(arm_m)
    arm_m.rotation_euler = (0.0, 0.0, math.radians(MECHA_ANG))
    parado_m.posar(arm_m, 0, parado_m.N_QUADROS)        # o parado da folha (quadro 0)
    for o in MECHA:
        if o.name.startswith("Piloto"):
            o.hide_render = True                         # o piloto está fora, encostado na perna: a cabine fica vazia


def posar_lobo():
    """Pose "D.Va": de pé na frente da perna esquerda (da tela) do mecha, recostado com as costas na canela/coxa dele, braços cruzados no peito,
    pernas cruzadas e a cabeça um pouco inclinada para a câmera. A pistola fica na mão esquerda (da tela), por baixo do cruzamento."""
    o = ossos_l
    o.zerar(arm_l)
    # pernas: a de dentro (perto do mecha) firme; a de fora cruza por cima, ponta do pé no chão
    o.girar(arm_l, "perna_d", x=0.05, y=0.10)
    o.girar(arm_l, "perna_e", x=-0.18, y=-0.28, z=0.2)
    o.girar(arm_l, "canela_e", x=0.22)
    o.girar(arm_l, "pe_e", x=0.25)
    o.girar(arm_l, "quadril", y=0.06)
    o.girar(arm_l, "torso", y=0.05, x=0.06)
    o.girar(arm_l, "cabeca", **POSE_CABECA)
    o.girar(arm_l, "braco_d", **POSE_BRACO_D)
    o.girar(arm_l, "antebraco_d", **POSE_ANTEBRACO_D)
    o.girar(arm_l, "braco_e", **POSE_BRACO_E)
    o.girar(arm_l, "antebraco_e", **POSE_ANTEBRACO_E)
    o.adaga(arm_l, d=False, e=True)
    o.pisar(arm_l)
    for p in ARMA:
        p.hide_render = not arm_l.get("adaga_" + p.name.split(".")[0][-1])
    arm_l.scale = Vector(ESCALA_LOBO0) * LOBO_ESCALA
    arm_l.rotation_mode = "ZYX"                          # vira (Z) e depois recosta para trás (X do mundo)
    arm_l.rotation_euler = (math.radians(-LOBO_RECOSTA), 0.0, math.radians(LOBO_ANG))
    # na frente da canela esquerda (da tela) do mecha; desliza em y até as costas do lobo encostarem nela (CONTATO)
    bpy.context.view_layer.update()
    canela = [q for q in MECHA if q.name.startswith(("Canela esquerda", "Joelho esquerda", "Coxa esquerda", "Joelheira esquerda"))]
    vc = np.array([q.matrix_world @ v.co for q in canela for v in q.data.vertices])
    arm_l.location = (vc[:, 0].mean() + LOBO_X, vc[:, 1].min() - 1.0, 0.0)
    bpy.context.view_layer.update()
    pecas = [q for q in LOBO if q.type == "MESH" and not q.hide_render and q.parent_bone in ("torso", "quadril", "cabeca")
             and not q.name.startswith(("Contorno", "Cauda"))]
    vl = np.array([q.matrix_world @ v.co for q in pecas for v in q.data.vertices])
    vm = np.array([q.matrix_world @ v.co for q in MECHA if q.type == "MESH" and not q.hide_render for v in q.data.vertices])
    x0, x1 = vl[:, 0].min(), vl[:, 0].max()
    gap = 1e9
    for z in np.linspace(vl[:, 2].min(), vl[:, 2].max(), 24):
        fl = vl[np.abs(vl[:, 2] - z) < 0.06]
        fm = vm[(np.abs(vm[:, 2] - z) < 0.06) & (vm[:, 0] > x0) & (vm[:, 0] < x1)]
        if len(fl) and len(fm):
            gap = min(gap, fm[:, 1].min() - fl[:, 1].max())
    if gap < 1e8:
        arm_l.location.y += gap + CONTATO
    print("CONTATO: lobo em (%.2f, %.2f); vão corrigido %.3f" % (arm_l.location.x, arm_l.location.y, gap + CONTATO))


ESCALA_LOBO0 = tuple(arm_l.scale)


def caixa_px(objs, T):
    """Caixa (x0, x1, y0, y1) em pixels do quadro T x T (y para baixo) dos vértices de `objs`, na câmera atual."""
    bpy.context.view_layer.update()
    p = [world_to_camera_view(cena, cam, o.matrix_world @ v.co) for o in objs if o.type == "MESH" and not o.hide_render for v in o.data.vertices]
    xs, ys = [q.x * T for q in p], [(1.0 - q.y) * T for q in p]
    return min(xs), max(xs), min(ys), max(ys)


def altura_mundo(objs):
    bpy.context.view_layer.update()
    zs = [(o.matrix_world @ v.co).z for o in objs if o.type == "MESH" and not o.hide_render for v in o.data.vertices]
    return min(zs), max(zs)


# ------------------------------------------------------------------ 4. render de cor + render de identidade (quem é dono de cada pixel)
mat_id = {}
for nome, cor in (("mecha", (1.0, 0.0, 0.0)), ("lobo", (0.0, 1.0, 0.0))):
    m = bpy.data.materials.new("id_" + nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    em, sai = nt.nodes.new("ShaderNodeEmission"), nt.nodes.new("ShaderNodeOutputMaterial")
    em.inputs["Color"].default_value = cor + (1.0,)
    nt.links.new(em.outputs[0], sai.inputs["Surface"])
    mat_id[nome] = m
ORIG = {o: list(o.data.materials) for o in MECHA + LOBO if o.type == "MESH"}


def renderizar(caminho, identidade=False):
    cena.view_settings.view_transform = "Raw" if identidade else "Standard"
    for o, mats in ORIG.items():
        for i in range(len(mats)):
            o.data.materials[i] = (mat_id["lobo" if o in LOBO else "mecha"] if identidade else mats[i])
    cena.render.filepath = str(caminho)
    bpy.ops.render.render(write_still=True)


def ler(caminho):
    img = bpy.data.images.load(str(caminho), check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1].copy()
    bpy.data.images.remove(img)
    return px


def gravar(px, caminho):
    h, w = px.shape[:2]
    img = bpy.data.images.new("saida", w, h, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels[:] = px[::-1].ravel()
    img.filepath_raw = str(caminho)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def retrato(T):
    cena.render.resolution_x = cena.render.resolution_y = T
    cena.render.resolution_percentage = 100
    cam_data.shift_x = cam_data.shift_y = 0.0
    cam_data.ortho_scale = 10.0
    todos = MECHA + LOBO
    x0, x1, y0, y1 = caixa_px(todos, T)
    cam_data.ortho_scale *= max(y1 - y0, x1 - x0) / float(T - 2 * MARGEM[T])     # o par inteiro cabe com MARGEM px livres
    x0, x1, y0, y1 = caixa_px(todos, T)
    cam_data.shift_y -= ((y0 + y1) / 2.0 - T / 2.0) / T     # y do quadro cresce para baixo; o shift_y, para cima
    cam_data.shift_x -= (T / 2.0 - (x0 + x1) / 2.0) / T
    ppu = T / cam_data.ortho_scale
    k = PPU_FOLHA / (ppu * LOBO_ESCALA)                   # casca do lobo de volta a ~1 px nesta escala
    for c, (b, d) in DELTA.items():
        c.data.vertices.foreach_set("co", b + d * k)
        c.data.update()
    renderizar(TMP / "cor.png")
    renderizar(TMP / "id.png", identidade=True)
    px, ident = ler(TMP / "cor.png"), ler(TMP / "id.png")
    mascara = px[..., 3] > 0.5
    lobo = mascara & (ident[..., 1] > ident[..., 0])
    px[..., 3] = np.where(mascara, 1.0, 0.0)               # alfa binário, como as folhas
    px[~mascara] = 0.0
    # acabamento 2D: contorno + rim do par contra o fundo; o lobo (na frente) ganha também o anel dele contra o mecha
    estilo2d.aplicar(px, mascara, ESTILO)
    estilo2d.aplicar(px, lobo, ESTILO)
    for c, (b, d) in DELTA.items():
        c.data.vertices.foreach_set("co", b + d)
        c.data.update()
    DESTINO.mkdir(parents=True, exist_ok=True)
    gravar(px, DESTINO / TAMANHOS[T])
    zm, zM = altura_mundo(MECHA)
    zl, zL = altura_mundo(LOBO)
    zc = altura_mundo([o for o in MECHA if o.name.startswith("Cintura")])
    zp = altura_mundo([o for o in MECHA if o.name.startswith("Pelve")])
    print("ALTURAS: topo do lobo %.2f; mecha: pelve %.2f-%.2f, cintura %.2f-%.2f, topo %.2f" % (zL, zp[0], zp[1], zc[0], zc[1], zM))
    print("RETRATO_OK %s (%dx%d, %.1f px/m; lobo = %.0f%% da altura do mecha; casca x%.2f)"
          % (DESTINO / TAMANHOS[T], T, T, ppu, 100.0 * (zL - zl) / (zM - zm), k))
    return px


posar_mecha()
posar_lobo()
saidas = {T: retrato(T) for T in sorted(TAMANHOS)}

if OPC.get("previa"):
    # prévia: 256 em x2 e 128 em x4 (mesma altura), sobre fundo escuro e claro
    def ampliar(p, f):
        return np.repeat(np.repeat(p, f, axis=0), f, axis=1)

    blocos = [ampliar(saidas[256], 2), ampliar(saidas[128], 4)]
    linhas = []
    for fundo in ((0.10, 0.11, 0.15), (0.62, 0.66, 0.72)):
        lin = []
        for b in blocos:
            f = np.empty_like(b)
            f[..., :3] = fundo
            f[..., 3] = 1.0
            a = b[..., 3:4]
            f[..., :3] = b[..., :3] * a + f[..., :3] * (1 - a)
            lin += [f, np.ones((b.shape[0], 8, 4), np.float32)]
        linhas += [np.concatenate(lin[:-1], axis=1), np.ones((8, sum(x.shape[1] for x in lin[:-1]), 4), np.float32)]
    gravar(np.concatenate(linhas[:-1], axis=0), Path(OPC["previa"]))
    print("PREVIA_OK", OPC["previa"])

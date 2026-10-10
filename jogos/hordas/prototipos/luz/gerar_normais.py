"""Normal maps dos sprites (protótipo de luz 2.5D). NÃO altera os geradores principais.

Reaproveita o gerador de verdade (hazaki.py, horror.py/monstros.py) trocando, em tempo de execução, só o que
muda pra gerar normal: os materiais viram emissão da normal em espaço de câmera (R = x, G = y, B = z, em
0.5 + 0.5 * n), a paleta e o contorno escuro saem, a view é 'Raw' (sem curva de cor) e sem dither. Enquadramento,
câmera, pose e recorte são os mesmos do sprite base, então o alfa tem que bater pixel a pixel (conferido na
hora: Hazaki e cão de ossos, 0 pixels de diferença). Nada de assets/ nem de dados/ é tocado: registrar_colunas vira
no-op.

Pós-processo (só na normal): exagero de inclinação no XY (ESTICA) e bisel de borda por quadro (BISEL), porque a
geometria quase não inclina a frente de um sprite e o relevo some. São escolhas de arte, documentadas aqui.

Saída: prototipos/luz/normais/normal_<arquivo>.png (mesmo nome do sprite base, com prefixo normal_).
Cópias dos sprites base (sem render): prototipos/luz/base/.

Uso (Blender 4.5 LTS):
    blender -b -P gerar_normais.py -- heroi
    blender -b -P gerar_normais.py -- monstro cao_ossos
"""
import os
import shutil
import sys
import tempfile

import bpy
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
HORDAS = os.path.normpath(os.path.join(AQUI, "..", ".."))
GERADORES = os.path.join(HORDAS, "fonte_arte", "modelos3d")
PROJETO = os.path.join(HORDAS, "projeto")
SAIDA = os.path.join(AQUI, "normais")
BASE = os.path.join(AQUI, "base")

sys.path.insert(0, GERADORES)
import pixel3d as px3  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["heroi"]
MODO = ARGS[0]
# o gerador de monstro espelha a imagem (folha[...] = pixelar(...)[:, ::-1]); aí o canal X da normal tem que inverter também
INVERTE_X = MODO == "monstro"


def copiar_base():
    """Cópias dos sprites base do projeto (só copia, nada é gerado de novo nem sobrescrito)."""
    os.makedirs(BASE, exist_ok=True)
    for origem in (
        os.path.join(PROJETO, "assets", "personagens", "hazaki", "andando_8.png"),
        os.path.join(PROJETO, "assets", "personagens", "hazaki", "corpo.png"),
        os.path.join(PROJETO, "assets", "personagens", "hazaki", "rosto.png"),
        os.path.join(PROJETO, "assets", "gerado", "inimigo_cao_ossos.png"),
    ):
        if os.path.exists(origem):
            shutil.copy2(origem, os.path.join(BASE, os.path.basename(origem)))


# ---------------------------------------------------------------- patches (só em memória)

_preparar_original = px3.preparar_render


def preparar_normal(largura, altura):
    cena = _preparar_original(largura, altura)
    cena.view_settings.view_transform = "Raw"    # valor linear cru: a normal não passa por curva de cor
    cena.render.dither_intensity = 0.0            # sem ruído de dither no 8 bits
    return cena


def material_normal(nome, *_args, **_kwargs):
    """Emissão da normal em espaço de câmera. Ignora luz: a cor é a própria normal."""
    m = bpy.data.materials.new("normal_" + nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    tr = nt.nodes.new("ShaderNodeVectorTransform")
    tr.vector_type = "NORMAL"
    tr.convert_from = "WORLD"
    tr.convert_to = "CAMERA"
    mad = nt.nodes.new("ShaderNodeVectorMath")
    mad.operation = "MULTIPLY_ADD"                # n * (0.5, 0.5, -0.5) + 0.5
    # Z entra com sinal invertido de propósito: medido no Blender 4.5 (diag com planos e cubo), o Vector Transform
    # mundo -> câmera devolve o Z ao contrário (face de frente sai com Z = -1). X e Y chegam certos.
    mad.inputs[1].default_value = (0.5, 0.5, -0.5)
    mad.inputs[2].default_value = (0.5, 0.5, 0.5)
    emi = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(geo.outputs["Normal"], tr.inputs["Vector"])
    nt.links.new(tr.outputs["Vector"], mad.inputs[0])
    nt.links.new(mad.outputs["Vector"], emi.inputs["Color"])
    nt.links.new(emi.outputs["Emission"], out.inputs["Surface"])
    return m


def render_normal():
    """Como px3.render_rgba, mas lendo o PNG como dado bruto (Non-Color): a normal não é cor."""
    caminho = os.path.join(tempfile.gettempdir(), "luz_normal_%d.png" % os.getpid())
    bpy.context.scene.render.filepath = caminho
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(caminho, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(img)
    return px


def pixelar_normal(px, contorno=True, paleta=None, luz_borda=True, pontilhado=0.0):
    """Mesmo recorte e alfa binário do pixelar original; sem paleta. Contorno vira a normal 'reta' (0.5, 0.5, 1)."""
    out = np.zeros_like(px)
    cheio = px[:, :, 3] > 0.5
    n = px[:, :, :3].copy()
    if INVERTE_X:
        n[:, :, 0] = 1.0 - n[:, :, 0]
    out[:, :, :3][cheio] = n[cheio]
    out[:, :, 3][cheio] = 1.0
    if contorno:
        viz = np.zeros_like(cheio)
        viz[1:, :] |= cheio[:-1, :]
        viz[:-1, :] |= cheio[1:, :]
        viz[:, 1:] |= cheio[:, :-1]
        viz[:, :-1] |= cheio[:, 1:]
        borda = viz & ~cheio
        out[:, :, :3][borda] = (0.5, 0.5, 1.0)
        out[:, :, 3][borda] = 1.0
    return out


ESTICA = 2.0   # inclinação exagerada no XY antes de renormalizar: a geometria real é quase toda voltada pra câmera,
               # e sem isso a luz quase não cria relevo (escolha de arte, pixel art pede relevo marcado)


def esticar(px):
    """Normal (x, y, z) -> (x * ESTICA, y * ESTICA, z) renormalizada, só nos pixels opacos."""
    alfa = px[:, :, 3] > 0.5
    n = px[:, :, :3] * 2.0 - 1.0
    n[:, :, 0] *= ESTICA
    n[:, :, 1] *= ESTICA
    n /= np.linalg.norm(n, axis=2, keepdims=True) + 1e-8
    px[:, :, :3] = np.where(alfa[:, :, None], n * 0.5 + 0.5, px[:, :, :3])
    return px


BISEL = 0.8        # força do relevo de borda (a silhueta vira um bisel de BISEL_PX pixels)
BISEL_PX = 4
GRADE = {"heroi": (44, 60), "cao_ossos": (50, 45)}   # tamanho do quadro em cada folha (o bisel é por quadro)


def _erodir(m):
    p = np.pad(m, 1, constant_values=False)
    return m & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]


def biselar(px):
    """Relevo de borda: altura = distância até a borda da silhueta (até BISEL_PX px), o gradiente dela vira normal
    e é somado à normal geométrica. A geometria quase não inclina a frente de um sprite; a borda sim, e é ali que a
    luz de lado pega o volume. Só dentro do quadro (px é um quadro), em espaço de câmera (Y pra cima, como no resto)."""
    m = px[:, :, 3] > 0.5
    if not m.any():
        return px
    h = np.zeros(m.shape, np.float32)
    cur = m.copy()
    for _ in range(BISEL_PX):
        cur = _erodir(cur)
        h += cur
    drow, dcol = np.gradient(h)
    n = px[:, :, :3] * 2.0 - 1.0
    nx = n[:, :, 0] - dcol * BISEL
    ny = n[:, :, 1] + drow * BISEL          # linha cresce pra baixo; Y da normal cresce pra cima
    nz = np.maximum(n[:, :, 2], 0.2)
    v = np.stack([nx, ny, nz], axis=2)
    v /= np.linalg.norm(v, axis=2, keepdims=True) + 1e-8
    px[:, :, :3] = np.where(m[:, :, None], v * 0.5 + 0.5, px[:, :, :3])
    return px


def biselar_folha(px, quadro):
    """Aplica o bisel quadro a quadro (a folha tem vários quadros lado a lado; a borda de um não pode alimentar o vizinho)."""
    if quadro is None:
        return biselar(px)
    qw, qh = quadro
    h, w = px.shape[:2]
    if h % qh or w % qw:
        return biselar(px)
    out = px.copy()
    for y in range(0, h, qh):
        for x in range(0, w, qw):
            out[y:y + qh, x:x + qw] = biselar(px[y:y + qh, x:x + qw].copy())
    return out


def salvar_normal(px, caminho):
    """Salva o PNG da normal (8 bits, Non-Color). O flash branco do monstro (RGB = 1) vira normal reta."""
    destino = os.path.join(SAIDA, "normal_" + os.path.basename(caminho))
    px = px.astype(np.float32).copy()
    branco = (px[:, :, 3] > 0.5) & np.all(px[:, :, :3] > 0.999, axis=2)
    px[branco, :3] = (0.5, 0.5, 1.0)
    px = esticar(px)
    px = biselar_folha(px, GRADE.get(MODO if MODO == "heroi" else ARGS[1] if len(ARGS) > 1 else None))
    h, w = px.shape[:2]
    os.makedirs(SAIDA, exist_ok=True)
    img = bpy.data.images.new("normal_saida", w, h, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels[:] = px[::-1].ravel()
    img.filepath_raw = destino
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    print("NORMAL salva:", destino)


px3.preparar_render = preparar_normal
px3.material_toon = material_normal
px3.material_emissao = material_normal
px3.render_rgba = render_normal
px3.pixelar = pixelar_normal
px3.salvar_png = salvar_normal

copiar_base()

if MODO == "heroi":
    import hazaki  # noqa: F401  (o módulo roda o próprio main() ao importar)
elif MODO == "monstro":
    import monstros
    monstros.registrar_colunas = lambda *a, **k: None   # não toca em projeto/dados
    sys.argv = sys.argv[:sys.argv.index("--") + 1] + ARGS[1:]   # rodar() lê só os nomes de monstro depois de --
    import horror  # noqa: F401  (roda rodar() com os nomes depois de --)
else:
    raise SystemExit("modo desconhecido: %s" % MODO)

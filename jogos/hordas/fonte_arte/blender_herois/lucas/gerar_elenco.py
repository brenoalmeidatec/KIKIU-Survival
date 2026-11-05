"""Gera os quadros do LUKE (Blender 4.5) no PADRÃO DO ELENCO (issue #586): roda o gerar.py desta pasta (rig, câmera, luz, contorno, normal e as anim_*.py)
com trocas de texto no código, SEM editar o gerar.py: o gerar.py do Luke também é a base do lobo do LightWolf (../lightwolf_lobo/gerar.py faz trocas de
texto nele), e mexer nele quebraria as âncoras do lobo. O que muda aqui:
  - paleta roxa saturada (cor-assinatura), cabeça maior (CABECA), adagas 1,5x mais compridas e mais claras (as das mãos; as do corpo ficam como eram, para o tronco não virar um pente de riscos brancos),
  - contorno escuro de 1 px + rim light (../hazaki/estilo2d.py) em cada quadro de cor,
  - retrato 64x64 em assets/personagens/lucas/retrato.png (busto em 3/4, mesma câmera dos outros heróis).

    blender -b -t 4 -P gerar_elenco.py                     # todas as animações + retrato
    blender -b -t 4 -P gerar_elenco.py -- --anim=andar     # só uma animação (sem retrato)
    blender -b -t 4 -P gerar_elenco.py -- --retrato        # só o retrato
Saída: quadros/<anim>/... e lucas_rig.blend (igual ao gerar.py); depois: python montar_folha.py
"""
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
LUCAS = AQUI / "gerar.py"

CABECA_NOVA = 1.32
ARMA_ESCALA = 1.5        # adagas 1,5x mais compridas
ARMA_ESPESSURA = 1.15    # e 15% mais grossas
ARMA_CLAREAR = 0.30      # materiais das adagas 30% mais perto do branco (cópias)
PALETA_NOVA = {          # roxo saturado e médio (o shader ainda escurece em 4 faixas); o resto da paleta fica como era
    "Roxo do capuz": "#8a2cc4", "Roxo iluminado": "#a64ae0", "Roxo das dobras": "#5a1c8c",
    "Calça escura": "#2e2a48", "Camisa escura": "#34305a",
    "Lenço dourado": "#e0c4f8", "Lenço verso": "#b090d8",    # o lenço deixa de ser dourado: o amarelo-dourado é da Lukako
}
RETRATO = {"pasta": "lucas", "cranio": "Cabeça facetada"}


def trocar(src, a, b):
    assert src.count(a) == 1, "trecho não encontrado (o gerar.py do Luke mudou?): " + a[:70]
    return src.replace(a, b)


src = LUCAS.read_text(encoding="utf-8")

# ---- flags, parâmetros e acabamento 2D
src = trocar(src, 'SAIDA = AQUI / "quadros"', '''SAIDA = AQUI / "quadros"
SO_RETRATO = "--retrato" in ARGS           # só o retrato 64x64 (pula as animações)
SEM_RETRATO = "--sem-retrato" in ARGS      # todas as animações sem o retrato
ARMA_ESCALA, ARMA_ESPESSURA, ARMA_CLAREAR = %r, %r, %r
ESTILO_ELENCO = {"contorno": True, "escuro": 0.30, "teto": 0.16,
                 "rim": True, "rim_dir": (1, -1), "rim_cor": (0.84, 0.93, 1.0), "rim_forca": 0.55, "rim_largura": 1}
ESTILO_2D = dict(ESTILO_ELENCO)
RETRATO_PADRAO = {"tam": 64, "ang": 45.0, "elev": 18.0, "cranio_px": 33.0, "topo_px": 4, "centro_x": 0.5,
                  "anim": "parado", "quadro": 0, "arma": False, "cranio": "Cabeça facetada", "pasta": "lucas"}
RETRATO = %r''' % (ARMA_ESCALA, ARMA_ESPESSURA, ARMA_CLAREAR, RETRATO))
src = trocar(src, "import ossos  # noqa: E402", "import ossos  # noqa: E402\nsys.path.append(r'%s')    # no FIM do path: os módulos do Luke ganham\nimport estilo2d  # noqa: E402"
             % (AQUI.parent / "hazaki"))
src = trocar(src, "CABECA = 1.32", "CABECA = %r" % CABECA_NOVA)
src = trocar(src, "cena.render.threads = 6", "cena.render.threads = int(sys.argv[sys.argv.index(\"-t\") + 1]) if \"-t\" in sys.argv[:sys.argv.index(\"--\") if \"--\" in sys.argv else len(sys.argv)] else 6")

# ---- paleta + adagas (antes da seção dos materiais)
ARMA_CODIGO = '''PALETA.update(%r)

# ARMA (adagas): 1,5x mais compridas (na malha, em torno da mão que segura) e cópia clareada dos materiais
bpy.context.view_layer.update()
GRUPOS_ARMA = {}
for o in heroi:
    if o.name.startswith("Adaga na mão "):
        GRUPOS_ARMA.setdefault("mao " + o.name[-1], []).append(o)
ARMA = [o for g in GRUPOS_ARMA.values() for o in g]
for chave, grupo in GRUPOS_ARMA.items():
    pts = [o.matrix_world @ v.co for o in grupo for v in o.data.vertices]
    if chave.startswith("mao "):
        pivo = Vector(PONTOS["punho_" + chave[-1]]) + Vector((0.02, -0.04, -0.09))      # a mão que segura
    else:
        pivo = max(pts, key=lambda q: q.z).copy()                                           # o topo do cabo (a adaga pende dele)
    longe = max(pts, key=lambda q: (q - pivo).length)
    d = (longe - pivo).normalized()
    dd = Matrix([[d[i] * d[j] for j in range(3)] for i in range(3)])
    M3 = Matrix.Identity(3) * ARMA_ESPESSURA + dd * (ARMA_ESCALA - ARMA_ESPESSURA)
    X = Matrix.Translation(pivo) @ M3.to_4x4() @ Matrix.Translation(-pivo)
    for o in grupo:
        o.data.transform(o.matrix_world.inverted() @ X @ o.matrix_world)
        o.data.update()
for o in ARMA:
    for i, m in enumerate(o.data.materials):
        if m is None or m.name not in PALETA:
            continue
        nome_c = m.name + " (arma)"
        if nome_c not in PALETA:
            b = hexa(PALETA[m.name])
            PALETA[nome_c] = "#%%02x%%02x%%02x" %% tuple(int(round(255 * (v + (1.0 - v) * ARMA_CLAREAR))) for v in b)
        o.data.materials[i] = bpy.data.materials.get(nome_c) or m.copy()
        o.data.materials[i].name = nome_c
print("ARMA: %%d peças em %%d adagas, escala %%.2f, espessura %%.2f, clarear %%.2f" %% (len(ARMA), len(GRUPOS_ARMA), ARMA_ESCALA, ARMA_ESPESSURA, ARMA_CLAREAR))

''' % (PALETA_NOVA,)
src = trocar(src, "# ============================================================ 2. materiais: 4 faixas", ARMA_CODIGO + "# ============================================================ 2. materiais: 4 faixas")

# ---- casca do contorno guarda base e delta (o retrato afina a casca para ~1 px); cascas das adagas entram em ARMA
src = trocar(src, "CASCAS = []\nfor original in list(heroi):", "CASCAS = []\nDELTA_CASCA = {}\nfor original in list(heroi):")
src = trocar(src, """    for v in copia.data.vertices:
        v.co = v.co + Ai @ ((Ai.transposed() @ v.normal).normalized() * CONTORNO)
    copia.data.update()""", """    _base = np.empty(len(copia.data.vertices) * 3, np.float32)
    copia.data.vertices.foreach_get("co", _base)
    _delta = []
    for v in copia.data.vertices:
        dv = Ai @ ((Ai.transposed() @ v.normal).normalized() * CONTORNO)
        _delta.extend(dv)
        v.co = v.co + dv
    DELTA_CASCA[copia] = (_base, np.array(_delta, np.float32))
    copia.data.update()""")
src = trocar(src, "    CASCAS.append(copia)\nheroi += CASCAS", "    CASCAS.append(copia)\n    if original in ARMA:\n        ARMA.append(copia)\nheroi += CASCAS")

# ---- ler/gravar_normal para qualquer tamanho (o retrato é 64x64)
src = trocar(src, "px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1].copy()",
             "w, h = img.size\n    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1].copy()")
src = trocar(src, 'img = bpy.data.images.new("n", W, H, alpha=True)', 'img = bpy.data.images.new("n", px.shape[1], px.shape[0], alpha=True)')

# ---- acabamento 2D em cada quadro de cor (contorno escuro + rim), antes do rastro
src = trocar(src, """            if polis:
                cor = ler(str(base) + "_cor.png", True)
                pintar_poligonos(cor, nor, mascara, polis)
                gravar_normal(cor, str(base) + "_cor.png")""", """            if polis or ESTILO_2D:
                cor = ler(str(base) + "_cor.png", True)
                estilo2d.aplicar(cor, mascara, ESTILO_2D)               # contorno escuro + rim: só no corpo, antes do rastro
                if polis:
                    pintar_poligonos(cor, nor, mascara, polis)
                gravar_normal(cor, str(base) + "_cor.png")""")

# ---- medida da cabeça (depois da calibragem)
MEDIDA = '''

def medir_cabeca(topo_px, pe_px):
    """Cabeça no parado de frente: do topo do desenho ao queixo ('Cabeça facetada'), sobre a altura toda. A ponta do capuz não conta na massa."""
    bpy.context.view_layer.update()
    cran = [o for o in CORPO if o.name == "Cabeça facetada"]
    queixo = max((1.0 - world_to_camera_view(cena, cam, o.matrix_world @ v.co).y) * H for o in cran for v in o.data.vertices)
    cab_objs = [o for o in heroi if OSSO_DE.get(o) == "cabeca" and o.type == "MESH"]
    topo_px = min(topo_px, min((1.0 - world_to_camera_view(cena, cam, o.matrix_world @ v.co).y) * H for o in cab_objs for v in o.data.vertices))
    if topo_px < 0:
        print("AVISO: a cabeça passa %.1f px do topo do quadro (cortada)" % -topo_px)
    alt = pe_px - topo_px + 1
    massa = [o for o in cab_objs if not o.name.startswith(("Ponta do capuz", "Contorno — Ponta do capuz"))]
    topo_m = min((1.0 - world_to_camera_view(cena, cam, o.matrix_world @ v.co).y) * H for o in massa for v in o.data.vertices)
    print("MEDIDA altura_px=%.1f cabeca_px=%.1f cabeca_pct=%.1f (com a ponta do capuz) massa_px=%.1f massa_pct=%.1f (sem a ponta; meta do elenco 35-40)"
          % (alt, queixo - topo_px, 100.0 * (queixo - topo_px) / alt, queixo - topo_m, 100.0 * (queixo - topo_m) / alt))


medir_cabeca(ys.min() - dy, ys.max() - dy)
'''
i = src.index('print("calibragem')
j = src.index("\n", i)
src = src[:j + 1] + MEDIDA + src[j + 1:]

# ---- retrato (igual ao do hazaki/gerar.py) no lugar do laço final das animações
RETRATO_CODIGO = '''# ============================================================ 7. RETRATO 64x64 (padrão do elenco; ver hazaki/gerar.py)
OCULTAS = set()


def retrato():
    r = dict(RETRATO_PADRAO)
    r.update(RETRATO or {})
    T = int(r["tam"])
    destino = AQUI.parents[2] / "projeto" / "assets" / "personagens" / r["pasta"] / "retrato.png"
    destino.parent.mkdir(parents=True, exist_ok=True)
    mod = importlib.import_module("anim_" + r["anim"])
    ossos.zerar(arm)
    arm.scale = (ESCALA * LARGURA, ESCALA, ESCALA)
    arm.location = LOC0
    arm.rotation_euler = (0, 0, math.radians(r["ang"]))
    if len(inspect.signature(mod.posar).parameters) >= 4:
        mod.posar(arm, int(r["quadro"]), mod.N_QUADROS, r["ang"])
    else:
        mod.posar(arm, int(r["quadro"]), mod.N_QUADROS)
    if not r["arma"]:
        ossos.adaga(arm, False, False)         # as adagas das mãos ficam fora do busto (renderizar() lê arm["adaga_*"])
    bpy.context.view_layer.update()
    salvo = (cam.location.copy(), cam.rotation_euler.copy(), cam_data.ortho_scale, cam_data.shift_x, cam_data.shift_y,
             cena.render.resolution_x, cena.render.resolution_y)
    el = math.radians(r["elev"])
    cam.location = (0.0, -20.0 * math.cos(el), 20.0 * math.sin(el))
    cam.rotation_euler = (math.pi / 2 - el, 0.0, 0.0)
    cena.render.resolution_x = cena.render.resolution_y = T
    cam_data.shift_x = cam_data.shift_y = 0.0
    cam_data.ortho_scale = max(W, H) / PPU
    bpy.context.view_layer.update()
    cabeca = [o for o in heroi if OSSO_DE.get(o) == "cabeca" and not o.hide_render]
    cran = [o for o in CORPO if o.name == r["cranio"]]

    def caixa(objs):
        bpy.context.view_layer.update()
        p = [world_to_camera_view(cena, cam, o.matrix_world @ v.co) for o in objs if o.type == "MESH" for v in o.data.vertices]
        xs_, ys_ = [q.x * T for q in p], [(1.0 - q.y) * T for q in p]
        return min(xs_), max(xs_), min(ys_), max(ys_)

    _, _, c0, c1 = caixa(cran)
    cam_data.ortho_scale *= (c1 - c0) / float(r["cranio_px"])
    x0, x1, y0, _ = caixa(cabeca)
    cam_data.shift_y += (r["topo_px"] - y0) / T
    cam_data.shift_x -= (T * r["centro_x"] - 0.5 * (x0 + x1)) / T
    ppu_r = T / cam_data.ortho_scale
    k = PPU / ppu_r
    for c, (b0, d0) in DELTA_CASCA.items():
        c.data.vertices.foreach_set("co", b0 + d0 * k)
        c.data.update()
    caminho = TMP / "retrato.png"
    renderizar(caminho)
    px = ler(caminho, True)
    mascara = px[:, :, 3] > 0.5
    px[..., 3] = np.where(mascara, 1.0, 0.0)
    px[~mascara] = 0.0
    est = dict(ESTILO_2D or ESTILO_ELENCO)
    est["abre_baixo"] = True
    estilo2d.aplicar(px, mascara, est)
    gravar_normal(px, str(destino))
    for c, (b0, d0) in DELTA_CASCA.items():
        c.data.vertices.foreach_set("co", b0 + d0)
        c.data.update()
    cam.location, cam.rotation_euler, cam_data.ortho_scale, cam_data.shift_x, cam_data.shift_y = salvo[:5]
    cena.render.resolution_x, cena.render.resolution_y = salvo[5], salvo[6]
    arm.location = LOC0
    arm.rotation_euler = (0, 0, 0)
    print("RETRATO_OK %s (%dx%d, %.1f px/m, %s)" % (destino, T, T, ppu_r, r["anim"]))


if not SO_RETRATO:
    for nome in animacoes():
        renderizar_animacao(nome)
if SO_RETRATO or not (SO_ANIM or SEM_RETRATO):
    retrato()
'''
src = trocar(src, "for nome in animacoes():\n    renderizar_animacao(nome)\n", RETRATO_CODIGO)
src = trocar(src, "if not SO_ANIM:\n    bpy.ops.wm.save_as_mainfile", "if not (SO_ANIM or SO_RETRATO):\n    bpy.ops.wm.save_as_mainfile")

exec(compile(src, str(LUCAS), "exec"), {"__name__": "__main__", "__file__": str(LUCAS)})

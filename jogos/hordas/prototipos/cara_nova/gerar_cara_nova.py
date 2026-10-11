"""Protótipo da cara nova (V1 + V2): ALBEDO sem sombra assada + NORMAL MAP + máscara de emissão (olhos), câmera a 45 graus,
escala nova (herói ~32x44 de quadro). NÃO altera os geradores principais (pixel3d, hazaki, monstros, horror, floresta):
reaproveita o modelo 3D deles e troca, só em memória, o que muda (materiais, câmera, escala, pós-processo).

Para cada sprite saem 3 PNGs com o MESMO enquadramento (mesmo alfa, pixel a pixel, o contorno de 1 px é o mesmo):
    <nome>_albedo.png   cor chapada na paleta do jogo, contorno escuro de 1 px, sem faixas de sombra e sem luz de borda
    <nome>_normal.png   normal em espaço de câmera (R = x, G = y pra cima, B = z), convenção validada no PR #148
    <nome>_emissao.png  só o que brilha sozinho (olhos, chamas) + 1 px de halo mais escuro; fora disso, transparente
    <nome>.json         tamanho do quadro e o que tem em cada linha/coluna

Folha: uma linha por vista, colunas = quadros. Herói: 8 direções (baixo, esquerda, direita, cima, baixo-esq, baixo-dir, cima-esq,
cima-dir) x [parado, andar 0, 2, 4, 6]. Monstro: linha 0 = frente, linha 1 = 3/4 frente-direita (o jogo espelha pro lado esquerdo)
x [andar 0..3]. Os bichos olham pra DIREITA.

Uso (Blender 4.5 LTS), a partir de jogos/hordas/prototipos/cara_nova:
    blender -b -P gerar_cara_nova.py -- heroi
    blender -b -P gerar_cara_nova.py -- monstro horror cao_ossos
    blender -b -P gerar_cara_nova.py -- monstro floresta aranha_tecela
Parâmetros no topo (ELEVACAO, PPU, QUADRO_HEROI, ESTICA, BISEL, SUAVIZA) são as escolhas de arte, documentadas no LEIA-ME.md.
"""
import json
import math
import os
import sys

import bpy
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
HORDAS = os.path.normpath(os.path.join(AQUI, "..", ".."))
GERADORES = os.path.join(HORDAS, "fonte_arte", "modelos3d")
SAIDA = os.path.join(AQUI, "sprites")
sys.path.insert(0, GERADORES)
import pixel3d as px3  # noqa: E402

# ------------------------------------------------------------------ parâmetros de arte
ELEVACAO = 45.0            # graus da câmera (hoje 32; a referência pede ~50)
PPU = 24.5                 # pixels por unidade do Blender (hoje 23.53 = 60/2.55). A 45 graus o herói encolhe na vertical (cos 45 < cos 32), então 24.5 dá ~40 px de arte (alvo da referência: ~43)
QUADRO_HEROI = (32, 44)    # (largura, altura) do quadro do herói (hoje 44x60, mas a arte tem só 44 px de altura: sobravam 16 px de margem)
PE_HEROI = 42              # linha do pé no quadro do herói (hoje 57 de 60)
ESCALA_MONSTRO = 0.8        # só pro quadro INICIAL da tabela (cada folha cresce até caber; hoje o quadro do herói tem 16 px de margem morta)
GANHO_ALBEDO = 1.0           # multiplicador linear da cor base
GAMA_ALBEDO = 0.6            # c ** GAMA em linear: levanta os escuros (quitina, roupa preta) sem estourar os claros; a cor chapada precisa ler no escuro
ESTICA = 2.0               # exagero da inclinação XY da normal (a geometria quase não inclina a frente de um sprite)
BISEL = 0.9                # força do relevo de borda
BISEL_PX = 3               # largura do bisel em pixels
SUAVIZA = 1                # passes de suavização 3x3 na normal (tira o ar de "caixa" sem perder a borda)
OLHO_ESCALA = 1.25         # os olhos/chamas são engrossados no modelo (a 17 px/u um olho de 0.05 u some)
ANDAR_HEROI = (0, 2, 4, 6)             # quadros do ciclo de 8 do hazaki.py que entram na folha (além do parado)
QUADROS_MONSTRO = 4

MODO = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "heroi"
ARGS = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []

PASSES = ("albedo", "normal", "emissao")
VARIANTES = {}   # nome do material de albedo -> {passe: material}


# ------------------------------------------------------------------ materiais (um por passe)

def _emissao(nome, cor_rgba, forca=1.0):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    emi = nt.nodes.new("ShaderNodeEmission")
    emi.inputs[0].default_value = cor_rgba
    emi.inputs[1].default_value = forca
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emi.outputs[0], out.inputs[0])
    return m


def _albedo(nome, cor_base, ruido=0.0, escala_ruido=6.0):
    """Cor chapada. Com 'ruido' (o que no toon virava textura de pedra/pelo) vira manchas de 2 tons da própria cor."""
    cor_base = tuple(min(1.0, c * GANHO_ALBEDO) ** GAMA_ALBEDO for c in cor_base[:3]) + (1.0,)
    m = bpy.data.materials.new("alb_" + nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    emi = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emi.outputs[0], out.inputs[0])
    if ruido > 0:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = escala_ruido
        tex.inputs["Detail"].default_value = 2.0
        rampa = nt.nodes.new("ShaderNodeValToRGB")
        rampa.color_ramp.interpolation = "CONSTANT"
        els = rampa.color_ramp.elements
        els[0].position = 0.0
        els[0].color = (px3.linear(1.0 - min(0.6, ruido * 1.6)),) * 3 + (1,)
        els[1].position = 0.5
        els[1].color = (1, 1, 1, 1)
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[7].default_value = cor_base
        nt.links.new(tex.outputs["Fac"], rampa.inputs[0])
        nt.links.new(rampa.outputs[0], mix.inputs[6])
        nt.links.new(mix.outputs[2], emi.inputs[0])
    else:
        emi.inputs[0].default_value = cor_base
    return m


def _normal(nome):
    """Emissão da normal em espaço de câmera (igual ao PR #148). Z entra com sinal invertido: medido no Blender 4.5,
    o Vector Transform mundo -> câmera devolve o Z ao contrário (face de frente sai com Z = -1)."""
    m = bpy.data.materials.new("nor_" + nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    tr = nt.nodes.new("ShaderNodeVectorTransform")
    tr.vector_type = "NORMAL"
    tr.convert_from = "WORLD"
    tr.convert_to = "CAMERA"
    mad = nt.nodes.new("ShaderNodeVectorMath")
    mad.operation = "MULTIPLY_ADD"
    mad.inputs[1].default_value = (0.5, 0.5, -0.5)
    mad.inputs[2].default_value = (0.5, 0.5, 0.5)
    emi = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(geo.outputs["Normal"], tr.inputs["Vector"])
    nt.links.new(tr.outputs["Vector"], mad.inputs[0])
    nt.links.new(mad.outputs["Vector"], emi.inputs["Color"])
    nt.links.new(emi.outputs["Emission"], out.inputs["Surface"])
    return m


def material_toon_novo(nome, cor_base, faixas=(0.35, 0.62, 1.0), limites=(0.22, 0.55), ruido=0.0, escala_ruido=6.0):
    """No lugar do toon em 3 faixas: albedo chapado. Mesma assinatura, pra os modelos não notarem."""
    alb = _albedo(nome, cor_base, ruido, escala_ruido)
    VARIANTES[alb.name] = {"albedo": alb, "normal": _normal(nome), "emissao": _emissao("emi0_" + nome, (0, 0, 0, 1)), "brilha": False}
    return alb


def material_emissao_novo(nome, cor_base, forca=1.0):
    alb = _emissao("alb_" + nome, cor_base, forca)
    VARIANTES[alb.name] = {"albedo": alb, "normal": _normal(nome), "emissao": _emissao("emi_" + nome, cor_base, forca), "brilha": True}
    return alb


def trocar_passe(passe):
    cena = bpy.context.scene
    cena.view_settings.view_transform = "Raw" if passe == "normal" else "Standard"
    cena.render.dither_intensity = 0.0
    for o in bpy.data.objects:
        if o.type == "MESH" and o.data.materials:
            v = VARIANTES.get(_nome_base(o))
            if v:
                o.data.materials[0] = v[passe]


def _nome_base(o):
    """Nome do material de albedo desse objeto (guardado na primeira vez, porque depois a vaga 0 muda de passe)."""
    if "_alb" not in o:
        o["_alb"] = o.data.materials[0].name
    return o["_alb"]


def engrossar_olhos():
    """Chamas e olhos emissivos crescem um pouco em volta do próprio centro (sem isso somem na escala nova)."""
    for o in bpy.data.objects:
        if o.type == "MESH" and o.data.materials:
            v = VARIANTES.get(_nome_base(o))
            if v and v["brilha"]:
                o.scale = tuple(s * OLHO_ESCALA for s in o.scale)


# ------------------------------------------------------------------ leitura do render e pós-processo

def ler_render():
    """Como px3.render_rgba, mas lendo como dado bruto (a normal não é cor). Linha 0 em cima."""
    caminho = os.path.join(os.environ.get("TEMP", "/tmp"), "cara_nova_%d.png" % os.getpid())
    bpy.context.scene.render.filepath = caminho
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(caminho, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(img)
    return px


def _contorno(cheio):
    viz = np.zeros_like(cheio)
    viz[1:, :] |= cheio[:-1, :]
    viz[:-1, :] |= cheio[1:, :]
    viz[:, 1:] |= cheio[:, :-1]
    viz[:, :-1] |= cheio[:, 1:]
    return viz & ~cheio


def pos_albedo(px, pal, espelha):
    out = px3.pixelar(px, contorno=True, paleta=pal, luz_borda=False)
    return out[:, ::-1] if espelha else out


def pos_normal(px, espelha):
    """Mesmo recorte e alfa binário do albedo; sem paleta. Contorno vira a normal 'reta' (0.5, 0.5, 1)."""
    out = np.zeros_like(px)
    cheio = px[:, :, 3] > 0.5
    n = px[:, :, :3].copy()
    out[:, :, :3][cheio] = n[cheio]
    out[:, :, 3][cheio] = 1.0
    # plano do sprite: desfaz a elevação da câmera (frente vertical -> (0,0,1); topo -> (0,1,0))
    c, s = math.cos(math.radians(ELEVACAO)), math.sin(math.radians(ELEVACAO))
    v = out[:, :, :3] * 2.0 - 1.0
    ny = c * v[:, :, 1] + s * v[:, :, 2]
    nz = -s * v[:, :, 1] + c * v[:, :, 2]
    v = np.stack([v[:, :, 0], ny, nz], axis=2)
    v[:, :, 0] *= ESTICA
    v[:, :, 1] *= ESTICA
    v /= np.linalg.norm(v, axis=2, keepdims=True) + 1e-8
    out[:, :, :3] = np.where(cheio[:, :, None], v * 0.5 + 0.5, out[:, :, :3])
    out = biselar(out)
    for _ in range(SUAVIZA):
        out = suavizar(out)
    borda = _contorno(cheio)
    out[:, :, :3][borda] = (0.5, 0.5, 1.0)
    out[:, :, 3][borda] = 1.0
    if espelha:
        out = out[:, ::-1].copy()
        out[:, :, 0] = np.where(out[:, :, 3] > 0.5, 1.0 - out[:, :, 0], out[:, :, 0])   # X da normal inverte junto
    return out


def _erodir(m):
    p = np.pad(m, 1, constant_values=False)
    return m & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]


def biselar(px):
    """Altura = distância até a borda da silhueta (até BISEL_PX px); o gradiente dela vira normal e soma à geométrica."""
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
    ny = n[:, :, 1] + drow * BISEL
    nz = np.maximum(n[:, :, 2], 0.2)
    v = np.stack([nx, ny, nz], axis=2)
    v /= np.linalg.norm(v, axis=2, keepdims=True) + 1e-8
    px[:, :, :3] = np.where(m[:, :, None], v * 0.5 + 0.5, px[:, :, :3])
    return px


def suavizar(px):
    """Média 3x3 só entre pixels opacos (a normal) e renormaliza: arredonda as quinas das caixas."""
    m = (px[:, :, 3] > 0.5).astype(np.float32)
    n = (px[:, :, :3] * 2.0 - 1.0) * m[:, :, None]
    pn = np.pad(n, ((1, 1), (1, 1), (0, 0)))
    pm = np.pad(m, 1)
    soma = sum(pn[dy:dy + n.shape[0], dx:dx + n.shape[1]] for dy in range(3) for dx in range(3))
    cont = sum(pm[dy:dy + n.shape[0], dx:dx + n.shape[1]] for dy in range(3) for dx in range(3))
    v = soma / np.maximum(cont, 1)[:, :, None]
    v /= np.linalg.norm(v, axis=2, keepdims=True) + 1e-8
    out = px.copy()
    out[:, :, :3] = np.where(m[:, :, None] > 0, v * 0.5 + 0.5, px[:, :, :3])
    return out


def pos_emissao(px, espelha):
    """Só o que brilha (cor exata) + 1 px de halo (cor x 0.45). Transparente no resto."""
    out = np.zeros_like(px)
    cheio = px[:, :, 3] > 0.5
    luz = cheio & (px[:, :, :3].max(axis=2) > 0.3)
    out[:, :, :3][luz] = np.clip(px[:, :, :3][luz] / np.maximum(px[:, :, :3][luz].max(axis=1, keepdims=True), 1e-4), 0, 1)
    out[:, :, 3][luz] = 1.0
    halo = _contorno(luz) & cheio
    if luz.any():
        cores = px[:, :, :3][luz]
        mediana = np.median(cores, axis=0)
        mediana = mediana / max(mediana.max(), 1e-4)
        out[:, :, :3][halo] = mediana * 0.45
        out[:, :, 3][halo] = 1.0
    return out[:, :, :][:, ::-1] if espelha else out


# ------------------------------------------------------------------ folha

def salvar(px, caminho):
    px3.salvar_png(px, caminho)


def montar_folha(nome, quadros, linhas, colunas, w, h):
    """quadros[(linha, coluna)] = {passe: array}. Devolve {passe: folha}."""
    folhas = {p: np.zeros((h * linhas, w * colunas, 4), np.float32) for p in PASSES}
    for (l, c), d in quadros.items():
        for p in PASSES:
            folhas[p][l * h:(l + 1) * h, c * w:(c + 1) * w] = d[p]
    return folhas


def gravar(nome, folhas, w, h, extra):
    os.makedirs(SAIDA, exist_ok=True)
    for p, f in folhas.items():
        if p == "emissao" and not (f[:, :, 3] > 0).any():
            continue
        px3.salvar_png(f, os.path.join(SAIDA, "%s_%s.png" % (nome, p)))
    info = {"quadro": [w, h], "elevacao": ELEVACAO, "ppu": PPU}
    info.update(extra)
    with open(os.path.join(SAIDA, nome + ".json"), "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)
    print("CARA_NOVA OK", nome, w, h, extra)


def render_tres(pal, espelha):
    """Os 3 passes do quadro atual, já pós-processados."""
    d = {}
    for p in PASSES:
        trocar_passe(p)
        px = ler_render()
        if p == "albedo":
            d[p] = pos_albedo(px, pal, espelha)
            alfa = d[p][:, :, 3]
        elif p == "normal":
            d[p] = pos_normal(px, espelha)
        else:
            d[p] = pos_emissao(px, espelha)
    # o alfa tem que ser o mesmo nos 3 (mesmo render, mesmo limiar); a normal e o albedo saem do mesmo contorno
    return d


# ------------------------------------------------------------------ herói

def exec_hazaki():
    """Carrega hazaki.py sem rodar o main() dele (ele roda sozinho ao importar): só queremos montar() e pose()."""
    caminho = os.path.join(GERADORES, "hazaki.py")
    with open(caminho, encoding="utf-8") as f:
        src = f.read()
    corte = src.rstrip().rsplit("\nmain()", 1)
    assert len(corte) == 2 and corte[1].strip() == "", "hazaki.py mudou: o main() não está mais no fim"
    ns = {"__name__": "hazaki_novo", "__file__": caminho}
    exec(compile(corte[0], caminho, "exec"), ns)
    return ns


def gerar_heroi():
    hz = exec_hazaki()
    w, h = QUADRO_HEROI
    px3.limpar_cena()
    VARIANTES.clear()
    px3.preparar_render(w, h)
    cam = px3.camera(elevacao_graus=ELEVACAO, escala=max(w, h) / PPU)
    raiz, corpo, p = hz["montar"]()
    visiveis = ("base", "cabelo", "botas", "bracadeiras", "katana_bainha") + (("armadura_samurai",) if "samurai" in ARGS else ())
    for nome, objs in hz["CAMADAS"].items():
        for o in objs:
            o.hide_render = nome not in visiveis
            o.is_holdout = False
    engrossar_olhos()
    trocar_passe("albedo")
    hz["pose"](corpo, p, "parado", 0)
    px3.calibrar_pe(cam, PE_HEROI, w, h)
    cx = px3.caixa_alfa(px3.render_rgba())
    print("HEROI caixa (x0,y0,x1,y1):", cx, "altura:", cx[3] - cx[1] + 1)
    pal = hz["PAL"]
    acoes = [("parado", 0)] + [("andar", q) for q in ANDAR_HEROI]
    quadros = {}
    for linha, ang in enumerate(hz["DIRECOES"]):
        raiz.rotation_euler = (0, 0, math.radians(ang))
        p["linha"] = linha
        for col, (acao, q) in enumerate(acoes):
            hz["pose"](corpo, p, acao, q)
            quadros[(linha, col)] = render_tres(pal, False)
    folhas = montar_folha("hazaki", quadros, len(hz["DIRECOES"]), len(acoes), w, h)
    gravar("hazaki" + ("_samurai" if "samurai" in ARGS else ""), folhas, w, h,
           {"linhas": ["baixo", "esquerda", "direita", "cima", "baixo_esq", "baixo_dir", "cima_esq", "cima_dir"],
            "colunas": ["parado"] + ["andar%d" % q for q in ANDAR_HEROI]})


# ------------------------------------------------------------------ monstros

def gerar_monstro(modulo, nome):
    import monstros
    monstros.rodar = lambda *a, **k: None            # não gera nada ao importar o módulo da região
    mod = __import__(modulo)
    tabela = mod.INIMIGOS if hasattr(mod, "INIMIGOS") else mod.MONSTROS
    modelo, W, H, giro, ramps = tabela[nome]
    W, H = max(16, int(round(W * ESCALA_MONSTRO))), max(16, int(round(H * ESCALA_MONSTRO)))
    N = QUADROS_MONSTRO
    fases = [2.0 * math.pi * k / N for k in range(N)]
    px3.limpar_cena()
    VARIANTES.clear()
    px3.preparar_render(W, H)
    cam = px3.camera(elevacao_graus=ELEVACAO, escala=max(W, H) / PPU)
    m = mod.mats()
    raiz, corpo, p, pose = modelo(m)
    engrossar_olhos()
    trocar_passe("albedo")
    cam.data.shift_x = 0.0
    cam.data.shift_y = 0.0
    cena = bpy.context.scene
    esc0 = cam.data.ortho_scale
    cena.render.resolution_x, cena.render.resolution_y = W * 2, H * 2
    cam.data.ortho_scale = esc0 * 2.0
    uniao = None
    vistas = (0.0, 45.0)
    for ang in vistas:
        raiz.rotation_euler = (0, 0, -math.radians(ang))
        for k, fase in enumerate(fases):
            pose(fase, k)
            cx = px3.caixa_alfa(px3.render_rgba())
            if cx is None:
                raise RuntimeError("o modelo não apareceu no render")
            uniao = list(cx) if uniao is None else [min(uniao[0], cx[0]), min(uniao[1], cx[1]), max(uniao[2], cx[2]), max(uniao[3], cx[3])]
    uw, uh = uniao[2] - uniao[0] + 1, uniao[3] - uniao[1] + 1
    Wn, Hn = max(W, int(math.ceil(uw)) + 2), max(H, int(math.ceil(uh)) + 3)
    cx_n = (uniao[0] + uniao[2]) / 2.0 - W + Wn / 2.0
    by_n = uniao[3] - H + Hn / 2.0
    W, H = Wn, Hn
    cena.render.resolution_x, cena.render.resolution_y = W, H
    maior = max(W, H)
    cam.data.ortho_scale = maior / PPU
    cam.data.shift_x = (cx_n - (W - 1) / 2.0) / maior
    cam.data.shift_y = -(by_n - (H - 2)) / maior
    pal = mod.monstros.paleta(ramps) if hasattr(mod, "monstros") else monstros.paleta(ramps)
    quadros = {}
    for v, ang in enumerate(vistas):
        raiz.rotation_euler = (0, 0, -math.radians(ang))
        for q, fase in enumerate(fases):
            pose(fase, q)
            quadros[(v, q)] = render_tres(pal, True)     # o bicho olha pra esquerda no render: espelha pra olhar pra direita
    folhas = montar_folha(nome, quadros, len(vistas), N, W, H)
    gravar("inimigo_" + nome, folhas, W, H, {"linhas": ["frente", "tres_quartos"], "colunas": ["andar%d" % k for k in range(N)],
                                           "pe_y": H - 2})


px3.material_toon = material_toon_novo     # patch só em memória, ANTES de importar monstros/hazaki (monstros faz T = px3.material_toon)
px3.material_emissao = material_emissao_novo

if MODO == "heroi":
    gerar_heroi()
elif MODO == "monstro":
    gerar_monstro(ARGS[0], ARGS[1])
else:
    raise SystemExit("modo desconhecido: " + MODO)

# Trecho injetado pelo gerar.py do lobo no framework do Luke (no lugar do laco final das animacoes), por troca de texto.
# RETRATO 64x64 (padrao do elenco #586): copia adaptada do retrato() do ../hazaki/gerar.py. Busto em 3/4 voltado para a direita, do PROPRIO rig,
# mesma camera e mesmo enquadramento dos outros herois (crânio com cranio_px de altura, topo do desenho a topo_px da borda, ombros cortados).
RETRATO_PADRAO = {"tam": 64, "ang": 45.0, "elev": 18.0, "cranio_px": 33.0, "topo_px": 4, "centro_x": 0.5,
                  "anim": "parado", "quadro": 0, "cranio": "Cabeça facetada", "pasta": "lightwolf"}


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
    cran = [o for o in CORPO if o.name.startswith(r["cranio"])]

    def caixa(objs):
        bpy.context.view_layer.update()
        p = [world_to_camera_view(cena, cam, o.matrix_world @ v.co) for o in objs if o.type == "MESH" for v in o.data.vertices]
        xs_, ys_ = [q.x * T for q in p], [(1.0 - q.y) * T for q in p]
        return min(xs_), max(xs_), min(ys_), max(ys_)

    _, _, c0, c1 = caixa(cran)
    cam_data.ortho_scale *= (c1 - c0) / float(r["cranio_px"])      # crânio com cranio_px de altura
    x0, x1, y0, _ = caixa(cabeca)
    cam_data.shift_y += (r["topo_px"] - y0) / T                     # topo do desenho da cabeça (orelhas) a topo_px da borda de cima
    cam_data.shift_x -= (T * r["centro_x"] - 0.5 * (x0 + x1)) / T   # cabeça centrada
    ppu_r = T / cam_data.ortho_scale
    k = PPU / ppu_r                                                  # casca do contorno com ~1 px também no retrato
    for c, (b0, d0) in DELTA_CASCA.items():
        c.data.vertices.foreach_set("co", b0 + d0 * k)
        c.data.update()
    caminho = TMP / "retrato.png"
    renderizar(caminho)
    px = ler(caminho, True)
    mascara = px[:, :, 3] > 0.5
    px[..., 3] = np.where(mascara, 1.0, 0.0)                         # alfa binário, como a folha
    px[~mascara] = 0.0
    est = dict(ESTILO_2D)
    est["abre_baixo"] = True                                         # o corte dos ombros na borda de baixo não ganha contorno
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
if SO_RETRATO or not (SO_ANIM or SEM_RETRATO):      # com --anim=<nome> só aquela animação (sem retrato), como no hazaki
    retrato()

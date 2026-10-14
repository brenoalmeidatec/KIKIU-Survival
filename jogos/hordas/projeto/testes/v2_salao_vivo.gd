extends Control
# Salão vivo (v2/salao_vivo.gd): limites por perfil, pausa, nenhum nó novo por quadro, níveis das estações (só leitura), herói vivo.
# Saves com prefixo único; hashes dos saves reais conferidos no fim. Com --prints=<pasta> (e janela de verdade) grava um print por perfil.
# godot --headless --path jogos/hordas/projeto res://testes/v2_salao_vivo.tscn
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
const Vivo = preload("res://v2/salao_vivo.gd")
var falhas := 0
var pasta := ""
var so := ""  # --so=alto: só esse perfil (para medir print)
var reais := {}
var prefixo := ""


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prints="):
			pasta = arg.trim_prefix("--prints=")
		if arg.begins_with("--so="):
			so = arg.trim_prefix("--so=")
	prefixo = "qa_vivo_%d_" % Time.get_ticks_usec()
	var d := DirAccess.open("user://")
	for arquivo in d.get_files():
		if arquivo.begins_with("v2_"):
			reais[arquivo] = FileAccess.get_md5("user://" + arquivo)
	Personagens.caminho_indice = "user://" + prefixo + "indice.cfg"
	Personagens.caminho_base = "user://" + prefixo + "p"
	Personagens.caminho_antigo = "user://" + prefixo + "antigo.cfg"
	Meta.caminho_save = "user://" + prefixo + "meta.cfg"
	ok(Personagens.ativar(Personagens.criar("Matheus")), "slot isolado ativo")
	DisplayServer.window_set_size(Vector2i(960, 540))
	for perfil in ["baixo", "medio", "alto"]:
		if so == "" or so == perfil:
			await perfil_testar(perfil)
	if so == "":
		await niveis_e_heroi()
	for arquivo in reais:
		ok(FileAccess.get_md5("user://" + arquivo) == reais[arquivo], "save real intacto " + arquivo)
	for arquivo in d.get_files():
		if arquivo.begins_with(prefixo):
			d.remove(arquivo)
	print("v2_salao_vivo falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)


func abrir() -> Control:
	var s: Control = load("res://v2/salao.tscn").instantiate()
	add_child(s)
	s.ao_entrar = func(_cena): pass
	await get_tree().process_frame
	await get_tree().process_frame
	return s


func vivo_de(s: Control) -> Node:
	for n in s.get_children():
		if n.get_script() == Vivo:
			return n
	return null


func achar(raiz: Node, tipo: String, saida: Array) -> void:
	for n in raiz.get_children():
		if n.is_class(tipo):
			saida.append(n)
		achar(n, tipo, saida)


func perfil_testar(perfil: String) -> void:
	Config.g_perfil_temporario(perfil)
	var limite: int = {"baixo": 2, "medio": 6, "alto": 10}[perfil]
	var s := await abrir()
	var v := vivo_de(s)
	ok(v != null, "vivo montado: " + perfil)
	if v == null:
		return
	for i in 20:
		await get_tree().process_frame
	var luzes := []
	achar(s, "PointLight2D", luzes)
	var ligadas := luzes.filter(func(l): return l.enabled).size()
	ok(ligadas > 0 and ligadas <= limite, "%s: %d luzes ligadas (limite %d)" % [perfil, ligadas, limite])
	ok(luzes.size() <= limite + 1, "%s: luzes criadas dentro do orçamento (%d)" % [perfil, luzes.size()])
	var mods := []
	achar(s, "CanvasModulate", mods)
	ok((mods.size() == 0) == (perfil == "baixo"), perfil + ": CanvasModulate só em Médio e Alto")
	for m in mods:
		ok(m.color.get_luminance() > 0.3, "modulador nunca preto")
	var parts := []
	achar(s, "CPUParticles2D", parts)
	var soma := 0
	for p in parts:
		soma += p.amount
		ok(p.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "partícula nearest")
	var teto: int = {"baixo": 20, "medio": 45, "alto": 80}[perfil]
	ok(soma > 0 and soma <= teto, "%s: %d partículas (teto %d)" % [perfil, soma, teto])
	ok((v._nevoa != null) == (perfil != "baixo"), perfil + ": névoa só em Médio e Alto")
	if DisplayServer.get_name() != "headless":
		ok((v._sombras != null) == (perfil != "baixo"), perfil + ": sombra do herói pelas luzes em Médio e Alto")
	# nenhum nó criado por quadro
	var antes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 60:
		v._process(0.02)
		await get_tree().process_frame
	ok(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == antes, perfil + ": nenhum nó criado por quadro")
	# pausa: com o painel aberto o tempo e as partículas param
	var t0: float = v._tempo
	s._painel.visible = true
	for i in 5:
		v._process(0.02)
		await get_tree().process_frame
	ok(is_equal_approx(v._tempo, t0), perfil + ": efeitos param com o painel aberto")
	ok(v._glow.process_mode == Node.PROCESS_MODE_DISABLED, perfil + ": partículas congeladas")
	s._painel.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	ok(v._glow.process_mode != Node.PROCESS_MODE_DISABLED and v._tempo > t0, perfil + ": volta a andar")
	# ciclo de luz: +-6%
	if perfil != "baixo":
		var m: CanvasModulate = mods[0]
		ok(absf(m.color.r / Vivo.MODULADO.r - 1.0) <= 0.0601, "ciclo de luz dentro de 6%")
	if not pasta.is_empty() and DisplayServer.get_name() != "headless":
		s._pos = Vector2(480, 400)
		for i in 90:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta.path_join("vivo_" + perfil + ".png"))
	s.queue_free()
	await get_tree().process_frame


func niveis_e_heroi() -> void:
	Config.g_perfil_temporario("alto")
	var s := await abrir()
	var v := vivo_de(s)
	var vis := func(): return v._estacao("estatuas").runas.filter(func(r): return r.visible).size()
	ok(vis.call() == 0, "sem compras, nenhuma runa acesa")
	Meta.creditar(500)
	var antes := Meta.nivel("vida")
	ok(s.comprar_item("vida") and s.comprar_item("dano"), "compras no save isolado")
	s._painel.visible = true
	await get_tree().process_frame
	s._painel.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	ok(vis.call() >= 1, "runas acendem depois de comprar (%d)" % vis.call())
	ok(Meta.nivel("vida") == antes + 1, "o salão vivo só lê o save")
	# herói: respiração em pixel inteiro, olhar para o alvo
	s._pos = Vector2(180, 240)
	s._destino = Vector2.INF
	for i in 10:
		s._process(0.016)
		v._process(0.3)
		await get_tree().process_frame
	ok(s._heroi.position.y == roundf(s._heroi.position.y) and s._heroi.position.x == roundf(s._heroi.position.x), "herói em pixel inteiro")
	ok(s._dir == 3, "olha para o portal do prompt (cima): %d" % s._dir)
	var ys := {}
	for i in 80:
		v._process(0.05)
		ys[s._heroi.position.y] = true
	ok(ys.size() == 2, "respiração de 1 px (%d posições)" % ys.size())
	# o portal intensifica de perto
	var alvo: Dictionary = s._alvos.filter(func(a): return a.id == "floresta")[0]
	s._pos = alvo.pos + Vector2(0, 30)
	for i in 30:
		v._process(0.05)
	var p = v._portais[0]
	ok(p.reacao > 0.9, "portal intensifica com o herói perto (%.2f)" % p.reacao)
	s._pos = Vector2(480, 480)
	for i in 30:
		v._process(0.05)
	ok(p.reacao < 0.1, "portal acalma longe (%.2f)" % p.reacao)
	s.queue_free()
	await get_tree().process_frame

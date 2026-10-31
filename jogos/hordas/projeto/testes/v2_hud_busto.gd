extends "res://testes/isolamento_v2.gd"
# Teste do busto do chefe na barra (v2/hud.gd BUSTOS, nó Raiz/Chefe/Busto em v2/hud.tscn, arte em assets/v2/chefes/ gerada por
# `gerar_objetos.py chefes`). Confere que cada marca de dados/v2_cartas.json tem o seu busto e que nenhum busto sobra; que cada PNG é 36 x 36, RGBA,
# com alfa só 0 ou 255, borda transparente e miolo visível; que o HUD põe o busto pelo id da marca em campo (combate.chefes.marca) e esconde o busto para
# chefe sem busto ou sem marca; e que o busto fica dentro da moldura do chefe, com o nome e a barra depois dele.
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_hud_busto.tscn  (imprime "v2_hud_busto falhas=0")
const Hud := preload("res://v2/hud.gd")
const TAM := 36
const CAMINHO_CARTAS := "res://dados/v2_cartas.json"
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const PASSO := 1.0 / 60.0

var falhas := 0


class Chefes:
	extends RefCounted
	var marca: Dictionary = {}


class Combate:
	extends RefCounted
	var chefes := Chefes.new()


## O mundo mínimo que o HUD liga: o sinal do chefe e o combate com a marca em campo (como chefe.gd deixa antes do sinal).
class MundoBusto:
	extends Node
	signal chefe_apareceu(nome: String, vida_max: float)
	var combate := Combate.new()


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var pasta := ""
	var janela := Vector2i.ZERO
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--janela="):
			var wh := a.trim_prefix("--janela=").split("x")
			janela = Vector2i(int(wh[0]), int(wh[1]))
	if pasta != "":
		await _fotos(pasta, janela)
		get_tree().quit()
		return
	_arte()
	_marcas()
	_hud()
	print("v2_hud_busto falhas=%d" % falhas)
	get_tree().quit()


## Cada busto: 36 x 36, RGBA, alfa só 0 ou 255 (sem meia transparência), borda inteira transparente e miolo visível.
func _arte() -> void:
	for id in Hud.BUSTOS:
		var tex: Texture2D = Hud.BUSTOS[id]
		ok(tex.get_size() == Vector2(TAM, TAM), "busto %s tem %s (quer %dx%d)" % [id, str(tex.get_size()), TAM, TAM])
		var img := Image.load_from_file(tex.resource_path)
		ok(img != null, "busto %s carrega de %s" % [id, tex.resource_path])
		if img == null:
			continue
		var w := img.get_width()
		var h := img.get_height()
		var opacos := 0
		var meios := 0
		var na_borda := 0
		for y in h:
			for x in w:
				var a := img.get_pixel(x, y).a8
				if a == 255:
					opacos += 1
				elif a != 0:
					meios += 1
				if (x == 0 or y == 0 or x == w - 1 or y == h - 1) and a != 0:
					na_borda += 1
		ok(meios == 0, "busto %s sem alfa intermediária (%d pixels)" % [id, meios])
		ok(na_borda == 0, "busto %s com a borda transparente (%d pixels visíveis na borda)" % [id, na_borda])
		ok(opacos > 300, "busto %s com miolo visível (%d pixels opacos)" % [id, opacos])


## Os ids de dados/v2_cartas.json (marcas dos chefes) são exatamente as chaves de BUSTOS: nenhum chefe sem busto, nenhum busto sem chefe.
## E o arquivo de cada busto é o do nome do chefe ("Devourer of Structure" -> devourer_of_structure.png), para um busto trocado de chefe não passar.
func _marcas() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_CARTAS))
	var marcas := _achar_marcas(dados)
	ok(not marcas.is_empty(), "dados/v2_cartas.json tem a lista de marcas dos chefes")
	var ids := []
	for mk in marcas:
		var id := str(mk.get("id", ""))
		var nome := str(mk.get("nome", ""))
		ids.append(id)
		ok(Hud.BUSTOS.has(id), "marca %s sem busto em v2/hud.gd (BUSTOS)" % id)
		if Hud.BUSTOS.has(id):
			var arquivo: String = Hud.BUSTOS[id].resource_path.get_file().get_basename()
			ok(arquivo == _slug(nome), "busto de %s (%s) é o de %s, não %s.png" % [id, nome, _slug(nome), arquivo])
	for id in Hud.BUSTOS:
		ok(ids.has(id), "busto %s sem marca em dados/v2_cartas.json" % id)


## "Devourer of Structure" -> "devourer_of_structure": minúsculas, espaço vira _, sem acento (o nome do arquivo do busto).
func _slug(nome: String) -> String:
	var s := nome.to_lower().replace(" ", "_")
	for par in [["á", "a"], ["â", "a"], ["ã", "a"], ["é", "e"], ["ê", "e"], ["í", "i"], ["ó", "o"], ["ô", "o"], ["ú", "u"], ["ç", "c"]]:
		s = s.replace(par[0], par[1])
	return s


func _achar_marcas(d) -> Array:
	if d is Dictionary:
		if d.has("marcas"):
			return d["marcas"]
		for k in d:
			var achado := _achar_marcas(d[k])
			if not achado.is_empty():
				return achado
	return []


## O HUD põe o busto da marca em campo e o tira quando não há busto para ela; o busto fica dentro da moldura do chefe, com o nome e a barra depois dele.
func _hud() -> void:
	var m := MundoBusto.new()
	var hud = Hud.criar(m)
	add_child(hud)
	hud.set_process(false)
	var moldura: NinePatchRect = hud.get_node("Raiz/Chefe")
	var busto: TextureRect = hud.get_node("Raiz/Chefe/Busto")
	for id in Hud.BUSTOS:
		m.combate.chefes.marca = {"id": id}
		m.chefe_apareceu.emit("Qualquer nome", 100.0)
		ok(busto.texture == Hud.BUSTOS[id] and busto.visible, "chefe %s mostra o seu busto na barra" % id)
	m.combate.chefes.marca = {"id": "sem_busto"}
	m.chefe_apareceu.emit("Chefe novo", 100.0)
	ok(busto.texture == null and not busto.visible, "chefe sem busto deixa a barra sem o retrato")
	m.combate.chefes.marca = {}
	m.chefe_apareceu.emit("Guardião do bosque", 1000.0)
	ok(busto.texture == null and not busto.visible, "sinal sem marca (mundo falso) não põe busto")
	ok(busto.offset_right - busto.offset_left == TAM and busto.offset_bottom - busto.offset_top == TAM, "busto no HUD com %dx%d" % [TAM, TAM])
	var fundo_w: float = moldura.offset_right - moldura.offset_left
	var fundo_h: float = moldura.offset_bottom - moldura.offset_top
	ok(
		busto.offset_left >= 0 and busto.offset_top >= 0 and busto.offset_right <= fundo_w and busto.offset_bottom <= fundo_h,
		"busto dentro da moldura do chefe"
	)
	for nome in ["Nome", "Fantasma", "Barra", "Texto"]:
		var no: Control = hud.get_node("Raiz/Chefe/" + nome)
		ok(no.offset_left >= busto.offset_right, "%s começa depois do busto (x %s, o busto acaba em %s)" % [nome, str(no.offset_left), str(busto.offset_right)])
	hud.queue_free()


## Fotos da partida real com cada chefe em campo (nascer pelo caminho do jogo): a barra com o busto e o anúncio, no tamanho de janela pedido.
func _fotos(pasta: String, janela: Vector2i) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	if janela != Vector2i.ZERO:
		get_window().size = janela
	Herois.forcado = "hazaki"
	for i in 3:
		var w = Mundo.instantiate()
		w.modo_teste = true
		add_child(w)
		w.set_process(false)
		w.heroi.entrada_forcada = Vector2.ZERO
		for k in 60:
			w.avancar(PASSO)
		var mk: Dictionary = w.combate.chefes.cfg.marcas[i]
		w.combate.chefes.nascer(mk, w.heroi.pos + Vector2(220, 0))
		for k in 30:
			w.avancar(PASSO)
		await get_tree().create_timer(1.5).timeout  # o HUD entra e atualiza a barra (nome, vida e busto) em alguns quadros
		var nome := "chefe_%s_%dx%d" % [mk.id, get_window().size.x, get_window().size.y]
		var tam = await w.ap.foto(pasta.path_join(nome + ".png"))
		print("FOTO %s %s janela %s" % [nome, tam, get_window().size])
		w.queue_free()
		await get_tree().process_frame
	Herois.forcado = ""

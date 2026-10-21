extends Node
## Quadros de UM herói do Blender em jogo (parado, andar, combo, E, Q, rolamento, escudo, dano, morte), para os GIFs dos PRs de herói
## (não roda no CI: fica em testes/fotos/). Monta uma partida sem diretor, com o herói escolhido e monstros parados na frente, e grava um PNG do
## viewport do mundo a cada 2 passos de 1/60 s (30 quadros por segundo de jogo), recortado em volta do herói. O ferramentas/gifs_golpes.py junta
## os PNG num GIF ampliado 4x sem suavizar.
## Uso: godot --path jogos/hordas/projeto res://testes/fotos/heroi_gif.tscn -- --fotos=PASTA [--heroi=lucas] [--cena=nome]
## Cenas: parado, andar, combo, habilidade (a E), especial (o Q), rolamento, escudo, dano, morte. Com `--andar_todas` o andar sai nas 8 direções.

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const CENAS := ["hud", "parado", "andar", "combo", "habilidade", "especial", "rolamento", "escudo", "dano", "morte"]
const LARGOS := ["habilidade", "especial", "rolamento"]

var w


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("FOTOS: precisa de janela (rode sem --headless)")
		get_tree().quit()
		return
	var pasta := ""
	var so := ""
	var id := "lucas"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--cena="):
			so = a.trim_prefix("--cena=")
		elif a.begins_with("--heroi="):
			id = a.trim_prefix("--heroi=")
	if pasta == "":
		print("FOTOS: passe --fotos=PASTA")
		get_tree().quit()
		return
	Config.arquivo = "user://qa_hgif_opcoes.cfg"
	Config.temporario("pausar_fora", false)
	Config.temporario("qualidade_auto", false)
	Config.g_perfil_temporario("alto")
	Meta.caminho_save = "user://qa_hgif_meta.cfg"
	Personagens.caminho_indice = "user://qa_hgif_indice.cfg"
	Personagens.caminho_base = "user://qa_hgif_p"
	Personagens.caminho_antigo = "user://qa_hgif_antigo.cfg"
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = false
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	await _quadros(3)
	for c in CENAS:
		if so != "" and c != so:
			continue
		await _cena(c, pasta)
	w.queue_free()
	await _quadros(3)
	get_tree().quit()


func _zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.escudo_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.heroi.m_critico = -1.0
	passos(90)  # a chegada do herói (o clarão de nascer) acaba antes da cena
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	passos(3)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Monstros parados (atordoados, imortais na prática) em fila à direita do herói.
func _monstros(n: int) -> void:
	for i in n:
		var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(70.0 + 22.0 * i, (i % 3 - 1) * 16.0))
		m.vida_max = 100000.0
		m.vida = 100000.0
		m.atordoa_t = 9999.0
		m.cacador = false
		m.raio_vaga = 0.0


func _cena(nome: String, pasta: String) -> void:
	_zerar()
	var h = w.heroi
	var n := 36
	match nome:
		"hud":
			pass
		"parado":
			n = 30  # 1 s
		"andar":
			h.entrada_forcada = Vector2(1, 0)
			n = 30
		"combo":
			_monstros(3)
			h.ataque_forcado = true
			n = 56
		"habilidade":
			_monstros(4)
			h.hab_recarga = 0.0
			h.habilidade()
			n = 40
		"especial":
			_monstros(4)
			h.esp_carga = h.esp_carga_max
			h.especial()
			n = 62
		"rolamento":
			h.entrada_forcada = Vector2(1, 0)
			h.esquivar()
			n = 24
		"escudo":
			h.escudo_forcado = true
			n = 24
		"dano":
			h.imortal = false
			h.vida = h.vida_max
			passos(2)
			h.levar_dano(1.0, h.pos + Vector2(30, 0))
			n = 20
		"morte":
			h.imortal = false
			passos(2)
			h.levar_dano(h.vida_max * 3.0, h.pos + Vector2(30, 0))
			n = 70
	var dir := pasta.path_join(nome)
	DirAccess.make_dir_recursive_absolute(dir)
	if nome == "hud":  # a janela inteira (HUD com o retrato do herói), uma foto só
		passos(30)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(pasta.path_join("hud.png"))
		return
	var recorte := Vector2i(300, 190) if nome in LARGOS else Vector2i(180, 140)
	for i in n:
		passos(2)
		await RenderingServer.frame_post_draw
		var img: Image = w.sv.get_texture().get_image()
		var tam := img.get_size()
		var pe: Vector2 = h.sprite.get_global_transform_with_canvas().origin  # a câmera atrasa no salto e no rolamento: o recorte segue o herói
		var centro := Vector2i(int(pe.x) + (40 if nome in LARGOS else 20), int(pe.y) - 12)
		centro = centro.clamp(recorte / 2, tam - recorte / 2)
		var r := Rect2i(centro - recorte / 2, recorte).intersection(Rect2i(Vector2i.ZERO, tam))
		img.get_region(r).save_png(dir.path_join("q%03d.png" % i))
	h.ataque_forcado = null
	h.entrada_forcada = Vector2.ZERO
	print("CENA %s %d quadros em %s" % [nome, n, dir])

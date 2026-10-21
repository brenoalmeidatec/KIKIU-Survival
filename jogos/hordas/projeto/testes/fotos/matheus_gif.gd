extends Node
## Quadros do Matheus em jogo (andar, combo, E, Q, rolamento, escudo, dano, morte) para os GIFs de docs/visual_2_5d/ (não roda no CI).
## Monta uma partida real sem diretor, com o personagem ATIVO escolhido (--ativo=matheus usa a folha do Matheus; --ativo=breno, a do Hazaki: o "antes"),
## e grava um PNG do viewport do mundo a cada 2 passos de 1/60 s, recortado em volta do herói. ferramentas/gifs_golpes.py junta os PNG em GIFs.
## Uso: godot --path jogos/hordas/projeto res://testes/fotos/matheus_gif.tscn -- --fotos=PASTA --ativo=matheus [--cena=nome] [--colisao]
## Cenas: parado, andar, andar_diag, combo, e, q, rolamento, escudo, dano, morte, pe (foto cheia com o círculo de colisão), hud (a tela inteira com o retrato do HUD).

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const PASSO := 1.0 / 60.0
const RECORTE := Vector2i(220, 160)
const CENAS := ["parado", "andar", "andar_diag", "combo", "e", "q", "rolamento", "escudo", "dano", "morte", "pe", "hud"]

var w
var pasta := "user://matheus_gif"
var so := ""
var ativo := "matheus"
var colisao := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--cena="):
			so = a.trim_prefix("--cena=")
		elif a.begins_with("--ativo="):
			ativo = a.trim_prefix("--ativo=")
		elif a == "--colisao":
			colisao = true
	Meta.caminho_save = "user://mgif.cfg"
	Personagens.caminho_indice = "user://mgif_indice.cfg"
	Personagens.caminho_base = "user://mgif_p"
	Personagens.caminho_antigo = "user://mgif_antigo.cfg"
	var nome := "Matheus" if ativo == "matheus" else "Breno"
	var id := Personagens.criar(nome, Personagens.heroi_do_nome(nome))
	Personagens.ativar(id)
	Herois.forcado = ""
	w = Mundo.instantiate()
	w.modo_teste = false
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	Config.g_aplicar_perfil("alto")
	await _quadros(3)
	print("FOLHA ", Herois.sprite_da_partida(w.combate.heroi_id))
	for c in CENAS:
		if so != "" and c != so:
			continue
		await _cena(c)
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("mgif"):
			DirAccess.remove_absolute("user://" + f)
	get_tree().quit()


func _zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	seed(7)
	var h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = null
	h.ruptura_forcada = null
	h.escudo_forcado = null
	h.fonte = Heroi.Fonte.MOUSE
	h.m_critico = -1.0
	passos(90)
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _monstros(n: int) -> void:
	for i in n:
		var off := Vector2(34.0 + 16.0 * i, (i % 3 - 1) * 14.0)
		var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + off)
		m.vida_max = 100000.0
		m.vida = 100000.0
		m.atordoa_t = 9999.0
		m.cacador = false
		m.raio_vaga = 0.0


func _cena(nome: String) -> void:
	_zerar()
	var h = w.heroi
	var n := 36
	var cada := 2
	match nome:
		"parado":
			n = 24
			cada = 6
		"andar":
			h.entrada_forcada = Vector2(1, 0)
			n = 30
		"andar_diag":
			h.entrada_forcada = Vector2(1, 1).normalized()
			n = 30
		"combo":
			_monstros(3)
			h.ataque_forcado = true
			n = 50
		"e":  # a E do Hazaki é a ruptura: segura (carga) e solta (corte)
			_monstros(3)
			h.ruptura_forcada = true
			for k in 6:  # o pedido pode ser comido por um quadro de chegada: repete até a carga começar
				if h.estado == Heroi.Estado.CARGA:
					break
				h.ruptura()
				passos(2)
			n = 60
		"q":
			_monstros(4)
			h.esp_carga = h.esp_carga_max
			print("Q disparou: ", h.especial())
			n = 40
		"rolamento":
			h.entrada_forcada = Vector2(1, 0)
			passos(10)
			h.esquivar()
			n = 24
		"escudo":
			_monstros(1)
			h.escudo_forcado = true
			n = 30
		"dano":
			h.imortal = false
			h.invenc = 0.0
			h.vida = h.vida_max
			h.levar_dano(5.0, h.pos + Vector2(30, 0), null, false)
			n = 20
		"morte":
			h.imortal = false
			h.invenc = 0.0
			h.levar_dano(100000.0, h.pos + Vector2(30, 0))
			n = 80
		"hud":
			_monstros(3)
			h.ataque_forcado = true
			passos(14)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var dir1 := pasta.path_join(nome)
			DirAccess.make_dir_recursive_absolute(dir1)
			get_viewport().get_texture().get_image().save_png(dir1.path_join("q000.png"))
			h.ataque_forcado = null
			return
		"pe":
			w.dbg_colisao.visible = true
			_monstros(3)
			passos(2)
			await RenderingServer.frame_post_draw
			var dir0 := pasta.path_join(nome)
			DirAccess.make_dir_recursive_absolute(dir0)
			w.sv.get_texture().get_image().save_png(dir0.path_join("q000.png"))
			w.dbg_colisao.visible = false
			return
	var dir := pasta.path_join(nome)
	DirAccess.make_dir_recursive_absolute(dir)
	for i in n:
		if nome == "e" and i == 30:
			h.ruptura_forcada = false
		passos(cada)
		await RenderingServer.frame_post_draw
		var img: Image = w.sv.get_texture().get_image()
		var tam := img.get_size()
		var centro := Vector2i(tam.x / 2 + 30, tam.y / 2 - 26)
		var r := Rect2i(centro - RECORTE / 2, RECORTE).intersection(Rect2i(Vector2i.ZERO, tam))
		img.get_region(r).save_png(dir.path_join("q%03d.png" % i))
	h.ataque_forcado = null
	print("CENA %s %d quadros em %s" % [nome, n, dir])

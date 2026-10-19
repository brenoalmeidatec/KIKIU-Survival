extends Node
## Quadros dos golpes em ação, para os GIFs de docs/combate_v2/gifs (não roda no CI: fica em testes/fotos/). Cada cena monta uma partida
## sem diretor, com o herói imortal e monstros parados na frente, liga um golpe e grava um PNG do viewport do mundo a cada 2 passos de 1/60 s
## (30 quadros por segundo de jogo), recortado em volta do herói. O ferramentas/gifs_golpes.py junta os PNG num GIF ampliado 4x sem suavizar.
## Uso: godot --path jogos/hordas/projeto res://testes/fotos/golpes_gif.tscn -- --fotos=PASTA [--cena=nome]
## Cenas: corte (katana, golpe leve), estocada (o 3º golpe do combo, pesado), combo, bola_fogo (projétil), adagas (projétil que gira),
## onda_choque (área), terremoto (área), meteoro (magia de fogo), lanca_geada (magia de gelo), nuvem_veneno (área que fica).

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const RECORTE := Vector2i(200, 120)
const CENAS := ["corte", "estocada", "combo", "bola_fogo", "adagas", "onda_choque", "terremoto", "meteoro", "lanca_geada", "nuvem_veneno"]

var w
var pasta := "user://golpes_gif"
var so := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--cena="):
			so = a.trim_prefix("--cena=")
	Herois.forcado = "hazaki"
	w = Mundo.instantiate()
	w.modo_teste = false
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	Config.g_aplicar_perfil("alto")
	await _quadros(3)
	for c in CENAS:
		if so != "" and c != so:
			continue
		await _cena(c)
	get_tree().quit()


func _zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
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


## Monstros parados (atordoados) que aguentam o golpe, em fila à direita do herói (ou em volta, com `roda`).
func _monstros(n: int, roda := false) -> void:
	for i in n:
		var off := Vector2(42.0 + 16.0 * i, (i % 3 - 1) * 14.0)
		if roda:
			var ang := TAU * i / n
			off = Vector2(cos(ang) * 58.0, sin(ang) * 36.0)
		var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + off)
		m.vida_max = 100000.0
		m.vida = 100000.0
		m.atordoa_t = 9999.0
		m.cacador = false
		m.raio_vaga = 0.0


func _golpe(id: String, quantidade := 1) -> Dictionary:
	w.combate.armas.definir_golpe(id, 3, 0.0)
	var a: Dictionary = w.combate.armas.ativas[id]
	if a.st.has("quantidade"):
		a.st.quantidade = quantidade
	a.st.recarga = 99.0
	a.t = 0.05
	return a


func _cena(nome: String) -> void:
	_zerar()
	var n := 36
	match nome:
		"corte":
			_monstros(3)
			w.heroi.ataque_forcado = true
			passos(1)
			w.heroi.ataque_forcado = false
			n = 16
		"estocada":
			_monstros(3)
			w.heroi.proximo = 2
			w.heroi.combo_t = 0.3
			w.heroi.ataque_forcado = true
			passos(1)
			w.heroi.ataque_forcado = false
			n = 22
		"combo":
			_monstros(3)
			w.heroi.ataque_forcado = true
			n = 50
		"bola_fogo":
			_monstros(2)
			_golpe("bola_fogo")
			n = 34
		"adagas":
			_monstros(2)
			_golpe("adagas_voadoras", 2)
			n = 30
		"onda_choque":
			_monstros(8, true)
			_golpe("onda_choque")
			n = 30
		"terremoto":
			_monstros(8, true)
			_golpe("terremoto")
			n = 34
		"meteoro":
			_monstros(3)
			_golpe("meteoro_flamejante")
			n = 80
		"lanca_geada":
			_monstros(2)
			_golpe("lanca_geada")
			n = 30
		"nuvem_veneno":
			_monstros(4)
			_golpe("nuvem_veneno")
			n = 60
	var dir := pasta.path_join(nome)
	DirAccess.make_dir_recursive_absolute(dir)
	for i in n:
		passos(2)
		await RenderingServer.frame_post_draw
		var img: Image = w.sv.get_texture().get_image()
		var tam := img.get_size()
		var centro := Vector2i(tam.x / 2 + 30, tam.y / 2 - 8)
		var r := Rect2i(centro - RECORTE / 2, RECORTE).intersection(Rect2i(Vector2i.ZERO, tam))
		img.get_region(r).save_png(dir.path_join("q%03d.png" % i))
	w.heroi.ataque_forcado = null
	print("CENA %s %d quadros em %s" % [nome, n, dir])

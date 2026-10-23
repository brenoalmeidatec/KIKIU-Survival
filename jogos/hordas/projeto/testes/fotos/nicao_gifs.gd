extends Node
## Quadros do Nicão (folha do Blender) em jogo, para os GIFs do PR (não roda no CI: fica em testes/fotos/). Monta uma partida sem diretor, com o
## herói imortal e monstros parados na frente, faz a ação e grava um PNG do viewport do mundo a cada 2 passos de 1/60 s (30 quadros por segundo de
## jogo), recortado em volta do herói. O ferramentas/gifs_golpes.py junta os PNG de cada subpasta num GIF ampliado sem suavizar.
## Uso: godot --path jogos/hordas/projeto res://testes/fotos/nicao_gifs.tscn -- --fotos=PASTA [--cena=nome] [--heroi=hazaki]
## Cenas: andar_direita, andar_baixo, andar_cima, combo, habilidade (E), especial (Q), rolamento, defesa.

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
const RECORTE := Vector2i(260, 190)
const CENAS := ["andar_direita", "andar_baixo", "andar_cima", "combo", "habilidade", "especial", "rolamento", "defesa"]

var w
var pasta := "user://nicao_gifs"
var so := ""
var heroi := "nicao"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--cena="):
			so = a.trim_prefix("--cena=")
		elif a.begins_with("--heroi="):
			heroi = a.trim_prefix("--heroi=")
	Config.temporario("pausar_fora", false)  # a janela fora da tela perde o foco: a pausa abriria sobre os quadros
	Herois.forcado = heroi
	w = Mundo.instantiate()
	w.modo_teste = false
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	await _quadros(3)
	for c in CENAS:
		if so == "" or c == so:
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


## Monstros parados (atordoados, sem morrer) na direção `d` do herói, em leque, ou em volta com `roda`.
func _monstros(n: int, d := Vector2.RIGHT, roda := false) -> void:
	for i in n:
		var off: Vector2 = d * (46.0 + 18.0 * (i % 4)) + d.orthogonal() * ((i % 3) - 1) * 20.0
		if roda:
			var ang := TAU * i / n
			off = Vector2(cos(ang) * 66.0, sin(ang) * 40.0)
		var m = w.nascer_monstro("inimigo_cavaleiro_oco", w.heroi.pos + off)
		m.vida_max = 100000.0
		m.vida = 100000.0
		m.atordoa_t = 9999.0
		m.cacador = false
		m.raio_vaga = 0.0


func _cena(nome: String) -> void:
	_zerar()
	var h = w.heroi
	var n := 40
	match nome:
		"andar_direita":
			w.mouse_forcado = h.centro() + Vector2(100, 0)
			h.entrada_forcada = Vector2(1, 0)
			n = 36
		"andar_baixo":
			w.mouse_forcado = h.centro() + Vector2(0, 100)
			h.entrada_forcada = Vector2(0, 1)
			n = 36
		"andar_cima":
			w.mouse_forcado = h.centro() + Vector2(0, -100)
			h.entrada_forcada = Vector2(0, -1)
			n = 36
		"combo":
			_monstros(6)
			h.entrada_forcada = Vector2.ZERO
			h.ataque_forcado = true
			n = 60
		"habilidade":
			w.mouse_forcado = h.centro() + Vector2(0, 100)  # para baixo: o chão do círculo de pedra está livre, sem ruína na frente
			_monstros(8, Vector2.DOWN)
			passos(2)
			h.habilidade()
			n = 34
		"especial":
			_monstros(10, Vector2.RIGHT, true)
			passos(2)
			h.esp_carga = h.esp_carga_max
			h.especial()
			n = 56
		"rolamento":
			h.entrada_forcada = Vector2(1, 0)
			passos(2)
			h.esquivar()
			n = 22
		"defesa":
			_monstros(3)
			passos(2)
			h.escudo_forcado = true
			n = 28
	var colunas := []
	var dir := pasta.path_join(nome)
	DirAccess.make_dir_recursive_absolute(dir)
	for i in n:
		passos(2)
		colunas.append(h.coluna)
		await RenderingServer.frame_post_draw
		var img: Image = w.sv.get_texture().get_image()
		var tam := img.get_size()
		var pe: Vector2 = h.sprite.get_global_transform_with_canvas().origin  # o recorte segue o herói (a câmera atrasa na investida)
		var centro := Vector2i(int(pe.x), int(pe.y) - 20)
		var r := Rect2i(centro - RECORTE / 2, RECORTE).intersection(Rect2i(Vector2i.ZERO, tam))
		img.get_region(r).save_png(dir.path_join("q%03d.png" % i))
	h.ataque_forcado = null
	h.escudo_forcado = null
	h.entrada_forcada = Vector2.ZERO
	print("CENA %s %d quadros em %s (modulate final %s, colunas %s)" % [nome, n, dir, h.sprite.modulate, colunas])

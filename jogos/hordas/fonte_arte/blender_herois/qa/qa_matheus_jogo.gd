extends Node
# QA visual do Matheus no jogo (nao e teste de CI): prints reais do salao (parado e andando) e da partida (no meio do golpe e morto), com o
# personagem Matheus ativo (folha propria, dados/v2_salao.json "sprite"), e a partida do Breno (folha do Hazaki) para comparar.
# Uso (janela oculta, fora do repo): copie este .gd e o .tscn para jogos/hordas/projeto/testes/ de uma copia e rode
#   godot --path jogos/hordas/projeto res://testes/qa_matheus_jogo.tscn -- --saida=PASTA
const Mundo := preload("res://v2/mundo.tscn")
const Salao := preload("res://v2/salao.tscn")
const Personagens := preload("res://v2/personagens.gd")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const Meta := preload("res://v2/meta.gd")
const PASSO := 1.0 / 60.0

var pasta := ""
var w


func _ready() -> void:
	Meta.caminho_save = "user://qa_matheus.cfg"
	Personagens.caminho_indice = "user://qa_matheus_indice.cfg"
	Personagens.caminho_base = "user://qa_matheus_p"
	Personagens.caminho_antigo = "user://qa_matheus_antigo.cfg"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			pasta = a.trim_prefix("--saida=")
	DirAccess.make_dir_recursive_absolute(pasta)
	var id_m := Personagens.criar("Matheus", Personagens.heroi_do_nome("Matheus"))
	var id_b := Personagens.criar("Breno", Personagens.heroi_do_nome("Breno"))
	Personagens.ativar(id_m)
	await _salao()
	await _partida("matheus")
	Personagens.ativar(id_b)
	await _partida("breno")
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("qa_matheus"):
			DirAccess.remove_absolute("user://" + f)
	get_tree().quit()


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join(nome + ".png"))
	print("FOTO ", nome)


func _salao() -> void:
	var s = Salao.instantiate()
	add_child(s)
	await _quadros(20)
	await _foto("salao_parado")
	s._destino = Vector2(s._pos.x + 150.0, s._pos.y + 20.0)
	await _quadros(6)
	await _foto("salao_andando_a")
	await _quadros(5)
	await _foto("salao_andando_b")
	s.queue_free()
	await _quadros(5)


func _passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _ate(cond: Callable, max_passos: int) -> void:
	for i in max_passos:
		if cond.call():
			return
		w.avancar(PASSO)


func _partida(quem: String) -> void:
	Herois.forcado = ""
	w = Mundo.instantiate()
	w.modo_teste = false
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	await _quadros(3)
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.fonte = Heroi.Fonte.MOUSE
	h.m_critico = -1.0
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	_passos(3)
	for a in 8:
		var ang := TAU * a / 8.0
		var m = w.nascer_monstro("inimigo_espantalho", h.pos + Vector2(cos(ang) * 46.0, sin(ang) * 36.0))
		m.atordoa_t = 0.0
	_passos(2)
	await _foto("partida_%s_parado" % quem)
	h.atacar()
	_ate(func(): return h.estado == Heroi.Estado.GOLPE, 20)
	_passos(6)
	await _foto("partida_%s_golpe" % quem)
	_ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	h.imortal = false
	h.invenc = 0.0
	h.levar_dano(100000.0, h.pos + Vector2(30, 0))
	_ate(func(): return h.coluna == 49, 1200)
	await _foto("partida_%s_morto" % quem)
	w.queue_free()
	await _quadros(3)

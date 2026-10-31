extends Node
## Traço reproduzível do combo real, separado do deslocamento puramente visual.
const Mundo = preload("res://v2/mundo.tscn")
const Heroi = preload("res://v2/heroi.gd")
const Herois = preload("res://v2/herois.gd")
const Personagens = preload("res://v2/personagens.gd")
const Meta = preload("res://v2/meta.gd")
const Ambiente = preload("res://testes/ambiente_v2.gd")
var saida := ""


func _init() -> void:
	Ambiente.iniciar(get_script().resource_path)


func _exit_tree() -> void:
	Ambiente.finalizar()


func _ready() -> void:
	print("ISOLAMENTO_USERDIR ", OS.get_user_data_dir())
	saida = Ambiente.arquivo("contrato_golpes.json")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
	Config.temporario("pausar_fora", false)
	Config.temporario("qualidade_auto", false)
	var casos := []
	for nome in ["Brendan", "Matthew", "Nick", "Luke"]:
		for hz in [60, 120]:
			var id = Personagens.criar(nome, Personagens.heroi_do_nome(nome))
			Personagens.ativar(id)
			Herois.forcado = ""
			var w = Mundo.instantiate()
			w.modo_teste = true
			add_child(w)
			w.set_process(false)
			w.combate.audio.mudo = true
			w.reiniciar()
			w.combate.limpar_partida()
			w.combate.diretor.ligado = false
			var h = w.heroi
			h.imortal = true
			h.entrada_forcada = Vector2.ZERO
			h.ataque_forcado = false
			h.fonte = Heroi.Fonte.MOUSE
			h.m_critico = -1.0
			var dt := 1.0 / float(hz)
			for i in 2 * hz:
				w.avancar(dt)
			w.mouse_forcado = h.centro() + Vector2(100, 0)
			var m = w.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(34, 0))
			m.vida_max = 1000000.0
			m.vida = m.vida_max
			m.peso = 1000000.0
			m.atordoa_t = 9999.0
			m.raio_vaga = 0.0
			seed(7)
			h.ataque_forcado = true
			var mecanica := []
			var visual := []
			for i in 3 * hz:
				if h.golpes >= 3:
					h.ataque_forcado = false
				w.avancar(dt)
				mecanica.append(
					[
						i,
						h.pos.x,
						h.pos.y,
						h.estado,
						h.golpe_i,
						h.golpe_t,
						h.golpe_dur,
						h.golpe_acertou,
						h.golpes,
						h.folego,
						m.vida,
						m.pos.x,
						m.pos.y,
						w.combate.acertos,
						w.combate.parada_t,
						w.combate.adagas.acertos,
						w.combate.adagas.ativas()
					]
				)
				visual.append([h.sprite.position.x, h.sprite.position.y, h.sprite.scale.x, h.sprite.scale.y, h.coluna, w.combate.fx.usados.duplicate()])
			casos.append(
				{"nome": nome, "hz": hz, "folha": Herois.sprite_da_partida(w.combate.heroi_id), "mecanica": mecanica, "visual": visual, "rng_final": randi()}
			)
			w.queue_free()
			await get_tree().process_frame
			await get_tree().process_frame
	var f := FileAccess.open(saida, FileAccess.WRITE)
	f.store_string(JSON.stringify(casos))
	f.close()
	Ambiente.finalizar()
	if DirAccess.dir_exists_absolute(Ambiente.raiz):
		print("FALHOU: fixture do contrato não foi removida")
		get_tree().quit(1)
		return
	for caminho in [Config.arquivo, Meta.caminho_save, Personagens.caminho_indice, Personagens.caminho_base, Personagens.caminho_antigo]:
		if not caminho.begins_with(Ambiente.raiz):
			print("FALHOU: callback do contrato escapou do sandbox")
			get_tree().quit(1)
			return
	print("contrato_golpes: ", casos.size(), " casos; ", "fixture limpa (sem exportação)" if saida.begins_with(Ambiente.raiz) else "exportados em " + saida)
	get_tree().quit()

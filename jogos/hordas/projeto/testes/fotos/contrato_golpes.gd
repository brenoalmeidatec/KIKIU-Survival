extends Node
## Traço reproduzível do combo real, separado do deslocamento puramente visual.
const Mundo = preload("res://v2/mundo.tscn")
const Heroi = preload("res://v2/heroi.gd")
const Herois = preload("res://v2/herois.gd")
const Meta = preload("res://v2/meta.gd")
const Personagens = preload("res://v2/personagens.gd")
var saida := "user://contrato_golpes.json"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
	Config.arquivo = "user://qa_contrato_opcoes.cfg"
	Config.recarregar()
	Config.temporario("pausar_fora", false)
	Config.temporario("qualidade_auto", false)
	Meta.caminho_save = "user://qa_contrato_meta.cfg"
	Personagens.caminho_indice = "user://qa_contrato_indice.cfg"
	Personagens.caminho_base = "user://qa_contrato_p"
	Personagens.caminho_antigo = "user://qa_contrato_antigo.cfg"
	var casos := []
	for nome in ["Breno", "Matheus", "Nicão", "Lucas"]:
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
	print("contrato_golpes: ", casos.size(), " casos gravados em ", saida)
	get_tree().quit()

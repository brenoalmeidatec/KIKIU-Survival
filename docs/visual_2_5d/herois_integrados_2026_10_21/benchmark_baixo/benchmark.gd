extends Node
## Harness externo idêntico para main e #394. Não avança o relógio com passo fixo: mede frames reais de render.

const PASSO_MAX := 0.1
const QUANTIDADE := 80
var w
var caso := "hazaki"
var saida := ""
var aquecer := 5.0
var duracao := 15.0
var inicio_us := 0
var anterior_us := 0
var coleta_us := 0
var amostras: Array[float] = []
var ultimo_ciclo := -1
var registro := {}


func _ready() -> void:
	set_process(false)
	if DisplayServer.get_name() == "headless":
		push_error("Benchmark exige render real com janela")
		get_tree().quit(2)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--personagem="):
			caso = a.trim_prefix("--personagem=")
		elif a.begins_with("--saida_bench="):
			saida = a.trim_prefix("--saida_bench=")
		elif a.begins_with("--aquecer="):
			aquecer = float(a.trim_prefix("--aquecer="))
		elif a.begins_with("--duracao_bench="):
			duracao = float(a.trim_prefix("--duracao_bench="))
	if saida == "":
		get_tree().quit(2)
		return
	Config.arquivo = "user://benchmark_opcoes.cfg"
	Config.recarregar()
	Config.temporario("pausar_fora", false)
	Config.temporario("qualidade_auto", false)
	Config.temporario("tamanho_ui", "grande")
	Config.g_perfil_temporario("baixo")
	var meta = load("res://v2/meta.gd")
	var personagens = load("res://v2/personagens.gd")
	var herois = load("res://v2/herois.gd")
	meta.caminho_save = "user://benchmark_meta.cfg"
	personagens.caminho_indice = "user://benchmark_indice.cfg"
	personagens.caminho_base = "user://benchmark_p"
	personagens.caminho_antigo = "user://benchmark_antigo.cfg"
	var nome: String = {"hazaki": "Breno", "matheus": "Matheus", "lucas": "Lucas", "nicao": "Nicão"}[caso]
	var id = personagens.criar(nome, personagens.heroi_do_nome(nome))
	personagens.ativar(id)
	herois.forcado = ""  # Matheus deve resolver pela folha do personagem ativo, nunca por herói forçado.
	seed(7)
	w = load("res://v2/mundo.tscn").instantiate()
	w.modo_teste = false
	add_child(w)
	w.set_process(false)
	w.set_process_input(false)
	w.set_process_unhandled_input(false)
	w.combate.audio.mudo = true
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = true
	w.heroi.m_critico = -1.0
	for i in QUANTIDADE:
		var ang := TAU * float(i) / QUANTIDADE
		var raio := 90.0 + float(i % 5) * 28.0
		var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(cos(ang) * raio, sin(ang) * raio * 0.65))
		m.vida_max = 1000000000.0
		m.vida = m.vida_max
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	registro = {
		"personagem": caso,
		"nome_ativo": personagens.nome(personagens.ativo()),
		"heroi_id": w.combate.heroi_id,
		"folha_do_heroi": herois.sprite(w.combate.heroi_id),
		"folha_real": _folha_real(),
		"folha_pixels_sha256": _hash(w.heroi.tipo.alb.get_image()),
		"quadro": [w.heroi.tipo.w, w.heroi.tipo.h],
		"perfil": Config.g_perfil(),
		"vsync": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
		"janela": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"semente": 7,
		"monstros_planejados": QUANTIDADE,
		"aquecimento_s": aquecer,
		"duracao_planejada_s": duracao,
		"renderer": RenderingServer.get_current_rendering_method(),
		"placa": RenderingServer.get_video_adapter_name(),
		"godot": Engine.get_version_info().string,
	}
	inicio_us = Time.get_ticks_usec()
	anterior_us = inicio_us
	set_process(true)


func _folha_real() -> String:
	# O cache guarda o nome de origem junto do MESMO dicionário/textura entregue ao ator.
	# Comparar PNG cru com pixels importados falha pelo tratamento dos pixels transparentes do importador.
	for nome in w.sprites._tipos:
		if w.sprites._tipos[nome] == w.heroi.tipo:
			return str(nome)
	return "desconhecida"


func _hash(imagem: Image) -> String:
	var copia := imagem.duplicate() as Image
	copia.convert(Image.FORMAT_RGBA8)
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(copia.get_data())
	return h.finish().hex_encode()


func _process(delta: float) -> void:
	var agora := Time.get_ticks_usec()
	var segundos := float(agora - inicio_us) / 1000000.0
	if segundos >= aquecer:
		if coleta_us == 0:
			coleta_us = agora
		else:
			amostras.append(float(agora - anterior_us) / 1000.0)
	anterior_us = agora
	var ciclo := int(segundos / 6.0)
	if ciclo != ultimo_ciclo:
		ultimo_ciclo = ciclo
		if ciclo % 2 == 0:
			w.heroi.hab_recarga = 0.0
			w.heroi.habilidade()
		else:
			w.heroi.esp_carga = w.heroi.esp_carga_max
			w.heroi.especial()
	w.heroi.entrada_forcada = Vector2.RIGHT if fmod(segundos, 2.0) < 1.0 else Vector2.LEFT
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	w.avancar(minf(delta, PASSO_MAX))
	if coleta_us > 0 and float(agora - coleta_us) / 1000000.0 >= duracao:
		set_process(false)
		_finalizar(agora)


func _finalizar(agora: int) -> void:
	var elapsed := float(agora - coleta_us) / 1000000.0
	var ordenadas := amostras.duplicate()
	ordenadas.sort()
	registro["duracao_real_s"] = elapsed
	registro["frames"] = amostras.size()
	registro["fps_medio"] = float(amostras.size()) / elapsed
	registro["frame_ms_p50"] = ordenadas[mini(int(ordenadas.size() * 0.50), ordenadas.size() - 1)]
	registro["frame_ms_p95"] = ordenadas[mini(int(ordenadas.size() * 0.95), ordenadas.size() - 1)]
	registro["monstros_finais"] = w.monstros.size()
	registro["frame_ms"] = amostras
	var f := FileAccess.open(saida, FileAccess.WRITE)
	f.store_string(JSON.stringify(registro, "\t"))
	f.close()
	print("BENCH ", caso, " folha=", registro.folha_real, " fps=", registro.fps_medio)
	w.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

extends "res://testes/isolamento_v2.gd"
## CAR-6a: efeito de tela, fila única, acessibilidade e reuso sem crescer a árvore.
const Mundo := preload("res://v2/mundo.tscn")
const EscalaUi := preload("res://v2/escala_ui.gd")
const Mapas := preload("res://v2/mapas.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w
var fx


func ok(cond: bool, mensagem: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", mensagem)


func _ready() -> void:
	var inicio := Time.get_ticks_msec()
	Config.g_perfil_temporario("alto")
	Config.g_temporario("tremor_clarao", 100)
	Config.temporario("reduzir_piscadas", false)
	w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = str(Mapas.LISTA[-1].id)
	add_child(w)
	w.set_process(false)
	w.combate.diretor.ligado = false
	w.combate.audio.mudo = true
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.args["particulas"] = "muitas"
	var tela_cfg: Dictionary = w.combate.cartas.cfg.apice.get("tela", {})
	for chave in ["_ajuda", "duracao", "espessura_anel", "alfa_vinheta", "alfa_clarao", "margem"]:
		ok(tela_cfg.has(chave), "apice.tela tem a chave " + chave)
	fx = w.combate.get("apice_tela")
	ok(fx != null, "a camada de tela existe antes do primeiro ÁPICE")
	if fx != null and not tela_cfg.is_empty():
		await get_tree().process_frame
		var fotos := ""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--fotos="):
				fotos = arg.trim_prefix("--fotos=")
		if fotos != "":
			await _fotos(fotos)
		else:
			_testar(tela_cfg)
			await _reencaixar()
	w.queue_free()
	await get_tree().process_frame
	EscalaUi.janela_forcada = Vector2i.ZERO
	print("v2_apice_tela falhas=%d duracao_ms=%d" % [falhas, Time.get_ticks_msec() - inicio])
	get_tree().quit(1 if falhas else 0)


func _disparar(quantos := 1) -> void:
	var antes: int = fx.disparos
	for i in quantos:
		w.combate.apice_ganho("qa_%d" % i, "Bônus %d" % i, Color(0.2, 0.7, 1.0))
	ok(fx.disparos == antes, "a fila espera a retomada do mundo")
	for i in 120:
		w.avancar(PASSO)
		if fx.disparos > antes:
			break
	ok(fx.disparos == antes + 1, "%d ÁPICES na fila disparam uma varredura" % quantos)
	ok(w.combate._apice_fila.is_empty(), "a fila foi consumida")


func _expirar() -> void:
	w.combate.efeitos(float(fx.duracao) + PASSO)
	ok(not fx.ativo and not fx.anel.visible and not fx.tela.visible, "parado: anel e sobreposição escondidos")


func _testar(tela_cfg: Dictionary) -> void:
	var nos := get_tree().get_node_count()
	var anel_id: int = fx.anel.get_instance_id()
	var tela_id: int = fx.tela.get_instance_id()
	_disparar(3)
	ok(fx.ativo and fx.anel.visible, "o anel aparece no mundo")
	ok(is_equal_approx(float(fx.raio_final), w.cam.retangulo().size.length() + float(tela_cfg.margem)), "anel ultrapassa diagonal da câmera mais margem")
	ok(is_equal_approx(float(fx.duracao), float(tela_cfg.duracao)), "duração lida dos dados")
	w.combate.efeitos(float(fx.duracao) * 0.25)
	ok(fx.vinheta_alfa > 0.0 and fx.clarao_alfa > 0.0, "clarões ligados: vinheta e clarão visíveis")
	ok(fx.vinheta_alfa <= float(tela_cfg.alfa_vinheta) and fx.clarao_alfa <= float(tela_cfg.alfa_clarao), "alfa respeita dados")
	ok(w.combate.lento_t > 0.0 and w.combate.lento_escala < 1.0, "o efeito ocorre durante a câmera lenta")
	_expirar()
	var disparos: int = fx.disparos
	for i in 90:
		w.avancar(PASSO)
	ok(fx.disparos == disparos, "voltar a andar não repete a fila consumida")
	Config.g_temporario("tremor_clarao", 0)
	_disparar()
	w.combate.efeitos(float(fx.duracao) * 0.25)
	ok(fx.simples and fx.anel.visible, "tremor/clarões desligados mantém anel")
	ok(fx.vinheta_alfa == 0.0 and fx.clarao_alfa == 0.0 and not fx.tela.visible, "opção desligada não cria pulso nem clarão")
	_expirar()
	Config.g_temporario("tremor_clarao", 100)
	w.args["particulas"] = "poucas"
	_disparar()
	w.combate.efeitos(float(fx.duracao) * 0.25)
	ok(fx.simples and fx.anel.visible, "perfil Baixo mantém o anel")
	ok(fx.vinheta_alfa == 0.0 and fx.clarao_alfa == 0.0 and not fx.tela.visible, "Baixo não desenha vinheta ou clarão")
	ok(fx.anel.material == null and fx.tela.material == null, "o efeito não usa shader")
	_expirar()
	w.args["particulas"] = "muitas"
	Config.temporario("reduzir_piscadas", true)
	_disparar()
	w.combate.efeitos(float(fx.duracao) * 0.25)
	ok(fx.clarao_alfa == 0.0, "Reduzir piscadas barra o clarão de tela inteira")
	_expirar()
	Config.temporario("reduzir_piscadas", false)
	for i in 20:
		_disparar()
		_expirar()
	ok(get_tree().get_node_count() == nos, "20 ÁPICES não acrescentam nós à árvore")
	ok(fx.anel.get_instance_id() == anel_id and fx.tela.get_instance_id() == tela_id, "os dois desenhos reutilizam os mesmos nós")
	w.reiniciar()
	ok(not fx.ativo and not fx.anel.visible and not fx.tela.visible, "reiniciar limpa efeito ativo")


## Fotografias de aquisição real do 5/5, em cenário preparado. Arquivos fora do projeto.
func _fotos(pasta: String) -> void:
	ok(DisplayServer.get_name() != "headless", "captura exige janela real")
	ok(pasta.is_absolute_path() and not pasta.begins_with(ProjectSettings.globalize_path("res://")), "fotos fora do projeto")
	if DisplayServer.get_name() == "headless" or not pasta.is_absolute_path() or pasta.begins_with(ProjectSettings.globalize_path("res://")):
		return
	DirAccess.make_dir_recursive_absolute(pasta)
	for ligado in [true, false]:
		w.reiniciar()
		w.combate.diretor.ligado = false
		w.heroi.imortal = true
		w.heroi.ataque_forcado = false
		w.heroi.entrada_forcada = Vector2.ZERO
		w.args["particulas"] = "muitas"
		Config.g_temporario("tremor_clarao", 100 if ligado else 0)
		Config.temporario("reduzir_piscadas", false)
		w.cam.cravar(w.heroi.centro())
		var cs = w.combate.cartas
		for i in 5:
			cs.aplicar(cs.montar_carta(cs.definicao("laminas"), 0))
		ok(cs.apice_de("laminas"), "a fotografia é de aquisição 5/5")
		for i in 120:
			w.avancar(PASSO)
			if fx.disparos > 0:
				break
		w.combate.efeitos(float(fx.duracao) * 0.18)
		ok(fx.ativo and fx.anel.visible, "varredura ativa no instante da foto")
		ok((fx.clarao_alfa > 0.0) == ligado, "clarão da foto segue a opção")
		var nome := "apice_claroes_ligados.png" if ligado else "apice_claroes_desligados.png"
		var tamanho = await w.ap.foto(pasta.path_join(nome))
		print(
			(
				"FOTO %s %s display=%s raio=%.1f vinheta=%.3f clarao=%.3f"
				% [nome, tamanho, DisplayServer.get_name(), fx.raio_atual, fx.vinheta_alfa, fx.clarao_alfa]
			)
		)


func _reencaixar() -> void:
	for tamanho in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(2560, 1080)]:
		EscalaUi.janela_forcada = tamanho
		w.ap.recalcular()
		await get_tree().process_frame
		_disparar()
		ok(fx.cobertura.is_equal_approx(w.ap.cobertura()), "sobreposição cobre o canvas em %s" % tamanho)
		_expirar()

extends "res://testes/isolamento_v2.gd"
# Teste dos detritos flutuantes da v2 (terra e pedacinhos subindo devagar, v2/atmosfera.gd). Ideia do Isac, aprovada pelo Alisson em 29/10.
# Confere: só as Ruínas da Floresta (medio) e a Vila Amaldiçoada (cidade) trazem "detritos" no json (com _ajuda); a floresta e o laboratório
# não; a quantidade por perfil (Alto = n, Médio = metade, Baixo e Nenhum = 0); no Baixo o emissor NEM NASCE e a atmosfera dos outros mapas
# fica igual; trocar de perfil com a partida rodando liga, desliga e cria o emissor na hora; o emissor segue a câmera.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_detritos.tscn  (imprime "v2_detritos falhas=0")
# Foto (precisa de janela): ... res://testes/v2_detritos.tscn -- --fotos=PASTA  grava detritos_<mapa>_<perfil>.png (não versione).
const Mundo := preload("res://v2/mundo.tscn")
const COM_DETRITOS := ["cidade", "medio"]
const SEM_DETRITOS := ["floresta", "laboratorio"]
const PASSO := 1.0 / 60.0

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	_dados()
	for id in SEM_DETRITOS + COM_DETRITOS:
		await _mapa_no_alto(id)
	for id in COM_DETRITOS:
		await _baixo_e_troca(id)
	Config.g_perfil_temporario("alto")
	print("v2_detritos falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _json(id: String) -> Dictionary:
	var f := FileAccess.open("res://dados/v2_%s.json" % id, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _dados() -> void:
	for id in COM_DETRITOS:
		var d: Dictionary = _json(id).get("atmosfera", {}).get("detritos", {})
		ok(int(d.get("n", 0)) > 0, "%s: o json traz detritos com n > 0" % id)
		ok(str(d.get("_ajuda", "")).length() > 40, "%s: detritos tem _ajuda" % id)
		ok(d.has("cor") and d.has("tam") and d.has("vel"), "%s: detritos tem cor, tam e vel" % id)
	for id in SEM_DETRITOS:
		ok(not _json(id).get("atmosfera", {}).has("detritos"), "%s: o json NÃO traz detritos" % id)
	var p: Dictionary = Config.PART_NIVEL
	ok(p["nenhuma"].amb_detritos == 0.0 and p["poucas"].amb_detritos == 0.0, "nenhuma e poucas (o Baixo) valem 0 em amb_detritos")
	ok(is_equal_approx(p["medias"].amb_detritos, 0.5) and not p.has("muitas"), "médias vale 0,5 e muitas fica no padrão (1)")


func _novo(id: String, perfil: String) -> Node:
	Config.g_perfil_temporario(perfil)
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = id
	add_child(w)
	w.set_process(false)
	for i in 30:
		w.avancar(PASSO)
	return w


func _tem_detrito_registrado(w) -> bool:
	for r in w.atm._regs:
		if r.tipo == "det":
			return true
	return false


func _mapa_no_alto(id: String) -> void:
	var w = _novo(id, "alto")
	var det: CPUParticles2D = w.atm._detritos
	if id in COM_DETRITOS:
		var cfg: Dictionary = _json(id).atmosfera.detritos
		ok(det != null, "%s alto: o emissor de detritos existe" % id)
		if det != null:
			ok(det.amount == int(cfg.n), "%s alto: %d detritos (json n=%d)" % [id, det.amount, int(cfg.n)])
			ok(det.emitting and det.visible and det.process_mode == Node.PROCESS_MODE_INHERIT, "%s alto: emitindo e processando" % id)
			ok(not det.local_coords and det.get_parent() == w.glow, "%s alto: no mundo (não segue o nó) e na camada do brilho" % id)
			ok(det.material == null, "%s alto: sem brilho aditivo (é terra, não luz)" % id)
	else:
		ok(det == null, "%s alto: sem emissor de detritos (mapa sem a chave)" % id)
		ok(not _tem_detrito_registrado(w), "%s alto: nada registrado como detrito" % id)
	await _foto(id, "alto")
	if det != null:
		w.atm.seguir(Vector2(700, 450))
		ok(det.position == Vector2(700, 450), "%s alto: o emissor segue a câmera" % id)
	w.queue_free()
	await get_tree().process_frame


func _baixo_e_troca(id: String) -> void:
	var cfg: Dictionary = _json(id).atmosfera.detritos
	# Baixo: o emissor nem nasce (nada de nó, nada de processamento) e a atmosfera de sempre continua igual
	var w = _novo(id, "baixo")
	ok(w.atm._detritos == null, "%s baixo: o emissor de detritos NÃO foi criado" % id)
	ok(w.atm.fator_det == 0.0, "%s baixo: fator de detritos 0" % id)
	ok(not _tem_detrito_registrado(w), "%s baixo: nenhum detrito registrado" % id)
	ok(w.atm._vaga != null and w.atm._folhas != null, "%s baixo: vaga-lumes e folhas seguem como antes" % id)
	ok(is_equal_approx(w.atm.fator_amb, 0.25), "%s baixo: o fator do ambiente continua 0,25 (%.2f)" % [id, w.atm.fator_amb])
	await _foto(id, "baixo")
	# sobe para Alto com a partida rodando: o emissor passa a existir, com a quantidade do json
	Config.g_perfil_temporario("alto")
	w._ler_graficos()
	var det: CPUParticles2D = w.atm._detritos
	ok(det != null and det.amount == int(cfg.n) and det.emitting and det.visible, "%s baixo para alto: detritos criados com n=%d" % [id, int(cfg.n)])
	# Médio: metade
	Config.g_perfil_temporario("medio")
	w._ler_graficos()
	ok(det.amount == int(round(float(cfg.n) * 0.5)) and det.emitting, "%s médio: metade dos detritos (%d)" % [id, det.amount])
	# volta ao Baixo: desligado de verdade (sem emitir, invisível, sem processar)
	Config.g_perfil_temporario("baixo")
	w._ler_graficos()
	ok(not det.emitting and not det.visible and det.process_mode == Node.PROCESS_MODE_DISABLED, "%s alto para baixo: detritos desligados e sem processar" % id)
	Config.g_perfil_temporario("alto")
	w._ler_graficos()
	ok(det.emitting and det.process_mode == Node.PROCESS_MODE_INHERIT, "%s baixo para alto: voltam a processar" % id)
	# Partículas Nenhuma: também desligado
	Config.g_temporario("particulas_sim", "nenhuma")
	w._ler_graficos()
	ok(not det.emitting and det.process_mode == Node.PROCESS_MODE_DISABLED, "%s nenhuma: detritos desligados" % id)
	Config.g_perfil_temporario("alto")
	w._ler_graficos()
	for i in 60:
		w.avancar(PASSO)
	ok(det.emitting, "%s: depois de trocar de perfil a partida segue rodando com detritos" % id)
	w.queue_free()
	await get_tree().process_frame


## Com --fotos=PASTA grava a tela (só com janela; no headless a imagem vem vazia e não grava).
func _foto(id: String, perfil: String) -> void:
	var pasta := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fotos="):
			pasta = arg.substr(8)
	if pasta == "" or DisplayServer.get_name() == "headless":
		return
	for i in 5:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pasta.path_join("detritos_%s_%s.png" % [id, perfil]))

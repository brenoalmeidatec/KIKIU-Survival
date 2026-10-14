extends Node
# Teste automático da música da v2 (v2/trilha.gd, o bus "Musica" de scripts/hordas/som.gd e dados/v2_musica.json). Usa saves
# TEMPORÁRIOS (meta e opções); o user://opcoes.cfg real não é tocado.
# Confere: o bus Musica existe, sai no Master e as duas faixas do Som tocam nele; cada momento do JSON aponta para um .ogg que existe
# e que está na lista de licenças (docs/LICENCAS_AUDIO.md); o santuário toca a faixa dele; a partida toca a dela; chefe aparecendo
# toca a do chefe; mini-chefe caindo volta a partida; o chefe final caindo (vitória em curso) segue na do chefe; o fim da partida
# toca a do resultado; reiniciar volta a partida; o slider Música (Config) move o bus, 0 silencia, e o volume salvo volta ao
# recarregar as opções (persistência).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_musica.tscn  (imprime "v2_musica falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Altar := preload("res://v2/altar.tscn")
const Meta := preload("res://v2/meta.gd")
const SAVE_TESTE := "user://teste_v2_musica_meta.cfg"
const OPCOES_TESTE := "user://teste_v2_musica_opcoes.cfg"
const PASTA_MUSICA := "res://assets/audio/musica/"
const LICENCAS := "../../../docs/LICENCAS_AUDIO.md"  # relativo à pasta do projeto (só existe com o repositório inteiro)

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	Config.arquivo = OPCOES_TESTE
	await _testes()
	Som.parar_musica()
	Config.arquivo = "user://opcoes.cfg"
	for c in [SAVE_TESTE, SAVE_TESTE + ".bak", SAVE_TESTE + ".tmp", OPCOES_TESTE]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))
	print("v2_musica falhas=%d" % falhas)
	get_tree().quit()


## Está tocando a faixa `nome` (a que entra no Som)?
func _toca(nome: String) -> bool:
	var s = load(PASTA_MUSICA + nome + ".ogg")
	return s != null and Som._atual.playing and Som._atual.stream == s


func _db_bus() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Som.BUS_MUSICA))


func _testes() -> void:
	# 1. o bus
	var i := AudioServer.get_bus_index(Som.BUS_MUSICA)
	ok(i != -1, "o bus Musica existe")
	ok(i != -1 and AudioServer.get_bus_send(i) == &"Master", "o bus Musica sai no Master")
	ok(Som._atual.bus == Som.BUS_MUSICA and Som._saida.bus == Som.BUS_MUSICA, "as duas faixas do Som tocam no bus Musica")

	# 2. os dados: cada momento tem faixa, o arquivo existe e a licença está registrada
	var faixas: Dictionary = Dados.json("v2_musica").get("faixas", {})
	var arq_lic := ProjectSettings.globalize_path("res://").path_join(LICENCAS).simplify_path()
	var licencas := FileAccess.get_file_as_string(arq_lic) if FileAccess.file_exists(arq_lic) else ""
	for m in ["santuario", "partida", "chefe", "resultado"]:
		var nome := str(faixas.get(m, ""))
		ok(nome != "", "o momento %s tem faixa em v2_musica.json" % m)
		ok(ResourceLoader.exists(PASTA_MUSICA + nome + ".ogg"), "a faixa %s (%s) existe" % [nome, m])
		if licencas != "":  # fora do repositório (exportado) o arquivo de licenças não está ao lado
			ok(licencas.contains("`%s.ogg`" % nome), "a faixa %s está em docs/LICENCAS_AUDIO.md" % nome)
	ok(faixas.size() == 4, "só os 4 momentos (sem faixa solta)")

	# 3. santuário
	Som.duracao_fade = 0.0  # troca seca nos testes: a conferência é de QUAL faixa, o crossfade é do cartas_comp
	Som.parar_musica()
	var altar = Altar.instantiate()
	add_child(altar)
	await get_tree().process_frame
	ok(altar.trilha != null and altar.trilha.momento == "santuario", "o santuário pede o momento santuario")
	ok(_toca(str(faixas.santuario)), "o santuário toca a faixa dele")
	altar.queue_free()
	await get_tree().process_frame

	# 4. partida
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	ok(mundo.trilha != null and mundo.trilha.momento == "partida", "a partida pede o momento partida")
	ok(_toca(str(faixas.partida)), "a partida toca a faixa dela (trocou a do santuário)")
	ok(await _bus_sonoro(), "a música passa pelo bus Musica (pico acima de -60 dB)")
	mundo.chefe_apareceu.emit("Chefe de Teste", 100.0)
	ok(mundo.trilha.momento == "chefe" and _toca(str(faixas.chefe)), "o chefe aparecendo toca a faixa do chefe")
	mundo.chefe_apareceu.emit("Chefe de Teste", 100.0)
	ok(_toca(str(faixas.chefe)), "um segundo aviso de chefe não reinicia a faixa")

	# mini-chefe cai com a partida seguindo: volta a faixa da partida (a decisão espera um quadro)
	mundo.combate.jogo = "jogando"
	mundo.chefe_vida.emit(40.0)
	await get_tree().process_frame
	ok(mundo.trilha.momento == "chefe", "chefe ferido (vida > 0) não troca a faixa")
	mundo.chefe_vida.emit(0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(mundo.trilha.momento == "partida" and _toca(str(faixas.partida)), "mini-chefe caindo volta a faixa da partida")

	# chefe final cai com a vitória em curso: segue a do chefe até o resultado
	mundo.chefe_apareceu.emit("Chefe Final", 500.0)
	mundo.combate.jogo = "vencendo"
	mundo.chefe_vida.emit(0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(mundo.trilha.momento == "chefe" and _toca(str(faixas.chefe)), "chefe final caindo mantém a faixa do chefe (vitória em curso)")

	# fim da partida
	mundo.partida_terminou.emit({"venceu": true})
	ok(mundo.trilha.momento == "resultado" and _toca(str(faixas.resultado)), "o fim da partida toca a faixa do resultado")
	mundo.reiniciar()
	ok(mundo.trilha.momento == "partida" and _toca(str(faixas.partida)), "jogar de novo volta a faixa da partida")
	mundo.queue_free()
	await get_tree().process_frame

	# 5. o slider Música (Config) move o bus, 0 silencia e o volume salvo volta ao recarregar as opções
	Config.definir("musica", 0.3)
	ok(absf(_db_bus() - linear_to_db(0.3)) < 0.1, "volume 30%% = %.1f dB no bus (veio %.1f)" % [linear_to_db(0.3), _db_bus()])
	ok(not AudioServer.is_bus_mute(AudioServer.get_bus_index(Som.BUS_MUSICA)), "30% não silencia")
	Config.definir("musica", 0.0)
	ok(AudioServer.is_bus_mute(AudioServer.get_bus_index(Som.BUS_MUSICA)), "volume 0 silencia o bus")
	Som.musica(str(faixas.partida))  # o mundo foi embora: põe a música de volta para o bus ter o que silenciar
	await get_tree().create_timer(0.4, true, false, true).timeout
	var pico := maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0))
	ok(pico < -60.0, "com o slider em 0 a música some do bus (pico %.0f dB)" % pico)
	Config.definir("musica", 0.7)
	Som.volume_musica = 0.6  # como se o jogo tivesse acabado de abrir com o padrão do Som...
	Som.atualizar_volume()
	Config.recarregar()  # ...e lesse o opcoes.cfg de novo (é o que o Config faz no _ready)
	Config.aplicar(false)
	ok(absf(Som.volume_musica - 0.7) < 0.001 and absf(_db_bus() - linear_to_db(0.7)) < 0.1, "o volume salvo (70%) volta ao abrir o jogo")
	ok(not AudioServer.is_bus_mute(AudioServer.get_bus_index(Som.BUS_MUSICA)), "o mute do 0 não fica preso depois de subir o volume")


## O bus está mesmo recebendo som (a faixa decodifica e passa pelo bus): pico acima de -60 dB em até 1 s.
func _bus_sonoro() -> bool:
	var b := AudioServer.get_bus_index(Som.BUS_MUSICA)
	for k in 10:
		await get_tree().create_timer(0.1, true, false, true).timeout
		if maxf(AudioServer.get_bus_peak_volume_left_db(b, 0), AudioServer.get_bus_peak_volume_right_db(b, 0)) > -60.0:
			return true
	return false

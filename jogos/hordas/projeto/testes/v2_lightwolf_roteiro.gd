extends "res://testes/isolamento_v2.gd"
# LW-8: o roteiro de fotos do LightWolf (v2/roteiro.gd, _r_lightwolf). Roda o roteiro inteiro numa partida de verdade (herói lightwolf, mecha
# imortal e parado, quadro a quadro como o _process do mundo) e confere: as 10 fotos saem na ordem certa (1_mecha ... 10_carta) e nenhum passo
# ficou esperando um estado até o prazo (lw_atrasos == 0: o E, o salto e o estouro do Q, o Lobo livre, o chamado e a volta aconteceram de
# verdade). Com janela, cada foto também tem de estar no disco com o arquivo gravado; em --headless não há janela (o viewport sai vazio), então
# ali só se conta que cada foto foi pedida, e o arquivo fica para a conferência com janela.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_lightwolf_roteiro.tscn  (imprime "v2_lightwolf_roteiro falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Roteiro := preload("res://v2/roteiro.gd")
const Meta := preload("res://v2/meta.gd")
const PASSO := 1.0 / 60.0
const LIMITE_QUADROS := 4000  # ~67 s de jogo; o roteiro leva uns 40 s
const PREFIXO := "lw8"
const PASTA := "user://testes_v2/v2_lightwolf_roteiro/fotos"
const SAVE_TESTE := "user://testes_v2/v2_lightwolf_roteiro/teste.cfg"
const ESPERADAS := ["1_mecha", "2_matriz", "3_misseis", "4_salto", "5_aceso", "6_explosao", "7_lobo", "8_chamado", "9_volta", "10_carta"]

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


## O roteiro de verdade, com a foto trocada por um registro: o pedido sai na hora, e com janela o arquivo é gravado e conferido.
class RoteiroCaptura:
	extends "res://v2/roteiro.gd"
	var pedidos: Array[String] = []
	var gravadas := 0

	func _foto(nome: String) -> void:
		ocupado = true
		pedidos.append(nome)
		if DisplayServer.get_name() != "headless":
			var caminho := pasta.path_join("%s_%s.png" % [prefixo, nome])
			var tam: Vector2i = await mundo.ap.foto(caminho)
			if FileAccess.file_exists(caminho) and tam.x > 0:
				gravadas += 1
		ocupado = false


func _ready() -> void:
	_run()


func _run() -> void:
	Meta.caminho_save = SAVE_TESTE
	Herois.forcado = "lightwolf"
	var pasta := ProjectSettings.globalize_path(PASTA)
	DirAccess.make_dir_recursive_absolute(pasta)
	for nome in ESPERADAS:
		var antiga := pasta.path_join("%s_%s.png" % [PREFIXO, nome])
		if FileAccess.file_exists(antiga):
			DirAccess.remove_absolute(antiga)
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var r := RoteiroCaptura.new()
	r.montar(w, {"roteiro": "lightwolf", "fotos": pasta, "nome": PREFIXO})
	ok(w.combate.heroi_id == "lightwolf", "a partida roda com o LightWolf (%s)" % str(w.combate.heroi_id))
	var quadros := 0
	while (r.pedidos.size() < ESPERADAS.size() or r.ocupado) and quadros < LIMITE_QUADROS:
		w.avancar(PASSO)  # o mesmo que o _process do mundo: avança o mundo e depois o roteiro
		r.atualizar(PASSO)
		if r.ocupado:
			await get_tree().process_frame
		quadros += 1
	ok(r.pedidos == ESPERADAS, "as fotos saem na ordem certa (%s)" % str(r.pedidos))
	ok(r.lw_atrasos == 0, "nenhum passo esperou um estado até o prazo (lw_atrasos=%d)" % r.lw_atrasos)
	if DisplayServer.get_name() == "headless":
		print("v2_lightwolf_roteiro: sem janela, %d fotos pedidas; os arquivos ficam para a conferência com janela" % r.pedidos.size())
	else:
		ok(r.gravadas == ESPERADAS.size(), "cada foto foi gravada no disco (%d de %d)" % [r.gravadas, ESPERADAS.size()])
	print("v2_lightwolf_roteiro: %d quadros, %d fotos, pasta %s" % [quadros, r.pedidos.size(), pasta])
	Herois.forcado = ""
	print("v2_lightwolf_roteiro falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)

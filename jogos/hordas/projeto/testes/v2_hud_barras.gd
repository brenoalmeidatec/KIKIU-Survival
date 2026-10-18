extends Node
# Teste do comprimento das barras de vida e de fôlego do HUD da v2 (v2/hud.gd, _barras). No máximo de partida a barra mede 142 px;
# cada ponto de vida acima da base do herói (mundo.combate.cfg) soma BARRA_PX_VIDA px, e cada carga de fôlego, BARRA_PX_FOLEGO. A barra
# desliza até o novo tamanho dentro de avancar; não corre com a escolha de carta na tela (a HUD some) e cresce quando ela volta; a
# moldura de pedra acompanha a mais comprida; o teto segura a borda antes do relógio (x 428); e o deslocamento do bloco no canvas
# (janela 1280x720) move as peças presas à borda sem mudar o comprimento.
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_hud_barras.tscn  (imprime "v2_hud_barras falhas=0")
# Prints: godot --path jogos/hordas/projeto res://testes/v2_hud_barras.tscn -- --fotos=PASTA  (o HUD do mundo real: antes, no meio do deslize, depois e teto; sai)
const Hud := preload("res://v2/hud.gd")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
const RELOGIO_X := 428.0  # o Tempo do HUD começa aqui (hud.tscn, Raiz/Tempo)

var falhas := 0


class Heroi:
	extends RefCounted
	var vida := 100.0
	var vida_max := 100.0
	var folego := 3.0
	var folego_max := 3.0
	var cansado := false


class Telas:
	extends RefCounted
	var escolha_aberta := false
	var bau_aberto := false


class Combate:
	extends RefCounted
	var cfg := {"heroi": {"vida": 100}, "folego": {"max": 3}}
	var telas := Telas.new()


class MundoFalso:
	extends RefCounted
	var heroi := Heroi.new()
	var combate := Combate.new()
	var tempo_partida := 0.0
	var abates := 0
	var combo := 0
	var monstros_vivos := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
		get_tree().quit()
		return
	_testes()
	print("v2_hud_barras falhas=%d" % falhas)
	get_tree().quit()


func _testes() -> void:
	var vista := SubViewport.new()  # 960x540, como o mundo
	vista.size = Vector2i(960, 540)
	vista.disable_3d = true
	add_child(vista)
	var falso := MundoFalso.new()
	var hud = Hud.criar(falso)
	vista.add_child(hud)
	hud.set_process(false)  # os passos são nossos
	var h: Heroi = falso.heroi

	# 1. no máximo de partida (vida 100, fôlego 3): barra de 142 px, moldura de 150 e o texto da vida com a barra
	hud.avancar(PASSO)
	ok(hud._vida_barra.size.x == 142.0 and hud._folego.size.x == 142.0, "base: barras de 142 px (%s, %s)" % [hud._vida_barra.size.x, hud._folego.size.x])
	ok(hud._moldura_barras.size.x == 150.0 and hud._vida_caixa.size.x == 150.0, "base: moldura e caixa da vida de 150 px")
	ok(hud._vida_txt.size.x == 142.0, "texto da vida tem a largura da barra (%s)" % hud._vida_txt.size.x)

	# 2. estátua (+50) e quatro cartas de vida (+80): 230 de vida dá 298 px; duas cargas a mais de fôlego dão 236 px
	h.vida_max = 230.0
	h.vida = 230.0
	h.folego_max = 5.0
	h.folego = 5.0
	hud.avancar(PASSO * 6.0)
	var meio: float = hud._vida_barra.size.x
	ok(meio > 142.0 and meio < 298.0, "a barra desliza, não pula (no meio do caminho: %s)" % meio)
	_passar(hud, 1.0)
	ok(hud._vida_barra.size.x == 298.0, "vida 230 vira barra de 298 px (tem %s)" % hud._vida_barra.size.x)
	ok(hud._folego.size.x == 236.0, "fôlego 5 vira barra de 236 px (tem %s)" % hud._folego.size.x)
	ok(hud._moldura_barras.size.x == 306.0 and hud._vida_caixa.size.x == 306.0, "a moldura acompanha a barra mais comprida (%s)" % hud._moldura_barras.size.x)
	ok(hud._vida_txt.size.x == 298.0, "o texto acompanha a barra da vida (%s)" % hud._vida_txt.size.x)

	# 3. teto: 100 mil de vida e 999 de fôlego não passam de 320 px, e a moldura para antes do relógio
	h.vida_max = 100000.0
	h.folego_max = 999.0
	_passar(hud, 1.0)
	ok(
		hud._vida_barra.size.x == 320.0 and hud._folego.size.x == 320.0,
		"teto de 320 px nas duas barras (%s, %s)" % [hud._vida_barra.size.x, hud._folego.size.x]
	)
	var borda: float = hud._moldura_barras.position.x + hud._moldura_barras.size.x
	ok(borda < RELOGIO_X - 8.0, "a moldura no teto para antes do relógio (borda em x %s)" % borda)

	# 4. volta ao normal: a barra encolhe junto
	h.vida_max = 100.0
	h.folego_max = 3.0
	_passar(hud, 1.0)
	ok(
		hud._vida_barra.size.x == 142.0 and hud._folego.size.x == 142.0,
		"volta ao máximo de partida: 142 px (%s, %s)" % [hud._vida_barra.size.x, hud._folego.size.x]
	)

	# 5. a base vem do herói: com 180 de vida de partida (Nicão) a barra começa em 142 px; 50 de bônus somam 60 px
	falso.combate.cfg = {"heroi": {"vida": 180}, "folego": {"max": 3}}
	h.vida_max = 180.0
	_passar(hud, 1.0)
	ok(hud._vida_barra.size.x == 142.0, "base de 180 de vida: barra de 142 px (tem %s)" % hud._vida_barra.size.x)
	h.vida_max = 230.0
	_passar(hud, 1.0)
	ok(hud._vida_barra.size.x == 202.0, "180 + 50 de bônus: barra de 202 px (tem %s)" % hud._vida_barra.size.x)
	falso.combate.cfg = {"heroi": {"vida": 100}, "folego": {"max": 3}}

	# 6. escolha de carta na tela (a HUD some): a barra fica parada; ao fechar, desliza até 298
	h.vida_max = 100.0
	_passar(hud, 1.0)
	falso.combate.telas.escolha_aberta = true
	h.vida_max = 230.0
	_passar(hud, 1.0)
	ok(hud._vida_barra.size.x == 142.0, "com a escolha na tela a barra não corre (tem %s)" % hud._vida_barra.size.x)
	ok(not hud.visible, "a HUD some com a escolha aberta")
	falso.combate.telas.escolha_aberta = false
	hud.avancar(PASSO)
	ok(hud.visible, "a HUD volta ao fechar a escolha")
	ok(hud._vida_barra.size.x > 142.0, "ao voltar, a barra começa a deslizar (tem %s)" % hud._vida_barra.size.x)
	_passar(hud, 1.0)
	ok(hud._vida_barra.size.x == 298.0, "e chega a 298 px (tem %s)" % hud._vida_barra.size.x)

	# 7. janela 1280x720 (Automático: canvas 1024x576, deslocamento 32,18): a moldura fica presa ao canto do canvas, e o comprimento não muda
	var vida_antes: float = hud._vida_barra.size.x
	var moldura_antes: float = hud._moldura_barras.size.x
	hud.ui_reencaixar(Vector2(1024, 576), Vector2(32, 18))
	_passar(hud, 0.5)
	var canto: float = hud._moldura_barras.position.x + 32.0
	ok(canto == 54.0 and hud._vida_caixa.position.x + 32.0 == 54.0, "a moldura fica presa ao canto do canvas (x %s)" % canto)
	ok(hud._vida_barra.size.x == vida_antes and hud._moldura_barras.size.x == moldura_antes, "o comprimento não muda com o deslocamento do bloco")

	# 8. sem mundo (HUD de antes da partida): os padrões de 100 de vida e 3 de fôlego, com barras de 142 px
	var sem = Hud.criar(null)
	vista.add_child(sem)
	sem.set_process(false)
	sem.avancar(PASSO)
	ok(sem._vida_barra.size.x == 142.0 and sem._folego.size.x == 142.0, "sem mundo: barras de 142 px (%s, %s)" % [sem._vida_barra.size.x, sem._folego.size.x])


## Prints do HUD do mundo real (o herói e o cfg da v2): antes (vida 100, fôlego 3), no meio do deslize (0,1 s depois),
## depois (vida 230, fôlego 5) e no teto (vida 400, fôlego 7).
func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.heroi.entrada_forcada = Vector2.ZERO
	for i in 60:
		w.avancar(PASSO)
	await _foto(w, pasta, "barras_antes")
	w.heroi.vida_max = 230.0
	w.heroi.vida = 230.0
	w.heroi.folego_max = 5.0
	w.heroi.folego = 5.0
	await get_tree().create_timer(0.1).timeout
	await _foto(w, pasta, "barras_meio_do_deslize")
	await get_tree().create_timer(0.8).timeout
	await _foto(w, pasta, "barras_depois")
	w.heroi.vida_max = 400.0
	w.heroi.vida = 400.0
	w.heroi.folego_max = 7.0
	w.heroi.folego = 7.0
	await get_tree().create_timer(0.8).timeout
	await _foto(w, pasta, "barras_teto")


func _foto(w, pasta: String, nome: String) -> void:
	var tam = await w.ap.foto(pasta.path_join("%s.png" % nome))
	print("FOTO %s %s" % [nome, tam])


func _passar(hud, segundos: float) -> void:
	for i in roundi(segundos / PASSO):
		hud.avancar(PASSO)

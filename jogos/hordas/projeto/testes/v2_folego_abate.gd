extends "res://testes/isolamento_v2.gd"
# Teste do TETO de fôlego que os abates devolvem (#374, "o fôlego cresce rápido demais no nível 30"): a carta Fôlego de caçador devolve valor% de uma carga por
# abate (12% a 38%, até 4 cartas), e numa horda de dezenas de abates por segundo isso enchia a barra na hora. dados/v2_combate.json folego.abate_max_s limita
# o que os abates devolvem por segundo (um balde que enche com o tempo); 0 desliga o teto. A regeneração normal (parado/andando) não muda.
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_folego_abate.tscn  (imprime "v2_folego_abate falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	var cfg: Dictionary = w.combate.cfg
	ok(float(cfg.folego.get("abate_max_s", 0.0)) > 0.0, "dados: folego.abate_max_s existe e é maior que zero")
	var teto := float(cfg.folego.abate_max_s)

	# 4 cartas lendárias (38,4% cada, 153,6% de carga por abate): sem teto, UM abate já enchia a barra
	w.combate.armas.definir_modificador("folego", 153.6)
	var h = w.heroi
	h.folego = 0.0
	h._credito_abate = teto
	_abates(h, 1)
	ok(h.folego <= teto + 0.001, "um abate de 153%% devolve no máximo o crédito de %s carga (%s)" % [teto, h.folego])

	# uma rajada de 40 abates no mesmo quadro não passa do teto (a barra não enche)
	h.folego = 0.0
	h._credito_abate = teto
	_abates(h, 40)
	ok(
		h.folego <= teto + 0.001 and h.folego < h.folego_max,
		"40 abates seguidos: no máximo %s carga, a barra não enche (%s de %s)" % [teto, h.folego, h.folego_max]
	)

	# 5 s com 30 abates por segundo: só o que veio dos abates entra na conta (a regeneração normal fica esperando o atraso)
	h.folego_max = 1000.0
	h.folego = 0.0
	h._credito_abate = teto
	var ganho := 0.0
	for i in 300:
		h._atraso_t = 99.0
		h._recuperar(PASSO, false)
		var antes: float = h.folego
		if i % 2 == 0:
			_abates(h, 1)  # 30 abates por segundo
		ganho += h.folego - antes
	ok(ganho <= teto * 5.0 + teto + 0.05, "5 s de abates (30/s): devolveu %s carga, no máximo %s" % [ganho, teto * 5.0 + teto])
	ok(ganho >= teto * 5.0 * 0.9, "o teto não é mais apertado do que diz: %s carga em 5 s (perto de %s)" % [ganho, teto * 5.0])

	# o balde enche com o tempo: sem crédito o abate não devolve; depois de 2 s volta a devolver
	h.folego_max = 3.0
	h.folego = 0.0
	h._credito_abate = 0.0
	_abates(h, 1)
	ok(h.folego == 0.0, "sem crédito, o abate não devolve nada (%s)" % h.folego)
	for i in 120:
		h._atraso_t = 99.0
		h._recuperar(PASSO, false)
	_abates(h, 1)
	ok(h.folego > 0.0, "depois de 2 s o crédito voltou e o abate devolve (%s)" % h.folego)

	# teto 0 = sem limite (o comportamento antigo)
	cfg.folego["abate_max_s"] = 0.0
	h.folego = 0.0
	_abates(h, 1)
	ok(is_equal_approx(h.folego, minf(1.536, h.folego_max)), "teto 0 desliga o limite: o abate devolve tudo (%s)" % h.folego)
	cfg.folego["abate_max_s"] = teto

	# sai do cansaço ao passar do limite, como antes (começa meio crédito abaixo do limite, então um abate cruza)
	h.folego = maxf(0.0, float(cfg.folego.cansado_ate) * h.folego_max - teto * 0.5)
	h.cansado = true
	h._credito_abate = teto
	_abates(h, 1)
	ok(not h.cansado, "o fôlego devolvido pelo abate tira o herói do cansaço")

	print("v2_folego_abate falhas=%d" % falhas)
	get_tree().quit()


## `n` abates: o que o combate faz a cada abate com o modificador (combate.matar chama isto com mods.folego / 100).
func _abates(h, n: int) -> void:
	for i in n:
		h.ganhar_folego_abate(float(w.combate.armas.mods.folego) / 100.0)

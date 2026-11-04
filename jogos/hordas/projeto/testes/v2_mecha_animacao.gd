extends "res://testes/isolamento_v2.gd"
## Estabilidade visual do corpo sem mudar timing real do ataque; E não simula tiro do braço.
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, mensagem: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", mensagem)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.escudo_forcado = false
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(300, 0)
	passos(3)


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()
	var h = w.heroi
	ok(bool(h.tipo.info.get("corpo_fixo_ao_atirar", false)), "a folha do mecha declara corpo fixo no tiro")
	ok(float(h.tipo.info.get("segurar_mira_s", 0.0)) > PASSO, "a mira cobre o intervalo visual entre tiros")
	h.ataque_forcado = true
	var livres := 0
	var golpes := 0
	for i in 60:
		passos(1)
		if h.estado == Heroi.Estado.GOLPE:
			golpes += 1
			ok(h.sprite.position == Vector2.ZERO and h.sprite.scale == Vector2.ONE, "tiro não desloca nem deforma o corpo inteiro")
		elif h.estado == Heroi.Estado.LIVRE and h._pose_tiro_t > 0.0:
			livres += 1
			ok(h.coluna == h._coluna_anim("combo", 0), "intervalo entre tiros mantém braços em mira")
	ok(golpes > 20 and livres > 0, "o teste percorreu golpes e intervalos reais com botão segurado")
	h.ataque_forcado = false
	for i in 10:
		if h.estado == Heroi.Estado.LIVRE:
			break
		passos(1)
	h.escudo_forcado = true
	passos(1)
	ok(h.escudo_ativo, "a Matriz responde imediatamente depois de atirar")
	ok(h.coluna == h._coluna_por_tempo("escudo", h.escudo_t), "mira mantida não esconde pose da Matriz")
	zerar()
	h.ataque_forcado = true
	passos(3)
	ok(h._pose_tiro_t > 0.0, "ataque real armou a pose")
	h.ataque_forcado = false
	w.reiniciar()
	ok(h._pose_tiro_t == 0.0, "reiniciar descarta a pose anterior")
	zerar()
	ok(h.habilidade() and h.hab_id == "misseis", "a E real inicia os mísseis")
	for i in 30:
		passos(1)
		ok(h.estado == Heroi.Estado.HABILIDADE and h.coluna == h._coluna_anim("parado", 0), "mísseis usam pose dos pods sem clarão do combo")
	zerar()
	var calmo_antes := Config.reduzir_piscadas
	Config.temporario("reduzir_piscadas", true)
	var colunas: Array = h.tipo.info.animacoes.combo.colunas
	ok(h._coluna_anim("combo", 1) == colunas[2] and h._coluna_anim("combo", 7) == colunas[8], "modo calmo escolhe os dois quadros sem clarão")
	Config.temporario("reduzir_piscadas", false)
	ok(h._coluna_anim("combo", 1) == colunas[1] and h._coluna_anim("combo", 7) == colunas[7], "modo normal mantém clarões de cada braço")
	Config.temporario("reduzir_piscadas", calmo_antes)
	# Controle negativo: a curva anterior continua para folhas que não declaram corpo fixo.
	var tipo_original: Dictionary = h.tipo
	h.tipo = tipo_original.duplicate()
	h.tipo.info = tipo_original.info.duplicate(true)
	h.tipo.info.erase("corpo_fixo_ao_atirar")
	h.proximo = 0
	h._iniciar_golpe()
	var deformou := false
	for fase in [0.1, 0.2, 0.3, 0.5, 0.8]:
		h.golpe_t = h.golpe_dur * fase
		h._visual(0.0, Vector2.ZERO)
		deformou = deformou or h.sprite.scale != Vector2.ONE or h.sprite.position != Vector2.ZERO
	ok(deformou, "a curva do corpo permanece para outras folhas")
	h.tipo = tipo_original
	Herois.forcado = ""
	w.queue_free()
	await get_tree().process_frame
	print("v2_mecha_animacao falhas=%d" % falhas)
	get_tree().quit(1 if falhas else 0)

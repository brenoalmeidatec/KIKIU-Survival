extends Node
## Prints REAIS do Nick (folha do Blender, PR "nicao no Blender") na partida da v2, em 960x540. Não roda no CI (fica em testes/fotos/).
## Grava: parado, andando (para a direita e para baixo), a batida e a pancada no quadro de impacto (de frente e de perfil) e o herói morto.
## Uso (janela oculta): godot --path jogos/hordas/projeto res://testes/fotos/nicao_fotos.tscn -- --fotos=PASTA [--prefixo=nicao]
## Imprime "FOTO <caminho>" a cada print.

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const PASSO := 1.0 / 60.0

var w
var pasta := "user://nicao_fotos"
var prefixo := "nicao"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--prefixo="):
			prefixo = a.trim_prefix("--prefixo=")
	DirAccess.make_dir_recursive_absolute(pasta)
	Config.temporario("pausar_fora", false)  # a janela fora da tela perde o foco: a pausa abriria sobre os prints
	Herois.forcado = "nicao"
	w = Mundo.instantiate()
	w.modo_teste = false
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	await _quadros(3)
	_zerar()
	var h = w.heroi
	# parado, de frente
	w.mouse_forcado = h.centro() + Vector2(0, 100)
	passos(12)
	await _foto("parado_baixo")
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(12)
	await _foto("parado_direita")
	# andando
	h.entrada_forcada = Vector2(1, 0)
	passos(22)
	await _foto("andando_direita")
	h.entrada_forcada = Vector2(0, 1)
	w.mouse_forcado = h.centro() + Vector2(0, 100)
	passos(22)
	await _foto("andando_baixo")
	h.entrada_forcada = Vector2(-1, -1).normalized()
	w.mouse_forcado = h.centro() + Vector2(-100, -100)
	passos(22)
	await _foto("andando_cima_esq")
	h.entrada_forcada = Vector2.ZERO
	passos(6)
	# batida e pancada, de perfil (alvos à direita)
	_zerar()
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	_alvos(Vector2(1, 0))
	_golpe()
	_acertar()
	await _foto("batida_impacto_direita")
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	_golpe()
	_acertar()
	await _foto("pancada_impacto_direita")
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	# meio do golpe, de frente (alvos embaixo) e de costas
	_zerar()
	w.mouse_forcado = h.centro() + Vector2(0, 100)
	_alvos(Vector2(0, 1))
	_golpe()
	_acertar()
	await _foto("batida_impacto_baixo")
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	_golpe()
	passos(14)
	await _foto("pancada_subindo_baixo")
	_acertar()
	await _foto("pancada_impacto_baixo")
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	# sem alvos (nada de clarão de acerto por cima): o meio da batida e a pancada, de perfil e de frente
	var cc: Array = h.tipo.info.animacoes.combo.colunas
	for dir in [["direita", Vector2(100, 0)], ["baixo", Vector2(0, 100)]]:
		_zerar()
		w.mouse_forcado = h.centro() + dir[1]
		_golpe()
		ate(func(): return h.coluna == int(cc[2]), 80)
		await _foto("batida_meio_%s" % dir[0])
		ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
		_golpe()
		ate(func(): return h.golpes > _g0 and h.coluna == int(cc[7]), 80)
		await _foto("pancada_antecipacao_%s" % dir[0])
		ate(func(): return h.coluna == int(cc[9]), 80)
		await _foto("pancada_chao_%s" % dir[0])
		ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	# esquiva e defesa
	_zerar()
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	h.entrada_forcada = Vector2(1, 0)
	h.esquivar()
	passos(8)
	await _foto("rolamento")
	h.entrada_forcada = Vector2.ZERO
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 120)
	h.escudo_forcado = true
	passos(30)
	await _foto("defesa")
	h.escudo_forcado = null
	# morto
	_zerar()
	w.mouse_forcado = h.centro() + Vector2(0, 100)
	h.imortal = false
	h.invenc = 0.0
	h.levar_dano(100000.0, h.pos + Vector2(30, 0))
	passos(12)
	await _foto("morrendo")
	var cm: Array = h.tipo.info.animacoes.morte.colunas
	ate(func(): return h.coluna == int(cm[cm.size() - 1]), 1200)
	await _foto("morto")
	print("fotos: fim")
	get_tree().quit()


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func ate(cond: Callable, max_passos: int) -> int:
	for i in max_passos:
		if cond.call():
			return i
		w.avancar(PASSO)
	return -1 if not cond.call() else max_passos


func _zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.heroi.m_critico = -1.0
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	passos(3)


## Alguns cavaleiros ocos (aguentam os dois golpes) diante do herói, na direção `d`.
func _alvos(d: Vector2) -> void:
	for k in 3:
		var p: Vector2 = w.heroi.pos + d * (46.0 + 16.0 * k) + d.orthogonal() * (k - 1) * 22.0
		var m = w.nascer_monstro("inimigo_cavaleiro_oco", p)
		m.atordoa_t = 0.0


var _g0 := 0


## Pede um golpe e lembra a contagem de golpes (golpe_acertou do golpe anterior fica ligado até o próximo começar).
func _golpe() -> void:
	_g0 = w.heroi.golpes
	w.heroi.atacar()


## Avança até o quadro de acerto do golpe pedido por _golpe (o impacto da marreta).
func _acertar() -> void:
	ate(func(): return w.heroi.golpes > _g0 and w.heroi.golpe_acertou, 80)


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	var caminho := pasta.path_join("%s_%s.png" % [prefixo, nome])
	var tam = await w.ap.foto(caminho)
	print("FOTO %s %s coluna=%d linha=%d" % [caminho, tam, w.heroi.coluna, w.heroi.linha])

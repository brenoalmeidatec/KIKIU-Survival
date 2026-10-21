extends CanvasLayer
## Transições suaves entre telas da v2 (#377): fade e deslize curtos (0,15 a 0,25 s) em cada troca.
## É um autoload ("Transicoes"). Dois usos, os dois só desenho por cima: a lógica do jogo nunca espera por eles.
##
## 1. Troca de cena: `Transicoes.ir_para(self, caminho)` no lugar de get_tree().change_scene_to_file. Tira uma foto da tela, troca
##    a cena e deixa a foto sumir por cima (fade + um deslize de poucos pixels), então a cena nova já está viva e recebendo
##    entrada desde o primeiro quadro: nada de entrada engolida. O segundo pedido de troca no mesmo instante (Enter duplo) é
##    ignorado: uma ida, uma cena.
## 2. Painel dentro da tela: `entrar(c)` aparece com fade + deslize, `sair(c)` some do mesmo jeito (pausa, ajustes, Códice,
##    resultado, créditos). O estado do painel (aberto, fechado, pausa da árvore) muda na hora, só a imagem é suave.
##
## "Reduzir animações" (Config, Acessibilidade): `reduzido()` zera tudo, e `duracao(base)` serve a quem quiser respeitar a opção
## (a frente das cartas, #376). A duração é em tempo real (relógio da máquina), então câmera lenta e pausa não mexem nela.

const DUR_TROCA := 0.22  # a foto da tela antiga some em tanto tempo
const DUR_ENTRAR := 0.18  # painel que aparece
const DUR_SAIR := 0.15  # painel que some (o mais curto: quem fecha quer ver o jogo de volta)
const DESLIZE_TROCA := 22.0  # px que a foto antiga anda até sumir
const DESLIZE_PAINEL := Vector2(0.0, 10.0)  # de onde o painel desliza até o lugar
const OPCAO := "reduzir_animacoes"

var _foto := TextureRect.new()  # a tela de antes da troca
var _veu := ColorRect.new()  # quando não dá para fotografar (sem renderizador), um véu escuro fraco faz o papel
var _dur := 0.0
var _t0 := -1  # Time.get_ticks_usec() do início do fade; -1 = a cena nova ainda não desenhou, -2 = desenhou o primeiro quadro
var _dir := -1.0  # -1: a tela antiga sai para a esquerda (avançar); +1: para a direita (voltar)
var _pendente := false  # ir_para já pediu e a troca ainda não aconteceu
var _animando := false
var trocas := 0  # quantas trocas de cena passaram por aqui (teste/medição)
var ultimo_caminho := ""


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foto.stretch_mode = TextureRect.STRETCH_SCALE
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # a tela toda, em qualquer escala do canvas (a partida troca a dela)
	_foto.visible = false
	add_child(_foto)
	_veu.color = Color(0.03, 0.025, 0.05)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veu.visible = false
	add_child(_veu)


## A opção "Reduzir animações" está ligada.
func reduzido() -> bool:
	return bool(Config.v(OPCAO))


## `base` em segundos, ou 0 com "Reduzir animações". Quem anima por conta própria (a roleta de cartas) usa isto.
func duracao(base: float) -> float:
	return 0.0 if reduzido() else base


## Uma troca de cena está em andamento (pedida ou com a foto ainda sumindo).
func ativa() -> bool:
	return _pendente or _animando


# ------------------------------------------------------------------ troca de cena


## Troca para a cena `caminho` com a foto da tela antiga sumindo por cima. `voltando` faz o deslize ir para o outro lado.
## Devolve false se já havia uma troca pedida (o pedido repetido é descartado, a primeira ida vale).
func ir_para(no: Node, caminho: String, voltando := false) -> bool:
	if _pendente:
		return false
	var arvore := no.get_tree() if is_instance_valid(no) and no.is_inside_tree() else get_tree()
	_pendente = true
	trocas += 1
	ultimo_caminho = caminho
	_dir = 1.0 if voltando else -1.0
	_dur = duracao(DUR_TROCA)
	_animando = false
	_foto.visible = false
	_veu.visible = false
	if _dur > 0.0:
		_fotografar(arvore)
	_trocar.call_deferred(arvore, caminho)
	return true


func _fotografar(arvore: SceneTree) -> void:
	var img: Image = null
	if DisplayServer.get_name() != "headless":
		var tex := arvore.root.get_texture()
		if tex != null:
			img = tex.get_image()
	if img != null and not img.is_empty():
		_foto.texture = ImageTexture.create_from_image(img)
		_foto.modulate.a = 1.0
		_foto.offset_left = 0.0
		_foto.offset_right = 0.0
		_foto.visible = true
	else:
		_veu.modulate.a = 0.6
		_veu.visible = true


func _trocar(arvore: SceneTree, caminho: String) -> void:
	_pendente = false
	if not is_instance_valid(arvore):
		return
	arvore.change_scene_to_file(caminho)
	if _dur > 0.0:
		_animando = true
		_t0 = -1  # o relógio só começa depois do primeiro quadro com a cena nova: um carregamento pesado não engole o fade


func _process(_dt: float) -> void:
	if not _animando:
		return
	var agora := Time.get_ticks_usec()
	if _t0 == -1:
		_t0 = -2  # primeiro quadro com a cena nova: é o do carregamento e da primeira pintura, o mais pesado; a foto o cobre inteiro
		return
	if _t0 == -2:
		_t0 = agora  # a pintura da cena nova já passou: o fade começa agora e dura o tempo todo
	var p := clampf((agora - _t0) / 1.0e6 / _dur, 0.0, 1.0)
	var suave := 1.0 - pow(1.0 - p, 2.0)  # sai rápido e assenta devagar
	_foto.modulate.a = 1.0 - suave
	var dx := _dir * DESLIZE_TROCA * suave
	_foto.offset_left = dx
	_foto.offset_right = dx
	_veu.modulate.a = 0.6 * (1.0 - suave)
	if p >= 1.0:
		_animando = false
		_foto.visible = false
		_veu.visible = false


# ------------------------------------------------------------------ painel dentro da tela


## `c` aparece: fade de `alfa0` até 1, deslizando de `desloc` até o lugar (ZERO = só fade; dentro de Container também só fade).
func entrar(c: CanvasItem, desloc := DESLIZE_PAINEL, alfa0 := 0.0, dur := DUR_ENTRAR) -> void:
	if not is_instance_valid(c):
		return
	var base := _base(c)
	c.visible = true
	var d := duracao(dur)
	if d <= 0.0 or not c.is_inside_tree():
		_fixar(c, base)
		return
	var cima := _desloc(c, desloc)
	if not animando(c):  # no meio de um sair, volta de onde está em vez de recomeçar do zero
		c.modulate.a = alfa0 * base.a
		if c is Control:
			(c as Control).position = base.pos + cima
		elif c is Node2D:
			(c as Node2D).position = base.pos + cima
	var tw := _novo_tween(c)
	tw.tween_property(c, "modulate:a", base.a, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if cima != Vector2.ZERO:
		tw.parallel().tween_property(c, "position", base.pos, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_fixar.bind(c, base))


## `c` some: fade até 0 (com um pequeno deslize), e no fim fica invisível e volta ao estado normal. Sem animação, some na hora.
func sair(c: CanvasItem, desloc := DESLIZE_PAINEL * 0.5, dur := DUR_SAIR) -> void:
	if not is_instance_valid(c):
		return
	var base := _base(c)
	var d := duracao(dur)
	if d <= 0.0 or not c.is_inside_tree() or not c.visible:
		_fixar(c, base)
		c.visible = false
		return
	var cima := _desloc(c, desloc)
	var tw := _novo_tween(c)
	tw.tween_property(c, "modulate:a", 0.0, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if cima != Vector2.ZERO:
		tw.parallel().tween_property(c, "position", base.pos + cima, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(
		func():
			_fixar(c, base)
			if is_instance_valid(c):
				c.visible = false
	)


## Está no meio de um entrar ou de um sair.
func animando(c: CanvasItem) -> bool:
	return is_instance_valid(c) and c.has_meta("tr_tween") and (c.get_meta("tr_tween") as Tween).is_valid()


## Estado "de repouso" de c: o que ele era antes da primeira animação em curso (para uma segunda não empilhar o deslize).
func _base(c: CanvasItem) -> Dictionary:
	if c.has_meta("tr_base"):
		return c.get_meta("tr_base")
	var pos := Vector2.ZERO
	if c is Control:
		pos = (c as Control).position
	elif c is Node2D:
		pos = (c as Node2D).position
	var b := {"pos": pos, "a": c.modulate.a}
	c.set_meta("tr_base", b)
	return b


func _desloc(c: CanvasItem, desloc: Vector2) -> Vector2:
	if c.get_parent() is Container or not (c is Control or c is Node2D):
		return Vector2.ZERO
	return desloc


func _novo_tween(c: CanvasItem) -> Tween:
	if c.has_meta("tr_tween"):
		var velho: Tween = c.get_meta("tr_tween")
		if velho != null and velho.is_valid():
			velho.kill()
	var tw := create_tween()
	tw.bind_node(c)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	c.set_meta("tr_tween", tw)
	return tw


## Devolve c ao repouso (alfa e posição de antes) e limpa a marca da animação.
func _fixar(c: CanvasItem, base: Dictionary) -> void:
	if not is_instance_valid(c):
		return
	if c.has_meta("tr_tween"):
		var tw: Tween = c.get_meta("tr_tween")
		if tw != null and tw.is_valid():
			tw.kill()
		c.remove_meta("tr_tween")
	c.modulate.a = base.a
	if c is Control:
		(c as Control).position = base.pos
	elif c is Node2D:
		(c as Node2D).position = base.pos
	c.remove_meta("tr_base")

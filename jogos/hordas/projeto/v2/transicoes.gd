extends CanvasLayer
## Transições suaves entre telas da v2 (#377): fade e deslize curtos (0,15 a 0,25 s) em cada troca.
## É um autoload ("Transicoes"). Dois usos, os dois só desenho por cima: a lógica do jogo nunca espera por eles.
##
## 1. Troca de cena: `Transicoes.ir_para(self, caminho)` no lugar de get_tree().change_scene_to_file. Tira uma foto da tela, troca
##    a cena e deixa a foto sumir por cima (fade + um deslize de poucos pixels). No perfil Baixo (e sem renderizador) não há foto:
##    um véu escuro some no lugar (a foto custa ~3,5 ms de espera pela GPU). Enquanto a foto/véu está na tela, a entrada (teclas,
##    mouse, controle) é descartada: o jogador ainda vê a tela antiga, então um Enter impaciente não pode valer na cena nova.
##    Ao fim do fade a entrada volta e a primeira vale normalmente, uma vez só. O segundo pedido de troca no mesmo instante (Enter
##    duplo) é ignorado: uma ida, uma cena. Um pedido durante o fade da troca anterior cancela esse fade antes de fotografar.
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
const GRUPO_ATIVOS := "ui_transicoes_ativas"

var _foto := TextureRect.new()  # a tela de antes da troca
var _veu := ColorRect.new()  # quando não dá para fotografar (sem renderizador), um véu escuro fraco faz o papel
var _dur := 0.0
var _t0 := -1  # Time.get_ticks_usec() do início do fade; -1 = a cena nova ainda não desenhou, -2 = desenhou o primeiro quadro
var _dir := -1.0  # -1: a tela antiga sai para a esquerda (avançar); +1: para a direita (voltar)
var _pendente := false  # ir_para já pediu e a troca ainda não aconteceu
var _animando := false
var _bloqueando := false  # a entrada da janela está desligada (gui_disable_input) durante a foto/véu
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
	var havia_fade := _animando
	_encerrar()  # um fade da troca anterior ainda rodando é cancelado antes de fotografar
	_pendente = true
	trocas += 1
	ultimo_caminho = caminho
	_dir = 1.0 if voltando else -1.0
	_dur = duracao(DUR_TROCA)
	if _dur > 0.0:
		_bloquear(arvore)
	if havia_fade and _dur > 0.0:
		_fotografar_depois(arvore, caminho)  # o último quadro desenhado ainda tem a foto antiga: espera um quadro sem ela
		return true
	if _dur > 0.0:
		_fotografar(arvore)
	_trocar.call_deferred(arvore, caminho)
	return true


## Dá para fotografar a tela: há renderizador e o perfil não é o Baixo (get_image espera a GPU terminar o quadro). Senão vai o véu.
func usa_foto() -> bool:
	return DisplayServer.get_name() != "headless" and Config.g_perfil() != "baixo"


func _fotografar_depois(arvore: SceneTree, caminho: String) -> void:
	await arvore.process_frame
	if _dur > 0.0 and is_instance_valid(arvore):
		_fotografar(arvore)
	_trocar.call_deferred(arvore, caminho)


func _fotografar(arvore: SceneTree) -> void:
	var img: Image = null
	if usa_foto():
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
		_encerrar()
		return
	arvore.change_scene_to_file(caminho)
	if _dur > 0.0:
		_animando = true
		_t0 = -1  # o relógio só começa depois do primeiro quadro com a cena nova: um carregamento pesado não engole o fade
	else:
		_encerrar()


## Esconde a foto e o véu, solta a textura da foto (não fica uma tela inteira guardada durante a partida) e devolve a entrada.
func _encerrar() -> void:
	_animando = false
	_foto.visible = false
	_foto.texture = null
	_veu.visible = false
	_liberar()


## Liga/desliga a entrada da janela inteira. O Input (tecla segurada, eixos) segue valendo para quem lê por polling: só os
## eventos que chegam às cenas (_input, GUI, _unhandled_input) são descartados.
func _bloquear(arvore: SceneTree) -> void:
	_bloqueando = true
	arvore.root.gui_disable_input = true


func _liberar() -> void:
	if _bloqueando and is_inside_tree():
		get_tree().root.gui_disable_input = false
	_bloqueando = false


## A entrada está descartada agora (a foto/véu da troca ainda está na tela).
func entrada_bloqueada() -> bool:
	return _bloqueando


func _exit_tree() -> void:
	_liberar()


## Refaz o layout da UI e atualiza a posição-base dos painéis animados que o layout moveu.
## Assim, o fim ou uma interrupção da animação não devolve um controle à posição anterior ao resize.
func reencaixar_ui(canvas: Vector2, desloc: Vector2) -> void:
	var antes: Dictionary = {}
	for item in get_tree().get_nodes_in_group(GRUPO_ATIVOS):
		if is_instance_valid(item):
			antes[item] = _posicao(item)
	get_tree().call_group("ui_escala", "ui_reencaixar", canvas, desloc)
	for item in antes:
		if not is_instance_valid(item) or not item.has_meta("tr_base"):
			continue
		var atual := _posicao(item)
		if atual.distance_to(antes[item]) > 0.01:
			var base: Dictionary = item.get_meta("tr_base")
			base.pos = atual


func _posicao(c: CanvasItem) -> Vector2:
	if c is Control:
		return (c as Control).position
	if c is Node2D:
		return (c as Node2D).position
	return Vector2.ZERO


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
		_encerrar()


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
		base.mov = true
		tw.parallel().tween_property(c, "position", base.pos, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_fixar.bind(c, base))


## `c` some: fade até 0 (com um pequeno deslize), e no fim fica invisível e volta ao estado normal. Sem animação, some na hora.
## `fim` (opcional) roda quando o fade acaba (ou na hora, sem animação); `esconder` false deixa `c` visível no fim (quem chama decide).
func sair(c: CanvasItem, desloc := DESLIZE_PAINEL * 0.5, dur := DUR_SAIR, fim := Callable(), esconder := true) -> void:
	if not is_instance_valid(c):
		return
	var base := _base(c)
	var d := duracao(dur)
	if d <= 0.0 or not c.is_inside_tree() or not c.visible:
		_fixar(c, base)
		if esconder:
			c.visible = false
		if fim.is_valid():
			fim.call()
		return
	var cima := _desloc(c, desloc)
	var tw := _novo_tween(c)
	tw.tween_property(c, "modulate:a", 0.0, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if cima != Vector2.ZERO:
		base.mov = true
		tw.parallel().tween_property(c, "position", base.pos + cima, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(
		func():
			_fixar(c, base)
			if is_instance_valid(c) and esconder:
				c.visible = false
			if fim.is_valid():
				fim.call()
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
	var b := {"pos": pos, "a": c.modulate.a, "mov": false}  # "mov": a animação mexeu na posição (só então o fim a repõe)
	c.set_meta("tr_base", b)
	if c is Control or c is Node2D:
		c.add_to_group(GRUPO_ATIVOS)
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
	c.remove_from_group(GRUPO_ATIVOS)
	c.modulate.a = base.a
	if base.mov:  # sem deslize a posição não é nossa: um reencaixe de layout no meio do fade (resize) não pode ser desfeito
		if c is Control:
			(c as Control).position = base.pos
		elif c is Node2D:
			(c as Node2D).position = base.pos
	c.remove_meta("tr_base")

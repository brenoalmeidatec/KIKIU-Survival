extends RefCounted
## Controles do menu de pausa da v2 (#422): Ajustes > Controles. A lista das ações que o jogo lê (v2/controles.gd), cada uma com o glifo da tecla ou do
## botão que vale agora (teclado e mouse à esquerda, controle à direita), mais "Restaurar padrão" e "Voltar". Enter, A ou o clique escolhem a ação e o
## jogo espera o próximo comando: tecla, botão do mouse, botão ou gatilho do controle (o slot trocado é o do dispositivo que apertou). Esc ou Start
## cancelam. Se o comando novo já era de outra ação, as duas trocam de lugar e o aviso diz quais. Esta classe só dá as linhas e trata a captura; o
## desenho e a navegação são da pausa (pausa.gd), como em ajustes_graficos.gd. Ids das linhas: "ct:<acao>" (ação do InputMap), "ct:restaurar" e "voltar".

const Controles := preload("res://v2/controles.gd")
const Glifos := preload("res://v2/glifos.gd")
const Paleta := preload("res://v2/paleta.gd")

const AJUDA := "Enter, A ou clique e depois aperte a nova tecla, botão do mouse ou do controle. Se já era de outra ação, as duas trocam de lugar."
const AJUDA_ANDAR := "A tecla nova substitui a letra e a seta dessa direção. O analógico do controle não muda. Se já era de outra ação, as duas trocam de lugar."
const AJUDA_CAPTURA := "Aperte a nova tecla, botão do mouse ou do controle para %s. Esc ou Start cancelam."
const AJUDA_RESTAURAR := "Volta todos os comandos para o padrão do jogo."
const GATILHO_FIRME := Controles.LIMIAR_GATILHO

var capturando := ""  # id da ação que espera o próximo comando ("" = nenhuma)
var mensagem := ""  # aviso curto (troca, tecla reservada...), mostrado embaixo do título


## As linhas da tela. O campo "glifos" pede à pausa o desenho dos glifos da ação à direita da linha.
func itens() -> Array:
	var r: Array = []
	for a in Controles.ACOES:
		var esperando: bool = capturando == a.id
		var it := {
			"id": "ct:%s" % a.id, "rotulo": a.nome, "valor": "Aperte o novo..." if esperando else "", "ajuda": AJUDA_ANDAR if a.slots.size() == 1 else AJUDA
		}
		if esperando:
			it["ajuda"] = AJUDA_CAPTURA % String(a.nome).to_lower()
		else:
			it["glifos"] = a.id
		r.append(it)
	r.append({"id": "ct:restaurar", "rotulo": "Restaurar padrão", "valor": "", "ajuda": AJUDA_RESTAURAR})
	r.append({"id": "voltar", "rotulo": "Voltar", "valor": "", "ajuda": ""})
	return r


## A linha foi acionada (Enter, A ou clique). `acao` = o que vem depois de "ct:".
func agir(acao: String) -> void:
	mensagem = ""
	if acao == "restaurar":
		capturando = ""
		Controles.restaurar()
		Glifos.avisar()
		mensagem = "Controles restaurados."
	else:
		capturando = acao


func limpar() -> void:
	capturando = ""
	mensagem = ""


## Esc ou Start com a captura aberta.
func cancelar() -> void:
	capturando = ""
	mensagem = ""


## Trata um evento enquanto espera o comando novo. Devolve true se a captura terminou (troca feita ou cancelada) e false se segue esperando (um
## comando recusado, ou um evento que não é comando: movimento do mouse, soltura de tecla, analógico).
func capturar(e: InputEvent) -> bool:
	if capturando == "":
		return false
	if e is InputEventKey:
		if not e.pressed or e.echo:
			return false
		if e.physical_keycode == KEY_ESCAPE or e.keycode == KEY_ESCAPE:
			cancelar()
			return true
	elif e is InputEventMouseButton:
		if not e.pressed or not (e.button_index in Controles.BOTOES_MOUSE):
			return false  # a roda do mouse não é comando
	elif e is InputEventJoypadButton:
		if not e.pressed:
			return false
		if e.button_index == JOY_BUTTON_START:
			cancelar()
			return true
	elif e is InputEventJoypadMotion:
		if not (e.axis == JOY_AXIS_TRIGGER_LEFT or e.axis == JOY_AXIS_TRIGGER_RIGHT) or e.axis_value < GATILHO_FIRME:
			return false  # o analógico e o gatilho de leve (ou parado em -1 no repouso) não são comando
	else:
		return false
	var acao := capturando
	var r := Controles.definir(acao, e)
	Glifos.avisar()  # a HUD e as dicas mostram o comando novo
	if not bool(r.ok):
		mensagem = _recusa(String(r.motivo), acao)
		return false
	capturando = ""
	if String(r.troca) != "":
		mensagem = "%s e %s trocaram de lugar." % [Controles.nome_da_acao(acao), Controles.nome_da_acao(String(r.troca))]
	elif String(r.motivo) == "igual":
		mensagem = "Já era esse comando."
	else:
		mensagem = "%s: comando trocado." % Controles.nome_da_acao(acao)
	return true


func _recusa(motivo: String, acao: String) -> String:
	match motivo:
		"reservada":
			return "Esse comando é reservado. Aperte outro."
		"slot":
			return "%s só aceita teclas. Aperte uma tecla." % Controles.nome_da_acao(acao)
	return "Esse comando não vale. Aperte outro."


## Os glifos da ação à direita da linha: teclado e mouse, uma folga e o controle (Xbox ou PlayStation, o que estiver em uso). Se refaz sozinho quando
## o dispositivo ou um comando muda.
class LinhaGlifos:
	extends Control
	var acao := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		Glifos.ao_mudar(queue_redraw)

	func _draw() -> void:
		if acao == "":
			return
		var par: Array = Glifos.descritores_da_acao(acao)
		var jogo_tem_controle: bool = Controles.slots_da_acao(acao).has("controle")
		var conjuntos: Array = [par[0]] + ([par[1]] if jogo_tem_controle else [])
		var total := 0.0
		for c in conjuntos:
			total += _largura(c)
		total += 14.0 * (conjuntos.size() - 1)
		var x := roundf(size.x - 12.0 - total)
		var y := roundf((size.y - Glifos.ALTURA) * 0.5)
		for c in conjuntos:
			if c.is_empty():
				var f: Font = Dados.fonte_texto
				draw_string(f, Vector2(x, y + f.get_ascent(16)), "-", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Paleta.TEXTO_APAGADO)
			for i in c.size():
				x += Glifos.desenhar(self, c[i], Vector2(x, y)) + (2.0 if i < c.size() - 1 else 0.0)
			x += (8.0 if c.is_empty() else 0.0) + 14.0

	func _largura(c: Array) -> float:
		if c.is_empty():
			return 8.0
		var w := 0.0
		for i in c.size():
			w += Glifos.largura(c[i]) + (2.0 if i > 0 else 0.0)
		return w

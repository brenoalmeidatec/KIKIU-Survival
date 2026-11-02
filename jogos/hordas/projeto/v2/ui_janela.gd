extends Node
## Tamanho da interface para as telas que desenham direto na janela (título, santuário, escolha de personagem; ver v2/escala_ui.gd).
## A janela passa ao modo CANVAS_ITEMS com base 960x540 e aspecto EXPAND (sem faixas pretas): o canvas é a janela inteira dividida pelo
## fator, e o `content_scale_factor` carrega a diferença entre o fator da UI e o de encaixe do bloco. A tela (um Control) vira o bloco
## 960x540, no centro do canvas; o que é de fundo usa EscalaUi.cobrir(). Muda a janela ou a opção "tamanho_ui": refaz tudo na hora.
## Ao sair da cena devolve à janela o modo que ela tinha (a partida e o jogo v1 usam outros) e zera o estado estático da escala.
## `opcao` (opcional) fixa a opção de tamanho em vez de ler "tamanho_ui": o salão passa "encaixe", porque a sala é cena e não deve encolher.
## Uso, no _ready da tela:  add_child(UiJanela.new().montar(self))

const EscalaUi := preload("res://v2/escala_ui.gd")

var _dono: Control
var _janela: Window
var _antes := {}
var _opcao := ""


func montar(dono: Control, opcao := "") -> Node:
	_dono = dono
	_opcao = opcao
	name = "UiJanela"
	return self


func _ready() -> void:
	_janela = get_window()
	_antes = {
		"modo": _janela.content_scale_mode,
		"tam": _janela.content_scale_size,
		"aspecto": _janela.content_scale_aspect,
		"escala": _janela.content_scale_stretch,
		"fator": _janela.content_scale_factor,
	}
	_janela.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_janela.content_scale_size = Vector2i(EscalaUi.BLOCO)
	_janela.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_janela.size_changed.connect(refazer)
	Config.tamanho_ui_mudou.connect(refazer)
	refazer()


func _exit_tree() -> void:
	if _janela == null or not is_instance_valid(_janela) or not _antes.has("modo"):
		return
	if _janela.size_changed.is_connected(refazer):
		_janela.size_changed.disconnect(refazer)
	if Config.tamanho_ui_mudou.is_connected(refazer):
		Config.tamanho_ui_mudou.disconnect(refazer)
	_janela.content_scale_mode = _antes.modo
	_janela.content_scale_size = _antes.tam
	_janela.content_scale_aspect = _antes.aspecto
	_janela.content_scale_stretch = _antes.escala
	_janela.content_scale_factor = _antes.fator
	EscalaUi.fator_atual = 1.0
	EscalaUi.canvas_atual = EscalaUi.BLOCO
	EscalaUi.desloc_atual = Vector2.ZERO


## Refaz fator, factor da janela, posição do bloco e fundos.
func refazer() -> void:
	if _janela == null or _dono == null or not is_instance_valid(_dono):
		return
	var f := EscalaUi.atualizar(_janela, _opcao)
	var j := EscalaUi.janela_px(_janela)
	_janela.content_scale_factor = f / minf(j.x / EscalaUi.LARG, j.y / EscalaUi.ALT)
	_dono.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_dono.size = EscalaUi.BLOCO
	_dono.position = EscalaUi.desloc_atual
	if is_inside_tree():
		for c in get_tree().get_nodes_in_group("ui_cobrir"):
			EscalaUi.cobrir(c)
		Transicoes.reencaixar_ui(EscalaUi.canvas_atual, EscalaUi.desloc_atual)

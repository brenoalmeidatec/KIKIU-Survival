extends Control
## Slot Q da faixa Brasas. Mostra carga, ícone, tecla e estado de uso; a carga pronta permanece acesa sem pulsar.
## O estado vem do nó irmão Habilidades. O slot redesenha só quando o estado ou o dispositivo muda.

const Paleta := preload("res://v2/paleta.gd")
const Glifos := preload("res://v2/glifos.gd")
const Slots := preload("res://v2/hud_habilidades.gd")
const TAM := Slots.TAM_CARD
const ESCALA_ICONE := Slots.ESCALA_ICONE
const ICONE := "ultimate_q"  # o ícone genérico, só para herói sem arte própria
const PASTA_ICONES := "res://assets/v2/especial_q/"  # o ícone do Q de cada herói, 32x32 (gerar_objetos.py especial_q), desenhado em 2x, pelo nome da chave dele
const FUNDO := Color(Paleta.PAINEL, 0.92)
const TRILHO := Color(Paleta.HABILIDADE_FUNDO, 0.95)

var _slots = null  # o nó irmão "Habilidades"
var _chave := ""
var _icone: Texture2D = null  # o ícone do Q do herói (ver _arte)
var _icone_chave := "#"  # nenhuma chave de herói é "#": força o primeiro carregamento


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = TAM
	process_priority = 101  # depois de "Habilidades" (100): lê o estado do mesmo quadro
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_mask = 0
	Glifos.ao_mudar(queue_redraw)  # o selo da tecla segue o dispositivo em uso (Q no teclado, RB no controle)
	_slots = get_parent().get_node_or_null("Habilidades")


func _process(_delta: float) -> void:
	if _slots == null or not is_instance_valid(_slots):
		return
	var chave: String = _slots.q_chave()
	if chave != _chave:
		_chave = chave
		queue_redraw()


func _draw() -> void:
	if _slots == null:
		return
	var fonte := get_theme_font("font")
	var tem: bool = _slots.q_implementada
	var pronta: bool = tem and (_slots.q_pronta or _slots.q_ativa)
	var f := clampf(float(_slots.q_carga_pct) / 100.0, 0.0, 1.0) if tem else 0.0
	var cor := Paleta.XP if tem else Paleta.HABILIDADE_DESATIVADA
	if tem and _slots.q_negada:
		cor = Paleta.PERIGO
	draw_rect(Rect2(Vector2.ZERO, TAM), FUNDO)
	draw_rect(Rect2(Vector2.ZERO, TAM), Slots.FILETE, false, 1.0)
	var barra := Rect2(1.0, TAM.y - 2.0, TAM.x - 2.0, 2.0)
	draw_rect(barra, TRILHO)
	if f > 0.0:
		barra.size.x = roundf(barra.size.x * f)
		draw_rect(barra, cor)
	var arte := _arte() if tem else null
	if arte != null:
		var lado := arte.get_size() * float(ESCALA_ICONE)
		var pos := Vector2((TAM.x - lado.x) * 0.5, Slots.TOPO_ICONE + (Slots.TAM_ICON.y - lado.y) * 0.5).round()
		draw_texture_rect(arte, Rect2(pos, lado), false, Color(1.0, 1.0, 1.0, 1.0 if pronta else 0.65))
	var rotulo := "%d%%" % _slots.q_carga_pct
	if not tem:
		rotulo = "INDISP."
	elif _slots.q_ativa:
		rotulo = "EM USO"
	elif pronta:
		rotulo = "PRONTA"
	draw_string(fonte, Vector2(0.0, Slots.BASE_ROTULO), rotulo, HORIZONTAL_ALIGNMENT_CENTER, TAM.x, Paleta.NUMERO_PEQUENO, cor)
	Glifos.desenhar_selo(self, "ultimate", TAM.x * 0.5, TAM.y - Glifos.ALTURA_SELO, cor, tem and pronta, Paleta.HABILIDADE_DESATIVADA)


## O ícone do Q do herói da partida (assets/v2/especial_q/<chave>.png), com o genérico de reserva. Guardado numa variável: o `load` solto devolve outra
## textura a cada redesenho (o cache não segura o que ninguém usa) e a textura nova ainda não subiu para a placa de vídeo, então saía um quadrado branco.
func _arte() -> Texture2D:
	var chave := str(_slots.q_heroi)
	if chave != _icone_chave or _icone == null:
		_icone_chave = chave
		var caminho := PASTA_ICONES + chave + ".png"
		_icone = load(caminho) as Texture2D if chave != "" and ResourceLoader.exists(caminho) else Dados.icone_carta(ICONE)
	return _icone

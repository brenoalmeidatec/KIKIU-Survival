extends CanvasLayer
## HUD da v2 (primeira leva): vida, fôlego, XP com selo de nível, tempo, abates, monstros vivos, combo e o brilho do nível novo.
## Fica numa CanvasLayer (layer 10) dentro da SubViewport 960x540 do mundo: pixel art na mesma resolução do mundo (o sharp bilinear
## escala junto), fonte PressStart2P sem anti-aliasing e sem hinting, e light_mask 0 para a luz do mundo não tocar nele.
## Lê o mundo com get() e valor padrão: sem combate mostra vida cheia, XP 0 e nível 1. Campos lidos: em mundo.heroi, vida, vida_max,
## xp, xp_proximo, nivel, folego, folego_max; em mundo, abates, combo, tempo_partida (segundos), monstros_vivos e o sinal
## nivel_subiu(nivel), conectado só se o mundo tiver o sinal. Uso no mundo (uma linha no _ready):
##   sv.add_child(preload("res://v2/hud.gd").criar(self))
## Layout em v2/hud.tscn (coordenadas de 960x540). O canto superior direito fica livre para o minimapa.

const CENA := "res://v2/hud.tscn"
const FONTE := "res://assets/fonte/PressStart2P.ttf"
const OURO := Color(0.945, 0.694, 0.055)  # #f1b10e, o destaque da paleta
const PULSO_T := 0.25  # segundos do pulso do combo a cada abate
const BRILHO_T := 1.2  # segundos do brilho da barra de XP ao subir de nível
const SALTO_PX := 4  # quantos pixels o combo sobe no pulso
const BRILHO_XP := Color(1.7, 1.5, 0.9)  # multiplicador de cor no pico do brilho: a barra e o selo clareiam para o dourado

## O mundo lido (o da v2, ou um falso nos testes). Pode ser null: aí o HUD mostra os valores padrão.
var mundo = null
## Segundos que faltam no pulso do combo e no brilho do XP. Públicos para os testes.
var pulso := 0.0
var brilho := 0.0

var _abates_antes := 0
var _combo_antes := 0
var _combo_x := 0.0
var _combo_y := 0.0

@onready var _vida_barra: TextureProgressBar = $Raiz/Vida/Barra
@onready var _vida_txt: Label = $Raiz/Vida/Texto
@onready var _folego: TextureProgressBar = $Raiz/Folego
@onready var _relogio: Label = $Raiz/Tempo/Relogio
@onready var _abates: Label = $Raiz/Abates/Linhas
@onready var _combo: Control = $Raiz/Combo
@onready var _combo_num: Label = $Raiz/Combo/Numero
@onready var _xp_barra: TextureProgressBar = $Raiz/Xp/Barra
@onready var _xp_txt: Label = $Raiz/Xp/Texto
@onready var _selo: TextureRect = $Raiz/Selo
@onready var _selo_num: Label = $Raiz/Selo/Numero


## Cria o HUD já ligado ao mundo. É o que o mundo.gd chama (numa linha).
static func criar(m) -> Node:
	var cena = load(CENA)
	var hud = cena.instantiate()
	hud.ligar(m)
	return hud


## Liga (ou troca) o mundo lido. Conecta o sinal nivel_subiu só se o mundo tiver o sinal.
func ligar(m) -> CanvasLayer:
	_desconectar()
	mundo = m
	if mundo != null and mundo.has_signal("nivel_subiu"):
		mundo.nivel_subiu.connect(_nivel_subiu)
	return self


func _ready() -> void:
	# A fonte do jogo sem anti-aliasing e sem hinting: a cópia é só deste HUD, o import compartilhado com a v1 não muda.
	var fonte := (load(FONTE) as FontFile).duplicate() as FontFile
	fonte.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fonte.hinting = TextServer.HINTING_NONE
	fonte.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	$Raiz.add_theme_font_override("font", fonte)
	$Raiz.light_mask = 0
	for n in $Raiz.find_children("*", "CanvasItem", true, false):
		n.light_mask = 0
		if n is Control:
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_x = _combo.position.x
	_combo_y = _combo.position.y


func _exit_tree() -> void:
	_desconectar()


func _desconectar() -> void:
	if mundo != null and is_instance_valid(mundo) and mundo.has_signal("nivel_subiu"):
		if mundo.nivel_subiu.is_connected(_nivel_subiu):
			mundo.nivel_subiu.disconnect(_nivel_subiu)


func _process(delta: float) -> void:
	avancar(delta)


## Um quadro do HUD: lê o mundo e atualiza barras, textos, pulso do combo e brilho do XP. Os testes chamam isto direto.
func avancar(dt: float) -> void:
	var h = _campo(mundo, "heroi")
	var vida_max := maxf(_num(h, "vida_max", 100.0), 1.0)
	var vida := clampf(_num(h, "vida", vida_max), 0.0, vida_max)
	_vida_barra.max_value = vida_max
	_vida_barra.value = vida
	_vida_txt.text = "%d/%d" % [roundi(vida), roundi(vida_max)]
	var folego_max := maxf(_num(h, "folego_max", 100.0), 1.0)
	_folego.max_value = folego_max
	_folego.value = clampf(_num(h, "folego", folego_max), 0.0, folego_max)
	var xp_prox := maxf(_num(h, "xp_proximo", 100.0), 1.0)
	var xp := clampf(_num(h, "xp", 0.0), 0.0, xp_prox)
	_xp_barra.max_value = xp_prox
	_xp_barra.value = xp
	_xp_txt.text = "%d/%d" % [roundi(xp), roundi(xp_prox)]
	_selo_num.text = str(roundi(_num(h, "nivel", 1.0)))
	var tempo := maxf(_num(mundo, "tempo_partida", 0.0), 0.0)
	_relogio.text = "%02d:%02d" % [int(tempo) / 60, int(tempo) % 60]
	var abates := roundi(_num(mundo, "abates", 0.0))
	var combo := roundi(_num(mundo, "combo", 0.0))
	_abates.text = "ABATES %d\nVIVOS %d" % [abates, roundi(_num(mundo, "monstros_vivos", 0.0))]
	_combo.visible = combo > 0
	_combo_num.text = "x%d" % combo
	if abates > _abates_antes or combo > _combo_antes:
		pulso = PULSO_T
	_abates_antes = abates
	_combo_antes = combo
	_animar(dt)


func _animar(dt: float) -> void:
	# Pulso do combo: sobe alguns pixels e clareia para o ouro, e volta no repouso. Posição em pixel inteiro.
	pulso = maxf(pulso - dt, 0.0)
	var k := pulso / PULSO_T
	_combo.position = Vector2(_combo_x, _combo_y - roundf(SALTO_PX * k))
	_combo_num.modulate = Color.WHITE.lerp(OURO, k)
	# Brilho do XP: a barra e o selo clareiam para o dourado, piscando em degraus de 1/4 (pixel art não tem alfa suave) e apagando até zero.
	brilho = maxf(brilho - dt, 0.0)
	var f := roundf(4.0 * (brilho / BRILHO_T) * (0.5 + 0.5 * sin(brilho * 16.0))) / 4.0
	_xp_barra.modulate = Color.WHITE.lerp(BRILHO_XP, f)
	_selo.modulate = _xp_barra.modulate


func _nivel_subiu(_nivel = 0) -> void:
	brilho = BRILHO_T


## Valor de um campo do mundo ou do herói, ou null se o objeto não existe ou não tem o campo.
static func _campo(obj, nome: String) -> Variant:
	if obj == null:
		return null
	return obj.get(nome)


static func _num(obj, nome: String, padrao: float) -> float:
	var v = _campo(obj, nome)
	return padrao if v == null else float(v)

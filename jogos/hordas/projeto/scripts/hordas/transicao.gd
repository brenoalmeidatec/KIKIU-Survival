extends CanvasLayer
## Transição entre telas (#55): a tela nova aparece por trás de uma "cortina" de losangos de pixel art que
## encolhem varrendo na diagonal, o clássico dos jogos de 16 bits. É só desenho por cima: a lógica do jogo
## não espera por ela, então não segura nenhum fluxo (nem os testes).
## Uso: Transicao.revelar() logo depois de trocar de tela (main.gd faz isso sozinho quando o estado muda).

const W := 640.0
const H := 360.0
const LADO := 20.0           # tamanho de cada losango
const DUR := 0.42            # segundos até a tela ficar toda à mostra
const ATRASO := 0.55         # fração da duração gasta no atraso da varredura (o resto é o encolher de cada losango)
const COR := Color(0.03, 0.025, 0.05)

var _t := DUR
var ligada := true          # os prints de teste (--print_tela) desligam: a foto é da tela, não da cortina
var _tela := Control.new()


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


func revelar() -> void:
	if not ligada:
		return
	_t = 0.0
	_tela.queue_redraw()


func ativa() -> bool:
	return _t < DUR


func _process(dt: float) -> void:
	if _t >= DUR:
		return
	_t += minf(dt / maxf(Engine.time_scale, 0.01), 1.0 / 30.0)   # tempo real: não acelera com --rapido nem trava no hitstop
	_tela.queue_redraw()


func _desenhar() -> void:
	if _t >= DUR:
		return
	var p := _t / DUR
	var colunas := int(W / LADO) + 2
	var linhas := int(H / LADO) + 2
	for ly in linhas:
		for cx in colunas:
			# varre da esquerda-de-cima pra direita-de-baixo
			var ordem := float(cx + ly) / float(colunas + linhas)
			var f := clampf((p - ordem * ATRASO) / (1.0 - ATRASO), 0.0, 1.0)
			var r := LADO * (1.0 - f)
			if r <= 0.5:
				continue
			var c := Vector2(cx * LADO, ly * LADO)
			_tela.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), COR)

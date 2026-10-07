extends CanvasLayer
## Transição entre telas (#55): a tela nova aparece por trás de uma "cortina" de losangos de pixel art que
## encolhem varrendo na diagonal, o clássico dos jogos de 16 bits. É só desenho por cima: a lógica do jogo
## não espera por ela, então não segura nenhum fluxo (nem os testes).
## Uso: Transicao.revelar() logo depois de trocar de tela (main.gd faz isso sozinho quando o estado muda).
## A duração é em TEMPO REAL (relógio da máquina): num PC que roda a 15 quadros por segundo a cortina dura o mesmo que a 60,
## só com menos quadros. O relógio começa no primeiro quadro desenhado depois da troca, então um quadro longo (tela pesada
## carregando) não engole a animação.

const W := 640.0
const H := 360.0
const LADO := 20.0           # tamanho de cada losango
const DUR := 0.42            # segundos até a tela ficar toda à mostra
const ATRASO := 0.55         # fração da duração gasta no atraso da varredura (o resto é o encolher de cada losango)
const COR := Color(0.03, 0.025, 0.05)

var _t := DUR
var _t0 := -1                # Time.get_ticks_usec() do primeiro quadro com a cortina; -1 = ainda não desenhou nenhum
var ligada := true          # os prints de teste (--print_tela) desligam: a foto é da tela, não da cortina
var ultimo_us := 0           # custo do último _desenhar (teste/medição)
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
	_t0 = -1
	_tela.queue_redraw()


func ativa() -> bool:
	return _t < DUR


func _process(_dt: float) -> void:
	if _t >= DUR:
		return
	var agora := Time.get_ticks_usec()
	if _t0 < 0:
		_t0 = agora   # este é o primeiro quadro depois da troca: a cortina começa cheia nele
	else:
		_t = (agora - _t0) / 1.0e6
	_tela.queue_redraw()


func _desenhar() -> void:
	if _t >= DUR:
		return
	var ini := Time.get_ticks_usec()
	var p := _t / DUR
	var colunas := int(W / LADO) + 2
	var linhas := int(H / LADO) + 2
	# Todos os losangos entram num único comando de desenho (uma lista de triângulos), em vez de 600+ polígonos soltos:
	# no PC fraco o que pesava era o número de comandos por quadro.
	var pts := PackedVector2Array()
	var idx := PackedInt32Array()
	var k := 0
	var passo := 1.0 / float(colunas + linhas)
	var feitas := int(floorf((p - (1.0 - ATRASO)) / (passo * ATRASO)))   # diagonais (cx + ly) já varridas: nem entram na conta
	for ly in linhas:
		for cx in range(maxi(0, feitas + 1 - ly), colunas):
			# varre da esquerda-de-cima pra direita-de-baixo
			var f := (p - float(cx + ly) * passo * ATRASO) / (1.0 - ATRASO)
			var r := LADO * (1.0 - maxf(f, 0.0))
			if r <= 0.5:
				continue
			var x := cx * LADO
			var y := ly * LADO
			pts.append(Vector2(x, y - r))
			pts.append(Vector2(x + r, y))
			pts.append(Vector2(x, y + r))
			pts.append(Vector2(x - r, y))
			idx.append_array([k, k + 1, k + 2, k, k + 2, k + 3])
			k += 4
	if k > 0:
		RenderingServer.canvas_item_add_triangle_array(_tela.get_canvas_item(), idx, pts, PackedColorArray([COR]))
	ultimo_us = Time.get_ticks_usec() - ini

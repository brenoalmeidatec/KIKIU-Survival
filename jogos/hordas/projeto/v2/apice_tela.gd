extends CanvasLayer
## Varredura genérica do ÁPICE (CAR-6a). Nós e conexões nascem uma vez por mundo; iniciar só troca o estado.
## O anel acompanha o canvas do mundo. A luz de tela cobre o canvas da UI, inclusive fora do bloco 960x540.
## Sem shader, texturas, tweens ou vetores novos durante a animação. O relógio é o real de combate.efeitos.

const Piscadas := preload("res://v2/piscadas.gd")

var mundo
var disparos := 0
var ativo := false
var simples := false
var raio_final := 0.0
var raio_atual := 0.0
var duracao := 0.0
var vinheta_alfa := 0.0
var clarao_alfa := 0.0
var cobertura := Rect2()
var anel: Node2D
var tela: Node2D

var _tempo := 0.0
var _cor := Color.WHITE
var _ouro := Color.WHITE
var _alfa_anel := 0.0
var _espessura := 0.0
var _borda := 0.0
var _segmentos := 0
var _faixas := 0
var _largura_vinheta := 0.0
var _mistura_ouro := 0.0
var _max_anel := 0.0
var _max_vinheta := 0.0
var _max_clarao := 0.0


func montar(m) -> void:
	mundo = m
	layer = -1  # a luz cobre o mundo, sem encobrir a leitura do HUD
	m.ui.add_child(self)
	add_to_group("ui_escala")
	anel = Node2D.new()
	anel.name = "AnelApice"
	anel.draw.connect(_desenhar_anel)
	m.glow.add_child(anel)
	tela = Node2D.new()
	tela.name = "TelaApice"
	tela.draw.connect(_desenhar_tela)
	add_child(tela)
	ui_reencaixar(m.ap.canvas, m.ap.desloc)
	limpar()


## camera é o retângulo visível em coordenadas do mundo; a diagonal conserva folga mesmo com o herói fora do centro.
func iniciar(centro: Vector2, camera: Rect2, cor_bonus: Color, cor_ouro: Color, cfg: Dictionary, somente_anel: bool) -> void:
	disparos += 1
	_tempo = 0.0
	duracao = float(cfg.duracao)
	raio_final = camera.size.length() + float(cfg.margem)
	raio_atual = 0.0
	_cor = cor_bonus
	_ouro = cor_ouro
	_espessura = float(cfg.espessura_anel)
	_borda = float(cfg.espessura_borda)
	_segmentos = int(cfg.segmentos_anel)
	_faixas = int(cfg.vinheta_faixas)
	_largura_vinheta = float(cfg.vinheta_largura)
	_mistura_ouro = float(cfg.mistura_dourado)
	_max_anel = float(cfg.alfa_anel)
	_max_vinheta = float(cfg.alfa_vinheta)
	_max_clarao = float(cfg.alfa_clarao)
	simples = somente_anel or _restrito()
	ativo = duracao > 0.0
	visible = ativo
	anel.position = centro
	anel.visible = ativo
	tela.visible = ativo and not simples
	_alfa_anel = _max_anel
	vinheta_alfa = 0.0
	clarao_alfa = 0.0
	anel.queue_redraw()
	tela.queue_redraw()


## Desliga a luz imediatamente se a opção mudar durante a varredura; só volta na próxima ativação.
func atualizar(dt: float) -> void:
	if not ativo:
		return
	_tempo += maxf(dt, 0.0)
	if _tempo >= duracao:
		_esconder()
		return
	simples = simples or _restrito()
	var p := _tempo / duracao
	raio_atual = raio_final * p
	_alfa_anel = _max_anel * (1.0 - p)
	var pulso := sin(PI * p) * _intensidade() if not simples else 0.0
	vinheta_alfa = _max_vinheta * pulso
	clarao_alfa = _max_clarao * pulso
	tela.visible = not simples
	anel.queue_redraw()
	if tela.visible:
		tela.queue_redraw()


func ui_reencaixar(canvas: Vector2, desloc: Vector2) -> void:
	cobertura = Rect2(-desloc, canvas)
	if tela != null and ativo:
		tela.queue_redraw()


func limpar() -> void:
	disparos = 0
	_esconder()


func _esconder() -> void:
	ativo = false
	visible = false
	vinheta_alfa = 0.0
	clarao_alfa = 0.0
	if anel != null:
		anel.visible = false
	if tela != null:
		tela.visible = false


func _intensidade() -> float:
	var valor = Config.g("tremor_clarao")
	return clampf(float(valor) / 100.0, 0.0, 1.0) if valor != null else 1.0


func _restrito() -> bool:
	return mundo.combate._perfil_baixo() or _intensidade() <= 0.0 or not Piscadas.clarao_permitido()


func _desenhar_anel() -> void:
	if not ativo or raio_atual <= 0.0:
		return
	var ouro := Color(_ouro, _alfa_anel)
	var cor := Color(_cor, _alfa_anel)
	anel.draw_arc(Vector2.ZERO, raio_atual, 0.0, TAU, _segmentos, ouro, _espessura + 2.0 * _borda)
	anel.draw_arc(Vector2.ZERO, raio_atual, 0.0, TAU, _segmentos, cor, _espessura)


func _desenhar_tela() -> void:
	if not ativo or simples:
		return
	if clarao_alfa > 0.0:
		tela.draw_rect(cobertura, Color(_cor, clarao_alfa))
	var largura := minf(_largura_vinheta, minf(cobertura.size.x, cobertura.size.y) / 2.0)
	if vinheta_alfa <= 0.0 or _faixas <= 0 or largura <= 0.0:
		return
	var passo := largura / _faixas
	var cor := _cor.lerp(_ouro, _mistura_ouro)
	for i in _faixas:
		cor.a = vinheta_alfa * (1.0 - float(i) / _faixas)
		var borda := passo * i
		tela.draw_rect(Rect2(cobertura.position + Vector2(borda, borda), Vector2(cobertura.size.x - 2.0 * borda, passo)), cor)
		tela.draw_rect(Rect2(cobertura.position + Vector2(borda, cobertura.size.y - borda - passo), Vector2(cobertura.size.x - 2.0 * borda, passo)), cor)
		tela.draw_rect(Rect2(cobertura.position + Vector2(borda, borda + passo), Vector2(passo, cobertura.size.y - 2.0 * (borda + passo))), cor)
		tela.draw_rect(
			Rect2(cobertura.position + Vector2(cobertura.size.x - borda - passo, borda + passo), Vector2(passo, cobertura.size.y - 2.0 * (borda + passo))), cor
		)

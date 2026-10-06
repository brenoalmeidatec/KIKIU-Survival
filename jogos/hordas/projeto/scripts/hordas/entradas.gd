extends CanvasLayer
## Entradas (#32 item 6): (a) o herói e os aliados "chegam" no começo de cada fase (o desenho fica em
## visual.gd/jogador.gd/remoto.gd; aqui só se dispara) e (b) a entrada do chefe da fase: a câmera vai
## até ele e volta, barras de cinema e uma placa com o NOME e o subtítulo (dados/inimigos.json,
## campos "nome" e "subtitulo"). Sozinho, o tempo desacelera um pouco (Engine.time_scale, restaurado
## SEMPRE, inclusive no _exit_tree da arena); no online não mexe no tempo: só o visual local.
## Tudo usa tempo REAL (ticks), então a duração não depende da câmera lenta.

const W := 640.0
const H := 360.0
const PLACA_TEMPO := 1.5     # quanto a placa fica na tela
const LENTO := 0.25          # fator do slow-motion (só sozinho)

# [quando a câmera começa a ir (s), quando termina de chegar, quando começa a voltar, quando termina de voltar, quando a placa entra]
const LINHA_SOLO := [0.0, 0.45, 1.75, 2.2, 0.35]
const LINHA_ONLINE := [0.0, 0.35, 1.3, 1.7, 0.3]

var arena: Node
var _tela := Control.new()
var _ativo := false
var _t := 0.0
var _ultimo := 0
var _linha: Array = LINHA_SOLO
var _tipo := ""
var _nome := ""
var _sub := ""
var _pos := Vector2.ZERO     # onde está o chefe (última posição conhecida)
var _tem_pos := false
var _mix := 0.0              # 0 = câmera no jogador, 1 = no chefe
var _barras := 0.0
var _bateu := false
var _ts_salvo := 1.0
var _ts_preso := false


func _ready() -> void:
	layer = 6
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


func ativo() -> bool:
	return _ativo


## Começo de fase: o herói (e os aliados que já estão na tela) chegam.
func chegada() -> void:
	arena.jogador.entrar(str(arena.heroi.get("nome", arena.heroi_id)))
	if arena.online:
		for av in arena.online.avatares.values():
			av.entrar()


## O chefe da fase apareceu: câmera até ele, placa com o nome, tremida e (só sozinho) câmera lenta.
func chefe(tipo: String) -> void:
	if arena.duelo_ativo or arena.acabou:
		return
	var d: Dictionary = Dados.json("inimigos").get(tipo, {})
	_tipo = tipo
	_nome = str(d.get("nome", tipo)).to_upper()
	_sub = str(d.get("subtitulo", ""))
	_linha = LINHA_ONLINE if arena.eh_online else LINHA_SOLO
	_t = 0.0
	_ultimo = Time.get_ticks_usec()
	_tem_pos = false
	_bateu = false
	_ativo = true
	_achar_chefe()
	Som.tocar("whoosh", 0.0, 0.7)


func _achar_chefe() -> void:
	for c in arena.chefes():
		if c.tipo == _tipo:
			_pos = c.pos + Vector2(0, -16)
			_tem_pos = true
			return


func _process(_dt: float) -> void:
	if not _ativo:
		return
	var agora := Time.get_ticks_usec()
	var dt := minf(0.1, (agora - _ultimo) / 1.0e6)   # tempo real; ao pausar (cartas) a cena congela junto
	_ultimo = agora
	_t += dt
	if not _tem_pos or _t < 0.6:
		_achar_chefe()
	var L := _linha
	if not _tem_pos:
		_mix = 0.0
	elif _t < L[1]:
		_mix = _suave(inverse_lerp(L[0], L[1], _t))
	elif _t < L[2]:
		_mix = 1.0
	else:
		_mix = 1.0 - _suave(inverse_lerp(L[2], L[3], _t))
	_barras = clampf(minf(_t / 0.3, (L[3] + 0.15 - _t) / 0.3), 0.0, 1.0)
	if not _bateu and _t >= L[4]:
		_bateu = true
		arena.tremer(5)   # respeita a opção "Tremer a tela"
		Som.tocar("tremor", 0.0, 1.0, -4)
	_tempo(_t)
	if _t >= L[3] + 0.2 or arena.acabou:
		_ativo = false
		_mix = 0.0
		restaurar_tempo()
	_tela.queue_redraw()


## Câmera lenta só sozinho: segura em LENTO e volta pra velocidade de antes até o fim da placa.
func _tempo(t: float) -> void:
	if arena.eh_online:
		return
	if not _ts_preso:
		_ts_salvo = Engine.time_scale
		_ts_preso = true
	var f := 1.0
	if t < 1.1:
		f = LENTO
	elif t < 1.7:
		f = lerpf(LENTO, 1.0, _suave((t - 1.1) / 0.6))
	Engine.time_scale = _ts_salvo * f


## Devolve o tempo ao normal. Chamado no fim da entrada e no _exit_tree da arena.
func restaurar_tempo() -> void:
	if _ts_preso:
		Engine.time_scale = _ts_salvo
		_ts_preso = false


static func _suave(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Onde a câmera deve ficar: no foco normal ou a caminho do chefe.
func camera(foco: Vector2) -> Vector2:
	return foco.lerp(_pos, _mix) if _ativo and _mix > 0.0 else foco


func _txt(p: Vector2, s: String, tam: int, cor: Color, larg: float) -> void:
	var f: Font = Dados.fonte
	_tela.draw_string(f, p + Vector2(tam / 8 + 1, tam / 8 + 1), s, HORIZONTAL_ALIGNMENT_CENTER, larg, tam, Color(0, 0, 0, cor.a * 0.9))
	_tela.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_CENTER, larg, tam, cor)


func _desenhar() -> void:
	if not _ativo:
		return
	var b := 34.0 * _suave(_barras)
	_tela.draw_rect(Rect2(0, 0, W, b), Color(0, 0, 0, 0.92))
	_tela.draw_rect(Rect2(0, H - b, W, b), Color(0, 0, 0, 0.92))
	var inicio: float = _linha[4]
	var fim := inicio + PLACA_TEMPO
	if _t < inicio or _t > fim + 0.25:
		return
	var entra := _suave((_t - inicio) / 0.22)
	var sai := 1.0 - _suave((_t - fim) / 0.25)
	var a := entra * sai
	var y := 150.0
	_tela.draw_rect(Rect2(0, y, W, 66), Color(0.05, 0.0, 0.05, 0.78 * a))
	_tela.draw_rect(Rect2(0, y, W, 2), Color(0.9, 0.25, 0.3, a))
	_tela.draw_rect(Rect2(0, y + 64, W, 2), Color(0.9, 0.25, 0.3, a))
	var dx := (1.0 - entra) * -70.0
	_txt(Vector2(dx, y + 14), "CHEFE", 8, Color(1, 0.55, 0.5, a), W)
	var tam := 24 if _nome.length() * 24 < 600 else 16
	_txt(Vector2(dx, y + 42), _nome, tam, Color(1, 0.9, 0.5, a), W)
	if _sub != "":
		_txt(Vector2(-dx, y + 58), _sub, 8, Color(0.85, 0.85, 0.95, a), W)

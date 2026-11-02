extends Control
## A conquista em andamento, no canto de cima à esquerda da HUD (UI-5, pedido 6 do Alisson; decisão D13). Mostra o nome, o progresso e
## uma barra. A escolha é feita uma vez e fica TRAVADA até a conquista ser cumprida: o jogo não troca de conquista no meio da partida.
## Quando cumpre, mostra CUMPRIDA, o nome e o prêmio por 2,6 s (sem piscar); depois disso escolhe a próxima, se houver.
## O estado do save (Meta.estado()) é lido UMA vez por partida, na primeira quadro. Depois, o progresso vem da partida viva e as
## conquistas cumpridas chegam por `cumprir` (resultado_meta.gd, que já gravou no save). A HUD não grava nada.
## Quem anda é hud.gd (avancar), como o resto da HUD: a conquista não tem _process próprio.

const Meta := preload("res://v2/meta.gd")
const Conquistas := preload("res://v2/conquistas.gd")
const Paleta := preload("res://v2/paleta.gd")

const PERIODO := 0.25  # s entre as atualizações do texto e da barra (contador, não por quadro)
const TEMPO_CUMPRIDA := 2.6  # s que o selo CUMPRIDA fica no topo
const LARG := 268.0  # a caixa da conquista (hud.tscn, Raiz/Conquista): 6 a 274 x 6 a 46 no canvas
const ALT := 40.0
const MARGEM := 8.0
const ESPACO := 8.0  # entre o nome e o texto da direita
const BARRA_Y := 26.0
const BARRA_ALT := 8.0
const COR_FUNDO := Color(0.0, 0.0, 0.0, 0.7)
const COR_PROGRESSO := Color("#cca8ff")  # a alma (Paleta.ALMA): a barra da conquista em andamento
const COR_CUMPRIDA := Paleta.OURO

var mundo = null
var _estado := {}
var _lida := false
var _travada := ""  # id da conquista em andamento; "" enquanto não há uma escolhida
var _t := 0.0  # contagem até a próxima atualização
var _cumprida_t := 0.0  # > 0 enquanto o selo CUMPRIDA está no topo
var _caixa: Panel
var _nome: Label
var _progresso: Label
var _barra_fundo: ColorRect
var _barra: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(LARG, ALT)
	_caixa = Panel.new()
	_caixa.size = size
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.border_color = Paleta.BORDA
	estilo.set_border_width_all(2)
	_caixa.add_theme_stylebox_override("panel", estilo)
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caixa)
	_nome = _rotulo(Rect2(MARGEM, 3.0, LARG - 2.0 * MARGEM - 70.0, 20.0), HORIZONTAL_ALIGNMENT_LEFT)
	_progresso = _rotulo(Rect2(LARG - MARGEM - 70.0, 3.0, 70.0, 20.0), HORIZONTAL_ALIGNMENT_RIGHT)
	_barra_fundo = ColorRect.new()
	_barra_fundo.position = Vector2(MARGEM, BARRA_Y)
	_barra_fundo.size = Vector2(LARG - 2.0 * MARGEM, BARRA_ALT)
	_barra_fundo.color = Paleta.PAINEL
	_barra_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_barra_fundo)
	_barra = ColorRect.new()
	_barra.position = _barra_fundo.position
	_barra.size = Vector2(0.0, BARRA_ALT)
	_barra.color = COR_PROGRESSO
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_barra)
	visible = false


func _rotulo(r: Rect2, alin: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = alin
	l.clip_text = true
	l.add_theme_font_size_override("font_size", Paleta.TEXTO_TAMANHO)
	l.add_theme_color_override("font_color", Paleta.TEXTO)
	l.add_theme_color_override("font_outline_color", Paleta.PRETO)
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## Liga a partida (ou troca): zera a escolha e espera a primeira leitura. Sem mundo (testes), a conquista fica escondida.
func ligar(m) -> void:
	mundo = m
	_lida = false
	_travada = ""
	_t = 0.0
	_cumprida_t = 0.0
	visible = false


## Um quadro da conquista (chamado por hud.gd no avancar). Sem partida, não faz nada.
func avancar(dt: float) -> void:
	if mundo == null:
		visible = false
		return
	if not _lida:
		_estado = Meta.estado()  # a única leitura do save nesta partida
		_lida = true
	if _cumprida_t > 0.0:
		_cumprida_t -= dt
		if _cumprida_t > 0.0:
			return
		_cumprida_t = 0.0
		_t = 0.0  # o selo saiu: já atualiza a conquista seguinte
	_t -= dt
	if _t > 0.0:
		return
	_t = PERIODO
	_atualizar()


## Atualiza o texto e a barra da conquista travada. Se ainda não há nenhuma, escolhe a de maior fração que a partida pode cumprir.
func _atualizar() -> void:
	var vivo := _vivo()
	var ls: Array = Conquistas.linhas(vivo, _estado)
	if _travada == "":
		_travada = str(Conquistas.escolher(ls, str(vivo.get("heroi", ""))).get("id", ""))
	var linha: Dictionary = Conquistas.linha_da_id(ls, _travada) if _travada != "" else {}
	if linha.is_empty():
		visible = false
		return
	visible = true
	_linha_de_cima(str(linha.nome), [str(linha.progresso), str(linha.contagem)])
	_nome.add_theme_color_override("font_color", Paleta.TEXTO)
	_barra.color = COR_PROGRESSO
	_barra.size.x = (LARG - 2.0 * MARGEM) * clampf(float(linha.frac), 0.0, 1.0)


## Chamado por resultado_meta.gd quando a partida cumpre conquistas (ao vivo: a gravação já foi feita). Mostra CUMPRIDA por 2,6 s.
## Se a travada é uma delas, ela sai; a próxima entra quando o selo sair. As outras só aparecem no selo.
func cumprir(ids: Array) -> void:
	if ids.is_empty():
		return
	if not _lida:
		_estado = Meta.estado()
		_lida = true
	for id in ids:
		_estado.conquistas[str(id)] = true
	if ids.has(_travada):
		_travada = ""
	var c := _catalogo(str(ids[0]))
	if c.is_empty():
		return
	var extra := " +%d" % (ids.size() - 1) if ids.size() > 1 else ""
	visible = true
	_linha_de_cima("CUMPRIDA: " + str(c.nome) + extra, [Conquistas.premio(c), ""])
	_nome.add_theme_color_override("font_color", COR_CUMPRIDA)
	_barra.color = COR_CUMPRIDA
	_barra.size.x = LARG - 2.0 * MARGEM
	_cumprida_t = TEMPO_CUMPRIDA


## Nome à esquerda e, à direita, a primeira opção que cabe inteira junto com ele (senão a última). O texto da direita ganha a largura
## que precisa e o nome fica com o resto: com 70 px fixos e 16 px por letra, "1/15 nível" saía cortado pela esquerda ("ıível").
func _linha_de_cima(nome: String, opcoes: Array) -> void:
	_nome.text = nome
	var util := LARG - 2.0 * MARGEM
	var direita := str(opcoes[-1])
	for o in opcoes:
		if _largura(nome) + ESPACO + _largura(str(o)) <= util:
			direita = str(o)
			break
	var w := minf(_largura(direita), util)
	_progresso.text = direita
	_progresso.position.x = LARG - MARGEM - w
	_progresso.size.x = w
	_nome.size.x = maxf(util - w - (ESPACO if w > 0.0 else 0.0), 0.0)


func _largura(t: String) -> float:
	return ceilf(_nome.get_theme_font("font").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, _nome.get_theme_font_size("font_size")).x)


## A partida viva para a conta de progresso, a mesma de Meta.vivo_da_partida (herói, abates, nível, evoluções, tempo e combo). Lê com get:
## os mundos falsos dos testes não têm todos os campos, e um acesso por ponto a um campo ausente vira SCRIPT ERROR.
func _vivo() -> Dictionary:
	var h = mundo.get("heroi")
	var c = mundo.get("combate")
	var cartas = c.get("cartas") if c != null else null
	var heroi = c.get("heroi_id") if c != null else null
	var nivel = h.get("nivel") if h != null else null
	var evolucoes = cartas.get("evolucoes_feitas") if cartas != null else null
	var tempo = mundo.get("tempo_partida")
	return {
		"abates": _inteiro(mundo.get("abates")),
		"nivel": _inteiro(nivel) if nivel != null else 1,
		"evolucoes": _inteiro(evolucoes),
		"heroi": str(heroi) if heroi != null else "",
		"tempo": float(tempo) if tempo != null else 0.0,
		"combo": _inteiro(mundo.get("maior_combo")),
	}


static func _inteiro(v) -> int:
	return int(v) if v != null else 0


func _catalogo(id: String) -> Dictionary:
	for c in Meta.conquistas():
		if str(c.id) == id:
			return c
	return {}

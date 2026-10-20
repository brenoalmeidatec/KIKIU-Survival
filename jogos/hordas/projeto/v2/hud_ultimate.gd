extends Control
## A ULTIMATE (Q) do HUD da v2, no estilo Overwatch: um CÍRCULO no centro de baixo, logo acima da barra de XP. Um anel de ouro mede a carga (sobe do topo,
## no sentido horário); dentro, a % da carga em números enquanto enche, e o ícone do especial aceso quando chega a 100%, com o anel e o fundo pulsando
## na cor do herói até apertar o Q (ou RB no controle). Em andamento mantém o pulso; o aperto negado (sem a carga cheia) pinta o anel de vermelho.
## O estado vem do nó irmão "Habilidades" (v2/hud_habilidades.gd), que lê os campos esp_* do herói; este nó só DESENHA. Sem os campos (herói sem especial,
## mundo falso dos testes) o círculo fica apagado com "EM BREVE" e nunca indica uma ultimate pronta que não existe. Desenhado por código, num Control só,
## redesenhado só quando a chave de estado muda (ou a cada quadro enquanto pronto, em andamento ou negado, que pulsam).

const Paleta := preload("res://v2/paleta.gd")
const Glifos := preload("res://v2/glifos.gd")
const EstiloPremium := preload("res://v2/estilo_premium.gd")
const DIAMETRO := 64.0  # o nó inteiro: o círculo (60) e, embaixo, a tecla Q por cima da borda
const RAIO_FUNDO := 29.0
const RAIO_ANEL := 26.5  # o centro do anel de carga
const LARG_ANEL := 4.0
const PONTOS := 72  # segmentos do arco: o círculo fica liso sem custar nada (um desenho só quando muda)
const TAM_PORCENTO := 14
const TAM_VAZIO := 10
const ICONE := "ultimate_q"  # o ícone genérico, só para herói sem arte própria
const PASTA_ICONES := "res://assets/v2/especial_q/"  # o ícone do Q de cada herói, 32x32 (gerar_objetos.py especial_q), pelo nome da chave dele
const FUNDO := Color(Paleta.PAINEL, 0.92)
const TRILHO := Color(Paleta.HABILIDADE_FUNDO, 0.95)

var _slots = null  # o nó irmão "Habilidades"
var _chave := ""
var _icone: Texture2D = null  # o ícone do Q do herói (ver _arte)
var _icone_chave := "#"  # nenhuma chave de herói é "#": força o primeiro carregamento


func _ready() -> void:
	size = Vector2(DIAMETRO, DIAMETRO)
	process_priority = 101  # depois de "Habilidades" (100): lê o estado do mesmo quadro
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_mask = 0
	Glifos.ao_mudar(queue_redraw)  # o selo da tecla segue o dispositivo em uso (Q no teclado, RB no controle)
	_slots = get_parent().get_node_or_null("Habilidades")


func _process(_delta: float) -> void:
	if _slots == null or not is_instance_valid(_slots):
		return
	var chave: String = _slots.q_chave()
	var pulsa: bool = _slots.q_implementada and (_slots.q_pronta or _slots.q_ativa or _slots.q_negada)
	if pulsa or chave != _chave:
		_chave = chave
		queue_redraw()


func _draw() -> void:
	if _slots == null:
		return
	var fonte := get_theme_font("font")
	var c := Vector2(DIAMETRO, DIAMETRO) * 0.5 - Vector2(0.0, 2.0)  # o círculo sobe 2 px: a tecla fica na borda de baixo do nó
	var tem: bool = _slots.q_implementada
	var pronta: bool = tem and (_slots.q_pronta or _slots.q_ativa)
	var f := clampf(float(_slots.q_carga_pct) / 100.0, 0.0, 1.0) if tem else 0.0
	var cor_heroi: Color = _slots.q_cor if tem else Paleta.HABILIDADE_DESATIVADA
	var pulso := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * TAU * 2.0)
	var cor: Color = cor_heroi
	if tem and _slots.q_negada:
		cor = Paleta.PERIGO
	elif pronta:
		cor = cor_heroi.lerp(Paleta.BRANCO, 0.45 * pulso)
	# o halo de quando está pronta: um círculo suave atrás que respira
	if pronta:
		draw_circle(c, RAIO_FUNDO + 3.0, Color(cor_heroi, 0.12 + 0.2 * pulso), true, -1.0, true)
	draw_circle(c, RAIO_FUNDO, FUNDO, true, -1.0, true)
	if pronta:  # cheia (100%): um aro de luz por fora e o miolo tingido; nunca mais apagado do que a 99%
		draw_arc(c, RAIO_FUNDO + 1.5, 0.0, TAU, PONTOS, Color(cor_heroi.lerp(Paleta.BRANCO, 0.5), 0.35 + 0.55 * pulso), 2.0, true)
		draw_circle(c, RAIO_ANEL - LARG_ANEL * 0.5, Color(cor_heroi, 0.14 + 0.18 * pulso), true, -1.0, true)
	draw_arc(c, RAIO_ANEL, 0.0, TAU, PONTOS, TRILHO, LARG_ANEL, true)
	if f > 0.0:
		draw_arc(c, RAIO_ANEL, -PI * 0.5, -PI * 0.5 + TAU * f, PONTOS, cor if tem else Paleta.HABILIDADE_DESATIVADA, LARG_ANEL, true)
	draw_arc(c, RAIO_FUNDO, 0.0, TAU, PONTOS, Color(EstiloPremium.OURO, 0.9 if pronta else 0.45), 1.5, true)  # o filete dourado do visual premium
	draw_arc(c, RAIO_ANEL - LARG_ANEL * 0.5 - 1.0, 0.0, TAU, PONTOS, Color(Paleta.PRETO, 0.5), 1.0, true)
	var arte := _arte()
	if arte != null and tem:
		var alfa := 1.0 if pronta else 0.32
		var tinta := cor_heroi.lerp(Paleta.BRANCO, 0.35) if pronta else Paleta.HABILIDADE_DESATIVADA
		draw_texture(arte, c - arte.get_size() * 0.5, Color(tinta, alfa))
	if not tem:
		draw_string(fonte, c + Vector2(-DIAMETRO * 0.5, 4.0), "EM BREVE", HORIZONTAL_ALIGNMENT_CENTER, DIAMETRO, TAM_VAZIO, Paleta.HABILIDADE_DESATIVADA)
	elif not pronta:
		_texto_contornado(fonte, c, _slots._rotulo_q(), cor_heroi.lerp(Paleta.BRANCO, 0.35))
	# a tecla por cima da borda de baixo do círculo
	var nome_tecla := Glifos.texto("ultimate")
	var larg := maxf(16.0, 8.0 * float(nome_tecla.length()) + 8.0)
	var selo := Rect2(Vector2(c.x - larg * 0.5, DIAMETRO - 10.0), Vector2(larg, 10.0))
	var aceso := tem and (pronta or f >= 1.0)
	draw_rect(selo, Color(Paleta.PAINEL, 0.98))
	var cor_selo: Color = cor if aceso else Paleta.HABILIDADE_DESATIVADA
	_moldura(selo, cor_selo)
	draw_string(fonte, selo.position + Vector2(0.0, 9.0), nome_tecla, HORIZONTAL_ALIGNMENT_CENTER, larg, Paleta.NUMERO_PEQUENO, cor_selo)


## O ícone do Q do herói da partida (assets/v2/especial_q/<chave>.png), com o genérico de reserva. Guardado numa variável: o `load` solto devolve outra
## textura a cada redesenho (o cache não segura o que ninguém usa) e a textura nova ainda não subiu para a placa de vídeo, então saía um quadrado branco.
func _arte() -> Texture2D:
	var chave := str(_slots.q_heroi)
	if chave != _icone_chave or _icone == null:
		_icone_chave = chave
		var caminho := PASTA_ICONES + chave + ".png"
		_icone = load(caminho) as Texture2D if chave != "" and ResourceLoader.exists(caminho) else Dados.icone_carta(ICONE)
	return _icone


## O texto da % centrado no círculo, com contorno escuro para ler sobre o ícone apagado.
func _texto_contornado(fonte: Font, c: Vector2, texto: String, cor: Color) -> void:
	var tam := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_PORCENTO)
	var pos := Vector2(c.x - tam.x * 0.5, c.y + fonte.get_ascent(TAM_PORCENTO) * 0.5 - 1.0)
	draw_string_outline(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_PORCENTO, 4, Color(0.0, 0.0, 0.0, 0.9))
	draw_string(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_PORCENTO, cor)


func _moldura(r: Rect2, cor: Color) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), cor)
	draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), cor)
	draw_rect(Rect2(r.position.x, r.position.y + 1.0, 1.0, r.size.y - 2.0), cor)
	draw_rect(Rect2(r.end.x - 1.0, r.position.y + 1.0, 1.0, r.size.y - 2.0), cor)

extends Control
## Dois slots de habilidade no HUD. E lê somente os campos publicados pelo herói; Q fica explicitamente reservada.

const TAM_CARD := Vector2(86.0, 74.0)
const ESPACO_CARD := 2.0
const TAM_ICON := Vector2(48.0, 48.0)
const POSICAO := Vector2(596.0, 438.0)
const CARGA_LARANJA := Color(1.0, 0.55, 0.2)
const BORDA := Color(0.58, 0.55, 0.52)
const DESATIVADO := Color(0.32, 0.31, 0.34)
const FUNDO := Color(0.08, 0.075, 0.09, 0.92)
const FUNDO_CARD := Color(0.035, 0.035, 0.045, 0.88)

var estado_e := "indisponivel"  # indisponivel | ruptura
var e_disponivel := false
var e_pronta := false
var q_implementada := false  # Q nunca ganha disponibilidade sem uma mecânica publicada.
var carga_px := 0
var recarga_px := 0
var contragolpe_px := 0
var recarga_s := 0.0
var carga_percentual := 0
var perfeita := false
var negada := false
var _chave := ""
var _hud = null
var _cache_propriedades := {}
var _mundo_id := 0
var _heroi_id := 0


func _ready() -> void:
	position = POSICAO
	size = Vector2(TAM_CARD.x * 2.0 + ESPACO_CARD, TAM_CARD.y)
	process_priority = 100  # corre depois do HUD antigo e mantém os desenhos duplicados apagados
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_mask = 0
	_hud = get_parent().get_parent()


func _process(_delta: float) -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	# PR201 já cria os controles dos slots dinamicamente; esconde só esses dois desenhos para evitar duplicação.
	# O módulo de combate, os atributos e qualquer outra parte do HUD continuam intactos.
	_esconder_slot_anterior("_rb")
	_esconder_slot_anterior("_ult")
	visible = true
	var mundo = _campo(_hud, "mundo", null)
	var heroi = _campo(mundo, "heroi", null)
	var id_mundo := _id_instancia(mundo)
	if id_mundo != _mundo_id:
		_cache_propriedades.erase(_mundo_id)
		_mundo_id = id_mundo
	sincronizar(heroi)


## Compatível com o mundo principal (sem campos de Ruptura) e com um herói que publique os números reais da habilidade.
func sincronizar(heroi) -> void:
	# Também limpa o herói anterior quando a sincronização é chamada diretamente.
	var id_heroi := _id_instancia(heroi)
	if id_heroi != _heroi_id:
		_cache_propriedades.erase(_heroi_id)
		_heroi_id = id_heroi
	e_disponivel = _tem_propriedade(heroi, "rup_carga")
	estado_e = "ruptura" if e_disponivel else "indisponivel"
	q_implementada = false
	e_pronta = false
	carga_px = 0
	recarga_px = 0
	contragolpe_px = 0
	recarga_s = 0.0
	carga_percentual = 0
	perfeita = false
	negada = false
	if e_disponivel:
		var carga := clampf(float(heroi.get("rup_carga")), 0.0, 1.0)
		var recarga := maxf(float(_campo(heroi, "rup_recarga", 0.0)), 0.0)
		var recarga_max := maxf(float(_campo(heroi, "rup_recarga_max", 1.0)), 0.001)
		var contra := maxf(float(_campo(heroi, "contragolpe_t", 0.0)), 0.0)
		var contra_max := maxf(float(_campo(heroi, "contragolpe_max", 1.5)), 0.001)
		e_pronta = recarga <= 0.0
		carga_px = roundi(carga * 20.0)
		carga_percentual = roundi(carga * 100.0)
		recarga_s = recarga
		recarga_px = roundi(recarga / recarga_max * 20.0) if recarga > 0.0 else 0
		recarga_px = mini(recarga_px, 20)
		contragolpe_px = ceili(contra / contra_max * 20.0) if contra > 0.0 else 0
		perfeita = _campo(heroi, "rup_perfeita", false) == true
		negada = float(_campo(heroi, "rup_nega_t", 0.0)) > 0.0
	var rotulo := _rotulo_e()
	var fase_perfeita := int(Time.get_ticks_msec() / 50.0) % 2 if perfeita else 0
	var nova_chave := (
		"%s|%s|%s|%d|%d|%d|%d|%s|%s|%s|%d"
		% [estado_e, e_pronta, q_implementada, carga_px, carga_percentual, recarga_px, contragolpe_px, perfeita, negada, rotulo, fase_perfeita]
	)
	if nova_chave != _chave:
		_chave = nova_chave
		queue_redraw()


func _draw() -> void:
	var fonte := get_theme_font("font")
	_desenhar_card(Vector2.ZERO, "E", fonte)
	_desenhar_card(Vector2(TAM_CARD.x + ESPACO_CARD, 0.0), "Q", fonte)


func _desenhar_card(origem: Vector2, tecla: String, fonte: Font) -> void:
	var card := Rect2(origem, TAM_CARD)
	draw_rect(card, FUNDO_CARD)
	_moldura(card, BORDA if tecla == "E" and e_disponivel else DESATIVADO)
	var icon_pos := origem + Vector2((TAM_CARD.x - TAM_ICON.x) * 0.5, 1.0)
	var icone := Rect2(icon_pos, TAM_ICON)
	var cor := CARGA_LARANJA if tecla == "E" and e_pronta else DESATIVADO
	if tecla == "E" and not e_disponivel:
		cor = DESATIVADO
	if tecla == "E" and negada:
		cor = Color(1.0, 0.25, 0.2)
	if tecla == "E" and perfeita and int(Time.get_ticks_msec() / 50.0) % 2 == 0:
		cor = Color.WHITE
	draw_rect(icone, FUNDO)
	_moldura(icone, cor)
	if tecla == "E":
		# Duas placas de solo afastadas; o vazio ramificado central é a ruptura.
		var p := icon_pos
		var esquerda := PackedVector2Array([Vector2(6, 14), Vector2(18, 8), Vector2(21, 16), Vector2(17, 23), Vector2(21, 30), Vector2(17, 38), Vector2(6, 32)])
		var direita := PackedVector2Array(
			[Vector2(27, 8), Vector2(41, 14), Vector2(41, 32), Vector2(25, 39), Vector2(29, 29), Vector2(25, 23), Vector2(29, 16)]
		)
		for placa in [esquerda, direita]:
			for i in placa.size():
				placa[i] += p
			draw_colored_polygon(placa, Color(cor.r, cor.g, cor.b, 0.24))
			var contorno: PackedVector2Array = placa.duplicate()
			contorno.append(placa[0])
			draw_polyline(contorno, cor, 1.5)
		var fenda := PackedVector2Array([p + Vector2(24, 8), p + Vector2(26, 16), p + Vector2(21, 23), p + Vector2(26, 30), p + Vector2(22, 39)])
		draw_polyline(fenda, Color(1.0, 0.88, 0.6) if perfeita else cor, 2.5)
		draw_polyline(PackedVector2Array([p + Vector2(21, 23), p + Vector2(15, 20), p + Vector2(11, 22)]), cor, 1.5)
		draw_polyline(PackedVector2Array([p + Vector2(26, 30), p + Vector2(33, 26), p + Vector2(37, 27)]), cor, 1.5)

	else:
		# Q usa um selo apagado, sem sugerir uma habilidade pronta.
		draw_arc(icon_pos + Vector2(24.0, 23.0), 13.0, 0.0, TAU, 24, DESATIVADO, 2.0)
		draw_line(icon_pos + Vector2(17.0, 23.0), icon_pos + Vector2(31.0, 23.0), DESATIVADO, 2.0)
	if tecla == "E" and e_disponivel:
		var f := clampf(float(carga_px) / 20.0, 0.0, 1.0)
		if recarga_px > 0:
			var altura := 46.0 * clampf(float(recarga_px) / 20.0, 0.0, 1.0)
			draw_rect(Rect2(icon_pos + Vector2(1.0, 1.0), Vector2(46.0, altura)), Color(0.0, 0.0, 0.0, 0.56))
			if recarga_px < 20:
				draw_rect(Rect2(icon_pos + Vector2(1.0, 1.0 + altura), Vector2(46.0, 1.0)), Color(0.9, 0.65, 0.3, 0.95))
		elif carga_px > 0:
			draw_rect(Rect2(icon_pos + Vector2(2.0, 43.0), Vector2(44.0 * f, 3.0)), cor)
		if contragolpe_px > 0:
			draw_rect(Rect2(icon_pos + Vector2(2.0, 45.0), Vector2(44.0 * float(contragolpe_px) / 20.0, 2.0)), Color(1.0, 0.48, 0.18))
	var rotulo := "EM BREVE" if tecla == "Q" else _rotulo_e()
	draw_string(
		fonte,
		Vector2(origem.x, 63.0),
		rotulo,
		HORIZONTAL_ALIGNMENT_CENTER,
		TAM_CARD.x,
		10 if tecla == "Q" else 12,
		cor if tecla == "E" and e_disponivel else DESATIVADO
	)
	var selo := Rect2(origem + Vector2((TAM_CARD.x - 16.0) * 0.5, 64.0), Vector2(16.0, 10.0))
	draw_rect(selo, Color(0.025, 0.025, 0.03, 0.98))
	_moldura(selo, cor if tecla == "E" and e_disponivel else DESATIVADO)
	draw_string(fonte, selo.position + Vector2(4.0, 9.0), tecla, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, cor if tecla == "E" and e_disponivel else DESATIVADO)


func _rotulo_e() -> String:
	if not e_disponivel:
		return "INDISP."
	if recarga_s > 0.0:
		return "%.1f S" % recarga_s
	if carga_percentual > 0:
		return "%d%%" % carga_percentual
	return "RUPTURA"


func _moldura(retangulo: Rect2, cor: Color) -> void:
	draw_rect(Rect2(retangulo.position.x, retangulo.position.y, retangulo.size.x, 1.0), cor)
	draw_rect(Rect2(retangulo.position.x, retangulo.end.y - 1.0, retangulo.size.x, 1.0), cor)
	draw_rect(Rect2(retangulo.position.x, retangulo.position.y + 1.0, 1.0, retangulo.size.y - 2.0), cor)
	draw_rect(Rect2(retangulo.end.x - 1.0, retangulo.position.y + 1.0, 1.0, retangulo.size.y - 2.0), cor)


func _tem_propriedade(obj, nome: String) -> bool:
	if obj == null or not is_instance_valid(obj):
		return false
	var id: int = obj.get_instance_id()
	if not _cache_propriedades.has(id):
		var nomes := {}
		for propriedade in obj.get_property_list():
			nomes[str(propriedade.name)] = true
		_cache_propriedades[id] = nomes
	return _cache_propriedades[id].has(nome)


func _id_instancia(obj) -> int:
	return obj.get_instance_id() if obj != null and is_instance_valid(obj) else 0


func _campo(obj, nome: String, padrao: Variant) -> Variant:
	return obj.get(nome) if _tem_propriedade(obj, nome) else padrao


func _esconder_slot_anterior(nome: String) -> void:
	if not _tem_propriedade(_hud, nome):
		return
	var slot = _hud.get(nome)
	if slot is CanvasItem:
		# Alpha zero não interfere nos flags/estados que os testes e o combate de PR201 consultam.
		slot.modulate = Color(slot.modulate.r, slot.modulate.g, slot.modulate.b, 0.0)

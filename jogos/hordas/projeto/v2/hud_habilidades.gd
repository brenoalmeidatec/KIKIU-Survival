extends Control
## Os dois slots de habilidade do canto inferior DIREITO do HUD (estilo Overwatch): E (a habilidade do herói: a ruptura do Hazaki, a investida do Nicão, o salto
## do Lucas; v2/habilidade.gd) e o SECUNDÁRIO (botão direito ou gatilho esquerdo: o escudo, v2/escudo.gd). Também lê, no mesmo passo, o estado do Q (a ultimate
## do herói, v2/especial.gd), que é DESENHADO pelo círculo do centro (v2/hud_ultimate.gd, o nó "Ultimate"). Tudo vem somente dos campos publicados pelo herói:
## sem os campos o slot fica apagado (E e secundário "INDISP.", Q "EM BREVE") e nunca indica uma habilidade pronta que não existe. Quem tem a ruptura (hab_id
## "ruptura" ou sem hab_*) usa os rup_*; as outras E usam os hab_* (nome, ícone, cor, recarga). O escudo não tem recarga própria: ele gasta o FÔLEGO da corrida,
## então o slot do secundário acende pronto, pulsa erguido e, com o herói CANSADO (fôlego zerado), mostra a cortina de recarga até o fôlego voltar ao limite.

const Paleta := preload("res://v2/paleta.gd")
const Glifos := preload("res://v2/glifos.gd")
const TAM_CARD := Vector2(86.0, 74.0)
const ESCALA := 1.5  # decisão do Alisson: o HUD da partida é 1,5x. O nó inteiro é escalado (`scale`): o desenho e `size` ficam no espaço de 86x74 por card
const ESPACO_CARD := 2.0
const TAM_ICON := Vector2(44.0, 44.0)  # o ícone (32 px) com 6 px de folga; era 48 e encolheu para o selo da tecla caber com 16 px de altura
const CARGA_LARANJA := Paleta.CARGA_LARANJA
const COR_ESCUDO := Color(0.45, 0.82, 1.0)  # o azul do escudo (o mesmo do desenho dele no mundo, v2/escudo.gd)
const FOLEGO_MIN_PADRAO := 0.15  # fôlego mínimo para erguer o escudo e fração de volta do cansaço: lidos do cfg do combate; estes só valem sem combate
const ICONES_E := {
	"nicao": preload("res://assets/v2/habilidade_e/nicao.png"),
	"lucas": preload("res://assets/v2/habilidade_e/lucas.png"),
}
const CANSADO_ATE_PADRAO := 0.34
const BORDA := Paleta.HABILIDADE_BORDA
const DESATIVADO := Paleta.HABILIDADE_DESATIVADA
const FUNDO := Color(Paleta.CARTAO, 0.92)
const FUNDO_CARD := Color(Paleta.PAINEL, 0.88)
const MOLDURA := preload("res://v2/hud/moldura_habilidade.png")  # 9-slice da arte do Codex (#290), margem 11 (v2/hud/molduras_codex.json)
const MOLDURA_MARGEM := Vector2(11.0, 11.0)
const MOLDURA_APAGADA := Color(1.0, 1.0, 1.0, 0.75)  # slot desabilitado: a mesma moldura a 0,75 de alfa (DESIGN.md, botões)
const FOLGA_MOLDURA := 4.0  # espessura da borda de pedra: o quadro do ícone começa depois dela

var estado_e := "indisponivel"  # indisponivel | ruptura | habilidade
var e_icone := "ruptura"  # o id do ícone da E (assets/v2/icones_cartas)
var e_texto := "RUPTURA"  # o rótulo do slot E quando pronta
var e_cor := Paleta.CARGA_LARANJA  # a cor do slot E pronto
var e_ativa := false  # a E (que não é a ruptura) está em andamento
var e_disponivel := false
var e_pronta := false
var q_implementada := false  # Q só acende se o herói publica um especial real (esp_nome); sem os campos ela fica apagada.
var q_pronta := false
var q_carga_px := 0  # a carga da ultimate em 0 a 20 (a cortina que sobe no ícone)
var q_carga_pct := 0  # a carga da ultimate em % (o texto do slot)
var s_disponivel := false  # o herói publica o escudo (escudo_ativo): senão o slot do secundário fica apagado
var s_pronta := false  # pode erguer (não cansado e com o fôlego mínimo) ou já está erguido
var s_ativo := false  # o escudo está erguido
var s_recarga_px := 0  # a cortina do cansaço em 0 a 20: sobe a 20 com o fôlego zerado e desce até o fôlego voltar ao limite
var q_negada := false
var q_ativa := false  # o especial está em andamento
var q_rotulo := ""
var q_heroi := ""  # a chave do herói: o círculo do Q procura o ícone do especial dele por ela (assets/v2/especial_q/<chave>.png)
var q_cor := Color.WHITE
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
	Glifos.ao_mudar(queue_redraw)  # o selo da tecla segue o dispositivo em uso (E e botão direito no teclado, LB e LT no controle)
	scale = Vector2(ESCALA, ESCALA)  # o tamanho na tela é size * scale (261x111)
	size = Vector2(TAM_CARD.x * 2.0 + ESPACO_CARD, TAM_CARD.y)  # a posição é do hud.tscn (canto inferior direito; o HUD cola na borda do canvas)
	process_priority = 100  # corre depois do HUD; o círculo do Q (101) lê o estado que este nó acabou de sincronizar
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_mask = 0
	_hud = get_parent().get_parent()


func _process(_delta: float) -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
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
	var e_outra := _tem_propriedade(heroi, "hab_recarga") and str(_campo(heroi, "hab_id", "ruptura")) != "ruptura"
	e_disponivel = _tem_propriedade(heroi, "rup_carga") if not e_outra else str(_campo(heroi, "hab_nome", "")) != ""
	estado_e = ("habilidade" if e_outra else "ruptura") if e_disponivel else "indisponivel"
	e_icone = "ruptura"
	e_texto = "RUPTURA"
	e_cor = Paleta.CARGA_LARANJA
	e_ativa = false
	q_implementada = _tem_propriedade(heroi, "esp_carga") and str(_campo(heroi, "esp_nome", "")) != ""
	q_pronta = false
	q_carga_px = 0
	q_carga_pct = 0
	q_negada = false
	q_ativa = false
	q_rotulo = ""
	q_cor = Color.WHITE
	q_heroi = str(_campo(heroi, "chave", ""))
	if q_implementada:
		var carga := maxf(float(_campo(heroi, "esp_carga", 0.0)), 0.0)
		var carga_max := maxf(float(_campo(heroi, "esp_carga_max", 100.0)), 0.001)
		var f := clampf(carga / carga_max, 0.0, 1.0)
		q_pronta = f >= 1.0
		q_carga_pct = 100 if q_pronta else mini(floori(f * 100.0), 99)  # 99% nunca arredonda para 100: só a carga cheia mostra pronta
		q_carga_px = roundi(f * 20.0)
		q_negada = float(_campo(heroi, "esp_nega_t", 0.0)) > 0.0
		q_ativa = float(_campo(heroi, "esp_t", 0.0)) > 0.0
		q_rotulo = str(_campo(heroi, "esp_rotulo", ""))
		q_cor = _campo(heroi, "esp_cor", Color.WHITE)
	e_pronta = false
	carga_px = 0
	recarga_px = 0
	contragolpe_px = 0
	recarga_s = 0.0
	carga_percentual = 0
	perfeita = false
	negada = false
	if e_disponivel and e_outra:
		var rec_h := maxf(float(_campo(heroi, "hab_recarga", 0.0)), 0.0)
		var rec_h_max := maxf(float(_campo(heroi, "hab_recarga_max", 1.0)), 0.001)
		e_ativa = float(_campo(heroi, "hab_t", 0.0)) > 0.0
		e_icone = str(_campo(heroi, "hab_icone", "ruptura"))
		e_texto = str(_campo(heroi, "hab_rotulo", ""))
		e_cor = _campo(heroi, "hab_cor", Paleta.CARGA_LARANJA)
		e_pronta = rec_h <= 0.0 or e_ativa
		recarga_s = 0.0 if e_ativa else rec_h
		recarga_px = 0 if e_ativa or rec_h <= 0.0 else mini(ceili(rec_h / rec_h_max * 20.0), 20)
		negada = float(_campo(heroi, "hab_nega_t", 0.0)) > 0.0
	elif e_disponivel:
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
	_sincronizar_secundario(heroi)
	var rotulo := _rotulo_e()
	var fase_perfeita := int(Time.get_ticks_msec() / 50.0) % 2 if perfeita else 0
	var fase_pulso := int(Time.get_ticks_msec() / 160.0) % 2 if e_ativa or s_ativo else 0  # o quadro da E em andamento e o do escudo erguido pulsam
	var nova_chave := (
		"%s|%s|%d|%d|%d|%s|%s|%s|%d|%d|%s|%s|%s|%d|%s"
		% [
			estado_e,
			e_pronta,
			carga_px,
			carga_percentual,
			recarga_px,
			perfeita,
			negada,
			rotulo,
			fase_perfeita,
			contragolpe_px,
			e_ativa,
			e_icone,
			s_disponivel,
			s_recarga_px,
			"%s%s%d" % [s_pronta, s_ativo, fase_pulso]
		]
	)
	if nova_chave != _chave:
		_chave = nova_chave
		queue_redraw()


## O secundário (escudo): disponível se o herói publica escudo_ativo. Pronto se erguido ou se não está cansado e tem o fôlego mínimo; cansado, a cortina
## de recarga mede quanto falta para o fôlego voltar ao limite em que o cansaço acaba (cfg.folego.cansado_ate).
func _sincronizar_secundario(heroi) -> void:
	s_disponivel = _tem_propriedade(heroi, "escudo_ativo")
	s_pronta = false
	s_ativo = false
	s_recarga_px = 0
	if not s_disponivel:
		return
	s_ativo = _campo(heroi, "escudo_ativo", false) == true
	var cansado: bool = _campo(heroi, "cansado", false) == true
	var folego := maxf(float(_campo(heroi, "folego", 0.0)), 0.0)
	var folego_max := maxf(float(_campo(heroi, "folego_max", 1.0)), 0.001)
	var combate = _campo(_campo(heroi, "mundo", null), "combate", null)
	var cfg_escudo = _campo(_campo(combate, "escudo", null), "cfg", null)
	var cfg_folego = _cfg(_campo(combate, "cfg", null), "folego", null)
	var minimo := float(_cfg(cfg_escudo, "folego_min", FOLEGO_MIN_PADRAO))
	var cansado_ate := float(_cfg(cfg_folego, "cansado_ate", CANSADO_ATE_PADRAO))
	s_pronta = s_ativo or (not cansado and folego >= minimo)
	if cansado and not s_ativo:
		s_recarga_px = ceili((1.0 - clampf(folego / (folego_max * maxf(cansado_ate, 0.001)), 0.0, 1.0)) * 20.0)


func _draw() -> void:
	var fonte := get_theme_font("font")
	_desenhar_card(Vector2.ZERO, "E", fonte)
	_desenhar_card(Vector2(TAM_CARD.x + ESPACO_CARD, 0.0), "S", fonte)


## Um card: "E" (a habilidade do herói) ou "S" (o secundário, o escudo).
func _desenhar_card(origem: Vector2, tecla: String, fonte: Font) -> void:
	var e := tecla == "E"
	var card := Rect2(origem, TAM_CARD)
	draw_rect(card, FUNDO_CARD)
	_moldura_pedra(card, e_disponivel if e else s_disponivel)
	var icon_pos := origem + Vector2((TAM_CARD.x - TAM_ICON.x) * 0.5, FOLGA_MOLDURA + 1.0)
	var icone := Rect2(icon_pos, TAM_ICON)
	var pulsa := int(Time.get_ticks_msec() / 160.0) % 2 == 0
	var cor := _cor_do_card(e, pulsa)
	draw_rect(icone, FUNDO)
	_moldura(icone, cor)
	var arte: Texture2D = arte_e() if e else Dados.icone_carta("escudo")
	if arte != null:
		# o ícone próprio da carta (32x32, assets/v2/icones_cartas) no centro do quadro; apagado quando não está disponível
		var tinta := Color.WHITE if (e_disponivel if e else s_pronta) else DESATIVADO
		draw_texture(arte, icon_pos + (TAM_ICON - arte.get_size()) * 0.5, tinta)
	elif e:
		# Duas placas de solo afastadas; o vazio ramificado central é a ruptura (reserva, se o ícone faltar).
		var p := icon_pos + (TAM_ICON - Vector2(48.0, 48.0)) * 0.5  # o desenho de reserva foi feito num quadro de 48: fica centrado no atual
		var esquerda := PackedVector2Array([Vector2(6, 14), Vector2(18, 8), Vector2(21, 16), Vector2(17, 23), Vector2(21, 30), Vector2(17, 38), Vector2(6, 32)])
		var direita := PackedVector2Array(
			[Vector2(27, 8), Vector2(41, 14), Vector2(41, 32), Vector2(25, 39), Vector2(29, 29), Vector2(25, 23), Vector2(29, 16)]
		)
		for placa in [esquerda, direita]:
			for i in placa.size():
				placa[i] += p
			draw_colored_polygon(placa, Color(cor, 0.24))
			var contorno: PackedVector2Array = placa.duplicate()
			contorno.append(placa[0])
			draw_polyline(contorno, cor, 1.5)
		var fenda := PackedVector2Array([p + Vector2(24, 8), p + Vector2(26, 16), p + Vector2(21, 23), p + Vector2(26, 30), p + Vector2(22, 39)])
		draw_polyline(fenda, Paleta.CARGA_PERFEITA if perfeita else cor, 2.5)
		draw_polyline(PackedVector2Array([p + Vector2(21, 23), p + Vector2(15, 20), p + Vector2(11, 22)]), cor, 1.5)
		draw_polyline(PackedVector2Array([p + Vector2(26, 30), p + Vector2(33, 26), p + Vector2(37, 27)]), cor, 1.5)
	if e and e_disponivel:
		var f := clampf(float(carga_px) / 20.0, 0.0, 1.0)
		_cortina(icon_pos, recarga_px)
		if recarga_px <= 0 and carga_px > 0:
			draw_rect(Rect2(icon_pos + Vector2(2.0, TAM_ICON.y - 5.0), Vector2((TAM_ICON.x - 4.0) * f, 3.0)), cor)
		if contragolpe_px > 0:
			draw_rect(Rect2(icon_pos + Vector2(2.0, TAM_ICON.y - 3.0), Vector2((TAM_ICON.x - 4.0) * float(contragolpe_px) / 20.0, 2.0)), Paleta.CONTRAGOLPE)
	elif not e and s_disponivel:
		_cortina(icon_pos, s_recarga_px)
		if s_ativo:  # erguido: o quadro pulsa
			var pulso := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * TAU * 2.0)
			draw_rect(Rect2(icon_pos + Vector2(1.0, 1.0), TAM_ICON - Vector2(2.0, 2.0)), Color(COR_ESCUDO, 0.10 + 0.22 * pulso))
	var rotulo := _rotulo_e() if e else _rotulo_s()
	var texto_aceso := e_disponivel if e else s_pronta
	var cor_texto := cor if texto_aceso else DESATIVADO
	draw_string(fonte, Vector2(origem.x, 57.0), rotulo, HORIZONTAL_ALIGNMENT_CENTER, TAM_CARD.x, Paleta.NUMERO_PEQUENO, cor_texto)
	# o selo da tecla na borda de baixo do card (E e LB numa teclinha, o botão direito no mouse desenhado), do mesmo tamanho dos glifos das telas
	Glifos.desenhar_selo(self, "habilidade" if e else "secundario", origem.x + TAM_CARD.x * 0.5, TAM_CARD.y - Glifos.ALTURA_SELO, cor, texto_aceso, DESATIVADO)


## A cor do quadro do ícone: a do estado do slot (pronto, em andamento, negado, apagado).
func _cor_do_card(e: bool, pulsa: bool) -> Color:
	if not e:
		if not s_disponivel or not s_pronta:
			return DESATIVADO
		return COR_ESCUDO.lerp(Paleta.BRANCO, 0.45) if s_ativo and pulsa else COR_ESCUDO
	if not e_disponivel:
		return DESATIVADO
	var cor := e_cor if e_pronta else DESATIVADO
	if e_ativa and pulsa:
		cor = e_cor.lerp(Paleta.BRANCO, 0.45)  # a E em andamento: o quadro do ícone pulsa
	if negada:
		cor = Paleta.PERIGO
	if perfeita and int(Time.get_ticks_msec() / 50.0) % 2 == 0:
		cor = Paleta.BRANCO
	return cor


## A cortina de recarga: escura, do topo para baixo, a fração que falta (px de 0 a 20), com a linha de varredura na ponta.
func _cortina(icon_pos: Vector2, px: int) -> void:
	if px <= 0:
		return
	var altura := (TAM_ICON.y - 2.0) * clampf(float(px) / 20.0, 0.0, 1.0)
	draw_rect(Rect2(icon_pos + Vector2(1.0, 1.0), Vector2(TAM_ICON.x - 2.0, altura)), Color(Paleta.PRETO, 0.56))
	if px < 20:
		draw_rect(Rect2(icon_pos + Vector2(1.0, 1.0 + altura), Vector2(TAM_ICON.x - 2.0, 1.0)), Color(Paleta.RECARGA_LINHA, 0.95))


## Arte própria da E; os ícones antigos continuam sendo a reserva (inclusive a Ruptura do Hazaki).
func arte_e() -> Texture2D:
	if estado_e == "habilidade" and ICONES_E.has(q_heroi):  # chave do herói já sincronizada para o Q; a E usa a mesma identidade
		return ICONES_E[q_heroi]
	return Dados.icone_carta(e_icone)


## Tudo o que o círculo do Q desenha, numa chave: só redesenha quando ela muda, ou enquanto pulsa.
func q_chave() -> String:
	return "%s|%s|%d|%s|%s|%s|%s|%s" % [q_implementada, q_pronta, q_carga_pct, q_negada, q_ativa, q_rotulo, q_cor.to_html(), q_heroi]


## O texto do Q (o círculo desenha a % que sai daqui enquanto enche): "EM BREVE" sem especial no herói, a % da carga enquanto enche, e com a carga
## cheia alterna "PRONTA" e o rótulo do especial.
func _rotulo_q() -> String:
	if not q_implementada:
		return "EM BREVE"
	if q_ativa:
		return q_rotulo
	if q_carga_pct < 100:
		return "%d%%" % q_carga_pct
	return "PRONTA" if int(Time.get_ticks_msec() / 900.0) % 2 == 0 else q_rotulo


func _rotulo_s() -> String:
	if not s_disponivel:
		return "INDISP."
	if s_ativo:
		return "ERGUIDO"
	return "ESCUDO" if s_pronta else "CANSADO"


func _rotulo_e() -> String:
	if not e_disponivel:
		return "INDISP."
	if recarga_s > 0.0:
		return "%.1f S" % recarga_s
	if carga_percentual > 0:
		return "%d%%" % carga_percentual
	return e_texto


## A moldura de pedra do slot (9-slice, centro transparente). O estado (pronto, recarga, negado) continua no quadro de 1 px do ícone.
func _moldura_pedra(retangulo: Rect2, ativa: bool) -> void:
	RenderingServer.canvas_item_add_nine_patch(
		get_canvas_item(),
		retangulo,
		Rect2(Vector2.ZERO, MOLDURA.get_size()),
		MOLDURA.get_rid(),
		MOLDURA_MARGEM,
		MOLDURA_MARGEM,
		RenderingServer.NINE_PATCH_STRETCH,
		RenderingServer.NINE_PATCH_STRETCH,
		false,
		Color.WHITE if ativa else MOLDURA_APAGADA
	)


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


## Um número do cfg (Dictionary) ou o padrão, quando o combate não existe (mundo falso dos testes).
func _cfg(d, chave: String, padrao: Variant) -> Variant:
	return d.get(chave, padrao) if d is Dictionary else padrao

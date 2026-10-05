extends CanvasLayer
## Cena de diálogo: tela escurece, os dois aparecem de corpo inteiro com gestos,
## e a caixa de texto mostra o rosto grande de quem fala, com a boca mexendo.

signal terminou

const BOCA := ["m", "o", "c", "o", "m", "c", "o", "m"]
const ROSTO := Rect2(24, 0, 52, 52)   # recorte do rosto dentro do quadro 100x140

var ativo := false
var _falas: Array = []
var _i := 0
var _letras := 0.0
var _t := 0.0
var _jamal := 0.0        # tempo restante do "passinho do Jamal" do Breno no palco
var _jamal_x0 := 0.0
var _antes_quem := ""
var _esq := ""
var _dir := ""
var _estado := ""   # entrando, falando, escolhendo, saindo
var resultado := -1  # opção escolhida (quando o bloco termina numa escolha)
var _escolha: Dictionary = {}
var _sel := 0
var _so_caixa := false
var _opcoes_painel := PanelContainer.new()
var _opcoes_lista := VBoxContainer.new()

var _preto := Visual.criar_cortina()
var _foto := TextureRect.new()      # o mapa de fundo, desfocado e escurecido
var _tag := PanelContainer.new()    # plaquinha com o nome de quem fala
var _foco_atual := ""
var _palco := Control.new()
var _corpo_esq := Sprite2D.new()
var _corpo_dir := Sprite2D.new()
var _caixa := Panel.new()
var _estilo_fala := StyleBoxFlat.new()
var _estilo_pensa := StyleBoxFlat.new()
var _auto := 0.0
var _ultima_letra := 0
var _moldura := Panel.new()
var _rosto := Sprite2D.new()
var _rosto_novo: Texture2D
var _rosto_tam := 52      # 104 quando é o rosto_hd.png (desenhado em escala 1)
# Retrato novo (rosto_gemini.png): 12 quadros de 144x192, mostrados a 2/3 (96x128).
# 0 fechada, 1 entreaberta, 2 aberta, 3 "o", 4 sorriso, 5/6 inclinado esq./dir.,
# 7/8 três quartos esq./dir., 9 piscando, 10 rindo, 11 olhando pra cima.
const RET_W := 96
const RET_H := 128
const FALA := [0, 1, 2, 1, 3, 1]
const FALA_FORTE := [1, 2, 2, 1, 3, 2]
const FALA_ALEGRE := [4, 1, 2, 4, 1, 3]
const FALA_RINDO := [10, 4, 10, 2]
static var _retratos := {}
# Jeito de falar de cada um (capitulos/vozes.json): velocidade, tom do blip, pausas.
static var _vozes := {}
var _dur_voz := 0.0        # segundos da voz gravada desta fala (0 = sem voz)
var _voz: Dictionary = {}
var _pausa := 0.0
const PAUSAS := {",": 0.12, ".": 0.3, "!": 0.3, "?": 0.3, "…": 0.4, ":": 0.2, ";": 0.2}
var _retrato: Texture2D
var _ret_t := 0.0
var _ret_piscar_ate := 0.0
var _ret_prox_piscar := 3.0
var _ret_angulo := 0
var _ret_angulo_ate := 0.0
var _ret_prox_angulo := 1.0
var _nome := Label.new()
var _texto := RichTextLabel.new()
var _seta := Label.new()


func _ready() -> void:
	layer = 10
	_palco.size = Vector2(480, 270)
	_palco.visible = false
	_palco.draw.connect(_desenhar_fundo)
	add_child(_palco)
	_foto.size = Vector2(480, 270)
	_foto.stretch_mode = TextureRect.STRETCH_SCALE
	_foto.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mf := ShaderMaterial.new()
	mf.shader = Visual.shader("desfoque")
	_foto.material = mf
	_foto.show_behind_parent = true
	_palco.add_child(_foto)
	for c in [_corpo_esq, _corpo_dir]:
		c.hframes = Dados.QUADROS.size()
		c.centered = false
		_palco.add_child(c)
	_corpo_esq.position = Vector2(92, 18)
	_corpo_dir.position = Vector2(288, 18)

	_estilo_fala = Visual.painel(Color(0.09, 0.11, 0.3, 0.96), Color("ffd34e"))
	_estilo_pensa.bg_color = Color(0.23, 0.2, 0.4, 0.96)
	_estilo_pensa.shadow_color = Color(0, 0, 0, 0.45)
	_estilo_pensa.shadow_offset = Vector2(3, 3)
	_estilo_pensa.shadow_size = 1
	_estilo_pensa.border_color = Color("c8c0f0")
	_estilo_pensa.set_border_width_all(2)
	_estilo_pensa.set_corner_radius_all(10)
	_caixa.add_theme_stylebox_override("panel", _estilo_fala)
	_caixa.position = Vector2(4, 156)
	_caixa.size = Vector2(472, 110)
	_palco.add_child(_caixa)
	Visual.borda_interna(_caixa)
	var em := StyleBoxFlat.new()
	em.bg_color = Color("f0e2bc")
	em.border_color = Color("ffd34e")
	em.set_border_width_all(2)
	_moldura.add_theme_stylebox_override("panel", em)
	_moldura.position = Vector2(6, 5)
	_moldura.size = Vector2(104, 100)
	_caixa.add_child(_moldura)
	_rosto.centered = false
	_rosto.region_enabled = true
	_rosto.scale = Vector2(2, 2)
	_rosto.position = Vector2(6, 3)
	_caixa.add_child(_rosto)
	var et := Visual.painel(Color("ffd34e"), Color("1a2050"), 4)
	et.content_margin_left = 8
	et.content_margin_right = 8
	_tag.add_theme_stylebox_override("panel", et)
	_nome.add_theme_color_override("font_color", Color("1a2050"))
	_tag.add_child(_nome)
	_palco.add_child(_tag)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.bbcode_enabled = true
	_texto.scroll_active = false
	_texto.clip_contents = false
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.add_theme_constant_override("line_separation", 6)
	_texto.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_texto.add_theme_constant_override("shadow_offset_x", 1)
	_texto.add_theme_constant_override("shadow_offset_y", 1)
	_caixa.add_child(_texto)
	_seta.text = "»"
	_seta.position = Vector2(456, 92)
	_seta.add_theme_color_override("font_color", Color("ffd34e"))
	_caixa.add_child(_seta)

	var est2 := Visual.painel(Color(0.09, 0.11, 0.3, 0.97), Color("ffd34e"), 7)
	_opcoes_painel.add_theme_stylebox_override("panel", est2)
	_opcoes_lista.add_theme_constant_override("separation", 6)
	_opcoes_painel.add_child(_opcoes_lista)
	_opcoes_painel.visible = false
	_palco.add_child(_opcoes_painel)

	add_child(_preto)


## falas: lista de {quem, texto, gestos, ouvinte, foco}; esq = jogador; dir = npc ("" se só o jogador).
## escolha: {escolha: "pergunta", opcoes: [{texto}...]} mostrada depois da última fala.
## so_caixa: sem escurecer e sem palco (narrador por cima do mapa).
func tocar(falas: Array, esq: String, dir: String, escolha: Dictionary = {}, so_caixa := false) -> void:
	_falas = []
	for f in falas:
		var g: Dictionary = f.duplicate()
		if g.get("quem", "*") == "jogador":
			g.quem = esq
		_falas.append(g)
	_escolha = escolha
	resultado = -1
	if not escolha.is_empty():
		var qe: String = escolha.get("quem", "*")
		_falas.append({"quem": esq if qe == "jogador" else qe, "texto": escolha.get("escolha", ""), "gestos": escolha.get("gestos", ["think"]), "_escolha": true})
	if _falas.is_empty():
		terminou.emit()
		return
	_esq = esq
	_antes_quem = ""
	_jamal = 0.0
	_dir = dir
	_i = 0
	_so_caixa = so_caixa
	ativo = true
	_corpo_esq.visible = not so_caixa
	_corpo_esq.texture = Dados.textura(esq, "cena")
	_corpo_dir.visible = dir != "" and not so_caixa
	if dir != "":
		_corpo_dir.texture = Dados.textura(dir, "cena")
	_corpo_esq.position.x = 92 if dir != "" else 190
	_foto.visible = false
	if so_caixa:
		_palco.visible = true
		_comecar_fala()
		_entrar_caixa()
		_estado = "falando"
		return
	_capturar_fundo()
	_escurecer(func():
		_palco.visible = true
		_comecar_fala()
		_entrar_corpos()
		_entrar_caixa()
		_estado = "falando")
	_estado = "entrando"


func _escurecer(no_meio: Callable) -> void:
	await Visual.cortina(_preto, 1.0, 0.25).finished
	no_meio.call()
	Visual.cortina(_preto, 0.0, 0.3)


## Foto da tela de agora (o mapa) pra servir de fundo desfocado da conversa.
func _capturar_fundo() -> void:
	var img := get_viewport().get_texture().get_image()
	if img and not img.is_empty():
		_foto.texture = ImageTexture.create_from_image(img)
		_foto.visible = true


func _entrar_corpos() -> void:
	for par in [[_corpo_esq, -110.0], [_corpo_dir, 480.0]]:
		var c: Sprite2D = par[0]
		var alvo := c.position.x
		c.position.x = par[1]
		create_tween().tween_property(c, "position:x", alvo, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _entrar_caixa() -> void:
	_caixa.position.y = 280
	create_tween().tween_property(_caixa, "position:y", 156.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _comecar_fala() -> void:
	var f: Dictionary = _falas[_i]
	var quem: String = f.get("quem", "*")
	_letras = 0.0
	_t = 0.0
	_pausa = 0.0
	_voz = voz(quem)
	_auto = 0.0
	_ultima_letra = 0
	var pensa: bool = f.get("pensa", false)
	var texto: String = f.get("texto", "")
	# o Breno grita KIKIUU quando acontece algo muito foda (com som)
	if texto.to_upper().contains("KIKIUU"):
		Jogo.som("kikiuu", -2.0)
	# passinho do Jamal: de vez em quando, enquanto os outros falam, o Breno dança no palco
	if quem != "breno" and quem != "*" and "breno" in [_esq, _dir] and _jamal <= 0.0 and Visual.ligado():
		var chance := 0.35 if _antes_quem != "breno" and _antes_quem != "" else 0.12
		if randf() < chance:
			_jamal = 2.2
			_jamal_x0 = (_corpo_esq if _esq == "breno" else _corpo_dir).position.x
	if quem == "breno" and _jamal > 0.0:
		_jamal = 0.001
	_antes_quem = quem
	# voz gravada (audio/vozes): o texto anda junto com a voz e o blip fica quieto
	_dur_voz = 0.0
	_dur_voz = Jogo.tocar_voz(quem, texto, str(f.get("voz", "")))
	if pensa and not texto.begins_with("("):
		texto = "(" + texto + ")"
	var limpo := texto.replace("*", "").replace("~", "")
	_texto.text = _enfase(texto)
	# quem fala tremendo (vozes.json "tremer": 0 a 1): a fala toda treme de leve
	var trem := float(_voz.get("tremer", 0.0))
	if trem > 0.0 and Visual.ligado() and not pensa:
		_texto.text = "[shake rate=%d level=%d]%s[/shake]" % [int(10 + trem * 10), int(1 + trem * 3), _texto.text]
	if not f.has("gestos"):
		f["gestos"] = gestos_padrao(texto, pensa)
	_caixa.add_theme_stylebox_override("panel", _estilo_pensa if pensa else _estilo_fala)
	_texto.add_theme_color_override("default_color", Color("d8d2ff") if pensa else Color("f3efe2"))
	if not f.get("_escolha", false):
		Jogo.registrar_fala(quem, limpo)
	if Visual.ligado() and (limpo.contains("!!") or "[shake" in _texto.text):
		_sacudir_caixa()
	_texto.visible_characters = 0
	# alguém de fora da dupla falou: ele entra no lugar de quem está à direita
	if quem != "*" and quem != _esq and quem != _dir and not _so_caixa and ResourceLoader.exists("res://assets/personagens/%s/cena.png" % quem):
		_dir = quem
		_corpo_dir.texture = Dados.textura(quem, "cena")
		_corpo_dir.visible = true
		_corpo_esq.position.x = 92
		_corpo_dir.modulate.a = 0.0
		create_tween().tween_property(_corpo_dir, "modulate:a", 1.0, 0.2)
	var narrador := quem == "*" or not (quem == _esq or quem == _dir)
	_tag.visible = not narrador
	_moldura.visible = not narrador
	_rosto.visible = not narrador
	if narrador:
		_texto.position = Vector2(14, 14)
		_texto.size = Vector2(440, 86)
	else:
		_nome.text = Dados.nome(quem) + (" (pensando)" if pensa else "")
		_tag.reset_size()
		_tag.position = Vector2(118, 145)
		_texto.position = Vector2(122, 30)
		_texto.size = Vector2(334, 70)
		_retrato = _carregar_retrato(quem)
		_ret_t = 0.0
		_ret_piscar_ate = 0.0
		_ret_angulo_ate = 0.0
		_ret_prox_angulo = randf_range(0.7, 1.5)
		_ret_prox_piscar = randf_range(1.5, 3.5)
		if _retrato:
			_moldura.position = Vector2(6, -25)
			_moldura.size = Vector2(RET_W + 4, RET_H + 4)
			_rosto.position = Vector2(8, -23)
			_rosto.scale = Vector2.ONE
			_rosto.texture = _retrato
			_rosto.region_rect = Rect2(0, 0, RET_W, RET_H)
		else:
			_moldura.position = Vector2(6, 5)
			_moldura.size = Vector2(104, 100)
			_rosto.position = Vector2(6, 3)
		_rosto_novo = Dados.textura(quem, "rosto_hd")
		_rosto_tam = 104
		if _rosto_novo == null:
			_rosto_novo = Dados.textura(quem, "rosto")
			_rosto_tam = 52
		if not _retrato:
			_rosto.scale = Vector2.ONE * (104.0 / _rosto_tam if _rosto_novo else 2.0)
			_rosto.texture = _rosto_novo if _rosto_novo else Dados.textura(quem, "cena")
		if not _retrato and not _rosto_novo:
			# sem retrato desenhado (ex.: Seu Mauro): só o nome e o texto, o corpo aparece no palco
			_moldura.visible = false
			_rosto.visible = false
			_tag.position = Vector2(10, 145)
			_texto.position = Vector2(14, 30)
			_texto.size = Vector2(440, 70)
	_opcoes_painel.visible = false
	if f.get("_escolha", false):
		_montar_opcoes()
		_opcoes_painel.visible = false
	_palco.queue_redraw()


## Voz de um personagem (capitulos/vozes.json, "padrao" para quem não estiver lá).
static func voz(quem: String) -> Dictionary:
	if _vozes.is_empty():
		var d = Dados.ler_json("vozes.json")
		_vozes = d if d is Dictionary else {"padrao": {}}
	var v = _vozes.get(quem, _vozes.get("padrao", {}))
	return v if v is Dictionary else {}


## Destaque nas falas: *palavra* fica amarela e ondulando; ~palavra~ treme (grito, susto);
## numa fala com "!", PALAVRA EM MAIÚSCULAS (3+ letras) também treme sozinha (grito).
## Sem "Efeitos tela", só a cor.
func _enfase(texto: String) -> String:
	var t := texto.replace("[", "[lb]")
	var mexe := Visual.ligado()
	var re := RegEx.new()
	re.compile("\\*([^*]+)\\*")
	t = re.sub(t, "[color=#ffd34e]" + ("[wave amp=18 freq=4]$1[/wave]" if mexe else "$1") + "[/color]", true)
	re.compile("~([^~]+)~")
	t = re.sub(t, "[color=#ff8a7a]" + ("[shake rate=20 level=6]$1[/shake]" if mexe else "$1") + "[/color]", true)
	if texto.contains("!"):
		re.compile("(?<![\\p{L}\\]=])(\\p{Lu}{%d,})(?![\\p{L}])" % (2 if texto.contains("!!") else 3))
		var troca := "$1"
		# "!!" = grito: as palavras em maiúsculas ficam com o dobro do tamanho
		if texto.contains("!!"):
			troca = "[font_size=%d]%s[/font_size]" % [_texto.get_theme_font_size("normal_font_size") * 2, troca]
		if mexe:
			troca = "[shake rate=20 level=5]%s[/shake]" % troca
		if troca != "$1":
			t = re.sub(t, troca, true)
	return t


func _sacudir_caixa() -> void:
	var x := 4.0
	var tw := create_tween()
	for k in [3.0, -3.0, 2.0, -1.0, 0.0]:
		tw.tween_property(_caixa, "position:x", x + k, 0.04)


func _montar_opcoes() -> void:
	for c in _opcoes_lista.get_children():
		_opcoes_lista.remove_child(c)
		c.queue_free()
	_sel = 0
	for op in _escolha.get("opcoes", []):
		var l := Label.new()
		l.text = "  " + str(op.get("texto", "?"))
		_opcoes_lista.add_child(l)
	_marcar_opcao()


func _marcar_opcao() -> void:
	var n := _opcoes_lista.get_child_count()
	for i in n:
		var l: Label = _opcoes_lista.get_child(i)
		var t := l.text.substr(2)
		l.text = ("> " if i == _sel else "  ") + t
		l.add_theme_color_override("font_color", Color("ffd34e") if i == _sel else Color("f3efe2"))
	_opcoes_painel.reset_size()
	Visual.marcar_lista(_opcoes_lista.get_children(), _sel)


func _process(delta: float) -> void:
	if _estado != "falando":
		return
	_t += delta
	var f: Dictionary = _falas[_i]
	var total := _texto.get_total_character_count()
	var digitando := _letras < total
	if digitando:
		if _pausa > 0.0:
			_pausa -= delta
		else:
			var antes := int(_letras)
			var vel := Jogo.vel_texto() * float(_voz.get("velocidade", 1.0))
			if _dur_voz > 0.0:
				vel = maxf(total / maxf(_dur_voz * 0.85, 0.3), vel if Jogo.vel_texto() > 1000.0 else 0.0)
			_letras = min(_letras + vel * delta, total)
			# respira na pontuação, como gente falando (para na letra e espera um pouco)
			var txt := _texto.get_parsed_text()
			for i in range(antes, int(_letras)):
				var prox := txt.substr(i + 1, 1)
				if _dur_voz <= 0.0 and i + 1 < total and (prox == " " or prox == "\n"):
					var p := float(PAUSAS.get(txt.substr(i, 1), 0.0)) * float(_voz.get("pausa", 1.0))
					if p > 0.0:
						_letras = i + 1
						_pausa = p
						break
			_texto.visible_characters = int(_letras)
			if _dur_voz <= 0.0 and int(_letras) - _ultima_letra >= int(_voz.get("blip_cada", 2)) and quem_fala() != "*":
				_ultima_letra = int(_letras)
				Jogo.som("blip", -10.0, float(_voz.get("variar", 0.06)), float(_voz.get("tom", 1.0)))
	# segurar X (ou Ctrl) acelera: mostra o texto todo e vai passando sozinho
	if Input.is_action_pressed("acelerar") and not f.get("_escolha", false):
		_texto.visible_characters = -1
		_letras = total
		_auto += delta
		if _auto > 0.12:
			_avancar()
			return
		digitando = false
	_seta.visible = not digitando and not _opcoes_painel.visible
	_seta.position.y = 90 + round(sin(_t * 6.0) * 2.0)
	if not digitando and f.get("_escolha", false) and not _opcoes_painel.visible:
		_opcoes_painel.visible = true
		_opcoes_painel.position = Vector2(476 - _opcoes_painel.size.x, 152 - _opcoes_painel.size.y)
		Visual.surgir(_opcoes_painel, 0.2)
	if _opcoes_painel.visible:
		_opcoes_painel.position = Vector2(476 - _opcoes_painel.size.x, 152 - _opcoes_painel.size.y)

	var quem: String = f.get("quem", "*")
	var foco: String = f.get("foco", quem if quem != "*" else (_dir if _dir != "" else _esq))
	var gestos: Array = f.get("gestos", ["talk1"])
	if gestos.is_empty():
		gestos = ["idle"]
	var gesto: String = gestos[int(_t / 1.2) % gestos.size()]
	var boca: String = BOCA[int(_t / 0.08) % BOCA.size()] if (digitando or (_dur_voz > 0.0 and Jogo.voz_tocando())) and quem != "*" and not f.get("pensa", false) else "c"
	var alterna := int(_t / 0.3) % 2 == 1
	var ouvinte: String = f.get("ouvinte", "idle")
	if foco != _foco_atual:
		_foco_atual = foco
		_palco.queue_redraw()
	var piscando := fmod(_t, 3.0) > 2.85

	for lado in [[_corpo_esq, _esq], [_corpo_dir, _dir]]:
		var spr: Sprite2D = lado[0]
		if lado[1] == "":
			continue
		spr.modulate = Color.WHITE if lado[1] == foco else Color(0.7, 0.72, 0.85)
		if lado[1] == foco and gesto == "cismado":
			spr.frame = Dados.QUADROS.find("piscar")
		elif lado[1] == foco:
			spr.frame = Dados.quadro(gesto, boca, alterna)
		elif ouvinte == "idle" and piscando:
			spr.frame = Dados.QUADROS.find("piscar")
		else:
			spr.frame = Dados.quadro(ouvinte, "c", alterna)
	if _jamal > 0.0:
		_jamal -= delta
		var sj: Sprite2D = _corpo_esq if _esq == "breno" else _corpo_dir
		# dois passinhos pra um lado, dois pro outro, as mãos acompanhando os pés
		var passo := int((2.2 - _jamal) / 0.17)
		var lado := 1.0 if (passo / 2) % 2 == 0 else -1.0
		sj.frame = Dados.QUADROS.find("wave_a" if passo % 2 == 0 else "wave_b")
		sj.position.x = _jamal_x0 + lado * (2.0 + (passo % 2) * 3.0)
		sj.position.y = 18 - (2 if passo % 2 == 0 else 0)
		if _jamal <= 0.0:
			sj.position = Vector2(_jamal_x0, 18)
	if _rosto.visible and _retrato:
		var qg := _quadro_retrato(delta, digitando or (_dur_voz > 0.0 and Jogo.voz_tocando()), gesto, f.get("pensa", false), quem)
		_rosto.region_rect = Rect2(qg * RET_W, 0, RET_W, RET_H)
		# cabeça balançando de um lado pro outro (vozes.json "tremer")
		var trem := float(_voz.get("tremer", 0.0)) if Visual.ligado() else 0.0
		_rosto.position.x = 8.0 + round(sin(_ret_t * (6.0 if digitando else 3.0)) * 2.0 * trem)
	elif _rosto.visible:
		var q := Dados.quadro("idle", boca, false)
		if not digitando and piscando:
			q = Dados.QUADROS.find("piscar")
		if _rosto_novo:
			# rosto.png: 52x52 por quadro, na mesma ordem de QUADROS (gesto do rosto acompanha o corpo)
			var qr := Dados.quadro(gesto if quem == foco else "idle", boca, alterna)
			if not digitando and piscando:
				qr = Dados.QUADROS.find("piscar")
			_rosto.region_rect = Rect2(qr * _rosto_tam, 0, _rosto_tam, _rosto_tam)
		else:
			_rosto.region_rect = Rect2(q * 100 + ROSTO.position.x, ROSTO.position.y, ROSTO.size.x, ROSTO.size.y)


## rosto_gemini.png reduzido uma vez (Lanczos) para 2/3, que é o tamanho da caixa.
static func _carregar_retrato(quem: String) -> Texture2D:
	var chave := Dados.pasta_personagens() + quem
	if _retratos.has(chave):
		return _retratos[chave]
	var tex: Texture2D = null
	var t := Dados.textura(quem, "rosto_gemini")
	if t:
		var img := t.get_image()
		if img.is_compressed():
			img.decompress()
		var n := img.get_width() / 144
		img.resize(n * RET_W, RET_H, Image.INTERPOLATE_LANCZOS)
		tex = ImageTexture.create_from_image(img)
	_retratos[chave] = tex
	return tex


## Qual quadro do retrato mostrar agora: boca acompanhando as letras, cabeça que
## inclina ou vira pro outro de vez em quando, piscadas, riso e "pensando".
func _quadro_retrato(delta: float, digitando: bool, gesto: String, pensa: bool, quem: String) -> int:
	_ret_t += delta
	if _ret_t >= _ret_prox_piscar:
		_ret_piscar_ate = _ret_t + 0.13
		_ret_prox_piscar = _ret_t + randf_range(2.5, 5.0)
	var piscando := _ret_t < _ret_piscar_ate
	if pensa or gesto == "think":
		return 9 if piscando else 11
	# "cismado": olho apertado, desconfiado (quadro 12, se o retrato tiver)
	if gesto == "cismado" and _retrato and _retrato.get_width() > 12 * RET_W:
		return 12
	var pro_outro := 8 if quem == _esq else 7
	if not digitando:
		if piscando:
			return 9
		match gesto:
			"laugh": return 10 if _ret_t - floor(_ret_t / 1.2) * 1.2 < 0.6 else 4
			"wave": return 4
			"point": return pro_outro
		return 0
	if _ret_t < _ret_angulo_ate:
		return _ret_angulo
	if _ret_t >= _ret_prox_angulo:
		_ret_prox_angulo = _ret_t + randf_range(1.6, 3.2)
		_ret_angulo_ate = _ret_t + randf_range(0.35, 0.7)
		match gesto:
			"point": _ret_angulo = pro_outro
			"shrug": _ret_angulo = [5, 6].pick_random()
			"laugh": _ret_angulo = 10
			_: _ret_angulo = [5, 6, pro_outro, pro_outro].pick_random()
		return _ret_angulo
	var ciclo: Array = FALA
	match gesto:
		"talk2", "point": ciclo = FALA_FORTE
		"wave": ciclo = FALA_ALEGRE
		"laugh": ciclo = FALA_RINDO
	return ciclo[int(_ret_t * 9.0) % ciclo.size()]


func _unhandled_input(event: InputEvent) -> void:
	if not ativo:
		return
	get_viewport().set_input_as_handled()
	if _estado != "falando":
		return
	var digitando := _texto.visible_characters < _texto.get_total_character_count() and _texto.visible_characters != -1
	if _opcoes_painel.visible and not digitando:
		var n := _opcoes_lista.get_child_count()
		if event.is_action_pressed("cima"):
			_sel = (_sel - 1 + n) % n
			Jogo.som("cursor")
			_marcar_opcao()
			return
		if event.is_action_pressed("baixo"):
			_sel = (_sel + 1) % n
			Jogo.som("cursor")
			_marcar_opcao()
			return
	if not event.is_action_pressed("interagir"):
		return
	if digitando:
		_letras = _texto.get_total_character_count()
		_texto.visible_characters = -1
		if _falas[_i].get("_escolha", false):
			_montar_opcoes()
			_opcoes_painel.visible = true
	else:
		_avancar()


func _avancar() -> void:
	if _estado != "falando":
		return
	Jogo.parar_voz()
	if _i < _falas.size() - 1:
		_i += 1
		_comecar_fala()
	else:
		if _opcoes_painel.visible:
			resultado = _sel
			Jogo.som("confirmar")
		_estado = "saindo"
		if _so_caixa:
			_fechar()
		else:
			_escurecer(_fechar)


func quem_fala() -> String:
	return _falas[_i].get("quem", "*") if _i < _falas.size() else "*"


## Gestos automáticos quando a fala não diz quais usar (pela pontuação).
static func gestos_padrao(texto: String, pensa := false) -> Array:
	var t := texto.to_lower()
	if pensa or t.ends_with("...") or t.ends_with("...)"):
		return ["think", "talk1"]
	if "kkk" in t or "haha" in t or "rsrs" in t or "hehe" in t:
		return ["laugh", "talk1"]
	if t.ends_with("?") or t.ends_with("?!"):
		return ["shrug", "talk1"]
	if t.ends_with("!"):
		return ["point", "talk2"]
	return ["talk1", "talk2"]


func _fechar() -> void:
	Jogo.parar_voz()
	_palco.visible = false
	_opcoes_painel.visible = false
	ativo = false
	_estado = ""
	terminou.emit()


func _desenhar_fundo() -> void:
	if _so_caixa:
		return
	if _foto.visible:
		# luz atrás de quem fala e um "chão" escuro embaixo dos dois
		var foco := _foco_atual
		for lado in [[_corpo_esq, _esq], [_corpo_dir, _dir]]:
			var spr: Sprite2D = lado[0]
			if lado[1] == "" or not spr.visible:
				continue
			var forte: bool = lado[1] == foco
			var c := spr.position + Vector2(50, 70)
			_palco.draw_texture_rect(Visual.textura_luz(), Rect2(c - Vector2(110, 110), Vector2(220, 220)), false,
				Color(1, 0.85, 0.45, 0.32 if forte else 0.1))
			_palco.draw_set_transform(spr.position + Vector2(50, 138), 0, Vector2(1, 0.25))
			_palco.draw_circle(Vector2.ZERO, 34, Color(0, 0, 0, 0.35))
			_palco.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		return
	_palco.draw_rect(Rect2(0, 0, 480, 270), Color("e6e9f5"))
	for x in range(0, 480, 60):
		var azul := (x / 60) % 2 == 0
		_palco.draw_rect(Rect2(x, 0, 60, 120), Color("2a2fa8") if azul else Color("f1f3fb"))
	_palco.draw_rect(Rect2(0, 114, 480, 6), Color("1b1f5e"))
	for y in range(120, 270, 16):
		for x in range(0, 480, 16):
			if ((x + y) / 16) % 2 == 0:
				_palco.draw_rect(Rect2(x, y, 16, 16), Color("c9cfe6"))
	_palco.draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.12))

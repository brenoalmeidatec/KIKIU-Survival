extends CanvasLayer
## Tela de opções (do menu e da pausa): volume, tela cheia, velocidade do texto.
## Setas mudam, Esc/E em "Voltar" fecha. Tudo é salvo na hora.

signal fechou

var _linhas: Array[Label] = []
var _sel := 0
var ITENS := ["musica", "efeitos", "voz", "tela_cheia", "vel_texto", "qualidade", "arte", "controles", "voltar"]
var _sub: Node = null


func _ready() -> void:
	if not Dados.tem_arte_antiga():
		ITENS.erase("arte")
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.size = Vector2(480, 270)
	add_child(fundo)
	var p := Panel.new()
	var e := Visual.painel()
	p.add_theme_stylebox_override("panel", e)
	Visual.borda_interna(p)
	p.position = Vector2(60, 24)
	p.size = Vector2(360, 222)
	add_child(p)
	Visual.surgir(p)
	var t := Label.new()
	t.text = "Opções"
	t.add_theme_color_override("font_color", Color("ffd34e"))
	t.position = Vector2(14, 12)
	p.add_child(t)
	for i in ITENS.size():
		var l := Label.new()
		l.position = Vector2(20, 36 + i * 18)
		p.add_child(l)
		_linhas.append(l)
	var dica := Label.new()
	dica.text = "cima/baixo: escolher   esq/dir: mudar"
	dica.add_theme_color_override("font_color", Color("6b7299"))
	dica.position = Vector2(14, 202)
	p.add_child(dica)
	_atualizar()


func _barra(v: float) -> String:
	var n := int(round(v * 10))
	return "[" + "|".repeat(n) + ".".repeat(10 - n) + "]"


func _atualizar() -> void:
	var o := Jogo.opcoes
	var textos := [
		"Música        " + _barra(o.musica),
		"Efeitos       " + _barra(o.efeitos),
		"Voz           " + ("Ligada" if o.get("voz", true) else "Desligada (só blip)"),
		"Tela cheia    " + ("Sim" if o.tela_cheia else "Não"),
		"Texto         " + Jogo.NOMES_VEL[int(o.vel_texto)],
		"Qualidade     " + Jogo.NOMES_QUALIDADE.get(o.get("qualidade", "alta"), "Alta"),
		"Personagens   " + ("Arte nova" if o.get("arte", "nova") == "nova" else "Arte antiga"),
		"Controles     " + ("(controle ligado)" if Input.get_connected_joypads().size() > 0 else "trocar teclas"),
		"Voltar",
	]
	if not "arte" in ITENS:
		textos.remove_at(6)
	for i in _linhas.size():
		_linhas[i].text = ("> " if i == _sel else "  ") + textos[i]
		_linhas[i].add_theme_color_override("font_color", Color("ffd34e") if i == _sel else Color("f3efe2"))
	Visual.marcar_lista(_linhas, _sel)


func _mudar(d: int) -> void:
	var o := Jogo.opcoes
	match ITENS[_sel]:
		"musica":
			o.musica = clampf(snappedf(o.musica + d * 0.1, 0.1), 0.0, 1.0)
		"efeitos":
			o.efeitos = clampf(snappedf(o.efeitos + d * 0.1, 0.1), 0.0, 1.0)
		"voz":
			o.voz = not o.get("voz", true)
			if not o.voz:
				Jogo.parar_voz()
		"tela_cheia":
			o.tela_cheia = not o.tela_cheia
		"vel_texto":
			o.vel_texto = clampi(int(o.vel_texto) + d, 0, Jogo.VELOCIDADES.size() - 1)
		"qualidade":
			var i := Jogo.QUALIDADES.find(o.get("qualidade", "alta"))
			o.qualidade = Jogo.QUALIDADES[clampi(i + d, 0, Jogo.QUALIDADES.size() - 1)]
		"arte":
			o.arte = "antiga" if o.get("arte", "nova") == "nova" else "nova"
			Dados.limpar_cache()
		"controles":
			if d > 0 and _sub == null:
				_sub = preload("res://scripts/controles_tela.gd").new()
				_sub.fechou.connect(func():
					_sub = null
					_atualizar())
				add_child(_sub)
			return
		_:
			return
	Jogo.aplicar_opcoes()
	Jogo.salvar_opcoes()
	Jogo.som("cursor")
	_atualizar()


func _unhandled_input(event: InputEvent) -> void:
	if _sub != null or not (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("cima"):
		_sel = (_sel - 1 + ITENS.size()) % ITENS.size()
		Jogo.som("cursor")
		_atualizar()
	elif event.is_action_pressed("baixo"):
		_sel = (_sel + 1) % ITENS.size()
		Jogo.som("cursor")
		_atualizar()
	elif event.is_action_pressed("esquerda"):
		_mudar(-1)
	elif event.is_action_pressed("direita"):
		_mudar(1)
	elif event.is_action_pressed("voltar") or (event.is_action_pressed("interagir") and ITENS[_sel] == "voltar"):
		Jogo.som("fechar")
		fechou.emit()
		queue_free()
	elif event.is_action_pressed("interagir"):
		_mudar(1)

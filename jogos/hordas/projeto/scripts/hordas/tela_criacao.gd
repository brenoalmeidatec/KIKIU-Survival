extends CanvasLayer
## Criação de herói (#72): marco 1 = raça e classe; marco 2 = nome, pontos de atributo, defeito voluntário e aparência por paleta,
## com prévia ao vivo (o corpo é recolorido na hora). Cima/baixo escolhem a linha, esquerda/direita trocam (ou gastam/tiram pontos),
## Enter cria. Na linha do nome, as letras vão pro texto (as setas continuam andando pelas linhas). Esc volta. O mouse também serve.
## Uso: var t := TelaCriacao.new(); add_child(t); t.fechou.connect(func(ok, id): ...)   (id = herói salvo, "c:h...")

signal fechou(confirmou: bool, id: String)

const Criacao := preload("res://scripts/hordas/criacao.gd")
const Paleta := preload("res://scripts/hordas/paleta.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
const W := 640.0
const H := 360.0
const LINHA_Y := 52.0
const LINHA_H := 17.0
const COL_ROTULO := 20.0
const COL_VALOR := 112.0
const COL_VALOR_W := 224.0

var raca := 0
var classe := 0
var ficha := {}
var linha := 0                 # a linha escolhida (0 = nome ... LINHAS.size()-1 = botão criar)
var _nome_txt := ""
var _defeito := 0              # 0 = nenhum; i = i-ésimo defeito da lista
var _pele_manual := false
var _msg := ""
var _msg_t := 0.0
var _quadro := 0
var _t := 0.0
var _linhas: Array = []
var _tela := Control.new()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_quadro = Engine.get_process_frames()   # a tecla que abriu a tela não conta aqui
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)
	_linhas = [{"t": "nome"}, {"t": "raca"}, {"t": "classe"}]
	for k in Criacao.lista_atributos():
		_linhas.append({"t": "attr", "k": k})
	_linhas.append({"t": "defeito"})
	for c in Paleta.canais():
		_linhas.append({"t": "pal", "k": c})
	_linhas.append({"t": "criar"})
	if ficha.is_empty():
		ficha = Criacao.ficha_nova(_raca_id(), _classe_id())
	else:   # ficha pronta (prints de teste): acerta os índices
		raca = maxi(0, Criacao.lista_racas().find(ficha.raca))
		classe = maxi(0, Criacao.lista_classes().find(ficha.classe))
		_defeito = 1 + Criacao.lista_defeitos().find(ficha.defeito) if ficha.defeito != "" else 0
		_nome_txt = str(ficha.nome)
		_pele_manual = true
	_atualizar()


func _raca_id() -> String:
	return str(Criacao.lista_racas()[raca])


func _classe_id() -> String:
	return str(Criacao.lista_classes()[classe])


## Joga o que a tela mostra na ficha (nome, raça, classe, defeito) e devolve a ficha.
func _atualizar() -> Dictionary:
	ficha["nome"] = Criacao.limpar_nome(_nome_txt)
	ficha["raca"] = _raca_id()
	ficha["classe"] = _classe_id()
	ficha["defeito"] = "" if _defeito == 0 else str(Criacao.lista_defeitos()[_defeito - 1])
	return ficha


func _sobra() -> int:
	return Criacao.pontos_totais(str(ficha.defeito)) - Criacao.pontos_gastos(ficha.pontos)


func _process(dt: float) -> void:
	_t += dt
	_msg_t = maxf(0.0, _msg_t - dt)
	_tela.queue_redraw()


func _aviso(s: String) -> void:
	_msg = s
	_msg_t = 3.5
	Som.ui("erro")


func _input(e: InputEvent) -> void:
	if Engine.get_process_frames() == _quadro:
		return
	if e is InputEventKey and e.pressed:
		_tecla(e)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_clique(_tela.get_local_mouse_position())
		get_viewport().set_input_as_handled()
	elif e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_DPAD_UP:
			_mover(-1)
		elif e.button_index == JOY_BUTTON_DPAD_DOWN:
			_mover(1)
		elif e.button_index == JOY_BUTTON_DPAD_LEFT:
			_trocar(-1)
		elif e.button_index == JOY_BUTTON_DPAD_RIGHT:
			_trocar(1)
		elif e.button_index == JOY_BUTTON_A:
			_confirmar()
		elif e.button_index == JOY_BUTTON_START:
			_voltar()


func _tecla(k: InputEventKey) -> void:
	get_viewport().set_input_as_handled()
	var no_nome: bool = _linhas[linha].t == "nome"
	match k.keycode:
		KEY_UP:
			_mover(-1)
		KEY_DOWN, KEY_TAB:
			_mover(1)
		KEY_ESCAPE:
			_voltar()
		KEY_ENTER, KEY_KP_ENTER:
			_confirmar()
		KEY_BACKSPACE:
			if no_nome:
				_nome_txt = _nome_txt.left(-1)
				_atualizar()
		KEY_LEFT:
			if not no_nome:
				_trocar(-1)
		KEY_RIGHT:
			if not no_nome:
				_trocar(1)
		_:
			if no_nome:
				if k.unicode >= 32 and _nome_txt.length() < int(Dados.json("aparencia").get("nome_max", 12)):
					var ch := char(k.unicode)
					var novo := _nome_txt + ch
					if ch == " ":
						if _nome_txt != "" and not _nome_txt.ends_with(" "):
							_nome_txt = novo
					elif Criacao.limpar_nome(ch) != "":   # só letras, números, espaço e hífen
						_nome_txt = novo
					_atualizar()
			elif k.keycode == KEY_W:
				_mover(-1)
			elif k.keycode == KEY_S:
				_mover(1)
			elif k.keycode == KEY_A:
				_trocar(-1)
			elif k.keycode == KEY_D:
				_trocar(1)
			elif k.keycode in [KEY_Z, KEY_E]:
				_confirmar()


func _voltar() -> void:
	Som.ui("voltar")
	fechou.emit(false, "")
	queue_free()


func _mover(passo: int) -> void:
	linha = (linha + passo + _linhas.size()) % _linhas.size()
	Som.ui("cursor")


func _confirmar() -> void:
	if _linhas[linha].t == "nome":
		_mover(1)
	else:
		_criar()


## Troca o valor da linha: raça, classe, defeito, cor ou +/- ponto de um atributo.
func _trocar(passo: int) -> void:
	var l: Dictionary = _linhas[linha]
	match str(l.t):
		"raca":
			var n := Criacao.lista_racas().size()
			raca = (raca + passo + n) % n
			if not _pele_manual:
				ficha.paleta["pele"] = Paleta.padrao(_raca_id()).pele
		"classe":
			var n := Criacao.lista_classes().size()
			classe = (classe + passo + n) % n
		"defeito":
			var n := Criacao.lista_defeitos().size() + 1
			_defeito = (_defeito + passo + n) % n
			_atualizar()
			var devolvidos := 0
			while _sobra() < 0:   # o defeito saiu: devolve os pontos que passaram do novo total (do último atributo pra trás)
				var lista: Array = Criacao.lista_atributos()
				for i in range(lista.size() - 1, -1, -1):
					if int(ficha.pontos[lista[i]]) > 0:
						ficha.pontos[lista[i]] = int(ficha.pontos[lista[i]]) - 1
						devolvidos += 1
						break
			if devolvidos > 0:
				_aviso("Sem o defeito, %d ponto(s) voltaram." % devolvidos)
				return
		"attr":
			var k := str(l.k)
			var v := int(ficha.pontos[k]) + passo
			if v < 0 or v > int(Criacao.atributos().get(k, {}).get("max", 0)):
				Som.ui("erro")
				return
			if passo > 0 and _sobra() <= 0:
				_aviso("Sem pontos sobrando. Escolha um defeito pra ganhar mais.")
				return
			ficha.pontos[k] = v
		"pal":
			var c := str(l.k)
			var n := Paleta.cores(c).size()
			ficha.paleta[c] = (int(ficha.paleta[c]) + passo + n) % n
			if c == "pele":
				_pele_manual = true
		_:
			return
	_atualizar()
	Som.ui("cursor")


func _criar() -> void:
	_atualizar()
	var erro := Criacao.erro_ficha(ficha)
	if erro != "":
		_aviso("Falta: " + erro + ".")
		return
	if Criacao.quantos() >= Criacao.MAX_HEROIS:
		_aviso("Você já tem %d heróis. Apague um pra criar outro." % Criacao.MAX_HEROIS)
		return
	var id := Criacao.salvar_ficha(ficha)
	if id == "":
		_aviso("Já existe um herói com esse nome.")
		return
	Som.ui("confirmar")
	fechou.emit(true, id)
	queue_free()


func _rect_linha(i: int) -> Rect2:
	return Rect2(COL_ROTULO - 4, LINHA_Y + i * LINHA_H - 11, COL_VALOR + COL_VALOR_W + 8 - COL_ROTULO + 4, LINHA_H - 1)


func _botao() -> Rect2:
	return Rect2(W / 2 - 70, 322, 140, 16)


func _clique(mp: Vector2) -> void:
	if _botao().has_point(mp):
		linha = _linhas.size() - 1
		_criar()
		return
	for i in _linhas.size() - 1:
		var q := _rect_linha(i)
		if not q.has_point(mp):
			continue
		linha = i
		var t: String = _linhas[i].t
		if t == "pal":   # clicar numa cor escolhe ela
			var c := str(_linhas[i].k)
			var j := int((mp.x - COL_VALOR) / 28.0)
			if mp.x >= COL_VALOR and j >= 0 and j < Paleta.cores(c).size():
				ficha.paleta[c] = j
				if c == "pele":
					_pele_manual = true
				Som.ui("cursor")
		elif t != "nome":
			if mp.x < COL_VALOR + 30:
				_trocar(-1)
			elif mp.x > COL_VALOR + COL_VALOR_W - 30:
				_trocar(1)
		return


func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := W, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	_tela.draw_string(Dados.fonte, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, 0.8))
	_tela.draw_string(Dados.fonte, p, s, alinhar, larg, tam, cor)


func _desenhar() -> void:
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.04, 0.07, 0.99))
	_txt(Vector2(0, 22), "Criar herói", 16, Color(1, 0.85, 0.45))
	_txt(Vector2(0, 38), "Atenção: se ele morrer, morre de vez.", 8, Color(1, 0.6, 0.5))
	if Criacao.lista_racas().is_empty() or Criacao.lista_classes().is_empty():
		return
	var heroi := Criacao.montar(_raca_id(), _classe_id(), _atualizar())
	var r: Dictionary = Criacao.racas().get(_raca_id(), {})
	var c: Dictionary = Criacao.classes().get(_classe_id(), {})
	_tela.draw_rect(Rect2(10, 40, 340, 238), Color(0.08, 0.08, 0.13))
	_tela.draw_rect(Rect2(10, 40, 340, 238), Color(0.3, 0.33, 0.48), false, 1.0)
	for i in _linhas.size() - 1:
		_desenhar_linha(i, _linhas[i], r, c)
	_txt(Vector2(COL_ROTULO, LINHA_Y + (_linhas.size() - 1) * LINHA_H - 3), "Pontos sobrando: %d de %d" % [_sobra(), Criacao.pontos_totais(str(ficha.defeito))], 8,
		Color(1, 0.9, 0.5) if _sobra() > 0 else Color(0.6, 0.65, 0.75), 320, HORIZONTAL_ALIGNMENT_LEFT)
	_desenhar_previa(heroi)
	# descrição da linha escolhida
	var d := _descricao(_linhas[linha], r, c)
	_tela.draw_rect(Rect2(362, 228, 268, 50), Color(0.08, 0.08, 0.13))
	_tela.draw_rect(Rect2(362, 228, 268, 50), Color(0.3, 0.33, 0.48), false, 1.0)
	_tela.draw_multiline_string(Dados.fonte, Vector2(368, 241), d, HORIZONTAL_ALIGNMENT_LEFT, 256, 8, 4, Color(0.78, 0.8, 0.88))
	# ficha final
	var s := Construcao.stats(heroi, {}, {})
	_txt(Vector2(0, 294), "Vida %d   Dano %d%%   Velocidade %d%%   Área %d%%   Crítico %d%%" % [roundi(s.vida_max), roundi(s.dano * 100.0),
		roundi(s.velocidade * 100.0), roundi(s.area * 100.0), roundi(s.critico * 100.0)], 8, Color(0.82, 0.85, 0.95))
	var arma := Dados.item(str(heroi.arma))
	var esp: Dictionary = Dados.json("especiais").get(str(heroi.especial), {})
	_txt(Vector2(0, 308), "Arma: %s   Especial (E): %s" % [str(arma.get("nome", heroi.arma)), str(esp.get("nome", "-"))], 8, Color(1, 0.9, 0.5))
	var b := _botao()
	var pulsa := 0.5 + 0.5 * sin(_t * 4.0)
	var sel_b: bool = linha == _linhas.size() - 1
	_tela.draw_rect(b, Color(0.35, 0.25, 0.08).lerp(Color(0.5, 0.36, 0.1), pulsa if sel_b else 0.3))
	_tela.draw_rect(b, Color(1, 0.85, 0.35) if sel_b else Color(0.6, 0.5, 0.25), false, 2.0 if sel_b else 1.0)
	_txt(Vector2(b.position.x, b.position.y + 12), "Criar e jogar", 8, Color(1, 0.92, 0.7), b.size.x)
	if _msg_t > 0.0:
		_txt(Vector2(0, 346), _msg, 8, Color(1, 0.6, 0.5))
	else:
		_txt(Vector2(0, 346), "Cima/baixo: linha   Esq/dir: trocar   Enter: criar   Esc: voltar", 8, Color(0.55, 0.55, 0.62))


func _desenhar_linha(i: int, l: Dictionary, r: Dictionary, c: Dictionary) -> void:
	var y := LINHA_Y + i * LINHA_H
	var ativo := i == linha
	if ativo:
		_tela.draw_rect(_rect_linha(i), Color(0.2, 0.17, 0.08, 0.9))
		_tela.draw_rect(_rect_linha(i), Color(1, 0.85, 0.3), false, 1.0)
	var rotulo := ""
	var valor := ""
	var cor_v := Color.WHITE
	var setas := true
	match str(l.t):
		"nome":
			rotulo = "Nome"
			valor = _nome_txt + ("_" if ativo and int(_t * 2) % 2 == 0 else "")
			if _nome_txt == "" and not ativo:
				valor = "(digite um nome)"
				cor_v = Color(0.5, 0.52, 0.6)
			setas = false
		"raca":
			rotulo = "Raça"
			valor = str(r.get("nome", ""))
		"classe":
			rotulo = "Classe"
			valor = str(c.get("nome", ""))
		"attr":
			rotulo = str(Criacao.atributos().get(l.k, {}).get("nome", l.k))
			setas = false
		"defeito":
			rotulo = "Defeito"
			valor = "Nenhum" if _defeito == 0 else str(Criacao.defeitos().get(Criacao.lista_defeitos()[_defeito - 1], {}).get("nome", ""))
			if _defeito > 0:
				cor_v = Color(1, 0.65, 0.5)
				valor += "  (+%d pts)" % int(Criacao.defeitos()[Criacao.lista_defeitos()[_defeito - 1]].get("pontos", 0))
		"pal":
			rotulo = str(Dados.json("aparencia").get("rotulos", {}).get(l.k, l.k))
			setas = false
	_txt(Vector2(COL_ROTULO, y), rotulo, 8, Color(1, 0.92, 0.6) if ativo else Color(0.7, 0.74, 0.86), 90, HORIZONTAL_ALIGNMENT_LEFT)
	var seta := Color(1, 0.85, 0.3) if ativo else Color(0.45, 0.47, 0.6)
	if setas:
		_txt(Vector2(COL_VALOR, y), "<", 8, seta, 20, HORIZONTAL_ALIGNMENT_LEFT)
		_txt(Vector2(COL_VALOR + COL_VALOR_W - 14, y), ">", 8, seta, 20, HORIZONTAL_ALIGNMENT_LEFT)
		_txt(Vector2(COL_VALOR + 18, y), valor, 8, cor_v, COL_VALOR_W - 36, HORIZONTAL_ALIGNMENT_LEFT)
	elif str(l.t) == "attr":
		var n := int(ficha.pontos[l.k])
		var mx := int(Criacao.atributos().get(l.k, {}).get("max", 6))
		_txt(Vector2(COL_VALOR, y), "<", 8, seta, 20, HORIZONTAL_ALIGNMENT_LEFT)
		for p in mx:
			var q := Rect2(COL_VALOR + 18 + p * 16, y - 8, 12, 9)
			_tela.draw_rect(q, Color(0.95, 0.75, 0.25) if p < n else Color(0.16, 0.17, 0.25))
			_tela.draw_rect(q, Color(0.4, 0.4, 0.5), false, 1.0)
		_txt(Vector2(COL_VALOR + 18 + mx * 16 + 2, y), ">", 8, seta, 20, HORIZONTAL_ALIGNMENT_LEFT)
		_txt(Vector2(COL_VALOR + 18 + mx * 16 + 16, y), str(n), 8, Color.WHITE, 24, HORIZONTAL_ALIGNMENT_LEFT)
	elif str(l.t) == "pal":
		var cs := Paleta.cores(str(l.k))
		for j in cs.size():
			var q := Rect2(COL_VALOR + j * 28, y - 9, 24, 11)
			_tela.draw_rect(q, Paleta.cor(str(l.k), j))
			var marcado: bool = j == int(ficha.paleta[l.k])
			_tela.draw_rect(q.grow(1) if marcado else q, Color.WHITE if marcado else Color(0.1, 0.1, 0.14), false, 2.0 if marcado else 1.0)
	else:
		_txt(Vector2(COL_VALOR, y), valor, 8, cor_v, COL_VALOR_W, HORIZONTAL_ALIGNMENT_LEFT)


func _desenhar_previa(heroi: Dictionary) -> void:
	_tela.draw_rect(Rect2(362, 40, 268, 184), Color(0.1, 0.1, 0.17))
	_tela.draw_rect(Rect2(362, 40, 268, 184), Color(0.3, 0.33, 0.48), false, 1.0)
	var pal: Dictionary = ficha.paleta
	var corpo := Paleta.textura(str(heroi.sprite), "corpo", pal)
	var cab := Paleta.textura(str(heroi.sprite), "camadas/cabelo", pal)
	if corpo:
		var dst := Rect2(362 + 134 - 66, 46, 132, 174)
		_tela.draw_texture_rect_region(corpo, dst, Rect2(0, 0, 44, 58))
		if cab:
			_tela.draw_texture_rect_region(cab, dst, Rect2(0, 0, 44, 58))
	var rosto := Paleta.textura(str(heroi.sprite), "rosto", pal)
	if rosto:
		_tela.draw_texture_rect_region(rosto, Rect2(568, 46, 56, 56), Rect2(0, 0, 52, 52))
	_txt(Vector2(366, 56), str(heroi.nome) if str(ficha.nome) != "" else "Sem nome", 8, Color(1, 0.95, 0.7), 190, HORIZONTAL_ALIGNMENT_LEFT)
	_txt(Vector2(366, 68), str(Criacao.racas().get(_raca_id(), {}).get("curto", "")) + " " + str(Criacao.classes().get(_classe_id(), {}).get("nome", "")), 8, Color(0.6, 0.85, 1), 190, HORIZONTAL_ALIGNMENT_LEFT)
	_txt(Vector2(0, 216), "prévia ao vivo", 8, Color(0.5, 0.52, 0.62), 360 + 268 - 6, HORIZONTAL_ALIGNMENT_RIGHT)


## Texto de ajuda da linha escolhida: o que ela dá e tira.
func _descricao(l: Dictionary, r: Dictionary, c: Dictionary) -> String:
	match str(l.t):
		"nome":
			return "Até %d letras. É o nome que os outros jogadores veem." % int(Dados.json("aparencia").get("nome_max", 12))
		"raca":
			return str(r.get("descricao", "")) + "\n" + _linhas_de(Criacao.descrever(r.get("bonus", {})) + Criacao.descrever(r.get("fraquezas", {})))
		"classe":
			return str(c.get("descricao", "")) + "\n" + _linhas_de(Criacao.descrever(c.get("bonus", {})))
		"attr":
			var a: Dictionary = Criacao.atributos().get(l.k, {})
			var ef := {}
			for k in a.get("efeito", {}):
				ef[k] = a.efeito[k]
			return str(a.get("descricao", "")) + "\nCada ponto: " + _linhas_de(Criacao.descrever(ef))
		"defeito":
			if _defeito == 0:
				return "Sem defeito. Escolher um dá pontos extras de atributo em troca de um problema."
			var d: Dictionary = Criacao.defeitos().get(Criacao.lista_defeitos()[_defeito - 1], {})
			return str(d.get("descricao", "")) + "\n" + _linhas_de(Criacao.descrever(d.get("efeito", {})))
		"pal":
			return "Troca as cores do corpo. A prévia ao lado muda na hora."
	return "Enter cria o herói e já começa a corrida."


func _linhas_de(l: Array) -> String:
	return ", ".join(l.map(func(x): return str(x[0])))

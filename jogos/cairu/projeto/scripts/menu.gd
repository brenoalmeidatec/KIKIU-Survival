extends Control
## Tela inicial: continuar, novo jogo, capítulos, opções e sair.

signal escolheu(capitulo: Dictionary, estado: Dictionary)

const Personagem := preload("res://scripts/personagem.gd")
const Opcoes := preload("res://scripts/opcoes.gd")
const Painel := preload("res://scripts/painel.gd")

var _capitulos: Array = []
var _itens: Array = []     # [{texto, acao, ativo, dado, info}]
var _labels: Array[Label] = []
var _sel := 0
var _tela := "principal"
var _caixa := VBoxContainer.new()
var _info := Label.new()
var _ocupado := false
var _pessoas: Array = []
var _cidade := Control.new()
var _janelas: Array = []    # [Rect2, acesa]
var _t := 0.0
var _titulo: Label
var _endereco := LineEdit.new()   # jogo online: endereço da sala
var _online_cap: Dictionary = {}  # anfitrião: capítulo escolhido
var _espera_t := 0.0              # cliente: tempo tentando conectar


func _ready() -> void:
	size = Vector2(480, 270)
	# céu de fim de tarde em Salvador, estrelas, prédios com janelas acendendo
	var ceu := ColorRect.new()
	ceu.size = size
	var mc := ShaderMaterial.new()
	mc.shader = Visual.shader("ceu")
	ceu.material = mc
	add_child(ceu)
	if Visual.ligado():
		var est := Visual.particulas({"tipo": "estrelas", "x": 0, "y": 0, "w": 480, "h": 140, "quantidade": 50})
		est.z_index = 0
		add_child(est)
	_cidade.size = size
	_cidade.draw.connect(_desenhar_cidade)
	add_child(_cidade)
	_montar_cidade()
	add_child(Visual.criar_pos(3))

	var titulo := Label.new()
	_titulo = titulo
	titulo.text = "JOGO"
	titulo.add_theme_font_size_override("font_size", 32)
	titulo.add_theme_color_override("font_color", Color("ffd34e"))
	titulo.add_theme_color_override("font_shadow_color", Color("2a2fa8"))
	titulo.add_theme_constant_override("shadow_offset_x", 3)
	titulo.add_theme_constant_override("shadow_offset_y", 3)
	titulo.position = Vector2(176, 22)
	add_child(titulo)
	var sub := Label.new()
	sub.text = "histórias de verdade"
	sub.add_theme_color_override("font_color", Color("a9b0d6"))
	sub.position = Vector2(160, 62)
	add_child(sub)

	var fundo_menu := Panel.new()
	fundo_menu.add_theme_stylebox_override("panel", Visual.painel(Color(0.05, 0.06, 0.17, 0.85)))
	Visual.borda_interna(fundo_menu)
	fundo_menu.position = Vector2(40, 80)
	fundo_menu.size = Vector2(400, 150)
	add_child(fundo_menu)
	_caixa.position = Vector2(54, 87)
	_caixa.add_theme_constant_override("separation", 4)
	add_child(_caixa)
	_info.add_theme_color_override("font_color", Color("6b7299"))
	_info.add_theme_constant_override("line_spacing", 4)
	_info.position = Vector2(54, 190)
	add_child(_info)

	var dica := Label.new()
	dica.text = "setas: escolher   %s: confirmar   F11: tela cheia" % Controles.tecla("interagir")
	dica.add_theme_color_override("font_color", Color("6b7299"))
	dica.position = Vector2(48, 258)
	add_child(dica)

	var x := 20.0
	for k in Dados.NOMES:
		var p := Personagem.new()
		p.configurar(k, "direita")
		p.position = Vector2(x, 248)
		p.andando = true
		add_child(p)
		_pessoas.append(p)
		x += 62

	_endereco.position = Vector2(54, 150)
	_endereco.size = Vector2(372, 18)
	_endereco.placeholder_text = "ex.: abc-123.gl.at.ply.gg:45678"
	_endereco.visible = false
	_endereco.text_submitted.connect(func(_t): _conectar())
	add_child(_endereco)
	Rede.conectou.connect(_rede_conectou)
	Rede.mudou.connect(_rede_mudou)
	Rede.entrou_no_jogo.connect(_rede_entrou)

	_capitulos = Dados.capitulos()
	Jogo.tocar_musica("menu")
	_principal()


func _montar_cidade() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 1905
	var x := -10
	while x < 490:
		var w := rnd.randi_range(30, 64)
		var h := rnd.randi_range(40, 110)
		var r := Rect2(x, 236 - h, w, h)
		for wy in range(int(r.position.y) + 6, 230, 9):
			for wx in range(int(r.position.x) + 4, int(r.end.x) - 4, 7):
				_janelas.append([Rect2(wx, wy, 3, 4), rnd.randf() < 0.35])
		_janelas.append([r, -1])
		x += w + rnd.randi_range(-4, 6)


func _desenhar_cidade() -> void:
	# lua com brilho
	_cidade.draw_texture_rect(Visual.textura_luz(), Rect2(352, 4, 90, 90), false, Color(1, 0.9, 0.7, 0.35))
	_cidade.draw_circle(Vector2(397, 49), 13, Color("fff1c8"))
	_cidade.draw_circle(Vector2(402, 45), 11, Color(0.16, 0.1, 0.3, 0.25))
	for j in _janelas:
		if j[1] is int:
			_cidade.draw_rect(j[0], Color("0b0d24"))
			_cidade.draw_rect(Rect2(j[0].position, Vector2(j[0].size.x, 2)), Color("1a1d42"))
	for j in _janelas:
		if j[1] is bool and j[1]:
			_cidade.draw_rect(j[0], Color("ffd879"))
	# chão
	_cidade.draw_rect(Rect2(0, 236, 480, 34), Color("141634"))
	_cidade.draw_rect(Rect2(0, 236, 480, 2), Color("2a2f6a"))


func _process(delta: float) -> void:
	_t += delta
	_process_online(delta)
	for p in _pessoas:
		p.position.x += 22.0 * delta
		if p.position.x > 500:
			p.position.x -= 520
	if _titulo:
		_titulo.position.y = 22 + round(sin(_t * 1.6) * 2.0)
	# de vez em quando uma janela acende ou apaga
	if randf() < delta * 3.0 and not _janelas.is_empty():
		var j = _janelas.pick_random()
		if j[1] is bool:
			j[1] = not j[1]
			_cidade.queue_redraw()


func _montar(itens: Array) -> void:
	_itens = itens
	for l in _labels:
		_caixa.remove_child(l)
		l.queue_free()
	_labels.clear()
	for it in itens:
		var l := Label.new()
		_caixa.add_child(l)
		_labels.append(l)
	_sel = 0
	while _sel < _itens.size() - 1 and not _itens[_sel].get("ativo", true):
		_sel += 1
	_marcar()


func _marcar() -> void:
	for i in _labels.size():
		var it: Dictionary = _itens[i]
		var tx: String = it.texto
		if tx.length() > 44:
			tx = tx.left(42) + ".."
		_labels[i].text = ("> " if i == _sel else "  ") + tx
		var cor := Color("ffd34e") if i == _sel else Color("f3efe2")
		if not it.get("ativo", true):
			cor = Color("4a5078")
		_labels[i].add_theme_color_override("font_color", cor)
	Visual.marcar_lista(_labels, _sel)
	var inf: String = _itens[_sel].get("info", "") if _sel < _itens.size() else ""
	var linhas := []
	for l in inf.split("\n"):
		linhas.append(l if l.length() <= 46 else l.left(44) + "..")
	_info.text = "\n".join(linhas)


func _principal() -> void:
	_tela = "principal"
	var itens := []
	if Jogo.tem_save():
		var s := Jogo.ler_save()
		itens.append({"texto": "Continuar", "acao": "continuar",
			"info": "Jogo %d: %s\n%s - %s" % [Jogo.slot, s.get("titulo", ""), s.get("lugar", ""), Jogo.resumo_slot(Jogo.slot)[1]]})
	itens.append({"texto": "Novo jogo", "acao": "novo", "info": "Começa do Capítulo 1 num jogo salvo novo."})
	itens.append({"texto": "Jogos salvos", "acao": "carregar", "info": "Em uso: Jogo %d (são %d)." % [Jogo.slot, Jogo.SLOTS]})
	itens.append({"texto": "Capítulos", "acao": "capitulos", "info": "Do Jogo %d. Dá pra continuar cada um de onde parou." % Jogo.slot})
	itens.append({"texto": "Jogar online", "acao": "online", "info": "Até %d pessoas, cada um no seu PC." % Rede.MAX})
	itens.append({"texto": "Opções", "acao": "opcoes"})
	itens.append({"texto": "Créditos", "acao": "creditos"})
	itens.append({"texto": "Sair", "acao": "sair"})
	_montar(itens)


## modo: "novo" (escolher onde começar), "carregar" (escolher qual usar) ou "apagar".
func _lista_slots(modo: String) -> void:
	_tela = "slots_" + modo
	var itens := []
	for n in range(1, Jogo.SLOTS + 1):
		var r: Array = Jogo.resumo_slot(n)
		var vazio: bool = r[0] == "vazio"
		var info := ""
		match modo:
			"novo":
				info = "Começar aqui." if vazio else "Vai apagar este jogo salvo (%s)." % r[1]
			"carregar":
				info = ("Usar este jogo salvo. Salvo em " + r[1]) if not vazio else ""
			"apagar":
				info = "Apagar este jogo salvo." if not vazio else ""
		itens.append({"texto": "Jogo %d%s: %s" % [n, " *" if n == Jogo.slot else "", r[0]], "acao": "slot_" + modo,
			"dado": n, "ativo": modo == "novo" or not vazio, "info": info})
	if modo == "carregar":
		itens.append({"texto": "Apagar um jogo salvo", "acao": "ir_apagar", "info": "* = em uso"})
	itens.append({"texto": "Voltar", "acao": "voltar", "info": "* = em uso"})
	_montar(itens)
	for i in Jogo.SLOTS:
		if i + 1 == Jogo.slot and _itens[i].get("ativo", true):
			_sel = i
			_marcar()


func _perguntar(texto_sim: String, acao: String, dado, info: String) -> void:
	_tela = "confirmar"
	_montar([
		{"texto": texto_sim, "acao": acao, "dado": dado, "info": info},
		{"texto": "Não", "acao": "voltar", "info": info},
	])
	_sel = 1
	_marcar()


func _lista_capitulos() -> void:
	_tela = "capitulos"
	var itens := []
	for i in _capitulos.size():
		var c: Dictionary = _capitulos[i]
		var arq: String = c.get("_arquivo", "")
		var livre: bool = Jogo.liberado(arq, i) or c.get("sempre_liberado", false)
		var feito: bool = arq in Jogo.progresso.completos
		var parou := Jogo.save_do_capitulo(arq)
		var info := "* = já terminado" if feito else ""
		if not parou.is_empty():
			info = "Parou em: %s (%s)" % [parou.get("lugar", "?"), str(parou.get("data", "")).replace("T", " ").substr(8, 2) + "/" + str(parou.get("data", "")).substr(5, 2)]
		itens.append({"texto": ((c.get("titulo", "?") + (" *" if feito else "") + (" >" if not parou.is_empty() else "")) if livre else "??? (bloqueado)"),
			"acao": "capitulo", "dado": c, "ativo": livre, "info": info})
	itens.append({"texto": "Voltar", "acao": "voltar", "info": "> = dá pra continuar de onde parou"})
	_montar(itens)


func _capitulo_escolhido(c: Dictionary) -> void:
	var parou := Jogo.save_do_capitulo(c.get("_arquivo", ""))
	if parou.is_empty():
		_comecar(c)
		return
	_tela = "confirmar"
	_montar([
		{"texto": "Continuar de onde parou", "acao": "continuar_cap", "dado": c, "info": "%s - %s" % [parou.get("lugar", ""), c.get("titulo", "")]},
		{"texto": "Começar do zero", "acao": "zerar_cap", "dado": c, "info": "Só este capítulo volta pro começo."},
		{"texto": "Voltar", "acao": "capitulos"},
	])


func _comecar(capitulo: Dictionary) -> void:
	Jogo.apagar_capitulo(capitulo.get("_arquivo", ""))
	Jogo.historico.clear()
	escolheu.emit(capitulo, {})


# ======================================================== jogo online

func _online() -> void:
	_tela = "online"
	_endereco.visible = false
	if Rede.online():
		Rede.sair()
	_montar([
		{"texto": "Criar sala (eu sou o anfitrião)", "acao": "criar_sala",
			"info": "Você escolhe o capítulo e puxa as cenas.\nOs amigos entram com o seu endereço."},
		{"texto": "Entrar na sala de um amigo", "acao": "entrar_sala", "info": "Precisa do endereço que o anfitrião passar."},
		{"texto": "Como jogar online", "acao": "como_online", "info": "Passo a passo (também está no LEIA-ME)."},
		{"texto": "Voltar", "acao": "voltar"},
	])


## Lista de personagens: os que já estão com alguém aparecem apagados.
func _escolher_personagem(acao: String) -> void:
	_tela = "personagem_" + acao
	var ocupados := Rede.ocupados()
	var itens := []
	for k in Rede.ELENCO:
		var livre: bool = not k in ocupados
		itens.append({"texto": Dados.nome(k) + ("" if livre else "  (já tem gente)"), "acao": acao, "dado": k, "ativo": livre})
	itens.append({"texto": Rede.NOME_FIGURANTE, "acao": acao, "dado": "figurante"})
	itens.append({"texto": "Voltar", "acao": "sair_online"})
	_montar(itens)
	_info.text = ""


func _caps_online() -> void:
	_tela = "caps_online"
	var itens := []
	for i in _capitulos.size():
		var c: Dictionary = _capitulos[i]
		var arq: String = c.get("_arquivo", "")
		var livre: bool = Jogo.liberado(arq, i) or c.get("sempre_liberado", false)
		var parou := Jogo.save_do_capitulo(arq)
		itens.append({"texto": c.get("titulo", "?") if livre else "??? (bloqueado)", "acao": "cap_online", "dado": c, "ativo": livre,
			"info": ("Continua de: " + str(parou.get("lugar", ""))) if not parou.is_empty() else "Começa do começo."})
	itens.append({"texto": "Voltar", "acao": "online"})
	_montar(itens)


func _abrir_sala(personagem: String) -> void:
	var erro := Rede.criar_sala(personagem, int(Jogo.opcoes.get("porta_online", Rede.PORTA)))
	if erro != "":
		_online()
		_info.text = erro
		return
	var c := _online_cap
	var parou := Jogo.save_do_capitulo(c.get("_arquivo", ""))
	Jogo.historico.clear()
	escolheu.emit(c, parou)


func _tela_endereco() -> void:
	_tela = "endereco"
	_montar([
		{"texto": "Conectar", "acao": "conectar", "info": ""},
		{"texto": "Voltar", "acao": "online"},
	])
	_info.text = "Endereço da sala (o anfitrião te passa)\ne aperte Enter:"
	_info.position.y = 120
	_endereco.text = str(Jogo.opcoes.get("ultimo_endereco", ""))
	_endereco.visible = true
	_endereco.grab_focus()
	_endereco.caret_column = _endereco.text.length()


func _conectar() -> void:
	var e := _endereco.text.strip_edges()
	_endereco.release_focus()
	_endereco.visible = false
	_info.position.y = 190
	var erro := Rede.entrar(e)
	if erro != "":
		_tela_endereco()
		_info.text = erro
		return
	Jogo.opcoes["ultimo_endereco"] = e
	Jogo.salvar_opcoes()
	_tela = "conectando"
	_espera_t = 12.0
	_montar([{"texto": "Cancelar", "acao": "online"}])
	_info.text = "Procurando a sala %s..." % e


func _rede_conectou(ok: bool, msg: String) -> void:
	if ok:
		_info.text = "Achei a sala! Pegando a lista..."
		return
	if _tela.begins_with("personagem_entrar"):
		_escolher_personagem("entrar_como")
		_info.text = msg
		return
	_online()
	_info.text = msg


func _rede_mudou() -> void:
	if _tela == "conectando" and Rede.cliente():
		_escolher_personagem("entrar_como")
		_info.text = "Quem você vai ser?"
	elif _tela == "personagem_entrar_como":
		var s := _sel
		_escolher_personagem("entrar_como")
		_sel = mini(s, _itens.size() - 1)
		_marcar()


func _rede_entrou(estado: Dictionary) -> void:
	for c in _capitulos:
		if c.get("_arquivo", "") == estado.get("capitulo", ""):
			Jogo.historico.clear()
			escolheu.emit(c, estado)
			return
	Rede.sair()
	_online()
	_info.text = "O anfitrião está num capítulo que este jogo não tem.\nAtualize o jogo (zip novo) e tente de novo."


func _como_online() -> String:
	return "[color=#ffd34e]Jogar online (até %d pessoas)[/color]\n" % Rede.MAX + \
		"Um de vocês é o [color=#ffd34e]anfitrião[/color]: o jogo dele vira a sala. Todo mundo precisa do MESMO zip do jogo.\n\n" + \
		"[color=#ffd34e]Na mesma casa (mesmo Wi-Fi)[/color]\nO anfitrião cria a sala. Os outros entram com o IP dele + :7777 (ex.: 192.168.0.10:7777). O IP aparece no Windows em Configurações > Rede > Propriedades.\n\n" + \
		"[color=#ffd34e]Cada um na sua casa (grátis, com o playit.gg)[/color]\n1. O anfitrião abre o abrir_tunel_playit.bat (na pasta do jogo). Na 1a vez ele baixa o programa do playit e pede pra criar uma conta grátis.\n2. No site do playit: Add Tunnel > tipo UDP > porta local 7777.\n3. O site mostra um endereço tipo abc-123.gl.at.ply.gg:45678. Passe ele pros amigos.\n4. O anfitrião cria a sala no jogo; os amigos escolhem Entrar e digitam o endereço.\nO playit precisa ficar aberto enquanto jogam.\n\n" + \
		"[color=#ffd34e]Como funciona[/color]\nCada um escolhe um personagem (sem repetir). Todo mundo anda junto pelos mapas. Só o anfitrião puxa conversa: quando ele começa uma cena, todo mundo vai pro lugar dele e vê a mesma cena (escolhas e minijogos são dele). Só o jogo do anfitrião salva."


func _process_online(delta: float) -> void:
	if _tela == "conectando":
		_espera_t -= delta
		if _espera_t <= 0.0:
			Rede.sair()
			_online()
			_info.text = "Não achei a sala (demorou demais).\nConfira o endereço e se a sala está aberta."


func _executar(it: Dictionary) -> void:
	match it.acao:
		"online", "sair_online":
			_online()
		"criar_sala":
			_caps_online()
		"cap_online":
			_online_cap = it.dado
			_escolher_personagem("anfitriao_como")
			_info.text = "Quem você vai ser?"
		"anfitriao_como":
			_abrir_sala(it.dado)
		"entrar_sala":
			_tela_endereco()
		"conectar":
			_conectar()
		"entrar_como":
			Rede.escolher(it.dado)
			_info.text = "Entrando..."
		"como_online":
			_ocupado = true
			var po := Painel.new()
			po.titulo = "Como jogar online"
			po.texto = _como_online()
			po.fechou.connect(_fim_opcoes)
			add_child(po)
		"continuar":
			var s := Jogo.ler_save()
			for c in _capitulos:
				if c.get("_arquivo", "") == s.get("capitulo", ""):
					escolheu.emit(c, s)
					return
			_info.text = "Não achei o capítulo salvo."
		"novo":
			_lista_slots("novo")
		"carregar":
			_lista_slots("carregar")
		"ir_apagar":
			_lista_slots("apagar")
		"slot_novo":
			if Jogo.slot_vazio(it.dado):
				_novo_em(it.dado)
			else:
				_perguntar("Sim, apagar o Jogo %d" % it.dado, "novo_confirmado", it.dado, "O Jogo %d vai ser apagado." % it.dado)
		"novo_confirmado":
			_novo_em(it.dado)
		"slot_carregar":
			Jogo.usar_slot(it.dado)
			Jogo.historico.clear()
			_principal()
			_info.text = "Jogo %d em uso." % it.dado
		"slot_apagar":
			_perguntar("Sim, apagar o Jogo %d" % it.dado, "apagar_confirmado", it.dado, "Não tem como desfazer.")
		"apagar_confirmado":
			Jogo.apagar_slot(it.dado)
			_lista_slots("carregar")
			_info.text = "Jogo %d apagado." % it.dado
		"capitulos":
			_lista_capitulos()
		"capitulo":
			_capitulo_escolhido(it.dado)
		"continuar_cap":
			Jogo.historico.clear()
			escolheu.emit(it.dado, Jogo.save_do_capitulo(it.dado.get("_arquivo", "")))
		"zerar_cap":
			_comecar(it.dado)
		"opcoes":
			_ocupado = true
			var o := Opcoes.new()
			o.fechou.connect(_fim_opcoes)
			add_child(o)
		"voltar":
			_principal()
		"creditos":
			_ocupado = true
			var p := Painel.new()
			p.titulo = "Créditos"
			p.texto = _texto_creditos()
			p.fechou.connect(_fim_opcoes)
			add_child(p)
		"sair":
			get_tree().quit()


func _novo_em(n: int) -> void:
	Jogo.apagar_slot(n)
	Jogo.usar_slot(n)
	if not _capitulos.is_empty():
		_comecar(_capitulos[0])


func _fim_opcoes() -> void:
	_ocupado = false


func _unhandled_input(event: InputEvent) -> void:
	if _ocupado or _itens.is_empty():
		return
	var n := _itens.size()
	if event.is_action_pressed("cima") or event.is_action_pressed("baixo"):
		var d := -1 if event.is_action_pressed("cima") else 1
		for k in n:
			_sel = (_sel + d + n) % n
			if _itens[_sel].get("ativo", true):
				break
		Jogo.som("cursor")
		_marcar()
	elif event.is_action_pressed("voltar") and _tela != "principal":
		Jogo.som("fechar")
		_endereco.visible = false
		_info.position.y = 190
		if _tela == "online":
			_principal()
		elif _tela == "caps_online" or _tela == "endereco" or _tela == "conectando" or _tela.begins_with("personagem_"):
			_online()
		else:
			_principal()
	elif event.is_action_pressed("interagir"):
		var it: Dictionary = _itens[_sel]
		if it.get("ativo", true):
			Jogo.som("confirmar")
			_executar(it)


## Créditos: capitulos/creditos.txt (dá pra editar), ou o texto padrão.
func _texto_creditos() -> String:
	var t := Dados.ler_texto("creditos.txt")
	if t != "":
		return t
	return "[color=#ffd34e]JOGO[/color]\nHistórias de verdade de quem trabalhou na Cairu, em Salvador.\n\n[color=#ffd34e]Histórias[/color]\nBreno\n\n[color=#ffd34e]Elenco[/color]\nBreno, Nicão, Lucas, João, Matheus, Beto, Lukako e Fábio\n\n[color=#ffd34e]Feito com[/color]\nGodot Engine (godotengine.org)\nPaleta Endesga 32 (Lospec)\nFonte Press Start 2P (OFL)\nMúsicas e efeitos feitos do zero para o jogo"

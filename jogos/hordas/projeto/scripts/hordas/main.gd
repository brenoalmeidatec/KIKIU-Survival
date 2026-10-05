extends Node
## Telas do jogo: título -> escolher herói -> partida -> resultado.
## Online: título -> criar sala / entrar (endereço) -> sala (cada um escolhe o herói) -> partida.
## Opções de linha de comando (pra teste): --bot  --heroi=lucas  --pular=300 (começa no segundo 300)
##   --sair=60 (fecha depois de 60 s de partida)  --fotos=pasta (salva prints a cada 20 s)
##   --online=host [--jogadores=2] (abre a sala e começa sozinho quando tiver 2)
##   --online=join --endereco=127.0.0.1:7777  (entra na sala)

const Arena := preload("res://scripts/hordas/arena.gd")
const W := 640.0
const H := 360.0
const SAVE := "user://recordes.json"
const SAVE_ONLINE := "user://online.json"
const TelaOpcoes := preload("res://scripts/hordas/tela_opcoes.gd")
const OPCOES := ["Jogar sozinho", "Criar sala", "Entrar em sala", "Opções", "Créditos", "Sair"]
const BETA := [1, 2]         # opções do online: ainda em teste, ganham o selo BETA no menu

const TECLAS := {
	"cima": [KEY_W, KEY_UP], "baixo": [KEY_S, KEY_DOWN], "esquerda": [KEY_A, KEY_LEFT], "direita": [KEY_D, KEY_RIGHT],
	"dash": [KEY_SPACE, KEY_SHIFT], "confirmar": [KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_Z], "voltar": [KEY_ESCAPE],
	"resortear": [KEY_R], "tela_cheia": [KEY_F11],
}
const CONTROLE := {
	"cima": [JOY_BUTTON_DPAD_UP], "baixo": [JOY_BUTTON_DPAD_DOWN], "esquerda": [JOY_BUTTON_DPAD_LEFT], "direita": [JOY_BUTTON_DPAD_RIGHT],
	"dash": [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER], "confirmar": [JOY_BUTTON_A], "voltar": [JOY_BUTTON_START], "resortear": [JOY_BUTTON_Y],
}

var _tela := Control.new()
var _camada := CanvasLayer.new()
var _estado := "titulo"      # titulo, herois, partida, fim
var _sel := 0
var _arena: Node2D
var _resumo := {}
var _recordes := {}
var _t := 0.0
var _args := {}
var _novo_recorde := false
var _endereco := ""          # último endereço digitado (fica salvo)
var _msg := ""               # aviso nas telas do online (erro, conectando...)
var _comecou_teste := false
var _caiu_teste := false


func _ready() -> void:
	_teclas()
	_ler_args()
	_camada.layer = 20
	add_child(_camada)
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	_camada.add_child(_tela)
	_recordes = _ler_recordes()
	_endereco = _ler_endereco()
	Rede.mudou.connect(_rede_mudou)
	Rede.conectou.connect(_rede_conectou)
	Rede.comecou.connect(func(op): _comecar(Rede.heroi_de(Rede.eu()), op, true))
	Rede.caiu.connect(_rede_caiu)
	if _args.has("rapido"):
		Engine.time_scale = float(_args.rapido)
	if _args.has("print_tela"):
		_print_tela(str(_args.print_tela))
	elif _args.has("online"):
		_online_teste()
	elif _args.has("bot") or _args.has("heroi"):
		_comecar(str(_args.get("heroi", "hazaki")))
	else:
		Som.musica("menu")


func _teclas() -> void:
	for acao in TECLAS:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao, 0.4)
		for k in TECLAS[acao]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(acao, e)
		for b in CONTROLE.get(acao, []):
			var j := InputEventJoypadButton.new()
			j.button_index = b
			InputMap.action_add_event(acao, j)
	for par in [["esquerda", JOY_AXIS_LEFT_X, -1.0], ["direita", JOY_AXIS_LEFT_X, 1.0], ["cima", JOY_AXIS_LEFT_Y, -1.0], ["baixo", JOY_AXIS_LEFT_Y, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = par[1]
		m.axis_value = par[2]
		InputMap.action_add_event(par[0], m)


func _ler_args() -> void:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--"):
			var p: PackedStringArray = a.substr(2).split("=", true, 1)
			_args[p[0]] = p[1] if p.size() > 1 else true


func _ler_recordes() -> Dictionary:
	if not FileAccess.file_exists(SAVE):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	return d if d is Dictionary else {}


func _salvar_recordes() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_recordes, " "))


func _herois() -> Array:
	return Dados.json("herois").get("lista", [])


func _process(dt: float) -> void:
	_t += dt
	_tela.queue_redraw()
	if Input.is_action_just_pressed("tela_cheia"):
		# vira a opção "Tela cheia" (o Config troca a janela e lembra pra próxima vez)
		var modo := DisplayServer.window_get_mode()
		var cheia := modo == DisplayServer.WINDOW_MODE_FULLSCREEN or modo == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		Config.definir("tela_cheia", not cheia)
	match _estado:
		"titulo":
			if Input.is_action_just_pressed("cima"):
				_sel = (_sel - 1 + OPCOES.size()) % OPCOES.size()
				Som.tocar("cursor")
			elif Input.is_action_just_pressed("baixo"):
				_sel = (_sel + 1) % OPCOES.size()
				Som.tocar("cursor")
			elif Input.is_action_just_pressed("confirmar") or Input.is_action_just_pressed("dash"):
				Som.tocar("confirmar")
				_msg = ""
				match OPCOES[_sel]:
					"Jogar sozinho":
						_estado = "herois"
						_sel = 0
					"Criar sala":
						_criar_sala()
					"Entrar em sala":
						_estado = "endereco"
					"Opções":
						_abrir_opcoes()
					"Créditos":
						_estado = "creditos"
					"Sair":
						get_tree().quit()
		"creditos":
			if Input.is_action_just_pressed("voltar") or Input.is_action_just_pressed("confirmar"):
				Som.tocar("confirmar")
				_estado = "titulo"
				_sel = OPCOES.find("Créditos")
		"endereco":
			pass   # o teclado é lido em _input (campo de texto)
		"conectando":
			if Input.is_action_just_pressed("voltar"):
				Rede.sair()
				_estado = "endereco"
		"sala":
			_sala()
		"herois":
			var n := _herois().size()
			if Input.is_action_just_pressed("esquerda"):
				_sel = (_sel - 1 + n) % n
				Som.tocar("cursor")
			elif Input.is_action_just_pressed("direita"):
				_sel = (_sel + 1) % n
				Som.tocar("cursor")
			elif Input.is_action_just_pressed("confirmar"):
				Som.tocar("confirmar")
				_comecar(_herois()[_sel])
			elif Input.is_action_just_pressed("voltar"):
				_estado = "titulo"
				_sel = 0
		"partida":
			_teste()
		"fim":
			if _t > 1.0 and (Input.is_action_just_pressed("confirmar") or Input.is_action_just_pressed("voltar")):
				Som.tocar("confirmar")
				Rede.sair()
				_estado = "titulo"
				_sel = 0
				Som.musica("menu")


## Online: as opções de teste (fase, pular, build) vêm do anfitrião, iguais pra todos.
func _comecar(heroi: String, opcoes := {}, online := false) -> void:
	Dados.recarregar()
	var o: Dictionary = opcoes if online else _args
	_arena = Arena.new()
	_arena.heroi_id = heroi
	_arena.bot = _args.has("bot")
	_arena.eh_online = online
	_arena.terminou.connect(_terminou)
	add_child(_arena)
	if o.has("estresse") and not online:
		for i in int(o.estresse):
			_arena.inimigos.criar(["bug", "popup", "spam", "trojan"].pick_random(), Vector2.from_angle(randf() * TAU) * randf_range(150, 420))
	if o.has("fase"):
		for _i in int(o.fase) - 1:
			_arena.diretor.proxima_fase()
		_arena.chao.nova_fase()
	if o.has("pular"):
		_arena.diretor.tempo = float(o.pular)
		_arena.diretor.t_fase = float(o.pular)
	if o.has("build"):
		_arena.dar_build_teste(int(o.build))
	if o.has("duelo") and not online:
		_arena.iniciar_duelo_teste(int(o.duelo))
	_estado = "partida"
	_t = 0.0


# ---------- online: sala ----------

func _ler_endereco() -> String:
	if not FileAccess.file_exists(SAVE_ONLINE):
		return ""
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_ONLINE))
	return str(d.get("endereco", "")) if d is Dictionary else ""


func _salvar_endereco() -> void:
	var f := FileAccess.open(SAVE_ONLINE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"endereco": _endereco}))


func _abrir_opcoes() -> void:
	_estado = "opcoes"   # a tela de Opções cuida das teclas; o título fica parado atrás
	var t := TelaOpcoes.new()
	add_child(t)
	t.fechou.connect(func():
		_estado = "titulo"
		_sel = OPCOES.find("Opções"))


func _criar_sala() -> void:
	var err := Rede.criar_sala(Rede.heroi_livre(str(_args.get("heroi", ""))), int(_args.get("porta", Rede.PORTA)))
	if err != "":
		_msg = err
		return
	_estado = "sala"


func _entrar() -> void:
	var err := Rede.entrar(_endereco)
	if err != "":
		_msg = err
		return
	_salvar_endereco()
	_msg = "Conectando em %s..." % _endereco
	_estado = "conectando"


## Chegou a lista da sala: o cliente pede o primeiro herói livre.
func _rede_mudou() -> void:
	if _estado == "conectando" and Rede.cliente() and not Rede.jogadores.is_empty() and not Rede.jogadores.has(Rede.eu()):
		Rede.escolher(Rede.heroi_livre(str(_args.get("heroi", ""))))


func _rede_conectou(ok: bool, msg: String) -> void:
	if ok:
		_estado = "sala"
		_msg = ""
	elif _estado == "sala":
		_msg = msg   # trocou pra um herói ocupado: continua na sala
	else:
		Rede.sair()
		_msg = msg
		_estado = "endereco"
		if _args.has("online"):
			print("ONLINE recusado: ", msg)
			get_tree().quit(1)


func _rede_caiu(msg: String) -> void:
	if _arena and _arena.acabou:
		return   # a partida já acabou: deixa o resultado aparecer (a sala fechar agora é normal)
	if _arena:
		_arena.queue_free()
		_arena = null
	get_tree().paused = false
	_estado = "titulo"
	_sel = 0
	_msg = msg
	Som.musica("menu")
	if _args.has("sair"):
		print("ONLINE caiu: ", msg)
		get_tree().quit()


func _sala() -> void:
	if not Rede.online():
		_estado = "titulo"
		return
	if Input.is_action_just_pressed("esquerda") or Input.is_action_just_pressed("direita"):
		var passo := -1 if Input.is_action_just_pressed("esquerda") else 1
		var tomados := Rede.ocupados(Rede.eu())
		var i := Rede.ELENCO.find(Rede.heroi_de(Rede.eu()))
		for _k in Rede.ELENCO.size():
			i = (i + passo + Rede.ELENCO.size()) % Rede.ELENCO.size()
			if not Rede.ELENCO[i] in tomados:
				Rede.escolher(Rede.ELENCO[i])
				Som.tocar("cursor")
				break
	elif Input.is_action_just_pressed("confirmar") and Rede.anfitriao():
		Som.tocar("confirmar")
		Rede.comecar()
	elif Input.is_action_just_pressed("voltar"):
		Rede.sair()
		_estado = "titulo"
		_sel = 0
	# teste: o anfitrião começa sozinho quando a sala enche
	if _args.has("online") and Rede.anfitriao() and not _comecou_teste \
			and Rede.jogadores.size() >= int(_args.get("jogadores", 2)):
		_comecou_teste = true
		var op := {}
		for k in ["fase", "pular", "build"]:
			if _args.has(k):
				op[k] = _args[k]
		Rede.comecar(op)


func _online_teste() -> void:
	if str(_args.online) == "host":
		_criar_sala()
	else:
		_endereco = str(_args.get("endereco", "127.0.0.1:%d" % Rede.PORTA))
		_entrar()
	if _msg != "" and _estado != "conectando":
		print("ONLINE erro: ", _msg)
		get_tree().quit(1)


## Campo de texto do endereço: digita, apaga, Ctrl+V cola, Enter conecta, Esc volta.
func _input(e: InputEvent) -> void:
	if _estado != "endereco" or not e is InputEventKey or not e.pressed:
		return
	var k: InputEventKey = e
	get_viewport().set_input_as_handled()
	if k.keycode == KEY_V and k.ctrl_pressed:
		_endereco = (_endereco + DisplayServer.clipboard_get().strip_edges()).left(80)
	elif k.keycode == KEY_BACKSPACE:
		_endereco = _endereco.left(-1)
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		Som.tocar("confirmar")
		_entrar()
	elif k.keycode == KEY_ESCAPE:
		_estado = "titulo"
		_msg = ""
	elif k.unicode > 32 and k.unicode < 127 and _endereco.length() < 80:
		var c := char(k.unicode)
		if c.is_valid_identifier() or c.is_valid_int() or c in [".", ":", "-", "_"]:
			_endereco += c


func _terminou(res: Dictionary) -> void:
	if _arena == null:
		return
	_resumo = res
	_novo_recorde = false
	var h: String = res.heroi
	var rec: Dictionary = _recordes.get(h, {})
	if res.tempo > float(rec.get("tempo", 0)):
		rec["tempo"] = res.tempo
		_novo_recorde = true
	rec["abates"] = maxi(int(rec.get("abates", 0)), res.abates)
	rec["melhor_fase"] = maxi(int(rec.get("melhor_fase", 0)), int(res.get("fase", 1)))
	if res.vitoria:
		rec["vitorias"] = int(rec.get("vitorias", 0)) + 1
	if res.has("duelo"):
		var lg: int = res.duelo.lugar
		rec["melhor_lugar"] = mini(int(rec.get("melhor_lugar", 99)), lg)
		if lg == 1:
			rec["campeao"] = int(rec.get("campeao", 0)) + 1
	_recordes[h] = rec
	_salvar_recordes()
	_arena.queue_free()
	_arena = null
	get_tree().paused = false
	_estado = "fim"
	_t = 0.0
	Som.musica("fim")
	if _args.has("sair"):
		print("RESULTADO ", JSON.stringify(res))
		get_tree().quit()


# ---------- modo de teste ----------

var _prox_log := 0.0
var _prox_foto := 5.0
var _quadros := 0
var _t_quadros := 0.0

func _teste() -> void:
	if _arena == null:
		return
	_quadros += 1
	_t_quadros += get_process_delta_time()
	if _args.has("facil") and not _arena.duelo_ativo:
		# teste: o chefe final nasce quase morto, pra chegar logo no duelo
		for v in _arena.inimigos.lista:
			if v.d.get("final", false) or (v.chefe and v.tipo == _arena.diretor.chefe_fase):
				v.hp = minf(v.hp, 1.0)
	if _args.has("cair") and _t >= float(_args.cair) and _arena.eh_online and not _arena.caido and not _caiu_teste:
		_caiu_teste = true   # teste do reviver: cai uma vez no segundo N (--cair=N)
		_arena.morrer("teste")
	if _args.has("sair") and _t >= _prox_log:
		_prox_log += 5.0
		print("t=%.0f fase=%d partida=%.0f fps=%d vivos=%d nivel=%d abates=%d hp=%.0f proc_ms=%.2f perfil=%s armas=%s passivos=%s duelo=%s" % [
			_t, _arena.diretor.fase_idx + 1, _arena.diretor.tempo, Engine.get_frames_per_second(), _arena.inimigos.vivos(), _arena.nivel, _arena.abates,
			_arena.jogador.hp, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, _arena.perfil,
			_arena.armas.lista.map(func(a): return "%s:%d" % [a.id, a.nivel]), _arena.passivos,
			("%s luta=%.0f vivos=%d raio=%.0f" % [_arena.duelo.estado, _arena.duelo.t_luta, _arena.duelo.vivos().size(), _arena.duelo.raio]) if _arena.duelo_ativo else "-"])
		if _arena.online:
			print("  online: %s peers=%d acertos=%d caido=%s fase=%d entre=%s duelo=%s" % ["anfitriao" if Rede.anfitriao() else "cliente",
				Rede.jogadores.size(), _arena.online.n_tx, _arena.caido, _arena.diretor.fase_idx + 1, _arena.entre_fases,
				_arena.duelo.estado if _arena.duelo_ativo else "-"])
		if _t >= float(_args.sair):
			get_tree().quit()
	if _args.has("fotos") and _t >= _prox_foto:
		_prox_foto += 20.0
		var img := get_viewport().get_texture().get_image()
		img.save_png(str(_args.fotos).path_join("foto_%03d.png" % int(_arena.diretor.tempo)))


# ---------- desenho das telas ----------

func _txt(p: Vector2, s: String, tam := 8, cor := Color.WHITE, larg := W, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var f: Font = Dados.fonte
	_tela.draw_string(f, p + Vector2(1, 1), s, alinhar, larg, tam, Color(0, 0, 0, 0.8))
	_tela.draw_string(f, p, s, alinhar, larg, tam, cor)


## Selo "BETA" ao lado de uma opção do menu (p = canto esquerdo, na linha de base do texto).
func _selo_beta(p: Vector2) -> void:
	var larg := Dados.fonte.get_string_size("BETA", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6
	var r := Rect2(p + Vector2(0, -9), Vector2(larg, 12))
	_tela.draw_rect(r, Color(0.3, 0.15, 0.45))
	_tela.draw_rect(r, Color(0.85, 0.6, 1.0), false, 1.0)
	_txt(p + Vector2(0, 0), "BETA", 8, Color(0.95, 0.85, 1.0), larg)


func _fundo() -> void:
	_tela.draw_rect(Rect2(0, 0, W, H), Color(0.08, 0.07, 0.12))
	# vírus passeando no fundo
	var nomes := ["inimigo_bug", "inimigo_popup", "inimigo_spam", "inimigo_trojan", "inimigo_minerador"]
	for i in 14:
		var tex := Dados.tex(nomes[i % nomes.size()])
		var w := tex.get_width() / 3.0
		var x := fmod(i * 97.0 + _t * (20 + i * 3), W + 80) - 40
		var y := 40 + fmod(i * 53.0, H - 80) + sin(_t * 2 + i) * 6
		_tela.draw_texture_rect_region(tex, Rect2(x, y, w * 2, tex.get_height() * 2), Rect2(w * (int(_t * 4 + i) % 2), 0, w, tex.get_height()), Color(1, 1, 1, 0.25))


func _desenhar() -> void:
	match _estado:
		"titulo":
			_fundo()
			_txt(Vector2(0, 100), "K.I.K.I.U", 32, Color(0.4, 0.65, 1))
			_txt(Vector2(0, 142), "Knights In Kaos, Infinite Upgrades", 10, Color(0.5, 1, 0.5))
			_txt(Vector2(0, 165), "sobreviva à horda e vença o duelo final", 8, Color(0.75, 0.75, 0.85))
			for i in OPCOES.size():
				var sel := i == _sel
				var rotulo: String = ("> " + OPCOES[i] + " <") if sel else OPCOES[i]
				_txt(Vector2(0, 190 + i * 18), rotulo, 8, Color(1, 0.9, 0.4) if sel else Color(0.8, 0.8, 0.8))
				if i in BETA:
					var meia := Dados.fonte.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x / 2
					_selo_beta(Vector2(W / 2 + meia + 6, 190 + i * 18))
			if _sel in BETA and _msg == "":
				_txt(Vector2(0, 302), "Multiplayer em teste: pode ter bugs. O foco agora é o modo sozinho.", 8, Color(0.85, 0.6, 1.0))
			if _msg != "":
				_txt(Vector2(0, 302), _msg, 8, Color(1, 0.6, 0.5))
			_txt(Vector2(0, 340), "Protótipo - WASD/setas, Espaço = dash, Enter = confirmar, F11 = tela cheia", 8, Color(0.5, 0.5, 0.6))
		"opcoes":
			_fundo()   # a tela de Opções desenha por cima (tela_opcoes.gd)
		"creditos":
			_fundo()
			_txt(Vector2(0, 50), "Créditos", 16, Color.WHITE)
			_txt(Vector2(0, 76), "K.I.K.I.U nasceu de uma ideia e virou jogo a quatro mãos.", 8, Color(0.75, 0.75, 0.85))
			_txt(Vector2(0, 110), "BRENO", 10, Color(0.4, 0.65, 1))
			_txt(Vector2(0, 125), "criador: ideia, história, personagens, mecânicas e o motor", 8, Color.WHITE)
			_txt(Vector2(0, 152), "ALISSON", 10, Color(0.5, 1, 0.5))
			_txt(Vector2(0, 167), "arte do Blender virando pixel art, cenários, visual e online", 8, Color.WHITE)
			_txt(Vector2(0, 198), "FEITO COM", 8, Color(1, 0.85, 0.3))
			_txt(Vector2(0, 213), "Godot 4  ·  Blender  ·  Claude Code (um Claude de cada lado)", 8, Color.WHITE)
			_txt(Vector2(0, 240), "Fonte Press Start 2P, de CodeMan38 (licença OFL)", 8, Color(0.6, 0.6, 0.7))
			_txt(Vector2(0, 254), "Músicas e efeitos gerados por código, no próprio projeto", 8, Color(0.6, 0.6, 0.7))
			_txt(Vector2(0, 290), "E valeu a você, que está jogando!", 10, Color(1, 0.6, 0.75))
			_txt(Vector2(0, 335), "Enter/Esc: voltar", 8, Color(0.5, 0.5, 0.6))
		"endereco", "conectando":
			_fundo()
			_txt(Vector2(0, 70), "Entrar em sala", 16, Color.WHITE)
			_txt(Vector2(0, 110), "Endereço que o anfitrião mandou (ex.: nome.gl.at.ply.gg:12345)", 8, Color(0.75, 0.78, 0.85))
			_tela.draw_rect(Rect2(120, 130, 400, 28), Color(0.1, 0.11, 0.18))
			_tela.draw_rect(Rect2(120, 130, 400, 28), Color(1, 0.85, 0.3) if _estado == "endereco" else Color(0.3, 0.35, 0.5), false, 2.0)
			var cursor := "_" if _estado == "endereco" and int(_t * 2) % 2 == 0 else ""
			_txt(Vector2(130, 149), _endereco + cursor, 8, Color.WHITE, 380, HORIZONTAL_ALIGNMENT_LEFT)
			if _msg != "":
				_txt(Vector2(0, 190), _msg, 8, Color(1, 0.6, 0.5) if _estado == "endereco" else Color(0.6, 0.9, 1))
			_txt(Vector2(0, 330), "Ctrl+V: colar   Enter: conectar   Esc: voltar", 8, Color(0.6, 0.6, 0.7))
		"sala":
			_fundo()
			_txt(Vector2(0, 40), "Sala online", 16, Color.WHITE)
			if Rede.anfitriao():
				_txt(Vector2(0, 62), "Você é o anfitrião (porta %d). Abra o abrir_tunel_playit.bat e mande o endereço pro pessoal." % Rede.PORTA, 8, Color(0.6, 0.9, 1))
			else:
				_txt(Vector2(0, 62), "Esperando o anfitrião começar...", 8, Color(0.6, 0.9, 1))
			var y0 := 90.0
			for p in Rede.jogadores:
				var h: Dictionary = Dados.json("herois").get(Rede.heroi_de(p), {})
				var eu: bool = p == Rede.eu()
				_tela.draw_rect(Rect2(170, y0, 300, 34), Color(0.1, 0.11, 0.18))
				_tela.draw_rect(Rect2(170, y0, 300, 34), Color(1, 0.85, 0.3) if eu else Color(0.3, 0.35, 0.5), false, 1.0)
				var rosto := Dados.tex_personagem(str(h.get("sprite", Rede.heroi_de(p))), "rosto")
				if rosto:
					_tela.draw_texture_rect_region(rosto, Rect2(174, y0 + 3, 28, 28), Rect2(0, 0, 52, 52))
				var quem: String = ("Você" if eu else "Jogador") + (" (anfitrião)" if p == 1 else "")
				_txt(Vector2(210, y0 + 15), str(h.get("nome", "?")), 8, Color.WHITE, 250, HORIZONTAL_ALIGNMENT_LEFT)
				_txt(Vector2(210, y0 + 28), quem, 8, Color(0.6, 0.65, 0.75), 250, HORIZONTAL_ALIGNMENT_LEFT)
				y0 += 40
			if _msg != "":
				_txt(Vector2(0, 314), _msg, 8, Color(1, 0.6, 0.5))
			_txt(Vector2(0, 330), "Setas: trocar herói   " + ("Enter: começar   " if Rede.anfitriao() else "") + "Esc: sair da sala", 8, Color(0.6, 0.6, 0.7))
		"herois":
			_fundo()
			_txt(Vector2(0, 40), "Escolha o herói", 16, Color.WHITE)
			var lista := _herois()
			var larg := 170.0
			var x0 := (W - lista.size() * larg - (lista.size() - 1) * 12) / 2
			for i in lista.size():
				var h: Dictionary = Dados.json("herois").get(lista[i], {})
				var sel := i == _sel
				var p := Vector2(x0 + i * (larg + 12), 70 - (6.0 if sel else 0.0))
				_tela.draw_rect(Rect2(p - Vector2(2, 2), Vector2(larg + 4, 224)), Color(1, 0.85, 0.3) if sel else Color(0.3, 0.35, 0.5))
				_tela.draw_rect(Rect2(p, Vector2(larg, 220)), Color(0.1, 0.11, 0.18))
				var rosto := Dados.tex_personagem(str(h.get("sprite", lista[i])), "rosto")
				if rosto:
					_tela.draw_texture_rect_region(rosto, Rect2(p + Vector2(larg / 2 - 39, 10), Vector2(78, 78)), Rect2(0, 0, 52, 52))
				_txt(p + Vector2(0, 104), str(h.get("nome", lista[i])), 16 if sel else 8, Color.WHITE, larg)
				var arma := Dados.item(str(h.get("arma", "")))
				var ic := Dados.icone(str(arma.get("icone", "")))
				if ic:
					_tela.draw_texture_rect(ic, Rect2(p + Vector2(10, 116), Vector2(32, 32)), false)
				_tela.draw_string(Dados.fonte, p + Vector2(48, 135), str(arma.get("nome", "")), HORIZONTAL_ALIGNMENT_LEFT, larg - 52, 8, Color(1, 0.9, 0.5))
				_tela.draw_multiline_string(Dados.fonte, p + Vector2(8, 164), str(h.get("descricao", "")), HORIZONTAL_ALIGNMENT_LEFT, larg - 16, 8, 5, Color(0.75, 0.78, 0.85))
				var rec: Dictionary = _recordes.get(lista[i], {})
				if rec.has("tempo"):
					_txt(p + Vector2(0, 214), "Recorde %02d:%02d" % [int(rec.tempo) / 60, int(rec.tempo) % 60], 8, Color(0.6, 0.9, 0.6), larg)
			_txt(Vector2(0, 330), "Setas: escolher   Enter: jogar   Esc: voltar", 8, Color(0.6, 0.6, 0.7))
		"fim":
			_fundo()
			var r := _resumo
			var y := 176.0
			var x_dano := 200.0
			if r.has("duelo"):
				var du: Dictionary = r.duelo
				var lg: int = du.lugar
				if lg == 1:
					_txt(Vector2(0, 50), "CAMPEÃO!", 24, Color(1, 0.85, 0.3).lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 6)))
					_txt(Vector2(0, 80), "Você foi o mais forte do duelo final.", 8, Color(0.9, 0.9, 0.8))
				else:
					_txt(Vector2(0, 50), "%dº LUGAR" % lg, 24, Color(1, 0.55, 0.45))
					_txt(Vector2(0, 80), "de %d lutadores. Tenta de novo!" % du.total, 8, Color(0.9, 0.8, 0.8))
				_txt(Vector2(0, 104), "Duelo %ds   Derrubou %d   Dano %d" % [int(du.duracao), du.abates, int(du.dano)], 8)
				_txt(Vector2(0, 120), "Corrida: %02d:%02d  %d fases  Nível %d  Abates %d" % [int(r.tempo) / 60, int(r.tempo) % 60, r.get("fase", 1), r.nivel, r.abates], 8, Color(0.7, 0.75, 0.85))
				# ranking à esquerda, dano por arma à direita
				_txt(Vector2(60, 156), "Ranking", 8, Color(0.7, 0.8, 1), 200, HORIZONTAL_ALIGNMENT_LEFT)
				var ry := 176.0
				for e in du.ranking:
					var cor := Color(1, 0.9, 0.4) if e.jogador else Color(0.85, 0.85, 0.9)
					_txt(Vector2(60, ry), "%dº" % e.lugar, 8, cor, 40, HORIZONTAL_ALIGNMENT_LEFT)
					_txt(Vector2(100, ry), "Você" if e.jogador else str(e.nome), 8, cor, 140, HORIZONTAL_ALIGNMENT_LEFT)
					ry += 20
				x_dano = 340.0
				_txt(Vector2(x_dano, 156), "Dano por arma", 8, Color(0.7, 0.8, 1), 240, HORIZONTAL_ALIGNMENT_LEFT)
			else:
				if r.get("vitoria", false):
					_txt(Vector2(0, 60), "VOCÊ SOBREVIVEU!", 24, Color(0.5, 1, 0.5))
					_txt(Vector2(0, 80), "A Tela Azul caiu. A faculdade está salva.", 8, Color(0.8, 0.9, 0.8))
				else:
					_txt(Vector2(0, 60), "A CORRIDA ACABOU", 24, Color(1, 0.4, 0.4))
					_txt(Vector2(0, 80), "Você chegou até a fase %d de %d. Tenta de novo!" % [r.get("fase", 1), r.get("fases", 1)], 8, Color(0.9, 0.8, 0.8))
				var tempo := float(r.get("tempo", 0))
				_txt(Vector2(0, 112), "Tempo %02d:%02d   Nível %d   Abates %d" % [int(tempo) / 60, int(tempo) % 60, r.get("nivel", 1), r.get("abates", 0)], 8)
				if _novo_recorde:
					_txt(Vector2(0, 128), "NOVO RECORDE!", 8, Color(1, 0.85, 0.3).lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 8)))
				_txt(Vector2(0, 156), "Dano por arma", 8, Color(0.7, 0.8, 1))
			for par in r.get("dano", []):
				var d := Dados.item(str(par[0]))
				var ic := Dados.icone(str(d.get("icone", "")))
				if ic:
					_tela.draw_texture(ic, Vector2(x_dano, y - 12))
				_txt(Vector2(x_dano + 22, y), str(d.get("nome", par[0])), 8, Color.WHITE, 200, HORIZONTAL_ALIGNMENT_LEFT)
				_txt(Vector2(x_dano + 140, y), str(int(par[1])), 8, Color(1, 0.9, 0.5), 100, HORIZONTAL_ALIGNMENT_RIGHT)
				y += 20
			_txt(Vector2(0, 330), "Enter: voltar ao título", 8, Color(0.6, 0.6, 0.7))


## Teste: abre uma tela, tira um print e fecha (--print_tela=titulo|herois|cartas|bau|fim --fotos=pasta).
func _print_tela(qual: String) -> void:
	match qual:
		"herois":
			_estado = "herois"
		"titulo_beta":
			_sel = BETA[0]
		"creditos":
			_estado = "creditos"
		"opcoes":
			_abrir_opcoes()
		"cartas", "bau":
			_comecar("lucas")
			await get_tree().create_timer(0.3).timeout
			if qual == "cartas":
				_arena.passivos["energetico"] = 2
				_arena.armas.adicionar("cafe")
				_arena.cartas.escolher("Subiu pro nível 7!", _arena.sortear_cartas())
			else:
				_arena.armas.lista[0].nivel = 6
				_arena.passivos["ctrl_c_v"] = 1
				_arena.abrir_bau()
		"duelo", "duelo_fim":
			_comecar("nicao")
			await get_tree().create_timer(0.2).timeout
			Engine.time_scale = 3.0
			await get_tree().create_timer(float(_args.get("espera", 9.0)) / 3.0).timeout
			Engine.time_scale = 1.0
		"fim":
			_resumo = {"vitoria": true, "tempo": 642.0, "nivel": 41, "abates": 5230, "heroi": "nicao",
				"dano": [["water_cooler", 52000], ["cafe", 21000], ["pendrive", 9000]]}
			_novo_recorde = true
			_estado = "fim"
	await get_tree().create_timer(0.6, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(_args.get("fotos", "user://")).path_join("tela_%s.png" % qual))
	get_tree().quit()

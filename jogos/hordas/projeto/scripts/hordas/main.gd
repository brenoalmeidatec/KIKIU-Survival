extends Node
## Telas do jogo: título -> escolher herói -> partida -> resultado.
## Online: título -> criar sala / entrar (endereço) -> sala (cada um escolhe o herói) -> partida.
## Opções de linha de comando (pra teste): --bot  --heroi=lucas  --pular=300 (começa no segundo 300)
##   --sair=60 (fecha depois de 60 s de partida)  --fotos=pasta (salva prints a cada 20 s)
##   --online=host [--jogadores=2] (abre a sala e começa sozinho quando tiver 2)
##   --online=join --endereco=127.0.0.1:7777  (entra na sala)
##   --dragao (transformação do herói já liberada e com a energia cheia; o robô transforma sozinho)

const Arena := preload("res://scripts/hordas/arena.gd")
const Perf := preload("res://scripts/hordas/perf.gd")
const AnimMonstros := preload("res://scripts/hordas/animacao_monstros.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
const Mapa := preload("res://scripts/hordas/mapa.gd")
const W := 640.0
const H := 360.0
const SAVE := "user://recordes.json"
const SAVE_ONLINE := "user://online.json"
const TelaOpcoes := preload("res://scripts/hordas/tela_opcoes.gd")
const TelaCalor := preload("res://scripts/hordas/tela_calor.gd")
const TelaPreparo := preload("res://scripts/hordas/tela_preparo.gd")
const Mochila := preload("res://scripts/hordas/mochila.gd")
const Calor := preload("res://scripts/hordas/calor.gd")
const TelaCriacao := preload("res://scripts/hordas/tela_criacao.gd")
const Criacao := preload("res://scripts/hordas/criacao.gd")
const Paleta := preload("res://scripts/hordas/paleta.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
const TelaHerois := preload("res://scripts/hordas/tela_herois.gd")
const Poca := preload("res://scripts/hordas/poca.gd")
const Interface := preload("res://scripts/hordas/interface.gd")
const OPCOES := ["Jogar sozinho", "Criar sala", "Entrar em sala", "Opções", "Créditos", "Sair"]
const BETA := [1, 2]         # opções do online: ainda em teste, ganham o selo BETA no menu

const TECLAS := {
	"cima": [KEY_W, KEY_UP], "baixo": [KEY_S, KEY_DOWN], "esquerda": [KEY_A, KEY_LEFT], "direita": [KEY_D, KEY_RIGHT],
	"dash": [KEY_SPACE, KEY_SHIFT], "confirmar": [KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_Z], "voltar": [KEY_ESCAPE],
	"resortear": [KEY_R], "pular": [KEY_X], "banir": [KEY_B], "tela_cheia": [KEY_F11], "transformar": [KEY_Q, KEY_F], "falar": [KEY_V], "especial": [KEY_E],
	"consumivel1": [KEY_1], "consumivel2": [KEY_2], "consumivel3": [KEY_3], "consumivel_usar": [], "consumivel_trocar": [],
}
const CONTROLE := {
	"cima": [JOY_BUTTON_DPAD_UP], "baixo": [JOY_BUTTON_DPAD_DOWN], "esquerda": [JOY_BUTTON_DPAD_LEFT], "direita": [JOY_BUTTON_DPAD_RIGHT],
	"dash": [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER], "confirmar": [JOY_BUTTON_A], "voltar": [JOY_BUTTON_START], "resortear": [JOY_BUTTON_Y], "pular": [JOY_BUTTON_LEFT_SHOULDER], "banir": [JOY_BUTTON_BACK], "transformar": [JOY_BUTTON_X], "especial": [JOY_BUTTON_Y],
	"consumivel_usar": [JOY_BUTTON_LEFT_STICK], "consumivel_trocar": [JOY_BUTTON_RIGHT_STICK],
}

var _tela := Control.new()
var _camada := CanvasLayer.new()
var _estado := "titulo"      # titulo, herois, partida, fim
var _estado_antes := "titulo"  # pra perceber a troca de tela e tocar a transição
var _apelido_txt := ""       # campo de texto do apelido (lobby, tecla N)
var _calor := {}              # calor escolhido pra próxima corrida {id: nível} (tela_calor.gd)
var _mochila := {}            # mochila escolhida no Preparo pra próxima corrida do herói criado (tela_preparo.gd)
var _criados: Array = []     # heróis criados salvos (#72, até 6): vão pra tela "Meus heróis"
var _aviso_heroi := ""        # "fulano morreu de vez" na escolha de heróis (o jogo fechou no meio da corrida)
var _fundo_tipos: Array = []  # monstros comuns das regiões que passeiam no fundo dos menus
var _sel_carta := 0           # carta onde estava antes de descer pro botão "Criar herói"
var _sel_sala := 0            # tela da lista de salas
var _publico_txt := ""        # anfitrião: campo do endereço público (tecla E no lobby)
var _forcar_t := -10.0       # anfitrião: Enter com gente não pronta avisa; outro Enter em 3 s começa assim mesmo
## telas que são a mesma tela pro jogador (só muda o texto): trocar entre elas não tem transição
const MESMA_TELA := [["endereco", "conectando"], ["titulo", "opcoes"], ["sala", "apelido"], ["sala", "publico"], ["herois", "calor"], ["sala", "calor_sala"], ["sala", "preparo_sala"],
	["herois", "criacao"], ["criacao", "calor"], ["herois", "preparo"], ["criacao", "preparo"], ["preparo", "calor"]]
var _sel := 0
var _arena: Node2D
var _resumo := {}
var _recordes := {}
var _t := 0.0
var _args := {}
var _novo_recorde := false
var _endereco := ""          # último endereço digitado (fica salvo)
var _versao := ""            # carimbo do título: "Versão 0.1.0 · 07/10/2026 · a3d5e4b" (ou "· dev" sem dados/versao.json), vem de Dados.texto_versao()
var _msg := ""               # aviso nas telas do online (erro, conectando...)
var _comecou_teste := false
var _caiu_teste := false
var _mouse_ult := Vector2(-1, -1)


func _ready() -> void:
	_versao = Dados.texto_versao()
	_teclas()
	_ler_args()
	if _args.has("qualidade"):   # teste: --qualidade=alta|media|baixa vale só nesta execução (não grava nas opções)
		Config.temporario("qualidade", str(_args.qualidade))
	Perf.ligado = _args.has("sair")   # relatório de custo por sistema no log do --sair (perf.gd)
	_camada.layer = 20
	add_child(_camada)
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	_camada.add_child(_tela)
	_recordes = _ler_recordes()
	if _args.has("morte_teste"):   # teste do permadeath (--morte_teste): arquivo próprio, longe do herói salvo de verdade
		Criacao.arquivo = "user://teste_morte_heroi.json"
	var cr := Criacao.carregar(_persistir())
	_criados = cr.ids
	if not cr.perdidos.is_empty():
		_aviso_heroi = "%s morreu de vez: o jogo fechou no meio da corrida." % ", ".join(cr.perdidos.map(func(i): return str(Dados.json("herois").get(i, {}).get("nome", "Um herói"))))
	if _args.has("ficha"):   # teste: --ficha=Nome/raça/classe/defeito/f,v,a,m,s/pele,cabelo,roupa monta um herói criado sem salvar (vira --heroi=)
		var fid := _ficha_de_args(str(_args.ficha))
		if fid != "":
			_args["heroi"] = fid
	if _args.has("mochila") and _args.has("heroi"):   # teste: --mochila=pocao_cura:2,bomba,amuleto_corvo,pao_duro (a que esta máquina declara no online, ou leva no solo)
		Rede.mochilas_locais[str(_args.heroi)] = Mochila.de_texto(str(_args.mochila))
	_endereco = _ler_endereco()
	_calor = Calor.de_texto(str(_args.calor)) if _args.has("calor") else Calor.ler()   # a última escolha de calor (ou a do teste)
	Rede.mudou.connect(_rede_mudou)
	Rede.conectou.connect(_rede_conectou)
	Rede.comecou.connect(func(op): _comecar(Rede.heroi_de(Rede.eu()), op, true))
	Rede.caiu.connect(_rede_caiu)
	if _args.has("rapido"):
		Engine.time_scale = float(_args.rapido)
	if _args.has("print_tela"):
		Transicao.ligada = false   # a foto é da tela pedida, não da cortina da transição
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


## Partida de verdade (não é robô, print nem teste com --sair): só ela grava o herói criado e a morte dele.
func _persistir() -> bool:
	return _args.has("morte_teste") or not (_args.has("bot") or _args.has("sair") or _args.has("print_tela"))


## Os heróis da escolha: só os fixos do herois.json. Os criados (até 6) ficam na tela "Meus heróis" (#72).
func _herois() -> Array:
	return Dados.json("herois").get("lista", []).duplicate()


## --ficha=Nome/raça/classe/defeito/f,v,a,m,s/pele,cabelo,roupa: registra um herói criado sem salvar (testes, online com 2 instâncias).
## Devolve o id (c:h<código do nome>) ou "" se a ficha não vale.
func _ficha_de_texto(txt: String) -> Dictionary:
	var p := txt.split("/")
	if p.size() < 6:
		print("FICHA inválida (esperado Nome/raça/classe/defeito/f,v,a,m,s/pele,cabelo,roupa): ", txt)
		return {}
	var ficha := Criacao.ficha_nova(p[1], p[2])
	ficha["nome"] = p[0]
	ficha["defeito"] = p[3]
	var n := p[4].split(",")
	for i in mini(n.size(), Criacao.lista_atributos().size()):
		ficha.pontos[Criacao.lista_atributos()[i]] = int(n[i])
	var c := p[5].split(",")
	for i in mini(c.size(), Paleta.canais().size()):
		ficha.paleta[Paleta.canais()[i]] = int(c[i])
	return ficha


func _ficha_de_args(txt: String) -> String:
	var ficha := _ficha_de_texto(txt)
	if ficha.is_empty():
		return ""
	var id := "c:h%x" % absi(str(ficha.nome).hash())
	if not Criacao.registrar_ficha(id, ficha):
		print("FICHA recusada: ", Criacao.erro_ficha(ficha))
		return ""
	return id


## Carta i: joga com aquele herói. O índice logo depois da última carta é o botão "Meus heróis" (#72).
func _escolher_heroi(i: int) -> void:
	var lista := _herois()
	if i < lista.size():
		_abrir_calor(lista[i])
		return
	_estado = "criacao"
	var t := TelaHerois.new()
	add_child(t)
	t.jogar.connect(func(id: String):
		_criados = Criacao.carregar(false).ids
		_abrir_preparo(id))
	t.fechou.connect(func():
		_criados = Criacao.carregar(false).ids
		_estado = "herois")


func _process(dt: float) -> void:
	_t += dt
	_tela.queue_redraw()
	if _estado != _estado_antes:
		if not ([_estado_antes, _estado] in MESMA_TELA or [_estado, _estado_antes] in MESMA_TELA):
			Transicao.revelar()
		_estado_antes = _estado
	if Input.is_action_just_pressed("tela_cheia"):
		# vira a opção "Tela cheia" (o Config troca a janela e lembra pra próxima vez)
		var modo := DisplayServer.window_get_mode()
		var cheia := modo == DisplayServer.WINDOW_MODE_FULLSCREEN or modo == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		Config.definir("tela_cheia", not cheia)
	_mouse_menu()
	match _estado:
		"titulo":
			if Input.is_action_just_pressed("cima"):
				_sel = (_sel - 1 + OPCOES.size()) % OPCOES.size()
				Som.ui("cursor")
			elif Input.is_action_just_pressed("baixo"):
				_sel = (_sel + 1) % OPCOES.size()
				Som.ui("cursor")
			elif Input.is_action_just_pressed("confirmar") or Input.is_action_just_pressed("dash"):
				_titulo_confirmar()
		"creditos":
			if Input.is_action_just_pressed("voltar") or Input.is_action_just_pressed("confirmar"):
				Som.ui("confirmar")
				_estado = "titulo"
				_sel = OPCOES.find("Créditos")
		"salas":
			_lista_salas()
		"endereco":
			pass   # o teclado é lido em _input (campo de texto)
		"conectando":
			if Input.is_action_just_pressed("voltar"):
				Rede.sair()
				_estado = "endereco"
		"sala":
			_sala()
		"herois":
			var n := _herois().size()   # _sel == n: o botão "Criar herói", embaixo das cartas
			if Input.is_action_just_pressed("esquerda") and _sel < n:
				_sel = (_sel - 1 + n) % n
				Som.ui("cursor")
			elif Input.is_action_just_pressed("direita") and _sel < n:
				_sel = (_sel + 1) % n
				Som.ui("cursor")
			elif Input.is_action_just_pressed("baixo") and _sel < n:
				_sel_carta = _sel
				_sel = n
				Som.ui("cursor")
			elif Input.is_action_just_pressed("cima") and _sel == n:
				_sel = mini(_sel_carta, n - 1)
				Som.ui("cursor")
			elif Input.is_action_just_pressed("confirmar"):
				Som.ui("confirmar")
				_escolher_heroi(_sel)
		"partida":
			_teste()
		"fim":
			if _t > 1.0 and (Input.is_action_just_pressed("confirmar") or Input.is_action_just_pressed("voltar")):
				_fim_voltar()


func _titulo_confirmar() -> void:
	Som.ui("confirmar")
	_msg = ""
	match OPCOES[_sel]:
		"Jogar sozinho":
			_estado = "herois"
			_sel = 0
		"Criar sala":
			_criar_sala()
		"Entrar em sala":
			_estado = "salas"
			_sel_sala = 0
			Salas.procurar()
		"Opções":
			_abrir_opcoes()
		"Créditos":
			_estado = "creditos"
		"Sair":
			get_tree().quit()


func _fim_voltar() -> void:
	Som.ui("confirmar")
	Rede.sair()
	_estado = "titulo"
	_sel = 0
	Som.musica("menu")


## Retângulos clicáveis do título e da escolha de herói (o desenho usa as mesmas contas: mouse e tela nunca divergem).
func _rects_titulo() -> Array:
	var r := []
	for i in OPCOES.size():
		r.append(Rect2(W / 2 - 110, 190 + i * 18 - 11, 220, 15))
	return r


func _rects_herois() -> Array:
	var r := []
	var n := _herois().size()
	var larg := _larg_carta(n)
	var x0 := (W - n * larg - (n - 1) * 12) / 2
	for i in n:
		r.append(Rect2(x0 + i * (larg + 12), 64, larg, 230))
	r.append(_botao_criar())   # índice n: o botão "Criar herói"
	return r


## Largura das cartas de herói: 170 px, e menos quando não cabem (com o herói criado são 4).
func _larg_carta(n: int) -> float:
	return minf(170.0, (W - 40.0 - (n - 1) * 12.0) / maxf(1.0, n))


func _botao_criar() -> Rect2:
	return Rect2(W / 2 - 80, 304, 160, 18)


## Mouse: passar por cima escolhe (só se ele se mexeu); clique esquerdo confirma, direito volta.
func _mouse_menu() -> void:
	var mp := _tela.get_local_mouse_position()
	if mp == _mouse_ult:
		return
	_mouse_ult = mp
	var q := -1
	match _estado:
		"titulo":
			q = Interface.quem(_rects_titulo(), mp)
		"herois":
			q = Interface.quem(_rects_herois(), mp)
	if q >= 0 and q != _sel:
		_sel = q
		Som.ui("cursor")


## Online: as opções de teste (fase, pular, build) vêm do anfitrião, iguais pra todos.
func _comecar(heroi: String, opcoes := {}, online := false) -> void:
	Dados.recarregar()
	if Criacao.eh_criado(heroi):   # herói criado (#72), também pelo --heroi=c:raça:classe: monta e põe na tabela
		Criacao.registrar(heroi)
		if _persistir():
			if _args.has("morte_teste"):
				Criacao.salvar(heroi)   # o teste começa com o herói já salvo, como quem acabou de criar
			Criacao.comecou(heroi)   # se o jogo fechar no meio da corrida, ele morre de vez
	_aviso_heroi = ""
	var o: Dictionary = opcoes if online else _args
	_arena = Arena.new()
	_arena.heroi_id = heroi
	_arena.mochila_cfg = _mochila_da_corrida(heroi, online)
	_arena.bot = _args.has("bot")
	_arena.com_abertura = _args.has("entrada") or (get_tree().current_scene == self and not (_args.has("bot") or _args.has("sair") or _args.has("print_tela") or _args.has("rapido")))   # abertura cinematográfica: só em partida de verdade, na cena principal (testes que montam o main por conta própria ficam sem; --entrada força, pra captura)
	_arena.eh_online = online
	# semente da corrida: online vem do anfitrião (igual pra todos); solo sorteia, ou --semente=N pra repetir uma partida
	_arena.semente = int(o.get("semente", 0)) if online else int(_args.get("semente", 0))
	_arena.calor = o.get("calor", {}) if online else _calor   # calor: no online, o que o anfitrião escolheu (a arena valida)
	_arena.terminou.connect(_terminou)
	add_child(_arena)
	_arena.inimigos.medir = _args.has("saltos")   # --saltos: conta saltos de posição dos vírus (relatório no fim do --sair)
	if o.has("fase"):
		_arena.saltar_para_andar(int(o.fase) - 1)
	if o.has("estresse") and not online:   # os bichos do conjunto da fase (vírus ou horror)
		var tabela := _tipos_do_conjunto(_arena.diretor.conjunto())
		for i in int(o.estresse):
			_arena.inimigos.criar(tabela.pick_random(), Vector2.from_angle(randf() * TAU) * randf_range(150, 420))
	if o.has("pular"):
		_arena.diretor.tempo = float(o.pular)
		_arena.diretor.t_fase = float(o.pular)
	if o.has("build"):
		_arena.dar_build_teste(int(o.build))
	if o.has("armas"):   # teste: --armas=cabo_rede,cafe,wifi entra com essas armas (no lugar das do herói)
		_arena.armas.lista.clear()
		for id in str(o.armas).split(","):
			_arena.armas.adicionar(id)
	if o.has("dragao") and not online:   # teste: transformação liberada e com a energia cheia
		_arena.habilidades.desbloquear()
		_arena.habilidades.energia = _arena.habilidades.energia_max()
	if o.has("duelo") and not online:
		_arena.iniciar_duelo_teste(int(o.duelo))
	_estado = "partida"
	_t = 0.0


## A mochila que o herói leva nesta corrida (#72). Herói fixo: nenhuma. Online: a que o anfitrião aceitou. Solo: a do Preparo (ou a do
## teste, --mochila=). Numa partida de verdade, o que ela leva SAI do baú agora (volta se ele vencer, e some se ele morrer).
func _mochila_da_corrida(heroi: String, online: bool) -> Dictionary:
	var m := {}
	if online:
		m = Rede.mochila_de(Rede.eu())
	elif Criacao.eh_criado(heroi):
		if _args.has("mochila"):
			m = Mochila.de_texto(str(_args.mochila))
		else:
			m = _mochila
	_mochila = {}
	if m.is_empty():
		return {}
	var h: Dictionary = Dados.json("herois").get(heroi, {})
	if Mochila.erro(m, str(h.get("raca", "")), str(h.get("classe", ""))) != "":
		print("MOCHILA recusada: ", Mochila.erro(m, str(h.get("raca", "")), str(h.get("classe", ""))))
		return {}
	if _persistir() and Criacao.salvo(heroi):
		var bau := Mochila.bau_limpo(Criacao.bau_de(heroi))
		if not Mochila.cabe_no_bau(bau, m):   # o baú mudou desde que ela foi montada: leva só o que há
			m = Mochila.ajustar_ao_bau(m, bau, heroi)
		Criacao.definir_bau(heroi, Mochila.retirar(bau, m))
	return m


## Tipos comuns (que o diretor sorteia) de um conjunto de inimigos: "virus" ou "horror".
func _tipos_do_conjunto(conjunto: String) -> Array:
	var res := []
	var inim: Dictionary = Dados.json("inimigos")
	for k in inim:
		if k.begins_with("_") or not inim[k] is Dictionary:
			continue
		if str(inim[k].get("conjunto", "virus")) == conjunto and float(inim[k].get("peso", 0)) > 0 and not inim[k].get("elite", false):
			res.append(k)
	return res


# ---------- online: sala ----------

## Lê o online.json: devolve o endereço da última sala e põe o apelido salvo em Rede.apelido
## (sem apelido ainda: sorteia um e já grava).
func _ler_endereco() -> String:
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_ONLINE)) if FileAccess.file_exists(SAVE_ONLINE) else null
	if not d is Dictionary:
		d = {}
	Rede.apelido = Rede.limpar_nome(str(d.get("nome", "")))
	Salas.endereco_publico = str(d.get("publico", "")) if Salas.endereco_valido(str(d.get("publico", ""))) else ""
	if Rede.apelido == "":
		Rede.apelido = Rede.nome_sorteado()
		_endereco = str(d.get("endereco", ""))
		_salvar_endereco()
	return str(d.get("endereco", ""))


func _salvar_endereco() -> void:
	var f := FileAccess.open(SAVE_ONLINE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"endereco": _endereco, "nome": Rede.apelido, "publico": Salas.endereco_publico}))


## Depois de escolher o herói CRIADO: a tela de Preparo (#72, marcos 3 e 4), onde ele monta a mochila com o que tem no baú.
## Enter segue pro Calor, Esc volta pros heróis. Os heróis fixos (Hazaki, Nicão, Lucas) não têm baú: pulam o Preparo e vão direto pro Calor.
func _abrir_preparo(heroi: String) -> void:
	if not Criacao.eh_criado(heroi) or not _persistir() or not Criacao.salvo(heroi):
		_abrir_calor(heroi)
		return
	_estado = "preparo"
	var t := TelaPreparo.new()
	t.heroi_id = heroi
	t.bau = Mochila.bau_limpo(Criacao.bau_de(heroi))
	t.mochila = Criacao.mochila_de(heroi)
	add_child(t)
	t.fechou.connect(func(ok: bool, escolha: Dictionary):
		if ok:
			_mochila = escolha
			Criacao.definir_mochila(heroi, escolha)
			_abrir_calor(heroi)
		else:
			_estado = "herois")


## Lobby online (tecla P): monta a mochila do herói criado que está na sala. O anfitrião confere e aceita (ou recusa) ao reenviar o herói.
func _abrir_preparo_sala() -> void:
	var heroi := Rede.heroi_de(Rede.eu())
	if not Criacao.eh_criado(heroi) or not Criacao.salvo(heroi):
		_msg = "Só herói criado e salvo leva mochila."
		Som.ui("erro")
		return
	_estado = "preparo_sala"
	var t := TelaPreparo.new()
	t.heroi_id = heroi
	t.bau = Mochila.bau_limpo(Criacao.bau_de(heroi))
	t.mochila = Criacao.mochila_de(heroi)
	add_child(t)
	t.fechou.connect(func(ok: bool, escolha: Dictionary):
		_estado = "sala"
		if ok:
			Criacao.definir_mochila(heroi, escolha)
			Rede.escolher(heroi))   # reenvia o herói com a mochila nova


## Depois de escolher o herói: a tela do Calor. Enter começa a corrida com o calor escolhido, Esc volta pros heróis.
func _abrir_calor(heroi: String) -> void:
	_estado = "calor"
	var t := TelaCalor.new()
	t.escolha = _calor.duplicate()
	add_child(t)
	t.fechou.connect(func(ok: bool, escolha: Dictionary):
		_calor = escolha
		if ok:
			_comecar(heroi)
		else:
			_estado = "herois")


## Anfitrião no lobby (tecla C): escolhe o calor da sala. Os outros veem o total no lobby.
func _abrir_calor_sala() -> void:
	_estado = "calor_sala"
	var t := TelaCalor.new()
	t.escolha = _calor.duplicate()
	t.titulo_confirmar = "salvar"
	add_child(t)
	t.fechou.connect(func(_ok: bool, escolha: Dictionary):
		_calor = escolha
		Rede.definir_calor_sala(Calor.pontos(_calor))
		_estado = "sala")


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
	Rede.definir_calor_sala(Calor.pontos(_calor))   # o lobby mostra o calor da sala pra todos


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
		if _args.has("chat"):   # teste: manda uma mensagem no chat ao entrar
			Rede.chat_enviar(str(_args.chat))
		if _args.has("pronto"):   # teste: o cliente já entra pronto
			Rede.marcar_pronto(true)
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
		if Criacao.eh_criado(_arena.heroi_id) and _persistir():
			Criacao.sobreviveu(_arena.heroi_id)   # cair a conexão não é morrer
			if _arena.provisoes:   # e o que não foi usado da mochila volta pro baú (o que achou fica pra lá: a corrida não acabou)
				_trazer_pra_casa(_arena.heroi_id, {"mochila": _arena.provisoes.sobra(), "achados": []})
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
		var opcoes: Array = Rede.ELENCO + _criados   # os heróis criados salvos também entram na sala (a ficha viaja, o anfitrião valida)
		var i := opcoes.find(Rede.heroi_de(Rede.eu()))
		for _k in opcoes.size():
			i = (i + passo + opcoes.size()) % opcoes.size()
			if not opcoes[i] in tomados:
				Rede.escolher(opcoes[i])
				Som.ui("cursor")
				break
	elif Input.is_action_just_pressed("confirmar") and Rede.anfitriao():
		if Rede.todos_prontos() or _t - _forcar_t < 3.0:
			Som.ui("confirmar")
			Rede.comecar({"calor": _calor})
		else:
			# alguém ainda não está pronto: avisa quem, e um segundo Enter em 3 s começa assim mesmo
			var faltam: Array = Rede.jogadores.keys().filter(func(p): return not Rede.pronto_de(p)).map(func(p): return Rede.nome_de(p))
			_msg = "Ainda não estão prontos: %s. Enter de novo começa assim mesmo." % ", ".join(faltam)
			_forcar_t = _t
			Som.ui("erro")
	elif (Input.is_action_just_pressed("confirmar") or Input.is_action_just_pressed("dash")) and Rede.cliente():
		Rede.marcar_pronto(not Rede.pronto_de(Rede.eu()))
		Som.ui("confirmar")
	elif Input.is_action_just_pressed("voltar"):
		Rede.sair()
		_estado = "titulo"
		_sel = 0
	# teste: o anfitrião começa sozinho quando a sala enche
	if _args.has("online") and Rede.anfitriao() and not _comecou_teste \
			and Rede.jogadores.size() >= int(_args.get("jogadores", 2)):
		_comecou_teste = true
		var op := {}
		for k in ["fase", "pular", "build", "semente"]:
			if _args.has(k):
				op[k] = _args[k]
		op["calor"] = _calor
		Rede.comecar(op)


## As salas que cabem na tela (rede local primeiro, depois as mais novas da internet).
func _salas_vis() -> Array:
	return Salas.lista().slice(0, 6)


## Tela "Entrar em sala": as salas que o Salas achou (rede local e internet) e, no fim, "Digitar endereço".
func _lista_salas() -> void:
	var n: int = _salas_vis().size() + 1
	_sel_sala = clampi(_sel_sala, 0, n - 1)
	if Input.is_action_just_pressed("cima"):
		_sel_sala = (_sel_sala - 1 + n) % n
		Som.ui("cursor")
	elif Input.is_action_just_pressed("baixo"):
		_sel_sala = (_sel_sala + 1) % n
		Som.ui("cursor")
	elif Input.is_action_just_pressed("confirmar"):
		Som.ui("confirmar")
		Salas.parar_procura()
		if _sel_sala >= n - 1:
			_estado = "endereco"
		else:
			_endereco = str(_salas_vis()[_sel_sala].endereco)
			_entrar()
			if _estado != "conectando":
				Salas.procurar()   # endereço com erro: continua na lista (a mensagem aparece embaixo)
	elif Input.is_action_just_pressed("voltar"):
		Salas.parar_procura()
		_estado = "titulo"


func _online_teste() -> void:
	if _args.has("nome"):
		Rede.apelido = Rede.limpar_nome(str(_args.nome))
	if str(_args.online) == "host":
		_criar_sala()
		if _args.has("publica"):   # teste da lista pública (use --topico=algo_de_teste)
			Salas.publica = true
			Salas.endereco_publico = str(_args.publica)
		if _args.has("foto_sala"):   # print do lobby depois de N s (--fotos=pasta) e fecha
			await get_tree().create_timer(float(_args.foto_sala)).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(str(_args.get("fotos", "user://")).path_join("tela_sala.png"))
			get_tree().quit()
	else:
		_endereco = str(_args.get("endereco", "127.0.0.1:%d" % Rede.PORTA))
		_entrar()
	if _msg != "" and _estado != "conectando":
		print("ONLINE erro: ", _msg)
		get_tree().quit(1)


## Esc na escolha de herói volta pro título. Fica aqui (e não no _process, que lê a tecla por polling) para só pegar o Esc
## que ninguém consumiu: o que fecha "Meus heróis" (tela_herois.gd lê em _input) não volta duas telas de uma vez.
func _unhandled_input(e: InputEvent) -> void:
	if _estado == "herois" and e.is_action_pressed("voltar") and not e.is_echo():
		get_viewport().set_input_as_handled()
		_estado = "titulo"
		_sel = 0


## Campo de texto do endereço: digita, apaga, Ctrl+V cola, Enter conecta, Esc volta.
func _input(e: InputEvent) -> void:
	if Chat.digitando:   # o teclado é do chat (chat.gd)
		return
	if Interface.clique(e) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT):
		_clique_menu(e)
		return
	if _estado == "sala" and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_6:
		var peers: Array = Rede.jogadores.keys()
		var i: int = e.physical_keycode - KEY_1
		if i < peers.size() and peers[i] != Rede.eu():   # 1-6: silencia (ou volta a ouvir) a voz de quem está naquele cartão
			Voz.silenciar(peers[i])
			Som.ui("cursor")
		get_viewport().set_input_as_handled()
		return
	if _estado == "sala" and e is InputEventKey and e.pressed and e.physical_keycode == KEY_N:
		_apelido_txt = Rede.apelido   # N no lobby: trocar o apelido
		_estado = "apelido"
		get_viewport().set_input_as_handled()
		return
	if _estado == "sala" and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_P:
		_abrir_preparo_sala()   # P no lobby: a mochila do herói criado (o anfitrião confere)
		get_viewport().set_input_as_handled()
		return
	if _estado == "apelido" and e is InputEventKey and e.pressed:
		_editar_apelido(e)
		return
	if _estado == "sala" and Rede.anfitriao() and e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_C:   # calor da sala (vale pra todos)
			_abrir_calor_sala()
			get_viewport().set_input_as_handled()
			return
		if e.physical_keycode == KEY_L:   # lista pública: liga/desliga
			Salas.publica = not Salas.publica
			_msg = "" if Salas.publica == false or Salas.endereco_valido(Salas.endereco_publico) else "Aperte E e cole o endereço do túnel (playit) pra sala aparecer na internet."
			Som.ui("confirmar")
			get_viewport().set_input_as_handled()
			return
		if e.physical_keycode == KEY_E:   # endereço público (o do playit)
			_publico_txt = Salas.endereco_publico
			_estado = "publico"
			get_viewport().set_input_as_handled()
			return
	if _estado == "publico" and e is InputEventKey and e.pressed:
		_editar_publico(e)
		return
	if _estado != "endereco" or not e is InputEventKey or not e.pressed:
		return
	var k: InputEventKey = e
	get_viewport().set_input_as_handled()
	if k.keycode == KEY_V and k.ctrl_pressed:
		_endereco = (_endereco + DisplayServer.clipboard_get().strip_edges()).left(80)
	elif k.keycode == KEY_BACKSPACE:
		_endereco = _endereco.left(-1)
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		Som.ui("confirmar")
		_entrar()
	elif k.keycode == KEY_ESCAPE:
		_estado = "titulo"
		_msg = ""
	elif k.unicode > 32 and k.unicode < 127 and _endereco.length() < 80:
		var c := char(k.unicode)
		if c.is_valid_identifier() or c.is_valid_int() or c in [".", ":", "-", "_"]:
			_endereco += c


## Campo do endereço público (lobby do anfitrião, tecla E): o endereço do túnel playit, que vai no anúncio da internet.
func _editar_publico(k: InputEventKey) -> void:
	get_viewport().set_input_as_handled()
	if k.keycode == KEY_V and k.ctrl_pressed:
		_publico_txt = (_publico_txt + DisplayServer.clipboard_get().strip_edges()).left(80)
	elif k.keycode == KEY_BACKSPACE:
		_publico_txt = _publico_txt.left(-1)
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		var e := _publico_txt.strip_edges().trim_prefix("udp://").trim_prefix("http://").trim_prefix("https://")
		if e == "" or Salas.endereco_valido(e):
			Salas.endereco_publico = e
			_salvar_endereco()
			_msg = ""
			Som.ui("confirmar")
			_estado = "sala"
		else:
			_msg = "Endereço no formato nome.do.tunel:porta (ex.: abc.gl.at.ply.gg:12345)."
			Som.ui("erro")
	elif k.keycode == KEY_ESCAPE:
		_estado = "sala"
	elif k.unicode > 32 and k.unicode < 127 and _publico_txt.length() < 80:
		_publico_txt += char(k.unicode)


## Campo de texto do apelido (lobby, tecla N). Enter grava, Esc desiste.
func _editar_apelido(k: InputEventKey) -> void:
	get_viewport().set_input_as_handled()
	if k.keycode == KEY_BACKSPACE:
		_apelido_txt = _apelido_txt.left(-1)
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if Rede.limpar_nome(_apelido_txt) != "":
			Rede.trocar_apelido(_apelido_txt)
			_salvar_endereco()
			Som.ui("confirmar")
		_estado = "sala"
	elif k.keycode == KEY_ESCAPE:
		_estado = "sala"
	elif k.unicode >= 32 and _apelido_txt.length() < 16:
		_apelido_txt = Rede.limpar_nome(_apelido_txt + char(k.unicode)) if k.unicode != 32 else _apelido_txt + " "


func _clique_menu(e: InputEventMouseButton) -> void:
	var esq: bool = e.button_index == MOUSE_BUTTON_LEFT
	var mp := _tela.get_local_mouse_position()
	match _estado:
		"titulo":
			var q := Interface.quem(_rects_titulo(), mp)
			if esq and q >= 0:
				_sel = q
				_titulo_confirmar()
		"herois":
			var q := Interface.quem(_rects_herois(), mp)
			if esq and q >= 0:
				_sel = q
				Som.ui("confirmar")
				_escolher_heroi(_sel)
			elif not esq:
				Som.ui("voltar")
				_estado = "titulo"
				_sel = 0
		"creditos":
			Som.ui("confirmar")
			_estado = "titulo"
			_sel = OPCOES.find("Créditos")
		"fim":
			if _t > 1.0:
				_fim_voltar()


## "Trazer pra casa" (#72, marco 4): o herói criado sobreviveu, então o que sobrou da mochila (consumíveis não usados e o amuleto) e o que
## ele achou na corrida voltam pro baú. O que não couber nos espaços do baú se perde (a tela de fim conta o que foi e o que ficou).
func _trazer_pra_casa(h: String, res: Dictionary) -> void:
	if not res.has("mochila") or not Criacao.salvo(h):
		return
	var r := Mochila.trazer(Mochila.bau_limpo(Criacao.bau_de(h)), res.mochila, res.get("achados", []))
	Criacao.definir_bau(h, r.bau)
	res["trazido"] = r.trazidos
	res["perdido_bau"] = r.perdidos


func _terminou(res: Dictionary) -> void:
	if _arena == null:
		return
	_resumo = res
	_novo_recorde = false
	var h: String = res.heroi
	if Criacao.eh_criado(h) and _persistir():
		if Criacao.morreu_de_vez(res):   # herói criado morreu: some de vez, junto com os recordes dele
			res["heroi_perdido"] = str(Dados.json("herois").get(h, {}).get("nome", "Seu herói"))
			Criacao.apagar(h)
			_criados.erase(h)
			_recordes.erase(h)
		else:
			Criacao.sobreviveu(h)
			_trazer_pra_casa(h, res)
	if not res.has("heroi_perdido"):
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
	Perf.quadros += 1
	_t_quadros += get_process_delta_time()
	if _args.has("imortal") and not _arena.duelo_ativo:   # teste: o robô não morre na horda (pra chegar no fim)
		_arena.jogador.invencivel = maxf(_arena.jogador.invencivel, 0.2)
		_arena.jogador.hp = maxf(_arena.jogador.hp, 1.0)
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
		print("  perf_us: ", Perf.relatorio())
		var ele = _arena.inimigos.elementos
		print("  elementos: estados=%d vistos=%d marcados=%d congelados=%d reacoes=%d" % [ele.estados.size(), ele.vis.size(), ele.contagem.qualquer, ele.contagem.congelados, ele.contagem.reacoes])
		if _arena.ganchos:
			print("  ganchos: %s auras_tocadas=%s pilhas=%d vidas_gastas=%d" % [_arena.ganchos.lista.map(func(g): return g.tipo), _arena.ganchos.aura_tocados, _arena.ganchos.pilhas, _arena.ganchos.vidas_gastas])
		print("t=%.0f fase=%d partida=%.0f fps=%d vivos=%d nivel=%d abates=%d hp=%.0f proc_ms=%.2f perfil=%s armas=%s passivos=%s duelo=%s forma=%s" % [
			_t, _arena.diretor.fase_idx + 1, _arena.diretor.tempo, Engine.get_frames_per_second(), _arena.inimigos.vivos(), _arena.nivel, _arena.abates,
			_arena.jogador.hp, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, _arena.perfil,
			_arena.armas.lista.map(func(a): return "%s:%d" % [a.id, a.nivel]), _arena.passivos,
			("%s luta=%.0f vivos=%d raio=%.0f" % [_arena.duelo.estado, _arena.duelo.t_luta, _arena.duelo.vivos().size(), _arena.duelo.raio]) if _arena.duelo_ativo else "-",
			("%s energia=%.0f vezes=%d armas=%s" % ["DRAGAO" if _arena.habilidades.ativa else "humano", _arena.habilidades.energia, _arena.habilidades.vezes, _arena.armas.forma_lista.map(func(a): return "%s:%d" % [a.id, a.nivel])]) if _arena.habilidades.desbloqueada else "-"])
		print("  sorte: semente=%d santuarios=%d(hash %d) fragmentos=%s dadivas=%d eventos=%s" % [Sorte.semente, _arena.chao.santuarios.size(),
			hash(str(_arena.chao.santuarios.map(func(s): return [snappedf(s.pos.x, 0.01), snappedf(s.pos.y, 0.01), s.tipo, s.variacao]))),
			_arena.descobertas.fragmentos, _arena.descobertas.dadivas.size(), _arena.descobertas.eventos_vistos])
		print("  mapa: hash=%s pos=%s no=%s ouro=%d trilha=%s" % [Mapa.resumo(_arena.mapa), _arena.mapa_pos, _arena.no_tipo, _arena.ouro, _arena.mapa_trilha.map(func(p): return "%d.%d" % [p.x, p.y])])
		if _arena.calor_pts > 0:
			print("  calor: %d %s" % [_arena.calor_pts, _arena.calor])
		if _arena.objetivo.id != "":
			print("  objetivo: %s" % [_arena.objetivo.snapshot()])
		if _arena.missao.id != "":
			print("  missao: %s est=%d etapa=%d t_fase=%.0f chefe_chamado=%s" % [_arena.missao.id, _arena.missao.est, _arena.missao.etapa, _arena.diretor.t_fase, _arena.diretor.final_chamado])
		if not _arena.conj_resumo.is_empty():
			print("  conjuntos: %s ef=%s" % [_arena.conj_contagem, _arena._conj_ef])
		if _arena.especial.tem():
			print("  especial: %s usos=%d recarga=%.0f" % [_arena.especial.d.get("nome", ""), _arena.especial.usos, _arena.especial.recarga])
		if _arena.online:
			print("  online: %s peers=%d acertos=%d caido=%s fase=%d entre=%s duelo=%s" % ["anfitriao" if Rede.anfitriao() else "cliente",
				Rede.jogadores.size(), _arena.online.n_tx, _arena.caido, _arena.diretor.fase_idx + 1, _arena.entre_fases,
				_arena.duelo.estado if _arena.duelo_ativo else "-"])
			for p in Rede.jogadores:   # como ESTA máquina enxerga cada jogador da sala (herói criado: nome, paleta, stats e se o boneco está recolorido)
				var hid := Rede.heroi_de(p)
				var hh: Dictionary = Dados.json("herois").get(hid, {})
				var st := Construcao.stats(hh, {}, {})
				var av = _arena.online.avatares.get(p)
				var recolorido: bool = av != null and not hh.get("paleta", {}).is_empty() and av.spr.texture == Paleta.textura(str(hh.get("sprite", "")), "corpo", hh.paleta) and av._cab != null
				print("  jogador: peer=%d%s heroi=%s nome=%s paleta=%s vida=%d dano=%d%% vel=%d%% defeito=%s boneco_recolorido=%s" % [p, " (eu)" if p == Rede.eu() else "", hid,
					Rede.nome_de(p), str(hh.get("paleta", {})), roundi(st.vida_max), roundi(st.dano * 100.0), roundi(st.velocidade * 100.0),
					str(hh.get("ficha", {}).get("defeito", "")), recolorido if p != Rede.eu() else "-"])
			if Rede.anfitriao():
				print("  golpes_remotos: recebidos=%d com_arma=%d elemento_do_cliente=%d" % [_arena.online.n_tx, _arena.online.n_arma, _arena.inimigos.elementos.remotos])
			var b: Vector2 = Rede.banda()
			print("  banda: envia=%.1f KB/s recebe=%.1f KB/s  voz: enviou=%d recebeu=%d bytes" % [b.x, b.y, Voz.enviados, Voz.recebidos])
		if _t >= float(_args.sair):
			if _args.has("saltos"):
				print("SALTOS ", _arena.inimigos.med_relatorio())
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
	# monstros comuns das regiões passeando no fundo, de perfil (a vista 2 da folha de 5 vistas)
	if _fundo_tipos.is_empty():
		var inim: Dictionary = Dados.json("inimigos")
		for k in inim:
			var d = inim[k]
			if d is Dictionary and int(d.get("vistas", 1)) == 5 and float(d.get("peso", 0)) > 0 and not d.get("elite", false) and not d.get("chefe", false):
				_fundo_tipos.append(k)
	if _fundo_tipos.is_empty():
		return
	for i in 14:
		var tex := Dados.tex(str(Dados.json("inimigos").get(_fundo_tipos[(i * 7) % _fundo_tipos.size()], {}).get("sprite", "")))
		if tex == null:
			continue
		var cols := AnimMonstros.colunas(str(Dados.json("inimigos").get(_fundo_tipos[(i * 7) % _fundo_tipos.size()], {}).get("sprite", "")))
		var w := tex.get_width() / float(cols)
		var h := tex.get_height() / 5.0
		var x := fmod(i * 97.0 + _t * (20 + i * 3), W + 120) - 60
		var y := 30 + fmod(i * 53.0, H - 80) + sin(_t * 2 + i) * 6
		_tela.draw_texture_rect_region(tex, Rect2(x, y, w, h), Rect2(w * (int(_t * 2.0 * (cols - 1) + i) % (cols - 1)), h * 2, w, h), Color(1, 1, 1, 0.25))


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
			_txt(Vector2(0, 354), _versao, 8, Color(0.72, 0.74, 0.86, 0.85), W - 4, HORIZONTAL_ALIGNMENT_RIGHT)
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
			_txt(Vector2(0, 236), "Fonte Press Start 2P, de CodeMan38 (licença OFL)", 8, Color(0.6, 0.6, 0.7))
			_txt(Vector2(0, 248), "Efeitos sonoros gerados por código, no próprio projeto", 8, Color(0.6, 0.6, 0.7))
			_txt(Vector2(0, 260), "Música: Kevin MacLeod (incompetech.com), CC BY 4.0", 8, Color(0.6, 0.6, 0.7))
			_txt(Vector2(0, 272), "Oppressive Gloom, Crypto, Giant Wyrm, Ignosi,", 8, Color(0.6, 0.6, 0.7))
			_txt(Vector2(0, 284), "Crusade, Wounded, Long Note Four (cortadas p/ laço)", 8, Color(0.6, 0.6, 0.7))
			_txt(Vector2(0, 302), "E valeu a você, que está jogando!", 10, Color(1, 0.6, 0.75))
			_txt(Vector2(0, 335), "Enter/Esc: voltar", 8, Color(0.5, 0.5, 0.6))
		"salas":
			_fundo()
			_txt(Vector2(0, 40), "Salas abertas", 16, Color.WHITE)
			_txt(Vector2(0, 58), "Rede local aparece sozinha; internet, só as da lista pública.", 8, Color(0.6, 0.65, 0.75))
			var salas: Array = _salas_vis()
			var y := 74.0
			for i in salas.size() + 1:
				var sel := i == _sel_sala
				var r := Rect2(110, y, 420, 26)
				_tela.draw_rect(r, Color(0.14, 0.15, 0.24) if sel else Color(0.08, 0.09, 0.15, 0.9))
				_tela.draw_rect(r, Color(1, 0.85, 0.3) if sel else Color(0.3, 0.35, 0.5), false, 1.0)
				if i == salas.size():
					_txt(r.position + Vector2(0, 17), "Digitar endereço...", 8, Color(1, 0.9, 0.4) if sel else Color(0.8, 0.8, 0.8), r.size.x)
					break
				var s: Dictionary = salas[i]
				var lan: bool = s.origem == "lan"
				var tag := Rect2(r.position + Vector2(6, 7), Vector2(52, 12))
				_tela.draw_rect(tag, Color(0.15, 0.35, 0.2) if lan else Color(0.18, 0.22, 0.45))
				_txt(tag.position + Vector2(0, 10), "LOCAL" if lan else "INTERNET", 8, Color(0.75, 1, 0.8) if lan else Color(0.7, 0.8, 1), tag.size.x)
				_txt(r.position + Vector2(66, 17), str(s.nome), 8, Color.WHITE, 260, HORIZONTAL_ALIGNMENT_LEFT)
				var cheia: bool = int(s.jogadores) >= int(s.max)
				_txt(r.position + Vector2(0, 17), "%d/%d" % [s.jogadores, s.max], 8, Color(1, 0.6, 0.5) if cheia else Color(0.6, 1, 0.65), r.size.x - 8, HORIZONTAL_ALIGNMENT_RIGHT)
				y += 30
			if salas.is_empty():
				_txt(Vector2(0, 130), "Procurando salas" + ".".repeat(int(_t * 2) % 4), 8, Color(0.7, 0.75, 0.85))
			var aviso: String = _msg if _msg != "" else Salas.erro_net
			if aviso != "":
				_txt(Vector2(0, 314), aviso, 8, Color(1, 0.7, 0.5))
			_txt(Vector2(0, 330), "Setas: escolher   Enter: entrar   Esc: voltar", 8, Color(0.6, 0.6, 0.7))
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
		"sala", "apelido", "publico", "calor_sala", "preparo_sala":
			_fundo()
			_txt(Vector2(0, 40), "Sala online", 16, Color.WHITE)
			if Rede.anfitriao():
				_txt(Vector2(0, 60), "Você é o anfitrião (porta %d). Na rede local, a sala já está na lista." % Rede.porta_aberta, 8, Color(0.6, 0.9, 1))
				var pub := "Lista pública: desligada  (L liga; pela internet precisa do túnel playit)"
				var cor_pub := Color(0.6, 0.62, 0.72)
				if Salas.publica:
					var ok_end: bool = Salas.endereco_valido(Salas.endereco_publico)
					pub = "Lista pública: LIGADA  ·  " + (Salas.endereco_publico if ok_end else "falta o endereço do túnel (E)")
					cor_pub = Color(0.6, 1, 0.65) if ok_end else Color(1, 0.8, 0.45)
				_txt(Vector2(0, 72), pub, 8, cor_pub)
			else:
				_txt(Vector2(0, 62), "Esperando o anfitrião começar...", 8, Color(0.6, 0.9, 1))
			var y0 := 92.0
			for p in Rede.jogadores:
				var h: Dictionary = Dados.json("herois").get(Rede.heroi_de(p), {})
				var eu: bool = p == Rede.eu()
				_tela.draw_rect(Rect2(170, y0, 300, 34), Color(0.1, 0.11, 0.18))
				_tela.draw_rect(Rect2(170, y0, 300, 34), Color(1, 0.85, 0.3) if eu else Color(0.3, 0.35, 0.5), false, 1.0)
				var rosto := Paleta.textura(str(h.get("sprite", Rede.heroi_de(p))), "rosto", h.get("paleta", {}))   # herói criado: com a paleta dele
				if rosto:
					_tela.draw_texture_rect_region(rosto, Rect2(174, y0 + 3, 28, 28), Rect2(0, 0, 52, 52))
				_txt(Vector2(210, y0 + 15), Rede.nome_de(p) + (" (você)" if eu else ""), 8, Color(1, 0.95, 0.7) if eu else Color.WHITE, 200, HORIZONTAL_ALIGNMENT_LEFT)
				_txt(Vector2(210, y0 + 28), str(h.get("nome", "?")) + ("  ·  anfitrião" if p == 1 else ""), 8, Color(0.6, 0.65, 0.75), 200, HORIZONTAL_ALIGNMENT_LEFT)
				# voz: número do cartão (tecla pra silenciar), MUDO, e ondas verdes quando a pessoa está falando
				var idx: int = Rede.jogadores.keys().find(p)
				_txt(Vector2(152, y0 + 21), str(idx + 1), 8, Color(0.45, 0.47, 0.55), 14, HORIZONTAL_ALIGNMENT_RIGHT)
				if Voz.silenciados.has(p):
					_tela.draw_rect(Rect2(362, y0 + 10, 36, 14), Color(0.45, 0.12, 0.12))
					_txt(Vector2(362, y0 + 21), "MUDO", 8, Color(1, 0.7, 0.7), 36)
				elif Voz.esta_falando(p):
					for k in 3:
						_tela.draw_arc(Vector2(372, y0 + 17), 3.0 + k * 3.0, -0.8, 0.8, 6, Color(0.5, 1, 0.6, 1.0 - k * 0.25), 1.0)
				# pronto (verde) ou esperando (cinza), à direita do cartão
				var pronto := Rede.pronto_de(p)
				var r := Rect2(404, y0 + 10, 60, 14)
				_tela.draw_rect(r, Color(0.15, 0.4, 0.2) if pronto else Color(0.16, 0.16, 0.22))
				_tela.draw_rect(r, Color(0.5, 1, 0.6) if pronto else Color(0.35, 0.37, 0.45), false, 1.0)
				_txt(r.position + Vector2(0, 11), "PRONTO" if pronto else "...", 8, Color(0.75, 1, 0.8) if pronto else Color(0.55, 0.57, 0.65), r.size.x)
				y0 += 40 if Rede.jogadores.size() <= 4 else 34   # com 5 ou 6, os cartões encostam pra sobrar lugar pro chat
			if _estado == "apelido":
				_tela.draw_rect(Rect2(150, 140, 340, 70), Color(0.04, 0.04, 0.08, 0.95))
				_tela.draw_rect(Rect2(150, 140, 340, 70), Color(1, 0.85, 0.3), false, 2.0)
				_txt(Vector2(0, 160), "Seu nome na sala", 8, Color(0.75, 0.78, 0.85))
				_txt(Vector2(0, 186), _apelido_txt + ("_" if int(_t * 2) % 2 == 0 else " "), 16, Color.WHITE)
				_txt(Vector2(0, 204), "Enter: salvar   Esc: cancelar", 8, Color(0.55, 0.57, 0.65))
			if _estado == "publico":
				_tela.draw_rect(Rect2(110, 136, 420, 82), Color(0.04, 0.04, 0.08, 0.95))
				_tela.draw_rect(Rect2(110, 136, 420, 82), Color(1, 0.85, 0.3), false, 2.0)
				_txt(Vector2(0, 154), "Endereço do túnel (playit) pra lista pública", 8, Color(0.75, 0.78, 0.85))
				_txt(Vector2(0, 176), _publico_txt + ("_" if int(_t * 2) % 2 == 0 else " "), 8, Color.WHITE)
				_txt(Vector2(0, 196), "Ctrl+V: colar   Enter: salvar   Esc: cancelar", 8, Color(0.55, 0.57, 0.65))
				_txt(Vector2(0, 210), "Esse endereço fica visível pra quem abrir a lista de salas.", 8, Color(1, 0.8, 0.45))
			var aviso: String = _msg if _msg != "" else (Salas.erro_net if Rede.anfitriao() and Salas.publica else "")
			if aviso != "":
				_txt(Vector2(0, 86), aviso, 8, Color(1, 0.6, 0.5))   # em cima dos cartões: embaixo é do chat
			# calor da sala, pra todos (o anfitrião escolhe com C)
			var cs := Rede.calor_sala()
			_txt(Vector2(W - 110, 36), "Calor %d" % cs, 8, Color(1, 0.7, 0.35) if cs > 0 else Color(0.55, 0.55, 0.6), 100, HORIZONTAL_ALIGNMENT_RIGHT)
			var dica := "Setas: herói  N: nome  P: mochila  " +("Enter: começar  C: calor  L/E: lista  " if Rede.anfitriao() else "Enter: pronto  ") + "Esc: sair"
			_txt(Vector2(0, 340), dica, 8, Color(0.6, 0.6, 0.7))
			_txt(Vector2(0, 353), "T: chat   V (segurar): falar   1-6: silenciar alguém", 8, Color(0.5, 0.52, 0.62))
		"herois", "calor", "criacao", "preparo":
			_fundo()
			_txt(Vector2(0, 40), "Escolha o herói", 16, Color.WHITE)
			if _aviso_heroi != "":
				_txt(Vector2(0, 56), _aviso_heroi, 8, Color(1, 0.45, 0.4))
			var lista := _herois()
			var larg := _larg_carta(lista.size())
			var x0 := (W - lista.size() * larg - (lista.size() - 1) * 12) / 2
			for i in lista.size():
				var h: Dictionary = Dados.json("herois").get(lista[i], {})
				var sel := i == _sel
				var p := Vector2(x0 + i * (larg + 12), 70 - (6.0 if sel else 0.0))
				_tela.draw_rect(Rect2(p - Vector2(2, 2), Vector2(larg + 4, 232)), Color(1, 0.85, 0.3) if sel else Color(0.3, 0.35, 0.5))
				_tela.draw_rect(Rect2(p, Vector2(larg, 228)), Color(0.1, 0.11, 0.18))
				var rosto := Dados.tex_personagem(str(h.get("sprite", lista[i])), "rosto")
				if rosto:
					var tom: Array = h.get("tom", [1.0, 1.0, 1.0])   # herói criado (#72): a raça tinge
					_tela.draw_texture_rect_region(rosto, Rect2(p + Vector2(larg / 2 - 39, 10), Vector2(78, 78)), Rect2(0, 0, 52, 52),
						Color(float(tom[0]), float(tom[1]), float(tom[2])))
				_txt(p + Vector2(0, 104), str(h.get("nome", lista[i])), 16 if sel else 8, Color.WHITE, larg)
				var arma := Dados.item(str(h.get("arma", "")))
				var ic := Dados.icone(str(arma.get("icone", "")))
				if ic:
					_tela.draw_texture_rect(ic, Rect2(p + Vector2(10, 116), Vector2(32, 32) if larg >= 160 else Vector2(24, 24)), false)
				_tela.draw_string(Dados.fonte, p + Vector2(48 if larg >= 160 else 38, 135), str(arma.get("nome", "")), HORIZONTAL_ALIGNMENT_LEFT, larg - (52 if larg >= 160 else 40), 8, Color(1, 0.9, 0.5))
				_tela.draw_multiline_string(Dados.fonte, p + Vector2(8, 164), str(h.get("descricao", "")), HORIZONTAL_ALIGNMENT_LEFT, larg - 16, 8, 5 if larg >= 160 else 6, Color(0.75, 0.78, 0.85))
				var rec: Dictionary = _recordes.get(lista[i], {})
				if rec.has("tempo"):
					_txt(p + Vector2(0, 222), "Recorde %02d:%02d" % [int(rec.tempo) / 60, int(rec.tempo) % 60], 8, Color(0.6, 0.9, 0.6), larg)
			var bc := _botao_criar()
			var bsel := _sel == lista.size()
			_tela.draw_rect(bc.grow(2), Color(1, 0.85, 0.3) if bsel else Color(0.3, 0.35, 0.5))
			_tela.draw_rect(bc, Color(0.2, 0.15, 0.06) if bsel else Color(0.1, 0.11, 0.18))
			_txt(Vector2(bc.position.x, bc.position.y + 13), "Meus heróis (%d/%d)" % [_criados.size(), Criacao.MAX_HEROIS], 8, Color(1, 0.9, 0.6) if bsel else Color(0.8, 0.82, 0.9), bc.size.x)
			_txt(Vector2(0, 342), "Setas: escolher   Baixo: meus heróis criados   Enter: jogar   Esc: voltar", 8, Color(0.6, 0.6, 0.7))
		"fim":
			_fundo()
			var r := _resumo
			if int(r.get("calor", 0)) > 0:   # calor da corrida (#63), no canto
				_txt(Vector2(W - 110, 20), "Calor %d" % int(r.calor), 8, Color(1, 0.7, 0.35), 100, HORIZONTAL_ALIGNMENT_RIGHT)
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
				if r.has("trazido"):
					_txt(Vector2(0, 138), "Trouxe pra casa: " + Mochila.resumo(r.trazido), 8, Color(0.6, 0.9, 0.7))
				# ranking à esquerda, dano por arma à direita
				_txt(Vector2(60, 156), "Ranking", 8, Color(0.7, 0.8, 1), 200, HORIZONTAL_ALIGNMENT_LEFT)
				var ry := 176.0
				for e in du.ranking:
					var cor := Color(1, 0.9, 0.4) if e.jogador else Color(0.85, 0.85, 0.9)
					_txt(Vector2(60, ry), "%dº" % e.lugar, 8, cor, 40, HORIZONTAL_ALIGNMENT_LEFT)
					_txt(Vector2(100, ry), "Você" if e.jogador else str(e.nome), 8, cor, 140, HORIZONTAL_ALIGNMENT_LEFT)
					ry += 20
				x_dano = 200.0
				y = 156.0
			else:
				if r.get("vitoria", false):
					_txt(Vector2(0, 60), "VOCÊ SOBREVIVEU!", 24, Color(0.5, 1, 0.5))
					_txt(Vector2(0, 80), "%s caiu. A faculdade está salva." % str(r.get("chefe_final", "O chefe final")), 8, Color(0.8, 0.9, 0.8))
				else:
					_txt(Vector2(0, 60), "A CORRIDA ACABOU", 24, Color(1, 0.4, 0.4))
					_txt(Vector2(0, 80), "Você chegou até a fase %d de %d. Tenta de novo!" % [r.get("fase", 1), r.get("fases", 1)], 8, Color(0.9, 0.8, 0.8))
					if r.has("heroi_perdido"):   # herói criado morre de vez
						_txt(Vector2(0, 96), "%s morreu de vez. Crie outro herói na escolha de heróis." % str(r.heroi_perdido), 8, Color(1, 0.45, 0.4))
				if r.has("trazido"):   # herói criado vivo: o que voltou pro baú (#72)
					_txt(Vector2(0, 92), "Trouxe pra casa: " + Mochila.resumo(r.trazido), 8, Color(0.6, 0.9, 0.7))
					if not r.get("perdido_bau", {}).is_empty():
						_txt(Vector2(0, 102), "Sem lugar no baú: " + Mochila.resumo(r.perdido_bau), 8, Color(1, 0.7, 0.45))
				var tempo := float(r.get("tempo", 0))
				_txt(Vector2(0, 112), "Tempo %02d:%02d   Nível %d   Abates %d" % [int(tempo) / 60, int(tempo) % 60, r.get("nivel", 1), r.get("abates", 0)], 8)
				if _novo_recorde:
					_txt(Vector2(0, 128), "NOVO RECORDE!", 8, Color(1, 0.85, 0.3).lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 8)))
				x_dano = 115.0
				y = 150.0
			_tabela_armas(x_dano, y, r.get("armas", []))
			_txt(Vector2(0, 340), "Enter, clique ou A: voltar ao título", 8, Color(0.6, 0.6, 0.7))


## Tabela de dano por arma do fim da corrida (estilo tela "Results" do Vampire Survivors): ícone, nome, nível, dano total,
## DPS e tempo com a arma. O maior dano e o maior DPS ficam em amarelo. Até 6 linhas (as de mais dano); 410 px de largura.
func _tabela_armas(x: float, y: float, linhas: Array) -> void:
	var cab := Color(0.7, 0.8, 1)
	_tela.draw_rect(Rect2(x - 8, y - 14, 426, 36 + 20.0 * maxi(1, mini(linhas.size(), 6))), Color(0.03, 0.03, 0.08, 0.78))   # placa: o fundo animado não atrapalha a leitura
	_txt(Vector2(x, y), "Arma", 8, cab, 100, HORIZONTAL_ALIGNMENT_LEFT)
	_txt(Vector2(x + 190, y), "Nv", 8, cab, 28, HORIZONTAL_ALIGNMENT_RIGHT)
	_txt(Vector2(x + 222, y), "Dano", 8, cab, 66, HORIZONTAL_ALIGNMENT_RIGHT)
	_txt(Vector2(x + 292, y), "DPS", 8, cab, 56, HORIZONTAL_ALIGNMENT_RIGHT)
	_txt(Vector2(x + 352, y), "Tempo", 8, cab, 58, HORIZONTAL_ALIGNMENT_RIGHT)
	_tela.draw_rect(Rect2(x, y + 4, 410, 1), Color(0.35, 0.4, 0.55))
	y += 22.0
	if linhas.is_empty():
		_txt(Vector2(x, y), "Nenhuma arma causou dano.", 8, Color(0.6, 0.6, 0.7), 410, HORIZONTAL_ALIGNMENT_LEFT)
	var ouro: Color = Interface.cor("destaque")
	for i in mini(linhas.size(), 6):
		var l: Dictionary = linhas[i]
		var ic := Dados.icone(str(l.icone))
		if ic:
			_tela.draw_texture(ic, Vector2(x, y - 12))
		_txt(Vector2(x + 20, y), str(l.nome).left(18), 8, Color.WHITE, 164, HORIZONTAL_ALIGNMENT_LEFT)
		_txt(Vector2(x + 190, y), "EVO" if l.evo else str(l.nivel), 8, Color(0.8, 0.85, 0.95), 28, HORIZONTAL_ALIGNMENT_RIGHT)
		_txt(Vector2(x + 222, y), Interface.texto_dano(l.dano), 8, ouro if l.top_dano else Color(0.9, 0.9, 0.95), 66, HORIZONTAL_ALIGNMENT_RIGHT)
		_txt(Vector2(x + 292, y), Interface.texto_dano(l.dps), 8, ouro if l.top_dps else Color(0.9, 0.9, 0.95), 56, HORIZONTAL_ALIGNMENT_RIGHT)
		_txt(Vector2(x + 352, y), Interface.texto_tempo(l.tempo), 8, Color(0.7, 0.75, 0.85), 58, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 20.0


## Teste: abre uma tela, tira um print e fecha (--print_tela=titulo|herois|cartas|bau|fim|hazaki --fotos=pasta).
## Prints em vários instantes (segundos reais desde agora, separados por vírgula): tela_<nome>_1.png, _2.png...
func _fotos_seq(nome: String, seq: String) -> void:
	var pasta := str(_args.get("fotos", "user://"))
	var ult := 0.0
	var n := 0
	for tk in seq.split(","):
		var alvo := float(tk)
		await get_tree().create_timer(maxf(0.01, alvo - ult), true, false, true).timeout
		ult = alvo
		await RenderingServer.frame_post_draw
		n += 1
		get_viewport().get_texture().get_image().save_png(pasta.path_join("tela_%s_%d.png" % [nome, n]))


## Tira de recortes do herói (#97): a cada instante da --seq (s reais) corta ~80x88 px em volta dele, amplia 2x sem
## filtro e emenda lado a lado num PNG só (tela_<nome>.png). Dá pra ver respiração, balanço e golpe de uma vez.
func _tira_animacao(nome: String, seq: String) -> void:
	var pasta := str(_args.get("fotos", "user://"))
	var ult := 0.0
	var cortes: Array = []
	var zoom := int(_args.get("zoom", 3))
	for tk in seq.split(","):
		var alvo := float(tk)
		await get_tree().create_timer(maxf(0.01, alvo - ult), true, false, true).timeout
		ult = alvo
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var c: Vector2 = get_viewport().get_canvas_transform() * (_arena.jogador.global_position + Vector2(0, -28))
		var r := Rect2i(int(c.x) - 32, int(c.y) - 46, 64, 76).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		cortes.append(img.get_region(r))
	var tira := Image.create(cortes.size() * 64 * zoom, 76 * zoom, false, Image.FORMAT_RGBA8)
	tira.fill(Color(0.2, 0.2, 0.25))
	for i in cortes.size():
		var im: Image = cortes[i]
		im.resize(im.get_width() * zoom, im.get_height() * zoom, Image.INTERPOLATE_NEAREST)
		tira.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(i * 64 * zoom, 0))
	tira.save_png(pasta.path_join("tela_%s.png" % nome))


func _print_tela(qual: String) -> void:
	Config.temporario("pausar_fora", false)   # a janela perde o foco enquanto o print espera: não pode pausar
	if _args.has("grande"):
		Config.temporario("texto_hud", "grande")
	if _args.has("daltonico"):
		Config.temporario("daltonico", true)
	match qual:
		"entrada":   # abertura da fase (abertura.gd): --fase=1 (começo da corrida) | 6 (2ª região) | 2 (andar comum) --heroi=X --seq=0.5,1.2,... (s reais) [--pular=T pula em T s]
			_args["entrada"] = true
			_comecar(str(_args.get("heroi", "hazaki")))
			if _args.has("pular_em"):
				get_tree().create_timer(float(_args.pular_em), true, false, true).timeout.connect(func(): _arena.abertura.pular())
			# os instantes da --seq são do RELÓGIO DA ABERTURA (não do real): a primeira troca de região trava uns quadros carregando arte
			var pasta_e := str(_args.get("fotos", "user://"))
			var n_e := 0
			for tk in str(_args.get("seq", "0.3,0.8,1.3,1.7,1.9,2.2,2.8,3.5")).split(","):
				while _arena.abertura.ativa() and _arena.abertura._t < float(tk):
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				n_e += 1
				get_viewport().get_texture().get_image().save_png(pasta_e.path_join("tela_%s_%s_%d.png" % [qual, str(_args.get("fase", "1")), n_e]))
			get_tree().quit()
			return
		"herois":
			_estado = "herois"
		"titulo_beta":
			_sel = BETA[0]
		"salas":   # lista de salas depois de --espera s (abra antes um --online=host, de preferência com --topico=teste)
			_estado = "salas"
			Salas.procurar()
			await get_tree().create_timer(float(_args.get("espera", 4.0))).timeout
		"creditos":
			_estado = "creditos"
		"opcoes":
			_abrir_opcoes()
		"calor":   # tela do Calor (use --calor=couro:2,garras:1 pra ver níveis ligados)
			_abrir_calor("hazaki")
		"rolamento":   # rolamento de esquiva (#68): o herói no meio da volta (--espera=s de rolamento) e as barrinhas de fôlego
			_comecar(str(_args.get("heroi", "hazaki")))
			await get_tree().create_timer(1.8, true, false, true).timeout
			_arena.bot = false
			_arena.jogador.bot = false
			_arena.jogador.rolar(Vector2.RIGHT)
			await get_tree().create_timer(float(_args.get("espera", 0.1)), true, false, true).timeout
			Engine.time_scale = 0.02
		"aviso":   # marcas de aviso no chão (#68): um jacaré preparando a investida e um chefe prestes a soltar o anel
			_comecar("hazaki")
			await get_tree().create_timer(0.3, true, false, true).timeout
			_arena.bot = false
			var jp: Vector2 = _arena.jogador.position
			var jac = _arena.inimigos.criar("jacare_lodo", jp + Vector2(-150, -40))
			var che = _arena.inimigos.criar(str(_args.get("chefe", "rainha_sapo")), jp + Vector2(150, 40))
			await get_tree().create_timer(0.05, true, false, true).timeout
			if jac:
				jac.estado = 1
				jac.t_estado = 0.25
				jac.dir_inv = (jp - jac.pos).normalized()
			if che:
				che.t_anel = 0.2
			Engine.time_scale = 0.05   # quase parado: o print sai 0,6 s (tempo real) depois, ainda no meio do aviso
		"legibilidade":   # legibilidade (#72 marco 7): elite e chefe com barra, drops com etiqueta, áreas do herói e do inimigo marcadas
			_comecar(str(_args.get("heroi", "hazaki")))
			await get_tree().create_timer(1.8, true, false, true).timeout
			_arena.bot = false
			_arena.jogador.bot = false
			_arena.jogador.hp = 1.0e9
			_arena.diretor.bonus_minutos = -100.0
			_arena.inimigos.limpar()
			_arena.armas.lista.clear()
			_arena.coleta.limpar()
			var jl: Vector2 = _arena.jogador.position
			var eli = _arena.inimigos.criar("jacare_lodo", jl + Vector2(120, -70), 1, true)
			var che2 = _arena.inimigos.criar(str(_args.get("chefe", "rainha_sapo")), jl + Vector2(150, 60))
			for i in 8:   # alguns comuns de companhia: sem barra
				var cm = _arena.inimigos.criar("sapo_podre", jl + Vector2(-140 + i * 12, -90 + (i % 3) * 14))
				if cm:
					cm.vel = 0.0
			await get_tree().create_timer(0.05, true, false, true).timeout
			for q in [eli, che2]:
				if q:
					q.vel = 0.0
					q.t_nasc = 0.0
			if eli:
				eli.hp = eli.hpmax * 0.6
				eli.t_golpe = _arena.inimigos._t   # acabou de levar um golpe: o nome aparece
			if che2:
				che2.hp = che2.hpmax * 0.8
				che2.t_anel = 0.25   # anel de aviso do chefe (perigo, vermelho)
			_arena.coleta.soltar(jl + Vector2(-60, 40), "bau")
			_arena.coleta.soltar(jl + Vector2(-10, 60), "marmita")
			_arena.coleta.soltar(jl + Vector2(40, 40), "wifi")
			_arena.coleta.soltar(jl + Vector2(-100, 70), "fragmento")
			_arena.coleta.gema(jl + Vector2(-60, 90), 30.0)
			# áreas do herói (azul, discretas): uma poça que machuca, uma que vai explodir logo, e a aura
			var raio_p := 36.0
			_arena.armas.pocas.append({"pos": jl + Vector2(-110, -10), "raio": raio_p, "vida": 5.0, "total": 6.0, "dano": 1.0, "tique": 0.5, "t": 0.5,
				"segue": false, "arma": "", "variante": 0, "semente": 1.0, "rampa": Poca.CAFE})
			_arena.armas.pocas.append({"pos": jl + Vector2(-20, -90), "raio": raio_p, "vida": 0.5, "total": 6.0, "dano": 1.0, "tique": 0.5, "t": 0.5,
				"segue": false, "arma": "", "variante": 1, "semente": 2.0, "rampa": Poca.CAFE, "explode": {"raio_mult": 1.8, "dano_mult": 4.0}})
			_arena.armas.adicionar("wifi")
			Engine.time_scale = 0.05
		"animacao":   # #97: tira do herói (recortes ampliados lado a lado): --heroi=X --cena=parado|andar|golpe|dano|morte --seq=t1,t2,.. (s reais) --lento=N
			_comecar(str(_args.get("heroi", "nicao")))
			await get_tree().create_timer(0.5, true, false, true).timeout
			var _espera := 0
			while _arena.jogador._nome_t <= 0.0 and _espera < 600:   # a chegada ainda não começou
				_espera += 1
				await get_tree().process_frame
			while _arena.jogador._nome_t > 0.0 or _arena.jogador._ent_t > 0.0:   # e agora espera acabar (queda e nome)
				await get_tree().process_frame
			_arena.bot = false
			_arena.jogador.bot = false
			_arena.jogador.hp = 1.0e9
			_arena.inimigos.limpar()
			_arena.diretor.bonus_minutos = -100.0
			var cena := str(_args.get("cena", "parado"))
			var jg2 = _arena.jogador
			Engine.time_scale = float(_args.get("lento", 1.0))
			match cena:
				"andar":
					var xy2 := str(_args.get("andar", "1,0")).split(",")
					jg2.entrada_forcada = Vector2(float(xy2[0]), float(xy2[1]))
				"golpe":
					jg2.atacou(Vector2.RIGHT)
				"dano":
					jg2.sofrer(1.0, "teste", 0.5, Vector2(-110, 0))
				"morte":
					jg2.hp = 0.0
					_arena.morrer("teste")
			await _tira_animacao(qual + "_" + str(_args.get("heroi", "nicao")) + "_" + cena, str(_args.get("seq", "0.0,0.15,0.3,0.45,0.6,0.75,0.9,1.05")))
			get_tree().quit()
			return
		"golpe":   # combate estilo Dimraeth: --heroi=X --arma=Y (katana, arte_marcial, cabo_rede, lanca, martelo) num grupo
			# de --inimigo parado à direita; o golpe sai já em câmera lenta (--lento) e as fotos seguem o --seq
			_comecar(str(_args.get("heroi", "beto")))
			await get_tree().create_timer(1.8, true, false, true).timeout
			_arena.bot = false
			_arena.jogador.bot = false
			_arena.jogador.hp = 1.0e9   # sem invencível: invencível pisca e enganava no print
			_arena.diretor.bonus_minutos = -100.0
			_arena.inimigos.limpar()
			_arena.armas.lista.clear()
			var arma_g := str(_args.get("arma", "katana"))
			_arena.armas.adicionar(arma_g)
			if _args.has("nivel_arma"):   # --nivel_arma=N: nível da arma no print (99 = o máximo), pra comparar a curva de crescimento
				_arena.armas.achar(arma_g).nivel = clampi(int(_args.nivel_arma), 1, _arena.armas.nivel_max(arma_g))
				_arena.armas.preaquecer()
				Config.temporario("numeros_dano", false)   # sem números por cima do golpe
			var jg: Vector2 = _arena.jogador.position
			for i in 6:
				var vg = _arena.inimigos.criar(str(_args.get("inimigo", "jacare_lodo")), jg + Vector2(34 + (i % 3) * 14, -22 + int(i / 3.0) * 30), 1)
				if vg:
					vg.vel = 0.0
					vg.t_nasc = 0.0
					if _args.has("nivel_arma"):   # alvos que aguentam todos os golpes: a comparação dos níveis fica na área do golpe, não em quem morreu
						vg.hp = 1.0e9
						vg.hpmax = 1.0e9
			await get_tree().create_timer(0.1, true, false, true).timeout
			_arena.armas.achar(arma_g).t = 0.0
			Engine.time_scale = float(_args.get("lento", 0.08))
			await _fotos_seq(qual + "_" + arma_g, str(_args.get("seq", "0.1,0.4,0.7,1.0,1.3,1.6")))
			get_tree().quit()
			return
		"elementos":   # estados de elemento (#72 marco 5): --heroi=X --cena=estados|reacao|poca; fotos pela --seq (câmera lenta com --lento)
			_comecar(str(_args.get("heroi", "beto")))
			await get_tree().create_timer(1.8, true, false, true).timeout
			_arena.bot = false
			_arena.jogador.bot = false
			_arena.jogador.hp = 1.0e9
			_arena.diretor.bonus_minutos = -100.0
			_arena.inimigos.limpar()
			_arena.armas.lista.clear()
			var ie = _arena.inimigos
			var el_e = ie.elementos
			var jp: Vector2 = _arena.jogador.position
			var cena := str(_args.get("cena", "estados"))
			_arena.hud.limpar_mensagens()
			var lote: Array = []
			if cena == "estados":   # uma fileira: queimando, gelado, congelado, envenenado, eletrificado, e dois elites com tudo
				var pares := [["fogo", 5.0], ["gelo", 2.0], ["gelo", 4.0], ["veneno", 8.0], ["raio", 3.0]]
				for i in pares.size():
					var ve = ie.criar("carnical", jp + Vector2(-100 + i * 50, 40), 1)
					lote.append(ve)
					el_e.aplicar(ve, pares[i][0], pares[i][1])
				for k in 2:
					var vl = ie.criar("galhudo", jp + Vector2(-60 + k * 120, 100), 1, true)
					lote.append(vl)
					for e2 in ["fogo", "veneno", "raio"]:
						el_e.aplicar(vl, e2, 1.5 + 1.5 * k if e2 != "veneno" else 1.5)
			elif cena == "reacao":   # vapor e descarga ao lado um do outro, num grupo de vizinhos
				for i in 8:
					var vr = ie.criar("jacare_lodo", jp + Vector2(-70 + (i % 4) * 34, -50 + int(i / 4.0) * 40), 1)
					lote.append(vr)
				await get_tree().create_timer(0.1, true, false, true).timeout
				el_e.aplicar(lote[1], "fogo", 2.0)
				el_e.aplicar(lote[1], "gelo", 2.0)
			elif cena == "poca":   # a Geada Rachada no chão com bichos dentro, um já congelado
				_arena.armas.adicionar("geada")
				for i in 5:
					var vp = ie.criar("jacare_lodo", jp + Vector2(40 + (i % 3) * 26, -26 + int(i / 3.0) * 36), 1)
					lote.append(vp)
				_arena.armas.pocas.append({"pos": jp + Vector2(66, -8), "raio": 70.0, "vida": 30.0, "total": 30.0, "dano": 3.0, "tique": 0.4, "t": 0.0,
					"segue": false, "arma": "geada", "variante": 1, "semente": 2.0, "rampa": _arena.armas.rampa_de(Dados.item("geada")), "gelo": true})
			for ve in lote:
				if ve:
					ve.vel = 0.0
					ve.t_nasc = 0.0
					ve.hp = 1.0e6
					ve.hpmax = 1.0e6
			await get_tree().create_timer(0.1, true, false, true).timeout
			if cena == "poca":
				for i in 4:
					_arena.armas._pocas(0.4)
			Engine.time_scale = float(_args.get("lento", 0.5))
			await _fotos_seq("elementos_" + cena, str(_args.get("seq", "0.3,0.8")))
			get_tree().quit()
			return
		"criacao":   # tela de criar herói (#72): --raca=N e --classe=N escolhem as opções (índice nas listas)
			_estado = "criacao"
			var tc := TelaCriacao.new()
			tc.raca = int(_args.get("raca", 0))
			tc.classe = int(_args.get("classe", 0))
			tc.linha = int(_args.get("linha", 0))
			if _args.has("ficha"):   # --ficha=Nome/raça/classe/defeito/f,v,a,m,s/pele,cabelo,roupa: a tela já com tudo preenchido
				tc.ficha = _ficha_de_texto(str(_args.ficha))
			add_child(tc)
		"herois_lista":   # tela "Meus heróis" (#72): cria 3 heróis num arquivo de teste e abre a lista (--vaga=N escolhe a vaga, --apagar abre a confirmação)
			Criacao.arquivo = "user://teste_lista.json"
			Criacao.apagar()
			for f in ["Brutus/orc/guerreiro/manco/3,2,0,0,0/4,1,2", "Lyra/elfo_sombrio/mago//0,1,2,3,2/5,2,5", "Pip/goblin/ladino/azarado/1,0,3,0,2/6,6,3"]:
				Criacao.salvar_ficha(_ficha_de_texto(f))
			_estado = "criacao"
			var th := TelaHerois.new()
			th.sel = int(_args.get("vaga", 0))
			add_child(th)
			if _args.has("apagar"):
				await get_tree().process_frame
				th.confirmando = str(Criacao.carregar(false).ids[th.sel])
		"preparo", "bau":   # Preparo e Baú (#72, marcos 3 e 4): um herói de teste (arquivo próprio) com o kit inicial; --mochila= já deixa itens escolhidos
			Criacao.arquivo = "user://teste_preparo.json"
			Criacao.apagar()
			var pid := Criacao.salvar_ficha(_ficha_de_texto("Brutus/orc/guerreiro/manco/3,2,0,0,0/4,1,2"))
			var bau := Mochila.bau_limpo(Criacao.bau_de(pid))
			for k in ["carne_seca", "pocao_vigor", "pergaminho_gelo", "amuleto_trevo", "amuleto_fenix"]:   # uns itens a mais pra lista ter o que mostrar
				bau[k] = 1
			bau["pocao_cura"] = 3
			Criacao.definir_bau(pid, bau)
			_estado = "preparo"
			var tp := TelaPreparo.new()
			tp.heroi_id = pid
			tp.bau = bau
			tp.modo = qual
			if qual == "preparo":
				tp.mochila = Mochila.de_texto(str(_args.get("mochila", "pao_duro,pocao_cura:2,bomba,amuleto_corvo")))
			add_child(tp)
			await get_tree().process_frame
			tp._sel = int(_args.get("vaga", 0))
			tp._rolar()
		"mochila_hud":   # HUD com a mochila (#72): uma corrida com o herói criado de teste e a mochila de --mochila=
			_comecar(str(_args.get("heroi", "c:orc:guerreiro")))
			await get_tree().create_timer(float(_args.get("espera", 3.0))).timeout
		"especial":   # --heroi=X --estresse=N: usa o especial no meio dos inimigos e tira o print depois de --espera s
			_comecar(str(_args.get("heroi", "hazaki")))
			await get_tree().create_timer(1.0).timeout
			_arena.especial.recarga = 0.0
			_arena.especial.usar()
			await get_tree().create_timer(float(_args.get("espera", 0.25))).timeout
			Engine.time_scale = 0.03   # o print sai 0,6 s (tempo real) depois: o efeito curto quase para, pra caber na foto
		"dragao":   # com --bot --dragao (e --estresse=N pra ter vírus): --espera=0.6 pega o meio da transformação
			_comecar("hazaki")
			await get_tree().create_timer(float(_args.get("espera", 5.0))).timeout
		"hazaki":   # Hazaki em ação (#32): --bot --espera=N; com --equip ele já entra com katana, aura e equipamentos
			_comecar("hazaki")
			await get_tree().create_timer(0.3).timeout
			if _args.has("equip"):
				_arena.armas.adicionar("katana")
				_arena.armas.adicionar("aura_hazaki")
				_arena.equipamentos["cabeca"] = "cabeca_guerreiro"
				_arena.equipamentos["peitoral"] = "armadura_samurai"
				_arena.atualizar_visual()
			if _args.has("andar"):   # --andar=1,1: anda nessa direção (print das 8 direções)
				var xy := str(_args.andar).split(",")
				_arena.bot = false
				_arena.jogador.bot = false
				_arena.jogador.entrada_forcada = Vector2(float(xy[0]), float(xy[1]))
			await get_tree().create_timer(float(_args.get("espera", 6.0))).timeout
		"cenario":   # #32 item 2: cenário da fase --fase=N (1 laboratório, 4 masmorra, 8 cidade); --espera=N s de jogo
			_comecar("hazaki")
			await get_tree().create_timer(float(_args.get("espera", 3.0))).timeout
			if _args.has("bichos"):   # bichos do cenário bem perto do herói parado, pra ver a fuga (--espera=0.4 pega no meio dela)
				_arena.bot = false
				var cel: Dictionary = _arena.chao.cenario.celula(floori(_arena.jogador.position.x / 150.0), floori(_arena.jogador.position.y / 150.0))
				var i := 0
				for tipo in ["rato", "morcego", "corvo", "rato", "corvo"]:
					cel.bichos.append({"tipo": tipo, "pos": _arena.jogador.position + Vector2(28 + i * 14, -20 + i * 14), "estado": 0, "t": 0.0, "dir": Vector2.ZERO,
						"alt": 0.0, "ph": float(i), "lado": 1.0})
					i += 1
				_arena.inimigos.limpar()
				await get_tree().create_timer(0.3).timeout
			if _args.has("limpo"):   # sem vírus em campo, pra ver só o cenário (props, detalhes, bichos)
				_arena.inimigos.limpar()
				_arena.diretor.tempo = 0.0
		"santuario":   # #21: Santuário do Dragão (combate) e de dádivas por perto, HUD com 2 de 3 fragmentos; "dadivas" mostra a escolha
			_comecar("hazaki")
			await get_tree().create_timer(0.3).timeout
			var jp: Vector2 = _arena.jogador.position
			_arena.descobertas.fragmentos["dragao"] = 2
			_arena.descobertas.dadivas.append({"id": "furia", "raridade": "rara"})
			_arena.descobertas.dadivas.append({"id": "olho", "raridade": "epica"})
			_arena.chao.santuarios.append({"pos": jp + Vector2(75, -35), "tipo": "fragmento", "variacao": "combate", "carga": 0.55, "usado": false})
			_arena.chao.santuarios.append({"pos": jp + Vector2(-120, 20), "tipo": "dadiva", "variacao": "", "carga": 0.0, "usado": false})
			_arena.chao.santuarios.append({"pos": jp + Vector2(420, -60), "tipo": "maldito", "variacao": "", "carga": 0.0, "usado": false})
			if _args.has("dadivas"):
				_arena.cartas.escolher("Dádiva do santuário", _arena.descobertas.oferta_dadivas(Sorte.fluxo("dadiva")))
			await get_tree().create_timer(0.5, true, false, true).timeout
		"santuario2":   # #63: prova em andamento (mini-chefe + anel de tempo), santuário selado (pré-requisito 1/2) e relíquia por perto
			_comecar("hazaki")
			await get_tree().create_timer(0.3).timeout
			var jq: Vector2 = _arena.jogador.position
			_arena.chao.santuarios.clear()
			var prova := {"pos": jq + Vector2(95, -25), "tipo": "prova", "variacao": "", "carga": 1.0, "usado": false}
			_arena.chao.santuarios.append(prova)
			_arena.chao.santuarios.append({"pos": jq + Vector2(-110, 25), "tipo": "selado", "variacao": "", "carga": 0.0, "usado": false, "requisito": "piras", "qtd": 2})
			_arena.chao.santuarios.append({"pos": jq + Vector2(-230, -60), "tipo": "tomada", "variacao": "", "carga": 0.0, "usado": true})
			_arena.chao.santuarios.append({"pos": jq + Vector2(-230, 100), "tipo": "tomada", "variacao": "", "carga": 0.0, "usado": false})
			_arena.chao.santuarios.append({"pos": jq + Vector2(10, 130), "tipo": "reliquia", "variacao": "", "carga": 0.0, "usado": false})
			_arena.descobertas.ativar(prova)
			await get_tree().create_timer(2.0, true, false, true).timeout
		"dupla":   # #63: oferta de dádivas com a dádiva em dupla (Fúria Antiga + Passo do Vento)
			_comecar("hazaki")
			await get_tree().create_timer(0.3).timeout
			_arena.descobertas.dadivas.append({"id": "furia", "raridade": "rara"})
			_arena.descobertas.dadivas.append({"id": "vento", "raridade": "comum"})
			var ofer: Array = []
			for _i in 12:
				ofer = _arena.descobertas.oferta_dadivas(Sorte.fluxo("dadiva"), "", ["furia", "vento"])
				if ofer.size() > 3:
					break
			_arena.cartas.escolher("Dádiva do santuário", ofer)
			_arena.cartas._sel = ofer.size() - 1
		"comp":   # #63: cartas de comportamento ao lado de uma arma e um passivo comuns
			_comecar("hazaki")
			await get_tree().create_timer(0.3).timeout
			_arena.armas.adicionar("pendrive")
			_arena.armas.lista[_arena.armas.lista.size() - 1].nivel = 3
			_arena.armas.adicionar("wifi")
			_arena.armas.lista[_arena.armas.lista.size() - 1].nivel = 4
			var pm: Array = [_arena._carta_comp(_arena.armas.achar("pendrive"), "ricochete"), _arena._carta_comp(_arena.armas.achar("wifi"), "pulso"),
				_arena._carta("arma", "pendrive", 4), _arena._carta("passivo", "overclock", 1)]
			_arena.cartas.escolher("Subiu pro nível 9!", pm)
			_arena.cartas._sel = 0
		"resultado":   # tela de resultados da fase (#32): --espera=N segundos de contagem (padrão 4)
			_comecar("hazaki")
			await get_tree().create_timer(0.3, true, false, true).timeout
			var st: Dictionary = _arena.fase_stat
			st.tempo = 98.0
			st.abates = 412
			st.chefes = 1
			st.xp = 380.0
			st.nivel_ini = 3
			st.nivel_fim = 6
			st.dano = {"katana": 5230.0, "aura_hazaki": 2100.0, "pendrive": 900.0, "cafe": 150.0}
			st.itens = [{"icone": "katana"}, {"icone": "aura_hazaki"}, {"icone": "energetico"}, {"icone": "cafe"}]
			_arena.resultado.abrir(st)
			await get_tree().create_timer(float(_args.get("espera", 4.0)), true, false, true).timeout
		"mapa", "loja":   # #32 item 8: tela do mapa no andar --andar=N (padrão 4) com a trilha do robô; "loja" mostra a vitrine
			_comecar("hazaki")
			await get_tree().create_timer(0.3, true, false, true).timeout
			_arena.bot = false
			_arena.entre_fases = true
			_arena.saltar_para_andar(int(_args.get("andar", 4)) - 1)
			_arena.ouro = 260
			if qual == "mapa":
				_arena.tela_mapa.abrir()
			else:
				_arena.loja.abrir(_arena.sortear_cartas(Sorte.criar("loja", 3)))
				_arena.loja._pos = Vector2(250, 190)   # a sala da loja (#112); --vitrine abre a lista de compras
				_arena.loja._vitrine = _args.has("vitrine")
			await get_tree().create_timer(float(_args.get("espera", 0.5)), true, false, true).timeout
		"prorrogacao", "saida":   # #112: HUD do cronômetro (--pror=N segundos de prorrogação, 0 = janela do chefe) e o portal de saída; "saida" aceita --seq=t1,t2 (s reais) com --entrar pra ver a sucção e o clarão
			_comecar("hazaki")
			await get_tree().create_timer(0.5, true, false, true).timeout
			_arena.bot = false
			_arena.jogador.bot = false
			_arena.jogador.invencivel = 999.0
			_arena.inimigos.limpar()
			var dr = _arena.diretor
			var fa: Dictionary = dr.fases()[dr.fase_idx]
			dr.final_chamado = true
			dr.chefe_fase = str(fa.get("chefe", ""))
			var base_t := float(fa.get("duracao", 600)) + float(Dados.json("prorrogacao").get("janela_chefe", 120.0))
			if qual == "prorrogacao":
				dr.t_fase = base_t + float(_args.get("pror", 23.0)) if _args.has("pror") else base_t - 95.0
				for i in 25:
					_arena.inimigos.criar("trojan", _arena.jogador.position + Vector2(randf_range(-200, 200), randf_range(-120, 120)), 1)
			else:
				dr.t_fase = base_t - 20.0
				_arena.abrir_saida(_arena.jogador.position + Vector2(70, -10))
				if _args.has("entrar"):
					_arena.jogador.position += _arena.saida.pos - _arena.jogador.centro() + Vector2(0, 6)
					_arena.saida.bot_segurar = true
				if _args.has("seq"):
					await _fotos_seq("saida", str(_args.seq))
					get_tree().quit()
					return
			await get_tree().create_timer(float(_args.get("espera", 0.8)), true, false, true).timeout
		"entrada_chefe":   # placa do chefe no meio da entrada: --espera=N segundos reais depois que ele nasce (padrão 1)
			_comecar("hazaki")
			await get_tree().create_timer(0.3, true, false, true).timeout
			var chefe_id := str(_args.get("chefe", "trojan_gigante"))   # --chefe=arauto pra ver o chefe de horror
			_arena.inimigos.criar(chefe_id, _arena.jogador.position + Vector2(260, -40), 1)
			_arena.chefe_final_chegou(false, chefe_id)
			await get_tree().create_timer(float(_args.get("espera", 1.0)), true, false, true).timeout
		"horror":   # fase de horror (--fase=6 é o padrão): bichos perto e longe do herói, --espera=N segundos antes do print
			if not _args.has("fase"):
				_args["fase"] = "6"
			_comecar("hazaki")
			await get_tree().create_timer(0.3, true, false, true).timeout
			var jp2: Vector2 = _arena.jogador.position
			var elenco := [["carnical", Vector2(-70, 40)], ["carnical", Vector2(-95, 62)], ["cao_ossos", Vector2(110, 50)],
				["cavaleiro_oco", Vector2(60, -85)], ["espectro", Vector2(-150, -50)], ["abominacao", Vector2(185, -20)],
				["carnical", Vector2(-230, 110)], ["cao_ossos", Vector2(250, 130)], ["espectro", Vector2(-260, -120)], ["cavaleiro_oco", Vector2(-120, 140)]]
			if _args.has("so"):   # --so=abominacao: um bicho só, a 130 px do herói
				elenco = [[str(_args.so), Vector2(130, 0)]]
				_arena.inimigos.limpar()
				_arena.diretor.bonus_minutos = -100.0   # sem nascer nada além dele
			for e in elenco:
				_arena.inimigos.criar(e[0], jp2 + e[1], 1)
			for v in _arena.inimigos.lista:
				v.vel = 0.0   # parados, pra a foto
			await get_tree().create_timer(float(_args.get("espera", 2.0)), true, false, true).timeout
		"conjuntos", "objetivo", "missao":   # #112 (missao): missão do chefe em andamento (--tipo=fragmentos|pilares|selos|invocar). #63: HUD com os conjuntos da build e (objetivo) um objetivo em andamento (--objetivo=pira|totens|fugitivo, --pronto=0..1 de quanto já foi)
			_args["fase"] = str(_args.get("fase", "2"))
			_comecar("hazaki")
			await get_tree().create_timer(1.8, true, false, true).timeout
			_arena.bot = false
			_arena.jogador.invencivel = 999.0
			_arena.inimigos.limpar()
			_arena.armas.lista.clear()
			for id in ["pendrive", "machado", "lanca", "cafe"]:
				_arena.armas.adicionar(id)
			_arena.passivos = {"energetico": 2, "mouse": 1, "marmita": 1, "monitor": 1}
			_arena.equipamentos = {"cabeca": "cabeca_guerreiro", "peitoral": "armadura_samurai", "pes": "botas_guerra"}
			_arena.build_mudou()
			if qual == "objetivo":
				var ob = _arena.objetivo
				ob._zerar()
				ob._iniciar(str(_args.get("objetivo", "pira")))
				var alvo_ob: float = ob.alvo
				if ob.id == "pira":
					_arena.jogador.position = ob.pos + Vector2(60, 40)
					ob.prog = alvo_ob * float(_args.get("pronto", 0.55))
				else:
					ob.prog = floorf(alvo_ob * float(_args.get("pronto", 0.0)))
				ob.resta -= 20.0
				ob._marcas()
				await get_tree().create_timer(2.4, true, false, true).timeout   # o anúncio grande some
			if qual == "missao":
				var ms = _arena.missao
				ms._zerar()
				ms._iniciar(str(_args.get("tipo", "fragmentos")))
				if not ms.pontos.is_empty():
					ms.pontos[0].ok = true
					_arena.jogador.position = ms.pontos[-1].pos + Vector2(40, 30)
				elif ms.tem_altar:
					_arena.jogador.position = ms.altar + Vector2(50, 30)
				await get_tree().create_timer(2.4, true, false, true).timeout
			if _args.has("muitos"):   # #123: horda em volta do jogador e um baú no meio, pra conferir que o marcador do objetivo continua legível
				_arena.armas.lista.clear()
				var jc: Vector2 = _arena.jogador.position
				for k in int(_args.get("muitos", 40)):
					_arena.inimigos.criar("carnical", jc + Vector2.from_angle(k * 0.9) * (20.0 + float(k) * 4.0), 1)
				_arena.coleta.itens.append({"pos": jc + Vector2(30, 0), "tipo": "bau", "valor": 0, "puxando": false, "vel": 0.0, "t0": 0.0})
			await get_tree().create_timer(0.5, true, false, true).timeout
		"mortes":   # #32: 8 inimigos morrem de 8 causas; prints no meio dos efeitos (--seq=0.15,0.4,0.7 em segundos reais, --reduzida, --conj=virus)
			if not _args.has("fase") and str(_args.get("conj", "horror")) != "virus":
				_args["fase"] = "6"
			Config.temporario("numeros_dano", false)   # números de 1e9 sujariam o print
			if _args.has("reduzida"):
				Config.temporario("mortes", "reduzida")
			_comecar("hazaki")
			await get_tree().create_timer(1.8, true, false, true).timeout
			_arena.bot = false
			_arena.jogador.invencivel = 999.0
			_arena.armas.lista.clear()
			_arena.diretor.bonus_minutos = -100.0
			_arena.inimigos.limpar()
			var jm: Vector2 = _arena.jogador.position
			var tipos_m: Array = ["carnical", "cao_ossos", "cavaleiro_oco", "espectro", "carnical", "cao_ossos", "abominacao", "cavaleiro_oco"]
			if str(_args.get("conj", "horror")) == "virus":
				tipos_m = ["bug", "popup", "spam", "trojan", "minerador", "spam", "bug", "trojan"]
			var causas_m: Array = [["baforada", ""], ["poder_elemental", "gelo"], ["wifi", ""], ["katana", ""], ["arte_marcial", ""], ["desert_eagles", ""], ["aura_hazaki", ""], ["energia_draconica", ""]]
			var posm: Array = [Vector2(-225, -70), Vector2(-75, -70), Vector2(75, -70), Vector2(225, -70), Vector2(-225, 70), Vector2(-75, 70), Vector2(75, 70), Vector2(225, 70)]
			var alvos_m: Array = []
			for i in 8:
				var vm = _arena.inimigos.criar(tipos_m[i], jm + posm[i], 1)
				vm.vel = 0.0
				vm.t_nasc = 0.0
				alvos_m.append(vm)
			await get_tree().create_timer(0.3, true, false, true).timeout
			for i in 8:
				alvos_m[i].causa_pend = causas_m[i][1]
				_arena.inimigos.ferir(alvos_m[i], 1.0e9, Vector2(60, -10), causas_m[i][0])
			await _fotos_seq(qual, str(_args.get("seq", "0.15,0.35,0.6")))
			get_tree().quit()
			return
		"virada":   # monstros virando com sprites de verdade: um monstro (--bicho=cavaleiro_oco|cao_ossos...) dá meia volta em torno do herói, da esquerda pra direita, e tira um print a cada passo
			_args["fase"] = str(_args.get("fase", "6"))
			_comecar("hazaki")
			await get_tree().create_timer(1.8, true, false, true).timeout
			_arena.bot = false
			_arena.jogador.invencivel = 999.0
			_arena.armas.lista.clear()
			_arena.diretor.bonus_minutos = -100.0
			_arena.inimigos.limpar()
			var jv: Vector2 = _arena.jogador.position
			var bv = _arena.inimigos.criar(str(_args.get("bicho", "cavaleiro_oco")), jv + Vector2(-80, 0), 1)
			bv.vel = 0.0
			bv.t_nasc = 0.0
			var pasta_v := str(_args.get("fotos", "user://"))
			await get_tree().create_timer(0.4, true, false, true).timeout
			for n in 11:
				var ang := -PI * 0.5 + PI * n / 10.0   # -90 (esquerda) ... 0 (embaixo, de frente pra câmera) ... +90 (direita)
				bv.pos = jv + Vector2(sin(ang), cos(ang) * (-1.0 if _args.has("frente") else 1.0)) * 80.0   # sem --frente: ele passa embaixo do herói e mostra as costas; com --frente passa em cima e mostra a frente
				bv.t_nasc = 0.0
				await get_tree().create_timer(0.22, true, false, true).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(pasta_v.path_join("virada%s_%s_%02d.png" % ["_frente" if _args.has("frente") else "", str(_args.get("bicho", "cavaleiro_oco")), n]))
			get_tree().quit()
			return
		"cerco":   # fase 6: monstros de horror cercando o herói, cada um olhando pra ele
			_args["fase"] = "6"
			_comecar("hazaki")
			await get_tree().create_timer(1.8, true, false, true).timeout
			_arena.bot = false
			_arena.jogador.invencivel = 999.0
			_arena.armas.lista.clear()
			_arena.diretor.bonus_minutos = -100.0
			_arena.inimigos.limpar()
			var jc: Vector2 = _arena.jogador.position
			var tipos_c := ["carnical", "cao_ossos", "cavaleiro_oco", "espectro", "carnical", "cao_ossos", "cavaleiro_oco", "espectro", "abominacao", "carnical", "cao_ossos", "cavaleiro_oco"]
			for i in tipos_c.size():
				var ac := TAU * i / tipos_c.size() + 0.2
				var bc = _arena.inimigos.criar(tipos_c[i], jc + Vector2(cos(ac) * 130.0, sin(ac) * 85.0), 1)
				bc.vel = 0.0
				bc.t_nasc = 0.0
			await get_tree().create_timer(1.0, true, false, true).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(str(_args.get("fotos", "user://")).path_join("cerco_fase6.png"))
			get_tree().quit()
			return
		"finalizacao":   # #32: chefe morto por --arma=katana|desert_eagles|arte_marcial|aura_hazaki|poder_elemental|pendrive (--chefe=, --seq=, --reduzida)
			Config.temporario("numeros_dano", false)   # números de 1e9 sujariam o print
			if _args.has("reduzida"):
				Config.temporario("mortes", "reduzida")
			if _args.has("fase") == false and str(_args.get("chefe", "trojan_gigante")) == "arauto":
				_args["fase"] = "6"
			_comecar("hazaki")
			await get_tree().create_timer(1.8, true, false, true).timeout
			_arena.bot = false
			_arena.jogador.invencivel = 999.0
			_arena.armas.lista.clear()
			_arena.diretor.bonus_minutos = -100.0
			_arena.inimigos.limpar()
			var bm = _arena.inimigos.criar(str(_args.get("chefe", "trojan_gigante")), _arena.jogador.position + Vector2(130, -10), 1)
			bm.vel = 0.0
			bm.t_nasc = 0.0
			await get_tree().create_timer(0.3, true, false, true).timeout
			_arena.inimigos.ferir(bm, 1.0e9, Vector2(60, 0), str(_args.get("arma", "katana")))
			await _fotos_seq(qual + "_" + str(_args.get("arma", "katana")), str(_args.get("seq", "0.2,0.5,0.8,1.1,1.5")))
			get_tree().quit()
			return
		"cartas4":   # 4 cartas de tipos diferentes: arma exclusiva nova, equipamento, arma em nível alto e passivo (--daltonico / --grande testam as opções)
			_comecar("hazaki")
			await get_tree().create_timer(0.3).timeout
			_arena.armas.adicionar("pendrive")
			_arena.passivos["overclock"] = 1
			var kat: Dictionary = _arena._carta("arma", "katana", 1)
			var mesa: Array = [kat, _arena._carta("equipamento", "cabeca_guerreiro", 1), _arena._carta("arma", "pendrive", 3), _arena._carta("passivo", "overclock", 2)]
			_arena.cartas.escolher("Subiu pro nível 12!", mesa)
			_arena.cartas._sel = 2
		"dadivas4":   # dádivas (raridade) + evolução na mesma tela
			_comecar("hazaki")
			await get_tree().create_timer(0.3).timeout
			_arena.cartas.escolher("Dádiva do santuário", _arena.descobertas.oferta_dadivas(Sorte.fluxo("dadiva")))
		"pausa":
			_comecar("hazaki")
			await get_tree().create_timer(0.3).timeout
			_arena.hud.pausar()
		"hud_chefe":   # chefe fora da tela (seta vermelha com a distância) e dano agrupado: --grande testa o texto do HUD
			_comecar("hazaki")
			await get_tree().create_timer(0.3).timeout
			_arena.inimigos.criar("trojan_gigante", _arena.jogador.position + Vector2(420, -150), 1)
			for i in 6:
				_arena.efeitos.numero(_arena.jogador.position + Vector2(40, -30), 7.0 + i)
			_arena.efeitos.numero(_arena.jogador.position + Vector2(-50, -20), 33.0, Color.WHITE, true)
			_arena.efeitos.numero(_arena.jogador.position + Vector2(0, -50), 12.0, Color(1, 0.6, 0.55))
			_arena.mensagem("Dádiva: Fúria (RARA)", Color(0.4, 0.7, 1))
			await get_tree().create_timer(0.1).timeout
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
				"dano": [["water_cooler", 52000], ["cafe", 21000], ["pendrive", 9000]],
				"armas": Interface.tabela_armas({"water_cooler": 52000.0, "cafe": 21000.0, "pendrive": 9000.0, "katana": 15000.0},
					{"water_cooler": 6, "cafe": 4, "pendrive": 8, "katana": 3}, {"water_cooler": 410.0, "cafe": 560.0, "pendrive": 642.0, "katana": 90.0}, 642.0)}
			_novo_recorde = true
			if _args.has("perdido"):   # --perdido: a derrota de um herói criado, que morre de vez
				_resumo.merge({"vitoria": false, "fase": 7, "fases": 25, "heroi_perdido": "Orc Guerreiro"}, true)
				_novo_recorde = false
			if _args.has("trazido"):   # --trazido: o que voltou pro baú de um herói criado que venceu (#72)
				_resumo["trazido"] = {"pocao_cura": 1, "bomba": 1, "amuleto_corvo": 1, "carne_seca": 1}
				_resumo["perdido_bau"] = {"pao_duro": 1}
			_estado = "fim"
	await get_tree().create_timer(0.6, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(_args.get("fotos", "user://")).path_join("tela_%s.png" % qual))
	get_tree().quit()

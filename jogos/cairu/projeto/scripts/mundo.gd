extends Node2D
## Um capítulo jogável: mapas, jogador, NPCs, portas e as cenas.
## Guarda o estado do capítulo: marcas (flags), cenas já vistas e onde cada NPC está.

signal sair
signal capitulo_completo(proximo: String)

const Personagem := preload("res://scripts/personagem.gd")
const Figurantes := preload("res://scripts/figurantes.gd")
const Movel := preload("res://scripts/movel.gd")
const Animado := preload("res://scripts/animado.gd")
const Mapa := preload("res://scripts/mapa.gd")
const Dialogo := preload("res://scripts/dialogo.gd")
const Diretor := preload("res://scripts/diretor.gd")
const Painel := preload("res://scripts/painel.gd")
const Pausa := preload("res://scripts/pausa.gd")
const Opcoes := preload("res://scripts/opcoes.gd")
const VELOCIDADE := 75.0
const ALCANCE := 36.0
const TONS := {"normal": "ffffff", "dia": "ffffff", "tarde": "ffd2a8", "entardecer": "f0b090",
	"noite": "6a78b8", "escuro": "3a3f60", "sepia": "e0c8a0", "lembranca": "d8c8f0"}

var capitulo: Dictionary
var flags := {}         # marcas: "nome" -> true
var npc_estado := {}    # mudanças feitas pelas cenas: id -> {mapa, x, y, dir, visivel, cena...}
var vistas := {}        # cena -> quantas vezes já rodou
var tom_atual := "normal"
var em_cena := false
var _figs := Figurantes.new()   # alunos de fundo (capitulos/figurantes.json)
var _relogio := 0.0     # segundos de jogo livre (sem cena), pra "rotina" dos NPCs
var _rotina_atual := {} # id -> índice da parada da rotina em que ele está
var cena_atual := ""
var carregar_estado: Dictionary = {}   # vindo do save (passo 3)

var _mapa: Node2D
var _cena := Node2D.new()   # tudo que ordena por Y (pessoas e móveis)
var _jogador: Node2D
var _cam := Camera2D.new()
var _cam_alvo: Node2D
var _lateral: Node2D = null   # palco lateral (cutscene vista de lado), quando está aberto
const ZOOM_LATERAL := 1.5     # o palco lateral começa mais perto (câmera de cinema)
const Y_LATERAL := 86.0       # altura (no fundo) que a câmera mira no palco lateral
var _tom := CanvasModulate.new()
var _npcs: Array = []
var _dialogo: CanvasLayer
var _diretor: Node
var _balao := Label.new()
var _balao_rabo := Polygon2D.new()
var _balao_de := ""       # em quem o balão "E Falar" está (pra saber quando ele aparece de novo)
var _balao_t := 0.0
var _reagindo := false   # E acabou de ser apertado: dá tempo de ver a reação antes da cena
var _titulo := Label.new()
var _info := Label.new()
var _preto := Visual.criar_cortina()
var _branco := ColorRect.new()
var _pos: CanvasLayer
var _ambiente := Color.WHITE
var _tom_cor := Color.WHITE
var _parado_t := 0.0   # quanto tempo o jogador está parado (pra fazer uma mania)
var _olhar := Vector2.ZERO   # câmera olha um pouco pra frente de quem anda
var _barra_cima := ColorRect.new()
var _barra_baixo := ColorRect.new()
var _trocando := false
var _debug := false
var _painel: Node
var _tremor := 0.0
var _tremor_forca := 0.0
var _gatilhos_dentro := {}
var _fila: Array[String] = []
var _t_passo := 0.0
var _pausa: CanvasLayer
var _salvo := Label.new()
var _encerrado := false
var modo_teste := false   # F6 / testar_cena.bat: não grava o save de verdade
var musica_cena := ""   # música trocada por uma cena (vale até a cena acabar)


func _ready() -> void:
	Roteiro.apelidos = {}
	for k in capitulo.get("apelidos", {}):
		Roteiro.apelidos[Roteiro.sem_acento(str(k).to_lower())] = Roteiro.nome(str(capitulo.apelidos[k]))
	_cena.y_sort_enabled = true
	add_child(_cena)
	_figs.mundo = self
	add_child(_figs)
	add_child(_tom)
	_jogador = Personagem.new()
	_jogador.configurar(Rede.personagem_de(Rede.eu()) if Rede.online() else capitulo.get("jogador", "breno"))
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 8.0
	add_child(_cam)
	_cam_alvo = _jogador

	_balao.add_theme_color_override("font_color", Color("1a2050"))
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("ffd34e")
	fundo.set_content_margin_all(2)
	_balao.add_theme_stylebox_override("normal", fundo)
	_balao.visible = false
	_balao.z_index = 50
	_balao_rabo.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(0, 3)])
	_balao_rabo.color = Color("ffd34e")
	_balao.add_child(_balao_rabo)
	add_child(_balao)

	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	for b in [_barra_cima, _barra_baixo]:
		b.color = Color.BLACK
		b.size = Vector2(480, 0)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(b)
	var faixa := StyleBoxFlat.new()
	faixa.bg_color = Color(0.067, 0.082, 0.173, 0.85)
	faixa.set_content_margin_all(5)
	var faixa_titulo := Visual.painel(Color(0.067, 0.082, 0.2, 0.92), Color("ffd34e"), 6)
	faixa_titulo.content_margin_left = 10
	faixa_titulo.content_margin_right = 10
	_titulo.add_theme_stylebox_override("normal", faixa_titulo)
	_titulo.add_theme_color_override("font_color", Color("ffd34e"))
	_titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_titulo.position = Vector2(8, 8)
	hud.add_child(_titulo)
	_info.add_theme_stylebox_override("normal", faixa)
	_info.add_theme_constant_override("line_spacing", 2)
	_info.position = Vector2(4, 4)
	_info.visible = false
	hud.add_child(_info)
	_salvo.text = "salvo"
	_salvo.add_theme_color_override("font_color", Color("6fd08c"))
	_salvo.add_theme_color_override("font_shadow_color", Color.BLACK)
	_salvo.position = Vector2(428, 256)
	_salvo.modulate.a = 0.0
	hud.add_child(_salvo)
	var hud2 := CanvasLayer.new()
	hud2.layer = 15
	add_child(hud2)
	_branco.color = Color(0, 0, 0, 0)
	_branco.size = Vector2(480, 270)
	_branco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud2.add_child(_branco)
	hud2.add_child(_preto)
	_pos = Visual.criar_pos(4)
	add_child(_pos)

	_online.add_theme_color_override("font_color", Color("6fd08c"))
	_online.add_theme_color_override("font_shadow_color", Color.BLACK)
	_online.position = Vector2(4, 258)
	hud.add_child(_online)
	_aviso_rede.add_theme_stylebox_override("normal", faixa)
	_aviso_rede.add_theme_color_override("font_color", Color("ffd34e"))
	_aviso_rede.position = Vector2(8, 232)
	_aviso_rede.modulate.a = 0.0
	hud.add_child(_aviso_rede)
	if Rede.online():
		Rede.mundo = self
		Rede.caiu.connect(_sala_caiu)

	_dialogo = Dialogo.new()
	add_child(_dialogo)
	_diretor = Diretor.new()
	_diretor.mundo = self
	add_child(_diretor)

	_avisar_erros.call_deferred()
	_pre_carregar.call_deferred()
	if not carregar_estado.is_empty():
		_restaurar(carregar_estado)
		return
	var inicio: Dictionary = capitulo.get("inicio", {})
	_entrar(capitulo.get("mapa_inicial", "recepcao"), inicio)
	_mostrar_titulo(capitulo.get("titulo", ""))
	var abertura: String = capitulo.get("abertura", "")
	if abertura != "":
		tocar_cena(abertura)
	else:
		_checar_ao_entrar()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	if Rede.mundo == self:
		Rede.mundo = null
		Rede.sair()   # voltar pro menu = sair da sala (o anfitrião fecha ela)


func _mostrar_titulo(texto: String) -> void:
	_titulo.text = texto
	_titulo.visible = texto != ""
	_titulo.modulate.a = 0.0
	_titulo.position = Vector2(-20, 10)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_titulo, "modulate:a", 1.0, 0.35)
	tw.tween_property(_titulo, "position:x", 10.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.6)
	tw.chain().tween_property(_titulo, "modulate:a", 0.0, 0.8)


# ======================================================== montar o mapa

## Monta o mapa "id" e coloca o jogador em "chegada" ({x, y, dir}).
func _entrar(id: String, chegada: Dictionary) -> void:
	var d = Dados.mapa(id)
	if d == null:
		push_error("Mapa não encontrado: " + id)
		d = {}
	if _mapa:
		_mapa.queue_free()
	if _jogador.get_parent():
		_cena.remove_child(_jogador)
	for c in _cena.get_children():
		c.queue_free()
	_npcs.clear()
	_gatilhos_dentro.clear()

	_mapa = Mapa.new()
	_mapa.carregar(id, d)
	_mapa.mostrar_debug(_debug)
	add_child(_mapa)
	move_child(_mapa, 0)
	for o in d.get("objetos", []):
		var mv := Movel.new()
		mv.position = Vector2(o.get("x", 0), o.get("y", 0))
		if o.has("imagem"):
			var tex := Dados.imagem_mapa(o.imagem)
			if tex == null:
				continue
			mv.usar_imagem(tex)
			if o.has("desce"):
				mv.get_child(0).offset.y += float(o.desce)
			var b: Array = o.get("solido", [0, 0])
			mv.tam_solido = Vector2(b[0], b[1])
		else:
			mv.tipo = o.get("tipo", "carteira")
		mv.balanco = float(o.get("balanco", 0.0))
		_cena.add_child(mv)
		if mv.solido().has_area():
			_mapa.solidos.append(mv.solido())
	for a in d.get("animados", []):
		var an := Animado.new()
		an.configurar(a)
		_cena.add_child(an)

	for n in _defs_npcs():
		if n.get("mapa", "") == id and n.get("visivel", true) and condicao_ok(n.get("requer", [])):
			_criar_npc(n)

	_figs.montar(id, d, _cena)
	_jogador.position = Vector2(chegada.get("x", 320), chegada.get("y", 150))
	_jogador.dir = chegada.get("dir", "baixo")
	_cena.add_child(_jogador)
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = int(max(_mapa.tam.x, 480))
	_cam.limit_bottom = int(max(_mapa.tam.y, 270))
	_cam_alvo = _jogador
	_olhar = Vector2.ZERO
	_cam.position = _jogador.position + Vector2(0, -20)
	var visual: Dictionary = d.get("visual", {})
	Visual.ajustar_pos(_pos, visual, 0.01)
	_ambiente = Color(visual.get("ambiente", "#ffffff"))
	_tom.color = _ambiente * _tom_cor
	_cam.reset_smoothing.call_deferred()
	if musica_cena == "":
		tocar_musica_do_mapa()


func tocar_musica_do_mapa() -> void:
	# o capítulo pode dar música própria pra cada lugar: "musicas": {"nucleo": "nucleo"}
	var musica: String = capitulo.get("musicas", {}).get(_mapa.id, _mapa.dados.get("musica", capitulo.get("musica", "")))
	if musica != "":
		Jogo.tocar_musica(musica)


## Passo "musica": "nome" troca até o fim da cena; "mapa" volta pra música do lugar; "" = silêncio.
func trocar_musica(nome: String) -> void:
	if nome == "mapa":
		musica_cena = ""
		tocar_musica_do_mapa()
	else:
		musica_cena = nome if nome != "" else "-"
		Jogo.tocar_musica(nome)


## NPCs do capítulo com as mudanças feitas pelas cenas por cima.
func _defs_npcs() -> Array:
	var lista := []
	var vistos := {}
	for n in capitulo.get("npcs", []):
		var id: String = Roteiro.nome(n.get("personagem", ""))
		var d: Dictionary = n.duplicate()
		d.personagem = id
		if n.has("rotina"):
			d.merge(_parada(n), true)
		d.merge(npc_estado.get(id, {}), true)
		lista.append(d)
		vistos[id] = true
	for id in npc_estado:
		if not vistos.has(id):
			var d: Dictionary = npc_estado[id].duplicate()
			d["personagem"] = id
			lista.append(d)
	return lista


func _criar_npc(n: Dictionary) -> Node2D:
	var npc := Personagem.new()
	npc.position = Vector2(n.get("x", 0), n.get("y", 0))
	npc.configurar(n.get("personagem", "nicao"), n.get("dir", "baixo"))
	npc.set_meta("dados", n)
	npc.set_meta("casa", npc.position)
	npc.set_meta("dir_casa", npc.dir)
	npc.set_meta("espera", randf_range(1.0, 3.0))
	_cena.add_child(npc)
	_npcs.append(npc)
	if n.get("comportamento", "") == "pc":
		_no_pc(npc, 0.0)
	return npc


# ======================================================== jogar

func _process(_delta: float) -> void:
	if Rede.online():
		_atualizar_remotos(_delta)
	if _pos:
		_pos.get_node("Pos").visible = Visual.ligado()
	# segurar X/Ctrl durante uma cena deixa tudo 3x mais rápido
	var acelera := em_cena and Input.is_action_pressed("acelerar") and get_tree().get_nodes_in_group("minijogo").is_empty()
	Engine.time_scale = 3.0 if acelera else 1.0
	if _cam_alvo and is_instance_valid(_cam_alvo):
		var frente := Vector2.ZERO
		if _cam_alvo == _jogador and _jogador.andando:
			frente = {"baixo": Vector2(0, 14), "cima": Vector2(0, -14), "esquerda": Vector2(-22, 0), "direita": Vector2(22, 0)}[_jogador.dir]
		_olhar = _olhar.lerp(frente, min(1.0, _delta * 2.0))
		_cam.position = mira(_cam_alvo) + _olhar
	if _debug:
		_info.text = _texto_debug()


func _physics_process(delta: float) -> void:
	if _tremor > 0.0:
		_tremor -= delta
		_cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _tremor_forca if _tremor > 0.0 else Vector2.ZERO
	if em_cena or _dialogo.ativo or _trocando or _painel or _pausa or _reagindo:
		_balao.visible = false
		if not em_cena:
			_jogador.andando = false
		return
	for n in _npcs:
		_vida_npc(n, delta)
	_figs.atualizar(delta)
	_relogio += delta
	_checar_rotinas()
	var v := Input.get_vector("esquerda", "direita", "cima", "baixo")
	_jogador.andando = v != Vector2.ZERO
	if _jogador.andando and (_jogador._animando > 0 or _jogador.pose != ""):
		_jogador.soltar_pose()
		_jogador.andando = true
	if _jogador.andando or _balao.visible:
		_parado_t = 0.0
	elif _jogador._animando == 0:
		_parado_t += delta
		if _parado_t > 9.0:
			_parado_t = -randf_range(4.0, 10.0)
			_jogador.mania(self)
	if _jogador.andando:
		var passo := v * VELOCIDADE * delta
		if not _bloqueado(_jogador.position + Vector2(passo.x, 0)):
			_jogador.position.x += passo.x
		if not _bloqueado(_jogador.position + Vector2(0, passo.y)):
			_jogador.position.y += passo.y
		if abs(v.x) > abs(v.y):
			_jogador.dir = "direita" if v.x > 0 else "esquerda"
		else:
			_jogador.dir = "baixo" if v.y > 0 else "cima"
		_t_passo -= delta
		if _t_passo <= 0.0:
			_t_passo = 0.27
			Jogo.som("passo", -14.0, 0.12)
			_poeirinha(_jogador.position)
		var porta: Dictionary = _mapa.porta_em(_jogador.position, v)
		if not porta.is_empty():
			_atravessar(porta)
			return
	if _checar_gatilhos():
		return
	var alvo = _alvo()
	_balao.visible = alvo != null
	if alvo != null:
		var dados: Dictionary = alvo.get_meta("dados") if alvo is Node2D else alvo.dados
		_balao.text = Controles.tecla("interagir") + " " + str(dados.get("dica", "Falar" if alvo is Node2D else "Ver"))
		_balao.reset_size()
		if alvo is Node2D:
			_balao.position = alvo.position + Vector2(-_balao.size.x / 2, -76)
		else:
			_balao.position = alvo.rect.get_center() + Vector2(-_balao.size.x / 2, -16)
		_animar_balao(alvo, delta)
	else:
		_balao_de = ""


## O balão "E Falar" nasce com um pulinho e fica flutuando de leve.
func _animar_balao(alvo, delta: float) -> void:
	_balao.pivot_offset = Vector2(_balao.size.x / 2, _balao.size.y + 3)
	_balao_rabo.position = Vector2(_balao.size.x / 2, _balao.size.y)
	var chave := str(alvo.get_instance_id()) if alvo is Node2D else str(alvo.rect)
	if chave != _balao_de:
		_balao_de = chave
		_balao_t = 0.0
		if Visual.ligado():
			_balao.scale = Vector2(0.2, 0.2)
			var tw := _balao.create_tween()
			tw.tween_property(_balao, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_balao_t += delta
	if Visual.ligado():
		_balao.position.y += round(sin(_balao_t * 4.0) * 1.5)


## Resposta visual ao apertar E: o móvel treme e solta brilhinho; a pessoa dá um pulinho.
func _reagir(alvo) -> void:
	if not Visual.ligado():
		return
	if alvo is Node2D:
		alvo.olhar_para(_jogador.position)
		_jogador.olhar_para(alvo.position)
		var tw: Tween = alvo.create_tween()
		alvo.scale = Vector2(1.12, 0.88)
		tw.tween_property(alvo, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		return
	var r: Rect2 = alvo.rect
	for c in _cena.get_children():
		if c is Movel and c.area().grow(2).intersects(r):
			c.tremer()
	Animacao.estouro("brilhos", _cena, r.get_center())


## Comportamento parado dos NPCs no mapa: "comportamento": "parado" | "olhar" | "passear" | "pc"
## ("raio" = até onde passeia). Todo mundo vira pro jogador quando ele chega perto.
func _vida_npc(n: Node2D, delta: float) -> void:
	if n.pose != "" or n._animando > 0 or not n.visible:
		return
	var d: Dictionary = n.get_meta("dados")
	if n.get_meta("saindo", false) or n.get_meta("chegando", false):
		return
	if d.get("comportamento", "") == "acao":
		_na_acao(n, d, delta)
		return
	if d.get("comportamento", "") == "pc" and (n._acao == "digitar" or n.get_meta("sentando", false)):
		return
	var perto := n.position.distance_to(_jogador.position) < 52
	if perto:
		if not n.get_meta("olhando", false):
			n.set_meta("olhando", true)
			n.andando = false
			if n._acao != "":
				n._folha_andar()
			n.remove_meta("destino")
			n.olhar_para(_jogador.position)
			n._spr.position = Vector2.ZERO
		return
	var modo: String = d.get("comportamento", "parado")
	if n.get_meta("olhando", false):
		n.set_meta("olhando", false)
		n.set_meta("espera", 1.5)
		if modo == "parado":
			n.dir = n.get_meta("dir_casa")
			n._atualizar()
	if modo == "pc":
		_no_pc(n, delta)
		return
	if _mania(n, delta):
		return
	if modo == "varrer":
		if n._acao != "varrendo":
			n.mostrar_acao("varrendo", -1.0 if n.get_meta("dir_casa") == "esquerda" else 1.0)
		return
	if modo == "parado":
		return
	if n.has_meta("destino"):
		var alvo: Vector2 = n.get_meta("destino")
		var passo: Vector2 = (alvo - n.position).limit_length(28.0 * delta)
		var novo: Vector2 = n.position + passo
		var pe := Rect2(novo.x - 7, novo.y - 5, 14, 5)
		var pe_j := Rect2(_jogador.position.x - 8, _jogador.position.y - 6, 16, 6)
		if passo.length() < 0.01 or _mapa.bloqueia(pe) or pe.intersects(pe_j):
			n.remove_meta("destino")
			n.andando = false
			n.set_meta("espera", randf_range(1.5, 4.0))
			return
		n.position = novo
		n.olhar_para(alvo + (alvo - novo))
		n.andando = true
		return
	var espera: float = n.get_meta("espera", 2.0) - delta
	n.set_meta("espera", espera)
	if espera > 0.0:
		return
	if modo == "olhar":
		n.dir = ["baixo", "esquerda", "direita", "cima", "baixo"].pick_random()
		n._atualizar()
		n.set_meta("espera", randf_range(1.5, 4.0))
	elif modo == "passear":
		var casa: Vector2 = n.get_meta("casa")
		var raio: float = d.get("raio", 40.0)
		n.set_meta("destino", casa + Vector2(randf_range(-raio, raio), randf_range(-raio, raio) * 0.6))


## "comportamento": "pc": sentado de lado no computador, digitando (quadros "digitar" da
## folha acoes2, com a cadeira desenhada junto). Se levantou numa cena ("levantar_cadeira"),
## fica em pé enquanto o jogador está perto e depois senta de novo sozinho.
func _no_pc(n: Node2D, delta: float) -> void:
	if n._acao == "digitar" or n.get_meta("sentando", false):
		return
	if Animacao.linha("digitar").is_empty() or Dados.textura(n.id, "acoes2") == null:
		_no_pc_simples(n, delta)
		return
	var ja_sentou: bool = n.get_meta("sentou", false)
	if ja_sentou and (n.position.distance_to(_jogador.position) < 60 \
			or n.position.distance_to(n.get_meta("casa", n.position)) > 2.0):
		return
	n.set_meta("sentou", true)
	n.set_meta("sentando", true)
	n.dir = "direita"
	if ja_sentou and Visual.ligado():
		for i in [3, 2, 1, 0]:
			n.mostrar_acao("levantar_cadeira:%d" % i, 1.0)
			await get_tree().create_timer(0.11).timeout
			if not is_instance_valid(n) or em_cena:
				break
	if is_instance_valid(n):
		n._spr.position = Vector2.ZERO
		n.mostrar_acao("digitar", 1.0)
		n.remove_meta("sentando")


## "comportamento": "acao" com "acoes": ["tocando_violao", "chupando_cana"]: fica fazendo uma
## delas (linhas de acoes/acoes2/extras) e troca de vez em quando ("troca": segundos).
## Continua na dele quando o jogador chega perto (as cenas falam com ele assim mesmo).
func _na_acao(n: Node2D, d: Dictionary, delta: float) -> void:
	var lista: Array = d.get("acoes", [])
	if lista.is_empty():
		return
	var t: float = n.get_meta("acao_t", 0.0) - delta
	var atual: String = n.get_meta("acao_atual", "")
	if t <= 0.0 or atual == "":
		t = float(d.get("troca", 20.0)) * randf_range(0.7, 1.3)
		atual = lista[0] if atual == "" else lista.pick_random()
		n.set_meta("acao_atual", atual)
	n.set_meta("acao_t", t)
	if n._acao != atual:
		n.mostrar_acao(atual, -1.0 if d.get("dir", "") == "esquerda" else 1.0)


## Sem os quadros de sentado: fica de costas pro computador, digitando em rajadas.
func _no_pc_simples(n: Node2D, delta: float) -> void:
	if n.dir != "cima":
		n.dir = "cima"
		n._atualizar()
	var t: float = n.get_meta("pc_t", randf() * 5.0) + delta
	n.set_meta("pc_t", t)
	var digitando := fmod(t, 5.0) < 3.2 and Visual.ligado()
	n._spr.position.y = -1.0 if digitando and int(t * 9.0) % 2 == 0 else 0.0
	n._spr.position.x = 1.0 if digitando and int(t * 3.0) % 3 == 0 else 0.0


## De vez em quando quem está parado faz uma das suas manias (animacoes.json, "manias").
## "manias": false no NPC desliga.
func _mania(n: Node2D, delta: float) -> bool:
	if n.andando or not Visual.ligado() or not n.get_meta("dados", {}).get("manias", true):
		return false
	var inter: Array = Animacao.defs().get("manias", {}).get("intervalo", [7, 16])
	var t: float = n.get_meta("mania_t", randf_range(float(inter[0]) * 0.3, float(inter[1]))) - delta
	n.set_meta("mania_t", t)
	if t > 0.0:
		return false
	n.set_meta("mania_t", randf_range(float(inter[0]), float(inter[1])))
	n.mania(self)
	return true


## Fumacinha de poeira no pé a cada passo.
func _poeirinha(p: Vector2) -> void:
	if not Visual.ligado():
		return
	var c := CPUParticles2D.new()
	c.position = p + Vector2(0, -1)
	c.one_shot = true
	c.amount = 3
	c.lifetime = 0.4
	c.explosiveness = 1.0
	c.direction = Vector2(0, -1)
	c.spread = 70
	c.initial_velocity_min = 6
	c.initial_velocity_max = 14
	c.gravity = Vector2(0, 20)
	c.color = Color(1, 1, 1, 0.35)
	c.z_index = -1
	_cena.add_child(c)
	c.emitting = true
	get_tree().create_timer(0.6).timeout.connect(c.queue_free)


func _atravessar(porta: Dictionary) -> void:
	_trocando = true
	_jogador.andando = false
	var de: String = _mapa.id
	if porta.has("folha"):
		# põe a mão na maçaneta, a porta abre, ele entra e a tela fecha
		_jogador.dir = "cima"
		_jogador.anim("abrir_porta_cima", self)
		await get_tree().create_timer(0.25).timeout
		await _mapa.mexer_porta(porta, true)
		var tw := create_tween()
		tw.tween_property(_jogador, "position:y", _jogador.position.y - 10, 0.3)
		tw.parallel().tween_property(_jogador, "modulate", Color(0.4, 0.4, 0.5), 0.3)
	else:
		Jogo.som("porta")
	await Visual.cortina(_preto, 1.0, 0.35).finished
	_jogador.modulate = Color.WHITE
	_jogador.soltar_pose()
	_jogador.andando = false
	_entrar(porta.para, porta.chegada)
	# do outro lado, a porta por onde ele veio está aberta e fecha atrás dele
	var volta: Dictionary = _mapa.porta_para(de)
	if volta.has("folha"):
		volta.folha.abertura = 1.0
	var nome: String = _mapa.dados.get("nome", "")
	if nome != "":
		_mostrar_titulo(nome)
	await get_tree().create_timer(0.05).timeout
	await Visual.cortina(_preto, 0.0, 0.35).finished
	if volta.has("folha"):
		_mapa.mexer_porta(volta, false)
	_trocando = false
	_checar_ao_entrar()
	if not em_cena:
		salvar()


func _unhandled_input(event: InputEvent) -> void:
	if em_cena or _dialogo.ativo or _trocando or _painel or _pausa or _reagindo:
		return
	if event.is_action_pressed("voltar"):
		_abrir_pausa()
	elif event.is_action_pressed("depurar"):
		_debug = not _debug
		_info.visible = _debug
		_mapa.mostrar_debug(_debug)
	elif event.is_action_pressed("recarregar"):
		recarregar_historia()
	elif event.is_action_pressed("modo_teste"):
		abrir_teste()
	elif event.is_action_pressed("diario"):
		_abrir_painel("Diário", _texto_diario(), "diario")
	elif event.is_action_pressed("historico"):
		_abrir_painel("Histórico de falas", _texto_historico(), "historico", true)
	elif event.is_action_pressed("interagir"):
		var alvo = _alvo()
		if alvo != null and Visual.ligado():
			_reagir(alvo)
			_reagindo = true
			_jogador.andando = false
			_balao.visible = false
			await get_tree().create_timer(0.2).timeout
			_reagindo = false
		if alvo is Node2D and alvo.has_meta("figurante"):
			_jogador.olhar_para(alvo.position)
			_figs.falar(alvo)
		elif alvo is Node2D:
			alvo.olhar_para(_jogador.position)
			_jogador.olhar_para(alvo.position)
			tocar_cena(_escolher_cena(alvo.get_meta("dados")), alvo.id)
		elif alvo is Dictionary:
			tocar_cena(_escolher_cena(alvo.dados), "")


# ======================================================== pausa e salvar

func _abrir_pausa() -> void:
	_jogador.andando = false
	get_tree().paused = true
	_pausa = Pausa.new()
	_pausa.escolheu.connect(_pausa_escolha)
	add_child(_pausa)


func _fechar_pausa() -> void:
	if _pausa:
		_pausa.queue_free()
		_pausa = null
	get_tree().paused = false


func _pausa_escolha(acao: String) -> void:
	match acao:
		"continuar":
			Jogo.som("fechar")
			_fechar_pausa()
		"salvar":
			salvar()
			_pausa.mostrar_aviso("Salvo no Jogo %d!" % Jogo.slot if not modo_teste else "Modo teste: não salva")
		"diario", "historico":
			_pausa.ocupar(true)
			if acao == "diario":
				_abrir_painel("Diário", _texto_diario(), "diario")
			else:
				_abrir_painel("Histórico de falas", _texto_historico(), "historico", true)
			_painel.fechou.connect(_desocupar_pausa)
		"opcoes":
			_pausa.ocupar(true)
			var o := Opcoes.new()
			o.fechou.connect(_desocupar_pausa)
			add_child(o)
		"menu":
			salvar()
			_fechar_pausa()
			sair.emit()
		"sair":
			salvar()
			get_tree().quit()


func _desocupar_pausa() -> void:
	if _pausa:
		_pausa.ocupar(false)


## Grava o jogo (só fora de cena). Chamado sozinho ao trocar de mapa e ao fim de cada cena.
func salvar() -> void:
	if em_cena or _encerrado or modo_teste or Rede.cliente() or capitulo.get("_arquivo", "") == "":
		return
	Jogo.salvar_jogo(estado())
	_salvo.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(_salvo, "modulate:a", 0.0, 0.4)


## Passo "fim_capitulo": tela de fim, libera o próximo capítulo e volta pro menu.
func terminar_capitulo() -> void:
	var proximo: String = capitulo.get("proximo", Dados.proximo_capitulo(capitulo.get("_arquivo", "")))
	_encerrado = true
	Jogo.completar_capitulo(capitulo.get("_arquivo", ""), proximo)
	Jogo.apagar_capitulo(capitulo.get("_arquivo", ""))
	await fade("preto", 0.8)
	var tela := CanvasLayer.new()
	tela.layer = 50
	add_child(tela)
	var fundo := ColorRect.new()
	fundo.color = Color("11152c")
	fundo.size = Vector2(480, 270)
	tela.add_child(fundo)
	var vistas_n := 0
	for id in capitulo.get("cenas", {}):
		if flags.has("viu_" + id):
			vistas_n += 1
	var ganhos := 0
	for f in flags:
		if str(f).begins_with("ganhou_"):
			ganhos += 1
	var nome_prox := ""
	if proximo != "":
		var c = Dados.ler_json(proximo)
		if c is Dictionary:
			nome_prox = c.get("titulo", "")
	var linhas := [
		["Fim do capítulo", Color("ffd34e"), 16, 50],
		[capitulo.get("titulo", ""), Color("f3efe2"), 8, 80],
		["Cenas vistas: %d" % vistas_n, Color("a9b0d6"), 8, 120],
		["Minijogos vencidos: %d" % ganhos, Color("a9b0d6"), 8, 138],
		[("Liberado: " + nome_prox) if nome_prox != "" else "", Color("6fd08c"), 8, 170],
		[Controles.tecla("interagir") + ": voltar ao menu", Color("6b7299"), 8, 236],
	]
	for l in linhas:
		var lb := Label.new()
		lb.text = l[0]
		lb.add_theme_color_override("font_color", l[1])
		lb.add_theme_font_size_override("font_size", l[2])
		lb.size = Vector2(480, 20)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.position = Vector2(0, l[3])
		lb.modulate.a = 0.0
		tela.add_child(lb)
		create_tween().tween_property(lb, "modulate:a", 1.0, 0.6).set_delay(0.3 + l[3] / 300.0)
	Jogo.tocar_musica("fim", 0.5)
	Jogo.som("vitoria")
	await get_tree().create_timer(1.2).timeout
	while not Input.is_action_just_pressed("interagir"):
		await get_tree().process_frame
	Jogo.som("confirmar")
	capitulo_completo.emit(proximo)
	sair.emit()


func _abrir_painel(titulo: String, texto: String, tecla: String, no_fim := false) -> void:
	_jogador.andando = false
	var p := Painel.new()
	p.titulo = titulo
	p.texto = texto
	p.tecla = tecla
	p.no_fim = no_fim
	_painel = p
	p.fechou.connect(func(): _painel = null)
	add_child(p)


## O que dá pra usar com E: um NPC perto, ou um ponto do mapa logo à frente.
## Só conta se tiver alguma cena disponível agora.
func _alvo():
	var melhor = null
	var menor := ALCANCE
	for n in _npcs:
		var d := Vector2(n.position.x - _jogador.position.x, (n.position.y - _jogador.position.y) * 1.3).length()
		if d < menor and _escolher_cena(n.get_meta("dados")) != "":
			menor = d
			melhor = n
	if melhor:
		return melhor
	var fig := _figs.alvo(_jogador.position, ALCANCE * 0.8)
	if fig:
		return fig
	var frente := {"baixo": Vector2(0, 10), "cima": Vector2(0, -12), "esquerda": Vector2(-12, -2), "direita": Vector2(12, -2)}
	var p: Vector2 = _jogador.position + frente[_jogador.dir]
	var ponto: Dictionary = _mapa.ponto_em(Rect2(p.x - 6, p.y - 6, 12, 12))
	if ponto.is_empty() or _escolher_cena(ponto.dados) == "":
		return null
	return ponto


func _bloqueado(p: Vector2) -> bool:
	var pe := Rect2(p.x - 7, p.y - 5, 14, 5)
	if _mapa.bloqueia(pe):
		return true
	for n in _npcs:
		if pe.intersects(Rect2(n.position.x - 8, n.position.y - 6, 16, 6)):
			return true
	return false


# ======================================================== textos do diário, histórico e depuração

func _texto_diario() -> String:
	var s := "[color=#a9b0d6]%s[/color]\n" % capitulo.get("titulo", "")
	s += "Lugar: [color=#ffd34e]%s[/color]\n\n" % _mapa.dados.get("nome", _mapa.id)
	var algum := false
	for o in capitulo.get("diario", []):
		if o is String:
			o = {"texto": o}
		if not condicao_ok(o.get("requer", [])):
			continue
		algum = true
		var feito: bool = o.has("feito") and condicao_ok(o.feito)
		if feito:
			s += "[color=#6fd08c]V[/color] [color=#8a90b8]%s[/color]\n" % o.texto
		else:
			s += "[color=#ffd34e]>[/color] %s\n" % o.texto
	if not algum:
		s += "[color=#8a90b8](Nada anotado ainda. Explore e converse com o pessoal.)[/color]\n"
	var vistas_n := 0
	for id in capitulo.get("cenas", {}):
		if flags.has("viu_" + id):
			vistas_n += 1
	s += "\n[color=#a9b0d6]Cenas vistas: %d[/color]" % vistas_n
	return s


func _texto_historico() -> String:
	if Jogo.historico.is_empty():
		return "[color=#8a90b8](Ninguém falou nada ainda.)[/color]"
	var s := ""
	for h in Jogo.historico:
		if h.quem == "*":
			s += "[color=#a9b0d6]%s[/color]\n" % h.texto
		else:
			s += "[color=#ffd34e]%s:[/color] %s\n" % [Dados.nome(h.quem), h.texto]
	return s


func _texto_debug() -> String:
	var s := "%s  x:%d y:%d  tom:%s\n" % [_mapa.id, _jogador.position.x, _jogador.position.y, tom_atual]
	s += "cena: %s  fila: %s\n" % [cena_atual if cena_atual != "" else "-", ", ".join(_fila) if not _fila.is_empty() else "-"]
	var fs := flags.keys()
	fs.sort()
	s += "marcas (%d):\n" % fs.size()
	var linha := ""
	for f in fs:
		if linha.length() + f.length() > 54:
			s += " " + linha + "\n"
			linha = ""
		linha += f + " "
	if linha != "":
		s += " " + linha + "\n"
	if not npc_estado.is_empty():
		s += "npcs mudados:\n"
		for id in npc_estado:
			var e: Dictionary = npc_estado[id]
			s += " %s: %s %d,%d%s\n" % [id, e.get("mapa", "?"), e.get("x", 0), e.get("y", 0), "" if e.get("visivel", true) else " (sumido)"]
	return s


# ======================================================== gatilhos

## Áreas do capítulo que disparam cena ao pisar: {"mapa", "x", "y", "w", "h", "cena"}.
func _checar_gatilhos() -> bool:
	for g in capitulo.get("gatilhos", []):
		if g.get("mapa", "") != _mapa.id or g.get("ao_entrar", false):
			continue
		var r := Rect2(g.get("x", 0), g.get("y", 0), g.get("w", 0), g.get("h", 0))
		var chave := str(g)
		var dentro := r.has_point(_jogador.position)
		if dentro and not _gatilhos_dentro.has(chave):
			_gatilhos_dentro[chave] = true
			var c := _escolher_cena(g)
			if c != "":
				_jogador.andando = false
				tocar_cena(c)
				return true
		elif not dentro:
			_gatilhos_dentro.erase(chave)
	return false


## Gatilhos com "ao_entrar": true rodam quando o jogador chega no mapa
## (se já tiver uma cena rodando, entram na fila).
func _checar_ao_entrar() -> void:
	for g in capitulo.get("gatilhos", []):
		if g.get("mapa", "") == _mapa.id and g.get("ao_entrar", false):
			var c := _escolher_cena(g)
			if c != "":
				tocar_cena(c)
				return


# ======================================================== cenas

## Definição de uma cena: lista de passos, ou {"passos": [...], "requer", "uma_vez", "vezes", "depois", "cinema"}.
func def_cena(id: String) -> Dictionary:
	var c = capitulo.get("cenas", {}).get(id, null)
	if c == null:
		return {"passos": [{"narrar": "(Ainda não tem história aqui: cena \"%s\".)" % id}]}
	var d: Dictionary
	if c is Array:
		d = {"passos": c}
	elif c is String:
		d = {"passos": [c]}
	else:
		d = c.duplicate()
	d["passos"] = Roteiro.preparar(d.get("passos", []))
	return d


func cena_disponivel(id: String) -> bool:
	if id == "":
		return false
	var d := def_cena(id)
	var vezes: int = d.get("vezes", 1 if d.get("uma_vez", false) else 0)
	if vezes > 0 and vistas.get(id, 0) >= vezes:
		return false
	return condicao_ok(d.get("requer", []))


## NPC/ponto/gatilho pode ter "cena": "id" ou "cenas": ["a", "b"] (vale a primeira disponível;
## com "aleatorio": true sorteia entre as disponíveis). Uma cena com "depois": "outra"
## é trocada pela outra depois de vista uma vez.
func _escolher_cena(dados: Dictionary) -> String:
	var lista: Array = dados.get("cenas", [])
	if dados.get("cena", "") != "":
		lista = [dados.cena] + lista
	var ok := []
	for c in lista:
		var id := str(c)
		var guarda := 0
		while vistas.has(id) and def_cena(id).has("depois") and guarda < 10:
			id = str(def_cena(id).depois)
			guarda += 1
		if cena_disponivel(id):
			ok.append(id)
			if not dados.get("aleatorio", false):
				break
	if ok.is_empty():
		return ""
	return ok.pick_random()


func tocar_cena(id: String, npc := "", de_rede := false) -> void:
	if id == "":
		return
	if Rede.cliente() and not de_rede:
		avisar_rede("Quem puxa as conversas é o anfitrião (%s)." % Dados.nome(Rede.personagem_anfitriao()))
		return
	if Rede.anfitriao():
		Rede.cena(id, npc, {"mapa": _mapa.id, "x": _jogador.position.x, "y": _jogador.position.y, "dir": _jogador.dir})
	if em_cena:
		enfileirar(id)
		return
	em_cena = true
	if Rede.online():   # nas cenas, todo mundo vê o protagonista no lugar do seu personagem
		_jogador.trocar(capitulo.get("jogador", "breno"))
	_jogador.andando = false
	_figs.parar()
	for n in _npcs:
		n.andando = false
		n.remove_meta("destino")
	while id != "":
		cena_atual = id
		if Rede.cliente():
			Rede.comecando(id)
		if def_cena(id).get("cinema", false):
			barras(true)
		await _diretor.rodar_cena(id, npc)
		npc = ""
		id = ""
		while not _fila.is_empty() and id == "":
			var prox: String = _fila.pop_front()
			if cena_disponivel(prox):
				id = prox
	cena_atual = ""
	if musica_cena != "":
		musica_cena = ""
		tocar_musica_do_mapa()
	await _fim_de_cena()
	if _jogador.pose != "":
		await _jogador.anim("levantar", self)
	em_cena = false
	Engine.time_scale = 1.0
	if Rede.online():
		_jogador.trocar(Rede.personagem_de(Rede.eu()))
		Rede.sincronizar(estado_historia())
		Rede.aplicar_pendente()
	if is_inside_tree() and not _trocando:
		salvar()


## Chamado pelo diretor quando uma cena termina (conta pra "uma_vez"/"vezes" e marca "viu_<id>").
func contar_vista(id: String) -> void:
	vistas[id] = vistas.get(id, 0) + 1
	marcar("viu_" + id)


func enfileirar(id: String) -> void:
	if id != "" and not id in _fila and id != cena_atual:
		_fila.append(id)


## Depois de uma cena: câmera volta pro jogador, zoom normal, barras somem.
func _fim_de_cena() -> void:
	if _lateral:
		await lateral("fim")   # cena que esqueceu o "!lateral fim" volta pro mapa sozinha
	if not _trocando and (Visual.progresso(_preto) > 0.0 or _branco.color.a > 0.0):
		fade("volta", 0.3)   # cena que terminou com a tela preta/branca não deixa o jogo escuro
	var precisa := _cam_alvo != _jogador or _cam.zoom != Vector2.ONE or _barra_cima.size.y > 0
	if not precisa:
		return
	barras(false)
	camera_seguir(_jogador, 0.4)
	await zoom(1.0, 0.4)


# ======================================================== usados pelo diretor

func jogador_id() -> String:
	return _jogador.id


func dialogo() -> CanvasLayer:
	return _dialogo


func personagem(id: String) -> Node2D:
	id = Roteiro.nome(id)
	if _lateral:
		return _lateral.ator(_jogador.id if id == "jogador" else id)
	if id == "jogador" or id == _jogador.id:
		return _jogador
	for n in _npcs:
		if is_instance_valid(n) and n.id == id:
			return n
	return null


## "requer": "marca" ou ["a", "!b"]  (! = NÃO pode ter a marca)
func condicao_ok(req) -> bool:
	if req is String:
		req = [req] if req != "" else []
	for r in req:
		var s := str(r)
		if s.begins_with("!"):
			if flags.has(s.substr(1)):
				return false
		elif not flags.has(s):
			return false
	return true


func marcar(nomes) -> void:
	for n in (nomes if nomes is Array else [nomes]):
		if str(n) != "":
			flags[str(n)] = true


func desmarcar(nomes) -> void:
	for n in (nomes if nomes is Array else [nomes]):
		flags.erase(str(n))


func guardar_posicao(pers: Node2D) -> void:
	if pers == _jogador or not is_instance_valid(pers) or pers.get_parent() != _cena:
		return
	var e: Dictionary = npc_estado.get(pers.id, {})
	e.merge({"mapa": _mapa.id, "x": pers.position.x, "y": pers.position.y, "dir": pers.dir}, true)
	npc_estado[pers.id] = e
	var dados: Dictionary = pers.get_meta("dados", {})
	dados.merge(e, true)
	pers.set_meta("casa", pers.position)
	pers.set_meta("dir_casa", pers.dir)


func aparecer(id: String, p: Dictionary, suave := true) -> Node2D:
	id = Roteiro.nome(id)
	if _lateral:
		var n: Node2D = _lateral.por(_jogador.id if id == "jogador" else id, float(p.get("x", 100)), float(p.get("y", 0)), str(p.get("dir", "")))
		if suave:
			n.modulate.a = 0.0
			create_tween().tween_property(n, "modulate:a", 1.0, 0.3)
		return n
	var e: Dictionary = npc_estado.get(id, {})
	e["visivel"] = true
	e["mapa"] = p.get("no_mapa", _mapa.id)
	for k in ["x", "y", "dir", "cena", "cenas", "comportamento", "raio", "dica"]:
		if p.has(k):
			e[k] = p[k]
	if p.has("cenas") and not p.has("cena"):
		e["cena"] = ""   # as cenas novas substituem a antiga
	npc_estado[id] = e
	var atual := personagem(id)
	if atual and atual != _jogador:
		_npcs.erase(atual)
		atual.queue_free()
	if e.mapa == _mapa.id:
		for n in _defs_npcs():
			if n.get("personagem", "") == id:
				var novo := _criar_npc(n)
				if suave:
					novo.modulate.a = 0.0
					create_tween().tween_property(novo, "modulate:a", 1.0, 0.3)
				return novo
	return null


# ======================================================== rotas (cenas desviam das coisas)

const CELULA := 8
var _grade: AStarGrid2D
var _grade_mapa := ""


func _pe_livre(c: Vector2) -> bool:
	return not _mapa.bloqueia(Rect2(c.x - 6, c.y - 4, 12, 4))


func _montar_grade() -> void:
	_grade = AStarGrid2D.new()
	var r: Rect2 = _mapa.limites
	_grade.region = Rect2i(0, 0, int(ceil(r.end.x / CELULA)) + 1, int(ceil(r.end.y / CELULA)) + 1)
	_grade.cell_size = Vector2(CELULA, CELULA)
	_grade.offset = Vector2(CELULA / 2.0, CELULA / 2.0)
	_grade.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grade.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grade.update()
	for y in _grade.region.size.y:
		for x in _grade.region.size.x:
			var c := Vector2(x * CELULA + CELULA / 2.0, y * CELULA + CELULA / 2.0)
			_grade.set_point_solid(Vector2i(x, y), not _pe_livre(c))
	_grade_mapa = _mapa_id_atual()


func _mapa_id_atual() -> String:
	return str(_mapa.get_instance_id())


func _celula_livre_perto(c: Vector2i) -> Vector2i:
	if _grade.is_in_boundsv(c) and not _grade.is_point_solid(c):
		return c
	for raio in range(1, 12):
		var melhor := Vector2i(-1, -1)
		var menor := INF
		for dy in range(-raio, raio + 1):
			for dx in range(-raio, raio + 1):
				var k := c + Vector2i(dx, dy)
				if _grade.is_in_boundsv(k) and not _grade.is_point_solid(k) and Vector2(dx, dy).length() < menor:
					menor = Vector2(dx, dy).length()
					melhor = k
		if melhor.x >= 0:
			return melhor
	return c


func _linha_livre(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 4.0) + 1
	for i in range(1, n + 1):
		if not _pe_livre(a.lerp(b, float(i) / n)):
			return false
	return true


## Caminho de "de" até "ate" contornando mesas, paredes e móveis (A* numa grade de 8 px).
## Se o destino estiver dentro de algo (uma porta, fora do mapa), vai até o ponto livre
## mais perto e termina reto até ele.
func rota(de: Vector2, ate: Vector2) -> Array:
	if _mapa == null:
		return [ate]
	if _grade == null or _grade_mapa != _mapa_id_atual():
		_montar_grade()
	if _linha_livre(de, ate):
		return [ate]
	var ci := _celula_livre_perto(Vector2i(de / CELULA))
	var cf := _celula_livre_perto(Vector2i(ate / CELULA))
	var bruto: PackedVector2Array = _grade.get_point_path(ci, cf)
	if bruto.is_empty():
		return [ate]
	# corta os cantos: de cada ponto, pula direto pro mais longe que dá pra ver
	var pts: Array = []
	var atual: Vector2 = de
	var i := 0
	while i < bruto.size():
		var j := bruto.size() - 1
		while j > i and not _linha_livre(atual, bruto[j]):
			j -= 1
		atual = bruto[j]
		pts.append(atual)
		i = j + 1
	if pts.is_empty() or pts[-1].distance_to(ate) > 0.5:
		pts.append(ate)
	return pts


func sumir(id: String) -> void:
	id = Roteiro.nome(id)
	if _lateral:
		_lateral.tirar(_jogador.id if id == "jogador" else id)
		return
	var e: Dictionary = npc_estado.get(id, {})
	e["visivel"] = false
	npc_estado[id] = e
	var atual := personagem(id)
	if atual and atual != _jogador:
		_npcs.erase(atual)
		var tw := create_tween()
		tw.tween_property(atual, "modulate:a", 0.0, 0.3)
		tw.tween_callback(atual.queue_free)


## Ponto de onde alguém entra / pra onde sai: "porta" (a mais perto), ou uma borda
## da tela ("esquerda", "direita", "cima", "baixo").
func _ponto_de_passagem(de: String, perto: Vector2) -> Vector2:
	var vis := Rect2(_cam.get_screen_center_position() - Vector2(240, 135) / _cam.zoom, Vector2(480, 270) / _cam.zoom)
	match de:
		"esquerda":
			return Vector2(vis.position.x - 16, perto.y)
		"direita":
			return Vector2(vis.end.x + 16, perto.y)
		"cima":
			return Vector2(perto.x, vis.position.y - 4)
		"baixo":
			return Vector2(perto.x, vis.end.y + 60)
	var melhor := Vector2(perto.x, vis.end.y + 60)
	var menor := INF
	for p in _mapa.portas:
		var c: Vector2 = p.rect.get_center()
		if c.distance_to(perto) < menor:
			menor = c.distance_to(perto)
			melhor = c
	return melhor


func entrar(id: String, alvo: Vector2, de: String, vel := 60.0) -> void:
	if _lateral:
		var b: Vector2 = _lateral.borda("direita" if de == "direita" else "esquerda", alvo.y)
		var na := aparecer(id, {"x": b.x, "y": b.y, "dir": "esquerda" if de == "direita" else "direita"}, false)
		if alvo.y <= 0.0:
			alvo.y = b.y
		await na.andar_ate(alvo, vel)
		return
	var ini := _ponto_de_passagem(de, alvo)
	var porta: Dictionary = _mapa.porta_perto(ini, 4.0) if de == "porta" else {}
	if porta.has("folha"):
		await _mapa.mexer_porta(porta, true)
	var n := aparecer(id, {"x": ini.x, "y": ini.y}, false)
	if n == null:
		return
	await n.andar_ate(alvo, vel)
	guardar_posicao(n)
	if porta.has("folha"):
		_mapa.mexer_porta(porta, false)


func sair_de_cena(id: String, por: String, vel := 60.0) -> void:
	var n := personagem(id)
	if n == null or n == _jogador:
		return
	if _lateral:
		var lado := por if por in ["esquerda", "direita"] else ("esquerda" if n.position.x < _lateral.tam.x / 2 else "direita")
		await n.andar_ate(_lateral.borda(lado, n.position.y), vel)
		sumir(n.id)
		return
	var fim := _ponto_de_passagem(por, n.position)
	var porta: Dictionary = _mapa.porta_perto(fim, 4.0) if por == "porta" else {}
	# a câmera acompanha quem está indo embora e depois volta
	var antes: Node2D = _cam_alvo
	await camera_seguir(n, 0.5)
	if porta.has("folha"):
		await n.andar_ate(fim + Vector2(0, 14), vel)
		await _mapa.mexer_porta(porta, true)
	await n.andar_ate(fim, vel)
	await get_tree().create_timer(0.25).timeout
	sumir(id)
	await get_tree().create_timer(0.4).timeout
	if antes and is_instance_valid(antes) and antes != n:
		camera_seguir(antes, 0.6)
	if porta.has("folha"):
		await get_tree().create_timer(0.3).timeout
		_mapa.mexer_porta(porta, false)


## Abre/fecha uma porta pelo nome do lugar pra onde ela leva ("" = a mais perto do jogador).
func porta(acao: String, destino := "") -> void:
	var p: Dictionary = _mapa.porta_para(destino) if destino != "" else _mapa.porta_perto(_jogador.position)
	if p.is_empty():
		return
	await _mapa.mexer_porta(p, acao in ["abrir", "abre", "aberta"])


## Toca uma animação em um ou mais personagens ("lucas,nicao") e espera todos.
func animar(quem: String, nome: String, alvo := "") -> void:
	var a: Node2D = personagem(alvo) if alvo != "" else null
	var lista: Array = []
	for q in quem.split(",", false):
		var p := personagem(q)
		if p:
			lista.append(p)
	if lista.is_empty():
		return
	for i in range(1, lista.size()):
		lista[i].anim(nome, self, a)
	await lista[0].anim(nome, self, a)
	for p in lista:
		while p._animando > 0 and is_instance_valid(p):
			await get_tree().process_frame
		guardar_posicao(p)


## Briga de desenho animado: "a" corre até "b", os dois somem numa nuvem de poeira
## com socos e estrelas, e no fim o perdedor (se tiver) cai no chão.
func briga(a: String, b: String, tempo := 2.0, perdedor := "") -> void:
	var pa := personagem(a)
	var pb := personagem(b)
	if pa == null or pb == null:
		return
	pa.soltar_pose()
	pb.soltar_pose()
	var lado := 1.0 if pb.position.x >= pa.position.x else -1.0
	pa.olhar_para(pb.position)
	pb.olhar_para(pa.position)
	pa.balao("raiva", 0.5)
	await pa.andar_ate(pb.position - Vector2(lado * 16, 0), 150.0)
	var meio: Vector2 = (pa.position + pb.position) / 2.0
	Jogo.som("whoosh")
	Animacao.estouro("poeira", _cena, meio)
	var nuvem := Animacao.Briga.new()
	nuvem.position = meio
	_cena.add_child(nuvem)
	nuvem.scale = Vector2(0.3, 0.3)
	create_tween().tween_property(nuvem, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pa.visible = false
	pb.visible = false
	tremer(tempo, 1.5)
	var t := 0.0
	while t < tempo:
		await get_tree().process_frame
		t += get_process_delta_time()
		if randf() < 0.04:
			Animacao.estouro("poeira", _cena, nuvem.position + Vector2(randf_range(-20, 20), 0))
	Animacao.estouro("poeira", _cena, meio)
	Animacao.estouro("estrelas", _cena, meio + Vector2(0, -30))
	Jogo.som("queda")
	nuvem.queue_free()
	pa.position = meio - Vector2(lado * 18, 0)
	pb.position = meio + Vector2(lado * 18, 0)
	pa.visible = true
	pb.visible = true
	pa.olhar_para(pb.position)
	pb.olhar_para(pa.position)
	var perd := personagem(perdedor) if perdedor != "" else null
	if perd == pa or perd == pb:
		var venc: Node2D = pb if perd == pa else pa
		venc.anim("comemorar", self)
		await perd.anim("nocaute", self, venc)
	else:
		pa.anim("zonzo", self)
		await pb.anim("zonzo", self)
	guardar_posicao(pa)
	guardar_posicao(pb)


func ir_para_mapa(id: String, p: Dictionary) -> void:
	_trocando = true
	if Visual.progresso(_preto) < 1.0:
		await Visual.cortina(_preto, 1.0, 0.35).finished
	_entrar(id, p)
	var nome: String = _mapa.dados.get("nome", "")
	if nome != "":
		_mostrar_titulo(nome)
	await Visual.cortina(_preto, 0.0, 0.35).finished
	_trocando = false


func tremer(tempo: float, forca: float) -> void:
	_tremor = tempo
	_tremor_forca = forca
	Jogo.som("tremor")
	await get_tree().create_timer(tempo).timeout
	_cam.offset = Vector2.ZERO


func flash(tempo: float, cor: Color) -> void:
	_branco.color = Color(cor, 1.0)
	var tw := create_tween()
	tw.tween_property(_branco, "color:a", 0.0, max(tempo, 0.05))
	await tw.finished


## "preto" escurece a tela (e fica escura); "branco" clareia até ficar branca;
## "volta" tira os dois.
func fade(modo: String, tempo: float) -> void:
	if modo in ["branco", "branca", "clarear"]:
		_branco.color = Color(1, 1, 1, _branco.color.a)
		var tw := create_tween()
		tw.tween_property(_branco, "color:a", 1.0, max(tempo, 0.05))
		await tw.finished
		return
	var alvo := 1.0 if modo in ["preto", "sair", "escurecer"] else 0.0
	if alvo == 0.0 and _branco.color.a > 0.0:
		create_tween().tween_property(_branco, "color:a", 0.0, max(tempo, 0.05))
	await Visual.cortina(_preto, alvo, tempo).finished


## !tela normal: câmera volta pro Breno, zoom 1, sem barras, cor normal, sem fade.
func tela_normal() -> void:
	barras(false)
	if _lateral:
		camera_ir(Vector2(_lateral.get_meta("x_cam", 240.0), 0.0), 0.4)
	else:
		camera_seguir(_jogador, 0.4)
	tom("normal", 0.4)
	fade("volta", 0.3)
	await zoom(ZOOM_LATERAL if _lateral else 1.0, 0.4)


## Câmera segue alguém (anda até ele em "tempo" segundos e continua seguindo).
func camera_seguir(alvo: Node2D, tempo: float) -> void:
	if alvo == null:
		return
	_cam_alvo = null
	_cam.position_smoothing_enabled = false
	_cam.position = _cam.get_screen_center_position()
	var tw := create_tween()
	tw.tween_property(_cam, "position", mira(alvo), max(tempo, 0.01)).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_cam_alvo = alvo
	_cam.position_smoothing_enabled = true
	_cam.reset_smoothing()


## Abre o palco lateral (cutscene vista de lado) com o fundo lado_<nome>.png, ou "fim" pra
## voltar ao mapa. x = onde a câmera começa (pixels do fundo; padrão: o meio).
func lateral(nome: String, x := -1.0) -> void:
	if Visual.progresso(_preto) < 1.0:
		await Visual.cortina(_preto, 1.0, 0.3).finished
	if _lateral:
		_lateral.queue_free()
		_lateral = null
	if nome in ["fim", "sair", "nao", "não", ""]:
		_limites_do_mapa()
		_cam.zoom = Vector2.ONE
		_cam_alvo = _jogador
		_cam.position = mira(_jogador)
		_cam.reset_smoothing()
	else:
		var p := preload("res://scripts/palco_lateral.gd").new()
		add_child(p)
		if not p.montar(nome):
			p.queue_free()
			push_warning("Palco lateral sem fundo: lado_%s.png" % nome)
			_limites_do_mapa()
		else:
			_lateral = p
			var r: Rect2 = p.area()
			_cam.limit_left = int(r.position.x)
			_cam.limit_top = int(r.position.y)
			_cam.limit_right = int(r.end.x)
			_cam.limit_bottom = int(r.end.y)
			_cam_alvo = null
			_cam.position_smoothing_enabled = false
			_cam.zoom = Vector2(ZOOM_LATERAL, ZOOM_LATERAL)
			var xc := x if x >= 0.0 else p.tam.x / 2.0
			p.set_meta("x_cam", xc)
			_cam.position = p.no_mundo(Vector2(xc, Y_LATERAL))
	await get_tree().process_frame
	await Visual.cortina(_preto, 0.0, 0.3).finished


func _limites_do_mapa() -> void:
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = int(max(_mapa.tam.x, 480))
	_cam.limit_bottom = int(max(_mapa.tam.y, 270))


## Close do rosto pixelado num quadro que entra no canto da tela (scripts/close_rosto.gd).
func rosto(quem: String, expr: String, tempo: float, lado := "direita") -> void:
	for c in get_children():
		if c.has_method("sair") and c.get("quem") != null and c.get("expr") != null:
			c.sair()
	var r := preload("res://scripts/close_rosto.gd").new()
	r.quem = quem
	r.expr = expr
	r.lado = lado
	add_child(r)
	await get_tree().create_timer(max(tempo, 0.3)).timeout
	if is_instance_valid(r):
		await r.sair()


func no_palco_lateral() -> bool:
	return _lateral != null


## Onde a câmera mira pra seguir alguém (um pouco acima do pé; no palco lateral, em dobro).
func mira(n: Node2D) -> Vector2:
	return n.global_position + Vector2(0, -20) * n.global_scale.y


## Câmera vai até um ponto do mapa e fica parada lá (no palco lateral: ponto do fundo).
func camera_ir(p: Vector2, tempo: float) -> void:
	if _lateral:
		if p.y <= 0.0:
			p.y = Y_LATERAL
		_lateral.set_meta("x_cam", p.x)
		p = _lateral.no_mundo(p)
	_cam_alvo = null
	_cam.position_smoothing_enabled = false
	_cam.position = _cam.get_screen_center_position()
	var tw := create_tween()
	tw.tween_property(_cam, "position", p, max(tempo, 0.01)).set_trans(Tween.TRANS_SINE)
	await tw.finished


func zoom(z: float, tempo: float) -> void:
	z = clampf(z, 0.5, 4.0)
	var tw := create_tween()
	tw.tween_property(_cam, "zoom", Vector2(z, z), max(tempo, 0.01)).set_trans(Tween.TRANS_SINE)
	await tw.finished


## Faixas pretas de cinema em cima e embaixo.
func barras(ligar: bool) -> void:
	var h := 24.0 if ligar else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_barra_cima, "size:y", h, 0.35)
	tw.tween_property(_barra_baixo, "size:y", h, 0.35)
	tw.tween_property(_barra_baixo, "position:y", 270.0 - h, 0.35)


## Cor da tela: "normal", "tarde", "noite", "escuro", "sepia", "lembranca" ou "#rrggbb".
func tom(nome: String, tempo := 1.0) -> void:
	tom_atual = nome
	var hex: String = TONS.get(nome, nome.trim_prefix("#"))
	_tom_cor = Color.from_string(hex, Color.WHITE)
	var tw := create_tween()
	tw.tween_property(_tom, "color", _ambiente * _tom_cor, max(tempo, 0.01))
	await tw.finished


# ======================================================== salvar (passo 3)

func estado() -> Dictionary:
	return {
		"capitulo": capitulo.get("_arquivo", ""),
		"mapa": _mapa.id, "x": _jogador.position.x, "y": _jogador.position.y, "dir": _jogador.dir,
		"flags": flags.keys(), "npc_estado": npc_estado, "vistas": vistas, "tom": tom_atual,
		"titulo": capitulo.get("titulo", ""), "lugar": _mapa.dados.get("nome", _mapa.id),
	}


# ======================================================== jogo online (scripts/rede.gd)

var _online := Label.new()
var _aviso_rede := Label.new()
var _aviso_tw: Tween
var _avatares := {}   # peer -> Personagem (os outros jogadores neste mapa)


## O que os outros recebem de mim, 12 vezes por segundo.
func estado_rede() -> Dictionary:
	return {"mapa": _mapa.id if _mapa else "", "x": _jogador.position.x, "y": _jogador.position.y,
		"dir": _jogador.dir, "andando": _jogador.andando, "cena": em_cena}


## Só a parte da história (marcas, cenas vistas, NPCs mexidos), sem posição.
func estado_historia() -> Dictionary:
	return {"flags": flags.keys(), "vistas": vistas, "npc_estado": npc_estado}


func aplicar_estado_rede(e: Dictionary) -> void:
	flags = {}
	for f in e.get("flags", []):
		flags[str(f)] = true
	vistas = {}
	var vs: Dictionary = e.get("vistas", {})
	for k in vs:
		vistas[k] = int(vs[k])
	npc_estado = e.get("npc_estado", npc_estado)


## Cliente: o anfitrião começou uma cena. Vai pro lugar dele (mesmo mapa) e toca junto.
func cena_da_rede(id: String, npc: String, lugar: Dictionary) -> void:
	if not em_cena and not _trocando and _painel == null and _pausa == null:
		if str(lugar.get("mapa", "")) != _mapa.id:
			await ir_para_mapa(str(lugar.mapa), lugar)
		else:
			_jogador.position = Vector2(float(lugar.get("x", _jogador.position.x)), float(lugar.get("y", _jogador.position.y)))
			_jogador.dir = str(lugar.get("dir", _jogador.dir))
	elif _pausa:
		_fechar_pausa()
	tocar_cena(id, npc, true)


## Mensagem rápida no pé da tela (coisas do jogo online).
func avisar_rede(texto: String, tempo := 2.5) -> void:
	_aviso_rede.text = texto
	_aviso_rede.reset_size()
	_aviso_rede.modulate.a = 1.0
	if _aviso_tw:
		_aviso_tw.kill()
	_aviso_tw = create_tween()
	_aviso_tw.tween_interval(tempo)
	_aviso_tw.tween_property(_aviso_rede, "modulate:a", 0.0, 0.4)


func _sala_caiu(msg: String) -> void:
	avisar_rede(msg, 3.0)
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		_fechar_pausa()
		sair.emit()


## Os outros jogadores: aparecem andando quando estão no mesmo mapa (some tudo durante as cenas).
func _atualizar_remotos(delta: float) -> void:
	var n := Rede.jogadores.size()
	_online.text = ("ONLINE: sala aberta  %d/%d" if Rede.anfitriao() else "ONLINE  %d/%d") % [n, Rede.MAX]
	_online.visible = not em_cena
	var vistos := {}
	for peer in Rede.remotos:
		if peer == Rede.eu() or not Rede.jogadores.has(peer):
			continue
		var d: Dictionary = Rede.remotos[peer]
		var a = _avatares.get(peer)
		if a != null and not is_instance_valid(a):
			a = null   # o mapa trocou e levou o boneco junto
		var aqui: bool = d.get("mapa", "") == _mapa.id and not em_cena and not d.get("cena", false) and not _lateral
		if not aqui:
			if a:
				a.queue_free()
			_avatares.erase(peer)
			continue
		vistos[peer] = true
		var alvo := Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
		var quem := Rede.personagem_de(peer)
		if a == null or a.id != quem:
			if a:
				a.queue_free()
			a = Personagem.new()
			a.configurar(quem, str(d.get("dir", "baixo")))
			a.position = alvo
			a.set_meta("remoto", peer)
			var nome := Label.new()
			nome.text = Dados.nome(quem) if not quem.begins_with(Rede.FIGURANTE) else "Figurante"
			nome.add_theme_color_override("font_color", Color("6fd08c"))
			nome.add_theme_color_override("font_shadow_color", Color.BLACK)
			nome.reset_size()
			nome.position = Vector2(-nome.size.x / 2.0, -78)
			nome.z_index = 40
			a.add_child(nome)
			_cena.add_child(a)
			_avatares[peer] = a
		a.position = alvo if a.position.distance_to(alvo) > 120.0 else a.position.lerp(alvo, minf(1.0, delta * 12.0))
		a.dir = str(d.get("dir", a.dir))
		a.andando = bool(d.get("andando", false))
	for peer in _avatares.keys():
		if not vistos.has(peer):
			if is_instance_valid(_avatares[peer]):
				_avatares[peer].queue_free()
			_avatares.erase(peer)


func _restaurar(e: Dictionary) -> void:
	flags = {}
	for f in e.get("flags", []):
		flags[str(f)] = true
	npc_estado = e.get("npc_estado", {})
	vistas = {}
	var vs: Dictionary = e.get("vistas", {})
	for k in vs:
		vistas[k] = int(vs[k])
	_entrar(e.get("mapa", capitulo.get("mapa_inicial", "recepcao")), {"x": e.get("x", 240), "y": e.get("y", 200), "dir": e.get("dir", "baixo")})
	tom(e.get("tom", "normal"), 0.0)
	_mostrar_titulo(_mapa.dados.get("nome", ""))


# ======================================================== rotina dos NPCs
## No NPC: "rotina": [{"mapa", "x", "y", "dir", "comportamento", "acoes", "tempo"}, ...]
## Ele passa "tempo" segundos em cada parada (contando só o jogo livre, sem cena) e depois
## vai pra próxima: sai andando pela porta mais perto e aparece entrando no outro mapa.

func _parada(n: Dictionary) -> Dictionary:
	var lista: Array = n.get("rotina", [])
	if lista.is_empty():
		return {}
	var total := 0.0
	for p in lista:
		total += float(p.get("tempo", 60))
	var t := fmod(_relogio, max(total, 1.0))
	for i in lista.size():
		t -= float(lista[i].get("tempo", 60))
		if t < 0.0:
			var p: Dictionary = lista[i].duplicate()
			p.erase("tempo")
			p["_parada"] = i
			return p
	return {}


func _checar_rotinas() -> void:
	for n in capitulo.get("npcs", []):
		if not n.has("rotina"):
			continue
		var id: String = Roteiro.nome(n.get("personagem", ""))
		if npc_estado.has(id):
			continue   # uma cena mexeu nele: a cena manda
		var p := _parada(n)
		var i: int = p.get("_parada", 0)
		if not _rotina_atual.has(id):
			_rotina_atual[id] = i
			continue
		if _rotina_atual[id] == i:
			continue
		var antiga: Dictionary = n.rotina[_rotina_atual[id]]
		_rotina_atual[id] = i
		var no := personagem(id)
		if no and antiga.get("mapa", "") == _mapa.id and p.get("mapa", "") != _mapa.id:
			_sair_pela_porta(no)
		elif p.get("mapa", "") == _mapa.id and (no == null or not is_instance_valid(no)):
			_entrar_pela_porta(n, p)
		elif no and p.get("mapa", "") == _mapa.id:
			var d: Dictionary = no.get_meta("dados").duplicate()
			d.merge(p, true)
			no.set_meta("dados", d)
			no.set_meta("casa", Vector2(p.x, p.y))
			no._folha_andar()
			no.set_meta("chegando", true)
			await no.andar_ate(Vector2(p.x, p.y), 40.0)
			if is_instance_valid(no):
				no.remove_meta("chegando")


func _porta_perto(de: Vector2) -> Vector2:
	var melhor := Vector2.INF
	for porta in _mapa.portas:
		var c: Vector2 = porta.rect.get_center()
		var dentro := c.move_toward(_mapa.limites.get_center(), 18.0)
		if melhor == Vector2.INF or dentro.distance_to(de) < melhor.distance_to(de):
			melhor = dentro
	return melhor


func _sair_pela_porta(no: Node2D) -> void:
	var porta := _porta_perto(no.position)
	no.set_meta("saindo", true)
	no._folha_andar()
	if porta != Vector2.INF:
		await no.andar_ate(porta, 55.0)
	if is_instance_valid(no) and no.get_meta("saindo", false):
		_npcs.erase(no)
		no.queue_free()


func _entrar_pela_porta(n: Dictionary, p: Dictionary) -> void:
	var d: Dictionary = n.duplicate()
	d.personagem = Roteiro.nome(n.get("personagem", ""))
	d.merge(p, true)
	var alvo := Vector2(p.get("x", 0), p.get("y", 0))
	var porta := _porta_perto(alvo)
	var no := _criar_npc(d)
	if porta == Vector2.INF:
		return
	no.position = porta
	no.set_meta("casa", alvo)
	no.set_meta("chegando", true)
	no._folha_andar()
	await no.andar_ate(alvo, 55.0)
	if is_instance_valid(no):
		no.remove_meta("chegando")
		no.dir = p.get("dir", "baixo")
		no._atualizar()


# ======================================================== vídeo no meio da cena
## "!video nome": toca um vídeo .ogv (Theora) em tela cheia e a cena continua quando ele
## acaba. E ou Esc pulam. Procura, nesta ordem: o caminho como foi escrito (ao lado do
## JOGO.exe), a pasta "videos" ao lado do JOGO.exe e a pasta videos/ de dentro do jogo.
## Sem ".ogv" no nome, o jogo põe sozinho.

func achar_video(nome: String) -> String:
	var arq := nome if nome.get_extension() != "" else nome + ".ogv"
	var base := OS.get_executable_path().get_base_dir()
	var lista := [arq, base.path_join(arq), base.path_join("videos").path_join(arq.get_file()),
		"res://videos/" + arq.get_file(), "res://" + arq]
	for c in lista:
		if c.begins_with("res://"):
			if ResourceLoader.exists(c):
				return c
		elif c.is_absolute_path() and FileAccess.file_exists(c):
			return c
	return ""


func tocar_video(nome: String, pode_pular := true) -> void:
	var caminho := achar_video(nome)
	var camada := CanvasLayer.new()
	camada.layer = 40
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camada)
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.size = Vector2(480, 270)
	camada.add_child(fundo)
	if caminho == "":
		var aviso := Label.new()
		aviso.text = "(vídeo não encontrado: %s)" % nome
		aviso.position = Vector2(20, 125)
		aviso.add_theme_color_override("font_color", Color("ffd34e"))
		camada.add_child(aviso)
		await get_tree().create_timer(1.5).timeout
		camada.queue_free()
		return
	var stream: VideoStream
	if caminho.begins_with("res://"):
		stream = load(caminho)
	else:
		var t := VideoStreamTheora.new()
		t.file = caminho
		stream = t
	var vp := VideoStreamPlayer.new()
	vp.stream = stream
	vp.expand = true
	vp.size = Vector2(480, 270)
	vp.volume_db = -2.0
	camada.add_child(vp)
	var dica := Label.new()
	dica.text = Controles.tecla("interagir") + ": pular"
	dica.position = Vector2(404, 252)
	dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	dica.visible = false
	camada.add_child(dica)
	var musica_antes := Jogo.musica_atual()
	Jogo.tocar_musica("", 0.3)
	vp.play()
	await get_tree().process_frame
	# mantém a proporção do vídeo (faixas pretas se precisar)
	var tex := vp.get_video_texture()
	if tex and tex.get_width() > 0:
		var esc := minf(480.0 / tex.get_width(), 270.0 / tex.get_height())
		vp.size = Vector2(tex.get_width(), tex.get_height()) * esc
		vp.position = (Vector2(480, 270) - vp.size) / 2
	var t := 0.0
	while vp.is_playing():
		await get_tree().process_frame
		t += get_process_delta_time()
		dica.visible = pode_pular and t > 0.8
		if pode_pular and t > 0.3 and (Input.is_action_just_pressed("interagir") or Input.is_action_just_pressed("voltar")):
			break
	vp.stop()
	camada.queue_free()
	if musica_antes != "":
		Jogo.tocar_musica(musica_antes, 0.5)


# ======================================================== escrever e testar história
## F5: relê o .txt/.json do capítulo e mostra os erros. F6: modo teste (cena ou mapa direto).

func _erros_historia() -> Array:
	return Historia.verificar(capitulo)


func _avisar_erros() -> void:
	var n := _erros_historia().size()
	if n == 0:
		return
	var l := Label.new()
	l.text = "%d erro(s) na história - F5 mostra" % n
	l.add_theme_color_override("font_color", Color("ff6b6b"))
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.position = Vector2(6, 256)
	var c := CanvasLayer.new()
	c.layer = 6
	c.add_child(l)
	add_child(c)
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(c.queue_free)


func recarregar_historia() -> void:
	for cap in Dados.capitulos():
		if cap.get("_arquivo", "") == capitulo.get("_arquivo", ""):
			for k in cap:
				if k != "npcs":   # os NPCs já estão no mapa; o resto vale na hora
					capitulo[k] = cap[k]
	Roteiro.apelidos = {}
	for k in capitulo.get("apelidos", {}):
		Roteiro.apelidos[Roteiro.sem_acento(str(k).to_lower())] = Roteiro.nome(str(capitulo.apelidos[k]))
	var erros := _erros_historia()
	Historia.gravar_relatorio(erros)
	var txt := ""
	if erros.is_empty():
		txt = "[color=#6fd08c]Tudo certo![/color] %d cenas carregadas.\n\nF6 abre o modo teste." % capitulo.get("cenas", {}).size()
	else:
		for e in erros:
			txt += "[color=#ff6b6b]-[/color] " + str(e).replace("[", "[lb]") + "\n"
	_abrir_painel("História recarregada (%d erro%s)" % [erros.size(), "" if erros.size() == 1 else "s"], txt, "recarregar")


var _cenas_de_outro_cap := {}


func abrir_teste() -> void:
	_jogador.andando = false
	var m := preload("res://scripts/teste_menu.gd").new()
	var cs: Array = capitulo.get("cenas", {}).keys()
	cs.sort()
	# cenas marcadas com "| teste: nome" (em qualquer capítulo) vêm primeiro, com nome fácil
	var destaques := []
	_cenas_de_outro_cap = {}
	for cap in Dados.capitulos():
		for id in cap.get("cenas", {}):
			var c = cap.cenas[id]
			if c is Dictionary and c.has("teste"):
				destaques.append(["★ " + str(c.teste), id])
				if not capitulo.get("cenas", {}).has(id):
					_cenas_de_outro_cap[id] = cap.cenas
	m.cenas = destaques + cs
	m.mapas = Dados.lista_mapas()
	_painel = m
	m.escolheu.connect(func(tipo: String, id: String):
		_painel = null
		if tipo == "cena":
			if _cenas_de_outro_cap.has(id):   # cena de outro capítulo: traz as cenas dele pro teste
				var de_la: Dictionary = _cenas_de_outro_cap[id]
				for k in de_la:
					if not capitulo.cenas.has(k):
						capitulo.cenas[k] = de_la[k]
			testar_cena(id)
		elif tipo == "mapa":
			testar_mapa(id))
	add_child(m)


func _marcar_teste() -> void:
	if modo_teste:
		return
	modo_teste = true
	var l := Label.new()
	l.text = "MODO TESTE"
	l.add_theme_color_override("font_color", Color("ff9f43"))
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.position = Vector2(398, 4)
	var c := CanvasLayer.new()
	c.layer = 6
	c.add_child(l)
	add_child(c)


## Toca a cena já: marca o que ela "requer", leva o Breno pro mapa de quem chama a cena.
func testar_cena(id: String) -> void:
	_marcar_teste()
	var d := def_cena(id)
	for r in (d.get("requer", []) if d.get("requer", []) is Array else [d.requer]):
		if not str(r).begins_with("!"):
			flags[str(r)] = true
	var onde := onde_fica_cena(id)
	var npc := str(onde.get("npc", ""))
	if onde.has("mapa") and onde.mapa != _mapa.id:
		await ir_para_mapa(onde.mapa, onde)
	elif onde.has("x"):
		_jogador.position = Vector2(onde.x, onde.y)
	if npc != "" and personagem(npc):
		_jogador.olhar_para(personagem(npc).position)
	tocar_cena(id, npc)


func testar_mapa(id: String) -> void:
	_marcar_teste()
	await ir_para_mapa(id, chegada_do_mapa(id))


## Onde a cena é chamada: {mapa, x, y, dir, npc} (perto do NPC, gatilho ou ponto que usa ela).
func onde_fica_cena(id: String) -> Dictionary:
	for n in _defs_npcs():
		if id in Historia._cenas_de(n):
			var dy := 34.0
			return {"mapa": n.get("mapa", _mapa.id), "x": float(n.get("x", 240)), "y": float(n.get("y", 200)) + dy,
				"dir": "cima", "npc": str(n.get("personagem", ""))}
	for g in capitulo.get("gatilhos", []):
		if id in Historia._cenas_de(g):
			return {"mapa": g.get("mapa", _mapa.id), "x": float(g.get("x", 0)) + float(g.get("w", 0)) / 2,
				"y": float(g.get("y", 0)) + float(g.get("h", 0)) / 2, "dir": "baixo"}
	for mid in Dados.lista_mapas():
		var md = Dados.mapa(mid)
		if md is Dictionary:
			for p in md.get("pontos", []):
				if id in Historia._cenas_de(p):
					return {"mapa": mid, "x": float(p.get("x", 0)) + float(p.get("w", 0)) / 2,
						"y": float(p.get("y", 0)) + float(p.get("h", 0)) + 14.0, "dir": "cima"}
	return {}


## Um lugar bom pra aparecer no mapa: a chegada de alguma porta que leva até ele.
func chegada_do_mapa(id: String) -> Dictionary:
	if id == capitulo.get("mapa_inicial", "") and capitulo.get("inicio") is Dictionary:
		return capitulo.inicio
	for mid in Dados.lista_mapas():
		var md = Dados.mapa(mid)
		if md is Dictionary:
			for porta in md.get("portas", []):
				if porta.get("para", "") == id and porta.get("chegada") is Dictionary:
					return porta.chegada
	return {"x": 240, "y": 200, "dir": "baixo"}


# ======================================================== carregar antes (sem engasgo ao trocar de mapa)
## Pede pra carregar em segundo plano as imagens de todos os mapas e personagens do capítulo,
## assim a primeira vez em cada mapa não dá aquela travadinha (ajuda muito em PC fraco).
func _pre_carregar() -> void:
	var caminhos := {}
	for mid in Dados.lista_mapas():
		var md = Dados.mapa(mid)
		if not md is Dictionary:
			continue
		var lst: Array = [str(md.get("fundo", {}).get("imagem", ""))]
		for o in md.get("objetos", []):
			lst.append(str(o.get("imagem", "")))
		for arq in lst:
			if arq != "":
				caminhos["res://capitulos/mapas/" + arq] = true
	var gente := {}
	for n in capitulo.get("npcs", []):
		gente[str(n.get("personagem", ""))] = true
	for i in range(1, 11):
		gente["aluno%d" % i] = true
	for g in gente:
		for tipo in ["andando_8", "andando", "acoes", "acoes2", "cena", "rosto_gemini"]:
			caminhos["%s/%s/%s.png" % [Dados.pasta_personagens(), g, tipo]] = true
	for c in caminhos:
		if ResourceLoader.exists(c) and not ResourceLoader.has_cached(c):
			ResourceLoader.load_threaded_request(c)

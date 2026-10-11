extends Node
## Mundo da v2 (primeira leva): a floresta de 2880x1620 (3x3 telas) dirigida por dados/v2_floresta.json, com o herói, ~20 monstros, câmera que
## segue, luz e sombra dinâmicas e atmosfera. É a base jogável sobre o protótipo cara_nova (que fica congelado como referência).
## Módulos (v2/): apresentacao (SubViewport 960x540 + sharp bilinear), camera_mundo, luzes, sombras, atmosfera, cenario (carregador), ator,
## heroi, monstro, sprites, entrada e o combate (combate, efeitos, orbes, progresso, diretor, telas, audio). Este script monta tudo e roda a
## ordem do quadro; nada de v1 (main.gd, arena.gd) é tocado.
##
## Rodar (a partir de jogos/hordas):  godot --path projeto res://v2/mundo.tscn [-- opções]
## Opções (após --): --fotos=PASTA --seq=2.0 --pos=x,y --nome=foto (foto do viewport e sai) | --medir --duracao=6 (fps e sai)
##   --sombra=baixa|media|alta|nenhuma (vale por cima da aba Gráficos) --particulas=nenhuma|poucas|medias|muitas --sem_vsync --sem_normal
##   --imortal --robo --estresse=N --roteiro=combate|correr (medição e fotos do combate, v2/roteiro.gd)
##   --depur (liga o texto de depuração do combate; F1 alterna)
##   --janela=1280x720 --rotulo (fps na tela) --escala_pura (nearest fracionário em vez do sharp bilinear) --colisao (formas de colisão ligadas)
## Modo livre: WASD/analógico anda, o mouse mira, clique esquerdo golpeia (combo de 3), Espaço esquiva, Shift corre, 1/2/3 trocam a sombra (baixa/média/alta),
## 0 desliga, F1 liga o texto de depuração do combate, F4 mostra a colisão, Esc sai.
## API pública para o HUD e o minimapa (ler com get() e valor padrão): no mundo abates, combo, tempo_partida, monstros_vivos, almas_partida,
## anuncios_no_hud e os sinais nivel_subiu, onda_forte, elite_apareceu, chefe_apareceu, chefe_vida, evolucao, anuncio e partida_terminou;
## no herói vida, vida_max, xp, xp_proximo, nivel, folego, folego_max, cansado.

const Apresentacao := preload("res://v2/apresentacao.gd")
const CameraMundo := preload("res://v2/camera_mundo.gd")
const Atmosfera := preload("res://v2/atmosfera.gd")
const Luzes := preload("res://v2/luzes.gd")
const Sombras := preload("res://v2/sombras.gd")
const Cenario := preload("res://v2/cenario.gd")
const Sprites := preload("res://v2/sprites.gd")
const Heroi := preload("res://v2/heroi.gd")
const Monstro := preload("res://v2/monstro.gd")
const Entrada := preload("res://v2/entrada.gd")
const Combate := preload("res://v2/combate.gd")
const Roteiro := preload("res://v2/roteiro.gd")
const Copas := preload("res://v2/copas.gd")
const Depuracao := preload("res://v2/depuracao_colisao.gd")
const LARG := 960
const ALT := 540
const MARGEM_SOMBRA := 96.0  # só ator a até 96 px da tela tem sombra
const Colisao := preload("res://v2/colisao.gd")
const TIPOS_MONSTRO := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_espantalho", "inimigo_lobo_sombrio", "inimigo_cavaleiro_oco"]
const PESOS_MONSTRO := [4, 4, 3, 3, 1]

signal nivel_subiu(nivel: int)
## Sinais da partida (leva 3), para o HUD e a meta-progressão: onda forte começou, elite/chefe apareceu, vida do chefe mudou, evolução feita,
## anúncio grande (texto + cor) e fim da partida com o resultado {tempo, abates, nivel, maior_combo, venceu, almas}.
signal onda_forte(numero: int)
signal elite_apareceu(nome: String)
signal chefe_apareceu(nome: String, vida_max: float)
signal chefe_vida(vida: float)
signal evolucao(nome: String)
signal anuncio(texto: String, cor: Color)
signal partida_terminou(resultado: Dictionary)

## Para os testes: true antes de add_child pula o que mexe na janela e nas fotos.
var modo_teste := false
var mouse_forcado: Variant = null  # testes: um Vector2 do mundo aqui vale no lugar do mouse
var dados: Dictionary = {}
var ap
var sv: SubViewport
var cam
var luzes
var sombras
var atm
var cenario
var copas  # copa transparente das árvores (copas.gd)
var dbg_colisao: Node2D  # F4: contorno das formas de colisão (depuracao_colisao.gd)
var sprites
var heroi
var monstros: Array = []  # os monstros VIVOS (quem morre volta para o pool e renasce depois)
var combate
var roteiro  # opções de medição e fotos (roteiro.gd); null no jogo normal
var abates := 0  # monstros mortos na partida
var combo := 0  # abates em sequência (zera depois de ~3 s sem matar)
var maior_combo := 0
var xp_coletado := 0.0  # soma do XP dos orbes pegos (com o bônus do combo)
var resultado: Dictionary = {}  # o último resultado de partida (vazio enquanto joga)
var anuncios_no_hud := false  # o HUD liga isto quando passa a desenhar os anúncios e a barra do chefe: telas.gd para de desenhar os dela
var almas_partida: int:  # almas ganhas na partida = XP coletado / 10, arredondado (a meta-progressão lê isto)
	get:
		return roundi(xp_coletado / 10.0)
var tempo_partida := 0.0  # s de jogo (não conta hit-stop nem a pausa da escolha)
var monstros_vivos: int:
	get:
		return monstros.size()
var _pool_monstros := {}  # tipo -> monstros mortos prontos para renascer
var _todos_monstros: Array = []
var _sombras_prontas := false
var mapa := Rect2(0, 0, 2880, 1620)
var limite_andavel := Rect2(150, 150, 2580, 1320)  # onde herói e monstros podem pisar (mapa menos "borda_andavel")
var t := 0.0
var quadros := 0
var args := {}
var no_mundo: Node2D  # onde ficam objetos, herói e monstros (y-sort)
var glow: CanvasLayer  # brilho, fogo e olhos: acima do escurecimento (segue a câmera)
var _modo := "livre"
var _fotos := ""
var _seq := 2.0
var _foto_feita := false
var _med := {"inicio": -1.0, "frames": 0, "aquecer": 2.0, "duracao": 6.0}
var _rng := RandomNumberGenerator.new()
var _rotulo: Label
var _rotulo_t := 0.0
var _us_total := 0
var _ms_carga := 0.0


func _ready() -> void:
	var t0 := Time.get_ticks_usec()
	args = _argumentos()
	_modo = "medir" if args.has("medir") else ("foto" if args.has("fotos") else "livre")
	_fotos = str(args.get("fotos", ""))
	_seq = float(args.get("seq", 2.0))
	_med["duracao"] = float(args.get("duracao", 6.0))
	Entrada.garantir()
	dados = Dados.json("v2_floresta")
	var tm: Array = dados.get("mapa", {}).get("tam", [2880, 1620])
	mapa = Rect2(0, 0, float(tm[0]), float(tm[1]))
	var borda := float(dados.get("mapa", {}).get("borda_andavel", 24.0))
	limite_andavel = mapa.grow(-borda)
	if not modo_teste:
		_ajustar_janela()
	ap = Apresentacao.new()
	add_child(ap)
	sv = ap.montar(get_window(), args.has("escala_pura"))
	if not modo_teste and (_modo == "medir" or args.has("sem_vsync")):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	RenderingServer.set_default_clear_color(Color(0.02, 0.03, 0.03))
	_montar()
	sv.add_child(preload("res://v2/hud.gd").criar(self))
	sv.add_child(preload("res://v2/minimapa.tscn").instantiate().iniciar(self))
	_ms_carga = (Time.get_ticks_usec() - t0) / 1000.0
	Config.graficos_mudou.connect(_ler_graficos)
	if _modo == "livre" or args.has("rotulo"):
		_montar_rotulo()
	if _modo == "medir":
		print(
			(
				"CARGA ms=%.0f cenario=%.0f blur=%.0f objetos=%d decalques=%d luzes=%d"
				% [_ms_carga, cenario.ms_carga, sprites.ms_blur, cenario.objetos.size(), cenario.n_decalques, luzes.lista.size()]
			)
		)


func _exit_tree() -> void:
	if combate != null:
		combate.liberar()
		combate = null
	roteiro = null


func _argumentos() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var partes := a.trim_prefix("--").split("=", true, 1)
		d[partes[0]] = partes[1] if partes.size() > 1 else "1"
	return d


func _ajustar_janela() -> void:
	var janela := get_window()
	if args.has("janela"):
		var wh := str(args.janela).split("x")
		janela.size = Vector2i(int(wh[0]), int(wh[1]))
	elif _modo == "livre":
		# a maior janela 16:9 que cabe na tela (o sharp bilinear cuida da escala fracionária, sem barras)
		var util := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var k := minf(util.size.x / float(LARG), (util.size.y - 70) / float(ALT))
		janela.size = Vector2i(int(LARG * k), int(ALT * k))
		janela.move_to_center()
	else:
		janela.size = Vector2i(1280, 720)


# ------------------------------------------------------------------ montagem


func _montar() -> void:
	var m: Dictionary = dados.get("mapa", {})
	var escuro := CanvasModulate.new()
	escuro.color = Color(str(m.get("ambiente", "172a30")))  # verde-azulado quase preto da arte de entrada
	sv.add_child(escuro)
	no_mundo = Node2D.new()
	no_mundo.y_sort_enabled = true
	sv.add_child(no_mundo)
	cam = CameraMundo.new()
	cam.limites = mapa
	sv.add_child(cam)
	glow = CanvasLayer.new()  # fora do CanvasModulate: o brilho do fogo e dos olhos não escurece junto com o resto
	glow.layer = 2
	glow.follow_viewport_enabled = true
	sv.add_child(glow)
	sprites = Sprites.new()
	sprites.com_normal = not args.has("sem_normal")
	atm = Atmosfera.new()
	atm.montar(glow)
	luzes = Luzes.new()
	luzes.montar(sv, glow, atm, dados.get("luz_tipos", {}))
	sombras = Sombras.new()
	sombras.montar(no_mundo)
	sombras.luzes = luzes
	cenario = Cenario.new()
	cenario.carregar(dados, no_mundo, luzes, sombras, sprites.com_normal)
	copas = Copas.new()
	copas.montar(cenario.objetos)
	dbg_colisao = Depuracao.new()
	dbg_colisao.mundo = self
	dbg_colisao.z_index = 400  # por cima do mundo inteiro (árvores, atores, sombras)
	dbg_colisao.visible = args.has("colisao")
	no_mundo.add_child(dbg_colisao)
	_rng.seed = int(dados.get("semente", 11))
	combate = Combate.new()
	combate.montar(self)
	_criar_heroi()
	combate.iniciar_heroi()
	_pre_criar_monstros()
	_popular_inicial()
	var todos: Array = cenario.objetos.duplicate()
	todos.append(heroi)
	todos.append_array(_todos_monstros)
	sombras.registrar_lote(todos)
	_sombras_prontas = true
	cam.cravar(heroi.pos + Heroi.CENTRO_CORPO)
	_luar(m)
	atm.ambiente(cam.position)
	_vinheta()
	_ler_graficos()
	if args.has("estresse") or args.has("robo") or args.has("roteiro") or args.has("imortal"):
		roteiro = Roteiro.new()
		roteiro.montar(self, args)
	avancar(0.0)


func _criar_heroi() -> void:
	var nasc: Dictionary = dados.get("nascimento", {})
	var c: Array = nasc.get("heroi", [1440, 820])
	var p := Vector2(float(c[0]), float(c[1]))
	if args.has("pos"):
		var xy := str(args.pos).split(",")
		p = Vector2(float(xy[0]), float(xy[1]))
	heroi = Heroi.new()
	if _modo != "livre":  # foto e medição não dependem do teclado de quem estiver na máquina
		heroi.entrada_forcada = _entrada_roteiro()
	heroi.criar(self, no_mundo, sprites.tipo("hazaki" if args.has("basico") else "hazaki_samurai"), p)
	# a tocha e a aura andam com o herói (a posição é o ponto no chão que a luz ilumina)
	luzes.prender(luzes.criar("tocha", p), heroi, Vector2(-38, -32))
	luzes.prender(luzes.criar("aura", p), heroi, Vector2(30, -8))


## Foto e medição: o herói fica parado, ou anda sozinho com --anda=dx,dy (direção).
func _entrada_roteiro() -> Vector2:
	if args.has("anda"):
		var xy := str(args.anda).split(",")
		return Vector2(float(xy[0]), float(xy[1])).normalized()
	return Vector2.ZERO


## Cria os monstros do pool de uma vez (e escondidos): morrer e renascer não cria nó nenhum durante a partida.
func _pre_criar_monstros() -> void:
	var pool: Dictionary = combate.cfg.get("pool", {})
	for nome in TIPOS_MONSTRO:
		for i in int(pool.get(nome, 0)):
			var mo = _novo_monstro(nome)
			mo.vivo = false
			mo.raiz.visible = false
			if not _pool_monstros.has(nome):
				_pool_monstros[nome] = []
			_pool_monstros[nome].append(mo)


## Os monstros que já estão no mapa quando a partida começa (zonas do json).
func _popular_inicial() -> void:
	var nasc: Dictionary = dados.get("nascimento", {})
	for z in nasc.get("monstros", []):
		var centro := Vector2(float(z.centro[0]), float(z.centro[1]))
		var raio := float(z.get("raio", 120.0))
		for i in int(z.get("n", 1)):
			var nome := _sorteia(TIPOS_MONSTRO, PESOS_MONSTRO)
			var a := _rng.randf() * TAU
			var p := centro + Vector2(cos(a), sin(a) * 0.6) * raio * sqrt(_rng.randf())
			var mo = nascer_monstro(nome, p)
			mo.raio_vaga = float(z.get("vaga", 90.0))


## Um monstro novo do tipo `nome` (nós, olhos e sombra). Só é chamado quando o pool do tipo esvazia.
func _novo_monstro(nome: String):
	var tp: Dictionary = sprites.tipo(nome)
	var mo := Monstro.new()
	mo.criar(self, no_mundo, nome, tp, Vector2.ZERO, _rng)
	mo.aplicar_stats(combate.cfg.monstros[nome])
	if tp.emissao != null:
		var o := Sprite2D.new()
		o.texture = tp.emissao
		o.region_enabled = true
		o.region_rect = mo.regiao
		o.centered = false
		o.offset = Vector2(-tp.w / 2.0, -tp.pe)
		o.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		o.material = mat
		o.visible = false
		glow.add_child(o)
		mo.olho = o
	_todos_monstros.append(mo)
	if _sombras_prontas:
		sombras.registrar_lote([mo])
	return mo


## Faz um monstro do tipo `nome` nascer em `p` (do pool, ou novo se o pool esvaziou). `cacador` = persegue de qualquer distância.
func nascer_monstro(nome: String, p: Vector2, cacador := false, k_vida := 1.0, k_dano := 1.0):
	var lista: Array = _pool_monstros.get(nome, [])
	var mo
	if lista.is_empty():
		mo = _novo_monstro(nome)
	else:
		mo = lista.pop_back()
	mo.aplicar_stats(combate.cfg.monstros[nome], k_vida, k_dano)
	mo.cacador = cacador
	mo.raio_vaga = 90.0
	mo.reviver(p)
	monstros.append(mo)
	return mo


## O monstro morreu (ou a partida acabou): sai da lista dos vivos e fica no pool do tipo.
func devolver_monstro(mo) -> void:
	monstros.erase(mo)
	if not _pool_monstros.has(mo.chave):
		_pool_monstros[mo.chave] = []
	_pool_monstros[mo.chave].append(mo)


func _sorteia(itens: Array, pesos: Array) -> String:
	var total := 0
	for p in pesos:
		total += p
	var r := _rng.randi() % total
	for i in itens.size():
		r -= pesos[i]
		if r < 0:
			return itens[i]
	return itens[0]


## Luar: contraluz azulado fraco, de cima, que pega o topo e as bordas dos objetos pelo normal map (o cenário das bordas não vira silhueta
## preta). DirectionalLight2D sem sombra própria e fora da lista de luzes: não entra na conta das sombras (a sombra do luar seria fixa).
func _luar(m: Dictionary) -> void:
	var l := DirectionalLight2D.new()
	var lu: Dictionary = m.get("luar", {})
	l.color = Color(0.42, 0.58, 1.0)
	l.energy = float(lu.get("e", 0.32))
	l.height = float(lu.get("h", 0.2))
	l.rotation = deg_to_rad(float(lu.get("ang", 90.0)))
	l.shadow_enabled = false
	sv.add_child(l)


func _vinheta() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 3
	sv.add_child(camada)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.12), Color(0, 0, 0, 0.62)])
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.85)
	tx.width = 192
	tx.height = 108
	var r := TextureRect.new()
	r.texture = tx
	r.size = Vector2(LARG, ALT)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(r)


## Lê da aba Gráficos o modo de sombra (opção "sombras": baixa, media, alta) e as partículas ("particulas_sim"). --sombra= e --particulas=
## valem por cima (medição e fotos).
func _ler_graficos() -> void:
	var nome := str(args.get("sombra", Config.g("sombras")))
	var m := Sombras.NOMES.find(nome)
	sombras.definir_modo(m if m >= 0 else Sombras.MEDIA)
	var nivel := str(args.get("particulas", Config.g("particulas_sim")))
	var f: Dictionary = Config.PART_NIVEL.get(nivel, {})
	atm.definir_fatores(float(f.get("amb_particulas", 1.0)), float(f.get("efe_particulas", 1.0)))
	if combate != null:
		combate.fx.fator_part = clampf(float(f.get("efe_particulas", 1.0)), 0.25, 1.0)


# ------------------------------------------------------------------ movimento e mouse


## PONTO ÚNICO DE MOVIMENTO: o herói e os monstros pedem aqui o deslocamento que querem (`desejado`, em px) e é aqui que a colisão age
## (v2/colisao.gd: o corpo é um círculo de raio `a.raio` no chão; contra as elipses dos objetos ele é empurrado e desliza). Depois prende
## na área andável (o mapa menos "borda_andavel": as árvores das bordas fecham o mapa). Devolve o deslocamento que de fato aconteceu.
func mover(a, desejado: Vector2) -> Vector2:
	var antes: Vector2 = a.pos
	var depois: Vector2 = Colisao.resolver(antes + desejado, a.raio)
	depois = depois.clamp(limite_andavel.position, limite_andavel.end)
	a.definir_pos(depois)
	return depois - antes


## Mouse nas coordenadas do mundo (a tela do mundo é 960x540 e a câmera já é inteira).
func mouse_mundo() -> Vector2:
	if mouse_forcado != null:
		return mouse_forcado
	if modo_teste or DisplayServer.get_name() == "headless":
		return heroi.pos + Heroi.CENTRO_CORPO + heroi.dir_olhar * 100.0
	return cam.centro_base() - Vector2(LARG, ALT) / 2.0 + ap.mouse_na_tela()


func _input(e: InputEvent) -> void:
	if combate != null and combate.telas.entrada(e):
		get_viewport().set_input_as_handled()
		return
	if (e is InputEventMouseMotion or e is InputEventMouseButton) and heroi != null:
		heroi.fonte = Heroi.Fonte.MOUSE
	if heroi != null and heroi.entrada_forcada == null and not combate.pausado:
		heroi.entrada_evento(e)
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_0:
			sombras.definir_modo(Sombras.NENHUMA)
		KEY_1:
			sombras.definir_modo(Sombras.BAIXA)
		KEY_2:
			sombras.definir_modo(Sombras.MEDIA)
		KEY_3:
			sombras.definir_modo(Sombras.ALTA)
		KEY_F4:
			dbg_colisao.visible = not dbg_colisao.visible
		KEY_ESCAPE:
			if get_tree().current_scene == self and not modo_teste:
				get_tree().quit()


# ------------------------------------------------------------------ quadro


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	avancar(minf(delta, 0.1))
	if roteiro != null:
		roteiro.atualizar(delta)
	_us_total += Time.get_ticks_usec() - t0
	if _rotulo != null:
		_rotulo_t += delta
		if _rotulo_t > 0.3:
			_rotulo_t = 0.0
			_texto_rotulo()
	if modo_teste:
		return
	if _modo == "medir":
		_medir()
	elif _modo == "foto" and not _foto_feita and t >= _seq and (roteiro == null or roteiro.roteiro == ""):
		_foto_feita = true
		_salvar_foto()


## Um passo do mundo, na ordem: herói, monstros, câmera, blocos visíveis, luzes (as da tela), atores na tela (sombra e olhos).
## Os testes chamam isto direto, com passos fixos de 1/60 s (set_process(false)).
func avancar(dt: float) -> void:
	t += dt
	quadros += 1
	if dt > 0.0:
		var dtm: float = combate.passo_tempo(dt)  # o mundo para no hit-stop e na pausa, e anda devagar na câmera lenta
		if dtm > 0.0:
			tempo_partida += dtm
			heroi.atualizar(dtm)
			for mo in monstros:
				mo.atualizar(dtm, heroi.pos)
			combate.atualizar(dtm)
		cam.seguir(heroi.pos + Heroi.CENTRO_CORPO + heroi.avanco_camera, dt)
		combate.efeitos(dt)
	var rect: Rect2 = cam.retangulo()
	atm.seguir(cam.position)
	cenario.atualizar_blocos(rect)
	var atores_mov: Array = [heroi]
	atores_mov.append_array(monstros)
	copas.atualizar(dt, cenario.ativos, atores_mov)
	luzes.atualizar(t, rect)
	var tela := rect.grow(MARGEM_SOMBRA)
	var com_sombra: bool = sombras.modo != Sombras.NENHUMA
	var estatica: bool = sombras.modo >= Sombras.MEDIA  # na baixa, o objeto parado só tem a mancha, que não muda
	var n := 0
	for a in cenario.ativos:
		var dentro := com_sombra and tela.has_point(a.pos)
		if dentro != a.ativo:
			sombras.ativar(a, dentro)
		n += 1
		if dentro and estatica and (n + quadros) % 2 == 0:  # cenário parado: só a luz muda, metade por quadro
			sombras.atualizar(a, t)
	var movel: Array = [heroi]
	movel.append_array(monstros)
	for a in movel:
		var dentro := com_sombra and tela.has_point(a.pos)
		if dentro != a.ativo:
			sombras.ativar(a, dentro)
			if a.olho != null:
				a.olho.visible = dentro
		if dentro:
			sombras.atualizar(a, t)


## Jogar de novo: o mesmo mapa, o herói no início, monstros do começo e tudo zerado.
func reiniciar() -> void:
	_rng.seed = int(dados.get("semente", 11))
	combate.limpar_partida()
	tempo_partida = 0.0
	abates = 0
	combo = 0
	maior_combo = 0
	var c: Array = dados.get("nascimento", {}).get("heroi", [1440, 820])
	heroi.resetar(Vector2(float(c[0]), float(c[1])))
	combate.iniciar_heroi()
	cam.cravar(heroi.pos + Heroi.CENTRO_CORPO)
	_popular_inicial()


func get_modo() -> String:
	return _modo


func atores_ativos() -> int:
	var n := 0
	for a in cenario.objetos:
		if a.ativo:
			n += 1
	for a in monstros:
		if a.ativo:
			n += 1
	return n + (1 if heroi.ativo else 0)


# ------------------------------------------------------------------ rótulo, foto e medição


func _montar_rotulo() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 4
	sv.add_child(camada)
	_rotulo = Label.new()
	_rotulo.position = Vector2(6, 4)
	_rotulo.add_theme_font_size_override("font_size", 12)
	_rotulo.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_rotulo.add_theme_constant_override("outline_size", 4)
	camada.add_child(_rotulo)
	_texto_rotulo()


func _texto_rotulo() -> void:
	_rotulo.text = (
		"sombra: %s   %d fps   atores na tela: %d   luzes ligadas: %d/%d\nWASD anda   mouse mira   1 baixa  2 media  3 alta  0 sem sombra   F4 colisão   Esc sai"
		% [str(Sombras.NOMES[sombras.modo]).to_upper(), Engine.get_frames_per_second(), atores_ativos(), luzes.ligadas(), luzes.lista.size()]
	)


func _salvar_foto() -> void:
	var caminho := _fotos.path_join("%s.png" % str(args.get("nome", "v2")))
	var tam: Vector2i = await ap.foto(caminho)
	print("FOTO ", caminho, " ", tam, " t=%.2f heroi=%s cam=%s" % [t, str(heroi.pos), str(cam.position)])
	get_tree().quit()


func _medir() -> void:
	if t < _med["aquecer"]:
		_us_total = 0
		return
	if _med["inicio"] < 0.0:
		_med["inicio"] = t
		_us_total = 0
		sombras.us_script = 0
		return
	_med["frames"] = int(_med["frames"]) + 1
	var dec: float = t - float(_med["inicio"])
	if dec >= float(_med["duracao"]):
		var frames: int = int(_med["frames"])
		print(
			(
				"MEDIDA sombra=%s luzes_ligadas=%d/%d atores_na_tela=%d blocos=%d/%d fps=%.1f frames=%d seg=%.2f"
				% [
					Sombras.NOMES[sombras.modo],
					luzes.ligadas(),
					luzes.lista.size(),
					atores_ativos(),
					cenario.n_blocos_visiveis(),
					cenario.n_blocos(),
					frames / dec,
					frames,
					dec
				]
			)
		)
		print("SCRIPT ms/quadro=%.3f (sombras %.3f)" % [_us_total / 1000.0 / frames, sombras.us_script / 1000.0 / frames])
		print(
			(
				"COMBATE abates=%d maior_combo=%d nivel=%d vivos=%d ondas=%d tempo_partida=%.1f vida=%d melhorias=%s"
				% [abates, maior_combo, heroi.nivel, monstros.size(), combate.diretor.ondas, tempo_partida, heroi.vida, str(combate.progresso.melhorias)]
			)
		)
		get_tree().quit()

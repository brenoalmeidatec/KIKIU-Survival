extends Node
## Mundo da v2 (primeira leva): a floresta de 2880x1620 (3x3 telas) dirigida por dados/v2_floresta.json, com o herói, ~20 monstros, câmera que
## segue, luz e sombra dinâmicas e atmosfera. É a base jogável sobre o protótipo cara_nova (que fica congelado como referência).
## Módulos (v2/): apresentacao (SubViewport 960x540 + sharp bilinear), camera_mundo, luzes, sombras, atmosfera, cenario (carregador), ator,
## heroi, monstro, sprites, entrada e o combate (combate, efeitos, orbes, progresso, diretor, telas, audio). Este script monta tudo e roda a
## ordem do quadro; nada de v1 (main.gd, arena.gd) é tocado.
##
## Rodar (a partir de jogos/hordas):  godot --path projeto res://v2/mundo.tscn [-- opções]
## Opções (após --): --fotos=PASTA --seq=2.0 --pos=x,y --nome=foto (foto do viewport e sai) | --medir --duracao=6 (fps e sai)
##   --perfil=baixo|medio|alto (vale o perfil de gráficos inteiro: sombras, partículas e orçamento de luzes; sem gravar) --luzes=N (orçamento de luzes)
##   --sombra=baixa|media|alta|nenhuma (vale por cima da aba Gráficos) --particulas=nenhuma|poucas|medias|muitas --sem_vsync --sem_normal
##   --imortal --robo --estresse=N --roteiro=combate|correr (medição e fotos do combate, v2/roteiro.gd)
##   --picos=MS (imprime cada quadro mais lento que MS ms, com as partes que pesaram nele, e um resumo no fim: v2/picos.gd)
##   --depur (liga o texto de depuração do combate; F1 alterna)
##   --tamanho_ui=auto|pequeno|medio|grande (vale o tamanho da interface, sem gravar nas opções) --ui_congelada (medição: o SubViewport da UI para de redesenhar) --janela=1280x720 --rotulo (começa com o texto de fps ligado) --escala_pura (nearest fracionário em vez do sharp bilinear) --colisao (formas de colisão ligadas)
## Modo livre: WASD/analógico anda, o mouse mira, clique esquerdo golpeia (combo de 3), botão direito (ou LT) ergue o ESCUDO, E (ou LB) é a RUPTURA, Q (ou RB) o ultimate (reservado), Espaço esquiva, Shift corre, 1/2/3 trocam a sombra (baixa/média/alta),
## 0 desliga, F1 liga o texto de depuração do combate, F3 liga o texto de fps e atores (desligado na partida normal), F4 mostra a colisão, C liga o card da build (v2/status.gd), Esc (ou Start) pausa e abre o menu (v2/pausa.gd: opções e Sair).
## API pública para o HUD e o minimapa (ler com get() e valor padrão): no mundo abates, combo, tempo_partida, monstros_vivos, almas_partida,
## e os sinais nivel_subiu, onda_forte, elite_apareceu, chefe_apareceu, chefe_vida, evolucao, anuncio e partida_terminou;
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
const Braseiros := preload("res://v2/braseiros.gd")  # o Braseiro Antigo: apagado, acende com o herói por perto e deixa a área mais segura
const Horda := preload("res://v2/horda.gd")  # os monstros comuns em lote (MultiMesh)
const Oclusao := preload("res://v2/oclusao.gd")  # silhueta do herói atrás de monstro grande (leva 4)
const Depuracao := preload("res://v2/depuracao_colisao.gd")
const Herois := preload("res://v2/herois.gd")  # heróis jogáveis (Hazaki, Nicão, Lucas)
const Meta := preload("res://v2/meta.gd")  # meta-progressão entre partidas (melhorias do santuário, almas, conquistas)
const ResultadoMeta := preload("res://v2/resultado_meta.gd")
const Mapas := preload("res://v2/mapas.gd")  # a lista de mapas e o escolhido no santuário
const Trilha := preload("res://v2/trilha.gd")  # a música de fundo da partida (faixa por momento, volume no bus Musica)
const QualidadeAuto := preload("res://v2/qualidade_auto.gd")  # "Baixar a qualidade se travar": desce o perfil quando o fps trava
const LARG := 960
const ALT := 540
const MAX_PASSO_COLISAO := 8.0  # menor pegada de árvore + círculo do herói ocupa mais que este passo
const ORCAMENTO_LUZES := {"desligada": 6, "so_heroi": 0, "tudo": 0}  # máximo de luzes ligadas por "luz_relevo" (0 = sem limite); o perfil Baixo usa "desligada"
const PASSO_SOMBRA_CENARIO := 3  # a sombra de cada objeto parado recalcula a cada 3 quadros (a luz que a move muda devagar; o deslize suaviza)
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
signal evolucao(nome: String, desc: String)
signal anuncio(texto: String, cor: Color)
signal partida_terminou(resultado: Dictionary)

## Para os testes: true antes de add_child pula o que mexe na janela e nas fotos.
var modo_teste := false
var id_mapa := ""  # "floresta", "laboratorio"...: vazio = o escolhido no santuário (floresta nos testes), ou --mapa=<id>; os testes podem pôr antes de add_child
var mouse_forcado: Variant = null  # testes: um Vector2 do mundo aqui vale no lugar do mouse
var dados: Dictionary = {}
var ap
var sv: SubViewport
var ui: SubViewport  # a interface (HUD, cartas, pausa...): tem o próprio SubViewport, do tamanho do canvas da UI (v2/apresentacao.gd, v2/escala_ui.gd)
var cam
var luzes
var sombras
var atm
var cenario
var copas  # buraco raio-x nas árvores atrás das quais o herói está (copas.gd)
var oclusao  # silhueta do herói quando um monstro na frente o cobre (oclusao.gd)
var braseiros  # os braseiros antigos do mapa (braseiros.gd)
var horda  # desenho dos monstros comuns em lote (horda.gd)
var dbg_colisao: Node2D  # F4: contorno das formas de colisão (depuracao_colisao.gd)
var sprites
var heroi  # o herói LOCAL (quem este teclado/controle comanda)
var herois: Array = []  # todos os heróis do mundo (local + remotos do coop + locais da tela dividida); no solo tem só o `heroi`
var coop_modo := ""  # --coop=host|join (etapa 1 do coop usa; hoje só é lido)
var monstros: Array = []  # os monstros VIVOS (quem morre volta para o pool e renasce depois)
var combate
var roteiro  # opções de medição e fotos (roteiro.gd); null no jogo normal
var meta_res  # resultado com as almas (resultado_meta.gd); null no modo de teste
var status  # card "SUA BUILD" (status.gd): a tecla C liga no HUD e a pausa o mostra ao lado do menu
var pausa  # menu de pausa (pausa.gd): pausa.aberto diz se está aberto (as telas leem aqui)
var trilha  # música de fundo (trilha.gd); null nas medições e nas fotos, que ficam mudas
var _qualidade := QualidadeAuto.new()  # a contagem do fps travado (opção qualidade_auto)
var _qualidade_ligada := false  # só no jogo de verdade: sem teste, sem argumentos e com janela
var meta_bonus := {}  # bônus do santuário que não são do herói: raridade, rolagem, almas (meta.gd aplicar)
var abates := 0  # monstros mortos na partida
var combo := 0  # abates em sequência (zera depois de ~3 s sem matar)
var maior_combo := 0
var xp_coletado := 0.0  # soma do XP dos orbes pegos (com o bônus do combo)
var resultado: Dictionary = {}  # o último resultado de partida (vazio enquanto joga)
var almas_partida: int:  # almas ganhas na partida = XP coletado / 10, arredondado (a meta-progressão lê isto)
	get:
		return maxi(0, roundi(xp_coletado / 10.0) - _almas_gastas)  # o mercador leva as que gastam o ouro da partida
var tempo_partida := 0.0  # s de jogo (não conta hit-stop nem a pausa da escolha)
var monstros_vivos: int:
	get:
		return monstros.size()
var _pool_monstros := {}  # tipo -> monstros mortos prontos para renascer
var _todos_monstros: Array = []
var _marcadores: Array = []  # marcas do mapa (dados "marcadores"): cada uma faz o efeito ao o herói entrar no raio (_tocar_marca)
var _tem_chave := false  # achou a chave da ruína nesta partida (abre o baú trancado)
var _fragmentos := 0  # fragmentos da relíquia achados nesta partida
var _alavancas := 0  # alavancas puxadas (duas abrem o atalho até o portão)
var _atalho_aberto := false
var _pilares_prox := 0  # quantos pilares já foram ativados na ordem certa (com um fora de ordem volta a zero)
var _pilares_ok := false  # os três pilares acenderam: o mini-chefe com "exige": "pilares" pode nascer
const PILARES := 3
const DEFESA_ONDA_S := 4.0  # a defesa de ponto solta uma onda de monstros a cada 4 s
const DEFESA_MONSTROS_POR_ONDA := 2
var _almas_gastas := 0  # almas da partida gastas no mercador (saem do almas_partida)
var _espinhos: Array = []  # zonas que machucam (dados "espinhos"): o caminho de pedra é seguro
const ESPINHOS_TIQUE_S := 1.0  # um tique de dano a cada segundo dentro da zona (o golpe tem invencibilidade)
const FRAGMENTOS_RELIQUIA := 4  # com estes fragmentos a relíquia monta e cai um baú
const COR_ANUNCIO := Color(1.0, 0.85, 0.4)
var _sombras_prontas := false
var mapa := Rect2(0, 0, 2880, 1620)
var minimapa  # o CanvasLayer do minimapa (o mirante revela o mapa inteiro por ele)
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
var _r_acum := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var perfil := {}  # medição (--medir): microssegundos acumulados por parte do quadro
var _ms_carga := 0.0
var picos = null  # --picos=MS: registro dos quadros lentos (v2/picos.gd)


func _ready() -> void:
	var t0 := Time.get_ticks_usec()
	args = _argumentos()
	coop_modo = str(args.get("coop", ""))  # lida e ignorada por enquanto: o solo não muda (docs/ONLINE_V2_PLANO.md, etapa 0)
	_modo = "medir" if args.has("medir") else ("foto" if args.has("fotos") else "livre")
	_fotos = str(args.get("fotos", ""))
	_seq = float(args.get("seq", 2.0))
	_med["duracao"] = float(args.get("duracao", 6.0))
	if args.has("playtest") and not modo_teste:  # robô de playtest (#301): save temporário próprio e sorteios pela semente
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest"))
		Meta.caminho_save = "user://playtest/meta_%d.cfg" % OS.get_process_id()
		for orfao in [Meta.caminho_save, Meta.caminho_save + ".tmp", Meta.caminho_save + ".bak"]:  # órfão de um PID reaproveitado
			if FileAccess.file_exists(orfao):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(orfao))
		seed(int(args.get("semente", 1)))
	Entrada.garantir()
	if args.has("picos") and not modo_teste:
		picos = preload("res://v2/picos.gd").new(float(args.picos))
	if args.has("tamanho_ui") and not modo_teste:  # fotos: vale o tamanho da interface (auto, pequeno, medio, grande) sem gravar nas opções
		Config.temporario("tamanho_ui", str(args.tamanho_ui))
	if args.has("perfil") and not modo_teste:  # medição: valer o perfil de gráficos (baixo, medio, alto) sem mexer no que está salvo
		Config.g_perfil_temporario(str(args.perfil))
	if id_mapa == "":
		id_mapa = str(args.get("mapa", Mapas.PADRAO if modo_teste else Mapas.escolhido()))
	dados = Dados.json(str(Mapas.buscar(id_mapa).dados))
	var tm: Array = dados.get("mapa", {}).get("tam", [2880, 1620])
	mapa = Rect2(0, 0, float(tm[0]), float(tm[1]))
	var borda := float(dados.get("mapa", {}).get("borda_andavel", 24.0))
	limite_andavel = mapa.grow(-borda)
	if not modo_teste:
		_ajustar_janela()
	ap = Apresentacao.new()
	add_child(ap)
	sv = ap.montar(get_window(), args.has("escala_pura"))
	ui = ap.ui
	if not modo_teste and (_modo == "medir" or args.has("sem_vsync")):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	RenderingServer.set_default_clear_color(Color(0.02, 0.03, 0.03))
	_montar()
	ui.add_child(preload("res://v2/hud.gd").criar(self))
	minimapa = preload("res://v2/minimapa.tscn").instantiate().iniciar(self)
	ui.add_child(minimapa)
	pausa = preload("res://v2/pausa.tscn").instantiate().iniciar(self)  # ESC ou Start pausam e abrem o menu (pausa.gd, com a Antena)
	ui.add_child(pausa)
	pausa.fechou.connect(func(): _qualidade.interromper())  # a árvore não processa durante a pausa: a retomada começa uma medição nova
	status = preload("res://v2/status.gd").criar(self)  # card "SUA BUILD": C liga no HUD, a pausa mostra ao lado do menu (status.gd)
	ui.add_child(status)
	if _modo == "livre":  # medir e fotografar ficam sem música
		trilha = Trilha.new()
		add_child(trilha)
		trilha.ligar(self)
	if not modo_teste:
		meta_res = ResultadoMeta.new()
		ui.add_child(meta_res)
		meta_res.montar(self)
	_ms_carga = (Time.get_ticks_usec() - t0) / 1000.0
	Config.graficos_mudou.connect(_ler_graficos)
	_qualidade_ligada = DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().is_empty()
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
	if picos != null:
		picos.resumo()
		picos = null
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
	if _modo == "foto":
		janela.unfocusable = true  # a foto não rouba o foco de quem está jogando por cima
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
	sombras.definir_ambiente(dados.get("mapa", {}).get("sombra_ambiente", {}))  # sombra base do mapa (laboratório); sem a chave, só as luzes
	cenario = Cenario.new()
	cenario.carregar(dados, no_mundo, luzes, sombras, sprites.com_normal)
	copas = Copas.new()
	copas.montar(cenario.objetos, float(dados.get("mapa", {}).get("copas_altura_min", Copas.ALTURA_MIN)), cenario)
	dbg_colisao = Depuracao.new()
	dbg_colisao.mundo = self
	dbg_colisao.z_index = 400  # por cima do mundo inteiro (árvores, atores, sombras)
	dbg_colisao.visible = args.has("colisao")
	no_mundo.add_child(dbg_colisao)
	_rng.seed = int(dados.get("semente", 11))
	combate = Combate.new()
	combate.montar(self)
	_criar_heroi()
	oclusao = Oclusao.new().montar(sv, heroi)
	combate.iniciar_heroi()
	Meta.aplicar(self)  # melhorias do santuário sobre os valores iniciais do herói (um ponto só, em v2/meta.gd)
	horda = Horda.new()
	horda.montar(self)
	braseiros = Braseiros.new()
	braseiros.montar(self)
	_pre_criar_monstros()
	_popular_inicial()
	var todos: Array = cenario.objetos.duplicate()
	todos.append(heroi)
	todos.append_array(_todos_monstros)
	sombras.registrar_lote(todos)
	_sombras_prontas = true
	cam.cravar(heroi.pos + Heroi.CENTRO_CORPO)
	_luar(m)
	atm.config = dados.get("atmosfera", {})
	atm.ambiente(cam.position)
	_vinheta()
	_ler_graficos()
	if args.has("estresse") or args.has("robo") or args.has("roteiro") or args.has("imortal") or args.has("build") or args.has("playtest"):
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
	herois = [heroi]
	if _modo != "livre":  # foto e medição não dependem do teclado de quem estiver na máquina
		heroi.entrada_forcada = _entrada_roteiro()
	heroi.criar(self, no_mundo, sprites.tipo(Herois.sprite(combate.heroi_id, args.has("basico"))), p)
	# a tocha e a aura andam com o herói (a posição é o ponto no chão que a luz ilumina)
	luzes.prender(luzes.criar("tocha", p), heroi, Vector2(-38, -32))
	luzes.prender(luzes.criar("aura", p), heroi, Vector2(30, -8))


## O herói vivo mais perto de `p` (o alvo dos monstros). Com todos caídos devolve o mais perto entre os caídos; sem lista, o local.
func alvo_mais_perto(p: Vector2):
	if herois.size() <= 1:
		return heroi
	var melhor = null
	var melhor_d := INF
	var melhor_vivo := false
	for h in herois:
		var vivo: bool = h.vida > 0.0
		if melhor_vivo and not vivo:
			continue
		var d: float = p.distance_squared_to(h.pos)
		if (vivo and not melhor_vivo) or d < melhor_d:
			melhor = h
			melhor_d = d
			melhor_vivo = vivo
	return melhor if melhor != null else heroi


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
	_montar_marcadores()  # as marcas voltam a nascer também no "Jogar de novo"
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


## Marcas do mapa (dados "marcadores"). Cada marca guarda `feito` (já teve efeito nesta partida) e `dentro` (o herói está no raio).
## O atalho ainda não faz nada (só dados). O portão cumpre a missão ao herói entrar no raio: some a seta do minimapa.
func _montar_marcadores() -> void:
	_marcadores.clear()
	_tem_chave = false
	_fragmentos = 0
	_alavancas = 0
	_atalho_aberto = false
	_pilares_prox = 0
	_pilares_ok = false
	_almas_gastas = 0
	for z in _espinhos:  # a reinicialização (Jogar de novo) refaz as zonas
		z.visual.queue_free()
	_espinhos.clear()
	for m in dados.get("marcadores", []):
		if str(m.tipo) == "espinhos":
			_espinhos.append(_montar_espinhos(m))
			continue
		(
			_marcadores
			. append(
				{
					"tipo": str(m.tipo),
					"pos": Vector2(float(m.pos[0]), float(m.pos[1])),
					"raio": float(m.get("raio", 600.0)),
					"forcar": int(m.get("forcar", 0)),
					"marca": str(m.get("marca", "")),
					"ordem": int(m.get("ordem", 0)),
					"nome": str(m.get("nome", "")),
					"texto": str(m.get("texto", "")),
					"exige": str(m.get("exige", "")),
					"tempo": float(m.get("tempo", 0.0)),
					"custo": int(m.get("custo", 0)),
					"t": 0.0,  # tempo de defesa já cumprido
					"onda": 0.0,  # segundos até a próxima onda da defesa
					"feito": false,
					"dentro": false,
				}
			)
		)


## O efeito de uma marca acontece quando o herói ENTRA no raio (não a cada quadro dentro dele).
func _checar_marcadores(dt: float) -> void:
	var hp: Vector2 = heroi.pos
	for m in _marcadores:
		var perto: bool = hp.distance_squared_to(m.pos) <= m.raio * m.raio
		if perto and not m.dentro:
			_tocar_marca(m)
		if perto and m.tipo == "defesa" and not m.feito:
			_defesa(m, dt)
		m.dentro = perto
	_dano_espinhos(dt)


## Espinhos: a zona (rect) que machuca e os caminhos de pedra seguros dentro dela. Os desenhos são polígonos criados uma vez, na montagem.
func _montar_espinhos(m: Dictionary) -> Dictionary:
	var visual := Node2D.new()
	visual.z_index = -95  # chão: abaixo dos decalques (-90), dos objetos e do herói
	no_mundo.add_child(visual)
	var zona := _rect(m.rect)
	var seguro: Array = []
	for s in m.get("seguro", []):
		var pedra := _rect(s)
		seguro.append(pedra)
		var poligono := Polygon2D.new()
		poligono.polygon = _cantos(pedra)
		poligono.color = Color(0.62, 0.6, 0.55, 0.9)
		visual.add_child(poligono)
	var espinhos := Polygon2D.new()
	espinhos.polygon = _cantos(zona)
	espinhos.color = Color(0.55, 0.12, 0.1, 0.45)
	visual.add_child(espinhos)
	return {"rect": zona, "seguro": seguro, "dano": float(m.get("dano", 6.0)), "t": 0.0, "visual": visual}


func _rect(a: Array) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


func _cantos(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Fora do caminho de pedra, quem está na zona apanha um tique a cada ESPINHOS_TIQUE_S.
func _dano_espinhos(dt: float) -> void:
	var hp: Vector2 = heroi.pos
	for z in _espinhos:
		if not z.rect.has_point(hp) or _em_algum(z.seguro, hp):
			z.t = 0.0
			continue
		z.t += dt
		if z.t >= ESPINHOS_TIQUE_S:
			z.t = 0.0
			heroi.levar_dano(z.dano, hp, null, false)  # ambiente: o escudo não barra (não há quem bateu)


func _em_algum(rects: Array, p: Vector2) -> bool:
	for r in rects:
		if r.has_point(p):
			return true
	return false


## Defesa de ponto: com o herói dentro do raio o tempo corre e surgem monstros em volta a cada DEFESA_ONDA_S; ao completar `tempo`, cai uma relíquia (baú).
func _defesa(m: Dictionary, dt: float) -> void:
	m.t += dt
	m.onda -= dt
	if m.onda <= 0.0:
		m.onda = DEFESA_ONDA_S
		for i in DEFESA_MONSTROS_POR_ONDA:
			var a := _rng.randf() * TAU
			nascer_monstro(_sorteia(TIPOS_MONSTRO, PESOS_MONSTRO), m.pos + Vector2(cos(a), sin(a)) * m.raio * 0.9, true)
	if m.t >= m.tempo:
		m.feito = true
		combate.baus.soltar(m.pos, 1.0, m.forcar)
		combate.anunciar("DEFESA CUMPRIDA", COR_ANUNCIO)


func _tocar_marca(m: Dictionary) -> void:
	match m.tipo:
		"bau":
			if not m.feito:
				combate.baus.soltar(m.pos, 1.0, m.forcar)
				m.feito = true
		"bau_trancado":
			if m.feito:
				return
			if _tem_chave:
				combate.baus.soltar(m.pos, 1.0, m.forcar)
				m.feito = true
			else:
				combate.anunciar("TRANCADO: a chave está numa ruína", COR_ANUNCIO)
		"chave":
			if not m.feito:
				m.feito = true
				_tem_chave = true
				combate.anunciar("CHAVE ENCONTRADA", COR_ANUNCIO)
		"fragmento":
			if m.feito:
				return
			m.feito = true
			_fragmentos += 1
			if _fragmentos < FRAGMENTOS_RELIQUIA:
				combate.anunciar("FRAGMENTO %d/%d" % [_fragmentos, FRAGMENTOS_RELIQUIA], COR_ANUNCIO)
			else:
				combate.anunciar("RELÍQUIA MONTADA!", COR_ANUNCIO)
				combate.baus.soltar(heroi.pos, 1.0, 3)
		"alavanca":
			if m.feito:
				return
			m.feito = true
			_alavancas += 1
			if _alavancas < 2:
				combate.anunciar("ALAVANCA 1/2: puxe a outra", COR_ANUNCIO)
			else:
				_atalho_aberto = true
				combate.anunciar("ATALHO ABERTO até o portão", COR_ANUNCIO)
		"pilar":
			if m.feito:
				return
			if m.ordem == _pilares_prox + 1:
				m.feito = true
				_pilares_prox += 1
				if _pilares_prox < PILARES:
					combate.anunciar("PILAR DO %s" % m.nome.to_upper(), COR_ANUNCIO)
				else:
					_pilares_ok = true
					combate.anunciar("OS PILARES ACORDARAM", COR_ANUNCIO)
			else:
				_pilares_prox = 0
				for p in _marcadores:
					if p.tipo == "pilar":
						p.feito = false
				combate.anunciar("ORDEM ERRADA: os pilares se apagam", COR_ANUNCIO)
		"placa":
			combate.anunciar(m.texto, COR_ANUNCIO)
		"defesa":
			if not m.feito:
				combate.anunciar("DEFESA: aguente %d s" % int(m.tempo), COR_ANUNCIO)
		"mirante":
			if not m.feito:
				m.feito = true
				minimapa.revelar_tudo()
				combate.anunciar("MIRANTE: o mapa inteiro se revela", COR_ANUNCIO)
		"portao":
			# só a missão por enquanto: a passagem física até o portão ainda não existe (LOGBOOK, Marco 4); entrar no raio cumpre e tira a seta
			m.feito = true
		"mercador":
			if m.feito:
				return
			if almas_partida < m.custo:
				combate.anunciar("MERCADOR: faltam %d almas" % (m.custo - almas_partida), COR_ANUNCIO)
				return
			m.feito = true
			_almas_gastas += m.custo
			combate.baus.soltar(m.pos, 1.0, m.forcar)
			combate.anunciar("MERCADOR: uma carta por %d almas" % m.custo, COR_ANUNCIO)
		"chefe":
			if m.feito or combate.chefes.atual != null:
				return
			if m.exige == "pilares" and not _pilares_ok:
				combate.anunciar("O CHEFE NÃO RESPONDE: ache os pilares", COR_ANUNCIO)
				return
			m.feito = true
			var mk := _marca_chefe(m.marca)
			if mk.is_empty():
				push_warning("v2 mapa: marca de chefe desconhecida: " + m.marca)
			else:
				combate.chefes.nascer(mk, m.pos)


## A marca de chefe (dados/v2_cartas.json, chefes.marcas) com este id; vazio se não existe.
func _marca_chefe(id: String) -> Dictionary:
	for mk in combate.chefes.cfg.marcas:
		if str(mk.id) == id:
			return mk
	return {}


## Um monstro novo do tipo `nome` (uma linha de números: quem o desenha é a horda). Só é chamado quando o pool do tipo esvazia.
func _novo_monstro(nome: String):
	var tp: Dictionary = sprites.tipo(nome)
	var mo := Monstro.new()
	mo.criar(self, no_mundo, nome, tp, Vector2.ZERO, _rng)
	mo.aplicar_stats(combate.cfg.monstros[nome])
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
	mo.aplicar_stats(combate.cfg.monstros[nome], k_vida * fator_pesadelo("vida_mult"), k_dano * fator_pesadelo("dano_mult"))
	mo.cacador = cacador
	mo.raio_vaga = 90.0
	mo.reviver(p)
	monstros.append(mo)
	return mo


## Multiplicador do modo Pesadelo (chave de dados/v2_meta.json, modos > pesadelo > regras); 1 quando o modo não está ligado.
func fator_pesadelo(chave: String) -> float:
	var r = meta_bonus.get("pesadelo")
	return float(r.get(chave, 1.0)) if r is Dictionary else 1.0


## A partida é no modo Pesadelo?
func pesadelo() -> bool:
	return meta_bonus.get("pesadelo") is Dictionary


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
	if horda != null and modo_teste == false:
		horda.atualizar(t, cam.retangulo(), quadros)  # mudou no menu de pausa: o lote já aparece no modo novo, sem esperar a partida andar
	# orçamento de luzes pelo perfil ("luz_relevo" da aba Gráficos): cada luz ligada custa GPU em tudo o que ela toca, e a iGPU do i5 é fraca
	var relevo := str(Config.g("luz_relevo"))
	luzes.orcamento = int(args.get("luzes", ORCAMENTO_LUZES.get(relevo, 0)))
	var nivel := str(args.get("particulas", Config.g("particulas_sim")))
	var f: Dictionary = Config.PART_NIVEL.get(nivel, {})
	atm.definir_fatores(float(f.get("amb_particulas", 1.0)), float(f.get("efe_particulas", 1.0)))
	if combate != null:
		combate.fx.fator_part = clampf(float(f.get("efe_particulas", 1.0)), 0.25, 1.0)


## Perfil Dinâmico (opção "qualidade_auto", aba Gráficos): fps abaixo de 40 por 8 s desce um perfil e fps firme por 30 s sobe um,
## só na memória. Config.g_perfil_temporario avisa a partida (graficos_mudou relê luzes e sombras) e o combate anuncia.
func _baixar_qualidade(dt: float, fps: float) -> void:
	if (
		not _qualidade_ligada
		or not bool(Config.v("qualidade_auto"))
		or combate == null
		or combate.jogo != "jogando"
		or combate.pausado
		or combate.pausado_mundo
		or get_tree().paused
	):
		_qualidade.interromper()  # cartas, baús e resultados têm FPS de tela estática; não contam nem somam trechos separados
		return
	var limite := int(Config.g("limite_fps"))
	var alvo := 55.0 if limite <= 0 or limite >= 60 else limite * 0.92  # com limite baixo de fps, "firme" é perto do limite
	var antes := Config.g_perfil()
	var nome := _qualidade.passo(dt, fps, antes, alvo)
	if nome == "":
		return
	Config.g_perfil_temporario(nome)
	var degrau := {"alto": "alta", "medio": "média", "baixo": "baixa"}
	if QualidadeAuto.DEGRAUS.find(nome) < QualidadeAuto.DEGRAUS.find(antes):
		combate.anunciar("FPS firme: qualidade gráfica %s" % degrau[nome], Color(0.6, 1, 0.6))
	else:
		combate.anunciar("FPS baixo: qualidade gráfica %s" % degrau[nome], Color(1, 0.8, 0.4))


# ------------------------------------------------------------------ movimento e mouse


## PONTO ÚNICO DE MOVIMENTO: o herói e os monstros pedem aqui o deslocamento que querem (`desejado`, em px) e é aqui que a colisão age
## (v2/colisao.gd: o corpo é um círculo de raio `a.raio` no chão; contra as elipses dos objetos ele é empurrado e desliza). Depois prende
## na área andável (o mapa menos "borda_andavel": as árvores das bordas fecham o mapa). Devolve o deslocamento que de fato aconteceu.
func mover(a, desejado: Vector2) -> Vector2:
	var antes: Vector2 = a.pos
	var depois := antes + desejado
	if desejado.length_squared() > MAX_PASSO_COLISAO * MAX_PASSO_COLISAO and Colisao.segmento_perto(antes, depois, a.raio):
		var n_passos := ceili(desejado.length() / MAX_PASSO_COLISAO)
		var passo := desejado / n_passos
		depois = antes
		for _i in n_passos:
			depois = Colisao.resolver(depois + passo, a.raio)
	else:
		depois = Colisao.resolver(depois, a.raio)
	depois = depois.clamp(limite_andavel.position, limite_andavel.end)
	a.definir_pos(depois)
	return depois - antes


## O mesmo `mover` para quem não é Ator (aliados, que guardam a posição num dicionário): devolve a nova posição de um corpo de raio
## `raio` que sai de `antes` e quer andar `desejado`, com as barreiras e a área andável. É uma cópia de `mover` de propósito: o herói e
## os monstros seguem com o código da main, sem uma chamada a mais por quadro.
func mover_ponto(antes: Vector2, desejado: Vector2, raio: float) -> Vector2:
	var depois := antes + desejado
	if desejado.length_squared() > MAX_PASSO_COLISAO * MAX_PASSO_COLISAO and Colisao.segmento_perto(antes, depois, raio):
		var n_passos := ceili(desejado.length() / MAX_PASSO_COLISAO)
		var passo := desejado / n_passos
		depois = antes
		for _i in n_passos:
			depois = Colisao.resolver(depois + passo, raio)
	else:
		depois = Colisao.resolver(depois, raio)
	return depois.clamp(limite_andavel.position, limite_andavel.end)


## Mouse nas coordenadas do mundo (a tela do mundo é 960x540 e a câmera já é inteira).
func mouse_mundo() -> Vector2:
	if mouse_forcado != null:
		return mouse_forcado
	if modo_teste or DisplayServer.get_name() == "headless":
		return heroi.pos + Heroi.CENTRO_CORPO + heroi.dir_olhar * 100.0
	return cam.centro_base() - Vector2(LARG, ALT) / 2.0 + ap.mouse_na_tela()


func _input(e: InputEvent) -> void:
	if status != null and status.entrada(e):  # C liga e desliga o card da build, também sobre a escolha de cartas e o baú (que comem as teclas)
		get_viewport().set_input_as_handled()
		return
	# ESC e Start (e toda a entrada com o menu aberto) já foram tratados pela Antena da pausa, que vem antes na ordem do _input
	if meta_res != null and meta_res.entrada(e):  # o resultado com as almas vem antes da tela de resultado (telas.gd)
		get_viewport().set_input_as_handled()
		return
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
		KEY_F3:
			_alternar_rotulo()
		KEY_F4:
			dbg_colisao.visible = not dbg_colisao.visible


# ------------------------------------------------------------------ quadro


func _process(delta: float) -> void:
	if picos != null:
		picos.quadro(self)
	var t0 := Time.get_ticks_usec()
	avancar(minf(delta, 0.1))
	if roteiro != null:
		var r0 := Time.get_ticks_usec()
		roteiro.atualizar(delta)
		_perfil("roteiro", Time.get_ticks_usec() - r0)  # o robô e os roteiros de teste (não é o jogo)
	_us_total += Time.get_ticks_usec() - t0
	if picos != null:
		picos.us_script += Time.get_ticks_usec() - t0
	if _rotulo != null and _rotulo.visible:
		_rotulo_t += delta
		if _rotulo_t > 0.3:
			_rotulo_t = 0.0
			_texto_rotulo()
	if modo_teste:
		return
	_baixar_qualidade(delta, Engine.get_frames_per_second())
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
			var p0 := Time.get_ticks_usec()
			if combate.dt_local > 0.0:
				heroi.atualizar(combate.dt_local)  # no solo é igual a dtm; hit-stop e câmera lenta locais não param o mundo
			var p1 := Time.get_ticks_usec()
			if herois.size() <= 1:  # solo: um alvo só, sem busca
				var hp: Vector2 = heroi.pos
				var hr: float = heroi.raio
				for mo in monstros:
					mo.atualizar(dtm, hp, hr)
			else:
				for mo in monstros:
					var alvo = alvo_mais_perto(mo.pos)
					mo.atualizar(dtm, alvo.pos, alvo.raio)
			var p2 := Time.get_ticks_usec()
			combate.atualizar(dtm)
			_checar_marcadores(dtm)
			braseiros.atualizar(dtm)
			var p3 := Time.get_ticks_usec()
			_perfil("heroi", p1 - p0)
			_perfil("monstros", p2 - p1)
			_perfil("combate", p3 - p2)
		var p4 := Time.get_ticks_usec()
		cam.seguir(heroi.pos + Heroi.CENTRO_CORPO + heroi.avanco_camera, dt)
		combate.efeitos(dt)
		_perfil("camera_efeitos", Time.get_ticks_usec() - p4)
	var p5 := Time.get_ticks_usec()
	var rect: Rect2 = cam.retangulo()
	atm.seguir(cam.position)
	cenario.atualizar_blocos(rect)
	var p6 := Time.get_ticks_usec()
	copas.atualizar(dt, cenario.ativos, heroi)
	oclusao.atualizar(dt, heroi, monstros)
	var p7 := Time.get_ticks_usec()
	luzes.atualizar(t, rect)
	_perfil("cenario_atm", p6 - p5)
	_perfil("copas", p7 - p6)
	_perfil("luzes", Time.get_ticks_usec() - p7)
	var p8 := Time.get_ticks_usec()
	var tela := rect.grow(MARGEM_SOMBRA)
	var com_sombra: bool = sombras.modo != Sombras.NENHUMA
	var estatica: bool = sombras.modo >= Sombras.MEDIA  # na baixa, o objeto parado só tem a mancha, que não muda
	var n := 0
	for a in cenario.ativos:
		var dentro := com_sombra and tela.has_point(a.pos)
		if dentro != a.ativo:
			sombras.ativar(a, dentro)
		n += 1
		if dentro and estatica and (n + quadros) % PASSO_SOMBRA_CENARIO == 0:  # cenário parado: só a luz muda, um terço por quadro
			sombras.atualizar(a, t)
	var movel: Array = [heroi]  # os atores com nós: o herói, as elites e os chefes (o resto da horda é do lote)
	for a in monstros:
		if not a.lote:
			movel.append(a)
	for a in movel:
		var dentro := com_sombra and tela.has_point(a.pos)
		if dentro != a.ativo:
			sombras.ativar(a, dentro)
			if a.olho != null:
				a.olho.visible = dentro
		if dentro:
			sombras.atualizar(a, t)
	_perfil("sombras_ativacao", Time.get_ticks_usec() - p8)
	var p9 := Time.get_ticks_usec()
	horda.atualizar(t, rect, quadros)
	_perfil("horda", Time.get_ticks_usec() - p9)


## Soma `us` microssegundos na parte `nome` do perfil (só vale a pena para a medição).
func _perfil(nome: String, us: int) -> void:
	perfil[nome] = int(perfil.get(nome, 0)) + us


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
	Meta.aplicar(self)
	cam.cravar(heroi.pos + Heroi.CENTRO_CORPO)
	_popular_inicial()
	if is_instance_valid(minimapa):
		minimapa.resetar()  # a névoa, os baús e as marcas da partida anterior (e o mirante) não valem para a nova
	if trilha != null:
		trilha.tocar("partida")


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
	_rotulo.visible = args.has("rotulo")  # desligado na partida normal: F3 liga e desliga (ou --rotulo já começa ligado)
	_texto_rotulo()


## F3: liga e desliga o texto de depuração (fps, atores na tela, luzes).
func _alternar_rotulo() -> void:
	if _rotulo == null:
		return
	_rotulo.visible = not _rotulo.visible
	_texto_rotulo()


func _texto_rotulo() -> void:
	_rotulo.text = (
		"sombra: %s   %d fps   atores na tela: %d   luzes ligadas: %d/%d\nWASD anda   mouse mira   1 baixa  2 media  3 alta  0 sem sombra   F4 colisão   Esc pausa"
		% [str(Sombras.NOMES[sombras.modo]).to_upper(), Engine.get_frames_per_second(), atores_ativos(), luzes.ligadas(), luzes.lista.size()]
	)


func _salvar_foto() -> void:
	var caminho := _fotos.path_join("%s.png" % str(args.get("nome", "v2")))
	var tam: Vector2i = await ap.foto(caminho)
	print("FOTO ", caminho, " ", tam, " t=%.2f heroi=%s cam=%s" % [t, str(heroi.pos), str(cam.position)])
	get_tree().quit()


## Tempo de CPU e de GPU do desenho (do mundo e da janela) e chamadas de desenho do quadro, somados na medição.
func _medir_render() -> void:
	var rid := sv.get_viewport_rid()
	var raiz := get_tree().root.get_viewport_rid()
	_r_acum[0] += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	_r_acum[1] += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	_r_acum[2] += RenderingServer.viewport_get_measured_render_time_cpu(raiz)
	_r_acum[3] += RenderingServer.viewport_get_measured_render_time_gpu(raiz)
	_r_acum[5] += RenderingServer.viewport_get_measured_render_time_cpu(ui.get_viewport_rid())
	_r_acum[6] += RenderingServer.viewport_get_measured_render_time_gpu(ui.get_viewport_rid())
	_r_acum[4] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func _medir() -> void:
	if t < _med["aquecer"]:
		_us_total = 0
		return
	if _med["inicio"] < 0.0:
		_med["inicio"] = t
		_us_total = 0
		sombras.us_script = 0
		combate.us_armas = 0
		combate.armas.us_desenho = 0
		perfil.clear()
		RenderingServer.viewport_set_measure_render_time(sv.get_viewport_rid(), true)
		RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(), true)
		RenderingServer.viewport_set_measure_render_time(ui.get_viewport_rid(), true)
		if args.has("ui_congelada"):  # experimento: o SubViewport da UI para de redesenhar (o teto do que "só redesenhar quando muda" pouparia)
			ui.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_med["frames"] = int(_med["frames"]) + 1
	_medir_render()
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
		print(
			(
				"SCRIPT ms/quadro=%.3f (sombras %.3f, golpes secundários %.3f, desenho deles %.3f)"
				% [
					_us_total / 1000.0 / frames,
					sombras.us_script / 1000.0 / frames,
					combate.us_armas / 1000.0 / frames,
					combate.armas.us_desenho / 1000.0 / frames
				]
			)
		)
		var partes := []
		for k in perfil:
			partes.append("%s %.2f" % [k, int(perfil[k]) / 1000.0 / frames])
		print("PERFIL ms/quadro: ", ", ".join(partes), " | horda: %d monstros em %d fatias" % [horda.n_lote, horda.n_fatias()])
		print(
			(
				"RENDER ms/quadro: cpu mundo %.2f, gpu mundo %.2f, cpu janela %.2f, gpu janela %.2f, cpu ui %.2f, gpu ui %.2f; chamadas de desenho %.0f; objetos %d; fora do script %.2f"
				% [
					_r_acum[0] / frames,
					_r_acum[1] / frames,
					_r_acum[2] / frames,
					_r_acum[3] / frames,
					_r_acum[5] / frames,
					_r_acum[6] / frames,
					_r_acum[4] / frames,
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
					dec * 1000.0 / frames - _us_total / 1000.0 / frames
				]
			)
		)
		print(
			(
				"COMBATE abates=%d maior_combo=%d nivel=%d vivos=%d ondas=%d tempo_partida=%.1f vida=%d melhorias=%s"
				% [abates, maior_combo, heroi.nivel, monstros.size(), combate.diretor.ondas, tempo_partida, heroi.vida, str(combate.progresso.melhorias)]
			)
		)
		get_tree().quit()

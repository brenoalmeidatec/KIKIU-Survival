extends Node2D
## Uma partida: junta jogador, vírus, armas, coleta, diretor, HUD e cartas.
## Também guarda os atributos do jogador (base + herói + passivos), o XP e o nível.

signal terminou(resumo: Dictionary)

const Jogador := preload("res://scripts/hordas/jogador.gd")
const Inimigos := preload("res://scripts/hordas/inimigos.gd")
const Armas := preload("res://scripts/hordas/armas.gd")
const Coleta := preload("res://scripts/hordas/coleta.gd")
const Efeitos := preload("res://scripts/hordas/efeitos.gd")
const Chao := preload("res://scripts/hordas/chao.gd")
const Diretor := preload("res://scripts/hordas/diretor_hordas.gd")
const Hud := preload("res://cenas/hud.tscn")
const Cartas := preload("res://scripts/hordas/cartas.gd")
const Duelo := preload("res://scripts/hordas/duelo.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
const Equipamento := preload("res://scripts/hordas/equipamento.gd")
const Online := preload("res://scripts/hordas/online.gd")
const Habilidades := preload("res://scripts/hordas/habilidades.gd")
const Especial := preload("res://scripts/hordas/especial.gd")
const Provisoes := preload("res://scripts/hordas/provisoes.gd")
const Ganchos := preload("res://scripts/hordas/ganchos.gd")
const Mochila := preload("res://scripts/hordas/mochila.gd")
const Calor := preload("res://scripts/hordas/calor.gd")
const Regioes := preload("res://scripts/hordas/regioes.gd")
const Conjuntos := preload("res://scripts/hordas/conjuntos.gd")
const Objetivos := preload("res://scripts/hordas/objetivos.gd")
const Saida := preload("res://scripts/hordas/saida.gd")
const TelaStatus := preload("res://scripts/hordas/tela_status.gd")
const CamadaObjetivos := preload("res://scripts/hordas/camada_objetivos.gd")
const MissaoChefe := preload("res://scripts/hordas/missao_chefe.gd")
const Descobertas := preload("res://scripts/hordas/descobertas.gd")
const Sorte := preload("res://scripts/hordas/sorte.gd")
const Resultado := preload("res://scripts/hordas/resultado.gd")
const Entradas := preload("res://scripts/hordas/entradas.gd")
const Abertura := preload("res://scripts/hordas/abertura.gd")
const Interface := preload("res://scripts/hordas/interface.gd")
const Mapa := preload("res://scripts/hordas/mapa.gd")
const MapaFase := preload("res://scripts/hordas/mapa_fase.gd")
const MapaFaseMundo := preload("res://scripts/hordas/mapa_fase_mundo.gd")
const TelaMapa := preload("res://scripts/hordas/tela_mapa.gd")
const Loja := preload("res://scripts/hordas/loja.gd")
const Escuridao := preload("res://scripts/hordas/escuridao.gd")
const Mortes := preload("res://scripts/hordas/mortes.gd")
const Finalizacao := preload("res://scripts/hordas/finalizacao.gd")

const Universais := preload("res://scripts/hordas/universais.gd")
const MAX_PASSIVOS := Construcao.MAX_PASSIVOS

var heroi_id := "hazaki"
var heroi: Dictionary
var bot := false

var jogador: Node2D
var inimigos: Node2D
var armas: Node2D
var habilidades: Node2D        # transformação (dragão do Hazaki), habilidades.gd
var especial: Node2D           # especial do herói (tecla E), especial.gd
var provisoes: Node            # mochila em ação: comida, amuleto e consumíveis (#72, marcos 3 e 4), provisoes.gd; null = sem mochila
var ganchos: Node              # regras próprias da raça/classe do herói (#72 marco 6), ganchos.gd; null = herói sem gancho
var mochila_cfg := {}          # a mochila que o herói leva (o main.gd põe antes de abrir a arena; no online, a que o anfitrião aceitou)
var descobertas: Node          # santuários, fragmentos, dádivas e eventos (#21), descobertas.gd
var semente := 0               # semente da corrida (0 = sorteia; no online vem do anfitrião, igual pra todos)
var coleta: Node2D
var efeitos: Node2D
var mortes: Node2D            # mortes violentas (mortes.gd)
var finalizacao: Node2D       # finalização de chefe (finalizacao.gd)
var chao: Node2D
var diretor
var hud: CanvasLayer
var cartas: CanvasLayer
var camera := Camera2D.new()
var duelo: Node2D
var duelo_ativo := false
var pre_duelo := false       # o chefe final caiu e o duelo ainda não começou
var entre_fases := false     # a fase acabou: descanso, baú e escolha antes da próxima
var eh_online := false       # partida online (main.gd liga antes de abrir a arena)
var online: Node             # online.gd, só no online
var caido := false           # online: caiu na horda e espera alguém levantar

var passivos := {}          # id -> nível
var equipamentos := {}      # slot -> id do equipamento vestido (aparece no personagem; veja equipamento.gd)
var _stats := {}
var xp := 0.0
var nivel := 1
var abates := 0
var _niveis_pendentes := 0
var _cartas_tomada := 0
var dano_por_arma := {}
var fase_stat := _stat_novo()  # números DESTA fase (zera a cada fase; a tela de resultados mostra isso)
var resultado: CanvasLayer     # tela de resultados da fase (resultado.gd)
var entradas: CanvasLayer      # entrada dos personagens e do chefe (entradas.gd)
var abertura: CanvasLayer      # abertura cinematográfica da fase (abertura.gd, dados/entrada.json)
var com_abertura := false      # o main.gd liga numa partida de verdade (ou com --entrada); robô, testes e capturas ficam sem
var escuridao: CanvasLayer     # escuridão da fase de horror (escuridao.gd)
var mapa: Dictionary            # mapa de progressão da corrida (mapa.gd), igual em todos os clientes (mesma semente)
var mapa_pos := Vector2i(0, 0)  # nó atual: x = andar (0 = fase 1), y = faixa
var mapa_fase_mundo: Node2D     # mapa fechado do andar atual (mapa_fase_mundo.gd, #128); null sem regiões
var _deslize := Vector2.ZERO    # embalo no gelo fino: o herói escorrega um pouco depois de soltar o movimento (#128)
var mapa_trilha: Array = []     # nós já percorridos (Vector2i)
var tela_mapa: CanvasLayer      # tela do mapa (tela_mapa.gd)
var loja: CanvasLayer           # loja do mapa (loja.gd)
var ouro := 0                   # moeda da corrida: 1 por abate (dados/mapa.json), gasta na loja
var no_tipo := "fase"           # tipo do nó em que o grupo está
var _no_seq := 0                # conta os nós escolhidos: a resolução atrasada de um nó antigo se descarta
var dano_recebido := {}     # de quem o jogador apanhou (pra equilibrar)
var resortear := 3          # cargas de "sortear de novo", "pular" e "banir" (dados/corrida.json > cartas)
var pular := 2
var banir := 2
var calor := {}             # modificadores de calor desta corrida {id: nível} (calor.gd, dados/calor.json)
var calor_ef := {}          # efeitos somados do calor (ef() lê)
var calor_pts := 0
var conj_contagem := {}     # etiquetas da build (#63): {etiqueta: quantos itens} (conjuntos.gd)
var conj_resumo: Array = [] # o que o HUD e a tela de fim mostram (Conjuntos.resumo)
var _conj_ef := {}          # comportamentos ligados pelos conjuntos (conj() lê)
var _conj_bonus := {}       # atributos que os conjuntos somam
var _conj_explodindo := false
var objetivo: Node2D        # objetivo próprio do andar (objetivos.gd)
var saida: Node2D           # portal de saída da fase (saida.gd, #112)
var tela_status: CanvasLayer  # Tab / Back: inventário e status (tela_status.gd, #125)
var camada_objetivos: CanvasLayer  # efeitos a 40% em cima de alvo e seta do portal (camada_objetivos.gd, #125)
var missao: Node2D          # missão que chama o chefe da fase (missao_chefe.gd, #112)
var _saida_pedida := false  # online: o anfitrião já mandou abrir a saída deste andar
var fases_corrida: Array = []   # regiões (#64): as fases da corrida inteira, na ordem dos andares (regioes.gd)
var banidos := {}           # id -> true: carta banida some do sorteio até o fim da corrida
var tempo_arma := {}        # id -> segundos com a arma ativa (DPS da tela final)
var nivel_arma := {}        # id -> último nível visto (tela final)
var acabou := false
var _tremor := 0.0
const OLHAR_MAX := 36.0          # px que a câmera adianta na direção em que o herói anda (#68)
var _olhar := Vector2.ZERO      # quanto ela está adiantada agora (vai até lá com suavidade)
var _hitstop_ate := 0   # Time.get_ticks_msec() até quando o jogo fica "congelado" (só solo)
var _hitstop_crit_ate := 0
var _golpe_ate := 0       # Time.get_ticks_msec() até quando um golpe corpo a corpo não treme/congela de novo
var _impacto_arma := {}   # arma -> se o acerto dela solta estrela de impacto (cache)
const SEM_IMPACTO := ["poca", "aura", "aura_energia", "baforada"]   # dano contínuo: estrela a cada tique vira ruído
const GOLPE_ESPERA := 0.3  # s mínimos entre dois "golpes pesados" (tremidinha + congelada do corpo a corpo)
var _chefes_vivos := []
var perfil := [0, 0, 0, 0]   # microssegundos: jogador+diretor, inimigos, armas, resto


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if semente == 0:
		semente = Sorte.nova_semente()
	Sorte.iniciar(semente)   # tudo que afeta o mundo compartilhado sai das streams dessa semente (sorte.gd)
	if Regioes.ativo():      # regiões (#64): a corrida inteira sorteada agora, igual em todos os clientes
		fases_corrida = Regioes.gerar_fases(Sorte.fluxo("regioes"))
	mapa = Mapa.gerar()      # stream "mapa": mesma semente, mesmo mapa em todos os clientes
	mapa_pos = Vector2i(0, Mapa.inicio(mapa))
	mapa_trilha = [mapa_pos]
	heroi = Dados.json("herois").get(heroi_id, {})
	var cc: Dictionary = Dados.json("corrida").get("cartas", {})   # cargas de sortear de novo / pular / banir
	resortear = int(cc.get("resortear", 3))
	pular = int(cc.get("pular", 2))
	banir = int(cc.get("banir", 2))
	calor = Calor.validar(calor)      # o main.gd põe a escolha antes de abrir a arena (no online, a do anfitrião)
	calor_ef = Calor.efeitos(calor)
	calor_pts = Calor.pontos(calor)
	if ef("sem_cartas") > 0.0:          # "Destino Selado": sem sortear de novo e sem pular
		resortear = 0
		pular = 0
	chao = Chao.new()
	chao.arena = self
	add_child(chao)
	objetivo = Objetivos.new()   # objetivo do andar (#63): desenha a pira no chão, embaixo de tudo
	objetivo.arena = self
	add_child(objetivo)
	missao = MissaoChefe.new()
	missao.arena = self
	add_child(missao)
	saida = Saida.new()
	saida.arena = self
	add_child(saida)
	coleta = Coleta.new()
	coleta.arena = self
	add_child(coleta)
	armas = Armas.new()
	armas.arena = self
	inimigos = Inimigos.new()
	inimigos.arena = self
	add_child(inimigos)
	mortes = Mortes.new()
	mortes.arena = self
	inimigos.mortes = mortes
	add_child(mortes)
	jogador = Jogador.new()
	jogador.arena = self
	jogador.bot = bot
	add_child(jogador)
	add_child(armas)
	armas.dono = jogador
	armas.campo = inimigos
	armas.statf = stat
	habilidades = Habilidades.new()
	add_child(habilidades)
	descobertas = Descobertas.new()
	add_child(descobertas)
	descobertas.iniciar(self)
	habilidades.configurar(self)
	especial = Especial.new()
	add_child(especial)
	especial.configurar(self)
	if not Mochila.vazio(mochila_cfg):   # heróis fixos e corridas de teste sem mochila: nada muda
		provisoes = Provisoes.new()
		add_child(provisoes)
		provisoes.configurar(self, mochila_cfg)
	var gs: Array = Ganchos.de_heroi(heroi_id)   # raça/classe com gancho (#72 marco 6); herói fixo ou save antigo: nenhum
	if not gs.is_empty() or (eh_online and Ganchos.cliente_com_aura()):   # o anfitrião aplica as auras dos clientes mesmo sem gancho dele
		ganchos = Ganchos.new()
		add_child(ganchos)
		ganchos.configurar(self, gs)
	efeitos = Efeitos.new()
	add_child(efeitos)
	finalizacao = Finalizacao.new()
	finalizacao.arena = self
	add_child(finalizacao)
	duelo = Duelo.new()
	duelo.arena = self
	add_child(duelo)
	add_child(camera)
	camera.make_current()
	if eh_online:
		online = Online.new()
		online.arena = self
		add_child(online)
		inimigos.online = online
		inimigos.espelho = Rede.cliente()
	diretor = Diretor.new()
	diretor.iniciar(self)
	missao.nova_fase(diretor.fases()[0], 0)   # missão do chefe do primeiro andar (os outros começam em _iniciar_andar)
	_atualizar_calor()
	_recalcular()
	jogador.configurar(str(heroi.get("sprite", heroi_id)))
	var tom: Array = heroi.get("tom", [1.0, 1.0, 1.0])   # herói criado (#72): a raça tinge o corpo
	jogador.tom = Color(float(tom[0]), float(tom[1]), float(tom[2]))
	jogador.paleta = heroi.get("paleta", {})   # herói criado (#72, marco 2): pele, cabelo e roupa da ficha
	atualizar_visual.call_deferred()   # personagem em camadas: cabelo e arma inicial
	jogador.hp = stat("vida_max")
	armas.adicionar(str(heroi.get("arma", "pendrive")))
	_montar_mapa_fase()
	chao.criar_santuarios()
	hud = Hud.instantiate()
	hud.arena = self
	add_child(hud)
	tela_status = TelaStatus.new()
	tela_status.arena = self
	add_child(tela_status)
	camada_objetivos = CamadaObjetivos.new()
	camada_objetivos.arena = self
	add_child(camada_objetivos)
	cartas = Cartas.new()
	cartas.arena = self
	add_child(cartas)
	resultado = Resultado.new()
	resultado.arena = self
	add_child(resultado)
	tela_mapa = TelaMapa.new()
	tela_mapa.arena = self
	add_child(tela_mapa)
	loja = Loja.new()
	loja.arena = self
	add_child(loja)
	entradas = Entradas.new()
	entradas.arena = self
	add_child(entradas)
	abertura = Abertura.new()
	abertura.arena = self
	add_child(abertura)
	add_child(preload("res://scripts/hordas/vinheta.gd").new())
	escuridao = Escuridao.new()   # fase de horror: só liga quando a fase tem "escuro" em corrida.json
	escuridao.arena = self
	add_child(escuridao)
	_zerar_fase_stat()
	Som.musica(_nome_musica(diretor.fases()[0].get("musica", Dados.json("fase").get("musica", "minijogo_tenso")), 0))
	var f0: Dictionary = diretor.fases()[0]
	camera.position = jogador.centro()
	_comeco_de_fase(0, "")   # abertura cinematográfica (ou, sem ela, o anúncio e o herói "cai" no começo da fase 1)


func _exit_tree() -> void:
	if entradas:
		entradas.restaurar_tempo()   # o slow-motion da entrada do chefe nunca pode ficar preso
	if finalizacao:
		finalizacao.restaurar()      # idem a câmera lenta e o zoom da finalização de chefe
	if is_inside_tree():
		get_tree().paused = false   # arena fechada com carta/mapa/loja aberta não deixa o jogo pausado


func jogadores() -> int:
	return maxi(1, Rede.jogadores.size()) if eh_online else 1


func stat(k: String) -> float:
	var v := float(_stats.get(k, Construcao.BASE.get(k, 0.0)))
	if habilidades:
		v += habilidades.bonus(k)   # transformado (dragão): mais rápido e mais forte
	if especial:
		v += especial.bonus(k)   # depois do especial (ex.: o "Sou Gostoso!" do Hazaki)
	if provisoes:
		v += provisoes.bonus(k)   # comida de viagem, amuleto e poções (#72)
	if ganchos:
		v += ganchos.bonus(k)   # fúria, regeneração no escuro... (#72 marco 6)
	if duelo_ativo:
		# no duelo: a vida vem da regra do pvp.json, a regeneração é menor e a aura de lentidão pega
		if k == "vida_max":
			return duelo.hp_pvp(v)
		elif k == "regen":
			return v * duelo.regen_mult
		elif k == "velocidade" and duelo.lut_jogador.lento > 0:
			return v * 0.55
	# calor (#63): só na horda; o duelo entre pessoas não leva calor
	if k == "xp":
		v += calor_pts * Calor.recompensa("xp")      # cada ponto de calor rende mais XP
	elif k == "vida_max":
		v *= maxf(0.2, 1.0 + ef("vida_heroi"))       # "Corpo Frágil"
	elif k == "regen":
		v *= maxf(0.0, 1.0 + ef("cura"))             # "Feridas Abertas"
	return v


## Efeito de comportamento ligado pelos conjuntos de etiquetas (0 se nenhum degrau o liga). Veja dados/conjuntos.json.
func conj(k: String) -> float:
	return float(_conj_ef.get(k, 0.0))


## Recontagem das etiquetas (chamada a cada mudança de build: armas.adicionar/trocar, passivo, equipamento).
func _conj_atualizar() -> void:
	var ids: Array = armas.lista.map(func(a): return a.id) if armas else []
	conj_contagem = Conjuntos.contar(ids, passivos, equipamentos)
	_conj_bonus = Conjuntos.bonus(conj_contagem)
	_conj_ef = Conjuntos.efeitos(conj_contagem)
	conj_resumo = Conjuntos.resumo(conj_contagem)


## Armas.adicionar/trocar avisam aqui: a etiqueta da arma nova (ou evoluída) liga ou desliga o conjunto na hora.
func build_mudou() -> void:
	if descobertas and jogador:
		_recalcular()


## Efeito somado do calor desta corrida (0 se o jogador não ligou o modificador). Veja dados/calor.json.
func ef(k: String) -> float:
	return float(calor_ef.get(k, 0.0))


func _recalcular() -> void:
	var antes := stat("vida_max")
	_conj_atualizar()
	var extra: Dictionary = descobertas.bonus().duplicate() if descobertas else {}
	for k in _conj_bonus:   # conjuntos de etiquetas (#63) somam junto das dádivas
		extra[k] = float(extra.get(k, 0.0)) + float(_conj_bonus[k])
	_stats = Construcao.stats(heroi, passivos, equipamentos, extra)
	if inimigos:
		inimigos.elementos.recalcular(_stats)   # el_<elemento>: chance por golpe de pôr acúmulos (#72)
	if jogador and stat("vida_max") > antes:
		jogador.curar(stat("vida_max") - antes)


func _process(dt: float) -> void:
	if acabou:
		return
	dt = minf(dt, 1.0 / 30.0)
	if Time.get_ticks_msec() < _hitstop_ate:   # hitstop: tempo real, não depende de Engine.time_scale
		dt *= Jogador.HITSTOP_ESCALA
	var t0 := Time.get_ticks_usec()
	var parado: bool = caido or (duelo_ativo and (duelo.estado == "contagem" or not duelo.lut_jogador.vivo)) or abertura.heroi_preso()
	var mundo_espera: bool = abertura.mundo_preso()   # abertura da fase: diretor, inimigos e relógio esperam (todos os clientes, mesma duração)
	if eh_online and cartas.aberto():
		jogador.invencivel = maxf(jogador.invencivel, 0.1)   # no online o jogo não pausa: escolhendo carta, não apanha
	if not parado:
		var antes := jogador.position
		jogador.atualizar(dt)
		if mapa_fase_mundo and not duelo_ativo:
			mapa_fase_mundo.prender(jogador, antes)   # parede do mapa fechado (#128): o herói não atravessa
			var dps: float = mapa_fase_mundo.dano_seg_em(jogador.position + MapaFaseMundo.PES)   # espinho, veneno, lodo, gelo (#128)
			if dps > 0.0 and jogador.hp > 0.0:
				jogador.dano_direto(dps * dt, "chao")   # o chão machuca por segundo; sem invencibilidade nem som a cada quadro
			# gelo fino ('e', #128): o herói segue por um tempo no embalo do último passo, sem mexer em jogador.gd
			if mapa_fase_mundo.chao_em(jogador.position + MapaFaseMundo.PES) == "e":
				var andou := jogador.position - antes
				if andou.length_squared() > 0.01:
					_deslize = andou
				else:
					_deslize *= pow(0.9, dt * 60.0)   # perde embalo aos poucos
				if _deslize.length_squared() > 0.01:
					var antes_d := jogador.position
					jogador.position += _deslize
					mapa_fase_mundo.prender(jogador, antes_d)
					if jogador.position == antes_d:
						_deslize = Vector2.ZERO   # bateu na parede: para
			else:
				_deslize = Vector2.ZERO
	elif caido:
		jogador.queue_redraw()
	if duelo_ativo:
		duelo.atualizar(dt)
	elif not pre_duelo and not entre_fases and not mundo_espera:
		if inimigos.espelho:
			diretor.so_relogio(dt)   # cliente: quem cria os vírus é o anfitrião
		else:
			diretor.atualizar(dt)
		objetivo.atualizar(dt)
		missao.atualizar(dt)
	var t1 := Time.get_ticks_usec()
	if not duelo_ativo and not pre_duelo and not entre_fases and not mundo_espera:
		inimigos.atualizar(dt, jogador)
	var t2 := Time.get_ticks_usec()
	if not parado:
		habilidades.atualizar(dt)
		especial.atualizar(dt)
		if provisoes:
			provisoes.atualizar(dt)
		if ganchos:
			ganchos.atualizar(dt)
		descobertas.atualizar(dt)
		armas.atualizar(dt)
	if online:
		online.atualizar(dt)
	for a in armas.ativas():   # tempo e nível de cada arma, pro DPS da tela final (poucas armas: custo desprezível)
		tempo_arma[a.id] = float(tempo_arma.get(a.id, 0.0)) + dt
		nivel_arma[a.id] = a.nivel
	var t3 := Time.get_ticks_usec()
	if mapa_fase_mundo:
		mapa_fase_mundo.marcar_heroi(jogador.position)
	coleta.atualizar(dt)
	efeitos.atualizar(dt)
	_luzes_quadro()
	mortes.atualizar(dt)
	chao.atualizar(dt)
	hud.atualizar(dt)
	var t4 := Time.get_ticks_usec()
	perfil = [t1 - t0, t2 - t1, t3 - t2, t4 - t3]
	_tremor = maxf(0.0, _tremor - dt * 20.0)
	# a câmera olha um pouco à frente pra onde o herói anda (#68), com suavidade; dá pra desligar nas Opções
	var olhar_alvo: Vector2 = (jogador._vel * 0.22).limit_length(OLHAR_MAX) if Config.v("camera_frente") else Vector2.ZERO
	_olhar = _olhar.lerp(olhar_alvo, minf(1.0, dt * 2.5))
	var foco: Vector2 = duelo.centro if duelo_ativo and not duelo.lut_jogador.vivo else jogador.centro() + _olhar
	camera.position = finalizacao.camera(entradas.camera(abertura.camera(foco)))   # a entrada do chefe leva a câmera até ele e traz de volta; a finalização aproxima
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _tremor


# ---------- mapa fechado (#128) ----------

## Mapa fechado do andar atual: com regiões, cada andar tem o seu (mapa_fase.gd). O herói nasce no começo do mapa, em (0, 0).
func _montar_mapa_fase() -> void:
	if not Regioes.ativo() or diretor == null:
		return
	var fs: Array = diretor.fases()
	var f: Dictionary = fs[clampi(diretor.fase_idx, 0, fs.size() - 1)]
	var m := MapaFase.gerar(str(Regioes.regiao(int(f.get("regiao", 0))).get("id", "")), int(f.get("andar_regiao", 0)))
	if not m.get("ok", false):
		return
	if mapa_fase_mundo == null:
		mapa_fase_mundo = MapaFaseMundo.new()
		add_child(mapa_fase_mundo)
	mapa_fase_mundo.configurar(m)
	jogador.position = Vector2.ZERO


# ---------- chamados pelos outros ----------

func tremer(forca: float) -> void:
	_tremor = maxf(_tremor, forca * float(Config.v("tremor")))


func mensagem(txt: String, cor := Color.WHITE) -> void:
	hud.mensagem(txt, cor)


func anunciar(txt: String, cor := Color.WHITE) -> void:
	hud.anunciar(txt, cor)


## Soma o dano nas contas da partida (por arma e do andar) sem número nem som: o dano de elemento (#72) entra por aqui.
func creditar_dano(arma: String, valor: float) -> void:
	if arma != "":
		dano_por_arma[arma] = float(dano_por_arma.get(arma, 0.0)) + valor
		var d: Dictionary = fase_stat.dano
		d[arma] = float(d.get(arma, 0.0)) + valor


func registrar_dano(arma: String, valor: float, pos: Vector2, crit := false) -> void:
	creditar_dano(arma, valor)
	if ganchos:
		ganchos.ao_acertar(valor)   # roubo de vida (#72 marco 6)
	efeitos.numero(pos, valor, Color.WHITE, crit)
	if _tem_impacto(arma):
		efeitos.impacto(pos + Vector2(0, -6), Color(1.0, 0.8, 0.35) if crit else Color(0.7, 0.85, 1.0), crit)
	Som.tocar("acerto", 0.07, randf_range(0.9, 1.2), -14)
	if crit and Time.get_ticks_msec() >= _hitstop_crit_ate:
		_hitstop_crit_ate = Time.get_ticks_msec() + int(Jogador.HITSTOP_CRIT_ESPERA * 1000.0)
		hitstop(Jogador.HITSTOP_CRIT)


## Luz do quadro (estilo Dimraeth: o que brilha acende o chão em volta). Halos aditivos baratos no efeitos.gd, sem Light2D:
## o herói leva uma luz quente (mais forte quanto mais escuro o andar), os projéteis dele a cor da arma e os tiros
## dos inimigos um vermelho que ajuda a ver o perigo no escuro.
const LUZ_HEROI := Color(1.0, 0.82, 0.55)
const LUZ_TIRO := Color(1.0, 0.25, 0.15, 0.45)
var _cor_luz_arma := {}

func _luzes_quadro() -> void:
	if jogador and jogador.visible:
		var amb: float = chao._ambiente.color.v if chao and "_ambiente" in chao else 1.0
		efeitos.luz(jogador.centro() + Vector2(0, 10), 78.0, Color(LUZ_HEROI, clampf(0.06 + (1.0 - amb) * 0.5, 0.06, 0.3)))
	if armas:
		for p in armas.projeteis:
			if not _cor_luz_arma.has(p.arma):
				_cor_luz_arma[p.arma] = Color(armas.cor_de(Dados.item(str(p.arma)), Color(1.0, 0.85, 0.6)), 0.3)
			efeitos.luz(p.pos, 26.0, _cor_luz_arma[p.arma])
	if inimigos:
		for t in inimigos.tiros:
			efeitos.luz(t.pos, 22.0, LUZ_TIRO)


func _tem_impacto(arma: String) -> bool:
	if not _impacto_arma.has(arma):
		_impacto_arma[arma] = arma == "" or not str(Dados.item(arma).get("tipo", "")) in SEM_IMPACTO
	return _impacto_arma[arma]


## Golpe corpo a corpo do herói que acertou (armas.gd golpe_acertou): tremidinha e congelada bem curta, no máximo
## uma a cada GOLPE_ESPERA (com duas armas de corpo a corpo, congelar em todo golpe cansa).
func golpe_pesado(forca: float) -> void:
	var agora := Time.get_ticks_msec()
	if agora < _golpe_ate:
		return
	_golpe_ate = agora + int(GOLPE_ESPERA * 1000.0)
	tremer(1.2 * forca)
	hitstop(Jogador.HITSTOP_GOLPE * minf(forca, 1.5))


## Congela o jogo por `seg` segundos REAIS (Time.get_ticks_msec, ignora Engine.time_scale). Só no solo, e só pra crítico e chefe
## (hitstop em tudo cansa). O teto é o do HITSTOP_CHEFE.
func hitstop(seg: float) -> void:
	if eh_online or acabou:
		return
	_hitstop_ate = maxi(_hitstop_ate, Time.get_ticks_msec() + int(minf(seg, Jogador.HITSTOP_CHEFE) * 1000.0))


func inimigo_morreu(v) -> void:
	recompensa(v.pos, v.tipo, v.elite)
	objetivo.abate(v)   # totem ou fugitivo do objetivo do andar (#63)
	habilidades.abate(v)   # enche a Energia da transformação
	if v.chefe:
		hitstop(Jogador.HITSTOP_CHEFE)
	if online:
		online.morreu(v)   # anfitrião: cada um dos outros pega a própria recompensa
	if v.d.get("final", false):
		if online:
			Rede.evento("tela_azul_caiu")
		else:
			tela_azul_caiu()
	elif v.chefe and diretor.final_chamado and v.tipo == diretor.chefe_fase:
		# #112: o chefe morrer não leva mais pra próxima fase; abre-se a saída e o jogador sai quando quiser
		if online:
			if not _saida_pedida:
				_saida_pedida = true
				Rede.evento("saida_aberta", {"x": v.pos.x, "y": v.pos.y})   # só o anfitrião manda; todos abrem o portal no mesmo lugar
		else:
			abrir_saida(v.pos)


## Abre o portal de saída onde o chefe caiu e deixa a horda mais leve. A fase acaba quando o jogador entra nele (saida.gd).
func abrir_saida(p: Vector2) -> void:
	if saida.aberta or entre_fases or acabou:
		return
	fase_stat.tempo = diretor.t_fase   # o tempo da fase para de contar aqui; ficar coletando depois não pesa
	diretor.saida_leve = true
	if mapa_fase_mundo:
		p = mapa_fase_mundo.portal_mundo()   # o portal fica no centro do pátio do portão (mapa fechado, #128)
	saida.abrir(p)
	anunciar("CHEFE DERROTADO!", Color(1, 0.9, 0.4))
	mensagem("Entre no portal e segure CONFIRMAR para sair", Color(0.75, 0.65, 1))
	Som.tocar("vitoria", 0.1, 1.0, -8)
	tremer(4)


## O que cada jogador ganha quando um vírus morre: abate, gema de XP, efeito e sorteio de drop
## (no online cada um sorteia o seu, então XP, baú e tomada são pessoais).
func recompensa(pos: Vector2, tipo: String, elite: bool) -> void:
	var d: Dictionary = Dados.json("inimigos").get(tipo, {})
	var chefe := bool(d.get("chefe", false))
	abates += 1
	var og: Dictionary = Mapa.cfg().get("ouro", {})
	var ganho: int = int(og.get("chefe", 40)) if chefe else (int(og.get("elite", 4)) if elite else int(og.get("abate", 1)))
	ouro += int(round(ganho * (1.0 + calor_pts * Calor.recompensa("ouro")) * diretor.mult_ouro()))   # prorrogação (#112): cada degrau paga mais   # cada ponto de calor rende mais ouro
	fase_stat.abates += 1
	if chefe:
		fase_stat.chefes += 1
	var xp_v: float = float(d.get("xp", 1)) * diretor.xp_mult
	if elite:
		xp_v *= 6.0
	coleta.gema(pos, xp_v)
	var cor := Color(1, 0.85, 0.3) if elite else Color(0.55, 0.9, 0.4)
	if tipo in ["trojan", "trojan_gigante"]:
		cor = Color(0.65, 0.4, 0.85)
	elif tipo in ["ransomware"]:
		cor = Color(0.9, 0.3, 0.3)
	if d.get("cor_morte") is Array:
		cor = Color(d.cor_morte[0], d.cor_morte[1], d.cor_morte[2])
	efeitos.explodir(pos, cor, 14 if chefe else 5, 160.0 if chefe else 80.0)
	_conj_ao_abater(pos)
	var drops: Dictionary = Dados.json("fase").get("drops", {})
	var sd := Sorte.fluxo("drop")   # drops saem de uma stream: com a mesma semente e os mesmos abates, caem iguais
	if d.get("bau", false) or (elite and sd.randf() < 0.25):
		coleta.soltar(pos, "bau")
	elif sd.randf() < float(drops.get("marmita", 0.004)):
		coleta.soltar(pos, "marmita")
	elif sd.randf() < float(drops.get("wifi", 0.0015)):
		coleta.soltar(pos, "wifi")
	if elite:
		descobertas.elite_morreu(pos)   # fragmento da transformação, com pity
	if chefe:
		tremer(8)
		Som.tocar("soco", 0.1, 0.7)


## Comportamentos dos conjuntos de etiquetas (#63) a cada abate (cada jogador roda o seu: no online vale a build de quem vê).
func _conj_ao_abater(pos: Vector2) -> void:
	var cura := conj("cura_abate")
	if cura > 0.0 and jogador and not caido and not duelo_ativo:
		jogador.curar(cura)
	if conj("explosao_morte") > 0.0 and not _conj_explodindo and not duelo_ativo:
		_conj_explodindo = true   # a explosão não encadeia outra explosão (e não vira laço no 500 de estresse)
		var dano := 6.0 * stat("dano") * (1.0 + 0.08 * nivel)
		var n := 0
		for v in inimigos.no_circulo(pos, 54.0):
			if v.hp > 0.0:
				inimigos.ferir(v, dano, (v.pos - pos).normalized() * 60.0)
				n += 1
				if n >= 8:
					break
		efeitos.explodir(pos, Color(1.0, 0.5, 0.15), 6, 70.0)
		_conj_explodindo = false


## O chefe final caiu: limpa a tela e, depois de 2 s, começa o duelo (no online quem decide é o anfitrião).
func tela_azul_caiu() -> void:
	if pre_duelo or duelo_ativo or acabou:
		return
	if not bool(Dados.json("pvp").get("ativo", true)):
		_fim(true)
		return
	anunciar("%s caiu..." % nome_chefe_final(), Color(0.6, 0.8, 1))
	pre_duelo = true
	if caido:
		levantar(1.0)
	for o in inimigos.lista.duplicate():
		efeitos.explodir(o.pos, Color(0.5, 0.8, 0.4), 4, 100.0)
	inimigos.limpar()
	await get_tree().create_timer(2.0, true, false, true).timeout
	await _esperar_cartas()
	if acabou:
		return
	if not eh_online:
		iniciar_duelo()
	elif Rede.anfitriao():
		if Rede.jogadores.size() < 2:
			iniciar_duelo()   # ficou sozinho na sala: duelo contra robôs, como no solo
		else:
			var c: Vector2 = jogador.position.snapped(Vector2(32, 32))
			Rede.evento("duelo_iniciar", {"cx": c.x, "cy": c.y, "ang": randf() * TAU, "ordem": Rede.jogadores.keys()})


## Online: todo mundo caiu ao mesmo tempo.
func fim_corrida() -> void:
	if not acabou:
		_fim(false)


func anunciar_todos(txt: String, cor := Color.WHITE) -> void:
	anunciar(txt, cor)
	if online and Rede.anfitriao():
		Rede.evento("anuncio", {"txt": txt, "cor": cor.to_html()})


func chefe_final_chegou(final := true, tipo := "") -> void:
	_musica_da_fase(true)
	if online and Rede.anfitriao():
		Rede.evento("chefe_final", {"final": final, "chefe": tipo})
	if Dados.json("inimigos").get(tipo, {}).get("chefe", false):   # só vale chefe que existe nos dados
		entradas.chefe(tipo)
	if final:
		hud.mensagem("Derrote %s pra vencer!" % nome_chefe_final(true), Color(0.6, 0.75, 1))
	else:
		hud.mensagem("Derrote o chefe pra fechar a fase!", Color(1, 0.75, 0.6))


## Nome do chefe final da corrida (o chefe da última fase): os textos não dependem de quem ele é.
## no_meio: artigo em minúscula, pro meio da frase ("Derrote o Soberano do Caos", não "Derrote O Soberano").
func nome_chefe_final(no_meio := false) -> String:
	var fs: Array = diretor.fases()
	var id := str(fs[fs.size() - 1].get("chefe", "")) if fs.size() > 0 else ""
	var nome := str(Dados.json("inimigos").get(id, {}).get("nome", "o chefe final"))
	if no_meio and (nome.begins_with("O ") or nome.begins_with("A ")):
		nome = nome[0].to_lower() + nome.substr(1)
	return nome


## Espera as escolhas de carta (nível, tomada, baú) acabarem, sem perder nenhuma.
func _esperar_cartas() -> void:
	await get_tree().process_frame
	while not acabou and (cartas.aberto() or _niveis_pendentes > 0 or _cartas_tomada > 0):
		await get_tree().process_frame


## O chefe da fase caiu: limpa a tela, junta o XP, dá um baú e uma cura, e começa a próxima fase.
## No online todo mundo faz isso ao mesmo tempo, cada um no seu computador, e avisa o anfitrião quando
## terminou as cartas; a próxima fase começa quando todos terminarem (ou depois de 60 s).
func fase_completa() -> void:
	if entre_fases or acabou:
		return
	entre_fases = true
	missao.encerrar()
	objetivo.encerrar()   # objetivo ainda aberto: falha sem castigo (o anfitrião manda o estado final)
	var seq := _no_seq   # se o nó seguinte for escolhido antes de terminar (online), este fluxo se descarta
	var n: int = diretor.fase_idx + 1
	if not saida.aberta:
		fase_stat.tempo = diretor.t_fase   # congela o tempo da fase antes do descanso (com a saída aberta já foi congelado)
	var ff: Dictionary = diretor.fases()[diretor.fase_idx]
	if ff.get("chefe_regiao", false):   # regiões (#64): derrubou o chefe da região
		anunciar("REGIÃO CONQUISTADA!", Color(1, 0.85, 0.4))
		mensagem(str(ff.get("regiao_nome", "")), Color(1, 0.9, 0.6))
	elif ff.has("regiao"):
		anunciar("%s completa!" % ff.get("nome", ""), Color(1, 0.9, 0.4))
	else:
		anunciar("Fase %d completa!" % n, Color(1, 0.9, 0.4))
	Som.tocar("vitoria", 0.1, 1.0, -8)
	if caido:
		levantar(0.5)   # quem caiu volta no fim da fase
	for o in inimigos.lista.duplicate():
		efeitos.explodir(o.pos, Color(0.5, 0.8, 0.4), 4, 100.0)
	inimigos.limpar()
	coleta.puxar_tudo()
	await get_tree().create_timer(2.2, true, false, true).timeout
	await _esperar_cartas()
	if acabou:
		return
	# tela de resultados: cada um vê a sua; no online ela fecha sozinha em ~8 s e ninguém espera ninguém
	fase_stat.nivel_fim = nivel
	fase_stat.conjuntos = conj_resumo
	resultado.abrir(fase_stat)
	while resultado.aberto() and not acabou:
		await get_tree().process_frame
	if acabou or not entre_fases or seq != _no_seq:   # (no online o anfitrião pode já ter mandado seguir)
		return
	jogador.curar(stat("vida_max") * 0.5)
	abrir_bau()
	await _esperar_cartas()
	if no_tipo == "elite" and not acabou:
		await _bonus_elite()
	if acabou or seq != _no_seq:
		return
	if loja_entre_fases_devida():   # #112: loja obrigatória entre fases (estilo Hades), antes do mapa
		loja.abrir(sortear_cartas(Sorte.criar("loja", mapa_pos.x)))
		while loja.aberto() and not acabou and seq == _no_seq:
			await get_tree().process_frame
		await _esperar_cartas()
		if acabou or seq != _no_seq or not entre_fases:
			return
	abrir_mapa()   # depois do baú vem o mapa: o grupo escolhe o próximo nó (solo: na hora; online: voto)


## Loja obrigatória entre fases (dados/fase.json "loja_entre_fases"): vale se há próximo nó e ele não é só loja (não repete).
func loja_entre_fases_devida() -> bool:
	if not bool(Dados.json("fase").get("loja_entre_fases", false)):
		return false
	var ac := mapa_acessiveis()
	if ac.is_empty():
		return false
	for f in ac:
		if mapa_tipo_de(f) != "loja":
			return true
	return false


## Prêmio extra da fase elite: baús a mais e um fragmento da transformação (com pity), se ainda falta algum.
func _bonus_elite() -> void:
	var t: Dictionary = Mapa.tipo_cfg("elite")
	for _i in int(t.get("baus_extra", 1)):
		abrir_bau()
		await _esperar_cartas()
		if acabou:
			return
	var alvo: String = descobertas.alvo_fragmento()
	var p: Dictionary = t.get("fragmento_pity", {})
	if alvo != "" and Sorte.pity("elite_no", float(p.get("base", 0.35)), float(p.get("passo", 0.3)), int(p.get("limite", 3))):
		descobertas.dar_fragmento(alvo)


# ---------- mapa de progressão (#32 item 8) ----------

## Abre a tela do mapa (se ainda há pra onde ir).
func abrir_mapa() -> void:
	if acabou or not entre_fases or mapa_acessiveis().is_empty():
		return
	tela_mapa.abrir()
	Transicao.revelar()   # sai da fase pro mapa


func mapa_acessiveis() -> Array:
	return Mapa.acessiveis(mapa, mapa_pos.x, mapa_pos.y)


func mapa_tipo_de(faixa: int) -> String:
	return str(Mapa.no(mapa, mapa_pos.x + 1, faixa).get("tipo", "fase"))


## O grupo escolheu o próximo nó. Solo: a tela do mapa chama direto. Online: só o anfitrião decide (depois da votação)
## e manda o evento "proxima_fase" com a faixa; todo mundo (ele também) cai aqui ao mesmo tempo.
## Nó de combate começa a fase do andar; os outros (descanso, loja, evento, santuário) resolvem na hora e voltam ao mapa.
func escolher_no(faixa: int) -> void:
	if not entre_fases or acabou:
		return
	var ac := mapa_acessiveis()
	if ac.is_empty():
		return
	if not faixa in ac:
		faixa = ac[0]
	_no_seq += 1
	var seq := _no_seq
	tela_mapa.fechar()
	Transicao.revelar()   # do mapa pra fase nova
	if resultado.aberto():
		resultado.fechar()
	loja.fechar()   # o anfitrião fechou a votação com alguém ainda na loja
	while cartas.aberto() and not acabou:   # uma escolha de carta em andamento termina antes (não se perde nenhuma)
		await get_tree().process_frame
	if acabou or seq != _no_seq or not entre_fases:
		return
	mapa_pos = Vector2i(mapa_pos.x + 1, faixa)
	mapa_trilha.append(mapa_pos)
	no_tipo = str(Mapa.no(mapa, mapa_pos.x, mapa_pos.y).get("tipo", "fase"))
	if Mapa.combate(no_tipo):
		_iniciar_andar(mapa_pos.x)
	else:
		_resolver_no(no_tipo, seq)


## Nós sem combate: acontecem aqui, sem fase. Depois volta pro mapa (a menos que um novo nó já tenha sido escolhido).
func _resolver_no(tipo: String, seq: int) -> void:
	var c: Dictionary = Mapa.tipo_cfg(tipo)
	var andar := mapa_pos.x
	match tipo:
		"descanso":
			jogador.curar(stat("vida_max") * float(c.get("cura", 1.0)))
			efeitos.explodir(jogador.centro(), Color(0.5, 0.95, 0.6), 12, 90.0)
			anunciar("Descanso: vida recuperada!", Color(0.5, 0.95, 0.6))
			Som.tocar("vitoria", 0.1, 1.1, -8)
			await get_tree().create_timer(1.8, true, false, true).timeout
		"loja":
			loja.abrir(sortear_cartas(Sorte.criar("loja", andar)))
			while loja.aberto() and not acabou and seq == _no_seq:
				await get_tree().process_frame
		"evento":
			_evento_no(c, andar)
		"santuario":
			Som.tocar("plim", 0.05, 1.2)
			anunciar("Santuário raro!", Color(1, 0.7, 0.25))
			cartas.escolher("Santuário raro", Descobertas.oferta_dadivas(Sorte.criar("mapa_santuario", andar), str(c.get("raridade_min", "epica")), _ids_dadivas()))
	await _esperar_cartas()
	if acabou or seq != _no_seq or not entre_fases:
		return
	abrir_mapa()


## Evento do mapa: sorteado com a semente (igual pra todos): dádiva, pacto sombrio (custa vida) ou baú.
func _evento_no(c: Dictionary, andar: int) -> void:
	var vars: Dictionary = c.get("variacoes", {})
	var chaves := vars.keys()
	var rng := Sorte.criar("mapa_evento", andar)
	var i := Sorte.ponderado(rng, chaves.map(func(k): return float(vars[k].get("peso", 1))))
	var k: String = "dadiva" if i < 0 else str(chaves[i])
	var v: Dictionary = vars.get(k, {})
	anunciar(str(v.get("titulo", "Evento")), Color(0.85, 0.6, 1))
	match k:
		"bau":
			abrir_bau()
		"sombria":
			jogador.hp = maxf(1.0, jogador.hp - stat("vida_max") * float(v.get("custo_vida", 0.25)))
			cartas.escolher(str(v.get("titulo", "")), Descobertas.oferta_dadivas(rng, str(v.get("raridade_min", "rara")), _ids_dadivas()))
		_:
			cartas.escolher(str(v.get("titulo", "")), Descobertas.oferta_dadivas(rng, "", _ids_dadivas()))


## Música da fase: "musica" da fase em corrida.json (ex.: horror), senão a de fase.json; no chefe, "musica_chefe" ou "chefe".
func _musica_da_fase(chefe: bool) -> void:
	var fs: Array = diretor.fases()
	var f: Dictionary = fs[clampi(diretor.fase_idx, 0, fs.size() - 1)] if fs.size() > 0 else {}
	if chefe:
		Som.musica(str(f.get("musica_chefe", "chefe")))
	else:
		Som.musica(_nome_musica(f.get("musica", Dados.json("fase").get("musica", "minijogo_tenso")), diretor.fase_idx))


## "musica" pode ser um nome ou uma lista de nomes; com lista, o andar escolhe por rodízio (andar % tamanho).
func _nome_musica(m, andar: int) -> String:
	if m is Array and not m.is_empty():
		return str(m[maxi(andar, 0) % m.size()])
	return str(m)


## Começa a fase do andar (índice em corrida.json); o tipo do nó (fase, elite, chefe) ajusta a dificuldade.
func _iniciar_andar(idx: int) -> void:
	diretor.ir_para(idx, no_tipo)
	_atualizar_calor()   # região nova: o calor dela soma por cima
	saida.fechar()
	_saida_pedida = false
	_montar_mapa_fase()
	chao.nova_fase()
	inimigos.elementos.nova_fase()   # contadores de elemento do santuário selado: por andar
	_zerar_fase_stat()
	if resultado.aberto():
		resultado.fechar()
	var f: Dictionary = diretor.fases()[diretor.fase_idx]
	objetivo.nova_fase(f, no_tipo, diretor.fase_idx)
	missao.nova_fase(f, diretor.fase_idx)
	var marca := "  (ELITE)" if no_tipo == "elite" else ""
	entre_fases = false
	_musica_da_fase(false)
	_comeco_de_fase(diretor.fase_idx, marca)   # abertura da fase (ou o anúncio e a chegada simples): herói e aliados chegam


## Começo de um andar: a abertura cinematográfica (abertura.gd) se estiver ligada; senão o anúncio do HUD e a chegada simples do herói.
func _comeco_de_fase(idx: int, marca: String) -> void:
	if abertura.comecar(idx, marca):
		return   # o título e a queda do herói são dela
	_anunciar_fase(idx, marca)
	entradas.chegada()


## Teste e depuração (--fase=N): vai direto pra um andar, andando pelo mapa com a política do robô.
func saltar_para_andar(idx: int) -> void:
	idx = clampi(idx, 0, int(mapa.andares) - 1)
	while mapa_pos.x < idx:
		var f := Mapa.escolha_bot(mapa, mapa_pos.x, mapa_pos.y)
		if f < 0:
			break
		mapa_pos = Vector2i(mapa_pos.x + 1, f)
		mapa_trilha.append(mapa_pos)
	no_tipo = "fase"
	diretor.ir_para(mapa_pos.x)
	saida.fechar()
	_atualizar_calor()
	_montar_mapa_fase()
	chao.nova_fase()
	inimigos.elementos.nova_fase()   # contadores de elemento do santuário selado: por andar
	objetivo.nova_fase(diretor.fases()[diretor.fase_idx], no_tipo, diretor.fase_idx)
	missao.nova_fase(diretor.fases()[diretor.fase_idx], diretor.fase_idx)
	hud.limpar_mensagens()   # o anúncio da fase 1 já tinha saído: troca pelo do andar de destino
	if not abertura.comecar(diretor.fase_idx, ""):
		_anunciar_fase(diretor.fase_idx, "")
	_musica_da_fase(false)


## Segue direto pra fase seguinte, sem passar pelo mapa (testes e atalhos de depuração).
func proxima_fase() -> void:
	if not entre_fases or acabou:
		return
	_no_seq += 1
	var idx: int = mini(diretor.fase_idx + 1, diretor.fases().size() - 1)
	var faixa := mapa_pos.y
	for x in int(mapa.faixas):
		if Mapa.no(mapa, idx, x).size() > 0:
			faixa = x
			break
	mapa_pos = Vector2i(idx, faixa)
	mapa_trilha.append(mapa_pos)
	no_tipo = "fase"
	_iniciar_andar(idx)


static func _stat_novo() -> Dictionary:
	return {"tempo": 0.0, "abates": 0, "chefes": 0, "xp": 0.0, "nivel_ini": 1, "nivel_fim": 1, "dano": {}, "itens": [], "objetivo": {}, "conjuntos": []}


## Estatísticas da fase: zeram aqui, no começo de cada fase (e na primeira, no _ready).
func _zerar_fase_stat() -> void:
	fase_stat = _stat_novo()
	fase_stat.nivel_ini = nivel


func chefes() -> Array:
	var lista: Array = inimigos.lista.filter(func(v): return v.chefe)
	lista.sort_custom(func(a, b): return a.d.get("final", false) and not b.d.get("final", false))
	return lista


# ---------- XP e nível ----------

func xp_para(n: int) -> float:
	var base := 519.0 + (n - 40) * 40.0
	if n < 20:
		base = 5.0 + (n - 1) * 6.0
	elif n < 40:
		base = 119.0 + (n - 20) * 20.0
	# as armas nascem fracas (dados/crescimento_armas.json): os primeiros níveis custam menos XP pra a build crescer logo
	var ini: Dictionary = Dados.json("crescimento_armas").get("xp_inicial", {})
	if n <= int(ini.get("ate", 0)):
		base *= float(ini.get("fator", 1.0))
	return base


func ganhar_xp(valor: float) -> void:
	fase_stat.xp += valor * stat("xp")
	xp += valor * stat("xp")
	while xp >= xp_para(nivel):
		xp -= xp_para(nivel)
		nivel += 1
		_niveis_pendentes += 1
	if _niveis_pendentes > 0 and not cartas.aberto() and not resultado.aberto():
		_abrir_proxima()


func ganhar_carta_tomada() -> void:
	_cartas_tomada += 1
	if not cartas.aberto() and not resultado.aberto():
		_abrir_proxima()


func _abrir_proxima() -> void:
	if acabou:
		return
	if _niveis_pendentes > 0:
		_niveis_pendentes -= 1
		Som.tocar("plim")
		cartas.escolher("Subiu pro nível %d!" % nivel, sortear_cartas())
	elif _cartas_tomada > 0:
		_cartas_tomada -= 1
		Som.tocar("plim", 0.05, 1.2)
		cartas.escolher(str(Descobertas.cfg().get("santuarios", {}).get("titulo_tomada", "Carregou!")), sortear_cartas())


## Chamado pelas cartas quando o jogador escolhe uma.
func escolheu(c: Dictionary) -> void:
	aplicar(c)
	if _niveis_pendentes > 0 or _cartas_tomada > 0:
		_abrir_proxima.call_deferred()


func aplicar(c: Dictionary) -> void:
	if str(c.tipo) in ["arma", "passivo", "evolucao", "equipamento"]:
		var d := Dados.item(str(c.id))
		fase_stat.itens.append({"tipo": str(c.tipo), "id": str(c.id), "nome": str(c.get("nome", d.get("nome", c.id))),
			"icone": str(c.get("icone", d.get("icone", c.id))), "nivel": int(c.get("nivel", 0))})
	match str(c.tipo):
		"arma":
			if armas.tem(c.id):
				armas.subir(c.id)
			else:
				armas.adicionar(c.id)
			atualizar_visual()
		"passivo":
			passivos[c.id] = int(passivos.get(c.id, 0)) + 1
			_recalcular()
			armas.preaquecer()   # passivo de área muda o tamanho da poça: gera agora, com as cartas abertas
		"cura":
			jogador.curar(40)
		"evolucao":
			armas.trocar(c.de, c.id)
			atualizar_visual()
		"equipamento":
			equipamentos[str(Dados.item(c.id).get("slot", c.id))] = c.id
			_recalcular()
			atualizar_visual()
		"ascensao":
			var aa = armas.achar(c.id)
			if aa:
				aa["asc"] = int(aa.get("asc", 0)) + 1
				armas.preaquecer()
			mensagem("%s: ascensão %d" % [str(c.get("nome", c.id)), int(aa.get("asc", 0)) if aa else 0], Color(1.0, 0.85, 0.3))
		"reforja":
			var ar = armas.achar(c.de)
			if ar:
				ar.id = str(c.id)   # mesma arma, outra variação: o nível e a ascensão ficam
				armas.preaquecer()
				build_mudou()
				atualizar_visual()
		"fusao":
			for i in c.get("consome", []):
				var k := -1
				for j in armas.lista.size():
					if armas.lista[j].id == i:
						k = j
				if k >= 0:
					armas.lista.remove_at(k)
			armas.adicionar(str(c.id))   # sem herdar nível: a fundida já nasce no topo (evolucao: true)
			atualizar_visual()
			mensagem("Fusão: " + str(c.get("nome", c.id)), Color(1.0, 0.5, 0.9))
		"comportamento":
			armas.dar_comportamento(str(c.arma), str(c.id))
			mensagem("%s: %s" % [str(c.get("arma_nome", c.arma)), str(c.nome)], Color(1.0, 0.65, 0.3))
		"dadiva":
			descobertas.aplicar_dadiva(c)


## Personagem em camadas (herois.json "camadas": true): o que ele veste e segura aparece nele.
func atualizar_visual() -> void:
	if heroi.get("camadas", false) and jogador:
		jogador.definir_camadas(Equipamento.camadas(armas.lista.map(func(a): return a.id), equipamentos))


func pode_resortear() -> bool:
	return resortear > 0


## Pular (VS/HoloCure "Skip"): fecha as cartas sem pegar nenhuma, gasta 1 carga e devolve parte do sortear de novo
## (corrida.json > cartas > pular_devolve). Retorna false (sem gastar) se não há carga.
func gastar_pular() -> bool:
	if pular <= 0:
		return false
	pular -= 1
	resortear += int(Dados.json("corrida").get("cartas", {}).get("pular_devolve", 0))
	return true


## Só arma, passivo e equipamento podem ser banidos (evolução, cura e dádiva não).
static func carta_banivel(c: Dictionary) -> bool:
	return str(c.get("tipo", "")) in ["arma", "passivo", "equipamento"]


## Banir (VS/HoloCure "Banish"): a carta some do sorteio até o fim da corrida. Troca a carta por outra que ainda
## não está na mesa; retorna essa carta nova, ou {} se não sobrou nenhuma (aí a carta só sai da mesa). Sem carga: {"erro": true}.
func gastar_banir(c: Dictionary, mesa: Array) -> Dictionary:
	if banir <= 0 or not carta_banivel(c):
		return {"erro": true}
	banir -= 1
	banidos[str(c.id)] = true
	var mostradas := mesa.map(func(x): return str(x.get("id", "")))
	for _i in 12:
		for n in sortear_cartas():
			if not str(n.id) in mostradas and not (n.tipo == "cura"):
				return n
	return {}


func gastar_resortear() -> Array:
	resortear -= 1
	return sortear_cartas()


## Sorteia 3 cartas (às vezes 4, com sorte) entre: subir arma/passivo que já tem, ou pegar novos.
func sortear_cartas(rng: RandomNumberGenerator = null) -> Array:   # com rng (baú) o sorteio sai da stream dele; sem, é pessoal
	var cand := []   # [peso, carta]
	var armas_d: Dictionary = Dados.json("armas")
	var pas_d: Dictionary = Dados.json("passivos")
	for a in armas.lista:
		if a.nivel < armas.nivel_max(a.id) and not banidos.has(a.id):
			cand.append([10.0, _carta("arma", a.id, a.nivel + 1)])
	for id in passivos:
		if passivos[id] < int(pas_d[id].get("max", 5)) and not banidos.has(id):
			cand.append([8.0, _carta("passivo", id, passivos[id] + 1)])
	_cartas_universais(cand)
	if armas.lista.size() < Universais.max_total():
		var ids: Array = armas.lista.map(func(a): return a.id)
		for id in armas_d:
			# global ou exclusiva deste herói (até o limite): nunca oferece carta impossível
			if not Construcao.arma_permitida(id, heroi_id, ids) or _tem_evolucao_de(id) or banidos.has(id):
				continue
			cand.append([float(armas_d[id].get("peso_carta", 6.0)), _carta("arma", id, 1)])
	# #63: cartas raras que mudam o COMPORTAMENTO de uma arma que já está no nível mínimo (comportamentos.json)
	var peso_comp := float(Dados.json("comportamentos").get("_config", {}).get("peso_carta", 2.5))
	for a in armas.lista:
		for cid in armas.comportamentos_disponiveis(a):
			cand.append([peso_comp, _carta_comp(a, str(cid))])
	if passivos.size() < MAX_PASSIVOS:
		for id in pas_d:
			if id.begins_with("_") or passivos.has(id) or banidos.has(id):
				continue
			cand.append([5.0, _carta("passivo", id, 1)])
	# equipamentos visuais: só slot livre e do próprio personagem (por enquanto só quem tem modelo em camadas)
	if heroi.get("camadas", false):
		var eq_d: Dictionary = Dados.json("equipamentos")
		for id in eq_d:
			if Equipamento.permitido(id, heroi_id, equipamentos) and not banidos.has(id):
				cand.append([float(eq_d.get("_config", {}).get("peso_carta", 5.0)), _carta("equipamento", id, 1)])
	var n := 3
	if _rf(rng) < 0.1 + stat("sorte") * 0.35:
		n = 4
	var res := []
	while res.size() < n and not cand.is_empty():
		var total := 0.0
		for c in cand:
			total += c[0]
		var r := _rf(rng) * total
		for i in cand.size():
			r -= cand[i][0]
			if r <= 0:
				res.append(cand[i][1])
				cand.remove_at(i)
				break
	if res.is_empty():
		res.append({"tipo": "cura", "id": "vida", "nome": "Café da tarde", "desc": "Recupera 40 de vida.", "icone": "vida", "nivel": 0})
	return res


## #115: cartas das armas universais: nova (variação sorteada pela semente), ascensão (depois do nível máximo),
## reforja (troca a variação) e fusão (consome as armas da receita e libera slots). Isso é o que mantém o jogo com
## escolhas de melhoria depois do nível 30: a cura só sai se não sobrar nenhuma carta.
func _cartas_universais(cand: Array) -> void:
	var ids: Array = armas.lista.map(func(a): return a.id)
	var tenho_bases: Array = ids.map(func(i): return Universais.base_de(i))
	var rodada: int = armas.lista.size() + banidos.size()
	if Universais.cabe(ids, false):
		var armas_d: Dictionary = Dados.json("armas")
		for b in Universais.bases_sorteaveis():
			if b in tenho_bases:
				continue
			var id := Universais.id_de(b, Universais.variacao_para(b, semente, rodada))
			if banidos.has(id) or banidos.has(b):
				continue
			cand.append([float(armas_d[id].get("peso_carta", 6.0)), _carta("arma", id, 1)])
	var asc_cfg: Dictionary = Universais.cfg().get("ascensao", {})
	for a in armas.lista:
		var d := Dados.item(a.id)
		if d.get("classe", "") == "transformacao" or banidos.has(a.id):
			continue
		if int(a.nivel) >= armas.nivel_max(a.id) and int(a.get("asc", 0)) < Universais.asc_max():
			var n := int(a.get("asc", 0)) + 1
			cand.append([float(asc_cfg.get("peso", 14.0)), {"tipo": "ascensao", "id": str(a.id), "nome": "%s (ascensão %d)" % [str(d.get("nome", a.id)), n],
				"desc": "+%d%% de dano e +%d%% de área, de novo." % [roundi(float(asc_cfg.get("dano", 0.12)) * 100.0), roundi(float(asc_cfg.get("area", 0.05)) * 100.0)],
				"icone": str(d.get("icone", a.id)), "nivel": n, "max": Universais.asc_max(), "cmp": []}])
		if Universais.eh_universal(a.id) and not Universais.eh_fusao(a.id) and int(a.nivel) >= 2:
			var b := Universais.base_de(a.id)
			var nv_id := Universais.id_de(b, Universais.outra_variacao(b, str(d.get("variacao", "puro")), semente, rodada))
			var nd := Dados.item(nv_id)
			cand.append([float(Universais.cfg().get("reforja", {}).get("peso", 3.0)), {"tipo": "reforja", "id": nv_id, "de": str(a.id),
				"nome": "Reforjar: " + str(nd.get("nome", nv_id)), "desc": str(nd.get("descricao", "")), "icone": str(nd.get("icone", nv_id)), "nivel": 0, "max": 1, "cmp": []}])
	for f in Universais.fusoes_possiveis(armas.lista, armas.nivel_max):
		var fd := Dados.item(f.vira)
		cand.append([float(Universais.cfg().get("fusao", {}).get("peso", 40.0)), {"tipo": "fusao", "id": f.vira, "consome": f.ids,
			"nome": str(fd.get("nome", f.vira)), "desc": str(fd.get("descricao", "")), "icone": str(fd.get("icone", f.vira)), "nivel": 0, "max": 1, "cmp": []}])


## Ids das dádivas que o jogador já tem (a dádiva em dupla só aparece com as duas exigidas).
func _ids_dadivas() -> Array:
	return descobertas.dadivas.map(func(x): return x.id)


func _rf(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng else randf()


func _tem_evolucao_de(base: String) -> bool:
	for e in Dados.json("evolucoes").get("lista", []):
		if e.arma == base and armas.tem(e.vira):
			return true
	return false


func _carta(tipo: String, id: String, nv: int) -> Dictionary:
	var d := Dados.item(id)
	var desc := str(d.get("descricao", ""))
	if tipo == "arma" and nv > 1:
		desc = _texto_nivel(d.get("niveis", [])[nv - 2])
	var c := {"tipo": tipo, "id": id, "nome": str(d.get("nome", id)), "desc": desc, "icone": str(d.get("icone", id)), "nivel": nv,
		"max": (1 + d.get("niveis", []).size()) if tipo == "arma" else int(d.get("max", 1)), "cmp": Interface.comparacao(tipo, id, nv)}
	if tipo in ["arma", "passivo", "equipamento", "evolucao"] and not Conjuntos.etiquetas_de(id).is_empty():
		# gancho pra tela de cartas (#63): etiquetas do item e o que elas mudam na build ("Lâmina 2>3  Fogo 0>1").
		# Só vale pra carta nova: subir de nível o que já se tem não muda a contagem.
		var novo: bool = (tipo == "arma" and nv == 1) or (tipo == "passivo" and not passivos.has(id)) or tipo == "equipamento" or tipo == "evolucao"
		c["etiquetas"] = Conjuntos.etiquetas_de(id)
		c["etiquetas_txt"] = Conjuntos.rotulo_carta(id, conj_contagem) if novo else ""
	if tipo == "arma" and Construcao.exclusiva(id):
		# carta de arma exclusiva mostra quantas ele terá de quantas pode ter (ex.: EXCLUSIVA 1/2)
		var ids: Array = armas.lista.map(func(a): return a.id)
		c["exclusiva"] = "%d/%d" % [Construcao.n_exclusivas(ids, heroi_id) + (1 if nv == 1 else 0), Construcao.limite_exclusivas()]
	return c


## Carta de comportamento: muda COMO a arma funciona (dados/comportamentos.json); o rótulo da carta diz isso.
func _carta_comp(a: Dictionary, cid: String) -> Dictionary:
	var def: Dictionary = armas.comp_def(cid)
	var d := Dados.item(a.id)
	return {"tipo": "comportamento", "id": cid, "arma": str(a.id), "arma_nome": str(d.get("nome", a.id)), "nome": str(def.get("nome", cid)),
		"desc": str(def.get("desc", "")), "icone": str(d.get("icone", a.id)), "nivel": 0, "max": 1, "cmp": []}


func _texto_nivel(n: Dictionary) -> String:
	var partes := []
	for k in n:
		var v := float(n[k])
		match k:
			"dano": partes.append("+%d de dano" % v)
			"quantidade": partes.append("+%d projétil" % v)
			"recarga": partes.append("recarrega %.2fs mais rápido" % -v)
			"area": partes.append("+%d%% de área" % (v * 100))
			"perfura": partes.append("atravessa +%d" % v)
			"duracao": partes.append("+%.1fs de duração" % v)
			"tique": partes.append("acerta mais rápido")
			_: partes.append("+%s %s" % [v, k])
	return ", ".join(partes)


# ---------- baú ----------

func abrir_bau() -> void:
	Som.tocar("abrir")
	var premios := []
	for e in Dados.json("evolucoes").get("lista", []):
		var a = armas.achar(e.arma)
		if a and a.nivel >= armas.nivel_max(e.arma) and passivos.has(e.passivo):
			var d := Dados.item(e.vira)
			premios.append({"tipo": "evolucao", "id": e.vira, "de": e.arma, "nome": str(d.get("nome", e.vira)),
				"desc": "EVOLUIU! " + str(d.get("descricao", "")), "icone": str(d.get("icone", e.vira)), "nivel": 0})
			break
	if premios.is_empty():
		var rb := Sorte.fluxo("bau")
		var n := 1
		var r := rb.randf()
		if r < 0.1 + stat("sorte") * 0.1:
			n = 5
		elif r < 0.35 + stat("sorte") * 0.2:
			n = 3
		for i in n:
			# baú prefere subir o que você já tem
			var opcoes := sortear_cartas(rb)
			var ja_tem := opcoes.filter(func(c): return c.nivel > 1)
			var c: Dictionary = Sorte.escolher(rb, ja_tem if not ja_tem.is_empty() else opcoes)
			premios.append(c)
			aplicar(c)
	else:
		aplicar(premios[0])
	_achar_item_no_bau()
	cartas.mostrar_bau(premios)


## Chance de achar um item da mochila dentro do baú da corrida (dados/mochila.json). Só o herói criado com mochila acha: o item
## vai pra bolsa de achados e só vem pra casa se ele vencer. Sorteio pessoal (não mexe nas streams da semente).
func _achar_item_no_bau() -> void:
	if provisoes == null:
		return
	var c := Mochila.cfg()
	var ids: Array = c.get("achados", [])
	if ids.is_empty() or randf() >= float(c.get("achado_bau", 0.4)):
		return
	var id: String = ids[randi() % ids.size()]
	if provisoes.achar(id):
		mensagem("Achou: %s (vai pro baú se você vencer)" % Mochila.nome(id), Color(1, 0.9, 0.5))


# ---------- fim ----------

func morrer(quem := "") -> void:
	if ganchos and not acabou and quem != "desistiu" and ganchos.reviver():
		return   # Sete Vidas (#72 marco 6): levanta de novo
	if provisoes and not duelo_ativo and not acabou and provisoes.fenix():
		return   # Pena de Fênix (#72): levanta uma vez
	if acabou:
		return
	if duelo_ativo:
		duelo.jogador_caiu(quem)
		return
	if eh_online:
		_cair()
		return
	_fim(false)


## Online: caiu na horda. Vira corpo no lugar e espera alguém ficar perto (ou a fase acabar).
func _cair() -> void:
	if caido:
		return
	caido = true
	jogador.hp = 0
	if jogador._tem_anim():   # folha de 9 colunas: o jogador.gd faz a queda (tropeça, cai e deita, ficando cinza) em _process
		jogador.spr.modulate = Color(0.45, 0.45, 0.5, 0.8)
	online.reviver_prog = 0.0
	anunciar("Você caiu!", Color(1, 0.4, 0.4))
	mensagem("Espere alguém chegar perto pra te levantar.", Color(1, 0.8, 0.6))


func levantar(frac: float) -> void:
	if not caido:
		return
	caido = false
	jogador.spr.rotation = 0.0
	jogador.spr.position = Vector2.ZERO
	jogador.spr.modulate = Color.WHITE
	jogador.hp = maxf(1.0, stat("vida_max") * frac)
	jogador.invencivel = 1.5


## Online: menu de pausa > Desistir. Sai da sala e termina a partida aqui.
func desistir() -> void:
	if eh_online:
		Rede.sair()
		_fim(false)
	else:
		morrer("desistiu")


## Começa o duelo final (depois do chefe final, ou direto no teste).
func iniciar_duelo() -> void:
	if duelo_ativo or acabou:
		return
	if cartas.aberto():
		cartas._fechar()
	habilidades.cancelar()   # o duelo é entre humanos: volta na hora
	duelo.iniciar(self)


## Online: o anfitrião mandou começar o duelo entre as pessoas (d = centro, ângulo e ordem dos peers).
func iniciar_duelo_online(d: Dictionary) -> void:
	if duelo_ativo or acabou:
		return
	await _esperar_cartas()   # quem ainda escolhe carta entra quando terminar
	if duelo_ativo or acabou:
		return
	if caido:
		levantar(1.0)
	duelo.iniciar_online(self, d)


## Teste: dá ao jogador uma build sorteada de nível N (--build=N).
func dar_build_teste(nv: int) -> void:
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = hash([semente, heroi_id, nv])   # build repetível com --semente (medir desempenho sempre com as mesmas armas)
	var b: Dictionary = Construcao.gerar(heroi_id, nv, rng_b)
	armas.lista.clear()
	for a in b.armas:
		armas.adicionar(a.id)
		armas.achar(a.id).nivel = a.nivel
	passivos = b.passivos
	nivel = nv
	_recalcular()
	jogador.hp = stat("vida_max")
	atualizar_visual()


## Teste: build de nível N e vai direto pro duelo (--duelo=N).
func iniciar_duelo_teste(nv: int) -> void:
	dar_build_teste(nv)
	iniciar_duelo()


func fim_duelo(res: Dictionary) -> void:
	_fim(res.lugar == 1, {"duelo": res})


func _fim(vitoria: bool, extra := {}) -> void:
	acabou = true
	habilidades.cancelar()
	Som.parar_musica()
	Som.tocar("vitoria" if vitoria else "derrota")
	var lista_dano := []
	for a in dano_por_arma:
		lista_dano.append([a, dano_por_arma[a]])
	lista_dano.sort_custom(func(x, y): return x[1] > y[1])
	var res := {"vitoria": vitoria, "calor": calor_pts, "fase": diretor.fase_idx + 1, "fases": diretor.fases().size(), "tempo": diretor.tempo, "nivel": nivel, "abates": abates,
		"heroi": heroi_id, "conjuntos": conj_resumo, "dano": lista_dano, "apanhou": dano_recebido, "chefe_final": nome_chefe_final(),
		"armas": Interface.tabela_armas(dano_por_arma, nivel_arma, tempo_arma, diretor.tempo)}
	if provisoes:   # o que sobrou da mochila e o que achou: o main.gd leva pro baú se o herói sobreviver (#72)
		res["mochila"] = provisoes.sobra()
		res["achados"] = provisoes.achados
		res["usos"] = provisoes.usos
	res.merge(extra)
	await get_tree().create_timer(1.2, true, false, true).timeout
	terminou.emit(res)


## Calor que vale agora: o que o jogador escolheu + o da região atual (regioes.json "calor": a dificuldade sobe
## de região em região). A recompensa (calor_pts) conta só o do jogador.
func _atualizar_calor() -> void:
	calor_ef = Calor.efeitos(calor)
	if Regioes.ativo() and diretor:
		var extra := Calor.efeitos(Regioes.calor(Regioes.do_andar(diretor.fase_idx)))
		for k in extra:
			calor_ef[k] = float(calor_ef.get(k, 0.0)) + float(extra[k])


## Anúncio no começo de cada fase. Com regiões: "Floresta Sombria 2/5: Trilha Torta"; na entrada de uma região
## nova, o nome dela aparece grande e a descrição embaixo.
func _anunciar_fase(idx: int, marca: String) -> void:
	var f: Dictionary = diretor.fases()[clampi(idx, 0, diretor.fases().size() - 1)]
	var cor := Color(1, 0.55, 0.45) if marca != "" else Color(0.7, 0.9, 1)
	if not f.has("regiao"):
		anunciar("Fase %d: %s%s" % [idx + 1, f.get("nome", ""), marca], cor)
		return
	var k := Regioes.por_regiao()
	if int(f.get("andar_regiao", 0)) == 0:
		anunciar(str(f.regiao_nome).to_upper(), Color(1, 0.85, 0.5))
		mensagem("Região %d de %d: %s" % [int(f.regiao) + 1, Regioes.n(), str(Regioes.regiao(int(f.regiao)).get("descricao", ""))], Color(0.8, 0.85, 1))
	var titulo := "CHEFE DA REGIÃO: %s" % f.get("nome", "") if f.get("chefe_regiao", false) else "%d/%d: %s" % [int(f.andar_regiao) + 1, k, f.get("nome", "")]
	if int(f.get("andar_regiao", 0)) == 0:
		mensagem(titulo + marca, cor)       # entrada de região: o nome dela já está grande
	else:
		anunciar(titulo + marca, cor)

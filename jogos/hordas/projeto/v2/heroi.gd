extends "res://v2/ator.gd"
## Herói da v2 (Hazaki): anda com WASD, setas e analógico esquerdo; fica virado para o MOUSE (8 direções) quando o mouse mexe, e para onde
## anda quando a direção de andar muda; com o controle, o analógico direito manda. Anima parado e andando com a folha do protótipo.
##
## Combate (números em dados/v2_combate.json):
##  - GOLPE no clique (ação "atacar") na direção do cursor: combo de 3 (corte, corte, estocada). Clique dentro da janela depois do golpe
##    encadeia o próximo; segurar o botão repete o combo. O dano sai no quadro "acerto_em" do golpe (combate.golpear), o herói avança um
##    pouco (lunge) e anda devagar enquanto golpeia. A esquiva cancela o fim do golpe.
##  - ESQUIVA (ação "esquiva", Espaço): rolamento com fôlego (cargas que voltam com o tempo) e invulnerabilidade no começo (porte do
##    movimento.json da v1).
##  - CORRER (ação "correr", Shift/L3): ~1,6x a velocidade de andar, gasta o MESMO fôlego da esquiva por segundo. Fôlego zerado = CANSADO:
##    não corre nem esquiva até recuperar ~30%, e anda mais devagar. A recuperação começa depois de um atraso sem gastar e é mais rápida
##    parado. Atacar cancela a corrida. A câmera adianta um pouco na direção da corrida.
##  - VIDA: ao apanhar fica invencível um instante, piscando, e leva um empurrão.
##  - RUPTURA (ação "ruptura", botão direito do mouse ou gatilho esquerdo; números em dados/v2_ruptura.json, disparo em v2/ruptura.gd): o APERTO
##    (evento) pede, a POSSE (polling) carrega. Estado.CARGA anda a 45%, não corre nem golpeia, NÃO é invencível e apanhar não cancela. Soltar
##    com carga mínima dispara em 360 graus (soltura perfeita na janela depois da carga cheia). Cancelam sem disparar e sem gastar recarga: a
##    esquiva, a pausa/escolha/baú/resultado (combate.jogo e pausado), a morte e o salto de relógio (ESC e perda de foco).
## API pública lida pelo HUD (get() com padrão): vida, vida_max, xp, xp_proximo, nivel, folego, folego_max, cansado (bool), correndo (bool), e da
## ruptura rup_carga (0 a 1), rup_recarga, rup_recarga_max, rup_perfeita, rup_nega_t, contragolpe_t e contragolpe_max.

enum Fonte { ANDA, MOUSE, STICK }
enum Estado { LIVRE, GOLPE, ESQUIVA, MORTO, CARGA }  # CARGA no fim: nada é renumerado
const VEL := 100.0  # px/s
const PASSO_ANIM := 0.13  # s por quadro de andar
const CENTRO_CORPO := Vector2(0, -20)  # do pé ao meio do corpo (mira e câmera)
const ORIGEM_GOLPE := Vector2(0, -10)  # de onde o arco do golpe parte (altura do tronco, no chão do 2.5D)

# ---- API pública (HUD)
var vida := 100.0
var vida_max := 100.0
var xp := 0.0
var xp_proximo := 5.0
var nivel := 1
var folego := 3.0  # fôlego em cargas (fracionário), gasto por esquiva (um bloco) e corrida (por segundo)
var folego_max := 3.0
var cansado := false  # fôlego zerou: sem correr nem esquivar até recuperar
var correndo := false

# ---- modificadores das melhorias (progresso.gd)
var m_dano := 1.0
var m_vel_ataque := 1.0
var m_area := 1.0
var m_vel_mov := 1.0
var m_ima := 1.0
var m_critico := 0.0

var mundo
var fonte := Fonte.ANDA
var estado := Estado.LIVRE
var dir_olhar := Vector2(0, 1)  # para onde está virado (nunca zero)
var mira_mundo := Vector2.ZERO  # ponto do mundo para onde o golpe vai (mouse ou analógico direito)
var entrada_forcada: Variant = null  # testes, fotos e medição: um Vector2 aqui vale no lugar do teclado e do controle
var ataque_forcado: Variant = null  # idem para o botão de atacar segurado (true/false); só vale com entrada_forcada
var correr_forcado: Variant = null  # idem para o botão de correr segurado
var ruptura_forcada: Variant = null  # idem para o botão da ruptura segurado
var _soltar_ataque := false  # o botão de atacar que fechou uma tela (escolha, baú) já foi gasto: só volta a golpear depois de soltá-lo
var avanco_camera := Vector2.ZERO  # para onde a câmera adianta ao correr (px, suavizado)
var imortal := false  # medição e roteiros: ninguém tira vida
var andando := false
var vel := Vector2.ZERO  # deslocamento real do último quadro, px/s
var emp := Vector2.ZERO  # empurrão que o herói leva ao apanhar (px/s)
var invenc := 0.0  # s de invencibilidade que faltam (ao apanhar)
# golpe
var golpe_i := 0  # índice do passo do combo em andamento
var golpe_t := 0.0
var golpe_dur := 0.0
var golpe_cfg: Dictionary = {}
var golpe_dir := Vector2.RIGHT
var golpe_acertou := false
var proximo := 0  # passo do combo que o próximo clique vai dar
var combo_t := 0.0  # janela que sobra para encadear
var pausa_t := 0.0  # folga depois da estocada
var pedido_t := 0.0  # clique guardado
var golpes := 0  # quantos golpes saíram (testes)
# esquiva
var esq_t := 0.0
var esq_dur := 0.42
var esq_inv := 0.3
var esq_dir := Vector2.RIGHT
var esq_pedido := 0.0
var esquivas := 0
# ruptura (botão direito)
var rup_carga := 0.0  # fração da carga (0 a 1) lida pelo HUD e pelo desenho do anel
var rup_carga_t := 0.0  # s de carga (tempo do mundo)
var rup_recarga := 0.0  # s até poder carregar de novo
var rup_recarga_max := 1.0  # a recarga do último disparo (o HUD desenha a fração)
var rup_perfeita := false  # a carga está na janela da soltura perfeita
var rup_nega_t := 0.0  # s do "negado" (apertou na recarga): o slot do HUD treme
var contragolpe_t := 0.0  # s que faltam do bônus de dano da katana depois de um disparo que acertou
var contragolpe_max := 1.5  # a janela cheia, para o HUD
var rup_pedido_t := 0.0  # aperto guardado
var rup_disparos := 0  # testes
var rup_cancelados := 0  # testes
var _rup_us := 0  # Time.get_ticks_usec() do último quadro da carga (salto de relógio)
var _rup_apos_acerto := false  # o aperto veio depois do acerto do golpe: cancela o resto do golpe (antes do acerto, espera o golpe acabar)
var _rup_tique := 0  # quantos marcos de som a carga atual já tocou
var _rup_punch := 0.0
var _esq_rastro := 0.0
var _atraso_t := 0.0  # s até o fôlego começar a voltar
var _poeira_t := 0.0
var _ofego_t := 0.0
var _punch := 0.0
var _anda_ant := Vector2.ZERO
var _anim := 0.0
var _off_base := Vector2.ZERO


func criar(m, pai: Node, t: Dictionary, p: Vector2) -> void:
	mundo = m
	chave = "hazaki"
	raio = 6.0
	montar_animado(pai, t, p, 0, 0, false)
	_off_base = sprite.offset


## Lê as vidas e as regras do dados/v2_combate.json (chamado pelo combate depois de criar o herói).
func iniciar_stats(cfg: Dictionary) -> void:
	vida_max = float(cfg.heroi.vida)
	vida = vida_max
	folego_max = float(cfg.folego.max)
	folego = folego_max
	cansado = false
	correndo = false
	_atraso_t = 0.0
	esq_dur = float(cfg.esquiva.tempo)
	esq_inv = float(cfg.esquiva.invulneravel)


## Volta ao começo de uma partida (jogar de novo).
func resetar(p: Vector2) -> void:
	m_dano = 1.0
	m_vel_ataque = 1.0
	m_area = 1.0
	m_vel_mov = 1.0
	m_ima = 1.0
	m_critico = 0.0
	xp = 0.0
	nivel = 1
	estado = Estado.LIVRE
	emp = Vector2.ZERO
	invenc = 0.0
	combo_t = 0.0
	pausa_t = 0.0
	pedido_t = 0.0
	esq_pedido = 0.0
	proximo = 0
	rup_carga = 0.0
	rup_carga_t = 0.0
	rup_recarga = 0.0
	rup_recarga_max = 1.0
	rup_perfeita = false
	rup_nega_t = 0.0
	contragolpe_t = 0.0
	rup_pedido_t = 0.0
	_rup_apos_acerto = false
	rup_disparos = 0
	rup_cancelados = 0
	_rup_tique = 0
	_rup_punch = 0.0
	avanco_camera = Vector2.ZERO
	_punch = 0.0
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	sprite.position = Vector2.ZERO
	sprite.offset = _off_base
	definir_pos(p)
	iniciar_stats(mundo.combate.cfg)


## O botão de atacar foi apertado (o mundo repassa o clique; os testes também chamam): guarda o pedido por alguns instantes.
func atacar() -> void:
	pedido_t = float(mundo.combate.cfg.golpe.buffer)


func esquivar() -> void:
	esq_pedido = float(mundo.combate.cfg.golpe.buffer)


## Uma tela (escolha de carta, baú) acabou de fechar com o botão de atacar possivelmente apertado: o golpe por segurar (polling) fica
## desligado até o botão ser solto, para o clique que escolheu a carta não virar um golpe no quadro seguinte.
func exigir_soltar_ataque() -> void:
	_soltar_ataque = true


## O botão da ruptura foi apertado (o mundo repassa o evento; os testes também chamam). Só pede: quem carrega é a POSSE do botão (_livre).
## Na recarga (mais que o buffer) é negado: som grave e o slot do HUD treme. Antes do quadro de acerto de um golpe, o pedido espera o golpe acabar.
func ruptura() -> void:
	var c = mundo.combate
	if c.ruptura == null or c.jogo != "jogando" or c.pausado or _pausa_aberta() or estado == Estado.MORTO or estado == Estado.CARGA:
		return
	var buffer := float(c.cfg.golpe.buffer)
	if rup_recarga > buffer:
		rup_nega_t = float(c.ruptura.cfg.nega_t)
		c.ruptura.negou(self)
		return
	rup_pedido_t = buffer
	_rup_apos_acerto = estado == Estado.GOLPE and golpe_acertou
	if estado == Estado.GOLPE and not golpe_acertou:
		rup_pedido_t += maxf(golpe_dur - golpe_t, 0.0)


func entrada_evento(e: InputEvent) -> void:
	if e.is_action_pressed("atacar", false, true):
		atacar()
	elif InputMap.has_action("esquiva") and e.is_action_pressed("esquiva", false, true):
		esquivar()
	elif InputMap.has_action("ruptura") and e.is_action_pressed("ruptura", false, true):
		# o gatilho analógico manda um evento a cada mexida: só a borda (o aperto de verdade) conta, senão o "negado" repetiria
		if not (e is InputEventJoypadMotion) or Input.is_action_just_pressed("ruptura"):
			ruptura()


func vivo() -> bool:
	return estado != Estado.MORTO


## Centro do corpo (mira, câmera, orbes vão para cá).
func centro() -> Vector2:
	return pos + CENTRO_CORPO


## Dano que o herói pode levar agora? (fora da invencibilidade e dos i-frames da esquiva)
func vulneravel() -> bool:
	if estado == Estado.MORTO or imortal or invenc > 0.0:
		return false
	return not (estado == Estado.ESQUIVA and esq_t < esq_inv)


func curar(v: float) -> void:
	vida = minf(vida_max, vida + v)


## Fôlego que volta (matar com o modificador "Fôlego de caçador"): sai do cansaço se passar do limite.
func ganhar_folego(x: float) -> void:
	folego = minf(folego_max, folego + x)
	if cansado and folego >= float(mundo.combate.cfg.folego.cansado_ate) * folego_max:
		cansado = false


## Levou `valor` de dano de algo em `de` (mundo). Devolve true se o dano entrou.
func levar_dano(valor: float, de: Vector2) -> bool:
	if not vulneravel():
		return false
	vida = maxf(0.0, vida - valor)
	invenc = float(mundo.combate.cfg.heroi.invencivel)
	var d := pos - de
	emp = (d.normalized() if d.length() > 0.5 else -dir_olhar) * float(mundo.combate.cfg.heroi.recuo_dano)
	if estado == Estado.GOLPE:  # apanhar corta o golpe e o combo
		estado = Estado.LIVRE
		combo_t = 0.0
		proximo = 0
	mundo.combate.heroi_apanhou(valor)
	if vida <= 0.0:
		cancelar_ruptura(false)
		estado = Estado.MORTO
		mundo.combate.heroi_morreu()
	return true


func atualizar(dt: float) -> void:
	var real := entrada_forcada == null
	var v: Vector2 = entrada_forcada if not real else Input.get_vector("esquerda", "direita", "cima", "baixo")
	if estado == Estado.MORTO:
		_visual_morto(dt)
		return
	if real and InputMap.has_action("mira_esquerda"):
		var s := Input.get_vector("mira_esquerda", "mira_direita", "mira_cima", "mira_baixo")
		if s.length() > 0.3:
			fonte = Fonte.STICK
			dir_olhar = s.normalized()
	# a direção de andar mudou (começou a andar ou virou): passa a olhar para onde anda, até o mouse mexer de novo
	if v != Vector2.ZERO and (_anda_ant == Vector2.ZERO or v.normalized().dot(_anda_ant.normalized()) < 0.9):
		fonte = Fonte.ANDA
	_anda_ant = v
	# relógios
	invenc = maxf(0.0, invenc - dt)
	pedido_t = maxf(0.0, pedido_t - dt)
	esq_pedido = maxf(0.0, esq_pedido - dt)
	pausa_t = maxf(0.0, pausa_t - dt)
	if rup_recarga > 0.0 or rup_pedido_t > 0.0 or rup_nega_t > 0.0 or contragolpe_t > 0.0:
		_rup_relogios(dt)
	_recuperar(dt, v == Vector2.ZERO and (estado == Estado.LIVRE or estado == Estado.CARGA))
	var segurando := false
	if real:
		segurando = InputMap.has_action("atacar") and Input.is_action_pressed("atacar")
		if _soltar_ataque:  # o aperto que escolheu a carta ainda está lá: não conta como golpe até soltar
			_soltar_ataque = segurando
			segurando = false
	elif ataque_forcado != null:
		segurando = bool(ataque_forcado)
	# mira (sempre calculada: o golpe sai para ela)
	var c := centro()
	if fonte == Fonte.MOUSE and estado != Estado.GOLPE:
		var d: Vector2 = mundo.mouse_mundo() - c
		if d.length() > 4.0:
			dir_olhar = d.normalized()
	mira_mundo = c + dir_olhar * 120.0 if fonte != Fonte.MOUSE else mundo.mouse_mundo()
	var desl := Vector2.ZERO
	match estado:
		Estado.LIVRE:
			desl = _livre(dt, v, segurando)
		Estado.GOLPE:
			desl = _golpe(dt, v)
		Estado.ESQUIVA:
			desl = _esquiva(dt)
		Estado.CARGA:
			desl = _carga(dt, v)
	if emp.length_squared() > 4.0:
		desl += emp * dt
		emp *= exp(-11.0 * dt)
	else:
		emp = Vector2.ZERO
	if estado != Estado.LIVRE:
		correndo = false
	var antes := pos
	if desl != Vector2.ZERO:
		mundo.mover(self, desl)
	vel = (pos - antes) / maxf(dt, 0.0001)
	_camera_adiantada(dt)
	_visual(dt, v)


func _livre(dt: float, v: Vector2, segurando: bool) -> Vector2:
	if combo_t > 0.0:
		combo_t -= dt
		if combo_t <= 0.0:
			proximo = 0
	andando = v != Vector2.ZERO
	correndo = false
	if esq_pedido > 0.0 and pode_esquivar():
		_iniciar_esquiva(v)
		return Vector2.ZERO
	if rup_pedido_t > 0.0 and pode_ruptura() and _segurando_ruptura():  # a ruptura vem antes do golpe: segurar o clique e apertar o direito carrega
		_iniciar_carga()
		return Vector2.ZERO
	if (pedido_t > 0.0 or segurando) and pausa_t <= 0.0:  # o golpe tem prioridade sobre a corrida
		_iniciar_golpe()
		return Vector2.ZERO
	if not andando:
		return Vector2.ZERO
	if fonte == Fonte.ANDA:
		dir_olhar = v.normalized()
	var k := VEL * m_vel_mov
	if cansado:
		k *= float(mundo.combate.cfg.folego.lento_cansado)
	elif _quer_correr() and folego > 0.0:
		correndo = true
		k *= float(mundo.combate.cfg.corrida.velocidade)
		_gastar(float(mundo.combate.cfg.corrida.gasto) * dt)
		if cansado:  # o último fôlego acabou agora: para de correr na hora
			correndo = false
			k = VEL * m_vel_mov * float(mundo.combate.cfg.folego.lento_cansado)
		else:
			_poeira_t -= dt
			if _poeira_t <= 0.0:
				_poeira_t = float(mundo.combate.cfg.corrida.poeira_cada)
				mundo.combate.poeira(self)
	return v * k * dt


func _quer_correr() -> bool:
	if entrada_forcada != null:
		return correr_forcado != null and bool(correr_forcado)
	return InputMap.has_action("correr") and Input.is_action_pressed("correr")


## Pode esquivar agora? (não cansado e com fôlego para um rolamento)
func pode_esquivar() -> bool:
	return not cansado and folego >= float(mundo.combate.cfg.esquiva.gasto)


## Gasta fôlego; zerar deixa cansado. Gastar adia a recuperação.
func _gastar(x: float) -> void:
	folego = maxf(0.0, folego - x)
	_atraso_t = float(mundo.combate.cfg.folego.atraso)
	if folego <= 0.001 and not cansado:
		cansado = true
		correndo = false
		_ofego_t = 1.3
		mundo.combate.cansou(self)


## Recuperação: espera o atraso depois do último gasto; parado volta mais rápido do que andando. Cansado sai do cansaço ao passar de 30%.
func _recuperar(dt: float, parado: bool) -> void:
	var f: Dictionary = mundo.combate.cfg.folego
	if _atraso_t > 0.0:
		_atraso_t -= dt
	elif folego < folego_max:
		folego = minf(folego_max, folego + float(f.regen_parado if parado else f.regen_andando) * dt)
	if cansado:
		_ofego_t -= dt
		if _ofego_t <= 0.0:
			_ofego_t = 1.3
			mundo.combate.ofego(self)
		if folego >= float(f.cansado_ate) * folego_max:
			cansado = false


func _camera_adiantada(dt: float) -> void:
	var alvo := Vector2.ZERO
	if correndo and vel.length() > 1.0:
		alvo = vel.normalized() * float(mundo.combate.cfg.corrida.avanco_camera)
	avanco_camera = avanco_camera.lerp(alvo, 1.0 - exp(-3.5 * dt))


# ------------------------------------------------------------------ golpe


func _iniciar_golpe() -> void:
	var passos: Array = mundo.combate.cfg.golpe.passos
	golpe_i = proximo if (combo_t > 0.0 and proximo < passos.size()) else 0
	golpe_cfg = passos[golpe_i]
	golpe_dur = float(golpe_cfg.duracao) / m_vel_ataque
	golpe_t = 0.0
	golpe_acertou = false
	pedido_t = 0.0
	var d: Vector2 = mira_mundo - centro()
	golpe_dir = d.normalized() if d.length() > 2.0 else dir_olhar
	dir_olhar = golpe_dir
	estado = Estado.GOLPE
	golpes += 1
	_punch = 0.0
	mundo.combate.golpe_comecou(self, golpe_cfg, golpe_dir, golpe_dur)


func _golpe(dt: float, v: Vector2) -> Vector2:
	golpe_t += dt
	var p := golpe_t / golpe_dur
	var acerto := float(golpe_cfg.acerto_em)
	# cancela o fim do golpe com a esquiva
	if esq_pedido > 0.0 and p >= acerto and pode_esquivar():
		_encerrar_golpe(false)
		_iniciar_esquiva(v)
		return Vector2.ZERO
	var desl := Vector2.ZERO
	var t_av := golpe_dur * acerto
	if golpe_t < t_av:  # lunge: velocidade que cai linearmente até zero, a integral dá exatamente "avanco" px
		desl += golpe_dir * float(golpe_cfg.avanco) * 2.0 * (1.0 - golpe_t / t_av) / t_av * dt
	if v != Vector2.ZERO:
		desl += v * VEL * m_vel_mov * float(mundo.combate.cfg.heroi.mov_golpe) * dt
	if not golpe_acertou and p >= acerto:
		golpe_acertou = true
		_punch = 1.0
		mundo.combate.golpear(self, pos + ORIGEM_GOLPE, golpe_dir, golpe_cfg, golpe_i)
	# a ruptura pedida depois do acerto cancela o resto do golpe e carrega na hora (o mesmo padrão da esquiva)
	if rup_pedido_t > 0.0 and _rup_apos_acerto and pode_ruptura() and _segurando_ruptura():
		_encerrar_golpe(false)
		_iniciar_carga()
		return Vector2.ZERO
	if p >= 1.0:
		_encerrar_golpe(true)
	return desl


func _encerrar_golpe(natural: bool) -> void:
	var passos: Array = mundo.combate.cfg.golpe.passos
	estado = Estado.LIVRE
	if golpe_i + 1 < passos.size():
		proximo = golpe_i + 1
		combo_t = float(mundo.combate.cfg.golpe.janela_combo)
	else:
		proximo = 0
		combo_t = 0.0
		if natural:
			pausa_t = float(mundo.combate.cfg.golpe.pausa_fim_combo)


# ------------------------------------------------------------------ esquiva


func _iniciar_esquiva(v: Vector2) -> void:
	var cfg: Dictionary = mundo.combate.cfg.esquiva
	_gastar(float(cfg.gasto))
	esq_pedido = 0.0
	pedido_t = 0.0
	esq_t = 0.0
	estado = Estado.ESQUIVA
	esquivas += 1
	if v != Vector2.ZERO:
		esq_dir = v.normalized()
	else:
		var d: Vector2 = mira_mundo - centro()
		esq_dir = d.normalized() if d.length() > 2.0 else dir_olhar
	dir_olhar = esq_dir
	_esq_rastro = 0.0
	combo_t = 0.0
	proximo = 0
	mundo.combate.esquiva_comecou(self)


func _esquiva(dt: float) -> Vector2:
	esq_t += dt
	var p := esq_t / esq_dur
	_esq_rastro -= dt
	if _esq_rastro <= 0.0:
		_esq_rastro = 0.055
		mundo.combate.rastro_esquiva(self)
	if esq_t >= esq_dur:
		estado = Estado.LIVRE
		return esq_dir * VEL * m_vel_mov * float(mundo.combate.cfg.esquiva.velocidade) * 0.25 * dt
	# arranca rápido e desacelera no fim (o rolamento "agarra" o chão)
	var k := 1.35 - 0.7 * p
	return esq_dir * VEL * m_vel_mov * float(mundo.combate.cfg.esquiva.velocidade) * k * dt


# ------------------------------------------------------------------ ruptura (botão direito)


## Pode começar a carga agora? Só com o jogo rolando (nada de escolha, baú, morte, vitória, resultado nem pausa), recarga zerada e livre
## ou depois do acerto de um golpe. Esquiva e morto não iniciam.
func pode_ruptura() -> bool:
	var c = mundo.combate
	return (
		c.ruptura != null
		and rup_recarga <= 0.0
		and c.jogo == "jogando"
		and not c.pausado
		and not _pausa_aberta()
		and (estado == Estado.LIVRE or estado == Estado.GOLPE)
	)


## O menu de pausa (ESC) está aberto sobre a partida? Com ele aberto nada da ruptura começa nem continua.
func _pausa_aberta() -> bool:
	return mundo.pausa != null and mundo.pausa.aberto


## O botão da ruptura está segurado? Polling, como o atacar. Em modo forçado (testes e fotos) vale `ruptura_forcada`.
func _segurando_ruptura() -> bool:
	if entrada_forcada != null:
		return ruptura_forcada != null and bool(ruptura_forcada)
	return InputMap.has_action("ruptura") and Input.is_action_pressed("ruptura")


## Relógios da ruptura, no tempo do mundo (hit-stop e pausa congelam). Quando a recarga zera, avisa uma vez.
func _rup_relogios(dt: float) -> void:
	rup_pedido_t = maxf(0.0, rup_pedido_t - dt)
	rup_nega_t = maxf(0.0, rup_nega_t - dt)
	contragolpe_t = maxf(0.0, contragolpe_t - dt)
	if rup_recarga > 0.0:
		rup_recarga = maxf(0.0, rup_recarga - dt)
		if rup_recarga <= 0.0:
			mundo.combate.ruptura.pronta(self)


func _iniciar_carga() -> void:
	estado = Estado.CARGA
	rup_carga = 0.0
	rup_carga_t = 0.0
	rup_perfeita = false
	rup_pedido_t = 0.0
	_rup_apos_acerto = false
	pedido_t = 0.0
	combo_t = 0.0
	proximo = 0
	_rup_tique = 0
	_rup_us = Time.get_ticks_usec()


func _carga(dt: float, v: Vector2) -> Vector2:
	var c = mundo.combate
	var rp = c.ruptura
	var agora := Time.get_ticks_usec()
	# fora de partida, em pausa ou com o relógio saltando (ESC e perda de foco não passam por combate.pausado): cancela sem disparar
	if c.jogo != "jogando" or c.pausado or _pausa_aberta() or float(agora - _rup_us) / 1.0e6 > float(rp.cfg.salto_relogio):
		cancelar_ruptura(false)
		return Vector2.ZERO
	_rup_us = agora
	if esq_pedido > 0.0 and pode_esquivar():  # a esquiva é a saída da carga: cancela de graça e rola (cansado, a carga continua)
		cancelar_ruptura(false)
		_iniciar_esquiva(v)
		return Vector2.ZERO
	rup_carga_t += dt
	var cm: float = rp.carga_max(self)
	rup_carga = clampf(rup_carga_t / cm, 0.0, 1.0)
	rup_perfeita = rup_carga_t >= cm and rup_carga_t <= cm + float(rp.cfg.perfeito.janela)  # janela fixa em s: não encolhe com a velocidade de ataque
	var tiques: Array = rp.cfg.tiques
	while _rup_tique < tiques.size() and rup_carga >= float(tiques[_rup_tique]):
		rp.tique(self, _rup_tique)
		_rup_tique += 1
	if not _segurando_ruptura():
		_soltar()
		return Vector2.ZERO
	andando = v != Vector2.ZERO
	if not andando:
		return Vector2.ZERO
	if fonte == Fonte.ANDA:
		dir_olhar = v.normalized()
	return v * VEL * m_vel_mov * float(rp.cfg.mov_carga) * dt  # a 45%, também cansado, sem somar com o cansaço


## Soltou o botão: carga curta cancela (sem recarga); senão dispara com o f e o perfeito deste instante.
func _soltar() -> void:
	var rp = mundo.combate.ruptura
	if rup_carga_t < float(rp.cfg.carga_min):
		cancelar_ruptura(true)
		return
	var f := rup_carga
	var perfeito := rup_perfeita
	estado = Estado.LIVRE
	rup_carga = 0.0
	rup_carga_t = 0.0
	rup_perfeita = false
	rup_disparos += 1
	rp.disparar(self, f, perfeito)
	pausa_t = maxf(pausa_t, float(rp.cfg.pausa_pos))  # só impede o golpe, não impede andar
	_rup_punch = 1.0


## Desfaz a carga sem disparar e sem gastar recarga. Idempotente; `som` = toca o ruptura_cancela. Público: o combate chama na pausa.
func cancelar_ruptura(som := true) -> void:
	if estado != Estado.CARGA:
		return
	var rp = mundo.combate.ruptura
	if rp != null:
		rp.cancelou(self, som)
	estado = Estado.LIVRE
	rup_carga = 0.0
	rup_carga_t = 0.0
	rup_perfeita = false
	rup_pedido_t = 0.0
	rup_cancelados += 1


# ------------------------------------------------------------------ visual


func _visual(dt: float, v: Vector2) -> void:
	var l := linha_de(dir_olhar)
	var c := 0
	if estado == Estado.LIVRE and andando:
		_anim += dt * (1.45 if correndo else 1.0)
		c = 1 + int(_anim / PASSO_ANIM) % (int(tipo.info.colunas.size()) - 1)
	else:
		_anim = 0.0
	if l != linha or c != coluna:
		quadro(c, l)
	# corpo: o "soco" do golpe (esticada na direção do corte), o giro da esquiva e o pisca de quem acabou de apanhar
	var punch_k := 0.0
	if _punch > 0.0:
		_punch = maxf(0.0, _punch - dt / 0.16)
		punch_k = _punch
	var desloca := Vector2.ZERO
	var esc := Vector2.ONE
	if estado == Estado.GOLPE:
		var ant := clampf(golpe_t / (golpe_dur * float(golpe_cfg.acerto_em)), 0.0, 1.0)
		desloca = (golpe_dir * (-2.0 * (1.0 - ant) + 3.0 * punch_k)).round()  # puxa para trás e solta
		esc = Vector2(1.0 + 0.1 * punch_k, 1.0 - 0.07 * punch_k)
	elif estado == Estado.CARGA:  # agacha, treme um pixel na carga cheia
		esc = Vector2(1.0 + 0.05 * rup_carga, 1.0 - 0.09 * rup_carga)
		if rup_carga >= 1.0:
			desloca = Vector2(float(int(Time.get_ticks_msec() / 40.0) % 3 - 1), 0.0)
	if _rup_punch > 0.0:  # o soco do disparo: alarga e achata um instante
		_rup_punch = maxf(0.0, _rup_punch - dt / 0.12)
		esc = Vector2(lerpf(esc.x, 1.14, _rup_punch), lerpf(esc.y, 0.88, _rup_punch))
	if estado == Estado.ESQUIVA:
		var p := clampf(esq_t / esq_dur, 0.0, 1.0)
		var gira := signf(esq_dir.x) if absf(esq_dir.x) > 0.1 else 1.0
		sprite.position = Vector2(0, -14)
		sprite.offset = _off_base + Vector2(0, 14)
		sprite.rotation = gira * TAU * minf(p * 1.15, 1.0)
		esc = Vector2(1.0, 0.82)
	else:
		if sprite.rotation != 0.0:
			sprite.rotation = 0.0
			sprite.offset = _off_base
		sprite.position = desloca
	sprite.scale = esc
	var piscando := invenc > 0.0 and int(Time.get_ticks_msec() / 1000.0 * float(mundo.combate.cfg.heroi.pisca_hz) * 2.0) % 2 == 0
	if estado == Estado.ESQUIVA:
		sprite.modulate = Color(1, 1, 1, 0.78)
	elif piscando:
		sprite.modulate = Color(1, 0.55, 0.55, 0.38)
	elif estado == Estado.CARGA:
		sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.85, 0.65), rup_carga)  # o corpo esquenta com a carga
	else:
		sprite.modulate = Color.WHITE


func _visual_morto(dt: float) -> void:
	sprite.position = Vector2(0, -14)
	sprite.offset = _off_base + Vector2(0, 14)
	sprite.rotation = lerpf(sprite.rotation, 1.45 * (1.0 if dir_olhar.x >= 0 else -1.0), 1.0 - exp(-9.0 * dt))
	sprite.scale = Vector2.ONE
	sprite.modulate = Color(1, 0.8, 0.8, 0.85)


## Linhas da folha: baixo, esquerda, direita, cima, baixo_esq, baixo_dir, cima_esq, cima_dir. As 8 direções saem do ângulo na tela.
static func linha_de(v: Vector2) -> int:
	const POR_OITANTE := [2, 5, 0, 4, 1, 6, 3, 7]  # 0 = direita, 1 = baixo-direita, 2 = baixo... (y para baixo, sentido horário)
	var oitante := posmod(int(round(v.angle() / (PI / 4.0))), 8)
	return POR_OITANTE[oitante]

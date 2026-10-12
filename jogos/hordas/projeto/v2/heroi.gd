extends "res://v2/ator.gd"
## Herói da v2 (o escolhido no santuário: Hazaki, Nicão ou Lucas, v2/herois.gd; os números vêm do cfg dele): anda com WASD, setas e analógico esquerdo; fica virado para o MOUSE (8 direções) quando o mouse mexe, e para onde
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
## API pública lida pelo HUD (get() com padrão): vida, vida_max, xp, xp_proximo, nivel, folego, folego_max, cansado (bool), correndo (bool).

const Herois := preload("res://v2/herois.gd")

enum Fonte { ANDA, MOUSE, STICK }
enum Estado { LIVRE, GOLPE, ESQUIVA, MORTO }
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
var vel_base := VEL  # px/s de andar do herói escolhido (cfg.heroi.vel, v2/herois.gd); o VEL é só o padrão

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
	chave = str(mundo.combate.heroi_id)  # o herói escolhido (v2/herois.gd): a folha de sprites já vem em `t`
	raio = float(Herois.heroi(chave).get("raio", 6.0))
	montar_animado(pai, t, p, 0, 0, false)
	_off_base = sprite.offset


## Lê as vidas e as regras do dados/v2_combate.json (chamado pelo combate depois de criar o herói).
func iniciar_stats(cfg: Dictionary) -> void:
	vel_base = float(cfg.heroi.get("vel", VEL))
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


func entrada_evento(e: InputEvent) -> void:
	if e.is_action_pressed("atacar", false, true):
		atacar()
	elif InputMap.has_action("esquiva") and e.is_action_pressed("esquiva", false, true):
		esquivar()


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


## Velocidade de andar (px/s) com o bônus de movimento, e a de correr. O card de status (status.gd) lê estas duas; `_livre` anda com elas.
## Velocidade de andar (px/s): a base do herói escolhido (cfg.heroi.vel) com o modificador de movimento das cartas.
func vel_andar() -> float:
	return vel_base * m_vel_mov


func vel_correr() -> float:
	return vel_andar() * float(mundo.combate.cfg.corrida.velocidade)


## Alcance do ímã de almas (px): a distância em que o orbe começa a voar para o herói (combate.atualizar).
func alcance_ima() -> float:
	return float(mundo.combate.cfg.heroi.ima_raio) * m_ima


## Duração (s) do passo `i` do combo com a velocidade de ataque de agora.
func duracao_do_passo(i: int) -> float:
	return float(mundo.combate.cfg.golpe.passos[i].duracao) / m_vel_ataque


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
	_recuperar(dt, v == Vector2.ZERO and estado == Estado.LIVRE)
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
	if (pedido_t > 0.0 or segurando) and pausa_t <= 0.0:  # o golpe tem prioridade sobre a corrida
		_iniciar_golpe()
		return Vector2.ZERO
	if not andando:
		return Vector2.ZERO
	if fonte == Fonte.ANDA:
		dir_olhar = v.normalized()
	var k := vel_andar()
	if cansado:
		k *= float(mundo.combate.cfg.folego.lento_cansado)
	elif _quer_correr() and folego > 0.0:
		correndo = true
		k = vel_correr()
		_gastar(float(mundo.combate.cfg.corrida.gasto) * dt)
		if cansado:  # o último fôlego acabou agora: para de correr na hora
			correndo = false
			k = vel_andar() * float(mundo.combate.cfg.folego.lento_cansado)
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
	golpe_dur = duracao_do_passo(golpe_i)
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
		desl += golpe_dir * float(golpe_cfg.get("avanco", 0.0)) * 2.0 * (1.0 - golpe_t / t_av) / t_av * dt
	if v != Vector2.ZERO:
		desl += v * vel_base * m_vel_mov * float(mundo.combate.cfg.heroi.mov_golpe) * dt
	if not golpe_acertou and p >= acerto:
		golpe_acertou = true
		_punch = 1.0
		mundo.combate.golpear(self, pos + ORIGEM_GOLPE, golpe_dir, golpe_cfg, golpe_i)
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
		return esq_dir * vel_base * m_vel_mov * float(mundo.combate.cfg.esquiva.velocidade) * 0.25 * dt
	# arranca rápido e desacelera no fim (o rolamento "agarra" o chão)
	var k := 1.35 - 0.7 * p
	return esq_dir * vel_base * m_vel_mov * float(mundo.combate.cfg.esquiva.velocidade) * k * dt


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

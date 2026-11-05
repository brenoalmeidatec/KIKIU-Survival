extends RefCounted
## IMPULSO do mecha do LightWolf (pedido do Alisson, 05/11: "Shift correr do Mecha deve funcionar como um especial do lado do E no HUD"; os propulsores da D.Va do
## Overwatch são só a referência de função, nada de nome, arte ou som). Só o MECHA tem: o bloco `impulso` está no cfg do lightwolf (dados/v2_herois.json), que
## vira `combate.cfg.impulso`; o Lobo tem cfg próprio e não o recebe, e nenhum outro herói tem o bloco (para eles o Shift continua sendo correr).
##  - APERTO da ação "correr" (Shift/L3; em teste, `correr_forcado`) com o impulso pronto: por `dur` s o mecha VOA em `vel` px/s. A direção vira, a `giro` rad/s,
##    para onde as teclas de andar apontam, ou para a mira quando nenhuma está apertada. Soltar não para: o voo acaba sozinho no fim de `dur`, ao virar Lobo
##    (quebra ou Q) e em qualquer estado que não seja LIVRE, GOLPE ou HABILIDADE. A recarga (`recarga` s) começa quando o voo acaba. Aperto na recarga = negado.
##  - FLUTUA: o desenho sobe `alt_px` px inteiros (sobe e desce em `subida` s, com curva) e boia 1 px no topo; a sombra fica no chão, mas encolhe e clareia ao subir
##    (Ator.ar); os propulsores nas costas (v2/propulsor.gd) acendem durante o voo, mais fortes na decolagem; o clarão do cano e a boca das bolinhas sobem junto (Heroi.alt_px).
##  - OBSTÁCULO BAIXO: objeto com largura de colisão até `larg_obstaculo` px não segura o mecha voando (v2/colisao.gd diz quais); se o voo acabar em cima de um,
##    o mecha segue passando por objetos baixos até sair de todos (sem pulo de empurrão). Os grandes seguram como sempre.
##  - POR CIMA DOS MONSTROS: o corpo do mecha não afasta ninguém (mundo.gd avisa os monstros com `por_cima`; o anel de cerco da IA segue com o raio real) e os empurrões que ele leva não o tiram da rota.
##    Cada monstro atravessado (raio do herói + raio dele + `alcance`) leva `dano` (vezes o dano do herói) a cada `intervalo` s; o toque NUNCA mata: para em 1 de vida
##    (chefe e elite também) e não empurra. Conta como fonte "impulso" na tela de fim.
##  - Contrato com o canhão e a Matriz (como a D.Va): o canhão atira e a E (mísseis) sai durante o voo; a Matriz não ergue (se estava erguida, cai) e a esquiva não sai.
##  - HUD: o herói publica imp_nome ("" = sem impulso nesta forma: o slot do Shift some), imp_t, imp_dur, imp_recarga, imp_recarga_max e imp_nega_t (v2/hud_habilidades.gd).
## Sem nó novo: um dicionário de "último toque" por monstro, zerado a cada voo.
##
##  - OBJETO GRANDE: segura e o mecha desliza nele (a colisão de sempre); na encostada sai um estalo de poucas faíscas (sem flash; nada no perfil Baixo).
##  - ORDEM DE DESENHO no ar: o mecha é desenhado por cima de quem sobrevoa (ordem(h), Ator.ordem_px), mas não de árvore e objeto grande.
## API: montar(c), cfg(), para(h), relogios(h, dt), quadro(h, dt, v) -> Vector2, depois_de_mover(h, desl, andou), larg_ignora(h), encerrar(h), alt(h) -> int,
## ordem(h) -> int, limpar().

const Colisao := preload("res://v2/colisao.gd")

var combate
var mundo
var toques := 0  # testes e calibragem: quantos toques de contato feriram na partida
var poupados := 0  # toques que não feriram porque o monstro já estava em 1 de vida (o impulso nunca mata)
var voos := 0  # quantos impulsos saíram
var _ultimo := {}  # monstro -> instante (relógio do voo) do último toque nele; zerado a cada voo
var _poeira_t := 0.0
var _raspando := false  # o voo estava encostado num objeto grande no quadro anterior (o estalo sai só na encostada)
var _estalo_em := -INF  # relógio do voo do último estalo (zerado a cada voo): não repete antes de `estalo_intervalo` s
var estalos := 0  # quantos estalos saíram (para os testes; conta também os do perfil Baixo, que não desenham)


func montar(c) -> void:
	combate = c
	mundo = c.mundo


func limpar() -> void:
	_ultimo.clear()
	toques = 0
	poupados = 0
	voos = 0
	estalos = 0
	_raspando = false
	_estalo_em = -INF


## O bloco do impulso da forma de agora ({} = esta forma não tem: o Lobo e todos os outros heróis).
func cfg() -> Dictionary:
	if combate == null or not (combate.cfg is Dictionary):
		return {}
	var c = combate.cfg.get("impulso", {})
	return c if c is Dictionary else {}


## O herói tem o impulso agora (o mecha do LightWolf)?
func para(h) -> bool:
	return not h.forma_lobo and not cfg().is_empty()


## Os relógios, todo quadro (Heroi.atualizar): recarga e negado correm, o aperto do Shift dispara (ou é negado) e o voo acaba se o estado não deixa voar.
## Publica o nome para a HUD (sem impulso: "").
func relogios(h, dt: float) -> void:
	var c := cfg()
	var tem := para(h)
	h.imp_nome = str(c.get("nome", "IMPULSO")) if tem else ""
	h.imp_recarga = maxf(0.0, h.imp_recarga - dt)
	h.imp_nega_t = maxf(0.0, h.imp_nega_t - dt)
	var apertado: bool = h._quer_correr()
	var aperto: bool = apertado and not h._imp_ant
	h._imp_ant = apertado
	if h.imp_t > 0.0 and (not tem or not _estado_voa(h) or combate.jogo != "jogando"):
		encerrar(h)
	if not aperto or not tem or combate.jogo != "jogando" or combate.pausado:
		return
	if h.imp_t > 0.0:
		return  # já voando: apertar de novo não faz nada (nem nega)
	if h.imp_recarga > 0.0 or not _estado_voa(h):
		h.imp_nega_t = 0.3
		return
	_iniciar(h, c)


func _estado_voa(h) -> bool:
	return h.estado == h.Estado.LIVRE or h.estado == h.Estado.GOLPE or h.estado == h.Estado.HABILIDADE


func _iniciar(h, c: Dictionary) -> void:
	h.imp_dur = float(c.get("dur", 3.0))
	h.imp_t = h.imp_dur
	h.imp_relogio = 0.0
	h._imp_larg = float(c.get("larg_obstaculo", 0.0))
	var v: Vector2 = h.entrada_forcada if h.entrada_forcada != null else Input.get_vector("esquerda", "direita", "cima", "baixo")
	h.imp_dir = v.normalized() if v != Vector2.ZERO else h.dir_olhar.normalized()
	if h.imp_dir == Vector2.ZERO:
		h.imp_dir = Vector2.RIGHT
	h.correndo = false
	h._baixar_escudo()  # a Matriz cai: não ergue durante o voo
	_ultimo.clear()
	_poeira_t = 0.0
	_estalo_em = -INF
	voos += 1
	combate.audio.tocar("esquiva", 0.6, 0.0, 0.0)


## O deslocamento do voo neste quadro (substitui o andar em LIVRE, GOLPE e HABILIDADE). Gasta o tempo do voo e o encerra no fim.
func quadro(h, dt: float, v: Vector2) -> Vector2:
	var c := cfg()
	var alvo: Vector2 = v.normalized() if v != Vector2.ZERO else h.dir_olhar
	if alvo != Vector2.ZERO:
		var giro := float(c.get("giro", 5.0)) * dt
		h.imp_dir = h.imp_dir.rotated(clampf(h.imp_dir.angle_to(alvo), -giro, giro))
	var usado := minf(dt, h.imp_t)
	h.imp_t = maxf(0.0, h.imp_t - dt)
	h.imp_relogio += dt
	h.emp = Vector2.ZERO  # o voo não é desviado pelo que o mecha leva
	h.andando = false  # flutua: o desenho fica na pose parada, não anda no ar
	_poeira(h, c, dt)
	var desl: Vector2 = h.imp_dir * float(c.get("vel", 220.0)) * h.m_vel_mov * usado
	if h.imp_t <= 0.0:
		encerrar(h)
	return desl


## O impulso acabou (tempo, troca de forma, estado): começa a recarga. Se o mecha parou em cima de um objeto baixo, segue passando por objetos baixos até sair.
func encerrar(h) -> void:
	if h.imp_t <= 0.0 and h.imp_relogio <= 0.0:
		return
	h.imp_t = 0.0
	h.imp_relogio = 0.0
	if h.propulsor != null:
		h.propulsor.esconder()  # os jatos nas costas somem com o voo
	h.imp_recarga = float(cfg().get("recarga", 5.0)) if para(h) else float(h.imp_recarga_max)
	h.imp_recarga_max = maxf(h.imp_recarga, 0.001)
	h._imp_saindo = not Colisao.livre(h.pos, h.raio)
	_ultimo.clear()


## A largura (px) dos objetos que não seguram o corpo neste quadro: a do cfg voando ou saindo de cima de um objeto baixo; 0 andando.
func larg_ignora(h) -> float:
	if h.imp_t > 0.0 or h._imp_saindo:
		return h._imp_larg  # gravado no início do voo: saindo de cima já como Lobo (cfg sem o bloco) vale o mesmo limite
	return 0.0


## Depois de mover (Heroi.atualizar): o contato com os monstros atravessados, o estalo ao raspar num objeto grande e o fim do "saindo de cima".
## `desl` é o que o voo pediu neste quadro e `andou`, o que a colisão deixou.
func depois_de_mover(h, desl := Vector2.ZERO, andou := Vector2.ZERO) -> void:
	if h._imp_saindo and h.imp_t <= 0.0:
		h._imp_saindo = not Colisao.livre(h.pos, h.raio)
	if h.imp_t > 0.0:
		_contato(h)
		_raspar(h, desl, andou)
	else:
		_raspando = false


## O ESTALO do contato: no quadro em que o voo encosta num objeto grande (a colisão comeu parte do passo e o corpo toca uma forma sólida), umas
## poucas faíscas (`estalo_faiscas`) saem do ponto de contato, uma vez por encostada e no máximo uma a cada `estalo_intervalo` s (num contorno
## curvo a encostada liga e desliga: sem o intervalo viravam estalos seguidos); o deslize continua. Sem flash nem luz (nada pisca). No perfil
## Baixo (partículas abaixo de 0,5) as faíscas saem com desenhar=false: nenhuma partícula, mas o mesmo consumo de randf() da convenção de
## v2/efeitos.gd (o robô de playtest semeia o RNG global e não pode divergir por perfil só por isso).
func _raspar(h, desl: Vector2, andou: Vector2) -> void:
	var comido := desl - andou
	var raspa := desl.length_squared() > 0.25 and comido.length_squared() > desl.length_squared() * 0.0625
	raspa = raspa and not Colisao.livre(h.pos, h.raio + 1.0, h._imp_larg)
	if raspa and not _raspando and h.imp_relogio - _estalo_em >= float(cfg().get("estalo_intervalo", 0.25)):
		var n := int(cfg().get("estalo_faiscas", 0))
		if n > 0:
			_estalo_em = h.imp_relogio
			estalos += 1
			var cor_a: Array = cfg().get("cor", [0.75, 0.95, 1.0])
			var dir := -comido.normalized()
			combate.fx.faiscas(
				h.pos + comido.normalized() * float(h.raio) - Vector2(0.0, float(alt(h))),
				dir,
				n,
				Color(float(cor_a[0]), float(cor_a[1]), float(cor_a[2])),
				90.0,
				combate.fx.fator_part >= 0.5
			)
	_raspando = raspa


func _contato(h) -> void:
	var c := cfg()
	var intervalo := float(c.get("intervalo", 0.5))
	var dano: float = float(c.get("dano", 8.0)) * h.m_dano
	var extra := float(c.get("alcance", 4.0))
	var cor_a: Array = c.get("cor", [0.75, 0.95, 1.0])
	var cor := Color(float(cor_a[0]), float(cor_a[1]), float(cor_a[2]))
	var antes: String = combate.fonte_dano
	combate.fonte_dano = "impulso"
	for m in mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var d: Vector2 = m.pos - h.pos
		var lim: float = float(h.raio) + float(m.raio) + extra
		if d.length_squared() > lim * lim:
			continue
		if _ultimo.has(m) and h.imp_relogio - float(_ultimo[m]) < intervalo:
			continue
		_ultimo[m] = h.imp_relogio
		var cabe := floorf(float(m.vida) - 1.0)  # nunca mata: o dano para em 1 de vida
		if cabe < 1.0:
			poupados += 1
			continue
		# sem o flash branco do acerto: ele sai na camada de brilho, POR CIMA de tudo, e o monstro sobrevoado piscaria em cima do mecha (lia
		# como "o mecha passou por trás", vídeo da rodada 4); fica só o número de dano
		var dn := maxi(1, roundi(minf(dano, cabe)))
		combate.ferir(m, float(dn), d.normalized() if d != Vector2.ZERO else h.imp_dir, 0.0, 0.0, cor, false)
		combate.fx.numero(m.pos + Vector2(0, -float(m.alt) * 0.8), str(dn), cor, false)
		toques += 1
	combate.fonte_dano = antes


## Poeira do propulsor (a mesma da corrida), só com partículas ligadas: o perfil Baixo não ganha partícula nova.
func _poeira(h, c: Dictionary, dt: float) -> void:
	if combate.fx.fator_part < 0.5:
		return
	_poeira_t -= dt
	if _poeira_t <= 0.0:
		_poeira_t = float(c.get("poeira_cada", 0.05))
		combate.poeira(h)


## Px inteiros que o desenho do herói sobe agora: `alt_px` x a curva da subida, mais a FLUTUAÇÃO de `flutua_px` px (um seno lento, só no topo: sem
## tremer, são 1 ou 2 degraus por segundo). Tudo em px inteiros; sem sorteio (a flutuação é função do relógio do voo).
func alt(h) -> int:
	var c := cfg()
	var k := _subida(h)
	var flutua := float(c.get("flutua_px", 1.0)) * sin(TAU * float(c.get("flutua_hz", 0.56)) * h.imp_relogio) * k * k
	return roundi(float(c.get("alt_px", 14)) * k + flutua)


## A força da chama dos propulsores (v2/propulsor.gd): 2 na decolagem (primeiros `propulsor.decolagem_s` s do voo), 0 na descida (últimos `subida` s), 1 no cruzeiro.
func forca(h) -> int:
	var c := cfg()
	if h.imp_relogio < float(c.get("propulsor", {}).get("decolagem_s", 0.5)):
		return 2
	return 0 if h.imp_t < float(c.get("subida", 0.35)) else 1


## Quanto do voo está no ar agora (0 no chão, 1 lá em cima), com curva: a decolagem arranca rápido e assenta no topo (ease-out), o pouso é suave dos dois
## lados (smoothstep). Sobe em `subida` s no começo e desce nos últimos `subida` s.
func _subida(h) -> float:
	if h.imp_t <= 0.0:
		return 0.0
	var s := maxf(float(cfg().get("subida", 0.35)), 0.001)
	var sobe := clampf(h.imp_relogio / s, 0.0, 1.0)
	var desce := clampf(h.imp_t / s, 0.0, 1.0)
	if sobe <= desce:
		return 1.0 - (1.0 - sobe) * (1.0 - sobe)
	return desce * desce * (3.0 - 2.0 * desce)


## Px inteiros que a ORDEM DE DESENHO do mecha desce abaixo dos pés agora (Ator.ordem_px; o desenho e a física não mudam). No ar ele fica por
## cima de quem sobrevoa: monstros, elites e objetos baixos com os pés até `ordem_px` px mais para baixo na tela são desenhados ATRÁS dele (e a
## silhueta de oclusão não acende por eles). Acompanha a subida e a descida (nada de salto de ordem no pouso: quem estava atrás volta para a frente
## de baixo para cima nos `subida` s finais). Objeto GRANDE (largura de colisão acima de `larg_obstaculo`, que segura o voo) não é sobrevoado: com
## um deles na frente, com o TRONCO perto do mecha na horizontal, a ordem para 1 px acima do pé dele, a mesma do chão (o mecha não passa por
## cima do tronco nem atravessa ele ao raspar). O tronco é a largura de colisão (`larg_col`), não a caixa do sprite com a copa (que travava a
## ordem a ~136 px do pé, revisão da rodada 5), alargada de cada lado pelo que o voo anda numa `subida` (vel x subida): é a folga para a rampa.
## RAMPA: com `dt` > 0 (o quadro do Heroi._visual) a ordem anda no máximo ordem_px/subida px por segundo (+1 px de arredondamento) a partir de
## h.ordem_px, a mesma velocidade do pouso: chegar perto ou sair de perto de um tronco não salta de ordem num quadro. dt 0 = o alvo direto.
func ordem(h, dt := 0.0) -> int:
	var c := cfg()
	var maximo := float(c.get("ordem_px", 0))
	var o := roundi(maximo * _subida(h))
	if o > 0 and mundo != null and mundo.get("cenario") != null:
		var y0: float = h.pr.y
		var meio_w := float(c.get("corpo_meia_larg", float(h.tipo.get("w", 0.0)) * 0.5))  # o corpo desenhado, não o quadro de 128 px da folha
		var folga := float(c.get("vel", 0.0)) * float(h.m_vel_mov) * float(c.get("subida", 0.35))
		var faixa := float(o)
		for a in mundo.cenario.ativos:
			if a.larg_col <= h._imp_larg:
				continue
			var p: Vector2 = a.raiz.position
			if p.y <= y0 or p.y > y0 + faixa:
				continue
			if absf(p.x - h.pr.x) > a.larg_col * 0.5 + meio_w + folga:  # o tronco não chega perto do mecha: a ordem entre os dois não aparece
				continue
			o = mini(o, ceili(p.y - y0) - 1)
		o = maxi(o, 0)
	o = maxi(o, 0)
	if dt > 0.0:
		var s := maxf(float(c.get("subida", 0.35)), 0.001)
		var passo := ceili(maximo * dt / s) + 1
		o = clampi(o, int(h.ordem_px) - passo, int(h.ordem_px) + passo)
		if h.imp_t <= 0.0:
			o = mini(o, int(h.ordem_px))  # fora do voo só desce
	return maxi(o, 0)

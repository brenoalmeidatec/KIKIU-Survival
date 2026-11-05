extends RefCounted
## IMPULSO do mecha do LightWolf (pedido do Alisson, 05/11: "Shift correr do Mecha deve funcionar como um especial do lado do E no HUD"; os propulsores da D.Va do
## Overwatch são só a referência de função, nada de nome, arte ou som). Só o MECHA tem: o bloco `impulso` está no cfg do lightwolf (dados/v2_herois.json), que
## vira `combate.cfg.impulso`; o Lobo tem cfg próprio e não o recebe, e nenhum outro herói tem o bloco (para eles o Shift continua sendo correr).
##  - APERTO da ação "correr" (Shift/L3; em teste, `correr_forcado`) com o impulso pronto: por `dur` s o mecha VOA em `vel` px/s. A direção vira, a `giro` rad/s,
##    para onde as teclas de andar apontam, ou para a mira quando nenhuma está apertada. Soltar não para: o voo acaba sozinho no fim de `dur`, ao virar Lobo
##    (quebra ou Q) e em qualquer estado que não seja LIVRE, GOLPE ou HABILIDADE. A recarga (`recarga` s) começa quando o voo acaba. Aperto na recarga = negado.
##  - FLUTUA: o desenho sobe `alt_px` px inteiros (sobe e desce em `subida` s), a sombra fica no chão; o clarão do cano e a boca das bolinhas sobem junto (Heroi.alt_px).
##  - OBSTÁCULO BAIXO: objeto com largura de colisão até `larg_obstaculo` px não segura o mecha voando (v2/colisao.gd diz quais); se o voo acabar em cima de um,
##    o mecha segue passando por objetos baixos até sair de todos (sem pulo de empurrão). Os grandes seguram como sempre.
##  - POR CIMA DOS MONSTROS: o corpo do mecha não afasta ninguém (mundo.gd passa raio 0 aos monstros) e os empurrões que ele leva não o tiram da rota.
##    Cada monstro atravessado (raio do herói + raio dele + `alcance`) leva `dano` (vezes o dano do herói) a cada `intervalo` s; o toque NUNCA mata: para em 1 de vida
##    (chefe e elite também) e não empurra. Conta como fonte "impulso" na tela de fim.
##  - Contrato com o canhão e a Matriz (como a D.Va): o canhão atira e a E (mísseis) sai durante o voo; a Matriz não ergue (se estava erguida, cai) e a esquiva não sai.
##  - HUD: o herói publica imp_nome ("" = sem impulso nesta forma: o slot do Shift some), imp_t, imp_dur, imp_recarga, imp_recarga_max e imp_nega_t (v2/hud_habilidades.gd).
## Sem nó novo: um dicionário de "último toque" por monstro, zerado a cada voo.
##
## API: montar(c), cfg(), para(h), relogios(h, dt), quadro(h, dt, v) -> Vector2, depois_de_mover(h), larg_ignora(h), encerrar(h), alt(h) -> int, limpar().

const Colisao := preload("res://v2/colisao.gd")

var combate
var mundo
var toques := 0  # testes e calibragem: quantos toques de contato feriram na partida
var poupados := 0  # toques que não feriram porque o monstro já estava em 1 de vida (o impulso nunca mata)
var voos := 0  # quantos impulsos saíram
var _ultimo := {}  # monstro -> instante (relógio do voo) do último toque nele; zerado a cada voo
var _poeira_t := 0.0


func montar(c) -> void:
	combate = c
	mundo = c.mundo


func limpar() -> void:
	_ultimo.clear()
	toques = 0
	poupados = 0
	voos = 0


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
	h.imp_recarga = float(cfg().get("recarga", 5.0)) if para(h) else float(h.imp_recarga_max)
	h.imp_recarga_max = maxf(h.imp_recarga, 0.001)
	h._imp_saindo = not Colisao.livre(h.pos, h.raio)
	_ultimo.clear()


## A largura (px) dos objetos que não seguram o corpo neste quadro: a do cfg voando ou saindo de cima de um objeto baixo; 0 andando.
func larg_ignora(h) -> float:
	if h.imp_t > 0.0 or h._imp_saindo:
		return h._imp_larg  # gravado no início do voo: saindo de cima já como Lobo (cfg sem o bloco) vale o mesmo limite
	return 0.0


## Depois de mover (Heroi.atualizar): o contato com os monstros atravessados e o fim do "saindo de cima".
func depois_de_mover(h) -> void:
	if h._imp_saindo and h.imp_t <= 0.0:
		h._imp_saindo = not Colisao.livre(h.pos, h.raio)
	if h.imp_t > 0.0:
		_contato(h)


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
		combate.ferir(m, minf(dano, cabe), d.normalized() if d != Vector2.ZERO else h.imp_dir, 0.0, 0.0, cor)
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


## Px inteiros que o desenho do herói sobe agora: sobe em `subida` s no começo do voo e desce nos últimos `subida` s.
func alt(h) -> int:
	if h.imp_t <= 0.0:
		return 0
	var c := cfg()
	var s := maxf(float(c.get("subida", 0.15)), 0.001)
	var k := minf(clampf(h.imp_relogio / s, 0.0, 1.0), clampf(h.imp_t / s, 0.0, 1.0))
	return roundi(float(c.get("alt_px", 5)) * k)

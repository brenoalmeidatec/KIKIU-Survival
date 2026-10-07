extends Node
## Provisões da corrida (#72, marcos 3 e 4): o que o herói levou na mochila, já em ação. Comida (bônus pelos primeiros N andares),
## amuleto (passivo a corrida toda) e consumíveis (teclas 1, 2 e 3; L3 usa e R3 troca no controle). arena.stat() soma bonus().
## As regras e o catálogo ficam em mochila.gd / dados/itens.json. Herói sem mochila: nada acontece (o nó nem é criado).
##
## Online: quem usa um consumível PEDE ao anfitrião (Rede.avisar "usar"); ele confere contra a mochila que aceitou e conta os usos
## (online.gd), e só então manda o evento "consumivel" pra todos. O efeito no corpo de quem usou (cura, escudo, buff, bomba) roda
## nele quando o evento chega; o que mexe no mundo dos vírus e é decidido pelo anfitrião (gelo) roda nele (Mochila.aplicar_mundo).

const Mochila := preload("res://scripts/hordas/mochila.gd")

var arena: Node
var m := {}                  # a mochila (validada) que o herói trouxe
var restantes := {}          # consumível -> unidades que ainda tem
var slots: Array = []        # consumíveis na ordem das teclas 1, 2, 3 (fixa a corrida toda)
var amuleto := ""
var comidas: Array = []
var buffs: Array = []        # {id, t, tmax, bonus}: poções ativas
var achados: Array = []      # itens achados na corrida: só voltam pro baú se o herói vencer
var usos := {}               # consumível -> quantos já usou (tela de fim)
var sel := 0                 # controle: o consumível escolhido (R3 troca, L3 usa)
var fenix_gasta := false
var _soma := {}              # bônus de atributos já somados (atualiza quando algo muda)
var _andar := -1
var _pend := 0.0             # online: espera a resposta do anfitrião antes de pedir de novo
var _bot_t := 0.0
var _trapaca := false         # teste (--trapaca): pede consumível mesmo sem ter, pra ver o anfitrião recusar
var _t := 0.0


func configurar(a: Node, mochila: Dictionary) -> void:
	arena = a
	m = mochila
	slots = Mochila.slots(m)
	for id in slots:
		restantes[id] = int(m.itens[id])
	amuleto = str(m.get("amuleto", ""))
	_trapaca = "--trapaca" in OS.get_cmdline_user_args() or "--trapaca" in OS.get_cmdline_args()
	comidas = Mochila.comidas(m)
	_recalcular()


func tem() -> bool:
	return not slots.is_empty() or amuleto != "" or not comidas.is_empty()


func _andar_atual() -> int:
	return int(arena.diretor.fase_idx) if arena and arena.diretor else 0


## Soma os bônus que valem agora: comida (enquanto o andar está dentro dos "andares" dela), amuleto e poções ativas.
func _recalcular() -> void:
	_andar = _andar_atual()
	_soma = {}
	for id in comidas:
		var d := Mochila.item(id)
		if _andar < int(d.get("andares", 5)):
			_somar(d.get("bonus", {}))
	if amuleto != "":
		_somar(Mochila.item(amuleto).get("bonus", {}))
	for b in buffs:
		_somar(b.bonus)


func _somar(b: Dictionary) -> void:
	for k in b:
		_soma[k] = float(_soma.get(k, 0.0)) + float(b[k])


func bonus(k: String) -> float:
	return float(_soma.get(k, 0.0))


## Comidas que ainda estão fazendo efeito (a tela de fim e o HUD mostram).
func comidas_ativas() -> Array:
	return comidas.filter(func(id): return _andar < int(Mochila.item(id).get("andares", 5)))


## O que sobrou pra levar de volta pra casa (só se vencer): consumíveis não usados e o amuleto.
func sobra() -> Dictionary:
	var itens := {}
	for id in restantes:
		if int(restantes[id]) > 0:
			itens[id] = int(restantes[id])
	return {"itens": itens, "amuleto": amuleto}


## Achou um item na corrida (baú). Vai pra bolsa de achados, até o limite de "trazer_max".
func achar(id: String) -> bool:
	if Mochila.item(id).is_empty() or achados.size() >= int(Mochila.cfg().get("trazer_max", 3)):
		return false
	achados.append(id)
	return true


func atualizar(dt: float) -> void:
	_t += dt
	_pend = maxf(0.0, _pend - dt)
	var mudou := _andar != _andar_atual()
	for b in buffs.duplicate():
		b.t -= dt
		if b.t <= 0.0:
			buffs.erase(b)
			mudou = true
	if mudou:
		_recalcular()
	if slots.is_empty() or not _pode_agir():
		return
	var i := _escolha()
	if i >= 0:
		pedir(i)


func _pode_agir() -> bool:
	var jog: Node2D = arena.jogador
	if jog.hp <= 0 or arena.caido or arena.acabou or arena.duelo_ativo or arena.pre_duelo:
		return false
	if arena.bot:
		return true
	return not (arena.cartas.aberto() or arena.hud._pausado or Chat.digitando)


## Qual slot o jogador (ou o robô) quer usar agora (-1 = nenhum).
func _escolha() -> int:
	if arena.bot:
		return _bot()
	for i in mini(slots.size(), 3):
		if Input.is_action_just_pressed("consumivel%d" % (i + 1)):
			return i
	if Input.is_action_just_pressed("consumivel_trocar"):
		sel = (sel + 1) % slots.size()
		Som.ui("cursor")
	elif Input.is_action_just_pressed("consumivel_usar"):
		return sel
	return -1


## O robô de teste usa o que levou quando faz sentido: cura com a vida baixa, bomba e gelo com bicho demais por perto.
func _bot() -> int:
	_bot_t -= get_process_delta_time()
	if _bot_t > 0.0:
		return -1
	_bot_t = 0.5
	if arena.eh_online:   # teste online: usa um consumível a cada 2,5 s pra exercitar o pedido e a conferência do anfitrião
		if _t < 4.0:
			return -1
		_bot_t = 2.5
		for i in slots.size():
			if _trapaca or int(restantes.get(slots[i], 0)) > 0:
				return i
		return -1
	var jog: Node2D = arena.jogador
	var c: Vector2 = jog.centro()
	var perto: int = arena.inimigos.no_circulo(c, 110.0).size()
	for i in slots.size():
		if int(restantes.get(slots[i], 0)) <= 0:
			continue
		var tipo := str(Mochila.item(slots[i]).get("efeito", {}).get("tipo", ""))
		match tipo:
			"cura":
				if jog.hp < jog.vida_max() * 0.55:
					return i
			"escudo":
				if jog.hp < jog.vida_max() * 0.4 and perto >= 3:
					return i
			"explosao", "lento", "buff":
				if perto >= 5:
					return i
			"ima":
				if arena.diretor.tempo > 20.0:
					return i
	return -1


func pode(slot: int) -> bool:
	return slot >= 0 and slot < slots.size() and (_trapaca or int(restantes.get(slots[slot], 0)) > 0) and _pend <= 0.0


## Pede pra usar o consumível do slot. Solo: usa na hora. Online: pede ao anfitrião, que confere e manda o evento.
func pedir(slot: int) -> void:
	if not pode(slot):
		return
	if arena.eh_online:
		_pend = 0.5
		Rede.avisar("usar", float(slot))
	else:
		consumir(slots[slot])


## Gasta uma unidade e aplica o efeito no corpo de quem usou. Solo: chamada direto. Online: quando o evento do anfitrião chega.
func consumir(id: String) -> void:
	if int(restantes.get(id, 0)) <= 0:
		return
	_pend = 0.0
	restantes[id] = int(restantes[id]) - 1
	usos[id] = int(usos.get(id, 0)) + 1
	var d := Mochila.item(id)
	var ef: Dictionary = d.get("efeito", {})
	var jog: Node2D = arena.jogador
	var c: Vector2 = jog.centro()
	var cor := Color(float(d.cor[0]), float(d.cor[1]), float(d.cor[2]))
	print("CONSUMIVEL usou %s (restam %d)" % [id, int(restantes[id])])
	arena.mensagem("Usou: %s" % str(d.get("nome", id)), cor)
	Som.tocar("abrir", 0.2, 1.3, -6)
	match str(ef.get("tipo", "")):
		"cura":
			var v: float = jog.vida_max() * float(ef.get("frac", 0.4))
			jog.curar(v)
			arena.efeitos.numero(jog.position + Vector2(0, -50), v, Color(0.5, 1, 0.55))
			arena.efeitos.explodir(c, Color(0.6, 1, 0.7), 8, 60.0)
		"buff":
			buffs.append({"id": id, "t": float(ef.get("tempo", 10)), "tmax": float(ef.get("tempo", 10)), "bonus": ef.get("bonus", {})})
			_recalcular()
			arena.efeitos.explodir(c, cor, 10, 70.0)
		"escudo":
			jog.invencivel = maxf(jog.invencivel, float(ef.get("tempo", 3.0)))
			arena.efeitos.explodir(c, Color(0.75, 0.85, 1), 10, 70.0)
		"explosao":
			var dano: float = float(ef.get("dano", 80)) * arena.stat("dano")
			var emp := float(ef.get("empurra", 250))
			for v in arena.inimigos.no_circulo(c, float(ef.get("raio", 90))):
				arena.inimigos.ferir(v, dano, (v.pos - c).normalized() * emp, str(d.get("nome", "Bomba")))
			arena.efeitos.explodir(c, Color(1, 0.7, 0.25), 18, 170.0)
			arena.efeitos.luz(c, float(ef.get("raio", 90)) * 1.6, Color(1, 0.65, 0.25))
			arena.tremer(5.0)
		"lento":
			arena.efeitos.explodir(c, Color(0.6, 0.9, 1), 14, 110.0)
			arena.efeitos.luz(c, float(ef.get("raio", 150)), Color(0.5, 0.85, 1))
			if not arena.eh_online:
				Mochila.aplicar_mundo(arena, id, c)
		"ima":
			arena.coleta.puxar_tudo()
			arena.efeitos.explodir(c, Color(0.8, 0.6, 1), 10, 80.0)


## Pena de Fênix: ao cair, levanta uma vez. Devolve true se salvou (arena.morrer não termina a corrida).
func fenix() -> bool:
	if fenix_gasta or amuleto == "":
		return false
	var ef: Dictionary = Mochila.item(amuleto).get("efeito", {})
	if str(ef.get("tipo", "")) != "fenix":
		return false
	fenix_gasta = true
	var jog: Node2D = arena.jogador
	jog.hp = maxf(1.0, jog.vida_max() * float(ef.get("frac", 0.4)))
	jog.invencivel = 2.0
	arena.anunciar("A Pena de Fênix te levantou!", Color(1, 0.65, 0.3))
	arena.efeitos.explodir(jog.centro(), Color(1, 0.6, 0.2), 24, 200.0)
	return true

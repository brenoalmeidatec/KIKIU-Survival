extends Node2D
## O que cai no chão: gemas de XP, marmita (cura), Wi-Fi (puxa todo o XP) e baú.
## O ímã do jogador puxa tudo que está perto.

const ESCALA := 2.0
const MAX_GEMAS := 450

var arena: Node
var itens: Array = []      # {pos, tipo, valor, puxando, vel}
var _t := 0.0


func gema(pos: Vector2, valor: float) -> void:
	if valor <= 0:
		return
	if itens.size() >= MAX_GEMAS:
		# muita gema no chão: junta numa que já existe
		for it in itens:
			if it.tipo == "gema" and not it.puxando:
				it.valor += valor
				return
	itens.append({"pos": pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)), "tipo": "gema", "valor": valor, "puxando": false, "vel": 0.0})


func soltar(pos: Vector2, tipo: String) -> void:
	itens.append({"pos": pos, "tipo": tipo, "valor": 0, "puxando": false, "vel": 0.0})


func puxar_tudo() -> void:
	for it in itens:
		if it.tipo == "gema":
			it.puxando = true


func limpar() -> void:
	itens.clear()


func atualizar(dt: float) -> void:
	_t += dt
	var jog: Node2D = arena.jogador
	var alvo: Vector2 = jog.centro()
	var ima: float = 70.0 * arena.stat("ima")
	for it in itens.duplicate():
		var dist: float = it.pos.distance_to(alvo)
		if not it.puxando and dist < ima and it.tipo != "bau":
			it.puxando = true
			it.vel = -140.0   # dá um pulinho pra trás antes de vir
		if it.puxando:
			it.vel += 900.0 * dt
			if it.vel < 0:
				it.pos -= (alvo - it.pos).normalized() * -it.vel * dt
			else:
				it.pos = it.pos.move_toward(alvo, it.vel * dt)
		if dist < 14:
			itens.erase(it)
			_pegar(it)
	queue_redraw()


func _pegar(it: Dictionary) -> void:
	match it.tipo:
		"gema":
			arena.ganhar_xp(it.valor)
			Som.tocar("blip", 0.04, randf_range(1.3, 1.6), -12)
		"marmita":
			arena.jogador.curar(float(Dados.json("fase").get("drops", {}).get("cura_marmita", 30)))
			Som.tocar("plim", 0.1, 1.2)
			arena.mensagem("Marmita! +vida", Color(1, 0.6, 0.5))
		"wifi":
			puxar_tudo()
			Som.tocar("plim", 0.1, 1.5)
			arena.mensagem("Wi-Fi grátis! Puxou todo o XP", Color(0.5, 0.85, 1))
		"bau":
			arena.abrir_bau()


func _textura(it: Dictionary) -> Texture2D:
	match it.tipo:
		"gema":
			if it.valor >= 20:
				return Dados.tex("gema_3")
			elif it.valor >= 4:
				return Dados.tex("gema_2")
			return Dados.tex("gema_1")
		"marmita":
			return Dados.tex("marmita")
		"wifi":
			return Dados.tex("wifi")
		"bau":
			return Dados.tex("bau")
	return null


func _draw() -> void:
	for it in itens:
		var tex := _textura(it)
		if tex == null:
			continue
		var sz := tex.get_size() * ESCALA
		var flutua := 0.0
		if it.tipo != "gema":
			flutua = sin(_t * 4.0 + it.pos.x) * 2.0
		if it.tipo == "bau":
			draw_circle(it.pos, 18 + sin(_t * 5.0) * 3, Color(1, 0.85, 0.3, 0.18))
		draw_texture_rect(tex, Rect2(it.pos - sz / 2 + Vector2(0, flutua), sz), false)

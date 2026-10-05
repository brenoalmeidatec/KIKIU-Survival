extends RefCounted
## Cérebro dos rivais no duelo final (e do robô de teste): fica na distância boa pra arma,
## anda de lado, foge do anel que fecha e usa o dash pra escapar ou pra chegar perto.
## Cada lutador tem um dicionário "st" próprio (estado da IA) e uma "habilidade" de 0 a 1.

const ALCANCE_TIPO := {"projetil": 170.0, "chicote": 85.0, "orbita": 65.0, "poca": 120.0, "aura": 60.0}


## Distância que a build prefere lutar: média dos tipos de arma pesada pelo nível.
static func alcance_preferido(armas: Array) -> float:
	var soma := 0.0
	var peso := 0.0
	var d: Dictionary = Dados.json("armas")
	for a in armas:
		var tipo := str(d.get(a.id, {}).get("familia", d.get(a.id, {}).get("tipo", "projetil")))
		soma += float(ALCANCE_TIPO.get(tipo, 120.0)) * a.nivel
		peso += a.nivel
	return soma / maxf(1.0, peso)


## eu: {pos, hp_frac, pref, dash_pronto}; alvos: lista de {pos, hp_frac, raio}; retorna {dir, dash}.
static func decidir(eu: Dictionary, alvos: Array, centro: Vector2, raio_anel: float, st: Dictionary, habilidade: float, dt: float) -> Dictionary:
	st.t_lado = float(st.get("t_lado", 0.0)) - dt
	if st.t_lado <= 0:
		st.t_lado = randf_range(1.0, 2.6)
		st["lado"] = -1.0 if randf() < 0.5 else 1.0
	st.t_reacao = float(st.get("t_reacao", 0.0)) - dt
	var pos: Vector2 = eu.pos
	var pref: float = eu.pref
	# alvo: o mais perto, com preferência pelo mais fraco
	var alvo = null
	var melhor := INF
	for a in alvos:
		var s: float = pos.distance_to(a.pos) * (0.6 + 0.8 * a.hp_frac)
		if s < melhor:
			melhor = s
			alvo = a
	var dir := Vector2.ZERO
	var quer_dash := false
	var d := 9999.0
	if alvo != null:
		var para: Vector2 = alvo.pos - pos
		d = para.length()
		var n := para / maxf(d, 0.01)
		var lateral := n.orthogonal() * float(st.lado)
		if d < pref * 0.7:
			dir = -n * 0.9 + lateral * 0.7
		elif d > pref * 1.3:
			dir = n + lateral * 0.2
		else:
			dir = lateral + n * (0.25 if d > pref else -0.2)
		# não colar nos outros
		for a in alvos:
			var dd: float = pos.distance_to(a.pos)
			if dd < pref * 0.5 and a != alvo:
				dir += (pos - a.pos).normalized() * 0.6
	# anel: perto da borda, volta pro centro (com mais força quanto mais fundo fora)
	var do_centro := centro - pos
	var fora := do_centro.length() - (raio_anel - 45.0)
	if fora > 0:
		dir += do_centro.normalized() * clampf(fora / 40.0, 0.3, 3.0)
	dir = dir.normalized() if dir.length() > 0.05 else Vector2.ZERO
	# dash: apanhou muito há pouco, ou está fora do anel, ou é corpo a corpo e o alvo está longe
	if eu.dash_pronto and st.t_reacao <= 0:
		var perdeu: float = float(st.get("hp_antes", eu.hp_frac)) - eu.hp_frac
		if perdeu > 0.06 and randf() < 0.55 * habilidade + 0.1:
			quer_dash = true
		elif fora > 25 and randf() < 0.7:
			quer_dash = true
			dir = do_centro.normalized()
		elif pref < 100.0 and d > pref * 2.2 and d < 500.0 and randf() < 0.25 * habilidade:
			quer_dash = true
		if quer_dash:
			st.t_reacao = lerpf(0.9, 0.4, habilidade)
	st["hp_antes"] = lerpf(float(st.get("hp_antes", eu.hp_frac)), eu.hp_frac, minf(1.0, dt * 2.0))
	return {"dir": dir, "dash": quer_dash}

extends RefCounted
## "Pegou Onda" (especial do Lucas, #63): o Lucas tem pegada de surfista. No jogo: uma onda gigante nasce atrás dele
## e corre pra frente, e ele surfa nela no começo (dash longo e invencível). A onda atropela e arrasta tudo na faixa
## da largura dela, uma vez cada. Módulo de efeito no padrão das armas; ativar() é chamado pelo especial.gd.

const AGUA_FUNDA := Color("1f4a8a")
const AGUA := Color("3a7fc4")
const CRISTA := Color("8fd0ff")
const ESPUMA := Color(0.95, 0.98, 1.0)


static func ativar(w, d: Dictionary, esp) -> void:
	var jog = w.dono
	var dir: Vector2 = jog.direcao_mov() if jog.direcao_mov() != Vector2.ZERO else Vector2(jog.lado, 0)
	dir = dir.normalized()
	# surfe: um dash comprido na direção da onda
	var surfe := float(d.get("surfe", 0.42))
	jog._dir_dash = dir
	jog.dash_t = surfe
	jog.invencivel = maxf(jog.invencivel, surfe + 0.25)
	w.especiais.append(
		{
			"tipo": "onda",
			"pos": jog.position - dir * 24.0,
			"dir": dir,
			"larg": float(d.get("largura", 130)),
			"alcance": float(d.get("alcance", 560)),
			"vel": float(d.get("velocidade", 560)),
			"andou": 0.0,
			"dano": esp.dano(),
			"empurra": float(d.get("empurra", 420)),
			"acertou": [],
			"t": 0.0,
			"arma": str(d.get("nome", "especial"))
		}
	)


static func passo(w, e: Dictionary, dt: float) -> bool:
	e.t += dt
	var passo_px: float = e.vel * dt
	e.pos += e.dir * passo_px
	e.andou += passo_px
	var lado: Vector2 = e.dir.orthogonal()
	for v in w.campo.no_circulo(e.pos, e.larg * 0.5 + 12.0):
		if v.id in e.acertou:
			continue
		var rel: Vector2 = v.pos - e.pos
		if absf(rel.dot(lado)) <= e.larg * 0.5 and rel.dot(e.dir) > -26.0 and rel.dot(e.dir) < 18.0:
			e.acertou.append(v.id)
			w.campo.ferir(v, e.dano, e.dir * e.empurra, e.arma)
	return e.andou < e.alcance + 60.0


static func pintar(w, e: Dictionary) -> void:
	var fim: float = clampf((e.alcance + 60.0 - e.andou) / 120.0, 0.0, 1.0)  # some no fim do alcance
	var nasc: float = clampf(e.t / 0.12, 0.0, 1.0)  # e cresce ao nascer
	var a := fim * nasc
	var lado: Vector2 = e.dir.orthogonal()
	var n := 14
	var frente := PackedVector2Array()
	for i in n + 1:
		var k := float(i) / n - 0.5
		var ondula := sin(e.t * 14.0 + i * 1.3) * 3.0
		frente.append(e.pos + lado * k * e.larg * nasc + e.dir * ondula)
	# corpo da onda: faixas de água, do fundo (atrás) pra crista (na frente)
	for faixa in 3:
		var tras := 30.0 - faixa * 10.0
		var cor: Color = [AGUA_FUNDA, AGUA, CRISTA][faixa]
		for i in n:
			var q := PackedVector2Array(
				[frente[i] - e.dir * tras, frente[i + 1] - e.dir * tras, frente[i + 1] - e.dir * (tras - 10.0), frente[i] - e.dir * (tras - 10.0)]
			)
			w.draw_colored_polygon(q, Color(cor, 0.85 * a))
	# espuma: a crista branca enrolando na frente e respingos saindo
	for i in n:
		w.draw_line(frente[i], frente[i + 1], Color(ESPUMA, a), 2.0)
		if (i + int(e.t * 20.0)) % 3 == 0:
			var r: Vector2 = frente[i] + e.dir * (4.0 + fmod(e.t * 60.0 + i * 7.0, 12.0)) + lado * sin(i * 3.1) * 4.0
			w.draw_rect(Rect2(r.floor(), Vector2(2, 2)), Color(ESPUMA, a * 0.8))


static func fundo(_w, _a: Dictionary, _s: Dictionary) -> void:
	pass


static func atras(_w, _ci: CanvasItem, _a: Dictionary, _s: Dictionary) -> void:
	pass

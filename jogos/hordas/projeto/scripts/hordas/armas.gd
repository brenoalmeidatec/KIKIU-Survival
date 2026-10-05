extends Node2D
## As armas do jogador. Todas atiram sozinhas. O jeito de cada uma vem do "tipo" no armas.json:
##   projetil  atira no vírus mais perto
##   chicote   golpe reto na frente (e atrás, com mais quantidade)
##   orbita    coisas girando em volta por um tempo
##   poca      poça no chão que machuca quem pisa
##   aura      círculo em volta do jogador que machuca e empurra
## e os tipos com arquivo próprio em MODULOS (katana, pistolas, marcial, aura_energia, elemental).
## Os atributos do jogador (dano, área, quantidade...) multiplicam os da arma na hora de atirar.

const ESCALA := 2.0
const Poca := preload("res://scripts/hordas/poca.gd")
## Comportamentos que moram no próprio arquivo (scripts/hordas/armas/<tipo>.gd). Pra criar arma nova com
## comportamento próprio (ex.: exclusiva de outro personagem): escreva o arquivo com atualizar/passo/pintar/fundo
## (veja katana.gd) e registre aqui. atras() desenha o que fica atrás do personagem. Os tipos antigos (projetil, chicote...) continuam neste arquivo.
const MODULOS := {
	"katana": preload("res://scripts/hordas/armas/katana.gd"),
	"pistolas": preload("res://scripts/hordas/armas/pistolas.gd"),
	"marcial": preload("res://scripts/hordas/armas/marcial.gd"),
	"aura_energia": preload("res://scripts/hordas/armas/aura_energia.gd"),
	"elemental": preload("res://scripts/hordas/armas/elemental.gd"),
}

var arena: Node
## Quem usa a arma e contra quem ela bate. O jogador usa os vírus (inimigos.gd); no duelo final,
## o jogador e os rivais usam um "campo" que aponta pros outros lutadores (duelo.gd).
var dono: Node2D                 # precisa de centro(), lado e curar()
var campo: Object                # precisa de no_circulo, n_mais_perto, aleatorio_na_tela, ferir
var statf: Callable              # nome do atributo -> valor (dano, recarga, area...)
var lista: Array = []        # {id, nivel, t, ativo, acertos{}}
var projeteis: Array = []    # {pos, vel, dano, perfura, vida, tex, esc, acertou[], arma}
var pocas: Array = []        # {pos, raio, vida, dano, tique, t, segue, arma}
var golpes: Array = []       # desenho do chicote {pos, lado, alcance, largura, t, arma}
var _fila: Array = []        # golpes atrasados do chicote {t, arma}
var especiais: Array = []    # efeitos das armas de MODULOS (cada um tem "tipo"; o módulo cuida do resto)
var _t := 0.0
var _chao_pocas := Node2D.new()   # poças ficam no chão: abaixo de quem pisa nelas, acima do piso
var _atras := Node2D.new()        # atrás do personagem (ex.: chamas da aura saindo de trás do corpo)


func limpar_tiros() -> void:
	projeteis.clear()
	pocas.clear()
	golpes.clear()
	_fila.clear()
	especiais.clear()
	for a in lista:
		a.ativo = 0.0
		a.acertos = {}


func tem(id: String) -> bool:
	return achar(id) != null


func achar(id: String):
	for a in lista:
		if a.id == id:
			return a
	return null


func adicionar(id: String) -> void:
	lista.append({"id": id, "nivel": 1, "t": 0.3, "ativo": 0.0, "acertos": {}, "tique": 0.0})
	preaquecer()


func nivel_max(id: String) -> int:
	var d := Dados.item(id)
	return 1 + d.get("niveis", []).size()


func subir(id: String) -> void:
	var a = achar(id)
	if a:
		a.nivel = mini(a.nivel + 1, nivel_max(id))
	preaquecer()


func trocar(de: String, para: String) -> void:
	var a = achar(de)
	if a:
		a.id = para
		a.nivel = 1
		a.t = 0.1
		a.ativo = 0.0
	preaquecer()


## Atributos da arma no nível atual (sem os bônus do jogador).
func atributos(id: String, nivel: int) -> Dictionary:
	var d := Dados.item(id)
	var s: Dictionary = d.get("base", {}).duplicate()
	var niveis: Array = d.get("niveis", [])
	for i in mini(nivel - 1, niveis.size()):
		for k in niveis[i]:
			s[k] = float(s.get(k, 0)) + float(niveis[i][k])
	return s


func _s(a: Dictionary) -> Dictionary:
	## Atributos finais = arma x jogador.
	var s := atributos(a.id, a.nivel)
	s["dano"] = float(s.get("dano", 1)) * statf.call("dano")
	s["recarga"] = float(s.get("recarga", 1)) * statf.call("recarga")
	s["area"] = float(s.get("area", 1)) * statf.call("area")
	s["quantidade"] = int(s.get("quantidade", 1)) + int(statf.call("quantidade"))
	s["duracao"] = float(s.get("duracao", 1)) * statf.call("duracao")
	s["velocidade"] = float(s.get("velocidade", 200)) * statf.call("velocidade_proj")
	return s


func atualizar(dt: float) -> void:
	_t += dt
	var jog: Node2D = dono
	for a in lista:
		var d := Dados.item(a.id)
		var s := _s(a)
		match str(d.get("tipo", "")):
			"projetil":
				a.t -= dt
				if a.t <= 0:
					a.t = maxf(0.1, s.recarga)
					_atirar(a, d, s)
			"chicote":
				a.t -= dt
				if a.t <= 0:
					a.t = maxf(0.15, s.recarga)
					for i in s.quantidade:
						_fila.append({"t": i * 0.12, "arma": a, "lado": jog.lado * (1 if i % 2 == 0 else -1)})
			"orbita":
				if a.ativo > 0:
					a.ativo -= dt
					_orbita(a, s)
					if a.ativo <= 0:
						a.t = s.recarga
				else:
					a.t -= dt
					if a.t <= 0:
						a.ativo = s.duracao
						a.acertos = {}
			"poca":
				a.t -= dt
				if a.t <= 0:
					a.t = maxf(0.3, s.recarga)
					_derramar(a, d, s)
			"aura":
				a.tique -= dt
				if a.tique <= 0:
					a.tique = maxf(0.15, float(s.get("tique", 0.5)))
					_aura(a, s)
			var outro:
				if MODULOS.has(outro):
					MODULOS[outro].atualizar(self, a, d, s, dt)
	for e in especiais.duplicate():
		if not MODULOS[e.tipo].passo(self, e, dt):
			especiais.erase(e)
	_chicotes(dt)
	_projeteis(dt)
	_pocas(dt)
	for g in golpes.duplicate():
		g.t -= dt
		if g.t <= 0:
			golpes.erase(g)
	queue_redraw()
	_chao_pocas.queue_redraw()
	_atras.queue_redraw()


# ---------- projétil ----------

func _atirar(a: Dictionary, d: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = dono
	var origem: Vector2 = jog.centro()
	var alvos: Array = campo.n_mais_perto(origem, s.quantidade, 380)
	for i in s.quantidade:
		var dir: Vector2
		if alvos.is_empty():
			dir = Vector2(jog.lado, 0).rotated(randf_range(-0.3, 0.3))
		else:
			var alvo = alvos[i % alvos.size()]
			dir = (alvo.pos - origem).normalized()
			if i >= alvos.size():
				dir = dir.rotated(randf_range(-0.25, 0.25))
		projeteis.append({"pos": origem, "vel": dir * s.velocidade, "dano": s.dano, "perfura": int(s.get("perfura", 1)),
			"vida": s.duracao, "tex": Dados.tex(str(d.get("sprite", "proj_pendrive"))), "esc": s.area,
			"acertou": [], "arma": a.id})
	Som.tocar("cursor", 0.08, 1.4, -10)


func _projeteis(dt: float) -> void:
	for p in projeteis.duplicate():
		p.pos += p.vel * dt
		p.vida -= dt
		if p.vida <= 0:
			projeteis.erase(p)
			continue
		for v in campo.no_circulo(p.pos, 6.0 * p.esc):
			if v.id in p.acertou:
				continue
			p.acertou.append(v.id)
			campo.ferir(v, p.dano, p.vel.normalized() * 60.0, p.arma)
			p.perfura -= 1
			if p.perfura <= 0:
				projeteis.erase(p)
				break


# ---------- chicote ----------

func _chicotes(dt: float) -> void:
	for f in _fila.duplicate():
		f.t -= dt
		if f.t > 0:
			continue
		_fila.erase(f)
		if not f.arma in lista:
			continue
		var a: Dictionary = f.arma
		var s := _s(a)
		var jog: Node2D = dono
		var alcance: float = float(s.get("alcance", 100)) * s.area
		var larg: float = float(s.get("largura", 30)) * s.area
		var c: Vector2 = jog.centro() + Vector2(f.lado * (alcance / 2 + 6), 0)
		var curou := 0
		for v in campo.no_circulo(c, alcance / 2):
			if absf(v.pos.y - c.y) <= larg / 2 + v.raio:
				campo.ferir(v, s.dano, Vector2(f.lado * 120, 0), a.id)
				if s.has("rouba_vida") and curou < 5:
					jog.curar(float(s.rouba_vida))
					curou += 1
		golpes.append({"pos": jog.centro(), "lado": f.lado, "alcance": alcance, "largura": larg, "t": 0.16, "arma": a.id})
		Som.tocar("whoosh", 0.05, 1.6, -8)


# ---------- órbita ----------

func _orbita(a: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = dono
	var r: float = float(s.get("raio", 60)) * s.area
	for i in s.quantidade:
		var p: Vector2 = jog.centro() + Vector2.from_angle(_t * float(s.get("giro", 3)) + TAU * i / s.quantidade) * r
		for v in campo.no_circulo(p, 9.0 * s.area):
			var prox: float = a.acertos.get(v.id, 0.0)
			if _t >= prox:
				a.acertos[v.id] = _t + 0.5
				campo.ferir(v, s.dano, (v.pos - jog.centro()).normalized() * 90.0, a.id)
	if a.acertos.size() > 600:
		a.acertos = {}


# ---------- poça ----------

func _derramar(a: Dictionary, d: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = dono
	for i in s.quantidade:
		var alvo = campo.aleatorio_na_tela(jog.centro())
		var p: Vector2 = alvo.pos if alvo else jog.centro() + Vector2.from_angle(randf() * TAU) * randf_range(40, 140)
		pocas.append({"pos": p, "raio": float(s.get("raio", 40)) * s.area, "vida": s.duracao, "total": s.duracao,
			"dano": s.dano, "tique": float(s.get("tique", 0.4)), "t": 0.0, "segue": bool(d.get("base", {}).get("segue", false)),
			"arma": a.id, "variante": randi() % 3, "semente": randf() * 10.0})
	Som.tocar("queda", 0.2, 1.5, -10)


func _pocas(dt: float) -> void:
	for p in pocas.duplicate():
		p.vida -= dt
		p.t -= dt
		if p.segue:
			p.pos = p.pos.move_toward(dono.centro(), 40.0 * dt)
		if p.t <= 0:
			p.t = p.tique
			for v in campo.no_circulo(p.pos, p.raio * 0.85):
				campo.ferir(v, p.dano, Vector2.ZERO, p.arma)
		if p.vida <= 0:
			pocas.erase(p)


# ---------- aura ----------

func _aura(a: Dictionary, s: Dictionary) -> void:
	var jog: Node2D = dono
	var r: float = float(s.get("raio", 50)) * s.area
	for v in campo.no_circulo(jog.centro(), r):
		if s.has("lentidao"):
			v.lento = 0.8
		campo.ferir(v, s.dano, (v.pos - jog.centro()).normalized() * float(s.get("empurra", 40)), a.id)


# ---------- desenho ----------

func _draw() -> void:
	var jog: Node2D = dono
	for a in lista:
		var d := Dados.item(a.id)
		var tipo := str(d.get("tipo", ""))
		if MODULOS.has(tipo):
			MODULOS[tipo].fundo(self, a, _s(a))
		elif tipo == "aura":
			var s := _s(a)
			var r: float = float(s.get("raio", 50)) * s.area
			var pulso := 0.5 + 0.5 * sin(_t * 4.0)
			var cor := Color(0.3, 0.75, 1.0) if a.id == "wifi" else Color(0.5, 1.0, 0.6)
			draw_circle(jog.centro(), r, Color(cor, 0.08 + 0.04 * pulso))
			for k in 3:
				var rr := fmod(_t * 40.0 + k * r / 3.0, r)
				draw_arc(jog.centro(), rr, 0, TAU, 32, Color(cor, 0.35 * (1.0 - rr / r)), 1.5)
		elif tipo == "orbita" and a.ativo > 0:
			var s := _s(a)
			var tex := Dados.tex(str(d.get("sprite", "proj_ventoinha")))
			var r: float = float(s.get("raio", 60)) * s.area
			var sz: Vector2 = tex.get_size() * ESCALA * s.area * 0.8
			for i in s.quantidade:
				var p: Vector2 = jog.centro() + Vector2.from_angle(_t * float(s.get("giro", 3)) + TAU * i / s.quantidade) * r
				draw_set_transform(p, _t * 12.0, Vector2.ONE)
				draw_texture_rect(tex, Rect2(-sz / 2, sz), false)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for g in golpes:
		var alfa: float = g.t / 0.16
		var x0: float = g.pos.x + g.lado * 8
		var pts := PackedVector2Array()
		for i in 13:
			var f := i / 12.0
			pts.append(Vector2(x0 + g.lado * g.alcance * f, g.pos.y + sin(f * 9.0 + _t * 30.0) * g.largura * 0.25 * (1.0 - absf(f - 0.5))))
		if g.arma == "fibra_optica":
			for k in 3:
				var cores := [Color(1, 0.3, 0.8), Color(0.4, 0.9, 1), Color(1, 0.95, 0.4)]
				var desl := PackedVector2Array()
				for p in pts:
					desl.append(p + Vector2(0, (k - 1) * 3))
				draw_polyline(desl, Color(cores[k], alfa), 2)
		else:
			draw_polyline(pts, Color(0.95, 0.8, 0.25, alfa), 3)
			draw_polyline(pts, Color(1, 1, 0.8, alfa), 1)
		draw_rect(Rect2(Vector2(minf(x0, x0 + g.lado * g.alcance), g.pos.y - g.largura / 2), Vector2(g.alcance, g.largura)), Color(1, 1, 0.7, alfa * 0.12))
	for p in projeteis:
		var tex: Texture2D = p.tex
		var sz: Vector2 = tex.get_size() * ESCALA * p.esc
		draw_set_transform(p.pos, p.vel.angle(), Vector2.ONE)
		draw_texture_rect(tex, Rect2(-sz / 2, sz), false)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for e in especiais:
		MODULOS[e.tipo].pintar(self, e)


## Gera antes as texturas das poças (o pior tamanho leva ~30 ms): chamado ao pegar/subir arma e passivo,
## quando a tela de cartas está aberta e o jogo parado, pra não dar engasgo no meio da horda.
func preaquecer() -> void:
	if not statf.is_valid():
		return
	for a in lista:
		if str(Dados.item(a.id).get("tipo", "")) == "poca":
			var s := _s(a)
			for v in 3:
				Poca.textura(float(s.get("raio", 40)) * s.area, v)


func _ready() -> void:
	_chao_pocas.z_index = -5
	_chao_pocas.draw.connect(func():
		for p in pocas:
			_desenhar_poca(_chao_pocas, p))
	add_child(_chao_pocas)
	_atras.z_index = -1
	_atras.draw.connect(func():
		for a in lista:
			var tipo := str(Dados.item(a.id).get("tipo", ""))
			if MODULOS.has(tipo):
				MODULOS[tipo].atras(self, _atras, a, _s(a)))
	add_child(_atras)


## Poça em pixel art (poca.gd) + bolhas que estouram e vapor subindo, tudo alinhado ao pixel.
func _desenhar_poca(ci: CanvasItem, p: Dictionary) -> void:
	var alfa: float = clampf(p.vida / 0.4, 0.0, 1.0)
	var cresce: float = clampf((p.total - p.vida) / 0.15, 0.3, 1.0)
	var r: float = p.raio * cresce
	var var_: int = p.get("variante", 0)
	var s: float = p.get("semente", 0.0)
	# só a textura do tamanho final; os 0,15 s em que ela "cai" e cresce são uma escala rápida dela
	var tex := Poca.textura(p.raio, var_)
	var tam_poca: Vector2 = tex.get_size() * cresce
	ci.draw_texture_rect(tex, Rect2((p.pos - tam_poca / 2.0).floor(), tam_poca.floor()), false, Color(1, 1, 1, alfa))
	var bolha := Color(Poca.CAFE[4])
	for i in 3:
		var fase := fmod(_t * 0.9 + i * 0.37 + s, 1.0)
		if fase > 0.8:
			continue   # estourou
		var a := i * 2.3 + s
		var pb: Vector2 = (p.pos + Vector2(cos(a) * r * 0.45, sin(a) * r * 0.45 * Poca.ACHATA)).floor()
		var tam := 1.0 if fase < 0.45 else 2.0
		ci.draw_rect(Rect2(pb, Vector2(tam, tam)), Color(bolha, alfa * 0.9))
		ci.draw_rect(Rect2(pb, Vector2.ONE), Color(1, 0.95, 0.85, alfa * 0.8))   # brilho da bolha
	var fios := 4 if p.segue else 2   # garrafa térmica: café mais quente, mais vapor
	for i in fios:
		var fv := fmod(_t * 0.55 + i * 0.5 / fios * 2.0 + s, 1.0)
		var pv: Vector2 = (p.pos + Vector2((i - (fios - 1) / 2.0) * r * 0.35 + sin(fv * 7.0 + i) * 2.0, -r * 0.2 - fv * 26.0)).floor()
		ci.draw_rect(Rect2(pv, Vector2(1, 2)), Color(1, 1, 1, alfa * 0.35 * (1.0 - fv)))

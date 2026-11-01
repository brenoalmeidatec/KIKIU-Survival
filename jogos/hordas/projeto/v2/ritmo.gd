extends RefCounted
## Ritmo da partida (#371): curvas limitadas e pool de pickups com sorteador próprio.
const Progresso := preload("res://v2/progresso.gd")
const Andante := preload("res://v2/andante.gd")
const VIDA := preload("res://assets/v2/icones_cartas/vida.png")
const IMA := preload("res://assets/v2/icones_cartas/ima.png")
var combate
var cfg: Dictionary
var rng := RandomNumberGenerator.new()
var itens: Array = []
var espera := {"cura": 0.0, "ima": 0.0, "curandeiro": 0.0}
var coletados := {"cura": 0, "ima": 0, "curandeiro": 0}
var soltos := {"cura": 0, "ima": 0, "curandeiro": 0}
var almas_atraidas := 0
var cura_efetiva := 0.0
var _guardiao: AtlasTexture


func montar(c) -> void:
	combate = c
	cfg = Dados.json("v2_ritmo")
	var ficha: Dictionary = Andante.FICHAS.guardiao_pedra
	_guardiao = AtlasTexture.new()
	_guardiao.atlas = load(ficha.folha)
	_guardiao.region = Rect2(Vector2(ficha.quadro) * Vector2(Andante.PARADO, 0), Vector2(ficha.quadro))
	if c.mundo.args.has("semente"):
		rng.seed = int(c.mundo.args.semente) + 371
	else:
		rng.randomize()
	for i in int(cfg.pool):
		var no := Sprite2D.new()
		no.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		no.visible = false
		c.mundo.no_mundo.add_child(no)
		var coracao := Sprite2D.new()
		coracao.texture = VIDA
		coracao.scale = Vector2(0.5, 0.5)
		coracao.position = Vector2(0, -70)
		coracao.visible = false
		no.add_child(coracao)
		var item := {"no": no, "coracao": coracao, "tipo": "", "resta": 0.0, "curado": 0.0}
		no.draw.connect(_marca.bind(item))
		itens.append(item)


func multiplicador(chave: String, nivel: int) -> float:
	return 1.0 + Progresso.bonus_por_nivel(nivel, cfg.curvas[chave])


## ECO-3 (pedido 12): o coração ganha uma curva própria; o curandeiro mantém a fórmula antiga.
func chance_cura(fracao: float, tipo := "cura") -> float:
	if tipo == "cura":
		return _curva_cura("chance", intensidade_cura(fracao))
	return float(cfg[tipo].chance) * (1.0 + float(cfg[tipo].baixa_vida) * pow(1.0 - clampf(fracao, 0.0, 1.0), 2.0))


## g(v): 0 com vida acima de `de`, 1 em `ate` ou menos, subindo exponencialmente entre os dois.
func intensidade_cura(fracao: float) -> float:
	var curva: Dictionary = cfg.cura_baixa_vida
	var x := clampf((float(curva.de) - fracao) / (float(curva.de) - float(curva.ate)), 0.0, 1.0)
	var expo := float(curva.expoente)
	return (exp(expo * x) - 1.0) / (exp(expo) - 1.0)


## Interpola o valor base (vida cheia) e o de `chave_baixa` (com 10% de vida ou menos) pela intensidade g.
func _curva_cura(chave: String, g: float) -> float:
	return lerpf(float(cfg.cura[chave]), float(cfg.cura[chave + "_baixa"]), g)


func fracao_coracao(fracao: float) -> float:
	return _curva_cura("fracao", intensidade_cura(fracao))


func intervalo(tipo: String, fracao: float) -> float:
	if tipo == "cura":
		return _curva_cura("intervalo", intensidade_cura(fracao))
	return float(cfg[tipo].intervalo)


func teto_chao(tipo: String, fracao: float) -> int:
	if tipo == "cura":
		return roundi(_curva_cura("max_chao", intensidade_cura(fracao)))
	return int(cfg[tipo].max_chao)


func _fracao_heroi() -> float:
	var h = combate.mundo.heroi
	return h.vida / h.vida_max


func limpar() -> void:
	for it in itens:
		it.tipo = ""
		it.no.visible = false
	espera = {"cura": 0.0, "ima": 0.0, "curandeiro": 0.0}
	coletados = {"cura": 0, "ima": 0, "curandeiro": 0}
	cura_efetiva = 0.0
	soltos = {"cura": 0, "ima": 0, "curandeiro": 0}
	almas_atraidas = 0
	if combate.mundo.args.has("semente"):
		rng.seed = int(combate.mundo.args.semente) + 371


func ativos(tipo: String) -> int:
	var n := 0
	for it in itens:
		if it.tipo == tipo:
			n += 1
	return n


func soltar(tipo: String, pos: Vector2) -> bool:
	if ativos(tipo) >= teto_chao(tipo, _fracao_heroi()):
		return false
	for it in itens:
		if it.tipo == "":
			soltos[tipo] += 1
			it.tipo = tipo
			it.resta = float(cfg[tipo].duracao)
			it.curado = 0.0
			it.coracao.visible = tipo == "curandeiro"
			it.no.centered = tipo != "curandeiro"
			it.no.offset = Vector2.ZERO
			if tipo == "curandeiro":
				it.no.texture = _guardiao
				it.no.offset = -Vector2(Andante.FICHAS.guardiao_pedra.pe)
			else:
				it.no.texture = VIDA if tipo == "cura" else IMA
			it.no.queue_redraw()
			it.no.position = pos.round() + Vector2(0, -8)
			it.no.visible = true
			return true
	return false


func abate(pos: Vector2) -> void:
	if combate.jogo != "jogando" or combate.pausado:
		return
	var h = combate.mundo.heroi
	if not h.vivo():
		return
	var fracao: float = h.vida / h.vida_max
	for tipo in ["cura", "ima", "curandeiro"]:
		if float(espera[tipo]) > 0.0 or ativos(tipo) >= teto_chao(tipo, fracao):
			continue
		var chance := chance_cura(fracao, tipo) if tipo != "ima" else float(cfg.ima.chance) * multiplicador("ima", h.nivel)
		if rng.randf() < chance and soltar(tipo, pos):
			espera[tipo] = intervalo(tipo, fracao)


## A transformação inversa do canvas fornece a tela real do mundo, inclusive corte/zoom e câmera deslocada.
func tela() -> Rect2:
	var sv = combate.mundo.sv
	var inv: Transform2D = sv.canvas_transform.affine_inverse()
	var fonte := Vector2(sv.size)
	var exibida: Vector2 = combate.mundo.ap.tela.size
	var k := maxf(exibida.x / fonte.x, exibida.y / fonte.y)
	var visivel := exibida / maxf(k, 0.001)
	return inv * Rect2((fonte - visivel) * 0.5, visivel)


func atualizar(dt: float) -> void:
	if combate.jogo != "jogando" or combate.pausado:
		return
	var h = combate.mundo.heroi
	for tipo in espera:
		espera[tipo] = maxf(0.0, float(espera[tipo]) - dt)
	for it in itens:
		if it.tipo == "":
			continue
		var passo: float = minf(dt, it.resta)
		it.resta -= dt
		if it.tipo == "curandeiro":
			_curar_aliado(it, h, passo)
		if it.resta <= 0.0:
			it.tipo = ""
			it.no.visible = false
			continue
		if it.tipo == "curandeiro":
			continue
		if not h.vivo() or h.pos.distance_to(it.no.position - Vector2(0, -8)) > float(cfg.coleta_raio):
			continue
		var tipo: String = it.tipo
		it.tipo = ""
		it.no.visible = false
		coletados[tipo] += 1
		if tipo == "ima":
			almas_atraidas += combate.orbes.atrair_em_rect(tela())
		else:
			var antes: float = h.vida
			h.curar(h.vida_max * fracao_coracao(h.vida / h.vida_max))
			h.repor_defesa_de("coracao")  # a cura repõe a barra do escudo (valor nominal: vale com a vida cheia)
			cura_efetiva += h.vida - antes
		combate.audio.tocar("escolher", 1.2, -6.0, 0.0)


func _curar_aliado(it: Dictionary, h, dt: float) -> void:
	if not h.vivo() or h.pos.distance_to(it.no.position - Vector2(0, -8)) > float(cfg.curandeiro.raio):
		return
	var falta: float = maxf(0.0, h.vida_max * float(cfg.curandeiro.teto_cura) - float(it.curado))
	var antes: float = h.vida
	h.curar(minf(falta, h.vida_max * float(cfg.curandeiro.por_s) * dt))
	h.repor_defesa_de("curandeiro_s", dt)  # dentro da aura: a barra do escudo sobe por segundo
	var efetiva: float = h.vida - antes
	if efetiva > 0.0 and it.curado == 0.0:
		coletados.curandeiro += 1
	it.curado += efetiva
	cura_efetiva += efetiva


func _marca(it: Dictionary) -> void:
	if it.tipo == "curandeiro":
		it.no.draw_arc(Vector2(0, 8), 16, 0, TAU, 32, Color(0.3, 1, 0.5), 2)


## Fecha os recursos ao acabar a partida, preservando os contadores do relatório.
func encerrar() -> void:
	for it in itens:
		it.tipo = ""
		it.no.visible = false


func relatorio() -> Dictionary:
	var fatores := {}
	for chave in cfg.curvas:
		fatores[chave] = multiplicador(chave, combate.mundo.heroi.nivel)
	return {
		"soltos": soltos.duplicate(),
		"coletados": coletados.duplicate(),
		"cura_efetiva": cura_efetiva,
		"almas_atraidas": almas_atraidas,
		"multiplicadores": fatores
	}

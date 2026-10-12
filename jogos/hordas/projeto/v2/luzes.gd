extends RefCounted
## Luzes da v2 (extraídas do protótipo cara_nova): PointLight2D com a queda de GRAD_OFF/GRAD_VAL, corpo brilhante aditivo (orbe) na camada
## sem escurecimento, fogo e faíscas em partículas. Os tipos vêm de dados/v2_floresta.json ("luz_tipos"). A luz FORA DA TELA FICA DESLIGADA:
## `atualizar(t, rect)` liga só as que alcançam a tela (o círculo da luz cruza o retângulo da câmera) e desliga também o orbe, o fogo e as
## faíscas dela. As ligadas viram os vetores `dpos/dr/de/dh` que o sistema de sombras (sombras.gd) lê.

const Ator := preload("res://v2/ator.gd")
const GRAD_OFF := [0.0, 0.22, 0.55, 1.0]  # queda das luzes: forte no centro e escura de verdade longe (poças contrastadas)
const GRAD_VAL := [1.0, 0.5, 0.1, 0.0]
const MARGEM_LUZ := 24.0  # a luz liga um pouco antes de o círculo entrar na tela


## Uma luz do mundo.
class Entrada:
	extends RefCounted
	var tipo := ""
	var luz: PointLight2D
	var pos := Vector2.ZERO  # onde a luz está no mundo (o ponto no chão que ela ilumina)
	var base := Vector2.ZERO  # posição de repouso (as que orbitam giram em volta dela)
	var raio := 100.0
	var energia := 1.0
	var altura := 40.0
	var tremor := 0.0
	var fase := 0.0
	var orbita := Vector2.ZERO
	var vel_orbita := 0.9
	var orbe: Sprite2D = null
	var orbe_desloca := Vector2.ZERO
	var particulas: Array[CPUParticles2D] = []  # fogo e faíscas, ligados só enquanto a luz está na tela
	var alvo: Ator = null  # luz presa a um ator (a tocha do herói)
	var desloca := Vector2.ZERO
	var ativa := false
	var cand := false  # alcança a tela neste quadro (antes do orçamento)


var orcamento := 0  # máximo de luzes ligadas ao mesmo tempo (0 = sem limite); vem do perfil de gráficos
var dn := 0
var dpos := PackedVector2Array()
var dr := PackedFloat32Array()
var de := PackedFloat32Array()
var dh := PackedFloat32Array()
var lista: Array[Entrada] = []
var tipos: Dictionary = {}
var _raiz_luz: Node
var _glow: Node
var _atm
var _tex_luz: GradientTexture2D


func montar(raiz_luz: Node, glow: Node, atm, tipos_json: Dictionary) -> void:
	_raiz_luz = raiz_luz
	_glow = glow
	_atm = atm
	tipos = tipos_json
	_tex_luz = _textura_luz()


func _textura_luz() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(GRAD_OFF)
	var cores := PackedColorArray()
	for v in GRAD_VAL:
		cores.append(Color(v, v, v, 1))
	g.colors = cores
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


## Cria uma luz do tipo `nome` em `pos` (mundo). `orbe` (ou null): onde fica o corpo brilhante; `fogo`: escala do fogo (0 = sem fogo).
func criar(nome: String, pos: Vector2, orbe: Variant = null, fogo := 0.0) -> Entrada:
	var d: Dictionary = tipos[nome]
	var e := Entrada.new()
	e.tipo = nome
	e.pos = pos
	e.base = pos
	e.raio = float(d.r)
	e.energia = float(d.e)
	e.altura = float(d.h)
	e.tremor = float(d.get("tremor", 0.0))
	e.fase = float(lista.size()) * 1.7
	if d.has("orbita"):
		e.orbita = Vector2(float(d.orbita[0]), float(d.orbita[1]))
	var cor := Color(float(d.cor[0]), float(d.cor[1]), float(d.cor[2]))
	var l := PointLight2D.new()
	l.texture = _tex_luz
	l.color = cor
	l.energy = e.energia
	l.texture_scale = e.raio / 128.0
	l.height = e.altura
	l.position = pos
	l.enabled = false
	_raiz_luz.add_child(l)
	e.luz = l
	var tam := float(d.get("orbe", 0.0))
	if tam > 0.0 and orbe != null:
		var o := Sprite2D.new()
		o.texture = _atm.tex_brilho
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		o.material = mat
		o.scale = Vector2(tam, tam)
		o.modulate = cor.lerp(Color.WHITE, 0.25)
		o.position = orbe
		o.visible = false
		_glow.add_child(o)
		e.orbe = o
		e.orbe_desloca = (orbe as Vector2) - pos
		if fogo > 0.0:
			e.particulas.append_array(_atm.fogo(orbe, fogo))
		if bool(d.get("faiscas", false)):
			e.particulas.append(_atm.faiscas(cor, orbe))
	for p in e.particulas:
		_atm.ligar(p, false)
	lista.append(e)
	return e


## Prende a luz a um ator: a luz anda com ele (a tocha do herói).
func prender(e: Entrada, a: Ator, desloca: Vector2) -> void:
	e.alvo = a
	e.desloca = desloca
	e.pos = a.raiz.position + desloca
	e.luz.position = e.pos


## Tremor, órbita e liga/desliga pela tela. `rect` = o que a câmera mostra (mundo). Com `orcamento` > 0, só as N luzes mais perto do
## centro da tela ficam ligadas (as presas ao herói sempre ficam): o perfil Baixo gasta menos GPU, que é o que a luz custa.
func atualizar(t: float, rect: Rect2) -> void:
	var tela := rect.grow(MARGEM_LUZ)
	dn = 0
	var n_cand := 0
	for e in lista:
		if e.alvo != null:
			e.pos = e.alvo.raiz.position + e.desloca
		elif e.orbita != Vector2.ZERO:
			e.pos = e.base + Vector2(cos(t * 0.9) * e.orbita.x, sin(t * 0.9) * e.orbita.y)
		# o círculo da luz cruza a tela? (distância do centro ao retângulo <= raio)
		var cx := clampf(e.pos.x, tela.position.x, tela.end.x)
		var cy := clampf(e.pos.y, tela.position.y, tela.end.y)
		var dx := e.pos.x - cx
		var dy := e.pos.y - cy
		e.cand = dx * dx + dy * dy <= e.raio * e.raio
		if e.cand:
			n_cand += 1
	if orcamento > 0 and n_cand > orcamento:
		_limitar(rect.get_center())
	for e in lista:
		var liga := e.cand
		if liga != e.ativa:
			e.ativa = liga
			e.luz.enabled = liga
			if e.orbe != null:
				e.orbe.visible = liga
			for p in e.particulas:
				_atm.ligar(p, liga)
		if not liga:
			continue
		var en := e.energia
		if e.tremor > 0.0:
			en *= 1.0 + e.tremor * sin(t * 9.0 + e.fase) + 0.6 * e.tremor * sin(t * 23.0 + 2.0 * e.fase)
		e.luz.energy = en
		e.luz.position = e.pos
		if e.orbe != null and (e.alvo != null or e.orbita != Vector2.ZERO):
			e.orbe.position = e.pos + e.orbe_desloca
		for p in e.particulas:
			if e.orbita != Vector2.ZERO or e.alvo != null:
				p.position = e.pos + e.orbe_desloca
		if dn >= dpos.size():
			dpos.resize(dn + 8)
			dr.resize(dn + 8)
			de.resize(dn + 8)
			dh.resize(dn + 8)
		dpos[dn] = e.pos
		dr[dn] = e.raio
		de[dn] = en
		dh[dn] = e.altura
		dn += 1


## Corta as candidatas que passam do orçamento: ficam as presas ao herói e as mais perto do centro da tela. Quem já está ligada ganha uma
## folga de 25% na distância, para a troca entre duas luzes parecidas não ficar piscando.
func _limitar(centro: Vector2) -> void:
	var fila: Array = []
	var sobra := orcamento
	for i in lista.size():
		var e: Entrada = lista[i]
		if not e.cand:
			continue
		if e.alvo != null:
			sobra -= 1
			continue
		var d2 := e.pos.distance_squared_to(centro) * (0.56 if e.ativa else 1.0)
		fila.append([d2, i])
	fila.sort()
	for k in fila.size():
		if k >= sobra:
			(lista[fila[k][1]] as Entrada).cand = false


func ligadas() -> int:
	var n := 0
	for e in lista:
		if e.ativa:
			n += 1
	return n

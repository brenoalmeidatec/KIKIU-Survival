extends RefCounted
## Copa transparente da v2: a COPA (a parte da árvore alta acima de COPA_ACIMA_DO_PE px do pé) fica semitransparente (ALFA)
## quando o herói ou um monstro está ATRÁS da árvore (o pé do ator é mais alto na tela que o pé da árvore) e o corpo dele
## cai sob a copa. O tronco, embaixo do corte, continua opaco e esconde quem está atrás dele. A alfa vai ao alvo com
## velocidade VEL por segundo, então a troca é suave. Só as árvores altas (ALTAS); tocos e o tronco caído não mudam.
## mundo.gd chama `montar` uma vez e `atualizar` a cada passo, com as árvores dos blocos visíveis (cenario.ativos).

const ALTAS := ["arvore", "arvore_pantano", "arvore_morta"]
const ALFA := 0.45
const VEL := 3.0  # alfa por segundo: de 1 a 0,45 leva uns 0,2 s
const COPA_ACIMA_DO_PE := 40.0  # px: o que está acima disto (na tela) é copa; abaixo é tronco, opaco
const SHADER := """shader_type canvas_item;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
uniform float corte : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (UV.y < corte) {
		c.a *= alfa;
	}
	COLOR = c * COLOR;
}
"""

var _alfa: Dictionary = {}  # Ator da árvore -> alfa atual (só as que já foram tocadas)
var _acum := 0.0
var _n := 0
var _copa: Dictionary = {}  # Ator da árvore -> retângulo da copa no mundo (a árvore não se mexe: calculado uma vez)


## Dá a cada árvore alta o material de copa (um shader com a alfa e o corte). Chamado uma vez, depois do cenário carregar.
func montar(objetos: Array) -> void:
	var sh := Shader.new()
	sh.code = SHADER
	for a in objetos:
		if not ALTAS.has(a.chave):
			continue
		var m := ShaderMaterial.new()
		m.shader = sh
		var altura := float(a.sprite.texture.get_height())
		# o pé está em -offset.y dentro da textura (offset = -pe - margem): o corte sobe COPA_ACIMA_DO_PE a partir dele
		m.set_shader_parameter("corte", clampf((-a.offset.y - COPA_ACIMA_DO_PE) / altura, 0.0, 1.0))
		a.sprite.material = m
		var r: Rect2 = a.sprite.get_rect()
		_copa[a] = Rect2(a.pos.x + r.position.x, a.pos.y + r.position.y, r.size.x, -a.offset.y - COPA_ACIMA_DO_PE)


## arvores: atores de cenário nos blocos visíveis; atores: herói e monstros. dt = 0 não muda nada (passo fixo dos testes).
func atualizar(dt: float, arvores: Array, atores: Array) -> void:
	if dt <= 0.0:
		return
	# a conta é cara com a horda (árvores x atores): roda a cada 3 quadros, com o tempo acumulado (a troca de alfa dura ~0,2 s)
	_acum += dt
	_n += 1
	if _n % 3 != 1 and _acum < 0.1:
		return
	var passo := _acum
	_acum = 0.0
	for a in arvores:
		if not ALTAS.has(a.chave) or a.sprite.material == null:
			continue
		var alvo := 1.0
		var copa: Rect2 = _copa[a]
		var ay: float = a.pos.y
		var x0 := copa.position.x - 40.0
		var x1 := copa.end.x + 40.0
		for ator in atores:
			var p: Vector2 = ator.pos
			if p.y >= ay or p.x < x0 or p.x > x1:  # descarte barato: só quem está atrás da árvore e na altura da copa
				continue
			if _encobre(a, ator):
				alvo = ALFA
				break
		var atual: float = _alfa.get(a, 1.0)
		if atual == alvo:
			continue
		atual = move_toward(atual, alvo, VEL * passo)
		_alfa[a] = atual
		a.sprite.material.set_shader_parameter("alfa", atual)


## Alfa atual da copa da árvore (1 = normal). Para os testes.
func alfa_da_copa(a) -> float:
	return float(a.sprite.material.get_shader_parameter("alfa")) if a.sprite.material != null else 1.0


## Verdadeiro se o ator está atrás da árvore (pé mais acima) e o corpo dele cruza a copa (do topo do sprite até COPA_ACIMA_DO_PE
## acima do pé). Um ator só atrás do tronco não aciona a copa: o tronco é opaco e já o esconde.
func _encobre(arvore, ator) -> bool:
	if ator.pos.y >= arvore.pos.y:
		return false
	var copa: Rect2 = _copa[arvore]
	# descarte barato antes de montar o retângulo do corpo (com 80 monstros são ~2000 pares por quadro)
	if ator.pos.x < copa.position.x - 40.0 or ator.pos.x > copa.end.x + 40.0:
		return false
	var t: Dictionary = ator.tipo
	var corpo := Rect2(ator.pos + Vector2(-float(t.w) / 2.0, -float(t.pe)), Vector2(float(t.w), float(t.h)))
	return copa.intersects(corpo)

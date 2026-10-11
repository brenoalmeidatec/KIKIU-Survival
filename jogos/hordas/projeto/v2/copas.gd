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


## arvores: atores de cenário nos blocos visíveis; atores: herói e monstros. dt = 0 não muda nada (passo fixo dos testes).
func atualizar(dt: float, arvores: Array, atores: Array) -> void:
	if dt <= 0.0:
		return
	for a in arvores:
		if not ALTAS.has(a.chave) or a.sprite.material == null:
			continue
		var alvo := 1.0
		for ator in atores:
			if _encobre(a, ator):
				alvo = ALFA
				break
		var atual: float = _alfa.get(a, 1.0)
		if atual == alvo:
			continue
		atual = move_toward(atual, alvo, VEL * dt)
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
	var r: Rect2 = arvore.sprite.get_rect()
	var copa := Rect2(arvore.pos.x + r.position.x, arvore.pos.y + r.position.y, r.size.x, -arvore.offset.y - COPA_ACIMA_DO_PE)
	var t: Dictionary = ator.tipo
	var corpo := Rect2(ator.pos + Vector2(-float(t.w) / 2.0, -float(t.pe)), Vector2(float(t.w), float(t.h)))
	return copa.intersects(corpo)

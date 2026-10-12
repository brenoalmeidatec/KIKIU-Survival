extends RefCounted
## Buraco raio-x da v2 (leva 4): quando o HERÓI está ATRÁS de uma árvore ou objeto alto (o pé dele é mais alto na tela que o
## pé do objeto) e o corpo dele cai sob o sprite, abre um buraco CIRCULAR e suave em volta do herói: o alfa cai a ALFA_MIN
## dentro de RAIO px e volta a 1 em RAIO + BORDA px. O resto do objeto fica opaco (o corte reto de antes saiu). A força do
## buraco (0 a 1) sobe e desce com transição, VEL por segundo. Só o herói conta: monstro atrás de árvore não muda nada.
## Entram os objetos com sprite de ALTURA_MIN px ou mais (árvores, pilares, torii, postes); toco e tronco caído são baixos.
## Árvores não usam a silhueta de monstro (oclusao.gd): aqui não há efeito duplo.
## mundo.gd chama `montar` uma vez e `atualizar` a cada passo, com os objetos dos blocos visíveis (cenario.ativos).

const ALTURA_MIN := 60  # px do sprite: abaixo disto não encobre o herói
const RAIO := 40.0  # px: o buraco inteiro, com o alfa mínimo
const BORDA := 12.0  # px: a borda suave, de RAIO até RAIO + BORDA
const ALFA_MIN := 0.35  # alfa dentro do buraco
const VEL := 3.0  # força por segundo: de 0 a 1 em ~0,33 s
const SHADER := """shader_type canvas_item;
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centro = vec2(0.0);
uniform float raio = 40.0;
uniform float borda = 12.0;
uniform float alfa_min = 0.35;
varying vec2 pos_mundo;
void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float dentro = 1.0 - smoothstep(raio, raio + borda, distance(pos_mundo, centro));
	c.a *= 1.0 - fuerza * dentro * (1.0 - alfa_min);
	COLOR = c * COLOR;
}
"""

var _altos: Dictionary = {}  # objeto alto -> Rect2 do sprite no mundo (calculado uma vez)
var _forca: Dictionary = {}  # objeto alto -> força atual do buraco (só os que já foram tocados)
var _acum := 0.0
var _n := 0


## Dá a cada objeto alto o material do buraco (shader com a força e o centro). Chamado uma vez, depois do cenário carregar.
func montar(objetos: Array) -> void:
	var sh := Shader.new()
	sh.code = SHADER
	for a in objetos:
		if a.sprite == null or a.sprite.texture == null or float(a.sprite.texture.get_height()) < ALTURA_MIN:
			continue
		var m := ShaderMaterial.new()
		m.shader = sh
		a.sprite.material = m
		var r: Rect2 = a.sprite.get_rect()
		_altos[a] = Rect2(a.pos + r.position, r.size)


## arvores: objetos nos blocos visíveis; heroi: o herói. dt = 0 não muda nada (passo fixo dos testes).
func atualizar(dt: float, arvores: Array, heroi) -> void:
	if dt <= 0.0 or heroi == null:
		return
	# a conta roda a cada 3 quadros, com o tempo acumulado (a troca de força dura ~0,33 s)
	_acum += dt
	_n += 1
	if _n % 3 != 1 and _acum < 0.1:
		return
	var passo := _acum
	_acum = 0.0
	var t: Dictionary = heroi.tipo
	var corpo := Rect2(heroi.pos + Vector2(-float(t.w) / 2.0, -float(t.pe)), Vector2(float(t.w), float(t.h)))
	var centro: Vector2 = heroi.centro()
	for a in arvores:
		if not _altos.has(a):
			continue
		var alvo := 0.0
		if heroi.pos.y < a.pos.y and _altos[a].intersects(corpo):  # o herói está atrás e o corpo cai sob o objeto
			alvo = 1.0
		var atual: float = _forca.get(a, 0.0)
		if atual != alvo:
			atual = move_toward(atual, alvo, VEL * passo)
			_forca[a] = atual
			a.sprite.material.set_shader_parameter("fuerza", atual)
		if atual > 0.0:  # o herói anda enquanto o buraco está aberto: o centro segue
			a.sprite.material.set_shader_parameter("centro", centro)


## Força atual do buraco do objeto (0 = opaco, 1 = buraco inteiro). Para os testes.
func fuerza_da_copa(a) -> float:
	return float(_forca.get(a, 0.0))


## Verdadeiro se algum objeto alto tem buraco aberto agora. Para os testes.
func alguma_ativa() -> bool:
	for a in _forca:
		if _forca[a] > 0.0:
			return true
	return false

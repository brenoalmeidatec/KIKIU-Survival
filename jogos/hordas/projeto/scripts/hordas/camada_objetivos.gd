extends CanvasLayer
## Camada dos objetivos (#123, #125): o que o jogador precisa ver primeiro fica legível mesmo com 250 inimigos.
## - Efeitos de arma (armas, poças, chamas de trás) ficam a 40% de opacidade quando estão em cima de um alvo (objetivo, altar,
##   portal): um shader leve nos nós de efeito, ligado só enquanto existe alvo (sem alvo, sem material, custo zero).
## - O baú faz o mesmo no próprio desenho (coleta.gd), então não passa por aqui.
## - Seta na borda da tela com a distância para o portal de saída quando está fora da tela (as setas do objetivo e da
##   missão já são do HUD).
## Os números e as contas puras moram em legibilidade.gd; aqui só tem a ligação com a arena.

const Legib := preload("res://scripts/hordas/legibilidade.gd")
const W := 640.0
const H := 360.0

const SHADER := """
shader_type canvas_item;
uniform vec2 alvos[8];
uniform int n = 0;
uniform float raio = 40.0;
uniform float alfa = 0.4;
varying vec2 mundo;
void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float k = 1.0;
	for (int i = 0; i < 8; i++) {
		if (i < n && distance(mundo, alvos[i]) < raio) {
			k = alfa;
		}
	}
	COLOR.a *= k;
}
"""

var arena: Node
var alvos: Array = []
var _mat: ShaderMaterial
var _tela := Control.new()
var _t := 0.0
var _com_material := false


func _ready() -> void:
	layer = 6
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("raio", Legib.SOBRE_RAIO)
	_mat.set_shader_parameter("alfa", Legib.SOBRE_ALFA)
	_tela.size = Vector2(W, H)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)


## Os nós de efeito que a camada abaixa de opacidade em cima de um alvo.
func _nos_efeito() -> Array:
	var r: Array = []
	var a = arena.get("armas")
	if a != null:
		r.append(a)
		r.append(a._chao_pocas)
		r.append(a._atras)
	return r


func _process(dt: float) -> void:
	_t += dt
	if arena == null:
		return
	alvos = Legib.alvos(arena)
	var n := mini(alvos.size(), Legib.ALVOS_MAX)
	if n > 0:
		var v := PackedVector2Array()
		v.resize(Legib.ALVOS_MAX)
		for i in n:
			v[i] = alvos[i]
		_mat.set_shader_parameter("alvos", v)
		_mat.set_shader_parameter("n", n)
	if (n > 0) != _com_material:
		_com_material = n > 0
		for no in _nos_efeito():
			no.material = _mat if _com_material else null
	_tela.queue_redraw()


func _desenhar() -> void:
	var s = arena.get("saida")
	if s == null or not s.aberta or s.pronto or arena.get("camera") == null:
		return
	var b := Legib.seta_borda(s.pos - arena.camera.position, Vector2(W, H))
	if b.is_empty():
		return
	var cor := Color(0.75, 0.6, 1.0)
	var pl := 0.65 + 0.35 * sin(_t * 6.0)
	var p: Vector2 = b.p
	var d: Vector2 = b.dir
	_seta(p, d, 11.0, 7.0, Color(cor, pl))
	_seta(p, d, 6.0, 3.5, Color(0.08, 0.04, 0.1, 0.8))
	var f: Font = Dados.fonte
	var txt := "SAÍDA %dm" % int(b.metros)
	var q := (p - d * 26.0 - Vector2(40, -3)).clamp(Vector2(0, 10), Vector2(W - 80, H - 2))
	_tela.draw_string(f, q + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(0, 0, 0, 0.9))
	_tela.draw_string(f, q, txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(cor, pl))


func _seta(p: Vector2, d: Vector2, ponta: float, lado: float, cor: Color) -> void:
	_tela.draw_colored_polygon(
		PackedVector2Array([p + d * ponta, p + d.orthogonal() * lado - d * (ponta * 0.45), p - d.orthogonal() * lado - d * (ponta * 0.45)]), cor
	)

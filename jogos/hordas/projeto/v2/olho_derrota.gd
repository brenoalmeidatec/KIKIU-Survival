extends CanvasLayer
## O olho que se fecha na derrota (#446): a tela escurece e borra, e as pálpebras (de cima e de baixo, em elipse) fecham até o preto, que
## fica por trás da tela de resultado. Mora no SubViewport do mundo (acima da vinheta), então a UI da derrota fica por cima.
## O HUD da partida (que mora na UI, acima do mundo) apaga junto.
## Quem manda é o combate: no fim da câmera lenta da morte chama por_restante(s que faltam). O efeito ocupa os últimos DURACAO s dessa
## janela (relógio real), sem somar nenhum segundo à espera pela tela de resultado.
## Versão completa: duas piscadas curtas, desfoque crescente e borda macia. Versão simples (perfil Baixo ou "Tremor e clarões" em 0%):
## só as pálpebras e o escurecimento, sem piscar, sem desfoque e sem mipmap da tela.

const DURACAO := 1.2  # s do efeito (a câmera lenta da morte dura pelo menos 1,3 s)
const SHADER := """shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D cena : hint_screen_texture, repeat_disable, FILTRO;
uniform float fecha = 0.0;
uniform float borrao = 0.0;
void fragment() {
	vec2 p = SCREEN_UV - vec2(0.5);
	float ay = max(0.76 * (1.0 - fecha), 0.0001);
	float ax = 0.76 * (1.0 - 0.3 * fecha * fecha);
	float d = length(vec2(p.x / ax, p.y / ay));
	float larg = mix(0.03, 0.28, borrao);
	float m = 1.0 - smoothstep(1.0 - larg, 1.0, d);
	m *= 1.0 - step(0.995, fecha);
	vec3 c = textureLod(cena, SCREEN_UV, borrao * fecha * 3.5).rgb;
	c *= 1.0 - 0.55 * fecha;
	COLOR = vec4(c * m, 1.0);
}
"""

var fecha := 0.0  # 0 aberto, 1 fechado (preto)
var simples := false  # a versão simples está valendo (decidida no iniciar)
var _hud: Control  # a raiz do HUD: some junto com o olho (senão a vinheta vermelha de vida baixa e as barras ficam sobre o preto)
var _mini: CanvasLayer  # o minimapa: some na metade do fechamento
var _mini_visivel := true  # como o minimapa estava antes (volta assim)
var _ret: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	layer = 6  # acima do minimapa (layer 5)
	visible = false


## A versão simples vale com o perfil Baixo ou "Tremor e clarões" em 0%.
static func versao_simples() -> bool:
	if Config.g_perfil() == "baixo":
		return true
	var f = Config.g("tremor_clarao")
	return f != null and float(f) <= 0.0


## Prepara o shader da versão certa e deixa a tela aberta. Chamado quando o herói morre.
func iniciar(hud: Node = null, minimapa: CanvasLayer = null) -> void:
	simples = versao_simples()
	_hud = hud.get_node_or_null("Raiz") if hud != null else null
	_mini = minimapa
	_mini_visivel = minimapa.visible if minimapa != null else true
	if _ret != null:
		_ret.queue_free()
	var sh := Shader.new()
	sh.code = SHADER.replace("FILTRO", "filter_nearest" if simples else "filter_linear_mipmap")
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_ret = ColorRect.new()
	_ret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ret.material = _mat
	add_child(_ret)
	_ret.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aplicar(0.0)


## `restante`: segundos que faltam para o fim da câmera lenta da morte. Antes dos últimos DURACAO s a tela segue aberta.
func por_restante(restante: float) -> void:
	if _ret == null:
		return
	_aplicar(curva(DURACAO - restante, simples))


## Fecha de volta e some (nova partida).
func limpar() -> void:
	fecha = 0.0
	visible = false
	_hud_alfa(1.0)
	if _mini != null and is_instance_valid(_mini):
		_mini.visible = _mini_visivel
	_mini = null
	if _ret != null:
		_ret.queue_free()
		_ret = null
		_mat = null


## Quanto está fechado (0 a 1) `t` s depois do começo do efeito. A completa pisca duas vezes (até 35% e 50%) antes de fechar de vez.
static func curva(t: float, modo_basico: bool) -> float:
	var u := clampf(t / DURACAO, 0.0, 1.0)
	if u <= 0.0:
		return 0.0
	if modo_basico:
		return smoothstep(0.0, 1.0, u)
	var fim := smoothstep(0.0, 1.0, clampf((u - 0.4) / 0.6, 0.0, 1.0))
	var p1 := 0.35 * sin(PI * clampf(u / 0.14, 0.0, 1.0))
	var p2 := 0.5 * sin(PI * clampf((u - 0.2) / 0.14, 0.0, 1.0))
	return maxf(fim, maxf(p1, p2))


func _aplicar(k: float) -> void:
	fecha = k
	visible = k > 0.0
	_mat.set_shader_parameter("fecha", k)
	_mat.set_shader_parameter("borrao", 0.0 if simples else 1.0)
	_hud_alfa(1.0 - smoothstep(0.25, 0.85, k))
	if k >= 0.5 and _mini != null and is_instance_valid(_mini):
		_mini.visible = false


func _hud_alfa(a: float) -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.modulate.a = a

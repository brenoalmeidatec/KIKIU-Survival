extends CanvasLayer
## Quantização RGB de 5 bits e Bayer estático na resolução do mundo, antes da vinheta e da UI.
## Só o perfil Alto desenha o passe; desligado, o retângulo fica oculto e sem material de screen texture.

const SHADER := """shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D cena : hint_screen_texture, repeat_disable, filter_nearest;
const mat4 BAYER = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0)
);
void fragment() {
	vec2 pixel = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec2 centro = (pixel + vec2(0.5)) * SCREEN_PIXEL_SIZE;
	vec4 origem = texture(cena, centro);
	ivec2 celula = ivec2(mod(pixel, 4.0));
	// Meio passo de quantização pico a pico: padrão discreto, sem variar no tempo.
	float dither = ((BAYER[celula.y][celula.x] + 0.5) / 16.0 - 0.5) * 0.5;
	vec3 quantizado = floor(clamp(origem.rgb, 0.0, 1.0) * 31.0 + 0.5 + dither) / 31.0;
	COLOR = vec4(clamp(quantizado, 0.0, 1.0), origem.a);
}
"""

var _retangulo: ColorRect
var _material: ShaderMaterial
var _pai: Node
var _ordem_pendente := false


func _init() -> void:
	layer = 3


func _ready() -> void:
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_retangulo = ColorRect.new()
	_retangulo.name = "QuantizacaoMundo"
	_retangulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retangulo.visible = false
	add_child(_retangulo)
	_retangulo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Config.graficos_mudou.connect(_aplicar_perfil)
	# --perfil é aplicado antes de montar a apresentação e não precisa emitir sinal.
	_aplicar_perfil()
	_pai = get_parent()
	_pai.child_order_changed.connect(_agendar_ordem)
	_agendar_ordem()


## CanvasLayers com mesmo layer não têm desempate garantido; a vinheta fica no sublayer normal.
func _agendar_ordem() -> void:
	if _ordem_pendente or not is_inside_tree():
		return
	_ordem_pendente = true
	_ordenar.call_deferred()


func _ordenar() -> void:
	_ordem_pendente = false
	if is_inside_tree():
		RenderingServer.viewport_set_canvas_stacking(get_viewport().get_viewport_rid(), get_canvas(), 3, -1)


func _aplicar_perfil() -> void:
	var ligado := Config.g_perfil() == "alto"
	_retangulo.material = _material if ligado else null
	_retangulo.visible = ligado


func _exit_tree() -> void:
	if is_instance_valid(_pai) and _pai.child_order_changed.is_connected(_agendar_ordem):
		_pai.child_order_changed.disconnect(_agendar_ordem)
	_pai = null
	if Config.graficos_mudou.is_connected(_aplicar_perfil):
		Config.graficos_mudou.disconnect(_aplicar_perfil)

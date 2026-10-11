extends RefCounted
## Atmosfera da v2 (extraída do protótipo cara_nova): vaga-lumes e folhas vermelhas caindo (seguem a câmera, só cobrem o que se vê), fogo
## de verdade (chama, brasas e fumaça) e faíscas das magias. Tudo CPUParticles2D baratas, na camada sem escurecimento (a do brilho).
## A quantidade vem da opção "particulas_sim" da aba Gráficos (Config.fator_particulas): "amb_particulas" para o ambiente e
## "efe_particulas" para fogo e faíscas. Nenhuma = nada emite. Fogo e faíscas fora da tela ficam parados (`ligar`).

const LARG := 960
const ALT := 540

var tex_brilho: GradientTexture2D
var fator_amb := 1.0
var fator_efe := 1.0
var _glow: Node
var _regs: Array = []  # {"p": CPUParticles2D, "base": amount, "tipo": "amb" | "efe"}
var _vaga: CPUParticles2D
var _folhas: CPUParticles2D


func montar(glow: Node) -> void:
	_glow = glow
	tex_brilho = _textura_brilho()


## brilho com queda suave (núcleo claro, halo que some): o corpo das magias e das chamas, no lugar do disco chapado
func _textura_brilho() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.3, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.05), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _rampa_alfa(offs: Array, alfas: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	var cs := PackedColorArray()
	for a in alfas:
		cs.append(Color(1, 1, 1, a))
	g.colors = cs
	return g


func _aditivo() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func _registrar(p: CPUParticles2D, base: int, tipo: String) -> void:
	_regs.append({"p": p, "base": base, "tipo": tipo})
	_glow.add_child(p)
	_aplicar(_regs.back())


func _aplicar(r: Dictionary) -> void:
	var p: CPUParticles2D = r.p
	var f := fator_amb if r.tipo == "amb" else fator_efe
	var n := int(round(float(r.base) * f))
	if n <= 0:
		p.emitting = false
		return
	if p.amount != n:
		p.amount = n
	p.emitting = true


## Aplica os fatores de partículas (Config.fator_particulas) a tudo que já existe.
func definir_fatores(amb: float, efe: float) -> void:
	fator_amb = amb
	fator_efe = efe
	for r in _regs:
		_aplicar(r)


## Liga ou desliga o processamento de um emissor (fogo e faíscas fora da tela não gastam nada por quadro).
func ligar(p: CPUParticles2D, ligado: bool) -> void:
	p.visible = ligado
	p.process_mode = Node.PROCESS_MODE_INHERIT if ligado else Node.PROCESS_MODE_DISABLED


## Vaga-lumes e folhas: os emissores vão para o centro da câmera (as partículas já emitidas ficam no mundo).
func ambiente(centro: Vector2) -> void:
	var f := CPUParticles2D.new()
	f.amount = 34
	f.lifetime = 7.0
	f.preprocess = 7.0
	f.local_coords = false
	f.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	f.emission_rect_extents = Vector2(LARG / 2.0, ALT / 2.0)
	f.position = centro
	f.direction = Vector2(0, -1)
	f.spread = 180.0
	f.gravity = Vector2(0, -2)
	f.initial_velocity_min = 3.0
	f.initial_velocity_max = 11.0
	f.tangential_accel_min = -6.0
	f.tangential_accel_max = 6.0
	f.damping_min = 0.5
	f.damping_max = 1.5
	f.color = Color(0.78, 1.0, 0.42)
	f.color_ramp = _rampa_alfa([0.0, 0.12, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0], [0.0, 1.0, 0.25, 1.0, 0.3, 1.0, 0.6, 0.0])
	f.texture = tex_brilho
	f.scale_amount_min = 0.03
	f.scale_amount_max = 0.07
	f.material = _aditivo()
	_vaga = f
	_registrar(f, 34, "amb")
	var fo := CPUParticles2D.new()
	fo.amount = 30
	fo.lifetime = 22.0
	fo.preprocess = 22.0
	fo.local_coords = false
	fo.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fo.emission_rect_extents = Vector2(LARG / 2.0 + 40.0, 4.0)
	fo.position = centro + Vector2(0, -ALT / 2.0 - 10.0)
	fo.direction = Vector2(0.25, 1.0)
	fo.spread = 14.0
	fo.gravity = Vector2.ZERO
	fo.initial_velocity_min = 16.0
	fo.initial_velocity_max = 28.0
	fo.angular_velocity_min = -90.0
	fo.angular_velocity_max = 90.0
	fo.tangential_accel_min = -4.0
	fo.tangential_accel_max = 4.0
	fo.color = Color(0.85, 0.1, 0.07, 0.95)
	var im := Image.create(4, 3, false, Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	fo.texture = ImageTexture.create_from_image(im)
	fo.scale_amount_min = 0.8
	fo.scale_amount_max = 1.4
	_folhas = fo
	_registrar(fo, 30, "amb")


func seguir(centro: Vector2) -> void:
	if _vaga != null:
		_vaga.position = centro
	if _folhas != null:
		_folhas.position = centro + Vector2(0, -ALT / 2.0 - 10.0)


## Fogo de verdade: chama (laranja para amarelo, de baixo para cima), brasas subindo e um pouco de fumaça escura.
func fogo(pos: Vector2, esc: float) -> Array[CPUParticles2D]:
	var add := _aditivo()
	var chama := CPUParticles2D.new()
	chama.amount = 36
	chama.lifetime = 0.7
	chama.preprocess = 0.7
	chama.local_coords = false
	chama.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	chama.emission_sphere_radius = 4.0 * esc
	chama.direction = Vector2(0, -1)
	chama.spread = 12.0
	chama.gravity = Vector2(0, -18)
	chama.initial_velocity_min = 16.0 * esc
	chama.initial_velocity_max = 30.0 * esc
	chama.scale_amount_min = 0.08 * esc
	chama.scale_amount_max = 0.17 * esc
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.5, 0.8, 1.0])
	g.colors = PackedColorArray(
		[Color(1, 0.95, 0.6, 0.0), Color(1, 0.85, 0.35, 1.0), Color(1, 0.5, 0.1, 0.85), Color(0.8, 0.15, 0.05, 0.45), Color(0.3, 0.05, 0.02, 0.0)]
	)
	chama.color_ramp = g
	chama.texture = tex_brilho
	chama.material = add
	chama.position = pos
	_registrar(chama, 36, "efe")
	var brasas := CPUParticles2D.new()
	brasas.amount = 10
	brasas.lifetime = 2.2
	brasas.preprocess = 2.2
	brasas.local_coords = false
	brasas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	brasas.emission_sphere_radius = 4.0 * esc
	brasas.direction = Vector2(0, -1)
	brasas.spread = 35.0
	brasas.gravity = Vector2(0, -6)
	brasas.initial_velocity_min = 22.0
	brasas.initial_velocity_max = 50.0
	brasas.scale_amount_min = 0.012
	brasas.scale_amount_max = 0.026
	brasas.color = Color(1.0, 0.6, 0.2)
	brasas.color_ramp = _rampa_alfa([0.0, 0.15, 0.7, 1.0], [0.0, 1.0, 0.7, 0.0])
	brasas.texture = tex_brilho
	brasas.material = add
	brasas.position = pos
	_registrar(brasas, 10, "efe")
	var fumaca := CPUParticles2D.new()
	fumaca.amount = 8
	fumaca.lifetime = 2.6
	fumaca.preprocess = 2.6
	fumaca.local_coords = false
	fumaca.direction = Vector2(0.2, -1)
	fumaca.spread = 15.0
	fumaca.gravity = Vector2(0, -3)
	fumaca.initial_velocity_min = 8.0
	fumaca.initial_velocity_max = 16.0
	fumaca.scale_amount_min = 0.1 * esc
	fumaca.scale_amount_max = 0.2 * esc
	fumaca.color = Color(0.07, 0.07, 0.08)
	fumaca.color_ramp = _rampa_alfa([0.0, 0.25, 1.0], [0.0, 0.4, 0.0])
	fumaca.texture = tex_brilho
	fumaca.position = pos + Vector2(0, -8 * esc)
	_registrar(fumaca, 8, "efe")
	return [chama, brasas, fumaca]


## poucas partículas subindo do corpo da magia
func faiscas(cor: Color, pos: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 10
	p.lifetime = 1.6
	p.preprocess = 1.6
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 7.0
	p.direction = Vector2(0, -1)
	p.spread = 35.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.color = cor.lerp(Color.WHITE, 0.3)
	p.color_ramp = _rampa_alfa([0.0, 0.2, 1.0], [0.0, 1.0, 0.0])
	p.texture = tex_brilho
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.05
	p.material = _aditivo()
	p.position = pos
	_registrar(p, 10, "efe")
	return p

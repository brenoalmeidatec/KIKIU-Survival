extends Node3D
## Visual 3D do Vornak (v3): instância do glb (assets/3d/vornak.glb) com AnimationPlayer.
## Toca a animação pelo estado, troca os materiais importados pelo shader toon de 2 tons + contorno
## e aplica a intensidade da energia (fendas, olhos) quadro a quadro, lida de assets/3d/vornak_energia.json.

const TOON := preload("res://cena_3d/toon_vornak.gdshader")
const CONTORNO := preload("res://cena_3d/contorno.gdshader")
const ENERGIA_JSON := "res://assets/3d/vornak_energia.json"

## estado -> animação do glb
const ANIM := {
	"idle": "Idle", "walk": "Walk", "run": "Run",
	"attack_01": "Attack_01", "attack_02": "Attack_02", "attack_03": "Attack_03", "attack_04": "Attack_04_Segunda_Forma",
	"hit": "Hit", "stagger": "Stagger", "phase_transition": "Phase_Transition", "death": "Death", "grito": "Grito",
	"ability": "Ability",
}
const EM_LOOP := ["Idle", "Walk", "Run"]

## grupos de cor (luz, sombra, força da emissão), paleta da folha conceitual
const GRUPOS := {
	"madeira": [Color("#6b4a2e"), Color("#3f2c1c"), 0.0],
	"musgo": [Color("#6f9a3c"), Color("#4f7a2a"), 0.0],
	"cipo": [Color("#4f7a2a"), Color("#34541f"), 0.0],
	"rosto": [Color("#4f7a2a"), Color("#34541f"), 0.0],
	"dente": [Color("#8b6b4e"), Color("#6b4a2e"), 0.0],
	"energia": [Color("#b8ff4a"), Color("#6f9a3c"), 0.6],
}
const MATERIAL_GRUPO := {
	"VN_Casca": "madeira", "VN_Tronco": "madeira", "VN_Galho": "madeira",
	"VN_Musgo": "musgo", "VN_Folha": "musgo", "VN_Verde": "cipo", "VN_Rosto": "rosto", "VN_Dente": "dente",
	"VN_Olho": "energia", "VN_Energia": "energia", "VN_Marca": "energia", "VN_Boca": "energia",
}

var animador: AnimationPlayer
var estado := ""
var energia := {}
var mats_energia: Array[ShaderMaterial] = []
var mult_energia := 1.0  ## fase 2: energia mais intensa
var modelo: Node3D


func _ready() -> void:
	modelo = get_node_or_null("Modelo")
	animador = _achar_animador(self)
	if animador:
		for nome in EM_LOOP:
			if animador.has_animation(nome):
				animador.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	_aplicar_materiais(self)
	if FileAccess.file_exists(ENERGIA_JSON):
		energia = JSON.parse_string(FileAccess.get_file_as_string(ENERGIA_JSON))
	tocar("idle")


func _achar_animador(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for f in n.get_children():
		var a := _achar_animador(f)
		if a:
			return a
	return null


func _aplicar_materiais(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var nome := m.resource_name if m else ""
			mi.set_surface_override_material(i, criar_material(String(MATERIAL_GRUPO.get(nome, "madeira"))))
	for f in n.get_children():
		_aplicar_materiais(f)


func criar_material(grupo: String) -> ShaderMaterial:
	var g: Array = GRUPOS[grupo]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("cor_luz", g[0])
	m.set_shader_parameter("cor_sombra", g[1])
	m.set_shader_parameter("forca_emissao", g[2])
	var c := ShaderMaterial.new()
	c.shader = CONTORNO
	m.next_pass = c
	if g[2] > 0.0:
		mats_energia.append(m)
	return m


## Toca a animação do estado (idle, walk, run, attack_01..04, hit, stagger, phase_transition, death, grito, ability).
func tocar(e: String, reiniciar := false) -> void:
	if animador == null:
		estado = e
		return
	var nome: String = ANIM.get(e, "Idle")
	if e == estado and not reiniciar and animador.is_playing():
		return
	estado = e
	animador.play(nome, 0.12)
	if reiniciar:
		animador.seek(0.0, true)


func duracao(e: String) -> float:
	var nome: String = ANIM.get(e, "Idle")
	if animador and animador.has_animation(nome):
		return animador.get_animation(nome).length
	return 1.0


func animacao_atual() -> String:
	return animador.current_animation if animador else ""


func nomes_animacoes() -> PackedStringArray:
	return animador.get_animation_list() if animador else PackedStringArray()


func _process(_dt: float) -> void:
	if animador == null or mats_energia.is_empty():
		return
	var nome := animador.current_animation
	var v := 1.0
	if energia.has(nome):
		var vals: Array = energia[nome]["valores"]
		var i := clampi(int(animador.current_animation_position * float(energia[nome]["fps"])), 0, vals.size() - 1)
		v = float(vals[i])
	v = clampf(v * mult_energia, 0.0, 4.0)
	for m in mats_energia:
		m.set_shader_parameter("intensidade", v)

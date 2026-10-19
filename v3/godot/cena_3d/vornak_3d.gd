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

## Sons sintetizados (assets/audio/vornak/, gerados por docs/v3/chefes/sintetizar_sons_vornak.py) e volume em dB.
const SONS := {
	"passo": -9.0, "rugido": 0.0, "estalo_madeira": -6.0, "terra_rachando": -4.0,
	"zumbido_energia": -10.0, "golpe_chao": -2.0, "succao_absorcao": -6.0,
}
const PASTA_SONS := "res://assets/audio/vornak/"
## Mapa de tempo: animação -> [[quadro do clipe (12 fps, quadro 1 = início), som], ...], conforme vornak_sons.md.
## O instante é no tempo do clipe, então segue a reescala do combate (aviso/recuperação) sozinho.
const MAPA_SONS := {
	"Walk": [[1, "passo"], [13, "passo"]],
	"Run": [[1, "passo"], [5, "passo"], [9, "passo"], [13, "passo"]],
	"Attack_01": [[4, "zumbido_energia"], [22, "golpe_chao"], [23, "terra_rachando"], [25, "estalo_madeira"], [28, "estalo_madeira"]],
	"Attack_02": [[5, "estalo_madeira"], [8, "golpe_chao"]],
	"Attack_03": [[1, "succao_absorcao"], [9, "zumbido_energia"]],
	"Attack_04_Segunda_Forma": [[1, "rugido"], [9, "estalo_madeira"], [12, "estalo_madeira"], [14, "terra_rachando"]],
	"Ability": [[1, "succao_absorcao"], [4, "zumbido_energia"]],
	"Hit": [[1, "estalo_madeira"]],
	"Stagger": [[1, "estalo_madeira"], [4, "golpe_chao"]],
	"Phase_Transition": [[1, "zumbido_energia"], [12, "golpe_chao"], [12, "terra_rachando"]],
	"Grito": [[10, "rugido"]],
	"Death": [[1, "estalo_madeira"], [14, "terra_rachando"]],
}
const VOZES := 8

signal som_tocado(nome: String)
var sons := {}              ## nome -> AudioStream
var contador_sons := {}     ## nome -> quantas vezes tocou (o teste lê)
var _vozes: Array[AudioStreamPlayer] = []
var _voz_i := 0
var _som_anim := ""
var _som_pos := -0.001

## Grupos de cor: rampa de 5 tons (sombra funda -> brilho), textura de detalhe, escala da UV e se é energia.
## Paleta a partir da folha conceitual (madeira #6b4a2e/#3f2c1c, musgo #6f9a3c/#4f7a2a, energia #b8ff4a),
## com tons de transição: sombras puxando para o frio, luzes para o quente. 29 cores no Vornak + contorno.
const TEX := "res://assets/3d/texturas/"
const GRUPOS := {
	"madeira": {"tons": ["#24191a", "#3f2c1c", "#5c3f28", "#7a5534", "#9c7650"], "tex": "madeira", "escala": 1.4},
	"musgo": {"tons": ["#1f3320", "#34541f", "#4f7a2a", "#6f9a3c", "#9cc25a"], "tex": "musgo", "escala": 1.4},
	"cipo": {"tons": ["#1a2a1f", "#2b4420", "#3f6128", "#577f33", "#6f9a3c"], "tex": "cipo", "escala": 1.0},
	"dente": {"tons": ["#3f2c1c", "#6e5641", "#8b6b4e", "#b39a7a", "#d8c9a8"], "tex": "dente", "escala": 1.0},
	"energia": {"tons": ["#4f7a2a", "#8fd13a", "#b8ff4a", "#dcff8a", "#f4ffd8"], "tex": "energia", "escala": 1.0, "energia": true},
	"olho": {"tons": ["#2e3d10", "#7aa82a", "#b8ff4a", "#e8ff9c", "#ffffff"], "tex": "olho", "escala": 1.0, "energia": true},
}
const MATERIAL_GRUPO := {
	"VN_Casca": "madeira", "VN_Tronco": "madeira", "VN_Galho": "madeira",
	"VN_Musgo": "musgo", "VN_Folha": "musgo", "VN_Verde": "cipo", "VN_Rosto": "cipo", "VN_Dente": "dente",
	"VN_Olho": "olho", "VN_Energia": "energia", "VN_Marca": "energia", "VN_Boca": "energia",
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
	_carregar_sons()
	tocar("idle")


func _carregar_sons() -> void:
	for nome in SONS:
		var s := load(PASTA_SONS + nome + ".wav") as AudioStream
		if s:
			sons[nome] = s
		contador_sons[nome] = 0
	for i in VOZES:
		var p := AudioStreamPlayer.new()
		p.name = "Voz%d" % i
		add_child(p)
		_vozes.append(p)


func tocar_som(nome: String) -> void:
	contador_sons[nome] = int(contador_sons.get(nome, 0)) + 1
	som_tocado.emit(nome)
	if not sons.has(nome) or _vozes.is_empty():
		return
	var p := _vozes[_voz_i]
	_voz_i = (_voz_i + 1) % _vozes.size()
	p.stream = sons[nome]
	p.volume_db = float(SONS[nome])
	p.play()


## Dispara os sons do mapa cujo quadro foi cruzado desde o último quadro (inclusive na volta do loop).
func _disparar_sons() -> void:
	var nome := animador.current_animation
	if nome == "":
		return
	var pos := animador.current_animation_position
	if nome != _som_anim:
		_som_anim = nome
		_som_pos = -0.001
	if not MAPA_SONS.has(nome):
		_som_pos = pos
		return
	var comp := animador.get_animation(nome).length
	for ev in MAPA_SONS[nome]:
		var t := (float(ev[0]) - 1.0) / 12.0
		var cruzou := (_som_pos < t and t <= pos) if pos >= _som_pos else (t > _som_pos and t <= comp) or t <= pos
		if cruzou:
			tocar_som(String(ev[1]))
	_som_pos = pos


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
	var g: Dictionary = GRUPOS[grupo]
	var m := ShaderMaterial.new()
	m.shader = TOON
	for i in 5:
		m.set_shader_parameter("tom_%d" % i, Color(g.tons[i]))
	m.set_shader_parameter("detalhe", load(TEX + String(g.tex) + ".png"))
	m.set_shader_parameter("escala_uv", float(g.escala))
	var e := bool(g.get("energia", false))
	m.set_shader_parameter("energia", 1.0 if e else 0.0)
	var c := ShaderMaterial.new()
	c.shader = CONTORNO
	m.next_pass = c
	if e:
		mats_energia.append(m)
	return m


## Toca a animação do estado (idle, walk, run, attack_01..04, hit, stagger, phase_transition, death, grito, ability).
## Trocar de animação volta a velocidade para 1x (o combate reescala os ataques com velocidade_anim()).
func tocar(e: String, reiniciar := false, mistura := 0.12) -> void:
	if animador == null:
		estado = e
		return
	var nome: String = ANIM.get(e, "Idle")
	if e == estado and not reiniciar and animador.is_playing():
		return
	estado = e
	animador.speed_scale = 1.0
	animador.play(nome, mistura)
	if reiniciar:
		animador.seek(0.0, true)
	_som_anim = nome
	_som_pos = -0.001


## Velocidade do clipe atual (AnimationPlayer.speed_scale): o aviso e a recuperação dos ataques são reescalados.
func velocidade_anim(v: float) -> void:
	if animador:
		animador.speed_scale = v


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
	if animador == null:
		return
	_disparar_sons()
	if mats_energia.is_empty():
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

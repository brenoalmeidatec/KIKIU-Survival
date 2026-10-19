extends Control
## Cena do protótipo 3D do Vornak: câmera isométrica ortográfica dentro de uma SubViewport de baixa resolução
## (320x180 numa janela 1280x720, ampliada por nearest), HUD simples e modos de demonstração para gravação.
## Teclas: WASD/setas anda, espaço bate, Tab troca câmera (retrato/arena), R reinicia.
## Demonstração (para --write-movie): -- --demo=andar | --demo=ataque | --demo=fase | --demo=foto

var tamanho_retrato := 5.0   ## chefe com ~75% da altura da tela (medido: 340 px de 720 com size 8); -- --tamanho=X muda
const TAMANHO_ARENA := 9.0     ## mostra o círculo de 3 m inteiro
const ALVO_ALTURA := 1.8

@onready var container: SubViewportContainer = $Tela
@onready var viewport: SubViewport = $Tela/Viewport
@onready var mundo: Node3D = $Tela/Viewport/Mundo
@onready var camera: Camera3D = $Tela/Viewport/Mundo/Camera
@onready var vornak: Node3D = $Tela/Viewport/Mundo/Vornak
@onready var heroi: CharacterBody3D = $Tela/Viewport/Mundo/Heroi
@onready var hud: Label = $Hud

var modo_camera := "retrato"
var demo := ""
var t := 0.0
var tab_antes := false
var r_antes := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			demo = a.substr(7)
		if a.begins_with("--tamanho="):
			tamanho_retrato = a.substr(10).to_float()
			camera.size = tamanho_retrato
	container.stretch_shrink = maxi(1, int(round(container.size.y / 180.0))) if container.size.y > 0 else 4
	_preparar_demo()
	_posicionar_camera(1.0)


func _preparar_demo() -> void:
	if demo == "":
		return
	heroi.controle_ligado = false
	match demo:
		"andar":
			mundo.ataques_ligados = false
			mundo.pode_correr = false
			heroi.position = Vector3(-4.0, 0, 6.0)
			vornak.position = Vector3(1.5, 0, -2.0)
		"ataque":
			modo_camera = "arena"
			mundo.ataques_ligados = false
			heroi.position = Vector3(1.2, 0, 2.0)
		"fase":
			mundo.ataques_ligados = false
			heroi.position = Vector3(0.8, 0, 1.6)
			mundo.vida = mundo.VIDA_CHEFE * 0.42
		"foto", "calibrar":
			mundo.ataques_ligados = false
			mundo.ativo = false
			heroi.visible = false
			vornak.rotation.y = deg_to_rad(45.0)  # de frente para a câmera
			if demo == "calibrar":
				mundo.get_node("Chao").visible = false


func _process(dt: float) -> void:
	t += dt
	if demo == "ataque" and t >= 0.3 and mundo.estado == "andar" and mundo.historico.count("aviso") == 0:
		mundo.forcar_ataque("raizes")
	if demo == "fase" and t >= 0.4 and mundo.fase == 1 and mundo.estado != "transicao":
		heroi.bater()
	if demo != "" and t >= 4.05:
		get_tree().quit()
	if demo == "":
		var tab := Input.is_physical_key_pressed(KEY_TAB)
		if tab and not tab_antes:
			modo_camera = "arena" if modo_camera == "retrato" else "retrato"
		tab_antes = tab
		var r := Input.is_physical_key_pressed(KEY_R)
		if r and not r_antes:
			get_tree().reload_current_scene()
		r_antes = r
	_posicionar_camera(dt)
	hud.text = "Vornak %d/%d  fase %d  estado: %s\nHerói %d/%d   (WASD/setas, espaço bate, Tab câmera, R reinicia)" % [
		mundo.vida, mundo.VIDA_CHEFE, mundo.fase, mundo.estado, mundo.vida_heroi, mundo.VIDA_HEROI]


func _posicionar_camera(dt: float) -> void:
	var alvo := vornak.global_position + Vector3(0, ALVO_ALTURA, 0)
	var tamanho := tamanho_retrato
	if modo_camera == "arena":
		alvo = vornak.global_position.lerp(heroi.global_position, 0.25) + Vector3(0, 0.6, 0)
		tamanho = TAMANHO_ARENA
	camera.size = lerpf(camera.size, tamanho, clampf(dt * 6.0, 0.0, 1.0))
	camera.global_position = alvo + camera.global_transform.basis.z * 30.0

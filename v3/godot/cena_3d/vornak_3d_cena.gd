extends Control
## Cena do protótipo 3D do Vornak: câmera isométrica ortográfica dentro de uma SubViewport de resolução interna
## 640x360 numa janela 1280x720 (ampliada 2x por nearest), HUD simples e modos de demonstração para gravação.
## A câmera segue o alvo com suavização (constante de tempo de 0,15 s) e tem a posição presa à grade de texels
## da resolução interna; o modelo do chefe e o corpo do herói também, para o pixel não "nadar" ao andar.
## Teclas: WASD/setas anda, espaço bate, Tab troca câmera (retrato/arena), R reinicia.
## Demonstração (para --write-movie): -- --demo=andar | --demo=ataque | --demo=fase | --demo=foto | --demo=calibrar
## -- --medir imprime o FPS médio ao fechar a demonstração.

var tamanho_retrato := 5.0     ## altura visível em metros (Camera3D.size); o chefe ocupa ~75% da tela. -- --tamanho=X muda
const TAMANHO_ARENA := 9.0     ## mostra o círculo de 3 m inteiro
const ALVO_ALTURA := 1.8
const SUAVIZACAO := 0.15       ## constante de tempo (s) do lerp da câmera até o alvo
const DISTANCIA_CAMERA := 30.0
const DURACAO_DEMO := {"fase": 5.6}  ## as outras demonstrações fecham em 4,05 s

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
var medir := false
var _quadros_medidos := 0
var _t0_usec := 0
var alvo_suave := Vector3.ZERO   ## posição suavizada (sem grade) do ponto que a câmera olha
var _primeiro := true
var erro_grade_camera := 0.0
var erro_grade_modelo := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			demo = a.substr(7)
		if a.begins_with("--tamanho="):
			tamanho_retrato = a.substr(10).to_float()
			camera.size = tamanho_retrato
		if a == "--medir":
			medir = true
	_t0_usec = Time.get_ticks_usec()
	var alt_interna := float(viewport.size.y)
	container.stretch_shrink = maxi(1, int(round(container.size.y / alt_interna))) if container.size.y > 0 else 2
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
			# um golpe do herói leva a vida abaixo de 40%
			mundo.vida = mundo.VIDA_CHEFE * mundo.FASE2 + mundo.DANO_HEROI * 0.5
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
	_quadros_medidos += 1
	if demo != "" and t >= float(DURACAO_DEMO.get(demo, 4.05)):
		if medir:
			var seg := (Time.get_ticks_usec() - _t0_usec) / 1e6
			print("MEDIDA_FPS quadros=%d tempo=%.2f fps=%.1f viewport=%s" % [_quadros_medidos, seg, _quadros_medidos / seg, viewport.size])
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


## Tamanho de um texel da resolução interna em metros do mundo. Na Godot, Camera3D.size ortográfica é a ALTURA
## inteira visível (keep_aspect = altura), então o texel é size / altura interna (equivale a 2*meia_altura/altura).
func texel() -> float:
	return camera.size / float(viewport.size.y)


## Prende um ponto à grade de texels no plano da câmera (eixos direita e cima da câmera). A profundidade
## (eixo de visão) não muda a imagem na projeção ortográfica e fica livre.
func na_grade(p: Vector3) -> Vector3:
	var b := camera.global_transform.basis
	var tx := texel()
	var x := p.dot(b.x)
	var y := p.dot(b.y)
	return p + b.x * (roundf(x / tx) * tx - x) + b.y * (roundf(y / tx) * tx - y)


func _posicionar_camera(dt: float) -> void:
	var alvo := vornak.global_position + Vector3(0, ALVO_ALTURA, 0)
	var tamanho := tamanho_retrato
	if modo_camera == "arena":
		alvo = vornak.global_position.lerp(heroi.global_position, 0.25) + Vector3(0, 0.6, 0)
		tamanho = TAMANHO_ARENA
	camera.size = lerpf(camera.size, tamanho, 1.0 - exp(-dt / SUAVIZACAO))
	if _primeiro:
		camera.size = tamanho
		alvo_suave = alvo
		_primeiro = false
	else:
		alvo_suave = alvo_suave.lerp(alvo, 1.0 - exp(-dt / SUAVIZACAO))
	camera.global_position = na_grade(alvo_suave + camera.global_transform.basis.z * DISTANCIA_CAMERA)
	# o desenho do chefe e do herói anda em passos de 1 texel (a lógica e as áreas de dano seguem livres)
	var modelo := vornak.get_node_or_null("Modelo") as Node3D
	if modelo:
		modelo.global_position = na_grade(vornak.global_position)
	for n in ["Corpo", "Golpe"]:
		var c := heroi.get_node_or_null(n) as Node3D
		if c:
			var local := Vector3(0, 0.6 if n == "Corpo" else 0.5, 0)
			c.global_position = na_grade(heroi.global_position + local)
	# conferência (o teste lê): quanto a câmera e o modelo ficaram fora da grade neste quadro, em texels
	erro_grade_camera = _fora_da_grade(camera.global_position)
	erro_grade_modelo = _fora_da_grade(modelo.global_position) if modelo else 0.0


func _fora_da_grade(p: Vector3) -> float:
	var b := camera.global_transform.basis
	var tx := texel()
	var ex := absf(p.dot(b.x) / tx - roundf(p.dot(b.x) / tx))
	var ey := absf(p.dot(b.y) / tx - roundf(p.dot(b.y) / tx))
	return maxf(ex, ey)

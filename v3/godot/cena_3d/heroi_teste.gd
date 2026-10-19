extends CharacterBody3D
## Herói de teste (cápsula) do protótipo 3D: anda com WASD ou setas (direções da câmera isométrica)
## e bate com espaço. Só serve para apanhar e bater no Vornak; não é o herói da v2.

@export var combate_path: NodePath = ^".."
@export var velocidade := 3.5
var controle_ligado := true   ## os modos de demonstração e o teste desligam o teclado
var espaco_antes := false
var t_golpe := 0.0
var combate: Node


func _ready() -> void:
	combate = get_node(combate_path)


func _physics_process(dt: float) -> void:
	t_golpe = maxf(0.0, t_golpe - dt)
	if not controle_ligado:
		return
	var e := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		e.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		e.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		e.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		e.x += 1
	# câmera girada 45 graus em Y: "cima" na tela é (-1, 0, -1) no chão
	var dir := Vector3(e.x + e.y, 0, e.y - e.x).normalized() if e != Vector2.ZERO else Vector3.ZERO
	velocity = dir * velocidade
	move_and_slide()
	var esp := Input.is_physical_key_pressed(KEY_SPACE)
	if esp and not espaco_antes:
		bater()
	espaco_antes = esp


func bater() -> bool:
	if t_golpe > 0.0:
		return false
	t_golpe = 0.35
	var v := get_node_or_null("Golpe") as Node3D
	if v:
		v.visible = true
		get_tree().create_timer(0.15).timeout.connect(func(): v.visible = false)
	return combate.heroi_bate()

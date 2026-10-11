extends "res://v2/ator.gd"
## Herói da v2 (Hazaki): anda com WASD, setas e analógico esquerdo; fica virado para o MOUSE (8 direções) quando o mouse mexe, e para onde
## anda quando a direção de andar muda; com o controle, o analógico direito manda. Anima parado e andando com a folha do protótipo. A tocha
## e a aura são luzes presas a ele (criadas em mundo.gd). O golpe principal (ação "atacar") é só um gancho: `atacar()` fica para a próxima leva.

enum Fonte { ANDA, MOUSE, STICK }
const VEL := 100.0  # px/s
const PASSO_ANIM := 0.13  # s por quadro de andar
const CENTRO_CORPO := Vector2(0, -20)  # do pé ao meio do corpo (mira e câmera)

var mundo
var fonte := Fonte.ANDA
var dir_olhar := Vector2(0, 1)  # para onde está virado (nunca zero)
var mira_mundo := Vector2.ZERO  # ponto do mundo para onde o golpe vai (mouse ou analógico direito)
var entrada_forcada: Variant = null  # testes, fotos e medição: um Vector2 aqui vale no lugar do teclado e do controle
var andando := false
var vel := Vector2.ZERO  # deslocamento real do último quadro, px/s
var _anda_ant := Vector2.ZERO
var _anim := 0.0


func criar(m, pai: Node, t: Dictionary, p: Vector2) -> void:
	mundo = m
	chave = "hazaki"
	raio = 6.0
	montar_animado(pai, t, p, 0, 0, false)


## A mira (para o futuro golpe): o mouse manda, a menos que o analógico direito esteja sendo usado.
func atualizar(dt: float) -> void:
	var v: Vector2 = entrada_forcada if entrada_forcada != null else Input.get_vector("esquerda", "direita", "cima", "baixo")
	if entrada_forcada == null and InputMap.has_action("mira_esquerda"):
		var s := Input.get_vector("mira_esquerda", "mira_direita", "mira_cima", "mira_baixo")
		if s.length() > 0.3:
			fonte = Fonte.STICK
			dir_olhar = s.normalized()
	# a direção de andar mudou (começou a andar ou virou): passa a olhar para onde anda, até o mouse mexer de novo
	if v != Vector2.ZERO and (_anda_ant == Vector2.ZERO or v.normalized().dot(_anda_ant.normalized()) < 0.9):
		fonte = Fonte.ANDA
	_anda_ant = v
	andando = v != Vector2.ZERO
	if andando:
		if fonte == Fonte.ANDA:
			dir_olhar = v.normalized()
		var antes := pos
		mundo.mover(self, v * VEL * dt)
		vel = (pos - antes) / maxf(dt, 0.0001)
	else:
		vel = Vector2.ZERO
	var centro := pos + CENTRO_CORPO
	if fonte == Fonte.MOUSE:
		var d: Vector2 = mundo.mouse_mundo() - centro
		if d.length() > 4.0:
			dir_olhar = d.normalized()
	mira_mundo = centro + dir_olhar * 120.0 if fonte != Fonte.MOUSE else mundo.mouse_mundo()
	var l := linha_de(dir_olhar)
	var c := 0
	if andando:
		_anim += dt
		c = 1 + int(_anim / PASSO_ANIM) % (int(tipo.info.colunas.size()) - 1)
	else:
		_anim = 0.0
	if l != linha or c != coluna:
		quadro(c, l)
	if entrada_forcada == null and InputMap.has_action("atacar") and Input.is_action_just_pressed("atacar"):
		atacar()


## Gancho do golpe principal (ação "atacar", #166): a próxima leva liga o ataque aqui, mirando em `mira_mundo`.
func atacar() -> void:
	pass


## Linhas da folha: baixo, esquerda, direita, cima, baixo_esq, baixo_dir, cima_esq, cima_dir. As 8 direções saem do ângulo na tela.
static func linha_de(v: Vector2) -> int:
	const POR_OITANTE := [2, 5, 0, 4, 1, 6, 3, 7]  # 0 = direita, 1 = baixo-direita, 2 = baixo... (y para baixo, sentido horário)
	var oitante := posmod(int(round(v.angle() / (PI / 4.0))), 8)
	return POR_OITANTE[oitante]

extends Node3D
## Protótipo de combate em tempo real do Vornak 3D (v3, sem ligação com a v2).
## Máquina de estados: andar, aviso, impacto, recupera, stagger, transicao, morto.
## Cada ataque tem uma Area3D de dano (ligada só no quadro de impacto) e um indicador no chão
## (MeshInstance3D que pulsa e só aparece no aviso). Fase 2 abre abaixo de 40% da vida.

signal estado_mudou(novo: String)
signal heroi_atingido(dano: float)
signal chefe_atingido(dano: float)
signal heroi_caiu

# ---------------- BALANÇO (PROVISÓRIO até a v3 ter herói próprio; tudo neste bloco) ----------------
# Números da folha conceitual: vida 1200 a 1600, dano 20 a 40 por golpe, velocidade 1,2 a 1,8, recarga 2 a 4 s.
# O dano de cada golpe fica na tabela ATAQUES (raízes 30, golpe 20, absorção 0, raízes longas 35, tempestade 25).
const VIDA_CHEFE := 1400.0       ## folha: 1200 a 1600
const VIDA_HEROI := 900.0        ## herói de TESTE: com o herói parado apanhando, a luta dura 60 a 90 s (o da v2 tem 100)
const DANO_HEROI := 10.0         ## golpe do herói de teste no chefe (espaço)
const RECARGA_GOLPE_HEROI := 0.5 ## intervalo mínimo entre golpes do herói de teste (s)
const VEL_HEROI := 1.5           ## folha: 1,2 a 1,8
const ALCANCE_HEROI := 2.0
const FASE2 := 0.4
const VEL_ANDAR := 1.5           ## folha: 1,2 a 1,8
const VEL_CORRER := 1.8          ## topo da faixa da folha
const DIST_CORRER := 6.0
const ANDAR_MIN := 0.5           ## tempo mínimo andando entre ataques
const STAGGER_DANO := 150.0      ## dano recebido dentro da janela que derruba o chefe
const STAGGER_JANELA := 3.0
const CURA_MAX := 180.0          ## teto de cura da absorção na luta toda
const RECARGA_FASE2 := 0.85      ## na fase 2 as recargas encolhem 15%...
const RECARGA_MIN := 2.5         ## ...mas nunca abaixo de 2,5 s
const VEL_RECUPERA_MAX := 2.0    ## a recuperação acelera o clipe até 2x; o que sobrar do clipe é cortado
const FPS_CLIPE := 12.0
# -----------------------------------------------------------------------------------------------------

## aviso e recupera em segundos (VORNAK_COMBATE.md); quadro = quadro de impacto no clipe (12 fps, quadro 1 = início);
## segura = quadros segurados no impacto. O clipe é reescalado para o quadro de impacto cair no fim do aviso.
const ATAQUES := [
	{"nome": "raizes", "clipe": "attack_01", "forma": "circulo", "raio": 3.0, "alcance": 3.2, "quadro": 22, "segura": 2, "aviso": 0.9, "recupera": 0.6, "recarga": 3.0, "dano": 30.0, "fase": 1},
	{"nome": "golpe", "clipe": "attack_02", "forma": "setor", "raio": 2.2, "angulo": 90.0, "alcance": 2.2, "quadro": 8, "segura": 2, "aviso": 0.7, "recupera": 0.6, "recarga": 2.5, "dano": 20.0, "fase": 1},
	{"nome": "absorcao", "clipe": "attack_03", "forma": "pontos", "raio": 0.8, "distancia": 2.2, "alcance": 3.0, "quadro": 9, "segura": 2, "aviso": 1.2, "recupera": 0.8, "recarga": 4.0, "dano": 0.0, "fase": 1, "cura": 60.0},
	{"nome": "raizes_longas", "clipe": "attack_04", "forma": "circulo", "raio": 3.6, "alcance": 3.8, "quadro": 14, "segura": 2, "aviso": 0.6, "recupera": 0.5, "recarga": 3.0, "dano": 35.0, "fase": 2},
	{"nome": "tempestade", "clipe": "ability", "forma": "pontos_heroi", "raio": 1.1, "distancia": 1.6, "alcance": 7.0, "quadro": 12, "segura": 2, "aviso": 0.9, "recupera": 0.4, "recarga": 3.5, "dano": 25.0, "fase": 2},
]

const COR_IND := Color("#b8ff4a")

@export var vornak_path: NodePath = ^"Vornak"
@export var heroi_path: NodePath = ^"Heroi"

var vornak: Node3D
var heroi: Node3D
var estado := "andar"
var t_estado := 0.0
var fase := 1
var vida := VIDA_CHEFE
var vida_heroi := VIDA_HEROI
var ativo := true
var ataques_ligados := true
var pode_correr := true
var ataque: Dictionary = {}
var recargas := {}
var ja_acertou := false
var curado := 0.0
var dano_janela: Array = []   ## [tempo, dano]
var relogio := 0.0
var t_hit := 0.0
var t_aviso := 0.0
var t_recupera := 0.0
var t_transicao := 0.0
var historico: Array[String] = []
var historico_t: Array[float] = []   ## relógio de cada mudança de estado (mesma ordem do historico)
var ataques_feitos: Array[String] = []
var vel_aviso := 1.0       ## velocidade do clipe no aviso do ataque atual
var vel_recupera := 1.0    ## velocidade do clipe na recuperação do ataque atual
var heroi_morto := false
var ultimo_uso := {}       ## nome do ataque -> relógio do último uso (rodízio)
var areas := {}         ## nome do ataque -> Array[Area3D]
var indicadores := {}   ## nome do ataque -> Node3D


func _ready() -> void:
	vornak = get_node(vornak_path)
	heroi = get_node(heroi_path)
	for a in ATAQUES:
		recargas[a.nome] = 0.0
		_criar_area_e_indicador(a)
	_mudar("andar")


# ---------------- áreas de dano e indicadores ----------------
func _criar_area_e_indicador(a: Dictionary) -> void:
	var lista: Array[Area3D] = []
	var pai: Node3D = vornak
	var ind := Node3D.new()
	ind.name = "Ind_" + a.nome
	ind.visible = false
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = COR_IND
	mat.no_depth_test = false
	var fundo := mat.duplicate() as StandardMaterial3D
	fundo.albedo_color = Color(COR_IND, 0.18)
	fundo.set_meta("fundo", true)
	var posicoes: Array[Vector3] = [Vector3.ZERO]
	if a.forma == "pontos" or a.forma == "pontos_heroi":
		posicoes = []
		for i in 4:
			var ang := PI * 0.25 + i * PI * 0.5
			posicoes.append(Vector3(cos(ang), 0, sin(ang)) * float(a.distancia))
	if a.forma == "pontos_heroi":
		pai = self
		ind.top_level = true
	for p in posicoes:
		var area := Area3D.new()
		area.name = "Area_" + a.nome
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 2
		var cs := CollisionShape3D.new()
		var cil := CylinderShape3D.new()
		cil.radius = float(a.raio)
		cil.height = 2.0
		cs.shape = cil
		cs.position.y = 1.0
		area.add_child(cs)
		area.position = p
		if a.forma == "pontos_heroi":
			area.top_level = true
		pai.add_child(area)
		lista.append(area)
		var r := float(a.raio)
		if a.forma == "circulo":
			ind.add_child(_malha(_anel(r - 0.12, r, 64), mat, p))
			ind.add_child(_malha(_anel(r * 0.55 - 0.08, r * 0.55, 48), mat, p))
			ind.add_child(_malha(_anel(0.0, r, 64), fundo, p))
		elif a.forma == "setor":
			ind.add_child(_malha(_setor(r, deg_to_rad(float(a.angulo)), 0.0, 24), fundo, p))
			ind.add_child(_malha(_setor(r, deg_to_rad(float(a.angulo)), r - 0.12, 24), mat, p))
			ind.add_child(_malha(_setor(r * 0.55, deg_to_rad(float(a.angulo)), r * 0.55 - 0.08, 24), mat, p))
		else:
			ind.add_child(_malha(_anel(r - 0.1, r, 32), mat, p))
			ind.add_child(_malha(_anel(0.0, r * 0.35, 16), mat, p))
	pai.add_child(ind)
	areas[a.nome] = lista
	indicadores[a.nome] = ind


func _malha(m: ArrayMesh, mat: Material, p: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p + Vector3(0, 0.03, 0)
	return mi


func _anel(r0: float, r1: float, n: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		st.add_vertex(p0 * r0); st.add_vertex(p0 * r1); st.add_vertex(p1 * r1)
		st.add_vertex(p0 * r0); st.add_vertex(p1 * r1); st.add_vertex(p1 * r0)
	return st.commit()


## Setor virado para +Z (frente do modelo), abertura total "ang".
func _setor(r1: float, ang: float, r0: float, n: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a0 := -ang * 0.5 + ang * i / n
		var a1 := -ang * 0.5 + ang * (i + 1) / n
		var p0 := Vector3(sin(a0), 0, cos(a0))
		var p1 := Vector3(sin(a1), 0, cos(a1))
		st.add_vertex(p0 * r0); st.add_vertex(p0 * r1); st.add_vertex(p1 * r1)
		st.add_vertex(p0 * r0); st.add_vertex(p1 * r1); st.add_vertex(p1 * r0)
	return st.commit()


# ---------------- máquina de estados ----------------
func _mudar(novo: String) -> void:
	estado = novo
	t_estado = 0.0
	historico.append(novo)
	historico_t.append(relogio)
	estado_mudou.emit(novo)


func _physics_process(dt: float) -> void:
	passo(dt)


func passo(dt: float) -> void:
	relogio += dt
	_pulsar_indicadores()
	if not ativo:
		return
	t_estado += dt
	for k in recargas:
		recargas[k] = maxf(0.0, recargas[k] - dt)
	t_hit = maxf(0.0, t_hit - dt)
	var para_heroi := heroi.global_position - vornak.global_position
	para_heroi.y = 0
	var dist := para_heroi.length()
	match estado:
		"andar":
			_virar(para_heroi, dt, 4.0)
			var escolhido := _escolher_ataque(dist) if ataques_ligados and t_estado >= ANDAR_MIN else {}
			if not escolhido.is_empty():
				_iniciar_ataque(escolhido)
			elif dist > 1.6:
				var correr := pode_correr and dist > DIST_CORRER
				vornak.global_position += para_heroi.normalized() * (VEL_CORRER if correr else VEL_ANDAR) * dt
				vornak.tocar("hit" if t_hit > 0.0 else ("run" if correr else "walk"))
			else:
				vornak.tocar("hit" if t_hit > 0.0 else "idle")
		"aviso":
			if t_estado < t_aviso * 0.6:
				_virar(para_heroi, dt, 3.0)
			if t_estado >= t_aviso - 0.0001:
				_mudar("impacto")
				vornak.velocidade_anim(1.0)  # os quadros segurados do impacto tocam no ritmo do clipe
				ja_acertou = false
				indicadores[ataque.nome].visible = false
				for ar in areas[ataque.nome]:
					ar.monitoring = true
		"impacto":
			_conferir_acerto()
			if t_estado >= float(ataque.segura) / FPS_CLIPE - 0.0001:
				for ar in areas[ataque.nome]:
					ar.monitoring = false
				vornak.velocidade_anim(vel_recupera)
				_mudar("recupera")
		"recupera":
			if t_estado >= t_recupera - 0.0001:
				# se o clipe ainda não acabou (Attack_01), ele é cortado aqui com uma mistura mais longa
				vornak.tocar("idle", false, 0.3)
				_mudar("andar")
		"stagger":
			if t_estado >= vornak.duracao("stagger"):
				_mudar("andar")
		"transicao":
			if t_estado < vornak.duracao("phase_transition"):
				vornak.tocar("phase_transition")
			else:
				vornak.tocar("grito")
			if t_estado >= t_transicao:
				fase = 2
				_mudar("andar")
		"morto":
			pass


func _virar(dir: Vector3, dt: float, vel: float) -> void:
	if dir.length() < 0.01:
		return
	var alvo := atan2(dir.x, dir.z)  # a frente do modelo é +Z
	vornak.rotation.y = lerp_angle(vornak.rotation.y, alvo, clampf(vel * dt, 0.0, 1.0))


## Entre os ataques prontos e no alcance, escolhe o usado há mais tempo (rodízio); na fase 2 os ataques
## da fase 2 vêm antes. Empate: a ordem da tabela.
func _escolher_ataque(dist: float) -> Dictionary:
	var melhor: Dictionary = {}
	var melhor_nota := INF
	for a in ATAQUES:
		if (fase >= int(a.fase)) and recargas[a.nome] <= 0.0 and dist <= float(a.alcance):
			if fase == 2 and int(a.fase) == 1 and a.nome == "raizes":
				continue  # na fase 2 as raízes viram raízes longas
			var nota := float(ultimo_uso.get(a.nome, -1000.0)) - (100.0 if fase == 2 and int(a.fase) == 2 else 0.0)
			if nota < melhor_nota:
				melhor_nota = nota
				melhor = a
	return melhor


func forcar_ataque(nome: String) -> void:
	for a in ATAQUES:
		if a.nome == nome:
			_iniciar_ataque(a)


func _iniciar_ataque(a: Dictionary) -> void:
	ataque = a
	recargas[a.nome] = maxf(RECARGA_MIN, float(a.recarga) * (RECARGA_FASE2 if fase == 2 else 1.0))
	ataques_feitos.append(a.nome)
	ultimo_uso[a.nome] = relogio
	# tempos da folha: o clipe é reescalado para o quadro de impacto cair no fim do aviso
	var t_imp := t_impacto_clipe(a)
	t_aviso = float(a.aviso)
	vel_aviso = t_imp / t_aviso
	t_recupera = float(a.recupera)
	var resto: float = vornak.duracao(a.clipe) - t_imp - float(a.segura) / FPS_CLIPE
	vel_recupera = clampf(resto / t_recupera, 1.0, VEL_RECUPERA_MAX)
	if a.forma == "pontos_heroi":
		var base := heroi.global_position
		var lista: Array = areas[a.nome]
		var ind: Node3D = indicadores[a.nome]
		for i in lista.size():
			var off: Vector3 = Vector3.ZERO if i == 0 else Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * float(a.distancia)
			lista[i].global_position = Vector3(base.x, 0, base.z) + off
			ind.get_child(i * 2).global_position = lista[i].global_position + Vector3(0, 0.03, 0)
			ind.get_child(i * 2 + 1).global_position = lista[i].global_position + Vector3(0, 0.03, 0)
	indicadores[a.nome].visible = true
	vornak.tocar(a.clipe, true)
	vornak.velocidade_anim(vel_aviso)
	_mudar("aviso")


## Instante do quadro de impacto dentro do clipe original (12 fps, quadro 1 = 0 s).
func t_impacto_clipe(a: Dictionary) -> float:
	return (float(a.quadro) - 1.0) / FPS_CLIPE


## Parte do clipe que não cabe na recuperação da folha (cortada), em segundos do clipe.
func clipe_cortado(a: Dictionary) -> float:
	var resto: float = vornak.duracao(a.clipe) - t_impacto_clipe(a) - float(a.segura) / FPS_CLIPE
	return maxf(0.0, resto - float(a.recupera) * VEL_RECUPERA_MAX)


func _conferir_acerto() -> void:
	if ja_acertou:
		return
	for ar in areas[ataque.nome]:
		for b in ar.get_overlapping_bodies():
			if b != heroi:
				continue
			if ataque.forma == "setor":
				var frente := vornak.global_transform.basis.z
				var d := heroi.global_position - vornak.global_position
				d.y = 0
				if d.length() > 0.01 and rad_to_deg(frente.angle_to(d.normalized())) > float(ataque.angulo) * 0.5:
					continue
			ja_acertou = true
			var dano := float(ataque.dano)
			vida_heroi = maxf(0.0, vida_heroi - dano)
			heroi_atingido.emit(dano)
			if ataque.has("cura") and curado < CURA_MAX:
				var c := minf(float(ataque.cura), CURA_MAX - curado)
				curado += c
				vida = minf(VIDA_CHEFE, vida + c)
			if vida_heroi <= 0.0 and not heroi_morto:
				_heroi_caiu()
			return


## O herói de teste caiu: o chefe para de atacar e fica parado (fim da luta).
func _heroi_caiu() -> void:
	heroi_morto = true
	_cancelar_ataque()
	vornak.tocar("idle", false, 0.3)
	_mudar("vitoria")
	ativo = false
	heroi_caiu.emit()


# ---------------- dano no chefe ----------------
func heroi_bate() -> bool:
	if estado == "morto" or heroi_morto:
		return false
	var d := heroi.global_position - vornak.global_position
	d.y = 0
	if d.length() > ALCANCE_HEROI:
		return false
	receber_dano(DANO_HEROI)
	return true


func receber_dano(v: float) -> void:
	if estado == "morto" or estado == "transicao":
		return
	vida = maxf(0.0, vida - v)
	chefe_atingido.emit(v)
	dano_janela.append([relogio, v])
	while not dano_janela.is_empty() and relogio - float(dano_janela[0][0]) > STAGGER_JANELA:
		dano_janela.pop_front()
	if vida <= 0.0:
		_morrer()
		return
	if fase == 1 and vida <= VIDA_CHEFE * FASE2:
		_cancelar_ataque()
		t_transicao = vornak.duracao("phase_transition") + vornak.duracao("grito")
		vornak.mult_energia = 1.6
		_mudar("transicao")
		return
	var soma := 0.0
	for e in dano_janela:
		soma += float(e[1])
	if soma >= STAGGER_DANO and estado in ["andar", "aviso", "recupera"]:
		dano_janela.clear()
		_cancelar_ataque()
		vornak.tocar("stagger", true)
		_mudar("stagger")
		return
	if estado == "andar":
		t_hit = vornak.duracao("hit")


func _cancelar_ataque() -> void:
	if ataque.is_empty():
		return
	indicadores[ataque.nome].visible = false
	for ar in areas[ataque.nome]:
		ar.monitoring = false


func _morrer() -> void:
	_cancelar_ataque()
	vornak.tocar("death", true)
	_mudar("morto")
	ativo = false


## Pulso dos indicadores visíveis: o traço oscila entre 45% e 95% de opacidade, o fundo entre 10% e 22%.
func _pulsar_indicadores() -> void:
	var p := 0.5 + 0.5 * sin(relogio * TAU * 2.5)
	for k in indicadores:
		var ind: Node3D = indicadores[k]
		if not ind.visible:
			continue
		for mi in ind.get_children():
			var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
			m.albedo_color.a = (0.10 + 0.12 * p) if m.has_meta("fundo") else (0.45 + 0.5 * p)

extends SceneTree
## Teste do protótipo 3D do Vornak (cena_3d/vornak_3d.tscn).
## Roda: godot --headless --fixed-fps 60 --path v3/godot -s res://testes/vornak_3d_teste.gd  (imprime "vornak_3d falhas=0")
## Instancia a cena, roda 3 s de combate simulado (60 quadros por segundo) e confere: glb carrega, 13 animações,
## andar -> aviso -> impacto, vida cai no dano (herói e chefe), fase 2 abaixo de 40% e morte para o combate.

const CENA := "res://cena_3d/vornak_3d.tscn"
const GLB := "res://assets/3d/vornak.glb"
const ANIMS := ["Idle", "Walk", "Run", "Attack_01", "Attack_02", "Attack_03", "Attack_04_Segunda_Forma",
	"Hit", "Stagger", "Ability", "Phase_Transition", "Death", "Grito"]

var falhas := 0
var quadro := 0
var etapa := 0
var cena: Node
var mundo: Node3D
var vornak: Node3D
var heroi: CharacterBody3D
var vida_heroi_antes := 0.0
var marca := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)
	else:
		print("ok: ", msg)


func _initialize() -> void:
	var glb := load(GLB) as PackedScene
	ok(glb != null, "glb carrega (%s)" % GLB)
	var ps := load(CENA) as PackedScene
	ok(ps != null, "cena carrega")
	if ps == null:
		_fim()
		return
	cena = ps.instantiate()
	root.add_child(cena)
	mundo = cena.get_node("Tela/Viewport/Mundo")
	vornak = mundo.get_node("Vornak")
	heroi = mundo.get_node("Heroi")
	heroi.controle_ligado = false
	# herói parado dentro do círculo das raízes (3 m), fora do alcance do golpe e da absorção
	heroi.position = Vector3(1.4, 0, 2.2)
	vida_heroi_antes = mundo.vida_heroi


func _process(_dt: float) -> bool:
	if cena == null:
		return true
	quadro += 1
	if quadro == 2:
		var lista: PackedStringArray = vornak.nomes_animacoes()
		var faltam := []
		for a in ANIMS:
			if not lista.has(a):
				faltam.append(a)
		ok(vornak.animador != null, "AnimationPlayer encontrado")
		ok(faltam.is_empty() and lista.size() == 13, "AnimationPlayer com as 13 animações (tem %d, faltam %s)" % [lista.size(), faltam])
		ok(mundo.estado == "andar", "começa andando")
	if quadro == 180:  # 3 s de combate simulado
		var h: Array = mundo.historico
		var i_av := h.find("aviso")
		var i_im := h.find("impacto")
		ok(h[0] == "andar" and i_av > 0 and i_im > i_av, "estado andar -> aviso -> impacto (%s)" % [h])
		ok(mundo.ataque.get("nome", "") == "raizes", "primeiro ataque são as raízes (círculo de 3 m)")
		ok(mundo.vida_heroi < vida_heroi_antes, "vida do herói cai no impacto (%d -> %d)" % [vida_heroi_antes, mundo.vida_heroi])
		ok(is_equal_approx(vida_heroi_antes - mundo.vida_heroi, mundo.DANO_GOLPE_CHEFE), "dano uma vez por golpe (%d)" % mundo.DANO_GOLPE_CHEFE)
		ok(not mundo.indicadores["raizes"].visible, "indicador some depois do aviso")
		var vida_antes: float = mundo.vida
		heroi.global_position = vornak.global_position + Vector3(0.8, 0, 0.8)
		ok(heroi.bater(), "herói acerta o chefe de perto")
		ok(mundo.vida < vida_antes, "vida do chefe cai no dano (%d -> %d)" % [vida_antes, mundo.vida])
		ok(mundo.fase == 1, "ainda na fase 1")
		mundo.vida = mundo.VIDA_CHEFE * 0.41
		mundo.receber_dano(mundo.DANO_HEROI)
		ok(mundo.estado == "transicao", "abaixo de 40%% entra na transição (vida %d)" % mundo.vida)
		marca = quadro
	if marca > 0 and quadro == marca + int(60.0 * (mundo.t_transicao + 0.2)):
		ok(mundo.fase == 2, "fase 2 aberta depois da transição")
		mundo.receber_dano(mundo.vida + 10.0)
		ok(mundo.estado == "morto" and not mundo.ativo, "morte para o combate")
		ok(vornak.animacao_atual() == "Death", "toca Death")
		marca = -quadro
	if marca < 0 and quadro == -marca + 60:
		ok(mundo.estado == "morto" and mundo.historico[-1] == "morto", "1 s depois continua morto, sem novos estados")
		var algum_ligado := false
		for k in mundo.areas:
			for ar in mundo.areas[k]:
				algum_ligado = algum_ligado or ar.monitoring
		ok(not algum_ligado, "nenhuma área de dano ligada depois da morte")
		_fim()
	if quadro > 2000:
		ok(false, "tempo esgotado")
		_fim()
	return false


func _fim() -> void:
	print("vornak_3d falhas=", falhas)
	quit(1 if falhas > 0 else 0)

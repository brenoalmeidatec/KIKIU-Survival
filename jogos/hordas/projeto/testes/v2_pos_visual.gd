extends "res://testes/isolamento_v2.gd"
# Passe de pixel (pos_visual.gd) na apresentação da v2: só o perfil Alto desenha; Baixo, Médio e Personalizado ficam com o
# retângulo oculto e sem material (sem custo de screen texture). Troca de perfil em tempo de execução liga e desliga o passe.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pos_visual.tscn  (imprime "v2_pos_visual falhas=0")
const Apresentacao := preload("res://v2/apresentacao.gd")
const OPCOES_TESTE := "user://testes_v2/v2_pos_visual/teste_v2_pos_visual_opcoes.cfg"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Config.arquivo = OPCOES_TESTE
	Config.g_aplicar_perfil("alto")
	var ap := Apresentacao.new()
	add_child(ap)
	var sv: SubViewport = ap.montar(get_window())
	await get_tree().process_frame
	var pv: CanvasLayer = ap.pos_visual
	ok(pv != null and pv.get_parent() == sv, "passe montado dentro do SubViewport do mundo")
	ok(pv.layer == 3, "passe na camada 3 (antes da vinheta e da UI)")
	var ret: ColorRect = pv.get_node("QuantizacaoMundo")
	_confere(ret, true, "alto")
	for nome in ["baixo", "medio", "alto", "medio", "baixo"]:
		Config.g_aplicar_perfil(nome)
		_confere(ret, nome == "alto", nome)
	Config.g_aplicar_perfil("alto")
	_confere(ret, true, "alto de novo")
	ap.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OPCOES_TESTE))
	print("v2_pos_visual falhas=", falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _confere(ret: ColorRect, ligado: bool, nome: String) -> void:
	ok(ret.visible == ligado, "%s: visível == %s" % [nome, ligado])
	ok((ret.material != null) == ligado, "%s: material presente == %s" % [nome, ligado])
	if ligado:
		ok(ret.material is ShaderMaterial and ret.material.shader != null, "%s: ShaderMaterial com shader" % nome)

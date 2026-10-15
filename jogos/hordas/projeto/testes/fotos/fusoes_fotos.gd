extends Node
## Prints da arte das fusões (PR #289 do Codex, integrado pelo Claude do Alisson). Não roda no CI (fica em testes/fotos/).
## Grava em 960x540, com janela oculta: o SUA BUILD com a Ventania, a onda dela em ação, o cartão FUSÃO e as lâminas com
## halo da fusão Anel de Brasas.
## Uso: godot --path jogos/hordas/projeto res://testes/fotos/fusoes_fotos.tscn -- --fotos=PASTA --prefixo=antes
## "antes" é a build sem a arte; "depois", com ela. Imprime "FOTO <caminho>" a cada print.

const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const PASSO := 1.0 / 60.0

var w
var pasta := "user://fusoes_fotos"
var prefixo := "depois"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--prefixo="):
			prefixo = a.trim_prefix("--prefixo=")
	DirAccess.make_dir_recursive_absolute(pasta)
	Herois.forcado = "hazaki"
	w = Mundo.instantiate()
	w.modo_teste = false
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	await _quadros(3)
	_zerar()
	for i in 2:
		_pegar("onda")
		_pegar("fura")
	print("ventania ativa: %s" % str(not w.combate.armas.ventania.is_empty()))
	await get_tree().create_timer(2.6).timeout  # o cartão FUSÃO anda em tempo real (tween): espera 2,6 s reais para sumir
	_anel(10, 34.0)
	passos(2)
	var h = w.heroi
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	h.atacar()
	ate(func(): return h.golpe_acertou, 80)
	passos(3)
	await _foto_viewport("ventania_onda_a")
	passos(5)
	await _foto_viewport("ventania_onda_b")
	passos(8)
	await _foto_viewport("ventania_onda_c")
	w.status.alternar()
	await _quadros(6)
	await _foto_janela("sua_build_ventania")
	w.status.alternar()
	_zerar()
	for i in 3:
		_pegar("aura_fogo")
		_pegar("laminas")
	passos(20)
	await get_tree().create_timer(0.35).timeout  # a entrada do cartão (0,22 s reais) termina antes do print
	await _foto_viewport("fusao_cartao")
	await get_tree().create_timer(2.6).timeout  # o cartão some sozinho; as lâminas com halo ficam
	passos(10)
	await _foto_viewport("fusao_lamina_halo")
	print("fotos: fim")
	get_tree().quit()


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func ate(cond: Callable, max_passos: int) -> int:
	for i in max_passos:
		if cond.call():
			return i
		w.avancar(PASSO)
	return -1 if not cond.call() else max_passos


func _zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.m_critico = -1.0
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	passos(3)


func _pegar(id: String, rar := 0) -> Dictionary:
	var cs = w.combate.cartas
	var c: Dictionary = cs.montar_carta(cs.definicao(id), rar)
	cs.aplicar(c)
	return c


func _anel(n: int, raio: float) -> void:
	var tipos := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_espantalho", "inimigo_lobo_sombrio"]
	for a in n:
		var ang := TAU * a / float(n)
		var m = w.nascer_monstro(tipos[a % 4], w.heroi.pos + Vector2(cos(ang) * raio, sin(ang) * raio * 0.8))
		m.atordoa_t = 0.0


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto_viewport(nome: String) -> void:
	var caminho := pasta.path_join("%s_%s.png" % [prefixo, nome])
	var tam = await w.ap.foto(caminho)
	print("FOTO %s %s" % [caminho, tam])


func _foto_janela(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var caminho := pasta.path_join("%s_%s.png" % [prefixo, nome])
	get_viewport().get_texture().get_image().save_png(caminho)
	print("FOTO %s" % caminho)

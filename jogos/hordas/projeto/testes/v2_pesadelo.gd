extends Node
# Teste automático dos dois itens que voltaram ao Santuário (#213): o modo Pesadelo e o visual Rastro de katana.
# Pesadelo: só liga com a conquista cumprida; monstros nascem com +50% de vida e +25% de dano; o diretor sobe a taxa, o teto de vivos e o
# tamanho das ondas; o mini-chefe chega mais cedo; o fim da partida credita +50% de almas; o HUD mostra PESADELO e o resultado também.
# Rastro de katana: ligado, o corte usa a folha ciano do Blender (fx.variante) e o dano do golpe não muda; desligado, volta à folha normal.
# Usa um save TEMPORÁRIO (user://teste_v2_pesadelo.cfg); o save real não é tocado.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pesadelo.tscn  (imprime "v2_pesadelo falhas=0")
const Meta := preload("res://v2/meta.gd")
const Mundo := preload("res://v2/mundo.tscn")
const Resultado := preload("res://v2/resultado_meta.gd")
const SAVE_TESTE := "user://teste_v2_pesadelo.cfg"

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	await _testes()
	_apagar_save()
	print("v2_pesadelo falhas=%d" % falhas)
	get_tree().quit()


func _apagar_save() -> void:
	for sufixo in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE_TESTE + sufixo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TESTE + sufixo))


func _testes() -> void:
	_apagar_save()
	var regras := Meta.regras_pesadelo()
	ok(
		not regras.has("_ajuda") and float(regras.vida_mult) > 1.0 and float(regras.dano_mult) > 1.0,
		"as regras do Pesadelo vêm dos dados (mais vida e mais dano)"
	)
	ok(
		float(regras.densidade_mult) > 1.0 and float(regras.chefe_tempo_mult) < 1.0 and float(regras.almas_mult) > 1.0,
		"mais densidade, chefe mais cedo e mais almas"
	)
	var texto := Meta.texto_item(Meta.item_extra("modo", "pesadelo"))
	ok(not texto.contains("{") and texto.contains("+50%") and texto.contains("+25%"), "o texto do modo mostra os números dos dados (%s)" % texto)

	# 1. sem a conquista o modo e o visual não ligam, mesmo pedindo; o mundo joga normal
	ok(not Meta.ligar("modo", "pesadelo", true) and not Meta.ligado("modo", "pesadelo"), "sem a conquista o Pesadelo não liga")
	var m = Mundo.instantiate()
	m.modo_teste = true
	add_child(m)
	m.set_process(false)
	m.combate.diretor.ligado = false
	ok(not m.pesadelo() and is_equal_approx(m.fator_pesadelo("vida_mult"), 1.0), "sem o modo o mundo não tem fator de Pesadelo")
	ok(m.combate.fx.variante == "katana", "sem o visual o corte usa a folha normal")
	var cao := "inimigo_cao_ossos"
	var base: Dictionary = m.combate.cfg.monstros[cao]
	var normal = m.nascer_monstro(cao, m.heroi.pos + Vector2(200, 0), true)
	ok(is_equal_approx(normal.vida_max, float(base.vida)) and is_equal_approx(normal.dano, float(base.dano)), "monstro normal: vida e dano dos dados")
	var t_normal := 0.0
	var taxa_normal: float = m.combate.diretor.taxa(t_normal)
	var cap_normal: int = m.combate.diretor.limite(200.0)
	var teto_normal: int = m.combate.diretor.teto()

	# 2. conquistas cumpridas: liga os dois e o mundo muda
	Meta.registrar_partida({"tempo": 10.0, "maior_combo": 50, "venceu": true, "almas": 0})
	ok(Meta.liberado("modo", "pesadelo") and Meta.liberado("visual", "rastro_katana"), "as conquistas liberam os dois")
	ok(Meta.ligar("modo", "pesadelo", true) and Meta.ligar("visual", "rastro_katana", true), "com a conquista liga e grava")
	Meta.aplicar(m)
	ok(m.pesadelo(), "ligado, o mundo está no Pesadelo")
	var duro = m.nascer_monstro(cao, m.heroi.pos + Vector2(-200, 0), true)
	ok(is_equal_approx(duro.vida_max, float(base.vida) * float(regras.vida_mult)), "Pesadelo: vida x%s (%s)" % [regras.vida_mult, duro.vida_max])
	ok(is_equal_approx(duro.dano, float(base.dano) * float(regras.dano_mult)), "Pesadelo: dano x%s (%s)" % [regras.dano_mult, duro.dano])
	var d = m.combate.diretor
	ok(d.taxa(t_normal) > taxa_normal * 1.25, "Pesadelo: a taxa de nascimento sobe (%.2f x %.2f)" % [d.taxa(t_normal), taxa_normal])
	ok(
		d.limite(200.0) > cap_normal and d.teto() > teto_normal,
		"Pesadelo: mais monstros vivos de uma vez (%d/%d x %d/%d)" % [d.limite(200.0), d.teto(), cap_normal, teto_normal]
	)
	var antes_vivos: int = m.monstros.size()
	d.ligado = false
	d.zerar()
	d.onda_forte()
	var n_duro: int = m.monstros.size() - antes_vivos
	m.reiniciar()
	m.combate.diretor.ligado = false
	ok(m.pesadelo(), "reiniciar mantém o Pesadelo")
	Meta.ligar("modo", "pesadelo", false)
	Meta.aplicar(m)
	m.combate.diretor.zerar()
	var antes_n: int = m.monstros.size()
	m.combate.diretor.onda_forte()
	var n_normal: int = m.monstros.size() - antes_n
	ok(n_duro > n_normal, "Pesadelo: a onda forte vem maior (%d x %d)" % [n_duro, n_normal])
	Meta.ligar("modo", "pesadelo", true)
	Meta.aplicar(m)

	# 3. o mini-chefe chega mais cedo: os níveis do mapa ficam mais curtos (chefe_tempo_mult)
	var chefes = m.combate.chefes
	var dir = m.combate.diretor
	var mk: Dictionary = dir.chefes_mapa[0].mk
	var n_mini: int = dir.chefes_mapa[0].nivel
	var t_normal: float = dir.duracao_nivel * float(n_mini - 1)
	var t_mini: float = dir.seg_nivel() * float(n_mini - 1) + 0.5
	ok(t_mini < t_normal, "o tempo do Pesadelo cai antes do tempo normal do mini-chefe (%d x %d)" % [t_mini, t_normal])
	m.combate.limpar_partida()
	dir.avancar_nivel(t_mini)
	chefes.atualizar(0.0)
	ok(chefes.atual != null and chefes.feitos.has(mk.id), "Pesadelo: o mini-chefe aparece antes do tempo normal")
	ok(chefes.atual.vida_max >= float(mk.vida) * float(regras.vida_mult) - 0.01, "o mini-chefe também ganha a vida do Pesadelo (%s)" % chefes.atual.vida_max)
	m.combate.limpar_partida()
	Meta.ligar("modo", "pesadelo", false)
	Meta.aplicar(m)
	dir.avancar_nivel(t_mini)
	chefes.atualizar(0.0)
	ok(chefes.atual == null, "sem o Pesadelo nesse instante ainda não há mini-chefe")
	Meta.ligar("modo", "pesadelo", true)
	Meta.aplicar(m)

	# 4. HUD e resultado mostram PESADELO
	var hud = m.get_node_or_null("%Hud")
	for no in m.find_children("*", "CanvasLayer", true, false):
		if no.has_method("avancar") and no.get("_selo_pesadelo") != null:
			hud = no
	ok(hud != null, "o HUD está na partida")
	if hud != null:
		hud.avancar(0.016)
		ok(hud._selo_pesadelo.visible and hud._selo_pesadelo.text == "PESADELO", "o HUD mostra PESADELO")
	var res = Resultado.new()
	res.montar(m)
	res._terminar({"tempo": 30.0, "abates": 3, "nivel": 2, "maior_combo": 3, "venceu": false, "almas": 100})
	ok(res._titulo.text.contains("PESADELO"), "o resultado mostra PESADELO (%s)" % res._titulo.text)
	ok(res._ganhas == roundi(100.0 * float(regras.almas_mult)), "o Pesadelo rende x%s de almas: 100 viram %d" % [regras.almas_mult, res._ganhas])
	ok(bool(Meta.estado().ultima.get("pesadelo", false)), "a última partida guarda que foi no Pesadelo")
	res._terminou = true
	var r2 := Meta.registrar_partida({"tempo": 30.0, "almas": 100})
	ok(int(r2.ganhas) == 100, "sem o Pesadelo as almas não mudam (100)")
	Meta.ligar("modo", "pesadelo", false)
	Meta.aplicar(m)
	ok(not m.pesadelo(), "desligado, o mundo volta ao normal")
	if hud != null:
		hud.avancar(0.016)
		ok(not hud._selo_pesadelo.visible, "desligado, o HUD esconde PESADELO")

	# 5. Rastro de katana: a folha ciano no corte e o dano igual
	Meta.aplicar(m)
	ok(m.combate.fx.variante == "ciano", "Rastro de katana ligado: o corte usa a folha ciano")
	var cortes: int = m.combate.fx.usados.cortes
	m.combate.fx.corte(m.heroi.pos, 0.0, 46.0, 125.0, 1.0, "corte", Color.WHITE, 0.2)
	ok(m.combate.fx.usados.cortes == cortes + 1, "o corte ciano é desenhado")
	var mat := m.combate.fx._cortes[(m.combate.fx._ci + m.combate.fx._cortes.size() - 1) % m.combate.fx._cortes.size()].material as ShaderMaterial
	ok(mat.get_shader_parameter("fixo") == 1.0, "o corte usa a rampa ciano da folha do Blender")
	var dano_passo: float = float(m.combate.cfg.golpe.passos[0].dano)
	ok(is_equal_approx(m.heroi.m_dano, 1.0) and dano_passo == 12.0, "o visual não mexe no dano (m_dano %s, passo %s)" % [m.heroi.m_dano, dano_passo])
	Meta.ligar("visual", "rastro_katana", false)
	Meta.aplicar(m)
	ok(m.combate.fx.variante == "katana", "desligado, o corte volta à folha normal")
	m.queue_free()
	await get_tree().process_frame

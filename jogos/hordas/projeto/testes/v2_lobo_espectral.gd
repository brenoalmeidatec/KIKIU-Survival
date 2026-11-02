extends "res://testes/isolamento_v2.gd"
# Teste do LOBO ESPECTRAL e do clarão da troca (lore do Isac, #511; v2/lobo_espectral.gd). Confere: os números em dados (com _ajuda); na forma Lobo o visual espectral
# está ativo (alfa ~0,75, tinta gelo, sprite aditivo com shader) e na forma mecha está desligado; o clarão dispara UMA vez por troca; com "Tremor e clarões" em 0 ou
# "Reduzir piscadas" não há flash de tela (sobra a silhueta no herói); no perfil Baixo não há shader nem névoa (só alfa e cor); a contagem de nós não cresce
# depois de 10 trocas; o mecha não muda.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_lobo_espectral.tscn  (imprime "v2_lobo_espectral falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Anim := preload("res://v2/anim_golpes.gd")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const SAVE_TESTE := "user://testes_v2/v2_lobo_espectral/teste.cfg"
const INDICE_TESTE := "user://testes_v2/v2_lobo_espectral/teste_indice.cfg"
const PREFIXO_TESTE := "user://testes_v2/v2_lobo_espectral/teste_p"
const ANTIGO_TESTE := "user://testes_v2/v2_lobo_espectral/teste_antigo.cfg"
const PASSO := 1.0 / 60.0

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _apagar_save() -> void:
	var alvos := [SAVE_TESTE, INDICE_TESTE]
	for i in range(1, 6):
		alvos.append(Personagens.caminho_do_save("p%d" % i))
		alvos.append(Personagens.caminho_do_save("p%d" % i) + ".bak")
	for c in alvos:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))


func novo(id: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = false
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	passos(3)


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	Personagens.caminho_indice = INDICE_TESTE
	Personagens.caminho_base = PREFIXO_TESTE
	Personagens.caminho_antigo = ANTIGO_TESTE
	_apagar_save()
	Config.g_perfil_temporario("alto")
	Config.g_temporario("tremor_clarao", 100)
	Config.temporario("reduzir_piscadas", false)
	Anim.suave = true
	await _testes()
	_apagar_save()
	Herois.forcado = ""
	print("v2_lobo_espectral falhas=%d" % falhas)
	get_tree().quit()


func _testes() -> void:
	_t_dados()
	await _t_formas()
	await _t_clarao()
	await _t_baixo()
	await _t_nos()
	await _t_outros_herois()


func quebrar() -> void:
	var h = w.heroi
	h.invenc = 0.0
	h.vida = 10.0
	ok(h.levar_dano(999.0, h.pos + Vector2(20, 0)), "o golpe fatal é consumido")


func _tela_acesa() -> bool:
	var fx = w.combate.fx
	return fx._cl_t < fx._cl_dur and fx._cl_cor.a > 0.0


func _apagar_tela() -> void:
	w.combate.fx._cl_t = 9.0


func _t_dados() -> void:
	var e: Dictionary = Herois.heroi("lightwolf_lobo").get("espectral", {})
	ok(not e.is_empty() and str(e.get("_ajuda", "")).length() > 40, "dados: lightwolf_lobo > espectral existe e tem _ajuda")
	for k in ["alfa", "cor_corpo", "cor_brilho", "brilho", "contorno", "pulso_hz", "pulso_amp", "cintila", "cintila_vel", "nevoa", "clarao"]:
		ok(e.has(k), "dados: espectral > %s" % k)
	ok(absf(float(e.get("alfa", 0.0)) - 0.75) < 0.01, "dados: alfa por volta de 0,75")
	var c: Dictionary = e.get("clarao", {})
	ok(str(c.get("_ajuda", "")).length() > 40, "dados: clarao tem _ajuda")
	ok(float(c.get("heroi_dur", 0.0)) >= 0.3 and float(c.get("heroi_dur", 9.0)) <= 0.5, "dados: o clarão do herói dura de 0,3 a 0,5 s")
	ok(not Herois.heroi("lightwolf").has("espectral"), "dados: o mecha não tem bloco espectral")


func _t_formas() -> void:
	await novo("lightwolf")
	var h = w.heroi
	w.args["particulas"] = "muitas"
	ok(h.espectral != null and not h.espectral.ativo, "mecha: o visual espectral existe mas está desligado")
	ok(not h.espectral.no.visible and h.sprite.modulate == Color.WHITE, "mecha: sem brilho, sprite branco puro (o mecha não muda)")
	quebrar()
	ok(h.forma_lobo and h.espectral.ativo, "Lobo: visual espectral ativo")
	h.invenc = 0.0
	passos(30)
	var m: Color = h.sprite.modulate
	ok(absf(m.a - 0.75) < 0.01, "Lobo: corpo meio translúcido, alfa ~0,75 (%.2f)" % m.a)
	ok(m.b > m.r and m.b > 0.9, "Lobo: tinta gelo, azul acima do vermelho (%s)" % str(m))
	ok(h.espectral.no.visible and h.espectral.no.material is ShaderMaterial, "Lobo: sprite aditivo com shader aparece")
	ok(h.espectral.no.region_rect == h.sprite.region_rect and h.espectral.no.texture == h.tipo.alb, "Lobo: o brilho copia o recorte e a folha do corpo")
	ok(h.sprite.material == null, "Lobo: o corpo não troca de material (o shader é do sprite irmão)")
	h.entrada_forcada = Vector2(-1, 0)
	passos(20)
	ok(h.espectral.no.flip_h == h.sprite.flip_h and h.espectral.no.position == h.sprite.position, "Lobo: espelho e posição do brilho seguem o corpo")
	var e = h.espectral
	ok(e._heroi() == h and e.get("heroi") == null, "Lobo: o visual guarda o herói por referência fraca (sem ciclo Heroi <-> espectral)")
	ok(is_equal_approx(float(e._mat.get_shader_parameter("forca")), 1.0), "Lobo: brilho cheio fora da invencibilidade")
	h.invenc = 1.0
	passos(2)
	ok(is_equal_approx(float(e._mat.get_shader_parameter("forca")), 0.35), "Lobo invencível: o brilho cai e o vermelho da invencibilidade manda")
	h.invenc = 0.0
	passos(2)
	ok(is_equal_approx(float(e._mat.get_shader_parameter("forca")), 1.0), "Lobo: o brilho volta ao fim da invencibilidade")
	h.entrada_forcada = Vector2.ZERO
	w.combate.mecha.chegar(h)
	passos(3)
	ok(not h.forma_lobo and not h.espectral.ativo and not h.espectral.no.visible, "volta ao mecha: visual espectral desligado")
	ok(h.sprite.modulate == Color.WHITE, "volta ao mecha: sprite branco de novo (%s)" % str(h.sprite.modulate))
	quebrar()
	ok(h.espectral.ativo, "Lobo de novo: ativo")
	w.combate.mecha.reiniciar(h)
	ok(not h.espectral.ativo, "recomeço: desligado")
	await novo("lightwolf")
	h = w.heroi
	quebrar()
	h.invenc = 0.0
	h.vida = 1.0
	h.levar_dano(99.0, h.pos + Vector2(10, 0))
	passos(3)
	ok(h.estado == Heroi.Estado.MORTO and not h.espectral.ativo and not h.espectral.no.visible, "morte do Lobo: o brilho some junto")


func _t_clarao() -> void:
	await novo("lightwolf")
	var h = w.heroi
	var e = h.espectral
	var fx = w.combate.fx
	w.args["particulas"] = "muitas"
	Config.g_temporario("tremor_clarao", 100)
	Config.temporario("reduzir_piscadas", false)
	_apagar_tela()
	var fl0: int = fx.usados.flashes
	e.clarao(true)  # sozinho: no quebrar() o golpe também faz flash no herói e esconderia a falta da silhueta
	ok(fx.usados.flashes > fl0, "clarão: silhueta branco-ciano no herói")
	passos(120)
	_apagar_tela()
	var n0: int = e.claroes
	quebrar()
	ok(e.claroes == n0 + 1, "clarão: dispara uma vez ao quebrar (%d)" % (e.claroes - n0))
	ok(_tela_acesa(), "clarão: flash de tela acende com 'Tremor e clarões' em 100%")
	passos(120)
	ok(e.claroes == n0 + 1, "clarão: não repete sozinho com o tempo (%d)" % (e.claroes - n0))
	ok(not _tela_acesa(), "clarão: o flash de tela acaba")
	_apagar_tela()
	w.combate.mecha.chegar(h)
	ok(e.claroes == n0 + 2, "clarão: um por troca, também na volta ao mecha (%d)" % (e.claroes - n0))
	ok(_tela_acesa(), "clarão da volta: flash de tela (mais fraco)")
	passos(120)
	Config.g_temporario("tremor_clarao", 0)
	_apagar_tela()
	quebrar()
	ok(not _tela_acesa(), "'Tremor e clarões' em 0: sem flash de tela")
	ok(e.claroes == n0 + 3, "'Tremor e clarões' em 0: o clarão do herói ainda conta uma vez")
	fl0 = fx.usados.flashes
	e.clarao(true)
	ok(fx.usados.flashes > fl0, "'Tremor e clarões' em 0: sobra a silhueta no herói")
	Config.g_temporario("tremor_clarao", 100)
	Config.temporario("reduzir_piscadas", true)
	w.combate.mecha.chegar(h)
	passos(120)
	_apagar_tela()
	quebrar()
	ok(not _tela_acesa(), "Reduzir piscadas: sem flash de tela")
	passos(3)
	ok(e.reduz, "Reduzir piscadas: o visual sabe (brilho parado)")
	Config.temporario("reduzir_piscadas", false)


func _t_baixo() -> void:
	await novo("lightwolf")
	var h = w.heroi
	var e = h.espectral
	var fx = w.combate.fx
	w.args["particulas"] = "muitas"
	quebrar()
	h.invenc = 0.0
	passos(3)
	var p0: int = fx.usados.particulas
	passos(90)
	var alto: int = fx.usados.particulas - p0
	ok(alto > 0, "alto: a névoa solta partículas (%d em 1,5 s)" % alto)
	ok(e.no.visible and e.no.material != null, "alto: shader ligado")
	w.args["particulas"] = "poucas"
	passos(40)
	ok(w.combate._perfil_baixo(), "o perfil Baixo está valendo")
	ok(e.baixo and not e.no.visible and e.no.material == null, "Baixo: sem shader (sprite aditivo escondido e sem material)")
	p0 = fx.usados.particulas
	passos(90)
	ok(fx.usados.particulas == p0, "Baixo: sem névoa (%d partículas)" % (fx.usados.particulas - p0))
	var m: Color = h.sprite.modulate
	ok(absf(m.a - 0.75) < 0.01 and m.b > m.r, "Baixo: só a translucidez e a cor (%s)" % str(m))
	ok(h.sprite.material == null, "Baixo: o corpo sem material")
	w.args["particulas"] = "muitas"


func _contar() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _t_nos() -> void:
	await novo("lightwolf")
	var h = w.heroi
	w.args["particulas"] = "muitas"
	Config.g_temporario("tremor_clarao", 100)
	quebrar()
	passos(30)
	w.combate.mecha.chegar(h)
	passos(30)
	var antes := _contar()
	for i in 10:
		quebrar()
		passos(40)
		w.combate.mecha.chegar(h)
		passos(40)
	var depois := _contar()
	ok(depois == antes, "10 trocas não criam nó (%d -> %d)" % [antes, depois])
	ok(h.espectral.no.get_parent() == h.raiz, "um só sprite espectral, filho da raiz do herói")


func _t_outros_herois() -> void:
	await novo("hazaki")
	ok(w.heroi.espectral == null, "outro herói (Hazaki): sem visual espectral")

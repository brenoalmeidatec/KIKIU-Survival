extends Node
# Teste da legibilidade do herói no escuro: o contorno claro (shader heroi_contorno) e a luz pessoal existem por perfil (Baixo só contorno,
# Médio e Alto contorno e luz), a luz pessoal não entra nas sombras, o arco do golpe poupa o corpo e a morte continua dissolvendo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_heroi_legivel.tscn  (imprime "v2_heroi_legivel falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
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


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.entrada_forcada = Vector2.ZERO
	var d := Herois.legibilidade()
	ok(not d.is_empty() and d.has("_ajuda") and d.has("perfis"), "dados/v2_herois.json tem o bloco legibilidade com _ajuda")
	ok(float(d.perfis.baixo.luz) == 0.0, "o Baixo não tem luz pessoal nos dados")

	for perfil in ["baixo", "medio", "alto"]:
		Config.g_perfil_temporario(perfil)
		h.aplicar_legibilidade()
		passos(2)
		var m := h.sprite.material as ShaderMaterial
		ok(m != null and m.shader == Heroi.CONTORNO, "%s: o herói vivo usa o shader de contorno" % perfil)
		ok(m != null and (m.get_shader_parameter("cor_contorno") as Color).a > 0.0, "%s: contorno com alfa > 0" % perfil)
		ok(not Heroi.CONTORNO.code.contains("TIME"), "o contorno não usa TIME")
		var lp = h.luz_pessoal
		if perfil == "baixo":
			ok(lp == null or lp.apagada, "baixo: sem luz pessoal (só contorno)")
			if lp != null:
				ok(not lp.luz.enabled, "baixo: a luz pessoal está desligada")
		else:
			ok(lp != null and not lp.apagada, "%s: existe a luz pessoal" % perfil)
			ok(lp != null and lp.alvo == h and lp.sem_sombra, "%s: presa ao herói e fora das sombras" % perfil)
			ok(lp != null and lp.luz.enabled and lp.luz.energy > 0.0 and lp.luz.energy < 1.5, "%s: ligada e suave" % perfil)
			ok(lp != null and lp.raio <= 120.0, "%s: raio curto" % perfil)
			var n_sombra := 0
			for i in w.luzes.dn:
				if lp != null and w.luzes.dpos[i].is_equal_approx(lp.pos):
					n_sombra += 1
			ok(n_sombra == 0, "%s: a luz pessoal não aparece nos vetores das sombras" % perfil)

	# o arco do golpe poupa o corpo
	var fx = w.combate.fx
	fx.corte(h.pos + Heroi.ORIGEM_GOLPE, 0.0, 50.0, 120.0, 1.0, "corte", Color.WHITE, 0.2)
	var s: Sprite2D = fx._cortes[(fx._ci + fx._cortes.size() - 1) % fx._cortes.size()]
	var poupa: Vector3 = (s.material as ShaderMaterial).get_shader_parameter("poupa")
	ok(poupa.x > 0.0 and poupa.z < 1.0, "o corte baixa o brilho perto do corpo (poupa=%s)" % str(poupa))
	ok((s.material as ShaderMaterial).shader.code.contains("poupa"), "o shader do corte lê a poupa")

	# morte e recomeço com o contorno
	Config.g_perfil_temporario("medio")
	h.aplicar_legibilidade()
	var vivo = h.sprite.material
	h.imortal = false
	h.invenc = 0.0
	h.levar_dano(h.vida + 100.0, h.pos + Vector2(10, 0))
	ok(h.estado == Heroi.Estado.MORTO, "morreu")
	h.aplicar_legibilidade()  # com o herói morto o material não pode voltar ao contorno
	var n := 0
	while h.morte_t == 0.0 and n < 1500:
		passos(1)
		n += 1
	ok(h.sprite.material == h._mat_morte and h.sprite.material != vivo, "morto: o material é o da dissolução")
	passos(900)
	ok(h.morte_k() == 1.0, "a dissolução termina (k=%f)" % h.morte_k())
	h.resetar(h.pos)
	ok(h.sprite.material == h._mat_contorno and h.sprite.material != null, "recomeço devolve o contorno")
	ok(h.luz_pessoal != null and not h.luz_pessoal.apagada, "recomeço mantém a luz pessoal no Médio")
	print("v2_heroi_legivel falhas=%d" % falhas)
	get_tree().quit()

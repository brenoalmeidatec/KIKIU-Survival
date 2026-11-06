extends "res://testes/isolamento_v2.gd"
# Teste do reviver() do monstro (v2/monstro.gd) com o status no corpo (v2/status_corpo.gd, shader do fogo, gelo, veneno, choque e sangue).
# Elite e chefe desenham o status trocando o material do sprite. Quando o monstro volta do pool, TODO o estado visual do status precisa
# voltar ao zero: material do sprite, tinta (modulate), estado do shader, marca, fogo e a fonte do dano. Senão a elite que nasce do mesmo
# nó do pool aparece com o fogo ou o gelo da vida anterior. Cobre: elite queimando, elite congelada (lenta), elite com veneno/choque/sangue,
# a volta pelo pool, o renascimento como comum (em lote) e como elite de novo (sem status, o corpo fica limpo), e o perfil Baixo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_status_reviver.tscn  (imprime "v2_status_reviver falhas=0")
const Anim := preload("res://v2/anim_golpes.gd")
const Mundo := preload("res://v2/mundo.tscn")
const StatusCorpo := preload("res://v2/status_corpo.gd")
const PASSO := 1.0 / 60.0
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _quadros(w, n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## O corpo está limpo: sem material de status no sprite, sem tinta e com o shader em estado 0.
func _limpo(m) -> bool:
	if m.sprite == null:
		return true
	var shader_zerado: bool = m._mat_corpo == null or float(m._mat_corpo.get_shader_parameter("estado")) == 0.0
	return m.sprite.material == null and m.sprite.modulate == m.tinta and shader_zerado and m.v_estado == StatusCorpo.NADA


func _rotulo(m) -> String:
	var mat = null if m.sprite == null else m.sprite.material
	var est = null if m._mat_corpo == null else m._mat_corpo.get_shader_parameter("estado")
	var mod = null if m.sprite == null else m.sprite.modulate
	return (
		"material=%s estado_shader=%s modulate=%s v_estado=%d marca_k=%d queima_dps=%.2f fonte='%s'"
		% [mat, est, mod, m.v_estado, m.marca_k, m.queima_dps, m.queima_fonte]
	)


## Põe o status `qual` no monstro (a elite `m`) e roda até o shader tomar o corpo.
func _acender(w, m, qual: String) -> void:
	match qual:
		"fogo":
			m.queimar(0.2, 30.0)
		"gelo":
			m.deixar_lento(30.0)
		"veneno":
			m.marcar(StatusCorpo.VENENO, 30.0)
		"choque":
			m.marcar(StatusCorpo.CHOQUE, 30.0)
		"sangue":
			m.marcar(StatusCorpo.SANGUE, 30.0)
	_quadros(w, 8)


func _ready() -> void:
	Anim.suave = true
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	var c = w.combate
	var p0: Vector2 = w.heroi.pos

	for qual in ["fogo", "gelo", "veneno", "choque", "sangue"]:
		# elite com o status no corpo: o shader tomou o sprite
		var e = c.elites.nascer("", "", p0 + Vector2(90, 0))
		ok(e != null and e.elite and not e.lote, "[%s] a elite nasceu como nó" % qual)
		_acender(w, e, qual)
		ok(e.sprite.material != null and e.v_estado != StatusCorpo.NADA, "[%s] antes de morrer: o status está no corpo (%s)" % [qual, _rotulo(e)])
		# morre com o status, volta ao pool
		c.ferir(e, 99999.0, Vector2.ZERO, 0.0, 0.0, Color.WHITE, false)
		_quadros(w, 8)
		ok(not e.vivo, "[%s] a elite morreu" % qual)
		# volta do pool como comum (lote): todo o estado visual do status foi limpo
		var r = w.nascer_monstro(e.chave, p0 + Vector2(-90, 0))
		ok(r == e, "[%s] o pool devolveu o mesmo nó (reaproveitado)" % qual)
		ok(r.lote and not r.elite, "[%s] renasceu como monstro comum em lote" % qual)
		ok(_limpo(r), "[%s] reviver limpou o status do corpo (%s)" % [qual, _rotulo(r)])
		ok(r.marca_k == 0 and r.queima_dps == 0.0 and r.queima_fonte == "", "[%s] marca, fogo e fonte zerados (%s)" % [qual, _rotulo(r)])
		# vira elite de novo, SEM status: o corpo precisa continuar limpo depois de desenhar
		c.elites.marcar(r, c.elites.cfg.modificadores[0])
		_quadros(w, 8)
		ok(r.elite and not r.lote, "[%s] a mesma peça virou elite de novo" % qual)
		ok(_limpo(r), "[%s] elite nova do pool nasce sem o status antigo (%s)" % [qual, _rotulo(r)])
		r.esconder()
		r.morrendo = false
		w.devolver_monstro(r)

	# perfil Baixo: o status não toma o corpo, e o reviver segue limpo
	Anim.suave = false
	var b = c.elites.nascer("", "", p0 + Vector2(90, 40))
	b.queimar(0.2, 30.0)
	_quadros(w, 8)
	ok(b._estado_corpo() == StatusCorpo.NADA, "perfil Baixo: sem shader de status")
	c.ferir(b, 99999.0, Vector2.ZERO, 0.0, 0.0, Color.WHITE, false)
	_quadros(w, 8)
	var b2 = w.nascer_monstro(b.chave, p0 + Vector2(-90, 40))
	ok(_limpo(b2), "perfil Baixo: reviver limpo (%s)" % _rotulo(b2))
	Anim.suave = true

	w.queue_free()
	await get_tree().process_frame
	print("v2_status_reviver falhas=", falhas)
	get_tree().quit(1 if falhas else 0)

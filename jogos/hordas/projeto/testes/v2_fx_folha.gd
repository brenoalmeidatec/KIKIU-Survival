extends "res://testes/isolamento_v2.gd"
# Teste automático do v2/fx_folha.gd (folhas do pixelfx em pool fixo): registro lido do dados/v2_pixelfx.json, tocar (efeito único que volta
# ao pool sozinho), prender/soltar (loop preso a um nó, alça com geração), limite por id, intervalo, pool que não cresce (nenhum nó novo por
# disparo), perfil Baixo (decorativo some), opção "Tremor e clarões", e a ponta a ponta: pegar um orbe de XP toca o collect-burst no mundo.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_fx_folha.tscn  (imprime "v2_fx_folha falhas=0")
const FxFolha := preload("res://v2/fx_folha.gd")
const Anim := preload("res://v2/anim_golpes.gd")
const Mundo := preload("res://v2/mundo.tscn")
const PASSO := 1.0 / 60.0
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _def(extra := {}) -> Dictionary:
	var d := {"arquivo": "pickups/collect-burst.png", "quadro": [112, 108], "colunas": 7, "quadros": 6, "fps": 10, "pivo": [56, 94]}
	d.merge(extra, true)
	return d


func _nos_total(raiz: Node) -> int:
	var n := 1
	for c in raiz.get_children():
		n += _nos_total(c)
	return n


func _ready() -> void:
	Anim.suave = true
	var camada := Node2D.new()
	add_child(camada)
	var fx := FxFolha.new()
	fx.montar(camada)

	# 1. registro: o collect-burst vem do json; entrada incompleta ou folha que não existe é recusada
	ok(fx.tem("collect-burst"), "o collect-burst está no dados/v2_pixelfx.json")
	ok(not fx.registrar("sem_campos", {"arquivo": "pickups/collect-burst.png"}), "entrada sem quadro/fps/pivô é recusada")
	ok(not fx.registrar("sem_arquivo", _def({"arquivo": "pickups/nao_existe.png"})), "folha que não existe é recusada")
	ok(not fx.tem("sem_campos") and not fx.tem("sem_arquivo"), "recusada não entra no registro")
	ok(fx.registrar("t_unico", _def({"limite": 3, "cor": "#ff0000"})), "registrar em tempo de execução")
	ok(fx.registrar("t_loop", _def({"loop": true, "limite": 2, "decorativo": false, "aditivo": true})), "registrar um loop")
	ok(fx.registrar("t_clarao", _def({"clarao": true})), "registrar um com clarão")
	ok(fx.registrar("t_passo", _def({"quadros": 6, "passo": 2})), "registrar um com passo")
	ok(fx.registrar("t_intervalo", _def({"intervalo": 0.5})), "registrar um com intervalo")
	ok(camada.get_child_count() == 2, "dois nós de desenho na camada (normal e aditivo): %d" % camada.get_child_count())

	# 2. tocar: efeito único volta ao pool sozinho; 6 quadros a 10 fps = 0,6 s
	ok(fx.tocar("t_unico", Vector2(100.4, 50.6)), "tocar devolve true")
	ok(fx.ativos == 1, "um efeito no ar")
	for i in 30:
		fx.atualizar(PASSO)
	ok(fx.ativos == 1, "meio segundo depois ainda está no ar")
	for i in 12:
		fx.atualizar(PASSO)
	ok(fx.ativos == 0, "passou de 0,6 s: voltou ao pool sozinho (%d)" % fx.ativos)
	ok(not fx.tocar("id_que_nao_existe", Vector2.ZERO) and fx.usados.recusados >= 1, "id desconhecido recusa e conta")

	# 3. passo: pula quadros (6 quadros, passo 2 = 3 quadros mostrados = 0,3 s)
	fx.tocar("t_passo", Vector2.ZERO)
	for i in 21:
		fx.atualizar(PASSO)
	ok(fx.ativos == 0, "passo 2 acaba na metade do tempo")

	# 4. limite por id no tocar: troca o mais velho, nunca passa de 3
	for i in 10:
		fx.tocar("t_unico", Vector2(i, 0))
		fx.atualizar(0.01)
	ok(fx.ativos == 3, "limite 3 do id: %d no ar" % fx.ativos)
	fx.limpar()
	ok(fx.ativos == 0, "limpar devolve tudo")

	# 5. intervalo: dois tocar seguidos do mesmo id, o segundo espera
	ok(fx.tocar("t_intervalo", Vector2.ZERO), "primeiro toca")
	ok(not fx.tocar("t_intervalo", Vector2.ZERO), "o segundo logo em seguida é recusado pelo intervalo")
	fx.atualizar(0.6)
	ok(fx.tocar("t_intervalo", Vector2.ZERO), "passado o intervalo toca de novo")
	fx.limpar()

	# 6. prender/soltar: loop preso a um nó, alça, limite e repetição
	var a := Node2D.new()
	var b := Node2D.new()
	var c := Node2D.new()
	for n in [a, b, c]:
		camada.add_child(n)
	a.position = Vector2(40, 40)
	var ha := fx.prender("t_loop", a, Vector2(0, -10))
	ok(ha > 0 and fx.vivo(ha) and fx.ativos == 1, "prender devolve uma alça viva")
	ok(fx.prender("t_loop", a, Vector2(0, -12)) == ha and fx.ativos == 1, "o mesmo id no mesmo alvo devolve a alça que já existe")
	var hb := fx.prender("t_loop", b)
	ok(hb > 0 and hb != ha and fx.ativos == 2, "outro alvo, outra alça")
	ok(fx.prender("t_loop", c) == 0 and fx.ativos == 2, "passou do limite do id: recusa (0)")
	ok(fx.prender("t_loop", null) == 0, "alvo nulo recusa")
	for i in 600:
		fx.atualizar(PASSO)
	ok(fx.ativos == 2 and fx.vivo(ha), "loop de 10 s segue no ar (não acaba sozinho)")
	fx.soltar(ha)
	ok(fx.ativos == 1 and not fx.vivo(ha), "soltar devolve ao pool")
	fx.soltar(ha)
	ok(fx.ativos == 1, "soltar a mesma alça de novo não faz nada")
	var hc := fx.prender("t_loop", c)  # reaproveita o slot que a alça velha tinha
	ok(hc > 0 and hc != ha, "slot reaproveitado ganha outra alça")
	fx.soltar(ha)
	ok(fx.vivo(hc) and fx.ativos == 2, "a alça velha não solta o efeito novo que ocupou o slot")
	fx.soltar(0)
	fx.soltar(-5)
	fx.soltar(99999999)
	ok(fx.ativos == 2, "alças inválidas não fazem nada")
	b.free()  # o dono some sem soltar
	fx.atualizar(PASSO)
	ok(fx.ativos == 1, "alvo liberado sem soltar: o efeito volta ao pool no quadro seguinte")
	fx.limpar()

	# 7. pool fixo: milhares de disparos não criam nó nem passam do MAX
	var antes := _nos_total(camada)
	for i in 3000:
		fx.tocar("t_unico", Vector2(i % 200, 0))
		fx.tocar("collect-burst", Vector2(i % 200, 0))
		fx.prender("t_loop", a)
		fx.atualizar(PASSO)
		if fx.ativos > FxFolha.MAX:
			ok(false, "o pool passou do MAX")
			break
	await get_tree().process_frame  # os nós de desenho rodam o _draw de verdade
	ok(_nos_total(camada) == antes, "nenhum nó novo depois de 3000 disparos (%d -> %d)" % [antes, _nos_total(camada)])
	ok(fx.ativos <= FxFolha.MAX, "ativos dentro do pool (%d de %d)" % [fx.ativos, FxFolha.MAX])
	fx.limpar()

	# 8. perfil Baixo (golpes suaves desligados): decorativo não nasce e some do ar; o que não é decorativo segue
	var h_antes := fx.prender("t_loop", a)
	fx.tocar("t_unico", Vector2.ZERO)
	ok(fx.ativos == 2, "antes do perfil Baixo: um loop e um único")
	Anim.suave = false
	fx.atualizar(PASSO)
	ok(fx.ativos == 1 and fx.vivo(h_antes), "perfil Baixo: o decorativo no ar some, o loop não decorativo fica")
	ok(not fx.tocar("t_unico", Vector2.ZERO), "perfil Baixo: decorativo não nasce")
	ok(not fx.tocar("collect-burst", Vector2.ZERO), "perfil Baixo: o collect-burst é decorativo e não nasce")
	ok(fx.prender("t_loop", c) > 0, "perfil Baixo: efeito não decorativo ainda nasce")
	Anim.suave = true
	fx.limpar()

	# 9. "Tremor e clarões": 0% não acende, 100% acende
	Config.g_temporario("tremor_clarao", 0)
	ok(not fx.tocar("t_clarao", Vector2.ZERO), "clarão em 0%% não acende")
	ok(fx.tocar("t_unico", Vector2.ZERO), "o que não é clarão ignora a opção")
	Config.g_temporario("tremor_clarao", 100)
	ok(fx.tocar("t_clarao", Vector2.ZERO), "clarão em 100% acende")
	fx.limpar()
	camada.queue_free()

	# 10. ponta a ponta: o orbe de XP que chega ao herói toca o collect-burst no mundo
	var w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	var cf = w.combate.fx_folha
	ok(cf != null and cf.tem("collect-burst"), "o combate monta o fx_folha com o registro")
	var nos_mundo := _nos_total(w)
	var tocados0: int = cf.usados.tocar
	w.combate.orbes.soltar(w.heroi.pos + Vector2(20, 0), 1.0)
	for i in 240:
		if cf.usados.tocar > tocados0:
			break
		w.avancar(PASSO)
	ok(cf.usados.tocar == tocados0 + 1 and cf.ativos == 1, "pegar o orbe toca o collect-burst uma vez (tocar=%d)" % (cf.usados.tocar - tocados0))
	for i in 90:
		w.avancar(PASSO)
	ok(cf.ativos == 0, "o estouro acabou e voltou ao pool no mundo (%d)" % cf.ativos)
	ok(_nos_total(w) == nos_mundo, "pegar o orbe não criou nó no mundo (%d -> %d)" % [nos_mundo, _nos_total(w)])
	w.combate.coletar(1.0, Vector2.ZERO)
	ok(cf.ativos == 1, "coletar toca o estouro")
	w.combate.limpar_partida()
	ok(cf.ativos == 0, "limpar_partida devolve o pool")
	w.queue_free()
	await get_tree().process_frame
	print("v2_fx_folha falhas=", falhas)
	get_tree().quit(1 if falhas else 0)

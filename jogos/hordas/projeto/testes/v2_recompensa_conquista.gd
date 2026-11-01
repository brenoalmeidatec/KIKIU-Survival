extends "res://testes/isolamento_v2.gd"
# UI-6 (pedido 6 de 01/11; decisão D13 do plano): conquista paga almas uma vez só e, cumprida ao vivo na partida, larga um baú de conquista.
# Checagens:
# 1. dados: as vence_<mapa> pagam 100, 150, 200 e 250 (o último mapa no maior valor), seguem com recompensa de progresso (o portal), e vence_pesadelo não paga almas.
# 2. almas do mapa: marcar a Floresta credita 100 uma vez; marcar de novo e a passada de _conquistar não creditam de novo.
# 3. ao vivo: abates de 300 numa partida cumprem abates_300 e pagam 100 uma vez; a passada seguinte não paga.
# 4. sem conquista nova nenhum baú cai.
# 5. com conquista ao vivo cai 1 baú, com piso 2, a no máximo DISTANCIA_BAU do herói.
# 6. o baú de conquista (piso 2) entrega só cartas épico ou melhor (rar >= 2), com 3 melhorias fixas.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_recompensa_conquista.tscn  (imprime "v2_recompensa_conquista falhas=0")
const Meta := preload("res://v2/meta.gd")
const Mundo := preload("res://v2/mundo.tscn")
const Resultado := preload("res://v2/resultado_meta.gd")
const SAVE_TESTE := "user://teste_v2_recompensa_conquista.cfg"

var falhas := 0


func _apagar(caminho: String) -> void:
	for sufixo in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(caminho + sufixo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho + sufixo))


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	await _testes()
	print("v2_recompensa_conquista falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _testes() -> void:
	# 1. dados: almas da cadeia de mapas, portal preservado
	var por_id := {}
	for c in Meta.conquistas():
		por_id[str(c.id)] = c
	var esperado := {"vence_floresta": 100, "vence_laboratorio": 150, "vence_cidade": 200, "vence_medio": 250}
	for id in esperado:
		var c: Dictionary = por_id.get(id, {})
		ok(Meta.almas_da_conquista(c) == esperado[id], "%s paga %d almas (paga %d)" % [id, esperado[id], Meta.almas_da_conquista(c)])
		ok(str(c.get("recompensa", {}).get("tipo", "")) == "progresso", "%s segue abrindo o portal (progresso)" % id)
	ok(Meta.almas_da_conquista(por_id.get("vence_pesadelo", {})) == 0, "vence_pesadelo não paga almas")

	# 2. almas do mapa: marcar_mapa_vencido só marca (como o combate, gravação direta); o prêmio entra uma vez em registrar_partida
	Meta.caminho_save = SAVE_TESTE
	_apagar(SAVE_TESTE)
	ok(Meta.marcar_mapa_vencido("floresta"), "a Floresta é marcada agora (gravação direta, como o combate)")
	ok(Meta.saldo() == 0, "marcar a Floresta não paga sozinho (saldo %d)" % Meta.saldo())
	var res_mapa := Meta.registrar_partida({"venceu": true, "mapa": "floresta", "mapa_vencido_agora": true, "almas": 0})
	ok(
		int(res_mapa.get("premios", -1)) == 100 and Meta.saldo() == 100,
		"registrar a vitória paga 100 de prêmio da Floresta (premios %s, saldo %d)" % [str(res_mapa.get("premios", "?")), Meta.saldo()]
	)
	ok(res_mapa.get("novas", []).has("vence_floresta"), "a conquista da Floresta aparece entre as novas")
	var res_repetida := Meta.registrar_partida({"venceu": true, "mapa": "floresta", "mapa_vencido_agora": false, "almas": 0})
	ok(int(res_repetida.get("premios", -1)) == 0 and Meta.saldo() == 100, "a vitória seguinte na Floresta não paga de novo (saldo %d)" % Meta.saldo())

	# 3. ao vivo: abates_300 paga 100 uma vez
	var viva := ConfigFile.new()
	var novas_vivo: Array = Meta._conquistar(viva, {"abates": 300})
	ok(novas_vivo.has("abates_300") and int(viva.get_value("moeda", "almas", 0)) == 100, "300 abates numa partida cumprem abates_300 e pagam 100")
	ok(Meta._conquistar(viva, {"abates": 300}).is_empty() and int(viva.get_value("moeda", "almas", 0)) == 100, "a passada seguinte não paga abates_300 de novo")

	var m := Mundo.instantiate()
	m.modo_teste = true
	add_child(m)
	m.set_process(false)
	var res = Resultado.new()
	res.montar(m)
	var baus = m.combate.baus

	# 6. baú de conquista: só épico ou melhor (3 melhorias fixas, para ver todas as cartas)
	for i in 3:
		baus.soltar(m.heroi.pos + Vector2(0, -120), 1.0, 3, 2)
		var b: Dictionary = {}
		for x in baus.lista:
			if x.ativo and int(x.forcar) == 3:
				b = x
		ok(not b.is_empty(), "o baú fixado cai (rodada %d)" % i)
		if b.is_empty():
			continue
		baus.abrir(b)
		var cartas: Array = baus.ultimas
		ok(cartas.size() == 3, "o baú entrega 3 cartas (rodada %d, tem %d)" % [i, cartas.size()])
		for c in cartas:
			ok(int(c.get("rar", -1)) >= 2, "carta de baú de conquista é épica ou melhor (rar %s)" % str(c.get("rar", "?")))

	# 4. sem conquista nova, nenhum baú cai
	var soltos_antes: int = baus.soltos
	res._conquistas_ao_vivo([])
	ok(baus.soltos == soltos_antes, "sem conquista nova, nenhum baú cai")

	# 5. com conquista ao vivo, cai 1 baú de piso 2 perto do herói
	res._conquistas_ao_vivo(["abates_300"])
	ok(baus.soltos == soltos_antes + 1, "conquista ao vivo larga 1 baú (%d -> %d)" % [soltos_antes, baus.soltos])
	var novos: Array = []
	for x in baus.lista:
		if x.ativo and int(x.forcar) == 0:
			novos.append(x)
	ok(novos.size() == 1 and int(novos[0].piso) == 2, "o baú de conquista tem piso 2 (achados %d)" % novos.size())
	if novos.size() == 1:
		var dist: float = (novos[0].pos as Vector2).distance_to(m.heroi.pos)
		ok(dist <= Resultado.DISTANCIA_BAU + 0.5, "o baú cai perto do herói (%.1f px)" % dist)

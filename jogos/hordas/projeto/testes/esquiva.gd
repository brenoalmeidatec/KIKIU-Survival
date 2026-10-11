extends Node
# Teste automático: esquiva com i-frames e esquiva perfeita (#126). Números em dados/movimento.json: 0,25 s invulnerável de
# 0,45 s de rolamento, recarga 1,2 s, 2 cargas (3 com o item do Pombo). Esquiva perfeita = inimigo a menos de 24 px no
# instante: clarão, câmera lenta local (inimigos perto ficam lentos 0,5 s) e +25% no PRÓXIMO golpe, uma vez só.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/esquiva.tscn  (imprime "ESQUIVA falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

## Tempo SIMULADO: o teste avança a arena em passos fixos de 1/60 s (a própria lógica do jogo, com o _process
## automático desligado). Antes esperava relógio de parede, e com a CPU ocupada os quadros longos estouravam as
## janelas de invencibilidade e das cargas: o resultado dependia da máquina, não do jogo.
func avancar(a: Node, s: float) -> void:
	var t := 0.0
	while t < s - 0.000001:
		var d := minf(1.0 / 60.0, s - t)
		a._process(d)
		a.jogador._process(d)   # a chegada e o nome do herói andam no mesmo tempo simulado
		await get_tree().process_frame   # um quadro de verdade por passo: golpe_extra() conta quadros do motor
		t += d

## Vigia: se um caminho do teste não chega ao quit() (um erro no meio aborta a função e o processo ficaria vivo, parado),
## o vigia encerra em 100 s de relógio real, com falha. Teste normal leva uns 10 s.
func _vigia() -> void:
	await get_tree().create_timer(100.0, true, false, true).timeout
	print("FALHOU: teste travou (passou de 100 s sem terminar)")
	print("ESQUIVA falhas=%d" % (falhas + 1))
	get_tree().quit(1)


func _ready() -> void:
	_vigia()
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar", "resortear", "pular", "banir", "status", "tela_cheia", "consumivel1", "consumivel2", "consumivel3", "consumivel_usar", "consumivel_trocar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	var mov: Dictionary = Dados.json("movimento")
	var r: Dictionary = mov.get("rolamento", {})
	var p: Dictionary = mov.get("esquiva_perfeita", {})
	ok(is_equal_approx(float(r.get("invulneravel", 0)), 0.25), "0,25 s invulnerável (%s)" % str(r.get("invulneravel")))
	ok(is_equal_approx(float(r.get("tempo", 0)), 0.45), "0,45 s de rolamento no total (%s)" % str(r.get("tempo")))
	ok(is_equal_approx(float(mov.get("folego", {}).get("recarga", 0)), 1.2), "recarga de 1,2 s")
	ok(int(mov.get("folego", {}).get("cargas", 0)) == 2, "2 cargas")
	ok(is_equal_approx(float(p.get("distancia", 0)), 24.0) and is_equal_approx(float(p.get("lento_tempo", 0)), 0.5) and is_equal_approx(float(p.get("bonus_dano", 0)), 0.25), "esquiva perfeita: 24 px, 0,5 s, +25%%")
	ok(str(mov.get("_ajuda", "")) != "", "movimento.json tem _ajuda")
	var a := Arena.new()
	a.heroi_id = "hazaki"
	add_child(a)
	a.set_process(false)   # o processo automático (relógio de parede) sai: quem anda o tempo é avancar()
	a.jogador.set_process(false)
	await avancar(a, 1.6)   # a chegada termina antes
	a.bot = false
	var j = a.jogador
	j.bot = false
	j.hp = 1000.0
	a.inimigos.limpar()
	# ---- i-frames: 0,25 s de 0,45 s ----
	ok(j.rolar(Vector2.RIGHT), "rola")
	ok(absf(j.invencivel - 0.25) < 0.03, "invulnerável 0,25 s (%.3f)" % j.invencivel)
	ok(absf(j.dash_t - 0.45) < 0.03, "rolamento de 0,45 s (%.3f)" % j.dash_t)
	var hp0: float = j.hp
	j.sofrer(10.0, "teste")
	ok(is_equal_approx(j.hp, hp0), "golpe nos i-frames não machuca")
	await avancar(a, 0.32)
	ok(j.dash_t > 0.0 and j._rolando > 0.0, "aos 0,32 s ainda está rolando (%.3f)" % j.dash_t)
	ok(j.invencivel <= 0.0, "mas os i-frames já acabaram (%.3f)" % j.invencivel)
	j.sofrer(10.0, "teste")
	ok(j.hp < hp0, "rolando sem i-frames o golpe machuca (%.0f)" % j.hp)
	await avancar(a, 0.4)
	ok(j.dash_t <= 0.0, "acabou o rolamento")
	# ---- cargas e recarga ----
	j.invencivel = 0.0
	j.folego = 2.0
	ok(j.rolar(Vector2.RIGHT), "1ª carga")
	await avancar(a, 0.5)
	ok(j.rolar(Vector2.LEFT), "2ª carga")
	ok(j.folego < 1.0 and not j.rolar(Vector2.LEFT), "as duas cargas gastas: sem carga cheia não rola (%.2f)" % j.folego)
	await avancar(a, 0.5)
	j.dash_t = 0.0
	j._rolando = 0.0
	j.folego = 0.0
	await avancar(a, 1.0)
	ok(j.folego < 1.0, "1,0 s depois ainda falta carga (%.2f)" % j.folego)
	await avancar(a, 0.35)
	ok(j.folego >= 1.0, "a carga volta em 1,2 s (%.2f)" % j.folego)
	var antes: float = j._folego_cfg("cargas", 2.0)
	ok(is_equal_approx(antes, 2.0), "2 cargas sem item")
	var gan = preload("res://scripts/hordas/ganchos.gd").new()   # o item do Pombo: uma carga a mais
	a.add_child(gan)
	gan.configurar(a, [{"tipo": "rolamento", "dist": 1.0, "cargas": 1}])
	a.ganchos = gan
	ok(is_equal_approx(j._folego_cfg("cargas", 2.0), 3.0), "3 cargas com o item")
	a.ganchos = null
	gan.queue_free()
	# ---- esquiva comum (ninguém perto): sem bônus ----
	j.folego = 2.0
	j.dash_t = 0.0
	var v_longe = a.inimigos.criar("carnical", j.centro() + Vector2(60, 0), 1)
	v_longe.atordoado = 5.0
	var perf0: int = j.perfeitas
	ok(j.rolar(Vector2.UP), "rola com inimigo a 60 px")
	ok(j.perfeitas == perf0 and not j.tem_bonus_esquiva(), "a 60 px não é esquiva perfeita")
	ok(is_equal_approx(j.golpe_extra(), 1.0), "sem bônus o golpe sai normal")
	await avancar(a, 0.55)
	# ---- esquiva perfeita: inimigo a menos de 24 px ----
	a.inimigos.limpar()
	j.folego = 2.0
	j.dash_t = 0.0
	j.invencivel = 0.0
	var v_perto = a.inimigos.criar("carnical", j.centro() + Vector2(14, 0), 1)
	v_perto.atordoado = 5.0
	var v_media = a.inimigos.criar("carnical", j.centro() + Vector2(100, 0), 1)
	v_media.atordoado = 5.0
	var v_fora = a.inimigos.criar("carnical", j.centro() + Vector2(300, 0), 1)
	v_fora.atordoado = 5.0
	await avancar(a, 3 / 60.0)   # a grade de busca dos vírus se refaz a cada quadro
	ok(j.rolar(Vector2.UP), "rola com inimigo colado")
	ok(j.perfeitas == perf0 + 1, "inimigo a 14 px: esquiva perfeita (%d)" % j.perfeitas)
	ok(j.tem_bonus_esquiva(), "ganhou o bônus do próximo golpe")
	ok(v_perto.lento >= 0.3 and v_media.lento >= 0.3, "câmera lenta local: os vírus perto ficam lentos (%.2f, %.2f)" % [v_perto.lento, v_media.lento])
	ok(v_fora.lento <= 0.0, "o vírus longe (300 px) não é afetado (%.2f)" % v_fora.lento)
	ok(j._perfeita_t > 0.0 and j._flash_t > 0.0, "clarão no herói")
	ok(not a.armas.aneis.is_empty(), "anel de luz no chão")
	# +25% no próximo golpe, uma vez só (um golpe em área leva tudo no mesmo quadro)
	var m1: float = j.golpe_extra()
	var m2: float = j.golpe_extra()
	ok(is_equal_approx(m1, 1.25) and is_equal_approx(m2, 1.25), "o próximo golpe sai +25%% (%.2f e %.2f no mesmo quadro)" % [m1, m2])
	await avancar(a, 4 / 60.0)
	ok(is_equal_approx(j.golpe_extra(), 1.0) and not j.tem_bonus_esquiva(), "só o próximo: depois volta ao normal")
	# o dano de verdade passa por inimigos.ferir
	a.inimigos.limpar()
	var alvo = a.inimigos.criar("carnical", j.centro() + Vector2(0, 200), 1)
	alvo.atordoado = 5.0
	alvo.hp = 100000.0
	j._extra_t = 4.0
	var h0: float = alvo.hp
	a.inimigos.ferir(alvo, 10.0)
	var perda: float = h0 - alvo.hp
	ok(perda >= 12.49, "ferir() aplica o +25%% (perda %.1f)" % perda)
	await avancar(a, 4 / 60.0)
	h0 = alvo.hp
	a.inimigos.ferir(alvo, 10.0)
	ok(h0 - alvo.hp < 12.49 or h0 - alvo.hp >= 19.0, "o golpe seguinte sai sem o bônus (perda %.1f; crítico à parte)" % (h0 - alvo.hp))
	# o bônus vence se o jogador não bater em 4 s
	j._extra_t = 0.2
	await avancar(a, 0.35)
	ok(not j.tem_bonus_esquiva(), "o bônus expira")
	# o robô usa a esquiva
	j.bot = true
	a.bot = true
	a.inimigos.limpar()
	j.hp = j.vida_max() - 5.0
	j.folego = 2.0
	j.dash_t = 0.0
	var v_bot = a.inimigos.criar("carnical", j.centro() + Vector2(10, 0), 1)
	v_bot.atordoado = 5.0
	await avancar(a, 3 / 60.0)
	ok(j._quer_dash(), "o robô esquiva quando tem vírus colado")
	a.queue_free()
	await get_tree().process_frame
	print("ESQUIVA falhas=%d" % falhas)
	get_tree().quit()

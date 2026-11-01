extends "res://testes/isolamento_v2.gd"
## Pool do cavaleiro oco (sprite inimigo_cavaleiro_oco): o pool pré-criado (v2_combate.json > pool) precisa cobrir, ao mesmo tempo, os pesados
## das ondas fortes (que se acumulam), a elite cavaleiro (até 2 vivas) e o mini-chefe que usa esse sprite (marca mini1).
## Joga a partida INTEIRA de cada mapa em passos acelerados (0,1 s, sem sombras) com o robô de playtest do roteiro (herói imortal, para a
## partida chegar à vitória), na dificuldade Difícil (a que mais enche a tela), e anota o PICO de monstros vivos com esse sprite.
## Falha se algum nó de monstro desse sprite for criado depois da pré-criação (o pool esvaziou e o mundo criou um na hora) ou se o pico
## passar do pool configurado. Os outros sprites só são impressos (AVISO): cada um tem o seu teste e o seu pool.
## Uma cena só não cabe nos 120 s do CI: este .tscn joga floresta e laboratório; v2_pool_cavaleiro_cidade e _medio jogam os outros dois.
## Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_pool_cavaleiro.tscn  (imprime "v2_pool_cavaleiro falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Dificuldade := preload("res://v2/dificuldade.gd")
const Sombras := preload("res://v2/sombras.gd")
const SPRITE := "inimigo_cavaleiro_oco"
## 0,1 s é o maior passo que o jogo aceita (`_process` usa minf(delta, 0.1)): um mapa inteiro roda em ~15 a 40 s reais.
const PASSO := 0.1
const TETO_PASSOS := 40 * 60 * 10  # 40 min de jogo: mais que o maior mapa (60 níveis de 20 s mais os chefes)
const SEMENTE := 1
## Os mapas desta cena.
@export var mapas: Array[String] = ["floresta", "laboratorio"]

var falhas := 0


## O robô de playtest sem sair do processo: `_pt_fim` só guarda o desfecho (o original encerra o jogo).
class Robo:
	extends "res://v2/roteiro.gd"
	var desfecho := ""

	func _pt_fim(d: String, trava := "") -> void:
		if not playtest:
			return
		playtest = false
		desfecho = d if trava == "" else "%s:%s" % [d, trava]


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var pool: int = int(Dados.json("v2_combate").pool[SPRITE])
	print("pool configurado do %s: %d" % [SPRITE, pool])
	var pico_geral := 0
	for id in mapas:
		pico_geral = maxi(pico_geral, await _partida(id, pool))
	print("pico de vivos com o sprite nesta cena: %d (pool %d; com folga de 25%% o pool pede %d)" % [pico_geral, pool, ceili(pico_geral * 1.25)])
	print("v2_pool_cavaleiro falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


## Quantos nós de monstro existem de cada sprite (vivos ou no pool): `_todos_monstros` guarda todos.
func _contar(w) -> Dictionary:
	var c := {}
	for mo in w._todos_monstros:
		c[mo.chave] = int(c.get(mo.chave, 0)) + 1
	return c


## Os monstros vivos com o sprite, e quantos deles são chefe, elite ou comuns (os pesados das ondas e os moradores).
func _vivos(w) -> Dictionary:
	var r := {"total": 0, "elite": 0, "chefe": 0, "comum": 0}
	for m in w.monstros:
		if m.chave != SPRITE:
			continue
		r.total += 1
		if m.chefe:
			r.chefe += 1
		elif m.elite:
			r.elite += 1
		else:
			r.comum += 1
	return r


## Joga a partida inteira do mapa `id` e devolve o pico de vivos com o sprite.
func _partida(id: String, pool: int) -> int:
	seed(SEMENTE)  # os sorteios sem semente própria (como no robô de playtest do jogo) repetem de uma execução para a outra
	var w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = id
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	w.sombras.definir_modo(Sombras.NENHUMA)  # só custo de desenho: não muda quem nasce nem quem morre
	w.meta_bonus["dificuldade"] = Dificuldade.regras("dificil")
	var robo := Robo.new()
	robo.montar(w, {"playtest": "1", "semente": str(SEMENTE), "playtest_max": "1000000"})
	w.roteiro = robo
	w.heroi.imortal = true
	var antes := _contar(w)
	ok(int(antes.get(SPRITE, 0)) == pool, "%s: o mundo pré-criou o pool configurado (%d de %d)" % [id, int(antes.get(SPRITE, 0)), pool])
	var pico := {"total": 0, "elite": 0, "chefe": 0, "comum": 0}
	var pico_t := 0.0
	var passos := 0
	var t0 := Time.get_ticks_msec()
	while robo.desfecho == "" and passos < TETO_PASSOS:
		w.avancar(PASSO)
		robo.atualizar(PASSO)
		passos += 1
		var v := _vivos(w)
		if v.total > pico.total:
			pico = v
			pico_t = w.tempo_partida
	var depois := _contar(w)
	var novos := {}
	for nome in depois:
		if int(depois[nome]) != int(antes.get(nome, 0)):
			novos[nome] = int(depois[nome]) - int(antes.get(nome, 0))
	print(
		(
			"cavaleiro %s: desfecho=%s, %.0f s de jogo (%.0f s reais), pico=%d aos %.0f s (comum %d, elite %d, chefe %d), nós novos: %s"
			% [id, robo.desfecho, w.tempo_partida, (Time.get_ticks_msec() - t0) / 1000.0, pico.total, pico_t, pico.comum, pico.elite, pico.chefe, str(novos)]
		)
	)
	ok(robo.desfecho == "vitoria", "%s: a partida inteira foi jogada até a vitória (desfecho '%s')" % [id, robo.desfecho])
	ok(int(novos.get(SPRITE, 0)) == 0, "%s: nenhum nó de %s criado depois da pré-criação (%d criados)" % [id, SPRITE, int(novos.get(SPRITE, 0))])
	ok(int(pico.total) <= pool, "%s: pico de vivos (%d) cabe no pool (%d)" % [id, pico.total, pool])
	for nome in novos:
		if nome != SPRITE:
			print("AVISO: %s: %d nós de %s criados no meio da partida (pool desse sprite, fora deste teste)" % [id, int(novos[nome]), nome])
	w.queue_free()
	await get_tree().process_frame
	return int(pico.total)

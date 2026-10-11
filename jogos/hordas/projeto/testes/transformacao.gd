extends Node
# Teste automático: transformação em dragão do Hazaki (#20, seções 8, 9, 10, 13, 25 e 26 do design).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/transformacao.tscn  (imprime "DRAGAO falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _ready() -> void:
	# seção 13: as habilidades do dragão não são cartas e não contam como exclusiva
	for id in ["baforada", "garras_dragao", "energia_draconica", "rugido"]:
		ok(not Construcao.arma_permitida(id, "hazaki", []), "%s nunca vira carta" % id)
		ok(not Construcao.exclusiva(id), "%s não conta como exclusiva" % id)
	ok(Construcao.arma_permitida("katana", "hazaki", ["poder_elemental", "aura_hazaki"]) == false, "limite de 2 exclusivas continua")
	# outro herói: sem transformação
	var outro := Arena.new()
	outro.heroi_id = "lucas"
	add_child(outro)
	await esperar(0.2)
	ok(not outro.habilidades.tem(), "o Lucas não vira dragão")
	outro.queue_free()
	# Hazaki com 2 exclusivas, equipamento e uma global: transforma e volta igual (seção 10)
	Engine.time_scale = 3.0
	var a := Arena.new()
	a.heroi_id = "hazaki"
	a.bot = false   # sem robô: ele pegava baús (armas novas) e escolhia cartas durante a espera, e a build mudava no meio do teste
	add_child(a)
	await esperar(0.2)
	a.jogador.bot = false
	a.jogador.invencivel = 999.0   # o herói não morre no meio do teste (e nem pisca)
	a.diretor.bonus_minutos = -100.0   # sem inimigos nascendo nas esperas
	a.inimigos.limpar()
	a.coleta.limpar()   # nada no chão para pegar
	a.armas.adicionar("aura_hazaki")
	a.armas.adicionar("katana")
	a.armas.subir("katana")
	a.equipamentos["cabeca"] = "cabeca_guerreiro"
	a.xp = -1.0e12   # sem subir de nível: nenhuma carta se abre durante o teste
	a.atualizar_visual()
	await esperar(0.1)
	var antes := JSON.stringify(a.armas.lista.map(func(x): return [x.id, x.nivel]))
	var camadas_antes: Array = a.jogador.camadas.keys()
	camadas_antes.sort()
	var h = a.habilidades
	ok(h.tem() and not h.desbloqueada, "começa bloqueada")
	var vel_humano: float = a.stat("velocidade")
	h.desbloquear()
	h.energia = h.energia_max()
	h.transformar()   # sem robô, quem aperta a tecla é o teste (com o robô ligado seria automático)
	await esperar(1.6)   # a animação da forma termina
	ok(h.ativa, "transformou")
	ok(a.jogador.forma != null and a.jogador.humano < 0.01, "corpo humano sumiu e o dragão apareceu")
	ok(a.armas.ativas().map(func(x): return x.id) == ["baforada", "garras_dragao", "energia_draconica", "rugido"], "só as habilidades do dragão atacam")
	ok(h.bonus("velocidade") > 0.0 and a.stat("velocidade") > vel_humano, "dragão é mais rápido")
	# uma carta escolhida durante a forma evolui a build HUMANA
	a.aplicar({"tipo": "arma", "id": "cafe", "nivel": 1})
	ok(a.armas.forma_lista.size() == 4 and not a.armas.forma_lista.any(func(x): return x.id == "cafe"), "carta não entra nas armas do dragão")
	var max1: float = h.energia_max()
	h.energia = 0.5
	await esperar(1.5)   # a energia acaba, ele volta
	ok(not h.ativa and a.jogador.forma == null and is_equal_approx(a.jogador.humano, 1.0), "voltou a ser humano")
	var depois := JSON.stringify(a.armas.lista.filter(func(x): return x.id != "cafe").map(func(x): return [x.id, x.nivel]))
	ok(antes == depois, "armas humanas exatamente como estavam (%s vs %s)" % [antes, depois])
	ok(a.armas.tem("cafe"), "a carta pega na forma ficou com o humano")
	var camadas_depois: Array = a.jogador.camadas.keys()
	camadas_depois.sort()
	ok(camadas_antes == camadas_depois and "cabeca_guerreiro" in camadas_depois, "equipamento visual volta igual (%s)" % [camadas_depois])
	ok(h.energia_max() > max1, "energia pedida cresce a cada uso (seção 25)")
	ok(h.bonus("velocidade") == 0.0 and h.bonus("dano") == 0.0 and h.mult_dano() == 1.0, "bônus da forma saem (atributos voltam ao normal)")
	Engine.time_scale = 1.0
	print("DRAGAO falhas=", falhas)
	get_tree().quit()

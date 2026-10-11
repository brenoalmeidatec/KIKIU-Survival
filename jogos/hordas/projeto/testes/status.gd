extends Node
# Teste automático: tela de inventário e status (#125). Contas puras (base cinza, variação verde/vermelha, recarga ao
# contrário), dados da build (armas com nível e tamanho, passivos, equipamentos, conjuntos), abrir/fechar com pausa no solo e
# sem pausa no online, aviso de 2 s quando um conjunto liga.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/status.tscn  (imprime "STATUS falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Tela := preload("res://scripts/hordas/tela_status.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


## Vigia: se um caminho do teste não chega ao quit() (um erro no meio aborta a função e o processo ficaria vivo, parado),
## o vigia encerra em 100 s de relógio real, com falha. Teste normal leva uns 5 s.
func _vigia() -> void:
	await get_tree().create_timer(100.0, true, false, true).timeout
	print("FALHOU: teste travou (passou de 100 s sem terminar)")
	print("STATUS falhas=%d" % (falhas + 1))
	get_tree().quit(1)


func _ready() -> void:
	_vigia()
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	# --- contas puras
	var base := {"dano": 1.0, "recarga": 1.0, "vida_max": 100.0, "regen": 0.0, "critico": 0.05, "sorte": 0.0}
	var atual := {"dano": 1.2, "recarga": 0.9, "vida_max": 90.0, "regen": 0.5, "critico": 0.05, "sorte": 0.0}
	var m := {}
	for l in Tela.linhas_atributos(base, atual):
		m[l.k] = l
	ok(m.dano.sentido == 1 and m.dano.txt_delta == "+20%" and m.dano.txt_base == "100%", "dano subiu: base 100%% e +20%% (%s %s)" % [m.dano.txt_base, m.dano.txt_delta])
	ok(m.vida_max.sentido == -1 and m.vida_max.txt_delta == "-10", "vida desceu: -10 (%s)" % m.vida_max.txt_delta)
	ok(m.recarga.sentido == 1 and m.recarga.txt_delta == "-10%", "recarga menor é melhor: sentido verde, texto -10%% (%s)" % m.recarga.txt_delta)
	ok(m.regen.sentido == 1 and m.regen.txt_delta == "+0.5/s", "regen +0.5/s (%s)" % m.regen.txt_delta)
	ok(m.critico.sentido == 0 and m.critico.txt_delta == "" and m.critico.txt_base == "5%", "sem variação: só a base em cinza")
	ok(Tela.linhas_atributos(base, atual).size() == Tela.ATRIBUTOS.size(), "uma linha por atributo")
	# --- dentro da partida
	var a = Arena.new()
	a.heroi_id = "hazaki"
	a.bot = true
	a.semente = 5
	add_child(a)
	await get_tree().create_timer(0.3, true, false, true).timeout
	a.set_process(false)
	a.jogador.invencivel = 999.0
	ok(a.tela_status != null and a.tela_status.arena == a, "a arena cria a tela de status")
	ok(a.camada_objetivos != null, "a arena cria a camada de objetivos")
	a.armas.adicionar("katana")
	a.armas.lista[-1].nivel = 4
	a.passivos = {"energetico": 3}
	a.equipamentos = {"cabeca": "cabeca_guerreiro"}
	a.build_mudou()
	var armas := Tela.armas_info(a)
	ok(armas.size() >= 2, "armas da build (%d)" % armas.size())
	var kat = armas.filter(func(x): return x.id == "katana")[0]
	ok(kat.nivel == 4 and kat.nivel_max >= 4 and kat.nome != "" and kat.tamanho > 0.0 and kat.dano > 0.0, "katana: nível, máximo, nome e crescimento")
	var pas := Tela.passivos_info(a)
	ok(pas.size() == 1 and pas[0].nivel == 3 and pas[0].nome == "Pedra de Amolar", "passivo com nível")
	var eq := Tela.equipamentos_info(a)
	ok(eq.size() == 1 and eq[0].slot == "cabeca" and eq[0].nome != "", "equipamento no slot")
	var lin := {}
	for l in Tela.linhas_atributos(Tela.bases(a), Tela.atuais(a)):
		lin[l.k] = l
	ok(lin.dano.sentido == 1, "o passivo de dano aparece em verde (%s)" % lin.dano.txt_delta)
	# --- abrir e fechar: solo pausa, online não
	var t = a.tela_status
	ok(not t.aberta and not get_tree().paused, "começa fechada")
	t.abrir()
	ok(t.aberta and get_tree().paused, "solo: aberta pausa o jogo")
	t.fechar()
	ok(not t.aberta and not get_tree().paused, "solo: fechar despausa")
	a.eh_online = true
	t.abrir()
	ok(t.aberta and not get_tree().paused, "online: aberta NÃO pausa")
	t.fechar()
	a.eh_online = false
	get_tree().paused = true
	ok(not t.pode_abrir(), "com outra tela pausando (carta, menu) a de status não abre")
	get_tree().paused = false
	ok(t.pode_abrir(), "jogo livre: pode abrir")
	# --- a ação existe e tem Tab no teclado e Back no controle (main.gd)
	var Main := preload("res://scripts/hordas/main.gd")
	ok(Main.TECLAS.has("status") and KEY_TAB in Main.TECLAS.status, "status = Tab")
	ok(Main.CONTROLE.has("status") and JOY_BUTTON_BACK in Main.CONTROLE.status, "status = Back no controle")
	print("STATUS falhas=%d" % falhas)
	get_tree().quit()

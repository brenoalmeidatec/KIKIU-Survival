extends Node
# Teste automático: as 8 raças com gancho (#72 marco 6). Dados válidos, cada gancho dispara na condição certa e NÃO dispara fora
# dela, a ficha online recusa raça inexistente, e herói salvo antes do marco (sem ganchos) continua carregando.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/racas.tscn  (imprime "RACAS falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Criacao := preload("res://scripts/hordas/criacao.gd")
const Ganchos := preload("res://scripts/hordas/ganchos.gd")
const Paleta := preload("res://scripts/hordas/paleta.gd")
const NOVAS := ["capivara", "cogumelo", "gargula", "vampiro", "gato", "pombo", "meio_dragao", "fantasma"]
var falhas := 0
var a
var ino


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## Uma partida nova com o herói c:<raca>:guerreiro (a anterior sai). O relógio é do teste: a arena não anda sozinha.
func nova(raca: String) -> void:
	if a != null:
		a.queue_free()
		await get_tree().process_frame
	var id := Criacao.id_de(raca, "guerreiro")
	Criacao.registrar(id)
	a = Arena.new()
	a.heroi_id = id
	a.bot = true
	a.semente = 5
	add_child(a)
	await esperar(0.2)
	a.set_process(false)
	a.xp = -1.0e12
	a.jogador.invencivel = 0.0
	a.jogador._mov = Vector2.ZERO
	ino = a.inimigos
	ino.limpar()
	a.armas.lista.clear()
	a.jogador.hp = a.stat("vida_max")


func bicho(desl: Vector2, vida := 1.0e6):
	var v = ino.criar("bug", a.jogador.centro() + desl)
	v.hpmax = vida
	v.hp = vida
	v.t_nasc = 0.0
	v.vel = 0.0
	return v


## Avança `s` segundos do relógio dos ganchos (e dos inimigos, que guardam os estados), em passos de 1/30 s.
## A grade dos inimigos (no_circulo) só se refaz no ino.atualizar: depois de criar bichos, chame grade().
func grade() -> void:
	ino.atualizar(0.001, a.jogador)


func passo(s: float, inimigos_tambem := true) -> void:
	for _i in int(round(s * 30.0)):
		a.ganchos.atualizar(1.0 / 30.0)
		if inimigos_tambem:
			ino.atualizar(1.0 / 30.0, a.jogador)


func levar(dano: float, fonte := "bug") -> float:
	return a.ganchos.dano_recebido(dano, fonte)


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	Criacao.arquivo = "user://teste_racas.json"
	Criacao.apagar()

	# --- dados
	var lista: Array = Criacao.lista_racas()
	ok(lista.size() >= 13, "13 raças na lista (%d)" % lista.size())
	var tipos_usados := {}
	var peles := {}
	for r in lista:
		var d: Dictionary = Criacao.racas().get(r, {})
		ok(d.has("nome") and d.has("curto") and d.has("descricao") and d.has("bonus") and d.has("fraquezas"), "%s tem os campos básicos" % r)
		var p := Paleta.padrao(r)
		ok(Paleta.valida(p), "%s tem paleta inicial válida" % r)
		peles[p.pele] = true
		for g in d.get("ganchos", []):
			ok(Ganchos.erro(g) == "", "%s: gancho válido (%s)" % [r, Ganchos.erro(g)])
			tipos_usados[str(g.tipo)] = true
		var h := Criacao.montar(r, "guerreiro")
		ok(h.has("ganchos") and h.ganchos.size() == d.get("ganchos", []).size(), "%s: o herói montado leva os ganchos" % r)
		var f := Criacao.ficha_nova(r, "mago")
		f["nome"] = "Teste"
		ok(Criacao.erro_ficha(f) == "", "%s: ficha nova vale (%s)" % [r, Criacao.erro_ficha(f)])
	ok(peles.size() == lista.size(), "cada raça começa com uma pele diferente (%d de %d)" % [peles.size(), lista.size()])
	for r in NOVAS:
		ok(r in lista, "a raça nova existe: " + r)
		ok(not Criacao.racas().get(r, {}).get("ganchos", []).is_empty(), "%s tem gancho" % r)
	for t in Ganchos.TIPOS:
		ok(tipos_usados.has(t), "o tipo de gancho '%s' é usado por alguma raça" % t)
	ok(Ganchos.erro({"tipo": "inexistente", "nome": "x", "texto": "y"}) != "", "tipo de gancho desconhecido é erro")
	ok(Ganchos.erro({"tipo": "pedra", "nome": "x", "texto": "y"}) != "", "gancho sem parâmetro é erro")
	var desc := Criacao.descrever({"el_fogo": 0.25})
	ok(desc.size() == 1 and str(desc[0][0]).contains("queimar"), "afinidade de fogo se descreve (%s)" % str(desc))

	# --- ficha online: raça inexistente é recusada, as novas passam
	var f := Criacao.ficha_nova("capivara", "guerreiro")
	f["nome"] = "Capi"
	ok(Criacao.erro_ficha(f) == "", "ficha de capivara vale")
	f["raca"] = "dragaozinho"
	ok(Criacao.erro_ficha(f) == "raça inexistente", "ficha com raça inventada é recusada (%s)" % Criacao.erro_ficha(f))
	ok(not Criacao.registrar_ficha("c:hfalso", f), "registrar_ficha recusa a raça inventada")
	ok(Criacao.partes("c:fantasma:mago") == ["fantasma", "mago"], "id c:fantasma:mago vale")
	ok(Criacao.partes("c:xuxa:mago").is_empty(), "id com raça inventada não vale")
	f = Criacao.ficha_nova("gato", "ladino")
	f["nome"] = "Mimi"
	f["paleta"]["pele"] = 99
	ok(Criacao.erro_ficha(f) != "", "pele fora da lista é recusada")

	# --- herói salvo antes do marco 6 continua carregando (formato do marco 1 e ficha sem ganchos)
	var antigo := FileAccess.open(Criacao.arquivo, FileAccess.WRITE)
	antigo.store_string(JSON.stringify({"id": "c:orc:guerreiro"}))
	antigo.close()
	var c1 := Criacao.carregar(false)
	ok(c1.ids == ["c:orc:guerreiro"], "save do marco 1 ainda carrega (%s)" % str(c1.ids))
	var h_orc: Dictionary = Dados.json("herois").get("c:orc:guerreiro", {})
	ok(not h_orc.is_empty() and h_orc.ganchos.is_empty(), "herói antigo (orc) carrega sem gancho")
	ok(Ganchos.de_heroi("hazaki").is_empty() and Ganchos.de_heroi("c:nao:existe").is_empty(), "herói fixo e id desconhecido: sem gancho")
	var f2 := Criacao.ficha_nova("goblin", "clerigo")
	f2["nome"] = "Velho"
	var antigo2 := FileAccess.open(Criacao.arquivo, FileAccess.WRITE)
	antigo2.store_string(JSON.stringify({"herois": [{"id": "c:hvelho", "ficha": f2, "em_corrida": false}]}))
	antigo2.close()
	var c2 := Criacao.carregar(false)
	ok(c2.ids == ["c:hvelho"], "save do marco 2 (ficha sem ganchos) carrega (%s)" % str(c2.ids))
	Criacao.apagar()

	# --- humano (sem gancho): nada disso existe pra ele
	await nova("humano")
	ok(a.ganchos == null, "humano: sem nó de ganchos")
	var dano_h: float = a.jogador.hp
	a.jogador.hp = 50.0
	a.registrar_dano("x", 100.0, a.jogador.position)
	ok(is_equal_approx(a.jogador.hp, 50.0), "humano: acertar não cura")
	a.jogador.hp = dano_h
	a.jogador.rolar(Vector2.RIGHT)
	var rol_base: float = a.jogador.dash_t
	var cargas_base: float = a.jogador._folego_cfg("cargas", 2.0)
	ok(is_equal_approx(rol_base, float(Dados.json("movimento").rolamento.tempo)), "humano: rolamento normal (%.2f)" % rol_base)

	# --- capivara: aura de lentidão (só quem está dentro do raio; só o anfitrião/solo aplica)
	await nova("capivara")
	ok(a.ganchos != null and a.ganchos.tem("aura_lento"), "capivara: tem a aura de lentidão")
	var perto = bicho(Vector2(40, 0))
	var longe = bicho(Vector2(220, 0))
	grade()
	passo(0.6)
	ok(perto.lento > 0.0, "capivara: quem está dentro da aura fica lento")
	ok(longe.lento == 0.0, "capivara: quem está fora do raio não fica lento")
	var perto2 = bicho(Vector2(30, 20))
	grade()
	ino.espelho = true  # cliente online: a IA não roda aqui, quem aplica é o anfitrião
	a.ganchos._aura_t.clear()
	passo(0.6, false)
	ok(perto2.lento == 0.0, "capivara: no cliente a aura não mexe nos inimigos (o anfitrião aplica)")
	ino.espelho = false
	var no_remoto = bicho(Vector2(0, 330))  # o anfitrião aplica a aura do cliente (a raça vem da ficha validada)
	grade()
	a.ganchos._aplicar_auras(Ganchos.de_heroi(a.heroi_id), a.jogador.centro() + Vector2(0, 330), 7, 0.3)
	ok(no_remoto.lento > 0.0, "capivara: a aura de um cliente (posição remota) pega os inimigos dele no anfitrião")
	a.ganchos._aura_t.clear()

	# --- cogumelo: esporos (veneno) e carne mole
	await nova("cogumelo")
	var el = ino.elementos
	var dentro = bicho(Vector2(30, 0))
	var fora = bicho(Vector2(200, 0))
	passo(2.0)
	ok(el.estados.has(dentro.id) and el.estados[dentro.id].st.has("veneno"), "cogumelo: quem chega perto fica envenenado")
	ok(not el.estados.has(fora.id), "cogumelo: quem está longe não")
	ok(dentro.hp < 1.0e6, "cogumelo: o veneno tira vida (%.1f)" % (1.0e6 - dentro.hp))
	ok(is_equal_approx(levar(10.0), 12.0), "cogumelo: carne mole, leva 20%% a mais (%.1f)" % levar(10.0))

	# --- gárgula: pele de pedra só depois de ficar parada
	await nova("gargula")
	a.jogador._mov = Vector2.ZERO
	passo(0.5)
	ok(is_equal_approx(levar(10.0), 10.0), "gárgula: parada há pouco tempo, dano normal")
	passo(1.0)
	ok(is_equal_approx(levar(10.0), 6.0), "gárgula: parada há 1,5 s, leva 40%% menos (%.1f)" % levar(10.0))
	a.jogador._mov = Vector2.RIGHT
	passo(0.1)
	ok(is_equal_approx(levar(10.0), 10.0), "gárgula: andou, a pedra some")

	# --- vampiro: roubo de vida (com teto por segundo) e luz
	await nova("vampiro")
	a.jogador.hp = 50.0
	a.registrar_dano("x", 100.0, a.jogador.position)  # 3% de 100 = 3 de vida
	passo(0.2)
	ok(absf(a.jogador.hp - 53.0) < 0.6, "vampiro: acertar 100 de dano cura ~3 (%.2f)" % a.jogador.hp)
	a.jogador.hp = 10.0
	a.registrar_dano("x", 100000.0, a.jogador.position)
	passo(1.0)
	var vmax: float = a.jogador.vida_max()
	ok(a.jogador.hp - 10.0 <= vmax * 0.12 + 1.0, "vampiro: o roubo tem teto por segundo (curou %.1f de no máx %.1f)" % [a.jogador.hp - 10.0, vmax * 0.12])
	ok(a.jogador.hp - 10.0 >= 5.0, "vampiro: e cura de fato (%.1f)" % (a.jogador.hp - 10.0))
	a.jogador.hp = vmax
	a.registrar_dano("x", 5000.0, a.jogador.position)
	passo(0.5)
	ok(is_equal_approx(a.jogador.hp, vmax), "vampiro: com a vida cheia nada acontece")
	a.chao._ambiente.color = Color(0.5, 0.5, 0.55)  # escuro
	a.jogador.hp = 40.0
	passo(1.0)
	ok(a.ganchos.escuro and not a.ganchos.claro, "vampiro: ambiente escuro liga o escuro")
	ok(is_equal_approx(a.ganchos.bonus("regen"), 1.0), "vampiro: no escuro regenera +1")
	ok(a.stat("regen") >= 1.0, "vampiro: e a regeneração do herói sobe (%.2f)" % a.stat("regen"))
	a.chao._ambiente.color = Color(1, 1, 1)  # luz forte
	a.jogador.hp = 40.0
	passo(2.0)
	ok(a.ganchos.claro and not a.ganchos.escuro, "vampiro: luz forte liga o claro")
	ok(is_equal_approx(a.ganchos.bonus("regen"), 0.0), "vampiro: sem regeneração na luz")
	ok(a.jogador.hp < 40.0 and a.jogador.hp >= 1.0, "vampiro: a luz queima (%.2f)" % a.jogador.hp)
	a.jogador.hp = 1.0
	passo(2.0)
	ok(a.jogador.hp >= 1.0 and not a.acabou, "vampiro: a luz nunca mata")
	a.chao._ambiente.color = Color(0.86, 0.86, 0.86)  # meio-termo: nem uma coisa nem outra
	a.jogador.hp = 40.0
	passo(1.0)
	ok(not a.ganchos.escuro and not a.ganchos.claro and is_equal_approx(a.jogador.hp, 40.0), "vampiro: luz média não faz nada (%.2f)" % a.jogador.hp)

	# --- gato: levanta até 3 vezes e explode; na quarta morte, morre
	await nova("gato")
	var perto_g = bicho(Vector2(40, 0), 5000.0)
	var longe_g = bicho(Vector2(400, 0), 5000.0)
	grade()
	for i in 3:
		a.jogador.invencivel = 0.0
		a.jogador.hp = 5.0
		a.jogador.sofrer(9999.0, "bug")
		ok(not a.acabou and a.jogador.hp > 0.0, "gato: levantou na morte %d (hp %.1f)" % [i + 1, a.jogador.hp])
		ok(a.ganchos.vidas_gastas == i + 1, "gato: contou a vida %d" % (i + 1))
		ok(a.jogador.invencivel > 1.0, "gato: ficou invencível um instante")
	ok(absf(a.jogador.hp - a.jogador.vida_max() * 0.4) < 1.0, "gato: volta com 40%% da vida (%.1f de %.1f)" % [a.jogador.hp, a.jogador.vida_max()])
	ok(perto_g.hp < 5000.0, "gato: a explosão feriu quem estava perto")
	ok(longe_g.hp == 5000.0, "gato: e não feriu quem estava longe")
	a.jogador.invencivel = 0.0
	a.jogador.sofrer(9999.0, "bug")
	ok(a.acabou, "gato: na quarta morte, morre de vez")
	await nova("gato")
	a.desistir()
	ok(a.acabou, "gato: desistir não levanta")

	# --- pombo: rolamento mais longo e com uma carga a mais
	await nova("pombo")
	ok(is_equal_approx(a.jogador._folego_cfg("cargas", 2.0), cargas_base + 1.0), "pombo: uma carga de rolamento a mais")
	a.jogador.folego = 3.0
	a.jogador.rolar(Vector2.RIGHT)
	ok(is_equal_approx(a.jogador.dash_t, rol_base * 1.5), "pombo: rola 50%% mais longe (%.2f contra %.2f)" % [a.jogador.dash_t, rol_base])
	ok(a.stat("velocidade") > 1.2, "pombo: bem mais rápido (%.2f)" % a.stat("velocidade"))

	# --- dragão: afinidade de fogo e fúria ao apanhar
	await nova("meio_dragao")
	ok(is_equal_approx(float(a._stats.get("el_fogo", 0.0)), 0.25), "dragão: 25%% de afinidade com fogo")
	ok(is_equal_approx(float(a.inimigos.elementos.chance.get("fogo", 0.0)), 0.25), "dragão: a chance chega nos elementos")
	var d0: float = a.stat("dano")
	passo(0.1)
	ok(is_equal_approx(a.stat("dano"), d0), "dragão: sem apanhar, sem fúria")
	for i in 3:
		levar(5.0)
	passo(0.1)
	ok(
		a.ganchos.pilhas == 3 and is_equal_approx(a.stat("dano"), d0 + 0.21),
		"dragão: 3 golpes levados = +21%% de dano (%.2f contra %.2f)" % [a.stat("dano"), d0]
	)
	for i in 10:
		levar(5.0)
	ok(a.ganchos.pilhas == 5, "dragão: a fúria tem teto de 5 pilhas")
	passo(5.5)
	ok(a.ganchos.pilhas == 0 and is_equal_approx(a.stat("dano"), d0), "dragão: sem apanhar por 5 s a fúria passa")

	# --- fantasma: o toque dos bichos atravessa quando anda; os tiros doem mais
	await nova("fantasma")
	a.jogador._mov = Vector2.RIGHT
	ok(is_equal_approx(levar(10.0, "bug"), 5.0), "fantasma andando: o toque dói 50%% menos")
	ok(is_equal_approx(levar(10.0, "tiro"), 12.5), "fantasma andando: o tiro dói 25%% mais")
	a.jogador._mov = Vector2.ZERO
	ok(is_equal_approx(levar(10.0, "bug"), 10.0), "fantasma parado: o toque dói normal")
	ok(is_equal_approx(levar(10.0, "tiro"), 12.5), "fantasma parado: o tiro continua doendo mais")

	a.queue_free()
	Criacao.apagar()
	print("RACAS falhas=", falhas)
	get_tree().quit()

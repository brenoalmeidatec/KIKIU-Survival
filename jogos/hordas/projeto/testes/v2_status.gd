extends Node
# Teste automático do card "SUA BUILD" da v2 (v2/status.gd). A pergunta de cada bloco é: o número que o card mostra é o que o jogo FAZ?
# Cada número do card é conferido contra o jogo em movimento: acerta um boneco com o combo e compara o dano, mede o alcance de cada passo,
# anda e corre e mede a velocidade, cura o herói subindo de nível, mede a recuperação do fôlego, solta orbes na borda do ímã, conta as
# esquivas, simula cada golpe automático (aura, lâminas, corvos, raio, runa e o Anel de Brasas) e confere o dano por acerto e o dano por
# segundo, dispara a onda e a lança da katana e lê o dano delas, e confere os bônus do Santuário e os contadores da partida. O "Combo
# completo" é medido segurando o clique num boneco (passos + hit-stop + pausa do fim do combo, margem de 5%), o alcance inclui o avanço
# do golpe (a estocada alcança o que o card diz), a onda sai em todos os cortes, as dicas de evolução acompanham banimento e evolução, o
# crítico para em 100% e as almas são as que o fim da partida credita (com "Almas abundantes").
# Interface: C liga e desliga o card pela entrada de verdade (Input.parse_input_event, a mesma que a janela usa). Sobre a escolha de cartas
# e o baú o C abre o painel CENTRAL (opaco, por cima das cartas): enquanto está aberto, tecla e clique não escolhem carta, a trava de 1 s
# segue correndo e o ESC abre a pausa. A pausa mostra o card ao lado do menu só na tela "menu"; atualizar não cria nó. Em TODOS os modos
# (HUD compacto, pausa e painel central) e com a build vazia, a de meio de partida, a máxima e o Santuário todo comprado, nenhuma linha
# estoura a coluna, nada é cortado e as colunas do HUD não cobrem o HUD.
# Usa saves TEMPORÁRIOS (meta e opções); o save real (user://v2_progresso.cfg) não é tocado, e o md5 confere.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_status.tscn  (imprime "v2_status falhas=0")
# Prints (com janela): godot --path jogos/hordas/projeto res://testes/v2_status.tscn -- --fotos=PASTA
#   grava status_hud_vazio, status_hud, status_hud_chefe, status_escolha, status_bau e status_pausa (só o viewport, nunca a área de trabalho).
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Status := preload("res://v2/status.gd")
const Meta := preload("res://v2/meta.gd")
const Pausa := preload("res://v2/pausa.gd")
const PASSO := 1.0 / 60.0
const PASSO_FINO := 1.0 / 240.0  # a medição do ciclo do combo e do avanço do golpe sem o arredondamento por quadro
const SAVE_TESTE := "user://teste_v2_status_meta.cfg"
const OPCOES_TESTE := "user://teste_v2_status_opcoes.cfg"
const SAVE_REAL := "user://v2_progresso.cfg"
const OPCOES_REAL := "user://opcoes.cfg"

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


## Compara dois números com tolerância absoluta.
func perto(a: float, b: float, tol: float, msg: String) -> void:
	ok(absf(a - b) <= tol, "%s (card/esperado %.4f contra jogo %.4f, tolerância %.4f)" % [msg, a, b, tol])


## Compara com tolerância relativa (a simulação não é exata: o alvo anda, o corvo voa, a runa espera).
func faixa(esperado: float, medido: float, lo: float, hi: float, msg: String) -> void:
	print("  %s: card %.1f, simulação %.1f (%.2fx)" % [msg.split(":")[0], esperado, medido, medido / maxf(esperado, 0.001)])
	ok(
		esperado > 0.0 and medido >= esperado * lo and medido <= esperado * hi,
		"%s (card %.2f, simulação %.2f, aceito %.2f a %.2f vezes)" % [msg, esperado, medido, lo, hi]
	)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Volta a partida ao começo (os bônus do Santuário entram de novo), tira os monstros e deixa o herói parado, imortal e olhando para a direita.
func zerar() -> void:
	seed(4242)  # o jogo sorteia com o gerador global: a simulação de cada bloco sai igual em toda rodada
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	var h = w.heroi
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = null
	h.correr_forcado = null
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	w.combate.cartas.rng.seed = 12345
	w.status._hud = false
	w.status.na_pausa(false)
	passos(3)


## Um boneco parado (vida enorme, atordoado para sempre, sem empurrão) a (dx, dy) do herói.
func boneco(dx: float, dy := 0.0, nome := "inimigo_cao_ossos"):
	var m = w.nascer_monstro(nome, w.heroi.pos + Vector2(dx, dy))
	m.vida_max = 1.0e6
	m.vida = 1.0e6
	m.atordoa_t = 99999.0
	m.emp_mult = 0.0
	m.cacador = false
	return m


func tirado(m) -> float:
	return m.vida_max - m.vida


## Tira o boneco de cena (volta ao pool, como se tivesse morrido).
func descartar(m) -> void:
	m.esconder()
	w.devolver_monstro(m)


## Segura o clique num boneco e mede quanto dura um combo inteiro de verdade (do começo de um passo 0 ao do seguinte), em s, com o mundo andando
## em passos de `dt`. Usa a média de dois ciclos, depois de um de aquecimento. Sem crítico nem variação (quem chama põe a chance em -5).
func _ciclo_medido(dt: float) -> float:
	var h = w.heroi
	h.definir_pos(h.pos)
	h.estado = Heroi.Estado.LIVRE
	h.proximo = 0
	h.combo_t = 0.0
	h.pausa_t = 0.0
	var m = boneco(30.0)
	h.ataque_forcado = true
	var inicios: Array = []
	var acertos_em: Array = []
	var t := 0.0
	var golpes_antes: int = h.golpes
	for i in roundi(10.0 / dt):
		w.avancar(dt)
		t += dt
		m.vida = m.vida_max
		m.definir_pos(h.pos + Vector2(30, 0))  # o herói avança a cada golpe: o boneco (e o ponto do mouse) acompanham, para todo passo acertar
		w.mouse_forcado = h.centro() + Vector2(100, 0)
		if h.golpes != golpes_antes:
			golpes_antes = h.golpes
			if h.golpe_i == 0:
				inicios.append(t)
				acertos_em.append(w.combate.acertos)
		if inicios.size() >= 4:
			break
	h.ataque_forcado = null
	h.estado = Heroi.Estado.LIVRE
	h.proximo = 0
	h.combo_t = 0.0
	h.pausa_t = 0.0
	descartar(m)
	ok(inicios.size() >= 4, "o herói completou três combos segurando o clique (%d inícios de combo)" % inicios.size())
	if inicios.size() < 4:
		return 0.0
	ok(
		int(acertos_em[3]) - int(acertos_em[1]) == 6,
		"cada passo do combo acertou o boneco (hit-stop de cada um): %d acertos em 2 combos" % (int(acertos_em[3]) - int(acertos_em[1]))
	)
	return (float(inicios[3]) - float(inicios[1])) / 2.0


## O "Combo completo" do card é o ciclo que o herói leva de verdade: confere contra a medição a 60 quadros por segundo (margem de 5%) e o mesmo
## cálculo em outros quadros (120 e 240 por segundo, margem de 3%).
func _confere_ciclo(rotulo: String) -> void:
	var c = w.combate
	var card := float(n_de("katana.combo")[0])
	perto(card, c.ciclo_do_combo(), 0.0001, "%s: o card mostra o ciclo do combate" % rotulo)
	var m60 := _ciclo_medido(PASSO)
	perto(
		card,
		m60,
		m60 * 0.05,
		"%s: o combo do card (%.3f s) é o ciclo medido a 60 quadros por segundo segurando o clique num boneco (%.3f s, margem de 5%%)" % [rotulo, card, m60]
	)
	var texto := "  combo %s: card %.3f s, medido %.3f s (60 Hz)" % [rotulo, card, m60]
	for dt in [1.0 / 120.0, PASSO_FINO]:
		var med := _ciclo_medido(dt)
		var modelo: float = c.ciclo_do_combo(dt)
		perto(
			modelo,
			med,
			med * 0.03,
			"%s: o mesmo cálculo a %.0f quadros por segundo (%.3f s) bate com a medição (%.3f s, margem de 3%%)" % [rotulo, 1.0 / dt, modelo, med]
		)
		texto += "; %.3f s contra %.3f s (%.0f Hz)" % [modelo, med, 1.0 / dt]
	print(texto)


## Os textos de uma lista de trechos ([[texto, estilo], ...]).
func _textos(trechos: Array) -> Array:
	var r: Array = []
	for t in trechos:
		r.append(str(t[0]))
	return r


## Deixa passar alguns quadros do jogo de verdade (a entrada de Input.parse_input_event só chega no quadro seguinte).
func esperar(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


## Pega a carta `id` na raridade `rar` e aplica (como a escolha faz).
func pegar(id: String, rar := 0) -> Dictionary:
	var cs = w.combate.cartas
	var c: Dictionary = cs.montar_carta(cs.definicao(id), rar)
	cs.aplicar(c)
	return c


func secoes() -> Array:
	return Status.coletar(w)


func lin(id: String) -> Dictionary:
	return Status.linha(secoes(), id)


func n_de(id: String) -> Array:
	var l := lin(id)
	ok(not l.is_empty(), "linha %s existe no card" % id)
	return l.get("n", [])


func tecla(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	Input.parse_input_event(e)  # a entrada de verdade: Window -> árvore -> mundo._input (o SubViewport não recebe isto)


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	Config.arquivo = OPCOES_TESTE
	_limpar_saves()
	var md5_real := _md5(SAVE_REAL) + _md5(OPCOES_REAL)
	_santuario()
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	if pasta != "":
		await _fotos(pasta)
	else:
		_estrutura()
		_heroi()
		_katana()
		_combo_veloz()
		_percentuais()
		_golpes()
		_modificadores()
		_partida()
		await _interface()
		ok(md5_real == _md5(SAVE_REAL) + _md5(OPCOES_REAL), "o save real e as opções reais não foram tocados")
	_limpar_saves()
	Config.arquivo = OPCOES_REAL
	get_tree().paused = false
	print("v2_status falhas=%d" % falhas)
	get_tree().quit()


func _limpar_saves() -> void:
	for c in [SAVE_TESTE, SAVE_TESTE + ".bak", SAVE_TESTE + ".tmp", OPCOES_TESTE]:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))


func _md5(caminho: String) -> String:
	return FileAccess.get_md5(caminho) if FileAccess.file_exists(caminho) else ""


## Compra melhorias no save temporário: vida 2, dano 2, velocidade 1, fôlego 1, ímã 1, treino 1 (precisa da conquista de 5 min), raridade 1, rolagem 1,
## almas 2 (+16% de almas por partida).
func _santuario() -> void:
	Meta.registrar_partida({"tempo": 400.0, "abates": 0, "nivel": 1, "maior_combo": 0, "venceu": false, "almas": 5000})
	for par in [["vida", 2], ["dano", 2], ["velocidade", 1], ["folego", 1], ["ima", 1], ["treino", 1], ["raridade", 1], ["rolagem", 1], ["almas", 2]]:
		for i in int(par[1]):
			ok(Meta.comprar(str(par[0])), "comprou %s no Santuário de teste" % par[0])


# ------------------------------------------------------------------ estrutura


func _estrutura() -> void:
	zerar()
	var secs := secoes()
	var ids: Array = []
	for s in secs:
		ids.append(str(s.id))
	ok(ids == ["heroi", "katana", "golpes", "partida", "santuario"], "as seções do card: herói, katana, golpes, partida, santuário (%s)" % str(ids))
	for s in secs:
		ok(str(s.titulo) != "" and not s.linhas.is_empty(), "a seção %s tem título e linhas" % s.id)
		for l in s.linhas:
			ok(
				str(l.get("id", "")) != "" and l.has("n") and str(l.get("tipo", "")) != "",
				"toda linha tem id, tipo e números crus (%s)" % str(l.get("id", "?"))
			)
	ok(Status.coletar(null).is_empty(), "sem mundo, coletar devolve vazio")
	ok(w.status != null and w.status is CanvasLayer, "o mundo guarda o card em mundo.status")
	ok(not w.status.visible and w.status._timer.is_stopped() and not w.status.is_processing(), "o card nasce escondido e sem rodar nada")
	ok(not lin("arma.nenhum").is_empty(), "sem golpe automático, o card diz que eles vêm pelas cartas")
	ok(
		lin("santuario.vida").get("texto", "") == "+20 de vida inicial",
		"o Santuário aparece com o texto de meta.gd (%s)" % lin("santuario.vida").get("texto", "")
	)


# ------------------------------------------------------------------ herói


func _heroi() -> void:
	zerar()
	var h = w.heroi
	var cfg: Dictionary = w.combate.cfg
	# bônus do Santuário: o card mostra e o jogo aplicou (vida 100 + 2x10, dano +2x6%, andar +4%, fôlego 3 + 0,5, ímã +15%, ataque +5%)
	perto(float(n_de("heroi.vida")[1]), 100.0 + 20.0, 0.001, "vida máxima = base + Santuário")
	perto(float(n_de("santuario.vida")[0]), 20.0, 0.001, "o Santuário diz +20 de vida e o herói tem +20")
	perto(float(n_de("santuario.dano")[0]), 12.0, 0.001, "o Santuário diz +12% de dano")
	perto(h.m_dano, 1.12, 0.001, "o dano do herói tem os +12% do Santuário")
	perto(float(n_de("heroi.folego")[0]), 3.5, 0.001, "fôlego 3 + 0,5 do Santuário")
	perto(float(n_de("heroi.andar")[0]), 100.0 * 1.04, 0.01, "andar 100 + 4% do Santuário")
	ok(lin("heroi.vida").bonus == "+20", "o bônus da vida aparece à parte (%s)" % lin("heroi.vida").bonus)
	ok(lin("heroi.andar").bonus == "+4%", "o bônus de andar aparece à parte (%s)" % lin("heroi.andar").bonus)
	# cartas de stat (raridade 1 = x1,5): vida +30, andar +12%, ímã +52,5%
	pegar("vida", 1)
	pegar("vel_mov", 1)
	pegar("ima", 1)
	perto(h.vida_max, 150.0, 0.001, "vida máxima: 100 + 20 do Santuário + 30 da carta")
	var v := n_de("heroi.vida")
	perto(float(v[1]), h.vida_max, 0.001, "o card mostra a vida máxima do herói")
	# vida: levar dano
	h.imortal = false
	h.invenc = 0.0
	var antes: float = h.vida
	h.levar_dano(10.0, h.pos + Vector2(20, 0))
	h.imortal = true
	h.emp = Vector2.ZERO  # sem o empurrão do dano na medição de velocidade
	h.invenc = 0.0
	perto(float(n_de("heroi.vida")[0]), antes - 10.0, 0.001, "a vida do card cai com o dano que o herói leva")
	# cura por nível: o card diz quanto volta; subir de nível cura exatamente isso
	var cura := float(n_de("heroi.cura")[0])
	perto(cura, h.vida_max * float(cfg.heroi.cura_nivel), 0.001, "cura por nível = fração da vida máxima")
	h.vida = 20.0
	w.combate.progresso.ganhar_xp(h.xp_proximo)
	w.combate.lento_t = 0.0  # não abre a escolha
	w.combate.lento_acao = ""
	w.combate.progresso.pendentes = 0
	perto(h.vida, 20.0 + cura, 0.01, "subir de nível cura o que o card anunciou")
	ok(int(n_de("heroi.nivel")[0]) == 2, "o card mostra o nível 2 depois de subir")
	# velocidade de andar e de correr: mede o deslocamento
	w.combate.parada_t = 0.0  # sem o hit-stop do dano que o herói levou
	h.vida = h.vida_max
	h.entrada_forcada = Vector2.RIGHT
	h.correr_forcado = false
	var x0: float = h.pos.x
	passos(30)
	var andou: float = (h.pos.x - x0) / (30.0 * PASSO)
	perto(float(n_de("heroi.andar")[0]), andou, 1.0, "a velocidade de andar do card é a que o herói anda (px/s)")
	h.correr_forcado = true
	h.folego = h.folego_max
	x0 = h.pos.x
	passos(30)
	var correu: float = (h.pos.x - x0) / (30.0 * PASSO)
	perto(float(n_de("heroi.correr")[0]), correu, 1.0, "a velocidade de correr do card é a que o herói corre (px/s)")
	ok(h.correndo, "o herói estava mesmo correndo")
	# recuperação do fôlego: parado e andando (depois do atraso de 0,6 s)
	h.correr_forcado = false
	h.entrada_forcada = Vector2.ZERO
	h.folego = 1.0
	h._atraso_t = 0.0
	passos(60)
	perto(float(n_de("heroi.recupera")[0]), h.folego - 1.0, 0.02, "o fôlego volta à taxa do card, parado (por s)")
	h.entrada_forcada = Vector2.LEFT
	h.folego = 1.0
	h._atraso_t = 0.0
	passos(60)
	perto(float(n_de("heroi.recupera_andando")[0]), h.folego - 1.0, 0.02, "o fôlego volta à taxa do card, andando (por s)")
	h.entrada_forcada = Vector2.ZERO
	# parado MAS golpeando: o golpe tira o herói do estado livre, então vale a taxa lenta ("em ação"), não a de parado (0,9/s). Mede pelo
	# relógio do mundo (o hit-stop não conta); o herói só volta a ser "livre e parado" no fim de cada combo, daí um pouco acima da lenta.
	var alvo_fo = boneco(30.0)
	h.ataque_forcado = true
	h.folego = 1.0
	h._atraso_t = 0.0
	var t_fo: float = w.tempo_partida
	passos(180)
	h.ataque_forcado = null
	var taxa_golpeando: float = (h.folego - 1.0) / (w.tempo_partida - t_fo)
	var taxa_acao := float(n_de("heroi.recupera_andando")[0])
	var taxa_parado := float(n_de("heroi.recupera")[0])
	print("  recupera golpeando parado: %.3f/s (card: parado %.2f, em ação %.2f)" % [taxa_golpeando, taxa_parado, taxa_acao])
	ok(
		taxa_golpeando >= taxa_acao * 0.9 and taxa_golpeando <= taxa_acao + 0.15,
		"golpeando parado o fôlego volta perto da taxa 'em ação' do card (%.3f contra %.2f)" % [taxa_golpeando, taxa_acao]
	)
	ok(taxa_golpeando < taxa_parado - 0.2, "golpeando parado o fôlego NÃO volta à taxa de parado (%.3f contra %.2f)" % [taxa_golpeando, taxa_parado])
	ok(
		lin("heroi.recupera_andando").rotulo != lin("heroi.recupera").rotulo and "ação" in str(lin("heroi.recupera_andando").rotulo),
		"o card nomeia a taxa lenta como 'em ação'"
	)
	h.estado = Heroi.Estado.LIVRE
	descartar(alvo_fo)
	# ímã: um orbe um pouco dentro do alcance é atraído, um pouco fora fica no chão
	var ima := float(n_de("heroi.ima")[0])
	perto(ima, 56.0 * h.m_ima, 0.01, "ímã = raio dos dados x bônus de ímã")
	var alvo: Vector2 = h.pos + Vector2(0, -8)
	var o = w.combate.orbes
	var dentro := _orbe(alvo + Vector2(ima - 3.0, 0))
	var fora := _orbe(alvo + Vector2(ima + 5.0, 0))
	passos(1)
	ok(o.estado[dentro] == 2, "o orbe 3 px dentro do ímã do card é puxado")
	ok(o.estado[fora] == 1, "o orbe 5 px fora do ímã do card fica no chão")
	o.limpar()
	# esquiva: quantas seguidas o fôlego aguenta, e quanto tempo sem dano
	h.folego = h.folego_max
	h.cansado = false
	var esq := n_de("heroi.esquiva")
	var feitas := 0
	for i in 8:
		if not h.pode_esquivar():
			break
		h.esquivar()
		var guarda := 0
		while h.estado == Heroi.Estado.LIVRE and guarda < 10:
			passos(1)
			guarda += 1
		while h.estado == Heroi.Estado.ESQUIVA:
			passos(1)
		feitas += 1
	ok(feitas == int(esq[0]), "as esquivas seguidas do card (%d) são as que o fôlego dá (%d)" % [int(esq[0]), feitas])
	h.folego = h.folego_max
	h.imortal = false
	h.invenc = 0.0
	h.esquivar()
	passos(1)
	var imune := 0
	while h.estado == Heroi.Estado.ESQUIVA and not h.vulneravel():
		imune += 1
		passos(1)
	h.imortal = true
	perto(float(n_de("heroi.imune")[0]), float(imune) * PASSO, PASSO * 1.5, "o tempo imune da esquiva do card é o do jogo (s)")
	while h.estado == Heroi.Estado.ESQUIVA:
		passos(1)


## Põe um orbe parado no chão na posição p e devolve o índice dele (o que acabou de nascer).
func _orbe(p: Vector2) -> int:
	var o = w.combate.orbes
	var antes: PackedByteArray = o.estado.duplicate()
	o.soltar(p, 1.0)
	for i in o.estado.size():
		if antes[i] == 0 and o.estado[i] == 1:
			o.pos[i] = p
			o.z[i] = 0.0
			o.zv[i] = 0.0
			o.vel[i] = Vector2.ZERO
			return i
	return -1


# ------------------------------------------------------------------ katana


func _katana() -> void:
	zerar()
	var h = w.heroi
	var c = w.combate
	var cfg: Dictionary = c.cfg
	var passos_cfg: Array = cfg.golpe.passos
	pegar("dano", 1)  # +22,5%
	pegar("vel_ataque", 1)  # +18%
	pegar("area", 1)  # +18%
	pegar("critico", 1)  # +7,5%
	var dano_esp: Array = []
	for p in passos_cfg:
		dano_esp.append(float(p.dano) * (1.0 + 0.12 + 0.225))
	var ndano := n_de("katana.dano")
	for i in 3:
		perto(float(ndano[i]), float(dano_esp[i]), 0.001, "dano do passo %d do card = dado x (1 + Santuário + carta)" % i)
	var var_antes: float = cfg.golpe.variacao
	var crit_antes: float = cfg.golpe.critico.chance
	cfg.golpe.variacao = 0.0
	cfg.golpe.critico.chance = -5.0
	# velocidade de ataque: um golpe no vazio (sem hit-stop) dura a duração dos dados / velocidade; conta os quadros
	h.atacar()
	var inicio_golpe := -1
	var duracao_medida := 0.0
	for f in 60:
		passos(1)
		if inicio_golpe < 0 and h.estado == Heroi.Estado.GOLPE:
			inicio_golpe = f
		elif inicio_golpe >= 0 and h.estado != Heroi.Estado.GOLPE:
			duracao_medida = float(f - inicio_golpe) * PASSO
			break
	passos(40)  # o combo reinicia
	ok(h.estado == Heroi.Estado.LIVRE and h.proximo == 0, "o combo voltou ao começo")
	# o combo de verdade: segura o ataque e lê o dano de cada acerto no boneco (sem sorteio de variação nem crítico)
	var m = boneco(30.0)
	h.ataque_forcado = true
	var drops: Array = []
	var vida_ant: float = m.vida
	var f2 := 0
	while drops.size() < 3 and f2 < 200:
		passos(1)
		f2 += 1
		if m.vida < vida_ant:
			drops.append(vida_ant - m.vida)
			vida_ant = m.vida
	h.ataque_forcado = null
	h.estado = Heroi.Estado.LIVRE
	ok(drops.size() == 3, "o combo acertou 3 vezes (%d)" % drops.size())
	for i in mini(3, drops.size()):
		perto(float(roundi(float(ndano[i]))), float(drops[i]), 0.001, "o acerto %d do combo tira o dano do card (arredondado)" % i)
	# velocidade de ataque: a duração do primeiro passo medida em quadros é a dos dados / velocidade
	perto(duracao_medida, float(passos_cfg[0].duracao) / (1.0 + 0.05 + 0.18), PASSO * 1.6, "o golpe dura a duração dos dados / (1 + treino + carta)")
	perto(float(n_de("katana.vel")[0]), 1.23, 0.001, "a velocidade de ataque do card é 1 + 5% do Santuário + 18% da carta")
	# combo completo: o ciclo REAL (passos com a velocidade + hit-stop de cada acerto + a pausa do fim do combo, que não acelera), nos quadros
	# de 60 Hz: segurando o clique num boneco, o herói leva isso (e não a soma das durações dos passos)
	descartar(m)
	var soma_passos := 0.0
	for p in passos_cfg:
		soma_passos += float(p.duracao) / 1.23
	ok(
		float(n_de("katana.combo")[0]) > soma_passos + 0.3,
		"o combo do card passa muito da soma das durações (%.2f contra %.2f)" % [float(n_de("katana.combo")[0]), soma_passos]
	)
	_confere_ciclo("x1,23")
	cfg.golpe.critico.chance = crit_antes
	# alcance de cada passo: o card mostra o alcance EFETIVO = o da área + o avanço (lunge) do golpe. Primeiro o alcance parado (um boneco logo
	# dentro é atingido, logo fora não), depois o golpe inteiro com o avanço.
	var alc := n_de("katana.alcance")
	var origem: Vector2 = h.pos + h.ORIGEM_GOLPE
	for i in 3:
		var alcance := float(alc[i]) - float(passos_cfg[i].avanco)
		perto(float(alc[i]), float(passos_cfg[i].alcance) * 1.18 + float(passos_cfg[i].avanco), 0.001, "alcance do passo %d do card = dado x área + avanço" % i)
		var a = boneco(100.0)
		var b = boneco(100.0)
		var raio: float = a.raio
		# o jogo compara a distância do tronco (origem do golpe) ao boneco, com 6 px de altura de diferença: 4 px abaixo da origem
		a.definir_pos(h.pos + Vector2(sqrt(pow(alcance + raio - 0.4, 2.0) - 16.0), 0.0))
		b.definir_pos(h.pos + Vector2(sqrt(pow(alcance + raio + 0.4, 2.0) - 16.0), 0.0))
		c.golpear(h, origem, Vector2.RIGHT, passos_cfg[i], i)
		ok(tirado(a) > 0.0, "o passo %d acerta o boneco 0,4 px dentro do alcance do card" % i)
		ok(tirado(b) == 0.0, "o passo %d não acerta o boneco 0,4 px fora do alcance do card" % i)
		descartar(a)
		descartar(b)
	# o golpe de verdade, com o avanço: segura o golpe do passo i num boneco logo dentro do alcance do card (acerta) e logo fora (não acerta)
	cfg.golpe.critico.chance = -5.0
	var pos0: Vector2 = h.pos
	for i in 3:
		var efetivo := float(alc[i])
		for lado in [-4.0, 8.0]:
			h.definir_pos(pos0)
			h.estado = Heroi.Estado.LIVRE
			h.pausa_t = 0.0
			h.proximo = i
			h.combo_t = 1.0
			var bo = boneco(100.0)
			bo.definir_pos(pos0 + Vector2(sqrt(pow(efetivo + float(bo.raio) + float(lado), 2.0) - 16.0), 0.0))
			h.atacar()
			for k in roundi(0.6 / PASSO_FINO):
				w.avancar(PASSO_FINO)
			var acertou: bool = tirado(bo) > 0.0
			ok(
				acertou == (float(lado) < 0.0),
				(
					"o passo %d %s o boneco a %.0f px do herói (alcance do card %.0f px, com o avanço)"
					% [i, "acerta" if acertou else "não acerta", efetivo + float(lado), efetivo]
				)
			)
			descartar(bo)
			h.estado = Heroi.Estado.LIVRE
	h.definir_pos(pos0)
	h.proximo = 0
	h.combo_t = 0.0
	h.pausa_t = 0.0
	cfg.golpe.critico.chance = crit_antes
	perto(float(n_de("katana.area")[0]), 1.18, 0.001, "a área do card é a do herói")
	# crítico: a chance do card é a que o jogo sorteia, e o multiplicador dobra o dano
	var chance := float(n_de("katana.critico")[0])
	perto(chance, 0.10 + 0.075, 0.0001, "crítico do card = 10% dos dados + 7,5% da carta")
	var alvo = boneco(30.0)
	seed(2026)
	var tiros := 1500
	var cr0: int = c.criticos
	var ac0: int = c.acertos
	for i in tiros:
		c.golpear(h, origem, Vector2.RIGHT, passos_cfg[0], 0)
		alvo.vida = alvo.vida_max
	var taxa := float(c.criticos - cr0) / float(c.acertos - ac0)
	perto(chance, taxa, 0.035, "a taxa de crítico sorteada pelo jogo bate com a chance do card")
	cfg.golpe.critico.chance = 5.0
	alvo.vida = alvo.vida_max
	c.golpear(h, origem, Vector2.RIGHT, passos_cfg[0], 0)
	perto(float(roundi(float(ndano[0]) * float(n_de("katana.critico")[1]))), tirado(alvo), 0.001, "o crítico tira o dano do card x o multiplicador do card")
	cfg.golpe.critico.chance = crit_antes
	cfg.golpe.variacao = var_antes
	descartar(alvo)


# ------------------------------------------------------------------ combo veloz


## Com a velocidade de ataque alta (x2 ou mais) os passos ficam curtos e o hit-stop e a pausa do fim do combo pesam mais: era aí que o card
## errava mais (mostrava 0,41 s e o jogo levava 0,83 s). O número do card tem de seguir o ciclo medido.
func _combo_veloz() -> void:
	zerar()
	var h = w.heroi
	var cfg: Dictionary = w.combate.cfg
	var var_antes: float = cfg.golpe.variacao
	var crit_antes: float = cfg.golpe.critico.chance
	cfg.golpe.variacao = 0.0
	cfg.golpe.critico.chance = -5.0
	for i in 3:
		pegar("vel_ataque", 3)  # lendária: +38,4% cada
	ok(h.m_vel_ataque > 2.0, "a velocidade de ataque passou de x2 (x%.2f)" % h.m_vel_ataque)
	var soma := 0.0
	for i in 3:
		soma += h.duracao_do_passo(i)
	ok(
		float(n_de("katana.combo")[0]) > soma + 0.3,
		"o card soma o hit-stop e a pausa do fim do combo (%.3f s contra só os passos, %.3f s)" % [float(n_de("katana.combo")[0]), soma]
	)
	_confere_ciclo("x%.2f" % h.m_vel_ataque)
	cfg.golpe.variacao = var_antes
	cfg.golpe.critico.chance = crit_antes


# ------------------------------------------------------------------ percentuais


## O crítico para em 100% (o jogo sorteia `randf() < chance`: acima disso todo acerto já é crítico) e os percentuais mostram uma casa decimal
## quando precisam (17,5%, não 18%).
func _percentuais() -> void:
	zerar()
	var c = w.combate
	var h = w.heroi
	var cfg: Dictionary = c.cfg
	var var_antes: float = cfg.golpe.variacao
	for i in 8:
		pegar("critico", 3)  # lendária: x3,2 de 5% = 16% por carta
	ok(c.chance_critico() > 1.3, "o jogo soma mais de 100%% de crítico com 8 cartas lendárias (%.3f)" % c.chance_critico())
	var cr := n_de("katana.critico")
	perto(float(cr[0]), 1.0, 0.0001, "o card limita a chance de crítico a 100%")
	ok(str(lin("katana.critico").valor).begins_with("100%"), "o card mostra 100%%, não %.0f%% (%s)" % [c.chance_critico() * 100.0, lin("katana.critico").valor])
	var m = boneco(30.0)
	var origem: Vector2 = h.pos + h.ORIGEM_GOLPE
	var cr0: int = c.criticos
	var ac0: int = c.acertos
	seed(77)
	for i in 120:
		c.golpear(h, origem, Vector2.RIGHT, cfg.golpe.passos[0], 0)
		m.vida = m.vida_max
	ok(c.acertos - ac0 == 120 and c.criticos - cr0 == 120, "com mais de 100%% todo acerto é crítico (%d de %d)" % [c.criticos - cr0, c.acertos - ac0])
	descartar(m)
	cfg.golpe.variacao = var_antes
	# uma casa decimal quando precisa: crítico raro = 7,5% (10% + 7,5% = 17,5%); ímã raro = +52,5% (+15% do Santuário = +67,5%)
	zerar()
	pegar("critico", 1)
	pegar("ima", 1)
	ok(
		lin("katana.critico").valor.begins_with("17,5%") and lin("katana.critico").bonus == "+7,5%",
		"o crítico mostra 17,5%%, não 18%% (%s %s)" % [lin("katana.critico").valor, lin("katana.critico").bonus]
	)
	ok(lin("heroi.ima").bonus == "+67,5%", "o ímã mostra +67,5%%, não +67%% nem +68%% (%s)" % lin("heroi.ima").bonus)
	ok(
		lin("heroi.andar").bonus == "+4%" and lin("katana.dano").bonus == "+12%",
		"os percentuais inteiros seguem sem casa decimal (%s, %s)" % [lin("heroi.andar").bonus, lin("katana.dano").bonus]
	)
	pegar("dano", 1)
	ok(lin("katana.dano").bonus == "+34,5%", "o dano raro (22,5%% + 12%% do Santuário) mostra +34,5%% (%s)" % lin("katana.dano").bonus)


# ------------------------------------------------------------------ golpes automáticos


## Anda `seg` segundos e devolve a lista de quedas de vida do boneco (uma por quadro em que ele apanhou), com o quadro.
func _quedas(m, seg: float) -> Array:
	var r: Array = []
	var antes: float = m.vida
	for i in roundi(seg / PASSO):
		passos(1)
		if m.vida < antes:
			r.append({"queda": antes - m.vida, "quadro": i})
			antes = m.vida
	return r


func _soma(q: Array) -> float:
	var s := 0.0
	for e in q:
		s += float(e.queda)
	return s


func _golpes() -> void:
	var cs = w.combate.cartas
	# --- aura de fogo (nível 3, carta rara na primeira)
	zerar()
	pegar("aura_fogo", 1)
	pegar("aura_fogo")
	pegar("aura_fogo")
	var l := lin("arma.aura_fogo")
	ok(
		l.get("rotulo", "") == "Aura de Fogo" and l.get("nivel_txt", "") == "nv 3/5",
		"a aura aparece com nome e nível (%s %s)" % [l.get("rotulo", ""), l.get("nivel_txt", "")]
	)
	ok(l.get("icone", "") == "icone_brasa_viva", "a aura mostra o ícone dela (campo icone de v2_cartas.json)")
	ok(
		str(l.get("dica", "")).contains("Lâminas Rodopiantes nv 3") and str(l.get("dica", "")).contains("Anel de Brasas"),
		"a aura diz o que falta para evoluir (%s)" % l.get("dica", "")
	)
	var n := n_de("arma.aura_fogo")
	var m = boneco(20.0)
	var q := _quedas(m, 6.0)
	ok(
		not q.is_empty() and float(q[0].queda) == float(n[0]),
		"o primeiro tique da aura tira o dano por acerto do card (%.0f contra %.0f)" % [float(q[0].queda) if not q.is_empty() else -1.0, float(n[0])]
	)
	faixa(float(n[2]) * 6.0, _soma(q), 0.88, 1.08, "aura: dano por segundo do card x 6 s (o primeiro tique só sai aos 0,3 s)")
	# --- lâminas (nível 3)
	zerar()
	pegar("laminas", 1)
	pegar("laminas")
	pegar("laminas")
	n = n_de("arma.laminas")
	m = boneco(25.0)
	q = _quedas(m, 8.0)
	ok(not q.is_empty() and float(q[0].queda) == float(n[0]), "a primeira passada de lâmina tira o dano por acerto do card")
	faixa(float(n[2]) * 8.0, _soma(q), 0.85, 1.2, "lâminas: dano por segundo do card x 8 s (depende de onde a lâmina passa)")
	# --- raio em cadeia (nível 3): três bonecos juntos, a cadeia pega os três
	zerar()
	pegar("raio", 1)  # nível 1: um raio por vez, com salto para os vizinhos
	n = n_de("arma.raio")
	var b1 = boneco(70.0)
	var b2 = boneco(70.0, 30.0)
	var b3 = boneco(70.0, -30.0)
	var bonecos := [b1, b2, b3]
	var antes := [b1.vida, b2.vida, b3.vida]
	var casts: Array = []
	var maior_queda := 0.0
	var total := 0.0
	for i in roundi(20.0 / PASSO):
		passos(1)
		var algum := false
		for k in 3:
			var d: float = antes[k] - bonecos[k].vida
			if d > 0.0:
				algum = true
				maior_queda = maxf(maior_queda, d)
				total += d
				antes[k] = bonecos[k].vida
		if algum:
			if casts.is_empty() or i - int(casts[casts.size() - 1]) > 20:
				casts.append(i)
	ok(maior_queda == float(n[0]), "o raio tira o dano por acerto do card no primeiro alvo (%.0f contra %.0f)" % [maior_queda, float(n[0])])
	if casts.size() >= 3:
		var intervalo_medido: float = float(int(casts[casts.size() - 1]) - int(casts[0])) * PASSO / float(casts.size() - 1)
		perto(float(n[1]), intervalo_medido, PASSO * 2.5, "o intervalo entre raios do card é o do jogo (s)")
	else:
		ok(false, "caíram raios suficientes para medir o intervalo (%d)" % casts.size())
	faixa(float(n[2]) * 20.0, total, 0.9, 1.15, "raio: dano por segundo do card x 20 s (a cadeia pega os 3 bonecos)")
	# --- corvos (nível 3): dano exato por bicada e dano por segundo na faixa
	zerar()
	pegar("corvos", 1)
	pegar("corvos")
	pegar("corvos")
	n = n_de("arma.corvos")
	m = boneco(60.0)
	q = _quedas(m, 20.0)
	var menor := 1.0e9
	for e in q:
		menor = minf(menor, float(e.queda))
	ok(not q.is_empty() and menor == float(n[0]), "a bicada do corvo tira o dano por acerto do card (%.0f contra %.0f)" % [menor, float(n[0])])
	faixa(float(n[2]) * 20.0, _soma(q), 0.8, 1.1, "corvos: dano por segundo do card x 20 s (os corvos levam um tempo para chegar)")
	# --- runa (nível 3): dano exato por explosão
	zerar()
	pegar("runa", 1)
	pegar("runa")
	pegar("runa")
	n = n_de("arma.runa")
	m = boneco(30.0)
	q = _quedas(m, 30.0)
	menor = 1.0e9
	for e in q:
		menor = minf(menor, float(e.queda))
	ok(not q.is_empty() and menor == float(n[0]), "a explosão da runa tira o dano por acerto do card (%.0f contra %.0f)" % [menor, float(n[0])])
	faixa(float(n[2]) * 30.0, _soma(q), 0.8, 1.3, "runa: dano por segundo do card x 30 s (o card já conta só as runas que nascem sobre o monstro)")
	# --- evolução: aura nv 3 + lâminas nv 3 viram o Anel de Brasas
	zerar()
	pegar("aura_fogo", 1)
	pegar("aura_fogo")
	pegar("aura_fogo")
	pegar("laminas")
	pegar("laminas")
	var ld := lin("arma.laminas")
	ok(
		str(ld.get("dica", "")).contains("falta Lâminas Rodopiantes nv 3"),
		"com a aura no 3 e as lâminas no 2, o card diz que falta só as lâminas no 3 (%s)" % ld.get("dica", "")
	)
	pegar("laminas")
	ok(cs.evoluidas.has("anel_de_brasas"), "as duas peças no nível 3 evoluem para o Anel de Brasas")
	ok(lin("arma.aura_fogo").is_empty() and lin("arma.laminas").is_empty(), "as peças somem do card quando evoluem")
	var anel := lin("arma.anel_de_brasas")
	ok(anel.get("rotulo", "") == "Anel de Brasas" and anel.get("nivel_txt", "") == "evoluída", "o Anel de Brasas aparece como evoluída")
	ok(anel.get("icone", "") == "icone_brasa_viva" and str(anel.get("dica", "")) == "", "o Anel de Brasas tem ícone e não tem dica de evolução")
	n = anel.n
	m = boneco(25.0)
	q = _quedas(m, 6.0)
	faixa(float(n[2]) * 6.0, _soma(q), 0.9, 1.1, "Anel de Brasas: dano por segundo do card x 6 s (lâminas + aura + fogo)")
	# --- Revoada de Trovões (corvos nv 3 + raio nv 3) e Círculo Rúnico (runa nv 3 + crítico explosivo nv 2): o "poder" é uma estimativa POR MONSTRO
	# (supõe todos os corvos mordendo; o arco elétrico só solta com vizinho e fica de fora; o círculo explode em área e o card conta um monstro
	# só). A faixa é mais larga embaixo que em cima: a simulação num boneco só não passa do que o card anuncia
	zerar()
	for id in ["corvos", "raio"]:
		pegar(id, 1)
		pegar(id)
		pegar(id)
	ok(cs.evoluidas.has("revoada_de_trovoes"), "corvos nv 3 + raio nv 3 evoluem para a Revoada de Trovões")
	n = n_de("arma.revoada_de_trovoes")
	m = boneco(60.0)
	q = _quedas(m, 20.0)
	faixa(float(n[2]) * 20.0, _soma(q), 0.5, 1.1, "Revoada de Trovões: dano por segundo do card x 20 s (um boneco só, sem vizinho para o arco elétrico)")
	zerar()
	pegar("runa", 1)
	pegar("runa")
	pegar("runa")
	pegar("explode")
	pegar("explode")
	ok(cs.evoluidas.has("circulo_runico"), "runa nv 3 + crítico explosivo nv 2 evoluem para o Círculo Rúnico")
	n = n_de("arma.circulo_runico")
	m = boneco(30.0)
	q = _quedas(m, 30.0)
	faixa(float(n[2]) * 30.0, _soma(q), 0.5, 1.15, "Círculo Rúnico: dano por segundo do card x 30 s (um boneco só: a explosão em área bate em todos em volta)")
	# --- dicas que não mentem: peça banida (evolução impossível), banida mas já no nível (continua possível) e peça gasta em outra evolução
	zerar()
	pegar("aura_fogo", 1)
	pegar("aura_fogo")
	pegar("aura_fogo")
	var dica_ok := str(lin("arma.aura_fogo").dica)
	ok(dica_ok == "Evolui: Anel de Brasas (falta Lâminas Rodopiantes nv 3)", "antes de banir, a dica promete a evolução (%s)" % dica_ok)
	cs.banir("laminas")
	var dica_b := str(lin("arma.aura_fogo").dica)
	ok(
		dica_b.contains("Evolução perdida") and dica_b.contains("Lâminas Rodopiantes banida") and not dica_b.contains("Evolui:"),
		"com a outra peça banida, a dica diz que a evolução está perdida (%s)" % dica_b
	)
	zerar()
	pegar("laminas", 1)
	pegar("laminas")
	pegar("laminas")
	pegar("aura_fogo")
	pegar("aura_fogo")
	cs.banir("laminas")
	ok(
		str(lin("arma.aura_fogo").dica).contains("Evolui: Anel de Brasas (falta Aura de Fogo nv 3)"),
		"banir uma peça que já está no nível pedido não perde a evolução (%s)" % lin("arma.aura_fogo").dica
	)
	cs.estado["laminas"].usada = true  # a outra peça já virou parte de outra evolução (não existe nos dados de hoje: simula)
	ok(
		str(lin("arma.aura_fogo").dica).contains("Evolução perdida") and str(lin("arma.aura_fogo").dica).contains("já evoluiu em outra"),
		"peça já gasta em outra evolução: evolução perdida (%s)" % lin("arma.aura_fogo").dica
	)
	# --- vários golpes: o card lista todos
	zerar()
	for id in ["aura_fogo", "laminas", "corvos", "raio", "runa"]:
		pegar(id)
	var ids: Array = []
	for l2 in secoes()[2].linhas:
		ids.append(str(l2.id))
	ok(ids.size() == 5, "uma build com os 5 golpes mostra os 5 no card (%s)" % str(ids))


# ------------------------------------------------------------------ modificadores da katana


func _onda_ativa() -> int:
	var ar = w.combate.armas
	for i in ar.w_dist.size():
		if ar.w_dist[i] > 0.0:
			return i
	return -1


func _modificadores() -> void:
	var c = w.combate
	var h = w.heroi
	var cfg: Dictionary = c.cfg
	var passos_cfg: Array = cfg.golpe.passos
	var origem: Vector2 = h.pos + h.ORIGEM_GOLPE
	var var_antes: float = cfg.golpe.variacao
	var crit_antes: float = cfg.golpe.critico.chance
	cfg.golpe.variacao = 0.0
	cfg.golpe.critico.chance = -5.0
	# --- onda: a onda sai em TODO corte do combo, e o card mostra o dano de cada um (o 2º corte bate mais que o 1º)
	zerar()
	pegar("onda", 1)  # 40 x 1,5 = 60%
	var onda := n_de("katana.onda")
	perto(float(onda[0]), 60.0, 0.001, "a onda do card leva 60% do corte")
	ok(onda.size() == 3, "o card guarda o dano da onda dos dois cortes do combo (%d números)" % onda.size())
	var m = boneco(30.0)
	var i := -1
	for k in 2:
		c.armas.w_dist.fill(0.0)
		c.golpear(h, origem, Vector2.RIGHT, passos_cfg[k], k)
		i = _onda_ativa()
		ok(i >= 0, "o corte %d soltou a onda" % k)
		if i >= 0 and onda.size() > 1 + k:
			perto(float(onda[1 + k]), c.armas.w_dano[i], 0.001, "o dano da onda do corte %d no card é o da onda que o jogo soltou" % k)
	ok(onda.size() == 3 and absf(float(onda[1]) - float(onda[2])) > 0.3, "os dois cortes soltam ondas de dano diferente, e o card sabe disso")
	ok("/" in "".join(_textos(lin("katana.onda").trechos)), "o card mostra o dano da onda de cada corte (%s)" % "".join(_textos(lin("katana.onda").trechos)))
	ok(lin("katana.onda").nivel_txt == "nv 1/4", "o modificador mostra o nível dele (%s)" % lin("katana.onda").nivel_txt)
	# --- o modificador segue o NOME do passo, não a posição: com o 2º passo rebatizado de estocada, o card acompanha o jogo
	zerar()
	pegar("onda", 1)
	pegar("fura", 1)
	passos_cfg[1].nome = "estocada"
	var on2 := n_de("katana.onda")
	var fu2 := n_de("katana.fura")
	ok(
		on2.size() == 2 and fu2.size() == 4,
		"um corte e duas estocadas no combo: a onda tem 1 dano e a lança 2 (%d e %d números)" % [on2.size() - 1, fu2.size() - 2]
	)
	for k in [1, 2]:
		c.armas.w_dist.fill(0.0)
		c.golpear(h, origem, Vector2.RIGHT, passos_cfg[k], k)
		var dano_l := -1.0
		for q in c.armas.w_dist.size():
			if c.armas.w_dist[q] > 0.0 and c.armas.w_tipo[q] == 1:
				dano_l = c.armas.w_dano[q]
		ok(dano_l > 0.0 and fu2.size() > 1 + k, "o passo %d (estocada) soltou a lança" % k)
		if dano_l > 0.0 and fu2.size() > 1 + k:
			perto(float(fu2[1 + k]), dano_l, 0.001, "o dano da lança do passo %d no card é o da lança que o jogo soltou" % k)
	c.armas.w_dist.fill(0.0)
	c.golpear(h, origem, Vector2.RIGHT, passos_cfg[1], 1)
	ok(_onda_ativa() >= 0 and c.armas.w_tipo[_onda_ativa()] == 1, "o passo rebatizado de estocada solta lança, não onda")
	passos_cfg[1].nome = "corte"
	# --- estocada perfurante e a Ventania (onda nv 2 + fura nv 2)
	zerar()
	pegar("onda")
	pegar("fura")
	ok(
		str(lin("katana.onda").dica).contains("Ventania Cortante") and str(lin("katana.onda").dica).contains("Estocada perfurante nv 2"),
		"a onda diz que falta a estocada no 2 para a Ventania (%s)" % lin("katana.onda").dica
	)
	pegar("onda")
	pegar("fura")
	ok(not c.armas.ventania.is_empty(), "onda nv 2 + estocada nv 2 evoluem para a Ventania Cortante")
	ok(not lin("katana.ventania").is_empty() and lin("katana.ventania").nivel_txt == "evoluída", "a Ventania aparece no card")
	ok(
		lin("katana.onda").nivel_txt == "evoluída" and lin("katana.fura").nivel_txt == "evoluída" and str(lin("katana.onda").dica) == "",
		"as peças gastas na Ventania não mostram mais um 'nv 2/4' parado nem dica (%s, %s)" % [lin("katana.onda").nivel_txt, lin("katana.fura").nivel_txt]
	)
	onda = n_de("katana.onda")
	perto(float(onda[0]), 80.0 * 1.9, 0.001, "com a Ventania a onda do card vale 80% x 1,9")
	m = boneco(30.0)
	for k in 2:
		c.armas.w_dist.fill(0.0)
		c.golpear(h, origem, Vector2.RIGHT, passos_cfg[k], k)
		i = _onda_ativa()
		ok(i >= 0, "o corte %d soltou a onda da Ventania" % k)
		if i >= 0:
			perto(float(onda[1 + k]), c.armas.w_dano[i], 0.001, "o dano da onda da Ventania no corte %d do card é o que o jogo soltou" % k)
	c.armas.w_dist.fill(0.0)
	var fura := n_de("katana.fura")
	c.golpear(h, origem, Vector2.RIGHT, passos_cfg[2], 2)
	var lancas := 0
	var dano_lanca := 0.0
	for k in c.armas.w_dist.size():
		if c.armas.w_dist[k] > 0.0 and c.armas.w_tipo[k] == 1:
			lancas += 1
			dano_lanca = c.armas.w_dano[k]
	ok(lancas == int(fura[1]) and lancas == 3, "a estocada da Ventania solta as 3 lanças do card (%d)" % lancas)
	perto(float(fura[2]), dano_lanca, 0.001, "o dano da lança do card é o da lança que o jogo soltou")
	# --- crítico explosivo: o vizinho do alvo apanha a fração do card do dano do crítico
	zerar()
	pegar("explode")
	var ex := n_de("katana.explode")
	perto(float(ex[0]), 50.0, 0.001, "o crítico explosivo do card leva 50% do dano")
	cfg.golpe.critico.chance = 5.0
	var a = boneco(40.0)
	var b = boneco(70.0)  # fora do alcance do corte (46 + 7), dentro da explosão (38) do alvo
	c.golpear(h, origem, Vector2.RIGHT, passos_cfg[0], 0)
	var dano_crit := float(roundi(c.dano_do_passo(passos_cfg[0]) * float(cfg.golpe.critico.mult)))
	perto(tirado(a), dano_crit, 0.001, "o alvo do crítico apanha o dano do crítico")
	perto(tirado(b), float(maxi(1, roundi(dano_crit * float(ex[0]) / 100.0))), 0.001, "o vizinho apanha a fração do card do dano do crítico")
	cfg.golpe.critico.chance = -5.0
	# --- fôlego de caçador: cada abate devolve a fração do card de uma carga
	zerar()
	pegar("folego")
	var fo := n_de("katana.folego")
	perto(float(fo[0]), 12.0, 0.001, "o fôlego de caçador do card devolve 12% de uma carga")
	h.folego = 1.0
	h.cansado = false
	var morrer = boneco(30.0)
	morrer.vida = 1.0
	c.golpear(h, origem, Vector2.RIGHT, passos_cfg[0], 0)
	perto(h.folego, 1.0 + float(fo[0]) / 100.0, 0.001, "matar devolve ao fôlego o que o card disse")
	cfg.golpe.variacao = var_antes
	cfg.golpe.critico.chance = crit_antes


# ------------------------------------------------------------------ partida


func _partida() -> void:
	zerar()
	var c = w.combate
	w.tempo_partida = 125.4
	w.abates = 37
	w.combo = 5
	w.maior_combo = 12
	w.xp_coletado = 574.0
	c.cartas.rerrolar_usados = 1
	c.cartas.banir_usados = 1
	c.diretor.ondas = 2
	c.diretor.proxima_onda = w.tempo_partida + 23.4
	ok(lin("partida.tempo").valor == "2:05", "o tempo do card é minutos:segundos (%s)" % lin("partida.tempo").valor)
	ok(int(n_de("partida.abates")[0]) == 37 and lin("partida.abates").valor == "37", "abates")
	ok(int(n_de("partida.combo")[0]) == 5 and int(n_de("partida.combo")[1]) == 12, "combo atual e maior combo")
	ok(int(n_de("partida.almas")[0]) == 57 and w.almas_partida == 57, "almas coletadas = XP / 10 arredondado (as do mundo)")
	# o card mostra as almas que o fim da partida CREDITA (as coletadas mais o "Almas abundantes" do Santuário, +16%), não o valor bruto
	var creditadas := int(n_de("partida.almas")[1])
	ok(
		creditadas == 66 and lin("partida.almas").valor == "66" and lin("partida.almas").bonus == "+9",
		"o card mostra as almas a receber (66, +9 do Santuário): %s %s" % [lin("partida.almas").valor, lin("partida.almas").bonus]
	)
	var saldo_antes := Meta.saldo()
	var reg := Meta.registrar_partida({"tempo": 1.0, "abates": 0, "nivel": 1, "maior_combo": 0, "venceu": false, "almas": w.almas_partida})
	ok(
		int(reg.ganhas) == creditadas and Meta.saldo() == saldo_antes + creditadas,
		"o que o card anunciou é o que Meta.registrar_partida creditou (%d contra %d)" % [creditadas, int(reg.ganhas)]
	)
	# rerrolar: 3 dos dados + 1 da "Segunda chance" do Santuário, menos 1 usado; banir: 2 dos dados, menos 1
	ok(int(n_de("partida.rerrolar")[0]) == 3 and c.cartas.rerrolares_restantes() == 3, "rerrolar restantes = 3 + 1 do Santuário - 1 usado")
	ok(int(n_de("partida.rerrolar")[1]) == 1 and c.cartas.banimentos_restantes() == 1, "banir restantes = 2 - 1 usado")
	ok(int(n_de("partida.onda")[0]) == 2 and ceili(float(n_de("partida.proxima")[0])) == 24, "onda forte atual e quanto falta para a próxima")
	ok(lin("partida.proxima").valor == "em 24 s", "a próxima onda aparece em segundos (%s)" % lin("partida.proxima").valor)
	perto(float(n_de("santuario.rolagem")[0]), 1.0, 0.001, "o Santuário mostra a rolagem extra que ele deu")
	perto(float(n_de("santuario.raridade")[0]), 4.0, 0.001, "o Santuário mostra a chance de rara que ele deu")
	perto(w.meta_bonus.raridade, 0.04, 0.0001, "o jogo aplicou a chance de rara do Santuário")
	# o card não confunde o Santuário com a build: sem compra nenhuma, diz que não há melhoria
	var vazio := Status.coletar(w, {})
	ok(Status.linha(vazio, "santuario.nenhuma").get("texto", "") == "Nenhuma melhoria comprada.", "sem compra no Santuário, o card diz isso")


# ------------------------------------------------------------------ interface


func _contar_nos() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _hud_rects() -> Array:
	var r: Array = []
	for hud in w.sv.get_children():
		if hud.has_node("Raiz/Combo"):
			for nome in ["Vida", "Folego", "Tempo", "Abates", "Combo", "Xp", "Selo"]:
				var no: Control = hud.get_node("Raiz/" + nome)
				r.append({"nome": nome, "rect": Rect2(no.position, no.size)})
		if "_quadro" in hud:
			r.append({"nome": "Minimapa", "rect": Rect2(hud._quadro.position, hud._quadro.size)})
	return r


## O CanvasLayer do HUD da partida (hud.gd, camada 10), ou null.
func _camada_hud():
	for hud in w.sv.get_children():
		if hud.has_node("Raiz/Combo"):
			return hud
	return null


func _achar_pausa():
	for no in w.sv.get_children():
		if no.has_method("abrir_sair"):
			return no
	return null


## Põe uma build cheia: os 5 golpes, os modificadores e os stats (a máxima que as cartas dão).
func _build_maxima() -> void:
	for id in ["aura_fogo", "laminas", "corvos", "raio", "runa"]:
		pegar(id, 1)
		pegar(id)
	for id in ["dano", "vel_ataque", "area", "critico", "onda", "fura", "explode", "folego"]:
		pegar(id)


## A build mais pesada que as cartas permitem sem evoluir: cada carta de stat no máximo de cópias e na raridade lendária (vida, dano e alcance
## enormes: os maiores números que o card vai mostrar), cada golpe no nível 2 e lendário, os modificadores em lendária (a onda e a estocada
## só uma vez: duas cópias de cada virariam a Ventania). Só os 5 golpes do desenho: com os 50 golpes do PR #192 a coluna não cabe,
## os 50 golpes do PR #192 ficam para o teste `_paginacao` (o card pagina, sem teto).
func _build_extrema() -> void:
	var cs = w.combate.cartas
	for d in cs.cfg.stats:
		for i in int(d.max):
			pegar(str(d.id), 3)
	var golpes := ["aura_fogo", "laminas", "corvos", "raio", "runa"]  # os 5 do desenho do card (os mesmos de _build_maxima)
	for d in cs.cfg.golpes:
		if str(d.id) in golpes:
			pegar(str(d.id), 3)
	for par in [["onda", 1], ["fura", 1], ["explode", 1], ["folego", 4]]:
		for i in int(par[1]):
			pegar(str(par[0]), 3)


## Compra tudo no Santuário do save temporário (todos os níveis de todas as melhorias).
func _comprar_tudo() -> void:
	Meta.creditar(1000000)
	for md in Meta.melhorias():
		for i in int(md.max):
			Meta.comprar(str(md.id))


func _interface() -> void:
	var st = w.status
	var c = w.combate
	var pausa = _achar_pausa()
	ok(pausa != null, "achou a pausa")
	zerar()
	# --- C liga e desliga pela entrada de verdade (mundo._input)
	ok(not st.aberto(), "começa fechado")
	tecla(KEY_C)
	await esperar()
	ok(st.aberto() and st.visible and not st._timer.is_stopped() and not st.is_processing(), "C liga o card no HUD, com o relógio de 4 Hz e sem _process")
	ok(st._modo_atual == "hud", "no jogo rolando o card é o compacto do HUD (%s)" % st._modo_atual)
	ok(st.layer < 10, "o card do HUD fica abaixo do HUD (camada %d), então a barra do chefe e os anúncios passam por cima" % st.layer)
	var vivo_antes: int = st.atualizacoes
	var q0 := Engine.get_process_frames()
	await get_tree().create_timer(1.0).timeout
	var feitas: int = st.atualizacoes - vivo_antes
	var quadros: int = Engine.get_process_frames() - q0
	ok(feitas >= 1 and feitas <= 6, "visível, o card se atualiza a ~4 Hz (%d atualizações em 1 s, %d quadros)" % [feitas, quadros])
	ok(feitas < quadros or quadros < 8, "e não a cada quadro")
	tecla(KEY_C)
	await esperar()
	ok(not st.aberto() and not st.visible and st._timer.is_stopped(), "C de novo desliga: escondido e sem rodar nada")
	var n_ant: int = st.atualizacoes
	await get_tree().create_timer(0.7).timeout
	ok(st.atualizacoes == n_ant, "escondido, o card não se atualiza")
	# --- atualizar não cria nós
	tecla(KEY_C)
	await esperar()
	var nos0 := _contar_nos()
	var filhos0: int = st.get_child_count() + st._tela.get_child_count()
	for i in 40:
		st._recoletar()
	await esperar()
	ok(_contar_nos() <= nos0 + 2, "40 atualizações não criam nó (%d antes, %d depois)" % [nos0, _contar_nos()])
	ok(st.get_child_count() + st._tela.get_child_count() == filhos0, "o card tem sempre os mesmos filhos")
	ok(st._tela.mouse_filter == Control.MOUSE_FILTER_IGNORE, "o card não pega o mouse")
	# --- o mundo continua rodando com o card aberto
	var t0: float = w.tempo_partida
	passos(10)
	ok(w.tempo_partida > t0, "com o card aberto o mundo segue rodando")
	# --- build cheia no HUD: o card compacto cabe inteiro e não cobre o HUD
	_build_maxima()
	st._recoletar()
	var rects: Array = st.retangulos()
	ok(st.linhas_que_estouram().is_empty(), "com a build cheia, nenhuma linha estoura a largura da coluna do HUD (%s)" % str(st.linhas_que_estouram()))
	ok(
		not st.colunas_cortadas().has(true),
		"com a build cheia, nada é cortado na altura das colunas do HUD (%s, alturas %s)" % [str(st.colunas_cortadas()), str(rects)]
	)
	var hud := _hud_rects()
	ok(hud.size() >= 7, "achou os retângulos do HUD e do minimapa (%d)" % hud.size())
	for rc in rects:
		ok(Rect2(0, 0, 960, 540).encloses(rc), "a coluna cabe na tela 960x540 (%s)" % str(rc))
		for e in hud:
			ok(not (rc as Rect2).intersects(e.rect), "a coluna %s não cobre %s %s" % [str(rc), e.nome, str(e.rect)])
	var direita := rects[1] as Rect2
	ok(direita.size.y <= 388.0 and direita.size.y > 200.0, "a coluna da direita com a build máxima ocupa %.0f de 388 px" % direita.size.y)
	var ids_dir: Array = []
	for sec in st.secoes:
		if sec.id in ["katana", "golpes"]:
			for l in sec.linhas:
				ids_dir.append(str(l.id))
	ok(
		ids_dir.has("katana.onda") and ids_dir.has("katana.fura") and ids_dir.has("katana.explode") and ids_dir.has("katana.folego"),
		"os 4 modificadores estão no card (%s)" % str(ids_dir)
	)
	ok(
		ids_dir.has("arma.aura_fogo") and ids_dir.has("arma.laminas") and ids_dir.has("arma.corvos") and ids_dir.has("arma.raio") and ids_dir.has("arma.runa"),
		"os 5 golpes estão no card"
	)
	tecla(KEY_C)  # desliga
	await esperar()
	ok(not st.aberto(), "desligou antes da escolha")
	await _escolha_e_bau(st, c, pausa)
	# --- a pausa: o card aparece ao lado do menu só na tela "menu"
	tecla(KEY_C)  # HUD ligado
	await esperar()
	ok(st.aberto() and st.layer < 10, "HUD ligado antes de pausar")
	pausa.pausar()
	ok(pausa.aberto and pausa.tela == "menu" and get_tree().paused, "a pausa abriu no menu")
	ok(
		st.aberto() and st._modo_atual == "pausa" and st.layer > pausa.layer,
		"na pausa o card aparece por cima do escurecimento dela (camada %d contra %d)" % [st.layer, pausa.layer]
	)
	var pr: Array = st.retangulos()
	ok(st.linhas_que_estouram().is_empty(), "nenhuma linha estoura a largura das colunas da pausa (%s)" % str(st.linhas_que_estouram()))
	ok(not st.colunas_cortadas().has(true), "nada é cortado nas colunas da pausa")
	var painel: Rect2 = Pausa.PAINEL
	# a página VISUAL (barras, pips e ícones) é a que abre; o Tab troca pela tabela de detalhes e volta
	ok(st.pagina() == "visual", "a pausa abre o card na página visual (%s)" % st.pagina())
	ok(not st.visual_cortada().has(true), "a página visual da pausa cabe na altura das colunas (%s)" % str(st.retangulos_visuais()))
	for rv in st.retangulos_visuais():
		ok(not (rv as Rect2).intersects(painel) and Rect2(0, 0, 960, 540).encloses(rv), "a página visual fica ao lado do menu, na tela (%s)" % str(rv))
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	ok(pausa.entrada(tab) and st.pagina() == "detalhe", "o Tab na pausa troca para a página de detalhes")
	ok(pausa.entrada(tab) and st.pagina() == "visual" and pausa.aberto, "o Tab de novo volta à página visual, com a pausa aberta")
	for rc in pr:
		ok(not (rc as Rect2).intersects(painel), "as colunas da pausa ficam ao lado do menu, não em cima (%s)" % str(rc))
		ok(Rect2(0, 0, 960, 540).encloses(rc), "as colunas da pausa cabem na tela")
	tecla(KEY_C)
	await esperar()
	ok(st.aberto() and st._hud, "C não desliga nada com a pausa aberta")
	pausa._ir("ajustes")
	ok(not st.aberto() or st.layer < 10, "em Ajustes o card da pausa some")
	ok(not st._pausa, "em Ajustes a pausa não pede mais o card")
	pausa._ir("graficos")
	ok(not st._pausa, "em Gráficos também some")
	pausa._ir("menu")
	ok(st._pausa and st.aberto(), "de volta ao menu o card volta")
	pausa._ir("confirmar_sair")
	ok(not st._pausa, "na confirmação de sair o card some")
	pausa._ir("menu")
	pausa.fechar()
	ok(not st._pausa and not get_tree().paused, "fechar a pausa tira o card dela")
	ok(st.aberto() and st.layer < 10, "o HUD ligado pelo C continua ligado depois da pausa")
	tecla(KEY_C)
	await esperar()
	ok(not st.aberto(), "C desliga o HUD depois da pausa")
	# --- o fim da partida desliga o card sozinho
	tecla(KEY_C)
	await esperar()
	ok(st.aberto(), "ligado de novo")
	c.jogo = "morte"
	await get_tree().create_timer(0.7).timeout
	ok(not st.aberto(), "no fim da partida o card sai de cena sozinho")
	c.jogo = "jogando"
	tecla(KEY_C)
	await esperar()
	ok(not st.aberto() or st._hud, "estado coerente")
	if st.aberto():
		tecla(KEY_C)
		await esperar()
	await _layouts(st, c)
	await _paginacao(st, c)


## Build com MUITOS golpes (todos os de dados/v2_cartas.json, o caso do PR #192): o card não tem teto. Na página visual da pausa e no painel
## central os golpes PAGINAM: "Página X/Y" aparece, Q e E trocam de página (pela entrada de verdade), nenhum golpe fica de fora e nada passa
## da altura da coluna em nenhuma página. No HUD compacto o card mostra o que cabe e o pé diz "+N golpes". Com um golpe só não há paginação.
func _paginacao(st, c) -> void:
	zerar()
	var cs = w.combate.cartas
	for d in cs.cfg.golpes:
		pegar(str(d.id))
	var total: int = w.combate.armas.ativas.size()
	ok(total >= 40, "a build de teste tem golpes demais para caber numa página (%d golpes)" % total)
	# --- HUD: o compacto mostra o que cabe e o pé diz quantos faltam
	st._hud = true
	st._aplicar()
	await esperar()
	ok(
		st._golpes_mostrados > 0 and st._golpes_mostrados < total,
		'no HUD o compacto mostra só o que cabe, com "+N golpes" no pé (%d de %d)' % [st._golpes_mostrados, total]
	)
	ok(st.linhas_que_estouram().is_empty(), "no HUD nenhuma linha estoura a largura com %d golpes (%s)" % [total, str(st.linhas_que_estouram())])
	st._hud = false
	st._aplicar()
	# --- pausa: a página visual pagina, e cada página cabe
	_achar_pausa().pausar()
	await esperar()
	ok(st.pagina() == "visual", "a pausa abre na página visual com %d golpes" % total)
	ok(not st.visual_cortada().has(true), "a página visual da pausa não passa da altura com %d golpes (%s)" % [total, str(st.retangulos_visuais())])
	var pg: Dictionary = st.paginas_golpes()
	ok(int(pg.paginas) > 1 and int(pg.pagina) == 1, "com %d golpes a pausa pagina (página %d de %d)" % [total, int(pg.pagina), int(pg.paginas)])
	var espaco := 300.0  # um espaço de exemplo: a conta tem de cobrir todos os golpes sem sobrar página vazia
	var conta: Array = Status._paginas_golpes(total, espaco)
	ok(
		int(conta[1]) * int(conta[0]) >= total and (int(conta[1]) - 1) * int(conta[0]) < total,
		"a conta de páginas cobre os %d golpes sem página vazia (%s)" % [total, str(conta)]
	)
	ok(int(conta[0]) * 20.0 + 13.0 <= espaco, "uma página cabe no espaço da coluna (%d golpes em %.0f px)" % [int(conta[0]), espaco])
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.physical_keycode = KEY_E
	ev.pressed = true
	ok(pausa_entrada(ev) and int(st.paginas_golpes().pagina) == 2, "E na pausa vai para a próxima página")
	ok(not st.visual_cortada().has(true), "a página 2 também cabe")
	var ev_q := InputEventKey.new()
	ev_q.keycode = KEY_Q
	ev_q.physical_keycode = KEY_Q
	ev_q.pressed = true
	ok(pausa_entrada(ev_q) and int(st.paginas_golpes().pagina) == 1, "Q na pausa volta para a página anterior")
	ok(not st.paginar(-1) and int(st.paginas_golpes().pagina) == 1, "Q na primeira página não passa do começo")
	for i in int(pg.paginas) + 2:
		st.paginar(1)
	pg = st.paginas_golpes()
	ok(int(pg.pagina) == int(pg.paginas), "E de sobra para na última página (%d de %d)" % [int(pg.pagina), int(pg.paginas)])
	ok(not st.visual_cortada().has(true), "a última página cabe na altura")
	# --- a tabela de detalhes (Tab) também pagina os golpes: Q e E trocam de página, e nenhuma coluna corta nada
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	ok(pausa_entrada(tab) and st.pagina() == "detalhe", "o Tab abre a tabela de detalhes")
	await esperar()
	var det: Dictionary = st.paginas_golpes()
	ok(int(det.paginas) > 1 and int(det.pagina) == 1, "a tabela de detalhes pagina os golpes com %d golpes (%s)" % [total, str(det)])
	ok(not st.colunas_cortadas().has(true), "a tabela de detalhes não corta nada com %d golpes (%s)" % [total, str(st.retangulos())])
	ok(pausa_entrada(ev) and int(st.paginas_golpes().pagina) == 2, "E na tabela de detalhes vai para a página 2")
	ok(not st.colunas_cortadas().has(true), "a página 2 da tabela de detalhes também cabe")
	ok(pausa_entrada(tab) and st.pagina() == "visual", "o Tab de novo volta à página visual")
	_achar_pausa().fechar()
	await esperar()
	# --- painel central: a mesma paginação, pelo teclado de verdade (C abre o painel; E passa pelo card)
	c.progresso.pendentes = 1
	c.progresso.abrir_escolha()
	tecla(KEY_C)
	await esperar()
	ok(st._modo_atual == "central", "o C abre o painel central com %d golpes" % total)
	ok(int(st.paginas_golpes().paginas) > 1, "o painel central pagina os golpes (%s)" % str(st.paginas_golpes()))
	ok(not st.visual_cortada().has(true), "a página visual do painel central cabe com %d golpes" % total)
	var antes: int = int(st.paginas_golpes().pagina)
	tecla(KEY_E)
	await esperar()
	ok(int(st.paginas_golpes().pagina) == antes + 1, "E no painel central troca de página")
	tecla(KEY_C)
	await esperar()
	c.progresso.escolher(0)
	c.progresso.pendentes = 0
	c.lento_t = 0.0
	c.lento_acao = ""
	ok(not st.aberto(), "o painel central fecha")
	# --- um golpe só: nenhuma paginação
	zerar()
	pegar("laminas")
	_achar_pausa().pausar()
	await esperar()
	ok(not st.visual_cortada().has(true) and int(st.paginas_golpes().paginas) == 1, "com um golpe só não há paginação (%s)" % str(st.paginas_golpes()))
	_achar_pausa().fechar()
	await esperar()


## Entrega um evento à pausa como a Antena faz (o menu aberto consome a tecla).
func pausa_entrada(ev: InputEvent) -> bool:
	return _achar_pausa().entrada(ev)


## Escolha de cartas e baú: o card compacto sai de cena, o C abre o painel CENTRAL por cima das cartas, nada é escolhido enquanto ele está
## aberto, a trava de 1 s segue correndo, o ESC abre a pausa e, fechado o painel, as cartas voltam intactas.
func _escolha_e_bau(st, c, pausa) -> void:
	var tela_c = c.telas
	tecla(KEY_C)  # liga o card compacto (jogo rolando)
	await esperar()
	ok(st.aberto() and st._modo_atual == "hud", "HUD ligado antes da escolha")
	c.progresso.pendentes = 1
	c.progresso.abrir_escolha()
	ok(c.jogo == "escolha" and c.pausado and tela_c.escolha_aberta, "a escolha de cartas está aberta")
	await get_tree().create_timer(0.4).timeout
	ok(not st.aberto(), "com a escolha aberta o card compacto sai de cena (as colunas dele cobririam a 1ª e a 3ª carta)")
	for i in 3:
		var cartao: Control = tela_c._cartas[i]
		ok(cartao.visible, "a carta %d está na tela" % i)
	var escolhidas0: int = c.progresso.escolhidas
	var sel0: int = tela_c.sel
	var rerrolar0: int = c.cartas.rerrolar_usados
	var banir0: int = c.cartas.banir_usados
	# --- C abre o painel central
	tecla(KEY_C)
	await esperar()
	ok(st.aberto() and st._modo_atual == "central", "C sobre a escolha abre o painel central (%s)" % st._modo_atual)
	ok(c.progresso.escolhidas == escolhidas0 and c.jogo == "escolha", "C não escolhe carta")
	ok(is_equal_approx(st._tela.modulate.a, 1.0), "o painel central é opaco")
	var camada_hud = _camada_hud()
	var camada_do_hud: int = camada_hud.layer if camada_hud != null else -1
	ok(
		camada_hud != null and st.layer > camada_do_hud and st.layer > tela_c.camada.layer and st.layer < pausa.layer,
		"o painel central fica por cima das cartas (camada %d) e do HUD (%d), e abaixo do menu de pausa (%d)" % [st.layer, camada_do_hud, pausa.layer]
	)
	var rc3: Array = st.retangulos()
	ok(rc3.size() == 3, "o painel central tem três colunas (%d)" % rc3.size())
	ok(st.linhas_que_estouram().is_empty() and not st.colunas_cortadas().has(true), "o painel central não estoura nem corta nada")
	for rc in rc3:
		ok(Rect2(0, 0, 960, 540).encloses(rc), "a coluna do painel central cabe na tela (%s)" % str(rc))
	ok(st.retangulos_visuais().size() == 3 and not st.visual_cortada().has(true), "a página visual do painel central tem três colunas e cabe")
	# --- a trava de 1 s das cartas segue correndo (tempo real) com o painel aberto
	var trava0: float = tela_c.espera_escolha
	ok(trava0 > 0.5, "a trava das cartas está correndo (%.2f s)" % trava0)
	passos(15)
	ok(
		tela_c.espera_escolha < trava0 - 0.2 and tela_c.espera_escolha > 0.0,
		"com o painel aberto a trava segue correndo em tempo real (%.2f s -> %.2f s depois de 0,25 s)" % [trava0, tela_c.espera_escolha]
	)
	# --- libera a trava e prova que o PAINEL (não a trava) segura as teclas e os cliques
	tela_c._liberar_cartas()
	ok(tela_c.espera_escolha == 0.0, "trava liberada para o teste")
	for k in [KEY_1, KEY_2, KEY_3, KEY_ENTER, KEY_SPACE, KEY_E, KEY_R, KEY_B, KEY_X, KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
		tecla(k)
	await esperar()
	ok(c.progresso.escolhidas == escolhidas0 and c.jogo == "escolha" and tela_c.escolha_aberta, "com o painel aberto nenhuma tecla escolhe carta")
	ok(c.cartas.rerrolar_usados == rerrolar0 and c.cartas.banir_usados == banir0 and tela_c.sel == sel0, "e nenhuma tecla rerrola, bane ou muda a seleção")
	var centro1: Vector2 = (tela_c._cartas[1] as Control).position + (tela_c._cartas[1] as Control).size * 0.5
	tela_c.mouse_fn = func(): return centro1
	var mov := InputEventMouseMotion.new()
	mov.position = centro1
	Input.parse_input_event(mov)
	var clique := InputEventMouseButton.new()
	clique.position = centro1
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	Input.parse_input_event(clique)
	await esperar()
	ok(c.progresso.escolhidas == escolhidas0 and c.jogo == "escolha", "com o painel aberto o clique sobre uma carta não escolhe nada")
	var clique_s := InputEventMouseButton.new()
	clique_s.position = centro1
	clique_s.button_index = MOUSE_BUTTON_LEFT
	clique_s.pressed = false
	Input.parse_input_event(clique_s)
	await esperar()
	ok(c.progresso.escolhidas == escolhidas0 and tela_c.sel == sel0, "nem o aperto nem a soltura mexem na seleção das cartas escondidas")
	tela_c.mouse_fn = Callable()
	# --- o ESC abre a pausa por cima do painel; ao fechar, o painel e as cartas voltam como estavam
	tecla(KEY_ESCAPE)
	await esperar()
	ok(pausa.aberto and get_tree().paused, "o ESC abre a pausa com o painel central aberto")
	ok(st._modo_atual == "pausa", "com o menu aberto o card é o da pausa (%s)" % st._modo_atual)
	pausa.fechar()
	ok(not get_tree().paused and st._modo_atual == "central" and st.aberto(), "ao fechar a pausa o painel central volta (%s)" % st._modo_atual)
	ok(c.progresso.escolhidas == escolhidas0 and c.jogo == "escolha" and c.pausado and tela_c.escolha_aberta and tela_c.sel == sel0, "e a escolha está intacta")
	# --- C fecha o painel: as cartas voltam e as teclas da escolha funcionam
	tecla(KEY_C)
	await esperar()
	ok(not st.aberto() and c.jogo == "escolha", "C fecha o painel central sobre a escolha")
	tecla(KEY_1)  # as teclas da escolha seguem funcionando
	await esperar()
	ok(c.progresso.escolhidas == escolhidas0 + 1 and c.jogo == "jogando", "a tecla 1 escolhe a primeira carta depois de fechar o painel")
	await get_tree().create_timer(0.4).timeout
	ok(st.aberto() and st._modo_atual == "hud", "terminada a escolha, o card compacto volta (%s)" % st._modo_atual)
	tecla(KEY_C)
	await esperar()
	ok(not st.aberto(), "C desliga o card compacto")
	# --- baú: o mesmo painel
	c.orbes.limpar()
	w.heroi.xp = 0.0
	c.baus.soltar(w.heroi.pos + Vector2(40, 0), 1.0, 2)
	w.heroi.definir_pos(w.heroi.pos + Vector2(40, 0))
	for i in 120:
		passos(1)
		if c.jogo == "bau":
			break
	ok(c.jogo == "bau" and tela_c.bau_aberto, "o baú abriu")
	var fase0: int = tela_c._bau_fase
	tecla(KEY_C)
	await esperar()
	ok(st.aberto() and st._modo_atual == "central", "C sobre o baú abre o painel central (%s)" % st._modo_atual)
	tela_c.espera_bau = 0.0  # sem a trava de 1,5 s: quem segura o clique é o painel
	tecla(KEY_ENTER)
	tecla(KEY_SPACE)
	tecla(KEY_E)
	tela_c.mouse_fn = func(): return Vector2(480, 270)
	var clique_b := InputEventMouseButton.new()
	clique_b.position = Vector2(480, 270)
	clique_b.button_index = MOUSE_BUTTON_LEFT
	clique_b.pressed = true
	Input.parse_input_event(clique_b)
	await esperar()
	ok(
		c.jogo == "bau" and tela_c.bau_aberto and tela_c._bau_fase == fase0 and not tela_c.bau_pronto,
		"com o painel aberto nem tecla nem clique pulam ou fecham o baú"
	)
	tecla(KEY_C)
	await esperar()
	ok(not st.aberto() and c.jogo == "bau", "C fecha o painel sobre o baú")
	tela_c.mouse_fn = Callable()
	tela_c.bau_pronto = true
	c.baus.fechar()
	ok(c.jogo == "jogando", "o jogo voltou depois do baú")


## Os três modos do card (HUD compacto, pausa e painel central) em quatro situações: build vazia (e Santuário sem compra), meio de partida,
## build máxima e a build extrema (os maiores números) com o Santuário todo comprado. Em todas: nenhuma linha estoura a coluna, nada é cortado, tudo cabe na tela, o HUD fica livre
## e o menu da pausa também.
func _layouts(st, c) -> void:
	var hud := _hud_rects()
	var painel: Rect2 = Pausa.PAINEL
	for cenario in ["vazia", "meio de partida", "build máxima", "build extrema e Santuário todo comprado"]:
		zerar()
		match cenario:
			"meio de partida":
				pegar("aura_fogo", 1)
				pegar("aura_fogo")
				pegar("laminas")
				pegar("corvos")
				pegar("dano")
				pegar("onda")
				w.tempo_partida = 200.0
				w.abates = 144
			"build máxima":
				_build_maxima()
			"build extrema e Santuário todo comprado":
				_comprar_tudo()
				w.reiniciar()
				c.limpar_partida()
				c.diretor.ligado = false
				_build_extrema()
				w.tempo_partida = 3599.0
				w.abates = 99999
				w.combo = 999
				w.maior_combo = 999
				w.xp_coletado = 999999.0
		for modo in ["hud", "pausa", "central"]:
			match modo:
				"hud":
					st._hud = true
					st._aplicar()
				"pausa":
					st.na_pausa(true)
				"central":
					c.progresso.pendentes = 1
					c.progresso.abrir_escolha()
					tecla(KEY_C)
					await esperar()
			ok(st.aberto() and st._modo_atual == modo, "[%s / %s] o card está no modo certo (%s)" % [cenario, modo, st._modo_atual])
			if cenario == "vazia":
				st._meta = {}  # nenhuma melhoria comprada no Santuário
			st._recoletar()
			var rs: Array = st.retangulos()
			var estoura: Array = st.linhas_que_estouram()
			var cortadas: Array = st.colunas_cortadas()
			var alturas: Array = []
			for r in rs:
				alturas.append(snappedf((r as Rect2).size.y, 1.0))
			print("  layout [%s / %s]: alturas %s" % [cenario, modo, str(alturas)])
			ok(estoura.is_empty(), "[%s / %s] nenhuma linha estoura a coluna (%s)" % [cenario, modo, str(estoura)])
			ok(not cortadas.has(true), "[%s / %s] nada é cortado na altura (%s)" % [cenario, modo, str(cortadas)])
			for rc in rs:
				ok(Rect2(0, 0, 960, 540).encloses(rc), "[%s / %s] a coluna cabe na tela (%s)" % [cenario, modo, str(rc)])
				if modo == "hud":
					for e in hud:
						ok(not (rc as Rect2).intersects(e.rect), "[%s / %s] a coluna %s não cobre %s" % [cenario, modo, str(rc), e.nome])
				elif modo == "pausa":
					ok(not (rc as Rect2).intersects(painel), "[%s / %s] a coluna fica ao lado do menu" % [cenario, modo])
			if modo == "central":
				for k in rs.size() - 1:
					ok(not (rs[k] as Rect2).intersects(rs[k + 1]), "[%s / %s] as colunas do painel não se tocam" % [cenario, modo])
			match modo:
				"hud":
					st._hud = false
					st._aplicar()
				"pausa":
					st.na_pausa(false)
				"central":
					tecla(KEY_C)
					await esperar()
					c.progresso.escolher(0)
					c.progresso.pendentes = 0
					c.lento_t = 0.0
					c.lento_acao = ""
			ok(not st.aberto(), "[%s / %s] fechado" % [cenario, modo])


# ------------------------------------------------------------------ prints


func _foto(nome: String, pasta: String) -> void:
	await get_tree().create_timer(0.4).timeout  # o card se atualiza a 4 Hz: dá tempo de ele pintar o estado de agora (opaco na escolha e na pausa)
	await RenderingServer.frame_post_draw
	var img: Image = w.sv.get_texture().get_image()
	img.save_png(pasta.path_join(nome + ".png"))
	print("FOTO ", pasta.path_join(nome + ".png"), " ", img.get_size())


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	Config.g_aplicar_perfil("alto")
	Config.temporario("pausar_fora", false)  # a janela de fundo perderia o foco e a pausa abriria sobre a foto
	zerar()
	var c = w.combate
	var h = w.heroi
	var st = w.status
	# 0a) a build com TODOS os golpes: o HUD mostra o que cabe com "+N golpes" no pé, e a pausa pagina (Q e E)
	for d in c.cartas.cfg.golpes:
		pegar(str(d.id))
	st._hud = true
	st._aplicar()
	await get_tree().process_frame
	await _foto("status_hud_50_golpes", pasta)
	st._hud = false
	st._aplicar()
	_achar_pausa().pausar()
	await get_tree().process_frame
	await _foto("status_pausa_50_golpes", pasta)
	st.paginar(1)
	await get_tree().process_frame
	await _foto("status_pausa_50_golpes_p2", pasta)
	st.alternar_detalhe()
	await get_tree().process_frame
	await _foto("status_pausa_50_detalhe", pasta)
	st.alternar_detalhe()
	_achar_pausa().fechar()
	zerar()
	# 0) HUD compacto com a build VAZIA (o começo de toda partida)
	st._hud = true
	st._aplicar()
	await get_tree().process_frame
	await _foto("status_hud_vazio", pasta)
	st._hud = false
	st._aplicar()
	# uma build cheia a meio de partida: 5 golpes, os modificadores, evolução e stats; bônus do Santuário já aplicados
	for id in ["aura_fogo", "aura_fogo", "aura_fogo", "laminas", "laminas", "laminas", "corvos", "corvos", "raio", "raio", "runa"]:
		pegar(id, 1 if id == "raio" else 0)
	for id in ["dano", "dano", "vel_ataque", "area", "critico", "vida", "vel_mov", "ima", "onda", "onda", "explode", "folego"]:
		pegar(id, 1)
	w.tempo_partida = 150.0
	w.abates = 241
	w.maior_combo = 34
	w.combo = 11
	w.xp_coletado = 1580.0
	c.cartas.rerrolar_usados = 1
	c.diretor.ondas = 5
	c.diretor.proxima_onda = w.tempo_partida + 17.0
	h.nivel = 14
	h.xp = 31.0
	h.xp_proximo = float(c.progresso.xp_para(14))
	h.vida = h.vida_max * 0.8
	h.imortal = true
	h.ataque_forcado = true
	for i in 22:
		var a := TAU * float(i) / 22.0
		var m = w.nascer_monstro("inimigo_cao_ossos" if i % 3 != 0 else "inimigo_lobo_sombrio", h.pos + Vector2(cos(a) * 150.0, sin(a) * 90.0))
		m.atordoa_t = 99999.0
	passos(150)
	h.ataque_forcado = null
	h.estado = Heroi.Estado.LIVRE
	# 1) HUD compacto (C) durante a partida
	st._hud = true
	st._aplicar()
	await get_tree().process_frame
	await _foto("status_hud", pasta)
	# 1b) com o mini-chefe em campo (a barra do chefe e o aviso aparecem): o card não passa por baixo de nada do HUD
	w.tempo_partida = 181.0
	h.ataque_forcado = true
	passos(45)
	h.ataque_forcado = null
	h.estado = Heroi.Estado.LIVRE
	await get_tree().process_frame
	await _foto("status_hud_chefe", pasta)
	# 2) escolha de cartas: o C abre o painel central por cima delas (o compacto sai de cena sozinho)
	c.progresso.pendentes = 1
	c.progresso.abrir_escolha()
	await get_tree().create_timer(0.4).timeout
	await _foto("status_escolha_cartas", pasta)  # as cartas intactas, sem o card
	st.alternar()
	await get_tree().process_frame
	await _foto("status_escolha", pasta)
	st.alternar()
	c.progresso.escolher(0)
	st._hud = false
	st._aplicar()
	# 3) baú: o mesmo painel
	c.orbes.limpar()
	c.baus.soltar(h.pos + Vector2(40, 0), 1.0, 3)
	h.definir_pos(h.pos + Vector2(40, 0))
	for i in 120:
		passos(1)
		if c.jogo == "bau":
			break
	await get_tree().create_timer(0.4).timeout
	st.alternar()
	await get_tree().process_frame
	await _foto("status_bau", pasta)
	st.alternar()
	c.telas.bau_pronto = true
	c.baus.fechar()
	# 4) menu de pausa com o card ao lado
	var pausa = _achar_pausa()
	pausa.pausar()
	await get_tree().process_frame
	await _foto("status_pausa", pasta)
	st.alternar_detalhe()  # a página de detalhes (a tabela de antes)
	await get_tree().process_frame
	await _foto("status_pausa_detalhe", pasta)
	st.alternar_detalhe()
	pausa.fechar()
	# 5) a build extrema (os maiores números) com o Santuário todo comprado: o pior caso de largura
	_comprar_tudo()
	zerar()
	_build_extrema()
	w.tempo_partida = 3599.0
	w.abates = 99999
	w.combo = 999
	w.maior_combo = 999
	w.xp_coletado = 999999.0
	h.vida = h.vida_max
	st._hud = true
	st._aplicar()
	await get_tree().process_frame
	await _foto("status_hud_extrema", pasta)
	st._hud = false
	st._aplicar()
	print("v2_status fotos em ", pasta)

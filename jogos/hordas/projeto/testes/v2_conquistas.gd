extends "res://testes/isolamento_v2.gd"
# Teste automático da lista de conquistas (#373): v2/conquistas.gd (a conta do progresso, a mesma do Códice e da pausa), o recorde
# no save, o Códice do santuário (v2/salao.gd) e o atalho "Conquistas" da pausa (v2/pausa.gd). Usa saves TEMPORÁRIOS (meta, personagens
# e opções); o save real da meta não é tocado (conferência por md5).
# Confere: cada mapa tem a sua conquista de vitória (Floresta, Laboratório, Cidade e Ruínas); cada linha traz nome, o que fazer,
# progresso, prêmio e ícone; o recorde (tempo e combo) só sobe; "3/5 min" e "33/50 abates" saem do recorde e a partida em andamento
# vale se for maior; cumprida mostra o progresso cheio; o Códice mostra uma linha por conquista com o cabeçalho "N / M CUMPRIDAS"
# e a cumprida em destaque; a pausa abre a mesma lista, mostra o progresso da partida viva e volta ao menu parada em "Conquistas".
# Roda: godot --headless --audio-driver Dummy --path jogos/hordas/projeto res://testes/v2_conquistas.tscn  (imprime "v2_conquistas falhas=0")

const Meta := preload("res://v2/meta.gd")
const Conquistas := preload("res://v2/conquistas.gd")
const Mapas := preload("res://v2/mapas.gd")
const Icones := preload("res://v2/icones_santuario.gd")
const Personagens := preload("res://v2/personagens.gd")
const Salao := preload("res://v2/salao.tscn")
const Hud := preload("res://v2/hud.gd")
const EscalaUi := preload("res://v2/escala_ui.gd")
const ConquistaHud := preload("res://v2/hud_conquista.gd")
const CONDICOES_AO_VIVO := ["tempo", "combo", "abates", "nivel", "evolucoes"]  # as que a partida mede sozinha (Conquistas.CONDICOES_AO_VIVO)
const Mundo := preload("res://v2/mundo.tscn")
const SAVE_TESTE := "user://testes_v2/v2_conquistas/teste_v2_conquistas_meta.cfg"
const OPCOES_TESTE := "user://testes_v2/v2_conquistas/teste_v2_conquistas_opcoes.cfg"
const SAVE_REAL := "user://testes_v2/v2_conquistas/v2_progresso.cfg"
const SEM_PREMIO := [
	"vence_pesadelo",
	"vence_dificuldade_facil",
	"vence_dificuldade_medio",
	"vence_dificuldade_dificil",
	"segredo_oferenda_vazia",
	"segredo_fonte_sem_agua",
	"segredo_capsula_rachada",
	"segredo_banco_voltado_ao_ceu"
]  # marcos e fragmentos só de lore, sem prêmio

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var md5_real := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	Meta.caminho_save = SAVE_TESTE
	Config.arquivo = OPCOES_TESTE
	Personagens.caminho_base = "user://testes_v2/v2_conquistas/teste_v2_conquistas_p"
	Personagens.caminho_indice = "user://testes_v2/v2_conquistas/teste_v2_conquistas_personagens.cfg"
	Personagens.caminho_antigo = "user://testes_v2/v2_conquistas/teste_v2_conquistas_antigo.cfg"
	_limpar()
	_escolha()
	_travada()
	_cabe()
	_topo()
	_dados()
	_progresso()
	_pesadelo()
	await _codice()
	await _pausa()
	_limpar()
	var depois := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	ok(md5_real == depois, "o save real da meta nao foi tocado")
	print("v2_conquistas falhas=%d" % falhas)
	get_tree().quit()


## Mundo falso da partida para o HUD da conquista em andamento (só os campos que ela lê).
class MundoFalsoConq:
	extends RefCounted
	var heroi = null
	var tempo_partida := 0.0
	var maior_combo := 0
	var abates := 0
	var monstros_vivos := 0


## A escolha: a de maior fração entre as que a partida mede sozinha, sem as feitas, os segredos e as de outro herói. Sem nada sobrando, vazia.
func _escolha() -> void:
	var estado := Meta.estado()  # save de teste, limpo antes
	var vivo := {"tempo": 0.0, "combo": 0, "abates": 0, "nivel": 1, "evolucoes": 0, "heroi": "nicao"}
	var ls: Array = Conquistas.linhas(vivo, estado)
	var e: Dictionary = Conquistas.escolher(ls, "nicao")
	ok(not e.is_empty(), "com o save vazio sempre há uma conquista em andamento")
	ok(not bool(e.get("feita", true)) and not bool(e.get("segredo", true)), "a escolhida não está feita nem é segredo")
	ok(CONDICOES_AO_VIVO.has(str(e.get("condicao", ""))), "a escolhida é medida ao vivo (%s)" % str(e.get("condicao", "")))
	var maior := true
	for l in ls:
		var cabe := not bool(l.feita) and not bool(l.segredo) and CONDICOES_AO_VIVO.has(str(l.condicao)) and (str(l.heroi) == "" or str(l.heroi) == "nicao")
		if cabe and float(l.frac) > float(e.frac):
			maior = false
	ok(maior, "nenhuma candidata tem fração maior que a escolhida")
	var de_outro: Dictionary = Conquistas.escolher(ls, "hazaki")
	ok(str(de_outro.get("heroi", "")) in ["", "hazaki"], "com outro herói, a escolhida não é de herói nenhum outro")
	for k in estado.conquistas.keys():
		estado.conquistas[k] = true
	ok(Conquistas.escolher(Conquistas.linhas(vivo, estado), "nicao").is_empty(), "com tudo cumprido não sobra conquista em andamento")


## O HUD trava a conquista: a partida em andamento não troca de conquista; cumprida, mostra CUMPRIDA e só depois entra a próxima.
func _travada() -> void:
	var m := MundoFalsoConq.new()
	var c := ConquistaHud.new()
	add_child(c)
	c.ligar(m)
	c.avancar(0.0)
	var id1: String = c._travada
	ok(id1 != "", "a conquista em andamento é escolhida na primeira leitura")
	m.maior_combo = 99
	m.tempo_partida = 9999.0
	c.avancar(0.3)
	ok(c._travada == id1, "outra conquista ganhar fração no meio da partida não troca a travada (%s)" % id1)
	var outro := ""
	for cc in Meta.conquistas():
		if str(cc.id) != id1:
			outro = str(cc.id)
			break
	c.cumprir([outro])
	c.avancar(1.0)
	c.avancar(3.0)
	ok(c._travada == id1, "cumprir outra conquista não tira a travada")
	c.cumprir([id1])
	ok(c.visible and str(c._nome.text).begins_with("CUMPRIDA"), "cumprida mostra o selo CUMPRIDA no topo")
	ok(c._travada == "", "cumprida a travada sai, e a próxima só entra quando o selo sai")
	c.avancar(1.0)
	ok(c._travada == "", "o selo ainda está no topo com 1 s")
	c.avancar(2.0)
	ok(c._travada != "" and c._travada != id1, "depois do selo entra outra conquista (%s)" % c._travada)
	ok(bool(c._estado.conquistas.get(id1, false)), "a cumprida fica marcada no estado da partida (sem reler o save)")
	c.queue_free()


## A linha de cima mostra o progresso (e o prêmio do selo) inteiro: com 70 px fixos, "1/15 nível" saía cortado pela esquerda como "ıível".
func _cabe() -> void:
	var m := MundoFalsoConq.new()
	var c := ConquistaHud.new()
	add_child(c)
	c.ligar(m)
	c.avancar(0.0)
	for cc in Meta.conquistas():
		c._travada = str(cc.id)
		c._t = 0.0
		c.avancar(0.0)
		if c.visible:
			_confere_linha(c, "%s em andamento" % cc.id)
			ok(str(c._progresso.text).contains("/"), "%s: o progresso traz a contagem (%s)" % [cc.id, c._progresso.text])
	for cc in Meta.conquistas():
		c.cumprir([str(cc.id)])
		_confere_linha(c, "%s cumprida" % cc.id)
	c.queue_free()


func _confere_linha(c: Control, onde: String) -> void:
	var p: Label = c._progresso
	var w := p.get_theme_font("font").get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, p.get_theme_font_size("font_size")).x
	ok(w <= p.size.x + 0.5, '%s: "%s" cabe inteiro (%.0f de %.0f px)' % [onde, p.text, w, p.size.x])
	ok(c._nome.position.x + c._nome.size.x <= p.position.x + 0.5, "%s: o nome não invade o progresso" % onde)
	ok(p.position.x + p.size.x <= c.size.x - 0.5, "%s: o progresso fica dentro da caixa" % onde)


## O retângulo da conquista no canvas: 6 a 274 x 6 a 46, sem cobrir nenhum bloco da HUD, nas três escalas fixas da interface.
func _topo() -> void:
	var m := MundoFalsoConq.new()
	var blocos := ["Retrato", "MolduraBarras", "Golpes", "Tempo", "Abates", "Nivel", "Combo", "Chefe", "Anuncio", "Xp", "Ultimate", "Habilidades"]
	for opcao in ["pequeno", "medio", "grande"]:
		var janela := Vector2(1920, 1080)
		var canvas: Vector2 = EscalaUi.canvas(janela, opcao)
		var d: Vector2 = EscalaUi.deslocamento(canvas)
		var hud = Hud.criar(m)
		add_child(hud)
		hud.set_process(false)
		hud.ui_reencaixar(canvas, d)
		var no: Control = hud.get_node("Raiz/Conquista")
		var r := Rect2(no.position + d, no.size)
		var rotulo := "%s (canvas %dx%d)" % [opcao, canvas.x, canvas.y]
		ok(r == Rect2(6, 6, 268, 40), "%s: a conquista fica em 6,6 268x40 do canvas (%s)" % [rotulo, r])
		for nome in blocos:
			var b: Control = hud.get_node("Raiz/" + nome)
			ok(not r.intersects(Rect2(b.position + d, b.size * b.scale)), "%s: a conquista não cobre %s" % [rotulo, nome])
		hud.queue_free()


func _limpar() -> void:
	get_tree().paused = false
	for f in DirAccess.get_files_at("user://testes_v2/v2_conquistas/"):
		if f.begins_with("teste_v2_conquistas_"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://testes_v2/v2_conquistas/" + f))


func _linha(linhas: Array, id: String) -> Dictionary:
	for l in linhas:
		if str(l.id) == id:
			return l
	return {}


## Os dados: uma conquista de vitória por mapa e todas as linhas completas.
func _dados() -> void:
	var por_mapa := {}
	for c in Meta.conquistas():
		if c.has("mapa"):
			por_mapa[str(c.mapa)] = str(c.id)
	for m in Mapas.LISTA:
		ok(por_mapa.has(str(m.id)), "o mapa %s tem a conquista de vitoria" % m.id)
	ok(por_mapa.size() >= 4, "Floresta, Laboratorio, Cidade e Ruinas tem conquista propria")
	var linhas := Conquistas.linhas()
	ok(linhas.size() == Meta.conquistas().size(), "uma linha por conquista")
	for l in linhas:
		ok(str(l.nome) != "" and str(l.fazer) != "" and str(l.progresso).contains("/"), "linha completa: " + str(l.id))
		ok((str(l.premio) == "") == (str(l.id) in SEM_PREMIO), "premio so onde ha item (o Pesadelo e so um marco): " + str(l.id))
		ok(Icones.textura(str(l.icone)) != null and Icones.textura(str(l.icone)) != Icones.textura("generico"), "icone proprio, nunca o generico: " + str(l.id))
		ok(str(l.icone_premio) == "" or Icones.textura(str(l.icone_premio)) != Icones.textura("generico"), "icone do premio existe, ou nao ha: " + str(l.id))
		ok(not l.feita and l.frac == 0.0, "save zerado: nada cumprido " + str(l.id))
	for id in ["vence_floresta", "vence_laboratorio", "vence_cidade", "vence_medio"]:
		var l := _linha(linhas, id)
		ok(not l.is_empty() and Icones.textura(str(l.icone)) != Icones.textura("generico"), "a conquista de mapa tem icone proprio: " + id)
	ok(str(_linha(linhas, "sobreviva_5min").progresso) == "0/5 min", "tempo comeca em 0/5 min (%s)" % _linha(linhas, "sobreviva_5min").progresso)
	ok(str(_linha(linhas, "vence_medio").icone_premio) == "", "o fim da jornada (Ruinas) nao tem icone de premio")
	ok(str(_linha(linhas, "combo_50").progresso) == "0/50 abates", "combo comeca em 0/50 abates")
	ok(Conquistas.contagem(linhas) == [0, linhas.size()], "contagem zerada")


## O recorde e o progresso: sobe, nunca desce, e a partida em andamento vale se for maior.
func _progresso() -> void:
	Meta.registrar_partida({"tempo": 190.0, "maior_combo": 33})
	var r: Dictionary = Meta.estado().recordes
	ok(is_equal_approx(float(r.tempo), 190.0) and int(r.combo) == 33, "o recorde guarda o melhor tempo e o melhor combo")
	Meta.registrar_partida({"tempo": 60.0, "maior_combo": 5})
	r = Meta.estado().recordes
	ok(is_equal_approx(float(r.tempo), 190.0) and int(r.combo) == 33, "uma partida pior nao baixa o recorde")
	var linhas := Conquistas.linhas()
	var t := _linha(linhas, "sobreviva_5min")
	ok(str(t.progresso) == "3/5 min" and is_equal_approx(float(t.frac), 190.0 / 300.0), "3/5 min com 190 s (%s, %s)" % [t.progresso, t.frac])
	var c := _linha(linhas, "combo_50")
	ok(str(c.progresso) == "33/50 abates" and is_equal_approx(float(c.frac), 0.66), "33/50 abates (%s)" % c.progresso)
	linhas = Conquistas.linhas({"tempo": 245.0, "combo": 10})
	ok(str(_linha(linhas, "sobreviva_5min").progresso) == "4/5 min", "a partida viva (245 s) passa o recorde")
	ok(str(_linha(linhas, "combo_50").progresso) == "33/50 abates", "o recorde vale quando a partida viva fez menos")
	ok(not Meta.estado().conquistas.sobreviva_5min, "o progresso vivo nao cumpre a conquista sozinho")
	var vivos: Array = Meta.checar_ao_vivo(300.0, 10)  # o resultado_meta.gd chama isto a cada 0.5 s na partida: tempo e combo cumprem ao vivo
	ok(vivos.has("sobreviva_5min") and _linha(Conquistas.linhas(), "sobreviva_5min").feita, "a conquista de tempo cumpre ao vivo, sem esperar o fim da partida")
	Meta.registrar_partida({"tempo": 320.0, "maior_combo": 10})
	t = _linha(Conquistas.linhas(), "sobreviva_5min")
	ok(t.feita and t.frac == 1.0 and str(t.progresso) == "5/5 min", "cumprida mostra o progresso cheio (%s)" % t.progresso)
	Meta.registrar_partida({"tempo": 100.0, "venceu": true, "mapa": "laboratorio", "mapa_vencido_agora": false})
	var lab := _linha(Conquistas.linhas(), "vence_laboratorio")
	ok(lab.feita and str(lab.progresso) == "1/1 chefe", "vencer o mapa cumpre a conquista dele (%s)" % lab.progresso)
	ok(not _linha(Conquistas.linhas(), "vence_floresta").feita, "so a do mapa vencido")
	ok(Conquistas.contagem(Conquistas.linhas()) == [3, Meta.conquistas().size()], "contagem: tempo, Derrote o chefe (qualquer vitoria) e laboratorio")


## A conquista do Pesadelo: só a vitória no modo Pesadelo conta (em qualquer mapa) e não tem prêmio.
func _pesadelo() -> void:
	var p := _linha(Conquistas.linhas(), "vence_pesadelo")
	ok(not p.is_empty() and not p.feita and str(p.progresso) == "0/1 chefe", "a conquista do Pesadelo comeca em 0/1 chefe")
	Meta.registrar_partida({"tempo": 100.0, "venceu": true, "pesadelo": false, "mapa": "cidade", "mapa_vencido_agora": false})
	ok(not _linha(Conquistas.linhas(), "vence_pesadelo").feita, "vencer no modo normal nao cumpre a do Pesadelo")
	Meta.registrar_partida({"tempo": 100.0, "venceu": false, "pesadelo": true, "mapa": "floresta", "mapa_vencido_agora": false})
	ok(not _linha(Conquistas.linhas(), "vence_pesadelo").feita, "Pesadelo sem vitoria nao cumpre")
	Meta.registrar_partida({"tempo": 100.0, "venceu": true, "pesadelo": true, "mapa": "medio", "mapa_vencido_agora": false})
	p = _linha(Conquistas.linhas(), "vence_pesadelo")
	ok(p.feita and str(p.progresso) == "1/1 chefe", "vencer no Pesadelo, em qualquer mapa, cumpre (%s)" % p.get("progresso", ""))


## O Códice: uma linha rica por conquista, a cumprida em destaque e o cabeçalho com a contagem.
func _codice() -> void:
	Personagens.ativar(Personagens.criar("Teste"))
	Meta.registrar_partida({"tempo": 320.0, "maior_combo": 33})  # ativar() aponta a meta para o save do personagem: refaz o mesmo estado nele
	Meta.registrar_partida({"tempo": 100.0, "venceu": true, "mapa": "laboratorio", "mapa_vencido_agora": false})
	var s = Salao.instantiate()
	add_child(s)
	await get_tree().process_frame
	s.abrir_estrutura("codice")
	await get_tree().process_frame
	var n := Meta.conquistas().size()
	ok(s._p_codice and s._p_lista.get_child_count() == n, "o Codice tem uma linha por conquista (%d)" % s._p_lista.get_child_count())
	ok(s._p_saldo.text == "%d / %d CUMPRIDAS" % [Conquistas.contagem(s._p_itens)[0], n], "cabecalho conta as cumpridas (%s)" % s._p_saldo.text)
	var textos := []
	for b in s._p_lista.get_children():
		for f in b.get_children():
			if f is Label:
				textos.append(str(f.text))
	for esperado in ["Sobreviva 5 minutos", "Sobreviver 5 min numa partida", "5/5 min", "CUMPRIDA", "Prêmio: Treino de guerreiro", "0/1 chefe"]:
		ok(textos.has(esperado), "o Codice mostra '%s'" % esperado)
	var feitas := 0
	for i in s._p_itens.size():
		var b: Button = s._p_lista.get_child(i)
		var normal := b.get_theme_stylebox("normal") as StyleBoxFlat
		if s._p_itens[i].feita:
			feitas += 1
			ok(normal.border_width_left == 2, "cumprida em destaque: " + str(s._p_itens[i].id))
		else:
			ok(normal.border_width_left == 1, "pendente sem destaque: " + str(s._p_itens[i].id))
	ok(feitas == 3, "tres cumpridas na lista")
	s.abrir_estrutura("estatuas")  # as outras estruturas voltam ao desenho de sempre
	ok(not s._p_codice and s._p_card.visible and s._p_rolagem.size.x < 400.0, "as Estatuas voltam ao painel com card")
	s._fechar_painel()
	s.queue_free()
	await get_tree().process_frame


## A pausa: o atalho abre a mesma lista, com a partida viva e o texto de ajuda; ESC volta parado em "Conquistas".
func _pausa() -> void:
	Meta.caminho_save = SAVE_TESTE
	var mundo = Mundo.instantiate()
	mundo.modo_teste = true
	add_child(mundo)
	mundo.set_process(false)
	await get_tree().process_frame
	mundo.tempo_partida = 245.0
	mundo.maior_combo = 10
	var pausa = null
	for c in mundo.ui.get_children():
		if c.has_method("abrir_sair"):
			pausa = c
	ok(pausa != null and pausa.pausar(), "a pausa abre")
	ok(str(pausa._itens_atuais[1].id) == "conquistas" and str(pausa._itens_atuais[1].rotulo) == "Conquistas", "o atalho Conquistas e o 2o item da pausa")
	pausa._executar("conquistas", 0)
	ok(pausa.tela == "conquistas" and pausa._titulo.text == "CONQUISTAS", "o atalho abre a lista de conquistas")
	var linhas := Conquistas.linhas({"tempo": 245.0, "combo": 10})
	ok(pausa._itens_atuais.size() == linhas.size() + 1, "uma linha por conquista mais o Voltar")
	var tempo: Dictionary = pausa._itens_atuais[0]
	ok(str(tempo.valor) == "CUMPRIDA" and bool(tempo.feita), "a cumprida mostra CUMPRIDA (%s)" % tempo.valor)
	var combo: Dictionary = {}
	for it in pausa._itens_atuais:
		if str(it.id) == "c:combo_50":
			combo = it
	ok(
		str(combo.valor) == "33/50 abates" and str(combo.ajuda).contains("Prêmio: Rastro de katana"),
		"progresso e premio na linha do combo (%s)" % combo.get("valor")
	)
	ok(
		pausa._sub.text == "6 de %d cumpridas" % linhas.size(),
		"o subtitulo conta as cumpridas: tempo, chefe, Laboratorio, Cidade, Ruinas e Pesadelo (%s)" % pausa._sub.text
	)
	pausa._ir("conquistas")
	pausa.sel = 0
	pausa._desenhar()
	ok(pausa._linhas[0]["icone"].visible and pausa._linhas[0]["icone"].texture == Icones.textura("sobreviva_5min"), "icone da conquista na linha")
	var ajuda_antes: String = pausa._ajuda.text
	ok(ajuda_antes.contains("Sobreviver 5 min numa partida") and ajuda_antes.contains("Prêmio"), "o rodape diz o que fazer e o premio (%s)" % ajuda_antes)
	pausa._voltar_tela()
	ok(pausa.tela == "menu" and str(pausa._itens_atuais[pausa.sel].id) == "conquistas", "ESC volta ao menu parado em Conquistas")
	ok(pausa._linhas[0]["rotulo"].position.x == 12.0 and not pausa._linhas[0]["icone"].visible, "no menu o nome volta para a margem e o icone some")
	pausa.fechar()
	mundo.queue_free()
	await get_tree().process_frame

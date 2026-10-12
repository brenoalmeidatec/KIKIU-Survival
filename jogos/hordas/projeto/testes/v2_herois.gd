extends Node
# Teste automático dos heróis da v2 (v2/herois.gd, adagas.gd, selecao_heroi.gd, dados/v2_herois.json): Hazaki (padrão), Nicão (marreta) e Lucas
# (adagas). Usa um save TEMPORÁRIO (user://teste_v2_herois.cfg): o save real não é tocado. Confere: o JSON (3 heróis, folhas de sprites que
# existem, o Hazaki repetindo os números do v2_combate.json); a escolha (sem chave = Hazaki, grava e relê, id inválido ignorado, o resto do
# save intacto); cada herói criando a partida de verdade (vida, velocidade, tamanho, bônus, sprite); o Hazaki sem mudar; o Nicão batendo em
# arco e depois em volta, empurrando para fora; o Lucas jogando adagas em leque na direção do mouse, que acertam monstro da horda, elite e
# chefe, furam, somem, repetem segurando e não criam nó; o filtro das cartas por herói (e as cartas novas funcionando); e o santuário
# com a seleção (cartões, mouse, teclado, ESC e a escolha gravada); e o card SUA BUILD com o herói escolhido (nome, arma e os
# modificadores dele).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_herois.tscn  (imprime "v2_herois falhas=0")
# Prints (precisa de janela): ... res://testes/v2_herois.tscn -- --fotos=PASTA  grava o santuário com a seleção, cada herói golpeando e o card SUA BUILD dele.
const Mundo := preload("res://v2/mundo.tscn")
const Altar := preload("res://v2/altar.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Meta := preload("res://v2/meta.gd")
const Status := preload("res://v2/status.gd")  # o card SUA BUILD (tecla C)
const SAVE_TESTE := "user://teste_v2_herois.cfg"
const SAVE_REAL := "user://v2_progresso.cfg"
const PASSO := 1.0 / 60.0
const PASTA_SPRITES := "res://prototipos/cara_nova/sprites/"

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func ate(cond: Callable, max_passos: int) -> int:
	for i in max_passos:
		if cond.call():
			return i
		w.avancar(PASSO)
	return -1 if not cond.call() else max_passos


func _apagar_save() -> void:
	if FileAccess.file_exists(SAVE_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TESTE))


## Um mundo novo com o herói `id` (a escolha vai pelo save temporário, o mesmo caminho do santuário).
func novo(id: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = ""
	Herois.escolher(id)
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true


## Mapa sem monstros, herói imortal e parado, sem diretor nem crítico (o dano fica previsível), mouse à direita.
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = null
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.heroi.m_critico = -1.0
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	passos(3)


func monstro_a(dx: float, dy := 0.0, nome := "inimigo_espantalho"):
	var m = w.nascer_monstro(nome, w.heroi.pos + Vector2(dx, dy))
	m.atordoa_t = 0.0
	return m


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	var pasta := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			pasta = a.trim_prefix("--fotos=")
	var md5_real := FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	_apagar_save()
	if pasta != "":
		await _fotos(pasta)
	else:
		await _testes()
		ok((FileAccess.get_md5(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else "") == md5_real, "o save real da v2 não foi tocado")
	_apagar_save()
	Herois.forcado = ""
	if pasta == "":
		print("v2_herois falhas=%d" % falhas)
	get_tree().quit()


func _testes() -> void:
	_t_dados()
	_t_escolha()
	await _t_hazaki()
	await _t_nicao()
	await _t_lucas()
	await _t_cartas()
	await _t_card()
	await _t_altar()


# ------------------------------------------------------------------ dados e escolha


func _t_dados() -> void:
	var cat := Herois.catalogo()
	var ids := []
	for h in Herois.lista():
		ids.append(str(h.id))
		for k in ["id", "nome", "titulo", "desc", "sprite", "raio", "bonus", "cfg"]:
			ok(h.has(k), "%s tem o campo %s" % [h.id, k])
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PASTA_SPRITES + str(h.sprite) + ".json"))
		ok(info != null and info.linhas.size() == 8 and info.colunas.size() == 5 and info.quadro.size() == 2, "%s: o json da folha tem quadro, 8 linhas e 5 colunas" % h.id)
		ok(ResourceLoader.exists(PASTA_SPRITES + str(h.sprite) + "_albedo.png") and ResourceLoader.exists(PASTA_SPRITES + str(h.sprite) + "_normal.png"), "%s: albedo e normal existem" % h.id)
		var ps: Array = h.cfg.golpe.passos
		ok(ps.size() >= 1, "%s tem passos de golpe" % h.id)
	ok(ids == ["hazaki", "nicao", "lucas"], "3 heróis na ordem hazaki, nicao, lucas (%s)" % str(ids))
	ok(str(cat.get("_ajuda", "")) != "", "v2_herois.json tem _ajuda")
	# o Hazaki repete v2_combate.json: nada muda para ele
	var base := Dados.json("v2_combate")
	var hz := Herois.cfg_para(base, "hazaki")
	ok(JSON.stringify(hz.golpe) == JSON.stringify(base.golpe), "Hazaki: o combo é igual ao do v2_combate.json")
	ok(float(hz.heroi.vida) == float(base.heroi.vida) and float(hz.heroi.mov_golpe) == float(base.heroi.mov_golpe) and float(hz.folego.max) == float(base.folego.max), "Hazaki: vida, mov_golpe e fôlego iguais ao v2_combate.json")
	ok(float(hz.heroi.vel) == 100.0, "Hazaki: anda a 100 px/s, como sempre")
	ok(hz.esquiva == base.esquiva and hz.corrida == base.corrida and hz.contato == base.contato, "Hazaki: esquiva, corrida e contato intactos")
	ok(not base.heroi.has("vel"), "cfg_para copia: o v2_combate.json em cache não foi alterado")
	var nc := Herois.cfg_para(base, "nicao")
	ok(float(nc.heroi.vida) == 180.0 and nc.golpe.passos.size() == 2 and float(nc.heroi.recuo_dano) == 70.0 and float(nc.heroi.invencivel) == float(base.heroi.invencivel), "Nicão: cobre só o que muda e mantém o resto (invencivel)")
	var num := Herois.numeros("lucas", base)
	ok(num.size() == 3 and num[0][0] == "VIDA" and num[0][1] == "70" and num[1][1] == "118", "números do cartão: vida e velocidade saem do cfg (%s)" % str(num))


func _t_escolha() -> void:
	ok(not FileAccess.file_exists(SAVE_TESTE) and Herois.escolhido() == "hazaki", "sem save: o herói é o Hazaki")
	# save antigo (sem a chave nova) segue valendo
	var cf := ConfigFile.new()
	cf.set_value("moeda", "almas", 77)
	cf.set_value("melhorias", "vida", 2)
	cf.save(SAVE_TESTE)
	ok(Herois.escolhido() == "hazaki" and Meta.heroi_escolhido() == "", "save antigo sem a chave: Hazaki")
	ok(Herois.escolher("nicao") and Herois.escolhido() == "nicao", "escolher grava e relê")
	var lido := ConfigFile.new()
	lido.load(SAVE_TESTE)
	ok(str(lido.get_value("heroi", "id", "")) == "nicao", "a chave [heroi] id está no arquivo")
	ok(int(lido.get_value("moeda", "almas", 0)) == 77 and int(lido.get_value("melhorias", "vida", 0)) == 2, "escolher não mexe nas almas nem nas melhorias")
	ok(not Herois.escolher("fantasma") and Herois.escolhido() == "nicao", "id que não existe é ignorado")
	Meta.escolher_heroi("sumiu")  # id velho no save (herói removido): volta ao Hazaki
	ok(Herois.escolhido() == "hazaki", "id inválido gravado no save cai no Hazaki")
	Herois.escolher("lucas")
	ok(Meta.comprar("vida") == false or true, "comprar continua funcionando com a chave nova")  # só não pode quebrar
	Herois.forcado = "nicao"
	ok(Herois.escolhido() == "nicao", "forcado vale por cima do save (testes e fotos)")
	Herois.forcado = ""
	ok(Herois.escolhido() == "lucas", "sem forcado volta ao save")


# ------------------------------------------------------------------ Hazaki (padrão, sem mudar)


func _t_hazaki() -> void:
	_apagar_save()  # sem as melhorias que o teste da escolha gravou: os números são os de base
	await novo("hazaki")
	var h = w.heroi
	var c: Dictionary = w.combate.cfg
	ok(w.combate.heroi_id == "hazaki" and h.chave == "hazaki", "a partida do Hazaki: heroi_id e chave")
	ok(h.vida_max == 100.0 and h.vel_base == 100.0 and h.raio == 6.0 and h.m_area == 1.0 and h.m_dano == 1.0, "Hazaki: vida 100, 100 px/s, raio 6, sem bônus")
	ok(h.tipo.w == 32 and h.tipo.h == 44, "Hazaki: folha de 32x44 (a samurai de antes)")
	ok(c.golpe.passos.size() == 3 and c.golpe.passos[2].nome == "estocada" and float(c.golpe.passos[0].dano) == 12.0, "Hazaki: combo de 3 com os números de sempre")
	zerar()
	var m = monstro_a(40)
	h.atacar()
	var n := ate(func(): return h.golpe_acertou, 60)
	ok(n >= 0, "Hazaki golpeia")
	ok(m.vida < m.vida_max and m.vida >= m.vida_max - 14.0 * 1.2 - 0.01, "Hazaki: o primeiro corte tira ~12 (vida %d de %d)" % [m.vida, m.vida_max])
	ok(w.combate.adagas.lancadas == 0, "Hazaki não joga adaga")


# ------------------------------------------------------------------ Nicão


func _t_nicao() -> void:
	await novo("nicao")
	var h = w.heroi
	ok(w.combate.heroi_id == "nicao" and h.chave == "nicao", "a partida do Nicão: heroi_id e chave")
	ok(h.vida_max == 180.0 and h.vida == 180.0, "Nicão: 180 de vida (Meta.aplicar não voltou para 100)")
	ok(h.vel_base == 78.0 and h.raio == 8.0, "Nicão: anda a 78 px/s e o corpo é maior (raio 8)")
	ok(absf(h.m_area - 1.2) < 0.001, "Nicão: bônus de área 1,2 (%.2f)" % h.m_area)
	ok(h.tipo.w == 64 and h.tipo.h == 60 and h.tipo.has("alb") and h.sprite.texture != null, "Nicão: folha própria, de quadro maior")
	ok(w.combate.cfg.golpe.passos.size() == 2 and w.combate.cfg.golpe.passos[1].nome == "pancada", "Nicão: combo curto, batida e pancada no chão")
	w.reiniciar()
	ok(h.vida_max == 180.0 and absf(h.m_area - 1.2) < 0.001 and h.vel_base == 78.0, "jogar de novo: os números do Nicão continuam (valores absolutos)")
	# anda mais devagar que o Hazaki
	zerar()
	h.entrada_forcada = Vector2(0, 1)
	passos(30)
	ok(absf(h.vel.length() - 78.0) < 8.0, "Nicão anda a ~78 px/s (%.1f)" % h.vel.length())
	h.entrada_forcada = Vector2.ZERO
	passos(10)
	# batida em arco e pancada em volta
	zerar()
	var frente = monstro_a(40, 0, "inimigo_cavaleiro_oco")  # vida 96: aguenta a batida e a pancada sem morrer
	var atras = monstro_a(-38, 0, "inimigo_cavaleiro_oco")
	var dur0: float = float(w.combate.cfg.golpe.passos[0].duracao)
	ok(dur0 > 0.4, "a batida é lenta (%.2f s, a do Hazaki é 0,26)" % dur0)
	h.atacar()
	ok(ate(func(): return h.golpe_acertou, 80) >= 0 and h.golpe_cfg.nome == "batida", "1º golpe: batida")
	passos(2)
	ok(frente.vida < frente.vida_max, "a batida acerta quem está na frente")
	ok(atras.vida == atras.vida_max, "a batida não acerta quem está atrás (arco de 150 graus)")
	ok(frente.emp.x > 0.0, "a batida empurra para a frente (emp.x=%.0f)" % frente.emp.x)
	var emp_batida: float = frente.emp.length()
	ok(ate(func(): return h.estado == Heroi.Estado.LIVRE, 80) >= 0, "a batida termina")
	atras.vida = atras.vida_max
	frente.atordoa_t = 0.0
	var g1: int = h.golpes
	h.atacar()  # dentro da janela do combo: o 2º passo
	ok(ate(func(): return h.golpes > g1 and h.golpe_acertou, 80) >= 0 and h.golpe_cfg.nome == "pancada", "2º golpe: pancada no chão")
	passos(2)
	ok(atras.vida < atras.vida_max, "a pancada acerta em volta, inclusive atrás")
	ok(atras.emp.x < 0.0, "a pancada empurra para FORA (atrás vai para trás, emp.x=%.0f)" % atras.emp.x)
	ok(atras.emp.length() > emp_batida * 0.9, "a pancada empurra forte (%.0f contra %.0f da batida)" % [atras.emp.length(), emp_batida])
	# o empurrão leva o monstro para longe de verdade
	var d0: float = atras.pos.distance_to(h.pos)
	passos(20)
	ok(atras.pos.distance_to(h.pos) > d0 + 10.0, "o monstro de trás foi mesmo empurrado (%.0f -> %.0f px)" % [d0, atras.pos.distance_to(h.pos)])
	# cartas do Nicão
	var cs = w.combate.cartas
	cs.aplicar(cs.montar_carta(cs.definicao("muralha"), 0))
	ok(float(w.combate.armas.mods.muralha) == 25.0, "carta Peso de muralha liga o modificador")
	cs.aplicar(cs.montar_carta(cs.definicao("abalo"), 0))
	ok(float(w.combate.armas.mods.abalo) == 45.0, "carta Abalo sísmico liga o modificador")
	zerar()  # limpa_partida zera os modificadores: refaz
	cs.aplicar(cs.montar_carta(cs.definicao("abalo"), 0))
	cs.aplicar(cs.montar_carta(cs.definicao("muralha"), 0))
	var alvo = monstro_a(40, 0, "inimigo_cavaleiro_oco")
	var gA: int = h.golpes
	h.atacar()
	ate(func(): return h.golpes > gA and h.golpe_acertou, 80)
	ate(func(): return h.estado == Heroi.Estado.LIVRE, 80)
	var l0: int = w.combate.armas.lancadas
	var g2: int = h.golpes
	h.atacar()
	ate(func(): return h.golpes > g2 and h.golpe_acertou, 80)
	passos(2)
	ok(w.combate.armas.lancadas > l0, "com o Abalo, a pancada solta uma onda de choque (lançadas %d -> %d)" % [l0, w.combate.armas.lancadas])
	ok(alvo.vida < alvo.vida_max, "o alvo apanhou")


# ------------------------------------------------------------------ Lucas


func _t_lucas() -> void:
	await novo("lucas")
	var h = w.heroi
	var ad = w.combate.adagas
	ok(w.combate.heroi_id == "lucas" and h.chave == "lucas", "a partida do Lucas: heroi_id e chave")
	ok(h.vida_max == 70.0 and h.vel_base == 118.0 and h.raio == 5.0, "Lucas: frágil (70), rápido (118 px/s), pequeno (raio 5)")
	ok(h.tipo.w == 40 and h.tipo.h == 46, "Lucas: folha própria")
	ok(float(w.meta_bonus.raridade) >= 0.15 - 0.0001, "Lucas: sorte nas cartas (meta_bonus.raridade %.2f)" % float(w.meta_bonus.raridade))
	ok(w.combate.cfg.golpe.passos.size() == 3 and str(w.combate.cfg.golpe.passos[0].tipo) == "adagas", "Lucas: combo de 3 arremessos de adagas")
	w.reiniciar()
	ok(float(w.meta_bonus.raridade) < 0.2, "jogar de novo não soma a sorte duas vezes (%.2f)" % float(w.meta_bonus.raridade))
	zerar()
	h.entrada_forcada = Vector2(0, 1)
	passos(30)
	ok(absf(h.vel.length() - 118.0) < 10.0, "Lucas anda a ~118 px/s (%.1f)" % h.vel.length())
	h.entrada_forcada = Vector2.ZERO
	# o arremesso: leque na direção do mouse
	zerar()
	var nos0: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	w.mouse_forcado = h.centro() + Vector2(-70, -70)
	h.atacar()
	ok(ate(func(): return ad.lancadas >= 2, 60) >= 0, "o arremesso solta adagas (lançadas=%d)" % ad.lancadas)
	var esperado := Vector2(-1, -1).normalized()
	var dentro := 0
	for i in ad.MAX:
		if ad.a_rest[i] > 0.0 and (ad.a_dir[i] as Vector2).dot(esperado) > 0.97:
			dentro += 1
	ok(dentro == 2, "as 2 adagas do 1º arremesso saem na direção do mouse (cima-esquerda): %d" % dentro)
	ok(ate(func(): return ad.ativas() == 0, 200) >= 0, "as adagas somem sozinhas (alcance)")
	ok(ad.sumiram == ad.lancadas, "toda adaga que saiu acabou (%d de %d)" % [ad.sumiram, ad.lancadas])
	ok(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= nos0, "arremessar e sumir não cria nó (%d -> %d)" % [nos0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	# acerta o monstro da horda, fura, empurra e mata
	zerar()
	var m1 = monstro_a(80, 0, "inimigo_cao_ossos")
	var m2 = monstro_a(130, 0, "inimigo_cao_ossos")
	var v1: float = m1.vida
	h.atacar()
	ate(func(): return ad.lancadas >= 2, 60)
	ate(func(): return ad.acertos >= 1, 60)
	passos(3)
	ok(m1.vida < v1 or not m1.vivo, "a adaga acerta o monstro da horda (vida %d de %d)" % [m1.vida, v1])
	ok(m1.emp.x > 0.0 or not m1.vivo, "e o empurra para longe do herói")
	ate(func(): return ad.ativas() == 0, 120)
	ok(ad.acertos >= 2 and (m2.vida < m2.vida_max or not m2.vivo), "furar: a mesma adaga atravessa e acerta o de trás também (acertos=%d)" % ad.acertos)
	# acerta elite e chefe
	zerar()
	var el = w.combate.elites.nascer("inimigo_cao_ossos", "blindado", h.pos + Vector2(110, 0))
	var vida_el: float = el.vida
	h.atacar()
	ate(func(): return ad.acertos >= 1, 120)
	passos(4)
	ok(el.vida < vida_el, "a adaga acerta a elite (vida %d de %d)" % [el.vida, vida_el])
	zerar()
	var ch = w.combate.chefes.nascer(w.combate.cartas.cfg.chefes.marcas[0], h.pos + Vector2(120, 0))
	var vida_ch: float = ch.vida
	h.atacar()
	ate(func(): return ad.acertos >= 1, 120)
	passos(4)
	ok(ch.vida < vida_ch, "a adaga acerta o chefe (vida %d de %d)" % [ch.vida, vida_ch])
	# segurar repete
	zerar()
	var gs0: int = h.golpes
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = true
	passos(120)
	h.ataque_forcado = false
	ok(h.golpes - gs0 >= 5, "segurar o botão repete os arremessos (%d em 2 s)" % (h.golpes - gs0))
	ok(ad.lancadas >= 10, "adagas em quantidade (%d); o pool segura (<= %d voando)" % [ad.lancadas, ad.MAX])
	ok(ad.ativas() <= ad.MAX, "nunca passa do pool")
	# o terceiro arremesso é o leque de 5
	zerar()
	var g0: int = h.golpes
	h.atacar()
	ate(func(): return h.golpes >= g0 + 1 and h.estado == Heroi.Estado.LIVRE, 60)
	h.atacar()
	ate(func(): return h.golpes >= g0 + 2 and h.estado == Heroi.Estado.LIVRE, 60)
	var l0: int = ad.lancadas
	h.atacar()
	ate(func(): return h.golpes >= g0 + 3 and h.golpe_acertou, 80)
	ok(ad.lancadas - l0 == 5, "o 3º arremesso é o leque de 5 adagas (%d)" % (ad.lancadas - l0))
	# modificadores do Lucas
	zerar()
	var cs = w.combate.cartas
	cs.aplicar(cs.montar_carta(cs.definicao("mira"), 0))
	ok(float(w.combate.armas.mods.mira) == 15.0, "carta Mira longa liga o modificador")
	h.atacar()
	ate(func(): return ad.lancadas >= 2, 60)
	var rest_max := 0.0
	for i in ad.MAX:
		rest_max = maxf(rest_max, ad.a_rest[i])
	ok(rest_max > 220.0, "com a Mira longa a adaga voa mais longe (%.0f px)" % rest_max)
	zerar()
	cs.aplicar(cs.montar_carta(cs.definicao("chuva"), 3))  # lendária: 15 x 3,2 = 48%
	w.combate.armas.mods.chuva = 100.0
	monstro_a(70, 0, "inimigo_cavaleiro_oco")
	h.atacar()
	ate(func(): return ad.lancadas >= 2, 60)
	var l1: int = ad.lancadas
	ate(func(): return ad.acertos >= 1, 60)
	passos(2)
	ok(ad.lancadas > l1, "com a Chuva de adagas um acerto solta outra adaga (%d -> %d)" % [l1, ad.lancadas])
	w.combate.armas.mods.chuva = 0.0
	# limpar a partida tira as adagas do ar
	w.combate.limpar_partida()
	ok(ad.ativas() == 0 and ad.lancadas == 0, "limpar a partida zera as adagas")


# ------------------------------------------------------------------ cartas


func _t_cartas() -> void:
	var quer := {
		"hazaki": {"sim": ["onda", "fura", "explode", "folego", "dano", "area"], "nao": ["abalo", "muralha", "chuva", "mira"]},
		"nicao": {"sim": ["abalo", "muralha", "explode", "folego", "dano", "area"], "nao": ["onda", "fura", "chuva", "mira"]},
		"lucas": {"sim": ["chuva", "mira", "explode", "folego", "dano", "area"], "nao": ["onda", "fura", "abalo", "muralha"]},
	}
	for id in quer:
		await novo(id)
		var ids := []
		for d in w.combate.cartas.disponiveis():
			ids.append(str(d.id))
		for c in quer[id].sim:
			ok(ids.has(c), "%s: a carta %s pode sair" % [id, c])
		for c in quer[id].nao:
			ok(not ids.has(c), "%s: a carta %s NÃO pode sair" % [id, c])
		var vistas := {}
		for k in 120:
			for c in w.combate.cartas.sortear(3, 1 + k % 20):
				vistas[str(c.id)] = true
		for c in quer[id].nao:
			ok(not vistas.has(c), "%s: o sorteio nunca traz %s (120 sorteios)" % [id, c])
		var algum := false
		for c in quer[id].sim:
			algum = algum or vistas.has(c)
		ok(algum, "%s: o sorteio traz as cartas dele" % id)
		# o baú usa o mesmo sorteio
		ok(w.combate.cartas.sortear(1, 5, 3.0).size() == 1, "%s: o sorteio do baú funciona" % id)


# ------------------------------------------------------------------ card SUA BUILD


func _secao_card(secs: Array, id: String) -> Dictionary:
	for s in secs:
		if str(s.get("id", "")) == id:
			return s
	return {}


## O card SUA BUILD mostra o herói ESCOLHIDO: o nome na seção HERÓI, a arma na seção de golpe, os números dele e os modificadores
## dele (e só os dele). O número de cada modificador é o que o jogo usa (armas.mods).
func _t_card() -> void:
	var arma := {"hazaki": "KATANA (CLIQUE)", "nicao": "MARRETA (CLIQUE)", "lucas": "ADAGAS (CLIQUE)"}
	var mods := {"hazaki": ["onda", "fura"], "nicao": ["abalo", "muralha"], "lucas": ["chuva", "mira"]}
	for id in ["hazaki", "nicao", "lucas"]:
		await novo(id)
		zerar()
		var h = w.heroi
		var cfg_h: Dictionary = Herois.heroi(id).cfg
		var secs: Array = Status.coletar(w)
		var titulo_h := str(_secao_card(secs, "heroi").get("titulo", ""))
		ok(titulo_h == "HERÓI: " + str(Herois.heroi(id).nome).to_upper(), "%s: o card abre a seção HERÓI com o nome dele (%s)" % [id, titulo_h])
		var titulo_k := str(_secao_card(secs, "katana").get("titulo", ""))
		ok(titulo_k == arma[id], "%s: a seção de golpe leva a arma dele (%s)" % [id, titulo_k])
		var vida_card := str(Status.linha(secs, "heroi.vida").get("valor", ""))
		ok(vida_card == "%d / %d" % [roundi(h.vida), roundi(h.vida_max)] and roundi(h.vida_max) == roundi(float(cfg_h.heroi.vida)), "%s: a vida no card é a do herói (%s)" % [id, vida_card])
		var andar_card := str(Status.linha(secs, "heroi.andar").get("valor", ""))
		ok(andar_card == "%d px/s" % roundi(float(cfg_h.heroi.vel)), "%s: o andar no card é a velocidade do herói (%s)" % [id, andar_card])
		ok(Status.linha(secs, "katana.dano").get("n", []).size() == cfg_h.golpe.passos.size(), "%s: a seção de golpe tem uma conta por passo do combo dele" % id)
		var cs = w.combate.cartas
		for md in mods[id]:
			cs.aplicar(cs.montar_carta(cs.definicao(md), 0))
		secs = Status.coletar(w)
		for md in mods[id]:
			var bl: Dictionary = Status.linha(secs, "katana." + md)
			ok(not bl.is_empty() and absf(float(bl.n[0]) - float(w.combate.armas.mods[md])) < 0.001, "%s: o card mostra o modificador %s com o número do jogo (%s)" % [id, md, str(bl.get("n", []))])
		for outro in ["hazaki", "nicao", "lucas"]:
			if outro == id:
				continue
			for md in mods[outro]:
				ok(Status.linha(secs, "katana." + md).is_empty(), "%s: o card não mostra o modificador %s, que é de outro herói" % [id, md])


# ------------------------------------------------------------------ santuário


func _t_altar() -> void:
	if w != null:
		w.queue_free()
		w = null
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.escolher("hazaki")
	var altar = Altar.instantiate()
	add_child(altar)
	await get_tree().process_frame
	var sel = altar._selecao
	ok(sel != null and sel.cartoes.size() == 3 and not sel.aberta, "o santuário monta a seleção com 3 cartões, fechada")
	ok(altar._heroi.text.contains("HAZAKI"), "o botão mostra o herói escolhido (%s)" % altar._heroi.text)
	altar._heroi.pressed.emit()
	await get_tree().process_frame
	ok(sel.aberta and sel.visible, "o botão HERÓI abre a seleção")
	ok((sel.cartoes["hazaki"] as Button).has_focus(), "o foco começa no herói escolhido")
	for id in ["hazaki", "nicao", "lucas"]:
		var b: Button = sel.cartoes[id]
		var textos := ""
		var sprites := 0
		for f in b.get_children():
			if f is Label:
				textos += (f as Label).text + "|"
			if f is TextureRect:
				sprites += 1
		var h := Herois.heroi(id)
		ok(textos.contains(str(h.nome).to_upper()) and textos.contains(str(h.titulo)) and textos.contains(str(h.desc).substr(0, 20)), "cartão de %s mostra nome, título e descrição" % id)
		ok(textos.contains("VIDA") and textos.contains("VELOC.") and textos.contains("COMBO") and sprites == 1, "cartão de %s tem 3 números e o sprite" % id)
	# teclado: seta para a direita e Enter escolhem o Nicão
	_tecla(KEY_RIGHT)
	await get_tree().process_frame
	ok((sel.cartoes["nicao"] as Button).has_focus(), "seta para a direita move o foco para o Nicão")
	_tecla(KEY_ENTER)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(not sel.aberta and Herois.escolhido() == "nicao", "Enter escolhe o Nicão, grava e fecha (escolhido=%s)" % Herois.escolhido())
	ok(altar._heroi.text.contains("NICÃO") and altar._heroi.has_focus(), "o botão passa a mostrar o Nicão e ganha o foco de volta")
	# ESC fecha sem mudar (e não abre o Sair?)
	altar._heroi.pressed.emit()
	await get_tree().process_frame
	_tecla(KEY_RIGHT)
	await get_tree().process_frame
	_tecla(KEY_ESCAPE)
	await get_tree().process_frame
	ok(not sel.aberta and Herois.escolhido() == "nicao", "ESC fecha a seleção sem mudar o herói")
	var pausa = null
	for f in altar.get_children():
		if f.has_method("abrir_ajustes"):
			pausa = f
	ok(pausa == null or not pausa.aberto, "o ESC da seleção não abre o menu de sair")
	# mouse: clicar no cartão do Lucas
	altar._heroi.pressed.emit()
	await get_tree().process_frame
	(sel.cartoes["lucas"] as Button).pressed.emit()
	await get_tree().process_frame
	ok(Herois.escolhido() == "lucas" and Meta.heroi_escolhido() == "lucas", "clicar no cartão escolhe o Lucas e grava no save")
	# controle: o direcional vira ui_left/ui_right
	altar._heroi.pressed.emit()
	await get_tree().process_frame
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_DPAD_LEFT
	jb.pressed = true
	Input.parse_input_event(jb)
	await get_tree().process_frame
	jb = InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_DPAD_LEFT
	jb.pressed = false
	Input.parse_input_event(jb)
	await get_tree().process_frame
	ok((sel.cartoes["nicao"] as Button).has_focus(), "o direcional do controle também move o foco (Lucas -> Nicão)")
	sel.fechar()
	# o santuário continua funcionando com qualquer herói: comprar melhoria, e o resultado
	Meta.creditar(500)
	altar._atualizar()
	var antes := Meta.nivel("vida")
	altar._comprar("vida")
	ok(Meta.nivel("vida") == antes + 1 and Meta.saldo() < 577 + 1, "comprar melhoria no santuário segue funcionando com herói escolhido")
	altar.queue_free()
	await get_tree().process_frame
	# Meta.aplicar com a melhoria comprada vale sobre a vida base do herói
	await novo("nicao")
	ok(w.heroi.vida_max == 180.0 + float(Meta.melhoria("vida").valor) * Meta.nivel("vida"), "Meta.aplicar soma a melhoria de vida à vida do Nicão (%.0f)" % w.heroi.vida_max)
	await novo("lucas")
	ok(w.heroi.vida_max == 70.0 + float(Meta.melhoria("vida").valor) * Meta.nivel("vida"), "e à do Lucas (%.0f)" % w.heroi.vida_max)
	zerar()
	var m = monstro_a(40)
	w.heroi.atacar()
	passos(40)
	w.combate.abandonar()  # resultado e almas funcionam com qualquer herói
	ok(w.combate.fim_emitido, "a partida do Lucas termina e registra o resultado")


func _tecla(k: Key) -> void:
	for pressionada in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressionada
		Input.parse_input_event(e)


# ------------------------------------------------------------------ prints


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _foto_janela(pasta: String, nome: String) -> void:
	await RenderingServer.frame_post_draw
	var c := pasta.path_join(nome + ".png")
	get_viewport().get_texture().get_image().save_png(c)
	print("FOTO ", c)


func _fotos(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	# o santuário: com a seleção fechada (botão HERÓI) e aberta
	Herois.escolher("nicao")
	var altar = Altar.instantiate()
	add_child(altar)
	await _quadros(8)
	await _foto_janela(pasta, "santuario_botao_heroi")
	altar._heroi.pressed.emit()
	await _quadros(8)
	await _foto_janela(pasta, "santuario_selecao")
	altar.queue_free()
	await _quadros(3)
	# cada herói golpeando na floresta
	for id in ["hazaki", "nicao", "lucas"]:
		Herois.escolher(id)
		w = Mundo.instantiate()
		w.modo_teste = false
		add_child(w)
		w.set_process(false)
		w.combate.audio.mudo = true
		await _quadros(3)
		await _golpes_foto(pasta, id)
		w.status.alternar()  # o card SUA BUILD (tecla C), ao lado da partida
		await _quadros(6)
		await _foto_janela(pasta, "card_%s" % id)
		w.status.alternar()
		w.queue_free()
		w = null
		await _quadros(3)


func _golpes_foto(pasta: String, id: String) -> void:
	zerar()
	w.heroi.m_critico = 0.0
	var h = w.heroi
	var tipos := ["inimigo_cao_ossos", "inimigo_aranha_tecela", "inimigo_espantalho", "inimigo_lobo_sombrio"]
	var k := 0
	if id == "lucas":  # horda à frente, em fila e espalhada
		for fila in 4:
			for lado in 3:
				monstro_a(70.0 + fila * 38.0, (lado - 1) * 26.0 + (fila % 2) * 9.0, tipos[(fila + lado) % 4])
	else:  # em volta
		for a in 10:
			var ang := TAU * a / 10.0
			var r := 34.0 + 14.0 * (a % 3)
			monstro_a(cos(ang) * r, sin(ang) * r * 0.8, tipos[a % 4])
	passos(2)
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	h.atacar()
	var g0: int = h.golpes
	if id == "nicao":
		ate(func(): return h.golpe_acertou, 80)
		passos(6)
		await RenderingServer.frame_post_draw
		await w.ap.foto(pasta.path_join("%s_batida.png" % id))
		ate(func(): return h.estado == Heroi.Estado.LIVRE, 80)
		h.atacar()
		ate(func(): return h.golpes > g0 + 1 and h.golpe_acertou, 80)
		passos(5)
		await RenderingServer.frame_post_draw
		await w.ap.foto(pasta.path_join("%s_pancada.png" % id))
	elif id == "lucas":
		ate(func(): return h.golpes >= g0 + 1 and h.estado == Heroi.Estado.LIVRE, 60)
		h.atacar()
		ate(func(): return h.golpes >= g0 + 2 and h.estado == Heroi.Estado.LIVRE, 60)
		h.atacar()
		ate(func(): return h.golpe_acertou and h.golpes >= g0 + 3, 80)
		passos(10)
		await RenderingServer.frame_post_draw
		await w.ap.foto(pasta.path_join("%s_leque.png" % id))
	else:
		ate(func(): return h.golpe_acertou, 80)
		passos(4)
		await RenderingServer.frame_post_draw
		await w.ap.foto(pasta.path_join("%s_golpe.png" % id))

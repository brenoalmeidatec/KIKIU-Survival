extends "res://testes/isolamento_v2.gd"
# LW-6: as cartas do LightWolf que mexem na matriz de defesa e no chamado do mecha (dados/v2_cartas.json: modificadores sifao, ampla e cabo; evolucoes_matriz > aurora_lunar).
# Confere: os dados (3 cartas só do LightWolf, máximo 5, valor x 5 = total; a Aurora Lunar pede Sifão 3 + Ampla 3 e não consome nada; os 4 ícones existem); a carta só sai
# para o LightWolf; o SIFÃO cura 12% do absorvido por nível, limitado por um teto de 8 PV/s (a cesta enche em 1 s) e sem gastar o teto quando a vida está cheia; a AMPLA abre
# 10 graus por nível (e para em 300); o CABO acelera a carga do chamado só no Lobo; a AURORA LUNAR acontece com 3 + 3, deixa as peças valendo, não ocupa vaga no Difícil, dobra a
# cura e o teto e faz da cura que passa da vida cheia um pouco de defesa; largar o Sifão desliga a Aurora; o card de status e o rodapé da carta falam delas.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_lw_cartas.tscn  (imprime "v2_lw_cartas falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Herois := preload("res://v2/herois.gd")
const Status := preload("res://v2/status.gd")
const PASSO := 1.0 / 60.0
const ACHATA := 0.62
var falhas := 0
var w
var cs
var h
var mat


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func perto(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)
		w.combate.efeitos(PASSO)


## Partida nova: mapa sem monstros, mecha parado, mirando para a direita, barra cheia, sem carta nenhuma.
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	h = w.heroi
	cs = w.combate.cartas
	mat = w.combate.matriz
	h.imortal = false
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.escudo_forcado = false
	h.vida = h.vida_max
	h.invenc = 0.0
	h.fonte = h.Fonte.MOUSE
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)
	h.def = h.def_max
	h.def_atraso_t = 0.0
	h.def_quebrado = false
	h.vida = h.vida_max


func dar(id: String, n: int) -> void:
	for k in n:
		cs.aplicar(cs.montar_carta(cs.definicao(id), 0))


## Um ponto no chão a `graus` da mira (para a direita), `dist` px de distância.
func ponto(graus: float, dist := 30.0) -> Vector2:
	var a := deg_to_rad(graus)
	return h.pos + Vector2(cos(a), sin(a) * ACHATA) * dist


func _ready() -> void:
	Herois.forcado = "lightwolf"
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	_t_dados()
	_t_disponibilidade()
	_t_sifao()
	_t_ampla()
	_t_cabo()
	_t_aurora()
	_t_status_e_rodape()
	Herois.forcado = ""
	print("v2_lw_cartas falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _t_dados() -> void:
	zerar()
	var cfg: Dictionary = cs.cfg
	for id in ["sifao", "ampla", "cabo"]:
		var d: Dictionary = cs.definicao(id)
		ok(not d.is_empty() and str(d.mod) == id, "%s: carta de modificador nos dados" % id)
		ok(int(d.max) == 5 and (d.herois as Array) == ["lightwolf"], "%s: máximo 5 e só do LightWolf" % id)
		ok(str(d.get("curto", "")) != "" and str(d.desc).contains("{v}"), "%s: nome curto e texto com o valor" % id)
		ok(w.combate.armas.mods.has(id), "%s: o modificador existe em armas.mods" % id)
		ok(Dados.icone_carta(id) != null and Dados.icone_carta(id, "", true) != null, "%s: ícones de 32 e 16 px" % id)
		ok(Dados.tex(str(d.icone)) != null, "%s: ícone antigo (assets/gerado) carrega" % id)
	ok(
		(
			float(cs.definicao("sifao").valor) * 5.0 == 60.0
			and float(cs.definicao("ampla").valor) * 5.0 == 50.0
			and float(cs.definicao("cabo").valor) * 5.0 == 75.0
		),
		"12%% de cura, 10 graus e 15%% de chamado por nível"
	)
	var au: Dictionary = cs.evolucao_matriz("aurora_lunar")
	ok(not au.is_empty() and (au.consome as Array).is_empty(), "a Aurora Lunar existe e não consome peça")
	ok(au.pecas[0].id == "sifao" and au.pecas[0].nivel == 3 and au.pecas[1].id == "ampla" and au.pecas[1].nivel == 3, "pede Sifão 3 e Ampla 3")
	ok(Dados.icone_carta("aurora_lunar") != null and Dados.icone_carta("aurora_lunar", "", true) != null, "aurora_lunar: ícones de 32 e 16 px")
	ok(cfg.evolucoes.size() == 27, "as 27 fusões ficam como estavam: a Aurora é uma lista à parte")
	var mc: Dictionary = cfg.matriz_cartas
	ok(
		float(mc.sifao_teto_s) == 8.0 and float(mc.arco_max) == 300.0 and float(mc.numero_s) >= 0.5,
		"teto de 8 PV/s, arco até 300 e número de cura no máximo 2 por segundo"
	)


func _t_disponibilidade() -> void:
	zerar()
	for id in ["sifao", "ampla", "cabo"]:
		ok(cs._disponivel(cs.definicao(id)), "%s sai para o LightWolf" % id)
	w.combate.heroi_id = "hazaki"
	for id in ["sifao", "ampla", "cabo"]:
		ok(not cs._disponivel(cs.definicao(id)), "%s não sai para o Hazaki" % id)
	w.combate.heroi_id = "lightwolf"
	var vistos := {}
	for i in 200:
		for c in cs.montar_mao(3, 1.0, 0, 3, false, false):
			vistos[str(c.id)] = true
	ok(vistos.has("sifao") or vistos.has("ampla") or vistos.has("cabo"), "nas mãos sorteadas do LightWolf aparece alguma das três")


func _t_sifao() -> void:
	zerar()
	h.escudo_forcado = true
	passos(3)
	ok(mat.ativa(h), "matriz erguida")
	# sem a carta a matriz não cura
	h.vida = 50.0
	ok(h.levar_dano(10.0, ponto(0)) and is_equal_approx(h.vida, 50.0) and mat.curado == 0.0, "sem Sifão o golpe absorvido não cura")
	dar("sifao", 1)
	ok(is_equal_approx(float(w.combate.armas.mods.sifao), 12.0), "um nível: 12%")
	h.vida = 50.0
	h.invenc = 0.0
	ok(h.levar_dano(20.0, ponto(0)), "o golpe de frente é absorvido")
	ok(perto(h.vida, 52.4, 0.001) and perto(mat.curado, 2.4, 0.001), "cura 12%% de 20 = 2,4 (vida %.3f)" % h.vida)
	ok(float(mat.ultimo.curou) > 2.39, "o último golpe guarda a cura")
	# o que vaza para a vida não cura: a barra só tinha o que tinha
	h.def = 5.0
	h.vida = 50.0
	h.invenc = 0.0
	var vazou: float = mat.absorver(h, 30.0, ponto(0))
	ok(perto(vazou, 25.0, 0.001) and perto(float(mat.ultimo.absorvido), 5.0, 0.001), "só o absorvido (5) conta, o que vazou (25) não")
	ok(perto(h.vida, 50.0 + 0.6, 0.001), "cura 12%% de 5 = 0,6 (vida %.3f)" % h.vida)
	# teto de 8 PV/s: a cesta cheia dá 8 de uma vez e depois nada até encher
	zerar()
	dar("sifao", 4)  # 48%
	ok(is_equal_approx(float(w.combate.armas.mods.sifao), 48.0), "quatro níveis: 48%")
	h.def_max = 1000.0
	h.def = 1000.0
	h.vida = 20.0
	mat.absorver(h, 100.0, ponto(0))
	ok(perto(h.vida, 28.0, 0.001), "100 absorvidos a 48%% pediam 48, o teto deixa 8 (vida %.3f)" % h.vida)
	mat.absorver(h, 100.0, ponto(0))
	ok(perto(h.vida, 28.0, 0.001), "com a cesta vazia o segundo golpe não cura (vida %.3f)" % h.vida)
	passos(30)  # meio segundo do mundo: 4 PV de volta na cesta
	mat.absorver(h, 100.0, ponto(0))
	ok(perto(h.vida, 32.0, 0.05), "meio segundo depois a cesta tem 4 (vida %.3f)" % h.vida)
	passos(120)
	h.vida = 20.0
	mat.absorver(h, 100.0, ponto(0))
	ok(perto(h.vida, 28.0, 0.001), "dois segundos depois a cesta está cheia de novo, mas o teto é 8 (vida %.3f)" % h.vida)
	# vida cheia: nada a curar, a cesta não gasta
	h.vida = h.vida_max
	var cesta0: float = mat._cesta
	mat.absorver(h, 100.0, ponto(0))
	ok(is_equal_approx(h.vida, h.vida_max) and is_equal_approx(mat._cesta, cesta0), "vida cheia: a cura não cabe e o teto não é gasto")
	# o número verde de cura: no máximo 2 por segundo
	ok(float(mat._cfg_cartas().numero_s) >= 0.5, "o número de cura tem intervalo")
	# partida nova zera a conta
	zerar()
	ok(mat.curado == 0.0 and mat.convertido == 0.0 and float(w.combate.armas.mods.sifao) == 0.0, "partida nova zera a cura e a carta")


func _t_ampla() -> void:
	zerar()
	ok(is_equal_approx(mat.arco_graus(), 140.0), "sem Ampla o arco é 140")
	ok(not mat.cobre(h, ponto(80.0)) and mat.cobre(h, ponto(60.0)), "140 graus: 60 entra e 80 fica fora")
	dar("ampla", 3)
	ok(is_equal_approx(mat.arco_graus(), 170.0), "três níveis: 140 + 30 = 170 (%.1f)" % mat.arco_graus())
	ok(mat.cobre(h, ponto(80.0)) and not mat.cobre(h, ponto(95.0)), "170 graus: 80 entra e 95 fica fora")
	# o empurrão vale no arco novo: um monstro a 80 graus só é empurrado depois da Ampla
	h.escudo_forcado = true
	passos(3)
	var m = w.nascer_monstro("inimigo_cao_ossos", ponto(80.0, 36.0))
	m.atordoa_t = 0.0
	m.vida = 5000.0
	m.vida_max = 5000.0
	m.recarga = 99.0
	mat.atualizar(PASSO)
	ok(mat.empurrados == 1, "o monstro a 80 graus está no arco ampliado e é empurrado (%d)" % mat.empurrados)
	w.combate.armas.definir_modificador("ampla", 0.0)
	mat.atualizar(PASSO)
	ok(mat.empurrados == 0, "sem a Ampla ele está fora do arco (%d)" % mat.empurrados)
	# o teto do arco
	w.combate.armas.definir_modificador("ampla", 999.0)
	ok(is_equal_approx(mat.arco_graus(), 300.0), "o arco para em 300 graus (%.1f)" % mat.arco_graus())
	passos(10)  # desenha o arco largo sem erro
	ok(mat.ativa(h), "a matriz segue erguida com o arco largo")
	m.vida = 0.0


func _t_cabo() -> void:
	zerar()
	var c = w.combate
	ok(is_equal_approx(cs.mult_cabo(), 1.0), "sem Cabo o multiplicador é 1")
	dar("cabo", 2)
	ok(is_equal_approx(cs.mult_cabo(), 1.3), "dois níveis: x1,30 (%.3f)" % cs.mult_cabo())
	# no mecha o Q não muda
	h.esp_carga = 0.0
	c.especial.dano(100.0)
	var mecha_carga: float = h.esp_carga
	ok(is_equal_approx(mecha_carga, 100.0 * 0.124), "no mecha o Cabo não mexe na carga do Q (%.2f)" % mecha_carga)
	# no Lobo o chamado enche 30% mais rápido
	h.vida = 10.0
	ok(h.levar_dano(999.0, h.pos + Vector2(20, 0)) and h.forma_lobo, "o mecha quebra e o herói vira Lobo")
	h.invenc = 0.0
	var antes: float = h.esp_carga
	c.especial.dano(100.0)
	ok(is_equal_approx(h.esp_carga - antes, 10.0 * 1.3), "100 de dano = 10 x 1,30 = 13 de chamado (%.2f)" % (h.esp_carga - antes))
	antes = h.esp_carga
	c.especial.abate({"chefe": false, "elite": true, "mare": false})
	ok(is_equal_approx(h.esp_carga - antes, 12.0 * 1.3), "abate de elite: 12 x 1,30 (%.2f)" % (h.esp_carga - antes))
	antes = h.esp_carga
	c.mecha.atualizar(1.0)
	ok(h.esp_carga - antes > 2.5 * 1.3 - 0.01, "o ganho por tempo também sobe (%.2f)" % (h.esp_carga - antes))


func _t_aurora() -> void:
	zerar()
	dar("sifao", 3)
	dar("ampla", 2)
	ok(not cs.evoluidas.has("aurora_lunar") and not cs.aurora_ativa(), "Sifão 3 + Ampla 2 ainda não evolui")
	var n_antes: int = cs.evolucoes_feitas
	dar("ampla", 1)
	ok(cs.evoluidas.has("aurora_lunar") and cs.aurora_ativa(), "Sifão 3 + Ampla 3 viram a Aurora Lunar")
	ok(cs.evolucoes_feitas == n_antes + 1, "conta como evolução feita")
	ok(cs.ativa("sifao") and cs.ativa("ampla") and cs.nivel_de("sifao") == 3 and cs.nivel_de("ampla") == 3, "as duas peças seguem valendo, nada foi consumido")
	ok(float(w.combate.armas.mods.sifao) == 36.0 and float(w.combate.armas.mods.ampla) == 30.0, "e os números delas não mudaram")
	ok(cs.bonus_contados() == 2 and cs.bonus_trocaveis().size() == 2, "a Aurora não ocupa vaga (duas peças = 2)")
	ok(cs.resumo().any(func(r): return str(r.id) == "aurora_lunar"), "o resumo da build mostra a Aurora Lunar")
	# a cura dobra: 36% x 2 = 72%
	h.escudo_forcado = true
	passos(90)  # a evolução para o mundo um instante (hit-stop e câmera lenta): espera a matriz subir
	ok(mat.ativa(h), "matriz erguida depois da evolução")
	h.vida = 50.0
	h.invenc = 0.0
	ok(h.levar_dano(10.0, ponto(0)), "golpe absorvido")
	ok(perto(h.vida, 57.2, 0.001), "Aurora: 36%% x 2 de 10 = 7,2 (vida %.3f)" % h.vida)
	# o teto dobra: 16
	ok(is_equal_approx(mat.teto_cura(), 16.0), "o teto passa a 16 PV/s")
	h.def_max = 1000.0
	h.def = 1000.0
	h.vida = 20.0
	mat._cesta = 99.0
	mat.absorver(h, 100.0, ponto(0))
	ok(perto(h.vida, 36.0, 0.001), "cheia, a cesta dá 16 (vida %.3f)" % h.vida)
	# a cura que passa da vida cheia vira defesa: 50% da sobra
	mat._cesta = 99.0
	h.def_max = 100.0
	h.def = 60.0
	h.vida = h.vida_max - 1.0
	var conv0: float = mat.convertido
	mat.absorver(h, 10.0, ponto(0))  # pede 7,2; cabe 1; sobram 6,2; metade = 3,1 de defesa; a barra gastou 10
	ok(perto(h.vida, h.vida_max, 0.001), "a vida enche")
	ok(perto(mat.convertido - conv0, 3.1, 0.001), "6,2 de sobra viram 3,1 de defesa (%.3f)" % (mat.convertido - conv0))
	ok(perto(h.def, 60.0 - 10.0 + 3.1, 0.001), "a barra gastou 10 e ganhou 3,1 (%.3f)" % h.def)
	# a defesa convertida nunca passa do máximo
	h.def = h.def_max - 1.0
	mat._cesta = 99.0
	h.vida = h.vida_max
	mat.absorver(h, 1.0, ponto(0))
	ok(h.def <= h.def_max + 0.001, "a defesa não passa do máximo")
	# largar o Sifão (troca do Difícil) desliga a Aurora e a cura
	ok(cs.remover_bonus("sifao") and not cs.aurora_ativa(), "largar o Sifão desliga a Aurora")
	h.vida = 50.0
	h.def = 100.0
	mat.absorver(h, 10.0, ponto(0))
	ok(is_equal_approx(h.vida, 50.0), "e a matriz volta a não curar")
	zerar()
	ok(not cs.evoluidas.has("aurora_lunar") and not cs.aurora_ativa() and cs.bonus_contados() == 0, "partida nova zera a Aurora")


func _t_status_e_rodape() -> void:
	zerar()
	dar("sifao", 2)
	dar("ampla", 2)
	dar("cabo", 1)
	var secs: Array = Status.coletar(w)
	for id in ["katana.sifao", "katana.ampla", "katana.cabo"]:
		var l: Dictionary = Status.linha(secs, id)
		ok(not l.is_empty(), "o card de status tem o bloco %s" % id)
	ok(Status.linha(secs, "katana.aurora_lunar").is_empty(), "sem a Aurora o card não mostra a evolução")
	# o rodapé da carta fala da evolução (não de fusão)
	var rodape: String = cs._sinergia_texto("sifao")
	ok(rodape.contains("EVOLUÇÃO") and rodape.contains("Aurora") and not rodape.contains("FUSÃO"), "o rodapé do Sifão avisa a evolução (%s)" % rodape)
	ok(rodape.length() <= cs.LINHA_RODAPE, "e cabe na linha do cartão (%d letras)" % rodape.length())
	ok(cs.evolucoes_com("ampla").size() == 1 and cs.evolucoes_com("ampla")[0].falta.size() == 2, "a dica de status diz o que falta: Sifão e Ampla nv 3")
	dar("sifao", 1)
	dar("ampla", 1)
	secs = Status.coletar(w)
	ok(not Status.linha(secs, "katana.aurora_lunar").is_empty(), "com a Aurora o card mostra a evolução")

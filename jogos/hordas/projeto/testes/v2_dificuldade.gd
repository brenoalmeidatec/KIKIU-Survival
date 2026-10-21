extends Node
## Dificuldade da v2 (#372): regras no Mundo real, pool, diretor/elites, fôlego do ataque e resultado persistido.
## Meta, índice/slots e Config são isolados ANTES do Mundo; nenhum arquivo do jogador é usado como fixture.
## Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_dificuldade.tscn (v2_dificuldade falhas=0).
const Mundo := preload("res://v2/mundo.tscn")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const Herois := preload("res://v2/herois.gd")
const Heroi := preload("res://v2/heroi.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const Colisao := preload("res://v2/colisao.gd")
const SAVE_A := "user://teste_v2_dificuldade_a.cfg"
const SAVE_B := "user://teste_v2_dificuldade_b.cfg"
const INDICE := "user://teste_v2_dificuldade_indice.cfg"
const SLOTS := "user://teste_v2_dificuldade_p_"
const ANTIGO := "user://teste_v2_dificuldade_antigo.cfg"
const OPCOES := "user://teste_v2_dificuldade_opcoes.cfg"
const IDS := ["facil", "medio", "dificil"]
const XP := [1.0, 1.25, 1.6]
const ALMAS := [1.0, 1.25, 1.6]
const VELOCIDADE := [1.0, 1.1, 1.2]
const DENSIDADE := [1.0, 1.25, 1.5]
const ONDA := [1.0, 0.9, 0.8]
const CHEFE := [1.0, 0.95, 0.9]
const CUSTO := [0.0, 0.22, 0.32]
const CALOR := [0.0, 2.0, 3.0]
const PASSO := 1.0 / 60.0
const MONSTRO := "inimigo_cao_ossos"

var falhas := 0
var w
var originais := {}
var protegidos := {}


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func perto(real: float, esperado: float, msg: String, tolerancia := 0.001) -> void:
	ok(absf(real - esperado) <= tolerancia, "%s (%.4f contra %.4f)" % [msg, real, esperado])


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _md5(caminho: String) -> String:
	return FileAccess.get_md5(caminho) if FileAccess.file_exists(caminho) else "ausente"


func _apagar(caminho: String) -> void:
	for sufixo in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(caminho + sufixo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho + sufixo))


func _limpar() -> void:
	for caminho in [SAVE_A, SAVE_B, INDICE, ANTIGO, OPCOES]:
		_apagar(caminho)
	for i in range(1, 5):
		_apagar(SLOTS + "p%d.cfg" % i)


func _isolar() -> void:
	originais = {
		"meta": Meta.caminho_save,
		"indice": Personagens.caminho_indice,
		"slots": Personagens.caminho_base,
		"antigo": Personagens.caminho_antigo,
		"opcoes": Config.arquivo,
		"cfg": Config._cfg,
		"temp": Config._temp.duplicate(true),
		"temp_perfil": Config._temp_perfil,
		"heroi": Herois.forcado
	}
	var arquivos: Array = [Meta.caminho_save, Personagens.caminho_indice, Personagens.caminho_antigo, Config.arquivo]
	for id in Personagens.lista():
		arquivos.append(Personagens.caminho_do_save(str(id)))
	for caminho in arquivos:
		for sufixo in ["", ".bak", ".tmp"]:
			protegidos[str(caminho) + sufixo] = _md5(str(caminho) + sufixo)
	Meta.caminho_save = SAVE_A
	Personagens.caminho_indice = INDICE
	Personagens.caminho_base = SLOTS
	Personagens.caminho_antigo = ANTIGO
	Config.arquivo = OPCOES
	_limpar()
	Config.recarregar()
	Config.g_perfil_temporario("baixo")
	Herois.forcado = "hazaki"


func _restaurar() -> void:
	for caminho in protegidos:
		ok(_md5(caminho) == protegidos[caminho], "arquivo do jogador preservado: " + caminho)
	_limpar()
	Meta.caminho_save = originais.meta
	Personagens.caminho_indice = originais.indice
	Personagens.caminho_base = originais.slots
	Personagens.caminho_antigo = originais.antigo
	Config.arquivo = originais.opcoes
	Config._cfg = originais.cfg
	Config._temp = originais.temp
	Config._temp_perfil = originais.temp_perfil
	Herois.forcado = originais.heroi


func _ready() -> void:
	_isolar()
	_dados_e_saves()
	Meta.caminho_save = SAVE_A
	_apagar(SAVE_A)
	w = Mundo.instantiate()
	w.modo_teste = true
	w.id_mapa = "floresta"
	add_child(w)
	w.set_process(false)
	ok(w.heroi != null and w.combate != null and w.status != null, "Mundo real carregou jogo e interface antes dos casos")
	if w.heroi == null or w.combate == null or w.status == null:
		remove_child(w)
		w.free()
		_restaurar()
		print("v2_dificuldade falhas=%d" % falhas)
		get_tree().quit(1)
		return
	w.combate.audio.mudo = true
	w.args.erase("dificuldade")
	for i in IDS.size():
		_preparar(str(IDS[i]))
		_monstros(i, false)
		_diretor(i, false)
		_chefe(i, false)
		_ataque(i)
		_preparar(str(IDS[i]), true)
		_monstros(i, true)
		_diretor(i, true)
		_chefe(i, true)
	_snapshot_e_resultado()
	_creditos_e_conquistas()
	remove_child(w)
	w.free()
	w = null
	_restaurar()
	print("v2_dificuldade falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _dados_e_saves() -> void:
	ok(Dificuldade.opcoes().map(func(d): return str(d.id)) == IDS, "três dificuldades na ordem Fácil/Médio/Difícil")
	ok(Meta.dificuldade() == "facil" and Dificuldade.normalizar("sumiu") == "facil", "save novo e id inválido usam Fácil")
	ok(Meta.escolher_dificuldade("medio") and Meta.dificuldade() == "medio", "escolha Média é gravada e relida")
	Meta.caminho_save = SAVE_B
	ok(Meta.dificuldade() == "facil", "outro save começa no Fácil")
	ok(Meta.escolher_dificuldade("dificil"), "grava Difícil no segundo save")
	Meta.caminho_save = SAVE_A
	ok(Meta.dificuldade() == "medio", "save A conserva sua escolha independente")
	ok(Meta.escolher_dificuldade("inexistente") and Meta.dificuldade() == "facil", "escolha inválida normaliza e persiste Fácil")
	Meta.caminho_save = SAVE_B
	ok(Meta.dificuldade() == "dificil", "normalização em A não alterou B")
	Meta.caminho_save = SAVE_A
	var corrompido := Meta._ler()
	corrompido.set_value("config", "dificuldade", "removida_dos_dados")
	ok(corrompido.save(SAVE_A) == OK and Meta.dificuldade() == "facil", "valor inválido já presente no save também cai no Fácil")
	var vistos := {}
	for c in Meta.conquistas():
		ok(not vistos.has(str(c.id)), "id de conquista único: " + str(c.id))
		vistos[str(c.id)] = true
		if str(c.id) == "vence_medio":
			ok(str(c.get("mapa", "")) == "medio" and not c.has("dificuldade"), "vence_medio continua sendo a conquista canônica das Ruínas")
	for id in IDS:
		ok(vistos.has("vence_dificuldade_" + str(id)), "conquista própria da dificuldade " + str(id))


func _preparar(id: String, pesadelo := false) -> void:
	Meta.caminho_save = SAVE_A
	_apagar(SAVE_A)
	ok(Meta.escolher_dificuldade(id), "grava dificuldade de preparação " + id)
	if pesadelo:
		Meta.registrar_partida({"venceu": true, "mapa": "floresta", "dificuldade": id, "almas": 0})
		ok(Meta.ligar("modo", "pesadelo", true), "liga Pesadelo sobre " + id)
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = true
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.correr_forcado = false
	w.heroi.escudo_forcado = false
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.heroi.m_critico = -1.0
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	Colisao.limpar()  # fixture aberta: sorteio de nascimento e movimento não dependem das árvores da semente do mapa
	ok(str(Dificuldade.da_partida(w).id) == id and Meta.dificuldade() == id, "partida lê a dificuldade escolhida " + id)
	ok(w.pesadelo() == pesadelo, "Pesadelo é independente da dificuldade " + id)


func _monstros(i: int, pesadelo: bool) -> void:
	var rotulo := "%s pesadelo=%s" % [IDS[i], pesadelo]
	var base: Dictionary = w.combate.cfg.monstros[MONSTRO]
	var m = w.nascer_monstro(MONSTRO, w.heroi.pos + Vector2(200, 0), true)
	var instancia: int = m.get_instance_id()
	for ciclo in 4:
		perto(float(m.xp), float(base.xp) * float(XP[i]), rotulo + " XP do monstro/pool")
		perto(float(m.vel_caca), float(base.vel) * float(VELOCIDADE[i]), rotulo + " velocidade do monstro/pool")
		var pm := Meta.regras_pesadelo() if pesadelo else {}
		perto(float(m.vida_max), float(base.vida) * float(pm.get("vida_mult", 1.0)), rotulo + " vida compõe só Pesadelo")
		perto(float(m.dano), float(base.dano) * float(pm.get("dano_mult", 1.0)), rotulo + " dano compõe só Pesadelo")
		m.esconder()
		w.devolver_monstro(m)
		m = w.nascer_monstro(MONSTRO, w.heroi.pos + Vector2(200, 0), true)
		ok(m.get_instance_id() == instancia, rotulo + " reutilizou o mesmo objeto do pool sem compor multiplicadores")
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false


func _diretor(i: int, pesadelo: bool) -> void:
	var d = w.combate.diretor
	var e = w.combate.elites
	var rotulo := "%s pesadelo=%s" % [IDS[i], pesadelo]
	var dens := float(DENSIDADE[i]) * (float(Meta.regras_pesadelo().densidade_mult) if pesadelo else 1.0)
	perto(d.taxa(0.0), float(d.cfg.taxa_ini) * dens, rotulo + " taxa inicial")
	perto(d.taxa(float(d.cfg.tempo_taxa)), float(d.cfg.taxa_fim) * dens, rotulo + " taxa final")
	ok(d.limite(0.0) == roundi(float(d.cfg.cap_ini) * dens), rotulo + " cap inicial")
	ok(d.limite(float(d.cfg.tempo_cap)) == roundi(float(d.cfg.cap_fim) * dens), rotulo + " cap final")
	ok(d.teto() == roundi(float(d.cfg.teto) * dens), rotulo + " teto total")
	perto(d.proxima_onda, float(d.cfg.onda_cada) * float(ONDA[i]), rotulo + " primeira onda já escalada no reset")
	perto(e.proxima, float(e.cfg.primeira) * float(ONDA[i]), rotulo + " primeira elite já escalada no reset")
	var chefe_mult := float(CHEFE[i]) * (float(Meta.regras_pesadelo().chefe_tempo_mult) if pesadelo else 1.0)
	perto(d.seg_nivel(), float(d.duracao_nivel) * chefe_mult, rotulo + " duração de nível")
	d.avancar_nivel(d.seg_nivel() - 0.001)
	ok(d.nivel == 1, rotulo + " nível não adianta antes do prazo")
	d.avancar_nivel(0.002)
	ok(d.nivel == 2, rotulo + " nível sobe quando o prazo termina")
	d.zerar()
	d.ligado = true
	w.tempo_partida = d.proxima_onda - 0.001
	d.atualizar(0.0)
	ok(d.ondas == 0, rotulo + " nenhuma onda antes do primeiro prazo")
	w.tempo_partida = d.proxima_onda
	d.atualizar(0.0)
	ok(d.ondas == 1 and d.nascidos > 0, rotulo + " primeira onda nasce no prazo")
	perto(d.proxima_onda, 2.0 * float(d.cfg.onda_cada) * float(ONDA[i]), rotulo + " intervalo da segunda onda")
	w.combate.limpar_partida()
	w.tempo_partida = e.proxima - 0.001
	e.atualizar(0.0)
	ok(e.nascidas == 0, rotulo + " nenhuma elite antes do primeiro prazo")
	w.tempo_partida = e.proxima
	e.atualizar(0.0)
	ok(e.nascidas == 1, rotulo + " primeira elite nasce no prazo")
	perto(e.proxima, w.tempo_partida + float(e.cfg.cada) * float(ONDA[i]), rotulo + " intervalo da próxima elite")
	w.combate.limpar_partida()
	w.tempo_partida = 0.0
	d.ligado = true
	d.acum = 1000.0
	d.atualizar(0.0)
	ok(w.monstros.size() == d.limite(0.0), rotulo + " nascimento real para no cap de caçadores")
	# Com cap livre, o teto TOTAL continua limitando o loop de nascimento; cfg do catálogo não é alterado.
	var original: Dictionary = d.cfg
	d.cfg = original.duplicate(true)
	d.cfg.cap_ini = 10000
	d.cfg.cap_fim = 10000
	d.acum = 1000.0
	d.atualizar(0.0)
	ok(w.monstros.size() == d.teto(), rotulo + " nascimento real para no teto total")
	d.cfg = original
	w.combate.limpar_partida()
	d.ligado = false
	w.tempo_partida = 0.0


func _chefe(i: int, pesadelo: bool) -> void:
	var mk: Dictionary = w.combate.diretor.chefes_mapa[0].mk
	var m = w.combate.chefes.nascer(mk, w.heroi.pos + Vector2(200, 0))
	var rotulo := "%s chefe pesadelo=%s" % [IDS[i], pesadelo]
	ok(m != null and m.chefe, rotulo + " nasceu pelo módulo real do chefe")
	perto(m.xp, float(mk.xp) * float(XP[i]), rotulo + " mantém o bônus XP ao substituir os stats da marca")
	perto(m.vel_caca, float(mk.vel) * float(VELOCIDADE[i]), rotulo + " mantém o bônus de velocidade da dificuldade")
	var pm := Meta.regras_pesadelo() if pesadelo else {}
	perto(m.vida_max, float(mk.vida) * float(pm.get("vida_mult", 1.0)), rotulo + " vida do Pesadelo continua composta")
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false


func _ataque(i: int) -> void:
	var h = w.heroi
	var antes := float(h.folego)
	var golpes := int(h.golpes)
	h.atacar()
	passos(1)
	ok(h.golpes == golpes + 1 and h.estado == Heroi.Estado.GOLPE, str(IDS[i]) + " ataque real começa")
	perto(antes - float(h.folego), float(CUSTO[i]), str(IDS[i]) + " custo exato do ataque principal")
	if i == 0:
		passos(35)
		h.folego = 0.0
		h._atraso_t = 1.0  # o fôlego segue zerado no quadro do pedido, sem uma regeneração mascarar a regra do Fácil
		h.atacar()
		passos(1)
		ok(h.golpes == golpes + 2 and h.golpe_calor_t == 0.0, "Fácil permite atacar mesmo sem fôlego e não aquece")
		return
	# A última fração de fôlego ainda permite o golpe que a consome; os seguintes aguardam o calor, com movimento livre.
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	h.imortal = true
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = false
	h.folego = float(CUSTO[i]) / 2.0
	h.atacar()
	passos(1)
	perto(h.folego, 0.0, str(IDS[i]) + " último golpe zera o fôlego")
	perto(h.golpe_calor_t, float(CALOR[i]), str(IDS[i]) + " calor inicial de 2/3 s")
	golpes = int(h.golpes)
	h.entrada_forcada = Vector2.RIGHT
	h.ataque_forcado = true
	var pos: Vector2 = h.pos
	var antecipou := false
	for quadro in floori((float(CALOR[i]) - 0.05) / PASSO):
		passos(1)
		antecipou = antecipou or h.golpes != golpes
	ok(not antecipou, str(IDS[i]) + " ataque segurado não atravessa a trava de calor em nenhum quadro")
	ok((h.pos as Vector2).distance_to(pos) > 20.0, str(IDS[i]) + " calor não bloqueia andar com ataque segurado")
	ok(h.folego > 0.0, str(IDS[i]) + " fôlego recupera durante o calor")
	for quadro in 90:
		if h.golpes > golpes:
			break
		passos(1)
	ok(h.golpes == golpes + 1, str(IDS[i]) + " volta a atacar após recuperar e esfriar")
	h.golpe_calor_t = float(CALOR[i])
	w.reiniciar()
	ok(h.golpe_calor_t == 0.0 and h.folego == h.folego_max, str(IDS[i]) + " reinício limpa calor e recupera fôlego")


func _snapshot_e_resultado() -> void:
	_preparar("medio")
	var foto: Dictionary = Dificuldade.da_partida(w).duplicate(true)
	ok(Meta.escolher_dificuldade("dificil"), "altera preferência durante uma partida Média")
	ok(Dificuldade.da_partida(w) == foto, "mudar o save não altera o snapshot da partida")
	_monstros(1, false)
	w.combate.fim_de_partida(true)
	ok(str(w.resultado.get("dificuldade", "")) == "medio", "sinal real de fim usa a dificuldade da partida e não a preferência nova")
	var r: Dictionary = w.resultado.duplicate(true)
	r.almas = 100
	var entrega := Meta.registrar_partida(r)
	ok(int(entrega.ganhas) == 125 and str(Meta.estado().ultima.dificuldade) == "medio", "crédito e última partida usam o snapshot Médio")
	ok(
		bool(Meta.estado().conquistas.vence_dificuldade_medio) and not bool(Meta.estado().conquistas.vence_dificuldade_dificil),
		"resultado Médio não concede vitória no Difícil"
	)
	ok(Meta.mapa_vencido("floresta") and entrega.novas.has("vence_floresta"), "conquista canônica do mapa sobrevive ao registro antecipado do combate")
	w.reiniciar()
	ok(str(Dificuldade.da_partida(w).id) == "dificil", "a próxima partida passa a usar a preferência nova")


func _creditos_e_conquistas() -> void:
	for i in IDS.size():
		for pesadelo in [false, true]:
			for melhorada in [false, true]:
				_apagar(SAVE_A)
				Meta.caminho_save = SAVE_A
				Meta.escolher_dificuldade("dificil" if i == 0 else "facil")  # diferente do resultado de propósito
				if melhorada:
					Meta.creditar(1000)
					ok(Meta.comprar("almas") and Meta.comprar("almas"), "compra real de dois níveis de Almas abundantes")
				var antes := Meta.saldo()
				var r := {"venceu": true, "mapa": "floresta", "dificuldade": IDS[i], "almas": 1000, "pesadelo": pesadelo}
				var resultado := Meta.registrar_partida(r)
				var mult := float(ALMAS[i]) * (float(Meta.regras_pesadelo().almas_mult) if pesadelo else 1.0)
				var bonus := 1.16 if melhorada else 1.0
				var esperado := roundi(1000.0 * mult * bonus)
				ok(
					int(resultado.ganhas) == esperado and Meta.saldo() == antes + esperado,
					"%s almas x dificuldade/Pesadelo/melhoria (%s/%s)" % [IDS[i], pesadelo, melhorada]
				)
				ok(str(Meta.estado().ultima.dificuldade) == str(IDS[i]), "última dificuldade vem do resultado explícito")
				for j in IDS.size():
					ok(
						bool(Meta.estado().conquistas["vence_dificuldade_" + str(IDS[j])]) == (i == j),
						"vitória concede somente sua dificuldade: %s -> %s" % [IDS[i], IDS[j]]
					)
				ok(Meta.mapa_vencido("floresta"), "vitória por dificuldade continua concedendo a conquista canônica da Floresta")
				var cf := Meta._ler()
				ok(bool(cf.get_value("dificuldades_vencidas", "floresta_" + str(IDS[i]), false)), "mapa/dificuldade vencidos persistem separados")
	_apagar(SAVE_A)
	Meta.escolher_dificuldade("dificil")
	Meta.registrar_partida({"venceu": true, "mapa": "medio", "almas": 0})
	ok(Meta.mapa_vencido("medio") and bool(Meta.estado().conquistas.vence_medio), "resultado legado mantém a vitória canônica das Ruínas")
	ok(str(Meta.estado().ultima.get("dificuldade", "")) == "", "última partida legada não inventa dificuldade Fácil")
	for id in IDS:
		ok(not bool(Meta.estado().conquistas["vence_dificuldade_" + str(id)]), "resultado legado sem dificuldade não inventa vitória " + str(id))
		ok(
			not bool(Meta._ler().get_value("dificuldades_vencidas", "medio_" + str(id), false)),
			"resultado legado não inventa histórico de dificuldade vencida " + str(id)
		)

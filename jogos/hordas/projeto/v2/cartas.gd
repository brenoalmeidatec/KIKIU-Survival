extends RefCounted
## As cartas da v2 (leva 3): montagem de build. Sorteia cartas com RARIDADE (comum, raro, épico, lendário; a chance das altas sobe com o
## nível), aplica melhorias de stat, golpes secundários automáticos (v2/armas.gd), modificadores da katana e as EVOLUÇÕES (duas peças viram
## uma versão evoluída). Tudo vem de dados/v2_cartas.json (veja o `_ajuda` de lá).
## As 5 melhorias da RUPTURA (tecla E) vêm de dados/v2_ruptura.json > cartas, entram aqui com cat "rb" e sorteiam, evoluem de raridade e
## aparecem no resumo como as outras (o ramo "rb" de aplicar soma o valor e avisa combate.ruptura.definir).
##
## Uma carta é um Dictionary: {id, icone (nome do PNG em assets/gerado/), nome, desc (já com o valor), cat ("stat", "golpe" ou "mod"), rar (0 a 3),
## rar_nome, cor (Color), valor (stat/mod/rb, já multiplicado pela raridade), max, nivel_atual, nivel_novo, proximo, nivel_txt, evolui, stat,
## tipo ("up" = sobe um bônus que o herói já tem; "nov" = bônus novo; "troca" = bônus novo com as vagas cheias (limite do Difícil): escolher abre o
## painel para o jogador largar um bônus; o cartão mostra o selo UPGRADE, NOVO ou TROCA)}.
## O cartão (telas.gd) mostra nessa ordem: raridade e tecla, ícone, nome, desc, proximo e, no rodapé, nivel_txt e evolui.

const Armas := preload("res://v2/armas.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const LINHA_RODAPE := 29  # letras que cabem no rodapé do cartão (Spleen 8x16 em 16 px: 8 px por letra, 232 px de largura)

var combate
var cfg: Dictionary = {}
var rar: Array = []
var rng := RandomNumberGenerator.new()
var estado := {}  # id -> {n: vezes que pegou, bonus: dano extra do golpe pela raridade, soma: valor acumulado (mod), usada: virou parte de evolução}
var evoluidas: Array = []  # ids das evoluções já feitas
var evolucoes_feitas := 0
var lendarias_feitas := 0  # só uma lendária por partida
var vistas: Array = []  # as últimas rodadas de cartas (listas de ids oferecidos): a novidade não repete o que acabou de passar (escolha.vistas_rodadas)
var descartadas: Array = []  # ids de bônus que o jogador largou (a troca do Difícil, CAR-4): a novidade nunca os oferece de novo
var _def := {}  # id -> definição (stat, golpe ou modificador)
var _cat := {}


func montar(c) -> void:
	combate = c
	cfg = Dados.json("v2_cartas")
	rar = cfg.raridades
	for d in cfg.stats:
		_def[d.id] = d
		_cat[d.id] = "stat"
	for d in cfg.golpes:
		_def[d.id] = d
		_cat[d.id] = "golpe"
	for d in cfg.modificadores:
		_def[d.id] = d
		_cat[d.id] = "mod"
	for d in Dados.json("v2_ruptura").get("cartas", []):  # a ruptura da tecla E (v2/ruptura.gd)
		_def[d.id] = d
		_cat[d.id] = "rb"
	rng.randomize()


func zerar() -> void:
	estado.clear()
	evoluidas.clear()
	evolucoes_feitas = 0
	lendarias_feitas = 0
	vistas.clear()
	descartadas.clear()
	rng.randomize()


# ------------------------------------------------------------------ raridade


## Peso do sorteio da raridade `i` no nível `nivel`: anda em linha reta do peso_ini (nível 1) ao peso_fim (nível `nivel_fim`).
func peso_raridade(i: int, nivel: int) -> float:
	var k := clampf(float(nivel - 1) / maxf(float(int(cfg.nivel_fim) - 1), 1.0), 0.0, 1.0)
	return lerpf(float(rar[i].peso_ini), float(rar[i].peso_fim), k)


## Chance (0 a 1) de sair a raridade `i` no nível `nivel`, com `bonus` multiplicando o peso das raridades acima da comum (o baú usa).
func chance_raridade(i: int, nivel: int, bonus := 1.0) -> float:
	var total := 0.0
	for j in rar.size():
		total += peso_raridade(j, nivel) * (bonus if j > 0 else 1.0)
	return peso_raridade(i, nivel) * (bonus if i > 0 else 1.0) / total


func sortear_raridade(nivel: int, bonus := 1.0) -> int:
	var r := rng.randf()
	var saiu := 0
	for j in rar.size():
		r -= chance_raridade(j, nivel, bonus)
		if r < 0.0:
			saiu = j
			break
	# "Olho para o raro" do santuário (mundo.meta_bonus.raridade, fração): chance de uma comum subir para rara
	if saiu == 0 and rng.randf() < meta("raridade"):
		saiu = 1
	return saiu


## Bônus do santuário (v2/meta.gd) lidos do mundo com valor padrão 0: raridade (fração) e almas (fração).
func meta(nome: String) -> float:
	var mb = combate.mundo.get("meta_bonus")
	if mb == null or not (mb is Dictionary):
		return 0.0
	return float(mb.get(nome, 0.0))


# ------------------------------------------------------------------ estado e sorteio


func definicao(id: String) -> Dictionary:
	return _def.get(id, {})


func nivel_de(id: String) -> int:
	return int(estado.get(id, {}).get("n", 0))


func ativa(id: String) -> bool:
	return nivel_de(id) > 0 and not bool(estado.get(id, {}).get("usada", false))


func _disponivel(d: Dictionary) -> bool:
	var id := str(d.id)
	if bool(estado.get(id, {}).get("usada", false)):
		return false
	if bool(d.get("oculta_ate_ter_efeito", false)):  # escondida até ter efeito real (dados/v2_cartas.json, _ajuda)
		return false
	if d.has("herois") and not (d.herois as Array).has(combate.heroi_id):  # carta de um herói só: não aparece para os outros
		return false
	return nivel_de(id) < int(d.max)


## Quantas cartas ainda poderiam sair (testes).
func disponiveis() -> Array:
	var r: Array = []
	for id in _def:
		if _disponivel(_def[id]):
			r.append(_def[id])
	return r


## Peso extra de cada carta que ajuda a fechar uma evolução (as outras peças já foram pegas): {id: peso}; quem não está aqui pesa 1.
## Uma passada pelas evoluções por sorteio (antes era uma por carta: ~4 ms em toda subida de nível).
func _pesos_sinergia() -> Dictionary:
	var r := {}
	var peso := float(cfg.escolha.peso_sinergia)
	for ev in cfg.evolucoes:
		if not _evo_livre(ev):
			continue
		var tem := 0
		for p in ev.pecas:
			if nivel_de(str(p.id)) > 0:
				tem += 1
		for p in ev.pecas:
			var outras := tem - (1 if nivel_de(str(p.id)) > 0 else 0)
			if outras >= ev.pecas.size() - 1:
				r[str(p.id)] = peso
	return r


## Evolução que ainda pode acontecer: não feita e, se for lendária, só enquanto nenhuma foi feita nesta partida.
func _evo_livre(ev: Dictionary) -> bool:
	if evoluidas.has(ev.id):
		return false
	return not (str(ev.get("raridade", "")) == "lendario" and lendarias_feitas >= 1)


## O aviso do rodapé da carta: "Aura nv3 » FUSÃO Anel", a receita inteira à vista antes da fusão. Cabe numa linha de 16 px (a Spleen
## 8x16 cabe LINHA_RODAPE letras): nome curto da peça e da fusão, "+N" quando sobram peças, e sem "FUSÃO" se ainda assim não cabe.
func _sinergia_texto(id: String) -> String:
	var ev := _sinergia_ev(id)
	if ev.is_empty():
		return ""
	var outras: Array = []
	for p in ev.pecas:
		if str(p.id) != id:
			outras.append(p)
	var fusao := str(ev.get("curto", ev.nome))
	var texto: String
	if outras.size() == 1:
		texto = "%s nv%d » FUSÃO %s" % [_curto(str(outras[0].id)), int(outras[0].nivel), fusao]
	else:
		texto = "%s +%d » FUSÃO %s" % [_curto(str(outras[0].id)), outras.size() - 1, fusao]
	if texto.length() > LINHA_RODAPE:  # sem a palavra FUSÃO quando não cabe: a fusão já aparece no nome
		texto = texto.replace("FUSÃO ", "")
	if texto.length() > LINHA_RODAPE:  # última saída: só a primeira palavra da peça e da fusão ("Guerreiro » Exército")
		texto = "%s » %s" % [_curto(str(outras[0].id)).split(" ")[0], fusao.split(" ")[0]]
	return texto


## Nome curto de uma peça: o `curto` do dado (o do card compacto), ou a primeira palavra do nome (Flechas Sombrias: Flechas).
func _curto(id: String) -> String:
	return str(_def[id].get("curto", str(_def[id].nome).split(" ")[0]))


## O id da fusão (ainda livre) que esta peça ajuda a fechar, ou "" (a tela de cartas aquece a arte dela antes: telas._aquecer_invocacoes).
func fusao_de(id: String) -> String:
	return str(_sinergia_ev(id).get("id", ""))


## A evolução (ainda livre) que esta peça ajuda a fechar, ou {} se nenhuma.
func _sinergia_ev(id: String) -> Dictionary:
	for ev in cfg.evolucoes:
		if not _evo_livre(ev):
			continue
		for p in ev.pecas:
			if p.id == id:
				return ev
	return {}


## Evoluções ainda não feitas que usam a peça `id` (o card de status mostra): [{nome, falta, perdida}], onde `falta` lista as peças que ainda
## não estão no nível pedido ("Aura de Fogo nv 3") e `perdida` as que NÃO CHEGAM MAIS lá (já gasta em outra evolução),
## cada uma como "Lâminas Rodopiantes já evoluiu em outra": se não está vazia, a evolução é impossível. Vazio = a peça não entra em evolução
## nenhuma, ou a evolução dela já aconteceu.
func evolucoes_com(id: String) -> Array:
	var r: Array = []
	for ev in cfg.evolucoes:
		if evoluidas.has(ev.id):
			continue
		var usa := false
		var falta: Array = []
		var perdida: Array = []
		for p in ev.pecas:
			if str(p.id) == id:
				usa = true
			if not _peca_ok(p):
				var nome := str(_def[str(p.id)].nome)
				falta.append("%s nv %d" % [nome, int(p.nivel)])
				if bool(estado.get(str(p.id), {}).get("usada", false)):
					perdida.append("%s já evoluiu em outra" % nome)
		if usa:
			r.append({"nome": str(ev.nome), "falta": falta, "perdida": perdida})
	return r


func golpes_ativos() -> int:
	var n := 0
	for d in cfg.golpes:
		if ativa(str(d.id)):
			n += 1
	return n


## A MÃO de cartas da escolha de nível e do baú: `escolha.cartas` (3) cartas diferentes em dois tipos, [upgrade, upgrade, novidade]. UPGRADE = bônus
## que o herói já tem (nível > 0) e ainda não está no máximo; NOVIDADE = bônus de nível 0 que não saiu nas últimas `escolha.vistas_rodadas` rodadas
## (`vistas`) nem foi descartado (`descartadas`). Assim a carta só repete quando aumenta um bônus que o jogador já tem. Sem candidato de um tipo,
## o espaço vira o outro tipo; sem nenhum, a mão fica menor (quem abre a escolha completa com a cura, progresso.abrir_escolha). No começo da
## partida (nenhum bônus) são 3 novidades. `bonus` = quanto o baú favorece as raridades altas e `piso` = a menor raridade que pode sair (o baú dá
## `bau.piso_raridade`, 1 = nunca comum). Até o nível `garantir_golpe_ate`, quem ainda não tem nenhum golpe secundário vê pelo menos um na mão
## (o começo da build). `registrar` guarda a mão em `vistas` (o roteiro de fotos e o atalho `sortear` não guardam). Com as vagas cheias (`cheio`,
## limite do Difícil): `com_troca` mantém a novidade, que sai marcada "troca" (a escolha de nível aceita, o jogador larga um bônus para pegá-la); sem
## `com_troca` (o baú, o atalho `sortear`) a novidade não cabe e o espaço vira upgrade.
func montar_mao(nivel: int, bonus := 1.0, piso := 0, n := -1, registrar := true, com_troca := false) -> Array:
	if n < 0:
		n = int(cfg.escolha.cartas)
	var sinergia := _pesos_sinergia()
	var recentes := _ids_vistos()
	var vagas := vagas_livres()  # quantas novidades ainda cabem (999 sem limite); sem `com_troca` a mão nunca passa disso
	var sem_novidade := vagas <= 0 and not com_troca
	var ups: Array = []
	var pesos_up: Array = []
	var novs: Array = []
	var pesos_nov: Array = []
	for id in _def:
		var d: Dictionary = _def[id]
		if not _disponivel(d):
			continue
		var peso := float(d.get("peso", 1.0)) * float(sinergia.get(str(id), 1.0))
		if nivel_de(str(id)) > 0:
			ups.append(d)
			pesos_up.append(peso)
		elif not sem_novidade and not descartadas.has(str(id)) and not recentes.has(str(id)):
			novs.append(d)
			pesos_nov.append(peso)
	var quer_nov := 0 if n < 2 else clampi(int(cfg.escolha.get("mao_novidades", 1)), 0, n)
	var escolhidas: Array = []
	for k in n:
		var e_nov := k >= n - quer_nov  # os últimos espaços da mão são as novidades
		var d: Dictionary
		if e_nov:
			d = _tirar(novs, pesos_nov) if not novs.is_empty() else _tirar(ups, pesos_up)
		else:
			d = _tirar(ups, pesos_up) if not ups.is_empty() else _tirar(novs, pesos_nov)
		if d.is_empty():
			break
		escolhidas.append(d)
		if nivel_de(str(d.id)) == 0:  # uma novidade ocupa uma vaga: acabaram, as outras viram upgrade (o baú aplica a mão inteira, ou várias pegas)
			vagas -= 1
			if vagas <= 0 and not com_troca:
				novs.clear()
				pesos_nov.clear()
	if (
		nivel <= int(cfg.escolha.garantir_golpe_ate)
		and golpes_ativos() == 0
		and not escolhidas.is_empty()
		and (com_troca or vagas > 0 or nivel_de(str(escolhidas[-1].id)) == 0)
	):
		var tem := false
		for d in escolhidas:
			if _cat[d.id] == "golpe":
				tem = true
		if not tem:
			var gs: Array = []
			for d in cfg.golpes:
				if _disponivel(d) and not descartadas.has(str(d.id)) and not recentes.has(str(d.id)):
					gs.append(d)
			if not gs.is_empty():
				escolhidas[escolhidas.size() - 1] = gs[rng.randi() % gs.size()]
	var cartas: Array = []
	for d in escolhidas:
		cartas.append(montar_carta(d, maxi(sortear_raridade(nivel, bonus), piso)))
	if registrar:
		registrar_mao(cartas)
	return cartas


## Guarda em `vistas` a mão que o jogador VIU (a novidade não repete o que passou nas últimas `escolha.vistas_rodadas` rodadas). Quem monta
## a mão e não a mostra não chama isto: o baú só registra quando abre a escolha (bau._abrir_escolha, CAR-2, ressalva 1).
func registrar_mao(mao: Array) -> void:
	var ids: Array = []
	for c in mao:
		ids.append(str(c.id))
	vistas.append(ids)
	while vistas.size() > int(cfg.escolha.get("vistas_rodadas", 2)):
		vistas.pop_front()


## O atalho antigo: `n` cartas pelo mesmo critério da mão (upgrade e novidade) sem guardar nada em `vistas`. O baú que entrega de graça e o roteiro
## de fotos usam; a escolha de nível e a do baú com escolha chamam `montar_mao`.
func sortear(n: int, nivel: int, bonus := 1.0, piso := 0) -> Array:
	return montar_mao(nivel, bonus, piso, n, false)


## Tira uma carta da lista pelo peso (e a tira também da lista de pesos). Lista vazia devolve {}.
func _tirar(cand: Array, pesos: Array) -> Dictionary:
	if cand.is_empty():
		return {}
	var total := 0.0
	for p in pesos:
		total += float(p)
	var r := rng.randf() * total
	var i := 0
	while i < cand.size() - 1:
		r -= float(pesos[i])
		if r < 0.0:
			break
		i += 1
	var d: Dictionary = cand[i]
	cand.remove_at(i)
	pesos.remove_at(i)
	return d


## Os ids das últimas rodadas de cartas (as novidades não voltam).
func _ids_vistos() -> Dictionary:
	var r := {}
	for rodada in vistas:
		for id in rodada:
			r[str(id)] = true
	return r


## ESCOLHA AUTOMÁTICA (botão do meio, Y, Q e o tempo esgotado): escolhe DENTRO DA MÃO que está na tela (`mao`), pelo que o herói já tem.
## Upgrade de golpe = (máximo - nível) x auto_peso_golpe + fusão + peso da carta; stat, modificador e ruptura = auto_base + (máximo - nível) x
## auto_peso_bonus + fusão. Assim a arma menos evoluída ganha, e uma fusão que fecha (auto_fusao_fecha) ainda vence. Nunca leva um bônus além de
## auto_nivel_max (o 5/5 é de quem escolhe à mão, e o automático nunca gasta ÁPICE). Novidade só entra com menos de auto_golpes_alvo golpes e sem
## golpe ativo abaixo de auto_novidade_nivel. A cura da mão (sem definição) fica de fora. A raridade sai rebaixada: auto_queda degraus, no máximo
## auto_raridade_max (o automático não traz épica nem lendária). Devolve a carta pronta (montar_carta), ou {} se nada da mão serve.
func escolha_automatica(mao: Array) -> Dictionary:
	var e: Dictionary = cfg.escolha
	var melhor := -1
	var melhor_nota := -1.0e9
	var novidade_ok := _novidade_liberada()
	for i in mao.size():
		var id := str(mao[i].get("id", ""))
		if not _def.has(id) or not _disponivel(_def[id]):
			continue
		var n := nivel_de(id)
		if n + 1 > int(e.auto_nivel_max) or (n == 0 and not novidade_ok):
			continue
		var cheio := int(_def[id].max)
		var nota: float
		if _cat[id] == "golpe":
			nota = float(cheio - n) * float(e.auto_peso_golpe) + float(_def[id].get("peso", 1.0))
		else:
			nota = float(e.auto_base) + float(cheio - n) * float(e.auto_peso_bonus)
		nota += _nota_fusao(id) + rng.randf() * float(e.auto_acaso)
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = i
	if melhor < 0:
		return {}
	var escolhida: Dictionary = _def[str(mao[melhor].get("id", ""))]
	var r := clampi(int(mao[melhor].get("rar", 0)) - int(e.auto_queda), 0, int(e.auto_raridade_max))
	return montar_carta(escolhida, r)


## A carta `c` serve ao tempo esgotado: não é TROCA (o automático nunca troca) e não leva o bônus além de auto_nivel_max (D26). A cura da mão serve.
func serve_ao_automatico(c: Dictionary) -> bool:
	return str(c.get("tipo", "")) != "troca" and int(c.get("nivel_novo", 0)) <= int(cfg.escolha.auto_nivel_max)


## Novidade no automático: só com menos de auto_golpes_alvo golpes ativos, nenhum golpe ativo abaixo de auto_novidade_nivel e vaga no limite de bônus
## do Difícil (o automático nunca troca: largar um bônus é de quem escolhe à mão).
func _novidade_liberada() -> bool:
	var e: Dictionary = cfg.escolha
	if cheio():
		return false
	if golpes_ativos() >= int(e.auto_golpes_alvo):
		return false
	for d in cfg.golpes:
		if ativa(str(d.id)) and nivel_de(str(d.id)) < int(e.auto_novidade_nivel):
			return false
	return true


## Bônus de fusão da peça `id`: 0 se não fecha nada; auto_fusao_ajuda se as outras peças já estão no nível pedido; auto_fusao_fecha se, além
## disso, esta carta sozinha leva a peça ao nível pedido (a fusão acontece na hora).
func _nota_fusao(id: String) -> float:
	var ev := _sinergia_ev(id)
	if ev.is_empty():
		return 0.0
	var minha := 0
	for p in ev.pecas:
		if str(p.id) == id:
			minha = int(p.nivel)
		elif not _peca_ok(p):
			return 0.0
	return float(cfg.escolha.auto_fusao_fecha) if nivel_de(id) + 1 >= minha else float(cfg.escolha.auto_fusao_ajuda)


## A carta `d` na raridade `r`: texto com o valor da raridade e o que o nível novo traz.
func montar_carta(d: Dictionary, r: int) -> Dictionary:
	var id := str(d.id)
	var cat: String = _cat[id]
	var ra: Dictionary = rar[r]
	var n := nivel_de(id)
	var c := {
		"id": id,
		"icone": str(d.get("icone", "")),
		"nome": d.nome,
		"cat": cat,
		"rar": r,
		"rar_nome": ra.nome,
		"cor": Color(ra.cor[0], ra.cor[1], ra.cor[2]),
		"max": int(d.max),
		"nivel_atual": n,
		"nivel_novo": n + 1,
		"valor": 0.0,
		"stat": str(d.get("stat", "")),
		"desc": "",
		"proximo": "",  # linha abaixo da descrição: o que o golpe ganha no próximo nível (ou o bônus da raridade)
		"tipo": "up" if n > 0 else ("troca" if cheio() else "nov"),  # o selo do cartão: UPGRADE (já tenho), NOVO ou TROCA (novo, mas as vagas estão cheias)
		"nivel_txt": "",  # rodapé: "Nível 2 » 3 de 5" (upgrade), "Novo golpe" ou "Novo bônus"
		"evolui": ""  # rodapé: "Evolui: ..." quando esta peça fecha uma evolução
	}
	var bonus_pct := roundi(float(ra.bonus_arma) * 100.0)
	if cat == "golpe":
		var sobe := 2 if r == rar.size() - 1 else 1
		c.nivel_novo = mini(n + sobe, int(d.max))
		c.desc = str(d.desc)
		var ni: int = c.nivel_novo
		if n == 0:
			c.nivel_txt = "Novo golpe"
			if ra.bonus_arma > 0.0:
				c.proximo = "+%d%% de dano pela raridade" % bonus_pct
		else:
			c.nivel_txt = "Nível %d » %d de %d" % [n, ni, int(d.max)]
			var partes: Array = []
			for k in range(n, ni):
				partes.append(str(d.niveis[k - 1].texto))
			c.proximo = "Próximo: %s" % ", ".join(partes)
			if ra.bonus_arma > 0.0:
				c.proximo += " (+%d%% de dano)" % bonus_pct
	else:
		c.valor = float(d.valor) * float(ra.mult)
		c.desc = str(d.desc).replace("{v}", str(roundi(float(c.valor))))
		c.nivel_txt = "Nível %d » %d de %d" % [n, n + 1, int(d.max)] if n > 0 else "Novo bônus"
	if c.tipo == "troca":
		c.nivel_txt = "Cheio: escolha quem sai"
	var sin := _sinergia_texto(id)
	if sin != "" and cat != "stat":
		c.evolui = sin
		c.lendaria = str(_sinergia_ev(id).get("raridade", "")) == "lendario"
	return c


# ------------------------------------------------------------------ aplicar


func aplicar(c: Dictionary) -> void:
	var h = combate.mundo.heroi
	var id := str(c.id)
	var cat := str(c.get("cat", "stat"))
	if not _def.has(id):  # a carta Cura ("Alma renovada": progresso._carta_cura, o baú): não é um bônus, não ocupa vaga nem entra em `estado`
		_aplicar_stat(h, str(c.get("stat", "")), float(c.get("valor", 0.0)))
		return
	if not estado.has(id):
		estado[id] = {"n": 0, "bonus": 0.0, "soma": 0.0, "usada": false}
	var e: Dictionary = estado[id]
	var d: Dictionary = _def.get(id, {})
	match cat:
		"golpe":
			var ni: int = int(c.get("nivel_novo", e.n + 1))
			e.n = clampi(ni, 1, int(d.max))
			e.bonus = float(e.bonus) + float(rar[int(c.get("rar", 0))].bonus_arma)
			combate.armas.definir_golpe(id, int(e.n), float(e.bonus))
		"mod":
			e.n = int(e.n) + 1
			e.soma = float(e.soma) + float(c.get("valor", d.valor))
			combate.armas.definir_modificador(str(d.mod), float(e.soma))
		"rb":
			e.n = int(e.n) + 1
			e.soma = float(e.soma) + float(c.get("valor", d.valor))
			combate.ruptura.definir(str(d.chave), float(e.soma))
		_:
			e.n = int(e.n) + 1
			e.soma = float(e.soma) + float(c.get("valor", 0.0))  # a soma aplicada: a troca no Difícil (CAR-4) desfaz por ela
			_aplicar_stat(h, str(c.get("stat", "")), float(c.get("valor", 0.0)))
	combate.progresso.melhorias[id] = int(e.n)
	_checar_evolucoes()


func _aplicar_stat(h, stat: String, v: float) -> void:
	match stat:
		"dano":
			h.m_dano += v / 100.0
		"vel_ataque":
			h.m_vel_ataque += v / 100.0
		"area":
			h.m_area += v / 100.0
		"vel_mov":
			h.m_vel_mov += v / 100.0
		"vida":
			h.vida_max += v
			h.curar(v)
		"ima":
			h.m_ima += v / 100.0
		"critico":
			h.m_critico += v / 100.0
		"cura":
			h.curar(h.vida_max)
			h.repor_defesa_de("carta_cura")  # a carta Cura enche a barra do escudo


# ------------------------------------------------------------------ limite de bônus e troca (Difícil, CAR-4)


## O limite de bônus distintos desta partida (dados/v2_dificuldade.json > limite_bonus). 0 = sem limite.
func limite_bonus() -> int:
	return Dificuldade.limite_bonus(combate.mundo)


## Os bônus que o herói tem agora, na ordem em que os pegou: nível acima de 0 e não consumidos por uma fusão. É a lista do painel de troca.
func bonus_trocaveis() -> Array:
	var r: Array = []
	for id in estado:
		if ativa(str(id)):
			r.append(str(id))
	return r


## Quantas vagas de bônus estão ocupadas: os bônus de `bonus_trocaveis` e cada fusão feita (conta 1; as peças consumidas deixam de contar).
func bonus_contados() -> int:
	return bonus_trocaveis().size() + evoluidas.size()


## Quantos bônus novos ainda cabem no limite (999 sem limite). Nunca negativo.
func vagas_livres() -> int:
	var lim := limite_bonus()
	return 999 if lim <= 0 else maxi(lim - bonus_contados(), 0)


## As vagas estão cheias: há limite e o herói já chegou nele. Aí um bônus novo só entra largando outro (`remover_bonus`).
func cheio() -> bool:
	var lim := limite_bonus()
	return lim > 0 and bonus_contados() >= lim


## Larga o bônus `id` por inteiro e desfaz o efeito dele: golpe sai do herói, modificador e ruptura voltam a 0 e o stat subtrai a `soma` aplicada
## (a vida máxima cai e a vida atual não passa da nova). O id vai para `descartadas`: a novidade nunca o oferece de novo. Devolve false se
## `id` não é um bônus trocável (não tem, ou já foi consumido por fusão).
func remover_bonus(id: String) -> bool:
	if not ativa(id):
		return false
	var e: Dictionary = estado[id]
	var d: Dictionary = _def[id]
	match _cat[id]:
		"golpe":
			combate.armas.remover(id)
		"mod":
			combate.armas.definir_modificador(str(d.mod), 0.0)
		"rb":
			combate.ruptura.definir(str(d.chave), 0.0)
		_:
			var h = combate.mundo.heroi
			var v := float(e.soma)
			if str(d.get("stat", "")) == "vida":
				h.vida_max -= v
				h.vida = minf(h.vida, h.vida_max)
			else:
				_aplicar_stat(h, str(d.get("stat", "")), -v)
	e.n = 0
	e.bonus = 0.0
	e.soma = 0.0
	combate.progresso.melhorias.erase(id)
	if not descartadas.has(id):
		descartadas.append(id)
	return true


# ------------------------------------------------------------------ evolução


func _peca_ok(p: Dictionary) -> bool:
	return ativa(str(p.id)) and nivel_de(str(p.id)) >= int(p.nivel)


## Confere se alguma evolução ficou pronta (as duas peças no nível pedido) e faz acontecer. Devolve o nome da última feita, ou "".
func _checar_evolucoes() -> String:
	var feita := ""
	for ev in cfg.evolucoes:
		if evoluidas.has(ev.id):
			continue
		if not _evo_livre(ev):
			continue
		var pronta := true
		for p in ev.pecas:
			if not _peca_ok(p):
				pronta = false
		if not pronta:
			continue
		evoluir(ev)
		feita = str(ev.nome)
	return feita


func evoluir(ev: Dictionary) -> void:
	evoluidas.append(ev.id)
	evolucoes_feitas += 1
	if str(ev.get("raridade", "")) == "lendario":
		lendarias_feitas += 1
	var bonus := 0.0
	for id in ev.consome:
		bonus = maxf(bonus, float(estado.get(id, {}).get("bonus", 0.0)))
		if estado.has(id):
			estado[id].usada = true
		combate.armas.remover(str(id))
	if ev.has("tipo"):
		combate.armas.adicionar_evoluida(ev, bonus)
	if ev.has("katana"):
		combate.armas.definir_evolucao_katana(ev)
	combate.evolucao_feita(ev)


## Dados de resumo para a tela (build atual): lista de {nome, nivel, cor}.
func resumo() -> Array:
	var r: Array = []
	for id in estado:
		var e: Dictionary = estado[id]
		if int(e.n) > 0 and not bool(e.usada) and _cat[id] != "stat":
			r.append({"id": id, "nome": str(_def[id].nome), "nivel": int(e.n)})
	for ev in cfg.evolucoes:
		if evoluidas.has(ev.id):
			r.append({"id": ev.id, "nome": str(ev.nome), "nivel": 0})
	return r

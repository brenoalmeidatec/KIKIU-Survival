extends RefCounted
## Meta-progressão da v2, entre partidas: almas como moeda permanente, melhorias compradas no santuário (v2/altar.gd), conquistas
## por marcos e `aplicar(mundo)`, que põe as melhorias no herói no começo de cada partida (uma linha no mundo.gd, depois do
## iniciar_heroi). Tudo fica em `caminho_save` (ConfigFile user://v2_progresso.cfg, separado do save da v1). Regras e textos
## vêm de dados/v2_meta.json. Não há estado em memória: cada leitura vem do arquivo, e os testes trocam `caminho_save` por um
## arquivo temporário para não tocar no save real.
## Seções do save: [moeda] almas; [melhorias] id = nível; [conquistas] id = true; [ultima] resumo da última partida; [recordes] tempo e combo máximos;
## [progressao] versao e partidas (v2/progressao.gd lê as travas). A chave legado das versões antigas não vale mais: save antigo
## segue as mesmas travas, mantendo só o que conquistou.
## Mapa vencido é a conquista vence_<id>; a seção antiga [mapas_vencidos] é migrada na leitura e não volta a ser gravada.

const VERSAO_PROGRESSAO := 2
const Dificuldade := preload("res://v2/dificuldade.gd")

static var caminho_save := "user://v2_progresso.cfg"
static var erro_save := false


static func _caminho_temporario() -> String:
	return caminho_save + ".tmp"


static func _caminho_backup() -> String:
	return caminho_save + ".bak"


static func _erro_de_parse(erro: Error) -> bool:
	return erro == ERR_PARSE_ERROR or erro == ERR_FILE_CORRUPT


static func catalogo() -> Dictionary:
	return Dados.json("v2_meta")


static func melhorias() -> Array:
	return catalogo().get("melhorias", [])


static func conquistas() -> Array:
	return catalogo().get("conquistas", []) + Dados.json("v2_dificuldade").get("conquistas", [])


static func dificuldade() -> String:
	var cf := _ler()
	return Dificuldade.normalizar(str(cf.get_value("config", "dificuldade", "facil"))) if cf != null else "facil"


static func escolher_dificuldade(id: String) -> bool:
	var cf := _ler()
	if cf == null:
		erro_save = true
		return false
	cf.set_value("config", "dificuldade", Dificuldade.normalizar(id))
	erro_save = not _gravar(cf)
	return not erro_save


static func melhoria(id: String) -> Dictionary:
	for m in melhorias():
		if m.id == id:
			return m
	return {}


## Item marcado com "oculta_ate_ter_efeito" (dados/v2_meta.json, _ajuda): não aparece para o jogador até ganhar efeito real.
static func oculto(item: Dictionary) -> bool:
	return bool(item.get("oculta_ate_ter_efeito", false))


## As melhorias que o santuário e o card SUA BUILD mostram (sem as ocultas).
static func melhorias_visiveis() -> Array:
	return melhorias().filter(func(m): return not oculto(m))


## O item (melhoria, modo ou visual do catálogo) que uma recompensa de conquista libera; {} se não achar.
static func item_da_recompensa(r: Dictionary) -> Dictionary:
	var lista: Array = []
	match str(r.get("tipo", "")):
		"progresso":  # abre um portal ou estrutura do santuário (dados/v2_progressao.json): só o texto, sem item no catálogo
			return {"id": str(r.get("id", "")), "nome": str(r.nome)} if str(r.get("nome", "")) != "" else {}
		"melhoria":
			lista = melhorias()
		"modo":
			lista = catalogo().get("modos", [])
		"visual":
			lista = catalogo().get("visuais", [])
	for x in lista:
		if str(x.id) == str(r.get("id", "")):
			return x
	return {}


## O modo ou visual do catálogo com este id; {} se não achar.
static func item_extra(tipo: String, id: String) -> Dictionary:
	return item_da_recompensa({"tipo": tipo, "id": id})


## O jogador já cumpriu a conquista que libera este modo ou visual? (`cf` = o save já lido.)
static func _item_liberado(tipo: String, id: String, cf: ConfigFile) -> bool:
	for c in conquistas():
		var r: Dictionary = c.get("recompensa", {})
		if str(r.get("tipo", "")) == tipo and str(r.get("id", "")) == id:
			return bool(cf.get_value("conquistas", c.id, false))
	return false


## Modo ou visual liberado pela conquista (ainda não quer dizer que está ligado).
static func liberado(tipo: String, id: String) -> bool:
	var cf := _ler()
	return cf != null and _item_liberado(tipo, id, cf)


## Ligado no Santuário E liberado: só então vale na partida (save: [config] <id> = true).
static func ligado(tipo: String, id: String) -> bool:
	var cf := _ler()
	return cf != null and _item_liberado(tipo, id, cf) and bool(cf.get_value("config", id, false))


## Liga ou desliga um modo ou visual no Santuário. Sem a conquista cumprida não liga. Devolve false se não gravou.
static func ligar(tipo: String, id: String, valor: bool) -> bool:
	erro_save = false
	var cf := _ler()
	if cf == null:
		erro_save = true
		return false
	if valor and not _item_liberado(tipo, id, cf):
		return false
	cf.set_value("config", id, valor)
	erro_save = not _gravar(cf)
	return not erro_save


## Os números do modo Pesadelo (dados/v2_meta.json, modos > pesadelo > regras), sem a chave de ajuda.
static func regras_pesadelo() -> Dictionary:
	var r: Dictionary = item_extra("modo", "pesadelo").get("regras", {}).duplicate()
	r.erase("_ajuda")
	return r


## Porcentagem a mais de um multiplicador do Pesadelo (1,5 = 50).
static func _mais_pct(regras: Dictionary, chave: String) -> int:
	return roundi((float(regras.get(chave, 1.0)) - 1.0) * 100.0)


## Texto do modo ou visual para o Santuário: o desc, com os números do Pesadelo no lugar de {vida}, {dano}, {densidade} e {almas}.
static func texto_item(item: Dictionary) -> String:
	var t := str(item.get("desc", ""))
	var r: Dictionary = item.get("regras", {})
	for par in [["vida", "vida_mult"], ["dano", "dano_mult"], ["densidade", "densidade_mult"], ["almas", "almas_mult"]]:
		t = t.replace("{%s}" % par[0], str(_mais_pct(r, par[1])))
	return t


## Migração das travas do santuário. Save de antes delas (sem [progressao] versao) já ficou "tudo aberto" (legado), mas isso
## contrariava o combinado: mapas e altares abrem pela progressão. Agora o save antigo segue as mesmas travas e MANTÉM o que
## conquistou: a conquista antiga Derrote o chefe (de antes dos mapas) vale como Vença a Floresta, e mapa vencido é mapa aberto
## (Progressao.aberto). A chave legado de versões antigas é apagada. Só marca na memória: a próxima gravação persiste.
static func _migrar(cf: ConfigFile) -> ConfigFile:
	if cf == null:
		return null
	var versao := int(cf.get_value("progressao", "versao", 0))
	if versao < VERSAO_PROGRESSAO:
		if cf.has_section_key("progressao", "legado"):
			cf.erase_section_key("progressao", "legado")
		if bool(cf.get_value("conquistas", "derrota_chefe", false)) and not bool(cf.get_value("conquistas", "vence_floresta", false)):
			cf.set_value("conquistas", "vence_floresta", true)
		cf.set_value("progressao", "versao", VERSAO_PROGRESSAO)
	if cf.has_section("mapas_vencidos"):
		for c in conquistas():
			if c.has("mapa") and bool(cf.get_value("mapas_vencidos", str(c.mapa), false)):
				cf.set_value("conquistas", str(c.id), true)
		cf.erase_section("mapas_vencidos")
	return cf


static func _ler() -> ConfigFile:
	return _migrar(_ler_arquivo())


static func _ler_arquivo() -> ConfigFile:
	var cf := ConfigFile.new()
	var existe := FileAccess.file_exists(caminho_save)
	if not existe:
		if not FileAccess.file_exists(_caminho_backup()):
			return cf
		var backup := ConfigFile.new()
		if backup.load(_caminho_backup()) == OK:
			push_warning("v2 meta: save ausente; recuperando %s" % _caminho_backup())
			return backup
		push_warning("v2 meta: backup inválido em %s" % _caminho_backup())
		return null
	var erro := cf.load(caminho_save)
	if erro == OK:
		return cf
	if not _erro_de_parse(erro):
		push_warning("v2 meta: não foi possível ler %s (erro %d); preservando os arquivos" % [caminho_save, erro])
		return null
	var backup := ConfigFile.new()
	if FileAccess.file_exists(_caminho_backup()):
		var erro_backup := backup.load(_caminho_backup())
		if erro_backup == OK:
			push_warning("v2 meta: save corrompido; recuperando %s" % _caminho_backup())
			return backup
		if not _erro_de_parse(erro_backup):
			push_warning("v2 meta: não foi possível ler o backup %s (erro %d)" % [_caminho_backup(), erro_backup])
			return null
	push_warning("v2 meta: save corrompido e sem backup válido; preservando os arquivos")
	return null


static func _gravar(cf: ConfigFile) -> bool:
	var temporario := _caminho_temporario()
	var backup := _caminho_backup()
	var erro := cf.save(temporario)
	if erro != OK:
		push_warning("v2 meta: não gravou temporário %s (erro %d)" % [temporario, erro])
		return false
	var conferir := ConfigFile.new()
	if conferir.load(temporario) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporario))
		push_warning("v2 meta: temporário inválido em %s" % temporario)
		return false
	var havia_save := FileAccess.file_exists(caminho_save)
	var save_valido := false
	if havia_save:
		var atual := ConfigFile.new()
		var erro_atual := atual.load(caminho_save)
		save_valido = erro_atual == OK
		if not save_valido and not _erro_de_parse(erro_atual):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporario))
			push_warning("v2 meta: não foi possível ler %s (erro %d); preservando os arquivos" % [caminho_save, erro_atual])
			return false
	if havia_save and save_valido:
		if FileAccess.file_exists(backup):
			erro = DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
			if erro != OK:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(temporario))
				push_warning("v2 meta: não removeu backup antigo %s (erro %d)" % [backup, erro])
				return false
		erro = DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho_save), ProjectSettings.globalize_path(backup))
		if erro != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporario))
			push_warning("v2 meta: não moveu save para backup (erro %d)" % erro)
			return false
	elif havia_save:
		# Um save inválido nunca substitui um backup recuperável.
		erro = DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_save))
		if erro != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporario))
			push_warning("v2 meta: não removeu save corrompido (erro %d)" % erro)
			return false
	erro = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporario), ProjectSettings.globalize_path(caminho_save))
	if erro != OK:
		if havia_save and save_valido:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(caminho_save))
		push_warning("v2 meta: não instalou save novo (erro %d)" % erro)
		return false
	return true


## Foto do save para a tela: saldo, nível de cada melhoria, conquistas cumpridas, o resumo da última partida e os recordes (tempo e combo).
static func estado() -> Dictionary:
	var cf := _ler()
	var niveis := {}
	for m in melhorias():
		niveis[m.id] = int(cf.get_value("melhorias", m.id, 0)) if cf != null else 0
	var cumpridas := {}
	for c in conquistas():
		cumpridas[c.id] = bool(cf.get_value("conquistas", c.id, false)) if cf != null else false
	var ultima := {}
	if cf != null and cf.has_section("ultima"):
		for k in cf.get_section_keys("ultima"):
			ultima[k] = cf.get_value("ultima", k)
	var recordes := {"tempo": 0.0, "combo": 0}  # o melhor de todas as partidas: é o progresso das conquistas de tempo e de combo (Conquistas.linhas)
	if cf != null:
		recordes.tempo = float(cf.get_value("recordes", "tempo", 0.0))
		recordes.combo = int(cf.get_value("recordes", "combo", 0))
	return {
		"almas": int(cf.get_value("moeda", "almas", 0)) if cf != null else 0, "niveis": niveis, "conquistas": cumpridas, "ultima": ultima, "recordes": recordes
	}


static func saldo() -> int:
	var cf := _ler()
	return int(cf.get_value("moeda", "almas", 0)) if cf != null else 0


static func nivel(id: String) -> int:
	var cf := _ler()
	return int(cf.get_value("melhorias", id, 0)) if cf != null else 0


## Almas que o próximo nível custa (o nível seguinte ao `n` já comprado).
static func custo_do_nivel(m: Dictionary, n: int) -> int:
	return roundi(float(m.custo) * pow(float(m.cresce), n))


## Pode comprar? (tem nível sobrando, a conquista que a libera está cumprida e as almas bastam). Não mexe em nada.
static func comprar(id: String) -> bool:
	erro_save = false
	var m := melhoria(id)
	if m.is_empty():
		return false
	var cf := _ler()
	if cf == null:
		erro_save = true
		return false
	var n := int(cf.get_value("melhorias", id, 0))
	if n >= int(m.max) or not _liberada(m, cf):
		return false
	var almas := int(cf.get_value("moeda", "almas", 0))
	var preco := custo_do_nivel(m, n)
	if almas < preco:
		return false
	cf.set_value("moeda", "almas", almas - preco)
	cf.set_value("melhorias", id, n + 1)
	erro_save = not _gravar(cf)
	return not erro_save


static func _liberada(m: Dictionary, cf: ConfigFile) -> bool:
	var req := str(m.get("requer", ""))
	return req == "" or bool(cf.get_value("conquistas", req, false))


## Soma almas ao saldo (testes e qualquer ganho fora da partida).
static func creditar(n: int) -> void:
	var cf := _ler()
	if cf == null:
		erro_save = true
		return
	cf.set_value("moeda", "almas", int(cf.get_value("moeda", "almas", 0)) + n)
	erro_save = not _gravar(cf)


static func _cumprida(c: Dictionary, r: Dictionary) -> bool:
	match str(c.condicao):
		"tempo":
			return float(r.get("tempo", 0.0)) >= float(c.get("limite", 0.0))
		"combo":
			return int(r.get("maior_combo", 0)) >= int(c.get("limite", 0))
		"venceu":  # com "mapa": só a vitória naquele mapa (vence_floresta...); com "pesadelo": true, só a vitória no modo Pesadelo
			return (
				bool(r.get("venceu", false))
				and (not c.has("mapa") or str(r.get("mapa", "")) == str(c.mapa))
				and (not c.has("dificuldade") or (r.has("dificuldade") and Dificuldade.normalizar(str(r.dificuldade)) == str(c.dificuldade)))
				and (not bool(c.get("pesadelo", false)) or bool(r.get("pesadelo", false)))
			)
	return false


## Marca as conquistas que o resultado `r` (tempo, maior_combo, venceu) cumpriu agora. Devolve os ids novos (sem gravar).
static func _conquistar(cf: ConfigFile, r: Dictionary) -> Array:
	var novas := []
	for c in conquistas():
		if bool(cf.get_value("conquistas", c.id, false)):
			continue
		if _cumprida(c, r):
			cf.set_value("conquistas", c.id, true)
			novas.append(c.id)
	return novas


static func _conquista_do_mapa(id: String) -> String:
	if id != "":
		for c in conquistas():
			if c.has("mapa") and str(c.mapa) == id:
				return str(c.id)
	return ""


## Mapa vencido: a conquista vence_<id> (dados/v2_meta.json, com "mapa": id) cumprida no save. `cf` opcional: sem ele, lê o save.
static func mapa_vencido(id: String, cf: ConfigFile = null) -> bool:
	if cf == null:
		cf = _ler()
	var conquista := _conquista_do_mapa(id)
	return cf != null and conquista != "" and bool(cf.get_value("conquistas", conquista, false))


## Marca a conquista do mapa no `cf` (quem chama grava). Sem `cf`, grava direto ao vencer o chefão. True só se marcou agora e,
## na gravação direta, salvou. O combate põe esse retorno em resultado.mapa_vencido_agora para o anúncio da conquista no resultado.
static func marcar_mapa_vencido(id: String, cf: ConfigFile = null) -> bool:
	erro_save = false
	var gravar := cf == null
	if gravar:
		cf = _ler()
	if cf == null:
		erro_save = true
		return false
	var conquista := _conquista_do_mapa(id)
	if conquista == "" or mapa_vencido(id, cf):
		return false
	cf.set_value("conquistas", conquista, true)
	if gravar:
		erro_save = not _gravar(cf)
		return not erro_save
	return true


## Os ids dos mapas vencidos, derivados das conquistas: portais, chefes e códice leem o mesmo estado.
static func mapas_vencidos() -> Array:
	var cf := _ler()
	var ids := []
	if cf != null:
		for c in conquistas():
			if c.has("mapa") and bool(cf.get_value("conquistas", str(c.id), false)):
				ids.append(str(c.mapa))
	return ids


## Chamado no quadro durante a partida: conquistas de tempo e de combo que já foram cumpridas. Devolve os ids novos.
static func checar_ao_vivo(tempo: float, maior_combo: int) -> Array:
	var cf := _ler()
	if cf == null:
		erro_save = true
		return []
	var novas := _conquistar(cf, {"tempo": tempo, "maior_combo": maior_combo, "venceu": false})
	if not novas.is_empty():
		if not _gravar(cf):
			erro_save = true
			return []
		erro_save = false
	return novas


## As almas que o fim da partida credita de fato: as `bruto` da partida mais o bônus "Almas abundantes" do Santuário (`bonus` = fração,
## `mundo.meta_bonus.almas`) e, no Pesadelo, o `mult` (almas_mult das regras). É a conta de `registrar_partida`; o card de status (status.gd) mostra o mesmo número.
static func almas_creditadas(bruto: int, bonus: float, mult := 1.0) -> int:
	return roundi(bruto * (1.0 + bonus) * mult)


## Fim da partida: credita as almas (com o bônus de "almas"), marca conquistas e guarda o resumo.
## `r` tem tempo, abates, nivel, maior_combo, venceu, mapa (id; a vitória abre o mapa seguinte), almas e pesadelo (true = a partida foi no modo Pesadelo). Devolve antes, ganhas, depois e as conquistas novas.
## `mapa_vencido_agora` preserva o anúncio quando combate.fim_de_partida já gravou a conquista ao vencer o chefão.
static func registrar_partida(r: Dictionary) -> Dictionary:
	erro_save = false
	var cf := _ler()
	if cf == null:
		erro_save = true
		return {}
	var antes := int(cf.get_value("moeda", "almas", 0))
	var bruto := int(r.get("almas", 0))
	var pesadelo := bool(r.get("pesadelo", false))
	var mult := float(regras_pesadelo().get("almas_mult", 1.0)) if pesadelo else 1.0
	var dif := Dificuldade.regras(str(r.get("dificuldade", "facil")))
	mult *= float(dif.almas_mult)
	var ganhas := almas_creditadas(bruto, _bonus("almas", cf), mult)
	cf.set_value("moeda", "almas", antes + ganhas)
	var novas := _conquistar(cf, r)
	var conquista_mapa := _conquista_do_mapa(str(r.get("mapa", "")))
	if bool(r.get("venceu", false)) and bool(r.get("mapa_vencido_agora", false)) and conquista_mapa != "":
		if mapa_vencido(str(r.mapa), cf) and not novas.has(conquista_mapa):
			novas.append(conquista_mapa)
	cf.set_value("ultima", "tempo", float(r.get("tempo", 0.0)))
	cf.set_value("ultima", "abates", int(r.get("abates", 0)))
	cf.set_value("ultima", "maior_combo", int(r.get("maior_combo", 0)))
	cf.set_value("ultima", "nivel", int(r.get("nivel", 1)))
	cf.set_value("ultima", "venceu", bool(r.get("venceu", false)))
	cf.set_value("ultima", "ganhas", ganhas)
	cf.set_value("ultima", "pesadelo", pesadelo)
	cf.set_value("ultima", "dificuldade", str(dif.id) if r.has("dificuldade") else "")
	if r.has("dificuldade") and bool(r.get("venceu", false)) and str(r.get("mapa", "")) != "":
		cf.set_value("dificuldades_vencidas", "%s_%s" % [str(r.mapa), str(dif.id)], true)
	cf.set_value("recordes", "tempo", maxf(float(cf.get_value("recordes", "tempo", 0.0)), float(r.get("tempo", 0.0))))
	cf.set_value("recordes", "combo", maxi(int(cf.get_value("recordes", "combo", 0)), int(r.get("maior_combo", 0))))
	if r.has("mapa"):
		cf.set_value("ultima", "mapa", str(r.mapa))
	cf.set_value("progressao", "partidas", int(cf.get_value("progressao", "partidas", 0)) + 1)
	if not _gravar(cf):
		erro_save = true
		return {}
	return {"antes": antes, "ganhas": ganhas, "depois": antes + ganhas, "novas": novas}


## Valor total de uma melhoria (valor de um nível vezes os níveis comprados).
static func _total(id: String, cf: ConfigFile) -> float:
	return float(melhoria(id).get("valor", 0.0)) * int(cf.get_value("melhorias", id, 0))


static func _bonus(id: String, cf: ConfigFile) -> float:
	return _total(id, cf) / 100.0


static func _numero(m: Dictionary, v: float) -> String:
	return ("%.1f" % v).replace(".", ",") if bool(m.get("decimal", false)) else str(roundi(v))


## Texto de uma melhoria com `n` níveis: o desc com o valor total (o {v} vira o número).
static func texto_efeito(m: Dictionary, n: int) -> String:
	return str(m.desc).replace("{v}", _numero(m, float(m.valor) * n))


## O que o próximo nível dá, curto: "proximo: +30" (o prefixo e a unidade vêm do desc; "maximo" quando não há mais nível).
static func texto_proximo(m: Dictionary, n: int) -> String:
	if n >= int(m.max):
		return "maximo"
	var partes := str(m.desc).split("{v}")
	var suf := partes[1] if partes.size() > 1 else ""
	var unidade := suf.split(" ")[0]  # "%" nos percentuais, "" no resto
	return "Próximo: %s%s%s" % [partes[0], _numero(m, float(m.valor) * (n + 1)), unidade]


## Põe as melhorias compradas no herói, no começo da partida. Os valores são ABSOLUTOS (base do dados/v2_combate.json mais o
## bônus), então chamar de novo não soma em cima. Os bônus de raridade, rolagem e almas (e as regras do Pesadelo, se ligado) ficam em mundo.meta_bonus; o Rastro de katana troca mundo.combate.fx.variante.
static func aplicar(mundo) -> void:
	var cf := _ler()
	var dif := Dificuldade.regras(str(mundo.args.get("dificuldade", dificuldade())))
	mundo.meta_bonus["dificuldade"] = dif
	if cf == null:
		return
	var h = mundo.heroi
	var cfg: Dictionary = mundo.combate.cfg
	h.vida_max = float(cfg.heroi.vida) + _total("vida", cf)
	h.vida = h.vida_max
	h.folego_max = float(cfg.folego.max) + _total("folego", cf)
	h.folego = h.folego_max
	h.m_dano = 1.0 + _bonus("dano", cf)
	h.m_vel_mov = 1.0 + _bonus("velocidade", cf)
	h.m_ima = 1.0 + _bonus("ima", cf)
	h.m_vel_ataque = 1.0 + _bonus("treino", cf)
	mundo.meta_bonus = {
		"raridade": _bonus("raridade", cf),
		"rolagem": int(_total("rolagem", cf)),
		"almas": (1.0 + _bonus("almas", cf)) * float(dif.almas_mult) - 1.0,
		"dificuldade": dif
	}
	if ligado("modo", "pesadelo"):
		mundo.meta_bonus["pesadelo"] = regras_pesadelo()  # as regras do modo; sem a chave a partida é normal (mundo.fator_pesadelo)
	if mundo.combate != null and mundo.combate.fx != null:  # visual do santuário: a folha do corte da katana (só cosmético, o dano é o mesmo)
		var rastro := ligado("visual", "rastro_katana")
		mundo.combate.fx.variante = str(item_extra("visual", "rastro_katana").get("variante", "katana")) if rastro else "katana"
	preload("res://v2/herois.gd").aplicar_bonus(mundo)  # bônus do herói escolhido (área, sorte...) por cima das melhorias


## Almas que a partida trouxe. `almas_partida` ainda não existe na v2 (o agente das cartas e dos chefes expõe): até lá vale 0.
static func almas_da_partida(mundo) -> int:
	var v = mundo.get("almas_partida")
	return int(v) if v != null else 0

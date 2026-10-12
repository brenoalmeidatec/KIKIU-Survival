extends RefCounted
## Meta-progressão da v2, entre partidas: almas como moeda permanente, melhorias compradas no santuário (v2/altar.gd), conquistas
## por marcos e `aplicar(mundo)`, que põe as melhorias no herói no começo de cada partida (uma linha no mundo.gd, depois do
## iniciar_heroi). Tudo fica em `caminho_save` (ConfigFile user://v2_progresso.cfg, separado do save da v1). Regras e textos
## vêm de dados/v2_meta.json. Não há estado em memória: cada leitura vem do arquivo, e os testes trocam `caminho_save` por um
## arquivo temporário para não tocar no save real.
## Seções do save: [moeda] almas; [melhorias] id = nível; [conquistas] id = true; [ultima] resumo da última partida; [heroi] id = herói escolhido.

static var caminho_save := "user://v2_progresso.cfg"


static func catalogo() -> Dictionary:
	return Dados.json("v2_meta")


static func melhorias() -> Array:
	return catalogo().get("melhorias", [])


static func conquistas() -> Array:
	return catalogo().get("conquistas", [])


static func melhoria(id: String) -> Dictionary:
	for m in melhorias():
		if m.id == id:
			return m
	return {}


static func _ler() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(caminho_save)  # sem arquivo ainda: sai com erro e o cf fica vazio (saldo 0, nada comprado)
	return cf


static func _gravar(cf: ConfigFile) -> void:
	var erro := cf.save(caminho_save)
	if erro != OK:
		push_warning("v2 meta: não gravou %s (erro %d)" % [caminho_save, erro])


## Foto do save para a tela: saldo, nível de cada melhoria, conquistas cumpridas e o resumo da última partida.
static func estado() -> Dictionary:
	var cf := _ler()
	var niveis := {}
	for m in melhorias():
		niveis[m.id] = int(cf.get_value("melhorias", m.id, 0))
	var cumpridas := {}
	for c in conquistas():
		cumpridas[c.id] = bool(cf.get_value("conquistas", c.id, false))
	var ultima := {}
	if cf.has_section("ultima"):
		for k in cf.get_section_keys("ultima"):
			ultima[k] = cf.get_value("ultima", k)
	return {"almas": int(cf.get_value("moeda", "almas", 0)), "niveis": niveis, "conquistas": cumpridas, "ultima": ultima}


## Herói escolhido no santuário ("" = nenhum gravado: vale o Hazaki). Chave nova, [heroi] id: save antigo sem ela segue valendo.
static func heroi_escolhido() -> String:
	return str(_ler().get_value("heroi", "id", ""))


static func escolher_heroi(id: String) -> void:
	var cf := _ler()
	cf.set_value("heroi", "id", id)
	_gravar(cf)


static func saldo() -> int:
	return int(_ler().get_value("moeda", "almas", 0))


static func nivel(id: String) -> int:
	return int(_ler().get_value("melhorias", id, 0))


## Almas que o próximo nível custa (o nível seguinte ao `n` já comprado).
static func custo_do_nivel(m: Dictionary, n: int) -> int:
	return roundi(float(m.custo) * pow(float(m.cresce), n))


## Pode comprar? (tem nível sobrando, a conquista que a libera está cumprida e as almas bastam). Não mexe em nada.
static func comprar(id: String) -> bool:
	var m := melhoria(id)
	if m.is_empty():
		return false
	var cf := _ler()
	var n := int(cf.get_value("melhorias", id, 0))
	if n >= int(m.max) or not _liberada(m, cf):
		return false
	var almas := int(cf.get_value("moeda", "almas", 0))
	var preco := custo_do_nivel(m, n)
	if almas < preco:
		return false
	cf.set_value("moeda", "almas", almas - preco)
	cf.set_value("melhorias", id, n + 1)
	_gravar(cf)
	return true


static func _liberada(m: Dictionary, cf: ConfigFile) -> bool:
	var req := str(m.get("requer", ""))
	return req == "" or bool(cf.get_value("conquistas", req, false))


## Soma almas ao saldo (testes e qualquer ganho fora da partida).
static func creditar(n: int) -> void:
	var cf := _ler()
	cf.set_value("moeda", "almas", int(cf.get_value("moeda", "almas", 0)) + n)
	_gravar(cf)


static func _cumprida(c: Dictionary, r: Dictionary) -> bool:
	match str(c.condicao):
		"tempo":
			return float(r.get("tempo", 0.0)) >= float(c.get("limite", 0.0))
		"combo":
			return int(r.get("maior_combo", 0)) >= int(c.get("limite", 0))
		"venceu":
			return bool(r.get("venceu", false))
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


## Chamado no quadro durante a partida: conquistas de tempo e de combo que já foram cumpridas. Devolve os ids novos.
static func checar_ao_vivo(tempo: float, maior_combo: int) -> Array:
	var cf := _ler()
	var novas := _conquistar(cf, {"tempo": tempo, "maior_combo": maior_combo, "venceu": false})
	if not novas.is_empty():
		_gravar(cf)
	return novas


## Fim da partida: credita as almas (com o bônus de "almas"), marca conquistas e guarda o resumo.
## `r` tem tempo, abates, nivel, maior_combo, venceu e almas. Devolve antes, ganhas, depois e as conquistas novas.
static func registrar_partida(r: Dictionary) -> Dictionary:
	var cf := _ler()
	var antes := int(cf.get_value("moeda", "almas", 0))
	var bruto := int(r.get("almas", 0))
	var ganhas := roundi(bruto * (1.0 + _bonus("almas", cf)))
	cf.set_value("moeda", "almas", antes + ganhas)
	var novas := _conquistar(cf, r)
	cf.set_value("ultima", "tempo", float(r.get("tempo", 0.0)))
	cf.set_value("ultima", "abates", int(r.get("abates", 0)))
	cf.set_value("ultima", "maior_combo", int(r.get("maior_combo", 0)))
	cf.set_value("ultima", "nivel", int(r.get("nivel", 1)))
	cf.set_value("ultima", "venceu", bool(r.get("venceu", false)))
	cf.set_value("ultima", "ganhas", ganhas)
	_gravar(cf)
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
## bônus), então chamar de novo não soma em cima. Os bônus de raridade, rolagem e almas ficam em mundo.meta_bonus.
static func aplicar(mundo) -> void:
	var cf := _ler()
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
	mundo.meta_bonus = {"raridade": _bonus("raridade", cf), "rolagem": int(_total("rolagem", cf)), "almas": _bonus("almas", cf)}
	preload("res://v2/herois.gd").aplicar_bonus(mundo)  # bônus do herói escolhido (área, sorte...) por cima das melhorias


## Almas que a partida trouxe. `almas_partida` ainda não existe na v2 (o agente das cartas e dos chefes expõe): até lá vale 0.
static func almas_da_partida(mundo) -> int:
	var v = mundo.get("almas_partida")
	return int(v) if v != null else 0

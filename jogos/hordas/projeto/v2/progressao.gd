extends RefCounted
## Progressão do santuário: o que fica trancado no começo (portais dos mapas e estruturas) e o que abre cada um. As regras ficam em
## dados/v2_progressao.json: para cada mapa e cada estrutura, uma lista de condições ALTERNATIVAS (basta cumprir uma); lista vazia =
## aberto desde o começo. Condições: {"conquista": id} (de dados/v2_meta.json, por exemplo vence_floresta), {"partidas": N} (partidas
## terminadas, contadas em Meta.registrar_partida) e {"conquistas": N} (quantas conquistas cumpridas, qualquer uma).
## Save antigo segue as mesmas travas e mantém o que conquistou (Meta._migrar): não existe mais "tudo aberto" por ser save velho.
## Mapa já vencido fica aberto mesmo que o anterior não conste no save (quem venceu um mapa já esteve nele).
## Lê o save a cada chamada, como o resto da meta-progressão. Sem class_name: carregue com preload.

const Meta := preload("res://v2/meta.gd")
const ARG_BETA := "--beta-tester"
const SEGREDO := "tudo_liberado"  # a chave em Config.segredo

## Só para teste: lista de argumentos no lugar da linha de comando (null = usa OS.get_cmdline_user_args()).
static var args_teste = null


## Modo beta tester: todos os portais e estruturas ficam liberados em tempo de execução. Não grava nada no save do personagem: a trava
## some só aqui, em aberto() (e curto()/aviso() herdam). Duas fontes: o argumento `-- --beta-tester` (vale só nesta execução) e o código
## secreto (Konami ou IDKFA, v2/codigo_secreto.gd), que fica ligado nas opções do jogador (Config, segredo "tudo_liberado") até digitar
## o código de novo.
static func beta_tester() -> bool:
	return por_argumento() or codigo_ligado()


static func por_argumento() -> bool:
	var args: Array = args_teste if args_teste != null else Array(OS.get_cmdline_user_args())
	return ARG_BETA in args


static func codigo_ligado() -> bool:
	return Config.segredo(SEGREDO)


## Liga ou desliga o código secreto (opção salva em Config). Devolve o estado novo.
static func alternar_codigo() -> bool:
	var novo := not codigo_ligado()
	Config.definir_segredo(SEGREDO, novo)
	return novo


## O texto do selo do canto ("" = sem selo): BETA TESTER pelo argumento, CÓDIGO SECRETO só pelo código.
static func selo() -> String:
	if por_argumento():
		return "BETA TESTER"
	return "CÓDIGO SECRETO" if codigo_ligado() else ""


static func regras() -> Dictionary:
	return Dados.json("v2_progressao")


## As condições (alternativas) do mapa ou estrutura; [] = aberto desde o começo. `tipo` é "mapa" ou "estrutura".
static func condicoes(tipo: String, id: String) -> Array:
	var grupo: Dictionary = regras().get("mapas" if tipo == "mapa" else "estruturas", {})
	return grupo.get(id, [])


static func _conquista(id: String) -> Dictionary:
	for c in Meta.conquistas():
		if str(c.id) == id:
			return c
	return {}


static func _cumpridas(cf: ConfigFile) -> int:
	var n := 0
	for c in Meta.conquistas():
		if bool(cf.get_value("conquistas", c.id, false)):
			n += 1
	return n


static func partidas(cf: ConfigFile = null) -> int:
	if cf == null:
		cf = Meta._ler()
	return int(cf.get_value("progressao", "partidas", 0)) if cf != null else 0


static func _cumpre(cond: Dictionary, cf: ConfigFile) -> bool:
	if cond.has("conquista"):
		var c := _conquista(str(cond.conquista))
		if c.has("mapa"):  # vencer um mapa é a conquista vence_<mapa>: lida pela função de mapa vencido (meta.gd)
			return Meta.mapa_vencido(str(c.mapa), cf)
		return bool(cf.get_value("conquistas", str(cond.conquista), false))
	if cond.has("partidas"):
		return partidas(cf) >= int(cond.partidas)
	if cond.has("conquistas"):
		return _cumpridas(cf) >= int(cond.conquistas)
	return false


## Aberto? Sem save legível, só o que não tem condição.
static func aberto(tipo: String, id: String) -> bool:
	if beta_tester():
		return true
	var conds := condicoes(tipo, id)
	if conds.is_empty():
		return true
	var cf := Meta._ler()
	if cf == null:
		return false
	if tipo == "mapa" and Meta.mapa_vencido(id, cf):
		return true
	for c in conds:
		if _cumpre(c, cf):
			return true
	return false


## Texto curto de uma condição, para o rótulo com cadeado no chão do santuário.
static func _curto(cond: Dictionary) -> String:
	if cond.has("conquista"):
		var c := _conquista(str(cond.conquista))
		return str(c.get("curto", c.get("nome", cond.conquista)))
	if cond.has("partidas"):
		return "%d partidas" % int(cond.partidas)
	if cond.has("conquistas"):
		var n := int(cond.conquistas)
		return "%d conquista%s" % [n, "" if n == 1 else "s"]
	return "?"


## Texto completo de uma condição, com o quanto falta (para o aviso).
static func _longo(cond: Dictionary, cf: ConfigFile) -> String:
	if cond.has("conquista"):
		var c := _conquista(str(cond.conquista))
		return str(c.get("desc", c.get("nome", cond.conquista))).trim_suffix(".")
	if cond.has("partidas"):
		return "jogue %d partidas (%d/%d)" % [int(cond.partidas), mini(partidas(cf), int(cond.partidas)), int(cond.partidas)]
	if cond.has("conquistas"):
		var n := int(cond.conquistas)
		return "cumpra %d conquista%s (%d/%d)" % [n, "" if n == 1 else "s", mini(_cumpridas(cf), n), n]
	return "?"


## Uma linha curta com o que abre ("Vença a Floresta ou 5 partidas"), ou "" se já está aberto.
static func curto(tipo: String, id: String) -> String:
	if aberto(tipo, id):
		return ""
	var partes := PackedStringArray()
	for c in condicoes(tipo, id):
		partes.append(_curto(c))
	return " ou ".join(partes)


## O aviso de quando o jogador tenta usar algo trancado ("Vença o chefe final da Floresta ou jogue 5 partidas (2/5)."), ou "" se aberto.
static func aviso(tipo: String, id: String) -> String:
	if aberto(tipo, id):
		return ""
	var cf := Meta._ler()
	var partes := PackedStringArray()
	for c in condicoes(tipo, id):
		partes.append(_longo(c, cf) if cf != null else _curto(c))
	var t := " ou ".join(partes)
	return t.substr(0, 1).to_upper() + t.substr(1) + "."

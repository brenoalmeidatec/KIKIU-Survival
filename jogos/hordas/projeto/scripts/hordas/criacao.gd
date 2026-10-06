extends RefCounted
## Criação de personagem (#72, marco 1): monta um herói no formato de dados/herois.json a partir de raça e classe.
## O id do herói criado já diz como montá-lo: "c:<raça>:<classe>". O resto do jogo só vê mais um herói na tabela
## (Dados junta os criados ao herois.json), então não precisa saber a diferença. No online (marco 2) só o id viaja e cada
## máquina monta o mesmo herói a partir dos mesmos JSON, que é o que deixa o anfitrião validar tudo.
## O último herói criado fica salvo em user://heroi_criado.json e aparece como carta na escolha de heróis.

const PREFIXO := "c:"
const ARQUIVO := "user://heroi_criado.json"
const ROTULO := {"dano": "dano", "area": "área", "duracao": "duração", "velocidade_proj": "velocidade dos tiros",
	"velocidade": "velocidade", "ima": "alcance do ímã", "xp": "XP", "critico": "chance de crítico", "critico_mult": "dano crítico"}


static func racas() -> Dictionary:
	return Dados.json("racas")


static func classes() -> Dictionary:
	return Dados.json("classes")


static func lista_racas() -> Array:
	return racas().get("lista", [])


static func lista_classes() -> Array:
	return classes().get("lista", [])


static func id_de(raca: String, classe: String) -> String:
	return "%s%s:%s" % [PREFIXO, raca, classe]


static func eh_criado(id: String) -> bool:
	return id.begins_with(PREFIXO)


## [raça, classe] de um id de herói criado, ou [] se o id não for de um herói possível.
static func partes(id: String) -> Array:
	if not eh_criado(id):
		return []
	var p := id.substr(PREFIXO.length()).split(":")
	if p.size() != 2 or not p[0] in lista_racas() or not p[1] in lista_classes():
		return []
	return [p[0], p[1]]


static func valido(id: String) -> bool:
	return not partes(id).is_empty()


## O herói no formato de herois.json: bônus da raça, fraquezas da raça e bônus da classe somados.
static func montar(raca: String, classe: String) -> Dictionary:
	var r: Dictionary = racas().get(raca, {})
	var c: Dictionary = classes().get(classe, {})
	var bonus := {}
	for fonte in [r.get("bonus", {}), r.get("fraquezas", {}), c.get("bonus", {})]:
		for k in fonte:
			bonus[k] = float(bonus.get(k, 0.0)) + float(fonte[k])
	return {
		"nome": "%s %s" % [str(r.get("curto", r.get("nome", raca))), str(c.get("nome", classe))],
		"sprite": str(r.get("sprite", "hazaki")),
		"camadas": true,
		"reviver": float(c.get("reviver", 1.0)),
		"arma": str(c.get("arma_inicial", "pendrive")),
		"especial": str(c.get("especial", "")),
		"descricao": str(c.get("descricao", "")),
		"bonus": bonus,
		"tom": r.get("tom", [1.0, 1.0, 1.0]),
		"raca": raca,
		"classe": classe,
	}


## Valida o id e põe o herói na tabela de heróis. Devolve false se o id não for de um herói possível.
static func registrar(id: String) -> bool:
	var p := partes(id)
	if p.is_empty():
		return false
	Dados.registrar_heroi(id, montar(p[0], p[1]))
	return true


## O último herói criado (salvo), já registrado; "" se não houver ou se a raça/classe saiu dos dados.
static func ultimo() -> String:
	if not FileAccess.file_exists(ARQUIVO):
		return ""
	var d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	var id := str(d.get("id", "")) if d is Dictionary else ""
	return id if registrar(id) else ""


static func salvar(id: String) -> void:
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"id": id}))


## Uma linha legível por atributo, com se é bom pro herói: [[texto, bom], ...].
## "+20% de dano", "-25 de vida", "ataques 10% mais lentos" (recarga: menos é mais rápido).
static func descrever(bonus: Dictionary) -> Array:
	var res := []
	for k in bonus:
		var v := float(bonus[k])
		if is_zero_approx(v):
			continue
		var bom := v > 0.0
		var txt := ""
		match str(k):
			"vida_max":
				txt = "%+d de vida" % roundi(v)
			"regen":
				txt = ("%+.1f de regeneração" % v).replace(".", ",")
			"sorte":
				txt = ("%+.1f de sorte" % v).replace(".", ",")
			"quantidade":
				txt = "%+d %s" % [roundi(v), "projétil" if absi(roundi(v)) == 1 else "projéteis"]
			"recarga":
				bom = v < 0.0
				txt = "ataques %d%% mais %s" % [roundi(absf(v) * 100.0), "rápidos" if v < 0.0 else "lentos"]
			_:
				txt = "%+d%% de %s" % [roundi(v * 100.0), ROTULO.get(k, k)]
		res.append([txt, bom])
	return res

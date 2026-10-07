extends RefCounted
## Criação de personagem (#72): monta um herói no formato de dados/herois.json a partir de raça e classe (marco 1)
## e de uma ficha com nome, pontos de atributo, defeito voluntário e aparência por paleta (marco 2).
## Dois jeitos de existir um herói criado:
##   - "c:<raça>:<classe>" (marco 1): o id diz tudo, sem ficha (atalho --heroi=c:orc:guerreiro e testes);
##   - "c:h<código>" (marco 2): id único de um herói salvo; os dados dele estão na ficha, guardada no arquivo e, no online,
##     mandada ao anfitrião, que valida cada número pelos mesmos JSON (atributos, defeitos, aparencia) antes de aceitar.
## O resto do jogo só vê mais um herói na tabela (Dados junta os criados ao herois.json).
## Até 6 heróis salvos em user://heroi_criado.json; aparecem na lista de heróis.

const PREFIXO := "c:"
const ARQUIVO := "user://heroi_criado.json"
const MAX_HEROIS := 6
const Paleta := preload("res://scripts/hordas/paleta.gd")
const ROTULO := {"dano": "dano", "area": "área", "duracao": "duração", "velocidade_proj": "velocidade dos tiros",
	"velocidade": "velocidade", "ima": "alcance do ímã", "xp": "XP", "critico": "chance de crítico", "critico_mult": "dano crítico"}
const VERBO_EL := {"fogo": "queimar", "gelo": "congelar", "raio": "eletrocutar", "veneno": "envenenar"}


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


## [raça, classe] de um id "c:raça:classe", ou [] se o id não for de um herói possível (ou for de um herói com ficha).
static func partes(id: String) -> Array:
	if not eh_criado(id):
		return []
	var p := id.substr(PREFIXO.length()).split(":")
	if p.size() != 2 or not p[0] in lista_racas() or not p[1] in lista_classes():
		return []
	return [p[0], p[1]]


## O herói existe: id "c:raça:classe" válido, ou herói com ficha que já foi registrado.
static func valido(id: String) -> bool:
	if not partes(id).is_empty():
		return true
	return eh_criado(id) and Dados.herois_extra.has(id)


# --- ficha (marco 2): {"nome": "Brutus", "raca": "orc", "classe": "guerreiro", "pontos": {"forca": 3, ...},
#     "defeito": "manco" | "", "paleta": {"pele": 4, "cabelo": 0, "roupa": 2}}
# Tudo em índices e ids que existem nos JSON, então quem recebe a ficha (o anfitrião) valida pelos mesmos números.

static func atributos() -> Dictionary:
	return Dados.json("atributos")


static func lista_atributos() -> Array:
	return atributos().get("lista", [])


static func defeitos() -> Dictionary:
	return Dados.json("defeitos")


static func lista_defeitos() -> Array:
	return defeitos().get("lista", [])


static func ficha_nova(raca: String, classe: String) -> Dictionary:
	var p := {}
	for k in lista_atributos():
		p[k] = 0
	return {"nome": "", "raca": raca, "classe": classe, "pontos": p, "defeito": "", "paleta": Paleta.padrao(raca)}


static func pontos_gastos(pontos: Dictionary) -> int:
	var n := 0
	for k in lista_atributos():
		n += int(pontos.get(k, 0))
	return n


## Pontos que o herói pode gastar: os da base mais os do defeito voluntário.
static func pontos_totais(defeito: String) -> int:
	return int(atributos().get("total", 0)) + int(defeitos().get(defeito, {}).get("pontos", 0))


## Nome do herói: só letras (com acento do português), números, espaço e hífen, até nome_max letras. O resto some.
static func limpar_nome(s: String) -> String:
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or ch == " " or ch == "-" or "áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ".contains(ch):
			out += ch
	return Rede.limpar_nome(out).left(int(Dados.json("aparencia").get("nome_max", 12))).strip_edges()


static func _inteiro(v) -> bool:
	return v is int or (v is float and v == floorf(v))


## Por que a ficha não vale ("" = vale). A ficha pode vir da rede, então confere tipo, faixa e soma de tudo.
static func erro_ficha(f) -> String:
	if not f is Dictionary:
		return "ficha inválida"
	var cfg: Dictionary = Dados.json("aparencia")
	var nome = f.get("nome")
	if not nome is String or nome != limpar_nome(nome) or nome.length() < int(cfg.get("nome_min", 2)) or nome.length() > int(cfg.get("nome_max", 12)):
		return "nome inválido (%d a %d letras)" % [int(cfg.get("nome_min", 2)), int(cfg.get("nome_max", 12))]
	var raca = f.get("raca")
	if not raca is String or not raca in lista_racas():
		return "raça inexistente"
	var classe = f.get("classe")
	if not classe is String or not classe in lista_classes():
		return "classe inexistente"
	var def = f.get("defeito", "")
	if not def is String or (def != "" and not def in lista_defeitos()):
		return "defeito inexistente"
	var p = f.get("pontos")
	if not p is Dictionary:
		return "pontos inválidos"
	for k in p:
		if not k is String or not k in lista_atributos():
			return "atributo inexistente"
	var soma := 0
	for k in lista_atributos():
		var v = p.get(k, 0)
		if not _inteiro(v) or int(v) < 0 or int(v) > int(atributos().get(k, {}).get("max", 0)):
			return "pontos fora da faixa em %s" % k
		soma += int(v)
	if soma > pontos_totais(def):
		return "pontos demais (%d de %d)" % [soma, pontos_totais(def)]
	if not Paleta.valida(f.get("paleta")):
		return "paleta fora da faixa"
	return ""


## A ficha limpa (só os campos conhecidos, com o tipo certo), ou {} se não vale.
static func validar_ficha(f) -> Dictionary:
	if erro_ficha(f) != "":
		return {}
	var p := {}
	for k in lista_atributos():
		p[k] = int(f.pontos.get(k, 0))
	return {"nome": str(f.nome), "raca": str(f.raca), "classe": str(f.classe), "pontos": p, "defeito": str(f.get("defeito", "")),
		"paleta": Paleta.limpar(f.paleta)}


## O herói no formato de herois.json: bônus da raça, fraquezas da raça e bônus da classe somados.
## Com ficha, soma também os pontos de atributo e o defeito, e o nome e a paleta são os dela (a paleta substitui o tom da raça).
static func montar(raca: String, classe: String, ficha := {}) -> Dictionary:
	var r: Dictionary = racas().get(raca, {})
	var c: Dictionary = classes().get(classe, {})
	var fontes := [r.get("bonus", {}), r.get("fraquezas", {}), c.get("bonus", {})]
	if not ficha.is_empty():
		for k in lista_atributos():
			var n := int(ficha.get("pontos", {}).get(k, 0))
			if n > 0:
				var e := {}
				var ef: Dictionary = atributos().get(k, {}).get("efeito", {})
				for b in ef:
					e[b] = float(ef[b]) * n
				fontes.append(e)
		fontes.append(defeitos().get(str(ficha.get("defeito", "")), {}).get("efeito", {}))
	var bonus := {}
	for fonte in fontes:
		for k in fonte:
			bonus[k] = float(bonus.get(k, 0.0)) + float(fonte[k])
	var titulo := "%s %s" % [str(r.get("curto", r.get("nome", raca))), str(c.get("nome", classe))]
	var h := {
		"nome": titulo,
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
		"ganchos": r.get("ganchos", []) + c.get("ganchos", []),   # marco 6: regras próprias (ganchos.gd); raça antiga sem o campo = nenhum
	}
	if not ficha.is_empty():
		h["nome"] = str(ficha.get("nome", titulo))
		h["titulo"] = titulo
		h["descricao"] = titulo + ". " + str(h["descricao"])
		h["tom"] = [1.0, 1.0, 1.0]
		h["paleta"] = Paleta.limpar(ficha.get("paleta", {}))
		h["ficha"] = ficha
	return h


## Valida o id e põe o herói (sem ficha) na tabela de heróis. Devolve false se o id não for de um herói possível.
static func registrar(id: String) -> bool:
	var p := partes(id)
	if p.is_empty():
		return false
	Dados.registrar_heroi(id, montar(p[0], p[1]))
	return true


## Põe na tabela o herói de uma ficha válida, com o id dado (único por herói salvo; no online, o que o anfitrião aceitou).
static func registrar_ficha(id: String, ficha) -> bool:
	if not eh_criado(id) or not partes(id).is_empty():
		return false
	var f := validar_ficha(ficha)
	if f.is_empty():
		return false
	Dados.registrar_heroi(id, montar(f.raca, f.classe, f))
	return true


# --- heróis salvos (até 6) e morte de vez (pedido do Alisson): o herói criado que morre SOME, e é preciso criar outro do zero.
# Vale no solo e no online; no online a morte é a corrida acabar em derrota (o grupo todo caiu). Desistir conta como
# morrer, e fechar o jogo no meio da corrida também: a marca "em_corrida" fica no arquivo e mata o herói ao abrir de novo.
# Perder o duelo final não mata (ele já venceu a corrida), e cair a conexão no online também não.
# Arquivo: {"herois": [{"id": "c:h1a2b", "ficha": {...}, "em_corrida": false}]}. O formato antigo ({"id": ...}, um herói) é lido.

static var arquivo := ARQUIVO   # os testes trocam, pra não mexer nos heróis salvos de verdade


static func _ler() -> Array:
	if not FileAccess.file_exists(arquivo):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(arquivo))
	if not d is Dictionary:
		return []
	if d.has("herois") and d.herois is Array:
		return d.herois
	if d.has("id"):   # formato do marco 1: um herói só, só raça e classe
		return [{"id": str(d.id), "em_corrida": bool(d.get("em_corrida", false))}]
	return []


static func _gravar(l: Array) -> void:
	var f := FileAccess.open(arquivo, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"herois": l}))


static func _achar(l: Array, id: String) -> int:
	for i in l.size():
		if l[i] is Dictionary and str(l[i].get("id", "")) == id:
			return i
	return -1


## Os heróis salvos, já registrados: {ids: [...], perdidos: [...]}. perdidos = heróis que morreram porque o jogo fechou
## no meio da corrida deles (saem do arquivo). matar = false só lê (testes rodando com o jogo aberto).
static func carregar(matar := true) -> Dictionary:
	var ids := []
	var perdidos := []
	var manter := []
	var mudou := false
	for e in _ler():
		if not e is Dictionary:
			mudou = true
			continue
		var id := str(e.get("id", ""))
		var ok := registrar_ficha(id, e.get("ficha")) if e.has("ficha") else registrar(id)
		if not ok:
			mudou = true
			continue
		if matar and bool(e.get("em_corrida", false)):
			perdidos.append(id)
			mudou = true
			continue
		ids.append(id)
		manter.append(e)
	if matar and mudou:
		if manter.is_empty():
			apagar()
		else:
			_gravar(manter)
	return {"ids": ids, "perdidos": perdidos}


static func quantos() -> int:
	return carregar(false).ids.size()


## Salva um herói novo da ficha. Devolve o id, ou "" se a ficha não vale, o nome já existe ou já são 6 heróis.
static func salvar_ficha(ficha) -> String:
	var f := validar_ficha(ficha)
	if f.is_empty():
		return ""
	var l := _ler()
	if l.size() >= MAX_HEROIS:
		return ""
	for e in l:
		if e is Dictionary and e.get("ficha") is Dictionary and str(e.ficha.get("nome", "")).to_lower() == str(f.nome).to_lower():
			return ""
	var id := "c:h%x" % (int(Time.get_unix_time_from_system() * 1000.0) + randi() % 4096)
	while _achar(l, id) >= 0:
		id += "0"
	l.append({"id": id, "ficha": f, "em_corrida": false, "bau": _kit()})
	_gravar(l)
	registrar_ficha(id, f)
	return id


## Salva um herói só de raça e classe (id "c:raça:classe", sem ficha): testes e o atalho --heroi. false se já são 6.
static func salvar(id: String) -> bool:
	if partes(id).is_empty():
		return false
	var l := _ler()
	if _achar(l, id) < 0:
		if l.size() >= MAX_HEROIS:
			return false
		l.append({"id": id, "em_corrida": false, "bau": _kit()})
	_gravar(l)
	return true


# --- baú pessoal e mochila (#72, marcos 3 e 4): ficam NA ENTRADA do herói, então somem junto com ele (apagar remove a entrada toda).
# Entrada: {"id", "ficha", "em_corrida", "bau": {id: n}, "mochila": {"itens": {...}, "amuleto": ""}}. A mochila guardada é a última
# que ele montou (vem pré-escolhida no Preparo). Herói salvo antes do marco 3 não tem "bau": ganha o kit inicial na primeira leitura.
# As regras (capacidade, validação, contas) ficam no mochila.gd; aqui só se guarda.

static func _kit() -> Dictionary:
	var k = Dados.json("mochila").get("kit_inicial", {})
	return k.duplicate() if k is Dictionary else {}


## O herói está salvo no arquivo (tem baú)? Herói fixo e herói de teste (--ficha, --heroi=) não estão.
static func salvo(id: String) -> bool:
	return _achar(_ler(), id) >= 0


## O baú do herói ({id: n}); {} se o herói não está salvo (morreu, ou é fixo). Herói antigo, sem baú: recebe o kit inicial e grava.
static func bau_de(id: String) -> Dictionary:
	var l := _ler()
	var i := _achar(l, id)
	if i < 0:
		return {}
	if not l[i].get("bau") is Dictionary:
		l[i]["bau"] = _kit()
		_gravar(l)
	return l[i]["bau"].duplicate()


static func definir_bau(id: String, bau: Dictionary) -> bool:
	var l := _ler()
	var i := _achar(l, id)
	if i < 0:
		return false
	l[i]["bau"] = bau
	_gravar(l)
	return true


## A última mochila que o herói montou ({} se nunca montou).
static func mochila_de(id: String) -> Dictionary:
	var l := _ler()
	var i := _achar(l, id)
	if i < 0 or not l[i].get("mochila") is Dictionary:
		return {}
	return l[i]["mochila"].duplicate(true)


static func definir_mochila(id: String, m: Dictionary) -> void:
	var l := _ler()
	var i := _achar(l, id)
	if i >= 0:
		l[i]["mochila"] = m
		_gravar(l)


## A corrida do herói começou: se o jogo fechar agora, ele morre.
static func comecou(id: String) -> void:
	_marcar(id, true)


## Venceu (ou caiu a conexão): continua vivo.
static func sobreviveu(id: String) -> void:
	_marcar(id, false)


static func _marcar(id: String, sim: bool) -> void:
	var l := _ler()
	var i := _achar(l, id)
	if i >= 0:
		l[i]["em_corrida"] = sim
		_gravar(l)


## Apaga um herói (morreu, ou o jogador apagou na lista). Sem id: apaga o arquivo todo (testes).
static func apagar(id := "") -> void:
	if id == "":
		if FileAccess.file_exists(arquivo):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(arquivo))
		return
	var l := _ler()
	var i := _achar(l, id)
	if i < 0:
		return
	l.remove_at(i)
	Dados.herois_extra.erase(id)
	if l.is_empty():
		apagar()
	else:
		_gravar(l)


## O resultado de uma corrida mata o herói de vez? Herói criado + corrida sem vitória + sem duelo.
static func morreu_de_vez(res: Dictionary) -> bool:
	return eh_criado(str(res.get("heroi", ""))) and not bool(res.get("vitoria", false)) and not res.has("duelo")


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
				if str(k).begins_with("el_"):   # afinidade elemental (marco 5/6): chance por golpe de pôr o elemento
					txt = "%+d%% de chance de %s" % [roundi(v * 100.0), VERBO_EL.get(str(k).substr(3), "marcar")]
				else:
					txt = "%+d%% de %s" % [roundi(v * 100.0), ROTULO.get(k, k)]
		res.append([txt, bom])
	return res

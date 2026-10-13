extends RefCounted
## Personagens da v2: cada personagem é um slot de save, com o santuário dele (almas, melhorias, conquistas e o último mapa).
## O índice (user://v2_personagens.cfg) lista os slots, na ordem de criação, e guarda o ativo. O save de cada slot fica em
## user://v2_personagem_<id>.cfg; ativar() aponta v2/meta.gd (caminho_save) para ele, e tudo o que lê a meta-progressão passa a
## valer para esse personagem. Criar um personagem novo começa com o santuário zerado.
## Migração: se o índice ainda não existe e há o save antigo (user://v2_progresso.cfg), ele vira o primeiro personagem. O arquivo
## antigo fica como está (e o .bak também), então nada se perde se algo der errado.
## Nomes, pastas dos retratos e arma inicial vêm de dados/v2_salao.json. Sem class_name: carregue com preload, como o resto do projeto.

const Meta := preload("res://v2/meta.gd")

static var caminho_indice := "user://v2_personagens.cfg"
static var caminho_base := "user://v2_personagem_"  # o arquivo de cada slot é caminho_base + id + ".cfg"
static var caminho_antigo := "user://v2_progresso.cfg"
const HEROI_PADRAO := "hazaki"


static func nomes() -> Array:
	return Dados.json("v2_salao").get("nomes", [])


static func caminho_do_save(id: String) -> String:
	return caminho_base + id + ".cfg"


static func _indice() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(caminho_indice)  # sem arquivo (ou ilegível) = índice vazio; nada é gravado até criar ou ativar
	return cf


## Os ids dos personagens, na ordem de criação.
static func lista() -> Array:
	return Array(_indice().get_value("geral", "lista", []))


static func ativo() -> String:
	return str(_indice().get_value("geral", "ativo", ""))


static func nome(id: String) -> String:
	return str(_indice().get_value(id, "nome", ""))


static func heroi(id: String) -> String:
	return str(_indice().get_value(id, "heroi", HEROI_PADRAO))


## Nomes que ainda não têm personagem (a tela de criar oferece só estes).
static func nomes_livres() -> Array:
	var usados := []
	for id in lista():
		usados.append(nome(id))
	return nomes().filter(func(n): return not usados.has(n.nome))


## Nível de cada melhoria do slot (id -> nível), lido do save dele, sem mexer na meta ativa.
static func niveis(id: String) -> Dictionary:
	var cf := ConfigFile.new()
	cf.load(caminho_do_save(id))
	var r := {}
	if cf.has_section("melhorias"):
		for k in cf.get_section_keys("melhorias"):
			r[k] = int(cf.get_value("melhorias", k, 0))
	return r


## Resumo do santuário de um slot, lido do save dele (sem mexer na meta ativa): almas, melhorias compradas e último mapa.
static func resumo(id: String) -> Dictionary:
	var cf := ConfigFile.new()
	cf.load(caminho_do_save(id))
	var compradas := 0
	for n in niveis(id).values():
		compradas += int(n)
	return {
		"id": id,
		"nome": nome(id),
		"heroi": heroi(id),
		"almas": int(cf.get_value("moeda", "almas", 0)),
		"niveis": compradas,
		"mapa": str(cf.get_value("config", "mapa", ""))
	}


## Copia o save antigo para o primeiro personagem, se for a primeira vez. Chamar à vontade: depois da primeira, não faz nada.
static func migrar_se_preciso() -> void:
	if FileAccess.file_exists(caminho_indice) or not FileAccess.file_exists(caminho_antigo):
		return
	var antigo := ConfigFile.new()
	if antigo.load(caminho_antigo) == OK:
		antigo.save(caminho_do_save("p1"))
	var antigo_bak := ConfigFile.new()
	if antigo_bak.load(caminho_antigo + ".bak") == OK:
		antigo_bak.save(caminho_do_save("p1") + ".bak")
	var cf := ConfigFile.new()
	cf.set_value("geral", "lista", ["p1"])
	cf.set_value("geral", "ativo", "p1")
	cf.set_value("p1", "nome", str(nomes()[0].nome) if not nomes().is_empty() else "Breno")
	cf.set_value("p1", "heroi", HEROI_PADRAO)
	cf.save(caminho_indice)


## Cria um personagem com santuário zerado (sem save anterior no caminho dele). Devolve o id, ou "" se não gravou.
static func criar(nome_novo: String, heroi_id := HEROI_PADRAO) -> String:
	var cf := _indice()
	var ids := lista()
	var id := "p%d" % (ids.size() + 1)
	while FileAccess.file_exists(caminho_do_save(id)):  # slot de um teste ou de uma tentativa anterior: não herda nada
		id = "p%d" % (int(id.substr(1)) + 1)
	ids.append(id)
	cf.set_value("geral", "lista", ids)
	cf.set_value(id, "nome", nome_novo)
	cf.set_value(id, "heroi", heroi_id)
	if cf.save(caminho_indice) != OK:
		return ""
	return id


## Põe o personagem como ativo (no índice e na meta): a partir daqui o santuário, os mapas e as almas são dele.
static func ativar(id: String) -> bool:
	if not lista().has(id):
		return false
	var cf := _indice()
	cf.set_value("geral", "ativo", id)
	if cf.save(caminho_indice) != OK:
		return false
	Meta.caminho_save = caminho_do_save(id)
	return true


## Ao abrir o jogo: garante a migração e aponta a meta para o personagem ativo (se houver um).
static func iniciar() -> void:
	migrar_se_preciso()
	var id := ativo()
	if id != "" and lista().has(id):
		Meta.caminho_save = caminho_do_save(id)

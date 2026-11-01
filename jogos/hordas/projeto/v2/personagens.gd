extends RefCounted
## Personagens da v2: cada personagem é um slot de save, com o santuário dele (almas, melhorias, conquistas e o último mapa).
## O índice (user://v2_personagens.cfg) lista os slots, na ordem de criação, e guarda o ativo. O save de cada slot fica em
## user://v2_personagem_<id>.cfg; ativar() aponta v2/meta.gd (caminho_save) para ele, e tudo o que lê a meta-progressão passa a
## valer para esse personagem. Criar um personagem novo começa com o santuário zerado.
## Migração: se o índice ainda não existe e há o save antigo (user://v2_progresso.cfg), ele vira o primeiro personagem. O arquivo
## antigo fica como está (e o .bak também), então nada se perde se algo der errado.
## Excluir: excluir(id) tira o personagem do índice e apaga o save dele (o .cfg, o .bak e o .tmp); apagar_tudo() zera todos os slots, o
## índice e o save antigo copiado (sem ele a migração traria o progresso de volta). Nenhum dos dois toca nas opções do jogador (Config:
## gráficos, som e controle), no marcador da migração de pasta nem na pasta antiga do Godot.
## Nomes, pastas dos retratos e arma inicial vêm de dados/v2_salao.json. Sem class_name: carregue com preload, como o resto do projeto.

const Meta := preload("res://v2/meta.gd")
const Herois := preload("res://v2/herois.gd")

static var caminho_indice := "user://v2_personagens.cfg"
static var caminho_base := "user://v2_personagem_"  # o arquivo de cada slot é caminho_base + id + ".cfg"
static var caminho_antigo := "user://v2_progresso.cfg"
const HEROI_PADRAO := "hazaki"
const PASTA_SPRITES := "res://prototipos/cara_nova/sprites/"


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


## O nome atual do personagem. Saves antigos guardam o nome de antes da troca para nomes em inglês (Nicão, Lucas...): o campo
## "nome_antigo" de dados/v2_salao.json traduz para o atual, então o que está gravado no índice não precisa ser migrado.
static func nome(id: String) -> String:
	var gravado := str(_indice().get_value(id, "nome", ""))
	for n in nomes():
		if str(n.get("nome_antigo", "")) == gravado and gravado != "":
			return str(n.nome)
	return gravado


## O herói do personagem `id`. Quem manda é o NOME (dados/v2_salao.json): o herói nunca foi escolha do jogador, então um save antigo que gravou o padrão
## (Hazaki) para um nome que hoje tem herói próprio (John, Matthew, Bert, Lukako, Fabian: #509, PER-3) passa a jogar com ele. Saves de Brendan, Nick e
## Luke não mudam, e um herói gravado que não é o padrão vale como está. Só leitura: o índice no disco continua como estava.
static func heroi(id: String) -> String:
	var gravado := str(_indice().get_value(id, "heroi", HEROI_PADRAO))
	return heroi_do_nome(nome(id)) if gravado == HEROI_PADRAO else gravado


## O herói que o nome joga ao ser criado (campo "heroi" de dados/v2_salao.json; sem ele, o Hazaki).
static func heroi_do_nome(nome_txt: String) -> String:
	for n in nomes():
		if str(n.nome) == nome_txt and Herois.existe(str(n.get("heroi", ""))):
			return str(n.heroi)
	return HEROI_PADRAO


## A folha de sprites que o NOME usa (campo opcional "sprite" de dados/v2_salao.json: nome da folha, sem extensão, em prototipos/cara_nova/sprites).
## Vazio = o personagem usa a folha do herói dele. Folha que não existe no disco também vale como vazio (o jogo cai na do herói).
static func sprite_do_nome(nome_txt: String) -> String:
	for n in nomes():
		if str(n.nome) == nome_txt:
			var s := str(n.get("sprite", ""))
			return s if s != "" and FileAccess.file_exists(PASTA_SPRITES + s + ".json") else ""
	return ""


## A folha do personagem `id` (slot do save), ou vazio.
static func sprite(id: String) -> String:
	return sprite_do_nome(nome(id))


## A folha que o personagem `id` desenha (retrato sem rosto, etc.): a própria (Matthew) ou, sem ela, a do herói dele (Hazaki, Nick, Luke).
static func folha(id: String) -> String:
	var s := sprite(id)
	return s if s != "" else Herois.sprite(heroi(id))


## O mesmo para um NOME ainda sem save (a oferta da tela de escolha).
static func folha_do_nome(nome_txt: String) -> String:
	var s := sprite_do_nome(nome_txt)
	return s if s != "" else Herois.sprite(heroi_do_nome(nome_txt))


## A arma inicial do herói do personagem (dados/v2_herois.json), em caixa de título.
static func arma_inicial(heroi_id: String) -> String:
	return str(Herois.heroi(heroi_id).get("arma", "")).capitalize()


## Nomes que ainda não têm personagem (a tela de criar oferece só estes).
static func nomes_livres() -> Array:
	var usados := []
	for id in lista():
		usados.append(nome(id))
	# nome de herói escondido (LightWolf, "beta": true em dados/v2_herois.json) só é oferecido a quem tem o herói liberado
	return nomes().filter(func(n): return not usados.has(n.nome) and (str(n.get("heroi", "")) == "" or Herois.existe(str(n.heroi))))


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
	cf.set_value("p1", "nome", str(nomes()[0].nome) if not nomes().is_empty() else "Brendan")
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


static func _apagar_arquivo(caminho: String) -> void:
	if FileAccess.file_exists(caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))


## O save de um slot e o que anda junto dele (.bak do backup e .tmp de uma gravação interrompida).
static func _apagar_save(caminho: String) -> void:
	for sufixo in ["", ".bak", ".tmp"]:
		_apagar_arquivo(caminho + sufixo)


## Exclui o personagem `id`: sai do índice (e do ativo, se era ele) e o save do slot é apagado. Devolve false, sem apagar nada, se o
## id não existe ou o índice não gravou. Se o excluído era o que a meta lia, a meta deixa de apontar para o slot (não o recria ao gravar).
static func excluir(id: String) -> bool:
	var ids := lista()
	if not ids.has(id):
		return false
	var cf := _indice()
	ids.erase(id)
	cf.set_value("geral", "lista", ids)
	if ativo() == id:
		cf.set_value("geral", "ativo", "")
	if cf.has_section(id):
		cf.erase_section(id)
	if cf.save(caminho_indice) != OK:
		return false
	_apagar_save(caminho_do_save(id))
	if Meta.caminho_save == caminho_do_save(id):
		Meta.caminho_save = caminho_antigo
	return true


## Apaga TODO o progresso: todos os slots (também os que o índice não lista), o índice e o save antigo (user://v2_progresso.cfg), que
## senão seria migrado de volta como personagem. Fica de fora tudo o que não é progresso: opções do jogador (Config) e marcador da migração.
static func apagar_tudo() -> void:
	var pasta := caminho_base.get_base_dir()
	var prefixo := caminho_base.get_file()
	var d := DirAccess.open(pasta)
	if d != null:
		for f in d.get_files():
			if f.begins_with(prefixo) and (f.ends_with(".cfg") or f.ends_with(".cfg.bak") or f.ends_with(".cfg.tmp")):
				_apagar_arquivo(pasta.path_join(f))
	_apagar_save(caminho_indice)
	_apagar_save(caminho_antigo)
	Meta.caminho_save = caminho_antigo


## Ao abrir o jogo: garante a migração e aponta a meta para o personagem ativo (se houver um).
static func iniciar() -> void:
	migrar_se_preciso()
	var id := ativo()
	if id != "" and lista().has(id):
		Meta.caminho_save = caminho_do_save(id)

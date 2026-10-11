extends Node
# Teste automático: criação de personagem, marco 2 (#72). Nome, pontos de atributo, defeito voluntário, aparência por paleta,
# até 6 heróis salvos (o 7º é recusado), morte de vez apaga, e a validação da ficha que chega pela rede.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/criacao2.tscn  (imprime "CRIACAO2 falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Criacao := preload("res://scripts/hordas/criacao.gd")
const Construcao := preload("res://scripts/hordas/construcao.gd")
const Paleta := preload("res://scripts/hordas/paleta.gd")
const Remoto := preload("res://scripts/hordas/remoto.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func ficha(nome: String, raca := "orc", classe := "guerreiro", pontos := {}, defeito := "", paleta := {}) -> Dictionary:
	var f := Criacao.ficha_nova(raca, classe)
	f["nome"] = nome
	f["defeito"] = defeito
	for k in pontos:
		f.pontos[k] = pontos[k]
	for k in paleta:
		f.paleta[k] = paleta[k]
	return f


## Primeiro pixel (RGB) de uma imagem com essa cor, em coordenadas [x, y]; [-1, -1] se não tem.
func achar(img: Image, r: int, g: int, b: int) -> Vector2i:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.9 and roundi(c.r * 255.0) == r and roundi(c.g * 255.0) == g and roundi(c.b * 255.0) == b:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func perto(a: Color, b: Color, tol := 0.02) -> bool:
	return absf(a.r - b.r) < tol and absf(a.g - b.g) < tol and absf(a.b - b.b) < tol


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	Criacao.arquivo = "user://teste_criacao2.json"
	Criacao.apagar()
	# --- os dados: tudo o que eles apontam existe
	var attrs := Criacao.lista_atributos()
	ok(attrs.size() >= 4 and attrs.size() <= 6, "poucos atributos (%d)" % attrs.size())
	for k in attrs:
		var a: Dictionary = Criacao.atributos().get(k, {})
		ok(a.has("nome") and a.has("descricao") and int(a.get("max", 0)) > 0, "atributo %s tem nome, descrição e teto" % k)
		for b in a.get("efeito", {}):
			ok(Construcao.BASE.has(b), "atributo %s: %s existe em Construcao.BASE" % [k, b])
	var defs := Criacao.lista_defeitos()
	ok(defs.size() >= 4 and defs.size() <= 6, "4 a 6 defeitos (%d)" % defs.size())
	for d in defs:
		var dd: Dictionary = Criacao.defeitos().get(d, {})
		ok(int(dd.get("pontos", 0)) > 0 and not dd.get("efeito", {}).is_empty(), "defeito %s dá pontos e tem efeito" % d)
		for b in dd.get("efeito", {}):
			ok(Construcao.BASE.has(b), "defeito %s: %s existe em Construcao.BASE" % [d, b])
	for canal in Paleta.canais():
		ok(Paleta.cores(canal).size() >= 6, "canal %s tem cores pra escolher" % canal)
	for r in Criacao.lista_racas():
		ok(int(Paleta.padrao(r).pele) < Paleta.cores("pele").size(), "raça %s tem pele padrão válida" % r)
	# --- pontos não passam do total
	var total := int(Criacao.atributos().total)
	ok(Criacao.erro_ficha(ficha("Brutus", "orc", "guerreiro", {"forca": 4, "vigor": 4})) == "", "gastar exatamente o total vale (%d)" % total)
	ok(Criacao.erro_ficha(ficha("Brutus", "orc", "guerreiro", {"forca": 5, "vigor": 4})) != "", "um ponto a mais que o total é recusado")
	ok(Criacao.erro_ficha(ficha("Brutus", "orc", "guerreiro", {"forca": 3})) == "", "gastar menos que o total vale")
	ok(Criacao.erro_ficha(ficha("Brutus", "orc", "guerreiro", {"forca": 99})) != "", "teto de um atributo só")
	ok(Criacao.erro_ficha(ficha("Brutus", "orc", "guerreiro", {"forca": -1, "vigor": 5})) != "", "ponto negativo é recusado")
	ok(Criacao.pontos_gastos({"forca": 2, "mente": 3}) == 5, "contagem de pontos gastos")
	# --- defeito dá os pontos
	var def := str(defs[0])
	var extra := int(Criacao.defeitos()[def].pontos)
	ok(Criacao.pontos_totais(def) == total + extra and Criacao.pontos_totais("") == total, "o defeito soma %d pontos ao total" % extra)
	ok(
		Criacao.erro_ficha(ficha("Brutus", "orc", "guerreiro", {"forca": 5, "vigor": 5, "sorte": total + extra - 10}, def)) == "",
		"com o defeito dá pra gastar o total + %d" % extra
	)
	ok(Criacao.erro_ficha(ficha("Brutus", "orc", "guerreiro", {"forca": 5, "vigor": 5, "sorte": total + extra - 9}, def)) != "", "e um a mais que isso não")
	ok(
		Criacao.erro_ficha(ficha("Brutus", "orc", "guerreiro", {"forca": 5, "vigor": 5, "sorte": total + extra - 10}, "")) != "",
		"tirando o defeito, os pontos extras viram recusa"
	)
	ok(Criacao.erro_ficha(ficha("Brutus", "orc", "guerreiro", {}, "defeito_que_nao_existe")) != "", "defeito inexistente é recusado")
	# --- os números chegam de verdade nos stats do jogo
	var f1 := ficha("Brutus", "humano", "guerreiro", {"forca": 4, "vigor": 3, "agilidade": 1}, "")
	var s1 := Construcao.stats(Criacao.montar("humano", "guerreiro", f1), {}, {})
	var s0 := Construcao.stats(Criacao.montar("humano", "guerreiro"), {}, {})
	ok(is_equal_approx(float(s1.dano) - float(s0.dano), 0.2), "4 pontos de força: +20%% de dano (%s)" % (float(s1.dano) - float(s0.dano)))
	ok(is_equal_approx(float(s1.vida_max) - float(s0.vida_max), 30.0), "3 pontos de vigor: +30 de vida (%s)" % (float(s1.vida_max) - float(s0.vida_max)))
	ok(is_equal_approx(float(s1.velocidade) - float(s0.velocidade), 0.03), "1 ponto de agilidade: +3%% de velocidade")
	var f2 := ficha("Brutus", "humano", "guerreiro", {}, "ossos_de_vidro")
	var s2 := Construcao.stats(Criacao.montar("humano", "guerreiro", f2), {}, {})
	ok(is_equal_approx(float(s2.vida_max), float(s0.vida_max) - 35.0), "Ossos de Vidro: -35 de vida (%s)" % s2.vida_max)
	var h := Criacao.montar("humano", "guerreiro", f1)
	ok(str(h.nome) == "Brutus" and str(h.titulo) == "Humano Guerreiro", "o herói tem o nome da ficha e o título raça + classe")
	ok(h.paleta == f1.paleta, "a paleta da ficha vai pro herói")
	# --- nome: validação e limite
	for ruim in ["", "A", "NomeGrandeDemaisAqui", "  espaço", "x\ny", "Ωmega", "<script>"]:
		ok(Criacao.erro_ficha(ficha(ruim)) != "", "nome recusado (%s)" % ruim.replace("\n", "\\n"))
	for bom in ["Ze", "João", "Maria Clara", "Brutus 2"]:
		ok(Criacao.erro_ficha(ficha(bom)) == "", "nome aceito (%s)" % bom)
	# --- salvar e carregar 6 heróis, o 7º é recusado
	var ids := []
	var nomes := ["Brutus", "Lyra", "Pip", "Thorn", "Mira", "Gus"]
	for i in nomes.size():
		var id := Criacao.salvar_ficha(
			ficha(nomes[i], Criacao.lista_racas()[i % 5], Criacao.lista_classes()[i % 5], {"forca": i % 4}, "", {"pele": i, "cabelo": 7 - i, "roupa": i})
		)
		ok(id != "" and not id in ids, "salvou o herói %d (%s)" % [i + 1, nomes[i]])
		ids.append(id)
	ok(Criacao.quantos() == 6, "6 heróis salvos")
	ok(Criacao.salvar_ficha(ficha("Setimo")) == "", "o 7º herói é recusado")
	ok(Criacao.quantos() == 6, "continuam 6 depois da recusa")
	ok(Criacao.salvar("c:orc:guerreiro") == false, "o formato antigo também não passa de 6")
	Dados.herois_extra.clear()
	Dados.recarregar()
	var cr := Criacao.carregar(false)
	ok(cr.ids == ids, "carregar devolve os 6 na ordem")
	for i in nomes.size():
		var hh: Dictionary = Dados.json("herois").get(ids[i], {})
		ok(str(hh.get("nome", "")) == nomes[i], "herói %d volta com o nome %s (%s)" % [i + 1, nomes[i], hh.get("nome", "?")])
		ok(int(hh.get("paleta", {}).get("pele", -1)) == i and int(hh.paleta.cabelo) == 7 - i, "herói %d volta com a paleta" % [i + 1])
	Criacao.apagar(ids[5])
	ok(Criacao.quantos() == 5, "apagou um: sobram 5")
	ok(Criacao.erro_ficha(ficha("BRUTUS")) == "" and Criacao.salvar_ficha(ficha("BRUTUS")) == "", "com vaga livre, nome repetido (qualquer caixa) é recusado")
	var novo := Criacao.salvar_ficha(ficha("Zeca"))
	ok(novo != "" and Criacao.quantos() == 6, "com vaga livre e nome novo, salva")
	Criacao.apagar(novo)
	# --- morte de vez apaga só aquele herói
	var morto: String = ids[2]
	ok(Criacao.morreu_de_vez({"heroi": morto, "vitoria": false}), "corrida perdida mata o herói criado")
	Criacao.apagar(morto)
	var rest: Array = Criacao.carregar(false).ids
	ok(rest.size() == 4 and not morto in rest, "morreu: o herói some da lista, os outros ficam (%d)" % rest.size())
	ok(not Dados.herois_extra.has(morto), "e sai da tabela de heróis")
	Criacao.comecou(ids[0])
	var c2 := Criacao.carregar()
	ok(c2.perdidos == [ids[0]] and not ids[0] in c2.ids and c2.ids.size() == 3, "fechar o jogo na corrida mata só o herói que estava nela")
	ok(Criacao.carregar(false).ids.size() == 3, "e o arquivo ficou com 3")
	Criacao.apagar()
	# --- arquivo do formato antigo (um herói só) ainda abre
	var fa := FileAccess.open(Criacao.arquivo, FileAccess.WRITE)
	fa.store_string('{"id": "c:orc:guerreiro", "em_corrida": false}')
	fa = null
	ok(Criacao.carregar(false).ids == ["c:orc:guerreiro"], "o arquivo do marco 1 ainda é lido")
	Criacao.apagar()
	# --- paleta muda as cores (pele, cabelo e roupa), e o contorno fica
	var t0 := Time.get_ticks_msec()
	var orig := Dados.tex_personagem("hazaki", "corpo").get_image()
	var pele_xy := achar(orig, 177, 110, 82)
	var roupa_xy := achar(orig, 42, 36, 38)
	var cont_xy := achar(orig, 13, 11, 20)
	ok(pele_xy.x >= 0 and roupa_xy.x >= 0 and cont_xy.x >= 0, "achei pele, roupa e contorno no corpo original")
	var pal := {"pele": 4, "cabelo": 3, "roupa": 2}
	var tex := Paleta.textura("hazaki", "corpo", pal)
	var ms := Time.get_ticks_msec() - t0
	var rec := tex.get_image()
	print("paleta: recolorir o corpo inteiro levou %d ms" % ms)
	ok(perto(rec.get_pixelv(pele_xy), Paleta.cor("pele", 4)), "pele verde: o pixel de pele virou a cor escolhida (%s)" % rec.get_pixelv(pele_xy))
	ok(perto(rec.get_pixelv(roupa_xy), Paleta.cor("roupa", 2)), "roupa azul: o tom médio virou a cor escolhida (%s)" % rec.get_pixelv(roupa_xy))
	ok(rec.get_pixelv(cont_xy).is_equal_approx(orig.get_pixelv(cont_xy)), "o contorno escuro não muda")
	ok(rec.get_pixelv(pele_xy) != orig.get_pixelv(pele_xy), "a textura recolorida é diferente da original")
	var rec2 := Paleta.textura("hazaki", "corpo", {"pele": 1, "cabelo": 3, "roupa": 2}).get_image()
	ok(not perto(rec2.get_pixelv(pele_xy), rec.get_pixelv(pele_xy)), "outra pele, outra cor no mesmo pixel")
	ok(perto(rec2.get_pixelv(roupa_xy), rec.get_pixelv(roupa_xy)), "mexer na pele não mexe na roupa")
	ok(Paleta.textura("hazaki", "corpo", pal) == tex, "a mesma paleta vem do cache")
	ok(Paleta.textura("hazaki", "corpo", {}) == Dados.tex_personagem("hazaki", "corpo"), "paleta vazia é a textura original")
	var cab0 := Dados.tex_personagem("hazaki", "camadas/cabelo").get_image()
	var cab_xy := achar(cab0, 26, 22, 24)
	ok(cab_xy.x >= 0, "achei o tom médio do cabelo")
	var cab1 := Paleta.textura("hazaki", "camadas/cabelo", {"pele": 0, "cabelo": 3, "roupa": 0}).get_image()
	ok(perto(cab1.get_pixelv(cab_xy), Paleta.cor("cabelo", 3)), "cabelo ruivo: o tom médio virou a cor escolhida (%s)" % cab1.get_pixelv(cab_xy))
	var padrao := Paleta.textura("hazaki", "corpo", {"pele": 0, "cabelo": 0, "roupa": 0}).get_image()
	var iguais := 0
	for i in 200:
		var xy := Vector2i((i * 37) % orig.get_width(), (i * 91) % orig.get_height())
		if perto(padrao.get_pixelv(xy), orig.get_pixelv(xy), 0.01):
			iguais += 1
	ok(iguais >= 195, "a paleta padrão deixa o corpo como era (%d de 200 pixels iguais)" % iguais)
	# --- a validação de rede recusa valores fora da faixa (o anfitrião usa Rede.erro_heroi)
	var base := ficha("Brutus", "orc", "guerreiro", {"forca": 4, "vigor": 4}, "", {"pele": 2})
	ok(Rede.erro_heroi("c:h1f3a", base) == "", "ficha boa passa na rede")
	ok(Rede.erro_heroi("hazaki", {}) == "" and Rede.erro_heroi("c:orc:guerreiro", {}) == "", "herói fixo e id antigo passam sem ficha")
	var maus := {
		"pontos demais": ficha("Brutus", "orc", "guerreiro", {"forca": 6, "vigor": 6}),
		"ponto negativo": ficha("Brutus", "orc", "guerreiro", {"forca": -3, "vigor": 5}),
		"pontos gigantes": ficha("Brutus", "orc", "guerreiro", {"forca": 1000000}),
		"atributo inventado": ficha("Brutus", "orc", "guerreiro", {"poder_supremo": 2}),
		"raça inventada": ficha("Brutus", "dragao", "guerreiro"),
		"classe inventada": ficha("Brutus", "orc", "pizzaiolo"),
		"defeito inventado": ficha("Brutus", "orc", "guerreiro", {}, "super_defeito"),
		"paleta alta": ficha("Brutus", "orc", "guerreiro", {}, "", {"pele": 99}),
		"paleta negativa": ficha("Brutus", "orc", "guerreiro", {}, "", {"roupa": -1}),
		"nome comprido": ficha("Brutus o Destruidor de Mundos"),
		"nome vazio": ficha(""),
		"nome com símbolo": ficha("Bru<tus>"),
	}
	for k in maus:
		ok(Rede.erro_heroi("c:h1f3a", maus[k]) != "", "rede recusa: " + k)
	var tipo := base.duplicate(true)
	tipo["pontos"] = "muitos"
	ok(Rede.erro_heroi("c:h1f3a", tipo) != "", "rede recusa: pontos que não são tabela")
	tipo = base.duplicate(true)
	tipo.pontos["forca"] = "9"
	ok(Rede.erro_heroi("c:h1f3a", tipo) != "", "rede recusa: ponto em texto")
	tipo = base.duplicate(true)
	tipo.paleta["pele"] = 1.5
	ok(Rede.erro_heroi("c:h1f3a", tipo) != "", "rede recusa: índice de paleta quebrado")
	tipo = base.duplicate(true)
	tipo["nome"] = 42
	ok(Rede.erro_heroi("c:h1f3a", tipo) != "", "rede recusa: nome que não é texto")
	ok(Rede.erro_heroi("c:h1f3a", null) != "" and Rede.erro_heroi("c:h1f3a", "ficha") != "", "rede recusa: ficha que nem é tabela")
	for id_ruim in ["c:", "c:h", "c:x1f", "c:h1f;rm", "c:hhhhhhhhhhhhhhhhhhhhhhhh", "pizzaiolo", "c:dragao:guerreiro", ""]:
		ok(Rede.erro_heroi(id_ruim, base) != "", "rede recusa o id (%s)" % id_ruim)
	var limpa := Criacao.validar_ficha(base)
	ok(not limpa.is_empty() and limpa.nome == "Brutus" and int(limpa.pontos.forca) == 4, "a ficha limpa mantém o que vale")
	tipo = base.duplicate(true)
	tipo["bagulho"] = "x".repeat(5000)
	ok(not Criacao.validar_ficha(tipo).has("bagulho"), "e joga fora campo desconhecido")
	# --- cada máquina monta o mesmo herói a partir da lista da sala (o que o cliente faz ao receber _lista)
	Dados.herois_extra.clear()
	Dados.recarregar()
	Rede.jogadores = {1: {"heroi": "hazaki", "nome": "Anfi", "pronto": true}, 2: {"heroi": "c:h1f3a", "nome": "apelido", "pronto": false, "ficha": limpa}}
	Rede._registrar_criados()
	var hr: Dictionary = Dados.json("herois").get("c:h1f3a", {})
	ok(str(hr.get("nome", "")) == "Brutus" and int(hr.get("paleta", {}).get("pele", -1)) == 2, "o cliente monta o herói do outro com nome e paleta")
	ok(Rede.nome_de(2) == "Brutus", "e na sala ele aparece com o nome do herói (%s)" % Rede.nome_de(2))
	ok(
		is_equal_approx(float(Construcao.stats(hr, {}, {}).dano), float(Construcao.stats(Criacao.montar("orc", "guerreiro", limpa), {}, {}).dano)),
		"os stats batem nas duas máquinas"
	)
	ok(Rede.ocupados().is_empty() or not "c:h1f3a" in Rede.ocupados(), "herói criado não ocupa vaga do elenco")
	ok(Rede._id_criado_em_uso(1, "c:h1f3a") and not Rede._id_criado_em_uso(2, "c:h1f3a"), "o mesmo id criado não pode ser de duas pessoas")
	Rede.jogadores = {}
	# --- o outro jogador, desenhado no meu computador: corpo e cabelo recoloridos
	var rm := Remoto.new()
	add_child(rm)
	rm.configurar(2, "c:h1f3a", "Brutus")
	ok(rm.spr.texture == Paleta.textura("hazaki", "corpo", {"pele": 2, "cabelo": 0, "roupa": 0}), "o boneco remoto usa o corpo recolorido")
	ok(rm._cab != null, "e tem a camada de cabelo")
	rm.queue_free()
	# --- uma partida com o herói criado: stats, paleta e camadas no jogador de verdade
	Criacao.apagar()
	var id := Criacao.salvar_ficha(ficha("Gorda", "orc", "guerreiro", {"forca": 4, "vigor": 2}, "mao_tremula", {"pele": 4, "cabelo": 5, "roupa": 1}))
	ok(id != "", "salvou o herói da partida")
	var a := Arena.new()
	a.heroi_id = id
	add_child(a)
	await esperar(0.4)
	ok(is_equal_approx(a.stat("dano"), 1.0 + 0.2 + 0.2 - 0.05), "na partida: orc +20%%, força +20%%, mão trêmula -5%% de dano (%s)" % a.stat("dano"))
	ok(is_equal_approx(a.stat("vida_max"), 145.0), "na partida: 100 + 25 do guerreiro + 20 do vigor (%s)" % a.stat("vida_max"))
	ok(a.jogador.paleta == {"pele": 4, "cabelo": 5, "roupa": 1}, "o jogador recebeu a paleta")
	ok(a.jogador.spr.texture == Paleta.textura("hazaki", "corpo", a.jogador.paleta), "o corpo do jogador está recolorido")
	ok(
		a.jogador.camadas.has("cabelo") and a.jogador.camadas.cabelo.texture == Paleta.textura("hazaki", "camadas/cabelo", a.jogador.paleta),
		"o cabelo do jogador está recolorido"
	)
	ok(a.armas.achar("lanca") != null, "arma da classe")
	a.queue_free()
	await esperar(0.1)
	Criacao.apagar()
	Criacao.arquivo = Criacao.ARQUIVO
	print("CRIACAO2 falhas=%d" % falhas)
	get_tree().quit()

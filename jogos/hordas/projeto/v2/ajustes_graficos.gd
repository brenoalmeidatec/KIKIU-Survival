extends RefCounted
## Gráficos do menu de pausa da v2: o menu completo da aba Gráficos da v1 (perfis Baixo, Médio e Alto, detectar pela máquina,
## CPU e GPU com sliders e listas), dirigido por dados/graficos.json e pela API do Config (g, g_definir, g_perfil,
## g_aplicar_perfil, g_detectar, g_opcoes, g_opcao). Opção nova no json aparece sozinha.
## A tela da v1 (scripts/hordas/tela_graficos.gd) não é usada: ela desenha tudo numa caixa de 640x360 e lê o mouse no espaço
## da própria tela, o que não cabe no SubViewport da partida. Esta classe só dá as linhas e aplica as ações; o desenho e a
## entrada são da pausa (pausa.gd), com a fonte da v2.
## O menu só mostra as opções que a v2 lê hoje (LIDAS_NA_V2), todas valendo na hora na partida. As outras do json seguem nos
## perfis (a v1 usa), mas sem linha aqui: opção que não faz nada na tela não aparece. Opção nova só entra na lista depois de ser lida.
## Ids das linhas: "g:perfil", "g:dinamico", "g:detectar", "g:tela", "g:fps", "g:piscadas", "g:ui" e "g:op:<chave>"; cabeçalhos de seção têm id "" e "cab": true.
## Perfil tem só Baixo, Médio e Alto (e Personalizado, quando uma opção é mexida à mão). O Ajuste dinâmico (qualidade_auto) é uma linha
## própria, logo abaixo do Perfil: com ele ligado a partida começa no Perfil escolhido, desce um degrau por vez se o fps travar e sobe de
## volta só até o Perfil escolhido (v2/qualidade_auto.gd; o Config guarda o escolhido em g_perfil_escolhido e a queda só na memória).
## Com ele ligado os DOIS seletores manuais de detalhe ficam apagados (linha com "bloqueado": true: a pausa não deixa mudar): o Perfil (Baixo,
## Médio, Alto: cada um fixa todos os detalhes de uma vez) e as opções soltas da tela Avançado. A ajuda diz que quem manda é o Ajuste dinâmico
## e o Perfil que estava escolhido vira o teto da subida. Por isso com ele ligado não há Personalizado: o Config.recarregar abre um save
## Personalizado como Não e ligar o dinâmico estando em Personalizado aplica o perfil da máquina (senão ficaria sem Perfil e sem como sair).
## Desligado, tudo volta a ser editável e mexer numa opção vira Personalizado. Detectar pela máquina, Tela cheia, Mostrar FPS, Reduzir piscadas e o
## Tamanho da interface ficam sempre livres. Detectar escolhe o Perfil (a máquina, não o jogador) e deixa o Ajuste dinâmico como está (o padrão de
## máquina nova é Sim).
## Tela cheia, o Ajuste dinâmico, o contador de fps e Reduzir piscadas são opções do jogador (seção "opcoes" do Config, não a "graficos"): mexer nelas não vira Personalizado.

const CursorKikiu := preload("res://v2/cursor_kikiu.gd")
const PERFIS := ["baixo", "medio", "alto"]
const NOMES_PERFIL := {"baixo": "Baixo", "medio": "Médio", "alto": "Alto", "personalizado": "Personalizado"}
const SECOES := ["cpu", "gpu"]
const NOMES_SECAO := {"cpu": "CPU (simulação)", "gpu": "GPU (visual)"}
const LIDAS_NA_V2 := ["particulas_sim", "calculo_monstros", "luz_relevo", "sombras", "nevoa", "tremor_clarao", "limite_fps", "vsync"]
const AJUDA_PERFIL := "Baixo, Médio e Alto fixam tudo. Mexer numa opção vira Personalizado."
const AJUDA_DINAMICO := "Baixa a qualidade sozinho se o jogo travar e volta quando o FPS firmar, sem passar do Perfil escolhido. Ligado, o Perfil e os detalhes do Avançado ficam travados."
const AJUDA_BLOQUEADO := "Controlado pelo Ajuste dinâmico. Desligue-o para ajustar à mão."
const AJUDA_PERFIL_BLOQUEADO := "Travado: o Ajuste dinâmico escolhe a qualidade sozinho e este Perfil é o teto dele. Desligue-o para escolher à mão."
const AJUDA_AVANCADO := "Opção por opção, separadas pelo que pesa na CPU (a conta do jogo) e na GPU (o desenho na tela)."
const AJUDA_DETECTAR := "Escolhe o perfil pela máquina: placa de vídeo e número de processadores."
const AJUDA_FPS := "Mostra os quadros por segundo no canto de baixo da tela."
const AJUDA_PISCADAS := "Tira o que liga e desliga rápido: invencibilidade, clarões, glitch, vida e fôlego baixos, avisos e flashes de acerto. No máximo 3 trocas de luz por segundo."
const AJUDA_UI := "Tamanho de menus, cartas e HUD. Automático ajusta à janela num tamanho confortável, sem cortar nada; Pequeno, Médio e Grande são fixos."
const AJUDA_TELA := "Ocupa a tela inteira. F11 também liga e desliga, em qualquer tela da v2."
const AJUDA_CURSOR_FORMA := "Desenho do cursor dentro da partida: a mira (retícula) ou a seta. Nos menus o cursor é sempre a seta."
const AJUDA_CURSOR_COR := "Cor do cursor em pixel art, nos menus e na partida."

var mensagem := ""  # aviso curto do detectar, mostrado no rodapé da pausa


## As linhas da tela Gráficos: o essencial. As opções soltas (CPU e GPU) ficam na tela Avançado (itens_avancado).
func itens() -> Array:
	var perfil := _it("g:perfil", "Perfil", _nome_perfil(), AJUDA_PERFIL)
	perfil["icone"] = true  # o "?": a pausa desenha o ícone depois do nome; a ajuda sai no rodapé com o foco ou o mouse
	if dinamico_ligado():
		perfil["bloqueado"] = true
		perfil["ajuda"] = AJUDA_PERFIL_BLOQUEADO
	var r: Array = [perfil]
	(
		r
		. append_array(
			[
				_it("g:dinamico", "Ajuste dinâmico", _sim_nao("qualidade_auto"), AJUDA_DINAMICO),
				_it("g:detectar", "Detectar pela máquina", "", AJUDA_DETECTAR),
				_it("g:tela", "Tela cheia (F11)", _sim_nao("tela_cheia"), AJUDA_TELA),
				_it("g:fps", "Mostrar FPS", _sim_nao("mostrar_fps"), AJUDA_FPS),
				_it("g:piscadas", "Reduzir piscadas", _sim_nao("reduzir_piscadas"), AJUDA_PISCADAS),
				_it("g:ui", "Tamanho da interface", Config.rotulo("tamanho_ui"), AJUDA_UI),
				_it(
					"g:cursor_forma", "Cursor na partida", CursorKikiu.ROTULOS_FORMA.get(CursorKikiu._opcao("cursor_forma", "mira"), "Mira"), AJUDA_CURSOR_FORMA
				),
				_it("g:cursor_cor", "Cor do cursor", CursorKikiu.ROTULOS_COR.get(CursorKikiu.cor_atual(), "Ouro"), AJUDA_CURSOR_COR),
				_it("g:avancado", "Avançado", "CPU e GPU", AJUDA_AVANCADO),
				_it("voltar", "Voltar"),
			]
		)
	)
	return r


## As linhas da tela Avançado: uma seção CPU e outra GPU, com as opções que a v2 lê (a ordem é a do json).
func itens_avancado() -> Array:
	var r: Array = []
	var opcoes: Array = Config.g_opcoes()
	for sec in SECOES:
		r.append({"id": "", "rotulo": NOMES_SECAO[sec], "valor": "", "ajuda": "", "cab": true})
		for op in opcoes:
			if str(op.get("secao", "")) == sec and lida_na_v2(str(op.get("chave", ""))):
				r.append(_linha_opcao(op))
	r.append(_it("voltar", "Voltar"))
	return r


## O perfil que o jogador vê: o de agora (Baixo, Médio, Alto ou Personalizado); se o Ajuste dinâmico já desceu, "Médio (dinâmico)".
func _nome_perfil() -> String:
	var agora := str(Config.g_perfil())
	var nome: String = NOMES_PERFIL.get(agora, "Personalizado")
	if dinamico_ligado() and agora != "personalizado" and agora != Config.g_perfil_escolhido():
		return "%s (dinâmico)" % nome
	return nome


## Aplica a ação de uma linha. `id` vem sem o prefixo "g:"; passo é +1 ou -1 (setas, clique esquerdo, Enter).
func agir(id: String, passo: int) -> void:
	if id == "perfil":
		_trocar_perfil(passo)
	elif id == "dinamico":
		_alternar("qualidade_auto")
		if not dinamico_ligado():
			Config.g_soltar_temporario()  # desligou com o perfil já caído: volta na hora ao Perfil escolhido
		elif Config.g_perfil_escolhido() == "personalizado":
			aplicar_perfil(Config.g_detectar())  # ligado não há Personalizado e o Perfil fica travado: a máquina escolhe o teto
	elif id == "detectar":
		_detectar()
	elif id == "tela":
		_alternar("tela_cheia")  # a F11 (pausa.gd) chama esta mesma linha
	elif id == "fps":
		_alternar("mostrar_fps")
	elif id == "piscadas":
		_alternar("reduzir_piscadas")  # fora do perfil: não vira Personalizado
	elif id == "ui":
		Config.girar("tamanho_ui", passo)  # a apresentação e as telas refazem o layout na hora (Config.tamanho_ui_mudou)
	elif id == "cursor_forma":
		_girar_cursor("cursor_forma", CursorKikiu.FORMAS, passo)
	elif id == "cursor_cor":
		_girar_cursor("cursor_cor", CursorKikiu.CORES.keys(), passo)
	elif id.begins_with("op:"):
		_mudar_opcao(id.substr(3), passo)


## O Ajuste dinâmico está ligado? Com ele ligado o Perfil e as opções do Avançado ficam travados (a linha pede "bloqueado": true).
func dinamico_ligado() -> bool:
	return bool(Config.v("qualidade_auto"))


## A v2 lê esta opção? (só as lidas ganham linha no menu)
func lida_na_v2(chave: String) -> bool:
	return LIDAS_NA_V2.has(chave)


## Liga ou desliga uma opção de sim ou não que fica fora do perfil (tela cheia, o Ajuste dinâmico, o contador de fps).
## Forma e cor do cursor: giram na lista e o cursor já muda na tela (v2/cursor_kikiu.gd lê a escolha de novo).
func _girar_cursor(chave: String, vals: Array, passo: int) -> void:
	var i := maxi(0, vals.find(CursorKikiu._opcao(chave, str(vals[0]))))
	Config.definir(chave, vals[posmod(i + passo, vals.size())])
	CursorKikiu.refrescar()


func _alternar(chave: String) -> void:
	Config.definir(chave, not bool(Config.v(chave)))


func _sim_nao(chave: String) -> String:
	return "Sim" if bool(Config.v(chave)) else "Não"


func _linha_opcao(op: Dictionary) -> Dictionary:
	var chave := str(op.get("chave", ""))
	var linha := _it("g:op:" + chave, str(op.get("nome", chave)), _texto_valor(op), str(op.get("ajuda", "")))
	if dinamico_ligado():
		linha["bloqueado"] = true
		linha["ajuda"] = AJUDA_BLOQUEADO
	return linha


func _texto_valor(op: Dictionary) -> String:
	var chave := str(op.get("chave", ""))
	var valor = Config.g(chave)
	if str(op.get("tipo", "")) == "slider":
		return _fmt_num(float(valor) if valor != null else float(op.get("min", 0)), float(op.get("passo", 1))) + str(op.get("unidade", ""))
	return _rotulo(op, valor)


func _trocar_perfil(passo: int) -> void:
	if dinamico_ligado():
		return  # o Ajuste dinâmico manda (a linha aparece apagada): defesa para quem chamar sem passar pela pausa
	var i := PERFIS.find(Config.g_perfil_escolhido())  # as setas partem do escolhido, não da queda do dinâmico
	if i < 0:
		i = 0 if passo > 0 else PERFIS.size() - 1  # personalizado: a seta começa de um lado ou do outro (como na v1)
	else:
		i = posmod(i + passo, PERFIS.size())
	aplicar_perfil(PERFIS[i])


## Escolhe um perfil da lista (Baixo, Médio ou Alto). Não mexe no Ajuste dinâmico: ele segue como o jogador deixou.
func aplicar_perfil(nome: String) -> void:
	Config.g_aplicar_perfil(nome)


func _detectar() -> void:
	var r = Config.g_detectar()
	if r is String and PERFIS.has(r):
		aplicar_perfil(r)
		mensagem = "Detectado: %s" % NOMES_PERFIL[r]
	else:
		mensagem = "Não deu para detectar"


## Uma opção do json: slider soma o passo (arredondado à grade), menu e sim_nao dão a volta na lista de valores.
func _mudar_opcao(chave: String, passo: int) -> void:
	if dinamico_ligado():
		return  # o Ajuste dinâmico manda (a linha aparece apagada): defesa para quem chamar sem passar pela pausa
	var op: Dictionary = Config.g_opcao(chave)
	if op.is_empty():
		return
	if str(op.get("tipo", "")) == "slider":
		var atual = Config.g(chave)
		var base := float(atual) if atual != null else float(op.get("min", 0))
		Config.g_definir(chave, _ajustar(op, base + passo * float(op.get("passo", 1))))
		return
	var padrao: Array = [false, true] if str(op.get("tipo", "")) == "sim_nao" else []
	var vals: Array = op.get("valores", padrao)
	if vals.is_empty():
		return
	var i := _indice(vals, Config.g(chave))
	if i < 0:
		i = 0 if passo > 0 else vals.size() - 1
	else:
		i = posmod(i + passo, vals.size())
	Config.g_definir(chave, vals[i])


## Valor da API arredondado à grade do controle (min, passo, max). Inteiro quando a grade é inteira (como na v1).
func _ajustar(op: Dictionary, v: float) -> Variant:
	var lo := float(op.get("min", 0))
	var hi := float(op.get("max", 1))
	var st := float(op.get("passo", 1))
	var r := clampf(v, lo, hi)
	if st > 0.0:
		r = clampf(lo + roundf((r - lo) / st) * st, lo, hi)
	if is_equal_approx(lo, roundf(lo)) and is_equal_approx(hi, roundf(hi)) and is_equal_approx(st, roundf(st)):
		return roundi(r)
	return r


func _indice(vals: Array, valor) -> int:
	for i in vals.size():
		var v = vals[i]
		if (v is float or v is int) and (valor is float or valor is int):
			if is_equal_approx(float(v), float(valor)):
				return i
		elif v == valor:
			return i
	return -1


func _rotulo(op: Dictionary, valor) -> String:
	var padrao: Array = [false, true] if str(op.get("tipo", "")) == "sim_nao" else []
	var vals: Array = op.get("valores", padrao)
	var rot: Array = op.get("rotulos", [])
	var i := _indice(vals, valor)
	if i >= 0 and i < rot.size():
		return str(rot[i])
	if valor is bool:
		return "Sim" if valor else "Não"
	return str(valor)


func _fmt_num(v: float, passo: float) -> String:
	if passo >= 1.0 and is_equal_approx(v, roundf(v)):
		return "%d" % roundi(v)
	return "%.2f" % v


func _it(id: String, rotulo: String, valor := "", ajuda := "") -> Dictionary:
	return {"id": id, "rotulo": rotulo, "valor": valor, "ajuda": ajuda}

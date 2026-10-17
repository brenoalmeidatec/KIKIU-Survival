extends RefCounted
## Gráficos do menu de pausa da v2: o menu completo da aba Gráficos da v1 (perfis Baixo, Médio e Alto, detectar pela máquina,
## CPU e GPU com sliders e listas), dirigido por dados/graficos.json e pela API do Config (g, g_definir, g_perfil,
## g_aplicar_perfil, g_detectar, g_opcoes, g_opcao). Opção nova no json aparece sozinha.
## A tela da v1 (scripts/hordas/tela_graficos.gd) não é usada: ela desenha tudo numa caixa de 640x360 e lê o mouse no espaço
## da própria tela, o que não cabe no SubViewport da partida. Esta classe só dá as linhas e aplica as ações; o desenho e a
## entrada são da pausa (pausa.gd), com a fonte da v2.
## O menu só mostra as opções que a v2 lê hoje (LIDAS_NA_V2), todas valendo na hora na partida. As outras do json seguem nos
## perfis (a v1 usa), mas sem linha aqui: opção que não faz nada na tela não aparece. Opção nova só entra na lista depois de ser lida.
## Ids das linhas: "g:perfil", "g:detectar", "g:tela", "g:qualidade", "g:fps", "g:ui" e "g:op:<chave>"; cabeçalhos de seção têm id "" e "cab": true.
## Tela cheia, a baixa automática e o contador de fps são opções do jogador (seção "opcoes" do Config, não a "graficos"): mexer nelas não vira Personalizado.

const PERFIS := ["baixo", "medio", "alto"]
const NOMES_PERFIL := {"baixo": "Baixo", "medio": "Médio", "alto": "Alto", "personalizado": "Personalizado"}
const SECOES := ["cpu", "gpu"]
const NOMES_SECAO := {"cpu": "CPU (simulação)", "gpu": "GPU (visual)"}
const LIDAS_NA_V2 := ["particulas_sim", "luz_relevo", "sombras", "tremor_clarao", "limite_fps", "vsync"]
const AJUDA_PERFIL := "Baixo, Médio e Alto mudam todas as opções de uma vez. Mexer numa opção deixa o perfil Personalizado."
const AJUDA_DETECTAR := "Escolhe o perfil pela máquina: placa de vídeo e número de processadores."
const AJUDA_FPS := "Mostra os quadros por segundo no canto de baixo da tela."
const AJUDA_UI := "Tamanho de menus, cartas e HUD. Automático usa o maior tamanho que cabe na janela, sem cortar nada; os outros são fixos."
const AJUDA_TELA := "Ocupa a tela inteira. F11 também liga e desliga, em qualquer tela da v2."
const AJUDA_QUALIDADE := "Se o fps ficar abaixo de 40 por 8 s, o perfil desce um degrau (Alto, Médio, Baixo) só nesta sessão, sem mudar o salvo. O Personalizado não muda."

var mensagem := ""  # aviso curto do detectar, mostrado no rodapé da pausa


## As linhas da aba, na ordem do json (seção por seção), com o valor atual lido da API.
func itens() -> Array:
	var r: Array = [
		_it("g:perfil", "Perfil", NOMES_PERFIL.get(str(Config.g_perfil()), "Personalizado"), AJUDA_PERFIL),
		_it("g:detectar", "Detectar pela máquina", "", AJUDA_DETECTAR),
		_it("g:tela", "Tela cheia (F11)", _sim_nao("tela_cheia"), AJUDA_TELA),
		_it("g:qualidade", "Baixar a qualidade se travar", _sim_nao("qualidade_auto"), AJUDA_QUALIDADE),
		_it("g:fps", "Mostrar FPS", _sim_nao("mostrar_fps"), AJUDA_FPS),
		_it("g:ui", "Tamanho da interface", Config.rotulo("tamanho_ui"), AJUDA_UI),
	]
	var opcoes: Array = Config.g_opcoes()
	for sec in SECOES:
		r.append({"id": "", "rotulo": NOMES_SECAO[sec], "valor": "", "ajuda": "", "cab": true})
		for op in opcoes:
			if str(op.get("secao", "")) == sec and lida_na_v2(str(op.get("chave", ""))):
				r.append(_linha_opcao(op))
	r.append(_it("voltar", "Voltar"))
	return r


## Aplica a ação de uma linha. `id` vem sem o prefixo "g:"; passo é +1 ou -1 (setas, clique esquerdo, Enter).
func agir(id: String, passo: int) -> void:
	if id == "perfil":
		_trocar_perfil(passo)
	elif id == "detectar":
		_detectar()
	elif id == "tela":
		_alternar("tela_cheia")  # a F11 (pausa.gd) chama esta mesma linha
	elif id == "qualidade":
		_alternar("qualidade_auto")
	elif id == "fps":
		_alternar("mostrar_fps")
	elif id == "ui":
		Config.girar("tamanho_ui", passo)  # a apresentação e as telas refazem o layout na hora (Config.tamanho_ui_mudou)
	elif id.begins_with("op:"):
		_mudar_opcao(id.substr(3), passo)


## A v2 lê esta opção? (só as lidas ganham linha no menu)
func lida_na_v2(chave: String) -> bool:
	return LIDAS_NA_V2.has(chave)


## Liga ou desliga uma opção de sim ou não que fica fora do perfil (tela cheia, a baixa automática, o contador de fps).
func _alternar(chave: String) -> void:
	Config.definir(chave, not bool(Config.v(chave)))


func _sim_nao(chave: String) -> String:
	return "Sim" if bool(Config.v(chave)) else "Não"


func _linha_opcao(op: Dictionary) -> Dictionary:
	var chave := str(op.get("chave", ""))
	return _it("g:op:" + chave, str(op.get("nome", chave)), _texto_valor(op), str(op.get("ajuda", "")))


func _texto_valor(op: Dictionary) -> String:
	var chave := str(op.get("chave", ""))
	var valor = Config.g(chave)
	if str(op.get("tipo", "")) == "slider":
		return _fmt_num(float(valor) if valor != null else float(op.get("min", 0)), float(op.get("passo", 1))) + str(op.get("unidade", ""))
	return _rotulo(op, valor)


func _trocar_perfil(passo: int) -> void:
	var i := PERFIS.find(str(Config.g_perfil()))
	if i < 0:
		i = 0 if passo > 0 else PERFIS.size() - 1  # personalizado: a seta começa de um lado ou do outro (como na v1)
	else:
		i = posmod(i + passo, PERFIS.size())
	Config.g_aplicar_perfil(PERFIS[i])


func _detectar() -> void:
	var r = Config.g_detectar()
	if r is String and PERFIS.has(r):
		Config.g_aplicar_perfil(r)
		mensagem = "Detectado: %s" % NOMES_PERFIL[r]
	else:
		mensagem = "Não deu para detectar"


## Uma opção do json: slider soma o passo (arredondado à grade), menu e sim_nao dão a volta na lista de valores.
func _mudar_opcao(chave: String, passo: int) -> void:
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

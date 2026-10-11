extends Node
# Teste automático: aba Gráficos (#150) contra a API real (Config.g_*). Muda opções de verdade (grava em opcoes.cfg)
# e devolve o perfil e cada opção como estavam no fim.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/tela_graficos.tscn  (imprime "GRAFICOS falhas=0")
const Tela := preload("res://cenas/tela_graficos.tscn")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

## Índice em _foco da opção com esta chave (-1 se não houver).
func _idx(t, chave: String) -> int:
	for k in t._foco.size():
		var f: Dictionary = t._foco[k]
		if str(f.tipo) == "opcao" and str(t._opcao_de(int(f.linha)).chave) == chave:
			return k
	return -1

func _achar(t, tipo: String) -> int:
	for k in t._foco.size():
		if str(t._foco[k].tipo) == tipo:
			return k
	return -1

func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "confirmar", "voltar"]:   # o jogo cria as ações em main.gd (_teclas); aqui, sem o jogo
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
	# estado de antes, para devolver no fim
	var perfil_antes: String = Config.g_perfil()
	var antes := {}
	for op in Config.g_opcoes():
		antes[str(op.chave)] = Config.g(str(op.chave))

	var t = Tela.instantiate()
	var saiu := [false]
	t.fechou.connect(func(): saiu[0] = true)
	add_child(t)

	# montagem: todas as opções da API, duas seções, perfil/detectar antes e voltar no fim
	var opcoes: Array = Config.g_opcoes()
	var n_op := 0
	var n_sec := 0
	for l in t._linhas:
		if str(l.tipo) == "opcao":
			n_op += 1
		elif str(l.tipo) == "secao":
			n_sec += 1
	ok(n_op == opcoes.size(), "monta as %d opções da API (%d)" % [opcoes.size(), n_op])
	ok(n_sec == 2, "duas seções com título (%d)" % n_sec)
	ok(t._foco.size() == opcoes.size() + 3, "foco: perfil, detectar, opções e voltar")
	ok(str(t._foco[0].tipo) == "perfil" and str(t._foco[1].tipo) == "detectar" and str(t._foco[-1].tipo) == "voltar", "ordem do foco")
	ok(t._rolagem_max > 0.0, "a lista rola quando não cabe (max %.0f)" % t._rolagem_max)
	ok(t._perfil == Config.g_perfil(), "o perfil da tela é o da API (%s)" % t._perfil)

	# perfil: escolher preenche tudo e os controles acompanham
	Config.g_aplicar_perfil("baixo")
	t._recarregar()
	t._sel = _achar(t, "perfil")
	t._agir(1)
	ok(Config.g_perfil() == "medio" and t._perfil == "medio", "próximo perfil (medio)")
	ok(is_equal_approx(float(t._valores.get("max_inimigos")), 350.0), "controle atualizado para o médio (max_inimigos 350)")
	t._mudar_perfil(-1)
	ok(t._perfil == "baixo" and is_equal_approx(float(t._valores.get("max_inimigos")), 250.0), "volta para baixo e atualiza")

	# mexer num detalhe vira personalizado
	t._sel = _idx(t, "max_inimigos")
	t._agir(1)
	ok(is_equal_approx(float(Config.g("max_inimigos")), 300.0), "slider: +1 passo (250 -> 300)")
	ok(t._perfil == "personalizado" and Config.g_perfil() == "personalizado", "mexer num detalhe vira Personalizado")
	t._agir(-1)
	ok(is_equal_approx(float(Config.g("max_inimigos")), 250.0), "slider: volta um passo")

	# arrastar: posição vira valor na grade do passo (150..500, passo 50)
	var op_max: Dictionary = t._opcao_de(int(t._foco[_idx(t, "max_inimigos")].linha))
	t._arrastar(op_max, 400.0 + 120.0)
	ok(is_equal_approx(float(Config.g("max_inimigos")), 500.0), "arrastar até o fim da barra dá o máximo")
	t._arrastar(op_max, 400.0 + 120.0 * 0.4)   # 40% da barra: 290 -> arredonda para 300
	ok(is_equal_approx(float(Config.g("max_inimigos")), 300.0), "arrastar cai na grade do passo (300)")

	# slider em %: brilhos_halos (0 a 100, passo 25), e em segundos: restos_chao (3 a 15, passo 1)
	t._sel = _idx(t, "brilhos_halos")
	Config.g_definir("brilhos_halos", 50)
	t._agir(1)
	ok(is_equal_approx(float(Config.g("brilhos_halos")), 75.0), "slider %: anda de 25 em 25 (50 -> 75)")
	ok(t._fmt_num(float(Config.g("brilhos_halos")), 25.0) + "%" == "75%", "slider %: o texto do valor é 75%")
	t._sel = _idx(t, "restos_chao")
	Config.g_definir("restos_chao", 9)
	t._agir(1)
	ok(is_equal_approx(float(Config.g("restos_chao")), 10.0), "slider s: anda de 1 em 1 (9 -> 10)")

	# menu com números: calculo_monstros (0.5, 1, 2) dá a volta
	t._sel = _idx(t, "calculo_monstros")
	Config.g_definir("calculo_monstros", 2.0)
	t._agir(1)
	ok(is_equal_approx(float(Config.g("calculo_monstros")), 0.5), "menu numérico dá a volta (2 -> 0,5)")

	# menu com texto: luz_relevo dá a volta nos dois sentidos
	t._sel = _idx(t, "luz_relevo")
	Config.g_definir("luz_relevo", "desligada")
	t._agir(1)
	ok(str(Config.g("luz_relevo")) == "so_heroi", "menu: próximo valor")
	t._agir(1)
	t._agir(1)
	ok(str(Config.g("luz_relevo")) == "desligada", "menu: dá a volta")
	t._agir(-1)
	ok(str(Config.g("luz_relevo")) == "tudo", "menu: anterior (volta pelo fim)")

	# sim/não: nevoa (sem valores no json, então vale [não, sim])
	t._sel = _idx(t, "nevoa")
	Config.g_definir("nevoa", false)
	t._agir(1)
	ok(bool(Config.g("nevoa")) == true, "sim/não alterna")
	ok(t._rotulo(t._opcao_de(int(t._foco[t._sel].linha)), Config.g("nevoa")) == "Sim", "sim/não mostra Sim")

	# menu com rótulo próprio: escala_render mostra 75%
	var op_esc: Dictionary = t._opcao_de(int(t._foco[_idx(t, "escala_render")].linha))
	ok(t._rotulo(op_esc, 75) == "75%", "menu numérico usa o rótulo do json (75%)")

	# detectar: pede a sugestão da API e aplica
	t._sel = _achar(t, "detectar")
	var sugerido: String = Config.g_detectar()
	t._agir(0, true)
	ok(Config.g_perfil() == sugerido and t._perfil == sugerido, "detectar aplica a sugestão da API (%s)" % sugerido)
	ok(t._msg.begins_with("Detectado"), "detectar avisa")

	# rolagem: a última opção aparece inteira
	var ult: int = t._foco.size() - 2
	t._sel = ult
	t._garantir_visivel()
	var f_ult: Dictionary = t._foco[ult]
	ok(float(f_ult.bot) <= t._rolagem + 234.0 + 0.01 and t._rolagem <= t._rolagem_max + 0.01, "rola até a última opção caber")
	t._sel = 2
	t._garantir_visivel()
	ok(t._rolagem <= float(t._foco[2].top) + 0.01, "volta até a primeira opção")

	# mouse: o que está sob o ponto
	ok(t._item_em(Vector2(200, 62)) == _achar(t, "perfil"), "mouse sobre o seletor de perfil")
	ok(t._item_em(Vector2(480, 62)) == _achar(t, "detectar"), "mouse sobre Detectar")
	ok(t._item_em(Vector2(565, 346)) == _achar(t, "voltar"), "mouse sobre Voltar")
	ok(t._item_em(Vector2(5, 5)) == -1, "mouse fora de tudo")
	# clique direito volta um valor e o esquerdo avança
	t._sel = _idx(t, "luz_relevo")
	Config.g_definir("luz_relevo", "tudo")
	t._clicar(t._sel, MOUSE_BUTTON_RIGHT)
	ok(str(Config.g("luz_relevo")) == "so_heroi", "clique direito volta um valor no menu")
	t._clicar(t._sel, MOUSE_BUTTON_LEFT)
	ok(str(Config.g("luz_relevo")) == "tudo", "clique esquerdo avança um valor no menu")

	# a tela escuta a API: uma mudança feita fora dela chega aos valores pelo sinal graficos_mudou
	Config.g_definir("nevoa", true)
	ok(t._valores.get("nevoa") == true, "mudança de fora chega à tela pelo sinal")

	# Esc (voltar) fecha, avisa quem abriu, se apaga e solta o sinal da API
	var cb: Callable = t._recarregar
	ok(Config.graficos_mudou.is_connected(cb), "a tela escuta graficos_mudou enquanto está aberta")
	t._sel = _achar(t, "voltar")
	t._agir(0, true)
	ok(saiu[0], "Esc/voltar emite fechou")
	await get_tree().process_frame
	ok(not is_instance_valid(t) or t.is_queued_for_deletion(), "a tela se apaga ao fechar")
	ok(not Config.graficos_mudou.is_connected(cb), "a tela solta o sinal graficos_mudou ao sair")

	# devolve o jogador como estava
	if perfil_antes != "personalizado":
		Config.g_aplicar_perfil(perfil_antes)
	else:
		for k in antes:
			Config.g_definir(k, antes[k])
	print("GRAFICOS falhas=", falhas)
	get_tree().quit()

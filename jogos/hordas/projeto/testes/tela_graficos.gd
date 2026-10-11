extends Node
# Teste automático: aba Gráficos (#150) contra o dublê da API (testes/graficos_api_falsa.gd).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/tela_graficos.tscn  (imprime "GRAFICOS falhas=0")
const Falsa := preload("res://testes/graficos_api_falsa.gd")
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
	var api = Falsa.new()
	var t = Tela.instantiate()
	t.api = api
	var saiu := [false]
	t.fechou.connect(func(): saiu[0] = true)
	add_child(t)

	# montagem: todas as opções, duas seções, perfil/detectar antes e voltar no fim
	var opcoes: Array = api.g_opcoes()
	var n_op := 0
	var n_sec := 0
	for l in t._linhas:
		if str(l.tipo) == "opcao":
			n_op += 1
		elif str(l.tipo) == "secao":
			n_sec += 1
	ok(n_op == opcoes.size(), "monta as %d opções (%d)" % [opcoes.size(), n_op])
	ok(n_sec == 2, "duas seções com título (%d)" % n_sec)
	ok(t._foco.size() == opcoes.size() + 3, "foco: perfil, detectar, opções e voltar")
	ok(str(t._foco[0].tipo) == "perfil" and str(t._foco[1].tipo) == "detectar" and str(t._foco[-1].tipo) == "voltar", "ordem do foco")
	ok(t._rolagem_max > 0.0, "a lista rola quando não cabe (max %.0f)" % t._rolagem_max)
	ok(t._perfil == "medio", "começa no perfil que a API diz (medio)")

	# perfil: trocar preenche tudo e atualiza os controles
	t._sel = _achar(t, "perfil")
	t._agir(1)
	ok(api.g_perfil() == "alto" and t._perfil == "alto", "próximo perfil (alto)")
	ok(is_equal_approx(float(t._valores.get("max_vivos")), 500.0), "controle atualizado para o alto (max_vivos 500)")
	ok(str(t._valores.get("luz_relevo")) == "tudo", "menu atualizado para o alto")
	t._mudar_perfil(-2)
	ok(t._perfil == "baixo" and is_equal_approx(float(t._valores.get("max_vivos")), 150.0), "volta para baixo e atualiza")

	# mexer num detalhe vira personalizado
	t._sel = _idx(t, "max_vivos")
	t._agir(1)
	ok(is_equal_approx(float(api.g("max_vivos")), 200.0), "slider: +1 passo (150 -> 200)")
	ok(t._perfil == "personalizado" and api.g_perfil() == "personalizado", "mexer num detalhe vira Personalizado")
	t._agir(-1)
	t._agir(-1)
	ok(is_equal_approx(float(api.g("max_vivos")), 150.0), "slider: não passa do mínimo")

	# arrastar: posição vira valor na grade do passo (150..500, passo 50)
	var op_max: Dictionary = t._opcao_de(int(t._foco[_idx(t, "max_vivos")].linha))
	t._arrastar(op_max, 400.0 + 120.0)  # fim da barra -> máximo
	ok(is_equal_approx(float(api.g("max_vivos")), 500.0), "arrastar até o fim da barra dá o máximo")
	t._arrastar(op_max, 400.0 + 120.0 * 0.4)  # 40% da barra: 290 -> arredonda para 300
	ok(is_equal_approx(float(api.g("max_vivos")), 300.0), "arrastar cai na grade do passo (300)")

	# menu: dá a volta nos valores
	t._sel = _idx(t, "luz_relevo")
	api.g_definir("luz_relevo", "desligada")
	t._agir(1)
	ok(str(api.g("luz_relevo")) == "so_heroi", "menu: próximo valor")
	t._agir(1)
	t._agir(1)
	ok(str(api.g("luz_relevo")) == "desligada", "menu: dá a volta")
	t._agir(-1)
	ok(str(api.g("luz_relevo")) == "tudo", "menu: anterior (volta pelo fim)")

	# sim/não alterna
	t._sel = _idx(t, "sombras")
	var antes: bool = bool(api.g("sombras"))
	t._agir(1)
	ok(bool(api.g("sombras")) != antes, "sim/não alterna")
	ok(t._rotulo(t._opcao_de(int(t._foco[t._sel].linha)), api.g("sombras")) == ("Sim" if not antes else "Não"), "sim/não mostra Sim ou Não")

	# passo fracionário: escala de 0.05
	t._sel = _idx(t, "escala")
	api.g_definir("escala", 0.75)
	t._agir(1)
	ok(is_equal_approx(float(api.g("escala")), 0.8), "escala anda de 0,05 (0,75 -> 0,80)")

	# detectar: pede a sugestão da API e aplica
	t._sel = _achar(t, "detectar")
	t._agir(0, true)
	ok(t._perfil == "medio" and t._msg.begins_with("Detectado"), "detectar aplica a sugestão (medio) e avisa")

	# rolagem: a última opção aparece inteira
	var ult := t._foco.size() - 2
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
	# clique direito no menu volta um valor
	t._sel = _idx(t, "luz_relevo")
	t._clicar(t._sel, MOUSE_BUTTON_RIGHT)
	ok(str(api.g("luz_relevo")) == "so_heroi", "clique direito volta um valor no menu")

	# Esc (volta) fecha e avisa quem abriu; a tela se apaga e solta o sinal da API
	t._sel = _achar(t, "voltar")
	t._agir(0, true)
	ok(saiu[0], "Esc/voltar emite fechou")
	await get_tree().process_frame
	ok(not is_instance_valid(t) or t.is_queued_for_deletion(), "a tela se apaga ao fechar")
	ok(api.graficos_mudou.get_connections().size() == 0, "a tela solta o sinal graficos_mudou ao sair")

	api.free()
	print("GRAFICOS falhas=", falhas)
	get_tree().quit()

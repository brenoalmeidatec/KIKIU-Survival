extends Node
## Opções do jogador (tela Opções, no título e na pausa). Ficam salvas em user://opcoes.cfg e valem na hora.
## Pra ler uma opção em qualquer lugar: Config.v("tremor"). Pra mudar: Config.definir("tremor", 0.5).
## Opção nova = um item em ITENS (+ usar Config.v onde ela faz efeito; se mexer em janela/som, em aplicar()).

const ARQUIVO := "user://opcoes.cfg"
## Onde se salva. Os testes que gravam opcoes trocam por um arquivo proprio (nunca o do jogador).
var arquivo := ARQUIVO
const VOLUMES := [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
## formato: "sim_nao" (false/true), "pct" (0..1 vira 0%..100%) ou rotulos (um texto por valor)
const ITENS := [
	{"chave": "pausar_fora", "grupo": "Jogabilidade", "nome": "Pausar ao sair da janela", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "tremor", "grupo": "Acessibilidade", "nome": "Tremer a tela", "valores": [0.0, 0.5, 1.0], "rotulos": ["Não", "Pouco", "Normal"], "padrao": 1.0},
	{"chave": "camera_frente", "grupo": "Acessibilidade", "nome": "Câmera olha à frente", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "flash_dano", "grupo": "Acessibilidade", "nome": "Flash ao levar dano", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{
		"chave": "mortes",
		"grupo": "Acessibilidade",
		"nome": "Mortes violentas",
		"valores": ["normal", "reduzida"],
		"rotulos": ["Normal", "Reduzida"],
		"padrao": "normal"
	},
	{"chave": "daltonico", "grupo": "Acessibilidade", "nome": "Modo daltônico", "valores": [false, true], "rotulos": ["Não", "Paleta segura"], "padrao": false},
	# Leitura da tela (#125). Nome, grupo e rótulos são chaves de tradução (assets/traducao/textos.csv); o texto passa por tr() ao desenhar.
	# "texto_hud" guarda "normal" (1x), "medio" (1,5x) ou "grande" (2x): "normal" e "grande" já existiam nos arquivos de opções salvos.
	{
		"chave": "texto_hud",
		"grupo": "OPC_GRUPO_LEITURA",
		"nome": "OPC_TEXTO_HUD",
		"valores": ["normal", "medio", "grande"],
		"rotulos": ["OPC_FONTE_1X", "OPC_FONTE_15X", "OPC_FONTE_2X"],
		"padrao": "normal"
	},
	{"chave": "numeros_dano", "grupo": "OPC_GRUPO_LEITURA", "nome": "OPC_NUMEROS_DANO", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "nomes_inimigo", "grupo": "OPC_GRUPO_LEITURA", "nome": "OPC_NOMES_INIMIGO", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	# Controles (#126). "acao" = linha de remapeamento: Enter/clique pede a nova tecla ou botão (Esc cancela); o valor guardado fica em [teclas].
	{"chave": "reticulo", "grupo": "Controles", "nome": "Retículo da mira", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "mira_assistida", "grupo": "Controles", "nome": "Mira assistida (20 graus)", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "mira_mouse", "grupo": "Controles", "nome": "Mirar com o mouse", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "tecla_dash", "grupo": "Controles", "nome": "Esquivar", "valores": [""], "padrao": "", "acao": "dash"},
	{"chave": "tecla_especial", "grupo": "Controles", "nome": "Especial", "valores": [""], "padrao": "", "acao": "especial"},
	{"chave": "tecla_transformar", "grupo": "Controles", "nome": "Transformar", "valores": [""], "padrao": "", "acao": "transformar"},
	{"chave": "tecla_status", "grupo": "Controles", "nome": "Status (inventário)", "valores": [""], "padrao": "", "acao": "status"},
	{"chave": "tela_cheia", "grupo": "Gráfico", "nome": "Tela cheia (F11)", "valores": [false, true], "formato": "sim_nao", "padrao": false},
	# Gráfico: perfil, CPU e GPU ficam em dados/graficos.json (Config.g / g_definir). Aqui só o que é do jogador, fora do perfil.
	{"chave": "qualidade_auto", "grupo": "Gráfico", "nome": "Detalhe dinâmico", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "verificar_versao", "grupo": "Gráfico", "nome": "Avisar versão nova", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "mostrar_fps", "grupo": "Gráfico", "nome": "Mostrar FPS", "valores": [false, true], "formato": "sim_nao", "padrao": false},
	{
		"chave": "tamanho_ui",
		"grupo": "Gráfico",
		"nome": "Tamanho da interface",
		"valores": ["auto", "pequeno", "medio", "grande"],
		"rotulos": ["Automático", "Pequeno", "Médio", "Grande"],
		"padrao": "auto"
	},
	{"chave": "musica", "grupo": "Som", "nome": "Música", "valores": VOLUMES, "formato": "pct", "padrao": 0.6},
	{"chave": "efeitos", "grupo": "Som", "nome": "Efeitos", "valores": VOLUMES, "formato": "pct", "padrao": 0.8},
	{
		"chave": "voz",
		"grupo": "Som",
		"nome": "Voz no online",
		"valores": ["desligada", "apertar", "aberta"],
		"rotulos": ["Desligada", "Segurar V", "Sempre aberta"],
		"padrao": "apertar"
	},
	{"chave": "voz_volume", "grupo": "Som", "nome": "Volume das vozes", "valores": VOLUMES, "formato": "pct", "padrao": 1.0},
]

var _cfg := ConfigFile.new()

## ---------- aba Gráficos (#150): perfis e opções de CPU e GPU ----------
## Valores e perfis: dados/graficos.json. Salvos na seção [graficos] de opcoes.cfg: "perfil" (baixo, medio, alto ou
## personalizado), "base" (o último perfil aplicado: preenche o que o jogador não mexeu) e uma chave por opção.

signal graficos_mudou
signal tamanho_ui_mudou  # a opção "tamanho_ui" (v2/escala_ui.gd) mudou: as telas abertas refazem o layout na hora

var _perfil_padrao := "alto"  # sem nada salvo: o perfil pela máquina (jogo de verdade) ou alto (testes e headless)
var _temp: Dictionary = {}  # valores só da memória (baixa automática, g_temporario): ficam por cima do salvo e nunca vão ao arquivo
var _temp_perfil := ""  # perfil só da memória ("" = nenhum); some ao mexer numa opção da aba ou ao recarregar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A fixture precisa apontar opcoes.cfg antes de qualquer leitura/migração do autoload (#387).
	# Só carrega código de teste quando a CLI (ou o robô filho) identifica uma cena v2_.
	var cena_teste := OS.get_environment("KIKIU_TESTE_V2_CENA")
	for argumento in OS.get_cmdline_args():
		var nome := str(argumento).replace("\\", "/").get_file()
		if nome.begins_with("v2_") and nome.ends_with(".tscn"):
			cena_teste = nome.get_basename()
			break
	if (
		not Engine.is_editor_hint()
		and cena_teste.begins_with("v2_")
		and cena_teste.is_valid_identifier()
		and ResourceLoader.exists("res://testes/ambiente_v2.gd")
	):
		var ambiente_teste = load("res://testes/ambiente_v2.gd")
		ambiente_teste.preparar_config(self)
	recarregar()
	# com opções de teste (--bot, --online, --print_tela...) só o som vale: os testes rodam em janela e sem limite de FPS
	aplicar(OS.get_cmdline_user_args().is_empty())
	_montar_proporcao()


## ---------- janela sempre 16:9 ----------
## O jogo é 16:9 e o Godot mantém a proporção por dentro, com barras pretas. Ao soltar a borda da janela (PAUSA_PROPORCAO s
## sem mudar de tamanho), corrige o tamanho para 16:9 pelo lado que o jogador mexeu mais. Tela cheia e maximizada não mudam.
const PROPORCAO := 16.0 / 9.0
const PAUSA_PROPORCAO := 0.25
var _prop_timer: Timer
var _prop_ultimo := Vector2i.ZERO  # o último tamanho 16:9 que a janela teve


func _montar_proporcao() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_prop_timer = Timer.new()
	_prop_timer.one_shot = true
	_prop_timer.wait_time = PAUSA_PROPORCAO
	_prop_timer.timeout.connect(_corrigir_proporcao)
	add_child(_prop_timer)
	_prop_ultimo = get_window().size
	get_window().size_changed.connect(func(): _prop_timer.start())


func _corrigir_proporcao() -> void:
	var w := get_window()
	if w.mode != Window.MODE_WINDOWED:
		return
	var t := w.size
	var dx := absf(t.x - _prop_ultimo.x)
	var dy := absf(t.y - _prop_ultimo.y) * PROPORCAO  # na mesma escala da largura
	var novo := Vector2i(t.x, roundi(t.x / PROPORCAO)) if dx >= dy else Vector2i(roundi(t.y * PROPORCAO), t.y)
	var util := DisplayServer.screen_get_usable_rect(w.current_screen).size - Vector2i(16, 48)  # borda e barra de título
	if novo.x > util.x or novo.y > util.y:  # nunca maior que a tela
		var k := minf(util.x / float(novo.x), util.y / float(novo.y))
		novo = Vector2i(roundi(novo.x * k), roundi(novo.x * k / PROPORCAO))
	_prop_ultimo = novo
	if absi(novo.x - t.x) > 2 or absi(novo.y - t.y) > 2:
		w.size = novo


## Lê user://opcoes.cfg de novo (ao abrir o jogo e nos testes de salvar e carregar). Faz a migração da qualidade antiga.
func recarregar() -> void:
	_zerar_temporario()  # o arquivo manda: o que era só da memória (baixa automática, testes) sai
	_cfg = ConfigFile.new()  # load() não limpa o que já estava na memória: começa de um ConfigFile vazio
	_cfg.load(arquivo)
	# migração, uma vez: a "Qualidade gráfica" antiga (alta, media, baixa) vira o perfil novo
	if not _cfg.has_section("graficos") and _cfg.has_section_key("opcoes", "qualidade"):
		var base: String = {"alta": "alto", "media": "medio", "baixa": "baixo"}.get(str(_cfg.get_value("opcoes", "qualidade")), "alto")
		_cfg.set_value("graficos", "perfil", base)
		_cfg.set_value("graficos", "base", base)
		_cfg.erase_section_key("opcoes", "qualidade")
		_cfg.save(arquivo)
	# migração, uma vez: "sombras" tinha contato e projetadas (#150); contato vira baixa e projetadas, média (a silhueta de hoje)
	var sombra_antiga := {"contato": "baixa", "projetadas": "media"}
	var sombra := str(_cfg.get_value("graficos", "sombras", ""))
	if sombra_antiga.has(sombra):
		_cfg.set_value("graficos", "sombras", sombra_antiga[sombra])
		_cfg.save(arquivo)
	# migração, uma vez: com o Detalhe dinâmico ligado não há Personalizado (os detalhes ficam travados no Perfil). Um save com as duas
	# coisas (o jogador montou à mão, v1 ou antes do dinâmico existir) abre com o dinâmico desligado: o que ele montou fica como está
	if str(_cfg.get_value("graficos", "perfil", "")) == "personalizado" and bool(v("qualidade_auto")):
		_cfg.set_value("opcoes", "qualidade_auto", false)
		_cfg.save(arquivo)
	# 1ª vez no jogo de verdade: a máquina fraca já começa em médio ou baixo (só em memória até o jogador mexer)
	if OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name() != "headless":
		_perfil_padrao = g_detectar()


## Valor atual de uma opção de graficos.json: o que o jogador salvou ou, se não mexeu, o do perfil base.
func g(chave: String) -> Variant:
	if _temp.has(chave):
		return _temp[chave]
	if _cfg.has_section_key("graficos", chave):
		return _cfg.get_value("graficos", chave)
	var perfis: Dictionary = Dados.json("graficos").get("perfis", {})
	var base := str(_cfg.get_value("graficos", "base", _perfil_padrao))
	return perfis.get(base, perfis.get("alto", {})).get(chave)


## Nome do perfil atual: "baixo", "medio", "alto" ou "personalizado". Com o Detalhe dinâmico (qualidade_auto) pode estar um degrau
## abaixo do escolhido, só na memória.
func g_perfil() -> String:
	if _temp_perfil != "":
		return _temp_perfil
	return g_perfil_escolhido()


## O perfil que o jogador escolheu (o que está salvo), sem a queda só da memória do Detalhe dinâmico: é o teto da subida.
func g_perfil_escolhido() -> String:
	return str(_cfg.get_value("graficos", "perfil", _perfil_padrao))


## Desfaz a queda só da memória (Detalhe dinâmico): volta ao perfil escolhido. Sem queda, não faz nada.
func g_soltar_temporario() -> void:
	if _temp_perfil == "":
		return
	_zerar_temporario()
	aplicar_graficos()
	graficos_mudou.emit()


## Muda uma opção da aba: o perfil vira "personalizado". Salva e aplica na hora.
func g_definir(chave: String, valor: Variant) -> void:
	if g_opcao(chave).is_empty():
		push_error("Opção de gráficos desconhecida: " + chave)
		return
	_zerar_temporario()  # o jogador escolheu: a baixa automática sai e vale o salvo, mais esta mudança
	_cfg.set_value("graficos", chave, valor)
	_cfg.set_value("graficos", "perfil", "personalizado")
	_salvar_graficos()


## Preenche TODAS as opções com o perfil ("baixo", "medio" ou "alto"). Salva e aplica na hora.
func g_aplicar_perfil(nome: String) -> void:
	_zerar_temporario()
	_preencher(nome)
	_cfg.set_value("graficos", "perfil", nome)
	_cfg.set_value("graficos", "base", nome)
	_salvar_graficos()


## Como g_aplicar_perfil, mas só na memória (testes, --perfil=, a baixa automática de fps): não grava nas opções, nem quando
## outra opção for salva depois (o temporário fica fora de _cfg). Vale por cima do salvo até o jogador mexer numa opção da aba
## ou recarregar. Aplica vsync e limite de fps e avisa a tela (graficos_mudou).
func g_perfil_temporario(nome: String) -> void:
	var perfis: Dictionary = Dados.json("graficos").get("perfis", {})
	if not perfis.has(nome):
		push_error("Perfil de gráficos desconhecido: " + nome)
		return
	_temp = perfis[nome].duplicate()
	_temp_perfil = nome
	aplicar_graficos()
	graficos_mudou.emit()


func _zerar_temporario() -> void:
	_temp = {}
	_temp_perfil = ""


func _preencher(nome: String) -> void:
	var perfis: Dictionary = Dados.json("graficos").get("perfis", {})
	if not perfis.has(nome):
		push_error("Perfil de gráficos desconhecido: " + nome)
		return
	for k in perfis[nome]:
		_cfg.set_value("graficos", k, perfis[nome][k])


func _salvar_graficos() -> void:
	_cfg.save(arquivo)
	aplicar_graficos()
	graficos_mudou.emit()


## Perfil pela máquina (reaproveita a lógica da qualidade automática de #140): até 4 processadores lógicos e vídeo
## integrado da Intel (HD/UHD, sem Iris/Arc) = baixo; só um dos dois = médio; o resto = alto.
func g_detectar() -> String:
	var placa := RenderingServer.get_video_adapter_name().to_lower()
	var integrada := placa.contains("intel") and not placa.contains("iris") and not placa.contains("arc")
	var poucos := OS.get_processor_count() <= 4
	if integrada and poucos:
		return "baixo"
	return "medio" if integrada or poucos else "alto"


## Todas as opções da aba (a tela monta os controles a partir disto). Cada uma tem chave, secao, nome, tipo, ajuda, peso.
func g_opcoes() -> Array:
	return Dados.json("graficos").get("opcoes", [])


func g_opcao(chave: String) -> Dictionary:
	for o in g_opcoes():
		if o.chave == chave:
			return o
	return {}


## Partículas por efeito e nível da opção "particulas_sim" (a ÚNICA opção de partículas): os valores antigos de
## dados/qualidade.json (muitas = 1). Nenhuma = tudo zero (inclusive o ambiente e os elementos).
const PART_NIVEL := {
	"nenhuma":
	{
		"amb_particulas": 0.0,
		"efe_faiscas": 0.0,
		"efe_impactos": 0.0,
		"efe_particulas": 0.0,
		"mortes_part": 0.0,
		"mortes_grandes": 0.0,
		"mortes_simples": 0.0,
		"elem_part": 0.0
	},
	"poucas":
	{
		"amb_particulas": 0.25,
		"efe_faiscas": 0.3,
		"efe_impactos": 0.34,
		"efe_particulas": 0.3,
		"mortes_part": 0.25,
		"mortes_grandes": 0.25,
		"mortes_simples": 0.4,
		"elem_part": 0.25
	},
	"medias":
	{
		"amb_particulas": 0.5,
		"efe_faiscas": 0.6,
		"efe_impactos": 0.67,
		"efe_particulas": 0.6,
		"mortes_part": 0.5,
		"mortes_grandes": 0.5,
		"mortes_simples": 0.6,
		"elem_part": 0.5
	},
}


## Fração de um efeito de partícula (efe_faiscas, mortes_part, elem_part...) pelo nível de "particulas_sim".
func fator_particulas(efeito: String) -> float:
	return float(PART_NIVEL.get(str(g("particulas_sim")), {}).get(efeito, 1.0))


## Halos de luz (efeitos.gd) pela opção "Brilhos e halos": 0 a 1.
func fator_brilho() -> float:
	return float(g("brilhos_halos")) / 100.0


## Leituras de tela do halo da fase de horror e luzes que o shader considera (escuridao.gd): faixas da opção de brilho.
## Com 100% = 8 e 16 (alto), 50% = 4 e 12 (médio), 25% = 0 e 8 (baixo, sem leitura de tela).
func leituras_horror() -> int:
	return 8 if fator_brilho() >= 0.75 else (4 if fator_brilho() >= 0.4 else 0)


func luzes_horror() -> int:
	return 16 if fator_brilho() >= 0.75 else (12 if fator_brilho() >= 0.4 else 8)


## Opção "Tamanho da fonte do HUD": 1.0, 1.5 ou 2.0. O Theme do HUD e os textos pequenos das outras telas multiplicam por isto.
func fator_fonte() -> float:
	match str(v("texto_hud")):
		"grande":
			return 2.0
		"medio":
			return 1.5
	return 1.0


func item(chave: String) -> Dictionary:
	for it in ITENS:
		if it.chave == chave:
			return it
	return {}


func v(chave: String) -> Variant:
	return _cfg.get_value("opcoes", chave, item(chave).get("padrao"))


## Só na memória (não grava no arquivo): usado pelos prints de teste (--grande, --daltonico) pra não mexer nas opções do jogador.
func temporario(chave: String, valor: Variant) -> void:
	_cfg.set_value("opcoes", chave, valor)


## Como temporario, mas para uma opção da aba Gráficos (dados/graficos.json). Só na memória, sem mudar o perfil: vai para _temp.
func g_temporario(chave: String, valor: Variant) -> void:
	_temp[chave] = valor


func definir(chave: String, valor: Variant) -> void:
	_cfg.set_value("opcoes", chave, valor)
	_cfg.save(arquivo)
	aplicar()
	if chave == "tamanho_ui":
		tamanho_ui_mudou.emit()


## Texto do valor atual (o que aparece na tela de Opções).
func rotulo(chave: String) -> String:
	var it := item(chave)
	if it.has("acao"):
		return texto_acao(str(it.acao))
	var val = v(chave)
	match str(it.get("formato", "")):
		"sim_nao":
			return "Sim" if val else "Não"
		"pct":
			return "%d%%" % roundi(float(val) * 100.0)
	var i: int = it.valores.find(val)
	return tr(str(it.rotulos[i])) if i >= 0 else str(val)


## ---------- remapeamento de teclas e botões (#126) ----------


## Nome curto da tecla/botão que a ação usa agora: "Espaço / Botão 1". Só conta a 1ª tecla e o 1º botão do controle.
func texto_acao(acao: String) -> String:
	if not InputMap.has_action(acao):
		return "-"
	var tecla := ""
	var botao := ""
	for e in InputMap.action_get_events(acao):
		if e is InputEventKey and tecla == "":
			tecla = OS.get_keycode_string(e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode)
		elif e is InputEventJoypadButton and botao == "":
			botao = "Botão %d" % e.button_index
	return " / ".join([tecla, botao].filter(func(s): return s != "")) if (tecla + botao) != "" else "-"


## Troca a tecla (InputEventKey) ou o botão do controle (InputEventJoypadButton) da ação e grava. Devolve false se o evento não serve.
func remapear(acao: String, ev: InputEvent) -> bool:
	if not (ev is InputEventKey or ev is InputEventJoypadButton) or not InputMap.has_action(acao):
		return false
	if ev is InputEventKey:
		var k: int = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
		if k == KEY_ESCAPE or k == KEY_NONE:
			return false
		_cfg.set_value("teclas", acao + "_teclado", k)
	else:
		_cfg.set_value("teclas", acao + "_controle", ev.button_index)
	_cfg.save(arquivo)
	aplicar_teclas()
	return true


## Põe no InputMap o que o jogador trocou: troca TODAS as teclas (ou todos os botões) da ação pela escolhida.
func aplicar_teclas() -> void:
	for it in ITENS:
		if not it.has("acao"):
			continue
		var acao: String = it.acao
		if not InputMap.has_action(acao):
			continue
		if _cfg.has_section_key("teclas", acao + "_teclado"):
			for e in InputMap.action_get_events(acao):
				if e is InputEventKey:
					InputMap.action_erase_event(acao, e)
			var ek := InputEventKey.new()
			ek.physical_keycode = int(_cfg.get_value("teclas", acao + "_teclado")) as Key
			InputMap.action_add_event(acao, ek)
		if _cfg.has_section_key("teclas", acao + "_controle"):
			for e in InputMap.action_get_events(acao):
				if e is InputEventJoypadButton:
					InputMap.action_erase_event(acao, e)
			var ej := InputEventJoypadButton.new()
			ej.button_index = int(_cfg.get_value("teclas", acao + "_controle")) as JoyButton
			InputMap.action_add_event(acao, ej)


## Passa pro próximo (passo 1) ou anterior (passo -1) valor da lista, dando a volta.
func girar(chave: String, passo: int) -> void:
	var vals: Array = item(chave).valores
	var i := maxi(0, vals.find(v(chave)))
	definir(chave, vals[(i + passo + vals.size()) % vals.size()])


func aplicar(janela := true) -> void:
	Som.volume_musica = float(v("musica"))
	Som.volume_efeitos = float(v("efeitos"))
	Som.atualizar_volume()
	if DisplayServer.get_name() == "headless":
		return
	if "--sem_limite" in OS.get_cmdline_user_args():  # medição de desempenho: sem V-Sync e sem teto de fps (não grava na opção)
		# antes ficava no fim, DEPOIS do "return" dos testes: como a medição sempre roda com argumentos, nunca valia
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		return
	if not janela:
		return
	# a escala é fracionária (project.godot): janela maximizada, 1918x1078 ou qualquer tamanho preenche sem barras.
	# Só mexe no modo ao entrar/sair da tela cheia: janela maximizada não pode ser "corrigida" de volta pra normal.
	var cheia := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if v("tela_cheia") and not cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif not v("tela_cheia") and cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	aplicar_graficos()


## Efeitos da aba Gráficos que moram na janela: V-Sync e limite de fps. Não mexe no modo de tela.
## escala_render ainda NÃO muda o render: content_scale_factor do viewport raiz muda a área visível (zoom), não a resolução.
## Falta um SubViewport com a cena do jogo (fase seguinte). A opção é salva e aparece na aba, mas não age.
func aplicar_graficos() -> void:
	if DisplayServer.get_name() == "headless" or "--sem_limite" in OS.get_cmdline_user_args():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if g("vsync") else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(g("limite_fps"))

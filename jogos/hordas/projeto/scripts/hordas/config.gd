extends Node
## Opções do jogador (tela Opções, no título e na pausa). Ficam salvas em user://opcoes.cfg e valem na hora.
## Pra ler uma opção em qualquer lugar: Config.v("tremor"). Pra mudar: Config.definir("tremor", 0.5).
## Opção nova = um item em ITENS (+ usar Config.v onde ela faz efeito; se mexer em janela/som, em aplicar()).

const ARQUIVO := "user://opcoes.cfg"
const VOLUMES := [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
## formato: "sim_nao" (false/true), "pct" (0..1 vira 0%..100%) ou rotulos (um texto por valor)
const ITENS := [
	{"chave": "pausar_fora", "grupo": "Jogabilidade", "nome": "Pausar ao sair da janela", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "tremor", "grupo": "Acessibilidade", "nome": "Tremer a tela", "valores": [0.0, 0.5, 1.0], "rotulos": ["Não", "Pouco", "Normal"], "padrao": 1.0},
	{"chave": "flash_dano", "grupo": "Acessibilidade", "nome": "Flash ao levar dano", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "mortes", "grupo": "Acessibilidade", "nome": "Mortes violentas", "valores": ["normal", "reduzida"], "rotulos": ["Normal", "Reduzida"], "padrao": "normal"},
	{"chave": "numeros_dano", "grupo": "Acessibilidade", "nome": "Números de dano", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "texto_hud", "grupo": "Acessibilidade", "nome": "Texto do HUD", "valores": ["normal", "grande"], "rotulos": ["Normal", "Grande"], "padrao": "normal"},
	{"chave": "daltonico", "grupo": "Acessibilidade", "nome": "Modo daltônico", "valores": [false, true], "rotulos": ["Não", "Paleta segura"], "padrao": false},
	{"chave": "tela_cheia", "grupo": "Gráfico", "nome": "Tela cheia (F11)", "valores": [false, true], "formato": "sim_nao", "padrao": false},
	{"chave": "vsync", "grupo": "Gráfico", "nome": "V-Sync", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "fps_max", "grupo": "Gráfico", "nome": "Limite de FPS", "valores": [30, 60, 120, 144, 0], "rotulos": ["30", "60", "120", "144", "Sem limite"], "padrao": 0},
	{"chave": "mostrar_fps", "grupo": "Gráfico", "nome": "Mostrar FPS", "valores": [false, true], "formato": "sim_nao", "padrao": false},
	{"chave": "musica", "grupo": "Som", "nome": "Música", "valores": VOLUMES, "formato": "pct", "padrao": 0.6},
	{"chave": "efeitos", "grupo": "Som", "nome": "Efeitos", "valores": VOLUMES, "formato": "pct", "padrao": 0.8},
]

var _cfg := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg.load(ARQUIVO)
	# com opções de teste (--bot, --online, --print_tela...) só o som vale: os testes rodam em janela e sem limite de FPS
	aplicar(OS.get_cmdline_user_args().is_empty())


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


func definir(chave: String, valor: Variant) -> void:
	_cfg.set_value("opcoes", chave, valor)
	_cfg.save(ARQUIVO)
	aplicar()


## Texto do valor atual (o que aparece na tela de Opções).
func rotulo(chave: String) -> String:
	var it := item(chave)
	var val = v(chave)
	match str(it.get("formato", "")):
		"sim_nao":
			return "Sim" if val else "Não"
		"pct":
			return "%d%%" % roundi(float(val) * 100.0)
	var i: int = it.valores.find(val)
	return str(it.rotulos[i]) if i >= 0 else str(val)


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
	if "--sem_limite" in OS.get_cmdline_user_args():   # medição de desempenho: sem V-Sync e sem teto de fps (não grava na opção)
		# antes ficava no fim, DEPOIS do "return" dos testes: como a medição sempre roda com argumentos, nunca valia
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		return
	if not janela:
		return
	# tela cheia EXCLUSIVA: a "normal" do Windows deixa a janela 1px menor que o monitor (1918x1078),
	# a escala inteira cai de 3x pra 2x e o jogo fica pequeno no meio com barras pretas
	var modo := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if v("tela_cheia") else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != modo:
		DisplayServer.window_set_mode(modo)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v("vsync") else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(v("fps_max"))

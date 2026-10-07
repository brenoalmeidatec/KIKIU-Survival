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
	{"chave": "camera_frente", "grupo": "Acessibilidade", "nome": "Câmera olha à frente", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "flash_dano", "grupo": "Acessibilidade", "nome": "Flash ao levar dano", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "mortes", "grupo": "Acessibilidade", "nome": "Mortes violentas", "valores": ["normal", "reduzida"], "rotulos": ["Normal", "Reduzida"], "padrao": "normal"},
	{"chave": "numeros_dano", "grupo": "Acessibilidade", "nome": "Números de dano", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "texto_hud", "grupo": "Acessibilidade", "nome": "Texto do HUD", "valores": ["normal", "grande"], "rotulos": ["Normal", "Grande"], "padrao": "normal"},
	{"chave": "daltonico", "grupo": "Acessibilidade", "nome": "Modo daltônico", "valores": [false, true], "rotulos": ["Não", "Paleta segura"], "padrao": false},
	{"chave": "tela_cheia", "grupo": "Gráfico", "nome": "Tela cheia (F11)", "valores": [false, true], "formato": "sim_nao", "padrao": false},
	{"chave": "qualidade", "grupo": "Gráfico", "nome": "Qualidade gráfica", "valores": ["alta", "media", "baixa"], "rotulos": ["Alta", "Média", "Baixa"], "padrao": "alta"},
	{"chave": "vinheta", "grupo": "Gráfico", "nome": "Vinheta (bordas escuras)", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "vsync", "grupo": "Gráfico", "nome": "V-Sync", "valores": [false, true], "formato": "sim_nao", "padrao": true},
	{"chave": "fps_max", "grupo": "Gráfico", "nome": "Limite de FPS", "valores": [30, 60, 120, 144, 0], "rotulos": ["30", "60", "120", "144", "Sem limite"], "padrao": 0},
	{"chave": "mostrar_fps", "grupo": "Gráfico", "nome": "Mostrar FPS", "valores": [false, true], "formato": "sim_nao", "padrao": false},
	{"chave": "musica", "grupo": "Som", "nome": "Música", "valores": VOLUMES, "formato": "pct", "padrao": 0.6},
	{"chave": "efeitos", "grupo": "Som", "nome": "Efeitos", "valores": VOLUMES, "formato": "pct", "padrao": 0.8},
	{"chave": "voz", "grupo": "Som", "nome": "Voz no online", "valores": ["desligada", "apertar", "aberta"], "rotulos": ["Desligada", "Segurar V", "Sempre aberta"], "padrao": "apertar"},
	{"chave": "voz_volume", "grupo": "Som", "nome": "Volume das vozes", "valores": VOLUMES, "formato": "pct", "padrao": 1.0},
]

var _cfg := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg.load(ARQUIVO)
	if OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name() != "headless" and not _cfg.has_section_key("opcoes", "qualidade"):
		_cfg.set_value("opcoes", "qualidade", qualidade_sugerida())   # 1ª vez: máquina fraca já começa em Média ou Baixa (só em memória até o jogador mexer em alguma opção)
	# com opções de teste (--bot, --online, --print_tela...) só o som vale: os testes rodam em janela e sem limite de FPS
	aplicar(OS.get_cmdline_user_args().is_empty())


var _perfil_nome := ""
var _perfil := {}


## Valor de uma chave do perfil de qualidade escolhido (dados/qualidade.json). Chave que o perfil não tem vale o de "alta".
func q(chave: String) -> Variant:
	var nome := str(v("qualidade"))
	if nome != _perfil_nome:
		_perfil_nome = nome
		var ps: Dictionary = Dados.json("qualidade").get("perfis", {})
		_perfil = ps.get(nome, ps.get("alta", {}))
	return _perfil.get(chave, Dados.json("qualidade").get("perfis", {}).get("alta", {}).get(chave))


## Perfil de partida pela máquina: até 4 processadores lógicos e vídeo integrado da Intel (HD/UHD, sem Iris/Arc) = baixa;
## só um dos dois = média; o resto = alta. O jogador muda em Opções > Gráfico.
static func qualidade_sugerida() -> String:
	var placa := RenderingServer.get_video_adapter_name().to_lower()
	var integrada := placa.contains("intel") and not placa.contains("iris") and not placa.contains("arc")
	var poucos := OS.get_processor_count() <= 4
	if integrada and poucos:
		return "baixa"
	return "media" if integrada or poucos else "alta"


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
	# a escala é fracionária (project.godot): janela maximizada, 1918x1078 ou qualquer tamanho preenche sem barras.
	# Só mexe no modo ao entrar/sair da tela cheia: janela maximizada não pode ser "corrigida" de volta pra normal.
	var cheia := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if v("tela_cheia") and not cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif not v("tela_cheia") and cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v("vsync") else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(v("fps_max"))

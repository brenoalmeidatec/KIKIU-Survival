extends RefCounted
## Tamanho da interface da v2, no estilo "GUI Scale" do Minecraft: um fator único (px de janela por px de UI) lido por todas as telas.
## Todo o layout da UI foi desenhado num "bloco" de 960x540. O fator diz quantos pixels de janela vale cada pixel da UI; a UI ganha
## então um canvas de janela / fator (maior que o bloco quando o fator é menor que o de encaixe), o bloco fica no centro dele e o que
## é de borda (HUD, minimapa, fundos) ancora no canvas, não no bloco. Assim a UI não vira gigante numa janela grande nem é cortada numa pequena.
## Cada opção é um canvas-alvo (quanto de UI a pessoa quer ver); o fator é o maior passo (nunca menos que 1) que ainda deixa o canvas com pelo menos
## esse tamanho, limitado ao encaixe do bloco (min(w/960, h/540)), de modo que nada é cortado.
##   Pequeno 1600x900 e Médio 1280x720 (passos de 0,5), Grande 960x540 (o bloco ocupa a janela, passos de 0,5).
##   Automático: canvas-alvo 1440x810 em passos de 0,25, entre o Pequeno e o Médio. O Alisson achou a UI antiga (o bloco encaixado na janela)
##   grande demais; com este alvo, em 1920x1080 o fator é 1,25 e as cartas ocupam cerca de metade da largura em vez de 85%
##   (1280x720 = 1; 2560x1440 = 1,75; 3840x2160 = 2,5). Quem quiser maior escolhe Médio ou Grande.
##   O Automático também lê a escala de tela do sistema (Windows 125%, 150%, 175%...): o fator bruto é multiplicado por ela, porque o jogo
##   desenha em px físicos e, sem isso, a UI fica minúscula num notebook 1080p a 150% (pedido do Alisson). 1920x1080 a 125% = 1,5; a 150% = 2.
##   Continua limitado ao encaixe do bloco. Os tamanhos fixos (Pequeno, Médio, Grande) ignoram o DPI: são escolha da pessoa.
## Tudo aqui é conta pura sobre o tamanho da janela (os testes passam o tamanho), e fica um estado estático com o último resultado,
## que as telas leem sem precisar de referência ao mundo.

const LARG := 960.0
const ALT := 540.0
const BLOCO := Vector2(LARG, ALT)
const OPCOES := ["auto", "pequeno", "medio", "grande"]
const ROTULOS := ["Automático", "Pequeno", "Médio", "Grande"]
const ALVOS := {"auto": Vector2(1440, 810), "medio": Vector2(1280, 720), "pequeno": Vector2(1600, 900), "grande": Vector2(960, 540)}
const CHAVE := "tamanho_ui"

## Para os testes e as fotos: tamanho de janela forçado (zero = o da janela de verdade; em headless, o próprio bloco 960x540).
static var janela_forcada := Vector2i.ZERO
## Para os testes e as fotos: escala de tela do sistema forçada (1,5 = 150%; zero = a do sistema; em headless, 1).
static var dpi_forcado := 0.0
## O último resultado, escrito pela apresentação e pelas telas de menu: fator, canvas e deslocamento do bloco no canvas.
static var fator_atual := 1.0
static var canvas_atual := BLOCO
static var desloc_atual := Vector2.ZERO


## O fator para uma janela (em px), uma opção ("auto", "pequeno", "medio" ou "grande") e a escala de tela do sistema (só o Automático usa).
static func fator(janela: Vector2, opcao: String, dpi := 1.0) -> float:
	var j := Vector2(maxf(janela.x, 1.0), maxf(janela.y, 1.0))
	var encaixe := minf(j.x / LARG, j.y / ALT)
	var alvo: Vector2 = ALVOS.get(opcao, ALVOS.auto)
	var bruto := minf(j.x / alvo.x, j.y / alvo.y)
	if opcao == "auto":
		bruto *= clampf(dpi, 1.0, 4.0)
	var gran := 4.0 if opcao == "auto" else 2.0  # o Automático afina em passos de 0,25; os fixos andam de 0,5
	var passo := maxf(floorf(bruto * gran + 0.0001) / gran, 1.0)
	return minf(passo, encaixe)


## O canvas da UI em px de UI (janela / fator, arredondado para cima: cobre a janela inteira).
static func canvas(janela: Vector2, opcao: String, dpi := 1.0) -> Vector2:
	var f := fator(janela, opcao, dpi)
	return Vector2(ceilf(janela.x / f - 0.001), ceilf(janela.y / f - 0.001))


## Onde o bloco 960x540 fica no canvas (centralizado, em px inteiros de UI).
static func deslocamento(cv: Vector2) -> Vector2:
	return ((cv - BLOCO) / 2.0).floor()


## O retângulo do canvas em coordenadas do bloco (começa em -deslocamento): o que cobre a tela toda.
static func cobertura(cv: Vector2, desloc: Vector2) -> Rect2:
	return Rect2(-desloc, cv)


## Faz um Control (fundo, escurecedor, vinheta) cobrir o canvas inteiro, e o põe no grupo "ui_cobrir": a apresentação o recobre sempre que a
## janela ou a opção mudam. Vale em qualquer CanvasLayer cujo offset seja o deslocamento do bloco (é como as telas da v2 são montadas).
static func cobrir(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var r := cobertura(canvas_atual, desloc_atual)
	c.position = r.position
	c.size = r.size
	if not c.is_in_group("ui_cobrir"):
		c.add_to_group("ui_cobrir")


## A opção salva (cai em "auto" se vier lixo).
static func opcao_atual() -> String:
	var o := str(Config.v(CHAVE))
	return o if OPCOES.has(o) else "auto"


## O tamanho da janela em px. Em headless (testes) é o bloco, para a conta dar fator 1 e canvas 960x540; janela_forcada vale sempre.
static func janela_px(w: Window) -> Vector2:
	if janela_forcada != Vector2i.ZERO:
		return Vector2(janela_forcada)
	if w == null or DisplayServer.get_name() == "headless":
		return BLOCO
	return Vector2(w.size)


## A escala de tela do sistema da janela (1 = 100%). No Windows o Godot não preenche screen_get_scale (fica 1), então vale o DPI efetivo
## do monitor (que já traz a escala do Windows: 144 = 150%) sobre 96. No Linux/X11 o DPI é o físico do monitor, não a escala, então lá
## só vale screen_get_scale (Wayland e macOS). Arredonda para 0,25 (125%, 150%, 175%) e fica entre 1 e 4. Headless: 1.
static func escala_dpi(w: Window) -> float:
	if dpi_forcado > 0.0:
		return dpi_forcado
	if DisplayServer.get_name() == "headless":
		return 1.0
	var tela := w.current_screen if w != null else DisplayServer.window_get_current_screen()
	var e := DisplayServer.screen_get_scale(tela)
	if OS.get_name() == "Windows":
		e = maxf(e, DisplayServer.screen_get_dpi(tela) / 96.0)
	return clampf(roundf(e * 4.0) / 4.0, 1.0, 4.0)


## Calcula para a janela e a opção atuais (ou a `opcao_forcada`, que o salão usa para ficar sempre encaixado), guarda no estado estático e devolve o fator.
static func atualizar(w: Window, opcao_forcada := "") -> float:
	var j := janela_px(w)
	var o := opcao_forcada if OPCOES.has(opcao_forcada) else opcao_atual()
	var d := escala_dpi(w)
	fator_atual = fator(j, o, d)
	canvas_atual = canvas(j, o, d)
	desloc_atual = deslocamento(canvas_atual)
	return fator_atual


## Rótulo da opção para as telas de ajuste.
static func rotulo(opcao: String) -> String:
	var i := OPCOES.find(opcao)
	return ROTULOS[i] if i >= 0 else ROTULOS[0]

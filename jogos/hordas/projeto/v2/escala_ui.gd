extends RefCounted
## Tamanho da interface da v2, no estilo "GUI Scale" do Minecraft: um fator único (px de janela por px de UI) lido por todas as telas.
## Todo o layout da UI foi desenhado num "bloco" de 960x540. O fator diz quantos pixels de janela vale cada pixel da UI; a UI ganha
## então um canvas de janela / fator (maior que o bloco quando o fator é menor que o de encaixe), o bloco fica no centro dele e o que
## é de borda (HUD, minimapa, fundos) ancora no canvas, não no bloco. Assim a UI não vira gigante numa janela grande nem é cortada numa pequena.
## Cada opção é um canvas-alvo (quanto de UI a pessoa quer ver); o fator é o maior passo (nunca menos que 1) que ainda deixa o
## canvas com pelo menos esse tamanho, limitado ao encaixe do bloco (min(w/960, h/540)), de modo que nada é cortado.
##   Grande 960x540 (o bloco ocupa a janela), Médio 1280x720, Pequeno 1600x900: passos de 0,5. Automático: alvo 1280x720 como o Médio, mas em
##   passos de 0,25, então acompanha melhor a janela (1600x900 vira 1,25; o Médio ficaria em 1,0 até 1920x1080).
## Tudo aqui é conta pura sobre o tamanho da janela (os testes passam o tamanho), e fica um estado estático com o último resultado,
## que as telas leem sem precisar de referência ao mundo.

const LARG := 960.0
const ALT := 540.0
const BLOCO := Vector2(LARG, ALT)
const OPCOES := ["auto", "pequeno", "medio", "grande"]
const ROTULOS := ["Automático", "Pequeno", "Médio", "Grande"]
const ALVOS := {"auto": Vector2(1280, 720), "medio": Vector2(1280, 720), "pequeno": Vector2(1600, 900), "grande": Vector2(960, 540)}
const CHAVE := "tamanho_ui"

## Para os testes e as fotos: tamanho de janela forçado (zero = o da janela de verdade; em headless, o próprio bloco 960x540).
static var janela_forcada := Vector2i.ZERO
## O último resultado, escrito pela apresentação e pelas telas de menu: fator, canvas e deslocamento do bloco no canvas.
static var fator_atual := 1.0
static var canvas_atual := BLOCO
static var desloc_atual := Vector2.ZERO


## O fator para uma janela (em px) e uma opção ("auto", "pequeno", "medio" ou "grande").
static func fator(janela: Vector2, opcao: String) -> float:
	var j := Vector2(maxf(janela.x, 1.0), maxf(janela.y, 1.0))
	var encaixe := minf(j.x / LARG, j.y / ALT)
	var alvo: Vector2 = ALVOS.get(opcao, ALVOS.auto)
	var bruto := minf(j.x / alvo.x, j.y / alvo.y)
	var gran := 4.0 if opcao == "auto" else 2.0  # o Automático afina em passos de 0,25 (1920x1080 não é mais 1,5 seco); os fixos andam de 0,5
	var passo := maxf(floorf(bruto * gran + 0.0001) / gran, 1.0)
	return minf(passo, encaixe)


## O canvas da UI em px de UI (janela / fator, arredondado para cima: cobre a janela inteira).
static func canvas(janela: Vector2, opcao: String) -> Vector2:
	var f := fator(janela, opcao)
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


## Calcula para a janela e a opção atuais (ou a `opcao_forcada`, que o salão usa para ficar sempre encaixado), guarda no estado estático e devolve o fator.
static func atualizar(w: Window, opcao_forcada := "") -> float:
	var j := janela_px(w)
	var o := opcao_forcada if OPCOES.has(opcao_forcada) else opcao_atual()
	fator_atual = fator(j, o)
	canvas_atual = canvas(j, o)
	desloc_atual = deslocamento(canvas_atual)
	return fator_atual


## Rótulo da opção para as telas de ajuste.
static func rotulo(opcao: String) -> String:
	var i := OPCOES.find(opcao)
	return ROTULOS[i] if i >= 0 else ROTULOS[0]

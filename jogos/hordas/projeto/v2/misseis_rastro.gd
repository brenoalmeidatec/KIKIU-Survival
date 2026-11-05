extends RefCounted
## O rastro dos micro-mísseis da E do LightWolf (pedido do Alisson de 05/11/2026: "Mísseis devem ter rastros, pode ser fumaça ou qualquer coisa"): um pontinho de CHAMA no
## bocal e uma fumaça de puffs deixados atrás dele. Só desenho: v2/adagas.gd decide ONDE (o bocal do míssil, pelo caminho DESENHADO, descida do pod incluída) e QUANDO (a cada
## ESPACO px de voo, não por sorteio), e este arquivo guarda os puffs num pool fixo (MAX; sem nó por puff, sem RNG: a sequência da partida não muda) e desenha.
##
## Grade de pixel: os puffs são quadradinhos de 2 a 4 px em posição inteira, sem rotação e SEM alfa parcial. Em vez de esmaecer, o puff vive em DEGRAUS: nasce pequeno e quente
## (2 px âmbar), vira fumaça clara (3 px), cresce até o cinza médio (4 px), segue 4 px num cinza escuro, encolhe para uma sobra mínima (3 px) e some inteiro. Cada degrau dura 1/5 de DUR e
## o puff sobe 1 px a cada dois degraus. DUR = 0,6 s de MUNDO = 0,48 s na tela (a partida anda a 1,25x).
## "Reduzir piscadas": só os degraus cinza, 3 trocas em vez de 5, todas do claro para o escuro e nunca de volta (desbotar não é piscar); a chama do bocal é fixa em qualquer opção.
## Perfil Baixo (efe_particulas <= 0,3): nenhum puff nasce (`adagas._fumaca`); fica só a chama do bocal, que é um desenho a mais do míssil e não uma partícula.

const MAX := 128  # ~8 mísseis no ar x (0,6 s x 270 px/s / ESPACO) = ~16 puffs vivos cada: cabe; cheio, o próximo toma o lugar do mais antigo
const DUR := 0.6
const ESPACO := 10.0  # px de voo entre dois puffs (~2 quadros a 270 px/s no mundo a 1,25x; a 14 px o rastro lia como faíscas soltas, não como fumaça)
const INICIO := 10.0  # px de voo antes do primeiro: o puff não nasce em cima do pod
const ATRAS := 18.0  # do centro da imagem (24 px) ao ponto onde o puff nasce: 12 até a cauda e 6 depois da ponta da chama
const DEGRAUS := 5
const TAMANHOS := [2, 3, 4, 4, 3]
const CORES := [Color(1.0, 0.78, 0.38), Color(0.9, 0.87, 0.84), Color(0.68, 0.65, 0.68), Color(0.46, 0.44, 0.5), Color(0.3, 0.28, 0.34)]
const CALMO := [1, 1, 2, 2, 3]  # com "Reduzir piscadas": o degrau de CORES/TAMANHOS usado em cada degrau da vida (sem o âmbar, três trocas)
const CHAMA_NUCLEO := Color(1.0, 0.92, 0.55)
const CHAMA_PONTA := Color(1.0, 0.5, 0.1)

var pos := PackedVector2Array()  # inteiras
var resta := PackedFloat32Array()  # segundos de vida que faltam (<= 0 = livre)
var emitidos := 0  # quantos puffs nasceram desde o último `limpar` (testes)
var _prox := 0  # onde o próximo puff procura lugar (anel); cheio, toma o lugar do mais antigo


func montar() -> void:
	pos.resize(MAX)
	resta.resize(MAX)
	limpar()


func limpar() -> void:
	resta.fill(0.0)
	_prox = 0
	emitidos = 0


## Um puff novo em `p` (arredondada aqui). Pool cheio: toma o lugar do que vem do anel (o mais antigo, já que nasce em ordem).
func emitir(p: Vector2) -> void:
	var i := _prox
	for k in MAX:
		var j := (_prox + k) % MAX
		if resta[j] <= 0.0:
			i = j
			break
	pos[i] = p.round()
	resta[i] = DUR
	_prox = (i + 1) % MAX
	emitidos += 1


func atualizar(dt: float) -> void:
	for i in MAX:
		if resta[i] > 0.0:
			resta[i] = maxf(0.0, resta[i] - dt)


func vivos() -> int:
	var n := 0
	for t in resta:
		if t > 0.0:
			n += 1
	return n


## O degrau (0 a DEGRAUS - 1) do puff com `falta` s de vida: 0 = recém-nascido. Com `calmo` ("Reduzir piscadas") devolve o degrau de CORES/TAMANHOS que vale (CALMO).
func degrau(falta: float, calmo: bool) -> int:
	var d := clampi(int((1.0 - falta / DUR) * float(DEGRAUS)), 0, DEGRAUS - 1)
	return CALMO[d] if calmo else d


func desenhar(no: Node2D, calmo: bool) -> void:
	for i in MAX:
		if resta[i] <= 0.0:
			continue
		var d := clampi(int((1.0 - resta[i] / DUR) * float(DEGRAUS)), 0, DEGRAUS - 1)
		var e := degrau(resta[i], calmo)
		var t: int = TAMANHOS[e]
		var c: Color = CORES[e]
		var p: Vector2 = pos[i] + Vector2(0.0, -float(d / 2))  # sobe 1 px a cada dois degraus da vida (inteiro: não mexe na grade)
		match t:
			2:
				no.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), c)
			3:  # cruz de 3 px (3x1 + 1x3)
				no.draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 1)), c)
				no.draw_rect(Rect2(p - Vector2(0, 1), Vector2(1, 3)), c)
			_:  # 4 px com as quinas cortadas (4x2 + 2x4): lê como bolinha e não como quadrado
				no.draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 2)), c)
				no.draw_rect(Rect2(p - Vector2(1, 2), Vector2(2, 4)), c)


## A chama do bocal: um núcleo 2x2 colado na cauda da imagem e uma ponta de 1 px atrás dele, nos 16 ângulos do míssil. `centro` é o centro da imagem (inteiro), `dir` o vetor
## da direção quantizada do desenho. Fixa: nunca pisca nem muda com o tempo. Desenhada ANTES da imagem, que fica por cima e não perde leitura.
static func chama(no: Node2D, centro: Vector2, dir: Vector2) -> void:
	var nuc := (centro - dir * 13.0).round()
	no.draw_rect(Rect2(nuc - Vector2.ONE, Vector2(2, 2)), CHAMA_NUCLEO)
	no.draw_rect(Rect2((centro - dir * 16.0).round(), Vector2.ONE), CHAMA_PONTA)

extends RefCounted
## Direção em que o boneco olha: tabela de linhas da folha num lugar só + giro suave com histerese.
## Folha com 8 linhas (altura 480): baixo, esquerda, direita, cima, baixo_esquerda, baixo_direita, cima_esquerda, cima_direita.
## Folha com 4 linhas (altura 240, heróis da Cairu): só as 4 primeiras, escolhidas pelo eixo dominante, como sempre foi.
## Ângulo de olhar em graus: 0 = baixo, 90 = direita, 180 = cima, -90 = esquerda (atan2(x, y) do vetor de movimento).
## Uso: var olhar := Direcao.new(); a cada quadro olhar.atualizar(mov, dt, spr.vframes); a linha é LINHA[olhar.dir].

const ALT_QUADRO := 60
const LINHA := {
	"baixo": 0,
	"esquerda": 1,
	"direita": 2,
	"cima": 3,
	"baixo_esquerda": 4,
	"baixo_direita": 5,
	"cima_esquerda": 6,
	"cima_direita": 7,
}
## Nomes na ordem em que o ângulo cresce (cada passo = 360 / n graus). Índice do setor = round(ângulo / passo).
const SETORES := {
	8: ["baixo", "baixo_direita", "direita", "cima_direita", "cima", "cima_esquerda", "esquerda", "baixo_esquerda"],
	4: ["baixo", "direita", "cima", "esquerda"],
}
const VEL_GIRO := 800.0  # graus por segundo (180° em ~0,23 s, passando pelas intermediárias)
const HISTERESE := 8.0  # graus além da fronteira do setor antes de trocar de direção

var angulo := 0.0  # para onde o boneco está olhando agora (gira com velocidade limitada)
var alvo := 0.0  # para onde quer olhar (última direção de movimento)
var dir := "baixo"  # nome da direção atual (chave de LINHA)
var _andou := false  # já andou alguma vez (a histerese de 4 direções só vale depois do primeiro passo)


## Número de linhas de direção de uma folha: altura / 60; 8 ou mais -> 8, senão 4.
static func linhas_da_altura(altura: int) -> int:
	return 8 if altura / ALT_QUADRO >= 8 else 4


static func angulo_de(v: Vector2) -> float:
	return rad_to_deg(atan2(v.x, v.y))


static func dif(a: float, b: float) -> float:
	return wrapf(b - a, -180.0, 180.0)


## Gira 'olhar' em direção a 'alvo' pelo caminho mais curto, no máximo vel * dt graus. Resultado em [-180, 180).
static func girar(olhar: float, alvo_: float, dt: float, vel: float = VEL_GIRO) -> float:
	var d := dif(olhar, alvo_)
	var passo := vel * maxf(dt, 0.0)
	if absf(d) <= passo:
		return wrapf(alvo_, -180.0, 180.0)
	return wrapf(olhar + signf(d) * passo, -180.0, 180.0)


## Direção (nome) para um ângulo de olhar, com n = 4 ou 8 direções. 'atual' mantém a direção anterior
## enquanto o ângulo não passar da fronteira do setor mais HISTERESE (não pisca no meio do caminho).
static func direcao_de(angulo_: float, n: int, atual: String = "") -> String:
	var nomes: Array = SETORES[n]
	var passo := 360.0 / n
	var i_atual: int = nomes.find(atual)
	if i_atual >= 0 and absf(dif(i_atual * passo, angulo_)) <= passo * 0.5 + HISTERESE:
		return atual
	return nomes[int(roundf(wrapf(angulo_, 0.0, 360.0) / passo)) % n]


## Regra das 4 direções (eixo dominante), usada pelas folhas de 4 linhas. Com `atual`, o eixo só troca quando o outro
## passa da fronteira com folga (HISTERESE4): manche analógico ou robô oscilando em volta da diagonal não faz o boneco
## piscar entre de lado e de frente. Sem `atual` (ou parado) vale a regra seca de antes.
const HISTERESE4 := 0.25  # fração da razão x/y da fronteira (0,9) que o eixo atual ganha de folga


static func direcao4(v: Vector2, atual: String = "") -> String:
	var lim := 0.9
	if atual == "direita" or atual == "esquerda":
		lim *= 1.0 - HISTERESE4  # já de lado: continua de lado até y mandar de verdade
	elif atual == "baixo" or atual == "cima":
		lim *= 1.0 + HISTERESE4  # já de frente/costas: só vira de lado quando x mandar de verdade
	if absf(v.x) > absf(v.y) * lim:
		return "direita" if v.x > 0 else "esquerda"
	return "baixo" if v.y > 0 else "cima"


## Um quadro: mov = movimento (ou entrada); parado mantém o alvo (e termina o giro que faltava). n = linhas da folha.
func atualizar(mov: Vector2, dt: float, n: int) -> void:
	var tem := mov.length_squared() > 0.0001
	if tem:
		alvo = angulo_de(mov)
	if n < 8:
		if tem:
			dir = direcao4(mov, dir if _andou else "")
			_andou = true
			angulo = alvo
		return
	angulo = girar(angulo, alvo, dt)
	dir = direcao_de(angulo, 8, dir)

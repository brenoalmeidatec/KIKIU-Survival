extends RefCounted
## Opção "Reduzir piscadas" (#512, UI-2): o ponto único que todo efeito de luz que liga e desliga consulta. Referência: WCAG 2.3.1, no máximo
## 3 trocas de luminância por segundo, e nenhum vermelho piscando. Nada de `Config.v("reduzir_piscadas")` espalhado: quem pisca pergunta aqui.
## A opção fica em Config.ITENS (grupo Gráfico, ao lado de mostrar_fps), fora do perfil dos Gráficos: ligar ou desligar não vira "Personalizado".
## Com ela ligada: a invencibilidade vira um tom vermelho translúcido fixo; os clarões de tela não acendem; o glitch do clima fica desligado;
## vida baixa e fôlego cansado viram cor fixa; o chão anunciado cresce sem pulsar; o flash de acerto vira tinta de alfa 0,5 que não repete
## no mesmo monstro em menos de FLASH_REPETE_S (0,34 s) (o flash da morte fica); brasas e cintilas com alfa constante.
## Toda luz de tela cheia nova (limpeza, aviso da Maré, explosão do mecha, ÁPICE) passa por `clarao_permitido()`.

const OPCAO := "reduzir_piscadas"
const MAX_TROCAS_S := 3.0  # o teto que o teste confere
const INVENCIVEL := Color(1.0, 0.7, 0.7, 0.6)  # herói invencível: translúcido, vermelho fixo (sem liga e desliga)
const FLASH_ALFA := 0.5  # flash de acerto: tinta da própria cor, alfa fixo
const FLASH_REPETE_S := 0.34  # o mesmo monstro não leva outro flash de acerto antes disso (a cada 0,34 s cabem 3 por segundo: 0,33 deixava 4 em 1 s)
const ALFA_FIXO := 0.8  # brasas, cintilas e torres por expirar: o alfa constante no lugar do tremeluzir


## A opção está ligada? (lê o Config na hora, então vale assim que o jogador muda)
static func ligado() -> bool:
	return Config.reduzir_piscadas  # cache do Config (refeito quando a opção muda): ler por quadro não varre Config.ITENS


## Pode acender uma luz de tela cheia agora? Falso com a opção ligada.
static func clarao_permitido() -> bool:
	return not ligado()


## Metade "acesa" de um liga e desliga de `hz` ciclos por segundo no instante `tempo` (s). Sempre falso com a opção ligada.
static func pisca(tempo: float, hz: float) -> bool:
	if ligado():
		return false
	return int(tempo * hz * 2.0) % 2 == 0


## `variavel` (o valor que tremeluz) ou `fixo` (o valor parado) conforme a opção.
static func valor(variavel: float, fixo: float) -> float:
	return fixo if ligado() else variavel


## Quantas vezes a série `amostras` cruza o ponto médio entre o menor e o maior valor (as "trocas" do teste). Só uma série praticamente
## parada (variação de até `minimo`, ruído de ponto flutuante) não troca: qualquer oscilação real conta. É a conta que o teste usa para
## conferir o teto de MAX_TROCAS_S por segundo.
static func trocas(amostras: Array, minimo := 0.0005) -> int:
	if amostras.size() < 2:
		return 0
	var menor := float(amostras[0])
	var maior := menor
	for a in amostras:
		menor = minf(menor, float(a))
		maior = maxf(maior, float(a))
	if maior - menor <= minimo:
		return 0
	var meio := (menor + maior) * 0.5
	var n := 0
	var acima: bool = float(amostras[0]) > meio
	for a in amostras:
		var agora: bool = float(a) > meio
		if agora != acima:
			n += 1
			acima = agora
	return n


## Luminância percebida de uma cor vezes o alfa (o que o teste amostra no herói, no fôlego e na vida).
static func luminancia(c: Color) -> float:
	return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * c.a

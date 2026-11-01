extends RefCounted
## Opção "Reduzir piscadas" (#512, UI-2): o ponto único que todo efeito de luz que liga e desliga consulta. Referência: WCAG 2.3.1, no máximo
## 3 trocas de luminância por segundo, e nenhum vermelho piscando. Nada de `Config.v("reduzir_piscadas")` espalhado: quem pisca pergunta aqui.
## A opção fica em Config.ITENS (grupo Gráfico, ao lado de mostrar_fps), fora do perfil dos Gráficos: ligar ou desligar não vira "Personalizado".
## Com ela ligada: a invencibilidade vira um tom vermelho translúcido fixo; os clarões de tela não acendem; o glitch do clima fica desligado;
## vida baixa (barra e vinheta vermelha) e fôlego cansado viram cor fixa; o chão anunciado cresce sem pulsar; o flash de acerto vira tinta de alfa 0,5 que não repete
## no mesmo monstro em menos de FLASH_REPETE_S (0,7 s) (o flash da morte fica); brasas e cintilas com alfa constante.
## As constantes de "valor parado" ficam aqui (BRASA_FIXA, ENERGIA_FOGO_FIXA, PULSO_RUNA_FIXO, VINHETA_FIXA_K, ALFA_FIXO_QUEDA, ALFA_FIXO_PECA, BRILHO_XP_FIXO, PULSO_ESCUDO_FIXO).
## Toda luz de tela cheia nova (limpeza, aviso da Maré, explosão do mecha, ÁPICE) passa por `clarao_permitido()`.

const OPCAO := "reduzir_piscadas"
const MAX_TROCAS_S := 3.0  # o teto que o teste confere
const INVENCIVEL := Color(1.0, 0.7, 0.7, 0.6)  # herói invencível: translúcido, vermelho fixo (sem liga e desliga)
const FLASH_ALFA := 0.5  # flash de acerto: tinta da própria cor, alfa fixo
const FLASH_REPETE_S := 0.7  # o mesmo monstro não leva outro flash de acerto antes disso: cada flash liga e desliga (2 trocas), então 1/0,7 = 1,43 flashes/s = 2,9 trocas/s
const ALFA_FIXO_QUEDA := 0.6  # cintila do chão anunciado de queda (armas_novas): o centro do tremeluzir de 0,2 a 1,0
const ALFA_FIXO_PECA := 0.7  # peça e torre por desmontar (armas_novas): o centro do tremeluzir de 0,4 a 1,0
const BRILHO_XP_FIXO := 0.5  # barra de XP ao subir de nível (hud): fração do dourado, parada enquanto o brilho dura (o centro de 0 a 1)
const PULSO_HUD_FIXO := 0.5  # pulso() parado: o centro do pulso dos quadros e halos do HUD (E, escudo, Q) e do anel da ruptura
const PULSO_ESCUDO_FIXO := 0.5  # escudo de lado ou de costas com o fôlego baixo (escudo): o centro do pulso vermelho, 0 a 1
const BRASA_FIXA := 0.85  # brilho das brasas (armas_novas): o centro do tremeluzir de 0,7 a 1,0
const ENERGIA_FOGO_FIXA := 0.75  # energia da luz do fogo da aura (armas): o centro do tremeluzir
const PULSO_RUNA_FIXO := 0.85  # brilho do glifo das runas armadas (armas): o centro do pulso de 0,7 a 1,0
const VINHETA_FIXA_K := 0.875  # vida baixa: a vinheta fica em VINHETA_MAX x isto (o centro do pulso de 0,75 a 1,0), sem pulsar


## A opção está ligada? (lê o Config na hora, então vale assim que o jogador muda)
static func ligado() -> bool:
	return Config.reduzir_piscadas  # cache do Config (refeito quando a opção muda): ler por quadro não varre Config.ITENS


## Pode acender uma luz de tela cheia agora? Falso com a opção ligada.
static func clarao_permitido() -> bool:
	return not ligado()


## Pulso senoidal de 0 a 1 a `hz` ciclos por segundo no instante `tempo_s` (s). Com a opção ligada, parado no meio (PULSO_HUD_FIXO). Para pulso de HUD e de anel.
static func pulso(tempo_s: float, hz: float) -> float:
	return PULSO_HUD_FIXO if ligado() else 0.5 + 0.5 * sin(TAU * hz * tempo_s)


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

extends RefCounted
## Detalhe dinâmico (aba Gráficos, opção "qualidade_auto"): a partida começa no Perfil escolhido e acompanha o fps medido. Com o
## fps abaixo de 40 por 8 s seguidos, o perfil desce um degrau (Alto, Médio, Baixo); com o fps firme (no alvo) por 30 s, sobe um
## degrau de volta, mas só até o Perfil escolhido (o teto): nunca acima dele. Se a subida foi seguida de outra queda em menos de
## 60 s, a espera para subir de novo dobra (até 4 min): assim não fica trocando de um lado para o outro.
## O Personalizado não mexe: é escolha do jogador. Quem chama decide quando contar (partida, sem pausa, no jogo de verdade) e aplica
## o resultado com Config.g_perfil_temporario, que vale só nesta sessão e não grava nas opções.
## Um degrau abaixo do Baixo entra depois com uma linha: o nome no fim de DEGRAUS (mais o perfil de mesmo nome em
## dados/graficos.json); o resto (descer, subir, o teto, o anúncio) já anda por essa lista.

const FPS_MINIMO := 40.0
const SEGUNDOS := 8.0
const SEGUNDOS_SUBIR := 30.0
const SEGUNDOS_SUBIR_MAX := 240.0
const JANELA_VAI_E_VOLTA := 60.0
const DEGRAUS := ["alto", "medio", "baixo"]  # do melhor ao pior; a ordem manda (descer = próximo, subir = anterior)
const NOMES_ANUNCIO := {"alto": "alta", "medio": "média", "baixo": "baixa"}  # "FPS baixo: qualidade gráfica ...": sem nome, usa o do degrau

var _lento := 0.0  # segundos seguidos com o fps abaixo do mínimo
var _firme := 0.0  # segundos seguidos com o fps no alvo
var _espera := SEGUNDOS_SUBIR  # quanto o fps precisa ficar firme para subir
var _relogio := 0.0  # soma dos dt, para medir o tempo entre uma subida e a queda seguinte
var _subiu_em := -1000.0


## Menus e pausas interrompem a medição contínua de FPS; a espera anti-oscilação é preservada.
func interromper() -> void:
	_lento = 0.0
	_firme = 0.0


## Conta um quadro (dt em s, fps do quadro, perfil atual, fps alvo da subida, teto = o Perfil escolhido) e devolve o perfil para o qual mudar, ou "" se nada
## muda agora. Depois de mudar, as contagens recomeçam do zero. Com limite de fps baixo, o "travado" é abaixo do alvo (e não
## abaixo de 40): rodar no próprio limite não é travamento, e sem isso o perfil desce sem parar até o Baixo.
func passo(dt: float, fps: float, perfil: String, alvo := 55.0, teto := "alto") -> String:
	var i := DEGRAUS.find(perfil)
	var i_teto := maxi(DEGRAUS.find(teto), 0)  # teto desconhecido (Personalizado já saiu acima): o melhor degrau
	if i < 0:
		interromper()
		return ""
	_relogio += dt
	var minimo := minf(FPS_MINIMO, alvo)  # sem limite baixo (alvo 55) o mínimo é 40; com o limite em 30, o alvo é 27,6
	_lento = _lento + dt if fps < minimo else 0.0
	_firme = _firme + dt if fps >= alvo else 0.0
	if i < DEGRAUS.size() - 1 and _lento >= SEGUNDOS:
		_lento = 0.0
		_firme = 0.0
		if _relogio - _subiu_em < JANELA_VAI_E_VOLTA:
			_espera = minf(_espera * 2.0, SEGUNDOS_SUBIR_MAX)  # subiu e travou logo: da próxima espera mais
		return DEGRAUS[i + 1]
	if i > i_teto and _firme >= _espera:
		_firme = 0.0
		_lento = 0.0
		_subiu_em = _relogio
		return DEGRAUS[i - 1]
	return ""

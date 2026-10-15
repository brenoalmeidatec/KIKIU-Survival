extends RefCounted
## Baixa automática de qualidade (opção "Baixar a qualidade se travar", aba Gráficos): com o fps abaixo de 40 por 8 s seguidos,
## o perfil desce um degrau (Alto, Médio, Baixo). Nunca sobe sozinho, e o Personalizado não mexe: é escolha do jogador.
## Quem chama decide quando contar (partida, sem pausa, no jogo de verdade) e aplica o resultado com
## Config.g_perfil_temporario, que vale só nesta sessão e não grava nas opções.

const FPS_MINIMO := 40.0
const SEGUNDOS := 8.0
const DEGRAUS := ["alto", "medio", "baixo"]

var _lento := 0.0  # segundos seguidos com o fps abaixo do mínimo


## Conta um quadro (dt em s, fps do quadro, perfil atual) e devolve o perfil para o qual descer, ou "" se nada muda agora.
## Depois de descer, a contagem recomeça do zero: outro degrau só depois de mais 8 s travado.
func passo(dt: float, fps: float, perfil: String) -> String:
	var i := DEGRAUS.find(perfil)
	if i < 0 or i == DEGRAUS.size() - 1:
		_lento = 0.0
		return ""
	_lento = _lento + dt if fps < FPS_MINIMO else 0.0
	if _lento < SEGUNDOS:
		return ""
	_lento = 0.0
	return DEGRAUS[i + 1]

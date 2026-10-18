extends RefCounted
## Perfil Dinâmico (aba Gráficos): começa no Alto e acompanha o fps medido. Com o fps abaixo de 40 por 8 s seguidos, o perfil
## desce um degrau (Alto, Médio, Baixo); com o fps firme (no alvo) por 30 s, sobe um degrau de volta. Se a subida foi seguida de
## outra queda em menos de 60 s, a espera para subir de novo dobra (até 4 min): assim não fica trocando de um lado para o outro.
## O Personalizado não mexe: é escolha do jogador. Quem chama decide quando contar (partida, sem pausa, no jogo de verdade) e aplica
## o resultado com Config.g_perfil_temporario, que vale só nesta sessão e não grava nas opções.

const FPS_MINIMO := 40.0
const SEGUNDOS := 8.0
const SEGUNDOS_SUBIR := 30.0
const SEGUNDOS_SUBIR_MAX := 240.0
const JANELA_VAI_E_VOLTA := 60.0
const DEGRAUS := ["alto", "medio", "baixo"]

var _lento := 0.0  # segundos seguidos com o fps abaixo do mínimo
var _firme := 0.0  # segundos seguidos com o fps no alvo
var _espera := SEGUNDOS_SUBIR  # quanto o fps precisa ficar firme para subir
var _relogio := 0.0  # soma dos dt, para medir o tempo entre uma subida e a queda seguinte
var _subiu_em := -1000.0


## Conta um quadro (dt em s, fps do quadro, perfil atual, fps alvo da subida) e devolve o perfil para o qual mudar, ou "" se nada
## muda agora. Depois de mudar, as contagens recomeçam do zero.
func passo(dt: float, fps: float, perfil: String, alvo := 55.0) -> String:
	var i := DEGRAUS.find(perfil)
	if i < 0:
		_lento = 0.0
		_firme = 0.0
		return ""
	_relogio += dt
	_lento = _lento + dt if fps < FPS_MINIMO else 0.0
	_firme = _firme + dt if fps >= alvo else 0.0
	if i < DEGRAUS.size() - 1 and _lento >= SEGUNDOS:
		_lento = 0.0
		_firme = 0.0
		if _relogio - _subiu_em < JANELA_VAI_E_VOLTA:
			_espera = minf(_espera * 2.0, SEGUNDOS_SUBIR_MAX)  # subiu e travou logo: da próxima espera mais
		return DEGRAUS[i + 1]
	if i > 0 and _firme >= _espera:
		_firme = 0.0
		_lento = 0.0
		_subiu_em = _relogio
		return DEGRAUS[i - 1]
	return ""

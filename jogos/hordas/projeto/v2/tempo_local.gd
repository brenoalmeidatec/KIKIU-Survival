extends RefCounted
## O tempo "de quem joga": hit-stop, câmera lenta e a pausa da escolha (carta, baú) de UM jogador (v2/combate.gd tem um destes por herói local).
## No solo ele vale para o mundo inteiro (combate.passo_tempo devolve o mesmo dt para todos). No coop (etapa 5 de docs/ONLINE_V2_PLANO.md) e na tela
## dividida só o herói dono congela ou desacelera; o relógio e os monstros do mundo seguem. Esta classe só guarda o estado e conta o relógio.
## A ação do fim da câmera lenta (abrir a escolha, a morte, a vitória) continua no combate, que é quem conhece as telas.

var parada_t := 0.0  # hit-stop que falta (s, relógio real)
var lento_t := 0.0  # câmera lenta que falta (s, relógio real)
var lento_escala := 1.0
var lento_acao := ""  # o que acontece quando a câmera lenta acaba: "nivel", "morte" ou "vitoria"
var pausado := false  # escolha de melhoria, baú ou resultado aberto para este jogador


## Volta ao estado de partida nova.
func zerar() -> void:
	parada_t = 0.0
	lento_t = 0.0
	lento_escala = 1.0
	lento_acao = ""
	pausado = false


## Pede um hit-stop de `s` segundos (vale o maior que estiver em curso). Devolve true se este pedido passou a valer.
func parar(s: float) -> bool:
	if s > parada_t:
		parada_t = s
		return true
	return false


func camera_lenta(acao: String, dur: float, escala: float) -> void:
	lento_t = dur
	lento_escala = escala
	lento_acao = acao

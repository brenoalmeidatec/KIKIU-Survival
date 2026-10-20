extends Node
## Trilha sonora da v2: decide qual faixa toca em cada MOMENTO (santuário, partida, chefe, resultado) e pede ao Som (autoload) a troca
## com crossfade. O volume é o do slider Música das Ajustes, que mora no bus "Musica" (som.gd); aqui só se escolhe a faixa.
## Faixas e momentos em dados/v2_musica.json (veja o _ajuda); origem e licença dos arquivos em docs/LICENCAS_AUDIO.md.
## Uso (uma linha em cada ponto de entrada):
##   santuário (altar.gd):  var t := Trilha.new(); add_child(t); t.tocar("santuario")
##   partida (mundo.gd):    var t := Trilha.new(); add_child(t); t.ligar(self)
## A partida liga sozinha os sinais do mundo: chefe_apareceu toca o chefe, o chefe cair (mini) volta a partida, e partida_terminou toca o
## resultado. O chefe final cai com a câmera lenta da vitória, então a faixa dele segue até o resultado.

const DADOS := "v2_musica"

var momento := ""  # o momento que está tocando (vazio: ainda nenhum)
var faixa := ""  # a faixa pedida ao Som nesse momento
var mundo = null
var _faixas := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_faixas = Dados.json(DADOS).get("faixas", {})


## Liga ao mundo da partida: começa na faixa da partida e segue os sinais dele.
func ligar(m) -> Node:
	mundo = m
	m.chefe_apareceu.connect(_chefe_apareceu)
	m.chefe_vida.connect(_chefe_vida)
	m.partida_terminou.connect(_terminou)
	tocar("partida")
	for k in ["chefe", "resultado"]:  # no carregamento: ler o .ogg (~7 ms cada) no quadro em que o chefe aparece era um engasgo
		if str(_faixas.get(k, "")) != "":
			Som.preparar_musica(str(_faixas[k]))
	return self


## Troca para a faixa do momento (com crossfade). Mesmo momento, ou momento sem faixa nos dados: nada acontece.
func tocar(m: String) -> void:
	var f := str(_faixas.get(m, ""))
	if m == momento or f == "":
		return
	momento = m
	faixa = f
	Som.musica(f)


func _chefe_apareceu(_nome = "", _vida_max = 1.0) -> void:
	tocar("chefe")


## O sinal sai antes de o combate saber se foi mini-chefe ou o final (chefe.gd emite e depois chama a vitória), então a decisão
## espera um instante: se a partida segue (jogando, escolha ou baú), foi um mini-chefe e volta a faixa da partida.
func _chefe_vida(vida = 1.0) -> void:
	if float(vida) <= 0.0:
		_chefe_caiu.call_deferred()


func _chefe_caiu() -> void:
	if momento != "chefe" or mundo == null or not is_instance_valid(mundo):
		return
	var c = mundo.get("combate")
	if c != null and str(c.get("jogo")) in ["jogando", "escolha", "bau"]:
		tocar("partida")


func _terminou(_resultado = {}) -> void:
	tocar("resultado")

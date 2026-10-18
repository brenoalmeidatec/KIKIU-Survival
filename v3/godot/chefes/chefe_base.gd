extends RefCounted
## Base de chefe da v3 (compartilhada por Vornak, Nythrax e Maltherion). Só lógica, sem nó: vida, fase, estados e ataques com aviso.
## Estados: andar -> aviso (área anunciada) -> impacto (um quadro, dano sai uma vez) -> recupera -> andar. Fase 2 abre em `fase2` da vida
## e troca a lista de ataques pelos marcados com "fase": 2 (com a transição antes de voltar a atacar).
## Os números ficam no dicionário de cada chefe (vida, ataques, recargas). São valores iniciais, ajustáveis.
## Quem desenha ouve os sinais: aviso_iniciou(nome, raio), golpe(nome, raio, dano), fase_mudou(fase), morreu().

signal aviso_iniciou(nome: String, raio: float)
signal golpe(nome: String, raio: float, dano: float)
signal estado_mudou(novo: String)
signal fase_mudou(fase: int)
signal morreu

const DURACAO_TRANSICAO := 1.6

var vida_max := 1000.0
var vida := 1000.0
var fase := 1
var estado := "andar"
var t_estado := 0.0
var fase2_limiar := 0.4
var fase3_limiar := -1.0  # só chefes com terceira fase (Maltherion) usam; -1 desliga
var ataques: Array = []
var ataque_atual: Dictionary = {}
var _recarga := 0.0
var _rodizio := 0


func iniciar(cfg: Dictionary) -> void:
	vida_max = float(cfg.vida)
	vida = vida_max
	fase2_limiar = float(cfg.get("fase2", 0.4))
	fase3_limiar = float(cfg.get("fase3", -1.0))
	ataques = cfg.ataques
	fase = 1
	_trocar("andar")


func _trocar(novo: String) -> void:
	estado = novo
	t_estado = 0.0
	estado_mudou.emit(novo)


func morto() -> bool:
	return estado == "morto"


## Recebe dano e devolve true se o chefe morreu neste golpe. A fase 2 começa aqui, com a transição.
func receber_dano(valor: float) -> bool:
	if morto() or valor <= 0.0:
		return morto()
	vida = max(0.0, vida - valor)
	if vida <= 0.0:
		_trocar("morto")
		morreu.emit()
		return true
	if fase < 3 and fase3_limiar > 0.0 and vida <= vida_max * fase3_limiar:
		fase = 3
		fase_mudou.emit(3)
		_trocar("transicao")
		return false
	if fase == 1 and vida <= vida_max * fase2_limiar:
		fase = 2
		fase_mudou.emit(2)
		_trocar("transicao")
	return false


func curar(valor: float) -> void:
	if not morto():
		vida = min(vida_max, vida + valor)


func avancar(dt: float) -> void:
	if morto():
		return
	t_estado += dt
	_recarga = max(0.0, _recarga - dt)
	match estado:
		"andar":
			if _recarga <= 0.0:
				_iniciar_aviso()
		"aviso":
			if t_estado >= float(ataque_atual.aviso):
				_trocar("impacto")
				_impacto()
		"impacto":
			_trocar("recupera")
		"recupera":
			if t_estado >= float(ataque_atual.recupera):
				_trocar("andar")
		"transicao":
			if t_estado >= DURACAO_TRANSICAO:
				_recarga = 1.0
				_trocar("andar")


func _disponiveis() -> Array:
	var lista := []
	for a in ataques:
		if int(a.get("fase", 1)) <= fase:
			lista.append(a)
	return lista


func _iniciar_aviso() -> void:
	var lista := _disponiveis()
	if lista.is_empty():
		return
	ataque_atual = lista[_rodizio % lista.size()]
	_rodizio += 1
	_trocar("aviso")
	aviso_iniciou.emit(String(ataque_atual.nome), float(ataque_atual.get("raio", 0.0)))


func _impacto() -> void:
	var nome := String(ataque_atual.nome)
	var raio := float(ataque_atual.get("raio", 0.0))
	var dano := float(ataque_atual.get("dano", 0.0))
	if ataque_atual.has("cura"):
		curar(float(ataque_atual.cura))
	golpe.emit(nome, raio, dano)
	_recarga = float(ataque_atual.recarga)

extends RefCounted
## XP, nível e escolha de cartas da v2. O XP vem dos orbes (combate.coletar). Ao encher a barra: sobe o nível (sinal nivel_subiu do mundo),
## câmera lenta de 0,4 s e a escolha de 1 entre 3 cartas (v2/cartas.gd: raridade, golpes secundários, modificadores da katana, evoluções), que
## pausa o mundo até o jogador escolher. Na escolha dá para RERROLAR (1 vez por tela, poucas na partida) e BANIR uma carta (ela não volta mais).
## Várias subidas seguidas viram várias escolhas, uma depois da outra. A curva de nível fica em dados/v2_combate.json ("xp", "nivel") e as
## cartas em dados/v2_cartas.json.

var combate
var cfg: Dictionary
var melhorias := {}  # id da carta -> quantas vezes pegou
var pendentes := 0  # níveis subidos que ainda esperam a escolha
var cartas: Array = []  # as cartas na tela
var escolhidas := 0  # quantas cartas o jogador já escolheu (testes)
var ultima_nome := ""  # o nome da última carta escolhida (o aviso da escolha automática diz qual foi)


func montar(c) -> void:
	combate = c
	cfg = c.cfg
	var h = c.mundo.heroi
	if h != null:
		h.xp_proximo = xp_para(1)


## XP que falta para sair do nível `n`: base + passo*(n-1) + quad*(n-1)^2.
func xp_para(n: int) -> float:
	var k := float(n - 1)
	var x: Dictionary = cfg.xp
	return roundf(float(x.base) + float(x.passo) * k + float(x.quad) * k * k)


## Vida que o herói recupera a cada nível que sobe (a fração `cura_nivel` da vida máxima de agora). O card de status mostra este valor.
func cura_por_nivel() -> float:
	return combate.mundo.heroi.vida_max * float(cfg.heroi.cura_nivel)


## Fração a mais por nível acima do 1 (regra = {por_nivel, teto}, de dados): nível 1 = 0; sobe `por_nivel` a cada nível e para no `teto`.
## Serve ao alcance do golpe (dados/v2_combate.json > golpe.raio_por_nivel, lido em combate.gd) e ao raio e ao arco do escudo (dados/v2_secundario.json > escudo).
static func bonus_por_nivel(nivel: int, regra: Dictionary) -> float:
	return minf(float(maxi(nivel - 1, 0)) * float(regra.por_nivel), float(regra.teto))


func zerar() -> void:
	melhorias.clear()
	pendentes = 0
	cartas.clear()
	escolhidas = 0
	if combate.cartas != null:
		combate.cartas.zerar()
	var h = combate.mundo.heroi
	if h != null:
		h.xp = 0.0
		h.nivel = 1
		h.xp_proximo = xp_para(1)


func ganhar_xp(v: float) -> void:
	var h = combate.mundo.heroi
	if not h.vivo():
		return
	h.xp += v
	while h.xp >= h.xp_proximo:
		h.xp -= h.xp_proximo
		h.nivel += 1
		h.xp_proximo = xp_para(h.nivel)
		h.curar(cura_por_nivel())
		pendentes += 1
		combate.nivel_subiu(h.nivel)
	if pendentes > 0 and combate.lento_acao == "" and not combate.pausado and combate.jogo == "jogando":
		combate.camera_lenta("nivel", float(cfg.nivel.camera_lenta), float(cfg.nivel.escala_lenta))


## Sorteia as cartas (até 3, diferentes) e abre a escolha (pausa o mundo).
func abrir_escolha() -> void:
	var cs = combate.cartas
	cs.rerrolar_na_tela = 0
	cartas = cs.sortear(int(cs.cfg.escolha.cartas), combate.mundo.heroi.nivel)
	if cartas.is_empty():  # tudo no máximo: uma carta de cura para não travar
		cartas = [_carta_cura()]
	combate.jogo = "escolha"
	combate.pausado = true
	combate.telas.mostrar_escolha(cartas, combate.mundo.heroi.nivel)


func _carta_cura() -> Dictionary:
	return {
		"id": "cura",
		"nome": "Alma renovada",
		"desc": "Cura toda a vida",
		"cat": "stat",
		"stat": "cura",
		"valor": 0,
		"max": 99,
		"rar": 0,
		"rar_nome": "Comum",
		"cor": Color(0.8, 0.82, 0.86),
		"extra": ""
	}


func escolher(i: int) -> void:
	if i < 0 or i >= cartas.size():
		return
	var c: Dictionary = cartas[i]
	aplicar(c)
	escolhidas += 1
	ultima_nome = str(c.get("nome", ""))
	pendentes = maxi(0, pendentes - 1)
	cartas = []
	combate.telas.esconder()
	combate.pausado = false
	combate.jogo = "jogando"
	combate.audio.tocar("escolher", 1.0, 0.0, 0.0)
	var h = combate.mundo.heroi
	var cor: Color = c.get("cor", Color(1.0, 0.9, 0.6))
	combate.fx.onda(h.pos + Vector2(0, -12), Color(cor.r, cor.g, cor.b, 0.9), 44.0 + 16.0 * float(c.get("rar", 0)), 0.25)
	if pendentes > 0:
		combate.camera_lenta("nivel", float(cfg.nivel.camera_lenta), float(cfg.nivel.escala_lenta))


## Perde a rodada de cartas aberta (o "Sim" de "Pausar agora?" na escolha): nenhuma carta é aplicada, o nível pendente é consumido e não
## há reembolso de rerrolar nem de banir. Com mais níveis pendentes a próxima rodada abre depois, como depois de uma escolha.
func descartar_rodada() -> void:
	if combate.jogo != "escolha":
		return
	pendentes = maxi(0, pendentes - 1)
	cartas = []
	combate.telas.esconder()
	combate.pausado = false
	combate.jogo = "jogando"
	if pendentes > 0:
		combate.camera_lenta("nivel", float(cfg.nivel.camera_lenta), float(cfg.nivel.escala_lenta))


## Escolha AUTOMÁTICA: o sistema escolhe a carta pelo que o herói já tem (cartas.escolha_automatica) e aplica na hora. Sem custo, mas a
## raridade vem rebaixada. Devolve false se não está na escolha ou não sobrou carta nenhuma.
func automatico() -> bool:
	var cs = combate.cartas
	if combate.jogo != "escolha":
		return false
	var c: Dictionary = cs.escolha_automatica(combate.mundo.heroi.nivel)
	if c.is_empty():
		return false
	cartas = [c]
	escolher(0)
	return true


## Rerrola as 3 cartas (novas, sem repetir as que estavam na tela). Devolve false se não pode (acabaram os usos).
func rerrolar() -> bool:
	var cs = combate.cartas
	if not combate.jogo == "escolha" or not cs.pode_rerrolar():
		return false
	var ids: Array = []
	for c in cartas:
		ids.append(c.id)
	var novas: Array = cs.sortear(int(cs.cfg.escolha.cartas), combate.mundo.heroi.nivel, 1.0, ids)
	if novas.size() < cartas.size():  # quase nada sobrou: completa com o que já estava
		novas = cs.sortear(int(cs.cfg.escolha.cartas), combate.mundo.heroi.nivel)
	cs.rerrolar_usados += 1
	cs.rerrolar_na_tela += 1
	cartas = novas
	combate.telas.mostrar_escolha(cartas, combate.mundo.heroi.nivel, true)
	return true


## Bane a carta `i`: nunca mais sai nesta partida, e uma carta nova toma o lugar dela. Devolve false se acabaram os banimentos.
func banir(i: int) -> bool:
	var cs = combate.cartas
	if combate.jogo != "escolha" or i < 0 or i >= cartas.size() or not cs.pode_banir():
		return false
	var velha: Dictionary = cartas[i]
	if str(velha.id) == "cura":
		return false
	cs.banir(str(velha.id))
	var ids: Array = []
	for c in cartas:
		ids.append(c.id)
	var nova: Array = cs.sortear(1, combate.mundo.heroi.nivel, 1.0, ids)
	if nova.is_empty():
		cartas.remove_at(i)
		if cartas.is_empty():
			cartas = [_carta_cura()]
	else:
		cartas[i] = nova[0]
	combate.telas.mostrar_escolha(cartas, combate.mundo.heroi.nivel, true)
	return true


func aplicar(c: Dictionary) -> void:
	combate.cartas.aplicar(c)


static func texto_carta(c: Dictionary) -> String:
	return str(c.desc).replace("{v}", str(int(c.get("valor", 0))))

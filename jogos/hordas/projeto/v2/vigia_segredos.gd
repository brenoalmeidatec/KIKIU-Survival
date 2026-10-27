extends RefCounted
## O vigia dos segredos do mapa (#424): a cada quadro confere se o herói cumpriu o gatilho de algum segredo (dados/v2_segredos.json) e,
## quando cumpre, revela. Cada segredo dispara uma vez por partida. Achado pela primeira vez (Meta.achar_segredo): grava no Códice (a lore
## inteira mora lá), credita as almas e anuncia o nome; nas partidas seguintes só anuncia o nome. O baú, se o segredo tem um, cai todas as partidas.
## Gatilhos: "encostar" (entrar no raio), "parado" (ficar `tempo` s sem andar dentro do raio) e "golpe" (atacar dentro do raio).
## Nada aparece na tela antes: é para achar por acidente. Quem chama é o mundo (montar na partida, atualizar a cada passo).

const Meta := preload("res://v2/meta.gd")
const Segredos := preload("res://v2/segredos.gd")
const COR := Color(0.72, 0.62, 1.0)

var itens: Array = []  # {s, pos, raio, t, feito, golpes, ultima}
var achados := 0  # quantos dispararam nesta partida (testes)

var _mundo


## Refaz a lista do mapa do mundo (também no "Jogar de novo").
func montar(mundo) -> void:
	_mundo = mundo
	itens.clear()
	achados = 0
	for s in Segredos.lista(str(mundo.id_mapa)):
		(
			itens
			. append(
				{
					"s": s,
					"pos": Vector2(float(s.pos[0]), float(s.pos[1])),
					"raio": float(s.raio),
					"t": 0.0,
					"feito": false,
					"golpes": int(mundo.heroi.golpes),
					"ultima": mundo.heroi.pos,
				}
			)
		)


func atualizar(dt: float) -> void:
	if itens.is_empty() or dt <= 0.0:
		return
	var h = _mundo.heroi
	var vel_max := Segredos.parado_vel_max()
	for it in itens:
		if it.feito:
			continue
		var dentro: bool = h.pos.distance_squared_to(it.pos) <= it.raio * it.raio
		match str(it.s.gatilho):
			"encostar":
				if dentro:
					_achar(it)
			"parado":
				if dentro and h.pos.distance_to(it.ultima) <= vel_max * dt:
					it.t += dt
					if it.t >= float(it.s.get("tempo", 3.0)):
						_achar(it)
				else:
					it.t = 0.0
			"golpe":
				if dentro and int(h.golpes) > int(it.golpes):
					_achar(it)
		it.golpes = int(h.golpes)
		it.ultima = h.pos


## O segredo se revela: onda e faíscas no ponto, o anúncio, a gravação no Códice e o baú.
func _achar(it: Dictionary) -> void:
	it.feito = true
	achados += 1
	var s: Dictionary = it.s
	var novo := Meta.achar_segredo(str(s.id))
	var combate = _mundo.combate
	combate.fx.onda(it.pos, Color(COR, 0.9), 64.0, 0.6)
	combate.fx.faiscas(it.pos + Vector2(0, -10), Vector2(0, -1), 14, COR, 140.0)
	combate.audio.tocar("nivel", 1.0, -2.0, 0.0)
	# A faixa de anúncio corta o que passa de ~28 letras (Label com clip_text): são faixas curtas, e a lore inteira fica no Códice.
	if novo:
		combate.anunciar("SEGREDO ACHADO!", COR)
		combate.anunciar(str(s.nome).to_upper(), COR)
		var premio: Dictionary = s.get("recompensa", {})
		if str(premio.get("tipo", "")) == "almas":
			combate.anunciar("NO CÓDICE: +%d ALMAS" % int(premio.n), COR)
	else:
		combate.anunciar(str(s.nome).to_upper(), COR)
	if int(s.get("bau", 0)) > 0:  # o baú cai ao lado (bau_pos): o herói anda até ele, e o anúncio não some atrás das cartas
		var bp: Array = s.get("bau_pos", [s.pos[0], s.pos[1]])
		combate.baus.soltar(Vector2(float(bp[0]), float(bp[1])), 1.0, int(s.bau))

extends RefCounted
## O vigia dos segredos do mapa (#424): a cada quadro confere se o herói cumpriu o gatilho de algum segredo (dados/v2_segredos.json) e,
## quando cumpre, revela. Cada segredo dispara uma vez por partida. Achado pela primeira vez (Meta.achar_segredo): grava no Códice (a lore
## inteira mora lá), credita as almas e anuncia o nome; nas partidas seguintes só anuncia o nome. O baú, se o segredo tem um, cai todas as partidas.
## Gatilhos: "encostar" (entrar no raio), "parado" (ficar `tempo` s sem andar dentro do raio) e "golpe" (atacar dentro do raio).
## Vale qualquer herói de `mundo.herois` (no coop o 2 também acha); cada um tem a própria conta do "parado" e dos golpes. Herói caído não dispara.
## O empurrão de monstro não zera o "parado": o deslocamento que o empurrão explica (o `emp` do herói) entra na folga do quadro.
## O robô (roteiro ativo: --robo, --estresse, --playtest...) pode disparar o segredo na partida dele, mas não grava no save nem credita almas.
## Nada aparece na tela antes: é para achar por acidente. Quem chama é o mundo (montar na partida, atualizar a cada passo).

const Meta := preload("res://v2/meta.gd")
const Segredos := preload("res://v2/segredos.gd")
const Heroi := preload("res://v2/heroi.gd")
const COR := Color(0.72, 0.62, 1.0)

var itens: Array = []  # {s, pos, raio, t (por herói), feito}
var achados := 0  # quantos dispararam nesta partida (testes)

var _mundo
var _maos: Dictionary = {}  # herói -> {golpes, ultima, emp}: o que ele era no quadro anterior


## Refaz a lista do mapa do mundo (também no "Jogar de novo").
func montar(mundo) -> void:
	_mundo = mundo
	itens.clear()
	_maos.clear()
	achados = 0
	for s in Segredos.lista(str(mundo.id_mapa)):
		(
			itens
			. append(
				{
					"s": s,
					"pos": Vector2(float(s.pos[0]), float(s.pos[1])),
					"raio": float(s.raio),
					"t": {},
					"feito": false,
				}
			)
		)


## Os heróis que valem: a lista do mundo (solo: só o local) ou, sem lista, o local.
func _herois() -> Array:
	var lista: Array = _mundo.herois
	return lista if not lista.is_empty() else [_mundo.heroi]


## Golpes e empurrão do herói; um herói de mentira ou remoto sem esses campos conta como 0 e sem empurrão.
func _golpes(h) -> int:
	var g = h.get("golpes")
	return int(g) if g != null else 0


func _emp(h) -> Vector2:
	var e = h.get("emp")
	return e if e is Vector2 else Vector2.ZERO


func atualizar(dt: float) -> void:
	if itens.is_empty() or dt <= 0.0:
		return
	var vel_max := Segredos.parado_vel_max()
	for h in _herois():
		var antes: Dictionary = _maos.get(h, {})
		if antes.is_empty():  # herói que acabou de entrar (coop): a conta dele começa agora
			antes = {"golpes": _golpes(h), "ultima": h.pos, "emp": Vector2.ZERO}
		var vivo: bool = float(h.vida) > 0.0
		# folga do "parado" neste quadro: a velocidade de parado mais o quanto o empurrão andou em dt. O empurrão aplicado é o `emp` do quadro
		# anterior ou, se o golpe veio antes do herói andar, o `emp` de agora desfeito do amortecimento deste quadro
		var emp_aplicado := maxf((antes.emp as Vector2).length(), _emp(h).length() * exp(Heroi.AMORTECE_EMP * dt))
		var quieto: bool = h.pos.distance_to(antes.ultima) <= (vel_max + emp_aplicado) * dt
		for it in itens:
			if it.feito or not vivo:
				continue
			var dentro: bool = h.pos.distance_squared_to(it.pos) <= it.raio * it.raio
			match str(it.s.gatilho):
				"encostar":
					if dentro:
						_achar(it)
				"parado":
					if dentro and quieto:
						it.t[h] = float(it.t.get(h, 0.0)) + dt
						if it.t[h] >= float(it.s.get("tempo", 3.0)):
							_achar(it)
					else:
						it.t.erase(h)
				"golpe":
					if dentro and _golpes(h) > int(antes.golpes):
						_achar(it)
		_maos[h] = {"golpes": _golpes(h), "ultima": h.pos, "emp": _emp(h)}


## O segredo se revela: onda e faíscas no ponto, o anúncio, a gravação no Códice e o baú.
func _achar(it: Dictionary) -> void:
	it.feito = true
	achados += 1
	var s: Dictionary = it.s
	var robo: bool = _mundo.roteiro != null and _mundo.roteiro.ativo()  # o robô não mexe em progresso nem save
	var novo: bool = false if robo else Meta.achar_segredo(str(s.id))
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

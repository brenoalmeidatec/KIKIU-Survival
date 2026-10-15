extends RefCounted
## Os heróis jogáveis da v2 (Hazaki, Nicão e Lucas): catálogo em dados/v2_herois.json, herói de cada personagem do salão (v2/personagens.gd) e a aplicação dos números do herói escolhido. Tudo estático, sem estado além de `forcado`.
##
## Como o herói entra na partida (sem espalhar `if` pelo combate):
##  - `cfg_para(base, id)`: o dados/v2_combate.json COPIADO e coberto pelo `cfg` do herói (vida, velocidade, fôlego, combo de golpes). O
##    combate guarda isto em `combate.cfg`, então o Meta.aplicar, o herói e o golpe leem o herói escolhido sem saber. O Hazaki repete os
##    números atuais e por isso não muda nada.
##  - `aplicar_bonus(mundo)`: bônus multiplicativos (área, dano, velocidade de ataque) e a sorte (soma em mundo.meta_bonus.raridade). Chamado
##    no fim de Meta.aplicar, que roda no começo e a cada recomeço da partida.
##  - O tipo de golpe vem do passo do combo: corte/estocada/batida/pancada (melee, combate.golpear) ou "adagas" (v2/adagas.gd).
## Escolha: `escolhido()` = `forcado` (testes e fotos) > `--heroi=id` na linha de comando > herói do personagem ativo (v2/personagens.gd, escolhido ao criá-lo; dados/v2_salao.json) > hazaki.

const PADRAO := "hazaki"

static var forcado := ""  # testes e fotos: vale no lugar do save e da linha de comando


static func catalogo() -> Dictionary:
	return Dados.json("v2_herois")


static func lista() -> Array:
	return catalogo().get("herois", [])


static func existe(id: String) -> bool:
	for h in lista():
		if str(h.id) == id:
			return true
	return false


## O registro do herói `id` (o padrão se não existir).
static func heroi(id: String) -> Dictionary:
	var primeiro := {}
	for h in lista():
		if primeiro.is_empty():
			primeiro = h
		if str(h.id) == id:
			return h
	return primeiro


static func escolhido() -> String:
	if forcado != "" and existe(forcado):
		return forcado
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--heroi=") and existe(a.trim_prefix("--heroi=")):
			return a.trim_prefix("--heroi=")
	var pers = load("res://v2/personagens.gd")  # load e não preload: o Meta chama este script (ciclo)
	var salvo := str(pers.heroi(pers.ativo())) if str(pers.ativo()) != "" else ""
	return salvo if existe(salvo) else PADRAO


## O nome da folha de sprites do herói; `basico` (--basico) usa o Hazaki sem armadura, como antes.
static func sprite(id: String, basico := false) -> String:
	if id == PADRAO and basico:
		return "hazaki"
	return str(heroi(id).sprite)


## `base` (o v2_combate.json) copiado e coberto pelo cfg do herói: dicionários se mesclam por chave, o resto (listas, números) substitui.
static func cfg_para(base: Dictionary, id: String) -> Dictionary:
	return mesclar(base.duplicate(true), heroi(id).get("cfg", {}))


static func mesclar(alvo: Dictionary, sobre: Dictionary) -> Dictionary:
	for k in sobre:
		if alvo.get(k) is Dictionary and sobre[k] is Dictionary:
			mesclar(alvo[k], sobre[k])
		else:
			alvo[k] = sobre[k].duplicate(true) if (sobre[k] is Array or sobre[k] is Dictionary) else sobre[k]
	return alvo


## Bônus do herói sobre os valores iniciais (Meta.aplicar já pôs as melhorias do santuário): área e velocidade de ataque são ABSOLUTAS
## (o herói acabou de ser zerado), o dano multiplica o que o santuário deu e a sorte soma na raridade.
static func aplicar_bonus(mundo) -> void:
	var h = mundo.heroi
	var b: Dictionary = heroi(str(mundo.combate.heroi_id)).get("bonus", {})
	h.m_area = float(b.get("area", 1.0))
	h.m_dano *= float(b.get("dano", 1.0))
	h.m_vel_ataque *= float(b.get("vel_ataque", 1.0))
	var mb: Dictionary = mundo.meta_bonus
	mb["raridade"] = float(mb.get("raridade", 0.0)) + float(b.get("sorte", 0.0))


## Os números que o santuário mostra: [[rótulo, texto]]. Saem do cfg do herói, então nunca desencontram do jogo.
static func numeros(id: String, base: Dictionary) -> Array:
	var cfg := cfg_para(base, id)
	var total := 0.0
	for p in cfg.golpe.passos:
		total += float(p.dano) * float(p.get("n", 1))
	return [
		["VIDA", str(roundi(float(cfg.heroi.vida)))],
		["VELOC.", str(roundi(float(cfg.heroi.vel)))],
		["COMBO", str(roundi(total))],
	]


## Números da legibilidade do herói no escuro (contorno, luz pessoal e arco do golpe): dados/v2_herois.json, "legibilidade".
static func legibilidade() -> Dictionary:
	return catalogo().get("legibilidade", {})

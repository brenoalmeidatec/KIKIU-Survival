extends RefCounted
## Crescimento das armas: arma fraca e pequena no nível 1, grande e cheia de efeitos no nível máximo (e na evolução).
## Os números moram em dados/crescimento_armas.json (veja o "_ajuda" de lá). Aqui ficam as contas (puras, testadas em
## testes/crescimento) e os ajudantes de desenho que TODO módulo de arma (scripts/hordas/armas/*.gd) pode chamar com o
## "tier" da arma: um número de 0 (nível 1-2) a 4 (evoluída). O armas.gd põe `tier` no `s` de cada arma e em cada efeito
## (e.tier), então um módulo novo ganha o crescimento do tamanho e do dano de graça e só escolhe os enfeites que quiser.

const ARQUIVO := "crescimento_armas"
const TIER_MAX := 4


static func cfg() -> Dictionary:
	return Dados.json(ARQUIVO)


static func nivel_max(id: String) -> int:
	return 1 + Dados.item(id).get("niveis", []).size()


## 0 (nível 1) a 1 (nível máximo): armas de 6 e de 7 níveis crescem na mesma proporção.
static func progresso(id: String, nivel: int) -> float:
	var m := nivel_max(id)
	return 0.0 if m <= 1 else clampf(float(nivel - 1) / float(m - 1), 0.0, 1.0)


## Interpolação linear numa lista de pontos [[p, valor], ...] (ordenada por p).
static func curva(pontos: Array, p: float) -> float:
	if pontos.is_empty():
		return 1.0
	if p <= float(pontos[0][0]):
		return float(pontos[0][1])
	for i in range(1, pontos.size()):
		var p1 := float(pontos[i][0])
		if p <= p1:
			var p0 := float(pontos[i - 1][0])
			return lerpf(float(pontos[i - 1][1]), float(pontos[i][1]), (p - p0) / maxf(0.0001, p1 - p0))
	return float(pontos[-1][1])


static func evoluida(id: String) -> bool:
	return bool(Dados.item(id).get("evolucao", false))


## Multiplicador de "area" ou "dano" da arma nesse nível. A arma pode trocar a curva com um bloco "crescimento" no armas.json.
static func mult(id: String, nivel: int, chave: String) -> float:
	var d := Dados.item(id)
	var ov: Dictionary = d.get("crescimento", {})
	if bool(ov.get("desligado", false)):
		return 1.0
	if bool(d.get("evolucao", false)):
		var ev: Dictionary = ov.get("evoluida", cfg().get("evoluida", {}))
		return float(ev.get(chave, 1.0))
	return curva(ov.get(chave, cfg().get(chave, [])), progresso(id, nivel))


## Faixa visual: 0 = nível 1-2, 1 = a partir do 3, 2 = a partir do 5, 3 = nível máximo, 4 = arma evoluída.
static func tier(id: String, nivel: int) -> int:
	if evoluida(id):
		return TIER_MAX
	var m := nivel_max(id)
	if m > 1 and nivel >= m:
		return 3
	var t := 0
	for n in cfg().get("tiers", {}).get("niveis", [3, 5]):
		if nivel >= int(n):
			t += 1
	return mini(t, 2)


## O que o tier acrescenta (cópia solta do json; faiscas/imagens/brasas já vêm multiplicados pelo perfil gráfico).
static func fx(t: int) -> Dictionary:
	var lista: Array = cfg().get("efeitos", [])
	if lista.is_empty():
		return {"faiscas": 0, "grossura": 1.0, "halo": 0.0, "tremor": 1.0, "brilho": 0.0, "imagens": 0, "brasas": 0, "arco_extra": false}
	return lista[clampi(t, 0, lista.size() - 1)]


## Quanto dos efeitos extras fica ligado (1 = tudo): vem do perfil gráfico (dados/graficos.json, chave arma_efeitos).
static func fator() -> float:
	return float(Config.g("efeitos_armas")) / 100.0


## Atributos da arma no nível (soma dos bônus de cada nível) com a curva de área e de dano por cima, sem os bônus do jogador.
## O jogo (armas.gd) e o cálculo de dano do duelo (construcao.gd) usam esta mesma conta, então os dois concordam.
static func atributos(id: String, nivel: int) -> Dictionary:
	var d := Dados.item(id)
	var s: Dictionary = d.get("base", {}).duplicate()
	var niveis: Array = d.get("niveis", [])
	for i in mini(nivel - 1, niveis.size()):
		for k in niveis[i]:
			s[k] = float(s.get(k, 0)) + float(niveis[i][k])
	s["area"] = float(s.get("area", 1.0)) * mult(id, nivel, "area")
	if s.has("dano"):
		s["dano"] = float(s.dano) * mult(id, nivel, "dano")
	return s


# ---------- desenho: os mesmos ajudantes servem a qualquer arma ----------

const COR_ELEMENTO := {"fogo": Color(1.0, 0.55, 0.2), "gelo": Color(0.65, 0.9, 1.0), "raio": Color(0.6, 0.85, 1.0), "veneno": Color(0.55, 0.9, 0.4)}


## Cor dos enfeites de uma arma: o "cor" do armas.json, senão a do elemento, senão um dourado claro.
static func cor_arma(d: Dictionary) -> Color:
	var c = d.get("cor")
	if c is Array and c.size() >= 3:
		return Color(float(c[0]), float(c[1]), float(c[2]))
	return COR_ELEMENTO.get(str(d.get("elemento", "")), Color(1.0, 0.9, 0.6))


## Cor mais viva a cada tier (mistura com branco).
static func cor(c: Color, t: int) -> Color:
	return c.lerp(Color(1, 1, 1, c.a), float(fx(t).get("brilho", 0.0)))


## Multiplicador da espessura de um traço (golpe, arco, trilha).
static func grossura(t: int) -> float:
	return float(fx(t).get("grossura", 1.0))


## Faíscas saindo de `pos` (no efeitos.gd, que já limita o total). `w` = o nó das armas.
static func fagulhas(w, pos: Vector2, dir: Vector2, c: Color, t: int, forca := 170.0) -> void:
	var n := int(round(float(fx(t).get("faiscas", 0)) * fator()))
	if n <= 0:
		return
	var ef = w.fx()
	if ef:
		ef.faisca(pos, dir, cor(c, t), n, forca)


## Tamanho aproximado de um efeito (dicionário em `especiais`) pra luz genérica: o raio que ele declara, ou 12 px x área se é
## uma coisa que voa (tem `vel`); 0 = não sei (o módulo cuida sozinho). Efeito esperando pra sair também fica sem luz.
static func raio_efeito(e: Dictionary) -> float:
	if float(e.get("espera", 0.0)) > 0.0:
		return 0.0
	if e.has("gatilho"):  # runa: a luz fica em volta do círculo dela, não do tamanho do estouro
		return float(e.gatilho) * 2.0
	for k in ["r", "raio", "explosao"]:
		if e.has(k):
			return float(e[k])
	return 12.0 * float(e.get("area", 1.0)) if e.has("vel") else 0.0


## Halo de luz aditivo (o efeitos.gd desenha e limpa a cada quadro: chame todo quadro que o efeito existir).
static func halo(w, pos: Vector2, raio: float, c: Color, t: int) -> void:
	var h := float(fx(t).get("halo", 0.0)) * fator()
	if h <= 0.0:
		return
	var ef = w.fx()
	if ef:
		ef.luz(pos, raio * (0.9 + 0.15 * h), Color(c, 0.2 * h))


## Força do tremor/congelada num acerto: o tier multiplica a que o módulo já pedia.
static func acerto(w, forca: float, t: int) -> void:
	w.golpe_acertou(forca * float(fx(t).get("tremor", 1.0)))


## Cópias fantasma de uma textura atrás dela (projétil, lâmina): `atras` = deslocamento de uma cópia pra próxima.
static func fantasmas(ci: CanvasItem, tex: Texture2D, pos: Vector2, ang: float, tam: Vector2, atras: Vector2, t: int, c := Color.WHITE) -> void:
	var n := int(round(float(fx(t).get("imagens", 0)) * fator()))
	for k in range(n, 0, -1):
		ci.draw_set_transform((pos - atras * k).floor(), ang, Vector2.ONE)
		ci.draw_texture_rect(tex, Rect2(-tam / 2, tam), false, Color(c, 0.32 / k))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Brasas: pontinhos que giram e sobem em volta de `pos`, posição só em função do tempo (sem estado, sem sorteio).
static func brasas(ci: CanvasItem, pos: Vector2, raio: float, c: Color, t: int, tempo: float, sem := 0.0, alfa := 1.0) -> void:
	var n := int(round(float(fx(t).get("brasas", 0)) * fator()))
	if n <= 0:
		return
	var cc := cor(c, t).lerp(Color(1.0, 0.85, 0.5), 0.35)
	for i in n:
		var fase := fmod(tempo * 0.7 + i * 0.618 + sem, 1.0)
		var ang := sem * 3.1 + TAU * i / n + tempo * (1.1 + 0.25 * (i % 3))
		var rr := raio * (0.45 + 0.5 * fmod(sem + i * 0.37, 1.0))
		var p := pos + Vector2(cos(ang) * rr, sin(ang) * rr * 0.6 - fase * 12.0)
		ci.draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(cc, (1.0 - fase) * alfa))


## Anel extra do tier alto (arco fino por fora do efeito), com `r` o raio do efeito.
static func anel(ci: CanvasItem, pos: Vector2, r: float, c: Color, t: int, alfa := 1.0, achata := 1.0) -> void:
	if not bool(fx(t).get("arco_extra", false)) or fator() < 0.5:
		return
	ci.draw_set_transform(pos.floor(), 0.0, Vector2(1.0, achata))
	ci.draw_arc(Vector2.ZERO, r * 1.12, 0.0, TAU, 28, Color(cor(c, t), 0.45 * alfa), 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

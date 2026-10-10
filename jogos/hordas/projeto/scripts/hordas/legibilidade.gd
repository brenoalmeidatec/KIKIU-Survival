extends RefCounted
## Legibilidade (#72 marco 7, #79): barra de vida de elite/chefe, etiqueta de drop e marca de área no chão.
## Só peças estáticas, sem estado: quem desenha é o nó dono (inimigos, coleta, armas) e o teste chama direto.
## Os números moram em dados/coletaveis.json > legibilidade; as cores, em Interface (respeitam o modo daltônico).
## Custo: nada disto roda por inimigo comum. A barra só olha `elite or chefe` numa passada que já existia; a etiqueta
## só olha os poucos itens do chão; a marca de área é uma por poça/aura/aviso.

const Interface := preload("res://scripts/hordas/interface.gd")
const ACHATA := 0.6   # o anel no chão é uma elipse (a mesma conta do aviso de #68 e das poças)


static func cfg() -> Dictionary:
	return Dados.json("coletaveis").get("legibilidade", {})


# ---------- barra de elite ----------

## A barra só existe para elite e chefe (os comuns morrem rápido demais para valer o desenho).
static func tem_barra(elite: bool, chefe: bool) -> bool:
	return elite or chefe


## Nome curto para cima da barra: cabe em ~14 letras (a fonte de pixel é larga).
static func nome_curto(nome: String) -> String:
	var n := nome.strip_edges()
	if n.length() <= 14:
		return n
	var p := n.split(" ")
	if p.size() > 1 and p[0].length() >= 3:
		var cur := p[0]
		for i in range(1, p.size()):
			if cur.length() + 1 + p[i].length() > 14:
				break
			cur += " " + p[i]
		if cur.length() <= 14:
			return cur
	return n.substr(0, 13) + "."


## O nome aparece só logo depois de um golpe (`seg` segundos); `t_golpe` é o relógio do desenho no último golpe.
static func mostra_nome(agora: float, t_golpe: float) -> bool:
	return agora - t_golpe < float(cfg().get("nome_seg", 2.5))


## Barra fina acima do bicho. `topo` = y da cabeça do sprite; `fr` = vida de 0 a 1.
static func barra(ci: CanvasItem, x: float, topo: float, larg: float, fr: float, chefe: bool) -> void:
	var w := roundf(clampf(larg, 18.0, 56.0))
	var x0 := roundf(x - w * 0.5)
	var y0 := roundf(topo) - 3.0   # os pips de elemento (elementos.gd) ficam logo acima: topo-10 a topo-5
	fr = clampf(fr, 0.0, 1.0)
	ci.draw_rect(Rect2(x0 - 1, y0 - 1, w + 2, 5), Color(0.05, 0.04, 0.08, 0.9))
	ci.draw_rect(Rect2(x0, y0, w, 3), Color(0.25, 0.05, 0.08))
	var cor: Color = Interface.cor("vida_chefe") if chefe else Interface.cor("destaque")
	ci.draw_rect(Rect2(x0, y0, maxf(1.0, roundf(w * fr)), 3), cor)


## Nome pequeno, com contorno escuro, em cima da barra.
static func nome_sobre(ci: CanvasItem, x: float, y: float, txt: String, a := 1.0) -> void:
	var f: Font = Dados.fonte
	var tam := tam_texto()
	var p := Vector2(roundf(x), roundf(y))
	var som := Color(0.05, 0.03, 0.08, a)
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		ci.draw_string(f, p + o, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, tam, som)
	ci.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, tam, Color(1, 0.95, 0.85, a))


## Tamanho do texto no chão: 8 (a fonte é de pixel de 8) ou 16 com "Texto do HUD: Grande".
static func tam_texto() -> int:
	return 16 if str(Config.v("texto_hud")) == "grande" else 8


# ---------- etiqueta de drop ----------

## Que etiqueta o item leva ({} = nenhuma). `valor` é o valor da gema (só a grande ganha etiqueta).
static func etiqueta(tipo: String, valor := 0.0) -> Dictionary:
	var e: Dictionary = cfg().get("etiquetas", {}).get(tipo, {})
	if e.is_empty() or valor < float(e.get("min_valor", 0.0)):
		return {}
	return e


## Regra de quando mostrar: nos primeiros `nasce` s do drop, ou com o herói a menos de `perto` px; fora disso, some.
static func etiqueta_visivel(e: Dictionary, idade: float, dist: float) -> bool:
	if e.is_empty():
		return false
	var c := cfg()
	if dist <= float(c.get("perto", 110.0)):
		return true
	return idade < float(c.get("nasce", 4.0)) and not bool(e.get("so_perto", false)) and dist < 420.0


## Cor do tipo (a chave vira Color já no modo daltônico) e ícone de forma + nome ao lado, tudo em lote.
static func desenhar_etiqueta(ci: CanvasItem, pos: Vector2, e: Dictionary, t: float, a := 1.0) -> void:
	var cor := Interface.cor(str(e.get("cor", "destaque")))
	var tam := tam_texto()
	var txt := str(e.get("nome", ""))
	var f: Font = Dados.fonte
	var larg := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var y := roundf(pos.y) - 22.0 - sin(t * 3.0) * 1.0
	var x := roundf(pos.x)
	var tot := larg + 14.0
	ci.draw_rect(Rect2(x - tot * 0.5 - 2, y - tam - 1, tot + 4, tam + 5), Color(0.05, 0.04, 0.08, 0.78 * a))
	ci.draw_rect(Rect2(x - tot * 0.5 - 2, y - tam - 1, tot + 4, 1), Color(cor, 0.9 * a))
	forma(ci, Vector2(x - tot * 0.5 + 4, y - tam * 0.5 + 1.0), str(e.get("forma", "circulo")), cor, a)
	var p := Vector2(x - tot * 0.5 + 12.0, y)
	ci.draw_string(f, p + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, a))
	ci.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(cor.lightened(0.35), a))


## Ícone de forma de 5 px: quem não distingue cor distingue a forma.
static func forma(ci: CanvasItem, c: Vector2, nome: String, cor: Color, a := 1.0) -> void:
	var k := Color(cor, a)
	match nome:
		"quadrado":
			ci.draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), k)
		"cruz":
			ci.draw_rect(Rect2(c - Vector2(1, 3), Vector2(3, 7)), k)
			ci.draw_rect(Rect2(c - Vector2(3, 1), Vector2(7, 3)), k)
		"triangulo":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 3), c + Vector2(-4, 3)]), k)
		"losango":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]), k)
		_:
			ci.draw_circle(c, 3.5, k)


# ---------- marca de área ----------

## Cor do perigo (o vermelho do aviso de #68; laranja no modo daltônico) e da área aliada (azul, mais discreta).
static func cor_perigo() -> Color:
	return Interface.cor("perigo")


static func cor_aliada() -> Color:
	return Interface.cor("area_aliada")


## Anel de aviso de um perigo que AINDA VAI acontecer (elipse no chão). `u` = 0..1, quanto falta pouco: engrossa e acende.
## O desenhista já está nas coordenadas do mundo; a elipse usa uma transformação própria e volta ao normal no fim.
static func marca_perigo(ci: CanvasItem, centro: Vector2, raio: float, u: float) -> void:
	var c := cor_perigo()
	ci.draw_set_transform(centro, 0, Vector2(1, ACHATA))
	ci.draw_circle(Vector2.ZERO, raio, Color(c, 0.05 + 0.09 * u))
	ci.draw_arc(Vector2.ZERO, raio, 0, TAU, 32, Color(c, 0.25 + 0.55 * u), 2.0)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## Borda de uma área do herói (poça, aura): fina, translúcida, de outra cor, sem preenchimento (não disputa com o aviso).
## `viva` = 0..1 de quanto ainda dura (esmaece no fim). `explode` = a área vai explodir logo: pulsa mais.
static func marca_aliada(ci: CanvasItem, centro: Vector2, raio: float, viva := 1.0, explode := false, t := 0.0, achatada := true) -> void:
	var c := cor_aliada()
	var a := (0.3 + (0.2 + 0.15 * sin(t * 12.0) if explode else 0.0)) * clampf(viva, 0.0, 1.0)
	ci.draw_set_transform(centro, 0, Vector2(1, ACHATA if achatada else 1.0))
	ci.draw_arc(Vector2.ZERO, raio, 0, TAU, 32, Color(c, a), 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


# ---------- objetivos acima da horda (#123, #125) ----------
## Objetivo, altar, portal de saída e baú se leem primeiro: ficam numa camada acima (z_index 50), efeitos e baús ficam a 40% de
## opacidade quando estão em cima de um alvo, o baú nunca nasce colado num alvo e quem está fora da tela ganha seta na borda.

const BAU_MIN := 96.0       # px: baú nasce pelo menos isso longe de qualquer alvo
const SOBRE_RAIO := 40.0    # px: efeito/baú a menos disso do centro de um alvo está "em cima" dele
const SOBRE_ALFA := 0.4     # opacidade de efeitos e baús em cima de um alvo
const ALVOS_MAX := 8        # o shader da camada guarda no máximo isso


## Posições (mundo) de tudo que é "alvo": objetivo do andar, objetivo da missão do chefe (fragmentos, altar) e portal de saída.
static func alvos(arena) -> Array:
	var r: Array = []
	if arena == null:
		return r
	if arena.get("objetivo") != null and arena.objetivo.ativo():
		r.append_array(arena.objetivo.marcas)
	if arena.get("missao") != null and arena.missao.ativo():
		r.append_array(arena.missao.marcas())
	if arena.get("saida") != null and arena.saida.aberta and not arena.saida.pronto:
		r.append(arena.saida.pos)
	return r


static func sobre_alvo(p: Vector2, lista: Array, raio := SOBRE_RAIO) -> bool:
	for a in lista:
		if p.distance_to(a) < raio:
			return true
	return false


## 1.0 normal; 0.4 quando o ponto está em cima de um alvo.
static func alfa_sobre(p: Vector2, lista: Array, raio := SOBRE_RAIO) -> float:
	return SOBRE_ALFA if sobre_alvo(p, lista, raio) else 1.0


## Empurra `p` pra fora do raio mínimo de cada alvo (o baú não cobre o marcador).
static func longe_dos_alvos(p: Vector2, lista: Array, minimo := BAU_MIN) -> Vector2:
	for _i in 3:   # empurrar de um alvo pode encostar em outro
		var mexeu := false
		for a in lista:
			var d: Vector2 = p - a
			if d.length() < minimo:
				p = a + (d.normalized() if d.length() > 0.5 else Vector2.RIGHT) * minimo
				mexeu = true
		if not mexeu:
			break
	return p


## Seta na borda da tela para um alvo fora dela. `rel` = alvo - centro da câmera. Devolve {} se está na tela, senão
## {p (ponto na borda), dir, metros}. 10 px do mundo = 1 m, a mesma conta das setas do HUD.
static func seta_borda(rel: Vector2, tela: Vector2, margem := 22.0, folga := 10.0) -> Dictionary:
	if absf(rel.x) <= tela.x * 0.5 - folga and absf(rel.y) <= tela.y * 0.5 - folga:
		return {}
	var dir := rel.normalized()
	var k := minf((tela.x * 0.5 - margem) / maxf(absf(dir.x), 0.01), (tela.y * 0.5 - margem) / maxf(absf(dir.y), 0.01))
	return {"p": tela * 0.5 + dir * k, "dir": dir, "metros": int(rel.length() / 10.0)}

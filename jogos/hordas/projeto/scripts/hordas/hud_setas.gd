extends Control
## Setas na borda da tela do HUD: chefe fora da tela (com a distância em metros), tomada mais perto, santuários
## ainda não usados, alvos do objetivo e da missão do chefe, rivais do duelo final. É a única parte do HUD que é
## desenho puro (triângulo na borda) em vez de nó de cena; o texto da distância usa a fonte do Theme.

const W := 640.0
const H := 360.0
const Interface := preload("res://scripts/hordas/interface.gd")
const Descobertas := preload("res://scripts/hordas/descobertas.gd")

var arena: Node
var t := 0.0


func _txt(p: Vector2, s: String, cor: Color, larg: float) -> void:
	var f := get_theme_default_font()
	var tam := get_theme_default_font_size()
	draw_string(f, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_CENTER, larg, tam, Color(0, 0, 0, cor.a * 0.8))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_CENTER, larg, tam, cor)


## Ponto na borda da tela na direção de `pos` (mundo), a `margem` px da beirada; null se `pos` está visível.
## Devolve {p, dir, rel}.
func borda(pos: Vector2, margem: float, folga := 10.0):
	var rel: Vector2 = pos - arena.camera.position
	if absf(rel.x) <= W / 2 - folga and absf(rel.y) <= H / 2 - folga:
		return null
	var dir := rel.normalized()
	var p := Vector2(W / 2, H / 2) + dir * minf((W / 2 - margem) / maxf(absf(dir.x), 0.01), (H / 2 - margem) / maxf(absf(dir.y), 0.01))
	return {"p": p, "dir": dir, "rel": rel}


func _seta(b: Dictionary, ponta: float, lado: float, cor: Color) -> void:
	var p: Vector2 = b.p
	var d: Vector2 = b.dir
	draw_colored_polygon(
		PackedVector2Array([p + d * ponta, p + d.orthogonal() * lado - d * (ponta * 0.45), p - d.orthogonal() * lado - d * (ponta * 0.45)]), cor
	)


## Seta com miolo escuro (vira um contorno e se destaca de qualquer fundo) e a distância em metros (px/10).
func _seta_alvo(b: Dictionary, cor: Color, pulso: float, grande := 12.0, lado := 8.0) -> void:
	_seta(b, grande, lado, Color(cor, pulso))
	_seta(b, grande * 0.55, lado * 0.5, Color(0.08, 0.04, 0.1, 0.8))
	_txt(b.p - b.dir * 24.0 - Vector2(20, -3), tr("HUD_METROS") % int(b.rel.length() / 10.0), Color(cor, pulso), 40)


func _draw() -> void:
	if arena == null or arena.jogador == null or arena.camera == null:
		return
	if arena.duelo_ativo:
		_duelo()
		return
	_dicas_santuario()
	_objetivo_missao()
	var chefes: Array = arena.chefes()
	for k in mini(chefes.size(), 2):
		var b = borda(chefes[k].pos, 22.0)
		if b != null:
			_seta_alvo(b, Interface.cor("alerta"), 0.7 + 0.3 * sin(t * 8))
	var s = arena.chao.mais_perto_livre(arena.jogador.position)
	if s:
		var bs = borda(s.pos, 24.0)
		if bs != null:
			var pulso := 0.6 + 0.4 * sin(t * 5)
			_seta(bs, 9.0, 6.0, Color(1, 0.85, 0.3, pulso))
			draw_texture_rect(
				Dados.tex(str(Descobertas.cfg().get("santuarios", {}).get("sprite", "tomada"))),
				Rect2(bs.p - bs.dir * 18 - Vector2(8, 9), Vector2(16, 18)),
				false,
				Color(1, 1, 1, pulso)
			)


## Indicação sutil (seção 21): uma setinha fraca na borda apontando santuário especial que ainda não foi usado.
func _dicas_santuario() -> void:
	for s in arena.chao.santuarios:
		if s.usado or s.tipo == "tomada":
			continue
		var b = borda(s.pos, 18.0, 14.0)
		if b == null:
			continue
		var cor: Color = arena.chao.COR_TIPO.get(s.tipo, Color.WHITE)
		_seta(b, 8.0, 5.0, Color(cor, 0.3 + 0.2 * sin(t * 3.0)))


func _objetivo_missao() -> void:
	var ob = arena.objetivo
	if ob != null and ob.visivel() and ob.est == ob.ANDAMENTO:
		for p in ob.marcas:
			var b = borda(p, 22.0)
			if b != null:
				_seta_alvo(b, ob.cor_de(ob.id), 0.65 + 0.35 * sin(t * 6.0), 11.0, 7.0)
	var ms = arena.missao
	if ms != null and ms.visivel() and ms.est == ms.ANDAMENTO:
		for p in ms.marcas():
			var b = borda(p, 22.0)
			if b != null:
				_seta_alvo(b, ms.cor_de(ms.id), 0.65 + 0.35 * sin(t * 6.0), 11.0, 7.0)


func _duelo() -> void:
	var d: Node2D = arena.duelo
	for l in d.vivos():
		if l.jogador:
			continue
		var cor: Color = l.cor
		var b = borda(l.pos, 26.0, 14.0)
		if b != null:
			_seta(b, 10.0, 6.0, cor)
			var hf: float = d._hp_frac(l)
			draw_rect(Rect2(b.p - b.dir * 14 - Vector2(10, 2), Vector2(20, 4)), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(b.p - b.dir * 14 - Vector2(9, 1), Vector2(18 * hf, 2)), cor)

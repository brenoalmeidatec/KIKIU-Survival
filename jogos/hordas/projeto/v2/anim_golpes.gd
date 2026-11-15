extends RefCounted
## Folhas animadas dos golpes secundários (projéteis, meteoros, anéis e nuvens): tiras horizontais em `assets/v2/armas_anim/`, descritas
## pelos `indice_<grupo>.json` da mesma pasta. O contrato da arte (tamanhos, âncora, fps, nomes) está em docs/combate_v2/SPEC_ARTE.md.
## Tudo é estático e lido uma vez por processo (as folhas de arma de carta só quando a arma aparece, ver GRUPOS_JA): cada arma aponta para um dicionário {nome da animação -> folha}, e cada folha é
## {tex, quadro (Vector2), n, fps, loop, ancora (Vector2), gira}. O desenho escolhe o quadro pelo tempo (`quadro_em`) ou pelo progresso
## da fase (`quadro_frac`) e desenha a região da tira (`desenhar`), sem nó nem alocação por quadro.
## Arma sem folha devolve {} e o golpe segue com o desenho antigo (armas_novas.gd).

const PixelRot := preload("res://v2/pixel_rot.gd")
const SpriteGiro := preload("res://v2/sprite_giro.gd")
const PASTA := "res://assets/v2/armas_anim/"
const GRUPOS := ["projeteis", "meteoros", "aneis", "nuvens", "evo_projeteis", "evo_met_aneis", "evo_nuvens", "magias", "martelo", "perigo", "pixelfx"]  # os índices lidos (lista fixa: listar res:// não serve no jogo exportado)

static var _armas := {}
static var _specs := {}  # arma -> a entrada do índice ({anims: ...}), ainda sem textura: `de` carrega na primeira vez
static var _lidas := false
## Os grupos que carregam tudo de uma vez em `carregar()`: os pequenos e os que não dependem de carta (perigo dos inimigos, magias, as
## adagas `_heroi`). As folhas de arma de carta (meteoro, anel, nuvem, evoluções e pixelfx) só carregam quando a arma entra no jogo
## (armas_novas.preparar_giros, na escolha da carta) ou na fila de aquecimento da tela de cartas (armas_novas.pedir_aquecer): ~41 MB de
## textura a menos na carga da partida. Os `fx_*` e o `raio` (impactos que qualquer golpe toca) também carregam já.
const GRUPOS_JA := ["projeteis", "magias", "martelo", "perigo"]
const IDS_JA := ["raio"]
## Quadros intermediários (#golpes-suaves): `desenhar_suave` funde o quadro atual com o próximo pela fração do tempo, e a folha de 6 a
## 12 quadros parece ter o dobro. Custa uma chamada de desenho a mais por golpe; a partida desliga com partículas em "nenhuma"/"poucas".
static var suave := true


## Lê os índices. As folhas dos grupos de GRUPOS_JA, dos `fx_*` e de IDS_JA carregam aqui; o resto fica só anotado até `de(id)`.
static func carregar() -> void:
	if _lidas:
		return
	_lidas = true
	for g in GRUPOS:
		var caminho: String = PASTA.path_join("indice_%s.json" % g)
		if not FileAccess.file_exists(caminho):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(caminho))
		if not (d is Dictionary):
			continue
		for nome in d.get("folhas", {}):
			var f: Dictionary = d.folhas[nome]
			if (f.get("anims", {}) as Dictionary).is_empty():
				continue
			for arma in f.get("armas", []):
				var id := str(arma)
				_specs[id] = f
				if GRUPOS_JA.has(g) or id.begins_with("fx_") or IDS_JA.has(id):
					_montar(id)


## Carrega as texturas da arma `id` (a partir do índice já lido) e guarda em _armas. A folha que falha fica de fora.
static func _montar(id: String) -> Dictionary:
	var f: Dictionary = _specs.get(id, {})
	var anims := {}
	for an in f.get("anims", {}):
		var s: Dictionary = f.anims[an]
		var tex := load(PASTA.path_join(str(s.arquivo))) as Texture2D
		if tex == null:
			continue
		var q := Vector2(float(s.quadro[0]), float(s.quadro[1]))
		var anc: Array = s.get("ancora", [q.x * 0.5, q.y * 0.5])
		anims[str(an)] = {
			"tex": tex,
			"quadro": q,
			"n": maxi(int(s.n), 1),
			"fps": maxf(float(s.fps), 1.0),
			"loop": bool(s.get("loop", false)),
			"ancora": Vector2(float(anc[0]), float(anc[1])),
			"gira": bool(s.get("gira", false))
		}
	_armas[id] = anims
	return anims


## As animações da arma `id` ({nome -> folha}), ou {} quando ela não tem folha animada. A primeira chamada de uma arma de carta carrega
## as folhas dela (de 0,1 a 2 MB): quem conhece a arma antes do golpe chama aqui na escolha da carta (preparar_giros, pedir_aquecer).
static func de(id: String) -> Dictionary:
	carregar()
	var a = _armas.get(id)
	if a != null:
		return a
	if not _specs.has(id):
		return {}
	return _montar(id)


## true quando as folhas da arma `id` já estão na memória (ou ela não tem folha): a fila de aquecimento pula o que não falta.
static func pronta(id: String) -> bool:
	carregar()
	return _armas.has(id) or not _specs.has(id)


## Os ids de todas as armas com folha animada (lidos dos índices, sem carregar textura).
static func ids() -> Array:
	carregar()
	return _specs.keys()


## Duração (s) de uma passada da folha.
static func duracao(f: Dictionary) -> float:
	return float(f.n) / float(f.fps)


## O quadro depois de `t` segundos: em loop dá a volta; sem loop trava no último.
static func quadro_em(f: Dictionary, t: float) -> int:
	var i := int(maxf(t, 0.0) * float(f.fps))
	if bool(f.loop):
		return i % int(f.n)
	return mini(i, int(f.n) - 1)


## O quadro pelo progresso `k` (0 a 1) de uma fase do golpe (o anel abrindo até o raio, a nuvem se formando).
static func quadro_frac(f: Dictionary, k: float) -> int:
	return clampi(int(clampf(k, 0.0, 0.9999) * float(f.n)), 0, int(f.n) - 1)


## Gera as cópias pré-giradas da folha `f` (22,5, 45 e 67,5 graus; ver sprite_giro.gd) para o `desenhar` com ângulo achar tudo pronto.
## Chame ao carregar a arma, não no meio da partida. Sem efeito se já gerou.
static func preparar_giro(f: Dictionary) -> void:
	var q: Vector2 = f.quadro
	SpriteGiro.preparar(f.tex, Vector2i(q), Vector2i(f.ancora as Vector2), int(f.n))


## Desenha o quadro `i` com a âncora em `pos`, apontando para `ang` e com `escala` (a folha de área estica até o raio real do golpe).
## Pixel art não gira livre (pixel_rot.gd): `ang` vira uma das 16 direções, a mais próxima: múltiplos de 90 graus por transformação exata e os
## outros por cópia pré-girada da folha (sprite_giro.gd). Com `escala` diferente de 1, só escala uniforme pode acompanhar um ângulo.
static func desenhar(ci: CanvasItem, f: Dictionary, i: int, pos: Vector2, ang := 0.0, escala := Vector2.ONE, cor := Color.WHITE) -> void:
	var q: Vector2 = f.quadro
	if PixelRot.direcao16(ang) != Vector2i.ZERO:
		SpriteGiro.desenhar(ci, f.tex, Vector2i(q), Vector2i(f.ancora as Vector2), int(f.n), i, pos, ang, escala, cor)
		return
	ci.draw_set_transform(pos.round(), 0.0, escala)
	ci.draw_texture_rect_region(f.tex, Rect2(-(f.ancora as Vector2), q), Rect2(Vector2(q.x * float(i), 0.0), q), cor)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## O quadro depois de `t` segundos, com a fração (3.4 = 40% do caminho entre o quadro 3 e o 4). Sem loop trava no último.
static func quadro_em_f(f: Dictionary, t: float) -> float:
	var x := maxf(t, 0.0) * float(f.fps)
	var n := float(f.n)
	if bool(f.loop):
		return fmod(x, n)
	return minf(x, n - 1.0)


## O quadro pelo progresso `k` (0 a 1), com a fração: o último quadro chega junto com o fim da fase.
static func quadro_frac_f(f: Dictionary, k: float) -> float:
	return clampf(k, 0.0, 1.0) * (float(f.n) - 1.0)


## Desenha o quadro fracionário `qf` fundindo o quadro de baixo com o próximo (o "meio-quadro" que a folha não tem). Na camada aditiva
## (`aditivo`) os pesos somam 1 e o brilho não pisca; na normal o de baixo some mais devagar (1 - u²) para o corpo não ficar ralo no meio.
## Sem `suave`, ou com a fração quase inteira, é o `desenhar` de sempre.
static func desenhar_suave(
	ci: CanvasItem, f: Dictionary, qf: float, pos: Vector2, ang := 0.0, escala := Vector2.ONE, cor := Color.WHITE, aditivo := false
) -> void:
	var n := int(f.n)
	var i := clampi(int(floorf(qf)), 0, n - 1)
	var u := qf - float(i)
	var j := (i + 1) % n if bool(f.loop) else mini(i + 1, n - 1)
	if not suave or u < 0.06 or j == i:
		desenhar(ci, f, i, pos, ang, escala, cor)
		return
	if u > 0.94:
		desenhar(ci, f, j, pos, ang, escala, cor)
		return
	var c0 := cor
	var c1 := cor
	c0.a *= (1.0 - u) if aditivo else (1.0 - u * u)
	c1.a *= u
	desenhar(ci, f, i, pos, ang, escala, c0)
	desenhar(ci, f, j, pos, ang, escala, c1)

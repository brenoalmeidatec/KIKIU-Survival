extends RefCounted
## Folhas animadas dos golpes secundários (projéteis, meteoros, anéis e nuvens): tiras horizontais em `assets/v2/armas_anim/`, descritas
## pelos `indice_<grupo>.json` da mesma pasta. O contrato da arte (tamanhos, âncora, fps, nomes) está em docs/combate_v2/SPEC_ARTE.md.
## Tudo é estático e lido uma vez por processo: cada arma aponta para um dicionário {nome da animação -> folha}, e cada folha é
## {tex, quadro (Vector2), n, fps, loop, ancora (Vector2), gira}. O desenho escolhe o quadro pelo tempo (`quadro_em`) ou pelo progresso
## da fase (`quadro_frac`) e desenha a região da tira (`desenhar`), sem nó nem alocação por quadro.
## Arma sem folha devolve {} e o golpe segue com o desenho antigo (armas_novas.gd).

const PASTA := "res://assets/v2/armas_anim/"
const GRUPOS := ["projeteis", "meteoros", "aneis", "nuvens", "evo_projeteis", "evo_met_aneis", "evo_nuvens", "magias"]  # os índices lidos (lista fixa: listar res:// não serve no jogo exportado)

static var _armas := {}
static var _lidas := false


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
			if anims.is_empty():
				continue
			for arma in f.get("armas", []):
				_armas[str(arma)] = anims


## As animações da arma `id` ({nome -> folha}), ou {} quando ela não tem folha animada.
static func de(id: String) -> Dictionary:
	carregar()
	return _armas.get(id, {})


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


## Desenha o quadro `i` com a âncora em `pos`, girado `ang` e com `escala` (a folha de área estica até o raio real do golpe).
static func desenhar(ci: CanvasItem, f: Dictionary, i: int, pos: Vector2, ang := 0.0, escala := Vector2.ONE, cor := Color.WHITE) -> void:
	var q: Vector2 = f.quadro
	ci.draw_set_transform(pos.round(), ang, escala)
	ci.draw_texture_rect_region(f.tex, Rect2(-(f.ancora as Vector2), q), Rect2(Vector2(q.x * float(i), 0.0), q), cor)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

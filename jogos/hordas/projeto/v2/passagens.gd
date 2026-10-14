extends RefCounted
## Lógica de caminho e passagens da v2 (genérica: serve à floresta, ao laboratório e ao futuro mapa Cidade).
## Rasteriza a área andável numa grade de navegação (células de CELULA px) usando as MESMAS formas de colisão do jogo
## (`Colisao.livre`) e responde: de onde dá para chegar a onde, onde há corredor estreito demais e onde há beco sem saída.
## `grade(limite, raio)` constrói; `alcancaveis(g, origem)` marca o que se alcança andando; `bolsoes(g, origem)` lista os trechos livres
## que NÃO se alcançam (ilhas fechadas); `becos(g)` marca as células de pontas mortas finas (corredor de 1 célula que termina em nada).
## O teste v2_mapas roda isso em cada mapa; o gerador de mapas e quem edita o JSON usam `relatorio` para achar o que desobstruir.

const Colisao := preload("res://v2/colisao.gd")
const CELULA := 16.0
const RAIO_HEROI := 7.0  # corpo do herói (e do monstro comum)
const RAIO_HORDA := 14.0  # corpo largo (elite, chefe pequeno): a passagem tem de caber ele também


## Grade de células livres para um corpo redondo de `raio`. g.livre[y * w + x] = 1 se o círculo no centro da célula não toca forma sólida.
static func grade(limite: Rect2, raio: float, celula := CELULA) -> Dictionary:
	var w := int(ceil(limite.size.x / celula))
	var h := int(ceil(limite.size.y / celula))
	var livre := PackedByteArray()
	livre.resize(w * h)
	for y in h:
		for x in w:
			var p := limite.position + Vector2((x + 0.5) * celula, (y + 0.5) * celula)
			livre[y * w + x] = 1 if Colisao.livre(p, raio) else 0
	return {"w": w, "h": h, "celula": celula, "origem": limite.position, "livre": livre, "raio": raio}


static func celula_de(g: Dictionary, pos: Vector2) -> Vector2i:
	var c: Vector2 = (pos - g.origem) / float(g.celula)
	return Vector2i(clampi(int(floor(c.x)), 0, int(g.w) - 1), clampi(int(floor(c.y)), 0, int(g.h) - 1))


static func centro_da_celula(g: Dictionary, c: Vector2i) -> Vector2:
	return g.origem + Vector2((c.x + 0.5) * float(g.celula), (c.y + 0.5) * float(g.celula))


## Célula livre mais próxima de `pos` (a própria, se livre), numa busca em anéis. Vector2i(-1, -1) se não há nenhuma.
static func livre_perto(g: Dictionary, pos: Vector2, max_aneis := 8) -> Vector2i:
	var c := celula_de(g, pos)
	var w: int = g.w
	var h: int = g.h
	var livre: PackedByteArray = g.livre
	for a in range(0, max_aneis + 1):
		for dy in range(-a, a + 1):
			for dx in range(-a, a + 1):
				if maxi(absi(dx), absi(dy)) != a:
					continue
				var x := c.x + dx
				var y := c.y + dy
				if x >= 0 and y >= 0 and x < w and y < h and livre[y * w + x] == 1:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


## Preenchimento (8 vizinhos, sem cortar quina de forma sólida) a partir de `origem`. Devolve a máscara das células alcançadas.
static func alcancaveis(g: Dictionary, origem: Vector2) -> PackedByteArray:
	var w: int = g.w
	var h: int = g.h
	var livre: PackedByteArray = g.livre
	var vis := PackedByteArray()
	vis.resize(w * h)
	var c0 := livre_perto(g, origem)
	if c0.x < 0:
		return vis
	var fila: Array[Vector2i] = [c0]
	vis[c0.y * w + c0.x] = 1
	var i := 0
	while i < fila.size():
		var c := fila[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var x: int = c.x + d.x
			var y: int = c.y + d.y
			if x < 0 or y < 0 or x >= w or y >= h or vis[y * w + x] == 1 or livre[y * w + x] == 0:
				continue
			if d.x != 0 and d.y != 0 and (livre[c.y * w + x] == 0 or livre[y * w + c.x] == 0):
				continue  # diagonal só com os dois lados livres
			vis[y * w + x] = 1
			fila.append(Vector2i(x, y))
	return vis


static func contar(m: PackedByteArray) -> int:
	var n := 0
	for v in m:
		n += v
	return n


## Trechos livres que não se alcançam a partir de `origem` (ilhas): lista de {n, centro} com mais de `min_celulas` células.
static func bolsoes(g: Dictionary, origem: Vector2, min_celulas := 12) -> Array:
	var w: int = g.w
	var h: int = g.h
	var livre: PackedByteArray = g.livre
	var vis := alcancaveis(g, origem)
	var visto := vis.duplicate()
	var saida: Array = []
	for y0 in h:
		for x0 in w:
			if livre[y0 * w + x0] == 0 or visto[y0 * w + x0] == 1:
				continue
			var fila: Array[Vector2i] = [Vector2i(x0, y0)]
			visto[y0 * w + x0] = 1
			var i := 0
			var soma := Vector2.ZERO
			while i < fila.size():
				var c := fila[i]
				i += 1
				soma += centro_da_celula(g, c)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var x: int = c.x + d.x
					var y: int = c.y + d.y
					if x < 0 or y < 0 or x >= w or y >= h or visto[y * w + x] == 1 or livre[y * w + x] == 0:
						continue
					visto[y * w + x] = 1
					fila.append(Vector2i(x, y))
			if fila.size() >= min_celulas:
				saida.append({"n": fila.size(), "centro": soma / float(fila.size())})
	return saida


## Pontas mortas finas: poda, uma camada por vez, as células com 1 vizinho livre ou menos (4 vizinhos) e conta o que sobra podado.
## É o corredor de uma célula que entra e não sai (o monstro que persegue pela frente trava nele). `max_prof` = profundidade da poda.
static func becos(g: Dictionary, max_prof := 6) -> Array[Vector2i]:
	var w: int = g.w
	var h: int = g.h
	var m: PackedByteArray = g.livre.duplicate()
	var podadas: Array[Vector2i] = []
	for _r in max_prof:
		var tirar: Array[Vector2i] = []
		for y in h:
			for x in w:
				if m[y * w + x] == 0:
					continue
				var viz := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var xx: int = x + d.x
					var yy: int = y + d.y
					if xx >= 0 and yy >= 0 and xx < w and yy < h and m[yy * w + xx] == 1:
						viz += 1
				if viz <= 1:
					tirar.append(Vector2i(x, y))
		if tirar.is_empty():
			break
		for c in tirar:
			m[c.y * w + c.x] = 0
			podadas.append(c)
	return podadas


## Resumo de um mapa para o teste e para quem edita: células livres, alcançadas, ilhas, becos e se cada ponto de `pontos` é alcançado.
static func relatorio(limite: Rect2, origem: Vector2, pontos: Array, raio := RAIO_HEROI) -> Dictionary:
	var g := grade(limite, raio)
	var vis := alcancaveis(g, origem)
	var n_livre := contar(g.livre)
	var fora: Array = []
	for p in pontos:
		var c := livre_perto(g, p, 4)
		if c.x < 0 or vis[c.y * int(g.w) + c.x] == 0:
			fora.append(p)
	return {
		"livres": n_livre,
		"alcancadas": contar(vis),
		"bolsoes": bolsoes(g, origem),
		"becos": becos(g).size(),
		"pontos_fora": fora,
		"grade": g,
	}

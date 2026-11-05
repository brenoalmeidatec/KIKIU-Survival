extends RefCounted
## Os PROPULSORES NAS COSTAS do mecha do LightWolf durante o impulso (pedido do Alisson, 05/11, rodada 6: "gere animação de propulsores nas costas também ao
## usar impulso"). Dois jatos em pixel art saem da mochila do mecha enquanto ele voa (Heroi.imp_t > 0) e somem no chão. SÓ VISUAL: dois Sprite2D fixos (um por
## jato, criados uma vez e reaproveitados; nenhum nó por efeito), filhos da raiz do herói, sem colisão, luz, partícula nem RNG. As chamas são desenhadas em código
## (nenhum arquivo de imagem), em textura guardada por inclinação, força e quadro; alfa só 0 ou 1, posições inteiras, nada gira (a inclinação é um cisalhamento
## em degraus de 1 px, linha por linha).
##  - NAS 8 DIREÇÕES: o jato aponta para baixo na tela e se inclina para o lado contrário ao que o mecha olha (para trás e para baixo, como a mochila): olhando para
##    a direita a chama cai para baixo à esquerda. A mochila fica nas costas: com o mecha olhando para baixo (baixo, baixo-esq, baixo-dir) ela está longe da câmera e
##    a chama é desenhada ATRÁS do corpo; olhando para cima e para os lados, na frente dele (a ordem é o y do nó no y-sort do herói, 1 px antes ou depois do
##    corpo, e a posição na árvore da raiz fora do y-sort: as duas dão a mesma resposta).
##  - FORÇA (Impulso.forca): 2 na decolagem (chama longa e larga), 1 no cruzeiro, 0 na descida (curta).
##  - CICLO de 4 quadros, a mesma chama com um "caroço" de largura que desce de um quadro para o outro e o comprimento variando 1 a 2 px: só a FORMA muda, as cores
##    ficam fixas. Com "Reduzir piscadas" o ciclo inteiro dura 0,5 s reais (2 Hz), e o brilho não liga nem desliga em nenhum caso. Perfil Baixo (e Brilhos e halos em
##    0%): uma chama simples e parada, 1 quadro por força, sem caroço.
## Os números (altura da mochila, afastamento, comprimentos e larguras por força, duração dos quadros) vêm de dados/v2_herois.json > lightwolf > impulso > propulsor.

const Foguinho := preload("res://v2/foguinho.gd")
const Piscadas := preload("res://v2/piscadas.gd")
const QUADROS := 4
const METADE := 24  # a textura tem 2 x 24 + 1 px de largura: o jato sai do topo, no pixel do meio
const ALTURA := 48
const ACHATA := 0.7071  # o eixo y do chão aparece comprimido pelos 45 graus da câmera (o mesmo de v2/sombras.gd)
const BRANCO := Color(0.93, 1.0, 1.0)
const CIANO := Color(0.62, 0.93, 1.0)
const AZUL := Color(0.31, 0.60, 0.88)
const ESCURO := Color(0.12, 0.20, 0.40)
const DIRS := {
	"baixo": Vector2(0, 1),
	"cima": Vector2(0, -1),
	"esquerda": Vector2(-1, 0),
	"direita": Vector2(1, 0),
	"baixo_esq": Vector2(-0.7071, 0.7071),
	"baixo_dir": Vector2(0.7071, 0.7071),
	"cima_esq": Vector2(-0.7071, -0.7071),
	"cima_dir": Vector2(0.7071, -0.7071),
}
const PADRAO := {
	"altura": 18.0,  # px acima dos pés em que a boca do jato sai da mochila
	"recuo": 7.0,  # px para trás do centro do corpo (no chão)
	"lado": 15.0,  # px para cada lado do centro (no chão)
	"abre": 0.1,  # inclinação a mais para fora de cada jato (uma chama para cada lado, não duas coladas)
	"atras_altura": 8.0,  # olhando para baixo a boca sai mais baixa (a mochila está atrás do corpo): a chama aparece abaixo dos blocos do tronco
	"atras_abre": 0.3,  # o mesmo, olhando para baixo: a chama abre para os lados para aparecer ao lado das pernas, atrás do corpo
	"atras_comp": 1.4,  # e fica mais longa (vezes), para a ponta passar da base do corpo
	"comp": [12, 22, 30],  # comprimento da chama (px) por força: descida, cruzeiro, decolagem
	"larg": [3, 5, 6],  # meia largura na boca
	"decolagem_s": 0.5,
	"quadro_s": 0.075,  # s de jogo por quadro (0,06 s reais a 1,25x)
	"quadro_lento_s": 0.15625,  # com "Reduzir piscadas": 0,125 s reais por quadro, o ciclo de 4 dura 0,5 s reais
}

static var _texturas := {}  # (inclinação em décimos, força, quadro, simples) -> ImageTexture

var nos: Array[Sprite2D] = []  # os dois jatos (esquerdo e direito do corpo); vazio antes do primeiro voo
var atras := false  # a chama está desenhada atrás do corpo agora
var quadro := 0  # o quadro do ciclo agora (0 sempre no perfil Baixo)
var forca := 1  # 0 descida, 1 cruzeiro, 2 decolagem
var nome_dir := ""  # a linha da folha do mecha (baixo, cima, esquerda, ...)
var inclina := 0.0  # a inclinação da chama (x por y; negativa = cai para a esquerda)
var _raiz: Node2D = null


func montar(raiz: Node2D) -> void:
	_raiz = raiz
	for i in 2:
		var s := Sprite2D.new()
		s.name = "Propulsor%d" % i
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # a chama acende sozinha: a luz do cenário não a escurece
		s.material = mat
		s.visible = false
		raiz.add_child(s)
		nos.append(s)


## Os números de `c` (bloco propulsor do cfg do impulso) cobrindo o padrão.
static func numeros(c: Dictionary) -> Dictionary:
	var r := PADRAO.duplicate()
	for k in c:
		r[k] = c[k]
	return r


## A geometria de uma direção (nome da linha da folha): `atras` (a mochila fica longe da câmera: chama atrás do corpo), `inclina` (x por y da chama) e
## `monta` (a boca de cada jato, px relativos aos pés, inteiros).
static func geometria(nome: String, n: Dictionary) -> Dictionary:
	var f: Vector2 = DIRS.get(nome, DIRS["baixo"])
	var lado := Vector2(-f.y, f.x)  # o lado do corpo (no chão)
	var atras: bool = f.y > 0.3
	var alt := float(n.atras_altura) if atras else float(n.altura)
	var monta: Array[Vector2] = []
	for s in [-1.0, 1.0]:
		var g: Vector2 = -f * float(n.recuo) + lado * float(n.lado) * s
		monta.append(Vector2(roundf(g.x), roundf(g.y * ACHATA - alt)))
	var d := Vector2(-f.x * 0.5, 1.0 - f.y * 0.5 * ACHATA)  # para trás e para baixo, projetado na tela
	return {
		"atras": atras,
		"inclina": d.x / d.y,
		"monta": monta,
		"abre": float(n.atras_abre) if atras else float(n.abre),
		"mult": float(n.atras_comp) if atras else 1.0,
	}


## Esconde os dois jatos (o impulso acabou, ou o herói morreu, ou virou Lobo).
func esconder() -> void:
	for s in nos:
		if s.visible:
			s.visible = false


func visivel() -> bool:
	return not nos.is_empty() and nos[0].visible


## Um quadro do voo (Heroi._visual): põe os dois jatos nas costas do corpo. `desloca` é o quanto o desenho do corpo está fora do repouso (o golpe, a subida do
## voo; px) e `chave_y` o y do sprite do corpo na raiz quando ela está no y-sort (INF = fora dele), o mesmo contrato de Foguinho.seguir.
func seguir(h, imp, desloca: Vector2, chave_y: float) -> void:
	var n := numeros(imp.cfg().get("propulsor", {}))
	var linhas: Array = h.tipo.info.get("linhas", []) if h.tipo is Dictionary and h.tipo.has("info") else []
	nome_dir = str(linhas[h.linha]) if h.linha >= 0 and h.linha < linhas.size() else "baixo"
	var g := geometria(nome_dir, n)
	forca = imp.forca(h)
	var dur := float(n.quadro_lento_s) if Piscadas.ligado() else float(n.quadro_s)
	quadro = 0 if _simples() else int(floorf(h.imp_relogio / maxf(dur, 0.001))) % QUADROS
	inclina = float(g.inclina)
	if atras != bool(g.atras):
		atras = bool(g.atras)
		for s in nos:
			_raiz.move_child(s, 0 if atras else _raiz.get_child_count() - 1)
	var d := desloca.round()
	for i in 2:
		var s := nos[i]
		var abre := float(g.abre) * (-1.0 if i == 0 else 1.0)
		var tx := _textura(roundi((inclina + abre) * 10.0), forca, quadro, n, float(g.mult))
		if s.texture != tx:
			s.texture = tx
		var boca: Vector2 = g.monta[i]
		var topo := Vector2(boca.x - float(METADE), boca.y) + d  # onde o canto de cima da textura cai, na raiz
		var pos := topo
		var off := Vector2.ZERO
		if chave_y != INF:  # no y-sort: o nó fica 1 px antes ou depois do corpo e o offset o leva ao lugar
			pos = Vector2(topo.x, chave_y + (-1.0 if atras else 1.0))
			off = Vector2(0.0, topo.y - pos.y)
		if s.position != pos:
			s.position = pos
		if s.offset != off:
			s.offset = off
		s.visible = true


## Perfil Baixo (ou Brilhos e halos em 0%): chama simples e parada.
static func _simples() -> bool:
	var nv: String = Foguinho.nivel()
	return nv == "baixo" or nv == "desligado"


## A textura de uma chama: `incl10` a inclinação em décimos de px por linha, `f` a força, `q` o quadro, `mult` o fator do comprimento (atrás do corpo). Guardada: o mesmo desenho serve a todos os voos.
static func _textura(incl10: int, f: int, q: int, n: Dictionary, mult := 1.0) -> ImageTexture:
	var simples := _simples()
	var chave := (((incl10 + 20) * 100 + f * 10 + q) * 2 + (1 if simples else 0)) * 4 + roundi((mult - 1.0) * 4.0)
	if _texturas.has(chave):
		return _texturas[chave]
	var img := Image.create(METADE * 2 + 1, ALTURA, false, Image.FORMAT_RGBA8)
	var comp := roundi(float((n.comp as Array)[f]) * mult)
	var larg := int((n.larg as Array)[f])
	var incl := float(incl10) / 10.0
	var cresce: int = 0 if simples else [0, -2, 1, -1][q]  # o comprimento varia um pouco no ciclo
	var caroco: float = -9.0 if simples else [0.25, 0.45, 0.65, 0.4][q] * float(comp)  # a linha onde a chama alarga 1 px
	var comp_q := mini(maxi(comp + cresce, 3), ALTURA)
	for y in comp_q:
		var u := float(y) / float(comp_q)
		var meia := roundi(float(larg) * (1.0 - pow(u, 1.3)))
		if absf(float(y) - caroco) <= 1.0 and larg >= 3:
			meia += 1
		var cx := METADE + roundi(incl * float(y))
		for dx in range(-meia, meia + 1):
			var x := cx + dx
			if x < 0 or x >= METADE * 2 + 1:
				continue
			var d := float(absi(dx)) / float(maxi(meia, 1))
			var cor := CIANO
			if meia >= 2 and absi(dx) == meia:
				cor = ESCURO if u < 0.8 else AZUL
			elif d > 0.66:
				cor = AZUL
			elif d <= 0.4 and u < 0.6:
				cor = BRANCO
			if y >= comp_q - 1:
				cor = AZUL
			img.set_pixel(x, y, cor)
	var tex := ImageTexture.create_from_image(img)
	_texturas[chave] = tex
	return tex

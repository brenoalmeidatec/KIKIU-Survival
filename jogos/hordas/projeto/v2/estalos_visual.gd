extends RefCounted
## Estalo das bolinhas do canhão do mecha (a rajada do LightWolf, `bala` em v2/adagas.gd): no ACERTO, uma explosãozinha de energia âmbar-branca
## no ponto do contato (ESTALO, 4 quadros em 0,2 s; o crítico usa o ESTALO_CRIT, maior, 5 quadros em 0,24 s); no FIM DO ALCANCE sem acertar,
## um "fizzle" menor (FIZZLE, 3 quadros em 0,15 s). Só desenha: o dano, o número, o som e o RNG continuam em adagas._acertar (aqui não há sorteio).
## Quadros desenhados em código uma vez (montar), na grade de 1 px: desenhados com draw_texture na posição inteira, sem escala nem giro.
## Custo (são ~28 bolinhas/s): pool fixo de MAX vagas, nenhum nó por impacto, e quatro tetos antes de ocupar uma vaga:
##  - por quadro: POR_QUADRO impactos (x efe_impactos do nível de partículas);
##  - por rajada (o `lancar` de 5 bolinhas): POR_RAJADA impactos, contando estalo e fizzle (x efe_impactos; o crítico passa deste teto, não dos outros);
##  - por lugar: o mesmo ponto (REGIAO px) não estala de novo antes de REPETE_S (no máximo 2 Hz; 1,0 s com "Reduzir piscadas");
##  - pool cheio: o impacto novo é descartado (não rouba a vaga de quem está tocando nem a memória de lugar).
## Perfil Baixo (efe_impactos < 0,5) e partículas "nenhuma" (0): nada (é efeito extra; o monstro continua piscando no acerto).
## "Reduzir piscadas": sem o miolo branco; mostra só o último quadro (faíscas âmbar) apagando em alfa, e o lugar espera 1,0 s.
## CLARÃO DE BOCA (BOCA, o tiro do canhão saindo): um clarão âmbar-branco no cano de cada braço quando a rajada sai (`emitir_boca`, chamada uma vez por
## rajada pelo `lancar` de v2/adagas.gd, na boca medida da folha). 13x13, 3 quadros em 0,1 s, mesma grade de 1 px e mesmo contorno. Conta como partícula extra:
## perfil Baixo (efe_impactos < 0,5) e "nenhuma" não desenham. Vagas PRÓPRIAS (BOCA_VAGAS, fora do pool dos impactos: o clarão nunca tira lugar de um estalo e
## os contadores dos estalos não mudam). A vaga é do BRAÇO (o herói + o lado 0/1), não de um ponto do mundo: guarda a boca relativa aos pés do herói (a linha
## de 8 direções e o braço, já arredondada) e é desenhada a cada quadro em h.pr + essa boca, o mesmo pixel em que a folha desenha o cano. Andando e atirando o
## clarão vai junto com o cano (nunca fica para trás no chão) e não pula 1 px em relação a ele. A mira virou com o brilho aceso (a folha já desenha o cano em outra
## das 8 linhas): o mesmo brilho passa para a boca daquele braço na linha nova (a tabela da folha, guardada com a vaga), sem apagar e reacender. Cada braço atira ~2,9 vezes por segundo: no modo normal cada tiro
## reinicia o clarão daquele braço (o mesmo que a folha faz com o clarão dela); com "Reduzir piscadas" não há flash nem miolo branco: UM brilho âmbar parado por
## braço, que cada tiro só renova (alfa 1 enquanto o braço atira, apaga em BOCA_APAGA_S depois do último tiro): no máximo 2 trocas por rajada contínua.
## A folha do mecha já traz um clarão branco no quadro do disparo (combo 1 e 7; com "Reduzir piscadas" a folha usa poses sem ele): o BOCA é desenhado por cima, centrado na mesma boca.

const Piscadas := preload("res://v2/piscadas.gd")
const MAX := 12
const POR_QUADRO := 3
const POR_RAJADA := 2
const REGIAO := 8.0  # px: dois impactos mais perto que isto são o mesmo lugar
const REPETE_S := 0.5  # o mesmo lugar acende no máximo 2 vezes por segundo
const MEMORIA := 24  # lugares lembrados (anel); com o anel cheio de lugares ainda "quentes", o impacto novo é descartado
const NUM_RAJADAS := 16  # rajadas recentes com a conta de impactos (anel, como o dos números em adagas.gd)
enum { ESTALO, ESTALO_CRIT, FIZZLE, BOCA }
const DUR := [0.2, 0.24, 0.15, 0.1]
const LADO := [11, 15, 7, 13]  # quadros ímpares: o centro cai num pixel
const BOCA_HEROIS := 4  # heróis com clarão ao mesmo tempo (coop / tela dividida dividem o mesmo combate.adagas)
const BOCA_VAGAS := 2 * BOCA_HEROIS  # uma vaga por braço de cada herói: o tiro do mesmo braço renova a vaga dele, nunca abre outra
const BOCA_CALMA_S := 0.6  # "Reduzir piscadas": quanto dura o brilho parado depois de um tiro (bem mais que o intervalo de ~0,35 s do mesmo braço + a parte que apaga: nunca apaga atirando)
const BOCA_APAGA_S := 0.15  # e a parte final em que ele apaga em alfa

const BRANCO := Color(1.0, 1.0, 1.0)
const QUENTE := Color(1.0, 0.93, 0.66)
const AMBAR := Color(1.0, 0.7, 0.22)  # o mesmo âmbar do corpo da bolinha
const BRASA := Color(0.85, 0.42, 0.1)
const CONTORNO := Color(0.16, 0.08, 0.03)  # o contorno escuro da bolinha: destaca do chão quente

var quadros: Array = []  # [tipo] -> Array[Texture2D]
var pos := PackedVector2Array()
var tempo := PackedFloat32Array()  # restante (s); 0 = vaga livre
var tipo := PackedInt32Array()
var boca_heroi: Array = []  # [vaga] -> o herói dono do braço (null = livre): o clarão é desenhado a partir dele
var boca_lado := PackedInt32Array()  # [vaga] -> o braço (0 = o esquerdo da tela, 1 = o direito)
var boca_rel := PackedVector2Array()  # [vaga] -> a boca relativa aos pés do herói, em px inteiros
var boca_linha := PackedInt32Array()  # [vaga] -> a linha (8 direções) que a folha desenhava no tiro; mudou, a boca sai da tabela na linha nova
var boca_tabela: Array = []  # [vaga] -> a tabela de bocas da folha ([linha][lado] -> [x, y]); [] = sem tabela, fica em boca_rel
var boca_tempo := PackedFloat32Array()  # restante (s); 0 = vaga livre
var boca_pos: PackedVector2Array:  # (só leitura) onde cada vaga desenha neste quadro, em px de mundo: h.pr + a boca da linha desenhada
	get:
		return _bocas_no_mundo()
var bocas_emitidas := 0  # testes: clarões de boca pedidos e aceitos (renovar o brilho parado conta)
var bocas_cortadas := 0  # testes: barrados pelo perfil (Baixo / sem partículas) ou por vaga cheia
var _mem_pos := PackedVector2Array()
var _mem_t := PackedFloat32Array()  # instante (relógio) do último impacto naquele lugar
var _mem_i := 0
var _raj_id := PackedInt64Array()
var _raj_n := PackedInt32Array()
var _raj_i := 0
var _relogio := 0.0
var _no_quadro := 0
var emitidos := 0  # testes
var descartados := 0  # testes: barrados por teto, lugar ou pool cheio
var pico := 0  # testes: o máximo de vagas ocupadas ao mesmo tempo


func montar() -> void:
	pos.resize(MAX)
	tempo.resize(MAX)
	tipo.resize(MAX)
	boca_heroi.resize(BOCA_VAGAS)
	boca_lado.resize(BOCA_VAGAS)
	boca_rel.resize(BOCA_VAGAS)
	boca_linha.resize(BOCA_VAGAS)
	boca_tabela.resize(BOCA_VAGAS)
	boca_tempo.resize(BOCA_VAGAS)
	_mem_pos.resize(MEMORIA)
	_mem_t.resize(MEMORIA)
	_raj_id.resize(NUM_RAJADAS)
	_raj_n.resize(NUM_RAJADAS)
	quadros = [_quadros_estalo(5, 4), _quadros_estalo(7, 5), _quadros_fizzle(), _quadros_boca()]
	limpar()


func limpar() -> void:
	tempo.fill(0.0)
	boca_tempo.fill(0.0)
	boca_heroi.fill(null)
	boca_tabela.fill([])
	bocas_emitidas = 0
	bocas_cortadas = 0
	_mem_t.fill(-99.0)
	_raj_id.fill(0)
	_raj_n.fill(0)
	_mem_i = 0
	_raj_i = 0
	_relogio = 0.0
	_no_quadro = 0
	emitidos = 0
	descartados = 0
	pico = 0


## Pede um impacto `t` (ESTALO, ESTALO_CRIT, FIZZLE) em `p`. `rajada` = adagas.a_rajada da bolinha (0 = sem conta por rajada); `fator` = efe_impactos
## do nível de partículas; `forcar` (o crítico) passa do teto por rajada. Devolve true se tocou.
func emitir(p: Vector2, t: int, rajada: int, fator: float, forcar := false) -> bool:
	if fator < 0.5:  # perfil Baixo / sem partículas: sem estalo nem fizzle
		return false
	var lugar := p.round()
	if _no_quadro >= maxi(1, roundi(POR_QUADRO * minf(fator, 1.0))):
		descartados += 1
		return false
	var k_raj := -1
	if rajada != 0:
		for k in NUM_RAJADAS:
			if _raj_id[k] == rajada:
				k_raj = k
				break
		var teto := maxi(1, roundi(POR_RAJADA * minf(fator, 1.0)))
		if k_raj >= 0 and _raj_n[k_raj] >= teto and not forcar:
			descartados += 1
			return false
	var repete := 1.0 if Piscadas.ligado() else REPETE_S
	for k in MEMORIA:
		if _relogio - _mem_t[k] < repete and _mem_pos[k].distance_squared_to(lugar) < REGIAO * REGIAO:
			descartados += 1
			return false
	if _relogio - _mem_t[_mem_i] < repete:  # o anel inteiro ainda está quente: sobrescrever deixaria um lugar acender cedo demais
		descartados += 1
		return false
	var livre := -1
	for i in MAX:
		if tempo[i] <= 0.0:
			livre = i
			break
	if livre < 0:
		descartados += 1
		return false
	pos[livre] = lugar
	tempo[livre] = DUR[t]
	tipo[livre] = t
	_mem_pos[_mem_i] = lugar
	_mem_t[_mem_i] = _relogio
	_mem_i = (_mem_i + 1) % MEMORIA
	if rajada != 0:
		if k_raj < 0:
			k_raj = _raj_i
			_raj_id[k_raj] = rajada
			_raj_n[k_raj] = 0
			_raj_i = (_raj_i + 1) % NUM_RAJADAS
		_raj_n[k_raj] += 1
	_no_quadro += 1
	emitidos += 1
	pico = maxi(pico, ativas())
	return true


## O clarão de boca do braço `lado` (0/1) do herói `h`, com a boca em `rel` (px relativos aos pés, a tabela da folha para a linha da mira e o braço).
## `fator` = efe_impactos do nível de partículas: abaixo de 0,5 (Baixo) e sem partículas, nada. Se o mesmo braço do mesmo herói ainda tem o clarão aceso,
## o pedido renova essa vaga (e leva a boca para a linha nova, se a mira virou) em vez de ocupar outra. `tabela` = a tabela de bocas da folha: se a mira virar
## com o brilho aceso, a vaga lê nela a boca da linha que a folha passou a desenhar. Devolve true se acendeu ou renovou.
func emitir_boca(h, rel: Vector2, lado: int, fator: float, tabela: Array = []) -> bool:
	if fator < 0.5:
		bocas_cortadas += 1
		return false
	var vaga := -1
	for i in BOCA_VAGAS:
		if boca_tempo[i] > 0.0 and is_same(boca_heroi[i], h) and boca_lado[i] == lado:
			vaga = i
			break
	if vaga < 0:
		for i in BOCA_VAGAS:
			if boca_tempo[i] <= 0.0:
				vaga = i
				break
	if vaga < 0:
		bocas_cortadas += 1
		return false
	boca_heroi[vaga] = h
	boca_lado[vaga] = lado
	boca_rel[vaga] = rel.round()
	boca_linha[vaga] = h.linha_de(h.dir_olhar)
	boca_tabela[vaga] = tabela
	boca_tempo[vaga] = BOCA_CALMA_S if Piscadas.ligado() else float(DUR[BOCA])
	bocas_emitidas += 1
	return true


func atualizar(dt: float) -> void:
	_relogio += dt
	_no_quadro = 0
	for i in MAX:
		tempo[i] = maxf(0.0, tempo[i] - dt)
	for i in BOCA_VAGAS:
		boca_tempo[i] = maxf(0.0, boca_tempo[i] - dt)
		if boca_tempo[i] <= 0.0:
			boca_heroi[i] = null  # a vaga livre não segura o herói
			boca_tabela[i] = []


func ativas() -> int:
	var n := 0
	for t in tempo:
		if t > 0.0:
			n += 1
	return n


## Vagas acesas dos clarões de boca.
func bocas_ativas() -> int:
	var n := 0
	for t in boca_tempo:
		if t > 0.0:
			n += 1
	return n


## Onde cada vaga do clarão de boca desenha neste quadro (px de mundo, inteiros): o pixel dos pés do herói (h.pr, o mesmo da folha) + a boca relativa.
## Vaga livre: Vector2.INF.
func _bocas_no_mundo() -> PackedVector2Array:
	var r := PackedVector2Array()
	r.resize(BOCA_VAGAS)
	for i in BOCA_VAGAS:
		r[i] = (boca_heroi[i].pr as Vector2) + _boca_rel_agora(i) if boca_tempo[i] > 0.0 and boca_heroi[i] != null else Vector2.INF
	return r


## A boca relativa (px inteiros) da vaga `i` neste quadro: a do tiro enquanto a folha desenha a mesma linha; a mira virou, a do mesmo braço na linha nova.
## Mais o desvio do quadro que a folha desenha agora (h.desvio_boca: o sobe-e-desce do passo no andar_tiro), para o clarão ficar no cano andando.
## O desenho do herói subido (`alt_px`, o mecha voando no impulso, v2/impulso.gd) sobe a boca junto.
func _boca_rel_agora(i: int) -> Vector2:
	var h = boca_heroi[i]
	var sobe := Vector2(0.0, -float(h.get("alt_px") if "alt_px" in h else 0))
	var linha: int = h.linha_de(h.dir_olhar)
	var tabela: Array = boca_tabela[i]
	var base: Vector2 = boca_rel[i]
	if linha != boca_linha[i] and tabela.size() == 8 and (tabela[linha] as Array).size() == 2 and (tabela[linha][boca_lado[i]] as Array).size() == 2:
		var xy: Array = tabela[linha][boca_lado[i]]
		base = Vector2(float(xy[0]), float(xy[1])).round()
	return base + h.desvio_boca(boca_lado[i]) + sobe


## Tudo o que ainda desenha: impactos e clarões de boca (é o que mantém o desenho de v2/adagas.gd acordado).
func vivos() -> int:
	return ativas() + bocas_ativas()


## O alfa do clarão de boca da vaga `i`: sempre 1 no modo normal (os quadros mudam, o alfa não); calmo: 1 enquanto o braço atira e só apaga nos últimos BOCA_APAGA_S.
func alfa_boca(i: int, calmo: bool) -> float:
	if boca_tempo[i] <= 0.0:
		return 0.0
	return clampf(boca_tempo[i] / BOCA_APAGA_S, 0.0, 1.0) if calmo else 1.0


## O quadro do clarão de boca que ainda tem `restante` s: os 3 primeiros em sequência; com "Reduzir piscadas" (`calmo`) sempre o brilho parado (o último).
func quadro_boca(restante: float, calmo: bool) -> int:
	var n: int = (quadros[BOCA] as Array).size()
	if calmo:
		return n - 1
	return clampi(int((1.0 - restante / float(DUR[BOCA])) * float(n - 1)), 0, n - 2)


## O quadro do impacto que ainda tem `restante` s; com "Reduzir piscadas" (`calmo`), sempre o último (sem o miolo branco).
func quadro_em(t: int, restante: float, calmo: bool) -> int:
	var n: int = (quadros[t] as Array).size()
	if calmo:
		return n - 1
	return clampi(int((1.0 - restante / float(DUR[t])) * n), 0, n - 1)


func desenhar(no: Node2D) -> void:
	var calmo := Piscadas.ligado()
	no.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in MAX:
		if tempo[i] <= 0.0:
			continue
		var t := tipo[i]
		var tex: Texture2D = quadros[t][quadro_em(t, tempo[i], calmo)]
		var meio := floorf(float(LADO[t]) * 0.5)
		var cor := Color(1, 1, 1, tempo[i] / float(DUR[t])) if calmo else Color.WHITE  # calmo: um só apagar, sem trocar de luminância
		no.draw_texture(tex, pos[i] - Vector2(meio, meio), cor)
	var meio_b := floorf(float(LADO[BOCA]) * 0.5)
	for i in BOCA_VAGAS:
		if boca_tempo[i] <= 0.0 or boca_heroi[i] == null:
			continue
		var lugar: Vector2 = (boca_heroi[i].pr as Vector2) + _boca_rel_agora(i)  # segue o cano: o herói pode ter andado ou virado a mira desde o tiro
		no.draw_texture(quadros[BOCA][quadro_boca(boca_tempo[i], calmo)], lugar - Vector2(meio_b, meio_b), Color(1, 1, 1, alfa_boca(i, calmo)))


# ------------------------------------------------------------------ quadros (pixel a pixel)


## Estalo de raio `r` (5 = normal 11x11, 7 = crítico 15x15) em `n` quadros: núcleo branco contornado, que abre em estrela, vira anel de faíscas
## e se espalha em pontinhos âmbar. Contorno escuro só nos quadros cheios (os primeiros), como a bolinha. As 8 faíscas têm o mesmo raio
## (diagonal = cardeal): com diagonais curtas o anel + 4 espetos longos lia como mira (⊕) numa foto parada, não como estouro.
func _quadros_estalo(r: int, n: int) -> Array:
	var lado := 2 * r + 1
	var lista: Array = []
	for q in n:
		var f := float(q) / float(n - 1)  # 0 no primeiro quadro, 1 no último
		var im := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
		var corpo := 0.0  # raio do disco cheio
		var anel := 0.0  # raio do anel oco (0 = sem anel)
		var faisca := 0  # raio das faíscas (0 = sem faíscas)
		var diagonais := false
		if f < 0.2:
			corpo = r * 0.4 + 0.5
		elif f < 0.45:
			corpo = r * 0.6 + 0.5
			faisca = r
		elif f < 0.8:  # o anel abre (o crítico, com mais quadros, mostra dois tamanhos)
			anel = r * (0.6 if f < 0.6 else 0.75) + 0.5
			faisca = r
			diagonais = true
		else:
			faisca = r
			diagonais = true
		for y in lado:
			for x in lado:
				var d := Vector2(x - r, y - r).length()
				if corpo > 0.0 and d <= corpo:
					im.set_pixel(x, y, BRANCO if d <= corpo * 0.45 else (QUENTE if d <= corpo * 0.75 else AMBAR))
				elif anel > 0.0 and absf(d - anel) <= 0.5:
					im.set_pixel(x, y, AMBAR)
		if faisca > 0:
			var ponta := BRASA if f >= 0.8 else QUENTE
			for k in 8:
				if k % 2 == 1 and not diagonais:
					continue
				var v := Vector2.from_angle(float(k) * PI / 4.0)
				var fim := Vector2i((v * float(faisca)).round()) + Vector2i(r, r)
				im.set_pixelv(fim, ponta)
				if f < 0.8:  # a faísca ainda tem cauda (um pixel para dentro)
					var cauda := Vector2i((v * float(faisca - 1)).round()) + Vector2i(r, r)
					if im.get_pixelv(cauda).a == 0.0:
						im.set_pixelv(cauda, AMBAR)
		if corpo > 0.0:
			_contornar(im)
		lista.append(ImageTexture.create_from_image(im))
	return lista


## O clarão de boca 13x13 (raio 6), 3 quadros + o brilho parado do "Reduzir piscadas". Simétrico (não gira: serve nas 8 direções): 0 = núcleo branco com
## quatro espetos longos e quatro curtos; 1 = disco âmbar com quatro espetos médios; 2 = brasas soltas; 3 (só com a opção ligada) = disco âmbar parado, sem branco.
## Contorno escuro nos quadros 0, 1 e 3, como a bolinha e o estalo; o quadro de brasas fica sem contorno (já é o fim).
func _quadros_boca() -> Array:
	const R := 6
	const CARDEAIS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	const DIAGONAIS := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]
	var lista: Array = []
	for q in 4:
		var im := Image.create(2 * R + 1, 2 * R + 1, false, Image.FORMAT_RGBA8)
		var c := Vector2i(R, R)
		match q:
			0:
				_disco(im, c, 2.5, AMBAR)
				_disco(im, c, 1.5, QUENTE)
				_disco(im, c, 0.6, BRANCO)
				for v in CARDEAIS:
					for d in range(3, 7):
						im.set_pixelv(c + v * d, QUENTE if d < 5 else AMBAR)
				for v in DIAGONAIS:
					for d in range(2, 4):
						im.set_pixelv(c + v * d, AMBAR)
			1:
				_disco(im, c, 2.5, AMBAR)
				_disco(im, c, 1.2, QUENTE)
				for v in CARDEAIS:
					for d in range(3, 6):
						im.set_pixelv(c + v * d, AMBAR)
			2:
				im.set_pixelv(c, AMBAR)
				for v in DIAGONAIS:
					im.set_pixelv(c + v * 2, BRASA)
				for v in CARDEAIS:
					im.set_pixelv(c + v * 5, BRASA)
			3:
				_disco(im, c, 3.5, BRASA)
				_disco(im, c, 2.5, AMBAR)
		if q != 2:
			_contornar(im)
		lista.append(ImageTexture.create_from_image(im))
	return lista


## Disco cheio de raio `r` (px) em volta de `c`, na grade de 1 px (alfa 0 ou 1).
func _disco(im: Image, c: Vector2i, r: float, cor: Color) -> void:
	for y in im.get_height():
		for x in im.get_width():
			if Vector2(x - c.x, y - c.y).length() <= r:
				im.set_pixel(x, y, cor)


## O fizzle 7x7: um ponto quente que se desfaz em quatro pontinhos âmbar e depois em brasa.
func _quadros_fizzle() -> Array:
	var lista: Array = []
	var desenhos := [
		[[Vector2i(3, 3), QUENTE], [Vector2i(2, 3), AMBAR], [Vector2i(4, 3), AMBAR], [Vector2i(3, 2), AMBAR], [Vector2i(3, 4), AMBAR]],
		[[Vector2i(3, 3), AMBAR], [Vector2i(1, 1), AMBAR], [Vector2i(5, 1), AMBAR], [Vector2i(1, 5), AMBAR], [Vector2i(5, 5), AMBAR]],
		[[Vector2i(0, 3), BRASA], [Vector2i(6, 3), BRASA], [Vector2i(3, 0), BRASA], [Vector2i(3, 6), BRASA]],
	]
	for q in desenhos.size():
		var im := Image.create(7, 7, false, Image.FORMAT_RGBA8)
		for px in desenhos[q]:
			im.set_pixelv(px[0], px[1])
		if q == 0:
			_contornar(im)
		lista.append(ImageTexture.create_from_image(im))
	return lista


## Contorno de 1 px (4 vizinhos) em volta do que já está pintado.
func _contornar(im: Image) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var cheio := PackedByteArray()
	cheio.resize(w * h)
	for y in h:
		for x in w:
			cheio[y * w + x] = 1 if im.get_pixel(x, y).a > 0.0 else 0
	for y in h:
		for x in w:
			if cheio[y * w + x] == 1:
				continue
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var o: Vector2i = Vector2i(x, y) + v
				if o.x >= 0 and o.y >= 0 and o.x < w and o.y < h and cheio[o.y * w + o.x] == 1:
					im.set_pixel(x, y, CONTORNO)
					break

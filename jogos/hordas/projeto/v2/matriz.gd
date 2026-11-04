extends RefCounted
## A MATRIZ DE DEFESA do LightWolf (LW-3, #511): o secundário (botão direito, segurar) do mecha. Como quase não existe projétil inimigo no jogo, a matriz da D.Va virou uma
## BARREIRA EM ARCO (140 graus, na direção da mira) que faz duas coisas enquanto está erguida:
##  - EMPURRA: todo monstro que chega na CASCA (`casca` px do herói, dentro do arco) leva um empurrão para fora (`m.emp`, `empurrao` px/s dividido pelo peso dele). Sem dano
##    e sem flash por monstro (item 7, reduzir piscadas): a barreira é uma parede que segura a horda, não uma arma.
##  - ABSORVE: o dano que vem de dentro do arco (contato, ataques anunciados no chão e golpes do chefe; `Heroi.levar_dano` chama `absorver`) sai da BARRA DE DEFESA, 1 para 1.
##    O que passa do que a barra tem VAZA para a vida. A barra é a mesma do escudo do Nick (campos `def` e `def_max` do herói, `defesa_regen_mult` da dificuldade, reposição pela
##    cura): o bloco `matriz > barra` de dados/v2_secundario.json só sobrepõe as chaves do `escudo > barra` (gasta 5 por segundo só por segurar, ~20 s; zerou = SOBRECARGA até voltar a 35%;
##    recarga de 6 por segundo depois de 2 s sem segurar). Quem gasta e quem recarrega é o herói (`_gastar_defesa`, `_recuperar_defesa`), o mesmo código do escudo.
## As cartas do LW-6 (dados/v2_cartas.json, modificadores `sifao`, `ampla` e `cabo`; a evolução `aurora_lunar` em `evolucoes_matriz`) mexem aqui:
##  - SIFÃO DA MATRIZ: parte do que a matriz absorve volta como vida (`armas.mods.sifao` em %, 12 por nível). O que cura por segundo tem TETO (`matriz_cartas.sifao_teto_s`, 8 PV/s):
##    uma cesta que enche à razão do teto e esvazia com cada cura, então um golpe grande cura até uma cesta cheia (1 s de teto) e o resto se perde.
##  - MATRIZ AMPLA: +10 graus de arco por nível (`armas.mods.ampla`, até `matriz_cartas.arco_max`): o arco vale para empurrar, absorver e desenhar (`arco_graus`).
##  - AURORA LUNAR (Sifão 3 + Ampla 3, sem consumir as peças): a cura do sifão dobra (e o teto também) e a cura que passa da vida cheia vira defesa (`excedente_barra`, 50%).
##  - CABO DE RESGATE não passa por aqui: multiplica a carga do chamado em `especial.carregar` (`cartas.mult_cabo`).
##
## A casca de 88 px (era 40) segura a horda mais longe, a ~94 px do herói no chão: ainda dentro dos 170 px do canhão. MEDIDO em testes/v2_matriz: o canhão nos 8 cães
## que a matriz parou dá ~61 de dano por segundo, contra ~64 com a mesma horda a ~35 px (a casca antiga); o leque abre, mas a horda espalhada pega o que o alvo único
## perderia. O empurrão (170 px/s) não mudou. A casca é uma PAREDE na frente do campo: de lado até a meia-largura da moldura da frente (+ o raio do monstro) ela é medida
## NA MIRA, então o monstro para rente ao pé da moldura da frente em qualquer ângulo (num raio só, a 35 graus ele parava 12 px para dentro dela, atravessando o campo);
## nas pontas do arco, fora da largura do campo, vale o raio da casca, onde a marca fina no chão mostra o alcance.
##
## O herói (v2/heroi.gd) cuida da entrada e do estado (`escudo_ativo` serve aos dois, velocidade, a barra); este módulo cuida da geometria (`cobre`), da absorção, do empurrão
## (`atualizar`, no tempo do mundo) e do visual (`efeitos`, no relógio de parede). O VISUAL é 100% em código (nenhuma folha) e segue a Matriz de Defesa como IDEIA (pedido do
## Alisson): um campo EM PÉ na frente do mecha, na direção da mira, feito de 3 MOLDURAS hexagonais (`molduras`) encaixadas em degraus: a de trás menor e mais perto do mecha,
## a da frente maior e mais longe; todas com contorno de 2 px (de 1 px as de trás sumiam sobre o corpo do mecha e o campo se lia como um contorno só) e preenchimento
## translúcido leve, em px inteiros e sem antialiasing (a grade de 1 px do mundo). De frente, o topo de cada moldura sobe ~8 px e os lados abrem ~14 px em relação à de trás.
## O campo é GRANDE e BEM À FRENTE (pedido do Alisson no #620): os pés a 34, 59 e 84 px do herói no chão e a da frente com 136x80 px de frente (o mecha tem 55x73), não
## uma caixinha em volta do corpo. A CASCA da regra acompanha a moldura da frente (88 px, 4 por fora do pé dela): o monstro que o empurrão segura fica logo na frente do
## campo, nunca atravessando a moldura (testes/v2_matriz_visual cobra os dois juntos).
## Cada moldura é um painel vertical no chão: a base fica a `distancia` + i x `recuo` px do herói, na mira, e o eixo da largura é a perpendicular à mira vista de cima (de frente
## para a câmera quando mira para baixo, largo; de lado quando mira para a direita ou a esquerda, estreito, mas nunca abaixo de `lado_min` da largura). A largura cresce com o
## arco (`arco_graus`, a Matriz Ampla abre). O nó do desenho fica DENTRO do y-sort do mundo (`no_mundo`), com a chave de ordem na base do campo: mirando para baixo o campo é
## desenhado depois do mecha (na frente), mirando para cima antes (atrás: o campo de costas não cobre o mecha); aditivo e sem luz (`LIGHT_MODE_UNSHADED`), como o foguinho,
## para o escuro do mapa e as luzes não apagarem o brilho. No chão fica só uma marca fina na casca (onde o empurrão começa). Uma linha de varredura sobe pela moldura da frente
## (`varredura_hz`, no máximo 2 Hz) e, quando absorve, um clarão e faíscas no ponto do golpe, no plano da moldura da frente. O brilho pulsa a 1,5 Hz (nunca acima de 2 Hz) e o
## clarão de absorção tem intervalo mínimo; no perfil Baixo (sem partículas) ficam só as molduras, paradas: sem clarão de absorção, luz rápida, tremor de tela nem varredura (os
## sons ficam). Com a defesa abaixo de 35% as molduras vão ficando laranja (inteiras em 5%), sem piscar. Ao erguer, as molduras entram em degraus, de trás para a frente.
##
## API: montar(c, camada), limpar(), ativa(h) -> bool, cobre(h, de) -> bool, absorver(h, valor, de) -> float [o que vazou], ergueu(h), abaixou(h), atualizar(dt), efeitos(dt).

const ACHATA := 0.62  # o chão visto de lado (a mesma do escudo, da ruptura e dos avisos)
const COR_BASE := Color(0.62, 0.86, 1.0)
const COR_CIANO := Color(0.5, 0.95, 1.0)
const COR_ALERTA := Color(1.0, 0.62, 0.3)
const COR_CURA := Color(0.62, 1.0, 0.6)  # o número de cura do sifão (verde claro, o mesmo tom das faíscas de cura da arte)
const ALERTA_ATE := 0.35  # fração da barra abaixo da qual a faixa começa a esquentar (laranja inteira em ALERTA_FIM)
const ALERTA_FIM := 0.05
const ENTRA_S := 0.12  # s para as molduras aparecerem, uma depois da outra (de trás para a frente)
## O hexágono de cada moldura, em frações: x da meia-largura (-1 a 1) e y da altura (0 no pé, 1 no topo). Base mais estreita, o ponto mais largo a 40% da altura e o topo
## quase tão largo: o painel alongado e trapezoidal da ideia da Matriz de Defesa. Forma de desenho, não regra.
const FORMA: Array[Vector2] = [Vector2(-0.72, 0.0), Vector2(0.72, 0.0), Vector2(1.0, 0.4), Vector2(0.84, 1.0), Vector2(-0.84, 1.0), Vector2(-1.0, 0.4)]

var combate
var mundo
var cfg: Dictionary = {}  # dados/v2_secundario.json > matriz
var visual: Dictionary = {}  # dados/v2_secundario.json > matriz > visual
var no: Node2D  # o desenho da barreira: dentro do y-sort do mundo (aditivo, sem luz), com a posição na base do campo
var absorvido := 0.0  # a defesa gasta absorvendo golpes na partida (o gancho das cartas de cura do LW-6)
var golpes := 0  # quantos golpes a matriz absorveu
var claroes := 0  # quantos clarões de absorção apareceram (no máximo 2 por segundo; nenhum no perfil Baixo)
var vazado := 0.0  # o dano que passou da barra e foi para a vida
var curado := 0.0  # a vida que o sifão devolveu na partida (LW-6)
var convertido := 0.0  # a defesa que a Aurora Lunar fez da cura que passava da vida cheia
var empurrados := 0  # quantos monstros levaram empurrão no quadro de agora (testes e calibragem)
var ultimo: Dictionary = {}  # o último golpe absorvido (testes): valor, absorvido, vazou, de
var _relogio := 0.0
var _sobe_t := 9.0  # s desde que ergueu (a faixa aparece em 0,12 s)
var _flash_t := 0.0  # s do clarão do último golpe absorvido
var _flash_cd := 0.0  # s até poder mostrar outro clarão (o limite de piscadas)
var _impacto := Vector2.ZERO  # o ponto do último golpe, no mundo
var _desenhou := false
var _cesta := 99.0  # a cesta do teto de cura do sifão, em PV (enche à razão do teto por segundo; 99 = cheia, o teto a corta)
var _num_cd := 0.0  # s até poder mostrar outro número de cura
var _num_acum := 0.0  # a cura ainda não mostrada


func montar(c, camada: Node) -> void:
	combate = c
	mundo = c.mundo
	var d: Dictionary = Dados.json("v2_secundario")
	cfg = d.get("matriz", {})
	visual = cfg.get("visual", {})
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # o escuro do mapa e as luzes do cenário não tingem nem apagam o campo
	no = Node2D.new()
	no.material = mat
	no.draw.connect(_desenhar)
	# no y-sort do mundo: a posição do nó (a base do campo) decide se ele sai na frente ou atrás do mecha; sem mundo (testes com mundo falso), a camada que veio
	var pai = mundo.get("no_mundo") if mundo != null else null
	(pai if pai != null else camada).add_child(no)


## Partida nova.
func limpar() -> void:
	absorvido = 0.0
	golpes = 0
	claroes = 0
	vazado = 0.0
	curado = 0.0
	convertido = 0.0
	_cesta = 99.0
	_num_cd = 0.0
	_num_acum = 0.0
	empurrados = 0
	ultimo = {}
	_sobe_t = 9.0
	_flash_t = 0.0
	_flash_cd = 0.0
	_desenhou = false
	if no != null:
		no.queue_redraw()


## O herói `h` está com a matriz erguida agora?
func ativa(h) -> bool:
	return h != null and h.escudo_ativo and combate.escudo.matriz_para(str(h.chave))


## O dano que vem de `de` (posição no mundo) cai dentro do arco da matriz? A conta é a do escudo (no chão, y dividido pela achatada).
func cobre(h, de: Vector2) -> bool:
	return combate.escudo.cobre_arco(h, de, arco_graus())


## O arco da matriz agora: o do dado mais o que a Matriz Ampla abriu (10 graus por nível), até `matriz_cartas.arco_max`.
func arco_graus() -> float:
	var base := float(cfg.arco)
	if combate == null or combate.armas == null:
		return base
	var teto := float(_cfg_cartas().get("arco_max", 300.0))
	return minf(base + float(combate.armas.mods.get("ampla", 0.0)), maxf(teto, base))


func _cfg_cartas() -> Dictionary:
	return combate.cartas.cfg.get("matriz_cartas", {}) if combate != null and combate.cartas != null else {}


## A matriz absorve um golpe de `valor` que vem de `de`: tira da barra de defesa 1 para 1 e devolve o que VAZOU (o que a barra não tinha; 0 = absorveu tudo). Zerar a barra é a
## sobrecarga (`def_quebrado`, feito por `_gastar_defesa` do herói): a barreira cai no quadro seguinte e só volta a erguer depois do retorno.
func absorver(h, valor: float, de: Vector2) -> float:
	var gasto := minf(valor, maxf(float(h.def), 0.0))
	h._gastar_defesa(gasto)
	var vaza := valor - gasto
	if vaza < 0.001:
		vaza = 0.0
	golpes += 1
	absorvido += gasto
	vazado += vaza
	var curou := _sifao(h, gasto)
	ultimo = {"valor": valor, "absorvido": gasto, "vazou": vaza, "de": de, "curou": curou}
	_clarao(h, de)
	return vaza


## O teto de cura do sifão agora, em PV por segundo (a Aurora Lunar o dobra junto com a cura).
func teto_cura() -> float:
	var t := float(_cfg_cartas().get("sifao_teto_s", 8.0))
	if combate != null and combate.cartas != null and combate.cartas.aurora_ativa():
		t *= float(combate.cartas.evolucao_matriz("aurora_lunar").get("teto_mult", 2.0))
	return t


## A cura do Sifão da Matriz para o golpe que a barra absorveu (`gasto`): `mods.sifao` % do absorvido (vezes a cura da Aurora Lunar), limitada pela cesta do teto. Cura a vida;
## com a Aurora, o que passa da vida cheia vira defesa (`excedente_barra`); sem ela, a cura que não cabe não gasta a cesta. Devolve a vida curada.
func _sifao(h, gasto: float) -> float:
	var pct := float(combate.armas.mods.get("sifao", 0.0)) / 100.0
	if pct <= 0.0 or gasto <= 0.0 or h.estado == h.Estado.MORTO:
		return 0.0
	var ev: Dictionary = combate.cartas.evolucao_matriz("aurora_lunar") if combate.cartas.aurora_ativa() else {}
	var cesta := minf(_cesta, teto_cura())
	var cura := minf(gasto * pct * float(ev.get("cura_mult", 1.0)), cesta)
	if cura <= 0.0:
		return 0.0
	var falta := maxf(float(h.vida_max) - float(h.vida), 0.0)
	var vida := minf(cura, falta)
	var sobra := cura - vida
	var gastou := vida
	if vida > 0.0:
		h.curar(vida)
		curado += vida
		_num_acum += vida
	if sobra > 0.0 and not ev.is_empty():
		var barra := sobra * float(ev.get("excedente_barra", 0.0))
		if barra > 0.0 and h.def_max > 0.0 and not h.def_quebrado:
			var antes: float = h.def
			h._ganhar_defesa(barra)
			convertido += float(h.def) - antes
		gastou = cura
	_cesta = cesta - gastou
	_numero_cura(h)
	return vida


## O clarão do golpe absorvido no ponto da barreira do lado de quem bateu. Intervalo mínimo entre dois (dados > visual > impacto_min): nunca mais que 2 por segundo.
func _clarao(h, de: Vector2) -> void:
	if _flash_cd > 0.0:
		return
	_flash_cd = float(visual.get("impacto_min", 0.5))
	combate.audio.tocar("impacto", 0.85, -3.0, 0.04)
	if _leve():  # perfil Baixo: só a faixa parada e o som, sem clarão na faixa, luz nem tremor de tela
		return
	_flash_t = 0.18
	claroes += 1
	_impacto = ponto_golpe(h, de)
	mundo.cam.tremer(0.8, 0.08)
	combate.fx.estouro(_impacto, COR_CIANO, 3)
	combate.fx.luz_rapida(_impacto, COR_BASE, 1.3, 36.0, 0.16)


## O número verde da cura do sifão sobre o herói: junta o que curou e mostra no máximo um a cada `matriz_cartas.numero_s` (nunca mais de 2 por segundo). Sem clarão nem luz.
func _numero_cura(h) -> void:
	if _num_acum < 1.0 or _num_cd > 0.0:
		return
	_num_cd = float(_cfg_cartas().get("numero_s", 0.6))
	combate.fx.numero(h.pos + Vector2(0, -34), "+%d" % roundi(_num_acum), COR_CURA, false)
	_num_acum = 0.0


func ergueu(_h) -> void:
	_sobe_t = 0.0
	combate.audio.tocar("ruptura_tique", 1.45, -6.0, 0.05)


## Soltou o botão ou a barra zerou: sobrecarga (`def_quebrado`) faz a barreira estourar; soltar só apaga.
func abaixou(h) -> void:
	if h == null or not h.def_quebrado:
		return
	var centro := _ponto(h, _n() - 1, 0.0, 0.45)  # o meio da moldura da frente
	combate.audio.tocar("impacto", 0.55, 0.0, 0.05)
	combate.audio.tocar("critico", 0.7, -5.0, 0.0)
	if _leve():  # perfil Baixo: só o som
		return
	mundo.cam.tremer(1.5, 0.12)
	combate.fx.estouro(centro, COR_BASE, 8)
	combate.fx.luz_rapida(centro, COR_BASE, 1.6, 48.0, 0.2)


## O empurrão, todo quadro do mundo enquanto erguida: quem está na casca e dentro do arco é empurrado para longe do herói. Na frente do campo a casca é a parede (a distância
## na mira); fora da largura dele, o raio. O rumo é sempre o radial (o monstro anda para o herói e o empurrão o devolve na mesma linha, sem escorregar de lado).
## Não toca na vida nem no flash do monstro.
func atualizar(dt: float) -> void:
	_cesta = minf(_cesta + teto_cura() * dt, teto_cura())  # a cesta do teto de cura do sifão enche à razão do teto por segundo
	empurrados = 0
	var h = mundo.heroi
	if not ativa(h):
		return
	var casca := float(cfg.casca)
	var forca := float(cfg.empurrao)
	var graus := arco_graus()
	var hp: Vector2 = h.pos
	var u := _mira_chao(h)
	var meia := float(_plano(h, _n() - 1).w)  # a meia-largura da moldura da frente, no chão (a Matriz Ampla alarga a parede junto com o desenho)
	for m in mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var rel: Vector2 = m.pos - hp
		var raio := float(m.raio)
		var lim: float = casca + raio
		var fora: float = Vector2(lim, meia + raio).length()  # o canto da parede, o mais longe que alguém pode ser segurado
		if absf(rel.x) > fora or absf(rel.y) > fora * ACHATA:
			continue
		var rf := Vector2(rel.x, rel.y / ACHATA)
		var na_mira := rf.dot(u)
		if na_mira > 0.0 and absf(rf.cross(u)) <= meia + raio:
			if na_mira > lim:  # na frente do campo: a PAREDE, a casca medida na mira (rente ao pé da moldura da frente)
				continue
		elif rf.length() > lim:  # nas pontas do arco, fora da largura do campo: o raio (a marca no chão)
			continue
		if not combate.escudo.cobre_arco(h, m.pos, graus):
			continue
		var rumo: Vector2 = rel.normalized() if rel.length() > 0.5 else h.dir_olhar
		var v: float = forca * float(m.emp_mult) / maxf(float(m.peso), 0.25)
		if m.emp.dot(rumo) < v:
			m.emp = rumo * v
		empurrados += 1


## O visual no relógio de parede: só redesenha enquanto a barreira está erguida (e uma vez ao apagar). A posição do nó (a chave do y-sort) segue a base do campo.
func efeitos(dt: float) -> void:
	_relogio += dt
	_sobe_t = minf(_sobe_t + dt, 9.0)
	_flash_t = maxf(_flash_t - dt, 0.0)
	_flash_cd = maxf(_flash_cd - dt, 0.0)
	_num_cd = maxf(_num_cd - dt, 0.0)
	var h = mundo.heroi
	var ligada := ativa(h)
	if ligada:
		no.position = chave_ordem(h)
	if ligada or _desenhou:
		_desenhou = ligada
		no.queue_redraw()


## O raio da marca no chão: a casca menos um pouco, para o traço ficar onde o empurrão começa.
func _raio() -> float:
	return float(cfg.casca) - float(visual.get("raio_extra", 3.0))


## O perfil Baixo (partículas em "poucas" ou "nenhuma"): sem brilho que corre, pulso, faíscas nem partículas.
func _leve() -> bool:
	if mundo == null or not mundo.has_method("_nivel_particulas"):
		return false
	return float(mundo._nivel_particulas().get("efe_particulas", 1.0)) < 0.5


## A frequência do pulso do brilho, no máximo 2 Hz (o limite de acessibilidade), mesmo que o dado peça mais.
func _hz() -> float:
	return minf(float(visual.get("pulso_hz", 1.5)), 2.0)


## O pulso do brilho das molduras (0,68 a 1,0): parado no perfil Baixo.
func _pulso() -> float:
	return 1.0 if _leve() else 0.84 + 0.16 * sin(_relogio * TAU * _hz())


## Quantas molduras o campo tem (dados > visual > molduras; 3, como os degraus da ideia).
func _n() -> int:
	return maxi(int(visual.get("molduras", 3)), 1)


## A mira no chão (o ângulo da tela desfeito da achatada), unitária.
func _mira_chao(h) -> Vector2:
	var a0: float = atan2(h.dir_olhar.y / ACHATA, h.dir_olhar.x)
	return Vector2(cos(a0), sin(a0))


## O plano da moldura `i` (0 = a de trás): `base` (o pé do meio, no mundo), `eixo` (o passo na tela de 1 px de largura no chão), `w` (a meia-largura, que cresce com o arco)
## e `alt` (a altura, em px de tela). O eixo é a perpendicular à mira vista de cima; de lado ele fica quase em pé e o painel some, então o x dele nunca cai abaixo de `lado_min`;
## e a parte vertical dele encolhe para `lado_inclina` com o quadrado do lado da mira: a projeção crua, de lado, esticava a moldura da frente num paralelogramo de 26x105 px
## (bem mais alto que o mecha, três agulhas inclinadas na tela); assim a altura de lado fica perto da de frente e as diagonais quase não mudam.
func _plano(h, i: int) -> Dictionary:
	var u := _mira_chao(h)
	var d := float(visual.get("distancia", 22.0)) + float(i) * float(visual.get("recuo", 8.0))
	var base: Vector2 = h.pos + Vector2(u.x, u.y * ACHATA) * d - Vector2(0.0, float(visual.get("solo", 2.0)))
	var eixo := Vector2(-u.y, u.x * ACHATA)
	var m := float(visual.get("lado_min", 0.3))
	if absf(eixo.x) < m:
		eixo.x = m if eixo.x >= 0.0 else -m
	eixo.y *= lerpf(1.0, float(visual.get("lado_inclina", 0.2)), u.x * u.x)
	var k := arco_graus() / maxf(float(cfg.arco), 1.0)  # a Matriz Ampla alarga as molduras na proporção do arco
	var w := (float(visual.get("largura", 30.0)) + float(i) * float(visual.get("largura_passo", 6.0))) * k
	var alt := float(visual.get("altura", 44.0)) + float(i) * float(visual.get("altura_passo", 8.0))
	return {"base": base, "eixo": eixo, "w": w, "alt": alt}


## Um ponto da moldura `i`: `sx` de -1 a 1 na largura, `zy` de 0 (pé) a 1 (topo) na altura. Sem arredondar (quem desenha arredonda).
func _ponto(h, i: int, sx: float, zy: float) -> Vector2:
	var p := _plano(h, i)
	return p.base + p.eixo * (sx * float(p.w)) - Vector2(0.0, zy * float(p.alt))


## As molduras do campo agora, de trás (a menor, perto do mecha) para a frente (a maior, mais longe): cada uma o hexágono de FORMA, 6 pontos em px inteiros do mundo.
func molduras(h) -> Array:
	var r: Array = []
	for i in _n():
		var pts := PackedVector2Array()
		for f in FORMA:
			pts.append(_ponto(h, i, f.x, f.y).round())
		r.append(pts)
	return r


## A chave de ordem do nó no y-sort do mundo: a base do meio do campo, em px inteiros. Mirando de lado ela empata com o mecha; 1 px a mais deixa o painel por cima.
func chave_ordem(h) -> Vector2:
	var u := _mira_chao(h)
	var d := float(visual.get("distancia", 22.0)) + float(_n() - 1) * 0.5 * float(visual.get("recuo", 8.0))
	var c: Vector2 = (h.pos + Vector2(u.x, u.y * ACHATA) * d).round()
	if absf(c.y - h.pos.y) < 1.0:
		c.y = roundf(h.pos.y) + 1.0
	return c


## Onde o golpe que vem de `de` bate no campo: no plano da moldura da frente, do lado de quem bateu (a fração do arco vira a fração da largura), a 45% da altura.
func ponto_golpe(h, de: Vector2) -> Vector2:
	var u := _mira_chao(h)
	var a := atan2((de.y - h.pos.y) / ACHATA, de.x - h.pos.x)
	var rel := wrapf(a - atan2(u.y, u.x), -PI, PI)
	var meio := deg_to_rad(arco_graus() * 0.5)
	var sx := clampf(rel / maxf(meio, 0.01), -1.0, 1.0) * 0.8
	return _ponto(h, _n() - 1, sx, 0.45).round()


## A frequência da linha de varredura que sobe pela moldura da frente, no máximo 2 Hz.
func _hz_varredura() -> float:
	return minf(float(visual.get("varredura_hz", 0.8)), 2.0)


## A altura (0 a 1) da linha de varredura agora; -1 no perfil Baixo (sem brilho que corre).
func varredura() -> float:
	return -1.0 if _leve() else fposmod(_relogio * _hz_varredura(), 1.0)


## A meia-largura (fração) do hexágono de FORMA na altura `zy` (0 a 1), pelo lado direito dele.
func _meia(zy: float) -> float:
	if zy <= FORMA[2].y:
		return lerpf(FORMA[1].x, FORMA[2].x, zy / FORMA[2].y)
	return lerpf(FORMA[2].x, FORMA[3].x, (zy - FORMA[2].y) / (FORMA[3].y - FORMA[2].y))


func _desenhar() -> void:
	var h = mundo.heroi
	if not ativa(h):
		return
	var esc = combate.escudo
	var frac: float = float(h.def) / maxf(float(h.def_max), 0.001)
	var cor := COR_BASE.lerp(COR_ALERTA, clampf((ALERTA_ATE - frac) / (ALERTA_ATE - ALERTA_FIM), 0.0, 1.0))
	var pulso := _pulso()
	var clarao := _flash_t / 0.18
	var aparece := clampf(_sobe_t / ENTRA_S, 0.0, 1.0)
	var o := no.position  # os pontos são do mundo: o desenho é relativo ao nó
	var n := _n()
	# a marca no chão, fina, onde a casca empurra (o alcance, para o jogador entender)
	var chao: PackedVector2Array = esc.pontos_na_grade(esc.pontos_arco(h, arco_graus(), _raio()))
	for k in chao.size():
		chao[k] -= o
	no.draw_polyline(chao, Color(cor.r, cor.g, cor.b, float(visual.get("chao_alfa", 0.3)) * aparece), 1.0)
	var lista := molduras(h)
	for i in n:
		var entra := clampf(aparece * float(n) - float(i), 0.0, 1.0)  # em degraus: a de trás primeiro
		if entra <= 0.0:
			continue
		var frente := i == n - 1
		var pts: PackedVector2Array = lista[i]
		for k in pts.size():
			pts[k] -= o
		var fundo := (0.07 + 0.03 * float(i)) * pulso + (0.3 * clarao if frente else 0.0)
		no.draw_colored_polygon(pts, Color(cor.r, cor.g, cor.b, fundo * entra))
		var fechado := PackedVector2Array(pts)
		fechado.append(pts[0])
		var forte := minf((0.95 + 0.05 * float(i)) * (pulso if frente else 1.0), 1.0)  # as de trás fortes também: são elas que fazem os degraus aparecerem por cima do mecha
		no.draw_polyline(fechado, Color(cor.r, cor.g, cor.b, forte * entra), 2.0)
		if frente:  # a grade da moldura da frente: traços em pé dividindo o painel
			var paineis := maxi(int(visual.get("paineis", 3)), 1)
			for j in range(1, paineis):
				var sx := -1.0 + 2.0 * float(j) / float(paineis)
				var a := _ponto(h, i, sx * FORMA[1].x, 0.0).round() - o
				var b := _ponto(h, i, sx * FORMA[3].x, 1.0).round() - o
				no.draw_line(a, b, Color(cor.r, cor.g, cor.b, 0.3 * entra), 1.0)
	if _leve():
		return
	var zv := varredura()  # a linha de varredura que sobe pela moldura da frente (uma volta a cada 1,25 s, sem piscar)
	if zv >= 0.0:
		var mw := _meia(zv)
		var a := _ponto(h, n - 1, -mw, zv).round() - o
		var b := _ponto(h, n - 1, mw, zv).round() - o
		no.draw_line(a, b, Color(1, 1, 1, 0.55 * aparece), 1.0)
	if _flash_t > 0.0:  # o golpe absorvido: faíscas no ponto do campo
		var tam := (1.0 - clarao) * 12.0 + 4.0
		var c := (_impacto - o).round()
		for i in 5:
			var d := Vector2.from_angle(TAU * float(i) / 5.0 + 0.3)
			no.draw_line((c + d * tam * 0.4).round(), (c + d * tam).round(), Color(COR_CIANO.r, COR_CIANO.g, COR_CIANO.b, clarao), 2.0)
		var r := maxi(roundi(2.0 * clarao), 1)
		no.draw_rect(Rect2(c - Vector2(r, r), Vector2(2 * r, 2 * r)), Color(1, 1, 1, clarao))

extends RefCounted
## A MATRIZ DE DEFESA do LightWolf (LW-3, #511): o secundário (botão direito, segurar) do mecha. Como quase não existe projétil inimigo no jogo, a matriz da D.Va virou uma
## BARREIRA EM ARCO (140 graus, na direção da mira) que faz duas coisas enquanto está erguida:
##  - EMPURRA: todo monstro que chega na CASCA (`casca` px do herói, dentro do arco) leva um empurrão para fora (`m.emp`, `empurrao` px/s dividido pelo peso dele). Sem dano
##    e sem flash por monstro (item 7, reduzir piscadas): a barreira é uma parede que segura a horda, não uma arma.
##  - ABSORVE: o dano que vem de dentro do arco (contato, ataques anunciados no chão e golpes do chefe; `Heroi.levar_dano` chama `absorver`) sai da BARRA DE DEFESA, 1 para 1.
##    O que passa do que a barra tem VAZA para a vida. A barra é a mesma do escudo do Nick (campos `def` e `def_max` do herói, `defesa_regen_mult` da dificuldade, reposição pela
##    cura): o bloco `matriz > barra` de dados/v2_secundario.json só sobrepõe as chaves do `escudo > barra` (gasta 5 por segundo só por segurar, ~20 s; zerou = SOBRECARGA até voltar a 35%;
##    recarga de 6 por segundo depois de 2 s sem segurar). Quem gasta e quem recarrega é o herói (`_gastar_defesa`, `_recuperar_defesa`), o mesmo código do escudo.
## As evoluções que curam pelo dano absorvido são cartas do LW-6; aqui só se conta o que foi absorvido (`absorvido`), que é o gancho delas.
##
## O herói (v2/heroi.gd) cuida da entrada e do estado (`escudo_ativo` serve aos dois, velocidade, a barra); este módulo cuida da geometria (`cobre`), da absorção, do empurrão
## (`atualizar`, no tempo do mundo) e do visual (`efeitos`, no relógio de parede). O VISUAL é 100% em código (nenhuma folha): uma faixa azul clara em arco no chão, na casca,
## com traços de painel hexagonal, um brilho que corre pelo arco e, quando absorve, um clarão e faíscas no ponto do golpe. O brilho pulsa a 1,5 Hz (nunca acima de 2 Hz) e o clarão
## de absorção tem intervalo mínimo; no perfil Baixo (sem partículas) fica só a faixa, parada. Com a defesa abaixo de 35% a faixa vai ficando laranja (inteira em 5%), sem piscar.
##
## API: montar(c, camada), limpar(), ativa(h) -> bool, cobre(h, de) -> bool, absorver(h, valor, de) -> float [o que vazou], ergueu(h), abaixou(h), atualizar(dt), efeitos(dt).

const ACHATA := 0.62  # o chão visto de lado (a mesma do escudo, da ruptura e dos avisos)
const COR_BASE := Color(0.62, 0.86, 1.0)
const COR_CIANO := Color(0.5, 0.95, 1.0)
const COR_ALERTA := Color(1.0, 0.62, 0.3)
const ALERTA_ATE := 0.35  # fração da barra abaixo da qual a faixa começa a esquentar (laranja inteira em ALERTA_FIM)
const ALERTA_FIM := 0.05
const PTS := 20  # pontos do arco desenhado

var combate
var mundo
var cfg: Dictionary = {}  # dados/v2_secundario.json > matriz
var visual: Dictionary = {}  # dados/v2_secundario.json > matriz > visual
var no: Node2D  # a camada glow (aditiva): o desenho da barreira
var absorvido := 0.0  # a defesa gasta absorvendo golpes na partida (o gancho das cartas de cura do LW-6)
var golpes := 0  # quantos golpes a matriz absorveu
var vazado := 0.0  # o dano que passou da barra e foi para a vida
var empurrados := 0  # quantos monstros levaram empurrão no quadro de agora (testes e calibragem)
var ultimo: Dictionary = {}  # o último golpe absorvido (testes): valor, absorvido, vazou, de
var _relogio := 0.0
var _sobe_t := 9.0  # s desde que ergueu (a faixa aparece em 0,12 s)
var _flash_t := 0.0  # s do clarão do último golpe absorvido
var _flash_cd := 0.0  # s até poder mostrar outro clarão (o limite de piscadas)
var _impacto := Vector2.ZERO  # o ponto do último golpe, no mundo
var _desenhou := false


func montar(c, camada: Node) -> void:
	combate = c
	mundo = c.mundo
	var d: Dictionary = Dados.json("v2_secundario")
	cfg = d.get("matriz", {})
	visual = cfg.get("visual", {})
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	no = Node2D.new()
	no.material = mat
	no.draw.connect(_desenhar)
	camada.add_child(no)


## Partida nova.
func limpar() -> void:
	absorvido = 0.0
	golpes = 0
	vazado = 0.0
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
	return combate.escudo.cobre_arco(h, de, float(cfg.arco))


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
	ultimo = {"valor": valor, "absorvido": gasto, "vazou": vaza, "de": de}
	_clarao(h, de)
	return vaza


## O clarão do golpe absorvido no ponto da barreira do lado de quem bateu. Intervalo mínimo entre dois (dados > visual > impacto_min): nunca mais que 2 por segundo.
func _clarao(h, de: Vector2) -> void:
	if _flash_cd > 0.0:
		return
	_flash_cd = float(visual.get("impacto_min", 0.5))
	_flash_t = 0.18
	var ang := atan2((de.y - h.pos.y) / ACHATA, de.x - h.pos.x)
	var r := _raio()
	var centro: Vector2 = h.pos + Vector2(0, -8)
	_impacto = centro + Vector2(cos(ang) * r, sin(ang) * r * ACHATA)
	combate.audio.tocar("impacto", 0.85, -3.0, 0.04)
	mundo.cam.tremer(0.8, 0.08)
	if not _leve():
		combate.fx.estouro(_impacto, COR_CIANO, 3)
	combate.fx.luz_rapida(_impacto, COR_BASE, 1.3, 36.0, 0.16)


func ergueu(_h) -> void:
	_sobe_t = 0.0
	combate.audio.tocar("ruptura_tique", 1.45, -6.0, 0.05)


## Soltou o botão ou a barra zerou: sobrecarga (`def_quebrado`) faz a barreira estourar; soltar só apaga.
func abaixou(h) -> void:
	if h == null or not h.def_quebrado:
		return
	var centro: Vector2 = h.pos + Vector2(0, -8) + h.dir_olhar * _raio() * 0.8
	combate.audio.tocar("impacto", 0.55, 0.0, 0.05)
	combate.audio.tocar("critico", 0.7, -5.0, 0.0)
	mundo.cam.tremer(1.5, 0.12)
	if not _leve():
		combate.fx.estouro(centro, COR_BASE, 8)
	combate.fx.luz_rapida(centro, COR_BASE, 1.6, 48.0, 0.2)


## O empurrão, todo quadro do mundo enquanto erguida: quem está na casca e dentro do arco é empurrado para longe do herói. Não toca na vida nem no flash do monstro.
func atualizar(_dt: float) -> void:
	empurrados = 0
	var h = mundo.heroi
	if not ativa(h):
		return
	var casca := float(cfg.casca)
	var forca := float(cfg.empurrao)
	var graus := float(cfg.arco)
	var hp: Vector2 = h.pos
	for m in mundo.monstros:
		if not m.vivo or m.morrendo:
			continue
		var rel: Vector2 = m.pos - hp
		var lim: float = casca + float(m.raio)
		if absf(rel.x) > lim or absf(rel.y) > lim * ACHATA:
			continue
		if Vector2(rel.x, rel.y / ACHATA).length() > lim:
			continue
		if not combate.escudo.cobre_arco(h, m.pos, graus):
			continue
		var rumo: Vector2 = rel.normalized() if rel.length() > 0.5 else h.dir_olhar
		var v: float = forca * float(m.emp_mult) / maxf(float(m.peso), 0.25)
		if m.emp.dot(rumo) < v:
			m.emp = rumo * v
		empurrados += 1


## O visual no relógio de parede: só redesenha enquanto a barreira está erguida (e uma vez ao apagar).
func efeitos(dt: float) -> void:
	_relogio += dt
	_sobe_t = minf(_sobe_t + dt, 9.0)
	_flash_t = maxf(_flash_t - dt, 0.0)
	_flash_cd = maxf(_flash_cd - dt, 0.0)
	var h = mundo.heroi
	var ligada := ativa(h)
	if ligada or _desenhou:
		_desenhou = ligada
		no.queue_redraw()


## O raio da faixa no chão: a casca menos um pouco, para o traço de fora ficar onde o empurrão começa.
func _raio() -> float:
	return float(cfg.casca) - float(visual.get("raio_extra", 3.0))


## O perfil Baixo (partículas em "poucas" ou "nenhuma"): sem brilho que corre, pulso, faíscas nem partículas.
func _leve() -> bool:
	if mundo == null or not mundo.has_method("_nivel_particulas"):
		return false
	return float(mundo._nivel_particulas().get("efe_particulas", 1.0)) < 0.5


func _desenhar() -> void:
	var h = mundo.heroi
	if not ativa(h):
		return
	var esc = combate.escudo
	var leve := _leve()
	var frac: float = float(h.def) / maxf(float(h.def_max), 0.001)
	var cor := COR_BASE.lerp(COR_ALERTA, clampf((ALERTA_ATE - frac) / (ALERTA_ATE - ALERTA_FIM), 0.0, 1.0))
	var pulso := 1.0 if leve else 0.84 + 0.16 * sin(_relogio * TAU * minf(float(visual.get("pulso_hz", 1.5)), 2.0))
	var entra := clampf(_sobe_t / 0.12, 0.0, 1.0)
	var clarao := _flash_t / 0.18
	var r := _raio()
	var faixa := float(visual.get("faixa", 7.0))
	var graus := float(cfg.arco)
	var fora: PackedVector2Array = esc.pontos_arco(h, graus, r)
	var dentro: PackedVector2Array = esc.pontos_arco(h, graus, r - faixa)
	var poligono := PackedVector2Array(fora)
	for i in range(dentro.size() - 1, -1, -1):
		poligono.append(dentro[i])
	no.draw_colored_polygon(poligono, Color(cor.r, cor.g, cor.b, (0.3 * pulso + 0.35 * clarao) * entra))
	no.draw_polyline(fora, Color(cor.r, cor.g, cor.b, 1.0 * pulso * entra), 3.0)
	no.draw_polyline(dentro, Color(cor.r, cor.g, cor.b, 0.6 * entra), 1.0)
	# os painéis hexagonais: traços que cruzam a faixa, alternando a inclinação (um favo)
	var n := maxi(int(visual.get("paineis", 7)), 2)
	for i in range(1, n):
		var k := roundi(float(i) / float(n) * float(fora.size() - 1))
		var k2 := clampi(k + (1 if i % 2 == 0 else -1), 0, fora.size() - 1)
		no.draw_line(fora[k], dentro[k2], Color(cor.r, cor.g, cor.b, 0.7 * entra), 1.0)
	if leve:
		return
	# o brilho que corre pelo arco (uma volta a cada 1,25 s, sem piscar)
	var u := fposmod(_relogio * 0.8, 1.0)
	var k0 := int(u * float(fora.size() - 4))
	no.draw_polyline(fora.slice(k0, k0 + 4), Color(1, 1, 1, 0.8 * entra), 2.0)
	if _flash_t > 0.0:  # o golpe absorvido: faíscas no ponto da barreira
		var tam := (1.0 - clarao) * 12.0 + 4.0
		for i in 5:
			var d := Vector2.from_angle(TAU * float(i) / 5.0 + 0.3)
			no.draw_line(_impacto + d * tam * 0.4, _impacto + d * tam, Color(COR_CIANO.r, COR_CIANO.g, COR_CIANO.b, clarao), 2.0)
		no.draw_circle(_impacto, 2.5 * clarao, Color(1, 1, 1, clarao))

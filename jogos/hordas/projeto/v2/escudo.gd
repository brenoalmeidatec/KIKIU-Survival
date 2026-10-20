extends RefCounted
## O tiro SECUNDÁRIO da v2 (botão direito do mouse ou gatilho esquerdo), no padrão Overwatch: botão direito = secundário (definido por herói),
## E / LB = habilidade (a ruptura, v2/ruptura.gd), Q / RB = especial (um por herói, v2/especial.gd). Para o herói de hoje o
## secundário é o ESCUDO: segurar ergue um escudo na frente do herói (arco de ~120 graus na direção da mira) que bloqueia o dano que vem de
## dentro do arco (contato dos monstros, ataques anunciados e ataques do chefe). O herói anda a ~60%, não corre nem golpeia e o escudo gasta o
## MESMO fôlego da corrida; zerar o fôlego deixa cansado e o escudo cai. Bloqueio PERFEITO (nos primeiros ~0,15 s depois de erguer): não gasta
## fôlego e empurra e atordoa quem bateu. Soltar volta ao fôlego normal.
##
## Qual secundário cada herói tem é DADO (dados/v2_secundario.json > padrao e herois > chave do herói), para que a branch de heróis mapeie
## outro secundário depois sem mexer no código: aqui só existe o id "escudo"; id desconhecido deixa o botão direito sem efeito.
##
## O herói (v2/heroi.gd) cuida da entrada e do estado (`escudo_ativo`, `escudo_t`, velocidade, fôlego); este módulo cuida da geometria
## (`cobre`), do bloqueio (`bloquear`), do visual (um Node2D aditivo na camada glow, sem nó por quadro) e do som. Dono: o combate (`combate.escudo`).
##
## API: montar(c, camada), limpar(), id_de(chave) -> String, ativo_para(chave) -> bool, para_heroi(chave), cobre(h, de) -> bool, raio(h) -> float, arco(h) -> float, pontos_do_arco(h),
## ergueu(h), abaixou(h), bloquear(h, valor, de, quem) -> bool [perfeito?], efeitos(dt) [relógio de parede: o visual], resumo().

const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x (a mesma da ruptura e dos avisos)
const COR_AZUL := Color(0.45, 0.82, 1.0)
const COR_OURO := Color(1.0, 0.85, 0.3)
const PTS := 20  # pontos do arco desenhado
const Progresso := preload("res://v2/progresso.gd")  # bonus_por_nivel: o crescimento do raio por nível (a mesma regra do golpe, outra tabela)

var combate
var mundo
var cfg: Dictionary = {}  # dados/v2_secundario.json > escudo
var padrao := "escudo"
var herois: Dictionary = {}  # chave do herói -> id do secundário (os testes mexem aqui)
var no: Node2D
var bloqueios := 0  # testes: quantos golpes o escudo já barrou
var perfeitos := 0  # testes: quantos foram perfeitos
var ultimo: Dictionary = {}  # o último bloqueio (testes): perfeito, valor, empurrao, atordoa
var _flash_t := 0.0  # s do clarão do último bloqueio (comum)
var _perf_t := 0.0  # s do clarão dourado do bloqueio perfeito
var _desenhou := false
var _impacto := Vector2.ZERO


func montar(c, camada: Node) -> void:
	combate = c
	mundo = c.mundo
	var d: Dictionary = Dados.json("v2_secundario")
	cfg = d.escudo
	padrao = str(d.get("padrao", "escudo"))
	herois = d.get("herois", {})
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	no = Node2D.new()
	no.material = mat
	no.draw.connect(_desenhar)
	camada.add_child(no)


## Partida nova.
func limpar() -> void:
	bloqueios = 0
	perfeitos = 0
	ultimo = {}
	_flash_t = 0.0
	_perf_t = 0.0
	_desenhou = false
	if no != null:
		no.queue_redraw()


## O id do secundário do herói `chave` (dados > herois, senão o padrão).
func id_de(chave: String) -> String:
	return str(herois.get(chave, padrao))


## O secundário deste herói é o escudo?
func ativo_para(chave: String) -> bool:
	return id_de(chave) == "escudo"


## O raio do desenho deste herói agora: o do dado MAIS o crescimento por nível (dados > escudo.raio_por_nivel). Não usa a área das cartas
## (h.m_area): o escudo do nível 1 é o de antes, para todo herói. Lido pelo desenho (pontos_do_arco) e pelo ponto da faísca.
func raio(h) -> float:
	return float(cfg.raio) * (1.0 + Progresso.bonus_por_nivel(int(h.nivel), cfg.raio_por_nivel))


## A abertura do escudo deste herói agora, em graus: a do dado MAIS o crescimento por nível (dados > escudo.arco_por_nivel). É a COBERTURA
## do bloqueio (`cobre` barra tudo o que vem dentro dela) e o arco do desenho: o escudo cresce em quanto protege, não só em quanto aparece.
func arco(h) -> float:
	return float(cfg.arco) + Progresso.bonus_por_nivel(int(h.nivel), cfg.arco_por_nivel)


## Os pontos do arco da base do escudo no chão (projetados na tela, de `h.pos + (0, -8)`): é daqui que o desenho tira o raio e a abertura,
## e é isto que o teste mede.
func pontos_do_arco(h) -> PackedVector2Array:
	var c: Vector2 = h.pos + Vector2(0, -8)
	var a0: float = atan2(h.dir_olhar.y / ACHATA, h.dir_olhar.x)  # o ângulo no chão, de volta para a tela
	var meio := deg_to_rad(arco(h) * 0.5)
	var r := raio(h)
	var pts := PackedVector2Array()
	for i in PTS + 1:
		var a := a0 - meio + 2.0 * meio * float(i) / float(PTS)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * ACHATA))
	return pts


## O dano que vem de `de` (posição no mundo) cai dentro do arco do escudo? A conta é no chão (y dividido pela achatada), a mesma do desenho.
func cobre(h, de: Vector2) -> bool:
	var rel: Vector2 = de - h.pos
	rel = Vector2(rel.x, rel.y / ACHATA)
	if rel.length() < 0.5:
		return true  # em cima do herói: vem da frente de quem está encostado
	var d := Vector2(h.dir_olhar.x, h.dir_olhar.y / ACHATA).normalized()
	return rel.normalized().dot(d) >= cos(deg_to_rad(arco(h) * 0.5))


func ergueu(_h) -> void:
	combate.audio.tocar("ruptura_tique", 1.5, -6.0, 0.05)


func abaixou(_h) -> void:
	pass


## O herói barrou um golpe de `valor` que vinha de `de`; `quem` é o monstro que bateu (null: ataque de área, sem alvo para empurrar).
## Devolve true se foi PERFEITO. Comum: gasta um pouco de fôlego e empurra de leve; perfeito: não gasta e empurra e atordoa forte.
func bloquear(h, valor: float, de: Vector2, quem) -> bool:
	var perfeito: bool = h.escudo_t <= float((cfg.perfeito as Dictionary).janela)
	bloqueios += 1
	h.escudo_bloqueios += 1
	var p: Dictionary = cfg.perfeito
	var emp: float = float(p.empurrao) if perfeito else float(cfg.empurrao)
	var atordoa: float = float(p.atordoa) if perfeito else 0.0
	if perfeito:
		perfeitos += 1
		h.escudo_perfeitos += 1
	else:
		h._gastar(float(cfg.gasto_golpe))
	if quem != null:
		var longe: Vector2 = quem.pos - h.pos
		longe = longe.normalized() if longe.length() > 0.5 else h.dir_olhar
		quem.apanhar(0.0, longe * emp, atordoa)  # dano zero: só empurra e atordoa (elite vale metade e chefe nada, como em qualquer golpe)
	ultimo = {"perfeito": perfeito, "valor": valor, "empurrao": emp, "atordoa": atordoa}
	# o clarão, as faíscas e o som
	var fx = combate.fx
	var entrada := Vector2(de.x - h.pos.x, (de.y - h.pos.y) / ACHATA).normalized()
	if entrada.length_squared() < 0.1:
		entrada = Vector2(h.dir_olhar.x, h.dir_olhar.y / ACHATA).normalized()
	_impacto = Vector2(entrada.x, entrada.y * ACHATA) * raio(h) + Vector2(0, -20)
	var ponto: Vector2 = h.pos + _impacto
	var cor := COR_OURO if perfeito else COR_AZUL
	fx.estouro(ponto, cor, 6 if perfeito else 3)
	fx.luz_rapida(ponto, cor, 1.6, 40.0, 0.18)
	if perfeito:
		_perf_t = 0.22
		combate.audio.tocar("critico", 1.2, -2.0, 0.0)
		combate.audio.tocar("ruptura_tique", 1.25, 0.0, 0.0)
		combate.hit_stop(float(p.hit_stop))
		mundo.cam.tremer(float(p.tremor), 0.14)
	else:
		_flash_t = 0.14
		combate.audio.tocar("impacto", 0.7, -1.0, 0.04)
		mundo.cam.tremer(1.0, 0.08)
	return perfeito


## Os números de agora para o painel de status.
func resumo() -> Dictionary:
	return {
		"arco": arco(mundo.heroi) if mundo.heroi != null else float(cfg.arco),
		"mov": float(cfg.mov),
		"gasto": float(cfg.gasto),
		"perfeito_janela": float((cfg.perfeito as Dictionary).janela),
	}


## O visual no relógio de parede: o arco translúcido enquanto ergue, com clarão ao bloquear. Só redesenha enquanto há algo (e uma vez ao apagar).
func efeitos(dt: float) -> void:
	_flash_t = maxf(_flash_t - dt, 0.0)
	_perf_t = maxf(_perf_t - dt, 0.0)
	var h = mundo.heroi
	var ativo: bool = h != null and h.escudo_ativo
	if ativo or _flash_t > 0.0 or _perf_t > 0.0 or _desenhou:
		_desenhou = ativo
		no.queue_redraw()


func _desenhar() -> void:
	var h = mundo.heroi
	if h == null or not h.escudo_ativo:
		return
	var c: Vector2 = h.pos + Vector2(0, -8)
	var cor := COR_AZUL
	var alfa := 0.2
	if _perf_t > 0.0:
		cor = COR_OURO
		alfa = 0.55
	elif _flash_t > 0.0:
		cor = Color.WHITE
		alfa = 0.45
	elif h.escudo_t <= float((cfg.perfeito as Dictionary).janela):
		cor = COR_OURO.lerp(COR_AZUL, h.escudo_t / maxf(float((cfg.perfeito as Dictionary).janela), 0.001))  # a janela perfeita se lê no arco
		alfa = 0.35
	var pts := pontos_do_arco(h)
	var leque := PackedVector2Array([c])
	leque.append_array(pts)
	# Barreira curva elevada: a base continua no mesmo arco de cobertura.
	no.draw_colored_polygon(leque, Color(cor.r, cor.g, cor.b, alfa * 0.18))
	var topo := PackedVector2Array()
	var altura := 24.0
	for q in pts:
		topo.append(q + Vector2(0, -altura))
	for i in PTS:
		var painel := PackedVector2Array([pts[i], pts[i + 1], topo[i + 1], topo[i]])
		no.draw_colored_polygon(painel, Color(cor.r * 0.65, cor.g * 0.8, cor.b, alfa * (0.45 if i % 2 == 0 else 0.3)))
	no.draw_polyline(topo, Color(cor.r, cor.g, cor.b, alfa * 0.35), 7.0)
	no.draw_polyline(topo, Color(cor.r, cor.g, cor.b, minf(alfa * 3.0, 0.95)), 2.0)
	no.draw_polyline(pts, Color(cor.r, cor.g, cor.b, alfa * 1.5), 1.0)
	for i in range(0, PTS + 1, 4):
		no.draw_line(pts[i], topo[i], Color(cor.r, cor.g, cor.b, alfa * 1.7), 1.5)
	# Runa central em losango, presa à barreira e à direção da mira.
	var centro := topo[PTS >> 1] + Vector2(0, altura * 0.5)
	var runa := PackedVector2Array([centro + Vector2(0, -8), centro + Vector2(5, 0), centro + Vector2(0, 8), centro + Vector2(-5, 0), centro + Vector2(0, -8)])
	no.draw_polyline(runa, Color(cor.r, cor.g, cor.b, 0.8), 1.5)
	if _flash_t > 0.0 or _perf_t > 0.0:
		var t := _perf_t / 0.22 if _perf_t > 0.0 else _flash_t / 0.14
		var impacto: Vector2 = h.pos + _impacto
		var tamanho := (1.0 - t) * 16.0 + 5.0
		for i in 8 if _perf_t > 0.0 else 4:
			var d := Vector2.from_angle(TAU * float(i) / (8.0 if _perf_t > 0.0 else 4.0))
			no.draw_line(impacto + d * tamanho * 0.4, impacto + d * tamanho, Color(cor.r, cor.g, cor.b, t), 2.0)
		no.draw_circle(impacto, 3.0 * t, Color(1.0, 0.97, 0.8, t))

extends RefCounted
## O tiro SECUNDÁRIO da v2 (botão direito do mouse ou gatilho esquerdo), no padrão Overwatch: botão direito = secundário (definido por herói),
## E / LB = habilidade (a ruptura, v2/ruptura.gd), Q = ultimate (reservado: só a ação de entrada e um slot vazio no HUD). Para o herói de hoje o
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
## API: montar(c, camada), limpar(), id_de(chave) -> String, ativo_para(chave) -> bool, para_heroi(chave), cobre(h, de) -> bool,
## ergueu(h), abaixou(h), bloquear(h, valor, de, quem) -> bool [perfeito?], efeitos(dt) [relógio de parede: o visual], resumo().

const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x (a mesma da ruptura e dos avisos)
const COR_AZUL := Color(0.45, 0.82, 1.0)
const COR_OURO := Color(1.0, 0.85, 0.3)
const PTS := 14  # pontos do arco desenhado

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


## O dano que vem de `de` (posição no mundo) cai dentro do arco do escudo? A conta é no chão (y dividido pela achatada), a mesma do desenho.
func cobre(h, de: Vector2) -> bool:
	var rel: Vector2 = de - h.pos
	rel = Vector2(rel.x, rel.y / ACHATA)
	if rel.length() < 0.5:
		return true  # em cima do herói: vem da frente de quem está encostado
	var d := Vector2(h.dir_olhar.x, h.dir_olhar.y / ACHATA).normalized()
	return rel.normalized().dot(d) >= cos(deg_to_rad(float(cfg.arco) * 0.5))


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
	var ponto: Vector2 = h.pos + Vector2(0, -10) + h.dir_olhar * float(cfg.raio)
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
		"arco": float(cfg.arco),
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
	var a0: float = atan2(h.dir_olhar.y / ACHATA, h.dir_olhar.x)  # o ângulo no chão, de volta para a tela
	var meio := deg_to_rad(float(cfg.arco) * 0.5)
	var r := float(cfg.raio)
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
	var pts := PackedVector2Array()
	for i in PTS + 1:
		var a := a0 - meio + 2.0 * meio * float(i) / float(PTS)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * ACHATA))
	var leque := PackedVector2Array([c])
	leque.append_array(pts)
	no.draw_colored_polygon(leque, Color(cor.r, cor.g, cor.b, alfa * 0.45))
	no.draw_polyline(pts, Color(cor.r, cor.g, cor.b, minf(alfa * 3.0, 0.95)), 2.0)

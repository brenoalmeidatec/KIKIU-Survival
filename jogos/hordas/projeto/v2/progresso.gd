extends RefCounted
## XP, nível e melhorias da v2. O XP vem dos orbes (combate.coletar). Ao encher a barra: sobe o nível (sinal nivel_subiu do mundo), câmera
## lenta de 0,4 s e a escolha de 1 entre 3 melhorias (cartas), que pausa o mundo até o jogador escolher. Várias subidas seguidas viram
## várias escolhas, uma depois da outra. Curva de nível, cartas e valores ficam em dados/v2_combate.json ("xp", "nivel", "melhorias").

var combate
var cfg: Dictionary
var melhorias := {}  # id da carta -> quantas vezes pegou
var pendentes := 0  # níveis subidos que ainda esperam a escolha
var cartas: Array = []  # as 3 cartas na tela
var escolhidas := 0  # quantas melhorias o jogador já escolheu (testes)


func montar(c) -> void:
	combate = c
	cfg = c.cfg
	var h = c.mundo.heroi
	if h != null:
		h.xp_proximo = xp_para(1)


## XP que falta para sair do nível `n`: base + passo*(n-1) + quad*(n-1)^2.
func xp_para(n: int) -> float:
	var k := float(n - 1)
	var x: Dictionary = cfg.xp
	return roundf(float(x.base) + float(x.passo) * k + float(x.quad) * k * k)


func zerar() -> void:
	melhorias.clear()
	pendentes = 0
	cartas.clear()
	escolhidas = 0
	var h = combate.mundo.heroi
	if h != null:
		h.xp = 0.0
		h.nivel = 1
		h.xp_proximo = xp_para(1)


func ganhar_xp(v: float) -> void:
	var h = combate.mundo.heroi
	if not h.vivo():
		return
	h.xp += v
	while h.xp >= h.xp_proximo:
		h.xp -= h.xp_proximo
		h.nivel += 1
		h.xp_proximo = xp_para(h.nivel)
		h.curar(h.vida_max * float(cfg.heroi.cura_nivel))
		pendentes += 1
		combate.nivel_subiu(h.nivel)
	if pendentes > 0 and combate.lento_acao == "" and not combate.pausado and combate.jogo == "jogando":
		combate.camera_lenta("nivel", float(cfg.nivel.camera_lenta), float(cfg.nivel.escala_lenta))


## Sorteia até 3 cartas diferentes entre as que ainda não chegaram ao máximo e abre a escolha (pausa o mundo).
func abrir_escolha() -> void:
	var pool: Array = []
	for c in cfg.melhorias:
		if int(melhorias.get(c.id, 0)) < int(c.max):
			pool.append(c)
	pool.shuffle()
	cartas = pool.slice(0, 3)
	if cartas.is_empty():  # tudo no máximo: uma carta de cura para não travar
		cartas = [{"id": "cura", "nome": "Alma renovada", "desc": "Cura toda a vida", "stat": "cura", "valor": 0, "max": 99}]
	combate.jogo = "escolha"
	combate.pausado = true
	combate.telas.mostrar_escolha(cartas, combate.mundo.heroi.nivel)


func escolher(i: int) -> void:
	if i < 0 or i >= cartas.size():
		return
	var c: Dictionary = cartas[i]
	aplicar(c)
	escolhidas += 1
	pendentes = maxi(0, pendentes - 1)
	cartas = []
	combate.telas.esconder()
	combate.pausado = false
	combate.jogo = "jogando"
	combate.audio.tocar("escolher", 1.0, 0.0, 0.0)
	var h = combate.mundo.heroi
	combate.fx.onda(h.pos + Vector2(0, -12), Color(1.0, 0.9, 0.6, 0.9), 44.0, 0.25)
	if pendentes > 0:
		combate.camera_lenta("nivel", float(cfg.nivel.camera_lenta), float(cfg.nivel.escala_lenta))


func aplicar(c: Dictionary) -> void:
	var h = combate.mundo.heroi
	var v := float(c.valor)
	match str(c.stat):
		"dano":
			h.m_dano += v / 100.0
		"vel_ataque":
			h.m_vel_ataque += v / 100.0
		"area":
			h.m_area += v / 100.0
		"vel_mov":
			h.m_vel_mov += v / 100.0
		"vida":
			h.vida_max += v
			h.curar(v)
		"ima":
			h.m_ima += v / 100.0
		"critico":
			h.m_critico += v / 100.0
		"cura":
			h.curar(h.vida_max)
	melhorias[c.id] = int(melhorias.get(c.id, 0)) + 1


static func texto_carta(c: Dictionary) -> String:
	return str(c.desc).replace("{v}", str(int(c.valor)))

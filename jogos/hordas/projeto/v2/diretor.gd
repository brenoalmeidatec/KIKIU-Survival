extends RefCounted
## Diretor de ondas da v2: faz nascer monstros FORA DA TELA, numa faixa em volta do que a câmera mostra (sempre dentro da área andável do
## mapa, nunca em cima de uma árvore). Começa leve e aperta com o tempo da partida: a taxa de nascimento e o teto de monstros vivos sobem
## aos poucos, os monstros ficam mais fortes por minuto e, a cada `onda_cada` segundos, vem uma ONDA FORTE (um anel de monstros de uma vez,
## com cavaleiros). Tudo vem de dados/v2_combate.json ("diretor"). O diretor roda no tempo do mundo (não conta durante hit-stop nem pausa).

const Colisao := preload("res://v2/colisao.gd")

var combate
var mundo
var cfg: Dictionary
var acum := 0.0  # monstros "devidos" (taxa x tempo)
var proxima_onda := 0.0
var ondas := 0  # quantas ondas fortes já vieram
var nascidos := 0  # total nascido pelo diretor (testes)
var rng := RandomNumberGenerator.new()
var ligado := true


func montar(c) -> void:
	combate = c
	mundo = c.mundo
	cfg = c.cfg.diretor
	zerar()


func zerar() -> void:
	acum = 0.0
	ondas = 0
	nascidos = 0
	proxima_onda = float(cfg.onda_cada)
	rng.seed = 7777


## Taxa de nascimento (monstros/s) e teto de vivos no instante `t` da partida: sobem em linha reta até tempo_taxa/tempo_cap.
func taxa(t: float) -> float:
	return lerpf(float(cfg.taxa_ini), float(cfg.taxa_fim), clampf(t / float(cfg.tempo_taxa), 0.0, 1.0)) * mundo.fator_pesadelo("densidade_mult")


## O máximo de monstros vivos de uma vez (o teto dos dados; no Pesadelo sobe com a densidade). A opção "Máximo de inimigos
## vivos" (aba Gráficos, seção CPU) vale se for menor, como na v1 (scripts/hordas/diretor_hordas.gd).
func teto() -> int:
	var base := roundi(float(cfg.teto) * mundo.fator_pesadelo("densidade_mult"))
	var opcao = Config.g("max_inimigos")
	return mini(base, int(opcao)) if opcao != null else base


func limite(t: float) -> int:
	return roundi(lerpf(float(cfg.cap_ini), float(cfg.cap_fim), clampf(t / float(cfg.tempo_cap), 0.0, 1.0)) * mundo.fator_pesadelo("densidade_mult"))


func atualizar(dt: float) -> void:
	if not ligado:
		return
	var t: float = mundo.tempo_partida
	if t >= proxima_onda:
		onda_forte()
		proxima_onda += float(cfg.onda_cada)
	var folga: float = 0.4 if combate.chefes.vivo else 1.0  # com chefe em campo a horda dá uma folga
	acum += taxa(t) * dt * folga
	var vivos: int = mundo.monstros.size()
	var cap := roundi(float(limite(t)) * (0.6 if combate.chefes.vivo else 1.0))
	while acum >= 1.0:
		acum -= 1.0
		if vivos >= cap or vivos >= teto():
			acum = minf(acum, 1.0)  # no teto não junta devedor: quando abrir vaga, nasce um por vez
			break
		if nascer(sortear(t)):
			vivos += 1


func sortear(t: float) -> String:
	var total := 0
	for e in cfg.tipos:
		if t >= float(e.desde):
			total += int(e.peso)
	var r := rng.randi() % maxi(total, 1)
	for e in cfg.tipos:
		if t >= float(e.desde):
			r -= int(e.peso)
			if r < 0:
				return str(e.sprite)
	return str(cfg.tipos[0].sprite)


## Nasce um monstro fora da tela. Devolve false se não achou lugar (a taxa tenta de novo no próximo).
func nascer(nome: String, forcar: Variant = null) -> bool:
	var p: Variant = forcar if forcar != null else ponto_fora_da_tela()
	if p == null:
		return false
	var minutos: float = mundo.tempo_partida / 60.0
	var kv := 1.0 + float(cfg.vida_por_min) * minutos
	var kd := 1.0 + float(cfg.dano_por_min) * minutos
	var m = mundo.nascer_monstro(nome, p, true, kv, kd)
	if m == null:
		return false
	nascidos += 1
	return true


## Um ponto na faixa de margem_min a margem_max px além da borda da tela, dentro da área andável e livre de colisão. null se não achou.
func ponto_fora_da_tela() -> Variant:
	var tela: Rect2 = mundo.cam.retangulo()
	var lim: Rect2 = mundo.limite_andavel
	for i in 14:
		var m := rng.randf_range(float(cfg.margem_min), float(cfg.margem_max))
		var r := tela.grow(m)
		# ponto sorteado no perímetro do retângulo ampliado, com sorteio proporcional ao tamanho de cada lado
		var per := 2.0 * (r.size.x + r.size.y)
		var s := rng.randf() * per
		var p: Vector2
		if s < r.size.x:
			p = Vector2(r.position.x + s, r.position.y)
		elif s < r.size.x + r.size.y:
			p = Vector2(r.end.x, r.position.y + (s - r.size.x))
		elif s < 2.0 * r.size.x + r.size.y:
			p = Vector2(r.end.x - (s - r.size.x - r.size.y), r.end.y)
		else:
			p = Vector2(r.position.x, r.end.y - (s - 2.0 * r.size.x - r.size.y))
		if not lim.has_point(p):
			continue  # essa parte do anel cai fora do mapa: tenta outra
		if tela.has_point(p) or not Colisao.livre(p, 7.0):
			continue
		return p
	return null


## Onda forte: um anel de monstros de uma vez em volta da tela, com cavaleiros.
func onda_forte() -> void:
	ondas += 1
	var n := int(cfg.onda_base) + int(cfg.onda_mais) * (ondas - 1)
	var t: float = mundo.tempo_partida
	var elite := int(cfg.onda_elite) * ondas
	var folga: int = teto() - mundo.monstros.size()
	n = mini(roundi(float(n) * mundo.fator_pesadelo("densidade_mult")) + elite, maxi(folga, 0))
	for i in n:
		var nome := "inimigo_cavaleiro_oco" if i < elite else sortear(t)
		nascer(nome)
	combate.onda_forte(ondas)

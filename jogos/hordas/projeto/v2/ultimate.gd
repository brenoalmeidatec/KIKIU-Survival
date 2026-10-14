extends RefCounted
## O ULTIMATE da v2 (tecla Q ou RB), no padrão Overwatch: botão direito = secundário (v2/escudo.gd), E = habilidade com recarga (v2/ruptura.gd),
## Q = ultimate. Cada herói tem uma CARGA de 0 a 100 que enche com DANO CAUSADO (golpes, armas e a ruptura passam por combate.golpear e
## combate.ferir) e um pouco com ABATES, e NÃO enche com o tempo parado nem com o ultimate ativo. Q com a carga cheia dispara; a carga zera ao usar,
## ao morrer, ao reiniciar e ao voltar ao santuário (cena nova), e sobrevive a abrir cartas, baú e pausa (é só um número aqui, o mundo parado não
## o toca). Todos os números estão em dados/v2_ultimate.json (o ritmo, a duração, os multiplicadores).
##
## Qual ultimate cada herói tem é DADO (dados/v2_ultimate.json > herois, chave do herói -> id), como o secundário: um herói novo entra com uma
## linha lá, um bloco com o id e o código do efeito aqui (função `_efeito_<id>` não existe: o efeito é lido pelos ganchos `k_alcance`, `k_dano`,
## `imune_empurrao`, `combo_firme` e `onda_do_golpe`, que o combate e o herói consultam). Hoje só existe "corte_do_crepusculo" (Hazaki).
##
## CORTE DO CREPÚSCULO: por `dur` s a katana fica fortalecida (alcance x1,8, dano x1,6), cada golpe solta uma onda em linha que atravessa os
## monstros (a onda é a do v2/armas.gd), o combo de 3 não reinicia por demora e o herói não leva empurrão (leva dano). Ao ativar: hit-stop curto
## e câmera lenta de 0,3 s (o relógio do combate; passa para o tempo local do coop quando o PR #252 entrar). A duração corre no tempo do mundo.
##
## O herói publica o que o HUD lê (ult_carga 0 a 1, ult_pronto, ult_ativo, ult_t, ult_dur, ult_cor, ult_id): ver `_publicar`.
##
## API: montar(c, camada), limpar(), id_de(chave), tem(chave), dano_causado(real), abate(m), pode(h), acionar(h) -> bool, atualizar(dt)
## [tempo do mundo], efeitos(dt) [relógio de parede: o visual], ativo(), pronto(), k_alcance(), k_dano(), imune_empurrao(), combo_firme(),
## onda_do_golpe(origem, dir, dano), cor(), resumo().

const ACHATA := 0.62  # o chão visto de lado: y vale 62% do x (a mesma da ruptura, do escudo e dos avisos)

var combate
var mundo
var dados: Dictionary = {}  # dados/v2_ultimate.json inteiro
var cfg_carga: Dictionary = {}
var padrao := ""
var herois: Dictionary = {}  # chave do herói -> id do ultimate (os testes mexem aqui)
var no: Node2D
var carga := 0.0  # 0 a max
var ativo_t := 0.0  # s que faltam do ultimate ativo (tempo do mundo)
var usos := 0  # testes: quantas vezes disparou
var ondas := 0  # testes: quantas ondas os golpes soltaram
var _fase := 0.0
var _faisca_t := 0.0
var _fim_t := 0.0  # s do clarão do fim (relógio de parede)
var _ini_t := 0.0  # s do clarão do começo (relógio de parede)
var _desenhou := false


func montar(c, camada: Node) -> void:
	combate = c
	mundo = c.mundo
	dados = Dados.json("v2_ultimate")
	cfg_carga = dados.carga
	padrao = str(dados.get("padrao", ""))
	herois = dados.get("herois", {})
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	no = Node2D.new()
	no.material = mat
	no.draw.connect(_desenhar)
	camada.add_child(no)


## Partida nova, herói morto ou cena nova: a carga e o ultimate ativo somem.
func limpar() -> void:
	carga = 0.0
	ativo_t = 0.0
	usos = 0
	ondas = 0
	_faisca_t = 0.0
	_fim_t = 0.0
	_ini_t = 0.0
	_desenhou = false
	_publicar()
	if no != null:
		no.queue_redraw()


## O id do ultimate do herói `chave` (dados > herois, senão o padrão; "" = sem ultimate).
func id_de(chave: String) -> String:
	return str(herois.get(chave, padrao))


## O herói tem um ultimate que existe nos dados?
func tem(chave: String) -> bool:
	var id := id_de(chave)
	return id != "" and dados.get(id) is Dictionary


## O bloco do ultimate do herói de agora (vazio se não tem).
func bloco() -> Dictionary:
	var h = mundo.heroi
	if h == null:
		return {}
	var id := id_de(str(h.chave))
	var b = dados.get(id) if id != "" else null
	return b if b is Dictionary else {}


func maximo() -> float:
	return float(cfg_carga.max)


func fracao() -> float:
	return clampf(carga / maxf(maximo(), 0.001), 0.0, 1.0)


func pronto() -> bool:
	return carga >= maximo() - 0.0001


func ativo() -> bool:
	return ativo_t > 0.0


# ------------------------------------------------------------------ carga


## O herói causou `real` de dano (a vida que o monstro tinha antes menos a que sobrou: o que passa da vida dele não conta).
func dano_causado(real: float) -> void:
	_encher(real * float(cfg_carga.por_dano))


## Um monstro morreu (por qualquer golpe, arma ou fogo).
func abate(m) -> void:
	var k := 1.0
	if m.chefe:
		k = float(cfg_carga.mult_chefe)
	elif m.elite:
		k = float(cfg_carga.mult_elite)
	_encher(float(cfg_carga.por_abate) * k)


func _encher(pontos: float) -> void:
	if pontos <= 0.0 or mundo == null or mundo.heroi == null:
		return
	if not tem(str(mundo.heroi.chave)) or not mundo.heroi.vivo():
		return
	if ativo_t > 0.0 and not bool(cfg_carga.enche_ativo):
		return
	carga = minf(maximo(), carga + minf(pontos, float(cfg_carga.max_por_acerto)))
	_publicar()


# ------------------------------------------------------------------ disparo


## O herói pode disparar agora? Carga cheia, nada ativo, partida rolando, fora da carga da ruptura.
func pode(h) -> bool:
	if h == null or not h.vivo() or not tem(str(h.chave)) or ativo_t > 0.0 or not pronto():
		return false
	if combate.jogo != "jogando" or combate.pausado or h.estado == h.Estado.CARGA:
		return false
	return true


## Q: dispara se puder. Devolve true se disparou.
func acionar(h) -> bool:
	if not pode(h):
		return false
	var b := bloco()
	carga = 0.0
	ativo_t = float(b.dur)
	usos += 1
	_ini_t = 0.35
	_faisca_t = 0.0
	var a: Dictionary = b.ativar
	var cor := cor_ult()
	combate.hit_stop(float(a.hit_stop))
	if combate.lento_t <= 0.0:  # não atropela a câmera lenta de uma subida de nível, morte ou vitória que já esteja rolando
		combate.camera_lenta("", float(a.camera_lenta_dur), float(a.camera_lenta_escala))
	mundo.cam.tremer(float(a.tremor), 0.3)
	combate.fx.onda(h.pos + Vector2(0, -8), Color(cor.r, cor.g, cor.b, 0.95), 90.0, 0.5)
	combate.fx.estouro(h.pos + Vector2(0, -14), cor, 14)
	combate.fx.luz_rapida(h.pos + Vector2(0, -14), cor, 2.2, 90.0, 0.4)
	combate.audio.tocar("critico", 0.7, 0.0, 0.0)
	combate.audio.tocar("ruptura_tique", 0.6, 0.0, 0.0)
	_publicar()
	return true


## Um quadro do mundo (tempo do mundo: parado no hit-stop e na pausa, lento na câmera lenta).
func atualizar(dt: float) -> void:
	if ativo_t <= 0.0:
		return
	ativo_t -= dt
	var h = mundo.heroi
	if h == null or not h.vivo():
		_encerrar()
		return
	if ativo_t <= 0.0:
		_encerrar()
		return
	_faisca_t -= dt
	if _faisca_t <= 0.0:  # faíscas subindo do corpo, na cor do herói
		_faisca_t = 0.07
		combate.fx.faiscas(h.pos + Vector2(randf_range(-6.0, 6.0), -6.0), Vector2(0, -1), 1, cor_ult(), 70.0)
	_publicar()


func _encerrar() -> void:
	ativo_t = 0.0
	_fim_t = 0.3
	var h = mundo.heroi
	if h != null:
		combate.fx.onda(h.pos + Vector2(0, -8), Color(cor_ult().r, cor_ult().g, cor_ult().b, 0.6), 40.0, 0.35)
	_publicar()


# ------------------------------------------------------------------ ganchos (o combate e o herói consultam)


func k_alcance() -> float:
	return float(bloco().get("alcance", 1.0)) if ativo_t > 0.0 else 1.0


func k_dano() -> float:
	return float(bloco().get("dano", 1.0)) if ativo_t > 0.0 else 1.0


func imune_empurrao() -> bool:
	return ativo_t > 0.0 and bool(bloco().get("imune_empurrao", false))


func combo_firme() -> bool:
	return ativo_t > 0.0 and bool(bloco().get("combo_firme", false))


## Cada golpe da katana solta uma onda curta em linha que atravessa os monstros (a onda do v2/armas.gd). `dano` já vem com o multiplicador do ultimate.
func onda_do_golpe(origem: Vector2, dir: Vector2, dano: float) -> void:
	if ativo_t <= 0.0:
		return
	var o: Dictionary = bloco().get("onda", {})
	if o.is_empty():
		return
	ondas += 1
	combate.armas.lancar_onda_externa(origem, dir, dano * float(o.dano_pct) / 100.0, float(o.vel), float(o.alcance), float(o.largura))


## A cor do ultimate do herói (aura, corte e corpo).
func cor_ult() -> Color:
	var a: Array = bloco().get("cor", [0.74, 0.5, 1.0])
	return Color(float(a[0]), float(a[1]), float(a[2]))


## Os números de agora para o painel de status.
func resumo() -> Dictionary:
	var b := bloco()
	return {
		"id": id_de(str(mundo.heroi.chave)) if mundo.heroi != null else "",
		"nome": str(b.get("nome", "")),
		"carga": roundi(carga),
		"pronto": pronto(),
		"ativo": ativo_t > 0.0,
		"restante": maxf(ativo_t, 0.0),
		"dur": float(b.get("dur", 0.0)),
	}


## Publica no herói o que o HUD lê (o mesmo padrão dos campos rup_*): carga 0 a 1, pronto, ativo, s restantes e a duração.
func _publicar() -> void:
	var h = mundo.heroi if mundo != null else null
	if h == null:
		return
	var b := bloco()
	h.ult_id = id_de(str(h.chave))
	h.ult_nome = str(b.get("nome", ""))
	h.ult_carga = fracao() if not b.is_empty() else 0.0
	h.ult_pronto = pronto() and not b.is_empty() and ativo_t <= 0.0
	h.ult_ativo = ativo_t > 0.0
	h.ult_t = maxf(ativo_t, 0.0)
	h.ult_dur = float(b.get("dur", 1.0))
	h.ult_cor = cor_ult()


# ------------------------------------------------------------------ visual (relógio de parede)


func efeitos(dt: float) -> void:
	_fase += dt
	_ini_t = maxf(0.0, _ini_t - dt)
	_fim_t = maxf(0.0, _fim_t - dt)
	var ligado := ativo_t > 0.0 or _fim_t > 0.0 or _ini_t > 0.0
	if ligado or _desenhou:
		_desenhou = ligado
		no.queue_redraw()


## Aura simples e legível, só com formas (sem arte nova): um anel no chão que respira, três anéis subindo e uma coluna de luz; o último segundo pisca
## para avisar que vai acabar. O Codex polir (rastro da katana, onda, ícone, som): ver a issue "Para o Codex: visual do ultimate do Hazaki".
func _desenhar() -> void:
	var h = mundo.heroi
	if h == null:
		return
	var b := bloco()
	if b.is_empty():
		return
	var cor := cor_ult()
	var c: Vector2 = h.pos
	if ativo_t > 0.0:
		var r := float(b.get("aura", 26.0))
		var resto := ativo_t / maxf(float(b.dur), 0.001)
		var piscar := 1.0
		if ativo_t < 1.0:  # o último segundo: pisca
			piscar = 0.55 + 0.45 * sin(_fase * 22.0)
		var pulso := 1.0 + 0.08 * sin(_fase * 9.0)
		var anel := PackedVector2Array()
		var anel2 := PackedVector2Array()
		for i in 33:
			var a := TAU * float(i) / 32.0
			anel.append(c + Vector2(cos(a) * r * pulso, sin(a) * r * pulso * ACHATA))
			anel2.append(c + Vector2(cos(a) * r * 1.6, sin(a) * r * 1.6 * ACHATA))
		no.draw_colored_polygon(anel, Color(cor.r, cor.g, cor.b, 0.16 * piscar))
		no.draw_polyline(anel, Color(cor.r, cor.g, cor.b, 0.85 * piscar), 2.0)
		no.draw_polyline(anel2, Color(cor.r, cor.g, cor.b, 0.3 * piscar), 1.0)
		# três anéis subindo pelo corpo
		for k in 3:
			var f := fposmod(_fase * 1.3 + float(k) / 3.0, 1.0)
			var y := -4.0 - f * 34.0
			var rr := r * (0.9 - f * 0.45)
			var seg := PackedVector2Array()
			for i in 17:
				var a := TAU * float(i) / 16.0
				seg.append(c + Vector2(cos(a) * rr, y + sin(a) * rr * ACHATA))
			no.draw_polyline(seg, Color(cor.r, cor.g, cor.b, 0.55 * (1.0 - f) * piscar), 1.5)
		# a barra do tempo que sobra, aos pés
		var larg := 30.0
		no.draw_rect(Rect2(c + Vector2(-larg * 0.5, 4.0), Vector2(larg, 2.0)), Color(0.0, 0.0, 0.0, 0.5))
		no.draw_rect(Rect2(c + Vector2(-larg * 0.5, 4.0), Vector2(larg * resto, 2.0)), Color(cor.r, cor.g, cor.b, 0.95))
	if _ini_t > 0.0:  # o clarão do começo: coluna de luz
		var t := _ini_t / 0.35
		no.draw_rect(Rect2(c + Vector2(-5.0 - 14.0 * (1.0 - t), -90.0), Vector2(10.0 + 28.0 * (1.0 - t), 90.0)), Color(cor.r, cor.g, cor.b, 0.35 * t))
	if _fim_t > 0.0:  # o fim: o anel encolhe
		var t2 := _fim_t / 0.3
		var r2 := float(b.get("aura", 26.0)) * t2
		var seg2 := PackedVector2Array()
		for i in 25:
			var a := TAU * float(i) / 24.0
			seg2.append(c + Vector2(cos(a) * r2, sin(a) * r2 * ACHATA))
		no.draw_polyline(seg2, Color(cor.r, cor.g, cor.b, 0.7 * t2), 1.5)

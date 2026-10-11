extends Node2D
## Habilidades descobríveis (DiscoverableAbility, seção 31 do design) — por enquanto, a TRANSFORMAÇÃO do personagem.
## Tudo vem de dados/habilidades.json; o dragão do Hazaki é só a primeira entrada. Outro personagem com outra
## forma (demoníaca, colossal...) = outra entrada lá + um visual (ou nenhum) + as armas dela no armas.json.
##
## Ciclo (seções 13, 25 e 26): bloqueada -> desbloqueada (nível, ou fragmentos na #21) -> enche a Energia
## (abates e tempo) -> cheia: Q transforma -> a energia esvazia enquanto dura -> volta sozinho -> recarga.
## Transformado: as armas humanas param INTACTAS (armas.forma_lista) e voltam exatamente como estavam;
## o corpo humano some (com o equipamento, que é filho do sprite) e volta igual; o dash vira investida.
## Não conta como arma exclusiva. No online e no duelo final não transforma (ainda não vai pela rede).

const Armas := preload("res://scripts/hordas/armas.gd")
const Dragao := preload("res://scripts/hordas/dragao.gd")
const ENTRAR := 1.1  # segundos da animação de transformação
const SAIR := 0.7  # e da volta

var arena: Node
var atual := ""  # id da transformação deste personagem no habilidades.json ("" = não tem)
var desbloqueada := false
var energia := 0.0
var ativa := false  # em forma transformada (inclui as animações de entrar e sair)
var vezes := 0
var _usos := 0  # transformações que já terminaram (a energia pedida cresce com elas)
var forma: Node2D  # corpo da forma (dragao.gd), filho do jogador
var _anim := 0.0  # tempo que falta da animação atual
var _saindo := false
var _recarga := 0.0
var _duracao := 18.0
var _dash_antes := 0.0
var _acertou_investida := []
var _t := 0.0


func configurar(a: Node) -> void:
	arena = a
	z_index = 2
	if arena.eh_online:
		return  # ainda não sincroniza pela rede (veja LOGBOOK)
	var todas: Dictionary = Dados.json("habilidades")
	for id in todas:
		var h = todas[id]
		if id.begins_with("_") or not h is Dictionary or str(h.get("tipo", "")) != "transformacao":
			continue
		if str(h.get("characterId", "")) in ["", arena.heroi_id]:
			atual = id
			break


func d() -> Dictionary:
	return Dados.json("habilidades").get(atual, {})


func tem() -> bool:
	return atual != ""


## Energia pra transformar. Cresce a cada uso (energia_cresce): no fim do jogo os abates enchem rápido,
## e a transformação tem que continuar sendo um momento, não o normal (seção 25).
func energia_max() -> float:
	var h := d()
	return float(h.get("energia_max", 100)) * (1.0 + float(h.get("energia_cresce", 0.0)) * _usos)


func pronta() -> bool:
	return desbloqueada and not ativa and energia >= energia_max() and pode_transformar()


func pode_transformar() -> bool:
	return not arena.duelo_ativo and not arena.pre_duelo and not arena.acabou and arena.jogador.hp > 0


## Segundos que ainda faltam transformado (pro HUD).
func restante() -> float:
	return energia / energia_max() * _duracao if ativa else 0.0


## Libera a transformação nesta partida (nível alcançado; na #21, os fragmentos dos santuários chamam isto).
func desbloquear() -> void:
	if desbloqueada or not tem():
		return
	desbloqueada = true
	arena.anunciar("%s DESPERTOU!" % str(d().get("nome", "A FORMA")).to_upper(), Color(0.55, 0.8, 1.0))
	arena.mensagem("Encha a Energia e aperte Q pra transformar", Color(0.7, 0.85, 1.0))
	Som.tocar("plim", 0.1, 0.7)


## Um vírus caiu: enche a energia (elite e chefe enchem mais).
func abate(v) -> void:
	if not desbloqueada or ativa or _recarga > 0:
		return
	var h := d()
	var ganho := float(h.get("energia_abate", 1.0))
	if v.chefe:
		ganho = float(h.get("energia_chefe", 20.0))
	elif v.elite:
		ganho = float(h.get("energia_elite", 5.0))
	energia = minf(energia_max(), energia + ganho)


## Atributos a mais enquanto transformado (arena.stat soma).
func bonus(k: String) -> float:
	if not ativa:
		return 0.0
	return float(d().get("bonus", {}).get(k, 0.0))


## Quanto do dano recebido pega (1 = tudo).
func mult_dano() -> float:
	return 1.0 - float(d().get("reducao_dano", 0.0)) if ativa else 1.0


func atualizar(dt: float) -> void:
	if not tem():
		return
	_t += dt
	if not desbloqueada:
		var cond: Dictionary = d().get("desbloqueio", {})
		var tipo := str(cond.get("tipo", ""))
		if tipo == "nivel" and arena.nivel >= int(cond.get("valor", 1)):
			desbloquear()
		elif tipo == "fragmentos" and arena.descobertas.completo(atual):
			desbloquear()  # juntou todos os fragmentos (santuários, elites e eventos, #21)
		return
	if ativa:
		_atualizar_forma(dt)
	else:
		_recarga = maxf(0.0, _recarga - dt)
		if _recarga <= 0:
			energia = minf(energia_max(), energia + float(d().get("energia_segundo", 0.0)) * dt)
		if pronta() and _quer_transformar():
			transformar()
	queue_redraw()


func _quer_transformar() -> bool:
	if arena.bot:
		return true
	if arena.cartas.aberto() or arena.hud._pausado:
		return false
	return Input.is_action_just_pressed("transformar")


func transformar() -> void:
	var h := d()
	var jog: Node2D = arena.jogador
	ativa = true
	_saindo = false
	_anim = ENTRAR
	vezes += 1
	energia = energia_max()
	_duracao = clampf(float(h.get("duracao", 18)) * arena.stat("duracao"), float(h.get("duracao_min", 15)), float(h.get("duracao_max", 30)))
	# habilidades da forma: nível sobe com o nível do jogador
	var nv: int = 1 + arena.nivel / maxi(1, int(h.get("nivel_armas_cada", 6)))
	var lista := []
	for i in h.get("armas", []).size():
		var id: String = h.armas[i]
		lista.append(
			{
				"id": id,
				"nivel": mini(nv, arena.armas.nivel_max(id)),
				"t": 0.6 + i * 0.25,
				"ativo": 0.0,
				"acertos": {},
				"tique": 0.0,
				"disparo": Armas.disparo_de(id, false)
			}
		)
	arena.armas.forma_lista = lista
	if str(h.get("visual", "")) == "dragao":
		forma = Dragao.new()
		jog.add_child(forma)
		forma.iniciar(jog.position, jog.direcao_mov() if jog.direcao_mov() != Vector2.ZERO else Vector2(jog.lado, 0))
		forma.surgir = 0.0
		forma.brilho = 1.0
	jog.forma = forma
	jog.invencivel = maxf(jog.invencivel, ENTRAR + 0.2)
	arena.tremer(6.0)
	arena.anunciar(str(h.get("nome", "")).to_upper() + "!", Color(0.55, 0.8, 1.0))
	Som.tocar("tremor", 0.1, 0.6)
	Som.tocar("whoosh", 0.1, 0.5)


## Volta à forma humana (energia acabou, duelo começou...). A animação de saída termina em _fim().
func voltar() -> void:
	if not ativa or _saindo:
		return
	_saindo = true
	_anim = SAIR
	Som.tocar("whoosh", 0.1, 0.8)


func _atualizar_forma(dt: float) -> void:
	var jog: Node2D = arena.jogador
	_anim = maxf(0.0, _anim - dt)
	if _saindo:
		var f := _anim / SAIR  # 1 -> 0
		jog.humano = 1.0 - f
		if forma:
			forma.surgir = f
			forma.brilho = 1.0 - f
		if _anim <= 0:
			_fim()
			return
	else:
		var f := 1.0 - _anim / ENTRAR  # 0 -> 1
		jog.humano = clampf(1.0 - f * 2.0, 0.0, 1.0)  # o corpo humano some na primeira metade...
		if forma:
			forma.surgir = clampf((f - 0.25) / 0.75, 0.0, 1.0)  # ...enquanto o dragão se desenrola de dentro da luz
			forma.brilho = maxf(1.0 - f, 0.5 if jog.dash_t > 0 else 0.0)
		if _anim <= 0:
			energia -= energia_max() / _duracao * dt
		if energia <= 0 or not pode_transformar():
			voltar()
	if forma:
		forma.boca_aberta = _boca_aberta()
		forma.atualizar(jog.position, jog.direcao_mov(), dt)
	_investida()


func _boca_aberta() -> bool:
	for e in arena.armas.especiais:
		if e.tipo in ["baforada", "rugido"] and e.get("boca", false):
			return true
	return false


## Investida: o dash, em forma de dragão, machuca e empurra quem estiver no caminho (uma vez por dash).
func _investida() -> void:
	var jog: Node2D = arena.jogador
	if jog.dash_t > 0 and _dash_antes <= 0:
		_acertou_investida.clear()
	_dash_antes = jog.dash_t
	if jog.dash_t <= 0 or _anim > 0:
		return
	var inv: Dictionary = d().get("investida", {})
	if inv.is_empty():
		return
	var dir: Vector2 = jog.direcao_mov() if jog.direcao_mov() != Vector2.ZERO else Vector2(jog.lado, 0)
	for v in arena.inimigos.no_circulo(jog.position, float(inv.get("raio", 28))):
		if not v.id in _acertou_investida:
			_acertou_investida.append(v.id)
			arena.inimigos.ferir(v, float(inv.get("dano", 30)) * arena.stat("dano"), dir * float(inv.get("empurra", 200)), "investida")


func _fim() -> void:
	var jog: Node2D = arena.jogador
	ativa = false
	_saindo = false
	energia = 0.0
	_usos += 1
	_recarga = float(d().get("recarga", 3))
	arena.armas.forma_lista = []
	if forma:
		forma.queue_free()
		forma = null
	jog.forma = null
	jog.humano = 1.0
	jog.invencivel = maxf(jog.invencivel, 0.6)


## Fim da partida/duelo: volta na hora, sem animação.
func cancelar() -> void:
	if ativa:
		_fim()


func _draw() -> void:
	if not ativa or _anim <= 0:
		return
	# coluna e redemoinho de energia cobalto em volta do Hazaki enquanto ele vira (ou volta de) dragão
	var c: Vector2 = arena.jogador.position + Vector2(0, -22)
	var f := _anim / (SAIR if _saindo else ENTRAR)  # 1 no começo, 0 no fim
	var cor := Color(0.25, 0.45, 1.0)
	var ciano := Color(0.55, 0.85, 1.0)
	var r := lerpf(10.0, 46.0, f)
	for k in 3:
		var a0 := _t * (7.0 + k) + k * TAU / 3.0
		draw_set_transform(arena.jogador.position, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, r + k * 6.0, a0, a0 + 2.2, 14, Color(ciano if k == 0 else cor, 0.8 * f + 0.2), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var alt := 70.0 * (1.0 - absf(f - 0.5) * 2.0) + 10.0
	draw_rect(Rect2(c.x - 3, c.y - alt + 22, 6, alt), Color(cor, 0.35 * f + 0.15))
	draw_rect(Rect2(c.x - 1, c.y - alt + 22, 2, alt), Color(1, 1, 1, 0.6 * f))
	for i in 8:
		var fase := fmod(_t * 1.7 + i * 0.13, 1.0)
		var p := c + Vector2.from_angle(i * 0.8 + _t * 4.0) * (r * (1.0 - fase))
		draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(ciano, 1.0 - fase))

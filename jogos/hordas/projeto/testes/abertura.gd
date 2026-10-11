extends Node
# Teste automático: abertura cinematográfica da fase (abertura.gd, dados/entrada.json).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/abertura.tscn  (imprime "ABERTURA falhas=0")
const Arena := preload("res://scripts/hordas/arena.gd")
const Regioes := preload("res://scripts/hordas/regioes.gd")
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func nova(com: bool) -> Node2D:
	var a := Arena.new()
	a.heroi_id = "nicao"
	a.bot = true
	a.semente = 7
	a.com_abertura = com
	add_child(a)
	return a


func _ready() -> void:
	for acao in ["cima", "baixo", "esquerda", "direita", "dash", "especial", "transformar", "voltar", "confirmar", "falar"]:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)

	# --- os dados: tempos coerentes, tema pra cada região
	var cfg: Dictionary = Dados.json("entrada")
	var rg: Dictionary = cfg.regiao
	var an: Dictionary = cfg.andar
	ok(float(rg.duracao) >= 3.0 and float(rg.duracao) <= 5.0, "abertura de região dura 3 a 5 s (%.1f)" % float(rg.duracao))
	ok(float(an.duracao) >= 1.5 and float(an.duracao) <= 2.5, "abertura de andar comum dura ~2 s (%.1f)" % float(an.duracao))
	for m in [rg, an]:
		var pouso: float = float(m.queda.inicio) + 0.65 * float(m.queda.duracao)
		ok(
			pouso < float(m.libera) and float(m.libera) <= float(m.duracao),
			"o pouso (%.2f) vem antes de liberar (%.2f) e de acabar (%.2f)" % [pouso, float(m.libera), float(m.duracao)]
		)
		ok(float(m.titulo_em) >= pouso - 0.05 and float(m.titulo_some) <= float(m.duracao), "o título entra no pouso e some antes do fim")
		ok(float(m.guindaste.ate) <= float(m.queda.inicio) + 0.6, "a câmera já chegou quando o herói cai")
	for r in Regioes.lista():
		ok(cfg.tema.has(str(r.id)), "tema de cores pra região %s" % r.id)

	# --- sem a opção (robô, testes, captura): nada muda
	var s := nova(false)
	await esperar(0.5)
	ok(not s.abertura.ativa() and not s.abertura.heroi_preso() and not s.abertura.mundo_preso(), "sem com_abertura ela não roda")
	ok(s.diretor.t_fase > 0.0, "sem abertura o relógio da fase corre (%.2f)" % s.diretor.t_fase)
	ok(s.jogador.visible and s.hud.visible, "herói e HUD visíveis")
	s.queue_free()
	await esperar(0.1)

	# --- com a opção: começo da corrida = abertura de região
	var a := nova(true)
	await esperar(0.5)
	var ab = a.abertura
	ok(ab.ativa() and ab.heroi_preso() and ab.mundo_preso(), "a abertura roda no começo da corrida")
	ok(absf(ab.duracao() - float(rg.duracao)) < 0.001 and absf(ab.libera() - float(rg.libera)) < 0.001, "começo da corrida usa a versão de região")
	ok(not a.hud.visible, "HUD escondido durante a abertura")
	ok(a.jogador.invencivel > 0.0, "herói invulnerável durante a abertura")
	var pos0: Vector2 = a.jogador.position
	Input.action_press("direita")  # tentar andar: parado
	await esperar(0.8)
	ok(a.jogador.position.distance_to(pos0) < 0.5, "herói não anda durante a abertura")
	Input.action_release("direita")
	ok(a.diretor.t_fase < 0.001, "o relógio da fase espera (%.3f)" % a.diretor.t_fase)
	ok(a.inimigos.lista.size() == 0, "nenhum inimigo nasce durante a abertura (%d)" % a.inimigos.lista.size())
	ok(a.jogador.invencivel > 0.0, "ainda invulnerável aos 1,3 s")
	await esperar(float(rg.libera) - 1.3 + 0.35)  # passou do libera
	ok(not ab.heroi_preso() and not ab.mundo_preso(), "liberou: herói e mundo soltos")
	ok(a.hud.visible and a.jogador.visible, "HUD e herói de volta")
	ok(a.jogador.invencivel > 0.0, "tolerância de invulnerabilidade depois de liberar")
	ok(a.diretor.t_fase > 0.0, "o relógio da fase começou (%.3f)" % a.diretor.t_fase)
	await esperar(float(rg.duracao) - float(rg.libera) + 0.2)
	ok(not ab.ativa(), "a abertura terminou sozinha")
	ok(a.camera.position.distance_to(a.jogador.centro() + a._olhar) < 2.0, "câmera de volta no herói")

	# --- pular com confirmar, na abertura de um andar comum
	a.entre_fases = true
	a.proxima_fase()  # andar 2 da região 1: versão curta
	await esperar(0.2)
	ok(ab.ativa() and absf(ab.duracao() - float(an.duracao)) < 0.001, "andar comum usa a versão curta")
	var ev := InputEventAction.new()
	ev.action = "confirmar"
	ev.pressed = true
	Input.parse_input_event(ev)
	await esperar(0.1)
	ok(not ab.heroi_preso() and not ab.mundo_preso(), "confirmar pula: herói e mundo soltos na hora")
	ok(a.hud.visible and a.jogador.visible, "pular devolve HUD e herói")
	ok(a.jogador.spr.position.y == 0.0, "pular deixa o herói no chão")
	await esperar(0.5)
	ok(not ab.ativa(), "depois de pular a abertura some em instantes")

	# --- pular com Esc em outra abertura (e nada de pausa junto)
	a.entre_fases = true
	a.proxima_fase()
	await esperar(0.15)
	var ev2 := InputEventAction.new()
	ev2.action = "voltar"
	ev2.pressed = true
	Input.parse_input_event(ev2)
	await esperar(0.1)
	ok(not ab.heroi_preso(), "Esc também pula")
	ok(not a.hud._pausado, "o Esc que pulou não abriu a pausa")
	await esperar(0.5)

	# --- online: pular só solta o herói, o mundo espera até o relógio natural
	a.eh_online = true
	a.entre_fases = true
	a.proxima_fase()
	await esperar(0.15)
	ab.pular()
	ok(not ab.heroi_preso(), "online: pular solta o herói")
	ok(ab.mundo_preso(), "online: o mundo continua parado depois de pular")
	var t_ini: float = a.diretor.t_fase
	await esperar(float(an.libera) - 0.15 + 0.1)
	ok(not ab.mundo_preso(), "online: o mundo solta no mesmo tempo fixo")
	ok(a.diretor.t_fase >= t_ini, "relógio não andou pra trás")
	a.eh_online = false

	# --- recomeçar uma abertura (saltar de andar) não deixa o herói escondido
	a.saltar_para_andar(5)
	await esperar(0.1)
	a.acabou = true
	await esperar(0.1)
	ok(a.jogador.visible and a.hud.visible and not ab.ativa(), "fim da partida durante a abertura devolve tudo")
	a.queue_free()
	await esperar(0.1)
	print("ABERTURA falhas=", falhas)
	get_tree().quit()

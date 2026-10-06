extends Node
# Teste: 8 direções do herói, giro suave do olhar e histerese. Roda: godot --headless --path . res://testes/direcoes.tscn  (imprime "DIR falhas=0")
const D := preload("res://scripts/hordas/direcao.gd")
const J := preload("res://scripts/hordas/jogador.gd")
var falhas := 0

func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)

## Roda o olhar por 'seg' segundos (60 quadros/s) com 'mov' e devolve a sequência de direções distintas.
func sequencia(o, mov: Vector2, seg: float, n := 8) -> Array:
	var seq: Array = []
	for i in int(seg * 60.0):
		o.atualizar(mov, 1.0 / 60.0, n)
		if seq.is_empty() or seq[-1] != o.dir:
			seq.append(o.dir)
	return seq

func antigo4(v: Vector2) -> String:
	if absf(v.x) > absf(v.y) * 0.9:
		return "direita" if v.x > 0 else "esquerda"
	return "baixo" if v.y > 0 else "cima"

func _ready() -> void:
	# tabela e altura da folha
	ok(D.linhas_da_altura(480) == 8 and D.linhas_da_altura(240) == 4 and D.linhas_da_altura(60) == 4, "linhas pela altura")
	ok(D.LINHA["baixo"] == 0 and D.LINHA["esquerda"] == 1 and D.LINHA["direita"] == 2 and D.LINHA["cima"] == 3, "linhas 0-3 como antes")
	ok(D.LINHA["baixo_esquerda"] == 4 and D.LINHA["baixo_direita"] == 5 and D.LINHA["cima_esquerda"] == 6 and D.LINHA["cima_direita"] == 7, "linhas 4-7 diagonais")
	ok(J.LINHA == D.LINHA, "jogador usa a mesma tabela")
	# 8 direções: cada vetor cai na linha certa (tela: x para a direita, y para baixo)
	var casos := {
		"baixo": Vector2(0, 1), "cima": Vector2(0, -1), "esquerda": Vector2(-1, 0), "direita": Vector2(1, 0),
		"baixo_esquerda": Vector2(-1, 1), "baixo_direita": Vector2(1, 1), "cima_esquerda": Vector2(-1, -1), "cima_direita": Vector2(1, -1),
	}
	for nome in casos:
		var o = D.new()
		sequencia(o, casos[nome], 1.0)
		ok(o.dir == nome, "8 dir: %s virou %s" % [nome, o.dir])
		var f: int = J.quadro_de("andando", o.dir, 0.0, 23)
		ok(f / 23 == D.LINHA[nome] and f % 23 == 1, "8 dir: quadro de %s" % nome)
		ok(J.quadro_de("parado", o.dir, 0.0, 23) / 23 == D.LINHA[nome], "8 dir: parado de %s" % nome)
	# 4 linhas: igual à regra antiga (eixo dominante), só linhas 0-3, instantâneo
	for i in 72:
		var v := Vector2.from_angle(deg_to_rad(i * 5.0))
		var o = D.new()
		o.atualizar(v, 0.016, 4)
		ok(o.dir == antigo4(v) and D.LINHA[o.dir] < 4, "4 linhas igual ao antigo em %d graus (%s)" % [i * 5, o.dir])
	# virada de baixo para cima passa por intermediárias e não volta atrás
	var o = D.new()
	sequencia(o, Vector2(0, 1), 0.2)
	var seq := sequencia(o, Vector2(0, -1), 0.5)
	ok(seq.size() >= 3 and seq[-1] == "cima", "baixo->cima passa por intermediárias: %s" % str(seq))
	var inter := 0
	for s in seq:
		if "_" in s:
			inter += 1
	ok(inter >= 1, "tem diagonal no caminho: %s" % str(seq))
	for s in seq:
		ok(seq.count(s) == 1, "não repete direção na virada: %s" % str(seq))
	# velocidade limitada: em 0,1 s (80 graus) ainda não chegou a 180
	o = D.new()
	o.atualizar(Vector2(0, -1), 0.1, 8)
	ok(absf(o.angulo) <= D.VEL_GIRO * 0.1 + 0.01 and o.dir != "cima", "giro limitado (%.1f graus)" % o.angulo)
	# caminho mais curto: baixo -> esquerda passa só pela diagonal baixo_esquerda
	o = D.new()
	var s2 := sequencia(o, Vector2(-1, 0), 0.5)
	ok(s2 == ["baixo", "baixo_esquerda", "esquerda"] or s2 == ["baixo_esquerda", "esquerda"], "baixo->esquerda direto: %s" % str(s2))
	# cima -> baixo pelo outro lado do círculo (180/-180) chega
	o = D.new()
	sequencia(o, Vector2(0, -1), 1.0)
	ok(o.dir == "cima", "vai pra cima")
	sequencia(o, Vector2(0, 1), 1.0)
	ok(o.dir == "baixo", "cima->baixo chega: %s" % o.dir)
	# parar mantém a última direção
	o = D.new()
	sequencia(o, Vector2(1, 1), 1.0)
	sequencia(o, Vector2.ZERO, 1.0)
	ok(o.dir == "baixo_direita", "parado mantém %s" % o.dir)
	# soltar no meio do giro termina o giro na última direção pedida (não congela entre duas)
	o = D.new()
	sequencia(o, Vector2(0, 1), 0.2)
	o.atualizar(Vector2(1, 0), 1.0 / 60.0, 8)
	sequencia(o, Vector2.ZERO, 0.5)
	ok(o.dir == "direita", "soltar no meio do giro termina em %s" % o.dir)
	# histerese: ângulo oscilando em volta da fronteira baixo/baixo_direita (22,5 graus) não pisca
	var troca := 0
	var atual := "baixo"
	for i in 200:
		var nova: String = D.direcao_de(22.5 + (5.0 if i % 2 == 0 else -5.0), 8, atual)
		if nova != atual:
			troca += 1
		atual = nova
	ok(troca <= 1, "histerese: %d trocas oscilando na fronteira" % troca)
	ok(D.direcao_de(22.6, 8, "baixo") == "baixo" and D.direcao_de(22.6, 8, "") == "baixo_direita", "histerese só vale com direção atual")
	ok(D.direcao_de(31.0, 8, "baixo") == "baixo_direita" and D.direcao_de(-31.0, 8, "baixo") == "baixo_esquerda", "passou da histerese: troca")
	ok(D.direcao_de(179.0, 8, "") == "cima" and D.direcao_de(-179.0, 8, "") == "cima", "volta do círculo em cima")
	# movimento com jitter de 8 graus em volta da diagonal: uma direção só
	o = D.new()
	sequencia(o, Vector2(1, 1), 0.5)
	var trocas := 0
	var ultima: String = o.dir
	for i in 120:
		o.atualizar(Vector2.from_angle(deg_to_rad(45.0 + (8.0 if i % 2 == 0 else -8.0))), 1.0 / 60.0, 8)
		if o.dir != ultima:
			trocas += 1
			ultima = o.dir
	ok(trocas == 0, "jitter na diagonal: %d trocas" % trocas)
	# no jogo: Hazaki tem 8 linhas e camadas combinam
	var m = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(0.3).timeout
	m._comecar("hazaki")
	var j = m._arena.jogador
	await get_tree().process_frame
	ok(j.spr.vframes == 8 and j.spr.texture.get_height() == 480, "Hazaki: vframes %d" % j.spr.vframes)
	for c in j.camadas.values():
		ok(c.vframes == 8 and c.texture.get_height() == 480, "camada com 8 linhas")
	for i in 20:
		j._animar(Vector2(1, 1).normalized())
	ok(j._dir == "baixo_direita" and j.spr.frame / j.spr.hframes == 5, "jogador na diagonal usa a linha 5 (frame %d)" % j.spr.frame)
	print("DIR falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)

extends "res://testes/isolamento_v2.gd"
# ECO-5 (pedido 15 de 01/11; decisão D18 do plano): as almas compram a chave de um portal trancado, uma vez por personagem.
# Checagens:
# 1. dados: a Torre custa 300, a Vila 800 e as Ruínas 1.800; a Floresta não se compra.
# 2. com 299 almas a Torre segue trancada, o aviso diz quanto falta e o saldo fica intacto.
# 3. com 300 almas: o 1º E só pede a confirmação (nada gasto, portal trancado); o 2º dentro de 4 s compra: o saldo cai 300 e o portal abre.
# 4. comprado, o portal abre sem cobrar de novo; comprar não cumpre vence_floresta.
# 5. fora da janela de 4 s o 1º E pede de novo (não compra); a Vila segue a mesma regra com 800.
# 6. por personagem: um personagem novo continua com a Torre trancada, mesmo com a chave do outro.
# 7. --beta-tester abre tudo sem comprar.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_compra_chave.tscn  (imprime "v2_compra_chave falhas=0")
const Personagens := preload("res://v2/personagens.gd")
const Meta := preload("res://v2/meta.gd")
const Mapas := preload("res://v2/mapas.gd")
const Progressao := preload("res://v2/progressao.gd")
const Salao := preload("res://v2/salao.tscn")

var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	await _testes()
	print("v2_compra_chave falhas=%d" % falhas)
	get_tree().quit(1 if falhas > 0 else 0)


func _novo(nome: String) -> void:
	var id := Personagens.criar(nome)
	ok(Personagens.ativar(id), "ativa o personagem " + nome)


func _salao() -> Node:
	var s = Salao.instantiate()
	s.ao_entrar = func(_cena): ok(false, "portal trancado não pode levar à partida")
	add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame
	return s


func _testes() -> void:
	# 1. preços da chave, na ordem dos mapas
	ok(Progressao.preco_chave("laboratorio") == 300, "a Torre custa 300 (%d)" % Progressao.preco_chave("laboratorio"))
	ok(Progressao.preco_chave("cidade") == 800, "a Vila custa 800 (%d)" % Progressao.preco_chave("cidade"))
	ok(Progressao.preco_chave("medio") == 1800, "as Ruínas custam 1.800 (%d)" % Progressao.preco_chave("medio"))
	ok(Progressao.preco_chave("floresta") == 0, "a Floresta não se compra")

	# 2. personagem novo com 299 almas: a Torre segue trancada, com o aviso do que falta
	_novo("Breno")
	Meta.creditar(299)
	var s := await _salao()
	ok(not s.usar_portal("laboratorio"), "299 almas: a Torre não abre")
	ok(s._aviso_lbl.text.contains("faltam 1 almas"), "o aviso diz quanto falta (%s)" % s._aviso_lbl.text)
	ok(Meta.saldo() == 299, "o saldo fica intacto com 299 (%d)" % Meta.saldo())
	ok(not Progressao.aberto("mapa", "laboratorio"), "a Torre segue trancada com 299 almas")

	# 3. com 300 almas: o 1º E pede a confirmação, o 2º compra
	Meta.creditar(1)
	ok(not s.usar_portal("laboratorio"), "o 1º E não abre a Torre")
	ok(s._aviso_lbl.text.contains("Confirme de novo"), "o 1º E pede a confirmação (%s)" % s._aviso_lbl.text)
	ok(Meta.saldo() == 300 and not Progressao.aberto("mapa", "laboratorio"), "o 1º E não gasta nada (saldo %d)" % Meta.saldo())
	ok(not s.usar_portal("laboratorio"), "o 2º E compra e não entra direto")
	ok(Meta.saldo() == 0, "o saldo cai 300 (%d)" % Meta.saldo())
	ok(Progressao.aberto("mapa", "laboratorio") and Mapas.condicao(Mapas.buscar("laboratorio")) == "", "a Torre abre depois da compra")
	ok(s._aviso_lbl.text.contains("foi comprada"), "a compra avisa (%s)" % s._aviso_lbl.text)
	var alvo_torre: Dictionary = {}
	for a in s._alvos:
		if a.tipo == "portal" and str(a.id) == "laboratorio":
			alvo_torre = a
	ok(str(alvo_torre.get("trava", "x")) == "", "o alvo da Torre sai do cadeado na hora")

	# 4. comprado: o próximo E escolhe a dificuldade sem cobrar de novo; comprar não cumpre a conquista do mapa
	ok(s.usar_portal("laboratorio") and s._escolha_dificuldade.visible, "com a Torre comprada, E abre a escolha de dificuldade")
	ok(Meta.saldo() == 0, "e não cobra de novo (saldo %d)" % Meta.saldo())
	ok(not Meta.mapa_vencido("floresta") and not bool(Meta._ler().get_value("conquistas", "vence_floresta", false)), "comprar não cumpre vence_floresta")
	s.queue_free()
	await get_tree().process_frame

	# 5. a janela de 4 s: fora dela o 1º E pede de novo; a Vila segue a mesma regra com 800
	Meta.creditar(800)
	s = await _salao()
	ok(not s.usar_portal("cidade") and s._aviso_lbl.text.contains("Confirme de novo"), "a Vila pede confirmação com 800")
	s._compra_ate = 0  # a janela venceu
	ok(not s.usar_portal("cidade") and s._aviso_lbl.text.contains("Confirme de novo"), "fora da janela o E pede de novo")
	ok(Meta.saldo() == 800 and not Progressao.aberto("mapa", "cidade"), "pedir de novo não gasta nada")
	ok(not s.usar_portal("cidade"), "o E dentro da nova janela compra a Vila")
	ok(Meta.saldo() == 0 and Progressao.aberto("mapa", "cidade"), "a Vila abre e o saldo cai 800")
	s.queue_free()
	await get_tree().process_frame

	# 6. por personagem: o personagem novo não herda a chave nem o saldo
	_novo("Outro")
	ok(Meta.saldo() == 0, "o personagem novo começa sem almas")
	ok(not Progressao.aberto("mapa", "laboratorio") and not Progressao.chave_comprada("laboratorio"), "a chave comprada não passa para o personagem novo")
	ok(not Progressao.aberto("mapa", "cidade"), "a Vila também segue trancada no personagem novo")

	# 7. beta tester: tudo aberto, sem comprar nada
	Progressao.args_teste = ["--beta-tester"]
	ok(Progressao.aberto("mapa", "medio") and Progressao.aberto("mapa", "laboratorio"), "--beta-tester abre todos os mapas")
	Progressao.args_teste = null

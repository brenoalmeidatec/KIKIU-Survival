extends "res://testes/isolamento_v2.gd"
# Teste do LW-2 (#511): as formas Mecha e Lobo do LightWolf (v2/mecha.gd). Confere: o registro do Lobo (fora da lista, com folha e números), a quebra (a vida
# do mecha zera e o herói vira Lobo em vez de morrer: 31% da vida, folha, tiro de plasma, E e secundário apagados, Q vira CHAMAR com 20, Q e E do mecha
# guardados, a troca não zera nada, a pistola atira no ritmo do papel), as cartas de vida na forma Lobo, o chamado (por dano, abate e tempo; aviso de 0,8 s; o mecha volta com vida cheia e o Q de
# antes), a derrota (só a morte do Lobo, pelo caminho normal) e o recomeço (volta à forma mecha). Um herói sem formas (Hazaki) morre como sempre.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_lightwolf_formas.tscn  (imprime "v2_lightwolf_formas falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Herois := preload("res://v2/herois.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const Status := preload("res://v2/status.gd")
const SAVE_TESTE := "user://testes_v2/v2_lightwolf_formas/teste.cfg"
const INDICE_TESTE := "user://testes_v2/v2_lightwolf_formas/teste_indice.cfg"
const PREFIXO_TESTE := "user://testes_v2/v2_lightwolf_formas/teste_p"
const ANTIGO_TESTE := "user://testes_v2/v2_lightwolf_formas/teste_antigo.cfg"
const PASSO := 1.0 / 60.0

var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


func _apagar_save() -> void:
	var alvos := [SAVE_TESTE, INDICE_TESTE]
	for i in range(1, 6):
		alvos.append(Personagens.caminho_do_save("p%d" % i))
		alvos.append(Personagens.caminho_do_save("p%d" % i) + ".bak")
	for c in alvos:
		if FileAccess.file_exists(c):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(c))


func novo(id: String) -> void:
	if w != null:
		w.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Herois.forcado = id
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	zerar()


## Mapa sem monstros, sem diretor, herói parado com a mira à direita; vulnerável (é o que o teste mede).
func zerar() -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.heroi.imortal = false
	w.heroi.entrada_forcada = Vector2.ZERO
	w.heroi.ataque_forcado = false
	w.heroi.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = w.heroi.centro() + Vector2(100, 0)
	passos(3)


func _ready() -> void:
	Meta.caminho_save = SAVE_TESTE
	Personagens.caminho_indice = INDICE_TESTE
	Personagens.caminho_base = PREFIXO_TESTE
	Personagens.caminho_antigo = ANTIGO_TESTE
	_apagar_save()
	await _testes()
	_apagar_save()
	Herois.forcado = ""
	print("v2_lightwolf_formas falhas=%d" % falhas)
	get_tree().quit()


func _testes() -> void:
	_t_dados()
	await _t_quebra()
	await _t_cartas_e_dano()
	await _t_chamado()
	await _t_defesa_na_volta()
	await _t_chamado_por_tempo()
	await _t_troca_de_folha()
	await _t_derrota_e_recomeco()
	await _t_sem_formas()


## Um golpe fatal no herói.
func quebrar() -> void:
	var h = w.heroi
	h.vida = 10.0
	ok(h.levar_dano(999.0, h.pos + Vector2(20, 0)), "o golpe fatal é consumido")


func _t_dados() -> void:
	var lobo: Dictionary = Herois.heroi("lightwolf_lobo")
	ok(str(lobo.get("id", "")) == "lightwolf_lobo" and str(lobo.get("forma_de", "")) == "lightwolf", "Herois.heroi encontra o registro do Lobo")
	Herois.forcado = "lightwolf"
	var ids := Herois.lista().map(func(h): return str(h.id))
	ok(ids.has("lightwolf") and not ids.has("lightwolf_lobo"), "o Lobo é forma, não herói de escolha: fora da lista (%s)" % str(ids))
	ok(not Herois.existe("lightwolf_lobo"), "o Lobo não existe como escolha")
	ok(str(Herois.heroi("lightwolf").get("forma_lobo", "")) == "lightwolf_lobo", "o mecha aponta para a forma Lobo")
	Herois.forcado = ""
	ok(is_equal_approx(float(lobo.vida_pct), 0.31) and is_equal_approx(float(lobo.invencivel), 1.5), "Lobo: 31% da vida e 1,5 s invencível")
	var c: Dictionary = lobo.cfg
	ok(int(c.heroi.vel) == 130 and int(c.heroi.recuo_dano) == 150, "Lobo: vel 130 e recuo 150")
	var p: Dictionary = c.golpe.passos[0]
	ok(
		c.golpe.passos.size() == 1 and str(p.proj) == "plasma" and float(p.dano) == 34.0 and int(p.perfura) == 3,
		"Lobo: pistola de plasma, dano 34, atravessa 3"
	)
	var esp: Dictionary = Dados.json("v2_especial")
	ok(str(esp.herois.get("lightwolf_lobo", "")) == "chamar" and esp.has("chamar"), "o Q do Lobo é o CHAMAR")
	ok(
		float(esp.chamar.inicio_quebra) == 20.0 and float(esp.chamar.carga.tempo) == 2.5 and float(esp.chamar.dur) == 0.8,
		"chamar: começa em 20, +2,5 por segundo, aviso de 0,8 s"
	)
	ok(str(Dados.json("v2_habilidade").herois.lightwolf_lobo) == "nenhuma", "o Lobo não tem E")
	var sec: Dictionary = Dados.json("v2_secundario").herois
	ok(str(sec.get("lightwolf", "")) == "matriz" and str(sec.get("lightwolf_lobo", "")) == "nenhum", "o mecha tem a matriz (LW-3) e o Lobo fica sem secundário")
	ok(not Dados.json("v2_especial").chamar.has("limpa_em"), "o CHAMAR não limpa a tela (sem limpa_em: de propósito)")


func _t_quebra() -> void:
	await novo("lightwolf")
	var h = w.heroi
	var c = w.combate
	ok(h.chave == "lightwolf" and not h.forma_lobo and is_equal_approx(h.vida_max, 130.0), "começa mecha, 130 de vida")
	ok(h.tipo.w == 128 and h.def_max == 100.0 and h.hab_nome != "", "mecha: folha 128x192, E e a barra de defesa da matriz (def_max %.0f)" % h.def_max)
	var fol: float = h.folego
	h.esp_carga = 77.0
	h.hab_recarga = 3.5
	quebrar()
	ok(h.estado != Heroi.Estado.MORTO and c.jogo == "jogando", "a vida do mecha zerou e o herói segue vivo, o jogo segue")
	ok(h.forma_lobo and h.chave == "lightwolf_lobo" and c.heroi_id == "lightwolf", "forma Lobo; o herói da partida segue lightwolf")
	ok(
		is_equal_approx(h.vida_max, 130.0 * 0.31) and is_equal_approx(h.vida, h.vida_max),
		"vida do Lobo = 31%% do mecha, cheia (%.1f de %.1f)" % [h.vida, h.vida_max]
	)
	ok(h.invenc > 1.4, "invencível ao virar Lobo (%.2f)" % h.invenc)
	ok(h.tipo.w == 32 and h.sprite.texture == h.tipo.tex and h.sprite.offset == Vector2(-16, -42) and h.alt == 42.0, "folha do Lobo ligada: 32x44, pés em 42")
	ok(is_equal_approx(h.vel_base, 130.0) and is_equal_approx(float(c.cfg.heroi.recuo_dano), 150.0), "velocidade 130 e recuo 150")
	ok(str(c.cfg.golpe.passos[0].proj) == "plasma", "o golpe agora é a pistola de plasma")
	ok(h.hab_nome == "" and h.def_max == 0.0 and not h.escudo_ativo, "E e secundário apagados no Lobo")
	ok(h.esp_rotulo == "CHAMAR" and is_equal_approx(h.esp_carga, 20.0), "o Q vira CHAMAR com 20 de chamado (%.1f)" % h.esp_carga)
	ok(is_equal_approx(h.folego, fol), "a troca não encheu nem zerou o fôlego")
	ok(is_equal_approx(c.mecha.recarga_mecha, 3.5), "a recarga da E do mecha ficou guardada, exata (%.2f)" % c.mecha.recarga_mecha)
	ok(c.mecha.quebras == 1 and c.mecha.carga_mecha >= 77.0, "o Q do mecha ficou guardado (%.1f, o golpe fatal ainda soma)" % c.mecha.carga_mecha)
	ok(not h.levar_dano(5.0, h.pos + Vector2(10, 0)), "invencível não leva dano")
	# o Lobo atira plasma de verdade
	h.invenc = 0.0
	var antes: int = c.adagas.lancadas
	h.ataque_forcado = true
	passos(60)
	h.ataque_forcado = false
	var tiros: int = c.adagas.lancadas - antes
	ok(tiros >= 3 and tiros <= 4, "pistola: ~3 tiros por segundo (%d em 1 s)" % tiros)
	var negados: int = h.esp_negados
	ok(not h.especial() and h.esp_negados == negados + 1, "chamar sem a carga cheia é negado")


func _t_cartas_e_dano() -> void:
	await novo("lightwolf")
	var h = w.heroi
	quebrar()
	h.invenc = 0.0
	var carga0: float = h.esp_carga
	ok(
		Status.linha(Status.coletar(w), "heroi.vida").bonus == "",
		"no Lobo sem carta o card de status não mostra bônus de vida (%s)" % Status.linha(Status.coletar(w), "heroi.vida").bonus
	)
	# a carta Vida (+20) soma à vida do mecha e o Lobo leva a fração
	h.vida_max += 20.0
	var linha_vida: Dictionary = Status.linha(Status.coletar(w), "heroi.vida")
	ok(linha_vida.bonus == "+20", "no Lobo o card mostra o +20 da carta, não a fração dele (%s)" % linha_vida.bonus)
	ok(
		is_equal_approx(h.vida_mecha_max, 150.0) and is_equal_approx(h.vida_max, 150.0 * 0.31),
		"carta de vida no Lobo vale +20 no mecha (%.1f / %.1f)" % [h.vida_mecha_max, h.vida_max]
	)
	# dano causado enche o chamado: 0,10 por ponto (nível 1)
	w.combate.especial.dano(100.0)
	ok(is_equal_approx(h.esp_carga - carga0, 10.0), "100 de dano causado = +10 de chamado (%.2f)" % (h.esp_carga - carga0))
	var c2: float = h.esp_carga
	w.combate.especial.abate({"chefe": false, "elite": false, "mare": false})
	ok(is_equal_approx(h.esp_carga - c2, 0.8), "abate comum = +0,8")
	c2 = h.esp_carga
	w.combate.especial.abate({"chefe": false, "elite": true, "mare": false})
	ok(is_equal_approx(h.esp_carga - c2, 12.0), "abate de elite = +12")
	c2 = h.esp_carga
	w.combate.especial.abate({"chefe": true, "elite": false, "mare": false})
	ok(is_equal_approx(h.esp_carga - c2, 40.0), "abate de chefe = +40")
	c2 = h.esp_carga
	w.combate.especial.recebeu(10.0)
	ok(is_equal_approx(h.esp_carga, c2), "dano recebido não enche o chamado")
	# o Q do mecha (terremoto) segue com os números comuns
	await novo("lightwolf")
	var carga_mecha0: float = w.heroi.esp_carga
	w.combate.especial.dano(100.0)
	ok(is_equal_approx(w.heroi.esp_carga - carga_mecha0, 100.0 * 0.124), "no mecha o Q segue com os números comuns (%.2f)" % (w.heroi.esp_carga - carga_mecha0))


func _t_chamado() -> void:
	await novo("lightwolf")
	var h = w.heroi
	var c = w.combate
	h.esp_carga = 61.0
	h.hab_recarga = 4.0
	var monstro = w.nascer_monstro("inimigo_cao_ossos", h.pos + Vector2(30, 0))
	monstro.vida = 5000.0
	monstro.vida_max = 5000.0
	monstro.atordoa_t = 0.0
	quebrar()
	var guardada: float = c.mecha.carga_mecha
	h.invenc = 0.0
	h.esp_carga = h.esp_carga_max
	ok(h.especial(), "Lobo com a carga cheia chama o mecha")
	ok(h.estado == Heroi.Estado.ESPECIAL and h.esp_invul and h.forma_lobo, "durante o aviso ainda é Lobo, invulnerável")
	var vida_monstro: float = monstro.vida
	passos(30)
	ok(h.forma_lobo and h.estado == Heroi.Estado.ESPECIAL, "em 0,5 s o mecha ainda não caiu")
	passos(25)
	ok(not h.forma_lobo and h.chave == "lightwolf", "o aviso de 0,8 s acabou: o mecha caiu e o herói voltou a Mecha")
	ok(is_equal_approx(h.vida_max, 130.0) and is_equal_approx(h.vida, 130.0), "mecha com a vida cheia (%.1f)" % h.vida)
	ok(
		h.tipo.w == 64 and h.def_max == 100.0 and h.def == 100.0 and h.hab_nome != "" and h.esp_rotulo != "CHAMAR",
		"folha, E, Q e a barra da matriz do mecha de volta (estava cheia, segue cheia)"
	)
	ok(is_equal_approx(h.esp_carga, guardada) and guardada >= 61.0, "o Q do mecha volta como estava (%.1f de %.1f)" % [h.esp_carga, guardada])
	ok(absf(h.hab_recarga - 4.0) < 0.05, "a E volta com a recarga que tinha na quebra, 4,0 (%.2f): nem zerada nem enchida pela troca" % h.hab_recarga)
	ok(c.especial.limpas == 0, "o chamado não limpa a tela (%d limpezas)" % c.especial.limpas)
	ok(str(c.cfg.golpe.passos[0].proj) == "bala" and is_equal_approx(h.vel_base, 90.0), "tiro de bala e velocidade 90 de volta")
	ok(monstro.vida < vida_monstro, "a queda feriu quem estava em volta (%.1f -> %.1f)" % [vida_monstro, monstro.vida])
	ok(h.estado == Heroi.Estado.LIVRE and c.jogo == "jogando" and c.mecha.chamados == 1, "livre, jogo rolando, um chamado")
	h.invenc = 0.0
	quebrar()
	ok(h.forma_lobo and is_equal_approx(h.vida_max, 130.0 * 0.31) and c.mecha.quebras == 2, "quebra de novo depois do chamado")


## A volta do Lobo NÃO enche a barra da matriz (só a cura repõe; no Difícil ela não recarrega sozinha): o mecha volta com a defesa e a sobrecarga de quando virou Lobo.
func _t_defesa_na_volta() -> void:
	await novo("lightwolf")
	var h = w.heroi
	w.meta_bonus["dificuldade"] = Dificuldade.regras("dificil")
	h.def = 42.0
	quebrar()
	ok(h.forma_lobo and h.def_max == 0.0, "virou Lobo (sem barra)")
	passos(300)  # 5 s de Lobo
	h.invenc = 0.0
	h.esp_carga = h.esp_carga_max
	ok(h.especial(), "chama o mecha")
	passos(70)
	ok(not h.forma_lobo and h.def_max == 100.0, "o mecha voltou")
	ok(h.def == 42.0, "Difícil: volta com os 42 que tinha, não com a barra cheia (%.1f)" % h.def)
	passos(300)
	ok(h.def == 42.0, "e no Difícil ela não recarrega sozinha depois da volta (%.1f)" % h.def)
	h.repor_defesa_de("coracao")
	ok(h.def > 42.0, "a cura repõe (%.1f)" % h.def)
	# a sobrecarga também vai e volta com o mecha
	zerar()
	w.meta_bonus["dificuldade"] = Dificuldade.regras("dificil")
	h.def = 0.0
	h.def_quebrado = true
	quebrar()
	passos(300)
	h.invenc = 0.0
	h.esp_carga = h.esp_carga_max
	h.especial()
	passos(70)
	ok(not h.forma_lobo and h.def == 0.0 and h.def_quebrado, "matriz em sobrecarga continua em sobrecarga na volta (%.1f %s)" % [h.def, h.def_quebrado])
	h.repor_defesa_de("coracao")
	ok(not h.def_quebrado and h.def > 0.0, "e qualquer reposição conserta (Difícil)")
	# recomeçar a partida enche a barra e esquece a reserva
	zerar()
	h.def = 42.0
	quebrar()
	ok(h.def_reserva == 42.0, "a reserva guarda a barra do mecha (%.1f)" % h.def_reserva)
	w.reiniciar()
	passos(3)
	ok(h.def == 100.0 and h.def_reserva < 0.0 and not h.forma_lobo, "partida nova: barra cheia, sem reserva (%.1f)" % h.def)


func _t_chamado_por_tempo() -> void:
	await novo("lightwolf")
	var h = w.heroi
	quebrar()
	h.invenc = 0.0
	var c0: float = h.esp_carga
	passos(60)
	ok(h.esp_carga - c0 > 2.0 and h.esp_carga - c0 < 3.0, "sem monstro o chamado sobe ~2,5 por segundo (%.2f)" % (h.esp_carga - c0))
	h.esp_carga = 90.0
	passos(60 * 5)
	ok(is_equal_approx(h.esp_carga, h.esp_carga_max), "o chamado enche sozinho e para no máximo (%.1f)" % h.esp_carga)
	await novo("lightwolf")
	var m0: float = w.heroi.esp_carga
	passos(120)
	ok(is_equal_approx(w.heroi.esp_carga, m0), "mecha não ganha carga por tempo")


## Trocar a folha com o quadro (linha e coluna) fora dos limites da folha nova prende o recorte dentro dela.
func _t_troca_de_folha() -> void:
	await novo("lightwolf")
	var h = w.heroi
	var pequena: Dictionary = w.sprites.tipo("hazaki")  # a folha antiga do Hazaki: 5 colunas, bem menos que as 38 do mecha
	ok(int(pequena.alb.get_width()) / int(pequena.w) < 30 and int(pequena.alb.get_height()) / int(pequena.h) < 30, "a folha pequena tem menos de 30 colunas")
	h.coluna = 30
	h.linha = 9
	h.trocar_tipo(pequena)
	var larg: int = int(pequena.alb.get_width())
	var alt: int = int(pequena.alb.get_height())
	ok(
		h.coluna * int(pequena.w) + int(pequena.w) <= larg and h.linha * int(pequena.h) + int(pequena.h) <= alt,
		"coluna %d e linha %d cabem na folha %dx%d" % [h.coluna, h.linha, larg, alt]
	)
	ok(h.sprite.region_rect.end.x <= larg and h.sprite.region_rect.end.y <= alt, "o recorte do sprite não sai da folha (%s)" % str(h.sprite.region_rect))
	ok(h.sh1 == null or h.sh1.region_rect == h.sprite.region_rect, "a sombra recorta o mesmo quadro")


func _t_derrota_e_recomeco() -> void:
	await novo("lightwolf")
	var h = w.heroi
	var c = w.combate
	quebrar()
	h.invenc = 0.0
	h.vida = 1.0
	h.levar_dano(50.0, h.pos + Vector2(10, 0))
	ok(h.estado == Heroi.Estado.MORTO and c.jogo == "morrendo", "a morte do Lobo é a derrota, pelo caminho normal")
	ok(h.chave == "lightwolf_lobo", "morre com a folha do Lobo")
	var n := 0
	while c.jogo != "morte" and n < 900:
		passos(1)
		n += 1
	ok(c.jogo == "morte" and c.pausado and c.telas.resultado_aberto, "a tela de resultado abre depois da morte do Lobo (%d quadros)" % n)
	ok(w.olho.visible and w.olho.fecha >= 0.999, "o olho da derrota (#497) fechou por completo (%.2f)" % w.olho.fecha)
	w.reiniciar()
	passos(3)
	ok(not h.forma_lobo and h.chave == "lightwolf" and h.estado != Heroi.Estado.MORTO, "recomeçar volta à forma mecha, viva")
	ok(is_equal_approx(h.vida_max, 130.0) and is_equal_approx(h.vida, 130.0) and h.tipo.w == 128, "vida 130 e folha ampliada do mecha")
	ok(h.esp_rotulo != "CHAMAR" and h.esp_carga < 1.0 and c.mecha.quebras == 0, "Q do mecha zerado, contadores zerados")
	ok(str(c.cfg.golpe.passos[0].proj) == "bala" and h.def_max == 100.0, "tiro do mecha e barra da matriz de volta")
	quebrar()
	w.reiniciar()
	passos(3)
	ok(not h.forma_lobo and h.chave == "lightwolf" and is_equal_approx(h.vida_max, 130.0), "recomeçar como Lobo também volta ao mecha")


func _t_sem_formas() -> void:
	await novo("hazaki")
	var h = w.heroi
	ok(not w.combate.mecha.tem(), "Hazaki não tem formas")
	h.vida = 5.0
	h.levar_dano(99.0, h.pos + Vector2(10, 0))
	ok(h.estado == Heroi.Estado.MORTO and w.combate.jogo == "morrendo" and h.chave == "hazaki", "sem formas, a vida zerada é derrota como sempre")

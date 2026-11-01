extends "res://testes/isolamento_v2.gd"
# Teste automático da BARRA DE DEFESA do escudo (DEF-1; v2/heroi.gd, v2/escudo.gd, dados/v2_secundario.json > escudo > barra, dados/v2_dificuldade.json):
# a barra é própria (def, def_max), separada do fôlego; segurar gasta max/gasto_s por segundo; cada golpe barrado custa 0,5 x o dano (piso 1, teto 12);
# o bloqueio perfeito não custa e devolve; a recarga espera o atraso, é mais lenta andando e vale defesa_regen_mult (1,5 / 1,0 / 0,0: no Difícil 60 s sem
# apanhar não mudam a defesa); a cura repõe a barra por chamada explícita (coração, carta Cura, nível, curandeiro), nunca dentro de curar(); o escudo não mexe em
# `cansado`; defesa zerada quebra o escudo. O mundo anda em passos fixos de 1/60 s.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_escudo_barra.tscn  (imprime "v2_escudo_barra falhas=0")
const Mundo := preload("res://v2/mundo.tscn")
const Heroi := preload("res://v2/heroi.gd")
const Dificuldade := preload("res://v2/dificuldade.gd")
const PASSO := 1.0 / 60.0
var falhas := 0
var w


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func perto(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func passos(n: int) -> void:
	for i in n:
		w.avancar(PASSO)


## Começa de novo na dificuldade `dif`: mapa sem monstros, herói parado e mortal, mirando para a direita, escudo baixo e a barra cheia.
func zerar(dif := "facil") -> void:
	w.reiniciar()
	w.combate.limpar_partida()
	w.combate.diretor.ligado = false
	w.meta_bonus["dificuldade"] = Dificuldade.regras(dif)
	var h = w.heroi
	h.imortal = false
	h.entrada_forcada = Vector2.ZERO
	h.ataque_forcado = null
	h.correr_forcado = null
	h.ruptura_forcada = false
	h.escudo_forcado = false
	h.m_vel_mov = 1.0
	h.vida = h.vida_max
	h.folego = h.folego_max
	h.cansado = false
	h.def = h.def_max
	h.def_atraso_t = 0.0
	h.def_quebrado = false
	h.invenc = 0.0
	h.fonte = Heroi.Fonte.MOUSE
	w.mouse_forcado = h.centro() + Vector2(100, 0)
	passos(3)
	h.def = h.def_max  # os passos de aquecimento não mexem, mas garante
	h.def_atraso_t = 0.0


func monstro_a(dx: float):
	var m = w.nascer_monstro("inimigo_cao_ossos", w.heroi.pos + Vector2(dx, 0))
	m.atordoa_t = 0.0
	m.vida = 5000.0
	m.vida_max = 5000.0
	m.emp = Vector2.ZERO
	return m


func _ready() -> void:
	w = Mundo.instantiate()
	w.modo_teste = true
	add_child(w)
	w.set_process(false)
	w.combate.audio.mudo = true
	var h = w.heroi
	var esc = w.combate.escudo
	esc.herois["hazaki"] = "escudo"  # DEF-2: o escudo é só do Nick; a barra do escudo é testada no herói padrão, a quem o dado devolve o escudo neste teste
	h._iniciar_defesa()
	var rit = w.combate.ritmo
	var d: Dictionary = Dados.json("v2_secundario")
	var b: Dictionary = d.escudo.barra

	# 1. dados e contrato do herói
	ok(float(b.max) == 100.0 and float(b.gasto_s) == 5.0, "barra: máximo 100 e gasto de 5 por segundo (20 s erguido)")
	ok(
		float(b.atraso_recarga) == 2.5 and float(b.regen_parado) == 3.0 and float(b.regen_andando) == 2.0,
		"barra: atraso 2,5 s, recarga 3,0 parado e 2,0 andando"
	)
	ok(not d.escudo.has("gasto") and not d.escudo.has("gasto_golpe") and not d.escudo.has("folego_min"), "os números do escudo no fôlego saíram do dado")
	zerar()
	ok(h.def_max == 100.0 and h.def == 100.0 and not h.def_quebrado, "o herói do escudo nasce com a barra cheia (%s de %s)" % [h.def, h.def_max])
	var regras: Array = Dificuldade.opcoes()
	var mults := {}
	for r in regras:
		mults[str(r.id)] = float(r.get("defesa_regen_mult", -1.0))
	ok(mults == {"facil": 1.5, "medio": 1.0, "dificil": 0.0}, "defesa_regen_mult: 1,5 / 1,0 / 0,0 (%s)" % [mults])
	var texto_dificil := ""
	for r in regras:
		if str(r.id) == "dificil":
			texto_dificil = str(r.desc)
	ok(texto_dificil.contains("escudo") and texto_dificil.contains("cura"), "o texto do Difícil avisa que o escudo só volta com cura (%s)" % texto_dificil)

	# 2. gasto parado: erguido sem apanhar dura max / gasto_s
	zerar()
	h.escudo_forcado = true
	var passos_ate := 0
	for i in 1500:
		passos(1)
		if h.def_quebrado:
			passos_ate = i + 1
			break
	var seg := float(passos_ate) * PASSO
	ok(perto(seg, float(b.max) / float(b.gasto_s), 0.2), "parado sem apanhar a barra dura max/gasto_s = 20 s (durou %s s)" % seg)
	ok(h.def == 0.0 and h.def_quebrado and not h.escudo_ativo, "zerou: o escudo quebrou e caiu")
	ok(not h.cansado and h.folego >= h.folego_max - 0.001, "o escudo não mexe em `cansado` nem no fôlego (cansado %s, fôlego %s)" % [h.cansado, h.folego])
	passos(20)
	ok(not h.escudo_ativo, "quebrado, segurar o botão não ergue o escudo de novo")
	var q = esc.visual_estado()
	ok(q.quebrado, "o visual do escudo mostra a quebra")

	# 3. custo por golpe: 0,5 x o dano, piso 1, teto 12
	ok(perto(esc.custo_golpe(6.0), 3.0, 0.001) and perto(esc.custo_golpe(14.0), 7.0, 0.001), "cão (6) custa 3 e cavaleiro (14) custa 7")
	ok(perto(esc.custo_golpe(1.0), 1.0, 0.001) and perto(esc.custo_golpe(0.2), 1.0, 0.001), "piso: golpe fraco custa 1")
	ok(perto(esc.custo_golpe(40.0), 12.0, 0.001) and perto(esc.custo_golpe(24.0), 12.0, 0.001), "teto: golpe de chefe custa 12")
	zerar()
	h.escudo_forcado = true
	passos(40)  # fora da janela do perfeito
	var m1 = monstro_a(14)
	var antes: float = h.def
	h.levar_dano(14.0, m1.pos, m1)
	ok(perto(antes - h.def, 7.0, 0.001) and h.vida == h.vida_max, "golpe de 14 barrado custa 7 de defesa, sem dano na vida (%s para %s)" % [antes, h.def])
	var m2 = monstro_a(14)
	antes = h.def
	h.levar_dano(40.0, m2.pos, m2)
	ok(perto(antes - h.def, 12.0, 0.001), "golpe de chefe barrado custa o teto, 12")
	# perfeito: custo 0 e devolve
	zerar()
	h.escudo_forcado = true
	passos(2)
	h.def = 50.0
	var m3 = monstro_a(14)
	h.levar_dano(14.0, m3.pos, m3)
	ok(
		esc.ultimo.get("perfeito", false) == true and perto(h.def, 50.0 + float(b.perfeito.devolve), 0.001),
		"bloqueio perfeito: sem custo e devolve +%s (defesa %s)" % [b.perfeito.devolve, h.def]
	)
	# golpe barrado que zera a barra quebra o escudo
	zerar()
	h.escudo_forcado = true
	passos(40)
	h.def = 4.0
	var m4 = monstro_a(14)
	h.levar_dano(14.0, m4.pos, m4)
	ok(h.def == 0.0 and h.def_quebrado, "o golpe que zera a barra quebra o escudo")
	ok(h.vida == h.vida_max, "o golpe que quebrou o escudo ainda foi barrado (sem dano de vida)")
	passos(2)
	ok(not h.escudo_ativo and not h.cansado, "quebrou: o escudo caiu, sem cansar o herói")

	# 4. recarga: espera o atraso, parado é mais rápido que andando, e vale a dificuldade
	for dif in ["facil", "medio"]:
		zerar(dif)
		h.def = 40.0
		h.def_atraso_t = float(b.atraso_recarga)
		passos(int(float(b.atraso_recarga) * 60.0) - 6)
		ok(perto(h.def, 40.0, 0.001), "%s: durante o atraso (2,5 s) a defesa não sobe" % dif)
		passos(66)  # passa do atraso e anda 1 s de recarga
		var mult := float(Dificuldade.regras(dif).defesa_regen_mult)
		ok(
			h.def > 40.0 + float(b.regen_parado) * mult * 0.6 and h.def < 40.0 + float(b.regen_parado) * mult * 1.4,
			"%s: depois do atraso sobe a %s x 3,0/s parado (%s)" % [dif, mult, h.def]
		)
	# andando: 2,0 em vez de 3,0
	zerar("medio")
	h.def = 10.0
	h.def_atraso_t = 0.0
	h.entrada_forcada = Vector2(-1, 0)
	passos(60)
	ok(perto(h.def, 10.0 + float(b.regen_andando), 0.2), "andando a recarga é de 2,0/s (%s)" % h.def)
	# vazio a cheio em cerca de 33 s parado, no Médio
	zerar("medio")
	h.def = 0.0
	h.def_quebrado = true
	h.def_atraso_t = 0.0
	passos(60 * 31)
	ok(h.def < h.def_max, "Médio: vazio a cheio leva mais de 31 s parado (%s)" % h.def)
	passos(60 * 4)
	ok(h.def >= h.def_max - 0.001, "Médio: vazio a cheio em cerca de 33 s parado (%s)" % h.def)
	ok(not h.def_quebrado, "recarregou: o escudo volta a poder erguer")
	# segurar o escudo não recarrega e baixar reabre o atraso
	zerar("facil")
	h.def = 50.0
	h.escudo_forcado = true
	passos(60)
	ok(h.def < 50.0 - 4.0, "erguido, a defesa só cai (%s)" % h.def)
	h.escudo_forcado = false
	passos(3)
	ok(h.def_atraso_t > float(b.atraso_recarga) - 0.2, "baixar o escudo reabre o atraso de recarga (%s s)" % h.def_atraso_t)
	# levar golpe pelas costas também adia
	zerar("facil")
	h.def = 50.0
	h.def_atraso_t = 0.0
	var mc = monstro_a(-12)
	h.levar_dano(5.0, mc.pos, mc)
	ok(h.def_atraso_t > float(b.atraso_recarga) - 0.01, "levar um golpe adia a recarga")

	# 5. Difícil: 60 s sem apanhar não mudam a defesa
	zerar("dificil")
	h.def = 40.0
	h.def_atraso_t = 0.0
	passos(60 * 60)
	ok(h.def == 40.0, "Difícil: 60 s sem apanhar não mudam a defesa (%s)" % h.def)
	h.entrada_forcada = Vector2(-1, 0)
	passos(60 * 5)
	ok(h.def == 40.0, "Difícil: andando também não recarrega (%s)" % h.def)
	h.entrada_forcada = Vector2.ZERO
	# e o que repõe continua repondo no Difícil
	h.repor_defesa_de("coracao")
	ok(perto(h.def, 75.0, 0.001), "Difícil: o coração do mapa repõe +35%% da barra (%s)" % h.def)

	# 6. reposição pela cura, nas três dificuldades
	for dif in ["facil", "medio", "dificil"]:
		zerar(dif)
		h.def = 10.0
		h.vida = h.vida_max  # vale com a vida cheia: o valor nominal
		rit.limpar()
		rit.soltar("cura", h.pos)
		rit.atualizar(0.01)
		ok(perto(h.def, 45.0, 0.001) and rit.coletados.cura >= 1, "%s: coletar um coração repõe +35%% da barra, com a vida cheia (%s)" % [dif, h.def])
		h.def = 10.0
		w.combate.cartas.aplicar({"id": "cura", "cat": "stat", "stat": "cura", "valor": 0.0})
		ok(h.def == h.def_max, "%s: a carta Cura enche a barra (%s)" % [dif, h.def])
		h.def = 10.0
		h.nivel = 1
		h.xp = 0.0
		w.combate.progresso.ganhar_xp(h.xp_proximo * w.combate.velocidade + 0.01)
		ok(h.nivel == 2 and perto(h.def, 25.0, 0.001), "%s: subir de nível repõe +15%% da barra (%s)" % [dif, h.def])
		rit.limpar()
		h.def = 10.0
		h.vida = h.vida_max * 0.5
		rit.soltar("curandeiro", h.pos)
		for i in 60:
			rit.atualizar(1.0 / 60.0)
		ok(perto(h.def, 20.0, 0.1), "%s: o curandeiro repõe +10%% por segundo dentro da aura (%s)" % [dif, h.def])
		rit.limpar()
	# curar() sozinha não repõe (a carta Vida também a chama)
	zerar("facil")
	h.def = 10.0
	h.vida = 1.0
	h.curar(50.0)
	ok(h.def == 10.0, "Heroi.curar() não repõe a defesa (a carta Vida usa curar)")
	# o baú não repõe
	zerar("facil")
	h.def = 10.0
	h.encher_folego()
	ok(h.def == 10.0, "encher o fôlego (baú) não repõe a defesa")
	# a reposição não passa do máximo
	zerar("facil")
	h.def = 90.0
	h.repor_defesa_de("coracao")
	ok(h.def == h.def_max, "a reposição para no máximo (%s)" % h.def)

	# 7. quebrado: Fácil e Médio voltam ao passar de 25%; no Difícil qualquer reposição conserta
	zerar("medio")
	h.def = 0.0
	h.def_quebrado = true
	h.repor_defesa(0.15)
	ok(h.def_quebrado and perto(h.def, 15.0, 0.001), "Médio: com 15%% ainda está quebrado (%s)" % h.def)
	h.repor_defesa(0.15)
	ok(not h.def_quebrado, "Médio: passou de 25%%, o escudo volta (%s)" % h.def)
	zerar("dificil")
	h.def = 0.0
	h.def_quebrado = true
	h.escudo_forcado = true
	passos(30)
	ok(not h.escudo_ativo, "Difícil quebrado: não ergue")
	passos(60 * 20)
	ok(h.def == 0.0 and h.def_quebrado, "Difícil quebrado: 20 s depois continua quebrado, sem recarga sozinha")
	h.repor_defesa_de("nivel")
	passos(3)
	ok(not h.def_quebrado and h.escudo_ativo, "Difícil: a próxima reposição conserta e o escudo ergue (%s)" % h.def)
	h.escudo_forcado = false

	# 8. sem escudo, sem barra
	zerar()
	var chave0: String = h.chave
	esc.herois["teste_sem"] = "outro_secundario"
	h.chave = "teste_sem"
	h.iniciar_stats(w.combate.cfg)
	ok(h.def_max == 0.0 and h.def == 0.0, "herói sem escudo: def_max 0 (a HUD esconde a barra)")
	h.repor_defesa_de("coracao")
	h.repor_defesa(1.0)
	ok(h.def == 0.0, "herói sem escudo: a reposição não faz nada")
	h.chave = chave0
	esc.herois.erase("teste_sem")
	h.iniciar_stats(w.combate.cfg)
	ok(h.def_max == 100.0, "voltando ao herói do escudo a barra volta")

	# 9. o painel de status mostra a barra e a recarga
	zerar("facil")
	var Status := preload("res://v2/status.gd")
	var secs: Array = Status.coletar(w)
	var lin_def: Dictionary = Status.linha(secs, "heroi.defesa")
	var lin_rec: Dictionary = Status.linha(secs, "heroi.defesa_recarga")
	ok(
		str(lin_def.get("valor", "")).begins_with("100") and str(lin_def.get("valor", "")).contains("20"),
		"status: Defesa do escudo 100 (20 s erguido) (%s)" % lin_def.get("valor", "")
	)
	ok(str(lin_rec.get("valor", "")).contains("4,5"), "status: no Fácil a recarga é 4,5/s parado (%s)" % lin_rec.get("valor", ""))
	zerar("dificil")
	secs = Status.coletar(w)
	lin_rec = Status.linha(secs, "heroi.defesa_recarga")
	ok(str(lin_rec.get("valor", "")).contains("cura"), "status: no Difícil a recarga diz 'só com cura' (%s)" % lin_rec.get("valor", ""))

	print("v2_escudo_barra falhas=%d" % falhas)
	get_tree().quit()

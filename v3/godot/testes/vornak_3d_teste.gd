extends SceneTree
## Teste do protótipo 3D do Vornak (cena_3d/vornak_3d.tscn).
## Roda: godot --headless --fixed-fps 60 --path v3/godot -s res://testes/vornak_3d_teste.gd  (imprime "vornak_3d falhas=0")
## Confere: glb e 13 animações; sons carregam e disparam (contador); andar -> aviso -> impacto com dano por golpe;
## tempos da folha (aviso e recuperação de cada ataque, com o quadro de impacto no fim do aviso); câmera suavizada e
## presa à grade de texels; luta simulada com o herói parado apanhando e batendo (60 a 90 s); fase 2 e morte.

const CENA := "res://cena_3d/vornak_3d.tscn"
const GLB := "res://assets/3d/vornak.glb"
const ANIMS := ["Idle", "Walk", "Run", "Attack_01", "Attack_02", "Attack_03", "Attack_04_Segunda_Forma",
	"Hit", "Stagger", "Ability", "Phase_Transition", "Death", "Grito"]
const SONS := ["passo", "rugido", "estalo_madeira", "terra_rachando", "zumbido_energia", "golpe_chao", "succao_absorcao"]
## tempos da folha (VORNAK_COMBATE.md): nome -> [aviso, recuperação]
const TEMPOS := {"raizes": [0.9, 0.6], "golpe": [0.7, 0.6], "absorcao": [1.2, 0.8], "raizes_longas": [0.6, 0.5]}
const DT := 1.0 / 60.0

var falhas := 0
var sons_total := {}


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)
	else:
		print("ok: ", msg)


func _initialize() -> void:
	_rodar.call_deferred()


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func nova_cena() -> Node:
	root.size = Vector2i(1280, 720)  # janela do jogo: a SubViewport fica 640x360 (2x)
	var c: Node = (load(CENA) as PackedScene).instantiate()
	root.add_child(c)
	return c


func somar_sons(vornak: Node) -> void:
	for k in vornak.contador_sons:
		sons_total[k] = int(sons_total.get(k, 0)) + int(vornak.contador_sons[k])


func _rodar() -> void:
	ok(load(GLB) is PackedScene, "glb carrega (%s)" % GLB)
	for s in SONS:
		var a := load("res://assets/audio/vornak/%s.wav" % s) as AudioStreamWAV
		ok(a != null and a.mix_rate == 22050 and a.get_length() > 0.2, "som %s.wav carrega (22050 Hz, %.2f s)" % [s, a.get_length() if a else 0.0])
	await _etapa_combate()
	await _etapa_tempos()
	await _etapa_camera()
	await _etapa_luta()
	for s in SONS:
		ok(int(sons_total.get(s, 0)) > 0, "som %s disparado (%d vezes)" % [s, int(sons_total.get(s, 0))])
	print("vornak_3d falhas=", falhas)
	quit(1 if falhas > 0 else 0)


# ---------------- 1. combate básico, fase 2 e morte ----------------
func _etapa_combate() -> void:
	var cena := nova_cena()
	var mundo: Node3D = cena.get_node("Tela/Viewport/Mundo")
	var vornak: Node3D = mundo.get_node("Vornak")
	var heroi: CharacterBody3D = mundo.get_node("Heroi")
	heroi.controle_ligado = false
	heroi.position = Vector3(1.4, 0, 2.2)  # dentro do círculo das raízes
	var vida_antes: float = mundo.vida_heroi
	await quadros(2)
	var lista: PackedStringArray = vornak.nomes_animacoes()
	var faltam := []
	for a in ANIMS:
		if not lista.has(a):
			faltam.append(a)
	ok(vornak.animador != null, "AnimationPlayer encontrado")
	ok(faltam.is_empty() and lista.size() == 13, "AnimationPlayer com as 13 animações (tem %d, faltam %s)" % [lista.size(), faltam])
	ok(vornak.sons.size() == 7, "7 sons carregados no Vornak (%d)" % vornak.sons.size())
	ok(mundo.estado == "andar", "começa andando")
	ok(mundo.VIDA_CHEFE == 1400.0, "vida do chefe 1400 (folha: 1200 a 1600)")
	var golpe_antes := int(vornak.contador_sons["golpe_chao"])
	await quadros(180)
	var h: Array = mundo.historico
	var i_av := h.find("aviso")
	var i_im := h.find("impacto")
	ok(h[0] == "andar" and i_av > 0 and i_im > i_av, "estado andar -> aviso -> impacto (%s)" % [h])
	ok(mundo.ataques_feitos.size() > 0 and mundo.ataques_feitos[0] == "raizes", "primeiro ataque são as raízes (círculo de 3 m)")
	ok(is_equal_approx(vida_antes - mundo.vida_heroi, 30.0), "raízes tiram 30 do herói, uma vez (%d -> %d)" % [vida_antes, mundo.vida_heroi])
	ok(not mundo.indicadores["raizes"].visible, "indicador some depois do aviso")
	ok(int(vornak.contador_sons["golpe_chao"]) > golpe_antes, "golpe no chão tocou no impacto das raízes")
	var vida_chefe: float = mundo.vida
	heroi.global_position = vornak.global_position + Vector3(0.8, 0, 0.8)
	ok(heroi.bater(), "herói acerta o chefe de perto")
	ok(is_equal_approx(vida_chefe - mundo.vida, mundo.DANO_HEROI), "vida do chefe cai %d no golpe do herói" % mundo.DANO_HEROI)
	mundo.vida = mundo.VIDA_CHEFE * 0.41
	mundo.receber_dano(mundo.DANO_HEROI * 2.0)
	ok(mundo.estado == "transicao", "abaixo de 40%% entra na transição (vida %d)" % mundo.vida)
	await quadros(int(60.0 * (mundo.t_transicao + 0.2)))
	ok(mundo.fase == 2, "fase 2 aberta depois da transição")
	ok(int(vornak.contador_sons["rugido"]) > 0, "rugido do Grito tocou na transição")
	mundo.receber_dano(mundo.vida + 10.0)
	ok(mundo.estado == "morto" and not mundo.ativo, "morte para o combate")
	await quadros(2)
	ok(vornak.animacao_atual() == "Death", "toca Death")
	await quadros(60)
	ok(mundo.estado == "morto" and mundo.historico[-1] == "morto", "1 s depois continua morto, sem novos estados")
	var algum := false
	for k in mundo.areas:
		for ar in mundo.areas[k]:
			algum = algum or ar.monitoring
	ok(not algum, "nenhuma área de dano ligada depois da morte")
	somar_sons(vornak)
	cena.queue_free()
	await quadros(2)


# ---------------- 2. tempos de aviso e recuperação ----------------
func _etapa_tempos() -> void:
	var cena := nova_cena()
	var mundo: Node3D = cena.get_node("Tela/Viewport/Mundo")
	var vornak: Node3D = mundo.get_node("Vornak")
	var heroi: CharacterBody3D = mundo.get_node("Heroi")
	heroi.controle_ligado = false
	heroi.position = Vector3(1.0, 0, 1.0)
	mundo.ataques_ligados = false
	await quadros(3)
	var pos_impacto := {}
	mundo.estado_mudou.connect(func(e: String):
		if e == "impacto":
			pos_impacto[mundo.ataque.nome] = vornak.animador.current_animation_position)
	for nome in TEMPOS:
		var n0: int = mundo.historico.size()
		mundo.forcar_ataque(nome)
		var limite := 0
		while mundo.estado != "andar" and limite < 600:
			await physics_frame
			limite += 1
		var h: Array = mundo.historico.slice(n0)
		var t: Array = mundo.historico_t.slice(n0)
		if h.size() < 4 or h[0] != "aviso" or h[1] != "impacto" or h[2] != "recupera":
			ok(false, "%s passa por aviso -> impacto -> recupera -> andar (%s)" % [nome, h])
			continue
		var aviso: float = t[1] - t[0]
		var impacto: float = t[2] - t[1]
		var recupera: float = t[3] - t[2]
		var a: Dictionary = {}
		for x in mundo.ATAQUES:
			if x.nome == nome:
				a = x
		var t_imp: float = mundo.t_impacto_clipe(a)
		var p_imp: float = float(pos_impacto.get(nome, -1.0))
		print("   %s: aviso %.3f s, impacto %.3f s, recuperação %.3f s, clipe no impacto %.3f s (quadro de impacto %.3f s), vel. aviso %.2fx, vel. recuperação %.2fx, cortado %.2f s do clipe" % [
			nome, aviso, impacto, recupera, p_imp, t_imp, mundo.vel_aviso, mundo.vel_recupera, mundo.clipe_cortado(a)])
		ok(absf(aviso - TEMPOS[nome][0]) <= DT + 0.001, "%s: aviso de %.2f s (folha %.1f s)" % [nome, aviso, TEMPOS[nome][0]])
		ok(absf(recupera - TEMPOS[nome][1]) <= DT + 0.001, "%s: recuperação de %.2f s (folha %.1f s)" % [nome, recupera, TEMPOS[nome][1]])
		ok(absf(p_imp - t_imp) <= 2.0 / 12.0, "%s: quadro de impacto do clipe cai no fim do aviso (%.2f vs %.2f s)" % [nome, p_imp, t_imp])
		await quadros(5)
	somar_sons(vornak)
	cena.queue_free()
	await quadros(2)


# ---------------- 3. câmera: suavização e grade de texels ----------------
func _etapa_camera() -> void:
	var cena := nova_cena()
	var mundo: Node3D = cena.get_node("Tela/Viewport/Mundo")
	var vornak: Node3D = mundo.get_node("Vornak")
	var heroi: CharacterBody3D = mundo.get_node("Heroi")
	var camera: Camera3D = mundo.get_node("Camera")
	var modelo: Node3D = vornak.get_node("Modelo")
	heroi.controle_ligado = false
	mundo.ataques_ligados = false
	mundo.pode_correr = false
	heroi.position = Vector3(-6.0, 0, 8.0)
	await quadros(3)
	var tx: float = cena.texel()
	ok(cena.get_node("Tela/Viewport").size == Vector2i(640, 360), "resolução interna 640x360")
	ok(is_equal_approx(tx, camera.size / 360.0), "texel = size / 360 = %.4f m" % tx)
	var b := camera.global_transform.basis
	var pior_cam := 0.0
	var pior_mod := 0.0
	var andou := 0.0
	var p0 := vornak.global_position
	for i in 120:  # 2 s andando; a cena registra o erro de grade no fim do seu _process (o estado que vai para a tela)
		await physics_frame
		pior_cam = maxf(pior_cam, cena.erro_grade_camera)
		pior_mod = maxf(pior_mod, cena.erro_grade_modelo)
	andou = (vornak.global_position - p0).length()
	ok(andou > 2.0, "chefe andou %.2f m em 2 s (vel. %.1f m/s)" % [andou, mundo.VEL_ANDAR])
	ok(pior_cam < 0.01 and pior_mod < 0.01, "câmera e modelo presos à grade de texels ao andar (erro máx. %.4f e %.4f texel)" % [pior_cam, pior_mod])
	# suavização: depois de um salto de 1 m do alvo, em 0,15 s a câmera anda ~63% (1 - e^-1)
	mundo.ativo = false
	await quadros(60)
	var c0 := camera.global_position
	vornak.global_position += b.x * 1.0
	await quadros(9)  # 0,15 s
	var feito := (camera.global_position - c0).dot(b.x)
	ok(feito > 0.5 and feito < 0.75, "suavização da câmera: %.0f%% do salto em 0,15 s (esperado ~63%%)" % (feito * 100.0))
	somar_sons(vornak)
	cena.queue_free()
	await quadros(2)


# ---------------- 4. luta simulada: herói parado, apanhando e batendo ----------------
func _etapa_luta() -> void:
	var cena := nova_cena()
	var mundo: Node3D = cena.get_node("Tela/Viewport/Mundo")
	var vornak: Node3D = mundo.get_node("Vornak")
	var heroi: CharacterBody3D = mundo.get_node("Heroi")
	heroi.controle_ligado = false
	heroi.position = Vector3(1.06, 0, 1.06)  # 1,5 m à frente do chefe, dentro do alcance do golpe do herói
	await quadros(2)
	var dano_recebido := {}
	mundo.heroi_atingido.connect(func(d: float):
		var n: String = mundo.ataque.nome
		dano_recebido[n] = float(dano_recebido.get(n, 0.0)) + d)
	var t0: float = mundo.relogio
	var t_fase2 := -1.0
	var limite := 60 * 240
	while mundo.estado != "morto" and not mundo.heroi_morto and limite > 0:
		heroi.bater()
		await physics_frame
		limite -= 1
		if t_fase2 < 0.0 and mundo.fase == 2:
			t_fase2 = mundo.relogio - t0
	var dur: float = mundo.relogio - t0
	var vencedor := "herói (chefe morto)" if mundo.estado == "morto" else ("chefe (herói caiu)" if mundo.heroi_morto else "ninguém")
	print("   LUTA: %.1f s; vencedor: %s; vida do chefe %d/%d; vida do herói %d/%d; fase 2 aos %.1f s; curou %d; ataques %d; dano por ataque %s" % [
		dur, vencedor, mundo.vida, mundo.VIDA_CHEFE, mundo.vida_heroi, mundo.VIDA_HEROI, t_fase2, mundo.curado,
		mundo.ataques_feitos.size(), dano_recebido])
	ok(dur >= 60.0 and dur <= 90.0, "luta com o herói parado apanhando dura 60 a 90 s (%.1f s)" % dur)
	ok(t_fase2 > 0.0, "a luta passou pela fase 2")
	somar_sons(vornak)
	cena.queue_free()
	await quadros(2)

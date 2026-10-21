extends "res://testes/isolamento_v2.gd"
# Teste do robô de playtest da v2 (#301, funções _pt_* do v2/roteiro.gd). Roda o jogo de verdade num SUBPROCESSO do Godot, com a
# mesma linha que o lote usa (ferramentas/playtest_v2.py), e confere:
#   a) partida curta (--playtest_max=30): código 0, uma linha PLAYTEST_JSON válida, desfecho "tempo" no teto e nível >= 1;
#   b) prova do vigia (--playtest_trava=cartas): o robô deixa a tela de cartas aberta, o vigia imprime "TRAVA: tela_escolha" e o
#      processo sai com código 3 e desfecho "trava", sem nenhuma carta escolhida;
#   d) partida que termina em morte (--playtest_fim=morte, se o roteiro tiver): é a que grava a meta no save temporário;
#   c) os arquivos reais do jogador (save da meta, personagens, opções) têm o mesmo md5 antes e depois, e o save temporário do
#      robô (user://playtest/meta_<pid>.cfg, com .tmp e .bak) não sobra.
# As partidas rodam uma depois da outra (o CI já roda 4 cenas em paralelo), com um prazo só para o teste inteiro: estourou, o filho
# é morto (OS.kill) e o teste falha, sem deixar processo órfão. A saída de cada filho vai para um log próprio (--log-file), lido
# depois que ele termina. A espera usa só get_process_exit_code: no Godot 4.4.1 para Linux, is_process_running guarda o status cru
# do waitpid, e o código 3 viraria 768.
# No notebook, KIKIU_GODOT_FILA aponta para o wrapper PowerShell: rode esta cena sozinha (pai e filho usam as duas vagas).
# O marcador do helper identifica o Godot real; a espera da fila não gasta o prazo e um timeout nunca mata o wrapper.
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_playtest.tscn  (imprime "v2_playtest falhas=0")
const Meta := preload("res://v2/meta.gd")
const Personagens := preload("res://v2/personagens.gd")
const TETO_CURTA := 30  # segundos de JOGO da partida curta (uns 8 s reais)
const TETO_MORTE := 90  # segundos de JOGO até um monstro matar o robô parado (a Floresta leva uns 50 s de jogo, uns 12 s reais)
const TETO_VIGIA := 150  # a 1ª tela de cartas abre perto de 62 s de jogo; se não abrir, a partida acaba em "tempo" e o teste falha
const PRAZO_S := 80  # prazo do teste inteiro, em segundos reais (o CI corta a cena em 120 s)
const PASTA := "user://playtest"  # contrato do robô de produção: um save temporário por PID
const SEM_ARQUIVO := "(não existe)"
# arquivos da v1 que uma partida da v2 não deveria tocar (conferidos de quebra)
const OUTROS_REAIS := [
	"user://testes_v2/v2_playtest/calor.json",
	"user://testes_v2/v2_playtest/recordes.json",
	"user://testes_v2/v2_playtest/online.json",
	"user://testes_v2/v2_playtest/heroi_criado.json"
]

var falhas := 0
var t0 := 0
var _fila_ms := 0  # espera do wrapper fica fora do prazo do jogo; o CI sem wrapper mantém o prazo de antes


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	t0 = Time.get_ticks_msec()
	print("v2_playtest: executável %s, pid do teste %d" % [OS.get_executable_path(), OS.get_process_id()])
	var antes := _retrato_real()
	var curta := _partida("curta", ["--playtest_max=%d" % TETO_CURTA])
	_conferir(curta, _conferir_curta)
	var vigia := _partida("vigia", ["--playtest_trava=cartas", "--playtest_max=%d" % TETO_VIGIA])
	_conferir(vigia, _conferir_vigia)
	# d) caminho da morte: é o único que grava a meta (registrar_partida), então só ele prova o save temporário e a limpeza dele.
	#    Depende de --playtest_fim=morte no roteiro.gd; sem a opção, a conferência é pulada (e avisada), não falha.
	if FileAccess.get_file_as_string("res://v2/roteiro.gd").contains("playtest_fim"):
		var morte := _partida("morte", ["--playtest_fim=morte", "--playtest_max=%d" % TETO_MORTE])
		_conferir(morte, _conferir_morte)
	else:
		print("v2_playtest: AVISO: roteiro.gd sem --playtest_fim; o caminho da morte (save do robô) NÃO foi conferido")
	var depois := _retrato_real()
	var chaves := antes.keys()
	for p in depois.keys():
		if not chaves.has(p):
			chaves.append(p)
	for p in chaves:
		var a: String = antes.get(p, SEM_ARQUIVO)
		var d: String = depois.get(p, SEM_ARQUIVO)
		ok(a == d, "arquivo real alterado pela partida: %s (md5 antes %s, depois %s)" % [p, a, d])
	print("v2_playtest: %.1f s no total" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("v2_playtest falhas=%d" % falhas)
	get_tree().quit(0 if falhas == 0 else 1)


## md5 de cada arquivo real do jogador que a partida poderia gravar (SEM_ARQUIVO se ainda não existe). Lista explícita, nunca a raiz
## user:// inteira: no CI outras cenas criam e apagam arquivos teste_* lá ao mesmo tempo.
func _retrato_real() -> Dictionary:
	var lista: Array = []
	for p in [Meta.caminho_save, Personagens.caminho_indice, Personagens.caminho_antigo, Config.arquivo] + OUTROS_REAIS:
		lista.append_array([p, p + ".tmp", p + ".bak"])
	var prefixo := Personagens.caminho_base.get_file()  # o save de cada personagem: v2_personagem_<id>.cfg (e .tmp, .bak)
	if DirAccess.dir_exists_absolute("user://testes_v2/v2_playtest/"):
		for f in DirAccess.get_files_at("user://testes_v2/v2_playtest/"):
			if f.begins_with(prefixo):
				lista.append("user://testes_v2/v2_playtest/" + f)
	var r := {}
	for arq in lista:
		r[arq] = FileAccess.get_md5(arq) if FileAccess.file_exists(arq) else SEM_ARQUIVO
	return r


func _decorrido() -> float:
	return (Time.get_ticks_msec() - t0 - _fila_ms) / 1000.0


## Roda uma partida do robô num processo novo e devolve {nome, pid, codigo, saida, s}. codigo -1: não terminou no prazo (foi morto).
func _partida(nome: String, extras: Array) -> Dictionary:
	var r := {"nome": nome, "pid": -1, "codigo": -1, "saida": "", "s": 0.0}
	if _decorrido() > PRAZO_S:
		ok(false, "%s: sem tempo para rodar (o prazo de %d s do teste já passou)" % [nome, PRAZO_S])
		return r
	var log_partida := AmbienteTesteV2.arquivo("playtest_%s.log" % nome)
	_apagar(log_partida)
	var args := PackedStringArray(["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--log-file", ProjectSettings.globalize_path(log_partida), "res://v2/mundo.tscn"])
	args.append_array(["--", "--playtest", "--heroi=hazaki", "--mapa=floresta", "--semente=1"])
	args.append_array(extras)
	# O notebook exige a fila para qualquer Godot novo, inclusive o filho. O CI Linux não define esta variável.
	var fila := OS.get_environment("KIKIU_GODOT_FILA")
	var pela_fila := fila != ""
	var executavel := OS.get_executable_path()
	var pid_arquivo := AmbienteTesteV2.arquivo("playtest_%s.pid" % nome)
	var pid_env_anterior := OS.get_environment(AmbienteTesteV2.ENV_PID)
	if pela_fila:
		if OS.get_name() != "Windows" or not FileAccess.file_exists(fila):
			ok(false, "%s: KIKIU_GODOT_FILA exige um script PowerShell existente no Windows" % nome)
			return r
		executavel = "powershell.exe"
		var argumentos_fila := PackedStringArray(["-NoProfile", "-File", fila])
		argumentos_fila.append_array(args)
		args = argumentos_fila
		_apagar(pid_arquivo)
		OS.set_environment(AmbienteTesteV2.ENV_PID, pid_arquivo)
	var inicio := Time.get_ticks_msec()
	var launcher_pid := OS.create_process(executavel, args)
	if pela_fila:
		OS.set_environment(AmbienteTesteV2.ENV_PID, pid_env_anterior)
	r.pid = -1 if pela_fila else launcher_pid
	if launcher_pid <= 0:
		ok(false, "%s: OS.create_process falhou" % nome)
		return r
	var codigo := -1
	var ultimo := inicio
	var esgotou := false
	while codigo == -1:
		if pela_fila and int(r.pid) <= 0:
			# O hook inicial da fixture escreve o PID antes do jogo. Até lá o wrapper pode estar só esperando uma vaga.
			var agora := Time.get_ticks_msec()
			_fila_ms += agora - ultimo
			ultimo = agora
			if FileAccess.file_exists(pid_arquivo):
				r.pid = int(FileAccess.get_file_as_string(pid_arquivo))
		if not esgotou and int(r.pid) > 0 and _decorrido() > PRAZO_S:
			esgotou = true
			var erro_matar := OS.kill(int(r.pid))
			ok(erro_matar == OK, "%s: não foi possível encerrar o Godot %d (%d)" % [nome, int(r.pid), erro_matar])
			ok(false, "%s: a partida passou do prazo de %d s do teste; encerrando Godot %d" % [nome, PRAZO_S, int(r.pid)])
			# no Linux o kill já espera o fim do processo; no Windows o TerminateProcess não, e o pid sai do mapa (get_process_exit_code
			# volta -1 para sempre): um respiro curto antes de ler e apagar o log
			OS.delay_msec(300)
			if not pela_fila:
				break
			# Nunca mata o wrapper: espera seu finally liberar a vaga após o Godot terminar.
		OS.delay_msec(100)
		codigo = OS.get_process_exit_code(launcher_pid)
	if pela_fila:
		ok(int(r.pid) > 0, "%s: filho sem marcador de PID; falta o hook inicial da fixture" % nome)
		_apagar(pid_arquivo)
	r.codigo = -1 if esgotou else codigo
	r.s = (Time.get_ticks_msec() - inicio) / 1000.0
	if FileAccess.file_exists(log_partida):
		r.saida = FileAccess.get_file_as_string(log_partida)
	else:
		ok(false, "%s: o log da partida não foi criado (%s)" % [nome, log_partida])
	_apagar(log_partida)
	return r


## O que vale para as duas partidas, mais a conferência própria de cada uma; se algo falhou, mostra o log do filho.
func _conferir(r: Dictionary, propria: Callable) -> void:
	if r.codigo == -1:  # não rodou ou foi morta no prazo: a falha já foi contada em _partida; o resto seria só cascata
		_mostrar_log(r)
		return
	var antes := falhas
	var saida: String = r.saida
	var j := _json(r)
	print(
		(
			"v2_playtest: %s pid=%d codigo=%d em %.1f s reais; desfecho=%s trava=%s tempo_jogo=%s nivel=%s"
			% [r.nome, r.pid, r.codigo, r.s, j.get("desfecho"), j.get("trava"), j.get("tempo_jogo"), j.get("nivel")]
		)
	)
	ok(not saida.contains("SCRIPT ERROR"), "%s: SCRIPT ERROR na partida" % r.nome)
	ok(str(j.get("heroi", "")) == "hazaki" and str(j.get("mapa", "")) == "floresta", "%s: herói ou mapa diferente do pedido" % r.nome)
	ok(int(j.get("semente", -1)) == 1, "%s: semente %s (pedida 1)" % [r.nome, j.get("semente")])
	if r.pid > 0:  # o save temporário do robô (mundo.gd aponta Meta.caminho_save para ele) sai junto com a partida
		var base := "%s/meta_%d.cfg" % [PASTA, r.pid]
		for arq in [base, base + ".tmp", base + ".bak"]:
			ok(not FileAccess.file_exists(arq), "%s: o save temporário do robô sobrou: %s" % [r.nome, arq])
		if j.has("save"):  # quando o PLAYTEST_JSON trouxer o caminho do save, ele tem de ser o deste processo
			ok(str(j.save) == base, "%s: o robô gravou em %s, esperava %s" % [r.nome, j.save, base])
	propria.call(r, j)
	if falhas > antes:
		_mostrar_log(r)


func _conferir_curta(r: Dictionary, j: Dictionary) -> void:
	var saida: String = r.saida
	ok(r.codigo == 0, "curta: código de saída %d (esperava 0)" % r.codigo)
	ok(not saida.contains("TRAVA:"), "curta: o vigia acusou trava numa partida normal")
	ok(str(j.get("desfecho", "")) == "tempo", 'curta: desfecho %s (esperava "tempo", pelo teto de %d s)' % [j.get("desfecho"), TETO_CURTA])
	ok(str(j.get("trava", "?")) == "", "curta: campo trava preenchido (%s)" % j.get("trava"))
	var t := float(j.get("tempo_jogo", -1.0))
	ok(t >= TETO_CURTA and t < TETO_CURTA + 1.0, "curta: tempo_jogo %.1f fora do teto de %d s" % [t, TETO_CURTA])
	ok(int(j.get("nivel", 0)) >= 1, "curta: nível %s (esperava >= 1)" % j.get("nivel"))


func _conferir_morte(r: Dictionary, j: Dictionary) -> void:
	ok(r.codigo == 0, "morte: código de saída %d (esperava 0)" % r.codigo)
	ok(not str(r.saida).contains("TRAVA:"), "morte: o vigia acusou trava")
	ok(str(j.get("desfecho", "")) == "morte", 'morte: desfecho %s (esperava "morte")' % j.get("desfecho"))
	ok(str(j.get("trava", "?")) == "", "morte: campo trava preenchido (%s)" % j.get("trava"))


func _conferir_vigia(r: Dictionary, j: Dictionary) -> void:
	var tem_linha := false
	for linha in str(r.saida).split("\n"):
		if linha.begins_with("TRAVA: tela_escolha "):
			tem_linha = true
	ok(r.codigo == 3, "vigia: código de saída %d (esperava 3, o da trava)" % r.codigo)
	ok(tem_linha, 'vigia: faltou a linha "TRAVA: tela_escolha ..." (a tela de cartas aberta demais)')
	ok(str(j.get("desfecho", "")) == "trava", 'vigia: desfecho %s (esperava "trava")' % j.get("desfecho"))
	ok(str(j.get("trava", "")) == "tela_escolha", "vigia: trava %s (esperava tela_escolha)" % j.get("trava"))
	var cartas = j.get("cartas", null)
	ok(cartas is Array and cartas.is_empty(), "vigia: o robô escolheu carta com --playtest_trava=cartas (%s)" % str(cartas))


## A linha PLAYTEST_JSON da partida: exige uma só, com um objeto JSON válido. Devolve {} se faltar.
func _json(r: Dictionary) -> Dictionary:
	var achadas := []
	for linha in str(r.saida).split("\n"):
		if linha.begins_with("PLAYTEST_JSON: "):
			achadas.append(linha.trim_prefix("PLAYTEST_JSON: ").strip_edges())
	ok(achadas.size() == 1, "%s: esperava uma linha PLAYTEST_JSON, vieram %d" % [r.nome, achadas.size()])
	if achadas.is_empty():
		return {}
	var j = JSON.parse_string(achadas[0])
	ok(j is Dictionary, "%s: a linha PLAYTEST_JSON não é um objeto JSON válido" % r.nome)
	return j if j is Dictionary else {}


## O log do filho sem o ruído de vazamento que o Godot imprime ao sair.
func _mostrar_log(r: Dictionary) -> void:
	print("--- log da partida %s (pid %d, código %d):" % [r.nome, r.pid, r.codigo])
	for linha in str(r.saida).split("\n"):
		var l := linha.strip_edges(false, true)
		if l == "" or l.contains("leaked") or l.contains("still in use") or l.begins_with("   at:"):
			continue
		print("  | ", l)
	print("--- fim do log da partida %s" % r.nome)


func _apagar(caminho: String) -> void:
	if FileAccess.file_exists(caminho):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))

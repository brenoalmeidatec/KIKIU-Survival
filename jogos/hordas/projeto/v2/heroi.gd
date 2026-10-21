extends "res://v2/ator.gd"
## Herói da v2 (o escolhido no santuário: Hazaki, Nicão ou Lucas, v2/herois.gd; os números vêm do cfg dele): anda com WASD, setas e analógico esquerdo; fica virado para o MOUSE (8 direções) quando o mouse mexe, e para onde
## anda quando a direção de andar muda; com o controle, o analógico direito manda. Anima parado e andando com a folha do protótipo.
##
## Combate (números em dados/v2_combate.json):
##  - GOLPE no clique (ação "atacar") na direção do cursor: combo de 3 (corte, corte, estocada). Clique dentro da janela depois do golpe
##    encadeia o próximo; segurar o botão repete o combo. O dano sai no quadro "acerto_em" do golpe (combate.golpear), o herói avança um
##    pouco (lunge) e anda devagar enquanto golpeia. A esquiva cancela o fim do golpe.
##  - ESQUIVA (ação "esquiva", Espaço): rolamento com fôlego (cargas que voltam com o tempo) e invulnerabilidade no começo (porte do
##    movimento.json da v1).
##  - CORRER (ação "correr", Shift/L3): ~1,6x a velocidade de andar, gasta o MESMO fôlego da esquiva por segundo. Fôlego zerado = CANSADO:
##    não corre nem esquiva até recuperar ~30%, e anda mais devagar. A recuperação começa depois de um atraso sem gastar e é mais rápida
##    parado. Atacar cancela a corrida. A câmera adianta um pouco na direção da corrida.
##  - VIDA: ao apanhar fica invencível um instante, piscando, e leva um empurrão.
##  - ESCUDO (ação "escudo", botão direito do mouse ou gatilho esquerdo; é o SECUNDÁRIO deste herói, definido em dados/v2_secundario.json; v2/escudo.gd):
##    segurar ergue um escudo na frente (arco de ~120 graus na direção da mira) que bloqueia o dano vindo da frente (levar_dano). Anda a 60%, não
##    corre nem golpeia e gasta o fôlego da corrida; o bloqueio nos primeiros ~0,15 s é PERFEITO (empurra e atordoa quem bateu, sem gasto).
##  - RUPTURA (ação "ruptura", tecla E ou LB do controle; números em dados/v2_ruptura.json, disparo em v2/ruptura.gd): o APERTO
##    (evento) pede, a POSSE (polling) carrega. Estado.CARGA anda a 45%, não corre nem golpeia, NÃO é invencível e apanhar não cancela. Soltar
##    com carga mínima dispara em 360 graus (soltura perfeita na janela depois da carga cheia). Cancelam sem disparar e sem gastar recarga: a
##    esquiva, a pausa/escolha/baú/resultado (combate.jogo e pausado), a morte e o salto de relógio (ESC e perda de foco).
##  - ESPECIAL (ação "ultimate", tecla Q ou RB; um por herói, dados/v2_especial.json, disparo em v2/especial.gd): o APERTO dispara na hora. Estado.ESPECIAL
##    dura `esp_dur` s, não golpeia nem corre, é INVULNERÁVEL e cancela a ruptura, o escudo e a esquiva. Sem a carga cheia o aperto é negado. A carga
##    (esp_carga, 0 a 100) NÃO corre por tempo: enche por dano causado, abates e dano recebido (combate chama especial.dano, abate e recebeu) e zera ao disparar.
##  - HABILIDADE (ação "ruptura", tecla E ou LB; UMA POR HERÓI, dados/v2_habilidade.json, disparo em v2/habilidade.gd): `hab_id` diz qual. "ruptura" (Hazaki)
##    segue o caminho da RUPTURA acima (rup_*). Os outros (investida_escudo do Nicão, salto_adagas do Lucas) disparam no APERTO: Estado.HABILIDADE dura `hab_dur` s,
##    não golpeia nem corre, é INVULNERÁVEL e cancela a ruptura, o escudo e a esquiva; o Q cancela a E. Na recarga o aperto é negado. A recarga corre por tempo
##    (hab_recarga) e a partida começa com a E pronta.
## API pública lida pelo HUD (get() com padrão): vida, vida_max, xp, xp_proximo, nivel, folego, folego_max, cansado (bool), correndo (bool), da
## ruptura rup_carga (0 a 1), rup_recarga, rup_recarga_max, rup_perfeita, rup_nega_t, contragolpe_t e contragolpe_max, e do especial esp_nome,
## esp_rotulo, esp_cor, esp_carga, esp_carga_max, esp_nega_t e esp_t (s desde o disparo; 0 fora do especial), e da habilidade hab_id, hab_nome,
## hab_rotulo, hab_icone, hab_cor, hab_recarga, hab_recarga_max, hab_nega_t e hab_t (a ruptura segue publicando rup_*).

const Herois := preload("res://v2/herois.gd")

enum Fonte { ANDA, MOUSE, STICK }
enum Estado { LIVRE, GOLPE, ESQUIVA, MORTO, CARGA, ESPECIAL, HABILIDADE }  # CARGA, ESPECIAL e HABILIDADE no fim: nada é renumerado
const VEL := 100.0  # px/s
const PASSO_ANIM := 0.13  # s por quadro de andar
const MORTE_DISSOLVE := 0.3  # s de jogo (relógio do herói: hit-stop e câmera lenta esticam) que o corpo leva para se desfazer
const MORTE_FLASH := 0.2  # fração inicial da dissolução em que o corpo fica branco (o "flash" do golpe fatal)
const SHADER_MORTE := """
shader_type canvas_item;
uniform float dissolver : hint_range(0.0, 1.0) = 0.0;
uniform float branco : hint_range(0.0, 1.0) = 0.0;
// Coordenadas da textura: a máscara não muda com o tempo nem com a rotação do sprite. O progresso vem do relógio de jogo.
float ruido_pixel(vec2 pixel) {
	return fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	float ruido = ruido_pixel(floor(UV / TEXTURE_PIXEL_SIZE));
	float resta = step(dissolver, ruido);
	float borda = (1.0 - smoothstep(0.0, 0.08, ruido - dissolver)) * resta;
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), max(branco, borda * 0.25));
	COLOR.a *= resta;
}
"""
const CENTRO_CORPO := Vector2(0, -20)  # do pé ao meio do corpo (mira e câmera)
const ORIGEM_GOLPE := Vector2(0, -10)  # de onde o arco do golpe parte (altura do tronco, no chão do 2.5D)

# ---- API pública (HUD)
var vida := 100.0
var vida_max := 100.0
var xp := 0.0
var xp_proximo := 5.0
var nivel := 1
var folego := 3.0  # fôlego em cargas (fracionário), gasto por esquiva (um bloco) e corrida (por segundo)
var folego_max := 3.0
var _credito_abate := 1.0  # fôlego que os abates ainda podem devolver agora (ver ganhar_folego_abate)
var cansado := false  # fôlego zerou: sem correr nem esquivar até recuperar
var golpe_calor_t := 0.0  # Médio/Difícil: ao zerar fôlego, o ataque principal espera o calor baixar.
var correndo := false
var vel_base := VEL  # px/s de andar do herói escolhido (cfg.heroi.vel, v2/herois.gd); o VEL é só o padrão

# ---- modificadores das melhorias (progresso.gd)
var m_dano := 1.0
var m_vel_ataque := 1.0
var m_area := 1.0
var m_vel_mov := 1.0
var m_ima := 1.0
var m_critico := 0.0

var mundo
var fonte := Fonte.ANDA
var estado := Estado.LIVRE
var dir_olhar := Vector2(0, 1)  # para onde está virado (nunca zero)
var mira_mundo := Vector2.ZERO  # ponto do mundo para onde o golpe vai (mouse ou analógico direito)
var entrada_forcada: Variant = null  # testes, fotos e medição: um Vector2 aqui vale no lugar do teclado e do controle
var ataque_forcado: Variant = null  # idem para o botão de atacar segurado (true/false); só vale com entrada_forcada
var correr_forcado: Variant = null  # idem para o botão de correr segurado
var ruptura_forcada: Variant = null  # idem para o botão da ruptura segurado
var escudo_forcado: Variant = null  # idem para o botão do escudo (secundário) segurado
var _soltar_ataque := false  # o botão de atacar que fechou uma tela (escolha, baú) já foi gasto: só volta a golpear depois de soltá-lo
var avanco_camera := Vector2.ZERO  # para onde a câmera adianta ao correr (px, suavizado)
var imortal := false  # medição e roteiros: ninguém tira vida
var andando := false
var vel := Vector2.ZERO  # deslocamento real do último quadro, px/s
var emp := Vector2.ZERO  # empurrão que o herói leva ao apanhar (px/s)
var invenc := 0.0  # s de invencibilidade que faltam (ao apanhar)
# golpe
var golpe_i := 0  # índice do passo do combo em andamento
var golpe_t := 0.0
var golpe_dur := 0.0
var golpe_cfg: Dictionary = {}
var golpe_dir := Vector2.RIGHT
var golpe_acertou := false
var proximo := 0  # passo do combo que o próximo clique vai dar
var combo_t := 0.0  # janela que sobra para encadear
var pausa_t := 0.0  # folga depois da estocada
var pedido_t := 0.0  # clique guardado
var golpes := 0  # quantos golpes saíram (testes)
# esquiva
var esq_t := 0.0
var esq_dur := 0.42
var esq_inv := 0.3
var esq_dir := Vector2.RIGHT
var esq_pedido := 0.0
var esquivas := 0
# escudo (secundário, botão direito)
var escudo_ativo := false  # o escudo está erguido (lido pelo desenho e pelo levar_dano)
var escudo_t := 0.0  # s desde que ergueu (tempo do mundo): a janela do bloqueio perfeito
var escudo_bloqueios := 0  # testes
var escudo_perfeitos := 0  # testes
# especial (tecla Q, v2/especial.gd)
var esp_nome := ""  # o nome do especial do herói ("" = não tem): o HUD só acende o slot Q com ele
var esp_rotulo := ""  # o texto curto do slot
var esp_cor := Color.WHITE  # o brilho do slot e dos efeitos
var esp_carga := 0.0  # a carga da ultimate, de 0 a esp_carga_max: enche por dano causado, abates e dano recebido (NUNCA por tempo); zera ao disparar
var esp_carga_max := 100.0  # a carga cheia: com ela o Q dispara
var esp_nega_t := 0.0  # s do "negado" (apertou na recarga): o slot do HUD treme
var esp_t := 0.0  # s desde o disparo (0 fora do especial)
var esp_dur := 1.0  # a duração do especial em andamento
var esp_invul := false  # invulnerável enquanto dura (lido por vulneravel)
var esp_anim_passo := 2  # o passo do combo cuja animação toca no especial
var esp_anim_ciclos := 1.0  # quantas vezes ela toca durante a duração
var esp_disparos := 0  # testes
var esp_negados := 0  # testes
# habilidade (tecla E, v2/habilidade.gd; a ruptura de quem tem hab_id "ruptura" usa os rup_* acima)
var hab_id := "ruptura"  # qual E o herói tem: "ruptura" (rup_*), investida_escudo, salto_adagas... ("" = nenhuma)
var hab_nome := ""  # o nome da E (o HUD)
var hab_rotulo := ""  # o texto curto do slot
var hab_icone := ""  # o id do ícone (assets/v2/icones_cartas)
var hab_cor := Color.WHITE  # o brilho do slot e dos efeitos
var hab_recarga := 0.0  # s até poder usar a E de novo (por tempo; o tempo do mundo corre)
var hab_recarga_max := 1.0  # a recarga cheia, para o HUD desenhar a fração
var hab_nega_t := 0.0  # s do "negado" (apertou na recarga): o slot do HUD treme
var hab_t := 0.0  # s desde o disparo (0 fora da E)
var hab_dur := 1.0  # a duração da E em andamento
var hab_invul := false  # invulnerável enquanto dura (lido por vulneravel)
var hab_anim_passo := 0  # o passo do combo cuja animação toca na E
var hab_anim_ciclos := 1.0  # quantas vezes ela toca durante a duração
var hab_disparos := 0  # testes
var hab_negados := 0  # testes
# ruptura (tecla E)
var rup_carga := 0.0  # fração da carga (0 a 1) lida pelo HUD e pelo desenho do anel
var rup_carga_t := 0.0  # s de carga (tempo do mundo)
var rup_recarga := 0.0  # s até poder carregar de novo
var rup_recarga_max := 1.0  # a recarga do último disparo (o HUD desenha a fração)
var rup_perfeita := false  # a carga está na janela da soltura perfeita
var rup_nega_t := 0.0  # s do "negado" (apertou na recarga): o slot do HUD treme
var contragolpe_t := 0.0  # s que faltam do bônus de dano da katana depois de um disparo que acertou
var contragolpe_max := 1.5  # a janela cheia, para o HUD
var rup_pedido_t := 0.0  # aperto guardado
var rup_disparos := 0  # testes
var rup_cancelados := 0  # testes
var _rup_us := 0  # Time.get_ticks_usec() do último quadro da carga (salto de relógio)
var _rup_apos_acerto := false  # o aperto veio depois do acerto do golpe: cancela o resto do golpe (antes do acerto, espera o golpe acabar)
var _rup_tique := 0  # quantos marcos de som a carga atual já tocou
var _rup_punch := 0.0
var _esq_rastro := 0.0
var _atraso_t := 0.0  # s até o fôlego começar a voltar
var _poeira_t := 0.0
var _ofego_t := 0.0
var _punch := 0.0
var _anda_ant := Vector2.ZERO
var _anim := 0.0
var _dano_t := -1.0  # s desde que apanhou (animação de dano da folha); negativo = fora da animação
var _morte_t := 0.0  # s desde que morreu (animação de morte da folha)
var _off_base := Vector2.ZERO
var morte_t := 0.0  # s de jogo desde a morte (só anda em _visual_morto, no dt do herói: hit-stop e pausa o congelam)
var _mat_morte: ShaderMaterial = null


func criar(m, pai: Node, t: Dictionary, p: Vector2) -> void:
	mundo = m
	chave = str(mundo.combate.heroi_id)  # o herói escolhido (v2/herois.gd): a folha de sprites já vem em `t`
	raio = float(Herois.heroi(chave).get("raio", 6.0))
	montar_animado(pai, t, p, 0, 0, false)
	_off_base = sprite.offset


## Lê as vidas e as regras do dados/v2_combate.json (chamado pelo combate depois de criar o herói).
func iniciar_stats(cfg: Dictionary) -> void:
	golpe_calor_t = 0.0
	vel_base = float(cfg.heroi.get("vel", VEL))
	vida_max = float(cfg.heroi.vida)
	vida = vida_max
	folego_max = float(cfg.folego.max)
	folego = folego_max
	cansado = false
	correndo = false
	escudo_ativo = false
	escudo_t = 0.0
	var esp = mundo.combate.especial
	if esp != null:
		esp.armar(self)  # o nome, a cor e a carga (0) do especial deste herói
	var hab = mundo.combate.habilidade
	if hab != null:
		hab.armar(self)  # a E deste herói (id, nome, ícone, cor) pronta
	_atraso_t = 0.0
	esq_dur = float(cfg.esquiva.tempo)
	esq_inv = float(cfg.esquiva.invulneravel)


## Volta ao começo de uma partida (jogar de novo).
func resetar(p: Vector2) -> void:
	m_dano = 1.0
	m_vel_ataque = 1.0
	m_area = 1.0
	m_vel_mov = 1.0
	m_ima = 1.0
	m_critico = 0.0
	xp = 0.0
	nivel = 1
	estado = Estado.LIVRE
	escudo_ativo = false
	escudo_t = 0.0
	escudo_bloqueios = 0
	escudo_perfeitos = 0
	emp = Vector2.ZERO
	invenc = 0.0
	combo_t = 0.0
	pausa_t = 0.0
	pedido_t = 0.0
	esq_pedido = 0.0
	proximo = 0
	rup_carga = 0.0
	rup_carga_t = 0.0
	rup_recarga = 0.0
	rup_recarga_max = 1.0
	rup_perfeita = false
	rup_nega_t = 0.0
	contragolpe_t = 0.0
	rup_pedido_t = 0.0
	_rup_apos_acerto = false
	rup_disparos = 0
	rup_cancelados = 0
	if mundo.combate.especial != null:
		mundo.combate.especial.cancelar(self)
	esp_disparos = 0
	esp_negados = 0
	esp_t = 0.0
	esp_invul = false
	if mundo.combate.habilidade != null:
		mundo.combate.habilidade.cancelar(self)
	hab_disparos = 0
	hab_negados = 0
	hab_t = 0.0
	hab_invul = false
	hab_recarga = 0.0
	hab_nega_t = 0.0
	_rup_tique = 0
	_rup_punch = 0.0
	avanco_camera = Vector2.ZERO
	_punch = 0.0
	_dano_t = -1.0
	_morte_t = 0.0
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	sprite.position = Vector2.ZERO
	sprite.offset = _off_base
	sprite.material = null
	morte_t = 0.0
	definir_pos(p)
	iniciar_stats(mundo.combate.cfg)


## O botão de atacar foi apertado (o mundo repassa o clique; os testes também chamam): guarda o pedido por alguns instantes.
func atacar() -> void:
	pedido_t = float(mundo.combate.cfg.golpe.buffer)


func esquivar() -> void:
	esq_pedido = float(mundo.combate.cfg.golpe.buffer)


## Uma tela (escolha de carta, baú) acabou de fechar com o botão de atacar possivelmente apertado: o golpe por segurar (polling) fica
## desligado até o botão ser solto, para o clique que escolheu a carta não virar um golpe no quadro seguinte.
func exigir_soltar_ataque() -> void:
	_soltar_ataque = true


## O botão da ruptura foi apertado (o mundo repassa o evento; os testes também chamam). Só pede: quem carrega é a POSSE do botão (_livre).
## Na recarga (mais que o buffer) é negado: som grave e o slot do HUD treme. Antes do quadro de acerto de um golpe, o pedido espera o golpe acabar.
func ruptura() -> void:
	var c = mundo.combate
	if hab_id != "ruptura":  # a E deste herói não é a ruptura: dispara na hora (ou não faz nada, se não tem E)
		habilidade()
		return
	if c.ruptura == null or c.jogo != "jogando" or c.pausado or _pausa_aberta() or estado == Estado.MORTO or estado == Estado.CARGA:
		return
	var buffer := float(c.cfg.golpe.buffer)
	if rup_recarga > buffer:
		rup_nega_t = float(c.ruptura.cfg.nega_t)
		c.ruptura.negou(self)
		return
	rup_pedido_t = buffer
	_rup_apos_acerto = estado == Estado.GOLPE and golpe_acertou
	if estado == Estado.GOLPE and not golpe_acertou:
		rup_pedido_t += maxf(golpe_dur - golpe_t, 0.0)


## O botão da E foi apertado e a E do herói NÃO é a ruptura (investida do Nicão, salto do Lucas): dispara na hora, se o jogo está rolando e a recarga
## zerou. Cancela o golpe, a ruptura em carga, o escudo e a esquiva. Na recarga é negado: som grave e o slot do HUD treme. Devolve true se disparou.
func habilidade() -> bool:
	var c = mundo.combate
	if (
		c.habilidade == null
		or c.jogo != "jogando"
		or c.pausado
		or _pausa_aberta()
		or estado == Estado.MORTO
		or estado == Estado.HABILIDADE
		or estado == Estado.ESPECIAL
	):
		return false
	if hab_nome == "" or hab_id == "ruptura":
		return false  # este herói não tem E (ou a dele é a ruptura)
	if hab_recarga > 0.0:
		hab_nega_t = float(c.habilidade.comum.nega_t)
		hab_negados += 1
		c.habilidade.negou(self)
		return false
	cancelar_ruptura(false)
	_baixar_escudo()
	estado = Estado.HABILIDADE
	pedido_t = 0.0
	combo_t = 0.0
	proximo = 0
	rup_pedido_t = 0.0
	esq_pedido = 0.0
	_rup_apos_acerto = false
	correndo = false
	if not c.habilidade.iniciar(self):
		estado = Estado.LIVRE
		return false
	hab_disparos += 1
	return true


## O botão do especial foi apertado (o mundo repassa o evento; os testes também chamam): dispara na hora, se o jogo está rolando e a carga está cheia.
## Cancela o golpe, a ruptura em carga, o escudo e a esquiva. Sem a carga cheia é negado: som grave e o slot do HUD treme. Devolve true se disparou.
func especial() -> bool:
	var c = mundo.combate
	if c.especial == null or c.jogo != "jogando" or c.pausado or _pausa_aberta() or estado == Estado.MORTO or estado == Estado.ESPECIAL:
		return false
	if esp_nome == "":
		return false  # este herói não tem especial
	if esp_carga < esp_carga_max:
		esp_nega_t = float(c.especial.comum.nega_t)
		esp_negados += 1
		c.especial.negou(self)
		return false
	cancelar_ruptura(false)
	_baixar_escudo()
	if c.habilidade != null:
		c.habilidade.cancelar(self)  # o Q corta a E em andamento
	estado = Estado.ESPECIAL
	pedido_t = 0.0
	combo_t = 0.0
	proximo = 0
	rup_pedido_t = 0.0
	esq_pedido = 0.0
	_rup_apos_acerto = false
	correndo = false
	if not c.especial.iniciar(self):
		estado = Estado.LIVRE
		return false
	esp_disparos += 1
	return true


func entrada_evento(e: InputEvent) -> void:
	if e.is_action_pressed("atacar", false, true):
		atacar()
	elif InputMap.has_action("ultimate") and e.is_action_pressed("ultimate", false, true):
		especial()
	elif InputMap.has_action("esquiva") and e.is_action_pressed("esquiva", false, true):
		esquivar()
	elif InputMap.has_action("ruptura") and e.is_action_pressed("ruptura", false, true):
		# o gatilho analógico manda um evento a cada mexida: só a borda (o aperto de verdade) conta, senão o "negado" repetiria
		if not (e is InputEventJoypadMotion) or Input.is_action_just_pressed("ruptura"):
			ruptura()


func vivo() -> bool:
	return estado != Estado.MORTO


## Centro do corpo (mira, câmera, orbes vão para cá).
func centro() -> Vector2:
	return pos + CENTRO_CORPO


## Dano que o herói pode levar agora? (fora da invencibilidade e dos i-frames da esquiva)
func vulneravel() -> bool:
	if estado == Estado.MORTO or imortal or invenc > 0.0:
		return false
	if estado == Estado.ESPECIAL and esp_invul:
		return false
	if estado == Estado.HABILIDADE and hab_invul:
		return false
	return not (estado == Estado.ESQUIVA and esq_t < esq_inv)


func curar(v: float) -> void:
	vida = minf(vida_max, vida + v)


## Velocidade de andar (px/s) com o bônus de movimento, e a de correr. O card de status (status.gd) lê estas duas; `_livre` anda com elas.
## Velocidade de andar (px/s): a base do herói escolhido (cfg.heroi.vel) com o modificador de movimento das cartas.
func vel_andar() -> float:
	return vel_base * m_vel_mov


func vel_correr() -> float:
	return vel_andar() * float(mundo.combate.cfg.corrida.velocidade)


## Alcance do ímã de almas (px): a distância em que o orbe começa a voar para o herói (combate.atualizar).
func alcance_ima() -> float:
	return float(mundo.combate.cfg.heroi.ima_raio) * m_ima


## Duração (s) do passo `i` do combo com a velocidade de ataque de agora.
func duracao_do_passo(i: int) -> float:
	return float(mundo.combate.cfg.golpe.passos[i].duracao) / m_vel_ataque


## O que o abate devolve de fôlego (modificador "Fôlego de caçador"), com o TETO por segundo de dados/v2_combate.json (folego.abate_max_s). Sem ele, 4 cartas
## (12% a 38% por abate cada, vezes a raridade) numa horda de dezenas de abates por segundo enchiam a barra na hora e o fôlego nunca acabava (nível 30, #374).
## O crédito é um balde: enche abate_max_s por segundo até abate_max_s (1 s de folga) e cada abate gasta dele; teto 0 ou ausente = sem limite.
func ganhar_folego_abate(x: float) -> void:
	var teto := float(mundo.combate.cfg.folego.get("abate_max_s", 0.0))
	if teto > 0.0:
		x = minf(x, _credito_abate)
		_credito_abate -= x
	if x > 0.0:
		ganhar_folego(x)


## Fôlego que volta: sai do cansaço se passar do limite.
func ganhar_folego(x: float) -> void:
	folego = minf(folego_max, folego + x)
	if cansado and folego >= float(mundo.combate.cfg.folego.cansado_ate) * folego_max:
		cansado = false


## Levou `valor` de dano de algo em `de` (mundo); `quem` é o monstro que bateu (null: ataque de área). Devolve true se o golpe foi CONSUMIDO: o
## dano entrou ou o escudo barrou (quem chama arma a recarga do golpe nos dois casos; o dano barrado não tira vida nem dá invencibilidade).
## `bloqueavel` = false é o dano de AMBIENTE (espinhos do mapa): não há quem bateu nem de onde vem, então o escudo não barra.
func levar_dano(valor: float, de: Vector2, quem = null, bloqueavel := true) -> bool:
	if not vulneravel():
		return false
	var esc = mundo.combate.escudo
	if bloqueavel and escudo_ativo and esc != null and esc.cobre(self, de):
		esc.bloquear(self, valor, de, quem)
		return true
	vida = maxf(0.0, vida - valor)
	invenc = float(mundo.combate.cfg.heroi.invencivel)
	var d := pos - de
	emp = (d.normalized() if d.length() > 0.5 else -dir_olhar) * float(mundo.combate.cfg.heroi.recuo_dano)
	if estado == Estado.GOLPE:  # apanhar corta o golpe e o combo
		estado = Estado.LIVRE
		combo_t = 0.0
		proximo = 0
	mundo.combate.heroi_apanhou(valor)
	_dano_t = 0.0
	if vida <= 0.0:
		_morte_t = 0.0
		cancelar_ruptura(false)
		escudo_ativo = false
		estado = Estado.MORTO
		_iniciar_morte()
		mundo.combate.heroi_morreu()
	return true


func atualizar(dt: float) -> void:
	var real := entrada_forcada == null
	var v: Vector2 = entrada_forcada if not real else Input.get_vector("esquerda", "direita", "cima", "baixo")
	if estado == Estado.MORTO:
		_visual_morto(dt)
		return
	if real and InputMap.has_action("mira_esquerda"):
		var s := Input.get_vector("mira_esquerda", "mira_direita", "mira_cima", "mira_baixo")
		if s.length() > 0.3:
			fonte = Fonte.STICK
			dir_olhar = s.normalized()
	# a direção de andar mudou (começou a andar ou virou): passa a olhar para onde anda, até o mouse mexer de novo
	if v != Vector2.ZERO and (_anda_ant == Vector2.ZERO or v.normalized().dot(_anda_ant.normalized()) < 0.9):
		fonte = Fonte.ANDA
	_anda_ant = v
	# relógios
	invenc = maxf(0.0, invenc - dt)
	golpe_calor_t = maxf(0.0, golpe_calor_t - dt)
	pedido_t = maxf(0.0, pedido_t - dt)
	esq_pedido = maxf(0.0, esq_pedido - dt)
	pausa_t = maxf(0.0, pausa_t - dt)
	if rup_recarga > 0.0 or rup_pedido_t > 0.0 or rup_nega_t > 0.0 or contragolpe_t > 0.0:
		_rup_relogios(dt)
	if hab_recarga > 0.0 or hab_nega_t > 0.0:
		_hab_relogios(dt)
	if esp_nega_t > 0.0:
		esp_nega_t = maxf(0.0, esp_nega_t - dt)  # só o tremor do slot: a carga do Q não corre por tempo
	_recuperar(dt, v == Vector2.ZERO and (estado == Estado.LIVRE or estado == Estado.CARGA))
	var segurando := false
	if real:
		segurando = InputMap.has_action("atacar") and Input.is_action_pressed("atacar")
		if _soltar_ataque:  # o aperto que escolheu a carta ainda está lá: não conta como golpe até soltar
			_soltar_ataque = segurando
			segurando = false
	elif ataque_forcado != null:
		segurando = bool(ataque_forcado)
	# mira (sempre calculada: o golpe sai para ela)
	var c := centro()
	if fonte == Fonte.MOUSE and estado != Estado.GOLPE and estado != Estado.ESPECIAL and estado != Estado.HABILIDADE:
		var d: Vector2 = mundo.mouse_mundo() - c
		if d.length() > 4.0:
			dir_olhar = d.normalized()
	mira_mundo = c + dir_olhar * 120.0 if fonte != Fonte.MOUSE else mundo.mouse_mundo()
	var desl := Vector2.ZERO
	match estado:
		Estado.LIVRE:
			desl = _livre(dt, v, segurando)
		Estado.GOLPE:
			desl = _golpe(dt, v)
		Estado.ESQUIVA:
			desl = _esquiva(dt)
		Estado.CARGA:
			desl = _carga(dt, v)
		Estado.ESPECIAL:
			desl = mundo.combate.especial.quadro(self, dt, v)
		Estado.HABILIDADE:
			desl = mundo.combate.habilidade.quadro(self, dt, v)
	if emp.length_squared() > 4.0:
		desl += emp * dt
		emp *= exp(-11.0 * dt)
	else:
		emp = Vector2.ZERO
	if estado != Estado.LIVRE:
		correndo = false
		_baixar_escudo()
	var antes := pos
	if desl != Vector2.ZERO:
		mundo.mover(self, desl)
	vel = (pos - antes) / maxf(dt, 0.0001)
	_camera_adiantada(dt)
	_visual(dt, v)


func _livre(dt: float, v: Vector2, segurando: bool) -> Vector2:
	if combo_t > 0.0:
		combo_t -= dt
		if combo_t <= 0.0:
			proximo = 0
	andando = v != Vector2.ZERO
	correndo = false
	if esq_pedido > 0.0 and pode_esquivar():
		_iniciar_esquiva(v)
		return Vector2.ZERO
	if rup_pedido_t > 0.0 and pode_ruptura() and _segurando_ruptura():  # a ruptura vem antes do golpe: segurar o clique e apertar o direito carrega
		_iniciar_carga()
		return Vector2.ZERO
	if _quer_escudo():  # o escudo vem antes do golpe: segurar o direito e o clique esquerdo ergue o escudo, não golpeia
		return _escudo(dt, v)
	_baixar_escudo()
	if (pedido_t > 0.0 or segurando) and pausa_t <= 0.0:  # o golpe tem prioridade sobre a corrida
		if _iniciar_golpe():
			return Vector2.ZERO
	if not andando:
		return Vector2.ZERO
	if fonte == Fonte.ANDA:
		dir_olhar = v.normalized()
	var k := vel_andar()
	if cansado:
		k *= float(mundo.combate.cfg.folego.lento_cansado)
	elif _quer_correr() and folego > 0.0:
		correndo = true
		k = vel_correr()
		_gastar(float(mundo.combate.cfg.corrida.gasto) * dt)
		if cansado:  # o último fôlego acabou agora: para de correr na hora
			correndo = false
			k = vel_andar() * float(mundo.combate.cfg.folego.lento_cansado)
		else:
			_poeira_t -= dt
			if _poeira_t <= 0.0:
				_poeira_t = float(mundo.combate.cfg.corrida.poeira_cada)
				mundo.combate.poeira(self)
	return v * k * dt


## O botão do escudo (secundário) está segurado e o herói pode erguer? Polling, como o atacar. Em modo forçado (testes) vale `escudo_forcado`.
func _quer_escudo() -> bool:
	var c = mundo.combate
	if c.escudo == null or not c.escudo.ativo_para(str(chave)) or c.jogo != "jogando" or c.pausado or _pausa_aberta():
		return false
	var apertado: bool
	if entrada_forcada != null:
		apertado = escudo_forcado != null and bool(escudo_forcado)
	else:
		apertado = InputMap.has_action("escudo") and Input.is_action_pressed("escudo")
	if not apertado or cansado:
		return false
	# erguer pede um mínimo de fôlego; já erguido segue até zerar (o _gastar deixa cansado e o escudo cai)
	return escudo_ativo or folego >= float(c.escudo.cfg.folego_min)


## Um quadro com o escudo erguido: anda devagar (mira manda para onde olha), gasta fôlego e não corre nem golpeia.
func _escudo(dt: float, v: Vector2) -> Vector2:
	var esc = mundo.combate.escudo
	if not escudo_ativo:
		escudo_ativo = true
		escudo_t = 0.0
		if fonte == Fonte.ANDA and entrada_forcada == null:
			fonte = Fonte.MOUSE  # o escudo olha para a mira, não para onde anda
		esc.ergueu(self)
	else:
		escudo_t += dt
	pedido_t = 0.0  # um clique de golpe guardado não vaza para depois
	_gastar(float(esc.cfg.gasto) * dt)
	if cansado:  # o último fôlego acabou agora: o escudo cai na hora
		_baixar_escudo()
		return v * vel_andar() * float(mundo.combate.cfg.folego.lento_cansado) * dt
	if v == Vector2.ZERO:
		return Vector2.ZERO
	return v * vel_andar() * float(esc.cfg.mov) * dt


func _baixar_escudo() -> void:
	if not escudo_ativo:
		return
	escudo_ativo = false
	escudo_t = 0.0
	var esc = mundo.combate.escudo
	if esc != null:
		esc.abaixou(self)


func _quer_correr() -> bool:
	if entrada_forcada != null:
		return correr_forcado != null and bool(correr_forcado)
	return InputMap.has_action("correr") and Input.is_action_pressed("correr")


## Pode esquivar agora? (não cansado e com fôlego para um rolamento)
func pode_esquivar() -> bool:
	return not cansado and folego >= float(mundo.combate.cfg.esquiva.gasto)


## Gasta fôlego; zerar deixa cansado. Gastar adia a recuperação.
func _gastar(x: float) -> void:
	folego = maxf(0.0, folego - x)
	_atraso_t = float(mundo.combate.cfg.folego.atraso)
	if folego <= 0.001 and not cansado:
		cansado = true
		correndo = false
		_ofego_t = 1.3
		mundo.combate.cansou(self)


## Recuperação: espera o atraso depois do último gasto; parado volta mais rápido do que andando. Cansado sai do cansaço ao passar de 30%.
func _recuperar(dt: float, parado: bool) -> void:
	var f: Dictionary = mundo.combate.cfg.folego
	var teto_abate := float(f.get("abate_max_s", 0.0))
	if teto_abate > 0.0:
		_credito_abate = minf(teto_abate, _credito_abate + teto_abate * dt)
	if _atraso_t > 0.0:
		_atraso_t -= dt
	elif folego < folego_max:
		folego = minf(folego_max, folego + float(f.regen_parado if parado else f.regen_andando) * dt)
	if cansado:
		_ofego_t -= dt
		if _ofego_t <= 0.0:
			_ofego_t = 1.3
			mundo.combate.ofego(self)
		if folego >= float(f.cansado_ate) * folego_max:
			cansado = false


func _camera_adiantada(dt: float) -> void:
	var alvo := Vector2.ZERO
	if correndo and vel.length() > 1.0:
		alvo = vel.normalized() * float(mundo.combate.cfg.corrida.avanco_camera)
	avanco_camera = avanco_camera.lerp(alvo, 1.0 - exp(-3.5 * dt))


# ------------------------------------------------------------------ golpe


func _iniciar_golpe() -> bool:
	var dif := preload("res://v2/dificuldade.gd").da_partida(mundo)
	var custo := float(dif.golpe_custo)
	if custo > 0.0:
		if golpe_calor_t > 0.0:
			return false
		if folego <= 0.0:
			golpe_calor_t = float(dif.golpe_calor)
			return false
		_gastar(custo)
		if folego <= 0.0:
			golpe_calor_t = float(dif.golpe_calor)
	var passos: Array = mundo.combate.cfg.golpe.passos
	golpe_i = proximo if (combo_t > 0.0 and proximo < passos.size()) else 0
	golpe_cfg = passos[golpe_i]
	golpe_dur = duracao_do_passo(golpe_i)
	golpe_t = 0.0
	golpe_acertou = false
	pedido_t = 0.0
	var d: Vector2 = mira_mundo - centro()
	golpe_dir = d.normalized() if d.length() > 2.0 else dir_olhar
	dir_olhar = golpe_dir
	estado = Estado.GOLPE
	golpes += 1
	_punch = 0.0
	mundo.combate.golpe_comecou(self, golpe_cfg, golpe_dir, golpe_dur)
	return true


## A fase do golpe da katana agora (docs/combate_v2): "pronto" fora do golpe, "preparo" antes do quadro do acerto (sem dano), "ativo" no
## quadro do acerto (combate.golpear, uma vez por golpe) e "recuperacao" depois dele, até o fim do golpe (a esquiva pode cancelar aqui).
func fase_golpe() -> String:
	if estado != Estado.GOLPE:
		return "pronto"
	if not golpe_acertou:
		return "preparo"
	return "ativo" if golpe_t <= golpe_dur * float(golpe_cfg.acerto_em) + 1.0 / 60.0 else "recuperacao"


func _golpe(dt: float, v: Vector2) -> Vector2:
	golpe_t += dt
	var p := golpe_t / golpe_dur
	var acerto := float(golpe_cfg.acerto_em)
	# cancela o fim do golpe com a esquiva
	if esq_pedido > 0.0 and p >= acerto and pode_esquivar():
		_encerrar_golpe(false)
		_iniciar_esquiva(v)
		return Vector2.ZERO
	var desl := Vector2.ZERO
	var t_av := golpe_dur * acerto
	if golpe_t < t_av:  # lunge: velocidade que cai linearmente até zero, a integral dá exatamente "avanco" px
		desl += golpe_dir * float(golpe_cfg.get("avanco", 0.0)) * 2.0 * (1.0 - golpe_t / t_av) / t_av * dt
	if v != Vector2.ZERO:
		desl += v * vel_base * m_vel_mov * float(mundo.combate.cfg.heroi.mov_golpe) * dt
	if not golpe_acertou and p >= acerto:
		golpe_acertou = true
		_punch = 1.0
		mundo.combate.golpear(self, pos + ORIGEM_GOLPE, golpe_dir, golpe_cfg, golpe_i)
	# a ruptura pedida depois do acerto cancela o resto do golpe e carrega na hora (o mesmo padrão da esquiva)
	if rup_pedido_t > 0.0 and _rup_apos_acerto and pode_ruptura() and _segurando_ruptura():
		_encerrar_golpe(false)
		_iniciar_carga()
		return Vector2.ZERO
	if p >= 1.0:
		_encerrar_golpe(true)
	return desl


func _encerrar_golpe(natural: bool) -> void:
	var passos: Array = mundo.combate.cfg.golpe.passos
	estado = Estado.LIVRE
	if golpe_i + 1 < passos.size():
		proximo = golpe_i + 1
		combo_t = float(mundo.combate.cfg.golpe.janela_combo)
	else:
		proximo = 0
		combo_t = 0.0
		if natural:
			pausa_t = float(mundo.combate.cfg.golpe.pausa_fim_combo)


# ------------------------------------------------------------------ esquiva


func _iniciar_esquiva(v: Vector2) -> void:
	var cfg: Dictionary = mundo.combate.cfg.esquiva
	_gastar(float(cfg.gasto))
	esq_pedido = 0.0
	pedido_t = 0.0
	esq_t = 0.0
	estado = Estado.ESQUIVA
	esquivas += 1
	if v != Vector2.ZERO:
		esq_dir = v.normalized()
	else:
		var d: Vector2 = mira_mundo - centro()
		esq_dir = d.normalized() if d.length() > 2.0 else dir_olhar
	dir_olhar = esq_dir
	_esq_rastro = 0.0
	combo_t = 0.0
	proximo = 0
	mundo.combate.esquiva_comecou(self)


func _esquiva(dt: float) -> Vector2:
	esq_t += dt
	var p := esq_t / esq_dur
	_esq_rastro -= dt
	if _esq_rastro <= 0.0:
		_esq_rastro = 0.055
		mundo.combate.rastro_esquiva(self)
	if esq_t >= esq_dur:
		estado = Estado.LIVRE
		return esq_dir * vel_base * m_vel_mov * float(mundo.combate.cfg.esquiva.velocidade) * 0.25 * dt
	# arranca rápido e desacelera no fim (o rolamento "agarra" o chão)
	var k := 1.35 - 0.7 * p
	return esq_dir * vel_base * m_vel_mov * float(mundo.combate.cfg.esquiva.velocidade) * k * dt


# ------------------------------------------------------------------ ruptura (tecla E)


## Pode começar a carga agora? Só com o jogo rolando (nada de escolha, baú, morte, vitória, resultado nem pausa), recarga zerada e livre
## ou depois do acerto de um golpe. Esquiva e morto não iniciam.
func pode_ruptura() -> bool:
	var c = mundo.combate
	return (
		c.ruptura != null
		and rup_recarga <= 0.0
		and c.jogo == "jogando"
		and not c.pausado
		and not _pausa_aberta()
		and (estado == Estado.LIVRE or estado == Estado.GOLPE)
	)


## O menu de pausa (ESC) está aberto sobre a partida? Com ele aberto nada da ruptura começa nem continua.
func _pausa_aberta() -> bool:
	return mundo.pausa != null and mundo.pausa.aberto


## O botão da ruptura está segurado? Polling, como o atacar. Em modo forçado (testes e fotos) vale `ruptura_forcada`.
func _segurando_ruptura() -> bool:
	if entrada_forcada != null:
		return ruptura_forcada != null and bool(ruptura_forcada)
	return InputMap.has_action("ruptura") and Input.is_action_pressed("ruptura")


## Relógios da ruptura, no tempo do mundo (hit-stop e pausa congelam). Quando a recarga zera, avisa uma vez.
func _rup_relogios(dt: float) -> void:
	rup_pedido_t = maxf(0.0, rup_pedido_t - dt)
	rup_nega_t = maxf(0.0, rup_nega_t - dt)
	contragolpe_t = maxf(0.0, contragolpe_t - dt)
	if rup_recarga > 0.0:
		rup_recarga = maxf(0.0, rup_recarga - dt)
		if rup_recarga <= 0.0:
			mundo.combate.ruptura.pronta(self)


## Relógios da E (a que não é a ruptura), no tempo do mundo (hit-stop e pausa congelam). Quando a recarga zera, avisa uma vez.
func _hab_relogios(dt: float) -> void:
	hab_nega_t = maxf(0.0, hab_nega_t - dt)
	if hab_recarga > 0.0 and estado != Estado.HABILIDADE:  # a recarga só corre depois da E (durante ela fica cheia)
		hab_recarga = maxf(0.0, hab_recarga - dt)
		if hab_recarga <= 0.0:
			mundo.combate.habilidade.pronta(self)


func _iniciar_carga() -> void:
	estado = Estado.CARGA
	rup_carga = 0.0
	rup_carga_t = 0.0
	rup_perfeita = false
	rup_pedido_t = 0.0
	_rup_apos_acerto = false
	pedido_t = 0.0
	combo_t = 0.0
	proximo = 0
	_rup_tique = 0
	_rup_us = Time.get_ticks_usec()


func _carga(dt: float, v: Vector2) -> Vector2:
	var c = mundo.combate
	var rp = c.ruptura
	var agora := Time.get_ticks_usec()
	# fora de partida, em pausa ou com o relógio saltando (ESC e perda de foco não passam por combate.pausado): cancela sem disparar
	if c.jogo != "jogando" or c.pausado or _pausa_aberta() or float(agora - _rup_us) / 1.0e6 > float(rp.cfg.salto_relogio):
		cancelar_ruptura(false)
		return Vector2.ZERO
	_rup_us = agora
	if esq_pedido > 0.0 and pode_esquivar():  # a esquiva é a saída da carga: cancela de graça e rola (cansado, a carga continua)
		cancelar_ruptura(false)
		_iniciar_esquiva(v)
		return Vector2.ZERO
	rup_carga_t += dt
	var cm: float = rp.carga_max(self)
	rup_carga = clampf(rup_carga_t / cm, 0.0, 1.0)
	rup_perfeita = rup_carga_t >= cm and rup_carga_t <= cm + float(rp.cfg.perfeito.janela)  # janela fixa em s: não encolhe com a velocidade de ataque
	var tiques: Array = rp.cfg.tiques
	while _rup_tique < tiques.size() and rup_carga >= float(tiques[_rup_tique]):
		rp.tique(self, _rup_tique)
		_rup_tique += 1
	if not _segurando_ruptura():
		_soltar()
		return Vector2.ZERO
	andando = v != Vector2.ZERO
	if not andando:
		return Vector2.ZERO
	if fonte == Fonte.ANDA:
		dir_olhar = v.normalized()
	return v * VEL * m_vel_mov * float(rp.cfg.mov_carga) * dt  # a 45%, também cansado, sem somar com o cansaço


## Soltou o botão: carga curta cancela (sem recarga); senão dispara com o f e o perfeito deste instante.
func _soltar() -> void:
	var rp = mundo.combate.ruptura
	if rup_carga_t < float(rp.cfg.carga_min):
		cancelar_ruptura(true)
		return
	var f := rup_carga
	var perfeito := rup_perfeita
	estado = Estado.LIVRE
	rup_carga = 0.0
	rup_carga_t = 0.0
	rup_perfeita = false
	rup_disparos += 1
	rp.disparar(self, f, perfeito)
	pausa_t = maxf(pausa_t, float(rp.cfg.pausa_pos))  # só impede o golpe, não impede andar
	_rup_punch = 1.0


## Desfaz a carga sem disparar e sem gastar recarga. Idempotente; `som` = toca o ruptura_cancela. Público: o combate chama na pausa.
func cancelar_ruptura(som := true) -> void:
	if estado != Estado.CARGA:
		return
	var rp = mundo.combate.ruptura
	if rp != null:
		rp.cancelou(self, som)
	estado = Estado.LIVRE
	rup_carga = 0.0
	rup_carga_t = 0.0
	rup_perfeita = false
	rup_pedido_t = 0.0
	rup_cancelados += 1


# ------------------------------------------------------------------ visual


func _visual(dt: float, v: Vector2) -> void:
	var l := linha_de(dir_olhar)
	var c := 0
	if estado == Estado.LIVRE and andando:
		_anim += dt * (1.45 if correndo else 1.0)
		var passo := PASSO_ANIM
		if _tem_anim("andar"):  # o tempo do andar vem da folha (animacoes.andar.s_por_quadro), então ajusta pelo JSON
			passo = float(tipo.info.animacoes.andar.get("s_por_quadro", PASSO_ANIM))
		c = 1 + int(_anim / passo) % (int(tipo.info.colunas.size()) - 1)
	else:
		_anim = 0.0
	var ca := _coluna_acao(dt)
	if ca >= 0:
		c = ca
	if l != linha or c != coluna:
		quadro(c, l)
	# corpo: o "soco" do golpe (esticada na direção do corte), o giro da esquiva e o pisca de quem acabou de apanhar
	var punch_k := 0.0
	if _punch > 0.0:
		_punch = maxf(0.0, _punch - dt / 0.16)
		punch_k = _punch
	var desloca := Vector2.ZERO
	var esc := Vector2.ONE
	if estado == Estado.GOLPE:
		var ant := clampf(golpe_t / (golpe_dur * float(golpe_cfg.acerto_em)), 0.0, 1.0)
		desloca = (golpe_dir * (-2.0 * (1.0 - ant) + 3.0 * punch_k)).round()  # puxa para trás e solta
		esc = Vector2(1.0 + 0.1 * punch_k, 1.0 - 0.07 * punch_k)
	elif estado == Estado.CARGA:  # agacha, treme um pixel na carga cheia
		esc = Vector2(1.0 + 0.05 * rup_carga, 1.0 - 0.09 * rup_carga)
		if rup_carga >= 1.0:
			desloca = Vector2(float(int(Time.get_ticks_msec() / 40.0) % 3 - 1), 0.0)
	if _rup_punch > 0.0:  # o soco do disparo: alarga e achata um instante
		_rup_punch = maxf(0.0, _rup_punch - dt / 0.12)
		esc = Vector2(lerpf(esc.x, 1.14, _rup_punch), lerpf(esc.y, 0.88, _rup_punch))
	if estado == Estado.ESQUIVA and _tem_anim("rolamento"):
		sprite.position = Vector2.ZERO  # o rolamento já está desenhado na folha: sem girar o sprite
		sprite.offset = _off_base
		sprite.rotation = 0.0
	elif estado == Estado.ESQUIVA:
		var p := clampf(esq_t / esq_dur, 0.0, 1.0)
		var gira := signf(esq_dir.x) if absf(esq_dir.x) > 0.1 else 1.0
		sprite.position = Vector2(0, -14)
		sprite.offset = _off_base + Vector2(0, 14)
		sprite.rotation = gira * TAU * minf(p * 1.15, 1.0)
		esc = Vector2(1.0, 0.82)
	else:
		if sprite.rotation != 0.0:
			sprite.rotation = 0.0
			sprite.offset = _off_base
		sprite.position = desloca
	sprite.scale = esc
	var piscando := invenc > 0.0 and int(Time.get_ticks_msec() / 1000.0 * float(mundo.combate.cfg.heroi.pisca_hz) * 2.0) % 2 == 0
	if estado == Estado.ESQUIVA:
		sprite.modulate = Color(1, 1, 1, 0.78)
	elif estado == Estado.ESPECIAL:
		sprite.modulate = Color.WHITE.lerp(esp_cor, 0.45)  # o corpo toma a cor do especial
	elif estado == Estado.HABILIDADE:
		sprite.modulate = Color.WHITE.lerp(hab_cor, 0.4)  # o corpo toma a cor da E
	elif piscando:
		sprite.modulate = Color(1, 0.55, 0.55, 0.38)
	elif estado == Estado.CARGA:
		sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.85, 0.65), rup_carga)  # o corpo esquenta com a carga
	else:
		sprite.modulate = Color.WHITE


## Gancho do visual da morte: põe o shader de dissolução no corpo (só agora, então o herói vivo não paga nada por ele).
func _iniciar_morte() -> void:
	morte_t = 0.0
	if _mat_morte == null:
		var sh := Shader.new()
		sh.code = SHADER_MORTE
		_mat_morte = ShaderMaterial.new()
		_mat_morte.shader = sh
	_mat_morte.set_shader_parameter("dissolver", 0.0)
	_mat_morte.set_shader_parameter("branco", 1.0)
	if not _tem_anim("morte"):  # com a queda do Blender o material só entra no fim dela (_visual_morto)
		sprite.material = _mat_morte


## Segundos reais da morte inteira: a queda do Blender (até o quadro de repouso, se a folha tem) mais a dissolução.
func duracao_morte() -> float:
	return (_duracao_anim("morte", true) if _tem_anim("morte") else 0.0) + MORTE_DISSOLVE


## Progresso 0..1 da dissolução do corpo (relógio de jogo, sem TIME).
func morte_k() -> float:
	return clampf(morte_t / MORTE_DISSOLVE, 0.0, 1.0)


func _visual_morto(dt: float) -> void:
	var anim := _tem_anim("morte")  # a queda do Blender (deitada de lado) toca primeiro; o dissolve entra quando ela chega ao quadro de repouso
	var c_lenta := 1.0
	if anim:
		c_lenta = maxf(mundo.combate.lento_escala if mundo.combate.lento_t > 0.0 else 1.0, 0.05)
		_morte_t += dt / c_lenta  # a câmera lenta da morte (0,25x por 1,3 s) não pode comer a animação: conta em tempo real
		var c := _coluna_por_tempo("morte", _morte_t)
		if c != coluna or linha_de(dir_olhar) != linha:
			quadro(c, linha_de(dir_olhar))
		sprite.rotation = 0.0
		sprite.position = Vector2.ZERO
		sprite.offset = _off_base
		sprite.scale = Vector2.ONE
		sprite.modulate = Color(1, 0.8, 0.8, 0.85)
		if _morte_t < _duracao_anim("morte", true):
			return
	morte_t += dt / c_lenta  # com a queda do Blender o dissolve também conta em tempo real (a tela de resultado não corta ele)
	var k := morte_k()
	if _mat_morte != null:
		if sprite.material != _mat_morte:
			sprite.material = _mat_morte
		_mat_morte.set_shader_parameter("dissolver", k)
		_mat_morte.set_shader_parameter("branco", clampf(1.0 - k / MORTE_FLASH, 0.0, 1.0))
	if anim:
		return
	sprite.position = Vector2(0, -14)
	sprite.offset = _off_base + Vector2(0, 14)
	sprite.rotation = lerpf(sprite.rotation, 1.45 * (1.0 if dir_olhar.x >= 0 else -1.0), 1.0 - exp(-9.0 * dt))
	sprite.scale = Vector2.ONE
	sprite.modulate = Color(1, 0.8, 0.8, 0.85)


## A folha tem a animação `nome` (as folhas de 50 colunas do Blender trazem "animacoes" no json; as antigas só andar)?
func _tem_anim(nome: String) -> bool:
	var a: Variant = tipo.info.get("animacoes", null)
	return a is Dictionary and (a as Dictionary).has(nome)


## Duração total (s) da animação `nome`, pelos tempos s_quadros da folha (ou s_por_quadro); `sem_ultimo` tira o quadro final (a pose que fica).
func _duracao_anim(nome: String, sem_ultimo := false) -> float:
	var a: Dictionary = tipo.info.animacoes[nome]
	var dur: Array = a.get("s_quadros", [])
	var tot := 0.0
	for i in (a.colunas as Array).size() - (1 if sem_ultimo else 0):
		tot += float(dur[i]) if i < dur.size() else float(a.get("s_por_quadro", 0.1))
	return tot


## A coluna do quadro `i` da animação `nome` (limitado ao último).
func _coluna_anim(nome: String, i: int) -> int:
	var cols: Array = tipo.info.animacoes[nome].colunas
	return int(cols[clampi(i, 0, cols.size() - 1)])


## A coluna da animação `nome` depois de `t` segundos, pelos tempos s_quadros da folha (ou s_por_quadro); trava no último quadro.
func _coluna_por_tempo(nome: String, t: float) -> int:
	var a: Dictionary = tipo.info.animacoes[nome]
	var n := (a.colunas as Array).size()
	var dur: Array = a.get("s_quadros", [])
	var acum := 0.0
	for i in n:
		acum += float(dur[i]) if i < dur.size() else float(a.get("s_por_quadro", 0.1))
		if t < acum:
			return _coluna_anim(nome, i)
	return _coluna_anim(nome, n - 1)


## Coluna da ação em andamento (golpe, rolamento, escudo, dano), ou -1 para seguir parado/andar. Só com a folha nova.
func _coluna_acao(dt: float) -> int:
	if _dano_t >= 0.0:
		_dano_t += dt
		if _tem_anim("dano") and estado != Estado.ESQUIVA:
			var dur := 0.0
			for x in tipo.info.animacoes.dano.get("s_quadros", [0.08]):
				dur += float(x)
			if _dano_t < dur:
				return _coluna_por_tempo("dano", _dano_t)
		if _dano_t >= 0.5:
			_dano_t = -1.0
	if estado == Estado.GOLPE and _tem_anim("combo"):
		var por_golpe := maxi(int(tipo.info.animacoes.combo.get("quadros_por_golpe", 6)), 1)
		var passo := mini(golpe_i, maxi(int(tipo.info.animacoes.combo.get("golpes", 3)) - 1, 0))
		var p := clampf(golpe_t / maxf(golpe_dur, 0.001), 0.0, 0.999)
		return _coluna_anim("combo", passo * por_golpe + int(p * por_golpe))
	if estado == Estado.ESQUIVA and _tem_anim("rolamento"):
		var n := (tipo.info.animacoes.rolamento.colunas as Array).size()
		return _coluna_anim("rolamento", int(clampf(esq_t / maxf(esq_dur, 0.001), 0.0, 0.999) * n))
	if estado == Estado.ESPECIAL and _tem_anim("combo"):  # o especial toca um passo do combo (esp_anim_passo), repetido esp_anim_ciclos vezes
		var por_golpe := maxi(int(tipo.info.animacoes.combo.get("quadros_por_golpe", 6)), 1)
		var passo := mini(esp_anim_passo, maxi(int(tipo.info.animacoes.combo.get("golpes", 3)) - 1, 0))
		var p := fposmod(esp_t / maxf(esp_dur, 0.001) * esp_anim_ciclos, 0.999)
		return _coluna_anim("combo", passo * por_golpe + int(p * por_golpe))
	if estado == Estado.HABILIDADE and _tem_anim("combo"):  # a E toca um passo do combo (hab_anim_passo), repetido hab_anim_ciclos vezes
		var por_golpe_h := maxi(int(tipo.info.animacoes.combo.get("quadros_por_golpe", 6)), 1)
		var passo_h := mini(hab_anim_passo, maxi(int(tipo.info.animacoes.combo.get("golpes", 3)) - 1, 0))
		var p_h := fposmod(hab_t / maxf(hab_dur, 0.001) * hab_anim_ciclos, 0.999)
		return _coluna_anim("combo", passo_h * por_golpe_h + int(p_h * por_golpe_h))
	if escudo_ativo and estado == Estado.LIVRE and _tem_anim("escudo"):
		return _coluna_por_tempo("escudo", escudo_t)
	return -1


## Linhas da folha: baixo, esquerda, direita, cima, baixo_esq, baixo_dir, cima_esq, cima_dir. As 8 direções saem do ângulo na tela.
static func linha_de(v: Vector2) -> int:
	const POR_OITANTE := [2, 5, 0, 4, 1, 6, 3, 7]  # 0 = direita, 1 = baixo-direita, 2 = baixo... (y para baixo, sentido horário)
	var oitante := posmod(int(round(v.angle() / (PI / 4.0))), 8)
	return POR_OITANTE[oitante]

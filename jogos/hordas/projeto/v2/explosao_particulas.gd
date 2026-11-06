extends RefCounted
## As PARTÍCULAS da explosão do mecha (Q do LightWolf, "Colapso da Matriz", rodada 7, pedido do Alisson: "queria partículas ... no ult"). Só desenho, chamado por
## v2/explosao_mecha.gd (explodir / atualizar / limpar / desenhar_*): nenhum nó próprio, um POOL FIXO (MAX vagas em PackedArrays, como v2/misseis_rastro.gd), nada de alfa
## parcial (cada partícula vive em DEGRAUS de tamanho e cor e some inteira), posição inteira na tela, sem giro livre (o "giro" dos pedaços de casco é a troca entre
## FORMAS_CASCO, 4 formas fixas de 3x3 px). Sem `randf`: cada partícula sorteia pelo hash fixo `_h(i, semente, campo)` (semente = o número da explosão), então a sequência
## do RNG da partida não muda.
## Tipos (contagens em dados/v2_especial.json > autodestruicao.explosao.particulas; tempos em s do MUNDO, o relógio é mundo / 1,25):
##  - DETRITO: pedaços de terra (TERRA/BURACO) e de blindagem do mecha (FUMACA, girando por forma) lançados da base em 16 direções quantizadas, com gravidade no
##    eixo da altura, 1 quique e depois param e encolhem 3 -> 2 -> 1 px.
##  - FAISCA: âmbar de 1 a 2 px (a mesma cor do míssil, para ligar as duas coisas), metade sobe e metade sai rasante, rastro de 2 pontos; âmbar claro -> laranja -> cinza.
##  - BRASA: pontos de 1 px que sobem devagar da cratera e da bola, em ciano (BRASA) ou âmbar, 3 degraus de cor.
##  - FUMACA: blobs de 14/10/6/3 px (discos pixel com pontilhado no lugar de alfa) que sobem e encolhem em degraus, furando antes de sumir. Atrás da bola.
##  - CALOR: pontos de 2 px no chão que acendem quando a onda passa e apagam em 3 degraus (ciano -> azul -> azul escuro). No nó do chão.
## "Reduzir piscadas" (calmo): faíscas e brasas de UMA cor (âmbar médio), sem rastro e sem trocar de tamanho, os pontos de calor de um azul só, os pedaços de casco sem
## trocar de forma e só 1 degrau de tamanho (3 -> 2 px); a fumaça só desce de claro para escuro, em 2 degraus. Nenhum estado dura menos de ~0,24 s de relógio.
## Perfil Baixo: explosao_mecha não chama `emitir` (zero partículas). A sucção do fim do fusível (`desenhar_succao`) é estática e fica em qualquer perfil (4 pontos no Baixo).

const MAX := 128
const LIVRE := 255
const DETRITO := 0
const FAISCA := 1
const BRASA_T := 2
const FUMACA_T := 3
const CALOR := 4
const ACHATA := 0.62
const GRAVIDADE := 700.0  # px/s² no eixo da altura (detritos)
const GRAV_FAISCA := 480.0
const DIRECOES := 16

const AMBAR_CLARO := Color(1.0, 0.78, 0.38)
const LARANJA := Color(1.0, 0.5, 0.1)
const CINZA_ESC := Color(0.3, 0.28, 0.34)
const AMBAR_MEDIO := Color(1.0, 0.64, 0.24)  # calmo: a cor única das faíscas e brasas
const BRANCO := Color(1.0, 1.0, 1.0)
const CIANO_CLARO := Color(0.78, 0.96, 1.0)
const CIANO := Color(0.4, 0.8, 1.0)
const AZUL := Color(0.18, 0.42, 0.9)
const AZUL_ESC := Color(0.08, 0.14, 0.4)
const FUMACA := Color(0.3, 0.33, 0.4)
const FUMACA_ESC := Color(0.16, 0.17, 0.22)
const TERRA := Color(0.36, 0.3, 0.25)
const BURACO := Color(0.1, 0.09, 0.1)
const BRASA := Color(0.5, 0.88, 1.0)
const FUMO_DIAM := [14, 10, 6, 3]  # os degraus de tamanho do blob de fumaça
const FORMAS_CASCO := [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)],
	[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
	[Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
]
const CASCO_GIRO := 0.07  # s do mundo entre duas formas do pedaço de casco (o "giro" quantizado)

static var _blobs := {}  # [diâmetro * 4 + variante] -> Texture2D: os discos de fumaça, desenhados uma vez por sessão

var tipo := PackedByteArray()
var x := PackedFloat32Array()
var y := PackedFloat32Array()
var z := PackedFloat32Array()  # altura acima do chão (px; a tela mostra y - z)
var vx := PackedFloat32Array()
var vy := PackedFloat32Array()
var vz := PackedFloat32Array()
var idade := PackedFloat32Array()  # < 0 = ainda não nasceu (atraso)
var vida := PackedFloat32Array()
var vari := PackedByteArray()  # variante: cor, forma, tamanho
var quicou := PackedByteArray()

var n_detritos := 18
var n_faiscas := 32
var n_brasas := 14
var n_fumaca := 12
var n_calor := 24
var n_succao := 16
var calmo := false
var emitidas := 0  # testes: quantas nasceram desde o último `limpar`


func montar(cfg: Dictionary) -> void:
	n_detritos = clampi(int(cfg.get("detritos", n_detritos)), 0, 32)
	n_faiscas = clampi(int(cfg.get("faiscas", n_faiscas)), 0, 48)
	n_brasas = clampi(int(cfg.get("brasas", n_brasas)), 0, 20)
	n_fumaca = clampi(int(cfg.get("fumaca", n_fumaca)), 0, 16)
	n_calor = clampi(int(cfg.get("calor", n_calor)), 0, 32)
	n_succao = clampi(int(cfg.get("succao", n_succao)), 4, 32)
	for a in [tipo, vari, quicou]:
		a.resize(MAX)
	for a in [x, y, z, vx, vy, vz, idade, vida]:
		a.resize(MAX)
	limpar()


func limpar() -> void:
	tipo.fill(LIVRE)
	emitidas = 0


## Quantas vagas estão ocupadas agora (testes; o teto é MAX).
func vivas() -> int:
	var n := 0
	for i in MAX:
		if tipo[i] != LIVRE:
			n += 1
	return n


## Um número fixo em [0, 1) para (i, semente, campo): o "RNG" do efeito (não mexe no RNG da partida).
static func _h(i: int, s: int, c: int) -> float:
	var v := (i * 73856093) ^ (s * 19349663) ^ (c * 83492791)
	v = (v ^ (v >> 13)) * 1274126177
	return float((v ^ (v >> 16)) & 0xFFFF) / 65536.0


## Todas as partículas de uma explosão em `centro` (o chão onde o mecha ficou), de uma vez, com atraso próprio. Uma explosão por vez: a nova reaproveita o pool.
## `raio_bola` em px; `vel_onda` e `onda_max` dão quando a onda do chão passa por cada ponto de calor.
func emitir(centro: Vector2, semente: int, eh_calmo: bool, raio_bola: float, vel_onda: float, onda_max: float) -> void:
	limpar()
	calmo = eh_calmo
	var s := semente
	for i in n_detritos:
		var a := _quantiza(TAU * (float(i) + _h(i, s, 1) * 0.8) / float(maxi(n_detritos, 1)))
		var v := lerpf(120.0, 320.0, _h(i, s, 2))
		_nova(
			DETRITO,
			centro + Vector2(cos(a), sin(a) * ACHATA) * 8.0,
			Vector3(cos(a) * v, sin(a) * v * ACHATA, lerpf(90.0, 230.0, _h(i, s, 3))),
			lerpf(6.0, 14.0, _h(i, s, 4)),
			0.0,
			lerpf(0.6, 1.1, _h(i, s, 5)),
			1 if i % 5 == 0 else (2 if _h(i, s, 6) < 0.35 else 0)
		)
	for i in n_faiscas:
		var a := _quantiza(TAU * _h(i, s, 11))
		var v := lerpf(200.0, 420.0, _h(i, s, 12))
		var sobe := i % 2 == 0
		var p := centro + Vector2(cos(a), sin(a) * ACHATA) * 6.0
		_nova(
			FAISCA,
			p,
			Vector3(cos(a) * v, sin(a) * v * ACHATA, lerpf(120.0, 280.0, _h(i, s, 13)) if sobe else 20.0),
			6.0 if sobe else 2.0,
			-_h(i, s, 14) * 0.08,
			lerpf(0.3, 0.7, _h(i, s, 15)),
			1 if i % 3 == 0 else 0
		)
	for i in n_brasas:
		var p := centro + Vector2((_h(i, s, 21) - 0.5) * raio_bola * 1.1, (_h(i, s, 22) - 0.5) * 18.0)
		_nova(
			BRASA_T,
			p,
			Vector3(0, 0, lerpf(25.0, 50.0, _h(i, s, 23))),
			lerpf(4.0, 30.0, _h(i, s, 24)),
			-lerpf(0.25, 0.9, _h(i, s, 25)),
			lerpf(0.75, 1.6, _h(i, s, 26)),
			i % 2
		)
	for i in n_fumaca:
		var p := centro + Vector2((_h(i, s, 31) - 0.5) * raio_bola * 1.4, 0.0)
		var alt := 14.0 + raio_bola * lerpf(0.2, 0.75, _h(i, s, 32))
		_nova(FUMACA_T, p, Vector3(0, 0, lerpf(14.0, 30.0, _h(i, s, 33))), alt, -lerpf(0.42, 0.95, _h(i, s, 34)), lerpf(1.0, 1.9, _h(i, s, 35)), i % 3)
	var alcance := minf(onda_max, 320.0)
	for i in n_calor:
		var a := TAU * (float(i) + _h(i, s, 41)) / float(maxi(n_calor, 1))
		var r := alcance * lerpf(0.18, 0.85, _h(i, s, 42))
		var p := centro + Vector2(cos(a) * r, sin(a) * r * ACHATA)
		_nova(CALOR, p, Vector3.ZERO, 0.0, -r / maxf(vel_onda, 1.0), 0.5, 0)


func _quantiza(a: float) -> float:
	var passo := TAU / float(DIRECOES)
	return roundf(a / passo) * passo


func _nova(t: int, p: Vector2, v: Vector3, alt: float, idade0: float, dur: float, variante: int) -> void:
	for i in MAX:
		if tipo[i] == LIVRE:
			tipo[i] = t
			x[i] = p.x
			y[i] = p.y
			z[i] = alt
			vx[i] = v.x
			vy[i] = v.y
			vz[i] = v.z
			idade[i] = idade0
			vida[i] = dur
			vari[i] = variante
			quicou[i] = 0
			emitidas += 1
			return


## Um passo do MUNDO (respeita pausa e hit-stop: quem chama é o explosao_mecha.atualizar).
func atualizar(dt: float) -> void:
	for i in MAX:
		var t := tipo[i]
		if t == LIVRE:
			continue
		idade[i] += dt
		if idade[i] < 0.0:
			continue
		if idade[i] >= vida[i]:
			tipo[i] = LIVRE
			continue
		var passo := minf(dt, idade[i])
		match t:
			DETRITO:
				x[i] += vx[i] * passo
				y[i] += vy[i] * passo
				z[i] += vz[i] * passo
				vz[i] -= GRAVIDADE * passo
				if z[i] <= 0.0:
					z[i] = 0.0
					if quicou[i] == 0:
						quicou[i] = 1
						vz[i] = -vz[i] * 0.35
						vx[i] *= 0.5
						vy[i] *= 0.5
					else:
						vz[i] = 0.0
						vx[i] = 0.0
						vy[i] = 0.0
			FAISCA:
				x[i] += vx[i] * passo
				y[i] += vy[i] * passo
				z[i] += vz[i] * passo
				vz[i] -= GRAV_FAISCA * passo
				if z[i] < 0.0:  # no chão: segue rasante, freando, até a vida acabar
					z[i] = 0.0
					vz[i] = 0.0
					vx[i] *= 1.0 - minf(1.0, 2.5 * passo)
					vy[i] *= 1.0 - minf(1.0, 2.5 * passo)
			BRASA_T, FUMACA_T:
				z[i] += vz[i] * passo


## Fração da vida (0..1).
func _f(i: int) -> float:
	return clampf(idade[i] / maxf(vida[i], 0.001), 0.0, 0.999)


func _tela(i: int) -> Vector2:
	return Vector2(roundf(x[i]), roundf(y[i] - z[i]))


## A fumaça: atrás da bola (o explosao_mecha chama antes de desenhar o quadro da bola).
func desenhar_fundo(no: CanvasItem) -> void:
	for i in MAX:
		if tipo[i] != FUMACA_T or idade[i] < 0.0:
			continue
		var f := _f(i)
		var tex := blob(FUMO_DIAM[degrau_fumaca(i)], vari[i])
		var p := _tela(i) + Vector2(0, -roundf(f * 6.0))
		no.draw_texture(tex, p - Vector2(tex.get_width() / 2, tex.get_height() / 2))


## O degrau de tamanho do blob de fumaça `i` (índice em FUMO_DIAM). Calmo: só dois degraus (14 e 6 px) na metade da vida, cada um >= 0,4 s de relógio.
func degrau_fumaca(i: int) -> int:
	var f := _f(i)
	if calmo:
		return 0 if f < 0.5 else 2
	return 0 if f < 0.4 else (1 if f < 0.65 else (2 if f < 0.85 else 3))


## O lado (px) do detrito `i`. Normal: 3 -> 2 -> 1. Calmo: 3 -> 2 uma vez só, na metade da vida (cada lado dura >= 0,24 s de relógio).
func lado_detrito(i: int) -> int:
	var f := _f(i)
	if calmo:
		return 3 if f < 0.5 else 2
	return 3 if f < 0.55 else (2 if f < 0.8 else 1)


## O lado (px) da faísca `i`. Normal: as de variante 1 têm 2 px na 1ª metade. Calmo: sempre 1 px (nada troca de tamanho).
func lado_faisca(i: int) -> int:
	return 2 if vari[i] == 1 and not calmo and _f(i) < 0.5 else 1


## A cor do ponto de calor `i`. Normal: ciano -> azul -> azul escuro. Calmo: um azul só.
func cor_calor(i: int) -> Color:
	if calmo:
		return AZUL
	var f := _f(i)
	return CIANO if f < 0.33 else (AZUL if f < 0.66 else AZUL_ESC)


## Detritos, faíscas e brasas: por cima da bola.
func desenhar_frente(no: CanvasItem) -> void:
	for i in MAX:
		var t := tipo[i]
		if t == LIVRE or t == FUMACA_T or t == CALOR or idade[i] < 0.0:
			continue
		var f := _f(i)
		var p := _tela(i)
		match t:
			DETRITO:
				var lado := lado_detrito(i)
				if vari[i] == 1 and lado == 3:  # pedaço de casco: gira trocando de forma (calmo: uma forma só)
					var forma: Array = FORMAS_CASCO[0 if calmo or quicou[i] == 1 and vz[i] == 0.0 else int(idade[i] / CASCO_GIRO) % 4]
					for q in forma:
						no.draw_rect(Rect2(p + Vector2(q) - Vector2(1, 1), Vector2.ONE), FUMACA if q.y < 2 else AZUL_ESC)
				else:
					var cor := FUMACA if vari[i] == 1 else (BURACO if vari[i] == 2 else TERRA)
					no.draw_rect(Rect2(p - Vector2(lado / 2, lado / 2), Vector2(lado, lado)), cor)
			FAISCA:
				var cor := AMBAR_MEDIO if calmo else (AMBAR_CLARO if f < 0.35 else (LARANJA if f < 0.7 else CINZA_ESC))
				var lado := lado_faisca(i)
				no.draw_rect(Rect2(p, Vector2(lado, lado)), cor)
				if not calmo and f < 0.7:  # o rastro: 2 pontos atrás, pela velocidade (sem guardar histórico)
					for k in [1, 2]:
						var tr := Vector2(roundf(x[i] - vx[i] * 0.012 * k), roundf(y[i] - vy[i] * 0.012 * k - (z[i] - vz[i] * 0.012 * k)))
						no.draw_rect(Rect2(tr, Vector2.ONE), LARANJA if k == 1 else CINZA_ESC)
			BRASA_T:
				var cor: Color
				if calmo:
					cor = AMBAR_MEDIO
				elif vari[i] == 0:
					cor = BRASA if f < 0.4 else (CIANO if f < 0.75 else AZUL)
				else:
					cor = AMBAR_CLARO if f < 0.4 else (LARANJA if f < 0.75 else CINZA_ESC)
				var bal := roundf(sin(idade[i] * 5.0 + float(i)) * 1.5) if not calmo else 0.0
				no.draw_rect(Rect2(p + Vector2(bal, 0), Vector2.ONE), cor)


## Os pontos de calor no chão (no nó do chão, embaixo dos monstros).
func desenhar_chao(no: CanvasItem) -> void:
	for i in MAX:
		if tipo[i] != CALOR or idade[i] < 0.0:
			continue
		no.draw_rect(Rect2(_tela(i), Vector2(2, 1)), cor_calor(i))


## O blob de fumaça de `diam` px (variante 0..2: o tom), desenhado uma vez por sessão: topo FUMACA, base FUMACA_ESC, borda pontilhada (AZUL_ESC / vazio) no lugar de alfa;
## os dois degraus menores furam (pixels vazios por hash fixo) antes de sumir.
static func blob(diam: int, variante: int) -> Texture2D:
	var chave := diam * 4 + variante
	if _blobs.has(chave):
		return _blobs[chave]
	var im := Image.create(diam, diam, false, Image.FORMAT_RGBA8)
	var r := float(diam) / 2.0
	for yy in diam:
		for xx in diam:
			var dx := float(xx) + 0.5 - r
			var dy := float(yy) + 0.5 - r
			var d := sqrt(dx * dx + dy * dy) / r
			if d > 1.0:
				continue
			var hv := _h(xx, yy, 90 + variante)
			if diam <= 6 and hv < (0.3 if diam == 6 else 0.45):
				continue  # furos
			var cor := FUMACA if dy + (hv - 0.5) * r * 0.6 < -r * 0.15 else FUMACA_ESC
			if variante == 2 and dy > r * 0.3:
				cor = AZUL_ESC
			if d > 0.8:
				if (xx + yy) % 2 == 0:
					continue
				cor = FUMACA_ESC
			im.set_pixel(xx, yy, cor)
	var tex := ImageTexture.create_from_image(im)
	_blobs[chave] = tex
	return tex


## A SUCÇÃO no fim do fusível (antes do estouro): `n` pontos de 1 px que convergem para o casco em 4 degraus de raio (48, 32, 18, 6 px). `k` = 0..1 dentro da janela
## da sucção. Calmo: o anel fecha UMA vez (fica no degrau de 18 px a janela inteira, sem trocar). Estático: não usa o pool (vale também no perfil Baixo, com 4 pontos).
static func desenhar_succao(no: CanvasItem, centro: Vector2, k: float, n: int, eh_calmo: bool) -> void:
	var pts := pontos_succao(centro, k, n, eh_calmo)
	for i in pts.size():
		no.draw_rect(Rect2(pts[i], Vector2.ONE), BRANCO if (i % 2 == 0 or eh_calmo) else CIANO_CLARO)


## Os pontos (inteiros) da sucção em `k` (testes e desenho).
static func pontos_succao(centro: Vector2, k: float, n: int, eh_calmo: bool) -> PackedVector2Array:
	var raios := [48.0, 32.0, 18.0, 6.0]
	var deg := 2 if eh_calmo else clampi(int(k * 4.0), 0, 3)
	var r: float = raios[deg]
	var c := centro.round()
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * (float(i) + 0.5) / float(n)
		out.append((c + Vector2(cos(a) * r, sin(a) * r * ACHATA)).round())
	return out

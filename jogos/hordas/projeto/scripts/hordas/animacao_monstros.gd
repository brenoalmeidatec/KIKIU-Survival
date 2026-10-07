extends RefCounted
## Animação dos monstros de 5 vistas: contas puras (sem nó, sem estado) do ciclo de andar e do movimento secundário.
## Tudo vem de dados/animacao_monstros.json (ver o "_ajuda" de lá); quem desenha é o inimigos.gd.
## O ciclo de andar é a FASE do passo (0..1 = um passo completo de duas pernas) e avança pela DISTÂNCIA andada, não pelo relógio:
## o pé não escorrega, bicho lento passa os quadros devagar e bicho parado congela (e assenta nos pés juntos).

const PADRAO := {
	"ciclo_alt": 1.1, "ciclo_min": 22.0, "bob": 0.018, "bob_min_px": 1.0, "inclina": 0.05, "inclina_suave": 10.0,
	"inclina_topo": 0.45, "aperto_golpe": 0.26, "aperto_golpe_seg": 0.28, "aperto_golpe_quique": 0.35,
	"carga_largura": 0.22, "carga_altura": 0.28, "carga_recuo": 3.0, "carga_curva": 2.0, "lod_dist": 260.0, "lod_max": 220.0,
	"passo_aperto": 0.03, "respira": 0.02, "parado_seg": 0.12, "parado_vel": 1.5,
}


## Os números do json por cima dos padrões daqui (chave que falta no arquivo cai no padrão).
static func config() -> Dictionary:
	var c: Dictionary = PADRAO.duplicate()
	for k in Dados.json("animacao_monstros"):
		if c.has(k):
			c[k] = float(Dados.json("animacao_monstros")[k])
	return c


## Colunas da folha (quadros de andar + 1 de branco). Folha que o gerador não registrou é antiga: 3 colunas.
static func colunas(sprite: String) -> int:
	return maxi(3, int(Dados.json("quadros_monstros").get(sprite, 3)))


## Quadro (0..n-1) da fase do passo (0..1).
static func quadro(fase: float, n: int) -> int:
	return clampi(int(fase * n), 0, n - 1)


## Coluna da folha cuja sombra assada serve a este quadro: só duas (a do passo e a do meio dele), como as 2 poses antigas;
## o atlas de sombras (1024x1024) não comportaria um por quadro de cada um dos ~50 monstros.
static func coluna_sombra(q: int, n: int) -> int:
	var meio := n / 2
	return meio if q >= n / 4 and q < n / 4 + meio else 0


## Comprimento do ciclo de andar em px da tela: `alt` alturas do sprite (`mult` > 0 troca a do json), com piso `minimo`.
static func ciclo_px(altura: float, alt: float, minimo: float, mult := -1.0) -> float:
	return maxf(minimo, altura * (mult if mult > 0.0 else alt))


## Fase depois de `passo` px andados (um ciclo = `ciclo` px).
static func avancar(fase: float, passo: float, ciclo: float) -> float:
	return fposmod(fase + passo / ciclo, 1.0)


## Parado: assenta no pé-junto mais perto (fase 0 ou 0,5) a `vel` ciclos por segundo.
static func assentar(fase: float, dt: float, vel: float) -> float:
	return fposmod(move_toward(fase, roundf(fase * 2.0) * 0.5, dt * vel), 1.0)


## Aperto ao levar golpe: 1 no impacto, volta a 0 em `dur` s, com um quique (passa do ponto pro lado oposto, de tamanho
## `quique` x o aperto). `t` = segundos desde o golpe. Positivo = achata e alarga; negativo = estica.
static func aperto(t: float, dur: float, quique: float) -> float:
	if t < 0.0 or t >= dur:
		return 0.0
	var u := t / dur
	var f := (1.0 - u) * cos(1.5 * PI * u)
	return f * quique / 0.39 if f < 0.0 else f   # (o lado negativo de f chega a -0,39)


## Curva do preparo da investida: u = 0..1 (quanto do aviso já passou), `curva` = potência (1 linear, 2 devagar no começo).
static func carga(u: float, curva: float) -> float:
	return pow(clampf(u, 0.0, 1.0), curva)


## Altura do corpo no passo (0..1): mais alto com as pernas juntas (fase 0 e 0,5), mais baixo com elas abertas.
static func subida(fase: float) -> float:
	return 0.5 + 0.5 * cos(4.0 * PI * fase)

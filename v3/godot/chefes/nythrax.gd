extends "res://chefes/chefe_base.gd"
## Nythrax, o Lobo do Véu Negro (mini-chefe 2 da Floresta, v3). Ficha em docs/v3/chefes/FICHA_TECNICA.md (seção Nythrax).
## Dados aqui; a lógica é a da base. Ilusões não dão dano (dano 0 e "ilusao": true); a névoa só muda a animação (sem dano).
## Fase de caça abaixo de 35% de vida: ataques novos e recargas menores. Valores iniciais, sem ajuste de jogo.

const CONFIG := {
	"vida": 1600.0,
	"fase2": 0.35,
	"ataques":
	[
		{"nome": "investida_sombria", "clip": "investida", "aviso": 0.6, "recupera": 0.5, "recarga": 2.2, "raio": 2.5, "dano": 7.0, "fase": 1},
		{"nome": "nevoa_ocultante", "clip": "nevoa", "aviso": 0.5, "recupera": 0.6, "recarga": 2.5, "raio": 0.0, "dano": 0.0, "fase": 1},
		{"nome": "golpe_em_arco", "clip": "golpe_arco", "aviso": 0.8, "recupera": 0.6, "recarga": 2.0, "raio": 1.8, "dano": 6.0, "fase": 1},
		{"nome": "ilusoes_espectrais", "clip": "ilusao", "aviso": 0.5, "recupera": 0.6, "recarga": 3.0, "raio": 0.0, "dano": 0.0, "ilusao": true, "fase": 1},
		{"nome": "investida_dupla", "clip": "investida", "aviso": 0.5, "recupera": 0.4, "recarga": 1.4, "raio": 2.8, "dano": 7.0, "fase": 2},
		{"nome": "garras_de_caca", "clip": "golpe_arco", "aviso": 0.5, "recupera": 0.4, "recarga": 1.2, "raio": 2.0, "dano": 7.0, "fase": 2},
	],
}


## Clipe de animação do ataque atual (ou o de andar, se não há ataque em curso).
func clip_atual() -> String:
	if ataque_atual.is_empty():
		return "run" if fase == 2 else "walk"
	return String(ataque_atual.clip)


## Fase de caça: a mesma regra de fase da base, com o limiar de 35%.
func em_caca() -> bool:
	return fase == 2

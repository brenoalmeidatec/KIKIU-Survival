extends "res://v3/chefes/chefe_base.gd"
## Vornak, o Devorador de Raízes (mini-chefe 1 da Floresta, v3). Ficha em docs/v3/chefes/FICHA_TECNICA.md.
## Dados aqui; a lógica é a da base. Cada ataque diz qual animação das folhas toca ("clip", em assets/v3/chefes/vornak_sprites.json).
## Valores iniciais, ainda sem ajuste de jogo: vida 1100 (chute da v1), fase 2 abaixo de 40%.

const CONFIG := {
	"vida": 1100.0,
	"fase2": 0.4,
	"ataques": [
		{"nome": "raizes_corrompidas", "clip": "attack_01", "aviso": 0.9, "impacto": 0.2, "recupera": 0.6, "recarga": 2.5, "raio": 3.0, "dano": 28.0, "fase": 1},
		{"nome": "golpe_de_raizes", "clip": "attack_02", "aviso": 0.7, "impacto": 0.2, "recupera": 0.6, "recarga": 2.0, "raio": 2.2, "dano": 22.0, "fase": 1},
		{"nome": "absorcao_de_vida", "clip": "attack_03", "aviso": 1.2, "impacto": 0.2, "recupera": 0.8, "recarga": 3.0, "raio": 0.0, "dano": 0.0, "cura": 60.0, "fase": 1},
		{"nome": "raizes_longas", "clip": "attack_04_segunda_forma", "aviso": 0.6, "impacto": 0.2, "recupera": 0.5, "recarga": 1.6, "raio": 3.6, "dano": 30.0, "fase": 2},
		{"nome": "tempestade_de_raizes", "clip": "attack_02", "aviso": 0.5, "impacto": 0.2, "recupera": 0.4, "recarga": 1.2, "raio": 2.6, "dano": 24.0, "fase": 2},
	],
}


## Clipe de animação do ataque atual (ou o do estado, se não há ataque em curso).
func clip_atual() -> String:
	if ataque_atual.is_empty():
		return "idle"
	return String(ataque_atual.clip)
